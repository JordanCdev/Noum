import json
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path

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
    (root / "docs").mkdir(parents=True, exist_ok=True)
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


def write_complete_evidence(root, source_fingerprint="sha256:test-source", git_commit="abc123"):
    root = Path(root)
    payloads = {
        "coach-live-eval-v1.json": {
            "schemaVersion": "coach-live-eval-v1",
            "sourceGitCommit": git_commit,
            "sourceCoachFingerprint": source_fingerprint,
            "fixtureCount": 10,
            "longFormConversationCount": 10,
            "summary": {},
            "rows": [],
        },
        "coach-chat-conversation-expert-calibration-results-v2.json": {
            "schemaVersion": "coach-chat-conversation-expert-calibration-results-v2",
            "sourcePacketSchemaVersion": "coach-chat-conversation-expert-calibration-v2",
            "sourcePacketFingerprint": "fnv1a64:test",
            "rubricVersion": "coach-parity-conversation-calibration-v2",
            "reviewerRole": "professionalCommunicationCoach",
            "reviewCount": 2,
            "summary": {},
            "rows": [],
        },
        "coach-real-user-transfer-outcomes-v2.json": {
            "schemaVersion": "coach-real-user-transfer-outcomes-v2",
            "studyProtocolVersion": "coach-transfer-outcome-ledger-v2",
            "cohortDescription": "closed-beta-transfer-cohort",
            "outcomeCount": 10,
            "summary": {},
            "rows": [],
        },
        "coach-real-device-testflight-qa-v2.json": {
            "schemaVersion": "coach-real-device-testflight-qa-v2",
            "testRunID": "qa-run",
            "appVersion": "1.0",
            "buildNumber": "2026.06.30.1",
            "deviceModel": "iPhone 15 Pro",
            "osVersion": "iOS 26",
            "testerRole": "releaseQA",
            "summary": {},
            "rows": [],
        },
        "coach-operational-launch-checklist-v2.json": {
            "schemaVersion": "coach-operational-launch-checklist-v2",
            "checklistVersion": "m14-launch-gate-v2",
            "releaseCandidateBuild": "2026.06.30.1",
            "completedByRole": "releaseManager",
            "summary": {},
            "items": [],
        },
    }
    for file_name, payload in payloads.items():
        (root / file_name).write_text(json.dumps(payload), encoding="utf-8")
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

        status = gate.build_readiness_status(
            report_with_readiness(readiness),
            Path("tools/coach-arena/reports/app-path/latest.json"),
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

        status = gate.build_readiness_status(report, canonical_report_path())

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

        status = gate.build_readiness_status(
            report_with_readiness(readiness),
            canonical_report_path(),
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

        self.assertTrue(status["vision"]["productionReady"])
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
        self.assertIn("lightweight JSON/schema-version", audit["validationBoundary"])

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
        self.assertIn("Python performs a lightweight JSON/schema-version staging check", markdown)

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
