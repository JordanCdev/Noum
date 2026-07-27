#if canImport(SwiftUI)
import SwiftUI

enum TranscriptUpgradePresentationState: Equatable {
    case loading
    case ready
    case unavailable
}

// MARK: - Rewrite Suggestion Card (Pro)
//
// Pro-only card that asks `AIRewriteService` to rewrite the user's
// weakest section in their own voice, then presents a transcript ladder:
// verified original → one-step upgrade → labelled aspiration → retry.
//
// Voice-preservation is the entire point. The card surfaces a short
// banner ("Written in your voice — no AI-speak") so the user
// understands we're not turning them into ChatGPT.
//
// Honest empty/error states:
//   - No AI provider configured → card hides itself (parent gates on
//     `primaryWeakness != nil && premium.isPremium` so it only attempts
//     when there's a real weakness to rewrite).
//   - Service returns nil (rate limit, content filter rejection, etc.)
//     → "We didn't have a confident rewrite for this rep" with a retry.

@available(iOS 17.0, *)
struct RewriteSuggestionCard: View {
    let transcript: String
    let weakness: AIRewriteService.Weakness
    var sourceSessionID: UUID? = nil
    var sourcePrompt: String? = nil
    /// Duration of the verified source rep; renders in the provenance eyebrow
    /// ("FROM YOUR TRANSCRIPT · VERIFIED 0:48"). Nil keeps the eyebrow duration-free.
    var sourceDuration: TimeInterval? = nil
    var targetDimension: String? = nil
    var targetDimensionID: String? = nil
    var goal: SpeakingStyleGoal? = nil
    var transcriptConfidence: Double? = nil
    var savedSnapshot: TranscriptRewriteSnapshot? = nil
    var onPracticePhrase: ((PhrasePracticeIntent) -> Void)? = nil
    var onPracticeRewrite: ((TranscriptPracticePrescription) -> Void)? = nil
    var onPresentationStateChange: ((TranscriptUpgradePresentationState) -> Void)? = nil

    @StateObject private var phraseBank = PhraseBankStore.shared
    @State private var oneStepRewrite: Rewrite?
    @State private var aspirationalRewrite: Rewrite?
    @State private var isLoading = false
    @State private var didFail = false
    @State private var didSave = false
    @State private var showPhraseBank = false
    @State private var ladderCorrelationID = UUID()
    /// Drives the standard transformation: the original renders at full
    /// strength first, then the let-go words recede while TRY THIS rises.
    /// Reduce Motion arrives in the settled state instantly — same
    /// information, no motion (frozen RM contract).
    @State private var revealReceded = false
    /// Beat 3 of the owned sequence (PhraseTransformationBeat.explain):
    /// the explanation line appears after the visual change.
    @State private var explainRevealed = false
    /// Replay re-arms only after the sequence settles.
    @State private var transformationSettled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isLoading {
                loadingState
            } else if let oneStepRewrite {
                ladderState(oneStepRewrite)
            } else if didFail {
                failureState
            } else {
                emptyState
            }

