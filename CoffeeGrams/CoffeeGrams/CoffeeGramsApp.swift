//
//  CoffeeGramsApp.swift
//  CoffeeGrams
//
//  Created by supaa_jarvis on 7/17/26.
//

import SwiftUI
import SwiftData

@main
struct CoffeeGramsApp: App {
    /// `nil` while unit-testing. If the host app also creates a ModelContainer
    /// for BrewLogRecord, then *two* containers for the same @Model coexist with
    /// the per-test containers, which SwiftData traps on (flakily). The unit
    /// tests never render the UI, so during tests we skip the host container
    /// entirely and let each test own the only container in the process.
    ///
    /// CloudKit seam: to sync across the user's devices later, add
    /// `cloudKitDatabase: .automatic` to the ModelConfiguration behind a
    /// Settings toggle (deferred to M7.1 — needs the iCloud capability).
    private let container: ModelContainer?

    init() {
        let isTesting = NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isTesting {
            container = nil
        } else {
            do {
                container = try ModelContainer(for: BrewLogRecord.self)
            } catch {
                fatalError("Failed to create the brew-log store: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            content
        }
    }

    // Rounded system font app-wide for a warmer, premium feel, and the
    // caramel-gold accent for every interactive control, in one place. The
    // SwiftData container is attached here (on the view) so it can be omitted
    // under tests.
    @ViewBuilder
    private var content: some View {
        let root = MethodPickerView()
            .fontDesign(.rounded)
            .tint(.cgAccent)
        if let container {
            root.modelContainer(container)
        } else {
            root
        }
    }
}

// Note: fully branding the navigation bar (cream background + espresso-brown
// large title) via the global UINavigationBarAppearance proxy hides the large
// title under iOS 26 + SwiftUI NavigationStack — the UIKit proxy conflicts with
// SwiftUI's own nav management. Deferred to M11, where the branded header will be
// built as a native SwiftUI view instead of fighting the UIKit appearance API.
// See DESIGN.md.
