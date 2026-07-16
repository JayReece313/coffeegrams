import Foundation

/// Where the guided brew currently is.
public enum BrewTimerPhase: Equatable, Sendable {
    /// Not started yet.
    case idle
    /// A fixed-duration step is counting down.
    case running
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
    /// Seconds elapsed within the current step.
    public private(set) var elapsedInStep: TimeInterval = 0
    /// Seconds of *counted* time across the whole brew (manual holds add none).
    public private(set) var totalElapsed: TimeInterval = 0

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
    /// finished states.
    public var remainingInStep: TimeInterval? {
        guard let duration = currentStep?.duration else { return nil }
        return max(0, Double(duration) - elapsedInStep)
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
        phase = .running
        onEvent?(.started)
        beginCurrentStep()
    }

    /// Advance counted time by `delta` seconds. Ignored unless running; stops at
    /// the first manual step encountered (carrying no time past it).
    public func advance(by delta: TimeInterval) {
        guard phase == .running, delta > 0 else { return }
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
                remaining = 0
            } else {
                elapsedInStep = Double(duration)
                totalElapsed += left
                remaining -= left
                completeCurrentStepAndAdvance()
            }
        }
    }

    /// Complete the current step immediately — the user's "next" tap on a manual
    /// step, or a deliberate skip of a timed step.
    public func advanceStep() {
        guard phase == .running || phase == .awaitingManualAdvance else { return }
        guard currentStep != nil else { return }
        phase = .running // so the shared transition path runs uniformly
        completeCurrentStepAndAdvance()
    }

    public func pause() {
        guard phase == .running else { return }
        phase = .paused
    }

    public func resume() {
        guard phase == .paused else { return }
        phase = .running
    }

    /// Return to the un-started state so the same timeline can be run again.
    public func reset() {
        phase = .idle
        currentStepIndex = 0
        elapsedInStep = 0
        totalElapsed = 0
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
