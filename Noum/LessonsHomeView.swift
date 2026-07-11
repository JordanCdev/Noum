#if canImport(SwiftUI)
import SwiftUI

// MARK: - Lessons Home (catalog browser)
//
// Curriculum surface. Lists every lesson with its current practice-pass
// progress so the user can see where they have progress, where they have
// headroom, and which technique is next on the path.

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
                    if let recommendedLesson {
                        recommendedLessonSection(recommendedLesson)
                    } else {
                        transferSection
                    }
                    if !showsFirstTimeEmptyState {
                        summaryStrip
                    }
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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Lessons")
                .font(Typography.screenTitle)
                .foregroundStyle(.primary)
            Text("Learn it, practice it, use it, then revisit it.")
                .font(Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - First-time empty state

    /// Renders only on the very first visit - when no practice passes exist
    /// and no lesson has ever been opened. Once a single attempt has happened
    /// (pass or fail), the catalog stands on its own.
    private var showsFirstTimeEmptyState: Bool {
        let everAttempted = lessonStore.progress.values.contains { $0.totalAttempts > 0 || $0.lastCompletedAt != nil }
        return lessonStore.totalPracticePasses == 0 && !everAttempted
    }

    private var recommendedLesson: Lesson? {
        lessonStore.nextRecommendedLesson
    }

    private func recommendedLessonSection(_ lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(recommendedEyebrow(for: lesson))
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
            lessonRow(lesson)
        }
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.brandBlue.opacity(0.14), lineWidth: 1)
        )
        .accessibilityIdentifier("emptyState.lessons")
    }

    private func recommendedEyebrow(for lesson: Lesson) -> String {
        switch lessonStore.reviewState(for: lesson.id) {
        case .new: return "Learn next"
        case .ready: return "Ready to revisit"
        case .waiting: return "Recommended lesson"
        }
    }

    private var transferSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Practice it in the room", systemImage: "arrow.up.right")
                .font(Typography.headline)
                .foregroundStyle(.primary)
            Text("Nothing is due right now. Use one learned move in a real conversation; Noum will bring it back when a spaced review is useful.")
                .font(Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.brandBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .accessibilityIdentifier("lessons.transferWindow")
    }

    // MARK: - Summary strip

    private var summaryStrip: some View {
        let practicedSkills = LessonsCatalog.all.filter { lessonStore.isCleared($0.id) }.count
        let reviewsReady = lessonStore.reviewsReadyCount
        return HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColor.brandBlue)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(practicedSkills) \(practicedSkills == 1 ? "skill" : "skills") practiced")
                    .font(Typography.headline)
                    .foregroundStyle(.primary)
                Text(reviewsReady == 0
                    ? "Spaced reviews appear when they can test retention."
                    : "\(reviewsReady) \(reviewsReady == 1 ? "review is" : "reviews are") ready now.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(practicedSkills) skills practiced. \(reviewsReady) reviews ready.")
    }

    // MARK: - Catalog grouped by category

    private var lessonsByCategory: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            ForEach(Lesson.Category.allCases, id: \.self) { category in
                let lessons = LessonsCatalog.all.filter {
                    $0.category == category && $0.id != recommendedLesson?.id
                }
                if !lessons.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(category.label)
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 0) {
                            ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                                lessonRow(lesson)
                                if index < lessons.count - 1 {
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
                    Text(LessonReviewPresentation(progress: lessonStore.progress(for: lesson.id)).rowLabel)
                        .font(Typography.caption.weight(.medium))
                        .foregroundStyle(lessonStatusColor(for: lesson.id))
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
        .buttonStyle(.plain)
        .accessibilityIdentifier("lessons.row.\(lesson.id)")
    }

    private func lessonStatusColor(for lessonID: String) -> Color {
        switch lessonStore.reviewState(for: lessonID) {
        case .ready: return AppColor.brandBlue
        case .new, .waiting: return .secondary
        }
    }
}

// MARK: - Celebration overlay

@available(iOS 17.0, macOS 12.0, *)
struct LessonCelebrationOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    Text(progressLine)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    ForEach(0..<LessonStore.masteryPassCap, id: \.self) { i in
                        Image(systemName: i < celebration.practicePassCount ? "checkmark.seal.fill" : "circle")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(i < celebration.practicePassCount ? AppColor.brandBlue : Color.secondary.opacity(0.3))
                    }
                }
                .accessibilityLabel(LessonProgressPresentation(completedPasses: celebration.practicePassCount).accessibilityLabel)

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
            guard !reduceMotion else {
                hasAppeared = true
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                hasAppeared = true
            }
        }
    }

    private var progressLine: String {
        LessonProgressPresentation(completedPasses: celebration.practicePassCount)
            .celebrationLine(for: celebration.kind)
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
            practicePassCount: 1
        ),
        lesson: LessonsCatalog.ruleOfThree,
        onDismiss: {}
    )
}
#endif

#endif
