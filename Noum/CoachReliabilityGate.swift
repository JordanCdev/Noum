import Foundation

// MARK: - Coach reliability gate
//
// The last-mile, deterministic guard that runs on the *final* coach reply, after
// the provider chain and its internal repair/quality loops, right before the text
// is committed to the UI thread (`AskNoumStore.completeCoachTurn`).
//
// Why this exists, when the service already has a quality gate: the existing gates
// fight the model *during* generation (semantic gate, quote guard, repair loops,
// typed-judgement fallback). None of them is a truthful backstop at the pipeline
// boundary. If the last draft the chain produced is still empty, a verbatim repeat
// of the previous coach turn, a leaked scaffold/JSON envelope, or literal
// placeholder text, today it ships as-is — which is exactly the "Noum repeated
// itself / gave me placeholder junk" failure the live-harness artefacts and the
// product screenshots show. A coach that repeats itself or leaks its own internals
// destroys trust instantly; a short honest "I don't have a clean read yet, give me
// one rep" is strictly better than a fake or duplicated answer.
//
// Design split — HARD vs SOFT:
//   • HARD issues (empty / placeholder / duplicateReply / scaffoldLeak /
//     noAttunementOnPushback / thinTrustRepair / repairCarryoverBreak /
//     silentPlanSwitch / repetitiveDiscourseMove) are unambiguous user-facing
//     defects. They BLOCK: the gate substitutes a truthful, coach-shaped
//     fallback (preferring the deterministic on-device read the judgement pass
//     already produced) and records that a fallback was applied.
//   • SOFT issues (nearDuplicateReply / floorConfidenceWithEvidence) are
//     calibration smells the report flagged. They are RECORDED for evals +
//     metadata but never blanket-replace an otherwise-fine reply.
//   • repeatedProofTest is blocking because the deterministic assessment
//     builder already has recent proof-test context and can usually supply a
//     non-repeated local read. Shipping the repeated action anyway is the
//     "same drill assistant" failure users notice immediately.
//
// Pure + flag-guarded (`CoachBrainFlags.reliabilityGateEnabled`, default on) so it
// is fully unit-testable and instantly revertable without a new state owner.

/// A single reliability defect detected on a final coach reply.
enum CoachReliabilityIssue: String, Codable, Equatable, CaseIterable {
    /// The reply is empty (or whitespace-only) after sanitisation.
    case empty
    /// Literal placeholder/scaffold-stub text leaked to the surface.
    case placeholder
    /// The reply is a verbatim (normalised) repeat of the previous coach turn.
    case duplicateReply
    /// The reply is not verbatim-identical but shares a high token overlap with
    /// the previous coach turn — the "it basically said the same thing again"
    /// case that exact-match misses. Recorded only (no false-block UX risk).
    case nearDuplicateReply
    /// Internal pipeline scaffolding (enum raw values, the structured envelope,
    /// the point-reason-example-point label) leaked into the surface text.
    case scaffoldLeak
    /// Confidence is pinned at the floor even though the assessment cites
    /// evidence — the "constant 0.20" smell from the artefacts. Recorded only.
    case floorConfidenceWithEvidence
    /// A trust-repair turn whose opening does not acknowledge the user's push
    /// before prescribing.
    case noAttunementOnPushback
    /// A trust-repair turn that acknowledges the push but skips the actual
    /// repair move before prescribing again.
    case thinTrustRepair
    /// The turn after a substantive trust repair drops back into generic advice
    /// instead of carrying the repaired read forward.
    case repairCarryoverBreak
    /// The reply silently abandons the prior intervention target without an
    /// evidence-backed revision rationale.
    case silentPlanSwitch
    /// The current reply continues a short run of prescription-only coach turns:
    /// varied wording, same discourse move.
    case repetitiveDiscourseMove
    /// The proof-test is the same one offered on a recent turn.
    case repeatedProofTest
    /// The user's turn was a bare greeting / social pleasantry ("hi") but the
    /// reply is a diagnostic coaching drill — the deterministic/fallback path
    /// answering "hello" with a Pressure-Drill read because no live model
    /// replied. A coach greets back; it does not drill a hello.
    case greetingWithDrill

    /// Issues that are unambiguous user-facing defects and therefore trigger the
    /// truthful fallback substitution.
    var isBlocking: Bool {
        switch self {
        case .empty, .placeholder, .duplicateReply, .scaffoldLeak,
                .noAttunementOnPushback, .thinTrustRepair,
                .repairCarryoverBreak, .silentPlanSwitch,
                .repetitiveDiscourseMove, .repeatedProofTest,
                .greetingWithDrill:
            return true
        case .nearDuplicateReply, .floorConfidenceWithEvidence:
            return false
        }
    }
}

