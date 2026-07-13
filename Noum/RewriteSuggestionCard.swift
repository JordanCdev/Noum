#if canImport(SwiftUI)
import SwiftUI

// MARK: - Rewrite Suggestion Card (Pro)
//
// Pro-only card that asks `AIRewriteService` to rewrite the user's
// weakest section in their own voice, then shows it next to a "your
// version" toggle so the user can compare.
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
    @State private var rewrite: Rewrite?
    @State private var intensity: AIRewriteService.Intensity = .medium
    @State private var isLoading = false
    @State private var didFail = false
    @State private var didSave = false
    @State private var showOriginal = false
    @State private var showPhraseBank = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            intensityPicker

            if isLoading {
                loadingState
            } else if let rewrite {
                rewrittenState(rewrite)
            } else if didFail {
                failureState
            } else {
                emptyState
            }

            phraseBankLink
            if rewrite?.source != .onDevice {
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
            await loadRewrite()
        }
        .onChange(of: intensity) { _, _ in
            rewrite = nil
            didFail = false
            didSave = false
            showOriginal = false
        }
        .sheet(isPresented: $showPhraseBank) {
            PhraseBankSheet(
                store: phraseBank,
                onPracticePhrase: onPracticePhrase
            )
        }
    }

    private var rewriteID: String { "\(weakness.rawValue)-\(intensity.rawValue)-\(transcript.hashValue)" }

    // MARK: - Header

    private var header: some View {
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
    }

    private var intensityPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Change level")
                .font(Typography.micro.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Change level", selection: $intensity) {
                ForEach(AIRewriteService.Intensity.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isLoading)
            .accessibilityIdentifier("rewrite.intensity")
            .accessibilityHint("Choose how lightly or strongly Noum reshapes the selected phrase.")
        }
    }

    // MARK: - States

    private var loadingState: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Rewriting in your voice…")
                .font(Typography.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func rewrittenState(_ rewrite: Rewrite) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(showOriginal ? originalSnippet : rewrite.text)
                .font(Typography.body.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(AppColor.pro.opacity(0.22), lineWidth: 1)
                )

            if rewrite.source == .onDevice {
                Label("Private on-device edit", systemImage: "lock.fill")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("rewrite.onDevice")
                    .accessibilityLabel("Private on-device edit, built from your own words without an AI provider.")
            }

            HStack(spacing: 8) {
                Button {
                    withAnimation(.standardSpring) { showOriginal.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showOriginal ? "wand.and.stars" : "text.bubble")
                            .font(.system(size: 11, weight: .bold))
                        Text(showOriginal ? "See coach version" : "See your version")
                            .font(Typography.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppColor.pro)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppColor.pro.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    save(rewrite)
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
                Task { await loadRewrite() }
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
    private var originalSnippet: String {
        let sentences = transcript
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !sentences.isEmpty else { return transcript.prefix(140).description + (transcript.count > 140 ? "…" : "") }
        switch weakness {
        case .opening:
            return sentences.prefix(2).joined(separator: ". ") + "."
        case .closing:
            return sentences.suffix(2).joined(separator: ". ") + "."
        case .structure, .concise:
            return transcript.prefix(160).description + (transcript.count > 160 ? "…" : "")
        }
    }

    private func loadRewrite() async {
        guard rewrite == nil, !isLoading else { return }
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
        let result = await AIRewriteService.shared.rewrite(
            transcript: transcript,
            weakness: weakness,
            voice: voice,
            targetDimension: targetDimension,
            transcriptConfidence: transcriptConfidence,
            intensity: intensity
        )
        await MainActor.run {
            isLoading = false
            if let result {
                withAnimation(.standardSpring) { rewrite = result }
            } else {
                didFail = true
            }
        }
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
}

@available(iOS 17.0, *)
struct PhraseBankSheet: View {
    @ObservedObject var store: PhraseBankStore
    var onPracticePhrase: ((PhrasePracticeIntent) -> Void)? = nil
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
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.remove(id: entry.id)
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
