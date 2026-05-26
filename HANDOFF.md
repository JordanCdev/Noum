# HANDOFF — M24 deferred slate (round 11): the Adaptation half — "did the drill work?"

## Scope

Rounds 9 and 10 built the *act* side of one coaching move: when a user
reliably misses the IM tone they committed to in a scenario, the coach
prescribes a one-tap re-rep of that exact scenario + tone — first on
Home (round 9), then everywhere the user lands: the practice picker and
the post-rep summary (round 10). Round 10 flagged the next move
explicitly and ranked it #3, naming it the deepest remaining gap:

> **Close the Adaptation half: did the drill work?** This round (and
> round 9) *prescribes* the drill across every surface; neither yet
> *observes the response*. The deeper coach-parity move is to read
> whether the tone-match rate on a drilled scenario improved across the
> reps that followed the recommendation, and either reinforce ("calm is
> landing now — hold it") or vary the intervention with an explained
> rationale. That is the "Adaptation" stage in `docs/VISION.md`'s
> coach-parity loop.

This push closes it. `docs/VISION.md` names the loop
`diagnose → formulate → prescribe → observe → adapt → transfer` and
lists **Adaptation** as a parity gap: "compare response across multiple
attempts and either reinforce, vary, or replace the intervention with an
explained rationale." Until this round Noum could prescribe but not
observe its own prescription. Now it can.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

## What shipped

### Track 1 — The Adaptation analyzer (`IMHistorySummary`)

`Noum/IMHistorySummary.swift`:

- **`toneDrillAdaptation(from:scenario:)`** — a pure read of whether the
  committed tone is *landing more, the same, or less* across the reps
  that followed the prescription. Method mirrors the existing
  `relationalTrend`: split the scenario's evaluated tone-match trace
  (oldest→newest) into a non-overlapping early window and recent window
  of `min(3, count / 2)` reps each, compare the fraction that landed the
  tone. The key honesty insight that means **no new timestamp store is
  needed**: because the drill is surfaced *continuously* on every
  recommendation surface while the signal is live, the recent evaluated
  reps in that scenario genuinely *are* the reps that came after seeing
  the recommendation. So an early-vs-recent split on the scenario's own
  trace answers "is the prescribed work helping?" directly.
- Reuses the exact `.imConversation` + scenario + non-blank-`actualTone`
  filter and the `matches(targetTone:actualTone:)` rule that
  `toneMatchStats` and `dominantEvaluatedTone` already use, via a small
  private `orderedToneMatches(from:scenario:)` helper (oldest→newest
  booleans). No new matching logic to keep in sync.
- Two thresholds as `static let`s so the suite asserts the boundary:
  `toneDrillAdaptationMinReps = 5` (above the 3-rep *firing* bar, so the
  coach only claims a before/after once the user has actually re-repped
  a couple of times) and `toneDrillAdaptationDelta = 0.25` (≈ one rep
  flipping in a 2–3-rep window; below it the read is `.holding`).
- `toneDrillSignal(from:)` now attaches the read for the **winning**
  scenario only (the candidate it already selected worst-first), so the
  cost is one extra pass over the chosen scenario's reps, not all four.

### Track 2 — The signal carries the read; the copy adapts (`PracticeSupport`)

`Noum/PracticeSupport.swift`:

- New **non-gated** `enum ToneDrillAdaptation` next to `IMToneDrillSignal`
  (the signal is non-gated; `IMHistorySummary` is iOS-17-gated, and only
  the *producer* lives there, so the enum must sit with the struct).
  Cases: `.firstPass`, `.reinforcing(recentRate:earlierRate:)`,
  `.holding(recentRate:earlierRate:)`, `.notLanding(recentRate:earlierRate:)`.
- `IMToneDrillSignal` gains an `adaptation` field with an explicit
  memberwise init that **defaults it to `.firstPass`** — so every
  existing construction site (the engine's candidate builder and the
  `blueprintFromToneSignalPrescribesScenarioDrill` test) compiles
  unchanged.
- `RecommendationBiasEngine.toneDrillBlueprint(signal:)` switches on the
  read. Same prescription (same scenario + tone prefill), adapted
  *rationale*:
  - **`.firstPass`** — original copy, byte-for-byte ("…landed only 25%
    of the time. Re-run the same scenario and hold the tone end to end.").
  - **`.reinforcing`** — leads with the gain: "Your calm tone is landing
    more in Difficult Conversation — 67% across your latest reps, up from
    0% earlier. Run it once more and lock it in."
  - **`.holding`** — varies the entry, same target: "…holding around
    33% — not slipping, not landing yet. This rep, set the tone in your
    very first line and protect it from there."
  - **`.notLanding`** — re-diagnoses before repeating: "…slipping… Before
    another rep, commit to calm out loud in one sentence, then open with
    that exact energy."
- Tone framework respected: every branch leads positive or neutral, uses
  real numbers, says "landing more / slipping" (never "the drill caused
  this" — it's association, not proof), no shame copy.

### Track 3 — Tests (`IMToneDrillAdaptationTests`)

`NoumTests/NoumTests.swift` — new suite next to `IMToneDrillSignalTests`,
reusing the same `imSession` / `input` fixtures:

- `thresholdConstantsAreStable` — locks `minReps == 5`, `delta == 0.25`.
- `adaptationIsFirstPassBelowRepBar` — 4 firing reps → still `.firstPass`.
- `adaptationReadsReinforcingWhenRecentRepsLandMore` — oldest-3 miss,
  recent-2-of-3 land; overall 0.33 still fires; asserts the
  `.reinforcing(0.667, 0)` read **and** the adapted copy ("landing more",
  "67%", "up from 0%", "lock it in").
- `adaptationReadsNotLandingWhenRecentRepsSlip` — early window 2/3, recent
  0/3, overall 0.38 fires; asserts `.notLanding(0, 0.667)` and the copy
  ("slipping", "down from 67%", "change the entry").
- `adaptationReadsHoldingWhenFlat` — one match per window, delta 0;
  asserts `.holding` and the "holding around 33%" / "fresh angle" copy.
- `windowsNeverOverlapAtMinReps` — at exactly 5 reps (window 2 each, one
  middle rep excluded) a strong-recent / weak-early split reads from
  disjoint windows; overall 0.60 does **not** fire, so the analyzer is
  exercised directly.
- `adaptationIgnoresOtherScenariosAndMissingTone` — a cross-scenario rep
  and a blank-`actualTone` rep in the freshest slot must not change the
  read.

### Vision alignment

- **Coach-parity Adaptation stage** (`docs/VISION.md`): "compare response
  across multiple attempts and either reinforce, vary, or replace the
  intervention with an explained rationale." That is now exactly what the
  three non-firstPass branches do — and each gives the *rationale*
  (reinforce because it's landing; vary the entry because it's flat;
  re-diagnose because it's slipping), not a bare verdict.
- **Pillar #5 Personalized coaching** and **Believable progress**: the
  recommendation stops repeating the identical nudge and starts tracking
  the user's actual trajectory in the exact setup they're working on.
- **Anti-goals respected.** No new disconnected AI surface (everything
  routes through the existing deterministic engine + signal), no
  fabricated data (the same ≥3-rep firing bar gates the drill; the
  ≥5-rep adaptation bar gates any before/after claim), association is
  never described as causation, and the copy never shame-frames a miss.

## Files touched

- **Modified:** `Noum/IMHistorySummary.swift` (+~75 LOC — adaptation
  analyzer, `orderedToneMatches` helper, two threshold constants;
  `toneDrillSignal` now attaches the read to the winner)
- **Modified:** `Noum/PracticeSupport.swift` (+~50 LOC — `ToneDrillAdaptation`
  enum, `adaptation` field + defaulted init on `IMToneDrillSignal`,
  `toneDrillBlueprint` switch on the read)
- **Modified:** `NoumTests/NoumTests.swift` (+~190 LOC — new
  `IMToneDrillAdaptationTests` suite, 8 tests)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief (via the
`claude/clever-hypatia-UfBCw` working branch + a PR into `Redesign`).

The artifact a user can now hold:

**The coach now watches whether its own prescription is working.** Keep
missing your calm tone in Difficult Conversation and the drill fires.
Re-rep it and start landing it, and the same card switches from "land it
end to end" to "your calm tone is landing more — 67%, up from 0% — run it
once more and lock it in." Stall, and it changes the angle instead of
repeating itself. Slip, and it tells you to commit to the tone out loud
before you open. Diagnose → prescribe → **observe → adapt** is closed for
the IM tone loop.

## Future moves

(Re-prioritised; round-10 item #3 closed this round.)

1. **Make the `LookingAheadCard` itself launch the drill.** Today the
   summary card *describes* the prescribed IM drill but isn't tappable.
   Thread `scenario`/`tone` + an `onStart` closure through `SummaryView`'s
   init and render a modest subordinate CTA only when the card carries a
   concrete IM drill. Deferred for the same reason every round defers
   new interactive recommendation UI: it wants real-device QA this build
   host lacks. Logic-only wiring ships first.
2. **Surface the adaptation read in Ask Noum + post-rep coach copy.**
   This round teaches the *recommendation engine* to reinforce/vary, but
   `CoachContextBuilder` / `AskNoumStore` and the post-rep coach note
   don't yet read `signal.adaptation`. Feeding the same
   reinforce/hold/notLanding read into the conversational coach voice
   would make Ask Noum say "your calm tone is starting to land in those
   hard conversations" without the user opening the picker. Pure context
   wiring, high vision value, no new UI.
3. **Preserve the just-finished IM scenario/tone on "Practice Again".**
   `SummaryView.onPracticeAgain` re-runs an IM rep with
   `.imPractice(scenario: nil, tone: nil)`, dropping the user on the
   scenario grid even though `imConversationDetails.setup` carries the
   exact scenario + tone they just did. Small, high-confidence, uses the
   existing prefill plumbing.
4. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
5. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Wants a dedicated refactor pass
   with proper visual QA (and a real device).
6. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` so the Settings AI-usage card AND the
   `CoachReadCard` daily-budget hint refresh mid-view. Low priority.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
changes were written to match the existing, tested patterns
line-for-line: `toneDrillAdaptation` reuses the `relationalTrend` window
method and the `toneMatchStats` filter/`matches` rule verbatim; the new
suite reuses `IMToneDrillSignalTests`' `imSession` / `input` fixtures
and the `signal?.field == .case` assertion shape the existing tests use;
the `ToneDrillAdaptation` enum is plain value-type and non-gated so the
non-gated `IMToneDrillSignal` compiles. The defaulted `adaptation` init
param means no existing call site changes. Before this lands in a
TestFlight build it still wants a real `xcodebuild test`, plus a glance
at the Home / picker / summary recommendation copy for a test account
that (a) keeps missing a scenario's tone (firstPass), (b) starts landing
it (reinforcing), and (c) keeps stalling (holding/notLanding), to confirm
the rationale reads naturally on-device. Treat the behaviour as
designed-for, not observed.
