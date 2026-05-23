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
//   • Provenance honesty — a tiny "RULE-BASED" tag when the note is
//     deterministic so the user can tell when AI is actually
//     participating vs. when the template is standing in.
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
    @State private var insight: AIInsight?
    @State private var isLoadingInsight = false
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var streakFreezeManager = StreakFreezeManager.shared
    @StateObject private var clutchWordStore = ClutchWordStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                NoumCharacter.Inline(size: 22, mood: .coaching, tint: AppColor.pro)
                Text(headerLabel)
                    .font(Typography.captionSmall)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.pro)
                Spacer(minLength: 0)
                if !note.isAIBacked {
                    Text("RULE-BASED")
                        .font(Typography.captionSmall)
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .stroke(AppColor.textSecondary.opacity(0.35), lineWidth: 1)
                        )
                }
            }

            Text(note.noteText)
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // M25: deep-analysis reveal — the post-hoc AI insight that
            // used to live in a separate AISessionDebriefCard now folds
            // into this single coach-voice surface. One card = one
            // voice; expand on demand. Hidden when no session (preview
            // paths, share-card renders) or when AI is unavailable
            // (insight returns nil) since silence beats an empty reveal.
            if session != nil {
                deepAnalysisSection
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(AppColor.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(AppColor.pro.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: AppColor.pro.opacity(0.06), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Coach read of your rep")
    }

    @ViewBuilder
    private var deepAnalysisSection: some View {
        Divider()
            .opacity(0.4)
            .padding(.top, 4)
        Button {
            withAnimation(.standardSpring) { showDeepAnalysis.toggle() }
            if showDeepAnalysis, insight == nil, !isLoadingInsight {
                Task { await loadInsight() }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: showDeepAnalysis ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.bold))
                Text(showDeepAnalysis ? "Hide deep analysis" : "Deep analysis")
                    .font(Typography.caption.weight(.semibold))
                if showDeepAnalysis, insight?.isAIBacked == true {
                    Spacer(minLength: 6)
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.caption2.weight(.bold))
                        Text("AI")
                            .font(Typography.captionSmall)
                            .tracking(0.6)
                    }
                    .foregroundStyle(AppColor.pro)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColor.pro.opacity(0.10), in: Capsule())
                }
            }
            .foregroundStyle(AppColor.pro)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showDeepAnalysis ? "Hide deep analysis" : "Show deep analysis")

        if showDeepAnalysis {
            if isLoadingInsight && insight == nil {
                insightSkeleton
            } else if let insight {
                insightBody(insight)
            }
        }
    }

    @ViewBuilder
    private func insightBody(_ insight: AIInsight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var insightSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 18).frame(maxWidth: 220)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.10))
                .frame(height: 14).frame(maxWidth: .infinity)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.10))
                .frame(height: 14).frame(maxWidth: 260)
        }
        .accessibilityHidden(true)
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
            .recent(limit: 2)
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
        input.voice = profile?.speakingStyleGoal
        input.recentProofQuotes = proofQuotes
        let next = await AIInsightsService.shared.insight(for: input)
        await MainActor.run {
            withAnimation(.standardSpring) {
                insight = next
                isLoadingInsight = false
            }
        }
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
}

#endif
