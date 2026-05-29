#if canImport(SwiftUI)
import SwiftUI

// MARK: - Session Reflection Inline Card
//
// "How did that feel?" — the post-rep reflection capture. Renders inline
// in the summary card flow (mirroring DeferredCaptureInlineCard) rather
// than as an auto-popping sheet, so it never interrupts the coach's read,
// the score, or the next move. One tap records the user's self-reported
// feeling; the card then collapses to a quiet confirmation.
//
// UX contract:
//   • 1 tap to commit — feeling chips record immediately, no Save button.
//   • Self-hiding — renders nothing when there's no session, and collapses
//     to a confirmation once the session has been reflected on so the
//     question is never asked twice.
//   • Honest — the copy makes clear this is the user's own read, the one
//     thing the coach can't measure. Skipping (scrolling past) leaves no
//     reflection; nothing is fabricated.

@available(iOS 17.0, *)
struct SessionReflectionInlineCard: View {
    let sessionID: UUID?

    @StateObject private var store = SessionReflectionStore.shared
    @State private var justSaved = false
    @State private var note = ""

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        if let sessionID {
            if justSaved || store.hasReflected(for: sessionID) {
                confirmation
                    .transition(.opacity)
            } else {
                prompt(for: sessionID)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var confirmation: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColor.positive)
            Text("Noted — your coach will remember how that felt.")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(AppColor.positive.opacity(0.18), lineWidth: 1)
        )
    }

    private func prompt(for sessionID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColor.brandBlue)
                Text("How did that feel?")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
            }

            Text("One tap. This is the part your coach can't hear — only you can.")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("What made it feel that way? (optional)", text: $note, axis: .vertical)
                .font(Typography.caption)
                .lineLimit(1...3)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    AppColor.cardBackground,
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(AppColor.brandBlue.opacity(0.16), lineWidth: 1)
                )
                .accessibilityIdentifier("sessionReflection.note")
                .accessibilityLabel("Reflection note")
                .accessibilityHint("Optional. Tell your coach what made this rep feel that way.")
                .onChange(of: note) { _, updated in
                    if updated.count > SessionReflection.noteCharacterLimit {
                        note = String(updated.prefix(SessionReflection.noteCharacterLimit))
                    }
                }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ReflectionFeeling.allCases) { feeling in
                    chip(for: feeling, sessionID: sessionID)
                }
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
    private func chip(for feeling: ReflectionFeeling, sessionID: UUID) -> some View {
        Button {
            record(feeling, sessionID: sessionID)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: feeling.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.brandBlue)
                Text(feeling.chipLabel)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.white.opacity(0.85),
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(AppColor.brandBlue.opacity(0.18), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sessionReflection.option.\(feeling.rawValue)")
        .accessibilityLabel(feeling.chipLabel)
    }

    private func record(_ feeling: ReflectionFeeling, sessionID: UUID) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let reflection = store.record(sessionID: sessionID, feeling: feeling, note: note)
        CoachMemoryStore.shared.noteReflection(reflection.coachClause)
        withAnimation(.standardSpring) {
            justSaved = true
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Prompt") {
    SessionReflectionInlineCard(sessionID: UUID())
        .padding()
}
#endif

#endif
