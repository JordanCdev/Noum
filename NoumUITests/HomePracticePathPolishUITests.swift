import XCTest

final class HomePracticePathPolishUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFillerControlCountdownCoversSetupAndProviderFailureReturnsToPristineState() {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "-DeepLink",
            "noum://practice/ah-counter"
        ]
        app.launch()
        defer { app.terminate() }

        let screen = app.descendants(matching: .any)["ahCounter.screen"]
        XCTAssertTrue(screen.waitForExistence(timeout: 10))

        let start = app.buttons["Start Filler Control"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        start.tap()

        let countdown = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Get ready")
        ).firstMatch
        XCTAssertTrue(
            countdown.waitForExistence(timeout: 2),
            "Countdown should be a full-screen focused state"
        )
        attachScreenshot(named: "filler-countdown", app: app)

        let unavailable = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "temporarily unavailable")
        ).firstMatch
        XCTAssertTrue(
            unavailable.waitForExistence(timeout: 10),
            "A missing simulator provider should return to setup with an actionable status"
        )
        XCTAssertTrue(start.exists && start.isHittable)
        XCTAssertFalse(app.staticTexts["Elapsed"].exists)
        attachScreenshot(named: "filler-provider-unavailable", app: app)
    }

    @MainActor
    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
