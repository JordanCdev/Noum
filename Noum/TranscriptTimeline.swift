import Foundation

// MARK: - Transcript Timeline
//
// Render-ready annotation of a single rep's word stream — the data substrate
// behind an *annotated transcript timeline* (the signature review surface in
// Speeko / Yoodli: the transcript shown back with every filler highlighted in
// place, every silent beat drawn as a real-duration gap, and rushed stretches
// flagged where they actually happened).
//
// Noum already captures the raw per-word timings every `TranscriptionProvider`
// emits (`TranscriptUpdate.WordTiming`), but today those timings are consumed
// once by `PauseMetrics` and then discarded (see `SpeechRecognizerViewModel`:
// "Word timings stay transient — we don't persist them"). So the app knows
// *how many* pauses a rep had, but can never SHOW the user *where* they fell.
// This engine is the pure transform that turns the word stream into a typed,
// plottable timeline. It is deliberately:
//
// - **Pure** — no view, persistence, or provider coupling, so it is unit
//   testable in isolation and free of collision with the live coach surface.
// - **Reuse-first** — segmentation uses the existing `PauseMetrics.minPauseSeconds`
//   threshold and burst detection uses the existing `ConversationalPaceBand`
//   upper edge. No new tuning constants are introduced beyond a documented
//   sample-size guard (so a one- or two-word fragment can never be branded a
//   "rushed burst" — CLAUDE.md: avoid fake certainty from small samples).
// - **Honest about its inputs** — filler classification is a lowercased
//   token match against the set the caller's `FillerWordDetector` already
//   produced, exactly mirroring how `PauseMetrics` decides a pause is
//   "filled". The two reads can therefore never disagree.
//
// The on-session persistence of these timings and the SwiftUI render of the
// timeline are a separate, device-felt-QA'd slice; this file ships only the
// substrate so it can land collision-free and fully verified.

struct TranscriptTimeline: Equatable {
    /// Total rep span in seconds, from the first word's start to the last
    /// word's end. 0 when there are no words.
    let duration: TimeInterval
    let words: [Word]
    let pauses: [Pause]
    let bursts: [Burst]

    /// A single transcribed word, positioned on the rep's 0...1 timeline.
    struct Word: Equatable {
        let text: String
        let start: TimeInterval
        let end: TimeInterval
        /// True when this token matched the filler set the caller passed in.
        let isFiller: Bool
        /// Normalized 0...1 midpoint of the word across the rep, for plotting.
        let position: Double
    }

    /// A silent or filled gap between two consecutive words that ran at or
    /// over `PauseMetrics.minPauseSeconds`.
    struct Pause: Equatable {
        let start: TimeInterval
        let end: TimeInterval
        /// True when the word *immediately following* the gap is a filler —
        /// i.e. the silence was bridged with "um"/"uh". Identical in meaning
        /// to `PauseMetrics.filledRatio`'s per-gap classification.
        let isFilled: Bool
        /// Normalized 0...1 midpoint of the gap across the rep, for plotting.
        let position: Double

        var duration: TimeInterval { max(0, end - start) }
    }

    /// A contiguous phrase (a run of words with no qualifying pause inside it)
    /// whose local pace exceeded the conversational band's upper edge. This is
    /// the "you rushed here" annotation — anchored to a real stretch of speech,
    /// not a whole-rep average.
    struct Burst: Equatable {
        let start: TimeInterval
        let end: TimeInterval
        let wpm: Double
        let wordCount: Int
        /// Normalized 0...1 midpoint of the burst across the rep, for plotting.
        let position: Double
    }

    /// A phrase shorter than this (in words) is never classified as a burst,
    /// so transient fast fragments ("and-then-I") don't read as a rushed
    /// stretch. A sample-size floor, not a pace tuning knob.
    static let minBurstWords = 4

    static let empty = TranscriptTimeline(
        duration: 0,
        words: [],
        pauses: [],
        bursts: []
    )

    // MARK: Derived counts (convenience for a future summary/render)

