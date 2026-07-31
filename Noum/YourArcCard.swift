#if canImport(SwiftUI)
import SwiftUI

// MARK: - Your Arc Card (Profile)
//
// A horizontal timeline that makes the user's progression LEGIBLE:
// Day 1  →  Today  →  Next landmark  →  Next chapter.
//
// Sits on Profile between the speakingRatingCard and the "Progression"
// cluster. Pillar 4 (Believable progress) made visual instead of inferred
// from the surrounding chart / peak-wall / mastery cards. The card never
// claims a "level up" — the markers reflect already-true state:
//   • Day 1 — the day of the user's first finished rep.
//   • Today — the current NoumCharacter.Stage (XP-derived, ratcheted).
//   • Next landmark — the title of the active path node (if any).
//   • Next chapter — the next NoumCharacter.Stage above the current one
//     (omitted on .mastery, which has no "next").
//
// State is read-only from the existing managers. No new stores, no new
// persistence, no new logic — this is composition. Coach copy comes from
// inline string builders that follow the spec's voice rules: no "Let's",
// no exclamations (the "Welcome." period is fine), no emoji.

@available(iOS 17.0, macOS 12.0, *)
struct YourArcCard: View {

    @StateObject private var profile = ProfileManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var pathProgress = PathProgressManager.shared
    @StateObject private var baselineStore = BaselineStore.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Animated scale of the "Today" marker. Reduce-motion pins to 1.0 so
    /// the pulse never fires. Otherwise drives a subtle 1.0 → 1.08 → 1.0
    /// autoreverse over 2s — the marker reads as "alive" without
    /// dominating the eye of the card.
    @State private var todayPulse: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            microHeader
            timeline
            coachVoiceRead
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(arcCardBackground)
        // Soft brand-blue elevation — paired register to the HomeCoachCard's
        // purple shadow so the two heroes feel like a family, not the same
        // card twice. The arc lives in the brand-blue (progression) register;
        // the home coach lives in the Pro-purple (premium / coaching)
        // register.
        .shadow(color: AppColor.brandBlue.opacity(0.16), radius: 18, x: 0, y: 8)
        .onAppear { startPulseIfAllowed() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("profile.yourArcCard")
    }

    // MARK: - Header

    private var microHeader: some View {
        HStack(spacing: Spacing.xs) {
            Text("Your arc")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
        }
    }

    // MARK: - Timeline
    //
    // The track + four markers laid out proportionally across a 280pt
    // width. We use a GeometryReader so the markers stay anchored to the
    // track even at different Dynamic Type sizes — labels expand below
    // the track without pushing the dots out of alignment.

