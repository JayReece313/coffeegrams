import Foundation

/// The core brewing math (spec §4.1), as pure, side-effect-free functions.
///
/// This is the single most test-worthy part of the app: every number here is a
/// promise to the user standing at their scale. It is intentionally a
/// namespace of `static` functions with no stored state — nothing to mock,
/// trivial to test, and callable from anywhere without wiring up an instance.
public enum BrewCalculator {

    // MARK: Dose-first (enter coffee grams, get water)

    /// Water needed for a given dose and ratio. `ratio` of 16 means 1:16, so
    /// 16 g of coffee → 256 g of water.
    ///
    /// A negative dose is treated as zero (the UI can momentarily hold an
    /// invalid value while the user edits a field); we never return a negative
    /// weight.
    public static func waterGrams(doseGrams: Double, ratio: Double) -> Double {
        guard doseGrams > 0, ratio > 0 else { return 0 }
        return doseGrams * ratio
    }

    // MARK: Yield-first (enter desired finished coffee, get dose)

    /// Coffee dose required to hit a target *finished* yield.
    ///
    /// Known v1 simplification (documented in the spec): immersion methods
    /// (French Press, AeroPress) lose ~2 g of water per gram of coffee to
    /// grounds absorption, so the true dose is marginally higher than
    /// `targetYield / ratio`. At the precision a home brewer works to, that
    /// correction is within scale noise, and modelling it convincingly needs
    /// testing against real output — so we deliberately keep it out of v1 and
    /// use the simple relationship for every method. The `switch` is retained
    /// (rather than a one-liner) precisely so the absorption seam is visible
    /// and easy to refine in v2 without touching call sites.
    ///
    /// Espresso is included for completeness — yield-first there is just
    /// `yield / ratio` = dose — though the espresso UI is driven dose-first.
    public static func doseGrams(
        targetYieldGrams: Double,
        ratio: Double,
        method: BrewMethod
    ) -> Double {
        guard targetYieldGrams > 0, ratio > 0 else { return 0 }

        switch method {
        case .v60, .chemex, .coldBrew, .espresso:
            // Pour-through / pressure: yield ≈ water, so dose = yield / ratio.
            return targetYieldGrams / ratio

        case .frenchPress, .aeropress:
            // Immersion: absorption offset deferred to v2 (see doc comment).
            let rawDose = targetYieldGrams / ratio
            return rawDose
        }
    }

    // MARK: Ratio clamping

    /// Clamp an arbitrary ratio into the method's allowed slider range. The UI
    /// slider is already bounded, but clamping here means every code path that
    /// consumes a ratio is protected — belt and braces for a number the whole
    /// calculation hinges on.
    public static func clampRatio(_ ratio: Double, for method: BrewMethod) -> Double {
        let range = BrewMethodProfile.profile(for: method).ratioRange
        return min(max(ratio, range.lowerBound), range.upperBound)
    }
}
