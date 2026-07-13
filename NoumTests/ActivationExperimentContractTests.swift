import Foundation
import Testing
@testable import Noum

@Suite(.serialized)
struct ActivationExperimentContractTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private var exposureContext: ActivationExperimentExposureContext {
        ActivationExperimentExposureContext(
            microphonePermission: .undetermined,
            speechPermission: .denied,
            locale: .englishUS
        )
    }

    @Test func assignmentRequiresAnExactApprovedExternalToken() {
        let id = UUID()
        let control = ActivationExperimentContract.resolveAssignment(
            configuredValue: ActivationExperimentContract.fullOnboardingToken,
            isEligible: true,
            correlationID: id,
            now: start
        )
        let fastLane = ActivationExperimentContract.resolveAssignment(
            configuredValue: ActivationExperimentContract.fastLaneToken,
            isEligible: true,
            correlationID: id,
            now: start
        )

        #expect(control?.variant == .fullOnboardingControl)
        #expect(fastLane?.variant == .permissionlessFastLane)
        #expect(control?.version == 1)
        #expect(control?.correlationID == id)
        #expect(ActivationExperimentContract.resolveAssignment(
            configuredValue: ActivationExperimentContract.fastLaneToken,
            isEligible: false
        ) == nil)
        #expect(ActivationExperimentContract.resolveAssignment(
            configuredValue: nil,
            isEligible: true
        ) == nil)
        #expect(ActivationExperimentContract.resolveAssignment(
            configuredValue: "enabled",
            isEligible: true
        ) == nil)
        #expect(ActivationExperimentContract.resolveAssignment(
            configuredValue: "first-run-v2:permissionless-fast-lane",
            isEligible: true
        ) == nil)
    }

    @Test func eligibilityExcludesUnhydratedInternalAutomatedAndReturningAccounts() {
        func eligible(
            hydrated: Bool = true,
            developer: Bool = false,
            uiTesting: Bool = false,
            profile: Bool = false,
            draft: Bool = false,
            entered: Bool = false
        ) -> Bool {
            ActivationExperimentContract.isEligibleForNewAssignment(
                hasHydratedAccountStores: hydrated,
                isDeveloper: developer,
                isUITesting: uiTesting,
                hasCoachingProfile: profile,
                hasOnboardingDraft: draft,
                hasEnteredActivation: entered
            )
        }

        #expect(eligible())
        #expect(!eligible(hydrated: false))
        #expect(!eligible(developer: true))
        #expect(!eligible(uiTesting: true))
        #expect(!eligible(profile: true))
        #expect(!eligible(draft: true))
        #expect(!eligible(entered: true))
    }

    @Test func unassignedProductionRouteRemainsTheFastLane() {
        #expect(FirstRunOnboardingGate.rootRoute(
            hasCoachingProfile: false,
            draft: nil,
            activationExperimentVariant: nil,
            isUITesting: false
        ) == .fastLane)
        #expect(FirstRunOnboardingGate.rootRoute(
            hasCoachingProfile: false,
            draft: nil,
            activationExperimentVariant: .permissionlessFastLane,
            isUITesting: false
        ) == .fastLane)
        #expect(FirstRunOnboardingGate.rootRoute(
            hasCoachingProfile: false,
            draft: nil,
            activationExperimentVariant: .fullOnboardingControl,
            isUITesting: false
        ) == .fullOnboarding)
    }

    @MainActor
    @Test func assignmentFreezesAndExposureIsASeparateMatchedEvent() throws {
        let defaults = UserDefaults(suiteName: "experiment.\(UUID().uuidString)")!
        let log = FlowEventLog(defaults: defaults, storageKey: "events")
        let first = try #require(ActivationExperimentContract.resolveAssignment(
            configuredValue: ActivationExperimentContract.fullOnboardingToken,
            isEligible: true,
            correlationID: UUID(),
            now: start
        ))
        let laterConfig = try #require(ActivationExperimentContract.resolveAssignment(
            configuredValue: ActivationExperimentContract.fastLaneToken,
            isEligible: true,
            correlationID: UUID(),
            now: start.addingTimeInterval(5)
        ))

        #expect(log.recordActivationExperimentAssignment(first) == first)
        #expect(log.recordActivationExperimentAssignment(laterConfig) == first)
        #expect(log.events.filter {
            $0.stage == TransformationKPIEventStage.activationExperimentAssigned
        }.count == 1)

        log.recordActivationExperimentExposure(
            assignment: first,
            route: .fastLane,
            context: exposureContext,
            now: start.addingTimeInterval(6)
        )
        #expect(!log.events.contains {
            $0.stage == TransformationKPIEventStage.activationExperimentExposed
        })

        log.recordActivationExperimentExposure(
            assignment: first,
            route: .fullOnboarding,
            context: exposureContext,
            now: start.addingTimeInterval(7)
        )
        log.recordActivationExperimentExposure(
            assignment: first,
            route: .fullOnboarding,
            context: exposureContext,
            now: start.addingTimeInterval(8)
        )

        let exposure = try #require(log.events.first {
            $0.stage == TransformationKPIEventStage.activationExperimentExposed
        })
        #expect(log.events.filter {
            $0.stage == TransformationKPIEventStage.activationExperimentExposed
        }.count == 1)
        #expect(exposure.correlationId == first.correlationID)
        #expect(exposure.numerics["variant"] == ActivationExperimentVariant.fullOnboardingControl.rawValue)
        #expect(exposure.numerics["microphonePermission"] == 0)
        #expect(exposure.numerics["speechPermission"] == 1)
        #expect(exposure.numerics["locale"] == 1)
        #expect(log.events.allSatisfy {
            !$0.reason.contains(ActivationExperimentContract.fullOnboardingToken)
                && !$0.reason.contains(ActivationExperimentContract.fastLaneToken)
        })
    }

    @MainActor
    @Test func assignmentAndExposureSurviveBoundedEventTrimming() throws {
        let defaults = UserDefaults(suiteName: "experiment.trim.\(UUID().uuidString)")!
        let log = FlowEventLog(defaults: defaults, storageKey: "events", maxRecords: 6)
        let assignment = try #require(ActivationExperimentContract.resolveAssignment(
            configuredValue: ActivationExperimentContract.fastLaneToken,
            isEligible: true,
            correlationID: UUID(),
            now: start.addingTimeInterval(1)
        ))

        log.log(FlowEvent.make(
            createdAt: start,
            correlationId: UUID(),
            flow: .other,
            stage: "activation.firstEligible"
        ))
        log.recordActivationExperimentAssignment(assignment)
        log.recordActivationExperimentExposure(
            assignment: assignment,
            route: .fastLane,
            context: exposureContext,
            now: start.addingTimeInterval(2)
        )
        log.log(FlowEvent.make(
            createdAt: start.addingTimeInterval(3),
            correlationId: UUID(),
            flow: .other,
            stage: TransformationKPIEventStage.structuredValueDelivered
        ))
        log.log(FlowEvent.make(
            createdAt: start.addingTimeInterval(4),
            correlationId: UUID(),
            flow: .other,
            stage: "transformation.helpfulness.yes"
        ))
        for index in 5...20 {
            log.log(FlowEvent.make(
                createdAt: start.addingTimeInterval(Double(index)),
                correlationId: UUID(),
                flow: .other,
                stage: "noise.\(index)"
            ))
        }

        #expect(log.events.count == 6)
        #expect(ActivationExperimentContract.persistedAssignment(in: log.events) == assignment)
        #expect(ActivationExperimentContract.attribution(in: log.events)?.exposedVariant == .permissionlessFastLane)
        #expect(log.events.contains { $0.stage == "activation.firstEligible" })
        #expect(log.events.contains { $0.stage == TransformationKPIEventStage.structuredValueDelivered })
        #expect(log.events.contains { $0.stage == "transformation.helpfulness.yes" })
    }

    @Test func attributionRequiresMatchingAssignmentAndExposure() {
        let assignmentID = UUID()
        let assigned = FlowEvent.make(
            createdAt: start,
            correlationId: assignmentID,
            flow: .other,
            stage: TransformationKPIEventStage.activationExperimentAssigned,
            numerics: ["experimentVersion": 1, "variant": 1]
        )
        let mismatchedExposure = FlowEvent.make(
            createdAt: start.addingTimeInterval(1),
            correlationId: assignmentID,
            flow: .other,
            stage: TransformationKPIEventStage.activationExperimentExposed,
            numerics: ["experimentVersion": 1, "variant": 0]
        )
        let orphanExposure = FlowEvent.make(
            createdAt: start.addingTimeInterval(1),
            correlationId: UUID(),
            flow: .other,
            stage: TransformationKPIEventStage.activationExperimentExposed,
            numerics: ["experimentVersion": 1, "variant": 1]
        )
        let matchingExposure = FlowEvent.make(
            createdAt: start.addingTimeInterval(2),
            correlationId: assignmentID,
            flow: .other,
            stage: TransformationKPIEventStage.activationExperimentExposed,
            numerics: ["experimentVersion": 1, "variant": 1]
        )

        #expect(ActivationExperimentContract.attribution(
            in: [assigned, mismatchedExposure, orphanExposure]
        )?.wasExposed == false)
        #expect(ActivationExperimentContract.attribution(
            in: [assigned, matchingExposure]
        )?.exposedVariant == .permissionlessFastLane)
        #expect(ActivationExperimentContract.attribution(
            in: [matchingExposure]
        ) == nil)
    }

    @Test func kpiKeepsTapIntentSeparateFromPersistedSpokenCompletion() {
        let correlationID = UUID()
        let valueAt = start.addingTimeInterval(10)
        let events = [
            FlowEvent.make(
                createdAt: valueAt,
                correlationId: correlationID,
                flow: .other,
                stage: TransformationKPIEventStage.structuredValueDelivered
            ),
            FlowEvent.make(
                createdAt: valueAt.addingTimeInterval(1),
                correlationId: correlationID,
                flow: .other,
                stage: TransformationKPIEventStage.liveUpgradeTapped
            ),
        ]
        let persistedRep = PracticeSession(
            transcript: "Private session content remains outside flow events.",
            fillerWordCount: 0,
            duration: 20,
            date: valueAt.addingTimeInterval(30),
            mode: .timed
        )

        let intentOnly = TransformationKPIReport.derive(
            events: events,
            sessions: [],
            outcomes: []
        )
        let completed = TransformationKPIReport.derive(
            events: events,
            sessions: [persistedRep],
            outcomes: []
        )

        #expect(intentOnly.structuredToSpokenUpgradeIntentRate == 1)
        #expect(intentOnly.structuredToSpokenRepCompleted == false)
        #expect(intentOnly.timeFromStructuredValueToSpokenRepSeconds == nil)
        #expect(completed.structuredToSpokenUpgradeIntentRate == 1)
        #expect(completed.structuredToSpokenRepCompleted == true)
        #expect(completed.timeFromStructuredValueToSpokenRepSeconds == 30)
        #expect(TransformationKPIReport.derive(
            events: [], sessions: [persistedRep], outcomes: []
        ).structuredToSpokenRepCompleted == nil)
    }

    @Test func notificationDecisionCountsOnlyAtOrAfterFirstValue() {
        let valueAt = start.addingTimeInterval(10)
        let base = [
            FlowEvent.make(
                createdAt: start.addingTimeInterval(1),
                correlationId: UUID(),
                flow: .other,
                stage: "notification.authorizationGranted"
            ),
            FlowEvent.make(
                createdAt: valueAt,
                correlationId: UUID(),
                flow: .other,
                stage: TransformationKPIEventStage.structuredValueDelivered
            ),
        ]

        #expect(TransformationKPIReport.derive(
            events: base, sessions: [], outcomes: []
        ).notificationOptInAfterValue == nil)

        let declinedAfterValue = base + [FlowEvent.make(
            createdAt: valueAt.addingTimeInterval(1),
            correlationId: UUID(),
            flow: .other,
            stage: "notification.authorizationDeclined"
        )]
        #expect(TransformationKPIReport.derive(
            events: declinedAfterValue, sessions: [], outcomes: []
        ).notificationOptInAfterValue == false)

        let grantedLater = declinedAfterValue + [FlowEvent.make(
            createdAt: valueAt.addingTimeInterval(2),
            correlationId: UUID(),
            flow: .other,
            stage: "notification.authorizationGranted"
        )]
        #expect(TransformationKPIReport.derive(
            events: grantedLater, sessions: [], outcomes: []
        ).notificationOptInAfterValue == true)
        #expect(TransformationKPIReport.derive(
            events: [base[0]], sessions: [], outcomes: []
        ).notificationOptInAfterValue == nil)
    }
}
