import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

struct CoachChatWireMessage: Codable, Sendable, Equatable {
    enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    let role: Role
    let content: String
}

enum CoachChatTurnIntent: String, Codable, Sendable, Equatable {
    case coaching
    case greeting
    case offTopic
    case preference
    case vulnerable
    case unknown

    static func classify(_ userTurn: String?) -> CoachChatTurnIntent {
        guard let userTurn else { return .unknown }
        let lower = userTurn.lowercased()
        if TurnDepthClassifier.isGreetingOrSmallTalk(userTurn) {
            return .greeting
        }
        // A repair request or explicit state change outranks a telemetry ask
        // when the user combines both in one turn. Returning a score while
        // ignoring "your wording is robotic" would repeat the trust failure.
        if isCoachStyleFeedback(lower) ||
            isDirectnessPreference(userTurn) ||
            [
                "keep the coaching", "keep your replies", "keep replies",
                "make the coaching", "make your replies", "make replies",
                "be more concise", "be warmer"
            ].contains(where: lower.contains) ||
            isExplicitGoalOrVoiceMutation(lower) {
            return .preference
        }
        if CoachReliabilityGate.vulnerablePushbackUserTurn(userTurn) ||
            [
                "i'm nervous", "i am nervous", "i'm anxious", "i am anxious",
                "i'm overwhelmed", "i am overwhelmed", "i'm scared", "i am scared",
                "i'm exhausted", "i am exhausted"
            ].contains(where: lower.contains) {
            return .vulnerable
        }
        // A bounded personal readout is a coaching answer, including a short
        // follow-up such as "My pace?". Do this before low-signal matching so
        // a two-word metric question cannot be mistaken for a probe.
        if TurnDepthClassifier.explicitlyRequestsMetrics(userTurn) {
            return .coaching
        }
        if TurnDepthClassifier.isLowSignalOffTopicTest(userTurn) {
            return .offTopic
        }
        if [
            "how should", "what should", "how do i", "what do i",
            "how can i", "why do i", "why did i", "help me", "coach me",
            "what voice", "which voice", "voice should", "voice do i",
            "voice to pick"
        ].contains(where: lower.contains) {
            return .coaching
        }
        if CoachReliabilityGate.goalOrVoiceChangeUserTurn(userTurn) {
            return .preference
        }
        return .coaching
    }

    /// Only explicit mutation language belongs ahead of a combined metric
    /// request. Broader goal phrases such as "sound more authoritative" stay
    /// below how-to coaching detection so advice questions are not swallowed.
    private static func isExplicitGoalOrVoiceMutation(_ lower: String) -> Bool {
        if [
            "set me to", "change my goal", "change my voice",
            "switch my voice", "pick a voice", "choose a voice",
            "choose my voice"
        ].contains(where: lower.contains) {
            return true
        }
        let voiceNames = [
            "authoritative", "warm", "concise", "persuasive",
            "executive", "storytelling", "engaging"
        ]
        return voiceNames.contains(where: lower.contains) &&
            ["set", "change", "switch", "pick", "choose"]
                .contains(where: lower.contains)
    }

    /// A bounded request to change Noum's delivery, not a request for a new
    /// diagnosis or practice assignment. Keep verdict asks such as "give it to
    /// me straight" out of this matcher because those still need coaching.
    static func isDirectnessPreference(_ userTurn: String?) -> Bool {
        guard let lower = userTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !lower.isEmpty else {
            return false
        }
        return [
            "be direct", "be more direct", "direct with me", "keep it direct"
        ].contains(where: lower.contains)
    }

    static func isCoachStyleFeedback(_ userTurn: String?) -> Bool {
        guard let lower = userTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !lower.isEmpty else {
            return false
        }
        let normalized = lower.replacingOccurrences(of: "’", with: "'")
        // These short trust-repair turns clearly address the coach even though
        // they do not repeat a noun such as "answer" or "wording". Keep the
        // subject explicit so "I keep repeating myself" remains user speech,
        // not feedback about Noum's delivery.
        let directCoachComplaint = [
            "you're repeating yourself", "youre repeating yourself",
            "you are repeating yourself", "you keep repeating yourself",
            "you repeated yourself", "you said the same thing again",
            "this is generic", "that is generic", "that's generic",
            "this feels generic", "that feels generic",
            "that's not informative", "that is not informative",
            "that's not useful", "that is not useful",
            "that's not helpful", "that is not helpful",
            "that wasn't helpful", "that wasnt helpful",
            "why can't you just give me a straight answer",
            "why cant you just give me a straight answer",
            "you didn't answer", "you did not answer",
            "you missed the point", "what did you miss",
            "what exactly did you miss", "stop saying practice more",
            "stop telling me to practice", "what was generic about it",
            "what exactly was generic about it",
            "don't feel like that answered what i meant",
            "dont feel like that answered what i meant",
            "do not feel like that answered what i meant"
        ].contains(where: normalized.contains)
        if directCoachComplaint {
            return true
        }
        let coachOwnedTarget = [
            "your wording", "your reply", "your replies", "your answer",
            "your answers", "this wording", "that wording", "this reply",
            "that reply", "this answer", "that answer", "the response",
            "the responses", "this response", "that response", "the coaching",
            "you sound", "this sounds", "that sounds", "this feels",
            "that feels", "the reply feels", "the answer feels",
            "this is robotic", "that is robotic",
            "this still sounds", "that still sounds",
            "doesn't feel like a human", "does not feel like a human",
            "it just says", "it says", "your formatting",
            "tts", "text to speech", "the voice reads", "voice reads them",
            "voice reads the"
        ].contains(where: normalized.contains)
        let formattingComplaint = [
            "tts", "read them out", "read aloud", "formatting", "markdown",
            "symbols", "no-symbol", "no symbol", "the **", "asterisks"
        ].contains(where: normalized.contains)
        let styleComplaint = [
            "robotic", "templated", "template", "generic ai", "ai wrapper",
            "weird wording", "redundant wording", "too redundant",
            "too wordy", "too verbose", "too long", "overexplained",
            "over explained", "repeated the point", "repeating the point",
            "not human", "human expert", "too much writing",
            "not informative", "not useful", "not helpful", "too vague",
            "straight answer", "answer directly"
        ].contains(where: normalized.contains)
        let directFormattingPreference = [
            "don't use markdown", "do not use markdown", "no markdown",
            "plain text please", "don't use symbols", "do not use symbols"
        ].contains(where: normalized.contains)
        return directFormattingPreference ||
            (coachOwnedTarget && (formattingComplaint || styleComplaint))
    }
}

