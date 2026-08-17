import SwiftUI

/// A read-only projection of the bounded context Noum carries between reps.
///
/// Persistence remains in `CoachMemoryStore` and `CoachingProfileStore`. This
/// type exists so the user-facing provenance contract can be tested without
/// constructing a view or adding a second memory owner.
struct CoachingMemoryPresentation: Equatable {
    let items: [CoachingMemoryItemPresentation]

    static func make(
        memory: CoachMemory?,
        profile: CoachingProfile?
    ) -> CoachingMemoryPresentation {
        CoachingMemoryPresentation(items: [
            currentLeverItem(memory: memory),
            workContextItem(memory: memory, profile: profile),
            voicePreferenceItem(profile: profile)
        ])
    }

    private static func currentLeverItem(
        memory: CoachMemory?
    ) -> CoachingMemoryItemPresentation {
        guard let memory, let lever = memory.currentLever else {
            return CoachingMemoryItemPresentation(
                kind: .currentLever,
                value: "Still forming",
                provenance: "Noum needs repeated eligible reps before choosing a lever"
            )
        }

        let provenance: String
        if memory.evidenceCount > 0 {
            let repLabel = memory.evidenceCount == 1 ? "rep" : "reps"
            provenance = "Observed from \(memory.evidenceCount) eligible \(repLabel) · \(leverStatus(memory.currentLeverConfidence))"
        } else {
            provenance = "Coach hypothesis · still testing"
        }

        return CoachingMemoryItemPresentation(
            kind: .currentLever,
            value: lever.coachingMemoryLabel,
            provenance: provenance
        )
    }

    private static func workContextItem(
        memory: CoachMemory?,
        profile: CoachingProfile?
    ) -> CoachingMemoryItemPresentation {
        if let statedGoal = nonEmpty(memory?.statedGoalSummary) {
            return CoachingMemoryItemPresentation(
                kind: .workContext,
                value: statedGoal,
                provenance: "Added by you"
            )
        }

        if let profile {
            return CoachingMemoryItemPresentation(
                kind: .workContext,
                value: profile.speakingContext.title,
                provenance: "Selected by you · Goal: \(profile.primaryGoal.title)"
            )
        }

        return CoachingMemoryItemPresentation(
            kind: .workContext,
            value: "Not added yet",
            provenance: "Add a goal when you want Noum to remember it"
        )
    }

    private static func voicePreferenceItem(
        profile: CoachingProfile?
    ) -> CoachingMemoryItemPresentation {
        guard let primary = profile?.chosenStyleGoal else {
            return CoachingMemoryItemPresentation(
                kind: .voicePreference,
                value: "Not chosen yet",
                provenance: "No voice preference confirmed by you"
            )
        }

        let value: String
        if let secondary = profile?.secondaryStyleGoal, secondary != primary {
            value = "\(primary.title) + \(secondary.title)"
        } else {
            value = primary.title
        }

        return CoachingMemoryItemPresentation(
            kind: .voicePreference,
            value: value,
            provenance: "Confirmed by you"
        )
    }

