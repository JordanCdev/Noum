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

    @State private var isNewHighScore: Bool = false
    @State private var displayedPoints: Int = 0
    @State private var showingShareSheet: Bool = false
    @State private var pendingShareKind: ShareKind = .thisRun
    @State private var currentRunID: UUID = UUID()
    @State private var multipliersRevealed: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accentColor = AppColor.modeSuddenDeath

    // MARK: - Derived values

    private var tierReached: Int {
        max(1, result.roundOutcomes.count)
    }

    private var previousBestPoints: Int {
        highScoreStore.bestPoints()
    }

    private var runEndNote: String {
        switch result.finalOutcome {
        case .survived:          return "Run cleared"
        case .fillerOverload:
            return "\(result.totalFillers) filler\(result.totalFillers == 1 ? "" : "s") ended the run"
        case .timeoutBeforeStart: return "Start window expired"
        case .tooShort:          return "Below word target"
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
        let pts = result.gamePoints
        let mults = result.multiplierLabels
        var text = "Tier \(tierReached) · \(pts.formatted()) pts on Noum Sudden Death."
        if !mults.isEmpty {
            text += " Multipliers: \(mults.joined(separator: ", "))."
        }
        return text
    }

    private var fullHistoryShareText: String {
        SuddenDeathHistoryExport.formatPlainText(runs: runHistoryStore.runs)
    }

    private enum ShareKind { case thisRun, fullHistory }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    outcomeIcon
                    headerBlock
                    pointsHero
                    if !result.computedMultipliers.isEmpty { multiplierChips }
                    statsRow
                    compactRunPath
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)
            }

            actionButtons
                .padding(.horizontal, Spacing.screenH)
                .padding(.bottom, 24)
        }
        .onAppear { resolveAndAnimate() }
        .accessibilityIdentifier("suddenDeath.result.screen")
        .sheet(isPresented: $showingShareSheet) {
            SuddenDeathShareSheet(text: resolvedShareText)
                .ignoresSafeArea()
        }
    }

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
            Text("Tier \(tierReached) Reached")
                .font(Typography.bigStat)
                .multilineTextAlignment(.center)
            Text(runEndNote)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var pointsHero: some View {
        VStack(spacing: 6) {
            Text("\(displayedPoints.formatted())")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(accentColor)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("pts")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if isNewHighScore {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    Text("NEW BEST")
                        .font(.caption.weight(.black))
                        .tracking(1.2)
                    SparkleRibbon(tint: .yellow, animated: !reduceMotion)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            } else if previousBestPoints > 0 {
                Text("Best: \(previousBestPoints.formatted()) pts")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private var multiplierChips: some View {
        HStack(spacing: 8) {
            ForEach(result.computedMultipliers, id: \.label) { m in
                HStack(spacing: 4) {
                    Text("×\(String(format: "%.1f", m.value))")
                        .font(.caption.weight(.black))
                    Text(m.label)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(accentColor.opacity(0.10), in: Capsule())
                .opacity(multipliersRevealed ? 1 : 0)
                .scaleEffect(multipliersRevealed ? 1 : 0.7)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: multipliersRevealed)
    }

    private var statsRow: some View {
        HStack(spacing: 20) {
            statTile(value: "\(result.roundsSurvived)", label: "Cleared", tint: accentColor)
            statTile(value: survivalTimeLabel, label: "Time", tint: .primary)
            statTile(value: "\(result.totalWords)", label: "Words", tint: .primary)
        }
    }

    /// Compact horizontal dot strip — scales to any number of tiers.
    private var compactRunPath: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Run Path")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if result.roundOutcomes.count <= 6 {
                HStack(spacing: 6) {
                    ForEach(Array(result.roundOutcomes.enumerated()), id: \.offset) { index, outcome in
                        VStack(spacing: 3) {
                            Image(systemName: outcome.isFailed ? "stop.circle.fill" : "checkmark.circle.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(outcome.isFailed ? accentColor : AppColor.positive)
                            Text("\(index + 1)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            } else {
                let cleared = result.roundOutcomes.filter { !$0.isFailed }.count
                let lastOutcome = result.roundOutcomes.last
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.positive)
                        .font(.body)
                    Text("\(cleared) tiers cleared")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if let last = lastOutcome, last.isFailed {
                        Image(systemName: "stop.circle.fill")
                            .foregroundStyle(accentColor)
                            .font(.body)
                        Text("Tier \(tierReached)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(accentColor)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
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
                    Label("Coach Read", systemImage: "text.bubble")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

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
        } else {
            Button {
                pendingShareKind = .thisRun
                showingShareSheet = true
            } label: {
                shareLabel
            }
            .accessibilityIdentifier("suddenDeath.result.shareButton")
        }
    }

    // MARK: - Helpers

    private func statTile(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func resolveAndAnimate() {
        _ = highScoreStore.recordRun(
            roundsSurvived: result.roundsSurvived,
            difficulty: result.difficulty
        )
        let isNewPointsBest = highScoreStore.recordPoints(result.gamePoints)
        isNewHighScore = isNewPointsBest || (result.roundsSurvived > result.personalBest)

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
            wasNewBestAtTime: isNewHighScore,
            gamePoints: result.gamePoints,
            activeMultipliers: result.multiplierLabels
        )
        runHistoryStore.record(record)
        animatePoints()
    }

    private func animatePoints() {
        let target = result.gamePoints
        guard !reduceMotion, target > 0 else {
            displayedPoints = target
            multipliersRevealed = true
            return
        }

        let duration: Double = 0.8
        let stepCount = min(target, 30)
        guard stepCount > 0 else {
            displayedPoints = target
            multipliersRevealed = true
            return
        }
        let stepDelay = duration / Double(stepCount)

        for step in 1...stepCount {
            let progress = Double(step) / Double(stepCount)
            let eased = 1 - pow(1 - progress, 2)
            let value = Int(round(eased * Double(target)))
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDelay * Double(step)) {
                displayedPoints = value
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.15) {
            withAnimation { multipliersRevealed = true }
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
