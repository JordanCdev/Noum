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
}

/// The measurable session metric a success criterion is judged against.
/// Restricted to fields every `PracticeSession` carries so status can always
/// be computed without a provider call or transcript re-analysis.
enum CoachCaseMetric: String, Codable, Equatable {
    case fillersPerRep
    case sessionScore
    case durationSeconds
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
        case .met: return "criterion currently met"
        case .notYetMet: return "criterion not yet met"
        }
    }
}

/// "What improvement looks like before the user starts" — the explicit,
/// measurable bar a prescription is held to. Defined once when the
/// intervention is prescribed and kept stable across rebuilds; only its
/// `status` is recomputed from the user's followed reps.
struct CoachSuccessCriterion: Codable, Equatable {
    var metric: CoachCaseMetric
    var comparator: CoachCaseComparator
    var threshold: Double
    var evaluationWindow: Int
    var summary: String

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

    /// True iff this course change documents a user-tapped rejection of the
    /// prior working hypothesis (as opposed to an engine-only lever shift).
    /// Pure function of the persisted `reason` — no extra state to round-trip
    /// through Codable, so memories persisted before this lift decode and
    /// behave correctly without a schema bump.
    var documentsUserPushback: Bool {
        reason.range(of: CoachCourseChange.userPushbackMarker, options: .caseInsensitive) != nil
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
    var recordedAt: Date
    var nextAction: CoachTransferReviewAction

    init(report: BigMomentOutcomeReport) {
        momentID = report.momentID
        momentTitle = report.momentTitle
        category = report.category
        outcome = report.outcome
        audienceResponse = report.audienceResponse
        note = report.note
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
        let base = "For \(category.displayName) \"\(momentTitle)\", the user reported \(outcome.coachClause); \(audienceResponse.coachClause)."
        guard let note else { return base }
        return "\(base) Their note: \"\(note)\"."
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
    var strengths: [String]
    var blockers: [String]
    var lastIntentLabel: String?
    var planWeekIndex: Int?
    var planFocus: SkillArea?
    var planMode: PracticeMode?
    var workingHypothesis: String?
    var activeIntervention: CoachIntervention?

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
        strengths: [String],
        blockers: [String],
        lastIntentLabel: String? = nil,
        planWeekIndex: Int? = nil,
        planFocus: SkillArea? = nil,
        planMode: PracticeMode? = nil,
        workingHypothesis: String? = nil,
        activeIntervention: CoachIntervention? = nil,
        hypothesisAcknowledgement: CoachHypothesisAcknowledgement? = nil,
        adaptationLog: [CoachCourseChange]? = nil,
        lastReflectionSummary: String? = nil,
        lastReflectionReview: CoachReflectionReview? = nil,
        lastTransferReview: CoachTransferReview? = nil,
        consecutiveCleanReps: Int? = nil,
        fillerTrendDirection: TrendDirection? = nil,
        weeklyRepCount: Int? = nil,
        isLatestSessionPersonalBest: Bool? = nil
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
        self.strengths = strengths
        self.blockers = blockers
        self.lastIntentLabel = lastIntentLabel
        self.planWeekIndex = planWeekIndex
        self.planFocus = planFocus
        self.planMode = planMode
        self.workingHypothesis = workingHypothesis
        self.activeIntervention = activeIntervention
        self.hypothesisAcknowledgement = hypothesisAcknowledgement
        self.adaptationLog = adaptationLog
        self.lastReflectionSummary = lastReflectionSummary
        self.lastReflectionReview = lastReflectionReview
        self.lastTransferReview = lastTransferReview
        self.consecutiveCleanReps = consecutiveCleanReps
        self.fillerTrendDirection = fillerTrendDirection
        self.weeklyRepCount = weeklyRepCount
        self.isLatestSessionPersonalBest = isLatestSessionPersonalBest
    }

    // Custom Decodable for backward compatibility — all momentum
    // fields use decodeIfPresent so existing persisted data decodes
    // without breaking.
    enum CodingKeys: String, CodingKey {
        case updatedAt, lastSessionID, evidenceCount, evidenceConfidence
        case voice, statedGoalSummary, currentLever, currentLeverConfidence
        case currentLeverBasis, previousLever, focusShiftedAt, goalFit
        case strengths, blockers, lastIntentLabel
        case planWeekIndex, planFocus, planMode
        case workingHypothesis, activeIntervention
        case hypothesisAcknowledgement
        case adaptationLog
        case lastReflectionSummary, lastReflectionReview, lastTransferReview
        case consecutiveCleanReps, fillerTrendDirection, weeklyRepCount
        case isLatestSessionPersonalBest
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
        strengths = try c.decode([String].self, forKey: .strengths)
        blockers = try c.decode([String].self, forKey: .blockers)
        lastIntentLabel = try c.decodeIfPresent(String.self, forKey: .lastIntentLabel)
        planWeekIndex = try c.decodeIfPresent(Int.self, forKey: .planWeekIndex)
        planFocus = try c.decodeIfPresent(SkillArea.self, forKey: .planFocus)
        planMode = try c.decodeIfPresent(PracticeMode.self, forKey: .planMode)
        workingHypothesis = try c.decodeIfPresent(String.self, forKey: .workingHypothesis)
        activeIntervention = try c.decodeIfPresent(CoachIntervention.self, forKey: .activeIntervention)
        hypothesisAcknowledgement = try c.decodeIfPresent(CoachHypothesisAcknowledgement.self, forKey: .hypothesisAcknowledgement)
        adaptationLog = try c.decodeIfPresent([CoachCourseChange].self, forKey: .adaptationLog)
        lastReflectionSummary = try c.decodeIfPresent(String.self, forKey: .lastReflectionSummary)
        lastReflectionReview = try c.decodeIfPresent(CoachReflectionReview.self, forKey: .lastReflectionReview)
        lastTransferReview = try c.decodeIfPresent(CoachTransferReview.self, forKey: .lastTransferReview)
        consecutiveCleanReps = try c.decodeIfPresent(Int.self, forKey: .consecutiveCleanReps)
        fillerTrendDirection = try c.decodeIfPresent(TrendDirection.self, forKey: .fillerTrendDirection)
        weeklyRepCount = try c.decodeIfPresent(Int.self, forKey: .weeklyRepCount)
        isLatestSessionPersonalBest = try c.decodeIfPresent(Bool.self, forKey: .isLatestSessionPersonalBest)
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
        latestTransferReport: BigMomentOutcomeReport? = nil,
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
        let voice = profile?.speakingStyleGoal
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
            let reason: String
            let evidenceBasis: String
            switch (priorLeverShift, droppedRejectedAck) {
            case let (prior?, ack?):
                reason = "Shifted focus from \(prior.displayName) to \(currentLever?.displayName ?? "the next read") after the user reported the prior hypothesis did not match what they saw."
                evidenceBasis = rejectedAckEvidenceBasis(ack: ack)
            case let (prior?, nil):
                reason = "Shifted focus from \(prior.displayName) to \(currentLever?.displayName ?? "the next read")."
                evidenceBasis = lever?.basis ?? "updated read across recent reps"
            case let (nil, ack?):
                reason = "User reported the prior hypothesis did not match what they saw; revising the read."
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
        memory.lastTransferReview = latestTransferReport.map { CoachTransferReview(report: $0) }
            ?? previous?.lastTransferReview
        memory.consecutiveCleanReps = momentumClean
        memory.fillerTrendDirection = momentumFillerTrend
        memory.weeklyRepCount = momentumWeekly
        memory.isLatestSessionPersonalBest = momentumPB
        return memory
    }

    private struct LeverSelection {
        let area: SkillArea
        let confidence: TrendConfidence?
        let basis: String
    }

    private static func selectLever(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        trends: [SkillTrend]
    ) -> LeverSelection? {
        if let trend = strongestTrendLever(from: trends, profile: profile) {
            return LeverSelection(
                area: trend.skillArea,
                confidence: trend.confidence,
                basis: trendBasis(trend)
            )
        }

        if let blocker = baseline.persistentBlockers.first,
           let area = skillArea(fromBlocker: blocker) {
            return LeverSelection(
                area: area,
                confidence: nil,
                basis: "persistent blocker in the rolling baseline"
            )
        }

        if let voice = profile?.speakingStyleGoal {
            return LeverSelection(
                area: voice.primaryAlignedSkillArea,
                confidence: nil,
                basis: "stated voice goal while evidence is still forming"
            )
        }

        return nil
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

        if profile?.speakingStyleGoal.aligns(with: trend.skillArea) == true {
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
        enrichWithCase(&intervention, sessions: sessions, previous: previous, now: now, calendar: calendar)
        return intervention
    }

    /// Attaches the case spine: a stable success criterion (carried forward
    /// when the prescription is unchanged, so "what good looks like" is defined
    /// once rather than re-derived each rebuild), the freshly-computed status
    /// from followed reps, and an explicit review date.
    private static func enrichWithCase(
        _ intervention: inout CoachIntervention,
        sessions: [PracticeSession],
        previous: CoachIntervention?,
        now: Date,
        calendar: Calendar
    ) {
        let isSamePrescription = previous?.mode == intervention.mode
            && boundedText(previous?.focus) == boundedText(intervention.focus)

        let criterion: CoachSuccessCriterion
        if isSamePrescription, let carried = previous?.successCriterion {
            criterion = carried
        } else {
            criterion = buildSuccessCriterion(
                mode: intervention.mode,
                focus: intervention.focus,
                title: intervention.title,
                sessions: sessions,
                now: now
            )
        }
        intervention.successCriterion = criterion

        let values = followedRepValues(
            metric: criterion.metric,
            mode: intervention.mode,
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
            return (.fillersPerRep, .atMost)
        }
        return (.sessionScore, .atLeast)
    }

    private static func metricValue(
        _ metric: CoachCaseMetric,
        from session: PracticeSession
    ) -> Double? {
        switch metric {
        case .fillersPerRep: return Double(session.fillerWordCount)
        case .sessionScore: return session.score.map(Double.init)
        case .durationSeconds: return session.duration
        }
    }

    private static func followedRepValues(
        metric: CoachCaseMetric,
        mode: PracticeMode,
        sessions: [PracticeSession],
        now: Date,
        limit: Int = 8
    ) -> [Double] {
        sessions
            .filter { $0.mode == mode && $0.date <= now }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .compactMap { metricValue(metric, from: $0) }
    }

    private static func buildSuccessCriterion(
        mode: PracticeMode,
        focus: String?,
        title: String,
        sessions: [PracticeSession],
        now: Date
    ) -> CoachSuccessCriterion {
        let (metric, comparator) = caseMetric(mode: mode, focus: focus, title: title)
        let window = caseEvaluationWindow
        let values = followedRepValues(metric: metric, mode: mode, sessions: sessions, now: now)
        // The pre-prescription baseline is everything older than the reps the
        // criterion is judged against, so the bar is "beat where you were",
        // not "beat the very reps being scored". Falls back to a sane default
        // when history is too thin to anchor a number.
        let priorValues = Array(values.dropFirst(window))
        let priorAverage = priorValues.isEmpty
            ? nil
            : priorValues.reduce(0, +) / Double(priorValues.count)

        let threshold: Double
        switch metric {
        case .fillersPerRep:
            threshold = max(0, ((priorAverage ?? 3) - 1).rounded())
        case .sessionScore:
            threshold = min(10, ((priorAverage ?? 6) + 1).rounded())
        case .durationSeconds:
            threshold = (priorAverage ?? 45).rounded()
        }

        return CoachSuccessCriterion(
            metric: metric,
            comparator: comparator,
            threshold: threshold,
            evaluationWindow: window,
            summary: criterionSummary(metric: metric, threshold: threshold, window: window)
        )
    }

    private static func criterionSummary(
        metric: CoachCaseMetric,
        threshold: Double,
        window: Int
    ) -> String {
        let count = Int(threshold)
        let reps = window <= 1 ? "the next rep" : "\(window) reps"
        switch metric {
        case .fillersPerRep:
            let fillers = count == 1 ? "filler" : "fillers"
            return "\(count) or fewer \(fillers) per rep across \(reps)"
        case .sessionScore:
            return "score of \(count) or higher across \(reps)"
        case .durationSeconds:
            return "hold ~\(count)s of structured delivery across \(reps)"
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

        guard latest.followed else {
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
        let status: CoachInterventionReviewStatus
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
            reviewBasis: (summary?.assessment ?? .forming).coachingGuidance
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
            profile.paraphrasedGoal,
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
    }

    func endSession() {
        currentMemory = nil
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
        latestTransferReport: BigMomentOutcomeReport? = nil,
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
            latestTransferReport: latestTransferReport,
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
    func noteReflection(_ summary: String?) {
        guard var memory = currentMemory else { return }
        memory.lastReflectionSummary = summary
        memory.lastReflectionReview = nil
        memory.updatedAt = Date()
        currentMemory = memory
        persist(memory)
    }

    /// Structured late-arriving reflection from the post-rep summary. Keeps
    /// the user's own words and the next review move inside the durable case
    /// immediately, without waiting for the next full memory rebuild.
    func noteReflection(_ reflection: SessionReflection) {
        guard var memory = currentMemory else { return }
        memory.lastReflectionSummary = reflection.coachClause
        memory.lastReflectionReview = CoachReflectionReview(reflection: reflection)
        memory.updatedAt = Date()
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
        at now: Date = Date()
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
        currentMemory = memory
        persist(memory)
    }

    /// Fold a completed real-world check-in into the current case without
    /// changing the measured intervention verdict. The report may motivate a
    /// review question or an adaptation, but it cannot establish causation.
    func noteTransferOutcome(_ report: BigMomentOutcomeReport) {
        guard var memory = currentMemory else { return }
        memory.lastTransferReview = CoachTransferReview(report: report)
        memory.updatedAt = Date()
        currentMemory = memory
        persist(memory)
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

    func clearAll() {
        guard let accountID = accountIDProvider() else {
            currentMemory = nil
            return
        }
        currentMemory = nil
        defaults.removeObject(forKey: storageKey(for: accountID))
    }

    func deleteAllData(for accountID: String) {
        defaults.removeObject(forKey: storageKey(for: accountID))
        if accountIDProvider() == accountID {
            currentMemory = nil
        }
    }

    private func persist(_ memory: CoachMemory) {
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
