import Foundation

// MARK: - Deterministic coach reasoning pass

/// A coarse learning stage keeps the coach from handing the user the same
/// beginner drill forever. It is an internal planning value, never surface copy.
enum CoachSkillStage: String, Codable, Equatable, CaseIterable {
    case establish
    case stretch
    case transfer
    case recover
}

/// One bounded professional intervention. The catalogue is intentionally small:
/// each move has a clear indication, contraindication, demonstration, exercise,
/// pass condition and real-world transfer. This is more useful than a long menu
/// of tips because the reasoning pass must choose one move and explain why.
struct CoachInterventionSpec: Equatable, Identifiable {
    let id: String
    let dimensionID: String?
    let title: String
    let whenToUse: String
    let whenNotToUse: String
    let modelLine: String
    let drill: String
    let passCondition: String
    let transferPrompt: String
    let signatureTerms: [String]

    func move(for stage: CoachSkillStage) -> String {
        switch stage {
        case .establish:
            return drill
        case .stretch:
            return "\(drill) Add one extra demand. It passes when \(passCondition)"
        case .transfer:
            return transferPrompt
        case .recover:
            return "Do not add a drill yet. Model the move once: “\(modelLine)”"
        }
    }
}

struct CoachInterventionChoice: Equatable {
    let intervention: CoachInterventionSpec
    let stage: CoachSkillStage
    let move: String

    var noveltyKey: String { "\(intervention.id):\(stage.rawValue)" }
}

/// Private deliberation contract used to brief the provider before it writes
/// prose. Keeping these fields typed prevents "scorecard first, advice second"
/// generation: the model receives one situation, one behavioural read and one
/// chosen intervention with an observable success test.
struct CoachDecisionPlan: Equatable {
    let situation: String
    let stakes: String
    let emotion: String
    let observedBehavior: String
    let exactEvidence: String
    let skillStage: CoachSkillStage
    let chosenIntervention: String
    let successTest: String
    let modelLine: String?
    let invitation: String?
    let replyPosture: CoachReplyPosture
    /// Non-nil only for a user-requested generic reference range. It never
    /// authorizes a claim about the user's own performance.
    let benchmarkAuthorization: CoachBenchmarkAuthorization?
}

enum CoachReasoningPass {

    static let interventionCatalogue: [CoachInterventionSpec] = [
        CoachInterventionSpec(
            id: "answer-first",
            dimensionID: "verdict_first",
            title: "Answer first",
            whenToUse: "The answer is delayed by setup or context.",
            whenNotToUse: "The user is asking for presence, or the decision itself is still unknown.",
            modelLine: "My recommendation is to delay the launch by one week. The dependency is not ready.",
            drill: "Give one 30-second answer: recommendation in sentence one, one reason in sentence two, then stop.",
            passCondition: "a listener can state the recommendation after sentence one.",
            transferPrompt: "Use the same two-sentence shape in the next real update, then ask whether the decision was clear.",
            signatureTerms: ["sentence one", "recommendation first", "answer first", "verdict first"]
        ),
        CoachInterventionSpec(
            id: "one-proof-point",
            dimensionID: "salience",
            title: "One proof point",
            whenToUse: "The claim is clear but generic or forgettable.",
            whenNotToUse: "The listener cannot yet tell what the main point is.",
            modelLine: "We should delay because the payment flow still fails for returning customers.",
            drill: "State the point, add one concrete example, then stop before a second example.",
            passCondition: "the example proves the point without opening a second thread.",
            transferPrompt: "Use one real proof point in the next meeting and notice what the listener repeats back.",
            signatureTerms: ["one proof point", "one concrete example", "second example", "concrete detail", "the example"]
        ),
        CoachInterventionSpec(
            id: "clean-close",
            dimensionID: "clean_close",
            title: "Land the close",
            whenToUse: "The point lands but the speaker reopens it, trails off, or hides the ask.",
            whenNotToUse: "The opening is still unclear enough that the listener cannot follow the answer.",
            modelLine: "I need your decision by Thursday.",
            drill: "Make the final sentence the ask or decision, then leave the silence there.",
            passCondition: "nothing after the final sentence weakens or re-explains it.",
            transferPrompt: "Use the clean close in the next real ask and note whether the listener responds to it directly.",
            signatureTerms: ["final sentence", "clean close", "leave the silence", "then stop", "the ask"]
        ),
        CoachInterventionSpec(
            id: "functional-pause",
            dimensionID: "controlled_pacing",
            title: "Give the pause a job",
            whenToUse: "Sentence boundaries disappear or filler pressure rises between ideas.",
            whenNotToUse: "The user is already slow and the real problem is an unclear message.",
            modelLine: "The answer is no. [one beat] The cost is too high.",
            drill: "Keep the natural pace and place one silent beat before the final sentence.",
            passCondition: "the next sentence starts cleanly without a filler or restart.",
            transferPrompt: "Use one deliberate beat before the key line in the next real conversation and check whether it feels easier to follow.",
            signatureTerms: ["silent beat", "one beat", "natural pace", "before the final sentence", "filler"]
        ),
        CoachInterventionSpec(
            id: "plain-commitment",
            dimensionID: "hedge_control",
            title: "Plain commitment",
            whenToUse: "A clear recommendation is softened by an unnecessary hedge.",
            whenNotToUse: "Uncertainty is real and should be named rather than hidden.",
            modelLine: "I recommend option B. The evidence is incomplete, but this is the better risk.",
            drill: "Replace one unnecessary maybe or probably with a plain recommendation, while keeping any real uncertainty.",
            passCondition: "the commitment and the genuine uncertainty are both easy to hear.",
            transferPrompt: "Use one plain recommendation in the next decision conversation and ask what sounded certain versus still open.",
            signatureTerms: ["plain recommendation", "maybe", "probably", "real uncertainty", "genuine uncertainty", "commitment", "hedge"]
        ),
        CoachInterventionSpec(
            id: "pressure-anchor",
            dimensionID: "pressure_stability",
            title: "Protect one anchor line",
            whenToUse: "A useful structure breaks when time, interruption, or social risk rises.",
            whenNotToUse: "The base message has not yet been made clear without pressure.",
            modelLine: "The point I do not want to lose is this: we need a decision today.",
            drill: "Run the same prompt under pressure and protect only the first clear sentence from setup.",
            passCondition: "the anchor line stays intact even if the rest becomes less polished.",
            transferPrompt: "Use the anchor line in the next stakes moment and note whether you can return to it after an interruption.",
            signatureTerms: ["under pressure", "anchor line", "timer", "keep sentence one", "after an interruption"]
        ),
        CoachInterventionSpec(
            id: "warm-disagreement",
            dimensionID: "pressure_stability",
            title: "Disagree before reassuring",
            whenToUse: "Reassurance delays the disagreement and makes the speaker sound defensive.",
            whenNotToUse: "The relationship needs immediate repair or the user does not yet know their position.",
            modelLine: "I disagree with that direction. My concern is the customer risk.",
            drill: "Say the disagreement in sentence one, add one calm reason, then stop before reassuring.",
            passCondition: "the position is clear without the delivery becoming hostile.",
            transferPrompt: "Use the same order in one low-risk disagreement and notice whether warmth survives after the point is clear.",
            signatureTerms: ["disagreement in sentence one", "calm reason", "before reassuring", "i disagree", "position is clear", "low-risk disagreement"]
        ),
        CoachInterventionSpec(
            id: "story-beat",
            dimensionID: "salience",
            title: "Build one story beat",
            whenToUse: "A story is abstract, chronological without a point, or missing the moment that changed something.",
            whenNotToUse: "The listener needs a direct decision or answer before any narrative.",
            modelLine: "We thought onboarding was fixed. Then one customer shared their screen and stalled at the same step twice. That is why we changed the flow.",
            drill: "Tell one 45-second story with three beats: expectation, turning point, meaning. Keep one concrete detail in the turning point.",
            passCondition: "the listener can name what changed and why the story matters.",
            transferPrompt: "Use the three-beat story in the next real explanation and ask what moment the listener remembers.",
            signatureTerms: ["three beats", "turning point", "why the story matters", "story beat", "moment the listener remembers", "expectation"]
        ),
        CoachInterventionSpec(
            id: "listening-loop",
            dimensionID: nil,
            title: "Close the listening loop",
            whenToUse: "The speaker is preparing a reply too early, interrupting, or answering before checking the other person's meaning.",
            whenNotToUse: "The other person has already made a clear request and needs a direct answer, not another reflection.",
            modelLine: "What I hear is that the deadline matters less than knowing the risk early. Have I got that right?",
            drill: "After one short answer from a partner, paraphrase the meaning in one sentence and ask one check question before adding your view.",
            passCondition: "the partner confirms or corrects the meaning before the speaker responds.",
            transferPrompt: "Use one paraphrase-and-check loop in the next real conversation and notice what the other person clarifies.",
            signatureTerms: ["paraphrase the meaning", "check question", "have i got that right", "listening loop", "partner confirms", "other person clarifies"]
        ),
        CoachInterventionSpec(
            id: "vocal-contrast",
            dimensionID: "controlled_pacing",
            title: "Create vocal contrast",
            whenToUse: "The wording is clear but important words disappear into an even, flat, or rushed delivery.",
            whenNotToUse: "The message itself is still unclear or extra vocal energy would feel performative in a sensitive moment.",
            modelLine: "The launch is not late. The risk is untested. [stress: untested]",
            drill: "Mark one meaning word in each sentence; give that word a little more stress and let the surrounding words stay conversational.",
            passCondition: "a listener identifies the intended meaning words without the delivery sounding theatrical.",
            transferPrompt: "Use one marked meaning word in the next real update and ask which phrase sounded most important.",
            signatureTerms: ["meaning word", "vocal contrast", "more stress", "sounding theatrical", "phrase sounded most important", "flat delivery"]
        ),
        CoachInterventionSpec(
            id: "audience-lens",
            dimensionID: nil,
            title: "Choose the audience lens",
            whenToUse: "The message is accurate but pitched at the wrong level of detail, consequence, or assumed knowledge for this listener.",
            whenNotToUse: "The audience is not yet known or the core point changes across versions.",
            modelLine: "For the executive room: revenue is protected, but the launch moves one week. For the technical room: the payment dependency needs one more validation cycle.",
            drill: "Name one audience and rewrite the same point around the decision, consequence, and detail that audience needs.",
            passCondition: "the core point stays stable while the consequence and level of detail fit the listener.",
            transferPrompt: "Before the next real message, write one sentence for that audience and remove any detail that does not change their decision.",
            signatureTerms: ["audience lens", "level of detail", "fit the listener", "executive room", "technical room", "that audience", "change their decision"]
        ),
        CoachInterventionSpec(
            id: "presence-before-practice",
            dimensionID: nil,
            title: "Presence before practice",
            whenToUse: "The user is exhausted, overwhelmed, defeated, or explicitly asks to stop.",
            whenNotToUse: "The user has energy and is explicitly asking for a concrete coaching attempt.",
            modelLine: "That sounds exhausting. You do not need to force another rep right now.",
            drill: "No drill. Reduce pressure and leave the door open.",
            passCondition: "the user feels no obligation to perform or answer another question.",
            transferPrompt: "Return to one small answer only when the user says they have room for it.",
            signatureTerms: ["no drill", "do not force another", "sounds exhausting", "when you have room"]
        )
    ]

