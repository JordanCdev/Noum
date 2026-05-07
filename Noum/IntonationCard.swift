#if canImport(SwiftUI)
import SwiftUI

// MARK: - Intonation Card
//
// M10 v1: surfaces the on-device pitch / intonation read for the
// just-finished session. Hides itself when there isn't enough voiced
// audio to publish honest numbers — better silence than a misleading
// "0% varied" reading on a five-word reply.
//
// Layout matches the other summary cards: tinted icon, headline + body,
// a row of three concrete numbers (variety score, range, median Hz).

@available(iOS 17.0, macOS 12.0, *)
struct IntonationCard: View {
    let metrics: IntonationMetrics

    private let tint: Color = AppColor.brandBlue

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "waveform.path")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(tint)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Intonation")
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

            Text(metrics.coachLine)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if metrics.voicedFrameCount >= IntonationMetrics.minimumVoicedFrames {
                HStack(spacing: 0) {
                    statCell(value: "\(metrics.varietyScore)", label: "Variety")
                    divider
                    statCell(value: formatSemis(metrics.rangeSemitones), label: "Range")
                    divider
                    statCell(value: formatHz(metrics.medianHz), label: "Median")
                }
                .padding(.vertical, Spacing.sm)
                .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .accessibilityIdentifier("summary.intonationCard")
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.05))
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    private func formatSemis(_ value: Double) -> String {
        if value < 10 { return String(format: "%.1f st", value) }
        return String(format: "%.0f st", value)
    }

    private func formatHz(_ value: Double) -> String {
        String(format: "%.0f Hz", value)
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Intonation — varied") {
    IntonationCard(metrics: IntonationMetrics(
        voicedFrameCount: 240,
        voicedSeconds: 6,
        medianHz: 145,
        stddevSemitones: 2.1,
        rangeSemitones: 5.4,
        varietyScore: 70
    ))
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("Intonation — flat") {
    IntonationCard(metrics: IntonationMetrics(
        voicedFrameCount: 200,
        voicedSeconds: 5,
        medianHz: 122,
        stddevSemitones: 0.5,
        rangeSemitones: 1.2,
        varietyScore: 17
    ))
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("Intonation — too short") {
    IntonationCard(metrics: IntonationMetrics(
        voicedFrameCount: 4,
        voicedSeconds: 0.1,
        medianHz: 130,
        stddevSemitones: 0.3,
        rangeSemitones: 0.8,
        varietyScore: 10
    ))
    .padding()
    .background(AppColor.screenBackground)
}
#endif

#endif
