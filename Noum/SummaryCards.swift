import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Hero Score Card

struct HeroScoreCard: View {
    let scoreValue: Int?
    let practiceTitle: String
    let scoreAccent: Color
    let scoreEmoji: String
    let headline: String
    let sessionPrompt: String?
    let effectiveFillerCount: Int
    let fillerTint: Color
    let fillerDelta: Double?
    /// VoiceOver names both the raw detector count and the normalized rate so
    /// the visible compact pill never implies that counts from unequal reps
    /// are directly comparable.
    var fillerAccessibilityLabel: String? = nil
    let effectiveDuration: TimeInterval
    let durationAssessment: DurationAssessment
    /// When true the rep was below the evidence floor (accidental instant-stop,
    /// too short to read). The ring shows no number and stays empty — a "1/10"
    /// on a rep the user never really gave is a lie. Opt-in, default false so
    /// every existing call site renders the normal score ring unchanged.
    var belowEvidenceFloor: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Optional IM tone-drill SOLVED ribbon. When non-nil, the card
    /// renders a quiet mode-tinted capsule between the score ring and the
    /// headline naming the just-resolved scenario + committed tone. The
    /// owning `SummaryView` only sets this on the *crossing rep* — the
    /// rep that pushed a scenario's hit rate over the bar — mirroring
    /// the post-rep coach-note crossing detection (`PracticeSessionFinalizer`
    /// rounds 14+). Defaults nil → every existing call site keeps
    /// rendering the descriptive-only hero. The ribbon is opt-in, not
    /// opt-out: a future call site that doesn't compute the resolved
    /// read can omit the argument and never accidentally celebrate.
    ///
    /// Pure-presentation contract: the card takes a string pair and
    /// renders a capsule; the crossing logic (which scenario, which rep
    /// crossed) lives in `SummaryView` next to the same store + scenario
    /// derivation the coach-note path uses, so "SOLVED" and the
    /// note's SOLVED-headlined sentence light up on the same rep.
    var toneDrillResolvedRibbon: ToneDrillResolvedRibbon? = nil

    /// Display-only bundle for the SOLVED ribbon. Two titles so the
    /// renderer doesn't depend on the iOS-17-gated `IMHistorySummary`
    /// types — the owning view does the lookup and passes the strings.
    struct ToneDrillResolvedRibbon: Equatable {
        /// Scenario the user just resolved, e.g. "Difficult Conversation".
        let scenarioTitle: String
        /// Committed tone whose hit rate crossed the bar, e.g. "Calm".
        let toneTitle: String
    }

    /// Predicate the body uses to gate the ribbon. Lifted so the same
    /// "show / hide" rule can be locked in tests without rendering the
    /// SwiftUI body: the ribbon shows iff a ribbon is wired.
    var shouldShowToneDrillResolvedRibbon: Bool { toneDrillResolvedRibbon != nil }

    /// Display copy for the SOLVED ribbon. Lifted so the per-scenario /
    /// per-tone label shape can be pinned in unit tests without rendering
    /// SwiftUI. Mirrors the post-rep coach-note's `Your <tone> tone in
    /// <scenario> is solved` phrasing but compressed to a capsule label:
    /// names the outcome as observed hit rate, never claims a drill
    /// *caused* the win, never re-prescribes. Returns nil when no ribbon
    /// is wired so callers can use the same predicate for both the gate
    /// and the label.
    var toneDrillResolvedRibbonLabel: String? {
        guard let ribbon = toneDrillResolvedRibbon else { return nil }
        return "Holding · \(ribbon.toneTitle) tone in \(ribbon.scenarioTitle)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Results")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .accessibilityAddTraits(.isHeader)

