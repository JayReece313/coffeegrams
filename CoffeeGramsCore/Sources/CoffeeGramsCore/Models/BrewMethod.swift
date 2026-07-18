import Foundation

/// The six brewing methods CoffeeGrams supports in v1.
///
/// The raw `String` values are **stable identifiers** — they are what we
/// persist in the brew log and (later) sync via CloudKit. Never rename an
/// existing case's raw value, or old log entries would fail to decode; add new
/// cases instead. This is why the raw values are spelled out explicitly rather
/// than relying on the case name.
public enum BrewMethod: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case v60
    case chemex
    case frenchPress = "french_press"
    case aeropress
    case coldBrew = "cold_brew"
    case espresso

    public var id: String { rawValue }

    /// Human-facing name for pickers and titles.
    public var displayName: String {
        switch self {
        case .v60: "V60"
        case .chemex: "Chemex"
        case .frenchPress: "French Press"
        case .aeropress: "AeroPress"
        case .coldBrew: "Cold Brew"
        case .espresso: "Espresso"
        }
    }

    /// The method(s) available for free; the rest are unlocked by the one-time
    /// in-app purchase. Encoded here (not in the paywall UI) so the free/paid
    /// split has a single source of truth the tests can assert.
    ///
    /// v1: only French Press is free — the most accessible, popular method —
    /// with its full experience (calculator, timer, log). Widening the free tier
    /// later (e.g. adding V60) is a one-line change here.
    public var isFreeTier: Bool {
        switch self {
        case .frenchPress: true
        default: false
        }
    }
}
