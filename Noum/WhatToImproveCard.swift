#if canImport(SwiftUI)
import SwiftUI

// MARK: - What To Improve Card
//
// Hero observational card. Surfaces 1–3 bullets describing what to
// sharpen on the next rep, sourced from existing evaluation systems:
//
//   • CoachNote.leverage — the primary observational claim
//   • Could-improve / OK rated FeedbackCategory dimensions
//   • Filler issue (only when count is meaningful)
//   • Pace issue (only when WPM is outside the soft band)
//   • AICoachFeedback.keyImprovement — when the user has generated
//     a coach read
//
// Each bullet is tap-to-reveal: chevron expands an evidence row
// underneath with the supporting detail (per-category note, filler
// breakdown chips, WPM number + comparison context).
//
// Coaching-logic invariants honored:
//   • Weak evidence → softer feedback. The CoachNote engine already
//     softens its `leverage` line on low-signal reps; we also hide
//     the whole card on minimal-effort reps so we never punish a
//     5-second blurt.
//   • Never punish semantically valid speech. Filler issue only
//     surfaces when the *detector* says there's a count worth
//     surfacing (≥2 on the rep).
//   • Empty state → hide. If no bullet can be sourced, no card. A
//     genuinely clean rep doesn't need a "to improve" placeholder.

@available(iOS 17.0, *)
struct WhatToImproveCard: View {
    let coachNote: CoachNote
    let feedbackCategories: [FeedbackCategory]
    let aiFeedback: AICoachFeedback?
    let transcriptText: String
    let effectiveFillerCount: Int
    let effectiveDuration: TimeInterval
    let transcriptWordCount: Int
    let isMinimalEffort: Bool
    /// Exact saved row behind this presentation. Filler and pace bullets are
    /// omitted when the row is absent or fails the shared historical metric
    /// boundary; independent leverage/category/AI bullets remain available.
    var metricSession: PracticeSession? = nil
    /// M21: the user's declared focus for this rep, if any. When a
    /// bullet aligns, an "You aimed for this" chip renders beneath
    /// the headline.
    var intentFocus: CoachingPriority? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedBulletIDs: Set<String> = []

    private var bullets: [Bullet] {
        WhatToImproveCard.computeBullets(
            coachNote: coachNote,
            feedbackCategories: feedbackCategories,
            aiFeedback: aiFeedback,
            transcriptText: transcriptText,
            effectiveFillerCount: effectiveFillerCount,
            effectiveDuration: effectiveDuration,
            transcriptWordCount: transcriptWordCount,
            isMinimalEffort: isMinimalEffort,
            customFillerWords: ClutchWordStore.shared.customFillerWords,
            metricSession: metricSession
        )
    }

