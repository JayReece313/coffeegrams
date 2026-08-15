//
//  TestSupport.swift
//  CoffeeGramsTests
//
//  Shared test doubles.
//

import Foundation
@testable import CoffeeGrams
import CoffeeGramsCore

/// A clock we control by hand, so timer logic can be tested instantly and
/// deterministically instead of waiting in real time.
///
/// `@unchecked Sendable`: it holds mutable state but is only ever touched from
/// the main actor in these tests, so the checks are unnecessary.
final class FakeClock: MonotonicClock, @unchecked Sendable {
    var now: TimeInterval

    init(now: TimeInterval = 0) {
        self.now = now
    }

    /// Move time forward by `seconds`.
    func advance(_ seconds: TimeInterval) {
        now += seconds
    }
}

/// Records what would have been scheduled, so notification flows can be tested
/// without touching the real notification system.
@MainActor
final class SpyNotificationService: NotificationScheduling {
    var authorizationGranted = true
    private(set) var authRequests = 0
    private(set) var scheduled: [ScheduledReminder] = []
    private(set) var cancelledIDs: [String] = []

    func requestAuthorization() async -> Bool {
        authRequests += 1
        return authorizationGranted
    }

    func schedule(_ reminder: ScheduledReminder) async {
        scheduled.append(reminder)
    }

    func cancel(id: String) {
        cancelledIDs.append(id)
    }
}

/// A controllable stand-in for wall-clock time, so `ReviewPromptTrigger`
/// tests don't depend on when they happen to run.
struct FakeWallClock: WallClock {
    var now: Date
}

/// In-memory test double for the rating-prompt's UserDefaults-backed state —
/// no real UserDefaults, no persistence across runs.
final class InMemoryReviewPromptState: ReviewPromptStateStoring {
    var firstLaunchDate: Date?
    var lastPromptDate: Date?

    init(firstLaunchDate: Date? = nil, lastPromptDate: Date? = nil) {
        self.firstLaunchDate = firstLaunchDate
        self.lastPromptDate = lastPromptDate
    }
}

/// A spy that records whether it was asked, for tests that can't observe the
/// real StoreKit sheet.
final class SpyReviewRequester: ReviewRequesting {
    private(set) var requestCount = 0

    func requestReview() {
        requestCount += 1
    }
}

enum BrewLogStoreTestError: Error { case notFound }

/// An in-memory stand-in for `BrewLogStoring`, so `ReviewPromptTrigger` tests
/// don't need a real SwiftData `ModelContext` (which also can't coexist with
/// other tests' containers in the same process — see BrewLogStoreTests).
@MainActor
final class FakeBrewLogStore: BrewLogStoring {
    private(set) var entriesByID: [UUID: BrewLogEntry] = [:]
    var throwOnSetRating = false

    init(entries: [BrewLogEntry] = []) {
        for entry in entries { entriesByID[entry.id] = entry }
    }

    func add(_ entry: BrewLogEntry) throws {
        entriesByID[entry.id] = entry
    }

    func entries() throws -> [BrewLogEntry] {
        Array(entriesByID.values)
    }

    func delete(id: UUID) throws {
        entriesByID.removeValue(forKey: id)
    }

    func setRating(_ rating: Int?, forID id: UUID) throws {
        if throwOnSetRating { throw BrewLogStoreTestError.notFound }
        guard var entry = entriesByID[id] else { throw BrewLogStoreTestError.notFound }
        entry = BrewLogEntry(
            id: entry.id, date: entry.date, method: entry.method,
            doseGrams: entry.doseGrams, waterGrams: entry.waterGrams, ratio: entry.ratio,
            shotSeconds: entry.shotSeconds, plannedSeconds: entry.plannedSeconds,
            actualSeconds: entry.actualSeconds, rating: rating, notes: entry.notes
        )
        entriesByID[id] = entry
    }

    func setNotes(_ notes: String?, forID id: UUID) throws {
        guard var entry = entriesByID[id] else { throw BrewLogStoreTestError.notFound }
        entry = BrewLogEntry(
            id: entry.id, date: entry.date, method: entry.method,
            doseGrams: entry.doseGrams, waterGrams: entry.waterGrams, ratio: entry.ratio,
            shotSeconds: entry.shotSeconds, plannedSeconds: entry.plannedSeconds,
            actualSeconds: entry.actualSeconds, rating: entry.rating, notes: notes
        )
        entriesByID[id] = entry
    }

    func completedBrewCount() throws -> Int {
        entriesByID.count
    }
}

enum PurchaseTestError: Error { case failed }

/// A controllable stand-in for StoreKit so purchase/gating flows are testable.
@MainActor
final class FakePurchaseProvider: PurchaseProviding {
    var purchased: Bool
    var price: String? = "$4.99"
    var outcome: PurchaseOutcome = .purchased
    var throwOnPurchase = false

    init(purchased: Bool = false) {
        self.purchased = purchased
    }

    func isPurchased() async -> Bool { purchased }
    func localizedPrice() async -> String? { price }

    func purchase() async throws -> PurchaseOutcome {
        if throwOnPurchase { throw PurchaseTestError.failed }
        if outcome == .purchased { purchased = true }
        return outcome
    }

    func restore() async -> Bool { purchased }
    func entitlementUpdates() -> AsyncStream<Bool> { AsyncStream { $0.finish() } }
}
