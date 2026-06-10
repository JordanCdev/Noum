//
//  DesignSystem.swift
//  Noum
//
//  Shared design tokens for consistent visual language across all screens.
//

#if canImport(SwiftUI)
import SwiftUI

// MARK: - Corner Radii

/// Standardized corner radius values used across the app.
enum CornerRadius {
    /// Small elements: chips, tags, inner containers (12pt)
    static let small: CGFloat = 12
    /// Medium elements: stat cards, secondary containers, buttons (18pt)
    static let medium: CGFloat = 18
    /// Large elements: primary content cards (24pt)
    static let large: CGFloat = 24
    /// Extra-large: hero cards, full-width panels, sheets (28pt)
    static let xl: CGFloat = 28
}

// MARK: - Spacing

/// Standardized spacing values for consistent rhythm.
enum Spacing {
    /// Tight spacing between related elements (4pt)
    static let xxs: CGFloat = 4
    /// Compact spacing (8pt)
    static let xs: CGFloat = 8
    /// Standard inner spacing (12pt)
    static let sm: CGFloat = 12
    /// Default content spacing (16pt)
    static let md: CGFloat = 16
    /// Section-level spacing (20pt)
    static let lg: CGFloat = 20
    /// Screen-level horizontal padding (20pt)
    static let screenH: CGFloat = 20
    /// Inter-card spacing (14pt)
    static let cardGap: CGFloat = 14
}

// MARK: - App Colors

/// Centralized color definitions — the single source of truth.
enum AppColor {

    // MARK: Backgrounds

    /// Standard screen background
    static let screenBackground = Color(UIColor.systemGroupedBackground)

    /// Light gradient used by setup/selection screens
    static let lightGradientStart = Color(red: 0.97, green: 0.97, blue: 1.0)
    static let lightGradientEnd = Color(red: 0.93, green: 0.95, blue: 1.0)

    /// Card surface
    static let cardBackground = Color.white
    /// Subtle inner surface (transcript backgrounds, secondary containers)
    static let innerSurface = Color(red: 0.97, green: 0.97, blue: 0.98)

    // MARK: Brand & Accent

    /// Premium/Pro purple
    static let pro = Color(red: 0.56, green: 0.28, blue: 0.92)
    /// Lighter pro purple for gradients
    static let proLight = Color(red: 0.82, green: 0.52, blue: 1.0)
    /// Primary brand blue
    static let brandBlue = Color(red: 0.20, green: 0.47, blue: 0.96)
    /// Lighter brand blue for gradients
    static let brandBlueLight = Color(red: 0.26, green: 0.63, blue: 1.00)

    // MARK: Mode Tints

    /// Timed mode
    static let modeTimed = Color(red: 0.20, green: 0.47, blue: 0.96)
    /// Pressure Drill mode
    static let modeSuddenDeath = Color(red: 0.95, green: 0.55, blue: 0.15)
    /// Ah-Counter mode
    static let modeAhCounter = Color(red: 0.14, green: 0.60, blue: 0.44)
    /// IM Conversation mode
    static let modeIM = Color(red: 0.32, green: 0.43, blue: 0.94)
    /// Cut the Crutch — control / restraint drill (warm rose, distinct from pressure tints)
    static let modeCrutch = Color(red: 0.78, green: 0.32, blue: 0.50)
    /// Pace Training mode — teal, distinct from modeAhCounter's green
    static let modePace = Color(red: 0.15, green: 0.72, blue: 0.78)

    // MARK: Semantic Feedback

    /// Positive / good score (#199966)
    static let positive = Color(red: 0.10, green: 0.60, blue: 0.40)
    /// Caution / okay score
    static let caution = Color(red: 0.83, green: 0.52, blue: 0.10)
    /// Warning / needs improvement
    static let warning = Color(red: 0.74, green: 0.22, blue: 0.20)

    // MARK: Text

