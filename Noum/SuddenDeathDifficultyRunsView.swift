#if canImport(SwiftUI)
import SwiftUI

// MARK: - SuddenDeathDifficultyRunsView
//
// Per-difficulty drill-down for Sudden Death runs. Reached from the
// breakdown card on `SessionHistoryView` when the user filters to
// Sudden Death and taps a difficulty row. Renders every run at that
// difficulty (not just the 5 visible on the per-run Result screen),
// sorted newest-first, plus a `ShareLink` export so the user can
// hold the data outside the app.
//
// Honest-data contract: each row is one record the engine wrote at
// finalize. No invented stats, no narrative, no coach voice. Mirrors
// the `SuddenDeathRecentRunsCard` row vocabulary so the user reads
// the same shape on Result and here.
//
// Vision-aligned (docs/VISION.md pillar #4 — Believable progress):
// the user owns their track record; this surface lets them browse
// the long tail of it. Anti-goal-compliant: export contains zero
// transcripts.

@available(iOS 17.0, *)
struct SuddenDeathDifficultyRunsView: View {

    let difficulty: SuddenDeathDifficulty
    @StateObject private var runHistoryStore = SuddenDeathRunHistoryStore.shared

    private var runs: [SuddenDeathRunRecord] {
        // Store is already sorted newest-first; defensive re-sort
        // here so the view doesn't depend on the store's invariant.
        runHistoryStore
            .recentRuns(difficulty: difficulty)
            .sorted { $0.completedAt > $1.completedAt }
    }

    private var exportText: String {
        SuddenDeathHistoryExport.formatPlainText(
            runs: runHistoryStore.runs,
            difficulty: difficulty
        )
    }

    private var bestRounds: Int {
        runs.map(\.roundsSurvived).max() ?? 0
    }

    private var cleanRunCount: Int {
        runs.reduce(0) { $0 + ($1.totalFillers == 0 ? 1 : 0) }
    }

    private let accent = AppColor.modeSuddenDeath

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            if runs.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        summaryHeader
                            .padding(.horizontal, Spacing.screenH)
                            .padding(.top, 8)

                        runsList
                            .padding(.horizontal, Spacing.screenH)

                        Spacer(minLength: 32)
                    }
                }
            }
        }
        .navigationTitle("Pressure Drill · \(difficulty.title)")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("history.suddenDeath.difficultyDetail")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !runs.isEmpty {
                    ShareLink(item: exportText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share run history")
                    .accessibilityIdentifier("history.suddenDeath.export")
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No \(difficulty.title) runs yet")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Finish a Pressure Drill rep at this difficulty to start a track record.")
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
                Image(systemName: "bolt.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                Text(difficulty.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(runs.count) run\(runs.count == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 18) {
                summaryStat(value: "\(bestRounds)", label: "Best")
                summaryStat(value: "\(cleanRunCount)", label: "Clean")
                summaryStat(value: avgLabel, label: "Avg")
            }
        }
        .padding(Spacing.lg)
        .background(cardBackground)
        .shadow(color: accent.opacity(0.12), radius: 12, x: 0, y: 5)
    }

    private var avgLabel: String {
        guard !runs.isEmpty else { return "0" }
        let total = runs.reduce(0) { $0 + $1.roundsSurvived }
        let avg = Double(total) / Double(runs.count)
        if avg == avg.rounded() {
            return "\(Int(avg.rounded()))"
        }
        return String(format: "%.1f", (avg * 10).rounded() / 10)
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
        }
    }

    // MARK: - Run list

    private var runsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(runs.enumerated()), id: \.element.id) { index, run in
                runRow(run: run)
                    .padding(.vertical, 12)
                if index < runs.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func runRow(run: SuddenDeathRunRecord) -> some View {
        let tier = max(1, run.roundsSurvived + (run.finalOutcome.isFailed ? 1 : 0))
        return HStack(spacing: 12) {
            Image(systemName: run.wasNewBestAtTime ? "trophy.fill" : "bolt.fill")
                .font(.subheadline)
                .foregroundStyle(run.wasNewBestAtTime ? Color.yellow : accent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Tier \(tier)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if run.wasNewBestAtTime {
                        bestBadge
                    }
                }
                Text(absoluteDateLabel(run.completedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if run.gamePoints > 0 {
                Text("\(run.gamePoints.formatted()) pts")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(accent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: run))
    }

    private var bestBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "trophy.fill")
                .font(.caption2.weight(.bold))
            Text("BEST")
                .font(.caption2.weight(.bold))
                .tracking(0.4)
        }
        .foregroundStyle(.yellow)
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(Color.yellow.opacity(0.12), in: Capsule())
    }

    // MARK: - Helpers

    private func absoluteDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func accessibilityLabel(for run: SuddenDeathRunRecord) -> String {
        let tier = max(1, run.roundsSurvived + (run.finalOutcome.isFailed ? 1 : 0))
        let outcome = SuddenDeathHistoryExport.outcomeLabel(run.finalOutcome)
        let bestPart = run.wasNewBestAtTime ? ", new best" : ""
        let pointsPart = run.gamePoints > 0 ? ", \(run.gamePoints) points" : ""
        return "Tier \(tier), \(outcome.lowercased())\(pointsPart)\(bestPart)"
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
