import Foundation
import Testing
@testable import Noum

@Suite("Competitive observation client contracts")
struct CompetitiveObservationClientTests {
    private let sessionID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let challengeID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    @Test("Callable routing is explicit and regional")
    func callableRouting() {
        #expect(BackendSyncManager.functionsRegion == "europe-west2")
        #expect(BackendSyncManager.beginCompetitiveObservationFunctionName == "beginCompetitiveObservation")
        #expect(BackendSyncManager.completeCompetitiveObservationFunctionName == "completeCompetitiveObservation")
    }

    @Test("Begin sends exact exercise provenance and no client authority")
    func beginRequestIsNarrow() throws {
        let prompt = "Explain the decision exactly."
        let provenance = try #require(CompetitiveObservationPromptProvenance.bound(
            source: .curated,
            exactPrompt: prompt
        ))
        let request = try #require(BeginCompetitiveObservationRequest(
            sessionID: sessionID,
            locale: .enUS,
            mode: .timed,
            demand: .timed(difficulty: .medium),
            promptProvenance: provenance,
            challengeID: nil
        ))
        let payload = try jsonObject(request)

        #expect(Set(payload.keys) == [
            "schemaVersion", "sessionID", "locale", "mode", "demand",
            "promptProvenance", "challengeID",
        ])
        #expect(payload["challengeID"] is NSNull)
        #expect(payload["locale"] as? String == "en-US")
        let demand = try #require(payload["demand"] as? [String: Any])
        #expect(Set(demand.keys) == [
            "schemaVersion", "timedDifficulty", "suddenDeathDifficulty", "speechProjectID",
        ])
        #expect(demand["timedDifficulty"] as? String == "medium")
        #expect(demand["suddenDeathDifficulty"] is NSNull)
        #expect(demand["speechProjectID"] is NSNull)
        assertForbiddenClientAuthority(payload)
    }

    @Test("Prompt binding hashes exact UTF-8 bytes without normalization")
    func exactPromptDigest() throws {
        let exact = try #require(CompetitiveObservationPromptProvenance.bound(
            source: .challenge,
            exactPrompt: "Hello"
        ))
        let whitespaceChanged = try #require(CompetitiveObservationPromptProvenance.bound(
            source: .challenge,
            exactPrompt: "Hello "
        ))

        #expect(exact.promptDigest == "185f8db32271fe25f561a6fc938b2e264306ec304eda518007d1764826381969")
        #expect(whitespaceChanged.promptDigest != exact.promptDigest)
        #expect(CompetitiveObservationIntent(
            promptProvenance: exact,
            challengeID: challengeID
        ).matches(exactPrompt: "Hello"))
        #expect(!CompetitiveObservationIntent(
            promptProvenance: exact,
            challengeID: challengeID
        ).matches(exactPrompt: "Hello "))
    }

    @Test("Challenge and project coupling fail closed")
    func provenanceCoupling() throws {
        let challenge = try #require(CompetitiveObservationPromptProvenance.bound(
            source: .challenge,
            exactPrompt: "Bound prompt"
        ))
        #expect(BeginCompetitiveObservationRequest(
            sessionID: sessionID,
            locale: .frFR,
            mode: .timed,
            demand: .timed(difficulty: .easy),
            promptProvenance: challenge,
            challengeID: nil
        ) == nil)

        let project = try #require(CompetitiveObservationPromptProvenance.bound(
            source: .speechProject,
            exactPrompt: "Project prompt"
        ))
        #expect(BeginCompetitiveObservationRequest(
            sessionID: sessionID,
            locale: .esES,
            mode: .timed,
            demand: .timed(difficulty: .easy),
            promptProvenance: project,
            challengeID: nil
        ) == nil)
        #expect(BeginCompetitiveObservationRequest(
            sessionID: sessionID,
            locale: .esES,
            mode: .timed,
            demand: .timed(difficulty: .easy, speechProjectID: "project_one"),
            promptProvenance: project,
            challengeID: nil
        ) != nil)
    }

    @Test("Completion sends only canonical audio and the server session ID")
    func completionRequestIsNarrow() throws {
        let pcm = Data(repeating: 0x01, count: CompetitiveObservationAudioPayload.minimumByteCount)
        let audio = CompetitiveObservationAudioPayload(
            pcm16Mono: pcm,
            sampleRate: 16_000,
            channelCount: 1
        )
        let request = try #require(CompleteCompetitiveObservationRequest(
            sessionID: sessionID,
            audio: audio
        ))
        let payload = try jsonObject(request)
        #expect(Set(payload.keys) == ["schemaVersion", "sessionID", "audio"])
        let envelope = try #require(payload["audio"] as? [String: Any])
        #expect(Set(envelope.keys) == [
            "encoding", "sampleRateHertz", "channelCount", "sampleWidthBits", "dataBase64",
        ])
        #expect(envelope["encoding"] as? String == "linear16")
        #expect(envelope["sampleRateHertz"] as? Int == 16_000)
        #expect(envelope["channelCount"] as? Int == 1)
        #expect(envelope["sampleWidthBits"] as? Int == 16)
        #expect(envelope["dataBase64"] as? String == pcm.base64EncodedString())
        assertForbiddenClientAuthority(payload)
        assertForbiddenClientAuthority(envelope)

        let undersized = CompetitiveObservationAudioPayload(
            pcm16Mono: Data(repeating: 0, count: CompetitiveObservationAudioPayload.minimumByteCount - 2),
            sampleRate: 16_000,
            channelCount: 1
        )
        #expect(CompleteCompetitiveObservationRequest(
            sessionID: sessionID,
            audio: undersized
        ) == nil)
    }

    @Test("Only an explicitly ineligible server observation is accepted in v1")
    func responseValidation() throws {
        let response = CompleteCompetitiveObservationResponse(
            schemaVersion: 1,
            sessionID: sessionID.uuidString,
            transcript: "  Server observed transcript.  ",
            durationSeconds: 12.5,
            wordCount: 3,
            competitiveEligible: false,
            replayed: false
        )
        let result = try response.result(expectedSessionID: sessionID)
        #expect(result.transcript == "Server observed transcript.")
        #expect(result.duration == 12.5)

        let overclaim = CompleteCompetitiveObservationResponse(
            schemaVersion: 1,
            sessionID: sessionID.uuidString,
            transcript: "Server observed transcript.",
            durationSeconds: 12.5,
            wordCount: 3,
            competitiveEligible: true,
            replayed: false
        )
        #expect(throws: SocialAuthorityError.invalidResponse) {
            try overclaim.result(expectedSessionID: sessionID)
        }

        // Provider silence is a valid backend outcome, but it is not evidence
        // that may replace the ordinary private transcript on-device. Treating
        // it as no usable observation makes the caller take its private-session
        // fallback path and keeps the rep unrated.
        let silence = CompleteCompetitiveObservationResponse(
            schemaVersion: 1,
            sessionID: sessionID.uuidString,
            transcript: "",
            durationSeconds: 1,
            wordCount: 0,
            competitiveEligible: false,
            replayed: false
        )
        #expect(throws: SocialAuthorityError.invalidResponse) {
            try silence.result(expectedSessionID: sessionID)
        }
    }

    @Test("Account, generation, and expiry all fence late responses")
    @MainActor
    func lifecycleFence() {
        let future = Date().addingTimeInterval(60)
        #expect(SpeechRecognizerViewModel.shouldAcceptCompetitiveObservation(
            capturedGeneration: 7,
            currentGeneration: 7,
            capturedAccountID: "account-a",
            currentAccountID: "account-a",
            capturedAccountLifecycleGeneration: 4,
            currentAccountLifecycleGeneration: 4,
            expiresAt: future
        ))
        #expect(!SpeechRecognizerViewModel.shouldAcceptCompetitiveObservation(
            capturedGeneration: 7,
            currentGeneration: 8,
            capturedAccountID: "account-a",
            currentAccountID: "account-a",
            capturedAccountLifecycleGeneration: 4,
            currentAccountLifecycleGeneration: 4,
            expiresAt: future
        ))
        #expect(!SpeechRecognizerViewModel.shouldAcceptCompetitiveObservation(
            capturedGeneration: 7,
            currentGeneration: 7,
            capturedAccountID: "account-a",
            currentAccountID: "account-b",
            capturedAccountLifecycleGeneration: 4,
            currentAccountLifecycleGeneration: 4,
            expiresAt: future
        ))
        #expect(!SpeechRecognizerViewModel.shouldAcceptCompetitiveObservation(
            capturedGeneration: 7,
            currentGeneration: 7,
            capturedAccountID: "account-a",
            currentAccountID: "account-a",
            capturedAccountLifecycleGeneration: 4,
            currentAccountLifecycleGeneration: 5,
            expiresAt: future
        ))
        #expect(!SpeechRecognizerViewModel.shouldAcceptCompetitiveObservation(
            capturedGeneration: 7,
            currentGeneration: 7,
            capturedAccountID: "account-a",
            currentAccountID: "account-a",
            capturedAccountLifecycleGeneration: 4,
            currentAccountLifecycleGeneration: 4,
            expiresAt: Date().addingTimeInterval(-1)
        ))
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func assertForbiddenClientAuthority(_ payload: [String: Any]) {
        let forbidden = [
            "transcript", "score", "duration", "durationSeconds", "fillerWordCount",
            "isRated", "competitiveEligible", "summary", "rating", "completedAt",
        ]
        for key in forbidden {
            #expect(payload[key] == nil, Comment(rawValue: key))
        }
    }
}
