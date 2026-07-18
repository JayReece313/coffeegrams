//
//  ColdBrewViewModel.swift
//  CoffeeGrams
//
//  Cold brew has no live timer — instead, starting a steep schedules a local
//  notification for when it's done (spec §4.5).
//

import Foundation
import Observation
import CoffeeGramsCore

@MainActor
@Observable
final class ColdBrewViewModel {

    /// The outcome of trying to start a steep.
    enum ReminderState: Equatable {
        case idle
        case scheduled(hours: Int)
        case denied
    }

    let doseGrams: Double
    let ratio: Double
    var steepHours: Double = 16
    private(set) var reminderState: ReminderState = .idle

    private let notifications: NotificationScheduling

    init(
        doseGrams: Double,
        ratio: Double,
        notifications: NotificationScheduling = LiveNotificationService()
    ) {
        self.doseGrams = doseGrams
        self.ratio = ratio
        self.notifications = notifications
    }

    var waterGrams: Double {
        BrewCalculator.waterGrams(doseGrams: doseGrams, ratio: ratio)
    }

    /// Ask permission and schedule the "steep done" reminder. If permission is
    /// denied we degrade gracefully — the user can still brew, just without the
    /// reminder.
    func startSteep() async {
        let granted = await notifications.requestAuthorization()
        guard granted else {
            reminderState = .denied
            return
        }
        await notifications.schedule(BrewReminder.coldBrewReady(steepHours: steepHours))
        reminderState = .scheduled(hours: Int(steepHours))
    }
}
