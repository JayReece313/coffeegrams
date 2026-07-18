//
//  ColdBrewPlanView.swift
//  CoffeeGrams
//
//  Cold brew is a 12–24h steep, so there is no live timer (spec §4.5). This
//  screen shows the recipe and steep length, and "Start Steep" schedules a local
//  notification for when it's done plus saves the brew to the log.
//

import SwiftUI
import SwiftData
import CoffeeGramsCore

struct ColdBrewPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm: ColdBrewViewModel
    @State private var started = false

    init(doseGrams: Double, ratio: Double) {
        _vm = State(initialValue: ColdBrewViewModel(doseGrams: doseGrams, ratio: ratio))
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                metric("Coffee", "\(Int(vm.doseGrams.rounded())) g")
                metric("Water", "\(Int(vm.waterGrams.rounded())) g")
                metric("Ratio", "1:\(Int(vm.ratio.rounded()))")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.cgSurface, in: RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 10) {
                Text("STEEP TIME")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.cgTextSecondary)
                    .tracking(1)
                Text("\(Int(vm.steepHours)) hours")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.cgTextPrimary)
                Slider(value: $vm.steepHours, in: 12...24, step: 1) {
                    Text("Steep hours")
                } minimumValueLabel: {
                    Text("12h").foregroundStyle(Color.cgTextSecondary)
                } maximumValueLabel: {
                    Text("24h").foregroundStyle(Color.cgTextSecondary)
                }
                .disabled(started)
            }
            .padding(20)
            .background(Color.cgSurface, in: RoundedRectangle(cornerRadius: 16))

            Label(
                "Combine coarse grounds with cold water, then refrigerate.",
                systemImage: "cup.and.saucer"
            )
            .font(.subheadline)
            .foregroundStyle(Color.cgTextSecondary)
            .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            primaryAction
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cgBackground.ignoresSafeArea())
        .navigationTitle("Cold Brew")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var primaryAction: some View {
        if started {
            confirmation
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        } else {
            Button {
                Task {
                    await vm.startSteep()
                    saveToLog()
                    started = true
                }
            } label: {
                Text("Start Steep")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(Color.cgAccent, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var confirmation: some View {
        switch vm.reminderState {
        case .scheduled(let hours):
            Label("Saved · reminder set for \(hours)h", systemImage: "bell.badge.fill")
                .foregroundStyle(Color.cgAccent)
        case .denied:
            Label("Saved · enable notifications in Settings for a reminder", systemImage: "bell.slash")
                .foregroundStyle(Color.cgTextSecondary)
        case .idle:
            Label("Saved to log", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.cgAccent)
        }
    }

    private func saveToLog() {
        let entry = BrewLogEntry(
            method: .coldBrew,
            doseGrams: vm.doseGrams,
            waterGrams: vm.waterGrams,
            ratio: vm.ratio
        )
        try? BrewLogStore(context: modelContext).add(entry)
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
