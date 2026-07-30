//
//  GuidedBrewViewModelTests.swift
//  CoffeeGramsTests
//
//  Drives the guided-brew view model with a fake clock so a full brew is
//  verified instantly. The tests are synchronous, so the VM's real-time ticking
//  Task never interleaves — we advance the clock and call `tickOnce()` by hand.
//

import Foundation
import Testing
@testable import CoffeeGrams
import CoffeeGramsCore

extension AppTests {
  @MainActor
  @Suite("GuidedBrewViewModel")
  struct GuidedBrewViewModelTests {

    /// V60: bloom(45) + pour1(45) + pour2(45) + drawdown(manual).
    private func makeVM(clock: FakeClock) -> GuidedBrewViewModel {
        let timeline = BrewTimelineBuilder.buildPulsePourTimeline(
            profile: .v60, doseGrams: 18, ratio: 16
        )
        return GuidedBrewViewModel(timeline: timeline, clock: clock, haptics: NoHaptics())
    }

    @Test("starts idle showing the first step's duration")
    func startsIdle() {
        let vm = makeVM(clock: FakeClock())
        #expect(vm.isIdle)
        #expect(vm.remainingSeconds == 45)
    }

    @Test("start begins running on the first step")
    func startRuns() {
        let vm = makeVM(clock: FakeClock())
        vm.start()
        #expect(vm.isRunning)
        #expect(vm.currentStepIndex == 0)
        #expect(vm.remainingSeconds == 45)
    }

    /// Run the brew to its drawdown. Intermediate steps flow into each other
    /// with no taps, exactly as in 1.0 — 135s covers bloom + pour 1 + pour 2.
    private func runToDrawdown(_ vm: GuidedBrewViewModel, clock: FakeClock) {
        vm.start()
        clock.advance(135)
        vm.tickOnce()
    }

    @Test("advancing the clock counts the step down")
    func countsDown() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()

        clock.advance(20)
        vm.tickOnce()
        #expect(vm.remainingSeconds == 25)
        #expect(vm.currentStepIndex == 0)
    }

    @Test("intermediate steps flow into the next one with no tap")
    func intermediateStepsAutoAdvance() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()

        clock.advance(45) // finishes the 45s bloom exactly
        vm.tickOnce()
        #expect(vm.currentStepIndex == 1) // straight on to pour 1
        #expect(vm.isRunning)
        #expect(vm.remainingSeconds == 45)
        #expect(vm.overrunSeconds == nil) // no overrun on an intermediate step
        #expect(vm.advanceTitle == nil)   // and nothing to tap

        clock.advance(45)
        vm.tickOnce()
        #expect(vm.currentStepIndex == 2) // and on to pour 2
        #expect(vm.isRunning)
    }

    @Test("the final step counts up and offers a single Done")
    func finalStepCountsUp() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        runToDrawdown(vm, clock: clock)

        #expect(vm.isAwaitingManualAdvance)
        #expect(vm.isOnFinalStep)
        #expect(vm.overrunSeconds == 0) // just arrived
        #expect(vm.advanceTitle == "Done")
        // Done already ends the brew, so no separate End Brew beside it.
        #expect(vm.stepActionEndsBrew)

        clock.advance(12)
        vm.tickOnce()
        #expect(vm.overrunSeconds == 12)
        #expect(vm.isAwaitingManualAdvance)

        vm.resolveCurrentStep() // user taps Done
        #expect(vm.isFinished)
        #expect(vm.fractionComplete == 1)
        #expect(vm.actualSeconds == 147) // 135 planned + 12 on the drawdown
    }

    // MARK: The master clock

    @Test("the master clock keeps counting on the final step")
    func masterClockRunsThroughHolds() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        runToDrawdown(vm, clock: clock)
        #expect(vm.totalElapsedSeconds == 135)

        clock.advance(20) // it keeps running while the bed drains
        vm.tickOnce()
        #expect(vm.totalElapsedSeconds == 155)
    }

    @Test("the master clock stops while paused")
    func masterClockStopsWhilePaused() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()

        clock.advance(20)
        vm.tickOnce()
        #expect(vm.totalElapsedSeconds == 20)

        vm.pause()
        clock.advance(300)
        vm.tickOnce()
        #expect(vm.totalElapsedSeconds == 20)

        vm.resume()
        clock.advance(10)
        vm.tickOnce()
        #expect(vm.totalElapsedSeconds == 30)
    }

    @Test("planned vs actual: a brew ended on time reports no delta")
    func plannedMatchesActualOnTime() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        runToDrawdown(vm, clock: clock)
        vm.resolveCurrentStep() // finish the drawdown immediately

        #expect(vm.isFinished)
        #expect(vm.plannedSeconds == 135)
        #expect(vm.actualSeconds == 135)
    }

    @Test("planned vs actual: a long drawdown shows up as extra actual time")
    func longFinalStepExtendsActual() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        runToDrawdown(vm, clock: clock)

        clock.advance(30) // the bed takes a while to drain
        vm.tickOnce()
        vm.resolveCurrentStep()

        #expect(vm.plannedSeconds == 135)
        #expect(vm.actualSeconds == 165) // 30s over, honestly logged
    }

    // MARK: Pause / resume

    @Test("pause freezes the countdown; resume continues")
    func pauseResume() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()

        clock.advance(20)
        vm.tickOnce()
        vm.pause()
        #expect(vm.isPaused)

        clock.advance(100) // ignored while paused
        vm.tickOnce()
        #expect(vm.remainingSeconds == 25)

        vm.resume()
        clock.advance(25) // finishes the bloom
        vm.tickOnce()
        #expect(vm.isRunning)
        #expect(vm.currentStepIndex == 1)
    }

    @Test("pausing the final step keeps its count-up on screen")
    func pausedFinalStepKeepsReadout() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        runToDrawdown(vm, clock: clock)

        clock.advance(12)
        vm.tickOnce()
        #expect(vm.overrunSeconds == 12)

        vm.pause()
        // The bug this guards: if overrunSeconds goes nil here the view falls
        // through to the countdown, and a manual step has no duration left to
        // count — so the screen would read "0:00" mid-drawdown.
        #expect(vm.overrunSeconds == 12)
        #expect(vm.isShowingOverrun)

        clock.advance(60) // paused — the clock is frozen
        vm.tickOnce()
        #expect(vm.overrunSeconds == 12)
    }

    @Test("togglePause flips between pause and resume")
    func togglePauseFlips() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()

        vm.togglePause()
        #expect(vm.isPaused)
        vm.togglePause()
        #expect(vm.isRunning)
    }

    // MARK: End Brew

    @Test("finish ends the brew mid-way and keeps the elapsed time")
    func finishMidBrew() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()

        clock.advance(72)
        vm.tickOnce()
        vm.finish()

        #expect(vm.isFinished)
        #expect(vm.actualSeconds == 72)

        clock.advance(50) // the clock is stopped for good
        vm.tickOnce()
        #expect(vm.actualSeconds == 72)
    }

    @Test("reset returns to idle")
    func reset() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()
        clock.advance(50)
        vm.tickOnce()
        vm.reset()
        #expect(vm.isIdle)
        #expect(vm.currentStepIndex == 0)
    }
  }
}
