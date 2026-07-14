import Foundation
import Testing
@testable import Noum

@Suite("M26 goal outcome loop")
struct GoalOutcomeLoopTests {
    @Test func everyVoiceHasAnExplicitNormalizedRubric() {
        let rubrics = SpeakingStyleGoal.allCases.map(GoalRubricStore.rubric(for:))
        #expect(Set(rubrics.map(\.goalID)).count == SpeakingStyleGoal.allCases.count)
        for rubric in rubrics {
            #expect(abs(rubric.defaultWeights.values.reduce(0, +) - 1) < 0.000_001)
            #expect(Set(rubric.defaultWeights.keys) == Set(rubric.dimensions.map(\.id)))
            #expect((rubric.establishedEvidenceFloor ?? 0) >= 0.65)
        }
    }

    @Test func warmAndStorytellingDoNotUseAuthorityWeights() {
        let authority = GoalRubricStore.rubric(for: .authoritative)
        let warm = GoalRubricStore.rubric(for: .warm)
        let story = GoalRubricStore.rubric(for: .storytelling)
        #expect(warm.defaultWeights["hedge_control"]! < authority.defaultWeights["hedge_control"]!)
        #expect(story.defaultWeights["salience"]! > authority.defaultWeights["salience"]!)
        #expect(story.defaultWeights["verdict_first"]! < authority.defaultWeights["verdict_first"]!)
    }

    @Test func outcomeReadIsDeterministicAndQualitative() {
        let assessment = makeAssessment(confidence: 0.76, evidence: ["The latest rep led with the decision.", "The close stopped cleanly."])
        let first = GoalOutcomeRead.make(style: .executive, assessment: assessment)
        let second = GoalOutcomeRead.make(style: .executive, assessment: assessment)
        #expect(first == second)
        #expect(first.evidenceLevel == .established)
        #expect(first.strongestDimension?.dimensionID == "clean_close")
        #expect(first.nextDimension?.dimensionID == "hedge_control")
    }

    @Test func outcomeReadHonoursEachGoalEvidenceFloor() {
        let assessment = makeAssessment(
            confidence: 0.70,
            evidence: ["The latest rep led with the decision.", "The close stopped cleanly."]
        )

        // Concise uses a calibrated 0.68 floor, while executive presence
        // requires 0.72 before the same evidence can be called established.
        #expect(GoalOutcomeRead.make(style: .concise, assessment: assessment).evidenceLevel == .established)
        #expect(GoalOutcomeRead.make(style: .executive, assessment: assessment).evidenceLevel == .forming)
    }

    @Test func goalOutcomeRequiresAnExplicitVoiceChoice() {
        let unchosen = makeProfile(style: .warm, chosenStyle: nil)
        let chosen = makeProfile(style: .warm, chosenStyle: .warm)
        #expect(GoalOutcomeEngine.selectedGoal(from: unchosen) == nil)
        #expect(GoalOutcomeEngine.selectedGoal(from: chosen) == .warm)
        #expect(AIRewriteService.selectedVoice(from: unchosen) == nil)
        #expect(AIRewriteService.selectedVoice(from: chosen) == .warm)
    }

    @Test func weakEvidenceNeverBecomesAnIdentityVerdict() {
        let read = GoalOutcomeRead.make(
            style: .persuasive,
            assessment: makeAssessment(confidence: 0.24, evidence: [])
        )
        #expect(read.evidenceLevel == .insufficient)
        #expect(read.movement == .emerging)
    }

    @Test func repeatedPromisingOutcomesProduceEarlyImprovement() {
        let outcomes = (0..<2).map { index in
            RecommendationOutcome(
                id: UUID(), fingerprint: "goal", title: "Tighten the close",
                focus: "Clean close", target: "End with the ask", mode: .timed,
                sessionID: UUID(), followed: true,
                completedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                scoreDelta: 1, hasComparableScore: true, fillerDelta: -1,
                durationDelta: 0, fillerRateDelta: -1, comparisonSessionCount: 3,
                goal: .concise, targetDimensionID: "clean_close",
                goalFollowUpResult: .earlyImprovement
            )
        }
        let read = GoalOutcomeRead.make(
            style: .concise,
            assessment: makeAssessment(confidence: 0.8, evidence: ["The close landed.", "The ask was explicit."]),
            outcomes: outcomes
        )
        #expect(read.movement == .improving)
        #expect(read.latestFollowUpResult == .earlyImprovement)
    }

