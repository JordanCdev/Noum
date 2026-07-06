// ReflectionCaptureRow.swift
//
// One-tap post-rep reflection intake — the production call site for
// `SessionReflectionStore.record`, closing the subjective-experience stage of
// the coaching loop (VISION: "an intervention cycle must invite short
// reflection at the right moments"). The store, the four feelings, and the
// downstream `CoachReflectionPattern` pipeline all shipped earlier; this row
// is the missing intake that actually feeds them.
//
// Design contract (the reason the earlier reflection card was cut in the
// summary subtraction — do not regress it):
//   • Lives INSIDE Summary's "More from this rep" disclosure, never the hero
//     block, so it cannot compete with the coach's read.
//   • Optional by design: scrolling past IS declining. No modal, no nag, no
//     badge, no streak.
//   • One tap answers it. Once answered it collapses to a quiet "Noted" line
//     (the store's own documented contract via `hasReflected(for:)`) so the
//     question is never asked twice — and the user can re-tap to change
//     their mind (`record` replaces the earlier answer for the same rep).
//   • State swap is plain (no theatrical motion), so it respects
//     reduced-motion by construction.

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, *)
struct ReflectionCaptureRow: View {
    let sessionID: UUID?
    @ObservedObject private var store = SessionReflectionStore.shared
    @State private var isRevising = false

    var body: some View {
        if let sessionID {
            if let existing = store.reflection(for: sessionID), !isRevising {
                noted(existing)
            } else {
                prompt(for: sessionID)
            }
        }
    }

    private func prompt(for sessionID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How did that rep feel?")
                .font(Typography.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(ReflectionFeeling.allCases) { feeling in
                    Button {
                        store.record(sessionID: sessionID, feeling: feeling)
                        isRevising = false
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: feeling.symbolName)
                                .font(.caption)
                            Text(feeling.chipLabel)
                                .font(Typography.caption)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(feeling.chipLabel)
                    .accessibilityHint("Logs how this rep felt for your coach")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func noted(_ reflection: SessionReflection) -> some View {
        Button {
            isRevising = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.caption2)
                Text("Noted — \(reflection.feeling.chipLabel.lowercased())")
                    .font(Typography.caption)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reflection noted: \(reflection.feeling.chipLabel). Tap to change.")
    }
}

#endif
