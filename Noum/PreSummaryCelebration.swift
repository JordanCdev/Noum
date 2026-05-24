#if canImport(SwiftUI)
import SwiftUI

// MARK: - Pre-Summary Celebration
//
// Full-screen stacked reveal that shows all SkillLevelUpEvents on a
// single screen with staggered card reveals before the summary content
// lands. Each card appears with a slight delay after the previous one,
// and once all cards are visible the view holds for 5 seconds (or until
// tap) before advancing.
//
// Choreography (full-motion):
//   • "LEVELED UP" header fades in first.
//   • Cards reveal one at a time with ~0.4s delay between each.
//   • Bars fill from previousLevel → newLevel shortly after each card
//     lands, with a staggered spring.
//   • Once all cards are visible, a 5-second hold begins. Tap skips.
//
// Reduce-motion:
//   • Springs collapse to simple fades.
//   • Stagger delay shortens.
//   • Hold shortens to 3 seconds.
//
// Zero-event safety: an empty list fires `onFinished` on appear so the
// parent transitions through to the summary in a single frame.

@available(iOS 17.0, *)
struct PreSummaryCelebration: View {
    let events: [SkillLevelUpEvent]
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Per-card visibility — staggered reveal drives each card's
    /// opacity + scale. Indexed by position in `events`.
    @State private var cardVisible: [Bool] = []
    /// Per-card bar fill state — bars advance shortly after each card
    /// appears. Indexed by position in `events`.
    @State private var barsAdvanced: [Bool] = []
    /// Header "LEVELED UP" visibility.
    @State private var headerVisible: Bool = false
    @State private var sequenceTask: Task<Void, Never>?
    @State private var holdContinuation: CheckedContinuation<Void, Never>?

    var body: some View {
        ZStack {
            backdrop
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                Spacer()

                // "LEVELED UP" header — anchors the moment before
                // cards start revealing.
                Text("LEVELED UP")
                    .font(Typography.micro)
                    .foregroundStyle(Color.white.opacity(0.70))
                    .tracking(1.4)
                    .opacity(headerVisible ? 1 : 0)

                // All cards in a vertical stack — each with its own
                // staggered visibility state.
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.md) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            eventCard(event: event, index: index)
                                .opacity(cardOpacity(at: index))
                                .scaleEffect(cardScale(at: index))
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }

                Spacer()

