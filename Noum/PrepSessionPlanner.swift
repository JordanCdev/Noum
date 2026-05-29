import Foundation

// MARK: - Prep Session Planner
//
// A real coach's highest-value session is the one right before the
// Big Moment — a mock interview, a presentation rehearsal, a
// difficult-conversation simulation. Noum has the practice modes
// (Timed, Sudden Death, IM); M23 frames a session as a rehearsal
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
                displayLabel: "Warm up · 2-minute Timed rep",
                rationale: "Loosen up. No pressure — just get your voice on tape."
            ),
            PrepRepStep(
                mode: .suddenDeath,
                displayLabel: "Pressure round · Sudden Death",
                rationale: "Composure under fire. One filler ends the round — exactly the stakes you'll feel."
            ),
            PrepRepStep(
                mode: .imConversation,
                displayLabel: "Audience simulation · IM round",
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
