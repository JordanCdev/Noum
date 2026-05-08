#if canImport(SwiftUI)
import SwiftUI

// MARK: - Pitch Summary Card
//
// M10 — surfaces pitch / intonation statistics for the just-finished
// session. Hides itself when there isn't enough voiced audio to read
// honestly (silence, whisper, or a rep that died early) — better silence
// than fake certainty.
//
// Layout matches the rest of the summary cards: tinted icon, on-voice
// headline + body, then a compact stats row (variety score, mean Hz,
// range in semitones). The variety bar is the eye-catch — it's the
// most-coachable signal at a glance.

@available(iOS 17.0, macOS 12.0, *)
struct PitchSummaryCard: View {
    let metrics: PitchMetrics

    private let tint: Color = AppColor.modeAhCounter

    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(tint)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pitch")
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

            if metrics.hasReadableSignal {
                varietyBar
                statsRow
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .accessibilityIdentifier("summary.pitchCard")
        .onAppear {
            withAnimation(.easeOut(duration: 0.45).delay(0.1)) {
                hasAppeared = true
            }
        }
    }

    private var varietyBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Variety")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                Text("\(metrics.displayScore) / 100")
                    .font(Typography.caption.monospacedDigit())
                    .foregroundStyle(tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(tint.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.65), tint],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * CGFloat(hasAppeared ? metrics.varietyScore : 0),
                            height: 8
                        )
                }
            }
            .frame(height: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pitch variety \(metrics.displayScore) out of 100")
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: "\(Int(metrics.meanHz.rounded()))", label: "Mean Hz")
            divider
            statCell(value: formatST(metrics.semitoneStdDev), label: "Spread")
            divider
            statCell(value: formatST(metrics.rangeSemitones), label: "Range")
            divider
            statCell(value: formatSeconds(metrics.voicedSeconds), label: "Voiced")
        }
        .padding(.vertical, Spacing.sm)
        .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
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

    private func formatST(_ value: Double) -> String {
        if value >= 10 { return String(format: "%.0f ST", value) }
        return String(format: "%.1f ST", value)
    }

    private func formatSeconds(_ value: Double) -> String {
        if value >= 60 {
            let minutes = Int(value / 60)
            let seconds = Int(value.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
        return String(format: "%.0fs", value)
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Pitch — varied") {
    PitchSummaryCard(metrics: PitchMetrics(
        meanHz: 165,
        voicedSeconds: 42,
        semitoneStdDev: 3.2,
        varietyScore: 0.78,
        rangeSemitones: 9.4
    ))
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("Pitch — flat") {
    PitchSummaryCard(metrics: PitchMetrics(
        meanHz: 132,
        voicedSeconds: 38,
        semitoneStdDev: 0.8,
        varietyScore: 0.13,
        rangeSemitones: 2.4
    ))
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("Pitch — no signal") {
    PitchSummaryCard(metrics: PitchMetrics.empty)
        .padding()
        .background(AppColor.screenBackground)
}
#endif

#endif
