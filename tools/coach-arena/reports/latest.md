# Coach Arena — run_2026-07-08_04-16-00

Provider: `replay` · coach model: `claude-sonnet-4-6` · judge model: `claude-sonnet-4-6`
Git: `52e2752d` on `ux-overhaul` · prompt: CoachContextBuilder.swift@4d08620e52aa0126, AICoachChatService.swift@f69f1b63bea443c4

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **70.2** (▲ +2.6) | 70 | ✅ |
| Deep-assessment mean | 76.7 (▼ -1.9) | 70 | ✅ |
| Trust-repair mean | 73.3 (▲ +2.8) | 65 | ✅ |
| Missing captures | 0 | 0 | ✅ |
| Fixture score floor | 22 | 60 | ❌ |
| Sub-70 fixtures | 16 | 0 | ❌ |
| Placeholder leaks | 2 | 0 | ❌ |

Scored 51/51 fixtures · range 22–88 · median 74.

## App-path evidence

| Metric | Value |
|---|---|
| Status | unavailable (prompt-layer run) |
| App-path score | unavailable |
| Why | This run used the Node prompt-faithful engine. It does not execute the Swift retrieval, memory, caching, provider fallback, live quality gate, or UI pipeline. Run ./tools/coach-arena/run.sh python with a fresh app-path dump to produce this evidence. |

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 19.7 | 18.6 | 14.5 | 12.1 | 11.7 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| cold-start | 1 | 22 | (▼ -39) |
| off-topic | 1 | 45 | (▼ -25) |
| goal-change | 3 | 45.3 | (▼ -9) |
| emotional-frustration | 1 | 56 | (▼ -4) |
| greeting | 1 | 56 | (▼ -20) |
| leadership-update | 1 | 60 | (▼ -15) |
| metadata-trap | 1 | 64 | (▲ +23) |
| mechanics | 6 | 67.2 | (▼ -0.8) |
| repetition-callout | 1 | 69 | (▼ -9) |
| partial-pushback | 1 | 70 | (▲ +18) |
| trust-repair | 9 | 70.4 | (▼ -5) |
| plan-request | 1 | 71 | (▲ +11) |
| filler-pressure | 1 | 73 | (▲ +5) |
| memory-recall | 1 | 73 | (▲ +2) |
| score-question | 1 | 74 | (▲ +3) |
| interview-prep | 1 | 75 | (▲ +10) |
| transfer | 3 | 77 | (▲ +14.7) |
| deep-assessment | 5 | 77.2 | (▼ -6) |
| emotional | 4 | 78.5 | (▲ +12.7) |
| fabrication-trap | 1 | 81 | (▲ +5) |
| pressure-mode | 3 | 82 | (▲ +13.3) |
| confidence-ending | 1 | 83 | (▲ +6) |
| big-moment | 1 | 84 | (▲ +7) |
| readiness-trap | 1 | 85 | (▲ +11) |
| data-question | 1 | 88 | (▲ +10) |

## Reliability caps triggered

- `placeholderOrBroken`: 2

## Worst 10

| Score | Fixture | Turn | closerTo | Top issue |
|---|---|---|---|---|
| **22** | cold-start-no-data | groundedRead | between | coldStartProductJargon |
| **26** | thats-not-informative | trustRepair | between | roboticPhrase |
| **31** | what-voice-should-i-pick | groundedRead | between | roboticPhrase |
| **45** | off-topic-egg | offTopic | between | sensitiveTurnReportVoice |
| **49** | goal-change-engaging | groundedRead | excellent | roboticPhrase |
| **54** | i-ramble | groundedRead | excellent | scaffoldLabel |
| **56** | its-not-easy | trustRepair | between | No next step or presence-close — ends on |
| **56** | greeting-hi | greeting | between | Report-voice residue: recites 'close hel |
| **56** | set-authoritative | groundedRead | excellent | roboticPhrase |
| **57** | talk-too-fast | groundedRead | excellent | sensitiveTurnReportVoice |

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
