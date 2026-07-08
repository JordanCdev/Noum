import json
import tempfile
import unittest
from pathlib import Path

import coach_arena as arena


def complete_app_path_trace():
    return {
        "candidateSource": "appPathReport",
        "context": {"conversationID": "c1", "surface": "text"},
        "retrieval": {"retrievedCardIDs": ["card-1"], "queryPresent": True},
        "memory": {
            "turnDepth": "groundedRead",
            "assessmentConfidence": 0.42,
            "proofTestHash": "proof-1",
        },
        "reasoning": {"qualityGateOutcome": "accepted"},
        "prompt": {"source": "CoachReplyPipeline app-path test"},
        "provider": {"name": "mocked-provider"},
        "rawReply": "Run one 60-second rep.",
        "finalReply": "Run one 60-second rep.",
        "issues": [],
        "latency": {
            "timeToFirstVisibleTokenMs": 120,
            "timeToCompleteReplyMs": 400,
        },
        "cache": {"sourcePath": "/tmp/source.json"},
        "fallback": {"qualityGateAcceptedFallback": False},
        "versions": {"runner": "test"},
        "gitCommit": "test",
        "sourceFingerprint": "sha256:test",
    }


def scored_result():
    return {
        "fixture": {
            "id": "custom-app-path-fixture",
            "turnType": "groundedRead",
        },
        "reply": "Run one 60-second rep.",
        "trace": complete_app_path_trace(),
        "judge": {
            "overall": 82,
            "checkFailures": [],
            "failureReasons": [],
        },
    }


def weak_app_path_result():
    result = scored_result()
    result["fixture"] = {
        "id": "weak-app-path",
        "turnType": "groundedRead",
    }
    result["trace"] = complete_app_path_trace()
    result["trace"]["memory"]["assessmentConfidence"] = 0.58
    result["trace"]["memory"]["proofTestHash"] = "proof-2"
    result["judge"] = {
        "overall": 69,
        "checkFailures": [],
        "failureReasons": ["missing practical intervention"],
    }
    return result


def gold_fixture(fixture_id):
    fixtures = json.loads(arena.DEFAULT_FIXTURES.read_text(encoding="utf-8"))
    for fixture in fixtures:
        if fixture["id"] == fixture_id:
            return fixture
    raise AssertionError(f"missing fixture {fixture_id}")


def app_fixture(overrides=None):
    base = {
        "id": "custom-app-path-fixture",
        "turnType": "quickMove",
        "userTurn": "Can you coach this?",
        "priorChatTurns": [],
        "goal": "No placeholder or fake loading text as answer.",
        "evidence": ["provider fallback path may leak placeholder"],
        "memoryState": "Broken chat must be held back honestly.",
        "emotionalSignal": "Asks for help.",
        "expectedCoachMove": "Either answer with grounded move or honest failure notice; never placeholder.",
        "badAnswerExample": "TODO: generate coach response here.",
        "excellentAnswerExample": "I need one rep before I can coach this honestly. Record 60 seconds, then I will read the opener and close.",
        "disqualifiers": ["TODO", "placeholder", "fake score=10", "empty reply"],
    }
    if overrides:
        base.update(overrides)
    return base


