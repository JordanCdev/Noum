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
        case .authoritative, .executive, .persuasive, .concise, .warm, .storytelling, nil:
            // The first shipped rubric is intentionally authoritative because
            // the failure case is "How far off am I from sounding
            // authoritative?" Other voices still benefit from the same
            // verdict-first / close / pressure-stability standard until their
            // own rubrics are added.
            return authoritativeRubric
        }
    }

    static let authoritativeRubric = GoalRubric(
        goalID: "authoritative",
        displayName: "Authoritative communication",
        dimensions: [
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
        ],
        defaultWeights: [
            "verdict_first": 0.22,
            "hedge_control": 0.18,
            "clean_close": 0.18,
            "pressure_stability": 0.18,
            "controlled_pacing": 0.16,
            "salience": 0.08
        ]
    )
}
