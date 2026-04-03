//
//  NoumUITests.swift
//  NoumUITests
//
//  Created by Jordan Coaten on 25/01/2025.
//

import XCTest

final class NoumUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testLaunchToTimedPracticeSmoke() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UI_TESTING")
        app.launch()

        XCTAssertTrue(app.buttons["home.startPracticing"].waitForExistence(timeout: 5))
        app.buttons["home.startPracticing"].tap()

        XCTAssertTrue(app.navigationBars["Practice Modes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["practiceMode.timed"].waitForExistence(timeout: 5))
        app.buttons["practiceMode.timed"].tap()

        XCTAssertTrue(app.buttons["practiceModes.start"].waitForExistence(timeout: 5))
        app.buttons["practiceModes.start"].tap()

        XCTAssertTrue(app.otherElements["timedPractice.screen"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOnboardingFlowSmoke() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_ONBOARDING"]
        app.launch()

        XCTAssertTrue(app.buttons["coaching.start"].waitForExistence(timeout: 5))
        app.buttons["coaching.start"].tap()

        XCTAssertTrue(app.buttons["coaching.continue"].waitForExistence(timeout: 5))
        app.buttons["coaching.continue"].tap()
        app.buttons["coaching.continue"].tap()
        app.buttons["coaching.continue"].tap()

        let goalField = app.textViews["coaching.goal"]
        XCTAssertTrue(goalField.waitForExistence(timeout: 5))
        goalField.tap()
        goalField.typeText("Lead updates in meetings without second-guessing every sentence.")
        app.buttons["Done"].tap()
        app.buttons["coaching.continue"].tap()

        let whyNowField = app.textViews["coaching.whyNow"]
        XCTAssertTrue(whyNowField.waitForExistence(timeout: 5))
        whyNowField.tap()
        whyNowField.typeText("I need to sound sharper in high-visibility conversations.")
        app.buttons["Done"].tap()
        app.buttons["coaching.continue"].tap()

        let successVisionField = app.textViews["coaching.successVision"]
        XCTAssertTrue(successVisionField.waitForExistence(timeout: 5))
        successVisionField.tap()
        successVisionField.typeText("I will feel calmer, clearer, and more credible at work.")
        app.buttons["Done"].tap()
        app.buttons["coaching.continue"].tap()

        XCTAssertTrue(app.buttons["coaching.save"].isEnabled)
        app.buttons["coaching.save"].tap()
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 17.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
