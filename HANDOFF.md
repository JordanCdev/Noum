# HANDOFF — M24 deferred slate (round 9): per-scenario tone-drill recommendation

## Scope

Round 8 (commit `93aae7d` and the slate before it) finished surfacing
the **read** side of the IM conversational loop: each scenario's
relational arc (trust ↑ / tension ↓) and tone-match accuracy now read at
a glance on the IM **History list row** (`IMHistoryBreakdownCard`) and in
depth on `IMScenarioDetailView`. Round 8 named the next move explicitly
in its "Future moves" list and flagged it #1:

> **Per-scenario drill recommendations.** When the tone-match rate on a
> scenario is low (<40%) AND the user has 3+ evaluated reps, the
> `RecommendationBiasEngine` could surface a "Drill the &lt;scenario&gt;
> tone" recommendation that biases toward the relevant skill area +
> auto-fills the scenario. With both the relational-trend read and the
> tone read now visible at the list **and** detail level, the read side
> of this loop is fully surfaced — the missing half is the
> recommendation trigger. **This is the natural next round — the read is
> done; close the loop.**

This push closes it.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- The user can already **see** which scenario is bleeding tone (the
  round-7/8 chips). Now the coach **acts** on it: the home coach card
  prescribes a one-tap re-rep of the exact scenario, with the exact
  tone the user keeps missing, the moment the evidence is there.

## What shipped

### Track 1 — The pure signal (`IMHistorySummary.toneDrillSignal`)

`Noum/IMHistorySummary.swift` gains a new pure static that scans every
`IMConversationScenario.allCases`, reads the existing
`toneMatchStats(from:scenario:)` per scenario, and returns the **single**
scenario most worth drilling — or `nil` when nothing clears the bar.

- **Honest evidence bar.** A scenario qualifies only with
  `evaluatedCount >= toneDrillMinEvaluatedReps` (3) **and** `matchRate <
  toneDrillMatchRateThreshold` (0.4). A low rate on one or two reps is a
  bad day, not a pattern; an undefined rate (no evaluated reps) is not a
  miss. Both thresholds are named `static let`s shared with the test
  suite so the boundary is asserted, not guessed.
- **Worst-first selection.** When several scenarios qualify, the lowest
  hit rate wins (most coaching leverage). Tiebreak: more `evaluatedCount`
  (more trustworthy read), then the most-recent evaluated rep (freshest).
- **The tone to re-set** is `dominantEvaluatedTone` — the tone the user
  committed to **most often** in that scenario's *evaluated* reps
  (tiebreak: the most-recent rep that used it), so a 2-2 split picks the
  tone they're reaching for now. It is computed over the same
  evaluated-rep filter that produced the hit rate — never a profile
  default. The drill re-sets the target the user is actually missing.
- New value type `IMToneDrillSignal` (`scenario` / `targetTone` /
  `matchRate` / `evaluatedCount`) lives in `PracticeSupport.swift` next
  to the engine, non-gated, so the engine's signature doesn't depend on
  the iOS-17-gated summary type.

### Track 2 — The engine override (`RecommendationBiasEngine`)

`RecommendationBiasEngine.blueprint(...)` gains a **purely additive**
trailing parameter `imToneSignal: IMToneDrillSignal? = nil`:

- **Default nil → every existing call site is byte-for-byte unchanged.**
  The four callers (`ContentView`, `HomeCoachCard`, `SummaryView`,
  `PracticeModeSelectionView`) that don't pass it get identical behaviour
  to before. Zero regression surface for the un-updated surfaces.
