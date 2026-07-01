# Coach Arena — run_2026-07-01_21-28-55

Provider: `anthropic` · coach model: `claude-sonnet-4-6` · judge model: `claude-sonnet-4-6`
Git: `0bb4e692` on `ux-overhaul` (+7 dirty) · prompt: CoachContextBuilder.swift@d1e8d0606efde3a3, AICoachChatService.swift@ad533fcd665b5961

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **69.4** | 70 | ❌ |
| Deep-assessment mean | 74.9 | 70 | ✅ |
| Trust-repair mean | 74 | 65 | ✅ |
| Placeholder leaks | 0 | 0 | ✅ |

Scored 50/50 fixtures · range 40–90 · median 72.

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 19.4 | 19 | 14 | 10.6 | 11.6 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| metadata-trap | 1 | 40 | — |
| partial-pushback | 1 | 47 | — |
| emotional-frustration | 1 | 48 | — |
| cold-start | 1 | 51 | — |
| off-topic | 1 | 56 | — |
| goal-change | 3 | 59 | — |
| interview-prep | 1 | 61 | — |
| confidence-ending | 1 | 63 | — |
| plan-request | 1 | 63 | — |
| memory-recall | 1 | 63 | — |
| big-moment | 1 | 63 | — |
| transfer | 3 | 63.3 | — |
| filler-pressure | 1 | 64 | — |
| leadership-update | 1 | 65 | — |
| mechanics | 5 | 66 | — |
| emotional | 4 | 66.8 | — |
| greeting | 1 | 73 | — |
| score-question | 1 | 74 | — |
| pressure-mode | 3 | 75.3 | — |
| trust-repair | 9 | 79.7 | — |
| deep-assessment | 5 | 80.8 | — |
| readiness-trap | 1 | 81 | — |
| fabrication-trap | 1 | 81 | — |
| data-question | 1 | 82 | — |
| repetition-callout | 1 | 83 | — |

## Worst 10

| Score | Fixture | Turn | closerTo | Top issue |
|---|---|---|---|---|
| **40** | what-do-you-know | groundedRead | between | tooLong |
| **47** | okay-thats-cool-however | groundedRead | between | tooLong |
| **48** | its-not-easy | trustRepair | between | tooLong |
| **50** | set-authoritative | groundedRead | between | 'The closest voice to what you're descri |
| **51** | cold-start-no-data | groundedRead | between | Trailing question ('What's the setting y |
| **54** | talk-went-well | groundedRead | between | Drops the most important coaching thread |
| **55** | goal-change-engaging | groundedRead | between | Never maps 'engaging' to the two real vo |
| **55** | awkward-pauses | groundedRead | between | tooLong |
| **56** | off-topic-egg | offTopic | between | The 'move' is a stat threshold (1 filler |
| **58** | exhausted | trustRepair | between | Closes with an open question instead of  |

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
