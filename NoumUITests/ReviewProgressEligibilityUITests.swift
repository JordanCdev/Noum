import XCTest

final class ReviewProgressEligibilityUITests: XCTestCase {
    private let fixtureArgument = "UI_TESTING_REVIEW_PROGRESS_ELIGIBILITY_FIXTURE"
    private let eligibleLatestPrompt = "Which decision should the team make next?"
    private let tooFewWordsPrompt = "Which saved short transcript should stay inspectable?"
    private let tooFewWordsID = "33333333-3333-4333-8333-333333333333"

    @MainActor
    func testReviewKeepsRawRowsInspectableWithoutTurningThemIntoProgress() throws {
        let app = launch(at: "noum://review")

        XCTAssertTrue(
            app.descendants(matching: .any)["history.screen"].waitForExistence(timeout: 12),
            "The mixed-history Review fixture did not open."
        )
        XCTAssertTrue(app.descendants(matching: .any)["review.story"].waitForExistence(timeout: 6))
        XCTAssertTrue(
            app.staticTexts["Based on your latest two reps."].waitForExistence(timeout: 6),
            "Three newer thin captures must not inflate Review's evidence depth."
        )

        let historyEntry = app.descendants(matching: .any)["history.sessionListEntry"]
        scrollUntilHittable(historyEntry, in: app)
        XCTAssertTrue(historyEntry.exists)
        XCTAssertTrue(app.staticTexts["5 saved reps"].exists, "Raw saved-history count must remain visible.")
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'review.highlight.'"))
                .count,
            0,
            "Five raw scored rows must not clear the five-measured-rep highlight floor."
        )

