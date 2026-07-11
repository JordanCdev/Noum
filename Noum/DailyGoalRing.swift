#if canImport(SwiftUI)
import SwiftUI

// MARK: - Daily Goal Ring

/// Compact home-screen card showing today's rep progress against the goal.
/// Renders as a card with a small circular progress ring and a status line.
@available(iOS 17.0, macOS 12.0, *)
struct DailyGoalCard: View {
    @ObservedObject var manager: DailyGoalManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ringSize: CGFloat = 52
    private let ringStroke: CGFloat = 6

    var body: some View {
        HStack(spacing: Spacing.md) {
            ring
                .frame(width: ringSize, height: ringSize)

            VStack(alignment: .leading, spacing: 4) {
                Text("Today's goal")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text(manager.statusLabel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)

                Text(secondaryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's goal: \(manager.repsToday) of \(manager.goalReps) reps")
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(AppColor.brandBlue.opacity(0.12), lineWidth: ringStroke)

            Circle()
                .trim(from: 0, to: manager.progress)
                .stroke(
                    progressGradient,
                    style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .standardSpring, value: manager.progress)

            Group {
                if manager.hasReachedGoal {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(AppColor.positive)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("\(manager.repsToday)")
                        .font(Typography.figtreeNumeric(size: 18, weight: .bold, relativeTo: .headline))
                        .foregroundStyle(AppColor.brandBlue)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .standardSpring, value: manager.repsToday)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: manager.hasReachedGoal
                ? [AppColor.positive, AppColor.positive.opacity(0.7)]
                : [AppColor.brandBlue, AppColor.brandBlueLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var strokeColor: Color {
        manager.hasReachedGoal
            ? AppColor.positive.opacity(0.20)
            : Color.white.opacity(0.72)
    }

    private var secondaryLabel: String {
        if manager.hasReachedGoal {
            return "Come back tomorrow to keep the rhythm."
        }
        let remaining = max(0, manager.goalReps - manager.repsToday)
        if remaining == manager.goalReps {
            return "One rep is enough to count today."
        }
        return "\(remaining) more rep\(remaining == 1 ? "" : "s") to land it."
    }
}

// MARK: - Goal Hit Celebration

/// Non-blocking receipt rendered after the rep that crosses today's target.
/// It never appears from hydration and never asks the user to dismiss a modal.
@available(iOS 17.0, macOS 12.0, *)
struct DailyGoalCelebration: View {
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "flame.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColor.positive)
                    .frame(width: 38, height: 38)
                    .background(AppColor.positive.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily rhythm held")
                        .font(Typography.cardLabel)
                        .foregroundStyle(.primary)
                    Text("Today's practice is logged.")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(.regularMaterial, in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.65), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.sm)
            .offset(y: appeared ? 0 : -18)
            .opacity(appeared ? 1.0 : 0)

            Spacer()
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily rhythm held. Today's practice is logged.")
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.bouncySpring) {
                    appeared = true
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.6))
                dismiss()
            }
        }
    }

    private func dismiss() {
        if reduceMotion {
            onDismiss()
        } else {
            withAnimation(.easeOut(duration: 0.2)) { appeared = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onDismiss() }
        }
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, *)
#Preview("Daily Goal Card — empty") {
    let m = DailyGoalManager.shared
    return DailyGoalCard(manager: m)
        .padding()
        .background(AppColor.screenBackground)
}
#endif

#endif
