#if canImport(SwiftUI)
import SwiftUI

// MARK: - Grammar Polish Card (M11)
//
// Pro-gated post-session card showing up to three concrete grammar / English-
// usage notes from `GrammarFeedbackService`. Hides itself when:
//   • The user is not Pro (gate handled at the call-site too — both belt
//     and braces, since the service also rejects non-Pro callers).
//   • The session was skipped (too short, too noisy, throat-clearing).
//   • No AI provider is configured. Template "polish notes" would be wrong
//     half the time on real speech, so we simply don't show anything.
//
// When the service runs and finds nothing, we DO render a soft positive
// ("Looks clean") so the user sees that the pass happened — that's the
// signal that grammar was reviewed, not that the feature is broken.
//
// Visual layout follows AISessionDebriefCard: micro header label, headline,
// then a bullet list of notes with category chip + severity tint.

@available(iOS 17.0, macOS 12.0, *)
struct GrammarPolishCard: View {
    let session: PracticeSession?

    @StateObject private var premium = PremiumManager.shared

    @State private var result: GrammarPolishResult?
    @State private var isLoading = true
    @State private var skipped = false

    var body: some View {
        Group {
            if !premium.isPremium {
                EmptyView()
            } else if skipped {
                EmptyView()
            } else if isLoading && result == nil {
                cardShell { skeleton }
            } else if let result, result.aiBacked {
                cardShell { content(result: result) }
            } else {
                EmptyView()
            }
        }
        .task(id: session?.id) {
            await refresh()
        }
    }

    // MARK: - Shell

    @ViewBuilder
    private func cardShell<Content: View>(@ViewBuilder _ inner: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            inner()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.badge.checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
            Text("Polish notes")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.caption2.weight(.bold))
                Text("AI")
                    .font(Typography.micro)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
            .foregroundStyle(AppColor.brandBlue)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AppColor.brandBlue.opacity(0.10), in: Capsule())
        }
    }

    // MARK: - Subviews

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 18)
                .frame(maxWidth: 220)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.10))
                .frame(height: 14)
                .frame(maxWidth: .infinity)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.10))
                .frame(height: 14)
                .frame(maxWidth: 280)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func content(result: GrammarPolishResult) -> some View {
        if result.notes.isEmpty {
            Text("Looks clean — nothing to polish in this rep.")
                .font(Typography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(headline(for: result))
                .font(Typography.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(result.notes) { note in
                    noteRow(note)
                }
            }
        }
    }

    private func noteRow(_ note: GrammarNote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(note.category.label)
                    .font(Typography.micro.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(severityTint(note.severity))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(severityTint(note.severity).opacity(0.10), in: Capsule())
                Spacer()
            }
            Text("\u{201C}\(note.excerpt)\u{201D}")
                .font(Typography.caption.italic())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(note.suggestion)
                .font(Typography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let rationale = note.rationale {
                Text(rationale)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }

    // MARK: - Helpers

    private func headline(for result: GrammarPolishResult) -> String {
        let count = result.notes.count
        if count == 1 { return "One thing to polish" }
        return "\(count) things to polish"
    }

    private func severityTint(_ severity: GrammarNoteSeverity) -> Color {
        switch severity {
        case .material: return AppColor.caution
        case .moderate: return .orange
        case .minor:    return .secondary
        }
    }

    // MARK: - Refresh

    private func refresh() async {
        guard let session else {
            await MainActor.run { isLoading = false }
            return
        }
        guard premium.isPremium else {
            await MainActor.run {
                isLoading = false
                result = nil
            }
            return
        }
        // Pre-check the skip rules so we hide the skeleton fast on
        // obviously-too-short reps, instead of flashing.
        let runnable = GrammarFeedbackService.shouldRun(
            transcript: session.transcript,
            duration: session.duration,
            wordCount: session.wordCount,
            fillerWordCount: session.fillerWordCount,
            transcriptConfidence: session.transcriptConfidence
        )
        guard runnable else {
            await MainActor.run {
                skipped = true
                isLoading = false
            }
            return
        }

        let next = await GrammarFeedbackService.shared.polish(
            sessionId: session.id,
            transcript: session.transcript,
            duration: session.duration,
            wordCount: session.wordCount,
            fillerWordCount: session.fillerWordCount,
            transcriptConfidence: session.transcriptConfidence,
            isPro: premium.isPremium
        )
        await MainActor.run {
            withAnimation(.standardSpring) {
                if let next, next.aiBacked {
                    result = next
                } else {
                    skipped = true
                }
                isLoading = false
            }
        }
    }
}

#endif
