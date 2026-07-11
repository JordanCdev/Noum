import Foundation
import Testing
@testable import Noum

@Suite("Home, practice, and Path polish")
struct HomePracticePathPolishTests {
    @Test("Daily-goal celebration is event-driven, never hydration-driven")
    func celebrationRequiresCompletedRepEvent() {
        #expect(!DailyGoalCelebrationPolicy.shouldPresent(
            source: .hydration,
            completionDayKey: "2026-07-11",
            todayKey: "2026-07-11",
            repsToday: 1,
            goalReps: 1,
            lastCelebrationDayKey: ""
        ))
        #expect(DailyGoalCelebrationPolicy.shouldPresent(
            source: .completedRep,
            completionDayKey: "2026-07-11",
            todayKey: "2026-07-11",
            repsToday: 1,
            goalReps: 1,
            lastCelebrationDayKey: ""
        ))
    }

    @Test("Daily-goal celebration rejects stale, early, and duplicate events")
    func celebrationRejectsInvalidEvents() {
        #expect(!DailyGoalCelebrationPolicy.shouldPresent(
            source: .completedRep,
            completionDayKey: "2026-07-10",
            todayKey: "2026-07-11",
            repsToday: 1,
            goalReps: 1,
            lastCelebrationDayKey: ""
        ))
        #expect(!DailyGoalCelebrationPolicy.shouldPresent(
            source: .completedRep,
            completionDayKey: "2026-07-11",
            todayKey: "2026-07-11",
            repsToday: 1,
            goalReps: 2,
            lastCelebrationDayKey: ""
        ))
        #expect(!DailyGoalCelebrationPolicy.shouldPresent(
            source: .completedRep,
            completionDayKey: "2026-07-11",
            todayKey: "2026-07-11",
            repsToday: 2,
            goalReps: 2,
            lastCelebrationDayKey: "2026-07-11"
        ))
    }

    @Test("Filler Control starts its clock only after transcription is live")
    func fillerControlClockFollowsRecordingState() {
        #expect(!AhCounterRecordingTransitionPolicy.shouldStartElapsedTimer(
            wasRecording: false,
            isRecording: false
        ))
        #expect(AhCounterRecordingTransitionPolicy.shouldStartElapsedTimer(
            wasRecording: false,
            isRecording: true
        ))
        #expect(AhCounterRecordingTransitionPolicy.shouldStopElapsedTimer(
            wasRecording: true,
            isRecording: false
        ))
    }

    @Test("Train library has three visibly distinct semantic groups")
    func trainGroupsRemainDistinctAndComplete() {
        #expect(TrainLibraryGroup.allCases.map(\.title) == [
            "Speaking drills",
            "Conversation practice",
            "Learn and build"
        ])
        #expect(TrainLibraryItem.items.filter { $0.group == .speakingDrills }.map(\.id) == ["chooseExercise"])
        #expect(TrainLibraryItem.items.filter { $0.group == .conversationPractice }.map(\.id) == ["roleplay"])
        #expect(TrainLibraryItem.items.filter { $0.group == .learnAndBuild }.map(\.id) == [
            "lessons", "speechProjects", "path"
        ])
    }

    @Test("Path trees grow toward the foreground")
    func pathTreePerspectiveIsNatural() {
        let horizon = PathLandscapeSizing.treePerspectiveScale(depthInField: 0)
        let foreground = PathLandscapeSizing.treePerspectiveScale(depthInField: 0.42)
        #expect(horizon == 1)
        #expect(foreground > horizon)
        #expect(PathLandscapeSizing.treePerspectiveScale(depthInField: -1) == 1)
        #expect(abs(PathLandscapeSizing.treePerspectiveScale(depthInField: 2) - 1.58) < 0.0001)
    }
}
