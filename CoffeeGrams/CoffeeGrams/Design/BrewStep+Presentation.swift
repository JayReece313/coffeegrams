//
//  BrewStep+Presentation.swift
//  CoffeeGrams
//
//  App-layer, user-facing copy for each brew step. Kept out of CoffeeGramsCore
//  so the domain stays free of UI wording (and so the copy is easy to localize
//  later in one place).
//

import CoffeeGramsCore

// These are pure, UI-free string helpers, so they are `nonisolated` — usable
// from any context despite the app module's main-actor default isolation.
extension BrewStep {
    /// A full-sentence instruction shown as the active step's prompt.
    nonisolated var instruction: String {
        switch self {
        case let .bloom(targetGrams, _):
            "Pour to \(Self.grams(targetGrams)) and let it bloom"
        case let .pour(_, targetCumulativeGrams, _):
            "Pour steadily up to \(Self.grams(targetCumulativeGrams))"
        case .steep:
            "Let it steep"
        case .stir:
            "Give it a gentle stir"
        case .wait:
            "Let the grounds settle"
        case .plunge:
            "Press the plunger down slowly, then tap Done"
        case .drawdown:
            "Let it draw down — tap Done when the drips stop"
        }
    }

    /// The scale target for this step, if it has one (bloom/pour). Shown as a
    /// prominent "pour to N g" cue.
    nonisolated var targetGramsText: String? {
        switch self {
        case let .bloom(targetGrams, _): Self.grams(targetGrams)
        case let .pour(_, targetCumulativeGrams, _): Self.grams(targetCumulativeGrams)
        default: nil
        }
    }

    nonisolated private static func grams(_ value: Double) -> String {
        "\(Int(value.rounded())) g"
    }
}
