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
    static let reportSchemaVersion = "coach-chat-conversation-eval-v10"
    static let longFormReportSchemaVersion = "coach-chat-long-form-conversation-eval-v1"
    static let longFormAdversarialReportSchemaVersion = "coach-chat-long-form-adversarial-eval-v1"
    static let expertCalibrationPacketSchemaVersion = "coach-chat-conversation-expert-calibration-v1"
    static let appPathReportSchemaVersion = "coach-chat-conversation-app-path-eval-v1"
    static let liveAppPathReportSchemaVersion = "coach-chat-live-app-path-eval-v1"
    static let readinessEvidenceManifestSchemaVersion = CoachVisionProductionReadinessEvidenceManifest.schemaVersion
    static let liveProviderSweepArtifactFileName = "coach-live-eval-v1.json"
    static let professionalCoachCalibrationResultsArtifactFileName =
        "coach-chat-conversation-expert-calibration-results-v1.json"
    static let realUserTransferOutcomesArtifactFileName =
        "coach-real-user-transfer-outcomes-v1.json"
    static let realDeviceTestFlightArtifactFileName =
        "coach-real-device-testflight-qa-v1.json"
    static let operationalLaunchChecklistArtifactFileName =
        "coach-operational-launch-checklist-v1.json"

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

    static let longFormConversations: [CoachChatConversationFixture] = [
        longFormConversation(
            baseIndex: 0,
            extraTurns: [
                CoachChatConversationTurn(
                    userTurn: "What happened in that rep? It rambled after sentence two.",
                    coachReply: "Good read: sentence one gave the point, then the answer drifted after sentence two, so the next pass should keep sentence one, cut the second explanation to one reason, and stop at 60 seconds."
                ),
                CoachChatConversationTurn(
                    userTurn: "What do I take into the interview?",
                    coachReply: "The drift is the interview risk, so take only the opener and proof test: answer first, one evidence line, then stop. After the interview, check whether the interviewer asked a clearer follow-up or looked confused."
                )
            ]
        ),
        longFormConversation(
            baseIndex: 1,
            extraTurns: [
                CoachChatConversationTurn(
                    userTurn: "I tried the close pause and fillers dropped, but I sounded stiff.",
                    coachReply: "That is useful: the pause reduced pressure but cost warmth, so the next rep should hold the beat only before the final sentence, then add one natural phrase after it."
                ),
                CoachChatConversationTurn(
                    userTurn: "How do I make that natural tomorrow?",
                    coachReply: "Naturalness is the thing to test tomorrow, so run a 30-second close with one spoken rehearsal of the last sentence, then check whether it sounds like a decision rather than a performance."
                )
            ]
        ),
        longFormConversation(
            baseIndex: 2,
            extraTurns: [
                CoachChatConversationTurn(
                    userTurn: "I tried it and still filled before the proof.",
                    coachReply: "Then the decision line is cleaner, but the proof handoff is leaking, so review the transcript from the first proof sentence and rewrite only that transition: decision, because, proof."
                ),
                CoachChatConversationTurn(
                    userTurn: "Do I change the whole answer?",
                    coachReply: "No. Keep the answer structure because that isolates the proof handoff. Run 45 seconds and check only the word before the proof."
                )
            ]
        ),
        longFormConversation(
            baseIndex: 3,
            extraTurns: [
                CoachChatConversationTurn(
                    userTurn: "That felt better but still not like a real coach.",
                    coachReply: "Fair. The better move is naming the friction before the drill: you wanted a sharper read, not more instructions, so for the next rep, open with the point and check whether the first sentence would help a real listener."
                ),
                CoachChatConversationTurn(
                    userTurn: "So what should you remember next time?",
                    coachReply: "I should keep the reply short, name the behavior, and give one test because that is what was missing from the repair. You should run the opener once and check whether it sounds like a coachable behavior, not an assignment."
                )
            ]
        ),
        longFormConversation(
            baseIndex: 4,
            extraTurns: [
                CoachChatConversationTurn(
                    userTurn: "The no-symbol version is easier to hear.",
                    coachReply: "Good, delivery format was part of the trust issue, so keep the no-symbol rule and test only the recommendation line with one proof."
                ),
                CoachChatConversationTurn(
                    userTurn: "What if the voice still sounds cold?",
                    coachReply: "If the voice still sounds cold, the issue is tone rather than content, so stop the drill, record one warm version of the same recommendation, and compare whether the proof still lands."
                )
            ]
        ),
        longFormConversation(
            baseIndex: 5,
            extraTurns: [
                CoachChatConversationTurn(
                    userTurn: "I tried recommendation first and it sounded abrupt.",
                    coachReply: "That tells us order improved faster than tone. Keep the recommendation first, then add one reassurance before the reason so clarity does not feel like a shove."
                ),
                CoachChatConversationTurn(
                    userTurn: "How do I know if it worked?",
                    coachReply: "The first two sentences carry the tone risk, so use a client concern prompt and check only this order: recommendation, reassurance. If the tone still feels abrupt, soften sentence two, not sentence one."
                )
            ]
        ),
        longFormConversation(
            baseIndex: 6,
            extraTurns: [
                CoachChatConversationTurn(
                    userTurn: "I did one pressure rep. It was cleaner but not settled.",
                    coachReply: "That is the right distinction: cleaner is mechanics; settled is presence, so run a second pressure rep with the same verdict, but slow only the final five words."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I look for before I call it progress?",
                    coachReply: "Check whether the verdict arrives before any caveat and whether the final five words stay steady, because two clean reps would update the hypothesis; one clean rep is still early."
                )
            ]
        ),
        longFormConversation(
            baseIndex: 7,
            extraTurns: [
                CoachChatConversationTurn(
                    userTurn: "I rewrote the close and it became too direct.",
                    coachReply: "Good boundary: direct is useful, abrupt is the risk. Keep the ask, but add one reason before it so the listener can agree without feeling pushed."
                ),
                CoachChatConversationTurn(
                    userTurn: "What do I do after that rep?",
                    coachReply: "The last sentence is where direct can become pressure, so review that sentence only and check the ask. If it asks for alignment and the reason is already clear, stop; if it sounds like pressure, rewrite the sentence with one softer verb."
                )
            ]
        ),
        longFormConversation(
            baseIndex: 8,
            extraTurns: [
                CoachChatConversationTurn(
                    userTurn: "I tried verdict-first. It helped but I am still unsure.",
                    coachReply: "That supports the structure hypothesis, not an identity label. Run the same answer under a pressure timer and compare whether uncertainty returns before sentence two."
                ),
                CoachChatConversationTurn(
                    userTurn: "When would you call it authority instead?",
                    coachReply: "Only after repeated pressure reps show the verdict stays early and the close stays calm, because authority needs to survive pressure. Until then, call it a structure improvement with authority potential."
                )
            ]
        ),
        longFormConversation(
            baseIndex: 9,
            extraTurns: [
                CoachChatConversationTurn(
                    userTurn: "I did the update. People asked for the timeline, not the decision.",
                    coachReply: "That outcome matters: the ask may have been clear, but the timeline proof was missing, so next prep should add one date before the final ask."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I capture now?",
                    coachReply: "The listener asked for sequence, so write the audience response in one line, then record a 60-second follow-up with timeline, risk, ask. Check whether the listener would know what happens next."
                )
            ]
        )
    ]

    private static func longFormConversation(
        baseIndex: Int,
        extraTurns: [CoachChatConversationTurn]
    ) -> CoachChatConversationFixture {
        let base = conversations[baseIndex]
        return CoachChatConversationFixture(
            id: "long-form-\(base.id)",
            sourceFixtureID: base.sourceFixtureID,
            turns: base.turns + extraTurns
        )
    }

    static var professionalCalibrationConversations: [CoachChatConversationFixture] {
        conversations + longFormConversations
    }

    static var longFormAdversarialConversations: [CoachChatConversationFixture] {
        let noAttunement = longFormConversations
            .compactMap { trustRepairWithoutAttunementVariant(for: $0) }
            .first
        return [
            staleStateVariant(for: longFormConversations[0]),
            repeatedProofTestVariant(for: longFormConversations[1]),
            requireIntentMismatchVariant(at: 2),
            requireIntentMismatchVariant(at: 3),
            noAttunement ?? staleStateVariant(for: longFormConversations[4]),
            requireIntentMismatchVariant(at: 5),
            staleStateVariant(for: longFormConversations[6]),
            repeatedProofTestVariant(for: longFormConversations[7]),
            requireIntentMismatchVariant(at: 8),
            requireIntentMismatchVariant(at: 9)
        ]
    }

    private static func requireIntentMismatchVariant(
        at index: Int
    ) -> CoachChatConversationFixture {
        guard let variant = intentMismatchVariant(for: longFormConversations[index]) else {
            preconditionFailure("Missing intent-mismatch turn in long-form conversation \(index)")
        }
        return variant
    }

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

    static func intentMismatchVariant(
        for conversation: CoachChatConversationFixture
    ) -> CoachChatConversationFixture? {
        guard let mismatchIndex = conversation.turns.lastIndex(where: { turn in
            turnAsksForIntentFit(turn.userTurn)
        }) else {
            return nil
        }

        return CoachChatConversationFixture(
            id: "\(conversation.id)-intent-mismatch",
            sourceFixtureID: conversation.sourceFixtureID,
            turns: conversation.turns.enumerated().map { index, turn in
                guard index == mismatchIndex else { return turn }
                return CoachChatConversationTurn(
                    userTurn: turn.userTurn,
                    coachReply: "The move is verdict-first: answer first, give one reason, then stop."
                )
            }
        )
    }

    private static func turnAsksForIntentFit(_ text: String) -> Bool {
        let lower = text
            .lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
        return containsAny(lower, [
            "give me an example", "example of me",
            "how do i know if it worked", "if it worked",
            "what test", "test separates", "what separates",
            "what should i capture", "what do i capture", "capture now",
            "do i change", "change the whole", "change my whole",
            "when would", "when should", "when do you call",
            "what should you remember", "remember next time",
            "what do i take into", "take into the", "bring into"
        ])
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
                latestUserTurn: turn.userTurn,
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

    @Test func longFormConversationCorpusCoversTenEndToEndTranscripts() {
        #expect(CoachChatConversationCorpus.longFormConversations.count == 10)

        let sourceIDs = Set(CoachChatEvaluationCorpus.fixtures.map(\.id))
        let allDepths = Set(
            CoachChatConversationCorpus.longFormConversations
                .flatMap(CoachChatConversationCorpus.turnDepthsByTurn(in:))
        )
        let pushbackConversationCount = CoachChatConversationCorpus.longFormConversations
            .filter(CoachChatConversationCorpus.userPushbackWithinTwoTurns(in:))
            .count

        for conversation in CoachChatConversationCorpus.longFormConversations {
            #expect(conversation.id.hasPrefix("long-form-"))
            #expect(conversation.turns.count >= 5, "\(conversation.id) must be a full end-to-end transcript")
            #expect(sourceIDs.contains(conversation.sourceFixtureID))
            let finalReply = conversation.turns.last?.coachReply.lowercased() ?? ""
            #expect(["check", "after", "compare", "record"].contains { finalReply.contains($0) })
        }

        #expect(pushbackConversationCount >= 3)
        #expect(allDepths.contains(.quickMove))
        #expect(allDepths.contains(.groundedRead))
        #expect(allDepths.contains(.deepAssessment))
        #expect(allDepths.contains(.trustRepair))
    }

    @Test func targetConversationsClearHarshConversationFloor() {
        for conversation in CoachChatConversationCorpus.conversations {
            let score = CoachChatConversationCorpus.evaluate(conversation)
            #expect(score.passesConversationFloor,
                    "\(conversation.id) scored \(score.score), lowest turn \(score.lowestTurnVisionScore), missed \(score.missed)")
        }
    }

    @Test func longFormConversationsClearHarshConversationFloor() {
        for conversation in CoachChatConversationCorpus.longFormConversations {
            let score = CoachChatConversationCorpus.evaluate(conversation)
            #expect(score.passesConversationFloor,
                    "\(conversation.id) scored \(score.score), lowest turn \(score.lowestTurnVisionScore), missed \(score.missed)")
        }
    }

    @Test func replayListeningPrescriptionClearsVisionFloor() {
        let reply = "For your first baseline rep, listen for sentence one only. If it names the answer before the setup, keep it. If it starts with background, rewrite that first sentence and run the rep again."
        let vision = AICoachChatService.coachVisionEvaluation(
            reply: reply,
            latestUserTurn: "What should I listen for in the replay?",
            turnDepth: .quickMove,
            surface: .text
        )

        #expect(vision.passesProductionFloor,
                "Replay-listening prescription scored \(vision.score), missed \(vision.missed)")
        #expect(vision.earned.contains(.prescribedAction))
        #expect(vision.earned.contains(.transferProof))
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

    @Test func intentMismatchVariantFailsProductionFloorInReport() {
        let conversation = CoachChatConversationFixture(
            id: "semantic-gate-example-request-without-example",
            sourceFixtureID: "answer-depth-one-example",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "Can you give me an example of me doing this in sessions?",
                    coachReply: "The move is verdict-first: answer first, give one reason, then stop."
                )
            ]
        )
        let report = CoachChatConversationEvaluationReport.make(from: [conversation])
        let row = report.rows[0]

        #expect(!row.passesSemanticGate)
        #expect(!row.passesProductionFloor)
        #expect(row.semanticIssues.contains("semantic:missingIntentFit"))
        #expect(row.turnSemanticIssues == [["semantic:missingIntentFit"]])
    }

    @Test func recentSessionGateAcceptsConversationLocalFollowUpAnchors() {
        let recentContext = """
        RECENT (most-recent first)
        - latest rep Pressure Drill, 2/10, 1 fillers, 52s.
        """
        let priorCoachReplies = [
            "Previous coach reply named sentence one, pause placement, the decision line, warmth, authority, and one proof point."
        ]
        let cases: [(String, String)] = [
            (
                "So not my whole speaking style yet?",
                "Right, because one rep is too thin for a style diagnosis. Use this first pass to create the baseline, then Noum can judge whether the same pattern repeats."
            ),
            (
                "Do I pause before every sentence?",
                "No, because the pause belongs where the pressure leaks: before the close. If you pause everywhere, the answer will sound managed instead of steady."
            ),
            (
                "Why after the decision line?",
                "Because the filler interrupts the moment where authority should sound settled. The pause after the decision gives your reason somewhere to go without weakening the recommendation."
            ),
            (
                "Give me the short version.",
                "Short version: the opener is the target because the prior reply buried the behavior. Open with the point, add one reason, then stop. Run that once and check whether sentence one lands before any setup."
            ),
            (
                "And stop saying practice more.",
                "Agreed: that was too generic. The move is not more volume; the target is a cleaner first sentence because it turns vague advice into a testable line: recommendation, one proof, stop."
            ),
            (
                "Does that make me sound less warm?",
                "No. The target is placement, not less warmth: lead with the decision so people know what you mean, then use warmth to make the decision easier to hear."
            ),
            (
                "Give me the pattern.",
                "Next rep, say: recommendation, one reason, one reassurance, then stop, because it keeps warmth after clarity."
            ),
            (
                "So I am not bad at authority?",
                "I would not claim that from this transcript. The observable issue is order: the listener waits too long for the conclusion."
            ),
            (
                "What test separates those?",
                "Run the same answer verdict-first because it separates structure from authority. If it lands better with the same voice and filler count, the issue was structure, not authority."
            ),
            (
                "Can you give me an example of me doing this in sessions?",
                "In the vendor rep, you said implementation risk was lower and the team already knew the workflow. Those are reasons, not a picture, so add one concrete example after the first reason, then stop."
            )
        ]

        for (userTurn, reply) in cases {
            let depth = TurnDepthClassifier.classify(
                userText: userTurn,
                recentTurns: [
                    CoachMessage(role: .coach, text: priorCoachReplies[0]),
                    CoachMessage(role: .user, text: userTurn)
                ]
            )
            let issue = AICoachChatService.replyQualityIssue(
                in: reply,
                latestUserTurn: userTurn,
                systemContext: recentContext,
                recentCoachReplies: priorCoachReplies,
                turnDepth: depth,
                surface: .text
            )
            #expect(issue == nil, "\(userTurn) should not fall into typed fallback: \(String(describing: issue))")
        }
    }

    @Test func explicitMissedMeaningPushbackClassifiesAsTrustRepairWithoutThreadHistory() {
        let depth = TurnDepthClassifier.classify(
            userText: "Okay, that's cool. However, I don't feel like that answered what I meant."
        )
        #expect(depth == .trustRepair)
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
        try Self.dumpEvaluationArtifactIfRequested(
            json,
            fileName: "coach-chat-conversation-eval-v10.json"
        )

        #expect(report.schemaVersion == CoachChatConversationCorpus.reportSchemaVersion)
        #expect(report.conversationCount == 12)
        #expect(report.visionProductionReadiness.score == 18)
        #expect(report.visionProductionReadiness.maximumAllowedScore == 20)
        #expect(report.visionProductionReadiness.claim == .localEvaluationSubstrateOnly)
        #expect(!report.visionProductionReadiness.productionReady)
        #expect(report.visionProductionReadiness.blockers.contains(.noProfessionalCoachCalibration))
        #expect(json.contains("\"schemaVersion\":\"coach-chat-conversation-eval-v10\""))
        #expect(json.contains("\"visionProductionReadiness\""))
        #expect(json.contains("\"score\":18"))
        #expect(json.contains("\"maximumAllowedScore\":20"))
        #expect(json.contains("\"claim\":\"localEvaluationSubstrateOnly\""))
        #expect(json.contains("\"noRealUserLongitudinalTransferOutcomes\""))
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

    @Test func longFormConversationReportRoundTripsAsSortedJSON() throws {
        let report = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.longFormConversations,
            schemaVersion: CoachChatConversationCorpus.longFormReportSchemaVersion
        )
        let json = try report.encodedSortedJSON()
        try Self.dumpEvaluationArtifactIfRequested(
            json,
            fileName: "coach-chat-long-form-conversation-eval-v1.json"
        )

        #expect(report.schemaVersion == CoachChatConversationCorpus.longFormReportSchemaVersion)
        #expect(report.conversationCount == 10)
        #expect(report.rows.count == 10)
        let allRowsPassConversationFloor = report.rows
            .allSatisfy { $0.passesConversationFloor }
        let allRowsHaveFullTranscripts = report.rows
            .allSatisfy { $0.turns.count >= 5 }
        let containsTrustRepair = report.rows
            .contains { !$0.trustRepairTurnIndices.isEmpty }
        let containsDeepAssessment = report.rows
            .contains { $0.turnDepths.contains(CoachTurnDepth.deepAssessment.rawValue) }
        let allRowsPassProductionFloor = report.rows
            .allSatisfy { $0.passesProductionFloor }
        #expect(allRowsPassConversationFloor)
        #expect(allRowsHaveFullTranscripts)
        #expect(containsTrustRepair)
        #expect(containsDeepAssessment)
        #expect(allRowsPassProductionFloor)
        #expect(report.summary.rowsPassingConversationFloor == 10)
        #expect(report.summary.rowsPassingRuntimeGate == 10)
        #expect(report.summary.rowsPassingSemanticGate == 10)
        #expect(report.summary.rowsPassingReliabilityGate == 10)
        #expect(report.summary.rowsPassingProductionFloor == 10)
        #expect(report.summary.productionFloorFailureConversationIDs.isEmpty)
        #expect(report.summary.runtimeIssueCounts.isEmpty)
        #expect(report.summary.semanticIssueCounts.isEmpty)
        #expect(report.summary.reliabilityIssueCounts.isEmpty)
        #expect(report.visionProductionReadiness.score == 18)
        #expect(report.visionProductionReadiness.maximumAllowedScore == 20)
        #expect(report.visionProductionReadiness.claim == .localEvaluationSubstrateOnly)
        #expect(!report.visionProductionReadiness.productionReady)
        #expect(json.contains("\"schemaVersion\":\"coach-chat-long-form-conversation-eval-v1\""))
        #expect(json.contains("\"conversationID\":\"long-form-cold-start-interview-baseline-conversation\""))
        #expect(json.contains("\"summary\""))
        #expect(json.contains("\"rowsPassingProductionFloor\":10"))
        #expect(json.contains("\"runtimeIssueCounts\":{}"))
        #expect(json.contains("\"turnIndex\"") == false)
        #expect(json.contains("\"visionProductionReadiness\""))
    }

    @Test func longFormAdversarialConversationReportFailsEveryPairedTranscript() throws {
        let report = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.longFormAdversarialConversations,
            schemaVersion: CoachChatConversationCorpus.longFormAdversarialReportSchemaVersion
        )
        let json = try report.encodedSortedJSON()
        try Self.dumpEvaluationArtifactIfRequested(
            json,
            fileName: "coach-chat-long-form-adversarial-eval-v1.json"
        )

        #expect(report.schemaVersion == CoachChatConversationCorpus.longFormAdversarialReportSchemaVersion)
        #expect(report.conversationCount == 10)
        #expect(report.rows.count == 10)
        #expect(report.rows.allSatisfy { $0.turns.count >= 5 })
        #expect(report.rows.allSatisfy { !$0.passesProductionFloor })
        #expect(report.summary.rowsPassingProductionFloor == 0)
        #expect(report.summary.productionFloorFailureConversationIDs.count == 10)
        #expect(report.summary.semanticIssueCounts["semantic:missingIntentFit", default: 0] >= 5)
        #expect(report.summary.reliabilityIssueCounts["repeatedProofTest", default: 0] >= 2)
        #expect(report.summary.reliabilityIssueCounts["noAttunementOnPushback", default: 0] >= 1)
        #expect(report.visionProductionReadiness.score <= 18)
        #expect(!report.visionProductionReadiness.productionReady)
        #expect(json.contains("\"schemaVersion\":\"coach-chat-long-form-adversarial-eval-v1\""))
        #expect(json.contains("\"semantic:missingIntentFit\""))
        #expect(json.contains("\"repeatedProofTest\""))
        #expect(json.contains("\"rowsPassingProductionFloor\":0"))
    }

    @Test func conversationExpertCalibrationPacketCoversFullCorpusWithoutClaimingReadiness() throws {
        let calibrationConversations = CoachChatConversationCorpus.professionalCalibrationConversations
        let packet = CoachChatConversationExpertCalibrationPacket.make(
            from: calibrationConversations
        )
        let expectedTurnCountsByID = Dictionary(uniqueKeysWithValues: calibrationConversations.map {
            ($0.id, $0.turns.count)
        })

        #expect(packet.schemaVersion == CoachChatConversationCorpus.expertCalibrationPacketSchemaVersion)
        #expect(packet.rubricVersion == "coach-parity-conversation-calibration-v1")
        #expect(packet.humanGateStatus == .pendingExpertReview)
        #expect(packet.conversationCount == CoachProfessionalCalibrationEvidence.requiredConversationIDs.count)
        #expect(packet.rows.count == CoachProfessionalCalibrationEvidence.requiredConversationIDs.count)
        #expect(packet.instructions.contains("do not assume the app is validated or production-ready"))
        #expect(packet.instructions.contains("longitudinal user outcomes"))
        #expect(packet.responseSchema.contains("\"calibrationDecision\""))
        #expect(packet.responseSchema.contains("\"humanCoachReference\""))

        for row in packet.rows {
            #expect(
                row.turns.count == expectedTurnCountsByID[row.conversationID],
                "\(row.conversationID) should export its full transcript"
            )
            #expect(row.expertBaselineStatus == CoachChatExpertBaselineStatus.pendingExpertReview.rawValue)
            #expect(row.sourcePillar != nil, "\(row.conversationID) should keep its source pillar")
            #expect(row.coachContext?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            #expect(row.turnDepths.count == row.turns.count)
        }

        #expect(packet.rows.filter { $0.turns.count == 3 }.count == 12)
        #expect(packet.rows.filter { $0.turns.count == 5 }.count == 10)
        #expect(packet.rows.contains { !$0.trustRepairTurnIndices.isEmpty })
        #expect(packet.rows.contains { !$0.coldnessComplaintTurnIndices.isEmpty })
        #expect(packet.rows.contains { !$0.softPushbackTurnIndices.isEmpty })
    }

    @Test func conversationExpertCalibrationPacketRoundTripsAsSortedJSON() throws {
        let packet = CoachChatConversationExpertCalibrationPacket.make(
            from: CoachChatConversationCorpus.professionalCalibrationConversations
        )
        let json = try packet.encodedSortedJSON()
        try Self.dumpEvaluationArtifactIfRequested(
            json,
            fileName: "coach-chat-conversation-expert-calibration-v1.json"
        )

        #expect(json.contains("\"schemaVersion\":\"coach-chat-conversation-expert-calibration-v1\""))
        #expect(json.contains("\"humanGateStatus\":\"pendingExpertReview\""))
        #expect(json.contains("\"conversationID\":\"polite-pushback-attunement-conversation\""))
        #expect(json.contains("\"conversationID\":\"long-form-leadership-transfer-setup-conversation\""))
        #expect(json.contains("calibrationDecision"))
        #expect(json.contains("trustRepair"))
        #expect(json.contains("overallUsefulness"))
        #expect(json.contains("wouldUseWithClient"))
        #expect(!json.contains("\"visionProductionReadiness\""))
    }

    @MainActor
    @Test func scriptedConversationAppPathReportCoversFullCorpusWithoutClaimingReadiness() async throws {
        let rows = await Self.scriptedConversationAppPathRows(surface: .text)
        let targetReport = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.conversations
        )
        let report = CoachChatConversationAppPathReport.make(
            rows: rows,
            localTargetShapeScore: targetReport.visionProductionReadiness.localTargetShapeScore,
            schemaVersion: CoachChatConversationCorpus.appPathReportSchemaVersion,
            surface: .text
        )
        let json = try report.encodedSortedJSON()
        try Self.dumpEvaluationArtifactIfRequested(
            json,
            fileName: "coach-chat-conversation-app-path-eval-v1.json"
        )

        #expect(report.schemaVersion == CoachChatConversationCorpus.appPathReportSchemaVersion)
        #expect(report.conversationCount == 12)
        #expect(report.turnCount == 36)
        #expect(report.summary.conversationCount == 12)
        #expect(report.summary.turnCount == 36)

        let appPathTurns = report.rows.flatMap(\.turns)
        let appPathFloorFailureCount = report.rows
            .filter { !$0.passesAppPathFloor }
            .count
        let visionFloorFailureTurnCount = appPathTurns
            .filter { $0.visionPassesProductionFloor == false }
            .count
        let appPathFailureConversationIDs = report.rows
            .filter { !$0.passesAppPathFloor }
            .map(\.conversationID)
        #expect(report.passesAppPathFloor == (appPathFloorFailureCount == 0))
        #expect(report.summary.appPathFloorFailureCount == appPathFloorFailureCount)
        #expect(report.summary.visionFloorFailureTurnCount == visionFloorFailureTurnCount)
        #expect(report.summary.failureConversationIDs == appPathFailureConversationIDs)
        if appPathFloorFailureCount == 0 {
            #expect(report.summary.readinessWarnings.isEmpty)
        } else {
            #expect(report.summary.readinessWarnings.contains(
                CoachChatConversationAppPathWarning.appPathFloorFailures.rawValue
            ))
        }
        if visionFloorFailureTurnCount == 0 {
            #expect(!report.summary.readinessWarnings.contains(
                CoachChatConversationAppPathWarning.visionFloorFailures.rawValue
            ))
        } else {
            #expect(report.summary.readinessWarnings.contains(
                CoachChatConversationAppPathWarning.visionFloorFailures.rawValue
            ))
        }
        #expect(report.summary.targetReplyMismatchCount == 0)
        #expect(report.summary.missingMetadataTurnCount == 0)
        #expect(report.summary.semanticGateFailureTurnCount == 0)
        #expect(report.summary.qualityGateEventCounts == ["passed": 36])
        #expect(report.summary.qualityGateFamilyCounts == ["passed": 36])
        #expect(report.summary.nonCleanQualityGateEvents.isEmpty)
        #expect(report.summary.acceptedFallbackTurnCount == 0)
        #expect(report.summary.typedAssessmentFallbackTurnCount == 0)
        #expect(report.summary.qualityGateBlockingFailureTurnCount == 0)
        #expect(report.summary.reliabilityIssueTurnCount == 0)
        #expect(report.summary.qualityGateBlockingFailureTurnCount ==
            appPathTurns.filter(\.qualityGateBlockingFailure).count)
        #expect(appPathTurns.contains { !$0.qualityGateEvents.isEmpty })
        #expect(appPathTurns.allSatisfy { $0.qualityGateEvents == ["passed"] })
        #expect(appPathTurns.allSatisfy { !$0.qualityGateAcceptedFallback })
        #expect(appPathTurns.allSatisfy { !$0.typedAssessmentFallbackApplied })
        #expect(report.visionProductionReadiness.score <= 18)
        #expect(report.visionProductionReadiness.maximumAllowedScore == 20)
        #expect(report.visionProductionReadiness.claim == .localEvaluationSubstrateOnly)
        #expect(!report.visionProductionReadiness.productionReady)
        #expect(report.visionProductionReadiness.blockers.contains(.noLiveProviderTranscriptSweep))
        #expect(json.contains("\"schemaVersion\":\"coach-chat-conversation-app-path-eval-v1\""))
        #expect(json.contains("\"passesAppPathFloor\":\(report.passesAppPathFloor ? "true" : "false")"))
        #expect(json.contains("\"qualityGateEventCounts\""))
        #expect(json.contains("\"qualityGateFamilyCounts\""))
        #expect(json.contains("\"nonCleanQualityGateEvents\""))
        #expect(json.contains("\"acceptedFallbackTurnCount\""))
        #expect(json.contains("\"typedAssessmentFallbackTurnCount\""))
        #expect(json.contains("\"qualityGateBlockingFailureTurnCount\""))
        #expect(json.contains("\"visionFloorFailureTurnCount\""))
        #expect(json.contains("\"qualityGateEvents\""))
        #expect(json.contains("\"visionProductionReadiness\""))
        #expect(json.contains("\"conversationID\":\"polite-pushback-attunement-conversation\""))
        #expect(json.contains("\"turnIndex\":2"))
    }

    @MainActor
    @Test func scriptedLiveConversationAppPathReportProvesTwoSpeedLocalReadWithoutClaimingReadiness() async throws {
        let rows = await Self.scriptedConversationAppPathRows(surface: .live)
        let targetReport = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.conversations
        )
        let report = CoachChatConversationAppPathReport.make(
            rows: rows,
            localTargetShapeScore: targetReport.visionProductionReadiness.localTargetShapeScore,
            schemaVersion: CoachChatConversationCorpus.liveAppPathReportSchemaVersion,
            surface: .live
        )
        let json = try report.encodedSortedJSON()
        try Self.dumpEvaluationArtifactIfRequested(
            json,
            fileName: "coach-chat-live-app-path-eval-v1.json"
        )

        #expect(report.schemaVersion == CoachChatConversationCorpus.liveAppPathReportSchemaVersion)
        #expect(report.surface == CoachReplySurface.live.rawValue)
        #expect(report.conversationCount == 12)
        #expect(report.turnCount == 36)

        let turns = report.rows.flatMap(\.turns)
        #expect(report.summary.immediateCoachReadExpectedCount == 36)
        #expect(report.summary.immediateCoachReadMissingCount == 0)
        #expect(turns.allSatisfy { $0.immediateCoachReadExpected })
        #expect(turns.allSatisfy { $0.immediateCoachReadShown })
        #expect(turns.allSatisfy { ($0.timeToFirstVisibleTokenMs ?? Int.max) < 500 })
        #expect(report.summary.missingMetadataTurnCount == 0)
        #expect(report.summary.qualityGateEventCounts == ["passed": 36])
        #expect(report.summary.qualityGateFamilyCounts == ["passed": 36])
        #expect(report.summary.nonCleanQualityGateEvents.isEmpty)
        #expect(report.summary.acceptedFallbackTurnCount == 0)
        #expect(report.summary.typedAssessmentFallbackTurnCount == 0)
        #expect(report.summary.qualityGateBlockingFailureTurnCount == 0)
        #expect(report.summary.reliabilityIssueTurnCount == 0)
        #expect(report.visionProductionReadiness.score <= 18)
        #expect(report.visionProductionReadiness.maximumAllowedScore == 20)
        #expect(report.visionProductionReadiness.claim == .localEvaluationSubstrateOnly)
        #expect(!report.visionProductionReadiness.productionReady)
        #expect(report.visionProductionReadiness.blockers.contains(.noLiveProviderTranscriptSweep))
        #expect(json.contains("\"schemaVersion\":\"coach-chat-live-app-path-eval-v1\""))
        #expect(json.contains("\"surface\":\"live\""))
        #expect(json.contains("\"immediateCoachReadExpectedCount\":36"))
        #expect(json.contains("\"immediateCoachReadMissingCount\":0"))
        #expect(json.contains("\"visionProductionReadiness\""))
    }

    @MainActor
    @Test func productionReadinessEvidenceManifestKeepsLocalArtifactsSeparateFromLaunchEvidence() async throws {
        let manifest = try Self.productionReadinessEvidenceManifestFromCurrentArtifacts()
        let json = try manifest.encodedSortedJSON()
        try Self.dumpEvaluationArtifactIfRequested(
            json,
            fileName: "coach-vision-production-readiness-evidence-manifest-v1.json"
        )
        let liveProviderRow = manifest.rows.first { $0.key == "liveProviderTranscriptSweep" }
        let professionalCalibrationRow = manifest.rows.first {
            $0.key == "professionalCoachCalibration"
        }
        let realUserTransferRow = manifest.rows.first {
            $0.key == "realUserLongitudinalTransferOutcomes"
        }
        let realDeviceRow = manifest.rows.first {
            $0.key == "realDeviceTestFlightVerification"
        }
        let operationalRow = manifest.rows.first {
            $0.key == "operationalLaunchChecklist"
        }
        let cleanLiveProviderSweep = liveProviderRow?.status == .earned
        let cleanProfessionalCalibration = professionalCalibrationRow?.status == .earned
        let cleanRealUserTransfer = realUserTransferRow?.status == .earned
        let cleanRealDevice = realDeviceRow?.status == .earned
        let cleanOperationalLaunch = operationalRow?.status == .earned
        let rawExpectedScore = 18 +
            (cleanLiveProviderSweep ? 16 : 0) +
            (cleanProfessionalCalibration ? 20 : 0) +
            (cleanRealUserTransfer ? 26 : 0) +
            (cleanRealDevice ? 12 : 0) +
            (cleanOperationalLaunch ? 8 : 0)
        let expectedCap: Int = {
            if !cleanLiveProviderSweep ||
                !cleanProfessionalCalibration ||
                !cleanRealUserTransfer {
                return 20
            }
            if !cleanRealDevice {
                return 45
            }
            if !cleanOperationalLaunch {
                return 60
            }
            return 100
        }()
        let expectedScore = min(rawExpectedScore, expectedCap)
        let expectedBlockers: [CoachVisionProductionReadinessBlocker] =
            (cleanLiveProviderSweep ? [] : [.noLiveProviderTranscriptSweep]) +
            (cleanProfessionalCalibration ? [] : [.noProfessionalCoachCalibration]) +
            (cleanRealUserTransfer ? [] : [.noRealUserLongitudinalTransferOutcomes]) +
            (cleanRealDevice ? [] : [.noRealDeviceTestFlightVerification]) +
            (cleanOperationalLaunch ? [] : [.operationalLaunchChecklistIncomplete])

        #expect(manifest.schemaVersion == CoachChatConversationCorpus.readinessEvidenceManifestSchemaVersion)
        #expect(manifest.audit.score == expectedScore)
        #expect(manifest.audit.maximumAllowedScore == 20)
        #expect(manifest.audit.claim == .localEvaluationSubstrateOnly)
        #expect(!manifest.audit.productionReady)
        #expect(manifest.audit.blockers == expectedBlockers)
        #expect(manifest.evidence.localConversationCount == 12)
        #expect(manifest.evidence.localRowsPassingProductionFloor == 12)
        #expect(manifest.evidence.appPathImmediateReadVerified)
        #expect(manifest.evidence.appPathProofTestProgressionVerified)
        #expect(manifest.evidence.liveProviderRowsPassingFloor == (liveProviderRow?.observedCount ?? 0))
        #expect(manifest.evidence.professionalCoachCalibrationRows == (
            professionalCalibrationRow?.observedCount ?? 0
        ))
        #expect(manifest.evidence.realUserLongitudinalOutcomeCount == (
            realUserTransferRow?.observedCount ?? 0
        ))
        #expect(manifest.evidence.realDeviceTestFlightVerified == cleanRealDevice)
        #expect(manifest.evidence.operationalLaunchChecklistComplete == cleanOperationalLaunch)

        let rowsByKey = Dictionary(uniqueKeysWithValues: manifest.rows.map { ($0.key, $0) })
        #expect(rowsByKey["localConversationCorpus"]?.status == .earned)
        #expect(rowsByKey["longFormConversationCorpus"]?.status == .earned)
        #expect(rowsByKey["longFormConversationCorpus"]?.observedCount == 10)
        #expect(rowsByKey["longFormConversationCorpus"]?.blocker == nil)
        #expect(manifest.evidence.localLongFormConversationCount == 10)
        #expect(manifest.evidence.localLongFormRowsPassingConversationFloor == 10)
        #expect(rowsByKey["adversarialNegativeControlCorpus"]?.status == .earned)
        #expect(rowsByKey["adversarialNegativeControlCorpus"]?.observedCount == 10)
        #expect(rowsByKey["adversarialNegativeControlCorpus"]?.blocker == nil)
        #expect(manifest.evidence.localAdversarialConversationCount == 10)
        #expect(manifest.evidence.localAdversarialRowsRejectedByProductionFloor == 10)
        #expect(rowsByKey["textAppPathReplay"]?.status == .earned)
        #expect(rowsByKey["liveAppPathImmediateRead"]?.status == .earned)
        #expect(rowsByKey["liveProviderTranscriptSweep"]?.status == (
            cleanLiveProviderSweep ? .earned : .missing
        ))
        #expect(rowsByKey["professionalCoachCalibration"]?.status == (
            cleanProfessionalCalibration ? .earned : .pending
        ))
        #expect(rowsByKey["realUserLongitudinalTransferOutcomes"]?.status == (
            cleanRealUserTransfer ? .earned : .missing
        ))
        #expect(rowsByKey["realDeviceTestFlightVerification"]?.status == (
            cleanRealDevice ? .earned : .missing
        ))
        #expect(rowsByKey["operationalLaunchChecklist"]?.status == (
            cleanOperationalLaunch ? .earned : .missing
        ))
        #expect(rowsByKey["liveProviderTranscriptSweep"]?.blocker == (
            cleanLiveProviderSweep ? nil : .noLiveProviderTranscriptSweep
        ))
        #expect(rowsByKey["professionalCoachCalibration"]?.blocker == (
            cleanProfessionalCalibration ? nil : .noProfessionalCoachCalibration
        ))
        #expect(rowsByKey["realUserLongitudinalTransferOutcomes"]?.blocker == (
            cleanRealUserTransfer ? nil : .noRealUserLongitudinalTransferOutcomes
        ))
        #expect(rowsByKey["realDeviceTestFlightVerification"]?.blocker == (
            cleanRealDevice ? nil : .noRealDeviceTestFlightVerification
        ))
        #expect(rowsByKey["operationalLaunchChecklist"]?.blocker == (
            cleanOperationalLaunch ? nil : .operationalLaunchChecklistIncomplete
        ))
        #expect(json.contains("\"schemaVersion\":\"coach-vision-production-readiness-evidence-manifest-v1\""))
        #expect(json.contains("\"liveProviderTranscriptSweep\""))
        #expect(json.contains("\"professionalCoachCalibration\""))
        #expect(json.contains("\"adversarialNegativeControlCorpus\""))
        #expect(json.contains("\"localEvaluationSubstrateOnly\""))
        #expect(json.contains("\"noRealUserLongitudinalTransferOutcomes\""))
    }

    @MainActor
    @Test func productionReadinessManifestIngestsCleanLiveSweepFromArtifactDirectory() async throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sweep = Self.liveProviderSweepEvidence()
        try sweep.encodedSortedJSON().write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.liveProviderSweepArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        let manifest = try Self.productionReadinessEvidenceManifestFromCurrentArtifacts(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachLiveProviderSweepManifest.\(UUID().uuidString)")!
        )
        let rowsByKey = Dictionary(uniqueKeysWithValues: manifest.rows.map { ($0.key, $0) })

        #expect(
            manifest.evidence.liveProviderRowsPassingFloor ==
                CoachLiveProviderSweepEvidence.requiredReadinessEvidenceCount
        )
        #expect(rowsByKey["liveProviderTranscriptSweep"]?.status == .earned)
        #expect(rowsByKey["liveProviderTranscriptSweep"]?.blocker == nil)
        #expect(!manifest.audit.blockers.contains(.noLiveProviderTranscriptSweep))
        #expect(manifest.audit.blockers.contains(.noProfessionalCoachCalibration))
        #expect(manifest.audit.blockers.contains(.noRealUserLongitudinalTransferOutcomes))
        #expect(manifest.audit.score == 20)
        #expect(manifest.audit.maximumAllowedScore == 20)
        #expect(!manifest.audit.productionReady)
    }

    @MainActor
    @Test func productionReadinessManifestIngestsCleanProfessionalCalibrationFromArtifactDirectory() async throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let calibration = Self.professionalCalibrationEvidence()
        try calibration.encodedSortedJSON().write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.professionalCoachCalibrationResultsArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        let manifest = try Self.productionReadinessEvidenceManifestFromCurrentArtifacts(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachProfessionalCalibrationManifest.\(UUID().uuidString)")!
        )
        let rowsByKey = Dictionary(uniqueKeysWithValues: manifest.rows.map { ($0.key, $0) })

        #expect(
            manifest.evidence.professionalCoachCalibrationRows ==
                CoachProfessionalCalibrationEvidence.requiredConversationIDs.count
        )
        #expect(rowsByKey["professionalCoachCalibration"]?.status == .earned)
        #expect(rowsByKey["professionalCoachCalibration"]?.blocker == nil)
        #expect(!manifest.audit.blockers.contains(.noProfessionalCoachCalibration))
        #expect(manifest.audit.blockers.contains(.noLiveProviderTranscriptSweep))
        #expect(manifest.audit.blockers.contains(.noRealUserLongitudinalTransferOutcomes))
        #expect(manifest.audit.score == 20)
        #expect(manifest.audit.maximumAllowedScore == 20)
        #expect(!manifest.audit.productionReady)
    }

    @MainActor
    @Test func productionReadinessManifestIngestsCleanRealUserTransferOutcomesFromArtifactDirectory() async throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let transferOutcomes = Self.realUserTransferOutcomeEvidence()
        try transferOutcomes.encodedSortedJSON().write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.realUserTransferOutcomesArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        let manifest = try Self.productionReadinessEvidenceManifestFromCurrentArtifacts(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachRealUserTransferManifest.\(UUID().uuidString)")!
        )
        let rowsByKey = Dictionary(uniqueKeysWithValues: manifest.rows.map { ($0.key, $0) })

        #expect(manifest.evidence.realUserLongitudinalOutcomeCount == 12)
        #expect(rowsByKey["realUserLongitudinalTransferOutcomes"]?.status == .earned)
        #expect(rowsByKey["realUserLongitudinalTransferOutcomes"]?.blocker == nil)
        #expect(!manifest.audit.blockers.contains(.noRealUserLongitudinalTransferOutcomes))
        #expect(manifest.audit.blockers.contains(.noLiveProviderTranscriptSweep))
        #expect(manifest.audit.blockers.contains(.noProfessionalCoachCalibration))
        #expect(manifest.audit.score == 20)
        #expect(manifest.audit.maximumAllowedScore == 20)
        #expect(!manifest.audit.productionReady)
    }

    @MainActor
    @Test func productionReadinessManifestIngestsCleanRealDeviceTestFlightFromArtifactDirectory() async throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let deviceEvidence = Self.realDeviceTestFlightEvidence()
        try deviceEvidence.encodedSortedJSON().write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.realDeviceTestFlightArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        let manifest = try Self.productionReadinessEvidenceManifestFromCurrentArtifacts(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachRealDeviceManifest.\(UUID().uuidString)")!
        )
        let rowsByKey = Dictionary(uniqueKeysWithValues: manifest.rows.map { ($0.key, $0) })

        #expect(manifest.evidence.realDeviceTestFlightVerified)
        #expect(rowsByKey["realDeviceTestFlightVerification"]?.status == .earned)
        #expect(rowsByKey["realDeviceTestFlightVerification"]?.blocker == nil)
        #expect(!manifest.audit.blockers.contains(.noRealDeviceTestFlightVerification))
        #expect(manifest.audit.blockers.contains(.noLiveProviderTranscriptSweep))
        #expect(manifest.audit.blockers.contains(.noProfessionalCoachCalibration))
        #expect(manifest.audit.blockers.contains(.noRealUserLongitudinalTransferOutcomes))
        #expect(manifest.audit.score == 20)
        #expect(manifest.audit.maximumAllowedScore == 20)
        #expect(!manifest.audit.productionReady)
    }

    @MainActor
    @Test func productionReadinessManifestIngestsCleanOperationalLaunchChecklistFromArtifactDirectory() async throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let checklist = Self.operationalLaunchChecklistEvidence()
        try checklist.encodedSortedJSON().write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.operationalLaunchChecklistArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        let manifest = try Self.productionReadinessEvidenceManifestFromCurrentArtifacts(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachOperationalLaunchManifest.\(UUID().uuidString)")!
        )
        let rowsByKey = Dictionary(uniqueKeysWithValues: manifest.rows.map { ($0.key, $0) })

        #expect(manifest.evidence.operationalLaunchChecklistComplete)
        #expect(rowsByKey["operationalLaunchChecklist"]?.status == .earned)
        #expect(rowsByKey["operationalLaunchChecklist"]?.blocker == nil)
        #expect(!manifest.audit.blockers.contains(.operationalLaunchChecklistIncomplete))
        #expect(manifest.audit.blockers.contains(.noLiveProviderTranscriptSweep))
        #expect(manifest.audit.blockers.contains(.noProfessionalCoachCalibration))
        #expect(manifest.audit.blockers.contains(.noRealUserLongitudinalTransferOutcomes))
        #expect(manifest.audit.score == 20)
        #expect(manifest.audit.maximumAllowedScore == 20)
        #expect(!manifest.audit.productionReady)
    }

    @Test func liveProviderSweepEvidenceRequiresCleanRunReadinessFloor() throws {
        let warningSweep = Self.liveProviderSweepEvidence(
            passesRunReadinessFloor: false,
            readinessWarnings: ["flatAssessmentConfidence"]
        )
        let warningDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: warningSweep.encodedSortedJSON()
        )

        #expect(!warningDecoded.qualifiesForReadiness)
        #expect(warningDecoded.rowsPassingReadinessFloor == 0)
        #expect(warningDecoded.rejectionReasons.contains("passesRunReadinessFloor=false"))
        #expect(warningDecoded.rejectionReasons.contains("readinessWarnings=flatAssessmentConfidence"))

        let failingSweep = Self.liveProviderSweepEvidence(
            failingRowIndices: [2]
        )
        let failingDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: failingSweep.encodedSortedJSON()
        )
        #expect(!failingDecoded.qualifiesForReadiness)
        #expect(failingDecoded.rowsPassingReadinessFloor == 0)
        #expect(failingDecoded.rejectionReasons.contains("productionFloorFailures"))
    }

    @Test func liveProviderSweepEvidenceRequiresLatestFixtureCoverage() throws {
        let partialSweep = Self.liveProviderSweepEvidence(
            fixtureIDs: Array(CoachLiveProviderSweepEvidence.requiredFixtureIDs.prefix(10))
        )
        let partialDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: partialSweep.encodedSortedJSON()
        )

        #expect(!partialDecoded.qualifiesForReadiness)
        #expect(partialDecoded.rowsPassingReadinessFloor == 0)
        #expect(partialDecoded.rejectionReasons.contains("missingLatestTranscriptCoverage"))
        #expect(partialDecoded.rejectionReasons.contains { reason in
            reason.hasPrefix("missingRequiredFixtures=")
        })

        let duplicateFixtureIDs = Array(repeating: CoachLiveProviderSweepEvidence.requiredFixtureIDs[0],
                                        count: CoachLiveProviderSweepEvidence.requiredFixtureIDs.count)
        let duplicateSweep = Self.liveProviderSweepEvidence(
            fixtureIDs: duplicateFixtureIDs
        )
        let duplicateDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: duplicateSweep.encodedSortedJSON()
        )

        #expect(!duplicateDecoded.qualifiesForReadiness)
        #expect(duplicateDecoded.rejectionReasons.contains("duplicateFixtureIDs"))
        #expect(duplicateDecoded.rejectionReasons.contains { reason in
            reason.hasPrefix("missingRequiredFixtures=")
        })
    }

    @Test func liveProviderSweepEvidenceRequiresLongFormConversationCoverage() throws {
        let partialLongFormSweep = Self.liveProviderSweepEvidence(
            longFormConversationIDsPassingProductionFloor: Array(
                CoachLiveProviderSweepEvidence.requiredLongFormConversationIDs.prefix(5)
            )
        )
        let partialDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: partialLongFormSweep.encodedSortedJSON()
        )

        #expect(!partialDecoded.qualifiesForReadiness)
        #expect(partialDecoded.rowsPassingReadinessFloor == 0)
        #expect(partialDecoded.rejectionReasons.contains("missingLiveLongFormConversationCoverage"))
        #expect(partialDecoded.rejectionReasons.contains { reason in
            reason.hasPrefix("missingRequiredLongFormConversations=")
        })

        let failedLongFormSweep = Self.liveProviderSweepEvidence(
            longFormConversationIDsPassingProductionFloor: Array(
                CoachLiveProviderSweepEvidence.requiredLongFormConversationIDs.dropLast()
            ),
            longFormConversationFailureIDs: [
                CoachLiveProviderSweepEvidence.requiredLongFormConversationIDs.last ?? "missing-long-form-id"
            ]
        )
        let failedDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: failedLongFormSweep.encodedSortedJSON()
        )

        #expect(!failedDecoded.qualifiesForReadiness)
        #expect(failedDecoded.rejectionReasons.contains { reason in
            reason.hasPrefix("longFormConversationFailures=")
        })
    }

    @Test func liveProviderSweepEvidenceRequiresTurnDepthAndJudgementVariety() throws {
        let shallowSweep = Self.liveProviderSweepEvidence(
            turnDepths: Array(
                repeating: CoachTurnDepth.groundedRead.rawValue,
                count: CoachLiveProviderSweepEvidence.requiredFixtureIDs.count
            ),
            confidenceDistinctRoundedCount: 1,
            uniqueProofTestHashCount: 1,
            repeatedProofTestHashCount: 4
        )
        let decoded = try CoachLiveProviderSweepEvidence.decode(
            from: shallowSweep.encodedSortedJSON()
        )

        #expect(!decoded.qualifiesForReadiness)
        #expect(decoded.rowsPassingReadinessFloor == 0)
        #expect(decoded.rejectionReasons.contains { reason in
            reason.hasPrefix("missingTurnDepthCoverage=")
        })
        #expect(decoded.rejectionReasons.contains("flatAssessmentConfidence"))
        #expect(decoded.rejectionReasons.contains("weakProofTestVariety"))
    }

    @Test func liveProviderSweepLoaderReturnsNilWhenSidecarIsMissing() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let loaded = try Self.liveProviderSweepEvidenceIfAvailable(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachLiveProviderSweepLoader.\(UUID().uuidString)")!
        )

        #expect(loaded == nil)
    }

    @Test func liveProviderSweepLoaderReadsSidecarFromDumpDirectory() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sweep = Self.liveProviderSweepEvidence()
        try sweep.encodedSortedJSON().write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.liveProviderSweepArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        let loaded = try Self.liveProviderSweepEvidenceIfAvailable(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachLiveProviderSweepLoader.\(UUID().uuidString)")!
        )

        #expect(loaded?.qualifiesForReadiness == true)
        #expect(
            loaded?.rowsPassingReadinessFloor ==
                CoachLiveProviderSweepEvidence.requiredReadinessEvidenceCount
        )
        #expect(loaded?.providerChain == ["Gemini (gemini-test)"])
    }

    @Test func liveProviderSweepLoaderSurfacesMalformedSidecar() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try "{".write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.liveProviderSweepArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        do {
            _ = try Self.liveProviderSweepEvidenceIfAvailable(
                environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
                arguments: [],
                defaults: UserDefaults(suiteName: "CoachLiveProviderSweepLoader.\(UUID().uuidString)")!
            )
            Issue.record("Malformed live-provider sidecar should fail loudly.")
        } catch {
            #expect(String(describing: error).isEmpty == false)
        }
    }

    @Test func professionalCalibrationEvidenceRequiresUsableExpertRows() throws {
        let warningEvidence = Self.professionalCalibrationEvidence(
            readinessWarnings: ["reviewerDisagreement"]
        )
        let warningDecoded = try CoachProfessionalCalibrationEvidence.decode(
            from: warningEvidence.encodedSortedJSON()
        )

        #expect(!warningDecoded.qualifiesForReadiness)
        #expect(warningDecoded.rowsPassingCalibrationFloor == 0)
        #expect(warningDecoded.rejectionReasons.contains("readinessWarnings=reviewerDisagreement"))

        let rejectedEvidence = Self.professionalCalibrationEvidence(
            rejectedRowIndices: Set(0..<13),
            rejectionDecision: "expertBetter"
        )
        let rejectedDecoded = try CoachProfessionalCalibrationEvidence.decode(
            from: rejectedEvidence.encodedSortedJSON()
        )

        #expect(!rejectedDecoded.qualifiesForReadiness)
        #expect(rejectedDecoded.rowsPassingCalibrationFloor == 0)
        #expect(rejectedDecoded.rejectionReasons.contains("insufficientPassingCalibrationRows"))
        #expect(rejectedDecoded.rejectionReasons.contains("rowCalibrationFloorFailures"))
    }

    @Test func professionalCalibrationEvidenceRequiresFullConversationCoverage() throws {
        let partialEvidence = Self.professionalCalibrationEvidence(
            conversationIDs: Array(CoachProfessionalCalibrationEvidence.requiredConversationIDs.prefix(10))
        )
        let partialDecoded = try CoachProfessionalCalibrationEvidence.decode(
            from: partialEvidence.encodedSortedJSON()
        )

        #expect(!partialDecoded.qualifiesForReadiness)
        #expect(partialDecoded.rowsPassingCalibrationFloor == 0)
        #expect(partialDecoded.rejectionReasons.contains("missingFullConversationCoverage"))
        #expect(partialDecoded.rejectionReasons.contains { reason in
            reason.hasPrefix("missingRequiredConversations=")
        })

        let unexpectedEvidence = Self.professionalCalibrationEvidence(
            conversationIDs: Array(CoachProfessionalCalibrationEvidence.requiredConversationIDs.dropFirst()) +
                ["outside-current-calibration-packet"]
        )
        let unexpectedDecoded = try CoachProfessionalCalibrationEvidence.decode(
            from: unexpectedEvidence.encodedSortedJSON()
        )

        #expect(!unexpectedDecoded.qualifiesForReadiness)
        #expect(unexpectedDecoded.rejectionReasons.contains { reason in
            reason.hasPrefix("missingRequiredConversations=")
        })
        #expect(unexpectedDecoded.rejectionReasons.contains { reason in
            reason.hasPrefix("unexpectedConversationIDs=")
        })
    }

    @Test func professionalCalibrationEvidenceRequiresReviewerCoherenceAndResolvedRevisions() throws {
        let reviewerMismatchEvidence = Self.professionalCalibrationEvidence(
            summaryReviewerCount: 2
        )
        let reviewerMismatchDecoded = try CoachProfessionalCalibrationEvidence.decode(
            from: reviewerMismatchEvidence.encodedSortedJSON()
        )

        #expect(!reviewerMismatchDecoded.qualifiesForReadiness)
        #expect(reviewerMismatchDecoded.rejectionReasons.contains("missingProfessionalReviewer"))

        let missingReviewerEvidence = Self.professionalCalibrationEvidence(
            reviewerIDs: [""]
        )
        let missingReviewerDecoded = try CoachProfessionalCalibrationEvidence.decode(
            from: missingReviewerEvidence.encodedSortedJSON()
        )

        #expect(!missingReviewerDecoded.qualifiesForReadiness)
        #expect(missingReviewerDecoded.rejectionReasons.contains("missingProfessionalReviewer"))

        let unresolvedRevisionEvidence = Self.professionalCalibrationEvidence(
            revisionNoteIndices: [0]
        )
        let unresolvedRevisionDecoded = try CoachProfessionalCalibrationEvidence.decode(
            from: unresolvedRevisionEvidence.encodedSortedJSON()
        )

        #expect(!unresolvedRevisionDecoded.qualifiesForReadiness)
        #expect(unresolvedRevisionDecoded.rejectionReasons.contains("unresolvedRevisionNotes"))
    }

    @Test func professionalCalibrationLoaderReturnsNilWhenSidecarIsMissing() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let loaded = try Self.professionalCalibrationEvidenceIfAvailable(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachProfessionalCalibrationLoader.\(UUID().uuidString)")!
        )

        #expect(loaded == nil)
    }

    @Test func professionalCalibrationLoaderReadsSidecarFromDumpDirectory() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let calibration = Self.professionalCalibrationEvidence()
        try calibration.encodedSortedJSON().write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.professionalCoachCalibrationResultsArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        let loaded = try Self.professionalCalibrationEvidenceIfAvailable(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachProfessionalCalibrationLoader.\(UUID().uuidString)")!
        )

        #expect(loaded?.qualifiesForReadiness == true)
        #expect(
            loaded?.rowsPassingCalibrationFloor ==
                CoachProfessionalCalibrationEvidence.requiredConversationIDs.count
        )
        #expect(loaded?.reviewerRole == "professionalCommunicationCoach")
    }

    @Test func professionalCalibrationLoaderSurfacesMalformedSidecar() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try "{".write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.professionalCoachCalibrationResultsArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        do {
            _ = try Self.professionalCalibrationEvidenceIfAvailable(
                environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
                arguments: [],
                defaults: UserDefaults(suiteName: "CoachProfessionalCalibrationLoader.\(UUID().uuidString)")!
            )
            Issue.record("Malformed professional calibration sidecar should fail loudly.")
        } catch {
            #expect(String(describing: error).isEmpty == false)
        }
    }

    @Test func realUserTransferOutcomeEvidenceRequiresLongitudinalUsableRows() throws {
        let warningEvidence = Self.realUserTransferOutcomeEvidence(
            readinessWarnings: ["insufficientFollowUpWindow"]
        )
        let warningDecoded = try CoachRealUserTransferOutcomeEvidence.decode(
            from: warningEvidence.encodedSortedJSON()
        )

        #expect(!warningDecoded.qualifiesForReadiness)
        #expect(warningDecoded.rowsPassingOutcomeFloor == 0)
        #expect(warningDecoded.rejectionReasons.contains("readinessWarnings=insufficientFollowUpWindow"))

        let rejectedEvidence = Self.realUserTransferOutcomeEvidence(
            rejectedRowIndices: [0, 1, 2]
        )
        let rejectedDecoded = try CoachRealUserTransferOutcomeEvidence.decode(
            from: rejectedEvidence.encodedSortedJSON()
        )

        #expect(!rejectedDecoded.qualifiesForReadiness)
        #expect(rejectedDecoded.rowsPassingOutcomeFloor == 0)
        #expect(rejectedDecoded.rejectionReasons.contains("insufficientPositiveTransferOutcomes"))
        #expect(rejectedDecoded.rejectionReasons.contains("insufficientAudienceResponseEvidence"))
        #expect(rejectedDecoded.rejectionReasons.contains("adverseOutcomesReported"))
        #expect(rejectedDecoded.rejectionReasons.contains("outcomeFloorFailures"))
    }

    @Test func realUserTransferOutcomeLoaderReturnsNilWhenSidecarIsMissing() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let loaded = try Self.realUserTransferOutcomeEvidenceIfAvailable(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachRealUserTransferLoader.\(UUID().uuidString)")!
        )

        #expect(loaded == nil)
    }

    @Test func realUserTransferOutcomeLoaderReadsSidecarFromDumpDirectory() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let transferOutcomes = Self.realUserTransferOutcomeEvidence()
        try transferOutcomes.encodedSortedJSON().write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.realUserTransferOutcomesArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        let loaded = try Self.realUserTransferOutcomeEvidenceIfAvailable(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachRealUserTransferLoader.\(UUID().uuidString)")!
        )

        #expect(loaded?.qualifiesForReadiness == true)
        #expect(loaded?.rowsPassingOutcomeFloor == 12)
        #expect(loaded?.cohortDescription == "closed-beta-transfer-cohort")
    }

    @Test func realUserTransferOutcomeLoaderSurfacesMalformedSidecar() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try "{".write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.realUserTransferOutcomesArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        do {
            _ = try Self.realUserTransferOutcomeEvidenceIfAvailable(
                environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
                arguments: [],
                defaults: UserDefaults(suiteName: "CoachRealUserTransferLoader.\(UUID().uuidString)")!
            )
            Issue.record("Malformed real-user transfer outcome sidecar should fail loudly.")
        } catch {
            #expect(String(describing: error).isEmpty == false)
        }
    }

    @Test func realDeviceTestFlightEvidenceRequiresAllHighRiskSurfaces() throws {
        let warningEvidence = Self.realDeviceTestFlightEvidence(
            readinessWarnings: ["manualTesterNotesMissing"]
        )
        let warningDecoded = try CoachRealDeviceTestFlightEvidence.decode(
            from: warningEvidence.encodedSortedJSON()
        )

        #expect(!warningDecoded.qualifiesForReadiness)
        #expect(warningDecoded.rejectionReasons.contains("readinessWarnings=manualTesterNotesMissing"))

        let rejectedEvidence = Self.realDeviceTestFlightEvidence(
            failingSurfaceKeys: ["liveActivity", "paywallPurchase"]
        )
        let rejectedDecoded = try CoachRealDeviceTestFlightEvidence.decode(
            from: rejectedEvidence.encodedSortedJSON()
        )

        #expect(!rejectedDecoded.qualifiesForReadiness)
        #expect(rejectedDecoded.rejectionReasons.contains("surfaceFloorFailures"))
        #expect(rejectedDecoded.rejectionReasons.contains("blockingIssuesPresent"))
        #expect(rejectedDecoded.rejectionReasons.contains("rowSurfaceFloorFailures"))
    }

    @Test func realDeviceTestFlightLoaderReturnsNilWhenSidecarIsMissing() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let loaded = try Self.realDeviceTestFlightEvidenceIfAvailable(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachRealDeviceLoader.\(UUID().uuidString)")!
        )

        #expect(loaded == nil)
    }

    @Test func realDeviceTestFlightLoaderReadsSidecarFromDumpDirectory() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let deviceEvidence = Self.realDeviceTestFlightEvidence()
        try deviceEvidence.encodedSortedJSON().write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.realDeviceTestFlightArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        let loaded = try Self.realDeviceTestFlightEvidenceIfAvailable(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachRealDeviceLoader.\(UUID().uuidString)")!
        )

        #expect(loaded?.qualifiesForReadiness == true)
        #expect(loaded?.summary.passedRequiredSurfaceCount == 4)
        #expect(loaded?.deviceModel == "iPhone 15 Pro")
    }

    @Test func realDeviceTestFlightLoaderSurfacesMalformedSidecar() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try "{".write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.realDeviceTestFlightArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        do {
            _ = try Self.realDeviceTestFlightEvidenceIfAvailable(
                environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
                arguments: [],
                defaults: UserDefaults(suiteName: "CoachRealDeviceLoader.\(UUID().uuidString)")!
            )
            Issue.record("Malformed real-device TestFlight sidecar should fail loudly.")
        } catch {
            #expect(String(describing: error).isEmpty == false)
        }
    }

    @Test func operationalLaunchChecklistEvidenceRequiresCompletedM14Items() throws {
        let warningEvidence = Self.operationalLaunchChecklistEvidence(
            readinessWarnings: ["privacyLabelReviewStale"]
        )
        let warningDecoded = try CoachOperationalLaunchChecklistEvidence.decode(
            from: warningEvidence.encodedSortedJSON()
        )

        #expect(!warningDecoded.qualifiesForReadiness)
        #expect(warningDecoded.rejectionReasons.contains("readinessWarnings=privacyLabelReviewStale"))

        let rejectedEvidence = Self.operationalLaunchChecklistEvidence(
            failingItemKeys: ["firestoreRulesDeployed", "privacyPolicyURLHosted"]
        )
        let rejectedDecoded = try CoachOperationalLaunchChecklistEvidence.decode(
            from: rejectedEvidence.encodedSortedJSON()
        )

        #expect(!rejectedDecoded.qualifiesForReadiness)
        #expect(rejectedDecoded.rejectionReasons.contains("incompleteRequiredItems"))
        #expect(rejectedDecoded.rejectionReasons.contains("failedRequiredItems"))
    }

    @Test func operationalLaunchChecklistLoaderReturnsNilWhenSidecarIsMissing() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let loaded = try Self.operationalLaunchChecklistEvidenceIfAvailable(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachOperationalLaunchLoader.\(UUID().uuidString)")!
        )

        #expect(loaded == nil)
    }

    @Test func operationalLaunchChecklistLoaderReadsSidecarFromDumpDirectory() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let checklist = Self.operationalLaunchChecklistEvidence()
        try checklist.encodedSortedJSON().write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.operationalLaunchChecklistArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        let loaded = try Self.operationalLaunchChecklistEvidenceIfAvailable(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachOperationalLaunchLoader.\(UUID().uuidString)")!
        )

        #expect(loaded?.qualifiesForReadiness == true)
        #expect(loaded?.summary.completedRequiredItemCount == 6)
        #expect(loaded?.releaseCandidateBuild == "2026.06.30.1")
    }

    @Test func operationalLaunchChecklistLoaderSurfacesMalformedSidecar() throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try "{".write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.operationalLaunchChecklistArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        do {
            _ = try Self.operationalLaunchChecklistEvidenceIfAvailable(
                environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
                arguments: [],
                defaults: UserDefaults(suiteName: "CoachOperationalLaunchLoader.\(UUID().uuidString)")!
            )
            Issue.record("Malformed operational launch checklist sidecar should fail loudly.")
        } catch {
            #expect(String(describing: error).isEmpty == false)
        }
    }

    @MainActor
    @Test func productionReadinessManifestCountsOnlyCleanLiveProviderSweepArtifact() async throws {
        let conversationReport = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.conversations
        )
        let longFormConversationReport = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.longFormConversations,
            schemaVersion: CoachChatConversationCorpus.longFormReportSchemaVersion
        )
        let expertPacket = CoachChatConversationExpertCalibrationPacket.make(
            from: CoachChatConversationCorpus.professionalCalibrationConversations
        )
        let textAppPathReport = Self.cleanAppPathReport(
            surface: .text,
            schemaVersion: CoachChatConversationCorpus.appPathReportSchemaVersion,
            localTargetShapeScore: conversationReport.visionProductionReadiness.localTargetShapeScore
        )
        let liveAppPathReport = Self.cleanAppPathReport(
            surface: .live,
            schemaVersion: CoachChatConversationCorpus.liveAppPathReportSchemaVersion,
            localTargetShapeScore: conversationReport.visionProductionReadiness.localTargetShapeScore
        )
        let cleanSweep = Self.liveProviderSweepEvidence()
        let manifest = CoachVisionProductionReadinessEvidenceManifest.make(
            conversationReport: conversationReport,
            longFormConversationReport: longFormConversationReport,
            expertPacket: expertPacket,
            textAppPathReport: textAppPathReport,
            liveAppPathReport: liveAppPathReport,
            liveProviderSweep: cleanSweep
        )

        let rowsByKey = Dictionary(uniqueKeysWithValues: manifest.rows.map { ($0.key, $0) })
        #expect(rowsByKey["adversarialNegativeControlCorpus"]?.status == .missing)
        #expect(rowsByKey["adversarialNegativeControlCorpus"]?.observedCount == 0)
        #expect(rowsByKey["adversarialNegativeControlCorpus"]?.blocker == nil)
        #expect(
            manifest.evidence.liveProviderRowsPassingFloor ==
                CoachLiveProviderSweepEvidence.requiredReadinessEvidenceCount
        )
        #expect(rowsByKey["liveProviderTranscriptSweep"]?.status == .earned)
        #expect(rowsByKey["liveProviderTranscriptSweep"]?.blocker == nil)
        #expect(!manifest.audit.blockers.contains(.noLiveProviderTranscriptSweep))
        #expect(manifest.audit.blockers.contains(.noProfessionalCoachCalibration))
        #expect(manifest.audit.blockers.contains(.noRealUserLongitudinalTransferOutcomes))
        #expect(manifest.audit.score == 20)
        #expect(manifest.audit.maximumAllowedScore == 20)
        #expect(!manifest.audit.productionReady)

        let rejectedSweep = Self.liveProviderSweepEvidence(
            passesRunReadinessFloor: false,
            readinessWarnings: ["uniformReplyWordCount"]
        )
        let rejectedManifest = CoachVisionProductionReadinessEvidenceManifest.make(
            conversationReport: conversationReport,
            longFormConversationReport: longFormConversationReport,
            expertPacket: expertPacket,
            textAppPathReport: textAppPathReport,
            liveAppPathReport: liveAppPathReport,
            liveProviderSweep: rejectedSweep
        )
        let rejectedRowsByKey = Dictionary(uniqueKeysWithValues: rejectedManifest.rows.map { ($0.key, $0) })
        #expect(rejectedManifest.evidence.liveProviderRowsPassingFloor == 0)
        #expect(rejectedRowsByKey["liveProviderTranscriptSweep"]?.status == .missing)
        #expect(rejectedRowsByKey["liveProviderTranscriptSweep"]?.blocker == .noLiveProviderTranscriptSweep)
        #expect(rejectedRowsByKey["liveProviderTranscriptSweep"]?.notes.contains("rejected") == true)
        #expect(rejectedManifest.audit.blockers.contains(.noLiveProviderTranscriptSweep))
        #expect(rejectedManifest.audit.score == 18)
    }

    @Test func evaluationArtifactDumpDirectoryReadsXcodeAndSimulatorInputs() {
        let suiteName = "CoachChatConversationArtifactDump.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        #expect(Self.evaluationArtifactDumpDirectory(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": " /tmp/noum-env "],
            arguments: [],
            defaults: defaults
        ) == "/tmp/noum-env")
        #expect(Self.evaluationArtifactDumpDirectory(
            environment: ["SIMCTL_CHILD_NOUM_COACH_EVAL_DUMP_DIR": "/tmp/noum-simctl"],
            arguments: [],
            defaults: defaults
        ) == "/tmp/noum-simctl")
        #expect(Self.evaluationArtifactDumpDirectory(
            environment: [:],
            arguments: ["NoumTests", "-NOUM_COACH_EVAL_DUMP_DIR", "/tmp/noum-args"],
            defaults: defaults
        ) == "/tmp/noum-args")
        #expect(Self.evaluationArtifactDumpDirectory(
            environment: [:],
            arguments: ["NoumTests", "NOUM_COACH_EVAL_DUMP_DIR=/tmp/noum-inline"],
            defaults: defaults
        ) == "/tmp/noum-inline")

        defaults.set("/tmp/noum-defaults", forKey: "NOUM_COACH_EVAL_DUMP_DIR")
        #expect(Self.evaluationArtifactDumpDirectory(
            environment: [:],
            arguments: [],
            defaults: defaults
        ) == "/tmp/noum-defaults")

        defaults.removeObject(forKey: "NOUM_COACH_EVAL_DUMP_DIR")
        #expect(Self.evaluationArtifactDumpDirectory(
            environment: [:],
            arguments: [],
            defaults: defaults
        )?.hasSuffix("/noum-coach-eval") == true)
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

    private static func dumpEvaluationArtifactIfRequested(
        _ json: String,
        fileName: String
    ) throws {
        guard let directory = evaluationArtifactDumpDirectory() else { return }

        let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try json.write(
            to: directoryURL.appendingPathComponent(fileName),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func liveProviderSweepEvidenceIfAvailable(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard
    ) throws -> CoachLiveProviderSweepEvidence? {
        guard let directory = evaluationArtifactDumpDirectory(
            environment: environment,
            arguments: arguments,
            defaults: defaults
        ) else {
            return nil
        }
        let sidecarURL = URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent(CoachChatConversationCorpus.liveProviderSweepArtifactFileName)
        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            return nil
        }
        let json = try String(contentsOf: sidecarURL, encoding: .utf8)
        return try CoachLiveProviderSweepEvidence.decode(from: json)
    }

    private static func professionalCalibrationEvidenceIfAvailable(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard
    ) throws -> CoachProfessionalCalibrationEvidence? {
        guard let directory = evaluationArtifactDumpDirectory(
            environment: environment,
            arguments: arguments,
            defaults: defaults
        ) else {
            return nil
        }
        let sidecarURL = URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent(
                CoachChatConversationCorpus.professionalCoachCalibrationResultsArtifactFileName
            )
        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            return nil
        }
        let json = try String(contentsOf: sidecarURL, encoding: .utf8)
        return try CoachProfessionalCalibrationEvidence.decode(from: json)
    }

    private static func realUserTransferOutcomeEvidenceIfAvailable(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard
    ) throws -> CoachRealUserTransferOutcomeEvidence? {
        guard let directory = evaluationArtifactDumpDirectory(
            environment: environment,
            arguments: arguments,
            defaults: defaults
        ) else {
            return nil
        }
        let sidecarURL = URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent(
                CoachChatConversationCorpus.realUserTransferOutcomesArtifactFileName
            )
        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            return nil
        }
        let json = try String(contentsOf: sidecarURL, encoding: .utf8)
        return try CoachRealUserTransferOutcomeEvidence.decode(from: json)
    }

    private static func realDeviceTestFlightEvidenceIfAvailable(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard
    ) throws -> CoachRealDeviceTestFlightEvidence? {
        guard let directory = evaluationArtifactDumpDirectory(
            environment: environment,
            arguments: arguments,
            defaults: defaults
        ) else {
            return nil
        }
        let sidecarURL = URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent(
                CoachChatConversationCorpus.realDeviceTestFlightArtifactFileName
            )
        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            return nil
        }
        let json = try String(contentsOf: sidecarURL, encoding: .utf8)
        return try CoachRealDeviceTestFlightEvidence.decode(from: json)
    }

    private static func operationalLaunchChecklistEvidenceIfAvailable(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard
    ) throws -> CoachOperationalLaunchChecklistEvidence? {
        guard let directory = evaluationArtifactDumpDirectory(
            environment: environment,
            arguments: arguments,
            defaults: defaults
        ) else {
            return nil
        }
        let sidecarURL = URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent(
                CoachChatConversationCorpus.operationalLaunchChecklistArtifactFileName
            )
        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            return nil
        }
        let json = try String(contentsOf: sidecarURL, encoding: .utf8)
        return try CoachOperationalLaunchChecklistEvidence.decode(from: json)
    }

    private static func productionReadinessEvidenceManifestFromCurrentArtifacts(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard
    ) throws -> CoachVisionProductionReadinessEvidenceManifest {
        let conversationReport = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.conversations
        )
        let longFormConversationReport = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.longFormConversations,
            schemaVersion: CoachChatConversationCorpus.longFormReportSchemaVersion
        )
        let adversarialConversationReport = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.longFormAdversarialConversations,
            schemaVersion: CoachChatConversationCorpus.longFormAdversarialReportSchemaVersion
        )
        let expertPacket = CoachChatConversationExpertCalibrationPacket.make(
            from: CoachChatConversationCorpus.professionalCalibrationConversations
        )
        let textAppPathReport = Self.cleanAppPathReport(
            surface: .text,
            schemaVersion: CoachChatConversationCorpus.appPathReportSchemaVersion,
            localTargetShapeScore: conversationReport.visionProductionReadiness.localTargetShapeScore
        )
        let liveAppPathReport = Self.cleanAppPathReport(
            surface: .live,
            schemaVersion: CoachChatConversationCorpus.liveAppPathReportSchemaVersion,
            localTargetShapeScore: conversationReport.visionProductionReadiness.localTargetShapeScore
        )
        let liveProviderSweep = try Self.liveProviderSweepEvidenceIfAvailable(
            environment: environment,
            arguments: arguments,
            defaults: defaults
        )
        let professionalCalibration = try Self.professionalCalibrationEvidenceIfAvailable(
            environment: environment,
            arguments: arguments,
            defaults: defaults
        )
        let realUserTransferOutcomes = try Self.realUserTransferOutcomeEvidenceIfAvailable(
            environment: environment,
            arguments: arguments,
            defaults: defaults
        )
        let realDeviceTestFlight = try Self.realDeviceTestFlightEvidenceIfAvailable(
            environment: environment,
            arguments: arguments,
            defaults: defaults
        )
        let operationalLaunchChecklist = try Self.operationalLaunchChecklistEvidenceIfAvailable(
            environment: environment,
            arguments: arguments,
            defaults: defaults
        )
        return CoachVisionProductionReadinessEvidenceManifest.make(
            conversationReport: conversationReport,
            longFormConversationReport: longFormConversationReport,
            adversarialConversationReport: adversarialConversationReport,
            expertPacket: expertPacket,
            textAppPathReport: textAppPathReport,
            liveAppPathReport: liveAppPathReport,
            liveProviderSweep: liveProviderSweep,
            professionalCalibration: professionalCalibration,
            realUserTransferOutcomes: realUserTransferOutcomes,
            realDeviceTestFlight: realDeviceTestFlight,
            operationalLaunchChecklist: operationalLaunchChecklist
        )
    }

    private static func evaluationArtifactDumpDirectory(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard
    ) -> String? {
        if let directory = trimmedNonEmpty(environment["NOUM_COACH_EVAL_DUMP_DIR"]) {
            return directory
        }
        if let directory = trimmedNonEmpty(environment["SIMCTL_CHILD_NOUM_COACH_EVAL_DUMP_DIR"]) {
            return directory
        }
        if let flagIndex = arguments.firstIndex(of: "-NOUM_COACH_EVAL_DUMP_DIR") {
            let valueIndex = arguments.index(after: flagIndex)
            if valueIndex < arguments.endIndex,
               let directory = trimmedNonEmpty(arguments[valueIndex]) {
                return directory
            }
        }
        for argument in arguments {
            if let directory = inlineDumpDirectoryArgument(argument) {
                return directory
            }
        }
        return trimmedNonEmpty(defaults.string(forKey: "NOUM_COACH_EVAL_DUMP_DIR")) ??
            defaultEvaluationArtifactDumpDirectory()
    }

    private static func inlineDumpDirectoryArgument(_ argument: String) -> String? {
        let prefixes = [
            "NOUM_COACH_EVAL_DUMP_DIR=",
            "-NOUM_COACH_EVAL_DUMP_DIR="
        ]
        for prefix in prefixes where argument.hasPrefix(prefix) {
            return trimmedNonEmpty(String(argument.dropFirst(prefix.count)))
        }
        return nil
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func defaultEvaluationArtifactDumpDirectory() -> String {
        "/private/tmp/noum-coach-eval"
    }

    private static func temporaryEvaluationDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NoumCoachEval.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private static func cleanAppPathReport(
        surface: CoachReplySurface,
        schemaVersion: String,
        localTargetShapeScore: Int
    ) -> CoachChatConversationAppPathReport {
        let rows = CoachChatConversationCorpus.conversations.map { conversation in
            var recentTurns: [CoachMessage] = []
            let turns = conversation.turns.enumerated().map { index, turn in
                let sanitizedReply = CoachReplyTextSanitizer.coachReplyText(
                    from: turn.coachReply
                )
                let turnDepth = TurnDepthClassifier.classify(
                    userText: turn.userTurn,
                    recentTurns: recentTurns
                )
                defer {
                    recentTurns.append(CoachMessage(role: .user, text: turn.userTurn))
                    recentTurns.append(CoachMessage(role: .coach, text: sanitizedReply))
                }
                return CoachChatConversationAppPathTurnRow(
                    turnIndex: index,
                    userTurn: turn.userTurn,
                    targetCoachReply: sanitizedReply,
                    finalCoachReply: sanitizedReply,
                    outcomeSucceeded: true,
                    targetReplyMatched: true,
                    metadataPresent: true,
                    turnDepth: turnDepth.rawValue,
                    providerTierRequested: nil,
                    providerTierChosen: nil,
                    providerName: "fixture",
                    providerModel: "clean-app-path-manifest",
                    semanticGateOutcome: "passed",
                    semanticGateIssue: nil,
                    semanticGatePassed: true,
                    qualityGateOutcome: "passed",
                    qualityGateEvents: ["passed"],
                    qualityGateClean: true,
                    qualityGateAcceptedFallback: false,
                    typedAssessmentFallbackApplied: false,
                    qualityGateBlockingFailure: false,
                    reliabilityIssues: [],
                    visionScore: 90,
                    visionPassesProductionFloor: true,
                    immediateCoachReadExpected: surface == .live,
                    immediateCoachReadShown: surface == .live,
                    proofTestHash: "manifest-\(conversation.id)-\(index)",
                    proofTestRecentlyRepeated: false,
                    timeToFirstVisibleTokenMs: surface == .live ? 1 : nil,
                    timeToCompleteReplyMs: 1,
                    passesAppPathFloor: true
                )
            }
            return CoachChatConversationAppPathReportRow.make(
                conversationID: conversation.id,
                sourceFixtureID: conversation.sourceFixtureID,
                turns: turns
            )
        }

        return CoachChatConversationAppPathReport.make(
            rows: rows,
            localTargetShapeScore: localTargetShapeScore,
            schemaVersion: schemaVersion,
            surface: surface
        )
    }

    private static func liveProviderSweepEvidence(
        fixtureIDs: [String] = CoachLiveProviderSweepEvidence.requiredFixtureIDs,
        turnDepths: [String]? = nil,
        passesProductionFloor: Bool = true,
        passesRunReadinessFloor: Bool = true,
        readinessWarnings: [String] = [],
        failingRowIndices: Set<Int> = [],
        confidenceDistinctRoundedCount: Int = 3,
        uniqueProofTestHashCount: Int? = nil,
        repeatedProofTestHashCount: Int = 0,
        longFormConversationIDsPassingProductionFloor: [String] =
            CoachLiveProviderSweepEvidence.requiredLongFormConversationIDs,
        longFormConversationFailureIDs: [String] = []
    ) -> CoachLiveProviderSweepEvidence {
        let rowCount = fixtureIDs.count
        let requiredDepths = CoachLiveProviderSweepEvidence.requiredTurnDepths
        let depths = turnDepths ?? fixtureIDs.indices.map { index in
            requiredDepths[index % requiredDepths.count]
        }
        let rows = fixtureIDs.enumerated().map { index, fixtureID in
            CoachLiveProviderSweepEvidence.Row(
                fixtureID: fixtureID,
                turnDepth: depths.indices.contains(index) ? depths[index] : CoachTurnDepth.groundedRead.rawValue,
                providerChosen: "Gemini",
                providerModel: "gemini-test",
                timeToFirstVisibleTokenMs: 420 + index,
                assessmentConfidence: 0.70 + (Double(index % max(confidenceDistinctRoundedCount, 1)) * 0.03),
                assessmentProofTestHash: "proof-\(index % (uniqueProofTestHashCount ?? rowCount))",
                immediateCoachReadExpected: true,
                immediateCoachReadShown: true,
                liveProductionFloor: !failingRowIndices.contains(index)
            )
        }
        let failureCount = rows.filter { !$0.liveProductionFloor }.count
        let longFormFailureCount = longFormConversationFailureIDs.count
        return CoachLiveProviderSweepEvidence(
            schemaVersion: CoachLiveProviderSweepEvidence.expectedSchemaVersion,
            fixtureCount: rowCount,
            longFormConversationCount: longFormConversationIDsPassingProductionFloor.count +
                longFormFailureCount,
            longFormConversationIDsPassingProductionFloor: longFormConversationIDsPassingProductionFloor,
            longFormConversationFailureIDs: longFormConversationFailureIDs,
            providerChain: ["Gemini (gemini-test)"],
            passesProductionFloor: passesProductionFloor && failureCount == 0 && longFormFailureCount == 0,
            passesRunReadinessFloor: passesRunReadinessFloor &&
                failureCount == 0 &&
                longFormFailureCount == 0 &&
                readinessWarnings.isEmpty,
            summary: CoachLiveProviderSweepEvidence.Summary(
                rowCount: rowCount,
                productionFloorFailureCount: failureCount,
                readinessWarnings: readinessWarnings,
                immediateCoachReadExpectedCount: rowCount,
                immediateCoachReadMissingCount: 0,
                assessmentConfidenceDistinctRoundedCount: confidenceDistinctRoundedCount,
                uniqueProofTestHashCount: uniqueProofTestHashCount ?? rowCount,
                repeatedProofTestHashCount: repeatedProofTestHashCount,
                maxProviderRetryCount: 1,
                totalProviderRefusalCount: 0,
                firstVisibleTokenMaxMs: rowCount > 0 ? 420 + rowCount - 1 : nil
            ),
            rows: rows
        )
    }

    private static func professionalCalibrationEvidence(
        conversationIDs: [String] = CoachProfessionalCalibrationEvidence.requiredConversationIDs,
        readinessWarnings: [String] = [],
        rejectedRowIndices: Set<Int> = [],
        rejectionDecision: String = "unsafeOrUnready",
        reviewerIDs: [String]? = nil,
        summaryReviewerCount: Int? = nil,
        revisionNoteIndices: Set<Int> = []
    ) -> CoachProfessionalCalibrationEvidence {
        let rows = conversationIDs.enumerated().map { index, conversationID in
            let rejected = rejectedRowIndices.contains(index)
            let ratings = CoachProfessionalCalibrationEvidence.Ratings(
                diagnosis: rejected ? 3 : 4,
                caseFormulation: rejected ? 3 : 4,
                intervention: rejected ? 3 : 4,
                adaptation: rejected ? 3 : 4,
                perceptionHonesty: rejected ? 3 : 4,
                transferSetup: rejected ? 3 : 4,
                trustRepair: rejected ? 3 : 4,
                overallUsefulness: rejected ? 3 : 4
            )
            let reviewerID = reviewerIDs?.isEmpty == false
                ? reviewerIDs![index % reviewerIDs!.count]
                : "coach-reviewer-1"
            return CoachProfessionalCalibrationEvidence.Row(
                conversationID: conversationID,
                reviewerID: reviewerID,
                calibrationDecision: rejected ? rejectionDecision : "roughTie",
                wouldUseWithClient: !rejected,
                ratings: ratings,
                humanCoachReferenceCount: rejected ? 0 : 2,
                overclaimNotes: rejected ? ["Too much certainty for the evidence."] : [],
                revisionNotes: rejected || revisionNoteIndices.contains(index)
                    ? ["Needs stronger evidence calibration."]
                    : []
            )
        }
        let rowCount = rows.count
        let passingRows = rows.filter(\.passesCalibrationFloor)
        let wouldUseCount = rows.filter(\.wouldUseWithClient).count
        let unsafeCount = rows.filter { $0.calibrationDecision == "unsafeOrUnready" }.count
        let overallRatings = rows.map(\.ratings.overallUsefulness)
        let averageOverall = overallRatings.isEmpty ? 0 :
            Double(overallRatings.reduce(0, +)) / Double(overallRatings.count)
        let uniqueReviewerIDs = Set(rows.map(\.reviewerID).filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })
        return CoachProfessionalCalibrationEvidence(
            schemaVersion: CoachProfessionalCalibrationEvidence.expectedSchemaVersion,
            sourcePacketSchemaVersion: CoachChatConversationCorpus.expertCalibrationPacketSchemaVersion,
            rubricVersion: CoachProfessionalCalibrationEvidence.expectedRubricVersion,
            reviewerRole: "professionalCommunicationCoach",
            reviewCount: rowCount,
            summary: CoachProfessionalCalibrationEvidence.Summary(
                rowCount: rowCount,
                reviewerCount: summaryReviewerCount ?? uniqueReviewerIDs.count,
                completedReviewCount: rowCount,
                passingCalibrationCount: passingRows.count,
                wouldUseWithClientCount: wouldUseCount,
                unsafeOrUnreadyCount: unsafeCount,
                averageOverallUsefulness: averageOverall,
                minimumOverallUsefulness: overallRatings.min() ?? 0,
                readinessWarnings: readinessWarnings
            ),
            rows: rows
        )
    }

    private static func realUserTransferOutcomeEvidence(
        rowCount: Int = 12,
        readinessWarnings: [String] = [],
        rejectedRowIndices: Set<Int> = []
    ) -> CoachRealUserTransferOutcomeEvidence {
        let rows = (0..<rowCount).map { index in
            let rejected = rejectedRowIndices.contains(index)
            return CoachRealUserTransferOutcomeEvidence.Row(
                outcomeID: "transfer-outcome-\(index)",
                userIDHash: "user-\(index % 6)",
                momentCategory: [
                    "presentation",
                    "interview",
                    "leadership",
                    "conflict"
                ][index % 4],
                realWorldMomentOccurred: !rejected,
                followUpCompleted: !rejected,
                linkedCoachInterventionCount: rejected ? 0 : 2,
                daysSinceFirstNoumSession: rejected ? 3 : 14 + index,
                preMomentConfidence: 2 + (index % 2),
                postMomentConfidence: rejected ? 1 : 3 + (index % 2),
                positiveTransferReported: !rejected,
                audienceResponseEvidenceCollected: !rejected,
                adverseOutcomeReported: rejected,
                causalityClaims: rejected ? ["Noum caused the outcome."] : [],
                notes: rejected ? ["Follow-up did not establish transfer."] : [
                    "User reported the prescribed proof test carried into the real moment."
                ]
            )
        }
        let passingRows = rows.filter(\.passesOutcomeFloor)
        let uniqueUsers = Set(rows.map(\.userIDHash)).count
        let minimumDays = rows.map(\.daysSinceFirstNoumSession).min() ?? 0
        return CoachRealUserTransferOutcomeEvidence(
            schemaVersion: CoachRealUserTransferOutcomeEvidence.expectedSchemaVersion,
            studyProtocolVersion: CoachRealUserTransferOutcomeEvidence.expectedProtocolVersion,
            cohortDescription: "closed-beta-transfer-cohort",
            outcomeCount: rowCount,
            summary: CoachRealUserTransferOutcomeEvidence.Summary(
                rowCount: rowCount,
                uniqueUserCount: uniqueUsers,
                completedFollowUpCount: rows.filter(\.followUpCompleted).count,
                realWorldMomentCount: rows.filter(\.realWorldMomentOccurred).count,
                linkedInterventionOutcomeCount: rows.filter {
                    $0.linkedCoachInterventionCount > 0
                }.count,
                positiveTransferCount: rows.filter(\.positiveTransferReported).count,
                audienceResponseEvidenceCount: rows.filter(\.audienceResponseEvidenceCollected).count,
                noRegressionOutcomeCount: rows.filter {
                    $0.postMomentConfidence >= $0.preMomentConfidence
                }.count,
                adverseOutcomeCount: rows.filter(\.adverseOutcomeReported).count,
                passingOutcomeCount: passingRows.count,
                minimumDaysSinceFirstSession: minimumDays,
                studyDurationDays: rowCount > 0 ? 42 : 0,
                readinessWarnings: readinessWarnings
            ),
            rows: rows
        )
    }

    private static func realDeviceTestFlightEvidence(
        readinessWarnings: [String] = [],
        failingSurfaceKeys: Set<String> = []
    ) -> CoachRealDeviceTestFlightEvidence {
        let rows = CoachRealDeviceTestFlightEvidence.requiredSurfaceKeys.map { key in
            let failed = failingSurfaceKeys.contains(key)
            return CoachRealDeviceTestFlightEvidence.Row(
                surfaceKey: key,
                passed: !failed,
                realDevice: true,
                testFlightBuildInstalled: true,
                evidenceReference: failed ? "" : "testflight://noum/qa/\(key)",
                latencyMs: key == "aiPromptLatency" ? (failed ? 4_200 : 1_850) : nil,
                blockingIssueCount: failed ? 1 : 0,
                notes: failed ? ["Blocking issue observed on \(key)."] : [
                    "Verified on physical device through TestFlight."
                ]
            )
        }
        let requiredKeys = Set(CoachRealDeviceTestFlightEvidence.requiredSurfaceKeys)
        let passedRequiredRows = rows.filter {
            requiredKeys.contains($0.surfaceKey) && $0.passesSurfaceFloor
        }
        let realDeviceRequiredRows = rows.filter {
            requiredKeys.contains($0.surfaceKey) && $0.realDevice
        }
        let testFlightRequiredRows = rows.filter {
            requiredKeys.contains($0.surfaceKey) && $0.testFlightBuildInstalled
        }
        let blockingIssueCount = rows.reduce(0) { $0 + $1.blockingIssueCount }
        return CoachRealDeviceTestFlightEvidence(
            schemaVersion: CoachRealDeviceTestFlightEvidence.expectedSchemaVersion,
            testRunID: "real-device-qa-2026-06-30",
            appVersion: "1.0",
            buildNumber: "2026.06.30.1",
            deviceModel: "iPhone 15 Pro",
            osVersion: "iOS 26.2",
            testerRole: "internalTestFlightQA",
            summary: CoachRealDeviceTestFlightEvidence.Summary(
                rowCount: rows.count,
                requiredSurfaceCount: CoachRealDeviceTestFlightEvidence.requiredSurfaceKeys.count,
                passedRequiredSurfaceCount: passedRequiredRows.count,
                realDeviceSurfaceCount: realDeviceRequiredRows.count,
                testFlightBuildSurfaceCount: testFlightRequiredRows.count,
                blockingIssueCount: blockingIssueCount,
                crashFree: blockingIssueCount == 0,
                readinessWarnings: readinessWarnings
            ),
            rows: rows
        )
    }

    private static func operationalLaunchChecklistEvidence(
        readinessWarnings: [String] = [],
        failingItemKeys: Set<String> = []
    ) -> CoachOperationalLaunchChecklistEvidence {
        let items = CoachOperationalLaunchChecklistEvidence.requiredItemKeys.map { key in
            let failed = failingItemKeys.contains(key)
            return CoachOperationalLaunchChecklistEvidence.Item(
                key: key,
                completed: !failed,
                evidenceReference: failed ? "" : "m14://launch-checklist/\(key)",
                completedAtISO8601: failed ? nil : "2026-06-30T00:00:00Z",
                notes: failed ? ["Required launch item incomplete."] : [
                    "Launch item completed and evidence captured."
                ]
            )
        }
        let requiredKeys = Set(CoachOperationalLaunchChecklistEvidence.requiredItemKeys)
        let completedRequiredItems = items.filter {
            requiredKeys.contains($0.key) && $0.completed
        }
        let failedRequiredItems = items.filter {
            requiredKeys.contains($0.key) && !$0.completed
        }
        return CoachOperationalLaunchChecklistEvidence(
            schemaVersion: CoachOperationalLaunchChecklistEvidence.expectedSchemaVersion,
            checklistVersion: CoachOperationalLaunchChecklistEvidence.expectedChecklistVersion,
            releaseCandidateBuild: "2026.06.30.1",
            completedByRole: "releaseManager",
            summary: CoachOperationalLaunchChecklistEvidence.Summary(
                itemCount: items.count,
                completedRequiredItemCount: completedRequiredItems.count,
                failedRequiredItemCount: failedRequiredItems.count,
                readinessWarnings: readinessWarnings
            ),
            items: items
        )
    }

    @MainActor
    private static func scriptedConversationAppPathRows(
        surface: CoachReplySurface
    ) async -> [CoachChatConversationAppPathReportRow] {
        var rows: [CoachChatConversationAppPathReportRow] = []
        for conversation in CoachChatConversationCorpus.conversations {
            let suiteName = "CoachChatConversationAppPath.\(surface.rawValue).\(conversation.id).\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            CoachAssessmentCache.shared.invalidate()
            UserTrajectoryCache.shared.invalidate()
            defer {
                defaults.removePersistentDomain(forName: suiteName)
                CoachAssessmentCache.shared.invalidate()
                UserTrajectoryCache.shared.invalidate()
            }

            let replySource = RuntimeConversationReplySource()
            let service = AICoachChatService(
                keyedProviders: { [.openAI] },
                keyLookup: { _ in "test-key" },
                localeSupportsAI: { true },
                providerHTTP: { _, _, _, _ in
                    .success(await replySource.currentOpenAIData())
                },
                diagnosticRecorder: { _, _, _, _, _, _, _, _ in }
            )
            let store = AskNoumStore(
                defaults: defaults,
                accountIDProvider: { "app-path-\(conversation.id)" }
            )
            var turnRows: [CoachChatConversationAppPathTurnRow] = []

            for (index, turn) in conversation.turns.enumerated() {
                await replySource.set(turn.coachReply)
                let ids = store.appendUserTurn(turn.userTurn)
                var qualityGateEvents: [CoachTurnQualityGateEvent] = []
                let outcome = await CoachReplyPipeline.generate(
                    coachID: ids.coachID,
                    surface: surface,
                    store: store,
                    coachService: service,
                    judgementPassEnabled: true,
                    realtimeCoachModeEnabled: true,
                    onQualityGateEvent: { event in
                        qualityGateEvents.append(event)
                    }
                )
                let coach = store.messages.first { $0.id == ids.coachID }
                let metadata = coach?.metadata
                let finalReply = coach?.role == .coach ? coach?.text : nil
                let sanitizedTarget = CoachReplyTextSanitizer.coachReplyText(
                    from: turn.coachReply
                )
                let targetReplyMatched = finalReply == sanitizedTarget
                let outcomeSucceeded: Bool = {
                    if case .reply = outcome, coach?.role == .coach {
                        return true
                    }
                    return false
                }()
                let semanticGatePassed: Bool = {
                    if case .passed? = metadata?.semanticGateOutcome {
                        return true
                    }
                    return false
                }()
                let qualityGateClean: Bool = {
                    switch metadata?.qualityGateOutcome {
                    case .passed?, .repaired?, .notEvaluated?:
                        return true
                    case .fallback?, .failed?, nil:
                        return false
                    }
                }()
                let qualityGateOutcome = metadata?.qualityGateOutcome?.logValue
                let qualityGateAcceptedFallback = outcomeSucceeded &&
                    (qualityGateOutcome?.hasPrefix("fallback:") == true)
                let typedAssessmentFallbackApplied = qualityGateOutcome == "fallback:typedAssessment" ||
                    qualityGateEvents.contains(.fallback("typedAssessment"))
                let qualityGateBlockingFailure = qualityGateOutcome?.hasPrefix("failed:") == true
                let reliabilityIssues = metadata?.reliabilityIssues?.map(\.rawValue) ?? []
                let immediateCoachReadExpected: Bool = {
                    guard let depth = metadata?.turnDepth,
                          let responseMode = metadata?.assessment?.responseMode else {
                        return false
                    }
                    return CoachReplyPipeline.shouldShowProvisionalCoachRead(
                        turnDepth: depth,
                        surface: surface,
                        responseMode: responseMode,
                        realtimeCoachModeEnabled: true
                    )
                }()
                let immediateCoachReadShown = metadata?.immediateCoachReadShown == true
                let immediateCoachReadSatisfied = !immediateCoachReadExpected || immediateCoachReadShown
                let passesAppPathFloor = outcomeSucceeded &&
                    targetReplyMatched &&
                    metadata != nil &&
                    semanticGatePassed &&
                    qualityGateClean &&
                    reliabilityIssues.isEmpty &&
                    metadata?.visionPassesProductionFloor == true &&
                    immediateCoachReadSatisfied

                turnRows.append(CoachChatConversationAppPathTurnRow(
                    turnIndex: index,
                    userTurn: turn.userTurn,
                    targetCoachReply: sanitizedTarget,
                    finalCoachReply: finalReply,
                    outcomeSucceeded: outcomeSucceeded,
                    targetReplyMatched: targetReplyMatched,
                    metadataPresent: metadata != nil,
                    turnDepth: metadata?.turnDepth?.rawValue,
                    providerTierRequested: metadata?.providerTier?.rawValue,
                    providerTierChosen: metadata?.providerTierChosen?.rawValue,
                    providerName: metadata?.providerName,
                    providerModel: metadata?.providerModel,
                    semanticGateOutcome: metadata?.semanticGateOutcome?.logValue,
                    semanticGateIssue: metadata?.semanticGateIssue,
                    semanticGatePassed: semanticGatePassed,
                    qualityGateOutcome: qualityGateOutcome,
                    qualityGateEvents: qualityGateEvents.map(CoachReplyPipeline.qualityGateEventLogValue),
                    qualityGateClean: qualityGateClean,
                    qualityGateAcceptedFallback: qualityGateAcceptedFallback,
                    typedAssessmentFallbackApplied: typedAssessmentFallbackApplied,
                    qualityGateBlockingFailure: qualityGateBlockingFailure,
                    reliabilityIssues: reliabilityIssues,
                    visionScore: metadata?.visionScore,
                    visionPassesProductionFloor: metadata?.visionPassesProductionFloor,
                    immediateCoachReadExpected: immediateCoachReadExpected,
                    immediateCoachReadShown: immediateCoachReadShown,
                    proofTestHash: metadata?.proofTestHash,
                    proofTestRecentlyRepeated: metadata?.proofTestRecentlyRepeated,
                    timeToFirstVisibleTokenMs: metadata?.timeToFirstVisibleTokenMs,
                    timeToCompleteReplyMs: metadata?.timeToCompleteReplyMs,
                    passesAppPathFloor: passesAppPathFloor
                ))
            }

            rows.append(CoachChatConversationAppPathReportRow.make(
                conversationID: conversation.id,
                sourceFixtureID: conversation.sourceFixtureID,
                turns: turnRows
            ))
        }
        return rows
    }
}

