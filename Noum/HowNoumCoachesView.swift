#if canImport(SwiftUI)
import SwiftUI

struct CoachingTrustPrinciple: Identifiable, Equatable {
    let id: String
    let symbol: String
    let title: String
    let body: String
}

enum HowNoumCoachesCopy {
    static let title = "How Noum coaches"
    static let headline = "The communication coach that only tells you what it can prove."
    static let introduction = "Noum builds a working read from your practice, then changes the plan as the evidence changes."

    static let principles: [CoachingTrustPrinciple] = [
        CoachingTrustPrinciple(
            id: "quotes",
            symbol: "quote.opening",
            title: "Your words are the evidence",
            body: "When Noum quotes you, the words come from a saved rep. It does not invent an example to make feedback sound specific."
        ),
        CoachingTrustPrinciple(
            id: "uncertainty",
            symbol: "scope",
            title: "Early reads stay tentative",
            body: "One rep can suggest a useful next move. Repeated comparable reps are required before Noum calls something a pattern."
        ),
        CoachingTrustPrinciple(
            id: "adaptation",
            symbol: "arrow.triangle.2.circlepath",
            title: "The plan can change",
            body: "Noum compares the rep you were prescribed with what happened next. It can reinforce, vary, or replace the exercise."
        ),
        CoachingTrustPrinciple(
            id: "transfer",
            symbol: "arrow.up.forward.app",
            title: "Practice is not the final claim",
            body: "A higher practice score is not proof that a meeting or interview improved. Real-world check-ins stay separate from practice evidence."
        ),
        CoachingTrustPrinciple(
            id: "privacy",
            symbol: "lock.shield",
            title: "You control the coaching memory",
            body: "You can inspect, correct, export, or delete saved coaching context. Noum never publishes your transcript to a leaderboard."
        ),
    ]

    static let limitationTitle = "What Noum cannot know"
    static let limitationBody = "Noum cannot read motives, diagnose a personality, guarantee an outcome, or replace the judgment of a qualified human coach. Camera-based cues are never treated as proof of an inner state."
}

@available(iOS 17.0, macOS 12.0, *)
struct HowNoumCoachesView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                hero

                ForEach(HowNoumCoachesCopy.principles) { principle in
                    principleCard(principle)
                }

                limitationCard
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg * 2)
        }
        .background(AppColor.screenBackground.ignoresSafeArea())
        .navigationTitle(HowNoumCoachesCopy.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("howNoumCoaches.screen")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("EVIDENCE-LED COACHING")
                .font(Typography.micro.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(AppColor.pro)
            Text(HowNoumCoachesCopy.headline)
                .font(Typography.figtree(size: 30, weight: .bold, relativeTo: .title))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(HowNoumCoachesCopy.introduction)
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColor.pro.opacity(0.11), AppColor.brandBlue.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(AppColor.pro.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func principleCard(_ principle: CoachingTrustPrinciple) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: principle.symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
                .frame(width: 40, height: 40)
                .background(AppColor.brandBlue.opacity(0.09), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(principle.title)
                    .font(Typography.headline)
                    .foregroundStyle(AppColor.textPrimary)
                Text(principle.body)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("howNoumCoaches.principle.\(principle.id)")
    }

    private var limitationCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(HowNoumCoachesCopy.limitationTitle, systemImage: "exclamationmark.shield")
                .font(Typography.headline)
                .foregroundStyle(AppColor.textPrimary)
            Text(HowNoumCoachesCopy.limitationBody)
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.innerSurface,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("howNoumCoaches.limitations")
    }
}
#endif
