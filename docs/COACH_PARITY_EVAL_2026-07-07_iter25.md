# Coach-parity eval — iteration 25 (2026-07-07, autonomous `noum2`)

Continuation of the `EXPERT_COACHING_BACKLOG` / coach-parity loop. This run shipped the
top **keyless, collision-safe** believable-memory lever (backlog #9) end-to-end with a
multi-role design workflow behind the copy, refreshed the honest 10/10 answer, and kept
strictly off the contended coach-brain lane.

## Constraints in force this run (why the lane was narrow)
- **A concurrent agent held the coach-brain lane, live.** On arrival, a sibling `claude`
  process was actively running `xcodebuild test` on `CoachContextBuilderTests` /
  `AICoachChatReplyQualityGateTests` / `CoachChatConversationCorpusTests` and had written
  `CoachContextBuilder.swift` + `AICoachChatService.swift` within the prior 5 minutes
  (08:03–08:04). The full uncommitted diff (15 files) is the sibling's in-flight coach +
  arena work — **not touched, not committed by this run.**
- **No `ANTHROPIC_API_KEY`.** The content-read + live-roleplay levers stay key-gated
  (unchanged from iters 22–24). Not a headless lever.
- **Lane taken:** cold, collision-safe UI/copy files only — `HomeCoachCard.swift`,
  `RepEventTrendCard.swift`, `RepEventTrendCopyTests.swift`. All verified cold (mtimes
  Jun 6 – Jul 1, none in the sibling's diff) before editing. Build isolated to
  `./DerivedData/Noum2` so it never contends the sibling's `./DerivedData/Noum` lock.

## Shipped this run (keyless, collision-safe, compile-verified)
**Backlog #9 — positional trend in the Home hero subtitle.** The longitudinal
recurring-position read (`RepEventTrendEngine`: "your fastest stretch keeps landing in the
close, 4 of your last 5 reps that rushed") already fed the coach prompt
(`CoachContextBuilder` POSITIONAL TREND block) and the dedicated `RepEventTrendCard`, but
**never reached the highest-traffic surface.** This threads one vetted line onto the Home
coach card — making the coach's cross-rep memory visible where the user actually looks.

- **Single copy owner, no re-invention.** The Home line is composed by a new
  `RepEventTrendCopy.homeSubtitle(for:)` that **reuses the already-test-locked `headline`**
  (zone/marker as grammatical subject, present-continuous "keeps" — trait-safe by
  construction) and appends only the earned denominator. No parallel copy, no new state,
  no new persistence — a pure projection of the engine's existing output.
- **Honest by construction.** The engine's floors (≥3 reps carried the event AND one zone
  holds a ≥60% super-majority, absolute floor 3) mean a thin-data user never sees it. The
  denominator is always **reps-that-carried-the-event** (`repsWithSignal`), never the
  window size — a unit test locks this so a wiring bug can't turn the line into the exact
  "N of your last M reps" lie the trust rules ban.
- **Placement** (locked by the workflow synthesis): in the `coachSubtitle` cascade BELOW
  BigMoment countdown / cold-start(<3) / case-intervention / landmark-within-reach (more
  time-critical or more concrete, and case-intervention returning first guarantees the
  coach never double-points at one marker in a single line) and ABOVE weekly-rhythm /
  tier-holding / generic-blueprint fallbacks (a named recurring position is more specific
  and more differentiating than a cadence nudge).

### Multi-role design workflow behind the copy
Rather than hand-pick the wording, ran a 14-agent workflow (the roles the task asked for):
**UX writer, veteran communications coach, two end-user personas (everyday-standup-dread
"Maya" + high-stakes-pitch skeptic "Devon"), market/competitive strategist** scored three
candidate lines; an **adversarial trust auditor** then tried to break each; a lead
synthesized the lock.

- **Unanimous:** all five roles ranked the **zone-as-subject** framing first (~9/10).
- **Adversary killed the second-person variant** ("You've rushed the close…") on trait
  framing — "the past-perfect form of the banned trait claim; the trailing 'not a verdict'
  disclaimer concedes the lead clause already read as one." This is exactly the failure the
  reused `headline` avoids structurally, which is why reuse (not the raw workflow string)
  is the shipped answer.
- **Residual risks the panel flagged, and how they're handled:** (1) *length* — omit the
  card's belt-and-braces hedge footer on Home; the zone-subject "keeps" framing is
  trait-safe without it and the fully-hedged card is one tap away (felt-QA: confirm ≤2
  lines on the narrowest width); (2) *repetition fatigue* — future polish, a
  once-per-window gate if the same pattern persists; (3) *denominator wiring* — locked by
  unit test.

## Verification
- `RepEventTrendCopyTests` (4 new Home-subtitle tests + existing copy contract) and
  `RepEventTrendEngineTests` — see the run log. Isolated `./DerivedData/Noum2`.
- Cold-file discipline verified: `git diff --name-only` on the three shipped files is
  disjoint from the sibling's 15-file coach/arena diff.

## §5 — The honest 10/10 / A* answer (unchanged, and it is a feature)
Restating for this run because the task asks for 10/10 "replaces a human coach":

- **(a) By-design refusal — do not chase.** The `.forming` readiness cap, the
  no-transcript-to-chat invariant, and the verbatim-quote gate deliberately hold the
  ceiling below 10. Removing them raises a benchmark number while *lowering* real-world
  credibility — the exact overclaim a senior coach never makes. This is Noum's trust moat.
- **(b) Key-gated capability — real, un-closeable headless.** Content/substance (~4/10)
  and live interactive roleplay (~3/10) are the two axes that genuinely cap parity at
  ~7.6. Both need a keyed LLM (`AICoachChatService.swift:777` is already scaffolded). An
  infrastructure/cost decision for Jordan, not a prompt problem, not a headless lever.
- **(c) Buildable now, keyless — this run's lane.** Visibility of the honest-memory wedge
  and believable-memory depth. #9 (shipped) makes the cross-rep memory legible on Home; it
  lifts *perceived* depth and differentiation, not the structural axes, so it can't alone
  move the headline much past ~7.6–7.8. The headline moves meaningfully only when (b) is
  funded, and it is capped below 10 forever by (a), on purpose.

**Honest limitation statement for Jordan:** the two things standing between Noum and a
"rivals + replaces a coach" claim are both real and both known — a keyed content-read pass
and live roleplay — and neither can be built headless without `ANTHROPIC_API_KEY`. Every
keyless iteration (incl. this one) widens the defensible *honest-memory* wedge the whole
category just vacated; it does not, and by design cannot, remove the (a) cap.

## Backlog delta (remaining keyless, collision-safe — unblocks once the coach lane frees)
- **#1** Flip `AutoGuidedFirstRep` default-ON — the acquisition/first-rep lever, path to
  A*; gated on on-device felt-QA (do NOT flip blind).
- **#3** Private-by-design trust strip (`ProfileView` `coachLoopReadinessCard` + onboarding)
  — scoped claim only ("analyzed here, not uploaded to a chat/roleplay model" + "every
  quote verbatim-verified"); NOT a broad "nothing leaves your device".
- **#4** Stated-stance honesty line pre-rep-5 (`HomeCoachCard`/`HomeSignalGate`).
- **#8** Case-history multi-entry timeline (`CaseReviewCard` renders only `.last` today).
- **#7** Thread built IM prep prompts into IM mode (`PrepSessionView:246`).
