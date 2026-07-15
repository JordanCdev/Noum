import Foundation
import Testing
@testable import Noum

@Suite("Evidence-qualified goal next action")
struct GoalOutcomeNextActionTests {
    private let sourceSessionID = UUID()

    @Test func everyGoalActionTargetIsVoiceAligned() {
        for voice in SpeakingStyleGoal.allCases {
            for dimension in GoalRubricStore.coreDimensions {
                if let target = GoalRubricStore.actionTarget(
                    for: voice,
                    dimensionID: dimension.id
                ) {
                    #expect(voice.aligns(with: target.skillArea))
                }
            }
        }

        #expect(GoalRubricStore.actionTarget(for: .warm, dimensionID: "verdict_first") == nil)
        #expect(GoalRubricStore.actionTarget(for: .warm, dimensionID: "hedge_control") == nil)
        #expect(GoalRubricStore.actionTarget(for: .storytelling, dimensionID: "verdict_first") == nil)
        #expect(GoalRubricStore.actionTarget(for: .storytelling, dimensionID: "hedge_control") == nil)
        #expect(GoalRubricStore.actionTarget(for: .concise, dimensionID: "hedge_control")?.skillArea == .conciseSpeaking)
    }

    @Test func outcomeReadUsesWeightedActionableDimensionAndMatchingProof() throws {
        let assessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "Goal read",
            directVerdict: "A bounded read.",
            confidence: 0.82,
            evidenceUsed: ["A qualified latest rep.", "A second comparable reference."],
            rubricScores: [
                score("hedge_control", value: 0.10),
                score("controlled_pacing", value: 0.60),
                score("salience", value: 0.40),
            ],
            missingEvidence: [],
            nextProofTest: "A stale generic proof test.",
            responseMode: .expandable
        )

        let read = GoalOutcomeRead.make(style: .warm, assessment: assessment)

