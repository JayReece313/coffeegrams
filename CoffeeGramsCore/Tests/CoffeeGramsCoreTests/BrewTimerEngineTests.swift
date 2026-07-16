import Testing
@testable import CoffeeGramsCore

/// M4 gate: the guided-brew timer state machine. Driven by exact time deltas,
/// so a full brew is verified instantly and deterministically — no real
/// waiting, no flakiness.
@Suite("BrewTimerEngine")
struct BrewTimerEngineTests {

    /// Collects events so their order can be asserted.
    private final class Recorder {
        private(set) var events: [BrewTimerEvent] = []
        func attach(to engine: BrewTimerEngine) {
            engine.onEvent = { [weak self] in self?.events.append($0) }
        }
    }

    private func v60() -> BrewTimeline {
        // bloom(45) + pour1(45) + pour2(45) + drawdown(manual)
        BrewTimelineBuilder.buildPulsePourTimeline(profile: .v60, doseGrams: 18, ratio: 16)
    }

    private func frenchPress() -> BrewTimeline {
        // bloom(30) + fill(15) + steep(240) + plunge(manual)
        BrewTimelineBuilder.buildFrenchPressTimeline(doseGrams: 30, ratio: 15)
    }

    // MARK: Start

    @Test("start emits started + first step and enters running")
    func startBeginsFirstStep() {
        let engine = BrewTimerEngine(timeline: v60())
        let rec = Recorder(); rec.attach(to: engine)
        engine.start()

        #expect(engine.phase == .running)
        #expect(engine.currentStepIndex == 0)
        #expect(rec.events == [.started, .stepBegan(index: 0, step: v60().steps[0])])
        #expect(engine.remainingInStep == 45)
    }

    @Test("advance before start does nothing")
    func advanceWhileIdleIgnored() {
        let engine = BrewTimerEngine(timeline: v60())
        engine.advance(by: 100)
        #expect(engine.phase == .idle)
        #expect(engine.totalElapsed == 0)
    }

    // MARK: Stepping through fixed-duration steps

    @Test("finishing a step's duration transitions to the next step")
    func stepBoundary() {
        let engine = BrewTimerEngine(timeline: v60())
        let rec = Recorder(); rec.attach(to: engine)
        engine.start()

        engine.advance(by: 45) // exactly finishes the bloom
        #expect(engine.currentStepIndex == 1)
        #expect(engine.elapsedInStep == 0)
        #expect(engine.phase == .running)
        #expect(rec.events.suffix(2) == [
            .stepCompleted(index: 0, step: v60().steps[0]),
            .stepBegan(index: 1, step: v60().steps[1]),
        ])
    }

    @Test("partial advance accumulates within a step")
    func partialAdvance() {
        let engine = BrewTimerEngine(timeline: v60())
        engine.start()
        engine.advance(by: 20)
        #expect(engine.elapsedInStep == 20)
        #expect(engine.remainingInStep == 25)
        #expect(engine.currentStepIndex == 0)
    }

    @Test("a single coarse tick can cross several steps but halts at a manual step")
    func coarseTickHaltsAtManual() {
        let engine = BrewTimerEngine(timeline: v60())
        engine.start()
        engine.advance(by: 10_000) // way past every timed step
        // bloom45 + pour45 + pour45 = 135 counted, then drawdown holds.
        #expect(engine.totalElapsed == 135)
        #expect(engine.phase == .awaitingManualAdvance)
        #expect(engine.currentStep == .drawdown(untilDripsStop: true))
    }

    // MARK: Manual steps

    @Test("manual step holds against time until advanceStep is called")
    func manualStepHolds() {
        let engine = BrewTimerEngine(timeline: v60())
        let rec = Recorder(); rec.attach(to: engine)
        engine.start()
        engine.advance(by: 135) // reach the drawdown

        #expect(engine.phase == .awaitingManualAdvance)
        engine.advance(by: 999) // ignored while awaiting
        #expect(engine.totalElapsed == 135)
        #expect(engine.phase == .awaitingManualAdvance)

        engine.advanceStep() // user taps "done"
        #expect(engine.phase == .completed)
        #expect(engine.isFinished)
        #expect(engine.fractionComplete == 1)
        #expect(rec.events.last == .completed)
    }

    @Test("advanceStep skips the remainder of a timed step")
    func skipTimedStep() {
        let engine = BrewTimerEngine(timeline: frenchPress())
        engine.start()
        engine.advance(by: 10) // 10s into the 30s bloom
        engine.advanceStep()   // skip the rest of the bloom
        #expect(engine.currentStepIndex == 1) // now on the fill pour
        #expect(engine.phase == .running)
    }

    // MARK: Full brews

    @Test("French Press runs to completion and holds at plunge")
    func frenchPressFullRun() {
        let engine = BrewTimerEngine(timeline: frenchPress())
        let rec = Recorder(); rec.attach(to: engine)
        engine.start()

        engine.advance(by: 285) // bloom30 + fill15 + steep240
        #expect(engine.currentStep == .plunge)
        #expect(engine.phase == .awaitingManualAdvance)
        #expect(engine.totalElapsed == 285)

        engine.advanceStep()
        #expect(engine.phase == .completed)
        #expect(rec.events.last == .completed)
        // Sanity: exactly one completed event, and it is last.
        #expect(rec.events.filter { $0 == .completed }.count == 1)
    }

    // MARK: Pause / resume

    @Test("pause freezes time; resume continues where it left off")
    func pauseResume() {
        let engine = BrewTimerEngine(timeline: v60())
        engine.start()
        engine.advance(by: 20)
        engine.pause()
        #expect(engine.phase == .paused)
        engine.advance(by: 100) // ignored while paused
        #expect(engine.elapsedInStep == 20)

        engine.resume()
        engine.advance(by: 25) // completes the 45s bloom
        #expect(engine.currentStepIndex == 1)
    }

    // MARK: Reset

    @Test("reset returns to idle so the timeline can be rerun")
    func reset() {
        let engine = BrewTimerEngine(timeline: v60())
        engine.start()
        engine.advance(by: 90)
        engine.reset()
        #expect(engine.phase == .idle)
        #expect(engine.currentStepIndex == 0)
        #expect(engine.totalElapsed == 0)

        engine.start() // rerunnable
        #expect(engine.phase == .running)
    }

    // MARK: Progress + edge cases

    @Test("fractionComplete tracks counted time over fixed duration")
    func fractionComplete() {
        let engine = BrewTimerEngine(timeline: v60()) // total fixed = 135
        engine.start()
        engine.advance(by: 45)
        #expect(abs(engine.fractionComplete - (45.0 / 135.0)) < 1e-9)
    }

    @Test("an empty timeline completes immediately on start")
    func emptyTimeline() {
        let engine = BrewTimerEngine(timeline: BrewTimeline(method: .v60, steps: [], totalWaterGrams: 0))
        let rec = Recorder(); rec.attach(to: engine)
        engine.start()
        #expect(engine.phase == .completed)
        #expect(rec.events == [.completed])
    }
}
