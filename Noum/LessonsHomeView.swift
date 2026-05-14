#if canImport(SwiftUI)
import SwiftUI

// MARK: - Lessons Home (catalog browser)
//
// Curriculum surface. Lists every lesson with its current crown level so
// the user can see where they have progress, where they have headroom,
// and which technique is next on the path.

@available(iOS 17.0, macOS 12.0, *)
struct LessonsHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var lessonStore = LessonStore.shared
    @Binding var navigationPath: NavigationPath

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
                    summaryStrip
                    lessonsByCategory
                    Spacer(minLength: Spacing.lg)
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("lessons.screen")
        .overlay {
            if let celebration = lessonStore.pendingCelebration,
               let lesson = LessonsCatalog.lesson(id: celebration.lessonID) {
                LessonCelebrationOverlay(
                    celebration: celebration,
                    lesson: lesson,
                    onDismiss: { lessonStore.consumeCelebration() }
                )
                .transition(.opacity)
                .zIndex(99)
            }
        }
    }

    // MARK: - Header

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lessons")
                .font(Typography.screenTitle)
                .foregroundStyle(.primary)
            Text("Short, focused lessons that teach a single move. Concept, then spot it, then say it. Each pass earns a crown.")
                .font(Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - First-time empty state

    /// Renders only on the very first visit — when no crowns have been earned
    /// and no lesson has ever been opened. Once a single attempt has happened
    /// (pass or fail), the catalog stands on its own.
    private var showsFirstTimeEmptyState: Bool {
        let everAttempted = lessonStore.progress.values.contains { $0.totalAttempts > 0 || $0.lastCompletedAt != nil }
        return lessonStore.totalCrowns == 0 && !everAttempted
    }

    private var firstTimeEmptyState: some View {
        let recommended = lessonStore.nextRecommendedLesson ?? LessonsCatalog.all.first
        return EmptyStateView(
            symbol: "books.vertical.fill",
            title: "Earn your first crown",
            body: "Each lesson teaches one move. Concept, then spot it, then say it.",
            tint: AppColor.brandBlue,
            cta: recommended.map { lesson in
                EmptyStateView.CTA(label: "Start \(lesson.title)", icon: "play.fill") {
                    navigationPath.append(AppDestination.lesson(id: lesson.id))
                }
            }
        )
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .accessibilityIdentifier("emptyState.lessons")
    }

    // MARK: - Summary strip

    private var summaryStrip: some View {
        let totalCrowns = lessonStore.totalCrowns
        let crownsPossible = LessonsCatalog.all.count * LessonStore.crownCap
        return HStack(spacing: 10) {
            summaryPill(
                title: "Crowns",
                value: "\(totalCrowns)/\(crownsPossible)",
                icon: "crown.fill",
                tint: AppColor.brandBlue
            )
            summaryPill(
                title: "Lessons",
                value: "\(LessonsCatalog.all.count)",
                icon: "books.vertical.fill",
                tint: AppColor.positive
            )
        }
    }

    private func summaryPill(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint.opacity(0.9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text(value)
                    .font(Typography.headline.monospacedDigit())
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    // MARK: - Catalog grouped by category

    private var lessonsByCategory: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            ForEach(Lesson.Category.allCases, id: \.self) { category in
                let lessons = LessonsCatalog.all.filter { $0.category == category }
                if !lessons.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(category.label)
                            .font(Typography.micro)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        VStack(spacing: Spacing.cardGap) {
                            ForEach(lessons) { lesson in
                                lessonRow(lesson)
                            }
                        }
                    }
                }
            }
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        Button {
            navigationPath.append(AppDestination.lesson(id: lesson.id))
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(AppColor.brandBlue.opacity(0.10))
                        .frame(width: 48, height: 48)
                    Image(systemName: lesson.symbolName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColor.brandBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(Typography.headline)
                        .foregroundStyle(.primary)
                    Text(lesson.tagline)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    crownRow(crowns: lessonStore.crownLevel(for: lesson.id))
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
        .buttonStyle(.plain)
        .accessibilityIdentifier("lessons.row.\(lesson.id)")
    }

    private func crownRow(crowns: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<LessonStore.crownCap, id: \.self) { i in
                Image(systemName: i < crowns ? "crown.fill" : "crown")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(i < crowns ? AppColor.brandBlue : Color.secondary.opacity(0.3))
            }
        }
    }
}

// MARK: - Celebration overlay

@available(iOS 17.0, macOS 12.0, *)
struct LessonCelebrationOverlay: View {
    let celebration: LessonCelebration
    let lesson: Lesson
    let onDismiss: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(AppColor.brandBlue.opacity(0.16))
                        .frame(width: 96, height: 96)
                    Image(systemName: lesson.symbolName)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(AppColor.brandBlue)
                        .scaleEffect(hasAppeared ? 1 : 0.7)
                }

                SparkleRibbon(tint: AppColor.brandBlue)
                    .opacity(hasAppeared ? 1 : 0)

                VStack(spacing: 10) {
                    Text(celebration.kind.headline)
                        .font(Typography.micro)
                        .foregroundStyle(AppColor.brandBlue)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text(lesson.title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    Text(crownLine)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    ForEach(0..<LessonStore.crownCap, id: \.self) { i in
                        Image(systemName: i < celebration.crownLevel ? "crown.fill" : "crown")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(i < celebration.crownLevel ? AppColor.brandBlue : Color.secondary.opacity(0.3))
                    }
                }

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColor.brandBlue, in: Capsule())
                }
                .accessibilityIdentifier("lesson.celebration.continue")
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 24, y: 8)
            .padding(.horizontal, 32)
            .scaleEffect(hasAppeared ? 1 : 0.92)
            .opacity(hasAppeared ? 1 : 0)
        }
        .onAppear {
            CoachHaptic.trendBreakthrough()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                hasAppeared = true
            }
        }
    }

    private var crownLine: String {
        switch celebration.kind {
        case .unlocked:
            return "First crown earned. Four more to master."
        case .levelUp:
            return "\(celebration.crownLevel) of \(LessonStore.crownCap) crowns."
        case .mastered:
            return "All five crowns. The technique is yours."
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Lessons — catalog") {
    NavigationStack {
        LessonsHomeView()
    }
}

@available(iOS 17.0, *)
#Preview("Lesson celebration — unlocked") {
    LessonCelebrationOverlay(
        celebration: LessonCelebration(
            lessonID: LessonsCatalog.ruleOfThree.id,
            kind: .unlocked,
            crownLevel: 1
        ),
        lesson: LessonsCatalog.ruleOfThree,
        onDismiss: {}
    )
}
#endif

#endif
