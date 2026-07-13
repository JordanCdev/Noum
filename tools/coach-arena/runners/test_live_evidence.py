import copy
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

import live_evidence as live
import test_readiness_gate as readiness_fixtures


SOURCE_EXPECTATIONS = {
    "source-git-commit.txt": "abc123",
    "source-coach-fingerprint.txt": "sha256:test-source",
}


def operational_rows(payload):
    rows = list(payload["rows"])
    for conversation in payload["longFormConversations"]:
        rows.extend(conversation["rows"])
    return rows


def complete_real_live_capture():
    payload = readiness_fixtures.complete_live_provider_evidence(
        source_fingerprint=SOURCE_EXPECTATIONS["source-coach-fingerprint.txt"],
        git_commit=SOURCE_EXPECTATIONS["source-git-commit.txt"],
    )
    payload.pop("liveEvidenceProvenance", None)
    payload["providerChain"] = ["Google Cloud (gemini-3.5-flash)"]
    for index, row in enumerate(operational_rows(payload)):
        row["providerChosen"] = "Google Cloud"
        row["providerModel"] = "gemini-3.5-flash"
        row["providerAttemptCount"] = 1
        row["providerRetryCount"] = 1 if index == 0 else 0
        row["providerRefusalCount"] = 1 if index == 0 else 0
        row["timeToCompleteReplyMs"] = 900 + index
        row["diagnostics"] = [{
            "provider": "Google Cloud",
            "model": "gemini-3.5-flash",
            "outcome": "success",
            "reason": "Transport succeeded",
            "statusCode": 200,
            "latencyMs": 850 + index,
        }]
        if index == 0:
            row["diagnostics"].insert(0, {
                "provider": "Google Cloud",
                "model": "gemini-3.5-flash",
                "outcome": "failure",
                "reason": "Provider refused: HTTP 429",
                "statusCode": 429,
                "latencyMs": 40,
            })
    payload["summary"]["maxProviderRetryCount"] = 1
    payload["summary"]["totalProviderRefusalCount"] = 1
    return payload


def write_capture(root, payload):
    path = Path(root) / "capture.json"
    path.write_bytes((json.dumps(payload, sort_keys=True) + "\n").encode("utf-8"))
    return path


def attestation_for(capture_path, **changes):
    raw = Path(capture_path).read_bytes()
    result = {
        "schemaVersion": live.ATTESTATION_SCHEMA,
        "executionMode": "liveProviderProductionPath",
        "producer": live.PRODUCER,
        "candidateSource": "providerNetworkResponse",
        "fixturePreset": "readiness",
        "longFormPreset": "required",
        "usesReplayResponses": False,
        "usesFixtureResponses": False,
        "usesTemplateResponses": False,
        "captureSHA256": "sha256:" + hashlib.sha256(raw).hexdigest(),
        "sourceGitCommit": SOURCE_EXPECTATIONS["source-git-commit.txt"],
        "sourceCoachFingerprint": SOURCE_EXPECTATIONS["source-coach-fingerprint.txt"],
        "runID": "live-2026-07-13T12-00-00Z",
        "capturedAt": "2026-07-13T12:00:00Z",
    }
    result.update(changes)
    return result


