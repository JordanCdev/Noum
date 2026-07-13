import hashlib
import importlib.util
import io
import json
import shutil
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace


TOOL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOL_ROOT.parents[1]
SPEC = importlib.util.spec_from_file_location(
    "release_evidence_under_test",
    TOOL_ROOT / "release_evidence.py",
)
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


FIXTURE_TIME = "2026-07-13T12:00:00Z"


def write_json(path, payload):
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def fixture_packet():
    conversation_ids = [
        f"TEST-ONLY-calibration-conversation-{index:02d}"
        for index in range(release.GATE.PROFESSIONAL_CALIBRATION_MIN_CONVERSATION_COUNT)
    ]
    return {
        "schemaVersion": release.GATE.PROFESSIONAL_CALIBRATION_PACKET_SCHEMA,
        "rubricVersion": release.GATE.PROFESSIONAL_CALIBRATION_RUBRIC,
        "sourceCorpusFingerprint": "fnv1a64:TEST-ONLY-calibration-packet",
        "conversationCount": len(conversation_ids),
        "requiredIndependentReviewsPerConversation": 2,
        "requiredReviewCount": len(conversation_ids) * 2,
        "rows": [
            {
                "conversationID": conversation_id,
                "sourceFixtureID": f"TEST-ONLY-fixture-{index:02d}",
                "turns": [],
            }
            for index, conversation_id in enumerate(conversation_ids)
        ],
    }


def make_source_dump(root):
    root.mkdir(parents=True, exist_ok=True)
    current = release.current_source_binding(REPO_ROOT)
    (root / "source-git-commit.txt").write_text(
        current["sourceGitCommit"], encoding="utf-8"
    )
    (root / "source-coach-fingerprint.txt").write_text(
        current["sourceCoachFingerprint"], encoding="utf-8"
    )
    write_json(root / release.PACKET_FILE, fixture_packet())


def init_run(run_dir, source_dump):
    with redirect_stdout(io.StringIO()):
        release.initialize_run(SimpleNamespace(
            run_dir=str(run_dir),
            source_dump=str(source_dump),
            repo_root=str(REPO_ROOT),
            initialized_by_id="TEST-ONLY-run-initializer",
            initialized_by_role="testFixtureBuilder",
        ))


def add_attachment(run_dir, manifest, evidence_id, kind, verified_by="TEST-ONLY-verifier"):
    attachments = run_dir / "attachments"
    path = attachments / f"{evidence_id}.txt"
    path.write_text(
        f"TEST FIXTURE ONLY — {evidence_id} — never production evidence\n",
        encoding="utf-8",
    )
    entry = {
        "id": evidence_id,
        "path": str(path.relative_to(run_dir)),
        "kind": kind,
        "sha256": release.sha256_file(path),
        "capturedAtISO8601": FIXTURE_TIME,
        "verifiedByID": verified_by,
        "containsPersonalData": False,
        "accessControlReference": "",
    }
    manifest["evidenceIndex"].append(entry)
    return f"evidence://{evidence_id}"


