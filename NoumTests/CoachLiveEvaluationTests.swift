//
//  CoachLiveEvaluationTests.swift
//  NoumTests
//
//  Skipped-by-default live Ask Noum eval harness.
//
//  Run manually with:
//    xcodebuild test -scheme Noum \
//      -destination 'platform=iOS Simulator,id=<id>' \
//      -only-testing:NoumTests/CoachLiveEvaluationTests \
//      OTHER_SWIFT_FLAGS='$(inherited) -D NOUM_LIVE_AI_EVAL -D NOUM_LIVE_AI_EVAL_SINGLE'
//
//  Provider selectors:
//    NOUM_LIVE_AI_PROVIDER_CHAIN=agent-platform|gemini|claude|production
//    -D NOUM_LIVE_AI_EVAL_AGENT_PLATFORM_ONLY
//    -D NOUM_LIVE_AI_EVAL_GEMINI_ONLY
//    -D NOUM_LIVE_AI_EVAL_CLAUDE_ONLY
//    -D NOUM_LIVE_AI_EVAL_PRODUCTION_CHAIN
//
//  Fixture selectors:
//    NOUM_LIVE_AI_FIXTURES=latest-transcript
//    NOUM_LIVE_AI_FIXTURES=readiness
//    NOUM_LIVE_AI_FIXTURES=fixture-id,another-fixture-id
//    NOUM_LIVE_AI_LONG_FORM=required
//    NOUM_LIVE_AI_LONG_FORM=conversation-id,another-conversation-id
//    -D NOUM_LIVE_AI_EVAL_SINGLE
//    -D NOUM_LIVE_AI_EVAL_COLD_START
//    -D NOUM_LIVE_AI_EVAL_TRUST_REPAIR
//    -D NOUM_LIVE_AI_EVAL_OVERCLAIM
//    -D NOUM_LIVE_AI_EVAL_LATEST_TRANSCRIPT
//    -D NOUM_LIVE_AI_EVAL_FULL_CORPUS
//    -D NOUM_LIVE_AI_EVAL_READINESS
//
//  This is not CI evidence and not a claim of human-coach parity. It is a
//  repeatable transcript capture for the exact live model path, context builder,
//  quote guard, RAG cards, and professional-coach gate the product uses.
//

import Foundation
import Testing
@testable import Noum

@Suite("CoachLiveEvaluationTests")
struct CoachLiveEvaluationTests {
    private static let liveReportSchemaVersion = "coach-live-eval-v1"

    @Test func latestTranscriptPresetCoversEveryManualEvalTurn() {
        let fixtures = Self.selectedFixtures(env: [
            "NOUM_LIVE_AI_FIXTURES": "latest-transcript"
        ])

        #expect(fixtures.map(\.id) == CoachChatEvaluationCorpus.latestManualEvalFixtureIDs)
    }

    @Test func typedJudgementSelectionKeepsIntentionalColdStartNeutral() {
        let selected = Self.selectedFixtures(env: [
            "NOUM_LIVE_AI_FIXTURES": "latest-transcript"
        ])
        let coldStart = selected.first { $0.id == "cold-start-interview-baseline" }
        let explicitlyStyled = Self.explicitVoiceFixtures(selected)

        #expect(coldStart?.profile == nil)
        #expect(!explicitlyStyled.contains { $0.id == "cold-start-interview-baseline" })
        #expect(explicitlyStyled.count == selected.count - 1)
        #expect(explicitlyStyled.allSatisfy { $0.profile?.chosenStyleGoal != nil })
    }

    @Test func readinessPresetSelectsLatestTranscriptAndRequiredLongFormConversations() {
        let env = [
            "NOUM_LIVE_AI_FIXTURES": "readiness"
        ]

        #expect(Self.selectedFixtures(env: env).map(\.id) == CoachChatEvaluationCorpus.latestManualEvalFixtureIDs)
        #expect(Self.selectedLongFormConversations(env: env).map(\.id) == CoachChatConversationCorpus.longFormConversations.map(\.id))
    }

