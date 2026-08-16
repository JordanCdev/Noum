import Foundation
import Testing
import XCTest
@testable import Noum

struct TranscriptPracticeEvaluationRow: Codable, Equatable {
    let id: String
    let lever: TranscriptPracticeLever
    let sourceTranscript: String
    let retryTranscript: String
    let expected: TranscriptRetryResult
    let actual: TranscriptRetryResult?
    let sourceBound: Bool
    let sourceSignal: Int?
    let retrySignal: Int?
    let meaningOverlapPercent: Int?

    var passes: Bool { actual == expected && sourceBound }
}

struct TranscriptPracticeEvaluationReport: Codable, Equatable {
    static let schemaVersion = "transcript-practice-evaluation-v1"

    let schemaVersion: String
    let generatedAt: Date
    let rows: [TranscriptPracticeEvaluationRow]
    let scenarioCount: Int
    let rowsPassing: Int
    let qualifiesForLocalReadiness: Bool

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(self), as: UTF8.self) + "\n"
    }
}

enum TranscriptPracticeEvaluationCorpus {
    struct Scenario {
        let id: String
        let lever: TranscriptPracticeLever
        let source: String
        let retry: String
        let expected: TranscriptRetryResult
        let sourceConfidence: Double?
        let retryConfidence: Double?

        init(
            _ id: String,
            _ lever: TranscriptPracticeLever,
            _ source: String,
            _ retry: String,
            _ expected: TranscriptRetryResult,
            sourceConfidence: Double? = 0.95,
            retryConfidence: Double? = 0.95
        ) {
            self.id = id
            self.lever = lever
            self.source = source
            self.retry = retry
            self.expected = expected
            self.sourceConfidence = sourceConfidence
            self.retryConfidence = retryConfidence
        }
    }

