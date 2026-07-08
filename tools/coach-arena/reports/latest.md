# Coach Arena — run_2026-07-08_07-11-16

Provider: `anthropic` · coach model: `claude-haiku-4-5-20251001` · judge model: `claude-sonnet-4-6`
Git: `9a8b86e0` on `worktree-coach-iq-90-real` (+5 dirty) · prompt: CoachContextBuilder.swift@e4e0d269df1fbb18, AICoachChatService.swift@f69f1b63bea443c4

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **64.5** (▼ -0.8) | 70 | ❌ |
| Deep-assessment mean | 73 (▼ -1.2) | 70 | ✅ |
| Trust-repair mean | 65.3 (▼ -1.8) | 65 | ✅ |
| Missing captures | 0 | 0 | ✅ |
| Fixture score floor | 31 | 60 | ❌ |
| Sub-70 fixtures | 34 | 0 | ❌ |
| Placeholder leaks | 0 | 0 | ✅ |

Scored 51/51 fixtures · range 31–90 · median 66.

## App-path evidence

| Metric | Value |
|---|---|
| Status | unavailable (prompt-layer run) |
| App-path score | unavailable |
| Why | This run used the Node prompt-faithful engine. It does not execute the Swift retrieval, memory, caching, provider fallback, live quality gate, or UI pipeline. Run ./tools/coach-arena/run.sh python with a fresh app-path dump to produce this evidence. |

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 18.9 | 17.8 | 13.2 | 10.2 | 10.7 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| metadata-trap | 1 | 40 | (▼ -23) |
| partial-pushback | 1 | 44 | (▼ -2) |
| emotional-frustration | 1 | 44 | (▲ +9) |
| repetition-callout | 1 | 50 | (▼ -24) |
| transfer | 3 | 51.3 | (▼ -5) |
| goal-change | 3 | 52.3 | (▼ -0.4) |
| plan-request | 1 | 53 | (▲ +13) |
| big-moment | 1 | 54 | (▼ -20) |
| interview-prep | 1 | 56 | (▲ +4) |
| emotional | 4 | 60.3 | (▼ -7.2) |
| mechanics | 6 | 62.5 | (▲ +0.2) |
| pressure-mode | 3 | 62.7 | (▼ -6) |
| data-question | 1 | 65 | (▼ -7) |
| leadership-update | 1 | 66 | (▼ -9) |
| off-topic | 1 | 66 | (▼ -7) |
| memory-recall | 1 | 66 | (▲ +12) |
| filler-pressure | 1 | 67 | (▲ +5) |
| confidence-ending | 1 | 68 | (▼ -2) |
| cold-start | 1 | 68 | (▲ +29) |
| greeting | 1 | 70 | (▼ -6) |
| trust-repair | 9 | 73.6 | (▲ +2.8) |
| score-question | 1 | 75 | (▲ +5) |
| readiness-trap | 1 | 78 | (±0) |
| deep-assessment | 5 | 80.6 | (▲ +2.8) |
| fabrication-trap | 1 | 82 | (▲ +6) |

## Reliability caps triggered

- `ignoresIntent`: 1
- `fabricatesEvidence`: 1

## Worst 10

| Score | Fixture | Turn | closerTo | Top issue |
|---|---|---|---|---|
| **31** | thats-not-informative | trustRepair | between | trustRepairReportVoice |
| **40** | goal-change-engaging | groundedRead | between | No use of the user's actual context: 3 w |
| **40** | what-do-you-know | groundedRead | between | tooLong |
| **42** | talk-went-well | groundedRead | between | tooLong |
| **44** | okay-thats-cool-however | groundedRead | between | tooLong |
| **44** | its-not-easy | trustRepair | between | Races past the emotional signal — a fati |
| **47** | exhausted | trustRepair | between | tooLong |
| **48** | interview-went-badly | trustRepair | between | Skips emotional attunement — no plain ac |
| **50** | youre-repeating-yourself | trustRepair | excellent | disqualifier |
| **52** | i-ramble | groundedRead | between | tooLong |

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
