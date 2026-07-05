# Coach Arena — run_2026-07-05_23-32-11

Provider: `anthropic` · coach model: `claude-sonnet-4-6` · judge model: `claude-sonnet-4-6`
Git: `6c18d481` on `ux-overhaul` · prompt: CoachContextBuilder.swift@d1e8d0606efde3a3, AICoachChatService.swift@ad533fcd665b5961

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **69.3** (▼ -0.1) | 70 | ❌ |
| Deep-assessment mean | 70.8 (▼ -4.1) | 70 | ✅ |
| Trust-repair mean | 73.5 (▼ -0.5) | 65 | ✅ |
| Placeholder leaks | 0 | 0 | ✅ |

Scored 51/51 fixtures · range 30–93 · median 72.

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 19.6 | 18.9 | 14 | 10.8 | 11.9 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| goal-change | 3 | 49.3 | (▼ -9.7) |
| partial-pushback | 1 | 50 | (▲ +3) |
| score-question | 1 | 53 | (▼ -21) |
| emotional-frustration | 1 | 56 | (▲ +8) |
| memory-recall | 1 | 56 | (▼ -7) |
| metadata-trap | 1 | 61 | (▲ +21) |
| pressure-mode | 3 | 63.3 | (▼ -12) |
| plan-request | 1 | 64 | (▲ +1) |
| emotional | 4 | 64.3 | (▼ -2.5) |
| interview-prep | 1 | 65 | (▲ +4) |
| leadership-update | 1 | 65 | (±0) |
| cold-start | 1 | 65 | (▲ +14) |
| confidence-ending | 1 | 68 | (▲ +5) |
| mechanics | 6 | 68.8 | (▲ +2.8) |
| deep-assessment | 5 | 70.2 | (▼ -10.6) |
| off-topic | 1 | 72 | (▲ +16) |
| big-moment | 1 | 73 | (▲ +10) |
| filler-pressure | 1 | 74 | (▲ +10) |
| greeting | 1 | 78 | (▲ +5) |
| data-question | 1 | 78 | (▼ -4) |
| trust-repair | 9 | 78.9 | (▼ -0.8) |
| transfer | 3 | 79 | (▲ +15.7) |
| readiness-trap | 1 | 83 | (▲ +2) |
| fabrication-trap | 1 | 84 | (▲ +3) |
| repetition-callout | 1 | 85 | (▲ +2) |

## Reliability caps triggered

- `placeholderOrBroken`: 1

## Worst 10

| Score | Fixture | Turn | closerTo | Top issue |
|---|---|---|---|---|
| **30** | am-i-improving | deepAssessment | excellent | scaffoldLabel |
| **38** | set-authoritative | groundedRead | between | 'Closest match' hedge is unnecessary and |
| **50** | okay-thats-cool-however | groundedRead | between | tooLong |
| **50** | goal-change-engaging | groundedRead | between | tooLong |
| **52** | panic-blank | trustRepair | between | No emotional acknowledgement before advi |
| **53** | score-drop-question | groundedRead | between | tooLong |
| **54** | exhausted | trustRepair | between | No concrete next-step permission given — |
| **56** | its-not-easy | trustRepair | between | Skips the one piece of earned evidence ( |
| **56** | memory-recall | groundedRead | between | tooLong |
| **58** | everyone-better | trustRepair | between | No concrete next move prescribed — ends  |

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
