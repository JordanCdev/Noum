import SwiftUI

/// Pure launch policy so UI automation can keep its existing immediate root
/// while one focused splash test can opt back into the production sequence.
enum SplashLaunchPolicy {
    static let uiTestingArgument = "UI_TESTING"
    static let uiTestingOptInArgument = "UI_TESTING_SPLASH"

    static func shouldPresent(arguments: [String]) -> Bool {
        !arguments.contains(uiTestingArgument)
            || arguments.contains(uiTestingOptInArgument)
    }
}

/// One clock shared by the SwiftUI implementation, tests, and the authored
/// Figma/Lottie handoff. Values are absolute seconds from first render.
enum SplashTimeline {
    static let secondBubble: TimeInterval = 0.70
    static let orangeSyllableOne: TimeInterval = 1.18
    static let orangeSyllableRest: TimeInterval = 1.45
    static let orangeSyllableTwo: TimeInterval = 1.72
    static let orangeTurnEnd: TimeInterval = 1.95
    static let yellowSyllableOne: TimeInterval = 2.15
    static let yellowSyllableRest: TimeInterval = 2.42
    static let yellowSyllableTwo: TimeInterval = 2.69
    static let yellowTurnEnd: TimeInterval = 2.92
    static let takeover: TimeInterval = 3.05
    static let wordmark: TimeInterval = 4.10
    static let completion: TimeInterval = 5.25
    static let reducedMotionCompletion: TimeInterval = 1.10

    static let pairTransition: TimeInterval = 0.50
    static let mouthTransition: TimeInterval = 0.22
    static let takeoverTransition: TimeInterval = 1.05
    static let wordmarkTransition: TimeInterval = 0.65
    static let homeTransition: TimeInterval = 0.40
    static let cameraZoomScale: CGFloat = 5.20
    static let conversationFocus = UnitPoint(x: 0.43, y: 0.44)

    static let orderedMilestones: [TimeInterval] = [
        secondBubble,
        orangeSyllableOne,
        orangeSyllableRest,
        orangeSyllableTwo,
        orangeTurnEnd,
        yellowSyllableOne,
        yellowSyllableRest,
        yellowSyllableTwo,
        yellowTurnEnd,
        takeover,
        wordmark,
        completion,
    ]

    static func cameraScale(reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 1 : cameraZoomScale
    }

}

