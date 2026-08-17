import Foundation

// MARK: - V4.6 Slice 3 presentation resolvers
//
// Pure, view-free projections for the Progress evidence head (258:1131) and
// the Updated Today earned state (258:1078). Every line they emit is derived
// from the recommendation ledger's comparable evidence — never from activity
// counts — and every clause self-suppresses when its datum is absent.

/// One evidence row on Progress: a day label plus one bounded outcome line.
struct V46EvidenceRow: Equatable, Identifiable {
    enum Tone: Equatable {
        case held
        case lapse
        case neutral
    }

    let id: UUID
    let dayLabel: String
    let copy: String
    let tone: Tone
}

/// One day cluster in the weekly trajectory. Intensity scales the cluster's
/// bar heights (1.0 = strongest); lapse days carry the amber label and are
/// always paired with the row's text cue — never colour alone.
struct V46TrajectoryDay: Equatable {
    let label: String
    let intensity: Double
    let isLapse: Bool
}

/// Visual register for the Progress coach read. This is deliberately derived
/// from the same comparable-retry floor as the visible claim: the waveform may
/// enter its earned state only after at least three comparable reps with a
/// three-in-four hold rate. Activity alone can never produce an earned hero.
enum V46ProgressReadStage: Equatable {
    case early
    case forming
    case reliable
}

/// Content-free identity for the one target represented by the Progress
/// cohort. The actual prompt remains owned by `PracticeSessionStore` and only
/// enters the existing process-local Timed Practice handoff at tap time.
struct V46ProgressPracticeTarget: Equatable {
    let outcomeID: UUID
    let sourceSessionID: UUID
    let lever: TranscriptPracticeLever
    let fingerprint: String
    let targetDimensionID: String?
    let goal: SpeakingStyleGoal?
}

/// A route-ready, prompt-backed projection for "Practice this target". It
/// fails closed when the cohort's exact latest row is absent, below the shared
/// evidence floor, or has no original prompt to repeat.
struct V46ProgressPracticeProjection: Equatable {
    let sourceSessionID: UUID
    let suggestedPrompt: String
    let title: String
    let focus: String
    let target: String
    let targetDimensionID: String?
    let goal: SpeakingStyleGoal?
    let retryTarget: TranscriptRetryTarget

    static func make(
        target: V46ProgressPracticeTarget,
        sessions: [PracticeSession]
    ) -> V46ProgressPracticeProjection? {
        guard let source = sessions.first(where: { $0.id == target.sourceSessionID }),
              PracticeProgressEligibility.qualifies(source),
              let prompt = clean(source.prompt) else {
            return nil
        }
        let retryTarget = TranscriptRetryTarget(lever: target.lever)
        guard retryTarget.isSupported else { return nil }
        return V46ProgressPracticeProjection(
            sourceSessionID: source.id,
            suggestedPrompt: prompt,
            title: "Practice \(target.lever.focusLabel)",
            focus: target.lever.focusLabel,
            target: target.lever.successMeasure,
            targetDimensionID: target.targetDimensionID,
            goal: target.goal,
            retryTarget: retryTarget
        )
    }

    func prescription(correlationID: UUID) -> TranscriptPracticePrescription {
        TranscriptPracticePrescription(
            correlationID: correlationID,
            sourceSessionID: sourceSessionID,
            suggestedPrompt: suggestedPrompt,
            title: title,
            focus: focus,
            target: target,
            targetDimensionID: targetDimensionID,
            goal: goal,
            retryTarget: retryTarget
        )
    }

