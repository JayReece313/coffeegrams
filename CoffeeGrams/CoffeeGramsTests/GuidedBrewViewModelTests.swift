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

    /// Every v60 timed step is hands-on, so each holds at its target and needs
    /// a tap. Walks the brew to the drawdown, taking `overrunPerStep` extra
    /// seconds on each one.
    private func runToDrawdown(
        _ vm: GuidedBrewViewModel,
        clock: FakeClock,
        overrunPerStep: TimeInterval = 0
    ) {
        vm.start()
        for _ in 0..<3 {
            clock.advance(45 + overrunPerStep)
            vm.tickOnce()
            vm.advanceStep()
        }
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

    @Test("a hands-on step holds at its target and counts up until tapped")
    func softTargetHolds() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()

        clock.advance(45) // finishes the 45s bloom exactly
        vm.tickOnce()
        #expect(vm.isOverrunning)
        #expect(vm.currentStepIndex == 0) // did NOT move on by itself
        #expect(vm.overrunSeconds == 0)
        #expect(vm.advanceTitle == "Next")

        clock.advance(7) // a slow pour keeps going
        vm.tickOnce()
        #expect(vm.overrunSeconds == 7)
        #expect(vm.isOverrunning)

        vm.advanceStep() // user taps Next
        #expect(vm.currentStepIndex == 1) // now on pour 1
        #expect(vm.isRunning)
        #expect(vm.remainingSeconds == 45)
        #expect(vm.advanceTitle == nil)
    }

    @Test("a manual step (drawdown) holds until Done, then completes the brew")
    func manualStepThenComplete() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        runToDrawdown(vm, clock: clock)
        #expect(vm.isAwaitingManualAdvance)
        #expect(vm.advanceTitle == "Done")

        clock.advance(1000) // the plan does not move on a manual step…
        vm.tickOnce()
        #expect(vm.isAwaitingManualAdvance)

        vm.advanceStep() // user taps Done
        #expect(vm.isFinished)
        #expect(vm.fractionComplete == 1)
    }

    // MARK: The master clock

    @Test("the master clock counts wall time through overruns and manual holds")
    func masterClockRunsThroughHolds() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        // 5s over on each of the three pours.
        runToDrawdown(vm, clock: clock, overrunPerStep: 5)
        #expect(vm.totalElapsedSeconds == 150) // 135 planned + 15 overrun

        clock.advance(20) // …and it keeps running while the bed drains
        vm.tickOnce()
        #expect(vm.totalElapsedSeconds == 170)
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

    @Test("planned vs actual: a brew run to time reports no delta")
    func plannedMatchesActualOnTime() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        runToDrawdown(vm, clock: clock)
        vm.advanceStep() // finish the drawdown immediately

        #expect(vm.isFinished)
        #expect(vm.plannedSeconds == 135)
        #expect(vm.actualSeconds == 135)
    }

    @Test("planned vs actual: slow pours show up as extra actual time")
    func slowPoursExtendActual() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        runToDrawdown(vm, clock: clock, overrunPerStep: 10)
        vm.advanceStep()

        #expect(vm.plannedSeconds == 135)
        #expect(vm.actualSeconds == 165) // 30s of overrun, honestly logged
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
        clock.advance(25) // reaches the bloom's target
        vm.tickOnce()
        #expect(vm.isOverrunning)
        #expect(vm.currentStepIndex == 0)
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
