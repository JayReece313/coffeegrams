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

        // Skip through the timed steps until the final step's advance button
        // appears. Steps advance on their own, but skipping gets us there in
        // seconds rather than the full brew time. (1.1 renamed "Skip" to
        // "Skip step".) Query by the stable "guidedBrew.advance" identifier,
        // not the "Done" title text — that title is now catalog-localized,
        // so it would break this lookup the day a translation is added.
        for _ in 0..<8 {
            if app.buttons["guidedBrew.advance"].exists { break }
            let skip = app.buttons["Skip step"]
            if skip.exists { skip.tap() } else { break }
        }
        let done = app.buttons["guidedBrew.advance"]
        if done.waitForExistence(timeout: 3) { done.tap() }

        // Save the finished brew.
        let save = app.buttons["Save to Log"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "A finished brew should offer Save to Log")
        save.tap()

        openBrewLog()

        // The saved French Press brew should be listed (i.e. not the empty
        // state). Distinct from a log *row* reading "French Press": the
        // Calculator screen's own nav title also reads "French Press", so
        // that text alone can't tell "opened the log" from "still on
        // Calculator" apart — the empty-state check is what actually does.
        XCTAssertFalse(app.staticTexts["No brews yet"].waitForExistence(timeout: 2),
                       "The log should not be empty after saving a brew")
        XCTAssertTrue(app.navigationBars["Brew Log"].waitForExistence(timeout: 5),
                      "Should be on the log screen (its nav bar), not still on Calculator")
    }

    // MARK: Rating a brew triggers the review-prompt path without regressing

    /// Doesn't (and can't) assert the real StoreKit sheet appears — the API
    /// gives no feedback either way, and Simulator doesn't render it. What
    /// this protects is the flow itself: tapping a star rating on a saved
    /// brew must persist the rating and leave the screen intact, regardless
    /// of whether ReviewPromptTrigger decides to fire underneath it (it
    /// won't, under normal test conditions — a fresh install has neither 3+
    /// completed brews nor 7+ days since first launch).
    @MainActor
    func testRatingABrewDoesNotRegressTheScreen() throws {
        app.buttons["method_french_press"].tap()
        let calcStart = app.buttons["calculatorStartBrew"]
        XCTAssertTrue(calcStart.waitForExistence(timeout: 10))
        calcStart.tap()

        let start = app.buttons["Start Timer"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        for _ in 0..<8 {
            if app.buttons["guidedBrew.advance"].exists { break }
            let skip = app.buttons["Skip step"]
            if skip.exists { skip.tap() } else { break }
        }
        let done = app.buttons["guidedBrew.advance"]
        if done.waitForExistence(timeout: 3) { done.tap() }

        let save = app.buttons["Save to Log"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        openBrewLog()
        let firstRow = app.cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.tap()

        let fiveStars = app.images["5 stars"]
        XCTAssertTrue(fiveStars.waitForExistence(timeout: 5))
        fiveStars.tap()

        // Still on the detail screen (not crashed, not dismissed), and the
        // rating actually reflects the tap.
        XCTAssertTrue(app.buttons["Delete Brew"].waitForExistence(timeout: 5),
                      "Rating shouldn't knock the screen out or crash the app")
        XCTAssertTrue(app.images["5 stars"].waitForExistence(timeout: 2),
                      "The filled 5th star should still be reachable by the same label after the tap")
    }

    // MARK: Helpers

    /// Tap the leading (back) button of the current navigation bar.
    private func navigateBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 5) { back.tap() }
    }

    /// Reaches and opens the brew log from a mid-brew or finished-brew screen.
    ///
    /// On iPhone's NavigationStack, "Brew log" only exists on the home
    /// screen's toolbar, so this needs two pops (guided brew → calculator →
    /// home). On iPad's NavigationSplitView, the button lives in the
    /// always-visible sidebar toolbar, so no pop is needed at all — a fixed
    /// `navigateBack() × 2` doesn't know that, and its second call taps
    /// `navigationBars.buttons.element(boundBy: 0)` blindly, which on iPad
    /// hits whatever sidebar toolbar button is first (e.g. "Unlock Pro"),
    /// not a real back chevron, silently misnavigating.
    private func openBrewLog() {
        for _ in 0..<3 {
            if app.buttons["Brew log"].waitForExistence(timeout: 2) { break }
            navigateBack()
        }
        let log = app.buttons["Brew log"]
        XCTAssertTrue(log.waitForExistence(timeout: 5), "Brew log control should become reachable")
        log.tap()
    }
}