            phraseBankLink
            if oneStepRewrite?.source != .onDevice {
                voicePreservationFootnote
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    AppColor.proQuietSurface,
                    AppColor.cardBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(AppColor.pro.opacity(0.18), lineWidth: 1)
        )
        .task(id: rewriteID) {
            await loadLadder()
        }
        .sheet(isPresented: $showPhraseBank) {
            PhraseBankSheet(
                onPracticePhrase: onPracticePhrase
            )
        }
    }

    private var rewriteID: String {
        "\(weakness.rawValue)-\(transcript.hashValue)-\(savedSnapshot?.oneStepText.hashValue ?? 0)"
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColor.pro)
            Text("One-step \(weakness.humanLabel) upgrade")
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
            Spacer()
            Text("PRO")
                .font(Typography.micro.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColor.pro, in: Capsule())
        }
    }

    // MARK: - States

    private var loadingState: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Building one useful upgrade…")
                .font(Typography.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var provenanceEyebrow: String {
        if let sourceDuration, sourceDuration > 0 {
            return "FROM YOUR TRANSCRIPT · VERIFIED \(RepDurationLabel.mss(sourceDuration))"
        }
        return "FROM YOUR TRANSCRIPT · VERIFIED"
    }

    private func ladderState(_ oneStep: Rewrite) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // The transformation: exact words first, then the let-go words
            // recede (crossfade between two pixel-aligned renderings — the
            // stable words never move; decision #5, recede never strikethrough).
            ReviewTranscriptStep(
                eyebrow: provenanceEyebrow,
                text: TranscriptChangeHighlighter.recededText(
                    original: originalSnippet,
                    revision: oneStep.text,
                    receded: revealReceded
                ),
                detail: "Verified from this rep",
                tint: .secondary,
                identifier: "rewrite.original",
                plainText: originalSnippet,
                spokenDiff: TranscriptChangeHighlighter
                    .spokenRemovals(original: originalSnippet, revision: oneStep.text)
                    .map { "Your original. Words being let go: \($0)." }
            )

            ReviewTranscriptStep(
                eyebrow: "TRY THIS",
                text: TranscriptChangeHighlighter.highlightedText(
                    original: originalSnippet,
                    revision: oneStep.text
                ),
                detail: "Changed words are highlighted · meaning and voice preserved",
                tint: AppColor.proText,
                identifier: "rewrite.oneStep",
                plainText: oneStep.text,
                spokenDiff: TranscriptChangeHighlighter
                    .spokenAdditions(original: originalSnippet, revision: oneStep.text)
                    .map { "Upgrade — adds \($0). Meaning and voice preserved." },
                hero: true,
                detailVisible: explainRevealed
            )
            .opacity(revealReceded ? 1 : 0)
            .offset(y: revealReceded ? 0 : 8)
            // The strengthened phrase resolves one beat after the recede
            // (PhraseTransformationBeat.resolve); the original's recede
            // rides the un-delayed transaction on the step above.
            .animation(
                reduceMotion ? nil : NoumMotion.phraseTransformation
                    .delay(PhraseTransformationBeat.resolve),
                value: revealReceded
            )
            .animation(
                reduceMotion ? nil : .v46ReduceMotionFade,
                value: explainRevealed
            )
            .overlay(alignment: .topTrailing) {
                if transformationSettled && !reduceMotion {
                    Button {
                        Task { await playTransformation(replay: true) }
                    } label: {
                        Label("Replay", systemImage: "arrow.counterclockwise")
                            .font(Typography.micro.weight(.semibold))
                            .foregroundStyle(AppColor.proText.opacity(0.8))
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("rewrite.replayTransformation")
                    .accessibilityHint("Plays the phrase transformation again.")
                }
            }

            targetRung

            if let aspirationalRewrite {
                ReviewTranscriptStep(
                    eyebrow: "ASPIRATIONAL END STATE",
                    text: TranscriptChangeHighlighter.highlightedText(
                        original: originalSnippet,
                        revision: aspirationalRewrite.text
                    ),
                    detail: "A direction to grow toward — not the next rep target",
                    tint: AppColor.brandBlue,
                    identifier: "rewrite.aspirational"
                )
            }

            if oneStep.source == .onDevice {
                Label("Private on-device edit", systemImage: "lock.fill")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier("rewrite.onDevice")
                    .accessibilityLabel("Private on-device edit, built from your own words without an AI provider.")
            }

            if onPracticeRewrite != nil || onPracticePhrase != nil {
                Button {
                    practise(oneStep)
                } label: {
                    Text("Try again with the same prompt")
                        .font(Typography.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(EditorialCTAButtonStyle())
                .accessibilityIdentifier("rewrite.practiceOneStep")
                .accessibilityHint("Saves the one-step version and starts a targeted retry of the same prompt.")
            }

            HStack(spacing: 8) {
                Button {
                    save(oneStep)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: didSave ? "checkmark" : "bookmark")
                            .font(.system(size: 11, weight: .bold))
                        Text(didSave ? "Saved" : "Save phrase")
                            .font(Typography.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppColor.proText)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(AppColor.proQuietSurface, in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityIdentifier("rewrite.savePhrase")
                .accessibilityHint("Saves this rewrite to your on-device phrase bank.")

                Spacer()
            }
        }
        .task {
            guard !revealReceded else { return }
            await playTransformation()
        }
    }

    /// The owned transformation sequence (PhraseTransformationBeat):
    /// exact transcript is already on screen → 450ms read dwell → let-go
    /// words recede (beat 1) while the strengthened phrase resolves one
    /// beat later (beat 2, via the rung's delayed animation) → the
    /// explanation surfaces after the visual change (beat 3). Reduce
    /// Motion arrives settled instantly — one accessible comparison.
    @MainActor
    private func playTransformation(replay: Bool = false) async {
        if reduceMotion {
            revealReceded = true
            explainRevealed = true
            transformationSettled = true
            return
        }
        if replay {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                revealReceded = false
                explainRevealed = false
                transformationSettled = false
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
        } else {
            try? await Task.sleep(nanoseconds: 450_000_000)
        }
        withAnimation(NoumMotion.phraseTransformation) {
            revealReceded = true
        }
        try? await Task.sleep(nanoseconds: UInt64(PhraseTransformationBeat.explain * 1_000_000_000))
        withAnimation(.v46ReduceMotionFade) {
            explainRevealed = true
        }
        try? await Task.sleep(
            nanoseconds: UInt64((PhraseTransformationBeat.settled - PhraseTransformationBeat.explain) * 1_000_000_000)
        )
        transformationSettled = true
    }

    private var targetRung: some View {
        let target = TranscriptRetryTarget(
            lever: TranscriptPracticeLever(weakness: weakness)
        )
        return VStack(alignment: .leading, spacing: 5) {
            Text("TARGET FOR THE RETRY")
                .font(Typography.micro.weight(.heavy))
                .tracking(0.5)
                .foregroundStyle(AppColor.proText)
            Text(target.lever.successMeasure)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
            Text("Noum will score your retry against the original rep; the target itself isn't scored.")
                .font(Typography.micro)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(.horizontal, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("rewrite.retryTarget")
    }

    private var failureState: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            Text("We didn't have a confident rewrite for this rep.")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Retry") {
                resetAndRetry()
            }
            .font(Typography.caption.weight(.semibold))
            .foregroundStyle(AppColor.pro)
        }
    }

    private var emptyState: some View {
        Text("Tap retry once the rep finishes processing.")
            .font(Typography.caption)
            .foregroundStyle(.secondary)
    }

    private var phraseBankLink: some View {
        Button {
            showPhraseBank = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bookmark")
                    .font(.system(size: 11, weight: .semibold))
                Text("Phrase bank\(phraseBank.entries.isEmpty ? "" : " (\(phraseBank.entries.count))")")
                    .font(Typography.caption.weight(.semibold))
            }
            .foregroundStyle(AppColor.textSecondary)
            .frame(minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityIdentifier("rewrite.phraseBank")
        .accessibilityHint("Shows phrases you saved for later practice.")
    }

    // MARK: - Voice-preservation footnote

    private var voicePreservationFootnote: some View {
        HStack(spacing: 6) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 10, weight: .bold))
            Text("Written in your voice — no AI-speak.")
                .font(Typography.micro)
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Logic

    /// Pull the slice of the original transcript closest to what the
    /// rewrite is replacing. For opening/closing this is roughly
    /// "first sentence" / "last sentence". Used as the "your version"
    /// view.
    ///
    /// Delegates to `AIRewriteService` so the locked (non-Pro) card quotes the
    /// exact same words back — a free user seeing a different snippet than the
    /// one Pro would rewrite would make the upgrade pitch dishonest.
    private var originalSnippet: String {
        AIRewriteService.originalSnippet(transcript: transcript, weakness: weakness)
    }

    private func loadLadder() async {
        guard oneStepRewrite == nil, !isLoading else { return }
        onPresentationStateChange?(.loading)
        if let savedSnapshot,
           savedSnapshot.weakness == weakness,
           savedSnapshot.matches(sourceTranscript: transcript) {
            oneStepRewrite = savedSnapshot.oneStepRewrite
            aspirationalRewrite = savedSnapshot.aspirationalRewrite
            onPresentationStateChange?(.ready)
            return
        }
        guard transcript.count >= 40,
              transcriptConfidence.map({ $0 >= 0.55 }) ?? true else {
            didFail = true
            onPresentationStateChange?(.unavailable)
            return
        }
        let saveToken = sourceSessionID.flatMap {
            PracticeSessionStore.shared.coachReadSaveToken(sessionID: $0)
        }
        let snapshotCreatedAt = Date()
        isLoading = true
        didFail = false
        // Voice from the live profile so the rewrite nudges toward the
        // user's voice goal while still anchored to their vocabulary.
        // Read off the main actor since CoachingProfileStore is main-isolated.
        let voice = await MainActor.run {
            AIRewriteService.selectedVoice(from: CoachingProfileStore.shared.profile)
        }
        let oneStep = await AIRewriteService.shared.rewrite(
            transcript: transcript,
            weakness: weakness,
            voice: voice,
            targetDimension: targetDimension,
            transcriptConfidence: transcriptConfidence,
            intensity: .medium
        )
        await MainActor.run {
            if let oneStep {
                isLoading = false
                withAnimation(reduceMotion ? nil : .standardSpring) {
                    oneStepRewrite = oneStep
                }
                onPresentationStateChange?(.ready)
                FlowEventLog.shared.recordTranscriptLadderShown(
                    correlationId: ladderCorrelationID,
                    lever: TranscriptPracticeLever(weakness: weakness)
                )
                persistSnapshot(
                    oneStep: oneStep,
                    aspiration: nil,
                    expected: saveToken,
                    createdAt: snapshotCreatedAt
                )
            } else {
                isLoading = false
                didFail = true
                onPresentationStateChange?(.unavailable)
            }
        }
        guard oneStep != nil, !Task.isCancelled else { return }
        // The aspiration is optional depth. The actionable one-step rung is
        // already visible, so a slow or rejected second rewrite can never
        // strand the card in a thinking state.
        let aspiration = await AIRewriteService.shared.rewrite(
            transcript: transcript,
            weakness: weakness,
            voice: voice,
            targetDimension: targetDimension,
            transcriptConfidence: transcriptConfidence,
            intensity: .strong
        )
        await MainActor.run {
            isLoading = false
            if let aspiration,
               aspiration.text.caseInsensitiveCompare(oneStep?.text ?? "") != .orderedSame {
                withAnimation(reduceMotion ? nil : .standardSpring) {
                    aspirationalRewrite = aspiration
                }
                if let oneStep {
                    persistSnapshot(
                        oneStep: oneStep,
                        aspiration: aspiration,
                        expected: saveToken,
                        createdAt: snapshotCreatedAt
                    )
                }
            }
        }
    }

    private func persistSnapshot(
        oneStep: Rewrite,
        aspiration: Rewrite?,
        expected token: CoachReadSaveToken?,
        createdAt: Date
    ) {
        guard let token else { return }
        let snapshot = TranscriptRewriteSnapshot(
            weakness: weakness,
            originalSnippet: originalSnippet,
            oneStepText: oneStep.text,
            aspirationalText: aspiration?.text,
            origin: .init(oneStep.source),
            createdAt: createdAt
        )
        _ = PracticeSessionStore.shared.saveTranscriptRewriteSnapshot(
            expected: token,
            snapshot: snapshot
        )
    }

    private func resetAndRetry() {
        oneStepRewrite = nil
        aspirationalRewrite = nil
        didFail = false
        didSave = false
        onPresentationStateChange?(.loading)
        Task { await loadLadder() }
    }

    private func save(_ rewrite: Rewrite) {
        let voice = AIRewriteService.selectedVoice(from: CoachingProfileStore.shared.profile)
        didSave = phraseBank.save(
            text: rewrite.text,
            voice: voice,
            weakness: rewrite.weakness,
            intensity: rewrite.intensity
        ) != nil
    }

    private func practise(_ rewrite: Rewrite) {
        let voice = AIRewriteService.selectedVoice(from: CoachingProfileStore.shared.profile)
        guard let entry = phraseBank.save(
            text: rewrite.text,
            voice: voice,
            weakness: rewrite.weakness,
            intensity: .medium
        ) else { return }
        guard let intent = PhrasePracticeIntent(entry: entry) else { return }
        didSave = true
        if let sourceSessionID, let onPracticeRewrite {
            let retryTarget = TranscriptRetryTarget(
                lever: TranscriptPracticeLever(weakness: weakness)
            )
            onPracticeRewrite(TranscriptPracticePrescription(
                correlationID: ladderCorrelationID,
                sourceSessionID: sourceSessionID,
                suggestedPrompt: TranscriptRetryPrompt.resolve(
                    sourcePrompt: sourcePrompt,
                    fallbackRewritePrompt: intent.suggestedPrompt
                ),
                title: "One-step \(retryTarget.lever.focusLabel) upgrade",
                focus: retryTarget.lever.focusLabel,
                target: retryTarget.lever.successMeasure,
                targetDimensionID: targetDimensionID,
                goal: goal,
                retryTarget: retryTarget
            ))
        } else {
            onPracticePhrase?(intent)
        }
    }
}

/// Shared visual rung for the production Review ladder. It owns presentation
/// only; the exact source/rewrite content remains in `PracticeSession` and the
/// transcript-retry handoff. Flexible height keeps it usable at AX5.
struct ReviewTranscriptStep: View {
    let eyebrow: String
    let text: Text
    let detail: String
    let tint: Color
    let identifier: String
    /// The rung's phrase as a plain string. `text` is a styled `Text` whose
    /// characters cannot be read back, so the spoken label needs this.
    var plainText: String = ""
    /// A clause naming what changed, e.g. `Adds “decide today”.` — supplied by
    /// the caller from `TranscriptChangeHighlighter`. When nil the label falls
    /// back to the previous concatenation, so nothing regresses.
    var spokenDiff: String?
    /// The frozen design gives the improved phrase unmistakable hero weight
    /// (decision: the transformation IS the teaching). Only the TRY THIS rung
    /// sets this.
    var hero: Bool = false
    /// Phrase-transformation beat 3: the explanation surfaces AFTER the
    /// visual change has landed. Only the TRY THIS rung drives this.
    var detailVisible: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(Typography.micro.weight(.heavy))
                .tracking(0.5)
                .foregroundStyle(tint)
            text
                .font(hero ? Typography.cardTitle.weight(.semibold) : Typography.body.weight(.medium))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            Text(detail)
                .font(Typography.micro)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(detailVisible ? 1 : 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(
                cornerRadius: CornerRadius.medium,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: CornerRadius.medium,
                style: .continuous
            )
            .stroke(tint.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        // `.combine` concatenates the eyebrow, the phrase and the caption, which
        // left a screen-reader user with two near-identical paragraphs and a
        // caption pointing at a colour highlight. When the caller supplies the
        // diff, state it instead — the changed words are the teaching.
        .accessibilityLabel(spokenLabel ?? combinedFallbackLabel)
        .accessibilityIdentifier(identifier)
    }

    /// Nil unless the caller passed a diff clause, in which case `.combine`'s
    /// concatenation still applies and nothing regresses.
    private var spokenLabel: String? {
        guard let spokenDiff, !spokenDiff.isEmpty else { return nil }
        return "\(eyebrow.capitalizedSentence). \(spokenDiff) Full line: \(plainText)"
    }

    private var combinedFallbackLabel: String {
        [eyebrow.capitalizedSentence, plainText, detail]
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }
}

private extension String {
    /// Eyebrows are heavy all-caps for the eye ("TRY THIS"); spoken verbatim
    /// VoiceOver may spell them out, so soften to sentence case for the label.
    var capitalizedSentence: String {
        guard !isEmpty else { return self }
        let lower = lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }
}

/// Violet editorial CTA per the frozen V4.6 system: one geometry, pressed
/// state darkens the fill to `actionPressed` (a state cue, not motion — safe
/// under Reduce Motion by construction). White label clears AA on both fills.
struct EditorialCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                configuration.isPressed ? AppColor.actionPressed : AppColor.coachingInk,
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.96 : 1)
    }
}

