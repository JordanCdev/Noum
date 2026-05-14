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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
                Text(metrics.headline)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                Spacer()
                if let mean = metrics.meanHz {
                    Text("\(Int(mean.rounded())) Hz")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            meter

            Text(metrics.coachLine)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                stat(label: "Variation", value: stdLabel)
                stat(label: "Voiced", value: voicedLabel)
                stat(label: "Windows", value: "\(metrics.windowCount)")
            }
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

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.6)
            Text(value)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var accent: Color {
        if metrics.monotoneScore < 0.30 { return AppColor.brandBlue }
        if metrics.monotoneScore < 0.65 { return .orange }
        return .secondary
    }

    private var stdLabel: String {
        guard let std = metrics.stdHz else { return "—" }
        return String(format: "±%.0f Hz", std)
    }

    private var voicedLabel: String {
        let pct = Int((metrics.voicedRatio * 100).rounded())
        return "\(pct)%"
    }
}

#endif
