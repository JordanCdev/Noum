import Foundation
import Testing
@testable import Noum

@Suite("Privacy-bounded transformation KPIs")
struct TransformationKPIReportTests {
    @Test func derivesActivationRetentionAndAcceptanceWithoutTranscriptData() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let day1 = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start))!
        let prescriptionID = UUID()
        let transcriptionID = UUID()
        let events = [
            FlowEvent.make(createdAt: start, correlationId: UUID(), flow: .other, stage: "activation.firstEligible"),
            FlowEvent.make(createdAt: start, correlationId: UUID(), flow: .other, stage: "retention.appActive"),
            FlowEvent.make(createdAt: day1, correlationId: UUID(), flow: .other, stage: "retention.appActive"),
            FlowEvent.make(createdAt: start.addingTimeInterval(120), correlationId: UUID(), flow: .other, stage: "review.sessionOpened"),
            FlowEvent.make(createdAt: start.addingTimeInterval(121), correlationId: UUID(), flow: .other, stage: "coach.typedOpened"),
            FlowEvent.make(createdAt: start.addingTimeInterval(122), correlationId: UUID(), flow: .other, stage: "coach.typedToLive"),
            FlowEvent.make(createdAt: start.addingTimeInterval(123), correlationId: UUID(), flow: .other, stage: "notification.authorizationGranted"),
            FlowEvent.make(createdAt: start.addingTimeInterval(124), correlationId: prescriptionID, flow: .other, stage: TransformationKPIEventStage.prescriptionShown),
            FlowEvent.make(createdAt: start.addingTimeInterval(125), correlationId: prescriptionID, flow: .other, stage: TransformationKPIEventStage.prescriptionAccepted),
            FlowEvent.make(createdAt: start.addingTimeInterval(126), correlationId: transcriptionID, flow: .practiceRep, stage: TransformationKPIEventStage.cloudTranscriptionResolvedLocal)
        ]
        let session = PracticeSession(
            transcript: "A private transcript that must never enter KPI events.",
            fillerWordCount: 0,
            duration: 30,
            date: start.addingTimeInterval(45),
            mode: .timed,
            transcriptionProvider: "local"
        )
        let outcome = RecommendationOutcome(
            id: UUID(), fingerprint: "one", title: "Practice", focus: nil,
            target: nil, mode: .timed, sessionID: session.id, followed: true,
            completedAt: start.addingTimeInterval(45), scoreDelta: 0,
            hasComparableScore: false, fillerDelta: 0, durationDelta: 0,
            fillerRateDelta: 0, comparisonSessionCount: 3,
            goal: .concise, targetDimensionID: "clean_close",
            goalFollowUpResult: .earlyImprovement
        )
        let report = TransformationKPIReport.derive(
            events: events,
            sessions: [session],
            outcomes: [outcome],
            now: day1.addingTimeInterval(60),
            calendar: calendar
        )
        #expect(report.firstRepCompleted)
        #expect(report.timeToFirstRepSeconds == 45)
        #expect(report.firstValueCompleted)
        #expect(report.timeToFirstValueSeconds == 45)
        #expect(!report.firstStructuredValueCompleted)
        #expect(report.reviewOpenRate == 1)
        #expect(report.prescriptionAcceptanceRate == 1)
        #expect(report.cloudToLocalFallbackRate == 1)
        #expect(report.typedToLiveUpgradeRate == 1)
        #expect(report.goalImprovementRate7Days == 1)
        #expect(report.goalImprovementRate28Days == 1)
        #expect(report.notificationOptInAfterValue == true)
        #expect(report.retainedDay1 == true)
        #expect(events.allSatisfy { !$0.reason.contains("private transcript") })
    }

    @Test func structuredOnlyCompletionIsFirstValueButNotSpokenRep() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let events = [
            FlowEvent.make(
                createdAt: start,
                correlationId: UUID(),
                flow: .other,
                stage: "activation.firstEligible"
            ),
            FlowEvent.make(
                createdAt: start.addingTimeInterval(32),
                correlationId: UUID(),
                flow: .other,
                stage: TransformationKPIEventStage.structuredValueDelivered,
                reason: "structured value delivered",
                numerics: ["wordCount": 18]
            ),
        ]

        let report = TransformationKPIReport.derive(
            events: events,
            sessions: [],
            outcomes: []
        )

        #expect(!report.firstRepCompleted)
        #expect(report.timeToFirstRepSeconds == nil)
        #expect(report.firstValueCompleted)
        #expect(report.timeToFirstValueSeconds == 32)
        #expect(report.firstStructuredValueCompleted)
    }

    @Test func spokenOnlyCompletionPreservesRepAndFirstValueSemantics() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = PracticeSession(
            transcript: "Private speech evidence remains in the session store only.",
            fillerWordCount: 0,
            duration: 20,
            date: start.addingTimeInterval(41),
            mode: .timed
        )
        let report = TransformationKPIReport.derive(
            events: [
                FlowEvent.make(
                    createdAt: start,
                    correlationId: UUID(),
                    flow: .other,
                    stage: "activation.firstEligible"
                )
            ],
            sessions: [session],
            outcomes: []
        )

        #expect(report.firstRepCompleted)
        #expect(report.timeToFirstRepSeconds == 41)
        #expect(report.firstValueCompleted)
        #expect(report.timeToFirstValueSeconds == 41)
        #expect(!report.firstStructuredValueCompleted)
    }

    @Test func firstValueUsesEarlierOfStructuredAndSpokenRegardlessOfOrdering() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let eligible = FlowEvent.make(
            createdAt: start,
            correlationId: UUID(),
            flow: .other,
            stage: "activation.firstEligible"
        )
        func structured(at offset: TimeInterval) -> FlowEvent {
            FlowEvent.make(
                createdAt: start.addingTimeInterval(offset),
                correlationId: UUID(),
                flow: .other,
                stage: TransformationKPIEventStage.structuredValueDelivered,
                reason: "structured value delivered"
            )
        }
        func session(at offset: TimeInterval) -> PracticeSession {
            PracticeSession(
                transcript: "Private spoken response.",
                fillerWordCount: 0,
                duration: 20,
                date: start.addingTimeInterval(offset),
                mode: .timed
            )
        }

        let structuredFirst = TransformationKPIReport.derive(
            events: [eligible, structured(at: 20)],
            sessions: [session(at: 50)],
            outcomes: []
        )
        let spokenFirst = TransformationKPIReport.derive(
            events: [eligible, structured(at: 50)],
            sessions: [session(at: 20)],
            outcomes: []
        )

        #expect(structuredFirst.timeToFirstValueSeconds == 20)
        #expect(structuredFirst.timeToFirstRepSeconds == 50)
        #expect(structuredFirst.firstStructuredValueCompleted)
        #expect(spokenFirst.timeToFirstValueSeconds == 20)
        #expect(spokenFirst.timeToFirstRepSeconds == 20)
        #expect(spokenFirst.firstStructuredValueCompleted)
    }

    @Test func noStructuredEventOrSessionLeavesFirstValuePending() {
        let report = TransformationKPIReport.derive(
            events: [
                FlowEvent.make(
                    correlationId: UUID(),
                    flow: .other,
                    stage: TransformationKPIEventStage.structuredStarted,
                    reason: "structured exercise opened"
                )
            ],
            sessions: [],
            outcomes: []
        )

        #expect(!report.firstRepCompleted)
        #expect(report.timeToFirstRepSeconds == nil)
        #expect(!report.firstValueCompleted)
        #expect(report.timeToFirstValueSeconds == nil)
        #expect(!report.firstStructuredValueCompleted)
    }

    @Test func prescriptionAcceptanceUsesDistinctShownToTapPairs() {
        let accepted = UUID()
        let ignored = UUID()
        let unpairedTap = UUID()
        let events = [
            FlowEvent.make(correlationId: accepted, flow: .other, stage: TransformationKPIEventStage.prescriptionShown),
            FlowEvent.make(correlationId: accepted, flow: .other, stage: TransformationKPIEventStage.prescriptionAccepted),
            FlowEvent.make(correlationId: accepted, flow: .other, stage: TransformationKPIEventStage.prescriptionAccepted),
            FlowEvent.make(correlationId: ignored, flow: .other, stage: TransformationKPIEventStage.prescriptionShown),
            FlowEvent.make(correlationId: unpairedTap, flow: .other, stage: TransformationKPIEventStage.prescriptionAccepted),
        ]
        let completedWithoutAcceptance = RecommendationOutcome(
            id: UUID(), fingerprint: "completed", title: "Practice", focus: nil,
            target: nil, mode: .timed, sessionID: UUID(), followed: true,
            completedAt: Date(), scoreDelta: 0, hasComparableScore: false,
            fillerDelta: 0, durationDelta: 0
        )

        let report = TransformationKPIReport.derive(
            events: events,
            sessions: [],
            outcomes: [completedWithoutAcceptance]
        )

        #expect(report.prescriptionAcceptanceRate == 0.5)
    }

    @Test func prescriptionAcceptanceHasNoDenominatorForOutcomeOrUnpairedTap() {
        let report = TransformationKPIReport.derive(
            events: [
                FlowEvent.make(correlationId: UUID(), flow: .other, stage: TransformationKPIEventStage.prescriptionAccepted)
            ],
            sessions: [],
            outcomes: []
        )

        #expect(report.prescriptionAcceptanceRate == nil)
    }

    @Test func fallbackRateUsesOnlyCloudRequestedRoutes() {
        let events = [
            FlowEvent.make(correlationId: UUID(), flow: .practiceRep, stage: TransformationKPIEventStage.cloudTranscriptionResolvedLocal),
            FlowEvent.make(correlationId: UUID(), flow: .practiceRep, stage: TransformationKPIEventStage.cloudTranscriptionResolvedCloud),
            FlowEvent.make(correlationId: UUID(), flow: .practiceRep, stage: TransformationKPIEventStage.localTranscriptionResolvedLocal),
        ]
        let deliberateLocalSession = PracticeSession(
            transcript: "Deliberately on device.", fillerWordCount: 0,
            duration: 20, date: Date(), mode: .timed, transcriptionProvider: "local"
        )

        let report = TransformationKPIReport.derive(
            events: events,
            sessions: [deliberateLocalSession],
            outcomes: []
        )

        #expect(report.cloudToLocalFallbackRate == 0.5)
    }

    @Test func deliberateLocalOnlySessionsDoNotCreateFallbackDenominator() {
        let localRoute = FlowEvent.make(
            correlationId: UUID(), flow: .practiceRep,
            stage: TransformationKPIEventStage.localTranscriptionResolvedLocal
        )
        let localSession = PracticeSession(
            transcript: "Private local practice.", fillerWordCount: 0,
            duration: 20, date: Date(), mode: .timed, transcriptionProvider: "local"
        )

        let report = TransformationKPIReport.derive(
            events: [localRoute],
            sessions: [localSession],
            outcomes: []
        )

        #expect(report.cloudToLocalFallbackRate == nil)
    }

    @MainActor
    @Test func boundedInstrumentationEmitsPairablePrescriptionAndRouteStages() {
        let defaults = UserDefaults(suiteName: "kpi.\(UUID().uuidString)")!
        let log = FlowEventLog(defaults: defaults, storageKey: "events")
        let prescriptionID = UUID()
        let cloudFallbackID = UUID()
        let localOnlyID = UUID()

        log.recordPrescriptionShown(correlationId: prescriptionID)
        log.recordPrescriptionShown(correlationId: prescriptionID)
        log.recordPrescriptionAccepted(correlationId: prescriptionID)
        log.recordPrescriptionAccepted(correlationId: prescriptionID)
        log.recordTranscriptionRoute(
            correlationId: cloudFallbackID,
            requestedCloud: true,
            resolvedProviderIdentifier: TranscriptionProviderID.local.rawValue
        )
        log.recordTranscriptionRoute(
            correlationId: localOnlyID,
            requestedCloud: false,
            resolvedProviderIdentifier: TranscriptionProviderID.local.rawValue
        )

        #expect(log.events.filter { $0.correlationId == prescriptionID }.count == 2)
        #expect(log.events.contains {
            $0.correlationId == cloudFallbackID
                && $0.stage == TransformationKPIEventStage.cloudTranscriptionResolvedLocal
        })
        #expect(log.events.contains {
            $0.correlationId == localOnlyID
                && $0.stage == TransformationKPIEventStage.localTranscriptionResolvedLocal
        })
        #expect(log.events.allSatisfy { $0.reason.count <= 256 && $0.numerics.isEmpty })
    }

    @Test func preInstrumentationRecommendationExposureStillDecodes() throws {
        let legacyExposure = RecommendationExposure(
            fingerprint: "legacy",
            title: "Practice",
            focus: "Clear close",
            target: "One final sentence",
            mode: .timed,
            isAIBacked: false,
            shownAt: Date(timeIntervalSince1970: 1_700_000_000),
            tappedAt: nil
        )

        let data = try JSONEncoder().encode(legacyExposure)
        #expect(!String(decoding: data, as: UTF8.self).contains("observabilityID"))
        let decoded = try JSONDecoder().decode(RecommendationExposure.self, from: data)

        #expect(decoded.observabilityID == nil)
        #expect(decoded.fingerprint == legacyExposure.fingerprint)
    }

    @MainActor
    @Test func activeDayLoggingIsDeduplicated() {
        let defaults = UserDefaults(suiteName: "kpi.\(UUID().uuidString)")!
        let log = FlowEventLog(defaults: defaults, storageKey: "events")
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        log.recordActiveDay(now: now)
        log.recordActiveDay(now: now.addingTimeInterval(60))
        #expect(log.events.filter { $0.stage == "activation.firstEligible" }.count == 1)
        #expect(log.events.filter { $0.stage == "retention.appActive" }.count == 1)
    }

    @MainActor
    @Test func activationAndQualitativeResponseSurviveRingTrimming() {
        let defaults = UserDefaults(suiteName: "kpi.\(UUID().uuidString)")!
        let log = FlowEventLog(defaults: defaults, storageKey: "events", maxRecords: 4)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        log.log(FlowEvent.make(createdAt: start, correlationId: UUID(), flow: .other, stage: "activation.firstEligible"))
        log.log(FlowEvent.make(createdAt: start.addingTimeInterval(1), correlationId: UUID(), flow: .other, stage: "transformation.helpfulness.yes"))
        for index in 2...10 {
            log.log(FlowEvent.make(createdAt: start.addingTimeInterval(Double(index)), correlationId: UUID(), flow: .other, stage: "noise.\(index)"))
        }
        #expect(log.events.count == 4)
        #expect(log.events.contains { $0.stage == "activation.firstEligible" })
        #expect(log.events.contains { $0.stage == "transformation.helpfulness.yes" })
        #expect(!TransformationQuestionEligibility.shouldShow(sessionCount: 3, events: log.events))
    }

    @MainActor
    @Test func structuredValueAnchorSurvivesRingTrimmingWithoutUserContent() {
        let defaults = UserDefaults(suiteName: "kpi.\(UUID().uuidString)")!
        let log = FlowEventLog(defaults: defaults, storageKey: "events", maxRecords: 4)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let correlationID = UUID()
        log.log(FlowEvent.make(
            createdAt: start,
            correlationId: UUID(),
            flow: .other,
            stage: "activation.firstEligible",
            reason: "first account-local value opportunity"
        ))
        log.log(FlowEvent.make(
            createdAt: start.addingTimeInterval(17),
            correlationId: correlationID,
            flow: .other,
            stage: TransformationKPIEventStage.structuredValueDelivered,
            reason: "structured value delivered",
            numerics: ["wordCount": 14]
        ))
        // A duplicate completion must not replace the true first-value anchor.
        log.log(FlowEvent.make(
            createdAt: start.addingTimeInterval(25),
            correlationId: UUID(),
            flow: .other,
            stage: TransformationKPIEventStage.structuredValueDelivered,
            reason: "duplicate structured value delivery ignored by KPI minimum"
        ))
        for index in 30...40 {
            log.log(FlowEvent.make(
                createdAt: start.addingTimeInterval(Double(index)),
                correlationId: UUID(),
                flow: .other,
                stage: "noise.\(index)"
            ))
        }

        let anchor = log.events.first { $0.correlationId == correlationID }
        #expect(log.events.count == 4)
        #expect(anchor?.stage == TransformationKPIEventStage.structuredValueDelivered)
        #expect(anchor?.reason == "structured value delivered")
        #expect(anchor?.numerics == ["wordCount": 14])
        #expect(log.events.allSatisfy { $0.reason.count <= 256 && $0.numerics.count <= 12 })

        let report = TransformationKPIReport.derive(
            events: log.events,
            sessions: [],
            outcomes: []
        )
        #expect(report.timeToFirstValueSeconds == 17)
        #expect(report.firstStructuredValueCompleted)
    }

    @Test func structuredActivationStagesAreStableAndBounded() {
        let stages = [
            TransformationKPIEventStage.structuredStarted,
            TransformationKPIEventStage.structuredValueDelivered,
            TransformationKPIEventStage.liveUpgradeTapped,
            TransformationKPIEventStage.profileSetupTapped,
        ]

        #expect(stages == [
            "activation.structuredStarted",
            "activation.structuredValueDelivered",
            "activation.liveUpgradeTapped",
            "activation.profileSetupTapped",
        ])
        #expect(stages.allSatisfy { !$0.isEmpty && $0.count <= 48 })
    }

    @Test func structuredToSpokenUpgradeIntentRequiresAPairedDeliveredValue() {
        let deliveredA = UUID()
        let deliveredB = UUID()
        let unrelated = UUID()
        let events = [
            FlowEvent.make(correlationId: deliveredA, flow: .other, stage: TransformationKPIEventStage.structuredValueDelivered),
            FlowEvent.make(correlationId: deliveredB, flow: .other, stage: TransformationKPIEventStage.structuredValueDelivered),
            FlowEvent.make(correlationId: deliveredA, flow: .other, stage: TransformationKPIEventStage.liveUpgradeTapped),
            FlowEvent.make(correlationId: unrelated, flow: .other, stage: TransformationKPIEventStage.liveUpgradeTapped),
        ]

        let report = TransformationKPIReport.derive(events: events, sessions: [], outcomes: [])

        #expect(report.structuredToSpokenUpgradeIntentRate == 0.5)
        #expect(TransformationKPIReport.derive(events: [], sessions: [], outcomes: []).structuredToSpokenUpgradeIntentRate == nil)
    }

    @Test func qualitativeQuestionAppearsOnlyAfterThreeRepsAndOnlyOnce() {
        #expect(!TransformationQuestionEligibility.shouldShow(sessionCount: 2, events: []))
        #expect(TransformationQuestionEligibility.shouldShow(sessionCount: 3, events: []))
        let response = FlowEvent.make(
            correlationId: UUID(), flow: .other,
            stage: "transformation.helpfulness.notYet"
        )
        #expect(!TransformationQuestionEligibility.shouldShow(sessionCount: 4, events: [response]))
    }
}