    @Test func showcaseSeedUsesComparableEvidenceBeforeOfferingAMilestone() {
        let fixture = DevSeedData.coachIntelligenceFixture(for: .improvingIntermediate)
        let comparable = fixture.recommendationOutcomes.filter {
            $0.goal == .warm && $0.targetDimensionID == "salience"
        }
        #expect(comparable.count >= 2)
        #expect(comparable.filter { $0.goalFollowUpResult == .earlyImprovement }.count >= 2)

        let read = GoalOutcomeEngine.read(
            profile: fixture.profile,
            baseline: fixture.baseline,
            rating: fixture.rating,
            sessions: fixture.sessions,
            coachMemory: fixture.memory,
            outcomes: fixture.recommendationOutcomes
        )
        #expect(read?.evidenceLevel == .established)
        #expect(read?.movement == .improving)
        #expect(read.map { GoalMilestoneShare.isAvailable(for: $0) } == true)
    }

    @Test func milestoneShareIsEvidenceBoundedAndTranscriptFree() {
        let established = GoalOutcomeRead.make(
            style: .concise,
            assessment: makeAssessment(
                confidence: 0.82,
                evidence: ["The latest rep led with the decision.", "The close stopped cleanly."]
            ),
            outcomes: [
                RecommendationOutcome(
                    id: UUID(), fingerprint: "goal", title: "Tighten the close",
                    focus: "Clean close", target: "End with the ask", mode: .timed,
                    sessionID: UUID(), followed: true, completedAt: Date(),
                    scoreDelta: 1, hasComparableScore: true, fillerDelta: -1,
                    durationDelta: 0, fillerRateDelta: -1, comparisonSessionCount: 3,
                    goal: .concise, targetDimensionID: "clean_close",
                    goalFollowUpResult: .earlyImprovement
                ),
                RecommendationOutcome(
                    id: UUID(), fingerprint: "goal-two", title: "Tighten the close",
                    focus: "Clean close", target: "End with the ask", mode: .timed,
                    sessionID: UUID(), followed: true, completedAt: Date(timeIntervalSince1970: 1),
                    scoreDelta: 1, hasComparableScore: true, fillerDelta: -1,
                    durationDelta: 0, fillerRateDelta: -1, comparisonSessionCount: 3,
                    goal: .concise, targetDimensionID: "clean_close",
                    goalFollowUpResult: .earlyImprovement
                ),
            ]
        )
        #expect(GoalMilestoneShare.isAvailable(for: established))
        let message = GoalMilestoneShare.message(for: established)
        #expect(message.contains("concise"))
        #expect(!message.contains("The latest rep led with the decision."))
        #expect(!message.contains("0.82"))

        let thin = GoalOutcomeRead.make(
            style: .concise,
            assessment: makeAssessment(confidence: 0.28, evidence: [])
        )
        #expect(!GoalMilestoneShare.isAvailable(for: thin))

        let mixed = GoalOutcomeRead.make(
            style: .concise,
            assessment: makeAssessment(
                confidence: 0.82,
                evidence: ["The latest rep led with the decision.", "The close stopped cleanly."]
            ),
            outcomes: [
                RecommendationOutcome(
                    id: UUID(), fingerprint: "mixed", title: "Tighten the close",
                    focus: "Clean close", target: "End with the ask", mode: .timed,
                    sessionID: UUID(), followed: true, completedAt: Date(),
                    scoreDelta: 1, hasComparableScore: true, fillerDelta: 1,
                    durationDelta: 0, fillerRateDelta: 1, comparisonSessionCount: 3,
                    goal: .concise, targetDimensionID: "clean_close",
                    goalFollowUpResult: .mixed
                ),
            ]
        )
        #expect(!GoalMilestoneShare.isAvailable(for: mixed))
    }

