#if canImport(SwiftUI)
import SwiftUI

// MARK: - Post Rep Verdict Card

enum CohesiveSummaryCopy {
    static let askNoum = "Ask Noum"
    static let seeDetails = "See details"
    static let done = "Done"
}

@available(iOS 17.0, *)
struct PostRepVerdictContent: Equatable {
    struct Win: Equatable {
        let headline: String
        let quote: String?
        let support: String?
        /// True only when `quote` is a verbatim, transcript-verified slice of
        /// the user's own words for this rep — either a `ProofMoment` that
        /// cleared `ProofMomentService`'s transcript-verify guard, or an
        /// on-tape eloquence snippet the evaluator detected in the user's
        /// speech. Drives the quiet "Your words" provenance line. Never set
        /// for coach-authored copy, so the affordance can never overclaim.
        var quoteIsVerified: Bool = false
    }

    struct Fix: Equatable {
        struct FillerChip: Equatable {
            let word: String
            let count: Int
        }

        enum Evidence: Equatable {
            case text(String)
            case fillerChips([FillerChip])
        }

        let headline: String
        let evidence: Evidence?
        let nextMove: String?
    }

    let readText: String
    let provenanceLabel: String?
    let thinEvidenceCopy: String?
    /// ONE bounded delivery read for this rep (move #8) — the
    /// `PostRepDeliveryReadLine` projection of the existing composure +
    /// confidence-marker fusion. Nil whenever either read failed its
    /// 2-channel evidence floor, and always suppressed on minimal-effort
    /// reps (a 5-second blurt can't earn a delivery read). Never numeric.
    let deliveryReadLine: String?
    let win: Win?
    let fix: Fix?

    static func make(
        note: PostRepCoachNote?,
        coachNote: CoachNote,
        winBullets: [WhatYouDidWellCard.Bullet],
        fixBullets: [WhatToImproveCard.Bullet],
        proof: ProofMoment?,
        isMinimalEffort: Bool,
        deliveryReadLine: String? = nil
    ) -> PostRepVerdictContent {
        PostRepVerdictContent(
            readText: readText(note: note, coachNote: coachNote, isMinimalEffort: isMinimalEffort),
            provenanceLabel: nil,
            thinEvidenceCopy: isMinimalEffort ? "Early read: one longer rep will make the next read clearer." : nil,
            deliveryReadLine: isMinimalEffort ? nil : deliveryReadLine,
            win: isMinimalEffort ? nil : win(proof: proof, bullets: winBullets),
            fix: isMinimalEffort ? nil : fix(coachNote: coachNote, bullets: fixBullets)
        )
    }

