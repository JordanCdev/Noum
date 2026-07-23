import Foundation

/// The single delivery lever a transcript-ladder retry is intended to move.
/// This is content-free and safe to persist/sync; the user's source and retry
/// transcripts remain in their existing `PracticeSession` evidence rows.
enum TranscriptPracticeLever: String, Codable, CaseIterable, Hashable, Sendable {
    case opening
    case closing
    case structure
    case concise

    init(weakness: AIRewriteService.Weakness) {
        switch weakness {
        case .opening: self = .opening
        case .closing: self = .closing
        case .structure: self = .structure
        case .concise: self = .concise
        }
    }

    var focusLabel: String {
        switch self {
        case .opening: return "opening directness"
        case .closing: return "closing decisiveness"
        case .structure: return "visible structure"
        case .concise: return "concise delivery"
        }
    }

    var successMeasure: String {
        switch self {
        case .opening:
            return "Lead with the point and remove one tentative opening marker."
        case .closing:
            return "Finish on the decision or next step without trailing off."
        case .structure:
            return "Make the sequence easier to follow with one useful signpost."
        case .concise:
            return "Preserve the meaning with fewer words and no extra branch."
        }
    }

    var weakness: AIRewriteService.Weakness {
        switch self {
        case .opening: return .opening
        case .closing: return .closing
        case .structure: return .structure
        case .concise: return .concise
        }
    }
}

/// Durable, source-bound presentation of the transcript upgrade that was
/// actually shown for one saved rep. The session remains the sole owner of the
/// source transcript; this snapshot only prevents Review from making another
/// provider request (and potentially showing different coaching) when the user
/// reopens the same evidence later.
struct TranscriptRewriteSnapshot: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let maximumRewriteCharacters = 1_200

    enum Origin: String, Codable, Equatable, Sendable {
        case provider
        case onDevice

        init(_ source: Rewrite.Source) {
            switch source {
            case .provider: self = .provider
            case .onDevice: self = .onDevice
            }
        }

        var rewriteSource: Rewrite.Source {
            switch self {
            case .provider: return .provider
            case .onDevice: return .onDevice
            }
        }
    }

    let schemaVersion: Int
    let weakness: AIRewriteService.Weakness
    let originalSnippet: String
    let oneStepText: String
    let aspirationalText: String?
    let origin: Origin
    let createdAt: Date

    init(
        weakness: AIRewriteService.Weakness,
        originalSnippet: String,
        oneStepText: String,
        aspirationalText: String?,
        origin: Origin,
        createdAt: Date = Date(),
        schemaVersion: Int = Self.schemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.weakness = weakness
        self.originalSnippet = originalSnippet
        self.oneStepText = oneStepText
        self.aspirationalText = aspirationalText
        self.origin = origin
        self.createdAt = createdAt
    }

    var isSupported: Bool {
        schemaVersion == Self.schemaVersion
            && !originalSnippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !oneStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && originalSnippet.count <= Self.maximumRewriteCharacters
            && oneStepText.count <= Self.maximumRewriteCharacters
            && (aspirationalText?.count ?? 0) <= Self.maximumRewriteCharacters
    }

    /// The source excerpt is derived by the same bounded helper used by the
    /// rewrite request. Exact equality is stronger than substring matching
    /// because long opening/closing excerpts intentionally include an ellipsis.
    func matches(sourceTranscript: String) -> Bool {
        guard isSupported else { return false }
        return originalSnippet == AIRewriteService.originalSnippet(
            transcript: sourceTranscript,
            weakness: weakness
        )
    }

    var oneStepRewrite: Rewrite {
        Rewrite(
            text: oneStepText,
            weakness: weakness,
            intensity: .medium,
            source: origin.rewriteSource
        )
    }

    var aspirationalRewrite: Rewrite? {
        guard let aspirationalText,
              !aspirationalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              aspirationalText.caseInsensitiveCompare(oneStepText) != .orderedSame else {
            return nil
        }
        return Rewrite(
            text: aspirationalText,
            weakness: weakness,
            intensity: .strong,
            source: origin.rewriteSource
        )
    }
}

