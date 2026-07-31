import XCTest

final class NoumUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeScreenAndPrimaryNavigation() throws {
        let app = launchApp()

        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
        app.terminate()

        // The V4.6 one-screen Home no longer renders a journey card, so the
        // tap-by-id branch below normally falls through to the noum://path
        // deep-link fallback. Both paths assert the journey screen is
        // reachable; the tap branch is kept so a future Home entry point
        // is exercised automatically if one returns.
        let pathApp = launchApp()
        let pathCard = pathApp.descendants(matching: .any)["home.path"]
        if pathCard.waitForExistence(timeout: 5) {
            scrollUntilHittable(pathCard, in: pathApp)
            pathCard.tap()
            XCTAssertTrue(pathApp.descendants(matching: .any)["journey.screen"].waitForExistence(timeout: 5))
            pathApp.terminate()
        } else {
            pathApp.terminate()
            let fallbackApp = launchSeededAt("noum://path")
            XCTAssertTrue(fallbackApp.descendants(matching: .any)["journey.screen"].waitForExistence(timeout: 5))
            fallbackApp.terminate()
        }
        // The old progressCard (which carried `home.rank`) was removed from
        // the home during the M14 consolidation — rank now lives on the
        // Profile tab. The Profile destination is exercised by tapping the
        // bottom-nav social button instead.

        let historyApp = launchApp()
        XCTAssertTrue(historyApp.buttons["nav.history"].waitForExistence(timeout: 5))
        historyApp.buttons["nav.history"].tap()
        XCTAssertTrue(historyApp.descendants(matching: .any)["history.screen"].waitForExistence(timeout: 5))

        historyApp.terminate()
        // V4.6 four-tab IA: Settings lives under You — open it through the
        // gear on the Profile root rather than a fifth tab button.
        let settingsApp = launchApp()
        XCTAssertTrue(settingsApp.buttons["nav.social"].waitForExistence(timeout: 5))
        settingsApp.buttons["nav.social"].tap()
        let openSettings = settingsApp.buttons["profile.openSettings"]
        XCTAssertTrue(openSettings.waitForExistence(timeout: 5))
        openSettings.tap()
        XCTAssertTrue(settingsApp.descendants(matching: .any)["settings.screen"].waitForExistence(timeout: 5))

