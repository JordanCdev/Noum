#if canImport(SwiftUI)
import SwiftUI

// MARK: - IMScenarioDetailView
//
// Per-scenario drill-down for IM Mode reps. Reached from the
// `IMHistoryBreakdownCard` row tap when the user has the IM filter
// selected on the History screen. Mirrors the shape of
// `SuddenDeathDifficultyRunsView` so the History surface keeps one
// design language across modes:
//   • Mode-tinted summary header — title, rep count, three at-a-glance
//     stat tiles (best score, avg trust, avg tension)
//   • Per-rep row list, newest-first, tap pushes the standard
//     `SessionHistoryDetailView` so the user can drill into full
//     transcript / coach read for any rep
//   • Trailing toolbar ShareLink with a `IMHistoryExport` plain-text
//     dump — same anti-goal contract as the SD export (zero
//     transcripts; only outcome numbers + scenario + target tone)
//
// Honest-data contract: every number here came from the engine at
// finalize. No invented narrative; no AI-generated read.
//
// Vision-aligned (docs/VISION.md pillar #3 — Conversational
// intelligence + pillar #4 — Believable progress + anti-goals): the
// surface lets the user browse their own track record at one
// scenario, the way a £130/hr human coach would pull up "your last
// ten Difficult Conversation reps."

@available(iOS 17.0, *)
struct IMScenarioDetailView: View {

    let scenario: IMConversationScenario
    @Binding var navigationPath: NavigationPath
    @StateObject private var sessionStore = PracticeSessionStore.shared

    /// Reps filtered to this scenario, newest-first. Defensive re-sort
    /// so the view doesn't depend on `PracticeSessionStore`'s invariant.
    private var reps: [PracticeSession] {
        sessionStore.sessions
            .filter { session in
                session.mode == .imConversation
                    && session.imConversationDetails?.setup.scenario == scenario
            }
            .sorted { $0.date > $1.date }
    }

    /// Pure summary read from the shared helper so the drill-down and
    /// the breakdown card never drift on the math.
    private var breakdown: IMScenarioBreakdown? {
        IMHistorySummary.breakdowns(from: sessionStore.sessions).first {
            $0.scenario == scenario
        }
    }

    private var exportText: String {
        IMHistoryExport.formatPlainText(sessions: sessionStore.sessions, scenario: scenario)
    }

    private let accent = AppColor.modeIM

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            if reps.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        summaryHeader
                            .padding(.horizontal, Spacing.screenH)
                            .padding(.top, 8)

                        repsList
                            .padding(.horizontal, Spacing.screenH)

                        Spacer(minLength: 32)
                    }
                }
            }
        }
        .navigationTitle("IM · \(scenario.title)")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("history.im.scenarioDetail")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !reps.isEmpty {
                    ShareLink(item: exportText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share scenario history")
                    .accessibilityIdentifier("history.im.scenario.export")
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No \(scenario.title) reps yet")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Finish an IM rep in this scenario to start a track record.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                Text(scenario.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(reps.count) rep\(reps.count == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(scenario.summary)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
            HStack(spacing: 18) {
                summaryStat(value: bestScoreLabel, label: "Best")
                summaryStat(value: averageTrustLabel, label: "Avg trust")
                summaryStat(value: averageTensionLabel, label: "Avg tension")
            }
        }
        .padding(Spacing.lg)
        .background(cardBackground)
        .shadow(color: accent.opacity(0.12), radius: 12, x: 0, y: 5)
    }

    private var bestScoreLabel: String {
        guard let best = breakdown?.bestScore else { return "—" }
        return "\(best)/10"
    }

    private var averageTrustLabel: String {
        guard let value = breakdown?.averageFinalTrust else { return "—" }
        return formatScalar(value)
    }

    private var averageTensionLabel: String {
        guard let value = breakdown?.averageFinalTension else { return "—" }
        return formatScalar(value)
    }

    private func formatScalar(_ value: Double) -> String {
        if value == value.rounded() {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
        }
    }

    // MARK: - Run list

    private var repsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(reps.enumerated()), id: \.element.id) { index, session in
                Button {
                    navigationPath.append(AppDestination.sessionDetail(sessionID: session.id))
                } label: {
                    repRow(session: session)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("history.im.scenario.row.\(session.id.uuidString)")

                if index < reps.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func repRow(session: PracticeSession) -> some View {
        HStack(spacing: 12) {
            let isTopScore = session.score != nil && session.score == breakdown?.bestScore
            Image(systemName: isTopScore ? "trophy.fill" : "bubble.left.and.bubble.right")
                .font(.subheadline)
                .foregroundStyle(isTopScore ? .yellow : accent.opacity(0.85))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.score.map { "\($0)/10" } ?? "—")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    if let tone = session.imConversationDetails?.setup.targetTone {
                        Text(tone.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(accent.opacity(0.12), in: Capsule())
                    }
                }
                Text(absoluteDateLabel(session.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 14) {
                relationalChip(
                    value: session.imConversationDetails?.finalState.map { "\($0.normalizedTrust)" } ?? "—",
                    label: "trust",
                    tint: .teal
                )
                relationalChip(
                    value: session.imConversationDetails?.finalState.map { "\($0.normalizedTension)" } ?? "—",
                    label: "tension",
                    tint: .orange
                )
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.leading, 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: session))
    }

    private func relationalChip(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func absoluteDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func accessibilityLabel(for session: PracticeSession) -> String {
        let score = session.score.map { "score \($0) of 10" } ?? "no score recorded"
        let trust = session.imConversationDetails?.finalState.map { "trust \($0.normalizedTrust)" } ?? "no trust reading"
        let tension = session.imConversationDetails?.finalState.map { "tension \($0.normalizedTension)" } ?? "no tension reading"
        return "\(scenario.title) rep, \(score), \(trust), \(tension)"
    }

    // MARK: - Background

    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        return ZStack {
            shape.fill(AppColor.cardBackground)
            shape.fill(
                RadialGradient(
                    colors: [accent.opacity(0.16), accent.opacity(0.04), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 280
                )
            )
            shape.strokeBorder(accent.opacity(0.22), lineWidth: 1)
        }
    }
}

#endif
