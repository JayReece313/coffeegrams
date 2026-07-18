//
//  ColdBrewPlanView.swift
//  CoffeeGrams
//
//  Cold brew is a 12–24h steep, so there is no live timer (spec §4.5). This
//  screen shows the recipe and steep length; the actual "steep is done" local
//  notification is wired up in M8.
//

import SwiftUI
import SwiftData
import CoffeeGramsCore

struct ColdBrewPlanView: View {
    let doseGrams: Double
    let ratio: Double

    @Environment(\.modelContext) private var modelContext
    @State private var steepHours: Double = 16
    @State private var saved = false

    private var waterGrams: Double {
        BrewCalculator.waterGrams(doseGrams: doseGrams, ratio: ratio)
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                metric("Coffee", "\(Int(doseGrams.rounded())) g")
                metric("Water", "\(Int(waterGrams.rounded())) g")
                metric("Ratio", "1:\(Int(ratio.rounded()))")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.cgSurface, in: RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 10) {
                Text("STEEP TIME")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.cgTextSecondary)
                    .tracking(1)
                Text("\(Int(steepHours)) hours")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.cgTextPrimary)
                Slider(value: $steepHours, in: 12...24, step: 1) {
                    Text("Steep hours")
                } minimumValueLabel: {
                    Text("12h").foregroundStyle(Color.cgTextSecondary)
                } maximumValueLabel: {
                    Text("24h").foregroundStyle(Color.cgTextSecondary)
                }
            }
            .padding(20)
            .background(Color.cgSurface, in: RoundedRectangle(cornerRadius: 16))

            Label(
                "Combine coarse grounds with cold water, then refrigerate. You'll get a reminder when the steep is done.",
                systemImage: "bell.badge"
            )
            .font(.subheadline)
            .foregroundStyle(Color.cgTextSecondary)
            .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            if saved {
                Label("Saved to log", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.cgAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                Button(action: saveToLog) {
                    Text("Save to Log")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .background(Color.cgAccent, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cgBackground.ignoresSafeArea())
        .navigationTitle("Cold Brew")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveToLog() {
        let entry = BrewLogEntry(
            method: .coldBrew,
            doseGrams: doseGrams,
            waterGrams: waterGrams,
            ratio: ratio
        )
        try? BrewLogStore(context: modelContext).add(entry)
        saved = true
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cgTextSecondary)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.cgTextPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        ColdBrewPlanView(doseGrams: 100, ratio: 5)
    }
    .fontDesign(.rounded)
    .tint(.cgAccent)
}
