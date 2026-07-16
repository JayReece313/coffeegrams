import Foundation

/// The physical category of a brew, which determines how its timeline and
/// water math behave.
///
/// - `pulsePour`: water is poured over grounds in stages and passes through
///   (V60, Chemex). Yield ≈ water poured.
/// - `immersion`: grounds sit submerged in water, then are separated
///   (French Press, AeroPress, Cold Brew). Some water is retained by the
///   grounds, so yield < water poured (a simplification we document in the
///   calculator).
/// - `pressure`: liquid is extracted under pressure (Espresso). The meaningful
///   number is *shot yield weight vs. dose*, not water added — so this type is
///   handled by a dedicated, deliberately shallow path.
public enum BrewType: String, Codable, Sendable, Hashable {
    case pulsePour
    case immersion
    case pressure
}
