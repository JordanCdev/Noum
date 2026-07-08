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


class AppPathBoundaryTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
