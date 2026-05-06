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
            // Backdrop — softer than a black overlay; this is a celebration,
            // not a modal alert.
            LinearGradient(
                colors: [
                    AppColor.brandBlue.opacity(0.96),
                    AppColor.brandBlueLight.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ConfettiLayer(active: confettiActive, pieceCount: 36, duration: 2.0)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer(minLength: 60)
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

    // MARK: - Subviews

    private var pulseBadge: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 2)
                .frame(width: 140, height: 140)
                .scaleEffect(pulseScale)
                .opacity(2 - pulseScale)
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 110, height: 110)
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var headerCopy: some View {
        VStack(spacing: 8) {
            Text("Your baseline is set")
                .font(Typography.screenTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("This is the line every future rep is measured against.")
                .font(Typography.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
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
