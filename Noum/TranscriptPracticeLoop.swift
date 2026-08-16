import Foundation

/// Renders rep durations in the honest-ledger `m:ss` format the design system
/// uses everywhere ("VERIFIED 0:48", "FIRST TRY · 0:48"). One owner so the
/// clock reads identically across Review, History and Comparison.
enum RepDurationLabel {
    nonisolated static func mss(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}

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

/// Source-bound copy for the page-19 C1 → C2 result beat. The milestone is
/// only available for a verified improved retry; it never invents a win from
/// score, duration, or a generic completion event.
struct TranscriptRetryMilestonePresentation: Identifiable, Equatable {
    let id: UUID
    let headline: String
    let detail: String

    static func make(
        outcome: RecommendationOutcome,
        sourceSession: PracticeSession?,
        retrySession: PracticeSession,
        priorHolds: Int
    ) -> TranscriptRetryMilestonePresentation? {
        guard outcome.isVerifiedFollowed,
              outcome.mode == .timed,
              retrySession.mode == .timed,
              outcome.sessionID == retrySession.id,
              let target = outcome.transcriptRetryTarget,
              target.isSupported,
              let sourceSession,
              outcome.sourceSessionID == sourceSession.id,
              let comparison = outcome.transcriptRetryComparison,
              comparison.isComparable,
              comparison.result == .improved,
              (comparison.retrySignal - comparison.sourceSignal) >= TranscriptRetryComparator.meaningfulSignalMovement,
              comparison.meaningOverlapPercent >= Int(
                (TranscriptRetryComparator.minimumMeaningOverlap * 100).rounded()
              ),
              comparison.lever == target.lever,
              comparison.sourceSessionID == sourceSession.id,
              comparison.retrySessionID == retrySession.id else {
            return nil
        }

        let lever = target.lever
        let underPressure: Bool
        switch retrySession.practiceDemand?.timedDifficulty {
        case .medium, .hard:
            underPressure = true
        default:
            underPressure = false
        }

        let isFirstHold = priorHolds == 0
        let headline: String
        switch (isFirstHold, underPressure) {
        case (true, true): headline = String(localized: "First hold under pressure")
        case (true, false): headline = String(localized: "First hold")
        case (false, true): headline = String(localized: "Held again under pressure")
        case (false, false): headline = String(localized: "The target moved")
        }

        // Transcript comparison verifies movement in the prescribed lever;
        // whole-rep duration cannot prove when the answer itself landed.
        let detail = String(
            localized: "Your \(lever.focusLabel) was stronger on this retry."
        )

        return TranscriptRetryMilestonePresentation(
            id: outcome.id,
            headline: headline,
            detail: detail
        )
    }
}

/// Full-screen earned beat between a verified retry and its evidence card.
/// This is the production translation of Figma D3: an explicit reward stack
/// (character reaction, real XP when present, source-bound evidence, receipt,
/// then continue) rather than an abstract report transition. Nothing shown here
/// is inferred from chrome: the presentation has already passed the strict
/// retry truth gate, and optional progress is supplied by Summary's exact rep.
@available(iOS 17.0, *)
struct TranscriptRetryMilestoneView: View {
    let presentation: TranscriptRetryMilestonePresentation
    var earnedXP: Int = 0
    var unlockedNextStep = false
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var evidenceFocused: Bool
    @State private var characterPhase = RetryRewardCharacterPhase.anticipation
    @State private var headlineVisible = false
    @State private var haloVisible = false
    @State private var confettiActive = false
    @State private var rewardVisible = false
    @State private var evidenceVisible = false
    @State private var receiptsVisible = false
    @State private var actionVisible = false
    @State private var contentVisible = true
    @State private var canContinue = false
    @State private var hasStarted = false
    @State private var hasFinished = false
    @State private var didFireEvidenceFeedback = false
    @State private var wasInterrupted = false
    @State private var playbackTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 244 / 255, green: 238 / 255, blue: 255 / 255),
                    Color(red: 234 / 255, green: 244 / 255, blue: 255 / 255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            decorativeBackdrop

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    characterStage
                    rewardPill
                    evidenceCard
                    receiptRow
                }
                .frame(maxWidth: 430)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 104)
            }
            .opacity(contentVisible ? 1 : 0)
            .accessibilityHidden(!contentVisible)

            ConfettiLayer(
                active: confettiActive,
                pieceCount: RetryRewardBeat.confettiPieces,
                duration: 1.35
            )
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            continueButton
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
        }
        .onAppear(perform: play)
        .onDisappear {
            playbackTask?.cancel()
            if !hasFinished { wasInterrupted = true }
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
        .onChange(of: reduceMotion) { _, _ in
            handleMotionPreferenceChange()
        }
        .preferredColorScheme(.light)
        .accessibilityIdentifier("transcriptRetry.milestone")
    }

    private var decorativeBackdrop: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(Color(red: 209 / 255, green: 133 / 255, blue: 255 / 255).opacity(0.18))
                    .frame(width: 310, height: 310)
                    .position(x: 78, y: 24)
                Circle()
                    .fill(AppColor.brandBlueLight.opacity(0.14))
                    .frame(width: 240, height: 240)
                    .position(x: geometry.size.width - 30, y: 128)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("REP COMPLETE")
                .font(Typography.figtree(size: 12, weight: .bold, relativeTo: .caption))
                .foregroundStyle(rewardPurple)
                .tracking(0.5)

            Text("THAT LANDED.")
                .font(Typography.figtree(size: 36, weight: .heavy, relativeTo: .largeTitle))
                .foregroundStyle(rewardInk)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.78)
                .opacity(headlineVisible ? 1 : 0)
                .offset(y: headlineVisible ? 0 : 14)
                .scaleEffect(headlineVisible ? 1 : 0.93)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityHidden(!headlineVisible)
    }

    private var characterStage: some View {
        ZStack {
            ZStack {
                Circle()
                    .fill(rewardGold.opacity(0.16))
                    .frame(width: 230, height: 205)
                Circle()
                    .fill(Color(red: 209 / 255, green: 133 / 255, blue: 255 / 255).opacity(0.18))
                    .frame(width: 178, height: 158)
                Circle()
                    .fill(Color.white.opacity(0.56))
                    .frame(width: 124, height: 112)
            }
            .scaleEffect(haloVisible ? 1 : 0.35)
            .opacity(haloVisible ? 1 : 0)

            RetryRewardCompanion(phase: characterPhase)
        }
        .frame(height: 188)
        .accessibilityHidden(true)
    }

    private var rewardPill: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 199 / 255, green: 123 / 255, blue: 0))
                .offset(y: 8)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1, green: 232 / 255, blue: 115 / 255), rewardGold],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.brown.opacity(0.18), radius: 14, y: 8)

            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.76))
                    Image(systemName: "sparkles")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(Color(red: 182 / 255, green: 107 / 255, blue: 0))
                }
                .frame(width: 42, height: 42)

                VStack(spacing: 0) {
                    Text(rewardTitle)
                        .font(Typography.figtree(size: 25, weight: .heavy, relativeTo: .title2))
                        .foregroundStyle(Color(red: 109 / 255, green: 67 / 255, blue: 0))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(
                        earnedXP > 0
                            ? String(localized: "EARNED")
                            : String(localized: "EVIDENCE SAVED")
                    )
                        .font(Typography.figtree(size: 9, weight: .bold, relativeTo: .caption2))
                        .foregroundStyle(Color(red: 109 / 255, green: 67 / 255, blue: 0))
                        .tracking(0.4)
                }
                .frame(minWidth: 102)
            }
            .padding(.horizontal, 16)
        }
        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 193)
        .frame(minHeight: 76)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
        .opacity(rewardVisible ? 1 : 0)
        .offset(y: rewardVisible ? 0 : 28)
        .scaleEffect(rewardVisible ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityHidden(!rewardVisible)
    }

    private var evidenceCard: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(rewardLime)
                .frame(width: 7)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle().fill(rewardLime.opacity(0.2))
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(AppColor.positive)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(presentation.headline.uppercased())
                            .font(Typography.figtree(size: 10, weight: .bold, relativeTo: .caption))
                            .foregroundStyle(Color(red: 51 / 255, green: 116 / 255, blue: 25 / 255))
                            .tracking(0.35)
                        Text(presentation.detail)
                            .font(Typography.figtree(size: 18, weight: .heavy, relativeTo: .headline))
                            .foregroundStyle(rewardInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("SAME TARGET  →  STRONGER RETRY")
                    .font(Typography.figtree(size: 9, weight: .bold, relativeTo: .caption2))
                    .foregroundStyle(Color(red: 109 / 255, green: 90 / 255, blue: 145 / 255))
                    .tracking(0.3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color(red: 244 / 255, green: 241 / 255, blue: 250 / 255))
                    )
            }
            .padding(16)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: rewardPurple.opacity(0.10), radius: 18, y: 7)
        .opacity(evidenceVisible ? 1 : 0)
        .offset(y: evidenceVisible ? 0 : 30)
        .accessibilityElement(children: .combine)
        .accessibilityHidden(!evidenceVisible)
        .accessibilityFocused($evidenceFocused)
    }

    private var receiptRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) { receiptTiles }
            } else {
                HStack(spacing: 12) { receiptTiles }
            }
        }
        .opacity(receiptsVisible ? 1 : 0)
        .offset(y: receiptsVisible ? 0 : 20)
        .scaleEffect(receiptsVisible ? 1 : 0.88)
        .accessibilityHidden(!receiptsVisible)
    }

    @ViewBuilder
    private var receiptTiles: some View {
        Group {
            receiptTile(
                icon: "checkmark.seal.fill",
                iconColor: AppColor.positive,
                colors: [
                    Color(red: 1, green: 244 / 255, blue: 229 / 255),
                    Color(red: 1, green: 229 / 255, blue: 195 / 255)
                ],
                value: "VERIFIED",
                label: "SOURCE MATCH"
            )

            receiptTile(
                icon: unlockedNextStep ? "lock.open.fill" : "brain.head.profile",
                iconColor: AppColor.brandBlue,
                colors: [
                    Color(red: 233 / 255, green: 242 / 255, blue: 1),
                    Color(red: 229 / 255, green: 228 / 255, blue: 1)
                ],
                value: unlockedNextStep ? "NEXT STEP" : "COACH MEMORY",
                label: unlockedNextStep ? "UNLOCKED" : "SAVED"
            )
        }
    }

    private func receiptTile(
        icon: String,
        iconColor: Color,
        colors: [Color],
        value: LocalizedStringKey,
        label: LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(iconColor)
            Text(value)
                .font(Typography.figtree(size: 15, weight: .heavy, relativeTo: .headline))
                .foregroundStyle(rewardInk)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.7)
            Text(label)
                .font(Typography.figtree(size: 9, weight: .bold, relativeTo: .caption2))
                .foregroundStyle(rewardInk.opacity(0.74))
                .tracking(0.35)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: iconColor.opacity(0.10), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
    }

    private var continueButton: some View {
        Button(action: continueToEvidence) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 79 / 255, green: 34 / 255, blue: 158 / 255))
                    .offset(y: 7)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppColor.brandBlue, rewardPurple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: rewardPurple.opacity(0.20), radius: 12, y: 7)
                Text("CONTINUE TO EVIDENCE")
                    .font(Typography.figtree(size: 16, weight: .heavy, relativeTo: .headline))
                    .foregroundStyle(Color.white)
                    .tracking(0.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .frame(height: 58)
        }
        .buttonStyle(.pressable)
        .disabled(!canContinue)
        .opacity(actionVisible ? 1 : 0.34)
        .scaleEffect(actionVisible ? 1 : 0.98)
        .accessibilityHint("Opens your verified retry evidence.")
        .accessibilityHidden(!actionVisible || !contentVisible)
        .accessibilityIdentifier("transcriptRetry.continueToEvidence")
    }

    private var rewardTitle: String {
        earnedXP > 0
            ? String(localized: "+\(earnedXP) XP")
            : String(localized: "Coach win")
    }

    private var rewardPurple: Color {
        Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255)
    }

    private var rewardGold: Color {
        Color(red: 1, green: 200 / 255, blue: 74 / 255)
    }

    private var rewardLime: Color {
        Color(red: 155 / 255, green: 227 / 255, blue: 90 / 255)
    }

    private var rewardInk: Color {
        Color(red: 23 / 255, green: 32 / 255, blue: 51 / 255)
    }

    private func play() {
        if hasStarted {
            if wasInterrupted, scenePhase == .active { settleAfterInterruption() }
            return
        }
        hasStarted = true
        playbackTask = Task { @MainActor in
            guard await wait(RetryRewardBeat.startDelay) else { return }
            guard scenePhase == .active else {
                wasInterrupted = true
                return
            }
            if reduceMotion {
                await playReducedMotion()
            } else {
                await playCelebration()
            }
        }
    }

    @MainActor
    private func playReducedMotion() async {
        settleToFinalFrame(contentVisible: false)
        withAnimation(.easeInOut(duration: RetryRewardBeat.reducedMotionReveal)) {
            contentVisible = true
        }
        guard await wait(RetryRewardBeat.reducedMotionReveal) else { return }
        fireEvidenceFeedbackIfNeeded()
        canContinue = true
        evidenceFocused = true
    }

    @MainActor
    private func playCelebration() async {
        withAnimation(.easeOut(duration: RetryRewardBeat.headlineReveal)) {
            headlineVisible = true
        }
        withAnimation(.easeInOut(duration: RetryRewardBeat.characterSquash)) {
            characterPhase = .squash
        }

        guard await wait(RetryRewardBeat.characterSquash) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.58)) {
            characterPhase = .jump
        }

        guard await wait(RetryRewardBeat.characterJump) else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
            haloVisible = true
        }
        confettiActive = true

        guard await wait(RetryRewardBeat.burstToReward) else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.58)) {
            characterPhase = .settled
            rewardVisible = true
        }
        fireEvidenceFeedbackIfNeeded()

        guard await wait(RetryRewardBeat.rewardToEvidence) else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            evidenceVisible = true
        }
        evidenceFocused = true

        guard await wait(RetryRewardBeat.evidenceToReceipts) else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.70)) {
            receiptsVisible = true
        }

        guard await wait(RetryRewardBeat.receiptsToAction) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            actionVisible = true
        }
        canContinue = true
    }

    private func fireEvidenceFeedbackIfNeeded() {
        guard !didFireEvidenceFeedback else { return }
        didFireEvidenceFeedback = true
        CoachHaptic.earnedEvidence()
        InteractionSoundEngine.cue(.verdictReveal)
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        guard hasStarted, !hasFinished else { return }
        if phase != .active {
            playbackTask?.cancel()
            playbackTask = nil
            wasInterrupted = true
        } else if wasInterrupted {
            settleAfterInterruption()
        }
    }

    private func handleMotionPreferenceChange() {
        guard hasStarted, !hasFinished else { return }
        playbackTask?.cancel()
        settleAfterInterruption()
    }

    private func settleAfterInterruption() {
        wasInterrupted = false
        settleToFinalFrame(contentVisible: true)
        fireEvidenceFeedbackIfNeeded()
        canContinue = true
        evidenceFocused = true
    }

    private func settleToFinalFrame(contentVisible: Bool) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            characterPhase = .settled
            headlineVisible = true
            haloVisible = true
            confettiActive = false
            rewardVisible = true
            evidenceVisible = true
            receiptsVisible = true
            actionVisible = true
            self.contentVisible = contentVisible
        }
    }

    @MainActor
    private func wait(_ duration: TimeInterval) async -> Bool {
        do {
            try await Task.sleep(
                nanoseconds: UInt64(max(0, duration) * 1_000_000_000)
            )
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    private func continueToEvidence() {
        guard canContinue, !hasFinished else { return }
        hasFinished = true
        playbackTask?.cancel()
        CoachHaptic.selectionTap()
        onContinue()
    }
}

private enum RetryRewardCharacterPhase {
    case anticipation
    case squash
    case jump
    case settled

    var xScale: CGFloat {
        switch self {
        case .anticipation: return 1.04
        case .squash: return 1.08
        case .jump: return 0.96
        case .settled: return 1
        }
    }

    var yScale: CGFloat {
        switch self {
        case .anticipation: return 0.92
        case .squash: return 0.90
        case .jump: return 1.10
        case .settled: return 1
        }
    }

    var yOffset: CGFloat {
        switch self {
        case .anticipation: return 4
        case .squash: return 8
        case .jump: return -24
        case .settled: return 0
        }
    }
}

private struct RetryRewardCompanion: View {
    let phase: RetryRewardCharacterPhase

    var body: some View {
        ZStack {
            arm(rotation: 42)
                .offset(x: -73, y: -32)
            arm(rotation: -42)
                .offset(x: 73, y: -32)

            RetryRewardSpeechTail()
                .fill(Color(red: 84 / 255, green: 33 / 255, blue: 162 / 255))
                .frame(width: 38, height: 33)
                .offset(x: -43, y: 52)

            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColor.brandBlueLight,
                            Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255),
                            Color(red: 84 / 255, green: 33 / 255, blue: 162 / 255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 46, style: .continuous)
                        .stroke(Color.white.opacity(0.38), lineWidth: 2)
                }
                .frame(width: 169, height: 124)

            crest
                .offset(x: -32, y: -69)

            HStack(spacing: 23) {
                RetryRewardHappyEye()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                RetryRewardHappyEye()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
            .frame(width: 104, height: 24)
            .offset(y: -17)

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color(red: 42 / 255, green: 23 / 255, blue: 79 / 255))
                    .frame(width: 40, height: 33)
                Capsule()
                    .fill(Color(red: 1, green: 122 / 255, blue: 154 / 255))
                    .frame(width: 23, height: 10)
                    .offset(y: -3)
            }
            .offset(y: 28)

            HStack(spacing: 24) {
                Capsule().fill(Color(red: 78 / 255, green: 32 / 255, blue: 153 / 255))
                Capsule().fill(Color(red: 78 / 255, green: 32 / 255, blue: 153 / 255))
            }
            .frame(width: 87, height: 16)
            .offset(y: 68)
        }
        .frame(width: 190, height: 170)
        .scaleEffect(x: phase.xScale, y: phase.yScale, anchor: .center)
        .offset(y: phase.yOffset)
    }

    private var crest: some View {
        HStack(alignment: .bottom, spacing: 5) {
            Capsule()
                .fill(Color(red: 209 / 255, green: 133 / 255, blue: 255 / 255))
                .frame(width: 10, height: 23)
            Capsule()
                .fill(Color(red: 1, green: 200 / 255, blue: 74 / 255))
                .frame(width: 10, height: 32)
            Capsule()
                .fill(AppColor.brandBlueLight)
                .frame(width: 10, height: 21)
        }
    }

    private func arm(rotation: Double) -> some View {
        Capsule()
            .fill(Color(red: 108 / 255, green: 85 / 255, blue: 219 / 255))
            .frame(width: 42, height: 12)
            .rotationEffect(.degrees(rotation))
    }
}

