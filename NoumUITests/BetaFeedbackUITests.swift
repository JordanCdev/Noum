import XCTest

final class BetaFeedbackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSettingsBetaFeedbackRouteShowsRedactedReport() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "-DeepLink", "noum://settings",
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["settings.screen"]
                .waitForExistence(timeout: 12)
        )

        let feedbackRoute = app.buttons["settings.betaFeedback"]
        scrollToElement(feedbackRoute, in: app)
        XCTAssertTrue(feedbackRoute.waitForExistence(timeout: 5))
        XCTAssertTrue(feedbackRoute.isHittable)
        feedbackRoute.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["betaFeedback.screen"]
                .waitForExistence(timeout: 5)
        )
        let details = app.textViews["betaFeedback.details"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        XCTAssertTrue(details.isHittable)
        details.tap()
        details.typeText("The next action was unclear after my rep.")

        let diagnostics = app.descendants(matching: .any)["betaFeedback.diagnostics"]
        scrollToElement(diagnostics, in: app)
        XCTAssertTrue(diagnostics.waitForExistence(timeout: 5))

        let redactionNotice = app.descendants(matching: .any)["betaFeedback.redactionNotice"]
        scrollToElement(redactionNotice, in: app)
        XCTAssertTrue(redactionNotice.waitForExistence(timeout: 5))

        let email = app.buttons["betaFeedback.email"]
        scrollToElement(email, in: app)
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        XCTAssertTrue(email.isEnabled)
    }

    @MainActor
    private func scrollToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 14
    ) {
        for _ in 0..<attempts {
            if element.exists, element.isHittable { return }
            app.swipeUp(velocity: .slow)
        }
    }
}
