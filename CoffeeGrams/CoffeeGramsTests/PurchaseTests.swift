//
//  PurchaseTests.swift
//  CoffeeGramsTests
//
//  Entitlement gating + purchase/restore flows, driven by a fake provider
//  (no StoreKit). Nested under the serialized AppTests root.
//

import Testing
@testable import CoffeeGrams
import CoffeeGramsCore

extension AppTests {
  @MainActor
  @Suite("PurchaseController")
  struct PurchaseControllerTests {

    @Test("without Pro, only French Press is accessible")
    func gatingLocked() {
        let controller = PurchaseController(provider: FakePurchaseProvider(purchased: false))
        #expect(controller.canAccess(.frenchPress))
        #expect(!controller.canAccess(.v60))
        #expect(!controller.canAccess(.chemex))
        #expect(!controller.canAccess(.espresso))
    }

    @Test("Pro unlocks every method")
    func gatingUnlocked() async {
        let controller = PurchaseController(provider: FakePurchaseProvider(purchased: true))
        await controller.restore() // pull entitlement from the provider
        for method in BrewMethod.allCases {
            #expect(controller.canAccess(method))
        }
    }

    @Test("a successful purchase unlocks Pro")
    func purchaseUnlocks() async {
        let controller = PurchaseController(provider: FakePurchaseProvider(purchased: false))
        #expect(!controller.isPremiumUnlocked)

        let didPurchase = await controller.purchase()
        #expect(didPurchase)
        #expect(controller.isPremiumUnlocked)
        #expect(controller.canAccess(.espresso))
    }

    @Test("a cancelled purchase leaves it locked")
    func purchaseCancelled() async {
        let fake = FakePurchaseProvider(purchased: false)
        fake.outcome = .cancelled
        let controller = PurchaseController(provider: fake)

        let didPurchase = await controller.purchase()
        #expect(!didPurchase)
        #expect(!controller.isPremiumUnlocked)
    }

    @Test("a failed purchase is handled gracefully")
    func purchaseThrows() async {
        let fake = FakePurchaseProvider(purchased: false)
        fake.throwOnPurchase = true
        let controller = PurchaseController(provider: fake)

        let didPurchase = await controller.purchase()
        #expect(!didPurchase)
        #expect(!controller.isPremiumUnlocked)
    }

    @Test("restore reflects an existing purchase")
    func restoreExisting() async {
        let controller = PurchaseController(provider: FakePurchaseProvider(purchased: true))
        await controller.restore()
        #expect(controller.isPremiumUnlocked)
    }
  }
}
