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
    static let heroEyebrow = "Coach pick"
    static let alternateSectionTitle = "Other ways to practice"
    static let pressureLockedHint = "Run one rated rep before Pressure Drill."
    static let cutTheCrutchTitle = "Cut the Crutch"
    static let cutTheCrutchSubtitle = "Avoid one specific word for 60 seconds. Three slips ends the rep."

    static func beginLabel(for title: String) -> String {
        "Begin \u{00B7} \(title)"
    }

    static func escapeLabel() -> String {
        "Pick another"
    }

    static func prescriptionLine(focus: String?, target: String?) -> String? {
        let cleanTarget = target?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFocus = focus?.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetValue = cleanTarget.flatMap { $0.isEmpty ? nil : $0 }
        let focusValue = cleanFocus.flatMap { $0.isEmpty ? nil : $0 }

        switch (targetValue, focusValue) {
        case let (target?, focus?) where target.localizedCaseInsensitiveCompare(focus) != .orderedSame:
            return "Target \(target) \u{00B7} Focus \(focus)"
        case let (target?, _):
            return "Target \(target)"
        case let (nil, focus?):
            return "Focus \(focus)"
        case (nil, nil):
            return nil
        }
    }
}

struct PracticeModeAvailability: Equatable {
    static func isUnlocked(_ mode: PracticeMode, rating: SpeakingRating) -> Bool {
        guard mode == .suddenDeath else { return true }
        return rating.hasRatedEvidence
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
    @StateObject private var hapticsSettings = HapticsSettings.shared
    @StateObject private var masteryStore = ModeMasteryStore.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @State private var cachedRecommendedMode: PracticeMode?
    @State private var cachedRecommendedFocus: String?
    @State private var cachedRecommendedTarget: String?
    /// Dynamic per-user "why this mode" line produced by the
    /// `RecommendationBiasEngine`. Falls back to the static
    /// `ModeOption.recommendedReason` when nil (cold start, no
    /// session history).
    @State private var cachedRecommendedReason: String?
    /// IM scenario + tone the `RecommendationBiasEngine` wants this user
    /// to drill next, carried by the blueprint only when the recommended
    /// mode is IM (a per-scenario tone drill or the goal-based default).
    /// Threaded into `appDestination(for: .imConversation)` so launching
    /// IM from the picker prefills the same scenario + tone the Home
    /// coach card does — the drill is offered wherever the user lands,
    /// not just on Home. Both nil when IM isn't the recommendation, so
    /// the IM setup falls back to the normal scenario grid.
    @State private var cachedRecommendedScenario: IMConversationScenario?
    @State private var cachedRecommendedTone: IMTargetTone?
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                title: PracticeMode.suddenDeath.displayLabel,
                subtitle: "A hard clock with zero filler tolerance.",
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
        let candidate = cachedRecommendedMode ?? .timed
        guard PracticeModeAvailability.isUnlocked(candidate, rating: ratingStore.rating) else {
            return .timed
        }
        return candidate
    }

    private var recommendedOption: ModeOption {
        options.first(where: { $0.mode == recommendedMode }) ?? options[0]
    }

