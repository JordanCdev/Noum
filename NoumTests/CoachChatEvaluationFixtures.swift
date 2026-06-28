//
//  CoachChatEvaluationFixtures.swift
//  NoumTests
//
//  Version-controlled Ask Noum evaluation fixtures.
//  SUBSTRATE ONLY: these fixtures are regression guards, not expert
//  calibration and not proof of human-coach parity.
//

import Foundation
import Testing
@testable import Noum

enum CoachChatEvaluationPillar: String, CaseIterable, Codable {
    case diagnosis
    case prescription
    case adaptation
    case transfer
    case honesty
    case validation
}

enum CoachChatExpertBaselineStatus: String, Codable, Equatable {
    case pendingExpertReview
}

struct CoachChatExpertBaselineSlot: Codable, Equatable {
    let status: CoachChatExpertBaselineStatus
    let baselineID: String?
    let coachSummary: String?
    let scoringRubricVersion: String

    static let pending = CoachChatExpertBaselineSlot(
        status: .pendingExpertReview,
        baselineID: nil,
        coachSummary: nil,
        scoringRubricVersion: "coach-chat-eval-v1"
    )
}

struct CoachChatEvaluationFixture {
    let id: String
    let pillar: CoachChatEvaluationPillar
    let expertBaseline: CoachChatExpertBaselineSlot
    let profile: CoachingProfile?
    let sessions: [PracticeSession]
    let trends: [SkillTrend]
    let latestUserTurn: String
    let previousCoachReply: String?
    let expectedContextNeedles: [String]
    let referenceReply: String
    let knownBadReply: String
    let expectedBadIssue: CoachChatReplyQualityIssue
}

struct CoachChatEvaluationCIReport: Codable, Equatable {
    let schemaVersion: String
    let fixtureCount: Int
    let rows: [CoachChatEvaluationCIReportRow]

