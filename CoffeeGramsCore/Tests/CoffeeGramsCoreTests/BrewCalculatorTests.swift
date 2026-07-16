import Testing
@testable import CoffeeGramsCore

/// M2 gate: the brewing math. Every assertion here is a number the user will
/// read off the app while standing at their scale, so the coverage is
/// deliberately exhaustive — canonical examples, every method's default,
/// both directions, boundaries, and the invalid-input guards.
@Suite("BrewCalculator")
struct BrewCalculatorTests {

    private let epsilon = 1e-9

    // MARK: Dose-first

    @Test("canonical example: 16 g at 1:16 = 256 g water")
    func canonicalWater() {
        #expect(BrewCalculator.waterGrams(doseGrams: 16, ratio: 16) == 256)
    }

    @Test("water = dose × ratio across a spread of values")
    func waterScales() {
        #expect(BrewCalculator.waterGrams(doseGrams: 20, ratio: 15) == 300)
        #expect(BrewCalculator.waterGrams(doseGrams: 11, ratio: 18) == 198) // Hoffmann 11:200-ish
        #expect(BrewCalculator.waterGrams(doseGrams: 18, ratio: 2) == 36)   // espresso 18→36
        #expect(BrewCalculator.waterGrams(doseGrams: 100, ratio: 5) == 500) // cold brew concentrate
    }

    @Test("water for each method at its default ratio", arguments: BrewMethodProfile.all)
    func waterAtDefaultRatio(profile: BrewMethodProfile) {
        let dose = 18.0
        let expected = dose * profile.defaultRatio
        let actual = BrewCalculator.waterGrams(doseGrams: dose, ratio: profile.defaultRatio)
        #expect(abs(actual - expected) < epsilon)
    }

    // MARK: Yield-first

    @Test("yield-first inverts dose-first: 256 g yield at 1:16 = 16 g dose")
    func yieldFirstInverts() {
        let dose = BrewCalculator.doseGrams(targetYieldGrams: 256, ratio: 16, method: .v60)
        #expect(abs(dose - 16) < epsilon)
    }

    @Test("round-trip dose → water → dose is stable", arguments: BrewMethod.allCases)
    func roundTrip(method: BrewMethod) {
        let startDose = 17.0
        let ratio = BrewMethodProfile.profile(for: method).defaultRatio
        let water = BrewCalculator.waterGrams(doseGrams: startDose, ratio: ratio)
        let backToDose = BrewCalculator.doseGrams(targetYieldGrams: water, ratio: ratio, method: method)
        // v1 uses the simple relationship for every method, so the round trip
        // is exact. When absorption modelling lands in v2, immersion methods
        // will intentionally diverge and this test should be updated.
        #expect(abs(backToDose - startDose) < epsilon)
    }

    @Test("yield-first for each method equals yield / ratio (v1 simplification)",
          arguments: BrewMethod.allCases)
    func yieldFirstSimplification(method: BrewMethod) {
        let ratio = 16.0
        let yield = 480.0
        let dose = BrewCalculator.doseGrams(targetYieldGrams: yield, ratio: ratio, method: method)
        #expect(abs(dose - (yield / ratio)) < epsilon)
    }

    // MARK: Invalid input guards

    @Test("zero and negative dose yield zero water, never negative")
    func nonPositiveDose() {
        #expect(BrewCalculator.waterGrams(doseGrams: 0, ratio: 16) == 0)
        #expect(BrewCalculator.waterGrams(doseGrams: -5, ratio: 16) == 0)
    }

    @Test("non-positive ratio is guarded (no divide-by-zero / NaN)")
    func nonPositiveRatio() {
        #expect(BrewCalculator.waterGrams(doseGrams: 18, ratio: 0) == 0)
        #expect(BrewCalculator.doseGrams(targetYieldGrams: 300, ratio: 0, method: .v60) == 0)
        let d = BrewCalculator.doseGrams(targetYieldGrams: 300, ratio: -2, method: .v60)
        #expect(d == 0)
    }

    @Test("zero target yield yields zero dose")
    func zeroYield() {
        #expect(BrewCalculator.doseGrams(targetYieldGrams: 0, ratio: 16, method: .v60) == 0)
    }

    // MARK: Ratio clamping

    @Test("clampRatio pins values into the method range", arguments: BrewMethodProfile.all)
    func clampWithinRange(profile: BrewMethodProfile) {
        let range = profile.ratioRange
        #expect(BrewCalculator.clampRatio(range.lowerBound - 5, for: profile.method) == range.lowerBound)
        #expect(BrewCalculator.clampRatio(range.upperBound + 5, for: profile.method) == range.upperBound)
        #expect(BrewCalculator.clampRatio(profile.defaultRatio, for: profile.method) == profile.defaultRatio)
    }

    @Test("clampRatio leaves in-range espresso ristretto/lungo untouched")
    func clampEspressoBand() {
        #expect(BrewCalculator.clampRatio(1.0, for: .espresso) == 1.0)   // ristretto edge
        #expect(BrewCalculator.clampRatio(2.5, for: .espresso) == 2.5)   // lungo-ish
        #expect(BrewCalculator.clampRatio(0.5, for: .espresso) == 1.0)   // clamped up
        #expect(BrewCalculator.clampRatio(4.0, for: .espresso) == 3.0)   // clamped down
    }
}
