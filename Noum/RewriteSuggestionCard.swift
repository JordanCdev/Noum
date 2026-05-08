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

    @State private var rewrite: Rewrite?
    @State private var isLoading = false
    @State private var didFail = false
    @State private var showOriginal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isLoading {
                loadingState
            } else if let rewrite {
                rewrittenState(rewrite)
            } else if didFail {
                failureState
            } else {
                emptyState
            }

            voicePreservationFootnote
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
    }

    private var rewriteID: String { "\(weakness.rawValue)-\(transcript.hashValue)" }

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
        isLoading = true
        didFail = false
        let result = await AIRewriteService.shared.rewrite(transcript: transcript, weakness: weakness)
        await MainActor.run {
            isLoading = false
            if let result {
                withAnimation(.standardSpring) { rewrite = result }
            } else {
                didFail = true
            }
        }
    }
}

#endif
