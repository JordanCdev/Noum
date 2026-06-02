import Foundation

// MARK: - Framework Drill Checks
//
// Deterministic, pure structural detectors for the three named-framework
// deliberate-practice drills introduced in the Coach-Parity exercise library:
//
//   • STAR / narrative "turn"     (story.starTurn      — .answerDevelopment)
//   • Persuasion claim / counter  (structure.claimCounter — .structure)
//   • Timed elevator pitch        (concise.elevatorPitch  — .conciseSpeaking)
//
// These are the deterministically VERIFIABLE subset of the named-exercise
// library a human coach owns. Each drill carries a named framework + an
// observable target stated BEFORE the rep (modelled in the `DrillVariation`
// catalog entries in `DrillSystem.swift`); these detectors check whether the
// observable target was actually hit, then surface ONE constructive structural
// nudge through the mini-drill copy seam (`DrillCompletionCopy`). They never
// move the deterministic numeric outcome (XP / `succeeded`) — they read the
// transcript post-hoc, exactly like the prompt-relevance note seam
// (`FeedbackEngine.buildPromptRelevanceNote`).
//
// Design contract (mirrors the proven post-hoc-grounding pattern):
//
//   GROUNDING GATE / HIGH EVIDENCE FLOOR — every detector is a conservative,
//   bounded discourse-marker reducer. Below the floor it returns `nil` (no
//   assertion): it NEVER emits a confident negative ("no turn", "one-sided")
//   on thin data. Lexical association is never described as causation.
//
//   DETERMINISTIC / OFFLINE / LOCALE-SAFE — pure functions over the transcript
//   and duration. No I/O, no singletons, no AI, no locale gate needed: they
//   run identically offline and in any locale (the drills themselves carry a
//   `LocaleSettingsManager.shared.current.aiSupported` gate only if/when an
//   optional LLM enrichment is layered on; the structural verdict here is the
//   deterministic floor).
//
//   SINGLE SOURCE OF TRUTH — the content-word tokenizer reuses
//   `PracticeEvaluator.relevanceContentWords`, the exact same helper the
//   prompt-answer verdict reads, so "what counts as a content word" is one rule
//   across the prompt relevance verdict and these structural checks. No forked
//   tokenizer / stop set. (These detectors scan the whole transcript for
//   discourse markers rather than the lead specifically, so they do not need
//   the `relevanceFirstSentence` split the positional BLUF verdict uses.)
//
// Every threshold is a named constant locked by a test in
// `FrameworkDrillCheckTests`.

enum FrameworkDrillChecks {

    // MARK: - Shared evidence floor

    /// Minimum distinct content words (post `relevanceContentWords` stop-filter)
    /// before ANY structural verdict is asserted. Below this the transcript is
    /// too thin to claim a missing turn / one-sided argument / hookless pitch —
    /// the detector returns `nil` (tentative, never punitive). Chosen to match
    /// the spirit of `minTranscriptWordsForRelevance` (12 raw words) while
    /// counting only content words, so a one-line fragment can never earn a
    /// confident negative.
    static let minContentWordsForVerdict: Int = 6

    /// Content words of `text` using the shared prompt-relevance tokenizer.
    /// Single source of truth — no forked stop set.
    private static func contentWords(_ text: String) -> [String] {
        PracticeEvaluator.relevanceContentWords(in: text)
    }

    /// Lowercased, punctuation-stripped transcript for phrase scanning. Every
    /// character that is not a letter, number, or apostrophe is mapped to a
    /// space, then runs of whitespace collapse to a single space. This is what
    /// lets multi-word discourse markers ("but then", "that said") and
    /// contractions ("i'm", "it's true that", "that's when") match as whole
    /// runs regardless of the transcript's commas/periods/spacing — without it,
    /// "i'm," (trailing comma) would never match the bare marker "i'm". The
    /// apostrophe is deliberately preserved so contraction markers survive.
    /// Pure.
    private static func normalised(_ text: String) -> String {
        // Fold the curly apostrophe (U+2019) onto the straight one so
        // contraction markers match regardless of how the transcriber renders
        // the quote.
        let folded = text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        let scrubbed = String(folded.map { ch -> Character in
            (ch.isLetter || ch.isNumber || ch == "'") ? ch : " "
        })
        return scrubbed
            .split(whereSeparator: { $0 == " " })
            .joined(separator: " ")
    }

