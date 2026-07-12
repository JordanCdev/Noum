#if canImport(SwiftUI)
import SwiftUI
#if canImport(Speech)
import Speech
#endif
#if canImport(AVFAudio)
import AVFAudio
#endif

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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Mode: Equatable { case live, type }
    @State private var mode: Mode
    @State private var flowCorrelationID = UUID()

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
        // V7 — resolve the *actual* starting door from the requested intent.
        // A caller asking for the immersive live call is only honored when the
        // call can really hear the user and completed-rep evidence exists;
        // otherwise we land in the readable typed chat (which carries the honest
        // deterministic day-0 greeting) instead of stranding a nervous,
        // permission-blocked beginner in a "Listening…" state.
        let resolved: Mode = {
            #if DEBUG
            if initialMode == .live,
               ProcessInfo.processInfo.arguments.contains("UI_TESTING_FORCE_LIVE_COACH") {
                return .live
            }
            #endif
            return Self.resolvedInitialMode(
                requested: initialMode,
                voiceAccessible: Self.voiceAccessibleNow(),
                hasCompletedReps: !sessionStore.sessions.isEmpty,
                hasVoiceProfile: coachingProfileStore.profile?.chosenStyleGoal != nil
            )
        }()
        self._mode = State(initialValue: resolved)
    }

    // MARK: - Day-0 door resolution
    //
    // V7 — the cold-start finding: defaulting every coach entry to the
    // immersive CALL is the wrong day-0 door for a nervous beginner with no
    // voice profile and possibly no mic permission. The live call only reveals
    // its "Type instead" escape after a 6s dead-mic window, so a
    // permission-blocked first contact reads as "frozen". This resolver routes
    // such a user to the typed chat — which is reachable, readable, and already
    // owns the honest deterministic day-0 greeting — while a returning user who
    // has granted voice access keeps the call. A chosen voice personalizes the
    // coach after evidence exists; it is not evidence and cannot bypass rep one.
    // Pure + view-free so the routing decision is unit-testable without standing
    // up the recognizer.

    /// Resolve the starting mode from the *requested* intent. An explicit
    /// `.type` request (e.g. the `askNoumTyped` destination) is always honored.
    /// A `.live` request falls back to `.type` when voice isn't actually
    /// accessible, or when the user has no completed rep — they meet the coach
    /// at the shared first-rep door in text first.
    static func resolvedInitialMode(
        requested: Mode,
        voiceAccessible: Bool,
        hasCompletedReps: Bool,
        hasVoiceProfile _: Bool
    ) -> Mode {
        guard requested == .live else { return requested }
        guard voiceAccessible else { return .type }
        guard AskNoumStore.hasCompletedPracticeEvidence(
            sessionCount: hasCompletedReps ? 1 : 0
        ) else {
            return .type
        }
        return .live
    }

    /// Best-effort, synchronous read of whether the live call can actually hear
    /// the user *now* — speech recognition authorized AND mic record permission
    /// granted. Cheap (no recognizer setup), so it's safe at route time.
    /// `.undetermined` counts as not-yet-accessible on purpose: a first-time
    /// user starts in the readable chat, then opts into the call when ready.
    private static func voiceAccessibleNow() -> Bool {
        #if canImport(Speech) && canImport(AVFAudio)
        let speechOK = SFSpeechRecognizer.authorizationStatus() == .authorized
        let micOK = AVAudioApplication.shared.recordPermission == .granted
        return speechOK && micOK
        #else
        return false
        #endif
    }

    private var hasCompletedPracticeEvidence: Bool {
        AskNoumStore.hasCompletedPracticeEvidence(
            sessionCount: sessionStore.sessions.count
        )
    }

    var body: some View {
        Group {
            if !hasCompletedPracticeEvidence {
                // One shared day-0 door. Passing no live action removes
                // "Start coach call" from the thread menu, while the typed
                // surface keeps its existing first-rep explanation + CTA.
                typedSurface(onGoLive: nil)
            } else {
                switch mode {
                case .live:
                    LiveCoachCallView(
                        hasCompletedPracticeEvidence: hasCompletedPracticeEvidence,
                        onSwitchToType: { transition(to: .type) },
                        onLeave: { if !navigationPath.isEmpty { navigationPath.removeLast() } }
                    )
                case .type:
                    typedSurface(onGoLive: enterLiveIfEligible)
                }
            }
        }
        .onAppear {
            guard mode == .type else { return }
            FlowEventLog.shared.logOnce(FlowEvent.make(
                correlationId: flowCorrelationID,
                flow: .other,
                stage: "coach.typedOpened",
                reason: "typed coach surface opened"
            ))
        }
    }

    /// The typed surface is also the first-rep gate. Keeping its construction
    /// in one helper prevents the gated and returning-user variants from
    /// drifting in profile, rating, or navigation ownership.
    private func typedSurface(onGoLive: (() -> Void)?) -> some View {
        AskNoumView(
            sessionStore: sessionStore,
            ratingStore: ratingStore,
            coachingProfileStore: coachingProfileStore,
            navigationPath: $navigationPath,
            onGoLive: onGoLive,
            startsInTextMode: true
        )
    }

    /// Re-check evidence at tap time as well as render time. This closes the
    /// stale-menu-action race if the last rep is deleted while the menu is
    /// already open.
    private func enterLiveIfEligible() {
        guard hasCompletedPracticeEvidence else {
            mode = .type
            return
        }
        transition(to: .live)
    }

    private func transition(to nextMode: Mode) {
        guard mode != nextMode else { return }
        if mode == .type, nextMode == .live {
            FlowEventLog.shared.logOnce(FlowEvent.make(
                correlationId: flowCorrelationID,
                flow: .other,
                stage: "coach.typedToLive",
                reason: "user upgraded from typed coach to live coach"
            ))
        }
        if reduceMotion {
            mode = nextMode
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                mode = nextMode
            }
        }
    }
}

#endif
