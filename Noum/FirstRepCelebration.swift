#if canImport(SwiftUI)
import SwiftUI

// MARK: - First Rep Celebration
//
// Full-screen reveal fired exactly once after the user completes their
// very first rep. Tuned to read as a single resonant frame — a coach
// acknowledging a milestone — not an information panel.
//
// The composition is deliberately spare:
//   • Tinted radial backdrop in `AppColor.pro` (purple premium register,
//     same vocabulary as `TierPromotionOverlay` for upward moments).
//   • Slow-drifting orbs for depth (no illustration, brand rule).
//   • Large `NoumCharacter` at `.excited` (150–180pt) — the coach
//     character, sparkle ribbon, the only "face" of the moment.
//   • A single bold display headline.
//   • A two-line concrete subtitle that names what the user just did
//     (duration + filler count) — coach evidence, not vanity stats.
//   • One primary "Continue" CTA tinted in `AppColor.pro`.
//   • Optional "Share" secondary (kept — `ImageRenderer` is wired).
//
// Beats (full-motion):
//   1. Backdrop + orbs fade in (0.4s).
//   2. Character springs from 0.8 → 1.0 (0.6s).
//      One short confetti burst at entrance (~1.5s).
//   3. Headline slides up + fades in.
//   4. Subtitle fades in (200ms after the headline).
//   5. CTA + share fade in last.
//
// Reduce-Motion:
//   All springs collapse to a single fade-in. Confetti burst skipped
//   entirely. Orbs render static. Sparkle ribbon stays — it's a
//   non-vestibular per-symbol opacity twinkle, not a moving layer.
//
// Driven by `FirstRepCelebrationManager.shared` so the caller doesn't
// need to know whether this is the user's first or hundredth rep.

@available(iOS 17.0, macOS 12.0, *)
struct FirstRepCelebration: View {
    let session: PracticeSession
    let onContinue: () -> Void

    @State private var phase: Phase = .preReveal
    @State private var confettiActive = false
    @State private var showShareSheet = false
    @State private var proofMoment: ProofMoment?
    @State private var characterMood: NoumCharacter.Mood = .excited
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Animation phases. Drives both the spring sequence (full-motion) and
    /// the flat-fade resolution (reduce-motion). Each phase is a single
    /// step forward — phases never reverse.
    enum Phase: Int, Comparable {
        case preReveal   // Nothing visible yet
        case backdropIn  // Radial + orbs fading in
        case characterIn // NoumCharacter scaled in, confetti firing
        case headlineIn  // Headline slid + faded in
        case subtitleIn  // Subtitle faded in
        case ctaIn       // Continue + Share faded in

        static func < (lhs: Phase, rhs: Phase) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    var body: some View {
        ZStack {
            backdrop
                .ignoresSafeArea()

            FloatingOrbsLayer(tint: AppColor.proLight)
                .opacity(phase >= .backdropIn ? 1 : 0)
                .ignoresSafeArea()

            // One short burst, then quiet. ConfettiLayer is reduce-motion
            // aware on its own — returns EmptyView when reduce-motion is
            // enabled — so the gate here is just so we don't allocate the
            // pieces on the inert path.
            if !reduceMotion {
                ConfettiLayer(active: confettiActive, pieceCount: 20, duration: 1.5)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: Spacing.lg) {
                Spacer(minLength: 0)

                headline
                    .padding(.horizontal, Spacing.lg)

                character
                    .padding(.vertical, Spacing.xs)

                subtitle
                    .padding(.horizontal, Spacing.lg)

                Spacer(minLength: 0)

                VStack(spacing: Spacing.sm) {
                    continueButton
                    shareButton
                }
                .opacity(phase >= .ctaIn ? 1 : 0)
                .offset(y: phase >= .ctaIn ? 0 : 8)
                .padding(.horizontal, Spacing.screenH)
                .padding(.bottom, Spacing.lg)
            }
        }
        .onAppear { runSequence() }
        .task { await loadProof() }
        .accessibilityIdentifier("firstRep.celebration")
        .sheet(isPresented: $showShareSheet) {
            FirstRepShareSheet(session: session)
        }
    }

    // MARK: - Backdrop

    /// Tinted radial in `AppColor.pro` — same purple premium register as
    /// `TierPromotionOverlay`. Anchored top so the character sits in the
    /// brighter band; black floor at the bottom focuses the CTA.
    private var backdrop: some View {
        ZStack {
            // Base black so the radial reads on every device + dark-mode
            // root. Black floor is the calming counterweight to the
            // purple bloom up top.
            Color.black
                .opacity(0.96)

            RadialGradient(
                colors: [
                    AppColor.pro.opacity(0.55),
                    AppColor.pro.opacity(0.28),
                    Color.black.opacity(0.0)
                ],
                center: UnitPoint(x: 0.5, y: 0.32),
                startRadius: 20,
                endRadius: 620
            )

            // Subtle bottom vignette so the CTA gets focus.
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.35)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .opacity(phase >= .backdropIn ? 1 : 0)
    }

