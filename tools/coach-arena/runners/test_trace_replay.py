import copy
import unittest

import trace_replay


def valid_bundle():
    return {
        "schemaVersion": trace_replay.SCHEMA_VERSION,
        "privacy": {
            "contentFree": True,
            "includesUserText": False,
            "includesTranscript": False,
            "includesPrompt": False,
            "includesResponse": False,
            "includesAccountIdentifier": False,
            "includesCredentials": False,
        },
        "trace": {
            "traceID": "12345678-1234-4234-8234-123456789abc",
            "terminalState": "retryableError",
            "terminalStatus": "retryableError",
            "terminalEventCount": 1,
            "terminalContractViolation": False,
            "events": [
                {"stage": "coach.accepted"},
                {"stage": "coach.classified"},
                {"stage": "coach.providerStarted"},
                {"stage": "coach.providerRefused"},
                {"stage": "coach.persisted"},
                {"stage": "coach.uiCommitted"},
                {"stage": "coach.terminal"},
            ],
        },
        "reproduction": {
            "mode": "content-free-terminal-path-replay",
            "semanticFixtureRequired": True,
        },
    }


def complete_semantic_bundle():
    bundle = valid_bundle()
    bundle["trace"]["events"][2:2] = [
        {"stage": "coach.goalResolved"},
        {"stage": "coach.memoryLoaded"},
        {"stage": "coach.evidenceLoaded"},
        {"stage": "coach.rubricSelected"},
        {"stage": "coach.promptAssembled"},
    ]
    return bundle


class TraceReplayTests(unittest.TestCase):
    def test_valid_bundle_replays_terminal_path(self):
        # Legacy v1 bundles did not carry an explicit memory stage.
        result = trace_replay.validate_and_replay(valid_bundle())
        self.assertTrue(result["valid"])
        self.assertEqual(result["terminalState"], "retryableError")
        self.assertEqual(result["providerStageCount"], 2)
        self.assertTrue(result["semanticFixtureRequired"])

    def test_complete_semantic_path_replays_in_contract_order(self):
        result = trace_replay.validate_and_replay(complete_semantic_bundle())
        self.assertEqual(
            result["stagePath"][1:7],
            [
                "coach.classified",
                "coach.goalResolved",
                "coach.memoryLoaded",
                "coach.evidenceLoaded",
                "coach.rubricSelected",
                "coach.promptAssembled",
            ],
        )

    def test_complete_semantic_path_fails_when_goal_precedes_classification(self):
        bundle = complete_semantic_bundle()
        events = bundle["trace"]["events"]
        classified = next(
            i for i, event in enumerate(events)
            if event["stage"] == "coach.classified"
        )
        goal = next(
            i for i, event in enumerate(events)
            if event["stage"] == "coach.goalResolved"
        )
        events[classified], events[goal] = events[goal], events[classified]
        with self.assertRaisesRegex(trace_replay.TraceReplayError, "semantic stages"):
            trace_replay.validate_and_replay(bundle)

    def test_ordered_semantic_prefix_can_terminate_before_evidence(self):
        bundle = valid_bundle()
        bundle["trace"]["events"][2:2] = [
            {"stage": "coach.goalResolved"},
            {"stage": "coach.memoryLoaded"},
        ]
        result = trace_replay.validate_and_replay(bundle)
        self.assertEqual(
            result["stagePath"][1:4],
            [
                "coach.classified",
                "coach.goalResolved",
                "coach.memoryLoaded",
            ],
        )

    def test_memory_stage_without_goal_fails_closed(self):
        bundle = valid_bundle()
        bundle["trace"]["events"].insert(2, {"stage": "coach.memoryLoaded"})
        with self.assertRaisesRegex(
            trace_replay.TraceReplayError,
            "requires classified and goalResolved",
        ):
            trace_replay.validate_and_replay(bundle)

    def test_duplicate_terminal_fails_closed(self):
        bundle = valid_bundle()
        bundle["trace"]["events"].append({"stage": "coach.terminal"})
        bundle["trace"]["terminalEventCount"] = 2
        with self.assertRaisesRegex(trace_replay.TraceReplayError, "exactly one"):
            trace_replay.validate_and_replay(bundle)

    def test_unsafe_privacy_flag_fails_closed(self):
        bundle = valid_bundle()
        bundle["privacy"]["includesPrompt"] = True
        with self.assertRaisesRegex(trace_replay.TraceReplayError, "privacy contract"):
            trace_replay.validate_and_replay(bundle)

    def test_unknown_stage_fails_closed(self):
        bundle = valid_bundle()
        bundle["trace"]["events"].insert(1, {"stage": "chat.rawPrompt"})
        with self.assertRaisesRegex(trace_replay.TraceReplayError, "unknown or unsafe"):
            trace_replay.validate_and_replay(bundle)

    def test_missing_semantic_limitation_fails_closed(self):
        bundle = copy.deepcopy(valid_bundle())
        bundle["reproduction"]["semanticFixtureRequired"] = False
        with self.assertRaisesRegex(trace_replay.TraceReplayError, "limitation"):
            trace_replay.validate_and_replay(bundle)


if __name__ == "__main__":
    unittest.main()
