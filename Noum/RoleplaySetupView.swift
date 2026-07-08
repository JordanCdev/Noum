import SwiftUI

/// Scenario + starting-rung picker for the pressure-ladder roleplay.
/// Mirrors the calm, single-purpose setup surfaces elsewhere in the app
/// (e.g. `BigMomentIntakeView`) rather than introducing a new screen
/// pattern: one header, a scrollable list of scenario cards, an inline
/// pressure-rung control, one primary CTA.
struct RoleplaySetupView: View {
    @Binding var navigationPath: NavigationPath

    @State private var selectedScenarioId: String = RoleplayCatalog.interview.scenarioId
    @State private var startingLevel: RoleplayPressureLevel = .easy

    private var selectedScenario: RoleplayScenario {
        RoleplayCatalog.scenario(id: selectedScenarioId) ?? RoleplayCatalog.interview
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    scenarioList
                    pressurePicker
                    beginButton
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
        }
        .navigationTitle("Practise a conversation")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Practise a conversation")
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
            Text("Pick a scenario and a starting pressure. You'll get one strength, one gap, and one next attempt after each turn.")
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scenarioList: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(RoleplayCatalog.all) { scenario in
                scenarioCard(scenario)
            }
        }
    }

    private func scenarioCard(_ scenario: RoleplayScenario) -> some View {
        let isSelected = scenario.scenarioId == selectedScenarioId
        return Button {
            selectedScenarioId = scenario.scenarioId
        } label: {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: "person.fill.questionmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.modeIM)
                    .frame(width: 32, height: 32)
                    .background(AppColor.modeIM.opacity(0.10), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(scenario.title)
                        .font(Typography.headline)
                        .foregroundStyle(.primary)
                    Text("\(scenario.personaName) — \(scenario.personaRole)")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    Text(scenario.objective)
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.modeIM)
                        .accessibilityHidden(true)
                }
            }
            .padding(Spacing.md)
        }
        .buttonStyle(.pressable)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(isSelected ? AppColor.modeIM.opacity(0.35) : Color.black.opacity(0.05), lineWidth: isSelected ? 1.5 : 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roleplay.scenario.\(scenario.scenarioId)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var pressurePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Starting pressure")
                .font(Typography.cardLabel)
                .foregroundStyle(.primary)
            Picker("Starting pressure", selection: $startingLevel) {
                ForEach(RoleplayPressureLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)
            Text(startingLevel.subtitle)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("roleplay.pressurePicker")
    }

    private var beginButton: some View {
        Button {
            navigationPath.append(AppDestination.roleplayRun(scenario: selectedScenario, startingLevel: startingLevel))
        } label: {
            Text("Begin roleplay")
                .font(Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.pressable)
        .background(AppColor.modeIM, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .accessibilityIdentifier("roleplay.begin")
    }
}
