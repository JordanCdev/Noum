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


def register_history_report(run_dir, secret_value="REDACTED"):
    manifest_path = run_dir / release.RUN_MANIFEST_FILE
    manifest = release.read_json(manifest_path)
    reference = add_attachment(
        run_dir, manifest, "history-import-report", "fullHistorySecretReview",
        "TEST-ONLY-history-verifier",
    )
    reachable = release.reachable_commit_set_binding(REPO_ROOT)
    source_commit = release.current_source_binding(REPO_ROOT)["sourceGitCommit"]
    current_commit = next(
        commit for commit in reachable["commits"] if commit.startswith(source_commit)
    )
    commits = [
        "277e2b388bb17d603011277a819b0bcaae517404",
        current_commit,
        current_commit,
    ]
    report = [{
        "RuleID": f"TEST-ONLY-import-rule-{index}",
        "Commit": commit,
        "File": f"TEST-ONLY/history/import-{index}.txt",
        "StartLine": index + 1,
        "Secret": secret_value if index == 0 else "REDACTED",
        "Match": "TEST-ONLY=REDACTED",
    } for index, commit in enumerate(commits)]
    evidence_id = reference.removeprefix("evidence://")
    entry = next(item for item in manifest["evidenceIndex"] if item["id"] == evidence_id)
    report_path = run_dir / entry["path"]
    write_json(report_path, report)
    entry["sha256"] = release.sha256_file(report_path)
    write_json(manifest_path, manifest)
    return reference, report


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
        for check in row["checks"]:
            check["passed"] = True
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
    prerequisite_by_key = {
        row["key"]: row for row in operational["releasePrerequisites"]
    }
    for gate_key, spec in release.OPERATIONAL_PREREQUISITES.items():
        row = prerequisite_by_key[gate_key]
        row.update({
            "completed": True,
            "evidenceReference": add_attachment(
                run_dir, manifest, f"prerequisite-{gate_key.lower()}-evidence",
                spec["evidenceKind"], "TEST-ONLY-operations-verifier",
            ),
            "verificationReference": add_attachment(
                run_dir, manifest, f"prerequisite-{gate_key.lower()}-verification",
                f"verification:{gate_key}", "TEST-ONLY-operations-verifier",
            ),
            "commandOrReviewOutputReference": add_attachment(
                run_dir, manifest, f"prerequisite-{gate_key.lower()}-output",
                f"output:{gate_key}", "TEST-ONLY-operations-verifier",
            ),
            "releaseCandidateBuild": operational["releaseCandidateBuild"],
            "completedAtISO8601": FIXTURE_TIME,
            "performedByID": "TEST-ONLY-operations-performer",
            "verifiedAtISO8601": FIXTURE_TIME,
            "verifiedByID": "TEST-ONLY-operations-verifier",
            "verifiedByRole": "releaseVerifier",
            "notes": ["TEST FIXTURE ONLY"],
        })

    reachable = release.reachable_commit_set_binding(REPO_ROOT)
    source_commit = release.current_source_binding(REPO_ROOT)["sourceGitCommit"]
    current_commit = next(
        commit for commit in reachable["commits"] if commit.startswith(source_commit)
    )
    finding_fixtures = [
        (
            "277e2b388bb17d603011277a819b0bcaae517404",
            "revoked",
            "secretFindingRevocation",
        ),
        (
            current_commit,
            "invalidated",
            "secretFindingInvalidation",
        ),
        (
            current_commit,
            "falsePositive",
            "secretFindingFalsePositiveReview",
        ),
    ]
    report_rows = [
        {
            "RuleID": f"TEST-ONLY-rule-{index}",
            "Commit": commit,
            "File": f"TEST-ONLY/history/fixture-{index}.txt",
            "StartLine": index + 1,
            "Secret": "REDACTED",
            "Match": "TEST-ONLY=REDACTED",
        }
        for index, (commit, _, _) in enumerate(finding_fixtures)
    ]
    history_evidence_reference = prerequisite_by_key[
        "fullHistorySecretFindingsAdjudicated"
    ]["evidenceReference"]
    history_evidence_id = history_evidence_reference.removeprefix("evidence://")
    history_evidence_entry = next(
        item for item in manifest["evidenceIndex"] if item["id"] == history_evidence_id
    )
    history_evidence_path = run_dir / history_evidence_entry["path"]
    write_json(history_evidence_path, report_rows)
    history_evidence_entry["sha256"] = release.sha256_file(history_evidence_path)
    operational["historySecretAdjudication"] = {
        "scanner": release.HISTORY_SECRET_SCANNER,
        "scannerVersion": release.HISTORY_SECRET_SCANNER_VERSION,
        "scanScope": release.HISTORY_SECRET_SCAN_SCOPE,
        "scannedRepositoryCommit": current_commit,
        "redactionPercent": 100,
        "reachableCommitCount": reachable["reachableCommitCount"],
        "reachableCommitSetSha256": reachable["reachableCommitSetSha256"],
        "redactedScanReportReference": history_evidence_reference,
        "detectedFindingCount": len(finding_fixtures),
        "adjudicatedFindingCount": len(finding_fixtures),
        "unresolvedFindingCount": 0,
        "suppressedFindingCount": 0,
        "findings": [],
    }
    for index, (commit, disposition, kind) in enumerate(finding_fixtures):
        report_row = report_rows[index]
        operational["historySecretAdjudication"]["findings"].append({
            "findingID": release.history_secret_finding_id(report_row),
            "detectorRuleID": report_row["RuleID"],
            "commit": commit,
            "path": report_row["File"],
            "disposition": disposition,
            "statusEvidenceReference": add_attachment(
                run_dir, manifest, f"history-finding-{index}-status", kind,
                "TEST-ONLY-operations-verifier",
            ),
        })
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

    def test_full_source_commit_expands_only_valid_git_commit_references(self):
        abbreviated = release.current_source_binding(REPO_ROOT)["sourceGitCommit"]
        expanded = release.full_source_commit(REPO_ROOT, abbreviated)

        self.assertRegex(expanded, r"^[0-9a-f]{40}$")
        self.assertTrue(expanded.startswith(abbreviated))
        with self.assertRaises(release.WorkflowError):
            release.full_source_commit(REPO_ROOT, "not-a-commit")

    def test_initialized_templates_are_visibly_nonpassing_and_fail_closed(self):
        result = release.validate_run(self.run_dir, REPO_ROOT)

        self.assertFalse(result["passes"])
        self.assertIn("professionalCalibrationNotMarkedCollected", result["failures"])
        for key, (artifact_name, _) in release.MANAGED_ARTIFACTS.items():
            payload = release.read_json(self.run_dir / artifact_name)
            self.assertEqual(payload["templateStatus"], "NOT_PRODUCTION_EVIDENCE")
            self.assertFalse(result["existingReadinessValidator"][key]["passes"])
        operational = release.read_json(
            self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        )
        reachable = release.reachable_commit_set_binding(REPO_ROOT)
        history = operational["historySecretAdjudication"]
        self.assertEqual(
            history["scannedRepositoryCommit"],
            release.full_source_commit(REPO_ROOT),
        )
        self.assertEqual(history["reachableCommitCount"], reachable["reachableCommitCount"])
        self.assertEqual(
            history["reachableCommitSetSha256"], reachable["reachableCommitSetSha256"]
        )

    def test_history_import_builds_only_an_unresolved_redacted_inventory(self):
        reference, report = register_history_report(self.run_dir)

        with redirect_stdout(io.StringIO()) as output:
            release.import_history_scan_command(SimpleNamespace(
                run_dir=str(self.run_dir),
                reference=reference,
                repo_root=str(REPO_ROOT),
            ))

        operational = release.read_json(
            self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        )
        history = operational["historySecretAdjudication"]
        self.assertEqual(history["detectedFindingCount"], len(report))
        self.assertEqual(history["adjudicatedFindingCount"], 0)
        self.assertEqual(history["unresolvedFindingCount"], len(report))
        self.assertEqual(history["suppressedFindingCount"], 0)
        self.assertTrue(all(row["disposition"] == "" for row in history["findings"]))
        self.assertTrue(all(
            row["statusEvidenceReference"] == "" for row in history["findings"]
        ))
        self.assertIn("gate remains closed", output.getvalue())
        self.assertFalse(release.validate_run(self.run_dir, REPO_ROOT)["passes"])

    def test_history_import_rejects_unredacted_content_without_logging_it(self):
        secret_sentinel = "TEST-ONLY-UNREDACTED-IMPORT-SECRET-MUST-NOT-LOG"
        reference, _ = register_history_report(self.run_dir, secret_sentinel)

        with self.assertRaises(release.WorkflowError) as raised:
            release.import_history_scan_command(SimpleNamespace(
                run_dir=str(self.run_dir),
                reference=reference,
                repo_root=str(REPO_ROOT),
            ))

        self.assertIn("historySecretRedactedReportContainsUnredactedSecret", str(raised.exception))
        self.assertNotIn(secret_sentinel, str(raised.exception))

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

    def test_testflight_v3_template_pins_fourteen_surfaces_and_seventy_seven_checks(self):
        path = self.run_dir / release.MANAGED_ARTIFACTS["realDeviceTestFlight"][0]
        payload = release.read_json(path)

        self.assertEqual(payload["schemaVersion"], "coach-real-device-testflight-qa-v3")
        self.assertEqual(len(payload["rows"]), 14)
        self.assertEqual(payload["summary"]["requiredCheckCount"], 77)
        self.assertEqual(
            sum(len(row["checks"]) for row in payload["rows"]),
            77,
        )
        rows = {row["surfaceKey"]: row for row in payload["rows"]}
        self.assertEqual(set(rows), set(release.GATE.REAL_DEVICE_REQUIRED_SURFACES))
        for surface in release.GATE.REAL_DEVICE_REQUIRED_SURFACES:
            self.assertEqual(
                rows[surface]["evidenceKind"],
                release.GATE.REAL_DEVICE_EVIDENCE_KIND_BY_SURFACE[surface],
            )
            self.assertEqual(
                [check["checkKey"] for check in rows[surface]["checks"]],
                release.GATE.REAL_DEVICE_REQUIRED_CHECKS_BY_SURFACE[surface],
            )

    def test_testflight_checks_fail_closed_when_missing_unexpected_duplicated_or_failed(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["realDeviceTestFlight"][0]
        payload = release.read_json(path)
        rows = {row["surfaceKey"]: row for row in payload["rows"]}
        rows["liveActivity"]["checks"].pop()
        rows["productionTranscriptionConsent"]["checks"].append({
            "checkKey": "syntheticPass",
            "passed": True,
        })
        rows["modeSmoke"]["checks"].append({
            "checkKey": "timedDifficulties",
            "passed": True,
        })
        rows["accountDeletion"]["checks"][0]["passed"] = False
        release.summarize_testflight(payload)
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        for expected_failure in [
            "missingRequiredChecks=liveActivity:forceQuitEnds",
            "unexpectedCheckKeys=productionTranscriptionConsent:syntheticPass",
            "duplicateCheckKeys=modeSmoke:timedDifficulties",
            "failedRequiredChecks=accountDeletion:serverFailurePreservesSignedInState",
        ]:
            self.assertIn(
                f"existingReadinessValidator.realDeviceTestFlight:{expected_failure}",
                failures,
            )

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
        prerequisites = {
            row["key"]: row for row in payload["releasePrerequisites"]
        }
        self.assertTrue(prerequisites["cloudOperationsProbePassed"]["completed"])
        prerequisites["historicalCredentialIncidentClosed"]["completed"] = False
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertIn(
            "operationalPrerequisiteOpen:historicalCredentialIncidentClosed",
            failures,
        )

    def test_prerequisites_require_exact_rows_and_reject_unknown_or_duplicate_keys(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(path)
        payload["releasePrerequisites"].pop()
        payload["releasePrerequisites"].append(dict(payload["releasePrerequisites"][0]))
        payload["releasePrerequisites"].append({
            **payload["releasePrerequisites"][1],
            "key": "TEST-ONLY-unknown-prerequisite",
        })
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertIn(
            "operationalPrerequisiteDuplicate:cloudOperationsProbePassed", failures,
        )
        self.assertIn(
            "operationalPrerequisiteUnexpected:TEST-ONLY-unknown-prerequisite", failures,
        )
        self.assertTrue(any(
            failure.startswith("operationalPrerequisiteMissing:") for failure in failures
        ))
        self.assertIn("operationalPrerequisiteCountMismatch", failures)

    def test_prerequisite_requires_build_kind_environment_and_exact_fields(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(path)
        row = payload["releasePrerequisites"][0]
        row["releaseCandidateBuild"] = "TEST-ONLY-wrong-build"
        row["evidenceKind"] = "TEST-ONLY-wrong-kind"
        row["environment"] = "TEST-ONLY-wrong-environment"
        row["unexpected"] = True
        del row["notes"]
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        key = "cloudOperationsProbePassed"
        self.assertIn(f"operationalPrerequisiteBuildMismatch:{key}", failures)
        self.assertIn(f"operationalPrerequisiteEvidenceKindMismatch:{key}", failures)
        self.assertIn(f"operationalPrerequisiteEnvironmentMismatch:{key}", failures)
        self.assertIn("operationalPrerequisiteFieldMissing:0.notes", failures)
        self.assertIn("operationalPrerequisiteFieldUnexpected:0.unexpected", failures)

    def test_prerequisite_requires_independent_chronological_verification(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(path)
        row = payload["releasePrerequisites"][0]
        row["verifiedByID"] = row["performedByID"]
        row["completedAtISO8601"] = "2026-07-14T12:00:00Z"
        row["verifiedAtISO8601"] = "2026-07-13T12:00:00Z"
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        key = "cloudOperationsProbePassed"
        self.assertIn(
            f"operationalPrerequisitePerformerAndVerifierMustDiffer:{key}", failures,
        )
        self.assertIn(
            f"operationalPrerequisiteVerifiedBeforeCompletion:{key}", failures,
        )

    def test_prerequisite_cannot_be_verified_before_its_attachment_exists(self):
        fill_complete_fixture(self.run_dir)
        operational_path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(operational_path)
        row = payload["releasePrerequisites"][0]
        evidence_id = row["evidenceReference"].removeprefix("evidence://")
        manifest_path = self.run_dir / release.RUN_MANIFEST_FILE
        manifest = release.read_json(manifest_path)
        entry = next(item for item in manifest["evidenceIndex"] if item["id"] == evidence_id)
        entry["capturedAtISO8601"] = "2026-07-14T12:00:00Z"
        write_json(manifest_path, manifest)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertIn(
            "operationalPrerequisiteEvidenceCapturedAfterVerification:"
            "cloudOperationsProbePassed",
            failures,
        )

    def test_prerequisite_requires_three_distinct_indexed_attachment_kinds(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(path)
        row = payload["releasePrerequisites"][0]
        row["verificationReference"] = row["evidenceReference"]
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        key = "cloudOperationsProbePassed"
        self.assertIn(
            f"operationalPrerequisiteReferencesMustBeDistinct:{key}", failures,
        )
        self.assertTrue(any(
            failure.startswith("attachmentKindMismatch:operational.prerequisite.")
            for failure in failures
        ))

    def test_history_adjudication_is_bound_to_source_and_reachable_commit_set(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(path)
        history = payload["historySecretAdjudication"]
        history["scannedRepositoryCommit"] = "0" * 40
        history["reachableCommitCount"] += 1
        history["reachableCommitSetSha256"] = "sha256:" + "0" * 64
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertIn("historySecretScanSourceCommitMismatch", failures)
        self.assertIn("historySecretReachableCommitCountMismatch", failures)
        self.assertIn("historySecretReachableCommitFingerprintMismatch", failures)

    def test_history_scan_metadata_report_and_counts_are_exact(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(path)
        history = payload["historySecretAdjudication"]
        history["scanner"] = "TEST-ONLY-other-scanner"
        history["scannerVersion"] = "0.0.0"
        history["scanScope"] = "working-tree-only"
        history["redactionPercent"] = 99
        history["redactedScanReportReference"] = payload["releasePrerequisites"][0][
            "evidenceReference"
        ]
        history["detectedFindingCount"] += 1
        history["adjudicatedFindingCount"] -= 1
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        for failure in (
            "historySecretScannerMismatch",
            "historySecretScannerVersionMismatch",
            "historySecretScanScopeMismatch",
            "historySecretScanNotFullyRedacted",
            "historySecretScanReportReferenceMismatch",
            "historySecretDetectedFindingCountMismatch",
            "historySecretAdjudicatedFindingCountMismatch",
        ):
            self.assertIn(failure, failures)

    def test_history_report_must_be_machine_readable_and_fully_redacted(self):
        fill_complete_fixture(self.run_dir)
        operational_path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(operational_path)
        reference = payload["historySecretAdjudication"]["redactedScanReportReference"]
        evidence_id = reference.removeprefix("evidence://")
        manifest_path = self.run_dir / release.RUN_MANIFEST_FILE
        manifest = release.read_json(manifest_path)
        entry = next(item for item in manifest["evidenceIndex"] if item["id"] == evidence_id)
        report_path = self.run_dir / entry["path"]
        report = release.read_json(report_path)
        secret_sentinel = "TEST-ONLY-UNREDACTED-SECRET-MUST-NOT-LOG"
        report[0]["Secret"] = secret_sentinel
        write_json(report_path, report)
        entry["sha256"] = release.sha256_file(report_path)
        write_json(manifest_path, manifest)

        result = release.validate_run(self.run_dir, REPO_ROOT)
        self.assertIn("historySecretRedactedReportContainsUnredactedSecret:0", result["failures"])
        self.assertNotIn(secret_sentinel, json.dumps(result))

    def test_history_report_rejects_an_unredacted_match_without_logging_it(self):
        fill_complete_fixture(self.run_dir)
        operational_path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(operational_path)
        reference = payload["historySecretAdjudication"]["redactedScanReportReference"]
        evidence_id = reference.removeprefix("evidence://")
        manifest_path = self.run_dir / release.RUN_MANIFEST_FILE
        manifest = release.read_json(manifest_path)
        entry = next(item for item in manifest["evidenceIndex"] if item["id"] == evidence_id)
        report_path = self.run_dir / entry["path"]
        report = release.read_json(report_path)
        match_sentinel = "TEST-ONLY-RAW-MATCH-MUST-NOT-LOG"
        report[0]["Match"] = match_sentinel
        write_json(report_path, report)
        entry["sha256"] = release.sha256_file(report_path)
        write_json(manifest_path, manifest)

        result = release.validate_run(self.run_dir, REPO_ROOT)
        self.assertIn("historySecretRedactedReportContainsUnredactedMatch:0", result["failures"])
        self.assertNotIn(match_sentinel, json.dumps(result))

    def test_history_inventory_must_cover_every_redacted_report_row(self):
        fill_complete_fixture(self.run_dir)
        operational_path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(operational_path)
        reference = payload["historySecretAdjudication"]["redactedScanReportReference"]
        evidence_id = reference.removeprefix("evidence://")
        manifest_path = self.run_dir / release.RUN_MANIFEST_FILE
        manifest = release.read_json(manifest_path)
        entry = next(item for item in manifest["evidenceIndex"] if item["id"] == evidence_id)
        report_path = self.run_dir / entry["path"]
        report = release.read_json(report_path)
        report.append({
            "RuleID": "TEST-ONLY-extra-rule",
            "Commit": report[1]["Commit"],
            "File": "TEST-ONLY/history/extra-fixture.txt",
            "StartLine": 99,
            "Secret": "REDACTED",
            "Match": "TEST-ONLY=REDACTED",
        })
        write_json(report_path, report)
        entry["sha256"] = release.sha256_file(report_path)
        write_json(manifest_path, manifest)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertIn("historySecretRedactedReportFindingCountMismatch", failures)
        self.assertIn("historySecretFindingInventoryDoesNotMatchRedactedReport", failures)

    def test_history_finding_identity_path_commit_and_status_reference_are_unique(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(path)
        findings = payload["historySecretAdjudication"]["findings"]
        findings[1]["findingID"] = findings[0]["findingID"]
        findings[1]["path"] = "../unsafe historical path"
        findings[1]["commit"] = "f" * 40
        findings[1]["statusEvidenceReference"] = findings[0]["statusEvidenceReference"]
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertTrue(any(
            failure.startswith("historySecretFindingIDDuplicate:") for failure in failures
        ))
        self.assertIn("historySecretFindingPathInvalid:1", failures)
        self.assertIn("historySecretFindingCommitNotReachable:" + "f" * 40, failures)
        self.assertIn("historySecretFindingStatusReferenceReused:1", failures)

    def test_history_adjudication_cannot_omit_known_or_unresolved_findings(self):
        fill_complete_fixture(self.run_dir)
        path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(path)
        history = payload["historySecretAdjudication"]
        history["findings"][0]["commit"] = history["findings"][1]["commit"]
        history["findings"][1]["disposition"] = "active"
        history["findings"].pop()
        history["detectedFindingCount"] = 2
        history["adjudicatedFindingCount"] = 2
        history["unresolvedFindingCount"] = 1
        history["suppressedFindingCount"] = 1
        write_json(path, payload)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertIn("historySecretUnresolvedFindingsRemain", failures)
        self.assertIn("historySecretSuppressedFindingsRemain", failures)
        self.assertIn("historySecretKnownFindingFloorNotMet", failures)
        self.assertIn("historySecretFindingDispositionOpenOrInvalid:1", failures)
        self.assertIn(
            "historySecretKnownCredentialFindingMissing:"
            "277e2b388bb17d603011277a819b0bcaae517404",
            failures,
        )

    def test_history_finding_status_requires_independent_indexed_evidence(self):
        fill_complete_fixture(self.run_dir)
        operational_path = self.run_dir / release.MANAGED_ARTIFACTS["operationalLaunch"][0]
        payload = release.read_json(operational_path)
        reference = payload["historySecretAdjudication"]["findings"][0][
            "statusEvidenceReference"
        ]
        evidence_id = reference.removeprefix("evidence://")
        manifest_path = self.run_dir / release.RUN_MANIFEST_FILE
        manifest = release.read_json(manifest_path)
        entry = next(item for item in manifest["evidenceIndex"] if item["id"] == evidence_id)
        entry["verifiedByID"] = "TEST-ONLY-different-verifier"
        write_json(manifest_path, manifest)

        failures = release.validate_run(self.run_dir, REPO_ROOT)["failures"]
        self.assertIn("historySecretFindingVerifierMismatch:0", failures)

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
