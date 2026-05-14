#if canImport(SwiftUI)
import SwiftUI

// MARK: - Word Choice Card
//
// Surfaces vocabulary variety + the user's most-repeated content words for
// the just-finished session. Hides itself when the transcript is too
// short to read.
//
// Sits next to PauseSummaryCard as the "speech-quality v2" pair: pause is
// about delivery rhythm, word-choice is about substance.

@available(iOS 17.0, macOS 12.0, *)
struct WordChoiceCard: View {
    let metrics: WordChoiceMetrics

    private let tint: Color = AppColor.modeAhCounter

    var body: some View {
        if metrics.contentWordCount < WordChoiceMetrics.minContentWords {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                header
                Text(metrics.coachLine)
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !metrics.repeatedContentWords.isEmpty {
                    repeatedRow
                }
                varietyBar
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .accessibilityIdentifier("summary.wordChoiceCard")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "text.word.spacing")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Word choice")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text(metrics.headline)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var repeatedRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Repeated this rep")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            FlowLayout(spacing: 8, runSpacing: 6) {
                ForEach(metrics.repeatedContentWords) { item in
                    HStack(spacing: 4) {
                        Text(item.word)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("×\(item.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tint)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.10), in: Capsule(style: .continuous))
                }
            }
        }
    }

    private var varietyBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Unique ratio")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                Text("\(Int((metrics.uniqueRatio * 100).rounded()))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }
            ShimmerProgressBar(progress: metrics.uniqueRatio, tint: tint)
                .frame(height: 8)
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Word choice — repeats") {
    WordChoiceCard(metrics: WordChoiceMetrics(
        uniqueRatio: 0.62,
        repeatedContentWords: [
            .init(word: "leadership", count: 6),
            .init(word: "structure", count: 4),
            .init(word: "team", count: 3)
        ],
        contentWordCount: 60
    ))
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("Word choice — varied") {
    WordChoiceCard(metrics: WordChoiceMetrics(
        uniqueRatio: 0.81,
        repeatedContentWords: [],
        contentWordCount: 50
    ))
    .padding()
    .background(AppColor.screenBackground)
}
#endif

#endif
