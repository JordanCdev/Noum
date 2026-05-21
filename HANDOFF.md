# HANDOFF — Goal-aware live UI extended to every practice mode

## Scope

Four Swift files touched: `Noum/VoiceAnchorBanner.swift` (+13 LOC, new
`resetsBetweenReps` flag), `Noum/SuddenDeathPracticeView.swift`
(+24 LOC, new HUD overlay + VoiceAnchorBanner inside `liveScreen`),
`Noum/AhCounterView.swift` (+18 LOC, new VoiceAnchorBanner + HUD
overlay), `Noum/IMPracticeView.swift` (+25 LOC, new VoiceAnchorBanner
inside the active conversation column + HUD overlay on the body).
Plus `docs/CURRENT_STATE.md` (header trail-of-breadcrumbs + Stubbed /
placeholder section extension) and this `HANDOFF.md`.

The brief: continue from the existing TO-DO and push toward A+
on the in-flight goal-aware coaching loop. Previously, the
mid-session goal-aware surfaces (`VoiceAnchorBanner` for "what voice
are you working toward" + `LiveEloquenceHUD` chip subtext for
"toward your <voice> voice" on aligned rhetorical moves) only
shipped in `TimedPracticeView`. Three other live practice modes —
SuddenDeath, AhCounter, IM — had no in-the-moment goal touchpoint.
The "Goal-driven coaching feedback in mid-session UI" entry under
"Stubbed / placeholder" in `docs/CURRENT_STATE.md` explicitly flagged
this and `.routines/06_m5_goal_aware_hud.md` sequenced it as steps
3–5 of the closing-the-loop work. This handoff closes those three
steps.

## What changed

### Move 1 — `VoiceAnchorBanner.resetsBetweenReps: Bool = true`

- `Noum/VoiceAnchorBanner.swift` lines 36–55 add an optional
  `resetsBetweenReps` flag, defaulted to `true` so the existing
  `TimedPracticeView` call site keeps its exact behavior with no
  call-site change.
- `Noum/VoiceAnchorBanner.swift` lines 77–86 swap the `else`
  branch of the `.onChange(of: isRecording)` handler from an
  unconditional `resetForNextRep()` to a flag-gated one. When
  `resetsBetweenReps == false`, the banner fires once on the
  first false→true transition per mount and stays "shown
  already" forever — the user gets one anchor per session, not
  one anchor per round / turn.
- Why a flag instead of two structs: the banner copy + styling
  + accessibility label + reduce-motion behavior is identical
  across the two modes. Splitting into two structs would
  duplicate ~50 LOC for a single boolean's worth of difference.

### Move 2 — `SuddenDeathPracticeView` wiring

- `Noum/SuddenDeathPracticeView.swift` lines 55–69 add a
  `.overlay(alignment: .top)` on the outer `ZStack` that mounts
  `LiveEloquenceHUD(styleGoal:)` whenever `phaseGroup == .live`.
  The `phaseGroup` accessor (line 137) maps `.npcTurn`,
  `.userTurnWaiting`, `.userTurnActive`, and `.roundResult` all
  to `.live` so the HUD stays mounted across round transitions
  inside one session — the announced-device set only resets
  when `speechVM.isRecording` actually flips on (start of each
  user turn), which is exactly the contract a per-round
  re-celebration wants.
- `Noum/SuddenDeathPracticeView.swift` lines 397–406 add a
  `VoiceAnchorBanner` inside `liveScreen` directly under
  `topBar`. Passes `resetsBetweenReps: false` — SuddenDeath
  has many rounds inside one session and re-firing the anchor
  each round would dilute the moment.
- The banner reads `coachingProfileStore.profile?.speakingStyleGoal`
  with the same `if let voice = ...` pattern Timed uses. Silent
  when no profile is set — no fake personalization for
  pre-onboarding sessions.
- Setup / countdown / sessionComplete phases do not mount the
  HUD overlay. Result screens stay visually calm; setup is the
  user picking difficulty, not speaking.

