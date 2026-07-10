#if canImport(SwiftUI)
import SwiftUI

// MARK: - Daily Challenge Tile (M8)
//
// Three-row claim-able tile shown on home, between the daily-goal ring and
// the practice CTA. Each row:
//   • SF Symbol + title + subtitle (compact, two-line max).
//   • State indicator on the right: "Claim" (when readyToClaim), check (when
//     claimed), or muted state (still locked / not yet satisfied).
//   • Tapping a "Claim" row fires the claim() and shows a restrained
//     confirmation. XP is still credited by `DailyChallengesManager`, but
//     Home copy frames the move, not the currency.
//
// Visual rhythm: brand-blue ready state, brand-gray locked, soft-fade past
// 9pm to communicate "today is winding down" without scolding the user.
//
// Daily-reset rhythm v2 (M14):
//   • Header eyebrow shows TODAY most of the day, flips to RESETS IN Nm in
//     the last 15 minutes, brief NEW FOCUS for the first 10 minutes after
//     midnight — so the user feels the rotation happen.
//   • Right-aligned in the header: "Xh Ym before midnight" — a real-time
//     coach-voice signal of expiry pressure.
//   • Bottom-edge 4pt progress bar: tracks day-fraction remaining, color-
//     shifts brandBlue → orange → deeper-orange as midnight approaches.
//   • Claim pill pulses (scale 1.0→1.04, 1.2s autoreverse) while ready;
//     on claim, fades into the checkmark.
//
// Driven by a 60s `Timer.publish` so the bar + countdown stay live without
// hammering the system clock.

@available(iOS 17.0, macOS 12.0, *)
struct DailyChallengeTile: View {
    @StateObject private var manager = DailyChallengesManager.shared
    @StateObject private var dailyGoal = DailyGoalManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showClaimToast = false
    @State private var lastClaim: DailyChallengeKind?

