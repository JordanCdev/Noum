# HANDOFF — M24 deferred slate (round 10): tone-drill reaches the practice picker + the post-session read

## Scope

Round 9 (commit `0b55e2b`) closed the *read → act* gap on **Home**:
the per-scenario tone-drill recommendation (`IMHistorySummary.toneDrillSignal`)
fed `RecommendationBiasEngine.blueprint` on `ContentView` and
`HomeCoachCard`, so the home coach card prescribed a one-tap re-rep of
the exact scenario + tone the user keeps missing. Round 9 named the next
move explicitly and flagged it #1:

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

Translation, this round: the coach already prescribes the drill on
Home. But a user who opens **Pick a mode** to start practicing, or who
just **finished a rep**, was getting the generic recommendation — the
exact scenario/tone the coach identified was dropped on the floor.
This round carries the drill to both of those surfaces, so the
prescription is the same wherever the user is standing when they decide
to practice.

## What shipped

### Track 1 — The practice picker honours the drill (`PracticeModeSelectionView`)

The mode picker is the main "I'm about to practice" surface. Two
changes make it carry the drill end to end:

- **Pass the signal.** `computeRecommendation()` now passes
  `imToneSignal: IMModeAvailability.isAvailable ? IMHistorySummary.toneDrillSignal(from: sessionStore.sessions) : nil`
  — the exact availability-guarded pattern the two Home surfaces already
  use. When the user has a sub-40% tone-match scenario (≥3 evaluated
  reps), the recommendation becomes the IM tone-drill blueprint; the
  picker's recommended tile + "why" line already read from that
  blueprint, so they light up with no further view change.
- **Honour the prefill.** Two new `@State`s
  (`cachedRecommendedScenario` / `cachedRecommendedTone`) capture
  `blueprint.recommendedScenario` / `recommendedTone` in
  `computeRecommendation()`, and `appDestination(for: .imConversation)`
  now returns `.imPractice(scenario: cachedRecommendedScenario, tone: cachedRecommendedTone)`
  instead of the old `scenario: nil, tone: nil`. Tapping the IM tile (or
  the start CTA when IM is pre-selected) drops the user **straight into
  the exact scenario + tone** the coach flagged — the same one-tap drill
  Home already offers.

### Track 2 — The post-session read names the drill (`SummaryView`)

`summaryRecommendation` now passes the same availability-guarded signal.
The blueprint feeds the post-session **"Looking ahead"** card
(`LookingAheadCard`), which is purely a read (no launch CTA). So after a
**non-IM** rep, the card now reads, in the user's own observed numbers,
"For your next session, try IM Conversation … your calm tone landed only
25% of the time — re-run the same scenario and hold the tone end to
end." From there the user taps "New Chat" → the now-wired picker, which
launches the drill prefilled. The summary surface therefore *names* the
drill and *routes to* the one-tap version of it.

