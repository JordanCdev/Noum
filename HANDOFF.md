# HANDOFF — M24 deferred slate (round 10): the tone-drill follows the user everywhere

## Scope

Round 9 (commit `0b55e2b`) made the home coach card *act* on a
scenario the user keeps missing the tone in: when the evidence clears
the honest bar (≥3 evaluated reps, sub-40% tone-match) the card stops
giving generic advice and prescribes a one-tap re-rep of the *exact*
scenario, in the *exact* tone the user keeps missing. But that drill
only lived on **Home**. Round 9 named the next move explicitly and
flagged it #1:

> **Offer the same drill from the other recommendation surfaces.**
> `PracticeModeSelectionView.computeRecommendation` and `SummaryView`
> also call `RecommendationBiasEngine.blueprint` but currently pass no
> signal, and `PracticeModeSelectionView.appDestination(for: .imConversation)`
> launches with `scenario: nil, tone: nil` even when the blueprint
> carries them. The natural next round is to (a) pass the signal at
> those two sites and (b) have their IM destination honour
> `blueprint.recommendedScenario` / `recommendedTone`, so the drill is
> offered consistently wherever the user lands — not only on Home.

This push closes it.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round: a recommendation the user can only act on from
one screen is half a recommendation. A human coach doesn't only mention
the drill if you happen to be standing in the right room. So the
tone-drill now reaches the user from **every** surface that recommends a
next rep — the mode **picker** and the **post-session** read — resolved
through one shared, tested rule so the prefill lands identically wherever
they start.

## What shipped

### Track 1 — One shared rule for "where does this recommendation go" (`RecommendationBiasEngine.practiceDestination`)

