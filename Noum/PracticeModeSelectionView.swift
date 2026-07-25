import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum PracticeMode: String, Codable, Sendable {
    case timed
    case suddenDeath
    case ahCounter
    case imConversation
}

/// The 3-line "What this trains" copy that surfaces under a mode row
/// when the user taps the expand affordance. Kept on its own type so
/// `PracticeModeRowExpansionTests` can pin the contract: every mode has
/// a complete, coach-voice triple (no exclamation marks, no emoji,
/// specific duration in the rep-length line). Living next to
/// `PracticeMode` keeps the copy beside the enum it documents.
struct PracticeModeExpansionCopy {
    let pressureType: String
    let surfaces: String
    let repLength: String

    static func copy(for mode: PracticeMode) -> PracticeModeExpansionCopy {
        switch mode {
        case .timed:
            return PracticeModeExpansionCopy(
                pressureType: "Soft clock. Room to think, structure to hit.",
                surfaces: "Whether your answers land complete or trail off early.",
                repLength: "60–120s rep."
            )
        case .suddenDeath:
            return PracticeModeExpansionCopy(
                pressureType: "Hard clock. One filler ends the rep.",
                surfaces: "How composure holds when the margin is narrow.",
                repLength: "30–90s rep."
            )
        case .ahCounter:
            return PracticeModeExpansionCopy(
                pressureType: "No clock. Live filler and pace counting.",
                surfaces: "The crutches and rhythms you don't hear yourself use.",
                repLength: "45–120s rep."
            )
        case .imConversation:
            return PracticeModeExpansionCopy(
                pressureType: "Live conversation. You set the tone and the stakes.",
                surfaces: "How you hold up under realistic back-and-forth.",
                repLength: "2–5 minute rep."
            )
        }
    }
}

struct PracticeModePrescriptionCopy {
    static let heroEyebrow = "Recommended rep"
    static let alternateSectionTitle = "Choose for myself"
    static let displayHeroEyebrow = heroEyebrow
    static let practiceLibraryTitle = "Free selection"
    static let chooseExerciseTitle = "Choose for myself"
    static let adjustLabel = "Adjust"
    static let pressureLockedHint = "Complete one rated rep before Pressure Drill."
    static let pressureLockedDisplayHint = pressureLockedHint
    static let cutTheCrutchTitle = "Cut the Crutch"
    static let cutTheCrutchSubtitle = "Avoid one specific word for 60 seconds. Three slips end the rep."

    static func beginLabel(for title: String) -> String {
        "Start \(title)"
    }

    static func prescriptionLine(focus: String?, target: String?) -> String? {
        let cleanTarget = target.map(CoachDisplayCopy.normalized)
        let cleanFocus = focus.map(CoachDisplayCopy.normalized)
        let targetValue = cleanTarget.flatMap { $0.isEmpty ? nil : $0 }
        let focusValue = cleanFocus.flatMap { $0.isEmpty ? nil : $0 }

        switch (targetValue, focusValue) {
        case let (target?, _):
            // The target is the concrete instruction. The broader focus can
            // explain why this exercise was chosen, but appending it here
            // turns one clear move into a second, competing thought.
            return target
        case let (nil, focus?):
            return focus
        case (nil, nil):
            return nil
        }
    }

    static func defaultRecommendationReason(for mode: PracticeMode) -> String {
        switch mode {
        case .timed:
            return "Helps when your answers end early."
        case .suddenDeath:
            return "Sharpens composure under live pressure."
        case .ahCounter:
            return "Cleans openings and steadies rhythm."
        case .imConversation:
            return "Trains realistic social or work pressure."
        }
    }
}

struct PracticeModeAvailability: Equatable {
    static func isUnlocked(_ mode: PracticeMode, rating: SpeakingRating) -> Bool {
        guard mode == .suddenDeath else { return true }
        return rating.hasRatedEvidence
    }
}

enum TrainLibraryAction: Hashable {
    case expandExercises
    case destination(AppDestination)
}

enum TrainLibraryGroup: String, CaseIterable, Identifiable {
    case speakingDrills
    case conversationPractice
    case learnAndBuild

    var id: String { rawValue }

    var title: String {
        switch self {
        case .speakingDrills: return "Speaking drills"
        case .conversationPractice: return "Conversation practice"
        case .learnAndBuild: return "Learn and build"
        }
    }

    var subtitle: String {
        switch self {
        case .speakingDrills: return "Focused reps for delivery, pressure, fillers, and pace."
        case .conversationPractice: return "Rehearse the moments where another person pushes back."
        case .learnAndBuild: return "Develop skills, prepared talks, and your longer path."
        }
    }

    var tint: Color {
        switch self {
        case .speakingDrills: return AppColor.brandBlue
        case .conversationPractice: return AppColor.modeIM
        case .learnAndBuild: return AppColor.caution
        }
    }
}

/// Pure, ordered contract for Train's grouped library. Navigation remains
/// owned by the existing `NavigationPath`; this type only describes rows.
struct TrainLibraryItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: TrainLibraryAction
    let group: TrainLibraryGroup

    static let items: [TrainLibraryItem] = [
        TrainLibraryItem(
            id: "chooseExercise",
            title: PracticeModePrescriptionCopy.chooseExerciseTitle,
            subtitle: "Compare every focused speaking exercise.",
            systemImage: "square.grid.2x2",
            tint: AppColor.brandBlue,
            action: .expandExercises,
            group: .speakingDrills
        ),
        TrainLibraryItem(
            id: "roleplay",
            title: "Roleplay",
            subtitle: "Rehearse a real conversation under rising pressure.",
            systemImage: "person.2.fill",
            tint: AppColor.modeIM,
            action: .destination(.roleplaySetup),
            group: .conversationPractice
        ),
        TrainLibraryItem(
            id: "lessons",
            title: "Lessons",
            subtitle: "Learn one communication move at a time.",
            systemImage: "books.vertical.fill",
            tint: AppColor.caution,
            action: .destination(.lessons),
            group: .learnAndBuild
        ),
        TrainLibraryItem(
            id: "speechProjects",
            title: "Speech Projects",
            subtitle: "Build a prepared talk around a clear objective.",
            systemImage: "doc.text.fill",
            tint: AppColor.pro,
            action: .destination(.speechProjects),
            group: .learnAndBuild
        ),
        TrainLibraryItem(
            id: "path",
            title: "Path",
            subtitle: "Continue your communication curriculum.",
            systemImage: "signpost.right.fill",
            tint: AppColor.positive,
            action: .destination(.pathJourney),
            group: .learnAndBuild
        )
    ]
}

