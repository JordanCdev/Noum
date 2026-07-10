# Coach Arena

A harsh, honest measurement harness for **Chat with Noum** — the Noum
communications coach. It exists because the old "score = 10" evals were
unreliable: a 10 could still be generic, low-EQ, placeholder, or broken. Arena
replaces a single soft number with a **/100 rubric behind hard reliability
caps**, graded against what an excellent human coach would do on the exact turn.

Source of product truth: [`docs/VISION.md`](../../docs/VISION.md). A reply is
not rewarded for being grounded or polite — it is rewarded for doing what the
fixture's `excellentAnswerExample` does.

## Two engines, one tree

Coach Arena has two complementary lenses (see *Provenance* at the bottom):

| Engine | Entry | Grades | Judge | Strength |
|---|---|---|---|---|
| **Prompt-faithful** (Node, canonical) | `./run.sh` | the **real extracted Swift system prompt** run on 60 gold+synthetic fixtures | LLM judge vs bad/excellent + deterministic checks | tests the shipping instructions directly; production-parity provider |
| **App-path** (Python, legacy) | `./run.sh app-path [report.json]` | **real app-generated candidates** + trace/real-pipeline evidence audits | heuristic `local_judge` + optional LLM hook | can score actual pipeline output when a dump exists, and refuses to run without one |

Both share the same rubric, caps, and thresholds. The Node engine is the default
because it needs no app dump to run and it tests the instruction layer that most
drives coach quality; the Python engine remains for scoring real app output.

## Rubric (/100)

| Dimension | Max | Rewards |
|---|---|---|
| Diagnostic IQ | 25 | the RIGHT problem for THIS user, sharp and specific, mechanics separated from goal |
| EQ / attunement | 25 | reading the human signal and opening in the right register before advice |
| Personal memory | 20 | durable context used to make the answer un-swappable to another user |
| Coaching interventions | 15 | one concrete testable move, in-voice, framed as a test, not repeated |
| Real-time dialogue feel | 15 | sounds like a person talking, compact, scannable |

### Reliability caps (clamp the total)

| Cap | Max | Trigger |
|---|---|---|
| Placeholder / fake score / broken | 30 | placeholder, canned fallback, metadata leak, fabricated top score, "you're ready now" from thin evidence |
| Ignores intent | 50 | doesn't engage what the user asked (menu instead of a decision, bare clarification of a readable turn) |
| Fabricates evidence | 40 | quotes the user never said, cites metrics not in context |
| Unsafe | 0 (fail) | harmful/shaming guidance, punish-shame, fixed psychological verdict on the person |

Deterministic caps and judge caps are **unioned** — either can clamp. Quality
flags (robotic phrase, scaffold label, exclamation, over-length, …) are capped
point deductions. See [`rubric.json`](rubric.json).

### Thresholds

- gold-suite mean ≥ **70**
- `deepAssessment` mean ≥ **70**
- `trustRepair` mean ≥ **65**
- placeholder leaks: **0**

## Run

```bash
# Live, production parity (matches the app: claude-sonnet-4-6 via api.anthropic.com)
ANTHROPIC_API_KEY=sk-ant-... ./tools/coach-arena/run.sh run

# Offline replay over captured replies/verdicts (no key, reproducible)
ARENA_PROVIDER=replay ./tools/coach-arena/run.sh run

# Include the 10 synthetic multi-turn conversations
ARENA_INCLUDE_SYNTHETIC=1 ./tools/coach-arena/run.sh run

# Real Swift app-path evidence from the XCTest artifact dump
./tools/coach-arena/run.sh app-path-source
./tools/coach-arena/run.sh app-path-preflight --no-fail
./tools/coach-arena/run.sh app-path
# Diagnostic scoring of a known-stale dump; writes to reports/app-path-diagnostic
./tools/coach-arena/run.sh app-path --allow-stale-source --no-fail

# Launch-readiness gate from the latest app-path report
./tools/coach-arena/run.sh readiness
./tools/coach-arena/run.sh readiness --dump-dir /private/tmp/noum-coach-eval --no-fail
./tools/coach-arena/run.sh readiness --repo-root /path/to/Noum --no-fail
./tools/coach-arena/run.sh readiness --probe-live --no-fail
```

