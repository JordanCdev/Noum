import Foundation

// MARK: - Pressure ladder

/// Roleplay-specific escalation ladder: easy -> realistic -> hostile.
/// Distinct from `BaselineEngine.PressureLevel` (session-level classification
/// used for baseline/rating) — this ladder governs which objections a
/// roleplay scenario surfaces and how sharply the persona pushes back.
enum RoleplayPressureLevel: Int, Codable, Comparable, CaseIterable, Identifiable, Hashable {
    case easy = 0
    case realistic = 1
    case hostile = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .realistic: return "Realistic"
        case .hostile: return "Hostile"
        }
    }

    var subtitle: String {
        switch self {
        case .easy: return "One clear, friendly objection."
        case .realistic: return "Normal pushback — the kind you'd actually get."
        case .hostile: return "Sharp and skeptical. No easy openings."
        }
    }

    static func < (lhs: RoleplayPressureLevel, rhs: RoleplayPressureLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// nil at `.hostile` — the ladder tops out, it doesn't wrap.
    var next: RoleplayPressureLevel? {
        RoleplayPressureLevel(rawValue: rawValue + 1)
    }

    var previous: RoleplayPressureLevel? {
        RoleplayPressureLevel(rawValue: rawValue - 1)
    }
}

// MARK: - Objections

/// Category tag recorded per turn alongside the raw objection text, so
/// downstream analysis (and tests) can reason about the shape of pushback
/// without string-matching authored copy.
enum RoleplayObjectionType: String, Codable, CaseIterable {
    case clarifyingQuestion
    case skepticalPushback
    case scopeChallenge
    case credibilityChallenge
    case redirect
}

struct RoleplayObjection: Codable, Identifiable, Equatable, Hashable {
    /// Stable, globally-unique key (e.g. "interview.hostile.1"). Uniqueness
    /// across the WHOLE catalog — not just within one scenario — is what
    /// guarantees the same drill can't recur across unrelated roleplays:
    /// `RoleplayStore.usedObjectionIDs` is tracked account-wide, not scoped
    /// per scenario.
    var id: String
    var pressureLevel: RoleplayPressureLevel
    var type: RoleplayObjectionType
    var text: String
}

// MARK: - Rubric

/// A single scored axis of a response. `label` is looked up by `RoleplayEngine`
/// against its shared observable-signal axes. Scenarios can weight speaking,
/// listening, ownership, inquiry, and constructive next steps differently
/// without adding per-scenario state or provider calls.
struct RoleplayRubricCriterion: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var label: String
    /// 0...1; a scenario's criteria should sum to ~1.0.
    var weight: Double
    /// What a weak response on this axis looks like — used to phrase the
    /// post-turn "gap" line.
    var lowSignalHint: String
    /// What a strong response on this axis looks like — used to phrase the
    /// post-turn "strength" line.
    var strongSignalHint: String
}

// MARK: - Scenario

struct RoleplayScenario: Codable, Identifiable, Equatable, Hashable {
    var scenarioId: String
    var title: String
    var personaName: String
    var personaRole: String
    var objective: String
    var objectionSet: [RoleplayObjection]
    var rubric: [RoleplayRubricCriterion]

    var id: String { scenarioId }

    func objections(at level: RoleplayPressureLevel) -> [RoleplayObjection] {
        objectionSet.filter { $0.pressureLevel == level }
    }
}

// MARK: - Catalog