    /// Build the private plan that precedes any provider prose. This method is
    /// intentionally pure so evals can inspect the decision without calling a
    /// model or exposing it to the user.
    static func decisionPlan(for assessment: CoachAssessment) -> CoachDecisionPlan {
        let requestedMetrics = assessment.requestedMetrics ?? []
        let posture = CoachReplyPosture.resolve(
            userText: assessment.questionRestatement,
            requestedMetrics: requestedMetrics
        )
        let intervention = interventionForAssessment(assessment, posture: posture)
        let stage = decisionStage(for: assessment, posture: posture)
        let exactEvidence = assessment.evidenceUsed.first(where: {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) ?? "No quantity-qualified personal evidence is available."

        let chosenIntervention: String
        let successTest: String
        if posture == .requestedMetrics {
            chosenIntervention = "No intervention. Answer only the metric kinds the user explicitly requested."
            successTest = "Every number in the answer belongs to the explicit metric request."
        } else if let intervention {
            chosenIntervention = [
                intervention.title,
                "Use when: \(intervention.whenToUse)",
                "Do not use when: \(intervention.whenNotToUse)"
            ].joined(separator: " | ")
            successTest = intervention.passCondition
        } else {
            chosenIntervention = "Evidence boundary before intervention."
            successTest = assessment.missingEvidence.first
                ?? "The response makes no claim beyond the available evidence."
        }

        return CoachDecisionPlan(
            situation: assessment.questionRestatement,
            stakes: stakesRead(in: assessment.questionRestatement),
            emotion: emotionRead(
                in: assessment.questionRestatement,
                repairFocus: assessment.repairFocus
            ),
            observedBehavior: assessment.directVerdict,
            exactEvidence: exactEvidence,
            skillStage: stage,
            chosenIntervention: chosenIntervention,
            successTest: successTest,
            modelLine: posture == .coachedAttempt
                ? intervention.map {
                    adaptedModelLine(
                        for: $0,
                        situation: assessment.questionRestatement
                    )
                }
                : nil,
            invitation: posture == .coachedAttempt
                ? "Invite one attempt now; do not assign a menu or a second drill."
                : nil,
            replyPosture: posture,
            benchmarkAuthorization: nil
        )
    }

    /// General craft questions have no personal assessment by design, but they
    /// still need a decision before prose. This plan states the evidence
    /// boundary explicitly and selects a demonstrable technique without
    /// pretending the app observed the user's delivery.
    static func generalDecisionPlan(
        userQuestion: String,
        recentMoves: [String] = []
    ) -> CoachDecisionPlan {
        let posture = CoachReplyPosture.resolve(userText: userQuestion)
        let benchmarkAuthorization = CoachBenchmarkAuthorization.explicitRequest(
            in: userQuestion
        )
        let candidates: [CoachInterventionSpec]
        if posture == .presenceOnly,
           let presence = interventionCatalogue.first(where: {
            $0.id == "presence-before-practice"
           }) {
            candidates = [presence]
        } else if posture == .coachedAttempt {
            candidates = orderedInterventions(
                for: userQuestion,
                preferredDimensionID: nil
            )
        } else {
            candidates = []
        }
        let recentKeys = Set(
            recentMoves.prefix(3).compactMap(interventionMoveKey)
        )
        let stages: [CoachSkillStage] = posture == .presenceOnly
            ? [.recover]
            : [.establish, .stretch, .transfer]
        var choice: CoachInterventionChoice?
        for intervention in candidates where choice == nil {
            for stage in stages where choice == nil {
                let candidate = CoachInterventionChoice(
                    intervention: intervention,
                    stage: stage,
                    move: intervention.move(for: stage)
                )
                if !recentKeys.contains(candidate.noveltyKey) {
                    choice = candidate
                }
            }
        }
        let selected = choice ?? candidates.first.map {
            CoachInterventionChoice(
                intervention: $0,
                stage: posture == .presenceOnly ? .recover : .transfer,
                move: $0.move(
                    for: posture == .presenceOnly ? .recover : .transfer
                )
            )
        }

        let chosenIntervention: String
        let successTest: String
        if let benchmarkAuthorization {
            chosenIntervention = "Answer-only bounded benchmark: \(benchmarkAuthorization.promptName). No personal diagnosis or exercise."
            successTest = "The answer gives the authorized range, names context that can move it, and avoids false precision."
        } else if posture == .informationOnly {
            chosenIntervention = "Answer-only craft explanation. Do not turn a legitimate knowledge question into a coached attempt."
            successTest = "The reply answers the craft question directly without a diagnosis, drill, or compulsory follow-up."
        } else if let selected {
            chosenIntervention = "\(selected.intervention.title) | Use when: \(selected.intervention.whenToUse) | Do not use when: \(selected.intervention.whenNotToUse)"
            successTest = selected.intervention.passCondition
        } else {
            chosenIntervention = "No catalogue move is earned by the wording. Answer the action request without defaulting to answer-first."
            successTest = "The reply addresses the exact request without inventing personal evidence or an unrelated technique."
        }

        return CoachDecisionPlan(
            situation: userQuestion.trimmingCharacters(in: .whitespacesAndNewlines),
            stakes: stakesRead(in: userQuestion),
            emotion: emotionRead(in: userQuestion, repairFocus: nil),
            observedBehavior: "No personal delivery claim is earned; answer the craft question itself.",
            exactEvidence: "No personal rep evidence is authorized on this general-coaching turn.",
            skillStage: selected?.stage ?? .establish,
            chosenIntervention: chosenIntervention,
            successTest: successTest,
            modelLine: posture == .coachedAttempt
                ? selected.map {
                    adaptedModelLine(
                        for: $0.intervention,
                        situation: userQuestion
                    )
                }
                : nil,
            invitation: posture == .coachedAttempt && selected != nil
                ? "Invite one attempt using the demonstrated shape."
                : nil,
            replyPosture: posture,
            benchmarkAuthorization: benchmarkAuthorization
        )
    }

    static func interventionForAssessment(
        _ assessment: CoachAssessment,
        posture: CoachReplyPosture? = nil
    ) -> CoachInterventionSpec? {
        let posture = posture ?? CoachReplyPosture.resolve(
            userText: assessment.questionRestatement,
            requestedMetrics: assessment.requestedMetrics ?? []
        )
        if posture == .requestedMetrics || posture == .informationOnly {
            return nil
        }
        if posture == .presenceOnly {
            return interventionCatalogue.first { $0.id == "presence-before-practice" }
        }

        let lower = [
            assessment.questionRestatement,
            assessment.directVerdict,
            assessment.nextProofTest
        ].joined(separator: " ").lowercased()
        if containsAny(lower, ["disagree", "disagreement", "reassur", "defensive"]) {
            return interventionCatalogue.first { $0.id == "warm-disagreement" }
        }
        for id in domainInterventionIDs(for: lower) {
            if let match = interventionCatalogue.first(where: { $0.id == id }) {
                return match
            }
        }
        if let dimensionID = assessment.nextProofDimensionID,
           let match = interventionCatalogue.first(where: { $0.dimensionID == dimensionID }) {
            return match
        }
        return interventionCatalogue.max { lhs, rhs in
            interventionMatchScore(lhs, in: lower) <
                interventionMatchScore(rhs, in: lower)
        }.flatMap { interventionMatchScore($0, in: lower) > 0 ? $0 : nil }
    }

    static func adaptedModelLine(
        for intervention: CoachInterventionSpec,
        situation: String
    ) -> String {
        let lower = situation.lowercased()
        if intervention.id == "answer-first",
           containsAny(lower, ["delay", "launch"]) {
            return intervention.modelLine
        }
        switch intervention.id {
        case "answer-first":
            return "I recommend option A. The reason is the delivery risk."
        case "one-proof-point":
            return "The risk is real: one customer failed at the final step."
        case "clean-close":
            return "I need your decision by Thursday."
        case "functional-pause":
            return "The answer is no. [one beat] The cost is too high."
        case "plain-commitment":
            return "I recommend option B. The evidence is incomplete, but it is the better risk."
        case "pressure-anchor":
            return "The point I do not want to lose is this: we need a decision today."
        case "warm-disagreement":
            return "I disagree with that direction. My concern is the customer impact."
        case "story-beat":
            return "We expected the handoff to work. Then one customer stalled at the same step twice. That is why we changed it."
        case "listening-loop":
            return "What I hear is that early warning matters more than a perfect forecast. Have I got that right?"
        case "vocal-contrast":
            return "The launch is not late. The risk is untested. [stress: untested]"
        case "audience-lens":
            return "For this room, the decision is simple: protect revenue now, then validate the dependency."
        case "presence-before-practice":
            return intervention.modelLine
        default:
            return intervention.modelLine
        }
    }

    /// Selects one intervention and one stage while avoiding any move used in
    /// the last three typed proof tests. Repeating a skill target is allowed only
    /// by advancing its stage (establish -> stretch -> transfer), never by
    /// silently handing back the same exercise with synonyms.
    static func selectIntervention(
        userQuestion: String,
        preferredDimensionID: String?,
        trajectory: UserTrajectorySnapshot,
        turnDepth: CoachTurnDepth,
        replyPosture: CoachReplyPosture,
        recentMoves: [String]
    ) -> CoachInterventionChoice? {
        if replyPosture == .requestedMetrics || replyPosture == .informationOnly {
            return nil
        }
        if replyPosture == .presenceOnly {
            guard let presence = interventionCatalogue.first(where: {
                $0.id == "presence-before-practice"
            }) else { return nil }
            return CoachInterventionChoice(
                intervention: presence,
                stage: .recover,
                move: presence.move(for: .recover)
            )
        }

        let candidates = orderedInterventions(
            for: userQuestion,
            preferredDimensionID: preferredDimensionID
        )
        guard !candidates.isEmpty else { return nil }
        let preferredStage = skillStage(
            trajectory: trajectory,
            turnDepth: turnDepth
        )
        let recentKeys = Set(
            recentMoves.prefix(3).compactMap(interventionMoveKey)
        )
        let stageOrder = progressiveStageOrder(startingAt: preferredStage)

        for candidate in candidates {
            for stage in stageOrder {
                let choice = CoachInterventionChoice(
                    intervention: candidate,
                    stage: stage,
                    move: candidate.move(for: stage)
                )
                if !recentKeys.contains(choice.noveltyKey) {
                    return choice
                }
            }
        }

        // Three recent stages can exhaust one target. Preserve plan continuity
        // and move into real-world transfer rather than switching skills merely
        // to sound novel.
        let candidate = candidates[0]
        return CoachInterventionChoice(
            intervention: candidate,
            stage: .transfer,
            move: candidate.transferPrompt
        )
    }

    static func interventionMoveKey(_ text: String) -> String? {
        let lower = text.lowercased()
        guard let intervention = interventionCatalogue.max(by: { lhs, rhs in
            interventionMatchScore(lhs, in: lower) <
                interventionMatchScore(rhs, in: lower)
        }), interventionMatchScore(intervention, in: lower) > 0 else {
            return nil
        }

        let stage: CoachSkillStage
        if intervention.id == "presence-before-practice" {
            stage = .recover
        } else if containsAny(lower, [
            "next real", "real update", "real ask", "real conversation",
            "real meeting", "stakes moment", "low-risk disagreement"
        ]) {
            stage = .transfer
        } else if containsAny(lower, [
            "passes when", "it passes", "one extra demand", "check whether",
            "notice whether", "compare whether"
        ]) {
            stage = .stretch
        } else {
            stage = .establish
        }
        return "\(intervention.id):\(stage.rawValue)"
    }

    private static func orderedInterventions(
        for userQuestion: String,
        preferredDimensionID: String?
    ) -> [CoachInterventionSpec] {
        let lower = userQuestion.lowercased()
        var preferredIDs = domainInterventionIDs(for: lower)
        if containsAny(lower, ["depth", "example"]) &&
            containsAny(lower, ["ramble", "overexplain", "too much context"]) {
            preferredIDs.append("one-proof-point")
        }
        if containsAny(lower, ["disagree", "disagreement", "defensive", "conflict"]) {
            preferredIDs.append("warm-disagreement")
        }
        if containsAny(lower, ["ramble", "overexplain", "too much context"]) {
            preferredIDs.append(contentsOf: ["clean-close", "answer-first"])
        }
        if containsAny(lower, ["pace", "too fast", "filler", " um", " uh", "pause"]) {
            preferredIDs.append("functional-pause")
        }
        if containsAny(lower, ["example", "depth", "memorable", "proof point"]) {
            preferredIDs.append("one-proof-point")
        }
        if containsAny(lower, ["close", "ending", "ask", "trail off"]) {
            preferredIDs.append("clean-close")
        }
        if containsAny(lower, ["pressure", "timer", "freeze", "blank", "interruption"]) {
            preferredIDs.append("pressure-anchor")
        }
        if containsAny(lower, ["hedge", "maybe", "probably", "conviction", "timid"]) {
            preferredIDs.append("plain-commitment")
        }
        if containsAny(lower, ["opening", "opener", "answer first", "recommendation"]) {
            preferredIDs.append("answer-first")
        }

        var candidates: [CoachInterventionSpec] = []
        func append(_ intervention: CoachInterventionSpec) {
            if !candidates.contains(where: { $0.id == intervention.id }) {
                candidates.append(intervention)
            }
        }
        for id in preferredIDs {
            if let match = interventionCatalogue.first(where: { $0.id == id }) {
                append(match)
            }
        }
        if let preferredDimensionID {
            interventionCatalogue
                .filter { $0.dimensionID == preferredDimensionID }
                .forEach(append)
        }
        return candidates
    }

    private static func domainInterventionIDs(for lower: String) -> [String] {
        var ids: [String] = []
        if containsAny(lower, ["story", "storytelling", "anecdote", "narrative", "turning point"]) {
            ids.append("story-beat")
        }
        if containsAny(lower, ["listen", "listening", "paraphrase", "interrupt", "heard", "other person"]) {
            ids.append("listening-loop")
        }
        if containsAny(lower, ["monotone", "flat", "prosody", "vocal", "emphasis", "energy", "intonation", "delivery sounds"]) {
            ids.append("vocal-contrast")
        }
        if containsAny(lower, ["audience", "stakeholder", "executive", "technical room", "tailor", "level of detail", "assumed knowledge"]) {
            ids.append("audience-lens")
        }
        return ids
    }

    private static func interventionMatchScore(
        _ intervention: CoachInterventionSpec,
        in lower: String
    ) -> Int {
        intervention.signatureTerms.reduce(0) {
            $0 + (lower.contains($1) ? 1 : 0)
        }
    }

    private static func skillStage(
        trajectory: UserTrajectorySnapshot,
        turnDepth: CoachTurnDepth
    ) -> CoachSkillStage {
        if turnDepth == .trustRepair {
            return .recover
        }
        if let intervention = trajectory.activeInterventionState {
            if intervention.followedRepCount >= 2 { return .transfer }
            if intervention.followedRepCount == 1 { return .stretch }
        }
        return trajectory.evidenceCoverage < 0.45 ? .establish : .stretch
    }

    private static func progressiveStageOrder(
        startingAt stage: CoachSkillStage
    ) -> [CoachSkillStage] {
        switch stage {
        case .establish: return [.establish, .stretch, .transfer]
        case .stretch: return [.stretch, .transfer, .establish]
        case .transfer: return [.transfer, .stretch, .establish]
        case .recover: return [.recover]
        }
    }

    private static func decisionStage(
        for assessment: CoachAssessment,
        posture: CoachReplyPosture
    ) -> CoachSkillStage {
        if posture == .presenceOnly || assessment.turnDepth == .trustRepair {
            return .recover
        }
        if let moveKey = interventionMoveKey(assessment.nextProofTest) {
            if moveKey.hasSuffix(":\(CoachSkillStage.transfer.rawValue)") {
                return .transfer
            }
            if moveKey.hasSuffix(":\(CoachSkillStage.stretch.rawValue)") {
                return .stretch
            }
            if moveKey.hasSuffix(":\(CoachSkillStage.establish.rawValue)") {
                return .establish
            }
        }
        let lower = assessment.nextProofTest.lowercased()
        if containsAny(lower, ["next real", "real meeting", "real update", "stakes moment"]) {
            return .transfer
        }
        if assessment.confidence < 0.45 {
            return .establish
        }
        return .stretch
    }

    private static func stakesRead(in userQuestion: String) -> String {
        let lower = userQuestion.lowercased()
        if containsAny(lower, ["tomorrow", "interview", "board", "leadership", "client", "presentation", "pitch"]) {
            return "A near-term real-world communication moment is at stake."
        }
        if containsAny(lower, ["disagree", "conflict", "raise", "feedback"]) {
            return "The social risk of a real conversation matters."
        }
        return "Routine practice; do not manufacture urgency."
    }

    private static func emotionRead(
        in userQuestion: String,
        repairFocus: String?
    ) -> String {
        let lower = ([userQuestion, repairFocus ?? ""])
            .joined(separator: " ")
            .lowercased()
        if containsAny(lower, ["exhausted", "overwhelmed", "defeated", "too tired", "need to stop"]) {
            return "Low capacity. Presence may be the complete response."
        }
        if containsAny(lower, ["not easy", "harder", "freeze", "panic", "scared", "nervous"]) {
            return "Friction or pressure is explicit; reduce the size of the ask."
        }
        if containsAny(lower, ["not helpful", "generic", "robotic", "missed", "wrong", "repeating"]) {
            return "Trust is damaged; own the miss before coaching."
        }
        return "No strong emotion is explicit; acknowledge context without inventing one."
    }

    static func assess(
        turnDepth: CoachTurnDepth,
        userQuestion: String,
        trajectory: UserTrajectorySnapshot,
        rubric: ActiveGoalRubric,
        surface: CoachReplySurface,
        recentProofTests: [String] = [],
        previousCoachReply: String? = nil
    ) -> CoachAssessment {
        let isMemoryHandoff = TurnDepthClassifier.isMemoryHandoff(userQuestion.lowercased())
        let requestedMetrics = TurnDepthClassifier.requestedPersonalMetrics(userQuestion)
        let evidenceReadKind: CoachEvidenceReadKind? = if !requestedMetrics.isEmpty {
            .latestRepMetrics
        } else if TurnDepthClassifier.isLongitudinalPerformanceRead(userQuestion) {
            .longitudinalTrend
        } else {
            nil
        }
        let repairFocus = repairFocus(
            for: userQuestion,
            previousCoachReply: previousCoachReply,
            turnDepth: turnDepth
        )
        let scores = rubric.rubric.dimensions.map { dimension in
            score(dimension: dimension, trajectory: trajectory)
        }
        let weightedMechanics = weightedScore(scores: scores, rubric: rubric.rubric)
        let goalReadiness = goalReadinessScore(scores: scores, coverage: trajectory.evidenceCoverage)
        let preferredDimensionID = preferredProofDimensionID(
            for: userQuestion,
            scores: scores,
            turnDepth: turnDepth,
            isMemoryHandoff: isMemoryHandoff
        )
        let replyPosture = CoachReplyPosture.resolve(
            userText: userQuestion,
            requestedMetrics: requestedMetrics
        )
        let interventionChoice = selectIntervention(
            userQuestion: userQuestion,
            preferredDimensionID: preferredDimensionID,
            trajectory: trajectory,
            turnDepth: turnDepth,
            replyPosture: replyPosture,
            recentMoves: Array(recentProofTests.prefix(3))
        )
        let explicitPreferredProofTest = preferredProofTest(
            for: userQuestion,
            turnDepth: turnDepth
        )
        let focusLabel = preferredDimensionID.flatMap { id in
            rubric.rubric.dimensions.first { $0.id == id }?.label
        }
        let directVerdict = isMemoryHandoff
            ? memoryHandoffVerdict(previousCoachReply: previousCoachReply)
            : verdict(
                depth: turnDepth,
                mechanics: weightedMechanics,
                goalReadiness: goalReadiness,
                coverage: trajectory.evidenceCoverage,
                rubricName: rubric.rubric.displayName,
                focusDimensionID: preferredDimensionID,
                focusLabel: focusLabel,
                repairFocus: repairFocus,
                trajectory: trajectory
            )
        let evidence = evidenceLines(
            from: trajectory,
            limit: evidenceLimit(for: turnDepth),
            repairFocus: repairFocus,
            turnDepth: turnDepth,
            isMemoryHandoff: isMemoryHandoff,
            previousCoachReply: previousCoachReply
        )
        let missing = missingEvidence(from: scores, trajectory: trajectory, depth: turnDepth)
        let proofSelection = isMemoryHandoff
            ? ProofTestSelection(
                text: memoryHandoffProofTest(previousCoachReply: previousCoachReply),
                dimensionID: nil
            )
            : nextProofSelection(
                userQuestion: userQuestion,
                turnDepth: turnDepth,
                trajectory: trajectory,
                from: scores,
                rubric: rubric.rubric,
                surface: surface,
                preferredDimensionID: preferredDimensionID,
                preferredProofTest: explicitPreferredProofTest,
                interventionChoice: interventionChoice,
                repairFocus: repairFocus,
                recentProofTests: recentProofTests
            )

        return CoachAssessment(
            turnDepth: turnDepth,
            surface: surface,
            questionRestatement: restatement(for: userQuestion, depth: turnDepth),
            directVerdict: directVerdict,
            confidence: confidence(
                coverage: trajectory.evidenceCoverage,
                mechanics: weightedMechanics,
                scores: scores,
                depth: turnDepth
            ),
            evidenceUsed: evidence,
            rubricScores: scores,
            evidenceReadKind: evidenceReadKind,
            requestedMetrics: requestedMetrics.isEmpty ? nil : requestedMetrics,
            latestRepMetrics: evidenceReadKind == .latestRepMetrics
                ? trajectory.latestRepEvidencePack?.metricProjection
                : nil,
            longitudinalTrend: evidenceReadKind == .longitudinalTrend
                ? trajectory.qualifiedLongitudinalTrend
                : nil,
            nextProofDimensionID: proofSelection.dimensionID,
            missingEvidence: missing,
            nextProofTest: proofSelection.text,
            responseMode: responseMode(depth: turnDepth, surface: surface),
            toneMode: toneMode(depth: turnDepth, repairFocus: repairFocus),
            repairFocus: repairFocus
        )
    }

    private static func score(
        dimension: RubricDimension,
        trajectory: UserTrajectorySnapshot
    ) -> RubricScore {
        let pack = trajectory.latestRepEvidencePack
        let transcript = pack?.meetsQuantityFloor == true
            ? (pack?.transcriptExcerpt ?? "").lowercased()
            : ""
        let wpm = pack?.wordsPerMinute
        let score = pack?.score
        let sessionCount = trajectory.sessionCount
        let fillerBurden = pack?.qualifyingFillerBurden
        let fillerRate = fillerBurden?.ratePerMinute

        let raw: Double
        let evidence: [String]
        switch dimension.id {
        case "verdict_first":
            let hasVerdict = containsAny(transcript, [
                "recommend", "recommendation", "decision", "the answer",
                "my answer", "the point", "i would", "we should"
            ])
            raw = hasVerdict ? 0.72 : 0.35
            evidence = hasVerdict
                ? ["latest transcript appears to lead with a decision word"]
                : ["no clear verdict-first proof in a quantity-qualified transcript"]
        case "hedge_control":
            // Word matching cannot tell a timid hedge from legitimate
            // uncertainty, and substring checks misread words such as
            // "adjust" as "just". Stay neutral until semantic intent is typed.
            raw = 0.60
            evidence = [
                "semantic intent is not classified, so hedge control is not judged from wording alone"
            ]
        case "clean_close":
            guard !transcript.isEmpty else {
                raw = 0.48
                evidence = ["no duration-qualified transcript is available to judge the close"]
                break
            }
            // Match the final spoken token, not an arbitrary string suffix.
            // The suffix form misclassified words such as "also", "premium",
            // and "momentum", while punctuation let a genuine "um." escape.
            // "I believe so" and "yeah" can be semantically complete; without
            // intent or prosody evidence, only unambiguous filler tokens count.
            let trailing = finalSpokenWord(in: transcript).map {
                ["um", "uh"].contains($0)
            } ?? false
            raw = trailing
                ? 0.35
                : (score.map { min(0.82, Double($0) / 10.0) } ?? 0.48)
            evidence = trailing
                ? ["latest transcript suggests a soft trailing close"]
                : ["latest transcript ends on a complete claim"]
        case "pressure_stability":
            let hasPressureEvidence = trajectory.recentSessionLines.contains {
                let lower = $0.lowercased()
                return lower.contains("sudden") || lower.contains("pressure") || lower.contains("ah-counter")
            }
            raw = hasPressureEvidence ? min(0.78, 0.45 + Double(sessionCount) / 20.0) : min(0.55, Double(sessionCount) / 18.0)
            evidence = hasPressureEvidence ? ["recent history includes a pressure-style rep"] : ["no explicit pressure-mode proof in the current evidence pack"]
        case "controlled_pacing":
            if let pack, pack.meetsQuantityFloor, let wpm {
                let paceScore = wpm < 105 ? 0.48 : (wpm > 175 ? 0.50 : 0.76)
                let fillerPenalty: Double
                if let fillerBurden,
                   fillerBurden.meets(.elevated),
                   let fillerRate {
                    fillerPenalty = fillerRate * 0.025
                } else {
                    fillerPenalty = 0
                }
                raw = max(0.25, paceScore - fillerPenalty)
                if let fillerRate {
                    evidence = [
                        "latest pace estimate \(wpm) WPM with \(formattedRate(fillerRate)) fillers/min across \(pack.durationSeconds)s"
                    ]
                } else {
                    evidence = ["latest pace estimate \(wpm) WPM; filler-rate evidence was unavailable"]
                }
            } else {
                raw = 0.42
                evidence = ["no duration-qualified pace estimate in the latest evidence pack"]
            }
        case "salience":
            let hasSalience = containsAny(transcript, ["because", "so ", "therefore", "means", "matters"])
            raw = hasSalience ? 0.64 : 0.38
            evidence = hasSalience
                ? ["latest transcript has a reason or implication marker"]
                : ["no memorable point or implication proof in a quantity-qualified transcript"]
        default:
            raw = 0.45
            evidence = ["no dimension-specific evidence available"]
        }

        let confidence = min(0.90, max(0.20, trajectory.evidenceCoverage))
        return RubricScore(
            dimensionID: dimension.id,
            label: dimension.label,
            score: min(1.0, max(0.0, raw)),
            confidence: confidence,
            evidence: evidence,
            missingEvidence: raw >= 0.70 ? nil : dimension.missingIfAbsent
        )
    }

    private static func finalSpokenWord(in transcript: String) -> String? {
        transcript
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .last
            .map(String.init)
    }

    private static func verdict(
        depth: CoachTurnDepth,
        mechanics: Double,
        goalReadiness: Double,
        coverage: Double,
        rubricName: String,
        focusDimensionID: String?,
        focusLabel: String?,
        repairFocus: String?,
        trajectory: UserTrajectorySnapshot
    ) -> String {
        switch depth {
        case .quickMove:
            return quickMoveVerdict(
                for: focusDimensionID,
                focusLabel: focusLabel,
                trajectory: trajectory
            )
        case .groundedRead:
            if let focusLabel {
                return "The grounded read should stay local to \(focusLabel.lowercased()) in the latest evidence."
            }
            return "The grounded read is local to the latest evidence, not a verdict on the whole goal."
        case .trustRepair:
            if repairFocus != nil {
                return "The repair is to name the miss first, then answer with one useful move."
            }
            return "The prior answer needs repair: it should answer the real question before offering advice."
        case .deepAssessment:
            if coverage < 0.35 {
                return "I do not have enough evidence for an overall \(rubricName.lowercased()) verdict yet."
            }
            if mechanics >= 0.68 && goalReadiness < 0.62 {
                return "You are closer mechanically than you are to fully meeting the \(rubricName.lowercased()) standard."
            }
            if goalReadiness >= 0.72 && coverage >= 0.70 {
                return "You are approaching the \(rubricName.lowercased()) standard, but it still needs pressure proof."
            }
            return "You have useful pieces, but the full \(rubricName.lowercased()) standard is not proven yet."
        }
    }

    private static func quickMoveVerdict(
        for dimensionID: String?,
        focusLabel: String?,
        trajectory: UserTrajectorySnapshot
    ) -> String {
        guard let dimensionID else {
            return trajectorySpecificQuickMoveVerdict(focusLabel: focusLabel, trajectory: trajectory)
        }
        switch dimensionID {
        case "controlled_pacing":
            return "Pacing is the next lever: add one deliberate beat before the reason, then judge the same answer."
        case "clean_close":
            return "The ending is the next lever: make the final sentence the ask or decision, then stop."
        case "verdict_first":
            return "The opening is the next lever: put the verdict in sentence one, then prove it once."
        case "hedge_control":
            return "Directness is the next lever: replace one hedge with a plain recommendation."
        case "pressure_stability":
            return "Pressure is the next lever: repeat the same answer under a timer and protect the sentence where it leaks."
        case "salience":
            return "Salience is the next lever: add one concrete detail, then return to the ask."
        default:
            return trajectorySpecificQuickMoveVerdict(focusLabel: focusLabel, trajectory: trajectory)
        }
    }

    private static func trajectorySpecificQuickMoveVerdict(
        focusLabel: String?,
        trajectory: UserTrajectorySnapshot
    ) -> String {
        if let intervention = trajectory.activeInterventionState,
           let target = nonEmpty(intervention.target) ?? nonEmpty(intervention.title) {
            let targetPhrase = statementFragment(target)
            if intervention.followedRepCount > 0 {
                return "Stay with the active intervention: \(targetPhrase), then judge that same target again."
            }
            return "Start with the active intervention: \(targetPhrase), then judge that one target."
        }

        if let summary = trajectory.coachCaseSummary,
           let nextMove = nonEmpty(summary.nextCoachMove) {
            return "Use the case file's next move: \(statementFragment(nextMove))."
        }

        if let summary = trajectory.coachCaseSummary,
           let focus = nonEmpty(summary.focus) {
            return "The next useful move should stay on \(focus.lowercased()): change one observable sentence, then compare it."
        }

        if let pack = trajectory.latestRepEvidencePack {
            let mode = shortModeName(pack.mode)
            if pack.qualifyingFillerBurden?.meets(.elevated) == true,
               let summary = pack.qualifyingFillerEvidence.summary {
                return "Use the latest \(mode) rep at \(summary): replace one filler urge with a silent beat, then compare fillers per minute under the same demand."
            }
            if let excerpt = pack.transcriptExcerpt?.lowercased(),
               containsAny(excerpt, ["recommend", "recommendation", "decision", "my answer", "i would"]) {
                return "Use the latest \(mode) rep: keep the verdict first and change only the close."
            }
            return "Use the latest \(mode) rep as the sample: change one sentence, then compare it with the original."
        }

        if let focusLabel {
            return "The next useful move is \(focusLabel.lowercased()): test one observable change, not a new plan."
        }
        return "The next useful move is narrow: test one observable change, not a new plan."
    }

    private static func evidenceLines(
        from trajectory: UserTrajectorySnapshot,
        limit: Int,
        repairFocus: String?,
        turnDepth: CoachTurnDepth,
        isMemoryHandoff: Bool,
        previousCoachReply: String?
    ) -> [String] {
        var lines: [String] = []
        if turnDepth == .trustRepair,
           let repairFocus {
            lines.append("trust repair signal: \(repairFocus)")
        }
        if isMemoryHandoff,
           let line = memoryHandoffEvidenceLine(previousCoachReply: previousCoachReply) {
            lines.append(line)
        }
        if let pack = trajectory.latestRepEvidencePack {
            lines.append(contentsOf: pack.evidenceLines)
        }
        if let summary = trajectory.coachCaseSummary {
            if let line = caseSummaryLine(from: summary) {
                lines.append(line)
            }
        }
        if let intervention = trajectory.activeInterventionState,
           let line = activeInterventionLine(from: intervention) {
            lines.append(line)
        }
        lines.append(contentsOf: trajectory.trendLines)
        return Array(unique(lines).prefix(limit))
    }

    private static func evidenceLimit(for depth: CoachTurnDepth) -> Int {
        switch depth {
        case .quickMove:
            return 2
        case .groundedRead:
            return 4
        case .deepAssessment, .trustRepair:
            return 8
        }
    }

    private static func caseSummaryLine(from summary: CoachCaseSummary) -> String? {
        var parts: [String] = []
        appendCasePart(&parts, label: "hypothesis", value: summary.hypothesis)
        appendCasePart(&parts, label: "focus", value: summary.focus)
        appendCasePart(&parts, label: "evidence", value: summary.evidenceSummary)
        appendCasePart(&parts, label: "next move", value: summary.nextCoachMove)
        guard !parts.isEmpty else { return nil }
        return "case summary: \(parts.joined(separator: "; "))"
    }

    private static func activeInterventionLine(from intervention: ActiveInterventionState) -> String? {
        var parts: [String] = []
        let title = intervention.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            parts.append(title)
        }
        appendCasePart(&parts, label: "target", value: intervention.target)
        parts.append("followed reps: \(intervention.followedRepCount)")
        appendCasePart(&parts, label: "review", value: intervention.reviewStatus)
        guard !parts.isEmpty else { return nil }
        return "active intervention: \(parts.joined(separator: "; "))"
    }

