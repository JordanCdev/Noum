#if canImport(SwiftUI)
import SwiftUI

// MARK: - AI Weekly Insight Card
//
// Replaces the templated `WeeklyDigestCard` on home with a narrative
// coaching read of the user's last 7 days. Falls back through
// `AIInsightsService` when no provider is configured. The view does not
// render placeholder insight copy while that service result is pending.
//
// Layout:
// - Headline (Figtree, large)
// - Body (Manrope, supporting paragraph)
// - Evidence pills (real numbers)
// - Action chip (if the model returned one)
// - "Coach mark" — small chip showing whether this is AI- or
//   template-generated. Honest signal so we never overclaim.

enum AIWeeklyInsightPresentation {
    static func shouldRequestInsight(weeklyReps: Int, totalSessions: Int) -> Bool {
        weeklyReps > 0 || totalSessions > 0
    }

    static func shouldRenderCard(weeklyReps: Int, totalSessions: Int, hasInsight: Bool) -> Bool {
        shouldRequestInsight(weeklyReps: weeklyReps, totalSessions: totalSessions) && hasInsight
    }
}

@available(iOS 17.0, macOS 12.0, *)
struct AIWeeklyInsightCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject var sessionStore: PracticeSessionStore
    @ObservedObject var ratingStore: RatingStore
    @ObservedObject var clutchWordStore: ClutchWordStore
    @ObservedObject var coachingProfileStore: CoachingProfileStore

    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var streakFreezeManager = StreakFreezeManager.shared
    @StateObject private var pathProgress = PathProgressManager.shared

    @State private var insight: AIInsight?
    @State private var proof: ProofMoment?
    @State private var focusShift: FocusShiftEvent?
    @State private var isRefreshing = false
    @State private var hasAppeared = false
    @State private var didRequestInitialInsight = false

    /// Chapter eyebrow for the headline. Mirrors the Home journey
    /// card's "Chapter · <tier>" — the chapter the user is *currently
    /// traveling through on the path*, not their rating tier. These
    /// can disagree (rating may be Gold while the path-node is still
    /// in the Bronze section), and the journey is the canonical story
    /// register. Falls back to the rating tier only if no current
    /// path node (cleared or pre-rating cold start).
    private var chapterEyebrow: String? {
        if let nodeTier = pathProgress.currentNode?.node.tier.title {
            return "Chapter \u{00B7} \(nodeTier)"
        }
        guard ratingStore.rating.totalRatedSessions > 0 else { return nil }
        let tier = LeagueTier.tier(for: ratingStore.rating.overall)
        return "Chapter \u{00B7} \(tier.title)"
    }

    private var weeklyReps: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessionStore.sessions.filter { $0.date >= cutoff }.count
    }

    var body: some View {
        let shouldRequest = AIWeeklyInsightPresentation.shouldRequestInsight(
            weeklyReps: weeklyReps,
            totalSessions: sessionStore.sessions.count
        )
        if !shouldRequest {
            EmptyView()
        } else if let insight {
            cardShell(insight: insight)
        } else {
            Color.clear
                .frame(height: 0)
                .accessibilityHidden(true)
                .task { await requestInitialInsightIfNeeded() }
        }
    }

    private func cardShell(insight: AIInsight) -> some View {
        cardContent(insight: insight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .scaleEffect(reduceMotion || hasAppeared ? 1 : 0.97)
            .opacity(hasAppeared ? 1 : 0)
            .onAppear {
                guard !hasAppeared else { return }
                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.standardSpring.delay(0.05)) { hasAppeared = true }
                }
            }
            .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func cardContent(insight: AIInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header(insight: insight)
            // Focus shift notice — one-sentence adaptation signal when
            // the coach's primary focus area shifted since the last
            // weekly window. Prepended so the user reads it before the
            // AI narrative. Only shown within the first 7 days of detection.
            if let shift = focusShift,
               Calendar.current.dateComponents([.day], from: shift.detectedAt, to: Date()).day ?? 8 <= 7 {
                Text("Your \(shift.from.displayName.lowercased()) is now stable. This week's focus shifts to \(shift.to.displayName.lowercased()).")
                    .font(Typography.caption.weight(.medium))
                    .foregroundStyle(AppColor.pro)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Focus shift: from \(shift.from.displayName) to \(shift.to.displayName)")
            }
            // Chapter eyebrow — when there's a current path landmark, the
            // weekly insight reads "Chapter · <Tier>" above the headline,
            // tying the AI read into the story register the rest of the
            // app uses ("YOUR JOURNEY · Chapter · Bronze" on the journey
            // card, "Chapter X — Landmark reached." on the celebration).
            if let chapter = chapterEyebrow {
                Text(chapter)
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(AppColor.pro.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
            Text(insight.headline)
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            // Body trimmed to 2 lines + tail-truncation so the home
            // card stays compact. Tap-to-expand lives on the card if
            // the caller adds it; for the home surface we lean
            // toward "headline + short body" and trust the AI debrief
            // detail view for the long form. Evidence chips and the
            // action chip are also gated behind ≥3 sessions of
            // signal so we never show a triple-stack of supporting
            // content when the headline alone is the story.
            Text(insight.body)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
            if let action = insight.action {
                actionChip(text: action)
            }
            // Proof of the week — transcript-anchored evidence that
            // the user actually demonstrated a goal-aligned move this
            // week. Goes BELOW the AI body so the narrative reads
            // first; the proof line is the receipt the narrative
            // hangs on. Collapses entirely if no proof could be
            // extracted (cold start, no qualifying session, no
            // baseline yet).
            if let proof = proof {
                Divider().padding(.vertical, 4)
                proofSection(proof: proof)
            }
        }
    }

    /// Compact proof block: tiny eyebrow + technique chip + quote +
    /// claim line. Mirrors the brand-purple coach register from the
    /// Ask Noum surface so the user reads "this is the coach
    /// speaking, not metrics."
    private func proofSection(proof: ProofMoment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.pro)
                Text("Proof of the week")
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(AppColor.pro.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer(minLength: 0)
                Text(proof.technique)
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(AppColor.pro)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColor.pro.opacity(0.10), in: Capsule())
            }
            Text("\u{201C}\(proof.quote)\u{201D}")
                .font(Typography.body.italic())
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(proof.claim)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func header(insight: AIInsight) -> some View {
        HStack(spacing: 8) {
            Image(systemName: insight.kind.symbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
            Text("This week")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            coachMark(isAIBacked: insight.isAIBacked)
            refreshButton
        }
    }

    private func coachMark(isAIBacked: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isAIBacked ? "sparkles" : "doc.plaintext")
                .font(.caption2.weight(.bold))
            Text(isAIBacked ? "AI" : "Live")
                .font(Typography.micro)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .foregroundStyle(isAIBacked ? AppColor.brandBlue : .secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            (isAIBacked ? AppColor.brandBlue : Color.secondary).opacity(0.10),
            in: Capsule()
        )
        .accessibilityHidden(true)
    }

    private var refreshButton: some View {
        Button {
            Task { await refresh(force: true) }
        } label: {
            ZStack {
                Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .modifier(RefreshSpinModifier(isActive: isRefreshing, reduceMotion: reduceMotion))
            }
        }
        .accessibilityLabel("Refresh weekly insight")
        .disabled(isRefreshing)
    }

    private func evidencePills(insight: AIInsight) -> some View {
        FlowLayout(spacing: 6, runSpacing: 6) {
            ForEach(insight.evidence, id: \.self) { line in
                Text(line)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColor.tagBackground, in: Capsule())
            }
        }
    }

    private func actionChip(text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
            Text(text)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColor.brandBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }

    // MARK: - Refresh

    private func requestInitialInsightIfNeeded() async {
        guard !didRequestInitialInsight else { return }
        didRequestInitialInsight = true
        await refresh()
    }

    private func refresh(force: Bool = false) async {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekly = sessionStore.sessions.filter { $0.date >= cutoff }
        let topFiller = clutchWordStore.topClutchWords.first?.word
        let profile = coachingProfileStore.profile
        let goalParaphrase = profile?.displayableGoal
        let goalDistance = profile.map { baselineStore.baseline.distanceFromGoal($0.primaryGoal) }

        let input = AIInsightInput(
            kind: .weeklyNarrative,
            sessions: weekly,
            baseline: baselineStore.baseline,
            rating: ratingStore.rating,
            weeklyDelta: ratingStore.rating.weeklyDelta,
            weeklyReps: weekly.count,
            topFillerWord: topFiller,
            goalParaphrase: goalParaphrase,
            currentStreak: streakFreezeManager.currentStreak,
            goalDistance: goalDistance,
            voice: profile?.speakingStyleGoal
        )

        isRefreshing = true
        if force {
            await AIInsightsService.shared.invalidate(for: input)
        }
        let next = await AIInsightsService.shared.insight(for: input)

        // Proof of the week — pick the highest-scoring rated session
        // from the weekly window and extract a transcript-anchored
        // moment. Falls back to the deterministic template when no AI
        // provider is configured. Picking the best session (rather
        // than the most recent) makes the proof feel like a victory
        // lap, not a random sample. Skips entirely if no session has
        // a score (cold start or all-skipped reps).
        var nextProof: ProofMoment? = nil
        let bestSession = weekly
            .filter { $0.score != nil && !$0.transcript.isEmpty }
            .max(by: { ($0.score ?? 0) < ($1.score ?? 0) })
        if let session = bestSession {
            let proofInput = ProofMomentInput(
                session: session,
                voice: profile?.speakingStyleGoal,
                goalParaphrase: goalParaphrase,
                baselineFillerRate: baselineStore.baseline.fillerRate.confidence != .insufficient
                    ? baselineStore.baseline.fillerRate.value : nil,
                baselinePace: baselineStore.baseline.pace.confidence != .insufficient
                    ? baselineStore.baseline.pace.value : nil
            )
            if force {
                await ProofMomentService.shared.invalidate(sessionID: session.id)
            }
            nextProof = await ProofMomentService.shared.proof(for: proofInput)
        }

        // Focus shift detection — detect when the primary focus area has
        // changed since the last weekly window and store the event so the
        // card can prepend a one-sentence adaptation notice.
        var nextFocusShift: FocusShiftEvent? = nil
        if let accountID = AuthManager.shared.currentAccountID {
            let snapshots = SkillTrendStore.shared.snapshots
            let trends = TrendAnalyzer.analyze(snapshots: snapshots)
            let recentDrills = Array(DrillHistoryStore.shared.entries.prefix(4))
            let currentFocus = TrendAnalyzer.primaryFocus(
                trends: trends,
                currentSessionSnapshot: snapshots.first,
                recentDrills: recentDrills,
                styleGoal: profile?.speakingStyleGoal
            )
            nextFocusShift = PrimaryFocusMemory.detectShift(current: currentFocus, accountID: accountID)
        }

        await MainActor.run {
            let apply = {
                self.insight = next
                self.proof = nextProof
                if nextFocusShift != nil {
                    self.focusShift = nextFocusShift
                }
            }
            if reduceMotion { apply() }
            else {
                withAnimation(.standardSpring, apply)
            }
            self.isRefreshing = false
        }
    }
}

