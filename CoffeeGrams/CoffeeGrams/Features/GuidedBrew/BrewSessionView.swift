//
//  BrewSessionView.swift
//  CoffeeGrams
//
//  Routes a chosen method + dose + ratio to the right guided experience:
//  a step timer (pour-over / immersion), the espresso shot timer, or the cold
//  brew plan. Centralising the switch keeps the calculator screen simple.
//

import SwiftUI
import CoffeeGramsCore

struct BrewSessionView: View {
    let method: BrewMethod
    let doseGrams: Double
    let ratio: Double

    var body: some View {
        switch method {
        case .v60, .chemex, .frenchPress, .aeropress:
            if let timeline = BrewTimelineBuilder.timeline(
                for: method, doseGrams: doseGrams, ratio: ratio
            ) {
                GuidedBrewView(timeline: timeline, doseGrams: doseGrams, ratio: ratio)
            } else {
                // Unreachable for these methods, but we never force-unwrap.
                unavailable
            }
        case .espresso:
            EspressoShotView(
                target: BrewTimelineBuilder.buildEspressoTarget(
                    doseGrams: doseGrams, ratio: ratio
                )
            )
        case .coldBrew:
            ColdBrewPlanView(doseGrams: doseGrams, ratio: ratio)
        }
    }

    private var unavailable: some View {
        ContentUnavailableView(
            "Can't start this brew",
            systemImage: "exclamationmark.triangle",
            description: Text("Enter a valid dose and ratio, then try again.")
        )
    }

    /// The label for the button that launches this session.
    static func startTitle(for method: BrewMethod) -> String {
        switch method {
        case .espresso: "Start Shot"
        case .coldBrew: "View Plan"
        default: "Start Brew"
        }
    }
}
