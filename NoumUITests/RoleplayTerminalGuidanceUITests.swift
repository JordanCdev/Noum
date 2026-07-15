import XCTest

final class RoleplayTerminalGuidanceUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFourthAttemptUsesPracticeFocusInFeedbackAndCompletion() {
        let app = launchFixture(
            .terminalFeedback,
            extraArguments: [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
            ]
        )
        defer { app.terminate() }

        let guidance = element("roleplay.feedback.guidance", in: app)
        XCTAssertTrue(guidance.label.contains("Practice focus"))
        XCTAssertFalse(guidance.label.contains("Next attempt"))

        let next = app.buttons["roleplay.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        XCTAssertEqual(next.label, "See results")
        attach(app, name: "roleplay-terminal-feedback-axxxl")
        next.tap()

        XCTAssertTrue(element("roleplay.complete.screen", in: app).exists)
        let summary = element("roleplay.complete.summary", in: app)
        XCTAssertTrue(summary.label.contains("4 response attempts"))
        XCTAssertTrue(summary.label.contains("Final attempted pressure: Easy"))

        let completeGuidance = element("roleplay.complete.guidance", in: app)
        XCTAssertTrue(completeGuidance.label.contains("Practice focus"))
        XCTAssertFalse(completeGuidance.label.contains("Next attempt"))

        let done = scrollToButton("roleplay.done", in: app)
        XCTAssertTrue(done.isHittable)
        attach(app, name: "roleplay-terminal-completion-axxxl")
    }

    @MainActor
    func testUnavailableTransitionFailsClosedBeforeCompletion() {
        let app = launchFixture(.unavailableFeedback)
        defer { app.terminate() }

        let guidance = element("roleplay.feedback.guidance", in: app)
        XCTAssertTrue(guidance.label.contains("available starting pressure"))
        XCTAssertFalse(guidance.label.lowercased().contains("objection"))

        let next = app.buttons["roleplay.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        XCTAssertEqual(next.label, "See results")
        next.tap()

        let summary = element("roleplay.complete.summary", in: app)
        XCTAssertTrue(summary.label.contains("3 response attempts"))
        XCTAssertTrue(summary.label.contains("Final attempted pressure: Realistic"))
        XCTAssertTrue(element("roleplay.complete.guidance", in: app).label.contains("available starting pressure"))
    }

    @MainActor
    func testPreterminalGuidanceStillAdvancesToTheProjectedTurn() {
        let app = launchFixture(.preterminalFeedback)
        defer { app.terminate() }

        let guidance = element("roleplay.feedback.guidance", in: app)
        XCTAssertTrue(guidance.label.contains("Next attempt"))
        XCTAssertTrue(guidance.label.contains("raise the pressure"))

        let next = app.buttons["roleplay.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        XCTAssertEqual(next.label, "Next attempt")
        next.tap()

        XCTAssertTrue(app.descendants(matching: .any)["roleplay.objection"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.descendants(matching: .any)["roleplay.pressureChip"].label, "Realistic")
        XCTAssertFalse(app.descendants(matching: .any)["roleplay.complete.screen"].exists)
    }

    private enum Fixture: String {
        case terminalFeedback
        case unavailableFeedback
        case preterminalFeedback
    }

    @MainActor
    private func launchFixture(_ fixture: Fixture, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_ROLEPLAY_FIXTURE", fixture.rawValue]
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        for _ in 0..<5 where !element.exists {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing element: \(identifier)")
        return element
    }

    @MainActor
    private func scrollToButton(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons[identifier]
        for _ in 0..<6 where !button.isHittable {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing button: \(identifier)")
        return button
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
