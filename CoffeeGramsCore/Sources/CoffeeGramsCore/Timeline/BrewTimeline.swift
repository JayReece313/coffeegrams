import Foundation

/// An ordered set of guided-brew steps for one brew, plus the totals a UI
/// header wants to show. Produced by `BrewTimelineBuilder`; consumed by the
/// `BrewTimerEngine` and the guided-brew view.
///
/// Cold Brew and Espresso do **not** produce a `BrewTimeline` — cold brew is a
/// long unattended steep (`ColdBrewPlan`) and espresso is a single timed pull
/// (`EspressoTarget`). Only the four "pour water over/through grounds" methods
/// have a step-by-step timeline.
public struct BrewTimeline: Equatable, Sendable {
    public let method: BrewMethod
    public let steps: [BrewStep]

    /// Final water weight the brew reaches (dose × ratio).
    public let totalWaterGrams: Double

    public init(method: BrewMethod, steps: [BrewStep], totalWaterGrams: Double) {
        self.method = method
        self.steps = steps
        self.totalWaterGrams = totalWaterGrams
    }

    /// Sum of the fixed-duration steps, in seconds. Manual steps (plunge,
    /// drawdown-until-drips) contribute nothing because they have no set length.
    /// Useful for an "≈ 3:15" estimate in the UI header.
    public var totalFixedDuration: Int {
        steps.reduce(0) { $0 + ($1.duration ?? 0) }
    }

    /// The absolute second each step *starts*, derived by prefix-summing
    /// durations. A manual step (nil duration) holds the clock until the user
    /// advances, so every following step's start is measured from that release
    /// point; here we simply carry the running clock forward by the step's
    /// fixed duration (0 for manual steps). The engine layers real
    /// manual-advance behaviour on top of this.
    public var stepStartTimes: [Int] {
        var starts: [Int] = []
        var clock = 0
        for step in steps {
            starts.append(clock)
            clock += step.duration ?? 0
        }
        return starts
    }
}
