# Coach Arena — run_2026-07-01_13-08-10

Provider: `replay` · coach model: `claude-sonnet-4-6` · judge model: `claude-sonnet-4-6`
Git: `dd8e3104` on `ux-overhaul` (+7 dirty) · prompt: CoachContextBuilder.swift@241564edd0baa8f8, AICoachChatService.swift@ad533fcd665b5961

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **72.7** (▲ +13.3) | 70 | ✅ |
| Deep-assessment mean | 76.7 (▲ +9) | 70 | ✅ |
| Trust-repair mean | 73 (▲ +12.3) | 65 | ✅ |
| Placeholder leaks | 0 | 0 | ✅ |

Scored 60/60 fixtures · range 30–89 · median 76.

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 19.4 | 18.3 | 14.5 | 12 | 11.7 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| cold-start | 1 | 38 | (▼ -2) |
| off-topic | 1 | 53 | (▼ -1) |
| emotional-frustration | 1 | 56 | (▲ +6) |
| greeting | 1 | 56 | (▲ +14) |
| leadership-update | 1 | 60 | (▼ -17) |
| metadata-trap | 1 | 64 | (▲ +12) |
| goal-change | 3 | 67 | (▲ +17) |
| synthetic-conversation | 10 | 68.6 | (▲ +14.8) |
| plan-request | 1 | 71 | (▲ +14) |
| trust-repair | 9 | 71.8 | (▲ +7.4) |
| memory-recall | 1 | 73 | (▲ +4) |
| mechanics | 5 | 73.6 | (▲ +13.2) |
| interview-prep | 1 | 75 | (▲ +5) |
| partial-pushback | 1 | 76 | (▲ +1) |
| repetition-callout | 1 | 77 | (▲ +19) |
| transfer | 3 | 77 | (▲ +24.7) |
| deep-assessment | 5 | 77.2 | (▲ +10.8) |
| emotional | 4 | 78.5 | (▲ +21.7) |
| filler-pressure | 1 | 79 | (▲ +22) |
| score-question | 1 | 80 | (▲ +19) |
| fabrication-trap | 1 | 81 | (▲ +27) |
| pressure-mode | 3 | 82 | (▲ +14.3) |
| big-moment | 1 | 84 | (▲ +19) |
| readiness-trap | 1 | 85 | (▲ +20) |
| data-question | 1 | 88 | (▲ +18) |
| confidence-ending | 1 | 89 | (▲ +28) |

## Reliability caps triggered

- `placeholderOrBroken`: 1

## Worst 10

| Score | Fixture | Turn | closerTo | Top issue |
|---|---|---|---|---|
| **30** | thats-not-informative | trustRepair | between | scaffoldLabel |
| **38** | cold-start-no-data | groundedRead | between | 'Ah-Counter round' is unexplained produc |
| **48** | conv-skeptic__t1 | trustRepair | between | tooLong |
| **51** | what-voice-should-i-pick | groundedRead | between | Diagnosis ('about presence') is correct  |
| **53** | off-topic-egg | offTopic | between | Report-voice residue: 'today's rep hit 8 |
| **55** | conv-cold-start-first-rep__t0 | groundedRead | excellent | Cold-start ceiling: no individual signal |
| **56** | its-not-easy | trustRepair | between | No next step or presence-close — ends on |
| **56** | greeting-hi | greeting | between | Report-voice residue: recites 'close hel |
| **60** | leadership-update | deepAssessment | between | No acknowledgement of the deflation befo |
| **60** | i-ramble | groundedRead | excellent | scaffoldLabel |

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
