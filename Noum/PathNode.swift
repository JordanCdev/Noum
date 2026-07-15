import Foundation

// MARK: - Path Node Model

/// One concrete step in the user's speaking-skill path. Each node has an
/// entry condition derived from existing engines (sessions, baseline, rating,
/// streak) — no parallel tracking.
///
/// Once unlocked a node stays unlocked. Persistence lives in
/// `PathProgressStore`, keyed per account.
struct PathNode: Identifiable, Equatable {
    let id: String
    let order: Int
    let tier: LeagueTier
    /// Short on-voice title — what the node represents.
    let title: String
    /// One-sentence target the user reads on the path.
    let detail: String
    /// One-line explanation in coach voice — why this step matters.
    let coachLine: String
    /// CTA copy for the action button on the home "next node" card.
    let actionLabel: String
    /// Where one-tap CTA pushes the user.
    let actionDestination: AppDestination
    /// SF Symbol used in the path map.
    let symbolName: String

    static func == (lhs: PathNode, rhs: PathNode) -> Bool { lhs.id == rhs.id }
}

// MARK: - Inputs evaluated by node criteria

/// Snapshot of every signal a node criterion can read. Built once per
/// evaluation pass so a 15-node check is one pass over the session list.
struct PathProgressInput {
    let sessions: [PracticeSession]
    let currentStreak: Int
    let baseline: CommunicationBaseline
    let rating: SpeakingRating
    let modeMastery: [PracticeMode: ModeMasterySnapshot]
    /// Total lesson practice passes the user has completed (sum across the catalog).
    /// Surfaces lesson progress as a path-progression signal — completing
    /// lessons should move the user up the path, not just sit in a
    /// parallel curriculum.
    let totalLessonPasses: Int
    /// Highest practice-pass count the user has reached on any single lesson.
    /// Used by "master a lesson" path nodes.
    let maxLessonPassCount: Int
    let now: Date

    var sessionCount: Int { sessions.count }

    var distinctPracticeDayCount: Int {
        let calendar = Calendar.current
        return Set(sessions.map { calendar.startOfDay(for: $0.date) }).count
    }

    var sessionsLast7Days: [PracticeSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        return sessions.filter { $0.date >= cutoff }
    }

    var hasQuantityQualifiedZeroFillerSession: Bool {
        sessions.contains {
            FillerBurden.quantityQualified($0)?.fillerCount == 0
        }
    }

    func quantityQualifiedZeroFillerCountLast7Days(
        minimumScore: Int
    ) -> Int {
        sessionsLast7Days.filter {
            FillerBurden.quantityQualified($0)?.fillerCount == 0
                && ($0.score ?? 0) >= minimumScore
        }.count
    }
}

// MARK: - Node criteria

/// Pure progress evaluator over `PathProgressInput`. Returns `(progress, complete)`
/// so the UI can render the "current" node with a partial bar.
enum PathNodeCriterion {
    case sessionCountAtLeast(Int)
    case modeSessionAtLeast(PracticeMode, Int)
    case scoreAtLeast(Int)
    case zeroFillerSession
    case streakAtLeast(Int)
    case ratingAtLeast(Int)
    case pressureSurvived(rounds: Int)
    case modeMasteryLevel(PracticeMode, Int)
    case modeMasteryAnyLevel(Int)
    case distinctPracticeDays(Int)
    case cleanRunsInWindow(_ count: Int, minScore: Int)
    case totalLessonPasses(Int)
    case anyLessonMastered
    /// User has held a single silent pause of at least `seconds` in any
    /// session. "Silent" = the pause was unfilled (no disfluency inside it).
    case heldSilentPause(seconds: Double)
    /// At least one session has a pause-fill ratio at or below `maxRatio`
    /// (lower = more composed pauses). Requires a session with ≥ 2 pauses
    /// so a single deliberate pause doesn't trivially complete the node.
    case cleanPauseSession(maxRatio: Double, minPauses: Int)

