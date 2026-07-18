//
//  BrewLogStoreTests.swift
//  CoffeeGramsTests
//
//  Exercises the persistence layer against a real in-memory SwiftData store —
//  more faithful than a hand-rolled fake, and still fast and isolated.
//

import Testing
import Foundation
import SwiftData
@testable import CoffeeGrams
import CoffeeGramsCore

// `.serialized`: Swift Testing runs a suite's tests in parallel by default, but
// these each stand up a SwiftData container and save concurrently, which races
// and traps inside SwiftData. Running them one at a time is both correct and
// realistic for a store.
@MainActor
@Suite("BrewLogStore", .serialized)
struct BrewLogStoreTests {

    /// One in-memory container for the whole suite. Creating a `ModelContainer`
    /// is not concurrency-safe (SwiftData registers the schema in a process-wide
    /// table), so spinning up a fresh one per test races other suites' tests and
    /// traps. A single shared container created once — combined with `.serialized`
    /// and clearing rows per test — is both safe and fully isolated.
    static let sharedContainer: ModelContainer = {
        // swiftlint:disable:next force_try
        try! ModelContainer(
            for: BrewLogRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }()

    /// A store on the shared container, emptied so each test starts clean.
    private func makeStore() throws -> BrewLogStore {
        let context = Self.sharedContainer.mainContext
        try context.delete(model: BrewLogRecord.self)
        try context.save()
        return BrewLogStore(context: context)
    }

    private func entry(
        method: BrewMethod = .v60,
        date: Date = .now,
        rating: Int? = nil
    ) -> BrewLogEntry {
        BrewLogEntry(
            date: date,
            method: method,
            doseGrams: 18,
            waterGrams: 288,
            ratio: 16,
            rating: rating
        )
    }

    @Test("add then fetch round-trips the entry")
    func addAndFetch() throws {
        let store = try makeStore()
        let e = entry(method: .chemex)
        try store.add(e)

        let all = try store.entries()
        #expect(all.count == 1)
        #expect(all[0].id == e.id)
        #expect(all[0].method == .chemex)
        #expect(all[0].waterGrams == 288)
    }

    @Test("entries come back newest first")
    func sortedNewestFirst() throws {
        let store = try makeStore()
        let older = entry(date: Date(timeIntervalSince1970: 1_000))
        let newer = entry(date: Date(timeIntervalSince1970: 2_000))
        try store.add(older)
        try store.add(newer)

        let all = try store.entries()
        #expect(all.map(\.id) == [newer.id, older.id])
    }

    @Test("delete removes the entry")
    func delete() throws {
        let store = try makeStore()
        let e = entry()
        try store.add(e)
        try store.delete(id: e.id)
        #expect(try store.entries().isEmpty)
    }

    @Test("rating and notes can be updated")
    func updateRatingAndNotes() throws {
        let store = try makeStore()
        let e = entry()
        try store.add(e)

        try store.setRating(4, forID: e.id)
        try store.setNotes("Bright, juicy", forID: e.id)

        let saved = try #require(try store.entries().first)
        #expect(saved.rating == 4)
        #expect(saved.notes == "Bright, juicy")
    }

    @Test("record maps to/from the domain entry losslessly")
    func mappingRoundTrip() {
        let e = BrewLogEntry(
            method: .espresso,
            doseGrams: 18,
            waterGrams: 36,
            ratio: 2,
            shotSeconds: 27,
            rating: 5,
            notes: "Syrupy"
        )
        let record = BrewLogRecord(entry: e)
        let back = record.entry
        #expect(back.method == .espresso)
        #expect(back.shotSeconds == 27)
        #expect(back.rating == 5)
        #expect(back.notes == "Syrupy")
        #expect(back.waterGrams == 36)
    }
}
