# HANDOFF — Ask Noum "Keep going" follow-up chips

## Scope

Three files touched: `Noum/CoachContextBuilder.swift` (+~150 LOC,
new `followUpSuggestions(forCoachReply:voice:)` API + nested
`FollowUpTopic` enum + six voice × topic chip catalogues),
`Noum/AskNoumView.swift` (+~70 LOC, new `followUpChips` computed
view, `followUpRow(chips:)` view-builder, FlowLayout-based capsule
chip row mounted under the most-recent coach reply), and
`NoumTests/NoumTests.swift` (+~140 LOC, nine new follow-up tests
inside the existing `CoachContextBuilderTests` struct). Two doc
updates: `docs/CURRENT_STATE.md` trail-of-breadcrumbs + a new
sub-bullet under the Ask Noum section.

The brief: continue from the existing TO-DO, push toward A+ on
the M14 "open the loop" milestone, stay on the `Redesign` branch,
and "make the dream come true." Up to this push, Ask Noum had
three entry points (Home ambient promo, Profile goal-anchored
link, Summary session-anchored bridge) — but once a user was
*inside* the chat, the surface was a respond-and-wait loop. Every
reply landed; the thread sat dead until the user typed. The
empty-state starter prompts existed to remove the friction of
the *first* message — there was no equivalent surface for the
*continuing* conversation. That gap is the engineering content
of this push: surface 2–3 voice-shaped, topic-anchored follow-up
chips beneath the most-recent coach reply so the conversation
keeps moving without forcing the user to author their own
follow-up from scratch.

## What changed

### Move 1 — `CoachContextBuilder.followUpSuggestions(forCoachReply:voice:)`

A new pure-function API on the existing context builder. Takes
the most-recent coach reply text + the user's `SpeakingStyleGoal?`
and returns up to three chip strings. Empty / whitespace-only
reply returns `[]` (defensive — should never happen in practice
because the call site already gates on `!isPending && !text.isEmpty`,
but the function contract is robust).

Architecture:

- **Topic detection** is a deterministic, case-insensitive substring
  walk over the reply text. The first match wins. Order is intentional:
  drill > pause > pace > filler > weekly > generic. The reasoning:
  drills are the most concrete coach recommendation (the user needs
  to know *how to do it*), so they take priority over more general
  framings. Pauses are second-most-concrete. Generic is the floor —
  every reply yields three chips, never zero (unless the reply is
  empty).
- **Detection lexicon** is intentionally narrow:
  - `.drillMentioned` — "drill", "exercise", "try this"
  - `.pauseMentioned` — "pause", "silence", "breath"
  - `.paceMentioned` — "pace", "wpm", "slow", "rush"
  - `.fillerMentioned` — "filler", quoted "um" / "uh"
  - `.weeklyMentioned` — "this week", "next week", "7 days", "seven days"
  - `.generic` — fallback
- **Chip catalogue** is voice × topic. Six voices + nil fallback ×
  six topics = 42 cells, each carrying exactly three chips. Every
  chip is < 60 characters (the test asserts this), brand-voice
  compliant (no exclamations, no "Let's", no emoji — the test asserts
  this too), and matches the register of its sister catalogue
  entries (`coachPersonality`, `starterPrompts`, `sessionOpener`,
  `askNoumProfileLabel`). Authoritative reaches for verdict-shaped
  questions ("How will I know I nailed it?"); warm reaches for
  felt-experience ("What does it feel like when it lands?"); concise
  is clipped ("Show me one example."); storytelling references the
  arc ("Where does this fit in my arc?"); executive uses chief-of-
  staff framings ("Top line: what does success look like?");
  persuasive shows reasoning ("Walk me through the reasoning.");
  the nil fallback is calm, direct, voice-neutral.

The new `FollowUpTopic` enum is `internal` (visible to the test
suite via the same module) but not `public` — there's no other
external consumer.

### Move 2 — `AskNoumView` chip row

The view picks up `followUpChips` (computed `[String]?`) which
returns nil to collapse the row entirely under any of these
conditions:
- a coach reply is in flight (`store.isAwaitingReply`),
- the latest message is not a coach reply (`last.role != .coach`),
- the latest message is pending (`last.isPending`),
- the reply text is empty.

When the conditions are satisfied, it delegates to
`CoachContextBuilder.followUpSuggestions(...)` and renders the
returned strings as capsule chips inside a `FlowLayout` (reused
from `AIWeeklyInsightCard.swift:344` so the chip rhythm matches
the evidence-pills surface visually).

