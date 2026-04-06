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
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @State private var highlightedMode: PracticeMode?

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
                tint: Color(red: 0.20, green: 0.47, blue: 0.96),
                outcome: "Best for fuller, cleaner complete answers.",
                challengeFit: "Helps when your answers end early or lose structure."
            ),
            ModeOption(
                mode: .suddenDeath,
                title: "Sudden Death",
                subtitle: "Start immediately and stay alive without a single filler word.",
                systemImage: "bolt.fill",
                tint: Color(red: 0.95, green: 0.55, blue: 0.15),
                outcome: "Best for pressure tolerance and quick thinking.",
                challengeFit: "Strong when you freeze or want sharper composure on the spot."
            ),
            ModeOption(
                mode: .ahCounter,
                title: "Ah-Counter",
                subtitle: "Speak freely while Noum tracks fillers and pacing in real time.",
                systemImage: "waveform.and.mic",
                tint: Color(red: 0.14, green: 0.60, blue: 0.44),
                outcome: "Best for reducing fillers and calming rushed delivery.",
                challengeFit: "Strong when you need cleaner openings and steadier rhythm."
            )
        ] + (IMModeAvailability.isAvailable ? [
            ModeOption(
                mode: .imConversation,
                title: "IM Mode",
                subtitle: "Train tone, pacing, realism, and relationship impact inside a live conversation.",
                systemImage: "message.badge.waveform.fill",
                tint: Color(red: 0.32, green: 0.43, blue: 0.94),
                outcome: "Best for real-world communication and tone control.",
                challengeFit: "Strong when you want realistic social, work, or pressure reps."
            )
        ] : [])
    }

    private var recommendedMode: PracticeMode {
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
                strongestMode: CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)?.strongestMode,
                currentIdentity: currentIdentity,
                currentIdentityEvidence: currentIdentityEvidence,
                styleAlignmentScore: 0,
                sessionStreak: sessionStreak,
                daysSinceLastSession: daysSinceLastSession,
                preferredModeBias: "",
                preferredToneBias: "",
                preferredScenarioBias: "",
                modeBenefitBias: ""
            ),
            plan: CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)
        )
        return blueprint.recommendedMode
    }

    private var recommendedOption: ModeOption? {
        options.first(where: { $0.mode == recommendedMode })
    }

    private var retentionSnapshot: RetentionLoopSnapshot {
        RetentionLoopEngine.snapshot(
            sessions: sessionStore.sessions,
            profile: coachingProfileStore.profile
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

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
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
                .padding(20)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("practiceModes.screen")
        .safeAreaInset(edge: .bottom) {
            bottomCTA
        }
        .onAppear {
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
            .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        .padding(18)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
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
                        .padding(.vertical, 14)
                        .background(primaryCTAOption.tint, in: Capsule())
                }
                .accessibilityIdentifier("practiceModes.start")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
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
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
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
            .padding(18)
            .background(
                Color.white,
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(option.tint.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func practiceModeCard(_ option: ModeOption) -> some View {
        let isSelected = selectedMode == option.mode
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
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
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
            .padding(18)
            .background(
                Color.white,
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
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
            TimedPracticeView()
        case .suddenDeath:
            SuddenDeathPracticeView()
        case .ahCounter:
            AhCounterView()
        case .imConversation:
            if IMModeAvailability.isAvailable {
                IMPracticeView()
            } else {
                TimedPracticeView()
            }
        }
    }

    private var recentSessionSummary: String {
        let recent = sessionStore.sessions.prefix(4)
        guard !recent.isEmpty else { return "No recent sessions yet." }
        return recent.map { session in
            let modeLabel: String
            switch session.mode {
            case .timed: modeLabel = "Timed"
            case .suddenDeath: modeLabel = "Sudden Death"
            case .ahCounter: modeLabel = "Ah-Counter"
            case .imConversation: modeLabel = "IM"
            }
            return "\(modeLabel): \(session.fillerWordCount) fillers, \(Int(session.duration))s"
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

    private var currentIdentity: String {
        PracticeEvaluator.speakingIdentity(
            for: sessionStore.sessions.first?.transcript ?? "",
            profile: coachingProfileStore.profile
        ).identity
    }

    private var currentIdentityEvidence: String {
        PracticeEvaluator.speakingIdentity(
            for: sessionStore.sessions.first?.transcript ?? "",
            profile: coachingProfileStore.profile
        ).evidence
    }
}
#endif