/// The quiet goal-grounding line under the Coach-Pick hero — ties the ONE
/// prescribed rep back to the user's stated goal using the measured
/// `distanceFromGoal` (M5) read, so the prescription feels like a coach
/// working a plan rather than a stateless default.
///
/// Honesty contract:
/// - No profile → no line (nothing to ground against).
/// - Goal-refresh cadence due (`GoalRefreshManager`, 2-week check-in) → no
///   line. We never claim distance against a goal the user hasn't
///   reconfirmed; the inline direction-check card owns that conversation.
/// - Insufficient baseline evidence → no line (`measuredDistanceFromGoal`
///   returns nil rather than fabricating the 0.5 midpoint read).
/// The label vocabulary ("On track" … "Early days") is forward-only —
/// distance never renders as a countdown or a deficit.
struct PracticeModeGoalGrounding {
    static func line(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        goalRefreshDue: Bool
    ) -> String? {
        guard let profile else { return nil }
        guard !goalRefreshDue else { return nil }
        guard baseline.measuredDistanceFromGoal(profile.primaryGoal) != nil else { return nil }
        return "Goal: \(profile.primaryGoal.title) \u{00B7} \(baseline.goalDistanceLabel(profile.primaryGoal))"
    }
}

/// One immutable presentation snapshot for Train's recommended-rep hero.
///
/// The recommendation engine's cached blueprint is intentionally unresolved:
/// capability can change between that cache write and SwiftUI's next render.
/// This projection applies the current capability snapshot once, then carries
/// every visible field and launch setup from that same resolved blueprint so a
/// Timed fallback can never inherit Conversation Practice or Pressure Drill
/// copy while `.onChange` catches up.
struct TrainRecommendationProjection {
    let blueprint: RecommendationBiasBlueprint
    let mode: PracticeMode
    let title: String
    let reason: String
    let focus: String
    let target: String
    let scenario: IMConversationScenario?
    let tone: IMTargetTone?
    let suggestedTheme: PromptTheme
    let prescribedDemand: PracticeSessionDemand?

    static var initialBlueprint: RecommendationBiasBlueprint {
        timedBlueprint(theme: .all, source: .coldStart)
    }

    static func resolve(
        blueprint: RecommendationBiasBlueprint,
        availability: NextActionModeAvailability,
        visibleModes: [PracticeMode]
    ) -> TrainRecommendationProjection {
        let capabilityResolved = availability.resolving(blueprint)
        let visibleBlueprint = visibleModes.contains(capabilityResolved.recommendedMode)
            ? capabilityResolved
            : timedFallback(from: capabilityResolved)
        let dynamicReason = [visibleBlueprint.whyNow, visibleBlueprint.whyMode]
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let reason = CoachDisplayCopy.normalized(
            dynamicReason ?? PracticeModePrescriptionCopy.defaultRecommendationReason(
                for: visibleBlueprint.recommendedMode
            )
        )

        let prescribedDemand: PracticeSessionDemand? = visibleBlueprint.recommendedMode == .timed
            ? visibleBlueprint.suggestedTimedDifficulty.map {
                PracticeSessionDemand.timed(difficulty: $0, speechProjectID: nil)
            }
            : nil
        return TrainRecommendationProjection(
            blueprint: visibleBlueprint,
            mode: visibleBlueprint.recommendedMode,
            title: visibleBlueprint.recommendedMode.displayLabel,
            reason: reason,
            focus: visibleBlueprint.focus,
            target: visibleBlueprint.target,
            scenario: visibleBlueprint.recommendedScenario,
            tone: visibleBlueprint.recommendedTone,
            suggestedTheme: visibleBlueprint.suggestedTheme,
            prescribedDemand: prescribedDemand
        )
    }

    private static func timedFallback(
        from blueprint: RecommendationBiasBlueprint
    ) -> RecommendationBiasBlueprint {
        timedBlueprint(theme: blueprint.suggestedTheme, source: blueprint.source)
    }

