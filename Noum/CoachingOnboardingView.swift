#if canImport(SwiftUI)
import SwiftUI

private enum OnboardingStep: Int, CaseIterable {
    case context
    case challenge
    case priority
    case confidence
    case outcome
    case style
    case brief

    var title: String {
        switch self {
        case .context: return "Where do you most want to sound stronger?"
        case .challenge: return "When speaking pressure hits, what tends to happen?"
        case .priority: return "What should the coaching prioritise first?"
        case .confidence: return "How would you describe your speaking confidence today?"
        case .outcome: return "What should a stronger result feel like?"
        case .style: return "What kind of voice or presence do you want to build?"
        case .brief: return "Finish this sentence for me."
        }
    }

    var subtitle: String {
        switch self {
        case .context: return "Choose the setting that matters most so practice feels relevant from the start."
        case .challenge: return "This gives Noum the clearest clue about what to correct in the moment."
        case .priority: return "We’ll use this to decide what kind of improvement to reinforce first."
        case .confidence: return "This sets the tone of the coaching, not a label you’re stuck with."
        case .outcome: return "Think about the version of your speaking you want people to notice."
        case .style: return "Choose the voice you want Noum to coach you toward, then make it specific in your own words."
        case .brief: return "Be specific. This gives the coaching its clearest target."
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
    @State private var primaryGoal: CoachingPriority = .reduceFillers
    @State private var confidenceLevel: ConfidenceLevel = .rebuilding
    @State private var desiredOutcome: SpeakingOutcome = .concise
    @State private var speakingStyleGoal: SpeakingStyleGoal = .authoritative
    @State private var styleReference: String = ""
    @State private var coachingBrief: String = ""

    private var isLastStep: Bool {
        step == .brief
    }

    private var canAdvance: Bool {
        if step == .brief {
            return coachingBrief.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12
        }
        if step == .style {
            return styleReference.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
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

                Circle()
                    .fill(Color.blue.opacity(0.10))
                    .frame(width: 220, height: 220)
                    .blur(radius: 16)
                    .offset(x: 110, y: -220)

                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 180, height: 180)
                    .blur(radius: 18)
                    .offset(x: -120, y: 260)

                VStack(spacing: 18) {
                    progressHeader
                    questionCard
                    navigationBar
                }
                .padding(18)
            }
            .navigationTitle("Coaching Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear(perform: loadExistingProfile)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Build a sharper coaching profile")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("A few focused answers now will make the feedback feel much more relevant later.")
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
            Text(step.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Group {
                switch step {
                case .context:
                    selectionList(options: SpeakingContext.allCases, selectedID: speakingContext.id) { speakingContext = $0 }
                case .challenge:
                    selectionList(options: SpeakingChallenge.allCases, selectedID: biggestChallenge.id) { biggestChallenge = $0 }
                case .priority:
                    selectionList(options: CoachingPriority.allCases, selectedID: primaryGoal.id) { primaryGoal = $0 }
                case .confidence:
                    selectionList(options: ConfidenceLevel.allCases, selectedID: confidenceLevel.id) { confidenceLevel = $0 }
                case .outcome:
                    selectionList(options: SpeakingOutcome.allCases, selectedID: desiredOutcome.id) { desiredOutcome = $0 }
                case .style:
                    styleComposer
                case .brief:
                    briefComposer
                }
            }
            .id(step.rawValue)
            .transition(.opacity.combined(with: .move(edge: .trailing)))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(22)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .animation(.easeInOut(duration: 0.22), value: step)
    }

    private var briefComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("“I want Noum to help me…”")
                .font(.headline)
            TextField("Example: speak more clearly in meetings without filling space with ‘um’", text: $coachingBrief, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(4...6)
            Text("This is required because it gives the coaching a specific aim to work toward.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var styleComposer: some View {
        VStack(alignment: .leading, spacing: 14) {
            selectionList(options: SpeakingStyleGoal.allCases, selectedID: speakingStyleGoal.id) { speakingStyleGoal = $0 }

            VStack(alignment: .leading, spacing: 8) {
                Text("Describe the voice you want")
                    .font(.headline)
                TextField("Example: like a calm king, more authority, less apologetic", text: $styleReference, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)
                Text("This is required so Noum can compare your current language with the style you want to grow into.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

            Button(isLastStep ? "Save Coaching Profile" : "Continue") {
                if isLastStep {
                    coachingProfileStore.save(
                        CoachingProfile(
                            speakingContext: speakingContext,
                            primaryGoal: primaryGoal,
                            confidenceLevel: confidenceLevel,
                            biggestChallenge: biggestChallenge,
                            desiredOutcome: desiredOutcome,
                            speakingStyleGoal: speakingStyleGoal,
                            styleReference: styleReference.trimmingCharacters(in: .whitespacesAndNewlines),
                            coachingBrief: coachingBrief.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                    dismiss()
                } else {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        step = OnboardingStep(rawValue: step.rawValue + 1) ?? .brief
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.description)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: option.id == selectedID ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(option.id == selectedID ? .blue : .secondary)
                    }
                    .padding(16)
                    .background(Color.blue.opacity(option.id == selectedID ? 0.10 : 0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadExistingProfile() {
        if let profile = coachingProfileStore.profile {
            speakingContext = profile.speakingContext
            biggestChallenge = profile.biggestChallenge
            primaryGoal = profile.primaryGoal
            confidenceLevel = profile.confidenceLevel
            desiredOutcome = profile.desiredOutcome
            speakingStyleGoal = profile.speakingStyleGoal
            styleReference = profile.styleReference
            coachingBrief = profile.coachingBrief
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
