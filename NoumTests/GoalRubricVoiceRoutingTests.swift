//
//  GoalRubricVoiceRoutingTests.swift
//  NoumTests
//
//  PER-VOICE RUBRIC ROUTING — locks the fix for a real honesty bug.
//
//  Before this slice, `GoalRubricStore.rubric(for:)` collapsed all six
//  `SpeakingStyleGoal` voices onto the single `authoritativeRubric`. A user who
//  explicitly chose "Warm and welcoming" was scored against a verdict-first /
//  hedge-control standard (the opposite of warmth) and the coach copy literally
//  told them they were "approaching the authoritative communication standard."
//  That violates the CLAUDE.md invariant "never punish semantically valid speech
//  patterns incorrectly" on the one surface that had not been voice-branched.
//
//  These tests are NOT a calibration claim. They assert STRUCTURAL invariants of
//  the routing + weighting only:
//    1. warm/storytelling route to their own rubric and stop overclaiming the
//       authoritative standard;
//    2. every voice reuses the exact same six scored dimension IDs (so the
//       deterministic `CoachReasoningPass` scorer remains the single source of
//       scoring truth — a voice rubric is a *weighting*, never a new heuristic);
//    3. all weight maps stay normalized and cover exactly the scored IDs;
//    4. the per-voice weight *intent* holds (warm de-emphasizes hedge control vs.
//       authoritative; storytelling makes salience its top dimension) — mirroring
//       the already-shipped `voiceDeliveryBonus` priorities.
//
//  No threshold or numeric-calibration assertion is made here; that remains in
//  CoachReadCalibrationBaselineTests and stays human-gated.

import Foundation
import Testing
@testable import Noum

@Suite("GoalRubricVoiceRoutingTests")
struct GoalRubricVoiceRoutingTests {

    /// The six dimension IDs the deterministic scorer (`CoachReasoningPass`)
    /// actually scores. Any rubric weight map must cover exactly these.
    private static let scoredDimensionIDs: Set<String> = [
        "verdict_first", "hedge_control", "clean_close",
        "pressure_stability", "controlled_pacing", "salience"
    ]

    // MARK: - Routing

    @Test func warmVoiceRoutesToWarmRubricNotAuthoritative() {
        let rubric = GoalRubricStore.rubric(for: .warm)
        #expect(rubric.goalID == "warm")
        // The headline overclaim fix: warm users must never be told they are
        // approaching the *authoritative* standard.
        #expect(rubric.displayName != GoalRubricStore.authoritativeRubric.displayName)
        #expect(!rubric.displayName.lowercased().contains("authoritative"))
    }

    @Test func storytellingVoiceRoutesToStorytellingRubricNotAuthoritative() {
        let rubric = GoalRubricStore.rubric(for: .storytelling)
        #expect(rubric.goalID == "storytelling")
        #expect(rubric.displayName != GoalRubricStore.authoritativeRubric.displayName)
        #expect(!rubric.displayName.lowercased().contains("authoritative"))
    }

    @Test func everyChosenVoiceOwnsAnExplicitRubric() {
        for voice in SpeakingStyleGoal.allCases {
            #expect(GoalRubricStore.rubric(for: voice).goalID == voice.rawValue)
        }
        #expect(GoalRubricStore.activeRubric(for: nil) == nil)
    }

    @Test func everyVoiceResolvesToARubric() {
        for voice in SpeakingStyleGoal.allCases {
            let rubric = GoalRubricStore.rubric(for: voice)
            #expect(!rubric.goalID.isEmpty)
            #expect(!rubric.displayName.isEmpty)
        }
    }

    @Test func askNoumUsesNeutralFundamentalsWithoutInferringAStyleGoal() {
        let rubric = GoalRubricStore.coachingRubric(for: nil)
        #expect(rubric.voice == nil)
        #expect(rubric.rubric.goalID == "neutral_coaching")
        #expect(rubric.rubric.displayName == "Communication fundamentals")
    }

    @Test func deepVerdictNamesTheSelectedRubricInsteadOfAuthority() {
        let rubrics = [
            GoalRubricStore.coachingRubric(for: nil),
            ActiveGoalRubric(
                rubric: GoalRubricStore.warmRubric,
                voice: .warm
            )
        ]

        for rubric in rubrics {
            let assessment = CoachReasoningPass.assess(
                turnDepth: .deepAssessment,
                userQuestion: "Where do I stand overall?",
                trajectory: Self.evidenceRichTrajectory,
                rubric: rubric,
                surface: .text
            )
            let verdict = assessment.directVerdict.lowercased()
            #expect(verdict.contains(rubric.rubric.displayName.lowercased()))
            #expect(!verdict.contains("sounding authoritative"))
        }
    }

