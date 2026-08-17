#if canImport(SwiftUI)
import SwiftUI

private enum OnboardingStage: Int, CaseIterable {
    // Free-text goals remain deferred until after the first rep. These three
    // choices are the minimum needed to prescribe an honest starting rep.
    case context
    case challenge
    case style

    var title: String {
        switch self {
        case .context: return "Where should training help first?"
        case .challenge: return "What should feel easier?"
        case .style: return "How do you want to sound?"
        }
    }

    var subtitle: String {
        switch self {
        case .context: return "Choose the situation that matters most right now."
        case .challenge: return "Pick the pattern Noum should target in your first rep."
        case .style: return "Choose a delivery quality—not a personality label."
        }
    }
}

private enum OnboardingScreen: Equatable {
    case intro
    case question(OnboardingStage)
    case summary
}

enum OnboardingCompletionTiming {
    static let profileRevealDelay: Double = 0.35
}

enum CoachingOnboardingCompletionPolicy {
    static let persistenceError = "Noum couldn't save your coaching direction. Try again."

    static func shouldAdvance(profileSaveSucceeded: Bool) -> Bool {
        profileSaveSucceeded
    }
}

@available(iOS 17.0, macOS 12.0, *)
struct CoachingOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared

    private let prefill: CoachingProfileDraft?
    private let onComplete: (() -> Void)?
    private let onDefer: (() -> Void)?

    @State private var screen: OnboardingScreen = .intro
    // A clean first run has no phantom defaults. Each saved value reflects a
    // tap, while editing and fast-lane handoff may truthfully prefill it.
    @State private var speakingContext: SpeakingContext?
    @State private var biggestChallenge: SpeakingChallenge?
    @State private var usesCustomChallenge = false
    @State private var customChallengeText = ""
    // The voice goal changes prescriptions and language, so it is never
    // silently defaulted. The user must choose it explicitly.
    @State private var speakingStyleGoal: SpeakingStyleGoal?
    @State private var coachingGoal = ""
    @State private var whyNow = ""
    @State private var successVision = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var isEditingExistingProfile = false
    @FocusState private var customChallengeFocused: Bool

    #if DEBUG
    private let isRealFirstRunUITesting =
        KeychainHelper.uiAutomationLaunchMode(
            arguments: ProcessInfo.processInfo.arguments
        ) == .realFirstRun
    #else
    private let isRealFirstRunUITesting = false
    #endif

    init(
        prefill: CoachingProfileDraft? = nil,
        onComplete: (() -> Void)? = nil,
        onDefer: (() -> Void)? = nil
    ) {
        self.prefill = prefill
        self.onComplete = onComplete
        self.onDefer = onDefer
    }

    private var progressStep: Int {
        switch screen {
        case .intro: return 0
        case let .question(stage): return stage.rawValue + 1
        case .summary: return OnboardingStage.allCases.count
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.screenBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.top, Spacing.xs)

                    Group {
                        switch screen {
                        case .intro:
                            introScreen
                        case let .question(stage):
                            questionScreen(stage: stage)
                        case .summary:
                            summaryScreen
                        }
                    }
                    .transition(.opacity)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear(perform: loadExistingProfile)
        .accessibilityIdentifier("coaching.screen")
    }

    private var topBar: some View {
        HStack(spacing: Spacing.sm) {
            if screen == .intro {
                Text(isEditingExistingProfile ? "Settings" : "Noum")
                    .font(Typography.headline)
                    .foregroundStyle(AppColor.textPrimary)

                Spacer()

                if isEditingExistingProfile {
                    NoumIconButton(
                        systemName: "xmark",
                        accessibilityLabel: "Close coaching profile",
                        action: { dismiss() }
                    )
                }
            } else {
                NoumIconButton(
                    systemName: "chevron.left",
                    accessibilityLabel: "Back",
                    action: goBack
                )

                Spacer()

                Text(screen == .summary ? "Review" : "Choice \(progressStep) of 3")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .frame(minHeight: NoumControlMetric.minimumTouchTarget)
    }

    private var introScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                NoumWaveformMark(state: .idle, size: 80)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(isEditingExistingProfile ? "YOUR COACHING PROFILE" : "YOUR FIRST TRAINING PLAN")
                        .font(Typography.micro.weight(.bold))
                        .tracking(0.9)
                        .foregroundStyle(AppColor.textSecondary)

                    Text(isEditingExistingProfile
                        ? "Refine what Noum trains next."
                        : "Three choices. Then one focused rep.")
                        .font(Typography.figtree(size: 34, weight: .bold, relativeTo: .largeTitle))
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(isEditingExistingProfile
                        ? "Your saved evidence stays intact. These choices only change the training emphasis."
                        : "Noum starts with a hypothesis, listens to what you actually say, and adapts from evidence.")
                        .font(Typography.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                NoumSurface(.quiet) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        onboardingPromise(
                            title: "One decision at a time",
                            detail: "Situation, challenge, then delivery goal."
                        )
                        onboardingPromise(
                            title: "No microphone yet",
                            detail: "Recording starts only after you choose to begin a rep."
                        )
                        onboardingPromise(
                            title: "No invented diagnosis",
                            detail: "The first rep sets the evidence boundary."
                        )
                    }
                }

                VStack(spacing: Spacing.sm) {
                    primaryButton(
                        title: isEditingExistingProfile ? "Review profile" : "Build my first plan",
                        action: { transition(to: .question(.context)) }
                    )
                    .accessibilityIdentifier("coaching.start")

                    if let onDefer, !isEditingExistingProfile {
                        Button(action: onDefer) {
                            Text("Explore first")
                                .font(Typography.body.weight(.semibold))
                                .foregroundStyle(AppColor.textSecondary)
                                .frame(maxWidth: .infinity)
                                .noumMinimumTouchTarget()
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("coaching.defer")
                        .accessibilityHint("Returns to Noum. Your two earlier choices stay saved.")
                    }
                }
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
    }

    private func onboardingPromise(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
            Text(detail)
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func questionScreen(stage: OnboardingStage) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .center, spacing: Spacing.md) {
                    NoumWaveformMark(state: .idle, size: 48)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(stage.title)
                            .font(Typography.figtree(size: 28, weight: .bold, relativeTo: .title2))
                            .foregroundStyle(AppColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(stage.subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                NoumProgressTrack(
                    value: Double(progressStep) / Double(OnboardingStage.allCases.count),
                    label: "Coaching direction",
                    valueLabel: "\(progressStep) of \(OnboardingStage.allCases.count)",
                    tint: AppColor.coachingInk
                )
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.vertical, Spacing.sm)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.sm) {
                    switch stage {
                    case .context:
                        optionList(
                            options: SpeakingContext.allCases,
                            selectedID: speakingContext?.id,
                            title: \SpeakingContext.title,
                            id: \SpeakingContext.id
                        ) { speakingContext = $0 }
                    case .challenge:
                        challengeOptionList
                    case .style:
                        optionList(
                            options: SpeakingStyleGoal.allCases,
                            selectedID: speakingStyleGoal?.id,
                            title: \SpeakingStyleGoal.title,
                            id: \SpeakingStyleGoal.id
                        ) { speakingStyleGoal = $0 }
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.vertical, Spacing.sm)
                .padding(.bottom, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)

            questionFooter(stage: stage)
        }
    }

    private func questionFooter(stage: OnboardingStage) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if usesCustomChallenge && stage == .challenge {
                Text("Your wording is saved; Noum maps it to the closest first drill.")
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            primaryButton(title: "Continue", action: { advance(from: stage) })
                .disabled(!canAdvance(from: stage))
                .accessibilityIdentifier("coaching.continue")
        }
        .padding(.horizontal, Spacing.screenH)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(AppColor.screenBackground)
    }

    private var summaryScreen: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    HStack(alignment: .center, spacing: Spacing.md) {
                        NoumWaveformMark(state: .idle, size: 64)

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("YOUR STARTING DIRECTION")
                                .font(Typography.micro.weight(.bold))
                                .tracking(0.8)
                                .foregroundStyle(AppColor.textSecondary)
                            Text("One focus for the first rep.")
                                .font(Typography.figtree(size: 30, weight: .bold, relativeTo: .title))
                                .foregroundStyle(AppColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    NoumSurface(.standard) {
                        VStack(spacing: Spacing.md) {
                            profileRow(label: "Situation", value: speakingContext?.title ?? "Choose a situation")
                            Divider()
                            profileRow(label: "First focus", value: displayedChallengeTitle)
                            Divider()
                            profileRow(label: "Delivery goal", value: speakingStyleGoal?.title ?? "Choose a goal")
                        }
                    }

                    NoumSurface(.quiet) {
                        HStack(alignment: .top, spacing: Spacing.md) {
                            NoumWaveformMark(state: .idle, size: 44)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Starting hypothesis")
                                    .font(Typography.caption.weight(.bold))
                                    .foregroundStyle(AppColor.textPrimary)
                                Text(coachCommitmentLine)
                                    .font(Typography.body)
                                    .foregroundStyle(AppColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("How Noum will coach you. \(coachCommitmentLine)")
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }

            summaryFooter
        }
    }

    private var summaryFooter: some View {
        VStack(spacing: Spacing.sm) {
            if let saveError {
                ErrorCard(message: saveError)
                    .accessibilityIdentifier("coaching.saveError")
            }

            primaryButton(
                title: isSaving
                    ? "Saving…"
                    : (isEditingExistingProfile ? "Save changes" : "Start first rep"),
                action: { Task { await finishOnboarding() } },
                showsProgress: isSaving
            )
            .disabled(
                isSaving
                    || speakingContext == nil
                    || biggestChallenge == nil
                    || speakingStyleGoal == nil
            )
            .accessibilityIdentifier("coaching.startPracticing")
        }
        .padding(.horizontal, Spacing.screenH)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(AppColor.screenBackground)
    }

    private func profileRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func optionList<Option: Identifiable>(
        options: [Option],
        selectedID: Option.ID?,
        title: KeyPath<Option, String>,
        id: KeyPath<Option, String>,
        onSelect: @escaping (Option) -> Void
    ) -> some View where Option.ID: Equatable {
        VStack(spacing: Spacing.sm) {
            ForEach(options) { option in
                let isSelected = selectedID == option.id
                optionButton(
                    title: option[keyPath: title],
                    detail: optionDetail(for: option),
                    isSelected: isSelected,
                    accessibilityID: "coaching.option.\(option[keyPath: id])"
                ) {
                    onSelect(option)
                }
            }
        }
    }

    private var challengeOptionList: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(SpeakingChallenge.allCases) { challenge in
                let isSelected = !usesCustomChallenge && biggestChallenge == challenge
                optionButton(
                    title: challenge.title,
                    detail: optionDetail(for: challenge),
                    isSelected: isSelected,
                    accessibilityID: "coaching.option.\(challenge.id)"
                ) {
                    customChallengeFocused = false
                    usesCustomChallenge = false
                    biggestChallenge = challenge
                }
            }

            customChallengeOption
        }
    }

    private var customChallengeOption: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            optionButton(
                title: "Something else",
                detail: "Describe the pattern in your own words.",
                isSelected: usesCustomChallenge,
                accessibilityID: "coaching.option.customChallenge"
            ) {
                usesCustomChallenge = true
                biggestChallenge = SpeakingChallenge.routingFallback(forCustomText: customChallengeText)
                customChallengeFocused = true
            }

            if usesCustomChallenge {
                TextField(
                    "Example: I sound defensive when challenged",
                    text: limitedBinding($customChallengeText, maxLength: 90),
                    axis: .vertical
                )
                .focused($customChallengeFocused)
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2...3)
                .padding(Spacing.md)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(AppColor.coachingInk, lineWidth: 2)
                )
                .submitLabel(.next)
                .onChange(of: customChallengeText) { _, newValue in
                    biggestChallenge = SpeakingChallenge.routingFallback(forCustomText: newValue)
                }
                .onSubmit {
                    if canAdvance(from: .challenge) {
                        advance(from: .challenge)
                    }
                }
                .accessibilityIdentifier("coaching.customChallenge.input")
                .transition(.opacity)
            }
        }
    }

    private func optionButton(
        title: String,
        detail: String,
        isSelected: Bool,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            CoachHaptic.selectionTap()
            withCalmMotion(action)
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if isSelected && !detail.isEmpty {
                        Text(detail)
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppColor.coachingInk : AppColor.neutralReceded)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
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
        .accessibilityIdentifier(accessibilityID)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func primaryButton(
        title: String,
        action: @escaping () -> Void,
        showsProgress: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(title)
                    .font(Typography.headline)

                Spacer(minLength: 0)

                if showsProgress {
                    ProgressView()
                        .tint(.white)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(AppColor.coachingInk, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    private func canAdvance(from stage: OnboardingStage) -> Bool {
        switch stage {
        case .context:
            return speakingContext != nil
        case .challenge:
            if usesCustomChallenge {
                return customChallengeText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
            }
            return biggestChallenge != nil
        case .style:
            return speakingStyleGoal != nil
        }
    }

    private func advance(from stage: OnboardingStage) {
        guard canAdvance(from: stage) else { return }
        CoachHaptic.selectionTap()
        customChallengeFocused = false

        if let next = OnboardingStage(rawValue: stage.rawValue + 1) {
            transition(to: .question(next))
        } else {
            transition(to: .summary)
        }
    }

    private func goBack() {
        customChallengeFocused = false
        saveError = nil

        switch screen {
        case .intro:
            dismiss()
        case let .question(stage):
            if let previous = OnboardingStage(rawValue: stage.rawValue - 1) {
                transition(to: .question(previous))
            } else {
                transition(to: .intro)
            }
        case .summary:
            transition(to: .question(.style))
        }
    }

    private func transition(to next: OnboardingScreen) {
        withCalmMotion { screen = next }
    }

    private func withCalmMotion(_ updates: @escaping () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(NoumMotion.animation(for: .calm, reduceMotion: false), updates)
        }
    }

    @MainActor
    private func finishOnboarding() async {
        guard !isSaving else { return }
        saveError = nil
        isSaving = true

        do {
            try await saveProfile()
        } catch {
            isSaving = false
            saveError = (error as? LocalizedError)?.errorDescription
                ?? CoachingOnboardingCompletionPolicy.persistenceError
            return
        }

        isSaving = false
        CoachHaptic.drillStart()
        if let onComplete {
            onComplete()
        } else {
            dismiss()
        }
    }

    private func saveProfile() async throws {
        guard let chosenVoice = speakingStyleGoal,
              let chosenContext = speakingContext,
              let chosenChallenge = biggestChallenge else {
            throw CoachingProfilePersistenceError.encodingFailed
        }
        let trimmedCustomChallenge = customChallengeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedChallenge = usesCustomChallenge
            ? SpeakingChallenge.routingFallback(forCustomText: trimmedCustomChallenge)
            : chosenChallenge

        try await coachingProfileStore.saveForOnboarding(
            CoachingProfile(
                speakingContext: chosenContext,
                primaryGoal: savedChallenge.recommendedPriority,
                confidenceLevel: .rebuilding,
                biggestChallenge: savedChallenge,
                customChallengeText: usesCustomChallenge ? trimmedCustomChallenge : nil,
                desiredOutcome: chosenVoice.recommendedOutcome,
                speakingStyleGoal: chosenVoice,
                styleReference: "",
                coachingBrief: coachingGoal.trimmingCharacters(in: .whitespacesAndNewlines),
                motivationWhyNow: whyNow.trimmingCharacters(in: .whitespacesAndNewlines),
                successVision: successVision.trimmingCharacters(in: .whitespacesAndNewlines),
                chosenStyleGoal: chosenVoice
            )
        )
    }

    private func limitedBinding(_ binding: Binding<String>, maxLength: Int) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = String($0.prefix(maxLength)) }
        )
    }

    private func loadExistingProfile() {
        if !isRealFirstRunUITesting, let profile = coachingProfileStore.profile {
            isEditingExistingProfile = true
            speakingContext = profile.speakingContext
            biggestChallenge = profile.biggestChallenge
            customChallengeText = profile.customChallengeText ?? ""
            usesCustomChallenge = !customChallengeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            speakingStyleGoal = profile.chosenStyleGoal
            coachingGoal = profile.coachingBrief.trimmingCharacters(in: .whitespacesAndNewlines)
            whyNow = profile.motivationWhyNow.trimmingCharacters(in: .whitespacesAndNewlines)
            successVision = profile.successVision.trimmingCharacters(in: .whitespacesAndNewlines)
            return
        }

        // A fast-lane draft can prefill only the two choices the user made. It
        // cannot invent a voice goal or become a complete coaching profile.
        if let prefill {
            speakingContext = prefill.speakingContext
            biggestChallenge = prefill.speakingChallenge
            customChallengeText = ""
            usesCustomChallenge = false
        }
    }

    private var displayedChallengeTitle: String {
        if usesCustomChallenge {
            let trimmed = customChallengeText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return biggestChallenge?.title ?? "Choose a focus"
    }

    private var coachCommitmentLine: String {
        let focus = biggestChallenge?.trainingFocusFragment ?? "your first speaking focus"
        let stance = "The first rep sets the evidence; then Noum can name one useful move."
        if let style = speakingStyleGoal {
            return "Noum will help you \(style.coachingDescription), starting with \(focus). \(stance)"
        }
        return "Noum will start with \(focus). \(stance)"
    }

    private func optionDetail<Option>(for option: Option) -> String {
        switch option {
        case let context as SpeakingContext:
            switch context {
            case .work: return "Meetings, updates, and everyday work conversations."
            case .interviews: return "Clearer answers when the stakes rise."
            case .presentations: return "Stronger openings and steadier delivery."
            case .social: return "More natural confidence in regular conversation."
            }
        case let challenge as SpeakingChallenge:
            switch challenge {
            case .fillerWords: return "Replace hesitation with deliberate pauses."
            case .rambling: return "Hold a clear point without drifting."
            case .freezing: return "Recover faster when put on the spot."
            case .rushing: return "Keep control when pressure speeds you up."
            }
        case let style as SpeakingStyleGoal:
            let description = style.coachingDescription
            return description.prefix(1).uppercased() + description.dropFirst() + "."
        default:
            return ""
        }
    }
}

extension SpeakingContext: CustomStringConvertible {
    var description: String { title }
}

extension CoachingPriority: CustomStringConvertible {
    var description: String { title }
}

extension ConfidenceLevel: CustomStringConvertible {
    var description: String { title }
}

extension SpeakingChallenge: CustomStringConvertible {
    var description: String { title }
}

extension SpeakingOutcome: CustomStringConvertible {
    var description: String { title }
}

extension SpeakingStyleGoal: CustomStringConvertible {
    var description: String { title }
}
#endif
