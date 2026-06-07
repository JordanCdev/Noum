# Noum handover

Updated: 2026-06-08
Branch: `ux-overhaul`

This file is for Claude or any follow-on agent picking up the Noum UX/value
overhaul cold. It is intentionally generic and source-linked so it can survive
handoffs without relying on the conversation that produced it.

## Read first

Required local docs:

- `docs/VISION.md`
- `docs/CURRENT_STATE.md`
- `docs/UX_VALUE_OVERHAUL_HANDOFF_2026-06-07.md`
- `docs/UX_VALUE_OVERHAUL_ROADMAP.md`
- `docs/UX_RENDERED_REVIEW.md`

Current milestone served: UX/value overhaul moving toward the coach-parity
standard in `docs/VISION.md`.

Product pillars supported:

- Believable progress
- Personalized coaching
- Pressure modes that feel fair
- Conversational intelligence
- Real-world transfer

Existing patterns to preserve:

- `HomeSignalGate` owns Home visibility and gradual reveal.
- `RecommendationBiasContext` / `RecommendationBiasEngine` own the one-rep
  prescription.
- `CoachContextBuilder` owns durable context and Ask Noum evidence rules.
- `ProofMomentService` owns quote verification. Never bypass it for "you said"
  evidence.
- `BigMomentStore` / `PrepSessionPlanner` own real-world transfer state.
- `ProfileEvidenceDetailPlan` / `ProfileDefaultSurfacePlan` own Profile
  subtraction and disclosure.
- `RatingStore` / `SpeakingRating.hasRatedEvidence` own whether rating, peak,
  league, or bucket claims are earned.

Do not introduce new stores, duplicate routes, fake progress, fake loading,
hearts/lives framing, or "replaces a human coach" claims.

## What changed in this handover session

- Tightened the League state owner so an unrated user has an empty league
  bucket key. The UI already said placement was pending; now the backend-facing
  state matches that honesty contract.
- Replaced "rated pressure rep" copy with "rated rep" across League and Peak
  empty states so first-run placement does not sound mode-gated or punitive.
- Added tests to `BelievableProgressZeroDataTests` for the empty-bucket
  contract before rated evidence and non-empty bucket after rated evidence.
- Added this `handover.md` with the current product/market/coach delta.
- Verified the focused zero-data progress tests on the iPhone 17 simulator and
  captured a fresh light five-tab screenshot sweep.

Files touched in this session:

- `Noum/LeagueManager.swift`
- `Noum/LeagueView.swift`
- `Noum/PeakRatingWallView.swift`
- `NoumTests/NoumTests.swift`
- `handover.md`
- `.screenshots/2026-06-08_autostop-de8ee0d-0006/HANDOFF.md`

Pre-existing dirty/generated changes at session start:

- `.agents/skills/noum-screenshots/capture.sh`
- `.claude/skills/noum-screenshots/capture.sh`
- `.screenshots/2026-06-07_autostop-de8ee0d-2331/HANDOFF.md`
- `.screenshots/2026-06-07_light-current-ui-testing/HANDOFF.md`
- `.derived-data-log-0CA5RPJ1`

Preserve these unless the owner explicitly says to clean them.

## Current UX iteration status

Iteration 1 - post-rep verdict:

- Functionally landed. Summary now leads with one read, verified proof where
  available, one fix, and value-before-Pro.
- Fresh light screenshot review completed in
  `.screenshots/2026-06-08_autostop-de8ee0d-0006/`.

Iteration 2 - honesty / a11y / dead-code sweep:

- Mostly landed. Loss-aversion notification copy, forever-pulse issues,
  random speak-off scoring, and pressure result shame copy appear addressed.
- Do not re-delete `SocialProfileView.swift` or `AchievementsPage.swift`; the
  newer handoff says they are not safe dead-code deletions.

Iteration 3 - first 60 seconds:

- Real first-run route and first-value-loop UI test hooks exist.
- The old long fake processing delay appears removed (`OnboardingCompletionTiming`
  is now a short reveal delay).
- Still needs true cold-start simulator proof: ask -> speak -> first read in
  about 60 seconds, not just UI-test injection.

Iteration 4 - Home:

- `HomeCoachCard` is the single hero and `HomeSignalGate` suppresses noisy
  surfaces. Ask Noum is folded into the coach card after one completed rep.
- Light simulator capture renders Home, Train, Review, Profile, and Settings
  without blank screens. Remaining work is broader state coverage: verify cold,
  1-rep, 3-rep-week, and rich seeded states on simulator. Do not add dashboard
  cards back to Home.

