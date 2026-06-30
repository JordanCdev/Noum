//
//  RepTimelineCardTests.swift
//  NoumTests
//
//  Locks the data → user-facing-text contract of the rep timeline render
//  (RepTimelineCard). The SwiftUI body itself is felt-QA-gated, but the copy it
//  shows is pure (RepTimelineCopy) and tested here:
//    1. summaryLine reuses the engine's readout verbatim minus its internal
//       prefix, capitalized — never invents a claim the model didn't make;
//    2. accessibilityReadout names EXACTLY the present signals (fastest →
//       pause → fillers), omitting absent ones, so VoiceOver can't announce a
//       finding the card didn't draw;
//    3. formatSeconds matches the sibling cards' boundary;
//    4. end-to-end: a real TranscriptTimeline → RepEventLocationsEngine.derive
//       → RepTimelineCopy names the right zones, so the visible read and the
//       coach's positional prompt block can never diverge.

import Testing
import Foundation
@testable import Noum

@Suite("RepTimelineCardTests")
struct RepTimelineCardTests {

    private func locations(
        longestPauseZone: RepEventLocations.Zone? = nil,
        longestPauseSeconds: Double? = nil,
        rushedBurstZone: RepEventLocations.Zone? = nil,
        rushedBurstWPM: Double? = nil,
        fillerClusterZone: RepEventLocations.Zone? = nil,
        fillerClusterCount: Int? = nil,
        readout: String = "Positional read (most-recent rep): test."
    ) -> RepEventLocations {
        RepEventLocations(
            longestPauseZone: longestPauseZone,
            longestPauseSeconds: longestPauseSeconds,
            rushedBurstZone: rushedBurstZone,
            rushedBurstWPM: rushedBurstWPM,
            fillerClusterZone: fillerClusterZone,
            fillerClusterCount: fillerClusterCount,
            readout: readout
        )
    }

    // 1 — summaryLine -------------------------------------------------------

    @Test("summaryLine strips the internal prefix and capitalizes")
    func summaryLineStripsPrefix() {
        let line = RepTimelineCopy.summaryLine(for: locations(
            readout: "Positional read (most-recent rep): the fastest stretch ran in the close."
        ))
        #expect(line == "The fastest stretch ran in the close.")
    }

    @Test("summaryLine leaves a readout without the prefix intact (still capitalized)")
    func summaryLineWithoutPrefix() {
        let line = RepTimelineCopy.summaryLine(for: locations(readout: "fillers clustered late."))
        #expect(line == "Fillers clustered late.")
    }

    // 2 — accessibilityReadout ---------------------------------------------

    @Test("accessibilityReadout names all three signals in draw order")
    func a11yAllThree() {
        let read = RepTimelineCopy.accessibilityReadout(for: locations(
            longestPauseZone: .opening, longestPauseSeconds: 1.4,
            rushedBurstZone: .close, rushedBurstWPM: 168,
            fillerClusterZone: .middle, fillerClusterCount: 3
        ))
        #expect(read == "Where it landed. fastest stretch 168 wpm in the close, longest pause 1.4s in the opening, fillers ×3 in the middle.")
    }

    @Test("accessibilityReadout omits absent signals")
    func a11ySingleSignal() {
        let read = RepTimelineCopy.accessibilityReadout(for: locations(
            rushedBurstZone: .close, rushedBurstWPM: 172
        ))
        #expect(read == "Where it landed. fastest stretch 172 wpm in the close.")
        #expect(!read.contains("pause"))
        #expect(!read.contains("fillers"))
    }

    // 3 — formatSeconds boundary -------------------------------------------

    @Test("formatSeconds matches sibling-card boundary at 10s")
    func formatSecondsBoundary() {
        #expect(RepTimelineCopy.formatSeconds(1.4) == "1.4s")
        #expect(RepTimelineCopy.formatSeconds(9.9) == "9.9s")
        #expect(RepTimelineCopy.formatSeconds(12) == "12s")
    }

    // 4 — end-to-end engine → copy -----------------------------------------

    @Test("engine-derived locations render a coherent positional read")
    func endToEndFromTimeline() {
        // A rep that rushes at the close and clusters fillers in the opening.
        let timeline = TranscriptTimeline(
            duration: 10,
            words: [
                TranscriptTimeline.Word(text: "um", start: 0, end: 0, isFiller: true, position: 0.05),
                TranscriptTimeline.Word(text: "uh", start: 0, end: 0, isFiller: true, position: 0.10),
                TranscriptTimeline.Word(text: "so", start: 0, end: 0, isFiller: false, position: 0.50),
                TranscriptTimeline.Word(text: "done", start: 0, end: 0, isFiller: false, position: 1.0)
            ],
            pauses: [],
            bursts: [TranscriptTimeline.Burst(start: 0, end: 1, wpm: 190, wordCount: 6, position: 0.9)]
        )
        let derived = RepEventLocationsEngine.derive(timeline: timeline)
        #expect(derived != nil)
        guard let derived else { return }

        let read = RepTimelineCopy.accessibilityReadout(for: derived)
        // Fastest burst landed in the close; the >=2 filler cluster in the opening.
        #expect(read.contains("fastest stretch 190 wpm in the close"))
        #expect(read.contains("fillers ×2 in the opening"))
        // No pause was present, so the read must not claim one.
        #expect(!read.contains("longest pause"))

        // The visible summary line is exactly the engine's own readout (deprefixed),
        // so the render can never drift from the coach's positional prompt block.
        let summary = RepTimelineCopy.summaryLine(for: derived)
        #expect(summary.hasSuffix("."))
        #expect(!summary.contains("Positional read (most-recent rep):"))
    }
}