    private static func readText(note: PostRepCoachNote?, coachNote: CoachNote, isMinimalEffort: Bool) -> String {
        // A rep too short to read gets an honest "no usable rep" line, never
        // the confident momentum/leverage read — the coach must not claim
        // "clean delivery, your opening is the biggest opportunity" from a
        // rep that never happened.
        if isMinimalEffort {
            return "That rep was too short to read. Give me one full answer — 30 seconds or so — and I'll have something real to work with."
        }
        if let noteText = note?.noteText.trimmingCharacters(in: .whitespacesAndNewlines),
           !noteText.isEmpty {
            return noteText
        }

        let parts = [coachNote.momentum, coachNote.leverage]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }
        return "This rep gave a light read. One fuller take will make the next move sharper."
    }

    private static func win(proof: ProofMoment?, bullets: [WhatYouDidWellCard.Bullet]) -> Win? {
        if let proof {
            return Win(
                headline: proof.claim,
                quote: proof.quote,
                // The verified quote and its plain-language claim are the
                // evidence. Internal technique taxonomy adds a third label
                // without helping the user decide what to repeat.
                support: nil,
                quoteIsVerified: true
            )
        }
        guard let bullet = bullets.first else { return nil }
        switch bullet.evidence {
        case .text(let text):
            return Win(headline: bullet.headline, quote: nil, support: text)
        case .quote(let text, let source):
            return Win(headline: bullet.headline, quote: text, support: source, quoteIsVerified: true)
        case nil:
            return Win(headline: bullet.headline, quote: nil, support: nil)
        }
    }

    private static func fix(coachNote: CoachNote, bullets: [WhatToImproveCard.Bullet]) -> Fix? {
        let nextStep = coachNote.nextStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let bullet = bullets.first else {
            guard !nextStep.isEmpty else { return nil }
            return Fix(headline: "Next move", evidence: nil, nextMove: nextStep)
        }

        let fallbackNextMove = nextStepFromEvidence(bullet.evidence)
        return Fix(
            headline: bullet.headline,
            evidence: evidence(from: bullet.evidence),
            nextMove: nextStep.isEmpty ? fallbackNextMove : nextStep
        )
    }

    private static func evidence(from source: WhatToImproveCard.Evidence?) -> Fix.Evidence? {
        switch source {
        case .text(let text):
            return .text(text)
        case .fillerChips(let chips):
            return .fillerChips(chips.map { Fix.FillerChip(word: $0.0, count: $0.1) })
        case .nextStep, nil:
            return nil
        }
    }

    private static func nextStepFromEvidence(_ source: WhatToImproveCard.Evidence?) -> String? {
        guard case .nextStep(let text) = source else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Combined post-rep debrief

/// Pure visibility contract for the single post-rep debrief surface. The
/// content still comes from `PostRepVerdictContent`; this projection only
/// decides which named sections have something honest to show.
@available(iOS 17.0, *)
struct PostRepDebriefVisibility: Equatable {
    let showsWhatHeld: Bool
    let showsNextMove: Bool

    static func resolve(
        content: PostRepVerdictContent,
        hasReviewIntervention: Bool = false
    ) -> PostRepDebriefVisibility {
        PostRepDebriefVisibility(
            showsWhatHeld: content.win != nil,
            showsNextMove: content.fix != nil || hasReviewIntervention
        )
    }
}

/// The one coaching surface beneath the verdict hero. It composes the existing
/// read, win and fix selectors into a single reading flow instead of making the
/// user parse three adjacent cards. Analytical depth remains in Summary's
/// Details disclosure; this surface stays focused on comprehension and action.
@available(iOS 17.0, *)
struct PostRepDebriefCard: View {
    let content: PostRepVerdictContent
    var revisedChange: CoachCourseChange? = nil
    var reviewIntervention: CoachIntervention? = nil
    var onReview: (() -> Void)? = nil

    private var visibility: PostRepDebriefVisibility {
        .resolve(content: content, hasReviewIntervention: reviewIntervention != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if !visibility.showsWhatHeld && !visibility.showsNextMove {
                coachRead
            }

            if visibility.showsWhatHeld, let win = content.win {
                whatHeld(win)
                    .accessibilityIdentifier("summary.win.card")
            }

            if visibility.showsNextMove {
                if visibility.showsWhatHeld {
                    Divider()
                }
                nextMove
                    .accessibilityIdentifier("summary.fix.card")
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(PostRepReadCard.AccessibilityID.root)
        .accessibilityLabel("Coaching debrief for this rep")
    }

    private var coachRead: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let change = revisedChange {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.pro)
                        .accessibilityHidden(true)
                    Text(RevisedReadCard.headlineCopy(for: change))
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Revised coaching read. \(RevisedReadCard.headlineCopy(for: change))")
                .accessibilityIdentifier("summary.revisedRead.card")
            }

            Text(content.readText)
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let deliveryLine = content.deliveryReadLine {
                Text(deliveryLine)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Delivery read: \(deliveryLine)")
            }

            if let copy = content.thinEvidenceCopy {
                Text(copy)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func whatHeld(_ win: PostRepVerdictContent.Win) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            debriefHeading("What held", symbol: "checkmark.circle.fill", tint: AppColor.positive)

            Text(win.headline)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let quote = win.quote, !quote.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\"\(quote)\"")
                        .font(Typography.body.italic())
                        .foregroundStyle(AppColor.textPrimary.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                    if win.quoteIsVerified {
                        Text("Your words from this rep")
                            .font(Typography.captionSmall)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                .padding(.leading, Spacing.sm)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AppColor.positive.opacity(0.55))
                        .frame(width: 3)
                }
            }

            if let support = win.support, !support.isEmpty {
                Text(support)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var nextMove: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            debriefHeading("Next move", symbol: "arrow.up.right", tint: AppColor.caution)

            if let fix = content.fix {
                Text(fix.headline)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let evidence = fix.evidence {
                    fixEvidence(evidence)
                }
            }

            if let reviewIntervention, let onReview {
                Text(InterventionReviewPromptCard.headlineCopy(for: reviewIntervention))
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(CohesiveSummaryCopy.askNoum, action: onReview)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.pro)
                    .frame(minHeight: 44, alignment: .leading)
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("summary.interventionReview.cta")
                    .accessibilityHint("Opens Ask Noum to review whether the active focus is working.")
            } else if let next = content.fix?.nextMove, !next.isEmpty {
                Text(next)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func debriefHeading(_ text: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
        }
    }

    @ViewBuilder
    private func fixEvidence(_ evidence: PostRepVerdictContent.Fix.Evidence) -> some View {
        switch evidence {
        case .text(let text):
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .fillerChips(let chips):
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(chips, id: \.word) { chip in
                        Text("\"\(chip.word)\" · \(chip.count)")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(AppColor.textSecondary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            .background(AppColor.tagBackground, in: Capsule())
                    }
                }
            }
            .accessibilityLabel(
                chips.map { "\($0.word), \($0.count)" }.joined(separator: "; ")
            )
        }
    }
}

