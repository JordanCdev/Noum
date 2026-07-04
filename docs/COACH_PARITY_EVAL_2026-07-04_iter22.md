# Coach-parity re-benchmark — iteration 22 (2026-07-04, autonomous `noum2` run)

Branch: `ux-overhaul` · no push · shipped one keyless, collision-safe lever +
two review artifacts. Method: a 5-role competitive re-benchmark workflow
(market · UX/visual · cold end-user · veteran coach · staff-eng/QA) → adversarial
synthesis, then I verified the top lever against the code and implemented it.

## The headline for Jordan

**The "software loop is at its ceiling" claim from iters 20–21 is TRUE but was
scoped too narrowly.** It is correct for exactly one axis: the interior
coaching-**honesty** prompt loop measured through `coach-arena`. 21 iterations
wrung the restraint / hedging / empty-state / gate levers dry there, and the
final live-reply A/B genuinely needs an `ANTHROPIC_API_KEY` this environment does
not have (confirmed unset; the `cli` provider path 401s from a nested session).

All five roles independently found that "the *whole software surface* is at its
ceiling" conflates that one prompt axis with four others that are **not** at their
ceiling and **do not need the key**:

1. **Harness parity** (shipped this run) — the arena literally could not feed the
   coach the recurring-position line iters 19–20 shipped, so the loop could not
   test its own #1 named behaviour.
2. **Coaching substance** — deterministic content/structure diagnosis
   (buried-lede, "no *because*") the lexical layer can't see. Pure Swift, no key.
3. **Visual presentation** — the market-leading insight renders as a motion-free
   text list; the picture lags the insight. Design work, review-gated.