    @Test func followUpClassificationStaysSoftOnThinOrConflictingEvidence() {
        #expect(RecommendationLearningStore.goalFollowUpResult(
            followed: true, comparableScoreDelta: nil, fillerRateDelta: 0,
            comparablePaceDelta: nil, comparisonSessionCount: 3
        ) == .needsMoreEvidence)
        #expect(RecommendationLearningStore.goalFollowUpResult(
            followed: true, comparableScoreDelta: 1, fillerRateDelta: 1,
            comparablePaceDelta: nil, comparisonSessionCount: 3
        ) == .mixed)
        #expect(RecommendationLearningStore.goalFollowUpResult(
            followed: false, comparableScoreDelta: 1, fillerRateDelta: -2,
            comparablePaceDelta: nil, comparisonSessionCount: 3
        ) == nil)
        #expect(RecommendationLearningStore.goalFollowUpResult(
            followed: true, comparableScoreDelta: 1, fillerRateDelta: -2,
            comparablePaceDelta: nil, comparisonSessionCount: 1
        ) == nil)
        #expect(RecommendationLearningStore.goalFollowUpResult(
            followed: true, comparableScoreDelta: 2, fillerRateDelta: 1.2,
            comparablePaceDelta: nil, comparisonSessionCount: 3,
            mode: .ahCounter, title: "Filler control", focus: "filler control"
        ) == .mixed)
        #expect(RecommendationLearningStore.goalFollowUpResult(
            followed: true, comparableScoreDelta: -2, fillerRateDelta: nil,
            comparablePaceDelta: -15, comparisonSessionCount: 3,
            mode: .timed, title: "Calm the pace", focus: "controlled pacing",
            wordsPerMinute: 180
        ) == .earlyImprovement)
    }

    @Test func recommendationOutcomeRequiresExplicitAcceptanceAndMatchingMode() {
        let untapped = recommendationExposure(mode: .timed, tappedAt: nil)
        let tapped = recommendationExposure(mode: .timed, tappedAt: Date())

        #expect(!RecommendationLearningStore.followedPrescription(
            untapped,
            completedMode: .timed
        ))
        #expect(RecommendationLearningStore.followedPrescription(
            tapped,
            completedMode: .timed
        ))
        #expect(!RecommendationLearningStore.followedPrescription(
            tapped,
            completedMode: .ahCounter
        ))
    }

    @Test func legacyUntappedExposureFailsClosedForOutcomeAttribution() throws {
        let json = """
        {"fingerprint":"legacy","title":"Timed rep","focus":"Structure","target":"Land one clear point","mode":"timed","isAIBacked":false,"shownAt":0}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let exposure = try decoder.decode(RecommendationExposure.self, from: json)

        #expect(exposure.tappedAt == nil)
        #expect(!RecommendationLearningStore.followedPrescription(
            exposure,
            completedMode: .timed
        ))
    }

    @Test func preM26OutcomeStillDecodes() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","fingerprint":"old","title":"Old","mode":"timed","sessionID":"00000000-0000-0000-0000-000000000002","followed":true,"completedAt":0,"scoreDelta":0,"fillerDelta":0,"durationDelta":0}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(RecommendationOutcome.self, from: json)
        #expect(decoded.goal == nil)
        #expect(decoded.targetDimensionID == nil)
        #expect(decoded.goalFollowUpResult == nil)
        #expect(decoded.fillerRateDelta == nil)
        #expect(decoded.comparisonSessionCount == nil)
        #expect(decoded.comparisonSchemaVersion == nil)
        #expect(!decoded.hasComparableBaseline)
    }

    @Test func legacyGoalFollowUpsCannotPromoteMovementWithoutComparableProvenance() {
        let legacy = (0..<2).map { index in
            RecommendationOutcome(
                id: UUID(), fingerprint: "legacy-\(index)", title: "Old prescription",
                focus: "Clean close", target: nil, mode: .timed,
                sessionID: UUID(), followed: true,
                completedAt: Date(timeIntervalSince1970: Double(index)),
                scoreDelta: 2, hasComparableScore: true, fillerDelta: -3,
                durationDelta: 10, goal: .concise,
                targetDimensionID: "clean_close",
                goalFollowUpResult: .earlyImprovement
            )
        }
        let read = GoalOutcomeRead.make(
            style: .concise,
            assessment: makeAssessment(
                confidence: 0.82,
                evidence: ["The close landed.", "The ask was explicit."]
            ),
            outcomes: legacy
        )

        #expect(read.movement != .improving)
        #expect(read.latestFollowUpResult == nil)
    }

    @Test func comparisonSchemaVersionFailsClosedForMissingOrUnknownPayloads() throws {
        func decode(versionField: String) throws -> RecommendationOutcome {
            let json = """
            {
              "id":"00000000-0000-0000-0000-000000000101",
              "fingerprint":"schema",
              "title":"Schema test",
              "mode":"timed",
              "sessionID":"00000000-0000-0000-0000-000000000102",
              "followed":true,
              "completedAt":0,
              "scoreDelta":1,
              "hasComparableScore":true,
              "fillerDelta":-1,
              "fillerRateDelta":-1,
              "durationDelta":0,
              "comparisonSessionCount":3
              \(versionField)
            }
            """.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            return try decoder.decode(RecommendationOutcome.self, from: json)
        }

        #expect(!(try decode(versionField: "")).hasComparableBaseline)
        #expect(!(try decode(versionField: ", \"comparisonSchemaVersion\":1")).hasComparableBaseline)
        #expect(!(try decode(versionField: ", \"comparisonSchemaVersion\":999")).hasComparableBaseline)
        #expect((try decode(versionField: ", \"comparisonSchemaVersion\":2")).hasComparableBaseline)
    }

    @Test func comparableBaselineNormalizesFillerExposureInsteadOfRawCounts() {
        let current = comparisonSession(fillers: 2, duration: 60)
        let history = [
            comparisonSession(dayOffset: -1, fillers: 3, duration: 120),
            comparisonSession(dayOffset: -2, fillers: 3, duration: 120),
        ]

        let result = RecommendationComparisonEngine.baseline(
            for: current,
            previousSessions: history
        )

        #expect(result.sessionCount == 2)
        #expect(result.rawFillerDelta == -1)
        #expect(result.fillerRateDelta == 0.5)
    }

    @Test func comparableBaselineCanReverseRawRegressionIntoRateImprovement() {
        let current = comparisonSession(fillers: 3, duration: 120)
        let history = [
            comparisonSession(dayOffset: -1, fillers: 2, duration: 60),
            comparisonSession(dayOffset: -2, fillers: 2, duration: 60),
        ]
        let result = RecommendationComparisonEngine.baseline(
            for: current,
            previousSessions: history
        )

        #expect(result.rawFillerDelta == 1)
        #expect(result.fillerRateDelta == -0.5)
    }

    @Test func comparableBaselineExcludesDifferentDemandAndLowQualitySessions() {
        let current = comparisonSession(fillers: 2, duration: 60)
        let validOne = comparisonSession(dayOffset: -1, fillers: 1, duration: 60)
        let validTwo = comparisonSession(dayOffset: -2, fillers: 1, duration: 60)
        let differentMode = comparisonSession(dayOffset: -3, fillers: 9, duration: 60, mode: .ahCounter)
        let differentPressure = comparisonSession(dayOffset: -4, fillers: 9, duration: 60, pressure: .high)
        let differentRatedState = comparisonSession(dayOffset: -5, fillers: 9, duration: 60, isRated: true)
        let tooLong = comparisonSession(dayOffset: -6, fillers: 9, duration: 180)
        let lowConfidence = comparisonSession(dayOffset: -7, fillers: 9, duration: 60, confidence: 0.2)

        let result = RecommendationComparisonEngine.baseline(
            for: current,
            previousSessions: [
                validOne, validTwo, differentMode, differentPressure,
                differentRatedState, tooLong, lowConfidence,
            ]
        )

        #expect(result.sessionIDs == [validOne.id, validTwo.id])
        #expect(result.fillerRateDelta == 1)
    }

    @Test func comparableBaselineRequiresTwoPriorsPerMetric() {
        let current = comparisonSession(fillers: 2, duration: 60, score: 8)
        let first = comparisonSession(dayOffset: -1, fillers: 1, duration: 60, score: 7)
        let thin = RecommendationComparisonEngine.baseline(
            for: current,
            previousSessions: [first]
        )
        #expect(thin.sessionCount == 1)
        #expect(thin.scoreDelta == nil)
        #expect(thin.fillerRateDelta == nil)
        #expect(thin.paceDelta == nil)

        let second = comparisonSession(dayOffset: -2, fillers: 1, duration: 60, score: 7)
        let measured = RecommendationComparisonEngine.baseline(
            for: current,
            previousSessions: [first, second]
        )
        #expect(measured.scoreDelta == 1)
        #expect(measured.fillerRateDelta == 1)
        #expect(measured.paceDelta != nil)
    }

    @Test func comparableBaselineRejectsDuplicateIDsAndMismatchedMetricEpochs() {
        let current = comparisonSession(fillers: 2, duration: 60)
        let first = comparisonSession(dayOffset: -1, fillers: 1, duration: 60)
        let second = comparisonSession(dayOffset: -2, fillers: 1, duration: 60)
        let legacy = comparisonSession(
            dayOffset: -3, fillers: 99, duration: 60,
            comparisonMetricSchemaVersion: nil
        )

        let measured = RecommendationComparisonEngine.baseline(
            for: current,
            previousSessions: [first, first, legacy, second]
        )
        #expect(measured.sessionIDs == [first.id, second.id])

        let inflated = RecommendationComparisonEngine.baseline(
            for: current,
            previousSessions: [first, first]
        )
        #expect(inflated.sessionCount == 1)
        #expect(inflated.scoreDelta == nil)
        #expect(inflated.fillerRateDelta == nil)

        let legacyCurrent = comparisonSession(
            fillers: 2, duration: 60, comparisonMetricSchemaVersion: nil
        )
        #expect(RecommendationComparisonEngine.baseline(
            for: legacyCurrent, previousSessions: [first, second]
        ).sessionCount == 0)
    }

    @Test func comparableBaselineRequiresExactTimedAndSuddenDeathDemand() {
        let current = comparisonSession(fillers: 2, duration: 60)
        let ordinaryOne = comparisonSession(dayOffset: -1, fillers: 1, duration: 60)
        let ordinaryTwo = comparisonSession(dayOffset: -2, fillers: 1, duration: 60)
        let hard = comparisonSession(
            dayOffset: -3, fillers: 9, duration: 60, timedDifficulty: .hard
        )
        let project = comparisonSession(
            dayOffset: -4, fillers: 9, duration: 60,
            speechProjectID: "ice_breaker"
        )
        let legacy = comparisonSession(
            dayOffset: -5, fillers: 9, duration: 60,
            includePracticeDemand: false
        )

        #expect(RecommendationComparisonEngine.baseline(
            for: current,
            previousSessions: [legacy, project, hard, ordinaryTwo, ordinaryOne]
        ).sessionIDs == [ordinaryOne.id, ordinaryTwo.id])

        let projectCurrent = comparisonSession(
            fillers: 2, duration: 60, speechProjectID: "ice_breaker"
        )
        let sameProjectOne = comparisonSession(
            dayOffset: -1, fillers: 1, duration: 60,
            speechProjectID: "ice_breaker"
        )
        let sameProjectTwo = comparisonSession(
            dayOffset: -2, fillers: 1, duration: 60,
            speechProjectID: "ice_breaker"
        )
        let otherProject = comparisonSession(
            dayOffset: -3, fillers: 9, duration: 60,
            speechProjectID: "table_topic"
        )
        #expect(RecommendationComparisonEngine.baseline(
            for: projectCurrent,
            previousSessions: [otherProject, sameProjectTwo, sameProjectOne]
        ).sessionIDs == [sameProjectOne.id, sameProjectTwo.id])

        let suddenCurrent = comparisonSession(
            fillers: 2, duration: 60, mode: .suddenDeath
        )
        let suddenOne = comparisonSession(
            dayOffset: -1, fillers: 1, duration: 60, mode: .suddenDeath
        )
        let suddenTwo = comparisonSession(
            dayOffset: -2, fillers: 1, duration: 60, mode: .suddenDeath
        )
        let suddenHard = comparisonSession(
            dayOffset: -3, fillers: 9, duration: 60, mode: .suddenDeath,
            suddenDeathDifficulty: .hard
        )
        #expect(RecommendationComparisonEngine.baseline(
            for: suddenCurrent,
            previousSessions: [suddenHard, suddenTwo, suddenOne]
        ).sessionIDs == [suddenOne.id, suddenTwo.id])

        let legacyCurrent = comparisonSession(
            fillers: 2, duration: 60, includePracticeDemand: false
        )
        #expect(RecommendationComparisonEngine.baseline(
            for: legacyCurrent,
            previousSessions: [ordinaryOne, ordinaryTwo]
        ).sessionCount == 0)
    }

    @Test func comparableBaselineUsesFiveRecentSessionsInsideTwentyEightDays() {
        let current = comparisonSession(fillers: 2, duration: 60)
        let recent = (1...7).map { day in
            comparisonSession(dayOffset: -day, fillers: day, duration: 60)
        }
        let stale = comparisonSession(dayOffset: -29, fillers: 99, duration: 60)
        let result = RecommendationComparisonEngine.baseline(
            for: current,
            previousSessions: Array(recent.reversed()) + [stale]
        )

        #expect(result.sessionIDs == Array(recent.prefix(5).map(\.id)))
        #expect(!result.sessionIDs.contains(stale.id))
    }

    @Test func comparableIMBaselineRequiresMatchingScenarioAndTone() {
        let setup = IMConversationSetup(scenario: .workUpdate, targetTone: .concise)
        let current = comparisonSession(
            fillers: 2, duration: 120, mode: .imConversation, imSetup: setup
        )
        let matchOne = comparisonSession(
            dayOffset: -1, fillers: 1, duration: 120, mode: .imConversation, imSetup: setup
        )
        let matchTwo = comparisonSession(
            dayOffset: -2, fillers: 1, duration: 120, mode: .imConversation, imSetup: setup
        )
        let mismatch = comparisonSession(
            dayOffset: -3, fillers: 8, duration: 120, mode: .imConversation,
            imSetup: IMConversationSetup(scenario: .networking, targetTone: .warm)
        )
        let result = RecommendationComparisonEngine.baseline(
            for: current,
            previousSessions: [mismatch, matchTwo, matchOne]
        )

        #expect(result.sessionIDs == [matchOne.id, matchTwo.id])
    }

    @Test func rewriteEligibilitySuppressesWeakOrSensitiveEvidence() {
        #expect(AIRewriteService.eligibility(
            transcript: "I think the proposal should start next week because the customer evidence is clear and the team is ready.",
            confidence: 0.9
        ) == .eligible)
        #expect(AIRewriteService.eligibility(
            transcript: "A short fragment.",
            confidence: 0.9
        ) == .tooShort)
        #expect(AIRewriteService.eligibility(
            transcript: "This transcript is long enough to inspect but its recognition confidence is too weak to rewrite honestly.",
            confidence: 0.3
        ) == .lowConfidence)
        #expect(AIRewriteService.eligibility(
            transcript: "Contact me at jordan@example.com because this sentence otherwise contains enough words for the rewrite gate.",
            confidence: 0.9
        ) == .containsSensitiveIdentifier)
        #expect(AIRewriteService.eligibility(
            transcript: "word word word word word word word word word word word word word word word word",
            confidence: 0.9
        ) == .semanticallyAmbiguous)
    }

    @Test func onDeviceRewriteIsDeterministicTransparentAndVocabularyBounded() throws {
        let transcript = "Um, so I think the release should start next week because the support team has time to prepare. The customer message needs one clear decision."
        let light = try #require(AIRewriteService.onDeviceRewrite(
            transcript: transcript,
            weakness: .opening,
            voice: .authoritative,
            intensity: .light,
            confidence: 0.9
        ))
        let medium = try #require(AIRewriteService.onDeviceRewrite(
            transcript: transcript,
            weakness: .opening,
            voice: .authoritative,
            intensity: .medium,
            confidence: 0.9
        ))
        let strong = try #require(AIRewriteService.onDeviceRewrite(
            transcript: transcript,
            weakness: .opening,
            voice: .authoritative,
            intensity: .strong,
            confidence: 0.9
        ))

        #expect(light.source == .onDevice)
        #expect(medium.source == .onDevice)
        #expect(strong.source == .onDevice)
        #expect(light.text.lowercased().contains("um") == false)
        #expect(medium.text.lowercased().hasPrefix("i think"))
        #expect(strong.text.lowercased().hasPrefix("the release"))
        #expect(Set([light.text, medium.text, strong.text]).count == 3)

        let sourceWords = Set(transcript.lowercased().split(whereSeparator: { !$0.isLetter }))
        let rewrittenWords = Set(strong.text.lowercased().split(whereSeparator: { !$0.isLetter }))
        #expect(rewrittenWords.isSubset(of: sourceWords))
    }

    @Test func onDeviceRewriteWithholdsCosmeticOrUnsafeEdits() {
        #expect(AIRewriteService.onDeviceRewrite(
            transcript: "The decision is ready for review. The team can respond today.",
            weakness: .opening,
            voice: .warm,
            intensity: .strong,
            confidence: 0.9
        ) == nil)
    }

    @Test func coachContextUsesObservationalGoalFollowUpLanguage() {
        let outcome = RecommendationOutcome(
            id: UUID(), fingerprint: "goal", title: "Tighten the close",
            focus: "Clean close", target: "End with the ask", mode: .timed,
            sessionID: UUID(), followed: true, completedAt: Date(),
            scoreDelta: 1, hasComparableScore: true, fillerDelta: -1,
            durationDelta: 0, fillerRateDelta: -1, comparisonSessionCount: 3,
            goal: .executive, targetDimensionID: "clean_close",
            goalFollowUpResult: .earlyImprovement
        )
        let lines = RecommendationResponseAnalyzer.promptLines(from: [outcome])
        #expect(lines.first?.contains("this rep showed early signs of improvement") == true)
        #expect(lines.first?.contains("not proof that the drill caused") == true)
    }

    private func makeAssessment(confidence: Double, evidence: [String]) -> CoachAssessment {
        CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "Goal read",
            directVerdict: "A bounded read.",
            confidence: confidence,
            evidenceUsed: evidence,
            rubricScores: [
                RubricScore(dimensionID: "clean_close", label: "Clean close", score: 0.82, confidence: confidence, evidence: ["The close landed."], missingEvidence: nil),
                RubricScore(dimensionID: "hedge_control", label: "Hedge control", score: 0.42, confidence: confidence, evidence: ["Two hedges remained."], missingEvidence: "Need a cleaner claim.")
            ],
            missingEvidence: [],
            nextProofTest: "Repeat the answer and finish with the ask.",
            responseMode: .expandable
        )
    }

    private func comparisonSession(
        dayOffset: Int = 0,
        fillers: Int,
        duration: TimeInterval,
        mode: PracticeMode = .timed,
        pressure: PressureLevel = .standard,
        isRated: Bool = false,
        score: Int? = 7,
        confidence: Double? = 0.9,
        imSetup: IMConversationSetup? = nil,
        comparisonMetricSchemaVersion: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        timedDifficulty: TimedPracticeDifficulty = .medium,
        speechProjectID: String? = nil,
        suddenDeathDifficulty: SuddenDeathDifficulty = .medium,
        includePracticeDemand: Bool = true
    ) -> PracticeSession {
        let details = imSetup.map {
            IMConversationDetails(
                setup: $0,
                turns: [],
                actualTone: nil,
                finalState: nil,
                outcome: nil
            )
        }
        let practiceDemand: PracticeSessionDemand? = switch mode {
        case .timed where includePracticeDemand:
            .timed(difficulty: timedDifficulty, speechProjectID: speechProjectID)
        case .suddenDeath where includePracticeDemand:
            .suddenDeath(difficulty: suddenDeathDifficulty)
        default:
            nil
        }
        return PracticeSession(
            transcript: "The recommendation is clear and the supporting evidence gives the listener one practical decision before the explanation moves into the next useful point.",
            fillerWordCount: fillers,
            duration: duration,
            date: Date(timeIntervalSince1970: 2_000_000 + Double(dayOffset) * 86_400),
            mode: mode,
            imConversationDetails: details,
            score: score,
            transcriptConfidence: confidence,
            pressureLevel: pressure,
            isRated: isRated,
            comparisonMetricSchemaVersion: comparisonMetricSchemaVersion,
            practiceDemand: practiceDemand
        )
    }

    private func recommendationExposure(
        mode: PracticeMode,
        tappedAt: Date?
    ) -> RecommendationExposure {
        RecommendationExposure(
            fingerprint: "goal-outcome-attribution",
            title: "One focused rep",
            focus: "Structure",
            target: "Land one clear point",
            mode: mode,
            isAIBacked: false,
            shownAt: Date(timeIntervalSince1970: 0),
            tappedAt: tappedAt
        )
    }

    private func makeProfile(
        style: SpeakingStyleGoal,
        chosenStyle: SpeakingStyleGoal?
    ) -> CoachingProfile {
        CoachingProfile(
            speakingContext: .work,
            primaryGoal: .moreConcise,
            confidenceLevel: .rebuilding,
            biggestChallenge: .rambling,
            desiredOutcome: .concise,
            speakingStyleGoal: style,
            styleReference: "",
            coachingBrief: "",
            motivationWhyNow: "",
            successVision: "",
            chosenStyleGoal: chosenStyle
        )
    }
}
