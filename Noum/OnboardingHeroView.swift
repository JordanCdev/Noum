#if canImport(SwiftUI)
import SwiftUI

// MARK: - Onboarding Hero
//
// Three-screen value-prop intro shown to brand-new users on first launch,
// before the existing `CoachingOnboardingView` questionnaire. Premium
// iOS-product feel: spring-driven hero animations, page indicator dots,
// horizontal swipe, restrained motion budget per screen.
//
// Voice rules followed (no "Let's", no exclamations, no emoji, no chirpy
// phrasing). All copy reads as a trusted speaking coach.

@available(iOS 17.0, *)
struct OnboardingHeroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @StateObject private var manager = OnboardingHeroManager.shared
    @State private var page: Int = 0

    /// Called when the user finishes the hero (Begin or Skip). Lets the
    /// caller dismiss the cover.
    let onFinish: () -> Void

    private static let pageCount = 3

    var body: some View {
        ZStack {
            LightGradientBackground()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, Spacing.sm)

                TabView(selection: $page) {
                    HeroPage(
                        index: 0,
                        title: "Speak with more clarity",
                        subhead: "Real-time coaching on filler words, pacing, structure.",
                        accent: AppColor.brandBlue,
                        reduceMotion: reduceMotion,
                        currentPage: page
                    ) {
                        WaveformPulse(tint: AppColor.brandBlue, reduceMotion: reduceMotion, isActive: page == 0)
                    }
                    .tag(0)

                    HeroPage(
                        index: 1,
                        title: "Become measurably better",
                        subhead: "Track your speaking rating across reps.",
                        accent: AppColor.modeIM,
                        reduceMotion: reduceMotion,
                        currentPage: page
                    ) {
                        RatingRingClimb(tint: AppColor.modeIM, reduceMotion: reduceMotion, isActive: page == 1)
                    }
                    .tag(1)

                    HeroPage(
                        index: 2,
                        title: "Two minutes a day",
                        subhead: "A short daily rep is enough.",
                        accent: AppColor.modeSuddenDeath,
                        reduceMotion: reduceMotion,
                        currentPage: page
                    ) {
                        StreakFlame(tint: AppColor.modeSuddenDeath, reduceMotion: reduceMotion, isActive: page == 2)
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                pageDots
                    .padding(.bottom, Spacing.md)

                PrimaryCTA("Begin", tint: AppColor.brandBlue) {
                    finish()
                }
                .accessibilityIdentifier("onboarding.hero.begin")
                .padding(.horizontal, Spacing.screenH)
                .padding(.bottom, Spacing.lg)
            }
            // Cap inner content width on iPad so the hero doesn't stretch
            // ridiculously on big screens; centered inside the ZStack.
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("onboarding.hero.screen")
        .animation(reduceMotion ? nil : .standardSpring, value: page)
    }

    // MARK: - Top bar (Skip)

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                finish()
            } label: {
                Text("Skip")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("onboarding.hero.skip")
        }
    }

    // MARK: - Page dots

    private var pageDots: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<Self.pageCount, id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(i == page ? AppColor.brandBlue : AppColor.brandBlue.opacity(0.18))
                    .frame(width: i == page ? 22 : 7, height: 7)
                    .animation(reduceMotion ? nil : .snappySpring, value: page)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Finish

    private func finish() {
        manager.markSeen()
        onFinish()
    }
}

// MARK: - Hero page (shared layout)

@available(iOS 17.0, *)
private struct HeroPage<Hero: View>: View {
    let index: Int
    let title: String
    let subhead: String
    let accent: Color
    let reduceMotion: Bool
    let currentPage: Int
    @ViewBuilder var hero: () -> Hero

    @State private var copyAppeared: Bool = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: 0)

            hero()
                .frame(maxWidth: .infinity)
                .frame(height: 220)

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(Typography.screenTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(copyAppeared ? 1 : 0)
                    .offset(y: copyAppeared ? 0 : 12)

                Text(subhead)
                    .font(Typography.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.md)
                    .opacity(copyAppeared ? 1 : 0)
                    .offset(y: copyAppeared ? 0 : 8)
            }
            .padding(.horizontal, Spacing.screenH)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { animateCopyIn() }
        .onChange(of: currentPage) { _, newValue in
            if newValue == index { animateCopyIn() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subhead)")
    }

    private func animateCopyIn() {
        copyAppeared = false
        if reduceMotion {
            copyAppeared = true
            return
        }
        withAnimation(.standardSpring.delay(0.08)) {
            copyAppeared = true
        }
    }
}

// MARK: - Hero 1: Waveform pulse

@available(iOS 17.0, *)
private struct WaveformPulse: View {
    let tint: Color
    let reduceMotion: Bool
    let isActive: Bool

    @State private var phase: CGFloat = 0
    @State private var ringScale: CGFloat = 0.7
    @State private var ringOpacity: Double = 0

