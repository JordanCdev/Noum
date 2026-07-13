import XCTest

final class HistoricalReplayUITests: XCTestCase {
    @MainActor
    func testHistoricalReviewOffersOneReplayActionAndLaunchesRecordedMode() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_CLEAR_ASK_NOUM",
            "-DeepLink", "noum://review"
        ]
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["history.screen"].waitForExistence(timeout: 12),
            "The seeded Review surface did not open."
        )

        let sessionListEntry = app.descendants(matching: .any)["history.sessionListEntry"]
        XCTAssertTrue(
            sessionListEntry.waitForExistence(timeout: 6),
            "Review did not expose its historical session list."
        )
        sessionListEntry.tap()

        let firstSession = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'history.row.'"))
            .firstMatch
        XCTAssertTrue(
            firstSession.waitForExistence(timeout: 6),
            "The seeded history did not expose a session row."
        )
        firstSession.tap()

        let replayActions = app.buttons.matching(
            NSPredicate(format: "identifier == 'history.detail.practiceAgain'")
        )
        let replayAction = replayActions.firstMatch
        XCTAssertTrue(
            replayAction.waitForExistence(timeout: 6),
            "Historical detail did not expose its replay action."
        )
        scrollUntilHittable(replayAction, in: app)

        XCTAssertEqual(
            replayActions.count,
            1,
            "Historical detail must render exactly one replay-oriented launch action."
        )
        XCTAssertTrue(
            replayAction.label.hasPrefix("Repeat this rep."),
            "The historical launch must be framed as replay, not a new prescription."
        )
        XCTAssertGreaterThanOrEqual(
            replayAction.frame.height,
            48,
            "The replay action must retain its accessible tap target."
        )

        XCTAssertEqual(
            app.buttons.matching(identifier: "goalOutcome.practice").count,
            0,
            "Historical goal movement must remain read-only."
        )
        XCTAssertEqual(
            app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Practice this mode'")
            ).count,
            0,
            "The legacy adaptive-action language must not appear on historical detail."
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Historical Review - Single Replay Action"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertTrue(replayAction.isHittable)
        replayAction.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["timedPractice.screen"].waitForExistence(timeout: 12),
            "The seeded Timed record did not launch the existing Timed Practice destination."
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
