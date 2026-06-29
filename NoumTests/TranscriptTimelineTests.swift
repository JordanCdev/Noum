//
//  TranscriptTimelineTests.swift
//  NoumTests
//
//  ANNOTATED TRANSCRIPT TIMELINE — locks the pure annotation engine that turns
//  the rep's per-word timings (today computed once by PauseMetrics and then
//  discarded) into a typed, plottable timeline of fillers, pauses, and rushed
//  bursts. This is the substrate behind the Speeko/Yoodli signature review
//  surface; the persistence + SwiftUI render are a separate, device-QA'd slice.
//
//  These tests assert STRUCTURAL invariants only — no calibration claim:
//    1. empty / degenerate input is handled without fabricating signal;
//    2. filler flagging matches the lowercased-token contract PauseMetrics uses
//       (incl. punctuation-insensitivity);
//    3. pause detection uses the SAME PauseMetrics.minPauseSeconds threshold and
//       agrees with PauseMetrics.compute on the pause count for the same stream;
//    4. filled vs unfilled pauses classify like PauseMetrics' filledRatio;
//    5. bursts fire only above ConversationalPaceBand.maxWPM AND only for
//       phrases at/over the documented sample-size floor (minBurstWords);
//    6. all normalized positions stay within 0...1 and increase with time.

import Testing
import Foundation
@testable import Noum

@Suite("TranscriptTimelineTests")
struct TranscriptTimelineTests {

    /// Build a word timing. `gapBefore` is the silence inserted before this
    /// word; the helper threads a running clock so callers describe a rep as a
    /// sequence of (word, spokenDuration, gapBefore) without bookkeeping.
    private final class Clock {
        var t: TimeInterval = 0
        func word(_ text: String, dur: TimeInterval = 0.3, gapBefore: TimeInterval = 0) -> TranscriptUpdate.WordTiming {
            t += gapBefore
            let start = t
            t += dur
            return TranscriptUpdate.WordTiming(word: text, startTime: start, endTime: t, confidence: 0.95)
        }
    }

    // 1 — empty / degenerate ------------------------------------------------

    @Test("Empty word stream yields the empty timeline")
    func emptyStream() {
        let timeline = TranscriptTimeline(words: [], fillerWords: [])
        #expect(timeline == .empty)
        #expect(timeline.isEmpty)
        #expect(timeline.duration == 0)
        #expect(timeline.pauseCount == 0)
        #expect(timeline.burstCount == 0)
    }

    @Test("Single word produces one word, no pauses, no bursts")
    func singleWord() {
        let c = Clock()
        let timeline = TranscriptTimeline(words: [c.word("hello")], fillerWords: [])
        #expect(timeline.words.count == 1)
        #expect(timeline.pauses.isEmpty)
        #expect(timeline.bursts.isEmpty)
        #expect(timeline.words.first?.isFiller == false)
    }

    // 2 — filler flagging ---------------------------------------------------

    @Test("Filler flagging is lowercased and punctuation-insensitive")
    func fillerFlagging() {
        let c = Clock()
        let words = [
            c.word("So,"),          // leading filler, trailing comma
            c.word("the"),
            c.word("Um"),           // capitalized filler
            c.word("point"),
        ]
        let timeline = TranscriptTimeline(words: words, fillerWords: ["so", "um"])
        #expect(timeline.fillerCount == 2)
        #expect(timeline.words[0].isFiller)   // "So," -> so
        #expect(!timeline.words[1].isFiller)  // "the"
        #expect(timeline.words[2].isFiller)   // "Um" -> um
        #expect(!timeline.words[3].isFiller)  // "point"
    }

    // 3 — pause threshold + PauseMetrics agreement --------------------------

    @Test("A gap at the minPauseSeconds boundary is a pause; just under is not")
    func pauseThreshold() {
        let c = Clock()
        let words = [
            c.word("one"),
            c.word("two", gapBefore: PauseMetrics.minPauseSeconds),       // exactly at floor -> pause
            c.word("three", gapBefore: PauseMetrics.minPauseSeconds - 0.05), // under -> rhythm
        ]
        let timeline = TranscriptTimeline(words: words, fillerWords: [])
        #expect(timeline.pauseCount == 1)
    }

