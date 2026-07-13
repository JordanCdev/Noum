import XCTest

final class PrepSessionAvailabilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLockedPrepShapesRenderAndRouteToTimedFallback() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_SEED_PROFILE", "beginner",
            "UI_TESTING_CLOUD_CONSENT",
            "UI_TESTING_NO_CLOUD_CONSENT",
            "UI_TESTING_MICROPHONE_GRANTED",
            "-DeepLink", "noum://prep",
        ]
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["prepSession.screen"]
                .waitForExistence(timeout: 15),
            "The seeded upcoming moment should open the real Prep surface."
        )
        XCTAssertTrue(app.staticTexts["Build-up rep: Timed Practice"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Complete one rated rep before Pressure Drill. Start with Timed Practice."]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Question rehearsal: Timed Practice"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Conversation Practice isn't available here yet. Start with Timed Practice."]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts["Pressure Round unavailable · Timed fallback offered"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts["Audience Simulation unavailable · Timed fallback offered"]
                .waitForExistence(timeout: 5)
        )

        let readinessLine = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "remain untested")
        ).firstMatch
        scrollUntilHittable(readinessLine, in: app, attempts: 6)
        XCTAssertTrue(
            readinessLine.waitForExistence(timeout: 5),
            "Timed fallbacks must not count as Pressure or audience rehearsal."
        )

        let planAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        planAttachment.name = "prep-locked-shapes-timed-fallbacks"
        planAttachment.lifetime = .keepAlways
        add(planAttachment)

        let pressureFallback = app.buttons["prepSession.step.2.begin"]
        scrollUntilHittable(pressureFallback, in: app, attempts: 6, direction: .down)
        XCTAssertTrue(pressureFallback.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(
            pressureFallback.frame.height,
            44,
            "Prep step actions must meet the minimum touch-target contract."
        )
        pressureFallback.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["timedPractice.screen"]
                .waitForExistence(timeout: 12),
            "The visible Pressure fallback should route to Timed Practice."
        )
        XCTAssertFalse(app.descendants(matching: .any)["suddenDeath.screen"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["imPractice.screen"].exists)

        let begin = app.buttons["timedPractice.begin"]
        scrollUntilHittable(begin, in: app, attempts: 3)
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        begin.tap()

        let routedPrompt = app.staticTexts["timedPractice.prompt"]
        XCTAssertTrue(routedPrompt.waitForExistence(timeout: 8))
        XCTAssertEqual(
            routedPrompt.label,
            "Give a clear 60-second opening for your upcoming presentation.",
            "The fallback must preserve the visible rehearsal promise through the route-bound prompt."
        )

        let destinationAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        destinationAttachment.name = "prep-pressure-fallback-exact-timed-prompt"
        destinationAttachment.lifetime = .keepAlways
        add(destinationAttachment)
    }

    private enum ScrollDirection {
        case up
        case down
    }

    @MainActor
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int,
        direction: ScrollDirection = .up
    ) {
        guard !element.isHittable else { return }
        let scroll = app.scrollViews.firstMatch
        guard scroll.exists else { return }
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            switch direction {
            case .up:
                scroll.swipeUp(velocity: .slow)
            case .down:
                scroll.swipeDown(velocity: .slow)
            }
        }
    }
}
