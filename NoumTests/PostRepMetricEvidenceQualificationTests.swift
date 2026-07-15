import Foundation
import Testing
@testable import Noum

@Suite("Post-rep metric evidence qualification")
struct PostRepMetricEvidenceQualificationTests {
    private let persona = CoachPersona.persona(for: .concise)

    @Test("Low-confidence reps do not make filler or pace claims")
    func lowConfidenceFailsClosed() {
        let sentence = metricSentence(
            fillers: 10,
            duration: 60,
            words: 240,
            confidence: 0.49,
            baselineFillerRate: 2
        )

        #expect(sentence == "Steady. Hold the line.")
    }

    @Test("Stale metric schemas do not make zero-filler or pace claims")
    func staleSchemaFailsClosed() {
        let sentence = metricSentence(
            fillers: 0,
            duration: 60,
            words: 240,
            schemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1,
            baselineFillerRate: 4
        )

        #expect(sentence == "Steady. Hold the line.")
    }

    @Test("Evaluation fixtures do not make live-user mechanic claims")
    func evaluationFixtureFailsClosed() {
        let sentence = metricSentence(
            fillers: 1,
            duration: 60,
            words: 240,
            baselineFillerRate: 4,
            isEvaluationFixture: true
        )

        #expect(sentence == "Steady. Hold the line.")
    }

    @Test("Thin reps cannot turn zero fillers into a clean-run claim")
    func thinRepFailsClosed() {
        let sentence = metricSentence(
            fillers: 0,
            duration: 14,
            words: 20,
            baselineFillerRate: 4
        )

        #expect(sentence == "Short. Extend it.")
    }

    @Test("Withheld mechanics do not suppress independent score evidence")
    func scoreEvidenceRemainsAvailable() {
        let sentence = metricSentence(
            score: 9,
            fillers: 10,
            duration: 60,
            words: 240,
            confidence: 0.49,
            baselineFillerRate: 2
        )

        #expect(sentence == "9. Repeat.")
    }

    @Test("Qualified reps retain filler, zero-filler, and pace coaching")
    func qualifiedControls() {
        #expect(metricSentence(
            fillers: 10,
            duration: 60,
            words: 120,
            confidence: 0.5,
            baselineFillerRate: 2
        ) == "10 fillers. Slow the open.")
        #expect(metricSentence(
            fillers: 0,
            duration: 60,
            words: 120,
            confidence: 0.5
        ) == "Zero fillers. Clean.")
        #expect(metricSentence(
            fillers: 1,
            duration: 60,
            words: 240,
            confidence: 0.5
        ) == "240 WPM. Pull back.")
    }

    private func metricSentence(
        score: Int? = nil,
        fillers: Int,
        duration: TimeInterval,
        words: Int,
        confidence: Double? = nil,
        schemaVersion: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        baselineFillerRate: Double? = nil,
        isEvaluationFixture: Bool = false
    ) -> String {
        let input = PostRepCoachNoteInput(
            sessionID: UUID(),
            mode: .timed,
            score: score,
            fillerCount: fillers,
            duration: duration,
            wordCount: words,
            voice: .concise,
            intentLabel: nil,
            baselineFillerRate: baselineFillerRate,
            baselinePaceWPM: nil,
            bigMoment: nil,
            bigMomentDaysUntil: nil,
            transcriptConfidence: confidence,
            comparisonMetricSchemaVersion: schemaVersion,
            isEvaluationFixture: isEvaluationFixture
        )
        return PostRepCoachNoteService.metricSentence(for: input, persona: persona)
    }
}
