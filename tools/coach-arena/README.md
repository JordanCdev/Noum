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
| **App-path** (Python, legacy) | `./run.sh python` | **real app-generated candidates** + trace/production-evidence audits | heuristic `local_judge` + optional LLM hook | can score actual pipeline output when a dump exists |

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
```

Other commands: `plan` (compose real prompts/context to `runs/<id>/requests.json`),
`prepare [n]` (per-voice prompts + per-fixture reqs + n agent batches),
`report` (re-render), `validate` (fixture integrity), `synth` (rebuild
conversations), `extract <voice|--json>` (print the extracted system prompt),
`test`.

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

## What Arena does NOT claim

Arena grades the coach's *language and reasoning quality*. A passing score is
strong local evidence, **not** proof the near-real-time architecture is sound
and **not** proof of human-coach parity (VISION reserves that for real users,
longitudinal outcomes, and blinded professional-coach calibration). Do not call
Chat with Noum production-ready from an Arena score alone.

## Provenance

Two agents built a coach-arena at this path in parallel. The **Python engine**
(`runners/coach_arena.py`, `fixtures/gold.json`, `judges/llm_judge*`,
`synthetic/ten_conversations.md`) came first and is preserved as the app-path
lens (`./run.sh python …`). The **Node engine** (this README, `lib/`,
`runners/replay.mjs` + `prepare.mjs`, `fixtures/gold/*.json`, `rubric.json`,
`judges/rubric-judge.md`) is the canonical default because it tests the real
shipping prompt end-to-end without needing an app dump.
