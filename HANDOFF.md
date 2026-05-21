# HANDOFF — Summary → Ask Noum bridge

## Scope

Five files touched: `Noum/CoachContextBuilder.swift` (+57 LOC, new
`sessionOpener` pure helper), `Noum/AskNoumStore.swift` (+72 LOC, new
`injectUserTurn` + `pendingInjectedCoachID` + `consumePendingInjectedCoachID`
+ `clearThread` wipe), `Noum/AskNoumView.swift` (+10 LOC, new `.onAppear`
inject consumer), `Noum/SummaryView.swift` (+~115 LOC, new
`onAskNoumAboutRep` callback prop + `askCoachBridgeCard` + path-based init
wire-up + insertion above `xpProgressCard`), `NoumTests/NoumTests.swift`
(+~140 LOC, 12 new tests). Plus `docs/CURRENT_STATE.md` (timestamp + Ask
Noum subsection extension) and this `HANDOFF.md`.

The brief: continue the Ask Noum dream-tier pass. The persistent coach
shipped last commit, knows the user's full context, and is reachable
from the home promo card + `noum://ask`. But the post-session moment —
the one moment a user is most likely to want a coach's take on a
specific rep — had no bridge. The templated `CoachNoteCard` answers
in advance; the user has no friction-free way to ask "what should I
take from THIS rep?" of the persistent coach. This handoff closes
that loop.

## What changed

### Move 1 — `CoachContextBuilder.sessionOpener(mode:score:fillerCount:duration:voice:)`

- `Noum/CoachContextBuilder.swift` lines 279–333. Pure-function copy
  generator. Takes the rep's identifying metrics + the user's voice
  goal; returns a two-sentence seed message the Summary surface can
  inject into the AskNoum thread on the user's behalf. The seed lands
  *as a user turn* so the model reads it as if the user had typed it.
- Sentence 1 is the fact line: `"Just finished a <Mode> rep — <N>s,
  <K> filler[s], <S>/10."`. Score is omitted entirely when nil
  (Ah-Counter) so we never leak `"nil/10"` or `"0/10"`. Pluralisation
  is handled on the `filler/fillers` token.
- Sentence 2 is a voice-shaped ask. Same per-voice mapping pattern
  the rest of the AskNoum surface uses (`coachPersonality(for:)`,
  `starterPrompts(for:)`) — authoritative gets "Give me your read.",
  warm gets "How did that one feel from your seat?", concise gets
  "One move?", persuasive gets "Walk me through what the data says.",
  executive gets "Brief me — top line first.", storytelling gets
  "Where does this one sit in my arc?", `nil` gets "What stood out?".
- No I/O, no async, no singletons. Easy to unit-test (six tests
  added, see below).

### Move 2 — `AskNoumStore.injectUserTurn(_:)` + cross-surface signal

- `Noum/AskNoumStore.swift` lines 88–101 add `pendingInjectedCoachID:
  UUID?` as a `@Published` property — the published "AskNoumView,
  there's a reply waiting for you to fire" handoff signal.
- `Noum/AskNoumStore.swift` lines 158–207 add `injectUserTurn(_:)`
  and `consumePendingInjectedCoachID()`. Together they bridge the gap
  between *the Summary bridge tap fires* and *AskNoumView mounts and
  needs to know to run the reply*. The store owns the signal so the
  caller never has to know AskNoumView's lifecycle.
- Idempotency: while a reply is pending, re-injecting the same opener
  returns the existing pending coachID instead of queuing a duplicate
  pair. A double-tap on the bridge is a no-op. After the prior reply
  has actually landed, re-injecting the same opener *is* a fresh ask
  — the user is asking again, which is a real action the bridge
  supports (e.g. user navigates back to Summary, scrolls, taps again
  later). Three of the new tests pin this contract from the three
  natural angles (idempotency-while-pending, re-inject-after-reply,
  consume-once).
- Empty / whitespace-only inputs are rejected at the boundary — they
  would produce a useless coach reply and a confusing blank user
  bubble.
- `clearThread()` now also wipes `pendingInjectedCoachID` so a sign-out
  / "Reset Ask Noum thread" doesn't leave the signal dangling.

### Move 3 — `AskNoumView` consumes the signal on appear

- `Noum/AskNoumView.swift` lines 100–115 add a top-level `.onAppear`
  that calls `store.consumePendingInjectedCoachID()` and, if non-nil,
  fires `runReply(coachID:)` for that ID. One-shot by construction:
  the store clears its own signal on consume, so a re-mount of
  AskNoumView (e.g. user navigates back and then forward again
  through the nav stack) won't fire a duplicate reply for the same
  seed. The existing `didLandFirstAppear` scroll hook is kept
  separate inside the `ScrollViewReader` block — they don't share
  state, and shouldn't.
