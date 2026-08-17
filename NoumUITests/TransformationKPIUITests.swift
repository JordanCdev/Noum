import XCTest

final class TransformationKPIUITests: XCTestCase {
    @MainActor
    func testThreeRepQualitativeQuestionIsAccessibleAndOneShot() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_CLEAR_FLOW_EVENTS",
            "-DeepLink", "noum://profile"
        ]
        app.launch()

        let card = app.descendants(matching: .any)["profile.transformationQuestion"]
        if !card.waitForExistence(timeout: 4) {
            // Weekly context has deterministic priority when both prompts are
            // due. The transfer question remains available through the one
            // secondary Library route rather than stacking on Profile.
            let library = app.buttons["profile.evidenceHub.toggle"]
            for _ in 0..<8 where !library.isHittable {
                app.swipeUp(velocity: .slow)
            }
            XCTAssertTrue(library.waitForExistence(timeout: 5))
            library.tap()

            let pending = app.descendants(matching: .any)["profile.library.pendingPrompt"]
            for _ in 0..<8 where !pending.isHittable {
                app.swipeUp(velocity: .slow)
            }
            XCTAssertTrue(pending.waitForExistence(timeout: 5))
            pending.tap()
        }
        XCTAssertTrue(card.waitForExistence(timeout: 8))

        let yes = app.buttons["profile.transformationQuestion.response.yes"]
        let notYet = app.buttons["profile.transformationQuestion.response.notYet"]
        XCTAssertTrue(yes.exists)
        XCTAssertTrue(notYet.exists)
        XCTAssertEqual(yes.label, "Yes, this helped outside the app")
        XCTAssertEqual(notYet.label, "Not yet, this has not helped outside the app")
        XCTAssertGreaterThanOrEqual(yes.frame.height, 44)
        XCTAssertGreaterThanOrEqual(notYet.frame.height, 44)

        notYet.tap()
        XCTAssertFalse(card.waitForExistence(timeout: 2))
    }
}
