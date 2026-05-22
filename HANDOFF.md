# HANDOFF — Quote → source session + seeded coaching profile

## Scope

This push closes two of the three open follow-ons left by the previous
HANDOFF (Growth Library):

1. **Future-move follow-on** — quote cards in the Growth Library now
   navigate to the session that produced them. The library moves from
   read-only evidence display ("here's a thing you said") to a learning
   loop ("here's a thing you said — go re-read the full session"). Tap a
   card → land on the same `SessionHistoryDetailView` the History tab
   uses, with the full transcript, AI coach read, IM conversation card,
   and metric breakdown available.
2. **M16 explicit TODO** — `DevSeedData.injectProfile(_:)` now seeds
   `CoachingProfileStore` alongside sessions / baseline / rating / XP.
   The TODO sat in `NoumUITests.swift:23` and called out that the
   `home.path` gated card couldn't be tap-tested on a freshly-seeded
   simulator because the M15 Phase 4 HomeSignalGate needed a
   `CoachingProfile`. Now it does. The UI test reverts from the
   `noum://path` deep-link fallback back to the tap-the-card pattern,
   with a defensive deep-link fallback if the card somehow isn't
   visible on a slow simulator boot.

Files in this push:

- `Noum/PracticeSupport.swift` (+~25 LOC) — new
  `AppDestination.sessionDetail(sessionID: UUID)` case, new
  `CoachingProfileStore.replaceForDebug(_:)` (DEBUG-only, mirrors
  `replaceFromRemote` but skips the backend-sync + AI-paraphrase side
  effects production `save(_:)` triggers).
- `Noum/SessionHistoryView.swift` (~3 LOC) —
  `SessionHistoryDetailView` is now `internal` (was `private`) so the
  ContentView destination switch can render it. View body is
  unchanged.
- `Noum/ContentView.swift` (+~20 LOC) — destination switch case for
  `.sessionDetail(sessionID:)` resolves the session against the live
  `PracticeSessionStore`. Falls back to `SessionHistoryView` when the
  session has been deleted since the artifact was recorded — graceful,
  no crash, no empty card.
- `Noum/GrowthLibraryView.swift` (~+5 / -3 LOC) — each quote card is
  now a `NavigationLink(value: .sessionDetail(sessionID:))` styled
  `.buttonStyle(.pressable)`. Adds `growthLibrary.card.<sessionID>`
  accessibility identifier + hint "Opens the session this moment came
  from."
- `Noum/DevSeedData.swift` (+~90 LOC) — `injectProfile` now also
  seeds `CoachingProfileStore` via a new internal helper
  `seedCoachingProfile(for:)`. Each `SeedProfile` carries a
  narrative-coherent voice + priority + challenge + coaching brief +
  motivation + success vision (improvingIntermediate → warm + moreConcise,
  plateauedAdvanced → authoritative + presentations, pressureVulnerable
  → executive + calmerDelivery, fillerFree → concise + persuasive,
  beginner → warm + reduceFillers + rebuilding confidence).
- `NoumUITests/NoumUITests.swift` (~+10 / -8 LOC) —
  `testHomeScreenAndPrimaryNavigation` switched back to tap-the-card
  pattern for the journey card, with the deep-link fallback retained
  as defense against slow-simulator flakes.
- `NoumTests/NoumTests.swift` (+~85 LOC) — eleven new tests across
  two suites:
  - `AppDestinationSessionDetailTests` (4 tests) — equality by session
    ID, distinctness across different IDs, distinctness from other
    destinations, Hashable round-trip.
  - `DevSeedCoachingProfileTests` (7 tests, DEBUG-only) — per-seed
    voice mapping locked (improvingIntermediate / plateauedAdvanced
    / pressureVulnerable / fillerFree / beginner), every-seed
    completeness contract (no empty coachingBrief / motivationWhyNow
    / successVision), voice-distinctness contract (≥4 distinct
    voices across 5 seeds for visual breadth).
