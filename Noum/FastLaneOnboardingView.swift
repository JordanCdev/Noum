#if canImport(SwiftUI)
import SwiftUI

/// Permissionless first value. The two setup choices are deliberately split
/// across separate screens; the resulting read remains structure-only and
/// never creates a spoken `PracticeSession`.
@available(iOS 17.0, macOS 12.0, *)
struct FastLaneOnboardingView: View {
    private enum Phase: Int {
        case context
        case challenge
        case exercise
        case result

        var step: Int { rawValue + 1 }
    }

    @ObservedObject private var profileStore: CoachingProfileStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var responseFocused: Bool

    private let onValueDelivered: (StructuredFirstValueResult) -> Bool
    private let onCompleteSetup: () -> Void
    private let onEnterApp: () -> Void

    @State private var phase: Phase
    @State private var selectedContext: SpeakingContext?
    @State private var selectedChallenge: SpeakingChallenge?
    @State private var response = ""
    @State private var result: StructuredFirstValueResult?
    @State private var saveError: String?

    init(
        profileStore: CoachingProfileStore,
        onValueDelivered: @escaping (StructuredFirstValueResult) -> Bool,
        onCompleteSetup: @escaping () -> Void,
        onEnterApp: @escaping () -> Void
    ) {
        self.profileStore = profileStore
        self.onValueDelivered = onValueDelivered
        self.onCompleteSetup = onCompleteSetup
        self.onEnterApp = onEnterApp
        let draft = profileStore.onboardingDraft
        _selectedContext = State(initialValue: draft?.speakingContext)
        _selectedChallenge = State(initialValue: draft?.speakingChallenge)
        _phase = State(initialValue: draft == nil ? .context : .exercise)
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header

                    switch phase {
                    case .context:
                        contextContent
                    case .challenge:
                        challengeContent
                    case .exercise:
                        exerciseContent
                    case .result:
                        resultContent
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .accessibilityIdentifier("fastLane.screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .center, spacing: Spacing.md) {
                if phase != .context && phase != .result {
                    NoumIconButton(
                        systemName: "chevron.left",
                        accessibilityLabel: "Back",
                        action: goBack
                    )
                }

                Spacer(minLength: 0)

                NoumWaveformMark(
                    state: .idle,
                    size: phase == .result ? 64 : 48
                )
            }

            Text(phase == .result ? "YOUR FIRST READ" : "A QUICK START")
                .font(Typography.micro.weight(.bold))
                .tracking(0.9)
                .foregroundStyle(AppColor.textSecondary)
                .accessibilityIdentifier(phase == .result ? "fastLane.result" : "fastLane.stage")

            Text(headerTitle)
                .font(Typography.figtree(size: 32, weight: .bold, relativeTo: .title))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(headerSubtitle)
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if phase != .result {
                NoumProgressTrack(
                    value: Double(phase.step) / 3,
                    label: "Quick start",
                    valueLabel: "Step \(phase.step) of 3",
                    tint: AppColor.coachingInk
                )
            }
        }
    }

    private var headerTitle: String {
        switch phase {
        case .context: return "Where should speaking feel easier?"
        case .challenge: return "What gets in your way most?"
        case .exercise: return "Try one written rep."
        case .result: return "One useful move, honestly framed."
        }
    }

    private var headerSubtitle: String {
        switch phase {
        case .context:
            return "Choose the situation that matters now."
        case .challenge:
            return "Pick one pattern. You can change this later."
        case .exercise:
            return "Write what you would say. Noum reads the answer's shape—not your delivery."
        case .result:
            return "This is an early structure signal. A spoken rep is needed before Noum can assess pace, fillers, pauses, or delivery."
        }
    }

    private var contextContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            optionSection(
                options: SpeakingContext.allCases,
                selectedID: selectedContext?.id,
                titleFor: \SpeakingContext.title,
                idFor: \SpeakingContext.id,
                accessibilityPrefix: "fastLane.context"
            ) { selectedContext = $0 }

