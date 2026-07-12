import json
import plistlib
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest import mock

import readiness_gate as gate


def report_with_readiness(readiness, **local_overrides):
    if readiness is not None:
        readiness = dict(readiness)
        readiness.setdefault(
            "localTargetShapeScore",
            gate.READY_LOCAL_TARGET_SHAPE_SCORE,
        )
    local_gates = {
        "scoreThresholdsPass": True,
        "realPipelineEvidencePasses": True,
        "traceQualityPasses": True,
        "average": 78.56,
        "failureCount": 0,
    }
    local_gates.update(local_overrides)
    return {
        "reportFamily": "app-path",
        "generatedAt": "2026-07-08T22:05:07+00:00",
        "summary": {
            **local_gates,
            "visionProductionReady": gate.computed_production_ready(readiness),
            "visionProductionReadiness": readiness,
        },
    }


def canonical_report_path():
    return gate.ARENA_ROOT / "reports" / "app-path" / "latest.json"


def write_static_ops_repo(root):
    root = Path(root)
    (root / "public").mkdir(parents=True, exist_ok=True)
    (root / "Noum").mkdir(parents=True, exist_ok=True)
    (root / "Noum.xcodeproj").mkdir(parents=True, exist_ok=True)
    (root / "docs").mkdir(parents=True, exist_ok=True)
    (root / ".gitignore").write_text(
        (
            "Noum/AIConfig.plist\n"
            "Noum/BackendConfig.plist\n"
            "Noum/Transcribe.plist\n"
            "Noum/TranscriptionProviders.plist\n"
        ),
        encoding="utf-8",
    )
    (root / "Noum/AIConfig.plist.example").write_text(
        "<plist><dict><key>OPENAI_API_KEY</key><string>REPLACE_ME</string></dict></plist>",
        encoding="utf-8",
    )
    (root / "Noum.xcodeproj/project.pbxproj").write_text(
        """
/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
    TEST /* Exceptions for "Noum" folder in "Noum" target */ = {
        isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
        membershipExceptions = (
            AIConfig.plist,
            BackendConfig.plist,
            Info.plist,
            Transcribe.plist,
            TranscriptionProviders.plist,
        );
        target = TEST_TARGET /* Noum */;
    };
/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */
""",
        encoding="utf-8",
    )
    (root / "firebase.json").write_text(
        json.dumps({
            "firestore": {"rules": "firestore.rules"},
            "hosting": {
                "public": "public",
                "rewrites": [
                    {"source": "/privacy", "destination": "/privacy.html"},
                ],
            },
        }),
        encoding="utf-8",
    )
    (root / "firestore.rules").write_text(
        """
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{accountID}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == accountID;
    }
    match /profiles_public/{accountID} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
        && request.auth.uid == accountID
        && request.resource.data.keys().hasOnly(['accountID']);
    }
    match /leagues/{bucket}/members/{accountID} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == accountID;
    }
    match /challenges/{challengeID} {
      allow read: if request.auth != null;
    }
  }
}
""",
        encoding="utf-8",
    )
    (root / "public/privacy.html").write_text(
        "<title>Noum — Privacy Policy</title><main>Noum Privacy Policy</main>",
        encoding="utf-8",
    )
    (root / "public/index.html").write_text("<title>Noum</title>", encoding="utf-8")
    (root / "Noum/PrivacyPolicy.md").write_text("# Privacy Policy\n", encoding="utf-8")
    (root / "Noum/PrivacyInfo.xcprivacy").write_bytes(plistlib.dumps({
        "NSPrivacyTracking": False,
        "NSPrivacyTrackingDomains": [],
        "NSPrivacyCollectedDataTypes": [
            {
                "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeOtherUserContent",
                "NSPrivacyCollectedDataTypeLinked": True,
                "NSPrivacyCollectedDataTypeTracking": False,
                "NSPrivacyCollectedDataTypePurposes": [
                    "NSPrivacyCollectedDataTypePurposeAppFunctionality",
                ],
            },
            {
                "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypePhotosorVideos",
                "NSPrivacyCollectedDataTypeLinked": True,
                "NSPrivacyCollectedDataTypeTracking": False,
                "NSPrivacyCollectedDataTypePurposes": [
                    "NSPrivacyCollectedDataTypePurposeAppFunctionality",
                ],
            },
        ],
        "NSPrivacyAccessedAPITypes": [],
    }))
    (root / "Noum/NoumWebURLs.swift").write_text(
        'static let privacy = URL(string: "https://noum-d0b6f.web.app/privacy")!',
        encoding="utf-8",
    )
    (root / "Noum/PrivacyPolicyView.swift").write_text(
        'Link(destination: NoumWebURLs.privacy) { Text("Open") }.accessibilityLabel("Open privacy policy on web")',
        encoding="utf-8",
    )
    (root / "Noum/SettingsView.swift").write_text(
        'Text("Privacy policy"); showPrivacyPolicy = true',
        encoding="utf-8",
    )
    (root / "docs/TESTFLIGHT_QA.md").write_text(
        """
firebase deploy --only firestore:rules
firebase deploy --only hosting
https://noum-d0b6f.web.app/privacy
Live Activity
AI prompt latency
Paywall
""",
        encoding="utf-8",
    )


def write_coach_source(root, contents="final reply pipeline"):
    path = Path(root) / "Noum/CoachReplyPipeline.swift"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents, encoding="utf-8")
    return path


def live_provider_row(row_id, index, turn_depth=None, immediate_expected=True, reply=None):
    return {
        "fixtureID": row_id,
        "turnDepth": turn_depth or gate.LIVE_REQUIRED_TURN_DEPTHS[index % len(gate.LIVE_REQUIRED_TURN_DEPTHS)],
        "providerChosen": "Gemini",
        "providerModel": "gemini-test",
        "timeToFirstVisibleTokenMs": 420 + index,
        "assessmentConfidence": 0.62 + ((index % 4) * 0.04),
        "trajectoryCacheHit": index % 5 == 0,
        "assessmentProofTestHash": f"{row_id}-proof-{index}",
        "immediateCoachReadExpected": immediate_expected,
        "immediateCoachReadShown": immediate_expected,
        "liveProductionFloor": True,
        "reply": reply or (
            f"{row_id} names the current evidence, answers the user's ask, "
            "and gives one proof test."
        ),
        "passesRubric": True,
        "visionPassesProductionFloor": True,
        "qualityIssue": "none",
        "semanticGateIssue": "none",
        "reliabilityIssues": [],
    }


def live_long_form_conversation(conversation_id, index):
    rows = [
        live_provider_row(
            f"{conversation_id}#turn-{turn_index + 1}",
            index + turn_index,
            immediate_expected=False,
            reply=(
                f"{conversation_id} turn {turn_index + 1} carries evidence, "
                "keeps the plan continuous, and ends with a proof test."
            ),
        )
        for turn_index in range(5)
    ]
    return {
        "conversationID": conversation_id,
        "sourceFixtureID": gate.LIVE_REQUIRED_FIXTURE_IDS[index % len(gate.LIVE_REQUIRED_FIXTURE_IDS)],
        "expectedTurnCount": len(rows),
        "observedTurnCount": len(rows),
        "liveProductionFloor": True,
        "failure": None,
        "rows": rows,
    }


