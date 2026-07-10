import SwiftUI

/// Scenario + starting-rung picker for the pressure-ladder roleplay.
/// Uses the shared focused canvas. Scenario and pressure controls stay in an
/// Adjust sheet so the launch screen has one directive and one primary CTA.
struct RoleplaySetupView: View {
    @Binding var navigationPath: NavigationPath

    @State private var selectedScenarioId: String = RoleplayCatalog.interview.scenarioId
    @State private var startingLevel: RoleplayPressureLevel = .easy
    @State private var showAdjustments = false

    private var selectedScenario: RoleplayScenario {
        RoleplayCatalog.scenario(id: selectedScenarioId) ?? RoleplayCatalog.interview
    }

    var body: some View {
        FocusedPracticeScaffold(
            style: .conversation,
            status: "Ready at \(startingLevel.title.lowercased()) pressure",
            title: "Roleplay",
            subtitle: "Rehearse one difficult moment. Keep the response grounded."
        ) {
            Button {
                CoachHaptic.selectionTap()
                showAdjustments = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.14), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("roleplay.adjust")
            .accessibilityLabel("Adjust roleplay")
        } content: {
            selectedScenarioCue
        }
        .accessibilityIdentifier("roleplay.setup.screen")
        .safeAreaInset(edge: .bottom) {
            beginButton
                .padding(.horizontal, Spacing.screenH)
                .padding(.vertical, Spacing.sm)
                .background(Color.black.opacity(0.10).ignoresSafeArea())
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdjustments) {
            roleplayAdjustSheet
        }
    }

    private var selectedScenarioCue: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(selectedScenario.title, systemImage: "person.2.wave.2.fill")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.focusedTextSecondary)

            Text("\(selectedScenario.personaName), \(selectedScenario.personaRole)")
                .font(Typography.figtree(size: 24, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(.white)

            Text(selectedScenario.objective)
                .font(Typography.body)
                .foregroundStyle(AppColor.focusedTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusedGlassSurface()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roleplay.selectionSummary")
    }

    private var roleplayAdjustSheet: some View {
        NavigationStack {
            ZStack {
                AppColor.screenBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text("Scenario")
                            .font(Typography.cardTitle)
                        scenarioList
                        pressurePicker
                    }
                    .padding(Spacing.screenH)
                }
            }
            .navigationTitle("Adjust roleplay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showAdjustments = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .accessibilityIdentifier("roleplay.pressurePicker")
    }

    private var beginButton: some View {
        Button {
            navigationPath.append(AppDestination.roleplayRun(scenario: selectedScenario, startingLevel: startingLevel))
        } label: {
            Text("Start roleplay")
                .font(Typography.headline)
                .foregroundStyle(AppColor.modeIM)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.pressable)
        .background(.white, in: Capsule())
        .accessibilityIdentifier("roleplay.begin")
    }
}