Iteration 5 - prescription / curriculum spine:

- Picker has Coach Pick, Begin, Pick another, telemetry, and availability
  fallback.
- Still not fully done: the broader curriculum spine should feel like a
  sequenced coach plan rather than a mode picker with a good default. Keep
  `RatingStore` as the one believable progress number; lessons/crowns/XP should
  feed the story rather than compete with it.

Iteration 6 - Ask Noum quality:

- Structured reply shape and quote guard exist.
- Needs simulator/adversarial review across empty state, post-rep seed, weak
  evidence, pushback, and goal-change turns. A fabricated quote is the top trust
  failure; do not weaken `CoachChatQuoteGuardContext`.

Iteration 7 - Profile / transfer:

- Profile is collapsed by default: identity, optional rating hero when evidence
  exists, one coach read, evidence hub.
- Transfer state is now surfaced compactly via `BigMomentStore`.
- Still needs visual review for Dynamic Type, VoiceOver, thin-data users, and
  whether the expanded evidence disclosure is still too dense.

## Delta to a strong human communications coach

What Noum now does credibly:

- Records real reps and persists a history.
- Detects fillers with semantic/prompt-echo caution.
- Tracks rating, baselines, trends, proof moments, coach memory, and big moments.
- Prescribes one next rep from existing recommendation context.
- Can quote verified user words and use them as proof.
- Has a bounded case-file direction and avoids claiming validation/parity.

Where a human coach is still ahead:

- Perception depth: a human reads breath, tension, posture, eye contact,
  energy, vocal variety, authority, emotional connection, and whether polished
  speech still feels evasive or detached.
- Case formulation: a human asks clarifying questions, notices what the user
  avoids, tests hypotheses live, and revises the read when the user disagrees.
- Intervention quality: a human designs drills against the exact user, room,
  audience, stake, and deadline, not just the detected metric.
- Adaptation: a human can say "this drill is not working for you" and change
  course after watching the response. Noum has some loops, but the general
  reinforce/vary/replace loop is still a roadmap item.
- Transfer: a human follows up after the interview, board update, pitch, date,
  conflict, or leadership conversation and updates the coaching plan from the
  user's real outcome.
- Validation: a human coach has externally observable judgment. Noum still
  lacks expert-calibrated evaluation fixtures and longitudinal outcome proof.

High-leverage next product moves:

1. Close the general adaptation loop in `RecommendationLearningStore` /
   `NextActionEngine`: reinforce, vary, or replace after enough followed reps.
2. Persist the soonest upcoming `BigMoment` into `CoachCaseFile`.
3. Fuse delivery reads into one careful, user-confirmable delivery hypothesis.
4. Aggregate repeated Big Moment outcomes into tentative transfer trends.
5. Build a version-controlled evaluation set and compare Noum reads to expert
   coach baselines. Label this "validation substrate", not validation.

## Competitor delta, checked 2026-06-07

Sources:

- Yoodli overview: https://support.yoodli.ai/en/articles/9550461-yoodli-overview
- Yoodli roleplay platform: https://yoodli.ai/
- Orai homepage: https://orai.com/
- Orai pricing / training plan: https://orai.com/pricing/
- Speeko homepage: https://www.speeko.co/home
- Speeko App Store: https://apps.apple.com/us/app/speeko-ai-for-public-speaking/id1071468459
- Duolingo Video Call with Lily: https://blog.duolingo.com/video-call/
- Duolingo Video Call with Falstaff: https://blog.duolingo.com/beginner-video-call-with-falstaff/
- Duolingo Android expansion release: https://investors.duolingo.com/news-releases/news-release-details/duolingo-launches-ai-powered-video-call-android

Yoodli:

- Strength: strong roleplay surface for pitches, presentations, interviews,
  sales calls, difficult conversations, and video-call coaching. Enterprise GTM
  and team/coach workflows are ahead of Noum.
- Noum edge: iOS-native private coach identity, durable personal memory,
  verified quote/proof moments, and a tighter pressure/filler coaching loop.
- Gap to close: Yoodli's roleplay breadth and call-context integration.

Orai:

- Strength: clear mobile public-speaking practice with interactive lessons,
  speech analysis, progress tracking, and a 4-week personalized training plan.
- Noum edge: stronger semantic filler logic, real pressure modes, Ask Noum,
  proof archive, coach case memory, and real-world moment hooks.
