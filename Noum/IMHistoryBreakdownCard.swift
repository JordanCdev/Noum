#if canImport(SwiftUI)
import SwiftUI

// MARK: - IMHistoryBreakdownCard
//
// Per-scenario IM track record, rendered on the History screen when
// the user filters to IM Mode. Mirrors `SuddenDeathHistoryBreakdownCard`
// — one card with rows, one row per scenario — adapted for IM's
// per-scenario axis (Social Catch-Up / Work Update / Difficult
// Conversation / Networking).
//
// Each row reads as the row the user would write themselves: how
// many reps, the average score, the average trust + tension they
// left in the final beat, and the best score they hit + when. The
// "trust ↑ / tension ↓" pair is the relational state the engine's
// `IMTurnStateBalancer` produced — it carries the same honesty
// signal as Sudden Death's filler count: it's what actually
// happened, not narrative.
//
// Beneath the stats, a chip row carries the one-glance reads that
// otherwise live a tap deeper on `IMScenarioDetailView`: the
// trust/tension *trend* (which way the relational arc moved across
// reps) and the *tone-match* rate. Both reuse the detail view's pure,
// already-tested helpers so the list and the drill-down never drift,
// and both self-hide on insufficient data rather than fabricate a
// reading.
//
// Self-hides when no IM reps with conversation metadata exist
// (cold start). Mirrors SD + Ah-Counter card pattern: rendering "0
// reps" on the History screen would just be noise.
//
// Vision-aligned (docs/VISION.md pillar #3 — Conversational
// intelligence + pillar #4 — Believable progress): the numbers are
// the engine's. No invented narrative; no AI-generated read.

@available(iOS 17.0, *)
struct IMHistoryBreakdownCard: View {

    let sessions: [PracticeSession]
    /// Tap handler for a scenario row. When `nil`, rows render
    /// read-only. Currently the IM mode doesn't have a per-scenario
    /// drill-down destination (would be a future move alongside the
    /// SD per-difficulty drill-down), but the callback shape is in
    /// place so the row can become interactive without a structural
    /// change later.
    var onSelectScenario: ((IMConversationScenario) -> Void)? = nil

    private var breakdowns: [IMScenarioBreakdown] {
        IMHistorySummary.breakdowns(from: sessions)
    }

    private var isInteractive: Bool { onSelectScenario != nil }

    private var totalRuns: Int {
        IMHistorySummary.totalRunCount(from: sessions)
    }

    private var mostRecent: Date? {
        IMHistorySummary.mostRecentDate(from: sessions)
    }

    private let accent = AppColor.modeIM

    var body: some View {
        if !breakdowns.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                header
                rowsSection
            }
            .padding(Spacing.lg)
            .background(cardBackground)
            .shadow(color: accent.opacity(0.14), radius: 14, x: 0, y: 6)
            .accessibilityIdentifier("history.im.breakdown")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                Text("Conversation history")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(runCountLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let mostRecent {
                Text("Last rep \(mostRecent.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if let best = bestThisWeek {
                bestThisWeekChip(scenario: best.scenario, score: best.score)
            }
        }
    }

    private var bestThisWeek: (session: PracticeSession, scenario: IMConversationScenario, score: Int)? {
        IMHistorySummary.bestThisWeek(from: sessions)
    }

    /// "BEST THIS WEEK · N/10 · <scenario>" capsule. Renders only when
    /// at least one scored rep lives inside the 7-day window. Mirrors
    /// the SD breakdown card's chip — same visual shape, same one-glance
    /// "current peak" read across modes.
    private func bestThisWeekChip(scenario: IMConversationScenario, score: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
                .font(.caption2.weight(.bold))
            Text("Best this week · \(score)/10 · \(scenario.title)")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(accent.opacity(0.12), in: Capsule())
        .accessibilityLabel("Best this week: \(score) of 10 in \(scenario.title).")
        .accessibilityIdentifier("history.im.bestThisWeek")
    }

    private var runCountLabel: String {
        totalRuns == 1 ? "1 rep" : "\(totalRuns) reps"
    }

    // MARK: - Rows

