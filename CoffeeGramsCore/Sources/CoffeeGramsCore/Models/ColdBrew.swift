import Foundation

/// The two cold-brew strengths, each with its own fixed ratio (spec §3/§4.5).
public enum ColdBrewStyle: String, CaseIterable, Codable, Sendable, Hashable {
    /// Strong concentrate, diluted before drinking. 1:5.
    case concentrate
    /// Brewed at drinking strength. 1:8.
    case readyToDrink = "ready_to_drink"

    /// Water:coffee ratio for this style.
    public var ratio: Double {
        switch self {
        case .concentrate: 5.0
        case .readyToDrink: 8.0
        }
    }

    public var displayName: String {
        switch self {
        case .concentrate: "Concentrate"
        case .readyToDrink: "Ready to Drink"
        }
    }
}

/// The plan for a cold brew. Unlike the other five methods there is no live
/// pour timer — it is a 12–24 hour steep — so instead of a `[BrewStep]`
/// timeline we produce a dose/water amount and the wall-clock time the steep
/// finishes, which the app turns into a single local notification.
public struct ColdBrewPlan: Equatable, Sendable, Hashable {
    public let doseGrams: Double
    public let waterGrams: Double
    public let style: ColdBrewStyle
    public let steepHours: Double
    /// Absolute time the steep completes = start + steepHours.
    public let notifyAt: Date

    public init(
        doseGrams: Double,
        waterGrams: Double,
        style: ColdBrewStyle,
        steepHours: Double,
        notifyAt: Date
    ) {
        self.doseGrams = doseGrams
        self.waterGrams = waterGrams
        self.style = style
        self.steepHours = steepHours
        self.notifyAt = notifyAt
    }
}
