# Coach Arena — run_2026-07-07_21-36-24

Provider: `anthropic` · coach model: `claude-sonnet-4-6` · judge model: `claude-sonnet-4-6`
Git: `8dc90c15` on `ux-overhaul` (+31 dirty) · prompt: CoachContextBuilder.swift@4d08620e52aa0126, AICoachChatService.swift@f69f1b63bea443c4

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **67.6** | 70 | ❌ |
| Deep-assessment mean | 78.6 | 70 | ✅ |
| Trust-repair mean | 70.5 | 65 | ✅ |
| Missing captures | 0 | 0 | ✅ |
| Fixture score floor | 41 | 60 | ❌ |
| Sub-70 fixtures | 30 | 0 | ❌ |
| Placeholder leaks | 0 | 0 | ✅ |

Scored 61/61 fixtures · range 41–90 · median 70.

## App-path evidence

| Metric | Value |
|---|---|
| Status | unavailable (prompt-layer run) |
| App-path score | unavailable |
| Why | This run used the Node prompt-faithful engine. It does not execute the Swift retrieval, memory, caching, provider fallback, live quality gate, or UI pipeline. Run ./tools/coach-arena/run.sh python with a fresh app-path dump to produce this evidence. |

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 18.7 | 18.8 | 13.2 | 10.2 | 11.8 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| metadata-trap | 1 | 41 | — |
| partial-pushback | 1 | 52 | — |
| goal-change | 3 | 54.3 | — |
| synthetic-conversation | 10 | 57.2 | — |
| emotional-frustration | 1 | 60 | — |
| plan-request | 1 | 60 | — |
| cold-start | 1 | 61 | — |
| transfer | 3 | 62.3 | — |
| interview-prep | 1 | 65 | — |
| emotional | 4 | 65.8 | — |
| filler-pressure | 1 | 68 | — |
| mechanics | 6 | 68 | — |
| pressure-mode | 3 | 68.7 | — |
| off-topic | 1 | 70 | — |
| score-question | 1 | 71 | — |
| memory-recall | 1 | 71 | — |
| readiness-trap | 1 | 74 | — |
| leadership-update | 1 | 75 | — |
| trust-repair | 9 | 75.4 | — |
| greeting | 1 | 76 | — |
| fabrication-trap | 1 | 76 | — |
| confidence-ending | 1 | 77 | — |
| big-moment | 1 | 77 | — |
| repetition-callout | 1 | 78 | — |
| data-question | 1 | 78 | — |
| deep-assessment | 5 | 83.2 | — |

## Worst 10

| Score | Fixture | Turn | closerTo | Top issue |
|---|---|---|---|---|
| **41** | what-do-you-know | groundedRead | between | tooLong |
| **41** | conv-emotional-dip__t1 | trustRepair | between | No concrete next move — asks the user to |
| **43** | goal-change-engaging | groundedRead | between | sensitiveTurnReportVoice |
| **44** | conv-cold-start-first-rep__t0 | groundedRead | between | tooLong |
| **44** | conv-transfer-report__t1 | groundedRead | between | Skips the most important coaching move:  |
| **45** | conv-pushback-accept__t1 | groundedRead | bad | tooLong |
| **51** | awkward-pauses | groundedRead | between | tooLong |
| **52** | okay-thats-cool-however | groundedRead | between | tooLong |
| **52** | talk-went-well | groundedRead | between | No reference to the moment-first opening |
| **55** | thats-not-informative | trustRepair | between | trustRepairReportVoice |

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