        #expect(read.nextDimension?.dimensionID == "salience")
        let expected = try #require(
            GoalRubricStore.coreDimensions.first { $0.id == "salience" }
        )
        #expect(read.prescribedNextAction == expected.proofTest)
        #expect(!read.prescribedNextAction.contains("stale"))
    }

    @Test func establishedGoalReadSelectsOneComparableRepWithExactAttribution() throws {
        let result = NextActionEngine.recommend(input: input(read: read()))

        guard case .practiceMode(let mode, let reason) = result.primary else {
            Issue.record("Expected an attributed full practice rep")
            return
        }
        #expect(mode == .timed)
        #expect(reason == "End with the exact ask, then stop.")
        let attribution = try #require(result.goalAttribution)
        #expect(attribution.goal == .authoritative)
        #expect(attribution.targetDimensionID == "clean_close")
        #expect(attribution.sourceSessionID == sourceSessionID)
        #expect(attribution.proofTest == reason)
        #expect(result.secondary == nil)
    }

    @Test func severeAndPersistentEvidenceKeepPriorityOverGoal() {
        let severe = input(read: read(), fillerCount: 4, duration: 20)
        let severeResult = NextActionEngine.recommend(input: severe)
        #expect(severeResult.goalAttribution == nil)
        guard case .practiceMode(let severeMode, _) = severeResult.primary else {
            Issue.record("Expected severe filler evidence to retain priority")
            return
        }
        #expect(severeMode == .ahCounter)

        let blocker = input(
            read: read(),
            baseline: baseline(blockers: ["Structure"])
        )
        let blockerResult = NextActionEngine.recommend(input: blocker)
        #expect(blockerResult.goalAttribution == nil)
        guard case .confidenceRebuilding(let drill) = blockerResult.primary else {
            Issue.record("Expected persistent blocker to retain priority")
            return
        }
        #expect(drill.skillArea == .structure)
    }

    @Test func continuingCaseBeatsGoalButDiagnoseStatusDoesNotRepeat() {
        let continuing = input(
            read: read(),
            coachMemory: memory(status: .formingEvidence)
        )
        let caseResult = NextActionEngine.recommend(input: continuing)
        #expect(caseResult.goalAttribution == nil)
        guard case .practiceMode(let mode, let reason) = caseResult.primary else {
            Issue.record("Expected the durable case to continue")
            return
        }
        #expect(mode == .ahCounter)
        #expect(reason == "Replace the next filler with a silent beat.")

        let diagnose = input(
            read: read(),
            coachMemory: memory(status: .diagnoseBeforeRepeating)
        )
        let goalResult = NextActionEngine.recommend(input: diagnose)
        #expect(goalResult.goalAttribution?.targetDimensionID == "clean_close")
    }

    @Test func weakMismatchedMixedAndSatisfiedGoalReadsFailClosed() {
        #expect(NextActionEngine.recommend(
            input: input(read: read(evidenceLevel: .insufficient))
        ).goalAttribution == nil)
        #expect(NextActionEngine.recommend(
            input: input(read: read(style: .warm))
        ).goalAttribution == nil)
        #expect(NextActionEngine.recommend(
            input: input(read: read(movement: .mixed))
        ).goalAttribution == nil)
        #expect(NextActionEngine.recommend(
            input: input(read: read(scoreValue: 0.82, missingEvidence: nil))
        ).goalAttribution == nil)
        #expect(NextActionEngine.recommend(
            input: input(read: read(), latestSessionQualifies: false)
        ).goalAttribution == nil)
    }

    @Test func lockedPressureProofFallsBackWithoutFalseGoalCredit() {
        let pressure = read(
            dimensionID: "pressure_stability",
            label: "Pressure stability",
            proof: "Run the answer under pressure and keep the verdict first."
        )
        let goalInput = input(read: pressure, modeAvailability: .failClosed)

        let result = NextActionEngine.recommend(input: goalInput)

        guard case .practiceMode(let mode, _) = result.primary else {
            Issue.record("Expected safe capability fallback")
            return
        }
        #expect(mode == .timed)
        #expect(result.availabilityFallbackFrom == .suddenDeath)
        #expect(result.goalAttribution == nil)
    }

    @Test func legacyGoalOnlyOutcomesCannotCreateTargetMovement() {
        let legacy = (0..<2).map { index in
            RecommendationOutcome(
                id: UUID(), fingerprint: "legacy-goal-\(index)", title: "Generic rep",
                focus: nil, target: nil, mode: .timed, sessionID: UUID(),
                followed: true,
                completedAt: Date(timeIntervalSince1970: Double(index)),
                scoreDelta: 1, hasComparableScore: true, fillerDelta: -1,
                durationDelta: 0, fillerRateDelta: -1, comparisonSessionCount: 3,
                goal: .authoritative, targetDimensionID: nil,
                goalFollowUpResult: .earlyImprovement
            )
        }
        let assessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "Goal read",
            directVerdict: "A bounded read.",
            confidence: 0.82,
            evidenceUsed: ["A qualified latest rep.", "A second comparable reference."],
            rubricScores: [score("clean_close", value: 0.40)],
            missingEvidence: [],
            nextProofTest: "Generic.",
            responseMode: .expandable
        )

        let outcome = GoalOutcomeRead.make(
            style: .authoritative,
            assessment: assessment,
            outcomes: legacy
        )
        #expect(outcome.movement != .improving)
        #expect(outcome.latestFollowUpResult == nil)
    }

    @Test func trendProjectionCannotOverwriteDurableCaseBlueprint() throws {
        let focus = try #require(CurrentCoachingFocusPresentation.make(
            trends: [
                SkillTrend(
                    skillArea: .structure,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 5,
                    currentLevel: .developing
                )
            ],
            sessionCount: 5
        ))
        let caseBlueprint = RecommendationBiasBlueprint(
            recommendedMode: .ahCounter,
            recommendedTone: nil,
            recommendedScenario: nil,
            focus: "Cleaner opening",
            target: "Replace the next filler with a silent beat.",
            modeBenefit: "Builds filler awareness.",
            whyMode: "The active case is still forming.",
            whyNow: "One followed rep is still due.",
            suggestedTimedDifficulty: nil,
            suggestedTheme: .all,
            source: .caseIntervention
        )

        let projected = focus.applying(to: caseBlueprint)

        #expect(projected.recommendedMode == caseBlueprint.recommendedMode)
        #expect(projected.focus == caseBlueprint.focus)
        #expect(projected.target == caseBlueprint.target)
        #expect(projected.source == .caseIntervention)
    }

    private func read(
        style: SpeakingStyleGoal = .authoritative,
        evidenceLevel: GoalEvidenceLevel = .established,
        movement: GoalMovement = .holding,
        dimensionID: String = "clean_close",
        label: String = "Clean close",
        scoreValue: Double = 0.40,
        missingEvidence: String? = "Need a committed close.",
        proof: String = "End with the exact ask, then stop."
    ) -> GoalOutcomeRead {
        GoalOutcomeRead(
            style: style,
            evidenceLevel: evidenceLevel,
            movement: movement,
            strongestDimension: nil,
            nextDimension: RubricScore(
                dimensionID: dimensionID,
                label: label,
                score: scoreValue,
                confidence: 0.82,
                evidence: ["The latest qualified rep left the close open."],
                missingEvidence: missingEvidence
            ),
            evidenceCitation: "The latest qualified rep left the close open.",
            confidence: 0.82,
            prescribedNextAction: proof,
            latestFollowUpResult: nil
        )
    }

    private func input(
        read: GoalOutcomeRead,
        fillerCount: Int = 1,
        duration: TimeInterval = 60,
        baseline: CommunicationBaseline? = nil,
        modeAvailability: NextActionModeAvailability = .allAvailable,
        coachMemory: CoachMemory? = nil,
        latestSessionQualifies: Bool = true
    ) -> NextActionInput {
        NextActionInput(
            fillerCount: fillerCount,
            duration: duration,
            wordCount: 120,
            wpm: 120,
            score: 6,
            categoryRatings: [:],
            mode: .timed,
            pressureLevel: .standard,
            baseline: baseline ?? self.baseline(),
            pressureProfile: .empty,
            trends: [],
            drillHistory: [],
            sessionCount: 10,
            streakDays: 2,
            styleGoal: SpeakingStyleGoal.authoritative.title,
            modeAvailability: modeAvailability,
            coachMemory: coachMemory,
            goalOutcomeRead: read,
            latestSessionID: sourceSessionID,
            latestSessionQualifies: latestSessionQualifies
        )
    }

    private func baseline(blockers: [String] = []) -> CommunicationBaseline {
        let sampleCount = 10
        let confidence = BaselineConfidence.established
        return CommunicationBaseline(
            lastUpdated: Date(),
            sessionCount: sampleCount,
            qualifyingSessionCount: sampleCount,
            fillerRate: BaselineStat(value: 1, sampleCount: sampleCount, confidence: confidence, trend: .stable, percentile25: 0.5, percentile75: 2),
            pace: BaselineStat(value: 130, sampleCount: sampleCount, confidence: confidence, trend: .stable, percentile25: 120, percentile75: 145),
            paceVariance: .empty,
            durationTendency: BaselineStat(value: 60, sampleCount: sampleCount, confidence: confidence, trend: .stable, percentile25: 45, percentile75: 75),
            pauseRate: .empty,
            pauseFilledRatio: .empty,
            openingStrength: .empty,
            closingStrength: .empty,
            structureQuality: .empty,
            answerDepth: .empty,
            clarity: .empty,
            vocabularyRange: .empty,
            hedgingRate: .empty,
            averageScore: BaselineStat(value: 6, sampleCount: sampleCount, confidence: confidence, trend: .stable, percentile25: 5, percentile75: 7),
            clutchWordFrequencies: [:],
            topStrengths: [],
            persistentBlockers: blockers
        )
    }

    private func memory(status: CoachInterventionReviewStatus) -> CoachMemory {
        CoachMemory(
            updatedAt: Date(),
            evidenceCount: 5,
            evidenceConfidence: .tentative,
            currentLever: .fillerReduction,
            goalFit: .aligned,
            strengths: [],
            blockers: ["Filler words"],
            workingHypothesis: "Fillers may still be carrying the opening.",
            activeIntervention: CoachIntervention(
                title: "Pause through the opening",
                focus: "Cleaner opening",
                target: "Replace the next filler with a silent beat.",
                mode: .ahCounter,
                prescribedAt: Date(),
                lastObservedAt: nil,
                followedRepCount: 1,
                minimumFollowedRepsForReview: 2,
                reviewStatus: status,
                reviewBasis: "Evidence is still forming."
            )
        )
    }

    private func score(_ dimensionID: String, value: Double) -> RubricScore {
        let label = GoalRubricStore.coreDimensions
            .first { $0.id == dimensionID }?.label ?? dimensionID
        return RubricScore(
            dimensionID: dimensionID,
            label: label,
            score: value,
            confidence: 0.82,
            evidence: ["Observed in a qualified rep."],
            missingEvidence: value < 0.70 ? "Need one observable proof." : nil
        )
    }
}
