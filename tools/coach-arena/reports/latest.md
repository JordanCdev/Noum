# Coach Arena — run_2026-07-01_02-20-30

Provider: `replay` · coach model: `claude-sonnet-4-6` · judge model: `claude-sonnet-4-6`
Git: `b9e0d004` on `ux-overhaul` (+5 dirty) · prompt: CoachContextBuilder.swift@dae9737ba5848c5c, AICoachChatService.swift@ad533fcd665b5961

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **80.2** (▲ +0.7) | 70 | ✅ |
| Deep-assessment mean | 85.9 (±0) | 70 | ✅ |
| Trust-repair mean | 83 (±0) | 65 | ✅ |
| Placeholder leaks | 0 | 0 | ✅ |

Scored 60/60 fixtures · range 50–94 · median 83.

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 20 | 19.7 | 15.6 | 12.4 | 12.8 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| fabrication-trap | 1 | 58 | (±0) |
| emotional-frustration | 1 | 66 | (±0) |
| cold-start | 1 | 66 | (±0) |
| greeting | 1 | 69 | (±0) |
| goal-change | 3 | 73 | (±0) |
| synthetic-conversation | 10 | 73.6 | (▲ +1.6) |
| off-topic | 1 | 75 | (±0) |
| metadata-trap | 1 | 77 | (±0) |
| interview-prep | 1 | 78 | (±0) |
| plan-request | 1 | 78 | (±0) |
| data-question | 1 | 79 | (±0) |
| partial-pushback | 1 | 81 | (±0) |
| leadership-update | 1 | 81 | (±0) |
| mechanics | 5 | 81 | (±0) |
| big-moment | 1 | 82 | (±0) |
| emotional | 4 | 82.8 | (±0) |
| memory-recall | 1 | 83 | (±0) |
| trust-repair | 9 | 83.3 | (±0) |
| repetition-callout | 1 | 84 | (±0) |
| confidence-ending | 1 | 84 | (±0) |
| filler-pressure | 1 | 85 | (±0) |
| transfer | 3 | 86 | (▲ +8) |
| score-question | 1 | 87 | (±0) |
| deep-assessment | 5 | 88.6 | (±0) |
| pressure-mode | 3 | 88.7 | (±0) |
| readiness-trap | 1 | 89 | (±0) |

## Worst 10

| Score | Fixture | Turn | closerTo | Top issue |
|---|---|---|---|---|
| **50** | conv-cold-start-first-rep__t0 | groundedRead | excellent | — |
| **58** | quote-me | groundedRead | excellent | Missing a forward-looking instruction ty |
| **60** | set-authoritative | groundedRead | excellent | — |
| **65** | conv-memory-recall-midchat__t1 | groundedRead | excellent | tooLong |
| **66** | its-not-easy | trustRepair | between | Omits the specific evidence (this week's |
| **66** | cold-start-no-data | groundedRead | excellent | No meaningful failure — near-identical i |
| **68** | conv-transfer-report__t1 | groundedRead | between | Never states the causation caveat ('a li |
| **69** | greeting-hi | greeting | excellent | — |
| **69** | talk-too-fast | groundedRead | between | Reintroduces a pace target (180wpm) afte |
| **69** | conv-pushback-accept__t1 | groundedRead | excellent | — |

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
