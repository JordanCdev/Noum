#!/usr/bin/env python3
"""Validate and replay a content-free Ask Noum terminal path.

This intentionally does not regenerate the user's request or the coach reply.
Those are absent from the privacy-safe support bundle. It reconstructs the
recorded classification/provider/gate/persistence/UI path and fails closed when
the packet or terminal contract is malformed. Semantic reproduction must use a
separately authored synthetic Coach Arena fixture.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any
from uuid import UUID


SCHEMA_VERSION = "noum-coach-trace-support-v1"
TERMINAL_STATES = {
    "accepted",
    "repaired",
    "safeFallback",
    "retryableError",
    "cancelled",
}
KNOWN_STAGES = {
    "coach.accepted",
    "coach.classified",
    "coach.goalResolved",
    "coach.memoryLoaded",
    "coach.evidenceLoaded",
    "coach.rubricSelected",
    "coach.promptAssembled",
    "coach.providerDeadlineArmed",
    "coach.providerStarted",
    "coach.providerRetried",
    "coach.providerRefused",
    "coach.providerFinished",
    "coach.streamFirstBuffered",
    "coach.streamFirstVisible",
    "coach.gatePassed",
    "coach.gateRepaired",
    "coach.gateFallback",
    "coach.gateRejected",
    "coach.finalSanitized",
    "coach.persisted",
    "coach.uiCommitted",
    "coach.terminal",
}

SEMANTIC_STAGE_PATH = (
    "coach.classified",
    "coach.goalResolved",
    "coach.memoryLoaded",
    "coach.evidenceLoaded",
    "coach.rubricSelected",
    "coach.promptAssembled",
)


class TraceReplayError(ValueError):
    """The bundle cannot safely or faithfully replay its terminal path."""


def _mapping(value: Any, field: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise TraceReplayError(f"{field} must be an object")
    return value


def _list(value: Any, field: str) -> list[Any]:
    if not isinstance(value, list):
        raise TraceReplayError(f"{field} must be an array")
    return value


def validate_and_replay(bundle: dict[str, Any]) -> dict[str, Any]:
    if bundle.get("schemaVersion") != SCHEMA_VERSION:
        raise TraceReplayError("unsupported or missing schemaVersion")

    privacy = _mapping(bundle.get("privacy"), "privacy")
    if privacy.get("contentFree") is not True:
        raise TraceReplayError("bundle is not declared content-free")
    prohibited_flags = (
        "includesUserText",
        "includesTranscript",
        "includesPrompt",
        "includesResponse",
        "includesAccountIdentifier",
        "includesCredentials",
    )
    unsafe = [key for key in prohibited_flags if privacy.get(key) is not False]
    if unsafe:
        raise TraceReplayError(
            "privacy contract missing or unsafe: " + ", ".join(sorted(unsafe))
        )

    trace = _mapping(bundle.get("trace"), "trace")
    trace_id = trace.get("traceID")
    try:
        UUID(str(trace_id))
    except (TypeError, ValueError) as error:
        raise TraceReplayError("trace.traceID must be a UUID") from error

    events = _list(trace.get("events"), "trace.events")
    if not events:
        raise TraceReplayError("trace.events must not be empty")
    stages: list[str] = []
    for index, raw_event in enumerate(events):
        event = _mapping(raw_event, f"trace.events[{index}]")
        stage = event.get("stage")
        if stage not in KNOWN_STAGES:
            raise TraceReplayError(f"unknown or unsafe stage at index {index}: {stage!r}")
        stages.append(stage)

    terminal_indexes = [
        index for index, stage in enumerate(stages) if stage == "coach.terminal"
    ]
    if len(terminal_indexes) != 1:
        raise TraceReplayError(
            f"terminal contract requires exactly one terminal event; found {len(terminal_indexes)}"
        )
    if terminal_indexes[0] != len(stages) - 1:
        raise TraceReplayError("coach.terminal must be the final recorded stage")
    if stages[0] != "coach.accepted":
        raise TraceReplayError("coach.accepted must open the replayable path")

    # v1 support bundles created before memory had its own trace stage remain
    # replayable. Once a producer emits the additive memory stage, however, it
    # is declaring the ordered semantic contract. Early terminal paths may
    # contain only a prefix, so validate the stages present rather than
    # requiring work that truthfully never ran.
    if "coach.memoryLoaded" in stages:
        required_prefix = (
            "coach.classified",
            "coach.goalResolved",
            "coach.memoryLoaded",
        )
        missing_prefix = [stage for stage in required_prefix if stage not in stages]
        if missing_prefix:
            raise TraceReplayError(
                "memory stage requires classified and goalResolved first: "
                + ", ".join(missing_prefix)
            )
        present_semantic = [
            stage for stage in SEMANTIC_STAGE_PATH if stage in stages
        ]
        duplicates = [stage for stage in present_semantic if stages.count(stage) != 1]
        if duplicates:
            raise TraceReplayError(
                "semantic path must contain each recorded stage once: "
                + ", ".join(duplicates)
            )
        semantic_indexes = [stages.index(stage) for stage in present_semantic]
        if semantic_indexes != sorted(semantic_indexes):
            raise TraceReplayError(
                "semantic stages must follow classified, goal, memory, evidence, rubric, prompt order"
            )

    for required in ("coach.persisted", "coach.uiCommitted"):
        if required not in stages:
            raise TraceReplayError(f"terminal path is missing {required}")
        if stages.index(required) > terminal_indexes[0]:
            raise TraceReplayError(f"{required} must occur before coach.terminal")
    if stages.index("coach.persisted") > stages.index("coach.uiCommitted"):
        raise TraceReplayError("coach.persisted must precede coach.uiCommitted")

    terminal_state = trace.get("terminalState")
    if terminal_state not in TERMINAL_STATES:
        raise TraceReplayError("terminalState is missing or unknown")
    if trace.get("terminalEventCount") != 1:
        raise TraceReplayError("terminalEventCount does not match the replayed path")
    if trace.get("terminalContractViolation") is not False:
        raise TraceReplayError("bundle declares a terminal contract violation")
    if trace.get("terminalStatus") != terminal_state:
        raise TraceReplayError("terminalStatus does not match terminalState")

    reproduction = _mapping(bundle.get("reproduction"), "reproduction")
    if reproduction.get("mode") != "content-free-terminal-path-replay":
        raise TraceReplayError("reproduction mode is not content-free terminal replay")
    if reproduction.get("semanticFixtureRequired") is not True:
        raise TraceReplayError("semantic-fixture limitation must remain explicit")

    provider_stages = {
        "coach.providerStarted",
        "coach.providerRetried",
        "coach.providerRefused",
        "coach.providerFinished",
    }
    gate_stages = {
        "coach.gatePassed",
        "coach.gateRepaired",
        "coach.gateFallback",
        "coach.gateRejected",
    }
    return {
        "valid": True,
        "schemaVersion": SCHEMA_VERSION,
        "traceID": trace_id,
        "terminalState": terminal_state,
        "stagePath": stages,
        "providerStageCount": sum(stage in provider_stages for stage in stages),
        "gateDecisionCount": sum(stage in gate_stages for stage in stages),
        "semanticFixtureRequired": True,
        "note": (
            "Terminal path reproduced from content-free metadata. "
            "Create a synthetic fixture with the same classified intent/depth "
            "to reproduce semantic behavior; raw user and coach text are unavailable."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Replay a privacy-safe Ask Noum support-bundle terminal path."
    )
    parser.add_argument("bundle", type=Path)
    args = parser.parse_args()
    try:
        raw = json.loads(args.bundle.read_text(encoding="utf-8"))
        result = validate_and_replay(_mapping(raw, "root"))
    except (OSError, json.JSONDecodeError, TraceReplayError) as error:
        print(json.dumps({"valid": False, "error": str(error)}, indent=2))
        return 2
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
