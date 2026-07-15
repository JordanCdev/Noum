import Foundation
import Testing
@testable import Noum

@Suite("Pace Training completion integrity")
struct PaceTrainingCompletionIntegrityTests {
    @Test("One or two terminal words cannot earn Pace XP", arguments: ["one", "one two"])
    func subfloorFinalWordsCannotEarnXP(_ text: String) {
        let disposition = resolve(
            text: text,
            captureDuration: 75,
            candidate: candidate(totalWords: 100)
        )

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

        #expect(exact == .eligible(candidate()))
        #expect(shortDuration == .insufficientSpeech)
        #expect(shortText == .insufficientSpeech)
        #expect(nonFinite == .insufficientSpeech)
    }

    @Test("The terminal transcript owns word eligibility")
    func terminalTranscriptOwnsEligibility() {
        let lateGrowth = resolve(
            text: "one two three",
            captureDuration: 75,
            candidate: candidate(totalWords: 1)
        )
        let lateShrink = resolve(
            text: "one two",
            captureDuration: 75,
            candidate: candidate(totalWords: 20)
        )

        #expect(lateGrowth == .eligible(candidate(totalWords: 1)))
        #expect(lateShrink == .insufficientSpeech)
    }

    @Test("Eligible completion preserves the live result and its exact XP")
    func eligibleCompletionPreservesResult() {
        let liveResult = candidate(zonePercentage: 0.65)
        let disposition = resolve(
            text: "one two three four",
            captureDuration: 75,
            candidate: liveResult
        )

        #expect(disposition.result == liveResult)
        #expect(disposition.awardedXP == liveResult.xpEarned)
    }

    @Test("Unusable terminal receipts never become Pace results")
    func unusableReceiptMatrix() {
        let candidate = candidate()
        let receipts: [FinalizedTranscript?] = [
            nil,
            FinalizedTranscript(text: "one two three", receivedFinalResult: true, audioByteCount: 0),
            FinalizedTranscript(text: "one two three", receivedFinalResult: false, audioByteCount: 4_096),
            FinalizedTranscript(text: "   ", receivedFinalResult: true, audioByteCount: 4_096),
        ]

        for receipt in receipts {
            let disposition = PaceTrainingCompletionDisposition.resolve(
                candidate: candidate,
                completion: receipt,
                captureDuration: 75
            )
            #expect(disposition == .unusableRecording)
            #expect(disposition.awardedXP == 0)
            #expect(disposition.result == nil)
        }
    }

    @Test("Pace resolves terminal evidence before mutating XP or presenting a result")
    func viewSourceOrdersCompletionBeforeProgress() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/PaceTrainingView.swift"),
            encoding: .utf8
        )

        let resolution = try #require(
            source.range(of: "PaceTrainingCompletionDisposition.resolve(")
        )
        let award = try #require(source.range(of: "profileManager.addXP(disposition.awardedXP)"))
        let presentation = try #require(source.range(of: "hasValidatedResult = true"))

        #expect(resolution.lowerBound < award.lowerBound)
        #expect(resolution.lowerBound < presentation.lowerBound)
        #expect(source.contains("captureDuration: speechVM.lastSessionDuration"))
        #expect(source.contains("paceTraining.insufficientSpeech"))
        #expect(!source.contains("profileManager.addXP(result.xpEarned)"))
    }

    private func resolve(
        text: String,
        captureDuration: TimeInterval,
        candidate: PaceTrainingResult? = nil
    ) -> PaceTrainingCompletionDisposition {
        PaceTrainingCompletionDisposition.resolve(
            candidate: candidate ?? self.candidate(),
            completion: FinalizedTranscript(
                text: text,
                receivedFinalResult: true,
                audioByteCount: 4_096
            ),
            captureDuration: captureDuration
        )
    }

    private func candidate(
        zonePercentage: Double = 0.65,
        totalWords: Int = 100
    ) -> PaceTrainingResult {
        PaceTrainingResult(
            subMode: .freestyle,
            targetWPM: 130,
            averageWPM: 132,
            zonePercentage: zonePercentage,
            peakWPM: 155,
            lowestWPM: 105,
            totalWords: totalWords,
            fillerCount: 0,
            totalDuration: 75,
            wpmSamples: [120, 130, 140, 150]
        )
    }
}