/// A bounded, one-shot identity transition. It owns no account, hydration, or
/// routing state; `NoumApp` removes it and reveals the authoritative root.
struct SplashScreenView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .firstBubble

    private let onComplete: @MainActor () -> Void

    init(onComplete: @escaping @MainActor () -> Void) {
        self.onComplete = onComplete
    }

    var body: some View {
        GeometryReader { proxy in
            let markWidth = min(proxy.size.width * 0.68, 268)
            let markHeight = markWidth * 0.804
            let presentedPhase = reduceMotion ? Phase.wordmark : phase

            ZStack {
                Color.white

                immersedConversationField
                    .opacity(presentedPhase.fieldOpacity)

                conversationMark(width: markWidth, phase: presentedPhase)
                    .opacity(presentedPhase.markOpacity)
                    .scaleEffect(
                        presentedPhase.markScale(reduceMotion: reduceMotion),
                        anchor: SplashTimeline.conversationFocus
                    )
                    .offset(
                        x: presentedPhase.centersConversation
                            ? markWidth * (0.5 - SplashTimeline.conversationFocus.x)
                            : 0,
                        y: presentedPhase.centersConversation
                            ? markHeight * (0.5 - SplashTimeline.conversationFocus.y)
                            : 0
                    )

                Text("noum")
                    .font(Typography.splashWordmark)
                    .tracking(-1.5)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 36)
                    .opacity(presentedPhase.wordmarkOpacity)
                    .scaleEffect(presentedPhase.wordmarkScale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        // The launch canvas owns the full screen. Hiding system chrome keeps
        // dark-appearance status icons from disappearing into its white beat.
        .statusBarHidden(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Noum")
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("splash.screen")
        .task(id: reduceMotion) {
            await playSequence()
        }
    }

    /// The zoom resolves into the two characters' shared palette. The colour
    /// direction preserves their app-icon relationship: deeper orange behind
    /// the conversation, bright yellow arriving from the foreground speaker.
    private var immersedConversationField: some View {
        LinearGradient(
            stops: [
                .init(color: AppColor.splashOrangeShadow, location: 0.00),
                .init(color: AppColor.splashOrange, location: 0.28),
                .init(color: AppColor.splashOrangeHighlight, location: 0.50),
                .init(color: AppColor.splashYellowShadow, location: 0.72),
                .init(color: AppColor.splashYellow, location: 0.88),
                .init(color: AppColor.splashYellowHighlight, location: 1.00),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func conversationMark(width: CGFloat, phase: Phase) -> some View {
        ZStack(alignment: .topLeading) {
            SplashRearBubbleView()
                .frame(width: width * 0.597, height: width * 0.655)
                .environment(\.splashRearMouthOpenness, phase.orangeMouthOpenness)

            if phase.showsPair {
                SplashFrontBubbleView()
                    .frame(width: width * 0.654, height: width * 0.640)
                    .offset(
                        x: width * 0.347,
                        y: width * 0.164
                    )
                    .environment(\.splashFrontMouthOpenness, phase.yellowMouthOpenness)
                    .transition(.opacity)
            }
        }
        .frame(width: width, height: width * 0.804, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    @MainActor
    private func playSequence() async {
        if reduceMotion {
            phase = .wordmark
            guard await wait(SplashTimeline.reducedMotionCompletion) else { return }
            onComplete()
            return
        }

        phase = .firstBubble

        guard await wait(SplashTimeline.secondBubble) else { return }
        setPhase(
            .pair,
            animation: .easeInOut(duration: SplashTimeline.pairTransition)
        )

        guard await wait(
            SplashTimeline.orangeSyllableOne - SplashTimeline.secondBubble
        ) else { return }
        setPhase(.orangeSyllableOne, animation: mouthAnimation)

        guard await wait(
            SplashTimeline.orangeSyllableRest - SplashTimeline.orangeSyllableOne
        ) else { return }
        setPhase(.orangeSyllableRest, animation: mouthAnimation)

        guard await wait(
            SplashTimeline.orangeSyllableTwo - SplashTimeline.orangeSyllableRest
        ) else { return }
        setPhase(.orangeSyllableTwo, animation: mouthAnimation)

        guard await wait(
            SplashTimeline.orangeTurnEnd - SplashTimeline.orangeSyllableTwo
        ) else { return }
        setPhase(.orangeTurnEnd, animation: mouthAnimation)

        guard await wait(
            SplashTimeline.yellowSyllableOne - SplashTimeline.orangeTurnEnd
        ) else { return }
        setPhase(.yellowSyllableOne, animation: mouthAnimation)

        guard await wait(
            SplashTimeline.yellowSyllableRest - SplashTimeline.yellowSyllableOne
        ) else { return }
        setPhase(.yellowSyllableRest, animation: mouthAnimation)

        guard await wait(
            SplashTimeline.yellowSyllableTwo - SplashTimeline.yellowSyllableRest
        ) else { return }
        setPhase(.yellowSyllableTwo, animation: mouthAnimation)

        guard await wait(
            SplashTimeline.yellowTurnEnd - SplashTimeline.yellowSyllableTwo
        ) else { return }
        setPhase(.yellowTurnEnd, animation: mouthAnimation)

        guard await wait(
            SplashTimeline.takeover - SplashTimeline.yellowTurnEnd
        ) else { return }
        setPhase(
            .takeover,
            animation: .easeInOut(duration: SplashTimeline.takeoverTransition)
        )

        guard await wait(SplashTimeline.wordmark - SplashTimeline.takeover) else { return }
        setPhase(
            .wordmark,
            animation: .easeOut(duration: SplashTimeline.wordmarkTransition)
        )

        guard await wait(SplashTimeline.completion - SplashTimeline.wordmark) else { return }
        onComplete()
    }

    @MainActor
    private var mouthAnimation: Animation {
        .easeInOut(duration: SplashTimeline.mouthTransition)
    }

    @MainActor
    private func setPhase(_ newPhase: Phase, animation: Animation) {
        withAnimation(animation) {
            phase = newPhase
        }
    }

    private func wait(_ seconds: TimeInterval) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

private extension SplashScreenView {
    enum Phase: Equatable {
        case firstBubble
        case pair
        case orangeSyllableOne
        case orangeSyllableRest
        case orangeSyllableTwo
        case orangeTurnEnd
        case yellowSyllableOne
        case yellowSyllableRest
        case yellowSyllableTwo
        case yellowTurnEnd
        case takeover
        case wordmark

        var showsPair: Bool {
            self != .firstBubble && self != .wordmark
        }

        var fieldOpacity: Double {
            self == .takeover || self == .wordmark ? 1 : 0
        }

        var centersConversation: Bool {
            self == .takeover || self == .wordmark
        }

        var wordmarkOpacity: Double {
            self == .wordmark ? 1 : 0
        }

        var wordmarkScale: CGFloat {
            self == .wordmark ? 1 : 0.82
        }

        var markOpacity: Double {
            switch self {
            case .takeover: 0.04
            case .wordmark: 0
            default: 1
            }
        }

        func markScale(reduceMotion: Bool) -> CGFloat {
            switch self {
            case .takeover, .wordmark:
                SplashTimeline.cameraScale(reduceMotion: reduceMotion)
            default:
                1
            }
        }

        var orangeMouthOpenness: CGFloat {
            switch self {
            case .orangeSyllableOne: 1
            case .orangeSyllableRest: 0.38
            case .orangeSyllableTwo: 0.88
            default: 0.22
            }
        }

        var yellowMouthOpenness: CGFloat {
            switch self {
            case .yellowSyllableOne: 1
            case .yellowSyllableRest: 0.45
            case .yellowSyllableTwo: 0.90
            default: 0.35
            }
        }
    }
}

private struct SplashRearMouthOpennessKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0.22
}

private struct SplashFrontMouthOpennessKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0.35
}

private extension EnvironmentValues {
    var splashRearMouthOpenness: CGFloat {
        get { self[SplashRearMouthOpennessKey.self] }
        set { self[SplashRearMouthOpennessKey.self] = newValue }
    }

    var splashFrontMouthOpenness: CGFloat {
        get { self[SplashFrontMouthOpennessKey.self] }
        set { self[SplashFrontMouthOpennessKey.self] = newValue }
    }
}

private struct SplashRearBubbleView: View {
    @Environment(\.splashRearMouthOpenness) private var mouthOpenness

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                SplashRearBubbleShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColor.splashOrangeHighlight,
                                AppColor.splashOrange,
                                AppColor.splashOrangeShadow,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                SplashRearBubbleShape()
                    .stroke(
                        AppColor.splashOrangeHighlight,
                        style: StrokeStyle(
                            lineWidth: max(2, width * 0.022),
                            lineJoin: .round
                        )
                    )

                Path { path in
                    path.move(to: CGPoint(x: width * 0.286, y: height * 0.265))
                    path.addCurve(
                        to: CGPoint(x: width * 0.433, y: height * 0.265),
                        control1: CGPoint(x: width * 0.325, y: height * 0.202),
                        control2: CGPoint(x: width * 0.399, y: height * 0.202)
                    )
                    path.move(to: CGPoint(x: width * 0.544, y: height * 0.265))
                    path.addCurve(
                        to: CGPoint(x: width * 0.692, y: height * 0.264),
                        control1: CGPoint(x: width * 0.581, y: height * 0.202),
                        control2: CGPoint(x: width * 0.657, y: height * 0.202)
                    )
                }
                .stroke(
                    AppColor.splashFaceYellow,
                    style: StrokeStyle(
                        lineWidth: max(3, width * 0.024),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                SplashRearMouthShape(openness: mouthOpenness)
                .fill(AppColor.splashFaceYellow)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The rear character's body never moves during conversation. Only this
/// mouth interpolates between a resting smile and two open phoneme shapes.
private struct SplashRearMouthShape: Shape {
    var openness: CGFloat

    var animatableData: CGFloat {
        get { openness }
        set { openness = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let amount = min(max(openness, 0), 1)
        let width = rect.width
        let height = rect.height
        let depth = 0.026 + (0.069 * amount)
        let bottomY = 0.343 + depth
        var path = Path()

        path.move(to: CGPoint(x: width * 0.356, y: height * 0.343))
        path.addCurve(
            to: CGPoint(x: width * 0.630, y: height * 0.343),
            control1: CGPoint(x: width * 0.416, y: height * (0.343 + depth * 0.42)),
            control2: CGPoint(x: width * 0.574, y: height * (0.343 + depth * 0.52))
        )
        path.addCurve(
            to: CGPoint(x: width * 0.494, y: height * bottomY),
            control1: CGPoint(x: width * 0.606, y: height * (0.343 + depth * 0.86)),
            control2: CGPoint(x: width * 0.555, y: height * bottomY)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.356, y: height * 0.343),
            control1: CGPoint(x: width * 0.430, y: height * bottomY),
            control2: CGPoint(x: width * 0.384, y: height * (0.343 + depth * 0.70))
        )
        path.closeSubpath()

        return path
    }
}

private struct SplashFrontBubbleView: View {
    @Environment(\.splashFrontMouthOpenness) private var mouthOpenness

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                SplashFrontBubbleShape(mouthOpenness: mouthOpenness)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColor.splashYellowHighlight,
                                AppColor.splashYellow,
                                AppColor.splashYellowShadow,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: AppColor.splashInk.opacity(0.18),
                        radius: max(3, width * 0.025),
                        x: width * 0.016,
                        y: width * 0.026
                    )

                SplashFrontBubbleShape(mouthOpenness: mouthOpenness)
                    .stroke(
                        AppColor.splashYellowHighlight,
                        style: StrokeStyle(
                            lineWidth: max(2, width * 0.018),
                            lineJoin: .round
                        )
                    )

                Circle()
                    .fill(AppColor.splashInk)
                    .frame(width: width * 0.124, height: height * 0.120)
                    .position(x: width * 0.321, y: height * 0.272)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Traced from the rear orange character in the shipping app icon: a
/// round head that narrows into a soft lower-left speech tail.
private struct SplashRearBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let x = rect.width
        let y = rect.height
        var path = Path()

        path.move(to: CGPoint(x: x * 0.020, y: y * 0.971))
        path.addCurve(
            to: CGPoint(x: x * 0.130, y: y * 0.741),
            control1: CGPoint(x: x * 0.110, y: y * 0.883),
            control2: CGPoint(x: x * 0.150, y: y * 0.811)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.040, y: y * 0.558),
            control1: CGPoint(x: x * 0.120, y: y * 0.680),
            control2: CGPoint(x: x * 0.070, y: y * 0.620)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.070, y: y * 0.160),
            control1: CGPoint(x: x * -0.020, y: y * 0.420),
            control2: CGPoint(x: x * -0.010, y: y * 0.270)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.490, y: 0),
            control1: CGPoint(x: x * 0.160, y: y * 0.030),
            control2: CGPoint(x: x * 0.340, y: 0)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.980, y: y * 0.310),
            control1: CGPoint(x: x * 0.720, y: 0),
            control2: CGPoint(x: x * 0.910, y: y * 0.120)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.750, y: y * 0.870),
            control1: CGPoint(x: x * 1.050, y: y * 0.520),
            control2: CGPoint(x: x * 0.930, y: y * 0.740)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.030, y: y),
            control1: CGPoint(x: x * 0.560, y: y),
            control2: CGPoint(x: x * 0.300, y: y * 1.020)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.020, y: y * 0.971),
            control1: CGPoint(x: x * 0.010, y: y),
            control2: CGPoint(x: x * 0.005, y: y * 0.987)
        )
        path.closeSubpath()

        return path
    }
}