    // Drives the countdown bar + expiry header. 60s is the right cadence:
    // minute-precise display, no CPU churn, and the reset-window flips
    // (TODAY ↔ RESETS IN Nm ↔ NEW FOCUS) all land on minute boundaries
    // by construction.
    @State private var nowTick: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            VStack(spacing: 8) {
                ForEach(manager.todays, id: \.self) { kind in
                    row(for: kind)
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            tileBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(alignment: .bottom) {
            expiryBar
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .overlay(alignment: .top) {
            if showClaimToast, let last = lastClaim {
                claimToast(kind: last)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .onChange(of: manager.pendingClaim) { _, kind in
            guard let kind else { return }
            lastClaim = kind
            withAnimation(reduceMotion ? .none : .standardSpring) {
                showClaimToast = true
            }
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                await MainActor.run {
                    withAnimation(reduceMotion ? .none : .standardSpring) {
                        showClaimToast = false
                    }
                    manager.consumePendingClaim()
                }
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { stamp in
            nowTick = stamp
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily challenges. \(manager.unclaimedCount) of \(manager.todays.count) remaining. \(expiryAccessibilityFragment)")
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Coach-narrator presence: the character lives on the hero
                // (HomeCoachCard) AND inline on tiles that speak in coach
                // voice. Same waveform glyph at smaller scale stitches the
                // tile to the same speaker.
                NoumCharacter.Inline(size: 14, mood: .calm, tint: headerAccent)
                Text(eyebrowLabel)
                    .font(Typography.micro)
                    .foregroundStyle(eyebrowTint)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .accessibilityIdentifier("home.daily.eyebrow")
                Spacer()
                // Right-aligned countdown coach line. Only renders when the
                // tile still has actionable state — once everything is
                // claimed there's nothing to chase, so the "before midnight"
                // signal would be noise.
                if shouldShowExpiryCountdown {
                    Text(expiryCountdownText)
                        .font(Typography.captionSmall)
                        .foregroundStyle(expiryBarColor)
                        .monospacedDigit()
                        .accessibilityIdentifier("home.daily.expiry")
                }
            }
            // Single coach-voice line that names today's challenge concretely
            // and folds the rep count in as a fragment. Replaces the older
            // two-row "1 of 1 rep today · Goal hit" stats treatment.
            Text(coachVoiceHeadline)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("home.daily.coachline")
        }
    }

    /// Single coach-voice headline that adapts to the current state and
    /// names today's anchor challenge by its concrete bar. Folds the
    /// daily-rep count in as a fragment rather than a separate counter row.
    private var coachVoiceHeadline: String {
        Self.headlineCopy(
            state: currentState,
            anchor: anchorChallenge,
            repsToday: dailyGoal.repsToday,
            goalReps: dailyGoal.goalReps
        )
    }

    /// The challenge the coach voice should reference in the headline.
    /// Picks the first ready-to-claim challenge if there is one (so the
    /// claim moment names the right reward), otherwise the first
    /// unclaimed one (so the "what to do" line is concrete). Falls back
    /// to the first kind in the day's trio when everything's claimed.
    private var anchorChallenge: DailyChallengeKind? {
        if let ready = manager.todays.first(where: { manager.readyToClaim.contains($0) }) {
            return ready
        }
        if let unclaimed = manager.todays.first(where: { !manager.claimedKinds.contains($0) }) {
            return unclaimed
        }
        return manager.todays.first
    }

    /// State enum derived from the manager — no new state storage, just
    /// a single switch the copy helper can read.
    enum HeadlineState {
        case cold              // no rep today, nothing ready
        case inProgress        // at least one rep, no challenge ready yet
        case readyToClaim      // at least one challenge satisfied, not claimed
        case claimed           // every challenge claimed
        case softExpiry        // past 9pm and still claimable
    }

    private var currentState: HeadlineState {
        if manager.allClaimedToday { return .claimed }
        if !manager.readyToClaim.isEmpty { return .readyToClaim }
        if manager.isPastSoftExpiry { return .softExpiry }
        if dailyGoal.repsToday > 0 { return .inProgress }
        return .cold
    }

    /// Pure copy helper — easy to test, easy to localize later. State
    /// drives shape; the anchor challenge contributes the concrete noun
    /// (the 3-second pause, the zero-filler rep, etc.).
    static func headlineCopy(
        state: HeadlineState,
        anchor: DailyChallengeKind?,
        repsToday: Int,
        goalReps: Int
    ) -> String {
        let target = anchor?.targetPhrase ?? "a clean rep"
        switch state {
        case .cold:
            return "Today's focus — \(target). One rep gets you started."
        case .inProgress:
            let repFragment = repsToday == 1 ? "One rep in." : "\(repsToday) reps in."
            return "Today's focus — \(target). \(repFragment)"
        case .readyToClaim:
            guard let kind = anchor else {
                return "Today's focus is logged. Tap to claim."
            }
            return "\(kind.claimedNoun.capitalizedFirst) logged. Tap to claim."
        case .claimed:
            let extra = max(0, repsToday - goalReps)
            if let kind = anchor, extra > 0 {
                let unit = extra == 1 ? "rep" : "reps"
                return "\(kind.claimedNoun.capitalizedFirst) logged and claimed. \(extra) \(unit) still in the bank if you want them."
            }
            if let kind = anchor {
                return "\(kind.claimedNoun.capitalizedFirst) logged and claimed."
            }
            return "Today's focus is logged and claimed."
        case .softExpiry:
            return "Today's focus is still open — \(target)."
        }
    }

    private var headerAccent: Color {
        if manager.allClaimedToday { return AppColor.brandBlue }
        if manager.isPastSoftExpiry { return .secondary }
        return AppColor.brandBlue
    }

    // MARK: - Reset rhythm header

    /// Window state for the eyebrow label. Three real-clock signals:
    ///   • `newFocus` — first 10 minutes after midnight; says the
    ///     rotation just happened.
    ///   • `resetsIn(Int)` — last 15 minutes of the day; counts down to
    ///     the rollover the user is about to see.
    ///   • `today` — every other moment.
    ///
    /// Derived purely from `nowTick` and `Calendar.current`. No state
    /// stored, no flags to clear — when the clock ticks past 12:10am the
    /// label naturally falls back to TODAY. Internal access so unit
    /// tests can assert against the helper directly.
    enum EyebrowWindow: Equatable {
        case today
        case resetsIn(minutes: Int)
        case newFocus
    }

    private var eyebrowWindow: EyebrowWindow {
        Self.eyebrowWindow(at: nowTick, calendar: .current)
    }

    /// Pure helper, exposed for unit tests. Uses `startOfDay` semantics so
    /// "midnight" is the canonical day boundary, not 23:59:59. Handles DST
    /// rollovers via Calendar arithmetic — no manual hour math.
    static func eyebrowWindow(at now: Date, calendar: Calendar) -> EyebrowWindow {
        let startOfDay = calendar.startOfDay(for: now)
        let secondsSinceMidnight = now.timeIntervalSince(startOfDay)
        // First 10 minutes after midnight — "NEW FOCUS" rotation moment.
        if secondsSinceMidnight < 10 * 60 {
            return .newFocus
        }
        // Last 15 minutes before midnight — "RESETS IN Nm".
        let mins = minutesUntilMidnight(from: now, in: calendar)
        if mins <= 15 {
            // Floor of remaining minutes — once we're under one minute,
            // show 1m rather than 0m so it never reads "RESETS IN 0m" while
            // claims are still live.
            return .resetsIn(minutes: max(1, mins))
        }
        return .today
    }

    private var eyebrowLabel: String {
        switch eyebrowWindow {
        case .today:                      return "Today"
        case .resetsIn(let m):            return "Resets in \(m)m"
        case .newFocus:                   return "New focus"
        }
    }

    /// Eyebrow tint shifts to the expiry color in the resets-in window so
    /// the visual pressure register matches the bottom bar and countdown.
    /// NEW FOCUS rides the brandBlue register — same color the
    /// claim-ready state already uses, signalling "fresh, ready, go."
    private var eyebrowTint: Color {
        switch eyebrowWindow {
        case .today:        return .secondary
        case .resetsIn:     return expiryBarColor
        case .newFocus:     return AppColor.brandBlue
        }
    }

    // MARK: - Expiry countdown + bar

    /// True for every state except `allClaimed` — once nothing is claimable
    /// there's no useful signal in displaying "Xh Ym before midnight."
    private var shouldShowExpiryCountdown: Bool {
        !manager.allClaimedToday
    }

    /// "3h 47m before midnight" / "47m before midnight" / "Under a minute".
    /// Coach voice — restrained, no exclamation, no "Hurry!".
    private var expiryCountdownText: String {
        Self.expiryCountdownText(minutesRemaining: Self.minutesUntilMidnight(from: nowTick, in: .current))
    }

    static func expiryCountdownText(minutesRemaining mins: Int) -> String {
        if mins <= 1 { return "Under a minute" }
        if mins < 60 { return "\(mins)m before midnight" }
        let h = mins / 60
        let m = mins % 60
        if m == 0 { return "\(h)h before midnight" }
        return "\(h)h \(m)m before midnight"
    }

    /// Compute minutes until the next local midnight. Stable to DST via
    /// `Calendar.startOfDay(for:) + .day = 1` — DON'T use 23:59:59 math.
    /// Returned value is clamped to [0, 1440] so callers don't have to
    /// guard against edge cases when the timer fires within a few ms of
    /// midnight.
    static func minutesUntilMidnight(from now: Date, in calendar: Calendar) -> Int {
        let startOfDay = calendar.startOfDay(for: now)
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return 0
        }
        let seconds = nextMidnight.timeIntervalSince(now)
        let mins = Int(floor(seconds / 60.0))
        return max(0, min(1440, mins))
    }

    /// Fraction of the day remaining, 0.0 (midnight) → 1.0 (just after the
    /// previous midnight). Drives the bottom bar width.
    private var dayFractionRemaining: Double {
        Double(Self.minutesUntilMidnight(from: nowTick, in: .current)) / 1440.0
    }

    /// Bar + countdown color. Three bands:
    ///   • > 6h left  → softened brand-blue (calm, plenty of time).
    ///   • 2–6h left  → modeSuddenDeath orange at 70% (warming up).
    ///   • < 2h left  → modeSuddenDeath orange at full (real pressure).
    /// After softExpiry (past 9pm) the bar drops to the orange register
    /// regardless of exact hours-remaining — matches the existing 9pm
    /// "winding down" tone the rest of the tile already wears.
    private var expiryBarColor: Color {
        let mins = Self.minutesUntilMidnight(from: nowTick, in: .current)
        let hoursLeft = Double(mins) / 60.0
        if hoursLeft < 2 {
            return AppColor.modeSuddenDeath
        }
        if hoursLeft < 6 || manager.isPastSoftExpiry {
            return AppColor.modeSuddenDeath.opacity(0.7)
        }
        return AppColor.brandBlue.opacity(0.7)
    }

    /// Bottom-edge progress strip — 4pt tall, fills as the day burns down.
    /// Hidden while everything is claimed (the celebration register owns
    /// the tile then, and there's nothing to chase).
    @ViewBuilder
    private var expiryBar: some View {
        if !manager.allClaimedToday {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    // Track — barely visible so the bar reads as "real
                    // surface fills" not "color on background."
                    Rectangle()
                        .fill(Color.secondary.opacity(0.10))
                    Rectangle()
                        .fill(expiryBarColor)
                        .frame(width: proxy.size.width * CGFloat(dayFractionRemaining))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: dayFractionRemaining)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: expiryBarColor)
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)  // The countdown text + accessibilityLabel already carry the signal.
        }
    }