    /// Primary text (use .primary for most cases)
    static let textPrimary = Color(red: 0.13, green: 0.15, blue: 0.20)
    /// Secondary / muted text
    static let textSecondary = Color(red: 0.41, green: 0.45, blue: 0.52)

    // MARK: Surfaces & Borders

    /// Subtle background for tags, chips
    static let tagBackground = Color.black.opacity(0.04)
    /// Subtle border/stroke
    static let subtleBorder = Color.black.opacity(0.05)

    /// Returns the tint color for a given practice mode.
    static func tint(for mode: PracticeMode) -> Color {
        switch mode {
        case .timed: return modeTimed
        case .suddenDeath: return modeSuddenDeath
        case .ahCounter: return modeAhCounter
        case .imConversation: return modeIM
        }
    }
}

// MARK: - Spring Animations

extension Animation {
    /// Standard interaction spring — cards, toggles, selections
    static let standardSpring = Animation.spring(response: 0.34, dampingFraction: 0.84)
    /// Snappy spring for quick interactions — chips, tabs
    static let snappySpring = Animation.spring(response: 0.26, dampingFraction: 0.88)
    /// Bouncy spring for celebrations, emphasis
    static let bouncySpring = Animation.spring(response: 0.40, dampingFraction: 0.65)

    // MARK: Reward & Progress Animations

    /// Duration companion for `scoreReveal`. Referenced wherever a beat
    /// must land on the ring's settle frame (haptic, delta pop) so the
    /// channels can't drift apart — never hardcode 0.8 at a call site.
    static let scoreRevealDuration: TimeInterval = 0.8
    /// Score number count-up landing — smooth deceleration
    static let scoreReveal = Animation.easeOut(duration: scoreRevealDuration)
    /// Press squish for `PressableButtonStyle` — fast enough to track the
    /// finger, springy enough to read as physical.
    static let buttonSquish = Animation.spring(response: 0.15, dampingFraction: 0.8)
    /// Stat delta badge pop-in — delayed bouncy spring
    static let statDelta = Animation.spring(response: 0.4, dampingFraction: 0.65).delay(0.3)
    /// Achievement badge or icon appearance
    static let achievementPop = Animation.spring(response: 0.5, dampingFraction: 0.55)
    /// Progress bar fill — smooth linear-to-ease
    static let progressFill = Animation.easeOut(duration: 0.6)
    /// Staggered list item entrance — pass index for delay
    static func stagger(_ index: Int) -> Animation {
        .spring(response: 0.34, dampingFraction: 0.84).delay(Double(index) * 0.08)
    }
    /// Coach note line appearance — staggered reading rhythm
    static func coachLineStagger(_ index: Int) -> Animation {
        .easeOut(duration: 0.3).delay(0.15 + Double(index) * 0.15)
    }
}

// MARK: - Shared View Components

/// Standard white card container used across the app.
struct CardView<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        cornerRadius: CGFloat = CornerRadius.xl,
        padding: CGFloat = Spacing.lg,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Stat card used in practice screens, summaries, and analytics.
struct StatCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }
}

/// Standardized error display card.
struct ErrorCard: View {
    let message: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }
}

/// Standardized section header with optional trailing content.
///
/// Optionally accepts a `glyph: NoumCharacter.Inline?` so the coach can
/// narrate the section — e.g. the "Today" and "This week" headers on the
/// Home screen carry a small Noum glyph that signals "this is what the
/// coach is reading from your data". The glyph is mutually-exclusive
/// with the SF Symbol `icon` slot: when both are set the glyph wins, so
/// the coach voice always takes precedence over a generic symbol.
struct SectionHeader<Trailing: View>: View {
    let title: String
    let icon: String?
    let glyph: NoumCharacter.Inline?
    @ViewBuilder let trailing: () -> Trailing

