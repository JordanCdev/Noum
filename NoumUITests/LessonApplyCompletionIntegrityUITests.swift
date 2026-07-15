import XCTest

final class LessonApplyCompletionIntegrityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testKeywordOnlySpeechShowsTransparentRetryWithoutProgress() {
        let app = launchFixture(
            "keywordOnly",
            extraArguments: [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            ]
        )
        defer { app.terminate() }

        let result = app.descendants(matching: .any)["lesson.apply.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 10))

        let completeAnswer = app.descendants(matching: .any)["lesson.apply.criterion.complete-answer"]
        XCTAssertTrue(completeAnswer.waitForExistence(timeout: 5))
        XCTAssertTrue(completeAnswer.label.contains("Try again"))
        XCTAssertTrue(completeAnswer.label.contains("12 words"))
        XCTAssertTrue(
            app.descendants(matching: .any)["lesson.apply.criterion.check.action"].label.contains("Met"),
            "The fixture should prove that keywords matched while response evidence still failed"
        )

        XCTAssertTrue(app.buttons["lesson.cta"].label == "Try again")
        XCTAssertFalse(app.buttons["lesson.summary.continue"].exists)
        XCTAssertFalse(app.staticTexts["Practice complete"].exists)
        attachScreenshot(named: "lesson-keyword-only-retry-axxxl", app: app)

        app.buttons["lesson.cta"].tap()
        XCTAssertTrue(app.buttons["lesson.cta"].label == "Speak now")
        XCTAssertFalse(app.descendants(matching: .any)["lesson.apply.result"].exists)
    }

    @MainActor
    func testEligibleTerminalEvidenceCompletesThroughProductionPolicy() {
        let app = launchFixture("eligible")
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["lesson.apply.result"].waitForExistence(timeout: 10)
        )
        let completeAnswer = app.descendants(matching: .any)["lesson.apply.criterion.complete-answer"]
        XCTAssertTrue(completeAnswer.waitForExistence(timeout: 5))
        XCTAssertTrue(completeAnswer.label.contains("Met"))
        XCTAssertTrue(app.staticTexts["Skill shown"].exists)

        let continueButton = app.buttons["lesson.cta"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        XCTAssertEqual(continueButton.label, "Continue")
        attachScreenshot(named: "lesson-eligible-evaluation", app: app)

        continueButton.tap()
        XCTAssertTrue(app.buttons["lesson.summary.continue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Practice complete"].exists)
        attachScreenshot(named: "lesson-eligible-summary", app: app)
    }

    @MainActor
    private func launchFixture(
        _ fixture: String,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_REDUCE_MOTION",
            "UI_TESTING_LESSON_APPLY_COMPLETION_FIXTURE", fixture,
            "-DeepLink", "noum://lesson/check_understanding",
        ]
        app.launchArguments += extraArguments
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