    private static func timedBlueprint(
        theme: PromptTheme,
        source: RecommendationBlueprintSource
    ) -> RecommendationBiasBlueprint {
        let timedBenefit = RecommendationBiasEngine.playbook.first { $0.mode == .timed }
        return RecommendationBiasBlueprint(
            recommendedMode: .timed,
            recommendedTone: nil,
            recommendedScenario: nil,
            focus: "First clear read",
            target: "Complete one rated rep",
            modeBenefit: timedBenefit?.benefit ?? "Builds a clean, rated speaking baseline.",
            whyMode: timedBenefit?.bestFor ?? "Timed Practice creates a clear rated starting point.",
            whyNow: "Timed Practice is ready now.",
            suggestedTimedDifficulty: nil,
            suggestedTheme: theme,
            source: source
        )
    }
}

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct PracticeModeSelectionView: View {
    @Binding var selectedMode: PracticeMode
    @Binding var navigationPath: NavigationPath
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var aiSettings = AISettingsManager.shared
    @StateObject private var hapticsSettings = HapticsSettings.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @StateObject private var skillTrendStore = SkillTrendStore.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    /// The engine result stays unresolved in state. The hero resolves this
    /// whole blueprint against one live capability snapshot each render,
    /// preventing independently cached mode/copy/setup fields from drifting.
    @State private var cachedRecommendationBlueprint = TrainRecommendationProjection.initialBlueprint
    /// When true, the picker has the Cut the Crutch tile selected.
    /// Tracked separately because Cut the Crutch isn't a `PracticeMode` —
    /// it's a sibling drill, not a pressure mode.
    @State private var crutchSelected: Bool = false
    /// When true, the picker has the Pace Training tile selected.
    @State private var paceSelected: Bool = false
    /// Per-row expansion state for the "What this trains" affordance.
    /// Set semantics so multiple rows can stay expanded if the user opens
    /// several — explore-then-commit, not modal "one at a time".
    @State private var expandedModes: Set<PracticeMode> = []
    @State private var showOtherWays: Bool = false
    @Environment(\.isAppTabRoot) private var isAppTabRoot
    @State private var showRecommendationReason: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isSelectedAppTab) private var isSelectedAppTab

    private struct CrutchOption {
        let title: String = PracticeModePrescriptionCopy.cutTheCrutchTitle
        let subtitle: String = PracticeModePrescriptionCopy.cutTheCrutchSubtitle
        let systemImage: String = "scissors"
        var tint: Color { AppColor.modeCrutch }
    }

    private let crutchOption = CrutchOption()

    private struct PaceOption {
        let title: String = "Pace Training"
        let subtitle: String = "Match the target speaking pace for 75 seconds."
        let systemImage: String = "metronome"
        var tint: Color { AppColor.modePace }
    }

    private let paceOption = PaceOption()

    // MARK: - Mode Options

    private struct ModeOption: Identifiable {
        let mode: PracticeMode
        let title: String
        let subtitle: String
        let instruction: String
        let systemImage: String
        let tint: Color
        var id: PracticeMode { mode }
    }

    private var options: [ModeOption] {
        modeOptions(imConversationAvailable: IMModeAvailability.isAvailable)
    }

    private func modeOptions(imConversationAvailable: Bool) -> [ModeOption] {
        [
            ModeOption(
                mode: .timed,
                title: PracticeMode.timed.displayLabel,
                subtitle: "Build a full answer with structure and a soft clock.",
                instruction: "Lead with the answer, then add one concrete example.",
                systemImage: "clock.fill",
                tint: AppColor.modeTimed
            ),
            ModeOption(
                mode: .suddenDeath,
                title: PracticeMode.suddenDeath.displayLabel,
                subtitle: "A hard clock with zero filler tolerance.",
                instruction: "Answer once and keep your composure under the clock.",
                systemImage: "bolt.fill",
                tint: AppColor.modeSuddenDeath
            ),
            ModeOption(
                mode: .ahCounter,
                title: PracticeMode.ahCounter.displayLabel,
                subtitle: "Speak freely while Noum tracks fillers and pacing.",
                instruction: "Pause instead of filling the space.",
                systemImage: "waveform.and.mic",
                tint: AppColor.modeAhCounter
            )
        ] + (imConversationAvailable ? [
            ModeOption(
                mode: .imConversation,
                title: PracticeMode.imConversation.displayLabel,
                subtitle: "Live conversation reps with tone and pressure control.",
                instruction: "Hold one clear point through the back-and-forth.",
                systemImage: "message.badge.waveform.fill",
                tint: AppColor.modeIM
            )
        ] : [])
    }

    private var renderedRecommendation: TrainRecommendationProjection {
        let imAvailable = IMModeAvailability.isAvailable
        let renderedOptions = modeOptions(imConversationAvailable: imAvailable)
        return TrainRecommendationProjection.resolve(
            blueprint: cachedRecommendationBlueprint,
            availability: NextActionModeAvailability(
                rating: ratingStore.rating,
                imConversationAvailable: imAvailable
            ),
            visibleModes: renderedOptions.map(\.mode)
        )
    }

    private var primaryOption: ModeOption {
        options.first(where: { $0.mode == selectedMode }) ?? options[0]
    }

    private var activeStartTitle: String {
        if paceSelected { return paceOption.title }
        if crutchSelected { return crutchOption.title }
        if !PracticeModeAvailability.isUnlocked(selectedMode, rating: ratingStore.rating) {
            return PracticeMode.timed.displayLabel
        }
        return primaryOption.title
    }

    /// Filled-capsule surface for the floating Start CTA only. Pace and
    /// Pressure Drill swap their decorative tints (white label 2.4:1) for
    /// the darkened action registers so the label clears AA; icons and
    /// washes elsewhere keep the raw tints.
    private var activeStartTint: Color {
        if paceSelected { return AppColor.modePaceAction }
        if crutchSelected { return crutchOption.tint }
        if !PracticeModeAvailability.isUnlocked(selectedMode, rating: ratingStore.rating) {
            return AppColor.modeTimed
        }
        if selectedMode == .suddenDeath { return AppColor.modeSuddenDeathAction }
        return primaryOption.tint
    }

    // MARK: - Body

    var body: some View {
        let imAvailable = IMModeAvailability.isAvailable
        let renderedOptions = modeOptions(imConversationAvailable: imAvailable)
        let recommendation = TrainRecommendationProjection.resolve(
            blueprint: cachedRecommendationBlueprint,
            availability: NextActionModeAvailability(
                rating: ratingStore.rating,
                imConversationAvailable: imAvailable
            ),
            visibleModes: renderedOptions.map(\.mode)
        )
        let recommendationOption = renderedOptions.first {
            $0.mode == recommendation.mode
        } ?? renderedOptions[0]
        let recommendationExposureFingerprint = recommendationFingerprint(
            for: recommendation.blueprint
        )
        let showsFloatingStartCTA = crutchSelected
            || paceSelected
            || selectedMode != recommendation.mode
        // The scaffold already adds `tabRootNavigationClearance` for tab
        // roots and the safeAreaInset CTA insets the scroll view by its own
        // height; stacking `floatingTabBarClearance` here as well left a
        // large dead strip under the browse list. The capsule clearance
        // lives on the floating CTA itself (see `safeAreaInset` below).
        return ReadingScreenScaffold(
            title: "Train",
            subtitle: "Your coach picked one focused rep.",
            bottomClearance: showsFloatingStartCTA ? 96 : Spacing.lg
        ) {
            // Browsing collapses the prescription to one clickable line so
            // the catalogue owns the screen; it expands again on tap. The
            // tab-root instance is retained by TabView, so the reset is
            // explicit: leaving the tab, completing a rep, or a capability
            // change all restore the hero (see `resetBrowseState`).
            if showOtherWays {
                compactRecommendedRow(recommendation, option: recommendationOption)
            } else {
                recommendedRepHero(
                    recommendation,
                    option: recommendationOption,
                    showsFloatingStartCTA: showsFloatingStartCTA
                )
            }
            freeSelectSection
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColor.screenBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .accessibilityIdentifier("practiceModes.screen")
        .safeAreaInset(edge: .bottom) {
            if showsFloatingStartCTA {
                startCTA
                    .padding(.bottom, isAppTabRoot ? Spacing.floatingTabBarClearance : 0)
            }
        }
        .task {
            let recommendation = computeRecommendation()
            if options.contains(where: { $0.mode == recommendation.mode }) {
                selectedMode = recommendation.mode
            }
            if !PracticeModeAvailability.isUnlocked(selectedMode, rating: ratingStore.rating) {
                selectedMode = .timed
            }
            // Defensive: clear any stale Quick Start flag from a prior
            // arm-then-back-out so the next "Begin" tap doesn't get
            // routed through a one-tap skip the user no longer wants.
            PracticeModeQuickStart.clear()
            PracticeModeQuickStart.clearCrutch()
        }
        .task(id: "\(recommendationExposureFingerprint)|\(isSelectedAppTab)") {
            // State hydration can replace the initial blueprint immediately
            // after mount. Count only a projection that remains rendered long
            // enough to be perceptible; a fast tap records synchronously in
            // launchMode before acceptance is marked.
            guard isSelectedAppTab else { return }
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, isSelectedAppTab else { return }
            recordRecommendationShown(recommendation)
        }
        .onChange(of: skillTrendStore.snapshots.count) { _, _ in
            let recommendation = computeRecommendation()
            selectedMode = recommendation.mode
            crutchSelected = false
            paceSelected = false
            resetBrowseState()
        }
        .onChange(of: IMModeAvailability.isAvailable) { _, _ in
            refreshRecommendationForCapabilityChange()
        }
        .onChange(of: ratingStore.rating.hasRatedEvidence) { _, _ in
            refreshRecommendationForCapabilityChange()
        }
        .onChange(of: isSelectedAppTab) { _, isSelected in
            // The Train tab root never remounts — TabView retains it. Reset
            // the browse state as the user leaves the tab (off-screen, so no
            // visible motion) so every fresh visit leads with the hero.
            // Pushes within the tab (starting a rep) keep the state; the
            // post-rep reset above owns that path.
            guard !isSelected else { return }
            resetBrowseState()
        }
    }

    /// Restores the prescription hero as the leading element. The tab-root
    /// instance is retained across tab switches and reps, so this replaces
    /// the remount-driven reset the pushed instance gets for free.
    private func resetBrowseState() {
        showOtherWays = false
        showRecommendationReason = false
    }

    // MARK: - Recommended Rep

    /// The recommendation the catalogue hides and the compact row names.
    private var currentRecommendedMode: PracticeMode? {
        let imAvailable = IMModeAvailability.isAvailable
        return TrainRecommendationProjection.resolve(
            blueprint: cachedRecommendationBlueprint,
            availability: NextActionModeAvailability(
                rating: ratingStore.rating,
                imConversationAvailable: imAvailable
            ),
            visibleModes: modeOptions(imConversationAvailable: imAvailable).map(\.mode)
        ).mode
    }

    /// Collapsed prescription while the user browses manually — still one
    /// tap to bring the full recommendation back.
    private func compactRecommendedRow(
        _ recommendation: TrainRecommendationProjection,
        option: ModeOption
    ) -> some View {
        // Same demand guard as the hero: `prescribedDemand` is nil unless
        // the recommendation itself is Timed, so a leftover blueprint
        // difficulty can never surface under a non-timed prescription.
        let demandLabel = recommendation.prescribedDemand?.timedDifficulty?.compactDemandLabel
        return Button {
            animateMode { showOtherWays = false }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: option.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(width: 32, height: 32)
                    .background(AppColor.brandBlue.opacity(0.10), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Recommended \u{00B7} \(option.title)")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                    if let demandLabel {
                        Text(demandLabel)
                            .font(Typography.captionSmall)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }

                Spacer(minLength: Spacing.xs)

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(AppColor.brandBlue.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(
            demandLabel.map { "Recommended rep, \(option.title), \($0)" }
                ?? "Recommended rep, \(option.title)"
        ))
        .accessibilityHint(Text("Expands the recommendation."))
        .accessibilityIdentifier("practiceModes.recommendedCompact")
    }

    private func recommendedRepHero(
        _ recommendation: TrainRecommendationProjection,
        option: ModeOption,
        showsFloatingStartCTA: Bool
    ) -> some View {
        let instruction = PracticeModePrescriptionCopy.prescriptionLine(
            focus: recommendation.focus,
            target: recommendation.target
        ) ?? option.instruction
        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                modeIcon(option)

                VStack(alignment: .leading, spacing: 6) {
                    // `brandBlueOnWash`, not `brandBlue`: the eyebrow sits
                    // in the card's tint-wash region where the standard dark
                    // register drops below the small-text AA threshold.
                    Text(PracticeModePrescriptionCopy.displayHeroEyebrow)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.brandBlueOnWash)

                    Text(recommendation.title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Image(systemName: "scope")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(option.tint)
                    .accessibilityHidden(true)

                Text(instruction)
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Focus. \(instruction)")
            .accessibilityIdentifier("practiceModes.recommendedHero.focus")

            if let difficulty = recommendation.prescribedDemand?.timedDifficulty {
                Label(difficulty.compactDemandLabel, systemImage: "timer")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(option.tint)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 8)
                    .background(option.tint.opacity(0.09), in: Capsule())
                    .accessibilityLabel("Recommended difficulty, \(difficulty.title)")
                    .accessibilityValue(difficulty.subtitle)
                    .accessibilityIdentifier("practiceModes.recommendedHero.timedDifficulty")
            }

            recommendationReasonDisclosure(
                recommendation.reason,
                tint: option.tint
            )

            if !showsFloatingStartCTA {
                PrimaryCTA(PracticeModePrescriptionCopy.beginLabel(for: recommendation.title), tint: AppColor.brandBlue) {
                    selectedMode = recommendation.mode
                    crutchSelected = false
                    paceSelected = false
                    launchMode(
                        recommendation.mode,
                        recommendation: recommendation,
                        quickStart: true,
                        recordsRecommendationAcceptance: true
                    )
                }
                .accessibilityIdentifier("practiceModes.recommendedHero.begin")
            }

            // Config access for the recommended mode WITHOUT losing the one-tap
            // Begin above. The recommended mode has no row in "other ways", so
            // this is its only setup entry point — navigate to the setup page
            // (no arm()) for users who want to tweak theme / pace / tools before
            // this rep. Restrained, mirrors the Impromptu redesign's gear-hidden
            // settings rather than a second loud button.
            Button {
                selectedMode = recommendation.mode
                crutchSelected = false
                paceSelected = false
                launchMode(
                    recommendation.mode,
                    recommendation: recommendation,
                    quickStart: false,
                    recordsRecommendationAcceptance: false
                )
            } label: {
                Text(PracticeModePrescriptionCopy.adjustLabel)
                    .font(Typography.captionSmall.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("practiceModes.recommendedHero.adjust")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(modeCardBackground(option, isRecommended: true, isSelected: true))
        .shadow(color: option.tint.opacity(0.10), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("practiceModes.recommendedHero")
        .accessibilityValue(recommendation.mode.displayLabel)
    }

    private func recommendationReasonDisclosure(_ reason: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                animateMode {
                    showRecommendationReason.toggle()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text("Why this rep?")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlueOnWash)
                    Spacer(minLength: 0)
                    Image(systemName: showRecommendationReason ? "chevron.up" : "chevron.down")
                        .font(Typography.captionSmall.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("practiceModes.recommendedHero.reasonToggle")
            .accessibilityLabel(showRecommendationReason ? "Hide why this rep was chosen" : "Show why this rep was chosen")

            if showRecommendationReason {
                Text(reason)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.bottom, Spacing.xs)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(tint.opacity(0.14))
                .frame(height: 0.5)
        }
    }

    // MARK: - Practice library

    private var freeSelectSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button {
                animateMode { showOtherWays.toggle() }
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                        .frame(width: 36, height: 36)
                        .background(
                            AppColor.brandBlue.opacity(0.09),
                            in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(PracticeModePrescriptionCopy.alternateSectionTitle)
                            .font(Typography.cardLabel)
                            .foregroundStyle(.primary)
                        Text("Browse exercises and learning paths.")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: showOtherWays ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    AppColor.cardBackground,
                    in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .stroke(AppColor.subtleBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("practiceModes.otherWays")
            .accessibilityLabel(PracticeModePrescriptionCopy.alternateSectionTitle)
            .accessibilityHint(showOtherWays ? "Hides free selection." : "Shows every exercise and learning path.")

            if showOtherWays {
                practiceLibrary
                    .transition(reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var practiceLibrary: some View {
        LazyVStack(alignment: .leading, spacing: Spacing.lg) {
            GroupedDestinationList(
                title: "Exercises",
                subtitle: "Choose a specific kind of rep.",
                tint: AppColor.brandBlue
            ) {
                exerciseLibraryRows
            }

            ForEach(TrainLibraryGroup.allCases.filter { $0 != .speakingDrills }) { group in
                let items = TrainLibraryItem.items.filter { $0.group == group }
                GroupedDestinationList(
                    title: group.title,
                    subtitle: group.subtitle,
                    tint: group.tint
                ) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider().padding(.leading, 60)
                        }

                        trainLibraryRow(item)
                    }
                }
            }
        }
    }

    private func trainLibraryRow(_ item: TrainLibraryItem) -> some View {
        Button {
            switch item.action {
            case .expandExercises:
                animateMode { showOtherWays.toggle() }
            case .destination(let destination):
                navigationPath.append(destination)
            }
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: item.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(item.tint)
                    .frame(width: 36, height: 36)
                    .background(item.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(item.title)
                        .font(Typography.cardLabel)
                        .foregroundStyle(.primary)
                    Text(item.subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: libraryChevron(for: item))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title). \(item.subtitle)")
        .accessibilityHint(libraryHint(for: item))
        .accessibilityIdentifier(item.action == .expandExercises
            ? "practiceModes.otherWays"
            : "train.library.\(item.id)")
    }

    private func libraryChevron(for item: TrainLibraryItem) -> String {
        if item.action == .expandExercises {
            return showOtherWays ? "chevron.up" : "chevron.down"
        }
        return "chevron.right"
    }

    private func libraryHint(for item: TrainLibraryItem) -> String {
        if item.action == .expandExercises {
            return showOtherWays ? "Collapses the exercise list." : "Expands the exercise list."
        }
        return "Opens \(item.title)."
    }

    private var exerciseLibraryRows: some View {
        // The prescription card above IS the recommended mode's entry —
        // repeating it in the catalogue read as a duplicate.
        let browseOptions = options.filter { $0.mode != currentRecommendedMode }
        return VStack(spacing: 0) {
            ForEach(Array(browseOptions.enumerated()), id: \.element.id) { index, option in
                if index > 0 {
                    Divider().padding(.leading, 72)
                }
                modeLibraryRow(option)
            }
            Divider().padding(.leading, 72)
            supplementalExerciseRow(
                title: crutchOption.title,
                subtitle: "Remove one verbal crutch for a focused minute.",
                systemImage: crutchOption.systemImage,
                tint: crutchOption.tint,
                isSelected: crutchSelected,
                accessibilityID: "practiceMode.cutTheCrutch"
            ) {
                animateMode {
                    crutchSelected = true
                    paceSelected = false
                }
                CoachHaptic.selectionTap()
            }
            Divider().padding(.leading, 72)
            supplementalExerciseRow(
                title: paceOption.title,
                subtitle: "Match a steady target pace for 75 seconds.",
                systemImage: paceOption.systemImage,
                tint: paceOption.tint,
                isSelected: paceSelected,
                accessibilityID: "practiceMode.paceTraining"
            ) {
                animateMode {
                    paceSelected = true
                    crutchSelected = false
                }
                CoachHaptic.selectionTap()
            }
        }
        .background(AppColor.innerSurface.opacity(0.58))
    }

    private func modeLibraryRow(_ option: ModeOption) -> some View {
        let isSelected = !crutchSelected && !paceSelected && selectedMode == option.mode
        let isExpanded = expandedModes.contains(option.mode)
        let isLocked = !PracticeModeAvailability.isUnlocked(option.mode, rating: ratingStore.rating)

        return VStack(spacing: 0) {
            Button {
                guard !isLocked else { return }
                animateMode {
                    selectedMode = option.mode
                    crutchSelected = false
                    paceSelected = false
                    expandedModes = [option.mode]
                }
                CoachHaptic.selectionTap()
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: option.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(option.tint)
                        .frame(width: 36, height: 36)
                        .background(option.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(option.title)
                            .font(Typography.cardLabel)
                            .foregroundStyle(.primary)
                        Text(isLocked ? PracticeModePrescriptionCopy.pressureLockedDisplayHint : option.subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: isLocked ? "lock.fill" : isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isLocked ? Color.secondary.opacity(0.45) : isSelected ? option.tint : Color.secondary.opacity(0.35))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("practiceMode.\(option.mode.rawValue)")
            .accessibilityLabel(option.title)
            .accessibilityHint(isLocked ? PracticeModePrescriptionCopy.pressureLockedDisplayHint : option.subtitle)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .overlay(alignment: .topTrailing) {
                expandToggleButton(for: option, isExpanded: isExpanded)
            }

            if isExpanded {
                modeExpandedSection(option)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
                    .transition(reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .sensoryFeedback(.selection, trigger: isSelected) { _, _ in hapticsSettings.isEnabled }
    }

    private func supplementalExerciseRow(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        isSelected: Bool,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(Typography.cardLabel)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? tint : Color.secondary.opacity(0.35))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Transparent tap target overlaying the visible chevron icon.
    /// Separating this from the row Button lets the user "preview" a
    /// mode (expand without selecting) — important for first-timers
    /// who don't yet know what each mode trains. Tapping the row
    /// proper still both selects and expands.
    private func expandToggleButton(for option: ModeOption, isExpanded: Bool) -> some View {
        Button {
            animateMode {
                if expandedModes.contains(option.mode) {
                    expandedModes.remove(option.mode)
                } else {
                    expandedModes.insert(option.mode)
                }
            }
            CoachHaptic.selectionTap()
        } label: {
            Color.clear
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, Spacing.lg - 14)
        .padding(.top, Spacing.lg - 14)
        .accessibilityIdentifier("practiceMode.\(option.mode.rawValue).expandButton")
        .accessibilityLabel(isExpanded
            ? "Collapse what this trains"
            : "Expand what this trains")
        .accessibilityHint("Shows the pressure type, what this surfaces, and the typical rep length.")
    }

    /// The "What this trains" body that drops in under the row when
    /// the user taps to expand. 28pt `NoumCharacter.Inline` on the left
    /// gives the moment a coach-presence anchor — visual narration,
    /// no audio. Three lines, each on-voice (declarative, specific,
    /// no exclamation marks). The "Start now" affordance hangs off the
    /// bottom of this block — see `quickStartButton` for the rationale.
    private func modeExpandedSection(_ option: ModeOption) -> some View {
        let copy = PracticeModeExpansionCopy.copy(for: option.mode)
        let isLocked = !PracticeModeAvailability.isUnlocked(option.mode, rating: ratingStore.rating)
        let isSelected = !crutchSelected && !paceSelected && selectedMode == option.mode
        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                NoumCharacter.Inline(
                    size: 28,
                    mood: .coaching,
                    tint: option.tint
                )
                .padding(.top, 2)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(copy.pressureType)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(copy.surfaces)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(copy.repLength)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("What this trains. \(copy.pressureType) \(copy.surfaces) \(copy.repLength)")

            if isLocked {
                lockedQuickStartHint(tint: option.tint)
            } else if isSelected {
                quickStartButton(for: option)
            } else {
                Text("Select this exercise to make it your next rep.")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(option.tint)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier("practiceMode.\(option.mode.rawValue).previewHint")
            }
        }
        .padding(.top, Spacing.md)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.secondary.opacity(0.14))
                .frame(height: 0.5)
        }
    }

    /// Secondary "Start now" CTA that arms a one-tap launch flag and
    /// pushes the same destination the floating Begin button uses. The
    /// configure-first behaviour (tap a row → Begin at the bottom) is
    /// preserved — Quick Start is purely additive, only visible inside
    /// the expanded "What this trains" reveal so it never competes
    /// with the curated picker hierarchy. Tint matches the mode so the
    /// affordance reads as an extension of the row, not a separate
    /// system control.
    private func quickStartButton(for option: ModeOption) -> some View {
        let title = quickStartLabel(for: option.mode)
        return Button {
            CoachHaptic.selectionTap()
            launchMode(
                option.mode,
                quickStart: true,
                recordsRecommendationAcceptance: false
            )
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.footnote.weight(.bold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(option.tint)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(option.tint.opacity(0.10), in: Capsule())
            .overlay(
                Capsule().strokeBorder(option.tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("practiceMode.\(option.mode.rawValue).quickStart")
        .accessibilityLabel(title)
        .accessibilityHint("Starts \(option.title) immediately with your saved defaults.")
    }

    private func lockedQuickStartHint(tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.footnote.weight(.bold))
            Text(PracticeModePrescriptionCopy.pressureLockedDisplayHint)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(tint.opacity(0.08), in: Capsule())
        .overlay(
            Capsule().strokeBorder(tint.opacity(0.16), lineWidth: 1)
        )
        .accessibilityIdentifier("practiceMode.suddenDeath.lockedHint")
    }

    /// Per-mode CTA copy. "Start" is the shared verb; the mode
    /// name is appended so accessibility users hear which rep they're
    /// about to launch when scanning the picker linearly.
    private func quickStartLabel(for mode: PracticeMode) -> String {
        "Start \(mode.displayLabel)"
    }

    /// Reduce-motion opts out of the picker spring entirely. The state
    /// change still lands immediately; haptics remain owned by callers.
    private func animateMode(_ changes: () -> Void) {
        if reduceMotion {
            changes()
        } else {
            withAnimation(.snappySpring) {
                changes()
            }
        }
    }

    /// Mode-card chrome. Two registers:
    ///
    ///  - **Recommended row** mirrors the Home Coach Card hero pattern:
    ///    a white base with a top-anchored radial mode-tint wash at
    ///    0.16 alpha, plus a faint tint hairline border. This is the
    ///    "here's what's special tonight" signal — the visual contrast
    ///    against the other rows IS the design.
    ///  - **Plain row** stays a calm white card with the standard
    ///    inner edge stroke. Non-recommended modes should never look
    ///    like they're competing for attention with the curated pick.
    ///
    /// Selected state always trumps the rest hairline with a brighter
    /// tinted stroke so the user can still see which card their tap
    /// lands on, recommended or not.
    private func modeCardBackground(
        _ option: ModeOption,
        isRecommended: Bool,
        isSelected: Bool
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        let restStrokeColor: Color = isRecommended
            ? option.tint.opacity(0.22)
            : Color.white.opacity(0.72)
        let strokeColor: Color = isSelected
            ? option.tint.opacity(0.32)
            : restStrokeColor
        let strokeWidth: CGFloat = isSelected ? 1.5 : 1

        return ZStack {
            shape.fill(AppColor.cardBackground)

            if isRecommended {
                // Top-anchored radial wash — same construction as the
                // Coach Card's `coachCardBackground`. Mode tint, low
                // alpha, fades into the card body so text on top stays
                // readable at the standard secondary contrast.
                shape.fill(
                    RadialGradient(
                        colors: [
                            option.tint.opacity(0.16),
                            option.tint.opacity(0.04),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.5, y: 0.0),
                        startRadius: 0,
                        endRadius: 320
                    )
                )
            }

            shape.strokeBorder(strokeColor, lineWidth: strokeWidth)
        }
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

    // MARK: - Bottom CTA

    private var startCTA: some View {
        let title = activeStartTitle
        let tint = activeStartTint
        let ctaLabel = "Start \(title)"
        return Button {
            // Commitment haptic (A2 register map) — same beat as the
            // Home coach card's Begin: medium impact on committing to a
            // rep, fired before navigation.
            CoachHaptic.drillStart()
            if paceSelected {
                navigationPath.append(AppDestination.paceTrainingPractice)
            } else if crutchSelected {
                navigationPath.append(AppDestination.cutTheCrutchPractice)
            } else if !PracticeModeAvailability.isUnlocked(selectedMode, rating: ratingStore.rating) {
                selectedMode = .timed
                navigationPath.append(AppDestination.timedPractice(difficulty: nil))
            } else {
                launchMode(
                    selectedMode,
                    quickStart: false,
                    recordsRecommendationAcceptance: false
                )
            }
        } label: {
            Text(ctaLabel)
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
        .accessibilityLabel(ctaLabel)
        .accessibilityHint("Starts a \(title) rep.")
        // Background tightened from a 0.02 → 0.72 white gradient to a
        // solid screen-bg fade — the earlier opacity stop left content
        // bleeding through (Cut the Crutch's setup copy was visible under
        // the CTA at rest scroll).
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

    @discardableResult
    private func computeRecommendation() -> TrainRecommendationProjection {
        let imAvailable = IMModeAvailability.isAvailable
        let renderedOptions = modeOptions(imConversationAvailable: imAvailable)
        let context = RecommendationBiasContextBuilder.context(
            profile: coachingProfileStore.profile,
            sessions: sessionStore.sessions,
            sessionStreak: sessionStreak,
            daysSinceLastSession: daysSinceLastSession,
            coachMemory: coachMemoryStore.currentMemory,
            imAvailable: imAvailable,
            recommendationOutcomes: recommendationLearningStore.outcomes,
            summaryStyle: .compact
        )
        let trends = TrendAnalyzer.analyze(snapshots: skillTrendStore.snapshots)
        let coherentBlueprint = CurrentCoachingFocusPresentation.make(
            trends: trends,
            sessionCount: sessionStore.progressEligibleSessionCount
        )?.applying(to: context.blueprint) ?? context.blueprint
        let sourceBlueprint = RecommendationTapCapabilityLossUITestFixture
            .blueprintForRendering(coherentBlueprint)
        cachedRecommendationBlueprint = sourceBlueprint
        let recommendation = TrainRecommendationProjection.resolve(
            blueprint: sourceBlueprint,
            availability: NextActionModeAvailability(
                rating: ratingStore.rating,
                imConversationAvailable: imAvailable
            ),
            visibleModes: renderedOptions.map(\.mode)
        )
        return recommendation
    }

    private func recordRecommendationShown(_ recommendation: TrainRecommendationProjection) {
        recommendationLearningStore.recordShown(
            fingerprint: recommendationFingerprint(for: recommendation.blueprint),
            title: recommendation.title,
            focus: recommendation.focus,
            target: recommendation.target,
            mode: recommendation.mode,
            isAIBacked: false,
            prescribedDemand: recommendation.prescribedDemand
        )
    }

    private func recommendationFingerprint(for blueprint: RecommendationBiasBlueprint) -> String {
        let recent = sessionStore.progressEligibleSessions.prefix(5).map { session in
            "\(session.id.uuidString)-\(session.mode.rawValue)-\(session.fillerWordCount)-\(Int(session.duration))-\(session.score ?? 0)"
        }.joined(separator: "|")
        let profileKey = coachingProfileStore.profile.map {
            "\($0.primaryGoal.rawValue)-\($0.biggestChallenge.rawValue)-\($0.desiredOutcome.rawValue)-\($0.chosenStyleGoal?.rawValue ?? "no-style")"
        } ?? "no-profile"
        return [
            "modePickerRecommendation",
            profileKey,
            blueprint.source.trackingLabel,
            blueprint.recommendedMode.rawValue,
            blueprint.recommendedScenario?.rawValue ?? "no-scenario",
            blueprint.recommendedTone?.rawValue ?? "no-tone",
            recommendationDemandFingerprint(for: blueprint),
            blueprint.suggestedTheme.rawValue,
            blueprint.focus,
            blueprint.target,
            recent
        ].joined(separator: ".")
    }

    private func recommendationDemandFingerprint(
        for blueprint: RecommendationBiasBlueprint
    ) -> String {
        guard blueprint.recommendedMode == .timed,
              let difficulty = blueprint.suggestedTimedDifficulty else {
            return "mode-only"
        }
        return PracticeSessionDemand.timed(
            difficulty: difficulty,
            speechProjectID: nil
        ).recommendationFingerprintComponent
    }

    private func launchMode(
        _ displayedMode: PracticeMode,
        recommendation: TrainRecommendationProjection? = nil,
        quickStart: Bool,
        recordsRecommendationAcceptance: Bool
    ) {
        let launchRecommendation = recommendation ?? renderedRecommendation
        let carriesRecommendationSetup = displayedMode == launchRecommendation.mode
        let prescribedDemand = recordsRecommendationAcceptance && carriesRecommendationSetup
            ? launchRecommendation.prescribedDemand
            : nil
        let imAvailable = RecommendationTapCapabilityLossUITestFixture
            .imAvailableAtTap(IMModeAvailability.isAvailable)
        let liveAvailability = RecommendationTapCapabilityLossUITestFixture
            .availabilityAtTap(
                NextActionModeAvailability(
                    rating: ratingStore.rating,
                    imConversationAvailable: imAvailable
                )
            )
        let launch = PracticeModeLaunchProjection.resolve(
            displayedMode: displayedMode,
            scenario: displayedMode == .imConversation && carriesRecommendationSetup
                ? launchRecommendation.scenario
                : nil,
            tone: displayedMode == .imConversation && carriesRecommendationSetup
                ? launchRecommendation.tone
                : nil,
            prescribedDemand: prescribedDemand,
            imAvailable: imAvailable,
            modeAvailability: liveAvailability
        )
        if recordsRecommendationAcceptance {
            RecommendationTapAttribution.apply(
                launch: launch,
                recordShown: {
                    recordRecommendationShown(launchRecommendation)
                },
                recordAccepted: { mode in
                    recommendationLearningStore.markTapped(mode: mode)
                }
            )
        }
        if launch.acceptsDisplayedPrescription {
            if quickStart {
                PracticeModeQuickStart.arm(for: launch.launchedMode)
            }
        } else {
            // The capability changed after this mode rendered. Route safely,
            // but do not arm/log an operational fallback the user never saw.
            PracticeModeQuickStart.clear()
            selectedMode = launch.launchedMode
        }
        navigationPath.append(launch.destination)
    }

    private func refreshRecommendationForCapabilityChange() {
        let recommendation = computeRecommendation()
        selectedMode = recommendation.mode
        crutchSelected = false
        paceSelected = false
        resetBrowseState()
    }

    // MARK: - Recent-session signals (feed RecommendationBiasEngine)

    /// Feeds the recommendation engine's input. Reads the freeze-aware
    /// displayed streak (StreakFreezeManager is the single displayed-streak
    /// owner) so prescription copy can never reference a streak the user
    /// doesn't see on Home/Profile.
    private var sessionStreak: Int {
        streakFreeze.currentStreak
    }

    private var daysSinceLastSession: Int {
        guard let last = sessionStore.progressEligibleSessions.first?.date else { return 99 }
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
#Preview("Mode picker — Pressure Drill selected") {
    NavigationStack {
        PracticeModeSelectionView(
            selectedMode: .constant(.suddenDeath),
            navigationPath: .constant(NavigationPath())
        )
    }
}
#endif
#endif
