//
//  GuidedBrewView.swift
//  CoffeeGrams
//
//  The live guided-brew timer for pour-over and immersion methods.
//

import SwiftUI
import SwiftData
import Combine
import CoffeeGramsCore

struct GuidedBrewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm: GuidedBrewViewModel
    @State private var saved = false

    /// Drives the countdown. `tickOnce()` is a no-op unless a step is running,
    /// so we can leave this firing steadily while the screen is visible.
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    /// Dose and ratio are carried so a completed brew can be written to the log.
    private let doseGrams: Double
    private let ratio: Double

    init(timeline: BrewTimeline, doseGrams: Double, ratio: Double) {
        _vm = State(initialValue: GuidedBrewViewModel(timeline: timeline))
        self.doseGrams = doseGrams
        self.ratio = ratio
    }

    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: vm.fractionComplete)
                .tint(.cgAccent)

            timerBlock

            stepList

            Spacer(minLength: 0)

            controls
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cgBackground.ignoresSafeArea())
        .navigationTitle(vm.timeline.method.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(ticker) { _ in vm.tickOnce() }
    }

    // MARK: Timer

    private var timerBlock: some View {
        VStack(spacing: 8) {
            Text(statusCaption)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(statusColor)
                .tracking(1.5)

            if vm.isAwaitingManualAdvance {
                Text("Your move")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.cgTextPrimary)
            } else {
                Text(TimeFormat.mmss(vm.remainingSeconds))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    // Approved design: numerals shift to gold while a phase is
                    // actively counting down (with the caption above as the
                    // required non-colour cue).
                    .foregroundStyle(vm.isRunning ? Color.cgTimerActive : Color.cgTextPrimary)
            }

            if let step = vm.currentStep, !vm.isFinished {
                Text(step.instruction)
                    .font(.headline)
                    .foregroundStyle(Color.cgTextSecondary)
                    .multilineTextAlignment(.center)
            } else if vm.isFinished {
                Text("Brew complete — enjoy ☕️")
                    .font(.headline)
                    .foregroundStyle(Color.cgTextSecondary)
            }
        }
        .animation(.default, value: vm.currentStepIndex)
    }

    private var statusCaption: String {
        if vm.isFinished { "DONE" }
        else if vm.isPaused { "PAUSED" }
        else if vm.isAwaitingManualAdvance { "TAP DONE" }
        else if vm.isRunning { "RUNNING" }
        else { "READY" }
    }

    private var statusColor: Color {
        vm.isRunning ? .cgTimerActive : .cgTextSecondary
    }

    // MARK: Step list

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(vm.steps.enumerated()), id: \.offset) { index, step in
                StepRow(
                    step: step,
                    state: state(for: index)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func state(for index: Int) -> StepRow.State {
        if vm.isFinished || index < vm.currentStepIndex { return .done }
        if index == vm.currentStepIndex && !vm.isIdle { return .current }
        return .upcoming
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        if vm.isFinished {
            VStack(spacing: 12) {
                if saved {
                    Label("Saved to log", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Color.cgAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    brewButton("Save to Log") { saveToLog() }
                }
                brewButton("Brew Again", role: .secondary) {
                    vm.reset()
                    saved = false
                }
            }
        } else if vm.isIdle {
            brewButton("Start Brew") { vm.start() }
        } else if vm.isAwaitingManualAdvance {
            brewButton("Done") { vm.advanceStep() }
        } else {
            HStack(spacing: 12) {
                if vm.isRunning {
                    brewButton("Pause", role: .secondary) { vm.pause() }
                } else {
                    brewButton("Resume") { vm.resume() }
                }
                brewButton("Skip", role: .secondary) { vm.advanceStep() }
            }
        }
    }

    private enum ButtonRole { case primary, secondary }

    private func brewButton(
        _ title: String,
        role: ButtonRole = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .background(
            role == .primary ? Color.cgAccent : Color.cgSurface,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .foregroundStyle(role == .primary ? Color.white : Color.cgTextPrimary)
    }

    private func saveToLog() {
        let entry = BrewLogEntry(
            method: vm.timeline.method,
            doseGrams: doseGrams,
            waterGrams: vm.timeline.totalWaterGrams,
            ratio: ratio
        )
        try? BrewLogStore(context: modelContext).add(entry)
        saved = true
    }
}

/// One row in the step checklist.
private struct StepRow: View {
    enum State { case done, current, upcoming }

    let step: BrewStep
    let state: State

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.body.weight(.semibold))
                .frame(width: 22)

            Text(step.title)
                .font(state == .current ? .body.weight(.bold) : .body)
                .foregroundStyle(textColor)

            Spacer()

            if let target = step.targetGramsText {
                Text(target)
                    .font(.subheadline)
                    .foregroundStyle(Color.cgTextSecondary)
            } else if let duration = step.duration, duration > 0 {
                Text(TimeFormat.mmss(duration))
                    .font(.subheadline)
                    .foregroundStyle(Color.cgTextSecondary)
            }
        }
        .opacity(state == .upcoming ? 0.55 : 1)
    }

    private var iconName: String {
        switch state {
        case .done: "checkmark.circle.fill"
        case .current: "circle.inset.filled"
        case .upcoming: "circle"
        }
    }

    private var iconColor: Color {
        switch state {
        case .done: .cgAccent
        case .current: .cgTimerActive
        case .upcoming: .cgTextSecondary
        }
    }

    private var textColor: Color {
        state == .upcoming ? .cgTextSecondary : .cgTextPrimary
    }
}

#Preview {
    NavigationStack {
        GuidedBrewView(
            timeline: BrewTimelineBuilder.buildPulsePourTimeline(
                profile: .v60, doseGrams: 18, ratio: 16
            ),
            doseGrams: 18,
            ratio: 16
        )
    }
    .fontDesign(.rounded)
    .tint(.cgAccent)
}
