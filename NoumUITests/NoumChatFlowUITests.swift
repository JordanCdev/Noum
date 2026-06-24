import XCTest

/// Integration UI tests for the Ask Noum *typed chat* reply flow.
///
/// These exercise the real send → CoachReplyPipeline → AskNoumStore → rendered
/// result path on the simulator. The suite uses a DEBUG-only launch argument to
/// force the provider result into an honest system notice, so the bugs these
/// guard against are the thread getting STUCK on the thinking state,
/// DUPLICATING a result for one input, or a result never appearing at all.
///
/// Voice / live-call cannot be auto-tested here: the simulator has no
/// microphone. That path is covered by unit tests over the pure logic
/// (`AskNoumVoiceInput` dedup latch, `LiveCoachCallView` PTT decisions) plus
/// manual computer-use verification.
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
    private func launchTypedChat() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_CLEAR_ASK_NOUM",
            "UI_TESTING_CHAT_FORCE_NOTICE",
            "-DeepLink",
            "noum://ask/type"
        ]
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
