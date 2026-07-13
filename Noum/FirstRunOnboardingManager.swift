import Foundation

// MARK: - Fast-lane draft

/// Account-scoped progress captured before the user completes the full
/// coaching profile. This is deliberately not a `CoachingProfile`: publishing
/// a profile after only two choices would make every profile-gated coaching
/// surface treat default confidence, outcome, and voice values as user truth.
///
/// `CoachingProfileStore.profile` therefore remains the sole full-onboarding
/// truth. The same store owns this draft and removes it only after a complete
/// profile has been durably verified.
struct CoachingProfileDraft: Codable, Equatable {
    /// Stable, content-free identity used to pair activation flow events across
    /// interruption and relaunch.
    let correlationID: UUID
    let speakingContext: SpeakingContext
    let speakingChallenge: SpeakingChallenge
    let createdAt: Date
    var updatedAt: Date
    var firstValueReceipt: FirstValueReceipt?

    init(
        correlationID: UUID = UUID(),
        speakingContext: SpeakingContext,
        speakingChallenge: SpeakingChallenge,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        firstValueReceipt: FirstValueReceipt? = nil
    ) {
        self.correlationID = correlationID
        self.speakingContext = speakingContext
        self.speakingChallenge = speakingChallenge
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.firstValueReceipt = firstValueReceipt
    }

    var hasCompletedFirstValue: Bool {
        firstValueReceipt != nil && isCoherent
    }

    /// A receipt is valid only for the authored exercise that belongs to this
    /// draft's context. This prevents a structurally valid result from another
    /// context (or arbitrary axes) from advancing the activation route.
    var isCoherent: Bool {
        guard let firstValueReceipt else { return true }
        guard firstValueReceipt.isCoherent else { return false }
        guard firstValueReceipt.modality == .structuredText else { return true }
        guard let metadata = firstValueReceipt.structuredResult else { return false }

        let prompt = StructuredFirstValueCatalog.prompt(for: speakingContext)
        guard metadata.promptID == prompt.id else { return false }
        return [metadata.strengthAxis, metadata.nextAxis]
            .compactMap { $0 }
            .allSatisfy(prompt.rubric.contains)
    }

    func recording(_ receipt: FirstValueReceipt) -> CoachingProfileDraft {
        var copy = self
        copy.firstValueReceipt = receipt
        copy.updatedAt = receipt.completedAt
        return copy
    }
}

/// Content-free proof that the fast lane reached value. A written rehearsal
/// can complete activation without becoming speech evidence; a spoken Timed
/// rep is linked to the real persisted `PracticeSession` that earned it.
struct FirstValueReceipt: Codable, Equatable {
    enum Modality: String, Codable, Equatable {
        case structuredText
        case spokenTimed
    }

    let modality: Modality
    let completedAt: Date
    let sessionID: UUID?
    let structuredResult: StructuredFirstValueMetadata?

    static func structured(
        _ result: StructuredFirstValueResult,
        completedAt: Date = Date()
    ) -> FirstValueReceipt {
        structured(metadata: result.metadata, completedAt: completedAt)
    }

    static func structured(
        metadata: StructuredFirstValueMetadata,
        completedAt: Date = Date()
    ) -> FirstValueReceipt {
        FirstValueReceipt(
            modality: .structuredText,
            completedAt: completedAt,
            sessionID: nil,
            structuredResult: metadata
        )
    }

    static func spokenTimed(
        sessionID: UUID,
        completedAt: Date = Date()
    ) -> FirstValueReceipt {
        FirstValueReceipt(
            modality: .spokenTimed,
            completedAt: completedAt,
            sessionID: sessionID,
            structuredResult: nil
        )
    }

    var isCoherent: Bool {
        switch modality {
        case .structuredText:
            guard sessionID == nil,
                  let structuredResult,
                  structuredResult.wordCount >= 8,
                  !structuredResult.promptID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
            return true
        case .spokenTimed:
            return sessionID != nil && structuredResult == nil
        }
    }
}

// MARK: - First-run onboarding policy

/// Pure root-routing policy for the first coaching intake.
///
/// `CoachingProfileStore.profile` is the only completion truth. The policy
/// waits until AuthManager has established a durable identity and hydrated the
/// account's local stores, then presents onboarding only when that account has
/// no saved coaching profile. No second "has seen onboarding" flag is owned
/// here.
enum FirstRunOnboardingGate {
    /// Legacy key retained only so account deletion can remove data written by
    /// builds that predate profile-as-truth onboarding.
    static let legacyCompletedKeyPrefix = "noum.onboarding.firstRun.completed."

    /// Root choices after `AuthManager` has established a durable account and
    /// hydrated its stores. Account readiness remains owned by `NoumApp`; this
    /// enum intentionally contains no bootstrap/loading state.
    enum RootRoute: Equatable {
        case fastLane
        case fullOnboarding
        case appShell
    }

    /// Transient choice made on the first-value result surface. It is not
    /// persisted as another onboarding flag: a receipt already prevents the
    /// fast lane repeating, while a complete profile remains the only durable
    /// full-onboarding truth.
    enum PostValueChoice: Equatable {
        case completeCoachingSetup
        case enterApp
    }

    /// Pure post-hydration route policy.
    ///
    /// - A complete profile always enters the app, even if a stale draft also
    ///   exists (the store cleans that draft on reload).
    /// - Before first value, an incomplete account sees the fast lane.
    /// - After first value, a one-session choice may open full onboarding;
    ///   otherwise the app shell opens and can offer setup again later.
    /// - Ordinary UI tests retain their established shell bypass.
    static func rootRoute(
        hasCoachingProfile: Bool,
        draft: CoachingProfileDraft?,
        postValueChoice: PostValueChoice? = nil,
        isUITesting: Bool
    ) -> RootRoute {
        if isUITesting || hasCoachingProfile {
            return .appShell
        }
        guard draft?.hasCompletedFirstValue == true else {
            return .fastLane
        }
        return postValueChoice == .completeCoachingSetup
            ? .fullOnboarding
            : .appShell
    }

    static func shouldPresent(
        hasDurableIdentity: Bool,
        hasHydratedAccountStores: Bool,
        hasCoachingProfile: Bool,
        isUITesting: Bool
    ) -> Bool {
        hasDurableIdentity
            && hasHydratedAccountStores
            && !isUITesting
            && !hasCoachingProfile
    }
}