### Move 3 — `AhCounterView` wiring

- `Noum/AhCounterView.swift` lines 145–151 add the
  `VoiceAnchorBanner` right under the header card, inside the
  pre-rep scroll column. Default `resetsBetweenReps: true` is
  the right call — AhCounter is one continuous open-ended rep
  per mount; one `isRecording` cycle, one anchor.
- `Noum/AhCounterView.swift` lines 344–355 add the
  `.overlay(alignment: .top)` that mounts
  `LiveEloquenceHUD(styleGoal:)` on the outer ZStack. No
  conditional gate — AhCounter is one phase from mount to
  dismount, and the HUD's own observer self-gates on
  `transcribedText` changes (no transcript → no findings → no
  chip).

### Move 4 — `IMPracticeView` wiring

- `Noum/IMPracticeView.swift` lines 153–166 add the
  `.overlay(alignment: .top)` on the body's outer ZStack that
  mounts `LiveEloquenceHUD(styleGoal:)` whenever
  `isSessionActive && !isEndingConversation`. The gates keep
  setup + ending screens calm; the active conversation column
  is the only place where the user is actually dictating.
- `Noum/IMPracticeView.swift` lines 270–283 add the
  `VoiceAnchorBanner` to the active conversation column,
  between `activeHeaderCard` and `conversationCard`. Passes
  `resetsBetweenReps: false` — IM users dictate several
  replies inside one conversation, and the anchor only needs
  to land once.
- The banner sits above the conversation card so it doesn't
  push the conversation transcript down mid-flow — it shows
  briefly at session start and then quietly fades, leaving
  the conversation card as the visual hero.

### Move 5 — `docs/CURRENT_STATE.md` updated

- Header trail-of-breadcrumbs gets the new bullet so a
  cold-read of the doc tells you what's new since the last
  push.
- The "Stubbed / placeholder" → "Goal-driven coaching feedback
  in mid-session UI" paragraph (lines 753–812) gets a new
  extension block. The earlier text already described the
  Timed-only state; the new block records the extension to
  SuddenDeath / AhCounter / IM, the `resetsBetweenReps` flag's
  purpose, and the per-mode mounting gate (phaseGroup for
  SuddenDeath, isSessionActive for IM).

## What did NOT change

- `Noum/TimedPracticeView.swift` — untouched. The default
  `resetsBetweenReps: true` preserves the existing call site
  semantics exactly. No regression.
- `Noum/LiveEloquenceHUD.swift` — untouched. The chip's
  styleGoal-aware subtext + stroke + shadow already shipped;
  the new call sites just hand it a new `styleGoal:` parameter
  via the existing public API.
- `Noum/CoachingProfileStore.swift`, `Noum/DrillSystem.swift`
  (`SpeakingStyleGoal.alignedEloquenceDevices`, `aligns(with
  device:)`, `shortVoiceLabel`) — untouched. The new surfaces
  read from the same source of truth Timed already reads from.
- All four practice views' core practice loops — untouched.
  The two new overlays are purely additive surfaces; no
  metric pipeline, no scoring, no XP math changed.
- Brand voice rules respected: banner copy is the existing
  "Toward your <voice> voice" — no exclamations, no "Let's",
  no chirpiness, no emoji. Chip subtext is the existing
  "toward your <voice> voice" / "noticed" pair.
- All design tokens are pulled from `DesignSystem.swift` /
  `Typography.swift`. No literal hex, no magic spacing, no
  bespoke fonts. The padding on the HUD overlays (`.padding(
  .top, 4)`) mirrors the Timed overlay exactly so the four
  modes share one visual rhythm.
- `Localizable.xcstrings` — untouched. Banner / chip copy is
  English-only per the M13 honest gap (~30 keys localised).
  Non-English users on these three modes see the same
  English copy Timed has shown for the past two pushes.

## Risks

