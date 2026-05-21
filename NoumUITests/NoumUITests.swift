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

        // The journey card is gated by HomeSignalGate (path-node unlocked OR
        // coaching profile set). DevSeedData.injectProfile(.improvingIntermediate)
        // doesn't populate CoachingProfile, so on a freshly-erased simulator the
        // card never renders and tap-by-id can't find it. Deep-link straight to
        // the journey screen — same test intent (screen reachable from launch)
        // without depending on simulator-leftover state.
        //
        // TODO: M16 — extend DevSeedData.injectProfile(.improvingIntermediate) to
        // also seed CoachingProfileStore so gated-card tests can use the
        // tap-the-card pattern again.
        let pathApp = launchSeededAt("noum://path")
        XCTAssertTrue(pathApp.descendants(matching: .any)["journey.screen"].waitForExistence(timeout: 5))
        pathApp.terminate()
        // The old progressCard (which carried `home.rank`) was removed from
        // the home during the M14 consolidation — rank now lives on the
        // Profile tab. The Profile destination is exercised by tapping the
        // bottom-nav social button instead.

        let historyApp = launchApp()
        XCTAssertTrue(historyApp.buttons["nav.history"].waitForExistence(timeout: 5))
        historyApp.buttons["nav.history"].tap()
        XCTAssertTrue(historyApp.descendants(matching: .any)["history.screen"].waitForExistence(timeout: 5))

        historyApp.terminate()
        let settingsApp = launchApp()
        XCTAssertTrue(settingsApp.buttons["nav.settings"].waitForExistence(timeout: 5))
        settingsApp.buttons["nav.settings"].tap()
        XCTAssertTrue(settingsApp.descendants(matching: .any)["settings.screen"].waitForExistence(timeout: 5))

        settingsApp.terminate()
        let practiceApp = launchApp()
        openPracticeModes(in: practiceApp)
        XCTAssertTrue(practiceApp.descendants(matching: .any)["practiceModes.screen"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPracticeModesOpenAvailableScreens() throws {
        assertPracticeModeLaunches(modeIdentifier: "practiceMode.timed", screenIdentifier: "timedPractice.screen")
        assertPracticeModeLaunches(modeIdentifier: "practiceMode.suddenDeath", screenIdentifier: "suddenDeath.screen")
        assertPracticeModeLaunches(modeIdentifier: "practiceMode.ahCounter", screenIdentifier: "ahCounter.screen")

        let imApp = launchApp()
        openPracticeModes(in: imApp)

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
    func testOnboardingFlowSmoke() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_ONBOARDING"]
        app.launch()

        XCTAssertTrue(app.buttons["coaching.start"].waitForExistence(timeout: 5))
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
        // before the redesign). The summary screen runs a ~12s processing
        // animation before revealing the profile card and its CTA, so the
        // wait window has to clear that animation budget plus a little
        // headroom for simulator latency.
        let finishButton = app.buttons["coaching.startPracticing"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 25))
        XCTAssertTrue(finishButton.isEnabled)
        finishButton.tap()
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
        let app = launchApp()
        openPracticeModes(in: app)

        let modeButton = app.buttons[modeIdentifier]
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
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        // UI_TESTING suppresses the splash / onboarding hero.
        // UI_TESTING_SEED injects the improving-intermediate dev profile so
        // the home renders its populated layout (which is where home.path /
        // home.rank etc. live — the empty-state home swaps in HomeCoachCard's
        // no-signal branch + secondaryDiscoveryCard, with the journey
        // card hidden).
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
    private func launchSeededAt(_ deepLink: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_SEED_FORCE", "-DeepLink", deepLink]
        app.launch()
        // Home screen is the deep-link consumption point; wait for it then
        // give the routing one beat to flip the navigation path.
        _ = app.otherElements["home.screen"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1.0)
        return app
    }

    @MainActor
    private func openPracticeModes(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["nav.practice"].waitForExistence(timeout: 5))
        app.buttons["nav.practice"].tap()
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
