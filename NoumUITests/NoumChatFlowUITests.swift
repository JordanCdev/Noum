import XCTest

/// Integration UI tests for the Ask Noum *typed chat* reply flow.
///
/// These exercise the real send → CoachReplyPipeline → AskNoumStore → bubble
/// path on the simulator. The simulator bundles a Gemini key, so a turn
/// normally lands a LIVE coach bubble; if the model hiccups it lands the
/// grounded OFFLINE bubble. Both are "resolved" — the bugs these guard
/// against are the thread getting STUCK on the thinking state, DUPLICATING a
/// reply for one input, or a reply never appearing at all.
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
        app.launchArguments += ["UI_TESTING", "UI_TESTING_SEED_FORCE", "-DeepLink", "noum://ask/type"]
        app.launch()
        _ = app.otherElements["home.screen"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1.0)
        return app
    }

    /// The message field (composer is `axis: .vertical`, so it's a textView).
    @MainActor
    private func messageField(in app: XCUIApplication) -> XCUIElement {
        app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
    }

    /// Count of landed coach bubbles (live OR offline). The coach bubble's
    /// text carries an accessibility label prefixed "Noum:" (live) or
    /// "Noum, offline reply:" (offline). The header reads just "Noum" (no
    /// colon), so these predicates never match chrome.
    @MainActor
    private func coachBubbleCount(in app: XCUIApplication) -> Int {
        let live = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Noum:")).count
        let offline = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Noum, offline reply:")).count
        return live + offline
    }

    /// Wait until the coach bubble count rises above `baseline`, i.e. a reply
    /// resolved (never stuck on the thinking state). Returns the new count.
    @MainActor
    @discardableResult
    private func waitForReply(in app: XCUIApplication, above baseline: Int, timeout: TimeInterval = 35) -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let now = coachBubbleCount(in: app)
            if now > baseline { return now }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return coachBubbleCount(in: app)
    }

    // MARK: - Tests

    /// A typed turn must RESOLVE to a coach bubble (live or offline) — the
    /// thread must never get stuck on the thinking state. Guards the
    /// "works then reverts / never answers" class of bug.
    @MainActor
    func testTypedTurnResolvesToACoachReply() throws {
        let app = launchTypedChat()
        let input = app.descendants(matching: .any)["askNoum.inputControl"]
        XCTAssertTrue(input.waitForExistence(timeout: 10), "Ask Noum input control should exist")

        let field = messageField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Message field should exist")
        let before = coachBubbleCount(in: app)

        field.tap()
        field.typeText("What should I focus on in my next rep?")
        input.tap()

        let after = waitForReply(in: app, above: before)
        XCTAssertGreaterThan(after, before,
            "A typed turn must resolve to a coach reply (live or offline) — never stay stuck thinking")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "typed-turn-resolved"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    /// Exactly ONE coach reply per user input. Guards the double-dispatch /
    /// echo bug where one send produced two racing replies.
    @MainActor
    func testOneSendProducesExactlyOneReply() throws {
        let app = launchTypedChat()
        let input = app.descendants(matching: .any)["askNoum.inputControl"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        let field = messageField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))

        let before = coachBubbleCount(in: app)
        field.tap()
        field.typeText("Give me one concrete drill for tomorrow.")
        input.tap()

        let after = waitForReply(in: app, above: before)
        XCTAssertEqual(after, before + 1,
            "One user input must produce exactly one new coach bubble — no double-dispatch")

        // Settle window: confirm a *second* reply does not arrive late.
        Thread.sleep(forTimeInterval: 6)
        XCTAssertEqual(coachBubbleCount(in: app), before + 1,
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

        let before = coachBubbleCount(in: app)
        field.tap()
        field.typeText("Am I improving?")
        input.tap()
        // Immediately tap the control again — must be a no-op while awaiting.
        input.tap()

        let after = waitForReply(in: app, above: before)
        Thread.sleep(forTimeInterval: 6)
        XCTAssertEqual(coachBubbleCount(in: app), before + 1,
            "A second tap during an in-flight reply must not produce a second reply")
        app.terminate()
    }
}
