import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - Primary Focus Memory
//
// Persists the last-known `TrendAnalyzer.primaryFocus(...)` result per
// account so we can detect when the coach's recommended focus area has
// shifted since the user last opened the app. A shift is surfaced in
// `AIWeeklyInsightCard` and the weekly digest notification copy — the
// lowest-cost / highest-trust signal that the coach is adapting.

struct FocusShiftEvent {
    let from: SkillArea
    let to: SkillArea
    let detectedAt: Date
}

enum PrimaryFocusMemory {

    private static func key(for accountID: String) -> String {
        "lastPrimaryFocus.\(accountID)"
    }

    // MARK: - Persist

    static func save(_ focus: SkillArea, for accountID: String) {
        UserDefaults.standard.set(focus.rawValue, forKey: key(for: accountID))
    }

    // MARK: - Detect shift

    /// Returns a `FocusShiftEvent` when `current` differs from the persisted
    /// last focus. Persists `current` before returning so the next call
    /// starts from the updated baseline. Returns nil on first run (no prior)
    /// or when the focus is unchanged.
    @discardableResult
    static func detectShift(
        current: SkillArea,
        accountID: String
    ) -> FocusShiftEvent? {
        let storedRaw = UserDefaults.standard.string(forKey: key(for: accountID))
        let prior = storedRaw.flatMap { SkillArea(rawValue: $0) }
        save(current, for: accountID)
        guard let prior, prior != current else { return nil }
        return FocusShiftEvent(from: prior, to: current, detectedAt: Date())
    }

    // MARK: - Read (without mutating)

    static func lastFocus(for accountID: String) -> SkillArea? {
        UserDefaults.standard.string(forKey: key(for: accountID))
            .flatMap { SkillArea(rawValue: $0) }
    }
}

// MARK: - Coach Memory
//
// PrimaryFocusMemory is intentionally tiny: last focus in, shift event out.
// CoachMemory is the richer "professional coach's working read" layered on
// the same product idea. It persists the current formulation per account so
// Ask Noum can say "my read has shifted" instead of re-deriving a fresh,
// stateless hypothesis on every chat turn.

enum CoachMemoryGoalFit: String, Codable, Equatable {
    case aligned
    case offGoal
    case noVoice
    case noLever
}

/// How the measured coaching lever lines up with the challenge the user
/// *stated* at onboarding (`CoachingProfile.biggestChallenge`). This is the
/// stated-vs-measured concordance read a human coach keeps in mind: never
/// silently overrule what the client said they want to work on. Bounded,
/// `Codable`, and defaulted (`.unknown`) so a `CoachMemory` blob persisted
/// before this field decodes cleanly.
///
/// Semantics (all decided in `CoachMemoryEngine.selectLever`):
///   • `.unknown`     — no stated challenge on file, or no lever to compare.
///                      The coach says nothing about concordance.
///   • `.deferred`    — the baseline is still thin (below the evidence
///                      floor). The measured read isn't trustworthy enough
///                      to challenge what the user said, so we defer to the
///                      stated challenge and stay tentative. No question.
///   • `.agree`       — above the floor, the measured lever maps to the same
///                      SkillArea the stated challenge points at. The coach
///                      can affirm "what you came in for is what the reps
///                      show" but raises no divergence question.
///   • `.divergent`   — above the floor, the measured lever points somewhere
///                      *other* than the stated challenge. The coach surfaces
///                      ONE divergence question ("you came in wanting X — the
///                      reps point more at Y; which should we anchor to?")
///                      and does NOT auto-flip the stored focus.
enum StatedChallengeConcordance: String, Codable, Equatable {
    case unknown
    case deferred
    case agree
    case divergent
}

enum CoachInterventionReviewStatus: String, Codable, Equatable {
    case awaitingAttempt
    case formingEvidence
    case continueAndVerify
    case diagnoseBeforeRepeating
    case adaptBeforeRepeating

    var contextLabel: String {
        switch self {
        case .awaitingAttempt:
            return "Awaiting a followed rep."
        case .formingEvidence:
            return "Evidence is forming."
        case .continueAndVerify:
            return "Continue and verify."
        case .diagnoseBeforeRepeating:
            return "Diagnose before repeating."
        case .adaptBeforeRepeating:
            return "Adapt before repeating."
        }
    }

    /// One shared continuation rule for every recommendation surface. A case
    /// that needs diagnosis or adaptation must not be prescribed unchanged.
    var shouldContinuePrescription: Bool {
        switch self {
        case .awaitingAttempt, .formingEvidence, .continueAndVerify:
            return true
        case .diagnoseBeforeRepeating, .adaptBeforeRepeating:
            return false
        }
    }
}

/// The measurable session metric a success criterion is judged against.
/// Restricted to fields every `PracticeSession` carries so status can always
/// be computed without a provider call or transcript re-analysis.
enum CoachCaseMetric: String, Codable, Equatable {
    /// Legacy raw-count metric retained only so persisted criteria decode.
    /// New filler criteria use `fillersPerMinute`; raw counts are duration-
    /// biased and must never be used for a newly built success measure.
    case fillersPerRep
    case fillersPerMinute
    case sessionScore
    case durationSeconds
    /// Focus-matched pace bar (transcript word count / duration — a field
    /// every session carries). Reads can be unreliable on very short reps, so
    /// `metricValue` returns nil below a duration floor and the criterion
    /// stays `.pending` until the window carries real readings.
    case wordsPerMinute
}

/// Shared pace-coaching vocabulary: one band + one prescription detector used
/// by BOTH the success-criterion builder (PrimaryFocusMemory) and the
/// adaptation analyzer (RecommendationAdaptationAnalyzer), so "what counts as
/// a pace prescription" and "what counts as healthy pace" can never drift
/// between the bar a prescription is held to and the ledger read that judges
/// its response.
enum PaceCoaching {
    /// The healthy conversational band — the same slow/fast cutoffs the
    /// reasoning pass uses (105 / 175 wpm).
    static let healthyBand: ClosedRange<Double> = 105...175

    private static let keywords = [
        "pace", "pacing", "rushing", "rushed", "too fast",
        "slow down", "words per minute", "wpm", "speaking speed"
    ]

    /// Whether a prescription is genuinely about pace. Filler prescriptions
    /// keep precedence (an Ah-Counter drill mentioning "slow your pace" stays
    /// a filler prescription).
    static func isPaceFocused(mode: PracticeMode, focus: String?, title: String) -> Bool {
        let haystack = "\(focus ?? "") \(title)".lowercased()
        guard mode != .ahCounter, !haystack.contains("filler") else { return false }
        return keywords.contains { haystack.contains($0) }
    }

    /// Distance from the healthy band (0 inside the band). The adaptation
    /// read judges pace movement by whether this shrank — polarity-correct
    /// for fast AND slow talkers without guessing a direction from copy.
    static func distanceFromBand(_ wordsPerMinute: Double) -> Double {
        if wordsPerMinute < healthyBand.lowerBound { return healthyBand.lowerBound - wordsPerMinute }
        if wordsPerMinute > healthyBand.upperBound { return wordsPerMinute - healthyBand.upperBound }
        return 0
    }
}

enum CoachCaseComparator: String, Codable, Equatable {
    case atMost
    case atLeast
}

enum CoachCriterionStatus: String, Codable, Equatable {
    case pending
    case met
    case notYetMet

    var contextLabel: String {
        switch self {
        case .pending: return "not enough followed reps yet to judge"
        case .met: return "already meeting the target"
        case .notYetMet: return "not meeting the target yet"
        }
    }
}

/// "What improvement looks like before the user starts" — the explicit,
/// measurable bar a prescription is held to. Defined once when the
/// intervention is prescribed and kept stable across rebuilds; only its
/// `status` is recomputed from the user's followed reps.
struct CoachSuccessCriterion: Codable, Equatable {
    struct BaselineSnapshot: Codable, Equatable {
        /// The user's own pre-prescription average for this metric, captured
        /// when the bar was set.
        var priorAverage: Double
        /// The number of prior reps behind the average. Numeric copy is only
        /// emitted when this meets the named evidence floor.
        var sampleDepth: Int
    }

    var metric: CoachCaseMetric
    var comparator: CoachCaseComparator
    var threshold: Double
    var evaluationWindow: Int
    var summary: String
    /// Bounded evidence behind the success bar. nil means "thin sample; use
    /// generic copy." Optional for decode safety with older memories.
    var baselineSnapshot: BaselineSnapshot? = nil
    /// Provenance recipe used to select followed reps and evaluate this bar.
    /// Nil identifies criteria persisted before exact recommendation-outcome
    /// joins; those criteria are rebuilt rather than carrying a false status.
    var evidenceSchemaVersion: Int? = nil

    /// Pure judgement: given the metric values from the most-recent
    /// followed reps (newest first), decide met / not-yet-met / pending.
    /// `pending` until at least `evaluationWindow` reps exist so the coach
    /// never claims a verdict on thin evidence.
    func status(forFollowedValues values: [Double]) -> CoachCriterionStatus {
        guard values.count >= evaluationWindow, evaluationWindow > 0 else { return .pending }
        let window = Array(values.prefix(evaluationWindow))
        let average = window.reduce(0, +) / Double(window.count)
        switch comparator {
        case .atMost: return average <= threshold ? .met : .notYetMet
        case .atLeast: return average >= threshold ? .met : .notYetMet
        }
    }
}

/// One recorded course-change in the coaching case — the "reason for changing
/// course" a human coach states and remembers. Appended whenever the current
/// lever shifts so the case carries an honest, revisable history rather than
/// silently swapping focus.
struct CoachCourseChange: Codable, Equatable, Identifiable {
    var id: UUID
    var changedAt: Date
    var fromLever: SkillArea?
    var toLever: SkillArea?
    var reason: String
    var evidenceBasis: String

    /// Marker phrase shared with `CoachMemoryEngine.build(...)`'s rejection-
    /// aware adaptation branch. Both the `(prior?, ack?)` and `(nil, ack?)`
    /// switch arms write this clause into `reason`, so the predicate below
    /// matches whenever the documented reason is a user-tapped rejection.
    /// Lifted as a constant so a copy edit in the engine forces the predicate
    /// to follow in one place.
    static let userPushbackMarker = "user reported the prior hypothesis did not match"

    /// Round-33 marker phrase appended to `reason` by `CoachMemoryEngine.build(...)`
    /// when a `.rejected` ack is dropped AND the previous adaptation log's last
    /// entry was itself a user pushback rebuild — i.e., the user has now pushed
    /// back twice across consecutive rebuild cycles.
    ///
    /// Embedded as a parenthetical INSIDE the existing first-cycle reason, so:
    ///   - `documentsUserPushback` still returns true (the first-cycle marker
    ///     phrase is preserved verbatim).
    ///   - `documentsSecondCyclePushback` returns true only when this tail is
    ///     present, so the two predicates layer cleanly.
    ///
    /// The model copy in `CoachContextBuilder` reads off this predicate to
    /// surface "Case file shifted again" / "second adapt cycle" phrasing
    /// instead of treating the new entry as a first-time pushback. Without
    /// this, the round-32 "second pushback" signal in the chat-coach context
    /// goes dark the moment the engine drops the round-30 ack, even though
    /// the persistent record still carries the full cycle lineage.
    ///
    /// Phrasing kept short and parenthetical so the case-state line stays
    /// readable when surfaced in the user-context block; the leading clause
    /// remains the user's own verdict, the second-cycle tag is the qualifier.
    static let secondCyclePushbackMarker = "after a prior pushback rebuild"

    /// Marker phrase written into `reason` by
    /// `CoachMemoryStore.noteVoiceChange(...)` whenever the user confirms a
    /// voice-goal change from the in-chat goal-change card. Lets
    /// `CoachContextBuilder.recentVoiceChangeCount(...)` count only voice-change
    /// entries (not engine lever shifts or hypothesis rejections) in the
    /// bounded `adaptationLog` for the anti-thrash note. Lifted as a constant so
    /// a copy edit in the recorder forces the counter to follow in one place.
    static let voiceChangeMarker = "changed voice goal from"

    /// The canonical `reason` string for a user-confirmed voice-goal change.
    /// Always embeds `voiceChangeMarker` so `documentsVoiceChange` (and the
    /// anti-thrash counter that reads it) match every entry the in-chat card
    /// records — the caller can't forget the marker. Uses each voice's
    /// `shortVoiceLabel` so the recorded reason reads in the coach's register
    /// ("The user changed voice goal from warm voice to persuasive voice.").
    /// `kind == .blend` documents a keep-primary-add-secondary choice so the
    /// recorded history distinguishes a full switch from a blend.
    static func voiceChangeReason(
        from: SpeakingStyleGoal,
        to: SpeakingStyleGoal,
        kind: VoiceChangeKind = .switchVoice
    ) -> String {
        switch kind {
        case .switchVoice:
            return "The user changed voice goal from \(from.shortVoiceLabel) to \(to.shortVoiceLabel)."
        case .blend:
            return "The user changed voice goal from \(from.shortVoiceLabel) to a blend of \(from.shortVoiceLabel) (primary) and \(to.shortVoiceLabel) (secondary)."
        }
    }

    /// Distinguishes a full voice switch from a blend in the recorded reason.
    enum VoiceChangeKind {
        case switchVoice
        case blend
    }

    /// True iff this course change documents a user-confirmed voice-goal change
    /// (as opposed to an engine lever shift or a hypothesis rejection). Pure
    /// function of the persisted `reason` — no extra state to round-trip, so
    /// entries persisted before this lift decode and behave correctly.
    var documentsVoiceChange: Bool {
        reason.range(of: CoachCourseChange.voiceChangeMarker, options: .caseInsensitive) != nil
    }

    /// True iff this course change documents a user-tapped rejection of the
    /// prior working hypothesis (as opposed to an engine-only lever shift).
    /// Pure function of the persisted `reason` — no extra state to round-trip
    /// through Codable, so memories persisted before this lift decode and
    /// behave correctly without a schema bump.
    var documentsUserPushback: Bool {
        reason.range(of: CoachCourseChange.userPushbackMarker, options: .caseInsensitive) != nil
    }

    /// Round-33 predicate. True iff this course change documents a user
    /// pushback rebuild that itself followed a prior pushback rebuild —
    /// the user has now lodged at least two pushback cycles back-to-back.
    /// Pure function of the persisted `reason`; the engine writes the
    /// `secondCyclePushbackMarker` parenthetical only on the (nil, ack?) and
    /// (prior?, ack?) arms of `CoachMemoryEngine.build(...)` when the
    /// previous adaptation log's `.last` entry already documented user
    /// pushback. The marker is embedded INSIDE the first-cycle reason, so
    /// `documentsUserPushback` and `documentsSecondCyclePushback` are
    /// orthogonal: `documentsSecondCyclePushback` always implies
    /// `documentsUserPushback`, never the other way round.
    ///
    /// Read by `CoachContextBuilder.freshRevisedReadContextLines(memory:)`
    /// (round 31) and the generic "Last course change" line (the
    /// `interventionCycleLines` else-arm) so the model gets the second-cycle
    /// signal both in the rebuild's fresh window AND after it ages out —
    /// closing the round-32 gap where the "second pushback" tag in
    /// context lived only while the chip-row ack was carried in memory.
    var documentsSecondCyclePushback: Bool {
        reason.range(of: CoachCourseChange.secondCyclePushbackMarker, options: .caseInsensitive) != nil
    }

