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
    /// V4.6 immersive pill CTA (30pt — capsule of the 58pt pill).
    static let pill: CGFloat = 30
    /// V4.6 Today hero bottom bleed (36pt).
    static let hero: CGFloat = 36
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
    /// V4.6 hero interior padding / section rhythm (24pt)
    static let xl: CGFloat = 24
    /// V4.6 large section air (32pt)
    static let xxl: CGFloat = 32
    /// V4.6 hero bottom air / generous section break (40pt)
    static let xxxl: CGFloat = 40

    /// Reserved scroll clearance for an immersive screen's safe-area action.
    static let focusedActionClearance: CGFloat = 112
    /// Physical viewport clearance for iOS's floating tab glass. Root scroll
    /// views use this as outer padding so copy is clipped above navigation,
    /// rather than merely remaining scrollable underneath it.
    static let tabRootNavigationClearance: CGFloat = 92
    /// Height + air of the V4.6 floating capsule bar — bottom-anchored
    /// controls on tab roots pad by this so the capsule never covers them.
    static let floatingTabBarClearance: CGFloat = 72
}

// MARK: - App Colors

/// Trait-resolving colour for the V4.6 semantic theme. Light and dark
/// values come from the frozen token contract (SwiftUI board 258:1865):
/// dark frames are semantic recolours of the same roles, never new hues.
private func dynamicColor(
    light: (Double, Double, Double),
    dark: (Double, Double, Double)
) -> Color {
    Color(UIColor { traits in
        let value = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
    })
}

private func dynamicOpacity(
    lightWhiteAmount: Double,
    darkWhiteAmount: Double,
    lightAlpha: Double,
    darkAlpha: Double
) -> Color {
    Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: darkWhiteAmount, alpha: darkAlpha)
            : UIColor(white: lightWhiteAmount, alpha: lightAlpha)
    })
}

/// Centralized color definitions — the single source of truth.
enum AppColor {

    // MARK: Backgrounds

    /// Standard screen background — the V4.6 warm canvas in both modes
    /// (#FAF9F7 → #17151C per the frozen token contract).
    static let screenBackground = dynamicColor(
        light: (0.980, 0.976, 0.969),
        dark: (0.090, 0.082, 0.110)
    )

    /// Light gradient used by setup/selection screens
    static let lightGradientStart = Color(red: 0.97, green: 0.97, blue: 1.0)
    static let lightGradientEnd = Color(red: 0.93, green: 0.95, blue: 1.0)

    /// Card surface — white on the warm canvas, warm dark surface in dark.
    static let cardBackground = dynamicColor(
        light: (1.0, 1.0, 1.0),
        dark: (0.129, 0.114, 0.169)
    )
    /// Subtle inner surface (transcript backgrounds, secondary containers)
    static let innerSurface = dynamicColor(
        light: (0.97, 0.97, 0.98),
        dark: (0.165, 0.149, 0.208)
    )

    // MARK: Brand & Accent

    /// Premium/Pro purple
    static let pro = Color(red: 0.56, green: 0.28, blue: 0.92)
    /// Lighter pro purple for gradients
    static let proLight = Color(red: 0.82, green: 0.52, blue: 1.0)
    /// Primary brand blue. The darker light-mode register keeps white
    /// labels above AA on buttons; dark mode lifts it so blue text and
    /// icons stay legible on the near-black canvas.
    static let brandBlue = dynamicColor(
        light: (0.10, 0.32, 0.70),
        dark: (0.30, 0.52, 0.95)
    )
    /// Lighter brand blue for gradients
    static let brandBlueLight = Color(red: 0.26, green: 0.63, blue: 1.00)
    /// Small brand-blue copy on tint-washed hero cards (eyebrows, "Why
    /// this rep?"). The standard dark `brandBlue` computes ~3.5–3.9:1 once
    /// the recommended card's 0.16-alpha mode-tint wash lifts the surface,
    /// below the 4.5:1 small-text threshold. This register keeps the exact
    /// light-mode value (5.9:1+ on washed white cards) and lifts dark mode
    /// to the `brandBlueLight` value: 4.63:1 against the brightest hero
    /// wash (Pressure Drill orange at 0.16 over #211D2B) and 6.08:1 on the
    /// plain dark card.
    static let brandBlueOnWash = dynamicColor(
        light: (0.10, 0.32, 0.70),
        dark: (0.26, 0.63, 1.00)
    )