        let progressToggle = app.buttons["review.progress.toggle"]
        scrollUntilHittable(progressToggle, in: app)
        XCTAssertTrue(progressToggle.isHittable)
        XCTAssertGreaterThanOrEqual(progressToggle.frame.height, 52)
        progressToggle.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["review.developmentForming"].waitForExistence(timeout: 6),
            "Two measured reps must keep the chart behind its three-rep evidence gate."
        )
        XCTAssertTrue(app.staticTexts["A few more scored reps will unlock the progress chart."].exists)
        XCTAssertFalse(app.staticTexts["How you're improving"].exists)
        attachScreenshot(app, name: "Review - mixed history stays at two measured reps")

        scrollToTop(in: app)
        let latest = app.buttons["review.latestRep"]
        scrollUntilHittable(latest, in: app)
        XCTAssertTrue(latest.isHittable)
        XCTAssertGreaterThanOrEqual(latest.frame.height, 48)
        latest.tap()

        XCTAssertTrue(
            app.staticTexts["Eligible latest rep"].waitForExistence(timeout: 8),
            "Review latest must route to the newest measured rep, not a newer thin capture."
        )
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", eligibleLatestPrompt)
            ).firstMatch.exists
        )
        XCTAssertFalse(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", tooFewWordsPrompt)
            ).firstMatch.exists
        )

        app.terminate()
        let rawApp = launch(at: "noum://review")
        let rawEntry = rawApp.descendants(matching: .any)["history.sessionListEntry"]
        scrollUntilHittable(rawEntry, in: rawApp)
        XCTAssertTrue(rawEntry.isHittable)
        rawEntry.tap()

        let leadSummary = rawApp.descendants(matching: .any)["history.leadSummary"]
        XCTAssertTrue(leadSummary.waitForExistence(timeout: 8))
        XCTAssertTrue(leadSummary.label.contains("5 sessions saved"))
        XCTAssertTrue(leadSummary.label.contains("2 measured reps"))
        XCTAssertTrue(leadSummary.label.contains("Average score 6.5"))

        // With one visible mode SwiftUI combines the card and its only row
        // into the card accessibility node. Assert the production aggregate
        // label instead of depending on that implementation detail.
        let timedBreakdown = rawApp.buttons["history.allModes.breakdown"].firstMatch
        scrollUntilVisible(timedBreakdown, in: rawApp)
        XCTAssertTrue(timedBreakdown.waitForExistence(timeout: 6))
        XCTAssertTrue(timedBreakdown.label.contains("2 reps"))
        XCTAssertTrue(timedBreakdown.label.contains("average score 6.5"))

        let search = rawApp.textFields["history.list.search"]
        scrollUntilHittable(search, in: rawApp)
        XCTAssertTrue(search.isHittable)
        search.tap()
        search.typeText("Two-word capture")

        let rawThinRow = rawApp.descendants(matching: .any)["history.row.\(tooFewWordsID.uppercased())"]
        scrollUntilHittable(rawThinRow, in: rawApp)
        XCTAssertTrue(
            rawThinRow.waitForExistence(timeout: 6),
            "The thin capture must remain searchable in raw All Reps history."
        )
        XCTAssertTrue(rawThinRow.label.localizedCaseInsensitiveContains("Not enough speech to measure"))
        XCTAssertFalse(rawThinRow.label.contains("10/10"))
        attachScreenshot(rawApp, name: "All Reps - raw thin capture remains inspectable")
        rawThinRow.tap()
        XCTAssertTrue(rawApp.staticTexts["Saved capture"].waitForExistence(timeout: 8))
        XCTAssertFalse(
            rawApp.staticTexts["Two-word capture"].exists,
            "A thin capture must not present its persisted evaluator headline as measured evidence."
        )
        XCTAssertTrue(
            rawApp.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", tooFewWordsPrompt)
            ).firstMatch.exists,
            "The exact saved thin row must still open its historical detail."
        )
        XCTAssertTrue(
            rawApp.descendants(matching: .any)["history.detail.insufficientEvidence"]
                .waitForExistence(timeout: 6)
        )
        XCTAssertTrue(rawApp.staticTexts["Not measured"].exists)
        XCTAssertFalse(rawApp.staticTexts["10/10"].exists)
        XCTAssertFalse(rawApp.staticTexts["Focus next"].exists)
        XCTAssertFalse(rawApp.staticTexts["See full review"].exists)
        attachScreenshot(rawApp, name: "History detail - thin capture is not measured")
    }

    @MainActor
    func testSessionHistoryControlsStayOperableAtAccessibilityXXXL() throws {
        let app = launch(at: "noum://review")
        defer { app.terminate() }

        let historyEntry = app.descendants(matching: .any)["history.sessionListEntry"]
        scrollUntilHittable(historyEntry, in: app)
        XCTAssertTrue(historyEntry.isHittable)
        historyEntry.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["history.list.screen"].waitForExistence(timeout: 8)
        )

        let allFilter = app.buttons["history.list.modeFilter.all"]
        let timedFilter = app.buttons["history.list.modeFilter.timed"]
        XCTAssertTrue(allFilter.waitForExistence(timeout: 6))
        XCTAssertTrue(timedFilter.waitForExistence(timeout: 6))
        assertMinimumTapTarget(allFilter)
        assertMinimumTapTarget(timedFilter)
        XCTAssertTrue(allFilter.isSelected)
        XCTAssertFalse(timedFilter.isSelected)

        timedFilter.tap()
        let timedBreakdown = app.descendants(matching: .any)["history.timed.breakdown"]
        XCTAssertTrue(
            timedBreakdown.waitForExistence(timeout: 6),
            "Selecting the Timed Practice filter must replace the cross-mode summary."
        )
        XCTAssertTrue(timedFilter.isSelected)
        XCTAssertFalse(allFilter.isSelected)

        let search = app.textFields["history.list.search"]
        scrollUntilHittable(search, in: app)
        XCTAssertTrue(search.waitForExistence(timeout: 6))
        assertMinimumTapTarget(search)

        let sort = app.buttons["history.list.sort"]
        scrollUntilHittable(sort, in: app)
        XCTAssertTrue(sort.waitForExistence(timeout: 6))
        assertMinimumTapTarget(sort)
        XCTAssertEqual(sort.value as? String, "Newest")

        scrollUntilHittable(search, in: app, direction: .down)
        XCTAssertTrue(search.isHittable)
        search.tap()
        search.typeText("Two-word capture")

        let matchingRow = app.descendants(matching: .any)[
            "history.row.\(tooFewWordsID.uppercased())"
        ]
        scrollUntilHittable(matchingRow, in: app)
        XCTAssertTrue(
            matchingRow.isHittable,
            "Typing in the accessible search field must still filter raw history."
        )

        let clearSearch = app.buttons["history.list.clearSearch"]
        scrollUntilHittable(clearSearch, in: app, direction: .down)
        XCTAssertTrue(clearSearch.waitForExistence(timeout: 6))
        assertMinimumTapTarget(clearSearch)
        clearSearch.tap()

        let clearSearchGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: clearSearch
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [clearSearchGone], timeout: 4),
            .completed,
            "Clearing the query must remove the conditional clear control."
        )
    }

    @MainActor
    func testProfileUsesTwoMeasuredRepsWhileLinkingToFiveRawRows() throws {
        let app = launch(at: "noum://profile")

        XCTAssertTrue(app.descendants(matching: .any)["profile.screen"].waitForExistence(timeout: 12))
        let coachRead = app.descendants(matching: .any)["profile.coachRead"]
        scrollUntilVisible(coachRead, in: app)
        XCTAssertTrue(coachRead.exists)
        let evidenceCaption = coachRead.descendants(matching: .staticText)[
            "Based on your latest two reps."
        ]
        XCTAssertTrue(evidenceCaption.waitForExistence(timeout: 6))
        XCTAssertTrue(
            coachRead.descendants(matching: .staticText)[
                "Your latest two reps are setting a starting point."
            ].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["profile.transformationQuestion"].waitForExistence(timeout: 1),
            "Five raw rows must not unlock the three-measured-rep transformation question."
        )

        let evidenceToggle = app.buttons["profile.evidenceHub.toggle"]
        scrollUntilHittable(evidenceToggle, in: app)
        XCTAssertTrue(evidenceToggle.isHittable)
        XCTAssertGreaterThanOrEqual(evidenceToggle.frame.height, 52)
        evidenceToggle.tap()

        let historyLink = app.descendants(matching: .any)["profile.evidence.history"]
        scrollUntilHittable(historyLink, in: app)
        XCTAssertTrue(historyLink.isHittable)
        XCTAssertTrue(historyLink.label.contains("5 saved reps"))
        attachScreenshot(app, name: "Profile - two measured reps and five saved rows")

        let coachingEvidence = app.descendants(matching: .any)["profile.evidence.baselineMap.row"]
        scrollUntilHittable(coachingEvidence, in: app, direction: .down)
        XCTAssertTrue(coachingEvidence.isHittable)
        coachingEvidence.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["profile.evidenceDetails"].waitForExistence(timeout: 8)
        )
        let whyPlanDisclosure = app.buttons["profile.evidence.whyPlan.toggle"]
        scrollUntilHittable(whyPlanDisclosure, in: app)
        XCTAssertTrue(whyPlanDisclosure.waitForExistence(timeout: 5) && whyPlanDisclosure.isHittable)
        whyPlanDisclosure.tap()
        XCTAssertEqual(whyPlanDisclosure.label, "Hide Why this focus")
        // Keep only one evidence disclosure open at a time. At AX XXXL the
        // complete Why-this-focus evidence is many viewports tall; stacking
        // both disclosures tests scroll distance rather than either control.
        whyPlanDisclosure.tap()
        XCTAssertEqual(whyPlanDisclosure.label, "Show Why this focus")

        let progressDisclosure = app.buttons["profile.evidence.progress.toggle"]
        scrollUntilHittable(progressDisclosure, in: app)
        XCTAssertTrue(progressDisclosure.waitForExistence(timeout: 5) && progressDisclosure.isHittable)
        progressDisclosure.tap()

        let rankProgress = app.descendants(matching: .any)["profile.evidence.rankProgress"]
        scrollUntilVisible(rankProgress, in: app, attempts: 20)
        XCTAssertTrue(rankProgress.label.contains("0 XP banked"))
        XCTAssertFalse(rankProgress.label.contains("1280 XP"))
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(identifier: "profile.evidence.speechPatterns")
                .count,
            0
        )
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(identifier: "profile.suddenDeath.historyShare")
                .count,
            0
        )
        attachScreenshot(app, name: "Profile evidence - fixture state stays coherent")

        let back = app.navigationBars["Coaching evidence"].buttons.firstMatch
        XCTAssertTrue(back.isHittable)
        back.tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.screen"].waitForExistence(timeout: 6))

        let restoredHistoryLink = app.descendants(matching: .any)["profile.evidence.history"]
        scrollUntilHittable(restoredHistoryLink, in: app)
        XCTAssertTrue(restoredHistoryLink.isHittable)
        restoredHistoryLink.tap()

        // Profile's library entry intentionally opens the shared Review root;
        // All Reps remains the explicit raw-history disclosure from there.
        let rawEntry = app.descendants(matching: .any)["history.sessionListEntry"]
        scrollUntilHittable(rawEntry, in: app)
        XCTAssertTrue(rawEntry.waitForExistence(timeout: 8))
        XCTAssertTrue(rawEntry.label.contains("5 saved reps"))
        rawEntry.tap()

        let leadSummary = app.descendants(matching: .any)["history.leadSummary"]
        XCTAssertTrue(leadSummary.waitForExistence(timeout: 8))
        XCTAssertTrue(leadSummary.label.contains("5 sessions saved"))
        XCTAssertTrue(leadSummary.label.contains("2 measured reps"))
    }

    @MainActor
    private func launch(at deepLink: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            fixtureArgument,
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
            "-DeepLink",
            deepLink,
        ]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 10)
        return app
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private enum ScrollDirection {
        case up
        case down
    }

    @MainActor
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 10,
        direction: ScrollDirection = .up
    ) {
        guard !element.isHittable else { return }
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.exists else { return }

        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            switch direction {
            case .up:
                app.swipeUp()
            case .down:
                app.swipeDown()
            }
        }
    }

    @MainActor
    private func assertMinimumTapTarget(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // XCUI can report an exact 44pt SwiftUI frame as
        // 43.99999999999996 after Core Graphics conversion. Permit only
        // floating-point noise, not a materially undersized target.
        let subpixelTolerance = 0.001
        XCTAssertTrue(element.isHittable, file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            element.frame.width + subpixelTolerance,
            44,
            file: file,
            line: line
        )
        XCTAssertGreaterThanOrEqual(
            element.frame.height + subpixelTolerance,
            44,
            file: file,
            line: line
        )
    }

    @MainActor
    private func scrollUntilVisible(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 10
    ) {
        let visibleFrame = app.frame.insetBy(dx: 0, dy: 96)
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.exists else { return }

        for _ in 0..<attempts {
            if element.exists && visibleFrame.intersects(element.frame) { return }
            app.swipeUp()
        }
    }

    @MainActor
    private func scrollToTop(in app: XCUIApplication) {
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.exists else { return }
        for _ in 0..<8 {
            scrollView.swipeDown(velocity: .fast)
        }
    }
}