`app-path` reads
`$NOUM_COACH_EVAL_DUMP_DIR/coach-chat-conversation-app-path-eval-v1.json`, defaulting
to `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`,
and writes the scored report to `reports/app-path/`. Pass an explicit report path
as the first argument when scoring another dump. Before trusting or rescoring a
dump, run `app-path-preflight` for the same dump directory. It fails closed when
the dump, source sidecars, trace commit/fingerprint, or app-path floor are stale
or missing, and prints the refresh sequence needed to make the evidence current.
For the canonical XCTest dump, `app-path` runs the same preflight before writing
`reports/app-path/latest.*`; use `--allow-stale-source` only when intentionally
scoring an old dump for diagnostics, not for readiness claims. That diagnostic
mode writes to `reports/app-path-diagnostic/` and
`synthetic/app-path-diagnostic/` by default so it cannot refresh the canonical
readiness input by accident. Pass explicit `--reports-dir` / `--synthetic-dir`
only when you deliberately want another output location.
Before refreshing the dump, run `app-path-source` for the same dump directory. It writes
`source-git-commit.txt` and `source-coach-fingerprint.txt`, letting the XCTest
bridge stamp every trace with the exact source commit and coach-source byte
fingerprint used for that run. Then use the XCTest bridge
`NoumTests/CoachChatConversationArtifactDumpXCTest` to refresh the app-path JSON.
The coach-source fingerprint covers the reply pipeline, provider wrapper,
typed assessment/reasoning layer, prompt bundles, reliability gate, rubrics,
trajectory cache/snapshot, retrieval knowledge, and their coach-eval tests.
The readiness gate compares the canonical app-path report and dump sidecars
against the current checkout's coach-source fingerprint and git commit when
available, so a stale but internally consistent report remains blocked until
the Swift dump and app-path report are regenerated from the current source.
The same source sidecars now gate `coach-live-eval-v1.json`: a live-provider
sweep only clears `.noLiveProviderTranscriptSweep` when its `sourceGitCommit`
and `sourceCoachFingerprint` match the sidecars in the dump directory, and the
staged artifact carries the required latest-fixture coverage, long-form
conversation coverage, provider evidence, immediate-read telemetry, confidence
variety, proof-test variety, trajectory-cache coverage, and clean
production-floor rows. A placeholder or stale JSON file stays blocked even if
the filename is present.
The app-path trace-quality gate also treats missing or all-cold
`trajectoryCacheHit` telemetry and exact repeated `finalReply` hashes as
production evidence failures: the launch report has to prove differentiated,
trajectory-aware coach reads, not merely high fixture averages.
The XCTest app-path report now exports `trajectoryCacheHitCount`,
`trajectoryCacheMissingTelemetryCount`, and `minimumTrajectoryCacheHitCount`
too, so weak trajectory-cache coverage is visible before the Python scorer
turns it into a launch-blocking trace-quality failure.
The calibration result sidecar is similarly staged against the exported
`coach-chat-conversation-expert-calibration-v2.json` packet: Python checks the
packet fingerprint, the 39-conversation / 78-review floor, two independent
professional reviewers per conversation, passing usefulness ratings, no
unsafe/unready rows, and no unresolved revision notes before the sidecar can
pass staging.

Other commands: `plan` (compose real prompts/context to `runs/<id>/requests.json`),
`prepare [n]` (per-voice prompts + per-fixture reqs + n agent batches),
`report` (re-render), `validate` (fixture integrity), `synth` (rebuild
conversations), `extract <voice|--json>` (print the extracted system prompt),
`test`, `app-path-source` (stamp real app-path source sidecars),
`app-path-preflight` (verify the app-path dump is fresh enough to trust), `readiness`
(fail the launch gate until local app-path gates, Swift `localTargetShapeScore`
>= 85, and external evidence artifacts are present; also audits required
sidecar presence in `NOUM_COACH_EVAL_DUMP_DIR` or `--dump-dir`, plus static
Firebase/privacy/TestFlight-QA repo wiring via `--repo-root`; pass
`--probe-live` to hard-block on public privacy URL reachability/content), and
`python` (direct access to the legacy engine; do not use it for app-path
readiness unless you pass `--app-path-report`, otherwise it grades reference
examples).

### Providers

- `anthropic` — `POST api.anthropic.com/v1/messages`, `x-api-key`,
  `anthropic-version: 2023-06-01`, model `claude-sonnet-4-6` — **exactly the
  app's request shape**. Needs `ANTHROPIC_API_KEY`. Set `ARENA_MODEL` /
  `ARENA_JUDGE_MODEL` to override.
- `cli` — shells out to `claude -p` (works in a normally-authenticated terminal).
- `replay` — reads `runners/captures/<id>.reply.txt` + `<id>.judge.json`.
  Offline; used for CI, deterministic-check runs, and reproducing a report
  without spending tokens. Default when no key is present.

## Pipeline

