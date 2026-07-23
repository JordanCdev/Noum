import Foundation
import SwiftUI
import Testing
@testable import Noum

@Suite("Post-rep coaching receipt")
struct PostRepReceiptProjectionTests {
    @MainActor
    @Test("Personal best leads while every additional update remains available")
    func personalBestPriorityAndDisclosureCount() throws {
        let tier = try #require(AchievementStore.allTiers.first)
        let projection = try #require(PostRepReceiptProjection.resolve(
            milestone: MilestoneEvent(
                icon: "star.fill",
                tint: .orange,
                title: "New personal best.",
                subtitle: "8/10 in Timed Practice",
                detail: "Previous best: 7/10"
            ),
            reachedNewPracticeLevel: false,
            practiceLevelTitle: "Practice level 2",
            skillEvents: [
                SkillLevelUpEvent(
                    skillArea: .fillerReduction,
                    previousLevel: .developing,
                    newLevel: .solid,
                    date: Date()
                )
            ],
            newUnlocks: [tier],
            practiceCredit: "+86 XP banked"
        ))

        #expect(projection.primary.title == "New personal best")
        #expect(projection.primary.detail.contains("Previous best: 7/10"))
        #expect(projection.additional.count == 2)
        #expect(projection.practiceCredit == "+86 XP banked")
    }

    @Test("A practice-level crossing is narrated once")
    func practiceLevelDeduplication() throws {
        let projection = try #require(PostRepReceiptProjection.resolve(
            milestone: MilestoneEvent(
                icon: "arrow.up.circle.fill",
                tint: .blue,
                title: "Level up.",
                subtitle: "Practice level 3",
                detail: "2,000 XP banked"
            ),
            reachedNewPracticeLevel: true,
            practiceLevelTitle: "Practice level 3",
            skillEvents: [],
            newUnlocks: [],
            practiceCredit: "+40 XP banked"
        ))

        #expect(projection.primary.title == "Practice record updated")
        #expect(projection.allUpdates.count == 1)
    }

    @Test("Practice credit alone does not fabricate a milestone")
    func creditDoesNotCreateProgressClaim() {
        let projection = PostRepReceiptProjection.resolve(
            milestone: nil,
            reachedNewPracticeLevel: false,
            practiceLevelTitle: "Practice level 1",
            skillEvents: [],
            newUnlocks: [],
            practiceCredit: "+20 XP banked"
        )

        #expect(projection == nil)
    }
}

@Suite("Post-rep first-pass copy")
struct PostRepDebriefCopyTests {
    @Test("Coach read shows one restrained observation")
    func conciseObservation() {
        let read = "Natural, well-controlled pace. Filler rate dropped to 1.2 per minute. Keep building consistency."

        #expect(PostRepDebriefCopy.conciseObservation(from: read) == "Natural, well-controlled pace.")
    }

    @Test("Prescribed action prefers the explicit next step")
    func prescribedAction() throws {
        let fix = PostRepVerdictContent.Fix(
            headline: "Your answer stayed surface-level.",
            evidence: .text("Three points were introduced without examples."),
            nextMove: "Develop one idea fully before moving to the next. Keep it concrete."
        )

        #expect(
            PostRepDebriefCopy.prescribedAction(from: fix)
                == "Develop one idea fully before moving to the next."
        )
    }
}
