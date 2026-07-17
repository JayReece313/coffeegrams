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
        }
    }
}
