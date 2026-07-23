# Rewrite Ladder Reliability — Diagnosis + Design-Gate Inputs

**Date:** 2026-07-23 · **Contract task:** COACHING_SYSTEM_SPEC §8 "reliably
earned, consistently surfaced, visually coherent" · **Status:** diagnosis
complete, fixes proposed, nothing implemented yet.

## Why the card is "conditionally" present — the verified funnel

Post-rep (`SummaryView.rewriteSection`), ALL must hold:

1. **Not a retry rep** — one lever at a time (correct per contract §9).
2. **Progress-eligible rep.**
3. **`primaryWeakness != nil`** — drill engine's skill area must be
   opening / closing / structure / concise / answer-development.
   **Filler, pace, pauses, emphasis, confidence → nil BY DESIGN** — those are
   practice-mode interventions, not rewrite-the-script ones
   (SummaryView.swift:269). Most reps land here, so most reps show no ladder.
4. **`AIRewriteService.eligibility == .eligible`** — en-US locale only
   (M13 AI gate), ≥40 chars, ≥8 words, ≥5 distinct words, TTR ≥0.30,
   transcript confidence ≥0.55 when known, no email/phone/SSN patterns.
5. **Pro subscription** — free users get silent absence, not an upsell state.
6. **Live AI call succeeds** — no provider / rate-limit / content-filter /
   voice-drift → honest "no confident rewrite" state with in-moment retry.

Persistence is **sound**: the one-step rung saves immediately on success
(`RewriteSuggestionCard.persistSnapshot`, called at load success), and the
aspiration re-save is additive. History detail then requires the saved snapshot
plus `snapshot.matches(sourceTranscript:)` integrity.

**Why the v1 tour + report 8 missed it:** the seeded rep wasn't Pro, its drill
skill area was a delivery one, and no snapshot was seeded. The v2 capture used
`UI_TESTING_PREMIUM` + `UI_TESTING_REWRITE_LADDER` (forces `.opening`).

## The one real contract conflict

**The recorded pricing default says "first-week review free." The ladder — the
heart of the review teaching loop — is Pro-only, always.** Slice 1's free
first-value moment ("What I heard → One step better → Try it now") cannot
currently happen for a free user. This is a product-contract conflict, not a
bug, and it has a decided answer: honour the pricing default.

## Proposed fixes (in order)

1. **Free-tier alignment** — ladder free during week one (and within the
   3-coached-reps/week allowance thereafter, if that's the reading Jordan
   confirms); outside allowance, a quiet Pro row replaces silent absence.
2. **Designed absence states** — absence must read as coached, not broken:
   - delivery-weakness rep → one line: this rep trains pace/filler, the drill
     is the intervention (no rewrite implied missing);
   - ineligible (short / low-confidence / non-English) → stay silent (honest);
   - generation failed → existing retry state (keep);
   - free-outside-allowance → quiet upsell row.
3. **History regeneration** — Pro users can generate the ladder from history
   detail when no snapshot exists but the transcript still matches and is
   eligible (reuses `RewriteSuggestionCard`; today history is snapshot-only, so
   a rep whose generation failed in the moment never earns its ladder).
4. **Funnel telemetry** — `FlowEventLog` already records ladder-shown; add one
   counter per gate exit (weakness-nil / ineligible / not-pro / call-failed) so
   real-world coverage is measurable before and after.

## What the Figma design gate must include (Review surface)

Five states, not one happy path:
ladder-present · coached-absence (drill-is-the-intervention) · generation-failed
retry · free-tier upsell · retry-rep (suppressed, comparison owns the screen).

## Open question for Jordan

Does "3 free coached reps/week" include the rewrite ladder on those reps after
week one, or is the ladder Pro-only after week one? (Fix 1 implements
whichever; the free-week part is already decided.)
