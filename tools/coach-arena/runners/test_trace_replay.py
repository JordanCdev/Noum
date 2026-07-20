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


class TraceReplayTests(unittest.TestCase):
    def test_valid_bundle_replays_terminal_path(self):
        result = trace_replay.validate_and_replay(valid_bundle())
        self.assertTrue(result["valid"])
        self.assertEqual(result["terminalState"], "retryableError")
        self.assertEqual(result["providerStageCount"], 2)
        self.assertTrue(result["semanticFixtureRequired"])

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
