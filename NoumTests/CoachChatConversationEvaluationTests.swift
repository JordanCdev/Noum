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
import XCTest
@testable import Noum

enum CoachChatAppPathAssessmentProvenance: Hashable {
    /// The source ID must resolve to a declared evaluation fixture. Its explicit
    /// `chosenStyleGoal` decides whether typed assessment is required.
    case fixtureBacked
    /// A deliberately profile-free supplemental scenario. This is an explicit
    /// trust-boundary declaration, not a fallback for an unknown source ID.
    case explicitNeutral
}

struct CoachChatAppPathConversationScript {
    let conversation: CoachChatConversationFixture
    let assessmentProvenance: CoachChatAppPathAssessmentProvenance
    let seedCoachReplies: [String]
    /// Verified proof quotes to seed into `ProofMomentStore.shared` before this
    /// fixture runs. When the user asks for a session example and a verified
    /// proof exists, the pipeline's `missingVerifiedExampleQuote` gate requires
    /// the reply to cite one — so a fixture whose gold cites a past-rep quote
    /// must supply that quote as real evidence (mirrors the shipping path where
    /// the proof archive holds the user's actual words). Seeded per-fixture and
    /// cleared after, so it never leaks into the other conversations' evidence.
    let seedProofQuotes: [String]

    init(
        conversation: CoachChatConversationFixture,
        assessmentProvenance: CoachChatAppPathAssessmentProvenance,
        seedCoachReplies: [String] = [],
        seedProofQuotes: [String] = []
    ) {
        self.conversation = conversation
        self.assessmentProvenance = assessmentProvenance
        self.seedCoachReplies = seedCoachReplies
        self.seedProofQuotes = seedProofQuotes
    }
}

enum CoachChatConversationCorpus {
    static let reportSchemaVersion = "coach-chat-conversation-eval-v10"
    static let longFormReportSchemaVersion = "coach-chat-long-form-conversation-eval-v1"
    static let longFormAdversarialReportSchemaVersion = "coach-chat-long-form-adversarial-eval-v1"
    static let expertCalibrationPacketSchemaVersion = "coach-chat-conversation-expert-calibration-v2"
    static let appPathReportSchemaVersion = "coach-chat-conversation-app-path-eval-v1"
    static let liveAppPathReportSchemaVersion = "coach-chat-live-app-path-eval-v1"
    static let readinessEvidenceManifestSchemaVersion = CoachVisionProductionReadinessEvidenceManifest.schemaVersion
    static let liveProviderSweepArtifactFileName = "coach-live-eval-v1.json"
    static let professionalCoachCalibrationResultsArtifactFileName =
        "coach-chat-conversation-expert-calibration-results-v2.json"
    static let realUserTransferOutcomesArtifactFileName =
        "coach-real-user-transfer-outcomes-v3.json"
    static let realDeviceTestFlightArtifactFileName =
        "coach-real-device-testflight-qa-v3.json"
    static let operationalLaunchChecklistArtifactFileName =
        "coach-operational-launch-checklist-v2.json"

