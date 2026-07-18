//
//  GuidedBrewViewModelTests.swift
//  CoffeeGramsTests
//
//  Drives the guided-brew view model with a fake clock so a full brew is
//  verified instantly. The tests are synchronous, so the VM's real-time ticking
//  Task never interleaves — we advance the clock and call `tickOnce()` by hand.
//

import Testing
@testable import CoffeeGrams
import CoffeeGramsCore

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

    @Test("advancing the clock counts the step down and moves to the next")
    func countsDown() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()

        clock.advance(20)
        vm.tickOnce()
        #expect(vm.remainingSeconds == 25)
        #expect(vm.currentStepIndex == 0)

        clock.advance(25) // finishes the 45s bloom exactly
        vm.tickOnce()
        #expect(vm.currentStepIndex == 1) // now on pour 1
        #expect(vm.remainingSeconds == 45)
    }

    @Test("a manual step (drawdown) holds until Done, then completes the brew")
    func manualStepThenComplete() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()

        clock.advance(135) // bloom + pour1 + pour2
        vm.tickOnce()
        #expect(vm.isAwaitingManualAdvance)

        clock.advance(1000) // time no longer matters on a manual step
        vm.tickOnce()
        #expect(vm.isAwaitingManualAdvance)

        vm.advanceStep() // user taps Done
        #expect(vm.isFinished)
        #expect(vm.fractionComplete == 1)
    }

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
        #expect(vm.currentStepIndex == 1)
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
