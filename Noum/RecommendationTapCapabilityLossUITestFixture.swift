import Foundation

/// DEBUG-gated source/tap split used to render a real recommendation and then
/// exercise the production capability-loss defense at the moment of launch.
///
/// The fixture never mutates RatingStore, AISettingsManager, recommendation
/// persistence, or navigation. It supplies the visible source blueprint and
/// the later live capability snapshot; presentation, exposure, routing, and
/// attribution remain owned by the same production code as a real mid-session
/// availability loss.
enum RecommendationTapCapabilityLossUITestFixture {
    enum Capability: String, Equatable {
        case pressure
        case conversation
    }

    static let argumentName = "UI_TESTING_RECOMMENDATION_TAP_CAPABILITY_LOSS"
    static let interruptedQuickStartArgumentName =
        "UI_TESTING_RECOMMENDATION_INTERRUPTED_QUICK_START"

    static func blueprintForRendering(
        _ current: RecommendationBiasBlueprint,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> RecommendationBiasBlueprint {
        #if DEBUG
        guard requestedCapability(arguments: arguments) == .pressure else {
            return current
        }
        let pressureBenefit = RecommendationBiasEngine.playbook.first {
            $0.mode == .suddenDeath
        }
        return RecommendationBiasBlueprint(
            recommendedMode: .suddenDeath,
            recommendedTone: nil,
            recommendedScenario: nil,
            focus: "Composure under pressure",
            target: "Hold one clear answer under the clock",
            modeBenefit: pressureBenefit?.benefit
                ?? "Builds composure when the clock adds pressure.",
            whyMode: pressureBenefit?.bestFor
                ?? "Pressure Drill rehearses clear answers under a hard clock.",
            whyNow: "Recent pressure reps make composure the next useful focus.",
            suggestedTimedDifficulty: nil,
            suggestedTheme: current.suggestedTheme,
            source: current.source
        )
        #else
        return current
        #endif
    }

    static func availabilityAtTap(
        _ current: NextActionModeAvailability,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> NextActionModeAvailability {
        #if DEBUG
        switch requestedCapability(arguments: arguments) {
        case .pressure:
            return NextActionModeAvailability(
                suddenDeathAvailable: false,
                imConversationAvailable: current.imConversationAvailable
            )
        case .conversation:
            return NextActionModeAvailability(
                suddenDeathAvailable: current.suddenDeathAvailable,
                imConversationAvailable: false
            )
        case nil:
            return current
        }
        #else
        return current
        #endif
    }

    /// Supplies a finalized-action-shaped source for the real Summary
    /// renderer. Summary remains responsible for availability projection,
    /// exposure, tap attribution, and routing; this only makes the otherwise
    /// timing-dependent Pressure branch deterministic in UI coverage.
    static func summaryActionForRendering(
        _ current: NextAction?,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> NextAction? {
        #if DEBUG
        guard requestedCapability(arguments: arguments) == .pressure else {
            return current
        }
        let reason = "Test the same control under one bounded pressure rep."
        return NextAction(
            primary: .pressureExposure(.suddenDeath, reason: reason),
            secondary: nil,
            reasoning: "Recent pressure evidence makes composure the next useful test.",
            confidenceLevel: .moderate
        )
        #else
        return current
        #endif
    }

    /// Optional stale handshake for the rendered fallback test. Returning a
    /// mode keeps mutation in the existing app test harness rather than this
    /// fixture; Release and ordinary UI-test launches always return nil.
    static func interruptedQuickStartMode(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> PracticeMode? {
        #if DEBUG
        guard requestedCapability(arguments: arguments) != nil,
              arguments.contains(interruptedQuickStartArgumentName) else {
            return nil
        }
        return .timed
        #else
        return nil
        #endif
    }

    static func imAvailableAtTap(
        _ current: Bool,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        #if DEBUG
        return requestedCapability(arguments: arguments) == .conversation
            ? false
            : current
        #else
        return current
        #endif
    }

    #if DEBUG
    private static func requestedCapability(arguments: [String]) -> Capability? {
        guard arguments.contains("UI_TESTING"),
              let index = arguments.firstIndex(of: argumentName),
              index + 1 < arguments.count else {
            return nil
        }
        return Capability(rawValue: arguments[index + 1])
    }
    #endif
}
