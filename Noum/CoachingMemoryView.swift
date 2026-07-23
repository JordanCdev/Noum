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
            LazyVStack(alignment: .leading, spacing: Spacing.cardGap) {
                Text("Use, correct, or remove any coaching context.")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                evidenceBoundary

                ForEach(presentation.items) { item in
                    CoachingMemoryItemCard(item: item)
                }

                NavigationLink {
                    YourDataView(isBackendConfigured: isBackendConfigured)
                } label: {
                    Text("Manage all memory")
                        .font(Typography.headline)
                        .foregroundStyle(AppColor.brandBlue)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(AppColor.cardBackground, in: Capsule(style: .continuous))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(AppColor.brandBlue, lineWidth: 1)
                        }
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.pressable)
                .accessibilityHint("Opens the existing data controls where you can correct or remove coaching memory.")
                .accessibilityIdentifier("coachingMemory.manage")
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, Spacing.lg)
        }
        .background(AppColor.screenBackground.ignoresSafeArea())
        .navigationTitle("Coaching memory")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("coachingMemory.screen")
        .task {
            isBackendConfigured = await BackendSyncManager.shared.isConfigured
        }
    }

    private var evidenceBoundary: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("EVIDENCE BOUNDARY")
                .font(Typography.captionSmall)
                .foregroundStyle(AppColor.brandBlue)
            Text("Noum separates what you said from what it is still testing.")
                .font(Typography.caption)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.coachHeroQuietSurface,
            in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Evidence boundary. Noum separates what you said from what it is still testing.")
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
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
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        }
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