private struct RetryRewardHappyEye: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return path
    }
}

private struct RetryRewardSpeechTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.28, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

@available(iOS 17.0, *)
struct TranscriptRetryComparisonCard: View {
    let outcome: RecommendationOutcome
    let sourceSession: PracticeSession?
    let retrySession: PracticeSession
    let intervention: CoachIntervention?
    /// Holds and tries for this lever BEFORE this retry (from the
    /// recommendation ledger). Nil hides the tally sentence — never fabricate.
    var priorHolds: Int? = nil
    var priorTries: Int? = nil
    /// The next prescribed answer clock in seconds, when a recommendation
    /// exists. Nil hides the "Next:" sentence.
    var nextClockSeconds: Int? = nil
    /// The full-screen milestone owns the improved-result haptic when shown;
    /// history/reopened cards keep the existing inline feedback by default.
    var playsPayoffFeedback: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// One-shot entrance guard keyed on the outcome identity — Summary can
    /// re-resolve on sheet/dialog round-trips, so bare `onAppear` would
    /// replay the payoff beat (same idiom as `MiniDrillResultView`'s
    /// `hasRunEntrance`, hardened against outcome re-resolution).
    @State private var enteredOutcomeID: UUID?
    @State private var cardSettled = false
    @State private var payoffLanded = false
    /// One restrained expansion pulse on the payoff row — improved only,
    /// fired on the same settle frame as the earnedEvidence haptic so the
    /// felt and seen beats are one moment. Never loops, never on held/
    /// regressed, skipped under Reduce Motion.
    @State private var payoffPulse = false
    /// Trigger for the one-shot changed-word brighten wave; never toggled
    /// under Reduce Motion (the static highlight is the RM presentation).
    @State private var waveTrigger = false

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

