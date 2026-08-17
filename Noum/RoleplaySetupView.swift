import SwiftUI

/// Scenario + starting-rung picker for pressure-ladder roleplay.
/// The launch view presents one conversation and one start action; optional
/// configuration stays in a system sheet.
struct RoleplaySetupView: View {
    @Binding var navigationPath: NavigationPath

    @State private var selectedScenarioId: String = RoleplayCatalog.interview.scenarioId
    @State private var startingLevel: RoleplayPressureLevel = .easy
    @State private var showAdjustments = false

    private var selectedScenario: RoleplayScenario {
        RoleplayCatalog.scenario(id: selectedScenarioId) ?? RoleplayCatalog.interview
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header
                    scenarioFocus
                    repContract
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xl)
            }
        }
        .accessibilityIdentifier("roleplay.setup.screen")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    CoachHaptic.selectionTap()
                    showAdjustments = true
                } label: {
                    Label("Adjust", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("roleplay.adjust")
            }
        }
        .safeAreaInset(edge: .bottom) {
            beginButton
                .padding(.horizontal, Spacing.screenH)
                .padding(.vertical, Spacing.sm)
                .background(.regularMaterial)
        }
        .sheet(isPresented: $showAdjustments) {
            roleplayAdjustSheet
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Spacing.md) {
                NoumWaveformMark(state: .idle, tint: AppColor.modeIM)
                headerCopy
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                NoumWaveformMark(state: .idle, tint: AppColor.modeIM)
                headerCopy
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("ROLEPLAY")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.modeIM)
                .tracking(0.8)
            Text("Rehearse the hard moment.")
                .font(Typography.screenTitle)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("One objection at a time. Feedback arrives after your answer, not while you speak.")
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scenarioFocus: some View {
        NoumSurface(.mission) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    NoumWaveformMark(state: .idle, tint: .white)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("YOUR CONVERSATION")
                            .font(Typography.captionSmall.weight(.bold))
                            .foregroundStyle(AppColor.homeHeroMetaText)
                            .tracking(0.7)
                        Text(selectedScenario.title)
                            .font(Typography.cardTitle)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(selectedScenario.personaName), \(selectedScenario.personaRole)")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.homeHeroSubtitleText)
                    }
                }

                Text(selectedScenario.objective)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.homeHeroSubtitleText)
                    .fixedSize(horizontal: false, vertical: true)

                Label("Starts at \(startingLevel.title.lowercased()) pressure", systemImage: "gauge.with.dots.needle.33percent")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roleplay.selectionSummary")
    }

    private var repContract: some View {
        NoumSurface(.quiet) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("How the rep works")
                    .font(Typography.headline)
                    .foregroundStyle(AppColor.textPrimary)
                Label("Respond naturally to the objection", systemImage: "1.circle.fill")
                Label("Review one strength and one gap", systemImage: "2.circle.fill")
                Label("Try the next pressure rung when available", systemImage: "3.circle.fill")
            }
            .font(Typography.body)
            .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var roleplayAdjustSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(RoleplayCatalog.all) { scenario in
                        scenarioRow(scenario)
                    }
                } header: {
                    Text("Conversation")
                } footer: {
                    Text("Choose the situation closest to the conversation you want to handle better.")
                }

                Section("Starting pressure") {
                    Picker("Starting pressure", selection: $startingLevel) {
                        ForEach(RoleplayPressureLevel.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(startingLevel.subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Adjust roleplay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showAdjustments = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func scenarioRow(_ scenario: RoleplayScenario) -> some View {
        let isSelected = scenario.scenarioId == selectedScenarioId
        return Button {
            selectedScenarioId = scenario.scenarioId
            CoachHaptic.selectionTap()
        } label: {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: "person.2.fill")
                    .font(.headline)
                    .foregroundStyle(AppColor.modeIM)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(scenario.title)
                        .font(Typography.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(scenario.personaRole)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer(minLength: Spacing.sm)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.modeIM)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roleplay.scenario.\(scenario.scenarioId)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var beginButton: some View {
        Button {
            navigationPath.append(AppDestination.roleplayRun(scenario: selectedScenario, startingLevel: startingLevel))
        } label: {
            Text("Start roleplay")
                .font(Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .noumMinimumTouchTarget()
                .padding(.vertical, Spacing.xs)
                .background(AppColor.coachingInk, in: Capsule(style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("roleplay.begin")
    }
}

#if DEBUG
#Preview("Roleplay — V3 setup") {
    NavigationStack {
        RoleplaySetupView(navigationPath: .constant(NavigationPath()))
    }
}
#endif
