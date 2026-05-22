#if canImport(SwiftUI)
import SwiftUI

// MARK: - What You Did Well Card
//
// Hero observational card. Surfaces 1–3 bullets describing what worked
// on this specific rep, sourced from existing evaluation systems:
//
//   • CoachNote.momentum — the primary observational claim (verdict
//     engine output, always present, voice-shaped)
//   • Good-rated FeedbackCategory dimensions (Opening, Structure,
//     etc.) — concrete per-axis wins
//   • Eloquence findings — rhetorical moves the engine detected
//   • AICoachFeedback.strengths — when the user has generated a
//     coach read
//
// Each bullet is tap-to-reveal: chevron expands an evidence row
// underneath with the supporting detail (per-category note, snippet,
// detected device).
//
// Empty-state safety: if no bullet can be sourced (very short rep,
// no detail), the card hides itself entirely. We don't fabricate
// praise — silence is better than fake feedback.

@available(iOS 17.0, *)
struct WhatYouDidWellCard: View {
    let coachNote: CoachNote
    let feedbackCategories: [FeedbackCategory]
    let eloquenceFindings: [EloquenceFinding]
    let aiFeedback: AICoachFeedback?
    let isMinimalEffort: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedBulletIDs: Set<String> = []

    private var bullets: [Bullet] {
        WhatYouDidWellCard.computeBullets(
            coachNote: coachNote,
            feedbackCategories: feedbackCategories,
            eloquenceFindings: eloquenceFindings,
            aiFeedback: aiFeedback,
            isMinimalEffort: isMinimalEffort
        )
    }

    /// Pure bullet selector. Extracted from the View body so the
    /// design contract (momentum first, ≤ 2 category wins, ≤ 1
    /// eloquence finding, AI strength only when there's headroom,
    /// hard 3-bullet ceiling) can be locked by unit tests without
    /// spinning up a SwiftUI runtime. Tests in
    /// `WhatYouDidWellBulletSelectorTests` pin every branch.
    static func computeBullets(
        coachNote: CoachNote,
        feedbackCategories: [FeedbackCategory],
        eloquenceFindings: [EloquenceFinding],
        aiFeedback: AICoachFeedback?,
        isMinimalEffort: Bool
    ) -> [Bullet] {
        // Minimal-effort sessions don't earn observational praise; the
        // CoachNote logic already softens its momentum line, but to be
        // safe we hide the whole card on those reps so we never end up
        // with "Strong opening" on a 4-second blurt.
        guard !isMinimalEffort else { return [] }

        var out: [Bullet] = []

        // 1) Momentum — the verdict engine's "what's getting stronger"
        //    line. Already voice-shaped, always present. No evidence
        //    underlay because the claim IS the evidence at this level.
        let momentum = coachNote.momentum.trimmingCharacters(in: .whitespacesAndNewlines)
        if !momentum.isEmpty {
            out.append(
                Bullet(
                    id: "momentum",
                    icon: "arrow.up.right",
                    iconTint: AppColor.positive,
                    headline: momentum,
                    evidence: nil
                )
            )
        }

        // 2) Per-dimension wins. Only `.good` ratings, because `.ok` is
        //    actually a mild improvement signal — surfacing it as a win
        //    would punish accuracy. Cap at two so we don't compete with
        //    the momentum line.
        let goodCategories = feedbackCategories.filter { $0.rating == .good }.prefix(2)
        for category in goodCategories {
            out.append(
                Bullet(
                    id: "category-\(category.dimension)",
                    icon: "checkmark.circle.fill",
                    iconTint: AppColor.positive,
                    headline: "\(category.dimension) felt solid.",
                    evidence: category.note.isEmpty
                        ? nil
                        : .text(category.note)
                )
            )
        }

        // 3) Eloquence findings — rhetorical moves the engine caught.
        //    Cap at one so the card stays under three bullets total
        //    when the rep also has a momentum + category win.
        if let finding = eloquenceFindings.first {
            let snippet = finding.snippet.trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(
                Bullet(
                    id: "eloquence-\(finding.device.rawValue)",
                    icon: "quote.opening",
                    iconTint: AppColor.brandBlue,
                    headline: "\(finding.device.title) landed.",
                    evidence: snippet.isEmpty
                        ? .text(finding.coachLine)
                        : .quote(text: snippet, source: finding.coachLine)
                )
            )
        }

        // 4) AI strengths — only if we still have headroom (the bullets
        //    above didn't already saturate). Cap at 3 total bullets.
        if out.count < 3, let aiFeedback, let firstStrength = aiFeedback.strengths.first {
            let trimmed = firstStrength.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                out.append(
                    Bullet(
                        id: "ai-strength",
                        icon: "sparkles",
                        iconTint: AppColor.brandBlue,
                        headline: trimmed,
                        evidence: nil
                    )
                )
            }
        }

