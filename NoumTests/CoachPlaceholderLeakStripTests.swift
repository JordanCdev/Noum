//
//  CoachPlaceholderLeakStripTests.swift
//  NoumTests
//
//  RALPH placeholder-leak backstop (2026-07-08). Coach Arena replay flagged two
//  deterministic placeholder/scaffold leaks in captured raw model output:
//
//    LEAK 1 (fixture `thats-not-informative`, trust-repair): a scaffold label
//      ("... coaching. Real read: ...") plus bare report-voice telemetry
//      ("score 74") reached the reply text.
//    LEAK 2 (fixture `cold-start-no-data`, groundedRead cold start): internal
//      product jargon ("Ah-Counter round") and an invented metric target
//      ("under 4 fillers", "a first number") before any baseline exists.
//
//  These tests take the EXACT low-scoring captured replies and prove the
//  strip/reliability layer makes them impossible in the emitted text —
//  regardless of model output. Pure + deterministic — no network, no API key.
//
//  The arena's own detector regexes are mirrored locally so a pass here means
//  the arena's leak checks would also pass on the finalized reply.

import Foundation
import Testing
@testable import Noum

@Suite("CoachPlaceholderLeakStripTests")
struct CoachPlaceholderLeakStripTests {

    // The verbatim reply Coach Arena captured for "That's not informative."
    // (trustRepair). Contains an inline scaffold label ("Real read:"), a second
    // scaffold label ("Next rep:"), and raw report-voice telemetry ("score 74").
    private let notInformativeLeak = """
    Fair. That was fluff, not coaching. Real read: score 74, but your point \
    didn't arrive until sentence four — the first three were warm-up. That's \
    the buried lede. Next rep: say the point in sentence one, then back it. \
    Cut the throat-clearing.
    """

    // The verbatim reply Coach Arena captured for "What should I work on?" on a
    // brand-new (no baseline) account.
    private let coldStartLeak = """
    No baseline yet, so start there. Everything else I say sharpens once I've \
    heard you speak once.

    Do one Ah-Counter round: 60 seconds on a topic you know cold, aiming to \
    stay under 4 fillers. That gives you a first number and me your starting \
    point.
    """

    // Arena / gate report-voice detector patterns (superset lock-step check).
    private let reportVoiceDetectors = [
        #"\b(?:score|scored|hit)\s+(?:\d{2,3}|\d(?:\.\d)?(?:\s*/\s*10)?)\b"#,
        #"\b\d{2,3}\s*(?:/|over)\s*\d{2,3}\s*s(?:ec(?:ond)?s?)?\s*(?:/|with)\s*(?:only\s*)?\d+\s+fillers?\b"#,
        #"\b\d+\s+fillers?\s+(?:in|over|across)\s+\d{2,3}\s*(?:s|sec(?:ond)?s?)\b"#,
        #"\b(?:clean|landed|held)\s+at\s+\d{2,3}\b"#
    ]

    // Arena scaffold-label detector (mirrors lib/checks.mjs SCAFFOLD).
    private let scaffoldDetector =
        #"(?:^|\n|[.!?]\s+|[,;]\s+|—\s+|-\s+)\s*(Read|The read|Coach read|Real read|Observation|Diagnosis|Insight|Next move|Next rep|Move|Action|Why|Evidence|Try this|Try|Focus|Target|Drill|Practice|Recommend|Recommendation|Verdict)\s*:"#

    private func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: - LEAK 1: scaffold label + report-voice residue

