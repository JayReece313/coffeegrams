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
//  They run as part of the normal suite rather than behind an opt-in flag,
//  because their assertions are worth having on every run: each one pins a UI
//  string that 1.1 changed and that a stale App Store screenshot would then
//  misrepresent ("Set Up Brew", the Pause/End Brew pair). The screenshots are a
//  by-product — attachments in the result bundle, which cost nothing to leave
//  there.
//
//  To actually produce upload-ready files, run Releases/screenshots/capture.sh,
//  which pins the status bar to 9:41, runs just these tests, pulls the frames
//  out of the result bundle and fits them to the 1290×2796 upload size.
//

import XCTest

@MainActor
final class ScreenshotCaptureTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
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

        // Let the clock run so TOTAL reads a non-zero time — a frozen 0:00 would
        // undersell the feature the shot exists to show.
        let pause = app.buttons["Pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5), "A running brew should offer Pause")
        XCTAssertTrue(app.buttons["End Brew"].exists, "1.1 pairs Pause with End Brew")
        Thread.sleep(forTimeInterval: 8)

        capture(named: "03-guided-timer")
    }

    // MARK: Helpers

    /// Full-device screenshot at native resolution, kept in the result bundle
    /// even though the test passes (the default discards attachments on success).
    private func capture(named name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
