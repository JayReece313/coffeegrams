//
//  ReviewPrompt.swift
//  CoffeeGrams
//
//  The App Store review request behind a small port, plus the UserDefaults-
//  backed state ReviewPromptEligibility needs (first-launch date, last-prompt
//  date). See Releases/roadmap_future.md — "In-app rating prompt".
//

import SwiftUI
import StoreKit

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
/// was read in, which is why this doesn't take or look up a scene itself.
/// Deliberately not doing the common `UIApplication.shared.connectedScenes`
/// scan: wrong the moment iPad multi-window is in play (ships the same
/// version as this feature), since "first foreground-active scene" can be a
/// window the user isn't looking at.
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

/// The small bit of state `ReviewPromptEligibility` needs that isn't already
/// derivable from the brew log. Not behind a protocol: nothing unit-tests the
/// view that reads this (`LogDetailView` has no ViewModel), and the
/// eligibility logic itself is tested with plain `Date` values, never this
/// type directly.
///
/// This is also the app's first use of `UserDefaults` — declared in
/// `PrivacyInfo.xcprivacy` under `NSPrivacyAccessedAPICategoryUserDefaults`
/// (reason `CA92.1`: own-app-only data, no App Group).
struct ReviewPromptState {
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

    /// `nil` only if `stampFirstLaunchIfNeeded()` was never called this
    /// install — in practice, app startup calls it before any view can read
    /// this, so a genuinely running app always has one.
    var firstLaunchDate: Date? {
        defaults.object(forKey: Self.firstLaunchKey) as? Date
    }

    var lastPromptDate: Date? {
        get { defaults.object(forKey: Self.lastPromptKey) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Self.lastPromptKey) }
    }
}
