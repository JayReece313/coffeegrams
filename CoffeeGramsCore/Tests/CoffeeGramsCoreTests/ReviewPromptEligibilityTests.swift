import Testing
import Foundation
@testable import CoffeeGramsCore

/// The one part of the rating-prompt feature that's genuinely provable — see
/// `ReviewPromptEligibility`'s own doc comment. Coverage is deliberately
/// exhaustive at the boundaries, since an off-by-one here either annoys users
/// with an early prompt or silently loses the one lever the app has on rank.
@Suite("ReviewPromptEligibility")
struct ReviewPromptEligibilityTests {

    private let day: TimeInterval = 86400

    /// A baseline that satisfies every gate, so each test can flip exactly
    /// one input away from eligible.
    private func eligibleCase(
        completedBrewCount: Int = 3,
        daysSinceFirstLaunch: Double = 7,
        daysSinceLastPrompt: Double? = nil,
        rating: Int = 5
    ) -> Bool {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let firstLaunchDate = now.addingTimeInterval(-daysSinceFirstLaunch * day)
        let lastPromptDate = daysSinceLastPrompt.map { now.addingTimeInterval(-$0 * day) }
        return ReviewPromptEligibility.shouldRequest(
            completedBrewCount: completedBrewCount,
            firstLaunchDate: firstLaunchDate,
            lastPromptDate: lastPromptDate,
            rating: rating,
            now: now
        )
    }

    @Test("every gate satisfied at once → eligible")
    func allGatesSatisfied() {
        #expect(eligibleCase())
    }

    // MARK: Rating gate

    @Test("rating 4 or 5 is eligible; below 4 is not", arguments: [1, 2, 3, 4, 5])
    func ratingThreshold(rating: Int) {
        let result = eligibleCase(rating: rating)
        #expect(result == (rating >= 4))
    }

    // MARK: Brew count gate

    @Test("fewer than 3 completed brews is never eligible")
    func brewCountBelowThreshold() {
        #expect(eligibleCase(completedBrewCount: 0) == false)
        #expect(eligibleCase(completedBrewCount: 2) == false)
    }

    @Test("exactly 3 completed brews is the eligible boundary")
    func brewCountAtThreshold() {
        #expect(eligibleCase(completedBrewCount: 3))
    }

    // MARK: First-launch gate

    @Test("fewer than 7 days since first launch is never eligible")
    func tooSoonAfterFirstLaunch() {
        #expect(eligibleCase(daysSinceFirstLaunch: 0) == false)
        #expect(eligibleCase(daysSinceFirstLaunch: 6.9) == false)
    }

    @Test("exactly 7 days since first launch is the eligible boundary")
    func firstLaunchAtThreshold() {
        #expect(eligibleCase(daysSinceFirstLaunch: 7))
    }

    // MARK: Cooldown gate

    @Test("never having prompted before doesn't block eligibility")
    func noPriorPromptIsFine() {
        #expect(eligibleCase(daysSinceLastPrompt: nil))
    }

    @Test("prompting again inside the cooldown is not eligible")
    func withinCooldown() {
        #expect(eligibleCase(daysSinceLastPrompt: 1) == false)
        #expect(eligibleCase(daysSinceLastPrompt: 89) == false)
    }

    @Test("exactly the cooldown length is the eligible boundary")
    func atCooldownBoundary() {
        #expect(eligibleCase(daysSinceLastPrompt: 90))
    }

    @Test("well past the cooldown is eligible")
    func wellPastCooldown() {
        #expect(eligibleCase(daysSinceLastPrompt: 365))
    }

    // MARK: Combined gates

    @Test("a low rating overrides an otherwise-perfect engagement history")
    func ratingGateWinsEvenWhenEngaged() {
        #expect(eligibleCase(completedBrewCount: 50, daysSinceFirstLaunch: 400, rating: 3) == false)
    }

    @Test("the day-count math treats a day as exactly 86400 seconds, not calendar days")
    func usesElapsedSecondsNotCalendarDays() {
        // 6 days and 23 hours — short of 7 full days even if it crosses a
        // calendar-day boundary at local midnight.
        #expect(eligibleCase(daysSinceFirstLaunch: 6.0 + 23.0 / 24.0) == false)
    }
}
