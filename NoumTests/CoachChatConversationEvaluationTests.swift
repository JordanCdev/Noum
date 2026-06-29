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
    static let reportSchemaVersion = "coach-chat-conversation-eval-v9"

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
                    coachReply: "Use a 45-second recommendation prompt because it tests the decision line without inviting a full essay. Sentence one is the decision, sentence two is one reason, then stop cleanly."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "critique-trust-repair-conversation",
            sourceFixtureID: "critique-trust-repair",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "This is robotic and too much writing.",
                    coachReply: "Fair push: that read was robotic and too much writing. The last rep gives enough signal; next rep, use one clean opener and stop after the point lands."
                ),
                CoachChatConversationTurn(
                    userTurn: "What was generic about it?",
                    coachReply: "That was generic because it named a plan without naming the behavior. The target is the opener: run a 45-second rep where sentence one lands before the explanation starts."
                ),
                CoachChatConversationTurn(
                    userTurn: "Give me the short version.",
                    coachReply: "Short version: the opener is the target because the prior reply buried the behavior. Open with the point, add one reason, then stop. Run that once and check whether sentence one lands before any setup."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "markdown-tts-trust-repair-conversation",
            sourceFixtureID: "markdown-tts-trust-repair",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "The ** don't format and TTS reads them out. The responses feel robotic and cold, nowhere near an expert coach.",
                    coachReply: "Fair push: the asterisks should never reach you or the voice, and that made the coaching feel robotic and cold. Your last rep had 4 fillers, so for the next rep, state the recommendation first, give one proof, then stop. No symbols, no report shape."
                ),
                CoachChatConversationTurn(
                    userTurn: "And stop saying practice more.",
                    coachReply: "Agreed: that was too generic. The move is not more volume; the target is a cleaner first sentence because it turns vague advice into a testable line: recommendation, one proof, stop."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I record?",
                    coachReply: "Record one 45-second answer to a recommendation prompt because it tests whether the first sentence carries the recommendation. If sentence one is not the recommendation, restart."
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
                    coachReply: "No. The target is placement, not less warmth: lead with the decision so people know what you mean, then use warmth to make the decision easier to hear."
                ),
                CoachChatConversationTurn(
                    userTurn: "Give me the pattern.",
                    coachReply: "Next rep, say: recommendation, one reason, one reassurance, then stop, because it keeps warmth after clarity."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "authoritative-distance-deep-assessment-conversation",
            sourceFixtureID: "authoritative-distance-deep-assessment",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "How far off am I from sounding authoritative?",
                    coachReply: "You are closer mechanically than you are to sounding authoritative overall. The transcript opens with a recommendation, and the latest timed rep was 7/10 with 1 filler, so the mechanics are partly landing, but goal readiness still needs repeated pressure evidence. Missing: more than one clean rep under stakes. Proof test: record a 75-second answer with the verdict in sentence one, one reason, and a clean stop."
                ),
                CoachChatConversationTurn(
                    userTurn: "Is 7/10 bad?",
                    coachReply: "No. 7/10 means the mechanics are not the bottleneck yet. The open question is whether the same steadiness survives a more consequential prompt."
                ),
                CoachChatConversationTurn(
                    userTurn: "What would make you change the diagnosis?",
                    coachReply: "Record 2 clean pressure reps with verdict-first openings because that is the evidence that would move the diagnosis from mechanics to presence: less explaining, more settled commitment."
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
                    coachReply: "In the last transcript, the opening is serviceable enough. The close is where authority leaks because the answer ends as a summary instead of an ask."
                ),
                CoachChatConversationTurn(
                    userTurn: "What is the exact rep?",
                    coachReply: "60 seconds, same topic, because it isolates the close. Last sentence must be the ask. If it turns into a recap, run it once more."
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
                    coachReply: "I would not claim that from this transcript. The observable issue is order: the listener waits too long for the conclusion."
                ),
                CoachChatConversationTurn(
                    userTurn: "What test separates those?",
                    coachReply: "Run the same answer verdict-first because it separates structure from authority. If it lands better with the same voice and filler count, the issue was structure, not authority."
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
                    coachReply: "For the 75-second update, use a placeholder ask: I need alignment on the next step, because it lets you train the shape of the close before the business content is final."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I check after?",
                    coachReply: "Check only the final 10 seconds of the 75-second update, because that is where the update transfers into the room. If the last sentence asks for alignment or a decision, keep it; if it recaps, rewrite the close."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "answer-depth-one-example-conversation",
            sourceFixtureID: "answer-depth-one-example",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "How do I add depth without rambling?",
                    coachReply: "Your last rep has strong reasons; the signal is no concrete example for the listener to picture. Next rep, keep the same claim, add one example, then stop before adding a second thread."
                ),
                CoachChatConversationTurn(
                    userTurn: "Can you give me an example of me doing this in sessions?",
                    coachReply: "In the vendor rep, you said implementation risk was lower and the team already knew the workflow. Those are reasons, not a picture, so add one concrete example after the first reason, then stop."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I record?",
                    coachReply: "Record the same executive recommendation in 60 seconds because it isolates answer depth. Sentence one is the claim, sentence two is one reason, sentence three is one example, then stop."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "polite-pushback-attunement-conversation",
            sourceFixtureID: "assistant-explainer-register",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "Okay, that's cool. However, I don't feel like that answered what I meant.",
                    coachReply: "Fair push: that was generic advice instead of evidence, and there is friction underneath the polite pushback. The actual read is warmth came before the recommendation, so the listener waits for the point. Next rep, say the recommendation first, then one reassurance."
                ),
                CoachChatConversationTurn(
                    userTurn: "What did you miss?",
                    coachReply: "I missed the hesitation in your pushback. Your last rep gives the actual read: the comfort came first and the point arrived late. You were asking for that behavior, not a harder drill."
                ),
                CoachChatConversationTurn(
                    userTurn: "How do I test that without sounding harsh?",
                    coachReply: "Run one 45-second client concern answer. Sentence one is the recommendation; sentence two is one reassurance. That tests order without removing warmth, because the tone stays kind while the point arrives first."
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

    static func nearDuplicateSecondTurnVariant(
        for conversation: CoachChatConversationFixture
    ) -> CoachChatConversationFixture {
        CoachChatConversationFixture(
            id: "\(conversation.id)-near-duplicate",
            sourceFixtureID: conversation.sourceFixtureID,
            turns: conversation.turns.enumerated().map { index, turn in
                guard index == 1, let firstReply = conversation.turns.first?.coachReply else {
                    return turn
                }
                return CoachChatConversationTurn(
                    userTurn: turn.userTurn,
                    coachReply: "\(firstReply) today."
                )
            }
        )
    }

    static func trustRepairWithoutAttunementVariant(
        for conversation: CoachChatConversationFixture
    ) -> CoachChatConversationFixture? {
        guard let repairIndex = conversation.turns.firstIndex(where: { turn in
            TurnDepthClassifier.classify(userText: turn.userTurn) == .trustRepair
        }) else {
            return nil
        }

        return CoachChatConversationFixture(
            id: "\(conversation.id)-no-attunement",
            sourceFixtureID: conversation.sourceFixtureID,
            turns: conversation.turns.enumerated().map { index, turn in
                guard index == repairIndex else { return turn }
                return CoachChatConversationTurn(
                    userTurn: turn.userTurn,
                    coachReply: "Let me give you the drill: run a 45-second rep with the opener first because it gives the point somewhere to land."
                )
            }
        )
    }

    static func reliabilityIssuesByTurn(
        in conversation: CoachChatConversationFixture
    ) -> [[CoachReliabilityIssue]] {
        var history: [CoachMessage] = []
        var recentActionFingerprints = Set<String>()
        var turnIssues: [[CoachReliabilityIssue]] = []

        for turn in conversation.turns {
            let turnDepth = TurnDepthClassifier.classify(
                userText: turn.userTurn,
                recentTurns: history
            )
            let previousCoachReply = history.last { $0.role == .coach }?.text
            let actionFingerprints = actionSentenceFingerprints(in: turn.coachReply)
            let proofTestRecentlyRepeated = actionFingerprints.contains {
                recentActionFingerprints.contains($0)
            }
            let verdict = CoachReliabilityGate.evaluate(
                replyText: turn.coachReply,
                previousCoachReply: previousCoachReply,
                turnDepth: turnDepth,
                assessment: nil,
                evidenceCoverage: nil,
                proofTestRecentlyRepeated: proofTestRecentlyRepeated,
                surface: .text
            )
            turnIssues.append(verdict.issues)
            recentActionFingerprints.formUnion(actionFingerprints)
            history.append(CoachMessage(role: .user, text: turn.userTurn))
            history.append(CoachMessage(role: .coach, text: turn.coachReply))
        }

        return turnIssues
    }

    static func reliabilityIssues(
        in conversation: CoachChatConversationFixture
    ) -> [CoachReliabilityIssue] {
        reliabilityIssuesByTurn(in: conversation).flatMap { $0 }
    }

    static func runtimeIssueLabelsByTurn(in conversation: CoachChatConversationFixture) -> [[String]] {
        var history: [CoachMessage] = []
        var turnIssues: [[String]] = []

        for turn in conversation.turns {
            let turnDepth = TurnDepthClassifier.classify(
                userText: turn.userTurn,
                recentTurns: history
            )
            let recentCoachReplies = history
                .filter { $0.role == .coach }
                .map(\.text)
            var labels: [String] = []
            if let issue = AICoachChatService.replyQualityIssue(
                in: turn.coachReply,
                latestUserTurn: turn.userTurn,
                recentCoachReplies: recentCoachReplies,
                turnDepth: turnDepth
            ) {
                labels.append(issue.auditLabel)
            }
            if let issue = AICoachChatService.visionQualityIssue(
                in: turn.coachReply,
                latestUserTurn: turn.userTurn,
                turnDepth: turnDepth
            ) {
                let label = issue.auditLabel
                if !labels.contains(label) {
                    labels.append(label)
                }
            }
            turnIssues.append(labels)
            history.append(CoachMessage(role: .user, text: turn.userTurn))
            history.append(CoachMessage(role: .coach, text: turn.coachReply))
        }

        return turnIssues
    }

    static func turnDepthsByTurn(in conversation: CoachChatConversationFixture) -> [CoachTurnDepth] {
        var history: [CoachMessage] = sourceFixture(for: conversation).flatMap {
            $0.previousCoachReply.map { [CoachMessage(role: .coach, text: $0)] }
        } ?? []
        var depths: [CoachTurnDepth] = []

        for turn in conversation.turns {
            let depth = TurnDepthClassifier.classify(
                userText: turn.userTurn,
                recentTurns: history
            )
            depths.append(depth)
            history.append(CoachMessage(role: .user, text: turn.userTurn))
            history.append(CoachMessage(role: .coach, text: turn.coachReply))
        }

        return depths
    }

    static func trustRepairTurnIndices(in conversation: CoachChatConversationFixture) -> [Int] {
        turnDepthsByTurn(in: conversation).enumerated().compactMap { index, depth in
            depth == .trustRepair ? index : nil
        }
    }

    static func coldnessComplaintTurnIndices(in conversation: CoachChatConversationFixture) -> [Int] {
        conversation.turns.enumerated().compactMap { index, turn in
            isColdnessComplaint(turn.userTurn) ? index : nil
        }
    }

    static func softPushbackTurnIndices(in conversation: CoachChatConversationFixture) -> [Int] {
        conversation.turns.enumerated().compactMap { index, turn in
            TurnDepthClassifier.isSoftPushback(
                turn.userTurn
                    .replacingOccurrences(of: "\u{2019}", with: "'")
                    .replacingOccurrences(of: "\u{2018}", with: "'")
                    .lowercased()
            ) ? index : nil
        }
    }

    static func userPushbackWithinTwoTurns(in conversation: CoachChatConversationFixture) -> Bool {
        var history: [CoachMessage] = []
        var lastCoachTurnIndex: Int?
        if let previousCoachReply = sourceFixture(for: conversation)?.previousCoachReply,
           !previousCoachReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            history.append(CoachMessage(role: .coach, text: previousCoachReply))
            lastCoachTurnIndex = -1
        }

        for (index, turn) in conversation.turns.enumerated() {
            let depth = TurnDepthClassifier.classify(
                userText: turn.userTurn,
                recentTurns: history
            )
            if depth == .trustRepair,
               let lastCoachTurnIndex,
               index - lastCoachTurnIndex <= 2 {
                return true
            }
            history.append(CoachMessage(role: .user, text: turn.userTurn))
            history.append(CoachMessage(role: .coach, text: turn.coachReply))
            lastCoachTurnIndex = index
        }

        return false
    }

    static func semanticIssueLabelsByTurn(in conversation: CoachChatConversationFixture) -> [[String]] {
        let sourceFixture = sourceFixture(for: conversation)
        let trajectory = UserTrajectoryCache.shared.snapshot(
            profile: sourceFixture?.profile,
            baseline: .empty,
            rating: .initial,
            sessions: sourceFixture?.sessions ?? [],
            coachMemory: nil
        ).snapshot
        let rubric = sourceFixture
            .map { GoalRubricStore.activeRubric(for: $0.profile) }
            ?? ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: nil), voice: nil)
        var history: [CoachMessage] = sourceFixture?.previousCoachReply.map {
            [CoachMessage(role: .coach, text: $0)]
        } ?? []
        var recentProofTests: [String] = []
        var turnIssues: [[String]] = []

        for turn in conversation.turns {
            let turnDepth = TurnDepthClassifier.classify(
                userText: turn.userTurn,
                recentTurns: history
            )
            let previousCoachReply = history.last { $0.role == .coach }?.text
            let assessment = CoachReasoningPass.assess(
                turnDepth: turnDepth,
                userQuestion: turn.userTurn,
                trajectory: trajectory,
                rubric: rubric,
                surface: .text,
                recentProofTests: recentProofTests,
                previousCoachReply: previousCoachReply
            )
            if let issue = AICoachChatService.semanticQualityIssue(
                in: turn.coachReply,
                turnDepth: turnDepth,
                assessment: assessment
            ) {
                turnIssues.append([CoachChatReplyQualityIssue.semanticJudgement(issue).auditLabel])
            } else {
                turnIssues.append([])
            }
            recentProofTests = updatedRecentProofTests(
                recentProofTests,
                adding: assessment.nextProofTest
            )
            history.append(CoachMessage(role: .user, text: turn.userTurn))
            history.append(CoachMessage(role: .coach, text: turn.coachReply))
        }

        return turnIssues
    }

    private static func updatedRecentProofTests(
        _ current: [String],
        adding proofTest: String,
        limit: Int = 6
    ) -> [String] {
        let trimmed = proofTest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return current }
        return Array(([trimmed] + current).prefix(limit))
    }

    private static func sourceFixture(for conversation: CoachChatConversationFixture) -> CoachChatEvaluationFixture? {
        CoachChatEvaluationCorpus.fixtures.first {
            $0.id == conversation.sourceFixtureID
        }
    }

    private static func isColdnessComplaint(_ text: String) -> Bool {
        let lower = text
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .lowercased()
        return containsAny(lower, [
            "cold",
            "robotic",
            "generic ai",
            "generic tips",
            "ai tips",
            "ai wrapper",
            "low eq",
            "not high eq",
            "not human",
            "doesn't feel human",
            "does not feel human",
            "not like a coach",
            "nowhere near an expert coach",
            "no where near an expert coach"
        ])
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
            if user.contains("what did you miss") &&
                !containsAny(reply, ["hesitation", "pushback", "underneath", "asking for the read"]) {
                return false
            }
            if user.contains("without sounding harsh") &&
                !containsAny(reply, ["warmth", "reassurance", "tone stays kind"]) {
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

    @Test func conversationCorpusCoversTwelveThreeTurnTranscripts() {
        #expect(CoachChatConversationCorpus.conversations.count == 12)
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

    @Test func targetConversationsClearReliabilityGateAcrossHistory() {
        for conversation in CoachChatConversationCorpus.conversations {
            let issues = CoachChatConversationCorpus.reliabilityIssuesByTurn(in: conversation)
            #expect(issues.allSatisfy { $0.isEmpty },
                    "\(conversation.id) target transcript tripped reliability gate: \(issues)")
        }
    }

    @Test func pairedReliabilityVariantsTripSpecificSoftIssues() {
        for conversation in CoachChatConversationCorpus.conversations {
            let nearDuplicate = CoachChatConversationCorpus.nearDuplicateSecondTurnVariant(for: conversation)
            let nearDuplicateIssues = CoachChatConversationCorpus.reliabilityIssues(in: nearDuplicate)
            #expect(nearDuplicateIssues.contains(.nearDuplicateReply),
                    "\(conversation.id) near-duplicate variant should trip nearDuplicateReply, got \(nearDuplicateIssues)")

            let repeatedProof = CoachChatConversationCorpus.repeatedProofTestVariant(for: conversation)
            let repeatedIssues = CoachChatConversationCorpus.reliabilityIssues(in: repeatedProof)
            #expect(repeatedIssues.contains(.repeatedProofTest),
                    "\(conversation.id) repeated-proof variant should trip repeatedProofTest, got \(repeatedIssues)")
        }

        let noAttunementVariants = CoachChatConversationCorpus.conversations.compactMap {
            CoachChatConversationCorpus.trustRepairWithoutAttunementVariant(for: $0)
        }
        #expect(noAttunementVariants.count >= 3)
        for conversation in noAttunementVariants {
            let issues = CoachChatConversationCorpus.reliabilityIssues(in: conversation)
            #expect(issues.contains(.noAttunementOnPushback),
                    "\(conversation.id) no-attunement variant should trip noAttunementOnPushback, got \(issues)")
        }
    }

    @Test func pairedReliabilityVariantsFailProductionFloorInReport() {
        var variants: [CoachChatConversationFixture] = []
        for conversation in CoachChatConversationCorpus.conversations {
            variants.append(CoachChatConversationCorpus.nearDuplicateSecondTurnVariant(for: conversation))
            variants.append(CoachChatConversationCorpus.repeatedProofTestVariant(for: conversation))
            if let noAttunement = CoachChatConversationCorpus
                .trustRepairWithoutAttunementVariant(for: conversation) {
                variants.append(noAttunement)
            }
        }

        let report = CoachChatConversationEvaluationReport.make(from: variants)
        #expect(!report.rows.isEmpty)
        for row in report.rows {
            #expect(!row.passesProductionFloor,
                    "\(row.conversationID) reliability variant should fail production floor")
            #expect(!row.reliabilityIssues.isEmpty,
                    "\(row.conversationID) reliability variant should expose reliability issue labels")
        }
    }

    @Test func runtimeGateVariantFailsProductionFloorInReport() {
        let conversation = CoachChatConversationFixture(
            id: "runtime-gate-bad-opening",
            sourceFixtureID: "cold-start-interview-baseline",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "How do I get better before my interview?",
                    coachReply: "Understood."
                )
            ]
        )
        let report = CoachChatConversationEvaluationReport.make(from: [conversation])
        let row = report.rows[0]

        #expect(!row.passesRuntimeGate)
        #expect(!row.passesProductionFloor)
        #expect(row.runtimeIssues.contains("professional:roboticPhrase"))
        #expect(row.runtimeIssues.contains {
            $0.hasPrefix("vision:")
        })
        #expect(row.turnRuntimeIssues.count == 1)
        #expect(row.turnRuntimeIssues[0].contains("professional:roboticPhrase"))
    }

    @Test func semanticGateVariantFailsProductionFloorInReport() {
        let conversation = CoachChatConversationFixture(
            id: "semantic-gate-hollow-trust-repair",
            sourceFixtureID: "assistant-explainer-register",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "This still sounds cold and overexplained, like generic AI tips.",
                    coachReply: "Fair push: that sounded cold, not like a human coach read. Proof test: record one verdict-first rep."
                )
            ]
        )
        let report = CoachChatConversationEvaluationReport.make(from: [conversation])
        let row = report.rows[0]

        #expect(!row.passesSemanticGate)
        #expect(!row.passesProductionFloor)
        #expect(row.semanticIssues.contains("semantic:missingRepairInsight"))
        #expect(row.turnSemanticIssues == [["semantic:missingRepairInsight"]])
    }

    @Test func politePushbackCannotPassSemanticGateBySayingBut() {
        let conversation = CoachChatConversationFixture(
            id: "semantic-gate-polite-pushback-but-only",
            sourceFixtureID: "assistant-explainer-register",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "Okay, that's cool. However, I don't feel like that answered what I meant.",
                    coachReply: "Fair push — but the move is a verdict-first rep. The actual read is your recommendation needs to land before the setup. Proof test: record one verdict-first rep."
                )
            ]
        )
        let report = CoachChatConversationEvaluationReport.make(from: [conversation])
        let row = report.rows[0]

        #expect(!row.passesSemanticGate)
        #expect(!row.passesProductionFloor)
        #expect(row.semanticIssues.contains("semantic:missingDirectVerdict"))
        #expect(row.turnSemanticIssues == [["semantic:missingDirectVerdict"]])
    }

    @Test func conversationReportExposesTrustLossSignals() throws {
        let report = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.conversations
        )
        let markdownRepair = try #require(report.rows.first {
            $0.conversationID == "markdown-tts-trust-repair-conversation"
        })
        let coldStart = try #require(report.rows.first {
            $0.conversationID == "cold-start-interview-baseline-conversation"
        })
        let politePushback = try #require(report.rows.first {
            $0.conversationID == "polite-pushback-attunement-conversation"
        })

        #expect(markdownRepair.turnDepths[0] == CoachTurnDepth.trustRepair.rawValue)
        #expect(markdownRepair.trustRepairTurnIndices == [0])
        #expect(markdownRepair.userPushbackWithinTwoTurns)
        #expect(markdownRepair.coldnessComplaintFlag)
        #expect(markdownRepair.coldnessComplaintTurnIndices == [0])
        #expect(!markdownRepair.softPushbackFlag)
        #expect(politePushback.turnDepths[0] == CoachTurnDepth.trustRepair.rawValue)
        #expect(politePushback.trustRepairTurnIndices == [0])
        #expect(politePushback.userPushbackWithinTwoTurns)
        #expect(!politePushback.coldnessComplaintFlag)
        #expect(politePushback.softPushbackFlag)
        #expect(politePushback.softPushbackTurnIndices == [0])
        #expect(!coldStart.userPushbackWithinTwoTurns)
        #expect(!coldStart.coldnessComplaintFlag)
        #expect(!coldStart.softPushbackFlag)
        #expect(report.rows.contains { $0.userPushbackWithinTwoTurns })
        #expect(report.rows.contains { $0.coldnessComplaintFlag })
        #expect(report.rows.contains { $0.softPushbackFlag })
    }

    @Test func conversationReportRoundTripsAsSortedJSON() throws {
        let report = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.conversations
        )
        let json = try report.encodedSortedJSON()

        #expect(report.schemaVersion == CoachChatConversationCorpus.reportSchemaVersion)
        #expect(report.conversationCount == 12)
        #expect(json.contains("\"schemaVersion\":\"coach-chat-conversation-eval-v9\""))
        #expect(json.contains("\"turnDepths\""))
        #expect(json.contains("\"trustRepairTurnIndices\""))
        #expect(json.contains("\"userPushbackWithinTwoTurns\""))
        #expect(json.contains("\"coldnessComplaintFlag\""))
        #expect(json.contains("\"coldnessComplaintTurnIndices\""))
        #expect(json.contains("\"softPushbackFlag\""))
        #expect(json.contains("\"softPushbackTurnIndices\""))
        #expect(json.contains("\"passesRuntimeGate\""))
        #expect(json.contains("\"passesSemanticGate\""))
        #expect(json.contains("\"runtimeIssues\""))
        #expect(json.contains("\"semanticIssues\""))
        #expect(json.contains("\"turnRuntimeIssues\""))
        #expect(json.contains("\"turnSemanticIssues\""))
        #expect(json.contains("\"passesReliabilityGate\""))
        #expect(json.contains("\"passesProductionFloor\""))
        #expect(json.contains("\"turnVisionScores\""))
        #expect(json.contains("\"userTurn\":\"How do I get better before my interview?\""))
        #expect(json.contains("\"conversationID\":\"answer-depth-one-example-conversation\""))
        #expect(json.contains("\"userTurn\":\"Can you give me an example of me doing this in sessions?\""))
        #expect(json.contains("\"conversationID\":\"polite-pushback-attunement-conversation\""))
        #expect(json.contains("\"userTurn\":\"Okay, that's cool. However, I don't feel like that answered what I meant.\""))
        let allRowsPass = report.rows.allSatisfy { $0.passesConversationFloor }
        #expect(allRowsPass)
        for row in report.rows {
            #expect(row.passesRuntimeGate,
                    "\(row.conversationID) runtime issues: \(row.turnRuntimeIssues)")
            #expect(row.passesSemanticGate,
                    "\(row.conversationID) semantic issues: \(row.turnSemanticIssues)")
            #expect(row.passesReliabilityGate,
                    "\(row.conversationID) reliability issues: \(row.turnReliabilityIssues)")
            #expect(row.passesProductionFloor,
                    "\(row.conversationID) production floor failed")
        }
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
                        "\(conversation.id) target turn tripped gate for user turn '\(turn.userTurn)': \(String(describing: issue))")

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