class AppPathBoundaryTests(unittest.TestCase):
    def test_direct_python_app_path_defaults_to_canonical_app_path_reports(self):
        args = type("Args", (), {
            "app_path_report": "/tmp/app-path.json",
            "reports_dir": str(arena.DEFAULT_REPORTS),
        })()

        report_dir, warnings = arena.choose_report_dir(args)

        self.assertEqual(report_dir, arena.CANONICAL_APP_PATH_REPORTS)
        self.assertTrue(warnings)

    def test_stale_nested_app_path_reports_are_redirected_to_canonical_path(self):
        args = type("Args", (), {
            "app_path_report": "/tmp/app-path.json",
            "reports_dir": str(arena.DUPLICATE_APP_PATH_REPORTS),
        })()

        report_dir, warnings = arena.choose_report_dir(args)

        self.assertEqual(report_dir, arena.CANONICAL_APP_PATH_REPORTS)
        self.assertIn("stale nested", warnings[0])

    def test_placeholder_trap_generic_latest_rep_reply_counts_as_fallback_leak(self):
        fixture = app_fixture()

        result = arena.local_judge(
            fixture,
            "I can coach the latest rep: the close is the usable signal, so make the final sentence the ask, then stop.",
            complete_app_path_trace(),
        )

        self.assertLessEqual(result["overall"], 30)
        self.assertIn("fallbackLeak", result["checkFailures"])
        self.assertTrue(any(
            cap["name"] == "placeholderOrBroken" and cap["applied"]
            for cap in result["caps"]
        ))

    def test_placeholder_trap_honest_failure_notice_is_allowed(self):
        fixture = app_fixture()

        result = arena.local_judge(
            fixture,
            "I need one rep before I can coach this honestly. Record 60 seconds, then I will read the opener and close.",
            complete_app_path_trace(),
        )

        self.assertNotIn("fallbackLeak", result["checkFailures"])
        self.assertFalse(any(
            cap["name"] == "placeholderOrBroken" and cap["applied"]
            for cap in result["caps"]
        ))

    def test_trace_fallback_output_counts_as_fallback_leak_even_when_text_is_clean(self):
        fixture = app_fixture({
            "id": "fallback-clean-text",
            "evidence": ["latest rep close softened"],
            "memoryState": "Close work in progress.",
            "expectedCoachMove": "One close move.",
            "badAnswerExample": "Keep practicing.",
            "disqualifiers": [],
        })
        trace = complete_app_path_trace()
        trace["fallback"] = {"qualityGateAcceptedFallback": True}

        result = arena.local_judge(
            fixture,
            "Make the final sentence the ask, then stop.",
            trace,
        )

        self.assertLessEqual(result["overall"], 30)
        self.assertIn("fallbackLeak", result["checkFailures"])

    def test_sensitive_raw_report_voice_is_capped(self):
        fixture = app_fixture({
            "id": "trust-repair-report-voice",
            "turnType": "trustRepair",
            "userTurn": "ok prove it again",
            "goal": "Repair trust without report voice.",
            "evidence": ["latest rep had a rushed close"],
            "memoryState": "Storytelling close rush hypothesis.",
            "emotionalSignal": "correction",
            "expectedCoachMove": "Prove memory without dumping metrics.",
            "badAnswerExample": "Your score is 74 with 4 fillers.",
            "excellentAnswerExample": "Fair push. The setup held, then the ending rushed right after the payoff line.",
            "disqualifiers": [],
        })

        result = arena.local_judge(
            fixture,
            "This week you scored 74 over 95 seconds with only 4 fillers, then the ending rushed.",
            complete_app_path_trace(),
        )

        self.assertLessEqual(result["overall"], 50)
        self.assertIn("reportVoice", result["checkFailures"])

    def test_app_path_loader_preserves_source_readiness_fields(self):
        report = {
            "schemaVersion": "coach-chat-conversation-app-path-eval-v1",
            "surface": "text",
            "passesAppPathFloor": False,
            "summary": {
                "readinessWarnings": ["appPathFloorFailures"],
                "appPathFloorFailureCount": 2,
                "reliabilityIssueTurnCount": 1,
                "blockingReliabilityIssueTurnCount": 0,
                "targetReplyMismatchCount": 1,
            },
            "visionProductionReadiness": {
                "score": 18,
                "maximumAllowedScore": 20,
                "claim": "localEvaluationSubstrateOnly",
                "blockers": ["noLiveProviderTranscriptSweep"],
            },
            "conversationCount": 1,
            "turnCount": 1,
            "rows": [
                {
                    "conversationID": "c1",
                    "sourceFixtureID": "custom-source",
                    "turns": [
                        {
                            "turnIndex": 0,
                            "userTurn": "What should I do next?",
                            "finalCoachReply": "Run one 60-second rep.",
                            "targetCoachReply": "Run one 60-second rep with a clear close.",
                            "passesAppPathFloor": False,
                            "targetReplyMatched": False,
                            "semanticGateOutcome": "failed:unsupportedClosenessClaim",
                            "qualityGateOutcome": "fallback:typedAssessment",
                            "qualityGateEvents": [
                                "rejected:semantic:missingCaseAnchor",
                                "fallback:typedAssessment",
                            ],
                            "visionPassesProductionFloor": False,
                            "arenaTrace": complete_app_path_trace(),
                        }
                    ],
                }
            ],
        }
        fixture = {"id": "custom-app-path-fixture", "userTurn": "What should I do next?"}

        with tempfile.TemporaryDirectory() as temp_dir:
            report_path = Path(temp_dir) / "app-path.json"
            report_path.write_text(json.dumps(report), encoding="utf-8")

            fixtures, candidates, coverage = arena.load_app_path_candidates(
                report_path,
                [fixture],
            )

        self.assertEqual([item["id"] for item in fixtures], ["custom-app-path-fixture"])
        self.assertEqual(candidates["custom-app-path-fixture"]["reply"], "Run one 60-second rep.")
        self.assertEqual(coverage["source"], "appPathReport")
        self.assertIs(coverage["sourcePassesAppPathFloor"], False)
        self.assertEqual(coverage["sourceReadinessWarnings"], ["appPathFloorFailures"])
        self.assertEqual(coverage["sourceAppPathFloorFailureCount"], 2)
        self.assertEqual(coverage["sourceReliabilityIssueTurnCount"], 1)
        self.assertEqual(coverage["sourceBlockingReliabilityIssueTurnCount"], 0)
        self.assertEqual(coverage["sourceTargetReplyMismatchCount"], 1)
        self.assertEqual(coverage["sourceVisionProductionReadiness"]["score"], 18)
        self.assertEqual(coverage["sourceTraceGitCommits"], ["test"])
        self.assertEqual(coverage["sourceTraceMissingGitCommitCount"], 0)
        self.assertEqual(coverage["sourceTraceCoachSourceFingerprints"], ["sha256:test"])
        self.assertEqual(coverage["sourceTraceMissingCoachSourceFingerprintCount"], 0)
        self.assertEqual(coverage["sourceTraceWithArenaTraceCount"], 1)
        self.assertEqual(coverage["sourceAppPathFailureSampleCount"], 1)
        self.assertEqual(coverage["sourceAppPathFailureTotalCount"], 1)
        sample = coverage["sourceAppPathFailureSamples"][0]
        self.assertEqual(sample["conversationID"], "c1")
        self.assertEqual(sample["sourceFixtureID"], "custom-source")
        self.assertEqual(sample["turnIndex"], 0)
        self.assertEqual(
            sample["failureKinds"],
            [
                "appPathFloor",
                "qualityGate",
                "semanticGate",
                "targetReplyMismatch",
                "visionFloor",
            ],
        )

    def test_source_app_path_warnings_fail_real_pipeline_gate_without_hiding_scores(self):
        coverage = {
            "source": "appPathReport",
            "coveragePasses": True,
            "coverageFailures": [],
            "sourcePassesAppPathFloor": False,
            "sourceReadinessWarnings": [
                "appPathFloorFailures",
                "targetReplyMismatch",
            ],
            "sourceVisionProductionReadiness": {
                "score": 18,
                "maximumAllowedScore": 20,
                "claim": "localEvaluationSubstrateOnly",
                "blockers": ["noLiveProviderTranscriptSweep"],
                "summary": "Local evaluation only.",
            },
        }

        summary = arena.summarize([scored_result()], coverage)

        self.assertTrue(summary["passes"], "local score and coverage thresholds still pass")
        self.assertFalse(summary["realPipelineEvidencePasses"])
        self.assertEqual(summary["evidenceClaim"], "localEvaluationOnly")
        self.assertFalse(summary["visionProductionReady"])
        self.assertIn(
            "source Swift app-path report did not pass its app-path floor",
            summary["productionEvidenceFailures"],
        )
        self.assertIn(
            "source Swift app-path readiness warnings: appPathFloorFailures,targetReplyMismatch",
            summary["productionEvidenceFailures"],
        )

    def test_app_path_local_fixture_failures_block_ready_claim_even_when_average_passes(self):
        coverage = {
            "source": "appPathReport",
            "coveragePasses": True,
            "coverageFailures": [],
            "sourcePassesAppPathFloor": True,
            "sourceReadinessWarnings": [],
            "sourceFreshnessPasses": True,
            "sourceFreshnessFailures": [],
            "sourceVisionProductionReadiness": {
                "score": 18,
                "maximumAllowedScore": 20,
                "claim": "localEvaluationSubstrateOnly",
                "blockers": ["noLiveProviderTranscriptSweep"],
            },
        }

        summary = arena.summarize([scored_result(), weak_app_path_result()], coverage)

        self.assertFalse(summary["passes"])
        self.assertFalse(summary["scoreThresholdsPass"])
        self.assertFalse(summary["thresholdPasses"]["appPathFixtureFloor"])
        self.assertEqual(summary["failureCount"], 1)
        self.assertTrue(summary["traceQualityPasses"])
        self.assertFalse(summary["realPipelineEvidencePasses"])
        self.assertEqual(summary["evidenceClaim"], "localEvaluationOnly")
        self.assertIn(
            "1 app-path fixture(s) below local quality floor 70: weak-app-path",
            summary["productionEvidenceFailures"],
        )

    def test_near_excellent_sales_pitch_reply_gets_intervention_credit(self):
        fixture = gold_fixture("sales-pitch-031")

        result = arena.local_judge(
            fixture,
            "The likely gap is salience: reasons are there, but nothing for the listener to picture. So add one concrete customer example after the first claim, then return to the ask.",
            complete_app_path_trace(),
        )

        self.assertGreaterEqual(result["overall"], 70)
        self.assertNotIn("missingIntervention", result["checkFailures"])
        self.assertNotIn("missingEvidence", result["checkFailures"])

    def test_format_only_one_move_reply_does_not_require_evidence_anchor(self):
        fixture = gold_fixture("grammar-leak-048")

        result = arena.local_judge(
            fixture,
            "The close is the move, so make the final sentence the ask, then stop.",
            complete_app_path_trace(),
        )

        self.assertGreaterEqual(result["overall"], 70)
        self.assertEqual(result["checkFailures"], [])

    def test_verified_example_request_requires_the_verified_quote(self):
        fixture = gold_fixture("examples-from-sessions-010")

        result = arena.local_judge(
            fixture,
            "A safe example is the latest rep: the reasons were clear, but there was no concrete scene for the listener to picture. That shows the pattern because the logic arrives before the image.",
            complete_app_path_trace(),
        )

        self.assertLess(result["overall"], 70)
        self.assertIn("missingEvidence", result["checkFailures"])
        self.assertIn("missing verified quote anchor", result["failureReasons"])

    def test_source_freshness_fields_detect_missing_commit_and_dirty_coach_source(self):
        coverage = {
            "source": "appPathReport",
            "sourceTraceGitCommits": [],
            "sourceTraceMissingGitCommitCount": 3,
            "sourceTraceMissingCoachSourceFingerprintCount": 3,
        }

        fields = arena.app_path_source_freshness_fields(
            coverage,
            "abc1234",
            ["Noum/AICoachChatService.swift"],
        )

        self.assertFalse(fields["sourceFreshnessPasses"])
        self.assertEqual(fields["currentGitCommit"], "abc1234")
        self.assertEqual(
            fields["currentDirtyCoachSourceFiles"],
            ["Noum/AICoachChatService.swift"],
        )
        self.assertFalse(fields["sourceFingerprintMatchesCurrent"])
        self.assertIn(
            "3 source app-path trace(s) missing coach source fingerprint",
            fields["sourceFreshnessFailures"],
        )
        self.assertIn(
            "3 source app-path trace(s) missing source git commit",
            fields["sourceFreshnessFailures"],
        )
        self.assertIn(
            "source app-path report has no source git commit",
            fields["sourceFreshnessFailures"],
        )
        self.assertIn(
            "dirty coach source files after app-path dump: Noum/AICoachChatService.swift",
            fields["sourceFreshnessFailures"],
        )

    def test_source_fingerprint_allows_dirty_tree_app_path_trace_to_prove_fresh_source(self):
        coverage = {
            "source": "appPathReport",
            "sourceTraceGitCommits": ["older"],
            "sourceTraceMissingGitCommitCount": 0,
            "sourceTraceCoachSourceFingerprints": ["sha256:fresh"],
            "sourceTraceMissingCoachSourceFingerprintCount": 0,
        }

        fields = arena.app_path_source_freshness_fields(
            coverage,
            "current",
            ["Noum/AICoachChatService.swift"],
            current_source_fingerprint="sha256:fresh",
        )

        self.assertTrue(fields["sourceFreshnessPasses"])
        self.assertTrue(fields["sourceFingerprintMatchesCurrent"])
        self.assertEqual(fields["currentCoachSourceFingerprint"], "sha256:fresh")
        self.assertEqual(fields["sourceFreshnessFailures"], [])

    def test_write_app_path_source_sidecars_stamps_commit_and_fingerprint(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            payload = arena.write_app_path_source_sidecars(temp_dir)
            commit_path = Path(payload["gitCommitSidecar"])
            fingerprint_path = Path(payload["coachSourceFingerprintSidecar"])

            self.assertTrue(commit_path.exists())
            self.assertTrue(fingerprint_path.exists())
            self.assertEqual(commit_path.read_text(encoding="utf-8").strip(), payload["gitCommit"])
            self.assertEqual(
                fingerprint_path.read_text(encoding="utf-8").strip(),
                payload["coachSourceFingerprint"],
            )
            self.assertTrue(payload["coachSourceFingerprint"].startswith("sha256:"))

    def test_source_freshness_failures_block_real_pipeline_claim_without_hiding_scores(self):
        coverage = {
            "source": "appPathReport",
            "coveragePasses": True,
            "coverageFailures": [],
            "sourcePassesAppPathFloor": True,
            "sourceReadinessWarnings": [],
            "sourceFreshnessPasses": False,
            "sourceFreshnessFailures": [
                "source app-path report has no source git commit",
            ],
            "sourceVisionProductionReadiness": {
                "score": 18,
                "maximumAllowedScore": 20,
                "claim": "localEvaluationSubstrateOnly",
                "blockers": ["noLiveProviderTranscriptSweep"],
            },
        }

        summary = arena.summarize([scored_result()], coverage)

        self.assertTrue(summary["passes"], "local score and coverage thresholds still pass")
        self.assertFalse(summary["realPipelineEvidencePasses"])
        self.assertEqual(summary["evidenceClaim"], "localEvaluationOnly")
        self.assertIn(
            "source Swift app-path freshness: source app-path report has no source git commit",
            summary["productionEvidenceFailures"],
        )

    def test_markdown_prints_vision_and_real_pipeline_boundaries(self):
        coverage = {
            "source": "appPathReport",
            "coveragePasses": True,
            "coverageFailures": [],
            "sourcePassesAppPathFloor": False,
            "sourceReadinessWarnings": ["appPathFloorFailures"],
            "sourceAppPathFloorFailureCount": 1,
            "sourceTargetReplyMismatchCount": 1,
            "sourceAppPathFailureSampleCount": 1,
            "sourceAppPathFailureTotalCount": 1,
            "sourceTraceGitCommits": [],
            "sourceTraceMissingGitCommitCount": 2,
            "sourceTraceCoachSourceFingerprints": ["sha256:test"],
            "sourceTraceMissingCoachSourceFingerprintCount": 0,
            "currentGitCommit": "abc1234",
            "currentCoachSourceFingerprint": "sha256:test",
            "sourceFingerprintMatchesCurrent": True,
            "currentDirtyCoachSourceFiles": ["Noum/AICoachChatService.swift"],
            "sourceFreshnessPasses": False,
            "sourceFreshnessFailures": ["source app-path report has no source git commit"],
            "sourceAppPathFailureSamples": [
                {
                    "conversationID": "c1",
                    "sourceFixtureID": "custom-source",
                    "turnIndex": 0,
                    "failureKinds": ["appPathFloor", "targetReplyMismatch"],
                    "semanticGateOutcome": "passed",
                    "qualityGateOutcome": "fallback:typedAssessment",
                }
            ],
            "sourceVisionProductionReadiness": {
                "score": 18,
                "maximumAllowedScore": 20,
                "claim": "localEvaluationSubstrateOnly",
                "blockers": ["noLiveProviderTranscriptSweep"],
            },
        }
        report = {
            "generatedAt": "2026-07-08T12:00:00+00:00",
            "candidate": "app-path.json",
            "coverage": coverage,
            "summary": arena.summarize([scored_result()], coverage),
            "results": [scored_result()],
        }

        markdown = arena.render_markdown(report)

        self.assertIn("## VISION Readiness Boundary", markdown)
        self.assertIn("## Real-Pipeline Evidence", markdown)
        self.assertIn("Production ready: `False`", markdown)
        self.assertIn("Real-pipeline evidence passes: `False`", markdown)
        self.assertIn("### Source App-Path Failure Samples", markdown)
        self.assertIn("`custom-source` / `c1` turn `0`", markdown)
        self.assertIn("Source freshness passes: `False`", markdown)
        self.assertIn("Source fingerprint matches current: `True`", markdown)
        self.assertIn("source app-path report has no source git commit", markdown)


if __name__ == "__main__":
    unittest.main()
