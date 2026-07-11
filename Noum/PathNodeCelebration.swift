#if canImport(SwiftUI)
import SwiftUI

// MARK: - Path Node Celebration ("Landmark Reached")
//
// Full-screen cinematic fired the moment a path node is newly unlocked.
// The path is the visible story of progress in Noum — clearing a node is
// the resonant beat that anchors the STORY/PROGRESSION pillar. The
// overlay carries the weight of that moment: brand-blue radial backdrop,
// large `NoumCharacter` at `.excited`, a "Chapter X of N" eyebrow that
// reads the moment back as a chapter in the user's arc, a coach-voice
// headline, the node title as subtitle, and one criterion-aware stat line
// that names what the user actually did to earn it. CTAs land last.
//
// Visual vocabulary matches `FirstRepCelebration` (phase enum, beat
// schedule, reduce-motion fallback) and `TierPromotionOverlay` (radial
// backdrop, SparkleRibbon — already baked into `.excited`). One celebration
// voice across the app.
//
// Beats (full-motion):
//   1. Backdrop fades in (0.0s → 0.5s).
//   2. Character springs from 0.7 → 1.0 with `.snappySpring` (0.0s → 0.7s).
//      Sparkle ribbon comes free with `.excited`; brief confetti burst.
//   3. Eyebrow + headline slide up + fade in (200ms delay).
//   4. Subtitle fades in (300ms delay).
//   5. Stat line fades in (400ms delay), numbers transition via
//      `.contentTransition(.numericText())` so the count animates if any
//      value changes after present.
//   6. CTAs (Continue + Open the Path) fade in last (500ms delay).
//
// Reduce-motion:
//   All phases collapse into a single 0.4s ease-out fade-in. No spring,
//   no slide, no confetti, no orbit. `NoumCharacter`'s breathing halo +
//   sparkle ribbon stay static (it's a per-symbol opacity twinkle in the
//   ribbon; the breathing halo internally honours reduce-motion).
//
// Brand rules honoured:
//   • No emoji. SF Symbols only.
//   • Coach voice — no exclamation. Motion + sparkle carry the moment.
//   • Character stays SF-Symbol composed (NoumCharacter).
//   • Lock-screen-safety: never quotes typed goal text. Stat line reads
//     numeric session metrics only.
//   • All tokens from DesignSystem.
//
// Persistence stays unchanged — `PathProgressManager.consumeCelebration()`
// owns the trigger lifecycle. The overlay just renders.

@available(iOS 17.0, macOS 12.0, *)
struct PathNodeCelebration: View {
    let node: PathNode
    let onDismiss: () -> Void
    /// Optional secondary CTA. When non-nil the "Open the Path" link
    /// renders under "Continue"; when nil it's hidden so the call site
    /// can opt out (e.g. when the celebration fires *from* the path view
    /// itself, where the secondary would be a no-op).
    var onOpenPath: (() -> Void)? = nil
    /// Optional transcript-anchored proof of growth tied to the user's
    /// voice goal. Renders as a small italicized quote below the stat
    /// line. When nil the row is hidden entirely — the celebration
    /// doesn't manufacture a quote it doesn't have.
    var proof: ProofMoment? = nil

    @State private var phase: Phase = .preReveal
    @State private var confettiActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var pathProgress = PathProgressManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared

    /// Entrance choreography phases. Forward-only; each step gates one
    /// element of the composition. Matches the cadence in
    /// `FirstRepCelebration` so the celebration vocabulary stays uniform.
    enum Phase: Int, Comparable {
        case preReveal     // Nothing visible yet
        case backdropIn    // Radial fading in
        case characterIn   // NoumCharacter scaled in, sparkle ribbon live
        case headlineIn    // Eyebrow + headline slid + faded in
        case subtitleIn    // Landmark name fading in
        case statIn        // Stat line fading in
        case ctaIn         // Continue + Open the Path