    private var expiryAccessibilityFragment: String {
        if manager.allClaimedToday { return "All claimed for today." }
        let mins = Self.minutesUntilMidnight(from: nowTick, in: .current)
        return Self.expiryCountdownText(minutesRemaining: mins) + "."
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for kind: DailyChallengeKind) -> some View {
        let claimed = manager.claimedKinds.contains(kind)
        let ready = manager.readyToClaim.contains(kind)
        let muted = manager.isPastSoftExpiry && !claimed

        Button {
            guard ready else { return }
            _ = manager.claim(kind)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(rowAccent(claimed: claimed, ready: ready, muted: muted))
                    .frame(width: 32, height: 32)
                    .background(
                        rowAccent(claimed: claimed, ready: ready, muted: muted).opacity(claimed ? 0.18 : 0.12),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                // Subtitle dropped — was 2 lines per row × 3 rows = 6 lines
                // of supporting text. The title carries the move; the
                // subtitle restated the same thing in slightly more
                // words. The full subtitle is read aloud in the
                // accessibility label below for VoiceOver users.
                Text(kind.title)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(claimed ? .secondary : .primary)
                    .strikethrough(claimed, color: .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                trailing(claimed: claimed, ready: ready, kind: kind)
            }
            .opacity(muted ? 0.6 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!ready)
        .accessibilityLabel(rowAccessibilityLabel(kind: kind, claimed: claimed, ready: ready))
    }

    @ViewBuilder
    private func trailing(claimed: Bool, ready: Bool, kind: DailyChallengeKind) -> some View {
        ZStack {
            if claimed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else if ready {
                ClaimReadyPill(reduceMotion: reduceMotion)
                    .transition(.opacity)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .standardSpring, value: claimed)
        .animation(reduceMotion ? nil : .standardSpring, value: ready)
    }

    private func rowAccent(claimed: Bool, ready: Bool, muted: Bool) -> Color {
        if claimed { return AppColor.brandBlue }
        if ready { return AppColor.brandBlue }
        if muted { return .secondary }
        return .secondary
    }

    private func rowAccessibilityLabel(kind: DailyChallengeKind, claimed: Bool, ready: Bool) -> String {
        Self.rowAccessibilityLabel(kind: kind, claimed: claimed, ready: ready)
    }

    static func rowAccessibilityLabel(kind: DailyChallengeKind, claimed: Bool, ready: Bool) -> String {
        if claimed { return "\(kind.title). Claimed." }
        if ready { return "\(kind.title). Ready to claim." }
        return "\(kind.title). \(kind.subtitle)"
    }

    // MARK: - Background

    private var tileBackground: some ShapeStyle {
        if manager.allClaimedToday {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppColor.brandBlue.opacity(0.10), AppColor.brandBlue.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(AppColor.cardBackground)
    }

    // MARK: - Claim toast

    private func claimToast(kind: DailyChallengeKind) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
            Text("Claimed — \(kind.title)")
                .font(Typography.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppColor.brandBlue, in: Capsule())
        .shadow(color: AppColor.brandBlue.opacity(0.30), radius: 12, x: 0, y: 4)
        .padding(.top, -16)
    }
}

// MARK: - Claim-ready pill (subtle scale pulse)
//
// Factored out so the pulse driver (`scaleEffect` + `withAnimation(autoreverses:)`)
// only re-runs when this view appears — not on every parent re-render. The
// pulse fires exactly when a challenge becomes claimable; once the user
// claims it (or never does, until midnight rolls the day over), the row
// transitions away from this view and the animation tears down with it.

@available(iOS 17.0, macOS 12.0, *)
private struct ClaimReadyPill: View {
    let reduceMotion: Bool

    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 4) {
            Text("Claim")
                .font(Typography.micro.weight(.bold))
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColor.brandBlue, in: Capsule())
        .scaleEffect(pulsing ? 1.04 : 1.0)
        .shadow(color: AppColor.brandBlue.opacity(pulsing ? 0.30 : 0.0), radius: 6, x: 0, y: 2)
        // Restraint: a 1.2s loop, 0.04 scale, 0.30 shadow alpha. The
        // pulse must read as "earn it" not as a fidget — too tight
        // and it feels needy, too loose and the user never notices.
        // .animation(value:) is the right primitive here over
        // `withAnimation` inside `.onAppear`, because it scopes the
        // implicit transaction to this view and tears down cleanly
        // when the row transitions to claimed.
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
            value: pulsing
        )
        .onAppear {
            guard !reduceMotion else { return }
            pulsing = true
        }
    }
}

