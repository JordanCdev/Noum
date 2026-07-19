#if canImport(SwiftUI)
import SwiftUI

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
    var targetDimension: String? = nil
    var transcriptConfidence: Double? = nil
    var onPracticePhrase: ((PhrasePracticeIntent) -> Void)? = nil

    @StateObject private var phraseBank = PhraseBankStore.shared
    @State private var oneStepRewrite: Rewrite?
    @State private var aspirationalRewrite: Rewrite?
    @State private var isLoading = false
    @State private var didFail = false
    @State private var didSave = false
    @State private var showPhraseBank = false

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
                    AppColor.pro.opacity(0.10),
                    AppColor.proLight.opacity(0.06)
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

    private var rewriteID: String { "\(weakness.rawValue)-\(transcript.hashValue)" }

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

    private func ladderState(_ oneStep: Rewrite) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ladderRung(
                eyebrow: "WHAT I HEARD",
                text: Text(originalSnippet),
                detail: "Verified from this rep",
                tint: .secondary
            )

            ladderRung(
                eyebrow: "ONE-STEP UPGRADE",
                text: TranscriptChangeHighlighter.highlightedText(
                    original: originalSnippet,
                    revision: oneStep.text
                ),
                detail: "Changed words are highlighted · meaning and voice preserved",
                tint: AppColor.pro
            )

            if let aspirationalRewrite {
                ladderRung(
                    eyebrow: "ASPIRATIONAL END STATE",
                    text: TranscriptChangeHighlighter.highlightedText(
                        original: originalSnippet,
                        revision: aspirationalRewrite.text
                    ),
                    detail: "A direction to grow toward — not the next rep target",
                    tint: AppColor.brandBlue
                )
            }

            if oneStep.source == .onDevice {
                Label("Private on-device edit", systemImage: "lock.fill")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("rewrite.onDevice")
                    .accessibilityLabel("Private on-device edit, built from your own words without an AI provider.")
            }

            if onPracticePhrase != nil {
                Button {
                    practise(oneStep)
                } label: {
                    Label("Practise this version", systemImage: "arrow.counterclockwise.circle.fill")
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(AppColor.pro, in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("rewrite.practiceOneStep")
                .accessibilityHint("Saves the one-step version and starts targeted timed practice.")
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
                    .foregroundStyle(AppColor.pro)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppColor.pro.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("rewrite.savePhrase")
                .accessibilityHint("Saves this rewrite to your on-device phrase bank.")

                Spacer()
            }
        }
    }

    private func ladderRung(
        eyebrow: String,
        text: Text,
        detail: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(Typography.micro.weight(.heavy))
                .tracking(0.5)
                .foregroundStyle(tint)
            text
                .font(Typography.body.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(Typography.micro)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
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
            .foregroundStyle(.secondary)
            .frame(minHeight: 32, alignment: .leading)
        }
        .buttonStyle(.plain)
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
        guard transcript.count >= 40,
              transcriptConfidence.map({ $0 >= 0.55 }) ?? true else {
            didFail = true
            return
        }
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
                withAnimation(.standardSpring) { oneStepRewrite = oneStep }
            } else {
                isLoading = false
                didFail = true
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
                withAnimation(.standardSpring) { aspirationalRewrite = aspiration }
            }
        }
    }

    private func resetAndRetry() {
        oneStepRewrite = nil
        aspirationalRewrite = nil
        didFail = false
        didSave = false
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
        onPracticePhrase?(intent)
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
                ? token.foregroundColor(AppColor.pro).bold()
                : token)
            cursor = match.range.location + match.range.length
        }
        if cursor < nsRevision.length {
            rendered = rendered + Text(nsRevision.substring(from: cursor))
        }
        return rendered
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
