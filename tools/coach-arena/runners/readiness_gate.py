#!/usr/bin/env python3
import argparse
import gzip
import hashlib
import json
import math
import os
import plistlib
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path


ARENA_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = ARENA_ROOT.parents[1]
SCRIPTS_ROOT = REPO_ROOT / "scripts"
if str(SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_ROOT))

from privacy_body_verifier import (  # noqa: E402
    HOSTING_ORIGINS_BY_TARGET,
    MAX_HOSTED_PAGE_BODY_BYTES,
    active_hosting_target_from_source,
    approved_https_origin_matches,
    build_no_redirect_opener,
    verify_hosted_page_response,
)

# Compatibility for existing callers/tests while the live probe now covers all
# release-critical public pages.
MAX_PRIVACY_BODY_BYTES = MAX_HOSTED_PAGE_BODY_BYTES

PUBLIC_LIVE_PAGE_SPECS = (
    ("homepageURL", "/", "public/index.html"),
    ("privacyURL", "/privacy", "public/privacy.html"),
    ("supportURL", "/support", "public/support.html"),
    ("coachingMethodURL", "/how-noum-coaches", "public/how-noum-coaches.html"),
)
NO_REDIRECT_OPENER = build_no_redirect_opener()

DEFAULT_REPORT = ARENA_ROOT / "reports" / "app-path" / "latest.json"
CANONICAL_APP_PATH_REPORT_DIR = ARENA_ROOT / "reports" / "app-path"
DEFAULT_DUMP_DIR = Path(os.environ.get("NOUM_COACH_EVAL_DUMP_DIR", "/private/tmp/noum-coach-eval"))
DEFAULT_RELEASE_EVIDENCE_RUN_DIR = os.environ.get("NOUM_RELEASE_EVIDENCE_RUN_DIR")
READINESS_MANIFEST_FILE = "coach-vision-production-readiness-evidence-manifest-v1.json"
READINESS_MANIFEST_SCHEMA = "coach-vision-production-readiness-evidence-manifest-v1"
READY_CLAIM = "productionReadyEvidenceAvailable"
READY_SCORE = 85
READY_LOCAL_TARGET_SHAPE_SCORE = 85
SOURCE_SIDECARS = [
    "source-git-commit.txt",
    "source-coach-fingerprint.txt",
]
FIREBASE_BACKEND_DEPLOYMENT_BLOCKER = (
    'node "$PROJECT_DIR/scripts/release-backend-deploy.mjs"'
)

RELEASE_EVIDENCE_MANAGED_ARTIFACTS = [
    "coach-chat-conversation-expert-calibration-results-v2.json",
    "coach-real-user-transfer-outcomes-v4.json",
    "coach-real-device-testflight-qa-v3.json",
    "coach-operational-launch-checklist-v2.json",
]
RELEASE_EVIDENCE_RUN_MANIFEST_FILE = "release-evidence-run-v1.json"
RELEASE_EVIDENCE_RUN_MANIFEST_SCHEMA = "noum-release-evidence-run-v1"
RELEASE_EVIDENCE_VALIDATION_SCHEMA = "noum-release-evidence-validation-v1"
RELEASE_EVIDENCE_PROMOTION_RECEIPT_FILE = "promotion-receipt-v1.json"
RELEASE_EVIDENCE_PROMOTION_RECEIPT_SCHEMA = (
    "noum-release-evidence-promotion-receipt-v1"
)
LIVE_EVIDENCE_ATTESTATION_SCHEMA = "coach-live-capture-attestation-v1"
LIVE_EVIDENCE_PRODUCER = (
    "NoumTests/CoachLiveEvaluationTests.liveGeminiRepliesClearFixtureRubric"
)
SHA256_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")
NON_LIVE_PROVIDER_IDENTITY_PATTERN = re.compile(
    r"(?:^|[\s_./()-])(?:replay|fixture|template|scripted|synthetic|mock|stub|fake|test)(?:$|[\s_./()-])",
    re.IGNORECASE,
)

COACH_SOURCE_STATUS_PATHS = [
    "Noum/AICoachChatService.swift",
    "Noum/AskNoumStore.swift",
    "Noum/CoachAssessment.swift",
    "Noum/CoachAssessmentCache.swift",
    "Noum/CoachContextBuilder.swift",
    "Noum/CoachPromptBundle.swift",
    "Noum/CoachReasoningPass.swift",
    "Noum/CoachReplyPipeline.swift",
    "Noum/CoachReliabilityGate.swift",
    "Noum/CoachTurnDepth.swift",
    "Noum/CoachingKnowledgeBase.swift",
    "Noum/GoalRubric.swift",
    "Noum/GoalRubricStore.swift",
    "Noum/KnowledgeRetriever.swift",
    "Noum/KnowledgeSemanticReranker.swift",
    "Noum/PrimaryFocusMemory.swift",
    "Noum/TurnDepthClassifier.swift",
    "Noum/UserTrajectoryCache.swift",
    "Noum/UserTrajectorySnapshot.swift",
    "NoumTests/CoachBrainRerankTests.swift",
    "NoumTests/CoachBrainTests.swift",
    "NoumTests/CoachChatEvaluationFixtures.swift",
    "NoumTests/CoachChatConversationEvaluationTests.swift",
    "NoumTests/CoachProviderChainTests.swift",
    "NoumTests/CoachReadCalibrationBaselineTests.swift",
    "NoumTests/CoachLiveEvaluationTests.swift",
    "NoumTests/CoachJudgementLayerTests.swift",
    "NoumTests/CoachPlaceholderLeakStripTests.swift",
    "NoumTests/CoachReportVoiceRegenerationProofTests.swift",
    "NoumTests/CoachReliabilityGateTests.swift",
    "NoumTests/GoalRubricVoiceRoutingTests.swift",
    "NoumTests/NoumTests.swift",
]

# Clean-ancestor reuse exists to avoid regenerating coach evidence after a
# documentation-only commit. Keep this list deliberately narrow and
# default-deny: Markdown under the evaluator can be an executable prompt or
# rubric, and generated reports are evidence rather than documentation.
CLEAN_ANCESTOR_DOCUMENTATION_FILES = {
    "AGENTS.md",
    "HANDOFF.md",
    "README.md",
}

# These paths are written by the evidence workflows themselves. Their bytes are
# validated as evidence inputs elsewhere; treating them as app source would make
# every successful refresh invalidate the dump it just produced.
GENERATED_EVIDENCE_OUTPUT_FILES = {
    "tools/coach-arena/reports/app-path/failures.md",
    "tools/coach-arena/reports/app-path/latest.json",
    "tools/coach-arena/reports/app-path/latest.md",
    "tools/coach-arena/reports/app-path-diagnostic/failures.md",
    "tools/coach-arena/reports/app-path-diagnostic/latest.json",
    "tools/coach-arena/reports/app-path-diagnostic/latest.md",
    "tools/coach-arena/synthetic/app-path/ten_conversations.md",
    "tools/coach-arena/synthetic/app-path-diagnostic/ten_conversations.md",
}


LOCAL_GATE_REQUIREMENTS = [
    {
        "key": "scoreThresholdsPass",
        "label": "localScoreAndFixtureThresholds",
        "gate": (
            "The latest app-path report must pass the score floors, placeholder "
            "leak cap, and app-path fixture floor."
        ),
        "nextStep": (
            "Run the app-path evaluator, inspect reports/app-path/failures.md, "
            "and fix any low-scoring or leaking fixture before launch."
        ),
    },
    {
        "key": "realPipelineEvidencePasses",
        "label": "realPipelineEvidence",
        "gate": (
            "The latest app-path report must be backed by real Swift pipeline "
            "traces, not Python reference replies or scripted local-only output."
        ),
        "nextStep": (
            "Regenerate the XCTest artifact dump, rerun app-path-source, then "
            "rerun app-path scoring against the refreshed dump."
        ),
    },
    {
        "key": "traceQualityPasses",
        "label": "traceQualityEvidence",
        "gate": (
            "Every scored app-path row must carry usable trace evidence for "
            "retrieval, cache/source freshness, depth routing, and quality gates."
        ),
        "nextStep": (
            "Inspect traceQualityFailures in the app-path report and repair the "
            "missing trace or retrieval surface before claiming readiness."
        ),
    },
]


EVIDENCE_REQUIREMENTS = {
    "noLiveProviderTranscriptSweep": {
        "rowKey": "liveProviderTranscriptSweep",
        "artifact": "coach-live-eval-v1.json",
        "expectedSchemaVersion": "coach-live-eval-v1",
        "requiredTopLevelKeys": [
            "schemaVersion",
            "sourceGitCommit",
            "sourceCoachFingerprint",
            "fixtureCount",
            "longFormConversationCount",
            "longFormConversationIDsPassingProductionFloor",
            "longFormConversationFailureIDs",
            "longFormConversations",
            "providerChain",
            "liveEvidenceProvenance",
            "passesProductionFloor",
            "passesRunReadinessFloor",
            "summary",
            "rows",
        ],
        "owner": "live provider eval",
        "gate": (
            "Real provider transcript sweep over the required app-path fixtures, "
            "with matching sourceGitCommit and sourceCoachFingerprint sidecars."
        ),
        "nextStep": (
            "Run app-path-source, refresh the live provider evaluation artifact, "
            "then rerun the Swift production-readiness manifest test."
        ),
    },
    "noProfessionalCoachCalibration": {
        "rowKey": "professionalCoachCalibration",
        "artifact": "coach-chat-conversation-expert-calibration-results-v2.json",
        "expectedSchemaVersion": "coach-chat-conversation-expert-calibration-results-v2",
        "requiredTopLevelKeys": [
            "schemaVersion",
            "sourcePacketSchemaVersion",
            "sourcePacketFingerprint",
            "rubricVersion",
            "reviewerRole",
            "reviewCount",
            "summary",
            "rows",
        ],
        "owner": "professional coach reviewers",
        "gate": (
            "Blinded professional-coach reviews for the required calibration "
            "packet, meeting the rubric and review-count floor."
        ),
        "nextStep": (
            "Collect the signed calibration results from real reviewers and place "
            "the artifact in NOUM_COACH_EVAL_DUMP_DIR."
        ),
    },
    "noRealUserLongitudinalTransferOutcomes": {
        "rowKey": "realUserLongitudinalTransferOutcomes",
        "artifact": "coach-real-user-transfer-outcomes-v4.json",
        "expectedSchemaVersion": "coach-real-user-transfer-outcomes-v4",
        "requiredTopLevelKeys": [
            "schemaVersion",
            "templateStatus",
            "studyProtocolVersion",
            "protocolRegistrationReference",
            "analysisPlanReference",
            "comparisonMethod",
            "benchmarkReference",
            "cohortDescription",
            "studyAttestation",
            "studyWindow",
            "enrollment",
            "installCohort",
            "outcomeCount",
            "summary",
            "rows",
        ],
        "owner": "closed beta outcome study",
        "gate": (
            "Longitudinal real-user transfer outcomes with follow-up delay, "
            "real-world moments, linked interventions, and evidence references."
        ),
        "nextStep": (
            "Complete the beta follow-up cohort and export the verified outcomes "
            "artifact. Local fixtures cannot earn this row."
        ),
    },
    "noRealDeviceTestFlightVerification": {
        "rowKey": "realDeviceTestFlightVerification",
        "artifact": "coach-real-device-testflight-qa-v3.json",
        "expectedSchemaVersion": "coach-real-device-testflight-qa-v3",
        "requiredTopLevelKeys": [
            "schemaVersion",
            "testRunID",
            "appVersion",
            "buildNumber",
            "deviceModel",
            "osVersion",
            "testerRole",
            "summary",
            "rows",
        ],
        "owner": "real device QA",
        "gate": (
            "Physical-device TestFlight verification for the exact 14-surface, "
            "84-check M14 hardware sweep, including the full StoreKit lifecycle."
        ),
        "nextStep": (
            "Run the release candidate on a physical TestFlight device and attach "
            "the required same-build proof for every structured surface and check."
        ),
    },
    "operationalLaunchChecklistIncomplete": {
        "rowKey": "operationalLaunchChecklist",
        "artifact": "coach-operational-launch-checklist-v2.json",
        "expectedSchemaVersion": "coach-operational-launch-checklist-v2",
        "requiredTopLevelKeys": [
            "schemaVersion",
            "templateStatus",
            "checklistVersion",
            "releaseCandidateBuild",
            "completedByRole",
            "completedByID",
            "releasePrerequisites",
            "historySecretAdjudication",
            "summary",
            "items",
        ],
        "owner": "release manager",
        "gate": (
            "M14 launch checklist covering Firestore rules, privacy URL, Settings "
            "privacy link, App Store privacy disclosure review, TestFlight upload, "
            "and release-blocking bug triage."
        ),
        "nextStep": (
            "Complete every required launch item against the release candidate "
            "build and attach the deploy/review/output references."
        ),
    },
}


LIVE_REQUIRED_FIXTURE_IDS = [
    "cold-start-interview-baseline",
    "filler-pressure-prescription",
    "metric-action-without-read",
    "critique-trust-repair",
    "markdown-tts-trust-repair",
    "assistant-explainer-register",
    "authoritative-distance-deep-assessment",
    "what-next-single-move",
    "overclaim-hypothesis-boundary",
    "personal-pattern-hypothesis-confirmation",
    "leadership-transfer-setup",
    "pace-control-next-rep",
    "closing-ask-proof-test",
    "opening-verdict-next-rep",
    "pause-before-answer-drill",
    "concise-answer-next-rep",
    "structure-one-reason-proof",
    "confidence-clean-stop",
    "answer-depth-one-example",
    "closing-stop-no-summary",
]

LIVE_REQUIRED_LONG_FORM_IDS = [
    "long-form-cold-start-interview-baseline-conversation",
    "long-form-filler-pressure-prescription-conversation",
    "long-form-metric-action-without-read-conversation",
    "long-form-critique-trust-repair-conversation",
    "long-form-markdown-tts-trust-repair-conversation",
    "long-form-assistant-explainer-register-conversation",
    "long-form-authoritative-distance-deep-assessment-conversation",
    "long-form-what-next-single-move-conversation",
    "long-form-overclaim-hypothesis-boundary-conversation",
    "long-form-leadership-transfer-setup-conversation",
    "long-form-polite-pushback-attunement-conversation",
]

LIVE_REQUIRED_LONG_FORM_TURN_COUNTS = {
    conversation_id: 5 for conversation_id in LIVE_REQUIRED_LONG_FORM_IDS
}

LIVE_REQUIRED_TURN_DEPTHS = [
    "quickMove",
    "groundedRead",
    "deepAssessment",
    "trustRepair",
]

GENERIC_PLACEHOLDER_REPLY_FRAGMENTS = [
    "focused coach reply with concrete evidence",
    "grounded coach reply with a proof test",
    "generic coach reply",
    "practice more and communicate clearly",
    "based on your data",
    "keep practicing and track your progress",
]

PROFESSIONAL_CALIBRATION_PACKET_FILE = "coach-chat-conversation-expert-calibration-v2.json"
PROFESSIONAL_CALIBRATION_PACKET_SCHEMA = "coach-chat-conversation-expert-calibration-v2"
PROFESSIONAL_CALIBRATION_RESULTS_SCHEMA = "coach-chat-conversation-expert-calibration-results-v2"
PROFESSIONAL_CALIBRATION_RUBRIC = "coach-parity-conversation-calibration-v2"
PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION = 3
PROFESSIONAL_CALIBRATION_MIN_CONVERSATION_COUNT = 39
PROFESSIONAL_CALIBRATION_MIN_REVIEW_COUNT = (
    PROFESSIONAL_CALIBRATION_MIN_CONVERSATION_COUNT
    * PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION
)
MIN_TRAJECTORY_CACHE_HIT_RATIO = 0.10

REAL_USER_TRANSFER_SCHEMA = "coach-real-user-transfer-outcomes-v4"
REAL_USER_TRANSFER_PROTOCOL = "coach-transfer-outcome-ledger-v4"
REAL_USER_TRANSFER_REQUIRED_OUTCOMES = 30
REAL_USER_TRANSFER_REQUIRED_USERS = 30
REAL_USER_TRANSFER_REQUIRED_MOMENT_CATEGORIES = 4
REAL_USER_TRANSFER_MAX_OUTCOMES_PER_USER = 2
REAL_USER_TRANSFER_MIN_FOLLOW_UP_HOURS = 24
REAL_USER_TRANSFER_MIN_STUDY_SECONDS = 28 * 24 * 60 * 60
REAL_USER_TRANSFER_REQUIRED_RELEASE_INSTALLS = 200
REAL_USER_TRANSFER_SCALE_INSTALLS = 500
REAL_USER_TRANSFER_INSTALL_SOURCE = "appStoreConnectAnalytics"
REAL_USER_TRANSFER_MIN_POSITIVE_RATE = 0.60
REAL_USER_TRANSFER_MIN_NO_REGRESSION_RATE = 0.70
REAL_USER_TRANSFER_MIN_COHORT_COMPLETION_RATE = 0.70

REAL_DEVICE_TESTFLIGHT_SCHEMA = "coach-real-device-testflight-qa-v3"
REAL_DEVICE_MAX_AI_PROMPT_LATENCY_MS = 3000
REAL_DEVICE_REQUIRED_SURFACES = [
    "liveActivity",
    "aiPromptLatency",
    "soundscapeAudioSession",
    "storeKitPurchaseRestoreEntitlements",
    "productionTranscriptionConsent",
    "transcriptionFailureIntegrity",
    "pitchMetrics",
    "multilingualPractice",
    "modeSmoke",
    "accountAuthentication",
    "accountDeletion",
    "accessibilityMotionType",
    "notificationLifecycle",
    "widgetRefresh",
]
REAL_DEVICE_EVIDENCE_KIND_BY_SURFACE = {
    "liveActivity": "screenRecording",
    "aiPromptLatency": "latencyTrace",
    "soundscapeAudioSession": "audioSessionLog",
    "storeKitPurchaseRestoreEntitlements": "storeKitReceipt",
    "productionTranscriptionConsent": "transcriptionConsentTrace",
    "transcriptionFailureIntegrity": "recordingIntegrityTrace",
    "pitchMetrics": "pitchMetricsCapture",
    "multilingualPractice": "multilingualSessionCapture",
    "modeSmoke": "modeSmokeRunLog",
    "accountAuthentication": "authenticationLifecycleTrace",
    "accountDeletion": "accountDeletionTrace",
    "accessibilityMotionType": "accessibilityScreenRecording",
    "notificationLifecycle": "notificationDeliveryLog",
    "widgetRefresh": "widgetScreenRecording",
}
REAL_DEVICE_REQUIRED_CHECKS_BY_SURFACE = {
    "liveActivity": [
        "dynamicIslandCompactExpanded",
        "lockScreenPresentation",
        "finishDismisses",
        "forceQuitEnds",
    ],
    "aiPromptLatency": [
        "productionPromptWithinBudget",
        "repeatedBeginWithinBudget",
        "airplaneModeCuratedFallback",
    ],
    "soundscapeAudioSession": [
        "focusCalmSteadyPlayback",
        "stopsWhenRecordingStarts",
        "phoneInterruptionRecovers",
        "spotifyMixesPolitely",
    ],
    "storeKitPurchaseRestoreEntitlements": [
        "paywallOpensFromSettings",
        "monthlySandboxPurchase",
        "annualSandboxPurchase",
        "annualTrialEligibilityAndExactTerms",
        "annualTrialStarts",
        "renewalPreservesEntitlement",
        "cancellationRemainsActiveUntilExpiry",
        "billingFailureFollowsVerifiedStoreKitState",
        "refundRevokesEntitlement",
        "expiryRemovesEntitlement",
        "restorePreviousPurchase",
        "coachModeEntitlement",
        "liveTranscriptEntitlement",
        "fillerTrackingEntitlement",
    ],
    "productionTranscriptionConsent": [
        "guestBootstrapCloudConsent",
        "firebaseDeepgramRealMicrophoneRep",
        "noPreConsentDataEgress",
        "declineKeepsSupportedPracticeLocal",
        "revokeKeepsSupportedPracticeLocal",
        "unsupportedLocalExplainsCloudRequirement",
        "settingsRecoveryRoute",
        "productionAppCheckAccepted",
    ],
    "transcriptionFailureIntegrity": [
        "providerStartFailure",
        "midSessionDisconnect",
        "audioInterruption",
        "bluetoothRouteChange",
        "silence",
        "finalWordDelay",
        "failedAttemptNotPersisted",
        "failedAttemptNotScored",
        "failedAttemptNoXP",
        "timerWaitsForCaptureReadiness",
    ],
    "pitchMetrics": [
        "variedPitchClassification",
        "monotoneClassification",
        "shortWhisperSuppressed",
    ],
    "multilingualPractice": [
        "spanishTranscriptionAndFillers",
        "frenchTranscriptionAndFillers",
        "nonEnglishDebriefUsesDeterministicFallback",
        "englishRestoresGeneratedPromptPath",
        "settingsLabelsLocalize",
    ],
    "modeSmoke": [
        "timedDifficulties",
        "suddenDeathDifficulties",
        "ahCounter",
        "imConversation",
        "miniDrill",
        "cutTheCrutch",
        "lesson",
        "pathNodeUnlock",
    ],
    "accountAuthentication": [
        "appleSignInReloadsData",
        "googleSignInReloadsData",
        "guestSignIn",
        "guestUpgradePreservesData",
    ],
    "accountDeletion": [
        "serverFailurePreservesSignedInState",
        "serverFailureShowsRetry",
        "successRemovesRegisteredLocalData",
        "successRemovesRemoteData",
        "successDeletesFirebaseAuthUser",
        "successRevokesAppleAuthorizationWhenApplicable",
        "successReturnsToOnboarding",
        "subscriptionCancellationNotClaimed",
    ],
    "accessibilityMotionType": [
        "reduceMotionSubduesSplash",
        "reduceMotionSubduesConfetti",
        "largestDynamicTypeHomeCTAs",
        "largestDynamicTypeSummaryCTAs",
        "voiceOverLabelsAndHints",
    ],
    "notificationLifecycle": [
        "firstRepPrePrompt",
        "nativePromptOnce",
        "allFourSurfacesArm",
        "declineCooldownThirtyDays",
        "streakWarningDelivery",
    ],
    "widgetRefresh": [
        "homeWidgetRefreshesRepCount",
        "homeWidgetRefreshesStreak",
        "lockScreenCircularNoClipping",
    ],
}
REAL_DEVICE_REQUIRED_CHECK_COUNT = sum(
    len(checks) for checks in REAL_DEVICE_REQUIRED_CHECKS_BY_SURFACE.values()
)

