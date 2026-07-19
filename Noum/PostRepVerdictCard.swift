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
    /// Owned here since the 2026-07-11 cohesion pass folded the old read/win/
    /// fix trio into this one card. The identifier value is unchanged so the
    /// existing UI tests keep resolving the same surface.
    enum AccessibilityID {
        static let root = "summary.postRepVerdict"
    }

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
        .accessibilityIdentifier(AccessibilityID.root)
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
        // "What held" / "Next move" are the two headings a VoiceOver user
        // navigates this card by. The card is `children: .contain`, so the
        // heading stays its own element and the rotor can reach it.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
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
