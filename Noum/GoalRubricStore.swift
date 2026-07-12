import Foundation

// MARK: - Goal rubric store

/// Tiny deterministic owner for goal rubrics. This is a store in the product
/// sense (single source of truth for rubric definitions), not another
/// ObservableObject: rubrics are static reference data and should not create a
/// new mutable state owner.
enum GoalRubricStore {

    static func activeRubric(for profile: CoachingProfile?) -> ActiveGoalRubric {
        ActiveGoalRubric(
            rubric: rubric(for: profile?.speakingStyleGoal),
            voice: profile?.speakingStyleGoal
        )
    }

    static func rubric(for voice: SpeakingStyleGoal?) -> GoalRubric {
        switch voice {
        case .warm:
            // Warmth is built on relational softeners and a natural cadence, so
            // judging it on the authoritative hedge-control / verdict-first
            // standard actively punishes a valid voice (CLAUDE.md: never punish
            // semantically valid speech patterns). Warm reps land on pacing and a
            // trustworthy point, not on stripped declaratives.
            return warmRubric
        case .storytelling:
            // A story does not lead with the verdict and is not about clean
            // declaratives; its whole job is a vivid, memorable arc. Scoring it
            // verdict-first / hedge-control-heavy mis-reads the voice. Salience
            // and a landed close carry it instead.
            return storytellingRubric
        case .authoritative, nil: return authoritativeRubric
        case .executive: return executiveRubric
        case .persuasive: return persuasiveRubric
        case .concise: return conciseRubric
        }
    }

    /// The six coaching dimensions are shared verbatim across every voice — only
    /// the weights and display name change per voice. This keeps the deterministic
    /// scorer (`CoachReasoningPass`, keyed on these exact dimension IDs) the single
    /// source of scoring truth: a voice rubric is a *weighting of what matters*,
    /// never a new heuristic or threshold. Weights mirror the already-shipped
    /// per-voice priorities in `PracticeEvaluator.voiceDeliveryBonus`.
    static let coreDimensions: [RubricDimension] = [
            RubricDimension(
                id: "verdict_first",
                label: "Verdict-first structure",
                description: "The recommendation or answer leads before context.",
                proofSignals: [
                    "recommendation appears in sentence one",
                    "decision language appears before explanation",
                    "answer leads before caveats"
                ],
                proofTest: "Record a 75-second answer where sentence one gives the verdict, sentence two gives one reason, and the final sentence names the ask.",
                missingIfAbsent: "Need a rep where the first sentence clearly carries the verdict."
            ),
            RubricDimension(
                id: "hedge_control",
                label: "Hedge control",
                description: "Low reliance on maybe, probably, kind of, sort of, just, or apologetic softeners.",
                proofSignals: [
                    "few hedge words per minute",
                    "clean declarative claims",
                    "no apology before the point"
                ],
                proofTest: "Run one answer with no maybe, probably, kind of, sort of, or just before the recommendation.",
                missingIfAbsent: "Need evidence that the recommendation holds without hedge language."
            ),
            RubricDimension(
                id: "clean_close",
                label: "Clean close",
                description: "The answer lands a committed final sentence and stops.",
                proofSignals: [
                    "close contains the ask",
                    "no trailing filler after final point",
                    "no soft tail such as yeah or so"
                ],
                proofTest: "End the next rep with the exact decision or ask, then stop talking for two seconds.",
                missingIfAbsent: "Need proof that the close lands under a hard stop."
            ),
            RubricDimension(
                id: "pressure_stability",
                label: "Pressure stability",
                description: "The same structure holds when timing, stakes, or interruption pressure rises.",
                proofSignals: [
                    "rated pressure-mode reps",
                    "stable score under timed pressure",
                    "fillers do not spike under pressure"
                ],
                proofTest: "Run the same answer under a 60-90 second timer or pressure mode and keep the verdict first.",
                missingIfAbsent: "Need a pressure rep; a clean normal rep does not prove authority under stakes."
            ),
            RubricDimension(
                id: "controlled_pacing",
                label: "Controlled pacing",
                description: "Pace and pauses give the user time to choose words instead of filling space.",
                proofSignals: [
                    "pace inside a natural band",
                    "silence replaces filler",
                    "few fillers per minute"
                ],
                proofTest: "Use one silent beat after the verdict, then finish the answer without speeding up.",
                missingIfAbsent: "Need a rep showing pauses replacing fillers, not just a lower score."
            ),
            RubricDimension(
                id: "salience",
                label: "Memorable point",
                description: "When mechanics are clean, the answer has one point the room can repeat.",
                proofSignals: [
                    "one repeatable phrase",
                    "one salient image",
                    "clear implication or so-what"
                ],
                proofTest: "Make the recommendation memorable with one short phrase the listener could repeat afterward.",
                missingIfAbsent: "Need salience evidence only after mechanics are already clean."
            )
    ]