    /// Pure bullet selector. Extracted from the View body so the
    /// design contract (leverage first, filler surfaces at ≥2, ≤ 2
    /// dedup'd category needs-work entries, pace anomaly only with
    /// headroom + band-out signal, AI improvement at tail, hard
    /// 3-bullet ceiling) can be locked by unit tests without spinning
    /// up SwiftUI. Custom filler words flow in as a parameter so the
    /// suite doesn't have to mutate the `ClutchWordStore` singleton.
    /// Tests in `WhatToImproveBulletSelectorTests` pin every branch.
    static func computeBullets(
        coachNote: CoachNote,
        feedbackCategories: [FeedbackCategory],
        aiFeedback: AICoachFeedback?,
        transcriptText: String,
        effectiveFillerCount: Int,
        effectiveDuration: TimeInterval,
        transcriptWordCount: Int,
        isMinimalEffort: Bool,
        customFillerWords: Set<String>,
        metricSession: PracticeSession? = nil
    ) -> [Bullet] {
        guard !isMinimalEffort else { return [] }

        let qualifiedFillerBurden = metricSession.flatMap(FillerBurden.quantityQualified)
        let qualifiedPaceWPM = metricSession.flatMap(SessionQualifier.quantityQualifiedWordsPerMinute)

        var out: [Bullet] = []

        // 1) Leverage — the primary "what's holding you back" line.
        //    Already voice-shaped + sensitivity-aware via VerdictEngine.
        let leverage = coachNote.leverage.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextStepEvidence: Evidence? = {
            let next = coachNote.nextStep.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !next.isEmpty else { return nil }
            return .nextStep(next)
        }()
        if !leverage.isEmpty {
            out.append(
                Bullet(
                    id: "leverage",
                    icon: "scope",
                    iconTint: AppColor.caution,
                    headline: leverage,
                    evidence: nextStepEvidence
                )
            )
        }

        // 2) Filler issue — only when the shared duration-normalized burden
        //    threshold is met. Absolute counts would mislabel a long answer
        //    with a few isolated fillers as a problem. We
        //    surface the actual chips (top 3 words) as evidence so the
        //    user can see *which* filler they leaned on, not just
        //    "fillers were a thing".
        if let qualifiedFillerBurden,
           qualifiedFillerBurden.meets(.elevated) {
            let qualifiedFillerCount = qualifiedFillerBurden.fillerCount
            let breakdown = FillerWordDetector.breakdown(
                in: metricSession?.transcript ?? transcriptText,
                customWords: customFillerWords
            )
            let topWords = Array(breakdown.topWords.prefix(3))
            let headline: String = {
                if qualifiedFillerCount >= 5 {
                    return "Fillers clustered — \(qualifiedFillerCount) across this rep."
                }
                return "Filler usage was higher than ideal (\(qualifiedFillerCount))."
            }()
            out.append(
                Bullet(
                    id: "filler",
                    icon: "waveform.path",
                    iconTint: AppColor.warning,
                    headline: headline,
                    evidence: topWords.isEmpty
                        ? nil
                        : .fillerChips(topWords.map { ($0.word, $0.count) })
                )
            )
        }

        // 3) Per-dimension "could improve" — only when CoachNote
        //    didn't already say the same thing (avoid duplicate
        //    bullets when leverage line names "structure" and the
        //    category for Structure is couldImprove).
        let needsWorkCategories = feedbackCategories
            .filter { $0.rating == .couldImprove || $0.rating == .ok }
            .filter { category in
                // Light dedup: don't add a category bullet if the
                // leverage line already mentions that dimension by
                // name. Keeps the card under the 3-bullet ceiling.
                !leverage.lowercased().contains(category.dimension.lowercased())
            }
            .prefix(2)
        for category in needsWorkCategories where out.count < 3 {
            out.append(
                Bullet(
                    id: "category-\(category.dimension)",
                    icon: "arrow.up.circle.fill",
                    iconTint: AppColor.caution,
                    headline: "\(category.dimension) has room to sharpen.",
                    evidence: category.note.isEmpty
                        ? nil
                        : .text(category.note)
                )
            )
        }

        // 4) Pace anomaly — only when outside the soft band AND we have
        //    headroom. Avoid surfacing pace + filler + leverage all at
        //    once on the same rep; the user needs ONE focus, not five.
        if out.count < 3, let qualifiedPaceWPM {
            let wpm = Int(qualifiedPaceWPM.rounded())
            if wpm >= 170 {
                out.append(
                    Bullet(
                        id: "pace-fast",
                        icon: "hare.fill",
                        iconTint: AppColor.caution,
                        headline: "Pace ran fast at \(wpm) WPM.",
                        evidence: .text("A 130–155 WPM target reads as confident without sounding rushed. Try slowing the first two sentences to set tempo.")
                    )
                )
            } else if wpm > 0 && wpm <= 95 {
                out.append(
                    Bullet(
                        id: "pace-slow",
                        icon: "tortoise.fill",
                        iconTint: AppColor.caution,
                        headline: "Pace ran slow at \(wpm) WPM.",
                        evidence: .text("A 130–155 WPM target reads as confident without sounding rushed. Commit to each sentence before starting it.")
                    )
                )
            }
        }

        // 5) AI keyImprovement — only when present + headroom.
        if out.count < 3, let aiFeedback {
            let key = aiFeedback.keyImprovement.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                out.append(
                    Bullet(
                        id: "ai-improvement",
                        icon: "sparkles",
                        iconTint: AppColor.brandBlue,
                        headline: key,
                        evidence: aiFeedback.suggestedDrill.isEmpty
                            ? nil
                            : .text(aiFeedback.suggestedDrill)
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
                    .stroke(AppColor.caution.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
            .accessibilityIdentifier("summary.whatToImprove")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.caution)
            Text("What to improve")
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

                    VStack(alignment: .leading, spacing: 6) {
                        Text(bullet.headline)
                            .font(Typography.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        if let intent = intentFocus,
                           SessionIntentMatcher.aligns(bulletID: bullet.id, with: intent) {
                            intentMatchChip
                        }
                    }

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

    /// M21: quiet "You aimed for this" pill aligned with the matching
    /// improvement bullet. Uses the caution palette so the chip reads
    /// as "you flagged this, here's the verdict" rather than as a win.
    private var intentMatchChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "scope")
                .font(.caption2.weight(.bold))
            Text("You aimed for this")
                .font(Typography.micro.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .foregroundStyle(AppColor.caution)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(AppColor.caution.opacity(0.12), in: Capsule())
        .accessibilityLabel("You aimed for this in this rep.")
        .accessibilityIdentifier("summary.intentMatchChip")
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

        case .nextStep(let text):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .padding(.top, 1)
                Text(text)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.brandBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

        case .fillerChips(let words):
            VStack(alignment: .leading, spacing: 8) {
                Text("Most-used fillers this rep")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(words, id: \.0) { entry in
                            HStack(spacing: 4) {
                                Text("\u{201C}\(entry.0)\u{201D}")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(entry.1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(chipTint(count: entry.1), in: Capsule())
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

    private func toggle(_ id: String) {
        if reduceMotion {
            if expandedBulletIDs.contains(id) {
                expandedBulletIDs.remove(id)
            } else {
                expandedBulletIDs.insert(id)
            }
        } else {
            withAnimation(.standardSpring) {
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
        case nextStep(String)
        case fillerChips([(String, Int)])
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("What to improve — full") {
    WhatToImproveCard(
        coachNote: CoachNote(
            momentum: "Your structure tightened.",
            leverage: "Pace ran a touch fast in the middle section.",
            nextStep: "Slow the first two sentences to set tempo."
        ),
        feedbackCategories: [
            FeedbackCategory(dimension: "Depth", rating: .couldImprove, note: "Push for one concrete example next time."),
            FeedbackCategory(dimension: "Close", rating: .ok, note: "Ended a bit abruptly.")
        ],
        aiFeedback: nil,
        transcriptText: "So um you know I think the most important thing is um like really being clear and structured about it so you know that's like how I'd approach it um.",
        effectiveFillerCount: 6,
        effectiveDuration: 22,
        transcriptWordCount: 38,
        isMinimalEffort: false
    )
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("What to improve — clean rep hides") {
    WhatToImproveCard(
        coachNote: CoachNote(momentum: "Clean delivery.", leverage: "", nextStep: ""),
        feedbackCategories: [],
        aiFeedback: nil,
        transcriptText: "Clear, calm, and on time.",
        effectiveFillerCount: 0,
        effectiveDuration: 35,
        transcriptWordCount: 80,
        isMinimalEffort: false
    )
    .padding()
    .background(AppColor.screenBackground)
}
#endif

#endif
