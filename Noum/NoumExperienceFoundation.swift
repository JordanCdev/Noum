#if canImport(SwiftUI)
import Foundation
import SwiftUI

// MARK: - Experience tokens

/// App-wide geometry that carries interaction or identity meaning.
/// Layout rhythm remains owned by `Spacing` and `CornerRadius`.
enum NoumControlMetric {
    /// Apple accessibility minimum for every interactive control.
    static let minimumTouchTarget: CGFloat = 44
    /// Standard progress-track thickness.
    static let progressTrackHeight: CGFloat = 10
    /// Default identity-mark size on cards.
    static let waveformMark: CGFloat = 56
    /// Inner reward content; surface padding brings the total above 68pt.
    static let rewardMinimumHeight: CGFloat = minimumTouchTarget
}

enum NoumMotionMetric {
    /// Earned acknowledgements stay bounded; never full-screen confetti rain.
    static let maximumEarnedParticles = 6
}

extension AppColor {
    // The waveform owns this spectrum. Other artwork should use the semantic
    // brand, coaching, or mode tokens instead of copying these stops.
    static let waveformStart = brandBlueLight
    static let waveformMid = coachAccent
    static let waveformEnd = proLight
    static let waveformDepth = Color(red: 55 / 255, green: 18 / 255, blue: 124 / 255)

    // Earned-reward colours are intentionally separate from caution amber.
    // Caution communicates a coaching lapse; gold communicates earned value.
    static let rewardGoldStart = Color(red: 1, green: 237 / 255, blue: 189 / 255)
    static let rewardGoldEnd = Color(red: 243 / 255, green: 190 / 255, blue: 68 / 255)
    static let rewardGoldDepth = Color(red: 156 / 255, green: 99 / 255, blue: 21 / 255)
    static let rewardGoldInk = Color(red: 73 / 255, green: 49 / 255, blue: 18 / 255)
}

// MARK: - Three-tier motion policy

/// The only three motion intensities available to product surfaces.
///
/// - `calm`: comprehension and state continuity.
/// - `responsive`: direct input or live audio response.
/// - `earned`: one-shot proof or milestone acknowledgement.
enum NoumMotionTier: CaseIterable, Equatable, Sendable {
    case calm
    case responsive
    case earned

    struct Allowance: Equatable, Sendable {
        let duration: TimeInterval
        let maximumScaleDelta: CGFloat
        let maximumTranslation: CGFloat
        let particleLimit: Int
        let allowsRepetition: Bool
    }

    /// Pure policy used by views and tests. Reduce Motion keeps a short fade,
    /// but removes displacement, scaling, particles, and repetition.
    func allowance(reduceMotion: Bool) -> Allowance {
        if reduceMotion {
            return Allowance(
                duration: 0.16,
                maximumScaleDelta: 0,
                maximumTranslation: 0,
                particleLimit: 0,
                allowsRepetition: false
            )
        }

        switch self {
        case .calm:
            return Allowance(
                duration: 0.20,
                maximumScaleDelta: 0,
                maximumTranslation: 0,
                particleLimit: 0,
                allowsRepetition: false
            )
        case .responsive:
            return Allowance(
                duration: 0.26,
                maximumScaleDelta: 0.03,
                maximumTranslation: 4,
                particleLimit: 0,
                allowsRepetition: false
            )
        case .earned:
            return Allowance(
                duration: Animation.payoffRevealDuration,
                maximumScaleDelta: 0.08,
                maximumTranslation: 18,
                particleLimit: NoumMotionMetric.maximumEarnedParticles,
                allowsRepetition: false
            )
        }
    }

    func animation(reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .easeInOut(duration: allowance(reduceMotion: true).duration)
        }

        switch self {
        case .calm: return .v46ReduceMotionFade
        case .responsive: return .listChange
        case .earned: return .payoffReveal
        }
    }
}

extension NoumMotion {
    /// One entry point for app-wide motion intensity. Screen code supplies the
    /// user's Reduce Motion preference rather than choosing a raw curve.
    static func animation(for tier: NoumMotionTier, reduceMotion: Bool) -> Animation {
        tier.animation(reduceMotion: reduceMotion)
    }
}

// MARK: - Waveform identity

enum NoumWaveformState: String, CaseIterable, Sendable {
    case idle
    case listening
    case processing
    case earned

    var motionTier: NoumMotionTier {
        switch self {
        case .idle, .processing: return .calm
        case .listening: return .responsive
        case .earned: return .earned
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .idle: return String(localized: "Noum is ready")
        case .listening: return String(localized: "Noum is listening")
        case .processing: return String(localized: "Noum is reviewing your rep")
        case .earned: return String(localized: "Improvement earned")
        }
    }
}

