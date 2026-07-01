# Coach-Parity Eval — Iteration 20 (2026-07-01, autonomous `noum2` run)

**Shipped ONE verified honesty lever, GREEN on iPhone 17 / iOS 26 (isolated
`DerivedData/Noum-iter20`), no push.** Branch `ux-overhaul`. Commit `aa6abce7`.

- `aa6abce7` — **weight the recurring-position trend by its BASE RATE**
  (`RepEventTrend.windowRepCount`). The panel's ranked **#2** next lever from
  iteration 19; ranked **#1** ("prove the recurring line *surfaces* in a live
  coach reply") is **BLOCKED in this environment — no `ANTHROPIC_API_KEY`** —
  so I took the top *software-closable-here* lever instead. See §4.

**Surface-panel mean: 8.2 / 10** (market 8 · UX 7 · end-user 8 · veteran-coach 9
· staff-eng/QA 9). This is the panel's score for the *recurring-pattern surface
after this change*, not a new global coach-parity number — the global number is
unchanged this run pending the blocked behavior-proof lever (§4). Method: same
5-role workflow panel (market · UX · end-user · veteran-coach · staff-eng/QA)
reading the working tree directly → adversarial verify-against-code → skeptical
synthesis.

---

## 1. The lever — base-rate prevalence on the recurring-position trend

Before this change, the trend (shipped iteration 19) named only the reps that
**carried** the event: *"In 4 of your last 5 reps with a rushed stretch."* A
reader — especially at the 3-of-3 floor — could infer the rushed stretch happens
on **every** rep. That is precisely the small-sample overclaim CLAUDE.md bans.

The fix threads a base rate through the pure engine and every surface:

- **Engine (`RepEventTrend.swift`).** New `windowRepCount = locations.count` —
  the reps in the recent window (≤6) that were positionally *readable*. Invariant
  `repsWithSignal <= windowRepCount` holds by construction (`zones` is a
  `compactMap` subset of `locations`). Zero new persistence — still a pure
  function over the already-persisted per-rep `repEventLocations`.
- **Honest by construction.** The base-rate clause is appended **only when the
  event did NOT carry every readable rep** (`repsWithSignal < windowRepCount`).
  When it carried all of them the base rate is 100% and the tail is **suppressed**
  — no redundant, inflating "N of N".
- **All three surfaces carry it identically:**
  - Coach readout: *"…It showed up in 5 of your last 6 reps overall."*
  - Visual card subline: *"…— 5 of 6 reps overall."* (tail drops the repeated
    "your last" to keep one 11 pt line scannable; `.fixedSize` added for Dynamic
    Type).
  - **VoiceOver readout: same base-rate clarifier** — closing the honesty
    asymmetry the panel caught (see §2): a screen-reader user no longer hears the
    un-hedged, more-pervasive-sounding line the sighted user stopped seeing.
- **+3 tests** locking the sparse tail string, the 100%-suppression, the engine's
  3-of-6 `windowRepCount`, and the a11y base-rate parity. Full `RepEventTrend`
  engine + copy suites `** TEST SUCCEEDED **`.

## 2. Panel verification (unanimous: real wire, not stub)

All 5 roles independently traced persisted data → pure engine → **both** the
coach prompt (`CoachContextBuilder` ~L1371 `lines.append("- \(trend.readout)")`)
and the card copy, and confirmed the base rate actually flows (not a comment),
the invariant holds, no persisted-Codable decode break, and the tests are
non-tautological (they assert exact strings).

Decision: **ship-with-notes**, no blocking fixes. Three flagged follow-ups were
folded into the **same commit** rather than deferred — the strongest, the
**VoiceOver honesty-parity gap**, was load-bearing to the lever's own thesis
(an anti-overclaim change that left blind users with the overclaiming line):

1. **a11y base-rate parity** — DONE (`accessibilityReadout` now carries the tail).
2. **`.fixedSize` on the subline** for Dynamic Type wrap safety — DONE.
3. **Copy tighten** — DONE (dropped repeated "your last"; warmed the clinical
   "That event surfaced" → "It showed up").

## 3. Competitive verdict (Speeko · Orai · Yoodli · Duolingo)

Category convention is whole-take averages (Speeko/Orai) and per-session event
ribbons / trend charts (Yoodli); Duolingo gates on streaks. **None weight a
cross-rep positional claim by prevalence, and none would *suppress* a 100% base
rate** — gamified products print "3 of 3 — 100%!" because it inflates. Suppressing
the redundant tail, and naming the base rate when it's < 100%, is the
"never overclaim from small samples" discipline that is Noum's stated moat. The
market caveat (recorded honestly): this is a **trust/retention** wedge, not an
**acquisition** line — it wins a careful read, not a 5-second store screenshot —
and it should not enter marketing copy until the behavior-proof lever (§4) lands.

## 4. Ranked next levers + the honest ceiling

1. **Prove coach BEHAVIOR, not just the wire** *(blocked here)* — a `coach-arena`
   assertion that the recurring-position + base-rate line actually surfaces in a
   reply under a now-dense prompt. **Requires a live model; no `ANTHROPIC_API_KEY`
   is present in this autonomous environment**, so it cannot be run or verified
   here. This is the single highest-value remaining software gap and is
   environment-gated, not design-gated.
2. **Widen / calibrate the base-rate window.** `window = 6` and the 3-of-3 floor
   are honest guesses, not calibrated truths; a power user with dozens of reps
   may read "last 6" as thin. Needs a coach-labeled corpus (external calibration),
   not a code change.
3. **Empty-state / first-rep honesty pass on `SummaryView`** — verify the
   disclosure collapses gracefully when no speech-quality card qualifies.

### The 10/10 answer — unchanged, and unchanged by design

The literal **"10/10, with no doubt replaces a human coach" stays REFUSED BY
DESIGN** via the `.forming` trust-moat cap — correct, and the product's moat.
This iteration's surface is a genuine, structurally-sound honesty upgrade; the
distance from *its* 8.2 to 10 is **external, not a defect in iteration 20**:

| Gap | Class | Why it's not closable in this run |
|---|---|---|
| Behavior-proof of the line in a live reply | **[environment]** | No Anthropic API key here; needs a live model run. |
| ≤6-rep base rate trusted as stable | **[external-calibration]** | Needs a coach-labeled corpus to validate window/floors. |
| Phone reads words, not breath/tension/body | **[hardware]** | On-device camera+mic perception the text pipeline can't add. |
| No longitudinal real-user outcome proof | **[longitudinal]** | A cohort study — outside code entirely. |

The ceiling on honest code work sits below 10 by construction. This run closed
the one purely-software honesty gap the ledger carried that was closable *without
an API key*: a narrow positional pattern can no longer read as pervasive, on any
surface — screen included, VoiceOver included.
