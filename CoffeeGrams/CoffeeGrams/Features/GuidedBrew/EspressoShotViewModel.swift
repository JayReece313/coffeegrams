//
//  EspressoShotViewModel.swift
//  CoffeeGrams
//
//  Espresso is deliberately shallow (spec §4.6): a target yield and a shot
//  stopwatch that reads green inside the 25–30s window, amber before, red after.
//

import Foundation
import Observation
import CoffeeGramsCore

@MainActor
@Observable
final class EspressoShotViewModel {

    let target: EspressoTarget

    private(set) var elapsedSeconds: Int = 0
    private(set) var isRunning: Bool = false

    private let clock: MonotonicClock
    private var startTime: TimeInterval = 0
    private var tickTask: Task<Void, Never>?

    init(target: EspressoTarget, clock: MonotonicClock = SystemClock()) {
        self.target = target
        self.clock = clock
    }

    /// Green / amber / red classification of the current elapsed time against
    /// the target window — computed by the tested Core helper.
    var timingState: ShotTimingState {
        ShotTimingState.classify(elapsedSeconds: elapsedSeconds, window: target.shotTimeRange)
    }

    var hasStarted: Bool { isRunning || elapsedSeconds > 0 }

    func startOrStop() {
        if isRunning { stop() } else { start() }
    }

    func start() {
        isRunning = true
        elapsedSeconds = 0
        startTime = clock.now
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                self.tickOnce()
                if !self.isRunning { break }
            }
        }
    }

    func stop() {
        isRunning = false
        tickTask?.cancel()
        tickTask = nil
    }

    func reset() {
        stop()
        elapsedSeconds = 0
    }

    /// Recompute elapsed whole seconds from the clock. Internal so tests can
    /// drive it with a fake clock.
    func tickOnce() {
        guard isRunning else { return }
        elapsedSeconds = max(0, Int(clock.now - startTime))
    }
}