/// Separates turns that require a personal evidence decision from turns that
/// can be answered with general coaching craft or consent-bound conversation
/// memory. This is a wire-level policy selector, not another state owner.
enum CoachChatResponseKind: String, Codable, Sendable, Equatable {
    case personalEvidenceRead
    case generalCoaching
    case memoryHandoff
    case conversational

    static func classify(
        _ userTurn: String?,
        intent explicitIntent: CoachChatTurnIntent? = nil
    ) -> CoachChatResponseKind {
        guard let userTurn else { return .generalCoaching }
        let lower = userTurn.lowercased()
        let intent = explicitIntent ?? CoachChatTurnIntent.classify(userTurn)
        switch intent {
        case .greeting, .offTopic, .preference, .vulnerable:
            return .conversational
        case .coaching, .unknown:
            break
        }

        if TurnDepthClassifier.isMemoryHandoff(lower) {
            return .memoryHandoff
        }

        let mentionsRatedScore = lower.range(
            of: #"\b\d{1,2}\s*/\s*10\b"#,
            options: .regularExpression
        ) != nil && [
            "my ", " i ", "score", "bad", "good", "mean", "improved",
            "got", "received"
        ].contains(where: lower.contains)

        if TurnDepthClassifier.isGroundedRead(lower) ||
            TurnDepthClassifier.isDeepAssessment(lower) ||
            mentionsRatedScore ||
            [
                "what should i fix", "what should i do next",
                "what do i do next", "what next", "next move",
                "what should i work on", "what should i focus on",
                "give me one move", "what is the one move",
                "what's the one move", "coach this", "use my last rep",
                "what do you know about me",
                "know about me",
                "what have you noticed about me",
                "what pattern do you see", "what patterns do you see",
                "what patterns have you noticed", "based on my reps",
                "from my last session", "from my recent session",
                "from my last rep", "from my recent rep", "in my answers",
                "example of me", "in my sessions", "in sessions",
                "am i afraid", "am i avoiding", "do i avoid",
                "you counted", "is that my filler", "prompt made me repeat",
                "did i actually say", "did i say that", "my score improved",
                "score improved", "my interview answer",
                "answer landed better than practice",
                "what should i do with that filler count",
                "what do i do with that filler count",
                "what should i do with that filler rate",
                "what do i do with that filler rate",
                "what do i run next", "why the close instead of the opening",
                "why the close rather than the opening",
                "what is the exact rep", "what's the exact rep",
                "not my whole speaking style",
                "what would make you change the diagnosis",
                "what would change your diagnosis",
                "what test separates those", "which test separates those"
            ].contains(where: lower.contains) {
            return .personalEvidenceRead
        }
        if lower.contains("for me"),
           ["evidence", "rep", "session", "answer", "pattern", "notice", "read"]
            .contains(where: lower.contains) {
            return .personalEvidenceRead
        }
        return .generalCoaching
    }
}

enum CoachChatGenerationMode: String, Codable, Sendable, Equatable {
    case model
    case modelRewrite = "model-rewrite"
    case modelSanitized = "model-sanitized"
    case deterministicBrief = "deterministic-brief"
}

struct CoachChatBrief: Codable, Sendable, Equatable {
    enum EvidenceStrength: String, Codable, Sendable {
        case missing
        case weak
        case forming
        case repeated
    }

    static let maxFieldCharacters = 600
    static let maxProvisionalCharacters = 420
    static let insufficientEvidenceVerdict =
        "I don’t have enough evidence to choose your next move yet."

    let evidenceStrength: EvidenceStrength
    let directVerdict: String
    let decisiveEvidence: String?
    let nextMove: String?
    let missingEvidence: String?
    let repairFocus: String?
    let evidenceReadKind: CoachEvidenceReadKind?
    let requestedMetrics: [CoachMetricKind]?
    let latestRepMetrics: CoachLatestRepMetricProjection?
    let longitudinalTrend: CoachLongitudinalTrendProjection?

    /// The only local provisional copy allowed onto the pending chat row. It is
    /// composed from the same bounded evidence contract sent to the server, so
    /// an assessment exercise cannot leak after the brief has withdrawn it.
    var provisionalCoachRead: String {
        provisionalCoachRead(for: .personalEvidenceRead)
    }

