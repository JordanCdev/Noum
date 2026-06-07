#if canImport(SwiftUI)
import SwiftUI

// MARK: - Post Rep Verdict Card

@available(iOS 17.0, *)
struct PostRepVerdictContent: Equatable {
    struct Win: Equatable {
        let headline: String
        let quote: String?
        let support: String?
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
    let win: Win?
    let fix: Fix?

    static func make(
        note: PostRepCoachNote?,
        coachNote: CoachNote,
        winBullets: [WhatYouDidWellCard.Bullet],
        fixBullets: [WhatToImproveCard.Bullet],
        proof: ProofMoment?,
        isMinimalEffort: Bool
    ) -> PostRepVerdictContent {
        PostRepVerdictContent(
            readText: readText(note: note, coachNote: coachNote),
            provenanceLabel: note?.isAIBacked == false ? "RULE-BASED" : nil,
            thinEvidenceCopy: isMinimalEffort ? "Early read: one longer rep will sharpen the diagnosis." : nil,
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
                support: proof.technique
            )
        }
        guard let bullet = bullets.first else { return nil }
        switch bullet.evidence {
        case .text(let text):
            return Win(headline: bullet.headline, quote: nil, support: text)
        case .quote(let text, let source):
            return Win(headline: bullet.headline, quote: text, support: source)
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

@available(iOS 17.0, *)
struct PostRepVerdictCard: View {
    let content: PostRepVerdictContent
    let scoreValue: Int
    let scoreAccent: Color
    let drill: DrillRecommendationV2
    let legacyDrill: DrillRecommendation
    var onStartMiniDrill: (DrillRecommendationV2) -> Void
    var onStartDrill: ((DrillRecommendation) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Text(content.readText)
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let copy = content.thinEvidenceCopy {
                Text(copy)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().opacity(0.45)

            if let win = content.win {
                winSection(win)
            }

            if let fix = content.fix {
                if content.win != nil {
                    Divider().opacity(0.30)
                }
                fixSection(fix)
            }

            Divider().opacity(0.45)

            drillCTA
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.pro.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: AppColor.pro.opacity(0.06), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("summary.postRepVerdict")
        .accessibilityLabel("Coach verdict for this rep")
    }

    private var header: some View {
        HStack(spacing: 8) {
            NoumCharacter.Inline(size: 22, mood: .coaching, tint: AppColor.pro)
            Text("THE READ")
                .font(Typography.captionSmall)
                .tracking(0.6)
                .foregroundStyle(AppColor.pro)
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
            Text("\(scoreValue)/10")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(scoreAccent)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(scoreAccent.opacity(0.10), in: Capsule())
        }
    }

    private func winSection(_ win: PostRepVerdictContent.Win) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Win", icon: "checkmark.seal.fill", tint: AppColor.positive)
            Text(win.headline)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let quote = win.quote, !quote.isEmpty {
                Text("\"\(quote)\"")
                    .font(Typography.body.italic())
                    .foregroundStyle(AppColor.brandBlue.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }
            if let support = win.support, !support.isEmpty {
                Text(support)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func fixSection(_ fix: PostRepVerdictContent.Fix) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Fix first", icon: "scope", tint: AppColor.caution)
            Text(fix.headline)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let evidence = fix.evidence {
                fixEvidence(evidence)
            }
            if let nextMove = fix.nextMove, !nextMove.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColor.brandBlue)
                        .padding(.top, 1)
                    Text(nextMove)
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.brandBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }
        }
    }

    private func sectionLabel(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
            Text(text)
                .font(Typography.micro)
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .foregroundStyle(tint)
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

    private var drillCTA: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(drill.title)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(drill.constraint)
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if drill.format == .miniDrill {
                Button {
                    onStartMiniDrill(drill)
                } label: {
                    ctaLabel("Start 45s drill", systemImage: "bolt.fill", tint: drill.tint)
                }
                .buttonStyle(.pressable)

                if let onStartDrill {
                    Button {
                        onStartDrill(legacyDrill)
                    } label: {
                        Text("Full retry")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            } else if let onStartDrill {
                Button {
                    onStartDrill(legacyDrill)
                } label: {
                    ctaLabel("Start full retry", systemImage: "arrow.clockwise", tint: drill.tint)
                }
                .buttonStyle(.pressable)

                Button {
                    onStartMiniDrill(drill)
                } label: {
                    Text("45s drill")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onStartMiniDrill(drill)
                } label: {
                    ctaLabel("Start 45s drill", systemImage: "bolt.fill", tint: drill.tint)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private func ctaLabel(_ text: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(Typography.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .foregroundStyle(.white)
        .background(tint, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private func chipTint(count: Int) -> Color {
        if count >= 4 { return AppColor.warning }
        if count >= 2 { return AppColor.caution }
        return .secondary
    }
}
#endif