/// Word-level comparison for the transcript ladder. It uses a longest common
/// subsequence so repeated words are not all marked as changed when a single
/// connective moves. The user sees the exact original above; highlighting is
/// explanatory presentation only and never mutates the stored transcript.
enum TranscriptChangeHighlighter {
    nonisolated static func changedWordIndexes(original: String, revision: String) -> Set<Int> {
        let source = words(in: original)
        let target = words(in: revision)
        guard !target.isEmpty else { return [] }

        var lengths = Array(
            repeating: Array(repeating: 0, count: target.count + 1),
            count: source.count + 1
        )
        if !source.isEmpty {
            for sourceIndex in 1...source.count {
                for targetIndex in 1...target.count {
                    if source[sourceIndex - 1] == target[targetIndex - 1] {
                        lengths[sourceIndex][targetIndex] = lengths[sourceIndex - 1][targetIndex - 1] + 1
                    } else {
                        lengths[sourceIndex][targetIndex] = max(
                            lengths[sourceIndex - 1][targetIndex],
                            lengths[sourceIndex][targetIndex - 1]
                        )
                    }
                }
            }
        }

        var matchedPairs: [(source: Int, target: Int)] = []
        var sourceIndex = source.count
        var targetIndex = target.count
        while sourceIndex > 0, targetIndex > 0 {
            if source[sourceIndex - 1] == target[targetIndex - 1] {
                matchedPairs.append((sourceIndex - 1, targetIndex - 1))
                sourceIndex -= 1
                targetIndex -= 1
            } else if lengths[sourceIndex - 1][targetIndex] >= lengths[sourceIndex][targetIndex - 1] {
                sourceIndex -= 1
            } else {
                targetIndex -= 1
            }
        }
        matchedPairs.reverse()

        let unchanged = Set(matchedPairs.map(\.target))
        var changed = Set(target.indices).subtracting(unchanged)
        var previousSource = -1
        var previousTarget = -1
        for pair in matchedPairs {
            let removedBeforeMatch = pair.source - previousSource - 1
            let insertedBeforeMatch = pair.target - previousTarget - 1
            // When words were removed and the next surviving word closes the
            // gap, highlight that word as the visible anchor of the edit.
            // Otherwise a tightening such as "I think we" -> "We" would
            // appear to contain no change at all because the deleted words
            // are not present in the revision to receive emphasis.
            if removedBeforeMatch > 0, insertedBeforeMatch == 0 {
                changed.insert(pair.target)
            }
            previousSource = pair.source
            previousTarget = pair.target
        }
        return changed
    }