    private let bars: Int = 9

    var body: some View {
        ZStack {
            // Soft halo behind the bars
            Circle()
                .fill(tint.opacity(0.10))
                .frame(width: 200, height: 200)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            HStack(alignment: .center, spacing: 8) {
                ForEach(0..<bars, id: \.self) { i in
                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: 8, height: barHeight(for: i))
                        .opacity(0.92)
                }
            }
        }
        .accessibilityHidden(true)
        .onAppear { start() }
        .onChange(of: isActive) { _, active in
            if active { start() }
        }
    }

    private func barHeight(for i: Int) -> CGFloat {
        let mid: CGFloat = 64
        let amplitude: CGFloat = 36
        // Per-bar phase offset gives the live-mic shimmer.
        let offset = CGFloat(i) * 0.55
        let raw = sin(phase + offset)
        // Edge bars taper for a more organic envelope.
        let envelope = sin(CGFloat(i) / CGFloat(bars - 1) * .pi)
        return mid + amplitude * raw * (0.4 + 0.6 * envelope)
    }

    private func start() {
        ringScale = 0.7
        ringOpacity = 0
        phase = 0
        if reduceMotion {
            // Static-but-shaped: show the bars in a calm, fixed envelope.
            phase = 0.5
            ringScale = 1.0
            ringOpacity = 1.0
            return
        }
        withAnimation(.bouncySpring) {
            ringScale = 1.0
            ringOpacity = 1.0
        }
        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
            phase = .pi * 2
        }
    }
}

// MARK: - Hero 2: Rating ring climb 200 → 600

@available(iOS 17.0, *)
private struct RatingRingClimb: View {
    let tint: Color
    let reduceMotion: Bool
    let isActive: Bool

    @State private var rating: Int = 200
    @State private var progress: CGFloat = 200.0 / 1000.0

    private let target: Int = 600
    private let start: Int = 200

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.14), lineWidth: 12)
                .frame(width: 180, height: 180)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 180, height: 180)

            VStack(spacing: 2) {
                Text("\(rating)")
                    .font(Typography.bigStat.monospacedDigit())
                    .foregroundStyle(AppColor.textPrimary)
                Text("Rating")
                    .microLabel(AppColor.textSecondary)
            }
        }
        .accessibilityHidden(true)
        .onAppear { start(animated: true) }
        .onChange(of: isActive) { _, active in
            if active { start(animated: true) }
        }
    }

    private func start(animated: Bool) {
        // Reset
        rating = start
        progress = CGFloat(start) / 1000.0

        if reduceMotion || !animated {
            rating = target
            progress = CGFloat(target) / 1000.0
            return
        }

        // Ring fill — smooth ease-out lasting ~1.2s.
        withAnimation(.easeOut(duration: 1.2)) {
            progress = CGFloat(target) / 1000.0
        }

        // Number count-up: tick rating from 200 → 600 over ~1.0s.
        let totalSteps: Int = 40
        let stepDuration: Double = 1.0 / Double(totalSteps)
        let span = target - start
        for step in 1...totalSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                let t = Double(step) / Double(totalSteps)
                // Ease-out so the digits settle naturally.
                let eased = 1 - pow(1 - t, 2)
                rating = start + Int((Double(span) * eased).rounded())
            }
        }
    }
}

// MARK: - Hero 3: Streak flame

@available(iOS 17.0, *)
private struct StreakFlame: View {
    let tint: Color
    let reduceMotion: Bool
    let isActive: Bool

    @State private var pulse: Bool = false
    @State private var scaleIn: CGFloat = 0.6
    @State private var glow: Double = 0

    var body: some View {
        ZStack {
            // Outer breathing glow
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 180, height: 180)
                .scaleEffect(pulse ? 1.06 : 0.94)
                .opacity(glow)
                .blur(radius: 8)

            // Inner soft disc
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 130, height: 130)
                .scaleEffect(scaleIn)

            Image(systemName: "flame.fill")
                .font(.system(size: 84, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(scaleIn)

            // Tiny "2 min" badge anchored bottom-right
            Text("2 min")
                .font(Typography.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 6)
                .background(tint, in: Capsule(style: .continuous))
                .offset(x: 60, y: 60)
                .opacity(scaleIn > 0.85 ? 1 : 0)
        }
        .accessibilityHidden(true)
        .onAppear { start() }
        .onChange(of: isActive) { _, active in
            if active { start() }
        }
    }

    private func start() {
        scaleIn = 0.6
        glow = 0
        pulse = false

        if reduceMotion {
            scaleIn = 1.0
            glow = 1.0
            return
        }

        withAnimation(.bouncySpring) {
            scaleIn = 1.0
        }
        withAnimation(.easeIn(duration: 0.5)) {
            glow = 1.0
        }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 17.0, *)
struct OnboardingHeroView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingHeroView(onFinish: {})
    }
}
#endif
#endif
