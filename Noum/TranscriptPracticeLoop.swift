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

/// Revalidates a persisted comparison at the presentation boundary. The
/// comparator creates these fields together, but legacy/corrupt storage must
/// not be able to join one result to different source or retry transcripts.
enum TranscriptRetryComparisonQualification {
    static func resolve(
        outcome: RecommendationOutcome,
        sourceSession: PracticeSession?,
        retrySession: PracticeSession
    ) -> TranscriptRetryComparison? {
        guard outcome.isVerifiedFollowed,
              outcome.mode == .timed,
              retrySession.mode == .timed,
              outcome.sessionID == retrySession.id,
              PracticeProgressEligibility.qualifies(retrySession),
              let target = outcome.transcriptRetryTarget,
              target.isSupported,
              let sourceSession,
              PracticeProgressEligibility.qualifies(sourceSession),
              outcome.sourceSessionID == sourceSession.id,
              let comparison = outcome.transcriptRetryComparison,
              comparison.schemaVersion == TranscriptRetryComparison.schemaVersion,
              comparison.lever == target.lever,
              comparison.sourceSessionID == sourceSession.id,
              comparison.retrySessionID == retrySession.id,
              (0...100).contains(comparison.sourceSignal),
              (0...100).contains(comparison.retrySignal),
              (0...100).contains(comparison.meaningOverlapPercent),
              comparison.result == .needsMoreEvidence || (
                comparison.isComparable && resultMatchesPersistedSignals(comparison)
              ) else {
            return nil
        }
        return comparison
    }

