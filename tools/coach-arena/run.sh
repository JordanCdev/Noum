#!/usr/bin/env bash
# Coach Arena — one entrypoint. Two engines share this tree (see README):
#   • Node "prompt-faithful" engine (default, canonical): grades the REAL
#     extracted Swift coach prompt on 60 gold+synthetic fixtures via an LLM judge.
#   • Python "app-path" engine (legacy): grades REAL app-generated candidates and
#     runs production-evidence/trace audits. Reach it with `./run.sh python ...`.
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
#   ./run.sh python ...   run the legacy Python app-path engine (runners/coach_arena.py)
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
  test)     node --test "$@" ;;
  python)   python3 runners/coach_arena.py "$@" ;;
  *)        echo "usage: ./run.sh {run|plan|prepare|report|validate|synth|extract|test|python}" >&2; exit 1 ;;
esac