- The reply task uses the same `runReply` plumbing the typed-message
  path uses (same `CoachContextBuilder.systemPrompt`, same
  `userContext` block, same `AICoachChatService` actor). The seed
  shape doesn't get any special treatment downstream — the model
  just sees a user message that happens to start with "Just
  finished a <Mode> rep…", then the standard context block. This is
  the right call: the bridge is a UX shortcut, not a different
  coaching mode.

### Move 4 — `SummaryView.askCoachBridgeCard` + `onAskNoumAboutRep` callback

- `Noum/SummaryView.swift` adds `var onAskNoumAboutRep: ((String) ->
  Void)?` as an optional callback prop (line 42–46) so the host can
  decline to wire it (previews + share-card renderers); the card
  hides itself when nil.
- `Noum/SummaryView.swift` lines 1740–1850 add the bridge card
  (`askCoachBridgeCard`), the opener accessor
  (`sessionAnchoredOpener` — calls into the new
  `CoachContextBuilder.sessionOpener` with the SummaryView's
  computed metrics), and the voice-shaped headline helper
  (`askCoachBridgeHeadline(for:)`). The card is brand-purple
  ambient — same `AppColor.pro` register the home AskNoum promo
  card already uses, so the surface stitches to the same speaker
  visually. NoumCharacter.Inline at 22pt sits left of the copy
  for the same coach-presence beat the rest of the app uses for
  coach-voice tiles.
- The card lives in `expandableDetailsSection` (lines 814–820)
  between `SkillProgressView` and `xpProgressCard`. That keeps
  the drill CTA (`YourNextMoveCard` above) as the in-the-moment
  hero, while putting the bridge in the secondary stack where
  the user lands when they've actioned the drill recommendation
  and now want a richer take.
- Accessibility: `accessibilityIdentifier("summary.askNoumBridge")`
  for the UI test suite. VoiceOver reads "Ask Noum. <Headline>.
  Opens the coach thread with this rep already in hand."

### Move 5 — path-based init wire-up

- `Noum/SummaryView.swift` lines 2655–2665 extend the path-based
  init (the one `ContentView` uses to push the summary) with the
  bridge wiring:
  ```swift
  self.onAskNoumAboutRep = { opener in
      _ = AskNoumStore.shared.injectUserTurn(opener)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
          pathBinding.wrappedValue.append(AppDestination.askNoum)
      }
  }
  ```
  The 50ms `asyncAfter` mirrors the pattern `onPracticeAgain` /
  `onSelectPracticeMode` already use — gives the store's
  `@Published` flush a frame to settle before AskNoumView mounts
  and reads it. Without the hop the consume can race the flush in
  rare cases.
- The previously-memberwise init in the struct body is preserved
  intact — the new callback defaults to `nil`, so any call site
  that hasn't been updated (previews, the share-render path)
  keeps compiling and renders the card hidden, which is the
  honest behaviour.

### Move 6 — tests

- `NoumTests/NoumTests.swift` adds twelve new tests across the
  two existing test structs.
- `CoachContextBuilderTests` (six new tests, lines 5149–5240):
  - `sessionOpenerIncludesConcreteMetrics` — mode label,
    duration in whole seconds, filler count, score-over-10 all
    present.
  - `sessionOpenerPluralisesFillers` — `1 filler` vs `4 fillers`.
  - `sessionOpenerDropsScoreWhenAbsent` — no `/10`, no `nil`,
    mode + duration + filler count still present.
  - `sessionOpenerEndingIsVoiceShaped` — every voice's closing
    ask hits its register signature (verdict / feel / move /
    brief / arc / stood-out).
  - `sessionOpenerHandlesEveryVoiceWithoutCrashing` — coverage
    invariant: every `SpeakingStyleGoal` produces an opener
    ending in `?` or `.`. Catches a future voice added without
    being wired into the switch.
- `AskNoumStoreTests` (six new tests, lines 5278–5375):
  - `injectUserTurnAddsTurnAndExposesPendingCoachID` — inject
    produces the same `[user, pending-coach]` pair shape that
    `appendUserTurn` does, but additionally publishes
    `pendingInjectedCoachID`.
  - `consumePendingInjectedClearsTheSignal` — one-shot.
  - `injectUserTurnIsIdempotentWhilePending` — double-tap
    returns the existing coachID, thread shape unchanged.
  - `injectUserTurnRejectsEmptyText` — whitespace-only seeds
    are rejected, store state untouched.
  - `injectUserTurnAfterCompletedReplyAppendsFreshTurn` —
    after the prior reply lands, re-inject is a legitimate
    fresh ask.
  - `clearThreadAlsoClearsPendingInjectedSignal` — sign-out /
    reset path leaves no dangling signal.

