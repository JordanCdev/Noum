#if canImport(SwiftUI)
import SwiftUI

// MARK: - Coach-Parity Readiness Card (F5)
//
// "How well Noum knows you" — a transparent, per-user read of how much coaching
// EVIDENCE has accumulated across the 7 loop stages. Honest by construction:
// thin stages read thin, and validation is capped (never "earned") because the
// app cannot self-certify parity. NOT a gamified progress bar — there's no
// percentage, no streak, no celebration; just where the real evidence stands.
struct CoachParityReadinessCard: View {
    let readiness: CoachParityReadiness

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How well Noum knows you")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            ForEach(CoachParityReadiness.Stage.allCases, id: \.rawValue) { stage in
                if let read = readiness.stages.first(where: { $0.stage == stage }) {
                    row(read)
                }
            }

            Text(readiness.headline)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
    }

    private func row(_ read: CoachParityReadiness.StageRead) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: glyph(read.status))
                .font(Typography.captionSmall)
                .foregroundStyle(color(read.status))
                .frame(width: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(read.stage.title)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(read.basis)
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func glyph(_ status: CoachParityReadiness.StageStatus) -> String {
        switch status {
        case .earned:  return "checkmark.circle.fill"
        case .forming: return "circle.lefthalf.filled"
        case .thin:    return "circle"
        }
    }

    private func color(_ status: CoachParityReadiness.StageStatus) -> Color {
        switch status {
        case .earned:  return AppColor.positive
        case .forming: return AppColor.caution
        case .thin:    return Color.secondary.opacity(0.5)
        }
    }
}
#endif
