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
    @Binding var navigationPath: NavigationPath
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var hapticsSettings = HapticsSettings.shared
    @State private var cachedRecommendedMode: PracticeMode?
    /// When true, the picker has the Cut the Crutch tile selected.
    /// Tracked separately because Cut the Crutch isn't a `PracticeMode` —
    /// it's a sibling drill, not a pressure mode.
    @State private var crutchSelected: Bool = false

    private struct CrutchOption {
        let title: String = "Cut the Crutch"
        let subtitle: String = "Avoid one specific word for 60 seconds. 3 hearts, no second chances."
        let systemImage: String = "scissors"
        var tint: Color { AppColor.modeCrutch }
    }

    private let crutchOption = CrutchOption()

    // MARK: - Mode Options

    private struct ModeOption: Identifiable {
        let mode: PracticeMode
        let title: String
        let subtitle: String
        let systemImage: String
        let tint: Color
        /// Pre-baked single line shown only when this mode is the recommended pick.
        /// Never user-derived — designed to read on-voice for any speaker.
        let recommendedReason: String
        var id: PracticeMode { mode }
    }

    private var options: [ModeOption] {
        [
            ModeOption(
                mode: .timed,
                title: "Timed Practice",
                subtitle: "Build a full answer with structure and a soft clock.",
                systemImage: "clock.fill",
                tint: AppColor.modeTimed,
                recommendedReason: "Helps when your answers end early."
            ),
            ModeOption(
                mode: .suddenDeath,
                title: "Sudden Death",
                subtitle: "Stay alive without a single filler word.",
                systemImage: "bolt.fill",
                tint: AppColor.modeSuddenDeath,
                recommendedReason: "Sharpens composure under live pressure."
            ),
            ModeOption(
                mode: .ahCounter,
                title: "Ah-Counter",
                subtitle: "Speak freely while Noum tracks fillers and pacing.",
                systemImage: "waveform.and.mic",
                tint: AppColor.modeAhCounter,
                recommendedReason: "Cleans openings and steadies rhythm."
            )
        ] + (IMModeAvailability.isAvailable ? [
            ModeOption(
                mode: .imConversation,
                title: "IM Mode",
                subtitle: "Live conversation reps with tone and pressure control.",
                systemImage: "message.badge.waveform.fill",
                tint: AppColor.modeIM,
                recommendedReason: "Trains realistic social or work pressure."
            )
        ] : [])
    }

    private var recommendedMode: PracticeMode {
        cachedRecommendedMode ?? .timed
    }

    private var primaryOption: ModeOption {
        options.first(where: { $0.mode == selectedMode }) ?? options[0]
    }

    private var activeStartTitle: String {
        crutchSelected ? crutchOption.title : primaryOption.title
    }

    private var activeStartTint: Color {
        crutchSelected ? crutchOption.tint : primaryOption.tint
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    headerCopy

                    VStack(spacing: Spacing.cardGap) {
                        ForEach(options) { option in
                            modeCard(option)
                        }
                        crutchCard
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("practiceModes.screen")
        .safeAreaInset(edge: .bottom) {
            startCTA
        }
        .task {
            computeRecommendation()
            if options.contains(where: { $0.mode == recommendedMode }) {
                selectedMode = recommendedMode
            }
        }
    }

    // MARK: - Header

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pick your next rep")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Each mode trains a different kind of pressure.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Mode Card

    private func modeCard(_ option: ModeOption) -> some View {
        let isSelected = !crutchSelected && selectedMode == option.mode
        let isRecommended = option.mode == recommendedMode

        return Button {
            withAnimation(.snappySpring) {
                selectedMode = option.mode
                crutchSelected = false
            }
            CoachHaptic.selectionTap()
        } label: {
            HStack(alignment: .top, spacing: Spacing.md) {
                modeIcon(option)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(option.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)

                        if isRecommended {
                            recommendedPill(tint: option.tint)
                        }

                        Spacer(minLength: 0)
                    }

                    Text(option.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    if isRecommended {
                        Text(option.recommendedReason)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(option.tint)
                            .padding(.top, 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? option.tint : Color.secondary.opacity(0.4))
                    .accessibilityHidden(true)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(
                        isSelected ? option.tint.opacity(0.32) : Color.white.opacity(0.72),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? option.tint.opacity(0.10) : .clear,
                radius: 16,
                y: 8
            )
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.selection, trigger: isSelected) { _, _ in hapticsSettings.isEnabled }
        .accessibilityIdentifier("practiceMode.\(option.mode.rawValue)")
        .accessibilityLabel(accessibilityLabel(option, isRecommended: isRecommended))
        .accessibilityHint(option.subtitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func modeIcon(_ option: ModeOption) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(option.tint.opacity(0.14))
                .frame(width: 52, height: 52)

            Image(systemName: option.systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(option.tint)
        }
        .accessibilityHidden(true)
    }

    private func recommendedPill(tint: Color) -> some View {
        Text("Recommended")
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
            .accessibilityHidden(true)
    }

    private func accessibilityLabel(_ option: ModeOption, isRecommended: Bool) -> String {
        isRecommended ? "\(option.title), recommended" : option.title
    }

    // MARK: - Cut the Crutch Card

    private var crutchCard: some View {
        let isSelected = crutchSelected
        let tint = crutchOption.tint

        return Button {
            withAnimation(.snappySpring) {
                crutchSelected = true
            }
            CoachHaptic.selectionTap()
        } label: {
            HStack(alignment: .top, spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 52, height: 52)
                    Image(systemName: crutchOption.systemImage)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(tint)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(crutchOption.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    Text(crutchOption.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? tint : Color.secondary.opacity(0.4))
                    .accessibilityHidden(true)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(
                        isSelected ? tint.opacity(0.32) : Color.white.opacity(0.72),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? tint.opacity(0.10) : .clear,
                radius: 16,
                y: 8
            )
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.selection, trigger: isSelected) { _, _ in hapticsSettings.isEnabled }
        .accessibilityIdentifier("practiceMode.cutTheCrutch")
        .accessibilityLabel(crutchOption.title)
        .accessibilityHint(crutchOption.subtitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Bottom CTA

    private var startCTA: some View {
        let title = activeStartTitle
        let tint = activeStartTint
        return Button {
            if crutchSelected {
                navigationPath.append(AppDestination.cutTheCrutchPractice)
            } else {
                navigationPath.append(appDestination(for: selectedMode))
            }
        } label: {
            Text("Start \(title.lowercased())")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(tint, in: Capsule())
                .padding(.horizontal, Spacing.screenH)
                .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("practiceModes.start")
        .accessibilityLabel("Start \(title)")
        .accessibilityHint("Begins a \(title) rep.")
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.02), Color.white.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Recommendation Engine

    private func computeRecommendation() {
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
    }

    private func appDestination(for mode: PracticeMode) -> AppDestination {
        switch mode {
        case .timed:
            return .timedPractice
        case .suddenDeath:
            return .suddenDeathPractice
        case .ahCounter:
            return .ahCounterPractice
        case .imConversation:
            if IMModeAvailability.isAvailable {
                return .imPractice(scenario: nil, tone: nil)
            } else {
                return .timedPractice
            }
        }
    }

    // MARK: - Recent-session signals (feed RecommendationBiasEngine)

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
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, *)
#Preview("Mode picker — default") {
    NavigationStack {
        PracticeModeSelectionView(
            selectedMode: .constant(.timed),
            navigationPath: .constant(NavigationPath())
        )
    }
}

@available(iOS 17.0, *)
#Preview("Mode picker — Sudden Death selected") {
    NavigationStack {
        PracticeModeSelectionView(
            selectedMode: .constant(.suddenDeath),
            navigationPath: .constant(NavigationPath())
        )
    }
}
#endif
#endif
