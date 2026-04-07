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
    /// Sudden Death mode
    static let modeSuddenDeath = Color(red: 0.95, green: 0.55, blue: 0.15)
    /// Ah-Counter mode
    static let modeAhCounter = Color(red: 0.14, green: 0.60, blue: 0.44)
    /// IM Conversation mode
    static let modeIM = Color(red: 0.32, green: 0.43, blue: 0.94)

    // MARK: Semantic Feedback

    /// Positive / good score
    static let positive = Color(red: 0.10, green: 0.56, blue: 0.40)
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
struct SectionHeader<Trailing: View>: View {
    let title: String
    let icon: String?
    @ViewBuilder let trailing: () -> Trailing

    init(_ title: String, icon: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.icon = icon
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            if let icon {
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
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.snappySpring, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

/// Standardized primary CTA button.
struct PrimaryCTA: View {
    let title: String
    let icon: String?
    let tint: Color
    let action: () -> Void

    init(_ title: String, icon: String? = nil, tint: Color = AppColor.brandBlue, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.tint = tint
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
            .foregroundStyle(.white)
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

// MARK: - Shared Helpers

extension PracticeMode {
    /// Display label for the mode.
    var displayLabel: String {
        switch self {
        case .timed: return "Timed"
        case .suddenDeath: return "Sudden Death"
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
#endif
