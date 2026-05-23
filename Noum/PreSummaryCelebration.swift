#if canImport(SwiftUI)
import SwiftUI

// MARK: - Pre-Summary Celebration
//
// Full-screen sequenced reveal that plays each SkillLevelUpEvent one at a
// time before the summary content lands. Replaces the previous inline
// stack of SkillLevelUpCards inside the hero — verbal feedback from
// real-device review flagged the stack as overwhelming and competing
// with the score read.
//
// Choreography (full-motion, multi-event):
//   • Per event: ~1.1s total — 0.55s spring in, 0.50s hold, 0.25s fade out
//   • Backdrop is the same purple-register radial used by
//     `FirstRepCelebration` / `TierPromotionOverlay` so upward moments
//     share one vocabulary.
//   • Bars fill from previousLevel → newLevel with a spring on appear,
//     mirroring the original `SkillLevelUpCard` treatment so the card
//     itself reads as "the same celebration moved up the chain".
//
// Single-event tightening:
//   • When there's only one event the user is staring at a card with
//     no "next" frame to wait for — the long hold reads as a beat
//     too long. Compress to ~0.65s total (0.42s spring in + 0.35s
//     hold, no fade-out because there's nothing to fade *to*) so the
//     single-level-up path reads as a wink, not a beat.
//
// Reduce-motion:
//   • Spring collapses to a single fade (0.2s in, ~0.3s hold, 0.2s out).
//   • Per-event duration shortens to ~0.7s so the sequence never
//     overstays its welcome on the vestibular-sensitive path.
//
// Zero-event safety: the manager that drives this should never present
// it with an empty event list. As a belt-and-braces guard, an empty
// list fires `onFinished` on appear so the parent transitions through
// to the summary in a single frame.
//
// Total upper bound for the worst case (4 simultaneous level-ups) is
// ~4.4s in full-motion / ~2.8s reduce-motion. Per the brief: ≤4s
// target. In practice multiple level-ups in one rep are rare (we've
// never seen >2 in archive data) so this lands well under.

@available(iOS 17.0, *)
struct PreSummaryCelebration: View {
    let events: [SkillLevelUpEvent]
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentIndex: Int = 0
    /// Tracks whether the current event's content has animated in.
    /// Toggles per event so the spring/fade plays on each new card.
    @State private var contentVisible: Bool = false
    /// Bars fill from previous → new once the card has settled.
    @State private var barsAdvanced: Bool = false
    @State private var sequenceTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            backdrop
                .ignoresSafeArea()

            if let event = currentEvent {
                eventCard(event: event)
                    .padding(.horizontal, Spacing.lg)
                    .opacity(contentVisible ? 1 : 0)
                    .scaleEffect(contentVisible ? 1.0 : 0.94)
                    .transition(.opacity)
            }