    static let scenarios: [Scenario] = [
        Scenario("opening-01", .opening,
                 "Well maybe I think the release plan should stay narrow because the support team needs a clear rollback path.",
                 "The release plan should stay narrow because the support team needs a clear rollback path.", .improved),
        Scenario("opening-02", .opening,
                 "So I guess the customer handoff needs one owner because the current rotation keeps dropping decisions.",
                 "The customer handoff needs one owner because the current rotation keeps dropping decisions.", .improved),
        Scenario("opening-03", .opening,
                 "Perhaps I think we should delay the launch because the payment failure still affects returning customers.",
                 "We should delay the launch because the payment failure still affects returning customers.", .improved),
        Scenario("opening-04", .opening,
                 "Maybe the pilot should include ten customers because support can follow each account closely.",
                 "Maybe the pilot should include ten customers because support can follow each account closely.", .held),
        Scenario("opening-05", .opening,
                 "The hiring plan needs approval today because the team loses its strongest candidate on Friday.",
                 "Well maybe I think the hiring plan needs approval today because the team loses its strongest candidate on Friday.", .regressed),

        Scenario("closing-01", .closing,
                 "The pilot protects the launch and gives support a clean rollback, so I think maybe.",
                 "The pilot protects the launch and gives support a clean rollback, so approve today.", .improved),
        Scenario("closing-02", .closing,
                 "The customer has accepted the revised scope and the team can deliver it, sort of I guess.",
                 "The customer has accepted the revised scope and the team can deliver it, so decide now.", .improved),
        Scenario("closing-03", .closing,
                 "The evidence supports a smaller first release with one owner and a weekly review, so yeah.",
                 "The evidence supports a smaller first release with one owner and a weekly review. Approve next.", .improved),
        Scenario("closing-04", .closing,
                 "The team can ship the focused change safely, and I recommend we approve today.",
                 "The team can ship the focused change safely, and I recommend we approve today.", .held),
        Scenario("closing-05", .closing,
                 "The first cohort is ready and support has a rollback plan, so approve today.",
                 "The first cohort is ready and support has a rollback plan, sort of, I think maybe.", .regressed),

        Scenario("structure-01", .structure,
                 "The delay affects onboarding. Support needs a script. Product needs one owner. Customers need a date.",
                 "First, the delay affects onboarding. Next, support needs a script because customers need a date and product needs one owner.", .improved),
        Scenario("structure-02", .structure,
                 "The proposal reduces cost. The transition stays reversible. The customer keeps the same deadline.",
                 "First, the proposal reduces cost. Second, the transition stays reversible. Finally, the customer keeps the same deadline.", .improved),
        Scenario("structure-03", .structure,
                 "The team owns the migration. The risk is data drift. A weekly audit catches problems early.",
                 "The team owns the migration. However, the risk is data drift. Therefore, a weekly audit catches problems early.", .improved),
        Scenario("structure-04", .structure,
                 "First, name the decision. Next, explain the customer risk. Finally, ask for approval today.",
                 "First, name the decision. Next, explain the customer risk. Finally, ask for approval today.", .held),
        Scenario("structure-05", .structure,
                 "First, name the decision. Because support needs clarity, next explain the risk and finally ask for approval.",
                 "Name the decision. Explain the support risk. Ask for approval after the customer review.", .regressed),

        Scenario("concise-01", .concise,
                 "The recommendation is to keep the launch narrow because that gives the support team a clear rollback while still delivering customer value this month.",
                 "Keep the launch narrow because support gets a clear rollback while customers still receive value this month.", .improved),
        Scenario("concise-02", .concise,
                 "The customer handoff needs one accountable owner who can answer questions, track the open risks, and confirm every promised date with the delivery team.",
                 "The customer handoff needs one owner to answer questions, track risks, and confirm promised dates with delivery.", .improved),
        Scenario("concise-03", .concise,
                 "I recommend approving the pilot today because ten customers give us enough evidence while keeping support demand controlled and the rollback straightforward.",
                 "Approve the ten-customer pilot today; it gives us evidence while keeping support and rollback controlled.", .improved),
        Scenario("concise-04", .concise,
                 "The team should protect the deadline by freezing scope and assigning one owner to customer questions.",
                 "The team should protect the deadline by freezing scope and assigning one owner to customer questions.", .held),
        Scenario("meaning-drift-01", .concise,
                 "Keep the launch narrow because support needs a rollback and customers need a reliable delivery date.",
                 "The office kitchen should serve fresh coffee and fruit before the morning planning meeting begins.", .needsMoreEvidence),
    ]

    static func report(generatedAt: Date = Date()) -> TranscriptPracticeEvaluationReport {
        let rows = scenarios.enumerated().map { index, scenario in
            let source = session(
                ordinal: index * 2,
                transcript: scenario.source,
                confidence: scenario.sourceConfidence
            )
            let retry = session(
                ordinal: index * 2 + 1,
                transcript: scenario.retry,
                confidence: scenario.retryConfidence
            )
            let comparison = TranscriptRetryComparator.compare(
                source: source,
                retry: retry,
                target: TranscriptRetryTarget(lever: scenario.lever)
            )
            return TranscriptPracticeEvaluationRow(
                id: scenario.id,
                lever: scenario.lever,
                sourceTranscript: scenario.source,
                retryTranscript: scenario.retry,
                expected: scenario.expected,
                actual: comparison?.result,
                sourceBound: comparison?.sourceSessionID == source.id
                    && comparison?.retrySessionID == retry.id,
                sourceSignal: comparison?.sourceSignal,
                retrySignal: comparison?.retrySignal,
                meaningOverlapPercent: comparison?.meaningOverlapPercent
            )
        }
        let rowsPassing = rows.filter(\.passes).count
        let qualifies = rows.count >= 20
            && rowsPassing == rows.count
            && Set(rows.map(\.lever)) == Set(TranscriptPracticeLever.allCases)
            && rows.contains { $0.expected == .needsMoreEvidence }
            && rows.contains { $0.expected == .regressed }
        return TranscriptPracticeEvaluationReport(
            schemaVersion: TranscriptPracticeEvaluationReport.schemaVersion,
            generatedAt: generatedAt,
            rows: rows,
            scenarioCount: rows.count,
            rowsPassing: rowsPassing,
            qualifiesForLocalReadiness: qualifies
        )
    }

