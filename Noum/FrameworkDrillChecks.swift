import Foundation

// MARK: - Framework Drill Checks
//
// Deterministic, pure structural detectors for the named-framework
// deliberate-practice drills introduced in the Coach-Parity exercise library:
//
//   • STAR / narrative "turn"     (story.starTurn      — .answerDevelopment)
//   • Persuasion claim / counter  (structure.claimCounter — .structure)
//   • Claim / evidence / warrant  (structure.claimEvidenceWarrant — .structure)
//   • Monroe's Sequence           (structure.monroeSequence — .structure)
//   • Timed elevator pitch        (concise.elevatorPitch  — .conciseSpeaking)
//   • Reframe / bridge (curveball)(structure.bridgeReframe — .structure)
//   • AREA answer scaffold        (depth.areaAnswer    — .answerDevelopment)
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

    /// First index after `lowerBound` at which any phrase appears as a whole
    /// run. Used by ordered multi-beat frameworks such as Monroe's Sequence.
    private static func firstIndex(of phrases: [String], after lowerBound: Int, in padded: String) -> Int? {
        var best: Int? = nil
        for phrase in phrases {
            var searchStart = padded.startIndex
            while let r = padded.range(of: " \(phrase) ", range: searchStart..<padded.endIndex) {
                let offset = padded.distance(from: padded.startIndex, to: r.lowerBound)
                if offset > lowerBound {
                    if best == nil || offset < best! { best = offset }
                    break
                }
                searchStart = r.upperBound
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

    // MARK: - Claim / Evidence / Warrant

    /// The result of the dedicated CEW drill. This deliberately delegates to
    /// the shared `PracticeEvaluator.argumentStructure` read so the app has one
    /// definition of claim / evidence / warrant across Timed insights, context,
    /// and drills. "Warrant" maps to the existing implication / so-what marker:
    /// the line that explains what the evidence means.
    enum ClaimEvidenceWarrantVerdict: Equatable {
        /// Claim + evidence + warrant / implication all present.
        case complete
        /// Claim + warrant present, but no evidence / reason marker.
        case missingEvidence
        /// Claim + evidence present, but no warrant / so-what marker.
        case missingWarrant
        /// A claim was made but neither backed nor carried forward.
        case assertionOnly
    }

    /// Pure. Grade the CEW drill by reusing the shared argument-logic read.
    ///
    /// - `nil` below the shared argument evidence floor or when no lead claim
    ///   exists, preserving the no-confident-negative-on-thin-data invariant.
    /// - `.complete` when claim + evidence + warrant are all present.
    /// - specific constructive misses for the partial spine.
    static func claimEvidenceWarrant(transcript: String) -> ClaimEvidenceWarrantVerdict? {
        let read = PracticeEvaluator.argumentStructure(transcript: transcript)
        guard let verdict = PracticeEvaluator.argumentLogicVerdict(for: read) else { return nil }
        switch verdict {
        case .fullChain:
            return .complete
        case .claimWithSupport:
            return read.hasEvidence ? .missingWarrant : .missingEvidence
        case .assertionOnly:
            return .assertionOnly
        }
    }

    // MARK: - Monroe's Sequence

    /// Monroe's motivated sequence: attention -> need -> satisfaction
    /// (solution) -> visualization -> action. The detector enforces the order
    /// because a persuasive sequence is not just five ingredients; the listener
    /// has to feel the need before the solution, picture the better outcome,
    /// then receive one concrete ask.
    enum MonroeSequenceVerdict: Equatable {
        case complete
        case missingNeed
        case missingSolution
        case missingVisualization
        case missingAction
    }

    /// Need / problem / stakes markers.
    static let monroeNeedMarkers: [String] = [
        "the problem", "problem is", "the challenge", "challenge is",
        "the risk", "risk is", "the cost", "cost is", "what's at stake",
        "what is at stake", "we need", "need to", "we're losing",
        "we are losing", "pain point", "right now"
    ]

    /// Satisfaction / proposed solution markers.
    static let monroeSolutionMarkers: [String] = [
        "my proposal", "i propose", "we should", "the solution",
        "solution is", "the fix", "fix is", "the answer", "answer is",
        "what we do", "what we should do", "here's how", "here is how"
    ]

    /// Visualization markers — picture the better future or consequence.
    static let monroeVisualizationMarkers: [String] = [
        "imagine", "picture", "the result", "this means", "that means",
        "which means", "so we can", "so that", "what this creates",
        "in practice", "you'll see", "you will see", "that would"
    ]

    /// Action markers — one concrete ask / next step.
    static let monroeActionMarkers: [String] = [
        "start by", "the next step", "next step", "today", "this week",
        "approve", "commit to", "choose", "sign up", "join", "act now",
        "book", "schedule", "try it", "pilot", "vote"
    ]

    /// Pure. Grade Monroe's Sequence on ordered persuasive beats.
    ///
    /// Evidence floor: below the content-word floor, return `nil`. Above it,
    /// return the first missing ordered beat. The attention beat is represented
    /// by the lead carrying real content via the shared first-sentence rule; a
    /// zero-content lead has no persuadable hook, so the first meaningful
    /// failure is still `.missingNeed`.
    static func monroeSequence(transcript: String) -> MonroeSequenceVerdict? {
        guard contentWords(transcript).count >= minContentWordsForVerdict else { return nil }

        let lead = PracticeEvaluator.relevanceFirstSentence(in: transcript)
        let leadHasContent = !contentWords(lead).isEmpty
        let padded = " \(normalised(transcript)) "
        let start = -1

        guard leadHasContent,
              let needIndex = firstIndex(of: monroeNeedMarkers, after: start, in: padded) else {
            return .missingNeed
        }
        guard let solutionIndex = firstIndex(of: monroeSolutionMarkers, after: needIndex, in: padded) else {
            return .missingSolution
        }
        guard let visualizationIndex = firstIndex(of: monroeVisualizationMarkers, after: solutionIndex, in: padded) else {
            return .missingVisualization
        }
        guard firstIndex(of: monroeActionMarkers, after: visualizationIndex, in: padded) != nil else {
            return .missingAction
        }
        return .complete
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

    // MARK: - Reframe / bridge (hostile or curveball question)

    /// The result of the acknowledge-then-bridge-to-priority reframe check.
    /// Only asserted ABOVE the evidence floor; `nil` below it. This is the
    /// drillable counterpart to hostility DETECTION (`IMUserMessageSignal`
    /// hostilityScore / `PressureFollowUpTemplates`): a curveball is only worth
    /// detecting if the speaker can practice the move that defuses it.
    enum BridgeReframeVerdict: Equatable {
        /// The speaker acknowledged the question fairly ("that's fair", "I hear
        /// that") and then BRIDGED to the more important issue ("the real
        /// question is…", "what matters more…") — the reframe move landed.
        case reframed
        /// Enough content to judge, but no acknowledge-THEN-bridge-to-priority
        /// move was found. Constructive, NOT punitive: answering a question
        /// head-on is perfectly valid — it simply isn't the bridging move this
        /// drill trains. Never a verdict on whether the answer was *right*.
        case facedDirectly
    }

    /// Acknowledgement markers for a hostile / curveball question — the speaker
    /// concedes the premise fairly BEFORE redirecting. A superset spirit of
    /// `acknowledgementMarkers` (which is tuned to persuasion concessions like
    /// "admittedly"); these add the conversational "fair / I hear you" band that
    /// defuses a loaded question. Whole-run matched. Bare affirmations ("yes",
    /// "sure") are deliberately excluded so the positive verdict stays honest.
    static let reframeAcknowledgementMarkers: [String] = [
        "that's fair", "that is fair", "fair point", "that's a fair point",
        "fair enough", "i hear that", "i hear you", "i get that", "i see that",
        "i understand the concern", "i take your point", "good question",
        "that's a good question", "i appreciate that", "to be fair", "i see why"
    ]

    /// Bridge-to-priority markers — the speaker pivots from the asked question to
    /// the issue that matters MORE. Distinct from the generic contrast band in
    /// `bridgeMarkers` ("but", "however"): a reframe is not just a contrast, it
    /// is an explicit redirect to a more important point. Must appear AFTER an
    /// acknowledgement for the framework to be satisfied.
    static let priorityBridgeMarkers: [String] = [
        "the more important", "more importantly", "the real question",
        "the real issue", "the bigger issue", "the bigger question",
        "the bigger picture", "what matters more", "what really matters",
        "what matters most", "the deeper issue", "the point is",
        "the key point", "what's really", "what we should", "the thing that matters"
    ]

    /// Pure. Detect an acknowledge-then-bridge-to-priority reframe in
    /// `transcript`.
    ///
    /// - `nil` below the content-word floor (no confident negative on thin data).
    /// - `.reframed` when an acknowledgement marker appears and a
    ///   priority-bridge marker appears strictly LATER (ordering enforced —
    ///   concede the question first, then redirect to what matters more).
    /// - `.facedDirectly` when above the floor but that ordering isn't present.
    ///
    /// Ordering is the load-bearing signal, exactly as in `claimCounter`: a bare
    /// "the real question is…" with no prior fair acknowledgement is a pivot the
    /// listener may read as dodging; the acknowledgement is what makes the
    /// reframe land as fair rather than evasive. Erring toward `.facedDirectly`
    /// keeps the positive verdict honest.
    static func bridgeReframe(transcript: String) -> BridgeReframeVerdict? {
        guard contentWords(transcript).count >= minContentWordsForVerdict else { return nil }
        let padded = " \(normalised(transcript)) "
        guard let ackIndex = firstIndex(of: reframeAcknowledgementMarkers, in: padded) else {
            return .facedDirectly
        }
        // A priority-bridge marker that occurs strictly after the acknowledgement.
        // Scan from just past the acknowledgement so an earlier stray bridge
        // can't satisfy the ordering (same technique as `claimCounter`).
        let afterAckStart = padded.index(padded.startIndex, offsetBy: ackIndex + 1)
        let afterAck = String(padded[afterAckStart...])
        let afterAckPadded = " \(afterAck) "
        if contains(any: priorityBridgeMarkers, in: afterAckPadded) {
            return .reframed
        }
        return .facedDirectly
    }

    // MARK: - AREA (Answer · Reason · Example · Answer)

    /// The result of the AREA scaffold check (Answer → Reason → Example →
    /// Answer). Only asserted ABOVE the evidence floor; `nil` below it. AREA is
    /// the answer-development sibling of PREP: lead with the answer, justify it,
    /// ground it in one concrete example, then close by returning to the answer.
    /// The dedicated `structure.claimEvidenceWarrant` drill owns the argument
    /// spine. AREA remains scoped to answer development: lead, justify, ground,
    /// and loop back.
    enum AreaVerdict: Equatable {
        /// All four AREA beats present: a lead answer, a reason marker, a
        /// concrete example, and a closing return to the answer.
        case complete
        /// Above the floor, but the lead (first sentence) carries no content
        /// word — the answer is buried under a pure hedge rather than led. The
        /// first "A" never landed. Constructive, not a verdict on correctness.
        case missingLead
        /// Lead + example present, but no reason marker — asserted and
        /// illustrated, but never justified ("why is this your answer?").
        case missingReason
        /// Lead + reason present, but no concrete example — the most common AREA
        /// gap: a justified claim with nothing to ground it.
        case missingExample
        /// Lead + reason + example present, but no closing return to the answer
        /// — the second "A". The loop never closed back to the point.
        case noClosingLoop
    }

    /// Reason markers — the speaker justifies the answer (the "R" in AREA). Note
    /// "because" is a stop word for content-word COUNTING (so it never inflates
    /// the evidence floor) but survives `normalised` tokenization, so it matches
    /// here as a discourse marker. Whole-run matched.
    static let areaReasonMarkers: [String] = [
        "because", "the reason", "since", "that's why", "that is why",
        "this is why", "which is why", "the reason is", "reason being",
        "due to", "given that"
    ]

    /// Example markers — the speaker grounds the claim in one concrete instance
    /// (the "E" in AREA). Mirrors the spirit of the depth drills' "one concrete
    /// example" target. Whole-run matched.
    static let areaExampleMarkers: [String] = [
        "for example", "for instance", "such as", "case in point",
        "to illustrate", "last week", "last month", "last year",
        "one time", "just yesterday", "in one case", "i remember when"
    ]

    /// Closing-loop markers — the speaker returns to the answer to close (the
    /// second "A" in AREA). Distinct from a mid-answer reason: these are the
    /// recap phrases that land the point again at the end. Whole-run matched.
    static let areaClosingMarkers: [String] = [
        "so that's", "that's why", "which is why", "in short", "to sum up",
        "in summary", "bottom line", "so in the end", "so the answer",
        "the answer is", "so yes", "so no", "that's my answer", "so ultimately",
        "that's the point", "so to recap"
    ]

    /// Pure. Grade an AREA-structured answer on its four beats.
    ///
    /// The lead-answer beat ("A") reuses `PracticeEvaluator.relevanceFirstSentence`
    /// — the SAME first-sentence span the prompt-relevance positional ("lead vs
    /// buried lede") read uses — so "what counts as the lead" is one rule across
    /// surfaces (single source of truth). The lead is satisfied when that first
    /// sentence carries at least one content word, i.e. the answer is actually
    /// led rather than buried under a pure hedge ("well, um, you know…"). A soft
    /// open that still names the answer ("Well, the key is discipline") clears
    /// this — only a zero-content lead fails it, so it stays false-negative-safe.
    ///
    /// Evidence floor: returns `nil` below the shared content-word floor — there
    /// is too little to claim a missing reason / example / closing loop / lead.
    ///
    /// Priority of miss reasons when not `.complete`:
    ///   1. `.missingLead`    — the answer was buried (no content in the lead).
    ///   2. `.missingReason`  — the logical backbone (no "why").
    ///   3. `.missingExample` — nothing concrete to ground the claim.
    ///   4. `.noClosingLoop`  — never returned to the answer to close.
    static func areaAnswer(transcript: String) -> AreaVerdict? {
        guard contentWords(transcript).count >= minContentWordsForVerdict else { return nil }
        // "A" — the lead answer. Anchor the lead span to the shared first-
        // sentence rule (single source of truth with the prompt-relevance read).
        let lead = PracticeEvaluator.relevanceFirstSentence(in: transcript)
        let leadHasContent = !contentWords(lead).isEmpty
        let padded = " \(normalised(transcript)) "
        let hasReason = contains(any: areaReasonMarkers, in: padded)
        let hasExample = contains(any: areaExampleMarkers, in: padded)
        let hasClosing = contains(any: areaClosingMarkers, in: padded)

        if !leadHasContent { return .missingLead }
        if !hasReason { return .missingReason }
        if !hasExample { return .missingExample }
        if !hasClosing { return .noClosingLoop }
        return .complete
    }
}
