#if canImport(SwiftUI)
import SwiftUI

/// Permissionless first-value path. It captures two bounded choices, runs one
/// offline written rehearsal, and returns a structure-only read. It never
/// creates a PracticeSession or enters speech-derived progress systems.
@available(iOS 17.0, macOS 12.0, *)
struct FastLaneOnboardingView: View {
    private enum Phase {
        case choices
        case exercise
        case result
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
        _phase = State(initialValue: draft == nil ? .choices : .exercise)
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    switch phase {
                    case .choices:
                        choicesContent
                    case .exercise:
                        exerciseContent
                    case .result:
                        resultContent
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .accessibilityIdentifier("fastLane.screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(phase == .result ? "FIRST VALUE" : "START IN UNDER A MINUTE")
                .font(Typography.micro.weight(.bold))
                .tracking(0.9)
                .foregroundStyle(AppColor.brandBlue)
                .accessibilityIdentifier(phase == .result ? "fastLane.result" : "fastLane.stage")

            Text(headerTitle)
                .font(Typography.figtree(size: 32, weight: .bold, relativeTo: .title))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(headerSubtitle)
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var headerTitle: String {
        switch phase {
        case .choices: return "Choose one real communication goal."
        case .exercise: return "Try one written rehearsal."
        case .result: return "You have a useful first move."
        }
    }

    private var headerSubtitle: String {
        switch phase {
        case .choices:
            return "No microphone or cloud processing yet. Pick where communication should feel easier and what to work on first."
        case .exercise:
            return "Write the response you would want to say. Noum will read its shape, not pretend to hear your delivery."
        case .result:
            return "This is a structure read from writing. Spoken practice later unlocks delivery feedback."
        }
    }

    private var choicesContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            optionSection(
                title: "Where should this help?",
                options: SpeakingContext.allCases,
                selectedID: selectedContext?.id,
                titleFor: \SpeakingContext.title,
                idFor: \SpeakingContext.id,
                accessibilityPrefix: "fastLane.context"
            ) { selectedContext = $0 }

            optionSection(
                title: "What should feel easier?",
                options: SpeakingChallenge.allCases,
                selectedID: selectedChallenge?.id,
                titleFor: \SpeakingChallenge.title,
                idFor: \SpeakingChallenge.id,
                accessibilityPrefix: "fastLane.challenge"
            ) { selectedChallenge = $0 }

            if let saveError {
                Text(saveError)
                    .font(Typography.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("fastLane.error")
            }

            Button(action: beginExercise) {
                Text("Start written rehearsal")
                    .font(Typography.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.brandBlue)
            .disabled(selectedContext == nil || selectedChallenge == nil)
            .accessibilityIdentifier("fastLane.begin")
            .accessibilityHint("Opens one permissionless written communication exercise.")
        }
    }

    private func optionSection<Option: Identifiable>(
        title: String,
        options: [Option],
        selectedID: Option.ID?,
        titleFor: KeyPath<Option, String>,
        idFor: KeyPath<Option, String>,
        accessibilityPrefix: String,
        select: @escaping (Option) -> Void
    ) -> some View where Option.ID: Equatable {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(Typography.cardLabel)
                .foregroundStyle(AppColor.textPrimary)

            ForEach(options) { option in
                let isSelected = selectedID == option.id
                Button {
                    select(option)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Text(option[keyPath: titleFor])
                            .font(Typography.body.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? AppColor.brandBlue : AppColor.textSecondary)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: 52)
                    .background(
                        isSelected ? AppColor.brandBlue.opacity(0.08) : AppColor.cardBackground,
                        in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(isSelected ? AppColor.brandBlue.opacity(0.35) : AppColor.subtleBorder, lineWidth: 1)
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
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("YOUR MOMENT")
                        .font(Typography.micro.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(AppColor.brandBlue)
                    Text(prompt.prompt)
                        .font(Typography.headline)
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("fastLane.prompt")

                ZStack(alignment: .topLeading) {
                    if response.isEmpty {
                        Text("Write at least eight words. Keep it close to what you would actually say.")
                            .font(Typography.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $response)
                        .font(Typography.body)
                        .focused($responseFocused)
                        .scrollContentBackground(.hidden)
                        .padding(Spacing.sm)
                        .frame(minHeight: 150)
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

                HStack {
                    Text("\(response.count)/600 characters")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text("Structure only · not saved")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                }

                if let saveError {
                    Text(saveError)
                        .font(Typography.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("fastLane.error")
                }

                Button(action: deliverValue) {
                    Text("Show my structure read")
                        .font(Typography.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.brandBlue)
                .disabled(structuredResult(for: prompt) == nil)
                .accessibilityIdentifier("fastLane.submit")
            }
            .onAppear { responseFocused = true }
        } else {
            Text("Choose a context to begin.")
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .onAppear { transition(to: .choices) }
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if let result {
            VStack(alignment: .leading, spacing: Spacing.md) {
                resultRow(
                    label: "What is already working",
                    text: result.strength,
                    systemImage: "checkmark.circle.fill",
                    tint: AppColor.modeAhCounter
                )
                resultRow(
                    label: "One next move",
                    text: result.nextMove,
                    systemImage: "arrow.up.right.circle.fill",
                    tint: AppColor.brandBlue
                )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label("Evidence boundary", systemImage: "text.page")
                        .font(Typography.caption.weight(.bold))
                        .foregroundStyle(AppColor.textSecondary)
                    Text("A written rehearsal can show answer shape. A spoken rep later unlocks fillers, pace, pauses, and delivery feedback.")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.md)
                .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))

                Button(action: completeSetup) {
                    Text("Set up my coaching plan")
                        .font(Typography.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.brandBlue)
                .accessibilityIdentifier("fastLane.completeSetup")
                .accessibilityHint("Continues to the full coaching profile. Your two choices are kept.")

                Button(action: enterApp) {
                    Text("Explore Noum first")
                        .font(Typography.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
                .accessibilityIdentifier("fastLane.enterApp")
                .accessibilityHint("Opens Noum now. You can finish your coaching profile from Home later.")
            }
        }
    }

    private func resultRow(label: String, text: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
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
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
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

    private func transition(to phase: Phase) {
        if reduceMotion {
            self.phase = phase
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                self.phase = phase
            }
        }
    }
}
#endif
