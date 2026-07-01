# Coach Arena — run_2026-07-01_12-34-41

Provider: `replay` · coach model: `claude-sonnet-4-6` · judge model: `claude-sonnet-4-6`
Git: `62557002` on `ux-overhaul` (+5 dirty) · prompt: CoachContextBuilder.swift@2a8ac5ac8d014afb, AICoachChatService.swift@ad533fcd665b5961

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **59.4** (▼ -20.4) | 70 | ❌ |
| Deep-assessment mean | 67.7 (▼ -18.2) | 70 | ❌ |
| Trust-repair mean | 60.7 (▼ -22) | 65 | ❌ |
| Placeholder leaks | 0 | 0 | ✅ |

Scored 60/60 fixtures · range 38–79 · median 60.

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 16.3 | 15.2 | 12.1 | 9.8 | 10.8 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| cold-start | 1 | 40 | (▼ -26) |
| greeting | 1 | 42 | (▼ -27) |
| emotional-frustration | 1 | 50 | (▼ -10) |
| goal-change | 3 | 50 | (▼ -23) |
| metadata-trap | 1 | 52 | (▼ -25) |
| transfer | 3 | 52.3 | (▼ -33.7) |
| synthetic-conversation | 10 | 53.8 | (▼ -19.2) |
| off-topic | 1 | 54 | (▼ -21) |
| fabrication-trap | 1 | 54 | (▼ -4) |
| emotional | 4 | 56.8 | (▼ -26) |
| filler-pressure | 1 | 57 | (▼ -28) |
| plan-request | 1 | 57 | (▼ -21) |
| repetition-callout | 1 | 58 | (▼ -26) |
| mechanics | 5 | 60.4 | (▼ -18.2) |
| confidence-ending | 1 | 61 | (▼ -23) |
| score-question | 1 | 61 | (▼ -26) |
| trust-repair | 9 | 64.4 | (▼ -18.9) |
| big-moment | 1 | 65 | (▼ -17) |
| readiness-trap | 1 | 65 | (▼ -24) |
| deep-assessment | 5 | 66.4 | (▼ -22.2) |
| pressure-mode | 3 | 67.7 | (▼ -21) |
| memory-recall | 1 | 69 | (▼ -14) |
| interview-prep | 1 | 70 | (▼ -8) |
| data-question | 1 | 70 | (▼ -9) |
| partial-pushback | 1 | 75 | (▼ -6) |
| leadership-update | 1 | 77 | (▼ -4) |

## Worst 10

| Score | Fixture | Turn | closerTo | Top issue |
|---|---|---|---|---|
| **38** | conv-cold-start-first-rep__t0 | groundedRead | between | — |
| **39** | conv-transfer-report__t1 | groundedRead | between | Never states the required causation cave |
| **40** | cold-start-no-data | groundedRead | between | — |
| **42** | greeting-hi | greeting | between | Mild report-voice residue in the rep tal |
| **48** | talk-too-fast | groundedRead | between | Bundles the pause-beat move with a contr |
| **48** | awkward-pauses | groundedRead | between | tooLong |
| **48** | froze-in-meeting | trustRepair | between | Asks a question ('the room or the words' |
| **48** | what-voice-should-i-pick | groundedRead | between | Reasoning for the top pick is generic co |
| **49** | goal-change-engaging | groundedRead | between | Clarifying question is generic rather th |
| **49** | not-improving | trustRepair | between | Opens with the correction instead of ack |

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