/// Authored content for the core pressure and interpersonal entry points. Objection text
/// is written in the persona's voice directly (no AI generation needed to
/// "deliver" it) so the pressure ladder works fully offline and
/// deterministically — see RoleplayEngine's doc-comment for why this was
/// chosen over routing through AINPCChatService.
enum RoleplayCatalog {
    static let interview = RoleplayScenario(
        scenarioId: "interview",
        title: "Job interview",
        personaName: "Morgan Hale",
        personaRole: "Hiring manager",
        objective: "Answer each question directly, back it with a real example, and hold your composure when pushed.",
        objectionSet: [
            RoleplayObjection(id: "interview.easy.0", pressureLevel: .easy, type: .clarifyingQuestion, text: "Walk me through why you're looking to leave your current role."),
            RoleplayObjection(id: "interview.easy.1", pressureLevel: .easy, type: .clarifyingQuestion, text: "What's an example of a project you're proud of."),
            RoleplayObjection(id: "interview.easy.2", pressureLevel: .easy, type: .clarifyingQuestion, text: "Where do you want to be in the next few years."),
            RoleplayObjection(id: "interview.realistic.0", pressureLevel: .realistic, type: .skepticalPushback, text: "That answer's a bit generic. Can you get specific about your actual contribution."),
            RoleplayObjection(id: "interview.realistic.1", pressureLevel: .realistic, type: .credibilityChallenge, text: "You mentioned you led that project — who else could take credit for the result."),
            RoleplayObjection(id: "interview.realistic.2", pressureLevel: .realistic, type: .clarifyingQuestion, text: "How would your last manager describe your biggest weakness."),
            RoleplayObjection(id: "interview.hostile.0", pressureLevel: .hostile, type: .credibilityChallenge, text: "Three companies in four years. Why should I believe you'll stay here."),
            RoleplayObjection(id: "interview.hostile.1", pressureLevel: .hostile, type: .skepticalPushback, text: "That story sounds rehearsed. What actually went wrong on that project."),
            RoleplayObjection(id: "interview.hostile.2", pressureLevel: .hostile, type: .credibilityChallenge, text: "I'm not convinced you were the reason that worked. Convince me.")
        ],
        rubric: [
            RoleplayRubricCriterion(id: "interview.directness", label: "Directness", weight: 0.4, lowSignalHint: "You circled the question before answering it — lead with the answer next time.", strongSignalHint: "You answered the actual question in the first sentence."),
            RoleplayRubricCriterion(id: "interview.evidence", label: "Evidence", weight: 0.35, lowSignalHint: "You stayed general — name the actual project, number, or outcome.", strongSignalHint: "You backed it with a specific, concrete example."),
            RoleplayRubricCriterion(id: "interview.composure", label: "Composure", weight: 0.25, lowSignalHint: "The hedging crept in once the pushback landed — commit to the answer.", strongSignalHint: "You held your tone even under the pushback.")
        ]
    )

    static let leadershipUpdate = RoleplayScenario(
        scenarioId: "leadershipUpdate",
        title: "Leadership update",
        personaName: "Priya Nandan",
        personaRole: "VP overseeing your team",
        objective: "Deliver the update in plain terms, own the risk, and don't bury the real number.",
        objectionSet: [
            RoleplayObjection(id: "leadershipUpdate.easy.0", pressureLevel: .easy, type: .clarifyingQuestion, text: "Give me the one-line status on the project."),
            RoleplayObjection(id: "leadershipUpdate.easy.1", pressureLevel: .easy, type: .clarifyingQuestion, text: "What's blocking the team right now."),
            RoleplayObjection(id: "leadershipUpdate.easy.2", pressureLevel: .easy, type: .clarifyingQuestion, text: "When do you expect this to ship."),
            RoleplayObjection(id: "leadershipUpdate.realistic.0", pressureLevel: .realistic, type: .skepticalPushback, text: "That timeline slipped once already. What's different this time."),
            RoleplayObjection(id: "leadershipUpdate.realistic.1", pressureLevel: .realistic, type: .scopeChallenge, text: "You said 'mostly on track' — what's the part that isn't."),
            RoleplayObjection(id: "leadershipUpdate.realistic.2", pressureLevel: .realistic, type: .scopeChallenge, text: "Who owns the risk if this misses again."),
            RoleplayObjection(id: "leadershipUpdate.hostile.0", pressureLevel: .hostile, type: .credibilityChallenge, text: "I heard a very different version of this from someone on your team. Which one's true."),
            RoleplayObjection(id: "leadershipUpdate.hostile.1", pressureLevel: .hostile, type: .skepticalPushback, text: "You've said 'almost there' for three updates running. Give me the actual number."),
            RoleplayObjection(id: "leadershipUpdate.hostile.2", pressureLevel: .hostile, type: .scopeChallenge, text: "If I pulled headcount from this project tomorrow, what breaks first.")
        ],
        rubric: [
            RoleplayRubricCriterion(id: "leadershipUpdate.directness", label: "Directness", weight: 0.45, lowSignalHint: "You softened the number instead of naming it — lead with the real status.", strongSignalHint: "You named the real number and the real blocker without softening it."),
            RoleplayRubricCriterion(id: "leadershipUpdate.evidence", label: "Evidence", weight: 0.3, lowSignalHint: "You gave a vibe, not a status — reference the actual metric or date.", strongSignalHint: "You grounded the update in a specific metric or date."),
            RoleplayRubricCriterion(id: "leadershipUpdate.composure", label: "Composure", weight: 0.25, lowSignalHint: "You got defensive once the update was challenged — stay factual instead.", strongSignalHint: "You stayed factual and unruffled when the update was challenged.")
        ]
    )

