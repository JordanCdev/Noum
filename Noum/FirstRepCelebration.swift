#if canImport(SwiftUI)
import SwiftUI

// MARK: - First Rep Celebration
//
// Full-screen ceremony fired exactly once after the user completes their
// very first session. The point: turn the otherwise-flat "you finished a
// rep" into a *moment* — Duolingo opens with one, every breakout learning
// app does.
//
// Three beats, ~5 seconds total:
//  1. Pulse + "Your baseline is set" text (1.0s)
//  2. Three stat tiles animate in — score / fillers / pace (1.6s)
//  3. CTA + confetti reveal (final 2.4s)
//
// Driven by `FirstRepCelebrationManager.shared` so the SummaryView doesn't
// have to know whether this is the user's first or hundredth rep.

@available(iOS 17.0, macOS 12.0, *)
struct FirstRepCelebration: View {
    let session: PracticeSession
    let onContinue: () -> Void

    @State private var phase: Phase = .reveal
    @State private var confettiActive = false
    @State private var pulseScale: CGFloat = 0.8
    @State private var showShareSheet = false

    enum Phase: Int, Comparable {
        case reveal, statsIn, ctaIn

        static func < (lhs: Phase, rhs: Phase) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    var body: some View {
        ZStack {
            // Layered backdrop — depth comes from three stacked elements
            // instead of a single flat gradient. Old version read as
            // generic-blue-corporate; this gives the screen the
            // "premium speaking coach" feel called out in the brand spec.
            backdropLayers
                .ignoresSafeArea()

            // Slow-drifting orbs add motion without being noisy. Brand
            // rule respected — no illustration, just shape + blur + opacity.
            FloatingOrbsLayer()
                .ignoresSafeArea()

            ConfettiLayer(active: confettiActive, pieceCount: 36, duration: 2.0)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 48)
                pulseBadge
                SparkleRibbon(tint: .white)
                    .opacity(phase >= .reveal ? 1 : 0)
                headerCopy
                statsGrid
                Spacer(minLength: 0)
                if phase >= .ctaIn {
                    VStack(spacing: 12) {
                        continueButton
                        shareButton
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                Spacer(minLength: 24)
            }
            .padding(.horizontal, Spacing.screenH)
        }
        .onAppear { runSequence() }
        .accessibilityIdentifier("firstRep.celebration")
        .sheet(isPresented: $showShareSheet) {
            FirstRepShareSheet(session: session)
        }
    }

    /// Three stacked layers that produce a richer celebration backdrop:
    ///   1. Deep blue base — anchors the brand identity.
    ///   2. Radial highlight at top-leading — lifts the character into
    ///      the frame instead of pinning it to flat colour.
    ///   3. Subtle vignette at the bottom — pulls focus back to the CTA.
    private var backdropLayers: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.32, blue: 0.85),  // deep brand
                    AppColor.brandBlue,
                    AppColor.brandBlueLight.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.0)
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 380
            )
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.18)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Subviews

    private var pulseBadge: some View {
        // The first finished rep is the highest-emotion moment in the
        // app, so the coach character lands on the .excited state. Three
        // concentric rings + a white inner halo give it more presence
        // than the single-ring v1 — visual weight matches emotional weight.
        ZStack {
            // Outermost slow-pulse ring — drifts through the breath cycle.
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 1.5)
                .frame(width: 220, height: 220)
                .scaleEffect(pulseScale * 1.04)
                .opacity(1.6 - pulseScale)
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 2)
                .frame(width: 175, height: 175)
                .scaleEffect(pulseScale)
                .opacity(2 - pulseScale)
            // Inner soft halo so the character lifts off the backdrop.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 90
                    )
                )
                .frame(width: 160, height: 160)
            NoumCharacter(mood: .excited, tint: .white, size: 116)
        }
    }

    private var headerCopy: some View {
        VStack(spacing: 10) {
            // Eyebrow micro-label adds editorial weight without forcing
            // the headline larger than it needs to be.
            Text("FIRST REP COMPLETE")
                .font(Typography.micro)
                .tracking(2.0)
                .foregroundStyle(Color.white.opacity(0.66))
            Text("Your baseline is set")
                .font(Typography.hero)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: Color.black.opacity(0.18), radius: 8, y: 2)
            Text("This is the line every future rep is measured against.")
                .font(Typography.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
        }
        .opacity(phase >= .reveal ? 1 : 0)
        .offset(y: phase >= .reveal ? 0 : 12)
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statTile(
                value: scoreText,
                label: "Score",
                tint: .white
            )
            .modifier(StatTileEntrance(delay: 0.10, active: phase >= .statsIn))
            statTile(
                value: fillerText,
                label: "Fillers",
                tint: .white
            )
            .modifier(StatTileEntrance(delay: 0.22, active: phase >= .statsIn))
            statTile(
                value: paceText,
                label: "Pace",
                tint: .white
            )
            .modifier(StatTileEntrance(delay: 0.34, active: phase >= .statsIn))
        }
    }

    private func statTile(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(Typography.bigStat.monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(tint.opacity(0.78))
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            HStack(spacing: 8) {
                Text("See your full read")
                    .font(Typography.headline)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(AppColor.brandBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white, in: Capsule())
            .shadow(color: Color.black.opacity(0.18), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("firstRep.celebration.continue")
    }

    /// Secondary CTA. The first rep is the highest-leverage moment to ask
    /// for a share — the user just had a magical experience and they're
    /// curious. Lower visual weight than the primary continue button so
    /// it doesn't compete.
    private var shareButton: some View {
        Button {
            CoachHaptic.selectionTap()
            showShareSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
                Text("Share your starting line")
                    .font(Typography.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.16), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("firstRep.celebration.share")
    }

    // MARK: - Sequence

    private func runSequence() {
        CoachHaptic.trendBreakthrough()
        withAnimation(.easeOut(duration: 1.2).repeatCount(3, autoreverses: true)) {
            pulseScale = 1.18
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.standardSpring) { phase = .statsIn }
            confettiActive = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.bouncySpring) { phase = .ctaIn }
            CoachHaptic.trendBreakthrough()
        }
    }

    // MARK: - Stat formatters

    private var scoreText: String {
        guard let score = session.score else { return "—" }
        return "\(score)/10"
    }

    private var fillerText: String {
        "\(session.fillerWordCount)"
    }

    private var paceText: String {
        let words = session.wordCount
        guard session.duration >= 1, words > 0 else { return "—" }
        let wpm = Double(words) / (session.duration / 60.0)
        return "\(Int(wpm.rounded())) WPM"
    }
}

// MARK: - Floating orbs backdrop (M14 polish)

/// Three slow-drifting blurred circles that add depth to celebration
/// surfaces without violating the no-illustration brand rule. Reduce-Motion
/// turns them static; otherwise they breathe on a 4–6s cycle. White-on-blue
/// only — sized + positioned so they read as ambient light, not decoration.
@available(iOS 17.0, macOS 12.0, *)
private struct FloatingOrbsLayer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                orb(size: 240, x: w * 0.2, y: h * (0.18 + 0.02 * phase), opacity: 0.18)
                orb(size: 320, x: w * 0.85, y: h * (0.34 - 0.03 * phase), opacity: 0.12)
                orb(size: 200, x: w * 0.7,  y: h * (0.78 + 0.04 * phase), opacity: 0.16)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 5.4).repeatForever(autoreverses: true)
            ) {
                phase = 1
            }
        }
    }

    private func orb(size: CGFloat, x: CGFloat, y: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(Color.white.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: size * 0.35)
            .position(x: x, y: y)
    }
}

