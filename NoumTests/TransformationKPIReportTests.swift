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
        let events = [
            FlowEvent.make(createdAt: start, correlationId: UUID(), flow: .other, stage: "activation.firstEligible"),
            FlowEvent.make(createdAt: start, correlationId: UUID(), flow: .other, stage: "retention.appActive"),
            FlowEvent.make(createdAt: day1, correlationId: UUID(), flow: .other, stage: "retention.appActive"),
            FlowEvent.make(createdAt: start.addingTimeInterval(120), correlationId: UUID(), flow: .other, stage: "review.sessionOpened"),
            FlowEvent.make(createdAt: start.addingTimeInterval(121), correlationId: UUID(), flow: .other, stage: "coach.typedOpened"),
            FlowEvent.make(createdAt: start.addingTimeInterval(122), correlationId: UUID(), flow: .other, stage: "coach.typedToLive"),
            FlowEvent.make(createdAt: start.addingTimeInterval(123), correlationId: UUID(), flow: .other, stage: "notification.authorizationGranted")
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
