//
//  CalculatorViewModel.swift
//  CoffeeGrams
//
//  The "VM" in MVVM: presentation state + logic for the brew calculator,
//  with no SwiftUI dependency so it can be unit-tested on its own.
//

import Foundation
import Observation
import CoffeeGramsCore

/// Drives the calculator screen.
///
/// It owns the values the user manipulates (method, direction, dose, target
/// yield, ratio) and *derives* the results by calling the already-tested
/// `BrewCalculator` in `CoffeeGramsCore`. Keeping this out of the view is what
/// makes the numbers testable and keeps the SwiftUI layer a thin description of
/// the UI.
///
/// `@Observable` (Apple's Observation framework) lets SwiftUI automatically
/// re-render any view that reads a property whenever that property changes — no
/// manual notification code. The type is main-actor isolated (the app's default
/// in this project), which is correct for UI state.
@Observable
final class CalculatorViewModel {

    /// Which way the user is calculating.
    enum Mode: String, CaseIterable, Identifiable {
        /// Enter coffee grams, get water (or espresso yield).
        case doseFirst
        /// Enter the desired output, get the coffee dose.
        case yieldFirst

        var id: String { rawValue }
        var title: String {
            switch self {
            case .doseFirst: "Dose → Water"
            case .yieldFirst: "Water → Dose"
            }
        }
    }

    // MARK: - Inputs (bound to controls in the view)

    /// The chosen brew method. `private(set)` because callers change it through
    /// `selectMethod(_:)`, which also fixes up the ratio — a plain setter could
    /// leave the ratio outside the new method's valid range.
    private(set) var method: BrewMethod
    var mode: Mode = .doseFirst
    var doseGrams: Double
    var targetYieldGrams: Double
    var ratio: Double

    init(
        method: BrewMethod = .v60,
        doseGrams: Double = 18,
        targetYieldGrams: Double = 300
    ) {
        self.method = method
        self.doseGrams = doseGrams
        self.targetYieldGrams = targetYieldGrams
        self.ratio = BrewMethodProfile.profile(for: method).defaultRatio
    }

    // MARK: - Method selection

    /// Switch method and reset the ratio to that method's default. Each method
    /// has a different valid ratio range (e.g. espresso 1:1–1:3 vs V60
    /// 1:15–1:17), so carrying the old ratio over could land out of range.
    func selectMethod(_ newMethod: BrewMethod) {
        method = newMethod
        ratio = profile.defaultRatio
    }

    // MARK: - Derived configuration

    var profile: BrewMethodProfile { .profile(for: method) }
    var ratioRange: ClosedRange<Double> { profile.ratioRange }

    /// Slider granularity — espresso is dialled in finer steps than brewed
    /// ratios, where whole/half numbers are plenty.
    var ratioStep: Double { method == .espresso ? 0.25 : 0.5 }

    /// "1:16"-style label. Whole numbers show no decimal; fractional show one.
    var ratioLabel: String {
        let whole = ratio == ratio.rounded()
        let value = whole ? String(format: "%.0f", ratio) : String(format: "%.1f", ratio)
        return "1:\(value)"
    }

    /// Espresso produces *yield* under pressure; the others add *water*.
    var waterOrYieldLabel: String { method == .espresso ? "Yield" : "Water" }

    // MARK: - Results (delegated to the tested core calculator)

    var computedWaterGrams: Double {
        BrewCalculator.waterGrams(doseGrams: doseGrams, ratio: ratio)
    }

    var computedDoseGrams: Double {
        BrewCalculator.doseGrams(targetYieldGrams: targetYieldGrams, ratio: ratio, method: method)
    }

    /// The headline number, given the current direction.
    var resultGrams: Double {
        switch mode {
        case .doseFirst: computedWaterGrams
        case .yieldFirst: computedDoseGrams
        }
    }

    /// Label for `resultGrams`.
    var resultLabel: String {
        switch mode {
        case .doseFirst: waterOrYieldLabel
        case .yieldFirst: "Coffee"
        }
    }
}
