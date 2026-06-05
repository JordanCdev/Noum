#if canImport(SwiftUI)
import SwiftUI

// MARK: - Coach Session
//
// The coach surface is now a "call", not a chat. This container defaults to the
// immersive LIVE call (`LiveCoachCallView`) — speaking with Noum face-to-face —
// and lets the user drop to the typed conversation (`AskNoumView`) and back.
// Both modes read/write the same `AskNoumStore` thread, so switching never loses
// context. Routed from `AppDestination.askNoum`.

@available(iOS 17.0, macOS 12.0, *)
struct CoachSessionView: View {
    @ObservedObject var sessionStore: PracticeSessionStore
    @ObservedObject var ratingStore: RatingStore
    @ObservedObject var coachingProfileStore: CoachingProfileStore
    @Binding var navigationPath: NavigationPath

    enum Mode { case live, type }
    @State private var mode: Mode

    init(
        sessionStore: PracticeSessionStore,
        ratingStore: RatingStore,
        coachingProfileStore: CoachingProfileStore,
        navigationPath: Binding<NavigationPath>,
        initialMode: Mode = .live
    ) {
        self.sessionStore = sessionStore
        self.ratingStore = ratingStore
        self.coachingProfileStore = coachingProfileStore
        self._navigationPath = navigationPath
        self._mode = State(initialValue: initialMode)
    }

    var body: some View {
        Group {
            switch mode {
            case .live:
                LiveCoachCallView(
                    onSwitchToType: { withAnimation(.easeInOut(duration: 0.25)) { mode = .type } },
                    onLeave: { if !navigationPath.isEmpty { navigationPath.removeLast() } }
                )
            case .type:
                AskNoumView(
                    sessionStore: sessionStore,
                    ratingStore: ratingStore,
                    coachingProfileStore: coachingProfileStore,
                    navigationPath: $navigationPath,
                    onGoLive: { withAnimation(.easeInOut(duration: 0.25)) { mode = .live } },
                    startsInTextMode: true
                )
            }
        }
    }
}

#endif