    private static func clean(_ source: String?) -> String? {
        guard let trimmed = source?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

/// The Progress head: what is becoming reliable, the honest tally, up to
/// four trajectory days, up to three evidence rows, and one plan-review row.
struct V46ProgressPresentation: Equatable {
    let readStage: V46ProgressReadStage
    /// Authored card eyebrow with the exact comparable depth represented.
    let coachReadEyebrow: String
    let eyebrow: String
    let headline: String
    /// Lever-specific headline used by the authored coach-read card. The
    /// legacy bounded class above stays available for existing consumers.
    let authoredHeadline: String
    let subtitle: String
    /// Compact receipt values from this exact cohort, never global activity.
    let evidenceValue: String
    let evidenceLabel: String
    /// The next observable behavior, derived from the represented lever.
    let nextFocus: String
    let trajectory: [V46TrajectoryDay]
    let rows: [V46EvidenceRow]
    /// "Review this target — due now" / "Review this target Friday"; nil
    /// when no real review date exists.
    let reviewRowTitle: String?
    let reviewIsDue: Bool
    /// Spoken summary for the whole chart (rows read individually).
    let chartAccessibilitySummary: String
    /// The exact latest row and lever represented by every number and row in
    /// this presentation. The view resolves it against session history before
    /// offering a practice route.
    let practiceTarget: V46ProgressPracticeTarget

    /// Comparable-evidence window and floors. One rep renders an early read;
    /// three comparable reps unlock a reliability claim. Nothing renders with
    /// zero comparable evidence — the caller falls back to the legacy story.
    static func make(
        outcomes: [RecommendationOutcome],
        intervention: CoachIntervention?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> V46ProgressPresentation? {
        let windowStart = now.addingTimeInterval(-14 * 24 * 3600)
        let candidates = outcomes
            .filter { $0.completedAt >= windowStart && $0.completedAt <= now }
            .compactMap(Self.validatedCohortMember)
            .sorted { $0.outcome.completedAt < $1.outcome.completedAt }
        guard let latest = candidates.last else { return nil }
        let cohortLever = latest.lever

        // One target owns the whole read. A closing retry can never inflate an
        // opening tally (or vice versa), even if both happened this week.
        let comparable = candidates
            .filter { $0.lever == cohortLever }
            .suffix(6)
        guard !comparable.isEmpty else { return nil }
        let comparableOutcomes = comparable.map(\.outcome)

        let results = comparableOutcomes.compactMap { $0.transcriptRetryComparison?.result }
        let holds = results.filter { $0 == .improved || $0 == .held }.count
        // No `lapses` count here: the lapse read is derived per-row further
        // down from `group.allRegressed`, so a second tally was dead weight
        // rather than a dropped signal.
        let tally = results.count

        let eyebrow = cohortLever.focusLabel.uppercased()

        let readStage: V46ProgressReadStage
        let headline: String
        if tally >= 3, Double(holds) / Double(tally) >= 0.75 {
            readStage = .reliable
            headline = "Becoming reliable."
        } else if tally >= 3 {
            readStage = .forming
            headline = "Not yet steady."
        } else {
            readStage = .early
            headline = "Early read."
        }

        let repNoun = tally == 1 ? "rep" : "reps"
        let coachReadEyebrow = "COACH READ \u{00B7} LAST \(tally) \(repNoun.uppercased())"
        let authoredHeadline = Self.authoredHeadline(
            lever: cohortLever,
            stage: readStage
        )

        let pressureHoldCount = comparableOutcomes.filter {
            guard let result = $0.transcriptRetryComparison?.result,
                  result == .improved || result == .held else { return false }
            return Self.isPressureDemand($0.executedDemand)
        }.count

        var subtitle = "Held in \(holds) of \(tally) comparable rep\(tally == 1 ? "" : "s")"
        if pressureHoldCount == 1 {
            subtitle += " \u{2014} one under pressure."
        } else if pressureHoldCount > 1 {
            subtitle += " \u{2014} \(pressureHoldCount) under pressure."
        } else {
            subtitle += "."
        }
        if tally < 3 {
            subtitle += " Noum needs \(3 - tally) more for a reliable read."
        }

        let dayGroups = Self.dayGroups(comparable: comparableOutcomes, now: now, calendar: calendar)
        let trajectory = dayGroups.suffix(4).map { group in
            V46TrajectoryDay(
                label: group.label,
                intensity: group.bestIsImproved ? 1.0 : (group.allRegressed ? 0.45 : 0.8),
                isLapse: group.allRegressed
            )
        }
        let rows = dayGroups.suffix(3).map { group -> V46EvidenceRow in
            V46EvidenceRow(
                id: group.newestOutcomeID,
                dayLabel: group.label,
                copy: group.rowCopy,
                tone: group.allRegressed ? .lapse : (group.bestIsImproved || group.anyHeld ? .held : .neutral)
            )
        }

        var reviewTitle: String?
        var reviewIsDue = false
        if let intervention, let due = intervention.reviewDueAt {
            if intervention.isReviewDue(at: now) {
                reviewTitle = "Review this target \u{2014} due now"
                reviewIsDue = true
            } else if due > now, due.timeIntervalSince(now) <= 7 * 24 * 3600 {
                let formatter = DateFormatter()
                formatter.calendar = calendar
                formatter.dateFormat = "EEEE"
                reviewTitle = "Review this target \(formatter.string(from: due))"
            }
        }

        let daysDescribed = trajectory.count
        let chartSummary = "\(daysDescribed) comparable practice day\(daysDescribed == 1 ? "" : "s") shown \u{2014} held \(holds) of \(tally)\(pressureHoldCount > 0 ? ", including under pressure" : "")."

        return V46ProgressPresentation(
            readStage: readStage,
            coachReadEyebrow: coachReadEyebrow,
            eyebrow: eyebrow,
            headline: headline,
            authoredHeadline: authoredHeadline,
            subtitle: subtitle,
            evidenceValue: "\(holds) / \(tally)",
            evidenceLabel: "\(cohortLever.focusLabel) held",
            nextFocus: cohortLever.successMeasure,
            trajectory: Array(trajectory),
            rows: Array(rows),
            reviewRowTitle: reviewTitle,
            reviewIsDue: reviewIsDue,
            chartAccessibilitySummary: chartSummary,
            practiceTarget: V46ProgressPracticeTarget(
                outcomeID: latest.outcome.id,
                sourceSessionID: latest.sourceSessionID,
                lever: cohortLever,
                fingerprint: latest.outcome.fingerprint,
                targetDimensionID: latest.outcome.targetDimensionID,
                goal: latest.outcome.goal
            )
        )
    }

    private static func authoredHeadline(
        lever: TranscriptPracticeLever,
        stage: V46ProgressReadStage
    ) -> String {
        let subject: String
        switch lever {
        case .opening: subject = "Your opening"
        case .closing: subject = "Your close"
        case .structure: subject = "Your structure"
        case .concise: subject = "Your concise delivery"
        }

        switch stage {
        case .reliable:
            return "\(subject) is becoming reliable."
        case .forming:
            return "\(subject) is not steady yet."
        case .early:
            return "An early read on \(subject.lowercased())."
        }
    }

    private struct CohortMember {
        let outcome: RecommendationOutcome
        let lever: TranscriptPracticeLever
        let sourceSessionID: UUID
    }

    /// Validates the persisted source → retry join before the outcome may
    /// enter either the chart or a new practice route. A mismatched legacy row
    /// fails closed instead of borrowing the latest session's prompt.
    private static func validatedCohortMember(
        _ outcome: RecommendationOutcome
    ) -> CohortMember? {
        guard let target = outcome.transcriptRetryTarget,
              target.isSupported,
              let comparison = outcome.transcriptRetryComparison,
              comparison.isComparable,
              comparison.lever == target.lever,
              comparison.retrySessionID == outcome.sessionID else {
            return nil
        }
        if let recordedSource = outcome.sourceSessionID,
           recordedSource != comparison.sourceSessionID {
            return nil
        }
        return CohortMember(
            outcome: outcome,
            lever: target.lever,
            sourceSessionID: comparison.sourceSessionID
        )
    }

    private static func isPressureDemand(_ demand: PracticeSessionDemand?) -> Bool {
        guard let difficulty = demand?.timedDifficulty else { return false }
        return difficulty == .medium || difficulty == .hard
    }

    // MARK: Day grouping

    private struct DayGroup {
        let label: String
        let newestOutcomeID: UUID
        let bestIsImproved: Bool
        let anyHeld: Bool
        let allRegressed: Bool
        let rowCopy: String
    }

    private static func dayGroups(
        comparable: [RecommendationOutcome],
        now: Date,
        calendar: Calendar
    ) -> [DayGroup] {
        let grouped = Dictionary(grouping: comparable) {
            calendar.startOfDay(for: $0.completedAt)
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "EEE"

        return grouped.keys.sorted().map { day in
            let dayOutcomes = grouped[day] ?? []
            let results = dayOutcomes.compactMap { $0.transcriptRetryComparison?.result }
            let improved = results.contains(.improved)
            let held = results.contains(.held)
            let allRegressed = !results.isEmpty && results.allSatisfy { $0 == .regressed }
            let isToday = calendar.isDate(day, inSameDayAs: now)
            let label = isToday ? "TODAY" : formatter.string(from: day).uppercased()
            let newest = dayOutcomes.max { $0.completedAt < $1.completedAt }

            let underPressure = dayOutcomes.contains {
                Self.isPressureDemand($0.executedDemand)
            }
            let lever = newest?.transcriptRetryTarget?.lever
            let copy = Self.rowCopy(
                improved: improved,
                held: held,
                allRegressed: allRegressed,
                underPressure: underPressure,
                isToday: isToday,
                lever: lever
            )

            return DayGroup(
                label: label,
                newestOutcomeID: newest?.id ?? UUID(),
                bestIsImproved: improved,
                anyHeld: held,
                allRegressed: allRegressed,
                rowCopy: copy
            )
        }
    }

    private static func rowCopy(
        improved: Bool,
        held: Bool,
        allRegressed: Bool,
        underPressure: Bool,
        isToday: Bool,
        lever: TranscriptPracticeLever?
    ) -> String {
        if allRegressed {
            let failure = lever == .opening
                ? "the wind-up came back"
                : "the first try read stronger"
            return underPressure
                ? "Didn't hold under time pressure \u{2014} \(failure)"
                : "Didn't hold this time \u{2014} \(failure)"
        }
        if improved {
            var copy = "Held"
            if underPressure { copy += " under pressure" }
            if isToday { copy += " \u{2014} on the retry" }
            else if let lever { copy += " \u{2014} \(lever.focusLabel)" }
            return copy
        }
        if held {
            return "Held again \u{2014} steady"
        }
        return "Not comparable \u{2014} the conditions changed"
    }
}

// MARK: - Earned-evidence acknowledgement ledger

/// Per-account persistence for the once-per-evidence-event contract:
/// the hero announces an earned outcome exactly once (acknowledged on
/// first render), and the compact receipt that replaces it on later
/// visits can be dismissed once. Bounded to the last 24 events; keys are
/// registered with `AccountDataRegistry` ("v46-earned-evidence").
enum V46EarnedEvidenceLedger {
    static let ackKeyPrefix = "v46.earnedAck."
    static let receiptKeyPrefix = "v46.earnedReceiptDismissed."
    private static let capacity = 24

    static func acknowledgedIDs(accountID: String?) -> Set<UUID> {
        Set(ackDates(accountID: accountID).keys)
    }

    /// Acknowledgement timestamps — the compact receipt waits for a later
    /// visit (the announcement and the collapsed signal never co-present).
    static func ackDates(accountID: String?) -> [UUID: Date] {
        let raw = UserDefaults.standard.dictionary(forKey: key(ackKeyPrefix, accountID)) as? [String: Date]
            ?? [:]
        return Dictionary(uniqueKeysWithValues: raw.compactMap { pair in
            UUID(uuidString: pair.key).map { ($0, pair.value) }
        })
    }

    static func acknowledge(_ id: UUID, accountID: String?, now: Date = Date()) {
        var dates = ackDates(accountID: accountID)
        guard dates[id] == nil else { return }
        dates[id] = now
        let bounded = dates.sorted { $0.value > $1.value }.prefix(capacity)
        let raw = Dictionary(uniqueKeysWithValues: bounded.map { ($0.key.uuidString, $0.value) })
        UserDefaults.standard.set(raw, forKey: key(ackKeyPrefix, accountID))
    }

    static func receiptDismissedIDs(accountID: String?) -> Set<UUID> {
        let raw = UserDefaults.standard.stringArray(forKey: key(receiptKeyPrefix, accountID)) ?? []
        return Set(raw.compactMap(UUID.init(uuidString:)))
    }

    static func dismissReceipt(_ id: UUID, accountID: String?) {
        var ids = receiptDismissedIDs(accountID: accountID)
        ids.insert(id)
        let bounded = Array(ids.map(\.uuidString).suffix(capacity))
        UserDefaults.standard.set(bounded, forKey: key(receiptKeyPrefix, accountID))
    }

    private static func key(_ prefix: String, _ accountID: String?) -> String {
        prefix + (accountID ?? "guest")
    }
}

// MARK: - Updated Today (258:1078)

/// The earned state Today shows once per evidence event: an un-acknowledged
/// held/improved retry comparison from the last 36 hours. When the next
/// prescription genuinely tightened the clock, the hero re-speaks around
/// that; otherwise only the chip + earned trace differentiate the hero.
struct V46EarnedTodayPresentation: Equatable {
    let outcomeID: UUID
    let chipText: String
    /// Override headline; nil keeps the ordinary coach title.
    let headlineOverride: String?
    /// Override meta line; nil keeps the ordinary meta clauses.
    let metaOverride: String?
    /// Override CTA title; nil keeps the ordinary Start label.
    let ctaOverride: String?

    static func make(
        outcomes: [RecommendationOutcome],
        suggestedNextDifficulty: TimedPracticeDifficulty?,
        acknowledgedOutcomeIDs: Set<UUID>,
        now: Date = Date()
    ) -> V46EarnedTodayPresentation? {
        let windowStart = now.addingTimeInterval(-36 * 3600)
        guard let earned = outcomes
            .filter({ outcome in
                guard let result = outcome.transcriptRetryComparison?.result else { return false }
                return (result == .improved || result == .held)
                    && outcome.completedAt >= windowStart
                    && outcome.completedAt <= now
                    && !acknowledgedOutcomeIDs.contains(outcome.id)
            })
            .max(by: { $0.completedAt < $1.completedAt })
        else { return nil }

        let chip = "New evidence \u{00B7} from your retry"

        // "Shorter clock" only when the clock genuinely tightened: the rep
        // ran on a longer answer clock than the plan now prescribes.
        if let executedDifficulty = earned.executedDemand?.timedDifficulty,
           let executedSeconds = executedDifficulty.duration,
           let next = suggestedNextDifficulty,
           let nextSeconds = next.duration,
           nextSeconds < executedSeconds {
            return V46EarnedTodayPresentation(
                outcomeID: earned.id,
                chipText: chip,
                headlineOverride: "Same target \u{2014} shorter clock.",
                metaOverride: "Plan moved \u{00B7} \(nextSeconds)s answer clock",
                ctaOverride: "Start the shorter clock"
            )
        }

        return V46EarnedTodayPresentation(
            outcomeID: earned.id,
            chipText: chip,
            headlineOverride: nil,
            metaOverride: nil,
            ctaOverride: nil
        )
    }
}
