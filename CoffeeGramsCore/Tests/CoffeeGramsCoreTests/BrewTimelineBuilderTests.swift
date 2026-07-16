import Foundation
import Testing
@testable import CoffeeGramsCore

/// M3 gate: timeline generation (spec §4.2–4.6). Asserts step shape, water
/// targets, bloom amounts, cadence, the espresso window, and the cold-brew
/// notify time.
@Suite("BrewTimelineBuilder")
struct BrewTimelineBuilderTests {

    private let epsilon = 1e-9

    // Small helpers to read a step's associated values in assertions.
    private func cumulative(of step: BrewStep) -> Double? {
        if case let .pour(_, target, _) = step { return target }
        return nil
    }
    private func bloomTarget(of step: BrewStep) -> Double? {
        if case let .bloom(target, _) = step { return target }
        return nil
    }

    // MARK: V60 / Chemex

    @Test("V60 timeline: bloom + 2 pours + drawdown, cumulative lands on total")
    func v60Shape() {
        let dose = 20.0, ratio = 16.0
        let t = BrewTimelineBuilder.buildPulsePourTimeline(
            profile: .v60, doseGrams: dose, ratio: ratio
        )
        #expect(t.method == .v60)
        #expect(t.totalWaterGrams == 320)
        #expect(t.steps.count == 4) // bloom + 2 pours + drawdown

        #expect(bloomTarget(of: t.steps[0]) == dose * 2.25) // 45 g

        // Pours are evenly sized and the last lands exactly on total water.
        let pourTargets = t.steps.compactMap(cumulative)
        #expect(pourTargets.count == 2)
        #expect(abs(pourTargets[0] - 182.5) < epsilon)
        #expect(abs(pourTargets[1] - 320) < epsilon)

        // Last step is a user-ended drawdown.
        #expect(t.steps.last == .drawdown(untilDripsStop: true))
        #expect(t.steps.last?.requiresManualAdvance == true)
    }

