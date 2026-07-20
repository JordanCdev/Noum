import XCTest

final class CoachTraceSupportUITests: XCTestCase {
    @MainActor
    func testDeveloperTraceExportsRedactedSupportBundle() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_CLEAR_ASK_NOUM",
            "UI_TESTING_COACH_TRACE_SUPPORT",
            "-DeepLink", "noum://settings",
        ]
        app.launch()

        let advanced = app.buttons["settings.advancedToggle"]
        scrollToElement(advanced, in: app)
        XCTAssertTrue(advanced.waitForExistence(timeout: 15))
        if (advanced.value as? String) != "Expanded" {
            advanced.tap()
        }

        let export = app.buttons["settings.debugTraces.copySupportBundle"]
        scrollToElement(export, in: app)
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        XCTAssertTrue(export.isHittable)
        XCTAssertTrue(app.staticTexts["safeFallback"].exists)
        export.tap()
        XCTAssertTrue(
            app.staticTexts["Redacted support bundle copied"].waitForExistence(timeout: 5)
        )

        let copyTrace = app.buttons["settings.debugTraces.copyTraceID"]
        XCTAssertTrue(copyTrace.exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "debug_trace_support_bundle"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func scrollToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 12
    ) {
        for _ in 0..<attempts {
            if element.exists, element.isHittable { return }
            app.swipeUp()
        }
    }
}
