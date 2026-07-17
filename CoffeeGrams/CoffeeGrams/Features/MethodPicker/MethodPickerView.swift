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
            }
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
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(method.displayName)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Placeholder marker for paid methods. It doesn't lock anything yet —
            // the in-app purchase gating arrives in M9. For now every method is
            // fully usable so we can build and test the flow.
            if !method.isFreeTier {
                Text("PRO")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2), in: Capsule())
            }
        }
        .padding(.vertical, 2)
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
}