@Suite("CoachVisionProductionReadinessAuditTests")
struct CoachVisionProductionReadinessAuditTests {

    @Test func localConversationCorpusDoesNotMasqueradeAsProductionReady() {
        let report = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.conversations
        )
        let expertPacket = CoachChatConversationExpertCalibrationPacket.make(
            from: CoachChatConversationCorpus.professionalCalibrationConversations
        )
        let localTargetShapeScore = CoachVisionProductionReadinessAudit
            .localTargetShapeScore(from: report)
        let audit = CoachVisionProductionReadinessAudit.make(
            localTargetShapeScore: localTargetShapeScore,
            evidence: .currentLocalSubstrate(
                conversationCount: report.conversationCount,
                rowsPassingProductionFloor: report.rows.filter(\.passesProductionFloor).count
            )
        )

        #expect(report.conversationCount == 12)
        #expect(expertPacket.humanGateStatus == .pendingExpertReview)
        #expect(expertPacket.conversationCount == CoachProfessionalCalibrationEvidence.requiredConversationIDs.count)
        #expect(localTargetShapeScore >= 80)
        #expect(audit.score == 18)
        #expect(audit.maximumAllowedScore == 20)
        #expect(audit.score < localTargetShapeScore / 4)
        #expect(audit.claim == .localEvaluationSubstrateOnly)
        #expect(!audit.productionReady)
        #expect(audit.blockers == [
            .noLiveProviderTranscriptSweep,
            .noProfessionalCoachCalibration,
            .noRealUserLongitudinalTransferOutcomes,
            .noRealDeviceTestFlightVerification,
            .operationalLaunchChecklistIncomplete
        ])
        #expect(audit.summary.contains("local target-shape"))
        #expect(audit.summary.contains("18/100"))
    }

    @Test func productionReadyClaimRequiresValidationEvidenceNotJustFixtures() {
        let audit = CoachVisionProductionReadinessAudit.make(
            localTargetShapeScore: 88,
            evidence: CoachVisionProductionReadinessEvidence(
                localConversationCount: 12,
                localRowsPassingProductionFloor: 12,
                localLongFormConversationCount: 10,
                localLongFormRowsPassingConversationFloor: 10,
                localAdversarialConversationCount: 10,
                localAdversarialRowsRejectedByProductionFloor: 10,
                appPathImmediateReadVerified: true,
                appPathProofTestProgressionVerified: true,
                liveProviderRowsPassingFloor: CoachLiveProviderSweepEvidence.requiredReadinessEvidenceCount,
                professionalCoachCalibrationRows: CoachProfessionalCalibrationEvidence.requiredConversationIDs.count,
                realUserLongitudinalOutcomeCount: 12,
                realDeviceTestFlightVerified: true,
                operationalLaunchChecklistComplete: true
            )
        )

        #expect(audit.score == 100)
        #expect(audit.maximumAllowedScore == 100)
        #expect(audit.blockers.isEmpty)
        #expect(audit.claim == .productionReadyEvidenceAvailable)
        #expect(audit.productionReady)
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

private actor RuntimeConversationReplySource {
    private var reply = ""

    func set(_ reply: String) {
        self.reply = reply
    }

    func currentOpenAIData() -> Data {
        RuntimeConversationScript.openAIData(reply)
    }
}
