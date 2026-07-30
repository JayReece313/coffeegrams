//
//  CoffeeGramsUITests.swift
//  CoffeeGramsUITests
//
//  End-to-end (system) UI flows, which also serve as UI regression tests.
//
//  Uses XCTest (not Swift Testing): UI automation relies on XCUIApplication /
//  XCUIElement from the XCTest framework, which has no Swift Testing equivalent.
//  Unit tests elsewhere use Swift Testing.
//
//  These drive the real app through the simulator like a user would:
//    • the app launches and shows the branded home + methods
//    • the free method (French Press) opens its calculator
//    • a full guided brew can be run and saved, and appears in the log
//    • a locked (Pro) method presents the paywall
//
//  Selectors use accessibility identifiers where added (e.g. "method_v60",
//  "calculatorStartBrew") and visible button titles otherwise.
//

import XCTest

/// `@MainActor` on the whole class: `XCUIApplication` and every query on it are
/// main-actor isolated, so isolating the test case matches where this code
/// actually runs and keeps Swift 6 strict concurrency quiet.
@MainActor
final class CoffeeGramsUITests: XCTestCase {

    private var app: XCUIApplication!

    // The `async` overload rather than `setUpWithError()`: an async override can
    // carry the class's main-actor isolation, so launching the app here needs no
    // escape hatch. The throwing-but-synchronous overload is forced nonisolated.
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: Smoke — home renders

    @MainActor
    func testHomeShowsBrandAndMethods() throws {
        XCTAssertTrue(app.staticTexts["CoffeeGrams"].waitForExistence(timeout: 10),
                      "Home should show the CoffeeGrams wordmark")
        XCTAssertTrue(app.buttons["method_french_press"].exists,
                      "French Press (the free method) should be listed")
        XCTAssertTrue(app.buttons["method_espresso"].exists,
                      "Espresso (a Pro method) should be listed")
    }

    // MARK: Free method opens its calculator

    @MainActor
    func testFreeMethodOpensCalculator() throws {
        app.buttons["method_french_press"].tap()
        XCTAssertTrue(app.buttons["calculatorStartBrew"].waitForExistence(timeout: 10),
                      "Tapping French Press should open the calculator with a Start button")
    }

    // MARK: Locked method shows the paywall

    @MainActor
    func testLockedMethodShowsPaywall() throws {
        // Espresso is a Pro method; tapping it should present the paywall.
        app.buttons["method_espresso"].tap()
        XCTAssertTrue(app.staticTexts["CoffeeGrams Pro"].waitForExistence(timeout: 10),
                      "Tapping a locked method should present the Pro paywall")
        XCTAssertTrue(app.buttons["Restore Purchase"].exists,
                      "Paywall must offer Restore Purchase")
        // Dismiss and confirm we're back on the list.
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["method_french_press"].waitForExistence(timeout: 5))
    }

    // MARK: Full brew → save → appears in the log (the core system test)

    @MainActor
    func testGuidedBrewSavesToLog() throws {
        // Open the free method and start a guided brew.
        app.buttons["method_french_press"].tap()
        let calcStart = app.buttons["calculatorStartBrew"]
        XCTAssertTrue(calcStart.waitForExistence(timeout: 10))
        calcStart.tap()

        // Begin the timer. (1.1: the calculator button "sets up" the brew, this
        // one starts the clock — the labels must stay distinct.)
        let start = app.buttons["Start Timer"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        // Skip through the timed steps until the final step's "Done" appears.
        // Steps advance on their own, but skipping gets us there in seconds
        // rather than the full brew time. (1.1 renamed "Skip" to "Skip step".)
        for _ in 0..<8 {
            if app.buttons["Done"].exists { break }
            let skip = app.buttons["Skip step"]
            if skip.exists { skip.tap() } else { break }
        }
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 3) { done.tap() }

        // Save the finished brew.
        let save = app.buttons["Save to Log"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "A finished brew should offer Save to Log")
        save.tap()

        // Back to home (guided → calculator → home), then open the log.
        navigateBack()
        navigateBack()
        let log = app.buttons["Brew log"]
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        log.tap()

        // The saved French Press brew should be listed (i.e. not the empty state).
        XCTAssertFalse(app.staticTexts["No brews yet"].waitForExistence(timeout: 2),
                       "The log should not be empty after saving a brew")
        XCTAssertTrue(app.staticTexts["French Press"].exists,
                      "The saved French Press brew should appear in the log")
    }

    // MARK: Helpers

    /// Tap the leading (back) button of the current navigation bar.
    private func navigateBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 5) { back.tap() }
    }
}
