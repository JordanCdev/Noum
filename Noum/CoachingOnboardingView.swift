#if canImport(SwiftUI)
import SwiftUI

private enum OnboardingStage: Int, CaseIterable {
    // Three load-bearing questions only. Free-text fields (goal text,
    // why-now, success vision) are captured *after* the first rep via
    // contextual prompts so the user speaks before doing reflective setup.
    case context
    case challenge
    case style

    var title: String {
        switch self {
        case .context: return "Where do you want the most help?"
        case .challenge: return "Where do you want the most growth?"
        case .style: return "How should you come across?"
        }
    }

    var subtitle: String {
        switch self {
        case .context: return "Pick the situation Noum should coach first."
        case .challenge: return "Pick the area you'd most like to strengthen."
        case .style: return "Pick the voice you want to reinforce."
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

@available(iOS 17.0, macOS 12.0, *)
struct CoachingOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    var onComplete: (() -> Void)? = nil

    @State private var screen: OnboardingScreen = .intro
    @State private var speakingContext: SpeakingContext = .work
    @State private var biggestChallenge: SpeakingChallenge = .fillerWords
    // No pre-selection — the voice goal drives the entire tailored coaching
    // persona, so the user must actively choose it rather than tap through a
    // defaulted "authoritative." nil until they pick; the continue button on
    // the style stage is gated on a selection.
    @State private var speakingStyleGoal: SpeakingStyleGoal?
    @State private var coachingGoal = ""
    @State private var whyNow = ""
    @State private var successVision = ""
    @State private var isSaving = false
    @State private var showProfileCard = false
    @State private var isEditingExistingProfile = false
    @State private var editorOverlayField: InputField? = nil
    @State private var editorOverlayText = ""
    @FocusState private var focusedField: InputField?
    @FocusState private var overlayEditorFocused: Bool
    @Namespace private var headerNamespace
    private let isRealFirstRunUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING_REAL_FIRST_RUN")

    private enum InputField: Hashable {
        case goal
        case whyNow
        case successVision
    }

    private var currentStage: OnboardingStage? {
        if case let .question(stage) = screen {
            return stage
        }
        return nil
    }

    private var progressStep: Int {
        switch screen {
        case .intro: return 0
        case let .question(stage): return stage.rawValue + 1
        case .summary: return OnboardingStage.allCases.count
        }
    }

    private var progressValue: Double {
        Double(progressStep) / Double(OnboardingStage.allCases.count)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let size = geometry.size

                ZStack {
                    backgroundLayer

                    VStack(spacing: 0) {
                        topBar
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        Spacer(minLength: 6)

                        switch screen {
                        case .intro:
                            introScreen(size: size)
                                .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
                        case let .question(stage):
                            questionScreen(stage: stage, size: size)
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        case .summary:
                            summaryScreen(size: size)
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                        }

                        Spacer(minLength: 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Full-screen text editor overlay
                    if let field = editorOverlayField {
                        editorOverlay(field: field)
                            .transition(.opacity)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear(perform: loadExistingProfile)
    }

    private var backgroundLayer: some View {
        ZStack {
            AppColor.screenBackground
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.20, green: 0.55, blue: 0.98).opacity(0.11))
                .frame(width: 260, height: 260)
                .blur(radius: 36)
                .offset(x: 130, y: 230)

            Circle()
                .fill(Color(red: 1.00, green: 0.77, blue: 0.45).opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 32)
                .offset(x: -120, y: -220)
        }
    }

    private var topBar: some View {
        HStack {
            if screen == .intro {
                Text("Settings")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.35, green: 0.32, blue: 0.27))
            } else if screen != .summary {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(red: 0.23, green: 0.24, blue: 0.28))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.78), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(height: 40)
    }

    private func introScreen(size: CGSize) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            introHeroCard
                .frame(height: min(size.height * 0.62, 450))
                .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
    }

    private var introHeroCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Coaching Profile")
                        .font(Typography.caption)
                        .foregroundStyle(Color.white.opacity(0.74))
                        .textCase(.uppercase)

                    Text("Build a coaching profile that actually changes how you sound.")
                        .font(Typography.figtree(size: 31, weight: .bold, relativeTo: .title))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Noum will shape drills, prompts, and reminders around what matters in real conversations.")
                        .font(Typography.headline.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                progressRing(step: 1, total: OnboardingStage.allCases.count, compact: false)
                    .matchedGeometryEffect(id: "progressRing", in: headerNamespace)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 24) {
                progressPills(activeCount: 0)

                Button {
                    animate(.standardSpring) {
                        screen = .question(.context)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("Begin")
                            .font(.headline.weight(.semibold))

                        Spacer()

                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.16))
                                .frame(width: 44, height: 44)

                            advancingArrowImage(font: .headline.weight(.bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, Spacing.md)
                    .background(
                        LinearGradient(
                            colors: [
                                AppColor.brandBlue,
                                AppColor.brandBlueLight
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule(style: .continuous)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("coaching.start")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroCardBackground.matchedGeometryEffect(id: "heroCard", in: headerNamespace))
    }

    private func questionScreen(stage: OnboardingStage, size: CGSize) -> some View {
        VStack(spacing: 12) {
            compactHeader
                .padding(.horizontal, 20)

            questionCard(stage: stage)
                .padding(.horizontal, 20)
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Building your coaching profile")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("\(progressStep) of \(OnboardingStage.allCases.count) answered")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.72))

                progressPills(activeCount: progressStep)
            }

            Spacer(minLength: 12)

            progressRing(step: progressStep, total: OnboardingStage.allCases.count, compact: true)
                .matchedGeometryEffect(id: "progressRing", in: headerNamespace)
        }
        .frame(height: 82)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(heroCardBackground.matchedGeometryEffect(id: "heroCard", in: headerNamespace))
    }

    private func questionCard(stage: OnboardingStage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(stage.title)
                    .font(Typography.bigStat)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(stage.subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }

            ScrollView {
                VStack(spacing: 10) {
                    switch stage {
                    case .context:
                        optionList(options: SpeakingContext.allCases, selectedID: speakingContext.id) { speakingContext = $0 }
                    case .challenge:
                        optionList(options: SpeakingChallenge.allCases, selectedID: biggestChallenge.id) { biggestChallenge = $0 }
                    case .style:
                        optionList(options: SpeakingStyleGoal.allCases, selectedID: speakingStyleGoal?.id) { speakingStyleGoal = $0 }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.hidden)

            HStack {
                if let helper = helperText(for: stage) {
                    Text(helper)
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button {
                    advance(from: stage)
                } label: {
                    HStack(spacing: 8) {
                        Text(stage == .style ? "Finish" : "Next")
                            .font(.subheadline.weight(.semibold))

                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.16))
                                .frame(width: 34, height: 34)

                            advancingArrowImage(font: .subheadline.weight(.bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: canAdvance(from: stage)
                                ? [
                                    AppColor.brandBlue,
                                    AppColor.brandBlueLight
                                ]
                                : [
                                    Color(red: 0.70, green: 0.73, blue: 0.78),
                                    Color(red: 0.65, green: 0.68, blue: 0.73)
                                ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule(style: .continuous)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 0.18, green: 0.53, blue: 0.98).opacity(canAdvance(from: stage) ? 0.18 : 0), radius: 14, y: 8)
                }
                .buttonStyle(.plain)
                .disabled(!canAdvance(from: stage))
                .accessibilityIdentifier("coaching.continue")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .fill(Color.white.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(Color.white.opacity(0.90), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)
    }

    private func summaryScreen(size: CGSize) -> some View {
        VStack(spacing: 0) {
            if showProfileCard {
                // Interactive profile summary card
                profileSummaryCard(size: size)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                Spacer()

                completionState
                    .padding(.horizontal, 40)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startCompletionReveal()
        }
    }

    private var completionState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColor.brandBlue,
                                Color(red: 0.33, green: 0.70, blue: 1.00)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: AppColor.brandBlue.opacity(0.3), radius: 30, y: 10)

                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            }
            .transition(.scale(scale: 0.5).combined(with: .opacity))

            VStack(spacing: 8) {
                Text(isEditingExistingProfile ? "Profile updated." : "Welcome to Noum.")
                    .font(Typography.screenTitle)
                    .foregroundStyle(AppColor.textPrimary)

                Text(isEditingExistingProfile
                    ? "Your coaching is now recalibrated."
                    : "Your coaching journey starts now.")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .transition(.opacity.combined(with: .offset(y: 16)))
        }
    }

    private func profileSummaryCard(size: CGSize) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Header
                    VStack(spacing: Spacing.xs) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppColor.brandBlue,
                                            Color(red: 0.33, green: 0.70, blue: 1.00)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                                .shadow(color: AppColor.brandBlue.opacity(0.25), radius: 16, y: 6)

                            Image(systemName: "person.text.rectangle.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.bottom, Spacing.xxs)

                        Text("Your Coaching Profile")
                            .font(Typography.bigStat)
                            .foregroundStyle(AppColor.textPrimary)

                        Text("Here's how Noum will coach you.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.lg)

                    // Profile detail rows
                    VStack(spacing: Spacing.sm) {
                        profileRow(
                            icon: "mappin.and.ellipse",
                            label: "Focus area",
                            value: speakingContext.title
                        )

                        profileRow(
                            icon: "flame.fill",
                            label: "Biggest challenge",
                            value: biggestChallenge.title
                        )

                        profileRow(
                            icon: "wand.and.stars",
                            label: "Style goal",
                            value: speakingStyleGoal?.title ?? "Not chosen yet"
                        )

                        if !coachingGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            profileRow(
                                icon: "target",
                                label: "Your goal",
                                value: coachingGoal.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        }

                        if !whyNow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            profileRow(
                                icon: "bolt.fill",
                                label: "Why now",
                                value: whyNow.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        }

                        if !successVision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            profileRow(
                                icon: "star.fill",
                                label: "Success looks like",
                                value: successVision.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .padding(.bottom, Spacing.lg)
            }
            .scrollIndicators(.hidden)

            // CTA button pinned at bottom
            VStack(spacing: 0) {
                Divider()
                    .opacity(0.3)

                Button {
                    if !isEditingExistingProfile {
                        // First-run: don't drop the brand-new user on a cold Home.
                        // Route straight to their prescribed first rep (the picker
                        // leads with the Coach Pick + Begin). Iteration 3 — first
                        // felt value before Home. (Editing from Settings just saves.)
                        DeepLinkRouter.shared.pending = URL(string: "noum://train")
                    }
                    saveProfile()
                    onComplete?()
                    dismiss()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Text(isEditingExistingProfile ? "Save Changes" : "Start Practicing")
                            .font(.headline.weight(.semibold))

                        Spacer()

                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.16))
                                .frame(width: 44, height: 44)

                            Image(systemName: isEditingExistingProfile ? "checkmark" : "arrow.right")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(
                        LinearGradient(
                            colors: [
                                AppColor.brandBlue,
                                AppColor.brandBlueLight
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule(style: .continuous)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: AppColor.brandBlue.opacity(0.22), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("coaching.startPracticing")
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xs)
            }
        }
        .padding(.top, Spacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func profileRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .fill(AppColor.brandBlue.opacity(0.10))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(label.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.textSecondary)

                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.white.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(Color(red: 0.90, green: 0.92, blue: 0.96), lineWidth: 1)
        )
    }

    private func startCompletionReveal() {
        guard !showProfileCard else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingCompletionTiming.profileRevealDelay) {
            animate(.standardSpring) {
                showProfileCard = true
            }
        }
    }

    private func optionList<Option: Identifiable & CaseIterable & Hashable>(
        options: Option.AllCases,
        selectedID: Option.ID?,
        onSelect: @escaping (Option) -> Void
    ) -> some View where Option.AllCases.Element == Option, Option: CustomStringConvertible {
        VStack(spacing: 8) {
            ForEach(Array(options), id: \.id) { option in
                // `selectedID` is optional so the voice stage can render with
                // nothing pre-selected — no option highlights until the user
                // taps (`option.id == nil` is always false).
                let isSelected = selectedID != nil && option.id == selectedID
                let detail = optionDetail(for: option)

                Button {
                    animate(.snappySpring) {
                        onSelect(option)
                    }
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.description)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color(red: 0.14, green: 0.16, blue: 0.21))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)

                            if isSelected, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(Color(red: 0.43, green: 0.46, blue: 0.52))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .transition(.opacity)
                            }
                        }

                        Spacer(minLength: 12)

                        ZStack {
                            Circle()
                                .fill(isSelected ? AppColor.brandBlue : Color.clear)
                                .frame(width: 28, height: 28)
                            Circle()
                                .stroke(isSelected ? AppColor.brandBlue : Color(red: 0.80, green: 0.83, blue: 0.88), lineWidth: 2)
                                .frame(width: 28, height: 28)
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 54)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(isSelected ? Color(red: 0.92, green: 0.96, blue: 1.00) : Color(red: 0.97, green: 0.98, blue: 1.00))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(
                                isSelected ? Color(red: 0.57, green: 0.76, blue: 0.98) : Color(red: 0.89, green: 0.92, blue: 0.96),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(color: isSelected ? Color(red: 0.18, green: 0.53, blue: 0.98).opacity(0.08) : .clear, radius: 10, y: 5)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("coaching.option.\(option.id)")
            }
        }
    }

    private func editorCard(
        prompt: String,
        text: Binding<String>,
        field: InputField,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your answer")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.38, green: 0.41, blue: 0.48))
                    .textCase(.uppercase)

                Spacer()

                Text("\(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).count)/200")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(red: 0.56, green: 0.59, blue: 0.64))
            }

            Button {
                editorOverlayText = text.wrappedValue
                animate(.standardSpring) {
                    editorOverlayField = field
                }
            } label: {
                ZStack(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(prompt)
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 0.56, green: 0.59, blue: 0.65))
                    } else {
                        Text(text.wrappedValue)
                            .font(.body)
                            .foregroundStyle(AppColor.textPrimary)
                    }
                }
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .fill(Color(red: 0.97, green: 0.98, blue: 1.00))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .stroke(Color(red: 0.88, green: 0.91, blue: 0.95), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
        }
    }