```
fixtures/gold/*.json  ─┐
synthetic/…           ─┤
                       ▼
lib/extractPrompt.mjs  →  REAL Swift system prompt   (Noum/CoachContextBuilder.swift,
                                                       Noum/AICoachChatService.swift)
lib/context.mjs        →  CONTEXT block (mirrors CoachContextBuilder sections)
                       ▼
provider.generate  →  coach reply
                       ▼
lib/checks.mjs     →  deterministic reliability findings (mirror the app's own
                       replyQualityIssue family + leak/score-as-readiness checks)
lib/judge.mjs      →  JSON LLM judge (5 dims, caps, closerTo bad/excellent, fix)
lib/score.mjs      →  combine (judge − flags, clamped by unioned caps)
lib/report.mjs     →  reports/latest.json · latest.md · failures.md (+ history, deltas)
```

Every scored record carries a **trace**: provider, model, latency, token usage,
system/context sizes, prompt provenance (source-file sha256s), and git commit —
so a report ties to an exact state of the coach.

## Fixtures

50 gold fixtures in [`fixtures/gold/`](fixtures/gold) + 10 multi-turn
conversations expanded from [`synthetic/conversations.data.mjs`](synthetic/conversations.data.mjs).
Each carries `userTurn`, `priorChatTurns`, `goal`, `evidence`, `memoryState`,
`emotionalSignal`, `expectedCoachMove`, `badAnswerExample`,
`excellentAnswerExample`, and `disqualifiers`
(schema: [`fixtures/schema.json`](fixtures/schema.json)).

They are drawn from VISION, real Ask-Noum failure modes, and named hard turns —
including *"How far off am I from sounding authoritative?"*, *"That's not
informative"*, *"Okay that's cool, however…"*, *"It's not easy"*, *"You're
repeating yourself"*, interview prep, filler-under-pressure, the leadership
update, the confidence ending, and reliability traps (fabrication bait, "am I
ready?" readiness bait, "what does your system know about me?" metadata bait).

`validate` enforces that every `excellentAnswerExample` **passes** the
deterministic checks and every `badAnswerExample` is **caught** — so a fixture
genuinely discriminates rather than leaning entirely on the judge.

## What Arena does NOT claim — read this before trusting a number

Arena grades the coach's *language and reasoning quality*. A passing score is
weak-to-moderate local evidence, **not** proof of anything shippable. Specifically:

- **Self-graded, single model family.** In the runs committed here, Claude
  (`claude-sonnet-4-6`) generated the coach replies **and** judged them, against
  `excellentAnswerExample`/`badAnswerExample`/`disqualifiers` **also authored by
  Claude**. A high score is largely a same-model self-assessment.
- **Replay mode does not execute the prompt.** With the default `replay`
  provider, replies are pre-captured files — editing the Swift prompt does **not**
  change a replay reply. Attribute prompt-change deltas only to a `--live`
  (`anthropic`/`cli`) run that actually generates from the prompt.
- **Prompt-faithful runs are not the production model or pipeline.** Production's
  default coach model is `gemini-3.5-flash` (Sonnet is a fallback), and the
  prompt-faithful Node engine never exercises the live Swift pipeline —
  retrieval, memory assembly, the quality gate, provider fallback, caching.
  Use `./run.sh app-path` for the real Swift trace lens.
- **App-path green is still not VISION production readiness.** The app-path report
  proves local real-pipeline evidence and trace quality. It does not remove the
  VISION blockers for live-provider transcript sweeps, professional-coach
  calibration, real-user longitudinal transfer outcomes, real-device TestFlight
  verification, or launch operations. The app-path markdown prints that boundary
  from the Swift readiness audit when present.
- **Within-noise deltas.** The same prompt at the same commit has produced 75.7
  and 76.5; per-fixture judge scores swing ±9. Treat small movements as noise.
- The judge runs lenient (most replies land "excellent"); `closerTo` is advisory.

**Not** proof the near-real-time architecture is sound and **not** proof of
human-coach parity (VISION reserves that for real users, longitudinal outcomes,
and blinded professional-coach calibration). Do not call Chat with Noum
production-ready from an Arena score. The real coach-quality failures live in the
live pipeline — use the app-path engine (`./run.sh python`) or the on-device
Flow log for those.

## Provenance

Two agents built a coach-arena at this path in parallel. The **Python engine**
(`runners/coach_arena.py`, `fixtures/gold.json`, `judges/llm_judge*`,
`synthetic/ten_conversations.md`) came first and is preserved as the app-path
lens (`./run.sh python …`). The **Node engine** (this README, `lib/`,
`runners/replay.mjs` + `prepare.mjs`, `fixtures/gold/*.json`, `rubric.json`,
`judges/rubric-judge.md`) is the canonical default because it tests the real
shipping prompt end-to-end without needing an app dump.
