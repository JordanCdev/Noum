# UX Value Overhaul Handoff — 2026-06-07

Branch: `ux-overhaul`

Purpose: continuation handoff for the risky Noum UX/value revamp. This file captures where the current Codex session stopped, what was learned from the agent council, what has already changed in the dirty worktree, and what Claude should do next.

## Owner brief

The owner is dissatisfied with the app's UX and perceived value: too much text, too much useless information, not enough felt coaching value, not enough reason to return. They want a major overhaul, including team/agent workflow, market research, testers, developers, UX evaluation, iteration, and eventual confidence that Noum can approach the value of a human communications coach without relying on shallow gamification.

Important correction: do not claim Noum "replaces a human coach" in product copy or launch framing yet. Treat it as the long-term ambition. The shippable wedge is narrower and stronger:

> Coach-grade deliberate practice for high-stakes short speaking moments: one short rep, one grounded read, one next move, durable memory, and eventual real-world transfer proof.

## Required context already read

Read and synthesized:

- `AGENTS.md`
- `docs/VISION.md`
- `docs/CURRENT_STATE.md`
- `docs/M15_handoff.md`
- `docs/UX_VALUE_OVERHAUL_ROADMAP.md`
- `docs/UX_RENDERED_REVIEW.md`
- `docs/COACH_PARITY_ROADMAP.md`
- `.claude/skills/noum-design/SKILL.md`
- `.claude/skills/noum-design/README.md`
- `.agents/skills/noum-orchestrator/SKILL.md`

Note: the orchestrator skill points at `.Codex/skills/noum-design/SKILL.md`, but this repo actually has `.claude/skills/noum-design/SKILL.md`.

## Architecture framing

Milestone served: UX value overhaul on top of M15/M25 coaching/value work.

Product pillars supported:

- believable progress
- personalized coaching
- pressure fairness
- proof-backed improvement
- conversational intelligence
- real-world transfer
- return motivation through value, not coercion

State owners to preserve:

- Home: `ContentView`, `HomeSignalGate`, `HomeCoachCard`
- Sessions/summary: `PracticeSessionStore`, `SummaryView`, `SummaryDataStore`, `PostRepCoachNoteStore`
- Proof: `ProofMomentService`, `ProofMomentStore`, `GrowthLibraryView`
- Ratings/progression: `RatingStore`, `RatingEngine`, `BaselineStore`, `SkillProgressionStore`, `PathProgressManager`, `LeagueManager`
- Recommendations: `RecommendationBiasEngine`, `RecommendationLearningStore`, `CoachingPlanner`, `TrendAnalyzer`
- Coach memory: `CoachMemoryStore`, `CoachCaseFile`, `CoachContextBuilder`, `CoachCheckInStore`
- Onboarding: `FirstRunOnboardingManager`, `CoachingOnboardingView`, `CoachingProfileStore`, `NoumApp`
- Transfer: `BigMomentStore`, `PrepSessionPlanner`, `BigMomentOutcomeInlineCard`
- Notifications: `NotificationManager`, `NotificationCopy`, `NotificationPrePromptManager`

Do not create duplicate stores or parallel screens for the revamp.

## Agent team created

