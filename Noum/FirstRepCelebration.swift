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
//     Briefly pulses `.noticing` when the proof-moment lands so the
//     orb itself acknowledges the catch.
//   • A single bold display headline.
//   • The observation slot — a verbatim quote pulled from the user's
//     actual first rep, framed in their voice. The async proof-moment
//     fetch upgrades the line as soon as it lands; the duration+filler
//     summary is the safety net so the screen is never empty.
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
    /// Async-loaded proof moment. Nil while loading or when the rep
    /// can't yield a verbatim slice (we fall through to the duration+
    /// filler safety net in that case). Bumping this triggers the
    /// observation slot fade-in and the `.noticing` orb pulse.
    @State private var proof: ProofMoment?
    /// Bumped once when the proof transitions from nil → non-nil so the
    /// `.noticing` mood pulse fires exactly once, not on every redraw.
    @State private var noticeFlashID: Int = 0
    @State private var loadTask: Task<Void, Never>?
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

                observationSlot
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
        .onAppear {
            runSequence()
            loadProof()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
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
    /// celebration. The mood owns the sparkle ribbon already, so we don't
    /// stack a second one. Springs from 0.8 → 1.0 on entrance. Briefly
    /// pulses `.noticing` once when the proof-moment lands so the orb
    /// itself acknowledges the catch — keyed by `noticeFlashID` so the
    /// pulse fires exactly once on the proof transition, not on every
    /// surrounding redraw.
    @ViewBuilder
    private var character: some View {
        let base = NoumCharacter(mood: .excited, tint: .white, size: 160)
        Group {
            if noticeFlashID > 0 {
                base.moodPulse(.noticing, duration: 1.2)
                    .id(noticeFlashID)
            } else {
                base
            }
        }
        .scaleEffect(phase >= .characterIn ? 1.0 : 0.8)
        .opacity(phase >= .characterIn ? 1.0 : 0.0)
        .accessibilityHidden(true)
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

    /// Observation slot. Renders a verbatim-quote observation as soon
    /// as the proof lands. Until then — or in the (rare) case the proof
    /// fetch yields nothing useful — falls through to the duration+
    /// filler summary so the slot is never empty. Pre-proof and post-
    /// proof live in the same vertical so the layout doesn't reflow when
    /// the proof arrives.
    private var observationSlot: some View {
        Group {
            if let proof = proof, !proof.quote.isEmpty {
                quoteObservation(proof: proof)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            } else {
                Text(subtitleCopy)
                    .font(Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.86))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(phase >= .subtitleIn ? 1 : 0)
        .accessibilityElement(children: .combine)
    }

    /// Voice-shaped, quote-anchored observation. The user's verbatim
    /// slice is rendered in italics on its own line so it reads as
    /// quoted speech rather than coach copy; the voice-shaped frame
    /// follows underneath. Italicised quote, then a one-line claim —
    /// nothing else.
    private func quoteObservation(proof: ProofMoment) -> some View {
        let voice = CoachingProfileStore.shared.profile?.speakingStyleGoal
        return VStack(spacing: Spacing.xs) {
            (Text(Image(systemName: "quote.opening"))
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.55))
             + Text("  ")
             + Text(proof.quote)
                .font(Typography.subheadline.italic())
                .foregroundStyle(.white)
             + Text("  ")
             + Text(Image(systemName: "quote.closing"))
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.55)))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(quoteFraming(proof: proof, voice: voice))
                .font(Typography.subheadline)
                .foregroundStyle(.white.opacity(0.86))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coach observation: \(proof.quote). \(quoteFraming(proof: proof, voice: voice))")
        .accessibilityIdentifier("firstRep.celebration.observation")
    }

    // MARK: - CTAs

    private var continueButton: some View {
        Button(action: onContinue) {
            HStack(spacing: Spacing.xs) {
                // Names the reward waiting underneath instead of a generic
                // "Continue": dismissing this cover reveals the full Summary
                // read (the celebration shows only a one-line observation).
                // Honest to the action — it does not promise a second rep the
                // button doesn't start.
                Text("See the full read")
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

    // MARK: - Proof moment loading

    /// Kicks off the rep-1 proof fetch. Hits `ProofMomentService` (AI
    /// path with deterministic fallback inside the service), then falls
    /// through to a celebration-local extractor if even the service's
    /// fallback returns nil (very short rep, no qualifying clause).
    /// The celebration cannot fail — if every path returns nothing
    /// useful, the slot keeps the duration+filler safety net.
    private func loadProof() {
        guard proof == nil, loadTask == nil else { return }
        loadTask = Task { @MainActor in
            let profile = CoachingProfileStore.shared.profile
            let baseline = BaselineStore.shared.baseline
            let input = ProofMomentInput(
                session: session,
                voice: profile?.speakingStyleGoal,
                goalParaphrase: profile?.displayableGoal,
                baselineFillerRate: baseline.fillerRate.confidence != .insufficient
                    ? baseline.fillerRate.value : nil,
                baselinePace: baseline.pace.confidence != .insufficient
                    ? baseline.pace.value : nil
            )
            // First try the canonical archive-bound service. On rep 1 the
            // session frequently sits at the boundary (≤8s, very short
            // transcript) so this can legitimately return nil.
            let serviceProof = await ProofMomentService.shared.proof(for: input)
            if Task.isCancelled { return }
            let resolved: ProofMoment? = serviceProof ?? Self.celebrationLocalProof(for: session)
            if Task.isCancelled { return }
            guard let resolved = resolved else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) {
                self.proof = resolved
                self.noticeFlashID += 1
            }
            CoachHaptic.selectionTap()
        }
    }

    /// Celebration-only rep-1 minimum-viable proof. Reached only when the
    /// canonical `ProofMomentService` can't produce one (rep too short,
    /// transcript too sparse, no ≥4-word qualifying clause). Extracts
    /// any 4–14 word verbatim slice and pairs it with a neutral
    /// observation. Never persisted to the proof archive — that store
    /// keeps "real" proofs only; celebration-local quotes are surface-
    /// only so Ask Noum never quotes a low-evidence rep 1 weeks later.
    static func celebrationLocalProof(for session: PracticeSession) -> ProofMoment? {
        let transcript = session.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return nil }
        guard let slice = minimumVerbatimSlice(in: transcript) else { return nil }
        return ProofMoment(
            quote: slice,
            technique: "First Read",
            claim: "",
            sessionDate: session.date,
            isAIBacked: false,
            generatedAt: Date()
        )
    }

    /// Pick the first 4–14 word slice from the transcript. Prefers
    /// clauses split on sentence terminators, then comma, then a raw
    /// word window. Returns nil only if the transcript has fewer than
    /// four words.
    static func minimumVerbatimSlice(in transcript: String) -> String? {
        let cleaned = transcript
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\u{2019}", with: "'")
        let firstPass = cleaned
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { wordCount($0) >= 4 })
        if let firstPass, wordCount(firstPass) <= 14 { return firstPass }
        if let firstPass {
            let words = firstPass.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            return words.prefix(12).joined(separator: " ")
        }
        let allWords = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard allWords.count >= 4 else { return nil }
        return allWords.prefix(min(12, allWords.count)).joined(separator: " ")
    }

    static func wordCount(_ s: String) -> Int {
        s.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
    }

    /// Voice-shaped one-line framing for the verbatim quote. The frame
    /// must feel observational, not mocking — rep 1 is weak evidence so
    /// the language stays soft ("a tell, not a habit yet") rather than
    /// declarative ("you have a filler problem"). Mirrors the per-voice
    /// register pattern in `CoachContextBuilder.coachPersonality`.
    ///
    /// Branch logic:
    ///   • If the service returned a real claim (AI path or templated
    ///     fallback), trust it — that copy was already voice-shaped.
    ///   • Otherwise (rep-1 minimum-viable celebration-only path), build
    ///     a soft observation off the filler count: zero fillers reads
    ///     as composure, a small handful as a tell-not-a-habit, more as
    ///     "the moment surprised you." Never lectures. Never punishes.
    private func quoteFraming(proof: ProofMoment, voice: SpeakingStyleGoal?) -> String {
        Self.quoteFramingCopy(
            claim: proof.claim,
            fillerCount: session.fillerWordCount,
            voice: voice
        )
    }

    /// Pure copy resolver for the quote framing line. Pulled out of the
    /// instance method so unit tests can pin the per-voice × per-filler
    /// matrix without instantiating a View. Behaviour is verbatim from
    /// the original `quoteFraming` implementation — same branches, same
    /// strings, same precedence ("if claim is set, trust it").
    static func quoteFramingCopy(
        claim: String,
        fillerCount: Int,
        voice: SpeakingStyleGoal?
    ) -> String {
        if !claim.isEmpty {
            return claim
        }
        switch voice {
        case .authoritative:
            if fillerCount == 0 { return "Clean line, first time out. That's authority showing up early." }
            if fillerCount <= 2 { return "A couple of fillers in your opener. That's a tell, not a habit yet." }
            return "Fillers cluster early when the moment matters. We work the pause next."
        case .warm:
            if fillerCount == 0 { return "Calm and unhurried on the first try. The listener feels that." }
            if fillerCount <= 2 { return "Heard the hesitation — feels like the moment caught you a little." }
            return "First reps surprise everyone. The hesitation is honest, and it's workable."
        case .concise:
            if fillerCount == 0 { return "Clean. No filler. That's the baseline to hold." }
            if fillerCount <= 2 { return "Small fillers, big tell. The fix is one pause, not less talking." }
            return "Fillers cluster. Pause is the trim move."
        case .persuasive:
            if fillerCount == 0 { return "A direct opener, no softeners. That's how a case starts." }
            if fillerCount <= 2 { return "Fillers leak conviction. Yours are minor — the line still lands." }
            return "Hesitation reads as uncertainty. A short pause buys back the same beat with weight."
        case .executive:
            if fillerCount == 0 { return "Composed delivery on rep one. Recommend: hold that register." }
            if fillerCount <= 2 { return "Light fillers in the open. Brief read: a tell to track, not yet a pattern." }
            return "Fillers signal warm-up time. We bake in a pre-rep beat next."
        case .storytelling:
            if fillerCount == 0 { return "You set the scene clean, no scaffolding. That's a story breath." }
            if fillerCount <= 2 { return "The opener wobbled, then steadied. That's the arc of a first read." }
            return "First reads are draft pages. The line is there — the silences around it are next."
        case .none:
            if fillerCount == 0 { return "Clean first line. That's the starting baseline." }
            if fillerCount <= 2 { return "A few fillers in the open. That's a tell, not a habit yet." }
            return "Fillers cluster early. The pause is the move we work on next."
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

#if DEBUG
    func resetForDebug() {
        pendingSession = nil
        UserDefaults.standard.removeObject(forKey: seenKey)
    }
#endif

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