def complete_live_provider_evidence(source_fingerprint="sha256:test-source", git_commit="abc123"):
    rows = [
        live_provider_row(fixture_id, index)
        for index, fixture_id in enumerate(gate.LIVE_REQUIRED_FIXTURE_IDS)
    ]
    long_form = [
        live_long_form_conversation(conversation_id, index)
        for index, conversation_id in enumerate(gate.LIVE_REQUIRED_LONG_FORM_IDS)
    ]
    return {
        "schemaVersion": "coach-live-eval-v1",
        "sourceGitCommit": git_commit,
        "sourceCoachFingerprint": source_fingerprint,
        "fixtureCount": len(rows),
        "longFormConversationCount": len(long_form),
        "longFormConversationIDsPassingProductionFloor": list(gate.LIVE_REQUIRED_LONG_FORM_IDS),
        "longFormConversationFailureIDs": [],
        "longFormConversations": long_form,
        "providerChain": ["Gemini (gemini-test)"],
        "passesProductionFloor": True,
        "passesRunReadinessFloor": True,
        "summary": {
            "rowCount": len(rows),
            "productionFloorFailureCount": 0,
            "readinessWarnings": [],
            "immediateCoachReadExpectedCount": len(rows),
            "immediateCoachReadMissingCount": 0,
            "assessmentConfidenceDistinctRoundedCount": 4,
            "uniqueProofTestHashCount": len(rows),
            "repeatedProofTestHashCount": 0,
            "maxProviderRetryCount": 1,
            "totalProviderRefusalCount": 0,
            "firstVisibleTokenMaxMs": 520,
        },
        "rows": rows,
    }


CALIBRATION_CONVERSATION_IDS = [
    f"calibration-conversation-{index:02d}"
    for index in range(gate.PROFESSIONAL_CALIBRATION_MIN_CONVERSATION_COUNT)
]
CALIBRATION_PACKET_FINGERPRINT = "fnv1a64:test-calibration-packet"


def calibration_packet_payload(
    conversation_ids=CALIBRATION_CONVERSATION_IDS,
    source_packet_fingerprint=CALIBRATION_PACKET_FINGERPRINT,
):
    return {
        "schemaVersion": gate.PROFESSIONAL_CALIBRATION_PACKET_SCHEMA,
        "rubricVersion": gate.PROFESSIONAL_CALIBRATION_RUBRIC,
        "sourceCorpusFingerprint": source_packet_fingerprint,
        "conversationCount": len(conversation_ids),
        "requiredIndependentReviewsPerConversation": gate.PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION,
        "requiredReviewCount": len(conversation_ids) * gate.PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION,
        "rows": [
            {
                "conversationID": conversation_id,
                "sourceFixtureID": f"fixture-{index:02d}",
                "turns": [],
            }
            for index, conversation_id in enumerate(conversation_ids)
        ],
    }


def professional_calibration_row(conversation_id, reviewer_index, row_index):
    return {
        "conversationID": conversation_id,
        "reviewerID": f"coach-reviewer-{reviewer_index + 1}",
        "calibrationDecision": "roughTie",
        "wouldUseWithClient": True,
        "ratings": {
            "diagnosis": 4,
            "caseFormulation": 4,
            "intervention": 4,
            "adaptation": 4,
            "perceptionHonesty": 4,
            "transferSetup": 4,
            "trustRepair": 4,
            "overallUsefulness": 4,
        },
        "humanCoachReferenceCount": 2,
        "overclaimNotes": [],
        "revisionNotes": [],
    }


def complete_professional_calibration_evidence(
    conversation_ids=CALIBRATION_CONVERSATION_IDS,
    source_packet_fingerprint=CALIBRATION_PACKET_FINGERPRINT,
):
    rows = [
        professional_calibration_row(conversation_id, reviewer_index, row_index)
        for row_index, (conversation_id, reviewer_index) in enumerate(
            (conversation_id, reviewer_index)
            for conversation_id in conversation_ids
            for reviewer_index in range(gate.PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION)
        )
    ]
    reviewer_ids = {row["reviewerID"] for row in rows}
    return {
        "schemaVersion": gate.PROFESSIONAL_CALIBRATION_RESULTS_SCHEMA,
        "sourcePacketSchemaVersion": gate.PROFESSIONAL_CALIBRATION_PACKET_SCHEMA,
        "sourcePacketFingerprint": source_packet_fingerprint,
        "rubricVersion": gate.PROFESSIONAL_CALIBRATION_RUBRIC,
        "reviewerRole": "professionalCommunicationCoach",
        "reviewCount": len(rows),
        "summary": {
            "rowCount": len(rows),
            "reviewerCount": len(reviewer_ids),
            "completedReviewCount": len(rows),
            "passingCalibrationCount": len(rows),
            "wouldUseWithClientCount": len(rows),
            "unsafeOrUnreadyCount": 0,
            "averageOverallUsefulness": 4.0,
            "minimumOverallUsefulness": 4,
            "readinessWarnings": [],
        },
        "rows": rows,
    }


def complete_real_user_transfer_evidence():
    rows = []
    categories = ["presentation", "interview", "leadership", "conflict", "client-call", "networking"]
    for index in range(12):
        category = categories[index % len(categories)]
        outcome_id = f"transfer-outcome-{index}"
        rows.append({
            "outcomeID": outcome_id,
            "userIDHash": f"user-{index % 10}",
            "momentCategory": category,
            "interventionID": f"intervention-{index}",
            "realWorldMomentOccurred": True,
            "followUpCompleted": True,
            "linkedCoachInterventionCount": 2,
            "daysSinceFirstNoumSession": 14 + index,
            "followUpDelayHours": 36 + index,
            "preMomentConfidence": 2 + (index % 2),
            "postMomentConfidence": 3 + (index % 2),
            "positiveTransferReported": True,
            "audienceResponseEvidenceCollected": True,
            "adverseOutcomeReported": False,
            "interventionEvidenceReference": f"noum://intervention/intervention-{index}",
            "momentEvidenceReference": f"beta://moment/{category}/{index}",
            "followUpEvidenceReference": f"beta://follow-up/{outcome_id}",
            "audienceResponseEvidenceReference": f"beta://audience-response/{outcome_id}",
            "selfReportEvidenceReference": f"beta://self-report/{outcome_id}",
            "causalityClaims": [],
            "notes": ["Verified transfer follow-up."],
        })
    return {
        "schemaVersion": gate.REAL_USER_TRANSFER_SCHEMA,
        "studyProtocolVersion": gate.REAL_USER_TRANSFER_PROTOCOL,
        "cohortDescription": "closed-beta-transfer-cohort",
        "outcomeCount": len(rows),
        "summary": {
            "rowCount": len(rows),
            "uniqueUserCount": 10,
            "completedFollowUpCount": len(rows),
            "realWorldMomentCount": len(rows),
            "linkedInterventionOutcomeCount": len(rows),
            "positiveTransferCount": len(rows),
            "audienceResponseEvidenceCount": len(rows),
            "noRegressionOutcomeCount": len(rows),
            "adverseOutcomeCount": 0,
            "passingOutcomeCount": len(rows),
            "minimumDaysSinceFirstSession": 14,
            "studyDurationDays": 42,
            "uniqueMomentCategoryCount": len(categories),
            "verifiedEvidenceReferenceCount": len(rows),
            "minimumFollowUpDelayHours": 36,
            "maximumOutcomesPerUser": 2,
            "readinessWarnings": [],
        },
        "rows": rows,
    }


