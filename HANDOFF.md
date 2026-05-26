# HANDOFF — M24 deferred slate (round 10): offer the tone-drill from every recommendation surface

## Scope

Round 9 (commit `0b55e2b`) closed the **read → act** loop for the
per-scenario tone drill on Home: when a user keeps missing the tone in
one specific conversation setup, `IMHistorySummary.toneDrillSignal(from:)`
surfaces it and `RecommendationBiasEngine.blueprint(... imToneSignal:)`
turns it into a one-tap "drill this exact scenario, in this exact tone"
recommendation. `ContentView` and `HomeCoachCard` wired it.

Round 9 named the next move explicitly and flagged it #1:

> **Offer the same drill from the other recommendation surfaces.**
> `PracticeModeSelectionView.computeRecommendation` and `SummaryView`
> also call `RecommendationBiasEngine.blueprint` but currently pass no
> signal, and `PracticeModeSelectionView.appDestination(for: .imConversation)`
> launches with `scenario: nil, tone: nil` even when the blueprint
> carries them. The natural next round is to (a) pass the signal at those
> two sites and (b) have their IM destination honour
> `blueprint.recommendedScenario` / `recommendedTone`, so the drill is
> offered consistently wherever the user lands — not only on Home.

This push closes it.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- The coach already prescribes the exact scenario + tone re-rep **on
  Home**. But a user reaches "what should I do next" from two other
  places — the mode picker (Begin · IM) and the post-session summary's
  "Looking ahead." Until now those two ignored the tone signal and the
  picker dropped the user on a cold scenario grid. Now the recommendation
  reads the same everywhere, and the picker lands the user in the
  recommended setup with one tap.

## What shipped

### Track 1 — `PracticeModeSelectionView`: pass the signal + honour the prefill

`Noum/PracticeModeSelectionView.swift`:

- **(a)** `computeRecommendation()` now passes
  `imToneSignal: IMModeAvailability.isAvailable ? IMHistorySummary.toneDrillSignal(from: sessionStore.sessions) : nil`
  — the exact shape `ContentView` and `HomeCoachCard` already use. The
  availability guard means that when IM mode is offline the engine falls
  back to its normal goal/baseline bias instead of recommending a mode
  that would just be re-routed to Timed downstream.
- **(b)** Two new `@State` fields — `cachedRecommendedScenario`
  (`IMConversationScenario?`) and `cachedRecommendedTone` (`IMTargetTone?`)
  — are set from `blueprint.recommendedScenario` / `recommendedTone`
  alongside the existing `cachedRecommendedMode`.
  `appDestination(for: .imConversation)` now returns
  `.imPractice(scenario: cachedRecommendedScenario, tone: cachedRecommendedTone)`
  instead of the hard-coded `nil, nil`. So **both** launch paths through
  that helper honour the prefill:
  - the **floating Begin CTA** (`Begin · IM`) lands the user on the IM
    setup with the scenario pre-chosen and `setupStep` advanced to `.tone`
    (`IMPracticeView.onAppear`), still changeable;
  - the **IM Quick Start** button, which arms
    `PracticeModeQuickStart`, makes `IMPracticeView` short-circuit
    straight into `beginConversation()` with the resolved scenario/tone —
    a genuine one-tap re-rep of the weakest setup.

