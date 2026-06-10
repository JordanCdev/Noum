//
//  InteractionSoundTests.swift
//  NoumTests
//
//  A2-sound-haptics: pins the pure parts of the interaction-cue system —
//  trigger policy (mic suppression, master toggle, first-launch default)
//  and the synthesis envelope contracts (audible body, bounded output,
//  hard-silent tail, duration budgets). No audio graph is touched.
//

import Foundation
import Testing
@testable import Noum

@Suite("InteractionSound trigger policy")
struct InteractionSoundPolicyTests {

    @Test func playsWhenEnabledAndIdle() {
        for cue in InteractionCue.allCases {
            #expect(InteractionSoundPolicy.shouldPlay(cue, enabled: true, isRecording: false))
        }
    }

    /// The hard suppression invariant: while the mic is open NO cue may
    /// fire — including `repStartBreath`, whose pre-mic window has by
    /// definition closed once recording is active. A cue during recording
    /// bleeds into the transcript and fights the playAndRecord session.
    @Test func recordingSuppressesEveryCue() {
        for cue in InteractionCue.allCases {
            #expect(!InteractionSoundPolicy.shouldPlay(cue, enabled: true, isRecording: true))
        }
    }

    @Test func disabledSuppressesEveryCue() {
        for cue in InteractionCue.allCases {
            #expect(!InteractionSoundPolicy.shouldPlay(cue, enabled: false, isRecording: false))
            #expect(!InteractionSoundPolicy.shouldPlay(cue, enabled: false, isRecording: true))
        }
    }

    /// Default is ON when nothing was ever stored — deliberate: the cues
    /// respect the device silent switch via `.ambient`, so the hardware
    /// mute stays the outer gate. A stored choice always wins.
    @Test func settingsDefaultOnUntilUserChooses() {
        #expect(InteractionSoundSettings.resolve(stored: nil) == true)
        #expect(InteractionSoundSettings.resolve(stored: false) == false)
        #expect(InteractionSoundSettings.resolve(stored: true) == true)
    }
}

@Suite("InteractionSound synthesis contracts")
struct InteractionCueSynthTests {

    private let sampleRate = 44100.0

    private func render(_ cue: InteractionCue) -> [Float] {
        var synth = InteractionCueSynth(cue: cue, sampleRate: sampleRate)
        var samples: [Float] = []
        samples.reserveCapacity(synth.totalFrames)
        while !synth.isFinished {
            samples.append(synth.nextSample())
        }
        return samples
    }

    /// Every cue stays inside its envelope budget. `repStartBreath` is
    /// the safety-critical one: it must hard-finish in 450 ms so the
    /// in-rep cluster can land it strictly before mic activation.
    @Test func durationBudgets() {
        #expect(InteractionCue.repStartBreath.duration <= 0.45)
        for cue in InteractionCue.allCases {
            #expect(cue.duration <= 0.5, "\(cue) exceeds the half-second cue budget")
        }
    }

    /// Each cue produces an audible body — activating a cue that renders
    /// silence would be a dead toggle.
    @Test func everyCueIsAudible() {
        for cue in InteractionCue.allCases {
            let peak = render(cue).map(abs).max() ?? 0
            #expect(peak > 0.01, "\(cue) renders effectively silent (peak \(peak))")
        }
    }

    /// All samples bounded in [-1, 1] — no clipping handed to the mixer.
    @Test func everyCueIsBounded() {
        for cue in InteractionCue.allCases {
            let peak = render(cue).map(abs).max() ?? 0
            #expect(peak <= 1.0, "\(cue) clips (peak \(peak))")
        }
    }

    /// The final millisecond of every cue is effectively silent — the
    /// hard-finish guarantee that lets `repStartBreath` end cleanly
    /// before the mic opens and keeps every cue click-free.
    @Test func everyCueEndsSilent() {
        let tailFrames = Int(0.001 * sampleRate)
        for cue in InteractionCue.allCases {
            let samples = render(cue)
            let tailPeak = samples.suffix(tailFrames).map(abs).max() ?? 0
            #expect(tailPeak <= 0.02, "\(cue) tail still audible (peak \(tailPeak))")
        }
    }

    /// After the envelope ends the synth returns exact silence forever —
    /// the render callback can safely keep pulling frames.
    @Test func finishedSynthRendersExactSilence() {
        for cue in InteractionCue.allCases {
            var synth = InteractionCueSynth(cue: cue, sampleRate: sampleRate)
            while !synth.isFinished { _ = synth.nextSample() }
            for _ in 0..<64 {
                #expect(synth.nextSample() == 0)
            }
        }
    }

    /// Success is the BRIGHTER brush, incomplete the duller one — the
    /// distinction is timbral (cutoff), never a pitch sequence and never
    /// a fail-buzzer. Both share one duration and one shape.
    @Test func drillBrushVariantsDifferByTimbreOnly() throws {
        let success = InteractionCue.drillCompleteSuccess
        let incomplete = InteractionCue.drillCompleteIncomplete
        let successCutoff = try #require(success.drillBrushStartCutoffHz)
        let incompleteCutoff = try #require(incomplete.drillBrushStartCutoffHz)
        #expect(successCutoff > incompleteCutoff)
        #expect(success.duration == incomplete.duration)
        // Non-drill cues carry no brush cutoff.
        #expect(InteractionCue.verdictReveal.drillBrushStartCutoffHz == nil)
    }

    /// Synthesis is deterministic for a fixed seed — same cue, same
    /// samples. Keeps these contracts stable run-to-run.
    @Test func synthesisIsDeterministic() {
        for cue in InteractionCue.allCases {
            var a = InteractionCueSynth(cue: cue, sampleRate: sampleRate)
            var b = InteractionCueSynth(cue: cue, sampleRate: sampleRate)
            for _ in 0..<512 {
                #expect(a.nextSample() == b.nextSample())
            }
        }
    }
}
