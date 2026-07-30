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

    private let notifications: NotificationScheduling = LiveNotificationService()

    /// Scales the countdown with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 72

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
        .onChange(of: vm.phase) { oldPhase, newPhase in
            handleFrenchPressReminder(from: oldPhase, to: newPhase)
        }
        .onDisappear { notifications.cancel(id: BrewReminder.frenchPressID) }
    }

    /// French press should be plunged promptly or it turns bitter (spec §4.3),
    /// so when a FP brew starts we schedule a "plunge now" reminder for when the
    /// steep ends. It only surfaces if notifications are already authorized — we
    /// don't prompt mid-brew; in the foreground the haptic + timer already cover
    /// it. The reminder is cancelled when the brew finishes or the screen closes.
    private func handleFrenchPressReminder(from old: BrewTimerPhase, to new: BrewTimerPhase) {
        guard vm.timeline.method == .frenchPress else { return }
        if old == .idle, new == .running {
            let reminder = BrewReminder.frenchPressPlunge(
                steepEndsInSeconds: vm.timeline.totalFixedDuration
            )
            Task { await notifications.schedule(reminder) }
        } else if new == .completed || new == .idle {
            notifications.cancel(id: BrewReminder.frenchPressID)
        }
    }

    // MARK: Timer

    private var timerBlock: some View {
        VStack(spacing: 8) {
            Text(statusCaption)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(statusColor)
                .tracking(1.5)

            if let overrun = vm.overrunSeconds {
                // The final step, counting up. The leading "+" is the
                // non-colour cue that this is overrun, not time remaining.
                //
                // HIG — Color: "Avoid using color as the only way to
                // distinguish between elements or convey information."
                // Colour-blind users and anyone in bright sunlight get the
                // same meaning from the "+" prefix and the caption above.
                // https://developer.apple.com/design/human-interface-guidelines/color
                Text("+\(TimeFormat.mmss(overrun))")
                    .font(.system(size: timerSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    // Gold means the clock is live — so a paused count-up goes
                    // neutral, exactly like the paused countdown below.
                    .foregroundStyle(vm.isPaused ? Color.cgTextPrimary : Color.cgTimerActive)
            } else if vm.isAwaitingManualAdvance {
                Text("Your move")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.cgTextPrimary)
            } else {
                Text(TimeFormat.mmss(vm.remainingSeconds))
                    .font(.system(size: timerSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    // Approved design: numerals shift to gold while a phase is
                    // actively counting down (with the caption above as the
                    // required non-colour cue).
                    .foregroundStyle(vm.isRunning ? Color.cgTimerActive : Color.cgTextPrimary)
            }

            if let step = vm.currentStep, !vm.isFinished {
                Text(vm.stepActionEndsBrew ? finalStepInstruction(for: step) : step.instruction)
                    .font(.headline)
                    .foregroundStyle(Color.cgTextSecondary)
                    .multilineTextAlignment(.center)
            } else if vm.isFinished {
                Text("Brew complete — enjoy ☕️")
                    .font(.headline)
                    .foregroundStyle(Color.cgTextSecondary)
            }

            totalElapsedReadout
        }
        .animation(.default, value: vm.currentStepIndex)
        // Read the phase, time, and instruction as one VoiceOver announcement.
        .accessibilityElement(children: .combine)
    }

    /// The master count-up clock. Runs from Start until the brew ends, straight
    /// through overruns and manual holds — the answer to "how long did this brew
    /// actually take?", which the per-step countdown can never give.
    ///
    /// HIG — Accessibility: "Provide alternative text labels for images, icons
    /// and elements." The digits are spelled out for VoiceOver via
    /// `TimeFormat.spoken`, because "2:14" is read aloud as "two colon
    /// fourteen" — useless mid-brew with wet hands.
    /// https://developer.apple.com/design/human-interface-guidelines/accessibility
    @ViewBuilder
    private var totalElapsedReadout: some View {
        if vm.hasStarted || vm.isFinished {
            HStack(spacing: 6) {
                Text("TOTAL")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                Text(TimeFormat.mmss(vm.totalElapsedSeconds))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .foregroundStyle(Color.cgTextSecondary)
            .accessibilityLabel("Total elapsed \(TimeFormat.spoken(vm.totalElapsedSeconds))")
        }
    }

    /// On the last step the instruction changes from "do this" to "tell me when
    /// you're done" — the app is deliberately waiting rather than ending the
    /// brew on your behalf.
    private func finalStepInstruction(for step: BrewStep) -> String {
        "\(step.instruction) — tap Done when you're finished"
    }

    /// The caption deliberately distinguishes the two count-up cases that the
    /// colour treats alike. A *timed* final step really has passed a target, so
    /// "OVER TARGET" is accurate. A manual one (plunge, drawdown) has no target
    /// at all — it is simply being timed — so it keeps the actionable "TAP
    /// DONE"; labelling a freshly-arrived `+0:00` as over target would be a
    /// plain falsehood.
    private var statusCaption: String {
        if vm.isFinished { "DONE" }
        else if vm.isPaused { "PAUSED" }
        else if vm.isOverrunning { "OVER TARGET" }
        else if vm.isAwaitingManualAdvance { "TAP DONE" }
        else if vm.isRunning { "RUNNING" }
        else { "READY" }
    }

    /// Gold whenever the clock is live — counting down *or* up. Keyed off
    /// `isShowingOverrun` rather than the `.overrunning` phase so the caption
    /// can't end up grey beside a gold numeral on a manual final step, which
    /// counts up without ever entering that phase.
    private var statusColor: Color {
        guard !vm.isPaused else { return .cgTextSecondary }
        return (vm.isRunning || vm.isShowingOverrun) ? .cgTimerActive : .cgTextSecondary
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
            brewButton("Start Timer") { vm.start() }
        } else {
            VStack(spacing: 12) {
                // The step's own action, when it has one. Only the final step
                // holds, so in practice this is "Done" — and because it ends
                // the brew anyway, we drop "End Brew" beside it rather than
                // offering two buttons for one outcome.
                //
                // HIG — Buttons: "Use a verb or verb phrase that describes the
                // action" and give each button a distinct, unambiguous title.
                // Two buttons reading "Done" on one screen (step vs whole brew)
                // is precisely the ambiguity that rule exists to prevent.
                // https://developer.apple.com/design/human-interface-guidelines/buttons
                if let advanceTitle = vm.advanceTitle {
                    brewButton(advanceTitle) { vm.resolveCurrentStep() }
                }

                HStack(spacing: 12) {
                    brewButton(
                        vm.isPaused ? "Resume" : "Pause",
                        role: vm.isPaused ? .primary : .secondary
                    ) { vm.togglePause() }

                    if !vm.stepActionEndsBrew {
                        brewButton("End Brew", role: .secondary) { vm.finish() }
                    }
                }

                // Tertiary: leaving a timed step early while it is still
                // counting down. Everything else advances on its own.
                if vm.isRunning {
                    Button("Skip step") { vm.advanceStep() }
                        .font(.subheadline)
                        .foregroundStyle(Color.cgTextSecondary)
                        .accessibilityIdentifier("Skip step")
                }
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
        .accessibilityIdentifier(title)
    }

    private func saveToLog() {
        let entry = BrewLogEntry(
            method: vm.timeline.method,
            doseGrams: doseGrams,
            waterGrams: vm.timeline.totalWaterGrams,
            ratio: ratio,
            plannedSeconds: vm.plannedSeconds,
            actualSeconds: vm.actualSeconds
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
