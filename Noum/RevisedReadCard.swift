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
        let headline = RevisedReadCard.headlineCopy(for: change)
        let bodyLine = RevisedReadCard.bodyCopy(workingHypothesis: workingHypothesis)
        return VStack(alignment: .leading, spacing: 10) {
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

            Text(headline)
                .font(Typography.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(bodyLine)
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
        .accessibilityLabel("Revised coaching read. \(headline) \(bodyLine)")
        .accessibilityIdentifier("summary.revisedRead.card")
    }

    // MARK: - Copy (pure, locked by tests)

    /// Headline copy on the FIRST-cycle pushback. The user sees their own
    /// action named ("you flagged") so the line reads as the coach
    /// acknowledging the pushback, not as a generic "your plan changed"
    /// notification. Brand-voice compliant: no exclamation, no apology,
    /// no "we", no "Let's". Kept as a static constant for back-compat
    /// with surfaces that test the canonical first-cycle phrase.
    static let headlineCopy: String = "You flagged the prior read as off."

    /// Round-33 headline picker. When the carrying course change is the
    /// SECOND cycle of a user pushback (the dropped `.rejected` ack was
    /// on a hypothesis that was itself the rebuilt read from a prior
    /// pushback), the user sees a second-cycle phrase that acknowledges
    /// "you flagged the rebuilt read as off TOO." The first-cycle phrase
    /// would read as if this were a fresh pushback — and the user would
    /// notice the discrepancy, because their last rebuild already had a
    /// REVISED READ card on it. Closes the loop honestly: the card names
    /// the second pushback as the second pushback.
    /// Brand-voice compliant: no exclamation, no apology, no "we", no
    /// "Let's", no celebratory framing of a second adapt.
    ///
    /// Round-34 lift: delegates to `CoachCourseChange.caseFileHeadline`
    /// so the post-rep summary AND the Profile-tab `CaseReviewCard` read
    /// the same user-voiced phrase for the rebuild lineage. The card's
    /// upstream gate (`SummaryView.freshRevisedReadChange`) guarantees
    /// `change.documentsUserPushback == true` on every mount, so the
    /// engine-only fall-through arm of `caseFileHeadline` is unreachable
    /// from this surface — the picker reads as pushback-only here even
    /// though the underlying property is broader.
    static func headlineCopy(for change: CoachCourseChange) -> String {
        change.caseFileHeadline
    }

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

// MARK: - RevisedReadConfirmationCard
//
// Round-37 sibling of `RevisedReadCard` — the symmetric closure of the
// rejection-rebuild lifecycle on the post-rep summary surface.
//
// Round 28 surfaced `RevisedReadCard` on the rep that folded a user-tapped
// `.rejected` ack into a rebuilt working hypothesis. Round 36 landed the
// engine half of the matching closure: when the user later lodges a
// `.confirmed` ack on the rebuilt read, `CoachMemoryEngine.build(...)`
// appends a confirmation `CoachCourseChange` to `adaptationLog` so the
// case file carries the lock-in event as durably as it carries the
// rejections.
//
// Until now that closure was a chat-context and Profile-card signal only.
// The post-rep summary — the surface where the rebuild lifecycle BEGAN
// for the user — went silent on the rep that locked it in, so the user
// who skimmed only the summary never saw their acceptance acknowledged
// in the same family of cards. Round 37 closes that gap with a card that
// reads as the family member of `RevisedReadCard`: same outer chrome,
// distinct glyph + eyebrow ("REVISED READ · CONFIRMED"), and a calm
// "Here's the locked-in read: …" body line so the rebuild lineage has
// the same acknowledged closure on the summary surface it began on.
//
// Why this card exists (vision alignment):
//   • Coach-parity stage #4 (Adaptation). `docs/VISION.md`: the adaptation
//     loop must "compare response across multiple attempts and either
//     reinforce, vary, or replace the intervention with an explained
//     rationale." Round 36 records the reinforce branch in the durable
//     log; round 37 surfaces it to the user on the rep that locked it in.
//   • Pillar #5 (Personalized coaching). A real coach acknowledges when
//     the client accepts a read. Silently treating the lock-in like any
//     other rep would read as the coach not noticing.
//   • Pillar #4 (Believable progress). Quoting the user's locked-in
//     working hypothesis (via `workingHypothesis`) lands the closure as
//     continuous, evidenced coaching, not a fresh paint of telemetry.
//
// Why this card is restrained:
//   • No CTA — the existing `TalkToNoumCTACard` sits a few rows below
//     and already routes the user into Ask Noum if they want to talk
//     about the locked-in read in voice.
//   • No celebration, no exclamation, no "Let's". Brand-voice rules
//     match `RevisedReadCard` / `CaseReviewCard` /
//     `InterventionReviewPromptCard`.
//   • Renders only when the latest `CoachCourseChange` is BOTH a
//     `documentsRebuildConfirmation` entry AND fresh (i.e. appended on
//     this exact rebuild). On every subsequent rep the entry still
//     exists in `memory.adaptationLog` but is no longer fresh, so the
//     card does not re-show. The Profile-tab `CaseReviewCard` keeps
//     the long-term history surface via `caseFileHeadline`.
//   • Mutually exclusive with `RevisedReadCard`: the upstream gate
//     reads `documentsRebuildConfirmation`, which is false on every
//     pushback entry; the pushback card's gate reads
//     `documentsUserPushback`, which is false on every confirmation
//     entry. The two cards can never both mount in the same rep.
//
// Eligibility predicate (pure, locked by tests):
//   • `memory.adaptationLog?.last` exists.
//   • `change.documentsRebuildConfirmation == true`.
//   • `change.isFresh(comparedTo: memory.updatedAt) == true`.

@available(iOS 17.0, *)
struct RevisedReadConfirmationCard: View {

    let change: CoachCourseChange
    let workingHypothesis: String?

    var body: some View {
        let headline = RevisedReadConfirmationCard.headlineCopy
        let bodyLine = RevisedReadConfirmationCard.bodyCopy(workingHypothesis: workingHypothesis)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.pro)
                Text("REVISED READ · CONFIRMED")
                    .font(Typography.captionSmall)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.pro)
                Spacer(minLength: 0)
            }

            Text(headline)
                .font(Typography.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(bodyLine)
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
        .accessibilityLabel("Revised coaching read, confirmed. \(headline) \(bodyLine)")
        .accessibilityIdentifier("summary.revisedRead.confirmation.card")
    }

    // MARK: - Copy (pure, locked by tests)

    /// Headline copy on a confirmation entry. The user reads their own
    /// action named ("you confirmed") so the line lands as the coach
    /// acknowledging the acceptance, not a generic "plan stayed the
    /// same" notification. Brand-voice compliant: no exclamation, no
    /// celebration, no "we", no "Let's". Phrasing matches
    /// `CoachCourseChange.caseFileHeadline`'s round-36 confirmation
    /// branch byte-for-byte so the cross-surface read of the rebuild
    /// lineage stays consistent (post-rep summary, Profile card).
    static let headlineCopy: String = "You confirmed the rebuilt read."

    /// Body copy. Names the locked-in working hypothesis when one
    /// exists so the user reads what the coach has settled on. Falls
    /// back to a calm "the coach noted it" line when the rebuild
    /// produced no current hypothesis (rare — typically only with no
    /// current lever). Trims + strips a trailing period so the body
    /// line never reads as two sentences ending in one when the
    /// hypothesis already ends with `.`.
    static func bodyCopy(workingHypothesis: String?) -> String {
        guard let raw = workingHypothesis?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return "The coach noted it and is keeping the read."
        }
        let stripped: String
        if raw.hasSuffix(".") {
            stripped = String(raw.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            stripped = raw
        }
        return "Here's the locked-in read: \(stripped)."
    }
}

#endif
