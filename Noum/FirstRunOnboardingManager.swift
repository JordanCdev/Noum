import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(Speech)
import Speech
#endif

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

    /// The permissionless result has landed and the user may now choose the
    /// spoken-proof handoff. This does not imply microphone permission or arm
    /// capture; it only makes the user-initiated next action eligible.
    var canStartSpokenProof: Bool {
        hasCompletedFirstValue && firstValueReceipt?.modality == .structuredText
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

// MARK: - Activation experiment contract

/// The two already-shipping first-run routes that may participate in the
/// activation experiment. The app never chooses between these variants
/// locally: a value exists only when an approved external configuration token
/// is active. No token (including a value that has not fetched yet) means the
/// production fast lane remains the unassigned default.
enum ActivationExperimentVariant: Int, Codable, Equatable {
    case fullOnboardingControl = 0
    case permissionlessFastLane = 1

    var rootRoute: FirstRunOnboardingGate.RootRoute {
        switch self {
        case .fullOnboardingControl: return .fullOnboarding
        case .permissionlessFastLane: return .fastLane
        }
    }
}

/// Content-free, account-local assignment recovered from `FlowEventLog`.
/// Keeping it in the existing bounded flow ledger means export and deletion
/// continue through the established account-data owner rather than a second
/// analytics or onboarding store.
struct ActivationExperimentAssignment: Equatable {
    let correlationID: UUID
    let version: Int
    let variant: ActivationExperimentVariant
    let assignedAt: Date
}

/// Permission and locale state at the moment the assigned route actually
/// appeared. These are small enumerations, never identifiers or user content.
struct ActivationExperimentExposureContext: Equatable {
    enum PermissionState: Int, Equatable {
        case unknown = -1
        case undetermined = 0
        case denied = 1
        case granted = 2
    }

    enum Locale: Int, Equatable {
        case unknown = 0
        case englishUS = 1
        case spanishES = 2
        case frenchFR = 3
    }

    let microphonePermission: PermissionState
    let speechPermission: PermissionState
    let locale: Locale

    init(
        microphonePermission: PermissionState,
        speechPermission: PermissionState,
        locale: Locale
    ) {
        self.microphonePermission = microphonePermission
        self.speechPermission = speechPermission
        self.locale = locale
    }

    init?(numerics: [String: Int]) {
        guard let microphoneRaw = numerics["microphonePermission"],
              let microphonePermission = PermissionState(rawValue: microphoneRaw),
              let speechRaw = numerics["speechPermission"],
              let speechPermission = PermissionState(rawValue: speechRaw),
              let localeRaw = numerics["locale"],
              let locale = Locale(rawValue: localeRaw) else { return nil }
        self.init(
            microphonePermission: microphonePermission,
            speechPermission: speechPermission,
            locale: locale
        )
    }

    /// Captures the same bounded environment snapshot for every experiment
    /// exposure. It is called only when the assigned surface actually appears,
    /// never while assignment is being resolved.
    static func capture(practiceLocale: PracticeLocale) -> Self {
        let microphonePermission: PermissionState
        #if canImport(AVFoundation)
        switch PracticeMicrophonePermissionState.current() {
        case .unknown: microphonePermission = .unknown
        case .undetermined: microphonePermission = .undetermined
        case .denied: microphonePermission = .denied
        case .granted: microphonePermission = .granted
        }
        #else
        microphonePermission = .unknown
        #endif

        let speechPermission: PermissionState
        #if canImport(Speech)
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: speechPermission = .undetermined
        case .denied, .restricted: speechPermission = .denied
        case .authorized: speechPermission = .granted
        @unknown default: speechPermission = .unknown
        }
        #else
        speechPermission = .unknown
        #endif

        let locale: Locale
        switch practiceLocale {
        case .enUS: locale = .englishUS
        case .esES: locale = .spanishES
        case .frFR: locale = .frenchFR
        }

        return Self(
            microphonePermission: microphonePermission,
            speechPermission: speechPermission,
            locale: locale
        )
    }

    var numerics: [String: Int] {
        [
            "microphonePermission": microphonePermission.rawValue,
            "speechPermission": speechPermission.rawValue,
            "locale": locale.rawValue,
        ]
    }
}