    static let stakeholderPushback = RoleplayScenario(
        scenarioId: "stakeholderPushback",
        title: "Stakeholder pushback",
        personaName: "Devon Ashworth",
        personaRole: "Stakeholder reviewing your proposal",
        objective: "Hold your position, address the real objection, and don't concede ground you don't need to.",
        objectionSet: [
            RoleplayObjection(id: "stakeholderPushback.easy.0", pressureLevel: .easy, type: .clarifyingQuestion, text: "Walk me through why this approach over the alternative."),
            RoleplayObjection(id: "stakeholderPushback.easy.1", pressureLevel: .easy, type: .clarifyingQuestion, text: "What happens if we just don't do this."),
            RoleplayObjection(id: "stakeholderPushback.easy.2", pressureLevel: .easy, type: .clarifyingQuestion, text: "How long will this actually take."),
            RoleplayObjection(id: "stakeholderPushback.realistic.0", pressureLevel: .realistic, type: .skepticalPushback, text: "We tried something like this before and it stalled. What's different now."),
            RoleplayObjection(id: "stakeholderPushback.realistic.1", pressureLevel: .realistic, type: .scopeChallenge, text: "This is going to cost more than what you're telling me. Where's the rest of the number."),
            RoleplayObjection(id: "stakeholderPushback.realistic.2", pressureLevel: .realistic, type: .redirect, text: "My team doesn't have bandwidth for this. Whose time does it come out of."),
            RoleplayObjection(id: "stakeholderPushback.hostile.0", pressureLevel: .hostile, type: .credibilityChallenge, text: "Frankly, I don't trust this estimate at all. Why should I sign off."),
            RoleplayObjection(id: "stakeholderPushback.hostile.1", pressureLevel: .hostile, type: .redirect, text: "You're asking me to bet my budget on this. Give me one reason I shouldn't say no right now."),
            RoleplayObjection(id: "stakeholderPushback.hostile.2", pressureLevel: .hostile, type: .credibilityChallenge, text: "Every version of this plan I've seen has failed somewhere else. What makes you different.")
        ],
        rubric: [
            RoleplayRubricCriterion(id: "stakeholderPushback.directness", label: "Directness", weight: 0.35, lowSignalHint: "You hedged instead of taking a position — say plainly where you stand.", strongSignalHint: "You took a clear position instead of hedging."),
            RoleplayRubricCriterion(id: "stakeholderPushback.evidence", label: "Evidence", weight: 0.35, lowSignalHint: "The objection landed and you had nothing concrete to answer it with.", strongSignalHint: "You met the objection with a concrete number or precedent."),
            RoleplayRubricCriterion(id: "stakeholderPushback.composure", label: "Composure", weight: 0.3, lowSignalHint: "You gave ground you didn't need to the moment the pressure rose.", strongSignalHint: "You held your position without getting rattled.")
        ]
    )

