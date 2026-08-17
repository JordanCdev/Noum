#if canImport(SwiftUI)
import SwiftUI

// MARK: - CoachReadCard
//
// Hero coach voice for the post-rep Summary surface. Renders the
// `PostRepCoachNote` produced by `PostRepCoachNoteService` — a short,
// 2-sentence voice-shaped read of THIS rep, in the user's chosen
// voice register. The card is purposefully restrained:
//
//   • One paragraph of the coach's actual words. No metrics duplicated
//     (the HeroScoreCard already carries those). The note is the
//     coach turning toward the user and saying "here's what I just saw."
//   • Brand-purple register (per the M14 home-card design language:
//     purple = "your coach speaking", mode-tint = "this is what to do").
//   • Provenance honesty — evidence and source stay inspectable behind one
//     disclosure, so trust detail is available without cluttering the read.
//   • No emoji, no exclamation, no chirpy filler. The note text
//     itself is contract-locked by `PostRepCoachNoteService.passes-
//     BrandVoiceContract` for the AI path; the deterministic path is
//     hard-coded brand-voice-clean.
//
// The card collapses to nothing (returns EmptyView) when no note is
// available — non-IM modes without finalized data shouldn't render
// the card at all rather than show a placeholder.

@available(iOS 17.0, *)
struct CoachReadCard: View {

    let note: PostRepCoachNote
    /// Session under review. Optional — when nil, the deep-analysis
    /// reveal is hidden (no insight to fetch).
    var session: PracticeSession? = nil
    /// Recent sessions feed the AIInsight context window. Pass the
    /// same `Array(sessionStore.sessions.prefix(5))` AISessionDebriefCard
    /// used to consume.
    var recentSessions: [PracticeSession] = []

    @State private var showDeepAnalysis = false
    @State private var showEvidenceDetails = false
    @State private var insight: AIInsight?
    @State private var isLoadingInsight = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var streakFreezeManager = StreakFreezeManager.shared
    @StateObject private var clutchWordStore = ClutchWordStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    /// Observed so the daily-budget hint refreshes mid-view when the
    /// limiter's `changeToken` bumps — i.e. when a rep elsewhere
    /// consumes the AI-polish budget while this card is visible (the
    /// AI-upgrade pass on a still-mounted summary card, a deferred
    /// rep finalize landing while the user is still reading the
    /// previous summary, or a deletion from "Clear all data" while
    /// the card is rendered).
    @StateObject private var rateLimiter = AIRateLimiter.shared
    /// Observed so the daily-budget hint refreshes mid-view when the
    /// user upgrades to Pro from the paywall sheet that
    /// `SummaryView` presents on top of this card (see
    /// `SummaryView.swift` `.sheet(isPresented: $showPaywall)`). The
    /// paywall is a sheet, not a navigation push — when the purchase
    /// completes and the sheet dismisses, the underlying CoachReadCard
    /// stays mounted. Without this observer the hint reads the stale
    /// pre-upgrade cap (12) until the user navigates away and
    /// re-enters; with it, the body recomputes immediately so the cap
    /// reads 40 and the ratio drops below the show-threshold the same
    /// turn the purchase lands.
    ///
    /// The dependency is also true at the cascade level — `SummaryView`
    /// re-renders on the same publication and would propagate down —
    /// but making it explicit here keeps the read-side honesty
    /// contract on this card self-contained (a future `Equatable`
    /// optimization on the parent, or a refactor that hoists the
    /// CoachReadCard out of the SummaryView subtree, can't silently
    /// re-introduce the stale read).
    @StateObject private var premium = PremiumManager.shared
    /// Read at body recomputation time. The post-rep coach note runs
    /// synchronously at finalize, so by the time SummaryView mounts
    /// the consumption has happened and this read is fresh. Re-
    /// rendered whenever the rate limiter publishes a `changeToken`
    /// bump — see `rateLimiter` above.
    private var dailyCoachNoteRemaining: Int {
        rateLimiter.remainingToday(kind: .postRepCoachNote)
    }
    private var dailyCoachNoteCap: Int {
        rateLimiter.currentCap()
    }

    var body: some View {
        NoumSurface(.standard) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    NoumSemanticGraphic(
                        role: .coachRead,
                        tint: AppColor.coachAccent,
                        size: 28
                    )
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(headerLabel)
                            .font(Typography.captionSmall.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(AppColor.proText)
                        Text("One useful read from this rep")
                            .font(Typography.captionSmall)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }

                Text(note.noteText)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

            // Daily-budget hint — only when the AI-backed coach voice
            // is participating AND remaining-today is at or below 25%
            // of cap. Mirrors AISettingsManager.isApproachingLimit's
            // ≥90%-used pattern but on the daily-cap axis. Rendered as
            // a quiet caption so the user has an honest read on "your
            // coach is going rule-based after the next few reps today"
            // before it actually happens. Skipped when the note is
            // already rule-based (the source disclosure owns that story)
            // and when budget is healthy.
                if shouldShowDailyBudgetHint {
                    Text(dailyBudgetHintCopy)
                        .font(Typography.captionSmall)
                        .foregroundStyle(AppColor.textSecondary)
                        .accessibilityLabel(dailyBudgetHintCopy)
                }

            // M25: deep-analysis reveal — the post-hoc AI insight that
            // used to live in a separate AISessionDebriefCard now folds
            // into this single coach-voice surface. One card = one
            // voice; expand on demand. Hidden when no session (preview
            // paths, share-card renders) or when AI is unavailable
            // (insight returns nil) since silence beats an empty reveal.
                if session != nil {
                    deepAnalysisSection
                }

                evidenceAndSourceSection
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Coach read of your rep")
    }

