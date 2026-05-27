# HANDOFF — M24 deferred slate (round 13): the resolved-tone read (the win the drill loop earns)

## Scope

Round 12 (commit `7505d71`) threaded the tone-drill *Adaptation* read into
the two surfaces the user talks to between reps — the Ask Noum chat coach
and the post-rep `CoachReadCard` — so all three surfaces (recommendation
card, chat coach, post-rep note) read the same "is the work landing?"
trajectory. Round 12 named the next move and flagged it #3:

> **Surface the trajectory even when the scenario has recovered above the
> drill bar.** Today both new surfaces only read the trajectory while the
> scenario is still a prescribed drill (sub-40% overall). A scenario that
> climbed from 10% to 60% no longer produces a signal, so the coach stops
> acknowledging the win the moment it's won. A standalone "recently-resolved
> tone" read (the `resolved` analog of `TrendDirection`) would let the coach
> say "your calm tone in Difficult Conversation is solved — it's holding at
> 60%+." Pure-helper work.

This push closes it.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- `IMHistorySummary.toneDrillSignal` — and therefore the next-practice
  recommendation card *and* the round-12 Ask Noum `TONE-DRILL TRAJECTORY`
  section, both gated on it — return `nil` the instant a scenario's
  tone-match rate climbs at or above the 40% bar. That self-clearing is
  correct for the *drill* (a recovered scenario is no longer the
  highest-leverage place to re-rep), but it's wrong for the *coach*: the
  moment the user finally cracks the tone they kept missing is exactly when
  a real coach says "you've got this now," not when they go quiet. A coach
  who spent five sessions on "your calm tone keeps slipping in Difficult
  Conversation" and then never mentions it again the week you fix it has
  failed to close the loop. Now there's a separate read for the win.

## What shipped

### Track 1 — The resolved-tone signal (`IMHistorySummary`)

`Noum/IMHistorySummary.swift`:

- New pure helper `resolvedToneSignal(from:) -> IMToneResolvedSignal?` — the
  `resolved` analog of `TrendDirection` (was a problem, no longer is). It
  scans every scenario and returns the one that has genuinely recovered,
  gated on a deliberately stiff honest-evidence bar:
  - `evaluatedCount >= toneDrillMinEvaluatedReps` (≥3 — same denominator the
    drill signal demands)
  - overall `matchRate >= toneDrillMatchRateThreshold` (0.4 — genuinely out
    of drill territory; **this is what makes it mutually exclusive with
    `toneDrillSignal`**, which fires only strictly *below* 0.4, so the coach
    can never both prescribe and congratulate the same scenario)
  - `progress.direction == .recovering` AND `progress.earlierRate < 0.4`
    (real evidence it *climbed from* a struggle — a tone the user was always
    good at, e.g. 80% from rep one, has an earliest window above the bar and
    is correctly **not** awarded a fake "you fixed it")
  - `progress.recentRate >= toneResolvedRecentRateFloor` (0.6 — the latest
    window is solidly landing, not merely scraping over the drill bar)
  - Selection when several qualify: most solidly held first (highest recent
    rate), tiebreak by evidence (evaluatedCount), then freshest evaluated rep
    — the drill signal's "worst-first" ordering, inverted to "best-first."
  - Reuses the already-tested `toneMatchStats` + `toneDrillProgress`, so it
    inherits their `.imConversation`/scenario filters, missing/whitespace-
    `actualTone` exclusion, oldest→newest ordering, and 4-rep two-window
    floor — no new windowing arithmetic to get wrong.
- New constant `toneResolvedRecentRateFloor = 0.6`, shared with the test
  suite so the boundary is asserted, not guessed.

`Noum/PracticeSupport.swift`:

