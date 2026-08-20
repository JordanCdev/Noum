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
    let xpBreakdown: DrillXPEngine.Breakdown?
    let streak: Int                         // Current streak for this skill area
    /// Optional voice goal — when set and the drill's skill area aligns with
    /// the goal, a small "Closer to your X voice" line surfaces on success.
    /// Silent on fail or misalignment — we never claim progress we didn't earn.
    var styleGoal: SpeakingStyleGoal? = nil
    let onDone: () -> Void
    let onTryAnother: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var phase: Int = 0       // 0=hidden, 1=icon, 2=text, 3=badges, 4=stats, 5=buttons

    private var wpm: Double {
        outcome.duration > 0 ? Double(outcome.wordCount) / outcome.duration * 60 : 0
    }

    private var goalAlignmentLine: String? {
        guard let styleGoal,
              outcome.succeeded,
              styleGoal.aligns(with: outcome.drill.skillArea) else { return nil }
        return "Closer to your \(styleGoal.shortVoiceLabel)."
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
                    Text(DrillCompletionCopy.title(for: outcome))
                        .font(Typography.figtree(size: 26, weight: .bold, relativeTo: .title2))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("miniDrillResult.title")

                    Text(feedbackText)
                        .font(Typography.subheadline)
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
                        VStack(spacing: 4) {
                            Text("+\(xpEarned) XP")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppColor.focusedTextSecondary)
                                .accessibilityIdentifier("miniDrillResult.xp")
                            if let xpBreakdown {
                                Text(xpBreakdown.label)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(AppColor.focusedTextSecondary)
                            }
                        }
                    }

                    if let goalAlignmentLine {
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppColor.focusedTextSecondary)
                            Text(goalAlignmentLine)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(focusedAccent.opacity(0.12), in: Capsule())
                        .accessibilityLabel(goalAlignmentLine)
                    }
                }
                .scaleEffect(phase >= 3 ? 1.0 : 0.8)
                .opacity(phase >= 3 ? 1 : 0)

                // Quick stats — phase 4
                statsRow
                .padding(.top, 4)
                .opacity(phase >= 4 ? 1 : 0)

                Spacer()

                // Action buttons — phase 5. At accessibility sizes the same
                // controls are pinned below a scrollable result body.
                if !dynamicTypeSize.isAccessibilitySize {
                    resultActions(bottomPadding: 40)
                }
            }
            .padding(.top, dynamicTypeSize.isAccessibilitySize ? Spacing.lg : 0)
            .modifier(
                MiniDrillResultAccessibilityScrollModifier(
                    isEnabled: dynamicTypeSize.isAccessibilitySize
                )
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if dynamicTypeSize.isAccessibilitySize {
                    resultActions(bottomPadding: Spacing.sm)
                        .padding(.top, Spacing.sm)
                        .background(Color.black.opacity(0.96))
                }
            }
        }
        .onAppear { runEntrance() }
    }

    private func resultActions(bottomPadding: CGFloat) -> some View {
        VStack(spacing: 12) {
            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(
                        outcome.drill.skillArea.miniDrillActionForeground
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        outcome.drill.skillArea.miniDrillActionFill,
                        in: RoundedRectangle(
                            cornerRadius: CornerRadius.medium,
                            style: .continuous
                        )
                    )
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("miniDrillResult.done")

            if let onTryAnother {
                Button {
                    onTryAnother()
                } label: {
                    Text(DrillCompletionCopy.tryAnotherLabel(succeeded: outcome.succeeded))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, Spacing.screenH)
        .padding(.bottom, bottomPadding)
        .opacity(phase >= 5 ? 1 : 0)
        .offset(y: phase >= 5 ? 0 : 20)
    }

    // MARK: - Animation Sequence

    /// One-shot: onAppear can re-fire on sheet/navigation round-trips and
    /// the 5-phase entrance + drill-complete cue must not replay.
    @State private var hasRunEntrance = false

    private func runEntrance() {
        guard !hasRunEntrance else { return }
        hasRunEntrance = true
        // Phase 1: Icon (0s) — the drill verdict resolves here, so the
        // soft brush lands with the icon pop. The moment's haptic partner is
        // `.deliveredAtDrillVerdict`: it already fired at stop in
        // `MiniDrillView.finishDrill`, on the frame the verdict was computed.
        // Success is the brighter brush; incomplete is duller, never a
        // fail-buzzer.
        NoumMoment.drillResolved(succeeded: outcome.succeeded).land()
        if reduceMotion {
            phase = 5
            CoachHaptic.xpEarned()
            return
        }
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
        outcome.succeeded ? AppColor.positive : focusedAccent
    }

    private var focusedAccent: Color {
        outcome.drill.skillArea.miniDrillFocusedAccent
    }

    private var feedbackText: String {
        switch outcome.drillType {
        case .beatTheBrake:
            if let metrics = outcome.beatTheBrakeMetrics {
                return DrillCompletionCopy.beatTheBrakeFeedback(metrics: metrics, succeeded: outcome.succeeded)
            }
        case .landThePause:
            if let metrics = outcome.landThePauseMetrics {
                return DrillCompletionCopy.landThePauseFeedback(metrics: metrics, succeeded: outcome.succeeded)
            }
        case .prepStack:
            if let metrics = outcome.prepStackMetrics {
                return DrillCompletionCopy.prepStackFeedback(metrics: metrics, succeeded: outcome.succeeded)
            }
        case .frameworkCheck:
            return DrillCompletionCopy.frameworkFeedback(outcome: outcome)
        case .standard:
            break
        }
        return DrillCompletionCopy.feedbackLine(
            skillArea: outcome.drill.skillArea,
            succeeded: outcome.succeeded,
            fillerCount: outcome.fillerCount,
            wordCount: outcome.wordCount,
            duration: outcome.duration,
            wpm: wpm
        )
    }

    // MARK: - Stats Row

    @ViewBuilder
    private var statsRow: some View {
        switch outcome.drillType {
        case .beatTheBrake:
            if let m = outcome.beatTheBrakeMetrics {
                statGroup([
                    ("Pace Control", "\(Int(m.zonePercentage * 100))%"),
                    ("Fillers", "\(m.adjustedFillers)"),
                    ("Rushed", "\(m.rushedBursts)"),
                ])
            }
        case .landThePause:
            if let m = outcome.landThePauseMetrics {
                statGroup([
                    ("Locked", "\(m.checkpointsLocked)/3"),
                    ("Transition Fillers", "\(m.transitionFillers)"),
                    ("Best Combo", "\(m.bestCombo)"),
                ])
            }
        case .prepStack:
            if let m = outcome.prepStackMetrics {
                statGroup([
                    ("PREP", "\(m.stepsCompleted)/4"),
                    ("Fillers", "\(m.fillerCount)"),
                    ("Close", "\(Int(m.closeStrength * 100))%"),
                ])
            }
        case .standard, .frameworkCheck:
            // Framework drills reuse the generic delivery stats; the structural
            // verdict lives in the feedback line, not as a numeric stat.
            statGroup([
                ("Duration", "\(Int(outcome.duration))s"),
                ("Words", "\(outcome.wordCount)"),
                ("Fillers", "\(outcome.fillerCount)"),
            ])
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func statGroup(_ stats: [(label: String, value: String)]) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Spacing.md) {
                ForEach(stats.indices, id: \.self) { index in
                    miniStat(
                        label: stats[index].label,
                        value: stats[index].value
                    )
                }
            }
            .padding(.horizontal, Spacing.screenH)
        } else {
            HStack(spacing: 24) {
                ForEach(stats.indices, id: \.self) { index in
                    miniStat(
                        label: stats[index].label,
                        value: stats[index].value
                    )
                }
            }
        }
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColor.focusedTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(
            maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil
        )
    }
}

private struct MiniDrillResultAccessibilityScrollModifier: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            ScrollView {
                content
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }
}

#endif