    private static func appendCasePart(
        _ parts: inout [String],
        label: String,
        value: String?
    ) {
        guard let value else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        parts.append("\(label): \(trimmed)")
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func nonEmpty(_ value: String) -> String? {
        nonEmpty(Optional(value))
    }

    private static func statementFragment(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
    }

    private static func memoryHandoffVerdict(previousCoachReply: String?) -> String {
        guard let source = memoryHandoffSource(previousCoachReply) else {
            return "I don't have a clear pattern to carry forward yet."
        }
        switch source {
        case .disagreementAfterSetup:
            return "What I’d carry forward for now is that disagreement may be getting softened by setup."
        }
    }

    private static func memoryHandoffEvidenceLine(previousCoachReply: String?) -> String? {
        guard let source = memoryHandoffSource(previousCoachReply) else { return nil }
        switch source {
        case .disagreementAfterSetup:
            return "conversation hypothesis: disagreement may be getting softened by setup"
        }
    }

    private static func memoryHandoffProofTest(previousCoachReply: String?) -> String {
        guard let source = memoryHandoffSource(previousCoachReply) else { return "" }
        switch source {
        case .disagreementAfterSetup:
            return "Use two pressure reps to see whether the point still arrives late; drop this read if verdict-first solves it."
        }
    }

    /// A memory handoff can only be built from an explicitly recognized,
    /// revisable observation. Free-form coach prose is never promoted by taking
    /// its first sentence; if no typed source can be recovered, the memory lane
    /// stays empty and the server returns the deterministic no-memory response.
    private enum MemoryHandoffSource {
        case disagreementAfterSetup
    }

    private static func memoryHandoffSource(
        _ previousCoachReply: String?
    ) -> MemoryHandoffSource? {
        guard previousCoachReplyIsConsentBoundRead(previousCoachReply),
              previousCoachReplyContainsDisagreementSetup(previousCoachReply) else {
            return nil
        }
        return .disagreementAfterSetup
    }

    private static func previousCoachReplyIsConsentBoundRead(
        _ previousCoachReply: String?
    ) -> Bool {
        guard let previousCoachReply else { return false }
        let lower = previousCoachReply.lowercased()
        let isConditional = [
            "possible pattern", "carry forward for now", "hypothesis",
            "not a label", "not a fixed label"
        ].contains(where: lower.contains)
        let isRevisable = [
            "drop this read", "drop it if", "reject", "change this read",
            "keep it if"
        ].contains(where: lower.contains)
        return isConditional && isRevisable
    }

    private static func previousCoachReplyContainsDisagreementSetup(_ previousCoachReply: String?) -> Bool {
        guard let previousCoachReply else { return false }
        let lower = previousCoachReply.lowercased()
        return lower.contains("disagreement") &&
            (lower.contains("setup") || lower.contains("arrived after"))
    }

    private static func missingEvidence(
        from scores: [RubricScore],
        trajectory: UserTrajectorySnapshot,
        depth: CoachTurnDepth
    ) -> [String] {
        guard depth == .deepAssessment || depth == .trustRepair else {
            return []
        }
        let dimensionGaps = scores
            .filter { $0.score < 0.68 }
            .compactMap(\.missingEvidence)

        // The two cardinal honesty disclosures — the coverage floor and the
        // unproven-under-pressure gap — must never be evicted by dimension-
        // specific gaps. On a weak rep that fails three-plus dimensions at once,
        // the old `.append` + `.prefix(3)` quietly dropped the pressure
        // disclosure exactly when stakes-readiness mattered most, letting the
        // read imply more readiness than the evidence supports. Order the
        // disclosures the coach must always surface ahead of the rest, then cap.
        var priority: [String] = []
        if trajectory.evidenceCoverage < 0.70 {
            priority.append("Need repeated evidence across more than one clean rep before calling the user close overall.")
        }
        let pressureGaps = dimensionGaps.filter { $0.lowercased().contains("pressure") }
        let otherGaps = dimensionGaps.filter { !$0.lowercased().contains("pressure") }
        if pressureGaps.isEmpty && !priority.contains(where: { $0.lowercased().contains("pressure") }) {
            priority.append("Need pressure-mode evidence before treating the goal as ready for real stakes.")
        }
        return Array(unique(priority + pressureGaps + otherGaps).prefix(3))
    }

    private struct ProofTestSelection {
        let text: String
        let dimensionID: String?
    }

    private static func nextProofSelection(
        userQuestion: String,
        turnDepth: CoachTurnDepth,
        trajectory: UserTrajectorySnapshot,
        from scores: [RubricScore],
        rubric: GoalRubric,
        surface: CoachReplySurface,
        preferredDimensionID: String?,
        preferredProofTest: String?,
        interventionChoice: CoachInterventionChoice?,
        repairFocus: String?,
        recentProofTests: [String]
    ) -> ProofTestSelection {
        let sortedIDs = scores.sorted {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.dimensionID < $1.dimensionID
        }.map(\.dimensionID)
        let orderedIDs: [String]
        if let preferredDimensionID {
            orderedIDs = [preferredDimensionID] + sortedIDs.filter { $0 != preferredDimensionID }
        } else {
            orderedIDs = sortedIDs
        }
        let recentKeys = Set(recentProofTests.map(proofTestKey).filter { !$0.isEmpty })
        let recentInterventionKeys = Set(
            recentProofTests.prefix(3).compactMap(interventionMoveKey)
        )
        func isFresh(_ candidate: String) -> Bool {
            if recentKeys.contains(proofTestKey(candidate)) {
                return false
            }
            if let interventionKey = interventionMoveKey(candidate),
               recentInterventionKeys.contains(interventionKey) {
                return false
            }
            return true
        }
        if let preferredProofTest,
           !preferredProofTest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           isFresh(preferredProofTest) {
            return ProofTestSelection(
                text: surface == .live ? liveVersion(of: preferredProofTest) : preferredProofTest,
                dimensionID: preferredDimensionID
            )
        }
        for candidate in contextualProofTestCandidates(
            userQuestion: userQuestion,
            turnDepth: turnDepth,
            trajectory: trajectory,
            preferredDimensionID: preferredDimensionID,
            repairFocus: repairFocus
        ) {
            let rendered = surface == .live ? liveVersion(of: candidate) : candidate
            if isFresh(rendered) {
                return ProofTestSelection(
                    text: rendered,
                    dimensionID: preferredDimensionID
                )
            }
        }
        if let interventionChoice {
            let candidate = surface == .live
                ? liveVersion(of: interventionChoice.move)
                : interventionChoice.move
            if isFresh(candidate) {
                return ProofTestSelection(
                    text: candidate,
                    dimensionID: interventionChoice.intervention.dimensionID
                        ?? preferredDimensionID
                )
            }
        }
        for id in orderedIDs {
            guard let dimension = rubric.dimensions.first(where: { $0.id == id }) else { continue }
            for candidate in proofTestCandidates(
                for: dimension,
                surface: surface
            ) where isFresh(candidate) {
                return ProofTestSelection(text: candidate, dimensionID: id)
            }
        }
        let fallbackID = orderedIDs.first ?? rubric.dimensions[0].id
        let fallbackDimension = rubric.dimensions.first { $0.id == fallbackID } ?? rubric.dimensions[0]
        return ProofTestSelection(
            text: proofTestCandidates(
                for: fallbackDimension,
                surface: surface
            ).first ?? fallbackDimension.proofTest,
            dimensionID: fallbackDimension.id
        )
    }

    private static func contextualProofTestCandidates(
        userQuestion: String,
        turnDepth: CoachTurnDepth,
        trajectory: UserTrajectorySnapshot,
        preferredDimensionID: String?,
        repairFocus: String?
    ) -> [String] {
        let lower = userQuestion.lowercased()
        var candidates: [String] = []

        if turnDepth == .trustRepair {
            if containsAny(lower, ["not informative", "not helpful", "missed the point", "doesn't answer", "does not answer"]) {
                candidates.append("Answer the actual question in sentence one, then give one grounded next move.")
            }
            if containsAny(lower, ["too much writing", "too long", "less writing", "shorter", "get to the point"]) {
                candidates.append("Rewrite the answer in two sentences: the read first, the move second.")
            }
            if containsAny(lower, ["repeating yourself", "same thing again", "said that already", "already said that"]) {
                candidates.append("Advance the read: keep the prior target, but change the proof to the next observable sentence.")
            }
            if containsAny(lower, ["it's not easy", "its not easy", "not that easy", "harder than that", "easier said"]) {
                candidates.append("Make the pressure visible: run the same answer once with a timer and name where it breaks.")
            }
            if let repairFocus,
               !repairFocus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                candidates.append("Repair this turn first: name that \(repairFocus), then give one signal and one move.")
            }
        }

        if containsAny(lower, ["give me examples", "example of me", "examples from", "quote what", "quote me"]) {
            candidates.append("Use one verified session example, name the behavior it shows, then run that behavior once cleaner.")
        }
        if containsAny(lower, [
            "how far", "ready", "readiness", "overall", "where do i stand",
            "authoritative", "authority", "am i there"
        ]) {
            candidates.append("Run one stakes-style pressure proof: verdict first, one reason, clean stop, then compare it with a normal rep.")
        }
        if containsAny(lower, ["outcome", "cause", "caused", "landed better", "room seemed", "audience"]) {
            candidates.append("Log the outcome as a field note, then repeat one pressure rep and check the same observable target.")
        }
        if isPressureFillerQuestion(lower) {
            candidates.append(pressureFillerProofTest(from: trajectory))
        }
        if containsAny(lower, ["interview", "answer questions", "tell me about yourself"]) {
            candidates.append("Answer one interview prompt with the recommendation first, one example, then a clean stop.")
        }
        if containsAny(lower, ["leadership", "board", "executive", "update tomorrow", "status update"]) {
            candidates.append("Give the update as decision, one business reason, and the ask in under 45 seconds.")
        }
        if containsAny(lower, ["disagree", "disagreement", "conflict", "difficult conversation", "defensive"]) {
            candidates.append("Say the disagreement in sentence one, add one calm reason, then stop before reassuring.")
        }
        if containsAny(lower, ["networking", "introducing myself", "intro"]) {
            candidates.append("Run a 30-second intro: role, one memorable detail, then one handoff question.")
        }
        if containsAny(lower, ["sales", "pitch", "customer", "client concern"]) {
            candidates.append("Give the customer problem, one proof point, and the ask without adding a second example.")
        }
        if containsAny(lower, ["presentation", "flat", "energy", "emphasis", "nerves", "nervous"]) {
            candidates.append("Open the presentation answer with the point, hold one beat, then give one proof.")
        }
        if containsAny(lower, ["panic", "blank", "freeze", "barge", "interrupt", "under fire"]) {
            candidates.append("Run the same prompt under a timer and protect only sentence one from setup.")
        }
        if containsAny(lower, ["semantic", "like as a comparison", "meant it as a comparison", "prompt echo"]) {
            candidates.append("Replay the sentence and keep the word only if it adds meaning; cut the hedge if it buys time.")
        }
        if containsAny(lower, ["filler", "fillers", " um", " uh", " ah", "say like"]) {
            candidates.append("Run one answer and separate semantic words from filler words before cutting anything.")
        }
        if containsAny(lower, ["conviction", "convincing", "timid", "timidity", "weak"]) {
            candidates.append("Make one plain recommendation with no maybe/probably, then stop before explaining twice.")
        }
        if containsAny(lower, ["ramble", "overexplain", "over-explain", "too much context"]) {
            candidates.append("Run one answer with verdict, one reason, and a hard stop before the second example.")
        }

        if let pack = trajectory.latestRepEvidencePack {
            let mode = shortModeName(pack.mode)
            switch preferredDimensionID {
            case "controlled_pacing":
                if let wpm = pack.wordsPerMinute, wpm > 175 {
                    candidates.append("Repeat the latest \(mode) rep one beat slower: verdict, beat, one reason, stop.")
                } else {
                    candidates.append("Repeat the latest \(mode) rep with one silent beat after sentence one.")
                }
            case "hedge_control":
                if pack.qualifyingFillerBurden?.meets(.elevated) == true {
                    candidates.append("Replay the latest \(mode) rep and replace the first filler or hedge with the direct verb.")
                } else {
                    candidates.append("Replay the latest \(mode) rep and remove one softening word before the recommendation.")
                }
            case "clean_close":
                candidates.append("Replay the latest \(mode) rep and make the final sentence the ask, then stop.")
            case "verdict_first":
                candidates.append("Replay the latest \(mode) rep with the answer in sentence one before any setup.")
            case "pressure_stability":
                candidates.append("Run the latest \(mode) topic under a 60-second pressure timer and keep sentence one intact.")
            case "salience":
                candidates.append("Replay the latest \(mode) rep with one concrete detail after the verdict, then return to the ask.")
            default:
                break
            }
        }

        return unique(candidates)
    }

