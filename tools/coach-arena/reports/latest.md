# Coach Arena — run_2026-07-01_02-10-22

Provider: `replay` · coach model: `claude-sonnet-4-6` · judge model: `claude-sonnet-4-6`
Git: `bc1c25bb` on `ux-overhaul` (+24 dirty) · prompt: CoachContextBuilder.swift@4b448c852664e75c, AICoachChatService.swift@ad533fcd665b5961

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **79.5** (▲ +3) | 70 | ✅ |
| Deep-assessment mean | 85.9 (▲ +7.7) | 70 | ✅ |
| Trust-repair mean | 83 (▲ +2.6) | 65 | ✅ |
| Placeholder leaks | 0 | 0 | ✅ |

Scored 60/60 fixtures · range 50–94 · median 83.

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 19.7 | 19.6 | 15.5 | 12.2 | 12.7 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| fabrication-trap | 1 | 58 | (▼ -6) |
| emotional-frustration | 1 | 66 | (▲ +13) |
| cold-start | 1 | 66 | (▲ +12) |
| greeting | 1 | 69 | (▲ +7) |
| synthetic-conversation | 10 | 72 | (▼ -3) |
| goal-change | 3 | 73 | (▲ +13) |
| off-topic | 1 | 75 | (▲ +10) |
| metadata-trap | 1 | 77 | (▲ +35) |
| interview-prep | 1 | 78 | (▲ +48) |
| plan-request | 1 | 78 | (▲ +2) |
| transfer | 3 | 78 | (±0) |
| data-question | 1 | 79 | (▲ +5) |
| partial-pushback | 1 | 81 | (▲ +8) |
| leadership-update | 1 | 81 | (▲ +11) |
| mechanics | 5 | 81 | (▼ -4.2) |
| big-moment | 1 | 82 | (▲ +10) |
| emotional | 4 | 82.8 | (▲ +1) |
| memory-recall | 1 | 83 | (▲ +7) |
| trust-repair | 9 | 83.3 | (▲ +0.6) |
| repetition-callout | 1 | 84 | (▼ -4) |
| confidence-ending | 1 | 84 | (▼ -2) |
| filler-pressure | 1 | 85 | (▼ -1) |
| score-question | 1 | 87 | (▲ +3) |
| deep-assessment | 5 | 88.6 | (▼ -0.8) |
| pressure-mode | 3 | 88.7 | (▲ +8.4) |
| readiness-trap | 1 | 89 | (▲ +4) |

## Worst 10

| Score | Fixture | Turn | closerTo | Top issue |
|---|---|---|---|---|
| **50** | conv-cold-start-first-rep__t0 | groundedRead | excellent | — |
| **52** | conv-transfer-report__t1 | groundedRead | between | Implies the drill caused the outcome ('c |
| **57** | talk-went-well | groundedRead | between | Declares 'worth trusting now' from a sin |
| **58** | quote-me | groundedRead | excellent | Missing a forward-looking instruction ty |
| **60** | set-authoritative | groundedRead | excellent | — |
| **65** | conv-memory-recall-midchat__t1 | groundedRead | excellent | tooLong |
| **66** | its-not-easy | trustRepair | between | Omits the specific evidence (this week's |
| **66** | cold-start-no-data | groundedRead | excellent | No meaningful failure — near-identical i |
| **69** | greeting-hi | greeting | excellent | — |
| **69** | talk-too-fast | groundedRead | between | Reintroduces a pace target (180wpm) afte |

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