    /// High-contrast foreground for the light blue-to-cyan coaching hero.
    /// The darkest raw hero stop still clears WCAG AA for body copy, while
    /// the navy register keeps the screen calm and visibly coach-led.
    static let coachHeroInk = Color(red: 0.02, green: 0.08, blue: 0.18)
    /// Opaque secondary-action surface for the continuously varying coach
    /// gradient. Its quiet cyan register preserves hierarchy while making
    /// both rendered contrast and the tappable boundary unambiguous.
    static let coachHeroQuietSurface = Color(red: 0.78, green: 0.92, blue: 0.98)
    /// High-contrast foreground for the blue-to-green progress hero.
    static let progressHeroInk = Color.black
    /// Semantic purple for copy and icons on coaching surfaces. Keep the
    /// brighter `pro` token for filled accents and decorative identity.
    static let proText = dynamicColor(
        light: (0.34, 0.12, 0.64),
        dark: (0.718, 0.612, 0.988)
    )
    /// Opaque quiet violet surface for secondary Pro actions/cards
    /// (light pale lavender → dark #2B2440 from the frozen primitives).
    static let proQuietSurface = dynamicColor(
        light: (0.95, 0.93, 0.99),
        dark: (0.169, 0.141, 0.251)
    )

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

    // MARK: Mode Action Registers
    //
    // Filled-CTA surfaces for the two mode tints too bright to hold a
    // white label (white on raw modePace = 2.41:1, on raw modeSuddenDeath
    // = 2.45:1 — below AA at any size). Same hue family, darkened until
    // the white 17pt-semibold label computes ≥4.5:1; the fills are static,
    // so the ratio holds in both colour schemes. Use these ONLY for filled
    // action surfaces — icons, washes, and strokes keep the raw tints.

    /// Pressure Drill filled-action surface — white label = 4.78:1.
    static let modeSuddenDeathAction = Color(red: 0.66, green: 0.38, blue: 0.10)
    /// Pace Training filled-action surface — white label = 4.71:1.
    static let modePaceAction = Color(red: 0.06, green: 0.50, blue: 0.55)

    // MARK: Focused Practice Canvas

    /// Semantic gradient stops for the full-screen practice canvas. Keeping
    /// these beside the mode tints prevents individual modes from inventing
    /// a second palette while still giving each drill a distinct register.
    static let focusedTimedGradient = [
        Color(red: 0.07, green: 0.12, blue: 0.28), modeTimed, modePace
    ]
    static let focusedPressureGradient = [
        Color(red: 0.17, green: 0.10, blue: 0.12),
        Color(red: 0.68, green: 0.24, blue: 0.16),
        modeSuddenDeath
    ]
    static let focusedClarityGradient = [
        Color(red: 0.05, green: 0.17, blue: 0.19),
        modeAhCounter,
        Color(red: 0.22, green: 0.70, blue: 0.58)
    ]
    static let focusedConversationGradient = [
        Color(red: 0.10, green: 0.10, blue: 0.28), modeIM, pro
    ]
    static let focusedCrutchGradient = [
        Color(red: 0.19, green: 0.08, blue: 0.17),
        modeCrutch,
        Color(red: 0.91, green: 0.44, blue: 0.45)
    ]
    static let focusedPaceGradient = [
        Color(red: 0.04, green: 0.16, blue: 0.22), modePace, modeTimed
    ]
    /// A uniform contrast layer keeps the semantic mode colour visible while
    /// ensuring white practice copy remains readable over every bright stop.
    static let focusedContrastScrim = Color.black.opacity(0.48)
    static let focusedGlassFill = Color.white.opacity(0.13)
    static let focusedGlassBorder = Color.white.opacity(0.18)
    static let focusedTextSecondary = Color.white.opacity(0.90)
    /// Mini-drill actions stay legible for every skill tint. Skill colour
    /// remains present in the orb, progress ring, and banner; the action itself
    /// uses one stable high-contrast foreground/surface contract.
    static let focusedPrimaryActionFill = Color.white
    static let focusedPrimaryActionText = Color.black

    // MARK: Semantic Feedback