    /// Was this course change appended on the same rebuild that produced
    /// the carrying `CoachMemory`? Used by `RevisedReadCard` (post-rep
    /// summary) to surface "you flagged the prior read as off" only when
    /// the pushback was just folded in — not on every subsequent rep when
    /// the entry persists in the bounded adaptation history.
    ///
    /// Both `CoachCourseChange.changedAt` and `CoachMemory.updatedAt` are
    /// stamped from the same `now` in `CoachMemoryEngine.build(...)`, so
    /// equality holds round-trip after Codable. The 1-second tolerance is
    /// defensive against test fixtures that pass slightly-different `Date`
    /// instances.
    func isFresh(comparedTo memoryUpdatedAt: Date) -> Bool {
        abs(changedAt.timeIntervalSince(memoryUpdatedAt)) <= 1.0
    }
}

/// The next coaching move implied by a user's real-world outcome report.
/// This steers the review conversation without treating subjective transfer
/// evidence as proof that an intervention caused the result.
enum CoachTransferReviewAction: String, Codable, Equatable {
    case exploreWhatTransferred
    case diagnoseBeforeNextMoment
    case adaptBeforeNextMoment

    var contextInstruction: String {
        switch self {
        case .exploreWhatTransferred:
            return "Ask what specifically transferred before reinforcing the current intervention."
        case .diagnoseBeforeNextMoment:
            return "Ask what held and what broke down before repeating or changing the intervention."
        case .adaptBeforeNextMoment:
            return "Review what broke down and adapt preparation before the next similar moment."
        }
    }
}

/// A bounded snapshot of the latest off-app check-in held inside the durable
/// coaching case. `BigMomentStore` remains the complete outcome-history owner;
/// this is only the case file's current transfer-review decision.
struct CoachTransferReview: Codable, Equatable {
    var momentID: UUID
    var momentTitle: String
    var category: BigMomentCategory
    var outcome: ReportedMomentOutcome
    var audienceResponse: ReportedAudienceResponse
    var note: String?
    var drillTransfer: ReportedDrillTransfer?
    var recordedAt: Date
    var nextAction: CoachTransferReviewAction

    init(report: BigMomentOutcomeReport) {
        momentID = report.momentID
        momentTitle = report.momentTitle
        category = report.category
        outcome = report.outcome
        audienceResponse = report.audienceResponse
        note = report.note
        drillTransfer = report.drillTransfer
        recordedAt = report.recordedAt
        switch report.outcome {
        case .wentWell:
            nextAction = .exploreWhatTransferred
        case .mixed:
            nextAction = .diagnoseBeforeNextMoment
        case .fellShort:
            nextAction = .adaptBeforeNextMoment
        }
    }

    var reportedOutcomeLine: String {
        var line = "For \(category.displayName) \"\(momentTitle)\", the user reported \(outcome.coachClause); \(audienceResponse.coachClause)."
        if let drillTransfer {
            line += " They felt \(drillTransfer.coachClause)."
        }
        if let note {
            line += " Their note: \"\(note)\"."
        }
        return line
    }
}

/// The next coaching move implied by the user's self-reported inner
/// experience after a rep. This is deliberately a review instruction, not a
/// diagnosis: the user owns the feeling, and the coach asks the next useful
/// question.
enum CoachReflectionReviewAction: String, Codable, Equatable {
    case reinforceControl
    case diagnoseNerves
    case exploreAvoidance
    case calibrateAuthenticity

    var contextInstruction: String {
        switch self {
        case .reinforceControl:
            return "Ask what made the rep feel controlled before reinforcing the current intervention."
        case .diagnoseNerves:
            return "Ask where nerves appeared and whether the next rep needs a lower-pressure setup or a narrower target."
        case .exploreAvoidance:
            return "Ask what they avoided saying before strengthening or changing the intervention."
        case .calibrateAuthenticity:
            return "Ask what felt unlike them before coaching polish further."
        }
    }
}

/// A bounded snapshot of the latest post-rep reflection held inside durable
/// coach memory. `SessionReflectionStore` remains the historical owner; this
/// record is the current case-file read the AI coach receives every turn.
struct CoachReflectionReview: Codable, Equatable {
    var sessionID: UUID
    var feeling: ReflectionFeeling
    var note: String?
    var recordedAt: Date
    var nextAction: CoachReflectionReviewAction

    init(reflection: SessionReflection) {
        sessionID = reflection.sessionID
        feeling = reflection.feeling
        note = reflection.note
        recordedAt = reflection.recordedAt
        switch reflection.feeling {
        case .strong:
            nextAction = .reinforceControl
        case .nervous:
            nextAction = .diagnoseNerves
        case .heldBack:
            nextAction = .exploreAvoidance
        case .notLikeMe:
            nextAction = .calibrateAuthenticity
        }
    }

    var reportedLine: String {
        var line = "the user said \(feeling.coachClause)"
        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines),
           !note.isEmpty {
            line += " — \"\(note)\""
        }
        return line
    }
}

enum CoachReflectionPatternConfidence: String, Codable, Equatable {
    case forming
    case repeated

    var contextLabel: String {
        switch self {
        case .forming:
            return "forming pattern"
        case .repeated:
            return "repeated pattern"
        }
    }
}

/// A bounded read over the user's recent post-rep reflections. This is not a
/// psychological label; it is a repeated self-report pattern the coach should
/// use as a hypothesis to explore.
struct CoachReflectionPattern: Codable, Equatable {
    static let defaultWindowSize = 6
    private static let minimumSampleSize = 3
    private static let minimumDominantCount = 2
    private static let dominanceRatio = 0.5

    var dominantFeeling: ReflectionFeeling
    var dominantCount: Int
    var sampleSize: Int
    var windowSize: Int
    var firstSeenAt: Date
    var latestSeenAt: Date
    var confidence: CoachReflectionPatternConfidence

    static func build(
        from reflections: [SessionReflection],
        windowSize: Int = defaultWindowSize
    ) -> CoachReflectionPattern? {
        let window = reflections
            .sorted { $0.recordedAt > $1.recordedAt }
            .prefix(max(1, windowSize))
        guard window.count >= minimumSampleSize else { return nil }

        let grouped = Dictionary(grouping: window, by: \.feeling)
        let ranked = grouped.map { (feeling, items) in
            (
                feeling: feeling,
                items: items,
                count: items.count,
                latest: items.map(\.recordedAt).max() ?? .distantPast
            )
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.latest > rhs.latest
        }

        guard let dominant = ranked.first,
              dominant.count >= minimumDominantCount,
              Double(dominant.count) / Double(window.count) >= dominanceRatio,
              let firstSeen = dominant.items.map(\.recordedAt).min(),
              let latestSeen = dominant.items.map(\.recordedAt).max() else {
            return nil
        }

        let confidence: CoachReflectionPatternConfidence = dominant.count >= 3 && window.count >= 4
            ? .repeated
            : .forming

        return CoachReflectionPattern(
            dominantFeeling: dominant.feeling,
            dominantCount: dominant.count,
            sampleSize: window.count,
            windowSize: windowSize,
            firstSeenAt: firstSeen,
            latestSeenAt: latestSeen,
            confidence: confidence
        )
    }

    var reportedLine: String {
        "Across \(dominantCount) of the last \(sampleSize) reflections, the user reported \(dominantFeeling.coachClause)."
    }

    var contextInstruction: String {
        switch dominantFeeling {
        case .strong:
            return "Ask what conditions made control possible, then reuse those conditions deliberately."
        case .nervous:
            return "Treat this as a self-reported nerves pattern; ask where pressure enters before increasing difficulty."
        case .heldBack:
            return "Treat this as a self-reported avoidance hypothesis; ask what they avoided saying before prescribing firmer delivery."
        case .notLikeMe:
            return "Treat this as an authenticity calibration issue; ask what would sound more like them before coaching more polish."
        }
    }

    var interventionReviewQuestion: String {
        switch dominantFeeling {
        case .strong:
            return "check what made those stronger reps possible and whether the intervention should reuse those conditions"
        case .nervous:
            return "check whether the repeated nerves are easing, unchanged, or worse"
        case .heldBack:
            return "check whether they are still holding back or avoiding the direct version"
        case .notLikeMe:
            return "check whether the work is helping them sound more like themselves, not just more polished"
        }
    }
}

/// The user's one-tap verdict on whether the coach's current working
/// hypothesis matches what they actually see in themselves. Surfaced by
/// `AskNoumView`'s hypothesis acknowledgement chip row immediately after
/// the coach reply to an `interventionReviewOpener` lands. Three explicit
/// branches so the coach has a clean "user confirmed / user is uncertain /
/// user pushed back" signal rather than inferring agreement from silence.
///
/// Vision alignment: closes a long-standing coach-parity gap. Per
/// `docs/VISION.md`, "The coaching case is incomplete … one explicit,
/// revisable case formulation with hypothesis, intervention, success
/// criterion, review cadence, and reason for changing course." Recording
/// the user's confirmation / rejection of the hypothesis is the missing
/// "reason for changing course" signal — the durable coach memory now
/// carries the user's own verdict on the hypothesis, not just the
/// coach's read of the evidence.
enum CoachHypothesisConfidence: String, Codable, Equatable {
    case confirmed
    case uncertain
    case rejected

    /// Coach-context phrase the AI receives in the user-context block. Keep
    /// short — these lines compete for the model's attention with the rest
    /// of the case formulation. Brand-voice rules: no exclamation, no
    /// "Let's", no hype.
    var contextLabel: String {
        switch self {
        case .confirmed:
            return "user confirmed the working hypothesis matches what they see"
        case .uncertain:
            return "user is uncertain whether the working hypothesis matches"
        case .rejected:
            return "user said the working hypothesis does not match — adapt the read"
        }
    }

    /// Instruction the coach should follow on the next reply. Pinned per
    /// branch so the model has a concrete next move rather than treating
    /// the ack as background context.
    var nextMoveInstruction: String {
        switch self {
        case .confirmed:
            return "Reinforce the working hypothesis and tie the next prescription back to it."
        case .uncertain:
            return "Ask one focused question that would resolve the uncertainty before the next prescription."
        case .rejected:
            return "Treat the working hypothesis as falsified by user report; open the next reply by acknowledging the adapt and proposing a revised read."
        }
    }

    /// Round-32 verdict phrase for the rebuild-specific context line. The
    /// generic `contextLabel` carries the same three branches as a flat
    /// statement of fact; this phrase reads as a labelled outcome on a
    /// rebuild ("confirmed verdict", "uncertain verdict", "second
    /// pushback"). Used in `CoachContextBuilder.rebuildVerdictContextLines`
    /// so the model sees the rebuild-and-verdict pair as a single named
    /// event, not as a generic ack happening to follow a rebuild.
    var rebuildVerdictLabel: String {
        switch self {
        case .confirmed:
            return "confirmed verdict"
        case .uncertain:
            return "uncertain verdict"
        case .rejected:
            return "second pushback"
        }
    }

    /// Round-32 coach-move instruction tied specifically to a verdict on a
    /// rebuilt hypothesis. Distinct from `nextMoveInstruction` (which is
    /// hypothesis-agnostic) because the rebuild context demands the coach
    /// name the second cycle: a `.confirmed` ack reinforces the *rebuild*;
    /// a `.rejected` ack is the user pushing back twice, not once.
    /// Brand-voice compliant — no exclamation, no "Let's", no hype.
    var rebuildVerdictInstruction: String {
        switch self {
        case .confirmed:
            return "The user accepted the rebuilt read. Treat the rebuild as the operating hypothesis; reinforce it and tie the next prescription to it. Do not re-litigate the original read."
        case .uncertain:
            return "The user is still settling into the rebuilt read. Ask one focused question that would resolve the uncertainty before reinforcing the rebuild further; do not strengthen the rebuild ahead of the user."
        case .rejected:
            return "The user pushed back on the rebuilt read too. Acknowledge the second adapt explicitly; do not retry the same rebuilt hypothesis; propose a third angle and name what evidence would resolve which read fits."
        }
    }
}

/// A bounded snapshot of the user's most-recent hypothesis acknowledgement
/// held inside durable coach memory. The hypothesis snapshot is carried
/// alongside the confidence so a later coach rebuild (which may have
/// rewritten `workingHypothesis` to a fresh phrasing) can still tell
/// whether the ack still applies to today's read.
struct CoachHypothesisAcknowledgement: Codable, Equatable {
    var confidence: CoachHypothesisConfidence
    /// The hypothesis text the user was acknowledging when they tapped.
    /// Captured at acknowledgement time so a memory rebuild that
    /// produces a different `workingHypothesis` phrasing can detect the
    /// drift and treat the ack as stale.
    var hypothesisSnapshot: String
    var acknowledgedAt: Date

    /// Is this acknowledgement still about the same hypothesis the coach
    /// memory is currently carrying? Pure function — used by the context
    /// builder and by AskNoumView to decide whether to render the ack
    /// chip row again (a stale ack should re-prompt).
    func appliesTo(currentHypothesis: String?) -> Bool {
        guard let current = currentHypothesis?.trimmingCharacters(in: .whitespacesAndNewlines),
              !current.isEmpty else { return false }
        let snapshot = hypothesisSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        return snapshot == current
    }
}

/// The bounded intervention cycle carried in durable coach memory.
/// RecommendationLearningStore remains the raw evidence owner; this record
/// holds the coach's current prescription and review state for continuity.
/// The case-spine fields (`successCriterion`, `criterionStatus`,
/// `reviewDueAt`) are optional with nil defaults so memories persisted before
/// the case file decode unchanged.
struct CoachIntervention: Codable, Equatable {
    var title: String
    var focus: String?
    var target: String?
    var mode: PracticeMode
    var prescribedAt: Date?
    var lastObservedAt: Date?
    var followedRepCount: Int
    var minimumFollowedRepsForReview: Int
    var reviewStatus: CoachInterventionReviewStatus
    var reviewBasis: String
    var successCriterion: CoachSuccessCriterion? = nil
    var criterionStatus: CoachCriterionStatus? = nil
    var reviewDueAt: Date? = nil

    /// Has the user accumulated enough followed reps AND has the
    /// review-due date passed? Both conditions must hold so the
    /// post-rep summary never surfaces a review prompt before the
    /// case has enough observed evidence for the coach to review
    /// honestly — and never holds the prompt past the agreed-upon
    /// cadence once the threshold is met.
    ///
    /// Pure function of the intervention's own fields + `now`, so the
    /// predicate can be locked by tests without standing up a real
    /// `CoachMemoryStore`. Used by `SummaryView` to decide whether to
    /// render `InterventionReviewPromptCard`.
    func isReviewDue(at now: Date) -> Bool {
        guard followedRepCount >= minimumFollowedRepsForReview else { return false }
        guard let due = reviewDueAt else { return false }
        return now >= due
    }
}

