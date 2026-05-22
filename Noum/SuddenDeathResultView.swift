#if canImport(SwiftUI)
import SwiftUI
import UIKit

// MARK: - Sudden Death Result View

/// Extracted, redesigned result screen for Sudden Death mode.
///
/// Replaces the inline `resultScreen` function in `SuddenDeathPracticeView`.
/// Visual hierarchy:
///   1. Contextual run header (not the difficulty name)
///   2. Icon tinted to outcome
///   3. Number roll-up on rounds survived (dopamine beat)
///   4. "New Best!" badge when high score is beaten
///   5. Stats row (rounds / fillers / score)
///   6. Round-by-round breakdown
///   7. XP chip (readable size)
///   8. Share + action buttons
@available(iOS 17.0, *)
struct SuddenDeathResultView: View {

    let result: PressureSessionResult
    let highScoreStore: SuddenDeathHighScoreStore
    let onRetry: () -> Void
    let onSeeFullSummary: () -> Void

    // Whether this run set a new high score (resolved once on appear).
    @State private var isNewHighScore: Bool = false
    // Animated rounds counter (rolls from 0 to final).
    @State private var displayedRounds: Int = 0
    // Controls share sheet presentation.
    @State private var showingShareSheet: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accentColor = AppColor.modeSuddenDeath

    // MARK: - Contextual header

    /// Replaces the generic `resultLabel` (which was the difficulty-mapped
    /// outcome description) with a run-specific headline.
    private var contextualHeader: String {
        if isNewHighScore {
            return "New Best · \(result.roundsSurvived) round\(result.roundsSurvived == 1 ? "" : "s")"
        }
        if result.roundsSurvived > 0 && result.finalOutcome == .survived {
            // Completed all offered rounds with no failure
            if result.totalFillers == 0 {
                return "Clean Run · \(result.roundsSurvived) round\(result.roundsSurvived == 1 ? "" : "s")"
            }
            return "Survived · \(result.roundsSurvived) round\(result.roundsSurvived == 1 ? "" : "s")"
        }
        // Eliminated
        return "Eliminated · Round \(result.roundsSurvived + 1)"
    }

    // MARK: - Share text

    private var shareText: String {
        let difficultyName = result.difficulty.title
        let rounds = result.roundsSurvived
        let fillers = result.totalFillers
        if fillers == 0 {
            return "Survived \(rounds) round\(rounds == 1 ? "" : "s") in Noum Sudden Death (\(difficultyName)) with zero filler words."
        }
        return "Survived \(rounds) round\(rounds == 1 ? "" : "s") in Noum Sudden Death (\(difficultyName))."
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                outcomeIcon
                headerBlock
                if isNewHighScore { newBestBadge }
                statsRow
                roundBreakdown
                xpChip
            }
            .padding(.horizontal, Spacing.screenH)

            Spacer()

            actionButtons
                .padding(.horizontal, Spacing.screenH)
                .padding(.bottom, 24)
        }
        .onAppear { resolveHighScore() }
        .sheet(isPresented: $showingShareSheet) {
            SuddenDeathShareSheet(text: shareText)
                .ignoresSafeArea()
        }
    }

    // MARK: - Subviews

    private var outcomeIcon: some View {
        ZStack {
            Circle()
                .fill(result.resultTint.opacity(0.12))
                .frame(width: 80, height: 80)
            Image(systemName: result.resultIcon)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(result.resultTint)
        }
    }

    private var headerBlock: some View {
        VStack(spacing: 4) {
            Text(contextualHeader)
                .font(Typography.bigStat)
                .multilineTextAlignment(.center)
            // Difficulty as the subtitle — where it belongs
            Text(result.difficulty.title)
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
                label: "Rounds",
                tint: .green
            )
            .monospacedDigit()

            statTile(
                value: "\(result.totalFillers)",
                label: "Fillers",
                tint: result.totalFillers == 0 ? .green : .red
            )
            statTile(
                value: "\(result.score)/10",
                label: "Score",
                tint: .blue
            )
        }
    }

    private var roundBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rounds")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(Array(result.roundOutcomes.enumerated()), id: \.offset) { index, outcome in
                HStack(spacing: 8) {
                    Image(systemName: outcome.isFailed ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(outcome.isFailed ? .red : .green)
                        .font(.caption)
                    Text("Round \(index + 1)")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text(roundOutcomeRowLabel(outcome: outcome, index: index))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(outcome.isFailed ? .red : .green)
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
                Button {
                    showingShareSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                        Text("Share")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(accentColor)
                }

                Button(action: onSeeFullSummary) {
                    Text("See Full Summary")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
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

    /// Bounds-checked label for a round outcome row. Legacy sessions predate
    /// per-round word-count arrays; falls back to the enum label.
    private func roundOutcomeRowLabel(outcome: RoundOutcome, index: Int) -> String {
        guard outcome == .tooShort,
              index < result.wordCountsByRound.count,
              index < result.minimumWordsByRound.count else {
            return outcome.label
        }
        let said = result.wordCountsByRound[index]
        let needed = result.minimumWordsByRound[index]
        return "Too short — \(said) word\(said == 1 ? "" : "s") (needed \(needed))"
    }

    /// Records the run in the high score store and kicks off the roll-up animation.
    private func resolveHighScore() {
        isNewHighScore = highScoreStore.recordRun(
            roundsSurvived: result.roundsSurvived,
            difficulty: result.difficulty
        )
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