    /// First index (in the normalised string) at which any of `phrases`
    /// appears as a whole run, or nil. Used to enforce ORDERING (acknowledge
    /// before bridge) by comparing returned offsets. Word-boundary-aware via
    /// space padding so "but" doesn't match inside "contribute".
    private static func firstIndex(of phrases: [String], in padded: String) -> Int? {
        var best: Int? = nil
        for phrase in phrases {
            if let r = padded.range(of: " \(phrase) ") {
                let offset = padded.distance(from: padded.startIndex, to: r.lowerBound)
                if best == nil || offset < best! { best = offset }
            }
        }
        return best
    }

    /// True when any of `phrases` appears as a whole run in the padded string.
    private static func contains(any phrases: [String], in padded: String) -> Bool {
        for phrase in phrases where padded.contains(" \(phrase) ") { return true }
        return false
    }

    // MARK: - STAR / narrative "turn"

    /// The result of the STAR turn-check. `.turnDetected` and `.flat` are only
    /// ever returned ABOVE the evidence floor; below it the detector returns
    /// `nil` (no assertion) so a short answer never earns a confident "no turn".
    enum StarTurnVerdict: Equatable {
        /// A discourse shift was found — the narrative pivots (setup -> turn).
        case turnDetected
        /// Enough content to judge, but no shift marker — reads as a flat
        /// description, not a story with a turn. Constructive, not punitive.
        case flat
    }

    /// Discourse-shift markers that signal the narrative "turn" — the moment a
    /// setup pivots into change. Multi-word phrases are listed so they match as
    /// whole runs. Conservative on purpose: a strong, unambiguous shift band.
    /// `then` / `and then` alone are intentionally EXCLUDED — pure sequencing
    /// ("first I did X and then Y") is not a turn; we require a contrast or
    /// rupture marker.
    static let turnMarkers: [String] = [
        "but then", "until", "then everything", "then suddenly", "suddenly",
        "that's when", "all of a sudden", "out of nowhere", "before i knew it",
        "everything changed", "things changed", "turning point",
        "and that's when", "until one day", "but everything"
    ]

    /// Pure. Detect a narrative turn in `transcript`.
    ///
    /// - `nil` below the content-word floor (no confident negative on thin data).
    /// - `.turnDetected` when a discourse-shift marker is present.
    /// - `.flat` when above the floor but no shift marker — a flat description.
    static func starTurn(transcript: String) -> StarTurnVerdict? {
        guard contentWords(transcript).count >= minContentWordsForVerdict else { return nil }
        let padded = " \(normalised(transcript)) "
        if contains(any: turnMarkers, in: padded) { return .turnDetected }
        return .flat
    }

    // MARK: - Persuasion claim / counter

    /// The result of the claim/counter (acknowledge-then-bridge) check. Only
    /// asserted ABOVE the evidence floor; `nil` below it.
    enum ClaimCounterVerdict: Equatable {
        /// The speaker acknowledged a counter-position and then bridged back to
        /// their claim — the framework is satisfied.
        case counterAcknowledged
        /// Enough content to judge, but the argument was one-sided — no
        /// acknowledged counter before a bridge. Constructive nudge, not a
        /// verdict on correctness.
        case oneSided
    }

    /// Acknowledgement markers — the speaker concedes / names a counter-view.
    /// Explicit concession phrases only. Bare affirmations ("yes", "sure") are
    /// deliberately excluded: erring toward false negatives keeps the positive
    /// "counter acknowledged" verdict honest (matching the EloquenceEngine
    /// false-negative-preferred philosophy).
    static let acknowledgementMarkers: [String] = [
        "although", "though", "admittedly", "granted", "to be fair",
        "some would say", "some might say", "some argue", "some people",
        "critics say", "critics would", "you might think", "you could argue",
        "on one hand", "on the one hand", "it's true that", "while it's true",
        "i'll admit", "i will admit", "fair enough", "i get that"
    ]

    /// Bridge markers — the speaker pivots back from the counter to their claim.
    /// Must appear AFTER an acknowledgement for the framework to be satisfied.
    static let bridgeMarkers: [String] = [
        "but", "however", "still", "yet", "nevertheless", "nonetheless",
        "even so", "that said", "that being said", "the truth is",
        "the reality is", "what matters", "the key point", "ultimately",
        "in the end", "the bigger picture"
    ]