    func provisionalCoachRead(for responseKind: CoachChatResponseKind) -> String {
        if responseKind == .memoryHandoff {
            return Self.boundedProvisional(Self.completeSentence(directVerdict))
        }
        if evidenceReadKind != nil {
            return Self.boundedProvisional(Self.completeSentence(directVerdict))
        }
        guard evidenceStrength != .missing,
              let decisiveEvidence,
              let nextMove else {
            return Self.insufficientEvidenceVerdict
        }
        let move = Self.sentenceBody(nextMove)
        let rationale = Self.userFacingEvidenceClause(decisiveEvidence)
        guard !move.isEmpty, !rationale.isEmpty else {
            return Self.insufficientEvidenceVerdict
        }

        // The provisional row gets one prescription, not an assessment verdict
        // plus a second imperative. The selected move is the only instruction;
        // its typed evidence is carried as the reason for that move.
        return Self.boundedProvisional(
            Self.completeSentence("\(move) because \(rationale)")
        )
    }

    init(assessment: CoachAssessment) {
        self = Self.personalEvidenceBrief(assessment: assessment)
    }

    /// Returns the typed brief that is authoritative for this response kind.
    /// General coaching without personal evidence deliberately carries no
    /// personal brief, so the provider can answer the craft question without
    /// pretending it observed the speaker. Memory handoff retains only the
    /// consent-bound conversation hypothesis selected by the reasoning owner.
    static func applicable(
        assessment: CoachAssessment,
        responseKind: CoachChatResponseKind
    ) -> CoachChatBrief? {
        switch responseKind {
        case .personalEvidenceRead:
            return personalEvidenceBrief(assessment: assessment)
        case .generalCoaching:
            return nil
        case .memoryHandoff:
            let brief = memoryHandoffBrief(assessment: assessment)
            guard brief.decisiveEvidence != nil, brief.nextMove != nil else {
                return nil
            }
            return brief
        case .conversational:
            return nil
        }
    }

    private init(
        evidenceStrength: EvidenceStrength,
        directVerdict: String,
        decisiveEvidence: String?,
        nextMove: String?,
        missingEvidence: String?,
        repairFocus: String?,
        evidenceReadKind: CoachEvidenceReadKind? = nil,
        requestedMetrics: [CoachMetricKind]? = nil,
        latestRepMetrics: CoachLatestRepMetricProjection? = nil,
        longitudinalTrend: CoachLongitudinalTrendProjection? = nil
    ) {
        self.evidenceStrength = evidenceStrength
        self.directVerdict = directVerdict
        self.decisiveEvidence = decisiveEvidence
        self.nextMove = nextMove
        self.missingEvidence = missingEvidence
        self.repairFocus = repairFocus
        self.evidenceReadKind = evidenceReadKind
        self.requestedMetrics = requestedMetrics
        self.latestRepMetrics = latestRepMetrics
        self.longitudinalTrend = longitudinalTrend
    }

    private static func personalEvidenceBrief(
        assessment: CoachAssessment
    ) -> CoachChatBrief {
        if assessment.evidenceReadKind == .latestRepMetrics {
            return latestRepMetricBrief(assessment: assessment)
        }
        if assessment.evidenceReadKind == .longitudinalTrend {
            return longitudinalTrendBrief(assessment: assessment)
        }
        let evidence = Self.decisiveEvidence(from: assessment)
        let hasDecisiveEvidence = evidence != nil
        let strength: EvidenceStrength
        if !hasDecisiveEvidence {
            strength = .missing
        } else if assessment.confidence < 0.55 {
            strength = .weak
        } else {
            // A numeric confidence plus multiple lines does not prove those
            // lines came from comparable reps. Stay forming unless a future
            // typed trajectory owner can establish repetition explicitly.
            strength = .forming
        }
        return CoachChatBrief(
            evidenceStrength: strength,
            directVerdict: hasDecisiveEvidence
            ? (Self.bounded(assessment.directVerdict) ??
                "The available evidence does not support a firm read yet.")
            : Self.insufficientEvidenceVerdict,
            decisiveEvidence: Self.bounded(evidence),
            // The move and diagnosis are one evidence contract. If the selected
            // dimension has no usable fact, do not preserve its exercise as though
            // Noum had earned that prescription.
            nextMove: hasDecisiveEvidence
                ? Self.bounded(assessment.nextProofTest)
                : nil,
            missingEvidence: Self.bounded(assessment.missingEvidence.first),
            repairFocus: Self.bounded(assessment.repairFocus)
        )
    }

    private static func latestRepMetricBrief(
        assessment: CoachAssessment
    ) -> CoachChatBrief {
        let requested = uniqueMetrics(
            assessment.requestedMetrics ?? CoachMetricKind.allCases
        )
        guard let metrics = assessment.latestRepMetrics else {
            return CoachChatBrief(
                evidenceStrength: .missing,
                directVerdict: "I don’t have a recent rep with enough recorded speech to report those stats accurately.",
                decisiveEvidence: nil,
                nextMove: nil,
                missingEvidence: "A recent rep with enough recorded speech is still missing.",
                repairFocus: nil,
                evidenceReadKind: .latestRepMetrics,
                requestedMetrics: requested
            )
        }

        let missing = requested.filter { !metrics.hasValue(for: $0) }
        let hasRequestedEvidence = missing.count < requested.count
        return CoachChatBrief(
            evidenceStrength: hasRequestedEvidence ? .weak : .missing,
            directVerdict: latestRepMetricVerdict(
                metrics: metrics,
                requested: requested
            ),
            decisiveEvidence: hasRequestedEvidence ? bounded(metrics.evidenceText) : nil,
            nextMove: nil,
            missingEvidence: missing.isEmpty
                ? nil
                : bounded(missingMetricEvidenceLine(missing)),
            repairFocus: nil,
            evidenceReadKind: .latestRepMetrics,
            requestedMetrics: requested,
            latestRepMetrics: metrics
        )
    }