    @Test("V60 pour cadence is 45s; Chemex is spaced wider at 60s")
    func pourCadence() {
        let v60 = BrewTimelineBuilder.buildPulsePourTimeline(profile: .v60, doseGrams: 18, ratio: 16)
        let chemex = BrewTimelineBuilder.buildPulsePourTimeline(profile: .chemex, doseGrams: 18, ratio: 16)
        // Every pour uses the profile's interval as its duration.
        for step in v60.steps { if case .pour = step { #expect(step.duration == 45) } }
        for step in chemex.steps { if case .pour = step { #expect(step.duration == 60) } }
        #expect(bloomTarget(of: chemex.steps[0]) == 18 * 2.5)
    }

    // MARK: French Press

    @Test("French Press: bloom, fill, 4:00 steep, plunge")
    func frenchPressShape() {
        let dose = 30.0, ratio = 15.0
        let t = BrewTimelineBuilder.buildFrenchPressTimeline(doseGrams: dose, ratio: ratio)
        #expect(t.totalWaterGrams == 450)
        #expect(t.steps.count == 4)
        #expect(bloomTarget(of: t.steps[0]) == dose * 2.0) // 60 g
        #expect(cumulative(of: t.steps[1]) == 450)         // fill to full
        #expect(t.steps[2] == .steep(duration: 240))       // 4:00
        #expect(t.steps[3] == .plunge)
        #expect(t.steps[3].requiresManualAdvance == true)
    }

    // MARK: AeroPress

    @Test("AeroPress: pour, 2:00 steep, stir, settle, plunge — no bloom")
    func aeroPressShape() {
        let t = BrewTimelineBuilder.buildAeroPressTimeline(doseGrams: 11, ratio: 18)
        #expect(abs(t.totalWaterGrams - 198) < epsilon)
        #expect(t.steps.count == 5)
        #expect(t.steps.contains { if case .bloom = $0 { true } else { false } } == false)
        #expect(t.steps[1] == .steep(duration: 120))
        #expect(t.steps[2] == .stir(duration: 10))
        #expect(t.steps[3] == .wait(duration: 30))
        #expect(t.steps[4] == .plunge)
    }

    // MARK: Cold Brew

    @Test("Cold brew concentrate = 1:5, ready-to-drink = 1:8")
    func coldBrewRatios() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let conc = BrewTimelineBuilder.buildColdBrewPlan(doseGrams: 100, style: .concentrate, now: start)
        let rtd = BrewTimelineBuilder.buildColdBrewPlan(doseGrams: 100, style: .readyToDrink, now: start)
        #expect(conc.waterGrams == 500)
        #expect(rtd.waterGrams == 800)
    }

    @Test("Cold brew notify time = start + steepHours, hours clamped to 12–24")
    func coldBrewNotify() {
        let start = Date(timeIntervalSince1970: 0)
        let plan = BrewTimelineBuilder.buildColdBrewPlan(
            doseGrams: 100, style: .concentrate, steepHours: 16, now: start
        )
        #expect(plan.steepHours == 16)
        #expect(plan.notifyAt == start.addingTimeInterval(16 * 3600))

        // Out-of-band requests are clamped, not honoured verbatim.
        let tooShort = BrewTimelineBuilder.buildColdBrewPlan(
            doseGrams: 100, style: .concentrate, steepHours: 2, now: start
        )
        #expect(tooShort.steepHours == 12)
        let tooLong = BrewTimelineBuilder.buildColdBrewPlan(
            doseGrams: 100, style: .concentrate, steepHours: 48, now: start
        )
        #expect(tooLong.steepHours == 24)
    }

    // MARK: Espresso

    @Test("Espresso 18 g at 1:2 → 36 g yield, 25–30s window")
    func espressoNormale() {
        let target = BrewTimelineBuilder.buildEspressoTarget(doseGrams: 18, ratio: 2)
        #expect(target.doseGrams == 18)
        #expect(target.ratio == 2)
        #expect(target.targetYieldGrams == 36)
        #expect(target.shotTimeRange == 25...30)
    }

    @Test("Espresso ratio is clamped into the 1:1–1:3 band")
    func espressoRatioClamp() {
        #expect(BrewTimelineBuilder.buildEspressoTarget(doseGrams: 18, ratio: 5).ratio == 3)
        #expect(BrewTimelineBuilder.buildEspressoTarget(doseGrams: 18, ratio: 0.2).ratio == 1)
    }

    @Test("Shot timing state: too early / on target / too late")
    func shotTimingClassification() {
        let window = 25...30
        #expect(ShotTimingState.classify(elapsedSeconds: 20, window: window) == .tooEarly)
        #expect(ShotTimingState.classify(elapsedSeconds: 25, window: window) == .onTarget)
        #expect(ShotTimingState.classify(elapsedSeconds: 30, window: window) == .onTarget)
        #expect(ShotTimingState.classify(elapsedSeconds: 31, window: window) == .tooLate)
    }

    // MARK: Dispatcher

    @Test("timeline(for:) routes pour methods and returns nil for cold brew / espresso")
    func dispatcher() {
        #expect(BrewTimelineBuilder.timeline(for: .v60, doseGrams: 18, ratio: 16)?.method == .v60)
        #expect(BrewTimelineBuilder.timeline(for: .chemex, doseGrams: 18, ratio: 16)?.method == .chemex)
        #expect(BrewTimelineBuilder.timeline(for: .frenchPress, doseGrams: 18, ratio: 15)?.method == .frenchPress)
        #expect(BrewTimelineBuilder.timeline(for: .aeropress, doseGrams: 18, ratio: 18)?.method == .aeropress)
        #expect(BrewTimelineBuilder.timeline(for: .coldBrew, doseGrams: 100, ratio: 5) == nil)
        #expect(BrewTimelineBuilder.timeline(for: .espresso, doseGrams: 18, ratio: 2) == nil)
    }

    // MARK: Derived timing

    @Test("stepStartTimes prefix-sums fixed durations")
    func stepStartTimes() {
        // French Press: bloom 30, fill 15, steep 240, plunge(manual)
        let t = BrewTimelineBuilder.buildFrenchPressTimeline(doseGrams: 30, ratio: 15)
        #expect(t.stepStartTimes == [0, 30, 45, 285])
        #expect(t.totalFixedDuration == 285) // plunge adds nothing
    }
}