    static let difficultQA = RoleplayScenario(
        scenarioId: "difficultQA",
        title: "Difficult Q&A",
        personaName: "Sam Whitfield",
        personaRole: "Skeptical audience member",
        objective: "Answer the actual question first, then add context — don't dodge and don't over-explain.",
        objectionSet: [
            RoleplayObjection(id: "difficultQA.easy.0", pressureLevel: .easy, type: .clarifyingQuestion, text: "Can you clarify what you meant by that last point."),
            RoleplayObjection(id: "difficultQA.easy.1", pressureLevel: .easy, type: .clarifyingQuestion, text: "What data is this based on."),
            RoleplayObjection(id: "difficultQA.easy.2", pressureLevel: .easy, type: .clarifyingQuestion, text: "How does this apply outside your example."),
            RoleplayObjection(id: "difficultQA.realistic.0", pressureLevel: .realistic, type: .skepticalPushback, text: "That number seems optimistic. Where did it come from."),
            RoleplayObjection(id: "difficultQA.realistic.1", pressureLevel: .realistic, type: .scopeChallenge, text: "You skipped over the part where this didn't work. Why."),
            RoleplayObjection(id: "difficultQA.realistic.2", pressureLevel: .realistic, type: .redirect, text: "Isn't this basically the same thing your competitor already tried."),
            RoleplayObjection(id: "difficultQA.hostile.0", pressureLevel: .hostile, type: .redirect, text: "That's not an answer to what I asked. Try again."),
            RoleplayObjection(id: "difficultQA.hostile.1", pressureLevel: .hostile, type: .credibilityChallenge, text: "I've seen this pitch before and it fell apart in six months. Why is this time different."),
            RoleplayObjection(id: "difficultQA.hostile.2", pressureLevel: .hostile, type: .credibilityChallenge, text: "Be honest — do you actually believe this will work, or are you just selling it.")
        ],
        rubric: [
            RoleplayRubricCriterion(id: "difficultQA.directness", label: "Directness", weight: 0.4, lowSignalHint: "You talked around the question instead of answering it first.", strongSignalHint: "You answered the actual question before adding any context."),
            RoleplayRubricCriterion(id: "difficultQA.evidence", label: "Evidence", weight: 0.3, lowSignalHint: "You asserted the point without pointing to what it's based on.", strongSignalHint: "You pointed to a real source or example for the claim."),
            RoleplayRubricCriterion(id: "difficultQA.composure", label: "Composure", weight: 0.3, lowSignalHint: "You got flustered once the question turned pointed.", strongSignalHint: "You stayed level once the question turned pointed.")
        ]
    )

    static let feedbackConversation = RoleplayScenario(
        scenarioId: "feedbackConversation",
        title: "Give feedback",
        personaName: "Alex Chen",
        personaRole: "Teammate receiving your feedback",
        objective: "Stay specific, explain the impact, and leave the other person with one workable next step.",
        objectionSet: [
            RoleplayObjection(id: "feedbackConversation.easy.0", pressureLevel: .easy, type: .clarifyingQuestion, text: "What did I do that caused a problem."),
            RoleplayObjection(id: "feedbackConversation.easy.1", pressureLevel: .easy, type: .clarifyingQuestion, text: "What would you like me to do differently next time."),
            RoleplayObjection(id: "feedbackConversation.easy.2", pressureLevel: .easy, type: .clarifyingQuestion, text: "Can you give me a specific example."),
            RoleplayObjection(id: "feedbackConversation.realistic.0", pressureLevel: .realistic, type: .skepticalPushback, text: "I followed the process we agreed. Why is this suddenly on me."),
            RoleplayObjection(id: "feedbackConversation.realistic.1", pressureLevel: .realistic, type: .scopeChallenge, text: "You're asking me to slow down, but you also keep pushing for speed."),
            RoleplayObjection(id: "feedbackConversation.realistic.2", pressureLevel: .realistic, type: .redirect, text: "Other people do the same thing. Have you spoken to them."),
            RoleplayObjection(id: "feedbackConversation.hostile.0", pressureLevel: .hostile, type: .credibilityChallenge, text: "This feels personal, not useful. What exactly are you basing it on."),
            RoleplayObjection(id: "feedbackConversation.hostile.1", pressureLevel: .hostile, type: .skepticalPushback, text: "You change your expectations every week. Why should I trust this version."),
            RoleplayObjection(id: "feedbackConversation.hostile.2", pressureLevel: .hostile, type: .redirect, text: "Before you criticize me, maybe look at how unclear your own direction was.")
        ],
        rubric: [
            RoleplayRubricCriterion(id: "feedbackConversation.directness", label: "Directness", weight: 0.30, lowSignalHint: "The behavior stayed vague — name the specific moment you want to discuss.", strongSignalHint: "You named the issue without labeling the person."),
            RoleplayRubricCriterion(id: "feedbackConversation.evidence", label: "Evidence", weight: 0.30, lowSignalHint: "The feedback needs one observable example or impact.", strongSignalHint: "You grounded the feedback in a concrete example."),
            RoleplayRubricCriterion(id: "feedbackConversation.constructiveness", label: "Constructiveness", weight: 0.40, lowSignalHint: "Finish with one realistic request for next time.", strongSignalHint: "You turned the feedback into a clear next step.")
        ]
    )

