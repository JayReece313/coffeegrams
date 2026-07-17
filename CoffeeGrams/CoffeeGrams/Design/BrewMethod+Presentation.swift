//
//  BrewMethod+Presentation.swift
//  CoffeeGrams
//
//  App-layer presentation details for the domain's BrewMethod. These live in
//  the app (not in CoffeeGramsCore) to keep the domain model free of UI
//  concerns.
//

import CoffeeGramsCore

extension BrewMethod {
    /// SF Symbol used as a **placeholder** icon next to each method.
    ///
    /// Per DESIGN.md these are stand-ins until the custom vector method icons
    /// (a real Chemex / V60 silhouette, etc.) are drawn in M11. SF Symbols are
    /// used because they render crisply at any size and tint with the palette.
    var iconSystemName: String {
        switch self {
        case .v60: "triangle.fill"          // cone dripper
        case .chemex: "hourglass"            // hourglass silhouette
        case .frenchPress: "cylinder.fill"   // carafe
        case .aeropress: "capsule.fill"      // plunger tube
        case .coldBrew: "snowflake"          // served cold
        case .espresso: "cup.and.saucer.fill"
        }
    }
}