/// Persisted prescription provenance for one accepted transcript-ladder retry.
/// It intentionally contains no transcript, rewrite, prompt, or content hash.
struct TranscriptRetryTarget: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let lever: TranscriptPracticeLever

    init(lever: TranscriptPracticeLever, schemaVersion: Int = Self.schemaVersion) {
        self.schemaVersion = schemaVersion
        self.lever = lever
    }

    var isSupported: Bool { schemaVersion == Self.schemaVersion }
}

enum TranscriptRetryResult: String, Codable, Equatable, Sendable {
    case improved
    case held
    case regressed
    case needsMoreEvidence
}

/// Content-free result of comparing a retry with its exact verified source
/// session. Signals are bounded 0...100 and explain the direction of movement;
/// they are not a new overall speaking score.
struct TranscriptRetryComparison: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let lever: TranscriptPracticeLever
    let sourceSessionID: UUID
    let retrySessionID: UUID
    let sourceSignal: Int
    let retrySignal: Int
    let meaningOverlapPercent: Int
    let result: TranscriptRetryResult

    var isComparable: Bool {
        schemaVersion == Self.schemaVersion
            && sourceSessionID != retrySessionID
            && (0...100).contains(sourceSignal)
            && (0...100).contains(retrySignal)
            && (0...100).contains(meaningOverlapPercent)
            && result != .needsMoreEvidence
    }
}

/// Process-local route payload. The suggested words stay in the existing
/// account-bound handoff; only `retryTarget` is eligible for persistence.
struct TranscriptPracticePrescription: Equatable {
    let correlationID: UUID
    let sourceSessionID: UUID
    let suggestedPrompt: String
    let title: String
    let focus: String
    let target: String
    let targetDimensionID: String?
    let goal: SpeakingStyleGoal?
    let retryTarget: TranscriptRetryTarget

    var fingerprint: String {
        TranscriptPracticeIntent.fingerprint(
            sourceSessionID: sourceSessionID,
            retryTarget: retryTarget,
            targetDimensionID: targetDimensionID
        )
    }
}

