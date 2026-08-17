#!/usr/bin/env python3
"""Fail closed when a release UI result bundle is incomplete or skipped."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


TEST_METHOD = re.compile(r"^\s*func\s+(test[A-Za-z0-9_]+)\s*\(", re.MULTILINE)
COUNT_KEYS = (
    "passedTests",
    "failedTests",
    "skippedTests",
    "expectedFailures",
    "totalTestCount",
)
DESTINATION_COUNT_KEYS = COUNT_KEYS[:-1]


def declared_test_count(tests_root: Path) -> int:
    return sum(
        len(TEST_METHOD.findall(path.read_text(encoding="utf-8")))
        for path in sorted(tests_root.rglob("*.swift"))
    )


def validate(summary: dict[str, Any], tests_root: Path) -> list[str]:
    errors: list[str] = []
    counts: dict[str, int] = {}
    for key in COUNT_KEYS:
        value = summary.get(key)
        if isinstance(value, bool) or not isinstance(value, int) or value < 0:
            errors.append(f"xcresult summary has no nonnegative integer {key}")
        else:
            counts[key] = value

    declared = declared_test_count(tests_root)
    if declared == 0:
        errors.append("no source-declared UI test methods were found")

    destinations = summary.get("devicesAndConfigurations")
    destination_counts: dict[str, int] = {}
    if not isinstance(destinations, list) or len(destinations) != 1:
        errors.append("xcresult summary must contain exactly one test destination")
    elif not isinstance(destinations[0], dict):
        errors.append("xcresult test destination must be an object")
    else:
        for key in DESTINATION_COUNT_KEYS:
            value = destinations[0].get(key)
            if isinstance(value, bool) or not isinstance(value, int) or value < 0:
                errors.append(
                    f"xcresult destination has no nonnegative integer {key}"
                )
            else:
                destination_counts[key] = value

    if counts.get("failedTests", 1) != 0:
        errors.append(f"failed UI tests: {counts.get('failedTests', 'unknown')}")
    if counts.get("skippedTests", 1) != 0:
        errors.append(f"skipped UI tests: {counts.get('skippedTests', 'unknown')}")
    if counts.get("expectedFailures", 1) != 0:
        errors.append(
            f"expected UI test failures: {counts.get('expectedFailures', 'unknown')}"
        )

    passed = counts.get("passedTests")
    total = counts.get("totalTestCount")
    if passed is not None and passed != declared:
        errors.append(f"{passed} UI tests passed; source declares exactly {declared}")
    if total is not None and total != declared:
        errors.append(
            f"xcresult contains {total} UI tests; source declares exactly {declared}"
        )
    if passed is not None and total is not None and passed != total:
        errors.append(f"passed/total UI test counts disagree: {passed}/{total}")
    if len(counts) == len(COUNT_KEYS):
        accounted = sum(counts[key] for key in DESTINATION_COUNT_KEYS)
        if total != accounted:
            errors.append(
                "xcresult total does not equal passed + failed + skipped + "
                f"expected failures: {total}/{accounted}"
            )
    if len(destination_counts) == len(DESTINATION_COUNT_KEYS):
        for key in DESTINATION_COUNT_KEYS:
            if destination_counts[key] != counts.get(key):
                errors.append(
                    f"xcresult destination {key} disagrees with summary: "
                    f"{destination_counts[key]}/{counts.get(key, 'unknown')}"
                )
    if summary.get("result") != "Passed":
        errors.append(f"xcresult status is not Passed: {summary.get('result')!r}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("tests_root", type=Path)
    parser.add_argument(
        "summary",
        nargs="?",
        type=Path,
        help="xcresult summary JSON; reads standard input when omitted",
    )
    args = parser.parse_args(argv)

    try:
        raw = (
            args.summary.read_text(encoding="utf-8")
            if args.summary
            else sys.stdin.read()
        )
        summary = json.loads(raw)
    except (OSError, json.JSONDecodeError) as error:
        print(f"Unable to read xcresult summary: {error}", file=sys.stderr)
        return 2
    if not isinstance(summary, dict):
        print("xcresult summary root must be an object", file=sys.stderr)
        return 2

    errors = validate(summary, args.tests_root)
    if errors:
        for error in errors:
            print(f"Full-UI release gate failed: {error}", file=sys.stderr)
        return 1

    print(
        "Full-UI release gate passed: "
        f"{summary['passedTests']} passed, 0 failed, 0 skipped, "
        "0 expected failures."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