    /// Positive / qualified improvement delta (#0E7A3B; dark value explicitly
    /// mapped — never grey-bucketed, per the token contract).
    ///
    /// The light value is the one the accessibility gate prescribed
    /// ("green → #0E7A3B"). It was previously #199966, which measures 3.44:1 on
    /// the warm canvas and 3.63:1 on a white card — under AA's 4.5:1 for normal
    /// text, and this token is used on `.caption`/`.caption2`/`.subheadline`
    /// deltas at ~28 sites, nowhere near the 18.66pt bold threshold that would
    /// allow 3:1. #0E7A3B measures 5.16:1 / 5.43:1. The dark value already
    /// measured 8.69:1 on the dark canvas and is unchanged.
    static let positive = dynamicColor(
        light: (0.055, 0.478, 0.231),
        dark: (0.263, 0.792, 0.561)
    )
    /// Caution / okay score — lapse rows, ALWAYS paired with a text cue.
    ///
    /// Light value darkened from #D48519 (2.79:1 on canvas — the worst
    /// contrast in the semantic set) to #A65E08 at 4.72:1, keeping the hue.
    /// The text-cue pairing rule stands: this is a second signal, not a
    /// replacement for one. Dark value was already 8.78:1 and is unchanged.
    static let caution = dynamicColor(
        light: (0.651, 0.369, 0.031),
        dark: (0.914, 0.659, 0.302)
    )
    /// Warning / needs improvement
    static let warning = dynamicColor(
        light: (0.74, 0.22, 0.20),
        dark: (0.910, 0.412, 0.384)
    )

    // MARK: Review Transformation (V4.6 founder-approved tokens)

    /// Live/settling voice-trace bars on natively dark practice surfaces
    /// (#9E70FA). Never used as text on light surfaces — decorative trace
    /// colour only, so it is exempt from the light-surface AA gate.
    static let voiceLive = Color(red: 0.62, green: 0.44, blue: 0.98)
    /// Receded wording in the transcript transformation (#5A6474 → dark
    /// #8A93A4): the words the one-step upgrade lets go of. Recede, never
    /// strikethrough — a text colour that clears AA on both surfaces.
    static let neutralReceded = dynamicColor(
        light: (0.353, 0.392, 0.455),
        dark: (0.541, 0.576, 0.643)
    )
    /// Pressed fill for the violet editorial CTA (#3F2499 → dark #7A4FF0).
    /// White label clears AA on both fills.
    static let actionPressed = dynamicColor(
        light: (0.247, 0.141, 0.60),
        dark: (0.478, 0.310, 0.941)
    )

    // MARK: V4.6 Coaching Loop (frozen page-17 token contract)

    /// Coaching ink (#4C2BB8 → dark #9061F9) — editorial CTA fill,
    /// improved-phrase tint, selected tab label, ink labels on the white
    /// immersive pill. Labels on these fills clear AA in both modes.
    static let coachingInk = dynamicColor(
        light: (0.298, 0.169, 0.722),
        dark: (0.565, 0.380, 0.976)
    )
    /// Coach accent (#7C3AED → dark #9061F9) — trace bars and evidence
    /// marks on editorial surfaces. Decorative/graphic colour, never body.
    static let coachAccent = dynamicColor(
        light: (0.486, 0.227, 0.929),
        dark: (0.565, 0.380, 0.976)
    )
    /// Selected navigation-capsule label + glyph, read against the quiet
    /// violet pill they sit on. Both roles resolve to #9061F9 in dark,
    /// which computes 3.68:1 on `proQuietSurface` — under AA for the
    /// 10.5pt nav label. These registers keep each V4.6 light value
    /// untouched and lift dark to the `proText` violet (6.42:1), the same
    /// keep-light-lift-dark shape as `brandBlueOnWash`.
    static let coachingInkOnQuiet = dynamicColor(
        light: (0.298, 0.169, 0.722),
        dark: (0.718, 0.612, 0.988)
    )
    static let coachAccentOnQuiet = dynamicColor(
        light: (0.486, 0.227, 0.929),
        dark: (0.718, 0.612, 0.988)
    )
    /// Today hero gradient stops (#4D3CC7 → #6D46D6 at ~141°). The hero is
    /// the app's single marquee gradient; nothing else may use these stops.
    ///
    /// The end stop is the value the accessibility gate prescribed ("darken the
    /// gradient's light stop to >= #6D46D6 behind body copy"), which had not
    /// been adopted. It shipped as #7A45E0, where white text measured 3.57:1 at
    /// 0.7 alpha and 4.18:1 at 0.8 — the Home XXXL native audit failed on
    /// exactly this. On #6D46D6 white clears AA from 0.85 alpha upward
    /// (4.82:1) and reaches 6.00:1 at full strength.
    static let heroGradientStart = Color(red: 0.302, green: 0.235, blue: 0.780)
    static let heroGradientEnd = Color(red: 0.427, green: 0.275, blue: 0.839)
    /// Text roles for the continuously varying Home hero. Native contrast
    /// audits sample one backdrop point for the gradient, so these named roles
    /// are shared with the deterministic two-stop contrast gate.
    static let homeHeroTitleText = Color.white
    static let homeHeroSubtitleText = Color.white.opacity(0.85)
    static let homeHeroMetaText = Color.white.opacity(0.90)
    static let homeHeroSecondaryActionText = Color.white.opacity(0.95)
    /// Warm editorial canvas behind the V4.6 loop's screens
    /// (#FAF9F7 → #17151C, same mapping as `screenBackground`).
    static let warmCanvas = dynamicColor(
        light: (0.980, 0.976, 0.969),
        dark: (0.090, 0.082, 0.110)
    )
    /// Natively-dark immersive surface stops for Recording/Processing
    /// (#1B1625 → #100D19). These screens are dark in both appearances.
    static let immersiveTop = Color(red: 0.106, green: 0.086, blue: 0.145)
    static let immersiveBottom = Color(red: 0.063, green: 0.051, blue: 0.098)