    private static func longitudinalTrendBrief(
        assessment: CoachAssessment
    ) -> CoachChatBrief {
        guard let trend = assessment.longitudinalTrend else {
            return CoachChatBrief(
                evidenceStrength: .missing,
                directVerdict: "I don’t yet have two earlier reps under the same setup with enough speech for a fair comparison.",
                decisiveEvidence: nil,
                nextMove: nil,
                missingEvidence: "Two earlier reps under the same setup are still missing.",
                repairFocus: nil,
                evidenceReadKind: .longitudinalTrend
            )
        }
        return CoachChatBrief(
            evidenceStrength: .repeated,
            directVerdict: longitudinalTrendVerdict(trend),
            decisiveEvidence: bounded(trend.evidenceText),
            nextMove: nil,
            missingEvidence: "This reflects practice in Noum, not proof of transfer to real conversations.",
            repairFocus: nil,
            evidenceReadKind: .longitudinalTrend,
            longitudinalTrend: trend
        )
    }

    private static func latestRepMetricVerdict(
        metrics: CoachLatestRepMetricProjection,
        requested: [CoachMetricKind]
    ) -> String {
        if requested.count == 1, let metric = requested.first {
            switch metric {
            case .score:
                if let score = metrics.score {
                    return "Your latest \(metrics.mode) rep scored \(score)/10."
                }
            case .fillerCount:
                if let count = metrics.fillerCount {
                    let noun = count == 1 ? "filler" : "fillers"
                    return "Your latest \(metrics.mode) rep had \(count) \(noun) in \(metrics.durationSeconds) seconds."
                }
            case .fillerRatePerMinute:
                if let rate = metrics.fillerRatePerMinute {
                    return "You averaged \(oneDecimal(rate)) fillers per minute in your latest \(metrics.mode) rep."
                }
            case .paceWordsPerMinute:
                if let pace = metrics.paceWordsPerMinute {
                    return "You averaged \(pace) WPM over \(metrics.durationSeconds) seconds in your latest \(metrics.mode) rep."
                }
            case .durationSeconds:
                return "Your latest \(metrics.mode) rep lasted \(metrics.durationSeconds) seconds."
            }
            return "I found your latest \(metrics.mode) rep, but its \(metricLabel(metric)) isn’t reliable enough to report exactly."
        }

        var facts: [String] = []
        if requested.contains(.score), let score = metrics.score {
            facts.append("scored \(score)/10")
        }
        let requestsFillerCount = requested.contains(.fillerCount)
        let requestsFillerRate = requested.contains(.fillerRatePerMinute)
        if requestsFillerCount, let count = metrics.fillerCount {
            let noun = count == 1 ? "filler" : "fillers"
            if requestsFillerRate, let rate = metrics.fillerRatePerMinute {
                facts.append("had \(count) \(noun) (\(oneDecimal(rate)) per minute)")
            } else {
                facts.append("had \(count) \(noun)")
            }
        } else if requestsFillerRate, let rate = metrics.fillerRatePerMinute {
            facts.append("averaged \(oneDecimal(rate)) fillers per minute")
        }
        if requested.contains(.paceWordsPerMinute),
           let pace = metrics.paceWordsPerMinute {
            facts.append("averaged \(pace) WPM")
        }
        if requested.contains(.durationSeconds) {
            facts.append("spoke for \(metrics.durationSeconds) seconds")
        }

        let missing = requested.filter { !metrics.hasValue(for: $0) }
        let availableRead = facts.isEmpty
            ? "I found your latest \(metrics.mode) rep, but none of those measurements are reliable enough to report exactly."
            : "In your latest \(metrics.mode) rep, you \(joinedList(facts))."
        guard !missing.isEmpty else { return availableRead }
        return "\(availableRead) \(missingMetricEvidenceLine(missing))"
    }

    private static func longitudinalTrendVerdict(
        _ trend: CoachLongitudinalTrendProjection
    ) -> String {
        let improving = trend.metrics.filter { $0.direction == .improving }
        let declining = trend.metrics.filter { $0.direction == .declining }
        let opening: String
        if !improving.isEmpty, declining.isEmpty {
            opening = "There’s a positive signal in your latest \(trend.mode) rep, but I wouldn’t call it overall improvement yet."
        } else if improving.isEmpty, !declining.isEmpty {
            opening = "Your latest \(trend.mode) rep moved in the wrong direction on the measures we could compare."
        } else if !improving.isEmpty, !declining.isEmpty {
            opening = "Your latest \(trend.mode) rep is mixed, so I wouldn’t call it overall improvement yet."
        } else {
            opening = "Your latest \(trend.mode) rep is steady, with no clear improvement yet."
        }
        let comparisons = trend.metrics.map(trendComparisonSentence)
        let detail = joinedList(comparisons)
        let priorNoun = trend.comparableSessionIDs.count == 1 ? "rep" : "reps"
        return "\(opening) Compared with \(trend.comparableSessionIDs.count) earlier \(priorNoun) using the same setup, \(detail). This is practice evidence in Noum, not proof of transfer to real conversations."
    }