// MARK: - Stat tile entrance modifier

@available(iOS 17.0, macOS 12.0, *)
private struct StatTileEntrance: ViewModifier {
    let delay: Double
    let active: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? 1 : 0.85)
            .opacity(active ? 1 : 0)
            .animation(.spring(response: 0.42, dampingFraction: 0.78).delay(delay), value: active)
    }
}

// MARK: - First Rep Share Sheet

/// Wraps the existing `ShareableSessionCard` in a system share sheet.
/// Renders a UIImage at 2× scale and hands it to `UIActivityViewController`
/// for AirDrop / iMessage / Twitter / etc.
@available(iOS 17.0, macOS 12.0, *)
struct FirstRepShareSheet: UIViewControllerRepresentable {
    let session: PracticeSession

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let displayName = AuthManager.shared.currentAccountName ?? "Speaker"
        let rating = RatingStore.shared.rating.overall
        let image = ShareableSessionCard.render(
            session: session,
            displayName: displayName,
            rating: rating
        ) ?? UIImage()
        let caption = "I just took my first rep on Noum — sharper speaking, one rep at a time."
        let controller = UIActivityViewController(
            activityItems: [caption, image],
            applicationActivities: nil
        )
        controller.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .print
        ]
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - First Rep Celebration Manager

/// Tracks whether the user has seen the first-rep celebration. Persisted
/// per account so it never fires twice. Single-instance like the other
/// celebration triggers.
@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class FirstRepCelebrationManager: ObservableObject {
    static let shared = FirstRepCelebrationManager()

    @Published private(set) var pendingSession: PracticeSession?

    private let seenKeyPrefix = "noum.firstRep.seen."

    private init() {}

    /// Should only fire when the session count is exactly 1 AND we haven't
    /// shown the celebration before. Both checks survive a sign-out / sign-in
    /// cycle because the seen flag is keyed per account.
    func consider(session: PracticeSession, totalSessionCount: Int) {
        guard totalSessionCount == 1 else { return }
        guard !hasSeenCelebration else { return }
        pendingSession = session
    }

    func dismiss() {
        markSeen()
        pendingSession = nil
    }

    var hasSeenCelebration: Bool {
        UserDefaults.standard.bool(forKey: seenKey)
    }

    private func markSeen() {
        UserDefaults.standard.set(true, forKey: seenKey)
    }

    private static func currentAccountID() -> String {
        AuthManager.shared.currentAccountID ?? "guest"
    }

    private var seenKey: String {
        seenKeyPrefix + Self.currentAccountID()
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("First rep celebration") {
    FirstRepCelebration(
        session: PracticeSession(
            transcript: "I think the most important thing about leadership is empathy.",
            fillerWordCount: 2,
            duration: 32,
            date: Date(),
            mode: .timed,
            pressureLevel: .standard
        ),
        onContinue: {}
    )
}
#endif

#endif