/// Per-account attribution only. Noum does not aggregate this into population
/// analytics; an approved external analysis can group exported account-local
/// reports after its separate privacy/product decision.
struct ActivationExperimentAttribution: Equatable {
    let assignment: ActivationExperimentAssignment
    let exposedVariant: ActivationExperimentVariant?

    var wasExposed: Bool { exposedVariant != nil }
}

enum ActivationExperimentContract {
    /// Remote Config owns delivery. Only these exact, versioned tokens can
    /// enroll an eligible new account; unknown values fail closed.
    static let remoteConfigKey = "activation_first_run_contract"
    static let currentVersion = 1
    static let fullOnboardingToken = "first-run-v1:full-onboarding"
    static let fastLaneToken = "first-run-v1:permissionless-fast-lane"

    /// Eligibility is deliberately stricter than route availability. Existing
    /// accounts, developer accounts, UI automation, and any account whose
    /// activation window already opened are never newly enrolled.
    static func isEligibleForNewAssignment(
        hasHydratedAccountStores: Bool,
        isDeveloper: Bool,
        isUITesting: Bool,
        hasCoachingProfile: Bool,
        hasOnboardingDraft: Bool,
        hasEnteredActivation: Bool
    ) -> Bool {
        hasHydratedAccountStores
            && !isDeveloper
            && !isUITesting
            && !hasCoachingProfile
            && !hasOnboardingDraft
            && !hasEnteredActivation
    }

    static func resolveAssignment(
        configuredValue: String?,
        isEligible: Bool,
        correlationID: UUID = UUID(),
        now: Date = Date()
    ) -> ActivationExperimentAssignment? {
        guard isEligible,
              let value = configuredValue?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }

        let variant: ActivationExperimentVariant
        switch value {
        case fullOnboardingToken:
            variant = .fullOnboardingControl
        case fastLaneToken:
            variant = .permissionlessFastLane
        default:
            return nil
        }

        return ActivationExperimentAssignment(
            correlationID: correlationID,
            version: currentVersion,
            variant: variant,
            assignedAt: now
        )
    }

    static func persistedAssignment(in events: [FlowEvent]) -> ActivationExperimentAssignment? {
        events
            .filter { $0.stage == TransformationKPIEventStage.activationExperimentAssigned }
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap(decodeAssignment)
            .first
    }

    static func attribution(in events: [FlowEvent]) -> ActivationExperimentAttribution? {
        guard let assignment = persistedAssignment(in: events) else { return nil }
        let exposed = events.contains { event in
            event.stage == TransformationKPIEventStage.activationExperimentExposed
                && event.correlationId == assignment.correlationID
                && event.createdAt >= assignment.assignedAt
                && event.numerics["experimentVersion"] == assignment.version
                && event.numerics["variant"] == assignment.variant.rawValue
        }
        return ActivationExperimentAttribution(
            assignment: assignment,
            exposedVariant: exposed ? assignment.variant : nil
        )
    }

    private static func decodeAssignment(_ event: FlowEvent) -> ActivationExperimentAssignment? {
        guard event.numerics["experimentVersion"] == currentVersion,
              let rawVariant = event.numerics["variant"],
              let variant = ActivationExperimentVariant(rawValue: rawVariant) else {
            return nil
        }
        return ActivationExperimentAssignment(
            correlationID: event.correlationId,
            version: currentVersion,
            variant: variant,
            assignedAt: event.createdAt
        )
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
        activationExperimentVariant: ActivationExperimentVariant? = nil,
        isUITesting: Bool
    ) -> RootRoute {
        if isUITesting || hasCoachingProfile {
            return .appShell
        }
        guard draft?.hasCompletedFirstValue == true else {
            return activationExperimentVariant?.rootRoute ?? .fastLane
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
