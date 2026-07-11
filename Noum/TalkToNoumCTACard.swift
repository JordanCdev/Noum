#if canImport(SwiftUI)
import SwiftUI

// MARK: - Ask Noum summary affordance
//
// Single-source Ask Noum affordance. It deliberately renders as a quiet row,
// not another summary card, so the prescribed next rep remains the one
// visually dominant action.
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
            HStack(spacing: Spacing.sm) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.pro)
                    .accessibilityHidden(true)
                Text(CohesiveSummaryCopy.askNoum)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(AppColor.pro)
                if !isPremium {
                    lockChip
                }
                Spacer(minLength: 0)
                Image(systemName: isPremium ? "chevron.right" : "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
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

}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Ask Noum — Pro") {
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
#Preview("Ask Noum — Free (locked)") {
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
