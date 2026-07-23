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
    static func shouldRequestInsight(
        weeklyReps: Int,
        totalSessions: Int,
        contentMode: AIWeeklyInsightContentMode = .automatic,
        hasFirstWeekRead: Bool = false
    ) -> Bool {
        guard contentMode != .firstWeekOnly, !hasFirstWeekRead else { return false }
        return weeklyReps > 0 || totalSessions > 0
    }

    static func shouldRenderCard(weeklyReps: Int, totalSessions: Int, hasInsight: Bool) -> Bool {
        shouldRequestInsight(weeklyReps: weeklyReps, totalSessions: totalSessions) && hasInsight
    }
}

enum AIWeeklyInsightContentMode: Equatable {
    /// Preserve the existing behavior for non-Home call sites.
    case automatic
    /// Show only the rolling AI weekly narrative, even after Day 7. Home uses
    /// a separate compact first-week entry so the two reads do not duplicate.
    case rollingWeeklyOnly
    /// Dedicated first-week destination. Never substitutes a generic insight.
    case firstWeekOnly
}

/// Keeps the displayed proof identity aligned with the contract reference.
/// A referenced first-week example either resolves exactly or yields no quote;
/// the rolling weekly surface may still choose its own highest-scoring proof.
enum VerifiedExampleTranscriptResolver {
    static func session(
        referenceID: UUID?,
        allEligibleSessions: [PracticeSession],
        rollingWeeklySessions: [PracticeSession]
    ) -> PracticeSession? {
        if let referenceID {
            return allEligibleSessions.first {
                $0.id == referenceID && !$0.transcript.isEmpty
            }
        }
        return rollingWeeklySessions
            .filter { $0.score != nil && !$0.transcript.isEmpty }
            .max(by: { ($0.score ?? 0) < ($1.score ?? 0) })
    }
}

