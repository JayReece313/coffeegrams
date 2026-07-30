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

    /// A timeline whose **last** step is timed rather than manual, to exercise
    /// the final-step hold on its own terms. (No shipping method ends this way
    /// today — all four end on a plunge or drawdown.)
    private func timedFinalStep() -> BrewTimeline {
        BrewTimeline(
            method: .v60,
            steps: [.bloom(targetGrams: 40, duration: 45), .steep(duration: 60)],
            totalWaterGrams: 288
        )
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

    @Test("intermediate steps flow into the next one with no tap")
    func intermediateStepsAutoAdvance() {
        let engine = BrewTimerEngine(timeline: v60())
        let rec = Recorder(); rec.attach(to: engine)
        engine.start()

        engine.advance(by: 45) // the bloom's full duration
        #expect(engine.currentStepIndex == 1) // straight on to pour 1
        #expect(engine.elapsedInStep == 0)
        #expect(engine.phase == .running)
        #expect(rec.events.suffix(2) == [
            .stepCompleted(index: 0, step: v60().steps[0]),
            .stepBegan(index: 1, step: v60().steps[1]),
        ])
        // An intermediate step never announces an overrun; it simply ends.
        #expect(!rec.events.contains(.reachedTarget(index: 0, step: v60().steps[0])))

        engine.advance(by: 45)
        #expect(engine.currentStepIndex == 2) // and on to pour 2
        #expect(engine.phase == .running)
    }

    @Test("a single coarse tick crosses every timed step and stops on the last")
    func coarseTickReachesFinalStep() {
        let engine = BrewTimerEngine(timeline: v60())
        engine.start()
        engine.advance(by: 10_000) // way past every timed step
        // bloom45 + pour45 + pour45 = 135 of plan, then the drawdown holds.
        #expect(engine.totalElapsed == 135)
        #expect(engine.phase == .awaitingManualAdvance)
        #expect(engine.currentStep == .drawdown(untilDripsStop: true))
        #expect(engine.isOnFinalStep)
        // The leftover is still real time, spent on that final step — every
        // second of it past the plan.
        #expect(engine.totalWallElapsed == 10_000)
        #expect(engine.overrunInStep == engine.totalWallElapsed - engine.totalElapsed)
    }

    // MARK: The final step holds

    @Test("a timed final step holds at its target and counts up")
    func timedFinalStepHoldsAndCountsUp() {
        let engine = BrewTimerEngine(timeline: timedFinalStep())
        let rec = Recorder(); rec.attach(to: engine)
        engine.start()

        engine.advance(by: 45) // bloom auto-advances into the final steep
        #expect(engine.currentStepIndex == 1)
        #expect(engine.phase == .running)

        engine.advance(by: 60) // the final step reaches its target
        #expect(engine.phase == .overrunning)
        #expect(engine.currentStepIndex == 1) // does NOT complete on its own
        #expect(engine.remainingInStep == 0)
        #expect(engine.overrunInStep == 0)
        #expect(rec.events.last == .reachedTarget(index: 1, step: .steep(duration: 60)))

        engine.advance(by: 7)
        #expect(engine.overrunInStep == 7)
        // Overrun is real time but not *plan* progress.
        #expect(engine.totalElapsed == 105)
        #expect(engine.totalWallElapsed == 112)

        engine.advanceStep() // user ends the brew
        #expect(engine.phase == .completed)
        #expect(engine.overrunInStep == nil)
    }

    @Test("a manual final step counts every second as over-plan time")
    func manualFinalStepCountsUp() {
        let engine = BrewTimerEngine(timeline: v60())
        engine.start()
        engine.advance(by: 135) // straight through to the drawdown
        #expect(engine.phase == .awaitingManualAdvance)
        #expect(engine.overrunInStep == 0) // just arrived, nothing over yet

        engine.advance(by: 12)
        // A manual step has no target, so all 12s are past the plan — and
        // because everything before it ran exactly to time, this is also
        // precisely how far the whole brew is over.
        #expect(engine.overrunInStep == 12)
        #expect(engine.totalWallElapsed - engine.totalElapsed == 12)
    }

    // MARK: Manual steps

    @Test("manual step holds the plan but the master clock keeps running")
    func manualStepHolds() {
        let engine = BrewTimerEngine(timeline: v60())
        let rec = Recorder(); rec.attach(to: engine)
        engine.start()
        engine.advance(by: 135) // bloom + pour 1 + pour 2, no taps needed

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

        engine.advance(by: 285) // bloom30 + fill15 + steep240, all automatic
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
        engine.advance(by: 25) // finishes the 45s bloom
        #expect(engine.currentStepIndex == 1)
        #expect(engine.phase == .running)
        #expect(engine.totalWallElapsed == 45)
    }

    @Test("pausing an overrun resumes back into the overrun, not the next step")
    func pauseResumeFromOverrun() {
        let engine = BrewTimerEngine(timeline: timedFinalStep())
        engine.start()
        engine.advance(by: 110) // bloom45 + steep60 + 5s over on the final step
        #expect(engine.phase == .overrunning)

        engine.pause()
        engine.advance(by: 100) // ignored
        #expect(engine.overrunInStep == nil) // not overrunning *right now*
        engine.resume()

        #expect(engine.phase == .overrunning)
        #expect(engine.overrunInStep == 5)
        #expect(engine.currentStepIndex == 1)
    }

    @Test("a manual hold can be paused, stopping the master clock")
    func pauseDuringManualHold() {
        let engine = BrewTimerEngine(timeline: v60())
        engine.start()
        engine.advance(by: 135)
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

    // MARK: Final-step detection

    @Test("only the timeline's last step counts as final")
    func finalStepDetection() {
        let engine = BrewTimerEngine(timeline: v60()) // 4 steps
        engine.start()
        #expect(!engine.isOnFinalStep)

        engine.advance(by: 90) // through bloom and pour 1
        #expect(engine.currentStepIndex == 2)
        #expect(!engine.isOnFinalStep)

        engine.advance(by: 45) // on to the drawdown
        #expect(engine.currentStepIndex == 3)
        #expect(engine.isOnFinalStep)
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
