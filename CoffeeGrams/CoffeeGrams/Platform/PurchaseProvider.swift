//
//  PurchaseProvider.swift
//  CoffeeGrams
//
//  The in-app purchase port and its StoreKit 2 implementation. Callers depend
//  on the protocol, so the paywall/gating logic is testable with a fake and
//  never touches StoreKit directly.
//

import Foundation
import StoreKit

/// The single non-consumable that unlocks everything beyond the free method.
enum ProProduct {
    static let id = "com.jrlabapps.coffeegrams.pro"
}

/// The result of attempting a purchase.
enum PurchaseOutcome: Equatable {
    case purchased
    case cancelled
    case pending
}

/// Store-side failures distinct from a user cancel or a real StoreKit "pending".
enum StoreKitError: Error {
    /// The Pro product couldn't be loaded (bad id, no network, not configured).
    case productUnavailable
}

/// Everything the app needs from the store. Main-actor isolated because it is
/// only ever driven from the UI layer.
@MainActor
protocol PurchaseProviding {
    /// Whether the Pro unlock is currently owned.
    func isPurchased() async -> Bool
    /// Localized price for display (e.g. "$4.99"), or nil if unavailable.
    func localizedPrice() async -> String?
    /// Attempt to buy the Pro unlock.
    func purchase() async throws -> PurchaseOutcome
    /// Restore prior purchases; returns whether Pro is owned afterwards.
    func restore() async -> Bool
    /// Yields whenever entitlements change out-of-band (Ask to Buy approval,
    /// a purchase made on another device, a refund, …).
    func entitlementUpdates() -> AsyncStream<Bool>
}

/// The real StoreKit 2 implementation.
struct StoreKitPurchaseProvider: PurchaseProviding {

    private func proProduct() async -> Product? {
        try? await Product.products(for: [ProProduct.id]).first
    }

    func isPurchased() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result,
               transaction.productID == ProProduct.id,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    func localizedPrice() async -> String? {
        await proProduct()?.displayPrice
    }

    func purchase() async throws -> PurchaseOutcome {
        // A missing product is a real failure (not a StoreKit "pending"), so we
        // throw — the controller surfaces it as "not purchased" rather than
        // silently swallowing it as a pending transaction.
        guard let product = await proProduct() else { throw StoreKitError.productUnavailable }
        switch try await product.purchase() {
        case let .success(verification):
            if case let .verified(transaction) = verification {
                await transaction.finish()
                return .purchased
            }
            return .pending
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    func restore() async -> Bool {
        try? await AppStore.sync()
        return await isPurchased()
    }

    func entitlementUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if case let .verified(transaction) = result {
                        await transaction.finish()
                        continuation.yield(await isPurchased())
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
