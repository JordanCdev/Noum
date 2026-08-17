import SwiftUI

// MARK: - Delivery Profile Card (F3 — Perception surface)
//
// Surfaces the durable `DeliveryProfile` (recurring pattern / what improved /
// what breaks under pressure / next delivery target) in the Profile "Coaching"
// cluster. Read-only and restrained — the same card language as
// `CaseReviewCard` (this is the coach's read of HOW you come across, not a
// dashboard). Every row is a HYPOTHESIS about the rep SET and self-suppresses
// below its evidence floor; the owning `DeliveryProfile` is nil when nothing is
// earned, so the card never renders an empty shell. Never labels the person.
struct DeliveryProfileCard: View {
    let profile: DeliveryProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How you come across")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            if let patternLine = profile.patternLine {
                row(icon: "brain.head.profile", label: "Recurring read", text: patternLine)
            }
            if let improved = profile.improvedLine {
                row(icon: "arrow.up.right", label: "What's improved", text: improved)
            }
            if let pressure = profile.pressureLine {
                row(icon: "bolt.heart", label: "Under pressure", text: pressure)
            }
            if let next = profile.nextTargetLine {
                row(icon: "scope", label: "Next delivery target", text: next)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
    }

    private func row(icon: String, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(Typography.captionSmall)
                .foregroundStyle(.tertiary)
                .frame(width: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(text)
                    .font(Typography.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
