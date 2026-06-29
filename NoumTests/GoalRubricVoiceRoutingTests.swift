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

    @Test func authoritativeSpineVoicesMapToAuthoritativeDeliberately() {
        // executive / persuasive / concise / authoritative / nil share the
        // verdict-first spine and are mapped on purpose (documented), so they
        // stay on the authoritative rubric.
        for voice: SpeakingStyleGoal? in [.authoritative, .executive, .persuasive, .concise, nil] {
            #expect(GoalRubricStore.rubric(for: voice).goalID == "authoritative")
        }
    }

    @Test func everyVoiceResolvesToARubric() {
        for voice in SpeakingStyleGoal.allCases {
            let rubric = GoalRubricStore.rubric(for: voice)
            #expect(!rubric.goalID.isEmpty)
            #expect(!rubric.displayName.isEmpty)
        }
    }

    // MARK: - Dimension reuse (scorer stays single source of truth)

    @Test func allRubricsReuseTheSameScoredDimensionIDs() {
        let rubrics = [
            GoalRubricStore.authoritativeRubric,
            GoalRubricStore.warmRubric,
            GoalRubricStore.storytellingRubric
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
    }

    // MARK: - Weight maps stay well-formed

    @Test func everyRubricWeightMapIsNormalizedAndCoversScoredIDs() {
        let rubrics = [
            GoalRubricStore.authoritativeRubric,
            GoalRubricStore.warmRubric,
            GoalRubricStore.storytellingRubric
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
}
