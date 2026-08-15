import Foundation

/// Whether to ask for an App Store review right now, as a pure decision over
/// the caller's engagement state (see `roadmap_future.md` — "In-app rating
/// prompt").
///
/// This is the one part of the feature that's genuinely provable: the
/// `requestReview()` call itself gives no callback and no return value, so
/// nothing about whether the sheet appeared can ever be asserted. What *can*
/// be asserted is that we decided to ask under the right conditions — which
/// is why the decision lives here, as a pure function, and not inline at the
/// call site or in the platform adapter.
public enum ReviewPromptEligibility {

    /// Completed brews required before the first possible prompt. Below this,
    /// even a glowing rating isn't yet a pattern worth interrupting for.
    public static let minimumCompletedBrews = 3

    /// Days since first launch required before the first possible prompt —
    /// avoids asking someone who just installed the app.
    public static let minimumDaysSinceFirstLaunch = 7

    /// Star rating (of 5) that counts as "satisfied with the coffee" and
    /// triggers the check. Below this, no prompt — this gates on satisfaction
    /// with the coffee, not a sentiment survey about the app.
    public static let minimumRating = 4

    /// Minimum gap enforced between our own prompts, independent of iOS's
    /// silent 3-per-365-day cap (which we can't observe or rely on alone — it
    /// still lets us call the API as often as we want; it just may decline to
    /// show anything). Not specified numerically in the spec, only implied by
    /// "eligibility state is ours to keep... last prompt date": without some
    /// cooldown a highly-engaged user rating most brews 4-5 stars would be
    /// asked on every save. 90 days keeps our own cadence comfortably inside
    /// the iOS cap (up to ~4/year) without asking so rarely that a satisfied
    /// user's moment passes.
    public static let minimumDaysBetweenPrompts = 90

    /// - Parameters:
    ///   - completedBrewCount: total saved brews (any method) at the moment
    ///     of this rating — the log itself is the count, not separate state.
    ///   - firstLaunchDate: when this install first ran.
    ///   - lastPromptDate: when we last asked, or `nil` if never.
    ///   - rating: the star rating (1–5) just given to the brew that was saved.
    ///   - now: injected rather than read internally, so this stays a pure
    ///     function callable from the CLI with no clock or simulator.
    public static func shouldRequest(
        completedBrewCount: Int,
        firstLaunchDate: Date,
        lastPromptDate: Date?,
        rating: Int,
        now: Date
    ) -> Bool {
        guard rating >= minimumRating else { return false }
        guard completedBrewCount >= minimumCompletedBrews else { return false }

        let daysSinceFirstLaunch = now.timeIntervalSince(firstLaunchDate) / 86400
        guard daysSinceFirstLaunch >= Double(minimumDaysSinceFirstLaunch) else { return false }

        if let lastPromptDate {
            let daysSinceLastPrompt = now.timeIntervalSince(lastPromptDate) / 86400
            guard daysSinceLastPrompt >= Double(minimumDaysBetweenPrompts) else { return false }
        }

        return true
    }
}