Visual register:
- `Typography.caption.weight(.semibold)` for chip text (quieter
  than the starter prompts which use `Typography.body`).
- `AppColor.pro` text on `AppColor.cardBackground` capsules.
- `AppColor.pro.opacity(0.22)` 1pt stroke — same brand-purple-but-
  whispered register as the existing coach card border.
- `Spacing.sm` horizontal / 6pt vertical padding — capsule reads
  as a tap target without dominating.
- 34pt leading inset on the row + the eyebrow label — aligns with
  the coach card body content past the inline NoumCharacter glyph.
- "KEEP GOING" eyebrow above the chips (`Typography.micro.weight(.bold)`
  uppercased w/ 0.8 tracking) — matches the eyebrow register used
  elsewhere on the surface ("ASK NOUM · <voice>", "STARTERS").
  `.accessibilityHidden(true)` because the per-chip
  `accessibilityLabel: "Follow up: <chip>"` already carries the
  intent for VoiceOver users.
- `.transition(.opacity.combined(with: .move(edge: .top)))` so the
  row fades + drops in when a fresh reply hydrates — reduce-motion
  honored because the surrounding `withAnimation` calls in
  `scrollToBottom` already gate on the env value.

Tap path: each chip is a Button that fires `send(chip)` — the same
path the starter prompts use. The chip text becomes the user's
next turn (appears as a user bubble), and the coach replies
normally. The chip row then re-evaluates on the new reply.

### Move 3 — Nine new tests in `CoachContextBuilderTests`

All inside the existing struct (no new test target, no new file).
The block matches the rhythm of the existing `starterPrompts` +
`sessionOpener` blocks:

1. `followUpSuggestionsEmptyReplyReturnsEmpty` — empty + whitespace-
   only inputs collapse the row.
2. `followUpTopicDetectionFindsDrillFirst` — drill / exercise / "try
   this" all map to drillMentioned; drill wins when both drill and
   pause appear (priority order locked).
3. `followUpTopicDetectionFindsPause` — pause / silence / breath.
4. `followUpTopicDetectionFindsPace` — pace / WPM / rush / slow.
5. `followUpTopicDetectionFindsFillers` — filler + quoted "um".
6. `followUpTopicDetectionFindsWeekly` — this week / next week / 7
   days / seven days.
7. `followUpTopicDetectionFallsBackToGeneric` — replies with no
   detectable anchor still yield generic chips, never an empty row.
8. `followUpSuggestionsEveryVoiceProducesThreeChips` — coverage
   invariant: every voice × every topic = exactly three chips.
   Including the nil-voice path. A future refactor that drops a
   case will fail this test.
9. `followUpSuggestionsAreVoiceShapedForDrillTopic` — voice register
   preserved across topics; authoritative reaches for verdict
   language, warm reaches for felt-experience, concise is shorter
   than authoritative (asserted numerically), storytelling
   references the arc / scene.
10. `followUpSuggestionsRespectBrandVoiceRules` — no exclamations,
    no "Let's", no chip > 60 chars across all voice × topic cells.

### Move 4 — `docs/CURRENT_STATE.md` updated

- Header trail-of-breadcrumbs gets a new entry summarising the
  follow-up chip ship.
- The Ask Noum section's first bullet (the `Noum/AskNoumView.swift`
  description) gains a follow-up chip block — placement matches
  the existing pattern of "describe the surface, then describe
  what's special about it".

## What did NOT change

- `Noum/AskNoumStore.swift` — untouched. Chips ride on top of the
  existing `appendUserTurn` + `completeCoachTurn` plumbing. No
  new published property, no new accessor.
