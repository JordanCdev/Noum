#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
report_only=0
if [[ "${1:-}" == "--report-only" ]]; then
  report_only=1
  shift
fi
if [[ $# -ne 0 ]]; then
  echo "Usage: $0 [--report-only]" >&2
  exit 2
fi

output="$(mktemp "${TMPDIR:-/tmp}/noum-static-readiness.XXXXXX")"
trap 'rm -f "$output"' EXIT INT TERM

python3 "$repo_root/scripts/release-generate-processor-disclosures.py" --check
"$repo_root/scripts/test-release-cloud-operations-probe.sh"

"$repo_root/tools/coach-arena/run.sh" readiness \
  --repo-root "$repo_root" \
  --json \
  --no-fail > "$output"

python3 - "$output" "$report_only" <<'PY'
import json
import sys
from pathlib import Path

status = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
report_only = sys.argv[2] == "1"
preflight = status.get("operationalStaticPreflight") or {}
checks = preflight.get("checks") or []
failures = [check for check in checks if not check.get("passed")]

print(
    "Operational static readiness: "
    f"{len(checks) - len(failures)}/{len(checks)} checks passed."
)
for check in failures:
    print(f"- FAIL {check.get('label', check.get('key', 'unknown'))}")
    next_step = check.get("nextStep")
    if next_step:
        print(f"  {next_step}")

if failures and not report_only:
    raise SystemExit(1)
PY
