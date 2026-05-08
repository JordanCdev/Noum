#if canImport(SwiftUI)
import SwiftUI

// MARK: - Pitch Summary Card (M10)
//
// Surfaces "monotone vs varied" delivery using PitchMetrics. Hides
// itself when the metrics aren't reliable rather than showing a misleading
// "very varied" reading on a 5-second whisper.
//
// Visual: a horizontal "monotone meter" with the score positioned
// between Varied and Monotone anchors, plus the headline + coach line.

@available(iOS 17.0, *)
struct PitchSummaryCard: View {
    let metrics: PitchMetrics

    var body: some View {
        if !metrics.isReliable {
            EmptyView()
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        // M14 simplification (real-device feedback): the user said
        // "I dont know if Hz is relevant, like what does 141 Hz mean
        // etc. And windows?? Voiced?". Stripped the three technical
        // stat cells (Variation ±Hz, Voiced %, Windows count) and the
        // raw Hz number from the headline. The card now reads as
        // coaching: headline + meter + one coach line. Power users
        // can still see the precise reads in the trend chart on profile.
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
                Text(metrics.headline)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                Spacer()
            }

            meter

            Text(metrics.coachLine)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    // MARK: - Subviews

    private var meter: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let knobX = max(8, min(width - 8, width * CGFloat(1.0 - metrics.monotoneScore)))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(
                        colors: [AppColor.brandBlue.opacity(0.85), Color.secondary.opacity(0.5)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(height: 6)

                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(accent, lineWidth: 3))
                    .frame(width: 16, height: 16)
                    .position(x: knobX, y: 3)
                    .shadow(color: accent.opacity(0.30), radius: 4, y: 2)
            }
        }
        .frame(height: 16)
        .overlay(alignment: .leading) {
            Text("Varied")
                .font(Typography.micro)
                .foregroundStyle(.tertiary)
                .offset(y: 18)
        }
        .overlay(alignment: .trailing) {
            Text("Monotone")
                .font(Typography.micro)
                .foregroundStyle(.tertiary)
                .offset(y: 18)
        }
        .padding(.bottom, 14)
        .accessibilityLabel("Monotone score \(Int(metrics.monotoneScore * 100)) percent.")
    }

    // MARK: - Helpers

    private var accent: Color {
        if metrics.monotoneScore < 0.30 { return AppColor.brandBlue }
        if metrics.monotoneScore < 0.65 { return .orange }
        return .secondary
    }
}

#endif