// MARK: - Concept icon chip (shared register)

/// 36pt gradient rounded-square icon chip — the per-concept coloured chip
/// register from docs/UX_VISUAL_DIRECTION.md (same shape as the Big Moment
/// sheet's type chips). White cards stay calm; the chip carries the
/// semantic colour: blue = coach/read, green = win/proof, amber = fix/next.
struct ConceptIconChip: View {
    let systemName: String
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
                tint.gradient,
                in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Slot 2 — THE READ

/// White card with the blue "read" chip: the coach's spoken read for this
/// rep. Carries the RULE-BASED provenance capsule, the bounded delivery
/// line and the thin-evidence disclaimer — honesty contracts kept as
/// truth, rendered without weight. When the just-finished memory rebuild
/// documents fresh user pushback, the coach's acknowledgment renders as a
/// one-line prefix INSIDE the read (the revision IS the read, not a sixth
/// card). Eligibility stays on `CoachContextBuilder.freshRevisedReadChange`;
/// copy stays on `RevisedReadCard`'s tested statics.
///
/// The score chip the old mega-card carried in this header is gone on
/// purpose: the hero ring directly above already renders the number.
@available(iOS 17.0, *)
struct PostRepReadCard: View {
    let content: PostRepVerdictContent
    var revisedChange: CoachCourseChange? = nil

    enum AccessibilityID {
        static let root = "summary.postRepVerdict"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let change = revisedChange {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColor.pro)
                        .padding(.top, 1)
                    Text(RevisedReadCard.headlineCopy(for: change))
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Revised coaching read. \(RevisedReadCard.headlineCopy(for: change))")
                .accessibilityIdentifier("summary.revisedRead.card")
            }

            Text(content.readText)
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let deliveryLine = content.deliveryReadLine {
                // One quiet delivery line — qualitative only, self-suppressed
                // below the evidence floor (nil = this block never mounts).
                Text(deliveryLine)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Delivery read: \(deliveryLine)")
            }

            if let copy = content.thinEvidenceCopy {
                Text(copy)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.root)
        .accessibilityLabel("Coach verdict for this rep")
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            ConceptIconChip(systemName: "eye", tint: AppColor.brandBlue)
            Text("THE READ")
                .font(Typography.captionSmall)
                .tracking(0.6)
                .foregroundStyle(AppColor.brandBlue)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Slot 3 — WIN

/// Green-tinted card with the verified quote rail. The quote arrives via
/// `PostRepVerdictContent.win`, which only ever carries a `ProofMoment`
/// that passed the transcript-verify guard (verified-quotes-only
/// invariant) or a deterministic bullet — never raw model output.
@available(iOS 17.0, *)
struct PostRepWinCard: View {
    let win: PostRepVerdictContent.Win

    // The transcript-verified quote is the most earned artifact on the
    // page — it gets its own entrance beat shortly after the card body
    // instead of arriving in the bulk render. One-shot; Reduce Motion
    // renders it statically in place.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var quoteRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: Spacing.sm) {
                ConceptIconChip(systemName: "checkmark.seal.fill", tint: AppColor.positive)
                Text("WIN")
                    .font(Typography.captionSmall)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.positive)
                Spacer(minLength: 0)
            }

