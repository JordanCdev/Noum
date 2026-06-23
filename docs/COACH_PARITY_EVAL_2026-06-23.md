# Coach-parity evaluation — 2026-06-23

Branch: `ux-overhaul` · HEAD at eval: `c9e5cd9` · Run: autonomous `noum-1`
Method: role-diverse multi-agent workflow — **6 role agents** (market researcher,
UX designer, first-time end user, Swift engineer, coaching-honesty auditor, QA
engineer) → adversarial gap verification (each high/blocker gap re-checked against
current source) → strategist synthesis. **Read-only** (no build) by design, so the
panel did not contend with the concurrent session's active builds.

Predecessor: `docs/COACH_PARITY_EVAL_2026-06-22.md` (7.2/10 @ `ddff056`).

## Panel integrity (read first)

Unlike 06-22 (4 of 6 role agents stalled under build contention), this run was a
**clean 6-of-6 return** — achieved by holding the panel strictly read-only so it
added no `xcodebuild` load. Role scores: market 7.5 · UX 7.0 · end-user 6.5 ·
Swift-eng 7.5 · honesty 8.0 · QA 7.4. Every counted gap was adversarially
re-verified against a specific `file:line` in the current tree (including the
uncommitted in-flight diff).

## Concurrency note

A concurrent session holds a **large uncommitted diff** in the working tree
(3,849 insertions / 14 files; `TimedPracticeView.swift` alone +962/-523). It
implements three 2026-06-22 slices (below). This eval **reads** that diff to score
where the product is heading, but ships **no code** — the diff occupies most coach
files, so every high-value fix either collides or is felt/QA-gated. `safeSlices`
this run = **none** (honest, concurrency-forced — same conclusion as the prior
six continuations under hot contention).

## Honest score: 7.4 / 10  (+0.2 vs 7.2, once the in-flight diff lands)

The lift is **real but concentrated on retention / substance / trust** — *not* the
dimension the prior eval named the #1 lever. The acquisition / first-rep moment,
the single biggest drag, **did not move** (its routing files aren't even in the
diff). Depth went up; the moment that *sells* the depth is unchanged.

## Scorecard (achievable axis)

| Dimension | Score | Basis (code-grounded) |
|-----------|-------|-----------------------|
| Trust & honesty | **8.5** | Best-in-class wedge. Baseline radar is evidence-coverage-first: per-dimension `currentScore` is nil while `confidence == .insufficient` (`BaselineEngine.swift:183-185`); goal-gap gated on `measuredDistanceFromGoal` (`BaselineEngine.swift:646,255-266`); "0/10 forming" shown cold. Signup motivation is anchor-not-guilt, exact wording + "do not invent an emotion they did not state" (`CoachContextBuilder.swift:182-190,5915-5944`), test-locked. Moat intact: `.forming` cap + proof quote-gating untouched. |
| Adaptive-plan / transfer intelligence | **7.5** | Category-of-one no rival ships: `ForwardPlanService` re-plans Week-4 only on did-not-transfer plurality past an honesty floor (`ForwardPlanService.swift:139,216-234`; floor `minimumReports:3` at `BigMomentStore.swift:489,503,512`); durable `CoachCaseFile` spine (`PrimaryFocusMemory.swift:1011-1127`). Capped because the loop is **dormant for non-reporters** and invisible at conversion (`ProfileView.swift:1093` omits the row; `CoachContextBuilder.swift:590` gives zero context at n=0). |
| Personalized coaching / onboarding | **7.0** | Onboarding short/respectful (3 tap-only Qs, deferred free-text); blocking pre-rep focus sheet **removed** (`SessionIntentEngine.swift:135` hard-false; sheets stripped from both practice views). But the 3 answers get **no visible payoff** at the first decision point — picker `recommendedReason` is static/speaker-agnostic (`PracticeModeSelectionView.swift:204,212,220`); `cachedRecommendedReason` fills only from session history a new user lacks. |
| Market position vs leaders | **7.5** | Out-positions Speeko/Orai/Yoodli/Duolingo on what serious users keep paying for: durable inspectable case file + closed transfer loop none ship, plus honesty engineering vs Yoodli's confident-AI tone. Held back by audio-only prosody ceiling (`BaselineEngine.swift:996-1007`) and the moat being invisible at trial. |
| Live-conversation feel | **6.5** | Push-to-talk by design (echo-loop avoidance) — honest, correct, but a felt delta vs Yoodli/Duolingo continuous-listen; stale auto-rearm comment now fixed (`LiveCoachCallView.swift:74-75,202`). Loses the "magic" side-by-side demo. Warmth model-dependent. |
| Acquisition / first-rep moment | **5.5** | **The single largest drag, unchanged.** First-run → `noum://train` (`CoachingOnboardingView.swift:569`) → `ContentView.swift:1383` `.practiceSelection` (picker, not a rep). See "New finding" below. `SPEC_first_rep_auto_guided.md` is spec-only. The redesign polished friction *after* the picker; the acquisition moment *through* it is untouched. |
| **Overall** | **7.4** | Substance + trust (8.5 / 7.5 / 7.5) are A-grade and category-leading; held to 7.4 by the unmoved acquisition (5.5) and live-feel ceiling (6.5). |

