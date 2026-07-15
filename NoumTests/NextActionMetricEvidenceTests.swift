import Foundation
import Testing
@testable import Noum

@Suite("Next action metric evidence")
struct NextActionMetricEvidenceTests {
    @Test("Low-confidence filler evidence cannot trigger severe routing")
    func lowConfidenceFillerFailsClosed() {
        let input = makeInput(
            fillerCount: 3,
            duration: 20,
            wordCount: 47,
            transcriptConfidence: 0.49
        )

        #expect(NextActionEngine.recommendAfterSession(input: input) == nil)
    }

    @Test("Low-confidence pace evidence cannot trigger severe routing")
    func lowConfidencePaceFailsClosed() {
        let input = makeInput(
            fillerCount: 0,
            duration: 15,
            wordCount: 51,
            transcriptConfidence: 0.49
        )

        #expect(NextActionEngine.recommendAfterSession(input: input) == nil)
    }

    @Test("An explicitly unqualified latest session cannot trigger metric routing")
    func explicitUnqualifiedLatestSessionFailsClosed() {
        let input = makeInput(
            fillerCount: 3,
            duration: 20,
            wordCount: 70,
            transcriptConfidence: nil,
            latestSessionID: UUID(),
            latestSessionQualifies: false
        )

        #expect(NextActionEngine.recommendAfterSession(input: input) == nil)
    }

    private func makeInput(
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        transcriptConfidence: Double?,
        latestSessionID: UUID? = nil,
        latestSessionQualifies: Bool = false
    ) -> NextActionInput {
        NextActionInput(
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            wpm: Double(wordCount) / (duration / 60),
            score: 4,
            categoryRatings: [:],
            mode: .timed,
            pressureLevel: .standard,
            baseline: .empty,
            pressureProfile: .empty,
            trends: [],
            drillHistory: [],
            sessionCount: 1,
            streakDays: 1,
            styleGoal: nil,
            transcriptConfidence: transcriptConfidence,
            latestSessionID: latestSessionID,
            latestSessionQualifies: latestSessionQualifies
        )
    }
}
