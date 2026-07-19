//
//  CoffeeGramsUITestsLaunchTests.swift
//  CoffeeGramsUITests
//
//  Created by supaa_jarvis on 7/17/26.
//
//  Uses XCTest (not Swift Testing): launch/UI automation relies on
//  XCUIApplication from the XCTest framework, which has no Swift Testing
//  equivalent. Unit tests elsewhere use Swift Testing.
//

import XCTest

final class CoffeeGramsUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