        static func < (lhs: Phase, rhs: Phase) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    var body: some View {
        ZStack {
            backdrop
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Brief confetti burst at character entrance. The layer is
            // reduce-motion-aware on its own; the gate here just skips
            // the allocation on the inert path.
            if !reduceMotion {
                ConfettiLayer(active: confettiActive, pieceCount: 22, duration: 1.5)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: Spacing.lg) {
                Spacer(minLength: 0)

                character
                    .padding(.vertical, Spacing.xs)

                VStack(spacing: Spacing.sm) {
                    eyebrow
                    headline
                    subtitle
                }
                .padding(.horizontal, Spacing.lg)

                statLine
                    .padding(.horizontal, Spacing.lg)

                if let proof = proof {
                    proofLine(proof: proof)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.xs)
                }

                Spacer(minLength: 0)

                VStack(spacing: Spacing.sm) {
                    continueButton
                    if onOpenPath != nil {
                        openPathButton
                    }
                }
                .opacity(phase >= .ctaIn ? 1 : 0)
                .offset(y: phase >= .ctaIn ? 0 : 8)
                .padding(.horizontal, Spacing.screenH)
                .padding(.bottom, Spacing.lg)
            }
        }
        .onAppear { runSequence() }
        .accessibilityIdentifier("path.celebration")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityCopy)
    }

    // MARK: - Backdrop

    /// Tinted radial in `AppColor.brandBlue` — the path register. Anchored
    /// just above center so the character sits in the brighter band; the
    /// black floor at the bottom focuses the CTA cluster.
    private var backdrop: some View {
        ZStack {
            // Base black so the radial reads on every device + dark-mode
            // root. Floor is the calming counterweight to the blue bloom.
            Color.black.opacity(0.96)

            RadialGradient(
                colors: [
                    AppColor.brandBlue.opacity(0.58),
                    AppColor.brandBlue.opacity(0.30),
                    Color.black.opacity(0.0)
                ],
                center: UnitPoint(x: 0.5, y: 0.34),
                startRadius: 20,
                endRadius: 620
            )

            // Subtle bottom vignette so the CTA stack reads against a
            // calmer floor than the brighter middle band.
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.38)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .opacity(phase >= .backdropIn ? 1 : 0)
    }

    // MARK: - Character

    /// Large `NoumCharacter` at `.excited` — the coach, celebrating at
    /// the user's current arc. The `.excited` mood owns the sparkle
    /// ribbon already, so we don't stack a second one. Springs from
    /// 0.7 → 1.0 on entrance per spec.
    private var character: some View {
        NoumCharacter(
            mood: .excited,
            tint: .white,
            size: 140
        )
        .scaleEffect(phase >= .characterIn ? 1.0 : 0.7)
        .opacity(phase >= .characterIn ? 1.0 : 0.0)
        .shadow(color: AppColor.brandBlue.opacity(0.5), radius: 36, y: 10)
    }

    // MARK: - Eyebrow + headline + subtitle

    /// "Chapter X of N." — reads the moment back as a chapter in the
    /// user's arc, not a "node unlocked" gamification beat.
    private var eyebrow: some View {
        Text(chapterCopy)
            .font(Typography.micro)
            .foregroundStyle(.white.opacity(0.78))
            .textCase(.uppercase)
            .tracking(1.2)
            .opacity(phase >= .headlineIn ? 1 : 0)
            .offset(y: phase >= .headlineIn ? 0 : 8)
            .contentTransition(.numericText())
            .accessibilityLabel(accessibilityChapterCopy)
    }

    /// "Landmark reached." — display weight, Dynamic-Type-aware rounded
    /// treatment. Coach voice, no exclamation. Motion + sparkle carry the
    /// moment.
    private var headline: some View {
        Text("Landmark reached.")
            .font(Typography.figtree(size: 32, weight: .bold, relativeTo: .title))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: Color.black.opacity(0.28), radius: 14, y: 4)
            .opacity(phase >= .headlineIn ? 1 : 0)
            .offset(y: phase >= .headlineIn ? 0 : 12)
            .accessibilityAddTraits(.isHeader)
    }

    /// Landmark name = the node's `title`. Stays as the user's reference
    /// to what they just earned ("Hold a silent beat", "Three-day streak").
    private var subtitle: some View {
        Text(node.title)
            .font(Typography.cardTitle)
            .foregroundStyle(.white.opacity(0.92))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(phase >= .subtitleIn ? 1 : 0)
    }

    // MARK: - Stat line

    /// One specific stat line, criterion-aware. Switches on the node ID
    /// to pull the evidence from the latest session (and the live stores
    /// for streak / rating / mastery / crown nodes). Falls through to a
    /// concrete "X reps in" line if a specific evidence read isn't
    /// available — the celebration earns the right to assert *something*
    /// numeric, but only what the data actually supports.
    private var statLine: some View {
        Text(statCopy)
            .font(Typography.subheadline)
            .foregroundStyle(.white.opacity(0.86))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(phase >= .statIn ? 1 : 0)
            .contentTransition(.numericText())
            .accessibilityElement(children: .combine)
    }

    /// Transcript-anchored proof line. Italicized quote + technique
    /// chip, sitting just under the stat line. Visual restraint: this
    /// is the celebration register, the proof is supportive (not
    /// shouting). Same fade-in beat as the stat line so the moment
    /// reads as one composed reveal, not a stacked list of cards.
    @ViewBuilder
    private func proofLine(proof: ProofMoment) -> some View {
        VStack(spacing: 4) {
            Text("\u{201C}\(proof.quote)\u{201D}")
                .font(Typography.body.italic())
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(proof.technique.uppercased())
                .font(Typography.micro.weight(.bold))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(0.8)
        }
        .opacity(phase >= .statIn ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Proof: \(proof.quote). \(proof.technique).")
    }

    // MARK: - CTAs

    /// Brand-blue primary. The spec asks for brand-blue here even though
    /// `TierPromotionOverlay` flips to white-on-tint — that's because
    /// path nodes are *the* path register, so the brand colour reads as
    /// "this is the path's voice."
    private var continueButton: some View {
        Button(action: onDismiss) {
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
                AppColor.brandBlue.gradient,
                in: Capsule(style: .continuous)
            )
            .shadow(color: AppColor.brandBlue.opacity(0.45), radius: 18, y: 8)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("path.celebration.continue")
    }

    /// Lower-weight secondary that takes the user to the path view so
    /// they can see the just-unlocked node in context. Hidden when the
    /// caller doesn't provide a destination (e.g. when the celebration
    /// fires from the path view itself).
    private var openPathButton: some View {
        Button {
            CoachHaptic.selectionTap()
            onOpenPath?()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "map")
                    .font(Typography.caption.weight(.bold))
                Text("See Path")
                    .font(Typography.caption.weight(.bold))
            }
            .foregroundStyle(.white.opacity(0.78))
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("path.celebration.openPath")
    }

    // MARK: - Sequence

    /// Drives the entrance choreography. Reduce-motion users resolve all
    /// phases at once with a single fade — every animation in the build
    /// is gated by the same check.
    private func runSequence() {
        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.4)) {
                phase = .ctaIn
            }
            CoachHaptic.trendBreakthrough()
            return
        }

        // Beat 1 — Backdrop fades in (0.0s → 0.5s)
        withAnimation(.easeOut(duration: 0.5)) {
            phase = .backdropIn
        }

        // Beat 2 — Character springs in + brief confetti (0.0s → 0.7s).
        // Snappy spring matches the spec; sparkle ribbon is baked into
        // `.excited`, so the character orbits a ribbon during the
        // remainder of the overlay.
        withAnimation(.snappySpring) {
            phase = .characterIn
        }
        CoachHaptic.trendBreakthrough()
        confettiActive = true

        // Beat 3 — Eyebrow + headline slide up + fade (200ms delay).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                phase = .headlineIn
            }
        }

        // Beat 4 — Subtitle (landmark name) fades in (300ms delay).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(.easeOut(duration: 0.35)) {
                phase = .subtitleIn
            }
        }

        // Beat 5 — Stat line fades in (400ms delay).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            withAnimation(.easeOut(duration: 0.35)) {
                phase = .statIn
            }
        }

        // Beat 6 — CTAs fade in last (500ms delay).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            withAnimation(.easeOut(duration: 0.35)) {
                phase = .ctaIn
            }
            CoachHaptic.scoreReveal()
        }
    }

    // MARK: - Chapter copy
    //
    // Reads from `PathProgressManager.statuses`. At the moment this view
    // appears, the just-unlocked node has already been absorbed into the
    // unlocked set by `evaluateAfterSession()` — so the chapter number
    // *includes* the one we're celebrating. That's the right semantics:
    // "Chapter 3 of 20" means "you just landed on chapter 3."

    private var chapterNumber: Int {
        // Chapter index = position of this node in the registry (1-based).
        // We use the node's `order + 1` rather than "count of unlocked"
        // because a user can unlock out-of-sequence (a clean rep can
        // satisfy a later node before an earlier one). Naming the
        // chapter by position keeps the story sequential and honest.
        node.order + 1
    }

    private var totalChapters: Int {
        max(pathProgress.statuses.count, PathNodeRegistry.all.count)
    }

    private var chapterCopy: String {
        "Chapter \(chapterNumber) of \(totalChapters)."
    }

    private var accessibilityChapterCopy: String {
        "Chapter \(chapterNumber) of \(totalChapters)"
    }

    // MARK: - Stat line copy
    //
    // The celebration earns the right to assert *something* numeric — but
    // only what the underlying data actually supports. Each criterion
    // family resolves to its strongest evidence read from the last
    // session, the live stores, or the criterion target itself.
    //
    // Lock-screen-safety rule: never quote prompt or transcript text.
    // Numeric session metrics only.

    private var statCopy: String {
        let entry = PathNodeRegistry.all.first(where: { $0.0.id == node.id })
        let criterion = entry?.1
        let lastSession = sessionStore.sessions.last
        let totalReps = sessionStore.sessions.count

        // Specific reads per criterion family. When we can't pull a
        // crisp evidence line, we fall through to the generic line.
        switch criterion {
        case .zeroFillerSession:
            if let s = lastSession, s.fillerWordCount == 0 {
                let dur = max(1, Int(s.duration.rounded()))
                return "\(dur) seconds, zero fillers. You earned this."
            }
        case .cleanRunsInWindow:
            let clean = sessionStore.sessions.suffix(50)
                .filter { $0.fillerWordCount == 0 && ($0.score ?? 0) >= 5 }
                .count
            if clean > 0 {
                let unit = clean == 1 ? "clean rep" : "clean reps"
                return "\(clean) \(unit) banked. You earned this."
            }
        case .scoreAtLeast(let target):
            if let s = lastSession, let score = s.score, score >= target {
                return "\(score) out of 10. You earned this."
            }
        case .ratingAtLeast:
            let peak = RatingStore.shared.rating.peakRating
            return "Peak rating \(peak). You earned this."
        case .streakAtLeast(let n):
            let streak = StreakFreezeManager.shared.currentStreak
            let shown = max(streak, n)
            let unit = shown == 1 ? "day" : "days"
            return "\(shown) \(unit) in a row. You earned this."
        case .distinctPracticeDays:
            let days = uniquePracticeDayCount()
            let unit = days == 1 ? "day" : "days"
            return "\(days) \(unit) of practice. You earned this."
        case .sessionCountAtLeast(let n):
            let shown = max(totalReps, n)
            let unit = shown == 1 ? "rep" : "reps"
            return "\(shown) \(unit) in. You earned this."
        case .modeSessionAtLeast(let mode, _):
            let count = sessionStore.sessions.filter { $0.mode == mode }.count
            let unit = count == 1 ? "rep" : "reps"
            return "\(count) \(unit) in \(modeName(mode)). You earned this."
        case .pressureSurvived(let rounds):
            return "Held composure through round \(rounds). You earned this."
        case .modeMasteryLevel(let mode, let level):
            return "Mastery \(level) in \(modeNameForMastery(criterion: criterion, default: mode)). You earned this."
        case .modeMasteryAnyLevel(let level):
            return "Mastery \(level) across modes. You earned this."
        case .totalLessonPasses:
            let passes = LessonStore.shared.totalPracticePasses
            let unit = passes == 1 ? "practice pass" : "practice passes"
            return "\(passes) \(unit) complete. You earned this."
        case .anyLessonMastered:
            return "A lesson taken through five practice passes. You earned this."
        case .heldSilentPause:
            if let m = lastSession?.pauseMetrics, m.longestSeconds > 0 {
                return "\(secondsLabel(m.longestSeconds)) silent pause. You earned this."
            }
        case .cleanPauseSession:
            if let m = lastSession?.pauseMetrics, m.count > 0 {
                let pct = Int((m.filledRatio * 100).rounded())
                let unit = m.count == 1 ? "pause" : "pauses"
                return "\(m.count) \(unit), \(pct)% filled. You earned this."
            }
        case .none:
            break
        }

        // Fallback — concrete, never empty, never asserts data we don't
        // have. "X reps in" is true at any point a node clears.
        let unit = totalReps == 1 ? "rep" : "reps"
        let count = max(totalReps, 1)
        return "\(count) \(unit) in. You earned this."
    }

    private var accessibilityCopy: String {
        "Landmark reached. \(accessibilityChapterCopy). \(node.title). \(statCopy)"
    }

    // MARK: - Helpers

    private func uniquePracticeDayCount() -> Int {
        let calendar = Calendar.current
        return Set(sessionStore.sessions.map { calendar.startOfDay(for: $0.date) }).count
    }

    private func modeName(_ mode: PracticeMode) -> String {
        mode.displayLabel
    }

    /// Resolves the mode label for both `modeMasteryLevel(mode, level)` and
    /// `modeMasteryAnyLevel(level)` criteria. For the "any" variant we
    /// pick the mode the user is actually highest in so the copy is
    /// honest about which mode just hit the bar.
    private func modeNameForMastery(criterion: PathNodeCriterion?, default mode: PracticeMode) -> String {
        if case .modeMasteryAnyLevel = criterion {
            let snapshots = ModeMasteryStore.shared.snapshots
            if let (topMode, _) = snapshots.max(by: { $0.value.level < $1.value.level }) {
                return modeName(topMode)
            }
        }
        return modeName(mode)
    }

    /// "1.5s" / "3s" — short numeric pause label. Mirrors `GatingPhrase`.
    private func secondsLabel(_ s: Double) -> String {
        if s == floor(s) {
            return "\(Int(s))s"
        }
        return String(format: "%.1fs", s)
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Landmark Reached — Clean rep") {
    PathNodeCelebration(
        node: PathNodeRegistry.all.first(where: { $0.0.id == "clean_rep" })!.0,
        onDismiss: {},
        onOpenPath: {}
    )
}

@available(iOS 17.0, *)
#Preview("Landmark Reached — First rep") {
    PathNodeCelebration(
        node: PathNodeRegistry.all.first(where: { $0.0.id == "first_rep" })!.0,
        onDismiss: {}
    )
}

@available(iOS 17.0, *)
#Preview("Landmark Reached — Composed pauses") {
    PathNodeCelebration(
        node: PathNodeRegistry.all.first(where: { $0.0.id == "clean_pause_session" })!.0,
        onDismiss: {},
        onOpenPath: {}
    )
}
#endif

#endif
