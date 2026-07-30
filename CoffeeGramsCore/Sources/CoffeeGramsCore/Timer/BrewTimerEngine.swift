import Foundation

/// Where the guided brew currently is.
public enum BrewTimerPhase: Equatable, Sendable {
    /// Not started yet.
    case idle
    /// A fixed-duration step is counting down.
    case running
    /// A **soft-target** step has reached its target and is now counting *up*
    /// past it, waiting for the user to tap next. The brew has not stalled —
    /// the master clock keeps running — the app simply refuses to guess that a
    /// slow pour has finished. See `BrewStep.usesSoftTarget`.
    case overrunning
    /// Temporarily paused by the user.
    case paused
    /// On a manual step (plunge / drawdown-until-drips) — the clock is held and
    /// we are waiting for the user to tap "next".
    case awaitingManualAdvance
    /// The whole timeline is finished.
    case completed
}

/// Something worth reacting to — the app turns these into haptics / sounds /
/// UI updates. Emitted synchronously as the engine's state changes.
public enum BrewTimerEvent: Equatable, Sendable {
    case started
    case stepBegan(index: Int, step: BrewStep)
    /// A soft-target step hit its target and is now overrunning. Worth a haptic:
    /// it is the cue to finish pouring and tap next.
    case reachedTarget(index: Int, step: BrewStep)
    case stepCompleted(index: Int, step: BrewStep)
    case awaitingManualAdvance(index: Int, step: BrewStep)
    case completed
}

/// Walks a `BrewTimeline`'s steps in real time.
///
/// Design: the engine is a **pure state machine driven by time deltas**, not by
/// reading a clock. The app feeds it `advance(by:)` from a repeating timer that
/// measures elapsed seconds via a `MonotonicClock`; tests feed it exact deltas.
/// This inversion is the entire reason the timer is testable without waiting in
/// real time — a full four-minute French Press brew is verified in microseconds.
///
/// Manual steps (nil duration) *hold* the machine in `awaitingManualAdvance`:
/// `advance(by:)` deliberately does nothing until `advanceStep()` is called, so
/// a plunge or drawdown never times out on the user.
///
/// Not `Sendable` by design — it is mutable reference state intended to live on
/// the main actor alongside the UI. The app wraps it in an observable view
/// model; Core keeps it free of any UI framework.
public final class BrewTimerEngine {
    public let timeline: BrewTimeline

    public private(set) var phase: BrewTimerPhase = .idle
    public private(set) var currentStepIndex: Int = 0
    /// Seconds elapsed within the current step. For a soft-target step this may
    /// exceed the step's `duration` — that excess is the overrun.
    public private(set) var elapsedInStep: TimeInterval = 0
    /// Seconds of time counted **against the timeline's fixed durations**.
    /// Manual holds and overruns add none, so this stays a clean measure of
    /// progress through the plan — it is what `fractionComplete` divides.
    public private(set) var totalElapsed: TimeInterval = 0
    /// Seconds of **wall-clock** time since `start()`, the master "total
    /// elapsed" clock. Unlike `totalElapsed` this keeps running through
    /// overruns and manual holds, and stops only while paused — so it answers
    /// "how long did this brew actually take?" rather than "how far through the
    /// plan are we?". Pairing the two is what gives us planned vs actual.
    public private(set) var totalWallElapsed: TimeInterval = 0

    /// The phase to return to on `resume()`. A brew can be paused from any live
    /// phase, so "unpause" is not simply "go back to running".
    private var phaseBeforePause: BrewTimerPhase?

    /// Fired synchronously on every state transition. Wire haptics/sound here.
    public var onEvent: ((BrewTimerEvent) -> Void)?

    public init(timeline: BrewTimeline) {
        self.timeline = timeline
    }

    // MARK: Derived state (for the UI)

    private var steps: [BrewStep] { timeline.steps }

    public var currentStep: BrewStep? {
        steps.indices.contains(currentStepIndex) ? steps[currentStepIndex] : nil
    }

    /// Seconds left in the current fixed-duration step, or `nil` for manual /
    /// finished states. Clamped at 0 — once a soft-target step passes its
    /// target the overrun is reported by `overrunInStep`, not as a negative
    /// remainder, so existing countdown UI needs no special-casing.
    public var remainingInStep: TimeInterval? {
        guard let duration = currentStep?.duration else { return nil }
        return max(0, Double(duration) - elapsedInStep)
    }

    /// Seconds the current step has run **past** its target, or `nil` when it
    /// is not overrunning. This is what the UI shows as `+0:07`.
    public var overrunInStep: TimeInterval? {
        guard phase == .overrunning, let duration = currentStep?.duration else { return nil }
        return max(0, elapsedInStep - Double(duration))
    }

    /// True while a live brew is in progress in any form — running, overrunning
    /// or held on a manual step. Distinguishes "the brew is going" from paused,
    /// idle and completed, which is exactly what a Start/Stop toggle needs.
    public var isActive: Bool {
        phase == .running || phase == .overrunning || phase == .awaitingManualAdvance
    }

