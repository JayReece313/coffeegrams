//
//  ReviewPromptTriggerTests.swift
//  CoffeeGramsTests
//
//  ReviewPromptEligibility itself (the pure decision) is tested exhaustively
//  in CoffeeGramsCore. These tests cover the orchestration around it:
//  persisting the rating first, only evaluating eligibility if that
//  succeeds, and updating lastPromptDate from the same `now` used to decide.
//

import Testing
import Foundation
@testable import CoffeeGrams
import CoffeeGramsCore

extension AppTests {
    @MainActor
    @Suite("ReviewPromptTrigger")
    struct ReviewPromptTriggerTests {

        private let now = Date(timeIntervalSince1970: 1_000_000)
        private let day: TimeInterval = 86400

        private func eligibleEntry(rating: Int? = nil) -> BrewLogEntry {
            BrewLogEntry(method: .frenchPress, doseGrams: 18, waterGrams: 270, ratio: 15, rating: rating)
        }

        @Test("every gate satisfied: persists the rating and requests review")
        func firesWhenEligible() throws {
            let entry = eligibleEntry()
            let store = FakeBrewLogStore(entries: [entry, eligibleEntry(), eligibleEntry()])
            let promptState = InMemoryReviewPromptState(firstLaunchDate: now.addingTimeInterval(-7 * day))
            let requester = SpyReviewRequester()

            ReviewPromptTrigger.handleRatingChange(
                5, forRecordID: entry.id, store: store, promptState: promptState,
                clock: FakeWallClock(now: now), reviewRequester: requester
            )

            #expect(try store.entries().first(where: { $0.id == entry.id })?.rating == 5)
            #expect(requester.requestCount == 1)
            #expect(promptState.lastPromptDate == now)
        }

        @Test("rating below 4 persists but never requests a review")
        func lowRatingNeverPrompts() throws {
            let entry = eligibleEntry()
            let store = FakeBrewLogStore(entries: [entry, eligibleEntry(), eligibleEntry()])
            let promptState = InMemoryReviewPromptState(firstLaunchDate: now.addingTimeInterval(-7 * day))
            let requester = SpyReviewRequester()

            ReviewPromptTrigger.handleRatingChange(
                3, forRecordID: entry.id, store: store, promptState: promptState,
                clock: FakeWallClock(now: now), reviewRequester: requester
            )

            #expect(try store.entries().first(where: { $0.id == entry.id })?.rating == 3)
            #expect(requester.requestCount == 0)
            #expect(promptState.lastPromptDate == nil)
        }

        @Test("a failed save never evaluates eligibility or consumes the cooldown")
        func failedSaveSkipsEligibility() throws {
            let entry = eligibleEntry()
            let store = FakeBrewLogStore(entries: [entry, eligibleEntry(), eligibleEntry()])
            store.throwOnSetRating = true
            let promptState = InMemoryReviewPromptState(firstLaunchDate: now.addingTimeInterval(-7 * day))
            let requester = SpyReviewRequester()

            ReviewPromptTrigger.handleRatingChange(
                5, forRecordID: entry.id, store: store, promptState: promptState,
                clock: FakeWallClock(now: now), reviewRequester: requester
            )

            #expect(requester.requestCount == 0, "must not request review over a rating that didn't save")
            #expect(promptState.lastPromptDate == nil, "must not consume the cooldown for an unsaved change")
        }

        @Test("too few completed brews: persists but doesn't prompt")
        func notEnoughBrews() throws {
            let entry = eligibleEntry()
            let store = FakeBrewLogStore(entries: [entry]) // only 1, below the 3-brew gate
            let promptState = InMemoryReviewPromptState(firstLaunchDate: now.addingTimeInterval(-7 * day))
            let requester = SpyReviewRequester()

            ReviewPromptTrigger.handleRatingChange(
                5, forRecordID: entry.id, store: store, promptState: promptState,
                clock: FakeWallClock(now: now), reviewRequester: requester
            )

            #expect(try store.entries().first(where: { $0.id == entry.id })?.rating == 5)
            #expect(requester.requestCount == 0)
        }

        @Test("no first-launch date recorded yet: never prompts, never crashes")
        func noFirstLaunchDateYet() throws {
            let entry = eligibleEntry()
            let store = FakeBrewLogStore(entries: [entry, eligibleEntry(), eligibleEntry()])
            let promptState = InMemoryReviewPromptState(firstLaunchDate: nil)
            let requester = SpyReviewRequester()

            ReviewPromptTrigger.handleRatingChange(
                5, forRecordID: entry.id, store: store, promptState: promptState,
                clock: FakeWallClock(now: now), reviewRequester: requester
            )

            #expect(requester.requestCount == 0)
        }

        @Test("within the cooldown of the last prompt: persists but doesn't prompt again")
        func withinCooldown() throws {
            let entry = eligibleEntry()
            let store = FakeBrewLogStore(entries: [entry, eligibleEntry(), eligibleEntry()])
            let promptState = InMemoryReviewPromptState(
                firstLaunchDate: now.addingTimeInterval(-400 * day),
                lastPromptDate: now.addingTimeInterval(-10 * day)
            )
            let requester = SpyReviewRequester()

            ReviewPromptTrigger.handleRatingChange(
                5, forRecordID: entry.id, store: store, promptState: promptState,
                clock: FakeWallClock(now: now), reviewRequester: requester
            )

            #expect(requester.requestCount == 0)
        }

        @Test("clearing a rating back to unrated (0) persists nil and never prompts")
        func clearingRatingIsNeverEligible() throws {
            let entry = eligibleEntry(rating: 5)
            let store = FakeBrewLogStore(entries: [entry, eligibleEntry(), eligibleEntry()])
            let promptState = InMemoryReviewPromptState(firstLaunchDate: now.addingTimeInterval(-7 * day))
            let requester = SpyReviewRequester()

            ReviewPromptTrigger.handleRatingChange(
                0, forRecordID: entry.id, store: store, promptState: promptState,
                clock: FakeWallClock(now: now), reviewRequester: requester
            )

            #expect(try store.entries().first(where: { $0.id == entry.id })?.rating == nil)
            #expect(requester.requestCount == 0)
        }
    }
}
