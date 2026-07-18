//
//  TestSupport.swift
//  CoffeeGramsTests
//
//  Shared test doubles.
//

import Foundation
import CoffeeGramsCore

/// A clock we control by hand, so timer logic can be tested instantly and
/// deterministically instead of waiting in real time.
///
/// `@unchecked Sendable`: it holds mutable state but is only ever touched from
/// the main actor in these tests, so the checks are unnecessary.
final class FakeClock: MonotonicClock, @unchecked Sendable {
    var now: TimeInterval

    init(now: TimeInterval = 0) {
        self.now = now
    }

    /// Move time forward by `seconds`.
    func advance(_ seconds: TimeInterval) {
        now += seconds
    }
}