    private static func trendComparisonSentence(
        _ trend: CoachLongitudinalMetricTrend
    ) -> String {
        switch trend.metric {
        case .score:
            return "score was \(oneDecimal(trend.currentValue))/10 versus \(oneDecimal(trend.priorAverage))/10"
        case .fillerRatePerMinute:
            return "filler rate was \(oneDecimal(trend.currentValue)) per minute versus \(oneDecimal(trend.priorAverage)) per minute"
        case .paceWordsPerMinute:
            return "pace was \(Int(trend.currentValue.rounded())) WPM versus \(Int(trend.priorAverage.rounded())) WPM"
        case .fillerCount, .durationSeconds:
            return ""
        }
    }

    private static func missingMetricEvidenceLine(
        _ metrics: [CoachMetricKind]
    ) -> String {
        let labels = joinedList(metrics.map(metricLabel))
        let verb = metrics.count == 1 ? "was" : "were"
        return "The \(labels) \(verb) not reliable enough to report exactly."
    }

    private static func metricLabel(_ metric: CoachMetricKind) -> String {
        switch metric {
        case .score: return "score"
        case .fillerCount: return "filler count"
        case .fillerRatePerMinute: return "filler rate"
        case .paceWordsPerMinute: return "pace"
        case .durationSeconds: return "duration"
        }
    }

    private static func uniqueMetrics(_ metrics: [CoachMetricKind]) -> [CoachMetricKind] {
        var seen = Set<CoachMetricKind>()
        return metrics.filter { seen.insert($0).inserted }
    }

    private static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func joinedList(_ values: [String]) -> String {
        let nonEmpty = values.filter { !$0.isEmpty }
        guard let first = nonEmpty.first else { return "" }
        if nonEmpty.count == 1 { return first }
        if nonEmpty.count == 2 { return "\(first) and \(nonEmpty[1])" }
        return nonEmpty.dropLast().joined(separator: ", ") + ", and " + nonEmpty.last!
    }

    private static func memoryHandoffBrief(
        assessment: CoachAssessment
    ) -> CoachChatBrief {
        let evidence = assessment.evidenceUsed.compactMap { value -> String? in
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = clean.lowercased()
            guard lower.hasPrefix("conversation hypothesis:") ||
                    lower.hasPrefix("prior coach read:") else {
                return nil
            }
            return bounded(clean)
        }.first
        let hasEvidence = evidence != nil
        let strength: EvidenceStrength = hasEvidence && assessment.confidence >= 0.55
            ? .forming
            : .weak
        return CoachChatBrief(
            evidenceStrength: strength,
            directVerdict: bounded(assessment.directVerdict) ??
                "There is no conversation hypothesis to carry forward yet.",
            decisiveEvidence: evidence,
            nextMove: hasEvidence ? bounded(assessment.nextProofTest) : nil,
            missingEvidence: bounded(assessment.missingEvidence.first),
            repairFocus: nil
        )
    }

    var characterCount: Int {
        let requiredCharacters = evidenceStrength.rawValue.count + directVerdict.count
        let optionalFields: [String?] = [
            decisiveEvidence,
            nextMove,
            missingEvidence,
            repairFocus
        ]
        let optionalCharacters = optionalFields.reduce(into: 0) { count, field in
            count += field?.count ?? 0
        }
        let latestProvenanceCharacters = latestRepMetrics == nil ? 0 : 48
        let comparisonIDCharacters =
            (longitudinalTrend?.comparableSessionIDs.count ?? 0) * 36
        let requestedMetricCharacters = requestedMetrics?
            .map(\.rawValue)
            .joined()
            .count ?? 0
        let readKindCharacters = evidenceReadKind?.rawValue.count ?? 0
        let projectionCharacters = projectedMetricEvidenceText.count +
            latestProvenanceCharacters + comparisonIDCharacters +
            requestedMetricCharacters + readKindCharacters
        return requiredCharacters + optionalCharacters + projectionCharacters
    }

    var projectedMetricEvidenceText: String {
        [latestRepMetrics?.evidenceText, longitudinalTrend?.evidenceText]
            .compactMap { $0 }
            .joined(separator: "\n")
    }

    private static func bounded(_ value: String?) -> String? {
        let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !clean.isEmpty else { return nil }
        guard clean.count > maxFieldCharacters else { return clean }
        return String(clean.prefix(maxFieldCharacters - 1)) + "…"
    }

    private static func decisiveEvidence(from assessment: CoachAssessment) -> String? {
        guard let dimensionID = assessment.nextProofDimensionID else { return nil }

        // A typed move must be supported by evidence for that exact rubric
        // dimension and by a latest-rep signal. Never substitute a case-file
        // summary or a different dimension merely because it is the first line.
        guard assessment.evidenceUsed.contains(where: isLatestRepEvidence),
              let score = assessment.rubricScores.first(where: {
                  $0.dimensionID == dimensionID
              }),
              let fact = score.evidence.compactMap(usableEvidence).first else {
            return nil
        }
        let clean = fact.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        if lower.contains("latest rep") || lower.contains("recent rep") ||
            lower.contains("transcript") {
            return clean
        }
        let prefix = dimensionID == "pressure_stability"
            ? "recent reps: "
            : "latest rep: "
        return prefix + clean
    }

    private static func isLatestRepEvidence(_ value: String) -> Bool {
        let lower = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return lower.hasPrefix("latest rep:") ||
            lower.hasPrefix("transcript signal:") ||
            lower.hasPrefix("pace estimate:")
    }