    static let conversations: [CoachChatConversationFixture] = [
        CoachChatConversationFixture(
            id: "cold-start-interview-baseline-conversation",
            sourceFixtureID: "cold-start-interview-baseline",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "How do I get better before my interview?",
                    coachReply: "No baseline yet, so start with evidence. Record 60 seconds on 'Why should we hire you?', answer in sentence one, give one proof, then stop and replay only the opener."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I listen for in the replay?",
                    coachReply: "On your first baseline, listen only to sentence one because it shows whether the answer leads before setup. If background comes first, rewrite that sentence and run the rep again."
                ),
                CoachChatConversationTurn(
                    userTurn: "So not my whole speaking style yet?",
                    coachReply: "Right—not your whole speaking style. One interview answer is too thin for that claim, so keep the read to sentence order until different prompts show the same pattern."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "filler-pressure-prescription-conversation",
            sourceFixtureID: "filler-pressure-prescription",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "How do I stop saying um under pressure?",
                    coachReply: "When um wants to enter under pressure, hold a one-second silence instead because the gap stays quiet. Repeat the prompt and compare fillers per minute; treat one rep as a test, not a pattern."
                ),
                CoachChatConversationTurn(
                    userTurn: "Do I pause before every sentence?",
                    coachReply: "No. Use one beat before the final sentence as the test, because pausing everywhere changes too much at once to show whether that one timing move helped."
                ),
                CoachChatConversationTurn(
                    userTurn: "What proves it worked?",
                    coachReply: "Use the same 60-second prompt and timer because you only want to test the pause point. Success is a lower filler rate and a final sentence that still lands cleanly."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "metric-action-without-read-conversation",
            sourceFixtureID: "metric-action-without-read",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "What should I do with that filler count?",
                    coachReply: "Use the filler count as one baseline, not a pattern. Hold one silent beat after the decision line because that tests the timing move; then compare the rate on an equivalent rep."
                ),
                CoachChatConversationTurn(
                    userTurn: "Why after the decision line?",
                    coachReply: "Because the filler interrupts the moment where authority should sound settled. The pause after the decision gives your reason somewhere to go without weakening the recommendation."
                ),
                CoachChatConversationTurn(
                    userTurn: "What do I run next?",
                    coachReply: "Run a recommendation answer: decision, one reason, clean stop, because that isolates the proof boundary without inviting a full essay."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "critique-trust-repair-conversation",
            sourceFixtureID: "critique-trust-repair",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "This is robotic and too much writing.",
                    coachReply: "You're right—that sounded robotic and was too long. I'll use one specific point in plain language: the recommendation came after the setup."
                ),
                CoachChatConversationTurn(
                    userTurn: "What was generic about it?",
                    coachReply: "You're right—I named a plan without naming the behavior. The behavior was a late opener; next time I'll name that before offering a plan."
                ),
                CoachChatConversationTurn(
                    userTurn: "Give me the short version.",
                    coachReply: "The opener is the target because the prior reply buried it. Put the point in sentence one, add one reason, stop, then check whether the setup stayed out."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "markdown-tts-trust-repair-conversation",
            sourceFixtureID: "markdown-tts-trust-repair",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "The ** don't format and TTS reads them out. The responses feel robotic and cold, nowhere near an expert coach.",
                    coachReply: "You're right—TTS read the formatting aloud, and the wording sounded robotic. I'll use plain text and one direct point: the recommendation came after the setup."
                ),
                CoachChatConversationTurn(
                    userTurn: "And stop saying practice more.",
                    coachReply: "You're right—I prescribed another drill instead of answering. I'll answer the point directly without assigning more practice."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I record?",
                    coachReply: "Record a 30-second recommendation answer because that isolates the opener. Check only whether sentence one states the recommendation; stop once you have that evidence."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "assistant-explainer-register-conversation",
            sourceFixtureID: "assistant-explainer-register",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "This still sounds cold and overexplained, like generic AI tips.",
                    coachReply: "You're right—that sounded robotic and was too long. I'll use one specific point in plain language: reassurance came before the recommendation."
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
                    coachReply: "Not proven yet: the transcript shows mechanics—a recommendation and one controlled rep—but not authority under pressure. Missing repeated higher-stakes evidence; repeat the stakeholder answer with verdict first and a clean stop."
                ),
                CoachChatConversationTurn(
                    userTurn: "Is 7/10 bad?",
                    coachReply: "No. A rep score is useful evidence, not a verdict on authority; pressure repeatability is still unproven."
                ),
                CoachChatConversationTurn(
                    userTurn: "What would make you change the diagnosis?",
                    coachReply: "The latest timed rep is not enough to change the diagnosis. Two clean pressure reps with the verdict early and the close settled would."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "what-next-single-move-conversation",
            sourceFixtureID: "what-next-single-move",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "What next?",
                    coachReply: "The close is the target because the latest transcript ends in explanation. Rewrite only the final sentence, then retry the same prompt with that ask."
                ),
                CoachChatConversationTurn(
                    userTurn: "Why the close instead of the opening?",
                    coachReply: "In the last transcript, the opening is serviceable enough. The close is where authority leaks because the answer ends as a summary instead of an ask."
                ),
                CoachChatConversationTurn(
                    userTurn: "What is the exact rep?",
                    coachReply: "The recent rep makes the close the target, so use the same topic and change only the ending. Make the final sentence the ask; if it becomes a recap, rewrite that sentence before another run."
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
            id: "personal-pattern-consent-boundary-conversation",
            sourceFixtureID: "personal-pattern-hypothesis-confirmation",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "Do I sound defensive when I disagree?",
                    coachReply: "Treat defensiveness as a hypothesis, not a label: the transcript softened the disagreement before the point. Check whether that fits, then say the disagreement first, give one reason, and stop."
                ),
                CoachChatConversationTurn(
                    userTurn: "What if that doesn't fit?",
                    coachReply: "Then reject that hypothesis and keep the observable read: the disagreement arrived after too much setup. Run the same answer disagreement-first and compare whether the listener gets the point sooner."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should Noum remember?",
                    coachReply: "I’d remember one tentative pattern: disagreement may be softened by setup, and drop that read if later evidence contradicts it."
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
                    coachReply: "Check the close because it shows whether the update becomes a decision: did the final sentence ask for alignment or a choice? Treat your room read as self-report, not proof."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "answer-depth-one-example-conversation",
            sourceFixtureID: "answer-depth-one-example",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "How do I add depth without rambling?",
                    coachReply: "Add one layer only: state the point, give one concrete example, then stop. That creates depth without opening a second thread."
                ),
                CoachChatConversationTurn(
                    userTurn: "Can you give me an example of me doing this in sessions?",
                    coachReply: "I don't have a verified quote for that session, and I won't invent one. Choose a rep or transcript and I'll point to the exact moment."
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
                    coachReply: "Fair push—I answered with advice when you wanted the read. Reassurance came before the recommendation; next time I'll name that ordering issue directly."
                ),
                CoachChatConversationTurn(
                    userTurn: "What did you miss?",
                    coachReply: "You're right—I answered around the question and missed the hesitation inside the polite pushback. I'll answer the point directly without assigning more practice."
                ),
                CoachChatConversationTurn(
                    userTurn: "How do I test that without sounding harsh?",
                    coachReply: "Run one client-concern answer: recommendation in sentence one, reassurance in sentence two. That tests order without removing warmth, because the tone stays kind while the point arrives first."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "not-informative-trust-repair-conversation",
            sourceFixtureID: "assistant-explainer-register",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "That's not informative at all.",
                    coachReply: "You're right—that answer was vague. I should have said this plainly: reassurance came before the recommendation, so the listener had to wait for the point."
                ),
                CoachChatConversationTurn(
                    userTurn: "What was the useful read?",
                    coachReply: "The useful read is order: in your last rep, comfort arrived before the point, so the listener waits too long for the recommendation even though the tone is warm."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I do with that?",
                    coachReply: "Run one 45-second client concern answer because it isolates order. Sentence one is the recommendation; sentence two is one reassurance; then stop."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "not-easy-empathy-conversation",
            sourceFixtureID: "personal-pattern-hypothesis-confirmation",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "It's not easy.",
                    coachReply: "You're right—this isn't easy. The setup carries social risk under pressure, so make it smaller: say the disagreement and one calm reason, then stop."
                ),
                CoachChatConversationTurn(
                    userTurn: "Is it the disagreement or the setup?",
                    coachReply: "The setup is carrying the pressure: reassurance arrives before the disagreement, so the point feels harder to say. Keep the disagreement in sentence one, add one calm reason, then stop."
                ),
                CoachChatConversationTurn(
                    userTurn: "What is the smallest rep?",
                    coachReply: "Use a 20-second disagreement because it isolates the social risk: say no in sentence one, give one calm reason, then stop before you prove you are reasonable. Check whether the disagreement lands before reassurance."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "repeating-yourself-trust-repair-conversation",
            sourceFixtureID: "filler-pressure-prescription",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "You're repeating yourself.",
                    coachReply: "You're right—I repeated the same instruction. I should have changed the evidence instead of sending you through the same drill again."
                ),
                CoachChatConversationTurn(
                    userTurn: "So not the same drill again?",
                    coachReply: "Right. Keep the close as the target, but change the evidence: compare fillers after the decision line on an equivalent prompt instead of repeating the same drill."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should change next time?",
                    coachReply: "Your latest qualified rep gives one rate, not a pressure pattern, so run the same prompt and check whether a filler appears after the decision line. Then compare fillers per minute."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "polite-however-arena-repair-conversation",
            sourceFixtureID: "assistant-explainer-register",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "Okay that's cool, however I still don't feel like that answers what I meant.",
                    coachReply: "Fair push—I answered with advice when you wanted the read. Reassurance came before the recommendation; next time I'll name that ordering issue directly."
                ),
                CoachChatConversationTurn(
                    userTurn: "So what was the question underneath it?",
                    coachReply: "You were asking whether the read fits you, not whether another drill exists. Keep the hypothesis soft: if verdict-first solves the issue, it was structure rather than identity."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I try once?",
                    coachReply: "Run one verdict-first answer because it tests the hypothesis cleanly: sentence one gives the point, sentence two gives one reason, then stop before explaining yourself."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "too-much-writing-short-repair-conversation",
            sourceFixtureID: "critique-trust-repair",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "Too much writing. Get to the point.",
                    coachReply: "You're right—that was too long. I'll give the direct point in plain language: the answer kept explaining after the ask."
                ),
                CoachChatConversationTurn(
                    userTurn: "That short?",
                    coachReply: "Yes. Short is the point here because the extra explanation is where the close loses force."
                ),
                CoachChatConversationTurn(
                    userTurn: "What do I record?",
                    coachReply: "Record one 30-second close only because it isolates the close: decision, one reason, ask, stop. If you add a recap, rerun it once."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "confidence-ending-softener-conversation",
            sourceFixtureID: "confidence-clean-stop",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "Why does my ending sound less confident?",
                    coachReply: "The confidence leak is the extra softener after the recommendation. Your closing-strength lever is the ask: it starts sounding optional, so keep the recommendation, cut the final qualifier, and end on the ask."
                ),
                CoachChatConversationTurn(
                    userTurn: "So I should stop after the ask?",
                    coachReply: "Yes: stop after the ask because the extra sentence is where confidence drops. Repeat the prompt and check only whether the last line asks cleanly."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I listen for?",
                    coachReply: "Listen for any maybe, just, or I think after the ask, because those softeners reopen the decision. If one appears after the decision line, rewrite only the final sentence and record it once more."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "score-not-readiness-board-conversation",
            sourceFixtureID: "authoritative-distance-deep-assessment",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "I got 8/10. Am I ready for the board update?",
                    coachReply: "Not proven yet: the timed rep and clear recommendation show useful mechanics, but not board readiness under pressure. Missing: repeated pressure evidence; run a board proof with verdict first, one reason, and a clean stop."
                ),
                CoachChatConversationTurn(
                    userTurn: "So the score is not enough?",
                    coachReply: "Right: the score is evidence, not readiness by itself. Run one board-style close under pressure, then judge whether the decision ask stays clean."
                ),
                CoachChatConversationTurn(
                    userTurn: "What would make you call it ready?",
                    coachReply: "Two board-style reps where the headline lands first and the final sentence asks for a decision. If both stay clean under time pressure, then the readiness read gets stronger."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "no-baseline-interview-help-conversation",
            sourceFixtureID: "cold-start-interview-baseline",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "I have no sessions yet but need interview help.",
                    coachReply: "No baseline yet, so I cannot make a personal read. Record a 60-second interview answer with answer first, one proof, and a clean stop; then replay sentence one."
                ),
                CoachChatConversationTurn(
                    userTurn: "What question should I use?",
                    coachReply: "The signal is whether the answer starts before context, so use why should we hire you. Sentence one answers, sentence two gives one proof, then stop before listing strengths."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should Noum judge after?",
                    coachReply: "Judge only the first signal because it tells us whether sentence one answered before context. If it warmed up first, rewrite sentence one and run the same prompt again."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "pace-rushing-read-conversation",
            sourceFixtureID: "pace-control-next-rep",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "Am I rushing?",
                    coachReply: "Yes, locally: 181 WPM plus fillers after sentence one point to rushed transitions. Test one silent beat after the verdict, then check whether the next sentence stays clean."
                ),
                CoachChatConversationTurn(
                    userTurn: "Why not slow all of it down?",
                    coachReply: "Because the signal is not every word; it is the handoff after sentence one. Slow that handoff and keep the rest natural so the answer still sounds alive."
                ),
                CoachChatConversationTurn(
                    userTurn: "What proves the pace improved?",
                    coachReply: "Run the same 60-second prompt and check whether fillers stay down after sentence one while the final sentence still lands, because that isolates pace from overcontrol."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "closing-ask-fix-conversation",
            sourceFixtureID: "closing-ask-proof-test",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "What should I fix in the close?",
                    coachReply: "Fix the final sentence: it recaps instead of asking for a decision, so make the last line the ask and stop before explaining it again."
                ),
                CoachChatConversationTurn(
                    userTurn: "What if I need to summarize?",
                    coachReply: "Use the last rep's close: summarize before the final sentence, because the close should not recap the whole update. The final line should ask for the decision or alignment you need."
                ),
                CoachChatConversationTurn(
                    userTurn: "How do I test it?",
                    coachReply: "The signal is the last 10 seconds: if the final sentence asks for alignment or a decision, keep it. If it recaps, rewrite only that line and record 45 seconds again."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "opening-verdict-stronger-conversation",
            sourceFixtureID: "opening-verdict-next-rep",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "How do I make the opener stronger?",
                    coachReply: "Make sentence one the verdict. Your transcript warms into context before the point, so lead with the recommendation, give one reason, then stop."
                ),
                CoachChatConversationTurn(
                    userTurn: "Will that sound too blunt?",
                    coachReply: "Not if sentence two carries the warmth. The opener gives direction; the next sentence can make it easy to hear without delaying the point."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I record?",
                    coachReply: "Record one 45-second answer with verdict first and one reason second, because that tests the opener. Check whether the listener would know the point by sentence one."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "pause-before-answer-pressure-conversation",
            sourceFixtureID: "pause-before-answer-drill",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "I panic before answering. What do I do?",
                    coachReply: "That panic is the pressure cue. Hold one silent beat before sentence one, then say only the opener; check whether its first five words stay clean."
                ),
                CoachChatConversationTurn(
                    userTurn: "Won't the pause feel awkward?",
                    coachReply: "In the next pressure rep, the signal is the first word: a short beat can steady it, while a rushed start can signal pressure. Test one beat only before the opener."
                ),
                CoachChatConversationTurn(
                    userTurn: "What should I measure?",
                    coachReply: "Measure the first-five-words signal because that tests whether the pause helped: run two 20-second answers, then check whether the first sentence starts cleanly after the beat and fillers stay out."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "concise-answer-rambling-conversation",
            sourceFixtureID: "concise-answer-next-rep",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "How do I stop rambling?",
                    coachReply: "Use a two-sentence ceiling: recommendation, one reason, clean stop. That isolates the ramble point because a second reason opens another thread."
                ),
                CoachChatConversationTurn(
                    userTurn: "How do I know I stopped soon enough?",
                    coachReply: "Stop when the listener has a decision and one reason because anything after that starts a new thread. To check it, play only the first 20 seconds; if both are clear, cut the rest."
                ),
                CoachChatConversationTurn(
                    userTurn: "What prompt should I use?",
                    coachReply: "Use a 45-second client recommendation prompt. Restart if you add another condition after the reason, because that is the exact point where the answer starts to sprawl."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "structure-one-reason-conversation",
            sourceFixtureID: "structure-one-reason-proof",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "My answer has a claim and a reason, but it still feels weak.",
                    coachReply: "Your claim and reason are present; the missing link is an implication or ask. Use claim, one reason, implication, ask, then check whether the listener knows what to do."
                ),
                CoachChatConversationTurn(
                    userTurn: "So I should not add more reasons?",
                    coachReply: "No: more reasons would hide the gap. Use one reason, one implication, and one ask because that turns support into direction."
                ),
                CoachChatConversationTurn(
                    userTurn: "What is the drill?",
                    coachReply: "Run a 60-second update with claim, one reason, implication, ask, because that tests whether the reason creates direction. Check whether the ask follows without adding another proof."
                )
            ]
        ),
        CoachChatConversationFixture(
            id: "confidence-clean-stop-conversation",
            sourceFixtureID: "confidence-clean-stop",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "How do I sound more confident at the end?",
                    coachReply: "The confidence leak comes after the ask, where maybe or just reopens the decision. Make the ask and stop because anything after it weakens the close; then replay the final sentence."
                ),
                CoachChatConversationTurn(
                    userTurn: "What if I sound too direct?",
                    coachReply: "Direct is fine when the reason comes before the ask; keep that order, then stop. Do not apologise after the ask, because that reopens the decision."
                ),
                CoachChatConversationTurn(
                    userTurn: "What do I repeat?",
                    coachReply: "Repeat the final sentence only: ask, period, because that isolates the confidence leak. If you add a qualifier after it, rewrite that same line until it ends cleanly."
                )
            ]
        )
    ]

    static var appPathConversationScripts: [CoachChatAppPathConversationScript] {
        conversations.map {
            CoachChatAppPathConversationScript(
                conversation: $0,
                assessmentProvenance: .fixtureBacked
            )
        } +
            arenaSupplementalAppPathScripts
    }

    static var appPathConversations: [CoachChatConversationFixture] {
        appPathConversationScripts.map(\.conversation)
    }

    /// Resolves only declarations made at the script construction boundary.
    /// Missing sources, a fixture-backed source that no longer resolves, and a
    /// supplemental-neutral source that later collides with a real fixture all
    /// fail closed instead of silently becoming neutral.
    static func assessmentProvenance(
        for fixtureID: String
    ) -> CoachChatAppPathAssessmentProvenance? {
        let declarations = conversations
            .filter { $0.sourceFixtureID == fixtureID }
            .map { _ in CoachChatAppPathAssessmentProvenance.fixtureBacked } +
            arenaSupplementalAppPathScripts
            .filter { $0.conversation.sourceFixtureID == fixtureID }
            .map(\.assessmentProvenance)
        let uniqueDeclarations = Set(declarations)
        guard uniqueDeclarations.count == 1,
              let declaration = uniqueDeclarations.first else {
            return nil
        }
        let fixtureExists = CoachChatEvaluationCorpus.fixtures.contains {
            $0.id == fixtureID
        }
        switch declaration {
        case .fixtureBacked:
            return fixtureExists ? declaration : nil
        case .explicitNeutral:
            return fixtureExists ? nil : declaration
        }
    }

    private static let arenaSupplementalAppPathScripts: [CoachChatAppPathConversationScript] = [
        explicitNeutralArenaAppPathScript(
            fixtureID: "examples-from-sessions-010",
            userTurn: "Can you give me an example of me doing this in sessions?",
            coachReply: "In one verified rep, you said, 'we focused on three priorities.' Those are clear reasons but no picture, so add one concrete example after the first reason.",
            seedCoachReplies: ["You tend to give reasons before the picture."],
            // Include the trailing period: the guard extracts the quoted fragment
            // *with* its inner period ('we focused on three priorities.'), and
            // `transcriptContains` matches by substring — a period-bearing source
            // contains the fragment whether or not the period is captured, so this
            // verifies robustly in both directions (Gate 2 + the example gate).
            seedProofQuotes: ["we focused on three priorities."]
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "outcome-not-causation-027",
            userTurn: "The room seemed engaged. Did the drill cause that?",
            coachReply: "I would not call that causation: using the prepared close and your room-read show association, not proof. Keep the close, then capture the exact question people ask afterward.",
            seedCoachReplies: ["Use the final sentence as the ask."]
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "upcoming-conflict-028",
            userTurn: "I have a difficult conversation tonight. What should I practice?",
            coachReply: "Tonight's risk is over-proving, so practice the boundary sentence only: say the disagreement in sentence one, give one calm reason, then stop before proving you are reasonable."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "networking-intro-029",
            userTurn: "I ramble when introducing myself at networking events.",
            coachReply: "Start with a 20-second test: who you help, what changes, and one question for them. No full story yet, because first we need to hear where the ramble starts."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "presentation-nerves-030",
            userTurn: "My presentation sounds polished but flat. What is missing?",
            coachReply: "The words are structured; I cannot prove vocal energy from this text alone. Test the hypothesis by marking one sentence as the peak and recording it with a deliberate emphasis on the consequence."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "sales-pitch-031",
            userTurn: "My sales pitch loses people after the first minute.",
            coachReply: "The likely gap is salience: reasons are there, but nothing for the listener to picture. So add one concrete customer example after the first claim, then return to the ask."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "board-update-032",
            userTurn: "Would a board hear this as executive?",
            coachReply: "Mechanically, it has board ingredients; I would not yet call it executive in the room. The close recaps instead of asking for a decision, so rehearse the final sentence as the decision you need."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "overexplaining-033",
            userTurn: "Do I overexplain?",
            coachReply: "I would call it an overexplaining hypothesis, not a label. The observable signal is three reasons before the recommendation, so cap the next answer at recommendation plus one reason."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "fear-disagreement-034",
            userTurn: "Am I afraid to disagree?",
            coachReply: "I would not diagnose fear from one transcript. The observable pattern is delay: reassurance comes before the disagreement, so test disagreement in sentence one and tell me whether that feels accurate."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "lack-conviction-035",
            userTurn: "Do I lack conviction?",
            coachReply: "Not enough evidence to call this lack of conviction: the latest rep and pace support only a mechanics signal—hedging before the recommendation—not a verdict under pressure. Repeat the answer with a direct verb."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "emotional-disconnection-036",
            userTurn: "It sounds correct but not like me. What do I change?",
            coachReply: "Trust that signal. Keep the structure, replace one polished phrase with words you would actually say, then record once and compare how it feels."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "evasive-polished-037",
            userTurn: "Could this sound polished but evasive?",
            coachReply: "Yes, mechanically, but evasiveness under pressure is not proven: the latest rep and pace show only an answer arriving after setup. Missing repeated pressure proof; put the direct answer first, then one reason."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "timidity-038",
            userTurn: "Do I sound timid?",
            coachReply: "I cannot prove timid from text: the latest rep supports only indirectness before the recommendation, while tone still needs audio. So try one direct recommendation first and compare how it sounds."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "authority-under-pressure-039",
            userTurn: "What breaks when pressure goes up?",
            coachReply: "The pressure break is sentence one. Normal reps are clean, but under the timer the opener gets swallowed and fillers rise, so repeat the same prompt under a timer and protect only the first sentence."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "semantic-filler-use-040",
            userTurn: "You counted 'like' but I meant it as a comparison.",
            coachReply: "Good correction: if like carried a real comparison, I should not count it as filler. Keep the comparison; mark only pause-fillers that add no meaning.",
            seedCoachReplies: ["You used like as filler several times."]
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "prompt-echo-041",
            userTurn: "The prompt made me repeat the phrase. Is that my filler?",
            coachReply: "Fair boundary: prompt echo in the latest rep was not filler, so I would not count it. Next time, mark only words added while searching for the next thought."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "no-transcript-fabrication-042",
            userTurn: "Quote what I said that shows this.",
            coachReply: "I cannot quote that unless the transcript gives me the exact words. The safe read is non-quote evidence: the close softened after the recommendation, so rerun the final sentence as the ask.",
            seedCoachReplies: ["Your close softened."]
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "quote-guard-043",
            userTurn: "Did I actually say that?",
            coachReply: "Correction: I should not quote wording unless it is verified. I retract it; the supported read is only that the recommendation came late.",
            seedCoachReplies: ["You said 'we should pause the launch'."]
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "live-latency-short-044",
            // This latency fixture is intentionally profile-neutral, but it is
            // not evidence-free. Name the already-observed close in the user
            // turn so the real retriever can ground the scripted close move
            // instead of accepting an ungrounded provider target.
            userTurn: "Quickly, what do I do next about the close?",
            coachReply: "The close is the lever, so make the final sentence the ask, then stop."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "barge-in-045",
            userTurn: "Stop, that's not what I asked.",
            coachReply: "Fair—I am stopping that thread. Your ask is the close, so make the final sentence the ask, not another filler drill.",
            seedCoachReplies: ["Long spoken answer about filler counts."]
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "weekly-checkin-046",
            userTurn: "This week felt harder even though my score improved.",
            coachReply: "Both can be true: the score reflects mechanics, while your check-in records effort. Run the same prompt with one fewer condition because that tests whether effort drops without losing the gain."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "real-world-outcome-047",
            userTurn: "My interview answer landed better than practice. What do we learn?",
            coachReply: "Treat it as useful self-report, not proof. The reusable move is verdict first plus one example, so keep that for interviews and capture what question made it land.",
            seedCoachReplies: ["Practice verdict first, one example, clean stop."]
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "grammar-leak-048",
            userTurn: "What is the one move?",
            coachReply: "The close is the move, so make the final sentence the ask, then stop."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "placeholder-leak-049",
            userTurn: "Can you coach this?",
            coachReply: "I need one rep before I can coach this honestly. Record 60 seconds, then I will read the opener and close."
        ),
        explicitNeutralArenaAppPathScript(
            fixtureID: "assistant-wrapper-050",
            userTurn: "This feels like a generic AI wrapper.",
            coachReply: "You're right—that sounded templated. I should have named the specific read: the recommendation arrived after the setup, which made the advice feel generic.",
            seedCoachReplies: ["Here are some tips: be confident, speak clearly, and practice."]
        )
    ]

    private static func explicitNeutralArenaAppPathScript(
        fixtureID: String,
        userTurn: String,
        coachReply: String,
        seedCoachReplies: [String] = [],
        seedProofQuotes: [String] = []
    ) -> CoachChatAppPathConversationScript {
        CoachChatAppPathConversationScript(
            conversation: CoachChatConversationFixture(
                id: "arena-\(fixtureID)-app-path-conversation",
                sourceFixtureID: fixtureID,
                turns: [
                    CoachChatConversationTurn(
                        userTurn: userTurn,
                        coachReply: coachReply
                    )
                ]
            ),
            assessmentProvenance: .explicitNeutral,
            seedCoachReplies: seedCoachReplies,
            seedProofQuotes: seedProofQuotes
        )
    }

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
                    coachReply: "That is useful: fillers dropped but the close stiffened, so keep the pause point and change the check. Say only the final sentence twice—natural then deliberate—and keep the version that stays clean without sounding managed."
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
                    coachReply: "The signal is now placement before the proof, so review the transcript from the first proof sentence and rewrite only that transition: decision, because, proof."
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
                    coachReply: "You're right—that confirms formatting was part of the problem. I'll keep future replies plain and symbol-free."
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
                    coachReply: "Check whether the verdict stays early and the close stays steady on the next pressure rep, because a mechanics gain becomes progress only when that pattern repeats."
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
            baseIndex: 10,
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
        ),
        longFormConversation(
            baseIndex: 12,
            extraTurns: [
                CoachChatConversationTurn(
                    userTurn: "I said cool because I was trying not to be rude.",
                    coachReply: "That matters because the polite wording hid a stronger no-fit signal. The repair is to name the miss before the drill, then keep the target narrow: recommendation first, one reassurance, stop."
                ),
                CoachChatConversationTurn(
                    userTurn: "This still feels too generic, like you're just giving me another drill.",
                    coachReply: "Fair push—I prescribed another drill instead of using the evidence. I'll answer the point directly: recommendation first can stay warm when reassurance follows."
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
            repairCarryoverBreakVariant(for: longFormConversations[5]) ??
                requireIntentMismatchVariant(at: 5),
            silentPlanSwitchVariant(for: longFormConversations[6]),
            repeatedProofTestVariant(for: longFormConversations[7]),
            sameDiscourseMoveVariant(for: longFormConversations[8]),
            transferCausalityVariant(for: longFormConversations[9]),
            trustRepairWithoutAttunementVariant(for: longFormConversations[10]) ??
                staleStateVariant(for: longFormConversations[10])
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
        evaluate(.discourseMoveDiversity, weight: 0, passes: variesDiscourseMoves(conversation))
        evaluate(.planContinuity, weight: 0, passes: preservesInterventionContinuity(conversation))
        let isRepair = containsAny(lowerUser, [
            "robotic", "cold", "generic", "too much writing",
            "format", "tts", "not informative"
        ])
        evaluate(.adaptiveRepair, weight: 8, passes: isRepair
            ? containsAny(lowerCoach, [
                "fair push", "you're right", "you’re right",
                "i answered", "i missed", "i repeated",
                "advice, not coaching", "should never", "too generic"
            ])
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

    static func sameDiscourseMoveVariant(
        for conversation: CoachChatConversationFixture
    ) -> CoachChatConversationFixture {
        let targets = [
            "the opener",
            "the close",
            "the proof line",
            "the tone check",
            "the timeline detail"
        ]
        let checks = [
            "Check whether sentence one lands before setup.",
            "Check whether the final ask lands without recap.",
            "Check whether one proof line is concrete.",
            "Check whether reassurance follows the recommendation.",
            "Check whether the date answers sequence."
        ]
        return CoachChatConversationFixture(
            id: "\(conversation.id)-same-discourse-move",
            sourceFixtureID: conversation.sourceFixtureID,
            turns: conversation.turns.enumerated().map { index, turn in
                let target = targets[min(index, targets.count - 1)]
                let check = checks[min(index, checks.count - 1)]
                return CoachChatConversationTurn(
                    userTurn: turn.userTurn,
                    coachReply: "Run one focused rep on \(target). \(check)"
                )
            }
        )
    }

    static func transferCausalityVariant(
        for conversation: CoachChatConversationFixture
    ) -> CoachChatConversationFixture {
        CoachChatConversationFixture(
            id: "\(conversation.id)-transfer-causality",
            sourceFixtureID: conversation.sourceFixtureID,
            turns: conversation.turns.enumerated().map { index, turn in
                guard turn.userTurn.localizedCaseInsensitiveContains("I did the update") ||
                    turn.userTurn.localizedCaseInsensitiveContains("capture now") else {
                    return turn
                }
                let reply = index == conversation.turns.indices.last
                    ? "The audience response is objective proof that training transferred. Save it as proof the drill worked, then repeat the same prep unchanged."
                    : "That proves the 75-second close drill caused the room to engage. The outcome means the prep made the leadership update work, so keep the same drill unchanged."
                return CoachChatConversationTurn(
                    userTurn: turn.userTurn,
                    coachReply: reply
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

    static func silentPlanSwitchVariant(
        for conversation: CoachChatConversationFixture
    ) -> CoachChatConversationFixture {
        CoachChatConversationFixture(
            id: "\(conversation.id)-silent-plan-switch",
            sourceFixtureID: conversation.sourceFixtureID,
            turns: conversation.turns.enumerated().map { index, turn in
                guard index == 1 else { return turn }
                return CoachChatConversationTurn(
                    userTurn: turn.userTurn,
                    coachReply: "Actually, change target. New plan instead: ignore the earlier read and work on vocal warmth with a 60-second confidence rep."
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
            TurnDepthClassifier.classify(userText: turn.userTurn) == .trustRepair &&
                CoachChatTurnIntent.classify(turn.userTurn) != .vulnerable
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

    static func thinTrustRepairVariant(
        for conversation: CoachChatConversationFixture
    ) -> CoachChatConversationFixture? {
        guard let repairIndex = conversation.turns.firstIndex(where: { turn in
            TurnDepthClassifier.classify(userText: turn.userTurn) == .trustRepair &&
                CoachChatTurnIntent.classify(turn.userTurn) != .vulnerable
        }) else {
            return nil
        }

        return CoachChatConversationFixture(
            id: "\(conversation.id)-thin-trust-repair",
            sourceFixtureID: conversation.sourceFixtureID,
            turns: conversation.turns.enumerated().map { index, turn in
                guard index == repairIndex else { return turn }
                return CoachChatConversationTurn(
                    userTurn: turn.userTurn,
                    coachReply: "Fair push. Run a 45-second rep with the opener first because it gives the point somewhere to land."
                )
            }
        )
    }

    static func repairCarryoverBreakVariant(
        for conversation: CoachChatConversationFixture
    ) -> CoachChatConversationFixture? {
        guard let repairIndex = conversation.turns.firstIndex(where: { turn in
            TurnDepthClassifier.classify(userText: turn.userTurn) == .trustRepair &&
                CoachChatTurnIntent.classify(turn.userTurn) != .vulnerable
        }),
              conversation.turns.indices.contains(repairIndex + 1) else {
            return nil
        }

        return CoachChatConversationFixture(
            id: "\(conversation.id)-repair-carryover-break",
            sourceFixtureID: conversation.sourceFixtureID,
            turns: conversation.turns.enumerated().map { index, turn in
                guard index == repairIndex + 1 else { return turn }
                return CoachChatConversationTurn(
                    userTurn: turn.userTurn,
                    coachReply: "Let's reset. A good next step is to practice more and communicate clearly over time. Track your progress and keep practicing."
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
            let recentCoachReplies = Array(
                history
                    .reversed()
                    .filter { $0.role == .coach }
                    .map(\.text)
                    .prefix(4)
            )
            let actionFingerprints = actionSentenceFingerprints(in: turn.coachReply)
            let proofTestRecentlyRepeated = actionFingerprints.contains {
                recentActionFingerprints.contains($0)
            }
            // The shipping repeated-proof gate deliberately requires both the
            // upstream repeat signal and the typed proof it belongs to. Supply
            // that contract in the paired negative-control fixtures instead of
            // testing a nil-assessment path the runtime never uses.
            let assessment: CoachAssessment? = conversation.id.contains("-repeated-proof")
                ? CoachAssessment(
                    turnDepth: turnDepth,
                    surface: .text,
                    questionRestatement: turn.userTurn,
                    directVerdict: "The proof test is repeating.",
                    confidence: 0.70,
                    evidenceUsed: [],
                    rubricScores: [],
                    missingEvidence: [],
                    nextProofTest: "Run the same 60-second proof test.",
                    responseMode: .expandable
                )
                : nil
            let verdict = CoachReliabilityGate.evaluate(
                replyText: turn.coachReply,
                previousCoachReply: previousCoachReply,
                recentCoachReplies: recentCoachReplies,
                latestUserTurn: turn.userTurn,
                turnDepth: turnDepth,
                assessment: assessment,
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
        let systemContext = sourceFixture.map(CoachChatEvaluationCorpus.renderedContext(for:))
        let trajectory = UserTrajectoryCache.shared.snapshot(
            profile: sourceFixture?.profile,
            baseline: .empty,
            rating: .initial,
            sessions: sourceFixture?.sessions ?? [],
            coachMemory: nil
        ).snapshot
        let rubric = sourceFixture
            .flatMap { GoalRubricStore.activeRubric(for: $0.profile) }
            ?? ActiveGoalRubric(
                rubric: GoalRubricStore.rubric(for: .authoritative),
                voice: .authoritative
            )
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
                systemContext: systemContext,
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

    static func sourceFixture(for conversation: CoachChatConversationFixture) -> CoachChatEvaluationFixture? {
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
            "close overall", "drill caused", "practice caused",
            "objective proof", "proof that training", "proves transfer",
            "audience response is proof", "room response is proof"
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
                !(reply.contains("no") && containsAny(reply, ["before the close", "final sentence", "where the pressure", "where the pressure leaks"])) {
                return false
            }
            if user.contains("why after the decision line") && !reply.contains("decision") {
                return false
            }
            if user.contains("what was generic") &&
                !containsAny(reply, [
                    "actual behavior", "opener", "late opener",
                    "name the behavior", "behavior worth training"
                ]) {
                return false
            }
            if user.contains("stop saying practice more") &&
                !containsAny(reply, [
                    "not more volume", "cleaner first sentence",
                    "prior answer prescribed", "prescribed another drill",
                    "without assigning more practice", "one signal and one move"
                ]) {
                return false
            }
            if user.contains("less warm") &&
                !(reply.contains("no") && reply.contains("warmth")) {
                return false
            }
            if user.contains("7/10 bad") &&
                !(reply.contains("no") && containsAny(reply, [
                    "mechanics", "bottleneck", "rep score", "pressure"
                ])) {
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

    private enum ConversationDiscourseMove: String, CaseIterable {
        case answer
        case attune
        case diagnose
        case evidenceBoundary
        case prescribe
    }

    private static func variesDiscourseMoves(
        _ conversation: CoachChatConversationFixture
    ) -> Bool {
        guard conversation.turns.count >= 4 else { return true }

        let profiles = conversation.turns.map { discourseMoveProfile(in: $0.coachReply) }
        let profileKeys = profiles.map { profile in
            profile.map(\.rawValue).sorted().joined(separator: "+")
        }
        let uniqueProfileCount = Set(profileKeys).count
        let prescriptionOnlyCount = profiles.filter { profile in
            profile == Set([.prescribe])
        }.count
        let dominantCount = Dictionary(grouping: profileKeys, by: { $0 })
            .values
            .map(\.count)
            .max() ?? 0

        if prescriptionOnlyCount >= conversation.turns.count - 1 {
            return false
        }
        if dominantCount >= conversation.turns.count - 1 {
            return false
        }
        return uniqueProfileCount >= min(3, conversation.turns.count)
    }

    private static func discourseMoveProfile(
        in reply: String
    ) -> Set<ConversationDiscourseMove> {
        let lower = normalized(reply)
        var moves = Set<ConversationDiscourseMove>()

        if containsAny(lower, [
            "no,", "no.", "yes,", "yes.", "short version",
            "straight answer", "only after", "i would not claim",
            "not another", "not a harder", "not more",
            "placeholder ask", "check only", "write the audience response"
        ]) {
            moves.insert(.answer)
        }
        if containsAny(lower, [
            "fair push", "you're right", "you are right", "good boundary",
            "right distinction", "that matters", "that is useful",
            "useful push", "i missed", "i leaned on generic"
        ]) {
            moves.insert(.attune)
        }
        if containsAny(lower, [
            "the signal", "the pattern", "the issue", "the target",
            "the move", "the read", "the actual read", "the real read",
            "the bottleneck", "that tells us", "supports the",
            "outcome matters", "mechanics", "goal readiness",
            "solid on", "light on", "that is where",
            "listener asked", "asked for sequence"
        ]) {
            moves.insert(.diagnose)
        }
        if containsAny(lower, [
            "not enough", "missing", "too thin", "hypothesis",
            "from this sample", "from the transcript", "not proven",
            "need repeated", "before calling"
        ]) {
            moves.insert(.evidenceBoundary)
        }
        if !actionSentenceFingerprints(in: reply).isEmpty ||
            containsAny(lower, [
                "proof test", "next rep", "record", "run one",
                "rewrite", "review", "check whether", "listen for"
            ]) {
            moves.insert(.prescribe)
        }

        if moves.isEmpty {
            moves.insert(.answer)
        }
        return moves
    }

    private enum InterventionTarget: String, CaseIterable {
        case opening
        case close
        case pause
        case proof
        case tone
        case pressure
        case timeline
    }

    private static func preservesInterventionContinuity(
        _ conversation: CoachChatConversationFixture
    ) -> Bool {
        var priorTargets = Set<InterventionTarget>()
        var hasPriorCoachReply = false

        for turn in conversation.turns {
            let reply = normalized(turn.coachReply)
            let targets = interventionTargets(in: reply)

            if hasPriorCoachReply,
               containsAny(reply, [
                "forget what i said",
                "ignore what i said",
                "ignore the earlier",
                "new plan instead",
                "different target now",
                "actually change target",
                "actually, change target",
                "switch targets",
                "drop the previous target"
               ]) {
                return false
            }

            if hasPriorCoachReply,
               !targets.isEmpty,
               !targets.isSubset(of: priorTargets),
               negatesPriorTarget(in: reply, priorTargets: priorTargets),
               !explainsTargetRevision(reply) {
                return false
            }

            priorTargets.formUnion(targets)
            hasPriorCoachReply = true
        }

        return true
    }

    private static func interventionTargets(in reply: String) -> Set<InterventionTarget> {
        var targets = Set<InterventionTarget>()
        func add(_ target: InterventionTarget, ifAny needles: [String]) {
            if containsAny(reply, needles) {
                targets.insert(target)
            }
        }

        add(.opening, ifAny: [
            "sentence one", "first sentence", "opener", "opening",
            "verdict first", "verdict-first", "recommendation first",
            "lead with", "open with", "decision line"
        ])
        add(.close, ifAny: [
            "final sentence", "last sentence", "clean stop", "the close",
            "close ", "ask", "stop cleanly", "stop before"
        ])
        add(.pause, ifAny: [
            "pause", "beat", "silence", "filler", "fillers"
        ])
        add(.proof, ifAny: [
            "proof", "reason", "example", "concrete detail", "evidence line"
        ])
        add(.tone, ifAny: [
            "warmth", "reassurance", "tone", "natural", "stiff", "cold",
            "harsh", "abrupt"
        ])
        add(.pressure, ifAny: [
            "pressure", "timer", "timed", "stakes", "consequential"
        ])
        add(.timeline, ifAny: [
            "timeline", "sequence", "date", "next step"
        ])
        return targets
    }

    private static func negatesPriorTarget(
        in reply: String,
        priorTargets: Set<InterventionTarget>
    ) -> Bool {
        let targetPhrases: [(InterventionTarget, [String])] = [
            (.opening, ["not the opener", "not the opening", "not sentence one", "not the recommendation"]),
            (.close, ["not the close", "not the ask", "not the final sentence", "not the last sentence"]),
            (.pause, ["not the pause", "not the beat", "not the filler"]),
            (.proof, ["not the proof", "not the reason", "not the example"]),
            (.tone, ["not warmth", "not the tone", "not reassurance"]),
            (.pressure, ["not pressure", "not the timer", "not stakes"]),
            (.timeline, ["not the timeline", "not the sequence", "not the date"])
        ]
        return targetPhrases.contains { target, phrases in
            priorTargets.contains(target) && containsAny(reply, phrases)
        }
    }

    private static func explainsTargetRevision(_ reply: String) -> Bool {
        containsAny(reply, [
            "because",
            "that tells us",
            "the issue is",
            "the risk",
            "the bottleneck",
            "that outcome matters",
            "good boundary",
            "right distinction",
            "supports the structure hypothesis",
            "order improved faster than tone",
            "the ask may have been clear"
        ])
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
        guard replies.first.map({ containsAny($0, [
            "fair push", "you're right", "you’re right", "i missed",
            "advice not coaching", "should never"
        ]) }) == true else {
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

@Suite("CoachChatConversationCorpusTests", .serialized)
struct CoachChatConversationCorpusTests {

    @Test func appPathTargetUsesTheSamePresentationCopyContractAsPersistence() {
        let target = Self.persistedCoachReplyTarget(
            from: "The rolling baseline makes pacing the highest-leverage lever."
        )

        #expect(target == "Recent reps make pacing the main focus.")
    }

    @Test func conversationCorpusCoversFullThreeTurnTranscripts() {
        #expect(CoachChatConversationCorpus.conversations.count >= 13)
        for conversation in CoachChatConversationCorpus.conversations {
            #expect(conversation.turns.count == 3, "\(conversation.id) must be a full three-turn transcript")
            #expect(CoachChatEvaluationCorpus.fixtures.contains { $0.id == conversation.sourceFixtureID })
        }
    }

    @Test func longFormConversationCorpusCoversTenPlusEndToEndTranscripts() {
        #expect(CoachChatConversationCorpus.longFormConversations.count >= 10)

        let sourceIDs = Set(CoachChatEvaluationCorpus.fixtures.map(\.id))
        let allDepths = Set(
            CoachChatConversationCorpus.longFormConversations
                .flatMap(CoachChatConversationCorpus.turnDepthsByTurn(in:))
        )
        let pushbackConversationCount = CoachChatConversationCorpus.longFormConversations
            .filter(CoachChatConversationCorpus.userPushbackWithinTwoTurns(in:))
            .count
        let softPushbackConversationCount = CoachChatConversationCorpus.longFormConversations
            .filter { !CoachChatConversationCorpus.softPushbackTurnIndices(in: $0).isEmpty }
            .count

        for conversation in CoachChatConversationCorpus.longFormConversations {
            #expect(conversation.id.hasPrefix("long-form-"))
            #expect(conversation.turns.count >= 5, "\(conversation.id) must be a full end-to-end transcript")
            #expect(sourceIDs.contains(conversation.sourceFixtureID))
            let finalReply = conversation.turns.last?.coachReply.lowercased() ?? ""
            let finalUserTurn = conversation.turns.last?.userTurn
            if CoachChatTurnIntent.isCoachStyleFeedback(finalUserTurn) {
                #expect(!CoachReliabilityGate.conversationalTrustRepairNeedsCorrection(finalReply))
            } else {
                #expect(["check", "after", "compare", "record"].contains {
                    finalReply.contains($0)
                })
            }
        }

        #expect(pushbackConversationCount >= 3)
        #expect(softPushbackConversationCount >= 1)
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

    @Test func genericWrapperTrustRepairClearsVisionFloor() {
        let reply = "You're right—that sounded templated. I'll keep the next answer plain and name one specific point."
        let vision = AICoachChatService.coachVisionEvaluation(
            reply: reply,
            latestUserTurn: "This feels like a generic AI wrapper.",
            turnDepth: .trustRepair,
            surface: .text
        )

        #expect(vision.passesProductionFloor,
                "Generic-wrapper trust repair scored \(vision.score), missed \(vision.missed)")
        #expect(vision.earned.contains(.adaptiveRepair))
        #expect(vision.earned.contains(.insightBridge))
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

    @Test func sameDiscourseMoveVariantsFailDiversityGate() {
        let source = CoachChatConversationCorpus.longFormConversations[8]
        let sameMove = CoachChatConversationCorpus.sameDiscourseMoveVariant(for: source)
        let score = CoachChatConversationCorpus.evaluate(sameMove)

        #expect(score.missed.contains(.discourseMoveDiversity),
                "\(sameMove.id) should miss discourse move diversity, earned \(score.earned)")
        #expect(!score.missed.contains(.nonRepetitiveTrajectory),
                "\(sameMove.id) should vary wording enough to isolate discourse move repetition")
        #expect(!score.missed.contains(.proofTestProgression),
                "\(sameMove.id) should vary proof actions enough to isolate discourse move repetition")
        #expect(!score.passesConversationFloor)
    }

    @Test func silentPlanSwitchVariantsFailPlanContinuityGate() {
        let source = CoachChatConversationCorpus.longFormConversations[6]
        let switched = CoachChatConversationCorpus.silentPlanSwitchVariant(for: source)
        let score = CoachChatConversationCorpus.evaluate(switched)
        let issues = CoachChatConversationCorpus.reliabilityIssues(in: switched)

        #expect(score.missed.contains(.planContinuity),
                "\(switched.id) should miss plan continuity, earned \(score.earned)")
        #expect(issues.contains(.silentPlanSwitch),
                "\(switched.id) should trip runtime silentPlanSwitch, got \(issues)")
        #expect(!score.passesConversationFloor)
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
            #expect(
                issues.contains(.noAttunementOnPushback) || issues.contains(.thinTrustRepair),
                "\(conversation.id) no-attunement variant should trip the lane-specific repair issue, got \(issues)"
            )
        }

        let thinTrustRepairVariants = CoachChatConversationCorpus.conversations.compactMap {
            CoachChatConversationCorpus.thinTrustRepairVariant(for: $0)
        }
        #expect(thinTrustRepairVariants.count >= 3)
        for conversation in thinTrustRepairVariants {
            let issues = CoachChatConversationCorpus.reliabilityIssues(in: conversation)
            #expect(!issues.contains(.noAttunementOnPushback),
                    "\(conversation.id) thin repair variant should acknowledge the push, got \(issues)")
            #expect(issues.contains(.thinTrustRepair),
                    "\(conversation.id) thin repair variant should trip thinTrustRepair, got \(issues)")
        }

        let repairCarryoverBreakVariants = CoachChatConversationCorpus.conversations.compactMap {
            CoachChatConversationCorpus.repairCarryoverBreakVariant(for: $0)
        }
        #expect(repairCarryoverBreakVariants.count >= 3)
        for conversation in repairCarryoverBreakVariants {
            let issues = CoachChatConversationCorpus.reliabilityIssues(in: conversation)
            #expect(issues.contains(.repairCarryoverBreak),
                    "\(conversation.id) carryover-break variant should trip repairCarryoverBreak, got \(issues)")
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
            if let thinRepair = CoachChatConversationCorpus
                .thinTrustRepairVariant(for: conversation) {
                variants.append(thinRepair)
            }
            if let repairCarryover = CoachChatConversationCorpus
                .repairCarryoverBreakVariant(for: conversation) {
                variants.append(repairCarryover)
            }
        }

        let report = CoachChatConversationEvaluationReport.make(from: variants)
        #expect(!report.rows.isEmpty)
        #expect(report.summary.reliabilityIssueCounts["thinTrustRepair", default: 0] >= 3)
        #expect(report.summary.reliabilityIssueCounts["repairCarryoverBreak", default: 0] >= 3)
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
                    userTurn: "That is wrong about my last rep; the recommendation was early.",
                    coachReply: "Fair push: that sounded cold, not like a human coach read. Proof test: record one verdict-first rep."
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

    @Test func politePushbackCannotPassSemanticGateBySayingBut() {
        let conversation = CoachChatConversationFixture(
            id: "semantic-gate-polite-pushback-but-only",
            sourceFixtureID: "assistant-explainer-register",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "Okay, but that doesn't answer what happened in my last rep.",
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

    @Test func transferCausalityClaimFailsProductionFloorInReport() {
        let conversation = CoachChatConversationFixture(
            id: "semantic-gate-transfer-causality",
            sourceFixtureID: "leadership-transfer-setup",
            turns: [
                CoachChatConversationTurn(
                    userTurn: "What should I capture now?",
                    coachReply: "That proves the 75-second close drill caused the room to engage. The audience response is objective proof that training transferred."
                )
            ]
        )
        let report = CoachChatConversationEvaluationReport.make(from: [conversation])
        let row = report.rows[0]

        #expect(!row.passesSemanticGate)
        #expect(!row.passesProductionFloor)
        #expect(row.semanticIssues.contains("semantic:unsupportedTransferCausalityClaim"))
        #expect(row.turnSemanticIssues == [["semantic:unsupportedTransferCausalityClaim"]])
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
                "No. Use one beat before the final sentence as the test, because pausing everywhere changes too much at once to show whether that one timing move helped."
            ),
            (
                "Why after the decision line?",
                "Because the filler interrupts the moment where authority should sound settled. The pause after the decision gives your reason somewhere to go without weakening the recommendation."
            ),
            (
                "Give me the short version.",
                "The opener is the target because the prior reply buried it. Put the point in sentence one, add one reason, stop, then check whether the setup stayed out."
            ),
            (
                "And stop saying practice more.",
                "You're right—I prescribed another drill instead of answering. I'll answer the point directly without assigning more practice."
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
                "What should Noum judge after?",
                "In the next rep, judge only whether sentence one answered the question before context, because that is the first baseline. If it warmed up first, rewrite sentence one and run the same prompt again."
            ),
            (
                "What if I sound too direct?",
                "Direct is fine when the reason comes before the ask; keep that order, then stop. Do not apologise after the ask, because that reopens the decision."
            ),
            (
                "What do I repeat?",
                "Repeat the final sentence only: ask, period, because that isolates the confidence leak. If you add a qualifier after it, rewrite that same line until it ends cleanly."
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
        #expect(markdownRepair.trustRepairTurnIndices == [0, 1])
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
        #expect(report.conversationCount == CoachChatConversationCorpus.conversations.count)
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

        let expectedLongFormCount = CoachChatConversationCorpus.longFormConversations.count
        #expect(report.schemaVersion == CoachChatConversationCorpus.longFormReportSchemaVersion)
        #expect(report.conversationCount == expectedLongFormCount)
        #expect(report.rows.count == expectedLongFormCount)
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
        #expect(report.summary.rowsPassingConversationFloor == expectedLongFormCount)
        #expect(report.summary.rowsPassingRuntimeGate == expectedLongFormCount)
        #expect(report.summary.rowsPassingSemanticGate == expectedLongFormCount)
        #expect(report.summary.rowsPassingReliabilityGate == expectedLongFormCount)
        #expect(report.summary.rowsPassingProductionFloor == expectedLongFormCount)
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
        #expect(json.contains("\"conversationID\":\"long-form-polite-pushback-attunement-conversation\""))
        #expect(json.contains("\"summary\""))
        #expect(json.contains("\"rowsPassingProductionFloor\":\(expectedLongFormCount)"))
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
        let expectedAdversarialCount = CoachChatConversationCorpus.longFormConversations.count
        #expect(report.conversationCount == expectedAdversarialCount)
        #expect(report.rows.count == expectedAdversarialCount)
        #expect(report.rows.allSatisfy { $0.turns.count >= 5 })
        #expect(report.rows.allSatisfy { !$0.passesProductionFloor })
        #expect(report.summary.rowsPassingProductionFloor == 0)
        #expect(report.summary.productionFloorFailureConversationIDs.count == expectedAdversarialCount)
        #expect(report.summary.semanticIssueCounts["semantic:missingIntentFit", default: 0] >= 5)
        #expect(report.summary.semanticIssueCounts["semantic:unsupportedTransferCausalityClaim", default: 0] >= 1)
        #expect(report.summary.reliabilityIssueCounts["repeatedProofTest", default: 0] >= 2)
        let missingRepairOwnershipCount =
            report.summary.reliabilityIssueCounts["noAttunementOnPushback", default: 0] +
            report.summary.reliabilityIssueCounts["thinTrustRepair", default: 0]
        #expect(missingRepairOwnershipCount >= 2)
        #expect(report.summary.reliabilityIssueCounts["silentPlanSwitch", default: 0] >= 1)
        #expect(report.summary.reliabilityIssueCounts["repairCarryoverBreak", default: 0] >= 1)
        #expect(report.summary.reliabilityIssueCounts["repetitiveDiscourseMove", default: 0] >= 1)
        #expect(report.visionProductionReadiness.score <= 18)
        #expect(!report.visionProductionReadiness.productionReady)
        #expect(report.rows.contains { row in
            row.missed.contains(CoachChatConversationCriterion.discourseMoveDiversity.rawValue)
        })
        #expect(json.contains("\"schemaVersion\":\"coach-chat-long-form-adversarial-eval-v1\""))
        #expect(json.contains("\"conversationID\":\"long-form-authoritative-distance-deep-assessment-conversation-silent-plan-switch\""))
        #expect(json.contains("\"conversationID\":\"long-form-assistant-explainer-register-conversation-repair-carryover-break\""))
        #expect(json.contains("\"conversationID\":\"long-form-polite-pushback-attunement-conversation-no-attunement\""))
        #expect(json.contains("\"conversationID\":\"long-form-overclaim-hypothesis-boundary-conversation-same-discourse-move\""))
        #expect(json.contains("\"conversationID\":\"long-form-leadership-transfer-setup-conversation-transfer-causality\""))
        #expect(json.contains("\"discourseMoveDiversity\""))
        #expect(json.contains("\"semantic:missingIntentFit\""))
        #expect(json.contains("\"semantic:unsupportedTransferCausalityClaim\""))
        #expect(json.contains("\"repeatedProofTest\""))
        #expect(json.contains("\"silentPlanSwitch\""))
        #expect(json.contains("\"repairCarryoverBreak\""))
        #expect(json.contains("\"repetitiveDiscourseMove\""))
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
        #expect(packet.rubricVersion == CoachProfessionalCalibrationEvidence.expectedRubricVersion)
        #expect(packet.sourceCorpusFingerprint == CoachProfessionalCalibrationEvidence.expectedSourcePacketFingerprint)
        #expect(packet.sourceCorpusFingerprint.hasPrefix("fnv1a64:"))
        #expect(packet.humanGateStatus == .pendingExpertReview)
        #expect(packet.conversationCount == CoachProfessionalCalibrationEvidence.requiredConversationIDs.count)
        #expect(packet.rows.count == CoachProfessionalCalibrationEvidence.requiredConversationIDs.count)
        #expect(
            packet.requiredIndependentReviewsPerConversation ==
                CoachProfessionalCalibrationEvidence.requiredReviewsPerConversation
        )
        #expect(packet.requiredReviewCount == CoachProfessionalCalibrationEvidence.requiredCalibrationReviewCount)
        #expect(packet.instructions.contains("do not assume the app is validated or production-ready"))
        #expect(packet.instructions.contains("two independent professional communication-coach reviews"))
        #expect(packet.instructions.contains("longitudinal user outcomes"))
        #expect(packet.responseSchema.contains("\"calibrationDecision\""))
        #expect(packet.responseSchema.contains("\"reviewerID\""))
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

        #expect(packet.rows.filter { $0.turns.count == 3 }.count == CoachChatConversationCorpus.conversations.count)
        #expect(packet.rows.filter { $0.turns.count == 5 }.count == CoachChatConversationCorpus.longFormConversations.count)
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
            fileName: "\(CoachChatConversationCorpus.expertCalibrationPacketSchemaVersion).json"
        )

        #expect(json.contains("\"schemaVersion\":\"coach-chat-conversation-expert-calibration-v2\""))
        #expect(json.contains("\"sourceCorpusFingerprint\":\"fnv1a64:"))
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
        let expectedConversationCount = CoachChatConversationCorpus.appPathConversations.count
        let expectedTurnCount = CoachChatConversationCorpus.appPathConversations.flatMap(\.turns).count
        let targetReport = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.appPathConversations
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
        #expect(report.conversationCount == expectedConversationCount)
        #expect(report.turnCount == expectedTurnCount)
        #expect(report.summary.conversationCount == expectedConversationCount)
        #expect(report.summary.turnCount == expectedTurnCount)

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
        let targetReplyMismatchCount = appPathTurns
            .filter { !$0.targetReplyMatched }
            .count
        let missingMetadataTurnCount = appPathTurns
            .filter { !$0.metadataPresent }
            .count
        let semanticGateFailureTurnCount = appPathTurns
            .filter { !$0.semanticGateExpectationSatisfied }
            .count
        let qualityGateEventTotal = report.summary.qualityGateEventCounts.values.reduce(0, +)
        let qualityGateEvents = appPathTurns.flatMap(\.qualityGateEvents)
        let acceptedFallbackTurnCount = appPathTurns.filter(\.qualityGateAcceptedFallback).count
        let typedAssessmentFallbackTurnCount = appPathTurns.filter(\.typedAssessmentFallbackApplied).count
        let deterministicAssessmentFallbackTurnCount = appPathTurns.filter(\.deterministicAssessmentFallbackApplied).count
        let reliabilityIssueTurnCount = appPathTurns.filter { !$0.reliabilityIssues.isEmpty }.count
        let blockingReliabilityIssueTurnCount = appPathTurns.filter(\.hasBlockingReliabilityIssue).count
        #expect(appPathFloorFailureCount == 0)
        #expect(semanticGateFailureTurnCount == 0)
        #expect(report.passesAppPathFloor)
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
        if targetReplyMismatchCount == 0 {
            #expect(!report.summary.readinessWarnings.contains(
                CoachChatConversationAppPathWarning.targetReplyMismatch.rawValue
            ))
        } else {
            #expect(report.summary.readinessWarnings.contains(
                CoachChatConversationAppPathWarning.targetReplyMismatch.rawValue
            ))
        }
        if semanticGateFailureTurnCount == 0 {
            #expect(!report.summary.readinessWarnings.contains(
                CoachChatConversationAppPathWarning.semanticGateFailures.rawValue
            ))
        } else {
            #expect(report.summary.readinessWarnings.contains(
                CoachChatConversationAppPathWarning.semanticGateFailures.rawValue
            ))
        }
        #expect(report.summary.targetReplyMismatchCount == targetReplyMismatchCount)
        #expect(report.summary.missingMetadataTurnCount == missingMetadataTurnCount)
        #expect(report.summary.semanticGateFailureTurnCount == semanticGateFailureTurnCount)
        #expect(qualityGateEventTotal == qualityGateEvents.count)
        #expect(report.summary.acceptedFallbackTurnCount == acceptedFallbackTurnCount)
        #expect(report.summary.typedAssessmentFallbackTurnCount == typedAssessmentFallbackTurnCount)
        #expect(report.summary.deterministicAssessmentFallbackTurnCount == deterministicAssessmentFallbackTurnCount)
        #expect(report.summary.reliabilityIssueTurnCount == reliabilityIssueTurnCount)
        #expect(report.summary.blockingReliabilityIssueTurnCount == blockingReliabilityIssueTurnCount)
        if blockingReliabilityIssueTurnCount == 0 {
            #expect(!report.summary.readinessWarnings.contains(
                CoachChatConversationAppPathWarning.reliabilityIssues.rawValue
            ))
        } else {
            #expect(report.summary.readinessWarnings.contains(
                CoachChatConversationAppPathWarning.reliabilityIssues.rawValue
            ))
        }
        #expect(report.summary.qualityGateBlockingFailureTurnCount ==
            appPathTurns.filter(\.qualityGateBlockingFailure).count)
        let explicitlyStyledTurns = appPathTurns.filter {
            $0.semanticGateExpectation == .passedWithTypedAssessment
        }
        let neutralTurns = appPathTurns.filter {
            $0.semanticGateExpectation == .notEvaluatedWithoutTypedAssessment
        }
        #expect(explicitlyStyledTurns.allSatisfy {
            $0.assessmentConfidence != nil &&
                $0.semanticGateExpectation == .passedWithTypedAssessment &&
                $0.semanticGatePassed &&
                $0.typedAssessmentPresent &&
                $0.semanticGateExpectationSatisfied
        })
        #expect(neutralTurns.allSatisfy {
            $0.assessmentConfidence == nil &&
                $0.semanticGateExpectation == .notEvaluatedWithoutTypedAssessment &&
                $0.semanticGateOutcome == "notEvaluated" &&
                !$0.semanticGatePassed &&
                !$0.typedAssessmentPresent &&
                $0.proofTestHash == nil &&
                !$0.immediateCoachReadExpected &&
                !$0.immediateCoachReadShown &&
                $0.semanticGateExpectationSatisfied
        })
        #expect(appPathTurns.allSatisfy { $0.retrievalTrace != nil })
        let liveLatencyRow = try #require(report.rows.first {
            $0.sourceFixtureID == "live-latency-short-044"
        })
        let liveLatencyRetrieval = try #require(liveLatencyRow.turns.first?.retrievalTrace)
        #expect(liveLatencyRetrieval.retrievedCardIDs.contains {
            $0.contains("close")
        })
        #expect(appPathTurns.allSatisfy { $0.arenaTrace != nil })
        let appPathPromptModules = appPathTurns.compactMap { $0.arenaTrace?.prompt.modules }
        #expect(appPathPromptModules.count == expectedTurnCount)
        #expect(appPathPromptModules.allSatisfy { modules in
            modules.contains { module in
                module.name == "coachSystemPrompt" && module.cachePolicy == .ephemeral
            }
        })
        #expect(appPathPromptModules.allSatisfy { modules in
            modules.contains { module in
                module.name == "userContext" && module.cachePolicy == .none
            }
        })
        #expect(report.summary.retrievalTracePresentCount == expectedTurnCount)
        let trajectoryCacheHitCount = appPathTurns.filter { $0.trajectoryCacheHit == true }.count
        #expect(report.summary.trajectoryCacheHitCount == trajectoryCacheHitCount)
        #expect(report.summary.trajectoryCacheMissingTelemetryCount == 0)
        #expect(report.summary.minimumTrajectoryCacheHitCount ==
            CoachChatConversationAppPathSummary.minimumTrajectoryCacheHitCount(for: expectedTurnCount))
        // Cache state is captured from the real pipeline and proves the caching layer is
        // exercised end-to-end: the first turn of a conversation computes the trajectory
        // (cold miss) and later turns reuse the cached UserTrajectory snapshot (warm hit).
        #expect(appPathTurns.contains { $0.trajectoryCacheHit == false })
        #expect(appPathTurns.contains { $0.trajectoryCacheHit == true })
        #expect(report.summary.trajectoryCacheHitCount >= report.summary.minimumTrajectoryCacheHitCount)
        // The harness injects each conversation's real source-fixture practice
        // sessions (scriptedConversationAppPathRows -> sessionsOverride), so
        // UserTrajectory.evidenceCoverage varies per conversation and
        // CoachReasoningPass raises assessmentConfidence above the 0.20 thin-evidence
        // floor legitimately — driven by genuine evidence, not fabrication. Cold-start
        // conversations with no sessions correctly stay at 0.20; evidence-rich ones
        // rise. That produces a real spread of distinct rounded values and clears the
        // flatAssessmentConfidence warning. Calibration is additionally pinned by
        // CoachJudgementLayerTests.assessmentConfidenceMovesWithEvidenceCoverage.
        #expect(report.summary.assessmentConfidenceDistinctRoundedCount >= 3)
        #expect(report.summary.uniqueProofTestHashCount >= 3)
        #expect(report.summary.repeatedProofTestHashCount == 0)
        #expect(!report.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.missingRetrievalTrace.rawValue
        ))
        #expect(!report.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.missingTrajectoryCacheTelemetry.rawValue
        ))
        #expect(!report.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.weakTrajectoryCacheCoverage.rawValue
        ))
        #expect(!report.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.flatAssessmentConfidence.rawValue
        ))
        #expect(!report.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.weakProofTestVariety.rawValue
        ))
        #expect(appPathTurns.contains { !$0.qualityGateEvents.isEmpty })
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
        #expect(json.contains("\"deterministicAssessmentFallbackTurnCount\""))
        #expect(json.contains("\"deterministicAssessmentFallbackApplied\""))
        #expect(json.contains("\"qualityGateBlockingFailureTurnCount\""))
        #expect(json.contains("\"visionFloorFailureTurnCount\""))
        #expect(json.contains("\"blockingReliabilityIssueTurnCount\""))
        #expect(json.contains("\"retrievalTracePresentCount\""))
        #expect(json.contains("\"retrievalTrace\""))
        #expect(json.contains("\"retrievedCardIDs\""))
        #expect(json.contains("\"trajectoryCacheHitCount\""))
        #expect(json.contains("\"trajectoryCacheMissingTelemetryCount\":0"))
        #expect(json.contains("\"minimumTrajectoryCacheHitCount\""))
        #expect(json.contains("\"arenaTrace\""))
        #expect(json.contains("\"coachSystemPrompt\""))
        #expect(json.contains("\"cachePolicy\":\"ephemeral\""))
        #expect(json.contains("\"userContext\""))
        #expect(json.contains("\"traceSchemaVersion\":\"coach-arena-app-path-trace-v3\""))
        #expect(json.contains("\"timeToFirstVisibleTokenSource\""))
        #expect(json.contains("\"assessmentConfidenceDistinctRoundedCount\""))
        #expect(json.contains("\"uniqueProofTestHashCount\""))
        #expect(json.contains("\"repeatedProofTestHashCount\""))
        #expect(json.contains("\"assessmentConfidence\""))
        #expect(json.contains("\"semanticGateExpectation\":\"passedWithTypedAssessment\""))
        #expect(json.contains("\"semanticGateExpectation\":\"notEvaluatedWithoutTypedAssessment\""))
        #expect(json.contains("\"typedAssessmentPresent\":false"))
        #expect(json.contains("\"qualityGateEvents\""))
        #expect(json.contains("\"visionProductionReadiness\""))
        #expect(json.contains("\"conversationID\":\"polite-pushback-attunement-conversation\""))
        #expect(json.contains("\"turnIndex\":2"))
    }

    @MainActor
    @Test func scriptedLiveConversationAppPathReportProvesTwoSpeedLocalReadWithoutClaimingReadiness() async throws {
        let rows = await Self.scriptedConversationAppPathRows(surface: .live)
        let expectedConversationCount = CoachChatConversationCorpus.appPathConversations.count
        let expectedTurnCount = CoachChatConversationCorpus.appPathConversations.flatMap(\.turns).count
        let targetReport = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.appPathConversations
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
        #expect(report.conversationCount == expectedConversationCount)
        #expect(report.turnCount == expectedTurnCount)

        let turns = report.rows.flatMap(\.turns)
        let explicitlyStyledTurns = turns.filter {
            $0.semanticGateExpectation == .passedWithTypedAssessment
        }
        let neutralTurns = turns.filter {
            $0.semanticGateExpectation == .notEvaluatedWithoutTypedAssessment
        }
        let expectedImmediateReadCount = explicitlyStyledTurns.count
        #expect(report.summary.immediateCoachReadExpectedCount == expectedImmediateReadCount)
        #expect(report.summary.immediateCoachReadMissingCount == 0)
        #expect(explicitlyStyledTurns.allSatisfy { $0.immediateCoachReadExpected })
        #expect(explicitlyStyledTurns.allSatisfy { $0.immediateCoachReadShown })
        #expect(explicitlyStyledTurns.allSatisfy {
            ($0.timeToFirstVisibleTokenMs ?? Int.max) < 500
        })
        #expect(explicitlyStyledTurns.allSatisfy {
            $0.timeToFirstVisibleTokenSource == CoachFirstVisibleTokenSource.localImmediateRead.rawValue
        })
        #expect(explicitlyStyledTurns.allSatisfy {
            $0.assessmentConfidence != nil &&
                $0.semanticGateExpectation == .passedWithTypedAssessment &&
                $0.semanticGatePassed &&
                $0.typedAssessmentPresent &&
                $0.semanticGateExpectationSatisfied
        })
        #expect(neutralTurns.allSatisfy { !$0.immediateCoachReadExpected })
        #expect(neutralTurns.allSatisfy { !$0.immediateCoachReadShown })
        #expect(neutralTurns.allSatisfy {
            $0.assessmentConfidence == nil &&
                $0.semanticGateExpectation == .notEvaluatedWithoutTypedAssessment &&
                $0.semanticGateOutcome == "notEvaluated" &&
                !$0.semanticGatePassed &&
                !$0.typedAssessmentPresent &&
                $0.proofTestHash == nil &&
                $0.semanticGateExpectationSatisfied
        })
        #expect(neutralTurns.allSatisfy {
            $0.timeToFirstVisibleTokenSource == CoachFirstVisibleTokenSource.finalReplyCommit.rawValue
        })
        let targetReplyMismatchCount = turns.filter { !$0.targetReplyMatched }.count
        let missingMetadataTurnCount = turns.filter { !$0.metadataPresent }.count
        let semanticGateFailureTurnCount = turns
            .filter { !$0.semanticGateExpectationSatisfied }
            .count
        let qualityGateEventTotal = report.summary.qualityGateEventCounts.values.reduce(0, +)
        let qualityGateEvents = turns.flatMap(\.qualityGateEvents)
        #expect(semanticGateFailureTurnCount == 0)
        #expect(report.passesAppPathFloor)
        #expect(report.summary.targetReplyMismatchCount == targetReplyMismatchCount)
        #expect(report.summary.missingMetadataTurnCount == missingMetadataTurnCount)
        #expect(report.summary.semanticGateFailureTurnCount == semanticGateFailureTurnCount)
        #expect(qualityGateEventTotal == qualityGateEvents.count)
        #expect(report.summary.acceptedFallbackTurnCount == turns.filter(\.qualityGateAcceptedFallback).count)
        #expect(report.summary.typedAssessmentFallbackTurnCount == turns.filter(\.typedAssessmentFallbackApplied).count)
        #expect(report.summary.deterministicAssessmentFallbackTurnCount == turns.filter(\.deterministicAssessmentFallbackApplied).count)
        #expect(report.summary.qualityGateBlockingFailureTurnCount == turns.filter(\.qualityGateBlockingFailure).count)
        #expect(report.summary.reliabilityIssueTurnCount == turns.filter { !$0.reliabilityIssues.isEmpty }.count)
        #expect(report.summary.blockingReliabilityIssueTurnCount == turns.filter(\.hasBlockingReliabilityIssue).count)
        if semanticGateFailureTurnCount == 0 {
            #expect(!report.summary.readinessWarnings.contains(
                CoachChatConversationAppPathWarning.semanticGateFailures.rawValue
            ))
        } else {
            #expect(report.summary.readinessWarnings.contains(
                CoachChatConversationAppPathWarning.semanticGateFailures.rawValue
            ))
        }
        #expect(turns.allSatisfy { $0.retrievalTrace != nil })
        #expect(turns.allSatisfy { $0.arenaTrace != nil })
        let livePromptModules = turns.compactMap { $0.arenaTrace?.prompt.modules }
        #expect(livePromptModules.count == expectedTurnCount)
        #expect(livePromptModules.allSatisfy { modules in
            modules.contains { module in
                module.name == "coachSystemPrompt" && module.cachePolicy == .ephemeral
            }
        })
        #expect(livePromptModules.allSatisfy { modules in
            modules.contains { module in
                module.name == "userContext" && module.cachePolicy == .none
            }
        })
        #expect(report.summary.retrievalTracePresentCount == expectedTurnCount)
        let trajectoryCacheHitCount = turns.filter { $0.trajectoryCacheHit == true }.count
        #expect(report.summary.trajectoryCacheHitCount == trajectoryCacheHitCount)
        #expect(report.summary.trajectoryCacheMissingTelemetryCount == 0)
        #expect(report.summary.minimumTrajectoryCacheHitCount ==
            CoachChatConversationAppPathSummary.minimumTrajectoryCacheHitCount(for: expectedTurnCount))
        #expect(report.summary.trajectoryCacheHitCount >= report.summary.minimumTrajectoryCacheHitCount)
        // Injected source-fixture sessions (see the text-surface test above) give the
        // trajectory real, per-conversation evidence coverage, so assessmentConfidence
        // rises above the 0.20 thin-evidence floor legitimately and the distinct-value
        // spread clears the flatAssessmentConfidence warning.
        #expect(report.summary.assessmentConfidenceDistinctRoundedCount >= 3)
        #expect(report.summary.uniqueProofTestHashCount >= 3)
        #expect(report.summary.repeatedProofTestHashCount == 0)
        #expect(!report.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.missingRetrievalTrace.rawValue
        ))
        #expect(!report.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.missingTrajectoryCacheTelemetry.rawValue
        ))
        #expect(!report.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.weakTrajectoryCacheCoverage.rawValue
        ))
        #expect(!report.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.flatAssessmentConfidence.rawValue
        ))
        #expect(!report.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.weakProofTestVariety.rawValue
        ))
        #expect(report.visionProductionReadiness.score <= 18)
        #expect(report.visionProductionReadiness.maximumAllowedScore == 20)
        #expect(report.visionProductionReadiness.claim == .localEvaluationSubstrateOnly)
        #expect(!report.visionProductionReadiness.productionReady)
        #expect(report.visionProductionReadiness.blockers.contains(.noLiveProviderTranscriptSweep))
        #expect(json.contains("\"schemaVersion\":\"coach-chat-live-app-path-eval-v1\""))
        #expect(json.contains("\"surface\":\"live\""))
        #expect(json.contains("\"immediateCoachReadExpectedCount\":\(expectedImmediateReadCount)"))
        #expect(json.contains("\"immediateCoachReadMissingCount\":0"))
        #expect(json.contains("\"retrievalTracePresentCount\""))
        #expect(json.contains("\"retrievalTrace\""))
        #expect(json.contains("\"retrievedCardIDs\""))
        #expect(json.contains("\"trajectoryCacheHitCount\""))
        #expect(json.contains("\"trajectoryCacheMissingTelemetryCount\":0"))
        #expect(json.contains("\"minimumTrajectoryCacheHitCount\""))
        #expect(json.contains("\"arenaTrace\""))
        #expect(json.contains("\"coachSystemPrompt\""))
        #expect(json.contains("\"cachePolicy\":\"ephemeral\""))
        #expect(json.contains("\"userContext\""))
        #expect(json.contains("\"traceSchemaVersion\":\"coach-arena-app-path-trace-v3\""))
        #expect(json.contains("\"timeToFirstVisibleTokenSource\":\"localImmediateRead\""))
        #expect(json.contains("\"assessmentConfidenceDistinctRoundedCount\""))
        #expect(json.contains("\"uniqueProofTestHashCount\""))
        #expect(json.contains("\"repeatedProofTestHashCount\""))
        #expect(json.contains("\"assessmentConfidence\""))
        #expect(json.contains("\"semanticGateExpectation\":\"passedWithTypedAssessment\""))
        #expect(json.contains("\"semanticGateExpectation\":\"notEvaluatedWithoutTypedAssessment\""))
        #expect(json.contains("\"typedAssessmentPresent\":false"))
        #expect(json.contains("\"visionProductionReadiness\""))
    }

    @Test func appPathSemanticExpectationAcceptsOnlyDeclaredNeutralTelemetry() {
        let coldStart = CoachChatConversationAppPathSemanticExpectation
            .forFixtureID("cold-start-interview-baseline")
        let supplemental = CoachChatConversationAppPathSemanticExpectation
            .forFixtureID("outcome-not-causation-027")

        #expect(coldStart == .notEvaluatedWithoutTypedAssessment)
        #expect(supplemental == .notEvaluatedWithoutTypedAssessment)
        #expect(CoachChatConversationCorpus.assessmentProvenance(
            for: "outcome-not-causation-027"
        ) == .explicitNeutral)
        let supplementalNeutralScripts = CoachChatConversationCorpus
            .appPathConversationScripts
            .filter { $0.assessmentProvenance == .explicitNeutral }
        #expect(supplementalNeutralScripts.count == 25)
        #expect(Set(supplementalNeutralScripts.map {
            $0.conversation.sourceFixtureID
        }).count == supplementalNeutralScripts.count)
        #expect(supplementalNeutralScripts.allSatisfy {
            CoachChatConversationAppPathSemanticExpectation
                .forFixtureID($0.conversation.sourceFixtureID) ==
                .notEvaluatedWithoutTypedAssessment
        })
        #expect(supplemental.isSatisfied(
            semanticGateOutcome: "notEvaluated",
            typedAssessmentPresent: false,
            assessmentConfidence: nil,
            proofTestHash: nil,
            immediateCoachReadExpected: false,
            immediateCoachReadShown: false
        ))
        #expect(!supplemental.isSatisfied(
            semanticGateOutcome: "passed",
            typedAssessmentPresent: false,
            assessmentConfidence: nil,
            proofTestHash: nil,
            immediateCoachReadExpected: false,
            immediateCoachReadShown: false
        ))
        #expect(!supplemental.isSatisfied(
            semanticGateOutcome: "notEvaluated",
            typedAssessmentPresent: false,
            assessmentConfidence: nil,
            proofTestHash: "fabricated-neutral-proof",
            immediateCoachReadExpected: false,
            immediateCoachReadShown: false
        ))
        #expect(!supplemental.isSatisfied(
            semanticGateOutcome: "notEvaluated",
            typedAssessmentPresent: false,
            assessmentConfidence: nil,
            proofTestHash: nil,
            immediateCoachReadExpected: false,
            immediateCoachReadShown: true
        ))
    }

    @Test func appPathSemanticExpectationRejectsStyledMissingAssessment() {
        let styled = CoachChatConversationAppPathSemanticExpectation
            .forFixtureID("filler-pressure-prescription")

        #expect(styled == .passedWithTypedAssessment)
        #expect(!styled.isSatisfied(
            semanticGateOutcome: "passed",
            typedAssessmentPresent: false,
            assessmentConfidence: nil,
            proofTestHash: nil,
            immediateCoachReadExpected: false,
            immediateCoachReadShown: false
        ))
        #expect(!styled.isSatisfied(
            semanticGateOutcome: "passed",
            typedAssessmentPresent: true,
            assessmentConfidence: 0.72,
            proofTestHash: nil,
            immediateCoachReadExpected: false,
            immediateCoachReadShown: false
        ))
        #expect(styled.isSatisfied(
            semanticGateOutcome: "passed",
            typedAssessmentPresent: true,
            assessmentConfidence: 0.72,
            proofTestHash: "proof-test",
            immediateCoachReadExpected: true,
            immediateCoachReadShown: true
        ))
    }

    @Test func appPathSemanticExpectationFailsClosedForUnknownFixture() {
        let unknownID = "future-app-path-fixture-without-provenance"
        let unknown = CoachChatConversationAppPathSemanticExpectation
            .forFixtureID(unknownID)

        #expect(CoachChatConversationCorpus.assessmentProvenance(
            for: unknownID
        ) == nil)
        #expect(unknown == .unknownFixtureFailClosed)
        #expect(!unknown.isSatisfied(
            semanticGateOutcome: "notEvaluated",
            typedAssessmentPresent: false,
            assessmentConfidence: nil,
            proofTestHash: nil,
            immediateCoachReadExpected: false,
            immediateCoachReadShown: false
        ))
        #expect(!unknown.isSatisfied(
            semanticGateOutcome: "passed",
            typedAssessmentPresent: true,
            assessmentConfidence: 0.72,
            proofTestHash: "proof-test",
            immediateCoachReadExpected: true,
            immediateCoachReadShown: true
        ))
    }

    @Test func appPathReportSummaryWarnsForUnknownSemanticProvenance() throws {
        let clean = Self.cleanAppPathReport(
            surface: .text,
            schemaVersion: CoachChatConversationCorpus.appPathReportSchemaVersion,
            localTargetShapeScore: 85
        )
        let sourceRow = try #require(clean.rows.first)
        let unknownRow = CoachChatConversationAppPathReportRow.make(
            conversationID: "unknown-provenance-conversation",
            sourceFixtureID: "future-app-path-fixture-without-provenance",
            turns: sourceRow.turns
        )
        let report = CoachChatConversationAppPathReport.make(
            rows: [unknownRow],
            localTargetShapeScore: 85
        )

        #expect(!unknownRow.passesAppPathFloor)
        #expect(!report.passesAppPathFloor)
        #expect(report.summary.semanticGateFailureTurnCount == sourceRow.turns.count)
        #expect(report.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.semanticGateFailures.rawValue
        ))
    }

    @Test func appPathReportRequiresTrajectoryCacheTelemetryAndCoverage() throws {
        let allColdReport = Self.cleanAppPathReport(
            surface: .text,
            schemaVersion: CoachChatConversationCorpus.appPathReportSchemaVersion,
            localTargetShapeScore: 85,
            trajectoryCacheHitForTurn: { _, _ in false }
        )

        #expect(!allColdReport.passesAppPathFloor)
        #expect(allColdReport.summary.trajectoryCacheHitCount == 0)
        #expect(allColdReport.summary.trajectoryCacheMissingTelemetryCount == 0)
        #expect(allColdReport.summary.minimumTrajectoryCacheHitCount > 0)
        #expect(allColdReport.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.weakTrajectoryCacheCoverage.rawValue
        ))

        let missingTelemetryReport = Self.cleanAppPathReport(
            surface: .text,
            schemaVersion: CoachChatConversationCorpus.appPathReportSchemaVersion,
            localTargetShapeScore: 85,
            trajectoryCacheHitForTurn: { _, _ in nil }
        )

        #expect(!missingTelemetryReport.passesAppPathFloor)
        #expect(missingTelemetryReport.summary.trajectoryCacheHitCount == 0)
        #expect(missingTelemetryReport.summary.trajectoryCacheMissingTelemetryCount ==
            missingTelemetryReport.turnCount)
        #expect(missingTelemetryReport.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.missingTrajectoryCacheTelemetry.rawValue
        ))
        #expect(missingTelemetryReport.summary.readinessWarnings.contains(
            CoachChatConversationAppPathWarning.weakTrajectoryCacheCoverage.rawValue
        ))
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
        #expect(manifest.audit.maximumAllowedScore == expectedCap)
        #expect(manifest.audit.claim == (expectedBlockers.isEmpty
            ? .productionReadyEvidenceAvailable
            : .localEvaluationSubstrateOnly))
        #expect(manifest.audit.productionReady == (expectedBlockers.isEmpty && expectedScore >= 85))
        #expect(manifest.audit.blockers == expectedBlockers)
        #expect(manifest.evidence.localConversationCount == CoachChatConversationCorpus.conversations.count)
        #expect(manifest.evidence.localRowsPassingProductionFloor == CoachChatConversationCorpus.conversations.count)
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
        #expect(rowsByKey["longFormConversationCorpus"]?.observedCount == CoachChatConversationCorpus.longFormConversations.count)
        #expect(rowsByKey["longFormConversationCorpus"]?.blocker == nil)
        #expect(manifest.evidence.localLongFormConversationCount == CoachChatConversationCorpus.longFormConversations.count)
        #expect(manifest.evidence.localLongFormRowsPassingConversationFloor == CoachChatConversationCorpus.longFormConversations.count)
        #expect(rowsByKey["adversarialNegativeControlCorpus"]?.status == .earned)
        #expect(rowsByKey["adversarialNegativeControlCorpus"]?.observedCount == CoachChatConversationCorpus.longFormAdversarialConversations.count)
        #expect(rowsByKey["adversarialNegativeControlCorpus"]?.blocker == nil)
        #expect(manifest.evidence.localAdversarialConversationCount == CoachChatConversationCorpus.longFormAdversarialConversations.count)
        #expect(manifest.evidence.localAdversarialRowsRejectedByProductionFloor == CoachChatConversationCorpus.longFormAdversarialConversations.count)
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
        try Self.writeSourceSidecars(to: directory)
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
    @Test func productionReadinessManifestRejectsStaleLiveSweepSourceFingerprint() async throws {
        let directory = try Self.temporaryEvaluationDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let staleSweep = Self.liveProviderSweepEvidence(
            sourceGitCommit: "stale123",
            sourceCoachFingerprint: "sha256:stale"
        )
        try Self.writeSourceSidecars(
            to: directory,
            gitCommit: "fresh123",
            coachFingerprint: "sha256:fresh"
        )
        try staleSweep.encodedSortedJSON().write(
            to: directory.appendingPathComponent(CoachChatConversationCorpus.liveProviderSweepArtifactFileName),
            atomically: true,
            encoding: .utf8
        )

        let manifest = try Self.productionReadinessEvidenceManifestFromCurrentArtifacts(
            environment: ["NOUM_COACH_EVAL_DUMP_DIR": directory.path],
            arguments: [],
            defaults: UserDefaults(suiteName: "CoachLiveProviderSweepFreshness.\(UUID().uuidString)")!
        )
        let liveProviderRow = try #require(
            manifest.rows.first { $0.key == "liveProviderTranscriptSweep" }
        )

        #expect(manifest.evidence.liveProviderRowsPassingFloor == 0)
        #expect(liveProviderRow.status == .missing)
        #expect(liveProviderRow.blocker == .noLiveProviderTranscriptSweep)
        #expect(liveProviderRow.notes.contains("sourceGitCommitMismatch"))
        #expect(liveProviderRow.notes.contains("sourceCoachFingerprintMismatch"))
        #expect(manifest.audit.blockers.contains(.noLiveProviderTranscriptSweep))
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
                CoachProfessionalCalibrationEvidence.requiredCalibrationReviewCount
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

    @Test func liveProviderSweepEvidenceRequiresCurrentSourceProvenance() throws {
        let missingSourceSweep = Self.liveProviderSweepEvidence(
            sourceGitCommit: nil,
            sourceCoachFingerprint: nil
        )
        let missingDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: missingSourceSweep.encodedSortedJSON()
        )

        #expect(!missingDecoded.qualifiesForReadiness)
        #expect(missingDecoded.rowsPassingReadinessFloor == 0)
        #expect(missingDecoded.rejectionReasons.contains("sourceGitCommitMissing"))
        #expect(missingDecoded.rejectionReasons.contains("sourceCoachFingerprintMissing"))

        let staleSweep = Self.liveProviderSweepEvidence(
            sourceFreshnessFailures: [
                "sourceGitCommitMismatch",
                "sourceCoachFingerprintMismatch"
            ]
        )
        let staleDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: staleSweep.encodedSortedJSON()
        )

        #expect(!staleDecoded.qualifiesForReadiness)
        #expect(staleDecoded.rowsPassingReadinessFloor == 0)
        #expect(staleDecoded.rejectionReasons.contains("sourceGitCommitMismatch"))
        #expect(staleDecoded.rejectionReasons.contains("sourceCoachFingerprintMismatch"))
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

    @Test func liveProviderSweepEvidenceRequiresDetailedLongFormConversationRows() throws {
        let missingDetailSweep = Self.liveProviderSweepEvidence(
            omitLongFormConversationDetails: true
        )
        let missingDetailDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: missingDetailSweep.encodedSortedJSON()
        )

        #expect(!missingDetailDecoded.qualifiesForReadiness)
        #expect(missingDetailDecoded.rowsPassingReadinessFloor == 0)
        #expect(missingDetailDecoded.rejectionReasons.contains("missingDetailedLongFormConversations"))

        let requiredIDs = CoachLiveProviderSweepEvidence.requiredLongFormConversationIDs
        let detailedRows = Self.liveProviderLongFormConversations(
            passingIDs: requiredIDs,
            failureIDs: []
        )
        let mismatchedSummarySweep = Self.liveProviderSweepEvidence(
            longFormConversationIDsPassingProductionFloor: Array(requiredIDs.dropLast()),
            longFormConversationFailureIDs: [requiredIDs.last ?? "missing-long-form-id"],
            longFormConversations: detailedRows
        )
        let mismatchedSummaryDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: mismatchedSummarySweep.encodedSortedJSON()
        )

        #expect(!mismatchedSummaryDecoded.qualifiesForReadiness)
        #expect(mismatchedSummaryDecoded.rejectionReasons.contains("longFormConversationPassingSummaryMismatch"))
        #expect(mismatchedSummaryDecoded.rejectionReasons.contains("longFormConversationFailureSummaryMismatch"))
    }

    @Test func liveProviderSweepEvidenceRequiresCompleteLongFormTurnTelemetry() throws {
        var detailedRows = Self.liveProviderLongFormConversations(
            passingIDs: CoachLiveProviderSweepEvidence.requiredLongFormConversationIDs,
            failureIDs: []
        )
        let first = try #require(detailedRows.first)
        let shortenedRows = Array(first.rows.dropLast())
        detailedRows[0] = CoachLiveProviderSweepEvidence.LongFormConversation(
            conversationID: first.conversationID,
            sourceFixtureID: first.sourceFixtureID,
            expectedTurnCount: first.expectedTurnCount,
            observedTurnCount: shortenedRows.count,
            liveProductionFloor: true,
            failure: nil,
            rows: shortenedRows
        )

        let incompleteTurnSweep = Self.liveProviderSweepEvidence(
            longFormConversations: detailedRows
        )
        let incompleteTurnDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: incompleteTurnSweep.encodedSortedJSON()
        )

        #expect(!incompleteTurnDecoded.qualifiesForReadiness)
        #expect(incompleteTurnDecoded.rejectionReasons.contains { reason in
            reason.hasPrefix("malformedDetailedLongFormConversations=")
        })

        var telemetryRows = Self.liveProviderLongFormConversations(
            passingIDs: CoachLiveProviderSweepEvidence.requiredLongFormConversationIDs,
            failureIDs: []
        )
        let telemetryConversation = try #require(telemetryRows.first)
        let telemetryRow = try #require(telemetryConversation.rows.first)
        let badTelemetryRow = CoachLiveProviderSweepEvidence.Row(
            fixtureID: telemetryRow.fixtureID,
            turnDepth: telemetryRow.turnDepth,
            providerChosen: telemetryRow.providerChosen,
            providerModel: nil,
            timeToFirstVisibleTokenMs: nil,
            trajectoryCacheHit: nil,
            assessmentConfidence: telemetryRow.assessmentConfidence,
            assessmentProofTestHash: "",
            immediateCoachReadExpected: telemetryRow.immediateCoachReadExpected,
            immediateCoachReadShown: telemetryRow.immediateCoachReadShown,
            liveProductionFloor: true,
            reply: "",
            passesRubric: nil,
            visionPassesProductionFloor: nil,
            qualityIssue: nil,
            semanticGateIssue: nil,
            reliabilityIssues: nil
        )
        telemetryRows[0] = CoachLiveProviderSweepEvidence.LongFormConversation(
            conversationID: telemetryConversation.conversationID,
            sourceFixtureID: telemetryConversation.sourceFixtureID,
            expectedTurnCount: telemetryConversation.expectedTurnCount,
            observedTurnCount: telemetryConversation.observedTurnCount,
            liveProductionFloor: true,
            failure: nil,
            rows: [badTelemetryRow] + Array(telemetryConversation.rows.dropFirst())
        )

        let missingTelemetrySweep = Self.liveProviderSweepEvidence(
            longFormConversations: telemetryRows
        )
        let missingTelemetryDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: missingTelemetrySweep.encodedSortedJSON()
        )

        #expect(!missingTelemetryDecoded.qualifiesForReadiness)
        #expect(missingTelemetryDecoded.rejectionReasons.contains { reason in
            reason.hasPrefix("missingDetailedLongFormProviderEvidence=")
        })
        #expect(missingTelemetryDecoded.rejectionReasons.contains { reason in
            reason.hasPrefix("missingDetailedLongFormTelemetry=")
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

    @Test func liveProviderSweepEvidenceKeepsNeutralColdStartWithoutFabricatedJudgement() throws {
        let clean = Self.liveProviderSweepEvidence()
        let coldIndex = try #require(clean.rows.firstIndex {
            $0.fixtureID == "cold-start-interview-baseline"
        })
        let cold = clean.rows[coldIndex]

        #expect(!CoachLiveProviderSweepEvidence.requiresTypedAssessment(
            for: cold.fixtureID
        ))
        #expect(cold.assessmentConfidence == nil)
        #expect(cold.assessmentProofTestHash == nil)
        #expect(cold.immediateCoachReadExpected == false)
        #expect(cold.immediateCoachReadShown == false)
        #expect(cold.hasReadinessTelemetry)
        #expect(clean.qualifiesForReadiness)

        var fabricatedRows = clean.rows
        fabricatedRows[coldIndex] = CoachLiveProviderSweepEvidence.Row(
            fixtureID: cold.fixtureID,
            turnDepth: cold.turnDepth,
            providerChosen: cold.providerChosen,
            providerModel: cold.providerModel,
            timeToFirstVisibleTokenMs: cold.timeToFirstVisibleTokenMs,
            trajectoryCacheHit: cold.trajectoryCacheHit,
            assessmentConfidence: 0.70,
            assessmentProofTestHash: "fabricated-default-voice-proof",
            immediateCoachReadExpected: true,
            immediateCoachReadShown: true,
            liveProductionFloor: cold.liveProductionFloor,
            reply: cold.reply,
            passesRubric: cold.passesRubric,
            visionPassesProductionFloor: cold.visionPassesProductionFloor,
            qualityIssue: cold.qualityIssue,
            semanticGateIssue: cold.semanticGateIssue,
            reliabilityIssues: cold.reliabilityIssues
        )
        let fabricated = Self.copyLiveProviderSweepEvidence(
            clean,
            rows: fabricatedRows
        )

        #expect(!fabricated.rows[coldIndex].hasReadinessTelemetry)
        #expect(!fabricated.qualifiesForReadiness)
        #expect(fabricated.rejectionReasons.contains { reason in
            reason.hasPrefix("latestTurnReadinessTelemetryFailures=")
        })

        let explicitIndex = try #require(clean.rows.firstIndex {
            CoachLiveProviderSweepEvidence.requiresTypedAssessment(for: $0.fixtureID)
        })
        let explicit = clean.rows[explicitIndex]
        var missingExplicitRows = clean.rows
        missingExplicitRows[explicitIndex] = CoachLiveProviderSweepEvidence.Row(
            fixtureID: explicit.fixtureID,
            turnDepth: explicit.turnDepth,
            providerChosen: explicit.providerChosen,
            providerModel: explicit.providerModel,
            timeToFirstVisibleTokenMs: explicit.timeToFirstVisibleTokenMs,
            trajectoryCacheHit: explicit.trajectoryCacheHit,
            assessmentConfidence: nil,
            assessmentProofTestHash: nil,
            immediateCoachReadExpected: false,
            immediateCoachReadShown: false,
            liveProductionFloor: explicit.liveProductionFloor,
            reply: explicit.reply,
            passesRubric: explicit.passesRubric,
            visionPassesProductionFloor: explicit.visionPassesProductionFloor,
            qualityIssue: explicit.qualityIssue,
            semanticGateIssue: explicit.semanticGateIssue,
            reliabilityIssues: explicit.reliabilityIssues
        )
        let missingExplicit = Self.copyLiveProviderSweepEvidence(
            clean,
            rows: missingExplicitRows
        )

        #expect(!missingExplicit.rows[explicitIndex].hasReadinessTelemetry)
        #expect(!missingExplicit.qualifiesForReadiness)

        let unknownWithoutAssessment = CoachLiveProviderSweepEvidence.Row(
            fixtureID: "future-fixture-without-declared-style-boundary",
            turnDepth: explicit.turnDepth,
            providerChosen: explicit.providerChosen,
            providerModel: explicit.providerModel,
            timeToFirstVisibleTokenMs: explicit.timeToFirstVisibleTokenMs,
            trajectoryCacheHit: explicit.trajectoryCacheHit,
            assessmentConfidence: nil,
            assessmentProofTestHash: nil,
            immediateCoachReadExpected: false,
            immediateCoachReadShown: false,
            liveProductionFloor: explicit.liveProductionFloor,
            reply: explicit.reply,
            passesRubric: explicit.passesRubric,
            visionPassesProductionFloor: explicit.visionPassesProductionFloor,
            qualityIssue: explicit.qualityIssue,
            semanticGateIssue: explicit.semanticGateIssue,
            reliabilityIssues: explicit.reliabilityIssues
        )

        #expect(CoachLiveProviderSweepEvidence.requiresTypedAssessment(
            for: unknownWithoutAssessment.fixtureID
        ))
        #expect(!unknownWithoutAssessment.hasReadinessTelemetry)
    }

    @Test func liveProviderSweepEvidenceRequiresTrajectoryCacheCoverage() throws {
        let allColdLongFormConversations = Self.liveProviderLongFormConversations(
            passingIDs: CoachLiveProviderSweepEvidence.requiredLongFormConversationIDs,
            failureIDs: [],
            trajectoryCacheHitForTurn: { _ in false }
        )
        let coldSweep = Self.liveProviderSweepEvidence(
            trajectoryCacheHitIndices: [],
            longFormConversations: allColdLongFormConversations
        )
        let decoded = try CoachLiveProviderSweepEvidence.decode(
            from: coldSweep.encodedSortedJSON()
        )

        #expect(!decoded.qualifiesForReadiness)
        #expect(decoded.rowsPassingReadinessFloor == 0)
        #expect(decoded.rejectionReasons.contains { reason in
            reason.hasPrefix("weakTrajectoryCacheCoverage=")
        })
    }

    @Test func liveProviderSweepEvidenceRejectsContradictoryGateTelemetry() throws {
        let cleanSweep = Self.liveProviderSweepEvidence()
        var latestRows = cleanSweep.rows
        let latest = try #require(latestRows.first)
        latestRows[0] = CoachLiveProviderSweepEvidence.Row(
            fixtureID: latest.fixtureID,
            turnDepth: latest.turnDepth,
            providerChosen: latest.providerChosen,
            providerModel: latest.providerModel,
            timeToFirstVisibleTokenMs: latest.timeToFirstVisibleTokenMs,
            trajectoryCacheHit: latest.trajectoryCacheHit,
            assessmentConfidence: latest.assessmentConfidence,
            assessmentProofTestHash: latest.assessmentProofTestHash,
            immediateCoachReadExpected: latest.immediateCoachReadExpected,
            immediateCoachReadShown: latest.immediateCoachReadShown,
            liveProductionFloor: true,
            reply: latest.reply,
            passesRubric: false,
            visionPassesProductionFloor: true,
            qualityIssue: "missingIntentFit",
            semanticGateIssue: "missingIntentFit",
            reliabilityIssues: ["nearDuplicateReply"]
        )
        let latestContradiction = Self.copyLiveProviderSweepEvidence(
            cleanSweep,
            rows: latestRows
        )
        let latestDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: latestContradiction.encodedSortedJSON()
        )

        #expect(!latestDecoded.qualifiesForReadiness)
        #expect(latestDecoded.rowsPassingReadinessFloor == 0)
        #expect(latestDecoded.rejectionReasons.contains {
            $0.hasPrefix("latestTurnGateTelemetryFailures=")
        })

        var longFormConversations = try #require(cleanSweep.longFormConversations)
        let conversation = try #require(longFormConversations.first)
        let firstLongFormRow = try #require(conversation.rows.first)
        let badLongFormRow = CoachLiveProviderSweepEvidence.Row(
            fixtureID: firstLongFormRow.fixtureID,
            turnDepth: firstLongFormRow.turnDepth,
            providerChosen: firstLongFormRow.providerChosen,
            providerModel: firstLongFormRow.providerModel,
            timeToFirstVisibleTokenMs: firstLongFormRow.timeToFirstVisibleTokenMs,
            trajectoryCacheHit: firstLongFormRow.trajectoryCacheHit,
            assessmentConfidence: firstLongFormRow.assessmentConfidence,
            assessmentProofTestHash: firstLongFormRow.assessmentProofTestHash,
            immediateCoachReadExpected: firstLongFormRow.immediateCoachReadExpected,
            immediateCoachReadShown: firstLongFormRow.immediateCoachReadShown,
            liveProductionFloor: true,
            reply: firstLongFormRow.reply,
            passesRubric: true,
            visionPassesProductionFloor: false,
            qualityIssue: "none",
            semanticGateIssue: "unsupportedClosenessClaim",
            reliabilityIssues: []
        )
        longFormConversations[0] = CoachLiveProviderSweepEvidence.LongFormConversation(
            conversationID: conversation.conversationID,
            sourceFixtureID: conversation.sourceFixtureID,
            expectedTurnCount: conversation.expectedTurnCount,
            observedTurnCount: conversation.observedTurnCount,
            liveProductionFloor: true,
            failure: nil,
            rows: [badLongFormRow] + Array(conversation.rows.dropFirst())
        )
        let longFormContradiction = Self.copyLiveProviderSweepEvidence(
            cleanSweep,
            longFormConversations: longFormConversations
        )
        let longFormDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: longFormContradiction.encodedSortedJSON()
        )

        #expect(!longFormDecoded.qualifiesForReadiness)
        #expect(longFormDecoded.rejectionReasons.contains {
            $0.hasPrefix("detailedLongFormGateTelemetryFailures=")
        })
    }

    @Test func liveProviderSweepEvidenceRejectsDuplicatedOrGenericReplyText() throws {
        let cleanSweep = Self.liveProviderSweepEvidence()
        var duplicateRows = cleanSweep.rows
        let first = try #require(duplicateRows.first)
        let second = try #require(duplicateRows.dropFirst().first)
        duplicateRows[1] = CoachLiveProviderSweepEvidence.Row(
            fixtureID: second.fixtureID,
            turnDepth: second.turnDepth,
            providerChosen: second.providerChosen,
            providerModel: second.providerModel,
            timeToFirstVisibleTokenMs: second.timeToFirstVisibleTokenMs,
            trajectoryCacheHit: second.trajectoryCacheHit,
            assessmentConfidence: second.assessmentConfidence,
            assessmentProofTestHash: second.assessmentProofTestHash,
            immediateCoachReadExpected: second.immediateCoachReadExpected,
            immediateCoachReadShown: second.immediateCoachReadShown,
            liveProductionFloor: second.liveProductionFloor,
            reply: first.reply,
            passesRubric: second.passesRubric,
            visionPassesProductionFloor: second.visionPassesProductionFloor,
            qualityIssue: second.qualityIssue,
            semanticGateIssue: second.semanticGateIssue,
            reliabilityIssues: second.reliabilityIssues
        )
        let duplicateDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: Self.copyLiveProviderSweepEvidence(
                cleanSweep,
                rows: duplicateRows
            ).encodedSortedJSON()
        )

        #expect(!duplicateDecoded.qualifiesForReadiness)
        #expect(duplicateDecoded.rejectionReasons.contains {
            $0.hasPrefix("duplicatedLatestTurnReplies=")
        })

        var genericRows = cleanSweep.rows
        let generic = try #require(genericRows.first)
        genericRows[0] = CoachLiveProviderSweepEvidence.Row(
            fixtureID: generic.fixtureID,
            turnDepth: generic.turnDepth,
            providerChosen: generic.providerChosen,
            providerModel: generic.providerModel,
            timeToFirstVisibleTokenMs: generic.timeToFirstVisibleTokenMs,
            trajectoryCacheHit: generic.trajectoryCacheHit,
            assessmentConfidence: generic.assessmentConfidence,
            assessmentProofTestHash: generic.assessmentProofTestHash,
            immediateCoachReadExpected: generic.immediateCoachReadExpected,
            immediateCoachReadShown: generic.immediateCoachReadShown,
            liveProductionFloor: generic.liveProductionFloor,
            reply: "Here is a focused coach reply with concrete evidence.",
            passesRubric: generic.passesRubric,
            visionPassesProductionFloor: generic.visionPassesProductionFloor,
            qualityIssue: generic.qualityIssue,
            semanticGateIssue: generic.semanticGateIssue,
            reliabilityIssues: generic.reliabilityIssues
        )
        let genericDecoded = try CoachLiveProviderSweepEvidence.decode(
            from: Self.copyLiveProviderSweepEvidence(
                cleanSweep,
                rows: genericRows
            ).encodedSortedJSON()
        )

        #expect(!genericDecoded.qualifiesForReadiness)
        #expect(genericDecoded.rejectionReasons.contains {
            $0.hasPrefix("genericLatestTurnReplies=")
        })
    }

    @Test func liveProviderSweepEvidenceAllowsContextualPlaceholderAsk() throws {
        let cleanSweep = Self.liveProviderSweepEvidence()
        var conversations = try #require(cleanSweep.longFormConversations)
        let conversationIndex = try #require(conversations.firstIndex {
            $0.conversationID == "long-form-leadership-transfer-setup-conversation"
        })
        let conversation = conversations[conversationIndex]
        var rows = conversation.rows
        let rowIndex = try #require(rows.indices.dropFirst().first)
        let row = rows[rowIndex]
        rows[rowIndex] = CoachLiveProviderSweepEvidence.Row(
            fixtureID: row.fixtureID,
            turnDepth: row.turnDepth,
            providerChosen: row.providerChosen,
            providerModel: row.providerModel,
            timeToFirstVisibleTokenMs: row.timeToFirstVisibleTokenMs,
            trajectoryCacheHit: row.trajectoryCacheHit,
            assessmentConfidence: row.assessmentConfidence,
            assessmentProofTestHash: row.assessmentProofTestHash,
            immediateCoachReadExpected: row.immediateCoachReadExpected,
            immediateCoachReadShown: row.immediateCoachReadShown,
            liveProductionFloor: row.liveProductionFloor,
            reply: "Use a placeholder ask: I need alignment on the next step, then test the close.",
            passesRubric: row.passesRubric,
            visionPassesProductionFloor: row.visionPassesProductionFloor,
            qualityIssue: row.qualityIssue,
            semanticGateIssue: row.semanticGateIssue,
            reliabilityIssues: row.reliabilityIssues
        )
        conversations[conversationIndex] = CoachLiveProviderSweepEvidence.LongFormConversation(
            conversationID: conversation.conversationID,
            sourceFixtureID: conversation.sourceFixtureID,
            expectedTurnCount: conversation.expectedTurnCount,
            observedTurnCount: conversation.observedTurnCount,
            liveProductionFloor: conversation.liveProductionFloor,
            failure: conversation.failure,
            rows: rows
        )

        let decoded = try CoachLiveProviderSweepEvidence.decode(
            from: Self.copyLiveProviderSweepEvidence(
                cleanSweep,
                longFormConversations: conversations
            ).encodedSortedJSON()
        )

        #expect(decoded.qualifiesForReadiness, "Unexpected rejection: \(decoded.rejectionReasons)")
        #expect(!decoded.rejectionReasons.contains {
            $0.hasPrefix("genericDetailedLongFormReplies=")
        })
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
        try Self.writeSourceSidecars(to: directory)
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

    @Test func liveProviderSweepLoaderRequiresCurrentSourceSidecars() throws {
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

        #expect(loaded?.qualifiesForReadiness == false)
        #expect(loaded?.rejectionReasons.contains("currentSourceGitCommitMissing") == true)
        #expect(loaded?.rejectionReasons.contains("currentSourceCoachFingerprintMissing") == true)
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
        let singleReviewEvidence = Self.professionalCalibrationEvidence(
            reviewsPerConversation: 1
        )
        let singleReviewDecoded = try CoachProfessionalCalibrationEvidence.decode(
            from: singleReviewEvidence.encodedSortedJSON()
        )

        #expect(!singleReviewDecoded.qualifiesForReadiness)
        #expect(singleReviewDecoded.rowsPassingCalibrationFloor == 0)
        #expect(singleReviewDecoded.rejectionReasons.contains("missingFullConversationCoverage"))
        #expect(singleReviewDecoded.rejectionReasons.contains { reason in
            reason.hasPrefix("insufficientReviewsPerConversation=")
        })
        #expect(singleReviewDecoded.rejectionReasons.contains { reason in
            reason.hasPrefix("insufficientPassingReviewsPerConversation=")
        })

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

    @Test func professionalCalibrationEvidenceRequiresCurrentSourcePacketFingerprint() throws {
        let stalePacketEvidence = Self.professionalCalibrationEvidence(
            sourcePacketFingerprint: "fnv1a64:0000000000000000"
        )
        let stalePacketDecoded = try CoachProfessionalCalibrationEvidence.decode(
            from: stalePacketEvidence.encodedSortedJSON()
        )

        #expect(!stalePacketDecoded.qualifiesForReadiness)
        #expect(stalePacketDecoded.rowsPassingCalibrationFloor == 0)
        #expect(stalePacketDecoded.rejectionReasons.contains("sourcePacketFingerprintMismatch"))

        let missingPacketEvidence = Self.professionalCalibrationEvidence(
            sourcePacketFingerprint: nil
        )
        let missingPacketDecoded = try CoachProfessionalCalibrationEvidence.decode(
            from: missingPacketEvidence.encodedSortedJSON()
        )

        #expect(!missingPacketDecoded.qualifiesForReadiness)
        #expect(missingPacketDecoded.rowsPassingCalibrationFloor == 0)
        #expect(missingPacketDecoded.rejectionReasons.contains("sourcePacketFingerprintMissing"))
    }

    @Test func professionalCalibrationEvidenceRequiresReviewerCoherenceAndResolvedRevisions() throws {
        let reviewerMismatchEvidence = Self.professionalCalibrationEvidence(
            summaryReviewerCount: 1
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

        let singleReviewerEvidence = Self.professionalCalibrationEvidence(
            reviewerIDs: ["coach-reviewer-1"]
        )
        let singleReviewerDecoded = try CoachProfessionalCalibrationEvidence.decode(
            from: singleReviewerEvidence.encodedSortedJSON()
        )

        #expect(!singleReviewerDecoded.qualifiesForReadiness)
        #expect(singleReviewerDecoded.rejectionReasons.contains("duplicateConversationReviewerPairs"))
        #expect(singleReviewerDecoded.rejectionReasons.contains { reason in
            reason.hasPrefix("insufficientReviewerDiversity=")
        })

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
                CoachProfessionalCalibrationEvidence.requiredCalibrationReviewCount
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
            rejectedRowIndices: [0, 1, 2, 3, 4]
        )
        let rejectedDecoded = try CoachRealUserTransferOutcomeEvidence.decode(
            from: rejectedEvidence.encodedSortedJSON()
        )

        #expect(!rejectedDecoded.qualifiesForReadiness)
        #expect(rejectedDecoded.rowsPassingOutcomeFloor == 0)
        #expect(rejectedDecoded.rejectionReasons.contains("insufficientPositiveTransferOutcomes"))
        #expect(rejectedDecoded.rejectionReasons.contains("insufficientAudienceResponseEvidence"))
        #expect(rejectedDecoded.rejectionReasons.contains("outcomeFloorFailures"))
    }

    @Test func realUserTransferOutcomeEvidenceRetainsMixedAndResolvedAdverseRows() throws {
        let mixed = try CoachRealUserTransferOutcomeEvidence.decode(
            from: Self.realUserTransferOutcomeEvidence(
                regressedRowIndices: [0, 1, 2],
                adverseRowIndices: [3]
            ).encodedSortedJSON()
        )

        #expect(mixed.qualifiesForReadiness)
        #expect(mixed.rowsPassingOutcomeFloor == 12)
        #expect(mixed.summary.positiveTransferCount == 9)
        #expect(mixed.summary.noRegressionOutcomeCount == 9)
        #expect(mixed.summary.adverseOutcomeCount == 1)
        #expect(mixed.summary.resolvedAdverseOutcomeCount == 1)

        let unresolved = try CoachRealUserTransferOutcomeEvidence.decode(
            from: Self.realUserTransferOutcomeEvidence(
                adverseRowIndices: [3],
                unresolvedAdverseRowIndices: [3]
            ).encodedSortedJSON()
        )
        #expect(!unresolved.qualifiesForReadiness)
        #expect(unresolved.rejectionReasons.contains("unresolvedAdverseOutcomes"))
        #expect(unresolved.rejectionReasons.contains("outcomeFloorFailures"))
    }

    @Test func realUserTransferOutcomeEvidenceRejectsThinOrSmoothedSidecars() throws {
        let concentratedUsers = try CoachRealUserTransferOutcomeEvidence.decode(
            from: Self.realUserTransferOutcomeEvidence(
                collapsedUserIDs: true
            ).encodedSortedJSON()
        )

        #expect(!concentratedUsers.qualifiesForReadiness)
        #expect(concentratedUsers.rowsPassingOutcomeFloor == 0)
        #expect(concentratedUsers.rejectionReasons.contains("insufficientUniqueUsers"))
        #expect(concentratedUsers.rejectionReasons.contains("excessiveOutcomesPerUser"))

        let narrowCategories = try CoachRealUserTransferOutcomeEvidence.decode(
            from: Self.realUserTransferOutcomeEvidence(
                collapsedMomentCategories: true
            ).encodedSortedJSON()
        )

        #expect(!narrowCategories.qualifiesForReadiness)
        #expect(narrowCategories.rejectionReasons.contains("insufficientMomentCategoryDiversity"))

        let missingEvidence = try CoachRealUserTransferOutcomeEvidence.decode(
            from: Self.realUserTransferOutcomeEvidence(
                missingEvidenceReferenceIndices: [0]
            ).encodedSortedJSON()
        )

        #expect(!missingEvidence.qualifiesForReadiness)
        #expect(missingEvidence.rejectionReasons.contains("insufficientEvidenceReferences"))
        #expect(missingEvidence.rejectionReasons.contains("outcomeFloorFailures"))

        let sameHourFollowUp = try CoachRealUserTransferOutcomeEvidence.decode(
            from: Self.realUserTransferOutcomeEvidence(
                lowFollowUpDelayIndices: [0]
            ).encodedSortedJSON()
        )

        #expect(!sameHourFollowUp.qualifiesForReadiness)
        #expect(sameHourFollowUp.rejectionReasons.contains("insufficientFollowUpDelay"))
        #expect(sameHourFollowUp.rejectionReasons.contains("outcomeFloorFailures"))
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
            failingSurfaceKeys: ["liveActivity", "storeKitPurchaseRestoreEntitlements"]
        )
        let rejectedDecoded = try CoachRealDeviceTestFlightEvidence.decode(
            from: rejectedEvidence.encodedSortedJSON()
        )

        #expect(!rejectedDecoded.qualifiesForReadiness)
        #expect(rejectedDecoded.rejectionReasons.contains("surfaceFloorFailures"))
        #expect(rejectedDecoded.rejectionReasons.contains("blockingIssuesPresent"))
        #expect(rejectedDecoded.rejectionReasons.contains("rowSurfaceFloorFailures"))
    }

    @Test func realDeviceTestFlightV3PinsExactSurfacesAndChecks() throws {
        #expect(CoachRealDeviceTestFlightEvidence.requiredSurfaceKeys.count == 14)
        #expect(CoachRealDeviceTestFlightEvidence.requiredCheckCount == 77)
        #expect(
            Set(CoachRealDeviceTestFlightEvidence.requiredCheckKeysBySurface.keys) ==
                Set(CoachRealDeviceTestFlightEvidence.requiredSurfaceKeys)
        )

        let clean = try CoachRealDeviceTestFlightEvidence.decode(
            from: Self.realDeviceTestFlightEvidence().encodedSortedJSON()
        )
        #expect(clean.qualifiesForReadiness)
        #expect(clean.summary.requiredCheckCount == 77)
        #expect(clean.summary.passedRequiredCheckCount == 77)
    }

    @Test func realDeviceTestFlightV3RejectsMissingUnexpectedDuplicateAndFailedChecks() throws {
        let evidence = try CoachRealDeviceTestFlightEvidence.decode(
            from: Self.realDeviceTestFlightEvidence(
                missingCheckKeysBySurface: ["liveActivity": ["forceQuitEnds"]],
                unexpectedCheckKeysBySurface: [
                    "productionTranscriptionConsent": ["syntheticPass"]
                ],
                duplicateCheckKeysBySurface: ["modeSmoke": ["timedDifficulties"]],
                failedCheckKeysBySurface: [
                    "accountDeletion": ["serverFailurePreservesSignedInState"]
                ]
            ).encodedSortedJSON()
        )

        #expect(!evidence.qualifiesForReadiness)
        #expect(evidence.rejectionReasons.contains(
            "missingRequiredChecks=liveActivity:forceQuitEnds"
        ))
        #expect(evidence.rejectionReasons.contains(
            "unexpectedCheckKeys=productionTranscriptionConsent:syntheticPass"
        ))
        #expect(evidence.rejectionReasons.contains(
            "duplicateCheckKeys=modeSmoke:timedDifficulties"
        ))
        #expect(evidence.rejectionReasons.contains(
            "failedRequiredChecks=accountDeletion:serverFailurePreservesSignedInState"
        ))
        #expect(evidence.rejectionReasons.contains("checkFloorFailures"))
        #expect(evidence.rejectionReasons.contains("rowSurfaceFloorFailures"))
    }

    @Test func realDeviceTestFlightEvidenceRejectsSmoothedOrIncompleteEvidence() throws {
        let wrongEvidenceKind = try CoachRealDeviceTestFlightEvidence.decode(
            from: Self.realDeviceTestFlightEvidence(
                evidenceKindOverrides: ["liveActivity": "manualNote"]
            ).encodedSortedJSON()
        )
        let overBudgetLatency = try CoachRealDeviceTestFlightEvidence.decode(
            from: Self.realDeviceTestFlightEvidence(
                overBudgetLatencySurfaceKeys: ["aiPromptLatency"]
            ).encodedSortedJSON()
        )
        let negativeLatency = try CoachRealDeviceTestFlightEvidence.decode(
            from: Self.realDeviceTestFlightEvidence(
                latencyOverrides: ["aiPromptLatency": -1]
            ).encodedSortedJSON()
        )
        let missingRunMetadata = try CoachRealDeviceTestFlightEvidence.decode(
            from: Self.realDeviceTestFlightEvidence(
                appVersion: "",
                osVersion: ""
            ).encodedSortedJSON()
        )
        let mixedBuild = try CoachRealDeviceTestFlightEvidence.decode(
            from: Self.realDeviceTestFlightEvidence(
                buildMismatchSurfaceKeys: ["soundscapeAudioSession"]
            ).encodedSortedJSON()
        )
        let thinEvidence = try CoachRealDeviceTestFlightEvidence.decode(
            from: Self.realDeviceTestFlightEvidence(
                missingEvidenceReferenceSurfaceKeys: ["storeKitPurchaseRestoreEntitlements"],
                missingEvidenceTimestampSurfaceKeys: ["storeKitPurchaseRestoreEntitlements"],
                missingDeviceIdentitySurfaceKeys: ["storeKitPurchaseRestoreEntitlements"]
            ).encodedSortedJSON()
        )

        #expect(!wrongEvidenceKind.qualifiesForReadiness)
        #expect(wrongEvidenceKind.rejectionReasons.contains("evidenceKindMismatch=liveActivity"))
        #expect(wrongEvidenceKind.rejectionReasons.contains("rowSurfaceFloorFailures"))
        #expect(!overBudgetLatency.qualifiesForReadiness)
        #expect(overBudgetLatency.rejectionReasons.contains("aiPromptLatencyOverBudget"))
        #expect(overBudgetLatency.rejectionReasons.contains("rowSurfaceFloorFailures"))
        #expect(!negativeLatency.qualifiesForReadiness)
        #expect(negativeLatency.rejectionReasons.contains("aiPromptLatencyOverBudget"))
        #expect(negativeLatency.rejectionReasons.contains("rowSurfaceFloorFailures"))
        #expect(!missingRunMetadata.qualifiesForReadiness)
        #expect(missingRunMetadata.rejectionReasons.contains("missingRunMetadata"))
        #expect(!mixedBuild.qualifiesForReadiness)
        #expect(mixedBuild.rejectionReasons.contains("buildNumberMismatch=soundscapeAudioSession"))
        #expect(!thinEvidence.qualifiesForReadiness)
        #expect(thinEvidence.rejectionReasons.contains(
            "missingDeviceEvidence=storeKitPurchaseRestoreEntitlements"
        ))
        #expect(thinEvidence.rejectionReasons.contains(
            "missingDeviceIdentity=storeKitPurchaseRestoreEntitlements"
        ))
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
        #expect(
            loaded?.summary.passedRequiredSurfaceCount ==
                CoachRealDeviceTestFlightEvidence.requiredSurfaceKeys.count
        )
        #expect(
            loaded?.summary.passedRequiredCheckCount ==
                CoachRealDeviceTestFlightEvidence.requiredCheckCount
        )
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

        let openPrerequisite = try CoachOperationalLaunchChecklistEvidence.decode(
            from: Self.operationalLaunchChecklistEvidence(
                openPrerequisiteKeys: ["legacyTranscriptionEndpointProtectedOrDisabled"]
            ).encodedSortedJSON()
        )
        #expect(!openPrerequisite.qualifiesForReadiness)
        #expect(openPrerequisite.rejectionReasons.contains(
            "openReleasePrerequisites=legacyTranscriptionEndpointProtectedOrDisabled"
        ))
        #expect(openPrerequisite.rejectionReasons.contains("releasePrerequisiteFloorFailures"))

        let incompleteHistoryReview = try CoachOperationalLaunchChecklistEvidence.decode(
            from: Self.operationalLaunchChecklistEvidence(
                historyUnresolvedFindingCount: 1,
                includesKnownDeepgramHistoryFinding: false
            ).encodedSortedJSON()
        )
        #expect(!incompleteHistoryReview.qualifiesForReadiness)
        #expect(incompleteHistoryReview.rejectionReasons.contains(
            "incompleteHistorySecretAdjudication"
        ))
        #expect(incompleteHistoryReview.rejectionReasons.contains(
            "missingKnownDeepgramHistoryFinding"
        ))

        let unboundHistoryReview = try CoachOperationalLaunchChecklistEvidence.decode(
            from: Self.operationalLaunchChecklistEvidence(
                historyReportReferenceOverride: "evidence://different-history-report"
            ).encodedSortedJSON()
        )
        #expect(!unboundHistoryReview.qualifiesForReadiness)
        #expect(unboundHistoryReview.rejectionReasons.contains(
            "historySecretReportReferenceMismatch"
        ))
    }

    @Test func operationalLaunchChecklistEvidenceRejectsThinOrSmoothedItems() throws {
        let wrongEvidenceKind = try CoachOperationalLaunchChecklistEvidence.decode(
            from: Self.operationalLaunchChecklistEvidence(
                evidenceKindOverrides: ["firestoreRulesDeployed": "manualNote"]
            ).encodedSortedJSON()
        )
        let wrongEnvironment = try CoachOperationalLaunchChecklistEvidence.decode(
            from: Self.operationalLaunchChecklistEvidence(
                environmentOverrides: ["privacyPolicyURLHosted": "staging"]
            ).encodedSortedJSON()
        )
        let mixedBuild = try CoachOperationalLaunchChecklistEvidence.decode(
            from: Self.operationalLaunchChecklistEvidence(
                buildMismatchItemKeys: ["testFlightBuildUploaded"]
            ).encodedSortedJSON()
        )
        let missingOperationalProof = try CoachOperationalLaunchChecklistEvidence.decode(
            from: Self.operationalLaunchChecklistEvidence(
                missingEvidenceReferenceItemKeys: ["appStorePrivacyDisclosuresReviewed"],
                missingVerificationReferenceItemKeys: ["appStorePrivacyDisclosuresReviewed"],
                missingOutputReferenceItemKeys: ["appStorePrivacyDisclosuresReviewed"]
            ).encodedSortedJSON()
        )
        let missingVerificationIdentity = try CoachOperationalLaunchChecklistEvidence.decode(
            from: Self.operationalLaunchChecklistEvidence(
                missingVerifiedAtItemKeys: ["releaseBlockingBugsTriaged"],
                missingVerifiedByRoleItemKeys: ["releaseBlockingBugsTriaged"]
            ).encodedSortedJSON()
        )
        let selfVerifiedPrerequisite = try CoachOperationalLaunchChecklistEvidence.decode(
            from: Self.operationalLaunchChecklistEvidence(
                samePrerequisitePerformerAndVerifierKeys: ["customPrivacyDomainVerified"]
            ).encodedSortedJSON()
        )

        #expect(!wrongEvidenceKind.qualifiesForReadiness)
        #expect(wrongEvidenceKind.rejectionReasons.contains("evidenceKindMismatch=firestoreRulesDeployed"))
        #expect(wrongEvidenceKind.rejectionReasons.contains("itemFloorFailures"))
        #expect(!wrongEnvironment.qualifiesForReadiness)
        #expect(wrongEnvironment.rejectionReasons.contains("environmentMismatch=privacyPolicyURLHosted"))
        #expect(wrongEnvironment.rejectionReasons.contains("itemFloorFailures"))
        #expect(!mixedBuild.qualifiesForReadiness)
        #expect(mixedBuild.rejectionReasons.contains("releaseCandidateBuildMismatch=testFlightBuildUploaded"))
        #expect(!missingOperationalProof.qualifiesForReadiness)
        #expect(missingOperationalProof.rejectionReasons.contains("missingOperationalEvidence=appStorePrivacyDisclosuresReviewed"))
        #expect(missingOperationalProof.rejectionReasons.contains("itemFloorFailures"))
        #expect(!missingVerificationIdentity.qualifiesForReadiness)
        #expect(missingVerificationIdentity.rejectionReasons.contains("missingOperationalVerification=releaseBlockingBugsTriaged"))
        #expect(missingVerificationIdentity.rejectionReasons.contains("itemFloorFailures"))
        #expect(!selfVerifiedPrerequisite.qualifiesForReadiness)
        #expect(selfVerifiedPrerequisite.rejectionReasons.contains(
            "missingReleasePrerequisiteVerification=customPrivacyDomainVerified"
        ))
        #expect(selfVerifiedPrerequisite.rejectionReasons.contains("releasePrerequisiteFloorFailures"))
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

    @MainActor
    @Test func productionReadinessManifestCanReachReadyOnlyWhenEveryEvidenceContractPasses() async throws {
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
        let manifest = CoachVisionProductionReadinessEvidenceManifest.make(
            conversationReport: conversationReport,
            longFormConversationReport: longFormConversationReport,
            expertPacket: expertPacket,
            textAppPathReport: textAppPathReport,
            liveAppPathReport: liveAppPathReport,
            liveProviderSweep: Self.liveProviderSweepEvidence(),
            professionalCalibration: Self.professionalCalibrationEvidence(),
            realUserTransferOutcomes: Self.realUserTransferOutcomeEvidence(),
            realDeviceTestFlight: Self.realDeviceTestFlightEvidence(),
            operationalLaunchChecklist: Self.operationalLaunchChecklistEvidence()
        )

        #expect(manifest.audit.blockers.isEmpty)
        #expect(manifest.audit.score == 100)
        #expect(manifest.audit.maximumAllowedScore == 100)
        #expect(manifest.audit.claim == .productionReadyEvidenceAvailable)
        #expect(manifest.audit.productionReady)
        let requiredExternalKeys = Set([
            "liveProviderTranscriptSweep",
            "professionalCoachCalibration",
            "realUserLongitudinalTransferOutcomes",
            "realDeviceTestFlightVerification",
            "operationalLaunchChecklist"
        ])
        #expect(manifest.rows.filter { requiredExternalKeys.contains($0.key) }
            .allSatisfy { $0.status == .earned })
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

    @Test func sourceGitCommitReadsXcodeAndSimulatorInputs() {
        let suiteName = "CoachChatConversationSourceGit.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        #expect(Self.sourceGitCommitForAppPathTrace(
            environment: ["NOUM_SOURCE_GIT_COMMIT": " abc1234 "],
            arguments: [],
            defaults: defaults
        ) == "abc1234")
        #expect(Self.sourceGitCommitForAppPathTrace(
            environment: ["SIMCTL_CHILD_NOUM_SOURCE_GIT_COMMIT": "def5678"],
            arguments: [],
            defaults: defaults
        ) == "def5678")
        #expect(Self.sourceGitCommitForAppPathTrace(
            environment: [:],
            arguments: ["NoumTests", "-NOUM_SOURCE_GIT_COMMIT", "feedbee"],
            defaults: defaults
        ) == "feedbee")
        #expect(Self.sourceGitCommitForAppPathTrace(
            environment: [:],
            arguments: ["NoumTests", "NOUM_SOURCE_GIT_COMMIT=badcafe"],
            defaults: defaults
        ) == "badcafe")

        defaults.set(" cafe123 ", forKey: "NOUM_SOURCE_GIT_COMMIT")
        #expect(Self.sourceGitCommitForAppPathTrace(
            environment: [:],
            arguments: [],
            defaults: defaults
        ) == "cafe123")

        defaults.removeObject(forKey: "NOUM_SOURCE_GIT_COMMIT")
        let emptyDirectory = try! Self.temporaryEvaluationDirectory()
        #expect(Self.sourceGitCommitForAppPathTrace(
            environment: [:],
            arguments: [],
            defaults: defaults,
            dumpDirectory: emptyDirectory.path
        ) == nil)

        let directory = try! Self.temporaryEvaluationDirectory()
        try! " filecafe \n".write(
            to: directory.appendingPathComponent("source-git-commit.txt"),
            atomically: true,
            encoding: .utf8
        )
        #expect(Self.sourceGitCommitForAppPathTrace(
            environment: [:],
            arguments: [],
            defaults: defaults,
            dumpDirectory: directory.path
        ) == "filecafe")
    }

    @Test func sourceCoachFingerprintReadsXcodeAndSimulatorInputs() {
        let suiteName = "CoachChatConversationSourceFingerprint.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        #expect(Self.sourceCoachFingerprintForAppPathTrace(
            environment: ["NOUM_SOURCE_COACH_FINGERPRINT": " sha256:abc1234 "],
            arguments: [],
            defaults: defaults
        ) == "sha256:abc1234")
        #expect(Self.sourceCoachFingerprintForAppPathTrace(
            environment: ["SIMCTL_CHILD_NOUM_SOURCE_COACH_FINGERPRINT": "sha256:def5678"],
            arguments: [],
            defaults: defaults
        ) == "sha256:def5678")
        #expect(Self.sourceCoachFingerprintForAppPathTrace(
            environment: [:],
            arguments: ["NoumTests", "-NOUM_SOURCE_COACH_FINGERPRINT", "sha256:feedbee"],
            defaults: defaults
        ) == "sha256:feedbee")
        #expect(Self.sourceCoachFingerprintForAppPathTrace(
            environment: [:],
            arguments: ["NoumTests", "NOUM_SOURCE_COACH_FINGERPRINT=sha256:badcafe"],
            defaults: defaults
        ) == "sha256:badcafe")

        defaults.set(" sha256:cafe123 ", forKey: "NOUM_SOURCE_COACH_FINGERPRINT")
        #expect(Self.sourceCoachFingerprintForAppPathTrace(
            environment: [:],
            arguments: [],
            defaults: defaults
        ) == "sha256:cafe123")

        defaults.removeObject(forKey: "NOUM_SOURCE_COACH_FINGERPRINT")
        let emptyDirectory = try! Self.temporaryEvaluationDirectory()
        #expect(Self.sourceCoachFingerprintForAppPathTrace(
            environment: [:],
            arguments: [],
            defaults: defaults,
            dumpDirectory: emptyDirectory.path
        ) == nil)

        let directory = try! Self.temporaryEvaluationDirectory()
        try! " sha256:filecafe \n".write(
            to: directory.appendingPathComponent("source-coach-fingerprint.txt"),
            atomically: true,
            encoding: .utf8
        )
        #expect(Self.sourceCoachFingerprintForAppPathTrace(
            environment: [:],
            arguments: [],
            defaults: defaults,
            dumpDirectory: directory.path
        ) == "sha256:filecafe")
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
                let turnDepth = TurnDepthClassifier.classify(
                    userText: turn.userTurn,
                    recentTurns: history
                )
                let issue = AICoachChatService.replyQualityIssue(
                    in: turn.coachReply,
                    latestUserTurn: turn.userTurn,
                    recentCoachReplies: recentCoachReplies,
                    turnDepth: turnDepth,
                    surface: .text
                )
                #expect(issue == nil,
                        "\(conversation.id) target turn tripped gate for user turn '\(turn.userTurn)': \(String(describing: issue))")

                await script.push(turn.coachReply)
                let outcome = await service.reply(
                    history: history,
                    systemPrompt: "You are Noum.",
                    userContext: "Conversation fixture \(conversation.id)",
                    turnDepth: turnDepth
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
        let evidence = try CoachLiveProviderSweepEvidence.decode(from: json)
        return evidence.withSourceFreshnessExpectation(
            gitCommit: Self.sourceGitCommitForAppPathTrace(
                environment: environment,
                arguments: arguments,
                defaults: defaults,
                dumpDirectory: directory
            ),
            coachFingerprint: Self.sourceCoachFingerprintForAppPathTrace(
                environment: environment,
                arguments: arguments,
                defaults: defaults,
                dumpDirectory: directory
            )
        )
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

    private static func sourceGitCommitForAppPathTrace(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard,
        dumpDirectory: String? = nil
    ) -> String? {
        if let commit = trimmedNonEmpty(environment["NOUM_SOURCE_GIT_COMMIT"]) {
            return commit
        }
        if let commit = trimmedNonEmpty(environment["SIMCTL_CHILD_NOUM_SOURCE_GIT_COMMIT"]) {
            return commit
        }
        if let flagIndex = arguments.firstIndex(of: "-NOUM_SOURCE_GIT_COMMIT") {
            let valueIndex = arguments.index(after: flagIndex)
            if valueIndex < arguments.endIndex,
               let commit = trimmedNonEmpty(arguments[valueIndex]) {
                return commit
            }
        }
        if let inline = arguments.first(where: { $0.hasPrefix("NOUM_SOURCE_GIT_COMMIT=") }) {
            return trimmedNonEmpty(String(inline.dropFirst("NOUM_SOURCE_GIT_COMMIT=".count)))
        }
        if let inline = arguments.first(where: { $0.hasPrefix("-NOUM_SOURCE_GIT_COMMIT=") }) {
            return trimmedNonEmpty(String(inline.dropFirst("-NOUM_SOURCE_GIT_COMMIT=".count)))
        }
        if let commit = trimmedNonEmpty(defaults.string(forKey: "NOUM_SOURCE_GIT_COMMIT")) {
            return commit
        }
        let resolvedDumpDirectory = dumpDirectory ?? Self.evaluationArtifactDumpDirectory()
        if let resolvedDumpDirectory,
           let data = try? String(contentsOfFile: "\(resolvedDumpDirectory)/source-git-commit.txt", encoding: .utf8),
           let commit = trimmedNonEmpty(data) {
            return commit
        }
        return nil
    }

    private static func sourceCoachFingerprintForAppPathTrace(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard,
        dumpDirectory: String? = nil
    ) -> String? {
        if let fingerprint = trimmedNonEmpty(environment["NOUM_SOURCE_COACH_FINGERPRINT"]) {
            return fingerprint
        }
        if let fingerprint = trimmedNonEmpty(environment["SIMCTL_CHILD_NOUM_SOURCE_COACH_FINGERPRINT"]) {
            return fingerprint
        }
        if let flagIndex = arguments.firstIndex(of: "-NOUM_SOURCE_COACH_FINGERPRINT") {
            let valueIndex = arguments.index(after: flagIndex)
            if valueIndex < arguments.endIndex,
               let fingerprint = trimmedNonEmpty(arguments[valueIndex]) {
                return fingerprint
            }
        }
        if let inline = arguments.first(where: { $0.hasPrefix("NOUM_SOURCE_COACH_FINGERPRINT=") }) {
            return trimmedNonEmpty(String(inline.dropFirst("NOUM_SOURCE_COACH_FINGERPRINT=".count)))
        }
        if let inline = arguments.first(where: { $0.hasPrefix("-NOUM_SOURCE_COACH_FINGERPRINT=") }) {
            return trimmedNonEmpty(String(inline.dropFirst("-NOUM_SOURCE_COACH_FINGERPRINT=".count)))
        }
        if let fingerprint = trimmedNonEmpty(defaults.string(forKey: "NOUM_SOURCE_COACH_FINGERPRINT")) {
            return fingerprint
        }
        let resolvedDumpDirectory = dumpDirectory ?? Self.evaluationArtifactDumpDirectory()
        if let resolvedDumpDirectory,
           let data = try? String(
            contentsOfFile: "\(resolvedDumpDirectory)/source-coach-fingerprint.txt",
            encoding: .utf8
           ),
           let fingerprint = trimmedNonEmpty(data) {
            return fingerprint
        }
        return nil
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

    private static func writeSourceSidecars(
        to directory: URL,
        gitCommit: String = "abc123",
        coachFingerprint: String = "sha256:test-current"
    ) throws {
        try gitCommit.write(
            to: directory.appendingPathComponent("source-git-commit.txt"),
            atomically: true,
            encoding: .utf8
        )
        try coachFingerprint.write(
            to: directory.appendingPathComponent("source-coach-fingerprint.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func cleanAppPathReport(
        surface: CoachReplySurface,
        schemaVersion: String,
        localTargetShapeScore: Int,
        trajectoryCacheHitForTurn: (_ conversationID: String, _ turnIndex: Int) -> Bool? = { _, turnIndex in
            turnIndex > 0
        }
    ) -> CoachChatConversationAppPathReport {
        let rows = CoachChatConversationCorpus.appPathConversationScripts.map { script in
            let conversation = script.conversation
            var recentTurns: [CoachMessage] = []
            for seedReply in script.seedCoachReplies {
                recentTurns.append(CoachMessage(role: .coach, text: seedReply))
            }
            let turns = conversation.turns.enumerated().map { index, turn in
                let sanitizedReply = CoachReplyTextSanitizer.coachReplyText(
                    from: turn.coachReply
                )
                let turnDepth = TurnDepthClassifier.classify(
                    userText: turn.userTurn,
                    recentTurns: recentTurns
                )
                let turnIntent = CoachChatTurnIntent.classify(turn.userTurn)
                let responseKind = CoachChatResponseKind.classify(turn.userTurn)
                let semanticGateExpectation =
                    CoachChatConversationAppPathSemanticExpectation
                        .forResponseKind(responseKind)
                let typedAssessmentPresent = semanticGateExpectation ==
                    .passedWithTypedAssessment
                let assessmentConfidence = typedAssessmentPresent
                    ? 0.68 + (Double((index + conversation.id.count) % 5) * 0.03)
                    : nil
                let proofTestHash = typedAssessmentPresent
                    ? "manifest-\(conversation.id)-\(index)"
                    : nil
                let semanticGateOutcome: String? = {
                    switch semanticGateExpectation {
                    case .passedWithTypedAssessment:
                        return "passed"
                    case .notEvaluatedWithoutTypedAssessment:
                        return "notEvaluated"
                    case .unknownFixtureFailClosed:
                        return nil
                    }
                }()
                let immediateCoachReadExpected = surface == .live &&
                    typedAssessmentPresent
                let immediateCoachReadShown = immediateCoachReadExpected
                let semanticGateContractSatisfied = semanticGateExpectation
                    .isSatisfied(
                        semanticGateOutcome: semanticGateOutcome,
                        typedAssessmentPresent: typedAssessmentPresent,
                        assessmentConfidence: assessmentConfidence,
                        proofTestHash: proofTestHash,
                        immediateCoachReadExpected: immediateCoachReadExpected,
                        immediateCoachReadShown: immediateCoachReadShown
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
                    turnIntent: turnIntent.rawValue,
                    responseKind: responseKind.rawValue,
                    turnDepth: turnDepth.rawValue,
                    providerTierRequested: nil,
                    providerTierChosen: nil,
                    providerName: "fixture",
                    providerModel: "clean-app-path-manifest",
                    semanticGateExpectation: semanticGateExpectation,
                    semanticGateOutcome: semanticGateOutcome,
                    semanticGateIssue: nil,
                    semanticGatePassed: semanticGateOutcome == "passed",
                    typedAssessmentPresent: typedAssessmentPresent,
                    qualityGateOutcome: "passed",
                    qualityGateEvents: ["passed"],
                    qualityGateClean: true,
                    qualityGateAcceptedFallback: false,
                    typedAssessmentFallbackApplied: false,
                    deterministicAssessmentFallbackApplied: false,
                    qualityGateBlockingFailure: false,
                    reliabilityIssues: [],
                    visionScore: 90,
                    visionPassesProductionFloor: true,
                    immediateCoachReadExpected: immediateCoachReadExpected,
                    immediateCoachReadShown: immediateCoachReadShown,
                    assessmentConfidence: assessmentConfidence,
                    proofTestHash: proofTestHash,
                    proofTestRecentlyRepeated: false,
                    retrievalTrace: CoachRetrievalTrace(
                        strategy: "clean-app-path-manifest",
                        queryPresent: !turn.userTurn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        queryCharacterCount: turn.userTurn.trimmingCharacters(in: .whitespacesAndNewlines).count,
                        hasDiagnosis: true,
                        activeLever: nil,
                        voice: nil,
                        semanticRerankAllowed: false,
                        retrievedCardCount: 0,
                        retrievedCardIDs: [],
                        diagnosticReason: "Clean manifest trace; scripted app-path test captures real retrieval."
                    ),
                    arenaTrace: nil,
                    timeToFirstVisibleTokenMs: surface == .live ? 1 : nil,
                    timeToFirstVisibleTokenSource: surface == .live
                        ? (immediateCoachReadExpected
                            ? CoachFirstVisibleTokenSource.localImmediateRead.rawValue
                            : CoachFirstVisibleTokenSource.finalReplyCommit.rawValue)
                        : nil,
                    timeToCompleteReplyMs: 1,
                    trajectoryCacheHit: trajectoryCacheHitForTurn(conversation.id, index),
                    assessmentCacheHit: nil,
                    passesAppPathFloor: semanticGateContractSatisfied
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
        trajectoryCacheHitIndices: Set<Int>? = nil,
        confidenceDistinctRoundedCount: Int = 3,
        uniqueProofTestHashCount: Int? = nil,
        repeatedProofTestHashCount: Int = 0,
        longFormConversationIDsPassingProductionFloor: [String] =
            CoachLiveProviderSweepEvidence.requiredLongFormConversationIDs,
        longFormConversationFailureIDs: [String] = [],
        longFormConversations: [CoachLiveProviderSweepEvidence.LongFormConversation]? = nil,
        omitLongFormConversationDetails: Bool = false,
        sourceGitCommit: String? = "abc123",
        sourceCoachFingerprint: String? = "sha256:test-current",
        sourceFreshnessFailures: [String]? = nil
    ) -> CoachLiveProviderSweepEvidence {
        let rowCount = fixtureIDs.count
        let requiredDepths = CoachLiveProviderSweepEvidence.requiredTurnDepths
        let depths = turnDepths ?? fixtureIDs.indices.map { index in
            requiredDepths[index % requiredDepths.count]
        }
        let cacheHitIndices = trajectoryCacheHitIndices ?? Set(
            fixtureIDs.indices.filter { $0 % 5 == 0 }
        )
        let rows = fixtureIDs.enumerated().map { index, fixtureID in
            let requiresTypedAssessment = CoachLiveProviderSweepEvidence
                .requiresTypedAssessment(for: fixtureID)
            return CoachLiveProviderSweepEvidence.Row(
                fixtureID: fixtureID,
                turnDepth: depths.indices.contains(index) ? depths[index] : CoachTurnDepth.groundedRead.rawValue,
                providerChosen: "Gemini",
                providerModel: "gemini-test",
                timeToFirstVisibleTokenMs: 420 + index,
                trajectoryCacheHit: cacheHitIndices.contains(index),
                assessmentConfidence: requiresTypedAssessment
                    ? 0.70 + (Double(index % max(confidenceDistinctRoundedCount, 1)) * 0.03)
                    : nil,
                assessmentProofTestHash: requiresTypedAssessment
                    ? "proof-\(index % (uniqueProofTestHashCount ?? rowCount))"
                    : nil,
                immediateCoachReadExpected: requiresTypedAssessment,
                immediateCoachReadShown: requiresTypedAssessment,
                liveProductionFloor: !failingRowIndices.contains(index),
                reply: "For \(fixtureID), the live coach names the observed turn signal and gives one bounded next move.",
                passesRubric: true,
                visionPassesProductionFloor: true,
                qualityIssue: "none",
                semanticGateIssue: "none",
                reliabilityIssues: []
            )
        }
        let failureCount = rows.filter { !$0.liveProductionFloor }.count
        let typedAssessmentRowCount = rows.filter {
            CoachLiveProviderSweepEvidence.requiresTypedAssessment(for: $0.fixtureID)
        }.count
        let longFormFailureCount = longFormConversationFailureIDs.count
        let detailedLongFormConversations = omitLongFormConversationDetails
            ? nil
            : (
                longFormConversations ?? Self.liveProviderLongFormConversations(
                    passingIDs: longFormConversationIDsPassingProductionFloor,
                    failureIDs: longFormConversationFailureIDs
                )
            )
        return CoachLiveProviderSweepEvidence(
            schemaVersion: CoachLiveProviderSweepEvidence.expectedSchemaVersion,
            sourceGitCommit: sourceGitCommit,
            sourceCoachFingerprint: sourceCoachFingerprint,
            sourceFreshnessFailures: sourceFreshnessFailures,
            fixtureCount: rowCount,
            longFormConversationCount: longFormConversationIDsPassingProductionFloor.count +
                longFormFailureCount,
            longFormConversationIDsPassingProductionFloor: longFormConversationIDsPassingProductionFloor,
            longFormConversationFailureIDs: longFormConversationFailureIDs,
            longFormConversations: detailedLongFormConversations,
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
                immediateCoachReadExpectedCount: typedAssessmentRowCount,
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

    private static func copyLiveProviderSweepEvidence(
        _ evidence: CoachLiveProviderSweepEvidence,
        rows: [CoachLiveProviderSweepEvidence.Row]? = nil,
        longFormConversations: [CoachLiveProviderSweepEvidence.LongFormConversation]? = nil
    ) -> CoachLiveProviderSweepEvidence {
        CoachLiveProviderSweepEvidence(
            schemaVersion: evidence.schemaVersion,
            sourceGitCommit: evidence.sourceGitCommit,
            sourceCoachFingerprint: evidence.sourceCoachFingerprint,
            sourceFreshnessFailures: evidence.sourceFreshnessFailures,
            fixtureCount: evidence.fixtureCount,
            longFormConversationCount: evidence.longFormConversationCount,
            longFormConversationIDsPassingProductionFloor: evidence.longFormConversationIDsPassingProductionFloor,
            longFormConversationFailureIDs: evidence.longFormConversationFailureIDs,
            longFormConversations: longFormConversations ?? evidence.longFormConversations,
            providerChain: evidence.providerChain,
            passesProductionFloor: evidence.passesProductionFloor,
            passesRunReadinessFloor: evidence.passesRunReadinessFloor,
            summary: evidence.summary,
            rows: rows ?? evidence.rows
        )
    }

    private static func liveProviderLongFormConversations(
        passingIDs: [String],
        failureIDs: [String],
        trajectoryCacheHitForTurn: (Int) -> Bool = { $0 > 0 }
    ) -> [CoachLiveProviderSweepEvidence.LongFormConversation] {
        let ids = passingIDs + failureIDs
        let failureIDSet = Set(failureIDs)
        var conversations: [CoachLiveProviderSweepEvidence.LongFormConversation] = []
        for conversationID in ids {
            let source = CoachChatConversationCorpus.longFormConversations.first {
                $0.id == conversationID
            }
            let expectedTurnCount = source?.turns.count ?? 5
            let liveProductionFloor = !failureIDSet.contains(conversationID)
            var rows: [CoachLiveProviderSweepEvidence.Row] = []
            for index in 0..<expectedTurnCount {
                let reply: String? = liveProductionFloor
                    ? "\(conversationID) turn \(index + 1) names the current evidence, answers the user's ask, and gives one proof test."
                    : nil
                rows.append(CoachLiveProviderSweepEvidence.Row(
                    fixtureID: "\(conversationID)#turn-\(index + 1)",
                    turnDepth: CoachLiveProviderSweepEvidence
                        .requiredTurnDepths[index % CoachLiveProviderSweepEvidence.requiredTurnDepths.count],
                    providerChosen: "Gemini",
                    providerModel: "gemini-test",
                    timeToFirstVisibleTokenMs: 520 + index,
                    trajectoryCacheHit: trajectoryCacheHitForTurn(index),
                    assessmentConfidence: 0.64 + (Double(index % 4) * 0.04),
                    assessmentProofTestHash: "\(conversationID)-proof-\(index)",
                    immediateCoachReadExpected: false,
                    immediateCoachReadShown: false,
                    liveProductionFloor: liveProductionFloor,
                    reply: reply,
                    passesRubric: liveProductionFloor,
                    visionPassesProductionFloor: liveProductionFloor,
                    qualityIssue: "none",
                    semanticGateIssue: "none",
                    reliabilityIssues: []
                ))
            }
            conversations.append(CoachLiveProviderSweepEvidence.LongFormConversation(
                conversationID: conversationID,
                sourceFixtureID: source?.sourceFixtureID ?? "unknown-source",
                expectedTurnCount: expectedTurnCount,
                observedTurnCount: expectedTurnCount,
                liveProductionFloor: liveProductionFloor,
                failure: liveProductionFloor ? nil : "failed live production floor",
                rows: rows
            ))
        }
        return conversations
    }

    private static func professionalCalibrationEvidence(
        conversationIDs: [String] = CoachProfessionalCalibrationEvidence.requiredConversationIDs,
        reviewsPerConversation: Int = CoachProfessionalCalibrationEvidence.requiredReviewsPerConversation,
        readinessWarnings: [String] = [],
        rejectedRowIndices: Set<Int> = [],
        rejectionDecision: String = "unsafeOrUnready",
        reviewerIDs: [String]? = nil,
        summaryReviewerCount: Int? = nil,
        revisionNoteIndices: Set<Int> = [],
        sourcePacketFingerprint: String? = CoachProfessionalCalibrationEvidence
            .expectedSourcePacketFingerprint
    ) -> CoachProfessionalCalibrationEvidence {
        let defaultReviewerIDs = (1...CoachProfessionalCalibrationEvidence.requiredReviewsPerConversation)
            .map { "coach-reviewer-\($0)" }
        let rows = conversationIDs.enumerated().flatMap { conversationIndex, conversationID in
            (0..<reviewsPerConversation).map { reviewIndex in
                let rowIndex = conversationIndex * reviewsPerConversation +
                    reviewIndex
                let rejected = rejectedRowIndices.contains(rowIndex)
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
                let availableReviewerIDs = reviewerIDs ?? defaultReviewerIDs
                let reviewerID = availableReviewerIDs.isEmpty
                    ? ""
                    : availableReviewerIDs[rowIndex % availableReviewerIDs.count]
                return CoachProfessionalCalibrationEvidence.Row(
                    conversationID: conversationID,
                    reviewerID: reviewerID,
                    calibrationDecision: rejected ? rejectionDecision : "roughTie",
                    wouldUseWithClient: !rejected,
                    ratings: ratings,
                    humanCoachReferenceCount: rejected ? 0 : 2,
                    overclaimNotes: rejected ? ["Too much certainty for the evidence."] : [],
                    revisionNotes: rejected || revisionNoteIndices.contains(rowIndex)
                        ? ["Needs stronger evidence calibration."]
                        : []
                )
            }
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
            sourcePacketFingerprint: sourcePacketFingerprint,
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
        rejectedRowIndices: Set<Int> = [],
        regressedRowIndices: Set<Int> = [],
        adverseRowIndices: Set<Int> = [],
        unresolvedAdverseRowIndices: Set<Int> = [],
        collapsedUserIDs: Bool = false,
        collapsedMomentCategories: Bool = false,
        missingEvidenceReferenceIndices: Set<Int> = [],
        lowFollowUpDelayIndices: Set<Int> = []
    ) -> CoachRealUserTransferOutcomeEvidence {
        let rows = (0..<rowCount).map { index in
            let rejected = rejectedRowIndices.contains(index)
            let regressed = regressedRowIndices.contains(index)
            let adverse = adverseRowIndices.contains(index)
            let adverseResolved = adverse && !unresolvedAdverseRowIndices.contains(index)
            let missingEvidence = missingEvidenceReferenceIndices.contains(index)
            let momentCategory = collapsedMomentCategories ? "presentation" : [
                "presentation",
                "interview",
                "leadership",
                "conflict",
                "client-call",
                "networking"
            ][index % 6]
            return CoachRealUserTransferOutcomeEvidence.Row(
                outcomeID: "transfer-outcome-\(index)",
                userIDHash: collapsedUserIDs ? "user-\(index % 3)" : "user-\(index % 10)",
                momentCategory: momentCategory,
                interventionID: "intervention-\(index)",
                realWorldMomentOccurred: !rejected,
                followUpCompleted: !rejected,
                linkedCoachInterventionCount: rejected ? 0 : 2,
                daysSinceFirstNoumSession: rejected ? 3 : 14 + index,
                followUpDelayHours: lowFollowUpDelayIndices.contains(index) ? 4 : 36 + index,
                preMomentConfidence: 2 + (index % 2),
                postMomentConfidence: rejected || regressed ? 1 : 3 + (index % 2),
                positiveTransferReported: !rejected && !regressed,
                audienceResponseEvidenceCollected: !rejected,
                adverseOutcomeReported: adverse,
                adverseOutcomeResolved: adverseResolved,
                adverseOutcomeFollowUpReference: adverse
                    ? "beta://adverse-follow-up/transfer-outcome-\(index)"
                    : "",
                interventionEvidenceReference: missingEvidence
                    ? ""
                    : "noum://intervention/intervention-\(index)",
                momentEvidenceReference: missingEvidence
                    ? ""
                    : "beta://moment/\(momentCategory)/\(index)",
                followUpEvidenceReference: missingEvidence
                    ? ""
                    : "beta://follow-up/transfer-outcome-\(index)",
                audienceResponseEvidenceReference: missingEvidence
                    ? ""
                    : "beta://audience-response/transfer-outcome-\(index)",
                selfReportEvidenceReference: missingEvidence
                    ? ""
                    : "beta://self-report/transfer-outcome-\(index)",
                causalityClaims: rejected ? ["Noum caused the outcome."] : [],
                notes: rejected ? ["Follow-up did not establish transfer."] : [
                    "User reported the prescribed proof test carried into the real moment."
                ]
            )
        }
        let passingRows = rows.filter(\.passesOutcomeFloor)
        let uniqueUsers = Set(rows.map(\.userIDHash)).count
        let uniqueMomentCategories = Set(rows.map(\.momentCategory)).count
        let rowsByUser = Dictionary(grouping: rows, by: \.userIDHash)
        let maximumOutcomesPerUser = rowsByUser.values.map(\.count).max() ?? 0
        let minimumDays = rows.map(\.daysSinceFirstNoumSession).min() ?? 0
        let minimumFollowUpDelay = rows.map(\.followUpDelayHours).min() ?? 0
        return CoachRealUserTransferOutcomeEvidence(
            schemaVersion: CoachRealUserTransferOutcomeEvidence.expectedSchemaVersion,
            studyProtocolVersion: CoachRealUserTransferOutcomeEvidence.expectedProtocolVersion,
            protocolRegistrationReference: "registry://noum-transfer-v3",
            analysisPlanReference: "registry://noum-transfer-v3/analysis",
            comparisonMethod: "prePostWithinUser",
            benchmarkReference: "registry://noum-transfer-v3/benchmark",
            cohortDescription: "closed-beta-transfer-cohort",
            enrollment: CoachRealUserTransferOutcomeEvidence.Enrollment(
                enrolledUserCount: uniqueUsers + 2,
                completedUserCount: uniqueUsers,
                withdrawnUserCount: 1,
                excludedUserCount: 1,
                exclusionLogReference: "registry://noum-transfer-v3/exclusions"
            ),
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
                resolvedAdverseOutcomeCount: rows.filter {
                    $0.adverseOutcomeReported && $0.adverseOutcomeResolved
                }.count,
                passingOutcomeCount: passingRows.count,
                minimumDaysSinceFirstSession: minimumDays,
                studyDurationDays: rowCount > 0 ? 42 : 0,
                uniqueMomentCategoryCount: uniqueMomentCategories,
                verifiedEvidenceReferenceCount: rows.filter(\.hasRequiredEvidenceReferences).count,
                minimumFollowUpDelayHours: minimumFollowUpDelay,
                maximumOutcomesPerUser: maximumOutcomesPerUser,
                readinessWarnings: readinessWarnings
            ),
            rows: rows
        )
    }

    private static func realDeviceTestFlightEvidence(
        appVersion: String = "1.0",
        osVersion: String = "iOS 26.2",
        readinessWarnings: [String] = [],
        failingSurfaceKeys: Set<String> = [],
        evidenceKindOverrides: [String: String] = [:],
        missingEvidenceReferenceSurfaceKeys: Set<String> = [],
        missingEvidenceTimestampSurfaceKeys: Set<String> = [],
        buildMismatchSurfaceKeys: Set<String> = [],
        missingDeviceIdentitySurfaceKeys: Set<String> = [],
        overBudgetLatencySurfaceKeys: Set<String> = [],
        latencyOverrides: [String: Int] = [:],
        missingCheckKeysBySurface: [String: Set<String>] = [:],
        unexpectedCheckKeysBySurface: [String: Set<String>] = [:],
        duplicateCheckKeysBySurface: [String: Set<String>] = [:],
        failedCheckKeysBySurface: [String: Set<String>] = [:]
    ) -> CoachRealDeviceTestFlightEvidence {
        let buildNumber = "2026.06.30.1"
        let rows = CoachRealDeviceTestFlightEvidence.requiredSurfaceKeys.map { key in
            let failed = failingSurfaceKeys.contains(key)
            let missingEvidenceReference = missingEvidenceReferenceSurfaceKeys.contains(key)
            let missingEvidenceTimestamp = missingEvidenceTimestampSurfaceKeys.contains(key)
            let missingDeviceIdentity = missingDeviceIdentitySurfaceKeys.contains(key)
            let buildNumberForRow = buildMismatchSurfaceKeys.contains(key) ?
                "2026.06.29.9" : buildNumber
            let latency = key == "aiPromptLatency" ?
                (latencyOverrides[key] ??
                    (overBudgetLatencySurfaceKeys.contains(key) || failed ? 4_200 : 1_850)) : nil
            var checks = (CoachRealDeviceTestFlightEvidence.requiredCheckKeysBySurface[key] ?? [])
                .filter { missingCheckKeysBySurface[key]?.contains($0) != true }
                .map {
                    CoachRealDeviceTestFlightEvidence.Check(
                        checkKey: $0,
                        passed: failedCheckKeysBySurface[key]?.contains($0) != true
                    )
                }
            checks.append(contentsOf: (unexpectedCheckKeysBySurface[key] ?? []).sorted().map {
                CoachRealDeviceTestFlightEvidence.Check(checkKey: $0, passed: true)
            })
            checks.append(contentsOf: (duplicateCheckKeysBySurface[key] ?? []).sorted().map {
                CoachRealDeviceTestFlightEvidence.Check(checkKey: $0, passed: true)
            })
            return CoachRealDeviceTestFlightEvidence.Row(
                surfaceKey: key,
                passed: !failed,
                realDevice: true,
                testFlightBuildInstalled: true,
                evidenceReference: failed || missingEvidenceReference ?
                    "" : "testflight://noum/qa/\(buildNumber)/\(key)",
                evidenceKind: evidenceKindOverrides[key] ??
                    CoachRealDeviceTestFlightEvidence.expectedEvidenceKindBySurface[key] ?? "",
                evidenceCapturedAtISO8601: missingEvidenceTimestamp ?
                    "" : "2026-06-30T09:12:00Z",
                testFlightBuildNumber: buildNumberForRow,
                deviceIdentifierHash: missingDeviceIdentity ?
                    "" : "sha256:iphone15pro-real-device-qa",
                latencyMs: latency,
                blockingIssueCount: failed ? 1 : 0,
                checks: checks,
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
        let artifactBackedRows = rows.filter {
            requiredKeys.contains($0.surfaceKey) && $0.hasRequiredArtifactTrail
        }
        let expectedEvidenceKindRows = rows.filter {
            requiredKeys.contains($0.surfaceKey) && $0.evidenceKindMatchesSurface
        }
        let sameBuildRows = rows.filter {
            requiredKeys.contains($0.surfaceKey) && $0.testFlightBuildNumber == buildNumber
        }
        let deviceIdentityRows = rows.filter {
            requiredKeys.contains($0.surfaceKey) &&
                CoachRealDeviceTestFlightEvidence.usableEvidenceReference($0.deviceIdentifierHash)
        }
        let latencyWithinBudgetRows = rows.filter {
            requiredKeys.contains($0.surfaceKey) &&
                $0.surfaceKey == "aiPromptLatency" &&
                $0.latencyWithinBudget
        }
        let blockingIssueCount = rows.reduce(0) { $0 + $1.blockingIssueCount }
        let passedRequiredCheckCount = rows
            .filter { requiredKeys.contains($0.surfaceKey) }
            .reduce(0) { $0 + $1.passedRequiredCheckCount }
        return CoachRealDeviceTestFlightEvidence(
            schemaVersion: CoachRealDeviceTestFlightEvidence.expectedSchemaVersion,
            testRunID: "real-device-qa-2026-06-30",
            appVersion: appVersion,
            buildNumber: buildNumber,
            deviceModel: "iPhone 15 Pro",
            osVersion: osVersion,
            testerRole: "internalTestFlightQA",
            summary: CoachRealDeviceTestFlightEvidence.Summary(
                rowCount: rows.count,
                requiredSurfaceCount: CoachRealDeviceTestFlightEvidence.requiredSurfaceKeys.count,
                requiredCheckCount: CoachRealDeviceTestFlightEvidence.requiredCheckCount,
                passedRequiredCheckCount: passedRequiredCheckCount,
                passedRequiredSurfaceCount: passedRequiredRows.count,
                realDeviceSurfaceCount: realDeviceRequiredRows.count,
                testFlightBuildSurfaceCount: testFlightRequiredRows.count,
                artifactBackedSurfaceCount: artifactBackedRows.count,
                expectedEvidenceKindSurfaceCount: expectedEvidenceKindRows.count,
                sameBuildSurfaceCount: sameBuildRows.count,
                deviceIdentitySurfaceCount: deviceIdentityRows.count,
                latencyWithinBudgetSurfaceCount: latencyWithinBudgetRows.count,
                blockingIssueCount: blockingIssueCount,
                crashFree: blockingIssueCount == 0,
                readinessWarnings: readinessWarnings
            ),
            rows: rows
        )
    }

    private static func operationalLaunchChecklistEvidence(
        readinessWarnings: [String] = [],
        openPrerequisiteKeys: Set<String> = [],
        missingPrerequisiteReferenceKeys: Set<String> = [],
        failingItemKeys: Set<String> = [],
        evidenceKindOverrides: [String: String] = [:],
        environmentOverrides: [String: String] = [:],
        missingEvidenceReferenceItemKeys: Set<String> = [],
        missingVerificationReferenceItemKeys: Set<String> = [],
        missingOutputReferenceItemKeys: Set<String> = [],
        missingCompletedAtItemKeys: Set<String> = [],
        missingVerifiedAtItemKeys: Set<String> = [],
        missingVerifiedByRoleItemKeys: Set<String> = [],
        samePerformerAndVerifierItemKeys: Set<String> = [],
        prerequisiteEvidenceKindOverrides: [String: String] = [:],
        prerequisiteEnvironmentOverrides: [String: String] = [:],
        prerequisiteBuildMismatchKeys: Set<String> = [],
        samePrerequisitePerformerAndVerifierKeys: Set<String> = [],
        historyUnresolvedFindingCount: Int = 0,
        includesKnownDeepgramHistoryFinding: Bool = true,
        historyReportReferenceOverride: String? = nil,
        buildMismatchItemKeys: Set<String> = []
    ) -> CoachOperationalLaunchChecklistEvidence {
        let releaseCandidateBuild = "2026.06.30.1"
        func prerequisitePassed(_ key: String) -> Bool {
            !openPrerequisiteKeys.contains(key)
        }
        func prerequisiteReference(_ key: String) -> String {
            missingPrerequisiteReferenceKeys.contains(key) ? "" : "evidence://\(key)"
        }
        let items = CoachOperationalLaunchChecklistEvidence.requiredItemKeys.map { key in
            let failed = failingItemKeys.contains(key)
            let missingEvidenceReference = missingEvidenceReferenceItemKeys.contains(key)
            let missingVerificationReference = missingVerificationReferenceItemKeys.contains(key)
            let missingOutputReference = missingOutputReferenceItemKeys.contains(key)
            let missingCompletedAt = missingCompletedAtItemKeys.contains(key)
            let missingVerifiedAt = missingVerifiedAtItemKeys.contains(key)
            let missingVerifiedByRole = missingVerifiedByRoleItemKeys.contains(key)
            let samePerformerAndVerifier = samePerformerAndVerifierItemKeys.contains(key)
            let performedByID = "operator-\(key)"
            let itemBuild = buildMismatchItemKeys.contains(key) ?
                "2026.06.29.9" : releaseCandidateBuild
            return CoachOperationalLaunchChecklistEvidence.Item(
                key: key,
                completed: !failed,
                evidenceReference: failed || missingEvidenceReference ?
                    "" : "m14://launch-checklist/\(releaseCandidateBuild)/\(key)",
                evidenceKind: evidenceKindOverrides[key] ??
                    CoachOperationalLaunchChecklistEvidence.expectedEvidenceKindByItem[key] ?? "",
                verificationReference: failed || missingVerificationReference ?
                    "" : "m14://launch-verification/\(releaseCandidateBuild)/\(key)",
                commandOrReviewOutputReference: failed || missingOutputReference ?
                    "" : "m14://launch-output/\(releaseCandidateBuild)/\(key)",
                releaseCandidateBuild: itemBuild,
                environment: environmentOverrides[key] ??
                    CoachOperationalLaunchChecklistEvidence.expectedEnvironmentByItem[key] ?? "",
                completedAtISO8601: failed || missingCompletedAt ?
                    nil : "2026-06-30T00:00:00Z",
                performedByID: performedByID,
                verifiedAtISO8601: failed || missingVerifiedAt ?
                    nil : "2026-06-30T00:15:00Z",
                verifiedByID: samePerformerAndVerifier ? performedByID : "verifier-\(key)",
                verifiedByRole: failed || missingVerifiedByRole ?
                    "" : "releaseManager",
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
        let artifactBackedItems = items.filter {
            requiredKeys.contains($0.key) && $0.hasRequiredArtifactTrail
        }
        let expectedEvidenceKindItems = items.filter {
            requiredKeys.contains($0.key) && $0.evidenceKindMatchesItem
        }
        let expectedEnvironmentItems = items.filter {
            requiredKeys.contains($0.key) && $0.environmentMatchesItem
        }
        let sameBuildItems = items.filter {
            requiredKeys.contains($0.key) && $0.releaseCandidateBuild == releaseCandidateBuild
        }
        let verifiedRequiredItems = items.filter {
            requiredKeys.contains($0.key) && $0.hasVerificationIdentity
        }
        let releasePrerequisites = CoachOperationalLaunchChecklistEvidence
            .requiredPrerequisiteKeys.map { key in
                let performedByID = "operator-\(key)"
                return CoachOperationalLaunchChecklistEvidence.ReleasePrerequisite(
                    key: key,
                    completed: prerequisitePassed(key),
                    evidenceReference: prerequisiteReference(key),
                    evidenceKind: prerequisiteEvidenceKindOverrides[key] ??
                        CoachOperationalLaunchChecklistEvidence
                            .expectedEvidenceKindByPrerequisite[key] ?? "",
                    verificationReference: "evidence://verification-\(key)",
                    commandOrReviewOutputReference: "evidence://output-\(key)",
                    releaseCandidateBuild: prerequisiteBuildMismatchKeys.contains(key)
                        ? "2026.06.29.9"
                        : releaseCandidateBuild,
                    environment: prerequisiteEnvironmentOverrides[key] ??
                        CoachOperationalLaunchChecklistEvidence
                            .expectedEnvironmentByPrerequisite[key] ?? "",
                    completedAtISO8601: "2026-06-30T00:00:00Z",
                    performedByID: performedByID,
                    verifiedAtISO8601: "2026-06-30T00:15:00Z",
                    verifiedByID: samePrerequisitePerformerAndVerifierKeys.contains(key)
                        ? performedByID
                        : "verifier-\(key)",
                    verifiedByRole: "releaseManager",
                    notes: ["Release prerequisite completed and independently verified."]
                )
            }
        let historyFindings = [
            CoachOperationalLaunchChecklistEvidence.HistorySecretAdjudication.Finding(
                findingID: "sha256:\(String(repeating: "1", count: 64))",
                detectorRuleID: "generic-api-key",
                commit: includesKnownDeepgramHistoryFinding
                    ? CoachOperationalLaunchChecklistEvidence.HistorySecretAdjudication
                        .knownDeepgramIncidentCommit
                    : String(repeating: "c", count: 40),
                path: "Noum/LegacyProviderConfig.swift",
                disposition: "revoked",
                statusEvidenceReference: "evidence://history-finding-1"
            ),
            CoachOperationalLaunchChecklistEvidence.HistorySecretAdjudication.Finding(
                findingID: "sha256:\(String(repeating: "2", count: 64))",
                detectorRuleID: "firebase-api-key",
                commit: String(repeating: "a", count: 40),
                path: "docs/legacy-config.md",
                disposition: "publicIdentifier",
                statusEvidenceReference: "evidence://history-finding-2"
            ),
            CoachOperationalLaunchChecklistEvidence.HistorySecretAdjudication.Finding(
                findingID: "sha256:\(String(repeating: "3", count: 64))",
                detectorRuleID: "generic-secret",
                commit: String(repeating: "b", count: 40),
                path: "scripts/legacy-smoke.sh",
                disposition: "invalidated",
                statusEvidenceReference: "evidence://history-finding-3"
            )
        ]
        return CoachOperationalLaunchChecklistEvidence(
            schemaVersion: CoachOperationalLaunchChecklistEvidence.expectedSchemaVersion,
            templateStatus: CoachOperationalLaunchChecklistEvidence.expectedTemplateStatus,
            checklistVersion: CoachOperationalLaunchChecklistEvidence.expectedChecklistVersion,
            releaseCandidateBuild: releaseCandidateBuild,
            completedByRole: "releaseManager",
            completedByID: "release-operator",
            releasePrerequisites: releasePrerequisites,
            historySecretAdjudication: CoachOperationalLaunchChecklistEvidence
                .HistorySecretAdjudication(
                    scanner: "gitleaks",
                    scannerVersion: "8.30.1",
                    scanScope: "all-reachable-commits",
                    scannedRepositoryCommit: "b05258ab55b05b3b895a8ddc538e82ce46e054c3",
                    redactionPercent: 100,
                    reachableCommitCount: 500,
                    reachableCommitSetSha256: "sha256:\(String(repeating: "a", count: 64))",
                    redactedScanReportReference: historyReportReferenceOverride ??
                        prerequisiteReference("fullHistorySecretFindingsAdjudicated"),
                    detectedFindingCount: historyFindings.count,
                    adjudicatedFindingCount: historyFindings.count,
                    unresolvedFindingCount: historyUnresolvedFindingCount,
                    suppressedFindingCount: 0,
                    findings: historyFindings
                ),
            summary: CoachOperationalLaunchChecklistEvidence.Summary(
                itemCount: items.count,
                completedRequiredItemCount: completedRequiredItems.count,
                failedRequiredItemCount: failedRequiredItems.count,
                artifactBackedItemCount: artifactBackedItems.count,
                expectedEvidenceKindItemCount: expectedEvidenceKindItems.count,
                expectedEnvironmentItemCount: expectedEnvironmentItems.count,
                sameBuildItemCount: sameBuildItems.count,
                verifiedRequiredItemCount: verifiedRequiredItems.count,
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
        let sourceGitCommit = Self.sourceGitCommitForAppPathTrace(
            dumpDirectory: Self.evaluationArtifactDumpDirectory()
        )
        let sourceFingerprint = Self.sourceCoachFingerprintForAppPathTrace(
            dumpDirectory: Self.evaluationArtifactDumpDirectory()
        )
        let schemaVersion = surface == .live
            ? CoachChatConversationCorpus.liveAppPathReportSchemaVersion
            : CoachChatConversationCorpus.appPathReportSchemaVersion
        for script in CoachChatConversationCorpus.appPathConversationScripts {
            let conversation = script.conversation
            let sourceFixture = CoachChatConversationCorpus.sourceFixture(for: conversation)
            let suiteName = "CoachChatConversationAppPath.\(surface.rawValue).\(conversation.id).\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            let previousProfile = CoachingProfileStore.shared.profile
            CoachingProfileStore.shared.replaceForDebug(sourceFixture?.profile)
            CoachAssessmentCache.shared.invalidate()
            UserTrajectoryCache.shared.invalidate()
            // Neutralize any proof archive state (leaked from a prior fixture or
            // an earlier test) so each conversation sees exactly its own seeded
            // evidence — the pipeline reads the shared singleton directly.
            ProofMomentStore.shared.clear()
            defer {
                defaults.removePersistentDomain(forName: suiteName)
                CoachingProfileStore.shared.replaceForDebug(previousProfile)
                CoachAssessmentCache.shared.invalidate()
                UserTrajectoryCache.shared.invalidate()
                ProofMomentStore.shared.clear()
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
            for seedReply in script.seedCoachReplies {
                store.injectCoachTurn(seedReply)
            }
            // Seed this fixture's verified proof quotes into the shared proof
            // archive the live pipeline reads (`ProofMomentStore.shared.recent`).
            // A gold reply that cites a past-rep quote (e.g. examples-from-sessions)
            // only clears the `unverifiedQuotedUserSpeech` / `missingVerifiedExampleQuote`
            // gates if that quote is real evidence — this makes the citation honest,
            // not fabricated. Uses `replaceForDebug` (the deterministic seed seam
            // DevSeedData uses); cleared above + in defer so it can't leak.
            if !script.seedProofQuotes.isEmpty {
                ProofMomentStore.shared.replaceForDebug(
                    script.seedProofQuotes.map { quote in
                        ProofMomentRecord(
                            sessionID: UUID(),
                            proof: ProofMoment(
                                quote: quote,
                                technique: "Concrete Example",
                                claim: "That is the specific rep to point back to.",
                                sessionDate: Date(),
                                isAIBacked: false,
                                generatedAt: Date()
                            )
                        )
                    }
                )
            }
            // Real evidence for this conversation: the source fixture's practice
            // sessions. Injecting them (vs. an empty global store) makes the
            // pipeline's UserTrajectory.evidenceCoverage vary per conversation, so
            // assessmentConfidence rises legitimately with evidence instead of pinning
            // every turn to the thin-evidence 0.20 floor. This mirrors the shipping
            // precondition that Ask Noum chat happens after a baseline exists.
            let sourceSessions = sourceFixture?.sessions ?? []
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
                    sessionsOverride: sourceSessions,
                    coachMemoryOverride: { nil },
                    onQualityGateEvent: { event in
                        qualityGateEvents.append(event)
                    }
                )
                let coach = store.messages.first { $0.id == ids.coachID }
                let metadata = coach?.metadata
                let finalReply = coach?.role == .coach ? coach?.text : nil
                // AskNoumStore persists the sanitized reply through
                // CoachDisplayCopy. Compare the app path with that same
                // user-facing contract; otherwise an intentional vocabulary
                // translation (for example, "lever" -> "focus") is reported
                // as a coach failure even though the shipping store behaved
                // exactly as designed.
                let persistedTarget = Self.persistedCoachReplyTarget(
                    from: turn.coachReply
                )
                let targetReplyMatched = finalReply == persistedTarget
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
                let turnIntent = metadata?.turnIntent ??
                    CoachChatTurnIntent.classify(turn.userTurn)
                let responseKind = metadata?.responseKind ??
                    CoachChatResponseKind.classify(turn.userTurn)
                let semanticGateExpectation =
                    CoachChatConversationAppPathSemanticExpectation
                        .forResponseKind(responseKind)
                let typedAssessmentPresent = metadata?.assessment != nil
                let assessmentConfidence = metadata?.assessmentConfidence ??
                    metadata?.assessment?.confidence
                let qualityGateOutcome = metadata?.qualityGateOutcome?.logValue
                let qualityGateAcceptedFallback = outcomeSucceeded &&
                    (qualityGateOutcome?.hasPrefix("fallback:") == true)
                let callbackQualityGateEventLogValues = qualityGateEvents
                    .map(CoachReplyPipeline.qualityGateEventLogValue)
                let persistedQualityGateEventLogValues = metadata?.qualityGateEvents ?? []
                let qualityGateEventLogValues = persistedQualityGateEventLogValues.isEmpty
                    ? callbackQualityGateEventLogValues
                    : persistedQualityGateEventLogValues
                let typedAssessmentFallbackApplied = qualityGateOutcome == "fallback:typedAssessment" ||
                    qualityGateEventLogValues.contains("fallback:typedAssessment")
                let deterministicAssessmentFallbackApplied =
                    qualityGateOutcome == "fallback:deterministicAssessmentAfterContentRejected" ||
                    qualityGateEventLogValues.contains("fallback:deterministicAssessmentAfterContentRejected")
                let qualityGateClean: Bool = {
                    switch metadata?.qualityGateOutcome {
                    case .passed?, .repaired?, .notEvaluated?:
                        return true
                    case .fallback?, .failed?, nil:
                        return false
                    }
                }()
                let qualityGateBlockingFailure = qualityGateOutcome?.hasPrefix("failed:") == true
                let reliabilityIssues = metadata?.reliabilityIssues?.map(\.rawValue) ?? []
                let blockingReliabilityIssues = metadata?.reliabilityIssues?
                    .filter(\.isBlocking)
                    .map(\.rawValue) ?? []
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
                let semanticGateContractSatisfied = semanticGateExpectation
                    .isSatisfied(
                        semanticGateOutcome: metadata?.semanticGateOutcome?.logValue,
                        typedAssessmentPresent: typedAssessmentPresent,
                        assessmentConfidence: assessmentConfidence,
                        proofTestHash: metadata?.proofTestHash,
                        immediateCoachReadExpected: immediateCoachReadExpected,
                        immediateCoachReadShown: immediateCoachReadShown
                    )
                let passesAppPathFloor = outcomeSucceeded &&
                    targetReplyMatched &&
                    metadata != nil &&
                    semanticGateContractSatisfied &&
                    qualityGateClean &&
                    blockingReliabilityIssues.isEmpty &&
                    metadata?.visionPassesProductionFloor == true &&
                    immediateCoachReadSatisfied
                let arenaTrace = CoachArenaAppPathTrace.make(
                    conversationID: conversation.id,
                    sourceFixtureID: conversation.sourceFixtureID,
                    turnIndex: index,
                    userTurn: turn.userTurn,
                    surface: surface,
                    targetCoachReply: persistedTarget,
                    finalCoachReply: finalReply,
                    metadata: metadata,
                    qualityGateEvents: qualityGateEventLogValues,
                    qualityGateAcceptedFallback: qualityGateAcceptedFallback,
                    typedAssessmentFallbackApplied: typedAssessmentFallbackApplied,
                    deterministicAssessmentFallbackApplied: deterministicAssessmentFallbackApplied,
                    schemaVersion: schemaVersion,
                    gitCommit: sourceGitCommit,
                    sourceFingerprint: sourceFingerprint
                )

                turnRows.append(CoachChatConversationAppPathTurnRow(
                    turnIndex: index,
                    userTurn: turn.userTurn,
                    targetCoachReply: persistedTarget,
                    finalCoachReply: finalReply,
                    outcomeSucceeded: outcomeSucceeded,
                    targetReplyMatched: targetReplyMatched,
                    metadataPresent: metadata != nil,
                    turnIntent: turnIntent.rawValue,
                    responseKind: responseKind.rawValue,
                    turnDepth: metadata?.turnDepth?.rawValue,
                    providerTierRequested: metadata?.providerTier?.rawValue,
                    providerTierChosen: metadata?.providerTierChosen?.rawValue,
                    providerName: metadata?.providerName,
                    providerModel: metadata?.providerModel,
                    semanticGateExpectation: semanticGateExpectation,
                    semanticGateOutcome: metadata?.semanticGateOutcome?.logValue,
                    semanticGateIssue: metadata?.semanticGateIssue,
                    semanticGatePassed: semanticGatePassed,
                    typedAssessmentPresent: typedAssessmentPresent,
                    qualityGateOutcome: qualityGateOutcome,
                    qualityGateEvents: qualityGateEventLogValues,
                    qualityGateClean: qualityGateClean,
                    qualityGateAcceptedFallback: qualityGateAcceptedFallback,
                    typedAssessmentFallbackApplied: typedAssessmentFallbackApplied,
                    deterministicAssessmentFallbackApplied: deterministicAssessmentFallbackApplied,
                    qualityGateBlockingFailure: qualityGateBlockingFailure,
                    reliabilityIssues: reliabilityIssues,
                    visionScore: metadata?.visionScore,
                    visionPassesProductionFloor: metadata?.visionPassesProductionFloor,
                    immediateCoachReadExpected: immediateCoachReadExpected,
                    immediateCoachReadShown: immediateCoachReadShown,
                    assessmentConfidence: assessmentConfidence,
                    proofTestHash: metadata?.proofTestHash,
                    proofTestRecentlyRepeated: metadata?.proofTestRecentlyRepeated,
                    retrievalTrace: metadata?.retrievalTrace,
                    arenaTrace: arenaTrace,
                    timeToFirstVisibleTokenMs: metadata?.timeToFirstVisibleTokenMs,
                    timeToFirstVisibleTokenSource: metadata?.timeToFirstVisibleTokenSource?.rawValue,
                    timeToCompleteReplyMs: metadata?.timeToCompleteReplyMs,
                    trajectoryCacheHit: metadata?.trajectoryCacheHit,
                    assessmentCacheHit: metadata?.assessmentCacheHit,
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

    private static func persistedCoachReplyTarget(from raw: String) -> String {
        CoachDisplayCopy.normalized(
            CoachReplyTextSanitizer.coachReplyText(from: raw)
        )
    }

    @MainActor
    static func dumpTextAppPathReportForXCTestBridge() async throws {
        try await dumpAppPathReportForXCTestBridge(
            surface: .text,
            schemaVersion: CoachChatConversationCorpus.appPathReportSchemaVersion,
            fileName: "coach-chat-conversation-app-path-eval-v1.json"
        )
    }

    @MainActor
    static func dumpLiveAppPathReportForXCTestBridge() async throws {
        try await dumpAppPathReportForXCTestBridge(
            surface: .live,
            schemaVersion: CoachChatConversationCorpus.liveAppPathReportSchemaVersion,
            fileName: "coach-chat-live-app-path-eval-v1.json"
        )
    }

    @MainActor
    static func dumpExpertCalibrationPacketForXCTestBridge() throws {
        let packet = CoachChatConversationExpertCalibrationPacket.make(
            from: CoachChatConversationCorpus.professionalCalibrationConversations
        )
        try Self.dumpEvaluationArtifactIfRequested(
            packet.encodedSortedJSON(),
            fileName: "\(CoachChatConversationCorpus.expertCalibrationPacketSchemaVersion).json"
        )
    }

    @MainActor
    static func dumpGoalStyleCalibrationPacketForXCTestBridge() throws {
        let packet = try GoalStyleCalibrationFixtures.packet()
        try Self.dumpEvaluationArtifactIfRequested(
            packet.encodedSortedJSON(),
            fileName: GoalStyleCalibrationPacket.artifactFileName
        )
    }

    @MainActor
    static func dumpProductionReadinessManifestForXCTestBridge() throws {
        let manifest = try Self.productionReadinessEvidenceManifestFromCurrentArtifacts()
        try Self.dumpEvaluationArtifactIfRequested(
            manifest.encodedSortedJSON(),
            fileName: "coach-vision-production-readiness-evidence-manifest-v1.json"
        )
    }

    @MainActor
    private static func dumpAppPathReportForXCTestBridge(
        surface: CoachReplySurface,
        schemaVersion: String,
        fileName: String
    ) async throws {
        let rows = await Self.scriptedConversationAppPathRows(surface: surface)
        let targetReport = CoachChatConversationEvaluationReport.make(
            from: CoachChatConversationCorpus.appPathConversations
        )
        let report = CoachChatConversationAppPathReport.make(
            rows: rows,
            localTargetShapeScore: targetReport.visionProductionReadiness.localTargetShapeScore,
            schemaVersion: schemaVersion,
            surface: surface
        )
        try Self.dumpEvaluationArtifactIfRequested(
            report.encodedSortedJSON(),
            fileName: fileName
        )
    }
}

@MainActor
final class CoachChatConversationArtifactDumpXCTest: XCTestCase {

    func testDumpTextAppPathReport() async throws {
        try await CoachChatConversationCorpusTests.dumpTextAppPathReportForXCTestBridge()
    }

    func testDumpLiveAppPathReport() async throws {
        try await CoachChatConversationCorpusTests.dumpLiveAppPathReportForXCTestBridge()
    }

    func testDumpExpertCalibrationPacket() throws {
        try CoachChatConversationCorpusTests.dumpExpertCalibrationPacketForXCTestBridge()
    }

    func testDumpGoalStyleCalibrationPacket() throws {
        try CoachChatConversationCorpusTests.dumpGoalStyleCalibrationPacketForXCTestBridge()
    }

    func testDumpProductionReadinessManifest() throws {
        try CoachChatConversationCorpusTests.dumpProductionReadinessManifestForXCTestBridge()
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

        #expect(report.conversationCount == CoachChatConversationCorpus.conversations.count)
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
                professionalCoachCalibrationRows: CoachProfessionalCalibrationEvidence.requiredCalibrationReviewCount,
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
