//
//  BrewLogStore.swift
//  CoffeeGrams
//
//  A thin, testable service over the SwiftData context for reading and writing
//  brew-log records. Callers work in domain value types (`BrewLogEntry`); the
//  mapping to/from `BrewLogRecord` happens here.
//

import Foundation
import SwiftData
import CoffeeGramsCore

/// The operations the app needs against the brew log. A protocol so previews or
/// alternative back ends could stand in, and so intent is explicit.
@MainActor
protocol BrewLogStoring {
    func add(_ entry: BrewLogEntry) throws
    func entries() throws -> [BrewLogEntry]
    func delete(id: UUID) throws
    func setRating(_ rating: Int?, forID id: UUID) throws
    func setNotes(_ notes: String?, forID id: UUID) throws
}

@MainActor
final class BrewLogStore: BrewLogStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ entry: BrewLogEntry) throws {
        context.insert(BrewLogRecord(entry: entry))
        try context.save()
    }

    /// All saved brews, newest first.
    func entries() throws -> [BrewLogEntry] {
        let descriptor = FetchDescriptor<BrewLogRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor).map(\.entry)
    }

    func delete(id: UUID) throws {
        if let record = try record(id: id) {
            context.delete(record)
            try context.save()
        }
    }

    func setRating(_ rating: Int?, forID id: UUID) throws {
        if let record = try record(id: id) {
            record.rating = rating
            try context.save()
        }
    }

    func setNotes(_ notes: String?, forID id: UUID) throws {
        if let record = try record(id: id) {
            record.notes = notes
            try context.save()
        }
    }

    // MARK: Helpers

    private func record(id: UUID) throws -> BrewLogRecord? {
        var descriptor = FetchDescriptor<BrewLogRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
