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
                Text("IM history")
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
        }
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
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: breakdown))
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
        return "\(breakdown.scenario.title): \(runCopy), \(scoreCopy), \(trustCopy), \(tensionCopy)"
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