1. **SuddenDeath HUD remount cost across rounds.** The
   `.overlay` condition gates on `phaseGroup == .live`. Inside
   `.live`, the engine cycles through `.npcTurn` →
   `.userTurnWaiting` → `.userTurnActive` → `.roundResult` → next
   round's `.npcTurn`. All four map to `.live` in `phaseGroup`
   so the overlay stays mounted across the round — `observer`
   keeps its state, `cancellable` keeps its subscription. The
   HUD's `.onChange(of: speechVM.isRecording)` resets the
   announced-device set every time recording flips on, which
   is exactly what we want for per-round re-celebration. If
   SwiftUI does decide to recreate the HUD body across phase
   transitions in some future refactor, the `.onAppear` re-
   subscribes to `speechVM.$transcribedText` — no leak.
2. **AhCounter HUD doesn't gate on `isRecording`.** AhCounter
   is one continuous mount; the HUD's own observer gates
   silently on transcript content. Tested mentally against
   the no-text pre-recording state: the engine returns []
   findings on empty input, the observer enqueues nothing,
   no chip ever shows. Pre-rep is visually calm.
3. **IM HUD on dictated replies vs typed input.** IM in this
   codebase only accepts dictated replies (mic button →
   `speechVM.startRecording`). There's no typed-input path
   that the HUD would have to ignore. If a future move adds
   keyboard input to IM, the HUD will still only react to
   `speechVM.transcribedText` changes — typed input wouldn't
   surface there, so the chip stays silent. Honest by
   construction.
4. **`resetsBetweenReps` is a behavioral flag with no UI
   test.** SwiftUI internal `@State` (`hasShownThisSession`)
   isn't trivially testable from outside the view. The
   contract is small and additive — the existing Timed call
   site keeps its exact behavior because the default is
   `true`. The SuddenDeath + IM paths pass `false`
   explicitly. Visual verification on hardware is the right
   guard rail here; flagged in the verification section
   below.
5. **No double-overlay collision with the existing AhCounter
   toast.** AhCounter's toast surface (lines 307–342) lives
   inside the inner ZStack as a sibling, not as an overlay.
   The new `.overlay(alignment: .top)` is on the outer ZStack
   — it sits *above* the inner content including the toast,
   so a simultaneous "toast + HUD chip" moment would stack
   the chip on top of the toast briefly. Both are top-aligned
   and fade independently; the visual collision window is
   short (chip ~1.8s, toast ~2s) and rare (toast fires on
   milestones, chip on rhetorical detection). Acceptable
   collision risk; if it bites in QA the chip can move to
   `.top` with a `.padding(.top, 60)` to clear the toast.
6. **No `liveActivityCoordinator` interaction.** The HUD
   overlay on SuddenDeath is a pure SwiftUI mount; it
   doesn't touch `liveActivityCoordinator`. Phase changes
   that drive the Dynamic Island are untouched.

## Verification

### Implemented

- `VoiceAnchorBanner` gains `resetsBetweenReps: Bool = true`.
  Default preserves the Timed call site; explicit `false`
  honoured by gating `resetForNextRep()` behind it.
- `SuddenDeathPracticeView` mounts
  `LiveEloquenceHUD(speechVM:styleGoal:)` as a top overlay
  when `phaseGroup == .live`, and `VoiceAnchorBanner(
  styleGoal:isRecording:resetsBetweenReps: false)` inside
  `liveScreen` directly under `topBar`.
- `AhCounterView` mounts the HUD as a top overlay (no
  conditional gate, the observer self-gates on
  transcribedText) and `VoiceAnchorBanner(styleGoal:
  isRecording:)` inside the pre-rep scroll column (default
  reset behaviour).
- `IMPracticeView` mounts the HUD as a top overlay when
  `isSessionActive && !isEndingConversation`, and
  `VoiceAnchorBanner(... resetsBetweenReps: false)` inside
  the active-conversation column between `activeHeaderCard`
  and `conversationCard`.