    private var rowsSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(breakdowns.enumerated()), id: \.element.id) { index, breakdown in
                wrappedRow(breakdown)
                if index < breakdowns.count - 1 {
                    Divider()
                        .padding(.vertical, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func wrappedRow(_ breakdown: IMScenarioBreakdown) -> some View {
        if let onSelectScenario {
            Button {
                onSelectScenario(breakdown.scenario)
            } label: {
                breakdownRow(breakdown)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("history.im.row.\(breakdown.scenario.rawValue)")
        } else {
            breakdownRow(breakdown)
                .accessibilityIdentifier("history.im.row.\(breakdown.scenario.rawValue)")
        }
    }

    @ViewBuilder
    private func breakdownRow(_ breakdown: IMScenarioBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(breakdown.scenario.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(rowSubtitle(for: breakdown))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 8)
                statColumn(value: scoreLabel(for: breakdown.averageScore), label: "avg")
                statColumn(value: stateLabel(for: breakdown.averageFinalTrust), label: "trust")
                statColumn(value: stateLabel(for: breakdown.averageFinalTension), label: "tension")
                if isInteractive {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
            }
            chipRow(for: breakdown.scenario)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: breakdown))
    }

    /// Read-at-a-glance chip row beneath the row's stats: the
    /// trust/tension trend chips (the relational arc direction, the
    /// same read the scenario detail header carries) followed by the
    /// tone-match chip. It lives on its own full-width line rather than
    /// crammed into the title column, so up to three small capsules read
    /// clearly side by side without clipping on narrow devices.
    /// Self-hides entirely when the scenario has neither a non-flat
    /// trend (needs ≥4 final-state reps with real movement) nor a
    /// recorded tone — a cold-start scenario adds no empty strip.
    @ViewBuilder
    private func chipRow(for scenario: IMConversationScenario) -> some View {
        let toneStats = toneMatchStats(for: scenario)
        let trend = relationalTrend(for: scenario)
        let showTone = toneStats.evaluatedCount > 0
        let showTrend = trend?.hasSignal == true
        if showTrend || showTone {
            HStack(spacing: 6) {
                if let trend, trend.hasSignal {
                    trendChip(label: "Trust", movement: trend.trust, goodWhenUp: true)
                    trendChip(label: "Tension", movement: trend.tension, goodWhenUp: false)
                }
                if showTone {
                    toneMatchChip(stats: toneStats)
                }
            }
            // The row's combined VoiceOver label already folds in both
            // the trend and the tone read, so the visual chips are hidden
            // from VoiceOver to avoid a double read.
            .accessibilityHidden(true)
        }
    }

    /// Per-scenario relational trend, read from the same pure helper the
    /// scenario detail header uses so the list row and the detail view
    /// never drift on the direction.
    private func relationalTrend(
        for scenario: IMConversationScenario
    ) -> IMHistorySummary.IMScenarioRelationalTrend? {
        IMHistorySummary.relationalTrend(from: sessions, scenario: scenario)
    }

    /// One trust/tension trend chip, mirroring `IMScenarioDetailView`'s
    /// header chips exactly so the two surfaces never read differently.
    /// Self-hides on a flat metric. The arrow shows the *raw* numeric
    /// direction; the tint reads the *value judgment* — `goodWhenUp`
    /// flips the green/amber assignment so trust-up and tension-down both
    /// read green, the reverse amber. Calm capsule register: an amber
    /// chip is informative data, not a punish-shame failure state.
    @ViewBuilder
    private func trendChip(
        label: String,
        movement: IMHistorySummary.IMScenarioRelationalTrend.Movement,
        goodWhenUp: Bool
    ) -> some View {
        if movement != .flat {
            let isUp = movement == .up
            let isGood = (isUp == goodWhenUp)
            let tint = isGood ? AppColor.positive : AppColor.caution
            HStack(spacing: 4) {
                Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.weight(.bold))
                Text(label)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
        }
    }

    /// Per-scenario tone-match stats, read from the same pure helper the
    /// scenario drill-down uses so the list row and the detail view
    /// never drift on the match rate.
    private func toneMatchStats(for scenario: IMConversationScenario) -> IMHistorySummary.IMScenarioToneMatchStats {
        IMHistorySummary.toneMatchStats(from: sessions, scenario: scenario)
    }

    /// Compact "Tone X/Y" chip beneath the row subtitle. Renders only
    /// when the scenario has at least one rep with a recorded
    /// `actualTone` (gated by the caller on `evaluatedCount > 0`), so a
    /// scenario the evaluator never read a tone for shows no chip rather
    /// than a fabricated zero. Calm mode-tinted capsule — it's data, not
    /// a celebration or a penalty, matching the detail view's strip.
    private func toneMatchChip(stats: IMHistorySummary.IMScenarioToneMatchStats) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "target")
                .font(.caption2.weight(.bold))
            Text("Tone \(stats.matchCount)/\(stats.evaluatedCount)")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(accent.opacity(0.12), in: Capsule())
        .accessibilityHidden(true)
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .frame(minWidth: 44, alignment: .center)
    }

    /// Row subtitle pattern:
    ///   • "3 reps · best 9/10 last week" when the user has a best score
    ///   • "3 reps" alone when no rep has been scored yet
    /// Restraint: keep the row read at a glance — never two lines.
    private func rowSubtitle(for breakdown: IMScenarioBreakdown) -> String {
        let runUnit = breakdown.runCount == 1 ? "rep" : "reps"
        let base = "\(breakdown.runCount) \(runUnit)"
        guard let best = breakdown.bestScore else { return base }
        if let bestDate = breakdown.bestScoreDate {
            return "\(base) · best \(best)/10 \(bestDate.formatted(.relative(presentation: .named)))"
        }
        return "\(base) · best \(best)/10"
    }

    private func scoreLabel(for value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }

    private func stateLabel(for value: Double?) -> String {
        guard let value else { return "—" }
        if value == value.rounded() {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    private func accessibilityLabel(for breakdown: IMScenarioBreakdown) -> String {
        let runCopy = breakdown.runCount == 1 ? "1 rep" : "\(breakdown.runCount) reps"
        let scoreCopy = breakdown.averageScore.map { String(format: "average score %.1f", $0) } ?? "no score yet"
        let trustCopy = breakdown.averageFinalTrust.map { String(format: "trust %.1f", $0) } ?? "no trust reading"
        let tensionCopy = breakdown.averageFinalTension.map { String(format: "tension %.1f", $0) } ?? "no tension reading"
        let trendCopy = relationalTrendCopy(for: breakdown.scenario)
        let toneStats = toneMatchStats(for: breakdown.scenario)
        let toneCopy = toneStats.evaluatedCount > 0
            ? ", tone matched \(toneStats.matchCount) of \(toneStats.evaluatedCount) reps"
            : ""
        return "\(breakdown.scenario.title): \(runCopy), \(scoreCopy), \(trustCopy), \(tensionCopy)\(trendCopy)\(toneCopy)"
    }

    /// VoiceOver fragment for the relational trend, folded into the row's
    /// combined label so the visual trend chips stay
    /// `accessibilityHidden`. Empty when there's no non-flat signal
    /// (fewer than 4 final-state reps, or a stable arc) so VoiceOver
    /// never announces a trend the chips aren't showing.
    private func relationalTrendCopy(for scenario: IMConversationScenario) -> String {
        guard let trend = relationalTrend(for: scenario), trend.hasSignal else { return "" }
        var parts: [String] = []
        switch trend.trust {
        case .up: parts.append("trust trending up")
        case .down: parts.append("trust trending down")
        case .flat: break
        }
        switch trend.tension {
        case .up: parts.append("tension trending up")
        case .down: parts.append("tension trending down")
        case .flat: break
        }
        guard !parts.isEmpty else { return "" }
        return ", " + parts.joined(separator: " and ")
    }

    // MARK: - Background

    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        return ZStack {
            shape.fill(AppColor.cardBackground)
            shape.fill(
                RadialGradient(
                    colors: [accent.opacity(0.18), accent.opacity(0.05), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 320
                )
            )
            shape.strokeBorder(accent.opacity(0.25), lineWidth: 1)
        }
    }
}

#endif
