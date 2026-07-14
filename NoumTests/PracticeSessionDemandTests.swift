import Foundation
import Testing
@testable import Noum

struct PracticeSessionDemandTests {
    @Test func everyCurrentDifficultyRoundTrips() throws {
        let demands = TimedPracticeDifficulty.allCases.map {
            PracticeSessionDemand.timed(difficulty: $0)
        } + SuddenDeathDifficulty.allCases.map {
            PracticeSessionDemand.suddenDeath(difficulty: $0)
        }
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for demand in demands {
            let decoded = try decoder.decode(
                PracticeSessionDemand.self,
                from: encoder.encode(demand)
            )
            #expect(decoded == demand)
        }
    }

    @Test func projectIdentityRoundTripsWithoutDuplicatingCatalogContent() throws {
        let demand = PracticeSessionDemand.timed(
            difficulty: .hard,
            speechProjectID: "ice_breaker"
        )
        let decoded = try JSONDecoder().decode(
            PracticeSessionDemand.self,
            from: JSONEncoder().encode(demand)
        )

        #expect(decoded == demand)
        #expect(decoded.isValid(for: .timed))
        #expect(!decoded.isValid(for: .suddenDeath))
    }

    @Test func legacySessionWithoutDemandRemainsReadableAndUnknown() throws {
        let json = """
        {
          "id":"00000000-0000-4000-8000-000000000101",
          "transcript":"A complete legacy answer with enough evidence to remain readable.",
          "fillerWordCount":1,
          "duration":42,
          "date":0,
          "mode":"timed",
          "insights":[],
          "pressureLevel":1,
          "isRated":false,
          "isEvaluationFixture":false
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let session = try decoder.decode(PracticeSession.self, from: json)
        #expect(session.practiceDemand == nil)
        #expect(session.comparisonMetricSchemaVersion == nil)
    }

    @Test func malformedOrWrongModeDemandFailsComparisonValidation() {
        let mixed = PracticeSessionDemand(
            schemaVersion: PracticeSessionDemand.currentSchemaVersion,
            timedDifficulty: .medium,
            suddenDeathDifficulty: .hard,
            speechProjectID: nil
        )
        let unknownSchema = PracticeSessionDemand(
            schemaVersion: 999,
            timedDifficulty: .medium,
            suddenDeathDifficulty: nil,
            speechProjectID: nil
        )
        let invalidProject = PracticeSessionDemand(
            schemaVersion: PracticeSessionDemand.currentSchemaVersion,
            timedDifficulty: .medium,
            suddenDeathDifficulty: nil,
            speechProjectID: "project with spaces"
        )

        #expect(!mixed.isValid(for: .timed))
        #expect(!mixed.isValid(for: .suddenDeath))
        #expect(!unknownSchema.isValid(for: .timed))
        #expect(!invalidProject.isValid(for: .timed))
        #expect(!PracticeSessionDemand.timed(difficulty: .easy).isValid(for: .ahCounter))
    }

    @Test func currentSessionRoundTripPreservesExactDemand() throws {
        let session = PracticeSession(
            transcript: "The decision is clear, and the next step has one accountable owner.",
            fillerWordCount: 0,
            duration: 35,
            date: Date(timeIntervalSince1970: 1_720_000_000),
            mode: .timed,
            practiceDemand: .timed(
                difficulty: .medium,
                speechProjectID: "persuade_structure"
            )
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let decoded = try decoder.decode(
            PracticeSession.self,
            from: encoder.encode(session)
        )
        #expect(decoded.practiceDemand == session.practiceDemand)
        #expect(decoded.practiceDemand?.isValid(for: decoded.mode) == true)
    }

    @Test @MainActor func pendingIntentCopyPreservesExactDemand() {
        let demand = PracticeSessionDemand.timed(
            difficulty: .hard,
            speechProjectID: "teach_in_90"
        )
        let draft = PracticeSessionDraft(
            transcript: "Name the recommendation, support it, and close with one next step.",
            fillerWordCount: 0,
            duration: 40,
            date: Date(timeIntervalSince1970: 1_720_000_000),
            mode: .timed,
            practiceDemand: demand
        )
        let intent = SessionIntent(
            priority: .moreConcise,
            label: "Tighten structure",
            kind: .generic
        )

        let copied = PracticeSessionFinalizer.applying(
            pendingIntent: intent,
            to: draft
        )
        #expect(copied.practiceDemand == demand)
        #expect(copied.intentFocus == .moreConcise)
        #expect(copied.intentLabel == "Tighten structure")
    }
}