    // MARK: - Character

    /// Large `NoumCharacter` at `.excited` — the only "face" of the
    /// celebration. Briefly flashes to `.noticing` when the quote-anchored
    /// proof lands, so the user sees the orb register the moment.
    private var character: some View {
        NoumCharacter(
            mood: characterMood,
            tint: .white,
            size: 160
        )
        .scaleEffect(phase >= .characterIn ? 1.0 : 0.8)
        .opacity(phase >= .characterIn ? 1.0 : 0.0)
    }

    // MARK: - Headline + subtitle

    private var headline: some View {
        Text(headlineCopy)
            .font(Typography.hero)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: Color.black.opacity(0.25), radius: 12, y: 4)
            .opacity(phase >= .headlineIn ? 1 : 0)
            .offset(y: phase >= .headlineIn ? 0 : 12)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var subtitle: some View {
        if let proof = proofMoment {
            proofCard(proof)
                .opacity(phase >= .subtitleIn ? 1 : 0)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            Text(subtitleCopy)
                .font(Typography.subheadline)
                .foregroundStyle(.white.opacity(0.86))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(phase >= .subtitleIn ? 1 : 0)
                .accessibilityElement(children: .combine)
        }
    }

    /// Quote-anchored coach observation. The first thing a brand-new user
    /// sees after rep 1: their own words, named technique, voice-shaped
    /// claim — not a stats line. This is the "Noum heard me" moment.
    private func proofCard(_ proof: ProofMoment) -> some View {
        VStack(spacing: Spacing.sm) {
            Text("\u{201C}\(proof.quote)\u{201D}")
                .font(.system(.title3, design: .serif).italic())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.xs) {
                Image(systemName: "waveform.path.badge.plus")
                    .font(.caption.weight(.bold))
                Text(proof.technique)
                    .font(Typography.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
            .foregroundStyle(.white.opacity(0.78))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color.white.opacity(0.10))
            )

            Text(proof.claim)
                .font(Typography.subheadline)
                .foregroundStyle(.white.opacity(0.86))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You said \(proof.quote). \(proof.technique). \(proof.claim)")
    }

    // MARK: - CTAs

    private var continueButton: some View {
        Button(action: onContinue) {
            HStack(spacing: Spacing.xs) {
                Text("Continue")
                    .font(Typography.headline)
                Image(systemName: "arrow.right")
                    .font(Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                AppColor.pro.gradient,
                in: Capsule(style: .continuous)
            )
            .shadow(color: AppColor.pro.opacity(0.45), radius: 18, y: 8)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("firstRep.celebration.continue")
    }

    /// Lower-weight secondary. The first rep is the highest-leverage
    /// moment to ask for a share — kept under the primary so it doesn't
    /// compete.
    private var shareButton: some View {
        Button {
            CoachHaptic.selectionTap()
            showShareSheet = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "square.and.arrow.up")
                    .font(Typography.caption.weight(.bold))
                Text("Share your starting line")
                    .font(Typography.caption.weight(.bold))
            }
            .foregroundStyle(.white.opacity(0.78))
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("firstRep.celebration.share")
    }

    // MARK: - Sequence

    /// Drives the entrance choreography. Reduce-motion users get a single
    /// fade-in that resolves all phases instantly (no spring, no particle
    /// burst). Everything else lays in at the documented cadence.
    private func runSequence() {
        guard !reduceMotion else {
            // Resolve all phases at once with a single short fade.
            withAnimation(.easeOut(duration: 0.4)) {
                phase = .ctaIn
            }
            CoachHaptic.scoreReveal()
            return
        }

        // Beat 1 — Backdrop + orbs (0.0s → 0.4s)
        withAnimation(.easeOut(duration: 0.4)) {
            phase = .backdropIn
        }

        // Beat 2 — Character springs in + confetti burst (0.35s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            CoachHaptic.trendBreakthrough()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                phase = .characterIn
            }
            confettiActive = true
        }

