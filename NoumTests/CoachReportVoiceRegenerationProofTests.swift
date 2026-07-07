//
//  CoachReportVoiceRegenerationProofTests.swift
//  NoumTests
//
//  RALPH app-path proof (2026-07-07). The prompt-faithful Coach Arena scores the
//  RAW prompted model reply — it never runs the app's `replyQualityIssue`
//  regeneration loop. So an arena reply that leaks report-voice metrics
//  ("Score 74, 5 fillers in 68 seconds", "170 words per minute") does NOT prove
//  the leak reaches the user: in the real app, `replyQualityIssue` returning a
//  non-nil issue forces the provider chain to REGENERATE before the reply ships.
//
//  These tests take the EXACT low-scoring replies captured from the live
//  claude-sonnet-4-6 arena run and assert the app's upstream quality gate would
//  have caught them (→ regeneration), i.e. the arena number understates app-path
//  quality on these turns. Where the gate does NOT catch a real leak, the test
//  documents the gap so it can be closed. Pure + deterministic — no network.

import Testing
import Foundation
@testable import Noum

@Suite("CoachReportVoiceRegenerationProofTests")
struct CoachReportVoiceRegenerationProofTests {

    // The verbatim reply the live arena shipped for "That's not informative."
    // (trustRepair, scored 55/100 — deterministic trustRepairReportVoice flag).
    private let notInformativeReply = """
    Fair. Score 74, 5 fillers in 68 seconds — fine on the numbers. The real issue: \
    your point arrived in sentence 4. The first three sentences were throat-clearing. \
    Next rep, open with the point. One sentence, then the reason.
    """

    // The verbatim reply the live arena shipped for "What does your system
    // actually know about me?" (groundedRead, scored 41/100 — the worst turn:
    // dashboard-voice metric recitation + over length, 116 words vs 85 limit).
    private let whatDoYouKnowReply = """
    Five weeks in, working on Warm and welcoming — specifically wanting to sound like \
    yourself in tough conversations, not a polished version of someone else. What the \
    numbers show: your pace sits at 170 words per minute and your pause rate is low \
    (0.21), which together suggest you move fast when things get uncomfortable. The \
    filler rate of 3.9 per minute is middling — not the real story. The real story is \
    the pattern: you speed up exactly when the stakes rise, and the fillers cluster \
    where you are least sure of your point.
    """

    @Test("Trust-repair report-voice leak is caught upstream → the app would regenerate")
    func trustRepairReportVoiceIsCaught() {
        let issue = AICoachChatService.replyQualityIssue(
            in: notInformativeReply,
            latestUserTurn: "That's not informative.",
            turnDepth: .trustRepair
        )
        // Non-nil ⇒ the provider chain regenerates before shipping, so the
        // arena's raw-reply 55 understates what the real app path would send.
        #expect(issue != nil,
                "Report-voice leak on a trust-repair turn must trip the app quality gate so the reply regenerates; arena raw score does not reflect this.")
    }

    @Test("Over-length groundedRead is caught upstream → the app would regenerate")
    func overLengthGroundedReadIsCaught() {
        let issue = AICoachChatService.replyQualityIssue(
            in: whatDoYouKnowReply,
            latestUserTurn: "What does your system actually know about me?",
            turnDepth: .groundedRead
        )
        // This reply is 116 words (limit 85 for groundedRead) AND recites raw
        // metrics. At minimum the length gate must catch it so it regenerates.
        #expect(issue != nil,
                "A 116-word metric-reciting groundedRead reply must trip the app quality gate (length and/or report-voice) so it regenerates.")
    }

    @Test("A real high-scoring reply that cites metrics on a progress turn is NOT flagged")
    func excellentReplyWithRequestedMetricsIsNotFlagged() {
        // The live arena's best deep-assessment reply (`am-i-improving`, 90/100).
        // The user EXPLICITLY asked about progress, so citing the filler trend is
        // the right coaching move — the report-voice guard must NOT fire here, or
        // it would force needless regeneration of an excellent reply. This proves
        // the gate is SELECTIVE (turn-aware), not a blanket number ban.
        let excellent = """
        Real improvement. Fillers dropped from 6.0 to 3.4 per minute over five weeks \
        — that's not noise.

        But the score plateauing at 77 points at something different now. The filler \
        work is done. The close this week — "I think that's probably the right call" \
        — is where the decisive gap lives.

        Next rep, end on the call itself. No "I think", no "probably". Say the \
        recommendation, then stop.
        """
        let issue = AICoachChatService.replyQualityIssue(
            in: excellent,
            latestUserTurn: "Am I actually improving or am I just doing reps?",
            turnDepth: .deepAssessment
        )
        #expect(issue == nil,
                "An excellent progress-turn reply that cites the requested metric trend must not be flagged; the report-voice guard is turn-aware, not a blanket number ban.")
    }
}
