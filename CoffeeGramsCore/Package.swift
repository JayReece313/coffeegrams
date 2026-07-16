// swift-tools-version: 6.0
//
// CoffeeGramsCore
// ---------------
// The pure, UI-free heart of CoffeeGrams: brewing data, math, timeline
// generation, and the guided-brew timer state machine.
//
// WHY a separate package (not just app code)?
//   1. It has *zero* SwiftUI/UIKit/SwiftData imports, so it compiles and runs
//      on any platform — including this Mac from the command line via
//      `swift test`. That means every brewing number in the spec is verified
//      by tests long before the iOS UI exists.
//   2. Keeping the logic isolated behind a package boundary is the seam that
//      lets us reuse it later (a widget, a watchOS app) and is exactly the
//      kind of layering a senior reviewer expects.
//
// The iOS app target (built later in Xcode) will add this package as a local
// dependency and provide the "live" implementations of the Ports protocols.

import PackageDescription

let package = Package(
    name: "CoffeeGramsCore",
    // macOS is listed so the suite runs on the command line here; iOS 17 is the
    // real deployment target and unlocks the modern Swift concurrency features
    // the code relies on.
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "CoffeeGramsCore",
            targets: ["CoffeeGramsCore"]
        ),
    ],
    targets: [
        .target(
            name: "CoffeeGramsCore",
            swiftSettings: [
                // Treat the whole module as Swift 6 language mode: strict
                // concurrency checking, so our Sendable model types are
                // verified by the compiler.
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "CoffeeGramsCoreTests",
            dependencies: ["CoffeeGramsCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