- `docs/CURRENT_STATE.md` (header breadcrumbs + new bullets).
- `HANDOFF.md` (this file, rewritten).

## What changed

### Move 1 — `AppDestination.sessionDetail(sessionID:)`

The Growth Library shows a verbatim quote from a past session, a
technique label, a coach claim. Previously the card was read-only —
the user could see the evidence but couldn't get back to the source
material. This destination + the corresponding `NavigationLink`
wrapper turns the quote card into a learning launch point: tap →
land on the full session detail (`SessionHistoryDetailView`) →
re-read the transcript in context.

The destination is keyed by `UUID` (the `ProofMomentRecord.sessionID`,
which is also `PracticeSession.id` — same identity). `NavigationLink`
uses value-typed routing, so the navigation stack stays untyped /
`NavigationPath`-friendly the same way every other AppDestination
case does.

`SessionHistoryDetailView` was already a complete, polished detail
surface — heroCard + focusCard + transcript card + AI coach read +
IM conversation card (when applicable) + insights card. Reusing it
saves a parallel detail view and keeps the chrome consistent
whether the user lands from History or Growth Library.

Graceful fallback in `ContentView`: if the session has been deleted
since the proof was banked (e.g. user cleared history but the
ProofMomentArchive still has the record because the archive is
per-session-ID rather than per-PracticeSession), the destination
renders `SessionHistoryView` instead of the detail view. No crash,
no empty-state lie.

### Move 2 — `CoachingProfileStore.replaceForDebug(_:)`

