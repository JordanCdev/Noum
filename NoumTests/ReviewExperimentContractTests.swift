import Foundation
import Testing
@testable import Noum

@Suite(.serialized)
struct ReviewExperimentContractTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)
    private let exposureContext = ActivationExperimentExposureContext(
        microphonePermission: .granted,
        speechPermission: .denied,
        locale: .spanishES
    )

    @Test func assignmentRequiresAnExactVersionedExternalToken() {
        let id = UUID()
        let control = ReviewExperimentContract.resolveAssignment(
            configuredValue: ReviewExperimentContract.genericReviewToken,
            isEligible: true,
            correlationID: id,
            now: start
        )
        let treatment = ReviewExperimentContract.resolveAssignment(
            configuredValue: ReviewExperimentContract.outcomeLoopToken,
            isEligible: true,
            correlationID: id,
            now: start
        )

        #expect(control?.variant == .genericReviewControl)
        #expect(treatment?.variant == .goalOutcomeAdaptivePrescription)
        #expect(control?.version == 1)
        #expect(control?.correlationID == id)
        #expect(ReviewExperimentContract.resolveAssignment(
            configuredValue: ReviewExperimentContract.genericReviewToken,
            isEligible: false
        ) == nil)
        #expect(ReviewExperimentContract.resolveAssignment(
            configuredValue: nil,
            isEligible: true
        ) == nil)
        #expect(ReviewExperimentContract.resolveAssignment(
            configuredValue: "",
            isEligible: true
        ) == nil)
        #expect(ReviewExperimentContract.resolveAssignment(
            configuredValue: "enabled",
            isEligible: true
        ) == nil)
        #expect(ReviewExperimentContract.resolveAssignment(
            configuredValue: "review-outcome-v2:generic-review",
            isEligible: true
        ) == nil)
    }

    @Test func eligibilityExcludesUnhydratedInternalAutomatedAndPreviouslyExposedAccounts() {
        func eligible(
            hydrated: Bool = true,
            developer: Bool = false,
            uiTesting: Bool = false,
            priorReview: Bool = false
        ) -> Bool {
            ReviewExperimentContract.isEligibleForNewAssignment(
                hasHydratedAccountStores: hydrated,
                isDeveloper: developer,
                isUITesting: uiTesting,
                hasPriorReviewExposure: priorReview
            )
        }

        #expect(eligible())
        #expect(!eligible(hydrated: false))
        #expect(!eligible(developer: true))
        #expect(!eligible(uiTesting: true))
        #expect(!eligible(priorReview: true))
    }

    @Test func durableRepOrReviewMarkerPreventsLateEnrollment() {
        let realRep = session(at: start)
        let fixture = session(at: start, fixture: true)
        let reviewMarker = FlowEvent.make(
            createdAt: start,
            correlationId: UUID(),
            flow: .other,
            stage: TransformationKPIEventStage.reviewSurfaceOpened
        )

        #expect(!ReviewExperimentContract.hasPriorReviewExposure(
            events: [],
            sessions: []
        ))
        #expect(!ReviewExperimentContract.hasPriorReviewExposure(
            events: [],
            sessions: [fixture]
        ))
        #expect(ReviewExperimentContract.hasPriorReviewExposure(
            events: [],
            sessions: [realRep]
        ))
        #expect(ReviewExperimentContract.hasPriorReviewExposure(
            events: [reviewMarker],
            sessions: []
        ))
    }

    @Test func unassignedPresentationPreservesTheShippingOutcomeLoop() {
        #expect(ReviewExperimentContract.presentation(in: []) == .outcomeLoop)
        #expect(ReviewExperimentContract.presentation(in: []).showsGoalOutcome)
        #expect(ReviewExperimentContract.presentation(in: []).recordsAdaptivePrescription)
    }

    @MainActor
    @Test func firstAssignmentFreezesAndOnlyMatchingPresentationCountsAsExposure() throws {
        let defaults = UserDefaults(suiteName: "review.experiment.\(UUID().uuidString)")!
        let log = FlowEventLog(defaults: defaults, storageKey: "events")
        let first = try #require(ReviewExperimentContract.resolveAssignment(
            configuredValue: ReviewExperimentContract.genericReviewToken,
            isEligible: true,
            correlationID: UUID(),
            now: start
        ))
        let later = try #require(ReviewExperimentContract.resolveAssignment(
            configuredValue: ReviewExperimentContract.outcomeLoopToken,
            isEligible: true,
            correlationID: UUID(),
            now: start.addingTimeInterval(1)
        ))

        #expect(log.recordReviewExperimentAssignment(first) == first)
        #expect(log.recordReviewExperimentAssignment(later) == first)
        #expect(log.events.filter {
            $0.stage == TransformationKPIEventStage.reviewExperimentAssigned
        }.count == 1)

        log.recordReviewExperimentExposure(
            assignment: first,
            presentation: .outcomeLoop,
            context: exposureContext,
            now: start.addingTimeInterval(2)
        )
        #expect(!log.events.contains {
            $0.stage == TransformationKPIEventStage.reviewExperimentExposed
        })

        log.recordReviewExperimentExposure(
            assignment: first,
            presentation: .genericReview,
            context: exposureContext,
            now: start.addingTimeInterval(3)
        )
        log.recordReviewExperimentExposure(
            assignment: first,
            presentation: .genericReview,
            context: ActivationExperimentExposureContext(
                microphonePermission: .denied,
                speechPermission: .granted,
                locale: .frenchFR
            ),
            now: start.addingTimeInterval(4)
        )

        let exposure = try #require(log.events.first {
            $0.stage == TransformationKPIEventStage.reviewExperimentExposed
        })
        #expect(log.events.filter {
            $0.stage == TransformationKPIEventStage.reviewExperimentExposed
        }.count == 1)
        #expect(exposure.correlationId == first.correlationID)
        #expect(exposure.numerics["variant"] == ReviewExperimentVariant.genericReviewControl.rawValue)
        #expect(ActivationExperimentExposureContext(numerics: exposure.numerics) == exposureContext)
        #expect(log.events.allSatisfy {
            !$0.reason.contains(ReviewExperimentContract.genericReviewToken)
                && !$0.reason.contains(ReviewExperimentContract.outcomeLoopToken)
        })
    }

    @Test func conversionRequiresMatchedExposureThenALaterPersistedNonfixtureRep() throws {
        let assignment = try #require(ReviewExperimentContract.resolveAssignment(
            configuredValue: ReviewExperimentContract.outcomeLoopToken,
            isEligible: true,
            correlationID: UUID(),
            now: start
        ))
        let assigned = assignmentEvent(assignment)
        let exposedAt = start.addingTimeInterval(10)
        let exposure = exposureEvent(assignment, at: exposedAt)

        let sourceRep = session(at: start.addingTimeInterval(5))
        let sameMoment = session(at: exposedAt)
        let laterFixture = session(at: exposedAt.addingTimeInterval(10), fixture: true)
        let nextRealRep = session(at: exposedAt.addingTimeInterval(30))

        let assignmentOnly = ReviewExperimentContract.attribution(
            in: [assigned],
            sessions: [nextRealRep]
        )
        let exposed = ReviewExperimentContract.attribution(
            in: [assigned, exposure],
            sessions: [sourceRep, sameMoment, laterFixture, nextRealRep]
        )

        #expect(assignmentOnly?.wasExposed == false)
        #expect(assignmentOnly?.completedNextRep == false)
        #expect(exposed?.exposedVariant == .goalOutcomeAdaptivePrescription)
        #expect(exposed?.exposureContext == exposureContext)
        #expect(exposed?.completedNextRep == true)
        #expect(exposed?.completedNextRepAt == nextRealRep.date)
        #expect(exposed?.timeToCompletedNextRepSeconds == 30)
    }

    @Test func mismatchedOrOrphanExposureCannotCreateConversion() throws {
        let assignment = try #require(ReviewExperimentContract.resolveAssignment(
            configuredValue: ReviewExperimentContract.genericReviewToken,
            isEligible: true,
            correlationID: UUID(),
            now: start
        ))
        let mismatched = FlowEvent.make(
            createdAt: start.addingTimeInterval(1),
            correlationId: assignment.correlationID,
            flow: .other,
            stage: TransformationKPIEventStage.reviewExperimentExposed,
            numerics: ["experimentVersion": 1, "variant": 1]
        )
        let orphan = FlowEvent.make(
            createdAt: start.addingTimeInterval(1),
            correlationId: UUID(),
            flow: .other,
            stage: TransformationKPIEventStage.reviewExperimentExposed,
            numerics: ["experimentVersion": 1, "variant": 0]
        )
        let matchingWithoutSegmentationContext = FlowEvent.make(
            createdAt: start.addingTimeInterval(2),
            correlationId: assignment.correlationID,
            flow: .other,
            stage: TransformationKPIEventStage.reviewExperimentExposed,
            numerics: ["experimentVersion": 1, "variant": 0]
        )

        let attribution = ReviewExperimentContract.attribution(
            in: [
                assignmentEvent(assignment),
                mismatched,
                orphan,
                matchingWithoutSegmentationContext,
            ],
            sessions: [session(at: start.addingTimeInterval(30))]
        )

        #expect(attribution?.wasExposed == false)
        #expect(attribution?.completedNextRep == false)
        #expect(attribution?.timeToCompletedNextRepSeconds == nil)
    }

    @MainActor
    @Test func assignmentExposureAndReviewMarkerSurviveBoundedTrimming() throws {
        let defaults = UserDefaults(suiteName: "review.experiment.trim.\(UUID().uuidString)")!
        let log = FlowEventLog(defaults: defaults, storageKey: "events", maxRecords: 4)
        let assignment = try #require(ReviewExperimentContract.resolveAssignment(
            configuredValue: ReviewExperimentContract.genericReviewToken,
            isEligible: true,
            correlationID: UUID(),
            now: start
        ))

        log.recordReviewExperimentAssignment(assignment)
        log.recordReviewExperimentExposure(
            assignment: assignment,
            presentation: .genericReview,
            context: exposureContext,
            now: start.addingTimeInterval(1)
        )
        log.recordReviewSurfaceOpened(now: start.addingTimeInterval(2))
        for index in 3...20 {
            log.log(FlowEvent.make(
                createdAt: start.addingTimeInterval(Double(index)),
                correlationId: UUID(),
                flow: .other,
                stage: "noise.\(index)"
            ))
        }

        #expect(log.events.count == 4)
        #expect(ReviewExperimentContract.persistedAssignment(in: log.events) == assignment)
        #expect(ReviewExperimentContract.attribution(
            in: log.events,
            sessions: []
        )?.wasExposed == true)
        #expect(log.events.contains {
            $0.stage == TransformationKPIEventStage.reviewSurfaceOpened
        })
    }

    @Test func kpiCarriesAccountLocalReviewAttributionWithoutCountingATap() throws {
        let assignment = try #require(ReviewExperimentContract.resolveAssignment(
            configuredValue: ReviewExperimentContract.outcomeLoopToken,
            isEligible: true,
            correlationID: UUID(),
            now: start
        ))
        let exposure = exposureEvent(assignment, at: start.addingTimeInterval(10))
        let report = TransformationKPIReport.derive(
            events: [assignmentEvent(assignment), exposure],
            sessions: [session(at: start.addingTimeInterval(50))],
            outcomes: []
        )

        #expect(report.reviewExperimentAttribution?.wasExposed == true)
        #expect(report.reviewExperimentAttribution?.exposureContext == exposureContext)
        #expect(report.reviewExperimentAttribution?.completedNextRep == true)
        #expect(report.reviewExperimentAttribution?.timeToCompletedNextRepSeconds == 40)
    }

    @Test func genericControlIsNeutralReplayWithRestrainedCopy() {
        let timed = SummaryGenericReviewActionPresentation.make(for: .timed)
        let im = SummaryGenericReviewActionPresentation.make(for: .imConversation)

        #expect(timed.title == "Repeat this rep")
        #expect(timed.supportingCopy.contains(PracticeMode.timed.displayLabel))
        #expect(im.supportingCopy.contains("same scenario and target tone"))
        #expect(!timed.recordsAdaptivePrescriptionAcceptance)
        #expect(!timed.accessibilityLabel.contains("!"))
        #expect(!timed.accessibilityLabel.lowercased().contains("amazing"))
        #expect(!timed.accessibilityLabel.lowercased().contains("let's"))
    }

    private func assignmentEvent(_ assignment: ReviewExperimentAssignment) -> FlowEvent {
        FlowEvent.make(
            createdAt: assignment.assignedAt,
            correlationId: assignment.correlationID,
            flow: .other,
            stage: TransformationKPIEventStage.reviewExperimentAssigned,
            numerics: [
                "experimentVersion": assignment.version,
                "variant": assignment.variant.rawValue,
            ]
        )
    }

    private func exposureEvent(
        _ assignment: ReviewExperimentAssignment,
        at date: Date
    ) -> FlowEvent {
        var numerics = exposureContext.numerics
        numerics["experimentVersion"] = assignment.version
        numerics["variant"] = assignment.variant.rawValue
        return FlowEvent.make(
            createdAt: date,
            correlationId: assignment.correlationID,
            flow: .other,
            stage: TransformationKPIEventStage.reviewExperimentExposed,
            numerics: numerics
        )
    }

    private func session(at date: Date, fixture: Bool = false) -> PracticeSession {
        PracticeSession(
            transcript: "Private speech content remains in the session store.",
            fillerWordCount: 0,
            duration: 20,
            date: date,
            mode: .timed,
            isEvaluationFixture: fixture,
            fixtureID: fixture ? "review-fixture" : nil
        )
    }
}
