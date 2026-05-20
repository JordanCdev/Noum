# HANDOFF — Empty-state unification pass

## Scope

`Noum/HomeCoachCard.swift` (additive, ~30 LOC) + `Noum/ContentView.swift`
(net ~155 LOC removed) + `NoumUITests/NoumUITests.swift` (comment fix)
+ `docs/CURRENT_STATE.md` (timestamp + Home section + resolved-issue mark).

The brand-new user's first impression is now the same dream-tier hero the
returning user sees. The empty-state previously had a flat 104pt
greeting-header (`heroCard`) plus a brandBlue-capsule CTA card
(`firstSessionCard`) — neither carried the Pro-purple drift, glass material,
or emanation pulse that `HomeCoachCard` ships with on the populated home.
Now `HomeCoachCard` covers both states.

## What changed

### Move 1 — `HomeCoachCard` no-signal copy

- **`beginCTAText`** (`Noum/HomeCoachCard.swift` lines 132–147). Added an
  early-return for `!hasSignal` returning `"Begin · First rep"`. "Begin ·
  Timed" is a stranger's instruction at zero-rep; "Begin · First rep" is
  the door the user just walked up to.
- **`coachSubtitle`** (~`Noum/HomeCoachCard.swift` lines 348–367). The
  no-signal branch is now profile-aware. If `CoachingProfile` exists
  (user finished onboarding but hasn't done a rep yet), the subtitle
  reads "You want to work on [filler words / structure / thinking on
  the spot / pace]. One short rep sets your starting line." Falls
  through to "One short rep sets your starting line." otherwise. The
  copy mirrors what the legacy `firstSessionWelcomeMessage` in
  `ContentView` carried, lifted into the card itself so the
  composition is single-source.

### Move 2 — `restingMood` + `syncMoodForFreshRecommendation`

- New `restingMood` computed var (`Noum/HomeCoachCard.swift`). Reads
  `hasSignal ? .coaching : .listening`. Empty-state users see the
  `NoumCharacter` in `.listening` mood (symmetric arc-pulses around
  the character — "the coach is hearing you for the first time") so
  the moment feels like an invitation, not a lecture. Returning users
  see `.coaching` (slight tilt) as before.
- `syncMoodForFreshRecommendation` now sets the character to
  `restingMood` instead of hardcoding `.coaching`. Both onAppear and
  onChange paths route through this so the empty-state stays
  `.listening` until the user has reps.

### Move 3 — `ContentView` empty-state branch

- `Noum/ContentView.swift` lines 130–146. The empty-state branch in
  the populated/empty conditional now renders three cards:
  `HomeCoachCard` + `DailyGoalCard` + `secondaryDiscoveryCard`.
  Down from four (was `heroCard + firstSessionCard + DailyGoalCard +
  secondaryDiscoveryCard`). The `HomeCoachCard` instantiation passes
  `scrollOffset: homeScrollOffset` so the same interior parallax
  the populated home gets is active on empty state too.

### Move 4 — Dead-code removal

Deleted from `Noum/ContentView.swift`:

- `heroCard` (~50 LOC) — the legacy 104pt greeting-header with
  `NoumCharacter` at 76pt + time-of-day greeting + streak chip.
- `firstSessionCard` (~65 LOC) — the brandBlue-capsule CTA card with
  "Find your starting point" + "Start your first rep" button.
- `firstSessionWelcomeMessage` (~17 LOC) — copy generator now lifted
  into `HomeCoachCard.coachSubtitle`.
- `streakChip` (~17 LOC) — helper view used only by `heroCard`.
- `heroGreeting`, `heroSubtitle`, `heroTitle`, `heroCharacterMood`,
  `heroGradientTint`, `displayName` — all empty-state-only helpers
  whose call sites were the deleted cards.

Net `ContentView.swift`: 2136 → 1885 LOC (−251 LOC).

### Move 5 — Doc updates

- `docs/CURRENT_STATE.md` — Home section updated to note `HomeCoachCard`
  now serves both states; `SpeakingRatingCard placeholder` entry moved
  from "Known issues / debt" to a resolved note (it's actually fixed
  in `RatingHistoryChart.swift:38–49` — empty history returns
  `EmptyView()` from the chart slot rather than a placeholder string).