- New value type `IMToneResolvedSignal` (next to `IMToneDrillSignal`):
  `scenario`, `targetTone`, `matchRate` (current overall, ≥0.4),
  `earlierRate` (was below the bar), `recentRate` (now ≥0.6, the "holding at
  Y%" number), `evaluatedCount`, `windowSize`.

### Track 2 — Ask Noum banks the win (`CoachContextBuilder`)

`Noum/CoachContextBuilder.swift`:

- `userContext(...)` now appends a `RESOLVED TONE` section, computed from
  `IMHistorySummary.resolvedToneSignal(from: sessions)`, right after the
  `TONE-DRILL TRAJECTORY` section (its drilling-still-open analog). Zero new
  parameters — it computes from the `sessions` the function already
  receives, exactly as the trajectory section does. The two sections are
  mutually exclusive by construction (one fires below the bar, one at/above
  it), so the coach never both nags and congratulates the same scenario.
- New pure helper `resolvedToneLine(for: IMToneResolvedSignal) -> [String]`:
  a data line ("Confident tone in Networking: tone-match was 0%, now holding
  at 100% (earliest vs latest reps) — resolved.") plus a guidance clause so
  the model treats it as a closed win, not an open drill. Same terse,
  citeable register as `toneDrillTrajectoryLines`.
- System-prompt intelligence-floor **rule #9**: when `RESOLVED TONE` is
  present, treat it as banked confidence the user can draw on; never
  re-prescribe that drill, never restate the old miss as if still open;
  observed association, never proof a drill caused the change (same honesty
  bar as rules #6–#8).

### Track 3 — Locked the contracts (`NoumTests/NoumTests.swift`)

- `ResolvedToneSignalTests` (8 cases): nil on empty history; nil when still
  below the drill bar (it's a drill, not a win); nil when always-good (no
  struggle to recover from → no fake win); nil when recovered but the recent
  window is below the floor (the honest gap between "improving" and
  "solved"); fires on the canonical climb-from-struggle-to-solid arc (asserts
  scenario/tone/matchRate/earlierRate/recentRate/evaluatedCount/windowSize);
  picks the most solidly held when several qualify; the **mutual-exclusivity
  contract** (a drilling history yields a drill and no resolved read; a
  recovered history yields a resolved read and no drill); and the floor sits
  strictly above the drill bar.
- `ResolvedToneContextTests` (4 cases): `resolvedToneLine` cites "was X%, now
  holding at Y%" + "resolved" + the don't-re-prescribe guidance; `userContext`
  surfaces `RESOLVED TONE` and omits `TONE-DRILL TRAJECTORY` for a
  recovered-and-held history; omits `RESOLVED TONE` (and keeps the trajectory)
  while still drilling; and omits it entirely with no IM history.

### Vision alignment

- **Pillar #4 — Believable progress** and **coach-parity stage #4 —
  Adaptation.** `docs/VISION.md` requires the coach to "compare response
  across multiple attempts and either reinforce, vary, or replace the
  intervention with an explained rationale." Rounds 9–12 taught the coach to
  reinforce / vary a drill *in progress*. This round adds the missing
  terminal state: **retire** the intervention and acknowledge the outcome
  once the response is durable. Without it, "Believable progress" was a
  half-truth — the coach could see you improving but went silent the moment
  you arrived.
- **Anti-goals respected.** No new disconnected AI surface — the resolved
  read is a deterministic helper over the user's own reps; the chat coach
  only *speaks* a fact the helper already owns. No fabricated wins: the
  always-good and the recovered-but-below-floor cases both return `nil`, and
  the whole read is nil below 4 evaluated reps. No causation claim: rule #9
  and the existing prompt rules forbid it. No double-counting: mutual
  exclusivity with the drill signal is structural, not best-effort.

## Files touched

- **Modified:** `Noum/IMHistorySummary.swift` (+`resolvedToneSignal` helper,
  +`toneResolvedRecentRateFloor` constant)
- **Modified:** `Noum/PracticeSupport.swift` (+`IMToneResolvedSignal` type)
- **Modified:** `Noum/CoachContextBuilder.swift` (+`resolvedToneLine` helper,
  +`RESOLVED TONE` section in `userContext`, +system-prompt rule #9)
- **Modified:** `NoumTests/NoumTests.swift` (+12 tests across 2 structs)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief.

The artifact a user can now hold:

**The coach acknowledges the win, then moves on.** Keep missing your calm
tone in Difficult Conversation and the coach drills it (recommendation card),
talks you through the recovery (Ask Noum trajectory), and headlines the climb
after each rep (post-rep note). Cross the line — land it reliably — and the
drilling stops, but instead of silence, the chat coach now banks it: "you
cracked calm in Difficult Conversation — that holds now," and never
re-prescribes a drill you've already passed.

## Future moves

(Updated priority list — round-12 item #3 closed this round; remaining items
carried forward and re-prioritised:)

1. **Graduate the post-rep note from "recovering" to "resolved."** The
   post-rep `CoachReadCard` (branch 0d) reads raw `toneDrillProgress`, which
   is *not* gated on the drill bar — so for a recovered scenario it keeps
   saying "your calm tone is recovering — 0% to 100%" on every subsequent IM
   rep, forever, never graduating to "solved." Threading the resolved read
   into `PostRepCoachNoteInput` (additive fields, same shape as round 12's
   `imToneDrillProgress`) would let the note say the win once and then fall
   through to per-rep metrics. **This needs a self-clearing recency bound**
   (the resolved signal persists as long as the early struggle stays the
   earliest window) so the note doesn't congratulate the same scenario for
   months — design it to fire only while the recovery is recent (e.g. compute
   the read over a trailing window of the last N evaluated reps). Pure-helper
   + additive-input work, but the recency design deserves its own round.
2. **Make the `LookingAheadCard` itself launch the drill.** Today the summary
   card *describes* the prescribed IM drill but isn't tappable. Threading
   `scenario`/`tone` + an `onStart` closure through `SummaryView`'s init and
   rendering a subordinate CTA would complete the loop on the most-seen
   post-rep surface. Deferred: new interactive recommendation UI wants
   real-device QA this build host lacks.
3. **Preserve the just-finished IM scenario/tone on "Practice Again".**
   `SummaryView.onPracticeAgain` re-runs an IM rep with `.imPractice(scenario:
   nil, tone: nil)`, dropping the user back on the scenario grid even though
   `imConversationDetails.setup` carries the exact scenario + tone. Small,
   high-confidence, uses the existing prefill plumbing.
4. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
5. **`coachNoteRevealed` cleanup.** Still risky — animation chain interleaving
   with celebration timing. Worth a dedicated refactor pass with proper visual
   QA (and a real device).
6. **Rate-limiter live refresh.** Make `AIRateLimiter` an `ObservableObject`
   so the Settings AI-usage card AND the `CoachReadCard` daily-budget hint
   refresh mid-view. Low priority.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this
round was compiled or run — not the app, not the test suite. The changes were
written to match the existing, tested patterns line-for-line:
`resolvedToneSignal` reuses the already-tested `toneMatchStats` +
`toneDrillProgress` (it adds no new windowing arithmetic of its own, only a
gate composed of their outputs); `IMToneResolvedSignal` is a plain `Equatable`
value type alongside `IMToneDrillSignal`; the `RESOLVED TONE` section mirrors
the round-12 `TONE-DRILL TRAJECTORY` section's append shape exactly (computed
from the same `sessions`, zero new `userContext` parameters); and
`resolvedToneLine` follows `toneDrillTrajectoryLines`' data-line-plus-guidance
shape. The mutual-exclusivity claim is proven by construction (the drill bar
is a strict `< 0.4`, the resolved bar a `>= 0.4` on the same `matchRate`) and
asserted by `resolvedAndDrillAreMutuallyExclusive`. Before this lands in a
TestFlight build it still wants a real `xcodebuild test` and a glance at Ask
Noum for a test account with a scenario whose tone-match recovered from below
40% to a held 60%+ — to confirm the chat coach banks the win rather than
re-prescribing the drill. Treat the behaviour as designed-for, not observed.
