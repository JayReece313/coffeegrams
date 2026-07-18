//
//  PurchaseController.swift
//  CoffeeGrams
//
//  App-wide entitlement state. One instance is injected into the environment;
//  views read `isPremiumUnlocked` / `canAccess(_:)` and call purchase/restore.
//

import Foundation
import Observation
import CoffeeGramsCore

@MainActor
@Observable
final class PurchaseController {

    private(set) var isPremiumUnlocked = false
    private(set) var priceText: String?
    /// True while a purchase or restore is in flight (to disable buttons).
    private(set) var isWorking = false

    private let provider: any PurchaseProviding

    init(provider: any PurchaseProviding = StoreKitPurchaseProvider()) {
        self.provider = provider
    }

    /// Gate for a brew method: the free method is always available; everything
    /// else needs the Pro unlock. The free/paid split lives in the domain
    /// (`BrewMethod.isFreeTier`), so this stays a one-liner.
    func canAccess(_ method: BrewMethod) -> Bool {
        method.isFreeTier || isPremiumUnlocked
    }

    /// Load current entitlement + price, then keep listening for out-of-band
    /// changes. Call once from the app's root `.task`.
    func start() async {
        isPremiumUnlocked = await provider.isPurchased()
        priceText = await provider.localizedPrice()
        for await unlocked in provider.entitlementUpdates() {
            isPremiumUnlocked = unlocked
        }
    }

    /// Returns true if the purchase completed.
    @discardableResult
    func purchase() async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            let outcome = try await provider.purchase()
            if outcome == .purchased { isPremiumUnlocked = true }
            return outcome == .purchased
        } catch {
            return false
        }
    }

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        isPremiumUnlocked = await provider.restore()
    }
}