@available(iOS 17.0, macOS 12.0, *)
struct AIWeeklyInsightCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject var sessionStore: PracticeSessionStore
    @ObservedObject var ratingStore: RatingStore
    @ObservedObject var clutchWordStore: ClutchWordStore
    @ObservedObject var coachingProfileStore: CoachingProfileStore
    var contentMode: AIWeeklyInsightContentMode = .automatic

    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var streakFreezeManager = StreakFreezeManager.shared
    @StateObject private var pathProgress = PathProgressManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @StateObject private var checkInStore = CoachCheckInStore.shared

    @State private var insight: AIInsight?
    @State private var proof: ProofMoment?
    @State private var focusShift: FocusShiftEvent?
    @State private var isRefreshing = false
    @State private var hasAppeared = false
    @State private var didRequestInitialInsight = false
    @State private var didRequestInitialFirstWeekProof = false
    @State private var showsFirstWeekLimits = false

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
        return sessionStore.progressEligibleSessions.filter { $0.date >= cutoff }.count
    }

    private var accountRenderIdentity: String {
        [
            authManager.currentAccountID ?? "<signed-out>",
            String(authManager.accountLifecycleGeneration),
        ].joined(separator: "|")
    }

    private var firstWeekSnapshot: FirstWeekCoachingContract.Snapshot? {
        // Read the observed owners so a new prescription/check-in invalidates
        // this view, then delegate all account and evidence gates to the one
        // resolver shared with NotificationManager.
        _ = coachMemoryStore.currentMemory
        _ = checkInStore.checkIns
        return FirstWeekCoachingSnapshotResolver.current()
    }

    private var firstWeekRead: FirstWeekCoachingContract.FirstWeekReadProjection? {
        guard contentMode != .rollingWeeklyOnly else { return nil }
        return firstWeekSnapshot?.firstWeekRead
    }

    var body: some View {
        let shouldRequest = AIWeeklyInsightPresentation.shouldRequestInsight(
            weeklyReps: weeklyReps,
            totalSessions: sessionStore.progressEligibleSessionCount,
            contentMode: contentMode,
            hasFirstWeekRead: firstWeekRead != nil
        )
        Group {
            if let firstWeekRead {
                firstWeekCardShell(read: firstWeekRead)
                    .task { await requestInitialFirstWeekProofIfNeeded() }
            } else if contentMode == .firstWeekOnly {
                firstWeekUnavailableCard
            } else if !shouldRequest {
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
        .onChange(of: accountRenderIdentity) { _, _ in
            insight = nil
            proof = nil
            focusShift = nil
            isRefreshing = false
            hasAppeared = false
            didRequestInitialInsight = false
            didRequestInitialFirstWeekProof = false
        }
    }

    private func firstWeekCardShell(
        read: FirstWeekCoachingContract.FirstWeekReadProjection
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your first week", systemImage: "text.book.closed")
                .font(Typography.cardTitle)
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Divider().padding(.vertical, 2)
            firstWeekReadContent(read)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .opacity(hasAppeared ? 1 : 0)
        .onAppear {
            guard !hasAppeared else { return }
            recordFirstWeekReadViewedIfNeeded()
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.easeOut(duration: 0.2)) { hasAppeared = true }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("firstWeek.read.card")
    }

    private var firstWeekUnavailableCard: some View {
        ContentUnavailableView(
            "First-week read unavailable",
            systemImage: "text.book.closed",
            description: Text("Noum could not find an account-scoped first-week activation receipt.")
        )
        .accessibilityIdentifier("firstWeek.read.unavailable")
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
                if firstWeekRead != nil {
                    recordFirstWeekReadViewedIfNeeded()
                }
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
            if let firstWeekRead {
                firstWeekReadContent(firstWeekRead)
            } else {
            // Focus shift notice — one-sentence adaptation signal when
            // the coach's primary focus area shifted since the last
            // weekly window. Prepended so the user reads it before the
            // AI narrative. Only shown within the first 7 days of detection.
            if let shift = focusShift,
               Calendar.current.dateComponents([.day], from: shift.detectedAt, to: Date()).day ?? 8 <= 7 {
                Text("This week's focus has moved from \(shift.from.displayName.lowercased()) to \(shift.to.displayName.lowercased()).")
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
                Text("Verified example")
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(AppColor.pro.opacity(0.85))
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
            Text(firstWeekRead == nil ? "This week" : "Your first week")
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
            Text("Coach read")
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

    @ViewBuilder
    private func firstWeekReadContent(
        _ read: FirstWeekCoachingContract.FirstWeekReadProjection
    ) -> some View {
        firstWeekSection(
            title: "What changed",
            systemImage: "arrow.up.right",
            text: firstWeekChangeText(read.whatChanged)
        )

        Divider().padding(.vertical, 2)
        if let proof {
            proofSection(proof: proof)
        } else {
            firstWeekSection(
                title: "Verified example",
                systemImage: "quote.opening",
                text: "Noum does not yet have a transcript-grounded line it can safely show here."
            )
        }

        firstWeekSection(
            title: "Next week",
            systemImage: "arrow.right.circle.fill",
            text: firstWeekPlanText(read.nextWeekPlan)
        )

        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                showsFirstWeekLimits.toggle()
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(AppColor.pro)
                    .accessibilityHidden(true)
                Text("What still needs testing")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: showsFirstWeekLimits ? "chevron.up" : "chevron.down")
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(AppColor.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsFirstWeekLimits ? "Hide what still needs testing" : "Show what still needs testing")
        .accessibilityIdentifier("firstWeek.read.limits.toggle")

        if showsFirstWeekLimits {
            Text(read.remainsUnproven.map(firstWeekUnprovenText).joined(separator: " · "))
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
                .accessibilityIdentifier("firstWeek.read.limits")
        }
    }

    private func firstWeekSection(
        title: String,
        systemImage: String,
        text: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(AppColor.pro)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func firstWeekChangeText(
        _ change: FirstWeekCoachingContract.FirstWeekReadProjection.Change
    ) -> String {
        switch change {
        case .verifiedComparison(let trend):
            return trend.evidenceText
        case .notYetProven(let eligibleRepCount):
            let noun = eligibleRepCount == 1 ? "rep" : "reps"
            return "No qualified comparison yet · \(eligibleRepCount) eligible \(noun)"
        }
    }

    private func firstWeekUnprovenText(
        _ area: FirstWeekCoachingContract.FirstWeekReadProjection.UnprovenArea
    ) -> String {
        switch area {
        case .practiceChange: return "repeatable change in practice"
        case .realWorldOutcome: return "transfer to a real conversation"
        case .durability: return "whether it holds over time"
        }
    }

    private func firstWeekPlanText(
        _ plan: FirstWeekCoachingContract.FirstWeekReadProjection.NextWeekPlan
    ) -> String {
        let count = max(1, plan.remainingComparableRepsBeforeReview)
        let repText = count == 1 ? "one comparable rep" : "\(count) comparable reps"
        switch (plan.lever, plan.mode) {
        case let (lever?, mode?):
            return "Keep \(lever.displayName.lowercased()) as the lever in \(mode.displayLabel). Run \(repText), then review whether the pattern holds."
        case let (lever?, nil):
            return "Keep \(lever.displayName.lowercased()) as the lever. Run \(repText), then review whether the pattern holds."
        case let (nil, mode?):
            return "Use \(mode.displayLabel) for \(repText), then review before changing course."
        case (nil, nil):
            return "Run \(repText), then let the next qualified comparison choose the plan."
        }
    }

    private func recordFirstWeekReadViewedIfNeeded() {
        guard let snapshot = firstWeekSnapshot,
              snapshot.firstWeekRead != nil else { return }
        let correlationID = snapshot.activation.correlationID
            ?? snapshot.activation.sessionID
            ?? UUID()
        guard !FlowEventLog.shared.growthEvents().contains(where: {
            $0.name == .weeklyReadViewed && $0.correlationID == correlationID
        }) else { return }
        FlowEventGrowthEventSink.shared.record(
            GrowthEvent(
                correlationID: correlationID,
                name: .weeklyReadViewed,
                entryPoint: .home
            )
        )
    }

    // MARK: - Refresh

    private func requestInitialInsightIfNeeded() async {
        guard AIWeeklyInsightPresentation.shouldRequestInsight(
            weeklyReps: weeklyReps,
            totalSessions: sessionStore.progressEligibleSessionCount,
            contentMode: contentMode,
            hasFirstWeekRead: firstWeekRead != nil
        ) else { return }
        guard !didRequestInitialInsight else { return }
        didRequestInitialInsight = true
        await refresh()
    }

    /// The first-week destination needs its transcript-grounded proof but not
    /// the rolling weekly AI narrative. Keeping this as a separate task means
    /// that destination never incurs an unused narrative provider request.
    private func requestInitialFirstWeekProofIfNeeded() async {
        guard firstWeekRead != nil,
              !didRequestInitialFirstWeekProof else { return }
        didRequestInitialFirstWeekProof = true
        await refresh(requestNarrative: false)
    }

    private func refresh(
        force: Bool = false,
        requestNarrative: Bool = true
    ) async {
        let requestedAccountScope = authManager.currentAccountID
        let requestedAccountLifecycle = authManager.accountLifecycleGeneration
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekly = sessionStore.progressEligibleSessions.filter { $0.date >= cutoff }
        let topFiller = clutchWordStore.topClutchWords.first?.word
        let profile = coachingProfileStore.profile
        let goalParaphrase = profile?.displayableGoal
        let goalDistance = profile.map { baselineStore.baseline.distanceFromGoal($0.primaryGoal) }

        let input = requestNarrative
            ? AIInsightInput(
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
                voice: profile?.chosenStyleGoal
            )
            : nil

        isRefreshing = true
        if force, let input {
            await AIInsightsService.shared.invalidate(for: input)
        }
        let next: AIInsight?
        if let input {
            next = await AIInsightsService.shared.insight(for: input)
        } else {
            next = nil
        }
        guard !Task.isCancelled,
              authManager.currentAccountID == requestedAccountScope,
              authManager.accountLifecycleGeneration == requestedAccountLifecycle,
              authManager.initialAccountHydrationState == .ready else {
            isRefreshing = false
            return
        }

        // Proof of the week — pick the highest-scoring rated session
        // from the weekly window and extract a transcript-anchored
        // moment. Falls back to the deterministic template when no AI
        // provider is configured. Picking the best session (rather
        // than the most recent) makes the proof feel like a victory
        // lap, not a random sample. Skips entirely if no session has
        // a score (cold start or all-skipped reps).
        var nextProofResult: ProofMomentGenerationResult? = nil
        let proofWeekly = sessionStore.progressEligibleSessions.filter {
            $0.date >= cutoff
        }
        let proofProfile = coachingProfileStore.profile
        let proofBaseline = baselineStore.baseline
        let firstWeekExampleID = contentMode == .rollingWeeklyOnly
            ? nil
            : FirstWeekCoachingSnapshotResolver.current(now: Date())?
                .firstWeekRead?
                .verifiedExample?
                .sessionID
        // A first-week read names one exact evidence reference. If that
        // session has no renderable transcript, fail closed instead of
        // silently presenting another rep as the verified example.
        let bestSession = VerifiedExampleTranscriptResolver.session(
            referenceID: firstWeekExampleID,
            allEligibleSessions: sessionStore.progressEligibleSessions,
            rollingWeeklySessions: proofWeekly
        )
        if let session = bestSession {
            let proofInput = ProofMomentInput(
                session: session,
                voice: proofProfile?.chosenStyleGoal,
                goalParaphrase: proofProfile?.displayableGoal,
                baselineFillerRate: proofBaseline.fillerRate.confidence != .insufficient
                    ? proofBaseline.fillerRate.value : nil,
                baselinePace: proofBaseline.pace.confidence != .insufficient
                    ? proofBaseline.pace.value : nil
            )
            if let request = ProofMomentStore.shared.generationRequest(for: proofInput) {
                if force {
                    await ProofMomentService.shared.invalidate(sessionID: session.id)
                }
                nextProofResult = await ProofMomentService.shared.proof(for: request)
            }
        }

        guard !Task.isCancelled,
              authManager.currentAccountID == requestedAccountScope,
              authManager.accountLifecycleGeneration == requestedAccountLifecycle,
              authManager.initialAccountHydrationState == .ready else {
            isRefreshing = false
            return
        }

        // Focus shift detection — detect when the primary focus area has
        // changed since the last weekly window and store the event so the
        // card can prepend a one-sentence adaptation notice.
        var nextFocusShift: FocusShiftEvent? = nil
        if requestNarrative,
           let accountID = AuthManager.shared.currentAccountID {
            let snapshots = SkillTrendStore.shared.snapshots
            let trends = TrendAnalyzer.analyze(snapshots: snapshots)
            let recentDrills = Array(DrillHistoryStore.shared.entries.prefix(4))
            let currentFocus = TrendAnalyzer.primaryFocus(
                trends: trends,
                currentSessionSnapshot: snapshots.first,
                recentDrills: recentDrills,
                styleGoal: coachingProfileStore.profile?.chosenStyleGoal
            )
            nextFocusShift = PrimaryFocusMemory.detectShift(current: currentFocus, accountID: accountID)
        }

        await MainActor.run {
            guard !Task.isCancelled,
                  authManager.currentAccountID == requestedAccountScope,
                  authManager.accountLifecycleGeneration == requestedAccountLifecycle,
                  authManager.initialAccountHydrationState == .ready else {
                self.isRefreshing = false
                return
            }
            let nextProof = nextProofResult.flatMap { result in
                ProofMomentStore.shared.tokenIsCurrent(result.saveToken)
                    ? result.proof
                    : nil
            }
            let apply = {
                if requestNarrative {
                    self.insight = next
                }
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

/// Direct, durable destination used by the Day-7 notification and Home entry.
/// It reuses the same account-scoped resolver and read component as the weekly
/// surface, while bypassing rolling-week rep counts and AI availability.
@available(iOS 17.0, macOS 12.0, *)
struct FirstWeekReadDetailView: View {
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            AIWeeklyInsightCard(
                sessionStore: sessionStore,
                ratingStore: ratingStore,
                clutchWordStore: ClutchWordStore.shared,
                coachingProfileStore: coachingProfileStore,
                contentMode: .firstWeekOnly
            )
            .padding(.horizontal, Spacing.screenH)
            .padding(.vertical, Spacing.lg)
        }
        .background(AppColor.screenBackground.ignoresSafeArea())
        .navigationTitle("First-week read")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("firstWeek.read.detail")
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
