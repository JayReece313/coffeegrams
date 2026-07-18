//
//  CalculatorView.swift
//  CoffeeGrams
//
//  The "View" in MVVM: a thin, declarative description of the calculator UI.
//  It holds no brewing logic — it renders the ViewModel and forwards edits.
//

import SwiftUI
import CoffeeGramsCore

struct CalculatorView: View {

    /// `@State` owns the ViewModel for this screen's lifetime. With `@Observable`
    /// view models this is the modern replacement for `@StateObject`. The `$`
    /// projection gives us two-way `Binding`s into the VM's properties (a
    /// Binding is a read/write handle SwiftUI controls use to edit state).
    @State private var vm: CalculatorViewModel
    /// Drives navigation into the guided brew session.
    @State private var startBrew = false

    init(method: BrewMethod) {
        _vm = State(initialValue: CalculatorViewModel(method: method))
    }

    var body: some View {
        Form {
            Section {
                ResultView(grams: vm.resultGrams, label: vm.resultLabel)
            }
            .listRowBackground(Color.cgSurface)

            Section {
                Picker("Mode", selection: $vm.mode) {
                    ForEach(CalculatorViewModel.Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                sectionHeader("Direction")
            }
            .listRowBackground(Color.cgSurface)

            Section {
                HStack {
                    TextField("Grams", value: inputBinding, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title3)
                        .foregroundStyle(Color.cgTextPrimary)
                    Text("g").foregroundStyle(Color.cgTextSecondary)
                }
            } header: {
                sectionHeader(inputSectionTitle)
            }
            .listRowBackground(Color.cgSurface)

            Section {
                Slider(
                    value: $vm.ratio,
                    in: vm.ratioRange,
                    step: vm.ratioStep
                ) {
                    Text("Ratio")
                } minimumValueLabel: {
                    Text("1:\(Int(vm.ratioRange.lowerBound))")
                        .foregroundStyle(Color.cgTextSecondary)
                } maximumValueLabel: {
                    Text("1:\(Int(vm.ratioRange.upperBound))")
                        .foregroundStyle(Color.cgTextSecondary)
                }
            } header: {
                sectionHeader("Ratio  \(vm.ratioLabel)")
            }
            .listRowBackground(Color.cgSurface)

            Section {
                Button { startBrew = true } label: {
                    Text(BrewSessionView.startTitle(for: vm.method))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cgAccent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.cgBackground.ignoresSafeArea())
        .navigationTitle(vm.method.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $startBrew) {
            BrewSessionView(method: vm.method, doseGrams: vm.doseGrams, ratio: vm.ratio)
        }
    }

    /// A consistently styled section header in the muted secondary tone.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.cgTextSecondary)
    }

    /// Section header for the input field, which changes with the direction.
    private var inputSectionTitle: String {
        switch vm.mode {
        case .doseFirst: "Coffee dose"
        case .yieldFirst: "Target \(vm.waterOrYieldLabel.lowercased())"
        }
    }

    /// The same field edits either the dose or the target yield depending on the
    /// chosen direction, so we hand it whichever binding is active.
    private var inputBinding: Binding<Double> {
        switch vm.mode {
        case .doseFirst: $vm.doseGrams
        case .yieldFirst: $vm.targetYieldGrams
        }
    }
}

/// The headline result readout — the biggest, boldest thing on the screen.
private struct ResultView: View {
    let grams: Double
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.cgTextSecondary)
            (
                Text(grams, format: .number.precision(.fractionLength(0)))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                + Text(" g")
                    .font(.title2)
                    .foregroundStyle(Color.cgTextSecondary)
            )
            .foregroundStyle(Color.cgTextPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        // One combined element so VoiceOver reads "Water, 288 grams" not three
        // separate fragments. (Full accessibility pass happens in M10.)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(Int(grams.rounded())) grams")
    }
}

#Preview {
    NavigationStack {
        CalculatorView(method: .v60)
    }
    .fontDesign(.rounded)
    .tint(.cgAccent)
}
