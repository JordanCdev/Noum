import XCTest

final class PrepSessionAvailabilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The seeded beginner opens the prep surface with qualifying Timed reps
    /// already logged since the moment was set, while Pressure Drill is
    /// rating-gated and Conversation Practice is unavailable without cloud
    /// consent. Under ordered attribution the earliest timed rep credits the
    /// warm-up and each gated step is credited by its offered Timed fallback,
    /// so the plan reads fully covered — honestly marked — instead of
    /// dead-ending on an unavailable shape. Step rows combine their text for
    /// VoiceOver, so assertions match on element labels rather than raw
    /// static texts.
    @MainActor
    func testGatedShapesReadAsHonestFallbackCoverageAndRouteToTimed() throws {
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

        func element(labelContaining fragment: String) -> XCUIElement {
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", fragment))
                .firstMatch
        }

        // The gated steps keep their honest fallback naming.
        XCTAssertTrue(
            element(labelContaining: "Build-up rep: Timed Practice")
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element(labelContaining: "Question rehearsal: Timed Practice")
                .waitForExistence(timeout: 5)
        )

        // Fallback-covered steps read done but never claim the unavailable
        // shape itself was rehearsed.
        XCTAssertTrue(
            element(labelContaining: "the pressure round itself is still untested")
                .waitForExistence(timeout: 5),
            "A step covered via the Timed fallback must stay honest about the untested shape."
        )
        XCTAssertTrue(
            element(labelContaining: "the audience simulation itself is still untested")
                .waitForExistence(timeout: 5),
            "The last step's fallback coverage must be honest too — it has no later row to carry it."
        )

        // Every step is covered, so nothing may still read locked.
        XCTAssertFalse(
            element(labelContaining: "Unlocks after").exists,
            "Fallback coverage must advance the lock sequence — no step may dead-end."
        )

        // The intro's arc — now its own quieter line beneath the proximity
        // sentence — names only what the rendered plan actually offers.
        XCTAssertTrue(
            element(labelContaining: "two focused Timed Practice passes")
                .waitForExistence(timeout: 5),
            "With both shapes gated the intro must not promise pressure or audience rounds."
        )

        // The plan header's covered indicator mirrors the rendered rows —
        // fallback-inclusive, so the fully covered seed reads 3 of 3.
        XCTAssertTrue(
            element(labelContaining: "3 of 3 covered")
                .waitForExistence(timeout: 5),
            "The REHEARSAL PLAN header should carry the fallback-inclusive covered count."
        )

        let planAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        planAttachment.name = "prep-fallback-covered-honest-plan"
        planAttachment.lifetime = .keepAlways
        add(planAttachment)

        // Covered steps stay re-runnable: every row keeps its own action.
        XCTAssertTrue(app.buttons["prepSession.step.1.begin"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["prepSession.step.3.begin"].exists)

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