            Text(win.headline)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let quote = win.quote, !quote.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(AppColor.positive.opacity(0.55))
                            .frame(width: 3)
                        Text("\"\(quote)\"")
                            .font(Typography.body.italic())
                            .foregroundStyle(AppColor.textPrimary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Provenance affordance: Noum's strongest technical edge is
                    // that this quote is a verbatim slice of the user's own rep,
                    // not generated copy. Surface that quietly — never as a
                    // "verified vs competitors" or parity claim. Only renders for
                    // transcript-verified quotes (see `Win.quoteIsVerified`).
                    if win.quoteIsVerified {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(AppColor.positive.opacity(0.7))
                            Text("Your words, this rep")
                                .font(Typography.captionSmall)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Your own words from this rep, verified against the recording")
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.positive.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                .opacity(quoteRevealed ? 1 : 0)
                .offset(y: quoteRevealed ? 0 : 6)
                .onAppear {
                    guard !quoteRevealed else { return }
                    if reduceMotion {
                        quoteRevealed = true
                    } else {
                        // coachLineStagger(1): the quote follows the card
                        // body by one reading beat — its own moment, no
                        // fabricated weight.
                        withAnimation(.coachLineStagger(1)) {
                            quoteRevealed = true
                        }
                    }
                }
            }

            if let support = win.support, !support.isEmpty {
                Text(support)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColor.cardBackground, AppColor.positive.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.positive.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("summary.win.card")
    }
}

// MARK: - Slot 4 — FIX FIRST

/// Amber-tinted card: one located fix with its evidence inline
/// (evidence-above-fold principle) and a single "Next move:" line.
/// On review-due reps the agreed case-file review IS the named next
/// move — one-line context + the Ask-Noum CTA replace the generic
/// next step, so the review never competes as a separate card.
/// `isReviewDue` gating + opener composition stay in `SummaryView` /
/// `CoachContextBuilder`; this card is pure presentation.
@available(iOS 17.0, *)
struct PostRepFixCard: View {
    let fix: PostRepVerdictContent.Fix?
    var reviewIntervention: CoachIntervention? = nil
    var onReview: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: Spacing.sm) {
                ConceptIconChip(systemName: "arrow.up.right", tint: AppColor.caution)
                Text("FIX FIRST")
                    .font(Typography.captionSmall)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.caution)
                Spacer(minLength: 0)
            }

            if let fix {
                Text(fix.headline)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let evidence = fix.evidence {
                    fixEvidence(evidence)
                }
            }

            if let reviewIntervention, let onReview {
                // Review-due rep: the agreed review is the next move.
                VStack(alignment: .leading, spacing: 6) {
                    nextMoveLine(InterventionReviewPromptCard.headlineCopy(for: reviewIntervention))
                    Button(action: onReview) {
                        HStack(spacing: 6) {
                            Text(CohesiveSummaryCopy.askNoum)
                                .font(Typography.caption.weight(.semibold))
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(AppColor.pro)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("summary.interventionReview.cta")
                    .accessibilityHint("Opens Ask Noum to review whether this focus is working.")
                }
            } else if let nextMove = fix?.nextMove, !nextMove.isEmpty {
                nextMoveLine(nextMove)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColor.cardBackground, AppColor.caution.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.caution.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("summary.fix.card")
    }

    private func nextMoveLine(_ text: String) -> some View {
        (Text("Next move: ")
            .font(Typography.caption.weight(.bold))
            .foregroundStyle(AppColor.caution)
         + Text(text)
            .font(Typography.caption.weight(.semibold))
            .foregroundStyle(AppColor.textPrimary))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Next move: \(text)")
    }

    @ViewBuilder
    private func fixEvidence(_ evidence: PostRepVerdictContent.Fix.Evidence) -> some View {
        switch evidence {
        case .text(let text):
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        case .fillerChips(let chips):
            VStack(alignment: .leading, spacing: 8) {
                Text("Most-used fillers")
                    .font(Typography.micro)
                    .foregroundStyle(AppColor.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chips, id: \.word) { chip in
                            HStack(spacing: 4) {
                                Text("\"\(chip.word)\"")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(chip.count)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(chipTint(count: chip.count), in: Capsule())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.04), in: Capsule())
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        }
    }

    private func chipTint(count: Int) -> Color {
        if count >= 4 { return AppColor.warning }
        if count >= 2 { return AppColor.caution }
        return .secondary
    }
}

// MARK: - Bottom exit panel

/// The ONE in-scroll exit, rendered as the LAST element of the summary
/// content (owner decision, docs/UX_VISUAL_DIRECTION.md: exit lives at
/// the BOTTOM — the user scrolls through the feedback before leaving).
/// "Done" stays a ghost/outline action. Its optional drill inputs remain
/// source-compatible for other call sites and compose the same shared
/// `SummaryDrillActionCard`; SummaryView now mounts that card beside
/// FIX FIRST and passes no drill here so Done remains the final action.
@available(iOS 17.0, *)
struct SummaryExitPanel: View {
    var drill: DrillRecommendationV2? = nil
    var legacyDrill: DrillRecommendation? = nil
    var onStartMiniDrill: ((DrillRecommendationV2) -> Void)? = nil
    var onStartDrill: ((DrillRecommendation) -> Void)? = nil
    let onDone: () -> Void
    var onPracticeAgain: (() -> Void)? = nil

    enum AccessibilityID {
        static let root = "summary.exitPanel"
        static let drill = "summary.exitPanel.drill"
        static let done = "summary.exitPanel.done"
        static let practiceAgain = "summary.exitPanel.practiceAgain"
        // Legacy drill-button ids preserved verbatim — pinned by
        // NoumUITests.swift; do not rename.
        static let startMiniDrill = "summary.postRepVerdict.startMiniDrill"
        static let startFullRetry = "summary.postRepVerdict.startFullRetry"
        static let fullRetry = "summary.postRepVerdict.fullRetry"
        static let secondaryMiniDrill = "summary.postRepVerdict.secondaryMiniDrill"
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if let drill {
                SummaryDrillActionCard(
                    drill: drill,
                    legacyDrill: legacyDrill,
                    onStartMiniDrill: onStartMiniDrill,
                    onStartDrill: onStartDrill
                )
            }

            Button(action: onDone) {
                Text(CohesiveSummaryCopy.done)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier(AccessibilityID.done)
            .accessibilityLabel("Done")
            .accessibilityHint("Finishes the review and returns home.")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.root)
    }
}

/// The shared prescribed-drill renderer used beside FIX FIRST and by the
/// backwards-compatible `SummaryExitPanel` drill API. It is deliberately
/// presentation-only: recommendation ownership and routing stay with callers.
@available(iOS 17.0, *)
struct SummaryDrillActionCard: View {
    let drill: DrillRecommendationV2
    var legacyDrill: DrillRecommendation? = nil
    var onStartMiniDrill: ((DrillRecommendationV2) -> Void)? = nil
    var onStartDrill: ((DrillRecommendation) -> Void)? = nil
    /// Optional finalized-action context. Legacy call sites leave these nil
    /// and keep the original title + constraint presentation.
    var reason: String? = nil
    var evidence: String? = nil
    var confidenceLabel: String? = nil

    static func primaryCTALabel(drillTitle: String) -> String {
        let title = drillTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Start practice" : "Start \(title)"
    }

    private var primaryCTALabel: String {
        Self.primaryCTALabel(drillTitle: drill.title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if reason != nil || evidence != nil || confidenceLabel != nil {
                prescriptionEyebrow(confidenceLabel: confidenceLabel)
            }

            Text(drill.title)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(reason ?? drill.constraint)
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if reason != nil {
                Text("Target: \(drill.constraint)")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let evidence, !evidence.isEmpty {
                Text(evidence)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if drill.format == .miniDrill, let onStartMiniDrill {
                Button {
                    onStartMiniDrill(drill)
                } label: {
                    ctaLabel(primaryCTALabel, systemImage: "bolt.fill")
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier(SummaryExitPanel.AccessibilityID.startMiniDrill)
                .accessibilityHint("Starts the short drill Noum prescribed from this rep.")
            } else if drill.format != .miniDrill, let onStartDrill, let legacyDrill {
                Button {
                    onStartDrill(legacyDrill)
                } label: {
                    ctaLabel(primaryCTALabel, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier(SummaryExitPanel.AccessibilityID.startFullRetry)
                .accessibilityHint("Starts a full retry of the recommended practice.")
            } else if let onStartMiniDrill {
                Button {
                    onStartMiniDrill(drill)
                } label: {
                    ctaLabel(primaryCTALabel, systemImage: "bolt.fill")
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier(SummaryExitPanel.AccessibilityID.startMiniDrill)
                .accessibilityHint("Starts the short drill Noum prescribed from this rep.")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(SummaryExitPanel.AccessibilityID.drill)
    }

    private func ctaLabel(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(Typography.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .foregroundStyle(.white)
        .background(AppColor.brandBlue, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private func prescriptionEyebrow(confidenceLabel: String?) -> some View {
        HStack(spacing: Spacing.xs) {
            Text("Next rep")
                .font(Typography.micro.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
                .textCase(.uppercase)
                .tracking(0.8)

            if let confidenceLabel {
                Text(confidenceLabel)
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xxs)
                    .background(AppColor.innerSurface, in: Capsule())
            }
        }
    }
}

/// The one Summary action renderer. Finalized drill actions delegate to the
/// existing mini/full drill card so specialized drill behavior stays intact;
/// mode-level actions use one restrained full-rep card and the shared Summary
/// destination router exposed by `SummaryPrescriptionProjection`.
@available(iOS 17.0, *)
struct SummaryPrescriptionActionCard: View {
    let prescription: SummaryPrescriptionProjection
    var legacyDrill: DrillRecommendation? = nil
    var onStartMiniDrill: ((DrillRecommendationV2) -> Void)? = nil
    var onStartDrill: ((DrillRecommendation) -> Void)? = nil
    var resolveModeAvailability: (() -> NextActionModeAvailability)? = nil
    var onShowFullRep: ((PracticeMode) -> Void)? = nil
    var onStartFullRep: ((PracticeModeLaunchProjection) -> Void)? = nil

    @ViewBuilder
    var body: some View {
        switch prescription.kind {
        case .drill(let drill):
            SummaryDrillActionCard(
                drill: drill,
                legacyDrill: legacyDrill,
                onStartMiniDrill: onStartMiniDrill,
                onStartDrill: onStartDrill,
                reason: prescription.reason,
                evidence: prescription.evidence,
                confidenceLabel: prescription.confidenceLabel
            )

        case .fullRep(let mode, _, _):
            SummaryFullRepActionCard(
                title: prescription.title,
                reason: prescription.reason,
                evidence: prescription.evidence,
                confidenceLabel: prescription.confidenceLabel,
                mode: mode,
                resolveLaunch: {
                    prescription.launch(
                        modeAvailabilityAtTap: resolveModeAvailability?()
                            ?? prescription.modeAvailability
                    )
                },
                onShown: onShowFullRep,
                onStart: onStartFullRep
            )
        }
    }
}

/// Restrained renderer for a finalized full-rep prescription. It does not own
/// recommendation state or navigation; the active Summary records exposure and
/// forwards the routed destination through its existing callback.
@available(iOS 17.0, *)
private struct SummaryFullRepActionCard: View {
    let title: String
    let reason: String
    let evidence: String?
    let confidenceLabel: String?
    let mode: PracticeMode
    let resolveLaunch: () -> PracticeModeLaunchProjection?
    let onShown: ((PracticeMode) -> Void)?
    let onStart: ((PracticeModeLaunchProjection) -> Void)?

    private var tint: Color { AppColor.tint(for: mode) }
    private var ctaLabel: String { "Start \(mode.displayLabel)" }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Text("Next rep")
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(tint)
                    .textCase(.uppercase)
                    .tracking(0.8)

                if let confidenceLabel {
                    Text(confidenceLabel)
                        .font(Typography.micro.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .background(AppColor.innerSurface, in: Capsule())
                }
            }

            Text(title)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(reason)
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let evidence, !evidence.isEmpty {
                Text(evidence)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let onStart {
                Button {
                    guard let launch = resolveLaunch() else { return }
                    onStart(launch)
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: mode.iconName)
                            .font(Typography.subheadline.weight(.semibold))
                        Text(ctaLabel)
                            .font(Typography.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .foregroundStyle(.white)
                    .background(tint, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier(SummaryExitPanel.AccessibilityID.fullRetry)
                .accessibilityLabel(ctaLabel)
                .accessibilityHint("Starts the full rep Noum prescribed from this result.")
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.08), radius: 10, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(SummaryExitPanel.AccessibilityID.drill)
        .onAppear {
            guard resolveLaunch() != nil, onStart != nil else { return }
            onShown?(mode)
        }
        .onChange(of: mode) { _, newMode in
            guard resolveLaunch() != nil, onStart != nil else { return }
            onShown?(newMode)
        }
    }
}
#endif
