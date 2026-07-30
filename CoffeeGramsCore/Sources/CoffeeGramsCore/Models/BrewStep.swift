import Foundation

/// A single instruction in a guided brew timeline.
///
/// Design note: the spec sketched steps using a mix of `startSec` (for pours)
/// and `durationSec` (for bloom/steep). We deliberately unify on **duration**
/// here — each step knows only how long *it* lasts, and the absolute start time
/// is derived by prefix-summing the sequence (see `BrewTimeline`). A single
/// source of truth for timing means the timer engine never has to reconcile two
/// representations, and reordering/inserting a step can't desync a hardcoded
/// `startSec`.
///
/// `targetCumulativeGrams` is kept on pours because it is *not* derivable from
/// timing — it tells the user the scale reading to pour up to.
public enum BrewStep: Equatable, Sendable, Hashable {

    /// Wet the grounds and let them de-gas. `targetGrams` is the scale reading
    /// to reach; `duration` is how long to let the bloom rest.
    case bloom(targetGrams: Double, duration: Int)

    /// A pour (or single fill). `pourNumber` is 1-based. `targetCumulativeGrams`
    /// is the *total* scale reading to reach by the end of this pour, not the
    /// amount added.
    case pour(pourNumber: Int, targetCumulativeGrams: Double, duration: Int)

    /// Grounds sit submerged (immersion methods).
    case steep(duration: Int)

    /// Stir or swirl to knock down floating grounds.
    case stir(duration: Int)

    /// A passive pause (e.g. let grounds settle before plunging).
    case wait(duration: Int)

    /// Press the plunger (French Press / AeroPress). A manual action — the
    /// timer waits for the user rather than auto-advancing.
    case plunge

    /// Let the bed drain. When `untilDripsStop` is true this is user-advanced
    /// (there is no fixed time); false would make it a timed step.
    case drawdown(untilDripsStop: Bool)

    /// How long this step runs, in seconds. `nil` means the step has no fixed
    /// duration and the user must advance it manually (plunge, drawdown-until-
    /// drips-stop). The timer engine keys its behaviour off this.
    public var duration: Int? {
        switch self {
        case let .bloom(_, duration): duration
        case let .pour(_, _, duration): duration
        case let .steep(duration): duration
        case let .stir(duration): duration
        case let .wait(duration): duration
        case .plunge: nil
        case let .drawdown(untilDripsStop): untilDripsStop ? nil : 0
        }
    }

    /// True when the step has no fixed duration and the user taps to continue.
    public var requiresManualAdvance: Bool { duration == nil }

    /// Whether this step's `duration` is a **soft target** — a goal the timer
    /// counts past rather than a deadline it enforces.
    ///
    /// The distinction is *hands-on vs unattended*:
    ///
    /// - **Hands-on** (bloom, pour, stir) — you are at the scale and can easily
    ///   run long. Auto-advancing here gives an actively wrong instruction: if
    ///   your pour to 164 g takes 55 s, jumping to "Pour 2" tells you to add
    ///   more water before you have finished the first. So the step holds at
    ///   its target and counts up until you tap next.
    /// - **Unattended** (steep, wait) — you are doing nothing and may have
    ///   walked away; the clock *is* the instruction. These auto-advance, which
    ///   is also what fires the French Press "plunge now" prompt before the
    ///   brew over-extracts.
    ///
    /// Manual steps (`plunge`, `drawdown`) already wait for the user, so this
    /// is `false` for them — there is no target to overrun.
    public var usesSoftTarget: Bool {
        switch self {
        case .bloom, .pour, .stir: true
        case .steep, .wait, .plunge, .drawdown: false
        }
    }

    /// Short imperative title for the timer UI. Kept in Core (it is pure text,
    /// no UI dependency) so it can be unit-tested and localized centrally.
    public var title: String {
        switch self {
        case .bloom: "Bloom"
        case let .pour(pourNumber, _, _): "Pour \(pourNumber)"
        case .steep: "Steep"
        case .stir: "Stir"
        case .wait: "Wait"
        case .plunge: "Plunge"
        case .drawdown: "Drawdown"
        }
    }
}
