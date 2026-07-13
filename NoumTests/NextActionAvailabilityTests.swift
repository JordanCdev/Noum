import Foundation
import Testing
@testable import Noum

@Suite("Next action mode availability")
struct NextActionAvailabilityTests {
    @Test func snapshotUsesTheExistingRatedEvidenceGate() {
        #expect(!NextActionModeAvailability(rating: .initial).suddenDeathAvailable)

        let rated = RatingEngine.processRatedSession(
            rating: .initial,
            sessionScore: 8,
            sessionId: UUID(),
            pressureLevel: .elevated
        )

        #expect(NextActionModeAvailability(rating: rated).suddenDeathAvailable)
    }

    @Test func lockedStretchFallsBackToTimedWithMatchingCopy() {
        let result = NextActionEngine.recommend(
            input: stretchInput()
        )

        guard case .practiceMode(let mode, let reason) = result.primary else {
            Issue.record("Expected locked Pressure Drill to fall back to Timed Practice")
            return
        }
        #expect(mode == .timed)
        #expect(result.primary.displayTitle == PracticeMode.timed.displayLabel)
        #expect(reason == NextActionModeAvailability.suddenDeathFallbackReason)
        #expect(result.reasoning == reason)
        #expect(!result.primary.displayTitle.localizedCaseInsensitiveContains("pressure"))
    }

    @Test func unlockedStretchStillPrescribesSuddenDeath() {
        let rated = RatingEngine.processRatedSession(
            rating: .initial,
            sessionScore: 8,
            sessionId: UUID(),
            pressureLevel: .elevated
        )
        let result = NextActionEngine.recommend(
            input: stretchInput(
                availability: NextActionModeAvailability(rating: rated)
            )
        )

        guard case .pressureExposure(let mode, _) = result.primary else {
            Issue.record("Expected the unlocked stretch to preserve Pressure Drill")
            return
        }
        #expect(mode == .suddenDeath)
    }

    private func stretchInput(
        availability: NextActionModeAvailability? = nil
    ) -> NextActionInput {
        var input = NextActionInput(
            fillerCount: 0,
            duration: 50,
            wordCount: 140,
            wpm: 135,
            score: 8,
            categoryRatings: ["Opening": "Good", "Structure": "Good"],
            mode: .timed,
            pressureLevel: .standard,
            baseline: .empty,
            pressureProfile: .empty,
            trends: [],
            drillHistory: [],
            sessionCount: 1,
            streakDays: 1,
            styleGoal: nil
        )
        if let availability {
            input.modeAvailability = availability
        }
        return input
    }
}
