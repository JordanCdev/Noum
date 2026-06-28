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
                "assistant-explainer-register",
                "Fair push: that was advice, not coaching. Your last rep has the useful signal: warmth came before the recommendation, so next rep say the recommendation first, then soften it with one reassurance."
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
