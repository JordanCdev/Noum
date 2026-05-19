#if canImport(SwiftUI)
import SwiftUI

// MARK: - Daily Challenge Tile (M8)
//
// Three-row claim-able tile shown on home, between the daily-goal ring and
// the practice CTA. Each row:
//   • SF Symbol + title + subtitle (compact, two-line max).
//   • State indicator on the right: "Claim" (when readyToClaim), check (when
//     claimed), or muted state (still locked / not yet satisfied).
//   • Tapping a "Claim" row fires the claim() and shows the XP gain.
//
// Visual rhythm: brand-blue ready state, brand-gray locked, soft-fade past
// 9pm to communicate "today is winding down" without scolding the user.

@available(iOS 17.0, macOS 12.0, *)
struct DailyChallengeTile: View {
    @StateObject private var manager = DailyChallengesManager.shared
    @StateObject private var dailyGoal = DailyGoalManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showClaimToast = false
    @State private var lastClaim: DailyChallengeKind?

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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily challenges. \(manager.unclaimedCount) of \(manager.todays.count) remaining.")
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
                Text("Today")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text(headerStatusChip)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(headerAccent)
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
    fileprivate enum HeadlineState {
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
    fileprivate static func headlineCopy(
        state: HeadlineState,
        anchor: DailyChallengeKind?,
        repsToday: Int,
        goalReps: Int
    ) -> String {
        let target = anchor?.targetPhrase ?? "a clean rep"
        switch state {
        case .cold:
            return "Today's mission — \(target). One rep gets you started."
        case .inProgress:
            let repFragment = repsToday == 1 ? "One rep in." : "\(repsToday) reps in."
            return "Today's mission — \(target). \(repFragment)"
        case .readyToClaim:
            guard let kind = anchor else {
                return "Today's mission is logged. Tap to claim."
            }
            return "\(kind.claimedNoun.capitalizedFirst) logged. Tap to claim — +\(kind.xpReward) XP."
        case .claimed:
            let extra = max(0, repsToday - goalReps)
            if let kind = anchor, extra > 0 {
                let unit = extra == 1 ? "rep" : "reps"
                return "\(kind.claimedNoun.capitalizedFirst) logged and claimed. \(extra) \(unit) still in the bank if you want them."
            }
            if let kind = anchor {
                return "\(kind.claimedNoun.capitalizedFirst) logged and claimed."
            }
            return "Today's missions are logged and claimed."
        case .softExpiry:
            return "Today's mission is still open — \(target)."
        }
    }

    private var headerAccent: Color {
        if manager.allClaimedToday { return AppColor.brandBlue }
        if manager.isPastSoftExpiry { return .secondary }
        return AppColor.brandBlue
    }

    /// Right-edge status chip. Stays a small at-a-glance count so the
    /// coach voice headline can run long without losing the "N to go"
    /// scannable signal.
    private var headerStatusChip: String {
        if manager.allClaimedToday { return "All claimed" }
        if manager.isPastSoftExpiry {
            return "\(manager.unclaimedCount) before midnight"
        }
        return "\(manager.unclaimedCount) to go"
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
        if claimed {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColor.brandBlue)
        } else if ready {
            HStack(spacing: 4) {
                Text("Claim +\(kind.xpReward)")
                    .font(Typography.micro.weight(.bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColor.brandBlue, in: Capsule())
        } else {
            Text("+\(kind.xpReward) XP")
                .font(Typography.micro.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func rowAccent(claimed: Bool, ready: Bool, muted: Bool) -> Color {
        if claimed { return AppColor.brandBlue }
        if ready { return AppColor.brandBlue }
        if muted { return .secondary }
        return .secondary
    }

    private func rowAccessibilityLabel(kind: DailyChallengeKind, claimed: Bool, ready: Bool) -> String {
        if claimed { return "\(kind.title). Claimed." }
        if ready { return "\(kind.title). Ready to claim, \(kind.xpReward) XP." }
        return "\(kind.title). \(kind.subtitle) Worth \(kind.xpReward) XP."
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
            Text("+\(kind.xpReward) XP — \(kind.title)")
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

// MARK: - Coach-voice copy helpers
//
// These extensions live here (not in DailyChallenge.swift) because they're
// presentation-layer copy, not domain logic. Keeping the imperative target
// phrasing next to the tile that renders it makes both easier to revise.

extension DailyChallengeKind {
    /// Imperative target — drops into "Today's mission — \(targetPhrase)."
    /// Sentence-case, no trailing punctuation, no "you" (the wrapper line
    /// supplies the address).
    var targetPhrase: String {
        switch self {
        case .heldPause:        return "hold a 3 second pause cleanly"
        case .shortAnswer:      return "land a 14-word answer under 30 seconds with at most one filler"
        case .zeroFillers:      return "land a 14-word rep with zero fillers"
        case .sustainedAnswer:  return "hold a 60-second answer with at most three fillers"
        case .cleanSuddenDeath: return "clear a Sudden Death round with zero fillers"
        case .crispDelivery:    return "land a 130 to 155 WPM rep with at most two fillers"
        case .highScoreSession: return "land an 8 out of 10 session"
        case .multiplePauses:   return "use silence twice in one rep, no filler bridges"
        }
    }

    /// Noun phrase for the past-tense headline — drops into
    /// "\(claimedNoun.capitalizedFirst) logged. Tap to claim …" so the
    /// claim moment names what was earned. Lowercase, no article.
    var claimedNoun: String {
        switch self {
        case .heldPause:        return "hold"
        case .shortAnswer:      return "short answer"
        case .zeroFillers:      return "clean rep"
        case .sustainedAnswer:  return "long answer"
        case .cleanSuddenDeath: return "clean Sudden Death round"
        case .crispDelivery:    return "crisp rep"
        case .highScoreSession: return "8 out of 10 session"
        case .multiplePauses:   return "double-pause rep"
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
