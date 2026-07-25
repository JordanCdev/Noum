import Foundation
import Testing
@testable import Noum

/// Slice 2 contracts for the V4.6 coaching-loop surfaces: the voice-trace
/// geometry (the single motif of the frozen system) and the scripted
/// transcription seam that makes the full loop deterministically tourable.
@Suite("V4.6 loop surface contracts")
struct V46CoachingLoopSurfaceTests {

    // MARK: - Voice trace geometry (Figma components 209:497–504)

    @Test("Every trace variant pairs each bar with an opacity")
    func traceVariantGeometryIsConsistent() {
        for variant in [VoiceTraceVariant.idleHero, .earnedHero, .live, .settling] {
            #expect(variant.heights.count == variant.opacities.count)
            #expect(variant.heights.allSatisfy { $0 > 0 })
            #expect(variant.opacities.allSatisfy { $0 > 0 && $0 <= 1 })
        }
    }

    @Test("Hero traces are 12 bars; immersive traces are 22")
    func traceVariantBarCounts() {
        #expect(VoiceTraceVariant.idleHero.heights.count == 12)
        #expect(VoiceTraceVariant.earnedHero.heights.count == 12)
        #expect(VoiceTraceVariant.live.heights.count == 22)
        #expect(VoiceTraceVariant.settling.heights.count == 22)
    }

    @Test("Settling is the live silhouette, scaled and damped — never a new shape")
    func settlingDerivesFromLive() {
        let live = VoiceTraceVariant.live
        let settling = VoiceTraceVariant.settling
        for (index, height) in live.heights.enumerated() {
            #expect(abs(settling.heights[index] - height * 1.1) < 0.001)
        }
        for (index, opacity) in live.opacities.enumerated() {
            #expect(abs(settling.opacities[index] - opacity * 0.45) < 0.001)
        }
    }

    @Test("The earned hero trace is unmistakably stronger than idle")
    func earnedTraceOutweighsIdle() {
        let idle = VoiceTraceVariant.idleHero
        let earned = VoiceTraceVariant.earnedHero
        #expect(earned.heights.reduce(0, +) > idle.heights.reduce(0, +))
        #expect(earned.opacities.reduce(0, +) > idle.opacities.reduce(0, +))
    }

    // MARK: - Scripted transcription seam (UI_TESTING_TRANSCRIPTION_SCRIPTED)

    @Test("Scripted session finalizes with usable speech that passes the gate")
    func scriptedSessionPassesCompletionGate() async throws {
        let provider = UITestScriptedTranscriptionProvider()
        let session = try await provider.startSession(config: .init(
            languageCode: "en-US",
            sampleRate: 16_000,
            encoding: .pcmSigned16Bit,
            enableFillerWordDetection: false
        ))
        try await session.sendAudio(Data(repeating: 0, count: 640))
        let finalized = try await session.finish()
        #expect(finalized.hasUsableSpeech)
        #expect(RecordingCompletionGate.allowsScoringAndProgress(finalized))
        #expect(UITestScriptedTranscriptionProvider.script.hasPrefix(finalized.text.prefix(20)))
    }

    @Test("Scripted session refuses a second finalize")
    func scriptedSessionFinishesOnce() async throws {
        let provider = UITestScriptedTranscriptionProvider()
        let session = try await provider.startSession(config: .init(
            languageCode: "en-US",
            sampleRate: 16_000,
            encoding: .pcmSigned16Bit,
            enableFillerWordDetection: false
        ))
        try await session.sendAudio(Data(repeating: 0, count: 64))
        _ = try await session.finish()
        await #expect(throws: TranscriptionSessionError.alreadyFinished) {
            _ = try await session.finish()
        }
    }

    @Test("A silent capture still fails the gate even from the scripted seam")
    func scriptedSessionWithoutAudioFailsGate() async throws {
        let provider = UITestScriptedTranscriptionProvider()
        let session = try await provider.startSession(config: .init(
            languageCode: "en-US",
            sampleRate: 16_000,
            encoding: .pcmSigned16Bit,
            enableFillerWordDetection: false
        ))
        let finalized = try await session.finish()
        // No audio was ever sent — the honesty gate must refuse scoring.
        #expect(!finalized.hasCapturedAudio)
        #expect(!RecordingCompletionGate.allowsScoringAndProgress(finalized))
    }
}
