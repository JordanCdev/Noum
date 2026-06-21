import XCTest

/// M17 verification tour — drives the live app through the surfaces touched
/// by the 13 user-recording-driven polish items in `docs/M17_handoff.md`
/// and saves an XCTAttachment screenshot for each checkpoint. Run via:
///
///     xcodebuild test \
///       -project Noum.xcodeproj -scheme Noum \
///       -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' \
///       -only-testing:NoumUITests/M17VerificationTour \
///       -resultBundlePath .build/m17-verify.xcresult
///
/// Then extract:
///
///     xcrun xcresulttool export attachments --legacy \
///       --path .build/m17-verify.xcresult \
///       --output-path .build/m17-verify-attachments
///
/// `UI_TESTING_SEED_FORCE` reseeds the `improvingIntermediate` profile so
/// captures are deterministic. Live-rep flows (Summary cards from a real
/// Sudden Death / Timed rep) cannot be driven by XCUITest because the
/// pressure engine requires real microphone audio to advance — those items
/// fall back to code-trace evidence + adjacent-surface captures.
final class M17VerificationTour: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testCaptureM17Surfaces() throws {
        // ============================================================
        // SUDDEN DEATH — items 1, 2, 3
        //   1: TTS auto-speak on .npcTurn + speaker replay button visible
        //   2: No intra-round eloquence popups during the rep
        //   3: Pre-rep "Aim for N+ words" threshold hint visible
        // (post-rep "Too short — X words (needed Y)" requires a real rep
        //  with at least one too-short round — not capturable from XCUITest)
        // ============================================================

        let sd = launchSeededAt("noum://train")
        Thread.sleep(forTimeInterval: 1.0)
        attach(sd, name: "00_mode_picker")

        // Tap Sudden Death row → reveals the setup screen with the Start CTA.
        let sdRow = revealPracticeMode("practiceMode.suddenDeath", in: sd)
        XCTAssertTrue(sdRow.waitForExistence(timeout: 5), "Sudden Death mode row missing")
        sdRow.tap()
        Thread.sleep(forTimeInterval: 0.6)
        attach(sd, name: "01_sudden_death_setup")

        // Start the session: picker → setup → live. The picker uses
        // `practiceModes.start`; the SuddenDeath setup screen's Begin
        // button has no a11y identifier so we match by label below.
        let pickerStartCTA = sd.buttons["practiceModes.start"]
        if pickerStartCTA.waitForExistence(timeout: 4) {
            pickerStartCTA.tap()
            Thread.sleep(forTimeInterval: 0.8)
            attach(sd, name: "01b_sudden_death_setup_screen")

            // Setup-screen Begin button — no a11y identifier. The button
            // is a Button(HStack { bolt icon + Text("Begin") }) so it
            // matches both the bare "Begin" label and any descendant
            // text. Try a few selectors in case the label is composed
            // differently (icon + text → composed label).
            let candidates: [XCUIElement] = [
                sd.buttons["Begin"],
                sd.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Begin'")).element(boundBy: 0),
                sd.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Begin'")).element(boundBy: 0)
            ]
            var beginBtn: XCUIElement?
            for c in candidates {
                if c.waitForExistence(timeout: 1.5) { beginBtn = c; break }
            }
            if let beginBtn {
                beginBtn.tap()
                // Engine fetches the first prompt async; allow the .npcTurn
                // text + auto-speak path to land. Speaker icon pulses while
                // speaking (variableColor) — capture while it's likely active.
                Thread.sleep(forTimeInterval: 2.5)
                attach(sd, name: "02_sudden_death_npcturn_threshold_hint")

                // Hold a beat past the typical 4-5s TTS window so we get a
                // second capture where the speaker icon has dropped to its
                // resting glyph — verifies the variableColor pulse cycles.
                Thread.sleep(forTimeInterval: 3.0)
                attach(sd, name: "03_sudden_death_npcturn_post_tts")

                // Wait through the "you have to start speaking" timer to
                // confirm no LiveEloquenceHUD chip appears mid-rep. The HUD
                // would mount as an overlay above the prompt card; if it's
                // absent the prompt card region stays clean.
                Thread.sleep(forTimeInterval: 4.0)
                attach(sd, name: "04_sudden_death_silent_no_popup")
            } else {
                attach(sd, name: "02_sudden_death_no_begin_button")
            }
        } else {
            attach(sd, name: "02_sudden_death_no_start_cta")
        }
        sd.terminate()

        // ============================================================
        // ASK NOUM — items 8, 9, 10, 11, 12, 13
        //   8:  Gemini 2.5 Flash (confirmed in plist + PracticeSupport.swift)
        //   9:  AI replies cite CONTEXT + voice register + concrete next move
        //   10: 64pt mic button on brand-blue gradient w/ halo on record
        //   11: AI-tailored follow-up chips per coach reply
        //   12: Subtitle flips "Reading your context…" → "Thinking…" after
        //       first coach reply lands
        //   13: max_tokens 700 — replies don't truncate mid-sentence
        // ============================================================