    private static func session(
        ordinal: Int,
        transcript: String,
        confidence: Double?
    ) -> PracticeSession {
        let suffix = String(format: "%012d", ordinal + 1)
        return PracticeSession(
            id: UUID(uuidString: "70000000-0000-4000-8000-\(suffix)")!,
            transcript: transcript,
            fillerWordCount: 0,
            duration: 45,
            date: Date(timeIntervalSince1970: 1_800_000_000 + Double(ordinal)),
            mode: .timed,
            score: 7,
            transcriptConfidence: confidence,
            isRated: true,
            practiceDemand: .timed(difficulty: .medium)
        )
    }
}

@Suite("Transcript practice loop", .serialized)
struct TranscriptPracticeLoopTests {
    @Test("Twenty simulated retries cover every lever and terminal comparison")
    func corpusPassesSourceBoundContract() throws {
        let report = TranscriptPracticeEvaluationCorpus.report()
        if let dumpDirectory = ProcessInfo.processInfo.environment["NOUM_TRANSCRIPT_PRACTICE_DUMP_DIR"] {
            let directory = URL(fileURLWithPath: dumpDirectory, isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try report.encodedSortedJSON().write(
                to: directory.appendingPathComponent("transcript-practice-evaluation-v1.json"),
                atomically: true,
                encoding: .utf8
            )
        }
        #expect(report.rows.count == 20)
        #expect(report.rowsPassing == 20)
        #expect(report.qualifiesForLocalReadiness)
    }

    @Test("Low-confidence retry fails closed")
    func lowConfidenceFailsClosed() {
        var retry = TranscriptPracticeEvaluationCorpus.scenarios[0]
        retry = .init(
            retry.id,
            retry.lever,
            retry.source,
            retry.retry,
            retry.expected,
            retryConfidence: 0.4
        )
        let sourceSession = PracticeSession(
            transcript: retry.source,
            fillerWordCount: 0,
            duration: 40,
            date: Date(),
            mode: .timed,
            transcriptConfidence: 0.95
        )
        let retrySession = PracticeSession(
            transcript: retry.retry,
            fillerWordCount: 0,
            duration: 40,
            date: Date(),
            mode: .timed,
            transcriptConfidence: retry.retryConfidence
        )
        #expect(TranscriptRetryComparator.compare(
            source: sourceSession,
            retry: retrySession,
            target: TranscriptRetryTarget(lever: retry.lever)
        ) == nil)
    }

    @MainActor
    @Test("Handoff carries only content-free retry provenance and consumes once")
    func handoffCarriesRetryProvenance() throws {
        let handoff = TimedPracticePromptHandoff(accountIDProvider: { "account-a" })
        let sourceID = UUID()
        let traceID = UUID()
        let target = TranscriptRetryTarget(lever: .opening)
        let prescription = TranscriptPracticePrescription(
            correlationID: traceID,
            sourceSessionID: sourceID,
            suggestedPrompt: "Lead with the recommendation, then name the reason.",
            title: "Opening upgrade",
            focus: target.lever.focusLabel,
            target: target.lever.successMeasure,
            targetDimensionID: nil,
            goal: nil,
            retryTarget: target
        )
        let token = try #require(handoff.offerTranscriptRetryToken(prescription))
        let payload = try #require(handoff.consumePayload(token: token))
        #expect(payload.text == prescription.suggestedPrompt)
        #expect(payload.transcriptPracticeIntent == TranscriptPracticeIntent(
            correlationID: traceID,
            sourceSessionID: sourceID,
            title: prescription.title,
            focus: prescription.focus,
            target: prescription.target,
            targetDimensionID: prescription.targetDimensionID,
            goal: prescription.goal,
            retryTarget: target
        ))
        #expect(payload.competitiveObservationIntent == nil)
        #expect(handoff.consumePayload(token: token) == nil)
    }

    @MainActor
    @Test("One trace closes ladder, retry, comparison, and intervention stages")
    func observabilityTraceAndKPIsClose() throws {
        let suite = "transcript-practice-trace-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let log = FlowEventLog(defaults: defaults, storageKey: "events")
        let traceID = UUID()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        log.recordTranscriptLadderShown(correlationId: traceID, lever: .opening, now: now)
        log.recordPrescriptionShown(correlationId: traceID, now: now.addingTimeInterval(1))
        log.recordPrescriptionAccepted(correlationId: traceID, now: now.addingTimeInterval(2))
        log.recordTranscriptRetryCompleted(correlationId: traceID, now: now.addingTimeInterval(20))
        log.recordTranscriptTargetCompared(
            correlationId: traceID,
            result: .improved,
            comparison: nil,
            now: now.addingTimeInterval(21)
        )
        log.recordTranscriptInterventionUpdated(
            correlationId: traceID,
            result: .improved,
            now: now.addingTimeInterval(22)
        )

        let trace = try #require(log.recentTranscriptPracticeTraces(limit: 1).first)
        #expect(trace.correlationId == traceID)
        #expect(trace.result == .improved)
        #expect(trace.events.last?.stage == TransformationKPIEventStage.transcriptInterventionUpdated)
        let kpis = TransformationKPIReport.derive(events: log.events, sessions: [], outcomes: [])
        #expect(kpis.transcriptLadderAcceptanceRate == 1)
        #expect(kpis.transcriptRetryComparisonCompletionRate == 1)
        #expect(kpis.transcriptTargetImprovementRate == 1)
    }

    @MainActor
    @Test("Accepted retry persists target comparison and refreshes intervention on one trace")
    func acceptedRetryClosesLearningAndMemoryLoop() throws {
        let traceID = UUID()
        let source = PracticeSession(
            transcript: "Well maybe I think the release plan should stay narrow because support needs a clear rollback path.",
            fillerWordCount: 0,
            duration: 45,
            date: Date(timeIntervalSince1970: 1_800_000_000),
            mode: .timed,
            score: 7,
            transcriptConfidence: 0.95,
            isRated: true,
            practiceDemand: .timed(difficulty: .medium)
        )
        let retry = PracticeSession(
            transcript: "The release plan should stay narrow because support needs a clear rollback path.",
            fillerWordCount: 0,
            duration: 42,
            date: Date(timeIntervalSince1970: 1_800_000_100),
            mode: .timed,
            score: 7,
            transcriptConfidence: 0.95,
            isRated: true,
            practiceDemand: .timed(difficulty: .medium)
        )
        let target = TranscriptRetryTarget(lever: .opening)
        let exposure = RecommendationExposure(
            fingerprint: "transcript-ladder|\(source.id.uuidString)|opening|general",
            title: "One-step opening directness upgrade",
            focus: target.lever.focusLabel,
            target: target.lever.successMeasure,
            mode: .timed,
            isAIBacked: true,
            shownAt: source.date.addingTimeInterval(1),
            tappedAt: source.date.addingTimeInterval(2),
            sourceSessionID: source.id,
            observabilityID: traceID,
            transcriptRetryTarget: target
        )
        #expect(RecommendationLearningStore.followedPrescription(
            exposure,
            completedSession: retry
        ))
        let comparison = try #require(RecommendationLearningStore.transcriptRetryComparison(
            for: exposure,
            completedSession: retry,
            previousSessions: [source],
            followed: true
        ))
        let outcome = RecommendationOutcome(
            id: UUID(),
            fingerprint: exposure.fingerprint,
            title: exposure.title,
            focus: exposure.focus,
            target: exposure.target,
            mode: exposure.mode,
            sessionID: retry.id,
            followed: true,
            completedAt: retry.date,
            scoreDelta: 0,
            hasComparableScore: false,
            fillerDelta: 0,
            durationDelta: 0,
            goalFollowUpResult: RecommendationLearningStore.goalFollowUpResult(
                followed: true,
                transcriptRetryResult: comparison.result,
                hadTranscriptRetryTarget: true,
                comparableScoreDelta: nil,
                fillerRateDelta: nil,
                comparablePaceDelta: nil,
                comparisonSessionCount: 0
            ),
            observabilityID: traceID,
            transcriptRetryTarget: target,
            transcriptRetryComparison: comparison
        )
        #expect(outcome.isVerifiedFollowed)
        #expect(outcome.observabilityID == traceID)
        #expect(outcome.transcriptRetryTarget == target)
        #expect(outcome.transcriptRetryComparison?.result == .improved)
        #expect(outcome.goalFollowUpResult == .earlyImprovement)
        #expect(outcome.hasComparableBaseline)
        let roundTripped = try JSONDecoder().decode(
            RecommendationOutcome.self,
            from: JSONEncoder().encode(outcome)
        )
        #expect(roundTripped == outcome)

        let suite = "transcript-practice-memory-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let memory = CoachMemoryStore(
            defaults: defaults,
            accountIDProvider: { "transcript-loop-test" }
        )
        memory.refresh(
            profile: nil,
            baseline: .empty,
            sessions: [retry, source],
            trends: [],
            forwardPlan: nil,
            lastSessionID: retry.id,
            recommendationOutcomes: [outcome],
            now: retry.date.addingTimeInterval(1)
        )

        #expect(memory.currentMemory?.activeIntervention?.reviewStatus == .continueAndVerify)
        #expect(memory.currentMemory?.activeIntervention?.reviewBasis.contains("opening directness") == true)
    }
}