    static let boundaryConversation = RoleplayScenario(
        scenarioId: "boundaryConversation",
        title: "Set a boundary",
        personaName: "Riley Morgan",
        personaRole: "Manager asking for more work",
        objective: "State the limit, protect the important commitment, and offer only what you can actually deliver.",
        objectionSet: [
            RoleplayObjection(id: "boundaryConversation.easy.0", pressureLevel: .easy, type: .clarifyingQuestion, text: "Can you take this on before the end of today."),
            RoleplayObjection(id: "boundaryConversation.easy.1", pressureLevel: .easy, type: .clarifyingQuestion, text: "If today is not possible, what can you commit to."),
            RoleplayObjection(id: "boundaryConversation.easy.2", pressureLevel: .easy, type: .clarifyingQuestion, text: "Which current priority would this displace."),
            RoleplayObjection(id: "boundaryConversation.realistic.0", pressureLevel: .realistic, type: .scopeChallenge, text: "Everyone is stretched. I need you to find a way."),
            RoleplayObjection(id: "boundaryConversation.realistic.1", pressureLevel: .realistic, type: .skepticalPushback, text: "This should only take an hour. Why are you making it difficult."),
            RoleplayObjection(id: "boundaryConversation.realistic.2", pressureLevel: .realistic, type: .redirect, text: "Can you just work later tonight and get both done."),
            RoleplayObjection(id: "boundaryConversation.hostile.0", pressureLevel: .hostile, type: .credibilityChallenge, text: "I need people who solve problems, not people who tell me what they cannot do."),
            RoleplayObjection(id: "boundaryConversation.hostile.1", pressureLevel: .hostile, type: .scopeChallenge, text: "This is not optional. Are you refusing a direct request."),
            RoleplayObjection(id: "boundaryConversation.hostile.2", pressureLevel: .hostile, type: .redirect, text: "If you cannot handle this workload, perhaps we need to discuss your role.")
        ],
        rubric: [
            RoleplayRubricCriterion(id: "boundaryConversation.directness", label: "Directness", weight: 0.40, lowSignalHint: "The limit is still unclear — say what you can or cannot commit to.", strongSignalHint: "You made the limit unambiguous."),
            RoleplayRubricCriterion(id: "boundaryConversation.composure", label: "Composure", weight: 0.25, lowSignalHint: "The pressure pulled you into hedging — keep the boundary factual.", strongSignalHint: "You held the boundary without turning combative."),
            RoleplayRubricCriterion(id: "boundaryConversation.constructiveness", label: "Constructiveness", weight: 0.35, lowSignalHint: "Offer one alternative you can genuinely deliver.", strongSignalHint: "You paired the limit with a workable option.")
        ]
    )

    static let repairTrust = RoleplayScenario(
        scenarioId: "repairTrust",
        title: "Repair trust",
        personaName: "Jordan Ellis",
        personaRole: "Colleague affected by your decision",
        objective: "Hear the impact, own your part without qualification, and propose a concrete change.",
        objectionSet: [
            RoleplayObjection(id: "repairTrust.easy.0", pressureLevel: .easy, type: .clarifyingQuestion, text: "Do you understand why that decision left me out of the loop."),
            RoleplayObjection(id: "repairTrust.easy.1", pressureLevel: .easy, type: .clarifyingQuestion, text: "What do you think you should have done differently."),
            RoleplayObjection(id: "repairTrust.easy.2", pressureLevel: .easy, type: .clarifyingQuestion, text: "How will you stop this happening again."),
            RoleplayObjection(id: "repairTrust.realistic.0", pressureLevel: .realistic, type: .skepticalPushback, text: "You apologized last time too. What is actually changing."),
            RoleplayObjection(id: "repairTrust.realistic.1", pressureLevel: .realistic, type: .credibilityChallenge, text: "You say you value my input, but your actions keep saying otherwise."),
            RoleplayObjection(id: "repairTrust.realistic.2", pressureLevel: .realistic, type: .redirect, text: "Please do not explain the deadline again. I need you to address what you did."),
            RoleplayObjection(id: "repairTrust.hostile.0", pressureLevel: .hostile, type: .credibilityChallenge, text: "I do not trust that you will include me when it matters."),
            RoleplayObjection(id: "repairTrust.hostile.1", pressureLevel: .hostile, type: .skepticalPushback, text: "This sounds like another polished apology with no consequence."),
            RoleplayObjection(id: "repairTrust.hostile.2", pressureLevel: .hostile, type: .redirect, text: "Why should I keep investing in a working relationship you do not protect.")
        ],
        rubric: [
            RoleplayRubricCriterion(id: "repairTrust.listening", label: "Listening", weight: 0.30, lowSignalHint: "Reflect the impact before you explain or solve.", strongSignalHint: "You showed that the other person's experience registered."),
            RoleplayRubricCriterion(id: "repairTrust.ownership", label: "Ownership", weight: 0.40, lowSignalHint: "Name your specific part without adding a defense.", strongSignalHint: "You owned the behavior plainly."),
            RoleplayRubricCriterion(id: "repairTrust.constructiveness", label: "Constructiveness", weight: 0.30, lowSignalHint: "Make the repair concrete by naming what changes next time.", strongSignalHint: "You gave the repair a specific next step.")
        ]
    )

