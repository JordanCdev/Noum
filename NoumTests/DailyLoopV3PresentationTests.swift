import Foundation
import Testing
@testable import Noum

@Suite("V3 daily loop presentation")
struct DailyLoopV3PresentationTests {
    @Test("The Today mission honors the persisted one-to-three rep target")
    func missionProgressUsesTheChosenTarget() {
        let cold = TodayRepMissionProgress(completedReps: -4, targetReps: 0)
        let middle = TodayRepMissionProgress(completedReps: 1, targetReps: 3)
        let complete = TodayRepMissionProgress(completedReps: 9, targetReps: 9)

        #expect(cold.targetReps == 1)
        #expect(cold.completedReps == 0)
        #expect(cold.currentRep == 1)
        #expect(cold.progress == 0)
        #expect(middle.targetReps == 3)
        #expect(middle.currentRep == 2)
        #expect(middle.progress == 1.0 / 3.0)
        #expect(complete.targetReps == 3)
        #expect(complete.completedReps == 3)
        #expect(complete.isComplete)
        #expect(complete.progress == 1)
    }

    @Test("Mission copy reports progress without inventing rewards")
    func missionCopyIsTruthful() {
        let active = TodayRepMissionProgress(completedReps: 1, targetReps: 2)
        let complete = TodayRepMissionProgress(completedReps: 1, targetReps: 1)
        let copy = [
            active.compactLabel,
            active.accessibilityValue,
            complete.compactLabel,
            complete.accessibilityValue,
        ].joined(separator: " ").lowercased()

        #expect(active.compactLabel == "Rep 2 of 2")
        #expect(complete.compactLabel == "1 of 1 complete")
        #expect(!copy.contains("xp"))
        #expect(!copy.contains("reward"))
        #expect(!copy.contains("unlocked"))
    }

    @Test("Today gives the one support slot to due coaching before receipts")
    func supportPriorityIsSingleAndStable() {
        #expect(HomeSupportSurface.resolve(
            hasOutcomeAcknowledgement: true,
            hasGoalReview: true,
            hasProgressReceipt: true,
            hasFirstWeekEntry: true,
            hasDeferredSetup: true,
            hasRatingReview: true
        ) == .outcomeAcknowledgement)

        #expect(HomeSupportSurface.resolve(
            hasOutcomeAcknowledgement: false,
            hasGoalReview: true,
            hasProgressReceipt: true,
            hasFirstWeekEntry: true,
            hasDeferredSetup: true,
            hasRatingReview: true
        ) == .goalReview)

        #expect(HomeSupportSurface.resolve(
            hasOutcomeAcknowledgement: false,
            hasGoalReview: false,
            hasProgressReceipt: true,
            hasFirstWeekEntry: true,
            hasDeferredSetup: true,
            hasRatingReview: true
        ) == .firstWeek)

        #expect(HomeSupportSurface.resolve(
            hasOutcomeAcknowledgement: false,
            hasGoalReview: false,
            hasProgressReceipt: true,
            hasFirstWeekEntry: false,
            hasDeferredSetup: true,
            hasRatingReview: true
        ) == .progressReceipt)

        #expect(HomeSupportSurface.resolve(
            hasOutcomeAcknowledgement: false,
            hasGoalReview: false,
            hasProgressReceipt: false,
            hasFirstWeekEntry: true,
            hasDeferredSetup: true,
            hasRatingReview: true
        ) == .firstWeek)

        #expect(HomeSupportSurface.resolve(
            hasOutcomeAcknowledgement: false,
            hasGoalReview: false,
            hasProgressReceipt: false,
            hasFirstWeekEntry: false,
            hasDeferredSetup: false,
            hasRatingReview: false
        ) == nil)
    }

    @Test("The populated Today screen stays within three surfaces")
    func populatedHomeRetainsItsSurfaceBudget() {
        let presentation = HomePrimaryActionPresentation.resolve(
            sessionCount: 4,
            hasPendingOutcomeCheckIn: false,
            hasUpcomingMomentPrep: false
        )

        #expect(presentation.visibleSurfaceCount(hasConditionalRow: true) == 3)
    }

    @Test("Production Home wires the persisted daily goal into the mission")
    func homeUsesDailyGoalAsMissionTarget() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root
                .appendingPathComponent("Noum")
                .appendingPathComponent("ContentView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("targetRepsToday: dailyGoal.goalReps"))
        #expect(!source.contains("targetRepsToday: 3"))
    }
}
