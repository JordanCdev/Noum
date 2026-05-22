#if canImport(SwiftUI)
import SwiftUI

// MARK: - Talk To Noum CTA Card
//
// Hero-block bottom card. Always visible — the post-rep moment is the
// highest-intent buying moment in the product, so the upgrade path
// lives where the user has just felt the value.
//
// Behavior:
//   • Pro user → tap navigates to AskNoumView with the session-anchored
//     opener already seeded (via `onAskNoumAboutRep` — the same bridge
//     the askCoachBridgeCard in the Details disclosure already uses).
//     The Details bridge stays as the discovery hook; this card is the
//     hero CTA so non-expanders never miss the door.
//   • Free user → tap presents the existing `PaywallView` via the
//     `showPaywall` binding the host SummaryView already owns. We
//     don't introduce a parallel sheet; one paywall presenter, one
//     entry point.
//
// Visual register:
//   • AppColor.pro gradient + 0.18-opacity stroke — same vocabulary
//     the existing Pro preview card uses, so the upgrade hierarchy
//     reads as one coherent surface across the screen.
//   • NoumCharacter.Inline at .calm — the same coach speaker the
//     askCoachBridgeCard uses, stitching this CTA to the thread it
//     opens.
//   • Lock glyph for free users — honest signal, not dark-pattern.
//     The Pro register itself already says "premium"; the lock is a
//     small clarifier, not the headline.
//
// Voice rules honored: sentence case, no exclamation, no emoji. The
// pitch line names the value (`talk to your coach about every rep`)
// without claiming the moon — we don't promise outcomes we can't
// underwrite.

@available(iOS 17.0, *)
struct TalkToNoumCTACard: View {
    let isPremium: Bool
    let onAskNoum: () -> Void
    let onUpgradePrompt: () -> Void

    var body: some View {
        Button(action: handleTap) {
            HStack(alignment: .top, spacing: Spacing.md) {
                NoumCharacter.Inline(size: 22, mood: .calm, tint: AppColor.pro)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("ASK NOUM")
                            .font(Typography.micro)
                            .foregroundStyle(AppColor.pro)
                            .tracking(1.0)
                        if !isPremium {
                            lockChip
                        }
                    }
                    Text(headlineCopy)
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subCopy)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(ctaCopy)
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(AppColor.pro)
                        Image(systemName: isPremium ? "arrow.right" : "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColor.pro)
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        }
        .buttonStyle(.pressable)
        .background(background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(isPremium
            ? "summary.talkToNoum.pro"
            : "summary.talkToNoum.gated")
    }

    private func handleTap() {
        if isPremium {
            onAskNoum()
        } else {
            onUpgradePrompt()
        }
    }

    // MARK: - Copy

    private var headlineCopy: String {
        "Talk to Noum about this rep."
    }

    private var subCopy: String {
        isPremium
            ? "Open the thread with this session in hand — quotes, pace, and the call already loaded."
            : "Pro members can open a coach thread about every rep, with quotes and metrics pre-loaded."
    }

    private var ctaCopy: String {
        isPremium ? "Open the thread" : "Unlock with Pro"
    }

    private var accessibilityLabel: String {
        if isPremium {
            return "Talk to Noum about this rep. Opens the coach thread with this session pre-loaded."
        }
        return "Talk to Noum about this rep. Locked. Pro members unlock the coach thread for every rep."
    }

    // MARK: - Lock chip

    /// Small Pro lock chip — same Pro-gradient register the paywall
    /// uses. Sits inline with the section label so the lock signal
    /// reads alongside the section name, not as a separate warning.
    private var lockChip: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill")
                .font(.system(size: 8, weight: .bold))
            Text("PRO")
                .font(Typography.micro)
                .tracking(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            LinearGradient(
                colors: [AppColor.pro, AppColor.proLight],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: Capsule()
        )
    }

    // MARK: - Background

    @ViewBuilder
    private var background: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(AppColor.cardBackground)
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColor.pro.opacity(0.10), AppColor.pro.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.pro.opacity(0.22), lineWidth: 1)
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Talk to Noum — Pro") {
    TalkToNoumCTACard(
        isPremium: true,
        onAskNoum: { print("ask") },
        onUpgradePrompt: { print("upgrade") }
    )
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("Talk to Noum — Free (locked)") {
    TalkToNoumCTACard(
        isPremium: false,
        onAskNoum: { print("ask") },
        onUpgradePrompt: { print("upgrade") }
    )
    .padding()
    .background(AppColor.screenBackground)
}
#endif

#endif
