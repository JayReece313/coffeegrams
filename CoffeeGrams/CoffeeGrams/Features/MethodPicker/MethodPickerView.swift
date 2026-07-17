//
//  MethodPickerView.swift
//  CoffeeGrams
//
//  The app's root screen: pick a brew method, then drill into its calculator.
//

import SwiftUI
import CoffeeGramsCore

struct MethodPickerView: View {
    var body: some View {
        // NavigationStack manages a push/pop navigation hierarchy. Tapping a row
        // pushes the matching CalculatorView via the value-based destination
        // below (a type-safe alternative to wiring each NavigationLink by hand).
        NavigationStack {
            List(BrewMethod.allCases) { method in
                NavigationLink(value: method) {
                    MethodRow(method: method)
                }
                .listRowBackground(Color.cgSurface)
            }
            .listStyle(.insetGrouped)
            // Hide the system grouped background so our cream shows through.
            .scrollContentBackground(.hidden)
            .background(Color.cgBackground.ignoresSafeArea())
            .navigationTitle("CoffeeGrams")
            .navigationDestination(for: BrewMethod.self) { method in
                CalculatorView(method: method)
            }
        }
    }
}

/// One row in the method list.
private struct MethodRow: View {
    let method: BrewMethod

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

            // Placeholder marker for paid methods. It doesn't lock anything yet —
            // the in-app purchase gating arrives in M9. Gold here is one of the
            // few accent uses, keeping to the 60-30-10 discipline.
            if !method.isFreeTier {
                Text("PRO")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.cgAccent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.cgAccent.opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 6)
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
        .fontDesign(.rounded)
        .tint(.cgAccent)
}
