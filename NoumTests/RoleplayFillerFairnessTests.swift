import Testing
@testable import Noum

@Suite("Roleplay filler fairness")
struct RoleplayFillerFairnessTests {
    @Test("Semantic words do not lower Roleplay quality or raise pressure")
    func semanticWordsStayNeutral() {
        let scenario = RoleplayCatalog.interview
        let objection = scenario.objections(at: .easy)[0]
        let pairs = [
            (
                "I like this approach because the data supports our decision.",
                "I support this approach because the data supports our decision."
            ),
            (
                "Actually the plan worked because the data supports our decision.",
                "Clearly the plan worked because the data supports our decision."
            ),
            (
                "This kind works because the data supports our decision today.",
                "This model works because the data supports our decision today."
            ),
            (
                "We sort records because the data supports our decision today.",
                "We store records because the data supports our decision today."
            ),
        ]

        for (semantic, neutral) in pairs {
            let semanticResult = RoleplayEngine.evaluateTurn(
                scenario: scenario,
                objection: objection,
                response: semantic
            )
            let neutralResult = RoleplayEngine.evaluateTurn(
                scenario: scenario,
                objection: objection,
                response: neutral
            )

            #expect(semanticResult.responseQuality == neutralResult.responseQuality)
            #expect(semanticResult.recommendedRetryMode == neutralResult.recommendedRetryMode)
        }
    }

    @Test("Roleplay withholds disfluency penalties without duration-qualified evidence")
    func disfluencyDoesNotCreateAnUncalibratedPenalty() {
        let rubric = RoleplayCatalog.interview.rubric
        let withDisfluency = "Um we shipped on time because the data supports our decision."
        let neutralOpening = "Now we shipped on time because the data supports our decision."

        #expect(
            RoleplayEngine.score(response: withDisfluency, rubric: rubric)
                == RoleplayEngine.score(response: neutralOpening, rubric: rubric)
        )
    }

    @Test("Explicit hedging still affects the existing Roleplay content read")
    func explicitHedgingRemainsAContentSignal() {
        let rubric = RoleplayCatalog.interview.rubric
        let hedged = "Maybe we shipped on time because the data supports our decision."
        let direct = "Clearly we shipped on time because the data supports our decision."

        #expect(
            RoleplayEngine.score(response: hedged, rubric: rubric)
                < RoleplayEngine.score(response: direct, rubric: rubric)
        )
    }
}