                    Text(practiceTitle)
                        .font(Typography.headline)
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.xs)

                scoreSummary
            }

            if let label = toneDrillResolvedRibbonLabel {
                Label(label, systemImage: "checkmark.circle.fill")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .background(AppColor.brandBlue.opacity(0.08), in: Capsule())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("summary.hero.toneDrillSolvedRibbon")
                    .accessibilityLabel(label)
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Image(systemName: scoreEmoji)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(scoreAccent)
                    .accessibilityHidden(true)
                Text(headline)
                    .font(Typography.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let sessionPrompt, !sessionPrompt.isEmpty {
                Text(sessionPrompt)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Prompt: \(sessionPrompt)")
            }

            Divider()

            quickStats
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("summary.results.card")
    }

    private var scoreSummary: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if belowEvidenceFloor {
                Text("—")
                    .font(Typography.figtreeNumeric(size: 36, weight: .bold, relativeTo: .title))
                    .foregroundStyle(AppColor.textPrimary)
                Text("Too short to score")
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.textSecondary)
            } else if let scoreValue {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(scoreValue)")
                        .font(Typography.figtreeNumeric(size: 40, weight: .bold, relativeTo: .largeTitle))
                        .foregroundStyle(AppColor.textPrimary)
                        .monospacedDigit()
                    Text("/10")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                }
            } else {
                Text("—")
                    .font(Typography.figtreeNumeric(size: 36, weight: .bold, relativeTo: .title))
                    .foregroundStyle(AppColor.textPrimary)
                Text("Not scored")
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            belowEvidenceFloor
                ? "Too short to score"
                : scoreValue.map { "Score \($0) out of 10" } ?? "Not scored"
        )
    }

    @ViewBuilder
    private var quickStats: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Spacing.sm) {
                fillerMetric
                Divider()
                durationMetric
            }
        } else {
            HStack(spacing: Spacing.md) {
                fillerMetric
                Divider().frame(height: 36)
                durationMetric
            }
        }
    }

    private var fillerMetric: some View {
        compactMetric(
            label: "Fillers",
            value: "\(effectiveFillerCount)",
            detail: fillerDeltaLabel,
            tint: fillerTint,
            accessibilityLabel: fillerAccessibilityLabel ?? "\(effectiveFillerCount) fillers"
        )
    }

    private var durationMetric: some View {
        compactMetric(
            label: "Duration",
            value: "\(Int(effectiveDuration))s",
            detail: durationAssessment.rawValue,
            tint: durationAssessment.tint,
            accessibilityLabel: "Duration \(Int(effectiveDuration)) seconds, \(durationAssessment.rawValue)"
        )
    }

    private var fillerDeltaLabel: String? {
        guard let fillerDelta, fillerDelta != 0 else { return nil }
        let direction = fillerDelta < 0 ? "Down" : "Up"
        return "\(direction) \(String(format: "%.1f", abs(fillerDelta)))/min"
    }

    private func compactMetric(
        label: String,
        value: String,
        detail: String?,
        tint: Color,
        accessibilityLabel: String
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(value)
                .font(Typography.figtreeNumeric(size: 22, weight: .bold, relativeTo: .title3))
                .foregroundStyle(tint)
                .monospacedDigit()

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                if let detail {
                    Text(detail)
                        .font(Typography.captionSmall)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Sudden Death Review Card

struct SuddenDeathReviewCard: View {
    let points: Int
    let multiplierLabels: [String]
    let tiersCleared: Int
    let fillerCount: Int
    let duration: TimeInterval
    let wordCount: Int

    private let accent = AppColor.modeSuddenDeath

    private var elapsedLabel: String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return minutes > 0 ? String(format: "%d:%02d", minutes, seconds) : "\(seconds)s"
    }

    private var outcomeLine: String {
        guard fillerCount > 0 else { return "No filler ended this run." }
        return "\(fillerCount) filler\(fillerCount == 1 ? "" : "s") ended this run."
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("PRESSURE DRILL REVIEW")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1.4)

            VStack(spacing: 2) {
                Text(points.formatted())
                    .font(Typography.figtreeNumeric(size: 44, weight: .black, relativeTo: .largeTitle))
                    .foregroundStyle(accent)
                Text("POINTS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
            }

            if !multiplierLabels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(multiplierLabels, id: \.self) { multiplier in
                            Text(multiplier)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(accent.opacity(0.10), in: Capsule())
                        }
                    }
                }
            }

            Text(outcomeLine)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                StatPill(label: "Cleared", value: "\(tiersCleared)", delta: nil, tint: accent, invertDelta: false)
                StatPill(label: "Time", value: elapsedLabel, delta: nil, tint: .primary, invertDelta: false)
                StatPill(label: "Words", value: "\(wordCount)", delta: nil, tint: .primary, invertDelta: false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [AppColor.cardBackground, accent.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .accessibilityIdentifier("suddenDeath.review.card")
    }
}

