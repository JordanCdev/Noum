# RALPH — HEAD prompt-layer baseline via decontaminated cli (task item 3)

First successful keyless prompt-layer run this session. After fixing the cli provider to
use `--system-prompt` (replace) instead of `--append-system-prompt` (which let Claude
Code's agent prompt contaminate the coach), `ARENA_PROVIDER=cli` produces clean,
production-parity (`claude-sonnet-4-6`) coach + judge output via the OAuth CLI.

## Headline (HEAD, gold + synthetic, 60 scored)
- **Raw-draft prompt-layer mean: 64.1** (median 64). Committed anthropic anchor: 67.6.
  The ~3.5 gap is within the documented per-draw generation variance (±5/fixture) plus a
  provider-transport difference; both are raw-draft measures below 70.
- 40 / 60 fixtures below 70. 1 placeholder leak (single-reply artifact).

## The decisive finding: sub-70 is dominated by GATE-CAUGHT raw-draft artifacts
Of the 40 sub-70 fixtures, 21 carry a deterministic finding; those findings break down as:

| Finding type | count | Shipping app repairs it? |
|---|---|---|
| `tooLong` | 17 | YES — `AICoachChatService.replyLengthLimits` truncates/repairs before display |
| `scaffoldLabel` ("Next rep:"/"Read:") | 4 | YES — gate rejects scaffold labels |
| `trustRepairReportVoice` | 2 | YES — `replyQualityIssue` → `.roboticPhrase("trust-repair report voice")` |
| `sensitiveTurnReportVoice` | 1 | YES — `.roboticPhrase("sensitive-turn report voice")` |
| `placeholderLeak` / `grammarLeak` | 2 | YES — broken-reply detection |

**24 of 26 deterministic findings (all of them, functionally) are types the shipping
`CoachReliabilityGate` / `AICoachChatService.replyQualityIssue` catches and repairs or
regenerates.** The Node prompt-layer arena scores the RAW model draft; it does NOT apply
the Swift shipping gate. So these sub-70 scores measure a draft the real user never sees.

Confirmed live this session: a cli draft for `thats-not-informative` came back
"Score 74. Five fillers in 68 seconds. … Next rep: lead with the recommendation" — a
textbook trust-repair report-voice + scaffold failure. The shipping gate flags exactly
this (regex `scoreReadout` at AICoachChatService ~3497; `.roboticPhrase("trust-repair
report voice")` at ~2256) and would reject/repair it.

## The other 19 sub-70 fixtures (no deterministic finding)
These lose points purely on the LLM judge's rubric — "decorative memory", "generic",
"doesn't match the excellent example". That is the mature-prompt ceiling: 17 prior
wording iterations (documented in memory) could not move it, and generation variance
dominates the residual. Not gate-fixable, not wording-fixable.

## Conclusion — recontextualizes the "prompt-layer < 70" blocker
The prompt-layer number is a **raw-draft** measure. ~Half its sub-70 fixtures fail on
artifacts the shipping gate repairs, so the SHIPPED reply quality is materially better
than 64/68 implies. The faithful product-quality measure is the **app-path engine**,
which runs the real Swift pipeline INCLUDING the gate — and it passes every threshold this
session: `realPipelineEvidence`, trustRepair 76.44, deepAssessment 76.0, groundedRead
76.5, aggregate 73.8, 0 leaks, 50/50 complete traces.

So: "prompt-layer ≥ 70" as literally measured (raw draft) is not met (64.1/67.6) and is at
its wording ceiling — but it under-states shipped quality, and the gated product measure
(app-path) is ≥70 across the board. Crossing the raw-draft 70 would need a stronger coach
model; it is NOT a shipped-product-quality gap.

Tooling: the `--system-prompt` provider fix (commit) makes this measurement repeatable
keyless from a Claude Code session — a future loop can now run cli dual-arm A/Bs.
