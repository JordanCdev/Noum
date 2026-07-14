import XCTest

final class RecommendationSurfaceRoutingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeRecommendationRoutesAndRecordsCorrelatedAcceptance() throws {
        let app = launchRecommendationSurface(
            at: "noum://home",
            profile: "plateauedAdvanced"
        )

        XCTAssertTrue(
            app.descendants(matching: .any)["home.coachCard"]
                .waitForExistence(timeout: 15)
        )
        XCTAssertEqual(app.staticTexts["home.coachCard.title"].label, "Filler Words.")
        XCTAssertEqual(
            app.staticTexts["home.coachCard.subtitle"].label,
            "Recent reps point to filler words as the clearest next focus."
        )

        let begin = app.buttons["home.coachCard.begin"]
        scrollUntilHittable(begin, in: app, attempts: 6)
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(begin.frame.height, 44)
        XCTAssertEqual(begin.label, "Start Filler Control")
        let expectedDestination = destinationIdentifier(
            forModeLabelIn: begin.label,
            context: "Home recommendation CTA"
        )

        addScreenshot(named: "home-recommendation-rendered")
        begin.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[expectedDestination]
                .waitForExistence(timeout: 12),
            "Home must route the mode named by its visible recommendation CTA."
        )
        addScreenshot(named: "home-recommendation-destination")

        app.terminate()
        try assertPersistedCorrelatedAcceptance(surface: "Home")
    }

    @MainActor
    func testTrainRecommendationRoutesAndRecordsCorrelatedAcceptance() throws {
        let app = launchRecommendationSurface(
            at: "noum://practice",
            profile: "plateauedAdvanced"
        )

        let hero = app.descendants(matching: .any)["practiceModes.recommendedHero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        let recommendationSettled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Filler Control"),
            object: hero
        )
        XCTAssertEqual(XCTWaiter.wait(for: [recommendationSettled], timeout: 8), .completed)
        XCTAssertTrue(app.staticTexts["Filler Control"].waitForExistence(timeout: 5))
        let modeLabel = hero.value as? String ?? ""
        let expectedDestination = destinationIdentifier(
            forModeLabelIn: modeLabel,
            context: "Train recommendation accessibility value"
        )

        let begin = app.buttons["practiceModes.recommendedHero.begin"]
        scrollUntilHittable(begin, in: app, attempts: 5)
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(begin.frame.height, 44)

        addScreenshot(named: "train-recommendation-rendered")
        begin.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[expectedDestination]
                .waitForExistence(timeout: 12),
            "Train must route the mode exposed by its rendered recommendation hero."
        )
        addScreenshot(named: "train-recommendation-destination")

        app.terminate()
        try assertPersistedCorrelatedAcceptance(surface: "Train")
    }

    @MainActor
    func testTrainTimedRecommendationShowsExactDifficultyAndLaunchesTimed() throws {
        let app = launchRecommendationSurface(
            at: "noum://practice",
            profile: "beginner"
        )

        let hero = app.descendants(matching: .any)["practiceModes.recommendedHero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        let recommendationSettled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", "Timed Practice"),
            object: hero
        )
        XCTAssertEqual(XCTWaiter.wait(for: [recommendationSettled], timeout: 8), .completed)

        let difficulty = app.descendants(matching: .any)
            .matching(identifier: "practiceModes.recommendedHero.timedDifficulty")
            .firstMatch
        XCTAssertTrue(difficulty.waitForExistence(timeout: 5))
        XCTAssertEqual(difficulty.label, "Recommended difficulty, Medium")

        let begin = app.buttons["practiceModes.recommendedHero.begin"]
        scrollUntilHittable(begin, in: app, attempts: 5)
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        begin.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["timedPractice.prompt"]
                .waitForExistence(timeout: 12),
            "The recommended Begin action must enter the existing Timed rep flow."
        )
        addScreenshot(named: "train-timed-recommendation-destination")
    }

    @MainActor
    private func launchRecommendationSurface(
        at deepLink: String,
        profile: String
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_SEED_PROFILE", profile,
            "UI_TESTING_CLEAR_FLOW_EVENTS",
            "UI_TESTING_NO_CLOUD_CONSENT",
            "-DeepLink", deepLink,
        ]
        app.launch()
        return app
    }

    @MainActor
    private func assertPersistedCorrelatedAcceptance(surface: String) throws {
        let diagnostics = XCUIApplication()
        diagnostics.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_RECOMMENDATION_FLOW_LOG",
            "-DeepLink", "noum://settings",
        ]
        diagnostics.launch()

        XCTAssertTrue(
            diagnostics.descendants(matching: .any)["settings.screen"]
                .waitForExistence(timeout: 15)
        )
        let advanced = diagnostics.buttons["settings.advancedToggle"]
        scrollUntilHittable(advanced, in: diagnostics, attempts: 14)
        XCTAssertTrue(advanced.waitForExistence(timeout: 5))
        if (advanced.value as? String) != "Expanded" {
            advanced.tap()
        }

        let acceptance = diagnostics.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Prescription"))
            .firstMatch
        scrollUntilHittable(acceptance, in: diagnostics, attempts: 14)
        XCTAssertTrue(acceptance.waitForExistence(timeout: 8))
        XCTAssertTrue(
            acceptance.label.contains("100%"),
            "\(surface) must persist one correlated shown-to-accepted prescription; got \(acceptance.label)."
        )

        let acceptedEvent = diagnostics.staticTexts["prescription.accepted"]
        scrollUntilHittable(acceptedEvent, in: diagnostics, attempts: 5)
        XCTAssertTrue(acceptedEvent.waitForExistence(timeout: 5))
        XCTAssertTrue(diagnostics.staticTexts["prescription.shown"].waitForExistence(timeout: 5))
        addScreenshot(named: "\(surface.lowercased())-recommendation-correlated-acceptance")
        diagnostics.terminate()
    }

    private func destinationIdentifier(
        forModeLabelIn value: String,
        context: String
    ) -> String {
        let mapping = [
            ("Timed Practice", "timedPractice.screen"),
            ("Pressure Drill", "suddenDeath.screen"),
            ("Filler Control", "ahCounter.screen"),
            ("Conversation Practice", "imPractice.screen"),
        ]
        if let match = mapping.first(where: { value.localizedCaseInsensitiveContains($0.0) }) {
            return match.1
        }
        XCTFail("\(context) did not expose a canonical mode label: \(value)")
        return "missing-recommendation-destination"
    }

    @MainActor
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int
    ) {
        guard !element.isHittable else { return }
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            if scroll.exists {
                scroll.swipeUp(velocity: .slow)
            } else {
                app.swipeUp(velocity: .slow)
            }
        }
    }

    @MainActor
    private func addScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