    var fillerCount: Int { words.filter(\.isFiller).count }
    var pauseCount: Int { pauses.count }
    var filledPauseCount: Int { pauses.filter(\.isFilled).count }
    var burstCount: Int { bursts.count }
    var isEmpty: Bool { words.isEmpty }

    // MARK: - Build

    /// Build the timeline from the rep's captured word timings.
    ///
    /// - Parameters:
    ///   - words: the provider's per-word timings for the whole rep, in any
    ///     order (sorted internally by start time).
    ///   - fillerWords: lowercased bare tokens the `FillerWordDetector`
    ///     classified as fillers this rep. A word is flagged when its
    ///     normalized form (lowercased, surrounding punctuation stripped)
    ///     is in this set — the same text-match contract `PauseMetrics` uses.
    init(words rawWords: [TranscriptUpdate.WordTiming], fillerWords: Set<String>) {
        let sorted = rawWords.sorted { $0.startTime < $1.startTime }
        guard let first = sorted.first, let last = sorted.last else {
            self = .empty
            return
        }

        let origin = first.startTime
        let span = max(0, last.endTime - origin)
        // Normalize a timestamp to 0...1 across the rep; collapses to 0 when
        // the whole rep occupied a single instant (degenerate provider data).
        func normalize(_ time: TimeInterval) -> Double {
            guard span > 0 else { return 0 }
            return min(1, max(0, (time - origin) / span))
        }

        func isFiller(_ word: TranscriptUpdate.WordTiming) -> Bool {
            let token = word.word
                .lowercased()
                .trimmingCharacters(in: .punctuationCharacters)
            return !token.isEmpty && fillerWords.contains(token)
        }

        // Words ---------------------------------------------------------------
        let builtWords: [Word] = sorted.map { word in
            Word(
                text: word.word,
                start: word.startTime,
                end: word.endTime,
                isFiller: isFiller(word),
                position: normalize((word.startTime + word.endTime) / 2)
            )
        }

        // Pauses + phrase boundaries -----------------------------------------
        // A gap >= minPauseSeconds is a pause AND splits the word stream into
        // phrases, the natural unit for local-pace (burst) detection.
        var builtPauses: [Pause] = []
        var phrases: [[TranscriptUpdate.WordTiming]] = []
        var current: [TranscriptUpdate.WordTiming] = sorted.isEmpty ? [] : [sorted[0]]

        if sorted.count >= 2 {
            for index in 1..<sorted.count {
                let prev = sorted[index - 1]
                let word = sorted[index]
                let gap = word.startTime - prev.endTime
                if gap >= PauseMetrics.minPauseSeconds {
                    builtPauses.append(
                        Pause(
                            start: prev.endTime,
                            end: word.startTime,
                            isFilled: isFiller(word),
                            position: normalize((prev.endTime + word.startTime) / 2)
                        )
                    )
                    phrases.append(current)
                    current = [word]
                } else {
                    current.append(word)
                }
            }
        }
        if !current.isEmpty { phrases.append(current) }

        // Bursts --------------------------------------------------------------
        var builtBursts: [Burst] = []
        for phrase in phrases {
            guard phrase.count >= TranscriptTimeline.minBurstWords,
                  let head = phrase.first, let tail = phrase.last else { continue }
            let phraseSpan = tail.endTime - head.startTime
            guard phraseSpan > 0 else { continue }
            let wpm = Double(phrase.count) / (phraseSpan / 60)
            if wpm > ConversationalPaceBand.maxWPM {
                builtBursts.append(
                    Burst(
                        start: head.startTime,
                        end: tail.endTime,
                        wpm: wpm,
                        wordCount: phrase.count,
                        position: normalize((head.startTime + tail.endTime) / 2)
                    )
                )
            }
        }

        self.duration = span
        self.words = builtWords
        self.pauses = builtPauses
        self.bursts = builtBursts
    }

    /// Private memberwise init for the `.empty` constant and tests that need
    /// to assert against a fully-specified timeline.
    init(
        duration: TimeInterval,
        words: [Word],
        pauses: [Pause],
        bursts: [Burst]
    ) {
        self.duration = duration
        self.words = words
        self.pauses = pauses
        self.bursts = bursts
    }
}