    /// Source-side counterpart of `changedWordIndexes`: the words of the
    /// ORIGINAL that do not survive into the revision. Same LCS, backtracked
    /// on the source axis, so a moved connective is not marked as removed.
    nonisolated static func removedWordIndexes(original: String, revision: String) -> Set<Int> {
        let source = words(in: original)
        let target = words(in: revision)
        guard !source.isEmpty else { return [] }
        guard !target.isEmpty else { return Set(source.indices) }

        var lengths = Array(
            repeating: Array(repeating: 0, count: target.count + 1),
            count: source.count + 1
        )
        for sourceIndex in 1...source.count {
            for targetIndex in 1...target.count {
                if source[sourceIndex - 1] == target[targetIndex - 1] {
                    lengths[sourceIndex][targetIndex] = lengths[sourceIndex - 1][targetIndex - 1] + 1
                } else {
                    lengths[sourceIndex][targetIndex] = max(
                        lengths[sourceIndex - 1][targetIndex],
                        lengths[sourceIndex][targetIndex - 1]
                    )
                }
            }
        }
        var matchedSource = Set<Int>()
        var sourceIndex = source.count
        var targetIndex = target.count
        while sourceIndex > 0, targetIndex > 0 {
            if source[sourceIndex - 1] == target[targetIndex - 1] {
                matchedSource.insert(sourceIndex - 1)
                sourceIndex -= 1
                targetIndex -= 1
            } else if lengths[sourceIndex - 1][targetIndex] >= lengths[sourceIndex][targetIndex - 1] {
                sourceIndex -= 1
            } else {
                targetIndex -= 1
            }
        }
        return Set(source.indices).subtracting(matchedSource)
    }

