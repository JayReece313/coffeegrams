import Foundation

/// One saved brew in the log.
///
/// This is a **plain value type** living in Core so it can be created and
/// asserted in tests with no iOS dependency. The app layer defines a separate
/// SwiftData `@Model` class and maps to/from this struct — keeping the
/// persistence framework out of the pure core is the seam that keeps the logic
/// testable and portable.
public struct BrewLogEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let date: Date
    public let method: BrewMethod
    public let doseGrams: Double

    /// For espresso this stores the **shot yield** in grams (same field,
    /// different meaning), per the spec. See `EspressoTarget` for the target.
    public let waterGrams: Double

    public let ratio: Double

    /// Espresso only — the measured shot time. `nil` for every other method.
    public let shotSeconds: Int?

    /// Optional 1–5 rating.
    public let rating: Int?

    public let notes: String?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        method: BrewMethod,
        doseGrams: Double,
        waterGrams: Double,
        ratio: Double,
        shotSeconds: Int? = nil,
        rating: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.method = method
        self.doseGrams = doseGrams
        self.waterGrams = waterGrams
        self.ratio = ratio
        self.shotSeconds = shotSeconds
        self.rating = rating
        self.notes = notes
    }
}