    private var alternateOptions: [ModeOption] {
        options.filter { $0.mode != recommendedOption.mode }
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

    private var activeStartTint: Color {
        if paceSelected { return paceOption.tint }
        if crutchSelected { return crutchOption.tint }
        if !PracticeModeAvailability.isUnlocked(selectedMode, rating: ratingStore.rating) {
            return AppColor.modeTimed
        }
        return primaryOption.tint
    }

    private var showsFloatingStartCTA: Bool {
        crutchSelected || paceSelected || selectedMode != recommendedMode
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    headerCopy
                    recommendedRepHero

                    otherWaysSection
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                // Bottom inset clears the floating Start CTA when the user
                // opens alternate choices. At rest, the recommendation hero
                // owns the only Begin button so the picker does not show two
                // competing primary actions.
                .padding(.bottom, showsFloatingStartCTA ? 96 : Spacing.lg)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("practiceModes.screen")
        .safeAreaInset(edge: .bottom) {
            if showsFloatingStartCTA {
                startCTA
            }
        }
        .task {
            computeRecommendation()
            if options.contains(where: { $0.mode == recommendedMode }) {
                selectedMode = recommendedMode
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
    }

    // MARK: - Recommended Rep

    private var recommendedRepHero: some View {
        let option = recommendedOption
        let reason = cachedRecommendedReason ?? option.recommendedReason
        let snapshot = masteryStore.snapshot(for: option.mode)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: Spacing.md) {
                modeIcon(option)

                VStack(alignment: .leading, spacing: 6) {
                    Text(PracticeModePrescriptionCopy.heroEyebrow)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(option.tint)
                        .textCase(.uppercase)

                    Text(option.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if snapshot.sessionsLogged > 0 {
                        ModeMasteryBadge(snapshot: snapshot)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(reason)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            recommendedSuccessMarker(tint: option.tint)

            PrimaryCTA(PracticeModePrescriptionCopy.beginLabel(for: option.title), tint: option.tint) {
                selectedMode = option.mode
                crutchSelected = false
                paceSelected = false
                recommendationLearningStore.markTapped(mode: option.mode)
                navigationPath.append(appDestination(for: option.mode))
            }
            .accessibilityIdentifier("practiceModes.recommendedHero.begin")

            Button {
                animateMode {
                    showOtherWays = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.subheadline.weight(.bold))
                    Text(PracticeModePrescriptionCopy.escapeLabel())
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(option.tint)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("practiceModes.recommendedHero.pickAnother")
            .accessibilityHint("Shows the other practice modes.")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(modeCardBackground(option, isRecommended: true, isSelected: true))
        .shadow(color: option.tint.opacity(0.10), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("practiceModes.recommendedHero")
    }

    private func recommendedSuccessMarker(tint: Color) -> some View {
        Group {
            if let line = PracticeModePrescriptionCopy.prescriptionLine(
                focus: cachedRecommendedFocus,
                target: cachedRecommendedTarget
            ) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "target")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)

                    Text(line)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(line)
            }
        }
    }

    private var otherWaysSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionToggleButton(
                title: PracticeModePrescriptionCopy.alternateSectionTitle,
                isExpanded: showOtherWays,
                accessibilityID: "practiceModes.otherWays"
            ) {
                showOtherWays.toggle()
            }

            if showOtherWays {
                VStack(spacing: Spacing.cardGap) {
                    ForEach(alternateOptions) { option in
                        modeCard(option)
                    }
                    crutchCard
                    paceCard
                }
                .transition(reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionToggleButton(
        title: String,
        isExpanded: Bool,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            animateMode {
                action()
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.xs)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityLabel(title)
        .accessibilityHint(isExpanded ? "Collapses this section." : "Expands this section.")
    }

    // MARK: - Header

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Display treatment — the picker reads as an iOS premium
            // screen header ("pick your next rep" is a curated menu
            // moment), not a settings-list title. The richer 32pt
            // rounded weight is the single biggest signal that the
            // surface below is a curation, not a list.
            Text("Your next rep")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("One focused rep, then the read gets sharper.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Mode Card

    private func modeCard(_ option: ModeOption) -> some View {
        let isSelected = !crutchSelected && !paceSelected && selectedMode == option.mode
        let isRecommended = option.mode == recommendedMode
        let isExpanded = expandedModes.contains(option.mode)
        let isLocked = !PracticeModeAvailability.isUnlocked(option.mode, rating: ratingStore.rating)

        return VStack(spacing: 0) {
            Button {
                guard !isLocked else { return }
                animateMode {
                    selectedMode = option.mode
                    crutchSelected = false
                    paceSelected = false
                    // Collapse every other mode so the selected one stands
                    // out and the list stays compact.
                    expandedModes = [option.mode]
                }
                CoachHaptic.selectionTap()
            } label: {
                HStack(alignment: .top, spacing: Spacing.md) {
                    modeIcon(option)

                    VStack(alignment: .leading, spacing: 6) {
                        let snapshot = masteryStore.snapshot(for: option.mode)
                        HStack(alignment: .top, spacing: 8) {
                            Text(option.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.9)
                                .fixedSize(horizontal: false, vertical: true)

                            // Visual-only chevron — the actual tap target
                            // is the transparent overlay button below.
                            // Drawing the icon inside the row label keeps
                            // the existing layout coherent; using an
                            // overlay button avoids nesting buttons
                            // (which SwiftUI doesn't tap-route).
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }

                        if isRecommended || snapshot.sessionsLogged > 0 {
                            HStack(spacing: 6) {
                                if isRecommended {
                                    recommendedPill(tint: option.tint)
                                }

                                if snapshot.sessionsLogged > 0 {
                                    ModeMasteryBadge(snapshot: snapshot)
                                        .fixedSize(horizontal: true, vertical: false)
                                }

                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Text(option.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)

                        if isLocked {
                            Label(PracticeModePrescriptionCopy.pressureLockedHint, systemImage: "lock.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(option.tint)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if isRecommended {
                            Text(cachedRecommendedReason ?? option.recommendedReason)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(option.tint)
                                .padding(.top, 2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: isLocked ? "lock.fill" : isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isLocked ? Color.secondary.opacity(0.45) : isSelected ? option.tint : Color.secondary.opacity(0.4))
                        .accessibilityHidden(true)
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("practiceMode.\(option.mode.rawValue)")
            .accessibilityLabel(accessibilityLabel(option, isRecommended: isRecommended))
            .accessibilityHint(isLocked ? PracticeModePrescriptionCopy.pressureLockedHint : option.subtitle)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .overlay(alignment: .topTrailing) {
                expandToggleButton(for: option, isExpanded: isExpanded)
            }

            if isExpanded {
                modeExpandedSection(option)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                    .transition(reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(modeCardBackground(option, isRecommended: isRecommended, isSelected: isSelected))
        // Recommended carries a soft tint-ambient shadow even at
        // rest — that's the "this is tonight's pick" signal. The
        // selected sharp shadow stacks on top so the chosen card
        // still earns a touch more elevation than the others.
        .shadow(
            color: isRecommended ? option.tint.opacity(0.16) : .clear,
            radius: 20,
            y: 10
        )
        .shadow(
            color: isSelected ? option.tint.opacity(0.10) : .clear,
            radius: 16,
            y: 8
        )
        .sensoryFeedback(.selection, trigger: isSelected) { _, _ in hapticsSettings.isEnabled }
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
            } else {
                quickStartButton(for: option)
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
            PracticeModeQuickStart.arm(for: option.mode)
            navigationPath.append(appDestination(for: option.mode))
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
        .accessibilityHint("Begins a \(option.title) rep with default settings, no setup screen.")
    }

    private func lockedQuickStartHint(tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.footnote.weight(.bold))
            Text(PracticeModePrescriptionCopy.pressureLockedHint)
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

    /// Per-mode CTA copy. "Start now" is the shared verb; the mode
    /// name is appended so accessibility users hear which rep they're
    /// about to launch when scanning the picker linearly.
    private func quickStartLabel(for mode: PracticeMode) -> String {
        switch mode {
        case .timed: return "Start now \u{00B7} Timed"
        case .suddenDeath: return "Start now \u{00B7} \(PracticeMode.suddenDeath.displayLabel)"
        case .ahCounter: return "Start now \u{00B7} Ah-Counter"
        case .imConversation: return "Start now \u{00B7} IM Mode"
        }
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

    private func recommendedPill(tint: Color) -> some View {
        Text("Recommended")
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
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

        return VStack(spacing: 0) {
            Button {
                animateMode {
                    crutchSelected = true
                    paceSelected = false
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
            }
            .buttonStyle(.pressable)
            .sensoryFeedback(.selection, trigger: isSelected) { _, _ in hapticsSettings.isEnabled }
            .accessibilityIdentifier("practiceMode.cutTheCrutch")
            .accessibilityLabel(crutchOption.title)
            .accessibilityHint(crutchOption.subtitle)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            // "Start now" mirrors the per-mode affordance — same secondary
            // CTA pattern, same tint integration, same one-tap semantics.
            // Only visible once the card is selected so the picker reads
            // calm at rest; appears with the same expand-style transition
            // the four mode rows use for their reveal block.
            if isSelected {
                crutchQuickStartButton(tint: tint)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                    .transition(reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .move(edge: .top)))
            }
        }
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

    /// Cut the Crutch sibling of `quickStartButton`. The drill isn't a
    /// `PracticeMode`, so it routes through `cutTheCrutchPractice` with
    /// its own armed flag — same UX, separate plumbing.
    private func crutchQuickStartButton(tint: Color) -> some View {
        Button {
            CoachHaptic.selectionTap()
            PracticeModeQuickStart.armCrutch()
            navigationPath.append(AppDestination.cutTheCrutchPractice)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.footnote.weight(.bold))
                Text("Start now \u{00B7} Cut the Crutch")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(tint.opacity(0.10), in: Capsule())
            .overlay(
                Capsule().strokeBorder(tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("practiceMode.cutTheCrutch.quickStart")
        .accessibilityLabel("Start now, Cut the Crutch")
        .accessibilityHint("Begins a Cut the Crutch drill with default settings, no setup screen.")
    }

    // MARK: - Pace Training Card

    private var paceCard: some View {
        let isSelected = paceSelected
        let tint = paceOption.tint

        return VStack(spacing: 0) {
            Button {
                animateMode {
                    paceSelected = true
                    crutchSelected = false
                }
                CoachHaptic.selectionTap()
            } label: {
                HStack(alignment: .top, spacing: Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(tint.opacity(0.14))
                            .frame(width: 52, height: 52)
                        Image(systemName: paceOption.systemImage)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(tint)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(paceOption.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                        Text(paceOption.subtitle)
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
            }
            .buttonStyle(.pressable)
            .sensoryFeedback(.selection, trigger: isSelected) { _, _ in hapticsSettings.isEnabled }
            .accessibilityIdentifier("practiceMode.paceTraining")
            .accessibilityLabel(paceOption.title)
            .accessibilityHint(paceOption.subtitle)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if isSelected {
                paceQuickStartButton(tint: tint)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                    .transition(reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .move(edge: .top)))
            }
        }
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

    private func paceQuickStartButton(tint: Color) -> some View {
        Button {
            CoachHaptic.selectionTap()
            navigationPath.append(AppDestination.paceTrainingPractice)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.footnote.weight(.bold))
                Text("Start now \u{00B7} Pace Training")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(tint.opacity(0.10), in: Capsule())
            .overlay(
                Capsule().strokeBorder(tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("practiceMode.paceTraining.quickStart")
        .accessibilityLabel("Start now, Pace Training")
        .accessibilityHint("Begins a Pace Training drill.")
    }

    // MARK: - Bottom CTA

    private var startCTA: some View {
        let title = activeStartTitle
        let tint = activeStartTint
        // Match the Coach Card's Begin pattern — "Begin · Pressure Drill"
        // reads as a calm, premium action and keeps the mode name in
        // Title Case rather than mashing it into a lowercase sentence.
        // U+00B7 (middle dot) is the same separator the Coach Card uses.
        let ctaLabel = "Begin \u{00B7} \(title)"
        return Button {
            if paceSelected {
                navigationPath.append(AppDestination.paceTrainingPractice)
            } else if crutchSelected {
                navigationPath.append(AppDestination.cutTheCrutchPractice)
            } else if !PracticeModeAvailability.isUnlocked(selectedMode, rating: ratingStore.rating) {
                selectedMode = .timed
                navigationPath.append(AppDestination.timedPractice)
            } else {
                navigationPath.append(appDestination(for: selectedMode))
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
        .accessibilityHint("Begins a \(title) rep.")
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

    private func computeRecommendation() {
        let context = RecommendationBiasContextBuilder.context(
            profile: coachingProfileStore.profile,
            sessions: sessionStore.sessions,
            sessionStreak: sessionStreak,
            daysSinceLastSession: daysSinceLastSession,
            coachMemory: coachMemoryStore.currentMemory,
            imAvailable: IMModeAvailability.isAvailable,
            summaryStyle: .compact
        )
        let blueprint = visibleBlueprint(from: context.blueprint)
        cachedRecommendedMode = blueprint.recommendedMode
        cachedRecommendedFocus = blueprint.focus
        cachedRecommendedTarget = blueprint.target
        cachedRecommendedScenario = blueprint.recommendedScenario
        cachedRecommendedTone = blueprint.recommendedTone
        // Prefer `whyNow` (the situational hook) over `whyMode` (the
        // mode-benefit), but fall back gracefully and ignore empty
        // strings so we never render a blank line.
        let dynamic = [blueprint.whyNow, blueprint.whyMode]
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        cachedRecommendedReason = dynamic
        recordRecommendationShown(blueprint)
    }

    private func visibleBlueprint(from blueprint: RecommendationBiasBlueprint) -> RecommendationBiasBlueprint {
        let canShowMode = options.contains { $0.mode == blueprint.recommendedMode }
        let isUnlocked = PracticeModeAvailability.isUnlocked(blueprint.recommendedMode, rating: ratingStore.rating)
        guard canShowMode, isUnlocked else {
            let timedBenefit = RecommendationBiasEngine.playbook.first(where: { $0.mode == .timed })
            return RecommendationBiasBlueprint(
                recommendedMode: .timed,
                recommendedTone: nil,
                recommendedScenario: nil,
                focus: "Baseline control",
                target: "One rated rep",
                modeBenefit: timedBenefit?.benefit ?? "Builds a clean, rated speaking baseline.",
                whyMode: timedBenefit?.bestFor ?? "Timed Practice gives Noum the cleanest rated evidence.",
                whyNow: canShowMode
                    ? PracticeModePrescriptionCopy.pressureLockedHint
                    : "Start with a spoken rep while that practice mode is unavailable.",
                suggestedTimedDifficulty: nil,
                suggestedTheme: blueprint.suggestedTheme,
                source: blueprint.source
            )
        }
        return blueprint
    }

    private func recordRecommendationShown(_ blueprint: RecommendationBiasBlueprint) {
        recommendationLearningStore.recordShown(
            fingerprint: recommendationFingerprint(for: blueprint),
            title: recommendedOption.title,
            focus: blueprint.focus,
            target: blueprint.target,
            mode: blueprint.recommendedMode,
            isAIBacked: false
        )
    }

    private func recommendationFingerprint(for blueprint: RecommendationBiasBlueprint) -> String {
        let recent = sessionStore.sessions.prefix(5).map { session in
            "\(session.id.uuidString)-\(session.mode.rawValue)-\(session.fillerWordCount)-\(Int(session.duration))-\(session.score ?? 0)"
        }.joined(separator: "|")
        let profileKey = coachingProfileStore.profile.map {
            "\($0.primaryGoal.rawValue)-\($0.biggestChallenge.rawValue)-\($0.desiredOutcome.rawValue)-\($0.speakingStyleGoal.rawValue)"
        } ?? "no-profile"
        return [
            "modePickerRecommendation",
            profileKey,
            blueprint.source.trackingLabel,
            blueprint.recommendedMode.rawValue,
            blueprint.focus,
            blueprint.target,
            recent
        ].joined(separator: ".")
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
                // Honour the engine's recommended scenario + tone (set
                // only when IM is the recommendation — a tone drill or the
                // goal-based default). Both nil otherwise, so a free-choice
                // IM launch still opens the normal scenario grid.
                return .imPractice(scenario: cachedRecommendedScenario, tone: cachedRecommendedTone)
            } else {
                return .timedPractice
            }
        }
    }

    // MARK: - Recent-session signals (feed RecommendationBiasEngine)

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
