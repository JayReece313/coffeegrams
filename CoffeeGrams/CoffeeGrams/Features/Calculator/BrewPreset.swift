//
//  BrewPreset.swift
//  CoffeeGrams
//
//  Named recipe presets. AeroPress culture is genuinely split on ratio and
//  technique (spec §4.4), so rather than pick one "correct" number we offer a
//  couple of well-known starting points on top of the raw ratio slider.
//

import Foundation
import CoffeeGramsCore

struct BrewPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let doseGrams: Double
    let ratio: Double

    init(name: String, doseGrams: Double, ratio: Double) {
        self.id = name
        self.name = name
        self.doseGrams = doseGrams
        self.ratio = ratio
    }
}

enum BrewPresets {
    /// Presets to offer for a given method, or empty if it has none.
    static func presets(for method: BrewMethod) -> [BrewPreset] {
        switch method {
        case .aeropress: aeroPress
        default: []
        }
    }

    /// AeroPress: Hoffmann's clean 1:18 and a classic strong 1:12.
    static let aeroPress: [BrewPreset] = [
        BrewPreset(name: "Hoffmann", doseGrams: 11, ratio: 18),
        BrewPreset(name: "Classic Strong", doseGrams: 15, ratio: 12),
    ]
}