/// Keeps a transcript-ladder retry on the same communication problem. The
/// rewrite is a reference rung, not a script to recite; when the source rep
/// has a prompt, Timed Practice must present that exact prompt again.
enum TranscriptRetryPrompt {
    static func resolve(sourcePrompt: String?, fallbackRewritePrompt: String) -> String {
        if let sourcePrompt {
            let trimmed = sourcePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return fallbackRewritePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Content-free provenance that travels beside the seeded prompt and is
/// consumed by the exact Timed Practice route. It gives the route/debug layer
/// enough identity to join the retry without retaining a second copy of user
/// content.
struct TranscriptPracticeIntent: Equatable {
    let correlationID: UUID
    let sourceSessionID: UUID
    let title: String
    let focus: String
    let target: String
    let targetDimensionID: String?
    let goal: SpeakingStyleGoal?
    let retryTarget: TranscriptRetryTarget

    var fingerprint: String {
        Self.fingerprint(
            sourceSessionID: sourceSessionID,
            retryTarget: retryTarget,
            targetDimensionID: targetDimensionID
        )
    }

    static func fingerprint(
        sourceSessionID: UUID,
        retryTarget: TranscriptRetryTarget,
        targetDimensionID: String?
    ) -> String {
        [
            "transcript-ladder",
            sourceSessionID.uuidString,
            retryTarget.lever.rawValue,
            targetDimensionID ?? "general",
        ].joined(separator: "|")
    }
}

/// Source-bound, one-lever comparison used after a user accepts a transcript
/// ladder and completes Timed Practice. The result is intentionally cautious:
/// low-confidence speech, short fragments, or likely meaning drift all produce
/// `needsMoreEvidence` rather than a fabricated win/loss.
enum TranscriptRetryComparator {
    static let minimumConfidence = 0.55
    static let minimumWords = 8
    static let minimumSharedContentWords = 3
    static let minimumMeaningOverlap = 0.38
    static let meaningfulSignalMovement = 8

    static func compare(
        source: PracticeSession,
        retry: PracticeSession,
        target: TranscriptRetryTarget
    ) -> TranscriptRetryComparison? {
        guard target.isSupported,
              source.id != retry.id,
              source.transcriptConfidence.map({ $0 >= minimumConfidence }) ?? true,
              retry.transcriptConfidence.map({ $0 >= minimumConfidence }) ?? true else {
            return nil
        }

        let sourceWords = words(in: source.transcript)
        let retryWords = words(in: retry.transcript)
        let sourceContent = contentWords(in: source.transcript)
        let retryContent = contentWords(in: retry.transcript)
        let shared = sourceContent.intersection(retryContent).count
        let overlap = diceOverlap(sourceContent, retryContent)
        let overlapPercent = Int((overlap * 100).rounded()).clamped(to: 0...100)
        let sourceSignal = signal(for: target.lever, transcript: source.transcript)
        let retrySignal = signal(for: target.lever, transcript: retry.transcript)

        let evidenceIsThin = sourceWords.count < minimumWords
            || retryWords.count < minimumWords
            || shared < minimumSharedContentWords
            || overlap < minimumMeaningOverlap

        let result: TranscriptRetryResult
        if evidenceIsThin {
            result = .needsMoreEvidence
        } else {
            let delta = retrySignal - sourceSignal
            if delta >= meaningfulSignalMovement {
                result = .improved
            } else if delta <= -meaningfulSignalMovement {
                result = .regressed
            } else {
                result = .held
            }
        }

        return TranscriptRetryComparison(
            schemaVersion: TranscriptRetryComparison.schemaVersion,
            lever: target.lever,
            sourceSessionID: source.id,
            retrySessionID: retry.id,
            sourceSignal: sourceSignal,
            retrySignal: retrySignal,
            meaningOverlapPercent: overlapPercent,
            result: result
        )
    }

    private static func signal(for lever: TranscriptPracticeLever, transcript: String) -> Int {
        let tokens = words(in: transcript)
        guard !tokens.isEmpty else { return 0 }
        switch lever {
        case .opening:
            let opening = Array(tokens.prefix(16)).joined(separator: " ")
            let penalties = markerCount(
                in: opening,
                markers: ["um", "uh", "well", "so", "maybe", "perhaps", "i think", "i guess", "kind of", "sort of"]
            )
            return (100 - penalties * 14).clamped(to: 0...100)
        case .closing:
            let closing = Array(tokens.suffix(18)).joined(separator: " ")
            let penalties = markerCount(
                in: closing,
                markers: ["um", "uh", "maybe", "i think", "i guess", "kind of", "sort of", "so yeah", "that's it"]
            )
            let decisiveEnding = ["today", "now", "next", "approve", "decide", "recommend", "because"]
                .contains(tokens.last ?? "")
            return (86 - penalties * 14 + (decisiveEnding ? 14 : 0)).clamped(to: 0...100)
        case .structure:
            let normalized = tokens.joined(separator: " ")
            let signposts = markerCount(
                in: normalized,
                markers: ["first", "second", "third", "because", "therefore", "however", "for example", "the point", "next", "finally"]
            )
            return min(100, signposts * 20)
        case .concise:
            // A bounded inverse length signal. Meaning preservation is gated
            // separately, so shorter can only count when the retry still
            // overlaps the source's meaning-bearing vocabulary.
            return (100 - min(90, max(0, tokens.count - 8) * 2)).clamped(to: 0...100)
        }
    }

    private static func markerCount(in normalizedText: String, markers: [String]) -> Int {
        let padded = " \(normalizedText) "
        return markers.reduce(into: 0) { count, marker in
            var searchStart = padded.startIndex
            let needle = " \(marker) "
            while let range = padded.range(of: needle, range: searchStart..<padded.endIndex) {
                count += 1
                searchStart = range.upperBound
            }
        }
    }

    private static func words(in text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber && $0 != "'" }
            .map(String.init)
    }

    private static func contentWords(in text: String) -> Set<String> {
        Set(words(in: text).filter { word in
            word.count > 2 && !stopWords.contains(word)
        })
    }

    private static func diceOverlap(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        return Double(lhs.intersection(rhs).count * 2) / Double(lhs.count + rhs.count)
    }

    private static let stopWords: Set<String> = [
        "and", "are", "but", "for", "from", "have", "into", "just", "that", "the", "their",
        "then", "there", "they", "this", "was", "were", "what", "when", "where", "which",
        "with", "would", "you", "your"
    ]
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, *)
struct TranscriptRetryComparisonCard: View {
    let outcome: RecommendationOutcome
    let sourceSession: PracticeSession?
    let retrySession: PracticeSession
    let intervention: CoachIntervention?

    private var comparison: TranscriptRetryComparison? {
        outcome.transcriptRetryComparison
    }

    private var result: TranscriptRetryResult {
        comparison?.result ?? .needsMoreEvidence
    }

    private var lever: TranscriptPracticeLever {
        outcome.transcriptRetryTarget?.lever
            ?? comparison?.lever
            ?? .structure
    }

    private var resultTitle: String {
        switch result {
        case .improved: return "The target moved"
        case .held: return "The target held"
        case .regressed: return "The target moved back"
        case .needsMoreEvidence: return "Comparison needs another rep"
        }
    }

    private var resultDetail: String {
        switch result {
        case .improved:
            return "Your \(lever.focusLabel) was stronger than in the verified source rep. One retry is promising, not proof."
        case .held:
            return "Your \(lever.focusLabel) stayed close to the source rep. Keep the next change narrow."
        case .regressed:
            return "Your \(lever.focusLabel) weakened on this attempt. Noum will diagnose before repeating the same wording."
        case .needsMoreEvidence:
            return "The retry was too short, low-confidence, or changed too much of the meaning for a fair lever comparison."
        }
    }

    private var tint: Color {
        switch result {
        case .improved: return AppColor.positive
        case .held: return AppColor.brandBlue
        case .regressed, .needsMoreEvidence: return AppColor.caution
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TARGETED RETRY")
                        .font(Typography.micro.weight(.heavy))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    Text(resultTitle)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                }
            }

            Text(outcome.target ?? lever.successMeasure)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 7)
                .background(tint.opacity(0.10), in: Capsule())

            if let sourceSession {
                comparisonRung(
                    label: "VERIFIED SOURCE REP",
                    text: Text(AIRewriteService.originalSnippet(
                        transcript: sourceSession.transcript,
                        weakness: lever.weakness
                    ))
                )
                comparisonRung(
                    label: "YOUR RETRY",
                    text: TranscriptChangeHighlighter.highlightedText(
                        original: AIRewriteService.originalSnippet(
                            transcript: sourceSession.transcript,
                            weakness: lever.weakness
                        ),
                        revision: AIRewriteService.originalSnippet(
                            transcript: retrySession.transcript,
                            weakness: lever.weakness
                        )
                    )
                )
            }

            Text(resultDetail)
                .font(Typography.body)
                .foregroundStyle(.secondary)

            if let intervention,
               intervention.mode == outcome.mode,
               intervention.focus == outcome.focus {
                VStack(alignment: .leading, spacing: 3) {
                    Text("HOW NOUM ADAPTED")
                        .font(Typography.micro.weight(.heavy))
                        .foregroundStyle(.secondary)
                    Text(intervention.reviewBasis)
                        .font(Typography.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("transcriptRetry.comparison")
    }

    private func comparisonRung(label: String, text: Text) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typography.micro.weight(.heavy))
                .foregroundStyle(.secondary)
            text
                .font(Typography.caption.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }
}
#endif