OPERATIONAL_LAUNCH_SCHEMA = "coach-operational-launch-checklist-v2"
OPERATIONAL_LAUNCH_CHECKLIST_VERSION = "m14-launch-gate-v2"
OPERATIONAL_LAUNCH_TEMPLATE_STATUS = "COLLECTED_EXTERNAL_EVIDENCE"
OPERATIONAL_LAUNCH_REQUIRED_ITEMS = [
    "firestoreRulesDeployed",
    "privacyPolicyURLHosted",
    "settingsPrivacyURLVerified",
    "appStorePrivacyDisclosuresReviewed",
    "testFlightBuildUploaded",
    "releaseBlockingBugsTriaged",
]
OPERATIONAL_LAUNCH_EVIDENCE_KIND_BY_ITEM = {
    "firestoreRulesDeployed": "firebaseDeployLog",
    "privacyPolicyURLHosted": "publicURLProbe",
    "settingsPrivacyURLVerified": "settingsScreenshot",
    "appStorePrivacyDisclosuresReviewed": "appStorePrivacyExport",
    "testFlightBuildUploaded": "appStoreConnectBuildRecord",
    "releaseBlockingBugsTriaged": "releaseTriageReport",
}
OPERATIONAL_LAUNCH_ENVIRONMENT_BY_ITEM = {
    "firestoreRulesDeployed": "production",
    "privacyPolicyURLHosted": "production",
    "settingsPrivacyURLVerified": "releaseCandidate",
    "appStorePrivacyDisclosuresReviewed": "appStoreConnect",
    "testFlightBuildUploaded": "appStoreConnect",
    "releaseBlockingBugsTriaged": "releaseBoard",
}
OPERATIONAL_LAUNCH_REQUIRED_PREREQUISITES = [
    "cloudOperationsProbePassed",
    "historicalCredentialIncidentClosed",
    "legacyTranscriptionEndpointProtectedOrDisabled",
    "exposedProviderCredentialsRevoked",
    "providerUsageAndBillingAuditComplete",
    "fullHistorySecretFindingsAdjudicated",
    "releaseBundleSecretScanPassed",
    "protectedSocialCutoverCompleted",
    "socialMigrationDryRunPassed",
    "trustedSocialEvidenceProducerDeployed",
    "customPrivacyDomainVerified",
    "appleReleaseServicesConfigured",
]
OPERATIONAL_LAUNCH_EVIDENCE_KIND_BY_PREREQUISITE = {
    "cloudOperationsProbePassed": "cloudOperationsProbeOutput",
    "historicalCredentialIncidentClosed": "credentialIncidentClosure",
    "legacyTranscriptionEndpointProtectedOrDisabled": "legacyEndpointVerification",
    "exposedProviderCredentialsRevoked": "providerCredentialRevocation",
    "providerUsageAndBillingAuditComplete": "providerUsageBillingAudit",
    "fullHistorySecretFindingsAdjudicated": "fullHistorySecretReview",
    "releaseBundleSecretScanPassed": "releaseBundleSecretScan",
    "protectedSocialCutoverCompleted": "protectedSocialCutover",
    "socialMigrationDryRunPassed": "socialMigrationDryRun",
    "trustedSocialEvidenceProducerDeployed": "trustedSocialEvidenceProducer",
    "customPrivacyDomainVerified": "customPrivacyDomainVerification",
    "appleReleaseServicesConfigured": "appleReleaseServicesConfiguration",
}
OPERATIONAL_LAUNCH_ENVIRONMENT_BY_PREREQUISITE = {
    "cloudOperationsProbePassed": "production",
    "historicalCredentialIncidentClosed": "production",
    "legacyTranscriptionEndpointProtectedOrDisabled": "production",
    "exposedProviderCredentialsRevoked": "productionProvider",
    "providerUsageAndBillingAuditComplete": "productionProvider",
    "fullHistorySecretFindingsAdjudicated": "repositoryHistory",
    "releaseBundleSecretScanPassed": "releaseCandidate",
    "protectedSocialCutoverCompleted": "production",
    "socialMigrationDryRunPassed": "production",
    "trustedSocialEvidenceProducerDeployed": "production",
    "customPrivacyDomainVerified": "production",
    "appleReleaseServicesConfigured": "appStoreConnect",
}
OPERATIONAL_LAUNCH_HISTORY_SCANNER = "gitleaks"
OPERATIONAL_LAUNCH_HISTORY_SCANNER_VERSION = "8.30.1"
OPERATIONAL_LAUNCH_HISTORY_SCOPE = "all-reachable-commits"
OPERATIONAL_LAUNCH_KNOWN_DEEPGRAM_COMMIT = "277e2b388bb17d603011277a819b0bcaae517404"
OPERATIONAL_LAUNCH_HISTORY_DISPOSITIONS = {
    "revoked", "invalidated", "falsePositive", "publicIdentifier",
}


UI_FLOW_BOUNDARY = {
    "maestroSmokeFlows": [
        "maestro/chat_smoke.yaml",
        "maestro/chat_reject_smoke.yaml",
    ],
    "covered": [
        "Ask Noum type-chat happy path with deterministic markdown reply.",
        "Ask Noum deterministic rejection notice path.",
    ],
    "notLaunchProof": [
        "Physical TestFlight device coverage.",
        "Live Activity surface.",
        "AI prompt latency budget on real device.",
        "Soundscape audio-session behavior.",
        "Paywall purchase and receipt path.",
    ],
    "realDeviceArtifact": "coach-real-device-testflight-qa-v3.json",
}


def load_report(path):
    report_path = Path(path)
    with report_path.open(encoding="utf-8") as handle:
        return json.load(handle)


def readiness_from_report(report):
    summary = report.get("summary") if isinstance(report.get("summary"), dict) else {}
    readiness = summary.get("visionProductionReadiness")
    if isinstance(readiness, dict):
        return readiness
    readiness = report.get("visionProductionReadiness")
    return readiness if isinstance(readiness, dict) else None


def readiness_with_verified_artifacts(local_readiness, artifact_audit):
    if not isinstance(local_readiness, dict):
        return None
    valid_blockers = {
        item.get("blocker")
        for item in artifact_audit.get("requiredArtifacts", [])
        if item.get("present") and item.get("passesLightweightContract")
    }
    blockers = [
        blocker for blocker in EVIDENCE_REQUIREMENTS
        if blocker not in valid_blockers
    ]
    local_score = strict_int(local_readiness.get("score")) or 0
    # The local Swift audit now awards two bounded points for the source-bound
    # transcript-practice loop in addition to the original 18-point corpus and
    # app-path substrate. Keep the independent audit aligned with that explicit
    # 20-point local ceiling; external artifacts are still the only path above
    # it and the blocker caps below remain authoritative.
    raw_score = min(20, local_score)
    weights = {
        "noLiveProviderTranscriptSweep": 16,
        "noProfessionalCoachCalibration": 20,
        "noRealUserLongitudinalTransferOutcomes": 26,
        "noRealDeviceTestFlightVerification": 12,
        "operationalLaunchChecklistIncomplete": 8,
    }
    for blocker, weight in weights.items():
        if blocker in valid_blockers:
            raw_score += weight
    if any(blocker in blockers for blocker in [
        "noLiveProviderTranscriptSweep",
        "noProfessionalCoachCalibration",
        "noRealUserLongitudinalTransferOutcomes",
    ]):
        maximum = 20
    elif "noRealDeviceTestFlightVerification" in blockers:
        maximum = 45
    elif "operationalLaunchChecklistIncomplete" in blockers:
        maximum = 60
    else:
        maximum = 100
    score = min(raw_score, maximum)
    claim = READY_CLAIM if not blockers else "localEvaluationSubstrateOnly"
    local_target = local_readiness.get("localTargetShapeScore")
    blocker_text = ", ".join(blockers) if blockers else "no blocking evidence gaps"
    return {
        "score": score,
        "maximumAllowedScore": maximum,
        "localTargetShapeScore": local_target,
        "claim": claim,
        "blockers": blockers,
        "summary": (
            f"VISION production readiness {score}/100; local target-shape "
            f"{local_target}/100; claim {claim}; blockers: {blocker_text}."
        ),
    }


def readiness_manifest_audit(dump_dir, expected_readiness):
    path = Path(dump_dir) / READINESS_MANIFEST_FILE
    result = {
        "path": str(path),
        "present": path.is_file(),
        "schemaVersion": None,
        "passes": False,
        "failures": [],
    }
    if not path.is_file():
        result["failures"].append("missing")
        return result
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        result["failures"].append(f"invalidJSON:{type(exc).__name__}")
        return result
    if not isinstance(payload, dict):
        result["failures"].append("invalidTopLevelType")
        return result
    result["schemaVersion"] = payload.get("schemaVersion")
    if payload.get("schemaVersion") != READINESS_MANIFEST_SCHEMA:
        result["failures"].append("schemaVersionMismatch")
    audit = payload.get("audit") if isinstance(payload.get("audit"), dict) else None
    if audit is None:
        result["failures"].append("missingAudit")
    elif expected_readiness:
        for key in ["score", "maximumAllowedScore", "claim", "blockers"]:
            if audit.get(key) != expected_readiness.get(key):
                result["failures"].append(f"auditMismatch:{key}")
        manifest_local_target = strict_int(audit.get("localTargetShapeScore"))
        expected_local_target = strict_int(expected_readiness.get("localTargetShapeScore"))
        if (
            manifest_local_target is None
            or expected_local_target is None
            or manifest_local_target < expected_local_target
        ):
            result["failures"].append("auditMismatch:localTargetShapeScore")
    if not isinstance(payload.get("evidence"), dict):
        result["failures"].append("missingEvidence")
    if not isinstance(payload.get("rows"), list) or not payload.get("rows"):
        result["failures"].append("missingRows")
    result["failures"] = list(dict.fromkeys(result["failures"]))
    result["passes"] = not result["failures"]
    return result


def local_gates_from_report(report):
    summary = report.get("summary") if isinstance(report.get("summary"), dict) else {}
    return {
        "scoreThresholdsPass": summary.get("scoreThresholdsPass"),
        "realPipelineEvidencePasses": summary.get(
            "realPipelineEvidencePasses",
            summary.get("productionEvidencePasses"),
        ),
        "traceQualityPasses": summary.get("traceQualityPasses"),
        "localAverage": summary.get("average"),
        "localFixtureFailures": summary.get("failureCount"),
    }


def computed_production_ready(readiness):
    if not readiness:
        return False
    blockers = readiness.get("blockers") or []
    return (
        readiness.get("score", 0) >= READY_SCORE and
        readiness.get("claim") == READY_CLAIM and
        not blockers
    )


def local_gate_failures(local_gates):
    failures = []
    for requirement in LOCAL_GATE_REQUIREMENTS:
        if local_gates.get(requirement["key"]) is not True:
            failure = dict(requirement)
            failure["observed"] = local_gates.get(requirement["key"])
            failures.append(failure)
    return failures


def local_target_shape_failures(readiness):
    if not readiness:
        return []
    score = readiness.get("localTargetShapeScore")
    if isinstance(score, (int, float)) and score >= READY_LOCAL_TARGET_SHAPE_SCORE:
        return []
    return [{
        "key": "localTargetShapeScore",
        "label": "localTargetShapeScore",
        "observed": score,
        "gate": (
            "The Swift VISION audit must report localTargetShapeScore >= "
            f"{READY_LOCAL_TARGET_SHAPE_SCORE}; barely passing fixture floors "
            "are not enough for launch."
        ),
        "nextStep": (
            "Improve low-scoring Ask Noum / Live Coach fixtures, regenerate "
            "the app-path artifacts, and rerun the Swift production-readiness "
            "manifest before treating local quality as launch-shaped."
        ),
    }]


def local_readiness_failures(local_gates, readiness):
    return local_gate_failures(local_gates) + local_target_shape_failures(readiness)


def normalized_report_path(report_path):
    path = Path(report_path)
    if path.is_absolute():
        return path.resolve(strict=False)
    parts = path.parts
    if len(parts) >= 2 and parts[0] == "tools" and parts[1] == "coach-arena":
        return (REPO_ROOT / path).resolve(strict=False)
    return (ARENA_ROOT / path).resolve(strict=False)


def report_source_audit(report, report_path):
    report_family = report.get("reportFamily")
    normalized_path = normalized_report_path(report_path)
    canonical_dir = CANONICAL_APP_PATH_REPORT_DIR.resolve(strict=False)
    canonical_path = (
        normalized_path == canonical_dir or
        canonical_dir in normalized_path.parents
    )
    return {
        "validationBoundary": (
            "Launch readiness only accepts the canonical Swift app-path report. "
            "Prompt-layer replay and stale diagnostic reports are useful for "
            "debugging, but cannot be readiness evidence."
        ),
        "reportFamily": report_family,
        "requiredReportFamily": "app-path",
        "normalizedReportPath": str(normalized_path),
        "canonicalReportDir": str(canonical_dir),
        "canonicalPath": canonical_path,
        "passes": report_family == "app-path" and canonical_path,
    }


def report_source_gate_failures(report_source):
    failures = []
    if report_source.get("reportFamily") != report_source.get("requiredReportFamily"):
        failures.append({
            "key": "reportFamily",
            "label": "reportFamily",
            "observed": report_source.get("reportFamily"),
            "gate": (
                "The readiness gate must read an app-path report generated from "
                "the Swift/XCTest app-path dump, not a prompt-layer replay report."
            ),
            "nextStep": (
                "Refresh the canonical app-path evidence with "
                "`./tools/coach-arena/run.sh app-path` after regenerating the "
                "XCTest dump."
            ),
        })
    if report_source.get("canonicalPath") is not True:
        failures.append({
            "key": "reportPath",
            "label": "reportPath",
            "observed": report_source.get("normalizedReportPath"),
            "gate": (
                "The readiness gate must read the canonical "
                "tools/coach-arena/reports/app-path report, not diagnostic or "
                "ad hoc output."
            ),
            "nextStep": (
                "Use `./tools/coach-arena/run.sh readiness` with the canonical "
                "app-path latest report; keep stale diagnostics in "
                "reports/app-path-diagnostic or another non-readiness location."
            ),
        })
    return failures


def _collect_source_values(value, key):
    values = []
    if isinstance(value, dict):
        for current_key, current_value in value.items():
            if current_key == key and isinstance(current_value, str) and current_value.strip():
                values.append(current_value.strip())
            else:
                values.extend(_collect_source_values(current_value, key))
    elif isinstance(value, list):
        for item in value:
            values.extend(_collect_source_values(item, key))
    return values


def _sidecar_value(artifact_audit, file_name):
    for item in artifact_audit.get("sourceSidecars") or []:
        if item.get("fileName") == file_name and item.get("present"):
            value = (item.get("valuePreview") or "").strip()
            return value or None
    return None


