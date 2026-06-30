//
//  RepEventLocationsEngineTests.swift
//  NoumTests
//
//  Locks the pure positional-read engine that turns a rep's TranscriptTimeline
//  into a small, persisted, coach-facing summary of WHERE its events fell
//  (longest pause / fastest stretch / filler cluster, by opening/middle/close
//  third). Tests assert STRUCTURAL + honesty invariants only — no calibration:
//    1. empty / no-credible-signal input derives nil (never a fabricated read);
//    2. the longest pause and fastest burst drive the reported zone;
//    3. zones map to opening/middle/close thirds of the normalized timeline;
//    4. a filler "cluster" requires >= 2 in one zone (single stray filler is
//       not a cluster) and ties resolve to the earlier zone deterministically;
//    5. the readout names ONLY the signals that are present.

import Testing
import Foundation
@testable import Noum

@Suite("RepEventLocationsEngineTests")
struct RepEventLocationsEngineTests {

    private func word(_ text: String, isFiller: Bool, position: Double) -> TranscriptTimeline.Word {
        TranscriptTimeline.Word(text: text, start: 0, end: 0, isFiller: isFiller, position: position)
    }

    private func pause(duration: TimeInterval, position: Double) -> TranscriptTimeline.Pause {
        TranscriptTimeline.Pause(start: 0, end: duration, isFilled: false, position: position)
    }

    private func burst(wpm: Double, position: Double) -> TranscriptTimeline.Burst {
        TranscriptTimeline.Burst(start: 0, end: 1, wpm: wpm, wordCount: 5, position: position)
    }

    /// In a real rep, pauses and bursts are derived FROM the word stream, so a
    /// timeline carrying them always has words. The default supplies two plain
    /// (non-filler) words so pause/burst-only cases stay realistic; filler
    /// cases pass their own `words` array.
    private func timeline(
        words: [TranscriptTimeline.Word] = [
            TranscriptTimeline.Word(text: "the", start: 0, end: 0, isFiller: false, position: 0.0),
            TranscriptTimeline.Word(text: "end", start: 0, end: 0, isFiller: false, position: 1.0)
        ],
        pauses: [TranscriptTimeline.Pause] = [],
        bursts: [TranscriptTimeline.Burst] = []
    ) -> TranscriptTimeline {
        TranscriptTimeline(duration: 10, words: words, pauses: pauses, bursts: bursts)
    }

    // 1 — nil guards --------------------------------------------------------

    @Test("Empty timeline derives nil")
    func emptyDerivesNil() {
        #expect(RepEventLocationsEngine.derive(timeline: .empty) == nil)
    }

    @Test("Words but no pause, burst, or filler cluster derives nil")
    func noCredibleSignalDerivesNil() {
        let result = RepEventLocationsEngine.derive(
            timeline: timeline(words: [
                word("hello", isFiller: false, position: 0.1),
                word("there", isFiller: false, position: 0.5),
                word("um", isFiller: true, position: 0.9) // a single stray filler
            ])
        )
        #expect(result == nil)
    }

    // 2/3 — pause + burst zone ---------------------------------------------

    @Test("Longest pause drives the pause zone and seconds")
    func longestPauseWins() {
        let result = RepEventLocationsEngine.derive(
            timeline: timeline(pauses: [
                pause(duration: 0.6, position: 0.8),   // close, shorter
                pause(duration: 1.2, position: 0.1)    // opening, longest
            ])
        )
        #expect(result?.longestPauseZone == .opening)
        #expect(result?.longestPauseSeconds == 1.2)
    }

    @Test("Fastest burst drives the burst zone and wpm")
    func fastestBurstWins() {
        let result = RepEventLocationsEngine.derive(
            timeline: timeline(bursts: [
                burst(wpm: 155, position: 0.2),   // opening, slower
                burst(wpm: 178, position: 0.9)    // close, fastest
            ])
        )
        #expect(result?.rushedBurstZone == .close)
        #expect(result?.rushedBurstWPM == 178)
    }

    @Test("Zone thirds map opening / middle / close")
    func zoneThirds() {
        #expect(RepEventLocations.Zone.of(position: 0.0) == .opening)
        #expect(RepEventLocations.Zone.of(position: 0.33) == .opening)
        #expect(RepEventLocations.Zone.of(position: 0.34) == .middle)
        #expect(RepEventLocations.Zone.of(position: 0.66) == .middle)
        #expect(RepEventLocations.Zone.of(position: 0.67) == .close)
        #expect(RepEventLocations.Zone.of(position: 1.0) == .close)
    }

    // 4 — filler cluster floor + determinism -------------------------------

    @Test("Two fillers in one zone form a cluster; the dominant zone wins")
    func fillerClusterRequiresTwo() {
        let result = RepEventLocationsEngine.derive(
            timeline: timeline(words: [
                word("um", isFiller: true, position: 0.70),   // close
                word("uh", isFiller: true, position: 0.85),   // close
                word("er", isFiller: true, position: 0.90),   // close -> 3
                word("um", isFiller: true, position: 0.10)    // opening -> 1, not a cluster
            ])
        )
        #expect(result?.fillerClusterZone == .close)
        #expect(result?.fillerClusterCount == 3)
    }

    @Test("A single filler is not a cluster")
    func singleFillerIsNotCluster() {
        let result = RepEventLocationsEngine.derive(
            timeline: timeline(
                words: [word("um", isFiller: true, position: 0.5)],
                pauses: [pause(duration: 0.7, position: 0.5)] // a real signal so derive is non-nil
            )
        )
        #expect(result?.fillerClusterZone == nil)
        #expect(result?.fillerClusterCount == nil)
    }

    @Test("Equal filler counts across zones resolve to the earlier zone")
    func fillerClusterTieBreaksToEarlierZone() {
        let result = RepEventLocationsEngine.derive(
            timeline: timeline(words: [
                word("um", isFiller: true, position: 0.10),  // opening
                word("uh", isFiller: true, position: 0.20),  // opening -> 2
                word("um", isFiller: true, position: 0.80),  // close
                word("uh", isFiller: true, position: 0.90)   // close -> 2 (tie)
            ])
        )
        #expect(result?.fillerClusterZone == .opening)
        #expect(result?.fillerClusterCount == 2)
    }

    // 5 — readout honesty ---------------------------------------------------

    @Test("Readout names only the present signals")
    func readoutNamesOnlyPresent() {
        let result = RepEventLocationsEngine.derive(
            timeline: timeline(pauses: [pause(duration: 1.0, position: 0.1)])
        )
        let readout = result?.readout ?? ""
        #expect(readout.contains("longest silence"))
        #expect(readout.contains("opening"))
        #expect(!readout.contains("fastest stretch"))
        #expect(!readout.contains("fillers clustered"))
    }

    @Test("All three signals appear together in the readout")
    func readoutCombinesSignals() {
        let result = RepEventLocationsEngine.derive(
            timeline: timeline(
                words: [
                    word("um", isFiller: true, position: 0.45),
                    word("uh", isFiller: true, position: 0.50)
                ],
                pauses: [pause(duration: 1.0, position: 0.1)],
                bursts: [burst(wpm: 170, position: 0.9)]
            )
        )
        let readout = result?.readout ?? ""
        #expect(readout.contains("fastest stretch"))
        #expect(readout.contains("longest silence"))
        #expect(readout.contains("fillers clustered"))
        #expect(result?.rushedBurstZone == .close)
        #expect(result?.longestPauseZone == .opening)
        #expect(result?.fillerClusterZone == .middle)
    }
}