/// The gate's decision for one final reply.
struct CoachReliabilityVerdict: Equatable {
    /// Every detected issue, blocking and soft, in detection order.
    var issues: [CoachReliabilityIssue]
    /// Non-nil when a blocking issue fired: the truthful text to render instead.
    var fallbackText: String?

    /// True when a blocking issue fired and a fallback should replace the reply.
    var blocked: Bool { fallbackText != nil }
    /// The blocking subset (drives the "reliability cap" in evals).
    var blockingIssues: [CoachReliabilityIssue] { issues.filter(\.isBlocking) }

    static let clean = CoachReliabilityVerdict(issues: [], fallbackText: nil)
}

enum CoachReliabilityGate {

    /// Confidence at or below this is treated as "pinned at the floor". The
    /// reasoning pass clamps confidence to a 0.20 floor; a hair of epsilon keeps
    /// the comparison robust to floating-point representation.
    static let floorConfidence: Double = 0.205

    /// How many leading characters of a trust-repair reply are scanned for an
    /// acknowledgement marker.
    static let attunementWindow: Int = 140

    /// Token-overlap (Jaccard) at or above this — without being a verbatim
    /// duplicate — marks a reply as a near-duplicate of the previous coach turn.
    /// Deliberately high so genuinely distinct advice is never flagged.
    static let nearDuplicateThreshold: Double = 0.82

    /// Both replies must have at least this many distinct tokens before
    /// near-duplicate similarity is meaningful (short replies have unstable
    /// overlap ratios).
    static let nearDuplicateMinTokens: Int = 8

    // MARK: Detection vocabularies

    /// Literal stubs that must never reach a user. Matched on the lowercased,
    /// whitespace-collapsed surface text. Kept deliberately tight and
    /// unambiguous so real coaching prose can never trip them.
    static let placeholderMarkers: [String] = [
        "full answer coming",
        "coach read coming",
        "response coming",
        "placeholder reply",
        "placeholder response",
        "placeholder text",
        "placeholder copy",
        "lorem ipsum",
        "your response here",
        "insert response",
        "[placeholder",
        "[insert",
        "[todo",
        "todo:",
        "tbd.",
        "<placeholder",
        "xxxxx"
    ]

    /// Internal tokens that only appear when the pipeline leaks its own scaffold
    /// or structured envelope into the surface. The enum raw values are matched
    /// in their concatenated (no-space) form — "trust repair" the phrase is fine
    /// for a coach to say, but "trustrepair" only comes from code.
    static let scaffoldMarkers: [String] = [
        "turndepth",
        "deepassessment",
        "quickmove",
        "groundedread",
        "trustrepair",
        "directverdict",
        "rubricscore",
        "evidencecoverage",
        "responsemode",
        "tonemode",
        "repairfocus",
        "immediatecoachread",
        "assessmentconfidence",
        "point-reason-example-point",
        "pointreasonexamplepoint",
        "\"surfacetext\"",
        "\"verdict\":",
        "\"prooftest\":",
        "\"dialoguestate\""
    ]

    /// Openings that count as acknowledging the user's push on a trust-repair
    /// turn. Absence (not presence of a banned word) is what the gate records.
    static let acknowledgementMarkers: [String] = [
        "fair", "you're right", "youre right", "you are right",
        "i hear", "good push", "that's fair", "thats fair",
        "i missed", "i owe you", "right to push", "right to call",
        "makes sense", "i get it", "valid", "my read was off",
        "let me repair", "let me fix", "let me correct",
        "i was", "i didn't", "i didnt", "you're pushing",
        "i hear that", "i get that", "that's on me", "thats on me"
    ]

    /// Trust repair is more than a polite first word. These markers prove the
    /// reply named the miss, the real question, or a straight corrected read
    /// before returning to prescription.
    static let trustRepairMoveMarkers: [String] = [
        "i missed",
        "i gave you advice",
        "i gave advice",
        "i used too much",
        "i sounded cold",
        "i leaned on generic",
        "i was too generic",
        "that read was",
        "that sounded cold",
        "robotic and cold",
        "too much writing",
        "that was generic",
        "generic advice",
        "too generic",
        "should never",
        "i did not answer",
        "i didn't answer",
        "i didnt answer",
        "answered around",
        "useful read",
        "repeated the same",
        "repeated the same test",
        "changing the evidence",
        "same test",
        "same coaching move",
        "advancing the read",
        "advancing the coaching",
        "sound easier than it feels",
        "easier than it feels",
        "not easy",
        "hard part",
        "close is the leak",
        "under pressure",
        "before answering",
        "before prescribing",
        "before adding another drill",
        "the prior answer",
        "my prior answer",
        "that answer",
        "the miss",
        "the real question",
        "the actual question",
        "the friction",
        "answer the friction",
        "advice, not coaching",
        "not coaching",
        "let me repair",
        "let me fix",
        "let me correct",
        "what i should have said",
        "plain answer:",
        "straight answer:",
        "the real read is",
        "real read:",
        "what matters is"
    ]