    /// Pure. Detect an acknowledge-then-bridge persuasion move in `transcript`.
    ///
    /// - `nil` below the content-word floor.
    /// - `.counterAcknowledged` when an acknowledgement marker appears and a
    ///   bridge marker appears strictly LATER in the transcript (ordering
    ///   enforced — concede first, then return to the claim).
    /// - `.oneSided` when above the floor but that ordering isn't present.
    ///
    /// Ordering is the load-bearing signal: a bare "but" with no prior
    /// concession is just a continuation, not a counter-acknowledgement, so it
    /// does NOT satisfy the framework. This keeps the positive verdict honest.
    static func claimCounter(transcript: String) -> ClaimCounterVerdict? {
        guard contentWords(transcript).count >= minContentWordsForVerdict else { return nil }
        let padded = " \(normalised(transcript)) "
        guard let ackIndex = firstIndex(of: acknowledgementMarkers, in: padded) else {
            return .oneSided
        }
        // Find a bridge marker that occurs strictly after the acknowledgement.
        // Scan from just past the acknowledgement so an earlier stray bridge
        // can't satisfy the ordering.
        let afterAckStart = padded.index(padded.startIndex, offsetBy: ackIndex + 1)
        let afterAck = String(padded[afterAckStart...])
        let afterAckPadded = " \(afterAck) "
        if contains(any: bridgeMarkers, in: afterAckPadded) {
            return .counterAcknowledged
        }
        return .oneSided
    }

    // MARK: - Timed elevator pitch

    /// Lower bound (seconds) for a real elevator pitch. Below this it's a
    /// fragment, not a pitch — verdict is `nil` (no assertion) when also thin.
    static let elevatorMinSeconds: TimeInterval = 8
    /// Upper bound (seconds) of the time box. A pitch that runs past this
    /// missed the "timed" target — the whole point of the drill.
    static let elevatorMaxSeconds: TimeInterval = 30
    /// Word-count ceiling for a pitch to read as a single concise hook rather
    /// than a rambling intro. ~30s of speech at a brisk 150 WPM is ~75 words;
    /// we cap a touch above to allow a fast talker who still landed in the box.
    static let elevatorMaxWords: Int = 85
    /// Minimum content words for the pitch to carry a concrete hook (a name
    /// plus at least a few substantive words). Reuses the shared floor.
    static let elevatorMinContentWords: Int = minContentWordsForVerdict

    /// The result of the elevator-pitch check. Only `.landed` and the specific
    /// miss reasons are asserted ABOVE the evidence floor; `nil` below it.
    enum ElevatorPitchVerdict: Equatable {
        /// Named self + a concrete hook + landed inside the time box. Pass.
        case landed
        /// Strong on substance + named, but ran past the time box.
        case overTime
        /// Named + in the box, but no concrete hook (too thin to be a pitch).
        case missingHook
        /// In the box with a hook, but never named themselves — an elevator
        /// pitch is a self-introduction; the name is the observable target.
        case missingName
    }

    /// Self-naming markers — the speaker introduces who they are. Whole-run
    /// matched, so "i'm" / "i am" / "my name is" trigger but a mid-sentence
    /// "i am sure" still counts as a self-name (acceptable: it is still the
    /// speaker referring to themselves at the open of a self-intro). The
    /// `name`-specific phrases anchor the strongest signal.
    static let selfNameMarkers: [String] = [
        "my name is", "i'm", "i am", "this is", "call me", "i go by"
    ]

    /// Pure. Grade an elevator pitch on its three observable targets:
    /// named self, a single concrete hook, and landing inside the time box.
    ///
    /// Evidence floor: returns `nil` when the rep is BOTH too short (under
    /// `elevatorMinSeconds`) AND too thin (under `elevatorMinContentWords`) —
    /// there is nothing to grade, so no assertion. A rep that clears either
    /// bar is graded (a 5-second but content-rich blip, or a long-but-empty
    /// ramble, both get an honest read).
    ///
    /// Priority of miss reasons when not `.landed`:
    ///   1. `.missingName` — the defining target of a self-intro.
    ///   2. `.overTime`    — blew the time box.
    ///   3. `.missingHook` — no concrete substance.
    static func elevatorPitch(transcript: String, duration: TimeInterval) -> ElevatorPitchVerdict? {
        let contentCount = contentWords(transcript).count
        // No assertion when there's genuinely nothing to grade.
        if duration < elevatorMinSeconds && contentCount < elevatorMinContentWords {
            return nil
        }

        let padded = " \(normalised(transcript)) "
        let named = contains(any: selfNameMarkers, in: padded)
        let hasHook = contentCount >= elevatorMinContentWords
        let wordCount = transcript.split { !$0.isLetter && !$0.isNumber }.count
        let inBox = duration <= elevatorMaxSeconds && wordCount <= elevatorMaxWords

        if !named { return .missingName }
        if !inBox { return .overTime }
        if !hasHook { return .missingHook }
        return .landed
    }
}
