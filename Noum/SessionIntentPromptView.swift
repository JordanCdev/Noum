#if canImport(SwiftUI)
import SwiftUI

// MARK: - Session Intent Prompt
//
// "Today's focus?" — the pre-rep question a £130/hr coach asks every
// session. Renders as a `.sheet` over the practice mode's setup phase
// (TimedPracticeView / SuddenDeathPracticeView) and is built to come
// and go in under 2 seconds without blocking the rep.
//
// UX contract:
//   • 1 tap to commit — chip buttons commit immediately, no separate
//     "Save" button. The sheet dismisses the moment the user taps.
//   • Skip is always visible — toolbar "Skip" button drops without
//     setting a pending intent. Swipe-to-dismiss also drops cleanly
//     (the rep finalizes with `intentFocus: nil`).
//   • No fake state — when the user dismisses without selecting, the
//     intent stays nil. The summary cards + coach context omit the
//     "You aimed for this" chip and the "Intent declared" line.
//   • Voice-shaped reason labels — each chip carries a quiet eyebrow
//     ("From your plan" / "Your weakest area" / "Your stated goal")
//     so the user knows why this option is on screen. The generic
//     "Open rep" chip has no eyebrow — it's the always-present
//     escape hatch.
//   • Reduce-motion safe — no entry animations on the chip rows;
//     toggles use opacity, not movement.

@available(iOS 17.0, *)
struct SessionIntentPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let options: [SessionIntent]
    let onSelect: (SessionIntent) -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.screenBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        headerSection
                        chipsSection
                        Spacer(minLength: Spacing.lg)
                    }
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") {
                        onSkip()
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("sessionIntent.prompt.skip")
                }
            }
            .interactiveDismissDisabled(false)
            .accessibilityIdentifier("sessionIntent.prompt.sheet")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Today's focus?")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("Pick one — your coach will reference it after the rep.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Spacing.sm)
    }

    private var chipsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(options) { option in
                chipButton(for: option)
            }
        }
    }

    @ViewBuilder
    private func chipButton(for option: SessionIntent) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect(option)
            dismiss()
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let reason = option.kind.reasonLabel {
                        Text(reason.uppercased())
                            .font(Typography.micro)
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(borderColor(for: option), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sessionIntent.prompt.option.\(option.kind.rawValue)")
        .accessibilityLabel("\(option.label)\(option.kind.reasonLabel.map { ", \($0)" } ?? "")")
    }

    private func borderColor(for option: SessionIntent) -> Color {
        switch option.kind {
        case .planWeek:   return AppColor.brandBlue.opacity(0.25)
        case .trendFocus: return AppColor.caution.opacity(0.25)
        case .voiceGoal:  return AppColor.positive.opacity(0.25)
        case .generic:    return Color.secondary.opacity(0.15)
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Full options") {
    SessionIntentPromptView(
        options: [
            SessionIntent(priority: .moreConcise, label: "Tighten structure", kind: .planWeek),
            SessionIntent(priority: .reduceFillers, label: "Cut fillers", kind: .trendFocus),
            SessionIntent(priority: .calmerDelivery, label: "Stay composed", kind: .voiceGoal),
            SessionIntent(priority: .calmerDelivery, label: "Open rep", kind: .generic)
        ],
        onSelect: { _ in },
        onSkip: { }
    )
}

@available(iOS 17.0, *)
#Preview("Cold start — only generic") {
    SessionIntentPromptView(
        options: [
            SessionIntent(priority: .calmerDelivery, label: "Open rep", kind: .generic)
        ],
        onSelect: { _ in },
        onSkip: { }
    )
}
#endif

#endif