enum CoachCaseNextMove: String, Codable, Equatable {
    case confirmHypothesis
    case reformulateHypothesis
    case followIntervention
    case reviewIntervention
    case adaptIntervention
    case reviewTransfer
    case exploreSubjectivePattern
    case gatherEvidence

    var contextLabel: String {
        switch self {
        case .confirmHypothesis:
            return "Confirm the read"
        case .reformulateHypothesis:
            return "Reformulate the read"
        case .followIntervention:
            return "Run the intervention"
        case .reviewIntervention:
            return "Review the intervention"
        case .adaptIntervention:
            return "Adapt the intervention"
        case .reviewTransfer:
            return "Review transfer"
        case .exploreSubjectivePattern:
            return "Explore subjective pattern"
        case .gatherEvidence:
            return "Gather evidence"
        }
    }

    var contextInstruction: String {
        switch self {
        case .confirmHypothesis:
            return "Ask whether the current hypothesis matches the user's experience before strengthening it."
        case .reformulateHypothesis:
            return "Treat the current hypothesis as challenged by the user; propose a revised read and name what evidence would distinguish it."
        case .followIntervention:
            return "Keep the current prescription active and collect followed reps against the success measure."
        case .reviewIntervention:
            return "Review whether the current prescription should continue, adapt, or be replaced."
        case .adaptIntervention:
            return "Do not repeat the same intervention unchanged; diagnose what broke and prescribe a narrower variation."
        case .reviewTransfer:
            return "Ask what transferred into the real moment and what broke down before changing course."
        case .exploreSubjectivePattern:
            return "Ask the user to confirm, refine, or reject the repeated self-report pattern."
        case .gatherEvidence:
            return "Collect another rep before strengthening the case."
        }
    }
}

/// The most recent opt-in visual delivery read from AI video analysis.
///
/// This is deliberately small: no frames, no raw images, no trait language.
/// It carries only the normalized ratings/notes the user explicitly requested
/// from the summary screen, so the coach can remember "what the video read
/// showed" without pretending it diagnosed the person.
struct VisualDeliveryRead: Codable, Equatable {
    var recordedAt: Date
    var sessionID: UUID?
    var posture: FeedbackRating
    var eyeContact: FeedbackRating
    var gestureUse: FeedbackRating
    var presenceDelivery: FeedbackRating
    var summary: String
    var primaryImprovement: String?

    static func make(
        from result: VideoAnalysisResult,
        sessionID: UUID?,
        recordedAt: Date = Date()
    ) -> VisualDeliveryRead? {
        guard let normalized = VideoAnalysisContract.normalized(result) else { return nil }
        return VisualDeliveryRead(
            recordedAt: recordedAt,
            sessionID: sessionID,
            posture: normalized.posture,
            eyeContact: normalized.eyeContact,
            gestureUse: normalized.gestureUse,
            presenceDelivery: normalized.presenceDelivery,
            summary: normalized.overallNote,
            primaryImprovement: primaryImprovement(from: normalized)
        )
    }

    var coachContextLine: String {
        let improvement = primaryImprovement.map { " Next watch point: \($0)." } ?? ""
        return "User-initiated video read: posture \(posture.rawValue.lowercased()), eye contact \(eyeContact.rawValue.lowercased()), gestures \(gestureUse.rawValue.lowercased()), presence \(presenceDelivery.rawValue.lowercased()). \(summary)\(improvement) Treat as opt-in visual evidence from one recording, not a trait or diagnosis."
    }

    private static func primaryImprovement(from result: VideoAnalysisResult) -> String? {
        let candidates: [(FeedbackRating, String, String)] = [
            (result.eyeContact, "Eye contact", result.eyeContactNote),
            (result.presenceDelivery, "Presence", result.presenceNote),
            (result.gestureUse, "Gestures", result.gestureNote),
            (result.posture, "Posture", result.postureNote),
            (result.energyConfidence, "Energy", result.energyNote),
            (result.facialExpression, "Expression", result.facialExpressionNote),
        ]
        guard let candidate = candidates.first(where: { $0.0 != .good }) else { return nil }
        return "\(candidate.1): \(candidate.2)"
    }
}

struct CoachMemory: Codable, Equatable {
    var updatedAt: Date
    var lastSessionID: UUID?
    var evidenceCount: Int
    var evidenceConfidence: BaselineConfidence
    var voice: SpeakingStyleGoal?
    var statedGoalSummary: String?
    var currentLever: SkillArea?
    var currentLeverConfidence: TrendConfidence?
    var currentLeverBasis: String?
    var previousLever: SkillArea?
    var focusShiftedAt: Date?
    var goalFit: CoachMemoryGoalFit
    /// Stated-vs-measured read: how the current lever lines up with the
    /// challenge the user named at onboarding. Defaulted to `.unknown` and
    /// decoded with `decodeIfPresent` so memories persisted before this
    /// field decode cleanly. Consumed by `CoachContextBuilder` to surface a
    /// single divergence question rather than silently switching focus.
    var statedChallengeConcordance: StatedChallengeConcordance
    /// The SkillArea the user's stated challenge maps to, carried only when
    /// the concordance read is `.divergent` so the divergence-question copy
    /// can name what the user actually asked for. `nil` otherwise (agree /
    /// deferred / unknown need no second area to phrase a question).
    var statedChallengeArea: SkillArea?
    var strengths: [String]
    var blockers: [String]
    var lastIntentLabel: String?
    var planWeekIndex: Int?
    var planFocus: SkillArea?
    var planMode: PracticeMode?
    var workingHypothesis: String?
    var activeIntervention: CoachIntervention?

    // When the coach started watching the CURRENT read — the durable age
    // anchor behind "watching this across 9 reps over 3 weeks." Carried
    // forward across rebuilds while the lever (the case the hypothesis is
    // about) stays the same, even though the hypothesis PHRASING is
    // rewritten every rebuild; reset when the lever shifts (a new case is
    // a new watch — mirrors `focusShiftedAt`). Optional for backward
    // compat: memories persisted before this field decode to nil, and the
    // engine then claims age only from `previous.updatedAt` (never invents
    // a longer watch than it can prove).
    var hypothesisWatchStartedAt: Date?

    // The compact operating case a human coach would keep in their notes:
    // hypothesis, active intervention, evidence threshold, subjective pattern,
    // transfer read, and the next coaching move. Optional for backward compat.
    var caseFile: CoachCaseFile?

    /// The user's most-recent one-tap verdict on the working hypothesis,
    /// captured from the `AskNoumView` hypothesis acknowledgement chip
    /// row that surfaces after the coach's reply to an
    /// `interventionReviewOpener`. Optional for backward compat: memories
    /// persisted before round 26 decode without this key.
    var hypothesisAcknowledgement: CoachHypothesisAcknowledgement?

    // Adaptation history — the bounded record of explained course-changes
    // (the "reason for changing course" the case formulation needs).
    // Optional for backward compat; memories persisted before the case file
    // decode without this key.
    var adaptationLog: [CoachCourseChange]?

    // The user's most-recent self-reported reflection clause — the inner
    // experience telemetry can't see ("nerves affected their delivery").
    // Always the user's own report, never an inference. Optional for
    // backward compat.
    var lastReflectionSummary: String?

    // Structured version of the same self-report, carrying the coach's next
    // review move. Optional for backward compatibility; older memories only
    // have `lastReflectionSummary`.
    var lastReflectionReview: CoachReflectionReview?

    // Repeated self-report pattern across recent reflection history. Optional
    // and bounded; absence means no honest pattern yet, not "no issue."
    var reflectionPattern: CoachReflectionPattern?

    // The latest off-app outcome folded into this case file. Optional for
    // backward compatibility and kept separate from intervention verdicts:
    // reported transfer guides review but does not prove causation.
    var lastTransferReview: CoachTransferReview?

    // Momentum — cross-session trajectory. Optional for backward compat
    // (existing persisted memories decode without these keys).
    var consecutiveCleanReps: Int?
    var fillerTrendDirection: TrendDirection?
    var weeklyRepCount: Int?
    var isLatestSessionPersonalBest: Bool?

    // The single fused, DURABLE delivery read (#3) — how the recent rep SET
    // read on delivery (clear / timid / still forming), fused from the
    // existing per-rep reads by `DerivedReadsTrendEngine.fusedDeliveryRead`.
    // A HYPOTHESIS about the reps, never a trait or diagnosis. `CoachMemory`
    // remains the source of truth because the 5 post-hoc mutators rebuild
    // `caseFile` WITHOUT session data; `CoachCaseFile.build(from:)` copies this
    // durable read from memory into the case spine so the projection survives
    // those rebuilds. `build` computes it from sessions and carries the
    // previous read forward across thin windows (mirrors `lastTransferReview`).
    // Optional for backward compat — memories persisted before this field
    // decode to nil via `decodeIfPresent`.
    var coachDeliveryRead: CoachDeliveryRead?

    // F3 — the user-facing delivery profile (recurring pattern / what improved
    // / what breaks under pressure / next delivery target). Composed by
    // `DeliveryProfile.build` from the SAME engines the coach context uses;
    // persisted here ALONGSIDE `coachDeliveryRead` (same rationale: the 5
    // post-hoc caseFile mutators copy `CoachMemory` by value and never touch
    // this field, so it survives them) and carried forward across thin windows.
    // Optional for backward compat — memories persisted before this field
    // decode to nil via `decodeIfPresent`.
    var deliveryProfile: DeliveryProfile?

    // The most-recent opt-in video/presence read. Persisted beside the other
    // delivery reads so post-hoc caseFile mutators keep it, and framed in
    // context as one user-initiated recording rather than a durable trait.
    var visualDeliveryRead: VisualDeliveryRead?

    // Explicit memberwise init — required because the custom
    // `init(from:)` below suppresses the synthesized one.
    init(
        updatedAt: Date,
        lastSessionID: UUID? = nil,
        evidenceCount: Int,
        evidenceConfidence: BaselineConfidence,
        voice: SpeakingStyleGoal? = nil,
        statedGoalSummary: String? = nil,
        currentLever: SkillArea? = nil,
        currentLeverConfidence: TrendConfidence? = nil,
        currentLeverBasis: String? = nil,
        previousLever: SkillArea? = nil,
        focusShiftedAt: Date? = nil,
        goalFit: CoachMemoryGoalFit,
        statedChallengeConcordance: StatedChallengeConcordance = .unknown,
        statedChallengeArea: SkillArea? = nil,
        strengths: [String],
        blockers: [String],
        lastIntentLabel: String? = nil,
        planWeekIndex: Int? = nil,
        planFocus: SkillArea? = nil,
        planMode: PracticeMode? = nil,
        workingHypothesis: String? = nil,
        activeIntervention: CoachIntervention? = nil,
        hypothesisWatchStartedAt: Date? = nil,
        caseFile: CoachCaseFile? = nil,
        hypothesisAcknowledgement: CoachHypothesisAcknowledgement? = nil,
        adaptationLog: [CoachCourseChange]? = nil,
        lastReflectionSummary: String? = nil,
        lastReflectionReview: CoachReflectionReview? = nil,
        reflectionPattern: CoachReflectionPattern? = nil,
        lastTransferReview: CoachTransferReview? = nil,
        consecutiveCleanReps: Int? = nil,
        fillerTrendDirection: TrendDirection? = nil,
        weeklyRepCount: Int? = nil,
        isLatestSessionPersonalBest: Bool? = nil,
        coachDeliveryRead: CoachDeliveryRead? = nil,
        deliveryProfile: DeliveryProfile? = nil,
        visualDeliveryRead: VisualDeliveryRead? = nil
    ) {
        self.updatedAt = updatedAt
        self.lastSessionID = lastSessionID
        self.evidenceCount = evidenceCount
        self.evidenceConfidence = evidenceConfidence
        self.voice = voice
        self.statedGoalSummary = statedGoalSummary
        self.currentLever = currentLever
        self.currentLeverConfidence = currentLeverConfidence
        self.currentLeverBasis = currentLeverBasis
        self.previousLever = previousLever
        self.focusShiftedAt = focusShiftedAt
        self.goalFit = goalFit
        self.statedChallengeConcordance = statedChallengeConcordance
        self.statedChallengeArea = statedChallengeArea
        self.strengths = strengths
        self.blockers = blockers
        self.lastIntentLabel = lastIntentLabel
        self.planWeekIndex = planWeekIndex
        self.planFocus = planFocus
        self.planMode = planMode
        self.workingHypothesis = workingHypothesis
        self.activeIntervention = activeIntervention
        self.hypothesisWatchStartedAt = hypothesisWatchStartedAt
        self.caseFile = caseFile
        self.hypothesisAcknowledgement = hypothesisAcknowledgement
        self.adaptationLog = adaptationLog
        self.lastReflectionSummary = lastReflectionSummary
        self.lastReflectionReview = lastReflectionReview
        self.reflectionPattern = reflectionPattern
        self.lastTransferReview = lastTransferReview
        self.consecutiveCleanReps = consecutiveCleanReps
        self.fillerTrendDirection = fillerTrendDirection
        self.weeklyRepCount = weeklyRepCount
        self.isLatestSessionPersonalBest = isLatestSessionPersonalBest
        self.coachDeliveryRead = coachDeliveryRead
        self.deliveryProfile = deliveryProfile
        self.visualDeliveryRead = visualDeliveryRead
    }