    /// 0…1 progress across the brew's fixed duration. Completed reads as 1.
    public var fractionComplete: Double {
        if phase == .completed { return 1 }
        let total = timeline.totalFixedDuration
        guard total > 0 else { return 0 }
        return min(1, totalElapsed / Double(total))
    }

    public var isFinished: Bool { phase == .completed }

    // MARK: Controls

    /// Begin from idle. No-op if already started.
    public func start() {
        guard phase == .idle else { return }
        guard !steps.isEmpty else {
            phase = .completed
            onEvent?(.completed)
            return
        }
        currentStepIndex = 0
        elapsedInStep = 0
        totalElapsed = 0
        totalWallElapsed = 0
        phaseBeforePause = nil
        phase = .running
        onEvent?(.started)
        beginCurrentStep()
    }

    /// Advance the brew by `delta` seconds of real time.
    ///
    /// Two clocks move here, and they move differently:
    ///
    /// - `totalWallElapsed` accrues in **every** live phase — running,
    ///   overrunning, and holding on a manual step — because it measures how
    ///   long the brew has actually taken.
    /// - `totalElapsed` accrues **only** against a step's fixed duration, and
    ///   never past it, so the progress bar cannot exceed the plan.
    ///
    /// Ignored while idle, paused or completed.
    public func advance(by delta: TimeInterval) {
        guard delta > 0 else { return }

        switch phase {
        case .idle, .paused, .completed:
            return

        case .overrunning, .awaitingManualAdvance:
            // Held for the user. The plan makes no progress, but time passes:
            // the master clock and the step's own elapsed counter keep going so
            // we can show "+0:07" and log an honest actual duration.
            elapsedInStep += delta
            totalWallElapsed += delta

        case .running:
            var remaining = delta
            while remaining > 0, phase == .running {
                guard let duration = currentStep?.duration else {
                    // Defensive: a manual step should already have moved us to
                    // `awaitingManualAdvance` in `beginCurrentStep`.
                    return
                }
                let left = Double(duration) - elapsedInStep
                if remaining < left {
                    elapsedInStep += remaining
                    totalElapsed += remaining
                    totalWallElapsed += remaining
                    remaining = 0
                } else {
                    elapsedInStep = Double(duration)
                    totalElapsed += left
                    totalWallElapsed += left
                    remaining -= left
                    reachTargetOfCurrentStep()
                }
            }
            // A coarse tick can carry time past the point where we stopped
            // making plan progress (we hit a soft target, or landed on a manual
            // step). That leftover is still real time the user spent brewing.
            if remaining > 0, phase == .overrunning || phase == .awaitingManualAdvance {
                elapsedInStep += remaining
                totalWallElapsed += remaining
            }
        }
    }

    /// Complete the current step immediately — the user's "next" tap on a
    /// manual or overrunning step, or a deliberate skip of a timed step.
    public func advanceStep() {
        guard isActive, currentStep != nil else { return }
        phase = .running // so the shared transition path runs uniformly
        completeCurrentStepAndAdvance()
    }

    /// Pause any live phase. Overruns and manual holds are pausable too — the
    /// master clock is running during both, and stopping it is the whole point.
    public func pause() {
        guard isActive else { return }
        phaseBeforePause = phase
        phase = .paused
    }

    public func resume() {
        guard phase == .paused else { return }
        phase = phaseBeforePause ?? .running
        phaseBeforePause = nil
    }

    /// End the brew wherever it is — the "Done" button. Unlike `advanceStep()`
    /// this does not walk the remaining steps: the user has decided the coffee
    /// is made, so we finish immediately and keep the elapsed time they took.
    /// No-op when there is nothing to finish.
    public func finish() {
        guard phase != .idle, phase != .completed else { return }
        phaseBeforePause = nil
        phase = .completed
        onEvent?(.completed)
    }

    /// Return to the un-started state so the same timeline can be run again.
    public func reset() {
        phase = .idle
        currentStepIndex = 0
        elapsedInStep = 0
        totalElapsed = 0
        totalWallElapsed = 0
        phaseBeforePause = nil
    }

    // MARK: Transitions

    private func beginCurrentStep() {
        guard let step = currentStep else { return }
        onEvent?(.stepBegan(index: currentStepIndex, step: step))
        if step.requiresManualAdvance {
            phase = .awaitingManualAdvance
            onEvent?(.awaitingManualAdvance(index: currentStepIndex, step: step))
        }
    }

    /// Called the instant a timed step's duration is used up. A soft-target
    /// step holds here and counts up; an unattended one moves on by itself.
    private func reachTargetOfCurrentStep() {
        guard let step = currentStep else { return }
        if step.usesSoftTarget {
            phase = .overrunning
            onEvent?(.reachedTarget(index: currentStepIndex, step: step))
        } else {
            completeCurrentStepAndAdvance()
        }
    }

    private func completeCurrentStepAndAdvance() {
        guard let finished = currentStep else { return }
        onEvent?(.stepCompleted(index: currentStepIndex, step: finished))

        let nextIndex = currentStepIndex + 1
        if nextIndex >= steps.count {
            phase = .completed
            onEvent?(.completed)
            return
        }
        currentStepIndex = nextIndex
        elapsedInStep = 0
        beginCurrentStep()
    }
}
