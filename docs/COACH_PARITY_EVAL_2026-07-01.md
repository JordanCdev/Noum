# Coach-Parity Eval — Iteration 19 (2026-07-01, autonomous `noum-1` run)

**Shipped TWO verified levers, GREEN on iPhone 17 / iOS 26 (isolated
DerivedData), no push.** Branch `ux-overhaul`.

- `26906c49` — **positional read → trend memory** (`RepEventTrendEngine`)
- `57b93a2b` — **render that trend to the user** (`RepEventTrendCard`), the
  panel's unanimous top gap, shipped in the SAME run in response to it.

**Mean panel score: 7.5 / 10** (7.7 market · 7.6 UX · 7.5 end-user · 7.6 coach ·
7.0 staff/QA). Method: 5-role workflow panel (market · UX · end-user ·
veteran-coach · staff-eng/QA-honesty) reading the working tree directly →
adversarial verify-against-code → synthesis.

---

## 1. Lever A — positional read → trend memory (`26906c49`)

The per-rep positional read ("you rushed at the close") reached the coach for the
**most-recent rep only** (`CoachContextBuilder` POSITIONAL READ). This adds the
longitudinal companion: `RepEventTrendEngine.compute(sessions:)` aggregates the
already-persisted per-rep `repEventLocations` across the recent window into a
**recurring-position read** — "you've rushed the close in 4 of your last 5 reps"
— so the coach can name a *habit*, not just one slip.

Mirrors `DerivedReadsTrendEngine`'s contracts exactly:

- **Pure function, no new persistence.** Reads the Codable field
  `PracticeSession.repEventLocations` (written at finalize,
  `SpeechRecognizerViewModel:690`). Wired into a new POSITIONAL TREND section in
  `CoachContextBuilder` (its only consumer), self-suppressing on `[]`.
- **Honest by construction.** A position is named only when, among the recent
  reps that *carried* that event, `minRepsWithSignal` (3) had it AND one zone
  holds a super-majority (`dominanceFloor` 0.6) with an absolute floor of
  `minDominantReps` (3). The smallest nameable pattern is 3-of-3. The denominator
  is **reps-that-carried-the-event**, not all reps, so a clean rep is never
  counted as evidence of a pattern.
- **Rep-set hypothesis, never a trait.** "A recurring position, not a fixed
  trait." No new pace/pause thresholds; reuses `RepEventLocations.Zone`.
- **+11 tests** (`RepEventTrendEngineTests`) locking every floor boundary
  (below-sample / below-dominance / below-absolute-count all suppressed; 4/1
  passes; clean-rep exclusion; deterministic earlier-zone tie-break; windowing;
  empty→omit).

### Panel verification (unanimous: real, not stub)

All 5 roles independently traced the full chain — persisted data → pure engine →
coach prompt — and confirmed zero new persistence, floors that are code-and-tested
(not comments), and non-tautological tests. Two honest dings, neither
load-bearing, both fixed/acknowledged:

1. The first commit message claimed "+13 tests"; the suite ships **11** `@Test`
   cases. **Corrected** by amending the commit to "+11" before shipping Lever B.
2. The lever was verified as a context **wire**, not a coach **behavior** — no
   eval proves the model *speaks* the line in a now-dense prompt. Logged as a
   next lever (see §4).

## 2. Lever B — render the recurring-position trend (`57b93a2b`)

The panel's **unanimous #1 gap**: the trend was computed but **invisible**. This
is precisely the competitive deficit vs Speeko/Orai/Yoodli — they ship a
*visible* annotated-analytics surface you can screenshot; Noum's stronger
recurring-habit read was latent in the coach prompt.

`RepEventTrendCard` is a self-suppressing `SummaryView` card rendered directly
beside the per-rep `RepTimelineCard`:

- **Honest by construction.** Renders only the trends the engine already earned;
  the subline names the **earned denominator** ("in 4 of your last 5 reps with a
  rushed stretch") so a low base rate can never read as universal — closing the
  one overclaim surface Lever A opened (panel lever #2). Rep-set hedge footer,
  never a trait.
- **Consistent + calm.** Reuses `RepTimelineCard`'s exact symbol/color tokens
  (pace = caution amber, silence = brandBlue, fillers = muted secondary) — zero
  new tokens. Motion-free → reduced-motion safe by construction. One-sentence
  VoiceOver label collapsing the whole card.
- **Render-only.** Pure `RepEventTrendCopy` helper composed solely from the
  trend's typed fields, so the card cannot assert beyond the engine. **+8 copy
  tests** locking the earned-denominator / pattern-not-trait / hedge / token
  contracts.

Both levers: full app + test target **`** TEST SUCCEEDED **`** on iPhone 17 /
iOS 26, isolated `DerivedData/Noum-eval-verify`. Committed with explicit
pathspecs (a concurrent Coach Arena session had just touched
`CoachContextBuilder`; its work preserved byte-for-byte).

---

## 3. Competitive verdict (Speeko · Orai · Yoodli · Duolingo)

Noum is investing in the exact layer the competitors don't reach. Speeko, Orai,
and Yoodli score whole-take averages (fillers/min, pace, "energy"); Yoodli adds a
raw event-timeline ribbon; Duolingo gamifies streaks. **None synthesize a guarded
cross-rep positional claim** — "the same failure keeps landing in your close
across your recent reps" — the recurring-habit read a human coach leads with.
Noum now ships that read honestly AND renders it. The honesty discipline
(earned denominator, 3-of-3 floor, hypothesis-not-trait) is itself the moat: the
opposite of competitors' un-earned "confidence scores." With Lever B the strongest
differentiator is no longer latent — it is glanceable and screenshot-able.

## 4. Ranked next levers (collision-safe, non-human-gated)

1. **Prove coach BEHAVIOR, not just the wire** — add a `coach-arena` assertion
   that the recurring-position line actually surfaces in a reply, in a now-dense
   prompt where a new line can be diluted. Touches `tools/coach-arena`. *(This is
   now the top gap since Lever B closed the visibility one.)*
2. **Thread raw base-rate into the readout** — pass total windowed reps so the
   copy/coach can weight prevalence ("…of 12 reps total"). `Noum/RepEventTrend.swift`.
3. **Empty-state / first-rep honesty pass on `SummaryView`** — verify the
   disclosure collapses gracefully when no speech-quality card qualifies.

All three avoid `AICoachChatService` / `CoachReliabilityGate` / `CoachReasoningPass`.

## 5. The 10/10 answer — unchanged, and unchanged by design

The literal **"10/10, with no doubt replaces a human coach" stays REFUSED BY
DESIGN** via the `.forming` trust-moat cap. That refusal is correct and is the
product's moat — do not chase it. Three limitations are human-gated and NOT
closable in code:

| Gap | Class | What would actually close it |
|---|---|---|
| Phone reads words, not breath/tension/body | **[hardware]** | On-device camera+mic perception layer the text pipeline structurally cannot add. |
| Scoring is proxy heuristic, un-calibrated | **[external-calibration]** | A coach-labeled corpus to validate the thirds + pause/burst/filler edges (this lever's `window=6` / 3-of-3 floor are honest guesses, not calibrated truths). |
| No longitudinal real-user outcome proof | **[longitudinal]** | A cohort study: did users who followed the advice measurably improve a real interview/pitch. Outside code entirely. |
| Insight computed but invisible | **[closable-in-software]** | **Closed this run — Lever B.** |

Because the top three are gated, the ceiling on honest code work sits below 10 by
construction. This run closed the one purely-software gap the ledger carried.
