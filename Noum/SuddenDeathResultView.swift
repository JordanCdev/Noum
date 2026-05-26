#if canImport(SwiftUI)
import SwiftUI
import UIKit

// MARK: - Sudden Death Result View

/// Extracted, redesigned result screen for Sudden Death mode.
///
/// Replaces the inline `resultScreen` function in `SuddenDeathPracticeView`.
/// Visual hierarchy prioritises replayable game signals: tier reached,
/// time survived and personal best. Detailed coaching remains in Summary.
@available(iOS 17.0, *)
struct SuddenDeathResultView: View {

    let result: PressureSessionResult
    let highScoreStore: SuddenDeathHighScoreStore
    @ObservedObject var runHistoryStore: SuddenDeathRunHistoryStore
    let onRetry: () -> Void
    let onSeeFullSummary: () -> Void

    // Whether this run set a new high score (resolved once on appear).
    @State private var isNewHighScore: Bool = false
    // Animated rounds counter (rolls from 0 to final).
    @State private var displayedRounds: Int = 0
    // Controls share sheet presentation.
    @State private var showingShareSheet: Bool = false
    // Which payload the share sheet should present — resolved when
    // the user taps a Menu item, read by the sheet builder. Decoupling
    // the kind from the presentation flag means the share sheet always
    // reads a stable value rather than racing the menu close.
    @State private var pendingShareKind: ShareKind = .thisRun
    // Stable record id for the run we just finished — pinned in
    // `resolveHighScore` so the "Recent runs" list can anchor the
    // current row visually even after the same store is re-read
    // following a fast Go-Again.
    @State private var currentRunID: UUID = UUID()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accentColor = AppColor.modeSuddenDeath
    private let visibleTierLimit = 4

    // MARK: - Contextual header

    private var tierReached: Int {
        max(1, result.roundOutcomes.count)
    }

    private var displayedBest: Int {
        max(result.roundsSurvived, result.personalBest)
    }

    private var contextualHeader: String {
        if isNewHighScore {
            return "New Best · \(result.roundsSurvived) cleared"
        }
        return "Tier \(tierReached) Reached"
    }

    private var runEndNote: String {
        switch result.finalOutcome {
        case .survived:
            return "Run cleared"
        case .fillerOverload:
            return "Filler detected · run complete"
        case .timeoutBeforeStart:
            return "Start window expired · run complete"
        case .tooShort:
            return "Response below word target · run complete"
        }
    }

    private var survivalTimeLabel: String {
        let totalSeconds = max(0, Int(result.totalDuration.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return "\(seconds)s"
    }

    // MARK: - Share text

    private var shareText: String {
        let rounds = result.roundsSurvived
        return "Reached Tier \(tierReached) and cleared \(rounds) round\(rounds == 1 ? "" : "s") in \(survivalTimeLabel) on Noum Sudden Death."
    }

    /// Cross-difficulty plain-text dump of every Sudden Death run the
    /// user has recorded. Built lazily from the same store the recent-
    /// runs card reads from. Locked to zero transcript content by the
    /// `SuddenDeathHistoryExportTests` suite — sharing this artifact
    /// never leaks user-authored text, matching the leaderboard rule
    /// from `docs/VISION.md`.
    private var fullHistoryShareText: String {
        SuddenDeathHistoryExport.formatPlainText(runs: runHistoryStore.runs)
    }

    /// Resolved Share-button payload. The menu binds this `State`
    /// just-in-time on tap so the user picks "this run" vs "full
    /// history" without the sheet flickering between values.
    private enum ShareKind { case thisRun, fullHistory }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    outcomeIcon
                    headerBlock
                    if isNewHighScore { newBestBadge }
                    statsRow
                    roundBreakdown
                    SuddenDeathRecentRunsCard(
                        currentRunID: currentRunID,
                        runs: runHistoryStore.recentRuns(difficulty: result.difficulty, limit: 5)
                    )
                    xpChip
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)
            }

