import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)

/// Compact result screen shown after a mini-drill completes.
/// Designed to take <3 seconds to read. No analysis paralysis.
/// Animation sequence: icon (0s) → title (0.15s) → feedback (0.3s) → streak (0.45s) → XP (0.6s) → stats (0.7s) → buttons (0.8s)
struct MiniDrillResultView: View {
    let outcome: MiniDrillOutcome
    let xpEarned: Int
    let streak: Int                         // Current streak for this skill area
    let onDone: () -> Void
    let onTryAnother: (() -> Void)?

    @State private var phase: Int = 0       // 0=hidden, 1=icon, 2=text, 3=badges, 4=stats, 5=buttons

    private var wpm: Double {
        outcome.duration > 0 ? Double(outcome.wordCount) / outcome.duration * 60 : 0
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Result icon — phase 1
                resultIcon
                    .scaleEffect(phase >= 1 ? 1.0 : 0.3)
                    .opacity(phase >= 1 ? 1 : 0)

                // Title + feedback — phase 2
                VStack(spacing: 12) {
                    Text(DrillCompletionCopy.title(succeeded: outcome.succeeded))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(DrillCompletionCopy.feedbackLine(
                        skillArea: outcome.drill.skillArea,
                        succeeded: outcome.succeeded,
                        fillerCount: outcome.fillerCount,
                        wordCount: outcome.wordCount,
                        duration: outcome.duration,
                        wpm: wpm
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(phase >= 2 ? 1 : 0)
                .offset(y: phase >= 2 ? 0 : 12)

                // Streak badge + XP — phase 3
                VStack(spacing: 12) {
                    if let streakText = DrillCompletionCopy.streakLine(count: streak, skillArea: outcome.drill.skillArea),
                       outcome.succeeded {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                            Text(streakText)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.orange.opacity(0.15), in: Capsule())
                    }

                    if xpEarned > 0 {
                        Text("+\(xpEarned) XP")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(outcome.drill.tint)
                    }
                }
                .scaleEffect(phase >= 3 ? 1.0 : 0.8)
                .opacity(phase >= 3 ? 1 : 0)

                // Quick stats — phase 4
                HStack(spacing: 24) {
                    miniStat(label: "Duration", value: "\(Int(outcome.duration))s")
                    miniStat(label: "Words", value: "\(outcome.wordCount)")
                    miniStat(label: "Fillers", value: "\(outcome.fillerCount)")
                }
                .padding(.top, 4)
                .opacity(phase >= 4 ? 1 : 0)

                Spacer()

                // Action buttons — phase 5
                VStack(spacing: 12) {
                    Button {
                        onDone()
                    } label: {
                        Text("Done")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(outcome.drill.tint, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                    }
                    .buttonStyle(.pressable)

                    if let onTryAnother {
                        Button {
                            onTryAnother()
                        } label: {
                            Text(DrillCompletionCopy.tryAnotherLabel(succeeded: outcome.succeeded))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.bottom, 40)
                .opacity(phase >= 5 ? 1 : 0)
                .offset(y: phase >= 5 ? 0 : 20)
            }
        }
        .onAppear { runEntrance() }
    }

    // MARK: - Animation Sequence

    private func runEntrance() {
        // Phase 1: Icon (0s)
        withAnimation(.bouncySpring) { phase = 1 }

        // Phase 2: Title + feedback (0.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.35)) { phase = 2 }
        }

        // Phase 3: Streak + XP (0.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.achievementPop) { phase = 3 }
            CoachHaptic.xpEarned()
        }

        // Phase 4: Stats (0.7s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.25)) { phase = 4 }
        }

        // Phase 5: Buttons (0.9s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.3)) { phase = 5 }
        }
    }

    // MARK: - Result Icon

    private var resultIcon: some View {
        ZStack {
            Circle()
                .fill(resultTint.opacity(0.15))
                .frame(width: 100, height: 100)
                .scaleEffect(phase >= 1 ? 1.15 : 0.5)

            Circle()
                .stroke(resultTint.opacity(0.25), lineWidth: 2)
                .frame(width: 110, height: 110)
                .scaleEffect(phase >= 1 ? 1.2 : 0.4)

            Image(systemName: outcome.succeeded ? "checkmark.circle.fill" : "arrow.clockwise.circle")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(resultTint)
        }
    }

    // MARK: - Computed Properties

    private var resultTint: Color {
        outcome.succeeded ? AppColor.positive : outcome.drill.tint
    }

    // MARK: - Components

    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

#endif
