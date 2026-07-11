import SwiftUI

enum FocusedPracticeStyle {
    case timed
    case pressure
    case clarity
    case conversation
    case crutch
    case pace

    var accent: Color {
        switch self {
        case .timed: return AppColor.modeTimed
        case .pressure: return AppColor.modeSuddenDeath
        case .clarity: return AppColor.modeAhCounter
        case .conversation: return AppColor.modeIM
        case .crutch: return AppColor.modeCrutch
        case .pace: return AppColor.modePace
        }
    }

    var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .timed: colors = AppColor.focusedTimedGradient
        case .pressure: colors = AppColor.focusedPressureGradient
        case .clarity: colors = AppColor.focusedClarityGradient
        case .conversation: colors = AppColor.focusedConversationGradient
        case .crutch: colors = AppColor.focusedCrutchGradient
        case .pace: colors = AppColor.focusedPaceGradient
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct FocusedPracticeBackground: View {
    let style: FocusedPracticeStyle

    var body: some View {
        ZStack {
            style.gradient
            Circle()
                .fill(Color.white.opacity(0.13))
                .frame(width: 260, height: 260)
                .blur(radius: 34)
                .offset(x: 150, y: -250)
            Circle()
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
                .frame(width: 230, height: 230)
                .offset(x: -140, y: 220)
            AppColor.focusedContrastScrim
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Shared full-screen pre-rep cue. It replaces mode-specific dimmed boxes so
/// setup never remains visibly stacked behind the countdown.
struct FocusedPracticeCountdownOverlay: View {
    let style: FocusedPracticeStyle
    let value: String
    let subtitle: String

    var body: some View {
        ZStack {
            FocusedPracticeBackground(style: style)

            VStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                        .frame(width: 210, height: 210)
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 156, height: 156)
                        .blur(radius: 1)

                    Text(value)
                        .font(Typography.figtreeNumeric(size: 82, weight: .bold, relativeTo: .largeTitle))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }

                Text(subtitle)
                    .font(Typography.headline)
                    .foregroundStyle(AppColor.focusedTextSecondary)
            }
            .padding(.horizontal, Spacing.screenH)
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value). \(subtitle)")
        .accessibilityIdentifier("focusedPractice.countdown")
    }
}

/// A readable, low-noise failure state for dark practice canvases. Generic
/// error cards use neutral-screen colors and lose contrast over gradients.
struct FocusedPracticeErrorStatus: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color(red: 1.0, green: 0.67, blue: 0.62))
                .accessibilityHidden(true)

            Text(message)
                .font(Typography.subheadline)
                .foregroundStyle(.white.opacity(0.94))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct FocusedPracticeScaffold<Accessory: View, Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let style: FocusedPracticeStyle
    let status: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let content: () -> Content

    init(
        style: FocusedPracticeStyle,
        status: String,
        title: String,
        subtitle: String,
        @ViewBuilder accessory: @escaping () -> Accessory,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.status = status
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        ZStack {
            FocusedPracticeBackground(style: style)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    practiceHeader

                    content()
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.focusedActionClearance)
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var practiceHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.md) {
                headerCopy
                accessory()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .center, spacing: Spacing.md) {
                headerCopy
                Spacer(minLength: Spacing.sm)
                accessory()
            }
        }
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(status)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.focusedTextSecondary)
            Text(title)
                .font(Typography.figtree(size: 38, weight: .bold, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(Typography.body)
                .foregroundStyle(AppColor.focusedTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FocusedGlassSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColor.focusedGlassFill, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(AppColor.focusedGlassBorder, lineWidth: 1)
            )
    }
}

extension View {
    func focusedGlassSurface() -> some View {
        modifier(FocusedGlassSurfaceModifier())
    }
}