    func progress(for input: PathProgressInput) -> Double {
        switch self {
        case .sessionCountAtLeast(let n):
            return clamp(input.sessionCount, n)
        case .modeSessionAtLeast(let mode, let n):
            let count = input.sessions.filter { $0.mode == mode }.count
            return clamp(count, n)
        case .scoreAtLeast(let target):
            let best = input.sessions.compactMap(\.score).max() ?? 0
            return clamp(best, target)
        case .zeroFillerSession:
            return input.hasQuantityQualifiedZeroFillerSession ? 1.0 : 0.0
        case .streakAtLeast(let n):
            return clamp(input.currentStreak, n)
        case .ratingAtLeast(let target):
            return clamp(input.rating.peakRating, target)
        case .pressureSurvived(let rounds):
            let any = input.sessions.contains {
                $0.mode == .suddenDeath
                    && $0.pressureLevel >= .elevated
                    && $0.duration >= Double(rounds) * 12
            }
            return any ? 1.0 : 0.0
        case .modeMasteryLevel(let mode, let level):
            let current = input.modeMastery[mode]?.level ?? 1
            return clamp(current, level)
        case .modeMasteryAnyLevel(let level):
            let best = input.modeMastery.values.map(\.level).max() ?? 1
            return clamp(best, level)
        case .distinctPracticeDays(let n):
            return clamp(input.distinctPracticeDayCount, n)
        case .cleanRunsInWindow(let count, let minScore):
            let qualifying = input.quantityQualifiedZeroFillerCountLast7Days(
                minimumScore: minScore
            )
            return clamp(qualifying, count)
        case .totalLessonPasses(let target):
            return clamp(input.totalLessonPasses, target)
        case .anyLessonMastered:
            return input.maxLessonPassCount >= 5 ? 1.0 : Double(input.maxLessonPassCount) / 5.0
        case .heldSilentPause(let target):
            // Best longest-pause across sessions where the pause was
            // unfilled (filledRatio == 0). Sessions whose longest pause
            // happened to be filled don't contribute even if the duration
            // hits the bar — the goal is silent composure.
            let bestSilent = input.sessions
                .compactMap { s -> Double? in
                    guard let m = s.pauseMetrics, m.count > 0, m.filledRatio == 0 else { return nil }
                    return m.longestSeconds
                }
                .max() ?? 0
            return min(1.0, bestSilent / target)
        case .cleanPauseSession(let maxRatio, let minPauses):
            let any = input.sessions.contains { s in
                guard let m = s.pauseMetrics, m.count >= minPauses else { return false }
                return m.filledRatio <= maxRatio
            }
            return any ? 1.0 : 0.0
        }
    }

    func isComplete(for input: PathProgressInput) -> Bool {
        progress(for: input) >= 1.0
    }

    private func clamp(_ value: Int, _ target: Int) -> Double {
        guard target > 0 else { return 1.0 }
        return min(1.0, Double(value) / Double(target))
    }
}

// MARK: - Node registry