    static let authoritativeRubric = GoalRubric(
        goalID: "authoritative",
        displayName: "Authoritative communication",
        dimensions: coreDimensions,
        defaultWeights: [
            "verdict_first": 0.22,
            "hedge_control": 0.18,
            "clean_close": 0.18,
            "pressure_stability": 0.18,
            "controlled_pacing": 0.16,
            "salience": 0.08
        ],
        establishedEvidenceFloor: 0.70
    )

    static let executiveRubric = GoalRubric(
        goalID: "executive",
        displayName: "Executive communication",
        dimensions: coreDimensions,
        defaultWeights: [
            "verdict_first": 0.20,
            "hedge_control": 0.12,
            "clean_close": 0.18,
            "pressure_stability": 0.24,
            "controlled_pacing": 0.18,
            "salience": 0.08
        ],
        establishedEvidenceFloor: 0.72
    )

    static let persuasiveRubric = GoalRubric(
        goalID: "persuasive",
        displayName: "Persuasive communication",
        dimensions: coreDimensions,
        defaultWeights: [
            "verdict_first": 0.18,
            "hedge_control": 0.10,
            "clean_close": 0.18,
            "pressure_stability": 0.14,
            "controlled_pacing": 0.14,
            "salience": 0.26
        ],
        establishedEvidenceFloor: 0.70
    )

    static let conciseRubric = GoalRubric(
        goalID: "concise",
        displayName: "Concise communication",
        dimensions: coreDimensions,
        defaultWeights: [
            "verdict_first": 0.28,
            "hedge_control": 0.18,
            "clean_close": 0.24,
            "pressure_stability": 0.10,
            "controlled_pacing": 0.14,
            "salience": 0.06
        ],
        establishedEvidenceFloor: 0.68
    )

    /// Warm voice: down-weight hedge control (softeners are part of warmth) and
    /// verdict-first (warm builds rapport before the ask); reward natural pacing
    /// and a point worth trusting. Mirrors `voiceDeliveryBonus(.warm)` rewarding
    /// the 125–155 WPM band and substance over stripped declaratives.
    static let warmRubric = GoalRubric(
        goalID: "warm",
        displayName: "Warm, credible communication",
        dimensions: coreDimensions,
        defaultWeights: [
            "verdict_first": 0.12,
            "hedge_control": 0.06,
            "clean_close": 0.18,
            "pressure_stability": 0.16,
            "controlled_pacing": 0.26,
            "salience": 0.22
        ],
        establishedEvidenceFloor: 0.70
    )

    /// Storytelling voice: a story does not open with the verdict and is not a
    /// clean-declarative exercise, so verdict-first and hedge-control fall back
    /// hard; the memorable point (salience) and a landed close carry it. Mirrors
    /// `voiceDeliveryBonus(.storytelling)` rewarding a developed, vivid arc.
    static let storytellingRubric = GoalRubric(
        goalID: "storytelling",
        displayName: "Vivid, memorable communication",
        dimensions: coreDimensions,
        defaultWeights: [
            "verdict_first": 0.08,
            "hedge_control": 0.08,
            "clean_close": 0.20,
            "pressure_stability": 0.14,
            "controlled_pacing": 0.20,
            "salience": 0.30
        ],
        establishedEvidenceFloor: 0.70
    )
}
