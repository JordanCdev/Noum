#if canImport(SwiftUI)
import SwiftUI

// MARK: - Talk To Noum CTA Card
//
// Single-source Ask Noum CTA. Replaces the previous two-card setup
// (this card + askCoachBridgeCard in the Details disclosure).
//
// Behavior:
//   • Pro user → opens AskNoumView with session-anchored opener seeded.
//   • Free user → presents PaywallView via the showPaywall binding the
//     host SummaryView owns. One paywall presenter, one entry point.
//
// Voice-aware headline: shaped by the user's speakingStyleGoal so the
// question reads in the same register the thread it opens will use.
// Free users see a generic headline because the paywall interrupts
// before they enter the thread.

@available(iOS 17.0, *)
struct TalkToNoumCTACard: View {
    let isPremium: Bool
    let speakingStyleGoal: SpeakingStyleGoal?
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

    private var headlineCopy: String { Self.headlineCopy(isPremium: isPremium, voice: speakingStyleGoal) }
    private var subCopy: String { Self.subCopy(isPremium: isPremium) }
    private var ctaCopy: String { Self.ctaCopy(isPremium: isPremium) }
    private var accessibilityLabel: String { Self.accessibilityLabel(isPremium: isPremium, voice: speakingStyleGoal) }

    /// Copy contract — extracted to static accessors so brand-voice rules
    /// (sentence case, no exclamation, no emoji, honest upgrade signal)
    /// can be locked by unit tests without instantiating SwiftUI.
    static func headlineCopy(isPremium: Bool, voice: SpeakingStyleGoal? = nil) -> String {
        guard isPremium else { return "Want a coach's read on this rep?" }
        switch voice {
        case .authoritative: return "Want a verdict on this rep?"
        case .warm: return "Want to talk through how this rep felt?"
        case .concise: return "Want the one move from this rep?"
        case .persuasive: return "Want the argument this rep makes?"
        case .executive: return "Want a top-line read on this rep?"
        case .storytelling: return "Want to place this rep in your arc?"
        case .none: return "Want a coach's read on this rep?"
        }
    }

    static func subCopy(isPremium: Bool) -> String {
        isPremium
            ? "Ask about this rep with its quotes, pace, and coaching read already in hand."
            : "Pro members can open a coach thread about every rep, with quotes and metrics pre-loaded."
    }

    static func ctaCopy(isPremium: Bool) -> String {
        isPremium ? "Ask Noum" : "Unlock with Pro"
    }

    static func accessibilityLabel(isPremium: Bool, voice: SpeakingStyleGoal? = nil) -> String {
        let headline = headlineCopy(isPremium: isPremium, voice: voice)
        if isPremium {
            return "Ask Noum. \(headline). Opens the coach thread with this rep already in hand."
        }
        return "Ask Noum. \(headline). Locked — Pro members unlock the coach thread for every rep."
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
        speakingStyleGoal: .authoritative,
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
        speakingStyleGoal: nil,
        onAskNoum: { print("ask") },
        onUpgradePrompt: { print("upgrade") }
    )
    .padding()
    .background(AppColor.screenBackground)
}
#endif

#endif