// MARK: - Stat Pill (reusable)

struct StatPill: View {
    let label: String
    let value: String
    let delta: Double?
    let tint: Color
    let invertDelta: Bool
    var deltaPrecision: Int = 0
    var deltaSuffix: String = ""
    var accessibilityLabel: String? = nil
    /// Extra delay (on top of the `statDelta` token's built-in beat)
    /// before the delta badge pops in. The verdict hero passes the
    /// score-ring duration so the badge gets its own beat after the ring
    /// settles. Defaults 0 → existing call sites render with the plain
    /// pop. Only fires when a real non-zero delta exists (already gated).
    var deltaRevealDelay: TimeInterval = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var deltaRevealed = false

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            if let delta, delta != 0 {
                let improved = invertDelta ? delta < 0 : delta > 0
                HStack(spacing: 2) {
                    Image(systemName: improved ? "arrow.down" : "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(String(format: "%.*f", deltaPrecision, abs(delta)))\(deltaSuffix)")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(improved ? AppColor.positive : AppColor.caution)
                .scaleEffect(deltaRevealed ? 1.0 : 0.6)
                .opacity(deltaRevealed ? 1 : 0)
                .onAppear {
                    guard !deltaRevealed else { return }
                    if reduceMotion {
                        deltaRevealed = true
                    } else {
                        withAnimation(.statDelta.delay(deltaRevealDelay)) {
                            deltaRevealed = true
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "\(value) \(label)")
    }
}

// MARK: - Duration Assessment Pill

struct DurationAssessmentPill: View {
    let effectiveDuration: TimeInterval
    let durationAssessment: DurationAssessment

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(effectiveDuration))s")
                .font(.headline.weight(.bold))
                .foregroundStyle(durationAssessment.tint)
            Text("Duration")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                Image(systemName: durationAssessment.icon)
                    .font(.system(size: 9, weight: .bold))
                Text(durationAssessment.rawValue)
                    .font(Typography.figtree(size: 11, weight: .bold, relativeTo: .caption2))
            }
            .foregroundStyle(durationAssessment.tint)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Coach Note Card

struct CoachNoteCard: View {
    let coachNote: CoachNote
    let coachNoteRevealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coach Note")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            // Momentum — what's getting stronger
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.positive)
                    .frame(width: 18)
                Text(coachNote.momentum)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(coachNoteRevealed ? 1 : 0)
            .offset(y: coachNoteRevealed ? 0 : 8)

            // Leverage — what's holding them back
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "scope")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.caution)
                    .frame(width: 18)
                Text(coachNote.leverage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(coachNoteRevealed ? 1 : 0)
            .offset(y: coachNoteRevealed ? 0 : 8)

            // Next step — one concrete action
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.right.circle")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(width: 18)
                Text(coachNote.nextStep)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(coachNoteRevealed ? 1 : 0)
            .offset(y: coachNoteRevealed ? 0 : 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

// MARK: - Filler Breakdown Card

struct FillerBreakdownCard: View {
    let transcriptText: String

    var body: some View {
        let breakdown = FillerWordDetector.breakdown(
            in: transcriptText,
            customWords: ClutchWordStore.shared.customFillerWords
        )
        Group {
            if !breakdown.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Filler Breakdown")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)

                    // Per-word breakdown chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(breakdown.topWords.prefix(6), id: \.word) { entry in
                                HStack(spacing: 4) {
                                    Text("\"\(entry.word)\"")
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(entry.count)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Self.chipTint(count: entry.count), in: Capsule())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.04), in: Capsule())
                            }
                        }
                    }

                    // Coaching note about fillers
                    if breakdown.totalCount >= 3 {
                        Text("Most fillers appear in transitions between ideas. Try pausing briefly instead.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if breakdown.totalCount > 0 {
                        Text("Light filler usage. These tend to decrease as you build comfort with pausing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(Spacing.lg)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            }
        }
    }

    static func chipTint(count: Int) -> Color {
        if count >= 4 { return AppColor.warning }
        if count >= 2 { return AppColor.caution }
        return .secondary
    }
}

