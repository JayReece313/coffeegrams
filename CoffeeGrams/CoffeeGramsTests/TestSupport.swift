//
//  TestSupport.swift
//  CoffeeGramsTests
//
//  Shared test doubles.
//

import Foundation
@testable import CoffeeGrams
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

/// Records what would have been scheduled, so notification flows can be tested
/// without touching the real notification system.
@MainActor
final class SpyNotificationService: NotificationScheduling {
    var authorizationGranted = true
    private(set) var authRequests = 0
    private(set) var scheduled: [ScheduledReminder] = []
    private(set) var cancelledIDs: [String] = []

    func requestAuthorization() async -> Bool {
        authRequests += 1
        return authorizationGranted
    }

    func schedule(_ reminder: ScheduledReminder) async {
        scheduled.append(reminder)
    }

    func cancel(id: String) {
        cancelledIDs.append(id)
    }
}