// MARK: - Refresh spin

/// iOS 17-compatible rotating spinner for the refresh chip. Uses a
/// continuous rotation animation under iOS 17 and the native
/// `.symbolEffect(.rotate)` on iOS 18+ where it's available.
@available(iOS 17.0, *)
private struct RefreshSpinModifier: ViewModifier {
    let isActive: Bool
    let reduceMotion: Bool
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else if #available(iOS 18.0, *) {
            content.symbolEffect(.rotate, options: .repeating, isActive: isActive)
        } else {
            content
                .rotationEffect(.degrees(angle))
                .onChange(of: isActive) { _, newValue in
                    if newValue {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            angle = 360
                        }
                    } else {
                        angle = 0
                    }
                }
        }
    }
}

// MARK: - Flow layout (iOS 16+, but we run on iOS 17+ minimum)

/// Tiny wrap-around layout for evidence pills. Falls back to a single line
/// if items fit; wraps onto subsequent rows otherwise. Keeps the card
/// honest at any width.
@available(iOS 16.0, macOS 13.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var runSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let arranged = arrange(subviews: subviews, in: width)
        return CGSize(width: arranged.width, height: arranged.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arranged = arrange(subviews: subviews, in: bounds.width)
        for (index, frame) in arranged.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(subviews: Subviews, in maxWidth: CGFloat) -> (frames: [CGRect], width: CGFloat, height: CGFloat) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + runSpacing
                x = 0
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxRowWidth = max(maxRowWidth, x - spacing)
        }
        return (frames, maxRowWidth, y + rowHeight)
    }
}

#endif