// MARK: - Coach-voice copy helpers
//
// These extensions live here (not in DailyChallenge.swift) because they're
// presentation-layer copy, not domain logic. Keeping the imperative target
// phrasing next to the tile that renders it makes both easier to revise.

extension DailyChallengeKind {
    /// Imperative target — drops into "Today's focus — \(targetPhrase)."
    /// Sentence-case, no trailing punctuation, no "you" (the wrapper line
    /// supplies the address).
    var targetPhrase: String {
        switch self {
        case .heldPause:                return "hold a 3 second pause cleanly"
        case .shortAnswer:              return "land a 14-word answer under 30 seconds with at most one filler"
        case .zeroFillers:              return "land a 14-word rep with zero fillers"
        case .sustainedAnswer:          return "hold a 60-second answer with at most three fillers"
        case .cleanSuddenDeath:         return "clear a Pressure Drill round with zero fillers"
        case .crispDelivery:            return "land a 130 to 155 WPM rep with at most two fillers"
        case .highScoreSession:         return "land an 8 out of 10 session"
        case .multiplePauses:           return "use silence twice in one rep, no filler bridges"
        case .lowFillerRate:            return "hold a 25-word rep to a single filler"
        case .soloAhCounter:            return "run an Ah-Counter rep with at most one filler"
        case .timedDeepRep:             return "land a 90-second Timed rep that scores at least 7"
        case .suddenDeathSurvivor:      return "hold Pressure Drill 60 seconds with one filler at most"
        case .imConversationClean:      return "hold a 30-word conversation rep with at most two fillers"
        case .ratedRep:                 return "finish one rated rep today"
        case .noFillerSpike:            return "land a 40-word rep with zero fillers"
        case .sub3PercentFillers:       return "keep fillers under 3% across a 30-word rep"
        case .longHeldPause:            return "hold a single 4-second pause"
        case .threeDeliberatePauses:    return "use silence three times in one rep, mostly clean"
        case .meanPauseQuality:         return "average a 1-second pause across the rep, mostly clean"
        case .steadyPace:               return "hold a 120 to 170 WPM cadence with at most three fillers"
        case .measuredPace:             return "stay in a deliberate 110 to 135 WPM with at most two fillers"
        case .wordRich:                 return "land a 60-word rep that scores at least 7"
        case .sustainedSeventy:         return "hold an answer 70 seconds with at most two fillers"
        case .sustainedNinety:          return "hold an answer 90 seconds with at most three fillers"
        case .perfectTen:               return "land a perfect 10 out of 10 session"
        case .strongPair:               return "land a 7 or higher score with at most two fillers"
        case .pitchVariation:           return "vary your pitch across the rep, not monotone"
        case .pressureRep:              return "score 7 or higher on a non-standard pressure rep"
        case .secondRepToday:           return "stack a second finalized rep today"
        case .calmStart:                return "open a 60-second rep with no fillers and a deliberate pause"
        }
    }

