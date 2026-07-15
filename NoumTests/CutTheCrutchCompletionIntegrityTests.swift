import Foundation
import Testing
@testable import Noum

@Suite("Cut the Crutch completion integrity")
struct CutTheCrutchCompletionIntegrityTests {
    @Test("One or two terminal words cannot earn Cut the Crutch progress", arguments: ["one", "one two"])
    func subfloorFinalWordsCannotEarnProgress(_ text: String) {
        let candidate = partialCandidate()
        let disposition = resolve(
            text: text,
            captureDuration: 60,
            candidate: candidate
        )

        #expect(candidate.xpEarned == 60)
        #expect(disposition == .insufficientSpeech)
        #expect(disposition.awardedXP == 0)
        #expect(disposition.result == nil)
    }

    @Test("Three final words at three seconds is the minimum eligible boundary")
    func minimumBoundary() {
        let exact = resolve(text: "one two three", captureDuration: 3)
        let shortDuration = resolve(text: "one two three", captureDuration: 2.99)
        let shortText = resolve(text: "one two", captureDuration: 3)
        let nonFinite = resolve(text: "one two three", captureDuration: .infinity)

        #expect(exact == .eligible(cleanCandidate()))
        #expect(shortDuration == .insufficientSpeech)
        #expect(shortText == .insufficientSpeech)
        #expect(nonFinite == .insufficientSpeech)
    }

    @Test("The terminal transcript owns word eligibility")
    func terminalTranscriptOwnsEligibility() {
        let liveThin = resolve(
            text: "one two three",
            captureDuration: 60,
            candidate: partialCandidate()
        )
        let liveFull = resolve(
            text: "one two",
            captureDuration: 60,
            candidate: cleanCandidate()
        )

        #expect(liveThin == .eligible(partialCandidate()))
        #expect(liveFull == .insufficientSpeech)
    }

    @Test("Eligible completion preserves the live result and its exact XP")
    func eligibleCompletionPreservesResult() {
        let candidate = cleanCandidate()
        let disposition = resolve(
            text: "one two three four",
            captureDuration: 60,
            candidate: candidate
        )

        #expect(candidate.xpEarned == 150)
        #expect(disposition.result == candidate)
        #expect(disposition.awardedXP == 150)
    }

    @Test("Unusable terminal receipts never become Cut the Crutch results")
    func unusableReceiptMatrix() {
        let candidate = cleanCandidate()
        let receipts: [FinalizedTranscript?] = [
            nil,
            FinalizedTranscript(text: "one two three", receivedFinalResult: true, audioByteCount: 0),
            FinalizedTranscript(text: "one two three", receivedFinalResult: false, audioByteCount: 4_096),
            FinalizedTranscript(text: "   ", receivedFinalResult: true, audioByteCount: 4_096),
        ]

        for receipt in receipts {
            let disposition = CutTheCrutchCompletionDisposition.resolve(
                candidate: candidate,
                completion: receipt,
                captureDuration: 60
            )
            #expect(disposition == .unusableRecording)
            #expect(disposition.awardedXP == 0)
            #expect(disposition.result == nil)
        }
    }

    @Test("Cut the Crutch resolves terminal evidence before every progress effect")
    func viewSourceOrdersCompletionBeforeProgress() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/CutTheCrutchView.swift"),
            encoding: .utf8
        )
        let engineSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/CutTheCrutchEngine.swift"),
            encoding: .utf8
        )

        let stop = try #require(viewSource.range(of: "await speechVM.stopRecordingAwaitingFinalization()"))
        let resolution = try #require(viewSource.range(of: "CutTheCrutchCompletionDisposition.resolve("))
        let commit = try #require(viewSource.range(of: "guard engine.confirmCompletedCapture()"))
        let award = try #require(viewSource.range(of: "profileManager.addXP(disposition.awardedXP)"))
        let presentation = try #require(viewSource.range(of: "hasValidatedResult = true"))

        #expect(stop.lowerBound < resolution.lowerBound)
        #expect(resolution.lowerBound < commit.lowerBound)
        #expect(commit.lowerBound < award.lowerBound)
        #expect(award.lowerBound < presentation.lowerBound)
        #expect(viewSource.contains("captureDuration: speechVM.lastSessionDuration"))
        #expect(viewSource.contains("cutTheCrutch.insufficientSpeech"))
        #expect(!viewSource.contains("profileManager.addXP(result.xpEarned)"))
        #expect(engineSource.contains("!hasCommittedValidCapture"))
        #expect(engineSource.contains("DailyGoalManager.shared.recordDrillCompletion"))
    }

    private func resolve(
        text: String,
        captureDuration: TimeInterval,
        candidate: CutTheCrutchResult? = nil
    ) -> CutTheCrutchCompletionDisposition {
        CutTheCrutchCompletionDisposition.resolve(
            candidate: candidate ?? cleanCandidate(),
            completion: FinalizedTranscript(
                text: text,
                receivedFinalResult: true,
                audioByteCount: 4_096
            ),
            captureDuration: captureDuration
        )
    }

    private func cleanCandidate() -> CutTheCrutchResult {
        CutTheCrutchResult(
            avoidedWord: "actually",
            heartsRemaining: 3,
            composure: 1,
            survivedDuration: 60,
            violations: [],
            cleanCut: true
        )
    }

    private func partialCandidate() -> CutTheCrutchResult {
        CutTheCrutchResult(
            avoidedWord: "actually",
            heartsRemaining: 3,
            composure: 0,
            survivedDuration: 0,
            violations: [],
            cleanCut: false
        )
    }
}
