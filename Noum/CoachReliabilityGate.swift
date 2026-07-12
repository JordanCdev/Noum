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
    /// A "too generic / could go to anyone" repair that still exposes
    /// scaffold/report cadence, or fails to name the specific communication
    /// pattern that makes the repair credible.
    case genericRepairScaffolded
    /// A "not informative" repair that exposes scaffold/report language or a
    /// hostile anti-fluff instruction instead of owning the miss and giving the
    /// specific read the prior answer should have given.
    case notInformativeRepairScaffold
    /// A "give me a straight answer" repair that says "yes" but does not state
    /// the matching "no" half, or that falls back into raw report-voice metric
    /// readout instead of answering the split directly.
    case straightAnswerSplitMissing
    /// A repetition callout that apologizes generically, quotes raw score
    /// evidence, or repeats the old intervention instead of acknowledging the
    /// target is met and advancing to the next lever.
    case repetitionCourseCorrectionMiss
    /// A pace self-frustration turn ("I talk too fast") received report-like
    /// score language, generic "slow down" advice, or a speed read without the
    /// pause-gap mechanism that makes the advice useful.
    case paceSelfFrustrationReportVoice
    /// A rambling / losing-the-thread turn received a long scaffolded reply or
    /// generic concision advice instead of the concrete stop-rule mechanism.
    case rambleStoppingRuleMiss
    /// A high-stakes leadership update/status-report turn received a raw score
    /// read or skipped the concrete same-night opener rehearsal the user needs
    /// before tomorrow's room.
    case leadershipStatusReportMiss
    /// A "what should I work on next?" turn with a recurring close-rush trend
    /// watered down the trajectory read, usually by dropping the 5-of-6
    /// prevalence or bundling multiple close mechanics into one test.
    case recurringCloseTrendDiluted
    /// A "what do you know about me?" skepticism/metadata turn answered like a
    /// drill prompt or database row instead of a plain, person-shaped synthesis
    /// of known goal, pattern, and bounded metrics.
    case metadataSelfKnowledgeMiss
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
    /// The user's turn was a tiny off-topic probe / non-sequitur ("egg") but
    /// the reply recapped metrics or prescribed a drill. A composed coach names
    /// the probe lightly and steers back; it does not mine a nonsense turn for
    /// another metric read.
    case offTopicTestWithDrill
    /// There is no baseline yet (no rated sessions) but the reply names an
    /// internal practice mode ("Ah-Counter", "Sudden Death") or invents a metric
    /// target ("under 4 fillers", "a first number") — product jargon and fake
    /// calibration a first-launch user has no way to parse and that nothing on
    /// device supports yet. The prompt bans this; this is the deterministic
    /// backstop for a draft that ignored the ban.
    case coldStartJargon
    /// There is no baseline yet (no rated sessions) but the reply asserts a
    /// confident read of a specific rep that cannot exist — "I can coach the
    /// latest rep: the close is the usable signal…" — fabricating delivery
    /// evidence from nothing. This is the overclaim the `placeholder-leak-049`
    /// trap targets: today it only trips a *soft* floor-confidence smell and
    /// ships. A cold start must answer "give me one rep first", not invent a
    /// rep to coach. Distinct from `coldStartJargon` (mode names / metric
    /// targets); this is fabricated *rep* evidence, and it only fires when the
    /// reply does NOT already acknowledge the missing evidence.
    case evidenceOverclaimNoBaseline
    /// A discouraged / vulnerable pushback turn ("It's not easy", "I freeze")
    /// was acknowledged but then ended on a bare diagnostic question. That can
    /// be technically responsive while still pushing work back onto someone who
    /// needed presence, earned evidence, or one tiny next step.
    case vulnerablePushbackQuestionBurden
    /// A voice / goal-change reply leaked UI or state-write language ("tap to
    /// confirm", "I'll lock it in"). The coach can recommend a voice; the
    /// confirmation flow owns state mutation.
    case goalStateDirectiveLeak
    /// A voice / goal-change reply recited raw score/filler/duration telemetry
    /// as proof for a voice decision. Voice selection is identity-adjacent; it
    /// should use a spoken progress anchor, not a dashboard readout.
    case goalStateReportVoiceLeak

    /// Issues that are unambiguous user-facing defects and therefore trigger the
    /// truthful fallback substitution.
    var isBlocking: Bool {
        switch self {
        case .empty, .placeholder, .duplicateReply, .scaffoldLeak,
                .noAttunementOnPushback, .thinTrustRepair,
                .genericRepairScaffolded, .notInformativeRepairScaffold,
                .straightAnswerSplitMissing,
                .repetitionCourseCorrectionMiss,
                .paceSelfFrustrationReportVoice, .rambleStoppingRuleMiss,
                .leadershipStatusReportMiss,
                .recurringCloseTrendDiluted, .metadataSelfKnowledgeMiss,
                .repairCarryoverBreak, .silentPlanSwitch,
                .repetitiveDiscourseMove, .repeatedProofTest,
                .greetingWithDrill, .offTopicTestWithDrill, .coldStartJargon,
                .evidenceOverclaimNoBaseline, .vulnerablePushbackQuestionBurden,
                .goalStateDirectiveLeak, .goalStateReportVoiceLeak:
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

    /// Evidence coverage at or below this marks a true cold start (no rated
    /// sessions). `UserTrajectoryCache.evidenceCoverage` pins the value to
    /// exactly 0.05 when `sessions.isEmpty`, so this ceiling isolates the
    /// no-baseline turn without catching any user who has completed even one
    /// rep. The cold-start jargon guard only fires under this ceiling, so a real
    /// user citing their own filler count is never touched.
    static let coldStartCoverageCeiling: Double = 0.051

    /// Coverage below this is deliberately pinned to the 0.20 confidence
    /// floor by `CoachReasoningPass`. A floor-confidence assessment is only a
    /// calibration smell once the trajectory has enough breadth that the
    /// reasoning pass should have moved off that floor. Without this guard,
    /// one honest first rep is reported as defective merely because it supplies
    /// a local evidence line.
    static let floorConfidenceEvidenceCoverageFloor: Double = 0.15

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
        "i hear", "good push", "good call", "that's fair", "thats fair",
        "i missed", "i owe you", "right to push", "right to call",
        "makes sense", "i get it", "valid", "my read was off",
        "let me repair", "let me fix", "let me correct",
        "i was", "i didn't", "i didnt", "you're pushing",
        "i hear that", "i get that", "that's on me", "thats on me",
        "no, it is not easy", "no it is not easy",
        "no, it isn't", "no it isn't", "no, it isnt", "no it isnt"
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
        "i sounded robotic",
        "i sounded generic",
        "i leaned on generic",
        "i leaned on a generic",
        "i was too generic",
        "that read was",
        "that read too much like a report",
        "that read like a report",
        "cold report",
        "generic tip sheet",
        "actual practice",
        "that sounded cold",
        "robotic and cold",
        "too much writing",
        "that was generic",
        "could go to anyone",
        "specific thing",
        "specific pattern",
        "generic ai wrapper",
        "generic report",
        "not a coach read",
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
        "safe signal",
        "one safe signal",
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
           assessment.evidenceReferenceCount > 0,
           let evidenceCoverage,
           evidenceCoverage >= floorConfidenceEvidenceCoverageFloor {
            issues.append(.floorConfidenceWithEvidence)
        }
        if turnDepth == .trustRepair,
           !trimmed.isEmpty {
            let isRepetitionCallout = repetitionCalloutUserTurn(latestUserTurn)
            if !openingAcknowledges(trimmed) {
                issues.append(.noAttunementOnPushback)
            }
            if isRepetitionCallout,
               repetitionCourseCorrectionNeedsRepair(replyText: trimmed) {
                issues.append(.repetitionCourseCorrectionMiss)
                if openingAcknowledges(trimmed),
                   lacksTrustRepairMove(trimmed) {
                    issues.append(.thinTrustRepair)
                }
            } else if !isRepetitionCallout,
                      genericRepairUserTurn(latestUserTurn),
                      genericRepairNeedsSpecificPattern(trimmed) {
                issues.append(.genericRepairScaffolded)
            } else if !isRepetitionCallout,
                      openingAcknowledges(trimmed),
                      lacksTrustRepairMove(trimmed) {
                issues.append(.thinTrustRepair)
            }
            if notInformativeRepairUserTurn(latestUserTurn),
               leaksNotInformativeRepairScaffold(trimmed) {
                issues.append(.notInformativeRepairScaffold)
            }
            if straightAnswerUserTurn(latestUserTurn),
               straightAnswerNeedsSplitRepair(trimmed) {
                issues.append(.straightAnswerSplitMissing)
            }
            if burdensVulnerablePushback(reply: trimmed, latestUserTurn: latestUserTurn) {
                issues.append(.vulnerablePushbackQuestionBurden)
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
        // Same class of sensitive-turn failure for one-word / nonsense tests:
        // do not answer "egg" with today's score, fillers, or another drill.
        if let latestUserTurn,
           !trimmed.isEmpty,
           TurnDepthClassifier.isLowSignalOffTopicTest(latestUserTurn),
           replyDrillsInsteadOfGreeting(lowered) {
            issues.append(.offTopicTestWithDrill)
        }
        // Voice / goal-change turns should stay in the coach's voice. The coach
        // can recommend a direction, but it must not claim a state write or
        // recite button-copy-style instructions.
        if !trimmed.isEmpty,
           goalOrVoiceChangeUserTurn(latestUserTurn),
           leaksGoalStateDirective(lowered) {
            issues.append(.goalStateDirectiveLeak)
        }
        if !trimmed.isEmpty,
           goalOrVoiceChangeUserTurn(latestUserTurn),
           leaksGoalStateReportVoice(lowered) {
            issues.append(.goalStateReportVoiceLeak)
        }
        // Pace self-frustration needs the coach to separate speed from the
        // sentence-boundary gap. A raw score read or generic "slow down" advice
        // makes the answer feel like a report, not coaching.
        if !trimmed.isEmpty,
           turnDepth != .trustRepair,
           paceSelfFrustrationUserTurn(latestUserTurn),
           paceSelfFrustrationNeedsRepair(replyText: trimmed) {
            issues.append(.paceSelfFrustrationReportVoice)
        }
        // Rambling complaints need a stop-rule mechanism, not a long scaffolded
        // "be concise" answer that recreates the problem in coach form.
        if !trimmed.isEmpty,
           turnDepth != .trustRepair,
           rambleStoppingRuleUserTurn(latestUserTurn),
           rambleStoppingRuleNeedsRepair(replyText: trimmed) {
            issues.append(.rambleStoppingRuleMiss)
        }
        // A tomorrow leadership update where the room zones out needs status
        // hierarchy and an immediate rehearsal action, not another raw score
        // callout or abstract structure advice.
        if !trimmed.isEmpty,
           turnDepth != .trustRepair,
           leadershipStatusReportUserTurn(latestUserTurn),
           leadershipStatusReportNeedsRepair(replyText: trimmed) {
            issues.append(.leadershipStatusReportMiss)
        }
        // A next-work turn after a solid-feeling rep should use the trajectory
        // cache as the coach's spine: name the recurring close position, include
        // the overall prevalence, and prescribe one close test.
        if !trimmed.isEmpty,
           turnDepth != .trustRepair,
           recurringCloseRushUserTurn(latestUserTurn),
           recurringCloseRushTrendAvailable(assessment: assessment, replyText: trimmed),
           recurringCloseRushNeedsRepair(replyText: trimmed) {
            issues.append(.recurringCloseTrendDiluted)
        }
        // A self-knowledge / metadata challenge should answer what the coach
        // actually knows in human language. Do not append a fresh drill unless
        // the user asks for one, and do not sound like a database export.
        if !trimmed.isEmpty,
           turnDepth != .trustRepair,
           metadataSelfKnowledgeUserTurn(latestUserTurn),
           metadataSelfKnowledgeSourceAvailable(assessment: assessment, replyText: trimmed),
           metadataSelfKnowledgeNeedsRepair(replyText: trimmed) {
            issues.append(.metadataSelfKnowledgeMiss)
        }
        // No baseline yet, but the reply leaked an internal mode name or invented
        // a metric target — jargon a first-launch user can't parse and nothing on
        // device supports. Only fires under the cold-start coverage ceiling (so a
        // real user citing their own filler count is never touched), and not on
        // trust-repair (its own repair path owns that surface) or a bare greeting
        // (greetingWithDrill owns it, and takes priority below).
        if !trimmed.isEmpty,
           turnDepth != .trustRepair,
           let evidenceCoverage,
           evidenceCoverage <= coldStartCoverageCeiling,
           !(latestUserTurn.map(TurnDepthClassifier.isGreetingOrSmallTalk) ?? false),
           leaksColdStartJargon(lowered) {
            issues.append(.coldStartJargon)
        }
        // No baseline yet, but the reply asserts a confident read of a specific
        // rep that cannot exist ("I can coach the latest rep: the close is the
        // usable signal…"). This is fabricated delivery evidence, not honest
        // coaching. Same cold-start coverage ceiling as the jargon guard, and it
        // only fires when the reply does NOT already hedge about missing evidence
        // — so an honest "not enough evidence yet, the little I have is…" read
        // (e.g. lack-conviction) is never blocked. Not on trust-repair (own
        // surface) or greetings (greetingWithDrill owns those).
        if !trimmed.isEmpty,
           turnDepth != .trustRepair,
           let evidenceCoverage,
           evidenceCoverage <= coldStartCoverageCeiling,
           !(latestUserTurn.map(TurnDepthClassifier.isGreetingOrSmallTalk) ?? false),
           !acknowledgesMissingEvidence(lowered),
           overclaimsRepEvidence(lowered) {
            issues.append(.evidenceOverclaimNoBaseline)
        }

        // A greeting mismatch must be answered with a warm hello, NOT the
        // deterministic coaching read (which is itself the drill we are
        // escaping), so it takes priority over the generic truthful fallback.
        let fallback: String?
        if issues.contains(.greetingWithDrill) {
            fallback = greetingFallback(surface: surface, assessment: assessment)
        } else if issues.contains(.offTopicTestWithDrill) {
            fallback = offTopicTestFallback(surface: surface)
        } else if issues.contains(.genericRepairScaffolded) {
            fallback = genericRepairFallback(surface: surface, replyText: trimmed)
        } else if issues.contains(.notInformativeRepairScaffold) {
            fallback = notInformativeRepairFallback(surface: surface)
        } else if issues.contains(.straightAnswerSplitMissing) {
            fallback = straightAnswerSplitFallback(surface: surface)
        } else if issues.contains(.repetitionCourseCorrectionMiss) {
            fallback = repetitionCourseCorrectionFallback(surface: surface)
        } else if issues.contains(.repetitiveDiscourseMove) {
            // Reusing the assessment read here can reproduce the exact
            // prescription-only loop this gate just blocked. Respond to the
            // user's reported result and preserve the active plan without
            // handing back another generic rep assignment.
            fallback = discourseLoopFallback(
                surface: surface,
                latestUserTurn: latestUserTurn
            )
        } else if issues.contains(.vulnerablePushbackQuestionBurden) {
            fallback = vulnerablePushbackFallback(surface: surface, assessment: assessment)
        } else if issues.contains(.goalStateDirectiveLeak) ||
                    issues.contains(.goalStateReportVoiceLeak) {
            fallback = goalStateDirectiveFallback(
                surface: surface,
                latestUserTurn: latestUserTurn,
                replyText: trimmed
            )
        } else if issues.contains(.paceSelfFrustrationReportVoice) {
            fallback = paceSelfFrustrationFallback(
                surface: surface,
                assessment: assessment,
                replyText: trimmed
            )
        } else if issues.contains(.rambleStoppingRuleMiss) {
            fallback = rambleStoppingRuleFallback(
                surface: surface,
                latestUserTurn: latestUserTurn,
                assessment: assessment
            )
        } else if issues.contains(.leadershipStatusReportMiss) {
            fallback = leadershipStatusReportFallback(surface: surface)
        } else if issues.contains(.recurringCloseTrendDiluted) {
            fallback = recurringCloseRushFallback(surface: surface)
        } else if issues.contains(.metadataSelfKnowledgeMiss) {
            fallback = metadataSelfKnowledgeFallback(surface: surface)
        } else if issues.contains(.coldStartJargon) {
            // A cold-start turn must recover with a clean plain-language first-rep
            // invitation, NOT the deterministic read (which may itself carry the
            // jargon) or the generic verdict-first drill line.
            fallback = coldStartFallback(surface: surface)
        } else if issues.contains(.evidenceOverclaimNoBaseline) {
            // The draft invented a rep to coach. Recover with an honest "there is
            // no rep to read yet — record one" invitation, NOT the deterministic
            // read (which is the very overclaim we are escaping).
            fallback = noBaselineReadFallback(surface: surface)
        } else if issues.contains(where: { $0.isBlocking }) {
            fallback = truthfulFallback(
                turnDepth: turnDepth,
                assessment: assessment,
                surface: surface,
                previousCoachReply: previousCoachReply,
                recentCoachReplies: recentCoachReplies,
                latestUserTurn: latestUserTurn
            )
        } else {
            fallback = nil
        }

        return CoachReliabilityVerdict(issues: issues, fallbackText: fallback)
    }

    static func discourseLoopFallback(
        surface: CoachReplySurface,
        latestUserTurn: String?
    ) -> String {
        let turn = normalize(latestUserTurn ?? "")
        if containsAny(turn, ["natural", "stiff", "forced", "managed"]) {
            return surface == .live
                ? "Keep the change that helped; drop the managed rhythm everywhere else. Use the pause only at the pressure point."
                : "Keep the change that helped; drop the managed rhythm everywhere else. Tomorrow, let the rest of the answer run normally and use the pause only at the pressure point."
        }
        if containsAny(turn, ["real coach", "not like a coach", "robotic", "generic"]) {
            return surface == .live
                ? "Fair. I slipped back into a template instead of responding to your result. I should stay with what changed before prescribing anything else."
                : "Fair. I slipped back into a template instead of responding to what changed. The earlier move felt better; the remaining gap is my response, not another speaking drill. I should stay with that result before prescribing anything else."
        }
        return surface == .live
            ? "You're right — that's the same kind of drill again. Keep what helped, drop what felt forced, and stay with the current target."
            : "You're right — that's the same kind of drill again. Stay with the result you just gave me: keep what helped, drop what felt forced, and do not change the target until a real moment gives us new evidence."
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

    /// Internal practice-mode names. On a no-baseline turn these are unexplained
    /// product jargon (mirrors the cold-start ban in `CoachContextBuilder`).
    static let coldStartModeMarkers: [String] = [
        "ah-counter", "ah counter", "ahcounter",
        "sudden death", "sudden-death",
        "im conversation", "i.m. conversation", "im-conversation"
    ]

    /// Invented calibration language that only makes sense once a baseline
    /// exists. On a cold start there is nothing to calibrate against, so "your
    /// first number", "a starting number", etc. are fabricated.
    static let coldStartInventedMetricMarkers: [String] = [
        "first number", "starting number",
        "first metric", "starting metric", "starting benchmark"
    ]

    /// True when a reply leaks cold-start product jargon: an internal mode name,
    /// an invented calibration phrase, or an explicit numeric filler target
    /// ("under 4 fillers", "stay under 3"). Matched on already-normalised text.
    static func leaksColdStartJargon(_ lowered: String) -> Bool {
        if containsAny(lowered, coldStartModeMarkers) { return true }
        if containsAny(lowered, coldStartInventedMetricMarkers) { return true }
        // An explicit numeric filler target is fabricated when no rep exists yet.
        if lowered.range(of: "under [0-9]+ ?fillers?", options: .regularExpression) != nil {
            return true
        }
        if lowered.range(of: "stay under [0-9]+", options: .regularExpression) != nil {
            return true
        }
        return false
    }

    /// First-person claims to *coach* a specific rep. This is the tell that
    /// separates an overclaim from an honest read: honest replies DESCRIBE the
    /// rep ("on the latest rep, the reasons were clear") but never assert the
    /// ability to coach one. Paired below with a rep reference so a bare "I can
    /// coach this" (no named rep) is not caught. Normalised text.
    static let coachAbilityClaimMarkers: [String] = [
        "i can coach", "let me coach", "i will coach", "ill coach", "i'll coach"
    ]

    /// References to a specific, already-observed rep. Deliberately excludes the
    /// bare substring "the rep" (it matches "the report") — only concrete
    /// rep references count.
    static let namedRepMarkers: [String] = [
        "the latest rep", "your latest rep", "the last rep", "your last rep",
        "this rep", "that rep", "the rep you"
    ]

    /// Phrases by which a reply openly acknowledges that the evidence is thin or
    /// missing. When any is present the reply is being honest about its limits —
    /// e.g. "not enough evidence to call this… the little I can use is hedge
    /// control" — so the overclaim guard must NOT fire, even if the same reply
    /// also names a rep. This is what keeps lack-conviction-style honest reads
    /// (which legitimately cite "the latest rep … only support a signal") safe.
    static let evidenceLimitAcknowledgementMarkers: [String] = [
        "not enough evidence", "no baseline", "not enough to",
        "missing:", "i would not", "i wouldnt", "i cannot prove",
        "i cant prove", "not proven", "need one rep", "need a rep",
        "before i can coach", "would be guessing", "cannot call",
        "not a trait yet", "no rep", "havent recorded", "haven't recorded",
        "record 60 seconds", "record one"
    ]

    /// True when the reply hedges about missing/thin evidence (see markers).
    static func acknowledgesMissingEvidence(_ lowered: String) -> Bool {
        containsAny(lowered, evidenceLimitAcknowledgementMarkers)
    }

    /// True when the reply claims to coach a specific, named rep — the
    /// "I can coach the latest rep: the close is the usable signal…" overclaim.
    /// Requires BOTH a first-person coaching-ability claim AND a named rep, so
    /// honest reads that merely describe "the latest rep" are never caught.
    /// Callers additionally gate on the cold-start coverage ceiling AND
    /// `!acknowledgesMissingEvidence`, so it is high-precision by design.
    static func overclaimsRepEvidence(_ lowered: String) -> Bool {
        containsAny(lowered, coachAbilityClaimMarkers)
            && containsAny(lowered, namedRepMarkers)
    }

    /// The honest recovery when a draft invented a rep to coach on a no-baseline
    /// turn: name that there is nothing recorded to read yet, ask for one 60-second
    /// rep, and promise a real read of it — no invented signal, no fake "latest rep".
    static func noBaselineReadFallback(surface: CoachReplySurface) -> String {
        surface == .live
            ? "There's no rep for me to read yet, so I won't guess one. Give me 60 seconds — record now and I'll read the opener and close for real. Want to go?"
            : "There's no rep for me to read yet, so I won't invent one. Record 60 seconds first, then I'll coach the opener and close from what actually happened — that's the honest way to do this."
    }

    /// A clean, warm cold-start line: honest that there is no baseline, asks for
    /// one plain 60-second sample on something the user knows well, and avoids
    /// mode names, invented metrics, and a redundant closing question.
    static func coldStartFallback(surface: CoachReplySurface) -> String {
        surface == .live
            ? "No baseline yet, so start with one real sample. Record 60 seconds on something you know well at your real pace."
            : "No baseline yet, so start with one real sample. Record 60 seconds on something you know well at your real pace, with sentence one as the point."
    }

    /// A warm, brief greeting to render when the turn was a hello but the reply
    /// tried to drill. Invites the user back into the work without prescribing —
    /// on a greeting, an open question IS the right move, unlike a coaching turn.
    static func greetingFallback(surface: CoachReplySurface) -> String {
        surface == .live
            ? "Hey — good to see you. Want to keep going, or is something else on your mind?"
            : "Hey — good to see you back. Want to pick up where we left off, or is there something specific on your mind?"
    }

    static func greetingFallback(
        surface: CoachReplySurface,
        assessment: CoachAssessment?
    ) -> String {
        guard let cue = greetingThreadCue(from: assessment) else {
            return greetingFallback(surface: surface)
        }
        return surface == .live
            ? "Hey — good to see you. \(cue)"
            : "Hey — good to see you back. \(cue)"
    }

    static func greetingThreadCue(from assessment: CoachAssessment?) -> String? {
        guard let assessment else { return nil }
        let combined = normalize(
            [
                assessment.directVerdict,
                assessment.nextProofTest,
                assessment.evidenceUsed.joined(separator: " ")
            ].joined(separator: " ")
        )
        if containsAny(combined, ["close", "final sentence", "final line", "ending"]) {
            if containsAny(combined, ["flat", "softened", "softener"]) {
                return "Pick up with the close: land the final sentence flat, then stop."
            }
            if containsAny(combined, ["silent beat", "plant one beat", "plant a beat"]) {
                return "Pick up with the close: plant one silent beat before the final line."
            }
            return "Pick up with the close: make the final sentence the ask, then stop."
        }
        if containsAny(combined, ["opener", "opening", "recommendation", "verdict", "point first"]) {
            return "Pick up with the opener: lead with the recommendation, give one reason, then stop."
        }
        return nil
    }

    /// A composed redirect for tiny non-sequitur/test turns. This stays out of
    /// metrics and modes; the point is to preserve coach presence, not reward the
    /// probe with another drill.
    static func offTopicTestFallback(surface: CoachReplySurface) -> String {
        surface == .live
            ? "Tiny test. All good. Give me the moment you want to practice, and I'll give you one clean read."
            : "Tiny test. All good. Send the moment you want to practice, and I'll give you one clean read."
    }

    static func lowCapacityUserTurn(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return false }
        return containsAny(normalize(latestUserTurn), [
            "i'm exhausted", "im exhausted", "i am exhausted",
            "i'm tired", "im tired", "i am tired",
            "i'm overwhelmed", "im overwhelmed", "i am overwhelmed",
            "i feel defeated", "i'm defeated", "im defeated"
        ])
    }

    /// Presence-first recovery for a user who has no capacity for another drill.
    /// Rotate the copy if the same recovery was just shown; the invariant is no
    /// pressure and no fabricated progress, not one canonical sentence.
    static func lowCapacityFallback(
        surface: CoachReplySurface,
        previousCoachReply: String?,
        recentCoachReplies: [String]
    ) -> String {
        let variants = surface == .live
            ? [
                "That sounds exhausting. Do not force another rep right now. Stop here, and come back when you have room for one small answer.",
                "You sound spent. No drill now. Take the pressure off; we can use one small answer when you come back."
            ]
            : [
                "That sounds exhausting. Do not force another rep right now. Stop here, and come back when you have enough room for one small answer.",
                "You sound spent. No drill now. Take the pressure off; when you come back, we can use one small answer instead of a full session."
            ]
        return variants.first {
            isCleanCandidate(
                $0,
                previousCoachReply: previousCoachReply,
                recentCoachReplies: recentCoachReplies
            )
        } ?? variants.first { normalize($0) != previousCoachReply.map(normalize) } ?? variants[0]
    }

    /// Recovery for a genericness trust-repair complaint. The key is to stop
    /// sounding like a template: own the miss, name the concrete pattern, and
    /// give one behavioural move without raw counts or scaffold labels.
    static func genericRepairFallback(
        surface: CoachReplySurface,
        replyText: String
    ) -> String {
        let normalized = normalize(replyText)
        if containsAny(normalized, ["ask", "raise", "number", "qualifier", "hoping to maybe"]) {
            return surface == .live
                ? "Fair. That was too generic. The specific pattern is the ask itself. State the number flat, no qualifier, then stop."
                : "Fair. That was too generic. The specific pattern is the ask itself. You softened the number instead of stating it. State the raise as one flat sentence, no qualifier, then stop."
        }
        if normalized.contains("recommendation") {
            return surface == .live
                ? "Fair. That sounded generic. The specific pattern is that the recommendation arrived late. Put it in sentence one, give one reason, then stop."
                : "Fair. That sounded like generic advice, not a coach read. The specific pattern is that your recommendation arrived late. Put the recommendation in sentence one, give one reason, then stop."
        }
        return surface == .live
            ? "Fair. That was too generic. The specific pattern is that the point arrived late. Lead with the point, give one reason, then stop."
            : "Fair. That was too generic. The specific pattern is that your point arrived late instead of leading the answer. Make sentence one the point, give one reason, then stop."
    }

    /// Recovery for the "that was not informative" trust-repair case. The raw
    /// draft often contains the right evidence but wraps it in scaffold labels,
    /// bare scores, or hostile anti-fluff language. Replace it with the exact
    /// specific read and one plain behavioural move.
    static func notInformativeRepairFallback(surface: CoachReplySurface) -> String {
        surface == .live
            ? "Fair. I was too vague. Your point arrived after three warm-up sentences, so say the point first and support it once."
            : "Fair. I was too vague. The useful read is that your point arrived in sentence four after three warm-up sentences, so say the point first and support it once."
    }

    /// Recovery for a direct trust-repair ask. Preserve the user's requested
    /// directness: state both sides of the verdict, then give one bounded test.
    static func straightAnswerSplitFallback(surface: CoachReplySurface) -> String {
        surface == .live
            ? "Fair. Straight answer: yes on fillers; no on pace under pressure. The rush still shows up when pressure rises, so hold one silent beat before the hard answer."
            : "Fair. Straight answer: yes on fillers; no on pace under pressure. The rush still shows up when pressure rises, so next rep, hold one silent beat before the hard answer."
    }

    /// Recovery for "you're repeating yourself." Keep the trust repair concrete:
    /// own the repeated target, preserve the earned prior evidence without raw
    /// score language, and advance the intervention rather than re-issuing the
    /// old point-first drill.
    static func repetitionCourseCorrectionFallback(surface: CoachReplySurface) -> String {
        if surface == .live {
            return "Fair. I did repeat the same target. You led cleanly and the close held, so move on: pace. Slow the three words that carry the point, then hold one silent beat."
        }
        return "Fair. I did repeat the same target. You led cleanly and the close held, so there is no reason to run that drill again. New target: pace. Slow the three words that carry the point, then hold one silent beat before the next sentence."
    }

    /// Recovery for pace self-frustration that leaked a score or generic
    /// confidence/speed advice. Use metrics only when the assessment or draft
    /// actually supplied them; otherwise keep the mechanism truthful.
    static func paceSelfFrustrationFallback(
        surface: CoachReplySurface,
        assessment: CoachAssessment?,
        replyText: String
    ) -> String {
        let metricRead = paceSelfFrustrationMetricRead(
            assessment: assessment,
            replyText: replyText
        )
        if surface == .live {
            if let metricRead {
                return "You're not imagining it. \(metricRead) points to the gap, not confidence. Hold one silent beat after each full stop."
            }
            return "You're not imagining it. Fix the pause, not the speed: one silent beat after each full stop, then see if people track you better."
        }
        if let metricRead {
            return "You're not imagining it: \(metricRead) means the gap between sentences is disappearing. Fix the pause, not the speed. Next rep, hold one silent beat after every full stop and see if people track you without forcing a slower voice."
        }
        return "You're not imagining it: this reads like a missing gap between sentences, not a confidence problem. Fix the pause, not the speed. Next rep, hold one silent beat after every full stop and see if people track you without forcing a slower voice."
    }

    /// Recovery for rambling turns. Preserve the useful mechanism, but say it
    /// with the same stop discipline we are asking the user to practise.
    static func rambleStoppingRuleFallback(
        surface: CoachReplySurface,
        latestUserTurn: String? = nil,
        assessment: CoachAssessment? = nil
    ) -> String {
        let context = rambleStoppingRuleFallbackContext(
            latestUserTurn: latestUserTurn,
            assessment: assessment
        )
        if containsAny(context, [
            "networking",
            "introducing myself",
            "introduce myself",
            "introduction",
            "intro"
        ]) {
            if surface == .live {
                return "Start with a 20-second intro: who you help, what changes, one question. No full story yet."
            }
            return "Start with a 20-second test: who you help, what changes, and one question for them. No full story yet, because first we need to hear where the ramble starts."
        }
        if rambleStoppingRuleContextSuggestsConciseRecommendation(context) {
            if surface == .live {
                return "Use a two-sentence ceiling: recommendation first, one reason second, clean stop."
            }
            return "For your concise voice, use a two-sentence ceiling on a 45-second client recommendation: recommendation first, one reason second, clean stop. The extra condition is the ramble point because if a second reason appears, the answer sprawls."
        }
        if surface == .live {
            return "In your last rep, you kept the thread but reopened it after the side stories. The weaker repeat is the signal, so use a hard stop: point, one support line, silence."
        }
        return "In your last rep, you kept the thread but reopened it after the side stories. The weaker repeat is the signal, so use a hard stop: state the point, give one support line, then silence."
    }

    /// Recovery for high-stakes status-report leadership updates. The user needs
    /// a top-line hierarchy move they can rehearse tonight, not raw score proof.
    static func leadershipStatusReportFallback(surface: CoachReplySurface) -> String {
        if surface == .live {
            return "The status-report risk is hierarchy: equal-weight structure hides the leadership goal. Tonight, say one opener aloud: \"The one thing that matters this week is X because Y.\""
        }
        return "The status-report risk is hierarchy: equal-weight structure hides the leadership goal. Tonight, write one opener — \"The one thing that matters this week is X because Y\" — and say it aloud once."
    }

    /// Recovery for the recurring close-rush trend. This is trajectory-backed
    /// coaching, so the repair must keep both the dominant-position count and
    /// the overall prevalence while turning the move into one atomic test.
    static func recurringCloseRushFallback(surface: CoachReplySurface) -> String {
        if surface == .live {
            return "The solid feeling is real; the next edge is the close. It has rushed in 4 of the last 5 fast-stretch reps and 5 of the last 6 overall, so plant one silent beat before the final line."
        }
        return "That solid feeling is real, and the next edge is specific: the fastest stretch keeps landing at the close. It has shown up in 4 of the last 5 reps with a fast stretch, and 5 of the last 6 overall — a recurring spot, not a trait — so plant one silent beat before the final line."
    }

    /// Recovery for "what do you actually know about me?" turns. This closes
    /// the skepticism loop first: a coach gives a bounded person-shaped read,
    /// not another prescription unless the user asks for the next drill.
    static func metadataSelfKnowledgeFallback(surface: CoachReplySurface) -> String {
        if surface == .live {
            return "Real read, not a script: you want to sound like yourself in hard conversations. The pattern I know is racing to fill silence under pressure; the safe numbers are roughly 170 WPM and a 12-day streak."
        }
        return "Real read, not a script: you came in wanting to sound like yourself in hard conversations. The pattern I know is that tense moments make you race to fill silence; the numbers I can safely name are a pace baseline around 170 WPM and a 12-day streak. That is what I know. I will wait on a next drill until you ask for one."
    }

    /// A discouraged pushback needs presence first. Prefer a bounded evidence
    /// anchor from the assessment when it exists; otherwise keep the line honest
    /// and small instead of inventing reassurance.
    static func vulnerablePushbackFallback(
        surface: CoachReplySurface,
        assessment: CoachAssessment?
    ) -> String {
        let step = vulnerablePushbackSmallStep(from: assessment)
        if vulnerablePushbackHasPressureCloseAnchor(
            evidence: assessment?.evidenceUsed ?? [],
            step: step
        ) {
            return "Fair push: no, it is not easy. The hard part is holding the silent beat at the pressure point before the final sentence. Keep the next rep smaller: say only the close — one silent beat, the final sentence, then stop."
        }
        let frame = vulnerablePushbackDifficultyFrame(for: step)
        if let anchor = vulnerablePushbackEvidenceAnchor(from: assessment?.evidenceUsed ?? []) {
            return surface == .live
                ? "Fair push: no, it is not easy. \(anchor) \(frame) Keep it small: \(step)"
                : "Fair push: no, it is not easy. \(anchor) \(frame) Keep the next step small: \(step)"
        }
        return surface == .live
            ? "Fair push: no, it is not easy. \(frame) Keep it small: \(step)"
            : "Fair push: no, it is not easy. \(frame) Keep the next step small: \(step)"
    }

    /// Recovery for a voice/goal-change reply that tried to own the UI state
    /// write. Keep it as a coach recommendation; no button-copy, no lock/set/save
    /// promise.
    static func goalStateDirectiveFallback(
        surface: CoachReplySurface,
        latestUserTurn: String?,
        replyText: String = ""
    ) -> String {
        let lowered = normalize(latestUserTurn ?? "")
        if containsAny(lowered, ["engaging", "more engaging", "engage"]) {
            let progress = goalStateProgressAnchor(replyText)
            return "\(progress)Engaging maps closest to Storytelling because the goal is more memorable shape; Warm is the comparison only if the gap is connection. Use the latest rep as the baseline, then test Storytelling once. What changed: did the room need more energy, or did the current voice feel too distant?"
        }
        if containsAny(lowered, ["what voice", "which voice", "voice should", "six", "dont know", "don't know"]) {
            return "Start with Authoritative because short verdicts can hold the floor in meetings where you get talked over; Executive presence is the comparison only if the real pressure is a senior room."
        }
        if containsAny(lowered, ["authoritative", "verdict-first", "verdict first"]) {
            return surface == .live
                ? "Authoritative is a sensible recommendation: verdict first, one reason, clean stop. Try it on the next 60-second answer."
                : "Authoritative is a sensible recommendation: verdict first, one reason, clean stop. Treat it as the voice to try next; the practice test is a 60-second answer where sentence one carries the recommendation."
        }
        return surface == .live
            ? "I can recommend the direction without pretending to change it from chat. Start with the voice that matches the room, then test it in one short answer."
            : "I can recommend the direction without pretending to change it from chat. Start with the voice that matches the room you actually need to handle, then test it in one short answer."
    }

    static func goalStateProgressAnchor(_ replyText: String) -> String {
        let normalized = normalize(replyText)
        if containsAny(normalized, ["three weeks", "3 weeks", "authoritative work is landing"]) {
            return "Your authoritative work is already landing, so do not throw it away yet. "
        }
        return ""
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
            return greetingFallback(surface: surface, assessment: assessment)
        }
        if lowCapacityUserTurn(latestUserTurn) {
            return lowCapacityFallback(
                surface: surface,
                previousCoachReply: previousCoachReply,
                recentCoachReplies: recentCoachReplies
            )
        }
        if let latestUserTurn,
           TurnDepthClassifier.isLowSignalOffTopicTest(latestUserTurn) {
            return offTopicTestFallback(surface: surface)
        }
        if let latestUserTurn,
           isCoachThisEvidenceGapRequest(latestUserTurn) {
            return coachThisEvidenceGapFallback(surface: surface)
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

    static func isCoachThisEvidenceGapRequest(_ latestUserTurn: String) -> Bool {
        let lowered = normalize(latestUserTurn)
        return containsAny(lowered, [
            "can you coach this",
            "coach this?",
            "coach this for me",
            "coach me on this"
        ])
    }

    static func coachThisEvidenceGapFallback(surface: CoachReplySurface) -> String {
        surface == .live
            ? "I need one rep before I can coach this honestly. Record 60 seconds, then I'll read the opener and close."
            : "I need one rep before I can coach this honestly. Record 60 seconds, then I will read the opener and close."
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
                    "Keep it concrete: one 60-second rep, verdict first, and I'll give you the one change that matters.",
                    "One short rep — decision up front, clean stop — then I'll name the single fix."
                ]
                : [
                    "Keep this concrete. Run one 60-second rep — verdict first, one reason, clean stop — and I'll give you the single change that matters most.",
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

    static let genericRepairUserMarkers: [String] = [
        "too generic",
        "so generic",
        "sounds generic",
        "generic ai",
        "generic advice",
        "generic tips",
        "could be for anyone",
        "could go to anyone",
        "not specific",
        "isn't specific",
        "isnt specific"
    ]

    static let genericRepairScaffoldMarkers: [String] = [
        "the specific thing:",
        "specific thing:",
        "the specific pattern:",
        "specific pattern:",
        "real read:",
        "next rep:"
    ]

    static let genericRepairPatternMarkers: [String] = [
        "hedged the ask",
        "softened the ask",
        "the ask",
        "the number",
        "stating the number",
        "state the raise",
        "qualifier",
        "flat sentence",
        "recommendation arrived",
        "recommendation to the end",
        "recommendation all the way to the end",
        "recommendation first",
        "recommendation-first",
        "first sentence",
        "sentence one",
        "opener",
        "opening",
        "close",
        "point arrived",
        "warmth arrives",
        "warmth before",
        "warmth comes after",
        "reassuring the client",
        "reassurance before",
        "ordering signal",
        "one safe signal",
        "safe signal"
    ]

    static func genericRepairUserTurn(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return false }
        return containsAny(normalize(latestUserTurn), genericRepairUserMarkers)
    }

    /// True when a genericness trust repair still sounds scaffolded or never
    /// gives the concrete pattern the user asked for.
    static func genericRepairNeedsSpecificPattern(_ text: String) -> Bool {
        let normalized = normalize(text)
        if containsAny(normalized, genericRepairScaffoldMarkers) {
            return true
        }
        if normalized.range(
            of: #"\b[0-9]+(\.[0-9]+)?\s+(fillers?|filler words?)\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        if normalized.range(
            of: #"\bscore[sd]? [0-9]+\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        return !containsAny(normalized, genericRepairPatternMarkers)
    }

    static let notInformativeRepairUserMarkers: [String] = [
        "not informative",
        "not useful",
        "not helpful",
        "doesn't help",
        "doesnt help",
        "does not help",
        "missed the point",
        "too vague",
        "vague answer"
    ]

    static let notInformativeRepairScaffoldMarkers: [String] = [
        "real read:",
        "that was fluff",
        "cut the throat-clearing",
        "cut the throat clearing",
        "cut the fluff",
        "next rep:",
        "not coaching. real read"
    ]

    static func notInformativeRepairUserTurn(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return false }
        return containsAny(normalize(latestUserTurn), notInformativeRepairUserMarkers)
    }

    static func leaksNotInformativeRepairScaffold(_ text: String) -> Bool {
        let normalized = normalize(text)
        if containsAny(normalized, notInformativeRepairScaffoldMarkers) {
            return true
        }
        if normalized.range(
            of: #"\bscore [0-9]+\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        if normalized.range(
            of: #"\b[0-9]+/10\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        return false
    }

    static let straightAnswerUserMarkers: [String] = [
        "straight answer",
        "just answer",
        "answer me directly",
        "direct answer",
        "give me a yes or no",
        "yes or no"
    ]

    static func straightAnswerUserTurn(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return false }
        return containsAny(normalize(latestUserTurn), straightAnswerUserMarkers)
    }

    static func straightAnswerNeedsSplitRepair(_ text: String) -> Bool {
        let normalized = normalize(text)
        if straightAnswerLeaksReportVoice(normalized) {
            return true
        }
        guard containsAny(normalized, ["straight answer", "plain answer", "direct answer"]) else {
            return true
        }
        let hasYesHalf = containsAny(normalized, [
            "yes on",
            "yes, on",
            "yes for",
            "yes: fillers",
            "yes. fillers",
            "yes — fillers",
            "yes - fillers"
        ])
        let hasNoHalf = containsAny(normalized, [
            "no on",
            "no, on",
            "no for",
            "no: pace",
            "no. pace",
            "no — pace",
            "no - pace",
            "not on pace",
            "pace is no"
        ])
        return !(hasYesHalf && hasNoHalf)
    }

    static func straightAnswerLeaksReportVoice(_ normalized: String) -> Bool {
        if normalized.range(
            of: #"\bhit [0-9]+ in [0-9]+ seconds\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        if normalized.range(
            of: #"\blast rep (hit )?[0-9]+ in [0-9]+ seconds\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        if normalized.range(
            of: #"\bscored [0-9]+\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        return false
    }

    static let repetitionCalloutUserMarkers: [String] = [
        "repeating yourself",
        "repeat yourself",
        "repeated yourself",
        "same thing again",
        "same advice again",
        "same drill again",
        "same note again",
        "same target again",
        "on loop"
    ]

    static func repetitionCalloutUserTurn(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return false }
        return containsAny(normalize(latestUserTurn), repetitionCalloutUserMarkers)
    }

    static func repetitionCourseCorrectionNeedsRepair(replyText: String) -> Bool {
        let normalized = normalize(replyText)
        if repetitionCourseCorrectionLeaksReportVoice(normalized) {
            return true
        }
        if repeatsOldPointFirstDrill(normalized) {
            return true
        }
        let ownsRepetition = containsAny(normalized, [
            "repeat the same",
            "repeated the same",
            "same drill",
            "same target",
            "same note",
            "same coaching",
            "i did repeat",
            "that was the same"
        ])
        let marksOldTargetMet = containsAny(normalized, [
            "already cleared",
            "already met",
            "target is met",
            "target was met",
            "it is done",
            "it's done",
            "its done",
            "no reason to run it again",
            "no reason to run that drill again",
            "led clean",
            "led cleanly",
            "close held",
            "closed clean",
            "clean close"
        ])
        let advancesPlan = containsAny(normalized, [
            "new target",
            "next target",
            "next lever",
            "move on",
            "advance",
            "pace",
            "tempo",
            "variation",
            "vary"
        ])
        // A repeated intervention does not always mean the target is complete.
        // When the evidence is still unresolved, the honest course correction is
        // to keep the target and change how it is tested. Requiring the coach to
        // declare the old target "met" fabricated progress and forced a needless
        // pivot whenever a user called out repetition.
        let changesProofMethod = containsAny(normalized, [
            "change the proof",
            "change the test",
            "change the check",
            "different proof",
            "different test",
            "different check",
            "changing the evidence",
            "same target, different",
            "keep the close as the target",
            "keep the target"
        ])
        let namesConcreteComparison = containsAny(normalized, [
            "compare whether",
            "before or after",
            "mark where",
            "mark the first",
            "listen for",
            "track whether",
            "check whether",
            "find where"
        ])
        let advancesEvidence = changesProofMethod && namesConcreteComparison
        return !(ownsRepetition && ((marksOldTargetMet && advancesPlan) || advancesEvidence))
    }

    static func repetitionCourseCorrectionLeaksReportVoice(_ normalized: String) -> Bool {
        if normalized.range(
            of: #"\b(?:score|scored|hit)\s+\d{2,3}\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        if normalized.range(
            of: #"\b(?:clean|landed|held)\s+at\s+\d{2,3}\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        return false
    }

    static func repeatsOldPointFirstDrill(_ normalized: String) -> Bool {
        return normalized.range(
            of: #"\blead(?:ing)?\s+with\s+(?:the\s+|your\s+)?point\b"#,
            options: .regularExpression
        ) != nil
            || normalized.range(
                of: #"\bpoint\s+(?:up\s+)?front\b"#,
                options: .regularExpression
            ) != nil
            || normalized.range(
                of: #"\bpoint\s+in\s+(?:the\s+)?first\s+sentence\b"#,
                options: .regularExpression
            ) != nil
    }

    static let paceSelfFrustrationUserMarkers: [String] = [
        "talk too fast",
        "talk way too fast",
        "speak too fast",
        "speaking too fast",
        "too fast",
        "can't keep up",
        "cant keep up",
        "people can't keep up",
        "people cant keep up",
        "i rush",
        "i'm rushing",
        "im rushing"
    ]

    static let paceSelfFrustrationGenericAdviceMarkers: [String] = [
        "just slow down",
        "be more confident",
        "try to relax",
        "take a breath",
        "practice more",
        "speak slower"
    ]

    static let paceSelfFrustrationAttunementMarkers: [String] = [
        "you're not imagining",
        "you are not imagining",
        "makes sense",
        "that makes sense",
        "people can't keep up",
        "people cant keep up",
        "not a confidence problem",
        "not confidence"
    ]

    static let paceSelfFrustrationGapMarkers: [String] = [
        "gap between sentences",
        "gap between points",
        "sentence boundary",
        "full stop",
        "silent beat",
        "pause",
        "pause rate",
        "space between",
        "room to land"
    ]

    static func paceSelfFrustrationUserTurn(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return false }
        let normalized = normalize(latestUserTurn)
        // A neutral diagnostic question ("Am I rushing?") needs a direct
        // evidence read, not the empathy-heavy self-frustration recovery path.
        if containsAny(normalized, [
            "am i rushing",
            "was i rushing",
            "do i rush",
            "did i rush"
        ]),
           !containsAny(normalized, [
               "too fast",
               "way too fast",
               "can't keep up",
               "cant keep up"
           ]) {
            return false
        }
        return containsAny(normalized, paceSelfFrustrationUserMarkers)
    }

    static func paceSelfFrustrationNeedsRepair(replyText: String) -> Bool {
        let normalized = normalize(replyText)
        if straightAnswerLeaksReportVoice(normalized) {
            return true
        }
        if containsAny(normalized, paceSelfFrustrationGenericAdviceMarkers) {
            return true
        }
        if !containsAny(normalized, paceSelfFrustrationAttunementMarkers) {
            return true
        }
        let namesPace = containsAny(normalized, [
            "pace",
            "speed",
            "fast",
            "slow",
            "rush",
            "rushing"
        ])
        guard namesPace else { return false }
        return !containsAny(normalized, paceSelfFrustrationGapMarkers)
    }

    static func paceSelfFrustrationMetricRead(
        assessment: CoachAssessment?,
        replyText: String
    ) -> String? {
        let evidence = assessment?.evidenceUsed.joined(separator: " ") ?? ""
        let source = "\(evidence) \(replyText)"
        let pace = firstRegexCapture(
            in: source,
            patterns: [
                #"\b([1-9][0-9]{2})\s*(?:wpm|words a minute|words per minute)\b"#,
                #"\bpace(?:\s+(?:sat|held|is|was|near|around|estimate|estimate:|at))*\s*(?:near|around|at)?\s*([1-9][0-9]{2})\b"#
            ]
        )
        let pauseRate = firstRegexCapture(
            in: source,
            patterns: [
                #"\bpause rate(?:\s*(?:is|was|:|-|=))?\s*(0\.[0-9]+)\b"#,
                #"\b(0\.[0-9]+)\s*pause rate\b"#
            ]
        )
        switch (pace, pauseRate) {
        case let (pace?, pauseRate?):
            return "\(pace) WPM with a \(pauseRate) pause rate"
        case let (pace?, nil):
            return "\(pace) WPM"
        case let (nil, pauseRate?):
            return "a \(pauseRate) pause rate"
        case (nil, nil):
            return nil
        }
    }

    static let rambleStoppingRuleUserMarkers: [String] = [
        "i ramble",
        "ramble",
        "rambling",
        "lose the thread",
        "losing the thread",
        "somewhere else",
        "go on too long",
        "talk too long",
        "keep talking",
        "keep adding",
        "side story",
        "side stories"
    ]

    static let rambleStoppingRuleMechanismMarkers: [String] = [
        "stop signal",
        "stopping rule",
        "stop rule",
        "hard stop",
        "one line of support",
        "one support line",
        "one supporting reason",
        "side story",
        "side stories",
        "weaker version",
        "weaker repeat",
        "restate",
        "reopening",
        "keep adding",
        "point, one",
        "point. one",
        "point; one",
        "point, then silence",
        "one point, then silence"
    ]

    static let rambleStoppingRuleGenericAdviceMarkers: [String] = [
        "be more concise",
        "stay concise",
        "focus more",
        "stay focused",
        "structure your thoughts",
        "keep it brief",
        "practice summarizing"
    ]

    /// A rambling repair still needs to model concise delivery, but the reply
    /// may spend a short sentence naming an evidence limitation before giving
    /// the concrete stop rule. Keep a hard ceiling while leaving enough room
    /// for that honest calibration plus one bounded prescription.
    static let rambleStoppingRuleAbsoluteWordCeiling = 65

    static let rambleStoppingRuleScaffoldMarkers: [String] = [
        "next rep:",
        "try this next:",
        "proof test:",
        "the fix is:"
    ]

    static func rambleStoppingRuleUserTurn(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return false }
        let normalized = normalize(latestUserTurn)
        // "Add depth without rambling" names a design constraint, not an
        // observed loss of control. Treating every such phrase as a ramble
        // incident discards the user's actual depth question and forces the
        // generic hard-stop recovery.
        if containsAny(normalized, [
            "without rambling",
            "without ramble"
        ]) {
            return false
        }
        return containsAny(normalized, rambleStoppingRuleUserMarkers)
    }

    static func rambleStoppingRuleFallbackContext(
        latestUserTurn: String?,
        assessment: CoachAssessment?
    ) -> String {
        normalize([
            latestUserTurn ?? "",
            assessment?.questionRestatement ?? "",
            assessment?.directVerdict ?? "",
            assessment?.nextProofTest ?? "",
            assessment?.evidenceUsed.joined(separator: " ") ?? "",
            assessment?.missingEvidence.joined(separator: " ") ?? ""
        ].joined(separator: " "))
    }

    static func rambleStoppingRuleContextSuggestsConciseRecommendation(_ context: String) -> Bool {
        let hasRecommendationFrame = containsAny(context, [
            "recommendation",
            "client"
        ])
        let hasSpecificRambleBoundary = containsAny(context, [
            "second reason",
            "two sentence",
            "two-sentence",
            "sentence ceiling",
            "extra context",
            "tighten"
        ])
        return hasRecommendationFrame || hasSpecificRambleBoundary
    }

    static func rambleStoppingRuleNeedsRepair(replyText: String) -> Bool {
        let normalized = normalize(replyText)
        if rambleStoppingRuleHasScaffoldLabel(normalized) {
            return true
        }
        if wordCount(normalized) > rambleStoppingRuleAbsoluteWordCeiling {
            return true
        }
        if containsAny(normalized, rambleStoppingRuleGenericAdviceMarkers) {
            return true
        }
        return !containsAny(normalized, rambleStoppingRuleMechanismMarkers)
            && !rambleStoppingRuleHasBoundedMechanism(normalized)
    }

    /// Detect colon-led coaching labels at a sentence boundary without
    /// misclassifying a natural sentence such as "Test this on your next rep:"
    /// merely because it contains the substring `next rep:`.
    static func rambleStoppingRuleHasScaffoldLabel(_ normalized: String) -> Bool {
        rambleStoppingRuleScaffoldMarkers.contains { marker in
            normalized.hasPrefix(marker) ||
                containsAny(normalized, [
                    ". \(marker)",
                    "! \(marker)",
                    "? \(marker)"
                ])
        }
    }

    /// Accepts concrete answer shapes that bound the response even when they do
    /// not use our preferred "hard stop" vocabulary. This keeps the gate focused
    /// on the invariant (a usable stopping boundary), not one fixture's wording.
    static func rambleStoppingRuleHasBoundedMechanism(_ normalized: String) -> Bool {
        let hasBoundedUnit = containsAny(normalized, [
            "one example",
            "one reason",
            "one question",
            "one point",
            "one support",
            "one line",
            "two-sentence",
            "two sentence",
            "sentence ceiling",
            "second thread",
            "second reason"
        ]) || normalized.range(
            of: #"\b[0-9]+[ -](?:second|sentence|example|reason|question|point|line)\b"#,
            options: .regularExpression
        ) != nil

        let hasStopBoundary = containsAny(normalized, [
            "then stop",
            "clean stop",
            "before adding",
            "before a second",
            "no full story",
            "ceiling",
            "then silence",
            "and stop"
        ])
        return hasBoundedUnit && hasStopBoundary
    }

    static func firstRegexCapture(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            return String(text[captureRange])
        }
        return nil
    }

    static let leadershipStatusReportUserMarkers: [String] = [
        "leadership update",
        "weekly update",
        "department update",
        "whole department",
        "status report",
        "people zone out",
        "zone out"
    ]

    static func leadershipStatusReportUserTurn(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return false }
        let normalized = normalize(latestUserTurn)
        let hasLeadershipMoment = containsAny(normalized, [
            "leadership update",
            "weekly update",
            "department update",
            "whole department"
        ])
        let hasStatusProblem = containsAny(normalized, [
            "status report",
            "zone out",
            "people zone out"
        ])
        return hasLeadershipMoment && hasStatusProblem
    }

    static func leadershipStatusReportNeedsRepair(replyText: String) -> Bool {
        let normalized = normalize(replyText)
        if leadershipStatusReportLeaksReportVoice(normalized) {
            return true
        }
        let namesHierarchy = containsAny(normalized, [
            "hierarchy",
            "one thing",
            "so what",
            "top-line",
            "top line",
            "same weight",
            "equal weight",
            "through-line",
            "through line"
        ])
        let hasSameNightRehearsal = containsAny(normalized, [
            "tonight",
            "write the opener",
            "write and say",
            "say the opener",
            "say it aloud",
            "rehearse",
            "aloud"
        ])
        return !(namesHierarchy && hasSameNightRehearsal)
    }

    static func leadershipStatusReportLeaksReportVoice(_ normalized: String) -> Bool {
        if normalized.range(
            of: #"\b(?:clean|landed|held)\s+at\s+\d{2,3}\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        if normalized.range(
            of: #"\b(?:score|scored|hit)\s+\d{2,3}\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        return false
    }

    static func recurringCloseRushUserTurn(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return false }
        let normalized = normalize(latestUserTurn)
        let asksNextWork = containsAny(normalized, [
            "what should i work on next",
            "what should i work on",
            "work on next",
            "next thing to work on",
            "what next"
        ])
        let feltSolid = containsAny(normalized, [
            "felt solid",
            "feels solid",
            "last one felt solid",
            "that felt solid",
            "solid to me"
        ])
        return asksNextWork && feltSolid
    }

    static func recurringCloseRushTrendAvailable(
        assessment: CoachAssessment?,
        replyText: String
    ) -> Bool {
        let source = [
            assessment?.directVerdict ?? "",
            assessment?.evidenceUsed.joined(separator: " ") ?? "",
            assessment?.nextProofTest ?? "",
            replyText
        ].joined(separator: " ")
        let normalized = normalize(source)
        guard containsAny(normalized, ["close", "final line", "ending"]) else {
            return false
        }
        return recurringCloseRushDominantCountPresent(normalized)
            && recurringCloseRushOverallCountPresent(normalized)
    }

    static func recurringCloseRushNeedsRepair(replyText: String) -> Bool {
        let normalized = normalize(replyText)
        if containsAny(normalized, ["next rep:", "proof test:", "diagnosis:"]) {
            return true
        }
        if !(recurringCloseRushDominantCountPresent(normalized)
                && recurringCloseRushOverallCountPresent(normalized)) {
            return true
        }
        let moveMarkers = [
            "second-to-last sentence",
            "second to last sentence",
            "silent beat",
            "final line at half",
            "half the pace",
            "say the final line",
            "slow the exit"
        ]
        let moveCount = moveMarkers.reduce(0) { count, marker in
            normalized.contains(marker) ? count + 1 : count
        }
        return moveCount > 2
    }

    static func recurringCloseRushDominantCountPresent(_ normalized: String) -> Bool {
        normalized.range(
            of: #"\b4\s+of\s+(?:your\s+|the\s+)?last\s+5\b"#,
            options: .regularExpression
        ) != nil
    }

    static func recurringCloseRushOverallCountPresent(_ normalized: String) -> Bool {
        normalized.range(
            of: #"\b(?:5|five)\s+of\s+(?:your\s+|the\s+)?last\s+(?:6|six)\b"#,
            options: .regularExpression
        ) != nil
    }

    static func metadataSelfKnowledgeUserTurn(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return false }
        let normalized = normalize(latestUserTurn)
        return containsAny(normalized, [
            "what does your system actually know about me",
            "what do you actually know about me",
            "what do you know about me",
            "what does noum know about me",
            "what does your system know about me",
            "what do you have on me"
        ])
    }

    static func metadataSelfKnowledgeSourceAvailable(
        assessment: CoachAssessment?,
        replyText: String
    ) -> Bool {
        let source = [
            assessment?.directVerdict ?? "",
            assessment?.evidenceUsed.joined(separator: " ") ?? "",
            assessment?.nextProofTest ?? "",
            replyText
        ].joined(separator: " ")
        let normalized = normalize(source)
        let hasGoal = containsAny(normalized, [
            "sound like yourself",
            "sounding like yourself",
            "hard conversations",
            "tough conversations"
        ])
        let hasPressurePattern = containsAny(normalized, [
            "fill silence",
            "outrun the silence",
            "race to fill",
            "speed up",
            "tense"
        ])
        let hasBoundedNumbers = containsAny(normalized, [
            "170 pace",
            "170 wpm",
            "twelve days",
            "12 days",
            "12-day",
            "twelve-day"
        ])
        return hasGoal && hasPressurePattern && hasBoundedNumbers
    }

    static func metadataSelfKnowledgeNeedsRepair(replyText: String) -> Bool {
        let normalized = normalize(replyText)
        if containsAny(normalized, metadataSelfKnowledgeLeakMarkers) {
            return true
        }
        if containsAny(normalized, metadataSelfKnowledgePrescriptionMarkers) {
            return true
        }
        let closesSkepticismLoop = containsAny(normalized, [
            "real read",
            "not a script",
            "not a database",
            "what i know"
        ])
        return !closesSkepticismLoop && wordCount(normalized) > 75
    }

    static let metadataSelfKnowledgeLeakMarkers: [String] = [
        "system prompt",
        "context block",
        "metadata",
        "database row",
        "section header",
        "raw json",
        "internal scaffold"
    ]

    static let metadataSelfKnowledgePrescriptionMarkers: [String] = [
        "so the thing to test",
        "thing to test",
        "next rep",
        "try this next",
        "run one",
        "record 60",
        "hold one silent beat",
        "proof test"
    ]

    static func wordCount(_ normalized: String) -> Int {
        normalized.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// True for vulnerable / discouraged turns where ending on a diagnostic
    /// question would read as loading the next job back onto the user.
    static func vulnerablePushbackUserTurn(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return false }
        let lowered = normalize(latestUserTurn)
        return containsAny(lowered, [
            "it's not easy",
            "its not easy",
            "not easy",
            "not that easy",
            "easier said",
            "harder than",
            "this is hard",
            "that is hard",
            "i freeze",
            "i froze",
            "i blank",
            "i panic",
            "i get stuck",
            "discouraged",
            "defeated"
        ])
    }

    /// A vulnerable reply can include a question if it is attached to a real
    /// invitation or small step. It should not end with a bare probe like "what
    /// goes first?" after the user has just said the work feels hard.
    static func burdensVulnerablePushback(
        reply: String,
        latestUserTurn: String?
    ) -> Bool {
        guard vulnerablePushbackUserTurn(latestUserTurn) else { return false }
        let lowered = normalize(reply)
        guard lowered.hasSuffix("?") else { return false }
        if containsAny(lowered, vulnerablePushbackSafeQuestionMarkers) {
            return false
        }
        if containsAny(lowered, lowPressureActionMarkers) {
            return false
        }
        return true
    }

    static let vulnerablePushbackSafeQuestionMarkers: [String] = [
        "want to go",
        "want to try",
        "want to give it",
        "can we start",
        "shall we",
        "ready to"
    ]

    static let lowPressureActionMarkers: [String] = [
        "test a smaller version",
        "smaller version",
        "one calm reason",
        "say only",
        "stop before",
        "one small step",
        "keep it small",
        "keep the next step small",
        "silent beat",
        "next rep",
        "record 60 seconds",
        "no full performance test"
    ]

    static func vulnerablePushbackEvidenceAnchor(from evidence: [String]) -> String? {
        let lowered = normalize(evidence.joined(separator: " "))
        if containsAny(lowered, ["held composure", "through an interruption", "handled an interruption"]) {
            return "There is already one concrete example: this week you held composure through an interruption."
        }
        if containsAny(lowered, ["clean under pressure", "stayed clean under pressure"]) {
            return "There is already one concrete example: you have stayed clean under pressure once."
        }
        if containsAny(lowered, ["landed clean", "clean rep", "reps you keep landing clean"]) {
            return "There is already one concrete example: you have landed clean reps before."
        }
        return nil
    }

    static func vulnerablePushbackHasPressureCloseAnchor(
        evidence: [String],
        step: String
    ) -> Bool {
        let lowered = normalize((evidence + [step]).joined(separator: " "))
        let namesClose = containsAny(lowered, [
            "close", "final sentence", "final line", "the ending", "your ending", "the ask"
        ])
        let namesPressureBeat = containsAny(lowered, [
            "silent beat", "silence", "pause", "pressure", "filler"
        ])
        return namesClose && namesPressureBeat
    }

    static func vulnerablePushbackSmallStep(from assessment: CoachAssessment?) -> String {
        guard let assessment else {
            return "say only the first hard sentence, then stop."
        }
        let proof = assessment.nextProofTest
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = normalize(proof)
        guard !proof.isEmpty,
              containsAny(lowered, lowPressureActionMarkers) else {
            return "say only the first hard sentence, then stop."
        }
        return sentence(proof)
    }

    static func vulnerablePushbackDifficultyFrame(for step: String) -> String {
        let lowered = normalize(step)
        if containsAny(lowered, ["disagreement", "calm reason", "defending", "defend it"]) {
            return "The hard part is that sentence one carries the social risk."
        }
        return "The hard part is the first hard sentence, not the whole performance."
    }

    static func sentence(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last,
              last == "." || last == "?" || last == "!" else {
            return trimmed + "."
        }
        return trimmed
    }

    static func goalOrVoiceChangeUserTurn(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return false }
        let lowered = normalize(latestUserTurn)
        if containsAny(lowered, [
            "what voice",
            "which voice",
            "voice should",
            "voice do i",
            "voice to pick",
            "pick a voice",
            "choose a voice",
            "choose my voice",
            "set me to",
            "change my goal",
            "change my voice",
            "switch my voice",
            "sound more engaging",
            "sound warmer",
            "sound more warm",
            "something warmer",
            "warmer altogether",
            "more authoritative",
            "more persuasive",
            "more executive",
            "more concise",
            "more storytelling"
        ]) {
            return true
        }
        let voiceNames = [
            "authoritative", "warm", "concise", "persuasive",
            "executive", "storytelling", "engaging"
        ]
        return containsAny(lowered, voiceNames)
            && containsAny(lowered, ["set", "change", "switch", "pick", "choose"])
    }

    static let goalStateDirectiveMarkers: [String] = [
        "tap to confirm",
        "tap the card",
        "tap confirm",
        "confirm and i'll",
        "confirm and i will",
        "i'll lock it in",
        "i will lock it in",
        "ill lock it in",
        "lock it in",
        "i'll set it",
        "i will set it",
        "ill set it",
        "i'll set your voice",
        "i will set your voice",
        "ill set your voice",
        "i've set",
        "i have set",
        "voice is now",
        "voice has been",
        "i'll save",
        "i will save",
        "that answer picks the voice",
        "that picks the voice"
    ]

    static func leaksGoalStateDirective(_ lowered: String) -> Bool {
        containsAny(lowered, goalStateDirectiveMarkers)
    }

    static func leaksGoalStateReportVoice(_ lowered: String) -> Bool {
        let patterns = [
            #"\b(?:score|scored|hit)\s+\d{2,3}\b"#,
            #"\b\d{2,3}\s+this week\b"#,
            #"\b\d+\s+fillers?\s+(?:in|over|across)\s+\d{2,3}\s*(?:s|sec(?:ond)?s?)\b"#,
            #"\b\d{2,3}\s*(?:/|over)\s*\d{2,3}\s*s(?:ec(?:ond)?s?)?\s*(?:/|with)\s*(?:only\s*)?\d+\s+fillers?\b"#,
            #"\b\d(?:\.\d)?\s*/\s*10\b"#
        ]
        return patterns.contains { pattern in
            lowered.range(of: pattern, options: .regularExpression) != nil
        }
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
