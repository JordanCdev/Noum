//
//  CoachChatConversationEvaluationTests.swift
//  NoumTests
//
//  Multi-turn Ask Noum transcript fixtures.
//  SUBSTRATE ONLY: these are target-shape regression guards, not live provider
//  proof and not expert/human-coach calibration.
//

import Foundation
import Testing
@testable import Noum

enum CoachChatConversationCorpus {
    static let reportSchemaVersion = "coach-chat-conversation-eval-v3"

    static let conversations: [CoachChatConversationFixture] = [
        CoachChatConversationFixture(
            id: "cold-start-interview-baseline-conversation",
            sourceFixtureID: "cold-start-interview-baseline",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "How do I get better before my interview?",
                    coachReply: "No baseline yet, so the honest move is one interview rep. Record 60 seconds on a likely question, then review whether the first sentence gives the point before polishing anything."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I listen for in the replay?",
                    coachReply: "For your first baseline rep, listen for sentence one only. If it names the answer before the setup, keep it. If it starts with background, rewrite that first sentence and run the rep again."
                ),
                CoachChatConversationTurn(
                    userTurn: "So not my whole speaking style yet?",
                    coachReply: "Right, because one rep is too thin for a style diagnosis. Use this first pass to create the baseline, then Noum can judge whether the same pattern repeats."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "filler-pressure-prescription-conversation",
            sourceFixtureID: "filler-pressure-prescription",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "How do I stop saying um under pressure?",
                    coachReply: "Last rep had 6 fillers; the pressure cue is showing up before the close. Next rep, hold one beat before the final sentence and check whether fillers drop after that point."
                ),
                CoachChatConversationTurn(
                    userTurn: "Do I pause before every sentence?",
                    coachReply: "No, because the pause belongs where the pressure leaks: before the close. If you pause everywhere, the answer will sound managed instead of steady."
                ),
                CoachChatConversationTurn(
                    userTurn: "What proves it worked?",
                    coachReply: "Use the same 60-second prompt and timer because you only want to test the pause point. Success is fewer fillers after that point and a final sentence that still lands cleanly."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "metric-action-without-read-conversation",
            sourceFixtureID: "metric-action-without-read",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "What should I do with that filler count?",
                    coachReply: "Last rep had 5 fillers; the signal is inside the recommendation, not before it. Next rep, hold one beat after the decision line and restart if a filler appears."
                ),
                CoachChatConversationTurn(
                    userTurn: "Why after the decision line?",
                    coachReply: "Because the filler interrupts the moment where authority should sound settled. The pause after the decision gives your reason somewhere to go without weakening the recommendation."
                ),
                CoachChatConversationTurn(
                    userTurn: "What do I run next?",
                    coachReply: "Use a 45-second recommendation prompt. Sentence one is the decision, sentence two is one reason, then stop cleanly."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "critique-trust-repair-conversation",
            sourceFixtureID: "critique-trust-repair",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "This is robotic and too much writing.",
                    coachReply: "Fair push: that read was too generic. The last rep gives enough signal; next rep, use one clean opener and stop after the point lands."
                ),
                CoachChatConversationTurn(
                    userTurn: "What was generic about it?",
                    coachReply: "It was generic because it named a plan without naming the behavior. The target is the opener: run a 45-second rep where sentence one lands before the explanation starts."
                ),
                CoachChatConversationTurn(
                    userTurn: "Give me the short version.",
                    coachReply: "Short version: open with the point, add one reason, then stop. Run that once and check whether sentence one lands before any setup."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "markdown-tts-trust-repair-conversation",
            sourceFixtureID: "markdown-tts-trust-repair",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "The ** don't format and TTS reads them out. The responses feel robotic and cold, nowhere near an expert coach.",
                    coachReply: "Fair push: the asterisks should never reach you or the voice. Your last rep had 4 fillers, so state the recommendation first and stop after one proof. No symbols, no report shape."
                ),
                CoachChatConversationTurn(
                    userTurn: "And stop saying practice more.",
                    coachReply: "Agreed. The move is not more volume. It is a cleaner first sentence: recommendation, one proof, stop."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I record?",
                    coachReply: "Record one 45-second answer to a recommendation prompt. If sentence one is not the recommendation, restart."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "assistant-explainer-register-conversation",
            sourceFixtureID: "assistant-explainer-register",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "This still sounds cold and overexplained, like generic AI tips.",
                    coachReply: "Fair push: that was advice, not coaching. Your last rep has the useful signal: warmth came before the recommendation, so next rep say the recommendation first, then soften it with one reassurance."
                ),
                CoachChatConversationTurn(
                    userTurn: "Does that make me sound less warm?",
                    coachReply: "No. It moves warmth to the right place. Lead with the decision so people know what you mean, then use warmth to make the decision easier to hear."
                ),
                CoachChatConversationTurn(
                    userTurn: "Give me the pattern.",
                    coachReply: "Recommendation. One reason. One reassurance. Then stop."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "authoritative-distance-deep-assessment-conversation",
            sourceFixtureID: "authoritative-distance-deep-assessment",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "How far off am I from sounding authoritative?",
                    coachReply: "You are closer mechanically than you are to sounding authoritative overall. Your last rep was 7/10 with 1 filler, so the mechanics are partly landing, but goal readiness still needs repeated pressure evidence. Missing: more than one clean rep under stakes. Proof test: record a 75-second answer with the verdict in sentence one, one reason, and a clean stop."
                ),
                CoachChatConversationTurn(
                    userTurn: "Is 7/10 bad?",
                    coachReply: "No. It means the mechanics are not the bottleneck yet. The open question is whether the same steadiness survives a more consequential prompt."
                ),
                CoachChatConversationTurn(
                    userTurn: "What would make you change the diagnosis?",
                    coachReply: "Two clean pressure reps with verdict-first openings. If those hold, we move from mechanics to presence: less explaining, more settled commitment."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "what-next-single-move-conversation",
            sourceFixtureID: "what-next-single-move",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "What next?",
                    coachReply: "The pattern I'd pick is the rushed close. Review the last transcript, rewrite only the final sentence, then run one rep with that close as the target."
                ),
                CoachChatConversationTurn(
                    userTurn: "Why the close instead of the opening?",
                    coachReply: "The opening is serviceable enough. The close is where authority leaks because the answer ends as a summary instead of an ask."
                ),
                CoachChatConversationTurn(
                    userTurn: "What is the exact rep?",
                    coachReply: "60 seconds. Same topic. Last sentence must be the ask. If it turns into a recap, run it once more."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "overclaim-hypothesis-boundary-conversation",
            sourceFixtureID: "overclaim-hypothesis-boundary",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "Why did that answer land badly?",
                    coachReply: "From the transcript, I would treat it as a hypothesis: the recommendation arrived late. Next rep, say the conclusion first, then add one reason."
                ),
                CoachChatConversationTurn(
                    userTurn: "So I am not bad at authority?",
                    coachReply: "I would not claim that from this sample. The observable issue is order: the listener waits too long for the conclusion."
                ),
                CoachChatConversationTurn(
                    userTurn: "What test separates those?",
                    coachReply: "Run the same answer verdict-first. If it lands better with the same voice and filler count, the issue was structure, not authority."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "leadership-transfer-setup-conversation",
            sourceFixtureID: "leadership-transfer-setup",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "I have a leadership update tomorrow, what should I practice?",
                    coachReply: "Your recent timed rep was solid on fillers but light on the close. Record a 75-second leadership update and make the final sentence the ask, not a summary."
                ),
                CoachChatConversationTurn(
                    userTurn: "I do not know the ask yet.",
                    coachReply: "Then use a placeholder ask: I need alignment on the next step. The training target is the shape of the close, not the final business content."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I check after?",
                    coachReply: "Check only the final ten seconds, because that is where the update transfers into the room. If the last sentence asks for alignment or a decision, keep it; if it recaps, rewrite the close."
                )
            ]
        )
    ]

    static func evaluate(
        _ conversation: CoachChatConversationFixture
    ) -> CoachChatConversationScore {
        let source = CoachChatEvaluationCorpus.fixtures.first {
            $0.id == conversation.sourceFixtureID
        }
        let combinedCoach = conversation.turns.map(\.coachReply).joined(separator: " ")
        let combinedUser = conversation.turns.map(\.userTurn).joined(separator: " ")
        let lowerCoach = combinedCoach.lowercased()
        let lowerUser = combinedUser.lowercased()
        let turnVisionScores = conversation.turns.map { turn -> Int in
            let quoteGuard = CoachChatQuoteGuardContext(
                transcripts: [source?.sessions.first?.transcript],
                latestUserTurn: turn.userTurn,
                recentUserTurns: conversation.turns.map(\.userTurn)
            )
            return AICoachChatService.coachVisionEvaluation(
                reply: turn.coachReply,
                latestUserTurn: turn.userTurn,
                quoteGuard: quoteGuard,
                systemContext: source.map(CoachChatEvaluationCorpus.renderedContext(for:))
            ).score
        }

        var earned: [CoachChatConversationCriterion] = []
        var missed: [CoachChatConversationCriterion] = []
        var score = 0

        func evaluate(_ criterion: CoachChatConversationCriterion, weight: Int, passes: Bool) {
            if passes {
                earned.append(criterion)
                score += weight
            } else {
                missed.append(criterion)
            }
        }

        evaluate(.directAnswer, weight: 8, passes: !containsAny(lowerCoach, [
            "which direction would you prefer", "what is your priority today",
            "can you clarify", "could you clarify"
        ]))
        let hasEvidenceOrGap = hasObservableAnchor(lowerCoach) || containsAny(lowerCoach, [
            "no baseline", "too thin", "not enough", "missing",
            "hypothesis", "from this sample", "from the transcript"
        ])
        evaluate(.evidenceCalibration, weight: 12, passes: hasEvidenceOrGap && !overclaims(lowerCoach))
        evaluate(.observableAnchor, weight: 10, passes: hasObservableAnchor(lowerCoach))
        evaluate(.prescribedPractice, weight: 12, passes: prescribesPractice(lowerCoach))
        evaluate(.rationaleBridge, weight: 8, passes: containsAny(lowerCoach, [
            "because", "so ", "which", "the signal", "the pattern",
            "the issue", "the target", "the move", "the open question"
        ]))
        evaluate(.followupContinuity, weight: 8, passes: conversation.turns.count >= 3 && containsAny(lowerCoach, [
            "sentence one", "final sentence", "same", "that point",
            "the close", "the opener", "recommendation", "proof"
        ]))
        evaluate(.stateRetention, weight: 8, passes: preservesTurnState(conversation))
        evaluate(.nonRepetitiveTrajectory, weight: 4, passes: avoidsRepeatedReplyTrajectory(conversation))
        evaluate(.proofTestProgression, weight: 4, passes: proofTestsProgress(conversation))
        let isRepair = containsAny(lowerUser, [
            "robotic", "cold", "generic", "too much writing",
            "format", "tts", "not informative"
        ])
        evaluate(.adaptiveRepair, weight: 8, passes: isRepair
            ? containsAny(lowerCoach, ["fair push", "advice, not coaching", "should never", "too generic"])
            : !containsAny(lowerCoach, ["menu", "choose one"]))
        evaluate(.repairCarryover, weight: 4, passes: !isRepair || repairCarriesAcrossTurns(conversation))
        evaluate(.transferProof, weight: 6, passes: containsAny(lowerCoach, [
            "proof test", "what proves", "check", "success is",
            "tomorrow", "interview", "leadership", "same prompt",
            "same answer", "pressure reps", "record", "run one"
        ]))
        evaluate(.seniorRegister, weight: 6, passes: !containsAny(lowerCoach, AICoachChatService.roboticPhrases))
        let averageReplyWords = conversation.turns.isEmpty ? 0 : wordCount(combinedCoach) / conversation.turns.count
        evaluate(.brevity, weight: 2, passes: averageReplyWords <= 70)

        let cappedScore = harshConversationCap(
            score: score,
            lowerCoach: lowerCoach,
            conversation: conversation
        )

        return CoachChatConversationScore(
            score: max(0, min(100, cappedScore)),
            earned: earned,
            missed: missed,
            turnVisionScores: turnVisionScores,
            lowestTurnVisionScore: turnVisionScores.min() ?? 0
        )
    }

    static func knownBadVariant(
        for conversation: CoachChatConversationFixture
    ) -> CoachChatConversationFixture {
        let source = CoachChatEvaluationCorpus.fixtures.first {
            $0.id == conversation.sourceFixtureID
        }
        let badReply = source?.knownBadReply ?? "Based on your data, practice more and communicate clearly."
        return CoachChatConversationFixture(
            id: "\(conversation.id)-known-bad",
            sourceFixtureID: conversation.sourceFixtureID,
            turns: conversation.turns.map {
                CoachChatConversationTurn(userTurn: $0.userTurn, coachReply: badReply)
            }
        )
    }

    static func staleStateVariant(
        for conversation: CoachChatConversationFixture
    ) -> CoachChatConversationFixture {
        let replies = [
            "Start with a general communication goal and practice it until you feel clearer.",
            "Let's reset. Choose whether you want clarity, confidence, or polish before we pick a drill.",
            "A good next step is to keep practicing and track your progress over time."
        ]
        return CoachChatConversationFixture(
            id: "\(conversation.id)-stale-state",
            sourceFixtureID: conversation.sourceFixtureID,
            turns: conversation.turns.enumerated().map { index, turn in
                CoachChatConversationTurn(
                    userTurn: turn.userTurn,
                    coachReply: replies[min(index, replies.count - 1)]
                )
            }
        )
    }

    static func repeatedProofTestVariant(
        for conversation: CoachChatConversationFixture
    ) -> CoachChatConversationFixture {
        CoachChatConversationFixture(
            id: "\(conversation.id)-repeated-proof",
            sourceFixtureID: conversation.sourceFixtureID,
            turns: conversation.turns.map { turn in
                CoachChatConversationTurn(
                    userTurn: turn.userTurn,
                    coachReply: "\(turn.coachReply) Run the same 60-second proof test."
                )
            }
        )
    }

    private static func hasObservableAnchor(_ lower: String) -> Bool {
        if lower.rangeOfCharacter(from: .decimalDigits) != nil { return true }
        return containsAny(lower, [
            "last rep", "recent rep", "transcript", "filler", "pace",
            "sentence one", "final sentence", "close", "opener",
            "recommendation", "baseline", "sample", "proof", "pressure"
        ])
    }

    private static func prescribesPractice(_ lower: String) -> Bool {
        containsAny(lower, [
            "record", "run ", "next rep", "same prompt", "same answer",
            "rewrite", "review", "check", "listen", "use ", "say ",
            "lead with", "open with", "hold one", "make the", "stop"
        ])
    }

    private static func overclaims(_ lower: String) -> Bool {
        containsAny(lower, [
            "this proves", "definitely means", "always", "guarantees",
            "you lack conviction", "you are bad", "you are weak",
            "close overall"
        ])
    }

    private static func preservesTurnState(
        _ conversation: CoachChatConversationFixture
    ) -> Bool {
        guard conversation.turns.count >= 3 else { return false }
        if conversation.turns.map(\.coachReply).contains(where: resetsConversationState) {
            return false
        }

        for turn in conversation.turns.dropFirst() {
            let user = turn.userTurn.lowercased()
            let reply = turn.coachReply.lowercased()
            if user.contains("not my whole speaking style") &&
                !containsAny(reply, ["one rep", "too thin", "baseline"]) {
                return false
            }
            if user.contains("before every sentence") &&
                !(reply.contains("no") && containsAny(reply, ["before the close", "where the pressure", "where the pressure leaks"])) {
                return false
            }
            if user.contains("why after the decision line") && !reply.contains("decision") {
                return false
            }
            if user.contains("what was generic") &&
                !containsAny(reply, ["actual behavior", "opener", "behavior worth training"]) {
                return false
            }
            if user.contains("stop saying practice more") &&
                !containsAny(reply, ["not more volume", "cleaner first sentence"]) {
                return false
            }
            if user.contains("less warm") &&
                !(reply.contains("no") && reply.contains("warmth")) {
                return false
            }
            if user.contains("7/10 bad") &&
                !(reply.contains("no") && containsAny(reply, ["mechanics", "bottleneck"])) {
                return false
            }
            if user.contains("instead of the opening") && !reply.contains("close") {
                return false
            }
            if user.contains("not bad at authority") &&
                !containsAny(reply, ["would not claim", "observable issue", "from this sample"]) {
                return false
            }
            if user.contains("do not know the ask") && !reply.contains("placeholder ask") {
                return false
            }
        }
        return true
    }

    private static func avoidsRepeatedReplyTrajectory(
        _ conversation: CoachChatConversationFixture
    ) -> Bool {
        let normalizedReplies = conversation.turns.map {
            normalized($0.coachReply)
        }
        guard Set(normalizedReplies).count == normalizedReplies.count else { return false }

        let prefixes = normalizedReplies.map { reply in
            reply.split(separator: " ").prefix(8).joined(separator: " ")
        }
        return Set(prefixes).count == prefixes.count
    }

    private static func proofTestsProgress(
        _ conversation: CoachChatConversationFixture
    ) -> Bool {
        var counts: [String: Int] = [:]
        for reply in conversation.turns.map(\.coachReply) {
            for fingerprint in actionSentenceFingerprints(in: reply) {
                counts[fingerprint, default: 0] += 1
            }
        }
        return !counts.values.contains { $0 > 1 }
    }

    private static func harshConversationCap(
        score: Int,
        lowerCoach: String,
        conversation: CoachChatConversationFixture
    ) -> Int {
        var capped = score
        let normalizedReplies = conversation.turns.map {
            normalized($0.coachReply)
        }
        if Set(normalizedReplies).count < normalizedReplies.count {
            capped = min(capped, 42)
        }
        if overclaims(lowerCoach) || containsGenericCoachingAdvice(lowerCoach) {
            capped = min(capped, 42)
        }
        if conversation.turns.map(\.coachReply).contains(where: resetsConversationState) {
            capped = min(capped, 50)
        }
        return capped
    }

    private static func containsGenericCoachingAdvice(_ lower: String) -> Bool {
        containsAny(lower, [
            "based on your data",
            "practice more",
            "communicate clearly",
            "be clear and concise",
            "structure your thoughts",
            "practice confidence",
            "think about your audience",
            "sound more confident",
            "believe in yourself",
            "use fewer fillers next time",
            "optimize your communication plan"
        ])
    }

    private static func repairCarriesAcrossTurns(
        _ conversation: CoachChatConversationFixture
    ) -> Bool {
        let replies = conversation.turns.map { normalized($0.coachReply) }
        guard replies.first.map({ containsAny($0, ["fair push", "advice not coaching", "should never"]) }) == true else {
            return false
        }
        guard !replies.dropFirst().contains(where: resetsConversationState) else {
            return false
        }
        guard !replies.contains(where: { $0.contains("**") || $0.contains("practice more") }) else {
            return false
        }
        return true
    }

    private static func resetsConversationState(_ reply: String) -> Bool {
        let lower = normalized(reply)
        return containsAny(lower, [
            "let's reset",
            "start with a general communication goal",
            "choose whether you want",
            "what is your priority today",
            "keep practicing and track your progress"
        ])
    }

    private static func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private static func actionSentenceFingerprints(in reply: String) -> [String] {
        let delimiters = CharacterSet(charactersIn: ".!?\n")
        return reply
            .components(separatedBy: delimiters)
            .map(normalizedActionSentence)
            .filter { !$0.isEmpty }
    }

    private static func normalizedActionSentence(_ sentence: String) -> String {
        let lower = sentence.lowercased()
        guard containsAny(lower, [
            "record", "run", "repeat", "rewrite", "review", "check",
            "listen", "use", "say", "open", "hold", "make", "end"
        ]) else {
            return ""
        }

        let words = lower
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { word in
                ![
                    "a", "an", "the", "one", "same", "next", "again",
                    "then", "exact", "exactly"
                ].contains(word) &&
                !word.allSatisfy(\.isNumber) &&
                !word.hasSuffix("second")
            }
        return words.joined(separator: " ")
    }

    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
    }
}