class LiveEvidenceTests(unittest.TestCase):
    def test_complete_attested_capture_validates_and_preserves_operational_telemetry(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            payload = complete_real_live_capture()
            capture = write_capture(temp_dir, payload)
            attestation = attestation_for(capture)

            validated, digest = live.validate_capture(
                capture,
                attestation,
                SOURCE_EXPECTATIONS,
            )
            destination = Path(temp_dir) / live.ARTIFACT_NAME
            live.atomic_publish(validated, attestation, digest, destination)
            published = json.loads(destination.read_text(encoding="utf-8"))

        first = published["rows"][0]
        self.assertEqual(first["providerRetryCount"], 1)
        self.assertEqual(first["providerRefusalCount"], 1)
        self.assertEqual(first["timeToCompleteReplyMs"], 900)
        self.assertEqual(first["diagnostics"], payload["rows"][0]["diagnostics"])
        self.assertEqual(first["reply"], payload["rows"][0]["reply"])
        self.assertEqual(
            published["liveEvidenceProvenance"]["candidateSource"],
            "providerNetworkResponse",
        )
        self.assertFalse(published["liveEvidenceProvenance"]["usesReplayResponses"])
        self.assertEqual(
            live.readiness_gate.live_provider_sweep_contract_failures(
                published,
                source_expectations=SOURCE_EXPECTATIONS,
            ),
            [],
        )

    def test_replay_fixture_and_template_identities_are_rejected(self):
        for identity in [
            "Replay (offline-capture)",
            "Fixture Provider (gemini-3.5-flash)",
            "Template (coach-response-v1)",
        ]:
            with self.subTest(identity=identity), tempfile.TemporaryDirectory() as temp_dir:
                payload = complete_real_live_capture()
                payload["providerChain"] = [identity]
                capture = write_capture(temp_dir, payload)

                with self.assertRaisesRegex(live.LiveEvidenceError, "nonLiveProviderChainIdentity"):
                    live.validate_capture(
                        capture,
                        attestation_for(capture),
                        SOURCE_EXPECTATIONS,
                    )

    def test_test_model_identity_is_rejected_even_with_a_live_attestation(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            payload = complete_real_live_capture()
            payload["rows"][0]["providerModel"] = "gemini-test"
            capture = write_capture(temp_dir, payload)

            with self.assertRaisesRegex(live.LiveEvidenceError, "nonLiveProviderIdentity"):
                live.validate_capture(
                    capture,
                    attestation_for(capture),
                    SOURCE_EXPECTATIONS,
                )

    def test_incomplete_retry_refusal_latency_and_diagnostics_fail_closed(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            payload = complete_real_live_capture()
            row = payload["rows"][0]
            row.pop("providerRetryCount")
            row.pop("providerRefusalCount")
            row.pop("timeToCompleteReplyMs")
            row["diagnostics"] = []
            capture = write_capture(temp_dir, payload)

            with self.assertRaises(live.LiveEvidenceError) as context:
                live.validate_capture(
                    capture,
                    attestation_for(capture),
                    SOURCE_EXPECTATIONS,
                )

        message = str(context.exception)
        self.assertIn("providerRetryTelemetryMissing", message)
        self.assertIn("providerRefusalTelemetryMissing", message)
        self.assertIn("providerCompletionLatencyMissing", message)
        self.assertIn("providerDiagnosticsMissing", message)

    def test_real_looking_identity_without_a_verified_network_success_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            payload = complete_real_live_capture()
            payload["rows"][0]["diagnostics"] = [{
                "provider": "Google Cloud",
                "model": "gemini-3.5-flash",
                "outcome": "success",
                "reason": "Loaded a prepared response",
                "statusCode": None,
                "latencyMs": 1,
            }]
            capture = write_capture(temp_dir, payload)

            with self.assertRaisesRegex(live.LiveEvidenceError, "providerTransportSuccessMissing"):
                live.validate_capture(
                    capture,
                    attestation_for(capture),
                    SOURCE_EXPECTATIONS,
                )

    def test_stale_source_capture_is_rejected_without_rewriting_it(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            payload = complete_real_live_capture()
            payload["sourceGitCommit"] = "old456"
            capture = write_capture(temp_dir, payload)
            original = capture.read_bytes()

            with self.assertRaisesRegex(live.LiveEvidenceError, "sourceGitCommitMismatch"):
                live.validate_capture(
                    capture,
                    attestation_for(capture, sourceGitCommit="old456"),
                    SOURCE_EXPECTATIONS,
                )

            self.assertEqual(capture.read_bytes(), original)

    def test_capture_digest_attestation_is_bound_to_exact_bytes(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            payload = complete_real_live_capture()
            capture = write_capture(temp_dir, payload)
            attestation = attestation_for(capture)
            payload["rows"][0]["reply"] += " Changed after attestation."
            write_capture(temp_dir, payload)

            with self.assertRaisesRegex(live.LiveEvidenceError, "captureSHA256"):
                live.validate_capture(
                    capture,
                    attestation,
                    SOURCE_EXPECTATIONS,
                )

    def test_failed_candidate_does_not_replace_previously_published_artifact(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            destination = Path(temp_dir) / live.ARTIFACT_NAME
            prior = b'{"previouslyValid":true}\n'
            destination.write_bytes(prior)
            payload = complete_real_live_capture()
            payload["rows"] = payload["rows"][:-1]
            payload["fixtureCount"] -= 1
            payload["summary"]["rowCount"] -= 1
            capture = write_capture(temp_dir, payload)

            with self.assertRaises(live.LiveEvidenceError):
                validated, digest = live.validate_capture(
                    capture,
                    attestation_for(capture),
                    SOURCE_EXPECTATIONS,
                )
                live.atomic_publish(
                    validated,
                    attestation_for(capture),
                    digest,
                    destination,
                )

            self.assertEqual(destination.read_bytes(), prior)

    def test_live_network_requires_an_explicit_nonplaceholder_environment_key(self):
        self.assertEqual(live.configured_live_credentials({}), [])
        self.assertEqual(
            live.configured_live_credentials({"ANTHROPIC_API_KEY": "placeholder"}),
            [],
        )
        self.assertEqual(
            live.configured_live_credentials({"GEMINI_API_KEY": "real-exported-key"}),
            ["GEMINI_API_KEY"],
        )


if __name__ == "__main__":
    unittest.main()
