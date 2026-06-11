#if canImport(SwiftUI)
import SwiftUI

// MARK: - Post Rep Verdict Card

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
            readText: readText(note: note, coachNote: coachNote),
            provenanceLabel: note?.isAIBacked == false ? "RULE-BASED" : nil,
            thinEvidenceCopy: isMinimalEffort ? "Early read: one longer rep will sharpen the diagnosis." : nil,
            deliveryReadLine: isMinimalEffort ? nil : deliveryReadLine,
            win: win(proof: proof, bullets: winBullets),
            fix: fix(coachNote: coachNote, bullets: fixBullets)
        )
    }

    private static func readText(note: PostRepCoachNote?, coachNote: CoachNote) -> String {
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
                support: proof.technique,
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
            if let label = content.provenanceLabel {
                Text(label)
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
/// (evidence-above-fold principle) and a single "Next move ·" line.
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
                            Text("Review with coach")
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
                    .accessibilityHint("Opens Ask Noum to review whether the active intervention is working.")
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
        (Text("Next move · ")
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

// MARK: - Slot 5 — Bottom exit panel

/// The ONE in-scroll exit, rendered as the LAST element of the summary
/// content (owner decision, docs/UX_VISUAL_DIRECTION.md: exit lives at
/// the BOTTOM — the user scrolls through the feedback before leaving).
/// Re-homes the old `PostRepVerdictCard.drillCTA` verbatim: same
/// miniDrill / full-retry format split, same closures, and the SAME
/// button accessibility ids (`summary.postRepVerdict.startMiniDrill` /
/// `startFullRetry` / `fullRetry`) pinned by NoumUITests. The primary
/// pill is the approved blue; "Done" stays a ghost/outline secondary.
/// IM reps pass no drill (IMOneMoveCard already carries Try Again /
/// New Chat) and render Done only.
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
        VStack(spacing: 14) {
            if let drill {
                drillBlock(drill)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AccessibilityID.drill)
            }

            Button(action: onDone) {
                Text("Done")
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(AppColor.textSecondary.opacity(0.35), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier(AccessibilityID.done)
            .accessibilityLabel("Done")
            .accessibilityHint("Finishes the review and returns home.")

            if let onPracticeAgain {
                Button(action: onPracticeAgain) {
                    Text("Practice again")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.practiceAgain)
                .accessibilityLabel("Practice again")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.root)
    }

    // The old drillCTA, re-homed. Format split + closures unchanged;
    // the primary pill takes the approved blue (UX_VISUAL_DIRECTION:
    // "primary Start 45-second drill (blue pill)").
    @ViewBuilder
    private func drillBlock(_ drill: DrillRecommendationV2) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(drill.title)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(drill.constraint)
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if drill.format == .miniDrill, let onStartMiniDrill {
                Button {
                    onStartMiniDrill(drill)
                } label: {
                    ctaLabel("Start 45s drill", systemImage: "bolt.fill")
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier(AccessibilityID.startMiniDrill)
                .accessibilityHint("Starts the short drill Noum prescribed from this rep.")

                if let onStartDrill, let legacyDrill {
                    Button {
                        onStartDrill(legacyDrill)
                    } label: {
                        Text("Full retry")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.fullRetry)
                    .accessibilityHint("Starts a full retry of the recommended practice.")
                }
            } else if drill.format != .miniDrill, let onStartDrill, let legacyDrill {
                Button {
                    onStartDrill(legacyDrill)
                } label: {
                    ctaLabel("Start full retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier(AccessibilityID.startFullRetry)
                .accessibilityHint("Starts a full retry of the recommended practice.")

                if let onStartMiniDrill {
                    Button {
                        onStartMiniDrill(drill)
                    } label: {
                        Text("45s drill")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.secondaryMiniDrill)
                    .accessibilityHint("Starts the short drill Noum prescribed from this rep.")
                }
            } else if let onStartMiniDrill {
                Button {
                    onStartMiniDrill(drill)
                } label: {
                    ctaLabel("Start 45s drill", systemImage: "bolt.fill")
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier(AccessibilityID.startMiniDrill)
                .accessibilityHint("Starts the short drill Noum prescribed from this rep.")
            }
        }
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
}
#endif
