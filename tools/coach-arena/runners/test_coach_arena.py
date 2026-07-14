import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import coach_arena as arena


def complete_app_path_trace():
    return {
        "candidateSource": "appPathReport",
        "context": {
            "conversationID": "c1",
            "surface": "text",
            "semanticGateExpectation": "passedWithTypedAssessment",
            "semanticGateProvenanceMismatch": False,
        },
        "retrieval": {"retrievedCardIDs": ["card-1"], "queryPresent": True},
        "memory": {
            "turnDepth": "groundedRead",
            "typedAssessmentPresent": True,
            "assessmentConfidence": 0.42,
            "proofTestHash": "proof-1",
        },
        "reasoning": {
            "semanticGateOutcome": "passed",
            "qualityGateOutcome": "accepted",
        },
        "prompt": {"source": "CoachReplyPipeline app-path test"},
        "provider": {"name": "mocked-provider"},
        "rawReply": "Run one 60-second rep.",
        "finalReply": "Run one 60-second rep.",
        "issues": [],
        "latency": {
            "timeToFirstVisibleTokenMs": 120,
            "timeToFirstVisibleTokenSource": "finalReplyCommit",
            "timeToCompleteReplyMs": 400,
        },
        "cache": {
            "sourcePath": "/tmp/source.json",
            "assessmentCacheHit": True,
            "assessmentCacheAgeMs": 200,
            "trajectoryCacheHit": True,
        },
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
    result["reply"] = "Name the opener first, then run one quieter close."
    result["trace"] = complete_app_path_trace()
    result["trace"]["rawReply"] = result["reply"]
    result["trace"]["finalReply"] = result["reply"]
    result["trace"]["memory"]["assessmentConfidence"] = 0.58
    result["trace"]["memory"]["proofTestHash"] = "proof-2"
    result["judge"] = {
        "overall": 69,
        "checkFailures": [],
        "failureReasons": ["missing practical intervention"],
    }
    return result


def scored_trace_result(index, *, reply=None, trajectory_cache_hit=True):
    result = scored_result()
    rendered = reply or f"Run one 60-second rep for case {index}."
    result["fixture"] = {
        "id": f"fixture-{index}",
        "turnType": "groundedRead",
    }
    result["reply"] = rendered
    result["trace"] = complete_app_path_trace()
    result["trace"]["rawReply"] = rendered
    result["trace"]["finalReply"] = rendered
    result["trace"]["memory"]["assessmentConfidence"] = 0.42 + ((index % 4) * 0.04)
    result["trace"]["memory"]["proofTestHash"] = f"proof-{index}"
    result["trace"]["cache"]["trajectoryCacheHit"] = trajectory_cache_hit
    return result


def neutral_app_path_result():
    result = scored_result()
    result["fixture"] = {
        "id": "declared-neutral-fixture",
        "turnType": "quickMove",
    }
    trace = result["trace"]
    trace["context"]["semanticGateExpectation"] = (
        "notEvaluatedWithoutTypedAssessment"
    )
    trace["memory"]["turnDepth"] = "quickMove"
    trace["memory"]["typedAssessmentPresent"] = False
    trace["memory"].pop("assessmentConfidence")
    trace["memory"].pop("proofTestHash")
    trace["reasoning"]["semanticGateOutcome"] = "notEvaluated"
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
    def test_declared_neutral_trace_does_not_require_styled_assessment_fields(self):
        audit = arena.trace_quality_audit([neutral_app_path_result()])

        self.assertTrue(audit["passes"], audit["failures"])
        self.assertEqual(
            audit["semanticAssessmentProvenance"]["neutralCount"],
            1,
        )
        self.assertEqual(audit["semanticAssessmentProvenance"]["invalidCount"], 0)
        self.assertEqual(audit["assessmentConfidence"]["missingCount"], 0)
        self.assertEqual(audit["proofTest"]["missingCount"], 0)

    def test_ungrounded_neutral_empty_retrieval_still_fails_trace_quality(self):
        result = neutral_app_path_result()
        result["trace"]["retrieval"] = {
            "retrievedCardIDs": [],
            "queryPresent": True,
            "hasDiagnosis": False,
            "diagnosticReason": "No cards matched turn",
        }

        audit = arena.trace_quality_audit([result])

        self.assertFalse(audit["passes"])
        self.assertEqual(audit["retrieval"]["emptyRetrievedCardsCount"], 1)
        self.assertEqual(audit["retrieval"]["allowedEmptyRetrievedCardsCount"], 0)

    def test_declared_neutral_trace_rejects_fabricated_assessment_telemetry(self):
        result = neutral_app_path_result()
        result["trace"]["memory"]["assessmentConfidence"] = 0.20
        result["trace"]["memory"]["proofTestHash"] = "fabricated-neutral-proof"

        audit = arena.trace_quality_audit([result])

        self.assertFalse(audit["passes"])
        self.assertEqual(audit["semanticAssessmentProvenance"]["invalidCount"], 1)
        self.assertTrue(any(
            "invalid semantic assessment provenance" in failure
            for failure in audit["failures"]
        ))

    def test_styled_trace_missing_assessment_fields_fails_closed(self):
        result = scored_result()
        result["trace"]["memory"].pop("assessmentConfidence")
        result["trace"]["memory"].pop("proofTestHash")

        audit = arena.trace_quality_audit([result])

        self.assertFalse(audit["passes"])
        self.assertEqual(audit["semanticAssessmentProvenance"]["invalidCount"], 1)
        self.assertEqual(audit["assessmentConfidence"]["missingCount"], 1)
        self.assertEqual(audit["proofTest"]["missingCount"], 1)

    def test_unknown_and_legacy_trace_provenance_fail_closed(self):
        unknown = scored_result()
        unknown["trace"]["context"]["semanticGateExpectation"] = (
            "unknownFixtureFailClosed"
        )
        legacy = scored_trace_result(2)
        legacy["trace"]["context"].pop("semanticGateExpectation")

        audit = arena.trace_quality_audit([unknown, legacy])

        self.assertFalse(audit["passes"])
        self.assertEqual(audit["semanticAssessmentProvenance"]["invalidCount"], 2)

    def test_app_path_adapter_carries_row_owned_neutral_provenance(self):
        exported = complete_app_path_trace()
        exported["context"].pop("semanticGateExpectation")
        exported["context"].pop("semanticGateProvenanceMismatch")
        exported["memory"].pop("typedAssessmentPresent")
        exported["memory"].pop("assessmentConfidence")
        exported["memory"].pop("proofTestHash")
        exported["reasoning"]["semanticGateOutcome"] = "notEvaluated"
        turn = {
            "turnIndex": 0,
            "userTurn": "What should I do next?",
            "semanticGateExpectation": "notEvaluatedWithoutTypedAssessment",
            "semanticGateOutcome": "notEvaluated",
            "typedAssessmentPresent": False,
            "assessmentConfidence": None,
            "proofTestHash": None,
            "arenaTrace": exported,
        }

        trace = arena.app_path_trace(
            {"conversationID": "neutral", "sourceFixtureID": "neutral-source"},
            turn,
            {"surface": "text"},
            Path("/tmp/app-path.json"),
            "explicitAlias",
        )

        self.assertEqual(
            trace["context"]["semanticGateExpectation"],
            "notEvaluatedWithoutTypedAssessment",
        )
        self.assertIs(trace["memory"]["typedAssessmentPresent"], False)
        self.assertFalse(trace["context"]["semanticGateProvenanceMismatch"])
        self.assertEqual(arena.trace_semantic_gate_provenance(trace), "neutral")

    def test_thin_evidence_empty_retrieval_is_intentional(self):
        result = scored_result()
        result["trace"]["memory"]["assessmentConfidence"] = 0.20
        result["trace"]["retrieval"] = {
            "retrievedCardIDs": [],
            "queryPresent": True,
            "hasDiagnosis": False,
            "diagnosticReason": "No cards matched turn",
        }

        audit = arena.trace_quality_audit([result])

        self.assertTrue(audit["passes"])
        self.assertEqual(audit["retrieval"]["emptyRetrievedCardsCount"], 0)
        self.assertEqual(audit["retrieval"]["allowedEmptyRetrievedCardsCount"], 1)

    def test_evidence_bearing_empty_retrieval_still_fails_trace_quality(self):
        result = scored_result()
        result["trace"]["memory"]["assessmentConfidence"] = 0.21
        result["trace"]["retrieval"] = {
            "retrievedCardIDs": [],
            "queryPresent": True,
            "hasDiagnosis": False,
            "diagnosticReason": "No cards matched turn",
        }

        audit = arena.trace_quality_audit([result])

        self.assertFalse(audit["passes"])
        self.assertEqual(audit["retrieval"]["emptyRetrievedCardsCount"], 1)
        self.assertEqual(audit["retrieval"]["allowedEmptyRetrievedCardsCount"], 0)

    def test_trace_quality_requires_trajectory_cache_telemetry(self):
        result = scored_result()
        del result["trace"]["cache"]["trajectoryCacheHit"]

        audit = arena.trace_quality_audit([result])

        self.assertFalse(audit["passes"])
        self.assertEqual(audit["trajectoryCache"]["missingCount"], 1)
        self.assertTrue(any(
            "missing trajectoryCacheHit" in failure
            for failure in audit["failures"]
        ))

    def test_trace_quality_rejects_all_cold_trajectory_cache(self):
        results = [
            scored_trace_result(index, trajectory_cache_hit=False)
            for index in range(10)
        ]

        audit = arena.trace_quality_audit(results)

        self.assertFalse(audit["passes"])
        self.assertEqual(audit["trajectoryCache"]["hitCount"], 0)
        self.assertEqual(audit["trajectoryCache"]["minHitCount"], 1)
        self.assertTrue(any(
            "trajectoryCacheHit true for 0 real-pipeline fixtures" in failure
            for failure in audit["failures"]
        ))

    def test_trace_quality_rejects_reused_final_reply_hash(self):
        results = [
            scored_trace_result(1, reply="Make the final sentence the ask, then stop."),
            scored_trace_result(2, reply="Make the final sentence the ask, then stop."),
        ]

        audit = arena.trace_quality_audit(results)

        self.assertFalse(audit["passes"])
        self.assertEqual(audit["finalReply"]["maxHashReuse"], 2)
        self.assertTrue(any(
            "finalReply reused exactly across 2 real-pipeline fixtures" in failure
            for failure in audit["failures"]
        ))

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

    def test_clean_typed_assessment_fallback_can_score_as_deterministic_coaching(self):
        fixture = gold_fixture("filler-pressure-007")
        trace = complete_app_path_trace()
        trace["fallback"] = {
            "qualityGateAcceptedFallback": True,
            "typedAssessmentFallbackApplied": True,
        }
        trace["reasoning"]["qualityGateOutcome"] = "fallback:typedAssessment"
        reply = (
            "Your last pressure rep had 6 fillers, mostly before the close, "
            "so the pressure leak is the final sentence. Next rep, replace the "
            "urge with one silent beat before the final sentence, then finish the ask."
        )

        result = arena.local_judge(fixture, reply, trace)

        self.assertNotIn("fallbackLeak", result["checkFailures"])
        self.assertFalse(any(
            cap["name"] == "placeholderOrBroken" and cap["applied"]
            for cap in result["caps"]
        ))

    def test_generic_typed_assessment_fallback_still_counts_as_fallback_leak(self):
        fixture = gold_fixture("filler-pressure-007")
        trace = complete_app_path_trace()
        trace["fallback"] = {
            "qualityGateAcceptedFallback": True,
            "typedAssessmentFallbackApplied": True,
        }
        trace["reasoning"]["qualityGateOutcome"] = "fallback:typedAssessment"

        result = arena.local_judge(
            fixture,
            "Your last rep gives one usable signal so far, so run one answer and separate semantic words from filler words before cutting anything.",
            trace,
        )

        self.assertLessEqual(result["overall"], 30)
        self.assertIn("fallbackLeak", result["checkFailures"])

    def test_target_matching_deterministic_assessment_fallback_still_exposes_pipeline_failure(self):
        fixture = app_fixture({
            "id": "not-easy-deterministic-repair",
            "turnType": "trustRepair",
            "userTurn": "It's not easy.",
            "goal": "Handle pressure without flattening the user's frustration.",
            "evidence": ["pressure disagreement drill"],
            "memoryState": "Sentence one carries the social risk.",
            "expectedCoachMove": "Validate the difficulty and prescribe a smaller disagreement rep.",
            "badAnswerExample": "Try harder and run the drill again.",
            "excellentAnswerExample": (
                "Fair push: no, it is not easy. The hard part is that sentence one carries the social risk, "
                "so test a smaller version in the next rep: say only the disagreement and one calm reason, "
                "then stop before defending it."
            ),
            "disqualifiers": [],
        })
        trace = complete_app_path_trace()
        trace["fallback"] = {
            "qualityGateAcceptedFallback": True,
            "deterministicAssessmentFallbackApplied": True,
        }
        trace["reasoning"]["qualityGateOutcome"] = "fallback:deterministicAssessmentAfterContentRejected"
        reply = fixture["excellentAnswerExample"]

        result = arena.local_judge(fixture, reply, trace)

        self.assertIn("fallbackLeak", result["checkFailures"])
        self.assertLessEqual(result["overall"], 30)
        self.assertTrue(any(
            cap["name"] == "placeholderOrBroken" and cap["applied"]
            for cap in result["caps"]
        ))

    def test_generic_deterministic_assessment_fallback_still_counts_as_fallback_leak(self):
        fixture = gold_fixture("filler-pressure-007")
        trace = complete_app_path_trace()
        trace["fallback"] = {
            "qualityGateAcceptedFallback": True,
            "deterministicAssessmentFallbackApplied": True,
        }
        trace["reasoning"]["qualityGateOutcome"] = "fallback:deterministicAssessmentAfterContentRejected"

        result = arena.local_judge(
            fixture,
            "Your last rep gives one usable signal so far. Run one more rep and separate semantic words from filler words before cutting anything.",
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

    def test_app_path_failure_sampler_accepts_clean_declared_neutral_turn(self):
        report = {
            "rows": [{
                "conversationID": "neutral-conversation",
                "sourceFixtureID": "cold-start-interview-baseline",
                "turns": [{
                    "turnIndex": 0,
                    "passesAppPathFloor": True,
                    "targetReplyMatched": True,
                    "semanticGateExpectation": "notEvaluatedWithoutTypedAssessment",
                    "semanticGateOutcome": "notEvaluated",
                    "typedAssessmentPresent": False,
                    "visionPassesProductionFloor": True,
                    "qualityGateEvents": ["passed"],
                }],
            }],
        }

        samples, total = arena.source_app_path_failure_samples(report)

        self.assertEqual(samples, [])
        self.assertEqual(total, 0)

    def test_app_path_failure_sampler_rejects_fabricated_neutral_assessment(self):
        report = {
            "rows": [{
                "conversationID": "fabricated-neutral-conversation",
                "sourceFixtureID": "cold-start-interview-baseline",
                "turns": [{
                    "turnIndex": 0,
                    "passesAppPathFloor": True,
                    "targetReplyMatched": True,
                    "semanticGateExpectation": "notEvaluatedWithoutTypedAssessment",
                    "semanticGateOutcome": "passed",
                    "typedAssessmentPresent": True,
                    "visionPassesProductionFloor": True,
                    "qualityGateEvents": ["passed"],
                }],
            }],
        }

        samples, total = arena.source_app_path_failure_samples(report)

        self.assertEqual(total, 1)
        self.assertEqual(samples[0]["failureKinds"], ["semanticGate"])
        self.assertEqual(
            samples[0]["semanticGateExpectation"],
            "notEvaluatedWithoutTypedAssessment",
        )
        self.assertIs(samples[0]["typedAssessmentPresent"], True)

    def test_app_path_failure_sampler_requires_passed_typed_styled_assessment(self):
        styled_base = {
            "passesAppPathFloor": True,
            "targetReplyMatched": True,
            "semanticGateExpectation": "passedWithTypedAssessment",
            "visionPassesProductionFloor": True,
            "qualityGateEvents": ["passed"],
        }
        report = {
            "rows": [{
                "conversationID": "styled-conversation",
                "sourceFixtureID": "filler-pressure-prescription",
                "turns": [
                    {
                        **styled_base,
                        "turnIndex": 0,
                        "semanticGateOutcome": "passed",
                        "typedAssessmentPresent": True,
                    },
                    {
                        **styled_base,
                        "turnIndex": 1,
                        "semanticGateOutcome": "passed",
                        "typedAssessmentPresent": False,
                    },
                    {
                        **styled_base,
                        "turnIndex": 2,
                        "semanticGateOutcome": "notEvaluated",
                        "typedAssessmentPresent": True,
                    },
                ],
            }],
        }

        samples, total = arena.source_app_path_failure_samples(report)

        self.assertEqual(total, 2)
        self.assertEqual([sample["turnIndex"] for sample in samples], [1, 2])
        self.assertTrue(all(
            sample["failureKinds"] == ["semanticGate"]
            for sample in samples
        ))

    def test_app_path_failure_sampler_fails_closed_for_legacy_and_unknown_provenance(self):
        clean_base = {
            "passesAppPathFloor": True,
            "targetReplyMatched": True,
            "semanticGateOutcome": "passed",
            "visionPassesProductionFloor": True,
            "qualityGateEvents": ["passed"],
        }
        report = {
            "rows": [{
                "conversationID": "unknown-provenance-conversation",
                "sourceFixtureID": "future-app-path-fixture",
                "turns": [
                    {
                        **clean_base,
                        "turnIndex": 0,
                    },
                    {
                        **clean_base,
                        "turnIndex": 1,
                        "semanticGateExpectation": "unknownFixtureFailClosed",
                        "typedAssessmentPresent": True,
                    },
                ],
            }],
        }

        samples, total = arena.source_app_path_failure_samples(report)

        self.assertEqual(total, 2)
        self.assertEqual([sample["turnIndex"] for sample in samples], [0, 1])
        self.assertTrue(all(
            sample["failureKinds"] == ["semanticGate"]
            for sample in samples
        ))

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
            "sourceTraceGitCommits": ["current"],
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

    def test_app_path_regeneration_preflight_blocks_missing_dump(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            result = arena.app_path_regeneration_preflight(
                temp_dir,
                current_commit="abc1234",
                dirty_source_files=[],
                current_source_fingerprint="sha256:fresh",
            )

        self.assertFalse(result["passes"])
        self.assertIn("missingAppPathDump", result["blockers"])
        self.assertIn("missingSourceGitCommitSidecar", result["blockers"])
        self.assertIn("missingSourceCoachFingerprintSidecar", result["blockers"])
        self.assertEqual(result["traceCount"], 0)
        self.assertTrue(any("CoachChatConversationArtifactDumpXCTest" in step for step in result["nextSteps"]))

    def test_app_path_regeneration_preflight_blocks_stale_trace_fingerprint(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / arena.SOURCE_GIT_COMMIT_SIDECAR).write_text("abc1234\n", encoding="utf-8")
            (root / arena.SOURCE_FINGERPRINT_SIDECAR).write_text("sha256:fresh\n", encoding="utf-8")
            (root / arena.APP_PATH_DUMP_NAME).write_text(json.dumps({
                "passesAppPathFloor": True,
                "rows": [{
                    "turns": [{
                        "arenaTrace": {
                            "gitCommit": "abc1234",
                            "sourceFingerprint": "sha256:old",
                        }
                    }]
                }]
            }), encoding="utf-8")

            result = arena.app_path_regeneration_preflight(
                temp_dir,
                current_commit="abc1234",
                dirty_source_files=["Noum/AICoachChatService.swift"],
                current_source_fingerprint="sha256:fresh",
            )

        self.assertFalse(result["passes"])
        self.assertIn("traceCoachFingerprintStale", result["blockers"])
        self.assertIn("dirtyCoachSourceAfterDump", result["blockers"])
        self.assertNotIn("sourceCoachFingerprintSidecarStale", result["blockers"])
        self.assertEqual(result["traceCoachSourceFingerprints"], ["sha256:old"])
        self.assertTrue(any("run.sh app-path-source" in step for step in result["nextSteps"]))

    def test_app_path_regeneration_preflight_passes_current_dump(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / arena.SOURCE_GIT_COMMIT_SIDECAR).write_text("abc1234\n", encoding="utf-8")
            (root / arena.SOURCE_FINGERPRINT_SIDECAR).write_text("sha256:fresh\n", encoding="utf-8")
            (root / arena.APP_PATH_DUMP_NAME).write_text(json.dumps({
                "passesAppPathFloor": True,
                "rows": [{
                    "turns": [{
                        "arenaTrace": {
                            "gitCommit": "abc1234",
                            "sourceFingerprint": "sha256:fresh",
                        }
                    }]
                }]
            }), encoding="utf-8")

            result = arena.app_path_regeneration_preflight(
                temp_dir,
                current_commit="abc1234",
                dirty_source_files=[],
                current_source_fingerprint="sha256:fresh",
            )

        self.assertTrue(result["passes"])
        self.assertEqual(result["blockers"], [])
        self.assertEqual(result["traceCount"], 1)
        self.assertEqual(result["traceGitCommits"], ["abc1234"])

    def test_app_path_regeneration_preflight_passes_clean_report_only_descendant(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / arena.SOURCE_GIT_COMMIT_SIDECAR).write_text("abc1234\n", encoding="utf-8")
            (root / arena.SOURCE_FINGERPRINT_SIDECAR).write_text("sha256:fresh\n", encoding="utf-8")
            (root / arena.APP_PATH_DUMP_NAME).write_text(json.dumps({
                "passesAppPathFloor": True,
                "rows": [{
                    "turns": [{
                        "arenaTrace": {
                            "gitCommit": "abc1234",
                            "sourceFingerprint": "sha256:fresh",
                        }
                    }]
                }]
            }), encoding="utf-8")

            documentation_audit = {
                "ancestor": "abc1234",
                "descendant": "def5678",
                "changedPaths": ["docs/CURRENT_STATE.md"],
                "behaviorSourcePaths": [],
                "error": None,
                "passes": True,
            }
            with mock.patch.object(
                arena.readiness_gate,
                "clean_ancestor_descendant_audit",
                return_value=documentation_audit,
            ):
                result = arena.app_path_regeneration_preflight(
                    temp_dir,
                    current_commit="def5678",
                    dirty_source_files=[],
                    current_source_fingerprint="sha256:fresh",
                )

        self.assertTrue(result["passes"])
        self.assertEqual(result["blockers"], [])
        self.assertIn("sourceGitCommitSidecarCleanAncestor", result["warnings"])
        self.assertIn("traceGitCommitCleanAncestor", result["warnings"])
        self.assertEqual(result["cleanAncestorBehaviorSourcePaths"], [])

    def test_app_path_regeneration_preflight_blocks_unrelated_matching_commit(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / arena.SOURCE_GIT_COMMIT_SIDECAR).write_text("abc1234\n", encoding="utf-8")
            (root / arena.SOURCE_FINGERPRINT_SIDECAR).write_text("sha256:fresh\n", encoding="utf-8")
            (root / arena.APP_PATH_DUMP_NAME).write_text(json.dumps({
                "passesAppPathFloor": True,
                "rows": [{
                    "turns": [{
                        "arenaTrace": {
                            "gitCommit": "abc1234",
                            "sourceFingerprint": "sha256:fresh",
                        }
                    }]
                }]
            }), encoding="utf-8")

            rejected_audit = {
                "ancestor": "abc1234",
                "descendant": "def5678",
                "changedPaths": [],
                "behaviorSourcePaths": [],
                "error": "notAncestor",
                "passes": False,
            }
            with mock.patch.object(
                arena.readiness_gate,
                "clean_ancestor_descendant_audit",
                return_value=rejected_audit,
            ):
                result = arena.app_path_regeneration_preflight(
                    temp_dir,
                    current_commit="def5678",
                    dirty_source_files=[],
                    current_source_fingerprint="sha256:fresh",
                )

        self.assertFalse(result["passes"])
        self.assertIn("sourceGitCommitSidecarStale", result["blockers"])
        self.assertIn("traceGitCommitStale", result["blockers"])

    def test_source_freshness_fields_reject_behavior_source_descendant(self):
        coverage = {
            "source": "appPathReport",
            "sourceTraceGitCommits": ["abc1234"],
            "sourceTraceMissingGitCommitCount": 0,
            "sourceTraceCoachSourceFingerprints": ["sha256:fresh"],
            "sourceTraceMissingCoachSourceFingerprintCount": 0,
        }
        behavior_audit = {
            "ancestor": "abc1234",
            "descendant": "def5678",
            "changedPaths": ["Noum/PracticeSupport.swift"],
            "behaviorSourcePaths": ["Noum/PracticeSupport.swift"],
            "error": None,
            "passes": False,
        }

        with mock.patch.object(
            arena.readiness_gate,
            "clean_ancestor_descendant_audit",
            return_value=behavior_audit,
        ):
            fields = arena.app_path_source_freshness_fields(
                coverage,
                "def5678",
                [],
                current_source_fingerprint="sha256:fresh",
            )

        self.assertFalse(fields["sourceFreshnessPasses"])
        self.assertEqual(
            fields["cleanAncestorBehaviorSourcePaths"],
            ["Noum/PracticeSupport.swift"],
        )

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

    def test_coach_source_fingerprint_covers_typed_brain_owners(self):
        expected = {
            "Noum/AICoachChatService.swift",
            "Noum/CoachReplyPipeline.swift",
            "Noum/CoachTurnDepth.swift",
            "Noum/TurnDepthClassifier.swift",
            "Noum/CoachAssessment.swift",
            "Noum/CoachAssessmentCache.swift",
            "Noum/CoachReasoningPass.swift",
            "Noum/CoachPromptBundle.swift",
            "Noum/CoachReliabilityGate.swift",
            "Noum/GoalRubric.swift",
            "Noum/GoalRubricStore.swift",
            "Noum/UserTrajectoryCache.swift",
            "Noum/UserTrajectorySnapshot.swift",
            "Noum/KnowledgeRetriever.swift",
            "Noum/KnowledgeSemanticReranker.swift",
            "Noum/CoachingKnowledgeBase.swift",
            "Noum/PrimaryFocusMemory.swift",
        }

        self.assertTrue(
            expected.issubset(set(arena.COACH_SOURCE_STATUS_PATHS)),
            expected.difference(set(arena.COACH_SOURCE_STATUS_PATHS)),
        )

    def test_coach_source_fingerprint_changes_when_brain_file_changes(self):
        original_root = arena.ROOT
        try:
            with tempfile.TemporaryDirectory() as temp_dir:
                temp_root = Path(temp_dir)
                coach_file = temp_root / "Noum" / "CoachAssessment.swift"
                coach_file.parent.mkdir(parents=True)
                coach_file.write_text("struct CoachAssessment { let version = 1 }\n", encoding="utf-8")
                arena.ROOT = temp_root

                first = arena.coach_source_fingerprint(paths=["Noum/CoachAssessment.swift"])
                coach_file.write_text("struct CoachAssessment { let version = 2 }\n", encoding="utf-8")
                second = arena.coach_source_fingerprint(paths=["Noum/CoachAssessment.swift"])
        finally:
            arena.ROOT = original_root

        self.assertNotEqual(first, second)

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

    def test_ten_conversation_sample_labels_stale_app_path_source(self):
        coverage = {
            "source": "appPathReport",
            "coveragePasses": True,
            "coverageFailures": [],
            "sourcePassesAppPathFloor": True,
            "sourceReadinessWarnings": [],
            "sourceFreshnessPasses": True,
            "sourceFreshnessFailures": [],
            "currentGitCommit": "abc1234",
            "sourceTraceGitCommits": ["abc1234"],
            "currentCoachSourceFingerprint": "sha256:report",
            "sourceTraceCoachSourceFingerprints": ["sha256:report"],
            "sourceVisionProductionReadiness": {
                "score": 18,
                "maximumAllowedScore": 20,
                "claim": "localEvaluationSubstrateOnly",
                "blockers": ["noLiveProviderTranscriptSweep"],
            },
        }
        result = scored_result()
        result["fixture"] = app_fixture({
            "id": "stale-source-sample",
            "turnType": "groundedRead",
            "userTurn": "What should I practice next?",
            "goal": "Sound calmer in leadership updates.",
        })
        report = {
            "coverage": coverage,
            "summary": arena.summarize([result], coverage),
            "results": [result],
        }
        source_audit = {
            "passes": False,
            "sidecarGitCommit": "abc1234",
            "sidecarCoachFingerprint": "sha256:sidecar",
            "reportGitCommits": ["abc1234"],
            "reportCoachFingerprints": ["sha256:report"],
            "mismatches": [
                {
                    "label": "sourceCoachFingerprint",
                    "sidecar": "sha256:sidecar",
                    "reportValues": ["sha256:report"],
                }
            ],
        }

        markdown = arena.render_ten_conversations(report, source_audit=source_audit)

        self.assertIn("Evidence status: STALE APP-PATH SOURCE", markdown)
        self.assertIn("Do not treat these conversations as current-source proof", markdown)
        self.assertIn("Evidence: `stale app-path source`", markdown)
        self.assertIn("diagnostic evidence only, not current-source proof", markdown)
        self.assertIn("Current git commit: `abc1234`", markdown)
        self.assertIn("Report-internal source freshness passes: `True`", markdown)
        self.assertIn("Sidecar source freshness passes: `False`", markdown)
        self.assertIn("Report trace git commit(s): `abc1234`", markdown)
        self.assertIn("Current coach source fingerprint: `sha256:report`", markdown)
        self.assertIn("Report trace coach source fingerprint(s): `sha256:report`", markdown)
        self.assertIn("Sidecar coach source fingerprint: `sha256:sidecar`", markdown)
        self.assertIn("Sidecar/report mismatch `sourceCoachFingerprint`", markdown)

    def test_ten_conversation_sample_labels_current_app_path_source(self):
        coverage = {
            "source": "appPathReport",
            "coveragePasses": True,
            "coverageFailures": [],
            "sourcePassesAppPathFloor": True,
            "sourceReadinessWarnings": [],
            "sourceFreshnessPasses": True,
            "sourceFreshnessFailures": [],
            "currentGitCommit": "abc1234",
            "sourceTraceGitCommits": ["abc1234"],
            "currentCoachSourceFingerprint": "sha256:fresh",
            "sourceTraceCoachSourceFingerprints": ["sha256:fresh"],
            "sourceVisionProductionReadiness": {
                "score": 18,
                "maximumAllowedScore": 20,
                "claim": "localEvaluationSubstrateOnly",
                "blockers": ["noLiveProviderTranscriptSweep"],
            },
        }
        result = scored_result()
        result["fixture"] = app_fixture({
            "id": "fresh-source-sample",
            "turnType": "groundedRead",
            "userTurn": "What should I practice next?",
            "goal": "Sound calmer in leadership updates.",
        })
        report = {
            "coverage": coverage,
            "summary": arena.summarize([result], coverage),
            "results": [result],
        }

        markdown = arena.render_ten_conversations(
            report,
            source_audit={
                "passes": True,
                "sidecarGitCommit": "abc1234",
                "sidecarCoachFingerprint": "sha256:fresh",
                "reportGitCommits": ["abc1234"],
                "reportCoachFingerprints": ["sha256:fresh"],
                "mismatches": [],
            },
        )

        self.assertIn("Evidence status: CURRENT APP-PATH SOURCE", markdown)
        self.assertIn("Real-pipeline evidence passes: `True`", markdown)
        self.assertIn("Evidence: `current app-path source`", markdown)
        self.assertNotIn("Do not treat these conversations as current-source proof", markdown)

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
        self.assertIn("Evidence status: `stale app-path source`", markdown)
        self.assertIn("`custom-source` / `c1` turn `0`", markdown)
        self.assertIn("Source freshness passes: `False`", markdown)
        self.assertIn("Source fingerprint matches current: `True`", markdown)
        self.assertIn("source app-path report has no source git commit", markdown)


if __name__ == "__main__":
    unittest.main()
