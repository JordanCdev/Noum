import Foundation
import StoreKit
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Review prompts are a response to demonstrated value, never part of launch,
/// recovery, or a paywall. The caller owns identifying the first verified
/// improvement; this policy owns timing and per-version restraint.
enum AppReviewPromptMoment: Equatable, Sendable {
    case qualifyingRepCompleted
    case firstVerifiedImprovement
    case appLaunch
    case errorOrRecovery
}

struct AppReviewPromptContext: Equatable, Sendable {
    let moment: AppReviewPromptMoment
    let qualifyingRepCount: Int
    let currentVersion: String
    let lastRequestedVersion: String?
}

enum AppReviewPromptDecision: Equatable, Sendable {
    case eligible
    case insufficientValue
    case inappropriateMoment
    case alreadyRequestedThisVersion
    case versionUnavailable
}

/// Arms an eligible Summary satisfaction moment without presenting anything.
/// The intent can be consumed only by Summary's explicit Done/exit action, so
/// rendering results or waiting on the screen can never request StoreKit UI.
struct SummaryReviewPromptExitGate: Equatable, Sendable {
    private(set) var pendingMoment: AppReviewPromptMoment?

    mutating func arm(_ moment: AppReviewPromptMoment) {
        pendingMoment = moment
    }

    mutating func consumeForExplicitExit() -> AppReviewPromptMoment? {
        defer { pendingMoment = nil }
        return pendingMoment
    }
}

enum AppReviewPromptPolicy {
    static let minimumQualifyingRepCount = 3

    static func decision(for context: AppReviewPromptContext) -> AppReviewPromptDecision {
        let version = context.currentVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty else { return .versionUnavailable }
        guard context.lastRequestedVersion != version else {
            return .alreadyRequestedThisVersion
        }

        switch context.moment {
        case .appLaunch, .errorOrRecovery:
            return .inappropriateMoment
        case .firstVerifiedImprovement:
            return .eligible
        case .qualifyingRepCompleted:
            return context.qualifyingRepCount >= minimumQualifyingRepCount
                ? .eligible
                : .insufficientValue
        }
    }
}

/// Small persistence adapter around the pure policy. It records the version
/// immediately before asking StoreKit, because Apple may choose not to display
/// UI and provides no presentation callback. Nothing invokes this automatically.
@MainActor
final class AppReviewPromptCoordinator {
    static let lastRequestedVersionKey = "NoumAppReviewLastRequestedVersion"

    private let defaults: UserDefaults
    private let versionProvider: () -> String

    init(
        defaults: UserDefaults = .standard,
        versionProvider: @escaping () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        }
    ) {
        self.defaults = defaults
        self.versionProvider = versionProvider
    }

    @discardableResult
    func requestIfEligible(
        moment: AppReviewPromptMoment,
        qualifyingRepCount: Int,
        request: () -> Void
    ) -> AppReviewPromptDecision {
        let version = versionProvider()
        let context = AppReviewPromptContext(
            moment: moment,
            qualifyingRepCount: qualifyingRepCount,
            currentVersion: version,
            lastRequestedVersion: defaults.string(forKey: Self.lastRequestedVersionKey)
        )
        let decision = AppReviewPromptPolicy.decision(for: context)
        guard decision == .eligible else { return decision }

        defaults.set(version, forKey: Self.lastRequestedVersionKey)
        request()
        return .eligible
    }

    #if canImport(SwiftUI)
    @available(iOS 16.0, macOS 13.0, macCatalyst 16.0, *)
    @discardableResult
    func requestIfEligible(
        moment: AppReviewPromptMoment,
        qualifyingRepCount: Int,
        using requestReview: RequestReviewAction
    ) -> AppReviewPromptDecision {
        requestIfEligible(
            moment: moment,
            qualifyingRepCount: qualifyingRepCount,
            request: { requestReview() }
        )
    }
    #endif

    #if canImport(UIKit)
    @available(iOS 14.0, *)
    @discardableResult
    func requestIfEligible(
        moment: AppReviewPromptMoment,
        qualifyingRepCount: Int,
        in scene: UIWindowScene
    ) -> AppReviewPromptDecision {
        requestIfEligible(
            moment: moment,
            qualifyingRepCount: qualifyingRepCount,
            request: { SKStoreReviewController.requestReview(in: scene) }
        )
    }
    #endif
}
