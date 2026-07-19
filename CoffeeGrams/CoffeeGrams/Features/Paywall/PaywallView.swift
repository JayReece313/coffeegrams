//
//  PaywallView.swift
//  CoffeeGrams
//
//  Shown when a locked method is tapped. Presents the one-time Pro unlock.
//
//  Follows Apple's Human Interface Guidelines — In-App Purchase
//  (https://developer.apple.com/design/human-interface-guidelines/in-app-purchase)
//  and App Store Review Guideline 3.1.1 (In-App Purchase): the real StoreKit
//  price is shown, "Restore Purchase" is clearly available, and there are no
//  external/alternative purchase paths.
//

import SwiftUI

struct PaywallView: View {
    @Environment(PurchaseController.self) private var purchases
    @Environment(\.dismiss) private var dismiss

    private let benefits = [
        ("cup.and.saucer.fill", "All 6 brewing methods", "V60, Chemex, AeroPress, Cold Brew & Espresso — plus French Press."),
        ("timer", "Guided timers for every method", "Step-by-step pours, blooms, and shot windows."),
        ("list.bullet.rectangle", "Full brew log", "Save, rate, and take notes on every cup."),
        ("infinity", "One-time purchase", "Yours forever. No subscription."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    VStack(spacing: 18) {
                        ForEach(benefits, id: \.0) { icon, title, detail in
                            benefitRow(icon: icon, title: title, detail: detail)
                        }
                    }
                    buyButton
                    restoreButton
                    Text("One-time purchase, restores on all your devices.")
                        .font(.footnote)
                        .foregroundStyle(Color.cgTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .background(Color.cgBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.cgTextSecondary)
                }
            }
        }
        // Dismiss automatically once unlocked (covers Ask-to-Buy / another device).
        .onChange(of: purchases.isPremiumUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.cgAccent)
            Text("CoffeeGrams Pro")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color.cgTextPrimary)
            Text("Unlock every brewing method and feature.")
                .font(.headline)
                .foregroundStyle(Color.cgTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private func benefitRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.cgAccent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.cgTextPrimary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.cgTextSecondary)
            }
            Spacer()
        }
    }

    private var buyButton: some View {
        Button {
            Task {
                if await purchases.purchase() { dismiss() }
            }
        } label: {
            Text(buyTitle)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .background(Color.cgAccent, in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.white)
        .disabled(purchases.isWorking)
    }

    /// Never fabricate a price: show the real localized StoreKit price when it's
    /// loaded, and just "Unlock Everything" until then (prices vary by storefront
    /// and may not be $4.99).
    private var buyTitle: String {
        if purchases.isWorking { return "Please wait…" }
        if let price = purchases.priceText { return "Unlock Everything · \(price)" }
        return "Unlock Everything"
    }

    private var restoreButton: some View {
        Button("Restore Purchase") {
            Task { await purchases.restore() }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.cgAccent)
        .disabled(purchases.isWorking)
    }
}