def complete_real_device_testflight_evidence():
    build = "2026.06.30.1"
    rows = []
    for surface in gate.REAL_DEVICE_REQUIRED_SURFACES:
        rows.append({
            "surfaceKey": surface,
            "passed": True,
            "realDevice": True,
            "testFlightBuildInstalled": True,
            "evidenceReference": f"testflight://noum/qa/{build}/{surface}",
            "evidenceKind": gate.REAL_DEVICE_EVIDENCE_KIND_BY_SURFACE[surface],
            "evidenceCapturedAtISO8601": "2026-06-30T09:12:00Z",
            "testFlightBuildNumber": build,
            "deviceIdentifierHash": "sha256:iphone15pro-real-device-qa",
            "latencyMs": 1850 if surface == "aiPromptLatency" else None,
            "blockingIssueCount": 0,
            "notes": ["Verified on physical device through TestFlight."],
        })
    return {
        "schemaVersion": gate.REAL_DEVICE_TESTFLIGHT_SCHEMA,
        "testRunID": "real-device-qa-2026-06-30",
        "appVersion": "1.0",
        "buildNumber": build,
        "deviceModel": "iPhone 15 Pro",
        "osVersion": "iOS 26.2",
        "testerRole": "internalTestFlightQA",
        "summary": {
            "rowCount": len(rows),
            "requiredSurfaceCount": len(rows),
            "passedRequiredSurfaceCount": len(rows),
            "realDeviceSurfaceCount": len(rows),
            "testFlightBuildSurfaceCount": len(rows),
            "artifactBackedSurfaceCount": len(rows),
            "expectedEvidenceKindSurfaceCount": len(rows),
            "sameBuildSurfaceCount": len(rows),
            "deviceIdentitySurfaceCount": len(rows),
            "latencyWithinBudgetSurfaceCount": 1,
            "blockingIssueCount": 0,
            "crashFree": True,
            "readinessWarnings": [],
        },
        "rows": rows,
    }


def complete_operational_launch_evidence():
    build = "2026.06.30.1"
    items = []
    for key in gate.OPERATIONAL_LAUNCH_REQUIRED_ITEMS:
        items.append({
            "key": key,
            "completed": True,
            "evidenceReference": f"m14://launch-checklist/{build}/{key}",
            "evidenceKind": gate.OPERATIONAL_LAUNCH_EVIDENCE_KIND_BY_ITEM[key],
            "verificationReference": f"m14://launch-verification/{build}/{key}",
            "commandOrReviewOutputReference": f"m14://launch-output/{build}/{key}",
            "releaseCandidateBuild": build,
            "environment": gate.OPERATIONAL_LAUNCH_ENVIRONMENT_BY_ITEM[key],
            "completedAtISO8601": "2026-06-30T00:00:00Z",
            "verifiedAtISO8601": "2026-06-30T00:15:00Z",
            "verifiedByRole": "releaseManager",
            "notes": ["Launch item completed and evidence captured."],
        })
    return {
        "schemaVersion": gate.OPERATIONAL_LAUNCH_SCHEMA,
        "checklistVersion": gate.OPERATIONAL_LAUNCH_CHECKLIST_VERSION,
        "releaseCandidateBuild": build,
        "completedByRole": "releaseManager",
        "summary": {
            "itemCount": len(items),
            "completedRequiredItemCount": len(items),
            "failedRequiredItemCount": 0,
            "artifactBackedItemCount": len(items),
            "expectedEvidenceKindItemCount": len(items),
            "expectedEnvironmentItemCount": len(items),
            "sameBuildItemCount": len(items),
            "verifiedRequiredItemCount": len(items),
            "readinessWarnings": [],
        },
        "items": items,
    }


def write_complete_evidence(root, source_fingerprint="sha256:test-source", git_commit="abc123"):
    root = Path(root)
    (root / gate.PROFESSIONAL_CALIBRATION_PACKET_FILE).write_text(
        json.dumps(calibration_packet_payload()),
        encoding="utf-8",
    )
    payloads = {
        "coach-live-eval-v1.json": complete_live_provider_evidence(
            source_fingerprint,
            git_commit,
        ),
        "coach-chat-conversation-expert-calibration-results-v2.json": (
            complete_professional_calibration_evidence()
        ),
        "coach-real-user-transfer-outcomes-v2.json": complete_real_user_transfer_evidence(),
        "coach-real-device-testflight-qa-v2.json": complete_real_device_testflight_evidence(),
        "coach-operational-launch-checklist-v2.json": complete_operational_launch_evidence(),
    }
    for file_name, payload in payloads.items():
        (root / file_name).write_text(json.dumps(payload), encoding="utf-8")
    (root / gate.READINESS_MANIFEST_FILE).write_text(json.dumps({
        "schemaVersion": gate.READINESS_MANIFEST_SCHEMA,
        "localTargetShapeScore": 85,
        "audit": {
            "score": 100,
            "maximumAllowedScore": 100,
            "localTargetShapeScore": 85,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
            "summary": "All independently sourced evidence contracts passed.",
        },
        "evidence": {"externalEvidenceComplete": True},
        "rows": [{"key": "externalEvidence", "status": "earned"}],
    }), encoding="utf-8")
    (root / "source-coach-fingerprint.txt").write_text(source_fingerprint, encoding="utf-8")
    (root / "source-git-commit.txt").write_text(git_commit, encoding="utf-8")


def successful_privacy_fetch(url):
    return {
        "status": 200,
        "finalURL": url,
        "bodyPreview": "Noum Privacy Policy",
    }


