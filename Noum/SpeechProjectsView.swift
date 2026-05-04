#if canImport(SwiftUI)
import SwiftUI

// MARK: - Speech Projects (Toastmasters-inspired) — picker view

/// Browser for the curated set of structured speech projects. The user
/// picks a project, reads its objectives, and lands on a Timed practice
/// session pre-loaded with one of the project's prompts.
@available(iOS 17.0, macOS 12.0, *)
struct SpeechProjectsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var navigationPath: NavigationPath
    @State private var selectedProject: SpeechProject?

    init(navigationPath: Binding<NavigationPath>) {
        self._navigationPath = navigationPath
    }

    init() {
        self._navigationPath = .constant(NavigationPath())
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    headerCopy
                    projectGrid
                    Spacer(minLength: Spacing.lg)
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("speechProjects.screen")
        .sheet(item: $selectedProject) { project in
            SpeechProjectDetailSheet(project: project) {
                selectedProject = nil
                start(project: project)
            } onDismiss: {
                selectedProject = nil
            }
        }
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Speech projects")
                .font(Typography.screenTitle)
                .foregroundStyle(.primary)
            Text("Structured prepared speeches with concrete objectives. Inspired by Toastmasters Pathways.")
                .font(Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var projectGrid: some View {
        VStack(spacing: Spacing.cardGap) {
            ForEach(SpeechProjects.all) { project in
                Button {
                    selectedProject = project
                } label: {
                    projectRow(project: project)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("speechProjects.row.\(project.id)")
            }
        }
    }

    private func projectRow(project: SpeechProject) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(AppColor.brandBlue.opacity(0.10))
                    .frame(width: 48, height: 48)
                Image(systemName: project.symbolName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColor.brandBlue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(Typography.headline)
                    .foregroundStyle(.primary)
                Text(project.tagline)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    pillTag(text: project.focus.label)
                    pillTag(text: durationLabel(project.durationTarget))
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    private func pillTag(text: String) -> some View {
        Text(text)
            .font(Typography.micro)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppColor.tagBackground, in: Capsule())
    }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if seconds < 120 { return "\(Int(seconds))s" }
        return "\(minutes) min"
    }

    private func start(project: SpeechProject) {
        // Push timed practice with the project context. The timed practice
        // view reads `SpeechProjectContext.current` to render objectives in
        // the pre-roll and seed a project prompt.
        SpeechProjectContext.current = project
        navigationPath.append(AppDestination.timedPractice)
    }
}

// MARK: - Detail sheet

@available(iOS 17.0, macOS 12.0, *)
struct SpeechProjectDetailSheet: View {
    let project: SpeechProject
    let onStart: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                durationCard
                objectivesCard
                coachLine
                Spacer(minLength: Spacing.lg)
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: onStart) {
                    Text("Start project")
                        .font(Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColor.brandBlue, in: Capsule())
                }
                .accessibilityIdentifier("speechProjects.detail.start")
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 12)
            .background(AppColor.cardBackground.shadow(.drop(color: .black.opacity(0.06), radius: 12, y: -4)))
        }
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppColor.brandBlue.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: project.symbolName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColor.brandBlue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                    Text(project.focus.label)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Text(project.tagline)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var durationCard: some View {
        HStack(spacing: 16) {
            durationStat(label: "Target", value: minutesLabel(project.durationTarget))
            Divider().frame(height: 28)
            durationStat(label: "Minimum", value: minutesLabel(project.durationMinimum))
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    private func durationStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Text(value)
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func minutesLabel(_ seconds: TimeInterval) -> String {
        if seconds < 120 { return "\(Int(seconds))s" }
        let minutes = Int(seconds / 60)
        let remainder = Int(seconds.truncatingRemainder(dividingBy: 60))
        return remainder == 0 ? "\(minutes) min" : "\(minutes):\(String(format: "%02d", remainder))"
    }

    private var objectivesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Objectives")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(project.objectives.enumerated()), id: \.offset) { index, objective in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(Typography.caption.monospacedDigit())
                            .foregroundStyle(AppColor.brandBlue)
                            .frame(width: 22, height: 22)
                            .background(AppColor.brandBlue.opacity(0.10), in: Circle())
                        Text(objective)
                            .font(Typography.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    private var coachLine: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
            Text(project.coachLine)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }
}

// MARK: - Speech Project context

/// Lightweight handoff between the project picker and `TimedPracticeView`.
/// Set when a project is started, read once on TimedPractice setup, then
/// cleared. Uses a static var instead of a real environment so we don't
/// have to thread a Binding through the destination enum.
enum SpeechProjectContext {
    static var current: SpeechProject?
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Speech projects — list") {
    NavigationStack {
        SpeechProjectsView()
    }
}

@available(iOS 17.0, *)
#Preview("Speech project — detail") {
    SpeechProjectDetailSheet(
        project: SpeechProjects.iceBreaker,
        onStart: {},
        onDismiss: {}
    )
}
#endif

#endif
