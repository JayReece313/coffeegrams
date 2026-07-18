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
    var isAwaitingManualAdvance: Bool { phase == .awaitingManualAdvance }
    var isFinished: Bool { phase == .completed }

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

    func reset() {
        engine.reset()
        syncFromEngine()
    }

    // MARK: Ticking (called by the view's timer, or by tests directly)

    /// Advance the engine by the real time elapsed since the last tick. A no-op
    /// unless a timed step is running, so the view can call it on a steady timer
    /// without worrying about the current phase.
    func tickOnce() {
        guard phase == .running else { return }
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
    }
}
