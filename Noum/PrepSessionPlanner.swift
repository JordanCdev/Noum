import Foundation

// MARK: - Prep Session Planner
//
// A real coach's highest-value session is the one right before the
// Big Moment — a mock interview, a presentation rehearsal, a
// difficult-conversation simulation. Noum has the practice modes
// (Timed, Pressure Drill, IM); M23 frames a session as a rehearsal
// for a specific upcoming event.
//
// The planner is a pure-function decision maker. Given a BigMoment +
// optional baseline + voice + daysRemaining, it produces a structured
// `PrepSessionPlan` describing the three reps the user should run,
// the IM scenario seed for the audience-simulation round, and the
// coach's introduction copy.
//
// Pure function — no I/O, no singletons. Easy to unit test. The plan
// is deterministic: same inputs → same outputs.

// MARK: - Plan model

/// One rep in the prep session sequence. The mode + a coaching label
/// the intro card uses to describe what this rep targets.
struct PrepRepStep: Equatable {
    let mode: PracticeMode
    /// Display label, e.g. "Warm up · 2 min Timed".
    let displayLabel: String
    /// One-line rationale shown in the intro card and the inter-rep
    /// card. Coach voice.
    let rationale: String
}

/// Adversarial IM seed for the audience-simulation round. The IM mode
/// reads these to plant the persona + opening prompts.
struct IMScenarioConfig: Equatable {
    /// Short persona description: "skeptical board member", "tough
    /// hiring panel", etc.
    let persona: String
    /// 3-5 starter questions the audience would ask. Category-specific.
    let starterPrompts: [String]
    /// Hint to the IM tone selector ("formal", "challenging", "warm").
    let toneHint: String
}

/// The full prep session plan. Three reps + an IM scenario + the
/// coach intro copy that frames everything as a rehearsal for the
/// specific upcoming moment.
struct PrepSessionPlan: Equatable {
    /// Coach voice intro shown on the prep landing card. References
    /// the BigMoment category + days remaining + the warm-up sequence.
    let introductionCopy: String
    /// The three reps, in order: warmup → pressure → audience sim.
    let steps: [PrepRepStep]
    /// IM scenario seed for the third step.
    let imScenario: IMScenarioConfig
}

/// F2 — an honest read of how rehearsed the user is for the upcoming moment,
/// computed from how many of the plan's rehearsal SHAPES they've practiced
/// since setting it. Deliberately a "snapshot of where you stand", never a
/// pass/fail gate (matches the prep flow's stated anti-goal contract). The
/// evidence is observed practice activity, never a fabricated confidence
/// number. Closes the prep flow's documented "end-of-prep ready-signal" defer.
struct PrepSessionReadiness: Equatable {
    enum Level: String, Equatable {
        case notStarted   // no rehearsal reps logged since setting the moment
        case underway     // some shapes covered, not all
        case rehearsed    // every rehearsal shape practiced at least once
    }

    /// The plan's rehearsal modes, in order (warm-up / pressure / audience).
    let plannedModes: [PracticeMode]
    /// Which of those modes the user has practiced since the moment was set,
    /// in plan order (stable copy).
    let coveredModes: [PracticeMode]
    /// Total reps logged in the prep window (since the moment was set).
    let totalRepsInWindow: Int
    let level: Level

    var coveredCount: Int { coveredModes.count }

    /// User-facing line for the prep readiness card. Calm, no pass/fail.
    var line: String {
        switch level {
        case .notStarted:
            return "No rehearsal reps logged yet. Start with the warm-up; partial completion still counts."
        case .underway:
            let remaining = plannedModes.filter { !coveredModes.contains($0) }
            let remainingNames = remaining.map(Self.shapeName(for:)).joined(separator: " and ")
            return "You've completed \(coveredCount) of \(plannedModes.count) practice rounds. Next: \(remainingNames)."
        case .rehearsed:
            return "You've completed all \(plannedModes.count) practice rounds. One more pass close to the day can test what still holds."
        }
    }

    /// Terse, user-reported-style line for the coach context (BIG MOMENT
    /// section). Names observed activity, never a confidence claim.
    var contextLine: String {
        switch level {
        case .notStarted:
            return "the user has not logged a rehearsal rep since setting this moment."
        case .underway:
            return "the user has rehearsed \(coveredCount) of \(plannedModes.count) formats (\(totalRepsInWindow) reps since setting it)."
        case .rehearsed:
            return "the user has rehearsed all \(plannedModes.count) formats (\(totalRepsInWindow) reps since setting it)."
        }
    }

    static func shapeName(for mode: PracticeMode) -> String {
        switch mode {
        case .timed:          return "warm-up"
        case .suddenDeath:    return "pressure round"
        case .ahCounter:      return "filler drill"
        case .imConversation: return "audience simulation"
        }
    }
}

// MARK: - Planner

enum PrepSessionPlanner {

