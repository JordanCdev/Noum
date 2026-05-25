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

    // Adaptation history — the bounded record of explained course-changes
    // (the "reason for changing course" the case formulation needs).
    // Optional for backward compat; memories persisted before the case file
    // decode without this key.
    var adaptationLog: [CoachCourseChange]?

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
        adaptationLog: [CoachCourseChange]? = nil,
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
        self.adaptationLog = adaptationLog
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
        case adaptationLog
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
        adaptationLog = try c.decodeIfPresent([CoachCourseChange].self, forKey: .adaptationLog)
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

        let previousLever: SkillArea?
        let focusShiftedAt: Date?
        var adaptationLog = previous?.adaptationLog ?? []
        if let prior = previous?.currentLever,
           let currentLever,
           prior != currentLever {
            previousLever = prior
            focusShiftedAt = now
            adaptationLog.append(
                CoachCourseChange(
                    id: UUID(),
                    changedAt: now,
                    fromLever: prior,
                    toLever: currentLever,
                    reason: "Shifted focus from \(prior.displayName) to \(currentLever.displayName).",
                    evidenceBasis: lever?.basis ?? "updated read across recent reps"
                )
            )
            adaptationLog = Array(adaptationLog.suffix(8))
        } else {
            previousLever = previous?.previousLever
            focusShiftedAt = previous?.focusShiftedAt
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
            workingHypothesis: workingHypothesis(
                lever: lever,
                evidenceConfidence: evidenceConfidence
            ),
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
            now: now,
            calendar: calendar
        ) else { return }
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