    /// Source markers that make the previous coach turn look like a repair, not
    /// just any ordinary coaching reply. Combined with `trustRepairMoveMarkers`
    /// so a bare "fair" cannot raise the follow-up obligation by itself.
    static let trustRepairCarryoverSourceMarkers: [String] = [
        "fair push",
        "you're right",
        "youre right",
        "you are right",
        "right to push",
        "right to call",
        "let me repair",
        "let me fix",
        "let me correct",
        "i missed",
        "that's on me",
        "thats on me",
        "agreed"
    ]

    /// Generic reset/advice phrases that are unacceptable immediately after a
    /// repair. Kept intentionally narrow: specific drills can still follow a
    /// repair, but the broad advice the user just complained about cannot.
    static let repairCarryoverBreakMarkers: [String] = [
        "practice more",
        "keep practicing",
        "communicate clearly",
        "be clear and concise",
        "structure your thoughts",
        "think about your audience",
        "sound more confident",
        "believe in yourself",
        "optimize your communication plan",
        "start with a general communication goal",
        "choose whether you want",
        "what is your priority today",
        "let's reset",
        "lets reset",
        "track your progress over time"
    ]

    /// A good repair may explicitly reject the bad generic phrase. Do not punish
    /// that correction just because the phrase appears.
    static let repairCarryoverSafeNegations: [String] = [
        "not practice more",
        "do not practice more",
        "don't practice more",
        "dont practice more",
        "is not more practice",
        "not more practice",
        "not more volume",
        "not more reps"
    ]

    private enum DiscourseMove: String, CaseIterable {
        case answer
        case attune
        case diagnose
        case evidenceBoundary
        case prescribe
    }

    // MARK: Evaluation

    /// Evaluate a final reply. Pure: no store reads, no clock, no I/O.
    ///
    /// - Parameters:
    ///   - replyText: the model's final surface text (already sanitised by the
    ///     caller via `CoachReplyTextSanitizer`, but re-trimmed here for safety).
    ///   - previousCoachReply: the most recent prior coach turn's text, for the
    ///     verbatim-duplicate check.
    ///   - recentCoachReplies: newest-first prior coach turns, used to detect
    ///     short discourse-move loops that are not lexical duplicates.
    ///   - latestUserTurn: the current user turn, used only for narrow follow-up
    ///     exceptions where the user explicitly asks what exact line to repeat.
    ///   - turnDepth: the classified depth of this turn.
    ///   - assessment: the deterministic judgement object (source of the fallback
    ///     read and the confidence/evidence smell).
    ///   - evidenceCoverage: the trajectory coverage backing this turn.
    ///   - proofTestRecentlyRepeated: the upstream signal that the proof-test
    ///     duplicates a recent one.
    ///   - surface: text vs live (shapes fallback length).
    static func evaluate(
        replyText: String,
        previousCoachReply: String?,
        recentCoachReplies: [String] = [],
        latestUserTurn: String? = nil,
        turnDepth: CoachTurnDepth,
        assessment: CoachAssessment?,
        evidenceCoverage: Double?,
        proofTestRecentlyRepeated: Bool = false,
        surface: CoachReplySurface = .text
    ) -> CoachReliabilityVerdict {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        var issues: [CoachReliabilityIssue] = []

        // --- HARD ---
        if trimmed.isEmpty {
            issues.append(.empty)
        }

        let lowered = normalize(trimmed)
        if !trimmed.isEmpty, containsAny(lowered, placeholderMarkers) {
            issues.append(.placeholder)
        }
        if !trimmed.isEmpty, containsAny(lowered, scaffoldMarkers) {
            issues.append(.scaffoldLeak)
        }
        let normalizedPrevious = previousCoachReply
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : normalize($0) }
        if !trimmed.isEmpty, let normalizedPrevious {
            if normalizedPrevious == lowered {
                issues.append(.duplicateReply)
            } else if isNearDuplicate(lowered, normalizedPrevious) {
                // Not a verbatim repeat, but the model rephrased the same content
                // — the real "same response back" complaint. Recorded only.
                issues.append(.nearDuplicateReply)
            }
            if silentlySwitchesPlan(reply: lowered, previousCoachReply: normalizedPrevious) {
                issues.append(.silentPlanSwitch)
            }
            if breaksRepairCarryover(reply: lowered, previousCoachReply: normalizedPrevious) {
                issues.append(.repairCarryoverBreak)
            }
        }
        if repeatsPrescriptionOnlyMove(
            reply: lowered,
            recentCoachReplies: recentCoachReplies,
            latestUserTurn: latestUserTurn
        ) {
            issues.append(.repetitiveDiscourseMove)
        }

