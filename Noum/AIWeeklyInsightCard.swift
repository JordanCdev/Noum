#if canImport(SwiftUI)
import SwiftUI

// MARK: - AI Weekly Insight Card
//
// Replaces the templated `WeeklyDigestCard` on home with an AI-driven
// narrative coaching read of the user's last 7 days. Falls back to a
// template-derived insight when no provider is configured — the card
// always renders something useful, the AI version is just sharper.
//
// Layout:
// - Headline (Figtree, large)
// - Body (Manrope, supporting paragraph)
// - Evidence pills (real numbers)
// - Action chip (if the model returned one)
// - "Coach mark" — small chip showing whether this is AI- or
//   template-generated. Honest signal so we never overclaim.

@available(iOS 17.0, macOS 12.0, *)
struct AIWeeklyInsightCard: View {
    @ObservedObject var sessionStore: PracticeSessionStore
    @ObservedObject var ratingStore: RatingStore
    @ObservedObject var clutchWordStore: ClutchWordStore
    @ObservedObject var coachingProfileStore: CoachingProfileStore

    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var streakFreezeManager = StreakFreezeManager.shared

    @State private var insight: AIInsight?
    @State private var isRefreshing = false
    @State private var hasAppeared = false

    private var weeklyReps: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessionStore.sessions.filter { $0.date >= cutoff }.count
    }

    var body: some View {
        if weeklyReps == 0 && sessionStore.sessions.isEmpty {
            EmptyView()
        } else {
            cardContent
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.lg)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .stroke(Color.white.opacity(0.72), lineWidth: 1)
                )
                .scaleEffect(hasAppeared ? 1 : 0.97)
                .opacity(hasAppeared ? 1 : 0)
                .onAppear {
                    withAnimation(.standardSpring.delay(0.05)) { hasAppeared = true }
                    Task { await refresh() }
                }
                .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        let insight = insight ?? AIInsight.placeholder
        VStack(alignment: .leading, spacing: 12) {
            header(insight: insight)
            Text(insight.headline)
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(insight.body)
                .font(Typography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if !insight.evidence.isEmpty {
                evidencePills(insight: insight)
            }
            if let action = insight.action {
                actionChip(text: action)
            }
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
            Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .symbolEffect(.rotate, options: .repeating, isActive: isRefreshing)
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

    private func refresh(force: Bool = false) async {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekly = sessionStore.sessions.filter { $0.date >= cutoff }
        let topFiller = clutchWordStore.topClutchWords.first?.word
        let goalParaphrase = coachingProfileStore.profile?.displayableGoal

        let input = AIInsightInput(
            kind: .weeklyNarrative,
            sessions: weekly,
            baseline: baselineStore.baseline,
            rating: ratingStore.rating,
            weeklyDelta: ratingStore.rating.weeklyDelta,
            weeklyReps: weekly.count,
            topFillerWord: topFiller,
            goalParaphrase: goalParaphrase,
            currentStreak: streakFreezeManager.currentStreak
        )

        isRefreshing = true
        if force {
            await AIInsightsService.shared.invalidate(for: input)
        }
        let next = await AIInsightsService.shared.insight(for: input)
        await MainActor.run {
            withAnimation(.standardSpring) {
                self.insight = next
            }
            self.isRefreshing = false
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