        // Beat 3 — Headline slides up + fades in (0.95s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                phase = .headlineIn
            }
        }

        // Beat 4 — Subtitle fades in 200ms after the headline (1.15s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            withAnimation(.easeOut(duration: 0.35)) {
                phase = .subtitleIn
            }
        }

        // Beat 5 — CTAs fade in last (1.55s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            withAnimation(.easeOut(duration: 0.35)) {
                phase = .ctaIn
            }
            CoachHaptic.scoreReveal()
        }
    }

    // MARK: - Copy

    /// The headline is the single resonant frame of the celebration —
    /// coach voice, in the bag, no chirpiness. No exclamation: the
    /// motion + sparkle carry the celebration; the words stay composed.
    private var headlineCopy: String {
        "First rep, in the bag."
    }

    /// Two-line subtitle naming the specific concrete thing the user
    /// just did. Pulls duration (seconds) + filler count from the
    /// session itself — never the user's prompt or transcript text
    /// (lock-screen-safety rule). Falls through to a strong fallback if
    /// the data is malformed (very short rep, missing duration, etc.).
    private var subtitleCopy: String {
        let seconds = Int(session.duration.rounded())
        let fillers = session.fillerWordCount

        // Defensive: if duration is implausible (zero / negative), drop
        // back to the filler-only line. The first rep is also the most
        // common place an aborted recording sneaks through.
        guard seconds >= 1 else {
            return "Your baseline is set. The read starts now."
        }

        let durationPhrase = "\(seconds) second\(seconds == 1 ? "" : "s")"
        let fillerPhrase: String = {
            switch fillers {
            case 0:  return "zero fillers"
            case 1:  return "1 filler"
            default: return "\(fillers) fillers"
            }
        }()

        return "\(durationPhrase), \(fillerPhrase). The read starts now."
    }

    // MARK: - Proof loading

    /// Fetch a quote-anchored proof for the session. AI path attempts
    /// first; deterministic template is the always-on fallback. Nil
    /// results (transcript too short, no qualifying clause) leave the
    /// generic-stats subtitle in place — the celebration never shows
    /// "loading…" or a half-rendered card.
    private func loadProof() async {
        guard !session.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              session.duration > 8 else { return }

        let baseline = BaselineStore.shared.baseline
        let profile = CoachingProfileStore.shared.profile
        let input = ProofMomentInput(
            session: session,
            voice: profile?.speakingStyleGoal,
            goalParaphrase: profile?.displayableGoal,
            baselineFillerRate: baseline.fillerRate.confidence != .insufficient
                ? baseline.fillerRate.value : nil,
            baselinePace: baseline.pace.confidence != .insufficient
                ? baseline.pace.value : nil
        )
        let proof = await ProofMomentService.shared.proof(for: input)
        guard let proof = proof else { return }
        await MainActor.run {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                proofMoment = proof
            }
            flashNoticingMood()
        }
    }

    /// Briefly flip the character to `.noticing` (the orb's "I just
    /// spotted something" mood) and back to `.excited`. Reduce-motion
    /// users get an instant swap with no flare animation — the
    /// character itself handles that gating.
    private func flashNoticingMood() {
        characterMood = .noticing
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeOut(duration: 0.4)) {
                characterMood = .excited
            }
        }
    }
}

// MARK: - Floating orbs backdrop (purple register)

/// Three slow-drifting blurred circles that add depth to the celebration
/// surface. White-on-purple only — sized so they read as ambient bloom,
/// not decoration. Reduce-Motion turns them static; otherwise they
/// breathe on a 5–6s cycle. No illustration, per the brand rule.
@available(iOS 17.0, macOS 12.0, *)
private struct FloatingOrbsLayer: View {
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                orb(size: 260, x: w * 0.18, y: h * (0.22 + 0.02 * phase), opacity: 0.20)
                orb(size: 340, x: w * 0.86, y: h * (0.34 - 0.03 * phase), opacity: 0.14)
                orb(size: 220, x: w * 0.70, y: h * (0.80 + 0.04 * phase), opacity: 0.18)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 5.6).repeatForever(autoreverses: true)
            ) {
                phase = 1
            }
        }
    }

    private func orb(size: CGFloat, x: CGFloat, y: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(tint.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: size * 0.35)
            .position(x: x, y: y)
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
#Preview("First rep — clean") {
    FirstRepCelebration(
        session: PracticeSession(
            transcript: "I think the most important thing about leadership is empathy.",
            fillerWordCount: 1,
            duration: 32,
            date: Date(),
            mode: .timed,
            pressureLevel: .standard
        ),
        onContinue: {}
    )
}

@available(iOS 17.0, *)
#Preview("First rep — zero fillers") {
    FirstRepCelebration(
        session: PracticeSession(
            transcript: "Clear, calm, and on time.",
            fillerWordCount: 0,
            duration: 45,
            date: Date(),
            mode: .timed,
            pressureLevel: .standard
        ),
        onContinue: {}
    )
}

@available(iOS 17.0, *)
#Preview("First rep — degenerate duration") {
    FirstRepCelebration(
        session: PracticeSession(
            transcript: "",
            fillerWordCount: 0,
            duration: 0,
            date: Date(),
            mode: .timed,
            pressureLevel: .standard
        ),
        onContinue: {}
    )
}
#endif

#endif
