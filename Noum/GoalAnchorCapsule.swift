import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Goal Anchor Capsule
//
// Subtle pre-rep anchor that surfaces the user's chosen voice goal in the
// moments before they start speaking. This closes the "Goal capture is
// still a write-once event" gap flagged in docs/VISION.md — the goal now
// shapes what the user sees in the live UI, not just post-session copy.
//
// Design:
// - Capsule, low-saturation tint, single-line copy.
// - Reads `CoachingProfileStore.shared.profile?.speakingStyleGoal` by default;
//   accepts an explicit goal for previews / tests.
// - Hides itself entirely when no profile is set (anonymous first session)
//   — never invents a default goal.
// - Voice: anchor not nag. "Aim: warm voice" — no exclamations, no "Let's".
// - Reduce-motion respected on appearance animation.
//
// Wired into the pre-rep moment of TimedPracticeView, SuddenDeathPracticeView,
// and AhCounterView so every mode reminds the user of their voice goal at the
// instant the goal can still shape delivery.

@available(iOS 17.0, macOS 12.0, *)
struct GoalAnchorCapsule: View {

    /// Visual treatment. `.onDark` is the high-contrast white-on-translucent
    /// variant used over saturated practice backgrounds (Sudden Death warm
    /// gradient, Ah Counter mode tint). `.onLight` is the soft cardlike
    /// variant for light surfaces (Timed thinking phase has its own dark
    /// gradient so it also uses `.onDark`).
    enum Style {
        case onDark
        case onLight
    }

    let goal: SpeakingStyleGoal?
    var style: Style = .onLight

    var body: some View {
        if let goal {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.caption2.weight(.bold))
                Text(Self.anchorText(for: goal))
                    .font(Typography.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background)
            .overlay(border)
            .foregroundStyle(foreground)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Goal anchor: \(Self.accessibilityText(for: goal))")
        }
    }

    /// Convenience initializer that reads from the shared coaching profile
    /// store, hiding the capsule when no goal is captured.
    init(style: Style = .onLight) {
        self.goal = CoachingProfileStore.shared.profile?.speakingStyleGoal
        self.style = style
    }

    /// Explicit initializer for previews / tests.
    init(goal: SpeakingStyleGoal?, style: Style = .onLight) {
        self.goal = goal
        self.style = style
    }

    // MARK: - Style

    @ViewBuilder
    private var background: some View {
        switch style {
        case .onDark:
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.14))
        case .onLight:
            Capsule(style: .continuous)
                .fill(AppColor.brandBlue.opacity(0.08))
        }
    }

    @ViewBuilder
    private var border: some View {
        switch style {
        case .onDark:
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.75)
        case .onLight:
            Capsule(style: .continuous)
                .stroke(AppColor.brandBlue.opacity(0.22), lineWidth: 0.75)
        }
    }

    private var foreground: Color {
        switch style {
        case .onDark: return .white.opacity(0.92)
        case .onLight: return AppColor.brandBlue
        }
    }

    // MARK: - Copy

    /// Inline copy for the anchor. Pure function — testable.
    /// "Aim: <voice label>" pattern stays consistent across all six goals
    /// so users learn to recognise the anchor at a glance.
    static func anchorText(for goal: SpeakingStyleGoal) -> String {
        "Aim: \(goal.shortVoiceLabel)"
    }

    /// Accessibility version reads the same thing in a slightly more
    /// natural sentence — VoiceOver users get the same anchor.
    static func accessibilityText(for goal: SpeakingStyleGoal) -> String {
        "aim for your \(goal.shortVoiceLabel)"
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Goal Anchor — light") {
    VStack(spacing: 16) {
        ForEach(SpeakingStyleGoal.allCases) { goal in
            GoalAnchorCapsule(goal: goal, style: .onLight)
        }
        GoalAnchorCapsule(goal: nil, style: .onLight)
    }
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("Goal Anchor — dark") {
    VStack(spacing: 16) {
        ForEach(SpeakingStyleGoal.allCases) { goal in
            GoalAnchorCapsule(goal: goal, style: .onDark)
        }
    }
    .padding()
    .background(Color.black)
}
#endif

#endif
