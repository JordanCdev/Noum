import XCTest

final class GoalOutcomeLoopUITests: XCTestCase {
    @MainActor
    func testSummaryPrescriptionCompletesAndReturnsFollowUpRead() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_FIRST_VALUE_LOOP",
            "UI_TESTING_GOAL_OUTCOME_TIMED",
            "-DeepLink", "noum://summary"
        ]
        app.launch()

        dismissProgressionIfNeeded(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["summary.postRepVerdict"].waitForExistence(timeout: 15))

        XCTAssertFalse(
            app.buttons["goalOutcome.practice"].exists,
            "Goal movement is evidence; the finalizer-owned Summary action must be the only prescription."
        )
        let practice = app.buttons["summary.postRepVerdict.fullRetry"]
        scrollUntilHittable(practice, in: app, attempts: 10)
        XCTAssertTrue(practice.waitForExistence(timeout: 5))
        practice.tap()

        XCTAssertTrue(app.descendants(matching: .any)["timedPractice.screen"].waitForExistence(timeout: 12))
        advanceInjectedTimedRepToSummary(in: app)
        dismissProgressionIfNeeded(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["summary.postRepVerdict"].waitForExistence(timeout: 20))
        openDetails(in: app)

        let status = app.descendants(matching: .any)["goalOutcome.status"]
        scrollUntilHittable(status, in: app, attempts: 10)
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        let allowed = ["target held", "early improvement", "mixed evidence", "more comparable evidence"]
        XCTAssertTrue(
            allowed.contains { status.label.localizedCaseInsensitiveContains($0) },
            "Follow-up copy must stay within the bounded observational result vocabulary; got: \(status.label)"
        )
        let share = app.descendants(matching: .any)["goalOutcome.share"]
        scrollUntilHittable(share, in: app, attempts: 10)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "m26-goal-follow-up-summary"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(share.waitForExistence(timeout: 5))
    }

    @MainActor
    func testOnDeviceRewriteCanBeSavedAndOpenedFromSummary() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_PREMIUM",
            "-DeepLink", "noum://summary"
        ]
        app.launch()

        dismissProgressionIfNeeded(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["summary.postRepVerdict"].waitForExistence(timeout: 15))
        openDetails(in: app)

        let onDevice = app.descendants(matching: .any)["rewrite.onDevice"]
        scrollUntilHittable(onDevice, in: app, attempts: 20)
        XCTAssertTrue(onDevice.waitForExistence(timeout: 12))

        let save = app.buttons["rewrite.savePhrase"]
        scrollUntilHittable(save, in: app, attempts: 6)
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        let rewriteAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        rewriteAttachment.name = "on-device-rewrite-card"
        rewriteAttachment.lifetime = .keepAlways
        add(rewriteAttachment)
        save.tap()

        let phraseBank = app.buttons["rewrite.phraseBank"]
        scrollUntilHittable(phraseBank, in: app, attempts: 6)
        XCTAssertTrue(phraseBank.waitForExistence(timeout: 5))
        phraseBank.tap()
        XCTAssertTrue(app.staticTexts["Phrase bank"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No saved phrases"].exists)

        let practicePhrase = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "phraseBank.practice.")
        ).firstMatch
        XCTAssertTrue(
            practicePhrase.waitForExistence(timeout: 5),
            "A saved rewrite should be practiceable through the existing Timed handoff."
        )
        XCTAssertGreaterThanOrEqual(practicePhrase.frame.height, 44)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "on-device-rewrite-phrase-bank"
        attachment.lifetime = .keepAlways
        add(attachment)

        practicePhrase.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["timedPractice.screen"].waitForExistence(timeout: 12),
            "Practising a saved phrase should launch the existing Timed destination."
        )
    }

    @MainActor
    func testActiveWeekPhraseLaunchesExactPromptFromHome() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_FORWARD_PLAN_PHRASE",
            "UI_TESTING_MICROPHONE_GRANTED",
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["home.screen"].waitForExistence(timeout: 15))
        let plannedPhrase = app.buttons["home.coachCard.planPhrase"]
        scrollUntilHittable(plannedPhrase, in: app, attempts: 6)
        XCTAssertTrue(
            plannedPhrase.waitForExistence(timeout: 8),
            "The active plan week should render its assigned Phrase Bank line on Home."
        )
        XCTAssertGreaterThanOrEqual(plannedPhrase.frame.height, 44)
        plannedPhrase.tap()

        XCTAssertTrue(app.descendants(matching: .any)["timedPractice.screen"].waitForExistence(timeout: 12))
        revealTimedPrompt(in: app)

        let expectedPrompt =
            "Say this line in your own voice: Lead with the decision, then give one reason."
        let routedPrompt = app.staticTexts["timedPractice.prompt"]
        XCTAssertTrue(routedPrompt.waitForExistence(timeout: 8))
        XCTAssertEqual(
            routedPrompt.label,
            expectedPrompt,
            "Home must deliver the exact saved line through the bounded Timed handoff."
        )

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "active-week-phrase-timed-prompt"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func openDetails(in app: XCUIApplication) {
        let toggle = app.descendants(matching: .any)["summary.details.toggle"]
        scrollUntilHittable(toggle, in: app, attempts: 8)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        guard app.descendants(matching: .any)["goalOutcome.status"].exists == false else { return }

        if toggle.isHittable {
            toggle.tap()
        } else {
            // SwiftUI can report a false-negative hit point for this plain
            // button after the prescribed-rep route returns to Summary. Only
            // bypass that resolver when the full 44-point control is visibly
            // inside the active scroll viewport; the caller verifies the
            // expanded goal-outcome content immediately afterwards.
            let scroll = app.scrollViews.firstMatch
            XCTAssertTrue(scroll.exists)
            XCTAssertTrue(
                scroll.frame.contains(toggle.frame),
                "The details control must be fully visible before a coordinate tap."
            )
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    @MainActor
    private func advanceInjectedTimedRepToSummary(in app: XCUIApplication) {
        let deadline = Date().addingTimeInterval(35)
        while Date() < deadline {
            if app.descendants(matching: .any)["summary.postRepVerdict"].exists { return }
            for identifier in ["timedPractice.begin", "timedPractice.startNow"] {
                let button = app.buttons[identifier]
                if button.exists {
                    scrollUntilHittable(button, in: app, attempts: 2)
                    if button.isHittable { button.tap(); Thread.sleep(forTimeInterval: 0.6) }
                }
            }
            for label in ["Continue", "View Summary", "Got it"] {
                let button = app.buttons[label]
                if button.exists && button.isHittable {
                    button.tap(); Thread.sleep(forTimeInterval: 0.6)
                }
            }
            Thread.sleep(forTimeInterval: 0.4)
        }
        XCTFail("Injected prescribed Timed rep did not return to Summary")
    }

    @MainActor
    private func revealTimedPrompt(in app: XCUIApplication) {
        for identifier in ["timedPractice.begin", "timedPractice.startNow"] {
            let button = app.buttons[identifier]
            if button.waitForExistence(timeout: 3) {
                scrollUntilHittable(button, in: app, attempts: 3)
                if button.isHittable {
                    button.tap()
                    return
                }
            }
        }
        XCTFail("Timed Practice did not expose a start action")
    }

    @MainActor
    private func dismissProgressionIfNeeded(in app: XCUIApplication) {
        for _ in 0..<6 {
            if app.descendants(matching: .any)["summary.postRepVerdict"].exists { return }
            var tapped = false
            for label in ["View Summary", "Continue", "Got it"] {
                let button = app.buttons[label]
                if button.waitForExistence(timeout: 1), button.isHittable {
                    button.tap(); Thread.sleep(forTimeInterval: 0.5); tapped = true; break
                }
            }
            if !tapped { Thread.sleep(forTimeInterval: 0.5) }
        }
    }

    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, attempts: Int) {
        guard !element.isHittable else { return }
        let scroll = app.scrollViews.firstMatch
        guard scroll.exists else { return }
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            scroll.swipeUp(velocity: .slow)
        }
    }
}
