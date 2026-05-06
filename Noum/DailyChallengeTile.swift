#if canImport(SwiftUI)
import SwiftUI

// MARK: - Daily Challenge Tile (M8)
//
// Three-row claim-able tile shown on home, between the daily-goal ring and
// the practice CTA. Each row:
//   • SF Symbol + title + subtitle (compact, two-line max).
//   • State indicator on the right: "Claim" (when readyToClaim), check (when
//     claimed), or muted state (still locked / not yet satisfied).
//   • Tapping a "Claim" row fires the claim() and shows the XP gain.
//
// Visual rhythm: brand-blue ready state, brand-gray locked, soft-fade past
// 9pm to communicate "today is winding down" without scolding the user.

@available(iOS 17.0, macOS 12.0, *)
struct DailyChallengeTile: View {
    @StateObject private var manager = DailyChallengesManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showClaimToast = false
    @State private var lastClaim: DailyChallengeKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            VStack(spacing: 8) {
                ForEach(manager.todays, id: \.self) { kind in
                    row(for: kind)
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            tileBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(alignment: .top) {
            if showClaimToast, let last = lastClaim {
                claimToast(kind: last)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .onChange(of: manager.pendingClaim) { _, kind in
            guard let kind else { return }
            lastClaim = kind
            withAnimation(reduceMotion ? .none : .standardSpring) {
                showClaimToast = true
            }
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                await MainActor.run {
                    withAnimation(reduceMotion ? .none : .standardSpring) {
                        showClaimToast = false
                    }
                    manager.consumePendingClaim()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily challenges. \(manager.unclaimedCount) of \(manager.todays.count) remaining.")
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "target")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(headerAccent)
            Text("Daily challenges")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            Text(headerSummary)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(headerAccent)
        }
    }

    private var headerAccent: Color {
        if manager.allClaimedToday { return AppColor.brandBlue }
        if manager.isPastSoftExpiry { return .secondary }
        return AppColor.brandBlue
    }

    private var headerSummary: String {
        if manager.allClaimedToday { return "All claimed" }
        if manager.isPastSoftExpiry {
            return "\(manager.unclaimedCount) before midnight"
        }
        return "\(manager.unclaimedCount) to go"
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for kind: DailyChallengeKind) -> some View {
        let claimed = manager.claimedKinds.contains(kind)
        let ready = manager.readyToClaim.contains(kind)
        let muted = manager.isPastSoftExpiry && !claimed

        Button {
            guard ready else { return }
            _ = manager.claim(kind)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(rowAccent(claimed: claimed, ready: ready, muted: muted))
                    .frame(width: 32, height: 32)
                    .background(
                        rowAccent(claimed: claimed, ready: ready, muted: muted).opacity(claimed ? 0.18 : 0.12),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(claimed ? .secondary : .primary)
                        .strikethrough(claimed, color: .secondary)
                    Text(kind.subtitle)
                        .font(Typography.micro)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailing(claimed: claimed, ready: ready, kind: kind)
            }
            .opacity(muted ? 0.6 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!ready)
        .accessibilityLabel(rowAccessibilityLabel(kind: kind, claimed: claimed, ready: ready))
    }

    @ViewBuilder
    private func trailing(claimed: Bool, ready: Bool, kind: DailyChallengeKind) -> some View {
        if claimed {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColor.brandBlue)
        } else if ready {
            HStack(spacing: 4) {
                Text("Claim +\(kind.xpReward)")
                    .font(Typography.micro.weight(.bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColor.brandBlue, in: Capsule())
        } else {
            Text("+\(kind.xpReward) XP")
                .font(Typography.micro.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func rowAccent(claimed: Bool, ready: Bool, muted: Bool) -> Color {
        if claimed { return AppColor.brandBlue }
        if ready { return AppColor.brandBlue }
        if muted { return .secondary }
        return .secondary
    }

    private func rowAccessibilityLabel(kind: DailyChallengeKind, claimed: Bool, ready: Bool) -> String {
        if claimed { return "\(kind.title). Claimed." }
        if ready { return "\(kind.title). Ready to claim, \(kind.xpReward) XP." }
        return "\(kind.title). \(kind.subtitle) Worth \(kind.xpReward) XP."
    }

    // MARK: - Background

    private var tileBackground: some ShapeStyle {
        if manager.allClaimedToday {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppColor.brandBlue.opacity(0.10), AppColor.brandBlue.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(AppColor.cardBackground)
    }

    // MARK: - Claim toast

    private func claimToast(kind: DailyChallengeKind) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
            Text("+\(kind.xpReward) XP — \(kind.title)")
                .font(Typography.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppColor.brandBlue, in: Capsule())
        .shadow(color: AppColor.brandBlue.opacity(0.30), radius: 12, x: 0, y: 4)
        .padding(.top, -16)
    }
}

// MARK: - Preview

#Preview {
    DailyChallengeTile()
        .padding()
        .background(AppColor.screenBackground)
}

#endif
