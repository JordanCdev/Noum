import Testing
@testable import Noum

@Suite("Cohesive supporting surfaces")
struct CohesiveSupportingSurfaceTests {
    @Test func weeklyCheckInUsesPlainSelfReportedLanguage() {
        let copy = [
            WeeklyCheckInCopy.sheetBody,
            WeeklyCheckInCopy.noteTitle,
            WeeklyCheckInCopy.noteBody,
            WeeklyCheckInCopy.confidenceHelper,
            WeeklyCheckInCopy.drillHelper
        ].joined(separator: " ").lowercased()

        #expect(copy.contains("your words"))
        #expect(copy.contains("your own read"))
        #expect(!copy.contains("diagnosis"))
        #expect(!copy.contains("proof that"))
        #expect(!copy.contains("performance review"))
    }

    @Test func emptyPathOffersOneHonestFirstAction() {
        let presentation = PathJourneyPresentation.make(
            completedCount: 0,
            currentProgress: nil,
            totalCount: 0,
            currentTitle: nil,
            currentDetail: nil,
            currentGatingPhrase: nil,
            currentStreak: 0,
            sessionCount: 0
        )

        #expect(presentation.homeGoalShortLabel == "Start")
        #expect(presentation.explanationLine == "Start with one rep.")
        #expect(presentation.previewLine.contains("real signal"))
        #expect(!presentation.summaryLine.lowercased().contains("streak"))
    }

    @Test func supportingCopyAvoidsInternalCoachingJargon() {
        let copy = [
            WeeklyCheckInCopy.cardTitle,
            WeeklyCheckInCopy.cardBody,
            WeeklyCheckInCopy.sheetTitle,
            WeeklyCheckInCopy.sheetBody,
            WeeklyCheckInCopy.noteTitle,
            WeeklyCheckInCopy.noteBody,
            WeeklyCheckInCopy.drillHelper
        ].joined(separator: " ").lowercased()

        for bannedPhrase in ["lever", "rolling baseline", "rehearsal shapes", "established read", "rule-based"] {
            #expect(!copy.contains(bannedPhrase))
        }
    }
}
