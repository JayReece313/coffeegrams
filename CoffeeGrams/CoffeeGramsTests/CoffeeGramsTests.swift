//
//  CoffeeGramsTests.swift
//  CoffeeGramsTests
//
//  Unit tests for the app layer's presentation logic (the ViewModels).
//  The brewing math itself is tested in the CoffeeGramsCore package.
//

import Testing
@testable import CoffeeGrams
import CoffeeGramsCore

// The ViewModel is main-actor isolated (UI state), so its tests must run on the
// main actor too. Under Swift 6's strict concurrency this is required, not
// optional — the compiler won't let a nonisolated test touch main-actor state.
extension AppTests {
  @MainActor
  @Suite("CalculatorViewModel")
  struct CalculatorViewModelTests {

    @Test("defaults to V60 at its default ratio, dose-first")
    func defaults() {
        let vm = CalculatorViewModel()
        #expect(vm.method == .v60)
        #expect(vm.ratio == 16)
        #expect(vm.mode == .doseFirst)
    }

    @Test("dose-first result is water = dose × ratio")
    func doseFirst() {
        let vm = CalculatorViewModel(method: .v60, doseGrams: 18)
        #expect(vm.resultGrams == 288)   // 18 × 16
        #expect(vm.resultLabel == "Water")
    }

    @Test("selecting a method resets the ratio to that method's default")
    func selectMethodResetsRatio() {
        let vm = CalculatorViewModel()
        vm.selectMethod(.frenchPress)
        #expect(vm.method == .frenchPress)
        #expect(vm.ratio == 15)

        vm.selectMethod(.espresso)
        #expect(vm.ratio == 2)
        #expect(vm.ratioRange == 1...3)
    }

    @Test("ratio label formats as 1:N")
    func ratioLabel() {
        let vm = CalculatorViewModel(method: .v60)
        #expect(vm.ratioLabel == "1:16")

        vm.selectMethod(.espresso)
        #expect(vm.ratioLabel == "1:2")

        vm.ratio = 2.5
        #expect(vm.ratioLabel == "1:2.5")
    }

    @Test("espresso output is labelled Yield, not Water")
    func espressoYieldLabel() {
        let vm = CalculatorViewModel(method: .espresso, doseGrams: 18)
        #expect(vm.waterOrYieldLabel == "Yield")
        #expect(vm.resultGrams == 36)     // 18 × 2
    }

    @Test("yield-first result is dose = yield / ratio")
    func yieldFirst() {
        let vm = CalculatorViewModel(method: .v60, targetYieldGrams: 320)
        vm.mode = .yieldFirst
        #expect(vm.resultGrams == 20)     // 320 / 16
        #expect(vm.resultLabel == "Coffee")
    }

    @Test("ratio step is finer for espresso than for brewed methods")
    func ratioStep() {
        let vm = CalculatorViewModel(method: .v60)
        #expect(vm.ratioStep == 0.5)
        vm.selectMethod(.espresso)
        #expect(vm.ratioStep == 0.25)
    }

    @Test("applying a preset sets dose + clamped ratio and goes dose-first")
    func applyPreset() {
        let vm = CalculatorViewModel(method: .aeropress)
        vm.mode = .yieldFirst

        vm.applyPreset(doseGrams: 11, ratio: 18)
        #expect(vm.doseGrams == 11)
        #expect(vm.ratio == 18)
        #expect(vm.mode == .doseFirst)

        // A preset ratio outside the method range is clamped (AeroPress 12–18).
        vm.applyPreset(doseGrams: 15, ratio: 25)
        #expect(vm.ratio == 18)
    }

    @Test("AeroPress offers presets; other methods offer none")
    func presetsPerMethod() {
        #expect(BrewPresets.presets(for: .aeropress).count == 2)
        #expect(BrewPresets.presets(for: .v60).isEmpty)
        #expect(BrewPresets.presets(for: .espresso).isEmpty)
    }
  }
}
