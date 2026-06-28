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
//   • HARD issues (empty / placeholder / duplicateReply / scaffoldLeak) are
//     unambiguous user-facing defects. They BLOCK: the gate substitutes a truthful,
//     coach-shaped fallback (preferring the deterministic on-device read the
//     judgement pass already produced) and records that a fallback was applied.
//   • SOFT issues (floorConfidenceWithEvidence / noAttunementOnPushback /
//     repeatedProofTest) are calibration smells the report flagged. They are
//     RECORDED for evals + metadata but never blanket-replace an otherwise-fine
//     reply, because doing so would degrade a good answer into a generic one.
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
    /// Internal pipeline scaffolding (enum raw values, the structured envelope,
    /// the point-reason-example-point label) leaked into the surface text.
    case scaffoldLeak
    /// Confidence is pinned at the floor even though the assessment cites
    /// evidence — the "constant 0.20" smell from the artefacts. Recorded only.
    case floorConfidenceWithEvidence
    /// A trust-repair turn whose opening does not acknowledge the user's push
    /// before prescribing. Recorded only.
    case noAttunementOnPushback
    /// The proof-test is the same one offered on a recent turn. Recorded only.
    case repeatedProofTest

    /// Issues that are unambiguous user-facing defects and therefore trigger the
    /// truthful fallback substitution.
    var isBlocking: Bool {
        switch self {
        case .empty, .placeholder, .duplicateReply, .scaffoldLeak:
            return true
        case .floorConfidenceWithEvidence, .noAttunementOnPushback, .repeatedProofTest:
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

    // MARK: Detection vocabularies

    /// Literal stubs that must never reach a user. Matched on the lowercased,
    /// whitespace-collapsed surface text. Kept deliberately tight and
    /// unambiguous so real coaching prose can never trip them.
    static let placeholderMarkers: [String] = [
        "full answer coming",
        "coach read coming",
        "response coming",
        "placeholder",
        "lorem ipsum",
        "your response here",
        "insert response",
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
        "let me", "i was", "i didn't", "i didnt", "you're pushing",
        "i hear that", "i get that", "that's on me", "thats on me"
    ]

    // MARK: Evaluation

    /// Evaluate a final reply. Pure: no store reads, no clock, no I/O.
    ///
    /// - Parameters:
    ///   - replyText: the model's final surface text (already sanitised by the
    ///     caller via `CoachReplyTextSanitizer`, but re-trimmed here for safety).
    ///   - previousCoachReply: the most recent prior coach turn's text, for the
    ///     verbatim-duplicate check.
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
        if !trimmed.isEmpty,
           let previous = previousCoachReply?.trimmingCharacters(in: .whitespacesAndNewlines),
           !previous.isEmpty,
           normalize(previous) == lowered {
            issues.append(.duplicateReply)
        }

        // --- SOFT (recorded, never blanket-replace) ---
        if let assessment,
           assessment.confidence <= floorConfidence,
           assessment.evidenceReferenceCount > 0 {
            issues.append(.floorConfidenceWithEvidence)
        }
        if turnDepth == .trustRepair,
           !trimmed.isEmpty,
           !openingAcknowledges(trimmed) {
            issues.append(.noAttunementOnPushback)
        }
        if proofTestRecentlyRepeated {
            issues.append(.repeatedProofTest)
        }

        let blocking = issues.contains { $0.isBlocking }
        let fallback = blocking
            ? truthfulFallback(
                turnDepth: turnDepth,
                assessment: assessment,
                surface: surface,
                previousCoachReply: previousCoachReply
            )
            : nil

        return CoachReliabilityVerdict(issues: issues, fallbackText: fallback)
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
        previousCoachReply: String?
    ) -> String {
        if let assessment {
            let read = assessment.immediateCoachRead.trimmingCharacters(in: .whitespacesAndNewlines)
            if isCleanCandidate(read, previousCoachReply: previousCoachReply) {
                return read
            }
        }
        return staticFallback(turnDepth: turnDepth, surface: surface)
    }

    /// True when a candidate fallback string is safe to render: non-empty, free
    /// of placeholder/scaffold leaks, and not the same duplicate we are escaping.
    static func isCleanCandidate(_ candidate: String, previousCoachReply: String?) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lowered = normalize(trimmed)
        if containsAny(lowered, placeholderMarkers) { return false }
        if containsAny(lowered, scaffoldMarkers) { return false }
        if let previous = previousCoachReply?.trimmingCharacters(in: .whitespacesAndNewlines),
           !previous.isEmpty,
           normalize(previous) == lowered {
            return false
        }
        return true
    }

    static func staticFallback(turnDepth: CoachTurnDepth, surface: CoachReplySurface) -> String {
        switch turnDepth {
        case .trustRepair:
            return surface == .live
                ? "You're right to push me. I don't have a clean read yet — give me one 60-second rep on that exact moment and I'll name the biggest gap."
                : "You're right to push me on that. I don't have a clean enough read to answer it well yet. Give me one 60-second rep on that exact scenario and I'll name the single biggest gap."
        case .deepAssessment:
            return surface == .live
                ? "I won't fake your distance to goal. One focused rep under pressure and I'll give you a straight read."
                : "I won't fake a verdict on how far off you are — I don't have enough proof yet. Run one rep under pressure and I'll give you a straight, honest read on the gap."
        case .quickMove, .groundedRead:
            return surface == .live
                ? "Let's keep it concrete: one 60-second rep, verdict first, and I'll give you the one change that matters."
                : "Let's keep this concrete. Run one 60-second rep — verdict first, one reason, clean stop — and I'll give you the single change that matters most."
        }
    }

    // MARK: Helpers

    /// Whether the opening of a trust-repair reply acknowledges the push.
    static func openingAcknowledges(_ text: String) -> Bool {
        let opening = normalize(String(text.prefix(attunementWindow)))
        return containsAny(opening, acknowledgementMarkers)
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
}
