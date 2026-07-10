#if canImport(SwiftUI)
import SwiftUI

// MARK: - Speech Projects - picker view

/// Browser for the curated set of structured speech projects. The user
/// picks a project, reads its objectives, and lands on a Timed practice
/// session pre-loaded with one of the project's prompts.
@available(iOS 17.0, macOS 12.0, *)
struct SpeechProjectsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sessionStore = PracticeSessionStore.shared
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
                    if showsFirstTimeEmptyState {
                        firstTimeEmptyState
                    }
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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Speech projects")
                .font(Typography.screenTitle)
                .foregroundStyle(.primary)
            Text("\(SpeechProjects.all.count) guided speeches with a clear purpose, target length, and coaching focus.")
                .font(Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - First-time empty state

    /// Shown only when the user has never completed a practice session at all.
    /// Once a single rep exists, the catalog stands on its own — projects are
    /// extra credit, not the only entry point.
    private var showsFirstTimeEmptyState: Bool {
        sessionStore.sessions.isEmpty
    }

    private var firstTimeEmptyState: some View {
        EmptyStateView(
            symbol: "rectangle.stack.fill",
            title: "Prepare one complete speech",
            body: "Start with a guided brief, then rehearse it in a focused timed rep.",
            tint: AppColor.brandBlue,
            cta: EmptyStateView.CTA(label: "Open first project", icon: "arrow.right") {
                selectedProject = SpeechProjects.iceBreaker
            }
        )
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .accessibilityIdentifier("emptyState.projects")
    }

    private var projectGrid: some View {
        VStack(spacing: 0) {
            ForEach(Array(SpeechProjects.all.enumerated()), id: \.element.id) { index, project in
                Button {
                    selectedProject = project
                } label: {
                    projectRow(project: project)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("speechProjects.row.\(project.id)")

                if index < SpeechProjects.all.count - 1 {
                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
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
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
                    Text("Start speech")
                        .font(Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColor.brandBlue, in: Capsule())
                }
                .accessibilityIdentifier("speechProjects.detail.start")
                Button(action: onDismiss) {
                    Text("Not now")
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
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
                    Text("\(project.focus.label) focus")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Text(project.tagline)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.md) {
                    Label(minutesLabel(project.durationTarget), systemImage: "scope")
                    Label("\(minutesLabel(project.durationMinimum)) minimum", systemImage: "clock")
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label(minutesLabel(project.durationTarget), systemImage: "scope")
                    Label("\(minutesLabel(project.durationMinimum)) minimum", systemImage: "clock")
                }
            }
            .font(Typography.caption.weight(.semibold))
            .foregroundStyle(AppColor.brandBlue)
        }
    }

    private func minutesLabel(_ seconds: TimeInterval) -> String {
        if seconds < 120 { return "\(Int(seconds))s" }
        let minutes = Int(seconds / 60)
        let remainder = Int(seconds.truncatingRemainder(dividingBy: 60))
        return remainder == 0 ? "\(minutes) min" : "\(minutes):\(String(format: "%02d", remainder))"
    }

    private var objectivesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Your brief")
                .font(Typography.headline)
                .foregroundStyle(.primary)

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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Coaching focus")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
            Text(project.coachLine)
                .font(Typography.body)
                .foregroundStyle(.primary)
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