New DEBUG-only injector mirroring the pattern of
`PracticeSessionStore.replaceAllForDebug`,
`RatingStore.replaceForDebug`, and `ProfileManager.replaceFromRemote`.
Writes the profile to UserDefaults against the current account ID
(falling back to `"guest"` when no account is set, matching the
session store's behaviour). Skips the production `save(_:)` side
effects (backend sync + AI paraphrase) because seeded data is
local-only and shouldn't trigger backend writes or AI quota spend.

Sets `shouldPresentInitialOnboarding = false` so a seeded simulator
doesn't show the onboarding fullscreen cover over the home —
matches the behaviour of `replaceFromRemote` for the same reason.

### Move 3 — `DevSeedData.seedCoachingProfile(for:)`

Internal helper exposed for testing — returns a `CoachingProfile`
tuned to each `SeedProfile`'s narrative:

- `beginner` (5 sessions, high fillers) — `.reduceFillers` priority,
  `.fillerWords` challenge, `.rebuilding` confidence, `.warm` voice.
  Reads like an early-career user just starting to take feedback
  seriously; warm keeps the coach copy non-judgmental.
- `improvingIntermediate` (12 sessions, fillers dropping) —
  `.moreConcise` priority, `.rambling` challenge, `.inconsistent`
  confidence, `.warm` voice. Showcase profile: the screenshot tour
  + UI tests + `noum-screenshots` skill all hit this. Voice picks
  warm because the visible improvement reads better with friendly
  framing than authoritative.
- `plateauedAdvanced` (20 sessions, strong on most, weak openings) —
  `.moreConcise` priority, `.rambling` challenge, `.confident`
  baseline, `.authoritative` voice, `.presentations` context. Reads
  like a senior leader who's mid-career and looking for the next
  edge.
- `pressureVulnerable` (15 sessions, great casual / weak pressure) —
  `.calmerDelivery` primary, `.rushing` challenge, `.inconsistent`
  baseline, `.executive` voice, `.interviews` context. Reads like
  a founder prepping for investor Q&A.
- `fillerFree` (18 sessions, near-zero fillers) — `.moreConcise`
  primary, `.rambling` challenge, `.confident` baseline, `.concise`
  voice, `.persuasive` outcome. Reads like a polished speaker
  honing edges, not learning basics.

Five seeds × five distinct voices (or near it — `improvingIntermediate`
and `beginner` both pick `.warm`, which is the right choice for both
narratives, so the test contract is ≥4 distinct voices not 5). Each
seed carries non-empty `coachingBrief`, `motivationWhyNow`, and
`successVision` so the entire goal-aware coaching loop has
something to read — the M14 surfaces (VoiceAnchorBanner,
LiveEloquenceHUD, VoiceAlignmentChip, goal-progress ring) all light
up on a seeded simulator instead of staying cold.

### Move 4 — `home.path` tap-the-card pattern restored in UI tests

`testHomeScreenAndPrimaryNavigation` lands on the seeded home, looks
for `home.path` (the journey card), and taps it if present. The
defensive deep-link fallback to `noum://path` is retained — slow
simulator boots can still flake on the visibility wait. The test
intent is "journey screen reachable from a cold launch", which is
satisfied by either path.

### Move 5 — Eleven new tests

`AppDestinationSessionDetailTests` (4 tests, no MainActor needed,
the enum is value-typed):

1. `sessionDetailEqualsBySessionID` — same UUID → equal destinations.
2. `sessionDetailDistinctBySessionID` — different UUIDs → distinct.
3. `sessionDetailDistinctFromOtherCases` — `.sessionDetail` doesn't
   collide with `.growthLibrary` or `.sessionHistory`.
4. `sessionDetailIsHashable` — Set round-trip dedupes identical
   destinations.

`DevSeedCoachingProfileTests` (7 tests, DEBUG-only, no MainActor —
the helper is pure):

1. `improvingIntermediateSeedsWarmVoiceAndConciseGoal` — showcase
   profile voice + goal + challenge + non-empty displayableGoal.
2. `plateauedAdvancedSeedsAuthoritativeVoice` — voice + context.
3. `pressureVulnerableSeedsExecutiveVoiceAndCalmerGoal` — voice +
   primary goal + challenge.
4. `fillerFreeSeedsConciseVoiceAndPersuasiveOutcome` — voice +
   outcome.
5. `beginnerSeedsRebuildingConfidenceAndFillerFocus` — confidence
   level + primary goal + challenge.
6. `everySeedProfileProducesACompleteCoachingProfile` — every seed
   produces non-empty brief / why-now / success-vision so every
   goal-aware surface has something to read.
7. `everyVoiceIsDistinctAcrossSeedProfiles` — ≥4 distinct voices
   across the 5 seeds (visual breadth for the screenshot tour).

## What did NOT change

- `ProofMomentArchive.swift` — untouched. The store + record + weekly
  groupings + persistence are all unchanged. Move 1 only consumes
  the existing `sessionID`.
- `SessionHistoryDetailView` body — untouched. The view is now
  `internal` instead of `private`, that's the only diff. No visual
  changes, no behaviour changes.
- `AskNoumView.swift`, `AIWeeklyInsightCard.swift`,
  `PathNodeCelebration.swift`, `PersonalBestCelebrationScreen` —
  untouched. Existing proof-rendering surfaces still consume
  `ProofMomentStore.shared.recent(limit:)`; the new navigation
  surface is purely additive.
- `OnboardingHero` flow — untouched. `replaceForDebug` sets
  `shouldPresentInitialOnboarding = false` but doesn't bypass the
  onboarding hero (`OnboardingHeroManager` is a separate manager).
- Brand voice — preserved. Accessibility hint "Opens the session
  this moment came from." matches the coach's restrained register.
  No exclamations, no chirpy copy.
- Design tokens — used as-is. The NavigationLink wrapping doesn't
  introduce any new colors, spacing, or typography.

## Risks

1. **`SessionHistoryDetailView` is now reachable from two surfaces.**
   The History tab pushes it via the local
   `NavigationLink { SessionHistoryDetailView(...) }` (label-based),
   the Growth Library pushes it via `NavigationLink(value:)`
   (value-based). Both render the same view; the navigation back
   path differs (History → swipe back to History list, Library →
   swipe back to Library). The detail view has no awareness of
   where it was launched from, which is correct (the view itself
   shouldn't care).
2. **A user can deep-link a sessionDetail to a session that's been
   deleted.** Fallback renders `SessionHistoryView`, which is
   defensive but not informative — the user won't know why they
   landed on the list instead of the specific session. Acceptable
   for now: the proof archive is bounded at 12 records, sessions
   are rarely deleted, and the alternative (alert / toast) adds
   surface area for a rare case. Revisit if usage data suggests
   confusion.
3. **DEBUG-only `replaceForDebug` is reachable from production via
   `DevSeedData.injectProfile`.** That's intentional and matches
   the pattern of `PracticeSessionStore.replaceAllForDebug` /
   `RatingStore.replaceForDebug`. Production code never calls
   `injectProfile`; the only call sites are the Settings debug menu
   (`SettingsView.swift:1234`) and the UI testing launch path
   (`NoumApp.swift:40`), both DEBUG-guarded.
4. **Seeded CoachingProfile + restart.** On second launch with
   `UI_TESTING_SEED` (not `_FORCE`), `NoumApp.init` skips the
   reseed because `PracticeSessionStore.sessions` is not empty.
   The seeded `CoachingProfile` persists in UserDefaults via
   `replaceForDebug` and is reloaded on auth via
   `CoachingProfileStore.reloadForCurrentAccount()`. Verified the
   load path — UserDefaults blob is decoded via the
   `loadProfile(forKey:)` static helper, which handles the keys
   `replaceForDebug` writes.
5. **Voice-distinctness contract is ≥4 not =5.** Two seeds
   (`beginner` and `improvingIntermediate`) both pick `.warm`. If
   a future tightening wants every seed to be uniquely-voiced,
   the test will fail at `==5` — for now, `>=4` keeps the
   contract honest about the design choice (warm fits both
   narratives best) without locking us out of a future tightening.
6. **`AppDestination` is in a hot file (PracticeSupport.swift, 7800+
   lines).** Adding one case is low-risk, but each touch to that
   file is a tax on the long-term refactor target flagged in
   CURRENT_STATE.md known-debt. No regression introduced — the
   case is the smallest possible diff.

## Verification

### Implemented

- `AppDestination.sessionDetail(sessionID: UUID)` is declared once
  in `Noum/PracticeSupport.swift`.
- `ContentView.swift`'s destination switch handles `.sessionDetail`
  with a live-store resolve + graceful `SessionHistoryView`
  fallback.
- `SessionHistoryDetailView` is `internal` (the `private` modifier
  is gone — verified via `grep -n "struct SessionHistoryDetailView"`).
- `GrowthLibraryView`'s `weekSection` wraps each card in a
  `NavigationLink(value:)` with `growthLibrary.card.<sessionID>`
  identifier + the "Opens the session this moment came from."
  hint.
- `CoachingProfileStore.replaceForDebug(_:)` is `#if DEBUG`-gated
  and lives next to `replaceFromRemote(_:for:)` in the store.
- `DevSeedData.injectProfile(_:)` calls
  `CoachingProfileStore.shared.replaceForDebug(seedCoachingProfile(for:))`
  after the existing XP / Rating / Session writes.
- `DevSeedData.seedCoachingProfile(for:)` is `internal` (was
  `private`) so the tests can lock the mapping without mutating
  any live store.
- Eleven new tests added end-of-file in `NoumTests/NoumTests.swift`,
  follow the existing `@Test` + `#expect(...)` rhythm.

### Blocked / needs visual QA on device

Surface change is small; visual QA goal:

1. **Cold start with seed** — fresh install, launch with
   `UI_TESTING_SEED`. Confirm the journey card (`home.path`) is
   visible, and the goal-aware home surfaces
   (`VoiceAlignmentChip` on the suggestion link, voice anchor on
   practice modes) read "Toward your warm voice" since
   `improvingIntermediate` now carries `.warm`.
2. **Growth Library tap** — populate the proof archive (run a few
   sessions until Personal Best / Path Celebration / Weekly Insight
   fires a proof), open Profile → tap the insights banked chip,
   then tap a quote card. The session detail screen should push
   with the full transcript visible.
3. **Deleted-session fallback** — delete a session from History
   while its proof is still in the archive, then tap that proof
   card from the Library. The History list should appear instead
   of a crash or empty card.
4. **CoachingProfile persistence across restarts** — launch with
   seed once (profile lands), terminate, launch again without
   `_FORCE` — `CoachingProfileStore.shared.profile` should still
   be populated (not re-injected, just persisted).

### Assumptions

- The right destination for a Growth Library quote-card tap is
  the session detail view, not a dedicated "proof detail" screen.
  The proof itself is already fully shown on the library card
  (verbatim quote, technique, claim, source badge); the value of
  drilling in is the *full session context*, which is exactly
  what `SessionHistoryDetailView` provides.
- Seeded CoachingProfile narratives match the existing seed
  session shapes (fillers dropping → tightening, plateaued →
  authoritative, etc.) without requiring any session-side
  changes. The session generators in `DevSeedData` already
  produce the right session shapes for these voices; the profile
  is a label on top, not a contract.
- The "≥4 distinct voices" test is the right contract floor.
  Five seeds with five voices would be more visually exhaustive,
  but `warm` legitimately fits two narratives (beginner +
  improvingIntermediate) and forcing uniqueness would weaken
  the voice fit for at least one.

### What was checked

- File reads + edits applied via Read / Edit / Write. Sandboxed
  Linux environment; no Xcode toolchain available to build.
- `grep` after each edit confirmed: (a) the new
  `AppDestination.sessionDetail` case lands exactly once,
  (b) the destination switch case lands exactly once,
  (c) `SessionHistoryDetailView` is `internal` not `private`,
  (d) `NavigationLink(value:)` wraps each Growth Library card
  exactly once, (e) `CoachingProfileStore.replaceForDebug` is
  declared once inside the `#if DEBUG` block,
  (f) `DevSeedData.injectProfile` calls `replaceForDebug` once.
- Tests added follow the existing `@Test` + `#expect(...)`
  rhythm; the DEBUG-only suite is wrapped in `#if DEBUG`.
- Sendability — the pure helper `seedCoachingProfile(for:)` is
  static + returns a value type. No actor crossings introduced.
- Brand voice — accessibility hint "Opens the session this
  moment came from." matches the coach's restrained register.
  No exclamations, no chirpy copy, no Let's.

## Files modified

- `Noum/PracticeSupport.swift` (+~25 LOC — new AppDestination case
  + new CoachingProfileStore.replaceForDebug).
- `Noum/SessionHistoryView.swift` (~3 LOC — make
  SessionHistoryDetailView internal).
- `Noum/ContentView.swift` (+~20 LOC — destination switch case).
- `Noum/GrowthLibraryView.swift` (~+5 / -3 LOC — wrap cards in
  NavigationLink).
- `Noum/DevSeedData.swift` (+~90 LOC — CoachingProfile seeding
  + per-seed helper).
- `NoumUITests/NoumUITests.swift` (~+10 / -8 LOC — restore
  tap-the-card pattern).
- `NoumTests/NoumTests.swift` (+~85 LOC — eleven tests across
  two suites).
- `docs/CURRENT_STATE.md` (header breadcrumbs + new bullets).
- `HANDOFF.md` (this file).

## Branch

`Redesign` — committed and pushed per the user's brief. The user
explicitly requested work on the Redesign branch ("ensure working
on the redesign branch too (very important)"). Continues the
post-M15 pattern of small, voice-coherent additions that close
loops opened by earlier pushes — each push moves the app closer
to the vision (a coach who's actually present, who quotes your
words, who can take you back to them) without inflating surface
area or breaking the brand-voice contract.
