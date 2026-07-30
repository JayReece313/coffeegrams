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

    /// Walk a v60 brew to its drawdown. Every timed step is hands-on, so each
    /// one holds at its target and needs a tap — see `BrewStep.usesSoftTarget`.
    private func runV60ToDrawdown(_ engine: BrewTimerEngine) {
        engine.start()
        for _ in 0..<3 { // bloom, pour 1, pour 2
            engine.advance(by: 45)
            engine.advanceStep()
        }
    }

    // MARK: Stepping through fixed-duration steps

    @Test("partial advance accumulates within a step")
    func partialAdvance() {
        let engine = BrewTimerEngine(timeline: v60())
        engine.start()
        engine.advance(by: 20)
        #expect(engine.elapsedInStep == 20)
        #expect(engine.remainingInStep == 25)
        #expect(engine.currentStepIndex == 0)
    }

    @Test("an unattended step auto-advances at its target")
    func unattendedStepAutoAdvances() {
        // French Press: bloom(soft) → fill(soft) → steep 240 (unattended) → plunge.
        let engine = BrewTimerEngine(timeline: frenchPress())
        let rec = Recorder(); rec.attach(to: engine)
        engine.start()

        engine.advance(by: 30); engine.advanceStep() // bloom, tapped
        engine.advance(by: 15); engine.advanceStep() // fill pour, tapped
        #expect(engine.currentStep == .steep(duration: 240))

        engine.advance(by: 240) // the steep needs no tap — you may have walked away
        #expect(engine.currentStep == .plunge)
        #expect(engine.phase == .awaitingManualAdvance)
        #expect(rec.events.contains(.stepCompleted(index: 2, step: .steep(duration: 240))))
        // The steep never announces an overrun; it simply ends.
        #expect(!rec.events.contains(.reachedTarget(index: 2, step: .steep(duration: 240))))
    }

    // MARK: Soft targets (hands-on steps)

    @Test("a soft-target step holds at its target and counts up")
    func softTargetHoldsAndCountsUp() {
        let engine = BrewTimerEngine(timeline: v60())
        let rec = Recorder(); rec.attach(to: engine)
        engine.start()

        engine.advance(by: 45) // exactly reaches the bloom's target
        #expect(engine.phase == .overrunning)
        #expect(engine.currentStepIndex == 0) // did NOT move on by itself
        #expect(engine.remainingInStep == 0)
        #expect(engine.overrunInStep == 0)
        #expect(rec.events.last == .reachedTarget(index: 0, step: v60().steps[0]))

        engine.advance(by: 7) // a slow pour keeps going
        #expect(engine.phase == .overrunning)
        #expect(engine.overrunInStep == 7)
        // Overrun is real time but not *plan* progress.
        #expect(engine.totalElapsed == 45)
        #expect(engine.totalWallElapsed == 52)

        engine.advanceStep() // user finishes the pour and taps
        #expect(engine.currentStepIndex == 1)
        #expect(engine.phase == .running)
        #expect(engine.overrunInStep == nil)
    }

    @Test("a coarse tick halts at the first soft target rather than skipping ahead")
    func coarseTickHaltsAtSoftTarget() {
        let engine = BrewTimerEngine(timeline: v60())
        engine.start()
        engine.advance(by: 10_000) // way past every timed step
        // The bloom holds it: only the bloom's 45s counts as plan progress,
        // and the rest of the tick is overrun on that same step.
        #expect(engine.phase == .overrunning)
        #expect(engine.currentStepIndex == 0)
        #expect(engine.totalElapsed == 45)
        #expect(engine.totalWallElapsed == 10_000)
    }

    // MARK: Manual steps

    @Test("manual step holds the plan but the master clock keeps running")
    func manualStepHolds() {
        let engine = BrewTimerEngine(timeline: v60())
        let rec = Recorder(); rec.attach(to: engine)
        runV60ToDrawdown(engine)

        #expect(engine.phase == .awaitingManualAdvance)
        #expect(engine.currentStep == .drawdown(untilDripsStop: true))
        #expect(engine.totalElapsed == 135) // bloom45 + pour45 + pour45

        engine.advance(by: 999) // the plan does not move…
        #expect(engine.totalElapsed == 135)
        #expect(engine.phase == .awaitingManualAdvance)
        #expect(engine.totalWallElapsed == 135 + 999) // …but the brew does

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

        engine.advance(by: 30); engine.advanceStep()  // bloom (hands-on)
        engine.advance(by: 15); engine.advanceStep()  // fill pour (hands-on)
        engine.advance(by: 240)                       // steep (unattended)
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
        #expect(engine.totalWallElapsed == 20) // the master clock stops too

        engine.resume()
        engine.advance(by: 25) // reaches the 45s bloom target
        #expect(engine.phase == .overrunning)
        #expect(engine.totalWallElapsed == 45)
    }

    @Test("pausing an overrun resumes back into the overrun, not the next step")
    func pauseResumeFromOverrun() {
        let engine = BrewTimerEngine(timeline: v60())
        engine.start()
        engine.advance(by: 50) // 45s bloom + 5s over
        #expect(engine.phase == .overrunning)

        engine.pause()
        engine.advance(by: 100) // ignored
        #expect(engine.overrunInStep == nil) // not overrunning *right now*
        engine.resume()

        #expect(engine.phase == .overrunning)
        #expect(engine.overrunInStep == 5)
        #expect(engine.currentStepIndex == 0)
    }

    @Test("a manual hold can be paused, stopping the master clock")
    func pauseDuringManualHold() {
        let engine = BrewTimerEngine(timeline: v60())
        runV60ToDrawdown(engine)
        #expect(engine.phase == .awaitingManualAdvance)

        engine.pause()
        engine.advance(by: 500)
        #expect(engine.totalWallElapsed == 135)

        engine.resume()
        #expect(engine.phase == .awaitingManualAdvance)
        engine.advance(by: 10)
        #expect(engine.totalWallElapsed == 145)
    }

    // MARK: Finish (the "Done" button)

    @Test("finish ends the brew mid-way and keeps the elapsed time")
    func finishMidBrew() {
        let engine = BrewTimerEngine(timeline: v60())
        let rec = Recorder(); rec.attach(to: engine)
        engine.start()
        engine.advance(by: 60) // mid-bloom-overrun

        engine.finish()
        #expect(engine.phase == .completed)
        #expect(engine.isFinished)
        #expect(engine.totalWallElapsed == 60) // the honest brew duration
        #expect(rec.events.last == .completed)
        #expect(rec.events.filter { $0 == .completed }.count == 1)

        engine.advance(by: 100) // the clock is stopped for good
        #expect(engine.totalWallElapsed == 60)
    }

    @Test("finish is a no-op before the brew starts and after it ends")
    func finishIgnoredWhenNotRunning() {
        let engine = BrewTimerEngine(timeline: v60())
        let rec = Recorder(); rec.attach(to: engine)

        engine.finish() // never started
        #expect(engine.phase == .idle)
        #expect(rec.events.isEmpty)

        engine.start()
        engine.finish()
        engine.finish() // second tap must not emit a second completion
        #expect(rec.events.filter { $0 == .completed }.count == 1)
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
        #expect(engine.totalWallElapsed == 0)

        engine.start() // rerunnable
        #expect(engine.phase == .running)
    }

    // MARK: Step classification

    @Test("hands-on steps use soft targets; unattended waits do not")
    func softTargetClassification() {
        // Hands-on: you are at the scale and can run long.
        #expect(BrewStep.bloom(targetGrams: 40, duration: 45).usesSoftTarget)
        #expect(BrewStep.pour(pourNumber: 1, targetCumulativeGrams: 164, duration: 45).usesSoftTarget)
        #expect(BrewStep.stir(duration: 10).usesSoftTarget)

        // Unattended: the clock is the instruction and you may have walked away.
        #expect(!BrewStep.steep(duration: 240).usesSoftTarget)
        #expect(!BrewStep.wait(duration: 30).usesSoftTarget)

        // Already user-advanced — there is no target to overrun.
        #expect(!BrewStep.plunge.usesSoftTarget)
        #expect(!BrewStep.drawdown(untilDripsStop: true).usesSoftTarget)
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
