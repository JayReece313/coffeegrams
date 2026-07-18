//
//  GuidedBrewViewModel.swift
//  CoffeeGrams
//
//  Drives the guided-brew timer screen. It owns the tested BrewTimerEngine and
//  mirrors its state into observable properties the view can render, ticking the
//  engine forward in real time.
//

import Foundation
import Observation
import CoffeeGramsCore

@MainActor
@Observable
final class GuidedBrewViewModel {

    let timeline: BrewTimeline

    // MARK: Mirrored display state
    //
    // BrewTimerEngine is a plain (non-observable) state machine, so we copy the
    // values the UI needs into these observable properties after every change.
    // The view reads these, and `@Observable` refreshes it automatically.
    private(set) var phase: BrewTimerPhase = .idle
    private(set) var currentStepIndex: Int = 0
    private(set) var remainingSeconds: Int = 0
    private(set) var fractionComplete: Double = 0

    // MARK: Collaborators (injected for testability)
    private let engine: BrewTimerEngine
    private let clock: MonotonicClock
    private let haptics: HapticsPerforming

    private var tickTask: Task<Void, Never>?
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
        startTickingIfRunning()
    }

    func pause() {
        engine.pause()
        stopTicking()
        syncFromEngine()
    }

    func resume() {
        engine.resume()
        lastTickTime = clock.now
        syncFromEngine()
        startTickingIfRunning()
    }

    /// The "Next"/"Done" action for a manual step (or a deliberate skip).
    func advanceStep() {
        engine.advanceStep()
        lastTickTime = clock.now
        syncFromEngine()
        startTickingIfRunning()
    }

    func reset() {
        stopTicking()
        engine.reset()
        syncFromEngine()
    }

    // MARK: Ticking

    /// Advance the engine by the real time elapsed since the last tick. Exposed
    /// (internal) so tests can drive it deterministically with a fake clock
    /// instead of waiting in real time.
    func tickOnce() {
        guard phase == .running else { return }
        let now = clock.now
        let delta = now - lastTickTime
        lastTickTime = now
        engine.advance(by: delta)
        syncFromEngine()
    }

    private func startTickingIfRunning() {
        guard phase == .running else { return }
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                self.tickOnce()
                // Stop the loop once we leave the running state (manual step,
                // pause, or completion) — it restarts on the next control action.
                if self.phase != .running { break }
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
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
        // Round up so a step that has 0.3s left still reads "1", never "0:00"
        // while it's still going.
        remainingSeconds = Int((engine.remainingInStep ?? 0).rounded(.up))
        fractionComplete = engine.fractionComplete
    }
}
