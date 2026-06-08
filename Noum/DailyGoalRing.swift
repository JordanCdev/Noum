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

/// Lightweight celebration overlay rendered when the daily goal flips from
/// "not yet" to "done". Honors reduce-motion.
@available(iOS 17.0, macOS 12.0, *)
struct DailyGoalCelebration: View {
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(AppColor.positive.opacity(0.18))
                        .frame(width: 96, height: 96)
                        .scaleEffect(appeared ? 1.15 : 0.5)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(AppColor.positive)
                        .scaleEffect(appeared ? 1.0 : 0.4)
                }

                Text("Today's done")
                    .font(Typography.bigStat)
                    .foregroundStyle(.white)

                Text("That's the rep. Streak intact, no break needed.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColor.positive)
                        .padding(.horizontal, 32)
                        .padding(.vertical, Spacing.sm)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.pressable)
                .padding(.top, 8)
            }
            .padding(24)
            .padding(.horizontal, Spacing.lg)
            .scaleEffect(appeared ? 1.0 : 0.7)
            .opacity(appeared ? 1.0 : 0)
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.bouncySpring) {
                    appeared = true
                }
            }
        }
    }

    private func dismiss() {
        if reduceMotion {
            onDismiss()
        } else {
            withAnimation(.easeOut(duration: 0.25)) { appeared = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
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
