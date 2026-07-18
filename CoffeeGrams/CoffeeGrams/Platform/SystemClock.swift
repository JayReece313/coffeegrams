//
//  SystemClock.swift
//  CoffeeGrams
//
//  The live implementation of Core's `MonotonicClock` port.
//

import Foundation
import CoffeeGramsCore

/// Real monotonic time for the running app.
///
/// `systemUptime` counts seconds since boot and never runs backwards, which is
/// exactly what the timer engine needs — it only ever looks at the *difference*
/// between two readings, not the absolute value. In tests we swap in a fake
/// clock instead, which is why the engine and view models take a
/// `MonotonicClock` rather than reading the clock directly.
struct SystemClock: MonotonicClock {
    var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
}
