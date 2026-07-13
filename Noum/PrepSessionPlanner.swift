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

/// One rep in the prep session sequence. `mode` is the stable rehearsal-shape
/// identity used by readiness; it never changes when capability forces the
/// visible action to Timed Practice. `renderedLaunch` owns the mode/copy/route
/// the user actually sees and can start.
struct PrepRepStep: Equatable {
    /// Stable planned shape. Do not availability-resolve this value: one
    /// fallback Timed rep must not satisfy Pressure or audience readiness.
    let mode: PracticeMode
    let renderedLaunch: PracticeModeLaunchProjection
    /// Display label, e.g. "Warm up · 2 min Timed".
    let displayLabel: String
    /// One-line rationale shown in the intro card and the inter-rep
    /// card. Coach voice.
    let rationale: String

    init(
        mode: PracticeMode,
        displayLabel: String,
        rationale: String,
        renderedLaunch: PracticeModeLaunchProjection
    ) {
        self.mode = mode
        self.displayLabel = displayLabel
        self.rationale = rationale
        self.renderedLaunch = renderedLaunch
    }

    var renderedMode: PracticeMode {
        renderedLaunch.displayedMode
    }

    var isAvailabilityFallback: Bool {
        mode != renderedMode
    }

    var startLabel: String {
        PracticeModePrescriptionCopy.beginLabel(for: renderedMode.displayLabel)
    }

    var readinessLabel: String {
        let shape = PrepSessionReadiness.shapeName(for: mode).capitalized
        guard isAvailabilityFallback else { return shape }
        return "\(shape) unavailable · Timed fallback offered"
    }

    /// Recheck only the action that was rendered. A capability loss may fail
    /// closed to Timed; a rendered Timed fallback never silently upgrades when
    /// the original planned mode becomes available later.
    func resolvingLaunchForTap(
        modeAvailability: NextActionModeAvailability,
        imAvailable: Bool
    ) -> PracticeModeLaunchProjection {
        PracticeModeLaunchProjection.resolve(
            displayedMode: renderedMode,
            imAvailable: imAvailable,
            modeAvailability: modeAvailability
        )
    }
}