    @Test func longFormSelectorDefaultsEmptyUnlessExplicitlyRequested() {
        #expect(Self.selectedLongFormConversations(env: [:]).isEmpty)
        #expect(Self.selectedLongFormConversations(env: [
            "NOUM_LIVE_AI_LONG_FORM": "required"
        ]).map(\.id) == CoachChatConversationCorpus.longFormConversations.map(\.id))
        #expect(Self.selectedLongFormConversations(env: [
            "NOUM_LIVE_AI_LONG_FORM": CoachChatConversationCorpus.longFormConversations[0].id
        ]).map(\.id) == [CoachChatConversationCorpus.longFormConversations[0].id])
    }

    @Test func runtimeProviderSelectorCanExerciseProductionChain() {
        let allKeyed: (CoachChatProvider) -> String? = { _ in "test-key" }

        #expect(Self.liveProviderChain(
            env: ["NOUM_LIVE_AI_PROVIDER_CHAIN": "production"],
            keyLookup: allKeyed
        ) == CoachChatProvider.allCases)
        #expect(Self.liveProviderChain(
            env: ["NOUM_LIVE_AI_PROVIDER_CHAIN": "claude"],
            keyLookup: allKeyed
        ) == [.anthropic])
        #expect(Self.liveProviderChain(
            env: ["NOUM_LIVE_AI_PROVIDER_CHAIN": "gemini"],
            keyLookup: allKeyed
        ) == [.agentPlatform, .gemini])
    }

    @Test func liveProductionFloorRequiresEveryGateAndReliabilityCleanliness() {
        #expect(Self.liveProductionFloor(
            qualityIssuePresent: false,
            semanticIssuePresent: false,
            rubricPasses: true,
            visionPasses: true,
            reliabilityIssues: []
        ))

        #expect(!Self.liveProductionFloor(
            qualityIssuePresent: true,
            semanticIssuePresent: false,
            rubricPasses: true,
            visionPasses: true,
            reliabilityIssues: []
        ))
        #expect(!Self.liveProductionFloor(
            qualityIssuePresent: false,
            semanticIssuePresent: true,
            rubricPasses: true,
            visionPasses: true,
            reliabilityIssues: []
        ))
        #expect(!Self.liveProductionFloor(
            qualityIssuePresent: false,
            semanticIssuePresent: false,
            rubricPasses: false,
            visionPasses: true,
            reliabilityIssues: []
        ))
        #expect(!Self.liveProductionFloor(
            qualityIssuePresent: false,
            semanticIssuePresent: false,
            rubricPasses: true,
            visionPasses: false,
            reliabilityIssues: []
        ))
        #expect(!Self.liveProductionFloor(
            qualityIssuePresent: false,
            semanticIssuePresent: false,
            rubricPasses: true,
            visionPasses: true,
            reliabilityIssues: [.nearDuplicateReply]
        ))
    }

    @Test func liveHarnessScoresTheFinalVisibleReliabilityFallback() {
        let prior = "State the recommendation, add one concrete detail, then stop."
        let visible = Self.finalVisibleReply(
            providerReply: prior,
            history: [CoachMessage(role: .coach, text: prior)],
            latestUserTurn: "How do I know if it worked?",
            turnDepth: .quickMove,
            assessment: nil,
            evidenceCoverage: 0.5,
            proofTestRecentlyRepeated: false
        )

        #expect(visible.fallbackApplied)
        #expect(visible.sourceIssues.contains(.duplicateReply))
        #expect(visible.finalIssues.isEmpty)
        #expect(visible.text != prior)
    }

    @Test func liveHarnessAppliesPipelineContentRejectedFallback() {
        let assessment = CoachAssessment(
            turnDepth: .quickMove,
            surface: .text,
            questionRestatement: "Did the plain version work?",
            directVerdict: "Delivery format was part of the trust issue.",
            confidence: 0.30,
            evidenceUsed: [],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Keep the no-symbol rule and test the recommendation line with one proof.",
            responseMode: .immediateOnly
        )
        let turn = "The no-symbol version is easier to hear."
        let recovered = Self.livePipelineOutcome(
            .failure(.contentRejected),
            assessment: assessment,
            turnDepth: .quickMove,
            history: [],
            latestUserTurn: turn
        )

        guard case .reply(let reply) = recovered else {
            Issue.record("Expected the pipeline content-rejected fallback")
            return
        }
        #expect(reply == CoachReliabilityGate.noSymbolFollowThroughFallback(surface: .text))
        let visible = Self.finalVisibleReply(
            providerReply: reply,
            history: [],
            latestUserTurn: turn,
            turnDepth: .quickMove,
            assessment: assessment,
            evidenceCoverage: 0.5,
            proofTestRecentlyRepeated: false
        )
        #expect(visible.finalIssues.isEmpty)
        #expect(AICoachChatService.semanticQualityIssue(
            in: visible.text,
            latestUserTurn: turn,
            turnDepth: .quickMove,
            assessment: assessment
        ) == nil)
    }

    @Test func liveHarnessRecordsImmediateReadOnlyAfterStoreVisibilityTransition() async {
        let shown = await Self.verifyImmediateCoachReadVisibility(
            expected: true,
            userTurn: "Give me the deeper read.",
            immediateRead: "The close is the useful signal; test it once under pressure."
        )
        let notExpected = await Self.verifyImmediateCoachReadVisibility(
            expected: false,
            userTurn: "What next?",
            immediateRead: "Use one deliberate beat before the reason."
        )
        let empty = await Self.verifyImmediateCoachReadVisibility(
            expected: true,
            userTurn: "Give me the deeper read.",
            immediateRead: "   "
        )

        #expect(shown)
        #expect(!notExpected)
        #expect(!empty)
    }

    @Test func liveJudgementCarriesRecentProofTestsAcrossFixtureSweep() {
        CoachAssessmentCache.shared.invalidate()
        UserTrajectoryCache.shared.invalidate()
        guard let fixture = CoachChatEvaluationCorpus.fixtures.first(where: {
            $0.id == "filler-pressure-prescription"
        }) else {
            #expect(Bool(false), "missing filler-pressure-prescription fixture")
            return
        }

        let first = Self.judgement(
            for: fixture,
            history: Self.history(for: fixture),
            surface: .text,
            recentProofTests: []
        )
        guard let firstAssessment = first.assessment else {
            Issue.record("Explicitly styled fixture did not produce an assessment")
            return
        }
        let carried = Self.updatedRecentProofTests([], adding: firstAssessment.nextProofTest)
        let second = Self.judgement(
            for: fixture,
            history: Self.history(for: fixture),
            surface: .text,
            recentProofTests: carried
        )
        guard let secondAssessment = second.assessment else {
            Issue.record("Explicitly styled fixture lost its assessment")
            return
        }

        #expect(!carried.isEmpty)
        #expect(secondAssessment.nextProofTest != firstAssessment.nextProofTest)
        #expect(second.assessmentCacheHit == false)
        CoachAssessmentCache.shared.invalidate()
        UserTrajectoryCache.shared.invalidate()
    }

    @Test func readinessSweepRetainsFullProofHistoryForRunLevelDiversity() {
        CoachAssessmentCache.shared.invalidate()
        UserTrajectoryCache.shared.invalidate()
        let fixtures = Self.explicitVoiceFixtures(
            Self.selectedFixtures(env: [
                "NOUM_LIVE_AI_FIXTURES": "readiness"
            ])
        )
        var recentProofTests: [String] = []
        var proofKeys: [String] = []

        for fixture in fixtures {
            let judgement = Self.judgement(
                for: fixture,
                history: Self.history(for: fixture),
                surface: .text,
                recentProofTests: recentProofTests
            )
            guard let assessment = judgement.assessment else {
                Issue.record("Explicitly styled readiness fixture \(fixture.id) had no assessment")
                return
            }
            let proofTest = assessment.nextProofTest
            #expect(!Self.proofTestRecentlyRepeated(
                proofTest,
                in: recentProofTests
            ), "readiness fixture \(fixture.id) repeated an earlier run-level proof test")
            proofKeys.append(Self.proofTestKey(proofTest))
            recentProofTests = Self.updatedRecentProofTests(
                recentProofTests,
                adding: proofTest,
                limit: fixtures.count
            )
        }

        #expect(recentProofTests.count == fixtures.count)
        #expect(Set(proofKeys).count == fixtures.count)
        CoachAssessmentCache.shared.invalidate()
        UserTrajectoryCache.shared.invalidate()
    }

    @Test func proofTestRepeatDetectionNormalizesWhitespaceAndCase() {
        let prior = [
            "Run a 45-second answer with the recommendation first, then give exactly one proof point."
        ]

        #expect(Self.proofTestRecentlyRepeated(
            "  run a 45-second answer   with the recommendation first, then give exactly one proof point. ",
            in: prior
        ))
        #expect(!Self.proofTestRecentlyRepeated(
            "Open the next rep with the decision before any context.",
            in: prior
        ))
    }

    @Test func liveTelemetrySummaryCountsProviderEventsAndFirstVisibleProxy() {
        let gemini = CoachTurnProviderChoice(providerName: "Google Gemini", model: "gemini-test")
        let claude = CoachTurnProviderChoice(providerName: "Claude", model: "claude-test")
        let turnStartedAt = Date(timeIntervalSince1970: 100)
        let turnCompletedAt = Date(timeIntervalSince1970: 103.4)
        let records = [
            CoachLiveDiagnosticRecord(
                provider: "Google Gemini",
                model: "gemini-test",
                outcome: .success,
                reason: "Streaming first provider token received",
                statusCode: nil,
                latencyMs: 420
            )
        ]

        let summary = Self.liveTelemetrySummary(
            providerEvents: [
                .started(gemini),
                .retry(gemini),
                .refused(gemini),
                .started(claude)
            ],
            diagnostics: records,
            turnStartedAt: turnStartedAt,
            turnCompletedAt: turnCompletedAt,
            firstStreamedVisibleAt: nil,
            completedReplyVisible: true
        )

        #expect(summary.providerAttemptCount == 2)
        #expect(summary.providerRetryCount == 2)
        #expect(summary.providerRefusalCount == 1)
        #expect(summary.timeToFirstVisibleTokenMs == 420)
        #expect(summary.timeToFirstVisibleTokenSource == .providerFirstTokenDiagnostic)
    }

    @Test func liveTelemetrySummaryPrefersStreamVisibleTimeOverProviderTokenDiagnostic() {
        let gemini = CoachTurnProviderChoice(providerName: "Google Gemini", model: "gemini-test")
        let turnStartedAt = Date(timeIntervalSince1970: 100)
        let turnCompletedAt = Date(timeIntervalSince1970: 102)
        let firstVisibleAt = Date(timeIntervalSince1970: 100.25)

        let summary = Self.liveTelemetrySummary(
            providerEvents: [.started(gemini)],
            diagnostics: [
                CoachLiveDiagnosticRecord(
                    provider: "Google Gemini",
                    model: "gemini-test",
                    outcome: .success,
                    reason: "Streaming first provider token received",
                    statusCode: nil,
                    latencyMs: 90
                )
            ],
            turnStartedAt: turnStartedAt,
            turnCompletedAt: turnCompletedAt,
            firstStreamedVisibleAt: firstVisibleAt,
            completedReplyVisible: true
        )

        #expect(summary.timeToFirstVisibleTokenMs == 250)
        #expect(summary.timeToFirstVisibleTokenSource == .streamedPartialVisible)
    }

    @Test func liveTelemetrySummaryPrefersVerifiedLocalReadOverProviderTiming() {
        let gemini = CoachTurnProviderChoice(providerName: "Google Gemini", model: "gemini-test")
        let turnStartedAt = Date(timeIntervalSince1970: 100)
        let localVisibleAt = Date(timeIntervalSince1970: 100.03)
        let streamVisibleAt = Date(timeIntervalSince1970: 100.4)
        let turnCompletedAt = Date(timeIntervalSince1970: 103)

        let summary = Self.liveTelemetrySummary(
            providerEvents: [.started(gemini), .retry(gemini)],
            diagnostics: [
                CoachLiveDiagnosticRecord(
                    provider: "Google Gemini",
                    model: "gemini-test",
                    outcome: .success,
                    reason: "Streaming first provider token received",
                    statusCode: nil,
                    latencyMs: 280
                )
            ],
            turnStartedAt: turnStartedAt,
            turnCompletedAt: turnCompletedAt,
            firstStreamedVisibleAt: streamVisibleAt,
            completedReplyVisible: true,
            localImmediateVisibleAt: localVisibleAt
        )

        #expect((29...30).contains(summary.timeToFirstVisibleTokenMs ?? -1))
        #expect(summary.timeToFirstVisibleTokenSource == .localImmediateRead)
    }

    @Test func liveTrustSignalsSeparateSoftPushbackFromColdnessComplaint() {
        let priorCoach = [CoachMessage(role: .coach, text: "Try leading with the point.")]
        let soft = Self.liveTrustSignals(
            userTurn: "Okay, that's cool. However, I don't feel like that answered what I meant.",
            turnDepth: .trustRepair,
            history: priorCoach
        )
        let cold = Self.liveTrustSignals(
            userTurn: "That still feels robotic and cold.",
            turnDepth: .trustRepair,
            history: priorCoach
        )

        #expect(soft.userPushbackWithinTwoTurns)
        #expect(soft.softPushbackFlag)
        #expect(!soft.coldnessComplaintFlag)
        #expect(cold.userPushbackWithinTwoTurns)
        #expect(!cold.softPushbackFlag)
        #expect(cold.coldnessComplaintFlag)
        #expect(!soft.voiceBargeInOccurred)
    }

    @Test func liveEvaluationReportEncodesTelemetryAndGateSchema() throws {
        let row = CoachLiveEvaluationReportRow(
            fixtureID: "polite-pushback-attunement",
            userTurn: "Okay, that's cool. However, I don't feel like that answered what I meant.",
            turnDepth: CoachTurnDepth.trustRepair.rawValue,
            surface: CoachReplySurface.text.rawValue,
            providerTierRequested: CoachProviderTier.claudeReasoning.rawValue,
            providerTierChosen: CoachProviderTier.claudeReasoning.rawValue,
            providerChosen: "Claude",
            providerModel: "claude-test",
            providerAttemptCount: 1,
            providerRetryCount: 0,
            providerRefusalCount: 0,
            timeToFirstVisibleTokenMs: 240,
            timeToFirstVisibleTokenSource: TimeToFirstVisibleTokenSource.streamedPartialVisible.rawValue,
            timeToCompleteReplyMs: 980,
            trajectoryCacheHit: true,
            assessmentCacheHit: false,
            assessmentCacheAgeMs: 12,
            assessmentConfidence: 0.78,
            assessmentProofTestHash: "abc123",
            assessmentVerdict: "The actual miss is order, not warmth.",
            assessmentImmediateRead: "Lead with the point, then reassure.",
            assessmentResponseMode: CoachAssessment.ResponseMode.expandable.rawValue,
            immediateCoachReadExpected: true,
            immediateCoachReadShown: true,
            missingEvidence: [],
            proofTest: "Run a 45-second client concern answer.",
            proofTestRecentlyRepeated: false,
            userPushbackWithinTwoTurns: true,
            coldnessComplaintFlag: false,
            softPushbackFlag: true,
            voiceBargeInOccurred: false,
            brainIDs: ["repair-attunement"],
            diagnostics: [
                CoachLiveDiagnosticReportRecord(
                    provider: "Claude",
                    model: "claude-test",
                    outcome: AICallDiagnosticOutcome.success.rawValue,
                    reason: "Reply accepted",
                    statusCode: nil,
                    latencyMs: 980
                )
            ],
            reply: "Fair push: I answered too generally.",
            replyWordCount: 6,
            rubricScore: 91,
            rubricMisses: [],
            passesRubric: true,
            visionScore: 90,
            visionPassesProductionFloor: true,
            visionMisses: [],
            qualityIssue: "none",
            semanticGateIssue: "none",
            reliabilityFallbackApplied: false,
            reliabilityIssues: [],
            liveProductionFloor: true,
            failure: nil
        )
        let report = CoachLiveEvaluationReport.make(
            providerChain: ["Claude (claude-test)"],
            rows: [row],
            sourceGitCommit: "abc123",
            sourceCoachFingerprint: "sha256:test-current"
        )
        let json = try report.encodedSortedJSON()

        #expect(report.schemaVersion == Self.liveReportSchemaVersion)
        #expect(report.sourceGitCommit == "abc123")
        #expect(report.sourceCoachFingerprint == "sha256:test-current")
        #expect(report.fixtureCount == 1)
        #expect(report.longFormConversationCount == 0)
        #expect(report.longFormConversationIDsPassingProductionFloor.isEmpty)
        #expect(report.longFormConversationFailureIDs.isEmpty)
        #expect(report.passesProductionFloor)
        #expect(report.passesRunReadinessFloor)
        #expect(report.summary.rowCount == 1)
        #expect(report.summary.productionFloorFailureCount == 0)
        #expect(report.summary.readinessWarnings.isEmpty)
        #expect(report.summary.uniqueProofTestHashCount == 1)
        #expect(report.summary.averageReplyWordCount == 6)
        #expect(report.summary.maxProviderRetryCount == 0)
        #expect(report.summary.firstVisibleTokenMaxMs == 240)
        #expect(report.summary.immediateCoachReadExpectedCount == 1)
        #expect(report.summary.immediateCoachReadMissingCount == 0)
        #expect(report.summary.missingImmediateCoachReadFixtureIDs.isEmpty)
        #expect(json.contains("\"schemaVersion\":\"coach-live-eval-v1\""))
        #expect(json.contains("\"sourceGitCommit\":\"abc123\""))
        #expect(json.contains("\"sourceCoachFingerprint\":\"sha256:test-current\""))
        #expect(json.contains("\"summary\""))
        #expect(json.contains("\"passesRunReadinessFloor\":true"))
        #expect(json.contains("\"readinessWarnings\":[]"))
        #expect(json.contains("\"uniqueProofTestHashCount\":1"))
        #expect(json.contains("\"averageReplyWordCount\":6"))
        #expect(json.contains("\"providerAttemptCount\":1"))
        #expect(json.contains("\"providerRetryCount\":0"))
        #expect(json.contains("\"timeToFirstVisibleTokenSource\":\"streamedPartialVisible\""))
        #expect(json.contains("\"assessmentProofTestHash\":\"abc123\""))
        #expect(json.contains("\"assessmentResponseMode\":\"expandable\""))
        #expect(json.contains("\"immediateCoachReadExpected\":true"))
        #expect(json.contains("\"immediateCoachReadShown\":true"))
        #expect(json.contains("\"longFormConversations\":[]"))
        #expect(json.contains("\"semanticGateIssue\":\"none\""))
        #expect(json.contains("\"softPushbackFlag\":true"))
        #expect(json.contains("\"replyWordCount\":6"))
        #expect(json.contains("\"liveProductionFloor\":true"))
    }

    @Test func liveEvaluationReportSummaryFlagsDistributionalSmells() {
        let pass = Self.sampleLiveReportRow(
            fixtureID: "one",
            liveProductionFloor: true,
            assessmentConfidence: 0.72,
            assessmentProofTestHash: "hash-a",
            replyWordCount: 12,
            providerRetryCount: 0,
            providerRefusalCount: 0,
            timeToFirstVisibleTokenMs: 210,
            userPushbackWithinTwoTurns: false,
            coldnessComplaintFlag: false,
            softPushbackFlag: false
        )
        let fail = Self.sampleLiveReportRow(
            fixtureID: "two",
            liveProductionFloor: false,
            assessmentConfidence: 0.72,
            assessmentProofTestHash: "hash-a",
            replyWordCount: 28,
            providerRetryCount: 2,
            providerRefusalCount: 1,
            timeToFirstVisibleTokenMs: 840,
            userPushbackWithinTwoTurns: true,
            coldnessComplaintFlag: true,
            softPushbackFlag: false,
            turnDepth: .deepAssessment,
            assessmentResponseMode: .expandable,
            immediateCoachReadShown: false
        )
        let noReply = Self.sampleLiveReportRow(
            fixtureID: "three",
            liveProductionFloor: false,
            assessmentConfidence: 0.72,
            assessmentProofTestHash: "hash-b",
            replyWordCount: nil,
            providerRetryCount: 1,
            providerRefusalCount: 1,
            timeToFirstVisibleTokenMs: nil,
            userPushbackWithinTwoTurns: true,
            coldnessComplaintFlag: false,
            softPushbackFlag: true
        )

        let report = CoachLiveEvaluationReport.make(
            providerChain: ["Google Gemini (gemini-test)"],
            rows: [pass, fail, noReply]
        )

        #expect(!report.passesProductionFloor)
        #expect(!report.passesRunReadinessFloor)
        #expect(report.summary.rowCount == 3)
        #expect(report.summary.productionFloorFailureCount == 2)
        #expect(report.summary.failureFixtureIDs == ["two", "three"])
        #expect(report.summary.readinessWarnings == [
            CoachLiveReadinessWarning.productionFloorFailures.rawValue,
            CoachLiveReadinessWarning.repeatedProofTestHash.rawValue,
            CoachLiveReadinessWarning.flatAssessmentConfidence.rawValue,
            CoachLiveReadinessWarning.missingImmediateCoachRead.rawValue,
            CoachLiveReadinessWarning.providerRetryPressure.rawValue,
            CoachLiveReadinessWarning.providerRefusalPressure.rawValue
        ])
        #expect(report.summary.uniqueProofTestHashCount == 2)
        #expect(report.summary.repeatedProofTestHashCount == 1)
        #expect(report.summary.assessmentConfidenceMin == 0.72)
        #expect(report.summary.assessmentConfidenceMax == 0.72)
        #expect(report.summary.assessmentConfidenceDistinctRoundedCount == 1)
        #expect(report.summary.averageReplyWordCount == 20)
        #expect(report.summary.replyWordCountMin == 12)
        #expect(report.summary.replyWordCountMax == 28)
        #expect(report.summary.maxProviderRetryCount == 2)
        #expect(report.summary.totalProviderRefusalCount == 2)
        #expect(report.summary.firstVisibleTokenMinMs == 210)
        #expect(report.summary.firstVisibleTokenMaxMs == 840)
        #expect(report.summary.immediateCoachReadExpectedCount == 3)
        #expect(report.summary.immediateCoachReadMissingCount == 1)
        #expect(report.summary.missingImmediateCoachReadFixtureIDs == ["two"])
        #expect(report.summary.userPushbackWithinTwoTurnsCount == 2)
        #expect(report.summary.coldnessComplaintCount == 1)
        #expect(report.summary.softPushbackCount == 1)
    }

    @Test func liveEvaluationSummaryExcludesNeutralColdStartFromJudgementDistributions() {
        let styledRows = [
            ("styled-a", 0.64, "proof-a"),
            ("styled-b", 0.72, "proof-b"),
            ("styled-c", 0.80, "proof-c")
        ].map { row in
            let (fixtureID, confidence, proofHash) = row
            return Self.sampleLiveReportRow(
                fixtureID: fixtureID,
                liveProductionFloor: true,
                assessmentConfidence: confidence,
                assessmentProofTestHash: proofHash,
                replyWordCount: Int(confidence * 100),
                providerRetryCount: 0,
                providerRefusalCount: 0,
                timeToFirstVisibleTokenMs: 220,
                userPushbackWithinTwoTurns: false,
                coldnessComplaintFlag: false,
                softPushbackFlag: false
            )
        }
        let neutral = Self.sampleLiveReportRow(
            fixtureID: "cold-start-interview-baseline",
            liveProductionFloor: true,
            assessmentConfidence: 0,
            assessmentProofTestHash: "unused",
            replyWordCount: 16,
            providerRetryCount: 0,
            providerRefusalCount: 0,
            timeToFirstVisibleTokenMs: 260,
            userPushbackWithinTwoTurns: false,
            coldnessComplaintFlag: false,
            softPushbackFlag: false,
            includeTypedAssessment: false
        )

        let report = CoachLiveEvaluationReport.make(
            providerChain: ["Google Gemini (gemini-test)"],
            rows: styledRows + [neutral]
        )

        #expect(report.passesRunReadinessFloor)
        #expect(report.summary.assessmentConfidenceDistinctRoundedCount == 3)
        #expect(report.summary.uniqueProofTestHashCount == 3)
        #expect(report.summary.immediateCoachReadExpectedCount == 3)
        #expect(neutral.assessmentConfidence == nil)
        #expect(neutral.assessmentProofTestHash == nil)
        #expect(!neutral.immediateCoachReadExpected)
        #expect(!neutral.immediateCoachReadShown)
    }

    @Test func liveEvaluationReportCarriesLongFormConversationCoverage() {
        let latestRow = Self.sampleLiveReportRow(
            fixtureID: "latest",
            liveProductionFloor: true,
            assessmentConfidence: 0.80,
            assessmentProofTestHash: "latest-proof",
            replyWordCount: 14,
            providerRetryCount: 0,
            providerRefusalCount: 0,
            timeToFirstVisibleTokenMs: 180,
            userPushbackWithinTwoTurns: false,
            coldnessComplaintFlag: false,
            softPushbackFlag: false
        )
        let passingConversation = CoachLiveLongFormConversationReportRow.make(
            conversationID: "long-form-one",
            sourceFixtureID: "one",
            expectedTurnCount: 2,
            rows: [
                Self.sampleLiveReportRow(
                    fixtureID: "long-form-one#turn-1",
                    liveProductionFloor: true,
                    assessmentConfidence: 0.72,
                    assessmentProofTestHash: "lf-1",
                    replyWordCount: 18,
                    providerRetryCount: 0,
                    providerRefusalCount: 0,
                    timeToFirstVisibleTokenMs: 260,
                    userPushbackWithinTwoTurns: false,
                    coldnessComplaintFlag: false,
                    softPushbackFlag: false
                ),
                Self.sampleLiveReportRow(
                    fixtureID: "long-form-one#turn-2",
                    liveProductionFloor: true,
                    assessmentConfidence: 0.76,
                    assessmentProofTestHash: "lf-2",
                    replyWordCount: 20,
                    providerRetryCount: 0,
                    providerRefusalCount: 0,
                    timeToFirstVisibleTokenMs: 280,
                    userPushbackWithinTwoTurns: false,
                    coldnessComplaintFlag: false,
                    softPushbackFlag: false
                )
            ]
        )
        let failingConversation = CoachLiveLongFormConversationReportRow.make(
            conversationID: "long-form-two",
            sourceFixtureID: "two",
            expectedTurnCount: 2,
            rows: [
                Self.sampleLiveReportRow(
                    fixtureID: "long-form-two#turn-1",
                    liveProductionFloor: true,
                    assessmentConfidence: 0.70,
                    assessmentProofTestHash: "lf-3",
                    replyWordCount: 16,
                    providerRetryCount: 0,
                    providerRefusalCount: 0,
                    timeToFirstVisibleTokenMs: 240,
                    userPushbackWithinTwoTurns: false,
                    coldnessComplaintFlag: false,
                    softPushbackFlag: false
                ),
                Self.sampleLiveReportRow(
                    fixtureID: "long-form-two#turn-2",
                    liveProductionFloor: false,
                    assessmentConfidence: 0.70,
                    assessmentProofTestHash: "lf-4",
                    replyWordCount: 16,
                    providerRetryCount: 1,
                    providerRefusalCount: 0,
                    timeToFirstVisibleTokenMs: 320,
                    userPushbackWithinTwoTurns: false,
                    coldnessComplaintFlag: false,
                    softPushbackFlag: false
                )
            ]
        )

        let report = CoachLiveEvaluationReport.make(
            providerChain: ["Google Gemini (gemini-test)"],
            rows: [latestRow],
            longFormConversations: [passingConversation, failingConversation]
        )

        #expect(!report.passesProductionFloor)
        #expect(!report.passesRunReadinessFloor)
        #expect(report.longFormConversationCount == 2)
        #expect(report.longFormConversationIDsPassingProductionFloor == ["long-form-one"])
        #expect(report.longFormConversationFailureIDs == ["long-form-two"])
        #expect(report.longFormConversations.map(\.observedTurnCount) == [2, 2])
    }

    @Test func longFormOperationalPressureBlocksRunReadiness() {
        let latestRow = Self.sampleLiveReportRow(
            fixtureID: "latest",
            liveProductionFloor: true,
            assessmentConfidence: 0.80,
            assessmentProofTestHash: "latest-proof",
            replyWordCount: 24,
            providerRetryCount: 0,
            providerRefusalCount: 0,
            timeToFirstVisibleTokenMs: 12,
            userPushbackWithinTwoTurns: false,
            coldnessComplaintFlag: false,
            softPushbackFlag: false
        )
        let slowConversation = CoachLiveLongFormConversationReportRow.make(
            conversationID: "long-form-slow",
            sourceFixtureID: "slow",
            expectedTurnCount: 1,
            rows: [
                Self.sampleLiveReportRow(
                    fixtureID: "long-form-slow#turn-1",
                    liveProductionFloor: true,
                    assessmentConfidence: 0.74,
                    assessmentProofTestHash: "long-proof",
                    replyWordCount: 31,
                    providerRetryCount: 2,
                    providerRefusalCount: 0,
                    timeToFirstVisibleTokenMs: 7_800,
                    userPushbackWithinTwoTurns: false,
                    coldnessComplaintFlag: false,
                    softPushbackFlag: false
                )
            ]
        )

        let report = CoachLiveEvaluationReport.make(
            providerChain: ["Google Gemini (gemini-test)"],
            rows: [latestRow],
            longFormConversations: [slowConversation]
        )

        #expect(report.passesProductionFloor)
        #expect(!report.passesRunReadinessFloor)
        #expect(report.summary.maxProviderRetryCount == 2)
        #expect(report.summary.firstVisibleTokenMaxMs == 7_800)
        #expect(report.summary.readinessWarnings == [
            CoachLiveReadinessWarning.providerRetryPressure.rawValue,
            CoachLiveReadinessWarning.slowFirstVisibleToken.rawValue
        ])
    }

    @Test func liveEvaluationReportWithoutRowsIsNotRunReady() {
        let report = CoachLiveEvaluationReport.make(
            providerChain: [],
            rows: []
        )

        #expect(!report.passesProductionFloor)
        #expect(!report.passesRunReadinessFloor)
        #expect(report.summary.rowCount == 0)
        #expect(report.summary.readinessWarnings == [
            CoachLiveReadinessWarning.noRows.rawValue
        ])
    }

    @Test func liveJSONReportPathSitsBesideMarkdownReport() {
        #expect(Self.jsonReportPath(for: "/tmp/noum-live-coach-eval.md") == "/tmp/noum-live-coach-eval.json")
        #expect(Self.jsonReportPath(for: "/tmp/noum-live-coach-eval") == "/tmp/noum-live-coach-eval.json")
    }

    @Test func latestTranscriptJudgementSignalsAreNotFlatBeforeProviderRun() {
        CoachAssessmentCache.shared.invalidate()
        UserTrajectoryCache.shared.invalidate()
        let selectedFixtures = Self.selectedFixtures(env: [
            "NOUM_LIVE_AI_FIXTURES": "latest-transcript"
        ])
        let fixtures = Self.explicitVoiceFixtures(selectedFixtures)
        var recentProofTests: [String] = []
        var assessments: [CoachAssessment] = []

        for fixture in fixtures {
            let judgement = Self.judgement(
                for: fixture,
                history: Self.history(for: fixture),
                surface: .text,
                recentProofTests: recentProofTests
            )
            guard let assessment = judgement.assessment else {
                Issue.record("Explicitly styled transcript fixture \(fixture.id) had no assessment")
                return
            }
            assessments.append(assessment)
            recentProofTests = Self.updatedRecentProofTests(
                recentProofTests,
                adding: assessment.nextProofTest
            )
        }

        let roundedConfidences = Set(assessments.map { String(format: "%.2f", $0.confidence) })
        let proofKeys = Set(assessments.map { Self.proofTestKey($0.nextProofTest) })
        let verdicts = Set(assessments.map { $0.directVerdict })

        #expect(assessments.count == selectedFixtures.filter {
            $0.profile?.chosenStyleGoal != nil
        }.count)
        #expect(roundedConfidences.count >= 2, "latest transcript sweep should not pin every assessmentConfidence to one value")
        #expect(assessments.contains { $0.confidence > CoachReliabilityGate.floorConfidence })
        #expect(proofKeys.count >= 3, "latest transcript sweep should not reuse one canned proofTest")
        #expect(verdicts.count >= 3, "latest transcript sweep should not reuse one canned assessment verdict")
        CoachAssessmentCache.shared.invalidate()
        UserTrajectoryCache.shared.invalidate()
    }

    @Test func liveGeminiRepliesClearFixtureRubric() async {
        guard Self.liveEvalEnabled else {
            return
        }

        let fixtures = Self.selectedFixtures()
        let longFormConversations = Self.selectedLongFormConversations()
        #expect(!fixtures.isEmpty)

        let diagnostics = CoachLiveDiagnosticRecorder()
        let service = Self.liveService(diagnostics: diagnostics)
        var diagnosticCursor = 0

        var report: [String] = []
        var failed = false
        func emit(_ line: String = "") {
            report.append(line)
            print(line)
        }
        let outputPath = ProcessInfo.processInfo.environment["NOUM_LIVE_AI_EVAL_OUTPUT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedOutputPath = (outputPath?.isEmpty == false)
            ? outputPath!
            : Self.defaultReportPath()
        let resolvedJSONOutputPath = Self.jsonReportPath(for: resolvedOutputPath)
        let resolvedJSONDirectory = URL(fileURLWithPath: resolvedJSONOutputPath)
            .deletingLastPathComponent()
            .path
        let sourceGitCommit = Self.sourceGitCommitForLiveProviderSweep(
            dumpDirectory: resolvedJSONDirectory
        )
        let sourceCoachFingerprint = Self.sourceCoachFingerprintForLiveProviderSweep(
            dumpDirectory: resolvedJSONDirectory
        )
        let providerChain = Self.liveProviderChain()
        let providerChainLabels = providerChain.map { "\($0.displayName) (\($0.model))" }

        emit("# Noum Chat With Noum Live Transcripts")
        emit("")
        emit("Purpose: live transcript capture through the Ask Noum chat service, context builder, retrieved coaching expertise, quote guard, professional-coach gate, and explicit-style-only typed judgement pass.")
        emit("Secrets: API keys and request bodies are not written to this report.")
        emit("reportPath: \(resolvedOutputPath)")
        emit("jsonReportPath: \(resolvedJSONOutputPath)")
        emit("sourceGitCommit: \(sourceGitCommit ?? "missing")")
        emit("sourceCoachFingerprint: \(sourceCoachFingerprint ?? "missing")")
        emit("fixtures: \(fixtures.map { $0.id }.joined(separator: ","))")
        emit("longFormConversations: \(longFormConversations.map { $0.id }.joined(separator: ","))")
        emit("providerChain: \(providerChainLabels.joined(separator: " -> "))")
        CoachAssessmentCache.shared.invalidate()
        var recentLiveProofTests: [String] = []
        var liveRows: [CoachLiveEvaluationReportRow] = []
        var longFormRows: [CoachLiveLongFormConversationReportRow] = []

        for fixture in fixtures {
            let expertise = await KnowledgeRetriever.retrieveReranked(
                query: fixture.latestUserTurn,
                lever: fixture.trends.first?.skillArea,
                voice: fixture.profile?.chosenStyleGoal,
                hasDiagnosis: !fixture.sessions.isEmpty
            )
            var context = Self.liveContext(for: fixture, coachingExpertise: expertise)
            let system = CoachContextBuilder.systemPrompt(for: fixture.profile)
            let history = Self.history(for: fixture)
            let judgement = Self.judgement(
                for: fixture,
                history: history,
                surface: .text,
                recentProofTests: recentLiveProofTests
            )
            let assessment = judgement.assessment
            let proofTestRecentlyRepeated = assessment.map {
                Self.proofTestRecentlyRepeated(
                    $0.nextProofTest,
                    in: recentLiveProofTests
                )
            } ?? false
            if let assessment {
                recentLiveProofTests = Self.updatedRecentProofTests(
                    recentLiveProofTests,
                    adding: assessment.nextProofTest,
                    // These fixtures represent independent users, but the run-level
                    // readiness audit intentionally requires every assessment shape
                    // to differ. Retain the whole preset while generating the sweep
                    // so the deterministic reasoning pass can exercise its full
                    // candidate set instead of forgetting fixture one at fixture
                    // eight and then failing the artifact's global diversity rule.
                    limit: fixtures.count
                )
            }
            if let assessment, let rubric = judgement.rubric {
                context += "\n" + CoachPromptBundle.contextBlock(
                    assessment: assessment,
                    rubric: rubric,
                    surface: .text
                )
            }
            let recentTimed = fixture.sessions
                .filter { $0.mode == .timed }
                .max(by: { $0.date < $1.date })
            let grounding = ChatGroundingContext(
                recentTimedTranscript: recentTimed?.transcript,
                verifiedProofQuotes: []
            )
            let requestedTier = CoachPromptBundle.preferredProviderTier(
                for: judgement.turnDepth,
                surface: .text
            )
            var providerChoice: CoachTurnProviderChoice?
            var providerAttemptEvents: [CoachProviderAttemptEvent] = []
            var firstStreamedVisibleAt: Date?
            let turnStartedAt = Date()
            let immediateCoachReadExpected = assessment.map {
                Self.immediateCoachReadExpected(
                    turnDepth: judgement.turnDepth,
                    surface: .text,
                    responseMode: $0.responseMode
                )
            } ?? false
            let immediateCoachReadShown: Bool
            if let assessment {
                immediateCoachReadShown = await Self.verifyImmediateCoachReadVisibility(
                    expected: immediateCoachReadExpected,
                    userTurn: fixture.latestUserTurn,
                    immediateRead: assessment.immediateCoachRead
                )
            } else {
                immediateCoachReadShown = false
            }
            let localImmediateVisibleAt = immediateCoachReadShown ? Date() : nil

            let providerOutcome = await service.reply(
                history: history,
                systemPrompt: system,
                userContext: context,
                grounding: grounding,
                turnDepth: judgement.turnDepth,
                assessment: assessment,
                surface: .text,
                preferredTier: requestedTier,
                onStreamedPartialVisible: { _ in
                    if firstStreamedVisibleAt == nil {
                        firstStreamedVisibleAt = Date()
                    }
                },
                onProviderChosen: { choice in
                    providerChoice = choice
                },
                onProviderAttemptEvent: { event in
                    providerAttemptEvents.append(event)
                }
            )
            let outcome = Self.livePipelineOutcome(
                providerOutcome,
                assessment: assessment,
                turnDepth: judgement.turnDepth,
                history: history,
                latestUserTurn: fixture.latestUserTurn
            )
            let turnCompletedAt = Date()
            let records = diagnostics.records
            let newRecords = Array(records.dropFirst(diagnosticCursor))
            diagnosticCursor = records.count
            let timeToCompleteReplyMs = Self.latencyMs(
                from: turnStartedAt,
                to: turnCompletedAt
            )
            let completedReplyVisible: Bool = {
                if case .reply = outcome {
                    return true
                }
                return false
            }()
            let telemetry = Self.liveTelemetrySummary(
                providerEvents: providerAttemptEvents,
                diagnostics: newRecords,
                turnStartedAt: turnStartedAt,
                turnCompletedAt: turnCompletedAt,
                firstStreamedVisibleAt: firstStreamedVisibleAt,
                completedReplyVisible: completedReplyVisible,
                localImmediateVisibleAt: localImmediateVisibleAt
            )
            let trustSignals = Self.liveTrustSignals(
                userTurn: fixture.latestUserTurn,
                turnDepth: judgement.turnDepth,
                history: history
            )
            let providerTierChosen = CoachReplyPipeline.providerTierChosen(
                for: providerChoice,
                requestedTier: requestedTier
            )
            let assessmentProofTestHash = assessment.map {
                CoachReplyPipeline.proofTestHash(for: $0.nextProofTest)
            }
            let assessmentCacheAgeMs = judgement.assessmentGeneratedAt.map {
                Self.latencyMs(from: $0, to: turnCompletedAt)
            }
            let missingEvidence = assessment?.missingEvidence ?? []
            let brainIDs = expertise.map { $0.id }
            let diagnosticRows = newRecords.map(CoachLiveDiagnosticReportRecord.make)
            emit("")
            emit("## \(fixture.id)")
            emit("")
            emit("userTurn: \(fixture.latestUserTurn)")
            emit("turnDepth: \(judgement.turnDepth.rawValue)")
            emit("providerTierRequested: \(requestedTier.rawValue)")
            emit("providerTierChosen: \(providerTierChosen?.rawValue ?? "none")")
            emit("providerChosen: \(providerChoice?.providerName ?? "none")")
            emit("providerModel: \(providerChoice?.model ?? "none")")
            emit("providerAttemptCount: \(telemetry.providerAttemptCount)")
            emit("providerRetryCount: \(telemetry.providerRetryCount)")
            emit("providerRefusalCount: \(telemetry.providerRefusalCount)")
            emit("timeToFirstVisibleTokenMs: \(telemetry.timeToFirstVisibleTokenMs.map(String.init) ?? "unknown")")
            emit("timeToFirstVisibleTokenSource: \(telemetry.timeToFirstVisibleTokenSource.rawValue)")
            emit("timeToCompleteReplyMs: \(timeToCompleteReplyMs)")
            emit("trajectoryCacheHit: \(judgement.trajectory.cacheHit)")
            emit("assessmentCacheHit: \(judgement.assessmentCacheHit.map { String($0) } ?? "not-applicable")")
            emit("assessmentCacheAgeMs: \(assessmentCacheAgeMs.map { String($0) } ?? "not-applicable")")
            emit("assessmentConfidence: \(assessment.map { String(format: "%.2f", $0.confidence) } ?? "not-applicable")")
            emit("assessmentProofTestHash: \(assessmentProofTestHash ?? "not-applicable")")
            emit("assessmentVerdict: \(assessment?.directVerdict ?? "not-applicable")")
            emit("assessmentImmediateRead: \(assessment?.immediateCoachRead ?? "not-applicable")")
            emit("assessmentResponseMode: \(assessment?.responseMode.rawValue ?? "not-applicable")")
            emit("immediateCoachReadExpected: \(immediateCoachReadExpected)")
            emit("immediateCoachReadShown: \(immediateCoachReadShown)")
            if !missingEvidence.isEmpty {
                emit("missingEvidence: \(missingEvidence.joined(separator: " | "))")
            }
            emit("proofTest: \(assessment?.nextProofTest ?? "not-applicable")")
            emit("proofTestRecentlyRepeated: \(proofTestRecentlyRepeated)")
            emit("userPushbackWithinTwoTurns: \(trustSignals.userPushbackWithinTwoTurns)")
            emit("coldnessComplaintFlag: \(trustSignals.coldnessComplaintFlag)")
            emit("softPushbackFlag: \(trustSignals.softPushbackFlag)")
            emit("voiceBargeInOccurred: \(trustSignals.voiceBargeInOccurred)")
            emit("brain: \(brainIDs.joined(separator: ", "))")
            emit("diagnostics:")
            for record in newRecords {
                emit("- \(record.provider) \(record.model ?? "unknown-model") \(record.outcome.rawValue): \(record.reason) status=\(record.statusCode.map(String.init) ?? "nil") latencyMs=\(record.latencyMs.map(String.init) ?? "nil")")
            }

            switch outcome {
            case .reply(let raw):
                let visibleReply = Self.finalVisibleReply(
                    providerReply: raw,
                    history: history,
                    latestUserTurn: fixture.latestUserTurn,
                    turnDepth: judgement.turnDepth,
                    assessment: assessment,
                    evidenceCoverage: judgement.trajectory.snapshot.evidenceCoverage,
                    proofTestRecentlyRepeated: proofTestRecentlyRepeated
                )
                let reply = visibleReply.text
                let replyWordCount = Self.wordCount(reply)
                let rubric = AICoachChatService.professionalCoachRubric(
                    reply: reply,
                    latestUserTurn: fixture.latestUserTurn
                )
                let issue = AICoachChatService.replyQualityIssue(
                    in: reply,
                    latestUserTurn: fixture.latestUserTurn,
                    quoteGuard: CoachChatQuoteGuardContext(
                        transcripts: [grounding.recentTimedTranscript],
                        latestUserTurn: fixture.latestUserTurn,
                        recentUserTurns: history.filter { $0.role == .user }.map { $0.text }
                    ),
                    systemContext: context,
                    turnDepth: judgement.turnDepth,
                    surface: .text
                )
                let semanticIssue = AICoachChatService.semanticQualityIssue(
                    in: reply,
                    turnDepth: judgement.turnDepth,
                    assessment: assessment
                )
                let vision = AICoachChatService.coachVisionEvaluation(
                    reply: reply,
                    latestUserTurn: fixture.latestUserTurn,
                    quoteGuard: CoachChatQuoteGuardContext(
                        transcripts: [grounding.recentTimedTranscript],
                        latestUserTurn: fixture.latestUserTurn,
                        recentUserTurns: history.filter { $0.role == .user }.map { $0.text }
                    ),
                    systemContext: context,
                    turnDepth: judgement.turnDepth,
                    assessment: assessment,
                    surface: .text
                )

                emit("")
                emit("transcript:")
                emit("")
                emit("User: \(fixture.latestUserTurn)")
                emit("")
                emit("Noum: \(reply)")
                emit("")
                emit("rawReply:")
                emit("")
                emit(reply)
                emit("")
                emit("replyWordCount: \(replyWordCount)")
                emit("rubric: score=\(rubric.score) misses=\(rubric.misses.map { $0.rawValue }.joined(separator: ","))")
                emit("visionScore: \(vision.score) passesProductionFloor=\(vision.passesProductionFloor) missed=\(vision.missed.map { $0.rawValue }.joined(separator: ","))")
                emit("qualityIssue: \(String(describing: issue))")
                emit("semanticIssue: \(String(describing: semanticIssue))")
                emit("semanticGateIssue: \(semanticIssue?.rawValue ?? "none")")
                emit("reliabilityFallbackApplied: \(visibleReply.fallbackApplied)")
                emit("reliabilitySourceIssues: \(visibleReply.sourceIssues.isEmpty ? "none" : visibleReply.sourceIssues.map(\.rawValue).joined(separator: ","))")
                emit("reliabilityIssues: \(visibleReply.finalIssues.isEmpty ? "none" : visibleReply.finalIssues.map(\.rawValue).joined(separator: ","))")
                let reliabilityPasses = visibleReply.finalIssues.isEmpty
                let liveProductionFloor = Self.liveProductionFloor(
                    qualityIssuePresent: issue != nil,
                    semanticIssuePresent: semanticIssue != nil,
                    rubricPasses: rubric.passesSeniorCoachFloor,
                    visionPasses: vision.passesProductionFloor,
                    reliabilityIssues: visibleReply.finalIssues
                )
                emit("liveProductionFloor: \(liveProductionFloor)")
                liveRows.append(CoachLiveEvaluationReportRow(
                    fixtureID: fixture.id,
                    userTurn: fixture.latestUserTurn,
                    turnDepth: judgement.turnDepth.rawValue,
                    surface: CoachReplySurface.text.rawValue,
                    providerTierRequested: requestedTier.rawValue,
                    providerTierChosen: providerTierChosen?.rawValue,
                    providerChosen: providerChoice?.providerName,
                    providerModel: providerChoice?.model,
                    providerAttemptCount: telemetry.providerAttemptCount,
                    providerRetryCount: telemetry.providerRetryCount,
                    providerRefusalCount: telemetry.providerRefusalCount,
                    timeToFirstVisibleTokenMs: telemetry.timeToFirstVisibleTokenMs,
                    timeToFirstVisibleTokenSource: telemetry.timeToFirstVisibleTokenSource.rawValue,
                    timeToCompleteReplyMs: timeToCompleteReplyMs,
                    trajectoryCacheHit: judgement.trajectory.cacheHit,
                    assessmentCacheHit: judgement.assessmentCacheHit,
                    assessmentCacheAgeMs: assessmentCacheAgeMs,
                    assessmentConfidence: assessment?.confidence,
                    assessmentProofTestHash: assessmentProofTestHash,
                    assessmentVerdict: assessment?.directVerdict,
                    assessmentImmediateRead: assessment?.immediateCoachRead,
                    assessmentResponseMode: assessment?.responseMode.rawValue,
                    immediateCoachReadExpected: immediateCoachReadExpected,
                    immediateCoachReadShown: immediateCoachReadShown,
                    missingEvidence: missingEvidence,
                    proofTest: assessment?.nextProofTest,
                    proofTestRecentlyRepeated: proofTestRecentlyRepeated,
                    userPushbackWithinTwoTurns: trustSignals.userPushbackWithinTwoTurns,
                    coldnessComplaintFlag: trustSignals.coldnessComplaintFlag,
                    softPushbackFlag: trustSignals.softPushbackFlag,
                    voiceBargeInOccurred: trustSignals.voiceBargeInOccurred,
                    brainIDs: brainIDs,
                    diagnostics: diagnosticRows,
                    reply: reply,
                    replyWordCount: replyWordCount,
                    rubricScore: rubric.score,
                    rubricMisses: rubric.misses.map(\.rawValue),
                    passesRubric: rubric.passesSeniorCoachFloor,
                    visionScore: vision.score,
                    visionPassesProductionFloor: vision.passesProductionFloor,
                    visionMisses: vision.missed.map(\.rawValue),
                    qualityIssue: issue.map { String(describing: $0) } ?? "none",
                    semanticGateIssue: semanticIssue?.rawValue ?? "none",
                    reliabilityFallbackApplied: visibleReply.fallbackApplied,
                    reliabilityIssues: visibleReply.finalIssues.map(\.rawValue),
                    liveProductionFloor: liveProductionFloor,
                    failure: nil
                ))

                if !liveProductionFloor {
                    failed = true
                }
                #expect(issue == nil)
                #expect(semanticIssue == nil)
                #expect(rubric.passesSeniorCoachFloor)
                #expect(vision.passesProductionFloor)
                #expect(
                    reliabilityPasses,
                    "\(fixture.id) reliability issues: \(visibleReply.finalIssues.map(\.rawValue).joined(separator: ","))"
                )

            case .failure(let failure):
                emit("failure: \(failure)")
                liveRows.append(CoachLiveEvaluationReportRow(
                    fixtureID: fixture.id,
                    userTurn: fixture.latestUserTurn,
                    turnDepth: judgement.turnDepth.rawValue,
                    surface: CoachReplySurface.text.rawValue,
                    providerTierRequested: requestedTier.rawValue,
                    providerTierChosen: providerTierChosen?.rawValue,
                    providerChosen: providerChoice?.providerName,
                    providerModel: providerChoice?.model,
                    providerAttemptCount: telemetry.providerAttemptCount,
                    providerRetryCount: telemetry.providerRetryCount,
                    providerRefusalCount: telemetry.providerRefusalCount,
                    timeToFirstVisibleTokenMs: telemetry.timeToFirstVisibleTokenMs,
                    timeToFirstVisibleTokenSource: telemetry.timeToFirstVisibleTokenSource.rawValue,
                    timeToCompleteReplyMs: timeToCompleteReplyMs,
                    trajectoryCacheHit: judgement.trajectory.cacheHit,
                    assessmentCacheHit: judgement.assessmentCacheHit,
                    assessmentCacheAgeMs: assessmentCacheAgeMs,
                    assessmentConfidence: assessment?.confidence,
                    assessmentProofTestHash: assessmentProofTestHash,
                    assessmentVerdict: assessment?.directVerdict,
                    assessmentImmediateRead: assessment?.immediateCoachRead,
                    assessmentResponseMode: assessment?.responseMode.rawValue,
                    immediateCoachReadExpected: immediateCoachReadExpected,
                    immediateCoachReadShown: immediateCoachReadShown,
                    missingEvidence: missingEvidence,
                    proofTest: assessment?.nextProofTest,
                    proofTestRecentlyRepeated: proofTestRecentlyRepeated,
                    userPushbackWithinTwoTurns: trustSignals.userPushbackWithinTwoTurns,
                    coldnessComplaintFlag: trustSignals.coldnessComplaintFlag,
                    softPushbackFlag: trustSignals.softPushbackFlag,
                    voiceBargeInOccurred: trustSignals.voiceBargeInOccurred,
                    brainIDs: brainIDs,
                    diagnostics: diagnosticRows,
                    reply: nil,
                    replyWordCount: nil,
                    rubricScore: nil,
                    rubricMisses: [],
                    passesRubric: nil,
                    visionScore: nil,
                    visionPassesProductionFloor: nil,
                    visionMisses: [],
                    qualityIssue: "none",
                    semanticGateIssue: "none",
                    reliabilityFallbackApplied: nil,
                    reliabilityIssues: [],
                    liveProductionFloor: false,
                    failure: String(describing: failure)
                ))
                failed = true
                #expect(Bool(false), "\(fixture.id) failed with \(failure)")
            }
            await Self.paceLiveReadinessSweep()
        }

        for conversation in longFormConversations {
            let result = await Self.evaluateLiveLongFormConversation(
                conversation,
                service: service,
                diagnostics: diagnostics,
                diagnosticCursor: &diagnosticCursor,
                emit: emit
            )
            longFormRows.append(result)
            if !result.liveProductionFloor {
                failed = true
                #expect(
                    result.liveProductionFloor,
                    "\(conversation.id) failed the live long-form production floor"
                )
            }
        }

        let reportText = report.reduce(into: "") { output, line in
            if !output.isEmpty {
                output.append("\n")
            }
            output.append(line)
        }

        do {
            try reportText
                .write(toFile: resolvedOutputPath, atomically: true, encoding: .utf8)
            print("NOUM_LIVE_AI_EVAL_OUTPUT=\(resolvedOutputPath)")
        } catch {
            print("failed to write live eval report: \(error)")
            #expect(Bool(false))
        }
        let jsonReport = CoachLiveEvaluationReport.make(
            providerChain: providerChainLabels,
            rows: liveRows,
            longFormConversations: longFormRows,
            sourceGitCommit: sourceGitCommit,
            sourceCoachFingerprint: sourceCoachFingerprint
        )
        do {
            try jsonReport
                .encodedSortedJSON()
                .write(toFile: resolvedJSONOutputPath, atomically: true, encoding: .utf8)
            print("NOUM_LIVE_AI_EVAL_JSON_OUTPUT=\(resolvedJSONOutputPath)")
        } catch {
            print("failed to write live eval JSON report: \(error)")
            #expect(Bool(false))
        }
        if failed {
            #expect(!failed, "Live coach eval failed; report written to \(resolvedOutputPath)\n\(reportText)")
        }
    }

    private static var liveEvalEnabled: Bool {
        #if NOUM_LIVE_AI_EVAL
        return true
        #else
        return ProcessInfo.processInfo.environment["NOUM_LIVE_AI_EVAL"] == "1"
        #endif
    }

    /// The readiness corpus is an operator tool, not a production traffic
    /// generator. Space turns so 75 sequential checks do not create an
    /// artificial provider burst and fail the zero-refusal contract on quota
    /// pressure that a single real conversation would never produce.
    private static func paceLiveReadinessSweep() async {
        #if NOUM_LIVE_AI_EVAL_READINESS
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        #endif
    }

    private struct CoachLiveEvaluationReport: Codable, Equatable {
        let schemaVersion: String
        let sourceGitCommit: String?
        let sourceCoachFingerprint: String?
        let fixtureCount: Int
        let longFormConversationCount: Int
        let longFormConversationIDsPassingProductionFloor: [String]
        let longFormConversationFailureIDs: [String]
        let longFormConversations: [CoachLiveLongFormConversationReportRow]
        let providerChain: [String]
        let passesProductionFloor: Bool
        let passesRunReadinessFloor: Bool
        let summary: CoachLiveEvaluationSummary
        let rows: [CoachLiveEvaluationReportRow]

        static func make(
            providerChain: [String],
            rows: [CoachLiveEvaluationReportRow],
            longFormConversations: [CoachLiveLongFormConversationReportRow] = [],
            sourceGitCommit: String? = nil,
            sourceCoachFingerprint: String? = nil
        ) -> CoachLiveEvaluationReport {
            let operationalRows = rows + longFormConversations.flatMap(\.rows)
            let summary = CoachLiveEvaluationSummary.make(
                from: rows,
                operationalRows: operationalRows
            )
            let passingLongFormIDs = longFormConversations
                .filter(\.liveProductionFloor)
                .map(\.conversationID)
            let failingLongFormIDs = longFormConversations
                .filter { !$0.liveProductionFloor }
                .map(\.conversationID)
            let passesProductionFloor = !rows.isEmpty &&
                rows.allSatisfy(\.liveProductionFloor) &&
                failingLongFormIDs.isEmpty
            return CoachLiveEvaluationReport(
                schemaVersion: CoachLiveEvaluationTests.liveReportSchemaVersion,
                sourceGitCommit: sourceGitCommit,
                sourceCoachFingerprint: sourceCoachFingerprint,
                fixtureCount: rows.count,
                longFormConversationCount: longFormConversations.count,
                longFormConversationIDsPassingProductionFloor: passingLongFormIDs,
                longFormConversationFailureIDs: failingLongFormIDs,
                longFormConversations: longFormConversations,
                providerChain: providerChain,
                passesProductionFloor: passesProductionFloor,
                passesRunReadinessFloor: passesProductionFloor && summary.readinessWarnings.isEmpty,
                summary: summary,
                rows: rows
            )
        }

        func encodedSortedJSON() throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? ""
        }
    }

    private struct CoachLiveLongFormConversationReportRow: Codable, Equatable {
        let conversationID: String
        let sourceFixtureID: String
        let expectedTurnCount: Int
        let observedTurnCount: Int
        let liveProductionFloor: Bool
        let failure: String?
        let rows: [CoachLiveEvaluationReportRow]

        static func make(
            conversationID: String,
            sourceFixtureID: String,
            expectedTurnCount: Int,
            rows: [CoachLiveEvaluationReportRow],
            failure: String? = nil
        ) -> CoachLiveLongFormConversationReportRow {
            let observedTurnCount = rows.count
            let rowFailure = rows.first { !$0.liveProductionFloor }?.failure
            let liveProductionFloor = failure == nil &&
                observedTurnCount == expectedTurnCount &&
                rows.allSatisfy(\.liveProductionFloor)
            return CoachLiveLongFormConversationReportRow(
                conversationID: conversationID,
                sourceFixtureID: sourceFixtureID,
                expectedTurnCount: expectedTurnCount,
                observedTurnCount: observedTurnCount,
                liveProductionFloor: liveProductionFloor,
                failure: failure ?? rowFailure,
                rows: rows
            )
        }
    }

    private enum CoachLiveReadinessWarning: String, Codable, Equatable, CaseIterable {
        case noRows
        case productionFloorFailures
        case repeatedProofTestHash
        case flatAssessmentConfidence
        case uniformReplyWordCount
        case missingImmediateCoachRead
        case providerRetryPressure
        case providerRefusalPressure
        case slowFirstVisibleToken
    }

    private struct CoachLiveEvaluationSummary: Codable, Equatable {
        let rowCount: Int
        let productionFloorFailureCount: Int
        let failureFixtureIDs: [String]
        let readinessWarnings: [String]
        let uniqueProofTestHashCount: Int
        let repeatedProofTestHashCount: Int
        let assessmentConfidenceMin: Double?
        let assessmentConfidenceMax: Double?
        let assessmentConfidenceDistinctRoundedCount: Int
        let averageReplyWordCount: Int?
        let replyWordCountMin: Int?
        let replyWordCountMax: Int?
        let immediateCoachReadExpectedCount: Int
        let immediateCoachReadMissingCount: Int
        let missingImmediateCoachReadFixtureIDs: [String]
        let maxProviderRetryCount: Int
        let totalProviderRefusalCount: Int
        let firstVisibleTokenMinMs: Int?
        let firstVisibleTokenMaxMs: Int?
        let userPushbackWithinTwoTurnsCount: Int
        let coldnessComplaintCount: Int
        let softPushbackCount: Int
        let voiceBargeInCount: Int

        static func make(
            from rows: [CoachLiveEvaluationReportRow],
            operationalRows: [CoachLiveEvaluationReportRow]? = nil
        ) -> CoachLiveEvaluationSummary {
            // Distributional coaching checks intentionally use the independent
            // latest-fixture sweep: proof hashes can legitimately recur across
            // the turns of one continuing conversation. Operational checks must
            // cover every turn, though, or a slow/refused long-form turn can be
            // hidden behind a clean top-level summary.
            let operationalRows = operationalRows ?? rows
            let failures = rows.filter { !$0.liveProductionFloor }
            let proofHashes = rows.compactMap { row -> String? in
                let value = row.assessmentProofTestHash?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return value.isEmpty ? nil : value
            }
            let proofHashCounts = Dictionary(grouping: proofHashes, by: { $0 })
            let repeatedProofHashCount = proofHashCounts.values.filter { $0.count > 1 }.count
            let confidences = rows.compactMap(\.assessmentConfidence)
            let roundedConfidences = Set(confidences.map { String(format: "%.2f", $0) })
            let wordCounts = rows.compactMap(\.replyWordCount)
            let firstVisible = operationalRows.compactMap(\.timeToFirstVisibleTokenMs)
            let productionFloorFailureCount = failures.count
            let maxProviderRetryCount = operationalRows.map(\.providerRetryCount).max() ?? 0
            let totalProviderRefusalCount = operationalRows.reduce(0) { $0 + $1.providerRefusalCount }
            let firstVisibleTokenMaxMs = firstVisible.max()
            let immediateCoachReadExpectedRows = operationalRows.filter(\.immediateCoachReadExpected)
            let missingImmediateCoachReadRows = immediateCoachReadExpectedRows
                .filter { !$0.immediateCoachReadShown }

            return CoachLiveEvaluationSummary(
                rowCount: rows.count,
                productionFloorFailureCount: productionFloorFailureCount,
                failureFixtureIDs: failures.map(\.fixtureID),
                readinessWarnings: readinessWarnings(
                    rowCount: rows.count,
                    productionFloorFailureCount: productionFloorFailureCount,
                    repeatedProofTestHashCount: repeatedProofHashCount,
                    assessmentCount: confidences.count,
                    assessmentConfidenceDistinctRoundedCount: roundedConfidences.count,
                    replyWordCounts: wordCounts,
                    immediateCoachReadMissingCount: missingImmediateCoachReadRows.count,
                    maxProviderRetryCount: maxProviderRetryCount,
                    totalProviderRefusalCount: totalProviderRefusalCount,
                    firstVisibleTokenMaxMs: firstVisibleTokenMaxMs
                ),
                uniqueProofTestHashCount: proofHashCounts.count,
                repeatedProofTestHashCount: repeatedProofHashCount,
                assessmentConfidenceMin: confidences.min(),
                assessmentConfidenceMax: confidences.max(),
                assessmentConfidenceDistinctRoundedCount: roundedConfidences.count,
                averageReplyWordCount: averageInt(wordCounts),
                replyWordCountMin: wordCounts.min(),
                replyWordCountMax: wordCounts.max(),
                immediateCoachReadExpectedCount: immediateCoachReadExpectedRows.count,
                immediateCoachReadMissingCount: missingImmediateCoachReadRows.count,
                missingImmediateCoachReadFixtureIDs: missingImmediateCoachReadRows.map(\.fixtureID),
                maxProviderRetryCount: maxProviderRetryCount,
                totalProviderRefusalCount: totalProviderRefusalCount,
                firstVisibleTokenMinMs: firstVisible.min(),
                firstVisibleTokenMaxMs: firstVisibleTokenMaxMs,
                userPushbackWithinTwoTurnsCount: operationalRows.filter(\.userPushbackWithinTwoTurns).count,
                coldnessComplaintCount: operationalRows.filter(\.coldnessComplaintFlag).count,
                softPushbackCount: operationalRows.filter(\.softPushbackFlag).count,
                voiceBargeInCount: operationalRows.filter(\.voiceBargeInOccurred).count
            )
        }

        private static func averageInt(_ values: [Int]) -> Int? {
            guard !values.isEmpty else { return nil }
            let total = values.reduce(0, +)
            return Int((Double(total) / Double(values.count)).rounded())
        }

        private static func readinessWarnings(
            rowCount: Int,
            productionFloorFailureCount: Int,
            repeatedProofTestHashCount: Int,
            assessmentCount: Int,
            assessmentConfidenceDistinctRoundedCount: Int,
            replyWordCounts: [Int],
            immediateCoachReadMissingCount: Int,
            maxProviderRetryCount: Int,
            totalProviderRefusalCount: Int,
            firstVisibleTokenMaxMs: Int?
        ) -> [String] {
            var warnings: [CoachLiveReadinessWarning] = []
            if rowCount == 0 {
                warnings.append(.noRows)
            }
            if productionFloorFailureCount > 0 {
                warnings.append(.productionFloorFailures)
            }
            if repeatedProofTestHashCount > 0 {
                warnings.append(.repeatedProofTestHash)
            }
            if assessmentCount >= 3 && assessmentConfidenceDistinctRoundedCount <= 1 {
                warnings.append(.flatAssessmentConfidence)
            }
            if replyWordCounts.count >= 3,
               let min = replyWordCounts.min(),
               let max = replyWordCounts.max(),
               max - min <= 5 {
                warnings.append(.uniformReplyWordCount)
            }
            if immediateCoachReadMissingCount > 0 {
                warnings.append(.missingImmediateCoachRead)
            }
            if maxProviderRetryCount >= 2 {
                warnings.append(.providerRetryPressure)
            }
            if totalProviderRefusalCount > 0 {
                warnings.append(.providerRefusalPressure)
            }
            if let firstVisibleTokenMaxMs, firstVisibleTokenMaxMs > 2_500 {
                warnings.append(.slowFirstVisibleToken)
            }
            return warnings.map(\.rawValue)
        }
    }

    private struct CoachLiveEvaluationReportRow: Codable, Equatable {
        let fixtureID: String
        let userTurn: String
        let turnDepth: String
        let surface: String
        let providerTierRequested: String
        let providerTierChosen: String?
        let providerChosen: String?
        let providerModel: String?
        let providerAttemptCount: Int
        let providerRetryCount: Int
        let providerRefusalCount: Int
        let timeToFirstVisibleTokenMs: Int?
        let timeToFirstVisibleTokenSource: String
        let timeToCompleteReplyMs: Int
        let trajectoryCacheHit: Bool
        let assessmentCacheHit: Bool?
        let assessmentCacheAgeMs: Int?
        let assessmentConfidence: Double?
        let assessmentProofTestHash: String?
        let assessmentVerdict: String?
        let assessmentImmediateRead: String?
        let assessmentResponseMode: String?
        let immediateCoachReadExpected: Bool
        let immediateCoachReadShown: Bool
        let missingEvidence: [String]
        let proofTest: String?
        let proofTestRecentlyRepeated: Bool
        let userPushbackWithinTwoTurns: Bool
        let coldnessComplaintFlag: Bool
        let softPushbackFlag: Bool
        let voiceBargeInOccurred: Bool
        let brainIDs: [String]
        let diagnostics: [CoachLiveDiagnosticReportRecord]
        let reply: String?
        let replyWordCount: Int?
        let rubricScore: Int?
        let rubricMisses: [String]
        let passesRubric: Bool?
        let visionScore: Int?
        let visionPassesProductionFloor: Bool?
        let visionMisses: [String]
        let qualityIssue: String
        let semanticGateIssue: String
        let reliabilityFallbackApplied: Bool?
        let reliabilityIssues: [String]
        let liveProductionFloor: Bool
        let failure: String?
    }

    private struct CoachLiveDiagnosticReportRecord: Codable, Equatable {
        let provider: String
        let model: String?
        let outcome: String
        let reason: String
        let statusCode: Int?
        let latencyMs: Int?

        static func make(from record: CoachLiveDiagnosticRecord) -> CoachLiveDiagnosticReportRecord {
            CoachLiveDiagnosticReportRecord(
                provider: record.provider,
                model: record.model,
                outcome: record.outcome.rawValue,
                reason: record.reason,
                statusCode: record.statusCode,
                latencyMs: record.latencyMs
            )
        }
    }

    private static func sampleLiveReportRow(
        fixtureID: String,
        liveProductionFloor: Bool,
        assessmentConfidence: Double,
        assessmentProofTestHash: String,
        replyWordCount: Int?,
        providerRetryCount: Int,
        providerRefusalCount: Int,
        timeToFirstVisibleTokenMs: Int?,
        userPushbackWithinTwoTurns: Bool,
        coldnessComplaintFlag: Bool,
        softPushbackFlag: Bool,
        turnDepth: CoachTurnDepth = .groundedRead,
        surface: CoachReplySurface = .text,
        assessmentResponseMode: CoachAssessment.ResponseMode = .immediateOnly,
        immediateCoachReadShown: Bool = true,
        includeTypedAssessment: Bool = true
    ) -> CoachLiveEvaluationReportRow {
        let immediateCoachReadExpected = includeTypedAssessment && Self.immediateCoachReadExpected(
            turnDepth: turnDepth,
            surface: surface,
            responseMode: assessmentResponseMode
        )
        return CoachLiveEvaluationReportRow(
            fixtureID: fixtureID,
            userTurn: "How should I handle this?",
            turnDepth: turnDepth.rawValue,
            surface: surface.rawValue,
            providerTierRequested: CoachProviderTier.geminiFast.rawValue,
            providerTierChosen: CoachProviderTier.geminiFast.rawValue,
            providerChosen: "Google Gemini",
            providerModel: "gemini-test",
            providerAttemptCount: max(1, providerRetryCount + 1),
            providerRetryCount: providerRetryCount,
            providerRefusalCount: providerRefusalCount,
            timeToFirstVisibleTokenMs: timeToFirstVisibleTokenMs,
            timeToFirstVisibleTokenSource: timeToFirstVisibleTokenMs == nil
                ? TimeToFirstVisibleTokenSource.unavailable.rawValue
                : TimeToFirstVisibleTokenSource.completedReplyProxy.rawValue,
            timeToCompleteReplyMs: 1_000,
            trajectoryCacheHit: true,
            assessmentCacheHit: includeTypedAssessment ? false : nil,
            assessmentCacheAgeMs: includeTypedAssessment ? 20 : nil,
            assessmentConfidence: includeTypedAssessment ? assessmentConfidence : nil,
            assessmentProofTestHash: includeTypedAssessment ? assessmentProofTestHash : nil,
            assessmentVerdict: includeTypedAssessment ? "Verdict" : nil,
            assessmentImmediateRead: includeTypedAssessment ? "Immediate read" : nil,
            assessmentResponseMode: includeTypedAssessment ? assessmentResponseMode.rawValue : nil,
            immediateCoachReadExpected: immediateCoachReadExpected,
            immediateCoachReadShown: includeTypedAssessment && immediateCoachReadShown,
            missingEvidence: [],
            proofTest: includeTypedAssessment ? "Run a short proof test." : nil,
            proofTestRecentlyRepeated: false,
            userPushbackWithinTwoTurns: userPushbackWithinTwoTurns,
            coldnessComplaintFlag: coldnessComplaintFlag,
            softPushbackFlag: softPushbackFlag,
            voiceBargeInOccurred: false,
            brainIDs: [],
            diagnostics: [],
            reply: replyWordCount.map { words in
                Array(repeating: "word", count: words).joined(separator: " ")
            },
            replyWordCount: replyWordCount,
            rubricScore: liveProductionFloor ? 90 : 60,
            rubricMisses: [],
            passesRubric: liveProductionFloor,
            visionScore: liveProductionFloor ? 90 : 60,
            visionPassesProductionFloor: liveProductionFloor,
            visionMisses: [],
            qualityIssue: "none",
            semanticGateIssue: "none",
            reliabilityFallbackApplied: false,
            reliabilityIssues: liveProductionFloor ? [] : ["fixtureFailure"],
            liveProductionFloor: liveProductionFloor,
            failure: liveProductionFloor ? nil : "fixture failure"
        )
    }

    private static func jsonReportPath(for markdownPath: String) -> String {
        let url = URL(fileURLWithPath: markdownPath)
        guard !url.pathExtension.isEmpty else {
            return markdownPath + ".json"
        }
        return url.deletingPathExtension().appendingPathExtension("json").path
    }

    private static func sourceGitCommitForLiveProviderSweep(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard,
        dumpDirectory: String? = nil
    ) -> String? {
        sourceValueForLiveProviderSweep(
            key: "NOUM_SOURCE_GIT_COMMIT",
            sidecarName: "source-git-commit.txt",
            environment: environment,
            arguments: arguments,
            defaults: defaults,
            dumpDirectory: dumpDirectory
        )
    }

    private static func sourceCoachFingerprintForLiveProviderSweep(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard,
        dumpDirectory: String? = nil
    ) -> String? {
        sourceValueForLiveProviderSweep(
            key: "NOUM_SOURCE_COACH_FINGERPRINT",
            sidecarName: "source-coach-fingerprint.txt",
            environment: environment,
            arguments: arguments,
            defaults: defaults,
            dumpDirectory: dumpDirectory
        )
    }

    private static func sourceValueForLiveProviderSweep(
        key: String,
        sidecarName: String,
        environment: [String: String],
        arguments: [String],
        defaults: UserDefaults,
        dumpDirectory: String?
    ) -> String? {
        if let value = trimmedNonEmpty(environment[key]) {
            return value
        }
        if let value = trimmedNonEmpty(environment["SIMCTL_CHILD_\(key)"]) {
            return value
        }
        if let flagIndex = arguments.firstIndex(of: "-\(key)") {
            let valueIndex = arguments.index(after: flagIndex)
            if valueIndex < arguments.endIndex,
               let value = trimmedNonEmpty(arguments[valueIndex]) {
                return value
            }
        }
        if let inline = arguments.first(where: { $0.hasPrefix("\(key)=") }) {
            return trimmedNonEmpty(String(inline.dropFirst("\(key)=".count)))
        }
        if let inline = arguments.first(where: { $0.hasPrefix("-\(key)=") }) {
            return trimmedNonEmpty(String(inline.dropFirst("-\(key)=".count)))
        }
        if let value = trimmedNonEmpty(defaults.string(forKey: key)) {
            return value
        }
        let directories = [
            dumpDirectory,
            liveEvaluationDumpDirectory(
                environment: environment,
                arguments: arguments,
                defaults: defaults
            )
        ].compactMap { trimmedNonEmpty($0) }
        var seenDirectories = Set<String>()
        for directory in directories where !seenDirectories.contains(directory) {
            seenDirectories.insert(directory)
            if let data = try? String(
                contentsOfFile: "\(directory)/\(sidecarName)",
                encoding: .utf8
            ),
               let value = trimmedNonEmpty(data) {
                return value
            }
        }
        return nil
    }

    private static func liveEvaluationDumpDirectory(
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
            "/private/tmp/noum-coach-eval"
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

    private static func immediateCoachReadExpected(
        turnDepth: CoachTurnDepth,
        surface: CoachReplySurface,
        responseMode: CoachAssessment.ResponseMode
    ) -> Bool {
        CoachReplyPipeline.shouldShowProvisionalCoachRead(
            turnDepth: turnDepth,
            surface: surface,
            responseMode: responseMode,
            realtimeCoachModeEnabled: true
        )
    }

    /// Exercise the same pending-row transition that makes the local read
    /// visible in `CoachReplyPipeline`. The provider-only harness does not call
    /// the full pipeline, so deriving this flag from eligibility or non-empty
    /// text would overstate UI evidence. A read counts as shown only when the
    /// shipping store accepts it onto a real pending coach row.
    private static func verifyImmediateCoachReadVisibility(
        expected: Bool,
        userTurn: String,
        immediateRead: String
    ) async -> Bool {
        guard expected else { return false }
        return await MainActor.run {
            let suiteName = "CoachLiveImmediateRead.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                return false
            }
            defaults.removePersistentDomain(forName: suiteName)
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let store = AskNoumStore(
                defaults: defaults,
                accountIDProvider: { "live-eval-immediate-read" }
            )
            guard let coachID = store.injectUserTurn(userTurn) else {
                return false
            }
            return store.setProvisionalCoachRead(
                id: coachID,
                text: immediateRead
            )
        }
    }

    private static func liveProductionFloor(
        qualityIssuePresent: Bool,
        semanticIssuePresent: Bool,
        rubricPasses: Bool,
        visionPasses: Bool,
        reliabilityIssues: [CoachReliabilityIssue]
    ) -> Bool {
        !qualityIssuePresent &&
        !semanticIssuePresent &&
        rubricPasses &&
        visionPasses &&
        reliabilityIssues.isEmpty
    }

    private struct FinalVisibleLiveReply {
        let text: String
        let fallbackApplied: Bool
        let sourceIssues: [CoachReliabilityIssue]
        let finalIssues: [CoachReliabilityIssue]
    }

    /// Mirror the pipeline-owned safe recovery after every configured provider
    /// returns unusable content. Coaching content rejection may use a bounded
    /// assessment read; known non-coaching empty turns may use only their
    /// intent-specific acknowledgement. Live evidence must do the same.
    private static func livePipelineOutcome(
        _ providerOutcome: ChatOutcome,
        assessment: CoachAssessment?,
        turnDepth: CoachTurnDepth,
        history: [CoachMessage],
        latestUserTurn: String
    ) -> ChatOutcome {
        let previousCoachReply = history.last { $0.role == .coach }?.text
        let recentCoachReplies = Array(history
            .reversed()
            .filter { $0.role == .coach }
            .map(\.text)
            .prefix(4))
        guard let fallback = CoachReplyPipeline.safeFailureFallbackText(
            for: providerOutcome,
            assessment: assessment,
            turnDepth: turnDepth,
            surface: .text,
            previousCoachReply: previousCoachReply,
            recentCoachReplies: recentCoachReplies,
            latestUserTurn: latestUserTurn
        ) else {
            return providerOutcome
        }
        return .reply(fallback)
    }

    /// Mirror the shipping `CoachReplyPipeline` last mile before scoring live
    /// evidence. Provider/service output is first evaluated for reliability;
    /// a blocking verdict substitutes the same deterministic fallback the user
    /// would see, then the normal finalizer runs. The production floor evaluates
    /// that final visible text while retaining whether a fallback was needed.
    private static func finalVisibleReply(
        providerReply: String,
        history: [CoachMessage],
        latestUserTurn: String,
        turnDepth: CoachTurnDepth,
        assessment: CoachAssessment?,
        evidenceCoverage: Double?,
        proofTestRecentlyRepeated: Bool
    ) -> FinalVisibleLiveReply {
        let sanitized = CoachReplyTextSanitizer.coachReplyText(from: providerReply)
        let previousCoachReply = history.last { $0.role == .coach }?.text
        let recentCoachReplies = Array(history
            .reversed()
            .filter { $0.role == .coach }
            .map(\.text)
            .prefix(4))
        let sourceVerdict = CoachReliabilityGate.evaluate(
            replyText: sanitized,
            previousCoachReply: previousCoachReply,
            recentCoachReplies: recentCoachReplies,
            latestUserTurn: latestUserTurn,
            turnDepth: turnDepth,
            assessment: assessment,
            evidenceCoverage: evidenceCoverage,
            proofTestRecentlyRepeated: proofTestRecentlyRepeated,
            surface: .text
        )
        let effective = sourceVerdict.fallbackText ?? sanitized
        let finalized = AICoachChatService.finalizedCoachReply(
            from: effective,
            latestUserTurn: latestUserTurn,
            turnDepth: turnDepth
        )
        let finalVerdict = CoachReliabilityGate.evaluate(
            replyText: finalized,
            previousCoachReply: previousCoachReply,
            recentCoachReplies: recentCoachReplies,
            latestUserTurn: latestUserTurn,
            turnDepth: turnDepth,
            assessment: assessment,
            evidenceCoverage: evidenceCoverage,
            // The run-level proof-test hash audit owns this signal. Reapplying
            // it after text substitution would fail every fallback regardless
            // of the final reply's content.
            proofTestRecentlyRepeated: false,
            surface: .text
        )
        return FinalVisibleLiveReply(
            text: finalized,
            fallbackApplied: sourceVerdict.blocked,
            sourceIssues: sourceVerdict.issues,
            finalIssues: finalVerdict.issues
        )
    }

    private enum TimeToFirstVisibleTokenSource: String, Equatable {
        case localImmediateRead
        case streamedPartialVisible
        case providerFirstTokenDiagnostic
        case completedReplyProxy
        case unavailable
    }

    private struct LiveTelemetrySummary: Equatable {
        let providerAttemptCount: Int
        let providerRetryCount: Int
        let providerRefusalCount: Int
        let timeToFirstVisibleTokenMs: Int?
        let timeToFirstVisibleTokenSource: TimeToFirstVisibleTokenSource
    }

    private struct LiveTrustSignalSummary: Equatable {
        let userPushbackWithinTwoTurns: Bool
        let coldnessComplaintFlag: Bool
        let softPushbackFlag: Bool
        let voiceBargeInOccurred: Bool
    }

    private static func liveTelemetrySummary(
        providerEvents: [CoachProviderAttemptEvent],
        diagnostics: [CoachLiveDiagnosticRecord],
        turnStartedAt: Date,
        turnCompletedAt: Date,
        firstStreamedVisibleAt: Date?,
        completedReplyVisible: Bool,
        localImmediateVisibleAt: Date? = nil
    ) -> LiveTelemetrySummary {
        let firstVisible: (Int?, TimeToFirstVisibleTokenSource)
        if let localImmediateVisibleAt {
            firstVisible = (
                latencyMs(from: turnStartedAt, to: localImmediateVisibleAt),
                .localImmediateRead
            )
        } else if let firstStreamedVisibleAt {
            firstVisible = (
                latencyMs(from: turnStartedAt, to: firstStreamedVisibleAt),
                .streamedPartialVisible
            )
        } else if let firstProviderTokenMs = diagnostics.first(where: {
            $0.outcome == .success &&
            $0.reason == "Streaming first provider token received"
        })?.latencyMs {
            firstVisible = (firstProviderTokenMs, .providerFirstTokenDiagnostic)
        } else if completedReplyVisible {
            firstVisible = (
                latencyMs(from: turnStartedAt, to: turnCompletedAt),
                .completedReplyProxy
            )
        } else {
            firstVisible = (nil, .unavailable)
        }

        return LiveTelemetrySummary(
            providerAttemptCount: CoachReplyPipeline.providerAttemptCount(providerEvents),
            providerRetryCount: CoachReplyPipeline.providerRetryCount(providerEvents),
            providerRefusalCount: CoachReplyPipeline.providerRefusalCount(providerEvents),
            timeToFirstVisibleTokenMs: firstVisible.0,
            timeToFirstVisibleTokenSource: firstVisible.1
        )
    }

    private static func liveTrustSignals(
        userTurn: String,
        turnDepth: CoachTurnDepth,
        history: [CoachMessage]
    ) -> LiveTrustSignalSummary {
        let priorCoachReplyExists = history.contains { $0.role == .coach }
        return LiveTrustSignalSummary(
            userPushbackWithinTwoTurns: turnDepth == .trustRepair && priorCoachReplyExists,
            coldnessComplaintFlag: isColdnessComplaint(userTurn),
            softPushbackFlag: isSoftPushback(userTurn),
            voiceBargeInOccurred: false
        )
    }

    private static func isSoftPushback(_ text: String) -> Bool {
        TurnDepthClassifier.isSoftPushback(normalizedTrustText(text))
    }

    private static func isColdnessComplaint(_ text: String) -> Bool {
        let lower = normalizedTrustText(text)
        return [
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
        ].contains { lower.contains($0) }
    }

    private static func normalizedTrustText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .lowercased()
    }

    private static func latencyMs(from start: Date, to end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) * 1_000))
    }

    private static func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private static func evaluateLiveLongFormConversation(
        _ conversation: CoachChatConversationFixture,
        service: AICoachChatService,
        diagnostics: CoachLiveDiagnosticRecorder,
        diagnosticCursor: inout Int,
        emit: (String) -> Void
    ) async -> CoachLiveLongFormConversationReportRow {
        guard let source = sourceFixture(for: conversation) else {
            emit("")
            emit("## \(conversation.id)")
            emit("failure: missing source fixture \(conversation.sourceFixtureID)")
            return CoachLiveLongFormConversationReportRow.make(
                conversationID: conversation.id,
                sourceFixtureID: conversation.sourceFixtureID,
                expectedTurnCount: conversation.turns.count,
                rows: [],
                failure: "missing source fixture \(conversation.sourceFixtureID)"
            )
        }

        emit("")
        emit("## \(conversation.id)")
        emit("")
        emit("sourceFixtureID: \(conversation.sourceFixtureID)")
        emit("turnCount: \(conversation.turns.count)")

        var history = Self.initialHistory(for: source)
        var recentProofTests: [String] = []
        var rows: [CoachLiveEvaluationReportRow] = []

        for (index, turn) in conversation.turns.enumerated() {
            let previousCoachReply = history.last { $0.role == .coach }?.text
            let fixture = CoachChatEvaluationFixture(
                id: "\(conversation.id)#turn-\(index + 1)",
                pillar: source.pillar,
                expertBaseline: source.expertBaseline,
                profile: source.profile,
                sessions: source.sessions,
                trends: source.trends,
                latestUserTurn: turn.userTurn,
                previousCoachReply: previousCoachReply,
                expectedContextNeedles: source.expectedContextNeedles,
                referenceReply: turn.coachReply,
                knownBadReply: source.knownBadReply,
                expectedBadIssue: source.expectedBadIssue
            )
            let requestHistory = history + [
                CoachMessage(role: .user, text: turn.userTurn)
            ]
            let row = await Self.evaluateLiveTurn(
                fixture: fixture,
                history: requestHistory,
                service: service,
                diagnostics: diagnostics,
                diagnosticCursor: &diagnosticCursor,
                recentProofTests: &recentProofTests,
                emit: emit
            )
            rows.append(row)
            history.append(CoachMessage(role: .user, text: turn.userTurn))
            guard let reply = row.reply,
                  !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                break
            }
            history.append(CoachMessage(role: .coach, text: reply))
            await Self.paceLiveReadinessSweep()
        }

        let result = CoachLiveLongFormConversationReportRow.make(
            conversationID: conversation.id,
            sourceFixtureID: conversation.sourceFixtureID,
            expectedTurnCount: conversation.turns.count,
            rows: rows
        )
        emit("liveLongFormProductionFloor: \(result.liveProductionFloor)")
        if let failure = result.failure {
            emit("longFormFailure: \(failure)")
        }
        return result
    }

    private static func evaluateLiveTurn(
        fixture: CoachChatEvaluationFixture,
        history: [CoachMessage],
        service: AICoachChatService,
        diagnostics: CoachLiveDiagnosticRecorder,
        diagnosticCursor: inout Int,
        recentProofTests: inout [String],
        emit: (String) -> Void
    ) async -> CoachLiveEvaluationReportRow {
        let expertise = await KnowledgeRetriever.retrieveReranked(
            query: fixture.latestUserTurn,
            lever: fixture.trends.first?.skillArea,
            voice: fixture.profile?.chosenStyleGoal,
            hasDiagnosis: !fixture.sessions.isEmpty
        )
        let recentUserTurns = history
            .filter { $0.role == .user }
            .map(\.text)
        var context = Self.liveContext(
            for: fixture,
            coachingExpertise: expertise,
            recentUserTurns: recentUserTurns.isEmpty ? [fixture.latestUserTurn] : recentUserTurns
        )
        let system = CoachContextBuilder.systemPrompt(for: fixture.profile)
        let judgement = Self.judgement(
            for: fixture,
            history: history,
            surface: .text,
            recentProofTests: recentProofTests
        )
        let assessment = judgement.assessment
        let proofTestRecentlyRepeated = assessment.map {
            Self.proofTestRecentlyRepeated($0.nextProofTest, in: recentProofTests)
        } ?? false
        if let assessment {
            recentProofTests = Self.updatedRecentProofTests(
                recentProofTests,
                adding: assessment.nextProofTest
            )
        }
        if let assessment, let rubric = judgement.rubric {
            context += "\n" + CoachPromptBundle.contextBlock(
                assessment: assessment,
                rubric: rubric,
                surface: .text
            )
        }
        let recentTimed = fixture.sessions
            .filter { $0.mode == .timed }
            .max(by: { $0.date < $1.date })
        let grounding = ChatGroundingContext(
            recentTimedTranscript: recentTimed?.transcript,
            verifiedProofQuotes: []
        )
        let requestedTier = CoachPromptBundle.preferredProviderTier(
            for: judgement.turnDepth,
            surface: .text
        )
        var providerChoice: CoachTurnProviderChoice?
        var providerAttemptEvents: [CoachProviderAttemptEvent] = []
        var firstStreamedVisibleAt: Date?
        let turnStartedAt = Date()
        let immediateCoachReadExpected = assessment.map {
            Self.immediateCoachReadExpected(
                turnDepth: judgement.turnDepth,
                surface: .text,
                responseMode: $0.responseMode
            )
        } ?? false
        let immediateCoachReadShown: Bool
        if let assessment {
            immediateCoachReadShown = await Self.verifyImmediateCoachReadVisibility(
                expected: immediateCoachReadExpected,
                userTurn: fixture.latestUserTurn,
                immediateRead: assessment.immediateCoachRead
            )
        } else {
            immediateCoachReadShown = false
        }
        let localImmediateVisibleAt = immediateCoachReadShown ? Date() : nil

        let providerOutcome = await service.reply(
            history: history,
            systemPrompt: system,
            userContext: context,
            grounding: grounding,
            turnDepth: judgement.turnDepth,
            assessment: assessment,
            surface: .text,
            preferredTier: requestedTier,
            onStreamedPartialVisible: { _ in
                if firstStreamedVisibleAt == nil {
                    firstStreamedVisibleAt = Date()
                }
            },
            onProviderChosen: { choice in
                providerChoice = choice
            },
            onProviderAttemptEvent: { event in
                providerAttemptEvents.append(event)
            }
        )
        let outcome = Self.livePipelineOutcome(
            providerOutcome,
            assessment: assessment,
            turnDepth: judgement.turnDepth,
            history: history,
            latestUserTurn: fixture.latestUserTurn
        )
        let turnCompletedAt = Date()
        let records = diagnostics.records
        let newRecords = Array(records.dropFirst(diagnosticCursor))
        diagnosticCursor = records.count
        let timeToCompleteReplyMs = Self.latencyMs(
            from: turnStartedAt,
            to: turnCompletedAt
        )
        let completedReplyVisible: Bool = {
            if case .reply = outcome {
                return true
            }
            return false
        }()
        let telemetry = Self.liveTelemetrySummary(
            providerEvents: providerAttemptEvents,
            diagnostics: newRecords,
            turnStartedAt: turnStartedAt,
            turnCompletedAt: turnCompletedAt,
            firstStreamedVisibleAt: firstStreamedVisibleAt,
            completedReplyVisible: completedReplyVisible,
            localImmediateVisibleAt: localImmediateVisibleAt
        )
        let trustSignals = Self.liveTrustSignals(
            userTurn: fixture.latestUserTurn,
            turnDepth: judgement.turnDepth,
            history: history
        )
        let providerTierChosen = CoachReplyPipeline.providerTierChosen(
            for: providerChoice,
            requestedTier: requestedTier
        )
        let assessmentProofTestHash = assessment.map {
            CoachReplyPipeline.proofTestHash(for: $0.nextProofTest)
        }
        let assessmentCacheAgeMs = judgement.assessmentGeneratedAt.map {
            Self.latencyMs(from: $0, to: turnCompletedAt)
        }
        let missingEvidence = assessment?.missingEvidence ?? []
        let brainIDs = expertise.map { $0.id }
        let diagnosticRows = newRecords.map(CoachLiveDiagnosticReportRecord.make)
        emit("")
        emit("### \(fixture.id)")
        emit("userTurn: \(fixture.latestUserTurn)")
        emit("turnDepth: \(judgement.turnDepth.rawValue)")
        emit("providerTierRequested: \(requestedTier.rawValue)")
        emit("providerTierChosen: \(providerTierChosen?.rawValue ?? "none")")
        emit("providerChosen: \(providerChoice?.providerName ?? "none")")
        emit("providerModel: \(providerChoice?.model ?? "none")")
        emit("timeToFirstVisibleTokenMs: \(telemetry.timeToFirstVisibleTokenMs.map(String.init) ?? "unknown")")
        emit("timeToCompleteReplyMs: \(timeToCompleteReplyMs)")
        emit("assessmentConfidence: \(assessment.map { String(format: "%.2f", $0.confidence) } ?? "not-applicable")")
        emit("assessmentProofTestHash: \(assessmentProofTestHash ?? "not-applicable")")
        emit("assessmentImmediateRead: \(assessment?.immediateCoachRead ?? "not-applicable")")
        emit("immediateCoachReadExpected: \(immediateCoachReadExpected)")
        emit("immediateCoachReadShown: \(immediateCoachReadShown)")
        emit("proofTest: \(assessment?.nextProofTest ?? "not-applicable")")
        emit("proofTestRecentlyRepeated: \(proofTestRecentlyRepeated)")

        switch outcome {
        case .reply(let raw):
            let visibleReply = Self.finalVisibleReply(
                providerReply: raw,
                history: history,
                latestUserTurn: fixture.latestUserTurn,
                turnDepth: judgement.turnDepth,
                assessment: assessment,
                evidenceCoverage: judgement.trajectory.snapshot.evidenceCoverage,
                proofTestRecentlyRepeated: proofTestRecentlyRepeated
            )
            let reply = visibleReply.text
            let replyWordCount = Self.wordCount(reply)
            let quoteGuard = CoachChatQuoteGuardContext(
                transcripts: [grounding.recentTimedTranscript],
                latestUserTurn: fixture.latestUserTurn,
                recentUserTurns: history.filter { $0.role == .user }.map(\.text)
            )
            let rubric = AICoachChatService.professionalCoachRubric(
                reply: reply,
                latestUserTurn: fixture.latestUserTurn
            )
            let issue = AICoachChatService.replyQualityIssue(
                in: reply,
                latestUserTurn: fixture.latestUserTurn,
                quoteGuard: quoteGuard,
                systemContext: context,
                turnDepth: judgement.turnDepth,
                surface: .text
            )
            let semanticIssue = AICoachChatService.semanticQualityIssue(
                in: reply,
                turnDepth: judgement.turnDepth,
                assessment: assessment
            )
            let vision = AICoachChatService.coachVisionEvaluation(
                reply: reply,
                latestUserTurn: fixture.latestUserTurn,
                quoteGuard: quoteGuard,
                systemContext: context,
                turnDepth: judgement.turnDepth,
                assessment: assessment,
                surface: .text
            )
            let liveProductionFloor = Self.liveProductionFloor(
                qualityIssuePresent: issue != nil,
                semanticIssuePresent: semanticIssue != nil,
                rubricPasses: rubric.passesSeniorCoachFloor,
                visionPasses: vision.passesProductionFloor,
                reliabilityIssues: visibleReply.finalIssues
            )

            emit("Noum: \(reply)")
            emit("replyWordCount: \(replyWordCount)")
            emit("rubric: score=\(rubric.score) misses=\(rubric.misses.map { $0.rawValue }.joined(separator: ","))")
            emit("visionScore: \(vision.score) passesProductionFloor=\(vision.passesProductionFloor) missed=\(vision.missed.map { $0.rawValue }.joined(separator: ","))")
            emit("qualityIssue: \(String(describing: issue))")
            emit("semanticGateIssue: \(semanticIssue?.rawValue ?? "none")")
            emit("reliabilityFallbackApplied: \(visibleReply.fallbackApplied)")
            emit("reliabilitySourceIssues: \(visibleReply.sourceIssues.isEmpty ? "none" : visibleReply.sourceIssues.map(\.rawValue).joined(separator: ","))")
            emit("reliabilityIssues: \(visibleReply.finalIssues.isEmpty ? "none" : visibleReply.finalIssues.map(\.rawValue).joined(separator: ","))")
            emit("liveProductionFloor: \(liveProductionFloor)")

            return CoachLiveEvaluationReportRow(
                fixtureID: fixture.id,
                userTurn: fixture.latestUserTurn,
                turnDepth: judgement.turnDepth.rawValue,
                surface: CoachReplySurface.text.rawValue,
                providerTierRequested: requestedTier.rawValue,
                providerTierChosen: providerTierChosen?.rawValue,
                providerChosen: providerChoice?.providerName,
                providerModel: providerChoice?.model,
                providerAttemptCount: telemetry.providerAttemptCount,
                providerRetryCount: telemetry.providerRetryCount,
                providerRefusalCount: telemetry.providerRefusalCount,
                timeToFirstVisibleTokenMs: telemetry.timeToFirstVisibleTokenMs,
                timeToFirstVisibleTokenSource: telemetry.timeToFirstVisibleTokenSource.rawValue,
                timeToCompleteReplyMs: timeToCompleteReplyMs,
                trajectoryCacheHit: judgement.trajectory.cacheHit,
                assessmentCacheHit: judgement.assessmentCacheHit,
                assessmentCacheAgeMs: assessmentCacheAgeMs,
                assessmentConfidence: assessment?.confidence,
                assessmentProofTestHash: assessmentProofTestHash,
                assessmentVerdict: assessment?.directVerdict,
                assessmentImmediateRead: assessment?.immediateCoachRead,
                assessmentResponseMode: assessment?.responseMode.rawValue,
                immediateCoachReadExpected: immediateCoachReadExpected,
                immediateCoachReadShown: immediateCoachReadShown,
                missingEvidence: missingEvidence,
                proofTest: assessment?.nextProofTest,
                proofTestRecentlyRepeated: proofTestRecentlyRepeated,
                userPushbackWithinTwoTurns: trustSignals.userPushbackWithinTwoTurns,
                coldnessComplaintFlag: trustSignals.coldnessComplaintFlag,
                softPushbackFlag: trustSignals.softPushbackFlag,
                voiceBargeInOccurred: trustSignals.voiceBargeInOccurred,
                brainIDs: brainIDs,
                diagnostics: diagnosticRows,
                reply: reply,
                replyWordCount: replyWordCount,
                rubricScore: rubric.score,
                rubricMisses: rubric.misses.map(\.rawValue),
                passesRubric: rubric.passesSeniorCoachFloor,
                visionScore: vision.score,
                visionPassesProductionFloor: vision.passesProductionFloor,
                visionMisses: vision.missed.map(\.rawValue),
                qualityIssue: issue.map { String(describing: $0) } ?? "none",
                semanticGateIssue: semanticIssue?.rawValue ?? "none",
                reliabilityFallbackApplied: visibleReply.fallbackApplied,
                reliabilityIssues: visibleReply.finalIssues.map(\.rawValue),
                liveProductionFloor: liveProductionFloor,
                failure: nil
            )

        case .failure(let failure):
            emit("failure: \(failure)")
            return CoachLiveEvaluationReportRow(
                fixtureID: fixture.id,
                userTurn: fixture.latestUserTurn,
                turnDepth: judgement.turnDepth.rawValue,
                surface: CoachReplySurface.text.rawValue,
                providerTierRequested: requestedTier.rawValue,
                providerTierChosen: providerTierChosen?.rawValue,
                providerChosen: providerChoice?.providerName,
                providerModel: providerChoice?.model,
                providerAttemptCount: telemetry.providerAttemptCount,
                providerRetryCount: telemetry.providerRetryCount,
                providerRefusalCount: telemetry.providerRefusalCount,
                timeToFirstVisibleTokenMs: telemetry.timeToFirstVisibleTokenMs,
                timeToFirstVisibleTokenSource: telemetry.timeToFirstVisibleTokenSource.rawValue,
                timeToCompleteReplyMs: timeToCompleteReplyMs,
                trajectoryCacheHit: judgement.trajectory.cacheHit,
                assessmentCacheHit: judgement.assessmentCacheHit,
                assessmentCacheAgeMs: assessmentCacheAgeMs,
                assessmentConfidence: assessment?.confidence,
                assessmentProofTestHash: assessmentProofTestHash,
                assessmentVerdict: assessment?.directVerdict,
                assessmentImmediateRead: assessment?.immediateCoachRead,
                assessmentResponseMode: assessment?.responseMode.rawValue,
                immediateCoachReadExpected: immediateCoachReadExpected,
                immediateCoachReadShown: immediateCoachReadShown,
                missingEvidence: missingEvidence,
                proofTest: assessment?.nextProofTest,
                proofTestRecentlyRepeated: proofTestRecentlyRepeated,
                userPushbackWithinTwoTurns: trustSignals.userPushbackWithinTwoTurns,
                coldnessComplaintFlag: trustSignals.coldnessComplaintFlag,
                softPushbackFlag: trustSignals.softPushbackFlag,
                voiceBargeInOccurred: trustSignals.voiceBargeInOccurred,
                brainIDs: brainIDs,
                diagnostics: diagnosticRows,
                reply: nil,
                replyWordCount: nil,
                rubricScore: nil,
                rubricMisses: [],
                passesRubric: nil,
                visionScore: nil,
                visionPassesProductionFloor: nil,
                visionMisses: [],
                qualityIssue: "none",
                semanticGateIssue: "none",
                reliabilityFallbackApplied: nil,
                reliabilityIssues: [],
                liveProductionFloor: false,
                failure: String(describing: failure)
            )
        }
    }

    private static func sourceFixture(
        for conversation: CoachChatConversationFixture
    ) -> CoachChatEvaluationFixture? {
        CoachChatEvaluationCorpus.fixtures.first {
            $0.id == conversation.sourceFixtureID
        }
    }

    private static func initialHistory(
        for fixture: CoachChatEvaluationFixture
    ) -> [CoachMessage] {
        guard let previous = fixture.previousCoachReply,
              !previous.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return [CoachMessage(role: .coach, text: previous)]
    }

    private static func selectedFixtures(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> [CoachChatEvaluationFixture] {
        let all = CoachChatEvaluationCorpus.fixtures
        let raw = env["NOUM_LIVE_AI_FIXTURES"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let raw, !raw.isEmpty else {
            #if NOUM_LIVE_AI_EVAL_READINESS
            return CoachChatEvaluationCorpus.latestManualEvalFixtureIDs
                .compactMap { id in all.first { $0.id == id } }
            #elseif NOUM_LIVE_AI_EVAL_FULL_CORPUS
            return all
            #else
            // Keep the default run cheap but representative: cold start,
            // pressure prescription, and trust repair.
            #if NOUM_LIVE_AI_EVAL_LATEST_TRANSCRIPT
            let defaults = CoachChatEvaluationCorpus.latestManualEvalFixtureIDs
            #elseif NOUM_LIVE_AI_EVAL_SINGLE
            let defaults = [
                "filler-pressure-prescription"
            ]
            #elseif NOUM_LIVE_AI_EVAL_TRUST_REPAIR
            let defaults = [
                "markdown-tts-trust-repair"
            ]
            #elseif NOUM_LIVE_AI_EVAL_COLD_START
            let defaults = [
                "cold-start-interview-baseline"
            ]
            #elseif NOUM_LIVE_AI_EVAL_OVERCLAIM
            let defaults = [
                "overclaim-hypothesis-boundary"
            ]
            #else
            let defaults = [
                "cold-start-interview-baseline",
                "filler-pressure-prescription",
                "markdown-tts-trust-repair"
            ]
            #endif
            return defaults.compactMap { id in all.first { $0.id == id } }
            #endif
        }

        let preset = raw.lowercased()
        if ["latest", "latest-transcript", "latest-manual-eval", "readiness"].contains(preset) {
            return CoachChatEvaluationCorpus.latestManualEvalFixtureIDs
                .compactMap { id in all.first { $0.id == id } }
        }

        let wanted = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return wanted.compactMap { id in all.first { $0.id == id } }
    }

    /// The typed judgement layer is voice-rubric based, so only fixtures with
    /// explicit choice provenance may enter it. The intentional cold-start
    /// fixture remains unstyled; silently assigning it a legacy/default voice
    /// would make the evaluation harness violate the same trust boundary as
    /// production.
    private static func explicitVoiceFixtures(
        _ fixtures: [CoachChatEvaluationFixture]
    ) -> [CoachChatEvaluationFixture] {
        fixtures.filter { $0.profile?.chosenStyleGoal != nil }
    }

    private static func selectedLongFormConversations(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> [CoachChatConversationFixture] {
        let all = CoachChatConversationCorpus.longFormConversations
        let fixturePreset = env["NOUM_LIVE_AI_FIXTURES"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let raw = env["NOUM_LIVE_AI_LONG_FORM"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if fixturePreset == "readiness" {
            return all
        }
        guard let raw, !raw.isEmpty else {
            #if NOUM_LIVE_AI_EVAL_READINESS
            return all
            #else
            return []
            #endif
        }
        let preset = raw.lowercased()
        if ["1", "true", "yes", "all", "required", "long-form", "longform", "readiness"].contains(preset) {
            return all
        }

        let wanted = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return wanted.compactMap { id in all.first { $0.id == id } }
    }

    private struct JudgementContext {
        let turnDepth: CoachTurnDepth
        let trajectory: UserTrajectoryCacheResult
        let rubric: ActiveGoalRubric?
        let assessment: CoachAssessment?
        let assessmentCacheHit: Bool?
        let assessmentGeneratedAt: Date?
    }

    private static func judgement(
        for fixture: CoachChatEvaluationFixture,
        history: [CoachMessage],
        surface: CoachReplySurface,
        recentProofTests: [String] = []
    ) -> JudgementContext {
        let turnDepth = CoachBrainFlags.judgementPassEnabled
            ? TurnDepthClassifier.classify(
                userText: fixture.latestUserTurn,
                recentTurns: history,
                liveMode: surface == .live
            )
            : .groundedRead
        let trajectory = UserTrajectoryCache.shared.snapshot(
            profile: fixture.profile,
            baseline: .empty,
            rating: .initial,
            sessions: fixture.sessions,
            coachMemory: nil
        )
        guard let rubric = GoalRubricStore.activeRubric(for: fixture.profile) else {
            return JudgementContext(
                turnDepth: turnDepth,
                trajectory: trajectory,
                rubric: nil,
                assessment: nil,
                assessmentCacheHit: nil,
                assessmentGeneratedAt: nil
            )
        }
        let assessmentResult = CoachAssessmentCache.shared.assessment(
            turnDepth: turnDepth,
            userQuestion: fixture.latestUserTurn,
            trajectory: trajectory.snapshot,
            rubric: rubric,
            surface: surface,
            recentProofTests: recentProofTests,
            previousCoachReply: fixture.previousCoachReply,
            build: {
                CoachReasoningPass.assess(
                    turnDepth: turnDepth,
                    userQuestion: fixture.latestUserTurn,
                    trajectory: trajectory.snapshot,
                    rubric: rubric,
                    surface: surface,
                    recentProofTests: recentProofTests,
                    previousCoachReply: fixture.previousCoachReply
                )
            }
        )
        return JudgementContext(
            turnDepth: turnDepth,
            trajectory: trajectory,
            rubric: rubric,
            assessment: assessmentResult.assessment,
            assessmentCacheHit: assessmentResult.cacheHit,
            assessmentGeneratedAt: assessmentResult.generatedAt
        )
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

    private static func proofTestRecentlyRepeated(
        _ proofTest: String,
        in recentProofTests: [String]
    ) -> Bool {
        let key = proofTestKey(proofTest)
        guard !key.isEmpty else { return false }
        return recentProofTests.contains { proofTestKey($0) == key }
    }

    private static func proofTestKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func history(for fixture: CoachChatEvaluationFixture) -> [CoachMessage] {
        var messages: [CoachMessage] = []
        if let previous = fixture.previousCoachReply,
           !previous.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(CoachMessage(role: .coach, text: previous))
        }
        messages.append(CoachMessage(role: .user, text: fixture.latestUserTurn))
        return messages
    }

    private static func liveContext(
        for fixture: CoachChatEvaluationFixture,
        coachingExpertise: [CoachKnowledgeCard],
        recentUserTurns: [String]? = nil
    ) -> String {
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
            recentUserTurns: recentUserTurns ?? [fixture.latestUserTurn],
            coachingExpertise: coachingExpertise
        )
    }

    private static func liveService(diagnostics: CoachLiveDiagnosticRecorder) -> AICoachChatService {
        AICoachChatService(
            keyedProviders: {
                Self.liveProviderChain()
            },
            keyLookup: { provider in
                Self.liveKey(for: provider)
            },
            localeSupportsAI: {
                true
            },
            diagnosticRecorder: { surface, providerName, model, outcome, reason, statusCode, startedAt, now in
                diagnostics.record(
                    surface: surface,
                    providerName: providerName,
                    model: model,
                    outcome: outcome,
                    reason: reason,
                    statusCode: statusCode,
                    startedAt: startedAt,
                    now: now
                )
            }
        )
    }

    private static func liveProviderChain(
        env: [String: String] = ProcessInfo.processInfo.environment,
        keyLookup: ((CoachChatProvider) -> String?)? = nil
    ) -> [CoachChatProvider] {
        let lookup = keyLookup ?? { provider in
            Self.liveKey(for: provider)
        }
        let runtimeSelector = env["NOUM_LIVE_AI_PROVIDER_CHAIN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch runtimeSelector {
        case "agent", "agent-platform", "google-cloud", "vertex":
            return [.agentPlatform].filter { lookup($0) != nil }
        case "gemini", "google":
            return [.agentPlatform, .gemini].filter { lookup($0) != nil }
        case "claude", "anthropic":
            return [.anthropic].filter { lookup($0) != nil }
        case "production", "all", "chain":
            return CoachChatProvider.allCases.filter { lookup($0) != nil }
        case nil, "":
            break
        default:
            break
        }

        #if NOUM_LIVE_AI_EVAL_AGENT_PLATFORM_ONLY
        return [.agentPlatform].filter { lookup($0) != nil }
        #elseif NOUM_LIVE_AI_EVAL_GEMINI_ONLY
        return [.gemini].filter { lookup($0) != nil }
        #elseif NOUM_LIVE_AI_EVAL_CLAUDE_ONLY
        return [.anthropic].filter { lookup($0) != nil }
        #elseif NOUM_LIVE_AI_EVAL_PRODUCTION_CHAIN
        return CoachChatProvider.allCases.filter { lookup($0) != nil }
        #else
        // Keep the manual eval focused on the Google Gemini path the product is
        // being tuned around. If Google Cloud is keyed it goes first; direct
        // Gemini remains the fast fallback. Other providers are deliberately
        // excluded so a "green" live eval cannot hide that Gemini is broken.
        return [.agentPlatform, .gemini].filter { lookup($0) != nil }
        #endif
    }

    private static func liveKey(for provider: CoachChatProvider) -> String? {
        for keyName in provider.keyNames {
            if let value = AICoachChatService.usableAPIKey(ProcessInfo.processInfo.environment[keyName]) {
                return value
            }
            if let value = AICoachChatService.usableAPIKey(LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")) {
                return value
            }
            if let value = AICoachChatService.usableAPIKey(sourceAIConfigValue(forKey: keyName)) {
                return value
            }
        }
        return nil
    }

    /// Manual live evals run from a simulator test host while production builds
    /// correctly exclude `AIConfig.plist` from app resources. Resolve the
    /// gitignored developer config from the source checkout only for a
    /// compile-flagged live run; never copy it into the app or an artifact.
    private static func sourceAIConfigValue(forKey key: String) -> String? {
        #if NOUM_LIVE_AI_EVAL
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configURL = repoRoot
            .appendingPathComponent("Noum", isDirectory: true)
            .appendingPathComponent("AIConfig.plist")
        guard let data = try? Data(contentsOf: configURL),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any] else {
            return nil
        }
        return plist[key] as? String
        #else
        return nil
        #endif
    }

    private static func liveHTTP(
        provider: CoachChatProvider,
        endpoint: URL,
        key: String,
        body: [String: Any]
    ) async throws -> AICoachChatService.ProviderHTTPResult {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12
        switch provider {
        case .openAI, .deepSeek:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .agentPlatform, .gemini:
            request.setGoogleAPIKey(key)
        case .anthropic:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            return .refused(status: -1, retryAfter: nil)
        }
        let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
        guard (200..<300).contains(http.statusCode) else {
            return .refused(status: http.statusCode, retryAfter: retryAfter)
        }
        return .success(data)
    }

    private static func defaultReportPath() -> String {
        #if NOUM_LIVE_AI_EVAL
        if let dumpDirectory = liveEvaluationDumpDirectory() {
            let directory = URL(fileURLWithPath: dumpDirectory, isDirectory: true)
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory
                .appendingPathComponent("coach-live-eval-v1.md")
                .path
        }
        let source = URL(fileURLWithPath: #filePath)
        let repoRoot = source
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let derivedData = repoRoot
            .appendingPathComponent("DerivedData", isDirectory: true)
            .appendingPathComponent("Noum", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: derivedData,
            withIntermediateDirectories: true
        )
        return derivedData
            .appendingPathComponent("noum-live-coach-eval.md")
            .path
        #else
        if let shared = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.jordancoaten.noum"
        ) {
            return shared.appendingPathComponent("noum-live-coach-eval.md").path
        }
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documents.appendingPathComponent("noum-live-coach-eval.md").path
        }
        return (NSTemporaryDirectory() as NSString).appendingPathComponent("noum-live-coach-eval.md")
        #endif
    }
}

private struct CoachLiveDiagnosticRecord: Sendable {
    let provider: String
    let model: String?
    let outcome: AICallDiagnosticOutcome
    let reason: String
    let statusCode: Int?
    let latencyMs: Int?
}

private final class CoachLiveDiagnosticRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRecords: [CoachLiveDiagnosticRecord] = []

    var records: [CoachLiveDiagnosticRecord] {
        lock.lock()
        defer { lock.unlock() }
        return storedRecords
    }

    func record(
        surface: String,
        providerName: String?,
        model: String?,
        outcome: AICallDiagnosticOutcome,
        reason: String,
        statusCode: Int?,
        startedAt: Date?,
        now: Date
    ) {
        let latencyMs = startedAt.map { max(0, Int(now.timeIntervalSince($0) * 1_000)) }
        let record = CoachLiveDiagnosticRecord(
            provider: providerName ?? "No provider",
            model: model,
            outcome: outcome,
            reason: reason,
            statusCode: statusCode,
            latencyMs: latencyMs
        )
        lock.lock()
        storedRecords.append(record)
        lock.unlock()
    }
}
