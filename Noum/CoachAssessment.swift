import Foundation

// MARK: - Typed coach assessment

struct CoachAssessment: Codable, Equatable {
    enum ResponseMode: String, Codable, Equatable {
        case immediateOnly
        case expandable
    }

    enum ToneMode: String, Codable, Equatable {
        case validate
        case challenge
        case explain
        case prescribe
        case repair
    }

    var turnDepth: CoachTurnDepth
    var surface: CoachReplySurface
    var questionRestatement: String
    var directVerdict: String
    var confidence: Double
    var evidenceUsed: [String]
    var rubricScores: [RubricScore]
    var missingEvidence: [String]
    var nextProofTest: String
    var responseMode: ResponseMode
    var toneMode: ToneMode? = nil
    var repairFocus: String? = nil

    var evidenceReferenceCount: Int {
        evidenceUsed.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var weakestRubricScore: RubricScore? {
        rubricScores.min {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.dimensionID < $1.dimensionID
        }
    }

    /// Local, deterministic read for the streaming-like fallback. It is shown
    /// only while the provider is still verbalising the full answer and is not
    /// persisted as the final coach response.
    var immediateCoachRead: String {
        switch turnDepth {
        case .quickMove:
            if let pressureFillerRead = Self.pressureFillerRead(
                evidence: evidenceUsed,
                proofTest: nextProofTest
            ) {
                return pressureFillerRead
            }
            return Self.compactRead(
                verdict: directVerdict,
                evidence: evidenceUsed.first,
                missing: nil,
                proofTest: nextProofTest,
                turnDepth: turnDepth
            )
        case .groundedRead:
            return Self.compactRead(
                verdict: directVerdict,
                evidence: evidenceUsed.first,
                missing: nil,
                proofTest: nextProofTest,
                turnDepth: turnDepth
            )
        case .deepAssessment:
            return Self.compactRead(
                verdict: directVerdict,
                evidence: evidenceUsed.first,
                missing: missingEvidence.first,
                proofTest: nextProofTest,
                turnDepth: turnDepth
            )
        case .trustRepair:
            if let repairFocus,
               !repairFocus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if Self.isPressureDifficultyRepair(repairFocus) {
                    return Self.pressureDifficultyRepairRead(
                        evidence: evidenceUsed,
                        proofTest: nextProofTest
                    )
                }
                return Self.trustRepairRead(
                    repairFocus: repairFocus,
                    verdict: directVerdict,
                    proofTest: nextProofTest
                )
            }
            return Self.trustRepairRead(
                repairFocus: "I need to repair the answer before adding another drill",
                verdict: directVerdict,
                proofTest: nextProofTest
            )
        }
    }

    private static func pressureFillerRead(
        evidence: [String],
        proofTest: String
    ) -> String? {
        let combined = ([proofTest] + evidence)
            .joined(separator: " ")
            .lowercased()
        guard combined.contains("pressure"),
              combined.contains("filler"),
              combined.contains("silent beat"),
              combined.contains("final sentence") else {
            return nil
        }
        let countPhrase = fillerCountPhrase(in: [proofTest] + evidence)
        let evidencePhrase = countPhrase.map { " had \($0)" } ?? " showed fillers"
        let closeClusterPhrase = containsCloseClusterEvidence(in: combined)
            ? ", mostly before the close,"
            : ","
        return "Your last pressure rep\(evidencePhrase)\(closeClusterPhrase) so the pressure leak is the final sentence. Do not fight the urge; replace it with one silent beat before the final sentence, then finish the ask."
    }

    private static func fillerCountPhrase(in values: [String]) -> String? {
        let tokens = values
            .joined(separator: " ")
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        for index in tokens.indices {
            guard let count = Int(tokens[index]) else { continue }
            let nextIndex = tokens.index(after: index)
            guard nextIndex < tokens.endIndex,
                  tokens[nextIndex].hasPrefix("filler") else { continue }
            let noun = count == 1 ? "filler" : "fillers"
            return "\(count) \(noun)"
        }
        return nil
    }

    private static func containsCloseClusterEvidence(in value: String) -> Bool {
        value.contains("mostly before the close") ||
            value.contains("cluster before the close") ||
            value.contains("clustered before the close") ||
            value.contains("clusters before the close")
    }

    private static func trustRepairRead(
        repairFocus: String,
        verdict: String,
        proofTest: String
    ) -> String {
        [
            "Fair push. \(completeSentence(repairFocus))",
            completeSentence(verdict),
            completeSentence(proofTest)
        ].joined(separator: " ")
    }

    private static func isPressureDifficultyRepair(_ repairFocus: String) -> Bool {
        let lower = repairFocus.lowercased()
        return lower.contains("easier than it feels under pressure") ||
            lower.contains("not easy") ||
            lower.contains("harder than")
    }

