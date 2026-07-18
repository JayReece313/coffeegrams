//
//  EspressoShotView.swift
//  CoffeeGrams
//
//  The deliberately-shallow espresso screen: target yield + a shot stopwatch
//  that reads green inside the 25–30s window.
//

import SwiftUI
import SwiftData
import Combine
import CoffeeGramsCore

struct EspressoShotView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm: EspressoShotViewModel
    @State private var saved = false

    /// Drives the shot stopwatch; `tickOnce()` no-ops unless the shot is running.
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    /// Scales the stopwatch with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 96

    init(target: EspressoTarget) {
        _vm = State(initialValue: EspressoShotViewModel(target: target))
    }

    var body: some View {
        VStack(spacing: 28) {
            targetCard

            VStack(spacing: 6) {
                Text(stateCaption)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(stateColor)
                    .tracking(1.5)

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(vm.elapsedSeconds)")
                        .font(.system(size: timerSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(vm.hasStarted ? stateColor : Color.cgTextPrimary)
                    Text("s")
                        .font(.title)
                        .foregroundStyle(Color.cgTextSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(stateCaption), \(vm.elapsedSeconds) seconds")

            Text("Target window \(vm.target.shotTimeRange.lowerBound)–\(vm.target.shotTimeRange.upperBound)s")
                .font(.subheadline)
                .foregroundStyle(Color.cgTextSecondary)

            Spacer(minLength: 0)

            Button(action: { vm.startOrStop() }) {
                Text(vm.isRunning ? "Stop" : "Start Shot")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(Color.cgAccent, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)

            if vm.hasStarted && !vm.isRunning {
                if saved {
                    Label("Saved to log", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.cgAccent)
                } else {
                    Button("Save to Log") { saveToLog() }
                        .font(.headline)
                        .foregroundStyle(Color.cgAccent)
                }
                Button("Reset") { vm.reset(); saved = false }
                    .foregroundStyle(Color.cgTextSecondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cgBackground.ignoresSafeArea())
        .navigationTitle("Espresso")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(ticker) { _ in vm.tickOnce() }
    }

    private var targetCard: some View {
        HStack(spacing: 24) {
            metric("Dose", "\(Int(vm.target.doseGrams.rounded())) g")
            Image(systemName: "arrow.right")
                .foregroundStyle(Color.cgTextSecondary)
            metric("Yield", "\(Int(vm.target.targetYieldGrams.rounded())) g")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.cgSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cgTextSecondary)
            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(Color.cgTextPrimary)
        }
    }

    private func saveToLog() {
        let entry = BrewLogEntry(
            method: .espresso,
            doseGrams: vm.target.doseGrams,
            waterGrams: vm.target.targetYieldGrams,
            ratio: vm.target.ratio,
            shotSeconds: vm.elapsedSeconds
        )
        try? BrewLogStore(context: modelContext).add(entry)
        saved = true
    }

    // MARK: Shot-window state → colour + caption

    private var stateCaption: String {
        guard vm.hasStarted else { return "READY" }
        return switch vm.timingState {
        case .tooEarly: "BUILDING"
        case .onTarget: "ON TARGET"
        case .tooLate: "RUNNING LONG"
        }
    }

    /// Status colours (green/amber/red) are intentionally outside the brand
    /// palette — they convey meaning, and the caption above carries the same
    /// information in words for accessibility.
    private var stateColor: Color {
        guard vm.hasStarted else { return .cgTextSecondary }
        return switch vm.timingState {
        case .tooEarly: .orange
        case .onTarget: .green
        case .tooLate: .red
        }
    }
}

#Preview {
    NavigationStack {
        EspressoShotView(
            target: BrewTimelineBuilder.buildEspressoTarget(doseGrams: 18, ratio: 2)
        )
    }
    .fontDesign(.rounded)
    .tint(.cgAccent)
}
