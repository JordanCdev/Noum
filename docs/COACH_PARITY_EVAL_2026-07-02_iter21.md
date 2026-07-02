# Coach-parity eval — iteration 21 (2026-07-02, autonomous `noum-1` run)

Branch: `ux-overhaul` · toolchain: real (Xcode 26.3, iPhone 17 / iOS 26 sim,
isolated `DerivedData/Noum-iter21`) · no push.

## Summary

Shipped the **one purely-software honesty lever the iter-20 ledger carried that
was closable without an API key** (its ranked item #3): an honest empty-state on
the `SummaryView` "More from this rep" disclosure. Found + adversarially verified
by a 5-role panel reading the working tree directly; **unanimous ship-with-notes**,
and it survived a dedicated refutation pass.

Commit: `SUMMARY-EMPTYSTATE` (pending). Full method + verdicts below.

## The lever

Every speech-quality card in the disclosure self-hides when it lacks signal
(`EloquenceFindingsCard`→`EmptyView`, `PauseSummaryCard`/`PitchSummaryCard`/
`RepTimelineCard`/`RepEventTrendCard` gated on nil/empty, `WordChoiceCard`→
`EmptyView` under `minContentWords`, `GrammarPolishCard`→`EmptyView` without AI
findings). Correct restraint — but on a short **first** rep the whole analytical
block can render nothing, so "More from this rep" opens to a hollow disclosure
that reads like a bug and silently drops the small-sample-honesty coaching moment.

Fix: a pure `SummaryAnalyticsEmptyState.message(...)` names the restraint out
loud ("Your speech-pattern read builds over your first few reps. Noum waits until
a position has actually recurred before it names a habit — so what surfaces here
stays honest, not guessed.") and a render-only block in `SummaryView` shows it
with existing tokens (`Typography.body`, `Spacing`, `AppColor.cardBackground`),
`.fixedSize` for Dynamic Type, and a combined VoiceOver label.

## The load-bearing honesty guard (caught beyond the panel)

The empty-state renders **only when `repCount < patternFloor (3)`**. A mature
user (rep 50) whose one rep happened to be quiet is deliberately NOT told
"patterns are still building" — that would be a small-sample lie in the *other*
direction, and a nag. Past the floor, silence stays the honest default (current
behaviour). This guard — not the message — is the point: it mirrors
`RepEventTrendEngine`'s own occurrence floor so the two honesty gates stay
aligned. Locked by test (`matureQuietRepStaysSilent`, `repCount: 3` and `50`).

## Architecture / reuse

- Pure decider + render-only view, mirroring the praised `RepEventTrendCopy` /
  `RepTimelineCopy` pattern. Zero new tokens, zero new persistence, zero new
  store/route. Self-hides on any signal (`Signals.anyPresent`) and on IM summary.
- Two per-render computes hoisted (`positionalTrends`, `wordChoiceMetrics`) so the
  gate reuses them — no extra work vs. before.
- +6 tests (`SummaryAnalyticsEmptyStateTests`) locking: shows on rep 1/2 with no
  analytics; self-hides on each of the six signals; silent for a mature quiet rep;
  never on IM; copy carries no coach-replacement / certainty overclaim.

## Method

Workflow `coach-parity-iter21`: 5-role scout panel (market · UX · cold end-user ·
veteran coach · staff-eng/QA), each reading the working tree with an explicit
mandate that "no clean lever — the loop has hit its ceiling" was a valid answer.
All five converged on this lever; an adversarial verifier tried to refute it
(fake progress? already handled? device-gated? overclaim? collision?) and it
survived → ship-with-notes. I then re-verified every cited `file:line` against the
code myself and added the mature-rep guard the panel had not explicitly named.

## Verification

- Build GREEN (exit 0) with the two new files, iPhone 17 / iOS 26, isolated
  `DerivedData/Noum-iter21`.
- `SummaryAnalyticsEmptyStateTests` + regression on `RepEventTrendEngineTests` /
  `RepTimelineCardTests`: `** TEST SUCCEEDED **` (see run log).
- Collision-safe: staged only my 3 files by pathspec; the concurrent tree's
  uncommitted `Localizable.xcstrings` + `ten_conversations.md` + `.screenshots/`
  left byte-for-byte untouched.

## The 10/10 answer — unchanged, and unchanged by design

The literal **"10/10, with no doubt replaces a human coach" stays REFUSED BY
DESIGN** (`CoachParityReadiness.forming` trust-moat cap). This iteration is a
structurally-sound honesty upgrade; it does not move the global cap and is not
meant to. The distance to 10 remains **external, not a defect in this run**:

| Gap | Class | Why not closable here |
|---|---|---|
| Prove the recurring-position line surfaces in a live coach reply | **[environment]** | No `ANTHROPIC_API_KEY` in this autonomous env; needs a live model + `coach-arena` assertion. **This remains the single highest-value remaining software lever and is the honest blocker to flag to Jordan.** |
| ≤6-rep base-rate window trusted as stable | **[external-calibration]** | Needs a coach-labeled corpus, not a code change. |
| Phone reads words, not breath/tension/body | **[hardware]** | On-device camera+mic perception the text pipeline can't add. |
| No longitudinal real-user outcome proof | **[longitudinal]** | A cohort study — outside code entirely. |

With this run, the iter-20 ledger's one **[closable-in-software, no-key]** item is
closed. The remaining ranked levers are all environment- or external-data-gated.

## Honest note to Jordan

The headless prompt/UX loop is now at its verified ceiling: 21 iterations in, the
next real move (#1 above) needs you to supply an `ANTHROPIC_API_KEY` so the
`coach-arena` behaviour assertion can run — otherwise remaining code work is
marginal and risks the fake-progress the CLAUDE.md bans. Figma/Canva connectors
are live but weren't needed this run (no concrete visual spec to execute; the
change reuses shipped tokens). If you want the loop to keep producing verified
substance, the key is the unlock.