/// Reserved adversarial seed for a future category-prefilled conversation
/// round. The current launcher opens the standard Conversation Practice setup;
/// keeping this nil on fallback prevents stale setup from being presented as
/// active behavior.
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
    /// IM scenario seed for the third step. Nil when the rendered audience
    /// step has fallen back to Timed so stale conversation setup cannot leak.
    let imScenario: IMScenarioConfig?
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

    /// Availability-aware line for the rendered Prep surface. Readiness still
    /// credits only the stable planned shapes; this explains why a runnable
    /// Timed fallback does not pretend the unavailable shape was rehearsed.
    func displayLine(for steps: [PrepRepStep]) -> String {
        guard level != .rehearsed else { return line }
        let uncoveredUnavailable = steps.filter {
            $0.isAvailabilityFallback && !coveredModes.contains($0.mode)
        }
        guard !uncoveredUnavailable.isEmpty else { return line }

        let unavailableNames = uncoveredUnavailable
            .map { Self.shapeName(for: $0.mode) }
            .joined(separator: " and ")
        let sentenceUnavailableNames = unavailableNames.prefix(1).uppercased()
            + String(unavailableNames.dropFirst())
        let availabilityNote = "\(sentenceUnavailableNames) \(uncoveredUnavailable.count == 1 ? "remains" : "remain") untested until available; Timed fallback \(uncoveredUnavailable.count == 1 ? "is" : "reps are") available."

        switch level {
        case .notStarted:
            return "No rehearsal reps logged yet. Start with the warm-up. \(availabilityNote)"
        case .underway:
            let availableRemaining = steps.filter {
                !coveredModes.contains($0.mode) && !$0.isAvailabilityFallback
            }
            guard !availableRemaining.isEmpty else {
                return "You've completed \(coveredCount) of \(plannedModes.count) planned rehearsal shapes. \(availabilityNote)"
            }
            let nextNames = availableRemaining
                .map { Self.shapeName(for: $0.mode) }
                .joined(separator: " and ")
            return "You've completed \(coveredCount) of \(plannedModes.count) planned rehearsal shapes. Next: \(nextNames). \(availabilityNote)"
        case .rehearsed:
            return line
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

    /// Category-bounded prompt for a planned Prep shape that must launch in
    /// Timed Practice. The prompt carries no user-entered title or transcript;
    /// it only preserves the rehearsal promise already visible on the card.
    /// The caller route-binds it through `TimedPracticePromptHandoff`.
    static func timedFallbackPrompt(
        for plannedMode: PracticeMode,
        category: BigMomentCategory
    ) -> String? {
        switch plannedMode {
        case .suddenDeath:
            return "Give a clear 60-second opening for your upcoming \(category.displayName)."
        case .imConversation:
            guard let likelyQuestion = scenario(for: category).starterPrompts.first else {
                return nil
            }
            return "Rehearse this likely question for your \(category.displayName): \(likelyQuestion)"
        case .timed, .ahCounter:
            return nil
        }
    }

    /// Build the plan for an upcoming BigMoment.
    /// - Parameters:
    ///   - bigMoment: the active moment (carries category + title)
    ///   - daysRemaining: days until the moment; copy adapts to proximity
    ///   - voice: coaching voice (currently unused but reserved for
    ///     register tuning — authoritative vs warm coaches frame the
    ///     intro differently in a future iteration)
    ///   - modeAvailability: capability snapshot owning rendered step copy and
    ///     routes. It is intentionally required so no new caller can silently
    ///     render a gated exercise as available.
    static func plan(
        bigMoment: BigMoment,
        daysRemaining: Int,
        voice: SpeakingStyleGoal? = nil,
        modeAvailability: NextActionModeAvailability
    ) -> PrepSessionPlan {
        let category = bigMoment.category
        let steps: [PrepRepStep] = [
            renderedStep(for: .timed, modeAvailability: modeAvailability),
            renderedStep(for: .suddenDeath, modeAvailability: modeAvailability),
            renderedStep(for: .imConversation, modeAvailability: modeAvailability),
        ]
        let intro = introCopy(
            category: category,
            title: bigMoment.title,
            days: daysRemaining,
            voice: voice,
            steps: steps
        )
        return PrepSessionPlan(
            introductionCopy: intro,
            steps: steps,
            imScenario: steps.last?.renderedMode == .imConversation
                ? scenario(for: category)
                : nil
        )
    }

    /// Resolve presentation and route together while retaining `plannedMode`
    /// as the readiness identity. The fallback copy describes Timed Practice,
    /// never the unavailable exercise's mechanics.
    private static func renderedStep(
        for plannedMode: PracticeMode,
        modeAvailability: NextActionModeAvailability
    ) -> PrepRepStep {
        let renderedMode = modeAvailability.isAvailable(plannedMode)
            ? plannedMode
            : .timed
        let launch = PracticeModeLaunchProjection.resolve(
            displayedMode: renderedMode,
            imAvailable: modeAvailability.imConversationAvailable,
            modeAvailability: modeAvailability
        )

        switch (plannedMode, renderedMode) {
        case (.timed, _):
            return PrepRepStep(
                mode: plannedMode,
                displayLabel: "Warm-up: two-minute timed rep",
                rationale: "Loosen up. No pressure — just get your voice on tape.",
                renderedLaunch: launch
            )
        case (.suddenDeath, .suddenDeath):
            return PrepRepStep(
                mode: plannedMode,
                displayLabel: "Pressure rep: Pressure Drill",
                rationale: "Composure under fire. One filler ends the round — exactly the stakes you'll feel.",
                renderedLaunch: launch
            )
        case (.suddenDeath, .timed):
            return PrepRepStep(
                mode: plannedMode,
                displayLabel: "Build-up rep: Timed Practice",
                rationale: NextActionModeAvailability.suddenDeathFallbackReason,
                renderedLaunch: launch
            )
        case (.imConversation, .imConversation):
            return PrepRepStep(
                mode: plannedMode,
                displayLabel: "Audience simulation: Conversation Practice",
                rationale: "Hard questions from the kind of audience you're walking into. Stay grounded.",
                renderedLaunch: launch
            )
        case (.imConversation, .timed):
            return PrepRepStep(
                mode: plannedMode,
                displayLabel: "Question rehearsal: Timed Practice",
                rationale: NextActionModeAvailability.imConversationFallbackReason,
                renderedLaunch: launch
            )
        case (.ahCounter, .ahCounter):
            return PrepRepStep(
                mode: plannedMode,
                displayLabel: "Filler drill: Filler Control",
                rationale: "Notice the crutches that surface before the moment.",
                renderedLaunch: launch
            )
        default:
            // Timed is the shared fail-closed destination for every currently
            // gated mode. Keep this branch honest if a future planned shape is
            // added before it receives bespoke fallback copy.
            return PrepRepStep(
                mode: plannedMode,
                displayLabel: "Rehearsal rep: Timed Practice",
                rationale: "This exercise is unavailable here. Start with Timed Practice.",
                renderedLaunch: launch
            )
        }
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

    /// Adversarial prompts tailored to the BigMomentCategory. Reserved for a
    /// future category-prefilled Conversation Practice setup; the current
    /// standard picker does not consume this metadata.
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
        voice: SpeakingStyleGoal?,
        steps: [PrepRepStep]? = nil
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

        let pressureAvailable: Bool
        let conversationAvailable: Bool
        if let steps {
            pressureAvailable = steps
                .first(where: { $0.mode == .suddenDeath })?
                .renderedMode == .suddenDeath
            conversationAvailable = steps
                .first(where: { $0.mode == .imConversation })?
                .renderedMode == .imConversation
        } else {
            pressureAvailable = true
            conversationAvailable = true
        }
        let sequence: String
        switch (pressureAvailable, conversationAvailable) {
        case (true, true):
            sequence = "Three reps: warm up, run a pressure round, then take questions from the kind of audience you're walking into."
        case (false, true):
            sequence = "Three reps: warm up, use Timed Practice for one controlled build-up, then take questions from the kind of audience you're walking into."
        case (true, false):
            sequence = "Three reps: warm up, run a pressure round, then rehearse one likely question in Timed Practice."
        case (false, false):
            sequence = "Three reps: warm up, then use two focused Timed Practice passes — one controlled answer and one likely question."
        }

        return "\(proximity) \(sequence)"
    }
}