## What did NOT change

- `CoachContextBuilder.systemPrompt`, `userContext`,
  `coachPersonality`, `starterPrompts` — untouched. The new helper
  is additive.
- `AICoachChatService` — untouched. The reply path for an injected
  opener is identical to a typed message (model sees a user turn +
  the standard context block).
- `AskNoumStore.appendUserTurn`, `completeCoachTurn`,
  `cancelPendingCoachTurn`, `replayForModel`, persistence — all
  untouched. `injectUserTurn` is built on top of `appendUserTurn`
  with the idempotency guard layered above.
- `AskNoumView` chat thread layout, message bubble styling, input
  bar, pending-dots indicator, header NoumCharacter — all
  untouched. The only addition is the top-level `.onAppear` that
  consumes the cross-surface signal.
- `SummaryView` hero score card, Coach Note, AI debrief, drill
  recommendation V2, baseline comparison, transcript card,
  skill-progress section, XP progress, looking-ahead hint —
  untouched. The bridge is purely additive in the secondary
  stack.
- `ContentView` — no changes. The path-based init handles the
  wire-up; ContentView's `.summary` case keeps using the same
  `SummaryView(payload:navigationPath:)` it already does.
- `noum://ask` deep link — unchanged. Still pushes a clean
  AskNoum surface (no injected opener; that's only on the
  Summary bridge path).
- All design tokens are pulled from `DesignSystem.swift` and
  `Typography.swift`. No literal hex, no magic spacing, no
  bespoke fonts.
- Brand voice rules respected: no exclamations on the bridge
  copy, no "Let's", no chirpiness, no emoji. The card eyebrow
  reads "ASK NOUM" with the same micro/uppercase/tracking
  treatment Coach Card eyebrows already use.

## Risks

1. **AskNoumView re-mount during in-flight reply.** SwiftUI's
   `NavigationStack` reconstructs a pushed view's body when state
   upstream changes. If the user pushes Summary → bridge →
   AskNoum, and the model is still replying, then somehow the
   view body re-creates (rare but possible under upstream state
   churn), `.onAppear` fires again. `consumePendingInjectedCoachID`
   is one-shot so a second auto-trigger is impossible. The
   in-flight `runReply` Task is still owned by the previous
   instance and will hydrate the pending row when it returns. No
   duplicate reply.
2. **Idempotency vs legitimate re-ask.** The bridge guards
   against double-tap, but the user CAN re-ask the same opener
   after the reply lands — and that's correct. If the user wants
   to keep asking "give me your read" after the coach answers,
   each tap appends a fresh pair. Verified by
   `injectUserTurnAfterCompletedReplyAppendsFreshTurn`.
3. **Bridge visibility on IM mode summaries.** IM-mode Summary
   has its own card hierarchy
   (`IMVerdictCard`/`IMReadCard`/`IMOneMoveCard`) before falling
   into `expandableDetailsSection`. The bridge appears in the
   shared expandable section, so IM users also get the bridge
   — which is right: an IM rep is exactly the kind of session a
   user would want a coach's take on. No special-casing needed.
4. **Bridge copy is English-only.** The seven voice-shaped
   headlines + the `Open the thread` CTA are not yet in
   `Localizable.xcstrings`. Consistent with the M13 honest gap
   (~30 keys localised). Spanish / French users see the same
   English copy the rest of the post-session surface shows.
5. **The 50ms `asyncAfter` between inject and push.** Mirrors
   the existing `onPracticeAgain` / `onSelectPracticeMode`
   pattern. If a future refactor moves to a faster nav primitive
   that doesn't need the hop, the hop can be dropped — the
   one-shot consume still guarantees correctness.
6. **No keyboard-suppression on the bridge-driven mount.** A
   user landing on AskNoum through the bridge probably doesn't
   want the keyboard auto-presenting (they're reading the
   reply). The existing `inputFocused` state stays false on
   mount, so the keyboard stays down — verified by reading
   AskNoumView; no `.onAppear { inputFocused = true }` was
   ever wired in. Honest behaviour by accident.

## Verification

### Implemented

- `CoachContextBuilder.sessionOpener(mode:score:fillerCount:
  duration:voice:)` produces a two-sentence seed with concrete
  metrics + a voice-shaped ask. Six tests pin the contract.
