import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum PracticeMode: String, Codable {
    case timed
    case suddenDeath
    case ahCounter
    case imConversation
}

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct PracticeModeSelectionView: View {
    @Binding var selectedMode: PracticeMode
    var goHome: (() -> Void)?
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @State private var highlightedMode: PracticeMode?
    @State private var cachedRecommendedMode: PracticeMode?
    @State private var cachedRetentionSnapshot: RetentionLoopSnapshot?

    private struct ModeOption: Identifiable {
        let mode: PracticeMode
        let title: String
        let subtitle: String
        let systemImage: String
        let tint: Color
        let outcome: String
        let challengeFit: String

        var id: PracticeMode { mode }
    }

    private var options: [ModeOption] {
        [
            ModeOption(
                mode: .timed,
                title: "Timed Practice",
                subtitle: "Choose a difficulty, take a beat, and build a full answer with structure.",
                systemImage: "clock.fill",
                tint: AppColor.modeTimed,
                outcome: "Best for fuller, cleaner complete answers.",
                challengeFit: "Helps when your answers end early or lose structure."
            ),
            ModeOption(
                mode: .suddenDeath,
                title: "Sudden Death",
                subtitle: "Start immediately and stay alive without a single filler word.",
                systemImage: "bolt.fill",
                tint: AppColor.modeSuddenDeath,
                outcome: "Best for pressure tolerance and quick thinking.",
                challengeFit: "Strong when you freeze or want sharper composure on the spot."
            ),
            ModeOption(
                mode: .ahCounter,
                title: "Ah-Counter",
                subtitle: "Speak freely while Noum tracks fillers and pacing in real time.",
                systemImage: "waveform.and.mic",
                tint: AppColor.modeAhCounter,
                outcome: "Best for reducing fillers and calming rushed delivery.",
                challengeFit: "Strong when you need cleaner openings and steadier rhythm."
            )
        ] + (IMModeAvailability.isAvailable ? [
            ModeOption(
                mode: .imConversation,
                title: "IM Mode",
                subtitle: "Train tone, pacing, realism, and relationship impact inside a live conversation.",
                systemImage: "message.badge.waveform.fill",
                tint: AppColor.modeIM,
                outcome: "Best for real-world communication and tone control.",
                challengeFit: "Strong when you want realistic social, work, or pressure reps."
            )
        ] : [])
    }

    private var recommendedMode: PracticeMode {
        cachedRecommendedMode ?? .timed
    }

    private var recommendedOption: ModeOption? {
        options.first(where: { $0.mode == recommendedMode })
    }

    private var retentionSnapshot: RetentionLoopSnapshot {
        cachedRetentionSnapshot ?? RetentionLoopSnapshot(
            activeChallenge: PracticeChallengeStatus(
                title: "", summary: "", progress: 0, progressLabel: "", rewardLabel: ""
            ),
            achievements: [],
            motivationLine: ""
        )
    }

    private var primaryCTAOption: ModeOption {
        options.first(where: { $0.mode == selectedMode }) ?? options[0]
    }

    private var recommendationHeadline: String {
        let goal = (coachingProfileStore.profile?.communicationNorthStar ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if goal.isEmpty {
            return "Pick the rep that moves your communication forward fastest."
        }
        return "Built around your goal to \(goal.lowercased())."
    }

    /// Compute expensive recommendations once, not on every body evaluation
    private func computeRecommendations() {
        let plan = CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)
        let identity = PracticeEvaluator.speakingIdentity(
            for: sessionStore.sessions.first?.transcript ?? "",
            profile: coachingProfileStore.profile
        )
        let blueprint = RecommendationBiasEngine.blueprint(
            profile: coachingProfileStore.profile,
            input: AIHomeRecommendationInput(
                recentSessionSummary: recentSessionSummary,
                averageFillers: averageFillers,
                averageDuration: averageDuration,
                averageWordsPerMinute: averagePace,
                fillerTrendDelta: 0,
                durationTrendDelta: 0,
                paceTrendDelta: 0,
                averageWordCount: averageWordCount,
                strongestMode: plan?.strongestMode,
                currentIdentity: identity.identity,
                currentIdentityEvidence: identity.evidence,
                styleAlignmentScore: 0,
                sessionStreak: sessionStreak,
                daysSinceLastSession: daysSinceLastSession,
                preferredModeBias: "",
                preferredToneBias: "",
                preferredScenarioBias: "",
                modeBenefitBias: ""
            ),
            plan: plan
        )
        cachedRecommendedMode = blueprint.recommendedMode
        cachedRetentionSnapshot = RetentionLoopEngine.snapshot(
            sessions: sessionStore.sessions,
            profile: coachingProfileStore.profile
        )
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    headerCard

                    if let recommendedOption {
                        featuredRecommendationCard(recommendedOption)
                    }

                    momentumContextCard

                    VStack(alignment: .leading, spacing: 12) {
                        Text("All Drills")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("Choose a different drill if you want to target one specific weakness.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(options) { option in
                            practiceModeCard(option)
                        }
                    }

                    Spacer(minLength: 10)
                }
                .padding(Spacing.lg)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("practiceModes.screen")
        .safeAreaInset(edge: .bottom) {
            bottomCTA
        }
        .task {
            computeRecommendations()
            highlightedMode = recommendedMode
            if options.contains(where: { $0.mode == recommendedMode }) {
                selectedMode = recommendedMode
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose your next rep")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Each mode trains a different kind of pressure. Noum is already leaning toward what will help most right now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                PulseBadge(systemImage: "figure.mind.and.body", tint: .blue)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(recommendationHeadline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(retentionSnapshot.motivationLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var momentumContextCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Active challenge")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(retentionSnapshot.activeChallenge.title)
                    .font(.headline)
                Text(retentionSnapshot.activeChallenge.progressLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                ShimmerProgressBar(progress: retentionSnapshot.activeChallenge.progress, tint: .blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Reward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(retentionSnapshot.activeChallenge.rewardLabel)
                    .font(.headline)
                Text("Pick the right drill to progress faster.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SparkleRibbon(tint: .orange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.lg)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.blue.opacity(0.12), lineWidth: 1)
        )
    }

    private var bottomCTA: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                PulseBadge(systemImage: primaryCTAOption.systemImage, tint: primaryCTAOption.tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text(primaryCTAOption.title)
                        .font(.headline)
                    Text(primaryCTAOption.outcome)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                NavigationLink {
                    destinationView(for: selectedMode)
                } label: {
                    Text("Start")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, Spacing.md)
                        .background(primaryCTAOption.tint, in: Capsule())
                }
                .accessibilityIdentifier("practiceModes.start")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, Spacing.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.02),
                    Color.white.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func featuredRecommendationCard(_ option: ModeOption) -> some View {
        Button {
            withAnimation(.standardSpring) {
                selectedMode = option.mode
                highlightedMode = option.mode
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    PulseBadge(systemImage: option.systemImage, tint: option.tint)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recommended next")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(option.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(option.outcome)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(recommendationHeadline)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Best fit")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(option.tint)
                        SparkleRibbon(tint: option.tint)
                    }
                }

                ShimmerProgressBar(progress: 0.74, tint: option.tint)

                VStack(alignment: .leading, spacing: 6) {
                    Text(option.challengeFit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("This is the fastest drill to move your current challenge without losing momentum.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(option.tint.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func practiceModeCard(_ option: ModeOption) -> some View {
        let isSelected = selectedMode == option.mode
        return Button {
            withAnimation(.snappySpring) {
                selectedMode = option.mode
                highlightedMode = option.mode
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    if highlightedMode == option.mode {
                        PulseBadge(systemImage: option.systemImage, tint: option.tint)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                .fill(option.tint.opacity(0.14))
                                .frame(width: 54, height: 54)
                            Image(systemName: option.systemImage)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(option.tint)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(option.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if option.mode == recommendedMode {
                                Text("Smart pick")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(option.tint)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(option.tint.opacity(0.10), in: Capsule())
                            }
                        }
                        Text(option.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? option.tint : .secondary)
                }

                if isSelected {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(option.outcome)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(option.tint)
                            Spacer()
                            SparkleRibbon(tint: option.tint)
                        }
                        Text(option.challengeFit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ShimmerProgressBar(progress: option.mode == recommendedMode ? 0.72 : 0.54, tint: option.tint)
                        Text(option.mode == recommendedMode ? "This lines up with your current momentum and coaching goal." : "Use this when you want to deliberately train a narrower weakness.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(Spacing.lg)
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(isSelected ? option.tint.opacity(0.26) : Color.white.opacity(0.72), lineWidth: 1)
            )
            .shadow(color: isSelected ? option.tint.opacity(0.10) : .clear, radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practiceMode.\(option.mode.rawValue)")
    }

    @ViewBuilder
    private func destinationView(for mode: PracticeMode) -> some View {
        switch mode {
        case .timed:
            TimedPracticeView(goHome: goHome)
        case .suddenDeath:
            SuddenDeathPracticeView(goHome: goHome)
        case .ahCounter:
            AhCounterView(goHome: goHome)
        case .imConversation:
            if IMModeAvailability.isAvailable {
                IMPracticeView(goHome: goHome)
            } else {
                TimedPracticeView(goHome: goHome)
            }
        }
    }

    private var recentSessionSummary: String {
        let recent = sessionStore.sessions.prefix(4)
        guard !recent.isEmpty else { return "No recent sessions yet." }
        return recent.map { session in
            return "\(session.mode.displayLabel): \(session.fillerWordCount) fillers, \(Int(session.duration))s"
        }.joined(separator: " • ")
    }

    private var averageFillers: Double {
        let recent = Array(sessionStore.sessions.prefix(5))
        guard !recent.isEmpty else { return 0 }
        return Double(recent.map(\.fillerWordCount).reduce(0, +)) / Double(recent.count)
    }

    private var averageDuration: Double {
        let recent = Array(sessionStore.sessions.prefix(5))
        guard !recent.isEmpty else { return 0 }
        return recent.map(\.duration).reduce(0, +) / Double(recent.count)
    }

    private var averagePace: Double {
        let recent = Array(sessionStore.sessions.prefix(5))
        guard !recent.isEmpty else { return 0 }
        return Double(recent.map(\.wordsPerMinute).reduce(0, +)) / Double(recent.count)
    }

    private var averageWordCount: Double {
        let recent = Array(sessionStore.sessions.prefix(5))
        guard !recent.isEmpty else { return 0 }
        return Double(recent.map(\.wordCount).reduce(0, +)) / Double(recent.count)
    }

    private var sessionStreak: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(sessionStore.sessions.map { calendar.startOfDay(for: $0.date) })
        guard !uniqueDays.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        while uniqueDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }

    private var daysSinceLastSession: Int {
        guard let last = sessionStore.sessions.first?.date else { return 99 }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last), to: Calendar.current.startOfDay(for: Date())).day ?? 0
    }

    // currentIdentity and currentIdentityEvidence are now computed
    // once inside computeRecommendations() to avoid redundant calls
}
#endif
