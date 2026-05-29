#if canImport(SwiftUI)
import SwiftUI

// MARK: - Deferred Capture Inline Card (M14 UX rework)
//
// Inline replacement for the old full-screen `DeferredProfileCaptureSheet`.
// Surfaces below the rep results so the user can fill it in alongside
// reading their score, or scroll past — no modal block, no decision
// pressure. Captured text becomes visible on Profile in the "In your own
// words" section so users see their reflection being held by the app.
//
// Renders nothing when there's no pending prompt. This means it only
// appears at session-count milestones (1 / 3 / 7) for the matching
// unanswered prompt — same trigger cadence as before, just without the
// modal hijack.

@available(iOS 17.0, *)
struct DeferredCaptureInlineCard: View {
    @StateObject private var manager = DeferredProfileCaptureManager.shared
    @State private var text: String = ""
    @State private var isExpanded = false
    @FocusState private var isFocused: Bool

    var body: some View {
        if let prompt = manager.pendingPrompt {
            content(for: prompt)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private func content(for prompt: DeferredProfileCaptureManager.Prompt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColor.brandBlue)
                Text("Quick reflection")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Button {
                    manager.skip(prompt)
                    text = ""
                    isExpanded = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 22, height: 22)
                        .background(Color.secondary.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss reflection")
            }

            Text(prompt.headline)
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(prompt.hint)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isExpanded {
                editor(for: prompt)
            } else {
                Button {
                    withAnimation(.standardSpring) {
                        isExpanded = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        isFocused = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 13, weight: .bold))
                        Text("Add a sentence")
                            .font(Typography.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppColor.brandBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColor.brandBlue.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    AppColor.brandBlue.opacity(0.06),
                    AppColor.brandBlueLight.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(AppColor.brandBlue.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func editor(for prompt: DeferredProfileCaptureManager.Prompt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(prompt.placeholder)
                        .font(Typography.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $text)
                    .font(Typography.body)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 96)
            }
            .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(isFocused ? AppColor.brandBlue.opacity(0.40) : AppColor.brandBlue.opacity(0.18), lineWidth: 1)
            )

            HStack {
                Button {
                    manager.skip(prompt)
                    text = ""
                    isExpanded = false
                    isFocused = false
                } label: {
                    Text("Skip")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    manager.submit(text, for: prompt)
                    text = ""
                    isExpanded = false
                    isFocused = false
                } label: {
                    HStack(spacing: 6) {
                        Text("Save")
                            .font(Typography.headline)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        canSubmit(prompt) ? AppColor.brandBlue : Color.secondary.opacity(0.5),
                        in: Capsule()
                    )
                }
                .disabled(!canSubmit(prompt))
                .buttonStyle(.plain)
            }
        }
    }

    private func canSubmit(_ prompt: DeferredProfileCaptureManager.Prompt) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= prompt.minLength
    }
}

#endif