    static func make(from fixtures: [CoachChatEvaluationFixture]) -> CoachChatEvaluationCIReport {
        CoachChatEvaluationCIReport(
            schemaVersion: CoachChatEvaluationCorpus.reportSchemaVersion,
            fixtureCount: fixtures.count,
            rows: fixtures.map { fixture in
                let context = CoachChatEvaluationCorpus.renderedContext(for: fixture)
                let referenceResult = AICoachChatService.professionalCoachRubric(
                    reply: fixture.referenceReply,
                    latestUserTurn: fixture.latestUserTurn
                )
                let referenceIssue = AICoachChatService.replyQualityIssue(
                    in: fixture.referenceReply,
                    latestUserTurn: fixture.latestUserTurn,
                    quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                    systemContext: context
                )
                let issue = AICoachChatService.replyQualityIssue(
                    in: fixture.knownBadReply,
                    latestUserTurn: fixture.latestUserTurn,
                    quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                    systemContext: context
                )
                return CoachChatEvaluationCIReportRow(
                    fixtureID: fixture.id,
                    pillar: fixture.pillar.rawValue,
                    expertBaselineStatus: fixture.expertBaseline.status.rawValue,
                    referenceReplyPassesRubric: referenceResult.passesSeniorCoachFloor,
                    referenceReplyPassesQualityGate: referenceIssue == nil,
                    knownBadIssueMatched: issue == fixture.expectedBadIssue,
                    expectedBadIssue: String(describing: fixture.expectedBadIssue),
                    contextNeedleCount: fixture.expectedContextNeedles.count
                )
            }
        )
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct CoachChatEvaluationCIReportRow: Codable, Equatable {
    let fixtureID: String
    let pillar: String
    let expertBaselineStatus: String
    let referenceReplyPassesRubric: Bool
    let referenceReplyPassesQualityGate: Bool
    let knownBadIssueMatched: Bool
    let expectedBadIssue: String
    let contextNeedleCount: Int
}

struct CoachChatExpertReviewPacket: Codable, Equatable {
    let schemaVersion: String
    let rubricVersion: String
    let instructions: String
    let responseSchema: String
    let fixtureCount: Int
    let rows: [CoachChatExpertReviewPacketRow]

    static func make(from fixtures: [CoachChatEvaluationFixture]) -> CoachChatExpertReviewPacket {
        CoachChatExpertReviewPacket(
            schemaVersion: CoachChatEvaluationCorpus.expertReviewPacketSchemaVersion,
            rubricVersion: "coach-chat-eval-v1",
            instructions: [
                "Write the answer an excellent human communication coach would give for each case.",
                "Use only the supplied user turn, prior coach reply, and Noum context.",
                "Name one highest-leverage next move; avoid broad menus, trait labels, diagnoses, or claims that the app is validated.",
                "Mark thin evidence as a hypothesis and include what evidence would change your view.",
                "Do not score Noum in this packet; this captures an independent expert baseline for later blinded comparison."
            ].joined(separator: " "),
            responseSchema: "Return one JSON object per fixture: {\"fixtureID\": string, \"coachSummary\": string, \"recommendedReply\": string, \"evidenceUsed\": [string], \"uncertainty\": string, \"qualityNotes\": [string]}.",
            fixtureCount: fixtures.count,
            rows: fixtures.map { fixture in
                CoachChatExpertReviewPacketRow(
                    fixtureID: fixture.id,
                    pillar: fixture.pillar.rawValue,
                    expertBaselineStatus: fixture.expertBaseline.status.rawValue,
                    latestUserTurn: fixture.latestUserTurn,
                    previousCoachReply: fixture.previousCoachReply,
                    coachContext: CoachChatEvaluationCorpus.renderedContext(for: fixture)
                )
            }
        )
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct CoachChatExpertReviewPacketRow: Codable, Equatable {
    let fixtureID: String
    let pillar: String
    let expertBaselineStatus: String
    let latestUserTurn: String
    let previousCoachReply: String?
    let coachContext: String
}

enum CoachChatEvaluationCorpus {
    static let reportSchemaVersion = "coach-chat-eval-report-v2"
    static let expertReviewPacketSchemaVersion = "coach-chat-expert-review-packet-v1"
    static let latestManualEvalFixtureIDs = [
        "cold-start-interview-baseline",
        "filler-pressure-prescription",
        "metric-action-without-read",
        "critique-trust-repair",
        "markdown-tts-trust-repair",
        "assistant-explainer-register",
        "authoritative-distance-deep-assessment",
        "what-next-single-move",
        "overclaim-hypothesis-boundary",
        "leadership-transfer-setup",
        "pace-control-next-rep",
        "closing-ask-proof-test",
        "opening-verdict-next-rep",
        "pause-before-answer-drill",
        "concise-answer-next-rep",
        "structure-one-reason-proof",
        "confidence-clean-stop",
        "answer-depth-one-example",
        "closing-stop-no-summary"
    ]

    static let fixtures: [CoachChatEvaluationFixture] = [
        CoachChatEvaluationFixture(
            id: "cold-start-interview-baseline",
            pillar: .diagnosis,
            expertBaseline: .pending,
            profile: nil,
            sessions: [],
            trends: [],
            latestUserTurn: "How do I get better before my interview?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "No voice set yet",
                "No rated sessions yet",
                "Not enough data for a stable baseline yet",
                "COACH FORMULATION",
                "first useful coaching move is one usable rep",
                "do not ask a discovery question"
            ],
            referenceReply: "No baseline yet, so the honest move is one interview rep. Record 60 seconds on a likely question, then review whether the first sentence gives the point before polishing anything.",
            knownBadReply: "Keep practicing and try to sound more confident.",
            expectedBadIssue: .ignoredCoachingExpertise
        ),
        CoachChatEvaluationFixture(
            id: "filler-pressure-prescription",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .concise, challenge: .fillerWords),
            sessions: [
                session(
                    id: "11111111-1111-1111-1111-111111111111",
                    transcript: "I think the plan is strong, um, but I need the team to move faster before Friday.",
                    fillerCount: 6,
                    duration: 64,
                    daysAgo: 1,
                    mode: .timed,
                    score: 6,
                    prompt: "Give a concise team update."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .fillerReduction,
                    direction: .declining,
                    confidence: .high,
                    windowSize: 5,
                    currentLevel: .weak,
                    recentDelta: "2 more fillers vs prior window"
                )
            ],
            latestUserTurn: "How do I stop saying um under pressure?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "6 fillers",
                "TRENDS",
                "COACH FORMULATION",
                "silence as the replacement behavior"
            ],
            referenceReply: "Last rep had 6 fillers; the pressure cue is showing up before the close. Next rep, hold one beat before the final sentence and cut every filler after that point.",
            knownBadReply: "Based on your data, the key insight is reducing fillers.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "metric-action-without-read",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .authoritative, challenge: .fillerWords),
            sessions: [
                session(
                    id: "66666666-6666-6666-6666-666666666666",
                    transcript: "The recommendation is to hold the launch date, um, because the customer migration is not ready.",
                    fillerCount: 5,
                    duration: 61,
                    daysAgo: 1,
                    mode: .timed,
                    score: 6,
                    prompt: "Give a direct recommendation."
                )
            ],
            trends: [],
            latestUserTurn: "What should I do with that filler count?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "5 fillers",
                "Safe filler fact",
                "COACH FORMULATION",
                "leverage is the beat after the decision"
            ],
            referenceReply: "Last rep had 5 fillers; the signal is inside the recommendation, not before it. Next rep, hold one beat after the decision line and restart if a filler appears.",
            knownBadReply: "Your last rep had 5 fillers. Next rep, hold one beat before sentence two.",
            expectedBadIssue: .missingInsightBridge
        ),
        CoachChatEvaluationFixture(
            id: "critique-trust-repair",
            pillar: .adaptation,
            expertBaseline: .pending,
            profile: profile(voice: .warm, challenge: .rambling),
            sessions: [
                session(
                    id: "22222222-2222-2222-2222-222222222222",
                    transcript: "The point is that I can help the client, but I went too wide before saying it.",
                    fillerCount: 1,
                    duration: 58,
                    daysAgo: 0,
                    mode: .timed,
                    score: 7,
                    prompt: "Answer a client objection warmly."
                )
            ],
            trends: [],
            latestUserTurn: "This is robotic and too much writing.",
            previousCoachReply: "Recent reps show a decline in scores, so you should optimize your communication plan.",
            expectedContextNeedles: [
                "repair trust first",
                "specific friction",
                "RECENT (most-recent first)"
            ],
            referenceReply: "Fair push: that read was too generic. The last rep gives enough signal; next rep, use one clean opener and stop after the point lands.",
            knownBadReply: "Next rep, use one clean opener and stop after the point lands.",
            expectedBadIssue: .missedTrustRepair
        ),
        CoachChatEvaluationFixture(
            id: "markdown-tts-trust-repair",
            pillar: .adaptation,
            expertBaseline: .pending,
            profile: profile(voice: .authoritative, challenge: .fillerWords),
            sessions: [
                session(
                    id: "77777777-7777-7777-7777-777777777777",
                    transcript: "My recommendation is to hold the date, um, because the launch risk is still unresolved.",
                    fillerCount: 4,
                    duration: 52,
                    daysAgo: 0,
                    mode: .timed,
                    score: 6,
                    prompt: "Give a direct stakeholder recommendation."
                )
            ],
            trends: [],
            latestUserTurn: "The ** don't format and TTS reads them out. The responses feel robotic and cold, nowhere near an expert coach.",
            previousCoachReply: "**Read:** Your last rep has fillers. **Move:** practice more.",
            expectedContextNeedles: [
                "repair trust first",
                "specific friction",
                "Never output literal Markdown markers",
                "same text may be spoken aloud"
            ],
            referenceReply: "Fair push: the stars should never reach you or the voice. Your last rep had 4 fillers, so state the recommendation first and stop after one proof — no symbols, no report shape.",
            knownBadReply: "The app is designed to provide AI coaching, and formatting like **Read:** may appear while the system improves.",
            expectedBadIssue: .defensiveProductLanguage
        ),
        CoachChatEvaluationFixture(
            id: "assistant-explainer-register",
            pillar: .adaptation,
            expertBaseline: .pending,
            profile: profile(voice: .warm, challenge: .rambling),
            sessions: [
                session(
                    id: "88888888-8888-8888-8888-888888888888",
                    transcript: "I wanted to reassure the client first, but I took too long to say the actual recommendation.",
                    fillerCount: 1,
                    duration: 66,
                    daysAgo: 0,
                    mode: .timed,
                    score: 6,
                    prompt: "Answer a client concern with warmth."
                )
            ],
            trends: [],
            latestUserTurn: "This still sounds cold and overexplained, like generic AI tips.",
            previousCoachReply: "Here are some tips to communicate more clearly: be clear and concise and practice often.",
            expectedContextNeedles: [
                "repair trust first",
                "specific friction",
                "RECENT (most-recent first)",
                "1 filler",
                "Safe warmth fact",
                "COACH FORMULATION",
                "ordering signal"
            ],
            referenceReply: "Fair push: that was advice, not coaching. Your last rep has the useful signal: warmth came before the recommendation, so next rep say the recommendation first, then soften it with one reassurance.",
            knownBadReply: "I understand your frustration. Here are some tips to communicate more clearly: be clear and concise, structure your thoughts, and practice confidence.",
            expectedBadIssue: .roboticPhrase("i understand your frustration")
        ),
        CoachChatEvaluationFixture(
            id: "authoritative-distance-deep-assessment",
            pillar: .honesty,
            expertBaseline: .pending,
            profile: profile(voice: .authoritative, challenge: .fillerWords),
            sessions: [
                session(
                    id: "99999999-9999-9999-9999-999999999999",
                    transcript: "My recommendation is to keep the launch date because the customer migration risk is contained, and the team needs a clear decision today.",
                    fillerCount: 1,
                    duration: 60,
                    daysAgo: 0,
                    mode: .timed,
                    score: 7,
                    prompt: "Give a direct stakeholder recommendation."
                )
            ],
            trends: [],
            latestUserTurn: "How far off am I from sounding authoritative?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "7/10",
                "1 filler",
                "ARGUMENT LOGIC",
                "authoritative"
            ],
            referenceReply: "You are closer mechanically than you are to sounding authoritative overall. Your last rep was 7/10 with 1 filler, so the mechanics are partly landing, but goal readiness still needs repeated pressure evidence. Missing: more than one clean rep under stakes. Proof test: record a 75-second answer with the verdict in sentence one, one reason, and a clean stop.",
            knownBadReply: "This proves you are close to sounding authoritative. You scored 7/10, so use fewer fillers next time.",
            expectedBadIssue: .overclaimsEvidence
        ),
        CoachChatEvaluationFixture(
            id: "what-next-single-move",
            pillar: .validation,
            expertBaseline: .pending,
            profile: profile(voice: .executive, challenge: .rushing),
            sessions: [
                session(
                    id: "33333333-3333-3333-3333-333333333333",
                    transcript: "We can keep the launch tight if we align scope now and make the decision before noon.",
                    fillerCount: 0,
                    duration: 42,
                    daysAgo: 2,
                    mode: .timed,
                    score: 8,
                    prompt: "Give an executive update."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .closingStrength,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "close lost force in recent reps"
                )
            ],
            latestUserTurn: "What next?",
            previousCoachReply: "Which direction would you prefer?",
            expectedContextNeedles: [
                "choose the highest-leverage next action",
                "No broad menu",
                "RECENT (most-recent first)"
            ],
            referenceReply: "The pattern I'd pick is the rushed close. Review the last transcript, rewrite only the final sentence, then run one rep with that close as the target.",
            knownBadReply: "We can work on fillers or structure. What is your priority today?",
            expectedBadIssue: .menuInsteadOfDecision
        ),
        CoachChatEvaluationFixture(
            id: "overclaim-hypothesis-boundary",
            pillar: .honesty,
            expertBaseline: .pending,
            profile: profile(voice: .authoritative, challenge: .freezing),
            sessions: [
                session(
                    id: "44444444-4444-4444-4444-444444444444",
                    transcript: "I waited too long to state the recommendation, then gave the context after it.",
                    fillerCount: 2,
                    duration: 55,
                    daysAgo: 1,
                    mode: .timed,
                    score: 6,
                    prompt: "Make a recommendation under pressure."
                )
            ],
            trends: [],
            latestUserTurn: "Why did that answer land badly?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "PROMPT RELEVANCE",
                "ARGUMENT LOGIC",
                "RECENT (most-recent first)",
                "REPLY-SAFE FACTS",
                "recommendation arrived late",
                "do not say the point led",
                "2 fillers",
                "COACH FORMULATION",
                "do not say the recommendation was up front"
            ],
            referenceReply: "From the transcript, I would treat it as a hypothesis: the recommendation arrived late. Next rep, say the conclusion first, then add one reason.",
            knownBadReply: "You are clearly evasive, and this proves you lack conviction.",
            expectedBadIssue: .overclaimsEvidence
        ),
        CoachChatEvaluationFixture(
            id: "leadership-transfer-setup",
            pillar: .transfer,
            expertBaseline: .pending,
            profile: profile(voice: .executive, challenge: .rambling),
            sessions: [
                session(
                    id: "55555555-5555-5555-5555-555555555555",
                    transcript: "The update is simple: customer onboarding is ahead, support volume is down, and I need approval on the rollout date.",
                    fillerCount: 0,
                    duration: 72,
                    daysAgo: 3,
                    mode: .timed,
                    score: 8,
                    prompt: "Give a leadership update."
                )
            ],
            trends: [],
            latestUserTurn: "I have a leadership update tomorrow, what should I practice?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "Where they want to use this",
                "RECENT (most-recent first)",
                "0 fillers",
                "COACH FORMULATION",
                "75-second update"
            ],
            referenceReply: "Your recent timed rep was solid on fillers but light on the close. Record a 75-second leadership update and make the final sentence the ask, not a summary.",
            knownBadReply: "You should think about your audience and try to communicate clearly.",
            expectedBadIssue: .ignoredCoachingExpertise
        ),
        CoachChatEvaluationFixture(
            id: "pace-control-next-rep",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .executive, challenge: .rushing),
            sessions: [
                session(
                    id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                    transcript: "The decision is to keep support staffed through Friday because the migration will create two peak windows, and I need approval today.",
                    fillerCount: 0,
                    duration: 38,
                    daysAgo: 1,
                    mode: .timed,
                    score: 7,
                    prompt: "Give a calm operations update."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .paceControl,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "recent reps are landing compressed"
                )
            ],
            latestUserTurn: "How do I slow down without sounding unsure?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "Current coaching hypothesis: Pace is the next lever",
                "recent reps are landing compressed"
            ],
            referenceReply: "Your last rep is clean but compressed. Next rep, keep the same first sentence, then pause once after the decision so the reason has room to land.",
            knownBadReply: "Based on your data, slow down and sound more confident.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "closing-ask-proof-test",
            pillar: .validation,
            expertBaseline: .pending,
            profile: profile(voice: .persuasive, challenge: .rambling),
            sessions: [
                session(
                    id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
                    transcript: "The pilot is working, adoption is up, and I need your approval to expand it next week.",
                    fillerCount: 1,
                    duration: 54,
                    daysAgo: 1,
                    mode: .timed,
                    score: 7,
                    prompt: "Make a persuasive request."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .closingStrength,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "final ask has softened in recent reps"
                )
            ],
            latestUserTurn: "How do I make the ending stronger?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "1 filler",
                "TRENDS",
                "Current coaching hypothesis: Closings is the next lever",
                "final ask has softened in recent reps"
            ],
            referenceReply: "Your last rep already named the approval ask, but the close still softened after the evidence. Next rep, make the final sentence the ask itself: approve the expansion next week, then stop.",
            knownBadReply: "Based on your data, think about your audience and communicate more clearly.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "opening-verdict-next-rep",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .authoritative, challenge: .rambling),
            sessions: [
                session(
                    id: "cccccccc-cccc-cccc-cccc-cccccccccccc",
                    transcript: "The answer is yes, the pilot is ready to expand because usage is up and support volume is stable.",
                    fillerCount: 0,
                    duration: 46,
                    daysAgo: 1,
                    mode: .timed,
                    score: 8,
                    prompt: "Give a concise recommendation."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .openingStrength,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "openers are warming up before the point"
                )
            ],
            latestUserTurn: "How do I make the opening stronger?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "openers are warming up before the point",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep is clean, but the useful gap is the opener: it warms into the point, so the verdict arrives late. Next rep, make sentence one the verdict, then add one reason.",
            knownBadReply: "Based on your data, make the opening clearer.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "pause-before-answer-drill",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .executive, challenge: .freezing),
            sessions: [
                session(
                    id: "dddddddd-dddd-dddd-dddd-dddddddddddd",
                    transcript: "I think we should pause the rollout because the support queue is overloaded and the customer risk is still open.",
                    fillerCount: 2,
                    duration: 50,
                    daysAgo: 1,
                    mode: .timed,
                    score: 6,
                    prompt: "Respond to a difficult stakeholder question."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .pauseUsage,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "pauses are disappearing under pressure"
                )
            ],
            latestUserTurn: "What should I practice when I freeze before answering?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "2 fillers",
                "TRENDS",
                "pauses are disappearing under pressure",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep had 2 fillers, and the signal is the pause disappearing before the answer. Next rep, hold one silent beat before sentence one, then answer.",
            knownBadReply: "Based on your data, practice confidence and communicate clearly.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "concise-answer-next-rep",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .concise, challenge: .rambling),
            sessions: [
                session(
                    id: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
                    transcript: "The proposal is ready, the cost is controlled, and the team can begin on Monday if we approve today.",
                    fillerCount: 0,
                    duration: 49,
                    daysAgo: 1,
                    mode: .timed,
                    score: 8,
                    prompt: "Give a concise project update."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .conciseSpeaking,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "recent answers are carrying extra context"
                )
            ],
            latestUserTurn: "How do I tighten this answer?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "recent answers are carrying extra context",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep is already clean; the signal is the extra condition adding drag. Next rep, say the recommendation in one sentence, give one reason, then stop.",
            knownBadReply: "Based on your data, make it shorter and communicate clearly.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "structure-one-reason-proof",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .persuasive, challenge: .rambling),
            sessions: [
                session(
                    id: "ffffffff-ffff-ffff-ffff-ffffffffffff",
                    transcript: "The pilot should continue because adoption rose and support load stayed manageable.",
                    fillerCount: 0,
                    duration: 57,
                    daysAgo: 1,
                    mode: .timed,
                    score: 7,
                    prompt: "Make a persuasive case."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .structure,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "reasons are not consistently tied to the ask"
                )
            ],
            latestUserTurn: "How do I make the middle clearer?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "reasons are not consistently tied to the ask",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep has the claim and a reason; the signal is that the reason is not yet tied to the ask. Next rep, use claim, one reason, and one sentence that says what that reason makes possible.",
            knownBadReply: "Based on your data, structure the middle more clearly.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "confidence-clean-stop",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .authoritative, challenge: .freezing),
            sessions: [
                session(
                    id: "12121212-1212-1212-1212-121212121212",
                    transcript: "My recommendation is to keep the launch date because the risk is contained.",
                    fillerCount: 0,
                    duration: 36,
                    daysAgo: 1,
                    mode: .timed,
                    score: 7,
                    prompt: "Give a direct recommendation."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .confidence,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "final lines are ending cautiously"
                )
            ],
            latestUserTurn: "How do I sound more certain at the end?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "final lines are ending cautiously",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep is clear; the signal is the close keeps softening. Next rep, say the recommendation once, give one reason, and stop without adding a softener.",
            knownBadReply: "Based on your data, sound more confident and believe in yourself.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "answer-depth-one-example",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .executive, challenge: .rambling),
            sessions: [
                session(
                    id: "34343434-3434-3434-3434-343434343434",
                    transcript: "We should retain the vendor because implementation risk is lower, the team already knows the workflow, and switching now would slow the launch.",
                    fillerCount: 0,
                    duration: 63,
                    daysAgo: 1,
                    mode: .timed,
                    score: 8,
                    prompt: "Give an executive recommendation."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .answerDevelopment,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "answers need one concrete example before they expand"
                )
            ],
            latestUserTurn: "How do I add depth without rambling?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "answers need one concrete example before they expand",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep has strong reasons; the signal is no concrete example for the listener to picture. Next rep, keep the same claim, add one example, then stop before adding a second thread.",
            knownBadReply: "Based on your data, add more depth but avoid rambling.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "closing-stop-no-summary",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .executive, challenge: .rambling),
            sessions: [
                session(
                    id: "56565656-5656-5656-5656-565656565656",
                    transcript: "The safest choice is to renew the contract, keep support stable, and review pricing after the pilot.",
                    fillerCount: 0,
                    duration: 48,
                    daysAgo: 1,
                    mode: .timed,
                    score: 8,
                    prompt: "Give a concise recommendation."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .closingStrength,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "final sentences are turning into summaries"
                )
            ],
            latestUserTurn: "How do I stop trailing off at the end?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "final sentences are turning into summaries",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep has the decision; the signal is the ending turns into a summary. Next rep, make the final sentence the decision itself and stop there.",
            knownBadReply: "Based on your data, make the ending stronger and clearer.",
            expectedBadIssue: .roboticPhrase("based on your data")
        )
    ]

    static func deterministicCoachingExpertise(for fixture: CoachChatEvaluationFixture) -> [CoachKnowledgeCard] {
        KnowledgeRetriever.retrieve(
            query: fixture.latestUserTurn,
            lever: fixture.trends.first?.skillArea,
            voice: fixture.profile?.speakingStyleGoal,
            hasDiagnosis: !fixture.sessions.isEmpty
        )
    }

    static func quoteGuard(for fixture: CoachChatEvaluationFixture) -> CoachChatQuoteGuardContext {
        let recentTimed = fixture.sessions
            .filter { $0.mode == .timed }
            .max(by: { $0.date < $1.date })
        return CoachChatQuoteGuardContext(
            transcripts: [recentTimed?.transcript],
            latestUserTurn: fixture.latestUserTurn,
            recentUserTurns: [fixture.latestUserTurn]
        )
    }

    static func renderedContext(for fixture: CoachChatEvaluationFixture) -> String {
        CoachContextBuilder.userContext(
            profile: fixture.profile,
            baseline: .empty,
            rating: .initial,
            sessions: fixture.sessions,
            currentStreak: fixture.sessions.isEmpty ? 0 : 2,
            pathStatus: nil,
            pathGatingPhrase: nil,
            trends: fixture.trends,
            latestUserTurn: fixture.latestUserTurn,
            previousCoachReply: fixture.previousCoachReply,
            coachingExpertise: deterministicCoachingExpertise(for: fixture)
        )
    }

    static func contains(_ haystack: String, _ needle: String) -> Bool {
        haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static func profile(
        voice: SpeakingStyleGoal,
        challenge: SpeakingChallenge
    ) -> CoachingProfile {
        CoachingProfile(
            speakingContext: .work,
            primaryGoal: challenge.recommendedPriority,
            confidenceLevel: .inconsistent,
            biggestChallenge: challenge,
            desiredOutcome: voice.recommendedOutcome,
            speakingStyleGoal: voice,
            styleReference: "",
            coachingBrief: "I want senior coaching that makes my work communication sharper.",
            motivationWhyNow: "There are higher-stakes conversations coming up.",
            successVision: "I can land the point cleanly under pressure.",
            chosenStyleGoal: voice
        )
    }

    private static func session(
        id: String,
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        daysAgo: Int,
        mode: PracticeMode,
        score: Int,
        prompt: String
    ) -> PracticeSession {
        let date = Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: -daysAgo,
            to: Date(timeIntervalSince1970: 1_775_000_000)
        ) ?? Date(timeIntervalSince1970: 1_775_000_000)

        return PracticeSession(
            id: UUID(uuidString: id) ?? UUID(),
            transcript: transcript,
            fillerWordCount: fillerCount,
            duration: duration,
            date: date,
            mode: mode,
            score: score,
            prompt: prompt,
            pressureLevel: .standard,
            isRated: true
        )
    }
}

