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
    @StateObject private var masteryStore = ModeMasteryStore.shared
    @State private var cachedRecommendedMode: PracticeMode?
    /// Dynamic per-user "why this mode" line produced by the
    /// `RecommendationBiasEngine`. Falls back to the static
    /// `ModeOption.recommendedReason` when nil (cold start, no
    /// session history).
    @State private var cachedRecommendedReason: String?
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
                        lessonsCard
                        speechProjectsCard
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                // Bottom inset clears the floating Start CTA so the last
                // mode tile (Speech Projects) doesn't bleed under it. The
                // CTA is ~64pt tall with its own internal padding; leaving
                // 96pt here gives a clean visual gap at rest.
                .padding(.bottom, 96)
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
                .font(Typography.screenTitle)
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

                        let snapshot = masteryStore.snapshot(for: option.mode)
                        if snapshot.sessionsLogged > 0 {
                            ModeMasteryBadge(snapshot: snapshot)
                        }
                    }

                    Text(option.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    if isRecommended {
                        Text(cachedRecommendedReason ?? option.recommendedReason)
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

    // MARK: - Lessons Card

    /// Tappable entry point to the lessons catalog. Lessons teach a
    /// single technique (rule of three, anaphora, pause-instead-of-filler)
    /// in three short steps with engine-validated practice.
    private var lessonsCard: some View {
        Button {
            CoachHaptic.selectionTap()
            navigationPath.append(AppDestination.lessons)
        } label: {
            HStack(alignment: .top, spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(AppColor.brandBlue.opacity(0.14))
                        .frame(width: 52, height: 52)
                    Image(systemName: "books.vertical.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColor.brandBlue)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Lessons")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                        crownChip
                        Spacer(minLength: 0)
                    }
                    Text("Learn one technique at a time. Concept, then spot it, then say it. Earn crowns by repeat practice.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("practiceMode.lessons")
        .accessibilityLabel("Lessons")
        .accessibilityHint("Open the lessons catalog.")
    }

    /// Small crown count chip — shows the user's running total of crowns
    /// when they have any. Hides at zero to keep the card uncluttered for
    /// first-time users.
    @ViewBuilder
    private var crownChip: some View {
        let total = LessonStore.shared.totalCrowns
        if total > 0 {
            HStack(spacing: 3) {
                Image(systemName: "crown.fill")
                    .font(.caption2.weight(.bold))
                Text("\(total)")
                    .font(.caption2.weight(.bold).monospacedDigit())
            }
            .foregroundStyle(AppColor.brandBlue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppColor.brandBlue.opacity(0.10), in: Capsule())
        }
    }

    // MARK: - Speech Projects Card

    /// Tappable entry point to the structured speech-project catalog.
    /// Visually distinct from the four mode cards — projects are
    /// curated and prepared, not impromptu reps.
    private var speechProjectsCard: some View {
        Button {
            CoachHaptic.selectionTap()
            navigationPath.append(AppDestination.speechProjects)
        } label: {
            HStack(alignment: .top, spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(AppColor.pro.opacity(0.14))
                        .frame(width: 52, height: 52)
                    Image(systemName: "graduationcap.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColor.pro)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Speech projects")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    Text("Toastmasters-inspired prepared speeches with concrete objectives — Ice Breaker, Vocal Variety, Persuasive, Storytelling.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("practiceMode.speechProjects")
        .accessibilityLabel("Speech projects")
        .accessibilityHint("Browse structured prepared speeches with objectives.")
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
        // Background tightened from a 0.02 → 0.72 white gradient to a
        // solid screen-bg fade — the earlier opacity stop left content
        // bleeding through (Cut the Crutch's "60 seconds. 3 hearts, no
        // second chances." was visible under the CTA at rest scroll).
        // Gradient still fades in softly at the top edge so the CTA
        // doesn't read as a hard cut-line.
        .background(
            LinearGradient(
                colors: [AppColor.screenBackground.opacity(0), AppColor.screenBackground],
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
        // Prefer `whyNow` (the situational hook) over `whyMode` (the
        // mode-benefit), but fall back gracefully and ignore empty
        // strings so we never render a blank line.
        let dynamic = [blueprint.whyNow, blueprint.whyMode]
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        cachedRecommendedReason = dynamic
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