- Gap to close: Orai's simpler promise and visible training-plan artifact are
  easier for a new user to understand quickly.

Speeko:

- Strength: polished speech-style feedback across pace, tone, fillers,
  intonation, sentiment, talk time, word choice, virtual meetings, and voice
  coach content.
- Noum edge: stronger coaching-memory ambition, pressure modes, verified proof,
  and personal case formulation.
- Gap to close: Speeko's real-time "speaker coach when you need one" clarity
  and delivery-sensing breadth.

Duolingo:

- Strength: personality, retention design, path habit, and low-pressure AI
  conversation practice through Lily/Falstaff. It makes speaking feel playful
  and approachable.
- Noum edge: not language learning; Noum can specialize in professional and
  interpersonal communication under pressure, evidence-based coaching, and
  durable progress. That is a more valuable wedge if the trust bar is met.
- Gap to close: delight and repeat-use pacing. Noum should borrow the feeling
  of "one small session, visible progress" without borrowing hearts, shame,
  noisy streak pressure, or shallow gamification.

Market conclusion:

Noum's defensible wedge is not "another AI speech metric app." It is private,
evidence-led communication coaching that remembers the user's own words and
real moments, prescribes one next rep, and adapts over time. If Noum regresses
into dashboards, leaderboards, or generic AI chat, Orai/Speeko/Yoodli already
cover that territory. If Noum proves the loop, it can feel more coach-like than
those apps without claiming to replace a human coach prematurely.

## Verification recipe

Completed in this session:

- `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination "platform=iOS Simulator,id=3D077053-2981-4C5D-819D-FF6F9BA8AD06" -derivedDataPath ./DerivedData/Noum -only-testing:NoumTests/BelievableProgressZeroDataTests`
  succeeded.
- `.agents/skills/noum-screenshots/capture.sh` captured five tab tops to
  `.screenshots/2026-06-08_autostop-de8ee0d-0006/`.
- Screenshot PNGs were 1206 x 2622 and visually spot-checked for Home, Train,
  Review, Profile, and Settings.

Use repo-local DerivedData and confirm the binary mtime advanced:

```bash
xcrun simctl list devices booted
xcodebuild build -project Noum.xcodeproj -scheme Noum \
  -destination "platform=iOS Simulator,id=<UDID>" \
  -derivedDataPath ./DerivedData/Noum -configuration Debug
stat -f "%Sm %N" ./DerivedData/Noum/Build/Products/Debug-iphonesimulator/Noum.app/Noum
```

Focused tests to run after this handover:

```bash
xcodebuild test -project Noum.xcodeproj -scheme Noum \
  -destination "platform=iOS Simulator,id=<UDID>" \
  -derivedDataPath ./DerivedData/Noum \
  -only-testing:NoumTests/BelievableProgressZeroDataTests

xcodebuild test -project Noum.xcodeproj -scheme Noum \
  -destination "platform=iOS Simulator,id=<UDID>" \
  -derivedDataPath ./DerivedData/Noum \
  -only-testing:NoumTests/HomeSignalGateTests \
  -only-testing:NoumTests/ProfileCollapseContractTests \
  -only-testing:NoumTests/PracticeModePrescriptionCopyTests
```

Screenshot targets:

- Cold Home/Profile/League/Peak Rating Wall with zero reps.
- First-run onboarding -> Train -> first value-loop read.
- Train picker collapsed and expanded.
- Summary verdict with proof row.
- Ask Noum empty, seeded post-rep, and weak-evidence states.
- Profile collapsed and expanded evidence details.

Figma/Canva note:

The Figma MCP limit was already reached in the prior session. No Canva connector
is available in this environment. Use the local screenshot workflow plus static
HTML/Markdown mockups under `docs/concepts/` if a visual proposal is needed
before the Figma allowance resets.

## Red lines for follow-on work

- Do not claim human-coach replacement in app copy.
- Do not show league tier, peak rating, or bucket membership before
  `rating.hasRatedEvidence`.
- Do not quote user speech unless it passed the existing quote guard.
- Do not create parallel state for transfer, coach memory, or recommendation
  learning.
- Do not add a second Home coach door.
- Do not reintroduce "Sudden Death" user-facing copy where "Pressure Drill"
  is intended.
- Do not use hearts/lives/no-second-chances framing. Internal field names can
  remain for compatibility if user copy says "slips."
- Do not add dashboard surfaces to solve a hierarchy problem.