    @ViewBuilder
    private var deepAnalysisSection: some View {
        Divider()
            .overlay(AppColor.subtleBorder)

        Button {
            withAnimation(
                NoumMotion.animation(for: .calm, reduceMotion: reduceMotion)
            ) {
                showDeepAnalysis.toggle()
            }
            if showDeepAnalysis, insight == nil, !isLoadingInsight {
                Task { await loadInsight() }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "scope")
                    .font(Typography.captionSmall.weight(.semibold))
                    .accessibilityHidden(true)
                Text(showDeepAnalysis ? "Hide why this move" : "Why this move")
                    .font(Typography.caption.weight(.semibold))
                Spacer(minLength: Spacing.xs)
                Image(systemName: showDeepAnalysis ? "chevron.up" : "chevron.down")
                    .font(Typography.captionSmall.weight(.bold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(AppColor.proText)
            .frame(maxWidth: .infinity, minHeight: NoumControlMetric.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showDeepAnalysis ? "Hide why this coaching move" : "Show why this coaching move")
        .accessibilityIdentifier("coachRead.whyMove")

        if showDeepAnalysis {
            if isLoadingInsight && insight == nil {
                insightLoadingState
            } else if let insight {
                insightBody(insight)
            }
        }
    }

    @ViewBuilder
    private func insightBody(_ insight: AIInsight) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(insight.headline)
                .font(Typography.headline)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(insight.body)
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let action = insight.action {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "mic")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.proText)
                        .frame(width: 20)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("NEXT REP")
                            .font(Typography.micro.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(AppColor.textTertiary)
                        Text(action)
                            .font(Typography.body.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    AppColor.proQuietSurface,
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Next rep. \(action)")
            }
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private var evidenceAndSourceSection: some View {
        Button {
            withAnimation(
                NoumMotion.animation(for: .calm, reduceMotion: reduceMotion)
            ) {
                showEvidenceDetails.toggle()
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "lock.shield")
                    .font(Typography.captionSmall.weight(.semibold))
                    .accessibilityHidden(true)
                Text(showEvidenceDetails ? "Hide evidence and source" : "Evidence and source")
                    .font(Typography.caption.weight(.semibold))
                Spacer(minLength: Spacing.xs)
                Image(systemName: showEvidenceDetails ? "chevron.up" : "chevron.down")
                    .font(Typography.captionSmall.weight(.bold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(AppColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: NoumControlMetric.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("coachRead.evidenceSource")

        if showEvidenceDetails {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                sourceRow(
                    title: "Coach note",
                    detail: Self.noteSourceDescription(isAIBacked: note.isAIBacked)
                )

                if let insight {
                    sourceRow(
                        title: "Supporting read",
                        detail: Self.insightSourceDescription(isAIBacked: insight.isAIBacked)
                    )

                    ForEach(insight.evidence, id: \.self) { line in
                        Label(line, systemImage: "checkmark.circle")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppColor.innerSurface,
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .transition(.opacity)
        }
    }

    private func sourceRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title.uppercased())
                .font(Typography.micro.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(AppColor.textTertiary)
            Text(detail)
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var insightLoadingState: some View {
        HStack(spacing: Spacing.sm) {
            NoumSemanticGraphic(
                role: .progressTrajectory,
                tint: AppColor.coachAccent,
                size: 24
            )
            .accessibilityHidden(true)
            Text("Reviewing this rep with your recent practice…")
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reviewing this rep with your recent practice")
    }

    private func loadInsight() async {
        guard let session else { return }
        await MainActor.run { isLoadingInsight = true }
        var sessions = recentSessions
        if !sessions.contains(where: { $0.id == session.id }) {
            sessions.insert(session, at: 0)
        }
        let topFiller = clutchWordStore.topClutchWords.first?.word
        let profile = coachingProfileStore.profile
        let goalParaphrase = profile?.displayableGoal
        let goalDistance = profile.map { baselineStore.baseline.distanceFromGoal($0.primaryGoal) }
        let proofQuotes = ProofMomentStore.shared
            .recent(limit: 2, compatibleWith: profile?.chosenStyleGoal)
            .map { $0.proof.quote }
            .filter { !$0.isEmpty }
        var input = AIInsightInput(
            kind: .sessionDebrief,
            sessions: sessions,
            baseline: baselineStore.baseline,
            rating: ratingStore.rating,
            weeklyDelta: ratingStore.rating.weeklyDelta,
            weeklyReps: sessions.filter {
                $0.date >= (Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date())
            }.count,
            topFillerWord: topFiller,
            goalParaphrase: goalParaphrase,
            currentStreak: streakFreezeManager.currentStreak,
            goalDistance: goalDistance
        )
        input.voice = profile?.chosenStyleGoal
        input.recentProofQuotes = proofQuotes
        let next = await AIInsightsService.shared.insight(for: input)
        await MainActor.run {
            withAnimation(
                NoumMotion.animation(for: .calm, reduceMotion: reduceMotion)
            ) {
                insight = next
                isLoadingInsight = false
            }
        }
    }

    static func noteSourceDescription(isAIBacked: Bool) -> String {
        if isAIBacked {
            return "AI-polished from this rep after evidence and quote checks."
        }
        return "Rule-based from qualified signals in this rep; no AI wording was used."
    }

    static func insightSourceDescription(isAIBacked: Bool) -> String {
        if isAIBacked {
            return "AI-written from saved recent practice, baseline, and your selected coaching goal."
        }
        return "Rule-based from saved recent practice, baseline, and your selected coaching goal."
    }

    private var headerLabel: String {
        switch note.voice {
        case .authoritative: return "COACH READ"
        case .warm: return "FROM YOUR COACH"
        case .concise: return "COACH NOTE"
        case .persuasive: return "COACH BRIEFING"
        case .executive: return "COACH BRIEF"
        case .storytelling: return "COACH READ"
        case .none: return "COACH NOTE"
        }
    }

    // MARK: - Daily budget hint

    /// Show the daily-budget hint when the AI-backed coach voice is
    /// participating AND remaining-today is at or below
    /// `dailyBudgetHintThresholdRatio` of the cap. The cap is the
    /// active tier's cap (`AIRateLimiter.currentCap()` reads premium
    /// vs free at call time), so a mid-day Pro upgrade widens the
    /// budget and — because this view observes `PremiumManager` —
    /// the threshold recomputes the same body turn, hiding the hint
    /// the moment the wider cap pulls the ratio back below the bar.
    private var shouldShowDailyBudgetHint: Bool {
        CoachReadCard.shouldShowDailyBudgetHint(
            noteIsAIBacked: note.isAIBacked,
            cap: dailyCoachNoteCap,
            remaining: dailyCoachNoteRemaining
        )
    }

    /// Pure-function form of the threshold predicate so the contract
    /// can be locked by tests without standing up a real `AIRateLimiter`
    /// + `PremiumManager`. The math is:
    ///   • Rule-based notes → false (the `RULE-BASED` tag tells the
    ///     story instead; the hint would be a second voice saying the
    ///     same thing).
    ///   • Cap ≤ 0 → false (defensive — no honest "remaining" read
    ///     exists, so silence is the right caption).
    ///   • Else: `used / cap >= dailyBudgetHintThresholdRatio`.
    /// The tier-change contract that round 23 protects: at cap=12
    /// with used=10 the ratio is ~0.83 (hint shown); after a Pro
    /// upgrade widens cap to 40 the ratio is 0.25 (hint hidden) the
    /// same body turn, never after re-mount.
    static func shouldShowDailyBudgetHint(
        noteIsAIBacked: Bool,
        cap: Int,
        remaining: Int
    ) -> Bool {
        guard noteIsAIBacked else { return false }
        guard cap > 0 else { return false }
        let clampedRemaining = max(0, min(cap, remaining))
        let used = cap - clampedRemaining
        let ratio = Double(used) / Double(cap)
        return ratio >= dailyBudgetHintThresholdRatio
    }

    private var dailyBudgetHintCopy: String {
        CoachReadCard.dailyBudgetHintCopy(remaining: dailyCoachNoteRemaining)
    }

    /// Threshold at which the daily-budget hint starts showing. Set
    /// at 75% used (≥25% of the cap consumed below this triggers the
    /// quiet caption) — mirrors the spirit of
    /// `AISettingsManager.usageAwarenessThreshold` (0.9) but tuned
    /// lower because the daily cap is smaller (12/40 vs 20/100
    /// monthly) so the user notices the budget earlier in the day.
    static let dailyBudgetHintThresholdRatio: Double = 0.75

    /// Pure-function copy generator so the hint string can be locked
    /// by tests. Brand-voice compliant: no exclamations, no
    /// "running out" framing, no fake urgency. Tells the user what
    /// the number is and what happens when it lands on 0.
    static func dailyBudgetHintCopy(remaining: Int) -> String {
        let clamped = max(0, remaining)
        switch clamped {
        case 0:
            return "Simpler coach notes today. Personalized wording resumes tomorrow."
        case 1:
            return "1 AI coach note remaining today."
        default:
            return "\(clamped) AI coach notes remaining today."
        }
    }
}

#endif