                // Tap hint at bottom — gives the user an escape valve.
                Text("Tap to continue")
                    .font(Typography.caption)
                    .foregroundStyle(Color.white.opacity(allCardsVisible ? 0.45 : 0))
                    .padding(.bottom, Spacing.lg)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { advanceFromTap() }
        .onAppear(perform: start)
        .onDisappear {
            sequenceTask?.cancel()
            sequenceTask = nil
            resumeHoldIfWaiting()
        }
        .accessibilityIdentifier("preSummary.celebration")
        .accessibilityElement(children: .contain)
        .accessibilityHint("Tap to continue")
    }

    // MARK: - Helpers

    private func cardOpacity(at index: Int) -> Double {
        guard index < cardVisible.count else { return 0 }
        return cardVisible[index] ? 1 : 0
    }

    private func cardScale(at index: Int) -> CGFloat {
        guard index < cardVisible.count else { return 0.94 }
        return cardVisible[index] ? 1.0 : 0.94
    }

    private var allCardsVisible: Bool {
        !cardVisible.isEmpty && cardVisible.allSatisfy { $0 }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            Color.black
                .opacity(0.96)

            RadialGradient(
                colors: [
                    AppColor.pro.opacity(0.50),
                    AppColor.pro.opacity(0.24),
                    Color.black.opacity(0.0)
                ],
                center: UnitPoint(x: 0.5, y: 0.38),
                startRadius: 20,
                endRadius: 540
            )
        }
    }

    // MARK: - Event card

    @ViewBuilder
    private func eventCard(event: SkillLevelUpEvent, index: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            cardHeader(event: event)
            cardBars(event: event, index: index)
            Text(event.subline)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    AppColor.brandBlue,
                    AppColor.pro.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(alignment: .topTrailing) {
            SparkleRibbon(tint: .white)
                .padding(.trailing, 14)
                .padding(.top, 14)
                .opacity(0.6)
        }
        .shadow(color: AppColor.pro.opacity(0.4), radius: 22, y: 10)
        .accessibilityLabel("\(event.headline). \(event.subline).")
    }

    private func cardHeader(event: SkillLevelUpEvent) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 48, height: 48)
                Image(systemName: event.skillArea.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(event.skillArea.displayName)
                    .font(Typography.micro)
                    .foregroundStyle(Color.white.opacity(0.70))
                    .tracking(1.0)
                    .textCase(.uppercase)
                Text(event.headline)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// Four bars matching the SkillProgressView treatment (weak →
    /// developing → solid → strong). Fills from previous → new once the
    /// card lands.
    private func cardBars(event: SkillLevelUpEvent, index: Int) -> some View {
        let from = levelInt(event.previousLevel)
        let to = levelInt(event.newLevel)
        let advanced = index < barsAdvanced.count && barsAdvanced[index]
        let displayed = advanced ? to : from
        return HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i < displayed
                          ? Color.white.opacity(0.95)
                          : Color.white.opacity(0.18))
                    .frame(height: 10)
            }
        }
    }

    private func levelInt(_ level: SkillLevel) -> Int {
        switch level {
        case .weak: return 1
        case .developing: return 2
        case .solid: return 3
        case .strong: return 4
        }
    }

    // MARK: - Sequence

    private func start() {
        guard !events.isEmpty else {
            onFinished()
            return
        }

        // Initialize per-card state arrays.
        cardVisible = Array(repeating: false, count: events.count)
        barsAdvanced = Array(repeating: false, count: events.count)

        // Consume all events immediately so a mid-sequence backout
        // doesn't leave them queued for the next session.
        for event in events {
            SkillProgressionStore.shared.consume(event)
        }

        sequenceTask?.cancel()
        sequenceTask = Task { @MainActor in
            // 1. Header fades in.
            let headerDuration: Double = reduceMotion ? 0.15 : 0.30
            withAnimation(.easeOut(duration: headerDuration)) {
                headerVisible = true
            }
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.10 : 0.20))
            if Task.isCancelled { return }

            // 2. Cards reveal one at a time with stagger delay.
            let staggerDelay: Double = reduceMotion ? 0.20 : 0.40
            let barsDelay: Double = reduceMotion ? 0.05 : 0.15
            let cardSpring: Animation = reduceMotion
                ? .easeOut(duration: 0.20)
                : .spring(response: 0.50, dampingFraction: 0.78)
            let barsSpring: Animation = reduceMotion
                ? .easeOut(duration: 0.20)
                : .spring(response: 0.45, dampingFraction: 0.78)

            for index in events.indices {
                if Task.isCancelled { return }

                // Card slides in.
                withAnimation(cardSpring) {
                    cardVisible[index] = true
                }
                CoachHaptic.skillLevelUp()

                // Bars fill shortly after the card lands.
                try? await Task.sleep(for: .seconds(barsDelay))
                if Task.isCancelled { return }
                withAnimation(barsSpring) {
                    barsAdvanced[index] = true
                }

                // Wait before revealing the next card (skip on last).
                if index < events.count - 1 {
                    try? await Task.sleep(for: .seconds(staggerDelay))
                }
            }

            if Task.isCancelled { return }

            // 3. All cards visible — hold for 5 seconds (3s reduce-motion),
            //    tap escapes early.
            let holdSeconds: Double = reduceMotion ? 3.0 : 5.0
            await holdWithTapEscape(seconds: holdSeconds)
            if Task.isCancelled { return }

            onFinished()
        }
    }

    /// Suspend until either the timer elapses or a tap resumes the
    /// stored continuation.
    private func holdWithTapEscape(seconds: Double) async {
        await withCheckedContinuation { continuation in
            holdContinuation = continuation
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(seconds))
                resumeHoldIfWaiting()
            }
        }
    }

    private func resumeHoldIfWaiting() {
        guard let continuation = holdContinuation else { return }
        holdContinuation = nil
        continuation.resume()
    }

    private func advanceFromTap() {
        resumeHoldIfWaiting()
    }

    /// Exposed for tests — the canonical hold duration.
    static func holdDuration(isSingleEvent: Bool, reduceMotion: Bool) -> Double {
        if reduceMotion { return 3.0 }
        return 5.0
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, *)
#Preview("Pre-summary — single level-up") {
    PreSummaryCelebration(
        events: [
            SkillLevelUpEvent(
                skillArea: .fillerReduction,
                previousLevel: .developing,
                newLevel: .solid,
                date: Date()
            )
        ],
        onFinished: {}
    )
}

@available(iOS 17.0, *)
#Preview("Pre-summary — three level-ups") {
    PreSummaryCelebration(
        events: [
            SkillLevelUpEvent(
                skillArea: .conciseSpeaking,
                previousLevel: .weak,
                newLevel: .developing,
                date: Date()
            ),
            SkillLevelUpEvent(
                skillArea: .openingStrength,
                previousLevel: .developing,
                newLevel: .solid,
                date: Date()
            ),
            SkillLevelUpEvent(
                skillArea: .pauseUsage,
                previousLevel: .solid,
                newLevel: .strong,
                date: Date()
            )
        ],
        onFinished: {}
    )
}
#endif

#endif
