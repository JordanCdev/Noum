import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - EmptyStateView
//
// Single source of truth for empty-state surfaces across the app. Each empty
// state is a stack of: large tinted SF Symbol → on-voice headline →
// one-sentence value body → optional one-tap capsule CTA. Voice is restrained
// (no "Let's", no exclamations, no emoji) per the spec in
// `.claude/skills/noum-design/`.
//
// The view does not render its own card chrome; callers can wrap it in a
// `CardView` or place it on the screen background depending on the surface.
// That keeps the same component working in (a) full-screen empty surfaces
// (Session History) and (b) inline-within-a-card empty surfaces (Friends
// section, Friend Leaderboard, Async Speak-offs).

@available(iOS 17.0, macOS 12.0, *)
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    let tint: Color
    let cta: CTA?

    /// Capsule CTA. Provide nil to render the header + body without an action.
    struct CTA {
        let label: String
        let icon: String?
        let action: () -> Void

        init(label: String, icon: String? = nil, action: @escaping () -> Void) {
            self.label = label
            self.icon = icon
            self.action = action
        }
    }

    init(
        symbol: String,
        title: String,
        body: String,
        tint: Color = AppColor.brandBlue,
        cta: CTA? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.message = body
        self.tint = tint
        self.cta = cta
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.10))
                    .frame(width: 76, height: 76)
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .padding(.bottom, Spacing.xxs)

            Text(title)
                .font(Typography.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.sm)

            if let cta {
                Button(action: cta.action) {
                    HStack(spacing: Spacing.xs) {
                        if let icon = cta.icon {
                            Image(systemName: icon)
                                .font(.subheadline.weight(.semibold))
                        }
                        Text(cta.label)
                            .font(Typography.headline)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, 12)
                    .background(tint, in: Capsule(style: .continuous))
                }
                .buttonStyle(.pressable)
                .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .padding(.horizontal, Spacing.md)
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Empty state — with CTA") {
    ZStack {
        AppColor.screenBackground.ignoresSafeArea()
        EmptyStateView(
            symbol: "clock.arrow.circlepath",
            title: "Your progress starts with one rep",
            body: "Complete a short rep to see your first score, pace, and filler count.",
            tint: AppColor.brandBlue,
            cta: EmptyStateView.CTA(label: "Start a rep", icon: "mic.fill", action: {})
        )
        .padding(Spacing.lg)
    }
}

@available(iOS 17.0, *)
#Preview("Empty state — no CTA") {
    ZStack {
        AppColor.screenBackground.ignoresSafeArea()
        EmptyStateView(
            symbol: "person.2.wave.2",
            title: "Find your first speaking partner",
            body: "A speak-off pushes both speakers harder than solo practice.",
            tint: .teal
        )
        .padding(Spacing.lg)
    }
}
#endif

#endif
