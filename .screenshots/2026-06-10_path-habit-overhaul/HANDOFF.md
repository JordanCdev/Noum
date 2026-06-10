# Path page habit-first overhaul — visual verification (2026-06-10)

Branch `ux-overhaul`. Implementation in commits `75db725` + `4c4a46c`
(interleaved with a concurrent agent's commits; see session notes).

## What the shots show
1. **01-journey-top-seeded-night** — improvingIntermediate persona, real
   solar night sky, destination glow on the flag, NoumCharacter walker at
   the 12/21-day frontier, "12 of the last 21 days walked · 4 days" strip.
2. **02-journey-scrolled-full-story** — full new hierarchy: consistency
   strip → Today CTA → "Why you're walking" (provenance-quoted) → Trail
   landmarks (System B demoted, role footnote) → collapsed "Along the way"
   → honesty footer.
3. **03-journey-low-reveal-walker-trailhead** — beginner persona: walker
   large at the trailhead, short cleared strip, overgrowth ahead. No
   clipping at low reveal.
4. **04-journey-reduce-motion** — ReduceMotionEnabled: identical static
   render, no crash.

## Not visually verified (logic-verified only)
- "Along the way" expanded state (needs a tap; simulator was contended by
  a concurrent agent session — rows reuse the pre-existing milestoneRow).
- True day-0 (0 sessions): unreachable without completing coaching-profile
  onboarding by hand; day-0 copy branches are unit-tested
  (JourneyWhyComposer suite + never-punish sweep).
- 21/21 complete state (debug slider requires developer account).
- "Still true?" → GoalRefreshSheet and "Make it yours" → whyNow capture
  sheet presentations (both reuse shipped self-dismissing sheets).

Unit suite at verification time: **2423 passed / 0 failed** (xcresult).