        let ask = launchSeededAt("noum://ask/type")
        // Coach opener line seeds on appear — wait for the initial reply
        // to land so we can verify the "Reading your context…" subtitle
        // is the pre-reply state.
        Thread.sleep(forTimeInterval: 2.0)
        attach(ask, name: "05_ask_noum_initial_state")

        // Scroll to bottom to ensure the input bar + voice button are
        // on-screen (the bar lives at the bottom inside `safeAreaInset`).
        ask.swipeUp(velocity: .slow)
        Thread.sleep(forTimeInterval: 0.5)
        attach(ask, name: "06_ask_noum_voice_button_visible")

        // Send a typed message → verify the subtitle flips to "Thinking…"
        // while the coach reply is in-flight, and that the reply itself
        // lands without truncation + AI chips populate underneath.
        let textField = ask.textFields.firstMatch
        if textField.waitForExistence(timeout: 4) {
            textField.tap()
            textField.typeText("How can I cut filler words in the first 10 seconds of my answer?")
            Thread.sleep(forTimeInterval: 0.4)
            attach(ask, name: "07_ask_noum_typed_question")

            // Find the send button by accessibility label (no identifier on
            // the button itself — see AskNoumView.swift:665).
            let sendBtn = ask.buttons["Send message"]
            if sendBtn.waitForExistence(timeout: 2) {
                sendBtn.tap()
                Thread.sleep(forTimeInterval: 0.8)
                attach(ask, name: "08_ask_noum_thinking_subtitle")

                // Wait up to 25s for the AI reply + chip generation.
                // Gemini 2.5 Flash typically lands in 3-8s; chip request
                // fires after the reply hydrates.
                Thread.sleep(forTimeInterval: 22.0)
                attach(ask, name: "09_ask_noum_reply_and_chips")
                // Scroll once to give the bottom of the reply room +
                // ensure the chips row is fully on-screen.
                ask.swipeUp(velocity: .slow)
                Thread.sleep(forTimeInterval: 0.5)
                attach(ask, name: "10_ask_noum_reply_bottom")
            } else {
                attach(ask, name: "08_ask_noum_no_send_button")
            }
        } else {
            attach(ask, name: "07_ask_noum_no_text_field")
        }

        ask.terminate()

        // ============================================================
        // SUMMARY — items 4, 5, 6, 7
        // The new SummaryView surfaces (PreSummaryCelebration,
        // WhatYouDidWellCard, WhatToImproveCard, TalkToNoumCTACard) only
        // render after a real Sudden Death / Timed rep completes. The
        // pressure engine requires live microphone audio to advance off
        // `.userTurn`, which XCUITest cannot supply. Falls back to:
        //   • Code-trace evidence in VERIFICATION.md (the four card
        //     files exist + are wired into `SummaryView.body` at the
        //     documented call sites).
        //   • Adjacent-surface capture: Session History detail (the
        //     non-summary review surface for past reps).
        // ============================================================

        let history = launchSeededAt("noum://review")
        Thread.sleep(forTimeInterval: 1.5)
        attach(history, name: "11_history_top")

        // Session rows live on the Session History sub-page now — the
        // Review home is insight-first. Step through the entry card.
        let listEntry = history.descendants(matching: .any)["history.sessionListEntry"]
        if listEntry.waitForExistence(timeout: 4) {
            listEntry.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

        let firstRow = history.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'history.row.'"))
            .element(boundBy: 0)
        if firstRow.waitForExistence(timeout: 4) {
            firstRow.tap()
            Thread.sleep(forTimeInterval: 1.5)
            attach(history, name: "12_history_session_detail_top")
            history.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.4)
            attach(history, name: "13_history_session_detail_mid")
            history.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.4)
            attach(history, name: "14_history_session_detail_bottom")
        }
        history.terminate()

        // ============================================================
        // REGRESSION SMOKE — Path Journey, League
        //   Confirms the M17 work didn't break adjacent flows.
        // ============================================================

        let path = launchSeededAt("noum://path")
        Thread.sleep(forTimeInterval: 1.5)
        attach(path, name: "15_path_journey_top")
        path.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.4)
        attach(path, name: "16_path_journey_bottom")
        path.terminate()

        let league = launchSeededAt("noum://league")
        Thread.sleep(forTimeInterval: 1.5)
        attach(league, name: "17_league_top")
        league.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.4)
        attach(league, name: "18_league_bottom")
        league.terminate()

        let home = launchSeeded()
        XCTAssertTrue(home.otherElements["home.screen"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5)
        attach(home, name: "19_home_top")
        home.terminate()
    }

    // MARK: - Helpers (mirrored from ScreenshotTour.swift)

    @MainActor
    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_SEED_FORCE"]
        app.launch()
        return app
    }

    @MainActor
    private func launchSeededAt(_ deepLink: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING", "UI_TESTING_SEED_FORCE", "-DeepLink", deepLink]
        app.launch()
        _ = app.otherElements["home.screen"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1.0)
        return app
    }

    @MainActor
    private func revealPracticeMode(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let modeRow = app.buttons[identifier]
        if modeRow.waitForExistence(timeout: 2) { return modeRow }

        let otherWays = app.buttons["practiceModes.otherWays"]
        if otherWays.waitForExistence(timeout: 2) {
            otherWays.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        return modeRow
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
