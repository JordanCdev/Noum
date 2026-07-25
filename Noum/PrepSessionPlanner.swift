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

    /// Quiet availability marker rendered on the step's own row while it is
    /// locked (and voiced in its accessibility label), so the fallback status
    /// is visible even on the last step, which has no later row's lock line
    /// to carry it. Nil when the planned shape is available.
    var fallbackMarkerLine: String? {
        guard isAvailabilityFallback else { return nil }
        let shape = PrepSessionReadiness.shapeName(for: mode)
        let sentenceShape = shape.prefix(1).uppercased() + String(shape.dropFirst())
        return "\(sentenceShape) unavailable — a Timed fallback is offered."
    }

    /// Honest coverage line for a step credited via its Timed fallback: the
    /// step reads done, but never claims the unavailable shape itself was
    /// rehearsed.
    var coveredViaFallbackLine: String {
        "Covered with the Timed fallback — the \(PrepSessionReadiness.shapeName(for: mode)) itself is still untested."
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

    /// User-facing line for the Profile prep row. Calm, no pass/fail. Uses the
    /// rehearsal surface's steps/shapes vocabulary so both surfaces read as one
    /// system.
    var line: String {
        switch level {
        case .notStarted:
            return "No rehearsal reps logged yet. Start with the warm-up — partial prep still counts."
        case .underway:
            let remaining = plannedModes.filter { !coveredModes.contains($0) }
            let remainingNames = remaining.map(Self.shapeName(for:)).joined(separator: " and ")
            return "You've covered \(coveredCount) of \(plannedModes.count) rehearsal steps. Next: \(remainingNames)."
        case .rehearsed:
            return "All \(plannedModes.count) rehearsal steps covered. One more pass close to the day can test what still holds."
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

/// Per-step display state for the rendered rehearsal list. Derived by ordered
/// attribution (see `PrepSessionPlanner.stepStatuses`): completing a gated
/// step's offered Timed fallback advances the lock sequence — the plan can
/// never dead-end on an unavailable shape — while `coveredViaFallback` keeps
/// the row from overclaiming that the shape itself was rehearsed.
struct PrepStepStatus: Equatable {
    enum Phase: Equatable {
        case done
        case current
        case locked
    }

    let phase: Phase
    /// True when the step was credited by a rep in its offered Timed fallback
    /// mode rather than the planned shape itself.
    let coveredViaFallback: Bool
    /// Shape name of the first uncovered earlier step — the real unlock
    /// precondition. Present only while locked. Out-of-band Train reps can
    /// cover later shapes first, so this is never assumed to be index − 1.
    let unlockShapeName: String?
    /// True when that blocking step's planned shape is unavailable, so its
    /// offered Timed fallback is what actually unlocks this step.
    let unlockViaFallbackAvailable: Bool

    /// User-facing lock line. The fallback case gets its own sentence so the
    /// availability note never garbles the unlock condition.
    var unlockLine: String? {
        guard phase == .locked, let unlockShapeName else { return nil }
        guard unlockViaFallbackAvailable else {
            return "Unlocks after the \(unlockShapeName)."
        }
        return "Unlocks after the \(unlockShapeName) — its Timed fallback counts."
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
    ///   - modeAvailability: capability snapshot owning rendered step copy and
    ///     routes. It is intentionally required so no new caller can silently
    ///     render a gated exercise as available.
    static func plan(
        bigMoment: BigMoment,
        daysRemaining: Int,
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
                rationale: "Ease in gently — settle your pace and shape one clear opening.",
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
        let windowSessions = sessions.filter {
            $0.date >= momentCreatedAt
                && PracticeProgressEligibility.qualifies($0)
        }
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

    /// Derive the rendered list's per-step state. Pure — same inputs as
    /// `readiness(plan:sessions:momentCreatedAt:)`, but attribution is
    /// per-step: steps are walked in order and each consumes the earliest
    /// unconsumed qualifying rep whose mode matches the step's planned shape
    /// or, when that shape is unavailable, its offered Timed fallback.
    /// Planned-shape reps are preferred so a real pressure rep is never
    /// mislabelled as fallback coverage. One timed rep credits the warm-up
    /// only; a second timed rep credits a gated step's fallback. Readiness
    /// stays the honest shape-coverage read for the coach and Profile — this
    /// derivation only keeps the lock sequence passable.
    static func stepStatuses(
        plan: PrepSessionPlan,
        sessions: [PracticeSession],
        momentCreatedAt: Date
    ) -> [PrepStepStatus] {
        let windowReps = sessions
            .filter {
                $0.date >= momentCreatedAt
                    && PracticeProgressEligibility.qualifies($0)
            }
            .sorted { $0.date < $1.date }
        var consumed = [Bool](repeating: false, count: windowReps.count)

        func consumeEarliest(_ mode: PracticeMode) -> Bool {
            guard let index = windowReps.indices.first(where: {
                !consumed[$0] && windowReps[$0].mode == mode
            }) else { return false }
            consumed[index] = true
            return true
        }

        let coverage: [(covered: Bool, viaFallback: Bool)] = plan.steps.map { step in
            if consumeEarliest(step.mode) { return (true, false) }
            if step.isAvailabilityFallback, consumeEarliest(step.renderedMode) {
                return (true, true)
            }
            return (false, false)
        }

        let firstOpenIndex = coverage.firstIndex { !$0.covered }
        return plan.steps.indices.map { index in
            let phase: PrepStepStatus.Phase
            if coverage[index].covered {
                phase = .done
            } else if index == firstOpenIndex {
                phase = .current
            } else {
                phase = .locked
            }
            var unlockShapeName: String?
            var unlockViaFallbackAvailable = false
            if phase == .locked, let firstOpenIndex {
                let blocking = plan.steps[firstOpenIndex]
                unlockShapeName = PrepSessionReadiness.shapeName(for: blocking.mode)
                unlockViaFallbackAvailable = blocking.isAvailabilityFallback
            }
            return PrepStepStatus(
                phase: phase,
                coveredViaFallback: coverage[index].viaFallback,
                unlockShapeName: unlockShapeName,
                unlockViaFallbackAvailable: unlockViaFallbackAvailable
            )
        }
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
        steps: [PrepRepStep]? = nil
    ) -> String {
        let categoryName = category.displayName
        // Two casings: the clause opens the sentence for days > 1 but sits
        // mid-sentence for the day-of and day-before lines.
        let titleDetail = (title.count <= 40 && !title.isEmpty) ? " (\(title))" : ""
        let midSentenceClause = "your \(categoryName)\(titleDetail)"
        let sentenceStartClause = "Your \(categoryName)\(titleDetail)"

        let proximity: String
        if days <= 0 {
            proximity = "Today is the day — \(midSentenceClause) is here. Keep it light: one steady pass is enough."
        } else if days == 1 {
            proximity = "Tomorrow is \(midSentenceClause). One last set of reps — make them count."
        } else if days <= 3 {
            proximity = "\(sentenceStartClause) is \(days) days away. These reps are the difference between rehearsed and rattled."
        } else if days <= 7 {
            proximity = "\(sentenceStartClause) is a week out. Time to load the rehearsals."
        } else {
            proximity = "\(sentenceStartClause) is \(days) days away. Build the muscle now so the moment feels lighter."
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
        // The step list below carries the plan itself; the intro carries the
        // WHY (graduated exposure: ease in → hold pressure → rehearse the
        // actual shape). The arc names only what the rendered plan actually
        // contains — when a shape is gated, the sentence describes its Timed
        // stand-in instead of promising an exercise the list doesn't offer.
        let arc: String
        switch (pressureAvailable, conversationAvailable) {
        case (true, true):
            arc = "The plan mirrors the day itself: ease in, hold up under pressure, then rehearse what you'll actually face."
        case (false, true):
            arc = "The plan mirrors the day itself: ease in, build up in Timed Practice, then rehearse what you'll actually face."
        case (true, false):
            arc = "The plan mirrors the day itself: ease in, hold up under pressure, then rehearse a likely question in Timed Practice."
        case (false, false):
            arc = "The plan mirrors the day itself: ease in, then two focused Timed Practice passes — one controlled build-up, one likely question."
        }

        return "\(proximity) \(arc)"
    }
}