/// Traced from the foreground yellow character in the shipping app icon.
/// The left-side notch is its open talking mouth; the lower-right curl is the
/// app icon's distinctive speech tail.
private struct SplashFrontBubbleShape: Shape {
    var mouthOpenness: CGFloat

    var animatableData: CGFloat {
        get { mouthOpenness }
        set { mouthOpenness = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let x = rect.width
        let y = rect.height
        let amount = min(max(mouthOpenness, 0), 1)
        let lowerTipX = 0.119 + (0.080 * amount)
        let lowerTipY = 0.364 + (0.017 * amount)
        let upperTipX = 0.116 + (0.065 * amount)
        let upperTipY = 0.364 - (0.010 * amount)
        var path = Path()

        path.move(to: CGPoint(x: x * 0.053, y: y * 0.313))
        path.addCurve(
            to: CGPoint(x: x * 0.539, y: y * 0.002),
            control1: CGPoint(x: x * 0.165, y: y * 0.109),
            control2: CGPoint(x: x * 0.329, y: y * 0.006)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.994, y: y * 0.382),
            control1: CGPoint(x: x * 0.793, y: y * -0.005),
            control2: CGPoint(x: x * 0.972, y: y * 0.164)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.854, y: y * 0.759),
            control1: CGPoint(x: x * 1.016, y: y * 0.530),
            control2: CGPoint(x: x * 0.963, y: y * 0.657)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.860, y: y * 0.976),
            control1: CGPoint(x: x * 0.779, y: y * 0.829),
            control2: CGPoint(x: x * 0.766, y: y * 0.913)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.851, y: y * 0.998),
            control1: CGPoint(x: x * 0.882, y: y * 0.990),
            control2: CGPoint(x: x * 0.878, y: y)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.588, y: y * 0.925),
            control1: CGPoint(x: x * 0.759, y: y * 0.995),
            control2: CGPoint(x: x * 0.675, y: y * 0.964)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.026, y: y * 0.557),
            control1: CGPoint(x: x * 0.345, y: y * 0.907),
            control2: CGPoint(x: x * 0.133, y: y * 0.771)
        )
        path.addLine(to: CGPoint(x: x * 0.002, y: y * 0.496))
        path.addCurve(
            to: CGPoint(x: x * 0.028, y: y * 0.459),
            control1: CGPoint(x: x * -0.004, y: y * 0.477),
            control2: CGPoint(x: x * 0.008, y: y * 0.463)
        )
        path.addCurve(
            to: CGPoint(x: x * lowerTipX, y: y * lowerTipY),
            control1: CGPoint(x: x * 0.108, y: y * 0.444),
            control2: CGPoint(x: x * (lowerTipX - 0.018), y: y * 0.412)
        )
        path.addCurve(
            to: CGPoint(x: x * upperTipX, y: y * upperTipY),
            control1: CGPoint(x: x * (lowerTipX + 0.009), y: y * 0.365),
            control2: CGPoint(x: x * (upperTipX + 0.018), y: y * 0.357)
        )
        path.addLine(to: CGPoint(x: x * 0.064, y: y * 0.334))
        path.addCurve(
            to: CGPoint(x: x * 0.053, y: y * 0.313),
            control1: CGPoint(x: x * 0.049, y: y * 0.331),
            control2: CGPoint(x: x * 0.043, y: y * 0.321)
        )
        path.closeSubpath()

        return path
    }
}

#Preview("Splash") {
    SplashScreenView(onComplete: {})
}
