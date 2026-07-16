import Foundation

/// Generates the guided timeline (or plan/target) for a brew from a dose and
/// ratio, following spec §4.2–4.6. Pure and deterministic — the cold-brew
/// builder takes the start time as a parameter rather than reading the clock,
/// so its notification time is testable.
public enum BrewTimelineBuilder {

    // MARK: Public entry point

    /// The step timeline for the four pour-based methods. Returns `nil` for
    /// Cold Brew and Espresso, which have their own dedicated builders
    /// (`buildColdBrewPlan`, `buildEspressoTarget`) because they are not
    /// step-by-step pours.
    public static func timeline(
        for method: BrewMethod,
        doseGrams: Double,
        ratio: Double
    ) -> BrewTimeline? {
        switch method {
        case .v60, .chemex:
            buildPulsePourTimeline(
                profile: .profile(for: method),
                doseGrams: doseGrams,
                ratio: ratio
            )
        case .frenchPress:
            buildFrenchPressTimeline(doseGrams: doseGrams, ratio: ratio)
        case .aeropress:
            buildAeroPressTimeline(doseGrams: doseGrams, ratio: ratio)
        case .coldBrew, .espresso:
            nil
        }
    }

    // MARK: V60 / Chemex — pulse pour (spec §4.2)

    /// Bloom, then N evenly-sized pours spaced `pourIntervalSeconds` apart, then
    /// a drawdown the user ends when the drips stop. Each pour's
    /// `targetCumulativeGrams` is the running scale reading, and the final pour
    /// lands exactly on `dose × ratio`.
    public static func buildPulsePourTimeline(
        profile: BrewMethodProfile,
        doseGrams: Double,
        ratio: Double
    ) -> BrewTimeline {
        let totalWater = BrewCalculator.waterGrams(doseGrams: doseGrams, ratio: ratio)

        // Fall back to sane defaults if a profile ever omits these; the pulse-
        // pour profiles (V60/Chemex) always supply them.
        let bloomMultiplier = profile.bloomMultiplier ?? 2.25
        let bloomSeconds = profile.bloomSeconds ?? 45
        let numPours = max(1, profile.numPours ?? 2)
        let pourInterval = profile.pourIntervalSeconds ?? 45

        let bloomWater = doseGrams * bloomMultiplier
        let remainingWater = max(0, totalWater - bloomWater)
        let pourAmount = remainingWater / Double(numPours)

        var steps: [BrewStep] = []
        steps.append(.bloom(targetGrams: bloomWater, duration: bloomSeconds))

        var cumulative = bloomWater
        for pourNumber in 1...numPours {
            cumulative += pourAmount
            steps.append(.pour(
                pourNumber: pourNumber,
                targetCumulativeGrams: cumulative,
                duration: pourInterval
            ))
        }

        steps.append(.drawdown(untilDripsStop: true))
        return BrewTimeline(method: profile.method, steps: steps, totalWaterGrams: totalWater)
    }

    // MARK: French Press — bloom + fill + steep + plunge (spec §4.3)

    /// Optional 2× bloom, one fill pour to the full weight, a 4:00 steep that
    /// starts once the pour is complete, then plunge. The fill pour is given a
    /// short nominal duration so the guided timer shows a "pour to full" beat
    /// before the steep clock begins.
    public static func buildFrenchPressTimeline(
        doseGrams: Double,
        ratio: Double
    ) -> BrewTimeline {
        let profile = BrewMethodProfile.frenchPress
        let totalWater = BrewCalculator.waterGrams(doseGrams: doseGrams, ratio: ratio)
        let bloomWater = doseGrams * (profile.bloomMultiplier ?? 2.0)
        let bloomSeconds = profile.bloomSeconds ?? 30
        let steepSeconds = profile.steepSeconds ?? 240

        let steps: [BrewStep] = [
            .bloom(targetGrams: bloomWater, duration: bloomSeconds),
            .pour(pourNumber: 1, targetCumulativeGrams: totalWater, duration: Self.fillPourSeconds),
            .steep(duration: steepSeconds),
            .plunge,
        ]
        return BrewTimeline(method: .frenchPress, steps: steps, totalWaterGrams: totalWater)
    }

    // MARK: AeroPress — pour, steep, stir, settle, press (spec §4.4)

    /// Pour all the water at once, steep 2:00, stir/swirl, let the grounds
    /// settle, then plunge. Ratio doubles as a strength slider (handled by the
    /// caller); this builder just lays out the fixed sequence.
    public static func buildAeroPressTimeline(
        doseGrams: Double,
        ratio: Double
    ) -> BrewTimeline {
        let profile = BrewMethodProfile.aeropress
        let totalWater = BrewCalculator.waterGrams(doseGrams: doseGrams, ratio: ratio)
        let steepSeconds = profile.steepSeconds ?? 120

        let steps: [BrewStep] = [
            .pour(pourNumber: 1, targetCumulativeGrams: totalWater, duration: Self.fillPourSeconds),
            .steep(duration: steepSeconds),
            .stir(duration: 10),
            .wait(duration: 30),
            .plunge,
        ]
        return BrewTimeline(method: .aeropress, steps: steps, totalWaterGrams: totalWater)
    }

    // MARK: Cold Brew — no live timer, a scheduled notification (spec §4.5)

    /// A dose/water amount plus the wall-clock time the steep finishes. `now`
    /// is injected so the notify time is deterministic in tests. Steep hours are
    /// clamped to the sensible 12–24 h band.
    public static func buildColdBrewPlan(
        doseGrams: Double,
        style: ColdBrewStyle,
        steepHours: Double = 16,
        now: Date
    ) -> ColdBrewPlan {
        let clampedHours = min(max(steepHours, 12), 24)
        let waterGrams = BrewCalculator.waterGrams(doseGrams: doseGrams, ratio: style.ratio)
        return ColdBrewPlan(
            doseGrams: doseGrams,
            waterGrams: waterGrams,
            style: style,
            steepHours: clampedHours,
            notifyAt: now.addingTimeInterval(clampedHours * 3600)
        )
    }

    // MARK: Espresso — dose, ratio, target yield, shot window (spec §4.6)

    /// Four numbers only. Ratio is clamped to the espresso band (1:1–1:3) and
    /// the shot window comes from the profile (25–30 s).
    public static func buildEspressoTarget(
        doseGrams: Double,
        ratio: Double
    ) -> EspressoTarget {
        let clampedRatio = BrewCalculator.clampRatio(ratio, for: .espresso)
        let yield = BrewCalculator.waterGrams(doseGrams: doseGrams, ratio: clampedRatio)
        let window = BrewMethodProfile.espresso.shotTimeRangeSeconds ?? 25...30
        return EspressoTarget(
            doseGrams: doseGrams,
            ratio: clampedRatio,
            targetYieldGrams: yield,
            shotTimeRange: window
        )
    }

    // MARK: Tuning constants

    /// Nominal seconds allotted to a single "fill" pour (French Press /
    /// AeroPress). Not a brewing constant from the spec — it's a UI pacing
    /// choice so the timer shows a distinct pour beat before the steep clock,
    /// kept here as one named value rather than a magic number in two builders.
    static let fillPourSeconds = 15
}