    // Custom Decodable for backward compatibility — all momentum
    // fields use decodeIfPresent so existing persisted data decodes
    // without breaking.
    enum CodingKeys: String, CodingKey {
        case updatedAt, lastSessionID, evidenceCount, evidenceConfidence
        case voice, statedGoalSummary, currentLever, currentLeverConfidence
        case currentLeverBasis, previousLever, focusShiftedAt, goalFit
        case statedChallengeConcordance, statedChallengeArea
        case strengths, blockers, lastIntentLabel
        case planWeekIndex, planFocus, planMode
        case workingHypothesis, activeIntervention
        case hypothesisWatchStartedAt
        case caseFile
        case hypothesisAcknowledgement
        case adaptationLog
        case lastReflectionSummary, lastReflectionReview, reflectionPattern
        case lastTransferReview
        case consecutiveCleanReps, fillerTrendDirection, weeklyRepCount
        case isLatestSessionPersonalBest
        case coachDeliveryRead
        case deliveryProfile
        case visualDeliveryRead
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        lastSessionID = try c.decodeIfPresent(UUID.self, forKey: .lastSessionID)
        evidenceCount = try c.decode(Int.self, forKey: .evidenceCount)
        evidenceConfidence = try c.decode(BaselineConfidence.self, forKey: .evidenceConfidence)
        voice = try c.decodeIfPresent(SpeakingStyleGoal.self, forKey: .voice)
        statedGoalSummary = try c.decodeIfPresent(String.self, forKey: .statedGoalSummary)
        currentLever = try c.decodeIfPresent(SkillArea.self, forKey: .currentLever)
        currentLeverConfidence = try c.decodeIfPresent(TrendConfidence.self, forKey: .currentLeverConfidence)
        currentLeverBasis = try c.decodeIfPresent(String.self, forKey: .currentLeverBasis)
        previousLever = try c.decodeIfPresent(SkillArea.self, forKey: .previousLever)
        focusShiftedAt = try c.decodeIfPresent(Date.self, forKey: .focusShiftedAt)
        goalFit = try c.decode(CoachMemoryGoalFit.self, forKey: .goalFit)
        statedChallengeConcordance = try c.decodeIfPresent(StatedChallengeConcordance.self, forKey: .statedChallengeConcordance) ?? .unknown
        statedChallengeArea = try c.decodeIfPresent(SkillArea.self, forKey: .statedChallengeArea)
        strengths = try c.decode([String].self, forKey: .strengths)
        blockers = try c.decode([String].self, forKey: .blockers)
        lastIntentLabel = try c.decodeIfPresent(String.self, forKey: .lastIntentLabel)
        planWeekIndex = try c.decodeIfPresent(Int.self, forKey: .planWeekIndex)
        planFocus = try c.decodeIfPresent(SkillArea.self, forKey: .planFocus)
        planMode = try c.decodeIfPresent(PracticeMode.self, forKey: .planMode)
        workingHypothesis = try c.decodeIfPresent(String.self, forKey: .workingHypothesis)
        activeIntervention = try c.decodeIfPresent(CoachIntervention.self, forKey: .activeIntervention)
        hypothesisWatchStartedAt = try c.decodeIfPresent(Date.self, forKey: .hypothesisWatchStartedAt)
        caseFile = try c.decodeIfPresent(CoachCaseFile.self, forKey: .caseFile)
        hypothesisAcknowledgement = try c.decodeIfPresent(CoachHypothesisAcknowledgement.self, forKey: .hypothesisAcknowledgement)
        adaptationLog = try c.decodeIfPresent([CoachCourseChange].self, forKey: .adaptationLog)
        lastReflectionSummary = try c.decodeIfPresent(String.self, forKey: .lastReflectionSummary)
        lastReflectionReview = try c.decodeIfPresent(CoachReflectionReview.self, forKey: .lastReflectionReview)
        reflectionPattern = try c.decodeIfPresent(CoachReflectionPattern.self, forKey: .reflectionPattern)
        lastTransferReview = try c.decodeIfPresent(CoachTransferReview.self, forKey: .lastTransferReview)
        consecutiveCleanReps = try c.decodeIfPresent(Int.self, forKey: .consecutiveCleanReps)
        fillerTrendDirection = try c.decodeIfPresent(TrendDirection.self, forKey: .fillerTrendDirection)
        weeklyRepCount = try c.decodeIfPresent(Int.self, forKey: .weeklyRepCount)
        isLatestSessionPersonalBest = try c.decodeIfPresent(Bool.self, forKey: .isLatestSessionPersonalBest)
        coachDeliveryRead = try c.decodeIfPresent(CoachDeliveryRead.self, forKey: .coachDeliveryRead)
        deliveryProfile = try c.decodeIfPresent(DeliveryProfile.self, forKey: .deliveryProfile)
        visualDeliveryRead = try c.decodeIfPresent(VisualDeliveryRead.self, forKey: .visualDeliveryRead)
    }
}

/// The durable operating note for the coach. This deliberately composes
/// existing owners rather than owning raw history: `CoachMemory` remains the
/// per-account state, `RecommendationLearningStore` owns intervention
/// evidence, `SessionReflectionStore` owns reflection history, and
/// `BigMomentStore` owns transfer check-ins. The case file is the concise
/// strategy spine the AI coach can carry across chat, summaries, and plans.
struct CoachCaseFile: Codable, Equatable {
    var updatedAt: Date
    var hypothesis: String?
    var focus: SkillArea?
    var evidenceSummary: String
    var activeIntervention: String?
    var observableTarget: String?
    var successMeasure: String?
    var reviewDueAt: Date?
    var subjectivePattern: String?
    var transferRead: String?
    /// The single fused delivery read carried into the coach's durable case
    /// spine. Copied from `CoachMemory.coachDeliveryRead` rather than
    /// recomputed here so post-hoc case rebuilds preserve the characterized
    /// read without needing raw sessions. Optional for decode safety and nil
    /// below the delivery consistency floor.
    var deliveryRead: CoachDeliveryRead? = nil
    /// The most-recent opt-in video/presence read. Optional and explicitly
    /// framed as a user-initiated single-recording read in context.
    var visualDeliveryRead: VisualDeliveryRead? = nil
    /// The soonest upcoming real-world moment the user is preparing for, as a
    /// bounded one-line clause ("Preparing for: Q3 review (performance review),
    /// 5 days away."). Derived at the call site from `BigMomentStore` and
    /// threaded into `build` — the pure build never reads the store. Optional
    /// with a `nil` default so a `CoachCaseFile` blob persisted before this
    /// field decodes cleanly (synthesized Codable tolerates the missing key).
    var upcomingMomentLine: String? = nil
    var nextMove: CoachCaseNextMove
    var nextQuestion: String

    static func build(
        from memory: CoachMemory,
        now: Date,
        upcomingMomentLine: String? = nil
    ) -> CoachCaseFile? {
        let hypothesis = bounded(memory.workingHypothesis)
        let focus = memory.currentLever
        let activeIntervention = memory.activeIntervention.map(interventionSummary)
        let observableTarget = bounded(memory.activeIntervention?.target)
        let successMeasure = memory.activeIntervention.flatMap(successMeasureSummary)
        let reviewDueAt = memory.activeIntervention?.reviewDueAt
        let subjectivePattern = memory.reflectionPattern?.reportedLine
        let transferRead = memory.lastTransferReview?.reportedOutcomeLine
        let deliveryRead = memory.coachDeliveryRead
        let visualDeliveryRead = memory.visualDeliveryRead

        guard hypothesis != nil ||
                focus != nil ||
                activeIntervention != nil ||
                subjectivePattern != nil ||
                transferRead != nil ||
                deliveryRead?.tentativeLine != nil ||
                visualDeliveryRead != nil else {
            return nil
        }

        let move = nextMove(for: memory, now: now)
        return CoachCaseFile(
            updatedAt: now,
            hypothesis: hypothesis,
            focus: focus,
            evidenceSummary: evidenceSummary(for: memory, now: now),
            activeIntervention: activeIntervention,
            observableTarget: observableTarget,
            successMeasure: successMeasure,
            reviewDueAt: reviewDueAt,
            subjectivePattern: subjectivePattern,
            transferRead: transferRead,
            deliveryRead: deliveryRead,
            visualDeliveryRead: visualDeliveryRead,
            upcomingMomentLine: upcomingMomentLine,
            nextMove: move,
            nextQuestion: nextQuestion(for: move)
        )
    }

    private static func nextMove(for memory: CoachMemory, now: Date) -> CoachCaseNextMove {
        if let ack = memory.hypothesisAcknowledgement,
           ack.appliesTo(currentHypothesis: memory.workingHypothesis),
           ack.confidence == .rejected {
            return .reformulateHypothesis
        }

        if let intervention = memory.activeIntervention {
            switch intervention.reviewStatus {
            case .diagnoseBeforeRepeating, .adaptBeforeRepeating:
                return .adaptIntervention
            case .awaitingAttempt, .formingEvidence, .continueAndVerify:
                break
            }

            if intervention.isReviewDue(at: now) {
                return .reviewIntervention
            }

            if intervention.followedRepCount < intervention.minimumFollowedRepsForReview {
                return .followIntervention
            }
        }

        if let transfer = memory.lastTransferReview,
           transfer.nextAction != .exploreWhatTransferred {
            return .reviewTransfer
        }

        if memory.activeIntervention != nil {
            return .followIntervention
        }

        if memory.reflectionPattern != nil {
            return .exploreSubjectivePattern
        }

        if bounded(memory.workingHypothesis) != nil {
            return .confirmHypothesis
        }

        if memory.lastTransferReview != nil {
            return .reviewTransfer
        }

        return .gatherEvidence
    }

    private static func nextQuestion(for move: CoachCaseNextMove) -> String {
        switch move {
        case .confirmHypothesis:
            return "Does this working hypothesis match the user's lived experience?"
        case .reformulateHypothesis:
            return "What revised read fits the user's pushback, and what evidence would distinguish it?"
        case .followIntervention:
            return "What is the next followed rep that will test the success measure?"
        case .reviewIntervention:
            return "Should the current intervention continue, adapt, or be replaced?"
        case .adaptIntervention:
            return "What broke in the current intervention, and what narrower variation should replace it?"
        case .reviewTransfer:
            return "What transferred into the real moment, and what broke down?"
        case .exploreSubjectivePattern:
            return "Does this repeated self-report pattern fit, or should it be revised?"
        case .gatherEvidence:
            return "What one more rep would strengthen or weaken this read?"
        }
    }

    private static func evidenceSummary(for memory: CoachMemory, now: Date) -> String {
        let noun = memory.evidenceCount == 1 ? "signal" : "signals"
        var summary = "\(memory.evidenceConfidence.label) read across \(memory.evidenceCount) \(noun)"
        // Evidence AGE — how long the current read has been watched. Only
        // claimed when a hypothesis exists and its watch anchor proves a
        // span (legacy memories without the anchor stay depth-only).
        if memory.workingHypothesis != nil,
           let span = watchSpanPhrase(from: memory.hypothesisWatchStartedAt, to: now) {
            summary += ", watched \(span)"
        }
        if let basis = bounded(memory.currentLeverBasis) {
            summary += "; basis: \(basis)"
        }
        return summary
    }

    // MARK: - Evidence age + depth (the felt-durability clause)

    /// Coarse, honest phrasing of how long the current read has been
    /// watched. Nil for no anchor, a future anchor, or a same-day watch —
    /// the line never claims a span it can't prove. Pure function; calendar
    /// is injectable so tests can pin phrasing without DST flakiness.
    static func watchSpanPhrase(
        from start: Date?,
        to now: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard let start, start <= now else { return nil }
        let days = calendar.dateComponents([.day], from: start, to: now).day ?? 0
        switch days {
        case ..<1: return nil
        case 1: return "since yesterday"
        case 2...6: return "over the past \(days) days"
        case 7...13: return "over the past week"
        case 14...59: return "over \(days / 7) weeks"
        default: return "over \(days / 30) months"
        }
    }

    /// The short depth+age clause — "9 reps over 3 weeks" — shared by the
    /// Profile coach read and the post-rep note so every surface ages the
    /// same watch identically. "Reps" is honest here: `evidenceCount` is
    /// derived exclusively from session counts/trend windows.
    static func evidenceDepthClause(
        evidenceCount: Int,
        watchingSince: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard evidenceCount > 0 else { return nil }
        let noun = evidenceCount == 1 ? "rep" : "reps"
        guard let span = watchSpanPhrase(from: watchingSince, to: now, calendar: calendar) else {
            return "\(evidenceCount) \(noun)"
        }
        return "\(evidenceCount) \(noun) \(span)"
    }

    /// The full user-facing evidence line behind the working hypothesis.
    /// Assured ("Watching this across …") only at or above the `.moderate`
    /// evidence floor — the SAME floor at which `workingHypothesis` shifts
    /// from "may be" to "appears to be" — and tentative below it, so weak
    /// evidence always reads as a forming hypothesis, never a verdict.
    static func evidenceDepthLine(
        evidenceCount: Int,
        confidence: BaselineConfidence,
        watchingSince: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard let clause = evidenceDepthClause(
            evidenceCount: evidenceCount,
            watchingSince: watchingSince,
            now: now,
            calendar: calendar
        ) else { return nil }
        if confidence >= .moderate {
            let noun = evidenceCount == 1 ? "rep" : "reps"
            return "Seen across \(evidenceCount) recent \(noun)."
        }
        let hasSpan = watchSpanPhrase(from: watchingSince, to: now, calendar: calendar) != nil
        return hasSpan
            ? "Early read — \(clause); still forming."
            : "Early read — \(clause) so far; still forming."
    }

    private static func interventionSummary(_ intervention: CoachIntervention) -> String {
        let purpose = bounded(intervention.focus) ?? bounded(intervention.title) ?? intervention.mode.displayLabel
        return "\(intervention.mode.displayLabel) for \(purpose)"
    }

    private static func successMeasureSummary(_ intervention: CoachIntervention) -> String? {
        guard let criterion = intervention.successCriterion else { return nil }
        var summary = criterion.summary
        if let status = intervention.criterionStatus {
            summary += " — \(status.contextLabel)"
        }
        return summary
    }

    private static func bounded(_ value: String?, maximumLength: Int = 180) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maximumLength))
    }

    /// Window (in days) within which an upcoming moment is "preparing for"
    /// relevant to the durable case. Mirrors the per-turn `BIG MOMENT` gate in
    /// `CoachContextBuilder` (0...60 days) so the case file and the per-turn
    /// context agree on what counts as imminent.
    static let upcomingMomentHorizonDays = 60

    /// Derives the bounded "Preparing for:" line for the durable case file from
    /// the soonest upcoming moment. Returns nil for no moment, an undated
    /// moment, a past moment, or one beyond the horizon — so the case never
    /// claims preparation for something that isn't actually upcoming. Pure
    /// function of the passed `moment` (the store is read at the call site, not
    /// here) so it is unit-testable and the pure `build` stays store-free. Copy
    /// mirrors `CoachContextBuilder`'s per-turn `BIG MOMENT` line for a single
    /// coherent read across surfaces.
    static func upcomingMomentLine(for moment: BigMoment?) -> String? {
        guard let moment,
              let days = BigMomentStore.daysUntil(moment),
              days >= 0,
              days <= upcomingMomentHorizonDays else { return nil }
        let title = bounded(moment.title) ?? moment.category.title
        return "Preparing for: \(title) (\(moment.category.displayName)), \(days) day\(days == 1 ? "" : "s") away."
    }

    // MARK: - Call-landing anchor (the standing plan, surfaced on open)

    /// The durable "pick up where we left off" line for the live-call landing.
    /// A human coach opens by naming the plan you both agreed to last time;
    /// Noum prescribes a next move (`activeIntervention`) and persists it in
    /// `CoachMemory`, but until now never anchored it the moment the call
    /// opened — the eval's Rank-2 gap ("the next prescribed move … never
    /// anchored durably"). This names the standing prescription as a calm
    /// continuity line so the call lands on the plan, not a blank orb.
    ///
    /// Deliberately distinct from `hypothesis` — that is the coach's *read*,
    /// surfaced in the *spoken* reply at the trust moment (Rank 1). This is the
    /// *plan* (the prescribed intervention + its observable target). The two
    /// split cleanly: the landing carries continuity, the spoken open carries
    /// the read.
    ///
    /// Returns `nil` when there is no standing intervention, so a true cold
    /// start (no prescription yet) shows no anchor and nothing is fabricated —
    /// the earned read / last-rep line / blank orb still own that case. The
    /// phrasing tracks `nextMove` so a review-due or adapt case reads as the
    /// real current move, never a stale "keep going".
    var callLandingAnchor: String? {
        CoachCaseFile.callLandingAnchor(
            activeIntervention: activeIntervention,
            observableTarget: observableTarget,
            nextMove: nextMove
        )
    }

    /// Pure builder behind `callLandingAnchor`, lifted out so the continuity
    /// phrasing can be unit-tested without standing up a `CoachMemory`. Brand
    /// voice: measured, no exclamation, no "Let's", no hype. Returns `nil`
    /// without a standing intervention.
    static func callLandingAnchor(
        activeIntervention: String?,
        observableTarget: String?,
        nextMove: CoachCaseNextMove
    ) -> String? {
        guard let plan = bounded(activeIntervention) else { return nil }
        let target = bounded(observableTarget)
        switch nextMove {
        case .reviewIntervention:
            // Enough followed reps have landed and the review window is due —
            // the anchor names a review, not a fresh start.
            return target.map { "Time to review this: \(plan). Target was \($0)." }
                ?? "Time to review this: \(plan)."
        case .adaptIntervention:
            // The last attempt needs adapting before repeating it unchanged.
            return "Picking back up — last time this needed adapting: \(plan)."
        default:
            // A standing, still-active plan: the common continuity case.
            return target.map { "Picking up where we left off: \(plan). Target: \($0)." }
                ?? "Picking up where we left off: \(plan)."
        }
    }
}