4. **First-run trust** — the picker + 15s default countdown sit between onboarding
   and the proof moment (the ledger's own 5.5 drag). `AutoGuidedFirstRep` built,
   still default-OFF.

**The key unblocks *behaviour proof*, not the next move. The next move was keyless
and sitting in `context.mjs`** — this run closed it.

## Shipped: harness parity (`a96152ac`)

`tools/coach-arena/lib/context.mjs` rendered `PROMPT RELEVANCE` (most-recent-rep
positional read) and a generic `TRENDS` block, but had **no recurring-position
`POSITIONAL TREND` section** mirroring Swift's `RepEventTrendEngine` →
`CoachContextBuilder`. So every arena run fed the model everything *except* the
one longitudinal line iters 19–20 shipped ("you've rushed the close in 4 of your
last 5 reps…"), then the ledger reported that behaviour un-verifiable. It was
un-verifiable because the harness never presented it.

- **Faithful JS port** of `RepEventTrend.readout` (`Noum/RepEventTrend.swift:63`)
  from the same typed fields (`kind` / `zone` / `dominantCount` / `repsWithSignal`
  / `windowRepCount`), including the **base-rate prevalence-suppression rule**
  (omit "N of your last N reps overall" when the event carried every readable rep,
  so a 100% tail never reads as a redundant "N of N"). Rendered under the exact
  header `CoachContextBuilder` emits, in read→trend order. Omitted when absent —
  same "never invent a section" contract as every other block. Accepts a
  pre-composed string too (parity with the `promptRelevance`/`structureRead`
  string sections).
- **+4 keyless context-presence tests** locking the render, byte-for-byte
  Swift-parity wording, the 100%-tail suppression, omission-when-absent, and
  malformed-drop. `node --test`: **37 pass / 0 fail**.
- **New gold fixture** `51-recurring-close-rush.json` — a `groundedRead` case whose
  whole point is the recurring-position move, so a *keyed* run rewards the coach
  for actually speaking the trend. `validateFixtures`: **51 fixtures, 0 errors**
  (the one warning is pre-existing on `09-confidence-ending`).

Why this is real progress under CLAUDE.md's fake-progress ban: it is the
**prerequisite that makes the eventual key measure something meaningful**. With
the key but without this, the behaviour A/B would have scored the coach on a
context that never contained the behaviour.

Collision discipline: entirely inside `tools/coach-arena/` (JS harness), which the
~10 concurrent Swift-editing agents on this worktree do not touch. Staged only my
3 files by pathspec; the tree's pre-existing uncommitted `Localizable.xcstrings` +
`ten_conversations.md` + `.screenshots/` left byte-for-byte untouched.

## Review artifacts (NOT shipped as app code)

The genuinely-new axis the 21 iterations never measured is **visual presentation**.
Per the synthesis (and the `coach_lens_design_principle`): compose the
already-existing signals into ONE cohesive, screenshot-able **Rep Report** surface,
but do **not** land it as app code without Jordan's design review — "compose into
one screen" is exactly the hierarchy/rhythm decision the lead UI/UX owner should
make. So this run produced:

- `docs/SPEC_rep_report_surface.md` — composition, exact tokens/charts to reuse,
  motion, honesty invariants, and the Figma/Canva execution plan (gated on review).
- An on-brand rendered mockup (Artifact) using the real palette + type so Jordan
  has something concrete to react to.

The nice tie-in: the Rep Report's centrepiece is the **recurring-position read** —
the same insight this run just made testable in the harness. The substance lever
and the visual lever point at the same coaching moment.

## Honest scorecard (5-role consensus, 0–10)

| Dimension | Noum | Best rival | Note |
|---|---|---|---|
| Honesty / anti-overclaim | **9** | — | Evidence floors, self-suppressing cards, `.forming` cap. The real moat; unmatched in category. |
| Coaching substance | **8** | Yoodli (roleplay) | Positional/recurring read + durable case file beat rivals on read-quality; ceiling = semantic content diagnosis. |
| Design infra / motion identity | **8** | Speeko | Tokens, 3 hero gradients, Swift Charts, the `NoumCharacter` orb. Gap is propagation, not capability. |
| First-run trust / acquisition | **6** | Orai/Speeko | Guest-safe + verbatim celebration are strong; picker + 15s countdown drag the proof moment. |
| Analytics presentation | **6** | Yoodli | Market-leading insight rendered as a text list; `ProfileView` bars bypass the app's own Swift Charts. |
| Daily-habit entry point | **6** | Speeko (2-min) | Daily surface is a full rep — heavier than the sub-2-min ritual rivals open with. |
| Positioning / branded credibility | **5** | Speeko (Roger Love) | Trust moat is buried in code, never surfaced as a marketable stance. |
| Live interactive practice partner | **3** | Duolingo Max / Yoodli | IM is a scripted drill, not a counterpart that talks back. Needs a live model. |

## Genuine limitations blocking a literal 10/10

- **[by-design]** "Replaces a human coach" is capped at `CoachParityReadiness.forming`
  — the trust moat VISION.md mandates. This is CORRECT and must not be removed.
  A literal "with no doubt replaces a human coach" 10/10 stays **refused by design.**
- **[environment]** Live-reply behaviour proof (that the model *speaks* the
  recurring line) + any live conversational partner need `ANTHROPIC_API_KEY`. Unset
  here. **This run removed the harness blind spot that would have made that proof
  measure nothing.**
- **[hardware]** No breath / tension / posture / eye-contact / vocal-variety
  perception; no in-the-wild (Zoom/Meet) observation. Phone audio can't sense these.
- **[external-data]** No expert-calibrated evaluation corpus anchoring the
  thresholds; no named-authority credibility asset (Speeko's Roger Love).
- **[longitudinal]** No real-user outcome cohort proving durable improvement.

## Ranked remaining levers (for the next session)

1. **[shipped]** Harness POSITIONAL TREND parity — done this run.
2. **[Swift, keyless, collision-safe]** Deterministic content/structure diagnosis
   engine (buried-lede + claim→reason→implication shape). Largest substance gap a
   human coach leads with; new file keeps it collision-safe.
3. **[design, review-gated]** The Rep Report surface — spec + mockup delivered this
   run; needs Jordan's sign-off, then Figma execution, then Swift.
4. **[onboarding, ship-now]** A pre-rep framing bridge (one calm card → record with
   no countdown), independent of the still-dark `AutoGuidedFirstRep` flag.
5. **[Jordan-only]** Supply an `ANTHROPIC_API_KEY` for the behaviour A/B; flip +
   device-QA `AutoGuidedFirstRep`; the calibration-corpus / longitudinal-cohort
   decisions.

Connectors verified live this run: **Figma** (Jordan's team, authenticated) and
**Canva** (authenticated; no brand kit configured — a Noum brand kit would let
`generate-design` stay on-palette automatically). Canva is marketing-collateral
tooling, not the right tool for a product-surface design problem — Figma is.
