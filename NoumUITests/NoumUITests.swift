import XCTest

final class NoumUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeScreenAndPrimaryNavigation() throws {
        let app = launchApp()

        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))

        app.otherElements["home.path"].tap()
        XCTAssertTrue(app.otherElements["journey.screen"].waitForExistence(timeout: 5))

        app.terminate()
        let rankApp = launchApp()
        XCTAssertTrue(rankApp.otherElements["home.rank"].waitForExistence(timeout: 5))
        rankApp.otherElements["home.rank"].tap()
        XCTAssertTrue(rankApp.otherElements["rank.screen"].waitForExistence(timeout: 5))

        rankApp.terminate()
        let historyApp = launchApp()
        XCTAssertTrue(historyApp.buttons["nav.history"].waitForExistence(timeout: 5))
        historyApp.buttons["nav.history"].tap()
        XCTAssertTrue(historyApp.otherElements["history.screen"].waitForExistence(timeout: 5))

        historyApp.terminate()
        let settingsApp = launchApp()
        XCTAssertTrue(settingsApp.buttons["nav.settings"].waitForExistence(timeout: 5))
        settingsApp.buttons["nav.settings"].tap()
        XCTAssertTrue(settingsApp.otherElements["settings.screen"].waitForExistence(timeout: 5))

        settingsApp.terminate()
        let practiceApp = launchApp()
        openPracticeModes(in: practiceApp)
        XCTAssertTrue(practiceApp.otherElements["practiceModes.screen"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPracticeModesOpenAvailableScreens() throws {
        assertPracticeModeLaunches(modeIdentifier: "practiceMode.timed", screenIdentifier: "timedPractice.screen")
        assertPracticeModeLaunches(modeIdentifier: "practiceMode.suddenDeath", screenIdentifier: "suddenDeath.screen")
        assertPracticeModeLaunches(modeIdentifier: "practiceMode.ahCounter", screenIdentifier: "ahCounter.screen")

        let imApp = launchApp()
        openPracticeModes(in: imApp)

        let imButton = imApp.buttons["practiceMode.imConversation"]
        if imButton.waitForExistence(timeout: 2) {
            imButton.tap()
            XCTAssertTrue(imApp.buttons["practiceModes.start"].waitForExistence(timeout: 5))
            imApp.buttons["practiceModes.start"].tap()
            XCTAssertTrue(imApp.otherElements["imPractice.screen"].waitForExistence(timeout: 5))
        }
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
        dismissKeyboardIfNeeded(in: app)
        app.buttons["coaching.continue"].tap()

        let whyNowField = app.textViews["coaching.whyNow"]
        XCTAssertTrue(whyNowField.waitForExistence(timeout: 5))
        whyNowField.tap()
        whyNowField.typeText("I need to sound sharper in high-visibility conversations.")
        dismissKeyboardIfNeeded(in: app)
        app.buttons["coaching.continue"].tap()

        let successVisionField = app.textViews["coaching.successVision"]
        XCTAssertTrue(successVisionField.waitForExistence(timeout: 5))
        successVisionField.tap()
        successVisionField.typeText("I will feel calmer, clearer, and more credible at work.")
        dismissKeyboardIfNeeded(in: app)
        app.buttons["coaching.continue"].tap()

        XCTAssertTrue(app.buttons["coaching.save"].isEnabled)
        app.buttons["coaching.save"].tap()
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 17.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                _ = launchApp()
            }
        }
    }

    @MainActor
    private func assertPracticeModeLaunches(modeIdentifier: String, screenIdentifier: String) {
        let app = launchApp()
        openPracticeModes(in: app)

        XCTAssertTrue(app.buttons[modeIdentifier].waitForExistence(timeout: 5))
        app.buttons[modeIdentifier].tap()

        XCTAssertTrue(app.buttons["practiceModes.start"].waitForExistence(timeout: 5))
        app.buttons["practiceModes.start"].tap()

        XCTAssertTrue(app.otherElements[screenIdentifier].waitForExistence(timeout: 5))
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UI_TESTING")
        app.launch()
        return app
    }

    @MainActor
    private func openPracticeModes(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["nav.practice"].waitForExistence(timeout: 5))
        app.buttons["nav.practice"].tap()
    }

    @MainActor
    private func dismissKeyboardIfNeeded(in app: XCUIApplication) {
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        } else if app.keyboards.count > 0 {
            app.tap()
        }
    }
}