enum CoachMemoryEngine {
    static func build(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        sessions: [PracticeSession],
        trends: [SkillTrend],
        forwardPlan: ForwardPlan?,
        previous: CoachMemory?,
        lastSessionID: UUID?,
        pendingIntervention: RecommendationExposure? = nil,
        recommendationOutcomes: [RecommendationOutcome] = [],
        latestReflection: SessionReflection? = nil,
        reflectionHistory: [SessionReflection] = [],
        latestTransferReport: BigMomentOutcomeReport? = nil,
        upcomingMoment: BigMoment? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CoachMemory? {
        let cutoff = calendar.date(byAdding: .day, value: -30, to: now) ?? .distantPast
        let recentSessionCount = sessions.filter { $0.date >= cutoff }.count
        let maxTrendWindow = trends.map(\.windowSize).max() ?? 0
        let evidenceCount = [recentSessionCount, baseline.qualifyingSessionCount, maxTrendWindow].max() ?? 0
        guard evidenceCount > 0 else { return nil }

        let evidenceConfidence = max(
            baseline.overallConfidence,
            BaselineConfidence.from(sessionCount: evidenceCount)
        )

        let lever = selectLever(profile: profile, baseline: baseline, trends: trends)
        let voice = profile?.chosenStyleGoal
        let currentLever = lever?.area
        let goalFit: CoachMemoryGoalFit = {
            guard let currentLever else { return .noLever }
            guard let voice else { return .noVoice }
            return voice.aligns(with: currentLever) ? .aligned : .offGoal
        }()

        let newWorkingHypothesis = workingHypothesis(
            lever: lever,
            evidenceConfidence: evidenceConfidence
        )

        // Round-27 lift: surface a previously-recorded `.rejected`
        // acknowledgement as a documented `CoachCourseChange` whenever the
        // memory rebuild drops the ack (because the working hypothesis was
        // rewritten or the lever swapped). The bounded case-change record
        // then carries the user's own pushback as the reason for changing
        // course, instead of the engine silently inferring one. Pure
        // function lift — no UI changes.
        let droppedRejectedAck: CoachHypothesisAcknowledgement? = {
            guard let ack = previous?.hypothesisAcknowledgement,
                  ack.confidence == .rejected,
                  !ack.appliesTo(currentHypothesis: newWorkingHypothesis) else { return nil }
            return ack
        }()

        let previousLever: SkillArea?
        let focusShiftedAt: Date?
        var adaptationLog = previous?.adaptationLog ?? []
        let priorLeverShift: SkillArea? = {
            guard let prior = previous?.currentLever,
                  let currentLever,
                  prior != currentLever else { return nil }
            return prior
        }()

        if let prior = priorLeverShift {
            previousLever = prior
            focusShiftedAt = now
        } else {
            previousLever = previous?.previousLever
            focusShiftedAt = previous?.focusShiftedAt
        }

        if priorLeverShift != nil || droppedRejectedAck != nil {
            // Round-33: detect a second-cycle pushback. The signal is
            // ack-driven only (engine-only lever shifts are not "the user
            // pushing back again"); the prior bounded log's `.last` entry
            // must itself already document a user pushback. The tag is
            // embedded as a parenthetical inside the existing first-cycle
            // reason so `documentsUserPushback` still matches, AND
            // `documentsSecondCyclePushback` matches only when the
            // parenthetical is present.
            let priorEntryWasPushback = previous?.adaptationLog?.last?.documentsUserPushback == true
            let secondCycleTag = (droppedRejectedAck != nil && priorEntryWasPushback)
                ? " (\(CoachCourseChange.secondCyclePushbackMarker))"
                : ""
            let reason: String
            let evidenceBasis: String
            switch (priorLeverShift, droppedRejectedAck) {
            case let (prior?, ack?):
                reason = "Shifted focus from \(prior.displayName) to \(currentLever?.displayName ?? "the next read") after the user reported the prior hypothesis did not match what they saw\(secondCycleTag)."
                evidenceBasis = rejectedAckEvidenceBasis(ack: ack)
            case let (prior?, nil):
                reason = "Shifted focus from \(prior.displayName) to \(currentLever?.displayName ?? "the next read")."
                evidenceBasis = lever?.basis ?? "updated read across recent reps"
            case let (nil, ack?):
                reason = "User reported the prior hypothesis did not match what they saw\(secondCycleTag); revising the read."
                evidenceBasis = rejectedAckEvidenceBasis(ack: ack)
            case (nil, nil):
                reason = ""
                evidenceBasis = ""
            }
            adaptationLog.append(
                CoachCourseChange(
                    id: UUID(),
                    changedAt: now,
                    fromLever: previous?.currentLever,
                    toLever: currentLever,
                    reason: reason,
                    evidenceBasis: evidenceBasis
                )
            )
            adaptationLog = Array(adaptationLog.suffix(8))
        }

        let currentWeek = forwardPlan?.currentWeek(now: now, calendar: calendar)

        // Momentum signals — computed from the same session list the rest
        // of the memory reads. When sessions are thin (< 5), all momentum
        // fields stay nil — safe defaults.
        let baselineFillerRate: Double? = baseline.fillerRate.confidence == .insufficient
            ? nil : baseline.fillerRate.value
        let sorted = sessions.sorted { $0.date > $1.date }
        let momentumClean: Int? = sorted.count >= 5
            ? MomentumComputer.consecutiveCleanReps(sorted: sorted, baselineFillerRate: baselineFillerRate)
            : nil
        let momentumFillerTrend: TrendDirection? = sorted.count >= 6
            ? MomentumComputer.fillerTrend(sorted: sorted)
            : nil
        let momentumWeekly: Int? = MomentumComputer.weeklyRepCount(
            sorted: sorted, now: now, calendar: calendar
        )
        let momentumPB: Bool? = {
            guard let lastID = lastSessionID,
                  let current = sorted.first(where: { $0.id == lastID }) else { return nil }
            return MomentumComputer.isPersonalBest(current: current, allSessions: sorted)
        }()

        var memory = CoachMemory(
            updatedAt: now,
            lastSessionID: lastSessionID,
            evidenceCount: evidenceCount,
            evidenceConfidence: evidenceConfidence,
            voice: voice,
            statedGoalSummary: statedGoalSummary(from: profile),
            currentLever: currentLever,
            currentLeverConfidence: lever?.confidence,
            currentLeverBasis: lever?.basis,
            previousLever: previousLever,
            focusShiftedAt: focusShiftedAt,
            goalFit: goalFit,
            statedChallengeConcordance: lever?.concordance ?? .unknown,
            statedChallengeArea: lever?.statedChallengeArea,
            strengths: Array(baseline.topStrengths.prefix(3)),
            blockers: Array(baseline.persistentBlockers.prefix(3)),
            lastIntentLabel: latestIntentLabel(from: sessions),
            planWeekIndex: currentWeek?.weekIndex,
            planFocus: currentWeek?.focusSkillArea,
            planMode: currentWeek?.suggestedMode,
            workingHypothesis: newWorkingHypothesis,
            activeIntervention: activeIntervention(
                pending: pendingIntervention,
                outcomes: recommendationOutcomes,
                sessions: sessions,
                previous: previous?.activeIntervention,
                now: now,
                calendar: calendar
            )
        )
        memory.adaptationLog = adaptationLog.isEmpty ? nil : adaptationLog
        // Durable watch anchor — when the coach started watching the
        // CURRENT read. Resolved BEFORE `CoachCaseFile.build` below so the
        // case file's evidence summary can carry the watch age.
        memory.hypothesisWatchStartedAt = hypothesisWatchStart(
            hasHypothesis: newWorkingHypothesis != nil,
            currentLever: currentLever,
            previous: previous,
            now: now
        )
        // Carry the previous hypothesis acknowledgement forward only when
        // the freshly-built `workingHypothesis` matches the one the user
        // was acknowledging — same case-spine contract `successCriterion`
        // uses. A hypothesis rewrite means the ack is stale and must be
        // re-requested next time the user lands on a case-review reply.
        memory.hypothesisAcknowledgement = previous?.hypothesisAcknowledgement.flatMap { ack in
            ack.appliesTo(currentHypothesis: memory.workingHypothesis) ? ack : nil
        }
        memory.lastReflectionSummary = latestReflection?.coachClause
            ?? previous?.lastReflectionSummary
        memory.lastReflectionReview = latestReflection.map(CoachReflectionReview.init)
            ?? previous?.lastReflectionReview
        memory.reflectionPattern = reflectionHistory.isEmpty
            ? previous?.reflectionPattern
            : CoachReflectionPattern.build(from: reflectionHistory)
        memory.lastTransferReview = latestTransferReport.map { CoachTransferReview(report: $0) }
            ?? previous?.lastTransferReview
        memory.consecutiveCleanReps = momentumClean
        memory.fillerTrendDirection = momentumFillerTrend
        memory.weeklyRepCount = momentumWeekly
        memory.isLatestSessionPersonalBest = momentumPB
        // Fused delivery read (#3) — fuse the existing per-rep reads over the
        // recent window into one durable, hedged read of how the rep SET read
        // on delivery. Reuses the SAME per-session derive closures the
        // longitudinal trend block uses (hedging + pace relative to the user's
        // own baseline), so calibration is inherited and there is no absolute
        // loudness/pitch term. Carry a previously-CHARACTERISED read forward
        // across a thin or still-`.forming` window so a dip below the
        // consistency floor doesn't erase a durable read — exactly the
        // `lastTransferReview` carry-forward contract. A fresh `.forming`
        // (reps exist, no agreement) defers to the previous read; with no
        // previous read it stays nil rather than persisting `.forming`.
        let baselineHedgingPerMin = baseline.hedgingRate.value
        let baselinePace = baseline.pace.value
        let freshDeliveryRead = DerivedReadsTrendEngine.fusedDeliveryRead(
            sessions: sessions,
            snapshots: [],
            hedgingPerMinutePerSession: { _ in baselineHedgingPerMin },
            paceBaselinePerSession: { _ in baselinePace }
        )
        memory.coachDeliveryRead = freshDeliveryRead.flatMap { $0.isCharacterized ? $0 : nil }
            ?? previous?.coachDeliveryRead
        // F3 — the user-facing delivery profile, composed from the SAME inputs +
        // the just-resolved durable read. Carry a previous profile forward
        // across a thin window (mirrors the coachDeliveryRead carry-forward).
        memory.deliveryProfile = DeliveryProfile.build(
            sessions: sessions,
            snapshots: [],
            hedgingPerMinute: baselineHedgingPerMin,
            paceBaseline: baselinePace,
            deliveryRead: memory.coachDeliveryRead
        ) ?? previous?.deliveryProfile
        memory.visualDeliveryRead = previous?.visualDeliveryRead
        // Derive the upcoming-moment line HERE (not inside the pure build) so
        // the case file knows what the user is preparing for. Mirrors the
        // `lastTransferReview` wiring: the store is read at the SessionFinalizer
        // call site and the raw `BigMoment` is threaded in; `build` stays pure.
        let upcomingMomentLine = CoachCaseFile.upcomingMomentLine(for: upcomingMoment)
        memory.caseFile = CoachCaseFile.build(
            from: memory,
            now: now,
            upcomingMomentLine: upcomingMomentLine
        )
        return memory
    }

    private struct LeverSelection {
        let area: SkillArea
        let confidence: TrendConfidence?
        let basis: String
        /// Stated-vs-measured read of `area` against the user's onboarding
        /// `biggestChallenge`. Defaulted to `.unknown` so the existing
        /// return sites that don't compute it stay valid; `selectLever`
        /// fills it in before returning.
        var concordance: StatedChallengeConcordance = .unknown
        /// The SkillArea the stated challenge maps to. Only meaningful when
        /// `concordance == .divergent` (so the question copy can name what
        /// the user actually asked for); `nil` otherwise.
        var statedChallengeArea: SkillArea? = nil
    }

    private static func selectLever(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        trends: [SkillTrend]
    ) -> LeverSelection? {
        // Resolve the measured lever exactly as before — telemetry first,
        // then a persistent blocker, then the stated voice goal. The
        // stated-challenge reconciliation is applied AFTER, as a read on
        // the chosen lever, so it never changes WHICH lever is selected
        // (no silent focus switch — honesty invariant).
        var selection: LeverSelection?
        if let trend = strongestTrendLever(from: trends, profile: profile) {
            selection = LeverSelection(
                area: trend.skillArea,
                confidence: trend.confidence,
                basis: trendBasis(trend)
            )
        } else if let blocker = baseline.persistentBlockers.first,
                  let area = skillArea(fromBlocker: blocker) {
            selection = LeverSelection(
                area: area,
                confidence: nil,
                basis: "it keeps showing up in recent reps"
            )
        } else if let voice = profile?.chosenStyleGoal {
            selection = LeverSelection(
                area: voice.primaryAlignedSkillArea,
                confidence: nil,
                basis: "stated voice goal while evidence is still forming"
            )
        }

        guard var lever = selection else { return nil }
        let read = statedChallengeRead(
            measuredArea: lever.area,
            profile: profile,
            baseline: baseline
        )
        lever.concordance = read.concordance
        lever.statedChallengeArea = read.statedArea
        return lever
    }

    /// Pure stated-vs-measured concordance read. Composes the user's
    /// onboarding `biggestChallenge` into a SkillArea via the existing
    /// `SpeakingChallenge.recommendedPriority` ->
    /// `ForwardPlanService.skillAreaForAIWeek` mapping (the same canonical
    /// focus→skill map the AI forward plan uses, so the diagnosis and the
    /// plan never disagree about what a challenge "means"), then compares it
    /// to the measured lever:
    ///
    ///   • No stated challenge on file ............. `.unknown`
    ///   • Baseline below the evidence floor ....... `.deferred` (defer to
    ///                                               the stated challenge;
    ///                                               the measured read isn't
    ///                                               trustworthy enough yet)
    ///   • Above floor, same area .................. `.agree`
    ///   • Above floor, different area ............. `.divergent` (+ carry
    ///                                               the stated area so the
    ///                                               coach can name it)
    ///
    /// The evidence floor is `BaselineConfidence.isReliable` (>= .moderate,
    /// i.e. 5+ qualifying sessions) — the same "reliable enough to act on"
    /// bar the rest of the baseline layer uses. Below it we never challenge
    /// what the user said they wanted to work on.
    static func statedChallengeRead(
        measuredArea: SkillArea,
        profile: CoachingProfile?,
        baseline: CommunicationBaseline
    ) -> (concordance: StatedChallengeConcordance, statedArea: SkillArea?) {
        guard let challenge = profile?.biggestChallenge else {
            return (.unknown, nil)
        }
        let statedArea = ForwardPlanService.skillAreaForAIWeek(
            focus: challenge.recommendedPriority
        )
        guard baseline.overallConfidence.isReliable else {
            // Thin baseline — defer to the stated challenge, stay tentative.
            return (.deferred, nil)
        }
        if statedArea == measuredArea {
            return (.agree, nil)
        }
        return (.divergent, statedArea)
    }

    private static func strongestTrendLever(
        from trends: [SkillTrend],
        profile: CoachingProfile?
    ) -> SkillTrend? {
        let scored = trends.compactMap { trend -> (trend: SkillTrend, score: Int)? in
            let score = scoreTrend(trend, profile: profile)
            guard score > 0 else { return nil }
            return (trend, score)
        }
        return scored.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.trend.windowSize != rhs.trend.windowSize {
                return lhs.trend.windowSize > rhs.trend.windowSize
            }
            return lhs.trend.skillArea.displayName < rhs.trend.skillArea.displayName
        }.first?.trend
    }