def fill_complete_fixture(run_dir):
    manifest_path = run_dir / release.RUN_MANIFEST_FILE
    manifest = release.read_json(manifest_path)

    approval_ref = add_attachment(
        run_dir, manifest, "promotion-approval", "releaseEvidencePromotionApproval"
    )
    manifest["promotionApproval"] = {
        "approvedByID": "TEST-ONLY-release-approver",
        "approvedByRole": "releaseManager",
        "approvedAtISO8601": FIXTURE_TIME,
        "approvalReference": approval_ref,
        "attestsEvidenceIsExternalOrOperational": True,
        "attestsNoSyntheticFixtureWasUsed": True,
    }

    calibration_path = run_dir / release.MANAGED_ARTIFACTS["professionalCalibration"][0]
    calibration = release.read_json(calibration_path)
    calibration["templateStatus"] = "COLLECTED_EXTERNAL_EVIDENCE"
    calibration["collectionAttestation"] = {
        "coordinatorID": "TEST-ONLY-calibration-coordinator",
        "coordinatorRole": "calibrationCoordinator",
        "blindAssignmentReference": add_attachment(
            run_dir, manifest, "calibration-blind-assignment", "blindAssignment"
        ),
        "attestationReference": add_attachment(
            run_dir, manifest, "calibration-collection-attestation",
            "professionalCollectionAttestation",
        ),
        "attestedAtISO8601": FIXTURE_TIME,
        "attestsReviewsWereIndependentAndBlinded": True,
        "attestsNoReviewerWasOnTheNoumProductTeam": True,
    }
    calibration["reviewerAttestations"] = []
    reviewer_ids = ["TEST-ONLY-reviewer-a", "TEST-ONLY-reviewer-b"]
    for reviewer_id in reviewer_ids:
        slug = reviewer_id.lower()
        calibration["reviewerAttestations"].append({
            "reviewerID": reviewer_id,
            "professionalRole": "professionalCommunicationCoach",
            "qualificationsReference": add_attachment(
                run_dir, manifest, f"{slug}-qualification", "professionalQualification"
            ),
            "independenceAttestationReference": add_attachment(
                run_dir, manifest, f"{slug}-independence",
                "professionalIndependenceAttestation",
            ),
            "attestedAtISO8601": FIXTURE_TIME,
            "independentFromNoumProductTeam": True,
            "reviewedBlind": True,
            "hasUndisclosedConflictOfInterest": False,
        })
    for row in calibration["rows"]:
        row["reviewerID"] = reviewer_ids[row["reviewSlot"] - 1]
        row["calibrationDecision"] = "roughTie"
        row["wouldUseWithClient"] = True
        row["ratings"] = {key: 4 for key in [
            "diagnosis", "caseFormulation", "intervention", "adaptation",
            "perceptionHonesty", "transferSetup", "trustRepair", "overallUsefulness",
        ]}
        row["humanCoachReferenceCount"] = 1
        row["humanCoachReference"] = [{
            "turnIndex": 0,
            "idealCoachMove": "TEST-ONLY reference move for structural validation.",
            "evidenceUsed": ["TEST-ONLY packet turn"],
            "uncertainty": "TEST-ONLY uncertainty statement.",
        }]
        row["overclaimNotes"] = []
        row["revisionNotes"] = []
    calibration["summary"]["readinessWarnings"] = []
    release.summarize_professional(calibration)
    write_json(calibration_path, calibration)

    transfer_path = run_dir / release.MANAGED_ARTIFACTS["realUserTransfer"][0]
    transfer = release.read_json(transfer_path)
    transfer["templateStatus"] = "COLLECTED_EXTERNAL_EVIDENCE"
    transfer["protocolRegistrationReference"] = add_attachment(
        run_dir, manifest, "transfer-protocol", "registeredProtocol"
    )
    transfer["analysisPlanReference"] = add_attachment(
        run_dir, manifest, "transfer-analysis-plan", "registeredAnalysisPlan"
    )
    transfer["benchmarkReference"] = add_attachment(
        run_dir, manifest, "transfer-benchmark", "registeredBenchmark"
    )
    transfer["cohortDescription"] = "TEST-ONLY closed-beta fixture cohort"
    study_refs = {
        "attestationReference": ("transfer-study-attestation", "transferStudyAttestation"),
        "participantConsentLogReference": ("transfer-consent-log", "participantConsentLog"),
        "withdrawalLogReference": ("transfer-withdrawal-log", "withdrawalLog"),
        "exclusionLogReference": ("transfer-exclusion-log", "exclusionLog"),
        "adverseOutcomeLogReference": ("transfer-adverse-log", "adverseOutcomeLog"),
    }
    transfer["studyAttestation"] = {
        "principalInvestigatorID": "TEST-ONLY-principal-investigator",
        "analystID": "TEST-ONLY-independent-analyst",
        "attestedAtISO8601": FIXTURE_TIME,
        "attestsCompleteEnrollmentAccounting": True,
        "attestsWithdrawalsAndExclusionsWereRetained": True,
        "attestsNegativeAndAdverseOutcomesWereRetained": True,
    }
    for field, (evidence_id, kind) in study_refs.items():
        transfer["studyAttestation"][field] = add_attachment(
            run_dir, manifest, evidence_id, kind
        )
    transfer["enrollment"] = {
        "enrolledUserCount": 12,
        "completedUserCount": 10,
        "withdrawnUserCount": 1,
        "excludedUserCount": 1,
        "exclusionLogReference": transfer["studyAttestation"]["exclusionLogReference"],
    }
    categories = ["presentation", "interview", "leadership", "conflict", "networking"]
    transfer["rows"] = []
    for index in range(12):
        outcome_id = f"TEST-ONLY-outcome-{index}"
        row = {
            "outcomeID": outcome_id,
            "userIDHash": "sha256:" + hashlib.sha256(
                f"TEST-ONLY-user-{index % 10}".encode("utf-8")
            ).hexdigest(),
            "momentCategory": categories[index % len(categories)],
            "interventionID": f"TEST-ONLY-intervention-{index}",
            "realWorldMomentOccurred": True,
            "followUpCompleted": True,
            "linkedCoachInterventionCount": 1,
            "daysSinceFirstNoumSession": 14 + index,
            "followUpDelayHours": 36 + index,
            "preMomentConfidence": 2,
            "postMomentConfidence": 3,
            "positiveTransferReported": index < 9,
            "audienceResponseEvidenceCollected": True,
            "adverseOutcomeReported": False,
            "adverseOutcomeResolved": False,
            "adverseOutcomeFollowUpReference": "",
            "causalityClaims": [],
            "notes": ["TEST FIXTURE ONLY"],
        }
        for field, kind in {
            "interventionEvidenceReference": "coachInterventionRecord",
            "momentEvidenceReference": "realWorldMomentRecord",
            "followUpEvidenceReference": "delayedFollowUpRecord",
            "audienceResponseEvidenceReference": "audienceResponseRecord",
            "selfReportEvidenceReference": "participantSelfReport",
        }.items():
            row[field] = add_attachment(
                run_dir, manifest, f"transfer-row-{index}-{field.lower()}", kind
            )
        transfer["rows"].append(row)
    transfer["summary"]["studyDurationDays"] = 42
    transfer["summary"]["readinessWarnings"] = []
    release.summarize_transfer(transfer)
    write_json(transfer_path, transfer)

    testflight_path = run_dir / release.MANAGED_ARTIFACTS["realDeviceTestFlight"][0]
    testflight = release.read_json(testflight_path)
    testflight["templateStatus"] = "COLLECTED_EXTERNAL_EVIDENCE"
    testflight.update({
        "testRunID": "TEST-ONLY-device-run",
        "appVersion": "TEST-ONLY-1.0",
        "buildNumber": "TEST-ONLY-build-100",
        "deviceModel": "TEST-ONLY-physical-device",
        "osVersion": "TEST-ONLY-iOS",
        "testerRole": "internalTestFlightQA",
        "testRunAttestation": {
            "testerID": "TEST-ONLY-device-tester",
            "verifierID": "TEST-ONLY-device-verifier",
            "distributionChannel": "TestFlight",
            "testFlightInstallationReference": add_attachment(
                run_dir, manifest, "testflight-installation-proof",
                "testFlightInstallationProof", "TEST-ONLY-device-verifier",
            ),
            "attestationReference": add_attachment(
                run_dir, manifest, "testflight-run-attestation", "testFlightRunAttestation",
                "TEST-ONLY-device-verifier",
            ),
            "attestedAtISO8601": FIXTURE_TIME,
            "attestsPhysicalDeviceWasUsed": True,
            "attestsInstalledBuildCameFromTestFlight": True,
        },
    })
    device_hash = "sha256:" + hashlib.sha256(b"TEST-ONLY-device").hexdigest()
    for row in testflight["rows"]:
        surface = row["surfaceKey"]
        row.update({
            "passed": True,
            "realDevice": True,
            "testFlightBuildInstalled": True,
            "evidenceReference": add_attachment(
                run_dir, manifest, f"testflight-{surface.lower()}", row["evidenceKind"],
                "TEST-ONLY-device-verifier",
            ),
            "evidenceCapturedAtISO8601": FIXTURE_TIME,
            "testFlightBuildNumber": testflight["buildNumber"],
            "deviceIdentifierHash": device_hash,
            "latencyMs": 1800 if surface == "aiPromptLatency" else None,
            "blockingIssueCount": 0,
            "verifiedByID": "TEST-ONLY-device-verifier",
            "notes": ["TEST FIXTURE ONLY"],
        })
    testflight["summary"]["crashFree"] = True
    testflight["summary"]["readinessWarnings"] = []
    release.summarize_testflight(testflight)
    write_json(testflight_path, testflight)

    operational_path = run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
    operational = release.read_json(operational_path)
    operational.update({
        "templateStatus": "COLLECTED_EXTERNAL_EVIDENCE",
        "releaseCandidateBuild": "TEST-ONLY-build-100",
        "completedByRole": "releaseManager",
        "completedByID": "TEST-ONLY-operations-owner",
    })
    operational["releasePrerequisites"] = {}
    for gate_key, (reference_key, kind) in release.OPERATIONAL_PREREQUISITES.items():
        operational["releasePrerequisites"][gate_key] = True
        operational["releasePrerequisites"][reference_key] = add_attachment(
            run_dir, manifest, f"prerequisite-{gate_key.lower()}", kind,
            "TEST-ONLY-operations-verifier",
        )
    for item in operational["items"]:
        key = item["key"]
        item.update({
            "completed": True,
            "evidenceReference": add_attachment(
                run_dir, manifest, f"ops-{key.lower()}-evidence", item["evidenceKind"],
                "TEST-ONLY-operations-verifier",
            ),
            "verificationReference": add_attachment(
                run_dir, manifest, f"ops-{key.lower()}-verification", f"verification:{key}",
                "TEST-ONLY-operations-verifier",
            ),
            "commandOrReviewOutputReference": add_attachment(
                run_dir, manifest, f"ops-{key.lower()}-output", f"output:{key}",
                "TEST-ONLY-operations-verifier",
            ),
            "releaseCandidateBuild": operational["releaseCandidateBuild"],
            "completedAtISO8601": FIXTURE_TIME,
            "performedByID": "TEST-ONLY-operations-performer",
            "verifiedAtISO8601": FIXTURE_TIME,
            "verifiedByID": "TEST-ONLY-operations-verifier",
            "verifiedByRole": "releaseVerifier",
            "notes": ["TEST FIXTURE ONLY"],
        })
    operational["summary"]["readinessWarnings"] = []
    release.summarize_operational(operational)
    write_json(operational_path, operational)

    write_json(manifest_path, manifest)


class ReleaseEvidenceWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source_dump = self.root / "source-dump"
        self.run_dir = self.root / "run"
        make_source_dump(self.source_dump)
        init_run(self.run_dir, self.source_dump)

    def tearDown(self):
        self.temp.cleanup()

    def test_initialized_templates_are_visibly_nonpassing_and_fail_closed(self):
        result = release.validate_run(self.run_dir, REPO_ROOT)

        self.assertFalse(result["passes"])
        self.assertIn("professionalCalibrationNotMarkedCollected", result["failures"])
        for key, (artifact_name, _) in release.MANAGED_ARTIFACTS.items():
            payload = release.read_json(self.run_dir / artifact_name)
            self.assertEqual(payload["templateStatus"], "NOT_PRODUCTION_EVIDENCE")
            self.assertFalse(result["existingReadinessValidator"][key]["passes"])

    def test_structurally_complete_test_fixture_passes_and_promotes_to_temp_dump(self):
        fill_complete_fixture(self.run_dir)
        result = release.validate_run(self.run_dir, REPO_ROOT)
        self.assertTrue(result["passes"], result["failures"])
        self.assertTrue(all(
            status["passes"]
            for status in result["existingReadinessValidator"].values()
        ))

        target = self.root / "target-dump"
        target.mkdir()
        for file_name in (*release.SOURCE_FILES, release.PACKET_FILE):
            shutil.copy2(self.run_dir / file_name, target / file_name)
        with redirect_stdout(io.StringIO()):
            release.promote_command(SimpleNamespace(
                run_dir=str(self.run_dir),
                dump_dir=str(target),
                repo_root=str(REPO_ROOT),
                replace_existing=False,
            ))

        for artifact_name, _ in release.MANAGED_ARTIFACTS.values():
            self.assertTrue((target / artifact_name).is_file())
        receipt = release.read_json(self.run_dir / "promotion-receipt-v1.json")
        self.assertTrue(receipt["existingReadinessValidatorAcceptedManagedArtifacts"])
        self.assertFalse(receipt["launchReadyClaimed"])

    def test_reviewer_cannot_self_attest_as_calibration_coordinator(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["professionalCalibration"][0]
        payload = release.read_json(path)
        payload["collectionAttestation"]["coordinatorID"] = "TEST-ONLY-reviewer-a"
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertIn("reviewerIsCalibrationCoordinator:TEST-ONLY-reviewer-a", failures)

    def test_transfer_enrollment_accounting_and_independent_analysis_are_required(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["realUserTransfer"][0]
        payload = release.read_json(path)
        payload["enrollment"]["withdrawnUserCount"] = 0
        payload["studyAttestation"]["analystID"] = payload["studyAttestation"]["principalInvestigatorID"]
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertIn("transferEnrollmentAccountingMismatch", failures)
        self.assertIn("transferInvestigatorAndAnalystMustDiffer", failures)

    def test_missing_physical_attachment_is_rejected_even_when_json_says_passed(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["realDeviceTestFlight"][0]
        payload = release.read_json(path)
        evidence_id = payload["rows"][0]["evidenceReference"].removeprefix("evidence://")
        manifest = release.read_json(self.run_dir / release.RUN_MANIFEST_FILE)
        entry = next(item for item in manifest["evidenceIndex"] if item["id"] == evidence_id)
        (self.run_dir / entry["path"]).unlink()

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertTrue(any(
            failure.startswith("attachmentMissingEmptyOrUnsafe:testFlight.liveActivity")
            for failure in failures
        ))

    def test_operational_item_cannot_be_verified_by_its_performer(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(path)
        payload["items"][0]["verifiedByID"] = payload["items"][0]["performedByID"]
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertIn(
            "operationalPerformerAndVerifierMustDiffer:firestoreRulesDeployed",
            failures,
        )

    def test_cloud_probe_success_cannot_override_open_credential_incident(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(path)
        self.assertTrue(payload["releasePrerequisites"]["cloudOperationsProbePassed"])
        payload["releasePrerequisites"]["historicalCredentialIncidentClosed"] = False
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertIn(
            "operationalPrerequisiteOpen:historicalCredentialIncidentClosed",
            failures,
        )

    def test_direct_development_device_build_cannot_count_as_testflight(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["realDeviceTestFlight"][0]
        payload = release.read_json(path)
        payload["testRunAttestation"]["distributionChannel"] = "Development"
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertIn("testFlightDistributionChannelNotProven", failures)

    def test_source_sidecar_drift_is_rejected(self):
        fill_complete_fixture(self.run_dir)
        (self.run_dir / "source-git-commit.txt").write_text("stale-commit", encoding="utf-8")

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertIn("sourceBindingMismatch:sourceGitCommit", failures)

    def test_promotion_refuses_incomplete_run_without_writing_target(self):
        target = self.root / "target-dump"
        target.mkdir()
        for file_name in (*release.SOURCE_FILES, release.PACKET_FILE):
            shutil.copy2(self.run_dir / file_name, target / file_name)

        with redirect_stdout(io.StringIO()), self.assertRaises(release.WorkflowError):
            release.promote_command(SimpleNamespace(
                run_dir=str(self.run_dir),
                dump_dir=str(target),
                repo_root=str(REPO_ROOT),
                replace_existing=False,
            ))
        self.assertFalse(any(
            (target / artifact_name).exists()
            for artifact_name, _ in release.MANAGED_ARTIFACTS.values()
        ))


if __name__ == "__main__":
    unittest.main()