(The card self-suppresses after an IM rep — `lookingAheadHint` returns
nil when the recommended mode equals the mode just finished — so it
never tells the user to "try IM" on the IM summary. Correct: you don't
suggest the mode they're already in.)

### Track 3 — The honest no-leak invariant (`RecommendationIMDestinationPrefillTests`, 2 cases)

The picker's destination now reads `blueprint.recommendedScenario` /
`recommendedTone` directly, so the safety of the whole change rests on
one engine invariant: **those two fields are populated exactly when the
recommended mode is IM, and nil for every other mode.** If that ever
broke, tapping the IM tile after, say, an Ah-Counter recommendation
could launch a stale scenario. The tone-signal path was already locked
(round 9); these two cases pin the **profile path**:

- `imRecommendationPopulatesScenarioAndTone` — a calmer-delivery / work /
  warm profile biases to IM and resolves to `.difficultConversation` +
  `.warm`, so both fields are set.
- `nonIMRecommendationLeavesScenarioAndToneNil` — a reduce-fillers
  profile biases to a non-IM mode (Ah-Counter) and leaves **both** the
  scenario and tone nil, so the IM tile stays a default rep.

### Vision alignment

- **Pillar #3 — Conversational intelligence** and **#5 — Personalized
  coaching.** The coach's read of *which exact conversation tone keeps
  slipping* is now consistent across every surface where the user
  decides to practice — Home, the mode picker, and the post-rep read —
  not a one-off on a single screen.
- **Coach-parity loop — Prescribe + Transfer.** A human coach gives the
  same prescription whether you ask them before a session or right after
  one; the drill no longer evaporates depending on which door the user
  walked through. This round is plumbing in service of that consistency,
  not a new claim.
- **Anti-goals respected.** No new AI surface, no fabricated data (the
  signal still clears the same ≥3-rep / <40% bar; the new tests prove a
  non-IM bias can't leak a scenario), no shame copy (the Looking-ahead
  card reports the observed number, same as Home). Purely additive at the
  engine — the four prior callers are byte-for-byte unchanged.

## Files touched

- **Modified:** `Noum/PracticeModeSelectionView.swift` (+~22 LOC — two
  `@State`s, the availability-guarded `imToneSignal:` arg + scenario/tone
  caching in `computeRecommendation`, the honoured IM destination)
- **Modified:** `Noum/SummaryView.swift` (+~8 LOC — the availability-guarded
  `imToneSignal:` arg on `summaryRecommendation`)
- **Modified:** `NoumTests/NoumTests.swift` (+~88 LOC — new
  `RecommendationIMDestinationPrefillTests` suite, 2 cases + builders)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` (via PR from the working branch, per the user's brief — the
drill must land on Redesign).

The artifact a user can now hold:

**Wherever the user decides to practice — the home card, the "Pick a
mode" screen, or the read after a rep — the coach gives the same
prescription: drill the exact scenario whose tone keeps slipping, in the
exact tone they keep missing, in one tap.** Round 9 made Home say it;
this round makes the mode picker launch it and the post-session read
name it, so the prescription is consistent instead of surfacing on only
one screen.

## Future moves

(Updated priority list — round-9 item #1 closed this round; remaining
items carried forward and re-prioritised:)

1. **Close the Adaptation half: did the drill work?** The drill is now
   *prescribed* everywhere, but the loop still doesn't *observe the
   response*. The deeper coach-parity move is to read whether the
   tone-match rate on a drilled scenario improved across the reps that
   followed the recommendation (reuse the existing
   `RecommendationOutcome` / `RecommendationLearningStore` evidence
   machinery), and either reinforce ("calm is landing now — hold it") or
   vary the intervention with an explained rationale. This is the
   "Adaptation" stage in `docs/VISION.md`'s coach-parity loop and the
   honest next standard the VISION names ("did that prescribed work help
   this specific user?"). **This is the natural next round — the
   prescribe side is now fully surfaced; close the loop by observing the
   response.**
2. **"Try Again" after an IM rep could relaunch the same scenario.**
   `SummaryView.onPracticeAgain` re-runs the just-finished mode but, for
   IM, still launches `.imPractice(scenario: nil, tone: nil)` — i.e. a
   *random* scenario, not the one the user just did. Honouring the
   just-finished scenario (and, when it matches an active drill signal,
   its target tone) would make "Try Again" a true repeat. Deferred from
   this round because it changes "repeat" semantics and genuinely wants
   device QA, and because it needs the just-finished scenario threaded
   into the `onPracticeAgain` closure (it builds the destination from
   `payloadMode` alone today).
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

This environment has **no Xcode and no Swift toolchain** (`swift` /
`xcodebuild` are absent), so nothing in this round was compiled or run —
not the app, not the test suite. The change was written to match the
existing, tested round-9 pattern line-for-line: the `imToneSignal:`
call-site arg is copied verbatim from `ContentView` /
`HomeCoachCard`, the new `@State` + cache mirrors how
`cachedRecommendedMode` / `cachedRecommendedReason` are already set, the
destination uses the same `.imPractice(scenario:tone:)` shape Home's CTA
uses, and the new test suite reuses the `IMToneDrillSignalTests`
`input()` builder shape and the `CoachingProfile` construction used
across the existing suite. The engine itself is untouched. Before this
lands in a TestFlight build it still wants a real `xcodebuild test` and a
glance, for a test account that has a sub-40% tone-match scenario, at:
(1) the "Pick a mode" screen — confirm the IM tile is recommended and
tapping it opens the flagged scenario with the missed tone preset; and
(2) a post-session summary after a *non-IM* rep — confirm the
"Looking ahead" card names that scenario + tone in the observed %. Treat
the "lights up / launches the drill" claims as designed-for, not
observed.
