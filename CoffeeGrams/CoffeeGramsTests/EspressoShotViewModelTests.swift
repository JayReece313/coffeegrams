//
//  EspressoShotViewModelTests.swift
//  CoffeeGramsTests
//

import Testing
@testable import CoffeeGrams
import CoffeeGramsCore

@MainActor
@Suite("EspressoShotViewModel")
struct EspressoShotViewModelTests {

    private func makeVM(clock: FakeClock) -> EspressoShotViewModel {
        let target = BrewTimelineBuilder.buildEspressoTarget(doseGrams: 18, ratio: 2)
        return EspressoShotViewModel(target: target, clock: clock)
    }

    @Test("target reflects an 18 g, 1:2 shot")
    func target() {
        let vm = makeVM(clock: FakeClock())
        #expect(vm.target.targetYieldGrams == 36)
        #expect(vm.target.shotTimeRange == 25...30)
        #expect(!vm.hasStarted)
    }

    @Test("elapsed tracks the clock while running")
    func elapsedTracks() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()
        clock.advance(27)
        vm.tickOnce()
        #expect(vm.elapsedSeconds == 27)
        #expect(vm.isRunning)
        #expect(vm.hasStarted)
    }

    @Test("timing state is amber early, green in-window, red late")
    func timingState() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()

        clock.advance(20); vm.tickOnce()
        #expect(vm.timingState == .tooEarly)

        clock.advance(7); vm.tickOnce() // 27s — inside 25...30
        #expect(vm.timingState == .onTarget)

        clock.advance(8); vm.tickOnce() // 35s — past the window
        #expect(vm.timingState == .tooLate)
    }

    @Test("stop halts the clock; reset clears it")
    func stopAndReset() {
        let clock = FakeClock()
        let vm = makeVM(clock: clock)
        vm.start()
        clock.advance(28); vm.tickOnce()
        vm.stop()
        #expect(!vm.isRunning)
        #expect(vm.hasStarted)          // still shows the 28s result
        #expect(vm.elapsedSeconds == 28)

        clock.advance(50); vm.tickOnce() // ignored — stopped
        #expect(vm.elapsedSeconds == 28)

        vm.reset()
        #expect(vm.elapsedSeconds == 0)
        #expect(!vm.hasStarted)
    }
}
