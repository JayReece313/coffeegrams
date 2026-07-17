//
//  Theme.swift
//  CoffeeGrams
//
//  Semantic color tokens for the brand palette (see DESIGN.md).
//
//  Views reference these names, never raw hex. The actual colors — with light
//  and dark variants — live in Assets.xcassets, so re-tuning the brand is a
//  one-place change and Dark Mode comes for free. This indirection (semantic
//  name → asset) is the professional pattern; scattering `Color(red:…)` through
//  views is the trap it avoids.
//

import SwiftUI

extension Color {
    /// 60% — page background (Cream).
    static let cgBackground = Color("Background")
    /// Card / row fill, a touch lighter than the background.
    static let cgSurface = Color("Surface")
    /// 30% — primary text and icons (Espresso Brown).
    static let cgTextPrimary = Color("TextPrimary")
    /// Muted secondary text (Medium Roast Taupe).
    static let cgTextSecondary = Color("TextSecondary")
    /// 10% — actions and highlights (Caramel / Warm Gold).
    static let cgAccent = Color("Accent")
    /// Deeper gold for the large timer numerals while a phase is running
    /// (chosen for contrast on cream — see DESIGN.md).
    static let cgTimerActive = Color("TimerActive")
}