/// The full ordered set of nodes. Authored as a list so the order is the
/// ordering in the path UI — no implicit sorting. Tier just colours the icon.
enum PathNodeRegistry {
    static let all: [(PathNode, PathNodeCriterion)] = [
        (
            PathNode(
                id: "first_rep",
                order: 0,
                tier: .bronze,
                title: "First rep",
                detail: "Complete a practice session.",
                coachLine: "One rep is what proves the path can exist.",
                actionLabel: "Start a rep",
                actionDestination: .practiceSelection,
                symbolName: "figure.walk"
            ),
            .sessionCountAtLeast(1)
        ),
        (
            PathNode(
                id: "three_reps",
                order: 1,
                tier: .bronze,
                title: "Three reps",
                detail: "Reach three completed sessions.",
                coachLine: "Three reps starts to flatten the trail under your feet.",
                actionLabel: "Start a rep",
                actionDestination: .practiceSelection,
                symbolName: "figure.walk.motion"
            ),
            .sessionCountAtLeast(3)
        ),
        (
            PathNode(
                id: "first_sudden_death",
                order: 2,
                tier: .bronze,
                title: "First Pressure Drill",
                detail: "Complete one Pressure Drill run.",
                coachLine: "Pressure Drill shows how you handle a clock and a misstep.",
                actionLabel: "Start Pressure Drill",
                actionDestination: .suddenDeathPractice,
                symbolName: "bolt.fill"
            ),
            .modeSessionAtLeast(.suddenDeath, 1)
        ),
        (
            PathNode(
                id: "first_im",
                order: 3,
                tier: .bronze,
                title: "First conversation rep",
                detail: "Complete one Conversation Practice rep.",
                coachLine: "Live conversation tests the muscles drills can't fully reach.",
                actionLabel: "Start Conversation Practice",
                actionDestination: .imPractice(scenario: nil, tone: nil),
                symbolName: "bubble.left.and.bubble.right.fill"
            ),
            .modeSessionAtLeast(.imConversation, 1)
        ),
        (
            PathNode(
                id: "first_lesson",
                order: 4,
                tier: .bronze,
                title: "First lesson cleared",
                detail: "Complete your first lesson practice pass.",
                coachLine: "Lessons teach the technique. One pass means you've built the recognition.",
                actionLabel: "Start a lesson",
                actionDestination: .lessons,
                symbolName: "books.vertical.fill"
            ),
            .totalLessonPasses(1)
        ),
        (
            PathNode(
                id: "clean_rep",
                order: 5,
                tier: .silver,
                title: "Clean rep",
                detail: "Complete a zero-filler rep of at least \(SessionQualifier.minimumWordCount) words and \(Int(SessionQualifier.minimumDuration)) seconds.",
                coachLine: "One full clean rep is useful evidence. Repeat it to see whether the control holds.",
                actionLabel: "Start a rep",
                actionDestination: .practiceSelection,
                symbolName: "checkmark.seal.fill"
            ),
            .zeroFillerSession
        ),
        (
            PathNode(
                id: "score_six",
                order: 6,
                tier: .silver,
                title: "Score 6+",
                detail: "Hit a session score of 6 out of 10.",
                coachLine: "Six is the threshold where structure starts holding under any topic.",
                actionLabel: "Start a rep",
                actionDestination: .practiceSelection,
                symbolName: "6.circle.fill"
            ),
            .scoreAtLeast(6)
        ),
        (
            PathNode(
                id: "three_day_streak",
                order: 7,
                tier: .silver,
                title: "Three-day streak",
                detail: "Practice three days in a row.",
                coachLine: "Three consecutive days is when the habit starts owning your reps, not the other way around.",
                actionLabel: "Start a rep",
                actionDestination: .practiceSelection,
                symbolName: "flame.fill"
            ),
            .streakAtLeast(3)
        ),
        (
            PathNode(
                id: "score_eight",
                order: 8,
                tier: .gold,
                title: "Score 8+",
                detail: "Hit a session score of 8.",
                coachLine: "Eight means clarity, structure, and pacing were all working together.",
                actionLabel: "Start a rep",
                actionDestination: .practiceSelection,
                symbolName: "8.circle.fill"
            ),
            .scoreAtLeast(8)
        ),
        (
            PathNode(
                id: "rating_500",
                order: 9,
                tier: .gold,
                title: "Rating 500",
                detail: "Reach a peak speaking rating of 500.",
                coachLine: "A 500 rating marks stronger decisions across rated pressure reps.",
                actionLabel: "Start Pressure Drill",
                actionDestination: .suddenDeathPractice,
                symbolName: "chart.line.uptrend.xyaxis"
            ),
            .ratingAtLeast(500)
        ),
        (
            PathNode(
                id: "sudden_death_round_3",
                order: 10,
                tier: .gold,
                title: "Pressure Drill survivor",
                detail: "Survive into round 3 of a Pressure Drill session.",
                coachLine: "Round 3 is past the warmup. Holding it means you're composing under load.",
                actionLabel: "Start Pressure Drill",
                actionDestination: .suddenDeathPractice,
                symbolName: "shield.lefthalf.filled"
            ),
            .pressureSurvived(rounds: 3)
        ),
        (
            PathNode(
                id: "seven_day_streak",
                order: 11,
                tier: .gold,
                title: "Seven-day streak",
                detail: "Practice seven days in a row.",
                coachLine: "A week without a missed day means speaking practice is part of your day, not on top of it.",
                actionLabel: "Start a rep",
                actionDestination: .practiceSelection,
                symbolName: "flame.circle.fill"
            ),
            .streakAtLeast(7)
        ),
        (
            PathNode(
                id: "mode_mastery_three",
                order: 12,
                tier: .platinum,
                title: "Mode mastery III",
                detail: "Reach mastery level 3 in any practice mode.",
                coachLine: "Going deep in one mode beats going shallow in four.",
                actionLabel: "Start a rep",
                actionDestination: .practiceSelection,
                symbolName: "rosette"
            ),
            .modeMasteryAnyLevel(3)
        ),
        (
            PathNode(
                id: "rating_700",
                order: 13,
                tier: .platinum,
                title: "Rating 700",
                detail: "Reach a peak speaking rating of 700.",
                coachLine: "700 is where coaching defaults to refinement, not correction.",
                actionLabel: "Start Pressure Drill",
                actionDestination: .suddenDeathPractice,
                symbolName: "star.fill"
            ),
            .ratingAtLeast(700)
        ),
        (
            PathNode(
                id: "filler_free_week",
                order: 14,
                tier: .platinum,
                title: "Filler-free week",
                detail: "Within seven days, complete five zero-filler reps of \(SessionQualifier.minimumWordCount)+ words, \(Int(SessionQualifier.minimumDuration))+ seconds, and 5/10+.",
                coachLine: "Five full clean reps in one week show repeatable control in practice.",
                actionLabel: "Start a rep",
                actionDestination: .practiceSelection,
                symbolName: "sparkles"
            ),
            .cleanRunsInWindow(5, minScore: 5)
        ),
        (
            PathNode(
                id: "five_lesson_crowns",
                order: 15,
                tier: .platinum,
                title: "Five lesson passes",
                detail: "Complete five practice passes across the lessons catalog.",
                coachLine: "Five passes means the techniques aren't theoretical anymore — they're moves you've practiced.",
                actionLabel: "Start a lesson",
                actionDestination: .lessons,
                symbolName: "checkmark.seal.fill"
            ),
            .totalLessonPasses(5)
        ),
        (
            PathNode(
                id: "thirty_distinct_days",
                order: 16,
                tier: .diamond,
                title: "Thirty days trained",
                detail: "Practice on thirty distinct days.",
                coachLine: "Thirty days of returns is a real practice, not a streak hack.",
                actionLabel: "Start a rep",
                actionDestination: .practiceSelection,
                symbolName: "calendar.badge.checkmark"
            ),
            .distinctPracticeDays(30)
        ),
        (
            PathNode(
                id: "any_lesson_mastered",
                order: 17,
                tier: .diamond,
                title: "Master a lesson",
                detail: "Take any lesson through five successful practice passes.",
                coachLine: "Mastery means the move has survived repetition, not just recognition.",
                actionLabel: "Start a lesson",
                actionDestination: .lessons,
                symbolName: "rosette"
            ),
            .anyLessonMastered
        ),
        (
            PathNode(
                id: "held_silent_pause",
                order: 18,
                tier: .gold,
                title: "Hold a silent beat",
                detail: "Hold a single silent pause of 1.5 seconds or longer in any rep.",
                coachLine: "One held beat gives the next sentence room to land without adding a filler.",
                actionLabel: "Start a rep",
                actionDestination: .practiceSelection,
                symbolName: "pause.circle.fill"
            ),
            .heldSilentPause(seconds: 1.5)
        ),
        (
            PathNode(
                id: "clean_pause_session",
                order: 19,
                tier: .platinum,
                title: "Composed pauses",
                detail: "Land a session with three or more pauses, fewer than 25% filled with disfluency.",
                coachLine: "Composed delivery isn't no pauses — it's pauses that sound chosen. This is the bar.",
                actionLabel: "Start a rep",
                actionDestination: .practiceSelection,
                symbolName: "waveform.path"
            ),
            .cleanPauseSession(maxRatio: 0.25, minPauses: 3)
        )
    ]
}