    private static func scoreTrend(_ trend: SkillTrend, profile: CoachingProfile?) -> Int {
        guard trend.confidence != .low,
              trend.direction != .resolved,
              trend.currentLevel != .strong else { return 0 }

        var score: Int
        switch trend.direction {
        case .declining: score = 100
        case .newIssue: score = 90
        case .stable: score = trend.currentLevel <= .developing ? 75 : 25
        case .improving: score = trend.currentLevel <= .developing ? 60 : 20
        case .resolved: score = 0
        }

        switch trend.currentLevel {
        case .weak: score += 25
        case .developing: score += 15
        case .solid: score += 4
        case .strong: break
        }

        switch trend.confidence {
        case .high: score += 10
        case .medium: score += 4
        case .low: break
        }

        if profile?.chosenStyleGoal?.aligns(with: trend.skillArea) == true {
            score += 8
        }

        return score >= 50 ? score : 0
    }

    private static func trendBasis(_ trend: SkillTrend) -> String {
        let core: String
        switch trend.direction {
        case .declining:
            core = "declining trend"
        case .newIssue:
            core = "new issue in recent reps"
        case .stable:
            core = "stable at \(trend.currentLevel.rawValue)"
        case .improving:
            core = "improving but still \(trend.currentLevel.rawValue)"
        case .resolved:
            core = "recently resolved"
        }

        if let delta = trend.recentDelta?.trimmingCharacters(in: .whitespacesAndNewlines),
           !delta.isEmpty {
            return "\(core); \(delta)"
        }
        return core
    }

    /// Evidence-basis copy for a `CoachCourseChange` whose documented reason
    /// is a user-tapped rejection of the working hypothesis. Trims the
    /// snapshot down to a single readable clause so the case file's
    /// adaptation log carries the user's own pushback, not a paraphrase.
    private static func rejectedAckEvidenceBasis(
        ack: CoachHypothesisAcknowledgement
    ) -> String {
        let snapshot = ack.hypothesisSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !snapshot.isEmpty else {
            return "user-tapped rejection on the prior read"
        }
        let cap = 140
        let trimmed: String
        if snapshot.count > cap {
            let index = snapshot.index(snapshot.startIndex, offsetBy: cap)
            trimmed = "\(snapshot[..<index].trimmingCharacters(in: .whitespacesAndNewlines))…"
        } else {
            trimmed = snapshot
        }
        return "user-tapped rejection of: \"\(trimmed)\""
    }

    /// Resolves the durable watch anchor for the working hypothesis — the
    /// date the coach started watching the CURRENT case. Pure function,
    /// internal so tests can lock the carry-forward contract directly:
    ///
    ///   • No hypothesis → nil (no watch to age).
    ///   • Same lever as the previous memory → carry the previous anchor
    ///     (the hypothesis PHRASING is rewritten every rebuild; the case
    ///     it describes is the same watch).
    ///   • Same lever, legacy previous memory without an anchor but WITH a
    ///     hypothesis → claim age only from `previous.updatedAt` (the watch
    ///     provably existed at least since then — never invent more).
    ///   • Lever shifted, or first hypothesis → the watch starts now
    ///     (mirrors `focusShiftedAt`).
    static func hypothesisWatchStart(
        hasHypothesis: Bool,
        currentLever: SkillArea?,
        previous: CoachMemory?,
        now: Date
    ) -> Date? {
        guard hasHypothesis else { return nil }
        if let previous, let lever = currentLever, previous.currentLever == lever {
            if let carried = previous.hypothesisWatchStartedAt { return carried }
            if previous.workingHypothesis != nil { return previous.updatedAt }
        }
        return now
    }

    private static func workingHypothesis(
        lever: LeverSelection?,
        evidenceConfidence: BaselineConfidence
    ) -> String? {
        guard let lever else { return nil }
        switch evidenceConfidence {
        case .insufficient, .tentative:
            return "\(lever.area.displayName) may be the highest-leverage focus because \(lever.basis); verify over more reps."
        case .moderate, .established, .stable:
            return "\(lever.area.displayName) appears to be the highest-leverage focus because \(lever.basis); keep checking against future reps."
        }
    }

    private static let caseReviewCadenceDays = 3
    private static let caseEvaluationWindow = 2
    private static let criterionEvidenceSchemaVersion = 1

    private static func activeIntervention(
        pending: RecommendationExposure?,
        outcomes: [RecommendationOutcome],
        sessions: [PracticeSession],
        previous: CoachIntervention?,
        now: Date,
        calendar: Calendar
    ) -> CoachIntervention? {
        guard var intervention = baseIntervention(pending: pending, outcomes: outcomes) else {
            return nil
        }
        enrichWithCase(
            &intervention,
            outcomes: outcomes,
            sessions: sessions,
            previous: previous,
            now: now,
            calendar: calendar
        )
        return intervention
    }

    /// Attaches the case spine: a stable success criterion (carried forward
    /// when the prescription is unchanged, so "what good looks like" is defined
    /// once rather than re-derived each rebuild), the freshly-computed status
    /// from followed reps, and an explicit review date.
    private static func enrichWithCase(
        _ intervention: inout CoachIntervention,
        outcomes: [RecommendationOutcome],
        sessions: [PracticeSession],
        previous: CoachIntervention?,
        now: Date,
        calendar: Calendar
    ) {
        let isSamePrescription = previous?.mode == intervention.mode
            && boundedText(previous?.focus) == boundedText(intervention.focus)

        let criterion: CoachSuccessCriterion
        if isSamePrescription,
           let carried = previous?.successCriterion,
           carried.evidenceSchemaVersion == criterionEvidenceSchemaVersion {
            criterion = carried
        } else {
            criterion = buildSuccessCriterion(
                mode: intervention.mode,
                focus: intervention.focus,
                title: intervention.title,
                outcomes: outcomes,
                sessions: sessions,
                now: now
            )
        }
        intervention.successCriterion = criterion

        let values = followedRepValues(
            metric: criterion.metric,
            mode: intervention.mode,
            focus: intervention.focus,
            title: intervention.title,
            prescribedAt: intervention.prescribedAt,
            outcomes: outcomes,
            sessions: sessions,
            now: now
        )
        intervention.criterionStatus = criterion.status(forFollowedValues: values)

        if isSamePrescription, let carriedDue = previous?.reviewDueAt {
            intervention.reviewDueAt = carriedDue
        } else if let anchor = intervention.prescribedAt ?? intervention.lastObservedAt {
            intervention.reviewDueAt = calendar.date(byAdding: .day, value: caseReviewCadenceDays, to: anchor)
        }
    }

    private static func caseMetric(
        mode: PracticeMode,
        focus: String?,
        title: String
    ) -> (metric: CoachCaseMetric, comparator: CoachCaseComparator) {
        let haystack = "\(focus ?? "") \(title)".lowercased()
        if mode == .ahCounter || haystack.contains("filler") {
            return (.fillersPerMinute, .atMost)
        }
        return (.sessionScore, .atLeast)
    }

    private static func metricValue(
        _ metric: CoachCaseMetric,
        from session: PracticeSession
    ) -> Double? {
        switch metric {
        case .fillersPerRep: return Double(session.fillerWordCount)
        case .fillersPerMinute:
            guard session.duration >= RecommendationComparisonEngine.minimumReliableDuration else {
                return nil
            }
            return Double(session.fillerWordCount) / session.duration * 60
        case .sessionScore: return session.score.map(Double.init)
        case .durationSeconds: return session.duration
        case .wordsPerMinute:
            // A very short fragment reads as a wild wpm; below the qualifying
            // floor the reading is noise, so return nil and let the criterion
            // stay pending rather than judge pace on garbage.
            guard session.duration >= 15, session.wordsPerMinute > 0 else { return nil }
            return Double(session.wordsPerMinute)
        }
    }