- `Noum/AICoachChatService.swift` — untouched. The model never
  sees the chip text directly; it sees the chip text as a
  user-authored turn (because that's exactly what it is).
- `Noum/ContentView.swift` — untouched. The three entry points to
  Ask Noum are unchanged; only the inside of the chat surface
  evolved.
- `Noum/SummaryView.swift`, `Noum/ProfileView.swift` — untouched.
  The three entry-point catalogues (`askNoumPromoHeadline`,
  `askCoachBridgeHeadline`, `askNoumProfileLabel`) are unrelated
  to the follow-up catalogue and stay siloed by surface register
  (ambient / session-anchored / goal-anchored).
- `Noum/AIWeeklyInsightCard.swift` — untouched. The `FlowLayout`
  defined there is reused, not duplicated.
- Brand voice rules respected: chip catalogue carries no
  exclamations, no "Let's", no chirpiness, no emoji. Locked by
  the `followUpSuggestionsRespectBrandVoiceRules` test.
- Design tokens pulled from `DesignSystem.swift` (`AppColor.pro`,
  `AppColor.cardBackground`, `Spacing.xs`/`.sm`) and
  `Typography.swift` (`Typography.caption`, `Typography.micro`).
  No literal hex, no magic spacing.
- `Localizable.xcstrings` — untouched. Chip copy is English-only
  per the M13 honest gap. The chip catalogue is a natural pick-up
  for a future localisation pass alongside `starterPrompts` and
  `sessionOpener`.

## Risks

1. **Chip row could feel chatty.** Three chips after every reply is
   a lot of new surface area. Mitigated by: chips are visually
   quieter than starter prompts (caption-sized, capsule, brand-
   purple stroke rather than full-row card), only render under the
   most-recent reply (historical replies stay clean), collapse
   under pending / system-notice / empty-reply conditions. If QA
   feedback says they still feel pushy, we can drop to two chips
   per cell with a single-line catalogue edit — no architectural
   churn.
2. **Topic detection is a substring match, not real NLP.** A reply
   like "Don't rush — that's the move" would match `.paceMentioned`
   because of "rush", which is correct intent. A reply like "your
   pause **and** filler patterns are tied" would match `.pauseMentioned`
   because pause is checked first — which is fine; the chips
   shown will be pause-shaped, which is one of the two valid
   directions to take the conversation. Acceptable false-positive
   rate. If the chips start drifting from the conversation in
   practice, the detection layer is the right place to add a
   small priority tiebreaker (e.g. count occurrences, weight by
   sentence position).
3. **Chips don't see the user-context block.** The model gets the
   full baseline / rating / streak / sessions context block on
   every reply — chips don't. So a chip like "How long should a
   pause be?" doesn't know the user already held a 4-second pause
   yesterday. That's intentional: the chip is a *nudge*, not an
   answer. The model's reply to the chip-as-question is where the
   context lands. If a future move wants context-aware chips
   ("Repeat yesterday's 4-second pause"), the chip catalogue
   would need to grow into a function over the same user-context
   block — fair extension, not in scope for this push.
4. **The `FlowLayout` reuse crosses files.** `AskNoumView.swift`
   now depends on a `FlowLayout` defined inside
   `AIWeeklyInsightCard.swift`. Both ship in the same target and
   the layout struct is intentionally project-internal, so the
   cross-file reference is legitimate. If a future move extracts
   `FlowLayout` into `DesignSystem.swift` (it probably should —
   that's where shared layout primitives live), both call sites
   pick it up automatically.
5. **Eight new voice × topic cells could drift in copy quality.**
   The catalogue is 6 voices × 6 topics × 3 chips = 108 strings.
   Coach voice quality across that many cells is hard to spot-
   check exhaustively in code review. Mitigated by: the
   restraint-test asserts the brand-voice rules at the surface
   level; the voice-shape test asserts the register split at the
   sample-cell level; the rest is a copy job in the next coach-
   voice-audit cloud routine.

## Verification

### Implemented

- `CoachContextBuilder.followUpSuggestions(forCoachReply:voice:)`
  exists, returns three chips for every non-empty reply across
  every voice × topic cell + the nil-voice path.
- `CoachContextBuilder.FollowUpTopic` enum has six cases (drill,
  pause, pace, filler, weekly, generic). `detectFollowUpTopic(in:)`
  is order-sensitive and tested.
- `AskNoumView.followUpChips` collapses under all four documented
  conditions (in-flight, non-coach last message, pending, empty).
- `AskNoumView.followUpRow(chips:)` mounts beneath the latest
  coach reply, lays out via the existing `FlowLayout`, fires
  `send(chip)` on tap.
- Nine new tests in `CoachContextBuilderTests` cover empty input,
  topic detection (drill / pause / pace / filler / weekly /
  generic), every-voice-three-chips coverage, voice-shape register
  split, brand-voice rules.

### Partially implemented

- None.

### Blocked / needs visual QA on device

This push touches a live UI surface; the cloud sandbox can't
build or screenshot. The critical visual checks for QA:

1. **Chip row visual register**: chips read as quieter than the
   starter-prompt rows. Side-by-side compare empty-state vs.
   mid-thread state — starter rows are full-width, follow-up
   chips are capsule, the visual hierarchy should be obvious.
2. **Flow layout wrap behaviour**: on an iPhone SE (smallest
   regular-class width), do three chips wrap onto two rows
   gracefully without truncating any chip's text?
3. **Voice-catalogue spot-check**: set each of the six voices in
   Settings + send a starter prompt that's likely to trigger
   each topic. Verify the chip set reads in-register. The fastest
   spot-check is `concise` voice + "I rambled in my last rep —
   what cut it?" starter (should fire `.fillerMentioned` chips
   in clipped concise voice — "Best filler-cut drill?" / "When
   do mine cluster?" / "Replacement move?").
4. **Tap-and-send round-trip**: tap a chip → user bubble appears
   with the chip text → pending coach reply → reply hydrates →
   new chip row appears (possibly with different topic anchor).
5. **Scroll-to-bottom on chip appear**: when the chips fade in
   after the reply hydrates, does the scroll position track to
   the chip row so the user sees them? The existing
   `onChange(of: store.isAwaitingReply)` handler scrolls to
   "bottom" which is the bottom spacer AFTER the chips, so the
   chips should be in view by construction. Visual verification
   needed to confirm there's no half-second flash where the chips
   are below the fold.
6. **Reduce-motion respect**: with reduce-motion on, does the
   chip row appear without the move-edge transition (it should
   just opacity-fade or appear instantly)? The
   `.transition(.opacity.combined(with: .move(edge: .top)))`
   modifier is governed by the surrounding `withAnimation`
   contexts which already gate on the env value, so this should
   be correct — confirm visually.

### Assumptions

- The most-recent coach reply is the right anchor for the chips.
  Considered: chips beneath every coach reply (rejected — would
  clutter the thread on long conversations), chips above the
  input bar as a global suggestion strip (rejected — they
  wouldn't read as "from this specific reply"). The chosen
  inline-under-last-reply position matches the iMessage / Slack
  "thread continuation" pattern users already know.
- Topic detection priority (drill > pause > pace > filler >
  weekly > generic) is the right order. Reasoning: drills are
  the most concrete coach recommendation, so they take priority;
  pauses are the most concrete delivery mechanic; pace / fillers
  are diagnostic categories; weekly is a framing layer; generic
  is the floor. If the model reply describes a drill that
  involves a pause, the chips should be drill-shaped because
  *executing the drill* is what the user needs help with next.
- Three chips is the right count. Two would feel arbitrary;
  four would crowd. The starter-prompts surface lands on four
  (two voice-specific + two common), but starters need to cover
  more first-message cold-start ground; follow-ups only need to
  keep one specific conversation moving.

### Verification (what was checked)

- All file reads + edits applied via Edit / Write tools; no
  Bash builds run (sandboxed Linux environment, no Xcode
  toolchain).
- `grep` after the CoachContextBuilder edit confirmed the new
  `followUpSuggestions`, `FollowUpTopic`, `detectFollowUpTopic`,
  `followUpChips`, and the six topic-specific catalogue helpers
  (`drillFollowUps`, `pauseFollowUps`, `paceFollowUps`,
  `fillerFollowUps`, `weeklyFollowUps`, `genericFollowUps`) land
  exactly once in the file.
- AskNoumView.swift wiring traced end-to-end: ScrollView mount
  spot → `followUpChips` accessor → `followUpRow(chips:)` view
  → `send(chip)` invocation → existing store.appendUserTurn
  path → existing runReply path. No new state owners introduced.
- Test block follows the existing `CoachContextBuilderTests`
  rhythm (struct member, no new file, no new target). Coverage
  invariant test guards against future voice / topic adds
  drifting out of the catalogue.
- `FlowLayout` symbol confirmed visible in the same Noum target
  via the existing `AIWeeklyInsightCard.swift:344` definition —
  cross-file usage is legitimate, both files compile against
  the same `Layout` protocol.

### Risks

- See "Risks" section above.

## Files modified

- `Noum/CoachContextBuilder.swift` (+~150 LOC — `followUpSuggestions`
  API + `FollowUpTopic` enum + six voice × topic chip catalogues).
- `Noum/AskNoumView.swift` (+~70 LOC — `followUpChips` accessor +
  `followUpRow(chips:)` view-builder + chip row mount under the
  most-recent coach reply).
- `NoumTests/NoumTests.swift` (+~140 LOC — nine new follow-up
  tests inside `CoachContextBuilderTests`).
- `docs/CURRENT_STATE.md` (trail-of-breadcrumbs entry + Ask Noum
  section sub-bullet).
- `HANDOFF.md` (rewritten — this file).

## Branch

`Redesign` — committed and pushed per the brief. The user
explicitly requested work on the Redesign branch ("ensure
working on the redesign branch too (very important)"). All
M14 commits land here; this push continues that pattern.
