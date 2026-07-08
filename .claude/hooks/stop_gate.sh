#!/usr/bin/env bash
set -euo pipefail

# Noum Coach-Arena Stop gate.
#
# Opt-in and commit-aware. By default this does NOTHING so quick, non-coding
# Claude sessions can stop normally. Strict blocking only engages for
# autonomous Noum-improvement (RALPH) sessions, gated behind an explicit flag.
#
# Strict mode is ON when either:
#   - env NOUM_STRICT_STOP_GATE=1, or
#   - the marker file .claude/stop_gate_enabled exists
#
# In strict mode, refuse to stop unless ALL hold:
#   1. latest.md and failures.md reports exist
#   2. there is real work: dirty unstaged diff, staged diff, OR new commits
#      since the baseline recorded when strict mode started
#   3. the headline threshold rows in latest.md are passing (✅)

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

STRICT_MARKER=".claude/stop_gate_enabled"
BASE_FILE=".claude/stop_gate_base"
REPORT="tools/coach-arena/reports/latest.md"
FAILURES="tools/coach-arena/reports/failures.md"

# ---- 1. Opt-in check: default is non-blocking -------------------------------
if [[ "${NOUM_STRICT_STOP_GATE:-0}" != "1" && ! -f "$STRICT_MARKER" ]]; then
  exit 0
fi

block() {
  echo "Do not stop. $1" >&2
  exit 2
}

# ---- 2. Baseline: record HEAD once, when strict mode first runs --------------
if [[ ! -f "$BASE_FILE" ]]; then
  if head_sha=$(git rev-parse HEAD 2>/dev/null); then
    printf '%s\n' "$head_sha" > "$BASE_FILE"
  else
    printf '\n' > "$BASE_FILE"  # no commits yet; treat any diff as work
  fi
fi

# ---- 3. Reports must exist --------------------------------------------------
[[ -f "$REPORT" ]]   || block "Coach Arena latest.md is missing. Run ./tools/coach-arena/run.sh run."
[[ -f "$FAILURES" ]] || block "Coach Arena failures.md is missing. Generate the failure report."

# ---- 4. Commit-aware change detection ---------------------------------------
# Real work exists if ANY of: unstaged diff, staged diff, new commits since base.
has_changes=0
git diff --quiet          || has_changes=1  # unstaged
git diff --cached --quiet || has_changes=1  # staged

base="$(head -n1 "$BASE_FILE" 2>/dev/null || true)"
if [[ -n "$base" ]] && git cat-file -e "${base}^{commit}" 2>/dev/null; then
  new_commits="$(git rev-list --count "${base}..HEAD" 2>/dev/null || echo 0)"
  [[ "${new_commits:-0}" -gt 0 ]] && has_changes=1
fi

[[ "$has_changes" -eq 1 ]] || \
  block "No code changes since the strict-session baseline (no unstaged, staged, or committed work)."

# ---- 5. Threshold rows from latest.md (NOT keyword-grep of failures.md) ------
# Block only when a named headline row is explicitly failing (❌) or absent.
# failures.md may hold historical failure examples; never gate on it by keyword.
row_status() {
  # echo: PASS | FAIL | MISSING  for the headline row whose label is $1
  local label="$1" line
  line="$(grep -E "^\|[[:space:]]*${label}[[:space:]]*\|" "$REPORT" | head -n1 || true)"
  if [[ -z "$line" ]]; then echo MISSING; return; fi
  if printf '%s' "$line" | grep -q "❌"; then echo FAIL; return; fi
  if printf '%s' "$line" | grep -q "✅"; then echo PASS; return; fi
  echo MISSING
}

check_row() {
  # $1 = table label, $2 = human name for the message
  case "$(row_status "$1")" in
    FAIL)    block "$2 row is failing in latest.md. Improve it before stopping." ;;
    MISSING) block "$2 row is missing from latest.md — report is incomplete. Re-run Coach Arena." ;;
  esac
}

check_row "Gold-suite mean"      "Gold-suite mean"
check_row "Deep-assessment mean" "Deep-assessment"
check_row "Trust-repair mean"    "Trust-repair"
check_row "Placeholder leaks"    "Placeholder leaks"

exit 0