    init(
        _ title: String,
        icon: String? = nil,
        glyph: NoumCharacter.Inline? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.glyph = glyph
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            // Coach glyph wins over the SF Symbol icon — when both are
            // set, the coach voice is the one narrating this section.
            if let glyph {
                glyph
            } else if let icon {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            trailing()
        }
    }
}

/// Button style that provides a subtle press-down effect for tactile feedback.
/// Opacity dip + a 0.97 squish: pure input confirmation that acknowledges
/// the tap itself and claims nothing. `contentShape` keeps the full frame
/// tappable, and because the button gesture is already captured by the time
/// the press state flips, the mid-press scale never shrinks the hit area
/// out from under the finger. Reduce Motion: opacity only (no scale).
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressableLabel(configuration: configuration)
    }

    /// Inner view so the style can read the environment — `ButtonStyle`
    /// itself is not a `View`, so `@Environment` only resolves here.
    private struct PressableLabel: View {
        let configuration: Configuration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.7 : 1.0)
                .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1.0)
                .contentShape(Rectangle())
                .animation(
                    reduceMotion ? .easeOut(duration: 0.1) : .buttonSquish,
                    value: configuration.isPressed
                )
        }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

/// Standardized primary CTA button.
///
/// `labelTint` defaults to white (tinted capsule, white label). On a
/// gradient hero pass `tint: .white, labelTint: <hero start colour>` for
/// the inverted white-capsule register.
struct PrimaryCTA: View {
    let title: String
    let icon: String?
    let tint: Color
    let labelTint: Color
    let action: () -> Void

