#if canImport(SwiftUI)
import SwiftUI

// MARK: - Grammar Polish Card (M11 → M16)
//
// Pro-gated post-session card. Surfaces up to three observational grammar
// findings from `GrammarFeedbackService` — only when the rep meets a high
// threshold for clarity-affecting patterns. Hides itself when:
//   • The user is not Pro (gate handled at the call-site too — belt and
//     braces, since the service also rejects non-Pro callers).
//   • The session was skipped (too short, too noisy, throat-clearing).
//   • The active practice locale isn't English.
//   • No AI provider is configured.
//   • The model surfaced nothing that crossed the threshold.
//
// VISION future-milestone #7 framing: grammar feedback "risks feeling
// pedantic". Silence is the right default — we do NOT render a soft
// positive on the empty case. If the rubric finds nothing worth saying,
// the card stays gone. The user already gets a session summary; what we
// don't want is the feature constantly chirping "looks clean" on every
// rep, because that becomes its own form of noise.
//
// Visual layout matches the surrounding speech-quality cards
// (EloquenceFindingsCard, PauseSummaryCard, etc.): micro header label,
// observational note per finding with a small pattern chip + excerpt.

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
            } else if let result, result.aiBacked, !result.findings.isEmpty {
                cardShell { content(result: result) }
            } else {
                // No findings worth surfacing → silent. Better silent than
                // pedantic. The grammar pass did run; we just don't chirp
                // about it.
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
        Text(headline(for: result))
            .font(Typography.headline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(result.findings) { finding in
                findingRow(finding)
            }
        }
    }

    private func findingRow(_ finding: GrammarFinding) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(finding.pattern.label)
                    .font(Typography.micro.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(severityTint(finding.severity))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(severityTint(finding.severity).opacity(0.10), in: Capsule())
                Spacer()
            }
            Text("\u{201C}\(finding.excerpt)\u{201D}")
                .font(Typography.caption.italic())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(finding.note)
                .font(Typography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }

    // MARK: - Helpers

    private func headline(for result: GrammarPolishResult) -> String {
        // Observational, not corrective. We're surfacing patterns, not
        // grading the user's English.
        let count = result.findings.count
        if count == 1 { return "One pattern worth noting" }
        return "\(count) patterns worth noting"
    }

    private func severityTint(_ severity: GrammarFinding.Severity) -> Color {
        switch severity {
        case .highImpact: return AppColor.caution
        case .routine:    return .secondary
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

        // M16: if the session already has persisted grammar findings,
        // use them directly. The grammar pass ran when the session was
        // saved; re-asking the model would re-spend quota for the same
        // input. An empty persisted array still means "ran and found
        // nothing" — silence is the right move.
        if let persisted = session.grammarFindings {
            await MainActor.run {
                result = GrammarPolishResult(
                    findings: persisted,
                    aiBacked: true,
                    generatedAt: session.date
                )
                isLoading = false
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