def current_git_commit(repo_root):
    proc = subprocess.run(
        ["git", "-C", str(Path(repo_root)), "rev-parse", "--short", "HEAD"],
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        return None
    return proc.stdout.strip() or None


def generated_evidence_output_path(path):
    normalized = str(path)
    if "\\" in normalized:
        return False
    if normalized.startswith("./"):
        normalized = normalized[2:]
    return normalized in GENERATED_EVIDENCE_OUTPUT_FILES


def dirty_behavior_source_path(path):
    return not (
        clean_ancestor_documentation_path(path) or
        generated_evidence_output_path(path)
    )


def parse_git_status_porcelain_z(output):
    tokens = output.split(b"\0")
    if tokens and tokens[-1] == b"":
        tokens.pop()
    paths = []
    index = 0
    while index < len(tokens):
        record = tokens[index]
        index += 1
        if len(record) < 4 or record[2:3] != b" ":
            raise ValueError("malformedGitStatus")
        status = record[:2].decode("ascii")
        path_tokens = [record[3:]]
        if "R" in status or "C" in status:
            if index >= len(tokens):
                raise ValueError("malformedGitStatusRename")
            path_tokens.append(tokens[index])
            index += 1
        for raw_path in path_tokens:
            path = raw_path.decode("utf-8")
            if not path:
                raise ValueError("emptyGitStatusPath")
            paths.append(path)
    return sorted(set(paths))


def current_dirty_coach_source_files(repo_root):
    proc = subprocess.run(
        [
            "git", "-C", str(Path(repo_root)), "status", "--porcelain=v1",
            "-z", "--untracked-files=all", "--ignore-submodules=none",
            "--renames", "--",
        ],
        text=False,
        capture_output=True,
    )
    if proc.returncode != 0:
        return ["<git-status-unavailable>"]
    try:
        paths = parse_git_status_porcelain_z(proc.stdout)
    except (UnicodeDecodeError, ValueError):
        return ["<git-status-unavailable>"]
    return [path for path in paths if dirty_behavior_source_path(path)]


def unfingerprinted_dirty_coach_source_files(
    dirty_source_files,
    fingerprint_paths=COACH_SOURCE_STATUS_PATHS,
):
    fingerprint_path_set = set(fingerprint_paths)
    return sorted(set(
        path for path in dirty_source_files
        if not path.startswith("<") and path not in fingerprint_path_set
    ))


def git_commit_is_ancestor(repo_root, ancestor, descendant):
    if not ancestor or not descendant:
        return False
    proc = subprocess.run(
        [
            "git", "-C", str(Path(repo_root)), "merge-base", "--is-ancestor",
            ancestor, descendant,
        ],
        text=True,
        capture_output=True,
    )
    return proc.returncode == 0


def clean_ancestor_documentation_path(path):
    normalized = str(path)
    if "\\" in normalized:
        return False
    if normalized.startswith("./"):
        normalized = normalized[2:]
    if normalized in CLEAN_ANCESTOR_DOCUMENTATION_FILES:
        return True
    if normalized.startswith("docs/") and normalized.endswith(".md"):
        return True
    parts = normalized.split("/")
    return (
        len(parts) == 3 and
        parts[0] == ".screenshots" and
        parts[2] == "HANDOFF.md"
    )


def clean_ancestor_descendant_audit(repo_root, ancestor, descendant):
    result = {
        "ancestor": ancestor,
        "descendant": descendant,
        "changedPaths": [],
        "behaviorSourcePaths": [],
        "error": None,
        "passes": False,
    }
    if not ancestor or not descendant:
        result["error"] = "missingCommit"
        return result
    if ancestor == descendant:
        result["passes"] = True
        return result
    if not git_commit_is_ancestor(repo_root, ancestor, descendant):
        result["error"] = "notAncestor"
        return result

    proc = subprocess.run(
        [
            "git", "-C", str(Path(repo_root)), "diff", "--name-status", "-z",
            "--find-renames", f"{ancestor}..{descendant}", "--",
        ],
        text=False,
        capture_output=True,
    )
    if proc.returncode != 0:
        result["error"] = "diffUnavailable"
        return result

    tokens = proc.stdout.split(b"\0")
    if tokens and tokens[-1] == b"":
        tokens.pop()
    paths = []
    index = 0
    try:
        while index < len(tokens):
            status = tokens[index].decode("utf-8")
            index += 1
            kind = status[:1]
            if kind not in {"A", "C", "D", "M", "R", "T", "U", "X", "B"}:
                raise ValueError("unknownStatus")
            path_count = 2 if kind in {"C", "R"} else 1
            if index + path_count > len(tokens):
                raise ValueError("malformedDiff")
            for _ in range(path_count):
                paths.append(tokens[index].decode("utf-8"))
                index += 1
    except (UnicodeDecodeError, ValueError) as error:
        result["error"] = str(error)
        return result

    changed_paths = sorted(set(paths))
    behavior_paths = [
        path for path in changed_paths
        if dirty_behavior_source_path(path)
    ]
    result["changedPaths"] = changed_paths
    result["behaviorSourcePaths"] = behavior_paths
    result["passes"] = not behavior_paths
    return result


def coach_source_fingerprint(repo_root, paths=COACH_SOURCE_STATUS_PATHS):
    root = Path(repo_root)
    if not any((root / rel_path).exists() for rel_path in paths):
        return None

    digest = hashlib.sha256()
    for rel_path in sorted(paths):
        path = root / rel_path
        digest.update(rel_path.encode("utf-8"))
        digest.update(b"\0")
        if path.exists():
            digest.update(path.read_bytes())
        else:
            digest.update(b"<missing>")
        digest.update(b"\0")
    return "sha256:" + digest.hexdigest()


def _current_source_mismatch(label, current_value, sidecar_value, report_values):
    if not current_value:
        return None
    mismatched_against = []
    if sidecar_value and sidecar_value != current_value:
        mismatched_against.append("sidecar")
    if report_values and current_value not in report_values:
        mismatched_against.append("report")
    if not mismatched_against:
        return None
    return {
        "label": label,
        "current": current_value,
        "sidecar": sidecar_value,
        "reportValues": report_values,
        "mismatchedAgainst": mismatched_against,
    }


def source_freshness_audit(report, artifact_audit, repo_root=None):
    report_fingerprints = sorted(set(
        _collect_source_values(report, "sourceFingerprint") +
        _collect_source_values(report, "sourceCoachFingerprint")
    ))
    report_commits = sorted(set(
        _collect_source_values(report, "gitCommit") +
        _collect_source_values(report, "sourceGitCommit")
    ))
    sidecar_fingerprint = _sidecar_value(artifact_audit, "source-coach-fingerprint.txt")
    sidecar_commit = _sidecar_value(artifact_audit, "source-git-commit.txt")
    current_fingerprint = coach_source_fingerprint(repo_root) if repo_root else None
    current_commit = current_git_commit(repo_root) if repo_root else None
    dirty_source_files = current_dirty_coach_source_files(repo_root) if repo_root else []
    git_status_unavailable = "<git-status-unavailable>" in dirty_source_files
    binding_dirty_source_files = [
        path for path in dirty_source_files
        if not path.startswith("<")
    ]
    unfingerprinted_dirty_source_files = (
        unfingerprinted_dirty_coach_source_files(dirty_source_files)
        if repo_root else []
    )

    mismatches = []
    if sidecar_fingerprint and report_fingerprints and sidecar_fingerprint not in report_fingerprints:
        mismatches.append({
            "label": "sourceCoachFingerprint",
            "sidecar": sidecar_fingerprint,
            "reportValues": report_fingerprints,
        })
    if sidecar_commit and report_commits and sidecar_commit not in report_commits:
        mismatches.append({
            "label": "sourceGitCommit",
            "sidecar": sidecar_commit,
            "reportValues": report_commits,
        })

    fingerprint_current_mismatch = _current_source_mismatch(
        "currentCoachFingerprint",
        current_fingerprint,
        sidecar_fingerprint,
        report_fingerprints,
    )
    commit_current_mismatch = _current_source_mismatch(
        "currentGitCommit",
        current_commit,
        sidecar_commit,
        report_commits,
    )
    clean_ancestor_commits_accepted = []
    clean_ancestor_changed_paths = []
    clean_ancestor_behavior_source_paths = []
    clean_ancestor_diff_errors = []
    if commit_current_mismatch and repo_root:
        source_commits = sorted(set(
            [value for value in [sidecar_commit, *report_commits] if value]
        ))
        fingerprints_match_current = bool(
            current_fingerprint and
            sidecar_fingerprint == current_fingerprint and
            report_fingerprints and
            all(value == current_fingerprint for value in report_fingerprints)
        )
        ancestor_audits = [
            clean_ancestor_descendant_audit(repo_root, value, current_commit)
            for value in source_commits
        ]
        clean_ancestor_commits_accepted = [
            audit["ancestor"] for audit in ancestor_audits if audit["passes"]
        ]
        clean_ancestor_changed_paths = sorted(set(
            path for audit in ancestor_audits for path in audit["changedPaths"]
        ))
        clean_ancestor_behavior_source_paths = sorted(set(
            path for audit in ancestor_audits for path in audit["behaviorSourcePaths"]
        ))
        clean_ancestor_diff_errors = sorted(set(
            audit["error"] for audit in ancestor_audits if audit["error"]
        ))
        if (
            not dirty_source_files and
            fingerprints_match_current and
            source_commits and
            len(clean_ancestor_commits_accepted) == len(source_commits)
        ):
            commit_current_mismatch = None

    current_mismatches = [
        mismatch for mismatch in [fingerprint_current_mismatch, commit_current_mismatch]
        if mismatch
    ]

    return {
        "validationBoundary": (
            "Source freshness compares staged source sidecars, embedded report "
            "trace metadata, and the current checkout's coach-source fingerprint "
            "when available; missing sidecars are handled by the artifact gate."
        ),
        "currentCoachFingerprint": current_fingerprint,
        "currentGitCommit": current_commit,
        "dirtyCoachSourceFiles": dirty_source_files,
        "gitStatusUnavailable": git_status_unavailable,
        "unfingerprintedDirtyCoachSourceFiles": unfingerprinted_dirty_source_files,
        "cleanAncestorCommitsAccepted": clean_ancestor_commits_accepted,
        "cleanAncestorChangedPaths": clean_ancestor_changed_paths,
        "cleanAncestorBehaviorSourcePaths": clean_ancestor_behavior_source_paths,
        "cleanAncestorDiffErrors": clean_ancestor_diff_errors,
        "sidecarCoachFingerprint": sidecar_fingerprint,
        "sidecarGitCommit": sidecar_commit,
        "reportCoachFingerprints": report_fingerprints,
        "reportGitCommits": report_commits,
        "mismatches": mismatches,
        "currentMismatches": current_mismatches,
        "passes": (
            not mismatches and
            not current_mismatches and
            not binding_dirty_source_files and
            not (git_status_unavailable and current_commit)
        ),
    }


def source_freshness_gate_failures(source_audit):
    failures = []
    dirty_source_files = [
        path for path in (source_audit.get("dirtyCoachSourceFiles") or [])
        if not path.startswith("<")
    ]
    if dirty_source_files:
        failures.append({
            "key": "dirtyCoachSource",
            "label": "dirtyCoachSource",
            "observed": dirty_source_files,
            "gate": (
                "Uncommitted behavior, resource, project, test, script, "
                "evaluator, or unknown paths cannot be bound to a Git commit "
                "for launch evidence."
            ),
            "nextStep": (
                "Move the evidence refresh to a clean source checkout, or "
                "commit the behavior change and regenerate the complete "
                "app-path evidence chain from that commit."
            ),
        })
    if source_audit.get("gitStatusUnavailable") and source_audit.get("currentGitCommit"):
        failures.append({
            "key": "gitStatusUnavailable",
            "label": "gitStatusUnavailable",
            "observed": "gitStatusUnavailable",
            "gate": (
                "The current Git commit was resolved, but worktree status could "
                "not be inspected for uncommitted source."
            ),
            "nextStep": (
                "Restore Git worktree access and rerun the source-bound "
                "readiness command."
            ),
        })
    for mismatch in source_audit.get("mismatches") or []:
        failures.append({
            "key": mismatch["label"],
            "label": mismatch["label"],
            "observed": "staleReport",
            "gate": (
                "The app-path report must be generated from the same Swift "
                "coach source fingerprint and git commit staged in the dump "
                "directory."
            ),
            "nextStep": (
                "Regenerate the XCTest app-path artifact dump, rerun "
                "`./tools/coach-arena/run.sh app-path-source`, then rerun "
                "app-path scoring so report traces match the current source."
            ),
            "sidecar": mismatch.get("sidecar"),
            "reportValues": mismatch.get("reportValues", []),
        })
    for mismatch in source_audit.get("currentMismatches") or []:
        failures.append({
            "key": mismatch["label"],
            "label": mismatch["label"],
            "observed": "staleCurrentSource",
            "gate": (
                "The readiness report and dump sidecars must describe the "
                "current checkout's Swift coach source fingerprint and git "
                "commit before local evidence can support launch readiness."
            ),
            "nextStep": (
                "Run `./tools/coach-arena/run.sh app-path-source`, regenerate "
                "the XCTest app-path artifact dump from the current checkout, "
                "then rerun app-path scoring and readiness."
            ),
            "current": mismatch.get("current"),
            "sidecar": mismatch.get("sidecar"),
            "reportValues": mismatch.get("reportValues", []),
            "mismatchedAgainst": mismatch.get("mismatchedAgainst", []),
        })
    return failures


def sha256_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def default_release_evidence_validator(run_dir, repo_root):
    tool = REPO_ROOT / "tools" / "release-evidence" / "release_evidence.py"
    if not tool.is_file():
        return {
            "passes": False,
            "failureCount": 1,
            "failures": ["releaseEvidenceValidatorMissing"],
        }
    environment = os.environ.copy()
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    command = [
        sys.executable,
        str(tool),
        "validate",
        "--run-dir",
        str(run_dir),
        "--repo-root",
        str(repo_root),
        "--json",
    ]
    try:
        result = subprocess.run(
            command,
            cwd=repo_root,
            env=environment,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return {
            "passes": False,
            "failureCount": 1,
            "failures": ["releaseEvidenceValidatorExecutionFailed"],
        }
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {
            "passes": False,
            "failureCount": 1,
            "failures": ["releaseEvidenceValidatorOutputInvalid"],
        }
    if not isinstance(payload, dict):
        return {
            "passes": False,
            "failureCount": 1,
            "failures": ["releaseEvidenceValidatorOutputInvalid"],
        }
    if result.returncode != 0 and payload.get("passes") is True:
        payload = dict(payload)
        payload["passes"] = False
        failures = list(payload.get("failures") or [])
        failures.append("releaseEvidenceValidatorExitMismatch")
        payload["failures"] = failures
        payload["failureCount"] = len(failures)
    return payload


def release_evidence_run_audit(
    release_evidence_run,
    dump_dir,
    repo_root,
    validator=default_release_evidence_validator,
):
    boundary = (
        "Launch readiness requires the validated attachment-backed release run "
        "to remain available. Its promotion receipt, source binding, and four "
        "managed artifact hashes must match the active evidence dump exactly."
    )
    if release_evidence_run is None or not str(release_evidence_run).strip():
        return {
            "runDir": None,
            "passes": False,
            "failures": ["releaseEvidenceRunMissing"],
            "validationBoundary": boundary,
            "validator": None,
            "artifactBindings": [],
        }

    run_dir = Path(release_evidence_run).expanduser().resolve()
    dump_dir = Path(dump_dir).expanduser().resolve()
    repo_root = Path(repo_root).expanduser().resolve()
    failures = []
    if not run_dir.is_dir():
        return {
            "runDir": str(run_dir),
            "passes": False,
            "failures": ["releaseEvidenceRunNotDirectory"],
            "validationBoundary": boundary,
            "validator": None,
            "artifactBindings": [],
        }

    validation = validator(run_dir, repo_root)
    if not isinstance(validation, dict):
        validation = {
            "passes": False,
            "failureCount": 1,
            "failures": ["releaseEvidenceValidatorOutputInvalid"],
        }
    if validation.get("passes") is not True:
        failures.append("releaseEvidenceRunValidationFailed")
    if validation.get("schemaVersion") != RELEASE_EVIDENCE_VALIDATION_SCHEMA:
        failures.append("releaseEvidenceValidatorSchemaMismatch")
    if validation.get("passes") is True and (
        validation.get("failureCount") != 0
        or bool(validation.get("failures"))
    ):
        failures.append("releaseEvidenceValidatorResultInconsistent")
    validated_run_dir = trimmed_non_empty(validation.get("runDir"))
    if validated_run_dir is None:
        failures.append("releaseEvidenceValidatorRunMissing")
    else:
        try:
            if Path(validated_run_dir).expanduser().resolve() != run_dir:
                failures.append("releaseEvidenceValidatorRunMismatch")
        except OSError:
            failures.append("releaseEvidenceValidatorRunMismatch")

    def load_object(path, missing_failure, malformed_failure):
        if not path.is_file():
            failures.append(missing_failure)
            return {}
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            failures.append(malformed_failure)
            return {}
        if not isinstance(payload, dict):
            failures.append(malformed_failure)
            return {}
        return payload

    manifest = load_object(
        run_dir / RELEASE_EVIDENCE_RUN_MANIFEST_FILE,
        "releaseEvidenceRunManifestMissing",
        "releaseEvidenceRunManifestInvalid",
    )
    receipt = load_object(
        run_dir / RELEASE_EVIDENCE_PROMOTION_RECEIPT_FILE,
        "releaseEvidencePromotionReceiptMissing",
        "releaseEvidencePromotionReceiptInvalid",
    )
    if manifest and manifest.get("schemaVersion") != RELEASE_EVIDENCE_RUN_MANIFEST_SCHEMA:
        failures.append("releaseEvidenceRunManifestSchemaMismatch")
    if receipt and receipt.get("schemaVersion") != RELEASE_EVIDENCE_PROMOTION_RECEIPT_SCHEMA:
        failures.append("releaseEvidencePromotionReceiptSchemaMismatch")
    if receipt and receipt.get("existingReadinessValidatorAcceptedManagedArtifacts") is not True:
        failures.append("releaseEvidencePromotionReceiptNotValidatorAccepted")
    if receipt and receipt.get("launchReadyClaimed") is not False:
        failures.append("releaseEvidencePromotionReceiptClaimInvalid")
    receipt_dump_dir = trimmed_non_empty(receipt.get("dumpDir"))
    if receipt and receipt_dump_dir is None:
        failures.append("releaseEvidencePromotionReceiptDumpMissing")
    elif receipt_dump_dir is not None:
        try:
            if Path(receipt_dump_dir).expanduser().resolve() != dump_dir:
                failures.append("releaseEvidencePromotionReceiptDumpMismatch")
        except OSError:
            failures.append("releaseEvidencePromotionReceiptDumpMismatch")

    dump_binding = {}
    for sidecar, binding_key in [
        ("source-git-commit.txt", "sourceGitCommit"),
        ("source-coach-fingerprint.txt", "sourceCoachFingerprint"),
    ]:
        try:
            value = (dump_dir / sidecar).read_text(encoding="utf-8").strip()
        except OSError:
            value = ""
        if not value:
            failures.append(f"releaseEvidenceDumpSourceMissing={sidecar}")
        dump_binding[binding_key] = value
    manifest_binding = manifest.get("sourceBinding") if isinstance(manifest.get("sourceBinding"), dict) else {}
    receipt_binding = receipt.get("sourceBinding") if isinstance(receipt.get("sourceBinding"), dict) else {}
    for key, value in dump_binding.items():
        if manifest and manifest_binding.get(key) != value:
            failures.append(f"releaseEvidenceRunSourceMismatch={key}")
        if receipt and receipt_binding.get(key) != value:
            failures.append(f"releaseEvidenceReceiptSourceMismatch={key}")

    receipt_artifacts = receipt.get("artifacts") if isinstance(receipt.get("artifacts"), dict) else {}
    artifact_bindings = []
    for artifact_name in RELEASE_EVIDENCE_MANAGED_ARTIFACTS:
        run_path = run_dir / artifact_name
        dump_path = dump_dir / artifact_name
        receipt_digest = receipt_artifacts.get(artifact_name)
        run_digest = None
        dump_digest = None
        try:
            if run_path.is_file():
                run_digest = sha256_file(run_path)
            else:
                failures.append(f"releaseEvidenceRunArtifactMissing={artifact_name}")
            if dump_path.is_file():
                dump_digest = sha256_file(dump_path)
            else:
                failures.append(f"releaseEvidenceDumpArtifactMissing={artifact_name}")
        except OSError:
            failures.append(f"releaseEvidenceArtifactUnreadable={artifact_name}")
        if not isinstance(receipt_digest, str) or SHA256_PATTERN.fullmatch(receipt_digest) is None:
            failures.append(f"releaseEvidenceReceiptHashInvalid={artifact_name}")
        if (
            run_digest is not None
            and dump_digest is not None
            and receipt_digest is not None
            and not (run_digest == dump_digest == receipt_digest)
        ):
            failures.append(f"releaseEvidenceArtifactHashMismatch={artifact_name}")
        artifact_bindings.append({
            "artifact": artifact_name,
            "runSHA256": run_digest,
            "dumpSHA256": dump_digest,
            "receiptSHA256": receipt_digest,
            "matches": bool(
                run_digest is not None
                and run_digest == dump_digest == receipt_digest
            ),
        })

    failures = list(dict.fromkeys(failures))
    return {
        "runDir": str(run_dir),
        "passes": not failures,
        "failures": failures,
        "validationBoundary": boundary,
        "validator": {
            "schemaVersion": validation.get("schemaVersion"),
            "passes": validation.get("passes") is True,
            "failureCount": validation.get("failureCount"),
            "failures": validation.get("failures") or [],
        },
        "artifactBindings": artifact_bindings,
    }


def release_evidence_run_gate_failures(audit):
    if audit and audit.get("passes") is True:
        return []
    observed = ",".join((audit or {}).get("failures") or ["missingAudit"])
    return [{
        "label": "attachmentBackedReleaseEvidenceRun",
        "observed": observed,
        "gate": (
            "The final release gate must validate the original attachment-backed "
            "evidence run and match its promotion receipt to the active dump."
        ),
        "nextStep": (
            "Pass --release-evidence-run for the validated run used to promote "
            "the four managed external evidence artifacts, then rerun readiness."
        ),
    }]


def computed_launch_ready(
    readiness,
    local_gates,
    artifact_audit=None,
    readiness_manifest=None,
    ops_preflight=None,
    ops_live_probe=None,
    source_freshness_audit=None,
    report_source_audit=None,
    release_evidence_audit=None,
):
    artifact_failures = artifact_gate_failures(artifact_audit) if artifact_audit else []
    manifest_failures = (
        readiness_manifest_gate_failures(readiness_manifest)
        if readiness_manifest else []
    )
    ops_failures = operational_static_gate_failures(ops_preflight) if ops_preflight else []
    ops_live_failures = (
        operational_live_gate_failures(ops_live_probe) if ops_live_probe else []
    )
    source_failures = (
        source_freshness_gate_failures(source_freshness_audit)
        if source_freshness_audit else []
    )
    report_source_failures = (
        report_source_gate_failures(report_source_audit)
        if report_source_audit else []
    )
    release_evidence_failures = release_evidence_run_gate_failures(
        release_evidence_audit
    )
    return (
        computed_production_ready(readiness) and
        not report_source_failures and
        not local_readiness_failures(local_gates, readiness) and
        not source_failures and
        not artifact_failures and
        not manifest_failures and
        not release_evidence_failures and
        not ops_failures and
        not ops_live_failures
    )


def blocking_requirements(readiness):
    blockers = readiness.get("blockers") if readiness else None
    if blockers is None:
        blockers = list(EVIDENCE_REQUIREMENTS.keys())
    requirements = []
    for blocker in blockers:
        requirement = dict(EVIDENCE_REQUIREMENTS.get(blocker, {}))
        requirement["blocker"] = blocker
        if "artifact" not in requirement:
            requirement["artifact"] = "not mapped"
            requirement["gate"] = "Unknown VISION blocker. Update readiness_gate.py."
            requirement["nextStep"] = "Map this blocker to a concrete evidence artifact."
        requirements.append(requirement)
    return requirements


def trimmed_non_empty(value):
    if not isinstance(value, str):
        return None
    trimmed = value.strip()
    return trimmed or None


def strict_int(value):
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def finite_number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return value if math.isfinite(value) else None


def normalized_string_list(value):
    if not isinstance(value, list):
        return [], True
    normalized = [
        item.strip() for item in value
        if isinstance(item, str) and item.strip()
    ]
    return normalized, len(normalized) != len(value)


def normalized_reply_key(value):
    return re.sub(r"\s+", " ", value or "").strip().lower()


def clean_issue_value(value):
    return normalized_reply_key(value) in {"none", "passed", "clean", "no issue", "no issues"}


def generic_placeholder_reply(value):
    normalized = normalized_reply_key(value)
    if not normalized:
        return False
    if (
        normalized == "placeholder"
        or "placeholder reply" in normalized
        or "placeholder coach reply" in normalized
    ):
        return True
    return any(fragment in normalized for fragment in GENERIC_PLACEHOLDER_REPLY_FRAGMENTS)


def row_identifier(row):
    if not isinstance(row, dict):
        return None
    value = row.get("fixtureID")
    return value.strip() if isinstance(value, str) and value.strip() else None


def row_has_provider_evidence(row):
    return bool(
        isinstance(row, dict)
        and trimmed_non_empty(row.get("providerChosen"))
        and trimmed_non_empty(row.get("providerModel"))
    )


def row_has_readiness_telemetry(row):
    if not isinstance(row, dict):
        return False
    proof_hash = trimmed_non_empty(row.get("assessmentProofTestHash"))
    reply = trimmed_non_empty(row.get("reply"))
    quality = trimmed_non_empty(row.get("qualityIssue"))
    semantic = trimmed_non_empty(row.get("semanticGateIssue"))
    immediate_expected = row.get("immediateCoachReadExpected") is True
    immediate_satisfied = not immediate_expected or row.get("immediateCoachReadShown") is True
    return (
        trimmed_non_empty(row.get("turnDepth")) is not None
        and finite_number(row.get("timeToFirstVisibleTokenMs")) is not None
        and finite_number(row.get("assessmentConfidence")) is not None
        and isinstance(row.get("trajectoryCacheHit"), bool)
        and proof_hash is not None
        and reply is not None
        and isinstance(row.get("passesRubric"), bool)
        and isinstance(row.get("visionPassesProductionFloor"), bool)
        and quality is not None
        and semantic is not None
        and isinstance(row.get("reliabilityIssues"), list)
        and immediate_satisfied
    )


def row_has_clean_production_telemetry(row):
    return (
        isinstance(row, dict)
        and row.get("liveProductionFloor") is True
        and row.get("passesRubric") is True
        and row.get("visionPassesProductionFloor") is True
        and clean_issue_value(row.get("qualityIssue"))
        and clean_issue_value(row.get("semanticGateIssue"))
        and row.get("reliabilityIssues") == []
    )


def duplicated_reply_ids(rows):
    first_id_by_reply = {}
    duplicate_ids_by_reply = set()
    for row in rows:
        if not isinstance(row, dict):
            continue
        key = normalized_reply_key(row.get("reply"))
        if not key:
            continue
        row_id = row_identifier(row) or "unknown"
        if key in first_id_by_reply:
            duplicate_ids_by_reply.add(first_id_by_reply[key])
            duplicate_ids_by_reply.add(row_id)
        else:
            first_id_by_reply[key] = row_id
    return sorted(duplicate_ids_by_reply)


def min_trajectory_cache_hits(row_count):
    if row_count <= 0:
        return 0
    return max(1, math.ceil(row_count * MIN_TRAJECTORY_CACHE_HIT_RATIO))


def append_ids_failure(failures, label, ids):
    if ids:
        failures.append(f"{label}={','.join(ids)}")


def rating_minimum(ratings):
    if not isinstance(ratings, dict):
        return 0
    expected = [
        "diagnosis",
        "caseFormulation",
        "intervention",
        "adaptation",
        "perceptionHonesty",
        "transferSetup",
        "trustRepair",
        "overallUsefulness",
    ]
    values = []
    for key in expected:
        value = finite_number(ratings.get(key))
        values.append(value if value is not None else 0)
    return min(values) if values else 0


def professional_row_passes_calibration_floor(row):
    if not isinstance(row, dict):
        return False
    return (
        row.get("calibrationDecision") in {"roughTie", "noumBetter"}
        and row.get("wouldUseWithClient") is True
        and rating_minimum(row.get("ratings")) >= 4
        and strict_int(row.get("humanCoachReferenceCount")) is not None
        and strict_int(row.get("humanCoachReferenceCount")) > 0
        and row.get("overclaimNotes") == []
    )


def calibration_packet_context(root):
    packet_path = Path(root) / PROFESSIONAL_CALIBRATION_PACKET_FILE
    context = {
        "packetPath": str(packet_path),
        "packetPresent": packet_path.is_file(),
        "packetFailures": [],
        "requiredConversationIDs": [],
        "requiredReviewCount": None,
        "requiredReviewsPerConversation": PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION,
        "sourcePacketFingerprint": None,
        "sourcePacketSchemaVersion": PROFESSIONAL_CALIBRATION_PACKET_SCHEMA,
    }
    if not packet_path.is_file():
        context["packetFailures"].append("sourcePacketMissing")
        return context
    try:
        payload = json.loads(packet_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        context["packetFailures"].append(f"sourcePacketInvalidJSON:{exc.msg}")
        return context
    if not isinstance(payload, dict):
        context["packetFailures"].append("sourcePacketInvalidTopLevelType")
        return context

    schema = payload.get("schemaVersion")
    if schema != PROFESSIONAL_CALIBRATION_PACKET_SCHEMA:
        context["packetFailures"].append(f"sourcePacketSchemaVersion={schema}")
    fingerprint = trimmed_non_empty(payload.get("sourceCorpusFingerprint"))
    if fingerprint is None:
        context["packetFailures"].append("sourcePacketFingerprintMissing")
    context["sourcePacketFingerprint"] = fingerprint
    rows = payload.get("rows") if isinstance(payload.get("rows"), list) else []
    conversation_ids = [
        item.get("conversationID").strip()
        for item in rows
        if isinstance(item, dict)
        and isinstance(item.get("conversationID"), str)
        and item.get("conversationID").strip()
    ]
    context["requiredConversationIDs"] = conversation_ids
    reviews_per_conversation = payload.get("requiredIndependentReviewsPerConversation")
    if strict_int(reviews_per_conversation) is not None and reviews_per_conversation > 0:
        context["requiredReviewsPerConversation"] = reviews_per_conversation
        if reviews_per_conversation < PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION:
            context["packetFailures"].append("sourcePacketBelowIndependentReviewFloor")
    required_count = payload.get("requiredReviewCount")
    if strict_int(required_count) is not None and required_count > 0:
        context["requiredReviewCount"] = required_count
    else:
        context["requiredReviewCount"] = len(conversation_ids) * context["requiredReviewsPerConversation"]
    if payload.get("conversationCount") != len(conversation_ids):
        context["packetFailures"].append("sourcePacketConversationCountMismatch")
    if len(set(conversation_ids)) != len(conversation_ids):
        context["packetFailures"].append("sourcePacketDuplicateConversationIDs")
    if context["requiredReviewCount"] != len(conversation_ids) * context["requiredReviewsPerConversation"]:
        context["packetFailures"].append("sourcePacketReviewCountMismatch")
    if len(conversation_ids) < PROFESSIONAL_CALIBRATION_MIN_CONVERSATION_COUNT:
        context["packetFailures"].append("sourcePacketBelowConversationFloor")
    if context["requiredReviewCount"] < PROFESSIONAL_CALIBRATION_MIN_REVIEW_COUNT:
        context["packetFailures"].append("sourcePacketBelowReviewFloor")
    return context


def professional_calibration_contract_failures(payload, context=None):
    failures = []
    context = context or {}
    summary = payload.get("summary") if isinstance(payload.get("summary"), dict) else {}
    rows = payload.get("rows") if isinstance(payload.get("rows"), list) else []
    required_ids = context.get("requiredConversationIDs") or []
    required_reviews_per_conversation = (
        context.get("requiredReviewsPerConversation")
        or PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION
    )
    required_count = context.get("requiredReviewCount")
    if strict_int(required_count) is None or required_count <= 0:
        required_count = len(required_ids) * required_reviews_per_conversation
    required_count = max(required_count, PROFESSIONAL_CALIBRATION_MIN_REVIEW_COUNT)

    for packet_failure in context.get("packetFailures") or []:
        if packet_failure not in failures:
            failures.append(packet_failure)

    if payload.get("sourcePacketSchemaVersion") != PROFESSIONAL_CALIBRATION_PACKET_SCHEMA:
        failures.append(f"sourcePacketSchemaVersion={payload.get('sourcePacketSchemaVersion')}")
    source_fingerprint = trimmed_non_empty(payload.get("sourcePacketFingerprint"))
    expected_fingerprint = trimmed_non_empty(context.get("sourcePacketFingerprint"))
    if source_fingerprint is None:
        failures.append("sourcePacketFingerprintMissing")
    elif expected_fingerprint and source_fingerprint != expected_fingerprint:
        failures.append("sourcePacketFingerprintMismatch")
    elif expected_fingerprint is None:
        failures.append("sourcePacketFingerprintUnavailable")
    if payload.get("rubricVersion") != PROFESSIONAL_CALIBRATION_RUBRIC:
        failures.append(f"rubricVersion={payload.get('rubricVersion')}")

    review_count = payload.get("reviewCount")
    review_count = strict_int(review_count)
    if review_count is None or review_count < required_count or len(rows) < required_count:
        failures.append("fewerThanRequiredReviews")
        failures.append("missingFullConversationCoverage")
    if review_count is not None and review_count != len(rows):
        failures.append("rowCountMismatch")
    if summary.get("rowCount") != len(rows):
        failures.append("rowCountMismatch")

    review_slots = []
    rows_by_conversation = {}
    passing_rows_by_conversation = {}
    reviewer_ids = []
    passing_rows = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        conversation_id = trimmed_non_empty(row.get("conversationID")) or ""
        reviewer_id = trimmed_non_empty(row.get("reviewerID")) or ""
        review_slots.append(f"{conversation_id}|{reviewer_id}")
        rows_by_conversation.setdefault(conversation_id, []).append(row)
        if reviewer_id:
            reviewer_ids.append(reviewer_id)
        if professional_row_passes_calibration_floor(row):
            passing_rows.append(row)
            passing_rows_by_conversation.setdefault(conversation_id, []).append(row)

    if len(set(review_slots)) != len(review_slots):
        failures.append("duplicateConversationReviewerPairs")

    observed_ids = set(rows_by_conversation)
    if required_ids:
        missing_ids = [
            conversation_id for conversation_id in required_ids
            if conversation_id not in observed_ids
        ]
        append_ids_failure(failures, "missingRequiredConversations", missing_ids)
        unexpected_ids = sorted([
            conversation_id for conversation_id in observed_ids
            if conversation_id and conversation_id not in set(required_ids)
        ])
        append_ids_failure(failures, "unexpectedConversationIDs", unexpected_ids)
        insufficient_review_ids = [
            conversation_id for conversation_id in required_ids
            if len(rows_by_conversation.get(conversation_id, [])) < required_reviews_per_conversation
        ]
        append_ids_failure(
            failures,
            "insufficientReviewsPerConversation",
            insufficient_review_ids,
        )
        insufficient_passing_ids = [
            conversation_id for conversation_id in required_ids
            if len(passing_rows_by_conversation.get(conversation_id, [])) < required_reviews_per_conversation
        ]
        append_ids_failure(
            failures,
            "insufficientPassingReviewsPerConversation",
            insufficient_passing_ids,
        )
        insufficient_diversity_ids = []
        for conversation_id in required_ids:
            reviewers = {
                trimmed_non_empty(row.get("reviewerID"))
                for row in rows_by_conversation.get(conversation_id, [])
                if isinstance(row, dict)
            }
            reviewers.discard(None)
            if len(reviewers) < required_reviews_per_conversation:
                insufficient_diversity_ids.append(conversation_id)
        append_ids_failure(
            failures,
            "insufficientReviewerDiversity",
            insufficient_diversity_ids,
        )

    unique_reviewer_ids = set(reviewer_ids)
    reviewer_count = strict_int(summary.get("reviewerCount"))
    completed_review_count = strict_int(summary.get("completedReviewCount"))
    passing_calibration_count = strict_int(summary.get("passingCalibrationCount"))
    would_use_count = strict_int(summary.get("wouldUseWithClientCount"))
    unsafe_count = strict_int(summary.get("unsafeOrUnreadyCount"))
    minimum_usefulness = finite_number(summary.get("minimumOverallUsefulness"))
    average_usefulness = finite_number(summary.get("averageOverallUsefulness"))
    invalid_summary_fields = [
        key for key, value in [
            ("reviewerCount", reviewer_count),
            ("completedReviewCount", completed_review_count),
            ("passingCalibrationCount", passing_calibration_count),
            ("wouldUseWithClientCount", would_use_count),
            ("unsafeOrUnreadyCount", unsafe_count),
            ("minimumOverallUsefulness", minimum_usefulness),
            ("averageOverallUsefulness", average_usefulness),
        ]
        if value is None
    ]
    append_ids_failure(failures, "invalidSummaryTelemetry", invalid_summary_fields)

    if (
        reviewer_count != len(unique_reviewer_ids)
        or reviewer_count is None
        or reviewer_count < required_reviews_per_conversation
        or trimmed_non_empty(payload.get("reviewerRole")) is None
        or any(trimmed_non_empty(row.get("reviewerID")) is None for row in rows if isinstance(row, dict))
    ):
        failures.append("missingProfessionalReviewer")
    if completed_review_count != len(rows):
        failures.append("incompleteReviews")
    if (
        passing_calibration_count != len(passing_rows)
        or passing_calibration_count is None
        or passing_calibration_count < required_count
    ):
        failures.append("insufficientPassingCalibrationRows")
    if would_use_count is None or would_use_count < required_count:
        failures.append("insufficientWouldUseWithClientRows")
    if unsafe_count is None or unsafe_count > 0 or any(
        isinstance(row, dict) and row.get("calibrationDecision") == "unsafeOrUnready"
        for row in rows
    ):
        failures.append("unsafeOrUnreadyRows")
    if any(not professional_row_passes_calibration_floor(row) for row in rows):
        failures.append("rowCalibrationFloorFailures")
    if any(
        isinstance(row, dict)
        and professional_row_passes_calibration_floor(row)
        and row.get("revisionNotes") not in ([], None)
        for row in rows
    ):
        failures.append("unresolvedRevisionNotes")
    if (
        minimum_usefulness is None
        or average_usefulness is None
        or minimum_usefulness < 4
        or average_usefulness < 4.0
    ):
        failures.append("overallUsefulnessBelowFloor")
    readiness_warnings = summary.get("readinessWarnings")
    readiness_warnings = readiness_warnings if isinstance(readiness_warnings, list) else []
    append_ids_failure(failures, "readinessWarnings", [
        item for item in readiness_warnings if isinstance(item, str) and item.strip()
    ])

    deduped = []
    for failure in failures:
        if failure not in deduped:
            deduped.append(failure)
    return deduped


def all_live_operational_rows(payload):
    rows = [row for row in payload.get("rows", []) if isinstance(row, dict)]
    for conversation in payload.get("longFormConversations", []):
        if not isinstance(conversation, dict):
            continue
        nested = conversation.get("rows")
        if isinstance(nested, list):
            rows.extend(row for row in nested if isinstance(row, dict))
    return rows


def live_identity_looks_non_live(value):
    value = trimmed_non_empty(value)
    return (
        value is None
        or NON_LIVE_PROVIDER_IDENTITY_PATTERN.search(value) is not None
    )


def live_provider_runtime_provenance_failures(payload):
    """Require transport-path identities and telemetry for every live row."""
    failures = []
    provider_chain = payload.get("providerChain")
    if not isinstance(provider_chain, list) or not provider_chain:
        failures.append("liveProviderChainMissing")
    else:
        for identity in provider_chain:
            if live_identity_looks_non_live(identity):
                failures.append(f"nonLiveProviderChainIdentity={identity!r}")

    for index, row in enumerate(all_live_operational_rows(payload)):
        row_id = row_identifier(row) or f"row-{index + 1}"
        if (
            live_identity_looks_non_live(row.get("providerChosen"))
            or live_identity_looks_non_live(row.get("providerModel"))
        ):
            failures.append(f"nonLiveProviderIdentity={row_id}")

        attempts = strict_int(row.get("providerAttemptCount"))
        retries = strict_int(row.get("providerRetryCount"))
        refusals = strict_int(row.get("providerRefusalCount"))
        completion = finite_number(row.get("timeToCompleteReplyMs"))
        if attempts is None or attempts < 1:
            failures.append(f"providerAttemptTelemetryMissing={row_id}")
        if retries is None or retries < 0:
            failures.append(f"providerRetryTelemetryMissing={row_id}")
        if refusals is None or refusals < 0:
            failures.append(f"providerRefusalTelemetryMissing={row_id}")
        if completion is None or completion < 0:
            failures.append(f"providerCompletionLatencyMissing={row_id}")

        diagnostics = row.get("diagnostics")
        if not isinstance(diagnostics, list) or not diagnostics:
            failures.append(f"providerDiagnosticsMissing={row_id}")
            continue
        has_latency = False
        has_verified_transport_success = False
        for diagnostic in diagnostics:
            if not isinstance(diagnostic, dict):
                failures.append(f"providerDiagnosticMalformed={row_id}")
                continue
            latency = finite_number(diagnostic.get("latencyMs"))
            status_code = strict_int(diagnostic.get("statusCode"))
            diagnostic_is_well_formed = (
                not live_identity_looks_non_live(diagnostic.get("provider"))
                and trimmed_non_empty(diagnostic.get("outcome")) is not None
                and trimmed_non_empty(diagnostic.get("reason")) is not None
            )
            if not diagnostic_is_well_formed:
                failures.append(f"providerDiagnosticMalformed={row_id}")
            if latency is not None and latency >= 0:
                has_latency = True
            if (
                diagnostic_is_well_formed
                and diagnostic.get("outcome") == "success"
                and status_code is not None
                and 200 <= status_code < 300
                and latency is not None
                and latency >= 0
            ):
                has_verified_transport_success = True
        if not has_latency:
            failures.append(f"providerDiagnosticLatencyMissing={row_id}")
        if not has_verified_transport_success:
            failures.append(f"providerTransportSuccessMissing={row_id}")
    return list(dict.fromkeys(failures))


def published_live_evidence_provenance_failures(payload):
    provenance = payload.get("liveEvidenceProvenance")
    if not isinstance(provenance, dict):
        return ["publishedLiveEvidenceProvenanceMissing"]
    expected = {
        "schemaVersion": LIVE_EVIDENCE_ATTESTATION_SCHEMA,
        "producer": LIVE_EVIDENCE_PRODUCER,
        "executionMode": "liveProviderProductionPath",
        "candidateSource": "providerNetworkResponse",
        "usesReplayResponses": False,
        "usesFixtureResponses": False,
        "usesTemplateResponses": False,
    }
    failures = [
        f"publishedLiveEvidenceProvenanceMismatch={key}"
        for key, expected_value in expected.items()
        if provenance.get(key) != expected_value
    ]
    if trimmed_non_empty(provenance.get("runID")) is None:
        failures.append("publishedLiveEvidenceRunIDMissing")
    if not usable_iso8601_timestamp(provenance.get("capturedAt")):
        failures.append("publishedLiveEvidenceTimestampInvalid")
    capture_sha = trimmed_non_empty(provenance.get("captureSHA256"))
    if capture_sha is None or SHA256_PATTERN.fullmatch(capture_sha) is None:
        failures.append("publishedLiveEvidenceCaptureSHA256Invalid")
    return failures


def live_provider_sweep_contract_failures(
    payload,
    source_expectations=None,
    require_published_provenance=True,
):
    failures = []
    source_expectations = source_expectations or {}
    rows = payload.get("rows") if isinstance(payload.get("rows"), list) else []
    summary = payload.get("summary") if isinstance(payload.get("summary"), dict) else {}
    long_form_passing, malformed_passing_ids = normalized_string_list(
        payload.get("longFormConversationIDsPassingProductionFloor")
    )
    long_form_failures, malformed_failure_ids = normalized_string_list(
        payload.get("longFormConversationFailureIDs")
    )
    long_form_details = payload.get("longFormConversations")
    long_form_details = long_form_details if isinstance(long_form_details, list) else []
    if malformed_passing_ids:
        failures.append("invalidLongFormPassingIDs")
    if malformed_failure_ids:
        failures.append("invalidLongFormFailureIDs")
    if any(not isinstance(item, dict) for item in long_form_details):
        failures.append("invalidDetailedLongFormConversationRows")

    source_git_commit = trimmed_non_empty(payload.get("sourceGitCommit"))
    source_coach_fingerprint = trimmed_non_empty(payload.get("sourceCoachFingerprint"))
    if source_git_commit is None:
        failures.append("sourceGitCommitMissing")
    if source_coach_fingerprint is None:
        failures.append("sourceCoachFingerprintMissing")

    expected_commit = trimmed_non_empty(source_expectations.get("source-git-commit.txt"))
    expected_fingerprint = trimmed_non_empty(source_expectations.get("source-coach-fingerprint.txt"))
    if expected_commit and source_git_commit and source_git_commit != expected_commit:
        failures.append("sourceGitCommitMismatch")
    if expected_fingerprint and source_coach_fingerprint and source_coach_fingerprint != expected_fingerprint:
        failures.append("sourceCoachFingerprintMismatch")

    freshness_failures = payload.get("sourceFreshnessFailures")
    if freshness_failures is not None:
        if not isinstance(freshness_failures, list):
            failures.append("invalidSourceFreshnessFailures")
        else:
            for freshness_failure in freshness_failures:
                reason = trimmed_non_empty(freshness_failure)
                if reason and reason not in failures:
                    failures.append(reason)

    fixture_count = payload.get("fixtureCount")
    fixture_count = strict_int(fixture_count)
    if fixture_count is None or fixture_count < 10 or len(rows) < 10:
        failures.append("fewerThanTenRows")
    if fixture_count is None or fixture_count < len(LIVE_REQUIRED_FIXTURE_IDS) or len(rows) < len(LIVE_REQUIRED_FIXTURE_IDS):
        failures.append("missingLatestTranscriptCoverage")

    if fixture_count is not None and fixture_count != len(rows):
        failures.append("rowCountMismatch")
    if summary.get("rowCount") != len(rows):
        failures.append("rowCountMismatch")

    fixture_ids = [row_identifier(row) for row in rows]
    fixture_ids = [item for item in fixture_ids if item]
    if len(set(fixture_ids)) != len(fixture_ids):
        failures.append("duplicateFixtureIDs")
    missing_fixture_ids = [
        fixture_id for fixture_id in LIVE_REQUIRED_FIXTURE_IDS
        if fixture_id not in set(fixture_ids)
    ]
    append_ids_failure(failures, "missingRequiredFixtures", missing_fixture_ids)

    long_form_count = strict_int(payload.get("longFormConversationCount"))
    if (
        long_form_count is None
        or long_form_count < len(LIVE_REQUIRED_LONG_FORM_IDS)
        or len(long_form_passing) < len(LIVE_REQUIRED_LONG_FORM_IDS)
    ):
        failures.append("missingLiveLongFormConversationCoverage")
    if long_form_count is not None and long_form_count != len(long_form_passing) + len(long_form_failures):
        failures.append("longFormConversationCountMismatch")

    long_form_passing_ids = long_form_passing
    if len(set(long_form_passing_ids)) != len(long_form_passing_ids):
        failures.append("duplicateLongFormConversationIDs")
    missing_long_form_ids = [
        conversation_id for conversation_id in LIVE_REQUIRED_LONG_FORM_IDS
        if conversation_id not in set(long_form_passing_ids)
    ]
    append_ids_failure(failures, "missingRequiredLongFormConversations", missing_long_form_ids)
    unexpected_long_form_ids = sorted([
        conversation_id for conversation_id in set(long_form_passing_ids + long_form_failures)
        if conversation_id not in set(LIVE_REQUIRED_LONG_FORM_IDS)
    ])
    append_ids_failure(
        failures,
        "unexpectedLongFormConversationIDs",
        unexpected_long_form_ids,
    )

    detailed_ids = [
        item.get("conversationID", "").strip()
        for item in long_form_details
        if isinstance(item, dict) and isinstance(item.get("conversationID"), str)
    ]
    if not long_form_details:
        failures.append("missingDetailedLongFormConversations")
    if len(set(detailed_ids)) != len(detailed_ids):
        failures.append("duplicateDetailedLongFormConversationIDs")
    if long_form_count is not None and long_form_details and len(long_form_details) != long_form_count:
        failures.append("detailedLongFormConversationCountMismatch")
    missing_detailed_ids = [
        conversation_id for conversation_id in LIVE_REQUIRED_LONG_FORM_IDS
        if conversation_id not in set(detailed_ids)
    ]
    append_ids_failure(
        failures,
        "missingDetailedLongFormConversations",
        missing_detailed_ids,
    )
    unexpected_detailed_ids = sorted([
        conversation_id for conversation_id in set(detailed_ids)
        if conversation_id not in set(LIVE_REQUIRED_LONG_FORM_IDS)
    ])
    append_ids_failure(
        failures,
        "unexpectedDetailedLongFormConversations",
        unexpected_detailed_ids,
    )

    detailed_passing_ids = {
        item.get("conversationID")
        for item in long_form_details
        if isinstance(item, dict) and item.get("liveProductionFloor") is True
    }
    detailed_failure_ids = {
        item.get("conversationID")
        for item in long_form_details
        if isinstance(item, dict) and item.get("liveProductionFloor") is not True
    }
    if long_form_details and set(long_form_passing_ids) != detailed_passing_ids:
        failures.append("longFormConversationPassingSummaryMismatch")
    if long_form_details and set(long_form_failures) != detailed_failure_ids:
        failures.append("longFormConversationFailureSummaryMismatch")

    malformed_long_form = []
    failed_long_form = []
    missing_detailed_provider = []
    missing_detailed_telemetry = []
    detailed_gate_failures = []
    duplicated_detailed_replies = []
    generic_detailed_replies = []
    for conversation in long_form_details:
        if not isinstance(conversation, dict):
            continue
        conversation_id = conversation.get("conversationID") or "unknown"
        nested_rows = conversation.get("rows") if isinstance(conversation.get("rows"), list) else []
        observed = strict_int(conversation.get("observedTurnCount"))
        expected = strict_int(conversation.get("expectedTurnCount"))
        required_expected = LIVE_REQUIRED_LONG_FORM_TURN_COUNTS.get(conversation_id)
        if (
            not nested_rows
            or observed != len(nested_rows)
            or observed != expected
            or expected != required_expected
        ):
            malformed_long_form.append(conversation_id)
        if (
            conversation.get("liveProductionFloor") is not True
            or conversation.get("failure") is not None
            or any(row.get("liveProductionFloor") is not True for row in nested_rows if isinstance(row, dict))
        ):
            failed_long_form.append(conversation_id)
        if any(not row_has_provider_evidence(row) for row in nested_rows):
            missing_detailed_provider.append(conversation_id)
        if any(not row_has_readiness_telemetry(row) for row in nested_rows):
            missing_detailed_telemetry.append(conversation_id)
        if any(not row_has_clean_production_telemetry(row) for row in nested_rows):
            detailed_gate_failures.append(conversation_id)
        if duplicated_reply_ids(nested_rows):
            duplicated_detailed_replies.append(conversation_id)
        if any(generic_placeholder_reply(row.get("reply")) for row in nested_rows if isinstance(row, dict)):
            generic_detailed_replies.append(conversation_id)

    append_ids_failure(failures, "malformedDetailedLongFormConversations", malformed_long_form)
    append_ids_failure(failures, "detailedLongFormProductionFloorFailures", failed_long_form)
    append_ids_failure(failures, "missingDetailedLongFormProviderEvidence", missing_detailed_provider)
    append_ids_failure(failures, "missingDetailedLongFormTelemetry", missing_detailed_telemetry)
    append_ids_failure(failures, "detailedLongFormGateTelemetryFailures", detailed_gate_failures)
    append_ids_failure(failures, "duplicatedDetailedLongFormReplies", duplicated_detailed_replies)
    append_ids_failure(failures, "genericDetailedLongFormReplies", generic_detailed_replies)

    latest_provider_failures = [
        row_identifier(row) or "unknown" for row in rows
        if not row_has_provider_evidence(row)
    ]
    latest_telemetry_failures = [
        row_identifier(row) or "unknown" for row in rows
        if not row_has_readiness_telemetry(row)
    ]
    latest_gate_failures = [
        row_identifier(row) or "unknown" for row in rows
        if not row_has_clean_production_telemetry(row)
    ]
    append_ids_failure(failures, "latestTurnProviderEvidenceFailures", latest_provider_failures)
    append_ids_failure(failures, "latestTurnReadinessTelemetryFailures", latest_telemetry_failures)
    append_ids_failure(failures, "latestTurnGateTelemetryFailures", latest_gate_failures)

    # Latest-turn fixtures represent independent users and should usually be
    # cold. Warm cache reuse is exercised by later turns in the detailed live
    # conversations, so readiness must audit the complete operational set.
    operational_rows = list(rows)
    for conversation in long_form_details:
        if not isinstance(conversation, dict):
            continue
        nested_rows = conversation.get("rows")
        if isinstance(nested_rows, list):
            operational_rows.extend(row for row in nested_rows if isinstance(row, dict))

    operational_trajectory_cache_hit_rows = [
        row_identifier(row) or "unknown" for row in operational_rows
        if row.get("trajectoryCacheHit") is True
    ]
    required_trajectory_hits = min_trajectory_cache_hits(len(operational_rows))
    summary_trajectory_hits = strict_int(summary.get("trajectoryCacheHitCount"))
    if (
        "trajectoryCacheHitCount" in summary
        and summary_trajectory_hits != len(operational_trajectory_cache_hit_rows)
    ):
        failures.append("trajectoryCacheHitSummaryMismatch")
    if len(operational_trajectory_cache_hit_rows) < required_trajectory_hits:
        failures.append(
            "weakTrajectoryCacheCoverage="
            f"{len(operational_trajectory_cache_hit_rows)}/{required_trajectory_hits}"
        )

    duplicated_latest_replies = duplicated_reply_ids(rows)
    append_ids_failure(failures, "duplicatedLatestTurnReplies", duplicated_latest_replies)
    generic_latest_replies = [
        row_identifier(row) or "unknown" for row in rows
        if isinstance(row, dict) and generic_placeholder_reply(row.get("reply"))
    ]
    append_ids_failure(failures, "genericLatestTurnReplies", generic_latest_replies)

    observed_depths = {
        row.get("turnDepth") for row in rows
        if isinstance(row, dict) and isinstance(row.get("turnDepth"), str)
    }
    missing_depths = [
        depth for depth in LIVE_REQUIRED_TURN_DEPTHS
        if depth not in observed_depths
    ]
    append_ids_failure(failures, "missingTurnDepthCoverage", missing_depths)

    provider_chain = payload.get("providerChain")
    if not isinstance(provider_chain, list) or not provider_chain or latest_provider_failures:
        failures.append("missingProviderEvidence")
    if payload.get("passesProductionFloor") is not True:
        failures.append("passesProductionFloor=false")
    if payload.get("passesRunReadinessFloor") is not True:
        failures.append("passesRunReadinessFloor=false")
    production_failure_count = strict_int(summary.get("productionFloorFailureCount"))
    immediate_missing_count = strict_int(summary.get("immediateCoachReadMissingCount"))
    confidence_distinct_count = strict_int(summary.get("assessmentConfidenceDistinctRoundedCount"))
    unique_proof_count = strict_int(summary.get("uniqueProofTestHashCount"))
    repeated_proof_count = strict_int(summary.get("repeatedProofTestHashCount"))
    invalid_summary_fields = [
        key for key, value in [
            ("productionFloorFailureCount", production_failure_count),
            ("immediateCoachReadMissingCount", immediate_missing_count),
            ("assessmentConfidenceDistinctRoundedCount", confidence_distinct_count),
            ("uniqueProofTestHashCount", unique_proof_count),
            ("repeatedProofTestHashCount", repeated_proof_count),
        ]
        if value is None
    ]
    append_ids_failure(failures, "invalidSummaryTelemetry", invalid_summary_fields)

    if production_failure_count is None or production_failure_count > 0 or any(
        isinstance(row, dict) and row.get("liveProductionFloor") is not True
        for row in rows
    ):
        failures.append("productionFloorFailures")
    append_ids_failure(failures, "longFormConversationFailures", [
        item for item in long_form_failures if isinstance(item, str) and item.strip()
    ])
    readiness_warnings = summary.get("readinessWarnings")
    readiness_warnings = readiness_warnings if isinstance(readiness_warnings, list) else []
    append_ids_failure(failures, "readinessWarnings", [
        item for item in readiness_warnings if isinstance(item, str) and item.strip()
    ])
    if immediate_missing_count is None or immediate_missing_count > 0:
        failures.append("missingImmediateCoachRead")
    if confidence_distinct_count is None or confidence_distinct_count < 3:
        failures.append("flatAssessmentConfidence")
    if (
        unique_proof_count is None
        or repeated_proof_count is None
        or unique_proof_count < 3
        or repeated_proof_count > 0
    ):
        failures.append("weakProofTestVariety")

    failures.extend(live_provider_runtime_provenance_failures(payload))
    if require_published_provenance:
        failures.extend(published_live_evidence_provenance_failures(payload))

    deduped = []
    for failure in failures:
        if failure not in deduped:
            deduped.append(failure)
    return deduped


def usable_evidence_reference(value):
    normalized = normalized_reply_key(value if isinstance(value, str) else "")
    return bool(normalized) and normalized not in {
        "n/a", "na", "none", "todo", "tbd", "placeholder", "unknown",
    }


def parse_iso8601_timestamp(value):
    normalized = trimmed_non_empty(value)
    if normalized is None:
        return None
    try:
        parsed = datetime.fromisoformat(normalized.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo is not None else None


def usable_iso8601_timestamp(value):
    return parse_iso8601_timestamp(value) is not None


def real_user_transfer_scale_signal(payload, release_contract_passes=False):
    install_cohort = (
        payload.get("installCohort")
        if isinstance(payload.get("installCohort"), dict)
        else {}
    )
    observed = strict_int(install_cohort.get("qualifiedInstallCount")) or 0
    return {
        "key": "scaleConversionCohortReadiness",
        "observedCount": observed,
        "requiredCount": REAL_USER_TRANSFER_SCALE_INSTALLS,
        "ready": bool(
            release_contract_passes
            and observed >= REAL_USER_TRANSFER_SCALE_INSTALLS
        ),
        "blocking": False,
    }


def real_user_transfer_row_passes(row):
    if not isinstance(row, dict):
        return False
    identity_keys = ["outcomeID", "userIDHash", "momentCategory", "interventionID"]
    evidence_keys = [
        "interventionEvidenceReference",
        "momentEvidenceReference",
        "followUpEvidenceReference",
        "audienceResponseEvidenceReference",
        "selfReportEvidenceReference",
    ]
    days_since_first = strict_int(row.get("daysSinceFirstNoumSession"))
    follow_up_delay = strict_int(row.get("followUpDelayHours"))
    linked_interventions = strict_int(row.get("linkedCoachInterventionCount"))
    pre_confidence = strict_int(row.get("preMomentConfidence"))
    post_confidence = strict_int(row.get("postMomentConfidence"))
    adverse_reported = row.get("adverseOutcomeReported") is True
    adverse_resolved = row.get("adverseOutcomeResolved") is True
    adverse_follow_up = usable_evidence_reference(
        row.get("adverseOutcomeFollowUpReference")
    )
    positive_reported = row.get("positiveTransferReported")
    negative_reported = row.get("negativeOutcomeReported")
    return bool(
        all(trimmed_non_empty(row.get(key)) for key in identity_keys)
        and SHA256_PATTERN.fullmatch(row.get("userIDHash") or "") is not None
        and all(usable_evidence_reference(row.get(key)) for key in evidence_keys)
        and row.get("realWorldMomentOccurred") is True
        and row.get("followUpCompleted") is True
        and linked_interventions is not None and linked_interventions > 0
        and days_since_first is not None and days_since_first >= 7
        and follow_up_delay is not None
        and follow_up_delay >= REAL_USER_TRANSFER_MIN_FOLLOW_UP_HOURS
        and pre_confidence is not None and 1 <= pre_confidence <= 5
        and post_confidence is not None and 1 <= post_confidence <= 5
        and row.get("audienceResponseEvidenceCollected") is True
        and isinstance(positive_reported, bool)
        and isinstance(negative_reported, bool)
        and not (positive_reported and negative_reported)
        and (not adverse_reported or (adverse_resolved and adverse_follow_up))
        and row.get("causalityClaims") == []
    )


def real_user_transfer_contract_failures(payload):
    failures = []
    rows = payload.get("rows") if isinstance(payload.get("rows"), list) else []
    summary = payload.get("summary") if isinstance(payload.get("summary"), dict) else {}
    if any(not isinstance(row, dict) for row in rows):
        failures.append("invalidOutcomeRows")
    typed_rows = [row for row in rows if isinstance(row, dict)]

    if payload.get("templateStatus") != "COLLECTED_EXTERNAL_EVIDENCE":
        failures.append("transferNotMarkedCollected")

    attestation = (
        payload.get("studyAttestation")
        if isinstance(payload.get("studyAttestation"), dict)
        else {}
    )
    principal_id = trimmed_non_empty(attestation.get("principalInvestigatorID"))
    analyst_id = trimmed_non_empty(attestation.get("analystID"))
    if principal_id is None or analyst_id is None or principal_id == analyst_id:
        failures.append("invalidStudyRoles")
    required_attestations = [
        "attestsCompleteEnrollmentAccounting",
        "attestsWithdrawalsAndExclusionsWereRetained",
        "attestsNegativeAndAdverseOutcomesWereRetained",
        "attestsNoSyntheticParticipantsOrInstallsWereCounted",
    ]
    if any(attestation.get(key) is not True for key in required_attestations):
        failures.append("incompleteStudyAttestation")
    attestation_reference_keys = [
        "attestationReference",
        "participantConsentLogReference",
        "withdrawalLogReference",
        "exclusionLogReference",
        "negativeOutcomeLogReference",
        "adverseOutcomeLogReference",
        "populationProvenanceReference",
    ]
    if (
        not usable_iso8601_timestamp(attestation.get("attestedAtISO8601"))
        or any(
            not usable_evidence_reference(attestation.get(key))
            for key in attestation_reference_keys
        )
    ):
        failures.append("missingStudyAttestationEvidence")

    study_window = (
        payload.get("studyWindow")
        if isinstance(payload.get("studyWindow"), dict)
        else {}
    )
    study_started_at = parse_iso8601_timestamp(
        study_window.get("startedAtISO8601")
    )
    study_completed_at = parse_iso8601_timestamp(
        study_window.get("completedAtISO8601")
    )
    study_elapsed_seconds = None
    if study_started_at is not None and study_completed_at is not None:
        study_elapsed_seconds = (
            study_completed_at - study_started_at
        ).total_seconds()
    if study_elapsed_seconds is None or study_elapsed_seconds < 0:
        failures.append("invalidStudyWindow")
    elif study_elapsed_seconds < REAL_USER_TRANSFER_MIN_STUDY_SECONDS:
        failures.append("insufficientLongitudinalWindow")

    install_cohort = (
        payload.get("installCohort")
        if isinstance(payload.get("installCohort"), dict)
        else {}
    )
    qualified_installs = strict_int(install_cohort.get("qualifiedInstallCount"))
    day1_eligible = strict_int(install_cohort.get("day1EligibleInstallCount"))
    day1_retained = strict_int(install_cohort.get("day1RetainedInstallCount"))
    day7_eligible = strict_int(install_cohort.get("day7EligibleInstallCount"))
    day7_retained = strict_int(install_cohort.get("day7RetainedInstallCount"))
    install_counts = [
        qualified_installs,
        day1_eligible,
        day1_retained,
        day7_eligible,
        day7_retained,
    ]
    install_started_at = parse_iso8601_timestamp(
        install_cohort.get("cohortStartedAtISO8601")
    )
    install_completed_at = parse_iso8601_timestamp(
        install_cohort.get("cohortCompletedAtISO8601")
    )
    storefronts = install_cohort.get("storefronts")
    install_metadata_valid = bool(
        install_cohort.get("source") == REAL_USER_TRANSFER_INSTALL_SOURCE
        and trimmed_non_empty(install_cohort.get("appVersion"))
        and isinstance(storefronts, list)
        and storefronts
        and all(trimmed_non_empty(value) for value in storefronts)
        and len(set(storefronts)) == len(storefronts)
        and usable_evidence_reference(
            install_cohort.get("qualificationCriteriaReference")
        )
        and usable_evidence_reference(
            install_cohort.get("retentionEvidenceReference")
        )
        and install_started_at is not None
        and install_completed_at is not None
        and install_completed_at >= install_started_at
        and study_started_at is not None
        and study_completed_at is not None
        and install_started_at >= study_started_at
        and install_completed_at <= study_completed_at
    )
    if (
        not install_metadata_valid
        or any(value is None or value < 0 for value in install_counts)
    ):
        failures.append("invalidInstallCohort")
    else:
        if qualified_installs < REAL_USER_TRANSFER_REQUIRED_RELEASE_INSTALLS:
            failures.append("insufficientQualifiedReleaseInstalls")
        if day1_eligible < REAL_USER_TRANSFER_REQUIRED_RELEASE_INSTALLS:
            failures.append("insufficientDay1EligibleInstalls")
        if day7_eligible < REAL_USER_TRANSFER_REQUIRED_RELEASE_INSTALLS:
            failures.append("insufficientDay7EligibleInstalls")
        if not (
            day1_retained <= day1_eligible <= qualified_installs
            and day7_retained <= day7_eligible <= qualified_installs
        ):
            failures.append("invalidRetentionCounts")

    if payload.get("studyProtocolVersion") != REAL_USER_TRANSFER_PROTOCOL:
        failures.append(f"studyProtocolVersion={payload.get('studyProtocolVersion')}")
    if not all(usable_evidence_reference(payload.get(key)) for key in [
        "protocolRegistrationReference", "analysisPlanReference", "benchmarkReference",
    ]):
        failures.append("missingPreregisteredStudyReferences")
    if payload.get("comparisonMethod") != "prePostWithinUser":
        failures.append(f"unsupportedComparisonMethod={payload.get('comparisonMethod')}")
    outcome_count = strict_int(payload.get("outcomeCount"))
    if (
        outcome_count is None
        or outcome_count < REAL_USER_TRANSFER_REQUIRED_OUTCOMES
        or len(rows) < REAL_USER_TRANSFER_REQUIRED_OUTCOMES
    ):
        failures.append("fewerThanThirtyOutcomes")
    if outcome_count != len(rows) or strict_int(summary.get("rowCount")) != len(rows):
        failures.append("rowCountMismatch")

    outcome_keys = [normalized_reply_key(row.get("outcomeID")) for row in typed_rows]
    user_keys = [normalized_reply_key(row.get("userIDHash")) for row in typed_rows]
    moment_keys = [normalized_reply_key(row.get("momentCategory")) for row in typed_rows]
    missing_identity = []
    for index, row in enumerate(typed_rows):
        if not all(trimmed_non_empty(row.get(key)) for key in [
            "outcomeID", "userIDHash", "momentCategory", "interventionID",
        ]):
            missing_identity.append(trimmed_non_empty(row.get("outcomeID")) or f"row-{index}")
    if len(set(outcome_keys)) != len(rows):
        failures.append("duplicateOutcomeIDs")
    append_ids_failure(failures, "missingRowIdentity", missing_identity)
    invalid_user_hashes = [
        row.get("outcomeID") or f"row-{index}"
        for index, row in enumerate(typed_rows)
        if SHA256_PATTERN.fullmatch(row.get("userIDHash") or "") is None
    ]
    append_ids_failure(failures, "invalidParticipantHashes", invalid_user_hashes)

    unique_users = len(set(user_keys))
    if (
        strict_int(summary.get("uniqueUserCount")) != unique_users
        or unique_users < REAL_USER_TRANSFER_REQUIRED_USERS
    ):
        failures.append("insufficientQualifiedQualitativeParticipants")

    enrollment = payload.get("enrollment") if isinstance(payload.get("enrollment"), dict) else {}
    enrolled_users = strict_int(enrollment.get("enrolledUserCount"))
    completed_users = strict_int(enrollment.get("completedUserCount"))
    withdrawn_users = strict_int(enrollment.get("withdrawnUserCount"))
    excluded_users = strict_int(enrollment.get("excludedUserCount"))
    qualified_users = strict_int(
        enrollment.get("qualifiedQualitativeParticipantCount")
    )
    enrollment_counts = [
        enrolled_users,
        qualified_users,
        completed_users,
        withdrawn_users,
        excluded_users,
    ]
    enrollment_coherent = bool(
        all(value is not None and value >= 0 for value in enrollment_counts)
        and enrolled_users is not None and enrolled_users > 0
        and completed_users + withdrawn_users + excluded_users == enrolled_users
        and qualified_users == unique_users
        and qualified_users >= REAL_USER_TRANSFER_REQUIRED_USERS
        and completed_users == unique_users
        and usable_evidence_reference(
            enrollment.get("participantQualificationCriteriaReference")
        )
        and usable_evidence_reference(enrollment.get("exclusionLogReference"))
        and enrollment.get("exclusionLogReference")
        == attestation.get("exclusionLogReference")
    )
    completion_rate = (
        completed_users / enrolled_users
        if enrollment_coherent and enrolled_users else 0
    )
    if (
        not enrollment_coherent
        or completion_rate < REAL_USER_TRANSFER_MIN_COHORT_COMPLETION_RATE
    ):
        failures.append("invalidOrInsufficientCohortCompletion")
    unique_moments = len(set(moment_keys))
    if (
        strict_int(summary.get("uniqueMomentCategoryCount")) != unique_moments
        or unique_moments < REAL_USER_TRANSFER_REQUIRED_MOMENT_CATEGORIES
    ):
        failures.append("insufficientMomentCategoryDiversity")

    outcomes_by_user = {}
    for user_key in user_keys:
        outcomes_by_user[user_key] = outcomes_by_user.get(user_key, 0) + 1
    maximum_per_user = max(outcomes_by_user.values(), default=0)
    if (
        strict_int(summary.get("maximumOutcomesPerUser")) != maximum_per_user
        or maximum_per_user > REAL_USER_TRANSFER_MAX_OUTCOMES_PER_USER
    ):
        failures.append("excessiveOutcomesPerUser")

    evidence_keys = [
        "interventionEvidenceReference",
        "momentEvidenceReference",
        "followUpEvidenceReference",
        "audienceResponseEvidenceReference",
        "selfReportEvidenceReference",
    ]
    verified_evidence_count = sum(
        all(usable_evidence_reference(row.get(key)) for key in evidence_keys)
        for row in typed_rows
    )
    if (
        strict_int(summary.get("verifiedEvidenceReferenceCount")) != verified_evidence_count
        or verified_evidence_count < REAL_USER_TRANSFER_REQUIRED_OUTCOMES
        or verified_evidence_count < len(rows)
    ):
        failures.append("insufficientEvidenceReferences")

    follow_up_delays = [strict_int(row.get("followUpDelayHours")) for row in typed_rows]
    minimum_follow_up = min((value for value in follow_up_delays if value is not None), default=0)
    if (
        any(value is None for value in follow_up_delays)
        or strict_int(summary.get("minimumFollowUpDelayHours")) != minimum_follow_up
        or minimum_follow_up < REAL_USER_TRANSFER_MIN_FOLLOW_UP_HOURS
    ):
        failures.append("insufficientFollowUpDelay")

    count_contracts = [
        ("completedFollowUpCount", "followUpCompleted", "insufficientCompletedFollowUps"),
        ("realWorldMomentCount", "realWorldMomentOccurred", "insufficientRealWorldMoments"),
        ("audienceResponseEvidenceCount", "audienceResponseEvidenceCollected", "insufficientAudienceResponseEvidence"),
    ]
    for summary_key, row_key, failure in count_contracts:
        observed = sum(row.get(row_key) is True for row in typed_rows)
        if strict_int(summary.get(summary_key)) != observed or observed < REAL_USER_TRANSFER_REQUIRED_OUTCOMES:
            failures.append(failure)

    positive_count = sum(row.get("positiveTransferReported") is True for row in typed_rows)
    negative_count = sum(row.get("negativeOutcomeReported") is True for row in typed_rows)
    invalid_outcome_classification = [
        row.get("outcomeID") or f"row-{index}"
        for index, row in enumerate(typed_rows)
        if (
            not isinstance(row.get("positiveTransferReported"), bool)
            or not isinstance(row.get("negativeOutcomeReported"), bool)
            or (
                row.get("positiveTransferReported") is True
                and row.get("negativeOutcomeReported") is True
            )
        )
    ]
    append_ids_failure(
        failures,
        "invalidOutcomeClassification",
        invalid_outcome_classification,
    )
    if strict_int(summary.get("negativeOutcomeCount")) != negative_count:
        failures.append("negativeOutcomeCountMismatch")
    minimum_positive_count = math.ceil(
        len(typed_rows) * REAL_USER_TRANSFER_MIN_POSITIVE_RATE
    )
    if (
        strict_int(summary.get("positiveTransferCount")) != positive_count
        or positive_count < minimum_positive_count
    ):
        failures.append("insufficientPositiveTransferOutcomes")

    linked_count = sum((strict_int(row.get("linkedCoachInterventionCount")) or 0) > 0 for row in typed_rows)
    if (
        strict_int(summary.get("linkedInterventionOutcomeCount")) != linked_count
        or linked_count < REAL_USER_TRANSFER_REQUIRED_OUTCOMES
    ):
        failures.append("insufficientLinkedInterventions")
    no_regression_count = sum(
        strict_int(row.get("preMomentConfidence")) is not None
        and strict_int(row.get("postMomentConfidence")) is not None
        and strict_int(row.get("postMomentConfidence")) >= strict_int(row.get("preMomentConfidence"))
        for row in typed_rows
    )
    if (
        strict_int(summary.get("noRegressionOutcomeCount")) != no_regression_count
        or no_regression_count < math.ceil(
            len(typed_rows) * REAL_USER_TRANSFER_MIN_NO_REGRESSION_RATE
        )
    ):
        failures.append("insufficientNoRegressionOutcomes")
    adverse_count = sum(row.get("adverseOutcomeReported") is True for row in typed_rows)
    resolved_adverse_count = sum(
        row.get("adverseOutcomeReported") is True
        and row.get("adverseOutcomeResolved") is True
        and usable_evidence_reference(row.get("adverseOutcomeFollowUpReference"))
        for row in typed_rows
    )
    if (
        strict_int(summary.get("adverseOutcomeCount")) != adverse_count
        or strict_int(summary.get("resolvedAdverseOutcomeCount")) != resolved_adverse_count
        or resolved_adverse_count != adverse_count
    ):
        failures.append("unresolvedAdverseOutcomes")
    expected_study_duration_days = (
        math.floor(study_elapsed_seconds / (24 * 60 * 60))
        if study_elapsed_seconds is not None and study_elapsed_seconds >= 0
        else None
    )
    if (strict_int(summary.get("minimumDaysSinceFirstSession")) or 0) < 7:
        failures.append("insufficientLongitudinalWindow")
    if strict_int(summary.get("studyDurationDays")) != expected_study_duration_days:
        failures.append("studyDurationMismatch")
    if any(row.get("causalityClaims") != [] for row in typed_rows):
        failures.append("causalityClaimsPresent")

    passing_count = sum(real_user_transfer_row_passes(row) for row in typed_rows)
    if (
        passing_count != len(rows)
        or strict_int(summary.get("passingOutcomeCount")) != passing_count
        or passing_count < REAL_USER_TRANSFER_REQUIRED_OUTCOMES
    ):
        failures.append("outcomeFloorFailures")
    warnings = summary.get("readinessWarnings")
    if not isinstance(warnings, list):
        failures.append("invalidReadinessWarnings")
    else:
        append_ids_failure(failures, "readinessWarnings", [
            item for item in warnings if isinstance(item, str) and item.strip()
        ])
    return list(dict.fromkeys(failures))


def real_device_check_contract_status(row):
    surface = trimmed_non_empty(row.get("surfaceKey")) if isinstance(row, dict) else None
    surface_label = surface or "<invalid>"
    required_checks = REAL_DEVICE_REQUIRED_CHECKS_BY_SURFACE.get(surface, [])
    required_set = set(required_checks)
    checks = row.get("checks") if isinstance(row, dict) else None
    failures = []
    if not isinstance(checks, list):
        return {
            "failures": [f"invalidChecks={surface_label}"],
            "passedRequiredCheckCount": 0,
        }

    typed_checks = [check for check in checks if isinstance(check, dict)]
    check_keys = [
        trimmed_non_empty(check.get("checkKey"))
        for check in typed_checks
    ]
    if len(typed_checks) != len(checks) or any(key is None for key in check_keys):
        failures.append(f"invalidChecks={surface_label}")

    key_counts = {}
    for key in check_keys:
        if key is not None:
            key_counts[key] = key_counts.get(key, 0) + 1
    duplicates = sorted(key for key, count in key_counts.items() if count > 1)
    missing = sorted(required_set.difference(key_counts))
    unexpected = sorted(set(key_counts).difference(required_set))
    failed = sorted(
        key for key in required_checks
        if key_counts.get(key) == 1
        and next(
            check for check in typed_checks
            if trimmed_non_empty(check.get("checkKey")) == key
        ).get("passed") is not True
    )
    if duplicates:
        failures.append(f"duplicateCheckKeys={surface_label}:{','.join(duplicates)}")
    if missing:
        failures.append(f"missingRequiredChecks={surface_label}:{','.join(missing)}")
    if unexpected:
        failures.append(f"unexpectedCheckKeys={surface_label}:{','.join(unexpected)}")
    if failed:
        failures.append(f"failedRequiredChecks={surface_label}:{','.join(failed)}")

    passed_count = sum(
        key_counts.get(key) == 1
        and next(
            check for check in typed_checks
            if trimmed_non_empty(check.get("checkKey")) == key
        ).get("passed") is True
        for key in required_checks
    )
    return {
        "failures": failures,
        "passedRequiredCheckCount": passed_count,
    }


def real_device_row_passes(row):
    if not isinstance(row, dict):
        return False
    surface = row.get("surfaceKey")
    expected_kind = REAL_DEVICE_EVIDENCE_KIND_BY_SURFACE.get(surface)
    check_status = real_device_check_contract_status(row)
    latency = strict_int(row.get("latencyMs"))
    latency_passes = surface != "aiPromptLatency" or (
        latency is not None and 0 <= latency <= REAL_DEVICE_MAX_AI_PROMPT_LATENCY_MS
    )
    trail_keys = [
        "evidenceReference", "evidenceKind", "evidenceCapturedAtISO8601",
        "testFlightBuildNumber", "deviceIdentifierHash",
    ]
    return bool(
        row.get("passed") is True
        and row.get("realDevice") is True
        and row.get("testFlightBuildInstalled") is True
        and strict_int(row.get("blockingIssueCount")) == 0
        and all(usable_evidence_reference(row.get(key)) for key in trail_keys)
        and trimmed_non_empty(row.get("evidenceKind")) == expected_kind
        and latency_passes
        and not check_status["failures"]
    )


def real_device_testflight_contract_failures(payload):
    failures = []
    rows = payload.get("rows") if isinstance(payload.get("rows"), list) else []
    summary = payload.get("summary") if isinstance(payload.get("summary"), dict) else {}
    if any(not isinstance(row, dict) for row in rows):
        failures.append("invalidDeviceRows")
    typed_rows = [row for row in rows if isinstance(row, dict)]
    build = trimmed_non_empty(payload.get("buildNumber"))
    if not all(trimmed_non_empty(payload.get(key)) for key in [
        "testRunID", "appVersion", "buildNumber", "deviceModel", "osVersion", "testerRole",
    ]):
        failures.append("missingRunMetadata")
    if strict_int(summary.get("rowCount")) != len(rows):
        failures.append("rowCountMismatch")
    surface_keys = [trimmed_non_empty(row.get("surfaceKey")) for row in typed_rows]
    if any(key is None for key in surface_keys):
        failures.append("invalidSurfaceKeys")
    if len(set(surface_keys)) != len(rows):
        failures.append("duplicateSurfaceKeys")
    required = set(REAL_DEVICE_REQUIRED_SURFACES)
    missing = sorted(required.difference(surface_keys))
    append_ids_failure(failures, "missingRequiredSurfaces", missing)
    unexpected = sorted(
        key for key in set(surface_keys).difference(required)
        if key is not None
    )
    append_ids_failure(failures, "unexpectedSurfaces", unexpected)

    required_rows = [row for row in typed_rows if row.get("surfaceKey") in required]
    check_statuses = [real_device_check_contract_status(row) for row in typed_rows]
    for status in check_statuses:
        failures.extend(status["failures"])
    passed_required_check_count = sum(
        real_device_check_contract_status(row)["passedRequiredCheckCount"]
        for row in required_rows
    )
    passing_rows = [row for row in required_rows if real_device_row_passes(row)]
    real_device_rows = [row for row in required_rows if row.get("realDevice") is True]
    testflight_rows = [row for row in required_rows if row.get("testFlightBuildInstalled") is True]
    trail_keys = [
        "evidenceReference", "evidenceKind", "evidenceCapturedAtISO8601",
        "testFlightBuildNumber", "deviceIdentifierHash",
    ]
    artifact_rows = [row for row in required_rows if all(
        usable_evidence_reference(row.get(key)) for key in trail_keys
    )]
    kind_rows = [row for row in required_rows if (
        trimmed_non_empty(row.get("evidenceKind")) ==
        REAL_DEVICE_EVIDENCE_KIND_BY_SURFACE.get(row.get("surfaceKey"))
    )]
    same_build_rows = [row for row in required_rows if (
        trimmed_non_empty(row.get("testFlightBuildNumber")) == build
    )]
    identity_rows = [row for row in required_rows if usable_evidence_reference(
        row.get("deviceIdentifierHash")
    )]
    latency_rows = [row for row in required_rows if row.get("surfaceKey") == "aiPromptLatency"]
    latency_pass_rows = [row for row in latency_rows if (
        strict_int(row.get("latencyMs")) is not None
        and 0 <= strict_int(row.get("latencyMs")) <= REAL_DEVICE_MAX_AI_PROMPT_LATENCY_MS
    )]

    if strict_int(summary.get("requiredSurfaceCount")) != len(REAL_DEVICE_REQUIRED_SURFACES):
        failures.append("requiredSurfaceCountMismatch")
    if strict_int(summary.get("requiredCheckCount")) != REAL_DEVICE_REQUIRED_CHECK_COUNT:
        failures.append("requiredCheckCountMismatch")
    if (
        strict_int(summary.get("passedRequiredCheckCount")) != passed_required_check_count
        or passed_required_check_count < REAL_DEVICE_REQUIRED_CHECK_COUNT
    ):
        failures.append("checkFloorFailures")
    if strict_int(summary.get("passedRequiredSurfaceCount")) != len(passing_rows) or len(passing_rows) < len(required):
        failures.append("surfaceFloorFailures")
    if strict_int(summary.get("realDeviceSurfaceCount")) != len(real_device_rows) or len(real_device_rows) < len(required):
        failures.append("notAllSurfacesOnRealDevice")
    if strict_int(summary.get("testFlightBuildSurfaceCount")) != len(testflight_rows) or len(testflight_rows) < len(required):
        failures.append("notAllSurfacesOnTestFlightBuild")
    missing_artifacts = sorted(required.difference(row.get("surfaceKey") for row in artifact_rows))
    if strict_int(summary.get("artifactBackedSurfaceCount")) != len(artifact_rows) or missing_artifacts:
        failures.append(f"missingDeviceEvidence={','.join(missing_artifacts)}")
    kind_mismatches = sorted(required.difference(row.get("surfaceKey") for row in kind_rows))
    if strict_int(summary.get("expectedEvidenceKindSurfaceCount")) != len(kind_rows) or kind_mismatches:
        failures.append(f"evidenceKindMismatch={','.join(kind_mismatches)}")
    build_mismatches = sorted(required.difference(row.get("surfaceKey") for row in same_build_rows))
    if strict_int(summary.get("sameBuildSurfaceCount")) != len(same_build_rows) or build_mismatches:
        failures.append(f"buildNumberMismatch={','.join(build_mismatches)}")
    identity_missing = sorted(required.difference(row.get("surfaceKey") for row in identity_rows))
    if strict_int(summary.get("deviceIdentitySurfaceCount")) != len(identity_rows) or identity_missing:
        failures.append(f"missingDeviceIdentity={','.join(identity_missing)}")
    if (
        len(latency_rows) != 1
        or strict_int(summary.get("latencyWithinBudgetSurfaceCount")) != len(latency_pass_rows)
        or len(latency_pass_rows) != 1
    ):
        failures.append("aiPromptLatencyOverBudget")
    issue_counts = [strict_int(row.get("blockingIssueCount")) for row in typed_rows]
    blocking_count = sum(value for value in issue_counts if value is not None)
    if any(value is None for value in issue_counts) or strict_int(summary.get("blockingIssueCount")) != blocking_count or blocking_count > 0:
        failures.append("blockingIssuesPresent")
    if summary.get("crashFree") is not True:
        failures.append("crashesObserved")
    if len(passing_rows) != len(required_rows):
        failures.append("rowSurfaceFloorFailures")
    warnings = summary.get("readinessWarnings")
    if not isinstance(warnings, list):
        failures.append("invalidReadinessWarnings")
    else:
        append_ids_failure(failures, "readinessWarnings", [
            item for item in warnings if isinstance(item, str) and item.strip()
        ])
    return list(dict.fromkeys(failures))


def operational_launch_row_has_verification_identity(item):
    if not isinstance(item, dict):
        return False
    performed_by_id = trimmed_non_empty(item.get("performedByID"))
    verified_by_id = trimmed_non_empty(item.get("verifiedByID"))
    return bool(
        performed_by_id
        and verified_by_id
        and performed_by_id != verified_by_id
        and usable_iso8601_timestamp(item.get("verifiedAtISO8601"))
        and usable_evidence_reference(item.get("verifiedByRole"))
    )


def operational_launch_item_passes(item):
    if not isinstance(item, dict):
        return False
    key = item.get("key")
    return bool(
        item.get("completed") is True
        and all(usable_evidence_reference(item.get(field)) for field in [
            "evidenceReference", "verificationReference",
            "commandOrReviewOutputReference",
        ])
        and usable_iso8601_timestamp(item.get("completedAtISO8601"))
        and trimmed_non_empty(item.get("evidenceKind")) ==
            OPERATIONAL_LAUNCH_EVIDENCE_KIND_BY_ITEM.get(key)
        and trimmed_non_empty(item.get("environment")) ==
            OPERATIONAL_LAUNCH_ENVIRONMENT_BY_ITEM.get(key)
        and operational_launch_row_has_verification_identity(item)
    )


def operational_launch_prerequisite_passes(item, build):
    if not isinstance(item, dict):
        return False
    key = item.get("key")
    return bool(
        item.get("completed") is True
        and all(usable_evidence_reference(item.get(field)) for field in [
            "evidenceReference", "verificationReference",
            "commandOrReviewOutputReference",
        ])
        and usable_iso8601_timestamp(item.get("completedAtISO8601"))
        and trimmed_non_empty(item.get("evidenceKind")) ==
            OPERATIONAL_LAUNCH_EVIDENCE_KIND_BY_PREREQUISITE.get(key)
        and trimmed_non_empty(item.get("environment")) ==
            OPERATIONAL_LAUNCH_ENVIRONMENT_BY_PREREQUISITE.get(key)
        and trimmed_non_empty(item.get("releaseCandidateBuild")) == build
        and operational_launch_row_has_verification_identity(item)
    )


def safe_repository_relative_path(value):
    normalized = trimmed_non_empty(value)
    if normalized is None or normalized.startswith(("/", "\\")):
        return False
    return "\\" not in normalized and ".." not in normalized.split("/")


def operational_launch_history_failures(history, prerequisites, source_expectations=None):
    failures = []
    if not isinstance(history, dict):
        return ["invalidHistorySecretAdjudication"]
    findings = history.get("findings") if isinstance(history.get("findings"), list) else []
    if any(not isinstance(finding, dict) for finding in findings):
        failures.append("invalidHistorySecretFindingRows")
    typed_findings = [finding for finding in findings if isinstance(finding, dict)]
    if (
        history.get("scanner") != OPERATIONAL_LAUNCH_HISTORY_SCANNER
        or history.get("scannerVersion") != OPERATIONAL_LAUNCH_HISTORY_SCANNER_VERSION
        or history.get("scanScope") != OPERATIONAL_LAUNCH_HISTORY_SCOPE
        or strict_int(history.get("redactionPercent")) != 100
    ):
        failures.append("invalidHistorySecretScanMetadata")
    scanned_commit = trimmed_non_empty(history.get("scannedRepositoryCommit"))
    commit_pattern = r"[0-9a-f]{40}"
    sha256_pattern = r"sha256:[0-9a-f]{64}"
    expected_source_commit = trimmed_non_empty(
        (source_expectations or {}).get("source-git-commit.txt")
    )
    if (
        scanned_commit is None
        or re.fullmatch(commit_pattern, scanned_commit) is None
        or strict_int(history.get("reachableCommitCount")) is None
        or history.get("reachableCommitCount", 0) <= 0
        or re.fullmatch(
            sha256_pattern,
            trimmed_non_empty(history.get("reachableCommitSetSha256")) or "",
        ) is None
        or not usable_evidence_reference(history.get("redactedScanReportReference"))
    ):
        failures.append("invalidHistorySecretScanBinding")
    if (
        expected_source_commit
        and re.fullmatch(commit_pattern, expected_source_commit)
        and scanned_commit != expected_source_commit
    ):
        failures.append("historySecretSourceCommitMismatch")
    full_history_rows = [
        row for row in prerequisites
        if row.get("key") == "fullHistorySecretFindingsAdjudicated"
    ]
    if (
        len(full_history_rows) != 1
        or history.get("redactedScanReportReference") !=
            full_history_rows[0].get("evidenceReference")
    ):
        failures.append("historySecretReportReferenceMismatch")
    finding_count = len(findings)
    if (
        finding_count < 3
        or strict_int(history.get("detectedFindingCount")) != finding_count
        or strict_int(history.get("adjudicatedFindingCount")) != finding_count
        or strict_int(history.get("unresolvedFindingCount")) != 0
        or strict_int(history.get("suppressedFindingCount")) != 0
    ):
        failures.append("incompleteHistorySecretAdjudication")
    finding_ids = [trimmed_non_empty(finding.get("findingID")) for finding in typed_findings]
    if None in finding_ids or len(set(finding_ids)) != len(findings):
        failures.append("duplicateHistorySecretFindingIDs")
    if not any(
        finding.get("commit") == OPERATIONAL_LAUNCH_KNOWN_DEEPGRAM_COMMIT
        for finding in typed_findings
    ):
        failures.append("missingKnownDeepgramHistoryFinding")
    if any(
        re.fullmatch(sha256_pattern, trimmed_non_empty(finding.get("findingID")) or "") is None
        or trimmed_non_empty(finding.get("detectorRuleID")) is None
        or re.fullmatch(commit_pattern, trimmed_non_empty(finding.get("commit")) or "") is None
        or not safe_repository_relative_path(finding.get("path"))
        or finding.get("disposition") not in OPERATIONAL_LAUNCH_HISTORY_DISPOSITIONS
        or not usable_evidence_reference(finding.get("statusEvidenceReference"))
        for finding in typed_findings
    ):
        failures.append("invalidHistorySecretFindingRows")
    return failures


def operational_launch_contract_failures(payload, source_expectations=None):
    failures = []
    items = payload.get("items") if isinstance(payload.get("items"), list) else []
    summary = payload.get("summary") if isinstance(payload.get("summary"), dict) else {}
    if any(not isinstance(item, dict) for item in items):
        failures.append("invalidChecklistItems")
    typed_items = [item for item in items if isinstance(item, dict)]
    build = trimmed_non_empty(payload.get("releaseCandidateBuild"))
    if payload.get("checklistVersion") != OPERATIONAL_LAUNCH_CHECKLIST_VERSION:
        failures.append(f"checklistVersion={payload.get('checklistVersion')}")
    if payload.get("templateStatus") != OPERATIONAL_LAUNCH_TEMPLATE_STATUS:
        failures.append(f"templateStatus={payload.get('templateStatus')}")
    if (
        build is None
        or trimmed_non_empty(payload.get("completedByRole")) is None
        or trimmed_non_empty(payload.get("completedByID")) is None
    ):
        failures.append("missingReleaseMetadata")
    if strict_int(summary.get("itemCount")) != len(items):
        failures.append("itemCountMismatch")
    keys = [item.get("key") if isinstance(item.get("key"), str) else "" for item in typed_items]
    if len(set(keys)) != len(items):
        failures.append("duplicateChecklistItems")
    required = set(OPERATIONAL_LAUNCH_REQUIRED_ITEMS)
    append_ids_failure(failures, "missingRequiredItems", sorted(required.difference(keys)))
    append_ids_failure(failures, "unexpectedChecklistItems", sorted(set(keys).difference(required)))
    required_items = [item for item in typed_items if item.get("key") in required]
    completed_items = [item for item in required_items if item.get("completed") is True]
    failed_items = [item for item in required_items if item.get("completed") is not True]
    artifact_items = [item for item in required_items if all(
        usable_evidence_reference(item.get(field)) for field in [
            "evidenceReference", "verificationReference",
            "commandOrReviewOutputReference",
        ]
    ) and usable_iso8601_timestamp(item.get("completedAtISO8601"))]
    kind_items = [item for item in required_items if (
        trimmed_non_empty(item.get("evidenceKind")) ==
        OPERATIONAL_LAUNCH_EVIDENCE_KIND_BY_ITEM.get(item.get("key"))
    )]
    environment_items = [item for item in required_items if (
        trimmed_non_empty(item.get("environment")) ==
        OPERATIONAL_LAUNCH_ENVIRONMENT_BY_ITEM.get(item.get("key"))
    )]
    same_build_items = [item for item in required_items if (
        trimmed_non_empty(item.get("releaseCandidateBuild")) == build
    )]
    verified_items = [
        item for item in required_items
        if operational_launch_row_has_verification_identity(item)
    ]
    if strict_int(summary.get("completedRequiredItemCount")) != len(completed_items) or len(completed_items) < len(required):
        failures.append("incompleteRequiredItems")
    if strict_int(summary.get("failedRequiredItemCount")) != len(failed_items) or failed_items:
        failures.append("failedRequiredItems")
    missing_artifacts = sorted(required.difference(item.get("key") for item in artifact_items))
    if strict_int(summary.get("artifactBackedItemCount")) != len(artifact_items) or missing_artifacts:
        failures.append(f"missingOperationalEvidence={','.join(missing_artifacts)}")
    kind_mismatches = sorted(required.difference(item.get("key") for item in kind_items))
    if strict_int(summary.get("expectedEvidenceKindItemCount")) != len(kind_items) or kind_mismatches:
        failures.append(f"evidenceKindMismatch={','.join(kind_mismatches)}")
    environment_mismatches = sorted(required.difference(item.get("key") for item in environment_items))
    if strict_int(summary.get("expectedEnvironmentItemCount")) != len(environment_items) or environment_mismatches:
        failures.append(f"environmentMismatch={','.join(environment_mismatches)}")
    build_mismatches = sorted(required.difference(item.get("key") for item in same_build_items))
    if strict_int(summary.get("sameBuildItemCount")) != len(same_build_items) or build_mismatches:
        failures.append(f"releaseCandidateBuildMismatch={','.join(build_mismatches)}")
    verification_missing = sorted(required.difference(item.get("key") for item in verified_items))
    if strict_int(summary.get("verifiedRequiredItemCount")) != len(verified_items) or verification_missing:
        failures.append(f"missingOperationalVerification={','.join(verification_missing)}")
    if any(not operational_launch_item_passes(item) for item in required_items):
        failures.append("itemFloorFailures")
    prerequisites_value = payload.get("releasePrerequisites")
    prerequisites = prerequisites_value if isinstance(prerequisites_value, list) else []
    if any(not isinstance(item, dict) for item in prerequisites):
        failures.append("invalidReleasePrerequisites")
    typed_prerequisites = [item for item in prerequisites if isinstance(item, dict)]
    prerequisite_keys = [
        item.get("key") if isinstance(item.get("key"), str) else ""
        for item in typed_prerequisites
    ]
    required_prerequisites = set(OPERATIONAL_LAUNCH_REQUIRED_PREREQUISITES)
    if len(set(prerequisite_keys)) != len(prerequisites):
        failures.append("duplicateReleasePrerequisites")
    append_ids_failure(
        failures,
        "missingReleasePrerequisites",
        sorted(required_prerequisites.difference(prerequisite_keys)),
    )
    append_ids_failure(
        failures,
        "unexpectedReleasePrerequisites",
        sorted(set(prerequisite_keys).difference(required_prerequisites)),
    )
    required_prerequisite_rows = [
        item for item in typed_prerequisites
        if item.get("key") in required_prerequisites
    ]
    open_prerequisites = sorted(
        item.get("key") for item in required_prerequisite_rows
        if item.get("completed") is not True
    )
    append_ids_failure(failures, "openReleasePrerequisites", open_prerequisites)
    failing_prerequisites = sorted(
        item.get("key") for item in required_prerequisite_rows
        if not operational_launch_prerequisite_passes(item, build)
    )
    append_ids_failure(failures, "releasePrerequisiteFloorFailures", failing_prerequisites)
    failures.extend(operational_launch_history_failures(
        payload.get("historySecretAdjudication"),
        typed_prerequisites,
        source_expectations,
    ))
    warnings = summary.get("readinessWarnings")
    if not isinstance(warnings, list):
        failures.append("invalidReadinessWarnings")
    else:
        append_ids_failure(failures, "readinessWarnings", [
            item for item in warnings if isinstance(item, str) and item.strip()
        ])
    return list(dict.fromkeys(failures))


def evidence_artifact_contract_status(path, requirement, source_expectations=None):
    if not path.is_file():
        return {
            "parseStatus": "missing",
            "schemaVersion": None,
            "expectedSchemaVersion": requirement.get("expectedSchemaVersion"),
            "schemaVersionMatches": False,
            "missingRequiredKeys": requirement.get("requiredTopLevelKeys", []),
            "passesLightweightContract": False,
            "contractFailures": ["missing"],
            "nonBlockingSignals": [],
        }

    failures = []
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return {
            "parseStatus": f"invalidJSON:{exc.msg}",
            "schemaVersion": None,
            "expectedSchemaVersion": requirement.get("expectedSchemaVersion"),
            "schemaVersionMatches": False,
            "missingRequiredKeys": requirement.get("requiredTopLevelKeys", []),
            "passesLightweightContract": False,
            "contractFailures": [f"invalidJSON:{exc.msg}"],
            "nonBlockingSignals": [],
        }

    if not isinstance(payload, dict):
        return {
            "parseStatus": "invalidTopLevelType",
            "schemaVersion": None,
            "expectedSchemaVersion": requirement.get("expectedSchemaVersion"),
            "schemaVersionMatches": False,
            "missingRequiredKeys": requirement.get("requiredTopLevelKeys", []),
            "passesLightweightContract": False,
            "contractFailures": ["invalidTopLevelType"],
            "nonBlockingSignals": [],
        }

    expected_schema = requirement.get("expectedSchemaVersion")
    schema_version = payload.get("schemaVersion")
    if not isinstance(schema_version, str) or not schema_version.strip():
        failures.append("schemaVersionMissing")
    elif expected_schema and schema_version != expected_schema:
        failures.append(f"schemaVersionMismatch:{schema_version}")

    required_keys = requirement.get("requiredTopLevelKeys", [])
    missing_keys = [key for key in required_keys if key not in payload]
    if missing_keys:
        failures.append("missingRequiredKeys:" + ",".join(missing_keys))

    if expected_schema == "coach-live-eval-v1":
        failures.extend(
            live_provider_sweep_contract_failures(payload, source_expectations)
        )
    if expected_schema == PROFESSIONAL_CALIBRATION_RESULTS_SCHEMA:
        failures.extend(
            professional_calibration_contract_failures(
                payload,
                (source_expectations or {}).get("professionalCalibrationPacket"),
            )
        )
    non_blocking_signals = []
    if expected_schema == REAL_USER_TRANSFER_SCHEMA:
        failures.extend(real_user_transfer_contract_failures(payload))
    if expected_schema == REAL_DEVICE_TESTFLIGHT_SCHEMA:
        failures.extend(real_device_testflight_contract_failures(payload))
    if expected_schema == OPERATIONAL_LAUNCH_SCHEMA:
        failures.extend(operational_launch_contract_failures(payload, source_expectations))

    if expected_schema == REAL_USER_TRANSFER_SCHEMA:
        non_blocking_signals.append(real_user_transfer_scale_signal(
            payload,
            release_contract_passes=not failures,
        ))

    return {
        "parseStatus": "ok",
        "schemaVersion": schema_version if isinstance(schema_version, str) else None,
        "expectedSchemaVersion": expected_schema,
        "schemaVersionMatches": bool(expected_schema and schema_version == expected_schema),
        "missingRequiredKeys": missing_keys,
        "passesLightweightContract": not failures,
        "contractFailures": failures,
        "nonBlockingSignals": non_blocking_signals,
    }


def evidence_artifact_audit(dump_dir, readiness=None):
    root = Path(dump_dir)
    blockers = set(readiness.get("blockers") or []) if readiness else set(EVIDENCE_REQUIREMENTS)

    source_sidecars = []
    source_expectations = {}
    source_expectations["professionalCalibrationPacket"] = calibration_packet_context(root)
    for file_name in SOURCE_SIDECARS:
        path = root / file_name
        present = path.is_file()
        value_preview = None
        usable = False
        if present:
            raw_value = path.read_text(encoding="utf-8", errors="replace").strip()
            value_preview = raw_value[:80]
            usable = trimmed_non_empty(raw_value) is not None
            if usable:
                source_expectations[file_name] = raw_value
        source_sidecars.append({
            "fileName": file_name,
            "path": str(path),
            "present": present,
            "usable": usable,
            "valuePreview": value_preview,
        })

    required = []
    for blocker, requirement in EVIDENCE_REQUIREMENTS.items():
        artifact = requirement["artifact"]
        path = root / artifact
        present = path.is_file()
        contract = evidence_artifact_contract_status(
            path,
            requirement,
            source_expectations,
        )
        required.append({
            "blocker": blocker,
            "rowKey": requirement["rowKey"],
            "artifact": artifact,
            "path": str(path),
            "present": present,
            "activeBlocker": blocker in blockers,
            "presentButStillBlocked": present and blocker in blockers,
            **contract,
        })

    missing = [item for item in required if not item["present"]]
    present_but_blocked = [item for item in required if item["presentButStillBlocked"]]
    non_blocking_signals = [
        signal
        for item in required
        for signal in item.get("nonBlockingSignals", [])
    ]
    return {
        "dumpDir": str(root),
        "dumpDirExists": root.is_dir(),
        "validationBoundary": (
            "Python performs structured JSON/schema validation, mirrors the "
            "Swift row-level evidence contracts, validates source freshness, "
            "and requires the current Swift readiness manifest to agree before "
            "launch readiness can pass."
        ),
        "requiredArtifactCount": len(required),
        "presentArtifactCount": len(required) - len(missing),
        "validArtifactContractCount": sum(
            1 for item in required if item.get("passesLightweightContract")
        ),
        "missingArtifactCount": len(missing),
        "sourceSidecarCount": len(source_sidecars),
        "presentSourceSidecarCount": sum(1 for item in source_sidecars if item["present"]),
        "requiredArtifacts": required,
        "missingArtifacts": missing,
        "invalidArtifacts": [
            item for item in required
            if item["present"] and not item.get("passesLightweightContract")
        ],
        "presentButStillBlockedArtifacts": present_but_blocked,
        "sourceSidecars": source_sidecars,
        "nonBlockingSignals": non_blocking_signals,
    }


def artifact_gate_failures(artifact_audit):
    failures = []
    if not artifact_audit.get("dumpDirExists"):
        failures.append({
            "label": "evidenceDumpDirectory",
            "observed": False,
            "gate": "The evidence dump directory must exist for a launch-ready claim.",
            "nextStep": "Create or pass the release-candidate evidence directory with --dump-dir.",
        })
    for item in artifact_audit.get("missingArtifacts") or []:
        failures.append({
            "label": item["artifact"],
            "observed": "missing",
            "gate": "Required VISION evidence sidecar must be staged in the dump directory.",
            "nextStep": f"Place `{item['artifact']}` in `{artifact_audit.get('dumpDir')}` and rerun the Swift manifest.",
        })
    for item in artifact_audit.get("invalidArtifacts") or []:
        failures.append({
            "label": item["artifact"],
            "observed": ",".join(item.get("contractFailures") or ["invalid"]),
            "gate": (
                "Required VISION evidence sidecar must be valid JSON with the "
                "expected schemaVersion and top-level evidence sections."
            ),
            "nextStep": (
                f"Replace `{item['artifact']}` with a real "
                f"`{item.get('expectedSchemaVersion')}` artifact; placeholders "
                "do not count as launch evidence."
            ),
        })
    for item in artifact_audit.get("sourceSidecars") or []:
        if not item.get("present"):
            failures.append({
                "label": item["fileName"],
                "observed": "missing",
                "gate": "Source freshness sidecar must be staged with the evidence artifacts.",
                "nextStep": "Run `./tools/coach-arena/run.sh app-path-source` for the same dump directory.",
            })
        elif not item.get("usable"):
            failures.append({
                "label": item["fileName"],
                "observed": "empty",
                "gate": "Source freshness sidecar must contain a non-empty source identity.",
                "nextStep": "Run `./tools/coach-arena/run.sh app-path-source` for the same dump directory.",
            })
    return failures


def readiness_manifest_gate_failures(manifest_audit):
    if manifest_audit.get("passes"):
        return []
    return [{
        "label": READINESS_MANIFEST_FILE,
        "observed": ",".join(manifest_audit.get("failures") or ["invalid"]),
        "gate": (
            "The Swift readiness manifest must be regenerated from the current "
            "artifact directory and agree with the independently validated sidecars."
        ),
        "nextStep": (
            "Run `./tools/coach-arena/run.sh evidence-refresh --no-fail` for "
            "the same dump directory."
        ),
    }]


def file_text(root, relative_path):
    path = Path(root) / relative_path
    if not path.is_file():
        return None
    return path.read_text(encoding="utf-8", errors="replace")


def gitignore_mentions(root, relative_path):
    text = file_text(root, ".gitignore") or ""
    normalized = relative_path.strip().replace("\\", "/").lstrip("/")
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        candidate = stripped.lstrip("/").rstrip("/")
        if candidate == normalized:
            return True
    return False


def git_path_tracked(root, relative_path):
    root = Path(root)
    if not (root / ".git").exists():
        return None
    try:
        result = subprocess.run(
            ["git", "ls-files", "--error-unmatch", relative_path],
            cwd=root,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    except (OSError, ValueError):
        return None
    return result.returncode == 0


def noum_target_membership_exceptions(repo_root=REPO_ROOT):
    project = file_text(repo_root, "Noum.xcodeproj/project.pbxproj")
    if project is None:
        return None
    exception_set = re.search(
        r'/\* Exceptions for "Noum" folder in "Noum" target \*/ = \{(.*?)\n\s*\};',
        project,
        flags=re.DOTALL,
    )
    if not exception_set:
        return None
    membership = re.search(
        r"membershipExceptions\s*=\s*\((.*?)\);",
        exception_set.group(1),
        flags=re.DOTALL,
    )
    if not membership:
        return None
    return {
        entry.partition("/*")[0].strip().strip('"')
        for entry in membership.group(1).split(",")
        if entry.partition("/*")[0].strip()
    }


def hosting_origin_from_repo(repo_root=REPO_ROOT):
    web_urls = file_text(repo_root, "Noum/NoumWebURLs.swift") or ""
    try:
        return HOSTING_ORIGINS_BY_TARGET[
            active_hosting_target_from_source(web_urls)
        ]
    except ValueError:
        pass
    legacy = re.search(
        r"static\s+let\s+privacy\s*=\s*URL\(string:\s*\"(https://[^\"/]+)/privacy\"\)",
        web_urls,
    )
    return legacy.group(1) if legacy else None


def privacy_url_from_repo(repo_root=REPO_ROOT):
    origin = hosting_origin_from_repo(repo_root)
    return f"{origin}/privacy" if origin else None


def default_fetch_url(url, timeout=10):
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "NoumReadinessGate/1.0",
            "Accept-Encoding": "gzip, identity",
        },
    )
    with NO_REDIRECT_OPENER.open(request, timeout=timeout) as response:
        content_encoding = (response.headers.get("Content-Encoding") or "identity").lower()
        if content_encoding in ("", "identity"):
            body = response.read(MAX_HOSTED_PAGE_BODY_BYTES + 1)
        elif content_encoding == "gzip":
            with gzip.GzipFile(fileobj=response, mode="rb") as decompressed:
                body = decompressed.read(MAX_HOSTED_PAGE_BODY_BYTES + 1)
        else:
            raise ValueError("unsupportedHostedPageContentEncoding")
        return {
            "status": getattr(response, "status", response.getcode()),
            "finalURL": response.geturl(),
            "contentType": response.headers.get("Content-Type") or "",
            "bodyBytes": body,
            "bodyComplete": len(body) <= MAX_HOSTED_PAGE_BODY_BYTES,
            "bodySize": len(body),
            "redirectCount": 0,
        }


def operational_live_probe(repo_root=REPO_ROOT, fetch_url=default_fetch_url):
    hosting_origin = hosting_origin_from_repo(repo_root)
    checks = []

    def add(key, passed, observed, gate, next_step):
        checks.append({
            "key": key,
            "label": key,
            "passed": bool(passed),
            "observed": observed,
            "gate": gate,
            "nextStep": next_step,
        })

    def add_response_checks(prefix, source_path, source_error, verification, status):
        error_set = set(verification.errors)
        origin_errors = {
            "requestedURLNotApprovedHTTPS",
            "redirectOriginEscape",
            "httpRedirectNotAllowed",
        }
        body_errors = {"expectedBodyOversize", "responseBodyOversize", "bodyMismatch"}
        outcomes = (
            (
                f"{prefix}HTTP",
                "httpStatusNotSuccessful" not in error_set,
                status,
                "Every hosted launch page must return a successful HTTP status.",
                "Deploy Firebase Hosting or repair the named launch page.",
            ),
            (
                f"{prefix}Origin",
                not error_set.intersection(origin_errors),
                (
                    "sameApprovedHTTPSOrigin"
                    if not error_set.intersection(origin_errors)
                    else "originNotVerified"
                ),
                "Each hosted response must remain on its requested approved HTTPS origin.",
                "Remove cross-origin redirects and restore the approved Hosting origin.",
            ),
            (
                f"{prefix}ContentType",
                "contentTypeNotHTML" not in error_set,
                "textHTML" if "contentTypeNotHTML" not in error_set else "notTextHTML",
                "Every hosted launch page must be served as text/html.",
                "Repair the Firebase Hosting content type for the named page.",
            ),
            (
                f"{prefix}ExactBody",
                source_error is None and not error_set.intersection(body_errors),
                (
                    verification.safe_body_observation
                    if source_error is None
                    else f"expectedSourceUnavailable:{source_error}"
                ),
                f"The hosted response must exactly match {source_path}.",
                "Deploy the reviewed public sources and rerun the live probe.",
            ),
        )
        for outcome in outcomes:
            add(*outcome)

    def unavailable_response_checks(prefix, source_path, observed):
        add(
            f"{prefix}HTTP", False, observed,
            "Every hosted launch page must return a successful HTTP status.",
            "Deploy Firebase Hosting or repair the named launch page.",
        )
        add(
            f"{prefix}Origin", False, "notVerified",
            "Each hosted response must remain on its requested approved HTTPS origin.",
            "Remove cross-origin redirects and restore the approved Hosting origin.",
        )
        add(
            f"{prefix}ContentType", False, "notVerified",
            "Every hosted launch page must be served as text/html.",
            "Repair the Firebase Hosting content type for the named page.",
        )
        add(
            f"{prefix}ExactBody", False, "notVerified",
            f"The hosted response must exactly match {source_path}.",
            "Deploy the reviewed public sources and rerun the live probe.",
        )

    configured = bool(
        hosting_origin
        and approved_https_origin_matches(hosting_origin, hosting_origin)
    )
    add(
        "publicWebOriginConfigured",
        configured,
        hosting_origin or "missing",
        "NoumWebURLs.hostingOrigin must be an approved direct HTTPS Hosting origin.",
        "Restore Firebase Hosting until the custom-domain exact-body gate passes.",
    )

    if not configured:
        for prefix, _, source_path in PUBLIC_LIVE_PAGE_SPECS:
            unavailable_response_checks(prefix, source_path, "invalidConfiguredOrigin")
    else:
        for prefix, route, source_path in PUBLIC_LIVE_PAGE_SPECS:
            source_error = None
            try:
                expected_body = (Path(repo_root) / source_path).read_bytes()
            except OSError as exc:
                expected_body = b""
                source_error = type(exc).__name__
            requested_url = f"{hosting_origin}{route}"
            try:
                response = fetch_url(requested_url)
                status = response.get("status")
                content_type = response.get("contentType") or ""
                body = response.get("bodyBytes")
                if not isinstance(body, bytes):
                    raise ValueError("hostedPageResponseBodyBytesMissing")
                verification = verify_hosted_page_response(
                    expected_body=expected_body,
                    observed_body=body,
                    requested_url=requested_url,
                    final_url=response.get("finalURL") or "",
                    status=status,
                    content_type=content_type,
                    redirect_count=response.get("redirectCount", 0),
                    observed_complete=response.get("bodyComplete") is True,
                    observed_size=response.get("bodySize") or len(body),
                )
                add_response_checks(prefix, source_path, source_error, verification, status)
            except urllib.error.HTTPError as exc:
                content_type = exc.headers.get("Content-Type") if exc.headers else ""
                verification = verify_hosted_page_response(
                    expected_body=expected_body,
                    observed_body=b"",
                    requested_url=requested_url,
                    final_url=exc.geturl() or requested_url,
                    status=exc.code,
                    content_type=content_type or "",
                    redirect_count=0,
                )
                add_response_checks(prefix, source_path, source_error, verification, exc.code)
                try:
                    exc.close()
                except Exception:
                    pass
            except Exception as exc:
                unavailable_response_checks(prefix, source_path, type(exc).__name__)

    failures = [check for check in checks if not check["passed"]]
    return {
        "validationBoundary": (
            "Live ops probe checks all four public launch pages for bounded, "
            "source-exact bytes on the app's approved direct Hosting origin; it "
            "does not prove Firestore rules deployment, App Store privacy review, "
            "TestFlight upload, or release-blocking bug triage."
        ),
        "checkCount": len(checks),
        "passCount": len(checks) - len(failures),
        "failureCount": len(failures),
        "checks": checks,
        "failures": failures,
    }


def operational_live_gate_failures(probe):
    failures = []
    if not probe:
        return failures
    for item in probe.get("failures") or []:
        failures.append({
            "label": item["label"],
            "observed": item.get("observed"),
            "gate": item["gate"],
            "nextStep": item["nextStep"],
        })
    return failures


def operational_static_preflight(repo_root=REPO_ROOT):
    root = Path(repo_root)
    checks = []

    def add(key, label, passed, observed, gate, next_step):
        checks.append({
            "key": key,
            "label": label,
            "passed": bool(passed),
            "observed": observed,
            "gate": gate,
            "nextStep": next_step,
        })

    membership_exceptions = noum_target_membership_exceptions(root)
    local_secret_plists = {
        "AIConfig.plist",
        "BackendConfig.plist",
        "Transcribe.plist",
        "TranscriptionProviders.plist",
    }
    protected_client_config = (
        membership_exceptions is not None
        and local_secret_plists.issubset(membership_exceptions)
        and "GoogleService-Info.plist" not in membership_exceptions
    )
    add(
        "mainTargetClientSecretBoundary",
        "mainTargetClientSecretBoundary",
        protected_client_config,
        (
            "localSecretPlistsExcluded;firebaseClientConfigRetained"
            if protected_client_config
            else "targetMembershipUnsafeOrUnparseable"
        ),
        (
            "The main app target must exclude local provider and backend secret "
            "plists while retaining Firebase's public client configuration."
        ),
        (
            "Restore AIConfig.plist, BackendConfig.plist, Transcribe.plist, and "
            "TranscriptionProviders.plist in the Noum target membership exceptions "
            "without excluding GoogleService-Info.plist."
        ),
    )

    ai_config_ignored = gitignore_mentions(root, "Noum/AIConfig.plist")
    ai_config_tracked = git_path_tracked(root, "Noum/AIConfig.plist")
    ai_config_example_present = (root / "Noum/AIConfig.plist.example").is_file()
    repo_secret_boundary = (
        ai_config_ignored
        and ai_config_tracked is not True
        and ai_config_example_present
    )
    tracked_state = (
        "tracked" if ai_config_tracked is True
        else "untracked" if ai_config_tracked is False
        else "trackingUnknown"
    )
    add(
        "aiConfigRepositorySecretBoundary",
        "aiConfigRepositorySecretBoundary",
        repo_secret_boundary,
        (
            f"ignored={ai_config_ignored};{tracked_state};"
            f"examplePresent={ai_config_example_present}"
        ),
        (
            "AIConfig.plist must remain a local-only config with a checked-in "
            "placeholder example, never a tracked source of AI provider keys."
        ),
        (
            "Keep Noum/AIConfig.plist in .gitignore, keep "
            "Noum/AIConfig.plist.example checked in, and remove any tracked "
            "AIConfig.plist from the repository index."
        ),
    )

    processor_disclosure_generator = (
        root / "scripts/release-generate-processor-disclosures.py"
    )
    processor_disclosure_status = "generatorMissing"
    processor_disclosures_fresh = False
    if processor_disclosure_generator.is_file():
        try:
            result = subprocess.run(
                [sys.executable, str(processor_disclosure_generator), "--check"],
                cwd=root,
                capture_output=True,
                text=True,
                timeout=15,
                check=False,
            )
            processor_disclosures_fresh = result.returncode == 0
            processor_disclosure_status = (
                "generatedOutputsFresh"
                if processor_disclosures_fresh
                else f"generationCheckFailed:{result.returncode}"
            )
        except subprocess.TimeoutExpired:
            processor_disclosure_status = "generationCheckTimedOut"
        except OSError as exc:
            processor_disclosure_status = f"generationCheckError:{type(exc).__name__}"
    add(
        "processorDisclosureGenerationFreshness",
        "processorDisclosureGenerationFreshness",
        processor_disclosures_fresh,
        processor_disclosure_status,
        (
            "The versioned processor manifest must match the generated in-app, "
            "hosted, and Swift consent disclosures."
        ),
        (
            "Update privacy/processors.json, regenerate with "
            "scripts/release-generate-processor-disclosures.py, and review the "
            "material consent-version change."
        ),
    )

    privacy_manifest_path = root / "Noum/PrivacyInfo.xcprivacy"
    privacy_manifest = None
    privacy_manifest_error = None
    if privacy_manifest_path.is_file():
        try:
            with privacy_manifest_path.open("rb") as manifest_file:
                privacy_manifest = plistlib.load(manifest_file)
        except (OSError, plistlib.InvalidFileException) as exc:
            privacy_manifest_error = type(exc).__name__
    if privacy_manifest is not None and not isinstance(privacy_manifest, dict):
        privacy_manifest_error = "invalidTopLevelType"
        privacy_manifest = None
    collected_data = {
        item.get("NSPrivacyCollectedDataType"): item
        for item in (privacy_manifest or {}).get("NSPrivacyCollectedDataTypes", [])
        if isinstance(item, dict) and item.get("NSPrivacyCollectedDataType")
    }
    required_user_content_types = {
        "NSPrivacyCollectedDataTypeOtherUserContent",
        "NSPrivacyCollectedDataTypePhotosorVideos",
    }
    invalid_user_content_types = []
    for data_type in sorted(required_user_content_types):
        item = collected_data.get(data_type) or {}
        purposes = item.get("NSPrivacyCollectedDataTypePurposes") or []
        if (
            item.get("NSPrivacyCollectedDataTypeLinked") is not True
            or item.get("NSPrivacyCollectedDataTypeTracking") is not False
            or "NSPrivacyCollectedDataTypePurposeAppFunctionality" not in purposes
        ):
            invalid_user_content_types.append(data_type)
    privacy_user_content_disclosed = (
        privacy_manifest is not None and not invalid_user_content_types
    )
    add(
        "privacyManifestUserContentDisclosure",
        "privacyManifestUserContentDisclosure",
        privacy_user_content_disclosed,
        (
            "linkedNonTrackingAppFunctionality"
            if privacy_user_content_disclosed
            else privacy_manifest_error
            or "missingOrInvalid:" + ",".join(invalid_user_content_types)
        ),
        (
            "The app privacy manifest must disclose user-authored coaching content "
            "and optional video frames as linked, non-tracking app-functionality data."
        ),
        (
            "Declare Other User Content and Photos or Videos in "
            "Noum/PrivacyInfo.xcprivacy with the shipping linkage and purpose."
        ),
    )

    firebase_json_path = root / "firebase.json"
    firebase_config = None
    firebase_error = None
    if firebase_json_path.is_file():
        try:
            firebase_config = json.loads(firebase_json_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            firebase_error = f"invalidJSON:{exc.msg}"
    add(
        "firebaseJson",
        "firebase.json",
        firebase_config is not None,
        "present" if firebase_config is not None else (firebase_error or "missing"),
        "Firebase config must be present and parseable before deploy.",
        "Restore a valid firebase.json with Firestore and Hosting config.",
    )

    firestore_config = (firebase_config or {}).get("firestore")
    firestore_targets = (
        firestore_config if isinstance(firestore_config, list)
        else [firestore_config] if isinstance(firestore_config, dict)
        else []
    )
    firestore_rule_pointers = [
        target.get("rules") if isinstance(target, dict) else None
        for target in firestore_targets
    ]
    firestore_rules_pointer_is_safe = (
        bool(firestore_rule_pointers)
        and all(pointer == "firestore.rules" for pointer in firestore_rule_pointers)
    )
    add(
        "firestoreRulesPointer",
        "firestoreRulesPointer",
        firestore_rules_pointer_is_safe,
        firestore_rule_pointers,
        "firebase.json must point Firestore deploys at firestore.rules.",
        "Set firebase.json firestore.rules to `firestore.rules`.",
    )

    functions_config = (firebase_config or {}).get("functions")
    functions_targets = (
        functions_config if isinstance(functions_config, list)
        else [functions_config] if isinstance(functions_config, dict)
        else []
    )
    unlocked_function_codebases = []
    for index, target in enumerate(functions_targets):
        if not isinstance(target, dict):
            unlocked_function_codebases.append(f"invalid-{index}")
            continue
        predeploy = target.get("predeploy")
        if (
            not isinstance(predeploy, list)
            or not predeploy
            or predeploy[0] != FIREBASE_BACKEND_DEPLOYMENT_BLOCKER
        ):
            unlocked_function_codebases.append(target.get("codebase") or "default")
    functions_deploy_locked = bool(functions_targets) and not unlocked_function_codebases
    add(
        "firebaseFunctionsDeployLock",
        "firebaseFunctionsDeployLock",
        functions_deploy_locked,
        (
            "allCodebasesBlockedFirst"
            if functions_deploy_locked
            else "missingOrUnlocked:" + ",".join(unlocked_function_codebases or ["none"])
        ),
        (
            "Every checked-in Firebase Functions codebase must refuse deployment "
            "before lint, build, preparation, or network mutation while the social "
            "release gate is open."
        ),
        (
            "Make the first functions predeploy hook in firebase.json exactly "
            f"`{FIREBASE_BACKEND_DEPLOYMENT_BLOCKER}`."
        ),
    )

    unlocked_firestore_targets = []
    for index, target in enumerate(firestore_targets):
        if not isinstance(target, dict):
            unlocked_firestore_targets.append(f"invalid-{index}")
            continue
        predeploy = target.get("predeploy")
        if (
            not isinstance(predeploy, list)
            or not predeploy
            or predeploy[0] != FIREBASE_BACKEND_DEPLOYMENT_BLOCKER
        ):
            unlocked_firestore_targets.append(target.get("database") or "default")
    firestore_deploy_locked = bool(firestore_targets) and not unlocked_firestore_targets
    add(
        "firebaseFirestoreDeployLock",
        "firebaseFirestoreDeployLock",
        firestore_deploy_locked,
        (
            "allDatabasesBlockedFirst"
            if firestore_deploy_locked
            else "missingOrUnlocked:" + ",".join(unlocked_firestore_targets or ["none"])
        ),
        (
            "Checked-in Firebase Firestore deployment must refuse before rules or "
            "index mutation while the coordinated social release gate is open."
        ),
        (
            "Make the first Firestore predeploy hook in firebase.json exactly "
            f"`{FIREBASE_BACKEND_DEPLOYMENT_BLOCKER}`."
        ),
    )

    hosting_config = (firebase_config or {}).get("hosting") or {}
    hosting_public = hosting_config.get("public")
    add(
        "hostingPublicDirectory",
        "hostingPublicDirectory",
        hosting_public == "public",
        hosting_public,
        "Firebase Hosting must serve the checked-in public directory.",
        "Set firebase.json hosting.public to `public`.",
    )
    hosting_predeploy = hosting_config.get("predeploy")
    hosting_is_independent = not (
        isinstance(hosting_predeploy, list)
        and FIREBASE_BACKEND_DEPLOYMENT_BLOCKER in hosting_predeploy
    )
    add(
        "firebaseHostingDeployIsolation",
        "firebaseHostingDeployIsolation",
        hosting_is_independent,
        "independent" if hosting_is_independent else "backendBlockerInherited",
        (
            "The disabled social-backend gate must not prevent an independently "
            "authorized hosted privacy-policy correction."
        ),
        "Remove the backend deployment blocker from Firebase Hosting predeploy hooks.",
    )

    privacy_rewrite_present = any(
        item.get("source") == "/privacy" and item.get("destination") == "/privacy.html"
        for item in hosting_config.get("rewrites", [])
        if isinstance(item, dict)
    )
    add(
        "hostingPrivacyRewrite",
        "hostingPrivacyRewrite",
        privacy_rewrite_present,
        privacy_rewrite_present,
        "Firebase Hosting must rewrite /privacy to /privacy.html.",
        "Add the /privacy -> /privacy.html rewrite to firebase.json.",
    )
    required_public_rewrites = {
        "/privacy": "/privacy.html",
        "/support": "/support.html",
        "/how-noum-coaches": "/how-noum-coaches.html",
    }
    observed_public_rewrites = {
        item.get("source"): item.get("destination")
        for item in hosting_config.get("rewrites", [])
        if isinstance(item, dict)
    }
    public_rewrites_complete = all(
        observed_public_rewrites.get(source) == destination
        for source, destination in required_public_rewrites.items()
    )
    add(
        "hostingPublicPageRewrites",
        "hostingPublicPageRewrites",
        public_rewrites_complete,
        "complete" if public_rewrites_complete else "missingOrDrifted",
        "Firebase Hosting must route every reviewed public launch page.",
        "Restore the privacy, support, and coaching-method rewrites.",
    )

    firestore_rules = file_text(root, "firestore.rules")
    add(
        "firestoreRulesFile",
        "firestoreRulesFile",
        firestore_rules is not None,
        "present" if firestore_rules is not None else "missing",
        "The deploy target must have committed Firestore rules.",
        "Restore firestore.rules.",
    )
    if firestore_rules is not None:
        private_user_guard_present = (
            (
                "match /users/{accountID}/{document=**}" in firestore_rules and
                "request.auth.uid == accountID" in firestore_rules
            ) or (
                "match /users/{accountID}" in firestore_rules and
                "function isOwner(accountID)" in firestore_rules and
                "function isWritableOwner(accountID)" in firestore_rules and
                all(
                    path in firestore_rules for path in [
                        "match /profile/{profileID}",
                        "match /progress/{progressID}",
                        "match /sessions/{sessionID}",
                        "match /recommendations/{recommendationID}",
                    ]
                )
            )
        )
        public_profile_guard_present = (
            "match /profiles_public/{accountID}" in firestore_rules and
            (
                "request.resource.data.keys().hasOnly" in firestore_rules or
                (
                    "function updatesOnlyDisplayName(accountID)" in firestore_rules and
                    "affectedKeys().hasOnly(['displayName'])" in firestore_rules and
                    "allow update: if updatesOnlyDisplayName(accountID);" in firestore_rules
                )
            )
        )
        add(
            "firestoreRulesPrivateUsers",
            "firestoreRulesPrivateUsers",
            private_user_guard_present,
            "privateUserRulePresent",
            "Private user documents must be scoped to the signed-in account.",
            "Repair firestore.rules private user ownership guard.",
        )
        add(
            "firestoreRulesPublicProfileWriteGuard",
            "firestoreRulesPublicProfileWriteGuard",
            public_profile_guard_present,
            "publicProfileGuardPresent",
            "Public profile writes must be field-limited and account-owned.",
            "Repair profiles_public write guards in firestore.rules.",
        )
        add(
            "firestoreRulesLeagueAndChallengeScopes",
            "firestoreRulesLeagueAndChallengeScopes",
            "match /leagues/{bucket}/members/{accountID}" in firestore_rules and
            "match /challenges/{challengeID}" in firestore_rules,
            "leagueChallengeRulesPresent",
            "Peer/league launch surfaces need explicit Firestore rules.",
            "Restore league and challenge rule blocks in firestore.rules.",
        )

    privacy_html = file_text(root, "public/privacy.html")
    add(
        "hostedPrivacyHtml",
        "hostedPrivacyHtml",
        privacy_html is not None and "Noum" in privacy_html and "Privacy Policy" in privacy_html,
        "present" if privacy_html is not None else "missing",
        "The hosted privacy page must be staged locally before deploy.",
        "Restore public/privacy.html with Noum privacy policy content.",
    )
    add(
        "landingHtml",
        "landingHtml",
        (root / "public/index.html").is_file(),
        "present" if (root / "public/index.html").is_file() else "missing",
        "Firebase Hosting should have a landing page beside privacy.html.",
        "Restore public/index.html.",
    )
    public_source_paths = [
        root / source_path
        for _, _, source_path in PUBLIC_LIVE_PAGE_SPECS
    ]
    all_public_sources_present = all(path.is_file() for path in public_source_paths)
    add(
        "hostedPublicPageSources",
        "hostedPublicPageSources",
        all_public_sources_present,
        "allFourPresent" if all_public_sources_present else "oneOrMoreMissing",
        "All four exact-body launch sources must exist before Hosting deploy.",
        "Restore index, privacy, support, and how-noum-coaches HTML sources.",
    )
    add(
        "bundledPrivacyPolicy",
        "bundledPrivacyPolicy",
        (root / "Noum/PrivacyPolicy.md").is_file(),
        "present" if (root / "Noum/PrivacyPolicy.md").is_file() else "missing",
        "The in-app privacy policy view must have bundled Markdown content.",
        "Restore Noum/PrivacyPolicy.md.",
    )

    web_urls = file_text(root, "Noum/NoumWebURLs.swift") or ""
    configured_privacy_url = privacy_url_from_repo(root)
    configured_origin = hosting_origin_from_repo(root)
    required_web_url_fragments = (
        "static let landing = hostingOrigin",
        'static let privacy = hostingOrigin.appendingPathComponent("privacy")',
        'static let support = hostingOrigin.appendingPathComponent("support")',
        'static let coachingMethod = hostingOrigin.appendingPathComponent("how-noum-coaches")',
    )
    app_web_origin_approved = bool(
        configured_origin
        and approved_https_origin_matches(configured_origin, configured_origin)
        and all(fragment in web_urls for fragment in required_web_url_fragments)
    )
    add(
        "appPrivacyURLConstant",
        "appPrivacyURLConstant",
        app_web_origin_approved,
        configured_privacy_url or "missing",
        "The app must derive public pages from an approved direct Hosting origin.",
        "Restore NoumWebURLs.hostingOrigin to verified Firebase Hosting.",
    )

    privacy_view = file_text(root, "Noum/PrivacyPolicyView.swift") or ""
    add(
        "inAppPrivacyWebLink",
        "inAppPrivacyWebLink",
        "NoumWebURLs.privacy" in privacy_view and "Open privacy policy on web" in privacy_view,
        "webLinkPresent" if "NoumWebURLs.privacy" in privacy_view else "missing",
        "The in-app privacy policy must expose the hosted policy URL.",
        "Repair PrivacyPolicyView's hosted privacy Link.",
    )

    settings_view = file_text(root, "Noum/SettingsView.swift") or ""
    add(
        "settingsPrivacyEntry",
        "settingsPrivacyEntry",
        "Privacy policy" in settings_view and "showPrivacyPolicy = true" in settings_view,
        "settingsEntryPresent" if "showPrivacyPolicy = true" in settings_view else "missing",
        "Settings must expose the privacy policy before launch.",
        "Restore the Settings privacy row and sheet action.",
    )

    qa_doc = file_text(root, "docs/TESTFLIGHT_QA.md") or ""
    add(
        "testFlightQAChecklist",
        "testFlightQAChecklist",
        all(
            phrase in qa_doc for phrase in [
                "rules-only Firebase deployment is never",
                "scripts/deploy-hosting.mjs",
                "https://noum-d0b6f.web.app/privacy",
                "Live Activity",
                "AI prompt latency",
                "Paywall",
            ]
        ),
        "qaChecklistPresent" if qa_doc else "missing",
        "The release manager needs a hardware/TestFlight QA checklist.",
        "Restore docs/TESTFLIGHT_QA.md with deploy, privacy, and high-risk surface checks.",
    )

    firestore_operator_doc = file_text(root, "FIRESTORE_RULES.md") or ""
    legacy_emulator_entry = file_text(root, "scripts/test-coach-functions-emulator.sh") or ""
    operator_deployment_text = "\n".join((
        qa_doc,
        firestore_operator_doc,
        legacy_emulator_entry,
    ))
    unsafe_operator_fragments = (
        "firebase-tools@latest",
        "firebase deploy --only firestore:rules",
    )
    operator_instructions_safe = (
        "./scripts/release-functions-emulator.sh" in firestore_operator_doc
        and "release-functions-emulator.sh" in legacy_emulator_entry
        and not any(
            fragment in operator_deployment_text
            for fragment in unsafe_operator_fragments
        )
    )
    add(
        "operatorDeployInstructionsSafe",
        "operatorDeployInstructionsSafe",
        operator_instructions_safe,
        "pinned emulator and coordinated deployment instructions" if operator_instructions_safe else "unsafe or stale Firebase operator instruction",
        "Active operator paths must use pinned tooling and must not authorize a Firestore rules-only deployment.",
        "Use the pinned release emulator and remove mutable-CLI or rules-only deployment commands from active operator instructions.",
    )

    failures = [check for check in checks if not check["passed"]]
    return {
        "repoRoot": str(root),
        "validationBoundary": (
            "Static ops preflight checks local repository wiring only; it does not "
            "prove Firestore rules were deployed, the privacy URL is live, App Store "
            "privacy disclosures were reviewed, TestFlight was uploaded, or release "
            "bugs were triaged."
        ),
        "checkCount": len(checks),
        "passCount": len(checks) - len(failures),
        "failureCount": len(failures),
        "checks": checks,
        "failures": failures,
    }


def operational_static_gate_failures(preflight):
    failures = []
    for item in preflight.get("failures") or []:
        failures.append({
            "label": item["label"],
            "observed": item.get("observed"),
            "gate": item["gate"],
            "nextStep": item["nextStep"],
        })
    return failures


def build_readiness_status(
    report,
    report_path,
    dump_dir=DEFAULT_DUMP_DIR,
    repo_root=REPO_ROOT,
    probe_live=False,
    fetch_url=default_fetch_url,
    release_evidence_run=DEFAULT_RELEASE_EVIDENCE_RUN_DIR,
    release_evidence_validator=default_release_evidence_validator,
):
    local_readiness = readiness_from_report(report)
    summary = report.get("summary") if isinstance(report.get("summary"), dict) else {}
    local_gates = local_gates_from_report(report)
    report_audit = report_source_audit(report, report_path)
    report_source_failures = report_source_gate_failures(report_audit)
    artifact_audit = evidence_artifact_audit(dump_dir, local_readiness)
    readiness = readiness_with_verified_artifacts(local_readiness, artifact_audit)
    artifact_audit = evidence_artifact_audit(dump_dir, readiness)
    manifest_audit = readiness_manifest_audit(dump_dir, readiness)
    computed_ready = computed_production_ready(readiness)
    local_failures = report_source_failures + local_readiness_failures(local_gates, readiness)
    source_audit = source_freshness_audit(report, artifact_audit, repo_root)
    source_failures = source_freshness_gate_failures(source_audit)
    local_failures = local_failures + source_failures
    artifact_failures = artifact_gate_failures(artifact_audit)
    manifest_failures = readiness_manifest_gate_failures(manifest_audit)
    ops_preflight = operational_static_preflight(repo_root)
    ops_failures = operational_static_gate_failures(ops_preflight)
    ops_live_probe = operational_live_probe(repo_root, fetch_url) if probe_live else None
    ops_live_failures = operational_live_gate_failures(ops_live_probe)
    release_evidence_audit = release_evidence_run_audit(
        release_evidence_run,
        dump_dir,
        repo_root,
        validator=release_evidence_validator,
    )
    release_evidence_failures = release_evidence_run_gate_failures(
        release_evidence_audit
    )
    launch_ready = computed_launch_ready(
        readiness,
        local_gates,
        artifact_audit,
        manifest_audit,
        ops_preflight,
        ops_live_probe,
        source_audit,
        report_audit,
        release_evidence_audit,
    )
    reported_ready = summary.get("visionProductionReady")
    blockers = readiness.get("blockers") if readiness else None
    if blockers is None:
        blockers = list(EVIDENCE_REQUIREMENTS.keys())
    warnings = []
    if reported_ready is not None and bool(reported_ready) != computed_production_ready(local_readiness):
        warnings.append("reportedVisionProductionReadyMismatch")
    if readiness is None:
        warnings.append("missingVisionProductionReadiness")
    return {
        "reportPath": str(report_path),
        "reportFamily": report.get("reportFamily") or "missing",
        "reportSourceAudit": report_audit,
        "generatedAt": report.get("generatedAt"),
        "launchReady": launch_ready,
        "localGates": local_gates,
        "localBlockingRequirements": local_failures,
        "artifactBlockingRequirements": artifact_failures,
        "readinessManifestBlockingRequirements": manifest_failures,
        "releaseEvidenceBlockingRequirements": release_evidence_failures,
        "operationalStaticBlockingRequirements": ops_failures,
        "operationalLiveBlockingRequirements": ops_live_failures,
        "vision": {
            "productionReady": computed_ready,
            "score": readiness.get("score") if readiness else None,
            "minimumReadyScore": READY_SCORE,
            "localTargetShapeScore": readiness.get("localTargetShapeScore") if readiness else None,
            "minimumLocalTargetShapeScore": READY_LOCAL_TARGET_SHAPE_SCORE,
            "maximumAllowedScore": readiness.get("maximumAllowedScore") if readiness else None,
            "claim": readiness.get("claim") if readiness else None,
            "requiredClaim": READY_CLAIM,
            "blockers": blockers,
            "summary": readiness.get("summary") if readiness else None,
        },
        "blockingRequirements": blocking_requirements(readiness),
        "artifactAudit": artifact_audit,
        "readinessManifestAudit": manifest_audit,
        "releaseEvidenceRunAudit": release_evidence_audit,
        "sourceFreshnessAudit": source_audit,
        "operationalStaticPreflight": ops_preflight,
        "operationalLiveProbe": ops_live_probe,
        "uiFlowBoundary": UI_FLOW_BOUNDARY,
        "warnings": warnings,
    }


def render_markdown(status):
    vision = status["vision"]
    local = status["localGates"]
    report_source = status.get("reportSourceAudit") or {}
    manifest_audit = status.get("readinessManifestAudit") or {}
    release_evidence_audit = status.get("releaseEvidenceRunAudit") or {}
    lines = [
        "# Coach Production Readiness Gate",
        "",
        f"- Report: `{status['reportPath']}`",
        f"- Generated: `{status.get('generatedAt')}`",
        f"- Report family: `{status.get('reportFamily')}`",
        f"- Canonical app-path report: `{report_source.get('passes')}`",
        f"- Current Swift readiness manifest: `{manifest_audit.get('passes')}`",
        f"- Attachment-backed release evidence: `{release_evidence_audit.get('passes')}`",
        f"- Launch gate ready: `{status.get('launchReady')}`",
        f"- Local score/coverage gates pass: `{local.get('scoreThresholdsPass')}`",
        f"- Real-pipeline evidence passes: `{local.get('realPipelineEvidencePasses')}`",
        f"- Trace quality passes: `{local.get('traceQualityPasses')}`",
        f"- VISION production ready: `{vision.get('productionReady')}`",
        f"- VISION score: `{vision.get('score')}/100`",
        f"- Local target-shape score: `{vision.get('localTargetShapeScore')}/100`",
        f"- Maximum allowed score: `{vision.get('maximumAllowedScore')}/100`",
        f"- Claim: `{vision.get('claim')}`",
        "",
    ]
    if vision.get("summary"):
        lines.extend([vision["summary"], ""])

    requirements = status["blockingRequirements"]
    if requirements:
        lines.extend(["## Blocking Evidence", ""])
        for requirement in requirements:
            lines.append(
                f"- `{requirement['blocker']}` -> `{requirement['artifact']}` "
                f"({requirement.get('owner', 'owner not mapped')})"
            )
            lines.append(f"  Gate: {requirement['gate']}")
            lines.append(f"  Next: {requirement['nextStep']}")
        lines.append("")
    else:
        lines.extend(["## Blocking Evidence", "", "- `none`", ""])

    local_requirements = status["localBlockingRequirements"]
    if local_requirements:
        lines.extend(["## Local Gate Failures", ""])
        for requirement in local_requirements:
            lines.append(
                f"- `{requirement['label']}` observed `{requirement.get('observed')}`"
            )
            if requirement.get("sidecar") is not None:
                lines.append(f"  Sidecar: `{requirement['sidecar']}`")
            if requirement.get("reportValues"):
                rendered_values = ", ".join(f"`{value}`" for value in requirement["reportValues"])
                lines.append(f"  Report values: {rendered_values}")
            lines.append(f"  Gate: {requirement['gate']}")
            lines.append(f"  Next: {requirement['nextStep']}")
        lines.append("")

    lines.extend([
        "## Report Source",
        "",
        f"- Required family: `{report_source.get('requiredReportFamily')}`",
        f"- Observed family: `{report_source.get('reportFamily')}`",
        f"- Canonical path: `{report_source.get('canonicalPath')}`",
        f"- Canonical dir: `{report_source.get('canonicalReportDir')}`",
        f"- Normalized report path: `{report_source.get('normalizedReportPath')}`",
    ])
    if report_source.get("validationBoundary"):
        lines.append(f"- Boundary: {report_source['validationBoundary']}")
    lines.append("")

    artifact_requirements = status["artifactBlockingRequirements"]
    if artifact_requirements:
        lines.extend(["## Artifact Gate Failures", ""])
        for requirement in artifact_requirements:
            lines.append(
                f"- `{requirement['label']}` observed `{requirement.get('observed')}`"
            )
            lines.append(f"  Gate: {requirement['gate']}")
            lines.append(f"  Next: {requirement['nextStep']}")
        lines.append("")

    manifest_requirements = status.get("readinessManifestBlockingRequirements") or []
    if manifest_requirements:
        lines.extend(["## Readiness Manifest Failures", ""])
        for requirement in manifest_requirements:
            lines.append(
                f"- `{requirement['label']}` observed `{requirement.get('observed')}`"
            )
            lines.append(f"  Gate: {requirement['gate']}")
            lines.append(f"  Next: {requirement['nextStep']}")
        lines.append("")

    release_evidence_requirements = status.get("releaseEvidenceBlockingRequirements") or []
    if release_evidence_requirements:
        lines.extend(["## Release Evidence Workflow Failures", ""])
        for requirement in release_evidence_requirements:
            lines.append(
                f"- `{requirement['label']}` observed `{requirement.get('observed')}`"
            )
            lines.append(f"  Gate: {requirement['gate']}")
            lines.append(f"  Next: {requirement['nextStep']}")
        lines.append("")

    lines.extend([
        "## Release Evidence Run",
        "",
        f"- Run: `{release_evidence_audit.get('runDir')}`",
        f"- Validated and promotion-bound: `{release_evidence_audit.get('passes')}`",
    ])
    if release_evidence_audit.get("validationBoundary"):
        lines.append(f"- Boundary: {release_evidence_audit['validationBoundary']}")
    lines.append("")

    ops_requirements = status["operationalStaticBlockingRequirements"]
    if ops_requirements:
        lines.extend(["## Operational Static Gate Failures", ""])
        for requirement in ops_requirements:
            lines.append(
                f"- `{requirement['label']}` observed `{requirement.get('observed')}`"
            )
            lines.append(f"  Gate: {requirement['gate']}")
            lines.append(f"  Next: {requirement['nextStep']}")
        lines.append("")

    ops_live_requirements = status.get("operationalLiveBlockingRequirements") or []
    if ops_live_requirements:
        lines.extend(["## Operational Live Gate Failures", ""])
        for requirement in ops_live_requirements:
            lines.append(
                f"- `{requirement['label']}` observed `{requirement.get('observed')}`"
            )
            lines.append(f"  Gate: {requirement['gate']}")
            lines.append(f"  Next: {requirement['nextStep']}")
        lines.append("")

    artifact_audit = status.get("artifactAudit") or {}
    lines.extend([
        "## Evidence Directory",
        "",
        f"- Dump dir: `{artifact_audit.get('dumpDir')}`",
        f"- Dump dir exists: `{artifact_audit.get('dumpDirExists')}`",
        f"- Required sidecars present: `{artifact_audit.get('presentArtifactCount')}/{artifact_audit.get('requiredArtifactCount')}`",
        f"- Required sidecars passing staging contract: `{artifact_audit.get('validArtifactContractCount')}/{artifact_audit.get('requiredArtifactCount')}`",
        f"- Source sidecars present: `{artifact_audit.get('presentSourceSidecarCount')}/{artifact_audit.get('sourceSidecarCount')}`",
    ])
    if artifact_audit.get("validationBoundary"):
        lines.append(f"- Boundary: {artifact_audit['validationBoundary']}")
    missing_artifacts = artifact_audit.get("missingArtifacts") or []
    if missing_artifacts:
        lines.append("- Missing sidecars:")
        for item in missing_artifacts:
            lines.append(f"  - `{item['artifact']}`")
    invalid_artifacts = artifact_audit.get("invalidArtifacts") or []
    if invalid_artifacts:
        lines.append("- Invalid sidecars:")
        for item in invalid_artifacts:
            failures = ", ".join(item.get("contractFailures") or ["invalid"])
            expected = item.get("expectedSchemaVersion") or "unknown schema"
            lines.append(f"  - `{item['artifact']}` -> `{failures}` (expected `{expected}`)")
    present_but_blocked = artifact_audit.get("presentButStillBlockedArtifacts") or []
    if present_but_blocked:
        lines.append("- Staged but still blocked in latest report:")
        for item in present_but_blocked:
            lines.append(
                f"  - `{item['artifact']}` -> rerun the Swift manifest/app-path report to validate it"
            )
    source_sidecars = artifact_audit.get("sourceSidecars") or []
    if source_sidecars:
        lines.append("- Source sidecars:")
        for item in source_sidecars:
            state = "present" if item.get("present") else "missing"
            lines.append(f"  - `{item['fileName']}`: `{state}`")
    lines.append("")

    source_audit = status.get("sourceFreshnessAudit") or {}
    lines.extend([
        "## Source Freshness",
        "",
        f"- Passes: `{source_audit.get('passes')}`",
        f"- Current coach fingerprint: `{source_audit.get('currentCoachFingerprint')}`",
        f"- Current git commit: `{source_audit.get('currentGitCommit')}`",
        f"- Sidecar coach fingerprint: `{source_audit.get('sidecarCoachFingerprint')}`",
        f"- Sidecar git commit: `{source_audit.get('sidecarGitCommit')}`",
    ])
    report_fingerprints = source_audit.get("reportCoachFingerprints") or []
    report_commits = source_audit.get("reportGitCommits") or []
    if report_fingerprints:
        lines.append("- Report coach fingerprints:")
        for value in report_fingerprints:
            lines.append(f"  - `{value}`")
    else:
        lines.append("- Report coach fingerprints: `none found`")
    if report_commits:
        lines.append("- Report git commits:")
        for value in report_commits:
            lines.append(f"  - `{value}`")
    else:
        lines.append("- Report git commits: `none found`")
    if source_audit.get("validationBoundary"):
        lines.append(f"- Boundary: {source_audit['validationBoundary']}")
    freshness_mismatches = (
        (source_audit.get("mismatches") or []) +
        (source_audit.get("currentMismatches") or [])
    )
    if freshness_mismatches:
        lines.append("- Source mismatches:")
        for item in freshness_mismatches:
            observed = item.get("current") or item.get("sidecar")
            against = item.get("mismatchedAgainst") or ["report"]
            lines.append(
                f"  - `{item.get('label')}` observed `{observed}` vs "
                f"`{', '.join(against)}`"
            )
    lines.append("")

    ops_preflight = status.get("operationalStaticPreflight") or {}
    lines.extend([
        "## Operational Static Preflight",
        "",
        f"- Repo root: `{ops_preflight.get('repoRoot')}`",
        f"- Checks passing: `{ops_preflight.get('passCount')}/{ops_preflight.get('checkCount')}`",
    ])
    if ops_preflight.get("validationBoundary"):
        lines.append(f"- Boundary: {ops_preflight['validationBoundary']}")
    failures = ops_preflight.get("failures") or []
    if failures:
        lines.append("- Failed checks:")
        for item in failures:
            lines.append(f"  - `{item['label']}`")
    else:
        lines.append("- Failed checks: `none`")
    lines.append("")

    ops_live_probe = status.get("operationalLiveProbe")
    if ops_live_probe is not None:
        lines.extend([
            "## Operational Live Probe",
            "",
            f"- Checks passing: `{ops_live_probe.get('passCount')}/{ops_live_probe.get('checkCount')}`",
        ])
        configured_origin = next(
            (
                item.get("observed") for item in ops_live_probe.get("checks", [])
                if item.get("key") == "publicWebOriginConfigured"
            ),
            None,
        )
        if configured_origin:
            lines.append(f"- Public origin: `{configured_origin}`")
        if ops_live_probe.get("validationBoundary"):
            lines.append(f"- Boundary: {ops_live_probe['validationBoundary']}")
        failures = ops_live_probe.get("failures") or []
        if failures:
            lines.append("- Failed checks:")
            for item in failures:
                lines.append(f"  - `{item['label']}` observed `{item.get('observed')}`")
        else:
            lines.append("- Failed checks: `none`")
        lines.append("")

    ui = status["uiFlowBoundary"]
    lines.extend([
        "## UI Flow Boundary",
        "",
        "- Maestro smoke flows:",
    ])
    for flow in ui["maestroSmokeFlows"]:
        lines.append(f"  - `{flow}`")
    lines.append("- Covered by smoke:")
    for item in ui["covered"]:
        lines.append(f"  - {item}")
    lines.append(
        f"- Not launch proof until `{ui['realDeviceArtifact']}` covers:"
    )
    for item in ui["notLaunchProof"]:
        lines.append(f"  - {item}")

    if status["warnings"]:
        lines.extend(["", "## Warnings", ""])
        for warning in status["warnings"]:
            lines.append(f"- `{warning}`")
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Report Noum VISION production readiness.")
    parser.add_argument("--report", default=str(DEFAULT_REPORT))
    parser.add_argument("--dump-dir", default=str(DEFAULT_DUMP_DIR))
    parser.add_argument("--repo-root", default=str(REPO_ROOT))
    parser.add_argument(
        "--release-evidence-run",
        default=DEFAULT_RELEASE_EVIDENCE_RUN_DIR,
        help=(
            "Validated attachment-backed release-evidence run used to promote "
            "the four managed external artifacts. Defaults to "
            "NOUM_RELEASE_EVIDENCE_RUN_DIR."
        ),
    )
    parser.add_argument(
        "--probe-live",
        action="store_true",
        help="Probe public operational URLs and include failures in launchReady.",
    )
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--no-fail", action="store_true")
    args = parser.parse_args(argv)

    report_path = Path(args.report)
    report = load_report(report_path)
    status = build_readiness_status(
        report,
        report_path,
        Path(args.dump_dir),
        Path(args.repo_root),
        probe_live=args.probe_live,
        release_evidence_run=args.release_evidence_run,
    )
    if args.json:
        print(json.dumps(status, indent=2, sort_keys=True))
    else:
        print(render_markdown(status))
    if not args.no_fail and not status["launchReady"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