    private var timeline: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let width = geo.size.width
                let trackY: CGFloat = 8
                ZStack {
                    // The track itself — a thin brand-blue line that
                    // anchors the four position markers. Faded to 0.15
                    // alpha so the markers + their labels carry the
                    // visual weight, not the line.
                    Capsule()
                        .fill(AppColor.brandBlue.opacity(0.15))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                        .position(x: width / 2, y: trackY)

                    ForEach(markers, id: \.id) { marker in
                        let x = max(marker.diameter / 2,
                                    min(width - marker.diameter / 2, width * marker.fraction))
                        markerDot(marker)
                            .position(x: x, y: trackY)
                    }
                }
            }
            .frame(height: 18)

            // Labels row — two-line label under each marker. Positioned
            // proportionally to the same fractions so they sit beneath
            // their dots. Top line is the position name ("Day 1"); the
            // bottom line is the stage / landmark name.
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .topLeading) {
                    ForEach(markers, id: \.id) { marker in
                        markerLabel(marker)
                            .frame(width: labelWidth, alignment: .center)
                            .position(
                                x: max(labelWidth / 2,
                                       min(width - labelWidth / 2, width * marker.fraction)),
                                y: 22
                            )
                    }
                }
            }
            .frame(height: 56)
        }
        // The card uses Spacing.lg padding; the spec asks for ~280pt of
        // track. The default screen-padded card on a 393pt-wide iPhone
        // gives the inner content ~313pt, so the track lands inside spec.
        // Cap to 280 on wider devices so the markers don't drift apart
        // and the labels stay grouped under their dots.
        .frame(maxWidth: 280)
        .frame(maxWidth: .infinity)
    }

    /// Constant width used to lay out each marker's two-line label. Wide
    /// enough to fit "Pause Beats" / "Next chapter" on two lines without
    /// crowding adjacent labels; narrow enough that four labels fit across
    /// a 280pt track.
    private let labelWidth: CGFloat = 68

    @ViewBuilder
    private func markerDot(_ marker: ArcMarker) -> some View {
        let diameter = marker.diameter
        let isToday = (marker.kind == .today)
        Group {
            switch marker.style {
            case .filled:
                Circle()
                    .fill(marker.color)
                    .frame(width: diameter, height: diameter)
            case .stroked:
                Circle()
                    .strokeBorder(marker.color, lineWidth: 1.5)
                    .frame(width: diameter, height: diameter)
            case .dotted:
                // Dotted stroke for the "Next chapter" marker — visually
                // softer than a solid hollow ring, signaling "further
                // out, not yet earned." StrokeStyle dash + a tiny
                // chamfered cap keeps it crisp on Retina.
                Circle()
                    .strokeBorder(
                        marker.color,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 2.5])
                    )
                    .frame(width: diameter, height: diameter)
            }
        }
        .scaleEffect(isToday ? todayPulse : 1.0)
        .animation(.easeInOut(duration: 0.2), value: todayPulse)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func markerLabel(_ marker: ArcMarker) -> some View {
        VStack(spacing: 2) {
            Text(marker.positionLabel)
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(marker.detailLabel)
                .font(Typography.captionSmall)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Coach voice read

    private var coachVoiceRead: some View {
        Text(coachVoiceText)
            .font(Typography.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("profile.yourArcCard.coachRead")
    }

    /// One-to-two sentence coach-voice read pulling: days since first
    /// session, count of trending-positive metrics, and a landmark clause
    /// if one applies. The variants follow the spec exactly — every line
    /// is declarative and the language never punish-shames or overclaims.
    private var coachVoiceText: String {
        // Cold start — no sessions captured yet.
        guard !sessionStore.sessions.isEmpty else {
            return "Welcome. The arc starts on your first rep."
        }

        // Fewer than three sessions — too early to claim a trend honestly.
        if sessionStore.sessions.count < 3 {
            return "Two reps in. Build a baseline and the arc starts to bend."
        }

        // Mastery edge — the user has reached the top stage. The arc
        // language becomes the work itself, not the climb.
        if currentStage == .mastery {
            return "Mastery. The work is its own arc now."
        }

        // Default — open with days since the first session, optionally
        // attach the trending-metric count, then a landmark clause.
        var pieces: [String] = []

        let days = daysSinceFirstSession
        if days >= 1 {
            pieces.append("Day \(days + 1) to here.")
        } else {
            pieces.append("Day 1 to here.")
        }

        let trending = improvingTrendCount
        if trending > 0 {
            let metric = trending == 1 ? "metric" : "metrics"
            pieces.append("\(trending) \(metric) moving the right way.")
        }

        pieces.append(landmarkClause)

        return pieces.joined(separator: " ")
    }

    /// Landmark clause — selects from three honest framings:
    ///   1. "One landmark from your next chapter." — when the current
    ///      path node is honestly within reach (same predicate as
    ///      `HomeCoachCard.landmarkWithinReach`).
    ///   2. "Next landmark: <title>." — when there's a current node but
    ///      it's not within reach yet.
    ///   3. "Stay on the run." — when the path is cleared or has no
    ///      current node.
    private var landmarkClause: String {
        if landmarkWithinReach {
            return "One step from your next chapter."
        }
        if let title = pathProgress.currentNode?.node.title, !title.isEmpty {
            return "Next step: \(title)."
        }
        return "Stay on the run."
    }

    /// Mirrors the "Landmark within reach" predicate in HomeCoachCard. We
    /// don't share the helper — the home file owns its own UI state — but
    /// the math is identical so the two surfaces agree on when a user is
    /// genuinely one step away.
    private var landmarkWithinReach: Bool {
        guard let status = pathProgress.currentNode, !status.isComplete else {
            return false
        }
        if status.progress >= 0.80 {
            return true
        }
        if status.progress > 0,
           let phrase = pathProgress.currentNodeGatingPhrase,
           phrase.hasPrefix("One ") {
            return true
        }
        return false
    }

    // MARK: - Background
    //
    // Brand-blue hero treatment — paired register to the HomeCoachCard's
    // purple. The brand-blue radial wash sits at the top-center, a faint
    // hairline traces the silhouette, and the surface stays white so the
    // markers + their labels read sharply at the body-text scale.

    @ViewBuilder
    private var arcCardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        ZStack {
            shape.fill(AppColor.cardBackground)

            // Brand-blue radial wash at 0.42 alpha — visible-at-rest per
            // the spec; sits behind the timeline so the markers carry the
            // foreground weight.
            shape.fill(
                RadialGradient(
                    colors: [
                        AppColor.brandBlue.opacity(0.42),
                        AppColor.brandBlueLight.opacity(0.18),
                        AppColor.brandBlue.opacity(0.03),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 320
                )
            )

            // Frosted glass — keeps the wash readable through a subtle
            // desaturation layer so the timeline doesn't sit on a pure
            // blue field. Mirrors the HomeCoachCard glass treatment so
            // the two heroes share a material language.
            shape.fill(.regularMaterial)
                .opacity(0.30)

            // Faint brand-blue hairline border — silhouette definition
            // against the screen background.
            shape.strokeBorder(AppColor.brandBlue.opacity(0.40), lineWidth: 1)
        }
    }

    // MARK: - Derived state

    /// Sessions are stored newest-first by PracticeSessionStore. The first
    /// finished rep is `.last`; `.first` would give today's most recent.
    private var firstSessionDate: Date? {
        sessionStore.sessions.last?.date
    }

    /// Days between the first finished rep and today. Returns 0 when
    /// there are no sessions — the cold-start coach line covers that
    /// branch before this value is read.
    private var daysSinceFirstSession: Int {
        guard let first = firstSessionDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: first, to: Date()).day ?? 0
        return max(0, days)
    }

    private var currentStage: NoumCharacter.Stage {
        NoumCharacter.Stage.current(xp: profile.xp)
    }

    /// The stage immediately above the current one, if any. Mastery has
    /// no "next" — `nil` collapses the fourth marker so the arc reads
    /// honestly (the user is at the top of the chapter ladder).
    private var nextStage: NoumCharacter.Stage? {
        let cases = NoumCharacter.Stage.allCases
        guard let index = cases.firstIndex(of: currentStage),
              index + 1 < cases.count else {
            return nil
        }
        return cases[index + 1]
    }

    /// Count of baseline stats whose trend is `.improving` in the latest
    /// snapshot. We read the full set of `BaselineStat` fields so the
    /// count reflects the user's whole surface area, not a curated slice.
    private var improvingTrendCount: Int {
        let baseline = baselineStore.baseline
        let stats: [BaselineStat] = [
            baseline.fillerRate,
            baseline.pace,
            baseline.paceVariance,
            baseline.durationTendency,
            baseline.pauseRate,
            baseline.pauseFilledRatio,
            baseline.openingStrength,
            baseline.closingStrength,
            baseline.structureQuality,
            baseline.answerDepth,
            baseline.clarity,
            baseline.vocabularyRange,
            baseline.hedgingRate,
            baseline.pitchVariation,
            baseline.averageScore
        ]
        return stats.reduce(0) { acc, stat in
            // Require reliable confidence so a one-rep "improving" read
            // doesn't inflate the count. Same restraint pattern used in
            // the baseline summary cards elsewhere in the app.
            (stat.isReliable && stat.trend == .improving) ? acc + 1 : acc
        }
    }

    // MARK: - Marker layout

    private struct ArcMarker {
        let id: String
        let kind: Kind
        let fraction: CGFloat
        let diameter: CGFloat
        let style: Style
        let color: Color
        let positionLabel: String
        let detailLabel: String

        enum Kind { case day1, today, nextLandmark, nextChapter }
        enum Style { case filled, stroked, dotted }
    }

    /// The ordered marker set rendered on the timeline. Filtered to drop
    /// the "Next chapter" marker on mastery (no next stage) — restraint
    /// over coverage, the arc never invents a fifth chapter.
    private var markers: [ArcMarker] {
        var out: [ArcMarker] = []

        out.append(
            ArcMarker(
                id: "day1",
                kind: .day1,
                fraction: 0.05,
                diameter: 12,
                style: .filled,
                color: AppColor.textSecondary.opacity(0.7),
                positionLabel: "Day 1",
                detailLabel: NoumCharacter.Stage.awakening.displayTitle
            )
        )

        out.append(
            ArcMarker(
                id: "today",
                kind: .today,
                fraction: 0.32,
                diameter: 14,
                style: .filled,
                color: AppColor.brandBlue,
                positionLabel: "Today",
                detailLabel: currentStage.displayTitle
            )
        )

        let landmarkTitle = pathProgress.currentNode?.node.title
        let landmarkLabel = landmarkTitle.flatMap { $0.isEmpty ? nil : $0 } ?? "Open road"
        out.append(
            ArcMarker(
                id: "nextLandmark",
                kind: .nextLandmark,
                fraction: 0.62,
                diameter: 12,
                style: .stroked,
                color: AppColor.brandBlue,
                positionLabel: "Next step",
                detailLabel: landmarkLabel
            )
        )

        if let next = nextStage {
            out.append(
                ArcMarker(
                    id: "nextChapter",
                    kind: .nextChapter,
                    fraction: 0.92,
                    diameter: 12,
                    style: .dotted,
                    color: AppColor.pro,
                    positionLabel: "Next chapter",
                    detailLabel: next.displayTitle
                )
            )
        }

        return out
    }

    // MARK: - Pulse lifecycle

    /// Kick off the subtle "Today" marker pulse on appear. The animation
    /// only runs when reduce-motion is OFF; otherwise the marker is
    /// static. The pulse is 1.0 → 1.08 → 1.0 on a 2s autoreverse loop —
    /// quiet, peripheral, not distracting.
    private func startPulseIfAllowed() {
        guard !reduceMotion else {
            todayPulse = 1.0
            return
        }
        // Reset before kicking off the loop so a re-appear doesn't
        // animate from a stale partial value.
        todayPulse = 1.0
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            todayPulse = 1.08
        }
    }

    // MARK: - Accessibility

    /// One-line VoiceOver summary that recites the arc in coach voice.
    /// We hide the individual dots (they're decorative) and lift the
    /// labels into this combined string so a screen reader hears the
    /// timeline as a narrative rather than four disconnected fragments.
    private var accessibilitySummary: String {
        var pieces: [String] = ["Your arc."]
        for marker in markers {
            pieces.append("\(marker.positionLabel): \(marker.detailLabel).")
        }
        pieces.append(coachVoiceText)
        return pieces.joined(separator: " ")
    }
}

// MARK: - Stage display titles
//
// One-word chapter labels used by the arc markers. We deliberately don't
// reuse `NoumCharacter.Stage.accessibilitySuffix` here — that string is
// phrased for VoiceOver inline narration ("settled in composure"), not
// for a column label. The display titles are the chapter names a user
// would read on the screen: "Awakening" / "Voice" / "Composure" / etc.
//
// Lives in this file (rather than in `NoumCharacterStage.swift`) because
// it's purely UI label copy used by this one surface. If a second card
// ever needs the same titles, lift into the Stage extension.

@available(iOS 17.0, macOS 12.0, *)
private extension NoumCharacter.Stage {
    var displayTitle: String {
        switch self {
        case .awakening: return "Awakening"
        case .voice:     return "Voice"
        case .composure: return "Composure"
        case .command:   return "Command"
        case .mastery:   return "Mastery"
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 12.0, *)
#Preview("Your Arc — Default") {
    ScrollView {
        VStack(spacing: Spacing.cardGap) {
            YourArcCard()
        }
        .padding(.horizontal, Spacing.screenH)
    }
    .background(AppColor.screenBackground.ignoresSafeArea())
}
#endif

#endif