    private static func leverStatus(_ confidence: TrendConfidence?) -> String {
        switch confidence {
        case .high: return "repeated pattern"
        case .medium: return "forming read"
        case .low, .none: return "still testing"
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct CoachingMemoryItemPresentation: Identifiable, Equatable {
    enum Kind: String, CaseIterable, Hashable {
        case currentLever
        case workContext
        case voicePreference

        var id: String { rawValue }

        var eyebrow: String {
            switch self {
            case .currentLever: return "CURRENT LEVER"
            case .workContext: return "WORK CONTEXT / GOAL"
            case .voicePreference: return "VOICE PREFERENCE"
            }
        }
    }

    let kind: Kind
    let value: String
    let provenance: String

    var id: Kind { kind }
}

private extension SkillArea {
    /// User-facing intervention language for the durable lever. The store owns
    /// which skill is active; this projection only translates the taxonomy
    /// into the specific behavior the user can carry into the next rep.
    var coachingMemoryLabel: String {
        switch self {
        case .fillerReduction: return "Replace fillers with a pause"
        case .openingStrength: return "Open with the answer"
        case .closingStrength: return "Land the final point"
        case .paceControl: return "Hold a steady pace"
        case .structure: return "One point, then proof"
        case .answerDevelopment: return "Add one concrete example"
        case .conciseSpeaking: return "Say the point once"
        case .pauseUsage: return "Use a clean pause"
        case .vocalEmphasis: return "Stress the key words"
        case .confidence: return "Finish the thought"
        }
    }
}

@available(iOS 17.0, macOS 12.0, *)
struct CoachingMemoryView: View {
    @StateObject private var memoryStore = CoachMemoryStore.shared
    @StateObject private var profileStore = CoachingProfileStore.shared
    @State private var isBackendConfigured = false

    private var presentation: CoachingMemoryPresentation {
        CoachingMemoryPresentation.make(
            memory: memoryStore.currentMemory,
            profile: profileStore.profile
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                memoryIntroduction

                NoumSurface(.standard) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        evidenceBoundary

                        Divider()

                        ForEach(Array(presentation.items.enumerated()), id: \.offset) { index, item in
                            CoachingMemoryItemCard(item: item)

                            if index < presentation.items.count - 1 {
                                Divider()
                            }
                        }

                        Divider()

                        NavigationLink {
                            YourDataView(isBackendConfigured: isBackendConfigured)
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Text("Manage coaching memory")
                                    .font(Typography.cardLabel)
                                Spacer(minLength: Spacing.sm)
                                Image(systemName: "arrow.right")
                                    .font(Typography.caption.weight(.bold))
                                    .accessibilityHidden(true)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.lg)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(AppColor.coachingInk, in: Capsule(style: .continuous))
                            .contentShape(Capsule(style: .continuous))
                        }
                        .buttonStyle(.pressable)
                        .accessibilityHint("Opens the existing data controls where you can correct or remove coaching memory.")
                        .accessibilityIdentifier("coachingMemory.manage")
                    }
                }
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .background(AppColor.screenBackground.ignoresSafeArea())
        .navigationTitle("Coaching memory")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("coachingMemory.screen")
        .task {
            isBackendConfigured = await BackendSyncManager.shared.isConfigured
        }
    }

    private var memoryIntroduction: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            NoumSemanticGraphic(
                role: .coachingMemory,
                tint: AppColor.coachingInk,
                size: NoumControlMetric.semanticGraphic
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("CONTEXT YOU CONTROL")
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.brandBlue)

                Text("What Noum carries forward")
                    .font(Typography.screenTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Use, correct, or remove any coaching context. Noum keeps your words separate from patterns it is still testing.")
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var evidenceBoundary: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "checkmark.shield.fill")
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.positive)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Evidence boundary")
                    .font(Typography.cardLabel)
                    .foregroundStyle(AppColor.textPrimary)
                Text("Your choices are labelled separately from coach hypotheses.")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Evidence boundary. Your choices are labelled separately from coach hypotheses.")
    }
}

private struct CoachingMemoryItemCard: View {
    let item: CoachingMemoryItemPresentation

    private var tint: Color {
        switch item.kind {
        case .currentLever: return AppColor.brandBlue
        case .workContext: return AppColor.positive
        case .voicePreference: return AppColor.proText
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Capsule(style: .continuous)
                .fill(tint)
                .frame(width: 4, height: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.kind.eyebrow)
                    .font(Typography.captionSmall)
                    .foregroundStyle(tint)

                Text(item.value)
                    .font(Typography.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.provenance)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kind.eyebrow). \(item.value). \(item.provenance).")
        .accessibilityIdentifier("coachingMemory.item.\(item.kind.rawValue)")
    }
}

#Preview {
    NavigationStack {
        CoachingMemoryView()
    }
}
