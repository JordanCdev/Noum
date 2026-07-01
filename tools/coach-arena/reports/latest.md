# Coach Arena — run_2026-07-01_18-32-51

Provider: `anthropic` · coach model: `claude-sonnet-4-6` · judge model: `claude-sonnet-4-6`
Git: `16eb0c23` on `ux-overhaul` (+6 dirty) · prompt: CoachContextBuilder.swift@241564edd0baa8f8, AICoachChatService.swift@ad533fcd665b5961

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **67.7** (▼ -5) | 70 | ❌ |
| Deep-assessment mean | 76.2 (▼ -0.5) | 70 | ✅ |
| Trust-repair mean | 70.3 (▼ -2.7) | 65 | ✅ |
| Placeholder leaks | 0 | 0 | ✅ |

Scored 60/60 fixtures · range 34–89 · median 71.

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 18.8 | 18.5 | 13.5 | 10.2 | 11.4 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| partial-pushback | 1 | 45 | (▼ -31) |
| plan-request | 1 | 48 | (▼ -23) |
| metadata-trap | 1 | 51 | (▼ -13) |
| emotional-frustration | 1 | 53 | (▼ -3) |
| synthetic-conversation | 10 | 58.6 | (▼ -10) |
| interview-prep | 1 | 59 | (▼ -16) |
| data-question | 1 | 59 | (▼ -29) |
| goal-change | 3 | 59.7 | (▼ -7.3) |
| filler-pressure | 1 | 63 | (▼ -16) |
| emotional | 4 | 63.8 | (▼ -14.7) |
| transfer | 3 | 65 | (▼ -12) |
| mechanics | 5 | 68.2 | (▼ -5.4) |
| cold-start | 1 | 69 | (▲ +31) |
| pressure-mode | 3 | 70 | (▼ -12) |
| greeting | 1 | 72 | (▲ +16) |
| score-question | 1 | 72 | (▼ -8) |
| off-topic | 1 | 73 | (▲ +20) |
| confidence-ending | 1 | 74 | (▼ -15) |
| repetition-callout | 1 | 75 | (▼ -2) |
| memory-recall | 1 | 76 | (▲ +3) |
| deep-assessment | 5 | 77.2 | (±0) |
| big-moment | 1 | 78 | (▼ -6) |
| fabrication-trap | 1 | 78 | (▼ -3) |
| trust-repair | 9 | 78.2 | (▲ +6.4) |
| leadership-update | 1 | 80 | (▲ +20) |
| readiness-trap | 1 | 83 | (▼ -2) |

## Worst 10

| Score | Fixture | Turn | closerTo | Top issue |
|---|---|---|---|---|
| **34** | set-authoritative | groundedRead | between | Inserts 'what's driving the choice?' bef |
| **37** | conv-emotional-dip__t1 | trustRepair | bad | No intervention whatsoever — asking a qu |
| **45** | okay-thats-cool-however | groundedRead | between | tooLong |
| **47** | conv-transfer-report__t1 | groundedRead | between | Misses the critical causation caveat — i |
| **48** | plan-request-week | plan | between | scaffoldLabel |
| **48** | exhausted | trustRepair | between | No concrete rest prescription — asking ' |
| **49** | conv-cold-start-first-rep__t0 | groundedRead | between | Closing question ('What are you trying t |
| **51** | what-do-you-know | groundedRead | between | tooLong |
| **51** | conv-goal-change-arc__t1 | groundedRead | between | tooLong |
| **52** | awkward-pauses | groundedRead | between | tooLong |

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
