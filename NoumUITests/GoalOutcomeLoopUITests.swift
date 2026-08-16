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
    func testTranscriptLadderPractisesOneStepRewriteFromSummary() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_PREMIUM",
            "UI_TESTING_REWRITE_LADDER",
            "UI_TESTING_FIRST_VALUE_LOOP",
            "UI_TESTING_TRANSCRIPT_RETRY_IMPROVED",
            "UI_TESTING_SEED_PROFILE", "plateauedAdvanced",
            "-DeepLink", "noum://summary"
        ]
        app.launch()

        dismissProgressionIfNeeded(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["summary.postRepVerdict"].waitForExistence(timeout: 15))

        let onDevice = app.descendants(matching: .any)["rewrite.onDevice"]
        scrollUntilHittable(onDevice, in: app, attempts: 20)
        XCTAssertTrue(onDevice.waitForExistence(timeout: 12))

        XCTAssertTrue(app.descendants(matching: .any)["rewrite.original"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["rewrite.oneStep"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["rewrite.aspirational"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["rewrite.retryTarget"].exists)

        let rewriteAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        rewriteAttachment.name = "transcript-ladder"
        rewriteAttachment.lifetime = .keepAlways
        add(rewriteAttachment)

        let practice = app.buttons["rewrite.practiceOneStep"]
        scrollUntilHittable(practice, in: app, attempts: 6)
        XCTAssertTrue(practice.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(practice.frame.height, 44)
        practice.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["timedPractice.screen"].waitForExistence(timeout: 12),
            "The one-step ladder rung should launch the existing targeted Timed destination."
        )
        advanceInjectedTimedRepToSummary(in: app)
        dismissProgressionIfNeeded(in: app)
        let comparison = app.descendants(matching: .any)["transcriptRetry.comparison"]
        XCTAssertTrue(
            comparison.waitForExistence(timeout: 15),
            "The accepted ladder must return as a source-bound retry comparison."
        )
        scrollUntilHittable(comparison, in: app, attempts: 12)
        XCTAssertTrue(comparison.isHittable)
        XCTAssertTrue(
            app.staticTexts["The target moved"].waitForExistence(timeout: 5),
            "A meaning-preserving retry that improves the prescribed opening should report that bounded target movement."
        )
        let summaryScroll = app.scrollViews.firstMatch
        summaryScroll.swipeUp(velocity: .slow)
        summaryScroll.swipeUp(velocity: .slow)
        let comparisonAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        comparisonAttachment.name = "transcript-ladder-retry-comparison"
        comparisonAttachment.lifetime = .keepAlways
        add(comparisonAttachment)
    }

    /// The non-Pro half of the same surface. The rewrite is the clearest thing
    /// a free user cannot see, so the locked card must actually render — and it
    /// must render WITHOUT opening Details, which is the whole point of moving
    /// it above the fold.
    @MainActor
    func testLockedRewritePreviewRendersForFreeUsersWithoutOpeningDetails() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "-DeepLink", "noum://summary"
        ]
        app.launch()

        dismissProgressionIfNeeded(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["summary.postRepVerdict"].waitForExistence(timeout: 15))

        let locked = app.descendants(matching: .any)["summary.rewrite.locked"]
        scrollUntilHittable(locked, in: app, attempts: 20)
        XCTAssertTrue(
            locked.waitForExistence(timeout: 12),
            "A free user must reach the locked rewrite preview without expanding Details."
        )

        let upgrade = app.buttons["summary.rewrite.upgrade"]
        scrollUntilHittable(upgrade, in: app, attempts: 6)
        XCTAssertTrue(upgrade.waitForExistence(timeout: 5))

        // The Pro-only generated rewrite must NOT be present for a free user.
        XCTAssertFalse(
            app.descendants(matching: .any)["rewrite.onDevice"].exists,
            "The locked card must not render a generated rewrite."
        )

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "locked-rewrite-preview"
        attachment.lifetime = .keepAlways
        add(attachment)
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
            let evidence = app.buttons["transcriptRetry.continueToEvidence"]
            if evidence.exists, evidence.isEnabled, evidence.isHittable {
                evidence.tap()
                Thread.sleep(forTimeInterval: 0.6)
                continue
            }
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