@Suite("CoachChatConversationCorpusTests")
struct CoachChatConversationCorpusTests {

    @Test func conversationCorpusCoversTenThreeTurnTranscripts() {
        #expect(CoachChatConversationCorpus.conversations.count == 10)
        for conversation in CoachChatConversationCorpus.conversations {
            #expect(conversation.turns.count == 3, "\(conversation.id) must be a full three-turn transcript")
            #expect(CoachChatEvaluationCorpus.fixtures.contains { $0.id == conversation.sourceFixtureID })
        }
    }

    @Test func targetConversationsClearHarshConversationFloor() {
        for conversation in CoachChatConversationCorpus.conversations {
            let score = CoachChatConversationCorpus.evaluate(conversation)
            #expect(score.passesConversationFloor,
                    "\(conversation.id) scored \(score.score), lowest turn \(score.lowestTurnVisionScore), missed \(score.missed)")
        }
    }

    @Test func knownBadConversationVariantsStayFarBelowTargets() {
        for conversation in CoachChatConversationCorpus.conversations {
            let target = CoachChatConversationCorpus.evaluate(conversation)
            let bad = CoachChatConversationCorpus.evaluate(
                CoachChatConversationCorpus.knownBadVariant(for: conversation)
            )

            #expect(bad.score <= 45,
                    "\(conversation.id) known-bad score too high: \(bad.score)")
            #expect(target.score - bad.score >= 35,
                    "\(conversation.id) target/bad gap too small: target \(target.score), bad \(bad.score)")
        }
    }

    @Test func staleStateVariantsFailConversationStateGates() {
        for conversation in CoachChatConversationCorpus.conversations {
            let stale = CoachChatConversationCorpus.evaluate(
                CoachChatConversationCorpus.staleStateVariant(for: conversation)
            )

            #expect(stale.score <= 50,
                    "\(conversation.id) stale-state score too high: \(stale.score), earned \(stale.earned)")
            #expect(stale.missed.contains(.stateRetention),
                    "\(conversation.id) stale-state transcript should miss state retention")
            #expect(!stale.passesConversationFloor)
        }
    }

    @Test func repeatedProofTestVariantsFailProgressionGate() {
        for conversation in CoachChatConversationCorpus.conversations {
            let repeated = CoachChatConversationCorpus.evaluate(
                CoachChatConversationCorpus.repeatedProofTestVariant(for: conversation)
            )

            #expect(repeated.missed.contains(.proofTestProgression),
                    "\(conversation.id) repeated proof-test transcript should miss proof progression")
            #expect(!repeated.passesConversationFloor)
        }
    }

    @Test func conversationReportRoundTripsAsSortedJSON() throws {
        let report = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.conversations
        )
        let json = try report.encodedSortedJSON()

        #expect(report.schemaVersion == CoachChatConversationCorpus.reportSchemaVersion)
        #expect(report.conversationCount == 10)
        #expect(json.contains("\"schemaVersion\":\"coach-chat-conversation-eval-v3\""))
        #expect(json.contains("\"turnVisionScores\""))
        #expect(json.contains("\"userTurn\":\"How do I get better before my interview?\""))
        let allRowsPass = report.rows.allSatisfy { $0.passesConversationFloor }
        #expect(allRowsPass)
    }

    @Test func targetConversationsAreAcceptedByRuntimeGateAcrossHistory() async {
        for conversation in CoachChatConversationCorpus.conversations {
            let script = RuntimeConversationScript()
            let service = AICoachChatService(
                keyedProviders: { [.openAI] },
                keyLookup: { _ in "test-key" },
                localeSupportsAI: { true },
                providerHTTP: { _, _, _, _ in
                    let reply = await script.nextReply()
                    return .success(RuntimeConversationScript.openAIData(reply))
                }
            )
            var history: [CoachMessage] = []

            for turn in conversation.turns {
                history.append(CoachMessage(role: .user, text: turn.userTurn))
                let recentCoachReplies = history
                    .dropLast()
                    .filter { $0.role == .coach }
                    .map(\.text)
                let issue = AICoachChatService.replyQualityIssue(
                    in: turn.coachReply,
                    latestUserTurn: turn.userTurn,
                    recentCoachReplies: recentCoachReplies
                )
                #expect(issue == nil,
                        "\(conversation.id) target turn tripped gate: \(String(describing: issue))")

                await script.push(turn.coachReply)
                let outcome = await service.reply(
                    history: history,
                    systemPrompt: "You are Noum.",
                    userContext: "Conversation fixture \(conversation.id)"
                )
                guard case .reply(let accepted) = outcome else {
                    Issue.record("\(conversation.id) expected accepted reply, got \(outcome)")
                    return
                }
                #expect(accepted == turn.coachReply)
                history.append(CoachMessage(role: .coach, text: accepted))
            }
        }
    }
}

private actor RuntimeConversationScript {
    private var replies: [String] = []

    func push(_ reply: String) {
        replies.append(reply)
    }

    func nextReply() -> String {
        guard !replies.isEmpty else {
            return "No baseline yet, so run one short rep and check sentence one."
        }
        return replies.removeFirst()
    }

    static func openAIData(_ content: String) -> Data {
        let payload: [String: Any] = [
            "choices": [
                [
                    "message": [
                        "content": content
                    ],
                    "finish_reason": "stop"
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }
}
