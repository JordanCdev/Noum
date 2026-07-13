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
        app.launch()

        let fastLane = app.descendants(matching: .any)["fastLane.screen"]
        XCTAssertTrue(
            fastLane.waitForExistence(timeout: 15),
            "The permissionless fast lane did not become the first-run root."
        )

        let workContext = app.buttons["fastLane.context.work"]
        let ramblingChallenge = app.buttons["fastLane.challenge.rambling"]
        XCTAssertTrue(workContext.waitForExistence(timeout: 5))
        XCTAssertTrue(ramblingChallenge.waitForExistence(timeout: 5))
        assertMinimumTapTarget(workContext)
        assertMinimumTapTarget(ramblingChallenge)
        workContext.tap()
        ramblingChallenge.tap()

        let begin = app.buttons["fastLane.begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        assertMinimumTapTarget(begin)
        XCTAssertTrue(begin.isEnabled)
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
        XCTAssertTrue(app.staticTexts["What is already working"].exists)
        XCTAssertTrue(app.staticTexts["One next move"].exists)
        XCTAssertTrue(app.staticTexts["Evidence boundary"].exists)

        let evidenceBoundary = result.descendants(matching: .staticText)
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

        let explore = app.buttons["fastLane.enterApp"]
        XCTAssertTrue(explore.waitForExistence(timeout: 5))
        scrollUntilHittable(explore, in: app)
        assertMinimumTapTarget(explore)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Fast Lane - Truthful Structure-Only First Value"
        screenshot.lifetime = .keepAlways
        add(screenshot)

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

        XCTAssertFalse(app.descendants(matching: .any)["timedPractice.screen"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["summary.postRepVerdict"].exists)
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
