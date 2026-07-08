import SwiftUI

/// Small, transparent "Using in this answer" indicator shown near the coach's
/// latest reply. Reads a caller-supplied `MemoryTrajectorySnapshot` (built by
/// `TrajectorySummaryBuilder` from existing, read-only state) and never
/// claims more than the snapshot's own bounded evidence — an empty/thin
/// snapshot renders its own honest "not enough yet" line rather than hiding
/// or inventing something. Tapping the pill opens `TrajectoryView` so the
/// user can see exactly what's behind the line and, when there is a goal,
/// correct it via the existing goal-refresh flow.
struct MemoryUsagePill: View {
    let snapshot: MemoryTrajectorySnapshot
    var onManage: () -> Void

    var body: some View {
        Button(action: onManage) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(Typography.captionSmall.weight(.semibold))
                    .foregroundStyle(AppColor.pro.opacity(0.85))
                    .accessibilityHidden(true)

                Text(snapshot.userVisibility)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 8)
            .background(
                AppColor.cardBackground.opacity(0.6),
                in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .stroke(AppColor.subtleBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Memory in use. \(snapshot.userVisibility) View or manage.")
        .accessibilityIdentifier("askNoum.memoryUsagePill")
    }

    private var iconName: String {
        snapshot.isStale ? "clock.arrow.circlepath" : "brain"
    }
}
