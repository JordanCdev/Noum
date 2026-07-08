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
#   ./run.sh app-path [report.json]
#                         score a real Swift app-path dump into reports/app-path
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
    python3 -m unittest discover -s runners -p 'test_*.py' ;;
  app-path)
    report_path="${1:-${NOUM_COACH_EVAL_DUMP_DIR:-/private/tmp/noum-coach-eval}/coach-chat-conversation-app-path-eval-v1.json}"
    if [[ ! -f "$report_path" ]]; then
      echo "No real Swift app-path dump found at: $report_path" >&2
      echo "Generate it with the CoachChatConversationArtifactDumpXCTest bridge, or pass the report path explicitly." >&2
      exit 1
    fi
    shift || true
    python3 runners/coach_arena.py \
      --app-path-report "$report_path" \
      --reports-dir reports/app-path \
      --synthetic-dir synthetic/app-path \
      "$@" ;;
  python)   python3 runners/coach_arena.py "$@" ;;
  *)        echo "usage: ./run.sh {run|plan|prepare|report|validate|synth|extract|test|app-path|python}" >&2; exit 1 ;;
esac