    private static func shortModeName(_ mode: String) -> String {
        let trimmed = mode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "practice" }
        let lower = trimmed.lowercased()
        if lower.contains("timed") { return "Timed" }
        if lower.contains("pressure") || lower.contains("sudden") { return "pressure" }
        if lower.contains("ah") { return "Filler Control" }
        if lower.contains("im") || lower.contains("interaction") { return "conversation" }
        if lower.contains("free") { return "free practice" }
        return trimmed
    }

    private static func proofTestCandidates(
        for dimension: RubricDimension,
        surface: CoachReplySurface
    ) -> [String] {
        let candidates: [String]
        switch dimension.id {
        case "verdict_first":
            candidates = [
                dimension.proofTest,
                "Run a 45-second answer with the recommendation first, then give exactly one proof point.",
                "Open the next rep with the decision before any context."
            ]
        case "hedge_control":
            candidates = [
                dimension.proofTest,
                "Replay the answer once and replace one hedge with a direct recommendation.",
                "Record one rep and turn the first maybe/probably into a plain verb."
            ]
        case "clean_close":
            candidates = [
                dimension.proofTest,
                "End the next rep on the exact ask, then stop before adding a summary.",
                "Make the final sentence the ask or decision, then leave the silence there."
            ]
        case "pressure_stability":
            candidates = [
                dimension.proofTest,
                "Repeat the prompt with a timer and keep the first sentence as the answer, not setup.",
                "Run the same prompt under pressure and check whether the close stays decisive."
            ]
        case "controlled_pacing":
            candidates = [
                dimension.proofTest,
                "Run the next rep with a one-beat pause before the reason and no restart.",
                "Place one silent beat after the verdict, then finish the reason in one sentence."
            ]
        case "salience":
            candidates = [
                dimension.proofTest,
                "Use one specific detail that makes the point memorable, then return to the ask.",
                "Add one concrete example after the verdict, then stop before a second example."
            ]
        default:
            candidates = [dimension.proofTest]
        }
        return candidates.map { surface == .live ? liveVersion(of: $0) : $0 }
    }

    private static func proofTestKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func liveVersion(of test: String) -> String {
        if test.lowercased().contains("75-second") {
            return "Run one 60-second answer: verdict first, one reason, clean stop."
        }
        if test.lowercased().contains("60-90") {
            return "Repeat it under a 60-second pressure timer and keep the verdict first."
        }
        return test
    }

    private static func weightedScore(scores: [RubricScore], rubric: GoalRubric) -> Double {
        guard !scores.isEmpty else { return 0 }
        let totalWeight = scores.reduce(0.0) { partial, score in
            partial + (rubric.defaultWeights[score.dimensionID] ?? 0.10)
        }
        guard totalWeight > 0 else { return 0 }
        return scores.reduce(0.0) { partial, score in
            partial + score.score * (rubric.defaultWeights[score.dimensionID] ?? 0.10)
        } / totalWeight
    }

    private static func goalReadinessScore(scores: [RubricScore], coverage: Double) -> Double {
        guard !scores.isEmpty else { return 0 }
        let average = scores.map(\.score).reduce(0, +) / Double(scores.count)
        return min(average, coverage)
    }

    private static func confidence(
        coverage: Double,
        mechanics: Double,
        scores: [RubricScore],
        depth: CoachTurnDepth
    ) -> Double {
        // Thin coverage pins confidence to the floor regardless of mechanics:
        // you cannot be confident about an overall read without evidence breadth.
        // (Weak evidence → low confidence — see assessmentConfidenceMovesWithEvidenceCoverage.)
        if coverage < 0.15 {
            return 0.20
        }

        let scoreValues = scores.map(\.score)
        let weakest = scoreValues.min() ?? mechanics
        let strongest = scoreValues.max() ?? mechanics
        let spread = max(0, strongest - weakest)
        let evidenceBreadth = scoreValues.isEmpty
            ? 0
            : Double(scoreValues.filter { $0 >= 0.55 }.count) / Double(scoreValues.count)
        let depthCap: Double
        let depthAdjustment: Double
        switch depth {
        case .quickMove:
            depthCap = 0.74
            depthAdjustment = 0.04
        case .groundedRead:
            depthCap = 0.76
            depthAdjustment = 0.00
        case .trustRepair:
            depthCap = 0.70
            depthAdjustment = 0.07
        case .deepAssessment:
            depthCap = 0.82
            depthAdjustment = 0.03
        }

        let raw = coverage * 0.40 +
            mechanics * 0.30 +
            weakest * 0.15 +
            evidenceBreadth * 0.15 -
            spread * 0.04 +
            depthAdjustment
        let bounded = min(depthCap, max(0.20, raw))
        return (bounded * 100).rounded() / 100
    }

    private static func responseMode(depth: CoachTurnDepth, surface: CoachReplySurface) -> CoachAssessment.ResponseMode {
        if surface == .live { return .immediateOnly }
        switch depth {
        case .deepAssessment, .trustRepair:
            return .expandable
        case .quickMove, .groundedRead:
            return .immediateOnly
        }
    }

    private static func toneMode(
        depth: CoachTurnDepth,
        repairFocus: String?
    ) -> CoachAssessment.ToneMode {
        switch depth {
        case .trustRepair:
            return .repair
        case .deepAssessment:
            return .challenge
        case .groundedRead:
            return .explain
        case .quickMove:
            return repairFocus == nil ? .prescribe : .validate
        }
    }

    private static func repairFocus(
        for userQuestion: String,
        previousCoachReply: String?,
        turnDepth: CoachTurnDepth
    ) -> String? {
        guard turnDepth == .trustRepair else { return nil }
        let lower = userQuestion.lowercased()
        let previous = previousCoachReply?.lowercased() ?? ""
        if containsAny(lower, ["cold", "robotic", "not human", "low eq", "not high eq"]) {
            return "I sounded cold instead of giving a human coach read"
        }
        if containsAny(lower, ["too much writing", "too long", "less writing", "shorter", "get to the point", "straight to the point"]) {
            return "I used too much writing before the useful read"
        }
        if containsAny(lower, ["repeating yourself", "same thing again", "said that already", "already said that"]) {
            return "I repeated the same coaching move instead of advancing the read"
        }
        if containsAny(lower, ["it's not easy", "its not easy", "not that easy", "easier said than done", "harder than that"]) {
            return "I made the move sound easier than it feels under pressure"
        }
        if containsAny(lower, ["not informative", "not helpful", "not useful", "missed the point", "doesn't answer", "does not answer"]) {
            return "I missed the actual question before prescribing"
        }
        if containsAny(lower, [
            "generic", "generic ai", "generic tips",
            "stop saying practice more", "stop telling me to practice",
            "do not just tell me to practice", "don't just tell me to practice"
        ]) ||
            containsAny(previous, ["keep practicing", "practice more", "communicate clearly", "be clear and concise"]) {
            return "I leaned on generic advice instead of evidence"
        }
        if TurnDepthClassifier.isSoftPushback(lower) {
            return "there is friction underneath the polite pushback"
        }
        return "the prior answer did not earn trust before prescribing"
    }

    private static func preferredProofTest(
        for userQuestion: String,
        turnDepth: CoachTurnDepth
    ) -> String? {
        guard turnDepth == .trustRepair else { return nil }
        let lower = userQuestion.lowercased()
        if containsAny(lower, ["markdown", "tts", "formatting", "**"]) {
            return "Repair the same answer in plain speech: no markdown, one specific read, one move."
        }
        if containsAny(lower, [
            "generic", "generic ai", "ai tips", "ai wrapper", "assistant wrapper",
            "stop saying practice more", "stop telling me to practice",
            "do not just tell me to practice", "don't just tell me to practice"
        ]) {
            return "Use one user-specific signal first, then prescribe exactly one coach move."
        }
        if containsAny(lower, ["cold", "robotic", "not human", "low eq", "not high eq"]) {
            return "Rewrite the read with one human acknowledgement and one user-specific signal."
        }
        if containsAny(lower, ["it's not easy", "its not easy", "not that easy", "harder than that", "easier said"]) {
            return "Test a smaller version in the next rep: say only the disagreement and one calm reason, then stop before defending it."
        }
        return nil
    }

    private static func preferredProofDimensionID(
        for userQuestion: String,
        scores: [RubricScore],
        turnDepth: CoachTurnDepth,
        isMemoryHandoff: Bool = false
    ) -> String? {
        if isMemoryHandoff {
            return nil
        }
        let lower = userQuestion.lowercased()
        if turnDepth == .trustRepair {
            if containsAny(lower, ["it's not easy", "its not easy", "not that easy", "harder than that", "easier said"]) {
                return "pressure_stability"
            }
            if containsAny(lower, ["repeating yourself", "same thing again", "said that already", "already said that"]) {
                return "clean_close"
            }
            if containsAny(lower, ["too much writing", "too long", "get to the point", "not informative", "not helpful", "missed the point", "answered what"]) {
                return "verdict_first"
            }
            if containsAny(lower, ["robotic", "cold", "generic", "ai tips", "ai wrapper", "tts", "markdown", "format"]) {
                return "controlled_pacing"
            }
            return "verdict_first"
        }
        if turnDepth == .deepAssessment,
           containsAny(lower, [
            "how far", "ready", "readiness", "overall", "stand overall",
            "authoritative", "authority", "board", "executive"
           ]) {
            return "pressure_stability"
        }
        if isPressureFillerQuestion(lower) {
            return "pressure_stability"
        }
        if containsAny(lower, ["slow", "pace", "rushing", "too fast", "unsure", "pause", "breath"]) {
            return "controlled_pacing"
        }
        if containsAny(lower, [
            "presentation", "flat", "energy", "emphasis", "nerves",
            "nervous", "confidence", "confident", "panic"
        ]) {
            return "controlled_pacing"
        }
        if containsAny(lower, [
            "ending", "close", "closing", "ask", "stop", "land",
            "leadership", "update tomorrow", "board", "executive",
            "overexplain", "over-explain"
        ]) {
            return "clean_close"
        }
        if containsAny(lower, ["quote what", "give me an example", "example of me"]) {
            return "salience"
        }
        if containsAny(lower, [
            "opening", "start", "first sentence", "verdict", "point first",
            "lead with", "headline", "opener", "interview", "conversation tonight", "difficult conversation",
            "disagree", "disagreement", "defensive", "evasive", "direct",
            "actually say", "quote", "said that", "real question"
        ]) {
            return "verdict_first"
        }
        if containsAny(lower, [
            "filler", "fillers", "um", "uh", "ah", "hedge", "maybe",
            "probably", "kind of", "sort of", "conviction", "convincing",
            "semantic", "comparison", "prompt made me repeat", "prompt echo",
            "timid", "timidity"
        ]) {
            return "hedge_control"
        }
        if containsAny(lower, [
            "pressure", "stakes", "timer", "under fire", "interrupt",
            "real room", "room seemed", "did the drill cause", "cause that",
            "caused", "outcome", "landed better", "this week felt harder"
        ]) {
            return "pressure_stability"
        }
        if containsAny(lower, [
            "depth", "example", "memorable", "stick", "story", "salience",
            "boring", "networking", "introducing myself", "intro", "sales",
            "pitch", "customer", "loses people", "not like me", "my phrase",
            "claim", "reason", "weak"
        ]) {
            return "salience"
        }

        // Broad distance-to-goal questions should still be governed by the
        // weakest observed dimension, especially pressure evidence. Tactical
        // turns get no forced fallback here so the sorted weakest score below
        // remains the last-resort source of truth.
        if turnDepth == .deepAssessment {
            return nil
        }
        if turnDepth == .quickMove,
           let tacticalID = weakestTacticalEvidenceDimensionID(from: scores) {
            return tacticalID
        }
        return scores.sorted {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.dimensionID < $1.dimensionID
        }.first?.dimensionID
    }

    private static func isPressureFillerQuestion(_ lower: String) -> Bool {
        let pressureContext = containsAny(lower, [
            "pressure", "stakes", "timer", "timed", "under fire", "real room"
        ])
        let fillerContext = containsAny(lower, [
            "filler", "fillers", " um", " uh", " ah",
            "saying um", "saying uh", "saying ah", "say like"
        ])
        let semanticDisambiguation = containsAny(lower, [
            "semantic", "comparison", "meant it as a comparison",
            "prompt echo", "prompt made me repeat"
        ])
        return pressureContext && fillerContext && !semanticDisambiguation
    }

    private static func pressureFillerProofTest(from trajectory: UserTrajectorySnapshot) -> String {
        guard let pack = trajectory.latestRepEvidencePack else {
            return "No comparable filler sample is available yet. Run one 60-second pressure rep, use one silent beat before the final sentence, then compare fillers per minute on the next equivalent rep."
        }
        guard let summary = pack.qualifyingFillerEvidence.summary else {
            return "The latest pressure sample is too small or uncertain for a fair filler-rate read. Run one 60-second pressure rep, use one silent beat before the final sentence, then compare fillers per minute on the next equivalent rep."
        }
        return "Repeat the latest pressure rep after \(summary): use one silent beat before the final sentence, finish the ask, then compare fillers per minute under the same demand."
    }

    private static func formattedRate(_ rate: Double) -> String {
        String(format: "%.1f", rate)
    }

    private static func weakestTacticalEvidenceDimensionID(from scores: [RubricScore]) -> String? {
        scores
            .filter { $0.dimensionID != "pressure_stability" && $0.score < 0.55 }
            .sorted {
                if $0.score != $1.score { return $0.score < $1.score }
                return $0.dimensionID < $1.dimensionID
            }
            .first?.dimensionID
    }

    private static func restatement(for question: String, depth: CoachTurnDepth) -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        switch depth {
        case .quickMove: return "What should I do next?"
        case .groundedRead: return "What happened in that rep?"
        case .deepAssessment: return "How far off am I from my goal?"
        case .trustRepair: return "That was not helpful."
        }
    }

    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for value in values {
            let key = value.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            output.append(value)
        }
        return output
    }
}