    // MARK: Text

    /// Primary text (use .primary for most cases)
    static let textPrimary = dynamicColor(
        light: (0.13, 0.15, 0.20),
        dark: (0.949, 0.945, 0.965)
    )
    /// Secondary / muted text. Deliberately stronger than the system
    /// secondary label so coaching evidence remains readable at small roles.
    static let textSecondary = dynamicColor(
        light: (0.29, 0.33, 0.40),
        dark: (0.725, 0.706, 0.780)
    )
    /// Quiet metadata that still clears AA on Noum's surfaces.
    static let textTertiary = dynamicColor(
        light: (0.36, 0.40, 0.47),
        dark: (0.604, 0.580, 0.675)
    )

    // MARK: Rendered accessibility roles

    /// Exact semantic roles consumed by views whose continuously varying or
    /// simulator-sampled surfaces require a narrowly scoped native-audit
    /// exception. The contrast suite resolves these same values against their
    /// production surfaces, keeping the exception tied to rendered styling.
    static let recommendationActionFill = brandBlue
    static let recommendationActionText = Color.white
    static let recommendationDisclosureText = brandBlueOnWash
    /// Exact top stop behind the Review story eyebrow. Keep this shared with
    /// the deterministic contrast guard so the native-audit exception cannot
    /// drift away from the rendered gradient.
    static let reviewStoryWash = brandBlue.opacity(0.10)
    static let reviewStoryLabelText = textSecondary
    static let profileMetricLabelText = textSecondary
    static let coachPlanText = textPrimary
    static let reviewTranscriptAccentText = proText
    static let reviewTranscriptBodyText = textPrimary
    static let reviewTranscriptDetailText = textSecondary

    // MARK: Progress chart marks

    /// Opaque, appearance-aware registers for information-bearing chart marks.
    /// The identity tints remain available for decorative washes and picker
    /// fills; these stronger variants are reserved for lines and points that
    /// must remain distinguishable over every layer of the chart plot.
    static let progressScoreMark = brandBlue
    static let progressFillerMark = caution
    static let progressPaceMark = dynamicColor(
        light: (0.07, 0.48, 0.34),
        dark: (0.28, 0.72, 0.56)
    )
    static let progressPauseMark = dynamicColor(
        light: (0.25, 0.34, 0.80),
        dark: (0.45, 0.56, 1.00)
    )
    static let progressPitchMark = dynamicColor(
        light: (0.75, 0.10, 0.25),
        dark: (1.00, 0.40, 0.52)
    )
    /// Quiet neutral for the average rule. Its hierarchy comes from the thin,
    /// dashed stroke rather than contrast-reducing opacity.
    static let progressReferenceLine = dynamicColor(
        light: (0.43, 0.45, 0.50),
        dark: (0.58, 0.56, 0.64)
    )