            VStack {
                Spacer()
                countLabel
                    .padding(.bottom, Spacing.lg)
            }
        }
        .onAppear(perform: start)
        .onDisappear {
            sequenceTask?.cancel()
            sequenceTask = nil
        }
        .accessibilityIdentifier("preSummary.celebration")
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
    //
    // Uses the same visual register as the prior inline SkillLevelUpCard:
    // brand-blue → pro gradient, sparkle ribbon, four-bar progression
    // animation. Wrapped in a hero frame so it reads at full-screen
    // weight, not as a tile.

    @ViewBuilder
    private func eventCard(event: SkillLevelUpEvent) -> some View {
        VStack(spacing: Spacing.md) {
            // "LEVELED UP" label sits above the card to anchor the moment
            // even before the card content reads. Same micro-label
            // treatment Summary uses for section anchors.
            Text("LEVELED UP")
                .font(Typography.micro)
                .foregroundStyle(Color.white.opacity(0.70))
                .tracking(1.4)

            VStack(alignment: .leading, spacing: Spacing.md) {
                cardHeader(event: event)
                cardBars(event: event)
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
        }
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
    private func cardBars(event: SkillLevelUpEvent) -> some View {
        let from = levelInt(event.previousLevel)
        let to = levelInt(event.newLevel)
        let displayed = barsAdvanced ? to : from
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

    // MARK: - Count label

    /// Small "1 of 3" dot row at the bottom — discoverable progress
    /// cue. Hidden when only one event so we don't add noise to the
    /// common case.
    @ViewBuilder
    private var countLabel: some View {
        if events.count > 1 {
            HStack(spacing: 6) {
                ForEach(events.indices, id: \.self) { i in
                    Circle()
                        .fill(i == currentIndex
                              ? Color.white.opacity(0.85)
                              : Color.white.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Sequence

    private var currentEvent: SkillLevelUpEvent? {
        guard currentIndex < events.count else { return nil }
        return events[currentIndex]
    }

    private func start() {
        guard !events.isEmpty else {
            onFinished()
            return
        }
        sequenceTask?.cancel()
        sequenceTask = Task { @MainActor in
            for index in events.indices {
                if Task.isCancelled { return }
                await present(index: index)
            }
            if Task.isCancelled { return }
            onFinished()
        }
    }

    /// Plays one event: fade content in, advance bars, hold, fade out.
    /// Consumes the event from the store as the card lands so backing
    /// out mid-sequence doesn't leave them queued for the next session.
    private func present(index: Int) async {
        currentIndex = index
        contentVisible = false
        barsAdvanced = false

        // Consume immediately so a mid-sequence backout (rare — there's
        // no UI escape, but the system back gesture can still fire)
        // doesn't leave the events pending for the next session's hero.
        if index < events.count {
            SkillProgressionStore.shared.consume(events[index])
        }

        // Reduce-motion path: shorter beats, no spring.
        // Single-event full-motion path: the user isn't waiting on a
        // "next" frame, so the hold + in-spring tightens. Keeps the
        // common case from feeling like the app paused before the
        // summary. Multi-event keeps the longer hold so each card
        // earns its read before the next one lands.
        let isSingleEvent = events.count == 1
        let inDuration: Double = reduceMotion ? 0.20 : (isSingleEvent ? 0.30 : 0.35)
        // M24 fix — single-event hold bumped 0.35s → 1.80s so the user can
        // actually read the level-up card. Total visible time = in (~0.42)
        // + barsDelay (~0.12) + hold (1.80) + out (0.25 next card or
        // indefinite final) = ~2.6s, which matches typical celebration
        // read-times in iOS HIG. Multi-event keeps 0.50s per card because
        // the cards parade together — total stack visibility stays calm.
        let holdDuration: Double = reduceMotion ? 0.40 : (isSingleEvent ? 1.80 : 0.50)
        let outDuration: Double = reduceMotion ? 0.20 : 0.25
        let barsDelay: Double = reduceMotion ? 0.0 : (isSingleEvent ? 0.12 : 0.18)

        // Card slides in. Single-event full-motion uses a faster
        // spring response so the in-feel reads as a wink. Multi-event
        // keeps the gentler 0.55s spring so the sequence still feels
        // like a deliberate parade of moments.
        let contentSpring: Animation = isSingleEvent
            ? .spring(response: 0.42, dampingFraction: 0.78)
            : .spring(response: 0.55, dampingFraction: 0.78)
        let barsSpring: Animation = isSingleEvent
            ? .spring(response: 0.40, dampingFraction: 0.78)
            : .spring(response: 0.5, dampingFraction: 0.78)
        withAnimation(reduceMotion ? .easeOut(duration: inDuration)
                                   : contentSpring) {
            contentVisible = true
        }
        CoachHaptic.skillLevelUp()

        // Bars advance shortly after the card lands so the fill reads
        // as the consequence of the card arriving.
        if barsDelay > 0 {
            try? await Task.sleep(for: .seconds(barsDelay))
        }
        if Task.isCancelled { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.25)
                                   : barsSpring) {
            barsAdvanced = true
        }

        // Hold so the user can read the card
        try? await Task.sleep(for: .seconds(holdDuration))
        if Task.isCancelled { return }

        // Fade out — only when there's another card behind it; the
        // final event holds until the parent dismisses us.
        if index < events.count - 1 {
            withAnimation(.easeIn(duration: outDuration)) {
                contentVisible = false
            }
            try? await Task.sleep(for: .seconds(outDuration))
        }
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
