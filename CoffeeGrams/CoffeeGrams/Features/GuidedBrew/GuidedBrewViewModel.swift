//
//  GuidedBrewViewModel.swift
//  CoffeeGrams
//
//  Drives the guided-brew timer screen. It owns the tested BrewTimerEngine and
//  mirrors its state into observable properties the view can render.
//
//  The VM holds NO background timer of its own: the view drives the cadence by
//  calling `tickOnce()` on a periodic timer while a brew is running. Keeping the
//  clock loop in the view means the VM is a pure, synchronous state machine —
//  no leaked Tasks, and tests advance a fake clock and call `tickOnce()` by hand.
//

import Foundation
import Observation
import CoffeeGramsCore

@MainActor
@Observable
final class GuidedBrewViewModel {

    let timeline: BrewTimeline

    // MARK: Mirrored display state
    private(set) var phase: BrewTimerPhase = .idle
    private(set) var currentStepIndex: Int = 0
    private(set) var remainingSeconds: Int = 0
    private(set) var fractionComplete: Double = 0
    /// Seconds the current hands-on step has run past its target (0 unless
    /// overrunning) — displayed as "+0:07".
    private(set) var overrunSeconds: Int = 0
    /// The master count-up clock: total wall-clock seconds since Start.
    private(set) var totalElapsedSeconds: Int = 0

    // MARK: Collaborators (injected for testability)
    private let engine: BrewTimerEngine
    private let clock: MonotonicClock
    private let haptics: HapticsPerforming

    /// The clock reading at the last tick, used to compute the delta to advance.
    private var lastTickTime: TimeInterval = 0

    init(
        timeline: BrewTimeline,
        clock: MonotonicClock = SystemClock(),
        haptics: HapticsPerforming = LiveHaptics()
    ) {
        self.timeline = timeline
        self.engine = BrewTimerEngine(timeline: timeline)
        self.clock = clock
        self.haptics = haptics
        engine.onEvent = { [weak self] event in self?.handle(event) }
        syncFromEngine()
    }

    // MARK: Derived view state

    var steps: [BrewStep] { timeline.steps }
    var isIdle: Bool { phase == .idle }
    var isRunning: Bool { phase == .running }
    var isPaused: Bool { phase == .paused }
    var isOverrunning: Bool { phase == .overrunning }
    var isAwaitingManualAdvance: Bool { phase == .awaitingManualAdvance }
    var isFinished: Bool { phase == .completed }

    /// True whenever a brew is live — running, overrunning, or held on a manual
    /// step. What the Start/Stop toggle keys off.
    var isActive: Bool { isRunning || isOverrunning || isAwaitingManualAdvance }

    /// True when the brew has begun and can therefore be finished or stopped —
    /// i.e. anything other than "not started" or "already done".
    var hasStarted: Bool { !isIdle && !isFinished }

    /// The user's forward action on the current step, or `nil` when there is
    /// nothing to advance. An overrunning hands-on step and a manual step both
    /// resolve with the same tap, but they mean different things, so they get
    /// different words: "Next" moves to the following pour; "Done" ends an
    /// open-ended action like the plunge.
    var advanceTitle: String? {
        if isOverrunning { return "Next" }
        if isAwaitingManualAdvance { return "Done" }
        return nil
    }

    var currentStep: BrewStep? {
        steps.indices.contains(currentStepIndex) ? steps[currentStepIndex] : nil
    }

    // MARK: Controls

    func start() {
        guard phase == .idle else { return }
        engine.start()
        lastTickTime = clock.now
        syncFromEngine()
    }

    func pause() {
        engine.pause()
        syncFromEngine()
    }

    func resume() {
        engine.resume()
        lastTickTime = clock.now
        syncFromEngine()
    }

    /// The "Next"/"Done" action for a manual step (or a deliberate skip).
    func advanceStep() {
        engine.advanceStep()
        lastTickTime = clock.now
        syncFromEngine()
    }

    /// End the brew where it stands — the "End Brew" button. The user has
    /// decided the coffee is made, so we stop the master clock and keep the
    /// time it actually took rather than walking the remaining steps.
    func finish() {
        engine.finish()
        syncFromEngine()
    }

    /// One button, two meanings: pause a live brew, resume a paused one.
    func togglePause() {
        if isPaused { resume() } else { pause() }
    }

    func reset() {
        engine.reset()
        syncFromEngine()
    }

    /// The total elapsed time to write to the log when the brew is saved.
    /// Read from the engine's wall clock, so it includes slow pours and however
    /// long the plunge took — the "actual" half of planned vs actual.
    var actualSeconds: Int { totalElapsedSeconds }

    /// The brew's planned duration: the sum of the timeline's fixed step
    /// durations. Manual steps contribute nothing because they have no plan.
    var plannedSeconds: Int { timeline.totalFixedDuration }

    // MARK: Ticking (called by the view's timer, or by tests directly)

    /// Advance the engine by the real time elapsed since the last tick.
    ///
    /// This ticks through **every live phase**, not just `.running`: the master
    /// clock has to keep counting while a hands-on step overruns and while a
    /// manual step waits, or the logged brew time would omit exactly the parts
    /// the user was slowest on. The engine decides what that time counts
    /// towards; the view just keeps the pulse going.
    func tickOnce() {
        guard isActive else { return }
        let now = clock.now
        let delta = now - lastTickTime
        lastTickTime = now
        engine.advance(by: delta)
        syncFromEngine()
    }

    // MARK: Engine bridging

    private func handle(_ event: BrewTimerEvent) {
        switch event {
        case .stepBegan:
            haptics.stepChange()
        case .reachedTarget:
            haptics.targetReached()
        case .completed:
            haptics.finished()
        case .started, .stepCompleted, .awaitingManualAdvance:
            break
        }
    }

    private func syncFromEngine() {
        phase = engine.phase
        currentStepIndex = engine.currentStepIndex
        // Round up so a step with 0.3s left still reads "1", never "0:00" while
        // it's still going.
        remainingSeconds = Int((engine.remainingInStep ?? 0).rounded(.up))
        fractionComplete = engine.fractionComplete
        // Round overrun and the master clock *down*: they count up, so flooring
        // means the display never claims more time than has actually passed.
        overrunSeconds = Int((engine.overrunInStep ?? 0).rounded(.down))
        totalElapsedSeconds = Int(engine.totalWallElapsed.rounded(.down))
    }
}