    private func editorOverlay(field: InputField) -> some View {
        let title: String
        let prompt: String
        let binding: Binding<String>

        // Editor overlay is reused by `DeferredProfileCapture` (post-first-rep
        // prompts). The titles match the questions the deferred prompts ask.
        switch field {
        case .goal:
            title = "What do you want to get better at?"
            prompt = "Example: lead updates in meetings without second-guessing every sentence."
            binding = $coachingGoal
        case .whyNow:
            title = "Why does this matter right now?"
            prompt = "Example: I need to sound sharper in high-visibility conversations."
            binding = $whyNow
        case .successVision:
            title = "If this improves, what changes?"
            prompt = "Example: I will feel calmer, clearer, and more credible at work."
            binding = $successVision
        }

        let limitedOverlay = limitedBinding($editorOverlayText, maxLength: 200)

        return ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    commitOverlayText(to: binding)
                }

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(2)

                    Spacer()

                    Button {
                        commitOverlayText(to: binding)
                    } label: {
                        Text("Done")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(AppColor.brandBlue)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Character count
                HStack {
                    Spacer()
                    Text("\(editorOverlayText.trimmingCharacters(in: .whitespacesAndNewlines).count)/200")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color(red: 0.56, green: 0.59, blue: 0.64))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                // Text editor
                ZStack(alignment: .topLeading) {
                    if editorOverlayText.isEmpty {
                        Text(prompt)
                            .font(.body)
                            .foregroundStyle(Color(red: 0.56, green: 0.59, blue: 0.65))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                    }

                    TextEditor(text: limitedOverlay)
                        .focused($overlayEditorFocused)
                        .font(.body)
                        .foregroundStyle(AppColor.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 30, y: 15)
            )
            .padding(.horizontal, 12)
            .padding(.top, 60)
            .padding(.bottom, 8)
        }
        .onAppear {
            overlayEditorFocused = true
        }
    }

    private func commitOverlayText(to binding: Binding<String>) {
        binding.wrappedValue = editorOverlayText
        overlayEditorFocused = false
        animate(.snappySpring) {
            editorOverlayField = nil
        }
    }

    private var heroCardBackground: some View {
        RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.27, green: 0.25, blue: 0.23),
                        Color(red: 0.36, green: 0.34, blue: 0.31)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 20, y: 12)
    }

    private func progressRing(step: Int, total: Int, compact: Bool) -> some View {
        let size: CGFloat = compact ? 48 : 72

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: compact ? 6 : 7)
            Circle()
                .trim(from: 0, to: max(0.06, Double(step) / Double(total)))
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(red: 1.00, green: 0.79, blue: 0.42),
                            Color(red: 0.33, green: 0.70, blue: 1.00)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: compact ? 6 : 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(step == 0 ? 1 : step)")
                .font(.system(size: compact ? 16 : 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    private func progressPills(activeCount: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<OnboardingStage.allCases.count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < activeCount ? AppColor.brandBlue : Color.white.opacity(0.22))
                    .frame(height: 6)
            }
        }
    }

    @ViewBuilder
    private func advancingArrowImage(font: Font) -> some View {
        let image = Image(systemName: "arrow.right")
            .font(font)
            .foregroundStyle(.white)
        if reduceMotion {
            image
        } else {
            image.symbolEffect(.bounce, value: progressStep)
        }
    }

    private func helperText(for stage: OnboardingStage) -> String? {
        // Multi-choice stages don't need helper text.
        nil
    }

    private func canAdvance(from stage: OnboardingStage) -> Bool {
        // Context + challenge keep sensible defaults so the user can always
        // advance. The VOICE stage requires an explicit pick — it drives the
        // entire tailored coaching persona, so we never let a tap-through
        // assign a phantom default.
        switch stage {
        case .style:
            return speakingStyleGoal != nil
        case .context, .challenge:
            return true
        }
    }

    private func advance(from stage: OnboardingStage) {
        guard canAdvance(from: stage) else { return }
        focusedField = nil

        if let next = OnboardingStage(rawValue: stage.rawValue + 1) {
            animate(.standardSpring) {
                screen = .question(next)
            }
        } else {
            animate(.standardSpring) {
                screen = .summary
            }
        }
    }

    private func goBack() {
        focusedField = nil

        switch screen {
        case .intro:
            dismiss()
        case let .question(stage):
            if let previous = OnboardingStage(rawValue: stage.rawValue - 1) {
                animate(.standardSpring) {
                    screen = .question(previous)
                }
            } else {
                animate(.standardSpring) {
                    screen = .intro
                }
            }
        case .summary:
            break
        }
    }

    private func animate(_ animation: Animation, _ updates: @escaping () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(animation, updates)
        }
    }

    private func saveProfile() {
        guard !isSaving else { return }
        // Voice is required to finish onboarding (the continue button on the
        // style stage is gated on it), so a nil here is a programmer error, not
        // a user path — bail rather than persist a phantom default.
        guard let chosenVoice = speakingStyleGoal else { return }
        isSaving = true

        coachingProfileStore.save(
            CoachingProfile(
                speakingContext: speakingContext,
                primaryGoal: biggestChallenge.recommendedPriority,
                confidenceLevel: .rebuilding,
                biggestChallenge: biggestChallenge,
                desiredOutcome: chosenVoice.recommendedOutcome,
                speakingStyleGoal: chosenVoice,
                styleReference: "",
                coachingBrief: coachingGoal.trimmingCharacters(in: .whitespacesAndNewlines),
                motivationWhyNow: whyNow.trimmingCharacters(in: .whitespacesAndNewlines),
                successVision: successVision.trimmingCharacters(in: .whitespacesAndNewlines),
                chosenStyleGoal: chosenVoice   // finishing onboarding IS an explicit choice
            )
        )
    }

    private func limitedBinding(_ binding: Binding<String>, maxLength: Int) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                binding.wrappedValue = String(newValue.prefix(maxLength))
            }
        )
    }

    private func loadExistingProfile() {
        guard !isRealFirstRunUITesting else { return }
        guard let profile = coachingProfileStore.profile else { return }
        isEditingExistingProfile = true
        speakingContext = profile.speakingContext
        biggestChallenge = profile.biggestChallenge
        // Pre-fill the picker from the user's real prior choice (nil-safe: a
        // legacy profile that was never genuinely chosen leaves the picker
        // empty so they pick deliberately when editing).
        speakingStyleGoal = profile.chosenStyleGoal
        coachingGoal = profile.coachingBrief.trimmingCharacters(in: .whitespacesAndNewlines)
        whyNow = profile.motivationWhyNow.trimmingCharacters(in: .whitespacesAndNewlines)
        successVision = profile.successVision.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func optionDetail<Option: Identifiable & Hashable>(for option: Option) -> String where Option: CustomStringConvertible {
        switch option {
        case let context as SpeakingContext:
            switch context {
            case .work: return "Meetings, updates, and everyday work conversations."
            case .interviews: return "Faster answers under pressure."
            case .presentations: return "Stronger openings and clearer delivery."
            case .social: return "More natural confidence in regular conversation."
            }
        case let challenge as SpeakingChallenge:
            switch challenge {
            case .fillerWords: return "Sound more deliberate instead of hesitant."
            case .rambling: return "Keep your structure instead of drifting."
            case .freezing: return "Recover faster when put on the spot."
            case .rushing: return "Slow down enough to stay composed."
            }
        case let style as SpeakingStyleGoal:
            let desc = style.coachingDescription
            return desc.prefix(1).uppercased() + desc.dropFirst() + "."
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