    private static func pressureDifficultyRepairRead(
        evidence: [String],
        proofTest: String
    ) -> String {
        let combined = ([proofTest] + evidence)
            .joined(separator: " ")
            .lowercased()
        if ["silent beat", "silence", "close", "final sentence", "ask"].contains(where: { combined.contains($0) }) {
            return "Fair push: no, it is not easy. The hard part is holding the silent beat at the pressure point before the final sentence. Keep the next rep smaller: say only the close — one silent beat, the final sentence, then stop."
        }
        return "Fair push: no, it is not easy. The hard part is that sentence one carries the social risk, so test a smaller version in the next rep: say only the disagreement and one calm reason, then stop before defending it."
    }

    private static func compactRead(
        verdict: String,
        evidence: String?,
        missing: String?,
        proofTest: String,
        turnDepth: CoachTurnDepth
    ) -> String {
        var parts: [String] = []
        parts.append(completeSentence(verdict))
        if let signal = compactEvidence(evidence, turnDepth: turnDepth) {
            parts.append("The useful signal is \(completeSentence(signal))")
        }
        let hasMissing = !(missing?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
        if hasMissing, let missing {
            // Name the gap explicitly on a bounded/abstaining read: the word
            // "missing" keeps "I still need …" honest about what is not yet proven.
            parts.append("What is still missing is \(missingRequirementPhrase(missing))")
        }
        if hasMissing {
            parts.append("Use this as the proof test. \(completeSentence(proofTest))")
        } else {
            parts.append(completeSentence(proofTest))
        }
        return parts.joined(separator: " ")
    }

    private static func compactEvidence(_ raw: String?, turnDepth: CoachTurnDepth) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let prefixes = [
            "latest rep:",
            "pace estimate:",
            "case summary:",
            "case focus:",
            "case evidence:",
            "active intervention:",
            "conversation hypothesis:",
            "prior coach read:",
            "trust repair signal:"
        ]
        let lowered = trimmed.lowercased()
        let candidate: String
        if let prefix = prefixes.first(where: { lowered.hasPrefix($0) }) {
            let value = trimmed.dropFirst(prefix.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            candidate = value.isEmpty ? trimmed : String(value)
        } else {
            candidate = trimmed
        }
        guard !compactEvidenceIsModeOnly(candidate) else { return nil }
        let spoken = spokenEvidence(candidate, turnDepth: turnDepth)
        return spoken.isEmpty ? nil : spoken
    }

    private static func compactEvidenceIsModeOnly(_ value: String) -> Bool {
        let punctuation = CharacterSet(charactersIn: " .,:;")
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines.union(punctuation))
            .lowercased()
        let nucleus = normalized
            .replacingOccurrences(
                of: #"^(?:the\s+)?(?:last|latest)\s+rep\s+"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines.union(punctuation))
        return [
            "timed",
            "timed practice",
            "practice",
            "pressure",
            "pressure drill"
        ].contains(nucleus)
    }

    private static func spokenEvidence(_ raw: String, turnDepth: CoachTurnDepth) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = value.lowercased()

        if looksLikeRawRepMetricCluster(lower) {
            let mode = spokenModeName(from: lower)
            if turnDepth == .deepAssessment {
                return "one recent \(mode) rep gives a usable sample, not a full goal verdict"
            }
            return "one recent \(mode) rep gives a usable sample"
        }

        return value
    }

    private static func looksLikeRawRepMetricCluster(_ lower: String) -> Bool {
        let hasScore = lower.range(
            of: #"\b\d(?:\.\d)?\s*/\s*10\b"#,
            options: .regularExpression
        ) != nil || lower.range(
            of: #"\b(?:score|scored|hit)\s+\d{1,3}\b"#,
            options: .regularExpression
        ) != nil
        let hasFillers = lower.range(
            of: #"\b\d+\s+fillers?\b"#,
            options: .regularExpression
        ) != nil
        let hasDuration = lower.range(
            of: #"\b\d{2,3}\s*(?:s|sec(?:ond)?s?)\b"#,
            options: .regularExpression
        ) != nil
        return hasScore && (hasFillers || hasDuration)
    }

    private static func spokenModeName(from lower: String) -> String {
        if lower.contains("timed") { return "timed" }
        if lower.contains("sudden") || lower.contains("pressure") { return "pressure" }
        if lower.contains("conversation") || lower.contains("interaction") || lower.contains(" im ") {
            return "conversation"
        }
        if lower.contains("ah-counter") || lower.contains("filler") { return "filler-control" }
        return "practice"
    }

    private static func missingRequirementPhrase(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let lower = trimmed.lowercased()
        let phrase: String
        if lower.hasPrefix("need ") {
            phrase = String(trimmed.dropFirst("Need ".count))
        } else {
            phrase = trimmed
        }
        return completeSentence(lowercaseFirst(phrase))
    }

    private static func lowercaseFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).lowercased() + String(text.dropFirst())
    }

    private static func completeSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return trimmed }
        if ".!?".contains(last) { return trimmed }
        return "\(trimmed)."
    }
}
