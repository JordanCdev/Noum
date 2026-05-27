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

        // Session detail — tap the first session row (`history.row.<uuid>`
        // is added to each NavigationLink in SessionHistoryView). We don't
        // know the UUID up front, so match by prefix via `containing`.
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
        // SECTION D — Conditional sheets (forced via launch args)
        // ============================================================

        // ----- GOAL REFRESH SHEET -----
        let goalRefreshApp = launchSeededWith(extraArgs: ["FORCE_GOAL_REFRESH"])
        Thread.sleep(forTimeInterval: 2.5) // sheet animates in after a beat
        attach(goalRefreshApp, name: "26-goal-refresh-sheet")
        goalRefreshApp.terminate()

        // ----- NOTIFICATION PRE-PROMPT SHEET -----
        let notifPromptApp = launchSeededWith(extraArgs: ["FORCE_NOTIFICATION_PROMPT"])
        Thread.sleep(forTimeInterval: 2.5)
        attach(notifPromptApp, name: "27-notification-pre-prompt")
        notifPromptApp.terminate()
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
        let modeRow = app.buttons[modeID]
        guard modeRow.waitForExistence(timeout: 3) else { return }
        modeRow.tap()
        Thread.sleep(forTimeInterval: 0.4)
        let startCTA = app.buttons["practiceModes.start"]
        guard startCTA.waitForExistence(timeout: 3) else { return }
        startCTA.tap()
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
        let modeRow = app.buttons["practiceMode.suddenDeath"]
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
                let reviewCard = app.descendants(matching: .any)["suddenDeath.review.card"]
                XCTAssertTrue(reviewCard.waitForExistence(timeout: 5))
                if reviewCard.exists {
                    Thread.sleep(forTimeInterval: 0.4)
                    attach(app, name: reviewName)
                }
            }
        }
        app.terminate()
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let shot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