    private static func resultMatchesPersistedSignals(
        _ comparison: TranscriptRetryComparison
    ) -> Bool {
        let delta = comparison.retrySignal - comparison.sourceSignal
        let hasMeaningFloor = comparison.meaningOverlapPercent >= Int(
            (TranscriptRetryComparator.minimumMeaningOverlap * 100).rounded()
        )
        guard hasMeaningFloor else { return false }
        switch comparison.result {
        case .improved:
            return delta >= TranscriptRetryComparator.meaningfulSignalMovement
        case .held:
            return abs(delta) < TranscriptRetryComparator.meaningfulSignalMovement
        case .regressed:
            return delta <= -TranscriptRetryComparator.meaningfulSignalMovement
        case .needsMoreEvidence:
            return true
        }
    }
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
              let comparison = TranscriptRetryComparisonQualification.resolve(
                outcome: outcome,
                sourceSession: sourceSession,
                retrySession: retrySession
              ),
              comparison.isComparable,
              comparison.result == .improved,
              (comparison.retrySignal - comparison.sourceSignal) >= TranscriptRetryComparator.meaningfulSignalMovement,
              comparison.meaningOverlapPercent >= Int(
                (TranscriptRetryComparator.minimumMeaningOverlap * 100).rounded()
              ),
              comparison.lever == target.lever else {
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
/// This is the production translation of Figma V2.1 F1: an explicit reward
/// stack (verification emblem, source-bound evidence, optional earned XP or
/// unlock, then one comparison action) rather than an abstract report
/// transition. Nothing shown here is inferred from chrome: the presentation
/// has already passed the strict retry truth gate, and optional progress is
/// supplied by Summary's exact rep.
@available(iOS 17.0, *)
struct TranscriptRetryMilestoneView: View {
    let presentation: TranscriptRetryMilestonePresentation
    var earnedXP: Int = 0
    var unlockedNextStep = false
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AccessibilityFocusState private var evidenceFocused: Bool
    @State private var emblemPhase = RetryRewardEmblemPhase.anticipation
    @State private var headlineVisible = false
    @State private var haloVisible = false
    @State private var particleBurstActive = false
    @State private var rewardVisible = false
    @State private var evidenceVisible = false
    @State private var nextStepVisible = false
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
            AppColor.screenBackground
                .ignoresSafeArea()

            decorativeBackdrop

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    verificationStage
                    if earnedXP > 0 {
                        rewardPill
                    }
                    evidenceCard
                    if unlockedNextStep {
                        nextStepStrip
                    }
                }
                .frame(maxWidth: 430)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 104)
            }
            .opacity(contentVisible ? 1 : 0)
            .accessibilityHidden(!contentVisible)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                continueButton
                Text("Review the evidence, then continue.")
                    .font(Typography.manrope(size: 11, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                    .opacity(actionVisible ? 1 : 0)
                    .accessibilityHidden(true)
            }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(AppColor.screenBackground.opacity(0.97))
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
        .accessibilityIdentifier("transcriptRetry.milestone")
    }

    private var decorativeBackdrop: some View {
        GeometryReader { geometry in
            ZStack {
                RadialGradient(
                    colors: [AppColor.coachAccent.opacity(0.10), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 135
                )
                    .frame(width: 270, height: 270)
                    .position(x: 52, y: -26)
                RadialGradient(
                    colors: [AppColor.brandBlueLight.opacity(0.09), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 105
                )
                    .frame(width: 210, height: 210)
                    .position(x: geometry.size.width + 14, y: 92)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Rep complete")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.coachAccentOnQuiet)

            Text("That landed.")
                .font(Typography.screenTitle)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(headlineVisible ? 1 : 0)
                .offset(y: headlineVisible ? 0 : 14)
                .scaleEffect(headlineVisible ? 1 : 0.93)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityHidden(!headlineVisible)
    }

    private var verificationStage: some View {
        ZStack {
            RadialGradient(
                colors: [AppColor.coachAccent.opacity(0.16), .clear],
                center: .center,
                startRadius: 8,
                endRadius: 112
            )
                .frame(width: 240, height: 190)
                .blur(radius: 8)
                .scaleEffect(haloVisible ? 1 : 0.88)
                .opacity(haloVisible ? 1 : 0)

            RetryRewardParticleBurst(active: particleBurstActive)

            NoumSemanticGraphic(
                role: .verifiedEvidence,
                tint: AppColor.coachAccent,
                size: 180
            )
                .shadow(
                    color: AppColor.coachAccent.opacity(0.24),
                    radius: 22,
                    y: 12
                )
                .scaleEffect(emblemPhase.scale)
                .rotationEffect(emblemPhase.rotation)
                .offset(y: emblemPhase.yOffset)
                .opacity(emblemPhase.opacity)
        }
        .frame(height: 190)
        .accessibilityHidden(true)
    }

    private var rewardPill: some View {
        NoumRewardPill(kind: .xp(earnedXP))
        .opacity(rewardVisible ? 1 : 0)
        .offset(y: rewardVisible ? 0 : 28)
        .scaleEffect(rewardVisible ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityHidden(!rewardVisible)
    }

    private var evidenceCard: some View {
        NoumEvidenceCard(
            status: .verified,
            title: presentation.headline,
            detail: presentation.detail,
            source: "Compared with the verified source rep. One retry is promising, not proof."
        )
        .opacity(evidenceVisible ? 1 : 0)
        .offset(y: evidenceVisible ? 0 : 30)
        .accessibilityElement(children: .combine)
        .accessibilityHidden(!evidenceVisible)
        .accessibilityFocused($evidenceFocused)
    }

    private var nextStepStrip: some View {
        NoumSurface(.standard) {
            Label {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Path milestone unlocked")
                        .font(Typography.headline)
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("See the comparison, then continue along your path.")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                NoumSemanticGraphic(
                    role: .nextStepUnlocked,
                    tint: AppColor.coachAccent,
                    size: NoumControlMetric.minimumTouchTarget
                )
                .accessibilityHidden(true)
            }
        }
        .opacity(nextStepVisible ? 1 : 0)
        .offset(y: nextStepVisible ? 0 : 12)
        .scaleEffect(nextStepVisible ? 1 : 0.98)
        .accessibilityElement(children: .combine)
        .accessibilityHidden(!nextStepVisible)
    }

    private var continueButton: some View {
        PrimaryCTA(
            "See the comparison",
            icon: "arrow.left.arrow.right",
            tint: AppColor.coachingInk,
            action: continueToEvidence
        )
        .disabled(!canContinue)
        .opacity(actionVisible ? 1 : 0.34)
        .scaleEffect(actionVisible ? 1 : 0.98)
        .accessibilityHint("Opens your verified retry evidence.")
        .accessibilityHidden(!actionVisible || !contentVisible)
        .accessibilityIdentifier("transcriptRetry.continueToEvidence")
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
        withAnimation(NoumMotion.animation(for: .calm, reduceMotion: false)) {
            headlineVisible = true
        }
        guard await wait(RetryRewardBeat.emblemHold) else { return }
        withAnimation(NoumMotion.animation(for: .earned, reduceMotion: false)) {
            emblemPhase = .lifted
        }

        guard await wait(RetryRewardBeat.emblemLift) else { return }
        withAnimation(NoumMotion.animation(for: .earned, reduceMotion: false)) {
            haloVisible = true
        }
        particleBurstActive = true

        guard await wait(RetryRewardBeat.burstToReward) else { return }
        withAnimation(NoumMotion.animation(for: .earned, reduceMotion: false)) {
            emblemPhase = .settled
            rewardVisible = earnedXP > 0
        }
        fireEvidenceFeedbackIfNeeded()

        if earnedXP > 0 {
            guard await wait(RetryRewardBeat.rewardToEvidence) else { return }
        }
        withAnimation(NoumMotion.animation(for: .earned, reduceMotion: false)) {
            evidenceVisible = true
        }
        evidenceFocused = true

        if unlockedNextStep {
            guard await wait(RetryRewardBeat.evidenceToNextStep) else { return }
            withAnimation(NoumMotion.animation(for: .earned, reduceMotion: false)) {
                nextStepVisible = true
            }
        }

        guard await wait(RetryRewardBeat.nextStepToAction) else { return }
        withAnimation(NoumMotion.animation(for: .calm, reduceMotion: false)) {
            actionVisible = true
            canContinue = true
        }
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
            emblemPhase = .settled
            headlineVisible = true
            haloVisible = true
            particleBurstActive = false
            rewardVisible = earnedXP > 0
            evidenceVisible = true
            nextStepVisible = unlockedNextStep
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

private enum RetryRewardEmblemPhase: Equatable {
    case anticipation
    case lifted
    case settled

    var scale: CGFloat {
        switch self {
        case .anticipation: return 0.54
        case .lifted: return 1.08
        case .settled: return 1
        }
    }

    var yOffset: CGFloat {
        switch self {
        case .anticipation: return 20
        case .lifted: return -3
        case .settled: return 0
        }
    }

    var rotation: Angle {
        switch self {
        case .anticipation: return .degrees(-6)
        case .lifted, .settled: return .degrees(0)
        }
    }

    var opacity: Double {
        switch self {
        case .anticipation: return 0
        case .lifted, .settled: return 1
        }
    }
}

private struct RetryRewardParticleBurst: View {
    let active: Bool

    var body: some View {
        ZStack {
            ForEach(0..<RetryRewardBeat.celebrationParticles, id: \.self) { index in
                let endpoint = endpoint(for: index)
                particle(for: index)
                    .foregroundStyle(color(for: index))
                    .opacity(active ? opacity(for: index) : 0)
                    .scaleEffect(active ? 1 : 0.35)
                    .rotationEffect(.degrees(active ? angle(for: index) : angle(for: index) * 2.4))
                    .offset(
                        x: active ? endpoint.width : endpoint.width * 0.24,
                        y: active ? endpoint.height : endpoint.height * 0.24
                    )
                    .animation(
                        .spring(response: 0.40, dampingFraction: 0.62)
                            .delay(Double(index) * 0.02),
                        value: active
                    )
            }
        }
        .frame(width: 280, height: 190)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func particle(for index: Int) -> some View {
        switch index {
        case 0, 1:
            Image(systemName: "sparkle")
                .font(.system(size: index == 0 ? 22 : 18, weight: .bold))
        case 2, 4:
            Image(systemName: "diamond.fill")
                .font(.system(size: index == 2 ? 13 : 10, weight: .bold))
        case 3:
            Image(systemName: "star.fill")
                .font(.system(size: 13, weight: .bold))
        default:
            Image(systemName: "circle.fill")
                .font(.system(size: 9, weight: .bold))
        }
    }

    private func endpoint(for index: Int) -> CGSize {
        switch index {
        case 0: return CGSize(width: -112, height: -40)
        case 1: return CGSize(width: 112, height: -33)
        case 2: return CGSize(width: 118, height: 22)
        case 3: return CGSize(width: 88, height: -63)
        case 4: return CGSize(width: -110, height: 33)
        default: return CGSize(width: 105, height: 50)
        }
    }

    private func color(for index: Int) -> Color {
        switch index {
        case 0, 3: return AppColor.rewardGoldEnd
        case 1, 4: return AppColor.coachAccent
        default: return AppColor.brandBlueLight
        }
    }

    private func angle(for index: Int) -> Double {
        [12, -8, 22, -24, 17, -12][index]
    }

    private func opacity(for index: Int) -> Double {
        [1, 0.90, 0.85, 0.90, 0.80, 0.72][index]
    }
}

/// The comparison has two evidence roles, not two interchangeable audio clips.
/// Numbered markers make sequence and dominance legible without reusing the
/// waveform as generic decoration.
private enum RetryComparisonStage: Equatable {
    case source
    case retry

    var graphicRole: NoumSemanticGraphicRole {
        switch self {
        case .source: return .originalAttempt
        case .retry: return .retryAttempt
        }
    }

    func isDominant(for result: TranscriptRetryResult) -> Bool {
        switch result {
        case .improved:
            return self == .retry
        case .regressed:
            return self == .source
        case .held, .needsMoreEvidence:
            return false
        }
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
    /// Trigger for the one-shot changed-word brighten sweep; never toggled
    /// under Reduce Motion (the static highlight is the RM presentation).
    @State private var changeSweepTrigger = false

    private var comparison: TranscriptRetryComparison? {
        TranscriptRetryComparisonQualification.resolve(
            outcome: outcome,
            sourceSession: sourceSession,
            retrySession: retrySession
        )
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
        guard comparison != nil else {
            return "There is not enough source-bound evidence for a fair comparison yet."
        }
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
        if comparison != nil, let priorHolds, let priorTries {
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
            VStack(alignment: .leading, spacing: 2) {
                Text("COMPARISON · TWO TRIES")
                    .font(Typography.micro.weight(.heavy))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Text(resultTitle)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
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

            if comparison != nil, let sourceSession {
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
                    stage: .source
                )
                comparisonBridge
                comparisonRung(
                    label: rungLabel("RETRY", session: retrySession),
                    text: TranscriptChangeHighlighter.highlightedText(
                        original: sourceSnippet,
                        revision: retrySnippet
                    ),
                    stage: .retry,
                    sweep: (original: sourceSnippet, revision: retrySnippet)
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
                changeSweepTrigger.toggle()
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

    /// Numbered evidence markers communicate sequence. Dominance is earned by
    /// the comparison result: a verified improvement lifts the retry, a
    /// regression preserves the source, and uncertain/held results stay
    /// visually even. `sweep` (retry rung only) supplies the snippet pair for
    /// the one-shot changed-word brighten sweep layered over the static
    /// highlight.
    private func comparisonRung(
        label: String,
        text: Text,
        stage: RetryComparisonStage,
        sweep: (original: String, revision: String)? = nil
    ) -> some View {
        let dominant = stage.isDominant(for: result)
        let rungFont = dominant
            ? Typography.body.weight(.semibold)
            : Typography.caption.weight(.medium)
        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: stage.graphicRole.systemName)
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)

                Text(label)
                    .font(Typography.micro.weight(.heavy))
            }
            .foregroundStyle(dominant ? AppColor.proText : AppColor.neutralReceded)
            HStack(alignment: .top, spacing: Spacing.xs) {
                Text("“")
                    .font(Typography.cardTitle)
                    .foregroundStyle(dominant ? AppColor.proText : AppColor.neutralReceded)
                    .accessibilityHidden(true)

                text
                    .font(rungFont)
                    .foregroundStyle(dominant ? AppColor.textPrimary : AppColor.neutralReceded)
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay(alignment: .topLeading) {
                        if let sweep {
                            changedWordSweep(
                                original: sweep.original,
                                revision: sweep.revision,
                                font: rungFont
                            )
                        }
                    }

                Text("”")
                    .font(Typography.cardTitle)
                    .foregroundStyle(dominant ? AppColor.proText : AppColor.neutralReceded)
                    .accessibilityHidden(true)
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

    private var comparisonBridge: some View {
        Text("Same coaching target")
            .font(Typography.micro.weight(.heavy))
            .foregroundStyle(AppColor.proText)
            .padding(.leading, Spacing.sm)
            .accessibilityLabel("Same coaching target for the first try and retry")
    }

    /// Decorative one-shot brighten sweep over the retry rung: each changed
    /// word briefly brightens in reading order on the `coachLineStagger`
    /// cadence, then recedes to the static highlight. Purely additive — the
    /// base `highlightedText` underneath stays the authoritative (and RM)
    /// presentation, and the layers are hidden from accessibility. The
    /// trigger only ever toggles outside Reduce Motion, so the phase
    /// animator rests at opacity 0 (no motion, no loop) for RM users.
    private func changedWordSweep(
        original: String,
        revision: String,
        font: Font
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(
                Array(Self.sweepLayers(original: original, revision: revision).enumerated()),
                id: \.offset
            ) { index, layer in
                layer
                    // Mirrors this rung's exact text styling so held/even
                    // comparisons stay glyph-aligned as well as improvements.
                    .font(font)
                    .fixedSize(horizontal: false, vertical: true)
                    .brightness(0.25)
                    .phaseAnimator([0.0, 1.0], trigger: changeSweepTrigger) { view, phase in
                        view.opacity(phase)
                    } animation: { _ in
                        .coachLineStagger(index)
                    }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// Salience cap for the brighten sweep — beyond this the sweep stops
    /// reading as emphasis and starts reading as decoration.
    private static let sweepWordCap = 6

    /// Mirrors `TranscriptChangeHighlighter`'s word tokenisation (same
    /// pattern) so sweep layers land on the same words the static highlight
    /// marks. Drift would only mute the decorative sweep — the highlight
    /// underneath remains authoritative.
    private static let sweepWordRegex = try! NSRegularExpression(
        pattern: #"[\p{L}\p{N}'’-]+"#
    )

    /// One overlay layer per changed word (capped): the full revision string
    /// rendered with every glyph clear except that word, styled exactly like
    /// the base highlight's changed words so each layer wraps identically
    /// and the visible word sits pixel-aligned over its static counterpart.
    private static func sweepLayers(original: String, revision: String) -> [Text] {
        let nsRevision = revision as NSString
        let matches = sweepWordRegex.matches(
            in: revision,
            range: NSRange(location: 0, length: nsRevision.length)
        )
        let changed = TranscriptChangeHighlighter.changedWordIndexes(
            original: original,
            revision: revision
        )
        let emphasized = matches.indices.filter(changed.contains).prefix(sweepWordCap)
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

#Preview("Verified retry reward") {
    TranscriptRetryMilestoneView(
        presentation: TranscriptRetryMilestonePresentation(
            id: UUID(),
            headline: "First hold under pressure",
            detail: "Your direct opening was stronger on this retry."
        ),
        earnedXP: 25,
        unlockedNextStep: true,
        onContinue: {}
    )
}

#Preview("Verified retry reward · dark accessibility") {
    TranscriptRetryMilestoneView(
        presentation: TranscriptRetryMilestonePresentation(
            id: UUID(),
            headline: "The target moved",
            detail: "Your concise delivery was stronger on this retry."
        ),
        earnedXP: 25,
        unlockedNextStep: false,
        onContinue: {}
    )
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}
#endif