- When a signal **is** passed, the engine short-circuits to the new
  private `toneDrillBlueprint(signal:)` **before** the generic
  goal-based bias. It returns a blueprint that:
  - biases to **`.imConversation`** (the relevant skill area for tone),
  - prefills `recommendedScenario` + `recommendedTone` (the missed tone),
  - sets `focus` = "&lt;Scenario&gt; tone", `target` = "Land &lt;tone&gt;
    in &lt;Scenario&gt;",
  - writes `whyNow` copy that reports the **observed** hit rate ("Across
    your last 4 Difficult Conversation reps your calm tone landed only
    25% of the time. Re-run the same scenario and hold the tone end to
    end.") — no AI reframe, no shame; a low number is informative data,
    the fix is a rep.
- The override **self-clears**: once the user's hit rate on that scenario
  recovers to ≥40%, `toneDrillSignal` returns nil and the engine falls
  back to its normal bias. It can never get stuck recommending a scenario
  the user has already fixed.

### Track 3 — Wiring the two auto-filling surfaces

`ContentView.recommendationBiasBlueprint` and
`HomeCoachCard.recommendationBlueprint` (the two surfaces that already
drive the "your next rep" CTA **and** auto-fill scenario + tone via
`.imPractice(scenario:tone:)`) now compute and pass the signal:

```swift
imToneSignal: IMModeAvailability.isAvailable
    ? IMHistorySummary.toneDrillSignal(from: sessionStore.sessions)
    : nil
```

Guarded on `IMModeAvailability.isAvailable` so that if IM mode is offline
the engine falls back to its normal bias instead of recommending a mode
that would just be re-routed to Timed downstream. Because the existing
plumbing already reads `focus` (HomeCoachCard title), `target` (the chip),
`whyNow` (subtitle), and `recommendedScenario`/`recommendedTone` (the CTA
destination), **no view-layer code changed** — setting those four
blueprint fields lights up the whole card and the one-tap drill.

### Track 4 — Locked contract (`IMToneDrillSignalTests`, 12 cases)

New suite in `NoumTests/NoumTests.swift` pins the parts the surfaces now
depend on:

- nil on empty history; nil below the 3-rep bar; **nil at the exact 0.40
  boundary** (the "strictly below" contract — 2/5 reps must not fire);
- fires at 1/4 == 0.25 with the right scenario / tone / count / rate;
- **worst-scenario selection** (0.0 beats 0.25 across two qualifiers);
- **evidence tiebreak** (equal 0.25, the 8-rep scenario beats the 4-rep);
- **dominant-tone choice** across mixed committed tones in one scenario;
- missing / whitespace `actualTone` excluded so it can't pad the count
  into clearing the bar;
- the engine override (mode/scenario/tone/focus/target + honest `whyNow`
  copy contains the observed %), the **nil-signal regression guard**, and
  the **end-to-end** sessions → signal → blueprint path.

### Vision alignment

- **Pillar #3 — Conversational intelligence** and **#5 — Personalized
  coaching.** "You keep aiming for calm in difficult conversations and
  landing it under 40% of the time — let's drill exactly that" is the
  read a human coach gives, then the prescription that follows it.
- **Coach-parity loop — Intervention + Adaptation.** This is a
  recommendation with **evidence** (≥3 reps), a named **observable
  target** (the tone), an **honest threshold** for firing (<40%), and an
  honest threshold for **stopping** (self-clears at ≥40%). It prescribes a
  drill *for a reason* and names what improvement looks like, exactly per
  the VISION "Development instructions".
- **Anti-goals respected.** No fabricated data (the bar refuses thin
  evidence), no shame copy (reports the number, doesn't punish it), no
  new disconnected AI surface (extends the existing deterministic engine).

## Files touched

- **Modified:** `Noum/IMHistorySummary.swift` (+~95 LOC —
  `toneDrillSignal(from:)`, private `dominantEvaluatedTone(from:scenario:)`,
  nested `IMToneDrillCandidate`, the two `static let` thresholds, doc
  comment)
- **Modified:** `Noum/PracticeSupport.swift` (+~40 LOC — `IMToneDrillSignal`
  value type; `imToneSignal:` param on `blueprint`; private
  `toneDrillBlueprint(signal:)`; short-circuit comment)
- **Modified:** `Noum/ContentView.swift` (+~3 LOC — pass the signal,
  availability-guarded)
- **Modified:** `Noum/HomeCoachCard.swift` (+~3 LOC — pass the signal,
  availability-guarded)
- **Modified:** `NoumTests/NoumTests.swift` (+~210 LOC — new
  `IMToneDrillSignalTests` suite, 12 cases + builders)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief.

The artifact a user can now hold:

**When a user keeps missing the tone in one specific conversation
setup, the home coach card stops giving generic advice and instead
says, in their own numbers, "drill this exact scenario, in this exact
tone, now" — and tapping it drops them straight into that rep with
both prefilled.** The read side told them *where* the tone slips; this
closes the loop by making the *fix* a single tap, gated behind real
evidence, and it disappears on its own the moment they fix it.

## Future moves

(Updated priority list — round-8 item #1 closed this round; remaining
items carried forward and re-prioritised:)

1. **Offer the same drill from the other recommendation surfaces.**
   `PracticeModeSelectionView.computeRecommendation` and `SummaryView`
   also call `RecommendationBiasEngine.blueprint` but currently pass no
   signal, and `PracticeModeSelectionView.appDestination(for: .imConversation)`
   launches with `scenario: nil, tone: nil` even when the blueprint
   carries them. The natural next round is to (a) pass the signal at
   those two sites and (b) have their IM destination honour
   `blueprint.recommendedScenario` / `recommendedTone`, so the drill is
   offered consistently wherever the user lands — not only on Home.
   Deferred here only to keep this push to the two surfaces that already
   auto-fill, and because it wants the recommendation-surface QA the
   round-8 note called for (a real device, which this build host lacks).
2. **Close the Adaptation half: did the drill work?** This round
   *prescribes* the drill; it does not yet *observe the response*. The
   deeper coach-parity move is to read whether the tone-match rate on a
   drilled scenario improved across the reps that followed the
   recommendation (reuse the existing `RecommendationOutcome` /
   `RecommendationLearningStore` evidence machinery), and either
   reinforce ("calm is landing now — hold it") or vary the intervention
   with an explained rationale. That is the "Adaptation" stage in
   `docs/VISION.md`'s coach-parity loop and the honest next standard the
   VISION names ("did that prescribed work help this specific user?").
3. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
4. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor pass
   with proper visual QA (and a real device).
5. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` so the Settings AI-usage card AND the
   `CoachReadCard` daily-budget hint refresh mid-view. Low priority
   (Settings is modal in practice).

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
change was written to match the existing, tested patterns line-for-line
(the new test suite reuses the `IMScenarioToneMatchStatsTests`
session-builder shape verbatim; the engine change reuses the existing
`RecommendationBiasBlueprint` construction shape and `playbookEntry`),
and the engine change is **purely additive** (a default-`nil` parameter)
so every un-updated call site is byte-for-byte unchanged. Before this
lands in a TestFlight build it still wants a real `xcodebuild test` and a
glance at the home coach card for a test account that has a sub-40%
tone-match scenario, to confirm the title / target chip / subtitle /
one-tap CTA all read as designed. Treat the "lights up the whole card"
claim as designed-for, not observed.
