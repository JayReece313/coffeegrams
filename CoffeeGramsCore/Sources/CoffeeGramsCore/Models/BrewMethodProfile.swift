import Foundation

/// The static, hardcoded brewing parameters for one method — the encoded form
/// of the reference table in §3 of the spec.
///
/// These are **defaults**, not gospel: the UI lets users drag the ratio within
/// `ratioRange`, because taste and bean freshness shift the "right" number.
/// Everything a timeline generator needs to lay out a brew lives here, so the
/// generators stay free of magic numbers.
public struct BrewMethodProfile: Sendable, Hashable {
    public let method: BrewMethod
    public let brewType: BrewType

    /// Default water:coffee ratio (for espresso, yield:dose). `16.0` means 1:16.
    public let defaultRatio: Double

    /// The inclusive range the ratio slider allows.
    public let ratioRange: ClosedRange<Double>

    /// Bloom water as a multiple of dose grams (`multiplier * dose` = bloom
    /// water). `nil` for methods with no bloom.
    public let bloomMultiplier: Double?

    /// How long the bloom rests, in seconds. `nil` if there is no bloom.
    public let bloomSeconds: Int?

    /// Steep time for immersion methods, in seconds. `nil` for pour-over and
    /// for cold brew (whose steep is measured in hours — see `ColdBrewPlan`).
    public let steepSeconds: Int?

    /// Number of pours for pulse-pour methods. `nil` otherwise.
    public let numPours: Int?

    /// Seconds between the start of consecutive pours (pulse-pour only).
    public let pourIntervalSeconds: Int?

    /// Target shot-time window for espresso. `nil` for every other method.
    public let shotTimeRangeSeconds: ClosedRange<Int>?

    public init(
        method: BrewMethod,
        brewType: BrewType,
        defaultRatio: Double,
        ratioRange: ClosedRange<Double>,
        bloomMultiplier: Double? = nil,
        bloomSeconds: Int? = nil,
        steepSeconds: Int? = nil,
        numPours: Int? = nil,
        pourIntervalSeconds: Int? = nil,
        shotTimeRangeSeconds: ClosedRange<Int>? = nil
    ) {
        self.method = method
        self.brewType = brewType
        self.defaultRatio = defaultRatio
        self.ratioRange = ratioRange
        self.bloomMultiplier = bloomMultiplier
        self.bloomSeconds = bloomSeconds
        self.steepSeconds = steepSeconds
        self.numPours = numPours
        self.pourIntervalSeconds = pourIntervalSeconds
        self.shotTimeRangeSeconds = shotTimeRangeSeconds
    }
}

// MARK: - The reference table (spec §3)

public extension BrewMethodProfile {

    /// V60 — pulse pour. Bloom 2.25×, 45s; 2 pours, 45s apart.
    static let v60 = BrewMethodProfile(
        method: .v60,
        brewType: .pulsePour,
        defaultRatio: 16.0,
        ratioRange: 15.0...17.0,
        bloomMultiplier: 2.25,
        bloomSeconds: 45,
        numPours: 2,
        pourIntervalSeconds: 45
    )

    /// Chemex — pulse pour. Thicker filter drains slower, so pours are spaced
    /// further apart (60s) than the V60.
    static let chemex = BrewMethodProfile(
        method: .chemex,
        brewType: .pulsePour,
        defaultRatio: 16.0,
        ratioRange: 15.0...17.0,
        bloomMultiplier: 2.5,
        bloomSeconds: 45,
        numPours: 2,
        pourIntervalSeconds: 60
    )

    /// French Press — immersion. Optional 2× bloom (30s), then fill and steep
    /// 4:00 before plunging.
    static let frenchPress = BrewMethodProfile(
        method: .frenchPress,
        brewType: .immersion,
        defaultRatio: 15.0,
        ratioRange: 12.0...17.0,
        bloomMultiplier: 2.0,
        bloomSeconds: 30,
        steepSeconds: 240
    )

    /// AeroPress — immersion + press. Ratio is a strength slider (1:12 strong →
    /// 1:18 clean), defaulting to Hoffmann's 1:18. No bloom.
    static let aeropress = BrewMethodProfile(
        method: .aeropress,
        brewType: .immersion,
        defaultRatio: 18.0,
        ratioRange: 12.0...18.0,
        steepSeconds: 120
    )

    /// Cold Brew — immersion, no heat, no live timer. `defaultRatio` is the
    /// concentrate ratio (1:5); the ready-to-drink style (1:8) is selected via
    /// `ColdBrewStyle`. The range spans both styles so the slider can reach
    /// either. Steep is measured in hours, so `steepSeconds` stays nil and the
    /// long steep is modelled by `ColdBrewPlan`.
    static let coldBrew = BrewMethodProfile(
        method: .coldBrew,
        brewType: .immersion,
        defaultRatio: 5.0,
        ratioRange: 4.0...8.0
    )

    /// Espresso — pressure. Ratio is yield:dose (1:1 ristretto → 1:3 lungo),
    /// default 1:2 "normale". Target shot window 25–30s.
    static let espresso = BrewMethodProfile(
        method: .espresso,
        brewType: .pressure,
        defaultRatio: 2.0,
        ratioRange: 1.0...3.0,
        shotTimeRangeSeconds: 25...30
    )

    /// All profiles, in the order they appear in the picker.
    static let all: [BrewMethodProfile] = [
        .v60, .chemex, .frenchPress, .aeropress, .coldBrew, .espresso,
    ]

    /// The profile for a given method. Total by construction — `all` covers
    /// every `BrewMethod` case (asserted in tests), so this never returns nil.
    static func profile(for method: BrewMethod) -> BrewMethodProfile {
        // Force-unwrap is safe here and *proven* safe by
        // `everyMethodHasExactlyOneProfile` in the test suite. Documenting the
        // invariant beats scattering optionals through every call site.
        all.first { $0.method == method }!
    }
}