    // MARK: Surfaces & Borders

    /// Subtle background for tags, chips
    static let tagBackground = dynamicOpacity(
        lightWhiteAmount: 0, darkWhiteAmount: 1,
        lightAlpha: 0.04, darkAlpha: 0.08
    )
    /// Subtle border/stroke
    static let subtleBorder = dynamicOpacity(
        lightWhiteAmount: 0, darkWhiteAmount: 1,
        lightAlpha: 0.05, darkAlpha: 0.10
    )

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
    /// Duration companion for `progressFill` — referenced wherever a beat
    /// must land on the fill's settle frame (count-settle tick) so the
    /// channels can't drift apart. Never hardcode 0.6 at a call site.
    static let progressFillDuration: TimeInterval = 0.6
    /// Progress bar fill — smooth linear-to-ease
    static let progressFill = Animation.easeOut(duration: progressFillDuration)
    /// Staggered list item entrance — pass index for delay
    static func stagger(_ index: Int) -> Animation {
        .spring(response: 0.34, dampingFraction: 0.84).delay(Double(index) * 0.08)
    }
    /// Coach note line appearance — staggered reading rhythm
    static func coachLineStagger(_ index: Int) -> Animation {
        .easeOut(duration: 0.3).delay(0.15 + Double(index) * 0.15)
    }

    // MARK: V4.6 Motion Contract (page-17 transition names)
    //
    // Standard timings from the frozen motion sheet. Every use MUST branch
    // on `accessibilityReduceMotion`, replacing the smart-animate value with
    // the paired RM fade — `Animation.v46ReduceMotionFade` (200 ms) unless
    // the sheet names a different fallback. Never hardcode these durations
    // at call sites.

    /// pushRecording · closeLoop · tabToProgress — 340 ms settle.
    static let v46Settle = Animation.easeInOut(duration: 0.34)
    /// settleToProcessing · retrySamePrompt — 260 ms.
    static let v46Quick = Animation.easeInOut(duration: 0.26)
    /// revealReview dissolve — 600 ms (same under RM, no drift).
    static let v46Dissolve = Animation.easeInOut(duration: 0.6)
    /// Reduce Motion pair for the smart-animate steps — 200 ms fade.
    static let v46ReduceMotionFade = Animation.easeInOut(duration: 0.2)

    // MARK: V4.6.1 semantic vocabulary
    //
    // One motion vocabulary for the whole app: three speeds and two payoff
    // specials, each an alias onto an existing curve so no parallel timing
    // system can drift. Surface code uses THESE names; the raw curves above
    // stay for legacy call sites.

    /// Finger-tracking press feedback (buttons, capsules).
    static let tapFeedback = Animation.buttonSquish
    /// List compress/expand, selection dim, chip swaps — quick.
    static let listChange = Animation.snappySpring
    /// Entrances, reveals, CTA arrival — the default settle.
    static let settle = Animation.standardSpring
    /// Earned-moment reveal (comparison payoff, earned-hero flip) —
    /// 600 ms transformation per the signed-off V4.4 motion pairs.
    /// Beat companion: `payoffRevealDuration` — a haptic or cue that must
    /// land on the settle frame reads this, never a hardcoded 0.6.
    static let payoffRevealDuration: TimeInterval = 0.6
    static let payoffReveal = Animation.spring(response: payoffRevealDuration, dampingFraction: 0.86)
    /// Progress update acknowledgement (bars, counts) — reuses progressFill
    /// so the fill and its settle-frame beat stay on one clock.
    static let progressAck = Animation.progressFill
}

/// The blessed imperative Reduce-Motion guard: apply `changes` inside
/// `withAnimation(animation)` normally, or instantly when Reduce Motion is
/// on. Views read `@Environment(\.accessibilityReduceMotion)` and pass it
/// in — this helper exists so the branch is written once, not per surface.
@MainActor
func withMotion(_ reduceMotion: Bool, _ animation: Animation, _ changes: () -> Void) {
    if reduceMotion {
        changes()
    } else {
        withAnimation(animation) {
            changes()
        }
    }
}

// MARK: - Shared View Components

