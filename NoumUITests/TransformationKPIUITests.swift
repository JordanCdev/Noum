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
        XCTAssertTrue(card.waitForExistence(timeout: 12))

        let yes = app.buttons["Yes"]
        let notYet = app.buttons["Not yet"]
        XCTAssertTrue(yes.exists)
        XCTAssertTrue(notYet.exists)
        XCTAssertGreaterThanOrEqual(yes.frame.height, 44)
        XCTAssertGreaterThanOrEqual(notYet.frame.height, 44)

        notYet.tap()
        XCTAssertFalse(card.waitForExistence(timeout: 2))
    }
}