@Suite("Transcript retry milestone presentation")
struct TranscriptRetryMilestonePresentationTests {
    @Test("Only an exact verified improved retry earns the milestone")
    func qualificationFailsClosed() {
        let fixture = makeFixture(result: .improved)
        #expect(fixture.presentation() != nil)

        let held = makeFixture(result: .held)
        #expect(held.presentation() == nil)
        #expect(makeFixture(followed: false).presentation() == nil)
        #expect(makeFixture(comparisonSchemaVersion: 999).presentation() == nil)
        #expect(makeFixture(improvedSignalMovement: 0).presentation() == nil)
        #expect(makeFixture(meaningOverlapPercent: 20).presentation() == nil)
        #expect(makeFixture(outcomeMode: .ahCounter).presentation() == nil)
        #expect(makeFixture(retryMode: .ahCounter).presentation() == nil)

        let wrongRetry = PracticeSession(
            id: UUID(),
            transcript: fixture.retry.transcript,
            fillerWordCount: 0,
            duration: fixture.retry.duration,
            date: fixture.retry.date,
            mode: .timed,
            practiceDemand: .timed(difficulty: .easy)
        )
        #expect(TranscriptRetryMilestonePresentation.make(
            outcome: fixture.outcome,
            sourceSession: fixture.source,
            retrySession: wrongRetry,
            priorHolds: 0
        ) == nil)
        #expect(TranscriptRetryMilestonePresentation.make(
            outcome: fixture.outcome,
            sourceSession: nil,
            retrySession: fixture.retry,
            priorHolds: 0
        ) == nil)
    }

    @Test("Difficulty and prior holds select the milestone headline")
    func headlineSelection() {
        #expect(makeFixture(difficulty: .easy).presentation()?.headline == "First hold")
        #expect(
            makeFixture(difficulty: .easy).presentation(priorHolds: 1)?.headline
                == "The target moved"
        )
        #expect(
            makeFixture(difficulty: .medium).presentation()?.headline
                == "First hold under pressure"
        )
        #expect(
            makeFixture(difficulty: .hard).presentation(priorHolds: 1)?.headline
                == "Held again under pressure"
        )
    }

    @Test("Evidence names the verified lever and ignores whole-rep duration")
    func leverDetail() {
        for lever in TranscriptPracticeLever.allCases {
            let faster = makeFixture(
                lever: lever,
                sourceDuration: 46,
                retryDuration: 40
            ).presentation()?.detail
            let nearlyEqual = makeFixture(
                lever: lever,
                sourceDuration: 42,
                retryDuration: 40
            ).presentation()?.detail
            let expected = "Your \(lever.focusLabel) was stronger on this retry."

            #expect(faster == expected)
            #expect(nearlyEqual == expected)
        }
    }

    private struct Fixture {
        let source: PracticeSession
        let retry: PracticeSession
        let outcome: RecommendationOutcome

        func presentation(priorHolds: Int = 0) -> TranscriptRetryMilestonePresentation? {
            TranscriptRetryMilestonePresentation.make(
                outcome: outcome,
                sourceSession: source,
                retrySession: retry,
                priorHolds: priorHolds
            )
        }
    }

    private func makeFixture(
        result: TranscriptRetryResult = .improved,
        difficulty: TimedPracticeDifficulty = .easy,
        lever: TranscriptPracticeLever = .opening,
        sourceDuration: TimeInterval = 46,
        retryDuration: TimeInterval = 40,
        followed: Bool = true,
        comparisonSchemaVersion: Int = TranscriptRetryComparison.schemaVersion,
        improvedSignalMovement: Int = 30,
        meaningOverlapPercent: Int = 80,
        outcomeMode: PracticeMode = .timed,
        retryMode: PracticeMode = .timed
    ) -> Fixture {
        let source = PracticeSession(
            id: UUID(),
            transcript: "Well maybe the release plan stays narrow because support needs a clear rollback.",
            fillerWordCount: 0,
            duration: sourceDuration,
            date: Date(timeIntervalSince1970: 1_800_000_000),
            mode: .timed,
            practiceDemand: .timed(difficulty: difficulty)
        )
        let retry = PracticeSession(
            id: UUID(),
            transcript: "The release plan stays narrow because support needs a clear rollback.",
            fillerWordCount: 0,
            duration: retryDuration,
            date: Date(timeIntervalSince1970: 1_800_000_001),
            mode: retryMode,
            practiceDemand: .timed(difficulty: difficulty)
        )
        let target = TranscriptRetryTarget(lever: lever)
        let outcome = RecommendationOutcome(
            id: UUID(),
            fingerprint: "retry-milestone-test",
            title: "Opening upgrade",
            focus: target.lever.focusLabel,
            target: target.lever.successMeasure,
            mode: outcomeMode,
            sessionID: retry.id,
            followed: followed,
            completedAt: retry.date,
            scoreDelta: 0,
            hasComparableScore: false,
            fillerDelta: 0,
            durationDelta: 0,
            sourceSessionID: source.id,
            transcriptRetryTarget: target,
            transcriptRetryComparison: TranscriptRetryComparison(
                schemaVersion: comparisonSchemaVersion,
                lever: target.lever,
                sourceSessionID: source.id,
                retrySessionID: retry.id,
                sourceSignal: 40,
                retrySignal: result == .improved ? 40 + improvedSignalMovement : 40,
                meaningOverlapPercent: meaningOverlapPercent,
                result: result
            )
        )
        return Fixture(source: source, retry: retry, outcome: outcome)
    }
}

final class TranscriptPracticeArtifactDumpXCTest: XCTestCase {
    func testDumpTranscriptPracticeEvaluation() throws {
        let report = TranscriptPracticeEvaluationCorpus.report()
        XCTAssertEqual(report.scenarioCount, 20)
        XCTAssertEqual(report.rowsPassing, 20)
        XCTAssertTrue(report.qualifiesForLocalReadiness)

        let attachment = XCTAttachment(
            data: Data(try report.encodedSortedJSON().utf8),
            uniformTypeIdentifier: "public.json"
        )
        attachment.name = "transcript-practice-evaluation-v1"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