/// Noum's shared identity mark. It intentionally has no enclosing box, orb,
/// face, or mascot. The licensed Phosphor waveform remains the geometry;
/// Noum owns only its semantic colour and state-bound motion.
struct NoumWaveformMark: View {
    let state: NoumWaveformState
    var level: Double = 0
    var tint: Color = AppColor.coachAccent
    var size: CGFloat = NoumControlMetric.waveformMark

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            waveform
                .foregroundStyle(AppColor.waveformDepth.opacity(0.48))
                .offset(y: size * 0.035)

            waveform
                .foregroundStyle(foregroundStyle)
                .shadow(
                    color: state == .earned
                        ? AppColor.waveformDepth.opacity(0.22)
                        : .clear,
                    radius: state == .earned ? Spacing.sm : 0,
                    y: state == .earned ? Spacing.xs : 0
                )
        }
        .frame(width: size, height: size)
        .scaleEffect(renderedScale)
        .opacity(state == .idle ? 0.84 : 1)
        .animation(
            NoumMotion.animation(for: state.motionTier, reduceMotion: reduceMotion),
            value: state
        )
        .animation(
            reduceMotion ? nil : NoumMotion.audioResponse,
            value: renderedLevel
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
    }

    private var waveform: some View {
        Image("PhosphorWaveform")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
    }

    private var foregroundStyle: AnyShapeStyle {
        if state == .earned {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppColor.waveformStart, AppColor.waveformMid, AppColor.waveformEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        return AnyShapeStyle(tint)
    }

    private var renderedLevel: CGFloat {
        CGFloat(min(max(level, 0), 1))
    }

    private var renderedScale: CGFloat {
        guard !reduceMotion else { return 1 }
        switch state {
        case .listening:
            return 1 + renderedLevel * state.motionTier.allowance(reduceMotion: false).maximumScaleDelta
        case .earned:
            return 1.04
        case .idle, .processing:
            return 1
        }
    }
}

// MARK: - Shared surfaces

enum NoumSurfaceRole: CaseIterable, Equatable, Sendable {
    case standard
    case quiet
    case mission
    case evidence
    case reward

    var cornerRadius: CGFloat {
        self == .quiet ? CornerRadius.medium : CornerRadius.large
    }

    var padding: CGFloat {
        switch self {
        case .quiet: return Spacing.md
        case .standard, .evidence: return Spacing.lg
        case .mission: return Spacing.xl
        case .reward: return Spacing.sm
        }
    }