    /// Seconds the retry landed earlier than the verified source rep,
    /// computed directly on the pair (never the rolling-average delta).
    /// Nil below a 3s floor — small differences are noise, not a claim.
    private var secondsEarlier: Int? {
        guard let sourceSession else { return nil }
        let delta = sourceSession.duration - retrySession.duration
        guard delta >= 3 else { return nil }
        return Int(delta.rounded())
    }

    /// True when the retry ran on a compressed answer clock — the design's
    /// own ledger meaning of "under pressure" (medium/hard = 30s/15s).
    private var retryWasUnderPressure: Bool {
        switch retrySession.practiceDemand?.timedDifficulty {
        case .medium, .hard: return true
        default: return false
        }
    }

    /// The earned-progress line, first and green (frozen design: the win
    /// lands before any explanation). Founder template, real data only —
    /// each clause renders only when its evidence exists.
    private var payoffLine: String? {
        guard result == .improved else { return nil }
        var line = (priorHolds ?? 0) == 0 ? "First hold" : "Held again"
        if retryWasUnderPressure { line += " under pressure" }
        if let secondsEarlier { line += " — answer landed \(secondsEarlier)s earlier" }
        return line + "."
    }

    /// "Three holds in four tries. Next: a 45-second answer clock."
    /// Tally counts this attempt; both sentences self-suppress without data.
    private var planLine: String? {
        var sentences: [String] = []
        if let priorHolds, let priorTries {
            let holds = priorHolds + (result == .improved || result == .held ? 1 : 0)
            let tries = priorTries + 1
            sentences.append("\(Self.spelled(holds).capitalized) hold\(holds == 1 ? "" : "s") in \(Self.spelled(tries)) tr\(tries == 1 ? "y" : "ies").")
        }
        if let nextClockSeconds {
            sentences.append("Next: a \(nextClockSeconds)-second answer clock.")
        }
        return sentences.isEmpty ? nil : sentences.joined(separator: " ")
    }