    /// The verified original with let-go words receded — quieter colour, never
    /// strikethrough (design decision #5: nothing added, nothing lost). When
    /// `receded` is false the exact original renders in full strength, which
    /// is the pre-reveal state of the standard transformation.
    static func recededText(original: String, revision: String, receded: Bool = true) -> Text {
        let nsOriginal = original as NSString
        let matches = wordRegex.matches(
            in: original,
            range: NSRange(location: 0, length: nsOriginal.length)
        )
        let removed = receded
            ? removedWordIndexes(original: original, revision: revision)
            : []
        var rendered = Text("")
        var cursor = 0
        for (index, match) in matches.enumerated() {
            if match.range.location > cursor {
                rendered = rendered + Text(nsOriginal.substring(
                    with: NSRange(location: cursor, length: match.range.location - cursor)
                ))
            }
            let token = Text(nsOriginal.substring(with: match.range))
            rendered = rendered + (removed.contains(index)
                ? token.foregroundColor(AppColor.neutralReceded.opacity(0.75))
                : token)
            cursor = match.range.location + match.range.length
        }
        if cursor < nsOriginal.length {
            rendered = rendered + Text(nsOriginal.substring(from: cursor))
        }
        return rendered
    }

    static func highlightedText(original: String, revision: String) -> Text {
        let nsRevision = revision as NSString
        let matches = wordRegex.matches(
            in: revision,
            range: NSRange(location: 0, length: nsRevision.length)
        )
        let changed = changedWordIndexes(original: original, revision: revision)
        var rendered = Text("")
        var cursor = 0
        for (index, match) in matches.enumerated() {
            if match.range.location > cursor {
                rendered = rendered + Text(nsRevision.substring(
                    with: NSRange(location: cursor, length: match.range.location - cursor)
                ))
            }
            let token = Text(nsRevision.substring(with: match.range))
            rendered = rendered + (changed.contains(index)
                ? token.foregroundColor(AppColor.proText).bold()
                : token)
            cursor = match.range.location + match.range.length
        }
        if cursor < nsRevision.length {
            rendered = rendered + Text(nsRevision.substring(from: cursor))
        }
        return rendered
    }

