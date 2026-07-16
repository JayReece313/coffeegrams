import Foundation

/// A source of monotonic time, in seconds. Only *differences* between readings
/// are meaningful (it is not wall-clock time).
///
/// This is a "port" — an abstraction Core owns but does not implement. The iOS
/// app provides a live adapter backed by `CLOCK_MONOTONIC` / `Date`, and it
/// drives `BrewTimerEngine.advance(by:)` with the delta between ticks. The
/// engine itself never reads the clock, which is why its tests need no clock at
/// all: they call `advance(by:)` with exact deltas. Keeping the time source
/// behind a protocol is what makes the whole timer deterministically testable.
public protocol MonotonicClock: Sendable {
    var now: TimeInterval { get }
}
