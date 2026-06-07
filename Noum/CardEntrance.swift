#if canImport(SwiftUI)
import SwiftUI

// MARK: - Card Entrance
//
// Cheap, repeatable entrance animation: subtle scale-up + opacity fade.
// Use on every primary card on home so the screen feels composed
// rather than dropping all at once.
//
// Timing tuned to be fast — 350ms total, no longer than the app's
// `standardSpring`. Heavier motion would be cute the first time and
// annoying every time after.

@available(iOS 17.0, macOS 12.0, *)
struct CardEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let index: Int
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion || hasAppeared ? 1 : 0.96)
            .opacity(hasAppeared ? 1 : 0)
            .onAppear {
                guard !hasAppeared else { return }
                let delay = min(0.05 * Double(index), 0.30)
                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84).delay(delay)) {
                        hasAppeared = true
                    }
                }
            }
    }
}

extension View {
    /// Apply a staggered entrance to a card. Pass a 0-based index — the
    /// further down the stack, the more delay (capped at 300ms total so
    /// the last card doesn't feel slow).
    @available(iOS 17.0, macOS 12.0, *)
    func cardEntrance(_ index: Int) -> some View {
        modifier(CardEntranceModifier(index: index))
    }
}

#endif