    /// Noun phrase for the past-tense headline — drops into
    /// "\(claimedNoun.capitalizedFirst) logged. Tap to claim …" so the
    /// claim moment names what was earned. Lowercase, no article.
    var claimedNoun: String {
        switch self {
        case .heldPause:                return "hold"
        case .shortAnswer:              return "short answer"
        case .zeroFillers:              return "clean rep"
        case .sustainedAnswer:          return "long answer"
        case .cleanSuddenDeath:         return "clean Pressure Drill round"
        case .crispDelivery:            return "crisp rep"
        case .highScoreSession:         return "8 out of 10 session"
        case .multiplePauses:           return "double-pause rep"
        case .lowFillerRate:            return "single-filler rep"
        case .soloAhCounter:            return "clean Ah-Counter rep"
        case .timedDeepRep:             return "90-second Timed rep"
        case .suddenDeathSurvivor:      return "Pressure Drill 60-second run"
        case .imConversationClean:      return "clean conversation rep"
        case .ratedRep:                 return "rated rep"
        case .noFillerSpike:            return "40-word clean rep"
        case .sub3PercentFillers:       return "low-filler-rate rep"
        case .longHeldPause:            return "4-second hold"
        case .threeDeliberatePauses:    return "triple-pause rep"
        case .meanPauseQuality:         return "deliberate-cadence rep"
        case .steadyPace:               return "steady-cadence rep"
        case .measuredPace:             return "measured-pace rep"
        case .wordRich:                 return "60-word rep"
        case .sustainedSeventy:         return "70-second answer"
        case .sustainedNinety:          return "90-second answer"
        case .perfectTen:               return "10 out of 10 session"
        case .strongPair:               return "strong-score rep"
        case .pitchVariation:           return "varied-pitch rep"
        case .pressureRep:              return "pressure rep"
        case .secondRepToday:           return "second rep today"
        case .calmStart:                return "calm opener"
        }
    }
}

private extension String {
    /// Lightweight first-letter capitalize that preserves the rest of the
    /// string unchanged. Avoids `capitalized` which lowercases proper
    /// nouns ("Sudden Death" → "Sudden death").
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}

// MARK: - Preview

#Preview {
    DailyChallengeTile()
        .padding()
        .background(AppColor.screenBackground)
}

#endif