    init(_ title: String, icon: String? = nil, tint: Color = AppColor.brandBlue, labelTint: Color = .white, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.labelTint = labelTint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.headline.weight(.semibold))
                }
                Text(title)
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(labelTint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(tint.gradient, in: Capsule(style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}

/// Light gradient background used by setup/selection screens.
struct LightGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [AppColor.lightGradientStart, AppColor.lightGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Hero Gradient System

/// Hero gradient endpoints (docs/UX_VISUAL_DIRECTION.md — owner-approved
/// colour pass). Named by surface semantics, not by colour.
extension AppColor {
    /// Verdict hero (post-rep): indigo → violet
    static let verdictHeroStart = Color(red: 0.23, green: 0.43, blue: 0.96)
    static let verdictHeroMid   = Color(red: 0.42, green: 0.30, blue: 0.96)
    static let verdictHeroEnd   = Color(red: 0.55, green: 0.24, blue: 0.96)
    /// Coach hero (Home prescription): blue → cyan
    static let coachHeroStart = Color(red: 0.18, green: 0.48, blue: 0.96)
    static let coachHeroMid   = Color(red: 0.23, green: 0.63, blue: 1.00)
    static let coachHeroEnd   = Color(red: 0.09, green: 0.78, blue: 0.81)
    /// Progress hero (Profile speaking rating): blue → green
    static let progressHeroStart = Color(red: 0.18, green: 0.48, blue: 0.96)
    static let progressHeroMid   = Color(red: 0.17, green: 0.56, blue: 0.61)
    static let progressHeroEnd   = Color(red: 0.08, green: 0.62, blue: 0.41)
}

/// The three approved hero gradients — ONE vibrant gradient hero per
/// screen, everything else stays calm. Use through `GradientHeroCard`;
/// don't scatter raw per-screen `LinearGradient`s.
enum HeroGradient {
    /// Post-rep verdict: indigo → violet
    case verdict
    /// Home coach prescription: blue → cyan
    case coach
    /// Profile speaking rating: blue → green
    case progress

    var gradient: LinearGradient {
        switch self {
        case .verdict:
            return LinearGradient(
                colors: [AppColor.verdictHeroStart, AppColor.verdictHeroMid, AppColor.verdictHeroEnd],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .coach:
            return LinearGradient(
                colors: [AppColor.coachHeroStart, AppColor.coachHeroMid, AppColor.coachHeroEnd],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .progress:
            return LinearGradient(
                colors: [AppColor.progressHeroStart, AppColor.progressHeroMid, AppColor.progressHeroEnd],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    /// Shadow tint matching the gradient family (tinted shadows, never gray).
    var shadowTint: Color {
        switch self {
        case .verdict: return AppColor.verdictHeroMid
        case .coach: return AppColor.coachHeroStart
        case .progress: return AppColor.progressHeroMid
        }
    }
}

/// Gradient hero card — the single vibrant surface on a screen. Content
/// renders white-on-gradient; everything else on the screen stays a calm
/// white card.
struct GradientHeroCard<Content: View>: View {
    let style: HeroGradient
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        _ style: HeroGradient,
        padding: CGFloat = Spacing.lg,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.gradient, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .shadow(color: style.shadowTint.opacity(0.30), radius: 18, y: 10)
    }
}

/// Frosted stat chip for use ON a gradient hero (white-on-gradient).
struct HeroGlassChip: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xs + 2)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: CornerRadius.small + 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.small + 3, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Shared Helpers

extension PracticeMode {
    /// Display label for the mode.
    var displayLabel: String {
        switch self {
        case .timed: return "Timed"
        case .suddenDeath: return "Pressure Drill"
        case .ahCounter: return "Ah-Counter"
        case .imConversation: return "IM Mode"
        }
    }

    /// SF Symbol icon name for the mode.
    var iconName: String {
        switch self {
        case .timed: return "timer"
        case .suddenDeath: return "bolt.fill"
        case .ahCounter: return "waveform"
        case .imConversation: return "bubble.left.and.bubble.right.fill"
        }
    }

    /// Tint color for the mode.
    var tint: Color {
        AppColor.tint(for: self)
    }
}

/// Shared recursive dismiss helper for practice views.
func dismissRecursively(from dismiss: DismissAction, times: Int = 2) {
    dismiss()
    if times > 1 {
        DispatchQueue.main.async {
            dismissRecursively(from: dismiss, times: times - 1)
        }
    }
}

// MARK: - Milestone Celebration Overlay

/// A full-screen milestone celebration that interrupts to celebrate achievements.
struct MilestoneCelebrationOverlay: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let detail: String?
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var dismissed = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismissCelebration() }

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 100, height: 100)
                        .scaleEffect(appeared ? 1.2 : 0.5)
                    Circle()
                        .stroke(tint.opacity(0.25), lineWidth: 2)
                        .frame(width: 110, height: 110)
                        .scaleEffect(appeared ? 1.3 : 0.4)
                    Image(systemName: icon)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(tint)
                        .scaleEffect(appeared ? 1.0 : 0.3)
                }

                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                // M25: Continue button removed. The celebration is a
                // moment the user reads, not a screen they navigate.
                // Auto-dismiss after 5s lands on summary without an
                // interaction tax; tap-to-dismiss-anywhere stays so a
                // user who wants to move on faster still can.
            }
            .padding(32)
            .scaleEffect(appeared ? 1.0 : 0.7)
            .opacity(appeared ? 1.0 : 0)
        }
        .opacity(dismissed ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { dismissCelebration() }
        .onAppear {
            withAnimation(.bouncySpring) { appeared = true }
#if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
            // Auto-advance to summary after 5s. Cancelled implicitly if
            // the user taps to dismiss earlier (the second call into
            // dismissCelebration is idempotent — `dismissed` already
            // true on the second pass).
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                guard !dismissed else { return }
                dismissCelebration()
            }
        }
    }

    private func dismissCelebration() {
        withAnimation(.easeOut(duration: 0.25)) { dismissed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
    }
}

/// Represents a milestone event to celebrate.
struct MilestoneEvent: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let detail: String?

    static func == (lhs: MilestoneEvent, rhs: MilestoneEvent) -> Bool {
        lhs.id == rhs.id
    }
}
#endif