    var backgroundStyle: AnyShapeStyle {
        switch self {
        case .standard, .evidence:
            return AnyShapeStyle(AppColor.cardBackground)
        case .quiet:
            return AnyShapeStyle(AppColor.innerSurface)
        case .mission:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppColor.heroGradientStart, AppColor.heroGradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .reward:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppColor.rewardGoldStart, AppColor.rewardGoldEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    var border: Color {
        switch self {
        case .standard, .quiet: return AppColor.subtleBorder
        case .mission: return Color.white.opacity(0.12)
        case .evidence: return AppColor.positive.opacity(0.20)
        case .reward: return AppColor.rewardGoldDepth.opacity(0.24)
        }
    }

    var shadow: (color: Color, radius: CGFloat, y: CGFloat) {
        switch self {
        case .standard, .quiet: return (.clear, 0, 0)
        case .mission: return (AppColor.coachingInk.opacity(0.12), Spacing.md, Spacing.xs)
        case .evidence: return (AppColor.positive.opacity(0.08), Spacing.sm, Spacing.xxs)
        case .reward: return (AppColor.rewardGoldDepth.opacity(0.12), Spacing.md, Spacing.xs)
        }
    }
}

/// Stateless semantic container. Existing `CardView` remains the default card;
/// this is for screens migrating to an explicit mission/evidence/reward role.
struct NoumSurface<Content: View>: View {
    let role: NoumSurfaceRole
    @ViewBuilder let content: () -> Content

    init(_ role: NoumSurfaceRole, @ViewBuilder content: @escaping () -> Content) {
        self.role = role
        self.content = content
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: role.cornerRadius, style: .continuous)
        let shadow = role.shadow

        content()
            .padding(role.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(role.backgroundStyle))
            .overlay(shape.stroke(role.border, lineWidth: 1))
            .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
    }
}

// MARK: - Mission, evidence, progress, reward

/// One bite-sized prescription. Intended for the single startable mission on
/// Today, not as a generic gradient card used throughout the app.
struct NoumMissionCard: View {
    let eyebrow: String
    let title: String
    let instruction: String
    var metadata: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        NoumSurface(.mission) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: Spacing.md) {
                        mark
                        missionCopy
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        mark
                        missionCopy
                    }
                }

                if let actionTitle, let action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(Typography.cardLabel)
                            .foregroundStyle(AppColor.coachingInk)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .noumMinimumTouchTarget()
                            .background(Color.white, in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    private var mark: some View {
        NoumWaveformMark(state: .idle, tint: .white)
            .accessibilityHidden(true)
    }

    private var missionCopy: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(eyebrow)
                .font(Typography.caption)
                .foregroundStyle(AppColor.homeHeroMetaText)

            Text(title)
                .font(Typography.cardTitle)
                .foregroundStyle(AppColor.homeHeroTitleText)
                .fixedSize(horizontal: false, vertical: true)

            Text(instruction)
                .font(Typography.body)
                .foregroundStyle(AppColor.homeHeroSubtitleText)
                .fixedSize(horizontal: false, vertical: true)

            if let metadata {
                Text(metadata)
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.homeHeroMetaText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

enum NoumEvidenceStatus: CaseIterable, Sendable {
    case verified
    case provisional
    case needsMore

    var label: String {
        switch self {
        case .verified: return String(localized: "Verified improvement")
        case .provisional: return String(localized: "Early signal")
        case .needsMore: return String(localized: "More evidence needed")
        }
    }

    var symbol: String {
        switch self {
        case .verified: return "checkmark.seal.fill"
        case .provisional: return "waveform"
        case .needsMore: return "ellipsis.circle"
        }
    }

    var tint: Color {
        switch self {
        case .verified: return AppColor.positive
        case .provisional: return AppColor.caution
        case .needsMore: return AppColor.textSecondary
        }
    }
}

/// A bounded evidence object. Status is always written and symbol-backed;
/// colour is never the only signal.
struct NoumEvidenceCard: View {
    let status: NoumEvidenceStatus
    let title: String
    let detail: String
    var source: String? = nil

    var body: some View {
        NoumSurface(.evidence) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label(status.label, systemImage: status.symbol)
                    .font(Typography.caption)
                    .foregroundStyle(status.tint)

                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let source {
                    Text(source)
                        .font(Typography.captionSmall)
                        .foregroundStyle(AppColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

struct NoumProgressTrack: View {
    let value: Double
    let label: String
    var valueLabel: String? = nil
    var tint: Color = AppColor.coachingInk

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(label)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let valueLabel {
                    Text(valueLabel)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textPrimary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(AppColor.innerSurface)
                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: geometry.size.width * CGFloat(normalizedValue))
                }
            }
            .frame(height: NoumControlMetric.progressTrackHeight)
            .animation(
                reduceMotion ? nil : NoumMotion.earnedProgress,
                value: normalizedValue
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(valueLabel ?? percentageLabel)
    }

    var normalizedValue: Double {
        min(max(value, 0), 1)
    }

    private var percentageLabel: String {
        String(localized: "\(Int((normalizedValue * 100).rounded())) percent")
    }
}

enum NoumRewardKind: Equatable, Sendable {
    case xp(Int)
    case evidenceSaved
    case milestone(String)

    var isRenderable: Bool {
        switch self {
        case let .xp(amount): return amount > 0
        case .evidenceSaved: return true
        case let .milestone(title): return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var value: String {
        switch self {
        case let .xp(amount): return "+\(amount) XP"
        case .evidenceSaved: return String(localized: "Evidence saved")
        case let .milestone(title): return title
        }
    }

    var label: String {
        switch self {
        case .xp: return String(localized: "Earned")
        case .evidenceSaved: return String(localized: "From this rep")
        case .milestone: return String(localized: "Milestone")
        }
    }
}

/// Compact earned-value receipt. Invalid rewards (for example zero XP) do not
/// render, preventing a visual primitive from manufacturing progress.
struct NoumRewardPill: View {
    let kind: NoumRewardKind

    var body: some View {
        Group {
            if kind.isRenderable {
                NoumSurface(.reward) {
                    HStack(spacing: Spacing.sm) {
                        NoumWaveformMark(
                            state: .earned,
                            size: NoumControlMetric.minimumTouchTarget
                        )
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(kind.value)
                                .font(Typography.cardTitle)
                                .foregroundStyle(AppColor.rewardGoldInk)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(kind.label)
                                .font(Typography.captionSmall)
                                .foregroundStyle(AppColor.rewardGoldInk)
                        }
                    }
                    .frame(minHeight: NoumControlMetric.rewardMinimumHeight)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: - Interaction defaults

extension View {
    /// Expands compact labels and glyphs to the minimum accessible hit target.
    func noumMinimumTouchTarget() -> some View {
        frame(
            minWidth: NoumControlMetric.minimumTouchTarget,
            minHeight: NoumControlMetric.minimumTouchTarget
        )
        .contentShape(Rectangle())
    }
}

/// Shared icon-only control with a guaranteed label and touch target.
struct NoumIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    var tint: Color = AppColor.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .noumMinimumTouchTarget()
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(accessibilityLabel)
    }
}
#endif