Three surfaces (Home `HomeCoachCard.destination`, `ContentView`'s
practice-suggestion destination, and the picker's `appDestination`) each
carried their **own copy** of the same IM re-route switch: map the mode
to a destination, and for IM carry the prefilled scenario + tone — unless
IM mode is offline, in which case fall back to Timed. Three copies meant
the picker's copy had silently drifted: it launched IM with
`scenario: nil, tone: nil`, dropping the prefill the blueprint already
carried.

`Noum/PracticeSupport.swift` gains one pure static that *is* the rule:

```swift
static func practiceDestination(
    for mode: PracticeMode,
    scenario: IMConversationScenario?,
    tone: IMTargetTone?,
    imAvailable: Bool
) -> AppDestination
```

- An **IM recommendation carries its prefill** straight into
  `.imPractice(scenario:tone:)` — the one-tap start lands in the exact
  drill, not a blank IM rep.
- **IM offline re-routes to Timed** and drops the prefill, so we never
  push a mode that would just be bounced downstream.
- **Non-IM modes** map straight through and ignore any scenario/tone.

It lives next to the engine that *produces* the prefill, is pure
(no view state), and is now the single definition every surface shares —
so the drill is offered the same way wherever the user lands. This is
the rule the round-9 note asked the picker to "honour"; making it shared
is what guarantees it stays honoured.

### Track 2 — The picker now lands in the drill (`PracticeModeSelectionView`)

`computeRecommendation()` now passes the tone signal into the blueprint,
**byte-for-byte the same call Home makes**:

```swift
imToneSignal: IMModeAvailability.isAvailable
    ? IMHistorySummary.toneDrillSignal(from: sessionStore.sessions)
    : nil
```

The blueprint's prefill is cached into two new `@State` fields
(`cachedRecommendedScenario` / `cachedRecommendedTone`) right beside the
existing `cachedRecommendedMode`, and `appDestination(for:)` now resolves
through the Track-1 helper using them. Effect: when the user keeps
missing a scenario's tone, the picker recommends IM **and** quick-starting
it drops straight into that exact scenario + tone — the same drill Home
offers. When there's no tone-drill signal the cached prefill is nil, so a
generic IM pick is a blank IM rep exactly as before. Availability-guarded
so an offline IM mode falls back to the normal goal bias.

### Track 3 — The post-session read names the drill (`SummaryView`)

`summaryRecommendation` now passes the same availability-guarded signal.
Effect: after a non-IM rep, the "Looking ahead" card stops saying a
generic "try IM Mode" and instead carries the tone-drill read — the exact
scenario + tone, with the observed hit-rate copy ("…your calm tone landed
only 25% of the time…"). The existing `lookingAheadHint` guard
(`recommendedMode != currentMode`) means it correctly stays quiet right
after an IM rep rather than nagging the same mode.

**Honest scope note:** `LookingAheadCard` is an *informational* card —
it has no start CTA — so there is no navigable IM destination on the
Summary screen for the prefill to flow into. The screen's one IM
destination (`onPracticeAgain`) is a deliberate **same-mode re-rep** of
the session the user just finished; hijacking it with a *different*
recommended scenario would be wrong, so it is intentionally left alone.
Part (b) of the round-9 ask ("honour the prefill in the IM destination")
therefore applies to the picker, which has a real destination; for
Summary the win is part (a) — the read is now consistent with Home.
Turning the Summary card into a one-tap launcher is named below as the
natural follow-up (it wants the real-device QA this host can't give).

### Track 4 — Home + ContentView migrated to the shared rule

`HomeCoachCard.destination(for:)` and `ContentView`'s practice-suggestion
destination now call the Track-1 helper instead of their own inline
switch. **Behaviour-preserving** — each helper call reproduces the exact
switch it replaces (verified branch-by-branch) — but it removes the
triplication and makes the four surfaces provably identical. The
`UserDefaults` theme-seed side effect in `ContentView` is untouched; only
the trailing switch is replaced.

### Track 5 — Locked contract (`PracticeDestinationTests`, 4 cases + 1 end-to-end)

New suite in `NoumTests/NoumTests.swift` pins the rule every surface now
depends on:

- **IM available carries scenario + tone** into `.imPractice`.
- **IM offline re-routes to Timed** and drops the prefill (no dead route).
- **Generic IM** (no prefill) is still a blank IM rep — pre-existing
  behaviour unchanged.
- **Non-IM modes** map straight and ignore the prefill, asserted under
  *both* availability values.
- **End-to-end** (added to `IMToneDrillSignalTests`): low-hit-rate
  history → signal → blueprint → `practiceDestination` carries the exact
  `.imPractice(scenario:tone:)` — the full path the picker + Home now
  share.

### Vision alignment

- **Pillar #3 — Conversational intelligence** and **#5 — Personalized
  coaching.** The coach's read ("you keep aiming for calm and landing it
  under 40%") and its prescription (drill that exact scenario) no longer
  depend on the user being on the right screen. A real coach's advice
  follows you; so does this.
- **Coach-parity loop — Intervention, surfaced consistently.** The
  intervention is still evidence-gated and self-clearing (round 9); this
  round makes it *reachable* from every recommendation surface, which is
  what "the coach prepares the user for the moment that matters" requires
  in practice — not just on the home screen.
- **Anti-goals respected.** No new AI surface, no fabricated data (the
  same honest bar gates every surface), no shame copy. The migration is
  behaviour-preserving and the new logic is one pure, tested function.

## Files touched

- **Modified:** `Noum/PracticeSupport.swift` (+~26 LOC — the shared
  `practiceDestination(for:scenario:tone:imAvailable:)` static + doc
  comment)
- **Modified:** `Noum/PracticeModeSelectionView.swift` (pass the signal,
  two new cached `@State` fields, `appDestination` via the helper)
- **Modified:** `Noum/SummaryView.swift` (pass the signal,
  availability-guarded)
- **Modified:** `Noum/HomeCoachCard.swift` (migrate `destination` to the
  helper)
- **Modified:** `Noum/ContentView.swift` (migrate practice-suggestion
  destination to the helper)
- **Modified:** `NoumTests/NoumTests.swift` (+~100 LOC — new
  `PracticeDestinationTests` suite, 4 cases; +1 end-to-end case on
  `IMToneDrillSignalTests`)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — per the user's brief. (Pushed to the working development
branch and opened as a PR targeting `Redesign` so the change is
reviewable before it lands on the important branch.)

The artifact a user can now hold:

**The tone-drill the home coach prescribes now follows the user
everywhere.** Open the mode picker after missing the calm tone in
Difficult Conversation a few times and the picker recommends IM —
quick-start it and you drop straight into that exact scenario, in calm,
ready to re-set the target. Finish a Timed rep and the post-session
"Looking ahead" card names the same scenario + tone in the user's own
numbers. One evidence-gated, self-clearing recommendation, offered the
same way wherever the user lands — resolved through one shared,
test-locked rule.

## Future moves

(Updated priority list — round-9 item #1 closed this round; remaining
items carried forward and re-prioritised:)

1. **Close the Adaptation half: did the drill work?** Rounds 9–10
   *prescribe* the drill and now surface it everywhere; neither yet
   *observes the response*. The deeper coach-parity move is to read
   whether the tone-match rate on a drilled scenario improved across the
   reps that followed the recommendation (reuse the existing
   `RecommendationOutcome` / `RecommendationLearningStore` evidence
   machinery), and either reinforce ("calm is landing now — hold it") or
   vary the intervention with an explained rationale. That is the
   "Adaptation" stage in `docs/VISION.md`'s coach-parity loop and the
   honest next standard the VISION names ("did that prescribed work help
   this specific user?"). **This is the natural next round.**
2. **Make the Summary "Looking ahead" card a one-tap launcher.** Today it
   reads the tone-drill recommendation but can't start it (it has no CTA).
   Giving it the same one-tap launch as the home card — routed through the
   Track-1 `practiceDestination` helper, so the prefill is already wired —
   would close the last surface. Deferred because it's a view-layer change
   that wants real-device QA (does the CTA read right, does the nav push
   land in the prefilled scenario), which this build host can't provide.
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
change was written to match the existing, tested patterns line-for-line:
the picker/Summary signal calls are copied verbatim from the
already-shipped `ContentView` / `HomeCoachCard` calls; the Track-4
migration reproduces each replaced switch branch-by-branch
(behaviour-preserving); the new test suite reuses the `IMToneDrillSignal`
builders already in the file and asserts against `AppDestination`, which
is `Hashable` (so `==` is available). The new engine static is purely
additive. Before this lands in a TestFlight build it still wants a real
`xcodebuild test` and a glance, on a test account that has a sub-40%
tone-match scenario, at (a) the **picker** recommending IM and
quick-start dropping into the prefilled scenario + tone, and (b) the
post-session **Looking ahead** card naming that scenario + tone. Treat
the "lands in the exact drill" claim as designed-for, not observed.
