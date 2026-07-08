# Coach Arena — run_2026-07-08_07-11-16

Provider: `anthropic` · coach model: `claude-haiku-4-5-20251001` · judge model: `claude-sonnet-4-6`
Git: `9a8b86e0` on `worktree-coach-iq-90-real` (+5 dirty) · prompt: CoachContextBuilder.swift@e4e0d269df1fbb18, AICoachChatService.swift@f69f1b63bea443c4

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **64.5** (±0) | 70 | ❌ |
| Deep-assessment mean | 73 (±0) | 70 | ✅ |
| Trust-repair mean | 65.3 (±0) | 65 | ✅ |
| Missing captures | 0 | 0 | ✅ |
| Fixture score floor | 31 | 60 | ❌ |
| Sub-70 fixtures | 34 | 0 | ❌ |
| Placeholder leaks | 0 | 0 | ✅ |

Scored 51/51 fixtures · range 31–90 · median 66.

## Prompt-cache usage (this run)

| Metric | Value |
|---|---|
| Requests with usage data | 51 |
| Cache hit rate | 0% (0/51) |
| Cache read tokens (Anthropic) | 0 |
| Cache creation tokens (Anthropic) | 0 |
| Cached content tokens (Gemini) | 0 |
| Input tokens | 417427 |
| Output tokens | 6120 |
| Estimated tokens saved by cache | 0 |

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
| metadata-trap | 1 | 40 | (±0) |
| partial-pushback | 1 | 44 | (±0) |
| emotional-frustration | 1 | 44 | (±0) |
| repetition-callout | 1 | 50 | (±0) |
| transfer | 3 | 51.3 | (±0) |
| goal-change | 3 | 52.3 | (±0) |
| plan-request | 1 | 53 | (±0) |
| big-moment | 1 | 54 | (±0) |
| interview-prep | 1 | 56 | (±0) |
| emotional | 4 | 60.3 | (±0) |
| mechanics | 6 | 62.5 | (±0) |
| pressure-mode | 3 | 62.7 | (±0) |
| data-question | 1 | 65 | (±0) |
| leadership-update | 1 | 66 | (±0) |
| off-topic | 1 | 66 | (±0) |
| memory-recall | 1 | 66 | (±0) |
| filler-pressure | 1 | 67 | (±0) |
| confidence-ending | 1 | 68 | (±0) |
| cold-start | 1 | 68 | (±0) |
| greeting | 1 | 70 | (±0) |
| trust-repair | 9 | 73.6 | (±0) |
| score-question | 1 | 75 | (±0) |
| readiness-trap | 1 | 78 | (±0) |
| deep-assessment | 5 | 80.6 | (±0) |
| fabrication-trap | 1 | 82 | (±0) |

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