    /// Build the plan for an upcoming BigMoment.
    /// - Parameters:
    ///   - bigMoment: the active moment (carries category + title)
    ///   - daysRemaining: days until the moment; copy adapts to proximity
    ///   - voice: coaching voice (currently unused but reserved for
    ///     register tuning — authoritative vs warm coaches frame the
    ///     intro differently in a future iteration)
    static func plan(
        bigMoment: BigMoment,
        daysRemaining: Int,
        voice: SpeakingStyleGoal? = nil
    ) -> PrepSessionPlan {
        let category = bigMoment.category
        let steps: [PrepRepStep] = [
            PrepRepStep(
                mode: .timed,
                displayLabel: "Warm-up: two-minute timed rep",
                rationale: "Loosen up. No pressure — just get your voice on tape."
            ),
            PrepRepStep(
                mode: .suddenDeath,
                displayLabel: "Pressure rep: Pressure Drill",
                rationale: "Composure under fire. One filler ends the round — exactly the stakes you'll feel."
            ),
            PrepRepStep(
                mode: .imConversation,
                displayLabel: "Audience simulation: Conversation Practice",
                rationale: "Hard questions from the kind of audience you're walking into. Stay grounded."
            ),
        ]
        let scenario = scenario(for: category)
        let intro = introCopy(
            category: category,
            title: bigMoment.title,
            days: daysRemaining,
            voice: voice
        )
        return PrepSessionPlan(
            introductionCopy: intro,
            steps: steps,
            imScenario: scenario
        )
    }

    // MARK: - Readiness

    /// Compute how rehearsed the user is for the moment, from practice activity
    /// since it was set. Pure — counts sessions by mode against the plan's
    /// rehearsal shapes. An honest snapshot, never a pass/fail gate: a shape is
    /// "covered" once the user has logged at least one rep in that mode in the
    /// prep window. `momentCreatedAt` bounds the window so only reps done while
    /// preparing for THIS moment count.
    static func readiness(
        plan: PrepSessionPlan,
        sessions: [PracticeSession],
        momentCreatedAt: Date
    ) -> PrepSessionReadiness {
        let plannedModes = plan.steps.map(\.mode)
        let windowSessions = sessions.filter { $0.date >= momentCreatedAt }
        let practiced = Set(windowSessions.map(\.mode))
        // Preserve plan order so the copy reads warm-up → pressure → audience.
        let covered = plannedModes.filter { practiced.contains($0) }
        let level: PrepSessionReadiness.Level
        if covered.isEmpty {
            level = .notStarted
        } else if covered.count >= plannedModes.count {
            level = .rehearsed
        } else {
            level = .underway
        }
        return PrepSessionReadiness(
            plannedModes: plannedModes,
            coveredModes: covered,
            totalRepsInWindow: windowSessions.count,
            level: level
        )
    }

    // MARK: - Category-specific IM scenarios

    /// Adversarial prompts tailored to the BigMomentCategory. These
    /// seed the IM round's opening questions so the audience-simulation
    /// rep is actually a simulation of what the user is preparing for,
    /// not a generic chat.
    static func scenario(for category: BigMomentCategory) -> IMScenarioConfig {
        switch category {
        case .presentation:
            return IMScenarioConfig(
                persona: "Skeptical board member",
                starterPrompts: [
                    "Walk me through the key risk in this.",
                    "What's the ask, in one sentence?",
                    "Why now and not next quarter?",
                ],
                toneHint: "formal"
            )
        case .interview:
            return IMScenarioConfig(
                persona: "Hiring panel",
                starterPrompts: [
                    "Tell me about a time you disagreed with leadership.",
                    "Why this role over the others you're considering?",
                    "What would you fix in your first 90 days?",
                ],
                toneHint: "challenging"
            )
        case .publicSpeaking:
            return IMScenarioConfig(
                persona: "Curious audience member",
                starterPrompts: [
                    "Why this topic? Why you?",
                    "What's the one thing you want the audience to remember?",
                    "What would someone who disagrees with you say?",
                ],
                toneHint: "warm"
            )
        case .review:
            return IMScenarioConfig(
                persona: "Direct manager",
                starterPrompts: [
                    "What's the strongest thing you did this quarter?",
                    "Where did you fall short — and what did you learn?",
                    "What's the case for your next step?",
                ],
                toneHint: "formal"
            )
        case .conversation:
            return IMScenarioConfig(
                persona: "The other person",
                starterPrompts: [
                    "What's the outcome you actually need from this?",
                    "What's the response you're most afraid of?",
                    "What's the smallest version of what you're asking for?",
                ],
                toneHint: "warm"
            )
        case .other:
            return IMScenarioConfig(
                persona: "Tough but fair audience",
                starterPrompts: [
                    "Why does this matter?",
                    "What's the strongest counter-argument?",
                    "What's the one move that would land this?",
                ],
                toneHint: "warm"
            )
        }
    }

    // MARK: - Coach intro copy

    /// Intro paragraph for the prep landing card. References the
    /// category + days remaining in coach voice. Days-aware: a 2-day
    /// intro reads differently than a 12-day intro.
    static func introCopy(
        category: BigMomentCategory,
        title: String,
        days: Int,
        voice: SpeakingStyleGoal?
    ) -> String {
        let categoryName = category.displayName
        let titleClause: String
        if title.count <= 40, !title.isEmpty {
            titleClause = "your \(categoryName) (\(title))"
        } else {
            titleClause = "your \(categoryName)"
        }

        let proximity: String
        if days <= 1 {
            proximity = "Tomorrow is \(titleClause). One last set of reps — make them count."
        } else if days <= 3 {
            proximity = "\(titleClause) is \(days) days away. These reps are the difference between rehearsed and rattled."
        } else if days <= 7 {
            proximity = "\(titleClause) is a week out. Time to load the rehearsals."
        } else {
            proximity = "\(titleClause) is \(days) days away. Build the muscle now so the moment feels lighter."
        }

        return "\(proximity) Three reps: warm up, run a pressure round, then take questions from the kind of audience you're walking into."
    }
}
