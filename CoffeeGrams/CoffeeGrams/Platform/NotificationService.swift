//
//  NotificationService.swift
//  CoffeeGrams
//
//  Local-notification scheduling behind a small port, so callers don't depend
//  on UserNotifications directly and tests can use a spy.
//
//  Only *local* notifications are used (no server, no push), so there is no
//  privacy-manifest impact and no Info.plist usage string is required.
//

import Foundation
import UserNotifications

/// A reminder to schedule: what to say and how far in the future.
struct ScheduledReminder: Equatable, Sendable {
    let id: String
    let title: String
    let body: String
    /// Seconds from now until it fires.
    let delay: TimeInterval
}

/// The scheduling operations the app needs. Kept minimal and behind a protocol
/// so the cold-brew/French-press flows are testable with a spy.
protocol NotificationScheduling {
    /// Ask the user for permission. Returns whether it was granted.
    func requestAuthorization() async -> Bool
    /// Schedule (or replace, by id) a one-shot reminder.
    func schedule(_ reminder: ScheduledReminder) async
    /// Cancel a pending reminder by id.
    func cancel(id: String)
}

/// The real implementation, backed by `UNUserNotificationCenter`.
struct LiveNotificationService: NotificationScheduling {
    private var center: UNUserNotificationCenter { .current() }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func schedule(_ reminder: ScheduledReminder) async {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default

        // A time-interval trigger must be > 0; clamp very short delays up to 1s.
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, reminder.delay),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: reminder.id,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func cancel(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }
}

/// A do-nothing implementation for previews and tests.
struct NoopNotificationService: NotificationScheduling {
    func requestAuthorization() async -> Bool { true }
    func schedule(_ reminder: ScheduledReminder) async {}
    func cancel(id: String) {}
}

/// Builds the specific reminders CoffeeGrams schedules. Pure and `nonisolated`
/// so the content/timing is unit-testable without touching the notification
/// system.
enum BrewReminder {
    nonisolated static let coldBrewID = "cold_brew_ready"
    nonisolated static let frenchPressID = "french_press_plunge"

    /// Fires when a cold-brew steep finishes (spec §4.5).
    nonisolated static func coldBrewReady(steepHours: Double) -> ScheduledReminder {
        ScheduledReminder(
            id: coldBrewID,
            title: "Cold brew ready ☕️",
            body: "Your cold brew has finished steeping — strain it and enjoy.",
            delay: steepHours * 3600
        )
    }

    /// Fires when a French-press steep ends, so it isn't left to over-extract
    /// (spec §4.3).
    nonisolated static func frenchPressPlunge(steepEndsInSeconds: Int) -> ScheduledReminder {
        ScheduledReminder(
            id: frenchPressID,
            title: "Time to plunge",
            body: "Your French press is done steeping — plunge and serve so it doesn't turn bitter.",
            delay: TimeInterval(steepEndsInSeconds)
        )
    }
}