Agent Teams tooling was available, and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` was `1`. Five read-only agents were spawned:

- UX teardown lead: `019ea282-f0e7-7323-8c3a-96103dcc1bdc`
- Market/pre-market lead: `019ea283-0e6c-7f11-a6b7-98378dcff472`
- QA/accessibility lead: `019ea283-2b3e-75b3-b143-fc49dc8b8a60`
- Coach-parity/value strategist: `019ea283-4863-7a43-a9d9-ce57bb13a2a2`
- Implementation architecture lead: `019ea283-68b6-7831-a1fe-cc5eb9f2b57d`

All five completed read-only reports. No subagent edited files.

## Consensus diagnosis

The app's core coaching logic is much stronger than the UX makes it feel. The killer issue is not lack of features. It is hierarchy, trust, and value presentation:

- value is buried under repeated prose and dashboards
- the user has to interpret metrics instead of receiving a coach's judgment
- progress currencies compete with each other
- some reward/motion still fires from broad activity thresholds instead of true improvement crossings
- first-run still does not force a fast "speak -> honest read" payoff before Home
- Profile is default-collapsed now, but the disclosure is still a large junk drawer
- Ask Noum still returns prose strings, so deep context can feel like generic chat

The right direction is subtraction plus a tighter loop:

> Speak -> one evidenced read -> one prescribed next rep -> real pattern movement -> real-event prep/outcome -> coach adapts.

## Market synthesis

Competitors set the baseline expectation:

- Yoodli: AI speech coaching, roleplay, real-time/post-session feedback, enterprise rubrics
- Orai/Speeko: filler, pacing, tone, lessons, progress charts
- Poised: discreet real-time meeting coaching
- Vocal Image/BoldVoice/ELSA: bite-sized daily speech/voice/accent practice
- Duolingo: retention mechanics, useful only as interaction inspiration, not a product model

Category disappointments Noum must avoid:

- metrics without judgment
- context-blind filler detection
- generic repetition
- cluttered AI surfaces
- trust/privacy friction around voice data
- streak/hearts/league gamification drifting away from real learning

Noum's differentiation:

> Evidence-led private communication coaching, grounded in the user's own speech and durable memory.

The most defensible dopamine is not badges. It is "Noum noticed the real thing I said, showed the pattern moving, and gave me the next rep."

Useful sources from the market agent:

- https://yoodli.ai/
- https://orai.com/
- https://www.speeko.co/home
- https://www.poised.com/
- https://www.vocalimage.app/en/
- https://apps.apple.com/us/app/boldvoice-accent-training/id1567841142
- https://arxiv.org/abs/2507.07930
- https://arxiv.org/abs/2203.16175

## Current dirty worktree reality

The roadmap docs are partly stale because this branch already contains many revamp changes.

Already implemented or mostly implemented in the dirty tree:

- Home gating/collapse via `HomeSignalGate`
- Home optional override in Settings via `practice.showAllHomeCards`
- `HomeUtilityStrip`, `DailyChallengeTile`, and `VoiceMetricsCard` are retired from default Home
- `PostRepVerdictCard` exists and is wired into `SummaryView`
- Profile default surface is collapsed around identity, coach read, evidence links, and a disclosure
- `CoachParityReadinessCard` deleted
- `SocialProfileView.swift`, `SplashScreenView.swift`, `OnboardingHeroView.swift`, and `OnboardingHeroManager.swift` deleted
- `FirstRunOnboardingManager.swift` added
- First-run fake loading / splash appears removed
- Practice picker has recommended hero, "Other ways to practice", and mode expansion copy
- "3 hearts, no second chances" softened to "Three slips ends the rep"
- `PracticeMode.suddenDeath.displayLabel` returns "Pressure Drill"
- pressure result copy no longer says "Time Broke You"
- fake League/Silver zero-data placement appears improved
- Path debug controls are `#if DEBUG` plus developer-gated
- simulated challenge random opponent scoring appears removed
- Home/summary/profile tests were being added/updated

Still not proven or still risky:

- first-run does not clearly route directly into one short rep before Home
- summary celebration still appears locally thresholded by score/XP rather than canonical `RewardEngine` `.major`
- first-rep celebration/share may still reward participation before improvement
- Ask Noum remains prose-shaped (`ChatOutcome.reply(String)` style), not structured read/evidence/move
- Profile disclosure still contains rank, arc, peak wall, charts, mode mastery, achievements, coaching evidence, league, social, and stats
- user-facing "Sudden Death" strings still survive in history/share/daily challenge/deep surfaces
- `PostRepVerdictCard` CTA buttons need stable accessibility identifiers and integrated proof-failure tests
- notification copy still may include "Hold your N-day streak" daily reminder language
- several reduced-motion risks remain in onboarding, summary hero animations, profile numeric transitions, picker selection, and history disclosure

## Current git status summary

At the time of handoff, branch is `ux-overhaul...origin/ux-overhaul`.

The worktree is dirty and broad. Do not revert user/previous-agent changes.

Notable modified/deleted/added files include:

- `Noum/ContentView.swift`
- `Noum/HomeSignalGate.swift`
- `Noum/HomeCoachCard.swift`
- `Noum/SummaryView.swift`
- `Noum/SummaryCards.swift`
- `Noum/PostRepVerdictCard.swift` (untracked)
- `Noum/PracticeModeSelectionView.swift`
- `Noum/NoumApp.swift`
- `Noum/FirstRunOnboardingManager.swift` (untracked)
- `Noum/CoachingOnboardingView.swift`
- `ProfileView.swift`
- `Noum/NotificationCopy.swift`
- `Noum/LeagueManager.swift`
- `Noum/LeagueView.swift`
- `Noum/FriendLeaderboardView.swift`
- `Noum/PathProgressManager.swift`
- `Noum/PathJourneyView.swift`
- `NoumTests/NoumTests.swift`
- `Noum/SocialProfileView.swift` deleted
- `Noum/SplashScreenView.swift` deleted
- `Noum/OnboardingHeroView.swift` deleted
- `Noum/OnboardingHeroManager.swift` deleted
- `Noum/CoachParityReadinessCard.swift` deleted
- `.screenshots/2026-06-07_ux-value-overhaul-batch/HANDOFF.md` staged from prior work

There is also a modified `.derived-data-log-0CA5RPJ1`; treat it as generated unless proven otherwise.

## Figma / design tooling

The user mentioned Figma/Canva. During this handoff session:

- Figma plugin was installed successfully.
- Figma tools are now available via `mcp__codex_apps__figma`.
- Canva was listed as installable but was not installed.

No Figma file was created yet. If continuing design work, first load Figma guidance as required by the Figma tool, then create either:

- a FigJam workflow map of the council loop, or
- Figma mockups for the four critical screens: first-run, post-rep verdict, Home, Profile.

Do not block engineering on Figma. Production tokens remain `Noum/DesignSystem.swift` and `Noum/Typography.swift`.

## Recommended workflow from here

Phase 0 — lead only:

- Freeze the current dirty baseline mentally.
- Run `git status --short --branch`.
- Inspect all untracked/deleted files before editing.
- Get a green build before allowing worker agents to edit.

Phase 1 — lead integration:

- Stabilize cross-cutting files: `NoumApp.swift`, `ContentView.swift`, `SummaryView.swift`, `PracticeSupport.swift`, `ProfileView.swift`, `NoumTests.swift`.
- Confirm deleted files stay deleted unless there is a compile break.

Phase 2 — parallel workers after green build:

- Agent A, Summary proof/value: `SummaryView.swift`, `PostRepVerdictCard.swift`, proof/reward tests only.
- Agent B, First-run value path: `NoumApp.swift`, `FirstRunOnboardingManager.swift`, `CoachingOnboardingView.swift`, first-run tests only. This is collision-prone; consider serial ownership.
- Agent C, Profile/Home discipline: `HomeSignalGate.swift`, `HomeCoachCard.swift`, `ProfileView.swift`, no store changes.
- Agent D, copy/honesty cleanup: `NotificationCopy.swift`, `SessionHistoryView.swift`, `DailyChallenge.swift`, remaining pressure labels.
- Agent E, QA/screenshot sweep: no code edits; reduced-motion/a11y/screenshot verification.

Merge order:

1. lead baseline/build fixes
2. pure copy/presentation fixes
3. Summary reward/proof fixes
4. first-run routing
5. Profile/Home cleanup
6. QA/docs sync

## First sprint

Sprint goal: stabilize the already-started overhaul and make the highest-value loop honest.

Priority 1 — reward ownership:

- Find current summary celebration gate in `SummaryView`.
- Route celebration through canonical `RewardEngine` / `.major` events only.
- Add tests:
  - no full celebration on first rep
  - no full celebration for score >= 7 alone
  - no full celebration for XP >= 100 alone
  - full celebration only on true major crossing
  - reduced-motion fallback exists

Priority 2 — first-run to first value:

- Confirm `CoachingOnboardingView` save path.
- After the three-question intake, route directly into one short recommended first rep instead of dismissing to Home.
- After rep, show honest "first read" via the summary/verdict path.
- No celebration or parity/verdict overclaim on first rep.
- Preserve `UI_TESTING` launch behavior.

