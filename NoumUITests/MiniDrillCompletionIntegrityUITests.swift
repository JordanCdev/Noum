import XCTest

final class MiniDrillCompletionIntegrityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testInsufficientTerminalEvidenceReturnsToReadyWithoutResultOrRewardAtAccessibilityXXXL() {
        let app = launchFixture("insufficient")
        defer { app.terminate() }

        let issue = app.descendants(matching: .any)["miniDrill.completionIssue"]
        XCTAssertTrue(issue.waitForExistence(timeout: 15))
        XCTAssertTrue(issue.label.contains("at least 3 words over 3 seconds"))
        XCTAssertFalse(app.staticTexts["miniDrillResult.title"].exists)
        XCTAssertFalse(app.staticTexts["miniDrillResult.xp"].exists)

        let start = app.buttons["miniDrill.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        attachScreenshot(named: "mini-drill-insufficient-axxxl", app: app)
    }

    @MainActor
    func testEligibleTerminalEvidencePersistsBeforeRenderingExactResult() {
        let app = launchFixture("eligible")
        defer { app.terminate() }

        let result = app.staticTexts["miniDrillResult.title"]
        XCTAssertTrue(
            result.waitForExistence(timeout: 15),
            "The result may mount only after Summary accepts and persists the verified receipt."
        )

        XCTAssertEqual(result.label, "Clean Run")
        let xp = app.staticTexts["miniDrillResult.xp"]
        XCTAssertTrue(xp.waitForExistence(timeout: 5))
        XCTAssertTrue(xp.label.hasPrefix("+"))
        XCTAssertTrue(xp.label.hasSuffix(" XP"))
        XCTAssertTrue(app.staticTexts["12s"].exists)
        XCTAssertTrue(app.staticTexts["12"].exists)
        XCTAssertTrue(app.staticTexts["0"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["miniDrill.completionIssue"].exists)

        let done = app.buttons["miniDrillResult.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isHittable)
        attachScreenshot(named: "mini-drill-eligible-result-axxxl", app: app)

        done.tap()
        let celebration = app.descendants(matching: .any)["preSummary.celebration"]
        if celebration.waitForExistence(timeout: 2) {
            celebration.tap()
        }
        XCTAssertTrue(
            app.descendants(matching: .any)["summary.postRepVerdict"]
                .waitForExistence(timeout: 8)
        )
    }

    @MainActor
    private func launchFixture(_ fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_MINI_DRILL_COMPLETION_FIXTURE", fixture,
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            "-DeepLink", "noum://summary",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
