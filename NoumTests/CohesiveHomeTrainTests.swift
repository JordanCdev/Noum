import Foundation
import Testing
@testable import Noum

@Suite("Cohesive Home priority")
struct CohesiveHomePriorityTests {
    @Test func outcomeCheckInWinsEveryCompetingPriority() {
        let presentation = HomePrimaryActionPresentation.resolve(
            sessionCount: 12,
            hasPendingOutcomeCheckIn: true,
            hasUpcomingMomentPrep: true
        )

        #expect(presentation.kind == .pendingOutcomeCheckIn)
        #expect(presentation.showsAskNoum)
    }

    @Test func upcomingMomentPrepWinsTheRecommendedRep() {
        let presentation = HomePrimaryActionPresentation.resolve(
            sessionCount: 6,
            hasPendingOutcomeCheckIn: false,
            hasUpcomingMomentPrep: true
        )

        #expect(presentation.kind == .upcomingMomentPrep)
    }

    @Test func completedHistoryResolvesToRecommendationAndDayZeroToFirstRep() {
        #expect(HomePrimaryActionPresentation.resolve(
            sessionCount: 1,
            hasPendingOutcomeCheckIn: false,
            hasUpcomingMomentPrep: false
        ).kind == .recommendedRep)

        #expect(HomePrimaryActionPresentation.resolve(
            sessionCount: 0,
            hasPendingOutcomeCheckIn: false,
            hasUpcomingMomentPrep: false
        ).kind == .firstRep)
    }

    @Test func defaultHomeNeverExceedsThreeSurfaces() {
        let dayZero = HomePrimaryActionPresentation.resolve(
            sessionCount: 0,
            hasPendingOutcomeCheckIn: false,
            hasUpcomingMomentPrep: false
        )
        let populated = HomePrimaryActionPresentation.resolve(
            sessionCount: 8,
            hasPendingOutcomeCheckIn: false,
            hasUpcomingMomentPrep: false
        )

        #expect(dayZero.visibleSurfaceCount(hasConditionalRow: false) == 1)
        #expect(populated.visibleSurfaceCount(hasConditionalRow: false) == 2)
        #expect(populated.visibleSurfaceCount(hasConditionalRow: true) == 3)
    }
}

@Suite("Cohesive practice naming")
struct CohesivePracticeNamingTests {
    @Test func visibleExerciseNamesUseTheApprovedVocabulary() {
        #expect(PracticeMode.timed.displayLabel == "Timed Practice")
        #expect(PracticeMode.suddenDeath.displayLabel == "Pressure Drill")
        #expect(PracticeMode.ahCounter.displayLabel == "Filler Control")
        #expect(PracticeMode.imConversation.displayLabel == "Conversation Practice")
    }

    @Test func renamedLabelsDoNotChangePersistedRawValues() {
        let expected: [(PracticeMode, String)] = [
            (.timed, "timed"),
            (.suddenDeath, "suddenDeath"),
            (.ahCounter, "ahCounter"),
            (.imConversation, "imConversation")
        ]

        for (mode, rawValue) in expected {
            #expect(mode.rawValue == rawValue)
            #expect(PracticeMode(rawValue: rawValue) == mode)
        }
    }

    @Test func presentationGuardRemovesInternalCoachingVocabulary() {
        let line = CoachDisplayCopy.normalized(
            "RULE-BASED Using: the rolling baseline makes fillers the strongest lever across rehearsal shapes."
        ).lowercased()

        #expect(!line.contains("rule-based"))
        #expect(!line.contains("using:"))
        #expect(!line.contains("rolling baseline"))
        #expect(!line.contains("lever"))
        #expect(!line.contains("rehearsal shapes"))
        #expect(!line.contains("focusage"))
        #expect(line.contains("recent reps"))
        #expect(line.contains("focus"))
        #expect(line.contains("practice rounds"))
        #expect(line == "recent reps make fillers the main focus across practice rounds.")
    }

    @Test func recommendationMetadataDescribesTheAcceptedSessionShape() {
        let timed = TrainRecommendationMeta.make(
            mode: .timed,
            prescribedDemand: .timed(difficulty: .hard, speechProjectID: nil)
        )
        let open = TrainRecommendationMeta.make(
            mode: .timed,
            prescribedDemand: .timed(difficulty: .free, speechProjectID: nil)
        )
        let pressure = TrainRecommendationMeta.make(
            mode: .suddenDeath,
            prescribedDemand: nil
        )

        #expect(timed.line == "15 seconds · one clear target")
        #expect(open.line == "Open clock · one clear target")
        #expect(pressure.line == "Pressure rep · one clear target")
        #expect(timed.systemImage == "timer")
        #expect(pressure.systemImage == "bolt.fill")
        #expect(![timed.line, open.line, pressure.line]
            .joined(separator: " ")
            .lowercased()
            .contains("xp"))
    }
}

@Suite("Train practice library")
struct CohesiveTrainLibraryTests {
    @Test func libraryOrderStartsWithExercisesThenKeepsEveryDestinationReachable() {
        #expect(TrainLibraryItem.items.map(\.id) == [
            "chooseExercise",
            "roleplay",
            "lessons",
            "speechProjects",
            "path"
        ])

        #expect(TrainLibraryItem.items.map(\.action) == [
            .expandExercises,
            .destination(.roleplaySetup),
            .destination(.lessons),
            .destination(.speechProjects),
            .destination(.pathJourney)
        ])
    }

    @Test func libraryTitlesUseOneStableNamePerFeature() {
        #expect(TrainLibraryItem.items.map(\.title) == [
            "Choose for myself",
            "Roleplay",
            "Lessons",
            "Speech Projects",
            "Path"
        ])
    }
}
