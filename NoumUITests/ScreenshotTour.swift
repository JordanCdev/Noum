import XCTest

/// Drives the app through every primary tab + scroll states + sub-flows + key
/// surfaces and saves an XCTAttachment screenshot of each. Used by the
/// `noum-screenshots` skill in `detailed` mode. Run via:
///
///     xcodebuild test \
///       -project Noum.xcodeproj -scheme Noum \
///       -destination 'platform=iOS Simulator,name=iPhone 17' \
///       -only-testing:NoumUITests/ScreenshotTour/testCaptureAdvancementSurfaces \
///       -resultBundlePath /tmp/noum-tour.xcresult
///
/// Targeted completed-state captures can be produced with:
///
///     xcodebuild test \
///       -project Noum.xcodeproj -scheme Noum \
///       -destination 'platform=iOS Simulator,name=iPhone 17' \
///       -only-testing:NoumUITests/ScreenshotTour/testCaptureSuddenDeathResults \
///       -resultBundlePath /tmp/noum-sudden-death-results.xcresult
///
/// Then extract:
///
///     xcrun xcresulttool export attachments \
///       --path /tmp/noum-tour.xcresult \
///       --output-path /tmp/noum-tour-attachments
///
/// `UI_TESTING_SEED_FORCE` always reseeds the `improvingIntermediate`
/// profile so screenshots are deterministic. The seed suppresses overlay
/// celebrations (tier promotion, daily goal, path node, lesson) that would
/// otherwise cover Home and intercept tap targets — see `NoumApp.init`.
/// `-DeepLink noum://<host>` jumps directly to a tab/screen without going
/// through gesture navigation.
final class ScreenshotTour: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true   // keep capturing even if a step misses
    }

    @MainActor
    func testCaptureAdvancementSurfaces() throws {
        // ============================================================
        // SECTION A — Tabs + scroll states (5 tabs × top/mid/bottom)
        // ============================================================

        // ----- HOME -----
        let app = launchSeeded()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5)
        attach(app, name: "01-home-top")
        app.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.5)
        attach(app, name: "02-home-mid")
        app.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.5)
        attach(app, name: "03-home-bottom")
        app.terminate()

        // ----- PROFILE -----
        let profileApp = launchSeededAt("noum://profile")
        Thread.sleep(forTimeInterval: 1.5)
        attach(profileApp, name: "04-profile-top")
        profileApp.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.5)
        attach(profileApp, name: "05-profile-mid")
        profileApp.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.5)
        attach(profileApp, name: "06-profile-bottom")
        profileApp.terminate()

        // ----- REVIEW -----
        let reviewApp = launchSeededAt("noum://review")
        Thread.sleep(forTimeInterval: 1.5)
        attach(reviewApp, name: "07-review-top")
        reviewApp.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.5)
        attach(reviewApp, name: "08-review-bottom")

        // Session detail — rows live on the Session History sub-page now
        // (the Review home is insight-first), so step through the entry
        // card first, then tap the first `history.row.<uuid>` row.
        let listEntry = reviewApp.descendants(matching: .any)["history.sessionListEntry"]
        if listEntry.waitForExistence(timeout: 3) {
            listEntry.tap()
            Thread.sleep(forTimeInterval: 1.0)
            attach(reviewApp, name: "08b-session-history-list")
        }
        let firstSessionRow = reviewApp.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'history.row.'"))
            .element(boundBy: 0)
        if firstSessionRow.waitForExistence(timeout: 3) {
            firstSessionRow.tap()
            Thread.sleep(forTimeInterval: 1.5)
            attach(reviewApp, name: "09-session-detail")
        }
        reviewApp.terminate()

        // ----- SETTINGS -----
        let settingsApp = launchSeededAt("noum://settings")
        Thread.sleep(forTimeInterval: 1.5)
        attach(settingsApp, name: "10-settings-top")
        settingsApp.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.5)
        attach(settingsApp, name: "11-settings-mid")
        settingsApp.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.5)
        attach(settingsApp, name: "12-settings-bottom")
        settingsApp.terminate()

        // ============================================================
        // SECTION B — Practice mode picker + every mode setup
        // ============================================================

        // ----- MODE PICKER -----
        let pickerApp = launchSeededAt("noum://train")
        Thread.sleep(forTimeInterval: 1.5)
        attach(pickerApp, name: "13-mode-picker")

        // ----- TIMED PRACTICE SETUP -----
        captureModeSetup(pickerApp, modeID: "practiceMode.timed", name: "14-timed-setup")

        // ----- SUDDEN DEATH SETUP -----
        captureModeSetup(pickerApp, modeID: "practiceMode.suddenDeath", name: "15-sudden-death-setup")

        // ----- AH-COUNTER SETUP -----
        captureModeSetup(pickerApp, modeID: "practiceMode.ahCounter", name: "16-ah-counter-setup")

        // ----- IM CONVERSATION SETUP -----
        captureModeSetup(pickerApp, modeID: "practiceMode.imConversation", name: "17-im-conversation-setup")

        // ----- CUT THE CRUTCH SETUP -----
        captureModeSetup(pickerApp, modeID: "practiceMode.cutTheCrutch", name: "18-cut-the-crutch-setup")

        pickerApp.terminate()

        // ----- LESSONS HOME (card-style entry, not a pressure mode) -----
        let lessonsApp = launchSeededAt("noum://train")
        Thread.sleep(forTimeInterval: 1.0)
        let lessonsCard = lessonsApp.buttons["practiceMode.lessons"]
        if lessonsCard.waitForExistence(timeout: 5) {
            lessonsCard.tap()
            Thread.sleep(forTimeInterval: 1.2)
            attach(lessonsApp, name: "19-lessons-home")

            // ----- LESSON DETAIL — tap the first known lesson -----
            let firstLesson = lessonsApp.buttons["lessons.row.pause_beats_filler"]
            if firstLesson.waitForExistence(timeout: 3) {
                firstLesson.tap()
                Thread.sleep(forTimeInterval: 1.5)
                attach(lessonsApp, name: "20-lesson-detail")
            }
        }
        lessonsApp.terminate()

        // ----- SPEECH PROJECTS + DETAIL -----
        let projectsApp = launchSeededAt("noum://train")
        Thread.sleep(forTimeInterval: 1.0)
        let projectsCard = projectsApp.buttons["practiceMode.speechProjects"]
        if projectsCard.waitForExistence(timeout: 5) {
            projectsCard.tap()
            Thread.sleep(forTimeInterval: 1.2)
            attach(projectsApp, name: "21-speech-projects")

            // First project row, if the seed populated any — falls back to
            // the empty-state capture above when no projects exist.
            let firstProject = projectsApp.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'speechProjects.row.'"))
                .element(boundBy: 0)
            if firstProject.waitForExistence(timeout: 3) {
                firstProject.tap()
                Thread.sleep(forTimeInterval: 1.2)
                attach(projectsApp, name: "21b-speech-project-detail")
            }
        }
        projectsApp.terminate()

        // ============================================================
        // SECTION C — Path + League (Profile-adjacent destinations)
        // ============================================================

        // ----- LEAGUE -----
        let leagueApp = launchSeededAt("noum://league")
        Thread.sleep(forTimeInterval: 1.5)
        attach(leagueApp, name: "22-league")
        leagueApp.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.5)
        attach(leagueApp, name: "23-league-bottom")
        leagueApp.terminate()

        // ----- PATH JOURNEY -----
        let pathApp = launchSeededAt("noum://path")
        Thread.sleep(forTimeInterval: 1.5)
        attach(pathApp, name: "24-path-journey")
        pathApp.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.5)
        attach(pathApp, name: "25-path-journey-bottom")
        pathApp.terminate()

        // ----- ASK NOUM (M14 coach chat) -----
        let askApp = launchSeededAt("noum://ask")
        Thread.sleep(forTimeInterval: 2.0) // chat seeds opener line on appear
        attach(askApp, name: "25b-ask-noum")
        askApp.terminate()

        let askTypedApp = launchSeededAt(
            "noum://ask/type",
            extraArgs: [
                "UI_TESTING_CLEAR_ASK_NOUM",
                "UI_TESTING_CHAT_FORCE_MARKDOWN_REPLY"
            ]
        )
        let askField = askTypedApp.textViews.firstMatch.exists
            ? askTypedApp.textViews.firstMatch : askTypedApp.textFields.firstMatch
        if askField.waitForExistence(timeout: 6) {
            askField.tap()
            askField.typeText("Be direct with me.")
            askTypedApp.buttons["askNoum.inputControl"].tap()
            Thread.sleep(forTimeInterval: 2.0)
        }
        attach(askTypedApp, name: "25d-ask-noum-typed")
        askTypedApp.terminate()

        // ----- FRIEND LEADERBOARD (via Profile → leaderboard NavigationLink) -----
        let leaderboardApp = launchSeededAt("noum://profile")
        Thread.sleep(forTimeInterval: 1.2)
        let leaderboardLink = leaderboardApp.descendants(matching: .any)
            .matching(identifier: "profile.friendLeaderboard")
            .element(boundBy: 0)
        if leaderboardLink.waitForExistence(timeout: 4) {
            leaderboardLink.tap()
            Thread.sleep(forTimeInterval: 1.5)
            attach(leaderboardApp, name: "25c-friend-leaderboard")
        }
        leaderboardApp.terminate()

        // ============================================================
        // SECTION D — Conditional surfaces (forced via launch args)
        // ============================================================

        // ----- GOAL REFRESH INLINE CARD -----
        let goalRefreshApp = launchSeededWith(extraArgs: ["FORCE_GOAL_REFRESH"])
        Thread.sleep(forTimeInterval: 2.5)
        attach(goalRefreshApp, name: "26-goal-refresh-inline")
        goalRefreshApp.terminate()

        // ----- NOTIFICATION PRE-PROMPT SHEET -----
        let notifPromptApp = launchSeededWith(extraArgs: ["FORCE_NOTIFICATION_PROMPT"])
        Thread.sleep(forTimeInterval: 2.5)
        attach(notifPromptApp, name: "27-notification-pre-prompt")
        notifPromptApp.terminate()

        captureWeeklyCheckInSheet(name: "28-weekly-check-in-sheet")
    }

    @MainActor
    func testCapturePathJourneyOnly() throws {
        let pathApp = launchSeeded()
        XCTAssertTrue(pathApp.otherElements["home.screen"].waitForExistence(timeout: 10))
        let pathCard = pathApp.descendants(matching: .any)["home.path"].firstMatch
        XCTAssertTrue(pathCard.waitForExistence(timeout: 8))
        pathCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let journeyScreen = pathApp.descendants(matching: .any)["journey.screen"].firstMatch
        XCTAssertTrue(journeyScreen.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5)
        attach(pathApp, name: "path-marker-top")
        pathApp.swipeUp(velocity: .slow)
        Thread.sleep(forTimeInterval: 0.5)
        attach(pathApp, name: "path-marker-bottom")
        pathApp.terminate()
    }

    @MainActor
    func testCaptureProfileBaselineMapOnly() throws {
        let profileApp = launchSeededAt("noum://profile")
        XCTAssertTrue(profileApp.descendants(matching: .any)["profile.screen"].waitForExistence(timeout: 10))

        let baselineRow = profileApp.descendants(matching: .any)["profile.evidence.baselineMap.row"].firstMatch
        if !baselineRow.waitForExistence(timeout: 3) {
            profileApp.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertTrue(baselineRow.waitForExistence(timeout: 5))
        guard baselineRow.exists else {
            profileApp.terminate()
            return
        }

        baselineRow.tap()
        let baselineMap = profileApp.descendants(matching: .any)["profile.evidence.baselineMap"].firstMatch
        // The expanded readout renders below the compact evidence hub rows.
        // Move past the hub first so the attachment proves the card body, not
        // merely the expanded launcher row.
        profileApp.swipeUp(velocity: .slow)
        Thread.sleep(forTimeInterval: 0.5)
        scrollUntilCentered(baselineMap, in: profileApp, maxSwipes: 6)
        XCTAssertTrue(baselineMap.exists)

        Thread.sleep(forTimeInterval: 0.8)
        attach(profileApp, name: "profile-baseline-map")
        profileApp.terminate()
    }

    @MainActor
    func testCaptureWeeklyCheckInSheetOnly() throws {
        captureWeeklyCheckInSheet(name: "profile-weekly-check-in-sheet")
    }

    @MainActor
    func testCaptureSuddenDeathResults() throws {
        captureSuddenDeathResult(
            launchArgument: "UI_TESTING_SUDDEN_DEATH_RESULT_FILLER",
            topName: "28-sudden-death-result-filler",
            lowerName: "29-sudden-death-result-filler-lower",
            reviewName: "30-sudden-death-coach-read"
        )
        captureSuddenDeathResult(
            launchArgument: "UI_TESTING_SUDDEN_DEATH_RESULT_LONG",
            topName: "31-sudden-death-result-long",
            lowerName: "32-sudden-death-result-long-lower"
        )
    }

    @MainActor
    func testCaptureCelebrationOverlays() throws {
        captureOverlayHarness(kind: "progression", name: "33-post-session-progression")
        captureOverlayHarness(kind: "personalBest", name: "34-personal-best-celebration")
        captureOverlayHarness(kind: "levelUp", name: "35-level-up-celebration")
        captureOverlayHarness(kind: "achievementUnlock", name: "36-achievement-unlock-celebration")
    }

    /// Focused capture for the Impromptu setup surface. The full tour can fail
    /// on unrelated screens, so this keeps the primary pressure-drill entry
    /// independently verifiable.
    @MainActor
    func testCaptureTimedSetupOnly() throws {
        let app = launchSeededAt("noum://train")

        XCTAssertTrue(openModeSetup("practiceMode.timed", in: app))
        guard app.descendants(matching: .any)["timedPractice.screen"].waitForExistence(timeout: 8) else {
            app.terminate()
            return
        }

        Thread.sleep(forTimeInterval: 1.2)
        attach(app, name: "14-timed-setup")

        let settingsToggle = app.buttons["timedPractice.settings.toggle"]
        XCTAssertTrue(settingsToggle.waitForExistence(timeout: 3))
        if settingsToggle.exists {
            settingsToggle.tap()
            XCTAssertTrue(app.descendants(matching: .any)["timedPractice.settings.liveTranscript.locked"].waitForExistence(timeout: 5))
            Thread.sleep(forTimeInterval: 0.8)
            attach(app, name: "14b-timed-settings")
            app.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.6)
            attach(app, name: "14c-timed-settings-tools")

            let lockedTranscript = app.buttons["timedPractice.settings.liveTranscript.locked"]
            XCTAssertTrue(lockedTranscript.waitForExistence(timeout: 3))
            if lockedTranscript.exists {
                lockedTranscript.tap()
                let paywallRoot = app.descendants(matching: .any)["paywall.root"]
                let paywallTitle = app.staticTexts["Upgrade to Pro"]
                XCTAssertTrue(
                    paywallRoot.waitForExistence(timeout: 5)
                    || paywallTitle.waitForExistence(timeout: 2)
                )
            }
        }

        app.terminate()
    }

    // MARK: - Helpers

    @MainActor
    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_SEED_FORCE"]
        app.launch()
        return app
    }

    /// Cold-launch with seed + a `-DeepLink` arg so the app routes straight
    /// to the target screen without going through gesture nav.
    @MainActor
    private func launchSeededAt(_ deepLink: String, extraArgs: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_SEED_FORCE"] + extraArgs + ["-DeepLink", deepLink]
        app.launch()
        // Home screen is the deep-link consumption point; wait for it then
        // give the routing one beat to flip the navigation path.
        _ = app.otherElements["home.screen"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1.0)
        return app
    }

    /// Cold-launch with seed + extra launch args (e.g. `FORCE_GOAL_REFRESH`)
    /// for capturing conditional sheets that don't fire on a normal launch.
    @MainActor
    private func launchSeededWith(extraArgs: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_SEED_FORCE"] + extraArgs
        app.launch()
        _ = app.otherElements["home.screen"].waitForExistence(timeout: 10)
        return app
    }

    /// From the mode picker screen, tap a mode row + Start CTA, capture the
    /// setup view it lands on. Idempotent — caller must end on the picker.
    @MainActor
    private func captureModeSetup(_ app: XCUIApplication, modeID: String, name: String) {
        guard openModeSetup(modeID, in: app) else { return }
        Thread.sleep(forTimeInterval: 1.5)
        attach(app, name: name)
        // Back to picker for the next mode capture
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
            Thread.sleep(forTimeInterval: 0.6)
        }
    }

    @MainActor
    private func captureSuddenDeathResult(
        launchArgument: String,
        topName: String,
        lowerName: String,
        reviewName: String? = nil
    ) {
        let app = launchSeededAt("noum://train", extraArgs: [launchArgument])
        let modeRow = revealPracticeMode("practiceMode.suddenDeath", in: app)
        XCTAssertTrue(modeRow.waitForExistence(timeout: 5))
        guard modeRow.exists else {
            app.terminate()
            return
        }
        modeRow.tap()

        let startCTA = app.buttons["practiceModes.start"]
        XCTAssertTrue(startCTA.waitForExistence(timeout: 5))
        guard startCTA.exists else {
            app.terminate()
            return
        }
        startCTA.tap()

        let resultScreen = app.descendants(matching: .any)["suddenDeath.result.screen"]
        XCTAssertTrue(resultScreen.waitForExistence(timeout: 10))
        guard resultScreen.exists else {
            app.terminate()
            return
        }
        Thread.sleep(forTimeInterval: 1.2)
        attach(app, name: topName)
        app.swipeUp(velocity: .slow)
        Thread.sleep(forTimeInterval: 0.6)
        attach(app, name: lowerName)
        if let reviewName {
            let coachRead = app.buttons["Coach Read"]
            XCTAssertTrue(coachRead.waitForExistence(timeout: 3))
            if coachRead.exists {
                coachRead.tap()
                let reviewCard = waitForSuddenDeathReviewCard(in: app)
                XCTAssertTrue(reviewCard.exists)
                if reviewCard.exists {
                    Thread.sleep(forTimeInterval: 0.4)
                    attach(app, name: reviewName)
                }
            }
        }
        app.terminate()
    }

    @MainActor
    private func openModeSetup(_ modeID: String, in app: XCUIApplication) -> Bool {
        // The recommended-hero "Begin" now auto-begins (one tap), so it can no
        // longer reach the SETUP page. The recommended mode has no row in "other
        // ways", so its setup is reached via the hero's "Adjust this rep" CTA,
        // which navigates to setup without arming quick-start.
        if modeID == "practiceMode.timed" {
            let recommendedBegin = app.buttons["practiceModes.recommendedHero.begin"]
            let adjust = app.buttons["practiceModes.recommendedHero.adjust"]
            if recommendedBegin.waitForExistence(timeout: 2),
               recommendedBegin.label.contains("Timed"),
               adjust.waitForExistence(timeout: 2) {
                adjust.tap()
                return true
            }
        }

        let modeRow = revealPracticeMode(modeID, in: app)
        guard modeRow.waitForExistence(timeout: 3) else { return false }
        modeRow.tap()
        Thread.sleep(forTimeInterval: 0.4)

        let startCTA = app.buttons["practiceModes.start"]
        guard startCTA.waitForExistence(timeout: 3) else { return false }
        startCTA.tap()
        return true
    }

    @MainActor
    private func revealPracticeMode(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let picker = app.descendants(matching: .any)["practiceModes.screen"]
        _ = picker.waitForExistence(timeout: 8)

        let modeRow = app.buttons[identifier]
        if modeRow.waitForExistence(timeout: 2) {
            scrollUntilVisible(modeRow, in: app, maxSwipes: 2)
            return modeRow
        }

        let otherWays = app.buttons["practiceModes.otherWays"]
        if !otherWays.waitForExistence(timeout: 2) {
            scrollUntilVisible(otherWays, in: app, maxSwipes: 3)
        }
        if otherWays.waitForExistence(timeout: 2) {
            scrollUntilVisible(otherWays, in: app, maxSwipes: 2)
            otherWays.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        if modeRow.waitForExistence(timeout: 2) {
            scrollUntilVisible(modeRow, in: app, maxSwipes: 4)
        }
        return modeRow
    }

    @MainActor
    private func captureWeeklyCheckInSheet(name: String) {
        let profileApp = launchSeededAt("noum://profile", extraArgs: ["FORCE_WEEKLY_CHECKIN"])
        XCTAssertTrue(profileApp.descendants(matching: .any)["profile.screen"].waitForExistence(timeout: 10))

        let evidenceToggle = profileApp.descendants(matching: .any)["profile.evidenceHub.toggle"].firstMatch
        if !evidenceToggle.waitForExistence(timeout: 3) {
            profileApp.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertTrue(evidenceToggle.waitForExistence(timeout: 5))
        guard evidenceToggle.exists else {
            attach(profileApp, name: "\(name)-missing-toggle")
            profileApp.terminate()
            return
        }

        evidenceToggle.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let checkInCard = profileApp.descendants(matching: .any)["profile.weeklyCheckIn.start"].firstMatch
        scrollUntilVisible(checkInCard, in: profileApp, maxSwipes: 6)
        XCTAssertTrue(checkInCard.waitForExistence(timeout: 5))
        guard checkInCard.exists else {
            attach(profileApp, name: "\(name)-missing-card")
            profileApp.terminate()
            return
        }

        checkInCard.tap()
        let sheet = profileApp.descendants(matching: .any)["weeklyCheckIn.sheet"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        attach(profileApp, name: name)
        profileApp.terminate()
    }

    @MainActor
    private func waitForSuddenDeathReviewCard(in app: XCUIApplication) -> XCUIElement {
        let reviewCard = app.descendants(matching: .any)["suddenDeath.review.card"]
        let deadline = Date().addingTimeInterval(24)

        while Date() < deadline {
            let preSummary = app.descendants(matching: .any)["preSummary.celebration"]
            let continueButton = app.buttons["Continue"]
            let viewResultsButton = app.buttons["View Results"]
            if preSummary.exists {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.5)
                continue
            } else if continueButton.exists {
                continueButton.tap()
                Thread.sleep(forTimeInterval: 0.5)
                continue
            } else if viewResultsButton.exists {
                viewResultsButton.tap()
                Thread.sleep(forTimeInterval: 0.5)
                continue
            }

            if reviewCard.exists { return reviewCard }

            Thread.sleep(forTimeInterval: 0.5)
        }

        return reviewCard
    }

    @MainActor
    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int) {
        let visibleFrame = app.frame.insetBy(dx: 0, dy: 96)

        for _ in 0..<maxSwipes {
            if element.exists, visibleFrame.intersects(element.frame) {
                return
            }
            app.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.45)
        }
    }

    @MainActor
    private func scrollUntilCentered(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int) {
        let visibleFrame = app.frame.insetBy(dx: 0, dy: 120)

        for _ in 0..<maxSwipes {
            if element.exists, visibleFrame.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) {
                return
            }
            app.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.45)
        }
    }

    @MainActor
    private func captureOverlayHarness(kind: String, name: String) {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_OVERLAY", kind]
        app.launch()
        let harness = app.descendants(matching: .any)["overlayHarness.\(kind)"]
        XCTAssertTrue(harness.waitForExistence(timeout: 5))
        guard harness.exists else {
            app.terminate()
            return
        }
        Thread.sleep(forTimeInterval: 1.4)
        attach(app, name: name)
        app.terminate()
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // ============================================================
    // DEEP AUDIT — multi-state capture for lead UX / QA / market review
    // ============================================================

    /// Captures every primary surface across FOUR user states (cold/empty,
    /// beginner, improving-intermediate, plateaued-advanced) AND a full
    /// accessibility-tree dump per screen. This is the corpus the overhaul
    /// review fleets analyse: the SAME surface across the density gradient
    /// from a brand-new user to a power user is where "too much text / no
    /// value felt" is actually visible.
    @MainActor
    func testCaptureDeepAudit() throws {
        captureState(profile: nil,                     prefix: "A-cold")
        captureState(profile: "beginner",              prefix: "B-beginner")
        captureState(profile: "improvingIntermediate", prefix: "C-improving")
        captureState(profile: "plateauedAdvanced",     prefix: "D-plateaued")
    }

    /// True cold-start only. The no-seed launch reuses whatever the store
    /// already holds, so a genuine first-run capture requires the app's
    /// data to be cleared first (`simctl uninstall` before invoking this).
    @MainActor
    func testCaptureColdStart() throws {
        captureState(profile: nil, prefix: "A-cold")
    }

    /// Renders the post-rep Summary via the DEBUG `noum://summary` force-hook
    /// (seeded session) and scrolls it, so the redesigned one-screen verdict
    /// — incl. the WIN card's transcript-verified proof row — can be verified
    /// without completing a live audio rep.
    @MainActor
    func testCaptureSummary() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_SEED_FORCE", "-DeepLink", "noum://summary"]
        app.launch()
        _ = app.otherElements["home.screen"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 2.5) // deep-link routes Home -> Summary
        // The force-hook re-finalizes the seeded session, which can fire a
        // celebration/achievement overlay over the summary body. Dismiss the
        // chain (Continue) so we capture the actual verdict, not the overlay.
        // The force-hook re-finalizes the seeded session, which MAY fire the
        // progression/celebration chain over the verdict (only on a real
        // unlock since the PostRepProgressionGate change — silent reps now
        // route straight to the verdict). Tap through overlay labels only.
        // NEVER tap "Done": the redesigned verdict's bottom exit panel has
        // its own Done (summary.exitPanel.done) and blind-tapping it exits
        // the very screen this tour captures. Stop as soon as the verdict
        // read card (summary.postRepVerdict) is on screen.
        let dismissLabels = ["View Summary", "Continue", "Got it"]
        for _ in 0..<5 {
            if app.otherElements["summary.postRepVerdict"].exists { break }
            var tapped = false
            for label in dismissLabels {
                let b = app.buttons[label]
                if b.waitForExistence(timeout: 2) {
                    b.tap(); Thread.sleep(forTimeInterval: 1.2); tapped = true; break
                }
            }
            if !tapped { break }
        }
        deepAttach(app, name: "S-summary-1top")
        app.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.5)
        deepAttach(app, name: "S-summary-2mid")
        app.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.5)
        deepAttach(app, name: "S-summary-3bottom")
        app.terminate()
    }

    /// Walks onboarding stage by stage — every screen a first-time user sees
    /// before they reach any value at all.
    @MainActor
    func testCaptureOnboardingFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_ONBOARDING"]
        app.launch()

        guard app.buttons["coaching.start"].waitForExistence(timeout: 8) else {
            attach(app, name: "O-00-onboarding-not-reached")
            app.terminate()
            return
        }
        deepAttach(app, name: "O-01-welcome")
        app.buttons["coaching.start"].tap()
        Thread.sleep(forTimeInterval: 0.8)
        deepAttach(app, name: "O-02-context")
        tapFirstOption(app); tapContinue(app)
        deepAttach(app, name: "O-03-challenge")
        tapFirstOption(app); tapContinue(app)
        deepAttach(app, name: "O-04-style")
        tapFirstOption(app); tapContinue(app)
        // Final stage runs a ~12s processing animation before the CTA.
        if app.buttons["coaching.startPracticing"].waitForExistence(timeout: 25) {
            deepAttach(app, name: "O-05-summary")
        }
        app.terminate()
    }

    // MARK: - Deep-audit helpers

    private struct AuditSurface {
        let host: String?
        let name: String
        let scrollCaptures: Int
    }

    @MainActor
    private func captureState(profile: String?, prefix: String) {
        let surfaces: [AuditSurface] = [
            AuditSurface(host: nil,                 name: "home",      scrollCaptures: 3),
            AuditSurface(host: "noum://profile",   name: "profile",   scrollCaptures: 3),
            AuditSurface(host: "noum://review",    name: "review",    scrollCaptures: 2),
            AuditSurface(host: "noum://train",     name: "train",     scrollCaptures: 1),
            AuditSurface(host: "noum://league",    name: "league",    scrollCaptures: 3),
            AuditSurface(host: "noum://path",      name: "path",      scrollCaptures: 3),
            AuditSurface(host: "noum://ask",       name: "ask",       scrollCaptures: 1),
            AuditSurface(host: "noum://bigmoment", name: "bigmoment", scrollCaptures: 3),
            AuditSurface(host: "noum://settings",  name: "settings",  scrollCaptures: 3),
        ]
        for s in surfaces {
            let app = launchState(profile: profile, deepLink: s.host)
            if s.scrollCaptures > 1 {
                scrollCapture(app, base: "\(prefix)-\(s.name)", captures: s.scrollCaptures)
            } else {
                deepAttach(app, name: "\(prefix)-\(s.name)")
            }
            app.terminate()
        }
    }

    /// Cold-launch a chosen seed persona (or no seed → true empty first-run)
    /// routed straight to a deep-link target.
    @MainActor
    private func launchState(profile: String?, deepLink: String?) -> XCUIApplication {
        let app = XCUIApplication()
        var launchArgs = ["UI_TESTING"]
        if let profile {
            launchArgs += ["UI_TESTING_SEED_FORCE", "UI_TESTING_SEED_PROFILE", profile]
        }
        if let deepLink {
            launchArgs += ["-DeepLink", deepLink]
        }
        app.launchArguments += launchArgs
        app.launch()
        _ = app.otherElements["home.screen"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1.0)
        return app
    }

    @MainActor
    private func scrollCapture(_ app: XCUIApplication, base: String, captures: Int) {
        deepAttach(app, name: "\(base)-1top")
        guard captures > 1 else { return }
        screenSwipeUp(in: app)
        Thread.sleep(forTimeInterval: 0.5)
        deepAttach(app, name: "\(base)-2mid", includeAccessibility: false)
        guard captures > 2 else { return }
        screenSwipeUp(in: app)
        Thread.sleep(forTimeInterval: 0.5)
        deepAttach(app, name: "\(base)-3bottom", includeAccessibility: false)
    }

    @MainActor
    private func screenSwipeUp(in app: XCUIApplication) {
        if app.state != .runningForeground {
            app.activate()
            Thread.sleep(forTimeInterval: 0.3)
        }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32))
        start.press(forDuration: 0.01, thenDragTo: end)
    }

    @MainActor
    private func tapFirstOption(_ app: XCUIApplication) {
        let option = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'coaching.option.'"))
            .element(boundBy: 0)
        if option.waitForExistence(timeout: 5) {
            option.tap()
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    @MainActor
    private func tapContinue(_ app: XCUIApplication) {
        let cont = app.buttons["coaching.continue"]
        if cont.waitForExistence(timeout: 5) {
            cont.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
    }

    /// DIAGNOSTIC (owner repro 2026-06-10): drive TWO real chat turns
    /// through the live reply pipeline (real provider key, real network)
    /// and capture what renders. Answers definitively whether HEAD still
    /// degrades every turn to the deterministic fallback ("says the same
    /// thing over and over") or live replies survive the quality gate.
    /// Screenshots are the evidence; no assertion on reply content (live
    /// model output is non-deterministic by design).
    @MainActor
    func testDiagnosticLiveChatRoundTrip() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING", "UI_TESTING_SEED_FORCE",
            "UI_TESTING_SEED_PROFILE", "improvingIntermediate"
        ]
        app.launch()
        _ = app.otherElements["home.screen"].waitForExistence(timeout: 10)

        let entry = app.descendants(matching: .any)["home.askNoum.row"].firstMatch
        guard entry.waitForExistence(timeout: 8) else {
            deepAttach(app, name: "DIAG-00-no-askNoum-entry")
            app.terminate(); return
        }
        entry.tap()
        Thread.sleep(forTimeInterval: 1.5)

        // The coach surface defaults to the immersive live call — switch
        // to the TEXT chat via the call's Type control before composing.
        let typeButton = app.buttons["Type"].firstMatch
        if typeButton.waitForExistence(timeout: 5) {
            typeButton.tap()
            Thread.sleep(forTimeInterval: 1.2)
        }

        let field = app.textViews.firstMatch.exists
            ? app.textViews.firstMatch : app.textFields.firstMatch
        guard field.waitForExistence(timeout: 8) else {
            deepAttach(app, name: "DIAG-01-no-composer")
            app.terminate(); return
        }

        field.tap()
        field.typeText("What should I focus on in my next rep?")
        app.buttons["askNoum.inputControl"].tap()
        Thread.sleep(forTimeInterval: 20) // live model round-trip
        deepAttach(app, name: "DIAG-02-first-reply")

        field.tap()
        field.typeText("And how do I fix my pacing?")
        app.buttons["askNoum.inputControl"].tap()
        Thread.sleep(forTimeInterval: 20)
        deepAttach(app, name: "DIAG-03-second-reply")
        app.terminate()
    }

    /// Screenshot + optional full accessibility-tree dump (the structured
    /// truth the QA / a11y fleet reads: labels, identifiers, hittable elements).
    /// Scrolled positions keep visual evidence but skip redundant tree dumps;
    /// XCUITest can become unstable serializing large offscreen review trees.
    @MainActor
    private func deepAttach(_ app: XCUIApplication, name: String, includeAccessibility: Bool = true) {
        let shot = XCUIScreen.main.screenshot()
        let img = XCTAttachment(screenshot: shot)
        img.name = name
        img.lifetime = .keepAlways
        add(img)
        guard includeAccessibility else { return }
        let ax = XCTAttachment(string: app.debugDescription)
        ax.name = "\(name)__ax"
        ax.lifetime = .keepAlways
        add(ax)
    }
}
