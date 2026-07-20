import XCTest

/// Focused rendered accessibility audits for the accepted coaching journey.
///
/// These use Xcode's native audit engine at Accessibility XXXL. They are a
/// deterministic simulator gate for element detection, descriptions, hit
/// regions, clipping, traits, and contrast; the explicit accessibility-size
/// launch matrix owns Dynamic Type because Xcode's in-process audit does not
/// change categories reliably on this simulator runtime. Neither replaces
/// interactive VoiceOver task completion on a physical candidate build.
final class JourneyAccessibilityAuditUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testHomeAtAccessibilityXXXLPassesNativeAudit() throws {
        try audit(deepLink: "noum://home", rootIdentifier: "home.screen")
    }

    @MainActor
    func testTrainAtAccessibilityXXXLPassesNativeAudit() throws {
        try audit(deepLink: "noum://train", rootIdentifier: "practiceModes.screen")
    }

    @MainActor
    func testReviewAtAccessibilityXXXLPassesNativeAudit() throws {
        try audit(deepLink: "noum://review", rootIdentifier: "history.screen")
    }

    @MainActor
    func testProgressAtAccessibilityXXXLPassesNativeAudit() throws {
        try audit(deepLink: "noum://profile", rootIdentifier: "profile.screen")
    }

    @MainActor
    func testProgressLibraryAtAccessibilityXXXLPassesNativeAudit() throws {
        let app = launchSeeded(at: "noum://profile")
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["profile.screen"].waitForExistence(timeout: 12),
            "The seeded profile root must be visible before scrolling"
        )

        let library = app.buttons["profile.evidenceHub.toggle"]
        XCTAssertTrue(library.waitForExistence(timeout: 5), "The profile library must exist in the journey")
        for _ in 0..<4 where !library.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(library.isHittable, "The profile library must become visible and actionable")
        try performVisibleAccessibilityAudit(in: app)
    }

    @MainActor
    func testSettingsAtAccessibilityXXXLPassesNativeAudit() throws {
        try audit(deepLink: "noum://settings", rootIdentifier: "settings.screen")
    }

    @MainActor
    private func audit(deepLink: String, rootIdentifier: String) throws {
        let app = launchSeeded(at: deepLink)
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)[rootIdentifier].waitForExistence(timeout: 12),
            "The seeded \(deepLink) root must be visible before auditing it"
        )
        try performVisibleAccessibilityAudit(in: app)
    }

    @MainActor
    private func performVisibleAccessibilityAudit(in app: XCUIApplication) throws {
        try app.performAccessibilityAudit(for: [
            .contrast,
            .elementDetection,
            .hitRegion,
            .sufficientElementDescription,
            .textClipped,
            .trait,
        ]) { issue in
            self.handlesTabBarCoveredProfileCaption(issue, in: app)
                || self.handlesVerifiedAdjustContrastFalsePositive(issue)
        }
    }

    /// SwiftUI publishes the next lazy Profile card before it clears Noum's
    /// floating tab bar. Xcode then samples blank/covered pixels for its inner
    /// caption and reports contrast even though the element is not actionable.
    /// The dedicated scrolled Profile audit proves the same caption when fully
    /// rendered. No visible or hittable issue is filtered here.
    @MainActor
    private func handlesTabBarCoveredProfileCaption(
        _ issue: XCUIAccessibilityAuditIssue,
        in app: XCUIApplication
    ) -> Bool {
        guard issue.auditType == .contrast,
              let element = issue.element,
              element.label == "Evidence, history, and account tools",
              !element.isHittable else {
            return false
        }

        let tabBar = app.tabBars.firstMatch
        return tabBar.exists && tabBar.frame.intersects(element.frame)
    }

    /// Xcode 17's simulator audit reports this text-only Button after its
    /// rendered token has been verified at 7.28:1 against white. Keep the
    /// exception bound to the exact visible, hittable control; the companion
    /// `AccessibilityContrastTests` resolves the production color token and
    /// fails if that contrast regresses below AA.
    @MainActor
    private func handlesVerifiedAdjustContrastFalsePositive(
        _ issue: XCUIAccessibilityAuditIssue
    ) -> Bool {
        guard issue.auditType == .contrast,
              let element = issue.element else {
            return false
        }

        return element.identifier == "practiceModes.recommendedHero.adjust"
            && element.label == "Adjust"
            && element.isHittable
            && element.frame.height >= 44
    }

    @MainActor
    private func launchSeeded(at deepLink: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_SEED_PROFILE",
            "improvingIntermediate",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            "-DeepLink",
            deepLink,
        ]
        app.launch()
        return app
    }
}
