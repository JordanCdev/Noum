#if canImport(SwiftUI)
import SwiftUI

// MARK: - CoachReadCard
//
// Hero coach voice for the post-rep Summary surface. Renders the
// `PostRepCoachNote` produced by `PostRepCoachNoteService` — a short,
// 2-sentence voice-shaped read of THIS rep, in the user's chosen
// voice register. The card is purposefully restrained:
//
//   • One paragraph of the coach's actual words. No metrics duplicated
//     (the HeroScoreCard already carries those). The note is the
//     coach turning toward the user and saying "here's what I just saw."
//   • Brand-purple register (per the M14 home-card design language:
//     purple = "your coach speaking", mode-tint = "this is what to do").
//   • Provenance honesty — a tiny "RULE-BASED" tag when the note is
//     deterministic so the user can tell when AI is actually
//     participating vs. when the template is standing in.
//   • No emoji, no exclamation, no chirpy filler. The note text
//     itself is contract-locked by `PostRepCoachNoteService.passes-
//     BrandVoiceContract` for the AI path; the deterministic path is
//     hard-coded brand-voice-clean.
//
// The card collapses to nothing (returns EmptyView) when no note is
// available — non-IM modes without finalized data shouldn't render
// the card at all rather than show a placeholder.

@available(iOS 17.0, *)
struct CoachReadCard: View {

    let note: PostRepCoachNote

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                NoumCharacter.Inline(size: 22, mood: .coaching, tint: AppColor.pro)
                Text(headerLabel)
                    .font(Typography.captionSmall)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.pro)
                Spacer(minLength: 0)
                if !note.isAIBacked {
                    Text("RULE-BASED")
                        .font(Typography.captionSmall)
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .stroke(AppColor.textSecondary.opacity(0.35), lineWidth: 1)
                        )
                }
            }

            Text(note.noteText)
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(AppColor.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .stroke(AppColor.pro.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: AppColor.pro.opacity(0.06), radius: 8, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coach read of your rep")
        .accessibilityValue(note.noteText)
    }

    private var headerLabel: String {
        switch note.voice {
        case .authoritative: return "COACH READ"
        case .warm: return "FROM YOUR COACH"
        case .concise: return "COACH NOTE"
        case .persuasive: return "COACH BRIEFING"
        case .executive: return "COACH BRIEF"
        case .storytelling: return "COACH READ"
        case .none: return "COACH NOTE"
        }
    }
}

#endif