        // --- RECORDED ISSUES ---
        if let assessment,
           assessment.confidence <= floorConfidence,
           assessment.evidenceReferenceCount > 0 {
            issues.append(.floorConfidenceWithEvidence)
        }
        if turnDepth == .trustRepair,
           !trimmed.isEmpty {
            if !openingAcknowledges(trimmed) {
                issues.append(.noAttunementOnPushback)
            } else if lacksTrustRepairMove(trimmed) {
                issues.append(.thinTrustRepair)
            }
        }
        if proofTestRecentlyRepeated {
            issues.append(.repeatedProofTest)
        }
        // A bare greeting/social turn that gets a diagnostic drill (the fallback
        // path answering "hi" with a Pressure-Drill read) is a user-facing defect
        // the prompt+model path would never produce. Detect it here so the gate
        // greets back instead.
        if let latestUserTurn,
           !trimmed.isEmpty,
           TurnDepthClassifier.isGreetingOrSmallTalk(latestUserTurn),
           replyDrillsInsteadOfGreeting(lowered) {
            issues.append(.greetingWithDrill)
        }

        // A greeting mismatch must be answered with a warm hello, NOT the
        // deterministic coaching read (which is itself the drill we are
        // escaping), so it takes priority over the generic truthful fallback.
        let fallback: String?
        if issues.contains(.greetingWithDrill) {
            fallback = greetingFallback(surface: surface)
        } else if issues.contains(where: { $0.isBlocking }) {
            fallback = truthfulFallback(
                turnDepth: turnDepth,
                assessment: assessment,
                surface: surface,
                previousCoachReply: previousCoachReply,
                recentCoachReplies: recentCoachReplies
            )
        } else {
            fallback = nil
        }