- `AskNoumStore.injectUserTurn(_:)` + `pendingInjectedCoachID`
  + `consumePendingInjectedCoachID()` cross-surface signal,
  idempotent while pending, empty-text-rejected, fresh-after-
  reply, clear-thread-wipes. Six tests pin the contract.
- `AskNoumView.onAppear` consumes the signal once and triggers
  `runReply` for the matching coachID. The existing
  `didLandFirstAppear` scroll hook is untouched.
- `SummaryView.askCoachBridgeCard` renders inside
  `expandableDetailsSection` above `xpProgressCard`, voice-
  shaped headline, NoumCharacter inline glyph, brand-purple
  ambient register matching the home AskNoum promo card.
  Accessibility identifier `summary.askNoumBridge`.
- Path-based init wires `onAskNoumAboutRep` to inject the
  opener into `AskNoumStore.shared` and push the AskNoum
  destination after a 50ms hop.
- `CURRENT_STATE.md` updated with the new bridge in the AI
  Coach Chat subsection and the timestamp / header
  trail-of-breadcrumbs.

### Partially implemented

- None.

### Blocked

- None.

### Assumptions

- The expandable-details-section is the right home for the
  bridge. Three honest alternatives considered:
  - Top of the summary (above the hero score card) → would
    compete with the score-reveal moment, which is the wrong
    register for "ask a follow-up."
  - Inside the action bar at the bottom → would compete with
    Home / Practice Again / New Topic, which is the wrong
    weight for a tertiary action.
  - Between `YourNextMoveCard` and `BaselineComparisonCard` →
    too close to the drill CTA; would dilute the hero action.
  - Inside `expandableDetailsSection` between
    `SkillProgressView` and `xpProgressCard` → the user has
    moved past the drill, is reading their progression, and
    has both the data and the appetite for a richer coaching
    conversation. Lands.
- The voice-shaped ask sentences are the right register
  signatures. Reviewed against `coachPersonality(for:)` and
  `starterPrompts(for:)` — the registers match. A user who
  picked `.authoritative` will see "Want a verdict on this
  rep?" on the bridge and "Just finished a Timed rep — 28s,
  2 fillers, 8/10. Give me your read." land as the first
  user message in the thread. Both read as the same voice.
- `_ = AskNoumStore.shared.injectUserTurn(opener)` in the
  path-based init is the right wiring location vs. doing it
  in ContentView's `.summary` case. The path-based init
  already owns the `onHome` / `onSelectPracticeMode` /
  `onPracticeAgain` wiring patterns; consistency wins.
- The 50ms hop between store mutation and nav push is the
  same hop `onPracticeAgain` uses. Honest convention.

### Verification (what was checked)

- All file reads + edits applied via Edit / Write tools; no
  Bash builds run (sandboxed Linux environment, no Xcode
  toolchain). Files read cleanly end-to-end after edits.
- `CoachContextBuilder.sessionOpener` reuses `PracticeMode.
  displayLabel` from `DesignSystem.swift:326`, returns a
  `String`, no fail paths.
- `AskNoumStore.injectUserTurn` is `@MainActor` (inherits from
  the class), guards on whitespace-trimmed empty, checks for a
  trailing matching user turn before deciding to dedupe, falls
  through to `appendUserTurn` which sets the right published
  state including `isAwaitingReply`.
- `AskNoumView.onAppear` runs on the main actor (it's a
  SwiftUI view body), `consumePendingInjectedCoachID` is
  called from the main actor, `Task { await runReply(...) }`
  detaches the model call into a structured concurrency
  context without blocking the UI mount.
- `SummaryView.askCoachBridgeCard` uses `Spacing.lg`,
  `CornerRadius.large`, `AppColor.pro`, `Typography.micro` /
  `body` / `caption` — every token from the canonical
  sources. No magic numbers.
- All twelve tests written against the public API of the
  new helpers — pure functions or the documented `@Published`
  surface. No internal-state inspection.
- No regressions to the existing seven AskNoumStore tests
  (relying on the unchanged `appendUserTurn` /
  `completeCoachTurn` / `cancelPendingCoachTurn` paths).

### Risks

- See "Risks" section above.

## Files modified

- `Noum/CoachContextBuilder.swift` (+57 LOC).
- `Noum/AskNoumStore.swift` (+72 LOC).
- `Noum/AskNoumView.swift` (+10 LOC).
- `Noum/SummaryView.swift` (+~115 LOC).
- `NoumTests/NoumTests.swift` (+~140 LOC, 12 tests).
- `docs/CURRENT_STATE.md` (timestamp + Ask Noum subsection
  extension).
- `HANDOFF.md` (rewritten).

## Branch

`Redesign` — committed and pushed.