// MARK: - Your Next Move Card

struct YourNextMoveCard: View {
    let drill: DrillRecommendationV2
    let legacyDrill: DrillRecommendation
    let aiFeedback: AICoachFeedback?
    let nextAction: NextAction?
    var onStartMiniDrill: (DrillRecommendationV2) -> Void
    var onStartDrill: ((DrillRecommendation) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: drill.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(drill.tint)
                Text("Your Next Move")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                // Format badge
                Text(drill.format == .miniDrill ? "Quick Drill" : "Full Retry")
                    .font(Typography.figtree(size: 11, weight: .bold, relativeTo: .caption2))
                    .foregroundStyle(drill.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(drill.tint.opacity(0.1), in: Capsule())
            }

            // Drill title
            Text(drill.title)
                .font(.headline)
                .foregroundStyle(.primary)

            // Session-specific rationale
            Text(drill.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Trend context (if available)
            if let context = drill.trendContext {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(drill.tint.opacity(0.7))
                    Text(context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(drill.tint.opacity(0.05), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }

            // Strategic reasoning (from NextActionEngine)
            if let action = nextAction, !action.reasoning.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "brain")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.purple.opacity(0.7))
                    Text(action.reasoning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.purple.opacity(0.05), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }

            // Constraint rule
            VStack(alignment: .leading, spacing: 6) {
                Text("Your rule")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(drill.tint)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(drill.constraint)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(drill.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            // Primary CTA — Mini Drill or Full Retry
            if drill.format == .miniDrill {
                Button {
                    onStartMiniDrill(drill)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.subheadline.weight(.semibold))
                        Text("Start Quick Drill (45s)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.white)
                    .background(drill.tint, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                }
                .buttonStyle(.pressable)

                // Alternate: full retry
                if let onStartDrill {
                    Button {
                        onStartDrill(legacyDrill)
                    } label: {
                        Text("or Full Retry")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Full retry is the primary action
                if let onStartDrill {
                    Button {
                        onStartDrill(legacyDrill)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline.weight(.semibold))
                            Text("Start Full Retry")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(.white)
                        .background(drill.tint, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                }

                // Alternate: mini drill
                Button {
                    onStartMiniDrill(drill)
                } label: {
                    Text("or Quick Drill (45s)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // AI Coach suggested drill (if available, shown subtly)
            if let aiFeedback {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Coach note: \(aiFeedback.suggestedDrill)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

// MARK: - Looking Ahead Card

/// Quiet "next session" suggestion shown at the bottom of the expandable
/// details on the summary screen. Surfaces the mode-level recommendation
/// (computed by RecommendationBiasEngine) without competing with the
/// in-the-moment drill CTA above. Only renders when the suggestion would
/// actually shift the user's direction — see `lookingAheadHint` gating
/// in SummaryView.
///
/// As of round 19, the card can carry an optional `onStart` closure. When
/// the owning view passes one in, the card renders a subordinate text-link
/// CTA ("Start <mode> →") beneath the descriptive copy so the user can
/// launch the recommended mode in one tap instead of digging back through
/// the picker. The CTA is *additive* and *defaults to hidden* (the closure
/// defaults nil → all existing call sites and tests still compile and
/// render the same descriptive-only card). The destination contract lives
/// in `SummaryLookingAheadRouter`; the closure stays pure presentation so
/// the card can be unit-tested without a NavigationPath in scope.
struct LookingAheadCard: View {
    struct Hint {
        let mode: PracticeMode
        let whyMode: String
        let whyNow: String
        /// User's chosen voice goal. Optional — pre-onboarding users and
        /// users who skipped the voice step pass nil. When set AND the
        /// voice aligns with `mode`, the post-session card mirrors the
        /// home recommendation tile by surfacing a "Toward your <voice>
        /// voice" chip. Sixth surface in the M14 goal-aware loop.
        let styleGoal: SpeakingStyleGoal?

        init(mode: PracticeMode, whyMode: String, whyNow: String, styleGoal: SpeakingStyleGoal? = nil) {
            self.mode = mode
            self.whyMode = whyMode
            self.whyNow = whyNow
            self.styleGoal = styleGoal
        }

        /// True when a voice goal is set AND it aligns with the recommended
        /// mode. Lifted to a testable predicate so the gating is locked
        /// independently of the SwiftUI body — same honesty rules as the
        /// home chip: silent when no goal, silent when off-mode.
        var shouldShowVoiceAlignment: Bool {
            guard let styleGoal else { return false }
            return styleGoal.aligns(with: mode)
        }
    }

    let hint: Hint
    /// Optional launch callback. When non-nil, the card renders a
    /// subordinate text-link CTA that calls this on tap. Owning view is
    /// responsible for computing the destination via
    /// `SummaryLookingAheadRouter` and pushing it onto its navigation
    /// path. Defaults nil → the CTA hides entirely and the card stays a
    /// descriptive-only nudge (the pre-round-19 behavior).
    var onStart: (() -> Void)? = nil

    /// Predicate the body uses to gate the CTA. Lifted so the same
    /// "show / hide" rule can be locked in tests without rendering the
    /// view: the CTA shows iff a callback is wired.
    var shouldShowStartCTA: Bool { onStart != nil }

    /// Display copy for the subordinate CTA. Lifted so the tests can
    /// pin the per-mode label without rendering the SwiftUI body —
    /// matches the home coach card's "Begin · <Mode>" pattern shape
    /// but uses "Start" so the post-rep voice doesn't echo Home.
    var startCTALabel: String {
        "Start \(hint.mode.displayLabel)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.forward.circle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("Looking ahead")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }

            Text("For your next session, try \(hint.mode.displayLabel).")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(hint.whyMode)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !hint.whyNow.isEmpty {
                Text(hint.whyNow)
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VoiceAlignmentChip(
                styleGoal: hint.styleGoal,
                mode: hint.mode,
                tint: AppColor.tint(for: hint.mode)
            )

            // Subordinate launch CTA. Renders only when an `onStart`
            // closure is wired — the descriptive-only card stays the
            // default so the existing voice-alignment tests + call
            // sites are unchanged. Visual register stays quiet on
            // purpose: this is a card that lives at the bottom of the
            // Session Details disclosure, not the hero "Your Next Move"
            // surface. The drill CTA above the fold is the loud
            // action; this is the "and when you come back, this is
            // where you should go" follow-on.
            if let onStart {
                Button {
                    onStart()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.forward.circle.fill")
                            .font(.footnote.weight(.semibold))
                        Text(startCTALabel)
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(AppColor.tint(for: hint.mode))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        AppColor.tint(for: hint.mode).opacity(0.10),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("summary.lookingAhead.startCTA")
                .accessibilityLabel(startCTALabel)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityCopy)
    }

    private var accessibilityCopy: String {
        var parts = [
            "Looking ahead.",
            "For your next session, try \(hint.mode.displayLabel).",
            hint.whyMode,
            hint.whyNow
        ]
        if hint.shouldShowVoiceAlignment, let goal = hint.styleGoal {
            parts.append("Aligned with your \(goal.shortVoiceLabel).")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

// MARK: - Baseline Comparison Card

struct BaselineComparisonCard: View {
    let baseline: CommunicationBaseline
    let transcriptText: String
    let effectiveFillerCount: Int
    let effectiveDuration: TimeInterval
    let explicitMode: PracticeMode?
    let score: Int?
    let scoreValue: Int?
    let rating: SpeakingRating
    let pressureLevel: PressureLevel

    var body: some View {
        if baseline.overallConfidence >= .tentative {
            let dummySession = PracticeSession(
                transcript: transcriptText,
                fillerWordCount: effectiveFillerCount,
                duration: effectiveDuration,
                date: Date(),
                mode: explicitMode ?? .timed,
                score: score ?? scoreValue
            )
            let comparisons = BaselineEngine.sessionComparison(session: dummySession, baseline: baseline)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.blue)
                    Text("vs Your Baseline")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    Text(baseline.overallConfidence.label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColor.brandBlue.opacity(0.08), in: Capsule())
                }

                // Pressure context indicator with resilience data
                if pressureLevel >= .elevated {
                    let pressureProfile = BaselineStore.shared.pressureProfile
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("High-pressure session")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                            if let resilience = pressureProfile.pressureResilience {
                                Spacer()
                                Text("Resilience: \(Int(resilience * 100))%")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(resilience >= 0.7 ? AppColor.positive : resilience >= 0.4 ? AppColor.caution : .red)
                            }
                        }
                        if let insight = pressureProfile.pressureInsight {
                            Text(insight)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.orange.opacity(0.12), lineWidth: 1)
                    )
                }

                if !comparisons.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(Array(comparisons.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                            HStack(alignment: .top, spacing: 8) {
                                Text(key)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .leading)
                                Text(value)
                                    .font(.caption)
                                    .foregroundStyle(AppColor.textPrimary)
                            }
                        }
                    }
                }

                if rating.totalRatedSessions > 0 {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rating")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text("\(rating.overall)")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.blue)
                        }
                        if rating.weeklyDelta != 0 {
                            Text(rating.weeklyDelta > 0 ? "+\(rating.weeklyDelta) this week" : "\(rating.weeklyDelta) this week")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(rating.weeklyDelta > 0 ? AppColor.positive : AppColor.caution)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Peak")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text("\(rating.peakRating)")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }

                if !baseline.topStrengths.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("Strengths: \(baseline.topStrengths.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(Spacing.lg)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(AppColor.brandBlue.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

// MARK: - IM Verdict Card

struct IMVerdictCard: View {
    let scoreValue: Int?
    let scoreAccent: Color
    let scoreEmoji: String
    let headline: String
    let effectiveFillerCount: Int
    let effectiveDuration: TimeInterval
    let imConversationDetails: IMConversationDetails?

    var body: some View {
        let details = imConversationDetails
        let userTurns = details?.turns.filter { $0.speaker == .user }.count ?? 0
        let isShortSession = userTurns <= 2 || effectiveDuration < 30
        let confidenceLabel = isShortSession ? "Early read" : "Session read"

        VStack(spacing: 14) {
            // Mode + confidence label
            HStack(spacing: 8) {
                Text("Conversation".uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.4)
                Spacer()
                Text(confidenceLabel.uppercased())
                    .font(Typography.figtree(size: 11, weight: .bold, relativeTo: .caption2))
                    .foregroundStyle(scoreAccent.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(scoreAccent.opacity(0.1), in: Capsule())
            }

            // Verdict line — the headline
            HStack(spacing: 10) {
                Image(systemName: scoreEmoji)
                    .font(.title2)
                    .foregroundStyle(scoreAccent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline)
                        .font(.title3.weight(.bold))
                    if let tone = details?.actualTone, !tone.isEmpty {
                        Text("You came across as \(tone.lowercased())")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // Context chips + inline score
            HStack(spacing: 8) {
                if let details {
                    SummaryChip(text: details.setup.scenario.title, tint: .purple)
                    SummaryChip(text: details.setup.targetTone.title, tint: .blue)
                }
                Spacer()
                // Score shown small, not as hero
                if let scoreValue {
                    Text("\(scoreValue)/10")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(scoreAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(scoreAccent.opacity(0.1), in: Capsule())
                } else {
                    Text("Not scored")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            // Compact stats
            HStack(spacing: 16) {
                Label("\(userTurns) turns", systemImage: "bubble.left.and.bubble.right")
                Label("\(Int(effectiveDuration))s", systemImage: "clock")
                Label("\(effectiveFillerCount) fillers", systemImage: "waveform.path")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [AppColor.cardBackground, scoreAccent.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(scoreAccent.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

// MARK: - IM Read Card

struct IMReadCard: View {
    let coachNote: CoachNote
    let effectiveDuration: TimeInterval
    let imConversationDetails: IMConversationDetails?
    /// Fresh user-pushback acknowledgment, folded INTO the read as a
    /// one-line prefix (the revision IS the read — same fold the timed
    /// path's `PostRepReadCard` applies). nil → legacy rendering,
    /// byte-for-byte. Eligibility lives on
    /// `CoachContextBuilder.freshRevisedReadChange`; copy stays on
    /// `RevisedReadCard`'s tested statics.
    var revisedChange: CoachCourseChange? = nil

    var body: some View {
        let userTurns = imConversationDetails?.turns.filter { $0.speaker == .user }.count ?? 0
        let isShortSession = userTurns <= 2 || effectiveDuration < 30

        VStack(alignment: .leading, spacing: 12) {
            Text("The Read")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            if let change = revisedChange {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColor.pro)
                        .padding(.top, 1)
                    Text(RevisedReadCard.headlineCopy(for: change))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Revised coaching read. \(RevisedReadCard.headlineCopy(for: change))")
                .accessibilityIdentifier("summary.revisedRead.card")
            }

            // Strength
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.positive)
                VStack(alignment: .leading, spacing: 2) {
                    Text(coachNote.momentum)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            // Miss
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "scope")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.caution)
                VStack(alignment: .leading, spacing: 2) {
                    Text(coachNote.leverage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Confidence disclaimer for short sessions
            if isShortSession {
                Text("Based on a short conversation — longer sessions give a clearer picture.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

// MARK: - Conversation debrief

/// Conversation-mode counterpart to `PostRepDebriefCard`. It keeps the
/// scenario/tone read intact while composing the strength and next move into
/// one quiet surface.
struct IMDebriefCard: View {
    let coachNote: CoachNote
    let effectiveDuration: TimeInterval
    let imConversationDetails: IMConversationDetails?
    var revisedChange: CoachCourseChange? = nil
    var reviewIntervention: CoachIntervention? = nil
    var onReview: (() -> Void)? = nil
    var suppressesNextMove: Bool = false

    private var isShortSession: Bool {
        let turns = imConversationDetails?.turns.filter { $0.speaker == .user }.count ?? 0
        return turns <= 2 || effectiveDuration < 30
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
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
                .accessibilityIdentifier("summary.revisedRead.card")
            }

            debriefSection(
                title: "What held",
                symbol: "checkmark.circle.fill",
                tint: AppColor.positive,
                body: coachNote.momentum
            )

            if !suppressesNextMove {
                Divider()

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    debriefSection(
                        title: "Next move",
                        symbol: "arrow.up.right",
                        tint: AppColor.caution,
                        body: reviewIntervention == nil ? coachNote.nextStep : coachNote.leverage
                    )

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
                    }
                }
            }

            if isShortSession {
                Text("This is an early read from a short conversation.")
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("summary.postRepVerdict")
    }

    private func debriefSection(
        title: String,
        symbol: String,
        tint: Color,
        body: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(title)
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
            }
            Text(body)
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One dominant repeat action for conversation summaries. The optional Adjust
/// link keeps mode selection reachable without competing with the prescribed
/// start action.
struct SummaryRepeatActionCard: View {
    let exerciseName: String
    let onStart: () -> Void
    var onAdjust: (() -> Void)? = nil

    static func primaryCTALabel(exerciseName: String) -> String {
        let name = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Start practice" : "Start \(name)"
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Button(action: onStart) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                    Text(Self.primaryCTALabel(exerciseName: exerciseName))
                        .font(Typography.body.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    AppColor.brandBlue,
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("summary.postRepVerdict.fullRetry")

            if let onAdjust {
                Button("Adjust", action: onAdjust)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(minHeight: 44)
                    .buttonStyle(.pressable)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
    }
}

// MARK: - IM One Move Card

struct IMOneMoveCard: View {
    let coachNote: CoachNote
    var onPracticeAgain: () -> Void
    var onSelectPracticeMode: () -> Void
    /// On review-due reps the agreed case-file review IS the named next
    /// move (same fold the timed path's `PostRepFixCard` applies) — the
    /// one-line context + Ask-Noum CTA replace the generic next step.
    /// nil → legacy rendering. `isReviewDue` gating + opener composition
    /// stay in `SummaryView` / `CoachContextBuilder`.
    var reviewIntervention: CoachIntervention? = nil
    var onReview: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.brandBlue)
                Text("Next Move")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }

            if let reviewIntervention, let onReview {
                Text(InterventionReviewPromptCard.headlineCopy(for: reviewIntervention))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onReview) {
                    HStack(spacing: 6) {
                        Text(CohesiveSummaryCopy.askNoum)
                            .font(.caption.weight(.semibold))
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
            } else {
                Text(coachNote.nextStep)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // CTA buttons
            HStack(spacing: 12) {
                Button {
                    onPracticeAgain()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.bold))
                        Text("Try Again")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(.white)
                    .background(AppColor.brandBlue, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                }
                .buttonStyle(.pressable)

                Button {
                    onSelectPracticeMode()
                } label: {
                    Text("Choose another rep")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                }
                .buttonStyle(.pressable)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

// MARK: - IM Signals Card

struct IMSignalsCard: View {
    let details: IMConversationDetails

    var body: some View {
        let startTrust = 5
        let startTension = 4
        let startEngagement = 5
        let finalTrust = details.finalState?.normalizedTrust ?? startTrust
        let finalTension = details.finalState?.normalizedTension ?? startTension
        let finalEngagement = details.finalState?.normalizedEngagement ?? startEngagement

        VStack(alignment: .leading, spacing: 12) {
            Text("Conversation Signals")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(spacing: 10) {
                SignalPill(label: "Trust", start: startTrust, end: finalTrust, goodDirection: .up, tint: .blue)
                SignalPill(label: "Tension", start: startTension, end: finalTension, goodDirection: .down, tint: .orange)
                SignalPill(label: "Engage", start: startEngagement, end: finalEngagement, goodDirection: .up, tint: .green)
            }

            // Outcome milestone (if present)
            if let outcome = details.outcome {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(outcome.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(10)
                .background(Color.yellow.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }

            // Beat description
            if let beat = details.finalState?.beat, !beat.isEmpty {
                Text(beat)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

// MARK: - Signal Pill (IM helper)

enum SignalDirection { case up, down }

struct SignalPill: View {
    let label: String
    let start: Int
    let end: Int
    let goodDirection: SignalDirection
    let tint: Color

    var body: some View {
        let delta = end - start
        let isGood: Bool = {
            switch goodDirection {
            case .up: return delta >= 0
            case .down: return delta <= 0
            }
        }()
        let deltaColor: Color = delta == 0 ? .secondary : (isGood ? AppColor.positive : AppColor.caution)

        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text("\(start)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                Text("\(end)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
            }
            if delta != 0 {
                HStack(spacing: 2) {
                    Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(abs(delta))")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(deltaColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.05), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }
}

// MARK: - Summary Chip (reusable)

struct SummaryChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

#endif