## In-flight slices — verified COMPLETE, not half-done

The concurrent session's uncommitted work is real end-to-end wiring with new
tests, no stubs:

1. **Organic focus check-in** *(most complete; strongest first-run win)*.
   `shouldPresent` hard-returns false (`SessionIntentEngine.swift:135`); the
   blocking "Today's focus?" sheet + state removed from `TimedPracticeView` and
   `SuddenDeathPracticeView`; check-in re-homed as a **due-only, non-blocking**
   coach-context block with a "do not interrupt a rep" guard; branch-tested.
2. **Baseline map + signup motivation** *(substantive, honesty-tested)*. Profile
   evidence radar (filler/pace/structure/clarity/composure/vocal-range),
   evidence-coverage-first, goal-gap gated, signup motivation as anchor. Strong —
   but a Profile/coach-trust surface = **week-2 value, invisible in the first 60s**.
3. **Impromptu redesign** *(most consequential for positioning; cleanly executed)*.
   Default-first card, gear-hidden settings, locked Pro rows → paywall, premium
   gating migrated to one `enforcePremiumFeatureAvailability` chokepoint, every
   removed symbol confirmed zero dangling refs. **But it stops at the post-picker
   setup surface — it does not touch cold first-run routing, and introduces a
   regression (below).**

Net once landed: **+~0.2 overall**, moving retention/substance/trust — **not** the
acquisition gap the prior eval prioritized.

## ⚠️ New finding this run — double-Begin regression in the Impromptu redesign

The redesigned hero CTA **navigates without arming `PracticeModeQuickStart`**, so
the prescribed first-rep path now requires *two* Begin taps plus a countdown:

```
picker hero CTA (PracticeModeSelectionView.swift:367)  → appends destination, does NOT .arm
  (only the buried "Start now" at :743 arms; picker .task at :310-319 CLEARS the flag)
→ TimedPracticeView.swift:862 quick-start consume FAILS
→ user must tap "Start Impromptu" again (TimedPracticeView.swift:2290)
→ 15s thinking countdown (enableThinkingTime default true, :688/:2447) before first word
```

Concept fix is small — have the hero CTA call `PracticeModeQuickStart.arm` before
navigating, mirroring `:743` — but it is **felt/QA-gated** and **collides** with the
hot in-flight `TimedPracticeView` rewrite, so it is flagged for whoever lands the
diff rather than blind-patched this run.

## Verified remaining gaps (prioritized, code-confirmed)

1. **Cold first-run routes the first spoken word to a picker, not a rep** — now
   compounded by the double-Begin above. *(real · highest value-toward-goal ·
   FELT-QA GATED · collides with in-flight diff)* Evidence chain above.
   The single biggest lever from 7.4 → ~8.5. Spec: `docs/SPEC_first_rep_auto_guided.md`.
2. **Flagship transfer-loop moat is invisible at the conversion moment.** *(real ·
   FELT-QA GATED)* Non-reporting trialists see the transfer card vanish and get
   zero transfer context in coach chat; the pattern structurally needs **3 distinct
   same-category** reported real-world events. The depth that out-positions rivals
   is hidden exactly when the user decides to pay. **Do NOT lower the n=3 honesty
   floor** (`BigMomentStore.swift:489,503,512`) — add a restrained pre-loop
   teaser/empty state (`ProfileView.swift:1093`, `CoachContextBuilder.swift:590`).
3. **Onboarding answers get no visible payoff at the first decision point.** *(real ·
   low-medium · NOT felt-gated)* Picker recommendation is static and
   speaker-agnostic (`PracticeModeSelectionView.swift:204,212,220`); thread the 3
   onboarding answers into the recommended-reason copy so the questions read as a
   conversation, not a form. The most plausibly-blind-buildable lever — but its
   file is in the in-flight diff, so it must wait for the merge.
