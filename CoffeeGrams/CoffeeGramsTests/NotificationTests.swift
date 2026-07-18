//
//  NotificationTests.swift
//  CoffeeGramsTests
//

import Testing
@testable import CoffeeGrams
import CoffeeGramsCore

extension AppTests {
  @MainActor
  @Suite("BrewReminder")
  struct BrewReminderTests {
    @Test("cold brew reminder fires after the steep hours")
    func coldBrew() {
        let reminder = BrewReminder.coldBrewReady(steepHours: 16)
        #expect(reminder.id == BrewReminder.coldBrewID)
        #expect(reminder.delay == 16 * 3600)
        #expect(reminder.title.contains("Cold brew"))
    }

    @Test("french press reminder fires when the steep ends")
    func frenchPress() {
        let reminder = BrewReminder.frenchPressPlunge(steepEndsInSeconds: 285)
        #expect(reminder.id == BrewReminder.frenchPressID)
        #expect(reminder.delay == 285)
        #expect(reminder.body.contains("plunge"))
    }
}

@MainActor
@Suite("ColdBrewViewModel")
struct ColdBrewViewModelTests {
    @Test("starting a steep asks permission and schedules the reminder")
    func startsSteep() async {
        let spy = SpyNotificationService()
        let vm = ColdBrewViewModel(doseGrams: 100, ratio: 5, notifications: spy)
        vm.steepHours = 18

        await vm.startSteep()

        #expect(spy.authRequests == 1)
        #expect(spy.scheduled.count == 1)
        let delaySeconds = spy.scheduled.first.map { Int($0.delay) }
        #expect(delaySeconds == 18 * 3600)
        #expect(vm.reminderState == .scheduled(hours: 18))
    }

    @Test("denied permission degrades gracefully — nothing scheduled")
    func deniedPermission() async {
        let spy = SpyNotificationService()
        spy.authorizationGranted = false
        let vm = ColdBrewViewModel(doseGrams: 100, ratio: 5, notifications: spy)

        await vm.startSteep()

        #expect(spy.scheduled.isEmpty)
        #expect(vm.reminderState == .denied)
    }

    @Test("water uses the cold-brew ratio")
    func water() {
        let vm = ColdBrewViewModel(doseGrams: 100, ratio: 5, notifications: NoopNotificationService())
        #expect(vm.waterGrams == 500)
    }
  }
}
