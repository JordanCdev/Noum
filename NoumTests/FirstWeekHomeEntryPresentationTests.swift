import Foundation
import Testing
@testable import Noum

@Suite("First-week Home entry presentation")
struct FirstWeekHomeEntryPresentationTests {
    private let accountID = "private-first-week-account"

    @Test("Days 0 through 6 expose one calm action with the contract route")
    func unfinishedStepsUseContractCopyAndRoutes() throws {
        let cases: [(
            action: FirstWeekCoachingContract.NextAction,
            intent: FirstWeekCoachingContract.NotificationIntent,
            route: String
        )] = [
            (
                .recordSpokenBaseline,
                .recordSpokenBaseline,
                "noum://home/first-week-spoken-proof"
            ),
            (
                .repeatRep(mode: .timed),
                .repeatRep,
                "noum://home/first-week-action"
            ),
            (
                .compareAndAdapt(lever: .structure, mode: .suddenDeath),
                .compareAndAdapt,
                "noum://home/first-week-action"
            ),
            (
                .realWorldCheckIn,
                .realWorldCheckIn,
                "noum://profile/check-in"
            ),
        ]

        for item in cases {
            let snapshot = snapshot(action: item.action, intent: item.intent)
            let presentation = try #require(
                FirstWeekHomeEntryPresentation.make(snapshot: snapshot)
            )
            let line = NotificationCopy.firstWeek(intent: item.intent)

            #expect(presentation.style == .nextStep)
            #expect(presentation.title == line.title)
            #expect(presentation.body == line.body)
            #expect(presentation.route.absoluteString == item.route)
            #expect(
                presentation.accessibilityIdentifier
                    == item.action.accessibilityIdentifier
            )
            #expect(!presentation.accessibilityHint.isEmpty)
            #expect(!presentation.title.contains(accountID))
            #expect(!presentation.body.contains(accountID))
            #expect(!presentation.route.absoluteString.contains(accountID))
        }
    }

    @Test("Day 7 preserves the durable read copy and Home route")
    func durableReadPresentation() throws {
        let read = FirstWeekCoachingContract.FirstWeekReadProjection(
            whatChanged: .notYetProven(eligibleRepCount: 2),
            remainsUnproven: [.practiceChange, .realWorldOutcome, .durability],
            verifiedExample: nil,
            nextWeekPlan: .init(
                lever: .structure,
                mode: .timed,
                remainingComparableRepsBeforeReview: 1,
                recommendedAction: .repeatRep(mode: .timed)
            )
        )
        let presentation = try #require(
            FirstWeekHomeEntryPresentation.make(
                snapshot: snapshot(
                    action: .reviewFirstWeekRead,
                    intent: .firstWeekRead,
                    firstWeekRead: read
                )
            )
        )

        #expect(presentation.style == .durableRead)
        #expect(presentation.title == "Your first-week read")
        #expect(
            presentation.body
                == "See what Noum can support and what still needs evidence."
        )
        #expect(presentation.route.absoluteString == "noum://home/first-week-read")
        #expect(presentation.accessibilityIdentifier == "home.firstWeekRead.open")
        #expect(
            presentation.accessibilityHint
                == "Opens your durable first-week coaching read"
        )
    }

    @Test("A malformed read snapshot fails closed")
    func missingReadDoesNotRender() {
        let presentation = FirstWeekHomeEntryPresentation.make(
            snapshot: snapshot(
                action: .reviewFirstWeekRead,
                intent: .firstWeekRead
            )
        )

        #expect(presentation == nil)
    }

    @Test("An acknowledged Day-seven read releases Home's support slot")
    func viewedReadDoesNotStayPinnedToHome() throws {
        let correlationID = try #require(activation.correlationID)
        let readSnapshot = snapshot(
            action: .reviewFirstWeekRead,
            intent: .firstWeekRead,
            firstWeekRead: .init(
                whatChanged: .notYetProven(eligibleRepCount: 2),
                remainsUnproven: [.practiceChange],
                verifiedExample: nil,
                nextWeekPlan: .init(
                    lever: nil,
                    mode: .timed,
                    remainingComparableRepsBeforeReview: 1,
                    recommendedAction: .repeatRep(mode: .timed)
                )
            )
        )
        let viewed = GrowthEvent(
            correlationID: correlationID,
            name: .weeklyReadViewed,
            entryPoint: .home
        )

        #expect(FirstWeekHomeEntryAvailability.shouldPresent(
            snapshot: readSnapshot,
            growthEvents: []
        ))
        #expect(!FirstWeekHomeEntryAvailability.shouldPresent(
            snapshot: readSnapshot,
            growthEvents: [viewed]
        ))
        #expect(FirstWeekHomeEntryAvailability.shouldPresent(
            snapshot: readSnapshot,
            growthEvents: [GrowthEvent(
                correlationID: UUID(),
                name: .weeklyReadViewed,
                entryPoint: .home
            )]
        ))

        let nextStep = snapshot(
            action: .repeatRep(mode: .timed),
            intent: .repeatRep
        )
        #expect(FirstWeekHomeEntryAvailability.shouldPresent(
            snapshot: nextStep,
            growthEvents: [viewed]
        ))
    }

    private func snapshot(
        action: FirstWeekCoachingContract.NextAction,
        intent: FirstWeekCoachingContract.NotificationIntent,
        firstWeekRead: FirstWeekCoachingContract.FirstWeekReadProjection? = nil
    ) -> FirstWeekCoachingContract.Snapshot {
        let stageAndDay: (FirstWeekCoachingContract.Stage, Int) = switch action {
        case .recordSpokenBaseline: (.day0Baseline, 0)
        case .repeatRep: (.day1To2Repeat, 1)
        case .compareAndAdapt: (.day3To4CompareAndAdapt, 3)
        case .realWorldCheckIn: (.day5To6RealWorldCheckIn, 5)
        case .reviewFirstWeekRead: (.day7FirstWeekRead, 7)
        }

        return FirstWeekCoachingContract.Snapshot(
            accountID: accountID,
            activation: activation,
            day: stageAndDay.1,
            stage: stageAndDay.0,
            eligibleSessionCount: 0,
            currentLever: nil,
            prescription: nil,
            hasRealWorldCheckIn: false,
            firstWeekRead: firstWeekRead,
            nextAction: action,
            notificationIntent: intent
        )
    }

    private var activation: FirstWeekCoachingContract.ActivationReceipt {
        let completedAt = Date(timeIntervalSince1970: 1_767_225_600)
        let draft = CoachingProfileDraft(
            correlationID: UUID(
                uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"
            )!,
            speakingContext: .work,
            speakingChallenge: .rambling,
            createdAt: completedAt.addingTimeInterval(-60),
            firstValueReceipt: .structured(
                metadata: StructuredFirstValueMetadata(
                    promptID: StructuredFirstValueCatalog.prompt(for: .work).id,
                    wordCount: 18
                ),
                completedAt: completedAt
            )
        )
        return FirstWeekCoachingContract.ActivationReceipt(
            accountID: accountID,
            draft: draft
        )!
    }
}
