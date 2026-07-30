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
    /// Kept separate from `actualSeconds`: a shot time is a quality metric with
    /// its own target window, not a whole-brew duration.
    public let shotSeconds: Int?

    /// The brew's **planned** total, i.e. the sum of the guided timeline's
    /// fixed step durations. Stored rather than recomputed so a saved brew
    /// still reports the plan it was actually run against, even if we retune a
    /// method profile in a later release. `nil` for brews with no timeline
    /// (espresso, cold brew) and for entries saved before 1.1.
    public let plannedSeconds: Int?

    /// The brew's **actual** wall-clock total, from Start to finish — including
    /// slow pours and however long the plunge took. Compared against
    /// `plannedSeconds` this is what tells you your pours are consistently
    /// running long. `nil` for brews with no timeline and for pre-1.1 entries.
    public let actualSeconds: Int?

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
        plannedSeconds: Int? = nil,
        actualSeconds: Int? = nil,
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
        self.plannedSeconds = plannedSeconds
        self.actualSeconds = actualSeconds
        self.rating = rating
        self.notes = notes
    }

    /// How far the brew ran over (positive) or under (negative) its plan, or
    /// `nil` when we don't have both numbers.
    public var timeDeltaSeconds: Int? {
        guard let plannedSeconds, let actualSeconds else { return nil }
        return actualSeconds - plannedSeconds
    }
}
