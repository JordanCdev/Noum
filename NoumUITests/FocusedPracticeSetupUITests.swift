import XCTest

/// Pins the accessibility contract shared by the immersive practice setup
/// surfaces. These assertions deliberately use identifiers rather than copy so
/// visual/copy refinements do not strand navigation or screenshot automation.
final class FocusedPracticeSetupUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFocusedSetupIdentifiersSelectionTraitsAndTabBarHiding() throws {
        // Positive control: the Train root exposes the native TabView as an
        // XCUI tab bar. This makes the destination-level absence checks below
        // meaningful rather than passing because XCUI never saw a tab bar.
        let trainApp = launchSeededAt("noum://train")
        XCTAssertTrue(
            trainApp.descendants(matching: .any)["practiceModes.screen"].waitForExistence(timeout: 10)
        )
        let rootTabBar = trainApp.tabBars.firstMatch
        let visibleTabBar = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND isHittable == true"),
            object: rootTabBar
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [visibleTabBar], timeout: 5),
            .completed,
            "Train root should expose an interactive native tab bar to XCUI"
        )
        trainApp.terminate()

        assertFocusedSetup(
            deepLink: "noum://practice/cut-the-crutch",
            screenID: "cutTheCrutch.screen",
            adjustID: "cutTheCrutch.adjust",
            startID: "cutTheCrutch.start"
        )
        assertFocusedSetup(
            deepLink: "noum://practice/pace",
            screenID: "paceTraining.screen",
            adjustID: "paceTraining.adjust",
            startID: "paceTraining.start"
        )
        assertFocusedSetup(
            deepLink: "noum://roleplay",
            screenID: "roleplay.setup.screen",
            adjustID: "roleplay.adjust",
            startID: "roleplay.begin"
        )
        assertConversationSelectionTraits()
        assertFocusedDestination(
            deepLink: "noum://lesson/pause_beats_filler",
            screenID: "lesson.screen"
        )
    }

    @MainActor
    private func assertFocusedSetup(
        deepLink: String,
        screenID: String,
        adjustID: String,
        startID: String
    ) {
        let app = launchSeededAt(deepLink)
        defer { app.terminate() }

        let screen = app.descendants(matching: .any)[screenID]
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "Missing setup screen: \(screenID)")
        XCTAssertTrue(app.buttons[adjustID].waitForExistence(timeout: 3), "Missing Adjust control: \(adjustID)")
        XCTAssertTrue(app.buttons[startID].waitForExistence(timeout: 3), "Missing Start control: \(startID)")
        assertNativeTabBarHidden(in: app, destinationID: screenID)
    }

    @MainActor
    private func assertConversationSelectionTraits() {
        // A non-routable test URL enables the existing setup-only availability
        // gate without embedding a provider credential or making a request.
        let app = launchSeededAt(
            "noum://practice/conversation",
            extraArguments: ["UI_TESTING_CLOUD_CONSENT"],
            extraEnvironment: ["BACKEND_BASE_URL": "https://noum-ui-test.invalid"]
        )
        defer { app.terminate() }

        let screen = app.descendants(matching: .any)["imPractice.screen"]
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "Conversation setup did not open")
        assertNativeTabBarHidden(in: app, destinationID: "imPractice.screen")

        let scenario = app.buttons["imPractice.scenario.socialCatchUp"]
        XCTAssertTrue(scenario.waitForExistence(timeout: 5), "Scenario identifier is missing")
        scenario.tap()

        let tone = app.buttons["imPractice.tone.warm"]
        XCTAssertTrue(tone.waitForExistence(timeout: 5), "Tone identifier is missing")
        tone.tap()
        assertSelected(tone, identifier: "imPractice.tone.warm")

        // Selecting a scenario advances to the tone step. Return with the
        // bottom-most Back control so the selected scenario card is mounted
        // again and its trait can be inspected.
        let setupBack = app.buttons
            .matching(NSPredicate(format: "label == %@", "Back"))
            .allElementsBoundByIndex
            .filter(\.isHittable)
            .max { $0.frame.midY < $1.frame.midY }
        guard let setupBack else {
            XCTFail("Conversation tone step is missing its setup Back control")
            return
        }
        XCTAssertGreaterThan(
            setupBack.frame.midY,
            app.frame.midY,
            "Expected to use the setup Back control, not the navigation-bar Back control"
        )
        setupBack.tap()

        XCTAssertTrue(scenario.waitForExistence(timeout: 5), "Scenario step did not return")
        assertSelected(scenario, identifier: "imPractice.scenario.socialCatchUp")
    }

    @MainActor
    private func assertFocusedDestination(deepLink: String, screenID: String) {
        let app = launchSeededAt(deepLink)
        defer { app.terminate() }

        let screen = app.descendants(matching: .any)[screenID]
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "Missing focused destination: \(screenID)")
        assertNativeTabBarHidden(in: app, destinationID: screenID)
    }

    @MainActor
    private func assertSelected(_ element: XCUIElement, identifier: String) {
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [selected], timeout: 3),
            .completed,
            "Expected \(identifier) to expose the selected accessibility trait"
        )
    }

    @MainActor
    private func assertNativeTabBarHidden(in app: XCUIApplication, destinationID: String) {
        let tabBar = app.tabBars.firstMatch
        let hiddenTabBar = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false OR isHittable == false"),
            object: tabBar
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [hiddenTabBar], timeout: 5),
            .completed,
            "Native tab bar should not be interactive for focused destination \(destinationID)"
        )
        XCTAssertFalse(
            tabBar.exists && tabBar.isHittable,
            "Native tab bar remained interactive for focused destination \(destinationID)"
        )
    }

    @MainActor
    private func launchSeededAt(
        _ deepLink: String,
        extraArguments: [String] = [],
        extraEnvironment: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE"
        ] + extraArguments + [
            "-DeepLink",
            deepLink
        ]
        app.launchEnvironment.merge(extraEnvironment) { _, newValue in newValue }
        app.launch()
        return app
    }
}