    @Test func contextualMovesKeepTheirTypedEvidenceDimension() {
        let cases: [(question: String, expectedID: String)] = [
            ("How should I answer interview questions?", "verdict_first"),
            ("How do I disagree without sounding defensive?", "verdict_first"),
            ("How should I handle a client concern in a sales pitch?", "salience")
        ]
        let rubric = GoalRubricStore.coachingRubric(for: nil)

        for row in cases {
            let assessment = CoachReasoningPass.assess(
                turnDepth: .quickMove,
                userQuestion: row.question,
                trajectory: Self.evidenceRichTrajectory,
                rubric: rubric,
                surface: .text
            )
            #expect(assessment.nextProofDimensionID == row.expectedID)

            let selectedEvidence = assessment.rubricScores
                .first { $0.dimensionID == row.expectedID }?
                .evidence.first
            let brief = CoachChatBrief(assessment: assessment)
            #expect(selectedEvidence != nil)
            #expect(brief.decisiveEvidence?.contains(selectedEvidence ?? "") == true)
        }
    }

    @Test func typedBriefFailsClosedWithoutUsableEvidenceForItsMove() {
        let missingFact = Self.assessment(
            evidenceUsed: [
                "latest rep: Timed, 9/10, 0 fillers, 60s",
                "case summary: the opening needs work"
            ],
            dimensionID: "verdict_first",
            scoreEvidence: [
                "the available excerpt did not clearly put the answer first"
            ]
        )
        let internalFact = Self.assessment(
            evidenceUsed: ["latest rep: Timed, 9/10, 0 fillers, 60s"],
            dimensionID: "verdict_first",
            scoreEvidence: ["case summary: the opening needs work"]
        )
        let mismatchedDimension = Self.assessment(
            evidenceUsed: ["latest rep: Timed, 9/10, 0 fillers, 60s"],
            dimensionID: "clean_close",
            scoreEvidence: ["latest transcript leads with a decision word"]
        )

        for assessment in [missingFact, internalFact, mismatchedDimension] {
            let brief = CoachChatBrief(assessment: assessment)
            #expect(brief.decisiveEvidence == nil)
            #expect(brief.evidenceStrength == .missing)
            #expect(brief.directVerdict ==
                "I don’t have enough evidence to choose your next move yet.")
            #expect(brief.directVerdict != assessment.directVerdict)
            #expect(brief.nextMove == nil)
        }
    }

    @Test func untypedBriefRejectsInternalAndAbsenceMarkerEvidence() {
        let assessment = Self.assessment(
            evidenceUsed: [
                "case summary: hypothesis: the opening needs work",
                "active intervention: repeat the recommendation",
                "no clear verdict-first proof in the available excerpt",
                "filler evidence was not quantity-qualified"
            ],
            dimensionID: nil,
            scoreEvidence: []
        )

        let brief = CoachChatBrief(assessment: assessment)
        #expect(brief.decisiveEvidence == nil)
        #expect(brief.evidenceStrength == .missing)
        #expect(brief.directVerdict ==
            "I don’t have enough evidence to choose your next move yet.")
        #expect(brief.nextMove == nil)
    }

    @Test func nilProofDimensionCannotAuthorizeUsableLookingEvidenceOrAMove() {
        let assessment = Self.assessment(
            evidenceUsed: ["latest rep: Timed, 9/10, 0 fillers, 60s"],
            dimensionID: nil,
            scoreEvidence: ["latest transcript leads with a decision word"]
        )

        let brief = CoachChatBrief(assessment: assessment)
        #expect(brief.evidenceStrength == .missing)
        #expect(brief.decisiveEvidence == nil)
        #expect(brief.nextMove == nil)
        #expect(brief.directVerdict ==
            "I don’t have enough evidence to choose your next move yet.")
        #expect(!brief.provisionalCoachRead.contains(assessment.nextProofTest))
    }

    @Test func subFloorTranscriptCannotProveVerdictCloseOrSalience() throws {
        var trajectory = Self.evidenceRichTrajectory
        trajectory.latestRepEvidencePack = LatestRepEvidencePack(
            mode: "Timed",
            score: 10,
            fillerCount: 0,
            durationSeconds: 5,
            wordsPerMinute: 145,
            transcriptWordCount: 8,
            transcriptExcerpt: "My recommendation matters because we should decide um",
            evidenceLines: ["latest rep: Timed, 10/10, 0 fillers, 5s"]
        )

        let assessment = CoachReasoningPass.assess(
            turnDepth: .quickMove,
            userQuestion: "What should I fix next?",
            trajectory: trajectory,
            rubric: GoalRubricStore.coachingRubric(for: nil),
            surface: .text
        )
        let verdict = try #require(assessment.rubricScores.first {
            $0.dimensionID == "verdict_first"
        })
        let close = try #require(assessment.rubricScores.first {
            $0.dimensionID == "clean_close"
        })
        let salience = try #require(assessment.rubricScores.first {
            $0.dimensionID == "salience"
        })

        #expect(verdict.score == 0.35)
        #expect(close.score == 0.48)
        #expect(salience.score == 0.38)
        #expect(verdict.evidence.first?.contains("no clear") == true)
        #expect(close.evidence.first?.contains("no duration-qualified") == true)
        #expect(salience.evidence.first?.contains("no memorable") == true)
        #expect(CoachChatBrief(assessment: assessment).decisiveEvidence == nil)
    }

    @Test func hedgeControlDoesNotInferMeaningFromWordsOrSubstrings() throws {
        func assessment(transcript: String) -> CoachAssessment {
            var trajectory = Self.evidenceRichTrajectory
            trajectory.latestRepEvidencePack?.transcriptExcerpt = transcript
            return CoachReasoningPass.assess(
                turnDepth: .groundedRead,
                userQuestion: "Did I hedge too much?",
                trajectory: trajectory,
                rubric: GoalRubricStore.coachingRubric(for: nil),
                surface: .text
            )
        }

        let substring = assessment(
            transcript: "We should adjust the plan because one owner can decide."
        )
        let legitimateUncertainty = assessment(
            transcript: "Maybe legal can confirm the threshold; my recommendation still stands."
        )
        let substringScore = try #require(substring.rubricScores.first {
            $0.dimensionID == "hedge_control"
        })
        let uncertaintyScore = try #require(legitimateUncertainty.rubricScores.first {
            $0.dimensionID == "hedge_control"
        })

        #expect(substringScore.score == 0.60)
        #expect(uncertaintyScore.score == substringScore.score)
        #expect(substringScore.evidence.first?.contains("not judged from wording") == true)
        #expect(CoachChatBrief(assessment: substring).decisiveEvidence == nil)
        #expect(CoachChatBrief(assessment: legitimateUncertainty).decisiveEvidence == nil)
    }

    @Test func cleanCloseUsesTheFinalWordInsteadOfAStringSuffix() throws {
        func closeScore(for transcript: String) throws -> RubricScore {
            var trajectory = Self.evidenceRichTrajectory
            trajectory.latestRepEvidencePack?.transcriptExcerpt = transcript
            let assessment = CoachReasoningPass.assess(
                turnDepth: .groundedRead,
                userQuestion: "Did I land the close?",
                trajectory: trajectory,
                rubric: GoalRubricStore.coachingRubric(for: nil),
                surface: .text
            )
            return try #require(assessment.rubricScores.first {
                $0.dimensionID == "clean_close"
            })
        }

        let semanticallyValidCloses = [
            "The team needs momentum.",
            "The result should feel premium.",
            "I also support it.",
            "I believe so.",
            "Yeah."
        ]
        for transcript in semanticallyValidCloses {
            let score = try closeScore(for: transcript)
            #expect(score.score > 0.35)
            #expect(score.evidence.first?.contains("complete claim") == true)
        }

        let filler = try closeScore(
            for: "My recommendation is one owner because we need a decision, um."
        )
        #expect(filler.score == 0.35)
        #expect(filler.evidence.first?.contains("soft trailing close") == true)
    }

    // MARK: - Dimension reuse (scorer stays single source of truth)

    @Test func allRubricsReuseTheSameScoredDimensionIDs() {
        let rubrics = [
            GoalRubricStore.authoritativeRubric,
            GoalRubricStore.executiveRubric,
            GoalRubricStore.persuasiveRubric,
            GoalRubricStore.conciseRubric,
            GoalRubricStore.warmRubric,
            GoalRubricStore.storytellingRubric,
            GoalRubricStore.neutralCoachingRubric
        ]
        for rubric in rubrics {
            let ids = Set(rubric.dimensions.map(\.id))
            #expect(
                ids == Self.scoredDimensionIDs,
                "Rubric \(rubric.goalID) must reuse exactly the scored dimension IDs — a new ID would score as an inert default."
            )
        }
    }

    @Test func voiceRubricsShareTheCoreDimensionDefinitionsVerbatim() {
        // Only weights + displayName may differ per voice; the dimension copy is
        // shared so no rubric invents new coaching language or heuristics.
        #expect(GoalRubricStore.warmRubric.dimensions == GoalRubricStore.coreDimensions)
        #expect(GoalRubricStore.storytellingRubric.dimensions == GoalRubricStore.coreDimensions)
        #expect(GoalRubricStore.authoritativeRubric.dimensions == GoalRubricStore.coreDimensions)
        #expect(GoalRubricStore.executiveRubric.dimensions == GoalRubricStore.coreDimensions)
        #expect(GoalRubricStore.persuasiveRubric.dimensions == GoalRubricStore.coreDimensions)
        #expect(GoalRubricStore.conciseRubric.dimensions == GoalRubricStore.coreDimensions)
        #expect(GoalRubricStore.neutralCoachingRubric.dimensions == GoalRubricStore.coreDimensions)
    }

    // MARK: - Weight maps stay well-formed

    @Test func everyRubricWeightMapIsNormalizedAndCoversScoredIDs() {
        let rubrics = [
            GoalRubricStore.authoritativeRubric,
            GoalRubricStore.executiveRubric,
            GoalRubricStore.persuasiveRubric,
            GoalRubricStore.conciseRubric,
            GoalRubricStore.warmRubric,
            GoalRubricStore.storytellingRubric,
            GoalRubricStore.neutralCoachingRubric
        ]
        for rubric in rubrics {
            #expect(
                Set(rubric.defaultWeights.keys) == Self.scoredDimensionIDs,
                "Rubric \(rubric.goalID) weights must key exactly the scored dimensions."
            )
            let total = rubric.defaultWeights.values.reduce(0, +)
            #expect(abs(total - 1.0) < 0.0001, "Rubric \(rubric.goalID) weights must sum to 1.0 (got \(total)).")
            for (id, weight) in rubric.defaultWeights {
                #expect(weight > 0, "Rubric \(rubric.goalID) weight for \(id) must be positive.")
            }
        }
    }

    // MARK: - Per-voice weight intent

    @Test func warmDeEmphasizesHedgeControlVersusAuthoritative() {
        let warm = GoalRubricStore.warmRubric.defaultWeights
        let auth = GoalRubricStore.authoritativeRubric.defaultWeights
        // Warmth uses relational softeners by design — hedge control must not be
        // a heavy penalty, and pacing should carry more than under authority.
        #expect((warm["hedge_control"] ?? 1) < (auth["hedge_control"] ?? 0))
        #expect((warm["verdict_first"] ?? 1) < (auth["verdict_first"] ?? 0))
        #expect((warm["controlled_pacing"] ?? 0) > (auth["controlled_pacing"] ?? 1))
    }

    @Test func storytellingMakesSalienceItsTopDimension() {
        let weights = GoalRubricStore.storytellingRubric.defaultWeights
        let salience = weights["salience"] ?? 0
        for (id, weight) in weights where id != "salience" {
            #expect(salience >= weight, "Storytelling salience (\(salience)) must be >= \(id) (\(weight)).")
        }
        // And it must not be judged verdict-first like authority is.
        #expect((weights["verdict_first"] ?? 1) < (GoalRubricStore.authoritativeRubric.defaultWeights["verdict_first"] ?? 0))
    }

    private static let evidenceRichTrajectory = UserTrajectorySnapshot(
        generatedAt: Date(timeIntervalSince1970: 1_000),
        sessionCount: 8,
        ratedSessionCount: 8,
        evidenceCoverage: 0.50,
        recentSessionLines: ["Pressure Drill: 9/10, 0 fillers, 60s"],
        trendLines: [],
        latestRepEvidencePack: LatestRepEvidencePack(
            mode: "Pressure Drill",
            score: 9,
            fillerCount: 0,
            durationSeconds: 60,
            wordsPerMinute: 145,
            transcriptWordCount: 70,
            transcriptExcerpt: "My recommendation is one owner because the team needs a decision",
            evidenceLines: [
                "latest rep: Pressure Drill, 9/10, 0 fillers, 60s",
                "pace estimate: 145 WPM"
            ]
        ),
        coachCaseSummary: nil,
        activeInterventionState: nil
    )

    private static func assessment(
        evidenceUsed: [String],
        dimensionID: String?,
        scoreEvidence: [String]
    ) -> CoachAssessment {
        CoachAssessment(
            turnDepth: .quickMove,
            surface: .text,
            questionRestatement: "What should I fix first?",
            directVerdict: "The opening is the next lever.",
            confidence: 0.62,
            evidenceUsed: evidenceUsed,
            rubricScores: [RubricScore(
                dimensionID: "verdict_first",
                label: "Verdict-first structure",
                score: 0.42,
                confidence: 0.62,
                evidence: scoreEvidence,
                missingEvidence: nil
            )],
            nextProofDimensionID: dimensionID,
            missingEvidence: [],
            nextProofTest: "Put the recommendation in sentence one.",
            responseMode: .immediateOnly
        )
    }
}