    private static func spelled(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six",
                     "seven", "eight", "nine", "ten", "eleven", "twelve"]
        return n >= 0 && n < words.count ? words[n] : String(n)
    }

    private func rungLabel(_ prefix: String, session: PracticeSession?) -> String {
        guard let session else { return prefix }
        return "\(prefix) · \(RepDurationLabel.mss(session.duration))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SAME TARGET · TWO TRIES")
                        .font(Typography.micro.weight(.heavy))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    Text(resultTitle)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                }
            }

            if let payoffLine {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .accessibilityHidden(true)
                    Text(payoffLine)
                        .font(Typography.headline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(AppColor.positive)
                .opacity(payoffLanded ? 1 : 0)
                .scaleEffect(payoffLanded ? 1 : 0.94, anchor: .leading)
                .scaleEffect(payoffPulse ? 1.045 : 1, anchor: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("transcriptRetry.payoff")
            }

            // The capsule shares the payoff beat's transaction so the
            // settle-frame completion (haptic timing) is anchored to a real
            // animation for every result, including ones without a payoff row.
            Text(outcome.target ?? lever.successMeasure)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 7)
                .background(tint.opacity(payoffLanded ? 0.10 : 0.04), in: Capsule())

            if let sourceSession {
                let sourceSnippet = AIRewriteService.originalSnippet(
                    transcript: sourceSession.transcript,
                    weakness: lever.weakness
                )
                let retrySnippet = AIRewriteService.originalSnippet(
                    transcript: retrySession.transcript,
                    weakness: lever.weakness
                )
                comparisonRung(
                    label: rungLabel("FIRST TRY", session: sourceSession),
                    text: Text(sourceSnippet)
                        .foregroundColor(AppColor.neutralReceded),
                    dominant: false
                )
                comparisonRung(
                    label: rungLabel("RETRY", session: retrySession),
                    text: TranscriptChangeHighlighter.highlightedText(
                        original: sourceSnippet,
                        revision: retrySnippet
                    ),
                    dominant: true,
                    wave: (original: sourceSnippet, revision: retrySnippet)
                )
            }

            Text(resultDetail)
                .font(Typography.body)
                .foregroundStyle(.secondary)

            if let planLine {
                Text(planLine)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityIdentifier("transcriptRetry.plan")
            }

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
        // Entrance pre-state stays visible (0.85/0.98) so existence and
        // hittability are never delayed past first layout — the comparison
        // identifier and "The target moved" are UI-test pinned.
        .opacity(cardSettled ? 1 : 0.85)
        .scaleEffect(cardSettled ? 1 : 0.98)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("transcriptRetry.comparison")
        .onAppear(perform: runEntrance)
        .onChange(of: outcome.id) { _, _ in runEntrance() }
    }

    /// Entrance choreography, keyed on the outcome identity: the card
    /// settles in, then the payoff beat lands one `payoffRevealDuration`
    /// after it. The result haptic fires on the beat's settle frame —
    /// `improved` gets the positive-shift pulse, `held` a gentle ack, and
    /// `regressed`/`needsMoreEvidence` stay silent (never punish). Under
    /// Reduce Motion the whole card resolves in a single fade and the
    /// haptic still fires — haptics are the RM user's feedback channel.
    private func runEntrance() {
        guard enteredOutcomeID != outcome.id else { return }
        enteredOutcomeID = outcome.id
        if reduceMotion {
            withAnimation(.v46ReduceMotionFade) {
                cardSettled = true
                payoffLanded = true
            }
            fireResultHaptic()
            return
        }
        withAnimation(.settle) { cardSettled = true }
        withAnimation(
            Animation.payoffReveal.delay(Animation.payoffRevealDuration),
            completionCriteria: .logicallyComplete
        ) {
            payoffLanded = true
        } completion: {
            fireResultHaptic()
            if result == .improved || result == .held {
                waveTrigger.toggle()
            }
            if result == .improved {
                // The one visual pulse, paired with the two-beat haptic.
                withAnimation(NoumMotion.earnedProgress) { payoffPulse = true }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    withAnimation(NoumMotion.earnedProgress) { payoffPulse = false }
                }
            }
        }
    }

    private func fireResultHaptic() {
        guard playsPayoffFeedback else { return }
        switch result {
        case .improved: CoachHaptic.earnedEvidence()
        case .held: CoachHaptic.drillIncomplete()
        case .regressed, .needsMoreEvidence: break
        }
    }

    /// Frozen design: the first try recedes, the retry leads. Dominance is
    /// carried by fill + border + text colour, never by hiding the original.
    /// `wave` (retry rung only) supplies the snippet pair for the one-shot
    /// changed-word brighten wave layered over the static highlight.
    private func comparisonRung(
        label: String,
        text: Text,
        dominant: Bool,
        wave: (original: String, revision: String)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typography.micro.weight(.heavy))
                .foregroundStyle(dominant ? AppColor.proText : AppColor.neutralReceded)
            text
                .font(dominant ? Typography.body.weight(.semibold) : Typography.caption.weight(.medium))
                .foregroundStyle(dominant ? AppColor.textPrimary : AppColor.neutralReceded)
                .fixedSize(horizontal: false, vertical: true)
                .overlay(alignment: .topLeading) {
                    if let wave {
                        changedWordWave(original: wave.original, revision: wave.revision)
                    }
                }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            dominant ? AppColor.proQuietSurface : AppColor.tagBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(dominant ? AppColor.pro.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }

    /// Decorative one-shot brighten wave over the retry rung: each changed
    /// word briefly brightens in reading order on the `coachLineStagger`
    /// cadence, then recedes to the static highlight. Purely additive — the
    /// base `highlightedText` underneath stays the authoritative (and RM)
    /// presentation, and the layers are hidden from accessibility. The
    /// trigger only ever toggles outside Reduce Motion, so the phase
    /// animator rests at opacity 0 (no motion, no loop) for RM users.
    private func changedWordWave(original: String, revision: String) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(
                Array(Self.waveLayers(original: original, revision: revision).enumerated()),
                id: \.offset
            ) { index, layer in
                layer
                    // Mirrors the dominant rung's text styling exactly so the
                    // overlay lays out glyph-identical to the base highlight.
                    .font(Typography.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .brightness(0.25)
                    .phaseAnimator([0.0, 1.0], trigger: waveTrigger) { view, phase in
                        view.opacity(phase)
                    } animation: { _ in
                        .coachLineStagger(index)
                    }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// Salience cap for the brighten wave — beyond this the wave stops
    /// reading as emphasis and starts reading as decoration.
    private static let waveWordCap = 6

    /// Mirrors `TranscriptChangeHighlighter`'s word tokenisation (same
    /// pattern) so wave layers land on the same words the static highlight
    /// marks. Drift would only mute the decorative wave — the highlight
    /// underneath remains authoritative.
    private static let waveWordRegex = try! NSRegularExpression(
        pattern: #"[\p{L}\p{N}'’-]+"#
    )

    /// One overlay layer per changed word (capped): the full revision string
    /// rendered with every glyph clear except that word, styled exactly like
    /// the base highlight's changed words so each layer wraps identically
    /// and the visible word sits pixel-aligned over its static counterpart.
    private static func waveLayers(original: String, revision: String) -> [Text] {
        let nsRevision = revision as NSString
        let matches = waveWordRegex.matches(
            in: revision,
            range: NSRange(location: 0, length: nsRevision.length)
        )
        let changed = TranscriptChangeHighlighter.changedWordIndexes(
            original: original,
            revision: revision
        )
        let emphasized = matches.indices.filter(changed.contains).prefix(waveWordCap)
        return emphasized.map { emphasisIndex in
            var rendered = Text("")
            var cursor = 0
            for (index, match) in matches.enumerated() {
                if match.range.location > cursor {
                    rendered = rendered + Text(nsRevision.substring(
                        with: NSRange(location: cursor, length: match.range.location - cursor)
                    )).foregroundColor(.clear)
                }
                let token = Text(nsRevision.substring(with: match.range))
                if changed.contains(index) {
                    // Keep the base's bold on every changed word (clear or
                    // not) — metrics must match the highlight underneath.
                    rendered = rendered + token
                        .foregroundColor(index == emphasisIndex ? AppColor.proText : .clear)
                        .bold()
                } else {
                    rendered = rendered + token.foregroundColor(.clear)
                }
                cursor = match.range.location + match.range.length
            }
            if cursor < nsRevision.length {
                rendered = rendered + Text(nsRevision.substring(from: cursor))
                    .foregroundColor(.clear)
            }
            return rendered
        }
    }
}
#endif