        return Array(out.prefix(3))
    }

    var body: some View {
        let items = bullets
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                VStack(spacing: 10) {
                    ForEach(items) { bullet in
                        bulletRow(bullet)
                    }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(AppColor.positive.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
            .accessibilityIdentifier("summary.whatYouDidWell")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.positive)
            Text("What you did well")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
        }
    }

    @ViewBuilder
    private func bulletRow(_ bullet: Bullet) -> some View {
        let isExpanded = expandedBulletIDs.contains(bullet.id)
        let canExpand = bullet.evidence != nil

        VStack(alignment: .leading, spacing: 8) {
            Button {
                guard canExpand else { return }
                toggle(bullet.id)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: bullet.icon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(bullet.iconTint)
                        .frame(width: 18, alignment: .center)
                        .padding(.top, 2)

                    Text(bullet.headline)
                        .font(Typography.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)

                    if canExpand {
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .padding(.top, 4)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canExpand)
            .accessibilityHint(canExpand ? "Double tap to see why." : "")

            if isExpanded, let evidence = bullet.evidence {
                evidenceView(evidence)
                    .padding(.leading, 28)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func evidenceView(_ evidence: Evidence) -> some View {
        switch evidence {
        case .text(let text):
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

        case .quote(let text, let source):
            VStack(alignment: .leading, spacing: 6) {
                Text("\u{201C}\(text)\u{201D}")
                    .font(Typography.body.italic())
                    .foregroundStyle(AppColor.brandBlue.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !source.isEmpty {
                    Text(source)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        }
    }

    private func toggle(_ id: String) {
        let animation: Animation? = reduceMotion ? nil : .standardSpring
        if reduceMotion {
            if expandedBulletIDs.contains(id) {
                expandedBulletIDs.remove(id)
            } else {
                expandedBulletIDs.insert(id)
            }
        } else {
            withAnimation(animation) {
                if expandedBulletIDs.contains(id) {
                    expandedBulletIDs.remove(id)
                } else {
                    expandedBulletIDs.insert(id)
                }
            }
        }
    }

    // MARK: - Data shapes

    struct Bullet: Identifiable {
        let id: String
        let icon: String
        let iconTint: Color
        let headline: String
        let evidence: Evidence?
    }

    enum Evidence {
        case text(String)
        case quote(text: String, source: String)
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("What you did well — full") {
    WhatYouDidWellCard(
        coachNote: CoachNote(
            momentum: "Your structure tightened — clear opener, one solid example, clean close.",
            leverage: "Pace ran a touch fast on the middle section.",
            nextStep: "Try a one-beat pause before each new point."
        ),
        feedbackCategories: [
            FeedbackCategory(dimension: "Opening", rating: .good, note: "Confident first sentence, no preamble."),
            FeedbackCategory(dimension: "Structure", rating: .good, note: "Tight three-part flow."),
            FeedbackCategory(dimension: "Pace", rating: .ok, note: "Slightly rushed in the middle.")
        ],
        eloquenceFindings: [
            EloquenceFinding(
                device: .tricolon,
                snippet: "clarity, courage, and conviction",
                coachLine: "Lists of three feel complete."
            )
        ],
        aiFeedback: nil,
        isMinimalEffort: false
    )
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("What you did well — momentum only") {
    WhatYouDidWellCard(
        coachNote: CoachNote(
            momentum: "Cleaner delivery than your recent average.",
            leverage: "",
            nextStep: ""
        ),
        feedbackCategories: [],
        eloquenceFindings: [],
        aiFeedback: nil,
        isMinimalEffort: false
    )
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("What you did well — minimal effort hides") {
    WhatYouDidWellCard(
        coachNote: CoachNote(momentum: "x", leverage: "", nextStep: ""),
        feedbackCategories: [],
        eloquenceFindings: [],
        aiFeedback: nil,
        isMinimalEffort: true
    )
    .padding()
    .background(AppColor.screenBackground)
}
#endif

#endif