            actionButtons
                .padding(.horizontal, Spacing.screenH)
                .padding(.bottom, 24)
        }
        .onAppear { resolveHighScore() }
        .sheet(isPresented: $showingShareSheet) {
            SuddenDeathShareSheet(text: resolvedShareText)
                .ignoresSafeArea()
        }
    }

    /// Picks the right payload at sheet-build time based on which
    /// menu item the user just tapped. Defaults to the run brag —
    /// the original behaviour before the menu landed.
    private var resolvedShareText: String {
        switch pendingShareKind {
        case .thisRun:      return shareText
        case .fullHistory:  return fullHistoryShareText
        }
    }

    // MARK: - Subviews

    private var outcomeIcon: some View {
        let icon = isNewHighScore ? "trophy.fill" : "bolt.fill"
        let tint = isNewHighScore ? Color.yellow : accentColor
        return ZStack {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 80, height: 80)
            Image(systemName: icon)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(tint)
        }
    }

    private var headerBlock: some View {
        VStack(spacing: 4) {
            Text(contextualHeader)
                .font(Typography.bigStat)
                .multilineTextAlignment(.center)
            Text(runEndNote)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var newBestBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow)
            Text("New high score")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
            SparkleRibbon(tint: .yellow, animated: !reduceMotion)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }

    private var statsRow: some View {
        HStack(spacing: 20) {
            statTile(
                value: "\(displayedRounds)",
                label: "Cleared",
                tint: accentColor
            )
            .monospacedDigit()

            statTile(
                value: survivalTimeLabel,
                label: "Survived",
                tint: .primary
            )
            statTile(
                value: "\(displayedBest)",
                label: "Best",
                tint: .yellow
            )
        }
    }

    private var roundBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Run Path")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if hiddenTierCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "ellipsis.circle.fill")
                        .foregroundStyle(accentColor.opacity(0.72))
                        .font(.caption)
                    Text("\(hiddenTierCount) earlier tier\(hiddenTierCount == 1 ? "" : "s")")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text("Cleared")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.positive)
                }
            }

            ForEach(visibleTierEntries, id: \.offset) { entry in
                let outcome = entry.element
                HStack(spacing: 8) {
                    Image(systemName: outcome.isFailed ? "stop.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(outcome.isFailed ? accentColor : AppColor.positive)
                        .font(.caption)
                    Text("Tier \(entry.offset + 1)")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text(roundOutcomeRowLabel(outcome: outcome, index: entry.offset))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(outcome.isFailed ? accentColor : AppColor.positive)
                }
            }
        }
        .padding(Spacing.md)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private var xpChip: some View {
        Text("+\(result.xpEarned) XP")
            .font(.title3.weight(.bold))
            .foregroundStyle(AppColor.brandBlue)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(AppColor.brandBlue.opacity(0.10), in: Capsule())
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline.weight(.bold))
                    Text("Go Again")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(accentColor.gradient, in: Capsule())
            }
            .buttonStyle(.pressable)

            HStack(spacing: 20) {
                shareMenu

                Button(action: onSeeFullSummary) {
                    Text("See Full Summary")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    /// Share affordance with two payloads — the social-friendly run
    /// brag (the original behaviour) and the full plain-text history
    /// the user can paste outside the app. Falls back to a plain Share
    /// button (no menu) when the user has zero recorded runs aside
    /// from this one, since "full history" would just duplicate "this
    /// run" — restraint over redundant choice.
    @ViewBuilder
    private var shareMenu: some View {
        let totalRecordedRuns = runHistoryStore.runs.count
        let hasHistoryToShare = totalRecordedRuns > 1
        let shareLabel = HStack(spacing: 6) {
            Image(systemName: "square.and.arrow.up")
                .font(.subheadline.weight(.semibold))
            Text("Share")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(accentColor)

        if hasHistoryToShare {
            Menu {
                Button {
                    pendingShareKind = .thisRun
                    showingShareSheet = true
                } label: {
                    Label("Share this run", systemImage: "bolt.fill")
                }
                Button {
                    pendingShareKind = .fullHistory
                    showingShareSheet = true
                } label: {
                    Label("Share full history (\(totalRecordedRuns) runs)", systemImage: "list.bullet.rectangle")
                }
            } label: {
                shareLabel
            }
            .accessibilityIdentifier("suddenDeath.result.shareMenu")
            .accessibilityHint("Share this run, or your full Sudden Death track record.")
        } else {
            Button {
                pendingShareKind = .thisRun
                showingShareSheet = true
            } label: {
                shareLabel
            }
            .accessibilityIdentifier("suddenDeath.result.shareButton")
            .accessibilityHint("Share this run.")
        }
    }

    // MARK: - Helpers

    private func statTile(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var visibleTierEntries: [(offset: Int, element: RoundOutcome)] {
        Array(result.roundOutcomes.enumerated().suffix(visibleTierLimit))
    }

    private var hiddenTierCount: Int {
        max(0, result.roundOutcomes.count - visibleTierLimit)
    }

    /// Bounds-checked label for a stopped tier. Legacy sessions predate
    /// per-round word-count arrays, so keep the fallback general.
    private func roundOutcomeRowLabel(outcome: RoundOutcome, index: Int) -> String {
        switch outcome {
        case .survived:
            return "Cleared"
        case .fillerOverload:
            return "Filler detected"
        case .timeoutBeforeStart:
            return "Start window expired"
        case .tooShort:
            guard index < result.wordCountsByRound.count,
                  index < result.minimumWordsByRound.count else {
                return "Below word target"
            }
            let said = result.wordCountsByRound[index]
            let needed = result.minimumWordsByRound[index]
            return "\(said) word\(said == 1 ? "" : "s") · \(needed) needed"
        }
    }

    /// Records the run in the high score store, appends to the per-
    /// account run history, and kicks off the roll-up animation.
    private func resolveHighScore() {
        // Difficulty selection is no longer part of new play. Keep
        // populating the legacy bucket for stored-history compatibility,
        // while the visible best follows the one automatic progression
        // track already shown on the setup screen.
        _ = highScoreStore.recordRun(
            roundsSurvived: result.roundsSurvived,
            difficulty: result.difficulty
        )
        isNewHighScore = result.roundsSurvived > result.personalBest
        // Append the full run to history with the new-best flag
        // snapshotted at recording time. Idempotent on the stable
        // `currentRunID` State so a re-mount within the same lifecycle
        // (Go Again, then back) doesn't double-record.
        let record = SuddenDeathRunRecord(
            id: currentRunID,
            completedAt: Date(),
            difficulty: result.difficulty,
            roundsSurvived: result.roundsSurvived,
            totalFillers: result.totalFillers,
            totalWords: result.totalWords,
            score: result.score,
            xpEarned: result.xpEarned,
            finalOutcome: result.finalOutcome,
            wasNewBestAtTime: isNewHighScore
        )
        runHistoryStore.record(record)
        animateRoundCount()
    }

    private func animateRoundCount() {
        guard !reduceMotion else {
            displayedRounds = result.roundsSurvived
            return
        }
        guard result.roundsSurvived > 0 else {
            displayedRounds = 0
            return
        }
        let target = result.roundsSurvived
        let duration: Double = 0.6
        let stepCount = min(target, 20)
        let stepDelay = duration / Double(stepCount)

        for step in 1...stepCount {
            let progress = Double(step) / Double(stepCount)
            // Ease-out: accelerate early steps, slow the last ones
            let eased = 1 - pow(1 - progress, 2)
            let value = Int(round(eased * Double(target)))
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDelay * Double(step)) {
                displayedRounds = value
            }
        }
    }
}

// MARK: - Share Sheet Bridge

/// Presents a `UIActivityViewController` with plain text via `UIViewControllerRepresentable`.
@available(iOS 17.0, *)
private struct SuddenDeathShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        controller.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .print
        ]
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#endif
