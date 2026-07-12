#!/usr/bin/env bash
# Coach Arena — one entrypoint. Two engines share this tree (see README):
#   • Node "prompt-faithful" engine (default, canonical): grades the REAL
#     extracted Swift coach prompt on 60 gold+synthetic fixtures via an LLM judge.
#   • Python "app-path" engine (legacy): grades REAL app-generated candidates and
#     runs real-pipeline evidence/trace audits. Reach it with `./run.sh app-path`.
#
#   ./run.sh              full Node run (auto provider) + reports
#   ./run.sh run          same
#   ./run.sh plan         compose real prompts/context for every fixture
#   ./run.sh prepare [n]  write per-voice prompts + per-fixture reqs + n batches (for agent generation)
#   ./run.sh report       re-render reports from reports/latest.json
#   ./run.sh validate     validate all gold fixtures
#   ./run.sh synth        (re)generate the 10 synthetic conversations
#   ./run.sh extract [voice|--json]   print the extracted real system prompt
#   ./run.sh test         run unit tests
#   ./run.sh app-path [report.json] [--allow-stale-source]
#                         score a real Swift app-path dump into reports/app-path;
#                         refuses stale canonical dumps before publishing latest
#   ./run.sh app-path-source [dump-dir]
#                         stamp source commit/fingerprint sidecars before XCTest
#   ./run.sh app-path-preflight [dump-dir]
#                         check whether the app-path dump is fresh enough to score
#   ./run.sh evidence-refresh [readiness options]
#                         refresh source sidecars, app-path dumps, expert packet,
#                         readiness manifest, scoring, and final artifact audit
#   ./run.sh readiness [report.json] [--dump-dir dir] [--repo-root dir] [--probe-live] [--no-fail]
#                         evaluate the VISION production-readiness gate from
#                         an app-path report; exits nonzero until launch evidence exists
#   ./run.sh python ...   run the legacy Python engine directly (unsafe default:
#                         without --app-path-report it grades gold examples)
#
# Provider (env ARENA_PROVIDER, else auto): anthropic (needs ANTHROPIC_API_KEY,
# model claude-sonnet-4-6, production parity) | cli (`claude -p`) | replay
# (offline, reads runners/captures/). Env: ARENA_MODEL, ARENA_JUDGE_MODEL,
# ARENA_CAPTURES, ARENA_INCLUDE_SYNTHETIC=1.

set -euo pipefail
cd "$(dirname "$0")"

cmd="${1:-run}"; shift || true

case "$cmd" in
  run)
    if [[ -z "${ARENA_PROVIDER:-}" && -z "${ANTHROPIC_API_KEY:-}" ]]; then
      echo "No ANTHROPIC_API_KEY / ARENA_PROVIDER -> replay mode (offline; uses runners/captures/)." >&2
      echo "Live production-parity run: ANTHROPIC_API_KEY=sk-... ./run.sh run" >&2
    fi
    node runners/replay.mjs run "$@" ;;
  plan)     node runners/replay.mjs plan "$@" ;;
  prepare)  node runners/prepare.mjs "$@" ;;
  report)   node runners/replay.mjs report "$@" ;;
  validate) node lib/validateFixtures.mjs "$@" ;;
  synth)    node synthetic/generate.mjs "$@" ;;
  extract)  node lib/extractPrompt.mjs "$@" ;;
  test)
    node --test "$@"
    PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s runners -p 'test_*.py' ;;
  app-path)
    allow_stale="${NOUM_COACH_ALLOW_STALE_APP_PATH:-0}"
    report_path=""
    reports_dir="reports/app-path"
    synthetic_dir="synthetic/app-path"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --allow-stale-source)
          allow_stale=1
          shift
          ;;
        --)
          shift
          break
          ;;
        -*)
          break
          ;;
        *)
          if [[ -z "$report_path" ]]; then
            report_path="$1"
            shift
          else
            break
          fi
          ;;
      esac
    done
    report_path="${report_path:-${NOUM_COACH_EVAL_DUMP_DIR:-/private/tmp/noum-coach-eval}/coach-chat-conversation-app-path-eval-v1.json}"
    if [[ ! -f "$report_path" ]]; then
      echo "No real Swift app-path dump found at: $report_path" >&2
      echo "Generate it with the CoachChatConversationArtifactDumpXCTest bridge, or pass the report path explicitly." >&2
      exit 1
    fi
    report_file="${report_path##*/}"
    dump_dir="${report_path%/*}"
    if [[ "$dump_dir" == "$report_path" ]]; then
      dump_dir="."
    fi
    if [[ "$report_file" == "coach-chat-conversation-app-path-eval-v1.json" && "$allow_stale" != "1" ]]; then
      python3 runners/coach_arena.py --app-path-preflight "$dump_dir"
    elif [[ "$allow_stale" == "1" ]]; then
      reports_dir="reports/app-path-diagnostic"
      synthetic_dir="synthetic/app-path-diagnostic"
      echo "Warning: scoring app-path dump with stale-source guard disabled; default diagnostic reports dir is ${reports_dir} unless --reports-dir overrides it." >&2
    fi
    python3 runners/coach_arena.py \
      --app-path-report "$report_path" \
      --reports-dir "$reports_dir" \
      --synthetic-dir "$synthetic_dir" \
      "$@" ;;
  app-path-source)
    dump_dir="${1:-${NOUM_COACH_EVAL_DUMP_DIR:-/private/tmp/noum-coach-eval}}"
    python3 runners/coach_arena.py --write-app-path-source-sidecars "$dump_dir" ;;
  app-path-preflight)
    dump_dir="${NOUM_COACH_EVAL_DUMP_DIR:-/private/tmp/noum-coach-eval}"
    if [[ $# -gt 0 && "${1:0:1}" != "-" ]]; then
      dump_dir="$1"
      shift
    fi
    python3 runners/coach_arena.py --app-path-preflight "$dump_dir" "$@" ;;
  evidence-refresh)
    exec ./refresh-evidence.sh "$@" ;;
  readiness)
    report_path="${NOUM_COACH_READINESS_REPORT:-reports/app-path/latest.json}"
    if [[ $# -gt 0 && "${1:0:1}" != "-" ]]; then
      report_path="$1"
      shift
    fi
    python3 runners/readiness_gate.py --report "$report_path" "$@" ;;
  python)   python3 runners/coach_arena.py "$@" ;;
  *)        echo "usage: ./run.sh {run|plan|prepare|report|validate|synth|extract|test|app-path|app-path-source|app-path-preflight|evidence-refresh|readiness|python}" >&2; exit 1 ;;
esac