This mirrors `HomeCoachCard.destination(for:)` exactly. The cached fields
are non-nil **only** when the blueprint recommends IM — the tone-drill
override (the exact missed scenario+tone) when the evidence bar clears, or
the goal-based bias (the scenario+tone for the user's coaching goal)
otherwise. For every non-IM recommendation, and for cold-start users with
no profile and no signal, both fields are nil → `.imPractice(nil, nil)`,
**byte-for-byte the prior behaviour.**

### Track 2 — `SummaryView`: pass the signal so the post-session read agrees

`Noum/SummaryView.swift`:

- `summaryRecommendation` now passes the same availability-guarded
  `imToneSignal`. So the post-session **"Looking ahead"** card
  (`LookingAheadCard`) reflects the tone-drill recommendation — "For your
  next session, try IM Mode" + the honest observed-hit-rate `whyNow` copy
  — consistently with Home, instead of a generic goal-based nudge.
- `LookingAheadCard` is a **read-only** card by design (no launch button
  for any mode), so there is no nil/nil destination bug to fix here. The
  actionable handoff is the summary's "Choose another mode"
  (`onSelectPracticeMode`), which routes into
  `PracticeModeSelectionView` — now drill-aware from Track 1. The loop
  therefore closes end-to-end **without** turning a passive card into a
  CTA (which would be inconsistent with the other modes' looking-ahead
  read and out of scope).
- Note: `lookingAheadHint` keeps its existing guard
  `blueprint.recommendedMode != currentMode`, so right after an IM rep it
  stays silent (don't suggest the mode you just finished) — Home still
  carries the drill in that case. Honest, not redundant.

### Track 3 — Locked contract (`IMToneDrillSignalTests`, +2 cases)

The view wiring is a direct forward of two already-tested blueprint
fields, so the meaningful new lock is on the **invariant the forward
depends on** — extended in `NoumTests/NoumTests.swift`:

- `goalBasedImRecommendationCarriesScenarioAndTone` — a `.calmerDelivery`
  / `.work` profile (no drill signal at all) makes the blueprint
  recommend IM **and** carry `recommendedScenario == .difficultConversation`
  + `recommendedTone == .warm`. This is the new dependency:
  `PracticeModeSelectionView` previously discarded these; now it forwards
  them, so they must always be present for an IM recommendation.
- `nonImRecommendationCarriesNoScenarioOrTone` — the mirror: a
  `.reduceFillers` profile recommends a non-IM mode and carries `nil` for
  both, so the IM-destination forwarding is a guaranteed no-op and a
  non-IM CTA can never smuggle a stale scenario.

(The tone-drill override path — signal → IM + scenario + tone — and the
no-signal regression guard were already locked by round 9's suite.)

### Vision alignment

- **Pillar #3 — Conversational intelligence** and **#5 — Personalized
  coaching.** The coach's read of "you keep aiming for calm and landing
  it under 40% of the time — drill exactly that" is now the same wherever
  the user asks "what next," not a Home-only feature. Consistency *is* the
  coaching: a human coach doesn't forget the plan between the debrief and
  the next session.
- **Coach-parity loop — Intervention.** This round widens the *delivery*
  of the round-9 intervention; it doesn't fabricate a new one. The honest
  bar (≥3 reps, sub-40%), the self-clearing behaviour, and the
  observed-number copy are all inherited unchanged from the engine.
- **Anti-goals respected.** Purely additive at every site (default-nil
  param, nil cached fields → prior behaviour); no new AI surface; no shame
  copy; no read-only card forced into a fake CTA.

## Files touched

- **Modified:** `Noum/PracticeModeSelectionView.swift` (+~14 LOC — two
  `@State` caches + doc comment, pass `imToneSignal`, set the caches,
  `appDestination` IM branch honours them)
- **Modified:** `Noum/SummaryView.swift` (+~3 LOC — pass `imToneSignal`,
  availability-guarded)
- **Modified:** `NoumTests/NoumTests.swift` (+~55 LOC — two new
  `IMToneDrillSignalTests` invariant cases)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — work is based on `origin/Redesign` and pushed to the
session branch with a draft PR opened **into `Redesign`** per the user's
brief.

The artifact a user can now hold:

**The "drill this exact scenario, in this exact tone" recommendation no
longer lives only on the Home coach card.** Open the mode picker and the
Begin · IM button drops you straight into the weakest setup; finish a
(non-IM) session and the "Looking ahead" read names the same drill. The
coach gives one consistent answer to "what should I do next" no matter
where you ask it — and it still disappears on its own the moment your
hit rate recovers.

## Future moves

(Updated priority list — round-9 item #1 closed this round; remaining
items carried forward and re-prioritised:)

1. **Close the Adaptation half: did the drill work?** This slate now
   *prescribes* and *delivers* the tone drill everywhere; it still does
   not *observe the response*. The deeper coach-parity move is to read
   whether the tone-match rate on a drilled scenario improved across the
   reps that followed the recommendation (reuse the existing
   `RecommendationOutcome` / `RecommendationLearningStore` evidence
   machinery), and either reinforce ("calm is landing now — hold it") or
   vary the intervention with an explained rationale. That is the
   "Adaptation" stage in `docs/VISION.md`'s coach-parity loop and the
   honest next standard the VISION names ("did that prescribed work help
   this specific user?"). **This is now the natural next round.**
2. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
3. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor pass
   with proper visual QA (and a real device).
4. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` so the Settings AI-usage card AND the
   `CoachReadCard` daily-budget hint refresh mid-view. Low priority
   (Settings is modal in practice).

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
change was written to match the existing, tested patterns line-for-line:
the `imToneSignal` argument is copied verbatim from `ContentView` /
`HomeCoachCard`; the `appDestination` IM branch mirrors
`HomeCoachCard.destination(for:)`; the two new tests reuse the
`IMToneDrillSignalTests.input()` helper and the same
`CoachingProfile` init shape the existing prompt-generator tests use.
The change is **purely additive** (a default-`nil` engine param that was
already shipped in round 9, plus two new `@State` fields that default to
nil), so every un-updated call site and the no-signal path are byte-for-
byte unchanged. Before this lands in a TestFlight build it still wants a
real `xcodebuild test` and a glance, on a test account with a sub-40%
tone-match scenario, at: (1) the mode picker's `Begin · IM` landing on
the drilled scenario with the tone pre-set, (2) IM Quick Start dropping
straight into that scenario's live thread, and (3) the post-session
"Looking ahead" card naming the same drill after a non-IM rep. Treat the
"lands the user in the recommended setup" claim as designed-for, not
observed.
