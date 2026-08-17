import Foundation
import XCTest

final class FastLaneFirstSessionUITests: XCTestCase {
    @MainActor
    func testPermissionlessFirstValueStaysStructuredAndDefersSetupToHome() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_REAL_FIRST_RUN",
            "UI_TESTING_FAST_LANE",
            "UI_TESTING_CLEAR_FLOW_EVENTS"
        ]
        let launchStartedAt = Date()
        app.launch()

        let fastLane = app.descendants(matching: .any)["fastLane.screen"]
        XCTAssertTrue(
            fastLane.waitForExistence(timeout: 15),
            "The permissionless fast lane did not become the first-run root."
        )

        let workContext = app.buttons["fastLane.context.work"]
        let ramblingChallenge = app.buttons["fastLane.challenge.rambling"]
        XCTAssertTrue(workContext.waitForExistence(timeout: 5))
        assertMinimumTapTarget(workContext)
        workContext.tap()
        let contextContinue = app.buttons["fastLane.contextContinue"]
        XCTAssertTrue(contextContinue.waitForExistence(timeout: 5))
        assertMinimumTapTarget(contextContinue)
        contextContinue.tap()
        XCTAssertTrue(ramblingChallenge.waitForExistence(timeout: 5))
        scrollUntilHittable(ramblingChallenge, in: app)
        assertMinimumTapTarget(ramblingChallenge)
        XCTAssertTrue(ramblingChallenge.isHittable)
        ramblingChallenge.tap()

        let begin = app.buttons["fastLane.begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        scrollUntilHittable(begin, in: app)
        assertMinimumTapTarget(begin)
        XCTAssertTrue(begin.isEnabled)
        XCTAssertTrue(begin.isHittable)
        begin.tap()

        let response = app.descendants(matching: .any)["fastLane.response"]
        XCTAssertTrue(
            response.waitForExistence(timeout: 5),
            "The written rehearsal editor did not appear."
        )
        response.tap()
        response.typeText(
            "I would lead with the decision, explain one reason, and close clearly."
        )

        let submit = app.buttons["fastLane.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        scrollUntilHittable(submit, in: app)
        assertMinimumTapTarget(submit)
        XCTAssertTrue(submit.isEnabled)
        XCTAssertTrue(submit.isHittable)
        submit.tap()

        let result = app.descendants(matching: .any)["fastLane.result"]
        XCTAssertTrue(
            result.waitForExistence(timeout: 8),
            "The written rehearsal did not produce its bounded structure read."
        )
        let timeToFirstValue = Date().timeIntervalSince(launchStartedAt)
        XCTAssertLessThan(
            timeToFirstValue,
            60,
            "Permissionless first value took \(String(format: "%.1f", timeToFirstValue)) seconds from launch; the fast-lane contract is under 60 seconds."
        )
        XCTAssertTrue(app.staticTexts["What is already working"].exists)
        XCTAssertTrue(app.staticTexts["One next move"].exists)
        XCTAssertTrue(app.staticTexts["Evidence boundary"].exists)

        let evidenceBoundary = app.staticTexts
            .matching(NSPredicate(
                format: "label CONTAINS[c] 'A written rehearsal can show answer shape'"
            ))
            .firstMatch
        XCTAssertTrue(
            evidenceBoundary.waitForExistence(timeout: 3),
            "The result must distinguish written structure from spoken delivery evidence."
        )

        XCTAssertFalse(
            app.descendants(matching: .any)["timedPractice.screen"].exists,
            "The structured fast lane must not masquerade as a Timed spoken rep."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["summary.postRepVerdict"].exists,
            "The structured fast lane must not enter the spoken-session Summary route."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["summary.whatYouDidWell"].exists,
            "Spoken Summary evidence cards must stay absent from the structure-only result."
        )

        let spokenProof = app.buttons["fastLane.spokenProof"]
        XCTAssertTrue(spokenProof.waitForExistence(timeout: 5))
        scrollUntilHittable(spokenProof, in: app)
        assertMinimumTapTarget(spokenProof)
        XCTAssertEqual(spokenProof.label, "Try a 30-second spoken proof")

        let otherOptions = app.buttons["fastLane.otherOptions"]
        XCTAssertTrue(otherOptions.waitForExistence(timeout: 5))
        scrollUntilHittable(otherOptions, in: app)
        assertMinimumTapTarget(otherOptions)
        XCTAssertFalse(
            app.buttons["fastLane.completeSetup"].exists,
            "Secondary exits should stay collapsed so the spoken proof remains the one primary continuation."
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Fast Lane - One Primary Spoken Continuation"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        otherOptions.tap()

        let completeProfile = app.buttons["fastLane.completeSetup"]
        XCTAssertTrue(completeProfile.waitForExistence(timeout: 5))
        scrollUntilHittable(completeProfile, in: app)
        assertMinimumTapTarget(completeProfile)
        XCTAssertEqual(completeProfile.label, "Complete my coaching profile")

        let explore = app.buttons["fastLane.enterApp"]
        XCTAssertTrue(explore.waitForExistence(timeout: 5))
        scrollUntilHittable(explore, in: app)
        assertMinimumTapTarget(explore)

        XCTAssertTrue(explore.isHittable)
        explore.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["home.screen"].waitForExistence(timeout: 10),
            "Explore Noum first did not enter Home."
        )

        let resumeSetup = app.buttons["home.coachingSetup.resume"]
        scrollUntilHittable(resumeSetup, in: app, attempts: 8)
        XCTAssertTrue(
            resumeSetup.waitForExistence(timeout: 6),
            "Home did not preserve the quiet coaching-setup resume path."
        )
        assertMinimumTapTarget(resumeSetup)

        let homeScreenshot = XCTAttachment(screenshot: app.screenshot())
        homeScreenshot.name = "Fast Lane - Deferred Setup Resume on Home"
        homeScreenshot.lifetime = .keepAlways
        add(homeScreenshot)

        XCTAssertFalse(app.descendants(matching: .any)["timedPractice.screen"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["summary.postRepVerdict"].exists)

        // V4.6 four-tab IA: Settings lives under You (gear on Profile root).
        let youTab = app.buttons["nav.social"]
        XCTAssertTrue(youTab.waitForExistence(timeout: 5))
        youTab.tap()
        let openSettings = app.buttons["profile.openSettings"]
        XCTAssertTrue(openSettings.waitForExistence(timeout: 5))
        openSettings.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.screen"].waitForExistence(timeout: 5)
        )
        let deleteAccount = app.buttons["settings.account.delete"]
        for _ in 0..<12 where !deleteAccount.isHittable {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(
            deleteAccount.waitForExistence(timeout: 5),
            "The durable local guest must have a visible account-deletion entry point."
        )
        XCTAssertTrue(deleteAccount.isHittable)
    }

    @MainActor
    func testSpokenProofRequiresTapAndLandsOnPreparedTimedScreen() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_REAL_FIRST_RUN",
            "UI_TESTING_FAST_LANE",
            "UI_TESTING_CLEAR_FLOW_EVENTS"
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["fastLane.screen"].waitForExistence(timeout: 15))
        let work = app.buttons["fastLane.context.work"]
        let rambling = app.buttons["fastLane.challenge.rambling"]
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        let contextContinue = app.buttons["fastLane.contextContinue"]
        XCTAssertTrue(contextContinue.waitForExistence(timeout: 5))
        contextContinue.tap()
        XCTAssertTrue(rambling.waitForExistence(timeout: 5))
        scrollUntilHittable(rambling, in: app)
        XCTAssertTrue(rambling.isHittable)
        rambling.tap()

        let begin = app.buttons["fastLane.begin"]
        scrollUntilHittable(begin, in: app)
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        begin.tap()

        let response = app.descendants(matching: .any)["fastLane.response"]
        XCTAssertTrue(response.waitForExistence(timeout: 5))
        response.tap()
        response.typeText("I would state the decision, give one reason, and name the owner before I close.")

        let submit = app.buttons["fastLane.submit"]
        scrollUntilHittable(submit, in: app)
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        submit.tap()

        let spokenProof = app.buttons["fastLane.spokenProof"]
        scrollUntilHittable(spokenProof, in: app)
        XCTAssertTrue(spokenProof.waitForExistence(timeout: 8))
        XCTAssertTrue(spokenProof.isHittable)

        // Reaching the result never opens the microphone or Timed route by
        // itself. The explicit CTA is the only production handoff.
        XCTAssertFalse(app.descendants(matching: .any)["timedPractice.screen"].exists)
        spokenProof.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["timedPractice.screen"].waitForExistence(timeout: 12),
            "The explicit spoken-proof CTA should reuse the Timed practice engine."
        )
        XCTAssertTrue(
            app.buttons["timedPractice.begin"].waitForExistence(timeout: 5),
            "The production spoken proof must wait on the prepared screen for another user tap."
        )
        XCTAssertFalse(
            app.buttons["timedPractice.end"].exists,
            "The microphone/capture phase must not auto-start when the handoff opens."
        )
    }

    /// One deterministic production-route contract for the complete Day-0
    /// funnel. XCUITest cannot inject real microphone audio, so the checked-in
    /// fixture substitutes only the terminal captured rep after the user taps
    /// Start; onboarding, navigation, persistence, Summary, and paywall routing
    /// remain the shipping implementations.
    @MainActor
    func testFreshInstallReachesSpokenSummaryBeforeContextualPaywall() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_REAL_FIRST_RUN",
            "UI_TESTING_FAST_LANE",
            "UI_TESTING_CLEAR_FLOW_EVENTS",
            "UI_TESTING_FIRST_VALUE_LOOP"
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["fastLane.screen"].waitForExistence(timeout: 15))
        let work = app.buttons["fastLane.context.work"]
        let rambling = app.buttons["fastLane.challenge.rambling"]
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        let contextContinue = app.buttons["fastLane.contextContinue"]
        XCTAssertTrue(contextContinue.waitForExistence(timeout: 5))
        contextContinue.tap()
        XCTAssertTrue(rambling.waitForExistence(timeout: 5))
        scrollUntilHittable(rambling, in: app)
        XCTAssertTrue(rambling.isHittable)
        rambling.tap()

        let beginWritten = app.buttons["fastLane.begin"]
        scrollUntilHittable(beginWritten, in: app)
        XCTAssertTrue(beginWritten.waitForExistence(timeout: 5))
        beginWritten.tap()

        let response = app.descendants(matching: .any)["fastLane.response"]
        XCTAssertTrue(response.waitForExistence(timeout: 5))
        response.tap()
        response.typeText("I would name the decision, the owner, and the customer impact before I close.")

        let submit = app.buttons["fastLane.submit"]
        scrollUntilHittable(submit, in: app)
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        submit.tap()

        let spokenProof = app.buttons["fastLane.spokenProof"]
        scrollUntilHittable(spokenProof, in: app)
        XCTAssertTrue(spokenProof.waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["timedPractice.screen"].exists)
        spokenProof.tap()

        XCTAssertTrue(app.descendants(matching: .any)["timedPractice.screen"].waitForExistence(timeout: 12))
        let beginSpoken = app.buttons["timedPractice.begin"]
        XCTAssertTrue(beginSpoken.waitForExistence(timeout: 5))
        beginSpoken.tap()

        let spokenSummary = app.descendants(matching: .any)["summary.postRepVerdict"]
        XCTAssertTrue(
            spokenSummary.waitForExistence(timeout: 15),
            "The user-started spoken proof did not persist and reach its evidence summary."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["paywall.root"].exists,
            "The Day-0 paywall must stay absent until after spoken proof is visible."
        )

        let winCard = app.descendants(matching: .any)["summary.win.card"]
        XCTAssertTrue(
            winCard.waitForExistence(timeout: 5),
            "Day 0 must show one restrained observation backed by the spoken rep."
        )
        XCTAssertTrue(
            app.staticTexts
                .matching(identifier: "summary.win.quote")
                .matching(
                    NSPredicate(
                        format: "label CONTAINS %@",
                        "I would start by naming the decision clearly"
                    )
                )
                .firstMatch
                .waitForExistence(timeout: 5),
            "Day 0 must quote the user's own verified words."
        )
        XCTAssertTrue(
            app.staticTexts
                .matching(identifier: "summary.win.provenance")
                .matching(NSPredicate(format: "label BEGINSWITH %@", "Source: original transcript"))
                .firstMatch
                .waitForExistence(timeout: 5),
            "The quote must carry explicit source provenance."
        )
        let coachRead = app.descendants(matching: .any)["summary.coachRead"]
        XCTAssertTrue(coachRead.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts
                .matching(identifier: "summary.coachRead.observation")
                .matching(NSPredicate(format: "label == %@", "No fillers across the full duration."))
                .firstMatch
                .waitForExistence(timeout: 5),
            "The observation should stay bounded to what this one rep proves."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["summary.exitPanel.drill"]
                .waitForExistence(timeout: 5),
            "Day 0 must prescribe one concrete next action."
        )

        let details = app.buttons["summary.details.toggle"]
        scrollUntilHittable(details, in: app, attempts: 12)
        XCTAssertTrue(
            details.waitForExistence(timeout: 8),
            "Summary did not expose its optional depth disclosure."
        )
        details.tap()

        let proAction = app.buttons["summary.talkToNoum.gated"]
        scrollUntilHittable(proAction, in: app, attempts: 12)
        XCTAssertTrue(
            proAction.waitForExistence(timeout: 8),
            "Summary did not expose the contextual Pro coaching action."
        )
        XCTAssertTrue(proAction.isHittable)
        proAction.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["paywall.root"].waitForExistence(timeout: 8),
            "The contextual post-proof Pro action did not present the StoreKit-backed paywall."
        )
    }

    @MainActor
    func testStructuredValueCanUpgradeThroughPrefilledSetupToSpokenPractice() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_REAL_FIRST_RUN",
            "UI_TESTING_FAST_LANE",
            "UI_TESTING_NO_CLOUD_CONSENT"
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["fastLane.screen"].waitForExistence(timeout: 15))
        let work = app.buttons["fastLane.context.work"]
        let rambling = app.buttons["fastLane.challenge.rambling"]
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        let contextContinue = app.buttons["fastLane.contextContinue"]
        XCTAssertTrue(contextContinue.waitForExistence(timeout: 5))
        contextContinue.tap()
        XCTAssertTrue(rambling.waitForExistence(timeout: 5))
        scrollUntilHittable(rambling, in: app)
        XCTAssertTrue(rambling.isHittable)
        rambling.tap()

        let begin = app.buttons["fastLane.begin"]
        scrollUntilHittable(begin, in: app)
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        begin.tap()

        let response = app.descendants(matching: .any)["fastLane.response"]
        XCTAssertTrue(response.waitForExistence(timeout: 5))
        response.tap()
        response.typeText("The launch needs attention because one dependency is late, so I will reset the date today.")
        let submit = app.buttons["fastLane.submit"]
        scrollUntilHittable(submit, in: app)
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        submit.tap()

        let otherOptions = app.buttons["fastLane.otherOptions"]
        scrollUntilHittable(otherOptions, in: app)
        XCTAssertTrue(otherOptions.waitForExistence(timeout: 8))
        otherOptions.tap()

        let upgrade = app.buttons["fastLane.completeSetup"]
        scrollUntilHittable(upgrade, in: app)
        XCTAssertTrue(upgrade.waitForExistence(timeout: 8))
        upgrade.tap()

        XCTAssertFalse(
            app.buttons["coaching.start"].exists,
            "Fast-lane handoff must not replay the full-profile intro."
        )
        XCTAssertTrue(
            app.staticTexts["Final choice"].waitForExistence(timeout: 8),
            "Fast-lane handoff must resume at the one unanswered profile choice."
        )
        XCTAssertFalse(
            app.buttons["coaching.option.work"].exists,
            "The already-saved context must not be asked again."
        )
        XCTAssertFalse(
            app.buttons["coaching.option.rambling"].exists,
            "The already-saved challenge must not be asked again."
        )

        let concise = app.buttons["coaching.option.concise"]
        scrollUntilHittable(concise, in: app)
        XCTAssertTrue(concise.waitForExistence(timeout: 5))
        concise.tap()
        let continueButton = app.buttons["coaching.continue"]
        scrollUntilHittable(continueButton, in: app)
        continueButton.tap()

        let startPractice = app.buttons["coaching.startPracticing"]
        XCTAssertTrue(startPractice.waitForExistence(timeout: 25))
        startPractice.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["cloudProcessing.disclosure"].waitForExistence(timeout: 8),
            "The structured-upgrade contract must exercise the real cloud-processing disclosure."
        )
        let declineCloud = app.buttons["cloudProcessing.notNow"]
        scrollUntilHittable(declineCloud, in: app)
        XCTAssertTrue(declineCloud.waitForExistence(timeout: 3) && declineCloud.isHittable)
        declineCloud.tap()

        let beginRecommendedRep = app.buttons["home.coachCard.begin"]
        XCTAssertTrue(
            beginRecommendedRep.waitForExistence(timeout: 12),
            "Completing setup should offer the prefilled profile's recommended rep on Today."
        )
        beginRecommendedRep.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["timedPractice.screen"].waitForExistence(timeout: 12),
            "The rambling-focused recommendation should reach the existing local-capable Timed route after an explicit tap."
        )
    }

    @MainActor
    private func assertMinimumTapTarget(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(
            element.frame.height,
            44,
            "Interactive controls must retain a 44-point minimum target.",
            file: file,
            line: line
        )
    }

    @MainActor
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 6
    ) {
        guard !element.isHittable else { return }
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.exists else { return }

        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            scrollView.swipeUp(velocity: .slow)
        }
    }
}