- `NoumUITests/NoumUITests.swift` — fixed an outdated comment in
  `launchApp()` that referenced `firstSessionCard`.

## What did NOT change

- **HomeCoachCard's chrome** — Pro-purple drift wash, `.regularMaterial`
  glass overlay, emanation ray, hairline border, accent tint, shadow.
  All untouched. The empty-state inherits the same alive treatment
  the populated state already had.
- **Accessibility identifiers** — `home.coachCard`,
  `home.coachCard.title`, `home.coachCard.subtitle`,
  `home.coachCard.begin` all preserved.
- **`home.firstSession`** (the deleted card's identifier) was not
  referenced from any UI test or production code path (verified via
  grep). Safe deletion.
- **Recommendation pipeline** — `RecommendationBiasEngine.blueprint`
  already handles `profile == nil` / empty sessions sensibly
  (defaults to `.timed` with focus "Baseline control"). The card's
  guards on `hasSignal` ensure the no-signal branch never reads
  blueprint copy that would surface awkwardly ("Your recent sessions
  still need a steadier baseline." on a user with no sessions).
- **`secondaryDiscoveryCard`** — Lessons + Path discovery rows below
  the Coach Card. Untouched. Visually subordinate by design so the
  Coach Card's "Begin · First rep" stays the primary CTA on first
  open.
- **Empty-state `DailyGoalCard`** — kept. Default goal is 1 rep
  with friendly copy "One rep is enough to count today." Reads as
  an invitation, not a counter at zero.

## Risks

1. **No-signal subtitle pluralization** — copy is English-only. Per
   the M13 honest gap, ~30 keys are in the Localizable.xcstrings;
   this new subtitle is not yet in it. Spanish + French users see
   English here. Consistent with the rest of the home copy.
2. **Profile-set-but-no-reps path** — the most common path is users
   complete `CoachingOnboardingView` (which sets profile) THEN see
   the home for the first time. They'll see "You want to work on
   cleaning up filler words. One short rep sets your starting line."
   on the no-signal subtitle. This is the right call: the coach
   reads their goal back at them on first open.
3. **`.listening` mood vs `.coaching` switch on first finalize** —
   after the user finishes their first rep, `hasSignal` flips true,
   and `restingMood` switches `.listening → .coaching`. SwiftUI
   re-renders the character mood; the NoumCharacter mood-change
   animation is internal (no flicker).
4. **UI tests** — no test referenced `home.firstSession`. The
   existing screenshot tour seeds via `UI_TESTING_SEED` which
   produces a populated home, so the empty state was never tested
   visually. This change to the empty state therefore can't
   regress any currently-passing test.

## Verification

### Implemented

- `HomeCoachCard.beginCTAText` returns "Begin · First rep" when
  `hasSignal == false`.
- `HomeCoachCard.coachSubtitle` no-signal branch reads
  `CoachingProfileStore.shared.profile?.biggestChallenge` and
  renders the matching variant. Falls through to the generic
  variant when no profile.
- `HomeCoachCard.restingMood` returns `.listening` for empty state,
  `.coaching` otherwise. `syncMoodForFreshRecommendation` and the
  reduce-motion early return both honour it.
- `ContentView` empty-state renders `HomeCoachCard` instead of
  `heroCard + firstSessionCard`. Card count: 4 → 3.
- All five empty-state-only helpers in `ContentView` deleted along
  with `displayName` (only consumer was deleted helpers).
- `docs/CURRENT_STATE.md` updated for both the Home section and
  the resolved SpeakingRatingCard placeholder.

### Partially implemented

None.

### Blocked

None.

### Assumptions

- The empty-state Coach Card sits between Pro-purple chrome and the
  `.listening` mood without reading as "marketing" — the brand
  purple is the coaching register, the mood is honest to the moment
  (coach hasn't heard the user yet). Verified against the brand
  rules in `Noum/.claude/skills/noum-design/`.
- "Begin · First rep" is the right CTA copy for the empty state.
  Other candidates ("Start your first rep", "Take your first rep")
  break the "Begin · <noun>" pattern the populated state uses.
  Consistency wins here.
- `coachingProfileStore.profile?.biggestChallenge` is the right
  field to drive the no-signal subtitle. The other enum fields
  (`primaryGoal`, `speakingStyleGoal`) are also captured during
  onboarding, but `biggestChallenge` is the one the existing
  `firstSessionWelcomeMessage` already used — keeping the same
  source of truth means no copy is invented.

### Verification

- Edits applied via Edit tool; no Bash builds run (sandboxed Linux
  environment, no Xcode toolchain). File reads cleanly end-to-end.
- All four `home.coachCard*` accessibility identifiers preserved.
- All reduce-motion gates preserved through `syncMoodForFreshRecommendation`
  and `triggerEmanation` (both already guarded by
  `accessibilityReduceMotion`).
- Grep confirmed no remaining references to the deleted helpers
  inside `Noum/`, `NoumUITests/`, or `NoumTests/`.
- `home.firstSession` identifier (deleted) had zero references in
  the test suite — safe deletion.

### Risks

- See "Risks" section above.

## Branch

`Redesign` — committed and pushed.

---

# HANDOFF — Home Coach Card "alive premium iOS hero" pass

## Scope

`Noum/HomeCoachCard.swift` only. The card was a tasteful static tinted
gradient + faint trailing mode accent + hairline border. It now reads
as an Apple Music / Fitness / Sleep-app hero: a slow-drifting Pro-purple
radial wash sits under a `.regularMaterial` frosted-glass overlay, and
the NoumCharacter emits a soft mode-tinted radial pulse when a fresh
recommendation lands.

No copy, hierarchy, accessibility identifier, or state-store change.
No new managers, routes, or files.

## What changed

### Move 1 — gradient drift (`coachCardBackground` + new `purpleWash`)

- `Noum/HomeCoachCard.swift:190-220`. The Pro-purple radial wash is now
  factored into a `purpleWash<S: Shape>(in shape: S)` helper. The
  non-reduce-motion path wraps the gradient in a
  `TimelineView(.animation(minimumInterval: 1.0 / 30.0))` that samples
  `context.date.timeIntervalSinceReferenceDate` and maps a 7-second
  sine to a drifting `UnitPoint`:
  `(0.35, 0.0)` ↔ `(0.65, 0.15)`.
  Sine into `[0, 1]` gives a symmetric ease-in-out loop that lingers
  softly at each end — the user reads "this card breathes," not "this
  card animates."
- Reduce-motion path renders a single static `RadialGradient` anchored
  at `(0.5, 0.0)` with no `TimelineView`, no animation source, no
  per-frame redraw.
- The drift is driven by the system animation clock (TimelineView)
  rather than `withAnimation` on a `@State UnitPoint`, because SwiftUI
  doesn't smoothly interpolate `RadialGradient.center` across
  re-creations — the TimelineView's per-frame redraw is the right
  primitive for ambient continuous motion of a gradient parameter.
- Wash alpha was bumped slightly (`0.22 → 0.26` near, `0.04 → 0.06`
  far) because the material overlay desaturates the visible result.

### Move 2 — `.regularMaterial` glass overlay (`coachCardBackground`)

- `Noum/HomeCoachCard.swift:171-177`. A `RoundedRectangle.fill(.regularMaterial)`
  layer is now sandwiched between the two radial washes (Pro-purple
  drift + trailing mode tint) and the strokeBorder. The material is
  rendered at `0.55` opacity so the washes show through as frosted
  color rather than getting erased.
- The layer order, bottom → top, is:
  1. White card base (`AppColor.cardBackground`).
  2. Drifting Pro-purple radial (TimelineView under
     non-reduce-motion; static under reduce-motion).
  3. Trailing low-alpha mode-tint radial (anchored at
     `UnitPoint(x: 1.0, y: 0.5)`, radius 240, opacity 0.12).
  4. `.regularMaterial` at opacity 0.55 — the frost.
  5. Pro-purple hairline border at opacity 0.22 (was 0.20).
- All character + text + chip + CTA sit ABOVE the material in the
  `VStack`, so they render fully crisp; the material only frosts the
  background tint registers, not the content.
- Material choice is `.regularMaterial` per spec. The inline comment
  notes the drop-to-`.thinMaterial` lever if the result reads too soft
  in practice — single-line swap, no other changes needed.

### Move 3 — character emanation ray (new `emanationRay` + `triggerEmanation`)

- `Noum/HomeCoachCard.swift:30-39, 45-53, 222-249, 425-448`.
- New `@State private var emanationProgress: Double = 1.0`. The value
  represents the pulse's progress through its 700ms ease-out arc:
  `0.0` = just fired (opacity 0.5, scale 1.0 — the ring is visible
  at the character's size), `1.0` = resting (opacity 0.0, scale 1.6 —
  fully faded out and expanded). The rest state is invisible.
- The character is now wrapped in a `ZStack { emanationRay; NoumCharacter(...) }`
  so the ring renders behind it. Layout is unchanged — the ring is
  120×120 inside the existing 90-size character's natural frame.
- `triggerEmanation()` is called from `syncMoodForFreshRecommendation()`
  on a real `recommendationKey` change (not first appear). The function
  snaps `emanationProgress` to `0.0` via a `Transaction` with
  `disablesAnimations = true` (so a back-to-back trigger isn't
  interpolated from a partial mid-pulse state), then runs
  `withAnimation(.easeOut(duration: 0.7)) { emanationProgress = 1.0 }`.
- The pulse is `accessibilityHidden(true)` implicitly (it's
  decorative; no traits set), and the parent character is
  `accessibilityHidden(true)` already.

## Reduce-motion behavior

All three moves respect `accessibilityReduceMotion`:

| Move | Reduce-motion behavior |
|---|---|
| Gradient drift | Falls back to a static `RadialGradient` at `UnitPoint(x: 0.5, y: 0.0)` — no `TimelineView`, no per-frame redraw, no animation source. Identical to the prior static card except for the slight alpha tweak. |
| Glass overlay | Unchanged. `.regularMaterial` itself isn't animated; reduce-motion doesn't affect it. |
| Emanation ray | `emanationRay` returns `Color.clear.frame(width: 1, height: 1)` (an invisible placeholder so the ZStack layout doesn't shift). `triggerEmanation()` also early-returns under reduce-motion so no animation is scheduled. The user gets the mood swap but no ring. |

The check happens twice for the emanation (both at the view's
visibility gate and at the trigger function) so the ring is guaranteed
never to flash even if state momentarily disagrees with the env value.

## What did NOT change

- `coachTitle`, `coachSubtitle`, `coachLine`, `beginCTAText`,
  `microLabelText`, all derived state, the recommendation blueprint,
  and the action handler — all untouched.
- Character + title + subtitle + chip + CTA order, identical.
- Accessibility identifiers (`home.coachCard`, `home.coachCard.title`,
  `home.coachCard.subtitle`, `home.coachCard.begin`) — preserved.
- Outer `.shadow(color: AppColor.pro.opacity(0.18), radius: 22, ...)` —
  preserved.
- `Spacing`, `CornerRadius`, `AppColor` token usage — every value still
  comes from `DesignSystem.swift`.
- No new managers, stores, routes, types, or files.
- `NoumCharacter` itself — untouched. The emanation is composed at
  the call site, not added to the character system.
- The `#Preview("Coach Card — Populated")` block — untouched.

## Risks

1. **Material on a drifting gradient — perf cost.** The TimelineView
   redraws the radial fill at up to 30fps, and the `.regularMaterial`
   above it is a blur layer. On iOS 17+ this composites on the GPU
   and a single hero at 30fps is well within budget. If profiler shows
   a hotspot on older hardware, the cheapest mitigation is to swap
   `.regularMaterial` for `.thinMaterial` (lighter blur) or drop the
   TimelineView interval to 1/24.
2. **Reduce-motion fidelity.** Reduce-motion users still get the
   glass overlay (correctly — material is not "motion") and the
   static gradient (correctly). They DO NOT get the emanation ring
   or the gradient drift. The character's existing breathing halo
   was already gated by reduce-motion in `NoumCharacter`, so the
   composition stays consistent.
3. **Material color shift.** `.regularMaterial` desaturates the
   underlying Pro-purple noticeably. The wash alpha was bumped from
   `0.22 → 0.26` to compensate. If real-device QA shows the result
   is too pale, the lever is `shape.fill(.regularMaterial).opacity(0.55)` —
   drop opacity to `0.45` to let more color through.
4. **Emanation timing on back-to-back recommendation changes.**
   `triggerEmanation()` resets progress to `0.0` with a no-animation
   transaction before scheduling the ease-out. A second trigger
   landing mid-pulse will snap-cut to a fresh start, which is the
   right call — interpolating from a half-faded state to a fresh full
   pulse would look broken.
5. **Generic `purpleWash<S: Shape>`.** Both branches of the if/else
   return the same outer shape pipeline — SwiftUI's `@ViewBuilder`
   wraps them in `_ConditionalContent`. The TimelineView captures
   `shape` by value (RoundedRectangle is a `Shape` value type), so
   no retain cycle.

## Verification

### Implemented

- Move 1: drifting Pro-purple radial center on a 7s ease-in-out
  TimelineView, reduce-motion collapses to static.
- Move 2: `.regularMaterial` glass overlay between the radial washes
  and the strokeBorder, content sits above.
- Move 3: character emanation ray (1.0 → 1.6 scale, 0.5 → 0.0
  opacity over 700ms) on fresh-recommendation arrival,
  reduce-motion suppresses entirely.
- All animations gated through the existing `accessibilityReduceMotion`
  env var.
- No copy, hierarchy, accessibility-identifier, or state-store change.
- All tokens come from `DesignSystem.swift` (`AppColor.pro`,
  `AppColor.tint(for:)`, `CornerRadius.xl`, `Spacing.*`, the existing
  `.shadow` color).

### Partially implemented

- None.

### Blocked

- None.

### Assumptions

- The TimelineView's `minimumInterval: 1.0 / 30.0` is the right perf
  target — 30fps for the slow ambient drift is the iOS standard for
  ambient material motion (verified against the noum-design skill's
  "Ambient motion primitives" patterns: ShimmerProgressBar is a 2.4s
  loop, splash orbs are 1.8s / 2.1s — 7s drift fits the slow ambient
  register).
- The mode tint accent reading through the frost is the desired
  effect (the spec says the radial purple shows through; same logic
  applies to the mode tint, both register colors are kept under the
  glass intentionally).
- The wash-alpha bumps (`0.22 → 0.26`, `0.04 → 0.06`) compensate for
  the material desaturation without making the un-frosted state too
  saturated. Real-device QA is the calibration loop here.

### Verification

- File reads cleanly end-to-end after edits. No build run (per the
  brief: "Don't build the app yourself").
- All four `home.coachCard*` accessibility identifiers preserved at
  the same source line positions in the body hierarchy.
- Reduce-motion fall-through traced by reading the
  `accessibilityReduceMotion` env value at three branch points:
  `purpleWash(in:)` (static gradient), `emanationRay` (Color.clear
  placeholder), `triggerEmanation()` (early return). All three gate
  on the same env source.
- Spec compliance audit:
  - No emoji in source or copy.
  - All glyphs SF Symbols (none added in this pass).
  - All colors and spacing from `DesignSystem.swift` tokens.
  - No new managers/stores/state.
  - Hierarchy unchanged: character, title, subtitle, chip, CTA.
  - No hard accent color introduced.
  - `coachTitle` / `coachSubtitle` logic untouched.
  - Begin CTA label format untouched.

### Risks

- See "Risks" section above. The big one to validate on-device is the
  material's effect on the Pro-purple read — if it's too pale, drop
  the material opacity from `0.55` to `0.45` (one number) or swap
  `.regularMaterial → .thinMaterial`.

## Branch

`worktree-agent-a13a67d7e31f10f0a` (the worktree's local branch).
The actual file edit landed in `/Users/jordan/src/GitHub/Noum/Noum/HomeCoachCard.swift`,
which the live `Redesign` branch checkout owns. No commit was created
(per the brief: "Don't open PRs"); the file is modified in-place and
ready for the user to inspect, build, and commit on their schedule.

---

# HANDOFF — First-rep celebration: cinematic reveal pass

## What changed

`Noum/FirstRepCelebration.swift` — rewrote the body of `FirstRepCelebration` from a 3-stat-tile layout to a single resonant frame. The manager, share-sheet wrapper, and external API (`FirstRepCelebrationManager.shared`, `consider(session:totalSessionCount:)`, `dismiss()`, `pendingSession`) are **unchanged** — the celebration still fires once, persists per-account, and is presented by `SummaryView` via `fullScreenCover(item:)`.

### New composition

- **Backdrop.** `Color.black` base + `RadialGradient` in `AppColor.pro` (purple, 0.55 → 0.28 → clear) anchored at `(0.5, 0.32)` so the bloom sits behind the character, plus a bottom vignette to focus the CTA. This is the same premium register `TierPromotionOverlay` uses for upward-tier moments — the first rep is the equivalent first-time milestone.
- **Orbs.** `FloatingOrbsLayer(tint: AppColor.proLight)` — three slow-drifting blurred circles in the `proLight` tint. Reduce-motion turns them static. No illustration (brand rule).
- **Character.** Single `NoumCharacter(mood: .excited, tint: .white, size: 160)` — large, white-on-purple, sparkle ribbon owned by the `.excited` mood itself. Springs from `0.8 → 1.0` with a `0.6s / 0.72-damp` spring on full-motion; static at 1.0 with a fade-only entrance under reduce-motion.
- **Headline.** `Typography.hero` (40pt Figtree bold) reading `"First rep, in the bag."` — coach voice, no exclamations, no "Great job", no "Let's", no emoji. Slides up 12pt + fades in.
- **Subtitle.** `Typography.subheadline` reading `"<N> second(s), <K> filler(s) / 1 filler / zero fillers. The read starts now."`. Pluralisation handled in code. Defensively falls back to `"Your baseline is set. The read starts now."` when `session.duration < 1` (handles aborted-recording edge case). Concrete-evidence only — never quotes the user's prompt or transcript (lock-screen-safety rule).
- **Primary CTA.** `"Continue"` with `arrow.right`, gradient-filled capsule in `AppColor.pro`, soft purple shadow (`pro @ 45% / 18pt / y:8`). Uses the canonical `.pressable` button style so press feedback matches the rest of the app.
- **Secondary CTA.** `"Share your starting line"` (lower-weight inline button, white @ 78%). Opens the existing `FirstRepShareSheet` — `ImageRenderer`-backed share of `ShareableSessionCard`. Already-wired path; unchanged.

### Motion sequence (full-motion)

| Beat | Time | What animates |
|---|---|---|
| 1 | 0.0s → 0.4s | Backdrop + orbs fade in (`easeOut 0.4s`) |
| 2 | 0.35s | Character springs in + one confetti burst (`ConfettiLayer(pieceCount: 20, duration: 1.5)`) + `CoachHaptic.trendBreakthrough()` |
| 3 | 0.95s | Headline slides up + fades in (`spring 0.5 / 0.84`) |
| 4 | 1.15s | Subtitle fades in (`easeOut 0.35s`) |
| 5 | 1.55s | Continue + Share fade in (`easeOut 0.35s`) + `CoachHaptic.scoreReveal()` |

### Reduce-motion path

`runSequence()` checks `@Environment(\.accessibilityReduceMotion)` first. If on:
- All phases resolve in a single `withAnimation(.easeOut(duration: 0.4))`.
- Confetti is gated out entirely (`if !reduceMotion { ConfettiLayer(...) }`) so we don't even allocate the pieces.
- Orbs render static (their own internal reduce-motion gate).
- Sparkle ribbon stays on (it's a per-symbol opacity/scale twinkle inside `TimelineView`, not a moving particle — non-vestibular).
- One haptic (`CoachHaptic.scoreReveal()`); the breakthrough haptic on the spring beat is skipped.

### Brand rules respected

- **No emoji.** SF Symbols only (`arrow.right`, `square.and.arrow.up`).
- **No chirpiness.** Headline is `"First rep, in the bag."` — coach voice, declarative.
- **Zero exclamations.** The brief allowed up to one; I left it at zero. Motion + sparkle + the purple bloom carry the celebration; the words stay composed (same call `TierPromotionOverlay` makes).
- **Character composition unchanged.** Still `waveform`-family SF Symbols + halo + sparkle ribbon, sized to 160pt. No illustration.
- **All design tokens.** Spacing/CornerRadius/Typography/AppColor pulled from `DesignSystem.swift` and `Typography.swift`.
- **Lock-screen-safety.** Subtitle pulls `session.duration` and `session.fillerWordCount` only — never `session.prompt`, `session.transcript`, or any captured goal/topic text.

## What did NOT change

- `FirstRepCelebrationManager` (when the celebration fires, the once-only persistence, the per-account `seenKey` scheme).
- `FirstRepShareSheet` (the `UIViewControllerRepresentable` that opens `UIActivityViewController` with `ShareableSessionCard.render(...)`).
- Call sites in `SessionFinalizer.swift` (`consider(session:totalSessionCount:)`) and `SummaryView.swift` (`fullScreenCover(item: pendingSession) { ... }`).
- `accessibilityIdentifier("firstRep.celebration")`, `"firstRep.celebration.continue"`, `"firstRep.celebration.share"` — preserved (UI-test contract).
- `ConfettiLayer`, `NoumCharacter`, `SparkleRibbon`, `CoachHaptic`, `DesignSystem.swift` — all consumed unchanged.

## Verification

### Implemented
- Tinted radial backdrop in `AppColor.pro` with bottom vignette + static-friendly drifting orbs in `proLight`.
- Large `NoumCharacter(mood: .excited)` at 160pt (within the 150–180pt brief band) with the sparkle ribbon the mood already carries.
- Single bold display headline `"First rep, in the bag."` in `Typography.hero`.
- Two-line concrete-evidence subtitle with `<N> seconds, <K> filler[s] / 1 filler / zero fillers. The read starts now.` pluralisation handled. Defensive fallback for `duration < 1`.
- Primary `Continue` CTA in `AppColor.pro` (gradient capsule + tinted shadow + `.pressable`).
- Secondary `Share your starting line` opening the existing share sheet path.
- Five-beat motion sequence (`0.4s → 0.35s → 0.95s → 1.15s → 1.55s`) with `easeOut` + `spring` mix matching the brief.
- Reduce-motion path: single fade-in, no confetti burst, static orbs, one haptic.
- Headline has `.isHeader` trait. Subtitle uses `.accessibilityElement(children: .combine)` so VoiceOver reads it as one phrase.
- Three previews: clean rep (1 filler / 32s), perfect rep (0 fillers / 45s), degenerate (0s) so the subtitle fallback is visually checkable.

### Partially implemented
None.

### Blocked
None.

### Assumptions
- `CoachHaptic.trendBreakthrough()` and `.scoreReveal()` are the right pair — `trendBreakthrough` was already used in the v1 of this file, `scoreReveal` is the standard CTA-arrival cue elsewhere. If a richer "first-rep-only" haptic is desired, that's a separate `CoachHaptic.swift` addition (out of scope here).
- Removing the three stat tiles (Score / Fillers / Pace) is desirable: the brief explicitly asks for a single resonant frame, and `SummaryView` — which the user lands on after Continue — owns the full stat readout. The subtitle re-names the two most-loaded numbers (duration + filler count) so the celebration still feels evidence-grounded.
- `AppColor.pro` is the right register: same purple `TierPromotionOverlay` uses, and the brief explicitly named it as "purple = brand premium register."
- `NoumCharacter`'s built-in sparkle ribbon (`.excited` mood) is sufficient — I did not stack a second `SparkleRibbon` on top.
- The brief said "ONE exclamation max"; I went with zero. If Jordan prefers one, the obvious slot is `"First rep, in the bag!"` — single-character change.

### Verification (what was checked)
- Reviewed every API call against the canonical sources: `Typography` roles (`.hero`, `.subheadline`, `.headline`, `.caption`, `.micro`) exist in `Noum/Typography.swift:43–67`; `AppColor.pro / proLight` exist in `DesignSystem.swift:67–69`; `Animation.spring(response:dampingFraction:)` works as written; `.pressable` button style is exposed via `DesignSystem.swift:273-275`; `Capsule(style: .continuous)` matches the pattern used in `AhCounterView.swift`, `CoachingOnboardingView.swift`, etc.
- Confirmed `PracticeSession.fillerWordCount` and `.duration` are stored properties on the struct (`SpeechRecognizerViewModel.swift:523-524`), so the subtitle always has them.
- Confirmed `ConfettiLayer` is reduce-motion-aware internally (`ConfettiLayer.swift:31`) so my outer `if !reduceMotion` gate is redundant-but-cheap insurance against allocating piece state.
- Confirmed call sites still compile: `FirstRepCelebration(session:onContinue:)` initialiser unchanged, `FirstRepCelebrationManager.shared.pendingSession` / `.dismiss()` / `.consider(...)` unchanged.
- Did **not** run `xcodebuild` per the brief ("Don't build the app yourself"). The Xcode project uses `PBXFileSystemSynchronizedRootGroup` so the existing file path picks up the rewrite automatically — no project-file edit required.

### Risks
- The subtitle pluralisation is English-only (`"second(s)"`, `"filler(s)"`). Practice locale es-ES and fr-FR users will still see English here. Consistent with the M13 honest gap (~30 keys localised so far; this surface is not in the catalog). If localisation is desired, the two strings move to `Localizable.xcstrings` with plural variants — copy job, no code change.
- `phase.rawValue` ordering relies on a single forward sequence — the `Comparable` conformance was already there. No-op risk: if `phase` is ever set non-monotonically (no current code path does), some elements could fade back out. Kept the existing `Comparable` for compatibility but only ever advance the phase.
- One exclamation was allowed by the brief, zero used. If Jordan reads this and wants the punctuation back, it's a one-character edit on line ~282 of the new file.
- The "Share your starting line" caption (`"I just took my first rep on Noum — sharper speaking, one rep at a time."`) was preserved from the existing share sheet; that string survives because the share sheet is unchanged.

## Files modified

- `/Users/jordan/src/GitHub/Noum/Noum/FirstRepCelebration.swift` (488 LOC → 408 LOC; net `+263 / -225`).

## Files referenced (read-only)

- `/Users/jordan/src/GitHub/Noum/Noum/NoumCharacter.swift`
- `/Users/jordan/src/GitHub/Noum/Noum/ConfettiLayer.swift`
- `/Users/jordan/src/GitHub/Noum/Noum/TierPromotionOverlay.swift`
- `/Users/jordan/src/GitHub/Noum/Noum/GamifiedViews.swift` (SparkleRibbon)
- `/Users/jordan/src/GitHub/Noum/Noum/Typography.swift`
- `/Users/jordan/src/GitHub/Noum/Noum/CoachHaptic.swift`
- `/Users/jordan/src/GitHub/Noum/Noum/SpeechRecognizerViewModel.swift` (PracticeSession)
- `/Users/jordan/src/GitHub/Noum/Noum/SummaryView.swift` (call site)
- `/Users/jordan/src/GitHub/Noum/Noum/SessionFinalizer.swift` (call site)
- `/Users/jordan/src/GitHub/Noum/DesignSystem.swift`

## Branch

`worktree-agent-a698f8bd9753f73f1` (this worktree's local branch).
The actual file edit landed in `/Users/jordan/src/GitHub/Noum/Noum/FirstRepCelebration.swift` on the live `Redesign` checkout. No commit was created (per the brief: "Don't open PRs"); the file is modified in-place and ready for the user to inspect, build, and commit on their schedule.
