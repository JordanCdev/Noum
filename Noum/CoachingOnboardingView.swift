#if canImport(SwiftUI)
import SwiftUI

private enum OnboardingStep: Int, CaseIterable {
    case context
    case challenge
    case style
    case goal

    var title: String {
        switch self {
        case .context: return "Where do you want the most help?"
        case .challenge: return "What usually breaks first?"
        case .style: return "How should you come across?"
        case .goal: return "What are you trying to achieve?"
        }
    }

    var subtitle: String {
        switch self {
        case .context: return "Pick the main situation you want Noum to coach."
        case .challenge: return "Choose the pattern that costs you the most."
        case .style: return "Pick the voice you want practice to reinforce."
        case .goal: return "One short answer is enough."
        }
    }
}

@available(iOS 17.0, macOS 12.0, *)
struct CoachingOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared

    @State private var step: OnboardingStep = .context
    @State private var speakingContext: SpeakingContext = .work
    @State private var biggestChallenge: SpeakingChallenge = .fillerWords
    @State private var speakingStyleGoal: SpeakingStyleGoal = .authoritative
    @State private var coachingGoal: String = ""
    @State private var whyNow: String = ""
    @State private var successVision: String = ""

    private var isLastStep: Bool {
        step == .goal
    }

    private var canAdvance: Bool {
        if step == .goal {
            return coachingGoal.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 &&
                whyNow.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8 &&
                successVision.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.93, blue: 0.88),
                        Color.white,
                        Color(red: 0.90, green: 0.95, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        progressHeader
                        questionCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                navigationBar
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                    .background(.ultraThinMaterial)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear(perform: loadExistingProfile)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Coaching Profile")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text("A few quick answers, once.")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Noum will use these to tailor drills, feedback, and reminders around what better communication actually changes for you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(Array(OnboardingStep.allCases.enumerated()), id: \.offset) { index, _ in
                    Capsule()
                        .fill(index <= step.rawValue ? Color.blue : Color.white.opacity(0.65))
                        .frame(height: 8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(step.title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(step.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Group {
                switch step {
                case .context:
                    selectionList(options: SpeakingContext.allCases, selectedID: speakingContext.id) { speakingContext = $0 }
                case .challenge:
                    selectionList(options: SpeakingChallenge.allCases, selectedID: biggestChallenge.id) { biggestChallenge = $0 }
                case .style:
                    selectionList(options: SpeakingStyleGoal.allCases, selectedID: speakingStyleGoal.id) { speakingStyleGoal = $0 }
                case .goal:
                    goalComposer
                }
            }
            .id(step.rawValue)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(22)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .animation(.easeInOut(duration: 0.22), value: step)
    }

    private var goalComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(biggestChallenge.goalPrompt)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            TextField(goalPlaceholder, text: $coachingGoal, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)

            TextField("Why does this matter right now?", text: $whyNow, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            TextField("If this gets better, what changes for you?", text: $successVision, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            Text("Keep it concrete so Noum can coach toward a real outcome, not just a vague improvement.")
                .font(.caption)
                .foregroundStyle(.secondary)

            northStarPreview
        }
    }

    private var northStarPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What Noum will optimize for")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(goalPreviewHeadline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(goalPreviewDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var goalPreviewHeadline: String {
        let goal = coachingGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        if goal.isEmpty {
            return "Help me sound \(speakingStyleGoal.title.lowercased()) in \(speakingContext.title.lowercased())."
        }
        return goal
    }

    private var goalPreviewDetail: String {
        let why = whyNow.trimmingCharacters(in: .whitespacesAndNewlines)
        let success = successVision.trimmingCharacters(in: .whitespacesAndNewlines)

        if !why.isEmpty && !success.isEmpty {
            return "Because \(why), and better communication would help \(success)."
        }
        if !why.isEmpty {
            return "Because \(why)."
        }
        if !success.isEmpty {
            return "Success would look like \(success)."
        }
        return "Noum will bias recommendations toward the drills most likely to move this forward."
    }

    private var goalPlaceholder: String {
        switch speakingContext {
        case .work:
            return "Example: lead updates in meetings without second-guessing every sentence"
        case .interviews:
            return "Example: answer interview questions clearly without losing my structure"
        case .presentations:
            return "Example: sound more confident when opening a presentation"
        case .social:
            return "Example: speak more naturally without rushing or overexplaining"
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            if step.rawValue > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        step = OnboardingStep(rawValue: step.rawValue - 1) ?? .context
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.82), in: Capsule())
                .foregroundStyle(.primary)
            }

            Button(isLastStep ? "Save Profile" : "Continue") {
                if isLastStep {
                    let trimmedGoal = coachingGoal.trimmingCharacters(in: .whitespacesAndNewlines)
                    coachingProfileStore.save(
                        CoachingProfile(
                            speakingContext: speakingContext,
                            primaryGoal: biggestChallenge.recommendedPriority,
                            confidenceLevel: .rebuilding,
                            biggestChallenge: biggestChallenge,
                            desiredOutcome: speakingStyleGoal.recommendedOutcome,
                            speakingStyleGoal: speakingStyleGoal,
                            styleReference: "",
                            coachingBrief: trimmedGoal,
                            motivationWhyNow: whyNow.trimmingCharacters(in: .whitespacesAndNewlines),
                            successVision: successVision.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                    dismiss()
                } else {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        step = OnboardingStep(rawValue: step.rawValue + 1) ?? .goal
                    }
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canAdvance ? Color.blue : Color.gray.opacity(0.35), in: Capsule())
            .foregroundStyle(.white)
            .disabled(!canAdvance)
        }
    }

    private func selectionList<Option: Identifiable & CaseIterable & Hashable>(
        options: Option.AllCases,
        selectedID: Option.ID,
        onSelect: @escaping (Option) -> Void
    ) -> some View where Option.AllCases.Element == Option, Option: CustomStringConvertible {
        VStack(spacing: 10) {
            ForEach(Array(options), id: \.id) { option in
                Button {
                    onSelect(option)
                } label: {
                    HStack(spacing: 14) {
                        Text(option.description)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 12)

                        Image(systemName: option.id == selectedID ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(option.id == selectedID ? .blue : .secondary)
                    }
                    .padding(16)
                    .background(
                        Color.blue.opacity(option.id == selectedID ? 0.10 : 0.04),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadExistingProfile() {
        guard let profile = coachingProfileStore.profile else { return }
        speakingContext = profile.speakingContext
        biggestChallenge = profile.biggestChallenge
        speakingStyleGoal = profile.speakingStyleGoal
        coachingGoal = profile.personalGoalReference
        whyNow = profile.whyNowReference
        successVision = profile.successVisionReference
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
