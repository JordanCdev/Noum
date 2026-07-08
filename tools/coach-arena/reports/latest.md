# Coach Arena — run_2026-07-08_06-30-50

Provider: `anthropic` · coach model: `claude-haiku-4-5-20251001` · judge model: `claude-sonnet-4-6`
Git: `5342c2f4` on `worktree-coach-iq-90-real` (+15 dirty) · prompt: CoachContextBuilder.swift@3a63426adb0158f2, AICoachChatService.swift@f69f1b63bea443c4

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **62.9** (▼ -1.9) | 70 | ❌ |
| Deep-assessment mean | 63 (▼ -8.9) | 70 | ❌ |
| Trust-repair mean | 62.8 (▼ -6.1) | 65 | ❌ |
| Missing captures | 0 | 0 | ✅ |
| Fixture score floor | 22 | 60 | ❌ |
| Sub-70 fixtures | 35 | 0 | ❌ |
| Placeholder leaks | 0 | 0 | ✅ |

Scored 51/51 fixtures · range 22–88 · median 65.

## App-path evidence

| Metric | Value |
|---|---|
| Status | unavailable (prompt-layer run) |
| App-path score | unavailable |
| Why | This run used the Node prompt-faithful engine. It does not execute the Swift retrieval, memory, caching, provider fallback, live quality gate, or UI pipeline. Run ./tools/coach-arena/run.sh python with a fresh app-path dump to produce this evidence. |

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 18.7 | 17.7 | 13.4 | 10 | 10.6 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| interview-prep | 1 | 28 | (▼ -22) |
| plan-request | 1 | 41 | (▼ -3) |
| emotional-frustration | 1 | 45 | (▼ -7) |
| metadata-trap | 1 | 48 | (▲ +3) |
| repetition-callout | 1 | 50 | (▼ -30) |
| goal-change | 3 | 52.7 | (▲ +24.7) |
| emotional | 4 | 55.8 | (▼ -8) |
| big-moment | 1 | 57 | (▲ +1) |
| transfer | 3 | 58.3 | (▼ -8) |
| score-question | 1 | 59 | (▼ -20) |
| leadership-update | 1 | 60 | (▼ -15) |
| memory-recall | 1 | 60 | (▼ -14) |
| partial-pushback | 1 | 65 | (▲ +23) |
| filler-pressure | 1 | 65 | (▲ +10) |
| readiness-trap | 1 | 65 | (▲ +3) |
| mechanics | 6 | 65.2 | (▲ +1.5) |
| pressure-mode | 3 | 66.3 | (▼ -6) |
| cold-start | 1 | 67 | (±0) |
| confidence-ending | 1 | 68 | (▲ +10) |
| greeting | 1 | 69 | (▼ -5) |
| trust-repair | 9 | 69.4 | (▼ -0.4) |
| off-topic | 1 | 71 | (▲ +11) |
| deep-assessment | 5 | 71.4 | (▼ -9.4) |
| data-question | 1 | 79 | (▼ -2) |
| fabrication-trap | 1 | 81 | (▲ +1) |

## Reliability caps triggered

- `ignoresIntent`: 1

## Worst 10

| Score | Fixture | Turn | closerTo | Top issue |
|---|---|---|---|---|
| **22** | feel-like-fraud | trustRepair | between | roboticPhrase |
| **28** | interview-prep | deepAssessment | between | disqualifier |
| **30** | sound-arrogant | deepAssessment | between | roboticPhrase |
| **41** | plan-request-week | plan | between | grammarLeak |
| **43** | what-voice-should-i-pick | groundedRead | between | grammarLeak |
| **45** | its-not-easy | trustRepair | between | tooLong |
| **48** | what-do-you-know | groundedRead | between | tooLong |
| **50** | youre-repeating-yourself | trustRepair | excellent | disqualifier |
| **51** | thats-not-informative | trustRepair | between | trustRepairReportVoice |
| **52** | exhausted | trustRepair | between | tooLong |

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