        settingsApp.terminate()
        let practiceApp = launchApp()
        openPracticeModes(in: practiceApp)
        XCTAssertTrue(practiceApp.descendants(matching: .any)["practiceModes.screen"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSignedOutSettingsPresentsAccountOptions() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_RESTORE_PERSISTED_ACCOUNT",
            "UI_TESTING_REAL_FIRST_RUN",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_AUTHENTICATED_COACH",
            "UI_TESTING_SIGNED_OUT",
        ]
        app.launch()

        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 10))
        let youTab = app.buttons["nav.social"]
        XCTAssertTrue(youTab.waitForExistence(timeout: 5))
        youTab.tap()
        let openSettings = app.buttons["profile.openSettings"]
        XCTAssertTrue(openSettings.waitForExistence(timeout: 5))
        openSettings.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.screen"].waitForExistence(timeout: 5))

        let openLogin = app.buttons["settings.account.openLogin"]
        for _ in 0..<10 where !openLogin.isHittable {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(openLogin.waitForExistence(timeout: 3))
        XCTAssertTrue(openLogin.isHittable)
        XCTAssertFalse(
            app.buttons["settings.account.delete"].exists,
            "Signed-out Settings must not expose account deletion."
        )
        openLogin.tap()

        let loginScreen = app.descendants(matching: .any)["login.screen"]
        XCTAssertTrue(loginScreen.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["login.apple"].waitForExistence(timeout: 3))

        let otherOptions = app.descendants(matching: .any)["login.otherOptions"]
        XCTAssertTrue(otherOptions.waitForExistence(timeout: 3))
        otherOptions.tap()
        XCTAssertTrue(app.descendants(matching: .any)["login.google"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["login.guest"].waitForExistence(timeout: 3))

        let close = app.buttons["login.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        close.tap()
        XCTAssertFalse(loginScreen.waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["settings.screen"].exists)
    }

    @MainActor
    func testProfileEvidenceDisclosureStaysCoachEvidenceOnly() throws {
        let app = launchSeededAt("noum://profile")
        XCTAssertTrue(app.descendants(matching: .any)["profile.screen"].waitForExistence(timeout: 10))

        let toggle = app.descendants(matching: .any)["profile.evidenceHub.toggle"]
        let toggleLabel = app.staticTexts["Show profile library"]
        for _ in 0..<10 where !toggle.exists && !toggleLabel.exists {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(
            toggle.waitForExistence(timeout: 3) || toggleLabel.waitForExistence(timeout: 3),
            "Profile evidence toggle should exist"
        )
        if toggle.exists {
            scrollUntilHittable(toggle, in: app, attempts: 3)
            toggle.tap()
        } else {
            toggleLabel.tap()
        }

        XCTAssertTrue(
            app.buttons["Hide profile library"].waitForExistence(timeout: 5)
                || app.staticTexts["Hide profile library"].waitForExistence(timeout: 2),
            "Profile library disclosure should expand"
        )

        let evidenceRow = app.descendants(matching: .any)["profile.evidence.baselineMap.row"]
        scrollUntilHittable(evidenceRow, in: app, attempts: 4)
        XCTAssertTrue(evidenceRow.waitForExistence(timeout: 5))
        evidenceRow.tap()

        let whyPlan = app.buttons["profile.evidence.whyPlan.toggle"]
        scrollUntilHittable(whyPlan, in: app, attempts: 4)
        XCTAssertTrue(whyPlan.waitForExistence(timeout: 5) && whyPlan.isHittable)
        whyPlan.tap()

        let coachingDirection = app.descendants(matching: .any)["profile.evidence.coachingDirection"]
        let coachingDirectionTitle = app.staticTexts["Coaching Direction"]
        let coachingDirectionUppercaseTitle = app.staticTexts["COACHING DIRECTION"]
        for _ in 0..<8 where !coachingDirection.exists
            && !coachingDirectionTitle.exists
            && !coachingDirectionUppercaseTitle.exists {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(
            coachingDirection.exists || coachingDirectionTitle.exists || coachingDirectionUppercaseTitle.exists,
            "Expanded evidence should keep the coach direction card"
        )

        // NOTE (S2 progression spine): profile.evidence.rankProgress is no
        // longer banned — it returns as a quiet "Practice volume" row
        // rendered BELOW the rating trajectory (order pinned by the
        // ProfileCollapseContractTests plan test).
        let hiddenDashboardSurfaces = [
            "profile.evidence.skillProgress",
            "profile.evidence.activeChallenge",
            "profile.evidence.feedbackInbox",
            "profile.league",
            "profile.community.challenge",
            "profile.achievements.summary"
        ]
        for _ in 0..<8 {
            for identifier in hiddenDashboardSurfaces {
                XCTAssertFalse(
                    app.descendants(matching: .any)[identifier].exists,
                    "\(identifier) should stay out of the Profile evidence disclosure"
                )
            }
            XCTAssertFalse(app.staticTexts["Optional systems"].exists)
            app.swipeUp(velocity: .slow)
        }

        app.terminate()
    }

    @MainActor
    func testPracticeModesOpenAvailableScreens() throws {
        assertPracticeModeLaunches(modeIdentifier: "practiceMode.timed", screenIdentifier: "timedPractice.screen")
        assertPracticeModeLaunches(modeIdentifier: "practiceMode.suddenDeath", screenIdentifier: "suddenDeath.screen")
        assertPracticeModeLaunches(modeIdentifier: "practiceMode.ahCounter", screenIdentifier: "ahCounter.screen")

        let imApp = launchSeededAt("noum://practice")

        let imButton = imApp.buttons["practiceMode.imConversation"]
        if imButton.waitForExistence(timeout: 2) {
            imButton.tap()
            XCTAssertTrue(imApp.buttons["practiceModes.start"].waitForExistence(timeout: 5))
            imApp.buttons["practiceModes.start"].tap()
            // IM has a runtime availability gate (premium / feature flag) and
            // falls back to timedPractice when unavailable, so accept either
            // destination — the assertion is that a practice screen
            // surfaced, not which one.
            let imDestination = imApp.descendants(matching: .any)["imPractice.screen"]
            let fallback = imApp.descendants(matching: .any)["timedPractice.screen"]
            let landed = imDestination.waitForExistence(timeout: 10) || fallback.waitForExistence(timeout: 5)
            XCTAssertTrue(landed, "IM start did not land on imPractice.screen or timedPractice.screen fallback")
        }
    }

    @MainActor
    func testReviewDetailPracticeAgainLaunchesMatchingMode() throws {
        let app = launchSeededAt("noum://review")
        XCTAssertTrue(app.descendants(matching: .any)["history.screen"].waitForExistence(timeout: 10))

        let sessionListEntry = app.descendants(matching: .any)["history.sessionListEntry"]
        XCTAssertTrue(sessionListEntry.waitForExistence(timeout: 5))
        sessionListEntry.tap()

        let firstSession = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'history.row.'"))
            .element(boundBy: 0)
        XCTAssertTrue(firstSession.waitForExistence(timeout: 5))
        firstSession.tap()

        let practiceAgain = app.buttons["history.detail.practiceAgain"]
        XCTAssertTrue(practiceAgain.waitForExistence(timeout: 5))
        scrollUntilHittable(practiceAgain, in: app, attempts: 6)
        XCTAssertTrue(practiceAgain.isHittable)
        XCTAssertGreaterThanOrEqual(practiceAgain.frame.height, 48)

        practiceAgain.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["timedPractice.screen"].waitForExistence(timeout: 10),
            "The seeded Timed session should route back to Timed Practice."
        )
    }

    @MainActor
    func testOnboardingFlowSmoke() throws {
        let app = XCUIApplication()
        // UI_TESTING_REAL_FIRST_RUN clears the persisted identity inside
        // AuthManager, establishes a network-independent local guest, hydrates
        // that account, and only then presents the production onboarding root.
        app.launchArguments += ["UI_TESTING", "UI_TESTING_REAL_FIRST_RUN"]
        app.launch()

        XCTAssertFalse(
            app.descendants(matching: .any)["firstRun.bootstrap.error"].waitForExistence(timeout: 1),
            "A clean Keychain should fall back to a durable local guest instead of dead-ending."
        )
        try completeCoachingOnboarding(in: app)

        // Final stage CTA: `coaching.startPracticing` (was `coaching.save`
        // before the redesign). This test opts into the real app-level
        // first-run cover, not the pinned `UI_TESTING_ONBOARDING` harness.
        // Saving the profile must reach Today with an explicit first-rep
        // offer; automatic capture remains disabled until signed-device QA
        // closes. The save itself proves the clean local guest supplied a
        // durable account ID; the old implementation silently failed here
        // with an empty Keychain.
        let finishButton = app.buttons["coaching.startPracticing"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 25))
        XCTAssertTrue(finishButton.isEnabled)
        finishButton.tap()
        allowCloudProcessingIfPresented(in: app)

        XCTAssertTrue(
            app.descendants(matching: .any)["home.screen"].waitForExistence(timeout: 12),
            "First-run completion should reach Today after the profile is saved."
        )
        let begin = app.buttons["home.coachCard.begin"]
        XCTAssertTrue(
            begin.waitForExistence(timeout: 5) && begin.isHittable,
            "Today should offer the first focused rep without opening capture automatically."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["timedPractice.screen"].exists,
            "Finishing onboarding must not start microphone capture before the user taps Begin."
        )
    }

    @MainActor
    func testFirstRunCloudDeclineStillReachesLocalCapablePractice() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_REAL_FIRST_RUN", "UI_TESTING_NO_CLOUD_CONSENT"]
        app.launch()

        try completeCoachingOnboarding(in: app)
        let finishButton = app.buttons["coaching.startPracticing"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 25))
        finishButton.tap()
        let disclosure = app.descendants(matching: .any)["cloudProcessing.disclosure"]
        XCTAssertTrue(
            disclosure.waitForExistence(timeout: 8),
            "The decline contract must exercise the real cloud-processing disclosure."
        )
        let notNow = app.buttons["cloudProcessing.notNow"]
        scrollUntilHittable(notNow, in: app, attempts: 8)
        XCTAssertTrue(notNow.waitForExistence(timeout: 3) && notNow.isHittable)
        notNow.tap()

        let begin = app.buttons["home.coachCard.begin"]
        XCTAssertTrue(
            begin.waitForExistence(timeout: 12),
            "Declining cloud processing must still offer the profile's local-capable first rep."
        )
        begin.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["ahCounter.screen"].waitForExistence(timeout: 12),
            "The filler-focused profile should open its local-capable Filler Control route."
        )
    }

    @MainActor
    func testFirstRunProviderFailureHasRecoveryInsteadOfDeadEnd() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING", "UI_TESTING_REAL_FIRST_RUN", "UI_TESTING_CLOUD_CONSENT",
            "UI_TESTING_MICROPHONE_GRANTED", "UI_TESTING_TRANSCRIPTION_START_FAILURE"
        ]
        app.launch()

        try completeCoachingOnboarding(in: app)
        let finishButton = app.buttons["coaching.startPracticing"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 25))
        finishButton.tap()
        declineCloudProcessingIfPresented(in: app)

        // Finishing setup lands on Today, not in a recorder. `AutoGuidedFirstRep`
        // is default-OFF by design — automatic capture stays off until the
        // signed-device matrix is complete, so production reaches the first rep
        // through `prepareUserInitiatedSpokenProof`, which needs an explicit tap.
        // Asserting a push straight into Timed would assert the disabled lane.
        XCTAssertTrue(
            app.buttons["home.coachCard.begin"].waitForExistence(timeout: 12),
            "Finishing setup must offer the first rep on Today."
        )

        // That Home offer opens whichever mode the coach recommends (this
        // answer set gets Filler Control), so it cannot carry the Timed
        // recovery contract. Relaunch into Timed keeping the account this real
        // first run just created — dropping REAL_FIRST_RUN so nothing resets.
        app.terminate()
        app.launchArguments = [
            "UI_TESTING", "UI_TESTING_CLOUD_CONSENT",
            "UI_TESTING_RESTORE_PERSISTED_ACCOUNT",
            "UI_TESTING_MICROPHONE_GRANTED", "UI_TESTING_TRANSCRIPTION_START_FAILURE",
            "-DeepLink", "noum://practice/timed",
        ]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["timedPractice.screen"].waitForExistence(timeout: 12))

        let begin = app.buttons["timedPractice.begin"]
        if begin.waitForExistence(timeout: 8) {
            tapTimedPracticeBegin(begin, in: app)
        }
        let startNow = app.buttons["timedPractice.startNow"]
        if startNow.waitForExistence(timeout: 3), startNow.isHittable { startNow.tap() }

        let issue = app.descendants(matching: .any)["timedPractice.recordingIssue"]
        XCTAssertTrue(issue.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["timedPractice.recordingIssue.retry"].exists)
        // The failure must never be a dead end: the retry is paired with an
        // exit, so an unsatisfiable retry cannot trap the user in the rep.
        XCTAssertTrue(app.buttons["timedPractice.recordingIssue.exit"].exists)
        XCTAssertFalse(app.staticTexts["Elapsed"].exists)
    }

    @MainActor
    func testCompletedOnboardingSurvivesInterruptionAndRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_REAL_FIRST_RUN", "UI_TESTING_CLOUD_CONSENT"]
        app.launch()

        try completeCoachingOnboarding(in: app)
        let finishButton = app.buttons["coaching.startPracticing"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 25))
        finishButton.tap()
        XCTAssertTrue(
            app.buttons["home.coachCard.begin"].waitForExistence(timeout: 12),
            "Completed onboarding should persist after reaching Today, without requiring automatic capture."
        )
        app.terminate()

        let relaunched = XCUIApplication()
        relaunched.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_RESTORE_PERSISTED_ACCOUNT",
        ]
        relaunched.launch()
        XCTAssertTrue(relaunched.buttons["app.tab.home"].waitForExistence(timeout: 15))
        XCTAssertFalse(relaunched.buttons["coaching.start"].exists)
        let restoredRecommendation = relaunched.buttons["home.coachCard.begin"]
        XCTAssertTrue(
            restoredRecommendation.waitForExistence(timeout: 8),
            "The restored profile must rebuild its Today recommendation."
        )
        XCTAssertEqual(
            restoredRecommendation.label,
            "Start your first rep",
            "A restored profile with no completed rep should keep the honest cold-start CTA."
        )
        restoredRecommendation.tap()
        XCTAssertTrue(
            relaunched.descendants(matching: .any)["ahCounter.screen"]
                .waitForExistence(timeout: 12),
            "The restored filler-focused profile must route its first recommendation to Filler Control; merely showing the generic UI-test shell is not persistence proof."
        )
    }

    @MainActor
    func testOnboardingCustomChallengePath() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_REAL_FIRST_RUN"]
        app.launch()

        XCTAssertTrue(app.buttons["coaching.start"].waitForExistence(timeout: 15))
        app.buttons["coaching.start"].tap()

        try selectFirstOption(in: app, after: ["coaching.option.work", "coaching.option.interviews", "coaching.option.presentations", "coaching.option.social"])
        XCTAssertTrue(app.buttons["coaching.continue"].waitForExistence(timeout: 5))
        app.buttons["coaching.continue"].tap()

        let custom = app.buttons["coaching.option.customChallenge"]
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        scrollUntilHittable(custom, in: app, attempts: 2)
        let customHittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: custom)
        wait(for: [customHittable], timeout: 5)
        custom.tap()

        let input = app.descendants(matching: .any)["coaching.customChallenge.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("I sound defensive when challenged")

        let keyboardNext = app.keyboards.buttons["Next"]
        if keyboardNext.waitForExistence(timeout: 1) {
            keyboardNext.tap()
        } else {
            let next = app.buttons["coaching.continue"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            scrollUntilHittable(next, in: app, attempts: 2)
            next.tap()
        }

        try selectFirstOption(in: app, after: SpeakingStyleGoalOptionIDs.all)
        app.buttons["coaching.continue"].tap()

        XCTAssertTrue(app.staticTexts["I sound defensive when challenged"].waitForExistence(timeout: 25))

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "onboarding-custom-challenge-summary"
        shot.lifetime = .keepAlways
        add(shot)

        XCTAssertTrue(app.buttons["coaching.startPracticing"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFirstRunCreatesAccountThenTimedHarnessReachesFirstVerdict() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_REAL_FIRST_RUN",
            "UI_TESTING_FIRST_VALUE_LOOP",
            "UI_TESTING_CLOUD_CONSENT",
            "UI_TESTING_CLEAR_DEFERRED_CAPTURE"
        ]
        app.launch()

        try completeCoachingOnboarding(in: app)

        let finishButton = app.buttons["coaching.startPracticing"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 25))
        finishButton.tap()

        let firstRepCTA = app.buttons["home.coachCard.begin"]
        XCTAssertTrue(
            firstRepCTA.waitForExistence(timeout: 12),
            "Finishing setup must offer the first rep on Today."
        )
        XCTAssertTrue(firstRepCTA.isHittable, "The first-rep CTA must be actionable on Today.")

        // This fixture exercises the Timed post-rep pipeline specifically.
        // Preserve the account created above, then enter that route explicitly
        // instead of asserting the disabled automatic first-rep lane.
        app.terminate()
        app.launchArguments = [
            "UI_TESTING",
            "UI_TESTING_RESTORE_PERSISTED_ACCOUNT",
            "UI_TESTING_FIRST_VALUE_LOOP",
            "UI_TESTING_CLOUD_CONSENT",
            "UI_TESTING_CLEAR_DEFERRED_CAPTURE",
            "-DeepLink",
            "noum://practice/timed",
        ]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["timedPractice.screen"].waitForExistence(timeout: 10))
        let begin = app.buttons["timedPractice.begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10))
        tapTimedPracticeBegin(begin, in: app)

        let verdict = advanceToPostRepVerdict(in: app)

        XCTAssertTrue(
            verdict.waitForExistence(timeout: 20),
            "The persisted first-run account should reach the Timed post-rep verdict through the explicit UI-test harness."
        )
        XCTAssertTrue(
            app.buttons["summary.postRepVerdict.startMiniDrill"].exists
            || app.buttons["summary.postRepVerdict.fullRetry"].exists
            || app.buttons["summary.postRepVerdict.startFullRetry"].exists,
            "The first verdict should include a concrete next action, not just explanatory text."
        )

        let details = app.descendants(matching: .any)["summary.details.toggle"]
        scrollUntilHittable(details, in: app, attempts: 8)
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        details.tap()
        let deferredGoal = app.buttons["deferredCapture.expand"]
        scrollUntilHittable(deferredGoal, in: app, attempts: 8)
        XCTAssertTrue(
            deferredGoal.waitForExistence(timeout: 8),
            "The existing deferred-profile owner should offer the first reflection after value, not during onboarding."
        )
        let dismiss = app.buttons["deferredCapture.dismiss"]
        // XCUI converts simulator pixels back to points and can report an
        // exact 44pt target as 43.999999999999886. Round only that sub-pixel
        // representation; a genuinely undersized 43pt target still fails.
        XCTAssertGreaterThanOrEqual(
            dismiss.frame.height.rounded(.toNearestOrAwayFromZero),
            44
        )
    }

    @MainActor
    private func advanceToPostRepVerdict(in app: XCUIApplication, timeout: TimeInterval = 45) -> XCUIElement {
        let verdict = app.descendants(matching: .any)["summary.postRepVerdict"]
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if verdict.exists { return verdict }

            let begin = app.buttons["timedPractice.begin"]
            if begin.exists {
                tapTimedPracticeBegin(begin, in: app)
                Thread.sleep(forTimeInterval: 0.5)
                continue
            }

            let startNow = app.buttons["timedPractice.startNow"]
            if startNow.exists && startNow.isHittable {
                startNow.tap()
                Thread.sleep(forTimeInterval: 0.4)
                continue
            }

            let firstRepContinue = app.buttons["firstRep.celebration.continue"]
            if firstRepContinue.exists && firstRepContinue.isHittable {
                firstRepContinue.tap()
                Thread.sleep(forTimeInterval: 0.5)
                continue
            }

            let viewSummary = app.buttons["postSessionProgression.viewSummary"]
            if viewSummary.exists && viewSummary.isHittable {
                viewSummary.tap()
                Thread.sleep(forTimeInterval: 0.5)
                continue
            }

            let fallbackViewSummary = app.buttons["View Summary"]
            if fallbackViewSummary.exists && fallbackViewSummary.isHittable {
                fallbackViewSummary.tap()
                Thread.sleep(forTimeInterval: 0.5)
                continue
            }

            let continueButton = app.buttons["Continue"]
            if continueButton.exists && continueButton.isHittable {
                continueButton.tap()
                Thread.sleep(forTimeInterval: 0.5)
                continue
            }

            Thread.sleep(forTimeInterval: 0.5)
        }

        return verdict
    }

    @MainActor
    private func tapTimedPracticeBegin(_ begin: XCUIElement, in app: XCUIApplication) {
        scrollUntilHittable(begin, in: app, attempts: 2)
        if begin.isHittable {
            begin.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        }
    }

    @MainActor
    private func allowCloudProcessingIfPresented(in app: XCUIApplication) {
        let disclosure = app.descendants(matching: .any)["cloudProcessing.disclosure"]
        guard disclosure.waitForExistence(timeout: 5) else { return }
        let allow = app.buttons["cloudProcessing.allow"]
        scrollUntilHittable(allow, in: app, attempts: 8)
        XCTAssertTrue(
            allow.waitForExistence(timeout: 3) && allow.isHittable,
            "First-run cloud disclosure must provide an actionable Allow control."
        )
        allow.tap()
    }

    @MainActor
    private func declineCloudProcessingIfPresented(in app: XCUIApplication) {
        let disclosure = app.descendants(matching: .any)["cloudProcessing.disclosure"]
        guard disclosure.waitForExistence(timeout: 5) else { return }
        let notNow = app.buttons["cloudProcessing.notNow"]
        scrollUntilHittable(notNow, in: app, attempts: 8)
        XCTAssertTrue(notNow.waitForExistence(timeout: 3) && notNow.isHittable)
        notNow.tap()
    }

    @MainActor
    private func completeCoachingOnboarding(in app: XCUIApplication) throws {
        XCTAssertTrue(app.buttons["coaching.start"].waitForExistence(timeout: 15))
        app.buttons["coaching.start"].tap()

        // Post-M14 onboarding is three single-choice stages (context →
        // challenge → style). Each stage exposes its options with the
        // `coaching.option.<id>` identifier and the next button keeps
        // the same `coaching.continue` id.
        try selectFirstOption(in: app, after: ["coaching.option.work", "coaching.option.interviews", "coaching.option.presentations", "coaching.option.social"])
        XCTAssertTrue(app.buttons["coaching.continue"].waitForExistence(timeout: 5))
        app.buttons["coaching.continue"].tap()

        try selectFirstOption(in: app, after: SpeakingChallengeOptionIDs.all)
        app.buttons["coaching.continue"].tap()

        try selectFirstOption(in: app, after: SpeakingStyleGoalOptionIDs.all)
        app.buttons["coaching.continue"].tap()

        // Final stage CTA: `coaching.startPracticing` (was `coaching.save`
        // before the redesign). This helper opts into the real app-level
        // first-run cover, not the pinned `UI_TESTING_ONBOARDING` harness.
        // Callers decide whether to verify the Today handoff or explicitly
        // start the recommended rep.
        let finishButton = app.buttons["coaching.startPracticing"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 25))
        XCTAssertTrue(finishButton.isEnabled)
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
        let app = launchSeededAt("noum://practice")

        if launchRecommendedHeroIfMatching(modeIdentifier: modeIdentifier, screenIdentifier: screenIdentifier, in: app) {
            app.terminate()
            return
        }

        let modeButton = app.buttons[modeIdentifier]
        if !modeButton.waitForExistence(timeout: 2) {
            let otherWays = app.buttons["practiceModes.otherWays"]
            if otherWays.waitForExistence(timeout: 5) {
                otherWays.tap()
            }
        }
        XCTAssertTrue(modeButton.waitForExistence(timeout: 5))
        modeButton.tap()

        // The picker's `.task` recommendation can race with the test's tap
        // and overwrite selectedMode. Wait for the mode tile to carry the
        // .isSelected trait so we know the binding settled on our pick
        // before firing the start CTA.
        let selectedPredicate = NSPredicate(format: "isSelected == true")
        let selectedExpectation = expectation(for: selectedPredicate, evaluatedWith: modeButton)
        wait(for: [selectedExpectation], timeout: 5)

        XCTAssertTrue(app.buttons["practiceModes.start"].waitForExistence(timeout: 5))
        app.buttons["practiceModes.start"].tap()

        // Practice screens can surface their identifier on different
        // XCUIElementTypes depending on internal composition (Other for
        // SwiftUI ZStacks, NavigationBar pairings, etc.). Use a broad match
        // so the test doesn't false-fail on element type drift.
        let destination = app.descendants(matching: .any)[screenIdentifier]
        XCTAssertTrue(destination.waitForExistence(timeout: 20))
        app.terminate()
    }

    @MainActor
    private func launchRecommendedHeroIfMatching(
        modeIdentifier: String,
        screenIdentifier: String,
        in app: XCUIApplication
    ) -> Bool {
        guard let expectedTitle = practiceModeTitle(for: modeIdentifier) else { return false }
        let recommendedBegin = app.buttons["practiceModes.recommendedHero.begin"]
        guard recommendedBegin.waitForExistence(timeout: 3),
              recommendedBegin.label.contains(expectedTitle) else {
            return false
        }
        // The hero "Begin" now auto-begins the rep (one-tap prescription), so it
        // no longer lands on the mode's SETUP screen. Reach the setup screen via
        // the hero's "Adjust this rep" affordance, which navigates to setup
        // without arming quick-start — still confirms the mode's screen opens.
        let adjust = app.buttons["practiceModes.recommendedHero.adjust"]
        guard adjust.waitForExistence(timeout: 3) else { return false }
        adjust.tap()
        let destination = app.descendants(matching: .any)[screenIdentifier]
        XCTAssertTrue(destination.waitForExistence(timeout: 20))
        return true
    }

    private func practiceModeTitle(for identifier: String) -> String? {
        switch identifier {
        case "practiceMode.timed":
            return "Timed Practice"
        case "practiceMode.suddenDeath":
            return "Pressure Drill"
        case "practiceMode.ahCounter":
            return "Filler Control"
        case "practiceMode.imConversation":
            return "Conversation Practice"
        default:
            return nil
        }
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        // UI_TESTING suppresses the splash / onboarding hero.
        // UI_TESTING_SEED injects the improving-intermediate dev profile so
        // the home renders its populated layout instead of the cold-start
        // empty state.
        app.launchArguments += ["UI_TESTING", "UI_TESTING_SEED"]
        app.launch()
        return app
    }

    /// Cold-launch with seed + a `-DeepLink` arg so the app routes straight
    /// to the target screen without depending on a tap target whose visibility
    /// is gated by signal-derived data the seed doesn't populate. Mirror of
    /// `ScreenshotTour.launchSeededAt` — duplicated here to keep `NoumUITests`
    /// self-contained.
    @MainActor
    private func launchSeededAt(_ deepLink: String, extraArgs: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_CLEAR_ASK_NOUM"
        ] + extraArgs + ["-DeepLink", deepLink]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 10)
        Thread.sleep(forTimeInterval: 1.0)
        return app
    }

    @MainActor
    private func openPracticeModes(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["nav.practice"].waitForExistence(timeout: 5))
        app.buttons["nav.practice"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["practiceModes.screen"].waitForExistence(timeout: 8))
    }

    /// Scrolls the home until the target becomes hittable, then stops. Bails
    /// out after a small number of attempts so the suite fails fast if the
    /// element really isn't on the screen.
    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 4) {
        guard !element.isHittable else { return }
        let scroll = app.scrollViews.firstMatch
        guard scroll.exists else { return }
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            scroll.swipeUp(velocity: .slow)
        }
    }

    /// Taps the first option whose identifier is present, so the test stays
    /// robust to options being reordered.
    @MainActor
    private func selectFirstOption(in app: XCUIApplication, after candidates: [String]) throws {
        for id in candidates {
            let button = app.buttons[id]
            if button.waitForExistence(timeout: 5) {
                button.tap()
                return
            }
        }
        XCTFail("None of the expected option identifiers were found: \(candidates)")
    }

    // MARK: - Ask Noum in-chat goal change (confirm-before-commit + blend)
    //
    // Verifies the fix for the screenshotted dead-end where the coach refused
    // to set/change the user's voice and punted to settings. The seed profile
    // is `.authoritative`; typing a change request must surface the in-chat
    // goal-proposal card with the coach-like options (switch / blend / keep),
    // proving (a) intent detection fires deterministically (no API key in the
    // sim) and (b) the change is offered as a confirm-before-commit card, not
    // a silent write or a refusal.
    @MainActor
    func testAskNoumGoalChangeSurfacesConfirmationCard() throws {
        let app = launchSeededAt(
            "noum://ask/type",
            extraArgs: [
                "UI_TESTING_AUTHENTICATED_COACH",
                "UI_TESTING_CHAT_FORCE_GOAL_REPLY",
            ]
        )

        // Land on the chat.
        let input = app.descendants(matching: .any)["askNoum.inputControl"]
        XCTAssertTrue(input.waitForExistence(timeout: 10), "Ask Noum input control should exist")

        // Type a voice-change request (seed voice is authoritative -> concise).
        let field = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Message field should exist")
        field.tap()
        // NOTE: the field is `axis: .vertical`, so a trailing "\n" inserts a
        // newline into the draft rather than submitting — send via the unified
        // input control instead (verified working via the captured UI
        // hierarchy: the tap dispatches trySend()).
        field.typeText("I want to change my voice goal to concise and sharp")
        input.tap()

        // Capture the post-send state for the record.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "ask-noum-after-goal-change-send"
        shot.lifetime = .keepAlways
        add(shot)

        // The deterministic goal-proposal card must appear — the fix for the
        // screenshotted dead-end (coach refusing and punting to settings). The
        // concrete commit chip is `set.concise` when the profile has no voice
        // yet (initial set) or `switch.concise` when changing an existing one;
        // accept either so the test is robust to the seed's profile state.
        let setChip = app.buttons["askNoum.goalProposal.set.concise"]
        let switchChip = app.buttons["askNoum.goalProposal.switch.concise"]
        let commitChip = setChip.waitForExistence(timeout: 12) ? setChip
            : (switchChip.waitForExistence(timeout: 2) ? switchChip : setChip)
        XCTAssertTrue(commitChip.exists,
            "Goal request must surface the in-chat confirm-before-commit card (set/switch concise), not a refusal")

        // The decline option must always exist — the change is the user's call,
        // committed only on an explicit tap (the LLM never writes the profile).
        XCTAssertTrue(app.buttons["askNoum.goalProposal.decline"].exists
            || app.buttons["askNoum.goalProposal.keep"].exists,
            "Card must offer a decline/keep option — confirm-before-commit")

        // Tapping the commit chip is the only profile-write path; the card
        // collapses afterward.
        commitChip.tap()
        XCTAssertFalse(commitChip.waitForExistence(timeout: 3),
            "Confirmation card should collapse after the user taps a chip")

        app.terminate()
    }

    /// Regression for the screenshotted "Engaging" bug: a NON-CANONICAL voice
    /// descriptor ("engaging" — not one of the six voices) must now map to the
    /// closest real voice (Storytelling) and surface the confirm-before-commit
    /// card, instead of the coach narrating "You have chosen Engaging…" and
    /// silently accepting a goal change in prose. The seed voice is
    /// authoritative, so a change request yields switch/blend storytelling chips.
    @MainActor
    func testNonCanonicalVoiceDescriptorSurfacesCard() throws {
        let app = launchSeededAt(
            "noum://ask/type",
            extraArgs: [
                "UI_TESTING_AUTHENTICATED_COACH",
                "UI_TESTING_CHAT_FORCE_GOAL_REPLY",
            ]
        )

        let input = app.descendants(matching: .any)["askNoum.inputControl"]
        XCTAssertTrue(input.waitForExistence(timeout: 10), "Ask Noum input control should exist")

        let field = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Message field should exist")
        field.tap()
        field.typeText("I want to change my voice to sound more engaging")
        input.tap()

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "ask-noum-engaging-maps-to-storytelling"
        shot.lifetime = .keepAlways
        add(shot)

        // "engaging" → Storytelling. The card MUST appear with a storytelling
        // commit chip — `set.storytelling` (initial set) or `switch.storytelling`
        // (change from an existing voice), depending on profile state. The proof
        // the non-canonical descriptor no longer slips past the detector into
        // silent prose acceptance.
        let setChip = app.buttons["askNoum.goalProposal.set.storytelling"]
        let switchChip = app.buttons["askNoum.goalProposal.switch.storytelling"]
        let cardAppeared = setChip.waitForExistence(timeout: 12)
            || switchChip.waitForExistence(timeout: 2)
        XCTAssertTrue(cardAppeared,
            "A non-canonical descriptor ('engaging') must map to Storytelling and surface the goal card, not be silently accepted in prose")
        XCTAssertTrue(app.buttons["askNoum.goalProposal.keep"].exists
            || app.buttons["askNoum.goalProposal.decline"].exists,
            "Card must offer keep/decline — confirm-before-commit")

        app.terminate()
    }
}

// MARK: - Option identifier fixtures
//
// Mirror of the enum cases used in CoachingOnboardingView's stages. Kept in
// the test target so we don't have to expose the enums to XCTest; if the
// enums grow new cases the test will still tap whichever one appears first.

private enum SpeakingChallengeOptionIDs {
    static let all: [String] = [
        "coaching.option.fillerWords",
        "coaching.option.rambling",
        "coaching.option.freezing",
        "coaching.option.rushing"
    ]
}

private enum SpeakingStyleGoalOptionIDs {
    static let all: [String] = [
        "coaching.option.authoritative",
        "coaching.option.warm",
        "coaching.option.concise",
        "coaching.option.persuasive",
        "coaching.option.executive",
        "coaching.option.storytelling"
    ]
}