    @Test("Pause count agrees with PauseMetrics.compute for the same stream")
    func agreesWithPauseMetrics() {
        let c = Clock()
        let words = [
            c.word("the"),
            c.word("answer", gapBefore: 0.8),   // pause
            c.word("is"),
            c.word("um", gapBefore: 1.2),        // filled pause
            c.word("clear"),
        ]
        let timeline = TranscriptTimeline(words: words, fillerWords: ["um"])
        let metrics = PauseMetrics.compute(
            words: words,
            fillerStartTimes: words.filter { $0.word.lowercased() == "um" }.map(\.startTime)
        )
        #expect(timeline.pauseCount == metrics.count)
        #expect(timeline.pauseCount == 2)
    }

    // 4 — filled vs unfilled ------------------------------------------------

    @Test("A pause bridged by a following filler is classified filled")
    func filledPause() {
        let c = Clock()
        let words = [
            c.word("well"),
            c.word("um", gapBefore: 1.0),   // gap then a filler -> filled
            c.word("yes", gapBefore: 1.0),  // gap then a real word -> unfilled
        ]
        let timeline = TranscriptTimeline(words: words, fillerWords: ["um"])
        #expect(timeline.pauseCount == 2)
        #expect(timeline.filledPauseCount == 1)
        let filled = timeline.pauses.filter(\.isFilled)
        #expect(filled.count == 1)
        #expect(filled.first?.duration ?? 0 >= 1.0 - 0.0001)
    }

    // 5 — bursts ------------------------------------------------------------

    @Test("A fast phrase over the pace band's upper edge is a burst")
    func burstFires() {
        let c = Clock()
        // 6 words at 0.15s each, no gaps -> 0.9s for 6 words = 400 wpm, well
        // over ConversationalPaceBand.maxWPM.
        let words = (0..<6).map { c.word("w\($0)", dur: 0.15) }
        let timeline = TranscriptTimeline(words: words, fillerWords: [])
        #expect(timeline.burstCount == 1)
        #expect((timeline.bursts.first?.wpm ?? 0) > ConversationalPaceBand.maxWPM)
        #expect(timeline.bursts.first?.wordCount == 6)
    }

    @Test("A fast phrase under the sample-size floor is NOT a burst")
    func burstSampleGuard() {
        let c = Clock()
        // Only 3 words (< minBurstWords) even though they're fast.
        let words = (0..<3).map { c.word("w\($0)", dur: 0.1) }
        #expect(words.count < TranscriptTimeline.minBurstWords)
        let timeline = TranscriptTimeline(words: words, fillerWords: [])
        #expect(timeline.burstCount == 0)
    }

    @Test("A phrase paced inside the band is NOT a burst")
    func noBurstInBand() {
        let c = Clock()
        // 5 words at 130 wpm target: 60/130 ≈ 0.46s per word.
        let perWord = 60.0 / ConversationalPaceBand.targetWPM
        let words = (0..<5).map { c.word("w\($0)", dur: perWord) }
        let timeline = TranscriptTimeline(words: words, fillerWords: [])
        #expect(timeline.burstCount == 0)
    }

    @Test("A pause splits a fast run so each side is judged on its own pace")
    func pauseSplitsBurstPhrases() {
        let c = Clock()
        // Fast run, a real pause, then a slow run. Only the fast side bursts.
        var words = (0..<5).map { c.word("f\($0)", dur: 0.15) }
        words += (0..<5).map { i in c.word("s\(i)", dur: 0.6, gapBefore: i == 0 ? 1.0 : 0) }
        let timeline = TranscriptTimeline(words: words, fillerWords: [])
        #expect(timeline.pauseCount == 1)
        #expect(timeline.burstCount == 1)
        #expect(timeline.bursts.first?.wordCount == 5)
    }

    // 6 — normalized positions ---------------------------------------------

    @Test("All positions stay within 0...1 and increase with time")
    func positionsNormalized() {
        let c = Clock()
        let words = [
            c.word("first"),
            c.word("middle", gapBefore: 0.6),
            c.word("last", gapBefore: 0.6),
        ]
        let timeline = TranscriptTimeline(words: words, fillerWords: [])
        for word in timeline.words {
            #expect(word.position >= 0 && word.position <= 1)
        }
        let positions = timeline.words.map(\.position)
        #expect(positions == positions.sorted())
        // The first word's *midpoint* sits just after the origin (its start
        // anchors 0, not its center), so it's small but non-zero.
        #expect((timeline.words.first?.position ?? 1) < 0.1)
        #expect((timeline.words.last?.position ?? 0) > 0.5)  // last word near the end
        #expect(timeline.duration > 0)
    }
}