    static let discoveryConversation = RoleplayScenario(
        scenarioId: "discoveryConversation",
        title: "Discovery conversation",
        personaName: "Taylor Brooks",
        personaRole: "Client with an unclear concern",
        objective: "Reflect what you heard, ask useful follow-ups, and resist solving before the real need is clear.",
        objectionSet: [
            RoleplayObjection(id: "discoveryConversation.easy.0", pressureLevel: .easy, type: .clarifyingQuestion, text: "The new process is not really working for my team."),
            RoleplayObjection(id: "discoveryConversation.easy.1", pressureLevel: .easy, type: .clarifyingQuestion, text: "People keep finding workarounds instead of using it."),
            RoleplayObjection(id: "discoveryConversation.easy.2", pressureLevel: .easy, type: .clarifyingQuestion, text: "I am not sure whether the problem is training or the process itself."),
            RoleplayObjection(id: "discoveryConversation.realistic.0", pressureLevel: .realistic, type: .skepticalPushback, text: "You keep asking questions, but I need this fixed."),
            RoleplayObjection(id: "discoveryConversation.realistic.1", pressureLevel: .realistic, type: .scopeChallenge, text: "Every team complains about something different. Which problem are you trying to solve."),
            RoleplayObjection(id: "discoveryConversation.realistic.2", pressureLevel: .realistic, type: .redirect, text: "Can you just tell me what other clients do and skip the interview."),
            RoleplayObjection(id: "discoveryConversation.hostile.0", pressureLevel: .hostile, type: .credibilityChallenge, text: "This feels like you are making me diagnose the product for you."),
            RoleplayObjection(id: "discoveryConversation.hostile.1", pressureLevel: .hostile, type: .skepticalPushback, text: "I have answered this three times. Are you actually listening."),
            RoleplayObjection(id: "discoveryConversation.hostile.2", pressureLevel: .hostile, type: .redirect, text: "If you understood our business, you would already know what matters.")
        ],
        rubric: [
            RoleplayRubricCriterion(id: "discoveryConversation.listening", label: "Listening", weight: 0.35, lowSignalHint: "Reflect the concern so the next question has a clear anchor.", strongSignalHint: "You showed what you heard before moving forward."),
            RoleplayRubricCriterion(id: "discoveryConversation.inquiry", label: "Inquiry", weight: 0.45, lowSignalHint: "Ask a focused question that could change your understanding.", strongSignalHint: "Your question opened useful new information."),
            RoleplayRubricCriterion(id: "discoveryConversation.constructiveness", label: "Constructiveness", weight: 0.20, lowSignalHint: "Explain briefly how the question helps reach a useful next step.", strongSignalHint: "You kept the discovery tied to progress, not interrogation.")
        ]
    )

    static let all: [RoleplayScenario] = [
        interview,
        leadershipUpdate,
        stakeholderPushback,
        difficultQA,
        feedbackConversation,
        boundaryConversation,
        repairTrust,
        discoveryConversation
    ]

    static func scenario(id: String) -> RoleplayScenario? {
        all.first { $0.scenarioId == id }
    }
}