class ReadinessGateTests(unittest.TestCase):
    def test_lists_vision_blockers_as_concrete_evidence_requirements(self):
        readiness = {
            "score": 18,
            "maximumAllowedScore": 20,
            "claim": "localEvaluationSubstrateOnly",
            "blockers": [
                "noLiveProviderTranscriptSweep",
                "noRealDeviceTestFlightVerification",
                "operationalLaunchChecklistIncomplete",
            ],
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                Path("tools/coach-arena/reports/app-path/latest.json"),
                Path(temp_dir),
            )

        self.assertFalse(status["vision"]["productionReady"])
        artifacts = {
            item["blocker"]: item["artifact"]
            for item in status["blockingRequirements"]
        }
        self.assertEqual(
            artifacts["noLiveProviderTranscriptSweep"],
            "coach-live-eval-v1.json",
        )
        self.assertEqual(
            artifacts["noRealDeviceTestFlightVerification"],
            "coach-real-device-testflight-qa-v2.json",
        )
        self.assertEqual(
            artifacts["operationalLaunchChecklistIncomplete"],
            "coach-operational-launch-checklist-v2.json",
        )

    def test_production_ready_requires_score_claim_and_no_blockers(self):
        not_ready = {
            "score": 100,
            "maximumAllowedScore": 100,
            "claim": "localEvaluationSubstrateOnly",
            "blockers": [],
        }
        ready = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }

        self.assertFalse(gate.computed_production_ready(not_ready))
        self.assertTrue(gate.computed_production_ready(ready))

    def test_launch_ready_also_requires_local_app_path_gates(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        report = report_with_readiness(
            readiness,
            traceQualityPasses=False,
        )

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)

            status = gate.build_readiness_status(
                report,
                canonical_report_path(),
                root,
                root,
            )

        self.assertTrue(status["vision"]["productionReady"])
        self.assertFalse(status["launchReady"])
        self.assertEqual(
            [item["label"] for item in status["localBlockingRequirements"]],
            ["traceQualityEvidence"],
        )

    def test_launch_ready_requires_local_target_shape_floor(self):
        readiness = {
            "score": 85,
            "localTargetShapeScore": 84,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
            )

        self.assertTrue(status["vision"]["productionReady"])
        self.assertFalse(status["launchReady"])
        self.assertEqual(status["vision"]["localTargetShapeScore"], 84)
        self.assertEqual(
            [item["label"] for item in status["localBlockingRequirements"]],
            ["localTargetShapeScore"],
        )

    def test_local_target_shape_failures_treat_missing_score_as_not_ready(self):
        failures = gate.local_target_shape_failures({
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        })

        self.assertEqual([item["label"] for item in failures], ["localTargetShapeScore"])
        self.assertIsNone(failures[0]["observed"])

    def test_launch_ready_requires_required_artifacts_and_source_sidecars(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                Path(temp_dir),
            )

        self.assertFalse(status["vision"]["productionReady"])
        self.assertFalse(status["launchReady"])
        self.assertIn(
            "coach-live-eval-v1.json",
            [item["label"] for item in status["artifactBlockingRequirements"]],
        )
        self.assertIn(
            "source-git-commit.txt",
            [item["label"] for item in status["artifactBlockingRequirements"]],
        )

    def test_launch_ready_can_pass_when_all_gates_and_artifacts_are_present(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
            )

        self.assertTrue(status["launchReady"])
        self.assertEqual(status["artifactBlockingRequirements"], [])
        self.assertEqual(status["artifactAudit"]["presentArtifactCount"], 5)
        self.assertEqual(status["artifactAudit"]["presentSourceSidecarCount"], 2)
        self.assertEqual(status["operationalStaticBlockingRequirements"], [])

    def test_launch_ready_rejects_structurally_empty_external_evidence(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        cases = [
            ("coach-real-user-transfer-outcomes-v2.json", "rows"),
            ("coach-real-device-testflight-qa-v2.json", "rows"),
            ("coach-operational-launch-checklist-v2.json", "items"),
        ]
        for file_name, collection_key in cases:
            with self.subTest(file_name=file_name), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                write_static_ops_repo(root)
                write_complete_evidence(root)
                path = root / file_name
                payload = json.loads(path.read_text(encoding="utf-8"))
                payload["summary"] = {}
                payload[collection_key] = []
                path.write_text(json.dumps(payload), encoding="utf-8")

                status = gate.build_readiness_status(
                    report_with_readiness(readiness),
                    canonical_report_path(),
                    root,
                    root,
                )

                self.assertFalse(status["launchReady"])
                invalid = next(
                    item for item in status["artifactAudit"]["invalidArtifacts"]
                    if item["artifact"] == file_name
                )
                self.assertTrue(invalid["contractFailures"])

    def test_external_contracts_reject_smoothed_or_unverifiable_rows(self):
        transfer = complete_real_user_transfer_evidence()
        transfer["rows"][0]["causalityClaims"] = ["Noum caused the outcome."]
        device = complete_real_device_testflight_evidence()
        device["rows"][1]["latencyMs"] = -1
        operational = complete_operational_launch_evidence()
        operational["items"][0]["evidenceKind"] = "screenshot"

        self.assertIn(
            "causalityClaimsPresent",
            gate.real_user_transfer_contract_failures(transfer),
        )
        self.assertIn(
            "aiPromptLatencyOverBudget",
            gate.real_device_testflight_contract_failures(device),
        )
        self.assertTrue(any(
            failure.startswith("evidenceKindMismatch=")
            for failure in gate.operational_launch_contract_failures(operational)
        ))

    def test_launch_ready_rejects_prompt_layer_report_family(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        report = report_with_readiness(readiness)
        report["reportFamily"] = "prompt-layer"
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)

            status = gate.build_readiness_status(
                report,
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        self.assertFalse(status["reportSourceAudit"]["passes"])
        self.assertEqual(
            [item["label"] for item in status["localBlockingRequirements"]],
            ["reportFamily"],
        )

    def test_launch_ready_rejects_diagnostic_app_path_report_path(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        diagnostic_path = gate.ARENA_ROOT / "reports" / "app-path-diagnostic" / "latest.json"
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                diagnostic_path,
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        self.assertFalse(status["reportSourceAudit"]["passes"])
        self.assertEqual(
            [item["label"] for item in status["localBlockingRequirements"]],
            ["reportPath"],
        )

    def test_launch_ready_rejects_placeholder_evidence_sidecars(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            for requirement in gate.EVIDENCE_REQUIREMENTS.values():
                (root / requirement["artifact"]).write_text("{}", encoding="utf-8")
            (root / "source-coach-fingerprint.txt").write_text("sha256:test-source", encoding="utf-8")
            (root / "source-git-commit.txt").write_text("abc123", encoding="utf-8")

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        self.assertEqual(status["artifactAudit"]["presentArtifactCount"], 5)
        self.assertEqual(status["artifactAudit"]["validArtifactContractCount"], 0)
        self.assertEqual(len(status["artifactAudit"]["invalidArtifacts"]), 5)
        self.assertIn(
            "schemaVersionMissing",
            status["artifactBlockingRequirements"][0]["observed"],
        )

    def test_launch_ready_rejects_live_sweep_with_stale_source_sidecars(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(
                root,
                source_fingerprint="sha256:old-source",
                git_commit="old123",
            )
            (root / "source-coach-fingerprint.txt").write_text(
                "sha256:fresh-source",
                encoding="utf-8",
            )
            (root / "source-git-commit.txt").write_text("fresh123", encoding="utf-8")

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        live_artifact = next(
            item for item in status["artifactAudit"]["invalidArtifacts"]
            if item["artifact"] == "coach-live-eval-v1.json"
        )
        self.assertIn("sourceGitCommitMismatch", live_artifact["contractFailures"])
        self.assertIn("sourceCoachFingerprintMismatch", live_artifact["contractFailures"])

    def test_launch_ready_rejects_live_sweep_with_thin_latest_coverage(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)
            live_path = root / "coach-live-eval-v1.json"
            payload = json.loads(live_path.read_text(encoding="utf-8"))
            payload["rows"] = payload["rows"][:10]
            payload["fixtureCount"] = 10
            payload["summary"]["rowCount"] = 10
            live_path.write_text(json.dumps(payload), encoding="utf-8")

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        live_artifact = next(
            item for item in status["artifactAudit"]["invalidArtifacts"]
            if item["artifact"] == "coach-live-eval-v1.json"
        )
        self.assertIn("missingLatestTranscriptCoverage", live_artifact["contractFailures"])
        self.assertTrue(
            any(
                reason.startswith("missingRequiredFixtures=")
                for reason in live_artifact["contractFailures"]
            )
        )

    def test_launch_ready_rejects_live_sweep_with_flat_or_repeated_telemetry(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)
            live_path = root / "coach-live-eval-v1.json"
            payload = json.loads(live_path.read_text(encoding="utf-8"))
            payload["summary"]["assessmentConfidenceDistinctRoundedCount"] = 1
            payload["summary"]["trajectoryCacheHitCount"] = 0
            payload["summary"]["uniqueProofTestHashCount"] = 1
            payload["summary"]["repeatedProofTestHashCount"] = 7
            for row in payload["rows"]:
                row["trajectoryCacheHit"] = False
            for conversation in payload["longFormConversations"]:
                for row in conversation["rows"]:
                    row["trajectoryCacheHit"] = False
            live_path.write_text(json.dumps(payload), encoding="utf-8")

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        live_artifact = next(
            item for item in status["artifactAudit"]["invalidArtifacts"]
            if item["artifact"] == "coach-live-eval-v1.json"
        )
        self.assertIn("flatAssessmentConfidence", live_artifact["contractFailures"])
        self.assertIn("weakProofTestVariety", live_artifact["contractFailures"])
        self.assertTrue(
            any(
                reason.startswith("weakTrajectoryCacheCoverage=")
                for reason in live_artifact["contractFailures"]
            )
        )

    def test_launch_ready_rejects_live_sweep_placeholder_replies(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)
            live_path = root / "coach-live-eval-v1.json"
            payload = json.loads(live_path.read_text(encoding="utf-8"))
            payload["rows"][0]["reply"] = "generic coach reply with concrete evidence"
            live_path.write_text(json.dumps(payload), encoding="utf-8")

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        live_artifact = next(
            item for item in status["artifactAudit"]["invalidArtifacts"]
            if item["artifact"] == "coach-live-eval-v1.json"
        )
        self.assertTrue(
            any(
                reason.startswith("genericLatestTurnReplies=")
                for reason in live_artifact["contractFailures"]
            )
        )

    def test_live_sweep_accepts_warm_cache_coverage_from_long_form_turns(self):
        payload = complete_live_provider_evidence()
        for row in payload["rows"]:
            row["trajectoryCacheHit"] = False

        failures = gate.live_provider_sweep_contract_failures(payload)

        self.assertFalse(
            any(reason.startswith("weakTrajectoryCacheCoverage=") for reason in failures)
        )

    def test_live_sweep_allows_contextual_placeholder_question(self):
        payload = complete_live_provider_evidence()
        payload["longFormConversations"][0]["rows"][0]["reply"] = (
            "Your placeholder ask is specific: name the decision first, then give "
            "one reason and stop so the listener can test the recommendation."
        )

        failures = gate.live_provider_sweep_contract_failures(payload)

        self.assertFalse(
            any(reason.startswith("genericDetailedLongFormReplies=") for reason in failures)
        )

    def test_live_sweep_contract_accepts_real_swift_producer_shape(self):
        payload = complete_live_provider_evidence()

        failures = gate.live_provider_sweep_contract_failures(payload)

        self.assertEqual(failures, [])
        self.assertNotIn(
            "sourceFreshnessFailures",
            gate.EVIDENCE_REQUIREMENTS["noLiveProviderTranscriptSweep"]["requiredTopLevelKeys"],
        )

    def test_live_sweep_contract_rejects_boolean_numeric_telemetry(self):
        payload = complete_live_provider_evidence()
        payload["rows"][0]["timeToFirstVisibleTokenMs"] = True
        payload["rows"][0]["assessmentConfidence"] = True

        failures = gate.live_provider_sweep_contract_failures(payload)

        self.assertTrue(any(
            reason.startswith("latestTurnReadinessTelemetryFailures=")
            for reason in failures
        ))

    def test_live_sweep_contract_rejects_forged_one_turn_long_forms(self):
        payload = complete_live_provider_evidence()
        for conversation in payload["longFormConversations"]:
            conversation["rows"] = conversation["rows"][:1]
            conversation["expectedTurnCount"] = 1
            conversation["observedTurnCount"] = 1

        failures = gate.live_provider_sweep_contract_failures(payload)

        self.assertTrue(any(
            reason.startswith("malformedDetailedLongFormConversations=")
            for reason in failures
        ))

    def test_live_sweep_contract_rejects_unexpected_long_form_ids(self):
        payload = complete_live_provider_evidence()
        extra_id = "unexpected-long-form-conversation"
        payload["longFormConversations"].append(
            live_long_form_conversation(extra_id, 0)
        )
        payload["longFormConversationIDsPassingProductionFloor"].append(extra_id)
        payload["longFormConversationCount"] += 1

        failures = gate.live_provider_sweep_contract_failures(payload)

        self.assertTrue(any(
            reason.startswith("unexpectedLongFormConversationIDs=")
            for reason in failures
        ))
        self.assertTrue(any(
            reason.startswith("unexpectedDetailedLongFormConversations=")
            for reason in failures
        ))

    def test_live_sweep_contract_fails_closed_on_malformed_summary_numbers(self):
        payload = complete_live_provider_evidence()
        payload["summary"]["productionFloorFailureCount"] = "0"
        payload["summary"]["assessmentConfidenceDistinctRoundedCount"] = True

        failures = gate.live_provider_sweep_contract_failures(payload)

        self.assertTrue(any(
            reason.startswith("invalidSummaryTelemetry=")
            for reason in failures
        ))
        self.assertIn("productionFloorFailures", failures)
        self.assertIn("flatAssessmentConfidence", failures)

    def test_professional_calibration_fails_closed_on_malformed_numbers(self):
        payload = complete_professional_calibration_evidence()
        payload["summary"]["minimumOverallUsefulness"] = "4"
        payload["summary"]["passingCalibrationCount"] = True
        payload["rows"][0]["humanCoachReferenceCount"] = True
        context = {
            "requiredConversationIDs": CALIBRATION_CONVERSATION_IDS,
            "requiredReviewsPerConversation": gate.PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION,
            "requiredReviewCount": gate.PROFESSIONAL_CALIBRATION_MIN_REVIEW_COUNT,
            "sourcePacketFingerprint": CALIBRATION_PACKET_FINGERPRINT,
            "packetFailures": [],
        }

        failures = gate.professional_calibration_contract_failures(payload, context)

        self.assertTrue(any(
            reason.startswith("invalidSummaryTelemetry=")
            for reason in failures
        ))
        self.assertIn("rowCalibrationFloorFailures", failures)
        self.assertIn("overallUsefulnessBelowFloor", failures)

    def test_artifact_gate_rejects_empty_source_sidecars(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_complete_evidence(root)
            (root / "source-git-commit.txt").write_text("", encoding="utf-8")
            (root / "source-coach-fingerprint.txt").write_text("", encoding="utf-8")

            audit = gate.evidence_artifact_audit(root, {"blockers": []})
            failures = gate.artifact_gate_failures(audit)

        self.assertEqual(
            sorted(item["label"] for item in failures),
            ["source-coach-fingerprint.txt", "source-git-commit.txt"],
        )
        self.assertTrue(all(item["observed"] == "empty" for item in failures))

    def test_launch_ready_rejects_professional_calibration_stale_packet_fingerprint(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)
            calibration_path = root / "coach-chat-conversation-expert-calibration-results-v2.json"
            payload = json.loads(calibration_path.read_text(encoding="utf-8"))
            payload["sourcePacketFingerprint"] = "fnv1a64:stale"
            calibration_path.write_text(json.dumps(payload), encoding="utf-8")

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        calibration = next(
            item for item in status["artifactAudit"]["invalidArtifacts"]
            if item["artifact"] == "coach-chat-conversation-expert-calibration-results-v2.json"
        )
        self.assertIn("sourcePacketFingerprintMismatch", calibration["contractFailures"])

    def test_launch_ready_rejects_professional_calibration_with_single_review_coverage(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)
            calibration_path = root / "coach-chat-conversation-expert-calibration-results-v2.json"
            payload = json.loads(calibration_path.read_text(encoding="utf-8"))
            payload["rows"] = payload["rows"][::2]
            payload["reviewCount"] = len(payload["rows"])
            payload["summary"]["rowCount"] = len(payload["rows"])
            payload["summary"]["completedReviewCount"] = len(payload["rows"])
            payload["summary"]["passingCalibrationCount"] = len(payload["rows"])
            payload["summary"]["wouldUseWithClientCount"] = len(payload["rows"])
            calibration_path.write_text(json.dumps(payload), encoding="utf-8")

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        calibration = next(
            item for item in status["artifactAudit"]["invalidArtifacts"]
            if item["artifact"] == "coach-chat-conversation-expert-calibration-results-v2.json"
        )
        self.assertIn("fewerThanRequiredReviews", calibration["contractFailures"])
        self.assertIn("missingFullConversationCoverage", calibration["contractFailures"])
        self.assertTrue(
            any(
                reason.startswith("insufficientReviewsPerConversation=")
                for reason in calibration["contractFailures"]
            )
        )

    def test_launch_ready_rejects_professional_calibration_with_single_reviewer(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)
            calibration_path = root / "coach-chat-conversation-expert-calibration-results-v2.json"
            payload = json.loads(calibration_path.read_text(encoding="utf-8"))
            for row in payload["rows"]:
                row["reviewerID"] = "coach-reviewer-1"
            payload["summary"]["reviewerCount"] = 1
            calibration_path.write_text(json.dumps(payload), encoding="utf-8")

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        calibration = next(
            item for item in status["artifactAudit"]["invalidArtifacts"]
            if item["artifact"] == "coach-chat-conversation-expert-calibration-results-v2.json"
        )
        self.assertIn("duplicateConversationReviewerPairs", calibration["contractFailures"])
        self.assertIn("missingProfessionalReviewer", calibration["contractFailures"])
        self.assertTrue(
            any(
                reason.startswith("insufficientReviewerDiversity=")
                for reason in calibration["contractFailures"]
            )
        )

    def test_launch_ready_rejects_professional_calibration_unsafe_or_low_rows(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)
            calibration_path = root / "coach-chat-conversation-expert-calibration-results-v2.json"
            payload = json.loads(calibration_path.read_text(encoding="utf-8"))
            payload["rows"][0]["calibrationDecision"] = "unsafeOrUnready"
            payload["rows"][0]["wouldUseWithClient"] = False
            payload["rows"][0]["ratings"]["overallUsefulness"] = 3
            payload["rows"][0]["humanCoachReferenceCount"] = 0
            payload["rows"][0]["overclaimNotes"] = ["Too certain."]
            payload["summary"]["passingCalibrationCount"] = len(payload["rows"]) - 1
            payload["summary"]["wouldUseWithClientCount"] = len(payload["rows"]) - 1
            payload["summary"]["unsafeOrUnreadyCount"] = 1
            payload["summary"]["minimumOverallUsefulness"] = 3
            payload["summary"]["averageOverallUsefulness"] = 3.99
            calibration_path.write_text(json.dumps(payload), encoding="utf-8")

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        calibration = next(
            item for item in status["artifactAudit"]["invalidArtifacts"]
            if item["artifact"] == "coach-chat-conversation-expert-calibration-results-v2.json"
        )
        self.assertIn("unsafeOrUnreadyRows", calibration["contractFailures"])
        self.assertIn("rowCalibrationFloorFailures", calibration["contractFailures"])
        self.assertIn("insufficientPassingCalibrationRows", calibration["contractFailures"])
        self.assertIn("overallUsefulnessBelowFloor", calibration["contractFailures"])

    def test_launch_ready_rejects_forged_small_professional_calibration_packet(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)
            small_ids = CALIBRATION_CONVERSATION_IDS[:3]
            (root / gate.PROFESSIONAL_CALIBRATION_PACKET_FILE).write_text(
                json.dumps(calibration_packet_payload(conversation_ids=small_ids)),
                encoding="utf-8",
            )
            calibration_path = root / "coach-chat-conversation-expert-calibration-results-v2.json"
            calibration_path.write_text(
                json.dumps(complete_professional_calibration_evidence(conversation_ids=small_ids)),
                encoding="utf-8",
            )

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        calibration = next(
            item for item in status["artifactAudit"]["invalidArtifacts"]
            if item["artifact"] == "coach-chat-conversation-expert-calibration-results-v2.json"
        )
        self.assertIn("sourcePacketBelowConversationFloor", calibration["contractFailures"])
        self.assertIn("sourcePacketBelowReviewFloor", calibration["contractFailures"])
        self.assertIn("fewerThanRequiredReviews", calibration["contractFailures"])

    def test_launch_ready_requires_report_source_freshness_when_trace_values_exist(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        report = report_with_readiness(readiness)
        report["results"] = [{
            "trace": {
                "sourceFingerprint": "sha256:old-source",
                "gitCommit": "abc123",
            }
        }]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(
                root,
                source_fingerprint="sha256:new-source",
                git_commit="abc123",
            )

            status = gate.build_readiness_status(
                report,
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        self.assertFalse(status["sourceFreshnessAudit"]["passes"])
        self.assertEqual(
            [item["label"] for item in status["localBlockingRequirements"]],
            ["sourceCoachFingerprint"],
        )
        self.assertEqual(
            status["localBlockingRequirements"][0]["reportValues"],
            ["sha256:old-source"],
        )

    def test_source_freshness_passes_when_report_matches_staged_sidecars(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        report = report_with_readiness(readiness)
        report["results"] = [{
            "trace": {
                "sourceFingerprint": "sha256:test-source",
                "gitCommit": "abc123",
            }
        }]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)

            status = gate.build_readiness_status(
                report,
                canonical_report_path(),
                root,
                root,
            )

        self.assertTrue(status["launchReady"])
        self.assertTrue(status["sourceFreshnessAudit"]["passes"])
        self.assertEqual(status["localBlockingRequirements"], [])

    def test_launch_ready_requires_report_source_to_match_current_checkout(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        report = report_with_readiness(readiness)
        report["results"] = [{
            "trace": {
                "sourceFingerprint": "sha256:old-source",
                "gitCommit": "abc123",
            }
        }]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_coach_source(root, "current coach source")
            current_fingerprint = gate.coach_source_fingerprint(root)
            write_complete_evidence(
                root,
                source_fingerprint="sha256:old-source",
                git_commit="abc123",
            )

            status = gate.build_readiness_status(
                report,
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        self.assertFalse(status["sourceFreshnessAudit"]["passes"])
        self.assertEqual(
            [item["label"] for item in status["localBlockingRequirements"]],
            ["currentCoachFingerprint"],
        )
        self.assertEqual(
            status["localBlockingRequirements"][0]["current"],
            current_fingerprint,
        )
        self.assertEqual(
            status["localBlockingRequirements"][0]["mismatchedAgainst"],
            ["sidecar", "report"],
        )

    def test_source_freshness_passes_when_current_checkout_matches_report(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_coach_source(root, "current coach source")
            current_fingerprint = gate.coach_source_fingerprint(root)
            write_complete_evidence(
                root,
                source_fingerprint=current_fingerprint,
                git_commit="abc123",
            )
            report = report_with_readiness(readiness)
            report["results"] = [{
                "trace": {
                    "sourceFingerprint": current_fingerprint,
                    "gitCommit": "abc123",
                }
            }]

            status = gate.build_readiness_status(
                report,
                canonical_report_path(),
                root,
                root,
            )

        self.assertTrue(status["launchReady"])
        self.assertTrue(status["sourceFreshnessAudit"]["passes"])
        self.assertEqual(status["sourceFreshnessAudit"]["currentGitCommit"], None)
        self.assertEqual(status["localBlockingRequirements"], [])

    def test_source_freshness_accepts_clean_report_only_descendant(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_coach_source(root, "current coach source")
            current_fingerprint = gate.coach_source_fingerprint(root)
            write_complete_evidence(
                root,
                source_fingerprint=current_fingerprint,
                git_commit="abc123",
            )
            report = report_with_readiness(readiness)
            report["results"] = [{
                "trace": {
                    "sourceFingerprint": current_fingerprint,
                    "gitCommit": "abc123",
                }
            }]

            with (
                mock.patch.object(gate, "current_git_commit", return_value="def567"),
                mock.patch.object(gate, "current_dirty_coach_source_files", return_value=[]),
                mock.patch.object(gate, "git_commit_is_ancestor", return_value=True),
            ):
                status = gate.build_readiness_status(
                    report,
                    canonical_report_path(),
                    root,
                    root,
                )

        self.assertTrue(status["launchReady"])
        self.assertTrue(status["sourceFreshnessAudit"]["passes"])
        self.assertEqual(
            status["sourceFreshnessAudit"]["cleanAncestorCommitsAccepted"],
            ["abc123"],
        )

    def test_source_freshness_rejects_unrelated_matching_commit(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_coach_source(root, "current coach source")
            current_fingerprint = gate.coach_source_fingerprint(root)
            write_complete_evidence(
                root,
                source_fingerprint=current_fingerprint,
                git_commit="abc123",
            )
            report = report_with_readiness(readiness)
            report["results"] = [{
                "trace": {
                    "sourceFingerprint": current_fingerprint,
                    "gitCommit": "abc123",
                }
            }]

            with (
                mock.patch.object(gate, "current_git_commit", return_value="def567"),
                mock.patch.object(gate, "current_dirty_coach_source_files", return_value=[]),
                mock.patch.object(gate, "git_commit_is_ancestor", return_value=False),
            ):
                status = gate.build_readiness_status(
                    report,
                    canonical_report_path(),
                    root,
                    root,
                )

        self.assertFalse(status["launchReady"])
        self.assertFalse(status["sourceFreshnessAudit"]["passes"])
        self.assertEqual(
            [item["label"] for item in status["localBlockingRequirements"]],
            ["currentGitCommit"],
        )

    def test_launch_ready_requires_operational_static_preflight(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_complete_evidence(root)

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
            )

        self.assertFalse(status["launchReady"])
        self.assertIn(
            "firebase.json",
            [item["label"] for item in status["operationalStaticBlockingRequirements"]],
        )

    def test_local_gate_failures_treat_missing_values_as_not_ready(self):
        failures = gate.local_gate_failures({
            "scoreThresholdsPass": True,
            "traceQualityPasses": True,
        })

        self.assertEqual(
            [item["label"] for item in failures],
            ["realPipelineEvidence"],
        )
        self.assertIsNone(failures[0]["observed"])

    def test_artifact_audit_reports_required_sidecar_presence_without_earning_gate(self):
        readiness = {
            "score": 18,
            "maximumAllowedScore": 20,
            "claim": "localEvaluationSubstrateOnly",
            "blockers": [
                "noLiveProviderTranscriptSweep",
                "noProfessionalCoachCalibration",
            ],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "coach-live-eval-v1.json").write_text("{}", encoding="utf-8")
            (root / "source-git-commit.txt").write_text("abc123", encoding="utf-8")

            audit = gate.evidence_artifact_audit(root, readiness)

        self.assertTrue(audit["dumpDirExists"])
        self.assertEqual(audit["presentArtifactCount"], 1)
        self.assertEqual(audit["validArtifactContractCount"], 0)
        self.assertEqual(audit["missingArtifactCount"], 4)
        self.assertEqual(
            audit["invalidArtifacts"][0]["contractFailures"][0],
            "schemaVersionMissing",
        )
        self.assertEqual(audit["presentSourceSidecarCount"], 1)
        live_artifact = next(
            item for item in audit["requiredArtifacts"]
            if item["artifact"] == "coach-live-eval-v1.json"
        )
        self.assertTrue(live_artifact["present"])
        self.assertTrue(live_artifact["presentButStillBlocked"])
        self.assertIn("structured JSON/schema", audit["validationBoundary"])

    def test_status_includes_evidence_directory_audit(self):
        readiness = {
            "score": 18,
            "maximumAllowedScore": 20,
            "claim": "localEvaluationSubstrateOnly",
            "blockers": ["noProfessionalCoachCalibration"],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                Path(temp_dir),
            )

        self.assertEqual(status["artifactAudit"]["requiredArtifactCount"], 5)
        self.assertEqual(status["artifactAudit"]["presentArtifactCount"], 0)
        self.assertEqual(
            status["artifactAudit"]["missingArtifacts"][0]["artifact"],
            "coach-live-eval-v1.json",
        )

    def test_operational_static_preflight_passes_minimal_release_config(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)

            preflight = gate.operational_static_preflight(root)

        self.assertEqual(preflight["failureCount"], 0)
        self.assertEqual(preflight["passCount"], preflight["checkCount"])
        self.assertIn("Static ops preflight", preflight["validationBoundary"])

    def test_operational_static_preflight_accepts_display_name_only_profile_helper(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            rules_path = root / "firestore.rules"
            rules = rules_path.read_text(encoding="utf-8")
            rules = rules.replace(
                """    match /profiles_public/{accountID} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
        && request.auth.uid == accountID
        && request.resource.data.keys().hasOnly(['accountID']);
    }
""",
                """    function updatesOnlyDisplayName(accountID) {
      return request.auth != null
        && request.auth.uid == accountID
        && request.resource.data.diff(resource.data)
             .affectedKeys().hasOnly(['displayName']);
    }
    match /profiles_public/{accountID} {
      allow get: if request.auth != null;
      allow list, create, delete: if false;
      allow update: if updatesOnlyDisplayName(accountID);
    }
""",
            )
            rules_path.write_text(rules, encoding="utf-8")

            preflight = gate.operational_static_preflight(root)

        self.assertNotIn(
            "firestoreRulesPublicProfileWriteGuard",
            [item["key"] for item in preflight["failures"]],
        )

    def test_operational_static_preflight_accepts_bounded_private_user_paths(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            rules_path = root / "firestore.rules"
            rules = rules_path.read_text(encoding="utf-8")
            rules = rules.replace(
                """    match /users/{accountID}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == accountID;
    }
""",
                """    function isOwner(accountID) {
      return request.auth != null && request.auth.uid == accountID;
    }
    function isWritableOwner(accountID) {
      return isOwner(accountID);
    }
    match /users/{accountID} {
      allow read, write: if isWritableOwner(accountID);
      match /profile/{profileID} { allow read, write: if isWritableOwner(accountID); }
      match /progress/{progressID} { allow read, write: if isWritableOwner(accountID); }
      match /sessions/{sessionID} { allow read, write: if isWritableOwner(accountID); }
      match /recommendations/{recommendationID} { allow read, write: if isWritableOwner(accountID); }
    }
""",
            )
            rules_path.write_text(rules, encoding="utf-8")

            preflight = gate.operational_static_preflight(root)

        self.assertNotIn(
            "firestoreRulesPrivateUsers",
            [item["key"] for item in preflight["failures"]],
        )

    def test_operational_static_preflight_rejects_unsafe_client_config_membership(self):
        mutations = {
            "AIConfigBundled": ("            AIConfig.plist,\n", ""),
            "BackendConfigBundled": ("            BackendConfig.plist,\n", ""),
            "TranscribeBundled": ("            Transcribe.plist,\n", ""),
            "TranscriptionProvidersBundled": (
                "            TranscriptionProviders.plist,\n",
                "",
            ),
            "GoogleConfigExcluded": (
                "            AIConfig.plist,\n",
                "            AIConfig.plist,\n            GoogleService-Info.plist,\n",
            ),
        }
        for case, (old, new) in mutations.items():
            with self.subTest(case=case), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                write_static_ops_repo(root)
                project_path = root / "Noum.xcodeproj/project.pbxproj"
                project = project_path.read_text(encoding="utf-8")
                project_path.write_text(project.replace(old, new), encoding="utf-8")

                preflight = gate.operational_static_preflight(root)

                self.assertIn(
                    "mainTargetClientSecretBoundary",
                    [item["key"] for item in preflight["failures"]],
                )

    def test_operational_static_preflight_rejects_unsafe_ai_config_repository_boundary(self):
        mutations = {
            "missingGitignoreEntry": lambda root: (root / ".gitignore").write_text(
                "# local config missing\n",
                encoding="utf-8",
            ),
            "missingExample": lambda root: (root / "Noum/AIConfig.plist.example").unlink(),
        }
        for case, mutate in mutations.items():
            with self.subTest(case=case), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                write_static_ops_repo(root)
                mutate(root)

                preflight = gate.operational_static_preflight(root)

                self.assertIn(
                    "aiConfigRepositorySecretBoundary",
                    [item["key"] for item in preflight["failures"]],
                )

    def test_operational_static_preflight_requires_user_content_privacy_disclosures(self):
        required_types = {
            "NSPrivacyCollectedDataTypeOtherUserContent",
            "NSPrivacyCollectedDataTypePhotosorVideos",
        }
        for missing_type in required_types:
            with self.subTest(missing_type=missing_type), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                write_static_ops_repo(root)
                manifest_path = root / "Noum/PrivacyInfo.xcprivacy"
                with manifest_path.open("rb") as manifest_file:
                    manifest = plistlib.load(manifest_file)
                manifest["NSPrivacyCollectedDataTypes"] = [
                    item for item in manifest["NSPrivacyCollectedDataTypes"]
                    if item["NSPrivacyCollectedDataType"] != missing_type
                ]
                manifest_path.write_bytes(plistlib.dumps(manifest))

                preflight = gate.operational_static_preflight(root)

                self.assertIn(
                    "privacyManifestUserContentDisclosure",
                    [item["key"] for item in preflight["failures"]],
                )

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            (root / "Noum/PrivacyInfo.xcprivacy").write_bytes(
                plistlib.dumps(["not", "a", "dictionary"])
            )

            preflight = gate.operational_static_preflight(root)

            failure = next(
                item for item in preflight["failures"]
                if item["key"] == "privacyManifestUserContentDisclosure"
            )
            self.assertEqual(failure["observed"], "invalidTopLevelType")

    def test_operational_static_preflight_flags_missing_privacy_rewrite(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            config = json.loads((root / "firebase.json").read_text(encoding="utf-8"))
            config["hosting"]["rewrites"] = []
            (root / "firebase.json").write_text(json.dumps(config), encoding="utf-8")

            preflight = gate.operational_static_preflight(root)

        self.assertIn(
            "hostingPrivacyRewrite",
            [item["key"] for item in preflight["failures"]],
        )

    def test_operational_live_probe_passes_hosted_privacy_content(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)

            probe = gate.operational_live_probe(root, successful_privacy_fetch)

        self.assertEqual(probe["failureCount"], 0)
        self.assertEqual(probe["passCount"], probe["checkCount"])
        self.assertIn("Live ops probe", probe["validationBoundary"])

    def test_operational_live_probe_flags_privacy_url_404(self):
        def fetch_404(url):
            raise gate.urllib.error.HTTPError(url, 404, "Not Found", None, None)

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)

            probe = gate.operational_live_probe(root, fetch_404)

        self.assertEqual(probe["failureCount"], 2)
        self.assertEqual(
            [item["key"] for item in probe["failures"]],
            ["privacyURLHTTP", "privacyURLContent"],
        )
        self.assertEqual(probe["failures"][0]["observed"], 404)

    def test_live_probe_blocks_launch_ready_when_enabled(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }

        def fetch_404(url):
            raise gate.urllib.error.HTTPError(url, 404, "Not Found", None, None)

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
                probe_live=True,
                fetch_url=fetch_404,
            )

        self.assertFalse(status["launchReady"])
        self.assertEqual(status["vision"]["productionReady"], True)
        self.assertEqual(
            [item["label"] for item in status["operationalLiveBlockingRequirements"]],
            ["privacyURLHTTP", "privacyURLContent"],
        )

    def test_live_probe_can_pass_with_all_other_launch_gates(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)

            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
                probe_live=True,
                fetch_url=successful_privacy_fetch,
            )

        self.assertTrue(status["launchReady"])
        self.assertEqual(status["operationalLiveBlockingRequirements"], [])
        self.assertEqual(status["operationalLiveProbe"]["failureCount"], 0)

    def test_markdown_names_maestro_as_smoke_not_launch_proof(self):
        readiness = {
            "score": 18,
            "maximumAllowedScore": 20,
            "claim": "localEvaluationSubstrateOnly",
            "blockers": ["noRealDeviceTestFlightVerification"],
        }
        status = gate.build_readiness_status(report_with_readiness(readiness), canonical_report_path())

        markdown = gate.render_markdown(status)

        self.assertIn("maestro/chat_smoke.yaml", markdown)
        self.assertIn("maestro/chat_reject_smoke.yaml", markdown)
        self.assertIn("Not launch proof", markdown)
        self.assertIn("coach-real-device-testflight-qa-v2.json", markdown)
        self.assertIn("## Artifact Gate Failures", markdown)
        self.assertIn("## Evidence Directory", markdown)
        self.assertIn("## Operational Static Preflight", markdown)
        self.assertIn("Python performs structured JSON/schema", markdown)

    def test_markdown_includes_live_probe_when_enabled(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_static_ops_repo(root)
            write_complete_evidence(root)
            status = gate.build_readiness_status(
                report_with_readiness(readiness),
                canonical_report_path(),
                root,
                root,
                probe_live=True,
                fetch_url=successful_privacy_fetch,
            )

        markdown = gate.render_markdown(status)

        self.assertIn("## Operational Live Probe", markdown)
        self.assertIn("https://noum-d0b6f.web.app/privacy", markdown)

    def test_markdown_names_local_gate_failures(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        status = gate.build_readiness_status(
            report_with_readiness(readiness, realPipelineEvidencePasses=False),
            canonical_report_path(),
        )

        markdown = gate.render_markdown(status)

        self.assertIn("Launch gate ready: `False`", markdown)
        self.assertIn("Local target-shape score: `85/100`", markdown)
        self.assertIn("## Local Gate Failures", markdown)
        self.assertIn("realPipelineEvidence", markdown)

    def test_cli_exits_nonzero_when_vision_gate_is_not_ready(self):
        readiness = {
            "score": 18,
            "maximumAllowedScore": 20,
            "claim": "localEvaluationSubstrateOnly",
            "blockers": ["noProfessionalCoachCalibration"],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            report_path = Path(temp_dir) / "latest.json"
            report_path.write_text(
                json.dumps(report_with_readiness(readiness)),
                encoding="utf-8",
            )

            with redirect_stdout(StringIO()):
                exit_code = gate.main(["--report", str(report_path), "--json"])

        self.assertEqual(exit_code, 1)

    def test_cli_exits_nonzero_when_local_gate_is_not_ready(self):
        readiness = {
            "score": 85,
            "maximumAllowedScore": 100,
            "claim": "productionReadyEvidenceAvailable",
            "blockers": [],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            report_path = Path(temp_dir) / "latest.json"
            report_path.write_text(
                json.dumps(
                    report_with_readiness(readiness, scoreThresholdsPass=False)
                ),
                encoding="utf-8",
            )

            with redirect_stdout(StringIO()):
                exit_code = gate.main(["--report", str(report_path), "--json"])

        self.assertEqual(exit_code, 1)


if __name__ == "__main__":
    unittest.main()