    /// Spoken form of the diff. The changed/removed word sets already exist for
    /// the visual highlight, but nothing voiced them, so the transformation —
    /// the product's actual teaching moment — reached VoiceOver as two
    /// near-identical paragraphs plus a caption telling the user that "changed
    /// words are highlighted", i.e. pointing at a cue they cannot perceive.
    ///
    /// `original` names what is being let go; `upgrade` names what now leads.
    /// Both return nil when the diff is empty so a caller can fall back rather
    /// than announce an empty clause.
    nonisolated static func spokenRemovals(original: String, revision: String) -> String? {
        let source = words(in: original)
        let indexes = removedWordIndexes(original: original, revision: revision).sorted()
        let dropped = indexes.compactMap { $0 < source.count ? source[$0] : nil }
        guard !dropped.isEmpty else { return nil }
        return quotedList(dropped)
    }

    nonisolated static func spokenAdditions(original: String, revision: String) -> String? {
        let target = words(in: revision)
        let indexes = changedWordIndexes(original: original, revision: revision).sorted()
        let added = indexes.compactMap { $0 < target.count ? target[$0] : nil }
        guard !added.isEmpty else { return nil }
        return quotedList(added)
    }

    /// Groups runs of consecutive indexes into phrases so VoiceOver reads
    /// "adds 'decide today'" rather than "adds 'decide', 'today'".
    private nonisolated static func quotedList(_ tokens: [String]) -> String {
        tokens.map { "\u{201C}\($0)\u{201D}" }.joined(separator: ", ")
    }

