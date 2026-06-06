# Run: 2026-05-20 · branch:Redesign · M14 goal-aware verdict copy closes the last copy edge

The last open M14 verdict-copy edge from `docs/VISION.md` ("Evaluation *weighting* (scoring + verdict copy beyond the momentum line) is still goal-blind") is closed on the copy side. Three Coach Note lines — leverage, next step, and drill rationale — now carry a voice-alignment clause when the session's primary focus is in the goal's `alignedSkillAreas`. Restraint contract matches the existing momentum enrichment: silent on off-goal focus, silent when no goal is set.

## Mode
Linux blind — no simulator, no Xcode. All changes flagged for visual verification on the next local run.

## What shipped

| File | Change |
|---|---|
| `Noum/FeedbackEngine.swift` | Added `enrichLeverageWithStyleAlignment(_:primaryFocus:styleGoal:)` and `enrichNextStepWithStyleAlignment(_:primaryFocus:styleGoal:)` — same shape as the existing `enrichMomentumWithStyleAlignment`. Wired both into the Layer 3 style-lens block of `VerdictEngine.generate(...)`. Extended `VerdictEngine.drillRationale(...)` with an optional `styleGoal: SpeakingStyleGoal?` parameter; refactored the switch into a private `baseDrillRationale(...)` helper so the goal-aware suffix is the only new branch. |
| `Noum/FeedbackEngine.swift` | `DrillEngineV2.recommend(...)` now passes its `styleGoal` argument through to `VerdictEngine.drillRationale`. |
| `Noum/SummaryView.swift` | The fallback `coachNote` (used before `SessionFinalizer`'s richer pass lands) now passes `styleGoal: coachingProfileStore.profile?.speakingStyleGoal.title` so the goal-aware enrichments fire on the pre-finalizer render too. |
| `NoumTests/NoumTests.swift` | Nine new `VerdictEngineTests` cases lock the contract on all three new surfaces — aligned voice mentions the voice, off-goal focus stays silent, missing goal stays silent. |
| `docs/CURRENT_STATE.md` | Header trail-of-breadcrumbs updated to include "goal-aware leverage + next step + drill rationale closes the verdict copy edge". |
| `docs/VISION.md` | The "underweight" paragraph now reflects that copy is closed end-to-end; only scoring weighting remains as the open edge. |

## API additions

```swift
// Goal-aware leverage line (new private helper)
private static func enrichLeverageWithStyleAlignment(
    _ leverage: String,
    primaryFocus: SkillArea,
    styleGoal: String
) -> String

// Goal-aware next-step line (new private helper)
private static func enrichNextStepWithStyleAlignment(
    _ nextStep: String,
    primaryFocus: SkillArea,
    styleGoal: String
) -> String

// Goal-aware drill rationale (parameter addition, default = nil)
static func drillRationale(
    for skillArea: SkillArea,
    fillerCount: Int,
    wpm: Double,
    duration: TimeInterval,
    wordCount: Int,
    categoryRatings: [String: String],
    styleGoal: SpeakingStyleGoal? = nil
) -> String
```

## Voice clause shape (consistency check)

Three sister clauses appear at the *end* of their respective lines, separated by a single space:

| Surface | Clause |
|---|---|
| Momentum (existing) | `That's the work your <voice> depends on.` |
| Leverage (new) | `These are the moves that build your <voice>.` |
| Next step (new) | `This is direct work on your <voice>.` |
| Drill rationale (new) | `This drill targets the foundation of your <voice>.` |

Each is short (~6–9 words). Voice label is the canonical `SpeakingStyleGoal.shortVoiceLabel` (e.g. "warm voice", "authoritative voice", "executive presence" — the last one isn't a word that takes "your" comfortably; we pass through unchanged so the resulting copy is "your executive presence" which reads naturally).

## Restraint contract (locked by tests)

- Aligned focus + goal set → clause appears.
- Off-goal focus + goal set → no clause. No fake "moving toward your voice" inventions when the data doesn't support it.
- No goal set → no clause anywhere. The existing `goalAwareMomentumSkippedWhenNoGoalSet` test guarded this for momentum; new sister tests guard it for leverage / next step / drill rationale.

## Surfaces needing visual verification

The new clauses land in the Coach Note card on `SummaryView`. To eyeball the change, capture a session in each of these conditions and compare:

1. **TimedPracticeView → SummaryView, `concise` voice goal, primary focus = conciseSpeaking.**
   Expected: Coach Note "Next step" line ends with `This is direct work on your concise voice.`
   Expected: Coach Note "Leverage" line ends with `These are the moves that build your concise voice.`

2. **TimedPracticeView → SummaryView, `authoritative` voice goal, primary focus = openingStrength.**
   Expected: Drill rationale (the bullet inside the drill card) ends with `This drill targets the foundation of your authoritative voice.`

3. **TimedPracticeView → SummaryView, `warm` voice goal, primary focus = structure.**
   Expected: No voice clause anywhere (warm doesn't align with structure). This is the restraint test — confirms we don't fake personalization.

4. **TimedPracticeView → SummaryView, no goal set (anonymous user / onboarding skipped).**
   Expected: No voice clause anywhere in the Coach Note or drill card.

The four conditions cover every code path; if all four render correctly, the restraint contract is verified visually.

## VISION gap closing (estimate)

The M14 "goal-aware loop" was tracked as ~95% closed in the previous handoff (every *display* surface — pre-rep banner, mid-rep HUD, momentum line, profile ring, home chip, looking-ahead chip — read the voice goal, and the *picker* read it too). The remaining 5% was the rest of the verdict copy. This change closes that — every line of the Coach Note now speaks the user's chosen voice when there's real signal to support it.

What remains as the *single* open edge under M14:
- **Evaluation scoring weighting** inside `BaselineEngine.score(...)`. Today the 0–10 score is voice-blind. A future pass could weight goal-aligned dimensions more heavily (e.g. a "concise" voice user gets a small bonus for tight delivery / a small penalty for long rambling). Risk: shifts user scores mid-stream, needs care. Out of scope for this change.

Operational M14 work (Firestore rules deploy, hosted privacy URL, TestFlight build) is still pending and requires Mac / cloud creds — none possible from Linux blind.

## Branch + commit SHA

Branch: `Redesign`
Commit SHA: will be set on push.

## Risks

- The voice clause appears at the *end* of each line. For unusual edge cases where the existing copy ends in a question mark or some structural marker, the appended clause might read oddly. Spot-check above accounts for this on the four main goal/focus combinations.
- `SpeakingStyleGoal.shortVoiceLabel` returns "executive presence" (no "voice" word) for `.executive`. Resulting copy: "your executive presence" — natural, but worth eyeballing in the Coach Note context.
- No backend / persistence changes. Pure rendering logic.