            primaryButton(title: "Continue", action: continueFromContext)
                .disabled(selectedContext == nil)
                .accessibilityIdentifier("fastLane.contextContinue")
        }
    }

    private var challengeContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            optionSection(
                options: SpeakingChallenge.allCases,
                selectedID: selectedChallenge?.id,
                titleFor: \SpeakingChallenge.title,
                idFor: \SpeakingChallenge.id,
                accessibilityPrefix: "fastLane.challenge"
            ) { selectedChallenge = $0 }

            errorMessage

            primaryButton(title: "Start written rep", action: beginExercise)
                .disabled(selectedChallenge == nil)
                .accessibilityIdentifier("fastLane.begin")
                .accessibilityHint("Opens one permissionless written communication exercise.")
        }
    }

    private func optionSection<Option: Identifiable>(
        options: [Option],
        selectedID: Option.ID?,
        titleFor: KeyPath<Option, String>,
        idFor: KeyPath<Option, String>,
        accessibilityPrefix: String,
        select: @escaping (Option) -> Void
    ) -> some View where Option.ID: Equatable {
        VStack(spacing: Spacing.sm) {
            ForEach(options) { option in
                let isSelected = selectedID == option.id
                Button {
                    CoachHaptic.selectionTap()
                    withCalmMotion { select(option) }
                } label: {
                    HStack(spacing: Spacing.md) {
                        Text(option[keyPath: titleFor])
                            .font(Typography.body.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? AppColor.coachingInk : AppColor.neutralReceded)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: 56)
                    .background(
                        isSelected ? AppColor.proQuietSurface : AppColor.cardBackground,
                        in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(isSelected ? AppColor.coachingInk : AppColor.subtleBorder, lineWidth: isSelected ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(accessibilityPrefix).\(option[keyPath: idFor])")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private var exerciseContent: some View {
        if let context = selectedContext ?? profileStore.onboardingDraft?.speakingContext {
            let prompt = StructuredFirstValueCatalog.prompt(for: context)
            VStack(alignment: .leading, spacing: Spacing.lg) {
                NoumSurface(.standard) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("YOUR MOMENT")
                            .font(Typography.micro.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(AppColor.proText)
                        Text(prompt.prompt)
                            .font(Typography.headline)
                            .foregroundStyle(AppColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("fastLane.prompt")

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ZStack(alignment: .topLeading) {
                        if response.isEmpty {
                            Text("Write at least eight words. Keep it close to what you would actually say.")
                                .font(Typography.body)
                                .foregroundStyle(AppColor.textTertiary)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $response)
                            .font(Typography.body)
                            .foregroundStyle(AppColor.textPrimary)
                            .focused($responseFocused)
                            .scrollContentBackground(.hidden)
                            .padding(Spacing.sm)
                            .frame(minHeight: 156)
                            .onChange(of: response) { _, newValue in
                                if newValue.count > 600 {
                                    response = String(newValue.prefix(600))
                                }
                            }
                            .accessibilityLabel("Your written rehearsal")
                            .accessibilityHint("Write at least eight words. Your response is evaluated on this screen and is not saved.")
                            .accessibilityIdentifier("fastLane.response")
                    }
                    .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                            .stroke(AppColor.subtleBorder, lineWidth: 1)
                    )

                    ViewThatFits(in: .horizontal) {
                        HStack {
                            characterCount
                            Spacer()
                            privacyBoundary
                        }

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            characterCount
                            privacyBoundary
                        }
                    }
                }

                errorMessage

                primaryButton(title: "Show my structure read", action: deliverValue)
                    .disabled(structuredResult(for: prompt) == nil)
                    .accessibilityIdentifier("fastLane.submit")
            }
        } else {
            Text("Choose a context to begin.")
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .onAppear { transition(to: .context) }
        }
    }

    private var characterCount: some View {
        Text("\(response.count)/600 characters")
            .font(Typography.caption)
            .foregroundStyle(AppColor.textSecondary)
    }

    private var privacyBoundary: some View {
        Text("Structure only · not saved")
            .font(Typography.caption.weight(.semibold))
            .foregroundStyle(AppColor.textSecondary)
    }

    @ViewBuilder
    private var resultContent: some View {
        if let result {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                NoumSurface(.standard) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Label("Early structure signal", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(Typography.caption.weight(.bold))
                            .foregroundStyle(AppColor.caution)

                        resultSection(label: "What is already working", text: result.strength)
                        Divider()
                        resultSection(label: "One next move", text: result.nextMove)
                    }
                }

                NoumSurface(.quiet) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Label("Evidence boundary", systemImage: "checkmark.shield")
                            .font(Typography.caption.weight(.bold))
                            .foregroundStyle(AppColor.textPrimary)
                        Text("A written rehearsal can show answer shape. A spoken rep later unlocks fillers, pace, pauses, and delivery feedback.")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                errorMessage

                primaryButton(title: "Try a 30-second spoken proof", action: startSpokenProof)
                    .disabled(profileStore.onboardingDraft?.canStartSpokenProof != true)
                    .accessibilityIdentifier("fastLane.spokenProof")
                    .accessibilityHint("Opens a short Timed Practice setup. Recording and microphone permission begin only after you choose to start.")

                secondaryButton(title: "Complete my coaching profile", action: completeSetup)
                    .accessibilityIdentifier("fastLane.completeSetup")
                    .accessibilityHint("Opens the full coaching profile setup. Your two choices are kept.")

                Button(action: enterApp) {
                    Text("Explore Noum first")
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .noumMinimumTouchTarget()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fastLane.enterApp")
                .accessibilityHint("Opens Noum now. You can finish your coaching profile from Home later.")
            }
        }
    }

    private func resultSection(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.textSecondary)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let saveError {
            Text(saveError)
                .font(Typography.caption)
                .foregroundStyle(AppColor.warning)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("fastLane.error")
        }
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(title)
                    .font(Typography.headline)
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.bold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(AppColor.coachingInk, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    private func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.coachingInkOnQuiet)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppColor.proQuietSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(AppColor.coachingInk.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.pressable)
    }

    private func continueFromContext() {
        guard selectedContext != nil else { return }
        transition(to: .challenge)
    }

    private func beginExercise() {
        guard let selectedContext, let selectedChallenge else { return }
        saveError = nil
        guard profileStore.saveDraft(context: selectedContext, challenge: selectedChallenge) else {
            saveError = "Noum couldn't save your two choices. Try again."
            return
        }
        if let draft = profileStore.onboardingDraft {
            FlowEventLog.shared.logOnce(FlowEvent.make(
                correlationId: draft.correlationID,
                flow: .other,
                stage: TransformationKPIEventStage.structuredStarted,
                reason: "permissionless structured exercise opened"
            ))
        }
        transition(to: .exercise)
    }

    private func deliverValue() {
        guard let context = selectedContext ?? profileStore.onboardingDraft?.speakingContext else { return }
        let prompt = StructuredFirstValueCatalog.prompt(for: context)
        guard let nextResult = structuredResult(for: prompt) else { return }
        saveError = nil
        guard onValueDelivered(nextResult) else {
            saveError = "Noum couldn't save this first-value receipt. Your response was not stored. Try again."
            return
        }
        result = nextResult
        response = ""
        responseFocused = false
        transition(to: .result)
    }

    private func structuredResult(for prompt: StructuredFirstValuePrompt) -> StructuredFirstValueResult? {
        RoleplayEngine.evaluateStructuredFirstValue(response: response, prompt: prompt)
    }

    private func completeSetup() {
        logChoice(stage: TransformationKPIEventStage.profileSetupTapped, reason: "profile setup selected after structured value")
        onCompleteSetup()
    }

    private func startSpokenProof() {
        saveError = nil
        guard profileStore.onboardingDraft?.canStartSpokenProof == true,
              let preparation = AutoGuidedFirstRep.prepareUserInitiatedSpokenProof(),
              let route = AutoGuidedFirstRep.routeURL(for: preparation) else {
            saveError = "Noum couldn't prepare the spoken proof. You can still enter Noum and start Timed Practice from Train."
            return
        }
        logChoice(
            stage: TransformationKPIEventStage.liveUpgradeTapped,
            reason: "user initiated spoken proof after structured value"
        )
        DeepLinkRouter.shared.pending = route
        onEnterApp()
    }

    private func enterApp() {
        logChoice(stage: "activation.profileSetupDeferred", reason: "profile setup deferred after structured value")
        onEnterApp()
    }

    private func logChoice(stage: String, reason: String) {
        guard let draft = profileStore.onboardingDraft else { return }
        FlowEventLog.shared.logOnce(FlowEvent.make(
            correlationId: draft.correlationID,
            flow: .other,
            stage: stage,
            reason: reason
        ))
    }

    private func goBack() {
        saveError = nil
        switch phase {
        case .context:
            break
        case .challenge:
            transition(to: .context)
        case .exercise:
            responseFocused = false
            transition(to: .challenge)
        case .result:
            break
        }
    }

    private func withCalmMotion(_ updates: @escaping () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(NoumMotion.animation(for: .calm, reduceMotion: false), updates)
        }
    }

    private func transition(to phase: Phase) {
        withCalmMotion { self.phase = phase }
    }
}
#endif
