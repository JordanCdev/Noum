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
//
// Round 34 — second-cycle pushback copy split:
//   • When `change.documentsSecondCyclePushback == true` (round 33's
//     marker, written by the engine when the latest rebuild itself
//     followed a prior pushback rebuild), the headline + body swap to
//     a second-cycle register: the user reads that they flagged the
//     REBUILT read as off too, and the body names the repeated adapt
//     pattern instead of a first-time rebuild.
//   • Mirrors the round-33 split inside
//     `CoachContextBuilder.freshRevisedReadContextLines(...)` — the
//     post-rep card and the chat-coach context surface the same
//     cycle distinction to the user and to the model in lock-step.
//   • Brand-voice rules unchanged: no exclamation, no "Let's", no
//     "we", no apology. The second-cycle line is direct and calm,
//     framing the repeated adapt as case history, not as a problem.

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

            Text(RevisedReadCard.headlineCopy(for: change))
                .font(Typography.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(RevisedReadCard.bodyCopy(for: change, workingHypothesis: workingHypothesis))
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
        .accessibilityLabel("Revised coaching read. \(RevisedReadCard.headlineCopy(for: change)) \(RevisedReadCard.bodyCopy(for: change, workingHypothesis: workingHypothesis))")
        .accessibilityIdentifier("summary.revisedRead.card")
    }

    // MARK: - Copy (pure, locked by tests)

    /// First-cycle headline. The user sees their own action named ("you flagged")
    /// so the line reads as the coach acknowledging the pushback, not as a
    /// generic "your plan changed" notification. Brand-voice compliant: no
    /// exclamation, no apology, no "we", no "Let's".
    static let headlineCopy: String = "You flagged the prior read as off."

    /// Round-34 second-cycle headline. Surfaced when the latest course
    /// change carries the `secondCyclePushbackMarker` (round 33). The user
    /// sees their pushback named in the second cycle ("the rebuilt read as
    /// off too") so the card lands as the coach acknowledging the repeated
    /// adapt explicitly — no silent revision, no "we", no apology. Keeps
    /// the user-verdict register the first-cycle headline established.
    static let secondCycleHeadlineCopy: String = "You flagged the rebuilt read as off too."

    /// Round-34 headline router. Reads `documentsSecondCyclePushback` on
    /// the passed change and returns the second-cycle copy when the marker
    /// is present, falling back to the first-cycle copy otherwise. Pure
    /// function — same shape as the engine + context-builder predicates,
    /// so a future copy edit on either branch stays in one place.
    static func headlineCopy(for change: CoachCourseChange) -> String {
        change.documentsSecondCyclePushback ? secondCycleHeadlineCopy : headlineCopy
    }

    /// First-cycle body copy. Names the revised working hypothesis when one
    /// exists so the user reads what the coach has updated to. Falls back
    /// to a calm "forming the next read" line when the rebuild produced no
    /// current hypothesis (rare — typically only with no current lever).
    /// Trims + strips a trailing period so the body line never reads as
    /// two sentences ending in one when the hypothesis already ends with `.`.
    static func bodyCopy(workingHypothesis: String?) -> String {
        guard let raw = workingHypothesis?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return "The coach noted it and is forming the next read."
        }
        let stripped = CoachDisplayCopy.normalized(strippedHypothesis(raw))
        return "Here's the revised read: \(stripped)."
    }

    /// Round-34 second-cycle body copy. Surfaced when the latest course
    /// change carries the `secondCyclePushbackMarker`. Names the rebuilt
    /// read as the operating hypothesis AND tells the user the coach
    /// will treat the repeated adapt as case history — one focused
    /// question instead of re-prescribing identical work. Mirrors the
    /// round-33 second-cycle coach-move line inside
    /// `CoachContextBuilder.freshRevisedReadContextLines(...)` so the
    /// card and the chat thread read with one voice. Falls back to a
    /// calm "forming a new read" line when the rebuild produced no
    /// current hypothesis (defensive — same boundary as the first-cycle
    /// path).
    static func secondCycleBodyCopy(workingHypothesis: String?) -> String {
        guard let raw = workingHypothesis?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return "The coach noted the repeated adapt and is forming a new read."
        }
        let stripped = CoachDisplayCopy.normalized(strippedHypothesis(raw))
        return "Here's the next read: \(stripped). Expect one focused question, not the same exercise again."
    }

    /// Round-34 body router. Reads `documentsSecondCyclePushback` on the
    /// passed change and returns the second-cycle copy when the marker is
    /// present, falling back to the first-cycle copy otherwise. Pure
    /// function on the persisted predicate; the workingHypothesis trim +
    /// trailing-period strip applies on both branches via
    /// `strippedHypothesis(_:)`.
    static func bodyCopy(for change: CoachCourseChange, workingHypothesis: String?) -> String {
        if change.documentsSecondCyclePushback {
            return secondCycleBodyCopy(workingHypothesis: workingHypothesis)
        }
        return bodyCopy(workingHypothesis: workingHypothesis)
    }

    /// Shared hypothesis trim. The engine's hypothesis clause typically ends
    /// with `.`; both body copy paths wrap it in a "…: <hypothesis>." line
    /// which would otherwise produce `..`. Lifted so first-cycle and
    /// second-cycle bodies share one strip implementation.
    private static func strippedHypothesis(_ raw: String) -> String {
        if raw.hasSuffix(".") {
            return String(raw.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw
    }
}

#endif
