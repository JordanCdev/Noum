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
            "UI_TESTING_CLOUD_CONSENT",
            "UI_TESTING_MICROPHONE_GRANTED",
            "UI_TESTING_TRANSCRIPTION_START_FAILURE",
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

    /// Filler Control is the mode the Home hero recommends for a filler-words
    /// profile, so a first-run user is likely to meet its failure surface
    /// before Timed's. A transport failure there is legitimately retryable, but
    /// an unsupported on-device locale never resolves by pressing Start again:
    /// the mode must name that cause rather than offer an unsatisfiable retry.
    @MainActor
    func testFillerControlUnsupportedLocaleNamesTheCauseInsteadOfLoopingOnStart() {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_MICROPHONE_GRANTED",
            "UI_TESTING_TRANSCRIPTION_UNSUPPORTED_LOCALE",
            "UI_TESTING_PRACTICE_LOCALE",
            "en-US",
            "-DeepLink",
            "noum://practice/ah-counter",
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["ahCounter.screen"].waitForExistence(timeout: 10)
        )

        let start = app.buttons["Start Filler Control"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        start.tap()

        let issue = app.descendants(matching: .any)["ahCounter.recordingIssue"]
        XCTAssertTrue(
            issue.waitForExistence(timeout: 15),
            "The typed unsupported-locale failure should reach a named issue surface."
        )
        XCTAssertTrue(issue.label.contains("This language isn't available offline"))
        XCTAssertTrue(issue.label.contains("en-US"))

        // Start can never succeed for this cause, so it must not be the
        // offered recovery. Leaving the rep is the only honest action.
        XCTAssertFalse(app.buttons["Start Filler Control"].exists)
        let back = app.buttons["ahCounter.recordingIssue.backToSetup"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertTrue(back.isHittable)
        attachScreenshot(named: "filler-unsupported-locale", app: app)
    }

    @MainActor
    func testUnsupportedOnDeviceLocaleRendersSpecificActionableIssueAtAccessibilityXXXL() {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_MICROPHONE_GRANTED",
            "UI_TESTING_TRANSCRIPTION_UNSUPPORTED_LOCALE",
            "UI_TESTING_PRACTICE_LOCALE",
            "en-US",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
            "-DeepLink",
            "noum://practice/timed",
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["timedPractice.screen"]
                .waitForExistence(timeout: 12)
        )

        let begin = app.buttons["timedPractice.begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        scrollUntilHittable(begin, in: app, attempts: 3)
        XCTAssertTrue(begin.isHittable)
        begin.tap()

        let startNow = app.buttons["timedPractice.startNow"]
        XCTAssertTrue(startNow.waitForExistence(timeout: 5))
        let startNowHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: startNow
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [startNowHittable], timeout: 5),
            .completed
        )
        startNow.tap()

        let issue = app.descendants(matching: .any)["timedPractice.recordingIssue"]
        XCTAssertTrue(
            issue.waitForExistence(timeout: 15),
            "The typed unsupported-locale failure should reach the real Timed issue card."
        )
        XCTAssertTrue(issue.label.contains("This language isn't available offline"))
        XCTAssertTrue(issue.label.contains("On-device transcription isn't available"))
        XCTAssertTrue(issue.label.contains("en-US"))
        XCTAssertTrue(issue.label.contains("on this device"))
        XCTAssertTrue(issue.label.contains("Choose another Practice language in Settings"))
        XCTAssertFalse(app.buttons["timedPractice.recordingIssue.retry"].exists)
        XCTAssertFalse(app.buttons["timedPractice.end"].exists)

        let backToSetup = app.buttons["timedPractice.recordingIssue.backToSetup"]
        XCTAssertTrue(backToSetup.waitForExistence(timeout: 5))
        XCTAssertTrue(backToSetup.isHittable)
        attachScreenshot(named: "timed-unsupported-locale-axxxl", app: app)

        backToSetup.tap()
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        XCTAssertFalse(issue.exists)
    }

    @MainActor
    func testPaceInsufficientSpeechWithholdsResultAndXPAtAccessibilityXXXL() {
        let app = launchPaceCompletionFixture(
            "insufficient",
            extraArguments: [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        )
        defer { app.terminate() }

        let issue = app.descendants(matching: .any)["paceTraining.insufficientSpeech"]
        XCTAssertTrue(issue.waitForExistence(timeout: 10))
        XCTAssertTrue(issue.label.contains("enough speech"))
        XCTAssertFalse(app.descendants(matching: .any)["paceTraining.result"].exists)
        XCTAssertFalse(app.staticTexts["XP Earned"].exists)

        let start = app.buttons["paceTraining.start"]
        for _ in 0..<6 where !start.isHittable {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        attachScreenshot(named: "pace-insufficient-speech-axxxl", app: app)
    }

    @MainActor
    func testPaceEligibleTerminalEvidenceRendersExistingResult() {
        let app = launchPaceCompletionFixture("eligible")
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["paceTraining.result"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.staticTexts["XP Earned"].exists)
        XCTAssertTrue(app.staticTexts["+40"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["paceTraining.insufficientSpeech"].exists)

        let goAgain = app.buttons["Go Again"]
        XCTAssertTrue(goAgain.waitForExistence(timeout: 5))
        XCTAssertTrue(goAgain.isHittable)
        XCTAssertTrue(app.buttons["Done"].isHittable)
        attachScreenshot(named: "pace-eligible-result", app: app)
    }

    @MainActor
    func testCutTheCrutchInsufficientSpeechWithholdsResultAndProgressAtAccessibilityXXXL() {
        let app = launchCutTheCrutchCompletionFixture(
            "insufficient",
            extraArguments: [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        )
        defer { app.terminate() }

        let issue = app.descendants(matching: .any)["cutTheCrutch.insufficientSpeech"]
        XCTAssertTrue(issue.waitForExistence(timeout: 10))
        XCTAssertTrue(issue.label.contains("enough speech"))
        XCTAssertFalse(app.descendants(matching: .any)["cutTheCrutch.result"].exists)
        XCTAssertFalse(app.staticTexts["Score"].exists)
        XCTAssertFalse(app.staticTexts["XP earned"].exists)

        let start = app.buttons["cutTheCrutch.start"]
        for _ in 0..<6 where !start.isHittable {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        attachScreenshot(named: "crutch-insufficient-speech-axxxl", app: app)
    }

    @MainActor
    func testCutTheCrutchEligibleTerminalEvidenceRendersExactResult() {
        let app = launchCutTheCrutchCompletionFixture("eligible")
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["cutTheCrutch.result"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.staticTexts["Score"].exists)
        XCTAssertTrue(app.staticTexts["XP earned"].exists)
        XCTAssertTrue(app.staticTexts["+150"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["cutTheCrutch.insufficientSpeech"].exists)

        let retry = app.buttons["Try another rep"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(retry.isHittable)
        XCTAssertTrue(app.buttons["Done"].isHittable)
        attachScreenshot(named: "crutch-eligible-result", app: app)
    }

    @MainActor
    private func launchPaceCompletionFixture(
        _ fixture: String,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_PACE_COMPLETION_FIXTURE", fixture,
            "-DeepLink", "noum://practice/pace"
        ]
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func launchCutTheCrutchCompletionFixture(
        _ fixture: String,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_CRUTCH_COMPLETION_FIXTURE", fixture,
            "-DeepLink", "noum://practice/cut-the-crutch"
        ]
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int
    ) {
        guard !element.isHittable else { return }
        for _ in 0..<attempts where !element.isHittable {
            app.swipeUp(velocity: .slow)
        }
    }

    @MainActor
    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
