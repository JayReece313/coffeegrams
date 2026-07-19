//
//  MethodPickerView.swift
//  CoffeeGrams
//
//  The app's root screen: pick a brew method, then drill into its calculator.
//  Locked (Pro) methods present the paywall instead of navigating.
//

import SwiftUI
import CoffeeGramsCore

struct MethodPickerView: View {
    @Environment(PurchaseController.self) private var purchases
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                brandHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                List(BrewMethod.allCases) { method in
                    row(for: method)
                        .listRowBackground(Color.cgSurface)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(Color.cgBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: BrewMethod.self) { method in
                CalculatorView(method: method)
            }
            .toolbar {
                if !purchases.isPremiumUnlocked {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Unlock Pro", systemImage: "lock.open")
                        }
                        .tint(.cgAccent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        LogView()
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                            .accessibilityLabel("Brew log")
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    /// The brand lockup: the balance-scale logo beside the wordmark, in
    /// espresso. A custom header (not the nav title) so we control the colour —
    /// the nav large title can't be recoloured reliably under iOS 26.
    private var brandHeader: some View {
        HStack(spacing: 12) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
            Text("CoffeeGrams")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.cgTextPrimary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// A navigable row for accessible methods; a paywall-triggering button for
    /// locked ones.
    @ViewBuilder
    private func row(for method: BrewMethod) -> some View {
        if purchases.canAccess(method) {
            NavigationLink(value: method) {
                MethodRow(method: method, locked: false)
            }
        } else {
            Button {
                showPaywall = true
            } label: {
                MethodRow(method: method, locked: true)
            }
        }
    }
}

/// One row in the method list.
private struct MethodRow: View {
    let method: BrewMethod
    let locked: Bool

    private var profile: BrewMethodProfile { .profile(for: method) }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: method.iconSystemName)
                .font(.title2)
                .foregroundStyle(Color.cgTextPrimary)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(method.displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.cgTextPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.cgTextSecondary)
            }

            Spacer()

            if locked {
                Label("PRO", systemImage: "lock.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.cgAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cgAccent.opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 6)
        // Locked rows still read their normal colour; the lock chip conveys state
        // (plus the paywall on tap), so we don't rely on colour alone.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(locked ? "\(method.displayName), Pro, locked" : method.displayName)
        .accessibilityHint(locked
            ? "Unlock with CoffeeGrams Pro"
            : "Opens the \(method.displayName) calculator")
    }

    private var subtitle: String {
        "\(brewTypeName) · default 1:\(Int(profile.defaultRatio))"
    }

    private var brewTypeName: String {
        switch profile.brewType {
        case .pulsePour: "Pour-over"
        case .immersion: "Immersion"
        case .pressure: "Espresso"
        }
    }
}

#Preview {
    MethodPickerView()
        .environment(PurchaseController(provider: PreviewPurchaseProvider()))
        .fontDesign(.rounded)
        .tint(.cgAccent)
}

/// A preview-only provider so the picker renders without StoreKit.
private struct PreviewPurchaseProvider: PurchaseProviding {
    func isPurchased() async -> Bool { false }
    func localizedPrice() async -> String? { "$4.99" }
    func purchase() async throws -> PurchaseOutcome { .purchased }
    func restore() async -> Bool { false }
    func entitlementUpdates() -> AsyncStream<Bool> { AsyncStream { $0.finish() } }
}
