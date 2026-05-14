import XCTest

/// Drives the app through the surfaces this advancement-pass touched and saves
/// an XCTAttachment screenshot of each. Run via:
///
///     xcodebuild test \
///       -project Noum.xcodeproj -scheme Noum \
///       -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///       -only-testing:NoumUITests/ScreenshotTour/testCaptureAdvancementSurfaces \
///       -resultBundlePath ~/noum-result.xcresult
///
/// Then extract:
///
///     xcrun xcresulttool export attachments \
///       --path ~/noum-result.xcresult \
///       --output-path ~/noum-screens
final class ScreenshotTour: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true   // keep capturing even if a step misses
    }

    @MainActor
    func testCaptureAdvancementSurfaces() throws {
        // ----- HOME (seeded) -----
        let app = launchSeeded()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5)  // let seed inject + initial render settle
        attach(app, name: "01-home")

        // ----- PROFILE -----
        let profileTab = app.buttons["nav.social"]
        if profileTab.waitForExistence(timeout: 5) {
            profileTab.tap()
            Thread.sleep(forTimeInterval: 1.0)
            attach(app, name: "02-profile-top")

            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
            attach(app, name: "03-profile-mastery")
        }

        app.terminate()

        // ----- MODE PICKER -----
        let pickerApp = launchSeeded()
        XCTAssertTrue(pickerApp.otherElements["home.screen"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.0)

        let trainTab = pickerApp.buttons["nav.practice"]
        XCTAssertTrue(trainTab.waitForExistence(timeout: 5))
        trainTab.tap()
        XCTAssertTrue(pickerApp.otherElements["practiceModes.screen"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.7)
        attach(pickerApp, name: "04-mode-picker")

        // ----- SUDDEN DEATH SETUP (difficulty selector) -----
        let suddenDeathRow = pickerApp.buttons["practiceMode.suddenDeath"]
        if suddenDeathRow.waitForExistence(timeout: 3) {
            suddenDeathRow.tap()
            Thread.sleep(forTimeInterval: 0.4)
            let startCTA = pickerApp.buttons["practiceModes.start"]
            if startCTA.waitForExistence(timeout: 3) {
                startCTA.tap()
                Thread.sleep(forTimeInterval: 1.5)
                attach(pickerApp, name: "05-sudden-death-setup")
            }
        }
    }

    @MainActor
    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING_SEED"]
        app.launch()
        return app
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let shot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