        return CoachReliabilityVerdict(issues: issues, fallbackText: fallback)
    }

    /// Markers that only appear when a reply is a diagnostic coaching read /
    /// drill rather than a human greeting: the `immediateCoachRead` template
    /// stems, prescription verbs, drill/metric language, and mode names.
    static let greetingDrillMarkers: [String] = [
        "try this next", "the signal i can use", "next lever", "proof test",
        "run one", "run a", "60-second", "45-second", "next rep", "one rep",
        "put the verdict", "the opening is", "the ending is", "the close is",
        "verdict first", "fillers", "wpm", "/10", "under a timer",
        "pressure drill", "ah-counter", "hedge", "clean stop", "sentence one"
    ]

    /// True when a reply reads as a coaching drill/diagnostic instead of a warm,
    /// brief greeting.
    static func replyDrillsInsteadOfGreeting(_ lowered: String) -> Bool {
        containsAny(lowered, greetingDrillMarkers)
    }

    /// A warm, brief greeting to render when the turn was a hello but the reply
    /// tried to drill. Invites the user back into the work without prescribing —
    /// on a greeting, an open question IS the right move, unlike a coaching turn.
    static func greetingFallback(surface: CoachReplySurface) -> String {
        surface == .live
            ? "Hey — good to see you. Want to keep going, or is something else on your mind?"
            : "Hey — good to see you back. Want to pick up where we left off, or is there something specific on your mind?"
    }

    // MARK: Fallback

    /// The truthful, coach-shaped reply to render when a blocking issue fires.
    ///
    /// Prefers the deterministic on-device read the judgement pass already built
    /// (`assessment.immediateCoachRead`) — that read is generated locally from
    /// real evidence and is clean by construction, so it is a far better recovery
    /// than a dead-end apology. It is only used if it is itself clean (no
    /// placeholder/scaffold leak) and not the very duplicate we are escaping.
    /// Otherwise we fall to an honest, depth-appropriate static line.
    static func truthfulFallback(
        turnDepth: CoachTurnDepth,
        assessment: CoachAssessment?,
        surface: CoachReplySurface,
        previousCoachReply: String?,
        recentCoachReplies: [String] = [],
        latestUserTurn: String? = nil
    ) -> String {
        // A greeting/social turn must never be answered with the deterministic
        // coaching read (which IS a drill). Short-circuit before immediateCoachRead
        // so both the gate path and the content-rejected fallback path greet back.
        if let latestUserTurn,
           TurnDepthClassifier.isGreetingOrSmallTalk(latestUserTurn) {
            return greetingFallback(surface: surface)
        }
        if let assessment {
            let read = assessment.immediateCoachRead.trimmingCharacters(in: .whitespacesAndNewlines)
            if isCleanCandidate(
                read,
                previousCoachReply: previousCoachReply,
                recentCoachReplies: recentCoachReplies
            ) {
                return read
            }
        }
        return selectStaticFallback(
            turnDepth: turnDepth,
            surface: surface,
            previousCoachReply: previousCoachReply,
            recentCoachReplies: recentCoachReplies
        )
    }

    /// True when a candidate fallback string is safe to render: non-empty, free
    /// of placeholder/scaffold leaks, and not a verbatim or near-duplicate of the
    /// immediately previous coach turn OR any recent coach turn. The recent-turn
    /// arm is what stops the gate from re-handing the user a canned line (e.g.
    /// "run one 60-second rep, verdict first") it saw a turn or two ago — the
    /// "the coach keeps giving me the same fallback" failure that a single
    /// previous-turn check misses.
    static func isCleanCandidate(
        _ candidate: String,
        previousCoachReply: String?,
        recentCoachReplies: [String] = []
    ) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lowered = normalize(trimmed)
        if containsAny(lowered, placeholderMarkers) { return false }
        if containsAny(lowered, scaffoldMarkers) { return false }
        if let previous = previousCoachReply?.trimmingCharacters(in: .whitespacesAndNewlines),
           !previous.isEmpty,
           normalize(previous).count >= 20 {
            let previousLowered = normalize(previous)
            if previousLowered == lowered ||
                lowered.contains(previousLowered) ||
                previousLowered.contains(lowered) {
                return false
            }
        }
        for recent in recentCoachReplies {
            let recentTrimmed = recent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !recentTrimmed.isEmpty else { continue }
            let recentLowered = normalize(recentTrimmed)
            guard recentLowered.count >= 20 else { continue }
            if recentLowered == lowered ||
                lowered.contains(recentLowered) ||
                recentLowered.contains(lowered) ||
                isNearDuplicate(lowered, recentLowered) {
                return false
            }
        }
        return true
    }

    /// The canonical (first) honest static line for a depth/surface. Kept as the
    /// zero-context default; `selectStaticFallback` rotates through the variants
    /// to avoid repeating one the user just saw.
    static func staticFallback(turnDepth: CoachTurnDepth, surface: CoachReplySurface) -> String {
        staticFallbackVariants(turnDepth: turnDepth, surface: surface)[0]
    }

    /// Two honest, depth-shaped static lines per surface. They say the same true
    /// thing — "I don't have a clean read yet, give me one rep" — in genuinely
    /// different words so the gate can pick one the user has not just seen. Live
    /// variants stay shorter than their text counterparts.
    static func staticFallbackVariants(
        turnDepth: CoachTurnDepth,
        surface: CoachReplySurface
    ) -> [String] {
        switch turnDepth {
        case .trustRepair:
            return surface == .live
                ? [
                    "You're right to push me. I don't have a clean read yet — give me one 60-second rep on that exact moment and I'll name the biggest gap.",
                    "Fair. I don't have enough to answer that well yet — talk me through that one moment and I'll name the single thing to fix."
                ]
                : [
                    "You're right to push me on that. I don't have a clean enough read to answer it well yet. Give me one 60-second rep on that exact scenario and I'll name the single biggest gap.",
                    "Fair — I owe you a real answer, not another drill, and I don't have enough proof yet to give you one. Walk me through that exact moment once and I'll tell you the single thing to change."
                ]
        case .deepAssessment:
            return surface == .live
                ? [
                    "I won't fake your distance to goal. One focused rep under pressure and I'll give you a straight read.",
                    "I won't guess your gap without proof. One pressured rep and I'll read it straight for you."
                ]
                : [
                    "I won't fake a verdict on how far off you are — I don't have enough proof yet. Run one rep under pressure and I'll give you a straight, honest read on the gap.",
                    "I'm not going to guess at your distance to the goal without evidence. Give me one rep under real pressure and I'll tell you exactly where the gap is."
                ]
        case .quickMove, .groundedRead:
            return surface == .live
                ? [
                    "Let's keep it concrete: one 60-second rep, verdict first, and I'll give you the one change that matters.",
                    "One short rep — decision up front, clean stop — then I'll name the single fix."
                ]
                : [
                    "Let's keep this concrete. Run one 60-second rep — verdict first, one reason, clean stop — and I'll give you the single change that matters most.",
                    "Here's the honest move: one short rep with the decision up front and a clean ending, then I'll point you to the one thing worth fixing."
                ]
        }
    }

    /// A final, honest line for the rare case where every depth-shaped static
    /// fallback variant was already seen recently. It is separate from the main
    /// variant rotation so exhaustion can still produce a clean reply once.
    static func exhaustedStaticFallback(
        turnDepth: CoachTurnDepth,
        surface: CoachReplySurface
    ) -> String {
        switch turnDepth {
        case .trustRepair:
            return surface == .live
                ? "Fair. I don't have a fresh read yet. Give me the exact moment and I'll answer that first."
                : "Fair. I don't have a fresh enough read to make this more useful yet. Give me the exact moment I missed and I'll answer that first."
        case .deepAssessment:
            return surface == .live
                ? "I don't have a fresh sample yet. Give me one pressured answer and I'll read the gap from that."
                : "I don't have a fresh enough sample to update the verdict honestly. Give me one pressured answer and I'll judge the gap from that evidence."
        case .quickMove, .groundedRead:
            return surface == .live
                ? "I don't have a fresh signal yet. Give me one concrete answer and I'll make the next read specific."
                : "I don't have a fresh enough signal yet. Give me one concrete answer with a clear ask, and I'll make the next read specific."
        }
    }

    /// Pick the first static variant the user has not just seen (not equal to,
    /// contained in, or a near-duplicate of the previous or any recent coach
    /// turn). If every depth-shaped variant collides, use a separate honest
    /// recovery line. If even that was just shown, choose a non-immediate repeat
    /// as the least-bad option rather than handing back the same canned line
    /// twice in a row.
    static func selectStaticFallback(
        turnDepth: CoachTurnDepth,
        surface: CoachReplySurface,
        previousCoachReply: String?,
        recentCoachReplies: [String]
    ) -> String {
        let variants = staticFallbackVariants(turnDepth: turnDepth, surface: surface)
        let seen = (([previousCoachReply].compactMap { $0 }) + recentCoachReplies)
            .map { normalize($0) }
            .filter { $0.count >= 20 }
        guard !seen.isEmpty else { return variants[0] }
        func collides(_ variant: String) -> Bool {
            let v = normalize(variant)
            return seen.contains { s in
                s == v || v.contains(s) || s.contains(v) || isNearDuplicate(v, s)
            }
        }
        if let freshVariant = variants.first(where: { !collides($0) }) {
            return freshVariant
        }
        let exhausted = exhaustedStaticFallback(turnDepth: turnDepth, surface: surface)
        if isCleanCandidate(
            exhausted,
            previousCoachReply: previousCoachReply,
            recentCoachReplies: recentCoachReplies
        ) {
            return exhausted
        }
        let previous = previousCoachReply.map(normalize)
        return variants.first { normalize($0) != previous } ?? variants[0]
    }

    // MARK: Helpers

    /// Whether the opening of a trust-repair reply acknowledges the push.
    static func openingAcknowledges(_ text: String) -> Bool {
        let opening = normalize(String(text.prefix(attunementWindow)))
        return containsAny(opening, acknowledgementMarkers)
    }

    /// True when a trust-repair reply has a warm opening but still never names
    /// what it is repairing. This catches the high-EQ failure mode where the
    /// answer says "fair" and immediately resumes the same drill loop.
    static func lacksTrustRepairMove(_ text: String) -> Bool {
        let normalized = normalize(text)
        return !containsAny(normalized, trustRepairMoveMarkers)
    }

    /// True when the reply after a real repair returns to generic reset advice
    /// instead of preserving the repaired read. This is intentionally stricter
    /// than the general conversation-level `repairCarryover` criterion: it only
    /// blocks obvious generic regression at the runtime boundary.
    static func breaksRepairCarryover(reply: String, previousCoachReply: String) -> Bool {
        let reply = normalize(reply)
        let previous = normalize(previousCoachReply)
        guard containsAny(previous, trustRepairCarryoverSourceMarkers),
              containsAny(previous, trustRepairMoveMarkers),
              !containsAny(reply, repairCarryoverSafeNegations) else {
            return false
        }
        return containsAny(reply, repairCarryoverBreakMarkers)
    }

    /// Detects a same-discourse-move loop that surface similarity misses:
    /// current reply + the previous two coach replies are all prescription-only.
    /// This deliberately does not fire on one or two concise drill replies, and
    /// it does not fire when the coach also answers, attunes, diagnoses, or
    /// states an evidence boundary.
    static func repeatsPrescriptionOnlyMove(
        reply: String,
        recentCoachReplies: [String],
        latestUserTurn: String? = nil
    ) -> Bool {
        if isNarrowRepeatFollowUp(latestUserTurn),
           replyAnswersNarrowRepeatFollowUp(reply) {
            return false
        }
        let window = [reply] + recentCoachReplies.prefix(2)
        guard window.count >= 3 else { return false }
        return window.allSatisfy { text in
            discourseMoveProfile(in: text) == Set([.prescribe])
        }
    }

    static func isNarrowRepeatFollowUp(_ latestUserTurn: String?) -> Bool {
        let turn = normalize(latestUserTurn ?? "")
        guard !turn.isEmpty, turn.count <= 90 else { return false }
        return containsAny(turn, [
            "what do i repeat",
            "what should i repeat",
            "what exactly do i repeat",
            "which line do i repeat",
            "which sentence do i repeat"
        ])
    }

    static func replyAnswersNarrowRepeatFollowUp(_ reply: String) -> Bool {
        let lower = normalize(reply)
        guard containsAny(lower, ["repeat", "rewrite", "say", "use", "make"]) else {
            return false
        }
        guard containsAny(lower, [
            "final sentence",
            "last sentence",
            "same line",
            "that same line",
            "final line",
            "the ask",
            "ask, period",
            "qualifier",
            "softener",
            "close"
        ]) else {
            return false
        }
        return containsAny(lower, [
            "only",
            "exact",
            "exactly",
            "same",
            "period",
            "line"
        ])
    }

    private static func discourseMoveProfile(in reply: String) -> Set<DiscourseMove> {
        let lower = normalize(reply)
        var moves = Set<DiscourseMove>()

        if containsAny(lower, [
            "no,", "no.", "yes,", "yes.", "short version",
            "straight answer", "only after", "i would not claim",
            "not another", "not a harder", "not more",
            "placeholder ask", "check only", "write the audience response"
        ]) {
            moves.insert(.answer)
        }
        if containsAny(lower, [
            "fair push", "you're right", "you are right", "good boundary",
            "right distinction", "that matters", "that is useful",
            "useful push", "i missed", "i leaned on generic",
            "that's fair", "thats fair", "i hear"
        ]) {
            moves.insert(.attune)
        }
        if containsAny(lower, [
            "the signal", "the pattern", "the issue", "the target",
            "the move", "the read", "the actual read", "the real read",
            "the bottleneck", "that tells us", "supports the",
            "outcome matters", "mechanics", "goal readiness",
            "solid on", "light on", "that is where",
            "listener asked", "asked for sequence", "proof handoff",
            "decision line is", "is cleaner", "is leaking"
        ]) {
            moves.insert(.diagnose)
        }
        if containsAny(lower, [
            "not enough", "missing", "too thin", "hypothesis",
            "from this sample", "from the transcript", "not proven",
            "need repeated", "before calling", "i still need"
        ]) {
            moves.insert(.evidenceBoundary)
        }
        if containsAny(lower, [
            "proof test", "next rep", "record", "run one",
            "run a", "run the", "rewrite", "review", "check whether",
            "listen for", "open with", "hold one",
            "make the", "try this next", "practice",
            "repeat", "under a timer", "under the timer", "protect"
        ]) || containsAnyWholeWord(lower, ["use", "say"]) {
            moves.insert(.prescribe)
        }

        if moves.isEmpty {
            moves.insert(.answer)
        }
        return moves
    }

    /// Whether two already-normalised strings are near-duplicates by distinct
    /// token (word) Jaccard overlap, given the configured threshold and minimum
    /// token floor. Pure; symmetric.
    static func isNearDuplicate(_ a: String, _ b: String) -> Bool {
        let tokensA = Set(a.split(separator: " ").map(String.init))
        let tokensB = Set(b.split(separator: " ").map(String.init))
        guard tokensA.count >= nearDuplicateMinTokens,
              tokensB.count >= nearDuplicateMinTokens else {
            return false
        }
        let intersection = tokensA.intersection(tokensB).count
        let union = tokensA.union(tokensB).count
        guard union > 0 else { return false }
        return Double(intersection) / Double(union) >= nearDuplicateThreshold
    }

    /// Lowercase + collapse all runs of whitespace/newlines to single spaces, so
    /// the duplicate and marker checks are insensitive to formatting noise.
    static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
    }

    static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }

    static func containsAnyWholeWord(_ haystack: String, _ words: [String]) -> Bool {
        words.contains { word in
            let escaped = NSRegularExpression.escapedPattern(for: word)
            return haystack.range(
                of: "(?<![a-z0-9])\(escaped)(?![a-z0-9])",
                options: .regularExpression
            ) != nil
        }
    }

    // MARK: Plan continuity

    private enum InterventionTarget: String, CaseIterable {
        case opening
        case close
        case pause
        case proof
        case tone
        case pressure
        case timeline
    }

    /// Detects the most visible self-coherence break: the coach explicitly drops
    /// or reverses its previous intervention target without naming what changed.
    static func silentlySwitchesPlan(reply: String, previousCoachReply: String) -> Bool {
        let reply = normalize(reply)
        let previous = normalize(previousCoachReply)
        guard !reply.isEmpty, !previous.isEmpty else { return false }

        let priorTargets = interventionTargets(in: previous)
        guard !priorTargets.isEmpty else { return false }

        if containsAny(reply, explicitPlanSwitchMarkers),
           !explainsTargetRevision(reply) {
            return true
        }

        let currentTargets = interventionTargets(in: reply)
        guard !currentTargets.isEmpty,
              !currentTargets.isSubset(of: priorTargets) else {
            return false
        }
        return negatesPriorTarget(in: reply, priorTargets: priorTargets) &&
            !explainsTargetRevision(reply)
    }

    private static let explicitPlanSwitchMarkers: [String] = [
        "forget what i said",
        "ignore what i said",
        "ignore the earlier",
        "new plan instead",
        "different target now",
        "actually change target",
        "actually, change target",
        "switch targets",
        "drop the previous target"
    ]

    private static func interventionTargets(in reply: String) -> Set<InterventionTarget> {
        var targets = Set<InterventionTarget>()
        func add(_ target: InterventionTarget, ifAny needles: [String]) {
            if containsAny(reply, needles) {
                targets.insert(target)
            }
        }

        add(.opening, ifAny: [
            "sentence one", "first sentence", "opener", "opening",
            "verdict first", "verdict-first", "recommendation first",
            "lead with", "open with", "decision line"
        ])
        add(.close, ifAny: [
            "final sentence", "last sentence", "clean stop", "the close",
            "close ", "ask", "stop cleanly", "stop before"
        ])
        add(.pause, ifAny: [
            "pause", "beat", "silence", "filler", "fillers"
        ])
        add(.proof, ifAny: [
            "proof", "reason", "example", "concrete detail", "evidence line"
        ])
        add(.tone, ifAny: [
            "warmth", "reassurance", "tone", "natural", "stiff", "cold",
            "harsh", "abrupt"
        ])
        add(.pressure, ifAny: [
            "pressure", "timer", "timed", "stakes", "consequential"
        ])
        add(.timeline, ifAny: [
            "timeline", "sequence", "date", "next step"
        ])
        return targets
    }

    private static func negatesPriorTarget(
        in reply: String,
        priorTargets: Set<InterventionTarget>
    ) -> Bool {
        let targetPhrases: [(InterventionTarget, [String])] = [
            (.opening, ["not the opener", "not the opening", "not sentence one", "not the recommendation"]),
            (.close, ["not the close", "not the ask", "not the final sentence", "not the last sentence"]),
            (.pause, ["not the pause", "not the beat", "not the filler"]),
            (.proof, ["not the proof", "not the reason", "not the example"]),
            (.tone, ["not warmth", "not the tone", "not reassurance"]),
            (.pressure, ["not pressure", "not the timer", "not stakes"]),
            (.timeline, ["not the timeline", "not the sequence", "not the date"])
        ]
        return targetPhrases.contains { target, phrases in
            priorTargets.contains(target) && containsAny(reply, phrases)
        }
    }

    private static func explainsTargetRevision(_ reply: String) -> Bool {
        containsAny(reply, [
            "because",
            "that tells us",
            "the issue is",
            "the risk",
            "the bottleneck",
            "that outcome matters",
            "good boundary",
            "right distinction",
            "supports the structure hypothesis",
            "order improved faster than tone",
            "the ask may have been clear"
        ])
    }
}
