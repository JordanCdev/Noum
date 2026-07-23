import Foundation
import Testing
@testable import Noum

@Suite("Unified progress presentation")
struct UnifiedProgressPresentationTests {
    @Test("Evidence-over-time copy distinguishes no evidence, one rep, and repeated work")
    func evidenceSummaryIsBounded() {
        #expect(
            UnifiedProgressCopy.evidenceSummary(completedReps: 0, practiceDays: 0)
                == "Evidence begins after your first completed rep."
        )
        #expect(
            UnifiedProgressCopy.evidenceSummary(completedReps: 1, practiceDays: 1)
                == "Evidence over time · 1 completed rep across 1 practice day"
        )
        #expect(
            UnifiedProgressCopy.evidenceSummary(completedReps: 4, practiceDays: 3)
                == "Evidence over time · 4 completed reps across 3 practice days"
        )
    }

    @Test("Clarity outcomes state what detection observed and keep the quantity floor visible")
    func clarityOutcomeIsDetectionSafe() {
        let copy = UnifiedProgressCopy.achievementEvidence(
            track: .clarity,
            current: 3,
            target: 3
        )

        #expect(copy == "No filler words detected in 3 quantity-qualified reps")
        #expect(copy.localizedCaseInsensitiveContains("detected"))
        #expect(copy.localizedCaseInsensitiveContains("quantity-qualified"))
        #expect(!copy.localizedCaseInsensitiveContains("perfect"))
    }

    @Test("Achievement evidence cannot report progress beyond its verified target")
    func achievementEvidenceClampsProjection() {
        #expect(
            UnifiedProgressCopy.achievementEvidence(
                track: .volume,
                current: 17,
                target: 10
            ) == "10 qualifying practice reps recorded"
        )
    }

    @Test("A recorded consistency outcome names the achieved threshold, never a reset current streak")
    func recordedConsistencyUsesVerifiedThreshold() {
        let recordedValue = UnifiedProgressCopy.evidenceValue(
            current: 0,
            target: 3,
            isRecorded: true
        )
        #expect(
            UnifiedProgressCopy.achievementEvidence(
                track: .consistency,
                current: recordedValue,
                target: 3
            ) == "3-day practice rhythm recorded"
        )
    }

    @Test("Practice volume is explicitly separate from rated skill")
    func practiceAndRatingStayDistinct() {
        let copy = UnifiedProgressCopy.practiceRatingBoundary

        #expect(copy.localizedCaseInsensitiveContains("rated pressure reps"))
        #expect(copy.localizedCaseInsensitiveContains("not equivalent"))
        #expect(!copy.localizedCaseInsensitiveContains("level means"))
    }

    @Test("The shared outcome row retains every approved restrained variant")
    func progressOutcomeVariants() {
        #expect(Set(ProgressOutcomeKind.allCases) == [
            .personalBest,
            .practiceLevel,
            .achievement,
            .landmark,
        ])
    }
}