/// Standard white card container used across the app.
struct CardView<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        cornerRadius: CGFloat = CornerRadius.large,
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
/// `labelTint` defaults to white (solid tinted capsule, white label). A
/// caller may still pass a light tint with a dark `labelTint`, but the shared
/// control deliberately does not invent a decorative gradient: the action's
/// hierarchy should come from its label and contrast, not changing colour.
struct PrimaryCTA: View {
    let title: String
    let icon: String?
    let tint: Color
    let labelTint: Color
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

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
                    .font(Typography.cardLabel)
            }
            .foregroundStyle(isEnabled ? labelTint : AppColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background {
                Capsule(style: .continuous)
                    .fill(isEnabled ? AnyShapeStyle(tint) : AnyShapeStyle(AppColor.innerSurface))
            }
            .overlay {
                if !isEnabled {
                    Capsule(style: .continuous)
                        .stroke(AppColor.subtleBorder, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.pressable)
    }
}

/// V4.6 immersive primary action — the white pill on gradient/dark surfaces
/// ("Start rep", "I'm done"). One geometry: full-width capsule, ≥58 pt, ink
/// label. Pressed dims the fill to 84 % (a state cue, not motion — safe under
/// Reduce Motion by construction); disabled drops fill/label opacity; loading
/// swaps the label for three ink dots and announces "Starting". The capsule
/// grows with wrapped labels at accessibility sizes, radius following height.
struct ImmersiveCTA: View {
    let title: String
    var isLoading: Bool = false
    /// Surfaces the button's real press state to the host (V4.6.1 armed
    /// trace: the Today hero gains while the commit CTA is held). Optional
    /// so every other call site is unaffected.
    var isPressed: Binding<Bool>? = nil
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loadingPhase: Int = 0

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(Typography.figtree(size: 17, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(AppColor.coachingInk.opacity(isEnabled ? 1 : 0.45))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    loadingDots
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 58)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(ImmersiveCTAButtonStyle(isEnabled: isEnabled, pressBinding: isPressed))
        .accessibilityLabel(Text(isLoading ? "Starting" : title))
        .disabled(isLoading)
    }

    private var loadingDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppColor.coachingInk)
                    .frame(width: 7, height: 7)
                    .opacity(reduceMotion ? 0.8 : (loadingPhase == index ? 1 : 0.35))
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            loadingPhase = 0
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(280))
                loadingPhase = (loadingPhase + 1) % 3
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ImmersiveCTAButtonStyle: ButtonStyle {
    let isEnabled: Bool
    var pressBinding: Binding<Bool>? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Color.white.opacity(
                    isEnabled ? (configuration.isPressed ? 0.84 : 1) : 0.40
                ),
                in: Capsule(style: .continuous)
            )
            // Tactile press: subtle scale alongside the fill dim. Reduce
            // Motion keeps the dim-only state cue.
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.985 : 1)
            .animation(.tapFeedback, value: configuration.isPressed)
            // Fill, scale, and shadow respond together: pressed sits
            // closer to the surface (tighter, lower shadow).
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.10 : 0.06),
                radius: configuration.isPressed ? 12 : 24,
                y: configuration.isPressed ? 4 : 8
            )
            .onChange(of: configuration.isPressed) { _, pressed in
                pressBinding?.wrappedValue = pressed
            }
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

// MARK: - Reading & Configuration Scaffolds

