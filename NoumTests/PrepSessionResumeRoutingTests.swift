import Foundation
import Testing
@testable import Noum

@Suite("Prep session resume routing")
struct PrepSessionResumeRoutingTests {
    @Test func supportedPreparationDestinationsKeepExactLaunchConfiguration() throws {
        let momentID = UUID()
        let token = UUID()

        let timed = try #require(PreparationPracticeRoute(
            momentID: momentID,
            destination: .timedPractice(difficulty: .hard)
        ))
        let prompted = try #require(PreparationPracticeRoute(
            momentID: momentID,
            destination: .timedPracticePrompt(token: token, difficulty: .easy)
        ))
        let pressure = try #require(PreparationPracticeRoute(
            momentID: momentID,
            destination: .suddenDeathPractice
        ))
        let conversation = try #require(PreparationPracticeRoute(
            momentID: momentID,
            destination: .imPractice(scenario: .workUpdate, tone: .confident)
        ))

        #expect(timed.exercise == .timed(difficulty: .hard))
        #expect(prompted.exercise == .timedPrompt(token: token, difficulty: .easy))
        #expect(pressure.exercise == .suddenDeath)
        #expect(conversation.exercise == .conversation(scenario: .workUpdate, tone: .confident))
        #expect(timed.momentID == momentID)
    }

    @Test func nonPracticeDestinationCannotAcquirePreparationProvenance() {
        let route = PreparationPracticeRoute(
            momentID: UUID(),
            destination: .settings
        )
        #expect(route == nil)
    }

    @Test func doneResumesOnlyTheSameActiveBigMoment() {
        let momentID = UUID()
        let route = PreparationPracticeRoute(
            momentID: momentID,
            exercise: .suddenDeath
        )
        let origin = SummaryJourneyOrigin.bigMomentPreparation(route)

        #expect(SummaryJourneyExitRouter.disposition(
            origin: origin,
            activeBigMomentID: momentID
        ) == .resumePreparation)
        #expect(SummaryJourneyExitRouter.disposition(
            origin: origin,
            activeBigMomentID: UUID()
        ) == .appSectionRoot)
        #expect(SummaryJourneyExitRouter.disposition(
            origin: origin,
            activeBigMomentID: nil
        ) == .appSectionRoot)
        #expect(SummaryJourneyExitRouter.disposition(
            origin: nil,
            activeBigMomentID: momentID
        ) == .appSectionRoot)
    }

    @MainActor
    @Test func summaryStoreBindsOriginToOnlyThePayloadCreatedWhileRouteIsActive() throws {
        let store = SummaryDataStore.shared
        let route = PreparationPracticeRoute(
            momentID: UUID(),
            exercise: .timed(difficulty: .medium)
        )
        let origin = SummaryJourneyOrigin.bigMomentPreparation(route)
        let preparationPayloadID = UUID()
        let ordinaryPayloadID = UUID()
        let entry = makeEntry()

        store.activateJourneyOrigin(origin)
        store.store(entry, for: preparationPayloadID)
        store.deactivateJourneyOrigin(origin)
        store.store(entry, for: ordinaryPayloadID)

        #expect(store.journeyOrigin(for: preparationPayloadID) == origin)
        #expect(store.journeyOrigin(for: ordinaryPayloadID) == nil)

        store.remove(for: preparationPayloadID)
        store.remove(for: ordinaryPayloadID)
        #expect(store.journeyOrigin(for: preparationPayloadID) == nil)
    }

    @MainActor
    private func makeEntry() -> SummaryDataStore.Entry {
        SummaryDataStore.Entry(
            transcript: AttributedString("A complete preparation answer."),
            fillerCount: 0,
            duration: 30,
            score: 7,
            progressSegments: 0,
            xpEarned: 0,
            finalizedSessionID: UUID(),
            committedFinalization: nil,
            suddenDeathGamePoints: nil,
            suddenDeathMultiplierLabels: [],
            suddenDeathTotalWords: nil,
            showDuration: true,
            practiceTitle: "Timed Practice",
            feedbackOverride: nil,
            headlineOverride: nil,
            scoreBreakdown: [],
            insights: [],
            recentSessions: [],
            imConversationDetails: nil,
            explicitMode: .timed,
            recordingURL: nil,
            sessionPrompt: nil,
            sessionTheme: nil,
            feedbackCategories: [],
            strongMoments: [],
            weakMoments: [],
            durationAssessment: .onTarget,
            targetRange: (30, 60, 120),
            onStartDrill: nil
        )
    }
}
