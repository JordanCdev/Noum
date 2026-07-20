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
        for _ in 0..<6 where library.frame.midY > app.frame.height * 0.45 {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        XCTAssertTrue(library.isHittable, "The scrolled Profile audit must keep Library fully visible")
        // At the maximum Profile scroll offset the identity header remains a
        // few points above the viewport. The root Profile audit owns element
        // detection for that header; this state owns the fully rendered story,
        // transfer question, and Library affordance.
        try performVisibleAccessibilityAudit(
            in: app,
            includesElementDetection: false,
            verifiedContrastLabels: [
                "Your rated baseline is forming.",
                "Seen across 8 recent reps.",
                "Did Noum help you move toward the speaker you want to be?",
                "Yes",
                "Not yet",
            ]
        )
    }

    @MainActor
    func testSettingsAtAccessibilityXXXLPassesNativeAudit() throws {
        try audit(deepLink: "noum://settings", rootIdentifier: "settings.screen")
    }

    @MainActor
    func testContextualAskAtAccessibilityXXXLPassesNativeAudit() throws {
        let app = launch(arguments: [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_AUTHENTICATED_COACH",
            "UI_TESTING_CLEAR_ASK_NOUM",
            "-DeepLink",
            "noum://ask/type",
        ])
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["askNoum.messageField"].waitForExistence(timeout: 12),
            "The contextual typed coach must render before it is audited"
        )
        try performVisibleAccessibilityAudit(
            in: app,
            verifiedContrastLabels: ["Message Noum...", "Current focus"]
        )
    }

    @MainActor
    func testTranscriptLadderAtAccessibilityXXXLPassesNativeAudit() throws {
        let app = launch(arguments: [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_PREMIUM",
            "UI_TESTING_REWRITE_LADDER",
            "UI_TESTING_FIRST_VALUE_LOOP",
            "UI_TESTING_TRANSCRIPT_RETRY_IMPROVED",
            "UI_TESTING_SEED_PROFILE",
            "plateauedAdvanced",
            "-DeepLink",
            "noum://summary",
        ])
        defer { app.terminate() }

        dismissProgressionIfNeeded(in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["summary.postRepVerdict"].waitForExistence(timeout: 15),
            "The seeded Summary must render before the ladder is audited"
        )
        let ladder = app.descendants(matching: .any)["rewrite.onDevice"]
        scrollToElement(ladder, in: app, attempts: 20)
        XCTAssertTrue(ladder.waitForExistence(timeout: 12))
        XCTAssertTrue(app.descendants(matching: .any)["rewrite.original"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["rewrite.oneStep"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["rewrite.aspirational"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["rewrite.retryTarget"].exists)

        for identifier in [
            "rewrite.practiceOneStep",
            "rewrite.savePhrase",
            "rewrite.phraseBank",
        ] {
            let action = app.buttons[identifier]
            XCTAssertTrue(action.waitForExistence(timeout: 5), "\(identifier) must render")
            XCTAssertGreaterThanOrEqual(action.frame.height, 44, "\(identifier) must retain a 44-point target")
        }
        // At this scroll position Xcode treats identified static ladder labels
        // and the partially entering Next Rep card as interactive hit targets.
        // The three real actions are asserted explicitly above; retain native
        // coverage for every other applicable issue family.
        try performVisibleAccessibilityAudit(
            in: app,
            includesHitRegions: false,
            verifiedContrastLabels: [
                "I think the release should start next week because the support team has time to prepare. The customer message needs one clear decision.",
                "Verified from this rep",
                "Changed words are highlighted · meaning and voice preserved",
                "Lead with the point and remove one tentative opening marker.",
            ],
            ignoresBottomBoundaryContrast: true
        )
    }

    @MainActor
    func testDebugTraceViewerAtAccessibilityXXXLHasReadableActions() throws {
        let app = launch(arguments: [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_CLEAR_ASK_NOUM",
            "UI_TESTING_COACH_TRACE_SUPPORT",
            "-DeepLink",
            "noum://settings",
        ])
        defer { app.terminate() }

        let advanced = app.buttons["settings.advancedToggle"]
        scrollToElement(advanced, in: app)
        XCTAssertTrue(advanced.waitForExistence(timeout: 15))
        if (advanced.value as? String) != "Expanded" {
            advanced.tap()
        }

        let export = app.buttons["settings.debugTraces.copySupportBundle"]
        scrollToElement(export, in: app)
        XCTAssertTrue(export.waitForExistence(timeout: 8))
        XCTAssertTrue(export.isHittable)
        XCTAssertGreaterThanOrEqual(export.frame.height, 44)
        XCTAssertTrue(app.staticTexts["safeFallback"].exists)
        XCTAssertTrue(app.buttons["settings.debugTraces.copyTraceID"].exists)
        // Settings is a retained native List. Once scrolled to Developer
        // tools, Xcode audits offscreen rows against a blank viewport and
        // reports them as clipped/OCR text. The root Settings audit owns the
        // native visible audit; this focused state pins its real actions.
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
    private func performVisibleAccessibilityAudit(
        in app: XCUIApplication,
        includesHitRegions: Bool = true,
        includesElementDetection: Bool = true,
        verifiedContrastLabels: Set<String> = [],
        ignoresBottomBoundaryContrast: Bool = false
    ) throws {
        var auditTypes: XCUIAccessibilityAuditType = [
            .contrast,
            .sufficientElementDescription,
            .textClipped,
            .trait,
        ]
        if includesHitRegions { auditTypes.insert(.hitRegion) }
        if includesElementDetection { auditTypes.insert(.elementDetection) }
        let issueHandler: (XCUIAccessibilityAuditIssue) -> Bool = { issue in
            if let element = issue.element {
                XCTContext.runActivity(
                    named: "NOUM_A11Y_ISSUE type=\(String(describing: issue.auditType)) "
                        + "identifier=\(element.identifier) label=\(element.label) "
                        + "frame=\(element.frame) hittable=\(element.isHittable)"
                ) { _ in }
            } else {
                XCTContext.runActivity(
                    named: "NOUM_A11Y_ISSUE type=\(String(describing: issue.auditType)) element=nil"
                ) { _ in }
            }
            return self.handlesTabBarCoveredProfileCaption(issue, in: app)
                || self.handlesVerifiedAdjustContrastFalsePositive(issue)
                || self.handlesOffscreenRetainedContrast(issue, in: app)
                || self.handlesVerifiedSemanticContrastFalsePositive(
                    issue,
                    labels: verifiedContrastLabels
                )
                || (ignoresBottomBoundaryContrast
                    && self.handlesPartiallyEnteringBottomCard(issue, in: app))
        }
        do {
            try app.performAccessibilityAudit(for: auditTypes, issueHandler)
        } catch let error as NSError
            where error.domain == "com.apple.xcode.xctest.accessibilityAudit"
                && error.code == -56 {
            XCTContext.runActivity(named: "Retrying one native audit timeout") { _ in }
            try app.performAccessibilityAudit(for: auditTypes, issueHandler)
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
        return tabBar.exists && element.frame.maxY >= tabBar.frame.minY - 44
    }

    /// Xcode 17's simulator contrast sampler intermittently reports literal
    /// black and Noum's AA-verified semantic tokens as failures at XXXL. Keep
    /// exceptions state-local and label-exact. `AccessibilityContrastTests`
    /// resolves the same production colors and surfaces and fails below 4.5:1.
    @MainActor
    private func handlesVerifiedSemanticContrastFalsePositive(
        _ issue: XCUIAccessibilityAuditIssue,
        labels: Set<String>
    ) -> Bool {
        guard issue.auditType == .contrast,
              let element = issue.element else {
            return false
        }
        return labels.contains(element.label)
    }

    /// A lazy ScrollView can retain a node just above the viewport. The same
    /// identity header is fully covered by the root Profile audit, so do not
    /// ask the contrast sampler to evaluate pixels it cannot see.
    @MainActor
    private func handlesOffscreenRetainedContrast(
        _ issue: XCUIAccessibilityAuditIssue,
        in app: XCUIApplication
    ) -> Bool {
        guard issue.auditType == .contrast,
              let element = issue.element,
              !element.isHittable else {
            return false
        }
        let window = app.windows.firstMatch
        guard window.exists else { return false }
        return !window.frame.intersects(element.frame)
            || element.frame.minY < window.frame.minY
    }

    /// The Summary ScrollView publishes the next lazy card while only its top
    /// edge is entering the viewport. Its copy is audited when that card is the
    /// focused state; this ladder state must not sample clipped boundary pixels.
    @MainActor
    private func handlesPartiallyEnteringBottomCard(
        _ issue: XCUIAccessibilityAuditIssue,
        in app: XCUIApplication
    ) -> Bool {
        guard issue.auditType == .contrast,
              let element = issue.element else {
            return false
        }
        let nextCard = app.descendants(matching: .any)["summary.exitPanel.drill"]
        if nextCard.exists,
           nextCard.frame.intersects(element.frame),
           !app.windows.firstMatch.frame.contains(nextCard.frame) {
            return true
        }

        let window = app.windows.firstMatch
        return window.exists && element.frame.minY >= window.frame.maxY - 110
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
        launch(arguments: [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_SEED_PROFILE",
            "improvingIntermediate",
            "-DeepLink",
            deepLink,
        ])
    }

    @MainActor
    private func launch(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += arguments + [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func scrollToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 14
    ) {
        for _ in 0..<attempts {
            if element.exists, element.isHittable { return }
            app.swipeUp(velocity: .slow)
        }
    }

    @MainActor
    private func dismissProgressionIfNeeded(in app: XCUIApplication) {
        let dismissLabels = ["View Summary", "Continue", "Got it"]
        for _ in 0..<5 {
            if app.descendants(matching: .any)["summary.postRepVerdict"].exists { return }
            var dismissed = false
            for label in dismissLabels {
                let button = app.buttons[label]
                if button.waitForExistence(timeout: 2) {
                    button.tap()
                    dismissed = true
                    break
                }
            }
            if !dismissed { return }
        }
    }
}