/// Regression guard for the latest manual/live transcript the product was
/// tuned against. These are not generic "bad wording" examples; they are the
/// concrete drafts that made Ask Noum feel less than expert-coach level.
@Suite("CoachChatLatestLiveEvalRegressionTests")
struct CoachChatLatestLiveEvalRegressionTests {

    @Test func latestManualEvalWeakDraftsTripTheProfessionalGate() throws {
        let samples: [(fixtureID: String, reply: String, issue: CoachChatReplyQualityIssue)] = [
            (
                "cold-start-interview-baseline",
                """
                No rated sessions yet, so the honest starting point is: I don't know which part of your delivery needs the most work.
                Run one timed rep — pick a likely interview question, answer it out loud for 60–90 seconds, then note where you hesitated or rushed. That gives us something real to coach from.
                What's the interview for?
                """,
                .roboticPhrase("no rated sessions yet")
            ),
            (
                "filler-pressure-prescription",
                """
                Your last rep had 6 fillers under a timed limit, so the pattern is there when the clock runs.
                To break this, test the silent pause: the moment you feel an um coming, hold one second of silence instead, then say the next word.
                Run one rep now with that silent beat to see if it stops the filler.
                """,
                .roboticPhrase("to break this")
            ),
            (
                "metric-action-without-read",
                "Your last rep had five fillers, so test a slow open on your next run to give yourself room to find the second sentence. Say your first line slower than feels natural, which can replace the early um with a silent beat.",
                .roboticPhrase("give yourself room to find")
            ),
            (
                "metric-action-without-read",
                "Your last rep carried five fillers, which is a solid baseline to test against. Run one rep now where you focus on a slow open: say your first sentence slower than feels natural, then hold a silent beat before sentence two.",
                .missingInsightBridge
            ),
            (
                "critique-trust-repair",
                "You are right to call that out, and I am cutting the robotic report voice. Your last rep had one filler, so record a new rep where you say the main point in your very first sentence and then stop.",
                .roboticPhrase("i am cutting the")
            ),
            (
                "markdown-tts-trust-repair",
                "Fair push. I'll cut the markers and the report voice — your last rep gives me enough to work from, so next time out, lead with your recommendation in the first sentence and stop there.",
                .roboticPhrase("i'll cut the markers")
            ),
            (
                "assistant-explainer-register",
                "You are right to call that out, as that generic tip-giving was cold and did not help. Your last rep had one filler but the main point did not clearly lead, so open your next attempt by saying your core client recommendation in the very first sentence because that tests whether a strong start helps you feel in control.",
                .roboticPhrase("generic tip-giving")
            ),
            (
                "what-next-single-move",
                "Your last rep was clean on fillers but the point arrived late, so state your main takeaway in your very first sentence on the next run. Leading with the conclusion tests whether that immediately gives you more control over the pace.",
                .missingInsightBridge
            ),
            (
                "overclaim-hypothesis-boundary",
                "Your last rep put the recommendation right up front, but you asserted the claim without giving a reason or an implication to back it up. That risks sounding like an opinion rather than an authoritative verdict, so run a rep where you state the point, give one clear reason, and name the impact if we do not act.",
                .overclaimsEvidence
            ),
            (
                "leadership-transfer-setup",
                "Your last rep led with the point cleanly, so test the thirty-second update for tomorrow's meeting. State your main headline and what it means in the first sentence, because a senior room wants the implication immediately.",
                .roboticPhrase("a senior room wants")
            )
        ]

        for sample in samples {
            let fixture = try Self.fixture(sample.fixtureID)
            let context = CoachChatEvaluationCorpus.renderedContext(for: fixture)
            let issue = AICoachChatService.replyQualityIssue(
                in: sample.reply,
                latestUserTurn: fixture.latestUserTurn,
                quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                systemContext: context
            )

            #expect(issue == sample.issue,
                    "\(sample.fixtureID) expected \(sample.issue), got \(String(describing: issue))")
        }
    }

    @Test func latestManualEvalPreferredShapesStayShortAndActionable() throws {
        let samples: [(fixtureID: String, reply: String)] = [
            (
                "cold-start-interview-baseline",
                "No baseline yet, so start there. Record 60 seconds on one likely interview question, then review whether the first sentence answers it before polishing anything."
            ),
            (
                "filler-pressure-prescription",
                "Your last rep had 6 fillers, so hold one silent beat before the final sentence and check whether the next rep lowers the count."
            ),
            (
                "metric-action-without-read",
                "Your last rep had 5 fillers, so hold one silent beat after the decision line and restart if a filler appears."
            ),
            (
                "assistant-explainer-register",
                "Fair push: that was advice, not coaching. Your last rep has the useful signal: warmth came before the recommendation, so next rep say the recommendation first, then soften it with one reassurance."
            ),
            (
                "what-next-single-move",
                "The pattern I'd pick is the rushed close. Review the last transcript, rewrite only the final sentence, then run one rep with that close as the target."
            ),
            (
                "overclaim-hypothesis-boundary",
                "From the transcript, the recommendation arrived late, so say the decision first, add one reason, then name the implication."
            ),
            (
                "leadership-transfer-setup",
                "Your recent timed rep was solid on fillers but light on the close. Record a 75-second leadership update and make the final sentence the ask, not a summary."
            )
        ]

        for sample in samples {
            let fixture = try Self.fixture(sample.fixtureID)
            let context = CoachChatEvaluationCorpus.renderedContext(for: fixture)
            let issue = AICoachChatService.replyQualityIssue(
                in: sample.reply,
                latestUserTurn: fixture.latestUserTurn,
                quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                systemContext: context
            )
            let rubric = AICoachChatService.professionalCoachRubric(
                reply: sample.reply,
                latestUserTurn: fixture.latestUserTurn
            )

            #expect(issue == nil,
                    "\(sample.fixtureID) preferred shape tripped quality gate: \(String(describing: issue))")
            #expect(rubric.passesSeniorCoachFloor,
                    "\(sample.fixtureID) preferred shape should pass. Misses: \(rubric.misses)")
        }
    }

    @Test func fillerRepairShapeUsesDecisionLineWhenTranscriptShowsIt() throws {
        let fixture = try Self.fixture("metric-action-without-read")
        let shape = try #require(AICoachChatService.repairReferenceShape(
            issue: .missingInsightBridge,
            latestUserTurn: fixture.latestUserTurn,
            system: CoachChatEvaluationCorpus.renderedContext(for: fixture)
        ))

        #expect(shape.contains("after the decision line"))
        #expect(shape.contains("restart if a filler appears"))
        #expect(!shape.contains("before sentence two"))
    }

    @Test func trustRepairShapePrefersWarmthSignalOverFillerCount() throws {
        let fixture = try Self.fixture("assistant-explainer-register")
        let shape = try #require(AICoachChatService.repairReferenceShape(
            issue: .missedTrustRepair,
            latestUserTurn: fixture.latestUserTurn,
            system: CoachChatEvaluationCorpus.renderedContext(for: fixture)
        ))

        #expect(shape.contains("warmth came before the recommendation"))
        #expect(shape.contains("say the recommendation first"))
        #expect(!shape.contains("1 filler"))
    }

    private static func fixture(_ id: String) throws -> CoachChatEvaluationFixture {
        try #require(CoachChatEvaluationCorpus.fixtures.first { $0.id == id })
    }
}