    private static func followedRepValues(
        metric: CoachCaseMetric,
        mode: PracticeMode,
        focus: String?,
        title: String,
        prescribedAt: Date?,
        outcomes: [RecommendationOutcome],
        sessions: [PracticeSession],
        now: Date,
        limit: Int = 8
    ) -> [Double] {
        let normalizedFocus = boundedText(focus, maximumLength: 80)
        let sessionsByID = Dictionary(sessions.map { ($0.id, $0) }, uniquingKeysWith: { current, _ in current })
        var admittedSessionIDs = Set<UUID>()

        return outcomes
            .filter { outcome in
                outcome.isVerifiedFollowed
                    && outcome.hasComparableBaseline
                    && outcome.mode == mode
                    && boundedText(outcome.focus, maximumLength: 80) == normalizedFocus
                    && outcomeSupportsCriterion(
                        outcome,
                        metric: metric,
                        mode: mode,
                        focus: focus,
                        title: title
                    )
                    && outcome.completedAt <= now
                    && prescribedAt.map { outcome.completedAt >= $0 } ?? true
            }
            .sorted { lhs, rhs in
                if lhs.completedAt != rhs.completedAt { return lhs.completedAt > rhs.completedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .filter { admittedSessionIDs.insert($0.sessionID).inserted }
            .compactMap { outcome -> (RecommendationOutcome, PracticeSession)? in
                guard let session = sessionsByID[outcome.sessionID],
                      session.mode == mode,
                      session.date <= now,
                      session.comparisonMetricSchemaVersion == PracticeSession.currentComparisonMetricSchemaVersion else {
                    return nil
                }
                return (outcome, session)
            }
            .prefix(limit)
            .compactMap { metricValue(metric, from: $0.1) }
    }

    private static func outcomeSupportsCriterion(
        _ outcome: RecommendationOutcome,
        metric: CoachCaseMetric,
        mode: PracticeMode,
        focus: String?,
        title: String
    ) -> Bool {
        switch metric {
        case .fillersPerRep:
            return false
        case .fillersPerMinute:
            return outcome.fillerRateDelta != nil
        case .sessionScore:
            return RecommendationMetricFocus.kind(mode: mode, focus: focus, title: title) == .general
                && outcome.hasComparableScore == true
        case .durationSeconds:
            return true
        case .wordsPerMinute:
            return outcome.wordsPerMinute != nil && outcome.paceDelta != nil
        }
    }

    private static func buildSuccessCriterion(
        mode: PracticeMode,
        focus: String?,
        title: String,
        outcomes: [RecommendationOutcome],
        sessions: [PracticeSession],
        now: Date
    ) -> CoachSuccessCriterion {
        // Focus-matched bar first (hold the prescription to the metric it
        // prescribes); falls through byte-identically to the generic path
        // whenever the focused bar cannot be honestly grounded.
        if let pace = paceCriterion(
            mode: mode,
            focus: focus,
            title: title,
            outcomes: outcomes,
            sessions: sessions,
            now: now
        ) {
            return pace
        }
        let (metric, comparator) = caseMetric(mode: mode, focus: focus, title: title)
        let window = caseEvaluationWindow
        let baseline = comparisonBaseline(
            metric: metric,
            mode: mode,
            focus: focus,
            outcomes: outcomes,
            sessions: sessions,
            now: now
        )
        let priorAverage = baseline?.average

        let threshold: Double
        switch metric {
        case .fillersPerRep:
            threshold = max(0, ((priorAverage ?? 3) - 1).rounded())
        case .fillersPerMinute:
            let target = max(0, (priorAverage ?? 2.75) - RecommendationAdaptationAnalyzer.fillerSwing)
            threshold = (target * 10).rounded() / 10
        case .sessionScore:
            threshold = min(10, ((priorAverage ?? 6) + 1).rounded())
        case .durationSeconds:
            threshold = (priorAverage ?? 45).rounded()
        case .wordsPerMinute:
            // Unreachable via caseMetric (pace bars are built exclusively by
            // paceCriterion, which grounds direction in the user's own band
            // deviation); a safe in-band default keeps the switch total.
            threshold = healthyPaceBand.upperBound
        }

        let baselineSnapshot: CoachSuccessCriterion.BaselineSnapshot? = baseline.flatMap { baseline in
                guard baseline.sampleDepth >= minPriorRepsForGroundedCriterion else { return nil }
                return CoachSuccessCriterion.BaselineSnapshot(
                    priorAverage: clampedAverage(baseline.average, for: metric),
                    sampleDepth: baseline.sampleDepth
                )
        }

        return CoachSuccessCriterion(
            metric: metric,
            comparator: comparator,
            threshold: threshold,
            evaluationWindow: window,
            summary: criterionSummary(
                metric: metric,
                threshold: threshold,
                window: window,
                baseline: baselineSnapshot
            ),
            baselineSnapshot: baselineSnapshot,
            evidenceSchemaVersion: criterionEvidenceSchemaVersion
        )
    }

    private struct CriterionComparisonBaseline {
        let average: Double
        let sampleDepth: Int
    }

    /// Recovers the persisted same-demand baseline behind the latest accepted
    /// outcome. This keeps the success bar on the same evidence recipe as the
    /// adaptation ledger without storing a second copy of session history.
    private static func comparisonBaseline(
        metric: CoachCaseMetric,
        mode: PracticeMode,
        focus: String?,
        outcomes: [RecommendationOutcome],
        sessions: [PracticeSession],
        now: Date
    ) -> CriterionComparisonBaseline? {
        let normalizedFocus = boundedText(focus, maximumLength: 80)
        let sessionsByID = Dictionary(sessions.map { ($0.id, $0) }, uniquingKeysWith: { current, _ in current })
        guard let outcome = outcomes
            .filter({
                $0.isVerifiedFollowed
                    && $0.hasComparableBaseline
                    && $0.mode == mode
                    && boundedText($0.focus, maximumLength: 80) == normalizedFocus
                    && $0.completedAt <= now
            })
            .sorted(by: { $0.completedAt > $1.completedAt })
            .first,
              let session = sessionsByID[outcome.sessionID],
              session.comparisonMetricSchemaVersion == PracticeSession.currentComparisonMetricSchemaVersion,
              let current = metricValue(metric, from: session) else { return nil }

        let average: Double?
        switch metric {
        case .fillersPerRep:
            average = nil
        case .fillersPerMinute:
            average = outcome.fillerRateDelta.map { current - $0 }
        case .sessionScore:
            average = outcome.hasComparableScore == true ? current - outcome.scoreDelta : nil
        case .durationSeconds:
            average = current - outcome.durationDelta
        case .wordsPerMinute:
            average = outcome.paceDelta.map { current - $0 }
        }
        guard let average else { return nil }
        return CriterionComparisonBaseline(
            average: average,
            sampleDepth: outcome.comparisonSessionCount ?? 0
        )
    }

    /// The minimum pre-window history (reps OLDER than the evaluation window)
    /// required before the success-bar copy is allowed to quote the user's own
    /// average. Below this, the figure isn't trustworthy enough to ground the
    /// bar, so the copy falls back byte-identically to the generic phrasing.
    /// Gated on the PRE-WINDOW count (`priorValues.count`), never the full
    /// followed-rep count, so the real number never appears on thin data.
    private static let minPriorRepsForGroundedCriterion = 3

    /// The healthy conversational band the pace criterion anchors to.
    /// Shared with the adaptation analyzer via `PaceCoaching`.
    private static var healthyPaceBand: ClosedRange<Double> { PaceCoaching.healthyBand }

    /// Focus-matched pace bar: a pacing prescription is judged on words per
    /// minute, not the composite session score. Returns nil — the caller then
    /// falls back byte-identically to the generic criterion — unless ALL hold:
    ///   • the prescription is actually about pace (focus/title keywords) and
    ///     not a filler prescription (filler precedence is preserved),
    ///   • at least `minPriorRepsForGroundedCriterion` pre-window reps carry a
    ///     reliable wpm reading (never ground a bar on thin or unmeasurable
    ///     history), and
    ///   • the user's own prior average sits OUTSIDE the healthy band — an
    ///     in-band speaker already meets any honest pace bar, so holding them
    ///     to one would be theatre.
    /// The bar is the NEAR band edge (get inside 105–175), never a number the
    /// user hasn't shown they need, and the criterion is judged on the same
    /// followed-rep window as every other bar. Applies only to newly built
    /// criteria: same-prescription rebuilds carry the previous criterion
    /// verbatim upstream, so an open intervention's goalposts never move.
    private static func paceCriterion(
        mode: PracticeMode,
        focus: String?,
        title: String,
        outcomes: [RecommendationOutcome],
        sessions: [PracticeSession],
        now: Date
    ) -> CoachSuccessCriterion? {
        guard PaceCoaching.isPaceFocused(mode: mode, focus: focus, title: title) else { return nil }

        let window = caseEvaluationWindow
        guard let prior = comparisonBaseline(
            metric: .wordsPerMinute,
            mode: mode,
            focus: focus,
            outcomes: outcomes,
            sessions: sessions,
            now: now
        ), prior.sampleDepth >= minPriorRepsForGroundedCriterion else { return nil }
        let priorAverage = prior.average
        guard !healthyPaceBand.contains(priorAverage) else { return nil }

        let comparator: CoachCaseComparator = priorAverage > healthyPaceBand.upperBound
            ? .atMost
            : .atLeast
        let threshold = comparator == .atMost
            ? healthyPaceBand.upperBound
            : healthyPaceBand.lowerBound
        let baseline = CoachSuccessCriterion.BaselineSnapshot(
            priorAverage: clampedAverage(priorAverage, for: .wordsPerMinute),
            sampleDepth: prior.sampleDepth
        )
        return CoachSuccessCriterion(
            metric: .wordsPerMinute,
            comparator: comparator,
            threshold: threshold,
            evaluationWindow: window,
            summary: criterionSummary(
                metric: .wordsPerMinute,
                threshold: threshold,
                window: window,
                baseline: baseline,
                comparator: comparator
            ),
            baselineSnapshot: baseline,
            evidenceSchemaVersion: criterionEvidenceSchemaVersion
        )
    }

    private static func clampedAverage(_ value: Double, for metric: CoachCaseMetric) -> Double {
        switch metric {
        case .fillersPerRep, .fillersPerMinute, .durationSeconds, .wordsPerMinute:
            return max(0, value)
        case .sessionScore:
            return min(10, max(0, value))
        }
    }

    /// Formats a metric average for criterion copy: drops a trailing `.0` so a
    /// whole number reads as "6" (not "6.0"), otherwise rounds to one decimal
    /// ("6.3"). Locale-agnostic deterministic copy — no `NumberFormatter`, so
    /// the string is identical across locales and unit-testable without a
    /// device.
    private static func formattedAverage(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded.rounded()))
        }
        return String(format: "%.1f", rounded)
    }

    /// Builds the success-bar copy. When the user has >= 3 pre-window followed
    /// reps the bar is grounded in their OWN average ("your last 3 reps
    /// averaged 6.3 fillers — hold at 5 or fewer across 2 reps"); below that
    /// floor (or with no measurable prior average) the copy is BYTE-IDENTICAL
    /// to the generic phrasing so thin-evidence behaviour is unchanged and no
    /// fabricated number is ever shown. `fillersPerRep` is a COUNT (never a
    /// percentage) and `window` is always `caseEvaluationWindow` (2), so the
    /// grounded copy never invents a unit or a window the engine doesn't use.
    private static func criterionSummary(
        metric: CoachCaseMetric,
        threshold: Double,
        window: Int,
        baseline: CoachSuccessCriterion.BaselineSnapshot? = nil,
        comparator: CoachCaseComparator? = nil
    ) -> String {
        let count = Int(threshold)
        let reps = window <= 1 ? "the next rep" : "\(window) reps"
        // Pace bars carry direction (a fast talker slows, a slow talker
        // lifts); every other metric's direction is implied by the metric.
        let paceDirection = comparator == .atLeast ? "faster" : "slower"

        // Grounded path: enough pre-window history AND a real average to quote.
        if let baseline {
            let avg = formattedAverage(baseline.priorAverage)
            switch metric {
            case .fillersPerRep:
                let fillers = count == 1 ? "filler" : "fillers"
                return "your last \(baseline.sampleDepth) reps averaged \(avg) \(fillers) — hold at \(count) or fewer per rep across \(reps)"
            case .fillersPerMinute:
                return "your last \(baseline.sampleDepth) comparable reps averaged \(avg) fillers/min — hold at \(formattedAverage(threshold)) or fewer/min across \(reps)"
            case .sessionScore:
                return "your last \(baseline.sampleDepth) reps averaged \(avg) — hold a \(count) or higher across \(reps)"
            case .durationSeconds:
                return "your last \(baseline.sampleDepth) reps averaged ~\(avg)s — hold ~\(count)s of structured delivery across \(reps)"
            case .wordsPerMinute:
                return "your last \(baseline.sampleDepth) reps averaged \(avg) words/min — bring it to \(count) or \(paceDirection) across \(reps)"
            }
        }

        // Below the evidence floor — generic copy, byte-identical to before.
        switch metric {
        case .fillersPerRep:
            let fillers = count == 1 ? "filler" : "fillers"
            return "\(count) or fewer \(fillers) per rep across \(reps)"
        case .fillersPerMinute:
            return "\(formattedAverage(threshold)) or fewer fillers/min across \(reps)"
        case .sessionScore:
            return "score of \(count) or higher across \(reps)"
        case .durationSeconds:
            return "hold ~\(count)s of structured delivery across \(reps)"
        case .wordsPerMinute:
            return "\(count) words/min or \(paceDirection) across \(reps)"
        }
    }

    private static func baseIntervention(
        pending: RecommendationExposure?,
        outcomes: [RecommendationOutcome]
    ) -> CoachIntervention? {
        if let pending {
            return CoachIntervention(
                title: boundedText(pending.title) ?? pending.mode.displayLabel,
                focus: boundedText(pending.focus),
                target: boundedText(pending.target),
                mode: pending.mode,
                prescribedAt: pending.shownAt,
                lastObservedAt: nil,
                followedRepCount: 0,
                minimumFollowedRepsForReview: 2,
                reviewStatus: .awaitingAttempt,
                reviewBasis: "Shown to the user; no followed rep has tested it yet."
            )
        }

        guard let latest = outcomes.sorted(by: { $0.completedAt > $1.completedAt }).first else {
            return nil
        }

        guard latest.isVerifiedFollowed else {
            return CoachIntervention(
                title: boundedText(latest.title) ?? latest.mode.displayLabel,
                focus: boundedText(latest.focus),
                target: boundedText(latest.target),
                mode: latest.mode,
                prescribedAt: nil,
                lastObservedAt: latest.completedAt,
                followedRepCount: 0,
                minimumFollowedRepsForReview: 2,
                reviewStatus: .awaitingAttempt,
                reviewBasis: "The completed rep used another mode; do not count it as intervention evidence."
            )
        }

        let normalizedLatestFocus = boundedText(latest.focus, maximumLength: 80)
        let summary = RecommendationResponseAnalyzer
            .summarize(outcomes: outcomes, limit: 12)
            .first {
                $0.mode == latest.mode &&
                boundedText($0.focus, maximumLength: 80) == normalizedLatestFocus
            }
        let followedRepCount = summary?.followedCount ?? 1

        // Prefer the stricter reinforce / vary / replace verdict once enough
        // measurable reps exist (≥3), so the durable case file reads the SAME
        // adaptation decision the chat coach, forward plan, and next-practice
        // recommendation do — a coach holds one read across every surface, not a
        // "continue and verify" here and a "vary" there. Below the floor the
        // verdict is nil and we fall back to the existing association assessment,
        // so thin-evidence behaviour is unchanged.
        //
        // Deliberate keying difference (coherent, not contradictory): the case
        // file keys the verdict on `latest.mode`/`latest.focus` — the most-RECENT
        // prescription, i.e. the status of the ACTIVE intervention — whereas the
        // chat coach and forward plan key on `summarize().first`, the most-FOLLOWED
        // group. The identical reducer runs per key, so each key's verdict is
        // self-consistent; the surfaces can headline different keys when the most-
        // recent prescription isn't the most-evidenced one, which is the distinction
        // a real coach holds (the active drill vs. the strongest pattern), not two
        // contradictory reads. See docs/initiatives/01_adaptation_loop_spec.md.
        let status: CoachInterventionReviewStatus
        let reviewBasis: String
        if let verdict = RecommendationAdaptationAnalyzer.adaptationVerdict(
            mode: latest.mode, focus: latest.focus, in: outcomes),
           let verdictLine = RecommendationAdaptationAnalyzer.adaptationRationale(
            mode: latest.mode, focus: latest.focus, in: outcomes) {
            switch verdict.action {
            case .reinforce:
                status = .continueAndVerify
            case .vary:
                status = .diagnoseBeforeRepeating
            case .replace:
                status = .adaptBeforeRepeating
            }
            reviewBasis = verdictLine.trimmingCharacters(in: CharacterSet(charactersIn: "- "))
        } else {
            switch summary?.assessment ?? .forming {
            case .forming:
                status = .formingEvidence
            case .promising:
                status = .continueAndVerify
            case .mixed:
                status = .diagnoseBeforeRepeating
            case .needsAdjustment:
                status = .adaptBeforeRepeating
            }
            reviewBasis = (summary?.assessment ?? .forming).coachingGuidance
        }

        return CoachIntervention(
            title: boundedText(latest.title) ?? latest.mode.displayLabel,
            focus: boundedText(latest.focus),
            target: boundedText(latest.target),
            mode: latest.mode,
            prescribedAt: nil,
            lastObservedAt: latest.completedAt,
            followedRepCount: followedRepCount,
            minimumFollowedRepsForReview: 2,
            reviewStatus: status,
            reviewBasis: reviewBasis
        )
    }

    private static func boundedText(_ value: String?, maximumLength: Int = 120) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maximumLength))
    }

    private static func skillArea(fromBlocker blocker: String) -> SkillArea? {
        let normalized = blocker.lowercased()
        if normalized.contains("filler") { return .fillerReduction }
        if normalized.contains("opening") { return .openingStrength }
        if normalized.contains("closing") || normalized.contains("close") { return .closingStrength }
        if normalized.contains("pace") || normalized.contains("rush") { return .paceControl }
        if normalized.contains("structure") || normalized.contains("rambl") { return .structure }
        if normalized.contains("depth") || normalized.contains("answer") { return .answerDevelopment }
        if normalized.contains("clarity") || normalized.contains("concise") { return .conciseSpeaking }
        if normalized.contains("pause") { return .pauseUsage }
        if normalized.contains("emphasis") || normalized.contains("vocal") { return .vocalEmphasis }
        if normalized.contains("confidence") || normalized.contains("freez") { return .confidence }
        return nil
    }

    private static func latestIntentLabel(from sessions: [PracticeSession]) -> String? {
        sessions
            .sorted { $0.date > $1.date }
            .compactMap { $0.intentLabel?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func statedGoalSummary(from profile: CoachingProfile?) -> String? {
        guard let profile else { return nil }
        let candidates = [
            profile.trustedStyleGoalParaphrase,
            profile.personalGoalReference,
            profile.successVisionReference,
            profile.whyNowReference,
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

#if canImport(Combine)
@MainActor
final class CoachMemoryStore: ObservableObject {
    static let shared = CoachMemoryStore()

    @Published private(set) var currentMemory: CoachMemory?

    private static let storagePrefix = "coachMemory."

    private let defaults: UserDefaults
    private let accountIDProvider: () -> String?

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: (() -> String?)? = nil
    ) {
        self.defaults = defaults
        self.accountIDProvider = accountIDProvider ?? { KeychainHelper.load(key: "NoumAccountID") }
        loadFromDisk()
    }

    func reloadForCurrentAccount() {
        loadFromDisk()
        UserTrajectoryCache.shared.invalidate()
    }

    func endSession() {
        currentMemory = nil
        UserTrajectoryCache.shared.invalidate()
    }

    func refresh(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        sessions: [PracticeSession],
        trends: [SkillTrend],
        forwardPlan: ForwardPlan?,
        lastSessionID: UUID?,
        pendingIntervention: RecommendationExposure? = nil,
        recommendationOutcomes: [RecommendationOutcome] = [],
        latestReflection: SessionReflection? = nil,
        reflectionHistory: [SessionReflection] = [],
        latestTransferReport: BigMomentOutcomeReport? = nil,
        upcomingMoment: BigMoment? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        guard let memory = CoachMemoryEngine.build(
            profile: profile,
            baseline: baseline,
            sessions: sessions,
            trends: trends,
            forwardPlan: forwardPlan,
            previous: currentMemory,
            lastSessionID: lastSessionID,
            pendingIntervention: pendingIntervention,
            recommendationOutcomes: recommendationOutcomes,
            latestReflection: latestReflection,
            reflectionHistory: reflectionHistory,
            latestTransferReport: latestTransferReport,
            upcomingMoment: upcomingMoment,
            now: now,
            calendar: calendar
        ) else { return }
        currentMemory = memory
        persist(memory)
    }

    /// Update only the durable reflection clause on the current memory,
    /// without a full rebuild. Called when the user reflects on the summary
    /// screen (after `refresh` already ran at finalize) so Ask Noum's
    /// context carries this rep's felt experience immediately.
    func noteReflection(
        _ summary: String?,
        // Outer `nil` (the default) re-reads the LIVE nearest moment from the
        // store on every rebuild, so a caller can never accidentally freeze a
        // stale moment. Tests inject a specific value via `.some(...)`; default
        // args can't reference main-actor state, hence the double optional.
        upcomingMoment: BigMoment?? = .none
    ) {
        guard var memory = currentMemory else { return }
        memory.lastReflectionSummary = summary
        memory.lastReflectionReview = nil
        memory.reflectionPattern = nil
        memory.updatedAt = Date()
        // Re-derive the upcoming-moment line from the live store on every
        // incremental rebuild — it isn't a stored `CoachMemory` field. Carrying
        // the prior value forward kept "Preparing for: …" coherent only while
        // the moment was unchanged; if the user added or changed a real-world
        // moment between full refreshes, the durable case quoted a stale one.
        // Reading the store keeps goal + baseline + pattern + nearest moment
        // coherent, and still never drops a line that is genuinely still set.
        memory.caseFile = CoachCaseFile.build(
            from: memory,
            now: memory.updatedAt,
            upcomingMomentLine: CoachCaseFile.upcomingMomentLine(for: upcomingMoment ?? BigMomentStore.shared.activeMoment)
        )
        currentMemory = memory
        persist(memory)
    }

    /// Structured late-arriving reflection from the post-rep summary. Keeps
    /// the user's own words and the next review move inside the durable case
    /// immediately, without waiting for the next full memory rebuild.
    func noteReflection(
        _ reflection: SessionReflection,
        recentReflections: [SessionReflection] = [],
        // Outer `nil` (the default) re-reads the LIVE nearest moment from the
        // store on every rebuild, so a caller can never accidentally freeze a
        // stale moment. Tests inject a specific value via `.some(...)`; default
        // args can't reference main-actor state, hence the double optional.
        upcomingMoment: BigMoment?? = .none
    ) {
        guard var memory = currentMemory else { return }
        memory.lastReflectionSummary = reflection.coachClause
        memory.lastReflectionReview = CoachReflectionReview(reflection: reflection)
        let history = recentReflections.isEmpty ? [reflection] : recentReflections
        memory.reflectionPattern = CoachReflectionPattern.build(from: history)
        memory.updatedAt = Date()
        memory.caseFile = CoachCaseFile.build(
            from: memory,
            now: memory.updatedAt,
            upcomingMomentLine: CoachCaseFile.upcomingMomentLine(for: upcomingMoment ?? BigMomentStore.shared.activeMoment)
        )
        currentMemory = memory
        persist(memory)
    }

    /// Record the user's one-tap verdict on the working hypothesis from
    /// the `AskNoumView` acknowledgement chip row. Snapshots the current
    /// `workingHypothesis` so a later rebuild that rewrites the read can
    /// detect drift and re-prompt. No-op when no current memory exists or
    /// no `workingHypothesis` is set (defensive — the chip row never
    /// renders without a current hypothesis, but the store still guards).
    func noteHypothesisAcknowledgement(
        _ confidence: CoachHypothesisConfidence,
        at now: Date = Date(),
        // Outer `nil` (the default) re-reads the LIVE nearest moment from the
        // store on every rebuild, so a caller can never accidentally freeze a
        // stale moment. Tests inject a specific value via `.some(...)`; default
        // args can't reference main-actor state, hence the double optional.
        upcomingMoment: BigMoment?? = .none
    ) {
        guard var memory = currentMemory,
              let hypothesis = memory.workingHypothesis?.trimmingCharacters(in: .whitespacesAndNewlines),
              !hypothesis.isEmpty else { return }
        memory.hypothesisAcknowledgement = CoachHypothesisAcknowledgement(
            confidence: confidence,
            hypothesisSnapshot: hypothesis,
            acknowledgedAt: now
        )
        memory.updatedAt = now
        memory.caseFile = CoachCaseFile.build(
            from: memory,
            now: now,
            upcomingMomentLine: CoachCaseFile.upcomingMomentLine(for: upcomingMoment ?? BigMomentStore.shared.activeMoment)
        )
        currentMemory = memory
        persist(memory)
    }

    /// Record the user's confirmed voice-goal change from the `AskNoumView`
    /// goal-change card. Appends a `CoachCourseChange` to the bounded
    /// `adaptationLog` so the case carries an honest "reason for changing
    /// course" rather than silently swapping the goal — the human-in-the-loop
    /// audit trail the coach reads back. Mirrors
    /// `noteHypothesisAcknowledgement`: guard the current memory, append,
    /// bound to the last 8 (same ceiling the engine enforces in `build`),
    /// stamp `updatedAt`, rebuild the case file, persist. No-op when no
    /// current memory exists (cold-start has nothing to record against — the
    /// profile write is the durable record there).
    ///
    /// The change ONLY appends — it never wipes the prior adaptation history,
    /// session evidence, baseline, or trends (all keyed by `SkillArea`/metric,
    /// none carry a voice field). Levers are mapped via each voice's
    /// `primaryAlignedSkillArea` so the recorded `from`/`to` read as the
    /// concrete skill the voice change re-weights toward. The recorded entry
    /// auto-surfaces to the model through the generic course-change branch in
    /// `CoachContextBuilder.interventionCycleLines`.
    ///
    /// - Parameters:
    ///   - from: the voice the user is leaving.
    ///   - to: the voice the user is moving to.
    ///   - reason: the documented reason for the change (caller composes it
    ///     from `shortVoiceLabel`).
    ///   - evidenceBasis: how the prior voice's work is characterised.
    ///   - at: timestamp; defaults to now. Used by `recentVoiceChangeCount`.
    func noteVoiceChange(
        from: SpeakingStyleGoal,
        to: SpeakingStyleGoal,
        reason: String,
        evidenceBasis: String,
        statedGoalSummary: String? = nil,
        effectiveVoice: SpeakingStyleGoal? = nil,
        at now: Date = Date(),
        // Outer `nil` (the default) re-reads the LIVE nearest moment from the
        // store on every rebuild, so a caller can never accidentally freeze a
        // stale moment. Tests inject a specific value via `.some(...)`; default
        // args can't reference main-actor state, hence the double optional.
        upcomingMoment: BigMoment?? = .none
    ) {
        guard var memory = currentMemory else { return }
        var log = memory.adaptationLog ?? []
        log.append(
            CoachCourseChange(
                id: UUID(),
                changedAt: now,
                fromLever: from.primaryAlignedSkillArea,
                toLever: to.primaryAlignedSkillArea,
                reason: reason,
                evidenceBasis: evidenceBasis
            )
        )
        memory.adaptationLog = Array(log.suffix(8))
        // The observed case survives a goal change. Only goal-derived
        // projections are invalidated: provenance moves to the confirmed goal,
        // goal fit is recomputed against the same measured lever, and the plan
        // projection is cleared until a matching ForwardPlan is generated.
        let resolvedVoice = effectiveVoice ?? to
        memory.voice = resolvedVoice
        memory.statedGoalSummary = statedGoalSummary
        if let lever = memory.currentLever {
            memory.goalFit = resolvedVoice.aligns(with: lever) ? .aligned : .offGoal
        } else {
            memory.goalFit = .noLever
        }
        memory.planWeekIndex = nil
        memory.planFocus = nil
        memory.planMode = nil
        memory.updatedAt = now
        memory.caseFile = CoachCaseFile.build(
            from: memory,
            now: now,
            upcomingMomentLine: CoachCaseFile.upcomingMomentLine(for: upcomingMoment ?? BigMomentStore.shared.activeMoment)
        )
        currentMemory = memory
        persist(memory)
    }

    /// Fold a completed real-world check-in into the current case without
    /// changing the measured intervention verdict. The report may motivate a
    /// review question or an adaptation, but it cannot establish causation.
    func noteTransferOutcome(
        _ report: BigMomentOutcomeReport,
        // Outer `nil` (the default) re-reads the LIVE nearest moment from the
        // store on every rebuild, so a caller can never accidentally freeze a
        // stale moment. Tests inject a specific value via `.some(...)`; default
        // args can't reference main-actor state, hence the double optional.
        upcomingMoment: BigMoment?? = .none
    ) {
        guard var memory = currentMemory else { return }
        memory.lastTransferReview = CoachTransferReview(report: report)
        memory.updatedAt = Date()
        memory.caseFile = CoachCaseFile.build(
            from: memory,
            now: memory.updatedAt,
            upcomingMomentLine: CoachCaseFile.upcomingMomentLine(for: upcomingMoment ?? BigMomentStore.shared.activeMoment)
        )
        currentMemory = memory
        persist(memory)
    }

    /// Fold a user-initiated AI video analysis into the durable case. This is
    /// opt-in visual evidence from one recording, not a trait label; the
    /// `VisualDeliveryRead` builder reuses `VideoAnalysisContract.normalized`
    /// so generic/invalid provider text never reaches coach memory.
    @discardableResult
    func noteVisualDeliveryRead(
        from result: VideoAnalysisResult,
        sessionID: UUID?,
        recordedAt: Date = Date(),
        // Outer `nil` (the default) re-reads the LIVE nearest moment from the
        // store on every rebuild, matching the other incremental case updates.
        upcomingMoment: BigMoment?? = .none
    ) -> Bool {
        guard var memory = currentMemory,
              let read = VisualDeliveryRead.make(
                from: result,
                sessionID: sessionID,
                recordedAt: recordedAt
              ) else { return false }
        memory.visualDeliveryRead = read
        memory.updatedAt = recordedAt
        memory.caseFile = CoachCaseFile.build(
            from: memory,
            now: recordedAt,
            upcomingMomentLine: CoachCaseFile.upcomingMomentLine(for: upcomingMoment ?? BigMomentStore.shared.activeMoment)
        )
        currentMemory = memory
        persist(memory)
        return true
    }

    func replaceForTesting(_ memory: CoachMemory?) {
        currentMemory = memory
        guard let accountID = accountIDProvider() else { return }
        if let memory {
            persist(memory)
        } else {
            defaults.removeObject(forKey: storageKey(for: accountID))
        }
    }

    /// User-owned edit for the goal statement carried into coaching context.
    /// This never edits measured evidence, the active lever, or intervention
    /// history. Empty input removes the statement instead of inventing copy.
    func updateStatedGoalSummary(_ rawValue: String, at now: Date = Date()) {
        guard var memory = currentMemory else { return }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        memory.statedGoalSummary = trimmed.isEmpty ? nil : String(trimmed.prefix(280))
        memory.updatedAt = now
        memory.caseFile = CoachCaseFile.build(
            from: memory,
            now: now,
            upcomingMomentLine: CoachCaseFile.upcomingMomentLine(for: BigMomentStore.shared.activeMoment)
        )
        currentMemory = memory
        persist(memory)
    }

    /// Removes coach-authored interpretation while leaving user evidence and
    /// all observed session evidence intact. A later evidence rebuild may form
    /// a new, explicitly confirmable hypothesis.
    func removeWorkingHypothesis(at now: Date = Date()) {
        guard var memory = currentMemory else { return }
        memory.workingHypothesis = nil
        memory.hypothesisAcknowledgement = nil
        memory.hypothesisWatchStartedAt = nil
        memory.updatedAt = now
        memory.caseFile = CoachCaseFile.build(
            from: memory,
            now: now,
            upcomingMomentLine: CoachCaseFile.upcomingMomentLine(for: BigMomentStore.shared.activeMoment)
        )
        currentMemory = memory
        persist(memory)
    }

    /// Deletes the bounded self-report projection from coach memory. The
    /// underlying reflection owner remains the user's session-history store;
    /// this action controls what the cross-session coach carries forward.
    func removeCarriedReflection(at now: Date = Date()) {
        guard var memory = currentMemory else { return }
        memory.lastReflectionSummary = nil
        memory.lastReflectionReview = nil
        memory.reflectionPattern = nil
        memory.updatedAt = now
        memory.caseFile = CoachCaseFile.build(
            from: memory,
            now: now,
            upcomingMomentLine: CoachCaseFile.upcomingMomentLine(for: BigMomentStore.shared.activeMoment)
        )
        currentMemory = memory
        persist(memory)
    }

    func clearAll() {
        guard let accountID = accountIDProvider() else {
            currentMemory = nil
            UserTrajectoryCache.shared.invalidate()
            return
        }
        currentMemory = nil
        defaults.removeObject(forKey: storageKey(for: accountID))
        UserTrajectoryCache.shared.invalidate()
    }

    func deleteAllData(for accountID: String) {
        defaults.removeObject(forKey: storageKey(for: accountID))
        if accountIDProvider() == accountID {
            currentMemory = nil
            UserTrajectoryCache.shared.invalidate()
        }
    }

    private func persist(_ memory: CoachMemory) {
        defer {
            _ = UserTrajectoryCache.shared.warmFromCurrentStores()
        }
        guard let accountID = accountIDProvider(),
              let data = try? JSONEncoder().encode(memory) else { return }
        defaults.set(data, forKey: storageKey(for: accountID))
    }

    private func loadFromDisk() {
        guard let accountID = accountIDProvider(),
              let data = defaults.data(forKey: storageKey(for: accountID)),
              let decoded = try? JSONDecoder().decode(CoachMemory.self, from: data) else {
            currentMemory = nil
            return
        }
        currentMemory = decoded
    }

    private func storageKey(for accountID: String) -> String {
        "\(Self.storagePrefix)\(accountID)"
    }
}
#endif
