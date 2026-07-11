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

struct FocusedPracticeScaffold<Accessory: View, Content: View>: View {
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
                    HStack(alignment: .center, spacing: Spacing.md) {
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

                        Spacer(minLength: Spacing.sm)
                        accessory()
                    }

                    content()
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.focusedActionClearance)
            }
        }
        .preferredColorScheme(.dark)
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
