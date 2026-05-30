#if canImport(SwiftUI)
import SwiftUI

// MARK: - InterventionReviewPromptCard
//
// Post-rep summary surface that appears when the active case-file
// intervention has reached its review threshold — i.e.
// `CoachIntervention.isReviewDue(at:)` returns true on this rep's
// finalize. The card is the coach's quiet check-in: "this is the
// review moment we agreed to revisit." One CTA only — open Ask Noum
// with a case-anchored opener so the review conversation starts
// inline, in voice, with the case scaffolding already on the table.
//
// Why this card exists (vision alignment):
//   • Coach-parity stage #4 (Adaptation). `docs/VISION.md`:
//     "compare response across multiple attempts and either
//     reinforce, vary, or replace the intervention with an
//     explained rationale." The case file already records the
//     review cadence; this surface honours it by surfacing the
//     prompt at the exact moment the cadence elapses — not weeks
//     later when the user happens to open Profile.
//   • Pillar #5 (Personalized coaching). A real coach revisits the
//     prescribed plan. Silently re-prescribing the same drill past
//     the agreed review date breaks the coaching contract.
//
// Why this card is restrained:
//   • One paragraph of context, one CTA. No second-tier urgency
//     framing, no countdown chips, no badges.
//   • Brand-voice rules: no exclamation, no "Let's", no "running
//     out", no chirp. The pure-function copy generators below pin
//     the exact strings the card renders.
//   • Mirrors the `CoachReadCard` register (purple eyebrow + outer
//     stroke) so the user reads it as a continuation of the same
//     coach voice rather than a separate system notification.

@available(iOS 17.0, *)
struct InterventionReviewPromptCard: View {

    let intervention: CoachIntervention
    let onReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.pro)
                Text("REVIEW DUE")
                    .font(Typography.captionSmall)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.pro)
                Spacer(minLength: 0)
            }

            Text(headlineCopy)
                .font(Typography.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(bodyCopy)
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onReview) {
                HStack(spacing: 6) {
                    Text("Review with coach")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(AppColor.pro)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityHint("Opens Ask Noum to review whether the active intervention is working.")
            .accessibilityIdentifier("summary.interventionReview.cta")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(AppColor.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(AppColor.pro.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: AppColor.pro.opacity(0.06), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Review the active coaching intervention")
        .accessibilityIdentifier("summary.interventionReview.card")
    }

    // MARK: - Copy

    private var headlineCopy: String {
        InterventionReviewPromptCard.headlineCopy(for: intervention)
    }

    private var bodyCopy: String {
        InterventionReviewPromptCard.bodyCopy(for: intervention)
    }

    /// Pure-function headline so the copy can be locked by tests
    /// without standing up a SwiftUI view. Names the active focus so
    /// the user reads the subject of the review in one beat. Falls
    /// back to the intervention `title` when `focus` is nil/empty so
    /// the headline never shows an empty noun phrase.
    static func headlineCopy(for intervention: CoachIntervention) -> String {
        let focus = (intervention.focus?.isEmpty == false ? intervention.focus : intervention.title)
            ?? intervention.title
        return "Time to check in on \(focus.lowercased())."
    }

    /// Pure-function body copy. Names the followed-rep depth so the
    /// user sees the basis of the prompt (the coach didn't pop this
    /// up on rep 2 — it's been three or more), then frames the
    /// review question. Brand-voice compliant: no exclamation, no
    /// urgency framing, no "running out."
    static func bodyCopy(for intervention: CoachIntervention) -> String {
        let repNoun = intervention.followedRepCount == 1 ? "rep" : "reps"
        return "Your coach scheduled this review after \(intervention.followedRepCount) followed \(repNoun). One question: keep going, adapt, or replace it?"
    }
}

#endif
