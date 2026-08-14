//
//  ScreenshotCaptureTests.swift
//  CoffeeGramsUITests
//
//  The App Store screenshot harness.
//
//  Replaces the temporary in-app `CG_SHOT` switch used for the 1.0 set (see
//  Releases/screenshots/README.md), which had to be added to the *app* target
//  before a capture and deleted afterwards. Driving the real UI from the UI-test
//  target instead means no capture-only code ever exists in the shipping binary,
//  and the shots are of the same build a reviewer will run.
//
//  The *assertions* run in every suite, because each one pins a UI string that
//  1.1 changed and that a stale App Store screenshot would then misrepresent
//  ("Set Up Brew", the Pause/End Brew pair). That's the guard against the
//  listing drifting from the build again.
//
//  The *shutter* is opt-in: only with CG_CAPTURE=1 in the environment do these
//  take screenshots, keep attachments, or wait for the clock to advance. A
//  normal `xcodebuild test` therefore pays none of that cost.
//
//  To produce upload-ready files, run Releases/screenshots/capture.sh, which
//  sets that flag, pins the status bar to 9:41, builds Release so the shots are
//  of the configuration that ships, pulls the frames out of the result bundle
//  and fits them to the 1290×2796 upload size.
//

import XCTest

@MainActor
final class ScreenshotCaptureTests: XCTestCase {

    private var app: XCUIApplication!

    /// Whether this run is producing App Store assets or just checking the UI.
    ///
    /// capture.sh sets `TEST_RUNNER_CG_CAPTURE=1`, which xcodebuild forwards
    /// into the runner's environment with the prefix stripped. Off (the normal
    /// suite) the assertions still run — they're the point — but the shutter,
    /// the attachments and the wait that makes TOTAL non-zero are all skipped,
    /// so the suite stays fast and result bundles stay small.
    private var isCapturing: Bool {
        ProcessInfo.processInfo.environment["CG_CAPTURE"] == "1"
    }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: 01 — Home

    /// Just the launch state: branded header (or, on iPad, the split-view
    /// sidebar + empty detail pane) with the method list and its Pro locks.
    func testCaptureHome() throws {
        XCTAssertTrue(app.staticTexts["CoffeeGrams"].waitForExistence(timeout: 10),
                      "Home should show the CoffeeGrams wordmark")
        XCTAssertTrue(app.buttons["method_french_press"].exists,
                      "French Press (the free method) should be listed")

        capture(named: "01-home")
    }

    // MARK: 02 — Calculator

    /// French Press at its defaults: 18 g → 270 g at 1:15, and the 1.1 "Set Up
    /// Brew" call to action that replaced 1.0's "Start Brew".
    func testCaptureCalculator() throws {
        app.buttons["method_french_press"].tap()

        let cta = app.buttons["calculatorStartBrew"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10), "Calculator should be up")
        XCTAssertEqual(cta.label, "Set Up Brew",
                       "1.1 renamed this button; the screenshot must show the new label")

        capture(named: "02-calculator")
    }

    // MARK: 03 — Guided timer

    /// A brew mid-flight, which is where every 1.1 timer change is visible: the
    /// TOTAL count-up, and the Pause/End Brew control row that replaced
    /// Pause/Skip.
    func testCaptureGuidedTimer() throws {
        app.buttons["method_french_press"].tap()

        let cta = app.buttons["calculatorStartBrew"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10))
        cta.tap()

        let start = app.buttons["Start Timer"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        // Both controls are conditional on brew state, so synchronise on each
        // rather than reading `.exists` the instant the tap returns.
        let pause = app.buttons["Pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5), "A running brew should offer Pause")
        XCTAssertTrue(app.buttons["End Brew"].waitForExistence(timeout: 5),
                      "1.1 pairs Pause with End Brew")

        // Only when shooting: let the clock run so TOTAL reads a non-zero time.
        // A frozen 0:00 would undersell the feature the shot exists to show.
        if isCapturing { Thread.sleep(forTimeInterval: 8) }

        capture(named: "03-guided-timer")
    }

    // MARK: 04 — Paywall

    /// Espresso is a Pro method; tapping it presents the paywall directly
    /// (no calculator screen involved for a locked method).
    func testCapturePaywall() throws {
        app.buttons["method_espresso"].tap()
        XCTAssertTrue(app.staticTexts["CoffeeGrams Pro"].waitForExistence(timeout: 10),
                      "Tapping a locked method should present the Pro paywall")

        capture(named: "04-paywall")
    }

    // MARK: 05 — Brew log

    /// A single saved brew — enough to show the populated (non-empty) state.
    /// The current iPhone asset shows several rated, annotated brews; this
    /// one doesn't script a rating or notes (no accessibility identifiers on
    /// StarRating yet), so it's a plainer version of the same scene.
    func testCaptureBrewLog() throws {
        app.buttons["method_french_press"].tap()
        let cta = app.buttons["calculatorStartBrew"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10))
        cta.tap()

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

        // Distinct from a log *row* reading "French Press": the Calculator
        // screen's own nav title also reads "French Press", so checking for
        // that text can't tell "opened the log" from "still on Calculator"
        // apart. The nav bar title and the empty-state check both can.
        XCTAssertTrue(app.navigationBars["Brew Log"].waitForExistence(timeout: 5),
                      "Should be on the log screen, not still on Calculator")
        XCTAssertFalse(app.staticTexts["No brews yet"].waitForExistence(timeout: 2),
                       "The just-saved brew should make the log non-empty")

        capture(named: "05-brew-log")
    }

    // MARK: Helpers

    private func navigateBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 5) { back.tap() }
    }

    /// See CoffeeGramsUITests.openBrewLog — same fix, duplicated rather than
    /// shared across these two independent XCTestCase classes: on iPhone,
    /// "Brew log" only exists on the home screen's toolbar (needs two pops);
    /// on iPad's split view it's in the always-visible sidebar (needs none).
    /// A fixed pop count taps the wrong sidebar toolbar button on iPad.
    private func openBrewLog() {
        for _ in 0..<3 {
            if app.buttons["Brew log"].waitForExistence(timeout: 2) { break }
            navigateBack()
        }
        let log = app.buttons["Brew log"]
        XCTAssertTrue(log.waitForExistence(timeout: 5), "Brew log control should become reachable")
        log.tap()
    }

    /// Full-device screenshot at native resolution, kept in the result bundle
    /// even though the test passes (the default discards attachments on
    /// success). A no-op outside a capture run, so normal suites don't carry
    /// full-resolution PNGs around.
    private func capture(named name: String) {
        guard isCapturing else { return }
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
