import XCTest

/// Integration UI tests for the Ask Noum *typed chat* reply flow.
///
/// These exercise the real send → CoachReplyPipeline → AskNoumStore → rendered
/// result path on the simulator. The suite uses a DEBUG-only launch argument to
/// force the provider result into an honest system notice, so the bugs these
/// guard against are the thread getting STUCK on the thinking state,
/// DUPLICATING a result for one input, or a result never appearing at all.
///
/// Microphone capture cannot be auto-tested here, but live-call caption
/// rendering is covered with DEBUG-only seeded caption fixtures.
///
/// Helpers are duplicated from `NoumUITests` so this file stays self-contained
/// (same convention as `ScreenshotTour.launchSeededAt`).
final class NoumChatFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Cold-launch seeded + deep-linked straight to the typed chat.
    @MainActor
    private func launchTypedChat(forceArguments: [String] = ["UI_TESTING_CHAT_FORCE_NOTICE"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_CLEAR_ASK_NOUM",
            "-DeepLink",
            "noum://ask/type"
        ]
        app.launchArguments += forceArguments
        app.launch()
        _ = app.otherElements["home.screen"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1.0)
        return app
    }

    /// Cold-launch seeded + deep-linked to the live coach call.
    @MainActor
    private func launchLiveCall(forceArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_CLEAR_ASK_NOUM",
            "UI_TESTING_FORCE_LIVE_COACH",
            "-DeepLink",
            "noum://ask"
        ]
        app.launchArguments += forceArguments
        app.launch()
        _ = app.otherElements["home.screen"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1.0)
        return app
    }

    /// The message field (composer is `axis: .vertical`, so it's a textView).
    @MainActor
    private func messageField(in app: XCUIApplication) -> XCUIElement {
        let identified = app.descendants(matching: .any)["askNoum.messageField"]
        if identified.exists { return identified }
        return app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
    }

    @MainActor
    private func sendControl(in app: XCUIApplication) -> XCUIElement {
        app.buttons["askNoum.inputControl"]
    }

    @MainActor
    private func waitForEnabledSendControl(in app: XCUIApplication, timeout: TimeInterval = 5) -> XCUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        let send = sendControl(in: app)
        while Date() < deadline {
            if send.exists, send.isEnabled, send.label == "Send message" { return send }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return send
    }

    /// Count of landed live coach bubbles. Legacy offline rows are deliberately
    /// excluded: new provider failures must resolve as system notices, not
    /// local coach copy.
    @MainActor
    private func coachBubbleCount(in app: XCUIApplication) -> Int {
        let elements = app.descendants(matching: .any)
        return elements.matching(NSPredicate(format: "label BEGINSWITH %@", "Noum:")).count
    }

    @MainActor
    private func coachBubbleLabels(in app: XCUIApplication) -> [String] {
        let query = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Noum:"))
        return (0..<query.count).map { query.element(boundBy: $0).label }
    }

    @MainActor
    private func noticeCount(in app: XCUIApplication) -> Int {
        app.descendants(matching: .any)
            .matching(identifier: "askNoum.systemNotice")
            .count
    }

    @MainActor
    private func resolvedTurnCount(in app: XCUIApplication) -> Int {
        coachBubbleCount(in: app) + noticeCount(in: app)
    }

    /// Wait until the result count rises above `baseline`, i.e. a reply or
    /// honest notice resolved (never stuck on the thinking state). Returns the
    /// new count.
    @MainActor
    @discardableResult
    private func waitForResolution(in app: XCUIApplication, above baseline: Int, timeout: TimeInterval = 35) -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let now = resolvedTurnCount(in: app)
            if now > baseline { return now }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return resolvedTurnCount(in: app)
    }

    @MainActor
    @discardableResult
    private func waitForCoachBubble(in app: XCUIApplication, above baseline: Int, timeout: TimeInterval = 35) -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let now = coachBubbleCount(in: app)
            if now > baseline { return now }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return coachBubbleCount(in: app)
    }

    // MARK: - Tests

    /// A typed turn must RESOLVE to either a live coach bubble or an honest
    /// system notice — the thread must never get stuck on the thinking state.
    /// Guards the
    /// "works then reverts / never answers" class of bug.
    @MainActor
    func testTypedTurnResolvesToLiveReplyOrNotice() throws {
        let app = launchTypedChat()
        let input = app.descendants(matching: .any)["askNoum.inputControl"]
        XCTAssertTrue(input.waitForExistence(timeout: 10), "Ask Noum input control should exist")

        let field = messageField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Message field should exist")
        let before = resolvedTurnCount(in: app)

        field.tap()
        field.typeText("What should I focus on in my next rep?")
        let send = waitForEnabledSendControl(in: app)
        XCTAssertEqual(send.label, "Send message", "Typing in the composer should flip the unified control into Send mode")
        XCTAssertTrue(send.isEnabled, "Send control should be enabled once draft text exists")
        send.tap()

        let after = waitForResolution(in: app, above: before)
        XCTAssertGreaterThan(after, before,
            "A typed turn must resolve to a live coach reply or honest notice — never stay stuck thinking")

        Thread.sleep(forTimeInterval: 2)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "typed-turn-resolved"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    /// Provider markdown must be normalized before it reaches the rendered
    /// chat row. The TTS copy path is covered by the paired unit tests over
    /// `AskNoumSpokenMode.spokenText`.
    @MainActor
    func testMarkdownReplyRendersWithoutRawFormattingMarkers() throws {
        let app = launchTypedChat(forceArguments: ["UI_TESTING_CHAT_FORCE_MARKDOWN_REPLY"])
        let input = app.descendants(matching: .any)["askNoum.inputControl"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        let field = messageField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))

        let beforeCoach = coachBubbleCount(in: app)
        field.tap()
        field.typeText("Be direct with me.")
        let send = waitForEnabledSendControl(in: app)
        XCTAssertEqual(send.label, "Send message")
        XCTAssertTrue(send.isEnabled)
        send.tap()

        let afterCoach = waitForCoachBubble(in: app, above: beforeCoach)
        XCTAssertEqual(afterCoach, beforeCoach + 1, "Forced markdown reply should land as one coach bubble")
        XCTAssertEqual(noticeCount(in: app), 0, "Forced markdown reply should not degrade into a notice")

        guard let latest = coachBubbleLabels(in: app).last else {
            XCTFail("Expected a rendered coach bubble")
            app.terminate()
            return
        }
        XCTAssertFalse(latest.contains("**"), "Raw markdown markers must not be visible or exposed to accessibility")
        XCTAssertFalse(latest.contains("__"), "Raw emphasis markers must not be visible or exposed to accessibility")
        XCTAssertTrue(latest.contains("Fair."), "Directness preference should get a brief human acknowledgement")
        XCTAssertTrue(latest.contains("Target:"), "The forced reply should expose the current coaching target")
        XCTAssertTrue(latest.contains("Next rep:"), "The forced reply should end with one usable rep")
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "**"))
                .count,
            0,
            "No visible/accessibility label in the chat should expose raw markdown markers"
        )

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "markdown-reply-normalized"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    /// The immersive live-call caption had the owner-visible regression:
    /// literal `**Read:**` / `**Move:**` leaked into the caption and then into
    /// spoken output. This covers the caption surface directly; spoken output
    /// is covered by `S5SpokenModeRouteTests`.
    @MainActor
    func testLiveCallCaptionRendersWithoutRawFormattingMarkers() throws {
        let app = launchLiveCall(forceArguments: ["UI_TESTING_LIVE_FORCE_MARKDOWN_CAPTION"])
        let caption = app.descendants(matching: .any)["askNoum.live.caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 10), "Forced live caption should render")

        let label = caption.label
        XCTAssertTrue(label.hasPrefix("Noum:"), "Live caption should be exposed as Noum speaking")
        XCTAssertFalse(label.contains("**"), "Live caption must not expose raw markdown markers")
        XCTAssertFalse(label.contains("__"), "Live caption must not expose raw emphasis markers")
        XCTAssertTrue(label.contains("Read:"), "Plain lead-ins can remain for visual emphasis")
        XCTAssertTrue(label.contains("Move:"), "Plain lead-ins can remain for visual emphasis")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "live-caption-markdown-normalized"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    /// Exactly ONE result per user input. Guards the double-dispatch / echo bug
    /// where one send produced two racing replies/notices.
    @MainActor
    func testOneSendProducesExactlyOneReply() throws {
        let app = launchTypedChat()
        let input = app.descendants(matching: .any)["askNoum.inputControl"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        let field = messageField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))

        let before = resolvedTurnCount(in: app)
        field.tap()
        field.typeText("Give me one concrete drill for tomorrow.")
        let send = waitForEnabledSendControl(in: app)
        XCTAssertEqual(send.label, "Send message", "Typing in the composer should flip the unified control into Send mode")
        XCTAssertTrue(send.isEnabled, "Send control should be enabled once draft text exists")
        send.tap()

        let after = waitForResolution(in: app, above: before)
        XCTAssertEqual(after, before + 1,
            "One user input must produce exactly one new result — no double-dispatch")

        // Settle window: confirm a *second* reply does not arrive late.
        Thread.sleep(forTimeInterval: 6)
        XCTAssertEqual(resolvedTurnCount(in: app), before + 1,
            "No additional reply should arrive after the turn settled")
        app.terminate()
    }

    /// The send control must be gated while a reply is in flight — a user
    /// cannot stack a second dispatch on top of an unfinished turn. Sending
    /// a second turn only after the first resolves keeps the count exact.
    @MainActor
    func testRapidSecondTapDoesNotStackReplies() throws {
        let app = launchTypedChat()
        let input = app.descendants(matching: .any)["askNoum.inputControl"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        let field = messageField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))

        let before = resolvedTurnCount(in: app)
        field.tap()
        field.typeText("Am I improving?")
        let send = waitForEnabledSendControl(in: app)
        XCTAssertEqual(send.label, "Send message", "Typing in the composer should flip the unified control into Send mode")
        XCTAssertTrue(send.isEnabled, "Send control should be enabled once draft text exists")
        send.tap()
        // Immediately tap the control again — must be a no-op while awaiting.
        send.tap()

        _ = waitForResolution(in: app, above: before)
        Thread.sleep(forTimeInterval: 6)
        XCTAssertEqual(resolvedTurnCount(in: app), before + 1,
            "A second tap during an in-flight reply must not produce a second reply")
        app.terminate()
    }
}