/// Neutral, scrollable page scaffold for information-heavy screens.
///
/// The scaffold deliberately owns no navigation or feature state. It only
/// applies Noum's shared canvas, reading width, spacing rhythm, and Dynamic
/// Type-safe header treatment so feature screens do not invent their own
/// card stacks.
struct ReadingScreenScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    let bottomClearance: CGFloat
    @ViewBuilder let content: () -> Content
    @Environment(\.isAppTabRoot) private var isAppTabRoot

    init(
        title: String,
        subtitle: String? = nil,
        bottomClearance: CGFloat = Spacing.lg,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.bottomClearance = bottomClearance
        self.content = content
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(title)
                            .font(Typography.screenTitle)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let subtitle {
                            Text(subtitle)
                                .font(Typography.subheadline)
                                .foregroundStyle(AppColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    content()
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                // Keep clearance inside the scroll content. Padding the
                // ScrollView itself shrinks its viewport and leaves a dead
                // strip above the floating tab bar, which can visibly clip a
                // card halfway through the screen.
                .padding(
                    .bottom,
                    bottomClearance + (isAppTabRoot ? Spacing.tabRootNavigationClearance : 0)
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// One calm group of destination rows. Callers supply the rows and dividers;
/// this component owns only the shared title and container treatment.
struct GroupedDestinationList<Content: View>: View {
    let title: String
    let subtitle: String?
    let tint: Color
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        tint: Color = AppColor.brandBlue,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Capsule()
                    .fill(tint)
                    .frame(width: 4, height: subtitle == nil ? 22 : 38)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(tint.opacity(0.16), lineWidth: 1)
            )
        }
    }
}

/// Compact coaching brief with one observation, optional evidence caption,
/// and one next move. It intentionally has no card background so it can sit
/// inside a hero without creating a nested surface.
struct CoachBriefSurface: View {
    let observation: String
    let evidence: String?
    let nextMove: String
    let tint: Color

    init(
        observation: String,
        evidence: String? = nil,
        nextMove: String,
        tint: Color = AppColor.brandBlue
    ) {
        self.observation = observation
        self.evidence = evidence
        self.nextMove = nextMove
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(observation)
                .font(Typography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let evidence {
                Text(evidence)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Image(systemName: "target")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(nextMove)
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Shared sheet framing for quiet configuration and reflection flows. The
/// feature owns its bindings and dismissal; this view only aligns the title,
/// content, and bottom actions without adding animation or persisted state.
struct QuietSheetScaffold<Content: View, Actions: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content
    @ViewBuilder let actions: () -> Actions

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.actions = actions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.sectionHero)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            content()
            Spacer(minLength: 0)
            actions()
        }
        .padding(.horizontal, Spacing.screenH)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.sm)
        .background(AppColor.screenBackground.ignoresSafeArea())
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
            .shadow(color: style.shadowTint.opacity(0.10), radius: 12, y: 6)
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

/// Final presentation guard for coaching text produced by older deterministic
/// paths. It changes vocabulary only; evidence and recommendation ownership
/// remain with the existing engines.
enum CoachDisplayCopy {
    static func normalized(_ value: String) -> String {
        var result = value
        let replacements: [(String, String)] = [
            ("highest-leverage", "main"),
            ("strongest lever", "main focus"),
            ("leverage point", "focus"),
            ("the rolling baseline makes", "recent reps make"),
            ("the rolling baseline", "recent reps"),
            ("rolling baseline", "recent reps"),
            ("rehearsal shapes", "practice rounds"),
            ("read gets sharper", "coaching gets more specific"),
            ("case-file intervention", "coaching focus"),
            ("case file's next move", "coaching plan's next move"),
            ("case file", "coaching plan"),
            ("active intervention", "current coaching focus"),
            ("followed rep", "completed rep"),
            ("proof point", "concrete example"),
            ("rule-based", ""),
            ("using:", "")
        ]
        for (source, replacement) in replacements {
            result = replacingMatches(
                of: NSRegularExpression.escapedPattern(for: source),
                in: result,
                with: replacement
            )
        }
        result = replacingMatches(
            of: "\\blever\\b",
            in: result,
            with: "focus"
        )
        return result
            .components(separatedBy: .newlines)
            .map {
                $0.replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Vocabulary substitutions are case-insensitive, but the user's sentence
    /// casing is not disposable. Preserve an uppercase source initial in the
    /// replacement so "The rolling baseline..." becomes "Recent reps..."
    /// rather than a visibly broken lowercase sentence.
    private static func replacingMatches(
        of pattern: String,
        in value: String,
        with replacement: String
    ) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return value
        }

        var result = value
        let source = value as NSString
        let matches = regex.matches(
            in: value,
            range: NSRange(location: 0, length: source.length)
        )
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let matched = source.substring(with: match.range)
            let adjustedReplacement: String
            if matched.first?.isUppercase == true,
               let first = replacement.first {
                adjustedReplacement = first.uppercased() + String(replacement.dropFirst())
            } else {
                adjustedReplacement = replacement
            }
            result.replaceSubrange(range, with: adjustedReplacement)
        }
        return result
    }
}

extension PracticeMode {
    /// Display label for the mode.
    var displayLabel: String {
        switch self {
        case .timed: return "Timed Practice"
        case .suddenDeath: return "Pressure Drill"
        case .ahCounter: return "Filler Control"
        case .imConversation: return "Conversation Practice"
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
