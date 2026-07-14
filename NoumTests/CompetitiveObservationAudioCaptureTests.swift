import AVFoundation
import Foundation
import Testing
@testable import Noum

@Suite("Competitive observation audio capture")
struct CompetitiveObservationAudioCaptureTests {
    @Test("Release gate is independently closed by default")
    func releaseGateIsClosed() {
        #expect(!SocialReleaseCapabilities.competitiveObservation.isAvailable)
        #expect(!SocialReleaseCapabilities.peerProgress.isAvailable)
    }

    @Test("Existing microphone frames become bounded mono PCM16 at 16 kHz")
    func downsampledWireFormat() throws {
        let format = try #require(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 2,
            interleaved: false
        ))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
        buffer.frameLength = 480
        let channels = try #require(buffer.floatChannelData)
        for index in 0..<480 {
            channels[0][index] = 0.5
            channels[1][index] = 0.25
        }
        let capture = try #require(CompetitiveObservationAudioCapture(inputFormat: format))

        #expect(capture.append(buffer) == .accepted)
        let payload = try #require(capture.consume())

        #expect(payload.sampleRate == 16_000)
        #expect(payload.channelCount == 1)
        #expect(payload.pcm16Mono.count == 160 * MemoryLayout<Int16>.size)
        #expect(abs(payload.duration - 0.01) < 0.000_001)
        let first = payload.pcm16Mono.withUnsafeBytes {
            Int16(littleEndian: $0.loadUnaligned(as: Int16.self))
        }
        #expect((12_286...12_289).contains(Int(first)))
    }

    @Test("Crossing the byte bound invalidates the whole observation")
    func overflowFailsClosed() throws {
        let format = try #require(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 3))
        buffer.frameLength = 3
        let channel = try #require(buffer.floatChannelData?[0])
        channel[0] = 0.1
        channel[1] = 0.2
        channel[2] = 0.3
        let capture = try #require(CompetitiveObservationAudioCapture(
            inputFormat: format,
            maximumByteCount: 4
        ))

        #expect(capture.append(buffer) == .invalidatedByLimit)
        #expect(capture.consume() == nil)
    }

    @Test("Discard removes the only audio copy and rejects late callbacks")
    func discardRejectsLateAudio() throws {
        let format = try #require(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1))
        buffer.frameLength = 1
        buffer.floatChannelData?[0][0] = 0.5
        let capture = try #require(CompetitiveObservationAudioCapture(inputFormat: format))

        #expect(capture.append(buffer) == .accepted)
        capture.discard()
        #expect(capture.append(buffer) == .discarded)
        #expect(capture.consume() == nil)
    }

    @Test("A payload can only be consumed once")
    func consumeIsDestructive() throws {
        let format = try #require(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1))
        buffer.frameLength = 1
        buffer.floatChannelData?[0][0] = 0.5
        let capture = try #require(CompetitiveObservationAudioCapture(inputFormat: format))

        #expect(capture.append(buffer) == .accepted)
        #expect(capture.consume() != nil)
        #expect(capture.consume() == nil)
    }
}