    private nonisolated static func words(in text: String) -> [String] {
        let nsText = text as NSString
        return wordRegex.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ).map { nsText.substring(with: $0.range).lowercased() }
    }

    private nonisolated static let wordRegex = try! NSRegularExpression(
        pattern: #"[\p{L}\p{N}'’-]+"#
    )
}

// MARK: - Locked preview (non-Pro)
//
// The rewrite is the clearest thing Noum does that a free user cannot see, and
// it used to be invisible to them entirely — buried behind a collapsed
// disclosure that also required Pro. A feature nobody can see cannot sell
// itself.
//
// This card shows a free user the real sentence Noum would rework, and states
// plainly that the reworked version is Pro. What it must never do is fabricate
// a preview: no blurred fake text, no teaser rewrite, no "AI is thinking"
// state. The user's own words are real; the absence of the rewrite is honest.
// It deliberately never touches `AIRewriteService`, so no provider call is
// made for a user who cannot read the result.

@available(iOS 17.0, *)
struct LockedRewritePreviewCard: View {
    let transcript: String
    let weakness: AIRewriteService.Weakness
    var onUpgrade: () -> Void

    private var originalSnippet: String {
        AIRewriteService.originalSnippet(transcript: transcript, weakness: weakness)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColor.pro)
                Text("Try this \(weakness.humanLabel)")
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                Spacer()
                Text("PRO")
                    .font(Typography.micro.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColor.pro, in: Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Your version")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(originalSnippet)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(
                AppColor.innerSurface,
                in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
            )

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                Text("Pro rewrites this in your own vocabulary, so it still sounds like you.")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onUpgrade) {
                Text("Unlock with Pro")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.pro)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("summary.rewrite.upgrade")
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("summary.rewrite.locked")
        .accessibilityLabel("Rewrite suggestion, Pro feature. Your version: \(originalSnippet)")
    }
}

