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
                surfaces: "What you reach for when there's no safety net.",
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
    /// IM scenario + tone the recommendation prefills when the picker's
    /// recommended mode is IM Conversation. Carries the tone-drill
    /// scenario/tone when the engine surfaces a sub-40% tone-match
    /// pattern (so tapping the IM tile drops straight into that drill),
    /// otherwise the profile-aligned scenario/tone. `nil` when the
    /// recommendation is not IM, so tapping the IM tile after a non-IM
    /// recommendation stays a default (un-prefilled) rep.
    @State private var cachedRecommendedScenario: IMConversationScenario?
    @State private var cachedRecommendedTone: IMTargetTone?
    /// When true, the picker has the Cut the Crutch tile selected.
    /// Tracked separately because Cut the Crutch isn't a `PracticeMode` —
    /// it's a sibling drill, not a pressure mode.
    @State private var crutchSelected: Bool = false
    /// Per-row expansion state for the "What this trains" affordance.
    /// Set semantics so multiple rows can stay expanded if the user opens
    /// several — explore-then-commit, not modal "one at a time".
    @State private var expandedModes: Set<PracticeMode> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            // Defensive: clear any stale Quick Start flag from a prior
            // arm-then-back-out so the next "Begin" tap doesn't get
            // routed through a one-tap skip the user no longer wants.
            PracticeModeQuickStart.clear()
            PracticeModeQuickStart.clearCrutch()
        }
    }

    // MARK: - Header

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Display treatment — the picker reads as an iOS premium
            // screen header ("pick your next rep" is a curated menu
            // moment), not a settings-list title. The richer 32pt
            // rounded weight is the single biggest signal that the
            // surface below is a curation, not a list.
            Text("Pick your next rep")
                .font(.system(size: 32, weight: .bold, design: .rounded))
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
        let isExpanded = expandedModes.contains(option.mode)

        return VStack(spacing: 0) {
            Button {
                animateMode {
                    selectedMode = option.mode
                    crutchSelected = false
                    // Collapse every other mode so the selected one stands
                    // out and the list stays compact.
                    expandedModes = [option.mode]
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
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("practiceMode.\(option.mode.rawValue)")
            .accessibilityLabel(accessibilityLabel(option, isRecommended: isRecommended))
            .accessibilityHint(option.subtitle)
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

            quickStartButton(for: option)
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

    /// Per-mode CTA copy. "Start now" is the shared verb; the mode
    /// name is appended so accessibility users hear which rep they're
    /// about to launch when scanning the picker linearly.
    private func quickStartLabel(for mode: PracticeMode) -> String {
        switch mode {
        case .timed: return "Start now \u{00B7} Timed"
        case .suddenDeath: return "Start now \u{00B7} Sudden Death"
        case .ahCounter: return "Start now \u{00B7} Ah-Counter"
        case .imConversation: return "Start now \u{00B7} IM Mode"
        }
    }

    /// Reduce-motion shapes the expand/collapse feel. Spring under
    /// normal motion; a short linear fade when the user has opted into
    /// the reduced-motion accessibility setting.
    private func animateMode(_ changes: () -> Void) {
        withAnimation(reduceMotion ? .linear(duration: 0.15) : .snappySpring) {
            changes()
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
        // Match the Coach Card's Begin pattern — "Begin · Sudden Death"
        // reads as a calm, premium action and keeps the mode name in
        // Title Case rather than mashing it into a lowercase sentence.
        // U+00B7 (middle dot) is the same separator the Coach Card uses.
        let ctaLabel = "Begin \u{00B7} \(title)"
        return Button {
            if crutchSelected {
                navigationPath.append(AppDestination.cutTheCrutchPractice)
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
            plan: plan,
            // Same signal source the Home surfaces use: when the user
            // reliably misses the committed tone in one scenario (≥3
            // evaluated reps, sub-40% hit rate) the engine biases to a
            // one-tap re-rep of that exact scenario + tone. Guarded on
            // availability so an offline IM mode falls back to the
            // normal goal-based bias instead of recommending a mode that
            // would just be re-routed to Timed.
            imToneSignal: IMModeAvailability.isAvailable
                ? IMHistorySummary.toneDrillSignal(from: sessionStore.sessions)
                : nil
        )
        cachedRecommendedMode = blueprint.recommendedMode
        // Prefill the IM tile only when the recommendation is actually
        // IM — the engine leaves these nil for every other mode, so a
        // non-IM recommendation can never leak a stale scenario/tone
        // into the IM destination.
        cachedRecommendedScenario = blueprint.recommendedScenario
        cachedRecommendedTone = blueprint.recommendedTone
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
                // Honour the recommendation's prefilled scenario/tone so
                // the one-tap drill the engine surfaced on Home is also
                // offered here. Both nil for a default IM rep.
                return .imPractice(scenario: cachedRecommendedScenario, tone: cachedRecommendedTone)
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
