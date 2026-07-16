import Foundation

/// The target for an espresso shot. Espresso is deliberately shallow in v1
/// (spec §4.6): four numbers only — dose in, ratio, target yield out, and a
/// shot-time window. No dial-in, extraction %, or TDS tooling.
public struct EspressoTarget: Equatable, Sendable, Hashable {
    public let doseGrams: Double
    public let ratio: Double
    public let targetYieldGrams: Double
    public let shotTimeRange: ClosedRange<Int>

    public init(
        doseGrams: Double,
        ratio: Double,
        targetYieldGrams: Double,
        shotTimeRange: ClosedRange<Int>
    ) {
        self.doseGrams = doseGrams
        self.ratio = ratio
        self.targetYieldGrams = targetYieldGrams
        self.shotTimeRange = shotTimeRange
    }
}

/// How the elapsed shot time compares to the target window — drives the
/// green/amber/red timer state in the UI. Kept in Core so the thresholds are
/// testable rather than buried in a view.
public enum ShotTimingState: Sendable, Hashable {
    /// Before the window opens — shot is still young.
    case tooEarly
    /// Inside the target window (green).
    case onTarget
    /// Past the window — pull is running long (red).
    case tooLate

    /// Classify an elapsed shot time against a target window.
    public static func classify(elapsedSeconds: Int, window: ClosedRange<Int>) -> ShotTimingState {
        if elapsedSeconds < window.lowerBound { return .tooEarly }
        if elapsedSeconds > window.upperBound { return .tooLate }
        return .onTarget
    }
}