    @Test("Trust-repair finalize removes the inline scaffold label AND the report-voice residue")
    func trustRepairFinalizeStripsScaffoldAndReportVoice() {
        let finalized = AICoachChatService.finalizedCoachReply(
            from: notInformativeLeak,
            latestUserTurn: "That's not informative.",
            turnDepth: .trustRepair
        )

        #expect(!matches(scaffoldDetector, finalized),
                "Scaffold label leaked after finalize: \(finalized)")
        for detector in reportVoiceDetectors {
            #expect(!matches(detector, finalized),
                    "Report-voice telemetry leaked after finalize (\(detector)): \(finalized)")
        }
        // The human coaching substance must survive the strip.
        #expect(finalized.lowercased().contains("sentence four"),
                "Finalize must keep the coaching read, only cut telemetry: \(finalized)")
        #expect(!finalized.isEmpty)
    }

    @Test("strippingReportVoiceResidue is idempotent and reflows cleanly")
    func reportVoiceStripIsIdempotent() {
        let once = CoachReplyTextSanitizer.strippingReportVoiceResidue(
            from: "Fair. Score 74, 5 fillers in 68 seconds — fine on the numbers. The real issue: your point arrived late."
        )
        let twice = CoachReplyTextSanitizer.strippingReportVoiceResidue(from: once)
        #expect(once == twice, "Strip must be idempotent: \(once) != \(twice)")
        for detector in reportVoiceDetectors {
            #expect(!matches(detector, once), "residue after strip (\(detector)): \(once)")
        }
        #expect(once.contains("The real issue"))
    }

    @Test("Comma-joined scaffold label is stripped mid-sentence")
    func commaJoinedScaffoldIsStripped() {
        let cleaned = CoachReplyTextSanitizer.coachReplyText(
            from: "That was fluff, real read: you buried the point in sentence four."
        )
        #expect(!matches(scaffoldDetector, cleaned), "comma-joined scaffold survived: \(cleaned)")
        #expect(cleaned.lowercased().contains("buried the point"))
    }

    @Test("Comma-joined scaffold label trips the reliability gate (stricter, not weaker)")
    func commaJoinedScaffoldTripsGate() {
        let issue = AICoachChatService.replyQualityIssue(
            in: "That was fluff, real read: you buried the point in sentence four.",
            latestUserTurn: "That's not informative.",
            turnDepth: .trustRepair
        )
        #expect(issue == .scaffoldLabel,
                "Gate must flag a comma-joined scaffold label so the chain regenerates; got \(String(describing: issue))")
    }

    @Test("A progress turn that legitimately cites the requested metric trend is NOT stripped")
    func explicitMetricTurnIsNotStripped() {
        // deepAssessment + the user explicitly asked about improvement, so the
        // report-voice backstop must NOT fire — the finalize is turn-aware.
        let reply = "Real improvement. Fillers dropped from 6.0 to 3.4 per minute over five weeks — that is not noise."
        let finalized = AICoachChatService.finalizedCoachReply(
            from: reply,
            latestUserTurn: "Am I actually improving or am I just doing reps?",
            turnDepth: .deepAssessment
        )
        #expect(finalized.contains("3.4 per minute"),
                "Explicit-metric progress turns must pass through unchanged: \(finalized)")
    }

    // MARK: - LEAK 2: cold-start product jargon + invented metric target

    private let coldStartContext = """
    RATING
    - No rated sessions yet.
    - COLD START (no baseline): do not name internal practice modes.

    BASELINE (rolling, last 30 days)
    - Not enough data for a stable baseline yet.
    """

    @Test("Cold-start reply naming internal jargon + metric target trips the gate")
    func coldStartJargonTripsGate() {
        let issue = AICoachChatService.replyQualityIssue(
            in: coldStartLeak,
            latestUserTurn: "What should I work on?",
            systemContext: coldStartContext,
            turnDepth: .groundedRead
        )
        #expect(issue != nil,
                "Cold-start product jargon / invented metric target must trip the app gate so the reply regenerates.")
        if case .roboticPhrase(let phrase)? = issue {
            #expect(phrase.contains("cold-start"),
                    "Expected a cold-start rejection reason, got \(phrase)")
        }
    }

    @Test("Invented cold-start metric target alone (no product mode) still trips the gate")
    func coldStartMetricTargetAloneTripsGate() {
        let issue = AICoachChatService.replyQualityIssue(
            in: "No baseline yet, so start there. Do one 60-second rep aiming to stay under four fillers so we get a first number.",
            latestUserTurn: "Where do I start?",
            systemContext: coldStartContext,
            turnDepth: .groundedRead
        )
        #expect(issue != nil,
                "An invented filler target / 'first number' before any baseline must trip the gate.")
    }

    @Test("Naming Ah-Counter is allowed once a real baseline exists (turn-aware, not a blanket ban)")
    func establishedUserMayNameAhCounter() {
        let establishedContext = """
        RATING
        - Overall: 1420 (Silver tier).
        - Total rated sessions: 12.

        BASELINE (rolling, last 30 days)
        - Fillers per minute: 3.9.
        """
        // A well-formed coaching reply: observable anchor -> insight bridge ->
        // one prescribed move that legitimately names the Ah-Counter tool. The
        // earlier probe here ("Do an Ah-Counter round next, then hold one silent
        // beat...") was pure prescription with no insight bridge, so it tripped
        // the unrelated `missingInsightBridge` rubric — a bad probe for this
        // assertion. This reply isolates the intended behaviour: with a real
        // baseline, naming Ah-Counter must NOT trip the cold-start jargon/metric
        // ban (which is scoped to no-baseline turns only).
        let reply = "Your fillers spike right in the gap where you're reaching for the "
            + "next point — that pause is the tell. Do an Ah-Counter round next so those "
            + "gaps become audible and you can hold a silent beat instead of filling it."
        let issue = AICoachChatService.replyQualityIssue(
            in: reply,
            latestUserTurn: "What should I work on?",
            systemContext: establishedContext,
            turnDepth: .groundedRead
        )
        // Primary guarantee (the regression the hardened cold-start guard could
        // have introduced): an established user must never hit the cold-start ban.
        if case .roboticPhrase(let phrase) = issue {
            #expect(!phrase.contains("cold-start"),
                    "Established-user Ah-Counter tripped the cold-start ban: \(phrase)")
        }
        // And a well-formed established-user reply should pass the full gate clean.
        #expect(issue == nil,
                "With a real baseline, naming Ah-Counter is valid coaching — the cold-start ban must not fire; got \(String(describing: issue))")
    }
}