4. **Live-conversation feel is push-to-talk by design.** *(known trade, not a fix)*
5. **Dead-code / debt to clear before merge.** *(low · NOT felt-gated)* Orphaned
   `SessionIntentPromptView` (zero external refs); now-tautological always-false
   `SessionIntentPromptPolicy` + its tests; and a **git-TRACKED 2,068-line build
   log** `.derived-data-log-0CA5RPJ1` (confirmed tracked via `git ls-files`). The
   build log is actively being written by concurrent builds, so untracking it
   (`git rm --cached` + `.gitignore`) is left to the diff-landing session to avoid
   index contention — but it should not ship in a feature commit.

## Genuine limitations (named precisely)

1. **`CoachParityReadiness` capped at `.forming`; a literal "replaces a human
   coach" claim is REFUSED — correctly.** The trust moat, an intentional VISION
   property. Do not remove the cap to chase a literal 10/10. (Unchanged.)
2. **Audio-only prosody ceiling.** Vocal-range inferred from pitch monotone only
   (`BaselineEngine.swift:996-1007`); no body-language/eye-contact channel. A
   comparison shopper notices the coverage gap vs Yoodli video — VISION correctly
   defers visual presence to a later opt-in milestone. Structural.
3. **Transfer loop gated on real-user reporting** (n=3 floor) — correct by
   anti-overclaim design, but the moat cannot demonstrate itself at trial and is
   structurally weeks-to-months from firing for a new user.
4. **Continuous-listening feel ceded by design** (echo-loop avoidance) until
   root-cause AEC lands.
5. **Felt coaching warmth is model-dependent** — the new signup-memory + check-in
   context are excellent scaffolding, but payoff rides on the live model and is
   only verifiable by running the live pipeline on-device, which a read-only run
   cannot confirm.

## Bottom line on the 10/10 / A* goal

- **Refused axis — literal human-coach replacement: correctly out of scope.** The
  `.forming` cap is a feature, not a defect; do not score against it.
- **Achievable axis — rival/beat the leaders on substance + trust AND an A* demo
  moment: NOT yet A*, at a strong 7.4.** The substance + trust halves are already
  category-leading and arguably best-in-class (durable case file + closed transfer
  loop = a genuine category-of-one; honesty engineering = the defensible wedge).
  The gap to A* is **almost entirely the acquisition / first-rep moment (5.5)**: a
  brand-new user still taps through a picker + a redundant second Begin + a 15s
  countdown before speaking, and the flagship moat is invisible at conversion.

**Verdict: 7.4/10 today (once the in-flight diff lands), credible path to ~8.5 by
closing only the first-rep moment — which is felt/QA-gated and currently collides
with the hot in-flight `TimedPracticeView` rewrite, so it is correctly sequenced
*after* the diff lands, not skipped.** The score is held back by what's *visible at
acquisition*, not by what the system can *do*.

## Recommended sequence to A* (for the diff-landing / device-owning session)

1. **Land the in-flight diff** (the three slices are complete + tested).
2. **Fix the double-Begin**: arm `PracticeModeQuickStart` from the hero CTA
   (mirror `PracticeModeSelectionView.swift:743`); on-device QA the one-tap path.
3. **Build the auto-guided first rep** (`SPEC_first_rep_auto_guided.md`) so the
   first spoken word follows onboarding without a picker detour.
4. **Add a transfer-loop teaser** at the conversion moment (no floor change).
5. **Thread onboarding answers into the picker recommended-reason copy** (gap #3).
6. **Clear the dead code**: delete orphaned `SessionIntentPromptView` +
   always-false `SessionIntentPromptPolicy`/tests; untrack `.derived-data-log-*`.

## Verification evidence (this run)

- 6-of-6 role agents returned (read-only, code-grounded); 7 high/blocker gaps
  adversarially re-verified against current source incl. the uncommitted diff.
- **No build run this run** (deliberate): HEAD `c9e5cd9` sits on the
  already-verified `ddff056` (39 passed / 0 failed per 06-22 eval) with only an
  `EVAL+SPEC` doc commit + a comment-only `DOC-FIX` on top — no behavior change,
  green status unchanged. A third concurrent `xcodebuild` was avoided to prevent
  the coordinator-error-12 contention seen under load.
- No code shipped (concurrency-forced); deliverable is this eval + handover update.