@available(iOS 17.0, *)
struct PhraseBankSheet: View {
    var onPracticePhrase: ((PhrasePracticeIntent) -> Void)? = nil
    @StateObject private var store = PhraseBankStore.shared
    @StateObject private var forwardPlanStore = ForwardPlanStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var bigMomentStore = BigMomentStore.shared
    @State private var assignmentError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if store.entries.isEmpty {
                    ContentUnavailableView(
                        "No saved phrases",
                        systemImage: "bookmark",
                        description: Text("Save a rewrite you want to practise again.")
                    )
                } else {
                    ForEach(store.entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.text)
                                .font(Typography.body.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                            Text(metadata(for: entry))
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)

                            if let intent = Self.practiceIntent(
                                for: entry,
                                onPracticePhrase: onPracticePhrase
                            ) {
                                Button {
                                    Self.performPractice(
                                        intent,
                                        onPracticePhrase: onPracticePhrase,
                                        dismiss: { dismiss() }
                                    )
                                } label: {
                                    Label("Practice phrase", systemImage: "timer")
                                        .font(Typography.caption.weight(.semibold))
                                        .foregroundStyle(AppColor.modeTimed)
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Practice phrase")
                                .accessibilityHint("Starts Timed Practice with this saved phrase.")
                                .accessibilityIdentifier("phraseBank.practice.\(entry.id.uuidString)")
                            }

                            if let target = currentWeekTarget {
                                let isAssigned = target.assignedEntryID == entry.id
                                Button {
                                    assign(entry, to: target)
                                } label: {
                                    Label(
                                        isAssigned ? "In Week \(target.weekIndex)" : "Use in Week \(target.weekIndex)",
                                        systemImage: isAssigned ? "checkmark.circle.fill" : "calendar.badge.plus"
                                    )
                                    .font(Typography.caption.weight(.semibold))
                                    .foregroundStyle(isAssigned ? .secondary : AppColor.pro)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(isAssigned)
                                .accessibilityIdentifier("phraseBank.planWeek.\(entry.id.uuidString)")
                                .accessibilityLabel(
                                    isAssigned
                                        ? "This phrase is in Week \(target.weekIndex) of your plan"
                                        : "Use this phrase in Week \(target.weekIndex) of your plan"
                                )
                                .accessibilityHint(
                                    isAssigned
                                        ? ""
                                        : "Makes this saved line the phrase carried into this week's practice."
                                )
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button(role: .destructive) {
                                ForwardPlanPhraseCoordinator.remove(
                                    entryID: entry.id,
                                    phraseBank: store,
                                    planStore: forwardPlanStore
                                )
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Phrase bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .alert(
            "Couldn't update this week",
            isPresented: Binding(
                get: { assignmentError != nil },
                set: { if !$0 { assignmentError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { assignmentError = nil }
        } message: {
            Text(assignmentError ?? "Your plan changed. Try again.")
        }
    }

    private var currentPlan: ForwardPlan? {
        forwardPlanStore.currentPlan(
            activeBigMomentID: bigMomentStore.activeMoment?.id,
            chosenStyleGoal: coachingProfileStore.profile?.chosenStyleGoal
        )
    }

    private var currentWeekTarget: ForwardPlanPhraseTarget? {
        ForwardPlanPhraseProjection.target(plan: currentPlan)
    }

    private func assign(_ entry: PhraseBankEntry, to target: ForwardPlanPhraseTarget) {
        guard ForwardPlanPhraseCoordinator.assign(
            entryID: entry.id,
            renderedTarget: target,
            currentPlan: currentPlan,
            phraseBank: store,
            planStore: forwardPlanStore
        ) else {
            assignmentError = "Your active plan changed before the phrase was attached. Try once more."
            return
        }
    }

    private func metadata(for entry: PhraseBankEntry) -> String {
        let voice = entry.voice?.title ?? "General"
        return "\(voice) · \(entry.intensity.title) change · \(entry.weakness.humanLabel)"
    }

    /// Keeps the action absent unless an owner can route it and the saved
    /// phrase still passes the store's privacy boundary.
    nonisolated static func practiceIntent(
        for entry: PhraseBankEntry,
        onPracticePhrase: ((PhrasePracticeIntent) -> Void)?
    ) -> PhrasePracticeIntent? {
        guard onPracticePhrase != nil else { return nil }
        return PhrasePracticeIntent(entry: entry)
    }

    nonisolated static func performPractice(
        _ intent: PhrasePracticeIntent,
        onPracticePhrase: ((PhrasePracticeIntent) -> Void)?,
        dismiss: () -> Void
    ) {
        guard let onPracticePhrase else { return }
        onPracticePhrase(intent)
        dismiss()
    }
}

#endif
