#if canImport(SwiftUI)
import SwiftUI

// MARK: - RevisedReadCard
//
// Post-rep summary surface that appears when the just-completed memory
// rebuild folded a user-tapped `.rejected` hypothesis acknowledgement
// into `CoachMemory.adaptationLog` as a documented `CoachCourseChange`
// (rounds 26–27). The card is the coach turning back to the user and
// saying: "you flagged the prior read as off; here's the revised one."
//
// Why this card exists (vision alignment):
//   • Coach-parity stage #4 (Adaptation). `docs/VISION.md`: the case
//     formulation needs a "reason for changing course." Round 27
//     landed the adaptation-log entry; this card closes the loop by
//     surfacing it to the user themselves on the very rep that drove
//     the rebuild. The user sees that their pushback became case
//     history, not a transient tap.
//   • Pillar #5 (Personalized coaching). A real coach acknowledges
//     when the client pushes back. Silently revising the read without
//     naming the pushback breaks the coaching contract.
//   • Pillar #4 (Believable progress). Quoting the user's own prior
//     hypothesis (via the bounded `evidenceBasis` snapshot) lands a
//     revised read as continuous, evidenced coaching, not a fresh
//     paint of telemetry-derived copy.
//
// Why this card is restrained:
//   • No CTA — the existing `TalkToNoumCTACard` sits a few rows
//     below and already routes the user into Ask Noum with the
//     session-anchored opener if they want to discuss the revised
//     read in voice.
//   • No urgency framing, no celebration, no exclamation. Brand-voice
//     rules match `CaseReviewCard` / `InterventionReviewPromptCard`.
//   • Renders only when the latest `CoachCourseChange` is BOTH a
//     user-pushback entry AND fresh (i.e. appended on this exact
//     rebuild). On every subsequent rep the entry still exists in
//     `memory.adaptationLog` but is no longer fresh, so the card
//     does not re-show. The Profile-tab `CaseReviewCard` keeps the
//     long-term history surface.
//
// Eligibility predicate (pure, locked by tests):
//   • `memory.adaptationLog?.last` exists.
//   • `change.documentsUserPushback == true`.
//   • `change.isFresh(comparedTo: memory.updatedAt) == true`.

@available(iOS 17.0, *)
struct RevisedReadCard: View {

    let change: CoachCourseChange
    let workingHypothesis: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.pro)
                Text("REVISED READ")
                    .font(Typography.captionSmall)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.pro)
                Spacer(minLength: 0)
            }

            Text(RevisedReadCard.headlineCopy)
                .font(Typography.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(RevisedReadCard.bodyCopy(workingHypothesis: workingHypothesis))
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Revised coaching read. \(RevisedReadCard.headlineCopy) \(RevisedReadCard.bodyCopy(workingHypothesis: workingHypothesis))")
        .accessibilityIdentifier("summary.revisedRead.card")
    }

    // MARK: - Copy (pure, locked by tests)

    /// Headline copy. The user sees their own action named ("you flagged")
    /// so the line reads as the coach acknowledging the pushback, not as a
    /// generic "your plan changed" notification. Brand-voice compliant: no
    /// exclamation, no apology, no "we", no "Let's".
    static let headlineCopy: String = "You flagged the prior read as off."

    /// Body copy. Names the revised working hypothesis when one exists so
    /// the user reads what the coach has updated to. Falls back to a calm
    /// "forming the next read" line when the rebuild produced no current
    /// hypothesis (rare — typically only with no current lever). Trims +
    /// strips a trailing period so the body line never reads as two
    /// sentences ending in one when the hypothesis already ends with `.`.
    static func bodyCopy(workingHypothesis: String?) -> String {
        guard let raw = workingHypothesis?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return "The coach noted it and is forming the next read."
        }
        let stripped: String
        if raw.hasSuffix(".") {
            stripped = String(raw.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            stripped = raw
        }
        return "Here's the revised read: \(stripped)."
    }
}

#endif
