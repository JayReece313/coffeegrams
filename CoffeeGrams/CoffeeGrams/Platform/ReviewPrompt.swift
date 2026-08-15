//
//  ReviewPrompt.swift
//  CoffeeGrams
//
//  The App Store review request behind a small port, the UserDefaults-backed
//  state ReviewPromptEligibility needs, and the orchestration that ties a
//  rating save to the eligibility check. See Releases/roadmap_future.md —
//  "In-app rating prompt".
//
//  HIG — Ratings and reviews: ask only after the user has demonstrated
//  engagement (never on first launch), avoid interrupting a critical task,
//  and space requests out rather than asking on every opportunity — the
//  3-completed-brews, 7-day, and cooldown gates in ReviewPromptEligibility
//  exist to honor exactly this, on top of the system's own 3-per-365-day cap.
//  https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews
//

import SwiftUI
import StoreKit
import CoffeeGramsCore

/// The one side effect this feature has: asking iOS to show (or silently
/// decline) the review sheet. Kept minimal and behind a protocol so the
/// trigger call site is testable with a spy — even though, per the roadmap,
/// nothing can ever assert the sheet actually appeared. What tests *can*
/// assert is that we asked under the right conditions.
protocol ReviewRequesting {
    func requestReview()
}

/// Closes over `@Environment(\.requestReview)`, read at the View level and
/// passed down — the action resolves its own window scene from the view it
/// was read in. Deliberately not doing the common
/// `UIApplication.shared.connectedScenes` scan: wrong the moment iPad
/// multi-window is in play (ships the same version as this feature), since
/// "first foreground-active scene" can be a window the user isn't looking at.
struct LiveReviewRequester: ReviewRequesting {
    let action: RequestReviewAction

    func requestReview() {
        action()
    }
}

/// For previews and call sites that haven't wired the environment action.
struct NoopReviewRequester: ReviewRequesting {
    func requestReview() {}
}

/// Wall-clock time, injectable so `ReviewPromptTrigger` is testable without
/// waiting on a real clock. Distinct from Core's `MonotonicClock` (uptime,
/// for measuring elapsed brew time) — this is calendar time, for comparing
/// against stored `Date`s.
protocol WallClock {
    var now: Date { get }
}

struct SystemWallClock: WallClock {
    var now: Date { Date() }
}

/// The small bit of state `ReviewPromptEligibility` needs that isn't already
/// derivable from the brew log: when this install first launched, and when
/// we last asked. A protocol so `ReviewPromptTrigger` can be tested with an
/// in-memory double instead of real `UserDefaults`.
///
/// Class-constrained so `lastPromptDate`'s setter can be called through a
/// `let`-bound `any ReviewPromptStoring` parameter: a struct-typed existential
/// can't satisfy `{ get set }` that way (Swift requires the *binding* to be
/// mutable, even when the concrete type's setter is `nonmutating`), but a
/// class reference can, since mutation happens through the reference, not the
/// binding.
protocol ReviewPromptStateStoring: AnyObject {
    /// `nil` only if `stampFirstLaunchIfNeeded()` was never called this
    /// install — in practice, app startup calls it before any view can read
    /// this, so a genuinely running app always has one.
    var firstLaunchDate: Date? { get }
    var lastPromptDate: Date? { get set }
}

/// The live implementation, backed by `UserDefaults`. This is the app's first
/// use of `UserDefaults` — declared in `PrivacyInfo.xcprivacy` under
/// `NSPrivacyAccessedAPICategoryUserDefaults` (reason `CA92.1`: own-app-only
/// data, no App Group).
final class UserDefaultsReviewPromptState: ReviewPromptStateStoring {
    private let defaults: UserDefaults
    private static let firstLaunchKey = "reviewPrompt.firstLaunchDate"
    private static let lastPromptKey = "reviewPrompt.lastPromptDate"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Stamps "now" as the first-launch date, but only if this install has
    /// never launched before. Call once, at app startup (`CoffeeGramsApp
    /// .init()`) — a no-op on every launch after the first, so the 7-day
    /// eligibility clock always starts from the true first launch, not from
    /// whenever some view first happens to read `firstLaunchDate`.
    func stampFirstLaunchIfNeeded(now: Date = Date()) {
        guard defaults.object(forKey: Self.firstLaunchKey) == nil else { return }
        defaults.set(now, forKey: Self.firstLaunchKey)
    }

    var firstLaunchDate: Date? {
        defaults.object(forKey: Self.firstLaunchKey) as? Date
    }

    var lastPromptDate: Date? {
        get { defaults.object(forKey: Self.lastPromptKey) as? Date }
        set { defaults.set(newValue, forKey: Self.lastPromptKey) }
    }
}

/// Ties a rating save to the review-prompt eligibility check. A free function
/// on a namespace, not a `@MainActor @Observable` ViewModel: two of its
/// dependencies (`store`, backed by `@Environment(\.modelContext)`, and
/// `reviewRequester`, backed by `@Environment(\.requestReview)`) only resolve
/// once the calling View is placed in the hierarchy — before that point, no
/// ViewModel could hold them as constructor dependencies either, since
/// `@Environment` isn't readable during a View's synchronous `init`. Taking
/// every dependency as a parameter instead keeps this directly unit-testable
/// with fakes, and keeps the View itself down to plumbing: read the
/// environment, call this, no decision logic of its own.
@MainActor
enum ReviewPromptTrigger {
    static func handleRatingChange(
        _ rating: Int,
        forRecordID id: UUID,
        store: BrewLogStoring,
        promptState: ReviewPromptStateStoring,
        clock: WallClock,
        reviewRequester: ReviewRequesting
    ) {
        do {
            try store.setRating(rating == 0 ? nil : rating, forID: id)
        } catch {
            // Don't evaluate the prompt over a rating that didn't actually
            // save — that would consume the cooldown for a change the user
            // never really made.
            return
        }

        guard let firstLaunchDate = promptState.firstLaunchDate else { return }
        let completedBrewCount = (try? store.completedBrewCount()) ?? 0
        // One `now` for both the eligibility check and the timestamp we
        // persist, so they can't drift apart even by a few milliseconds.
        let now = clock.now

        let eligible = ReviewPromptEligibility.shouldRequest(
            completedBrewCount: completedBrewCount,
            firstLaunchDate: firstLaunchDate,
            lastPromptDate: promptState.lastPromptDate,
            rating: rating,
            now: now
        )
        guard eligible else { return }

        reviewRequester.requestReview()
        promptState.lastPromptDate = now
    }
}