- `docs/CURRENT_STATE.md` updated with the header trail-of-
  breadcrumbs entry and the Stubbed-section extension.

### Partially implemented

- None.

### Blocked / needs visual QA on device

- Live HUD + banner co-existence has not been visually
  verified in this push (cloud sandbox, no Xcode toolchain).
  The four critical visual checks for QA:
  1. **SuddenDeath**: VoiceAnchorBanner fires once at start
     of round 1, does NOT re-fire on rounds 2/3/4. HUD
     chip fires when rhetoric lands inside a user turn,
     resets at the start of each new user turn.
  2. **AhCounter**: VoiceAnchorBanner fires once when the
     user taps Start. HUD chip fires when rhetoric lands.
     Both surfaces co-exist with the existing milestone
     toast without overlap (rare; documented as acceptable
     risk in Risks #5).
  3. **IM**: VoiceAnchorBanner fires once when the
     conversation activates, does NOT re-fire on each
     dictated reply. HUD chip fires only inside the
     active conversation phase.
  4. **Timed (regression)**: Banner + HUD behaviour is
     unchanged. Banner still re-arms between reps because
     `resetsBetweenReps` defaults to `true`.

### Assumptions

- The HUD overlay belongs above the safe-area inset on
  IMPracticeView, not inside the conversation card. The
  card is a scrolling chat transcript; putting the chip
  inside it would scroll out of view immediately.
- The VoiceAnchorBanner belongs above the conversation card
  on IM (not below), so the chat transcript stays the
  visual hero once the conversation is going. Verified by
  reading the existing `activeHeaderCard` placement — the
  banner slots cleanly between header and chat.
- The banner default of `resetsBetweenReps: true` is the
  right call for new single-rep call sites that may be
  added later. The flag is a downshift, not an upshift —
  multi-rep surfaces opt into the calmer behaviour
  explicitly.
- The HUD overlay padding (`.padding(.top, 4)`) matches
  TimedPracticeView's existing overlay exactly. One
  spacing rhythm across all four modes.

### Verification (what was checked)

- All file reads + edits applied via Edit / Write tools;
  no Bash builds run (sandboxed Linux environment, no
  Xcode toolchain).
- `grep` after each edit confirmed the new call sites land
  exactly once in each target file, with no accidental
  duplication into TimedPracticeView.
- `VoiceAnchorBanner` flag semantics: traced the
  `.onChange(of: isRecording)` handler to confirm the
  `else if resetsBetweenReps` branch is the only path
  that flips `hasShownThisSession` back to `false`. With
  the flag false, the banner is one-shot per mount.
- `phaseGroup == .live` is the right gate for the
  SuddenDeath HUD: confirmed via the
  `private var phaseGroup: PhaseGroup` accessor at line
  137 — `.npcTurn`, `.userTurnWaiting`, `.userTurnActive`,
  `.roundResult` all default to `.live`, so the HUD
  stays mounted across the round.
- `isSessionActive && !isEndingConversation` is the right
  gate for IM: traced `isSessionActive` (line 24, flips
  in `startConversation()` line 961 and resets in
  `endConversation()` line 1000) and `isEndingConversation`
  (set during the wrap-up screen, cleared after summary
  navigation).
- The two new tokens (`Spacing.lg`, `Spacing.sm`) on the
  AhCounter VoiceAnchorBanner are inherited from the
  surrounding `VStack(spacing: Spacing.lg)` — no new
  spacing constants introduced.

### Risks

- See "Risks" section above.

## Files modified

- `Noum/VoiceAnchorBanner.swift` (+13 LOC).
- `Noum/SuddenDeathPracticeView.swift` (+24 LOC).
- `Noum/AhCounterView.swift` (+18 LOC).
- `Noum/IMPracticeView.swift` (+25 LOC).
- `docs/CURRENT_STATE.md` (timestamp + Stubbed-section extension).
- `HANDOFF.md` (rewritten).

## Branch

`Redesign` — committed and pushed.
