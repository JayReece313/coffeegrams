//
//  Haptics.swift
//  CoffeeGrams
//
//  A tiny abstraction over haptic feedback so view models can request a buzz
//  without depending on UIKit directly — and so tests can inject a silent
//  version.
//

import UIKit

/// Something that can produce haptic feedback. Main-actor isolated because the
/// UIKit feedback generators must be used on the main thread.
@MainActor
protocol HapticsPerforming {
    /// A light tap when the brew advances to a new step.
    func stepChange()
    /// A success buzz when the whole brew finishes.
    func finished()
}

/// Real device haptics.
struct LiveHaptics: HapticsPerforming {
    func stepChange() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func finished() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

/// No-op haptics for previews and unit tests (no device, no side effects).
struct NoHaptics: HapticsPerforming {
    func stepChange() {}
    func finished() {}
}
