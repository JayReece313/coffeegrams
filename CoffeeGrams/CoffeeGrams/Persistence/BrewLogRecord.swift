//
//  BrewLogRecord.swift
//  CoffeeGrams
//
//  The SwiftData persistence model for a saved brew.
//
//  This lives in the app layer, not CoffeeGramsCore: the domain uses the plain
//  value type `BrewLogEntry`, and we map between the two here. Keeping SwiftData
//  out of the core is what lets the core stay portable and fully unit-tested.
//

import Foundation
import SwiftData
import CoffeeGramsCore

@Model
final class BrewLogRecord {
    /// Matches the domain entry's id so records and value types line up.
    ///
    /// Not marked `@Attribute(.unique)`: the id is already unique by
    /// construction (a fresh UUID per brew), and SwiftData's unique-constraint
    /// upsert path can trap at save time — so we keep the column plain.
    var id: UUID
    var date: Date

    /// The brew method's *raw value* string. Stored as a string (not the enum)
    /// so the on-disk format is stable and independent of the Swift type.
    var methodRawValue: String

    var doseGrams: Double
    /// For espresso this holds the shot yield (mirrors `BrewLogEntry`).
    var waterGrams: Double
    var ratio: Double
    var shotSeconds: Int?
    var rating: Int?
    var notes: String?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        methodRawValue: String,
        doseGrams: Double,
        waterGrams: Double,
        ratio: Double,
        shotSeconds: Int? = nil,
        rating: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.methodRawValue = methodRawValue
        self.doseGrams = doseGrams
        self.waterGrams = waterGrams
        self.ratio = ratio
        self.shotSeconds = shotSeconds
        self.rating = rating
        self.notes = notes
    }

    /// Build a record from a domain entry.
    convenience init(entry: BrewLogEntry) {
        self.init(
            id: entry.id,
            date: entry.date,
            methodRawValue: entry.method.rawValue,
            doseGrams: entry.doseGrams,
            waterGrams: entry.waterGrams,
            ratio: entry.ratio,
            shotSeconds: entry.shotSeconds,
            rating: entry.rating,
            notes: entry.notes
        )
    }

    /// The method, decoded from its raw value. Falls back to V60 only if the
    /// stored string is somehow unrecognized (e.g. a future/removed method).
    var method: BrewMethod {
        BrewMethod(rawValue: methodRawValue) ?? .v60
    }

    /// Project back to the domain value type.
    var entry: BrewLogEntry {
        BrewLogEntry(
            id: id,
            date: date,
            method: method,
            doseGrams: doseGrams,
            waterGrams: waterGrams,
            ratio: ratio,
            shotSeconds: shotSeconds,
            rating: rating,
            notes: notes
        )
    }
}