Priority 3 — proof and verdict safety:

- Ensure `PostRepVerdictCard` displays only transcript-verified proof quotes or deterministic fallback.
- Add integrated fail-path tests:
  - rejected AI quote
  - no transcript
  - short transcript
  - provider unavailable
  - fallback does not fabricate quote
- Add stable identifiers/hints for verdict CTAs.

Priority 4 — pressure language cleanup:

- Finish user-facing rename from "Sudden Death" to "Pressure Drill" where appropriate.
- Keep internal enum as `.suddenDeath` if cheaper/safe; do not churn persistence.
- Audit:
  - `SessionHistoryView.swift`
  - `ProfileView.swift`
  - `DailyChallenge.swift`
  - `SuddenDeathResultView.swift`
  - share/export labels
- Preserve old strings only where they are purely code comments or persistence compatibility.

Priority 5 — profile disclosure discipline:

- Default Profile is much better; the disclosure is now the problem.
- Break the disclosure into fewer, named destinations or cut surfaces from default entirely.
- Do not add a "simple mode" toggle.
- Keep:
  - rating trajectory
  - one coach read / next move
  - growth library / review reps
  - real transfer loop
- Demote or cut from the default evidence disclosure:
  - mode mastery
  - achievements
  - league/social
  - duplicate peak wall/card combinations
  - internal coaching instrumentation

Priority 6 — notification and motion/a11y:

- Remove remaining loss-aversion daily reminder copy such as "Hold your N-day streak."
- Add reduced-motion gates where QA flagged:
  - `CoachingOnboardingView`
  - `SummaryCards.HeroScoreCard`
  - `ProfileView` numeric animations
  - `PracticeModeSelectionView` crutch/pace selection animations
  - `SessionHistoryView` disclosure animations
- Check VoiceOver for `LookingAheadCard` and `PostRepVerdictCard` CTAs.

## Test filters to run early

Use exact suite names only after confirming they compile in `NoumTests/NoumTests.swift`.

Suggested focused tests:

- `HomeSignalGateTests`
- `HomeSignalGateEdgeTests`
- `HomeBottomShortcutContractTests`
- `FirstRunFrictionContractTests`
- `PracticeModeRowExpansionTests`
- `PracticeModePrescriptionCopyTests`
- `PostRepVerdictContentTests`
- `ProofMomentServiceTests`
- `ProofMomentArchiveTests`
- `ProfileCollapseContractTests`
- `SummaryPracticeAgainRouterTests`
- `SummaryLookingAheadRouterTests`
- `LookingAheadCardStartCTAContractTests`
- `NotificationCopyEveningNudgeTests`
- add/extend daily reminder notification tests
- add/extend reward ownership tests

Recommended build:

```sh
xcodebuild build -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug
```

If the destination name is unavailable, inspect available simulators and use the current booted iPhone simulator.

## Screenshot / QA sweep

After build and focused tests:

- run light screenshot sweep if the local screenshot skill is available
- capture Home, Practice picker, Summary, Profile, League, Path, onboarding
- test states:
  - clean install / no profile
  - beginner
  - improving
  - plateaued
  - pressure-vulnerable
  - rated vs unrated
  - free vs premium
  - AI configured vs unavailable
  - Reduce Motion on
  - Dynamic Type XL and accessibility 3XL
  - mic granted/denied
  - notifications denied/not determined/authorized

## Red lines

Do not ship:

- fake progress, fake peers, fake peaks, fake loading, fake AI thinking
- "replace a human coach" claims
- unverified "you said..." quotes
- first-rep celebration as if improvement occurred
- score/XP celebration not backed by a real crossing
- hearts/lives framing
- punish-shame pressure outcomes
- raw "the user..." coaching rationale in UI
- empty clinical rubrics foregrounded as relationship
- paywall before first felt value
- hidden video/presence analysis without explicit consent

## Final answer requirements reminder

AGENTS.md asks final responses to include:

- Implemented
- Partially implemented
- Blocked
- Assumptions
- Verification
- Risks

Be explicit when tests/build/screenshots were not run.

