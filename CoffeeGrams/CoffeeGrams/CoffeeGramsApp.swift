//
//  CoffeeGramsApp.swift
//  CoffeeGrams
//
//  Created by supaa_jarvis on 7/17/26.
//

import SwiftUI

@main
struct CoffeeGramsApp: App {
    var body: some Scene {
        WindowGroup {
            // The method picker is the root; it contains its own NavigationStack.
            MethodPickerView()
                // Rounded system font app-wide for a warmer, premium feel, and
                // the caramel-gold accent for every interactive control (slider,
                // selected segment, back button) in one place.
                .fontDesign(.rounded)
                .tint(.cgAccent)
        }
    }
}

// Note: fully branding the navigation bar (cream background + espresso-brown
// large title) via the global UINavigationBarAppearance proxy hides the large
// title under iOS 26 + SwiftUI NavigationStack — the UIKit proxy conflicts with
// SwiftUI's own nav management. Deferred to M11, where the branded header will be
// built as a native SwiftUI view instead of fighting the UIKit appearance API.
// See DESIGN.md.