    private static func usableEvidence(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let lower = clean.lowercased()
        let internalPrefixes = [
            "case summary:",
            "active intervention:",
            "hypothesis:"
        ]
        let unqualifiedMarkers = [
            "no clear",
            "no trailing",
            "no explicit",
            "no duration",
            "not enough",
            "not quantity-qualified",
            "not qualified",
            "insufficient evidence",
            "too small",
            "unavailable",
            "did not",
            "does not",
            "not judged",
            "no memorable",
            "no dimension-specific"
        ]
        guard !internalPrefixes.contains(where: lower.hasPrefix),
              !unqualifiedMarkers.contains(where: lower.contains) else {
            return nil
        }
        return clean
    }

    private static func userFacingEvidenceClause(_ value: String) -> String {
        let clean = sentenceBody(value)
        let lower = clean.lowercased()
        let mappings: [(prefix: String, lead: String)] = [
            ("latest rep:", "the latest rep showed"),
            ("recent reps:", "recent reps showed"),
            ("recent rep:", "the recent rep showed"),
            ("transcript signal:", "the latest transcript showed"),
            ("pace estimate:", "the latest rep’s pace was")
        ]
        if let mapping = mappings.first(where: { lower.hasPrefix($0.prefix) }) {
            let detail = clean.dropFirst(mapping.prefix.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !detail.isEmpty else { return mapping.lead }
            return "\(mapping.lead) \(lowercaseFirst(detail))"
        }
        if lower.hasPrefix("latest transcript ") ||
            lower.hasPrefix("latest rep ") ||
            lower.hasPrefix("recent rep ") {
            return "the \(lowercaseFirst(clean))"
        }
        if lower.hasPrefix("the latest ") || lower.hasPrefix("recent reps ") {
            return lowercaseFirst(clean)
        }
        return "the evidence showed \(lowercaseFirst(clean))"
    }

    private static func sentenceBody(_ value: String) -> String {
        var clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = clean.last, ".!?".contains(last) {
            clean.removeLast()
            clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return clean
    }

    private static func boundedProvisional(_ value: String) -> String {
        guard value.count > maxProvisionalCharacters else { return value }
        let rawPrefix = String(value.prefix(maxProvisionalCharacters - 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let wordBounded: String
        if let boundary = rawPrefix.lastIndex(where: { $0.isWhitespace }) {
            let candidate = rawPrefix[..<boundary]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            wordBounded = candidate.isEmpty ? rawPrefix : candidate
        } else {
            wordBounded = rawPrefix
        }
        return wordBounded + "…"
    }

    private static func completeSentence(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = clean.last,
              !".!?".contains(last) else {
            return clean
        }
        return clean + "."
    }

    private static func lowercaseFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.lowercased() + String(value.dropFirst())
    }

}

struct CoachChatRequest: Codable, Sendable, Equatable {
    static let schemaVersion = 2
    static let maxContextCharacters = 12_000
    static let maxMessageCharacters = 4_000
    static let totalMessageCharacterBudget = 19_000
    static let totalRequestCharacterBudget = 32_000
    static let maxQuoteSources = 4
    static let maxQuoteSourceCharacters = 600

    let schemaVersion: Int
    let requestID: String
    let accountID: String
    let surface: String
    let qualityTier: String
    let coachVoice: String?
    let turnDepth: String
    let turnIntent: String
    let responseKind: String
    let coachingBrief: CoachChatBrief?
    let verifiedQuoteSources: [String]
    let coachingContext: String
    let messages: [CoachChatWireMessage]

    init(
        requestID: UUID = UUID(),
        accountID: String,
        surface: String,
        qualityTier: String,
        coachVoice: String? = nil,
        turnDepth: String = CoachTurnDepth.groundedRead.rawValue,
        turnIntent: String = CoachChatTurnIntent.unknown.rawValue,
        responseKind: String = CoachChatResponseKind.generalCoaching.rawValue,
        coachingBrief: CoachChatBrief? = nil,
        verifiedQuoteSources: [String] = [],
        coachingContext: String,
        messages: [CoachChatWireMessage]
    ) {
        self.schemaVersion = Self.schemaVersion
        self.requestID = requestID.uuidString
        self.accountID = accountID
        self.surface = surface
        self.qualityTier = qualityTier
        self.coachVoice = coachVoice
        self.turnDepth = turnDepth
        self.turnIntent = turnIntent
        self.responseKind = responseKind
        self.coachingBrief = coachingBrief
        let boundedQuoteSources = Self.boundedQuoteSources(verifiedQuoteSources)
        self.verifiedQuoteSources = boundedQuoteSources
        let boundedContext = Self.boundedContext(coachingContext)
        self.coachingContext = boundedContext
        let quoteCharacterCount = boundedQuoteSources.reduce(0) { $0 + $1.count }
        let nonMessageCharacterCount = boundedContext.count +
            (coachingBrief?.characterCount ?? 0) + quoteCharacterCount
        let requestHeadroom = max(
            0,
            Self.totalRequestCharacterBudget - nonMessageCharacterCount
        )
        self.messages = Self.boundedMessages(
            messages,
            budget: min(Self.totalMessageCharacterBudget, requestHeadroom)
        )
    }

    private static func boundedContext(_ value: String) -> String {
        guard value.count > maxContextCharacters else { return value }
        let separator = "\n…\n"
        let remaining = maxContextCharacters - separator.count
        let headCount = remaining / 2
        let tailCount = remaining - headCount
        return String(value.prefix(headCount)) + separator + String(value.suffix(tailCount))
    }

    private static func boundedQuoteSources(_ values: [String]) -> [String] {
        values.prefix(maxQuoteSources).compactMap { value in
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return nil }
            guard clean.count > maxQuoteSourceCharacters else { return clean }
            return String(clean.prefix(maxQuoteSourceCharacters - 1)) + "…"
        }
    }

    private static func boundedMessages(
        _ values: [CoachChatWireMessage],
        budget initialBudget: Int
    ) -> [CoachChatWireMessage] {
        var budget = initialBudget
        var newestFirst: [CoachChatWireMessage] = []

        for message in values.suffix(12).reversed() {
            guard budget > 0 else { break }
            let clean = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            let limit = min(maxMessageCharacters, budget)
            let content: String
            if clean.count <= limit {
                content = clean
            } else if limit == 1 {
                content = "…"
            } else {
                content = String(clean.prefix(limit - 1)) + "…"
            }
            newestFirst.append(CoachChatWireMessage(role: message.role, content: content))
            budget -= content.count
        }
        return newestFirst.reversed()
    }
}

struct CoachChatDelta: Codable, Sendable, Equatable {
    let type: String
    let requestID: String
    let text: String
}

struct CoachChatCompletion: Codable, Sendable, Equatable {
    let requestID: String
    let text: String
    let model: String
    let policyVersion: String?
    let generationMode: CoachChatGenerationMode?
    let qualityTier: String
    let finishReason: String
    let inputTokens: Int?
    let outputTokens: Int?

    init(
        requestID: String,
        text: String,
        model: String,
        qualityTier: String,
        finishReason: String,
        inputTokens: Int?,
        outputTokens: Int?,
        policyVersion: String? = nil,
        generationMode: CoachChatGenerationMode? = nil
    ) {
        self.requestID = requestID
        self.text = text
        self.model = model
        self.policyVersion = policyVersion
        self.generationMode = generationMode
        self.qualityTier = qualityTier
        self.finishReason = finishReason
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

enum CoachChatEvent: Sendable, Equatable {
    case delta(String)
    case completion(CoachChatCompletion)
}

enum CoachChatUnavailableReason: Sendable, Equatable {
    case authenticationPending
    /// The hydrated account deliberately owns only on-device data and has no
    /// Firebase identity that can authorize the live coach callable.
    case localOnlyGuest
    /// A backend-owned account is hydrated, but Firebase Auth is missing or
    /// names a different account. Reconnecting must preserve the durable owner.
    case secureSessionMissing
    /// The deployed capability handshake does not advertise the additive v2
    /// callable and policy contract required by this client.
    case backendVersionMissing
    case debugProviderMissing
    case service
}

enum CoachChatTransportAvailability: Sendable, Equatable {
    case checking
    case available
    case unavailable(CoachChatUnavailableReason)
}

enum CoachChatTransportError: Error, Sendable, Equatable {
    case serviceUnavailable
    case unauthenticated
    case rateLimited
    case cancelled
    case invalidResponse
    case qualityRejected
    case invalidRequest
    case permissionDenied
    case backendVersionMissing
    case network
}

protocol CoachChatTransport: Sendable {
    var requiresDurableAccountBinding: Bool { get }
    func availability() async -> CoachChatTransportAvailability
    func stream(_ request: CoachChatRequest) throws -> AsyncThrowingStream<CoachChatEvent, Error>
}

extension CoachChatTransport {
    var requiresDurableAccountBinding: Bool { false }
}

struct FirebaseCoachChatTransport: CoachChatTransport {
    static let region = "europe-west2"
    static let functionName = "coachChatV2"
    static let availabilityFunctionName = "coachChatAvailability"
    static let requiredPolicyVersion = "noum-coach-v2"
    let requiresDurableAccountBinding = true

    private struct AvailabilityRequest: Encodable {
        let schemaVersion = 1
        let requestID = UUID().uuidString
        let requiredFunctionName = FirebaseCoachChatTransport.functionName
        let requiredRequestSchemaVersion = CoachChatRequest.schemaVersion
        let requiredPolicyVersion = FirebaseCoachChatTransport.requiredPolicyVersion
    }

    private struct AvailabilityResponse: Decodable {
        let available: Bool
        let functionName: String?
        let requestSchemaVersion: Int?
        let policyVersion: String?
    }

    func availability() async -> CoachChatTransportAvailability {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFunctions)
        // The former callable preflight only echoed Auth/App Check admission;
        // it did not probe Vertex and production logs showed it returning true
        // immediately before failed generations. Keep composer admission local
        // and let the real coachChat request report the typed runtime outcome.
        // Firebase Auth and Noum's durable account must still be the same ready,
        // provider-admitted identity. A local-only guest or stale Firebase user
        // is not authority for this account's conversation.
        let accountState = await MainActor.run {
            let auth = AuthManager.shared
            let accountID = auth.currentAccountID
            return (
                accountID: accountID,
                isHydrated: auth.initialAccountHydrationState == .ready,
                providerWorkAllowed: accountID.map {
                    auth.isProviderWorkAllowed(for: $0)
                } ?? false
            )
        }
        let localAvailability = Self.localAvailability(
            firebaseConfigured: FirebaseApp.app() != nil,
            firebaseUID: Auth.auth().currentUser?.uid,
            durableAccountID: accountState.accountID,
            accountIsHydrated: accountState.isHydrated,
            providerWorkAllowed: accountState.providerWorkAllowed
        )
        guard localAvailability == .available else {
            return localAvailability
        }
        do {
            let functions = Functions.functions(region: Self.region)
            let callable: Callable<AvailabilityRequest, AvailabilityResponse> =
                functions.httpsCallable(Self.availabilityFunctionName)
            let response = try await callable.call(AvailabilityRequest())
            return Self.capabilityAvailability(
                available: response.available,
                functionName: response.functionName,
                requestSchemaVersion: response.requestSchemaVersion,
                policyVersion: response.policyVersion
            )
        } catch {
            if Self.mapStreamError(error) == .backendVersionMissing {
                return .unavailable(.backendVersionMissing)
            }
            return .unavailable(.service)
        }
        #else
        return .unavailable(.service)
        #endif
    }

    nonisolated static func localAvailability(
        firebaseConfigured: Bool,
        firebaseUID: String?,
        durableAccountID: String?,
        accountIsHydrated: Bool,
        providerWorkAllowed: Bool
    ) -> CoachChatTransportAvailability {
        guard firebaseConfigured else {
            return .unavailable(.service)
        }
        guard let durableAccountID,
              !durableAccountID.isEmpty,
              accountIsHydrated,
              providerWorkAllowed else {
            return .unavailable(.authenticationPending)
        }
        guard AuthManager.shouldSyncBackend(accountID: durableAccountID) else {
            return .unavailable(.localOnlyGuest)
        }
        guard firebaseUID == durableAccountID else {
            return .unavailable(.secureSessionMissing)
        }
        return .available
    }

    nonisolated static func requestIdentityMatches(
        requestAccountID: String,
        firebaseUID: String?,
        durableAccountID: String?
    ) -> Bool {
        !requestAccountID.isEmpty &&
            requestAccountID == firebaseUID &&
            requestAccountID == durableAccountID
    }

    nonisolated static func capabilityAvailability(
        available: Bool,
        functionName: String?,
        requestSchemaVersion: Int?,
        policyVersion: String?
    ) -> CoachChatTransportAvailability {
        guard available else { return .unavailable(.service) }
        guard functionName == Self.functionName,
              requestSchemaVersion == CoachChatRequest.schemaVersion,
              policyVersion == Self.requiredPolicyVersion else {
            return .unavailable(.backendVersionMissing)
        }
        return .available
    }

    func stream(_ request: CoachChatRequest) throws -> AsyncThrowingStream<CoachChatEvent, Error> {
        #if canImport(FirebaseFunctions)
        typealias Response = StreamResponse<CoachChatDelta, CoachChatCompletion>
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // `AICoachChatService.secureReply` owns the one remote
                    // capability preflight for this turn. Repeating it here
                    // could race a successful preflight and collapse a typed
                    // backend/service reason into `.unauthenticated`.
                    let durableAccountID = await MainActor.run {
                        AuthManager.shared.currentAccountID
                    }
                    guard Self.requestIdentityMatches(
                        requestAccountID: request.accountID,
                        firebaseUID: Auth.auth().currentUser?.uid,
                        durableAccountID: durableAccountID
                    ) else {
                        throw CoachChatTransportError.unauthenticated
                    }
                    let functions = Functions.functions(region: Self.region)
                    let callable: Callable<CoachChatRequest, Response> =
                        functions.httpsCallable(Self.functionName)
                    let upstream = try callable.stream(request)
                    for try await response in upstream {
                        switch response {
                        case .message(let message):
                            guard message.type == "delta", message.requestID == request.requestID else {
                                continue
                            }
                            continuation.yield(.delta(message.text))
                        case .result(let result):
                            guard result.requestID == request.requestID else {
                                throw CoachChatTransportError.invalidResponse
                            }
                            continuation.yield(.completion(result))
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CoachChatTransportError.cancelled)
                } catch {
                    continuation.finish(throwing: Self.mapStreamError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        #else
        throw CoachChatTransportError.serviceUnavailable
        #endif
    }

    #if canImport(FirebaseFunctions)
    nonisolated static func mapStreamError(_ error: Error) -> CoachChatTransportError {
        // Errors raised by our own admission and response-integrity checks are
        // already typed. Do not reinterpret their NSError bridge as an unknown
        // Functions failure and collapse them to a network outage.
        if let transportError = error as? CoachChatTransportError {
            return transportError
        }
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return .network
        }
        let details = nsError.userInfo[FunctionsErrorDetailsKey]
        let reason = (details as? [String: Any])?["reason"] as? String
        return mapFunctionsErrorCode(code, reason: reason)
    }

    nonisolated static func mapFunctionsErrorCode(
        _ code: FunctionsErrorCode,
        reason: String? = nil
    ) -> CoachChatTransportError {
        switch code {
        case .unauthenticated: return .unauthenticated
        case .invalidArgument: return .invalidRequest
        case .permissionDenied: return .permissionDenied
        case .resourceExhausted: return .rateLimited
        case .cancelled: return .cancelled
        case .dataLoss: return .invalidResponse
        case .failedPrecondition where reason == "coach-quality-rejected":
            return .qualityRejected
        case .notFound: return .backendVersionMissing
        case .unavailable, .deadlineExceeded: return .serviceUnavailable
        default: return .network
        }
    }
    #endif
}

#if DEBUG
/// Debug-only adapter used by the existing direct-provider chain. It accepts
/// an injected operation so no provider key or vendor SDK leaks into the
/// production transport surface.
struct DirectProviderDebugTransport: CoachChatTransport {
    typealias Operation = @Sendable (CoachChatRequest) async throws -> CoachChatCompletion

    let isConfigured: @Sendable () -> Bool
    let operation: Operation

    func availability() async -> CoachChatTransportAvailability {
        isConfigured() ? .available : .unavailable(.debugProviderMissing)
    }

    func stream(_ request: CoachChatRequest) throws -> AsyncThrowingStream<CoachChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.completion(try await operation(request)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
#endif
