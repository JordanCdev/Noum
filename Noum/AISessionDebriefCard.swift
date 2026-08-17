#if canImport(SwiftUI)
import SwiftUI

// MARK: - AI Session Debrief Card
//
// Post-session card that uses `AIInsightsService` to surface a narrative
// read of *this specific rep* — what just changed, why it matters, and
// what to do next. Falls back to template when no provider is configured.
//
// Shown on the summary screen between CoachNoteCard and the eloquence
// findings. Loads asynchronously with a skeleton state so it never blocks
// the rest of the summary.

@available(iOS 17.0, macOS 12.0, *)
struct AISessionDebriefCard: View {
    let session: PracticeSession?
    let recentSessions: [PracticeSession]

    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var streakFreezeManager = StreakFreezeManager.shared
    @StateObject private var clutchWordStore = ClutchWordStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var aiSettings = AISettingsManager.shared

    @State private var insight: AIInsight?
    @State private var isLoading: Bool = true

    var body: some View {
        if session == nil {
            EmptyView()
        } else {
            HStack(alignment: .top, spacing: 12) {
                // A scope identifies coach interpretation without repeating
                // the live-audio waveform or reintroducing a mascot.
                NoumSemanticGraphic(role: .coachRead, tint: AppColor.brandBlue, size: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    header
                    if isLoading && insight == nil {
                        skeleton
                    } else if let insight {
                        bodyContent(insight: insight)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .task(id: session?.id) {
                await refresh()
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 8) {
            Text("Coach read")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            if let insight {
                coachMark(isAIBacked: insight.isAIBacked)
            }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Coach read")
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 20)
                .frame(maxWidth: 220)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.10))
                .frame(height: 14)
                .frame(maxWidth: .infinity)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.10))
                .frame(height: 14)
                .frame(maxWidth: 280)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func bodyContent(insight: AIInsight) -> some View {
        Text(insight.headline)
            .font(Typography.headline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
        Text(insight.body)
            .font(Typography.body)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)

        if !insight.evidence.isEmpty {
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

        if let action = insight.action {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.caption.weight(.bold))
                Text(action)
                    .font(Typography.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(AppColor.brandBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColor.brandBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        }
    }

    // MARK: - Refresh

    private func refresh() async {
        guard let session else { return }
        isLoading = true
        var sessions = recentSessions
        if !sessions.contains(where: { $0.id == session.id }) {
            sessions.insert(session, at: 0)
        }
        let topFiller = clutchWordStore.topClutchWords.first?.word
        let profile = coachingProfileStore.profile
        let goalParaphrase = profile?.displayableGoal
        let goalDistance = profile.map { baselineStore.baseline.distanceFromGoal($0.primaryGoal) }
        let input = AIInsightInput(
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
            goalDistance: goalDistance,
            voice: profile?.chosenStyleGoal
        )
        let next: AIInsight
        if aiSettings.isCloudProcessingAllowed {
            next = await AIInsightsService.shared.insight(for: input)
        } else {
            next = AIInsightsService.templatedFallback(for: input)
        }
        await MainActor.run {
            withAnimation(.standardSpring) {
                insight = next
                isLoading = false
            }
        }
    }
}

#endif
