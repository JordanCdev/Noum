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

## Recent handover work

2026-06-08 ~17:08 continuation (local Codex run, real toolchain):

- Started the next M14 launch-readiness pass after the coach-parity
  scorecard cleanup by tightening Dynamic-Type coverage on high-traffic text
  surfaces.
- Migrated first-run login text (`noum` label, hero headline/subcopy, Google
  fallback button, guest button), Home coach card title, Settings cluster /
  Advanced / micro / toggle labels, and Big Moment intake header/category text
  off fixed `.system(size:)` fonts and onto `Typography` roles or
  Dynamic-Type-aware `Typography.figtree(...)` builders.
- Left fixed icon glyphs and fixed-format counters alone. The remaining
  `.system(size:)` inventory is mixed, not complete: some entries are
  intentional icons/counters/share-card/decoration; other legacy text in
  practice, summary, lesson, and celebration surfaces still needs
  surface-by-surface review.
- Corrected the Dynamic Type note in `docs/CURRENT_STATE.md` so follow-on work
  does not inherit a false "all remaining call sites are intentional" signal.
- Invoked the local screenshot workflow because UI changed. The expected mode
  file `.Codex/skills/noum-screenshots/.mode` was missing, so this run wrote a
  minimal `.screenshots/2026-06-08_m14-typography-accessibility/HANDOFF.md`
  and queued login/Home/Settings/Big Moment intake for visual verification.
- Verified with `git diff --check` and `xcodebuild test -scheme Noum
  -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/ScoreCalibrationTests`: `TEST SUCCEEDED`. Result
  bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_17-04-12-+0100.xcresult`.

Files touched this continuation: `Noum/LoginView.swift`,
`Noum/HomeCoachCard.swift`, `Noum/SettingsView.swift`, `Noum/SettingsRow.swift`,
`Noum/BigMomentIntakeView.swift`, `docs/CURRENT_STATE.md`,
`.screenshots/2026-06-08_m14-typography-accessibility/HANDOFF.md`,
`handover.md`.

2026-06-08 ~17:00 continuation (local Codex run, real toolchain):

- Cleared the remaining low-severity scorecard cleanup row. The
  `PromptAnswerVerdict` comments in current `PracticeSupport.swift` already
  matched behavior, so no code edit was needed there.
- Hardened `CoachContextBuilder.coachCaseFormulationLines(...)` for the
  defensive `.divergent` concordance edge. If future persisted memory says
  stated-vs-measured is divergent but `statedChallengeArea` is missing, the
  context now asks a clarifying question before changing focus instead of
  silently dropping the divergence line.
- Added `StatedChallengeConcordanceTests.divergentMemoryWithMissingStatedAreaAsksForClarification`
  to lock that behavior.
- Removed stale numeric line references from IM conversation grading and Coach
  Read comments in `PracticeSupport.swift`; these were comment-only cleanups.
- Updated `docs/COACH_REPLACEMENT_SCORECARD.md` so no scorecard-level
  code-tickable coach-parity backlog items remain. Human validation gates still
  stand.
- Verified with `git diff --check` and `xcodebuild test -scheme Noum
  -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/StatedChallengeConcordanceTests`: `TEST SUCCEEDED`.
  Result bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_16-55-56-+0100.xcresult`.

Files touched this continuation: `Noum/CoachContextBuilder.swift`,
`Noum/PracticeSupport.swift`, `NoumTests/NoumTests.swift`,
`docs/COACH_REPLACEMENT_SCORECARD.md`, `handover.md`.

2026-06-08 ~16:52 continuation (local Codex run, real toolchain):

- Closed the code-side `VALIDATE-1` depth pass as substrate only. This does
  not claim expert calibration, human-coach parity, or live LLM felt quality.
- Moved the six Ask Noum evaluation fixtures out of the inline
  `CoachChatEvaluationFixtureTests` block into the standalone synchronized test
  source file `NoumTests/CoachChatEvaluationFixtures.swift`. The existing tests
  still exercise the live `CoachContextBuilder.userContext` and
  `AICoachChatService.professionalCoachRubric` paths.
- Added explicit `CoachChatExpertBaselineSlot` metadata to every fixture. All
  slots are deliberately `pendingExpertReview` with no baseline ID or coach
  summary; `VALIDATE-2` remains the human/expert baseline comparison gate.
- Added a deterministic `CoachChatEvaluationCIReport` projection over the same
  fixtures. The report records fixture ID, pillar, pending expert-baseline
  status, reference-reply rubric pass, known-bad issue match, and context-needle
  count, and encodes to sorted JSON for future CI consumption.
- Added tests that lock the expert-baseline slots as pending and verify the CI
  report is deterministic, machine-readable, and still passing the senior-coach
  rubric / known-bad issue checks.
- First focused run failed at compile on Swift Testing macro expansion for
  key-path `allSatisfy` predicates; fixed by using explicit non-throwing
  closures. Rerun verified with `xcodebuild test -scheme Noum -destination
  'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/CoachChatEvaluationFixtureTests
  -only-testing:NoumTests/AICoachChatReplyQualityTests
  -only-testing:NoumTests/AICoachChatDeterministicReplyTests`: `TEST
  SUCCEEDED`. Result bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_16-48-10-+0100.xcresult`.

Files touched this continuation: `NoumTests/CoachChatEvaluationFixtures.swift`,
`NoumTests/NoumTests.swift`, `docs/COACH_REPLACEMENT_SCORECARD.md`,
`handover.md`.

2026-06-08 ~16:41 continuation (local Codex run, real toolchain):

- Closed the `VIDEO-ANALYSIS` contract row while keeping the presence pillar's
  felt-quality caveat human-gated. `VideoAnalysisService` still owns recording
  analysis; this slice only tightened when live video reads are allowed and
  what provider output may render.
- Added `FeedbackRating` custom Codable support in `PracticeSupport.swift` so
  provider-style rating labels (`good`, `OK`, `Could improve`, `couldImprove`)
  decode into the canonical app enum while encoded results stay on the existing
  display raw values.
- Added pure `VideoAnalysisContract` plus `VideoAnalysisError`. Live video
  analysis now requires `PracticeLocale.aiSupported`, rejects non-vision
  providers (`deepSeek` included), throws a clear no-frame error when frame
  extraction produces nothing usable, and normalizes provider results before
  recording/rendering them. Empty visual notes, AI self-disclosure, text-only
  generic analysis, and overlong notes are rejected.
- Removed the old text-only video-analysis fallback and updated the video prompt
  rating labels to the canonical display values. `SummaryView.analyzeVideo()`
  now renders the new restrained video-specific errors instead of a raw generic
  failure.
- Added `FeedbackRatingDecodingTests` and `VideoAnalysisContractTests` for
  rating alias decoding/encoding, provider eligibility, locale eligibility,
  copy bounding, and generic/no-visual/self-disclosing output rejection. Updated
  `docs/COACH_REPLACEMENT_SCORECARD.md` so `VideoAnalysisService` is no longer
  listed as a code-tickable contract gap.
- Verified with `git diff --check` and `xcodebuild test -scheme Noum
  -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/FeedbackRatingDecodingTests
  -only-testing:NoumTests/VideoAnalysisContractTests
  -only-testing:NoumTests/PaywallFeatureAccuracyTests`: `TEST SUCCEEDED`.
  Result bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_16-36-58-+0100.xcresult`.

Files touched this continuation: `Noum/PracticeSupport.swift`,
`Noum/SummaryView.swift`, `NoumTests/NoumTests.swift`,
`docs/COACH_REPLACEMENT_SCORECARD.md`, `handover.md`.

2026-06-08 ~16:32 continuation (local Codex run, real toolchain):

- Closed the `PRESSURE-FOLLOWUP` contract row without changing
  `PressureTimerEngine`'s round/state ownership. Sudden Death still uses
  `PressureFollowUpProviding` and falls back to `PressureFollowUpTemplates`;
  the live AI path now has to earn its slot.
- Added pure `PressureFollowUpContract` in `PressureFollowUpService.swift`.
  It gates live AI by `PracticeLocale.aiSupported`, normalizes whitespace,
  caps accepted AI follow-ups at 15 words, rejects hostile/chirpy output, and
  requires grounding against the user's prior turn via shared non-stop content
  words or a 12-character verbatim slice. Empty transcripts and generic
  "give me an example" style questions return nil.
- `PressureFollowUpService.generateFollowUp(...)` now skips provider calls on
  unsupported locales and validates decoded provider output before rendering it.
  Invalid/ungrounded output uses the existing deterministic template fallback,
  so the pressure round keeps moving without a generic English LLM question.
- Added `PressureFollowUpContractTests` for locale eligibility, grounded
  acceptance, word bounding, generic rejection, hostile rejection, empty
  transcript rejection, and too-short rejection. Updated
  `docs/COACH_REPLACEMENT_SCORECARD.md` so only `VideoAnalysisService` remains
  in the lower-leverage contract backlog.
- Verified with `git diff --check` and `xcodebuild test -scheme Noum
  -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/PressureFollowUpContractTests
  -only-testing:NoumTests/PressureFollowUpTemplateTests`: `TEST SUCCEEDED`.
  Result bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_16-29-25-+0100.xcresult`.

Files touched this continuation: `Noum/PressureFollowUpService.swift`,
`NoumTests/NoumTests.swift`, `docs/COACH_REPLACEMENT_SCORECARD.md`,
`handover.md`.

2026-06-08 ~16:26 continuation (local Codex run, real toolchain):

- Closed the `AI-HOME-REC` contract-completion row without moving the Home
  recommendation owner. `RecommendationBiasEngine` / `RecommendationBiasContext`
  still decide the next mode, focus, target, IM tone, and IM scenario; the live
  AI layer is now only allowed to rewrite bounded Home-card copy over that
  deterministic prescription.
- Added `AIHomeRecommendationContract.normalized(...)` in `PracticeSupport.swift`.
  Provider JSON must parse to a valid `PracticeMode`, match the binding
  preferred mode from `AIHomeRecommendationInput`, match any binding IM tone /
  scenario exactly, and carry non-empty restrained copy. Non-IM recommendations
  drop stray IM metadata; missing `modeBenefit` falls back to the deterministic
  mode-benefit bias. Invalid output throws `AICoachError.invalidResponse`, which
  preserves Home's existing deterministic fallback path.
- Tightened the `AIHomeRecommendationService` prompt wording from soft
  "rule-based bias" language to binding preferred mode/tone/scenario fields.
  The service validates decoded provider JSON before recording analysis or
  caching/rendering it.
- Added `AIHomeRecommendationContractTests` for mode drift, preferred IM setup
  drift, valid optional IM setup, invalid IM setup, empty visible copy, copy word
  bounds, brand-voice rejection, non-IM metadata cleanup, and deterministic
  `modeBenefit` fallback. Updated `docs/COACH_REPLACEMENT_SCORECARD.md` so
  `AI-HOME-REC` is shipped and removed from the lower-leverage backlog.
- Verified with `git diff --check` and `xcodebuild test -scheme Noum
  -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/AIHomeRecommendationContractTests
  -only-testing:NoumTests/RecommendationBiasCopyContractTests
  -only-testing:NoumTests/RecommendationBiasContextBuilderTests`:
  `TEST SUCCEEDED`. Result bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_16-22-49-+0100.xcresult`.

Files touched this continuation: `Noum/PracticeSupport.swift`,
`NoumTests/NoumTests.swift`, `docs/COACH_REPLACEMENT_SCORECARD.md`,
`handover.md`.

2026-06-08 ~16:18 continuation (local Codex run, real toolchain):

- Closed the `EXERCISE-5` remainder through the existing framework-drill system
  instead of creating a parallel exercise path. Added stable mini-drill IDs
  `structure.claimEvidenceWarrant` and `structure.monroeSequence`, both routed
  through `MiniDrillType.framework(for:)`, `FrameworkDrill`, and
  `FrameworkDrillVerdict.evaluate`.
- CEW deliberately reuses `PracticeEvaluator.argumentStructure` /
  `argumentLogicVerdict`, so claim/evidence/warrant remains single-sourced
  across Timed insights, coach context, and the new guided drill. Monroe's
  Sequence adds an ordered deterministic detector over need -> solution ->
  visualization -> action, with the same content-word floor / no-confident-thin
  negative behavior as the other framework checks.
- `DrillCompletionCopy` now has result titles and one-line constructive
  feedback for CEW and Monroe. These verdicts remain copy-only: tests pin that
  divergent structural outcomes do not change XP or success.
- Updated `docs/COACH_REPLACEMENT_SCORECARD.md`: `EXERCISE-5` is now shipped as
  a local continuation and removed from the code-tickable backlog.
- Verified with `git diff --check` and `xcodebuild test -scheme Noum
  -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/FrameworkDrillCheckTests
  -only-testing:NoumTests/FrameworkDrillCatalogTests
  -only-testing:NoumTests/FrameworkDrillCopyAndScoreTests
  -only-testing:NoumTests/ArgumentLogicTests`: `TEST SUCCEEDED`. Result bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_16-13-23-+0100.xcresult`.

Files touched this continuation: `Noum/FrameworkDrillChecks.swift`,
`Noum/DrillSystem.swift`, `Noum/MiniDrillView.swift`, `ReinforcementCopy.swift`,
`NoumTests/NoumTests.swift`, `docs/COACH_REPLACEMENT_SCORECARD.md`,
`handover.md`.

2026-06-08 ~16:08 continuation (local Codex run, real toolchain):

- Closed the stale `AI-CHAT-FALLBACK` backlog row without changing Ask Noum's
  state owner or rendering path. `AICoachChatService` now parses provider text
  through `ChatExtractionResult` so non-truncated empty / unparseable responses
  can use the existing grounded deterministic coach bubble instead of a system
  notice.
- Preserved truncation honesty: provider output stopped by `MAX_TOKENS` /
  `length` remains `.failure(.empty)`, so Noum still refuses to commit a
  guillotined model sentence. The deterministic path continues to be
  quality-gated by `deterministicReplyOutcome` before it reaches
  `AskNoumStore`.
- Updated `docs/COACH_REPLACEMENT_SCORECARD.md`: `AI-CHAT-FALLBACK` is now
  shipped as a local continuation, with the length-truncation caveat kept
  explicit.
- Verified with `git diff --check` and `xcodebuild test -scheme Noum
  -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/AICoachTruncationGuardTests
  -only-testing:NoumTests/AICoachChatDeterministicReplyTests
  -only-testing:NoumTests/AskNoumStoreTests
  -only-testing:NoumTests/AskNoumSpokenModeTests`: `TEST SUCCEEDED`. Result
  bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_16-03-22-+0100.xcresult`.

Files touched this continuation: `Noum/AICoachChatService.swift`,
`NoumTests/NoumTests.swift`, `docs/COACH_REPLACEMENT_SCORECARD.md`,
`handover.md`.

2026-06-08 ~15:56 continuation (local Codex run, real toolchain):

- Closed `OBSERVE+ADAPT-2` through the existing recommendation owners rather
  than adding a new planner. `RecommendationAdaptationAnalyzer` now exposes
  `confidentlyReplaces(mode:in:)` as the shared predicate for deterministic
  recommendation selection.
- `RecommendationBiasContextBuilder.context(...)` accepts defaulted
  `recommendationOutcomes` and threads the existing
  `RecommendationLearningStore` ledger into `RecommendationBiasEngine` for
  Home, the mode picker, and summary "Looking ahead".
- `RecommendationBiasEngine` now biases cold-start / goal-biased visible
  blueprints away from a mode only when the mode-level verdict is confident
  `.replace`; empty ledgers, thin evidence, and `.vary` remain inert. Active
  case-file interventions and IM tone-drill interventions still keep
  precedence.
- Added `.adaptationBias` as a blueprint source and updated Home so cached/live
  AI home recommendations cannot override the deterministic course-change.
  Home's AI cache key now includes the deterministic blueprint key, so stale
  AI rows cannot survive a ledger-driven switch.
- Updated `docs/COACH_REPLACEMENT_SCORECARD.md`: `OBSERVE+ADAPT-2` is now
  shipped-strong and removed from the code-tickable backlog.
- Verified with `git diff --check` before tests and `xcodebuild test -scheme
  Noum -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/NextActionEngineTests
  -only-testing:NoumTests/RecommendationBiasContextBuilderTests
  -only-testing:NoumTests/RecommendationAdaptationAnalyzerTests
  -only-testing:NoumTests/RecommendationBiasCopyContractTests`: `TEST
  SUCCEEDED`. Result bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_15-53-02-+0100.xcresult`.

Files touched this continuation: `Noum/ContentView.swift`,
`Noum/HomeCoachCard.swift`, `Noum/NextActionEngine.swift`,
`Noum/PracticeModeSelectionView.swift`, `Noum/PracticeSupport.swift`,
`Noum/SummaryView.swift`, `NoumTests/NoumTests.swift`,
`docs/COACH_REPLACEMENT_SCORECARD.md`, `handover.md`.

2026-06-08 ~15:40 continuation (local Codex run, real toolchain):

- Refreshed stale rows in `docs/COACH_REPLACEMENT_SCORECARD.md` after checking
  the current `ux-overhaul` code instead of treating old absent/partial rows as
  live backlog. `ARGUMENT-LOGIC`, `CONCISION-OF-MEANING`, and `EXERCISE-7` are
  now recorded as shipped-strong against existing deterministic owners and
  consumers; `EXERCISE-5` now correctly lists PREP, claim/counter, and AREA as
  present while keeping Monroe's Sequence and a dedicated guided CEW drill as
  remaining.
- Corrected the scorecard's old no-toolchain caveats from the prior generated
  host. Local focused suites have run on the iPhone 17 simulator, but full-suite
  breadth, device QA, live-key LLM quality, expert calibration, and longitudinal
  user outcomes remain explicitly unclaimed.
- Verified with `xcodebuild test -scheme Noum -destination 'platform=iOS
  Simulator,name=iPhone 17' -only-testing:NoumTests/FrameworkDrillCheckTests
  -only-testing:NoumTests/FrameworkDrillCatalogTests
  -only-testing:NoumTests/FrameworkDrillCopyAndScoreTests
  -only-testing:NoumTests/ArgumentLogicTests
  -only-testing:NoumTests/ConcisionOfMeaningTests
  -only-testing:NoumTests/TimedInsightArgumentConsumerTests`: `TEST SUCCEEDED`.
  Result bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_15-39-38-+0100.xcresult`.

Files touched this continuation: `docs/COACH_REPLACEMENT_SCORECARD.md`,
`handover.md`.

2026-06-08 ~15:28 continuation (local Codex run, real toolchain):

- Closed the `IM-TONE` scorecard gap without adding a new grader, store, or
  route. `IMToneMatcher.score` now uses bounded per-tone positive and
  contradictory lexical profiles instead of one keyword per tone, preserving the
  existing `>= 7` "tone landed" threshold while letting real commitment offset
  one soft hedge.
- `IMHistorySummary.matches` now delegates to the shared matcher for free-form
  evaluator tone labels: aliases such as "steady and composed" can satisfy
  Calm, while negated or contradictory reads such as "not confident" or "calm
  but rushed" do not inflate the hit rate.
- Updated the IM scenario detail documentation and
  `docs/COACH_REPLACEMENT_SCORECARD.md` so the backlog no longer describes the
  old substring-only matcher as remaining.
- Verified with `git diff --check` and `xcodebuild test -scheme Noum
  -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/IMScenarioToneMatchStatsTests
  -only-testing:NoumTests/IMToneMatcherContractTests
  -only-testing:NoumTests/IMToneDrillSignalTests
  -only-testing:NoumTests/IMConversationEvaluationContractTests`: `TEST
  SUCCEEDED`. Result bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_15-34-04-+0100.xcresult`.

Files touched this continuation: `Noum/PracticeSupport.swift`,
`Noum/IMHistorySummary.swift`, `Noum/IMScenarioDetailView.swift`,
`NoumTests/NoumTests.swift`, `docs/COACH_REPLACEMENT_SCORECARD.md`,
`handover.md`.

2026-06-08 ~15:22 continuation (local Codex run, real toolchain):

- Tightened Home celebration motion: `loadPathCelebrationProof()` now respects
  Reduce Motion when the async proof row lands, setting the proof immediately
  instead of always using `.standardSpring`.
- Added the pure `ContentView.shouldAnimatePathCelebrationProof(reduceMotion:)`
  contract to keep the branch testable.
- Verified with `git diff --check` and `xcodebuild test -scheme Noum
  -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/HomeAccessibilityModalGateTests`: `TEST SUCCEEDED`.
  Result bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_15-18-32-+0100.xcresult`.

Files touched this continuation: `Noum/ContentView.swift`,
`NoumTests/NoumTests.swift`, `handover.md`.

2026-06-08 ~15:17 continuation (local Codex run, real toolchain):

- Fixed the stale root accessibility landmark from `ContentView`: the persistent
  `NavigationStack` now reports `home.screen` only when the path is empty and
  switches to neutral `app.navigationStack` for pushed destinations. Destination
  views keep their own existing root identifiers (`practiceModes.screen`,
  `history.screen`, `profile.screen`, `settings.screen`, etc.), so UI tests and
  VoiceOver no longer see a Home root on every deep-linked screen.
- Added a focused Home accessibility contract test to keep the Home identifier
  root-only.
- Verified with `git diff --check` and `xcodebuild test -scheme Noum
  -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/HomeAccessibilityModalGateTests`: `TEST SUCCEEDED`.
  Result bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_15-13-27-+0100.xcresult`.

Files touched this continuation: `Noum/ContentView.swift`,
`NoumTests/NoumTests.swift`, `handover.md`.

2026-06-08 ~15:10 continuation (local Codex run, real toolchain):

- Surfaced the existing `CoachParityReadiness` spine on Profile as a compact
  "Coach loop" evidence card instead of reviving the old 7-row readiness
  matrix/dashboard. The card appears inside the value-first evidence details
  after coaching direction, reusing `CoachMemoryStore`, `PracticeSessionStore`,
  `RecommendationLearningStore`, `BigMomentStore`, and `CoachCheckInStore` as
  state owners.
- Added `ProfileCoachLoopReadinessContent` so Profile copy is derived from the
  pure readiness model: it summarizes solid or forming coach-loop stages,
  names the next evidence gap, suppresses a true cold start, and keeps
  validation explicitly outside the app rather than claiming parity.
- Added Profile collapse contract coverage for cold start suppression, no
  coach-parity/certified copy, and not counting validation as a solid coaching
  stage.
- Verified with `git diff --check` and `xcodebuild test -scheme Noum
  -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/ProfileCollapseContractTests
  -only-testing:NoumTests/CoachParityReadinessTests`: `TEST SUCCEEDED`. Result
  bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_15-05-48-+0100.xcresult`.

Files touched this continuation: `ProfileView.swift`,
`NoumTests/NoumTests.swift`, `handover.md`.

2026-06-08 ~15:00 continuation (local Codex run, real toolchain):

- Landed `DELIVERY-7` without adding a new analyzer, store, or route. The
  existing `CoachMemory.coachDeliveryRead` remains the source of truth for the
  fused delivery read; `CoachCaseFile.build(from:)` now copies a characterized
  read into additive optional `CoachCaseFile.deliveryRead` so the durable case
  spine carries delivery context across Ask Noum / case-file surfaces.
- Delivery-only case files are now allowed when the read has a real
  `tentativeLine`; `.forming` / thin delivery reads still suppress the line and
  do not fabricate a case-file signal.
- `CoachContextBuilder` now renders the delivery read inside
  `COACH CASE FILE (durable strategy)` and suppresses the older duplicate
  fused-read line in `DERIVED READ TRENDS` when the case file already carries
  it. Legacy memories with `coachDeliveryRead` but no case-file projection
  still fall back to the derived-trends line.
- Updated `docs/COACH_REPLACEMENT_SCORECARD.md` so recently closed backlog
  items no longer appear as absent.
- Verified with `git diff --check` and `xcodebuild test -scheme Noum
  -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/FusedDeliveryReadTests
  -only-testing:NoumTests/CoachContextBuilderTests
  -only-testing:NoumTests/CoachMemoryEngineTests`: `TEST SUCCEEDED`. Result
  bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_14-54-43-+0100.xcresult`.

Files touched this continuation: `Noum/PrimaryFocusMemory.swift`,
`Noum/CoachContextBuilder.swift`, `NoumTests/NoumTests.swift`,
`docs/COACH_REPLACEMENT_SCORECARD.md`, `handover.md`.

2026-06-08 ~14:50 continuation (local Codex run, real toolchain):

- Pushed `ux-overhaul` to `origin` through `87fae03` before continuing.
- Rechecked the roadmap backlog. `PRESCRIBE-3` is already present in code and
  tests: `PrimaryFocusMemory.buildSuccessCriterion` grounds success-bar copy in
  `priorAverage` once the pre-window sample floor is met, with tests for filler,
  score, and below-floor generic copy.
- Landed `SUBSTANCE-4` remainder for the post-rep AI Coach Read without adding a
  new state owner. `AICoachSessionInput` now carries optional
  `standingReviewDueAt` from `CoachCaseFile.reviewDueAt`; `SummaryView` threads
  it from `CoachMemoryStore.currentMemory?.caseFile`; and
  `AICoachService.userPrompt` renders `Review cadence: revisit by ...` inside
  the existing `STANDING CASE` block only when the case file provides it.
- Reused `CoachContextBuilder.caseReviewLabel` for the relative cadence wording
  (`today`, `tomorrow`, `in N days`, overdue), making the helper internal rather
  than duplicating date logic.
- Updated `CoachReadParityTests` for defaulted legacy construction, nil
  omission, standing-case inclusion, byte-identical all-nil prompt behavior,
  fixed-calendar cadence labels, and the system prompt's review-cadence rubric.
- Verified with `git diff --check` and `xcodebuild test -scheme Noum
  -destination 'platform=iOS Simulator,name=iPhone 17'
  -only-testing:NoumTests/CoachReadParityTests` after sandbox escalation:
  `TEST SUCCEEDED`. Result bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_14-45-24-+0100.xcresult`.

Files touched this continuation: `Noum/CoachContextBuilder.swift`,
`Noum/PracticeSupport.swift`, `Noum/SummaryView.swift`,
`NoumTests/NoumTests.swift`, `handover.md`.

2026-06-08 ~11:20 continuation (local Codex run, real toolchain):

- Committed the previously staged auto-stop screenshot handoff as `d110e50`
  (`docs: record latest screenshot handoff`).
- Checked REMEMBER-4 from this handover before editing; it is already present
  in code (`CoachCaseFile.upcomingMomentLine`, `CoachMemoryEngine.build(...,
  upcomingMoment:)`, `SessionFinalizer` threading, and B1 #2 tests).
- Landed TRANSFER-3 on Profile without adding a new store or Home dashboard
  card: `BigMomentTransferTrend` now owns short user-facing Profile copy, and
  `ProfileTransferStatusContent` shows a "Transfer pattern" row once the
  existing reducer crosses the 3-same-kind-report floor. Pending outcome
  check-ins and active prep still take priority; a repeated pattern beats a
  one-off latest outcome. Copy is self-report-only and avoids causal language.
- Added focused Profile contract tests for the trend row and priority order.
- Verified with `xcodebuild test -scheme Noum -destination 'platform=iOS
  Simulator,name=iPhone 17' -only-testing:NoumTests/ProfileCollapseContractTests
  -only-testing:NoumTests/BigMomentTransferStoreTests` after sandbox escalation:
  `TEST SUCCEEDED`. Result bundle:
  `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_11-17-09-+0100.xcresult`.
  `git diff --check` passed. App binary timestamp advanced to Jun 8 11:20:10
  2026.

Files touched this continuation: `Noum/BigMomentStore.swift`,
`ProfileView.swift`, `NoumTests/NoumTests.swift`, `handover.md`.

2026-06-08 ~08:45 continuation (autonomous `noum2` run, real toolchain):

- Closed two trust seams a communications coach cannot have, both verified by
  compile + test (not hand-traced):
  - Offline Ask Noum replies now route through the SAME quality gate as live
    replies via `AICoachChatService.deterministicReplyOutcome(...)`. The gate
    blocks only objective failures (robotic / over-long / defensive / menu /
    fabricated quote / overclaim); a turn-contextual no-anchor miss on a cold
    no-data line is intentionally allowed (the honest "run one more rep" line).
  - Every AI prose surface that quotes the user now routes attributed quotes
    through `ProofMomentService.transcriptContains` (via
    `CoachChatQuoteGuardContext`): added to `PostRepCoachNoteService.generate`
    and `AIInsightsService.insight` (sessionDebrief), which previously had only
    lexical / no quote verification. Unverifiable quote → deterministic
    non-quoting fallback.
- Added `CrossSurfaceQuoteFabricationGuardTests` + new
  `AICoachChatDeterministicReplyTests` cases.
- Verified: BUILD SUCCEEDED; 76/0 on the new+affected suites; 282/0 on a
  regression slice across AICoachChat / PostRepCoachNote / AIInsights /
  ProofMoment / CoachChatEvaluationFixture / BelievableProgressZeroData.
- Ran a 10-agent evaluation workflow; full delta, competitor verdict, ranked
  remaining backlog, and the honest human-gated limitations are in
  `docs/UX_VALUE_OVERHAUL_SESSION_2026-06-08_CONTINUATION.md`. Next code-tickable
  item with a complete authored spec: REMEMBER-4 (persist nearest upcoming
  BigMoment on `CoachCaseFile`).
- Note: Canva MCP is now connected in this environment (prior handover said it
  was unavailable); Figma MCP available but allowance may still be exhausted.

Files touched this continuation: `Noum/AICoachChatService.swift`,
`Noum/AIInsightsService.swift`, `Noum/PostRepCoachNoteService.swift`,
`NoumTests/NoumTests.swift`,
`docs/UX_VALUE_OVERHAUL_SESSION_2026-06-08_CONTINUATION.md`, `handover.md`.

2026-06-08 00:09 commit `a5c19d8`:

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

2026-06-08 07:30 continuation:

- Added a pure `BigMomentTransferTrend` reducer on `BigMomentStore`. It groups
  repeated real-world outcome reports by moment kind and only emits a pattern
  after at least 3 same-kind reports.
- Updated `CoachContextBuilder` so Ask Noum can see a tentative transfer pattern
  before the latest two anecdotes, with explicit self-report / non-causation
  guardrails.
- Widened `CoachReplyPipeline`'s transfer snapshot from 2 reports to the
  bounded outcome cap so the trend reducer has enough history without adding a
  new store.
- Added focused tests for the transfer threshold, same-kind grouping, context
  wording, and no objective-outcome claim.

2026-06-08 08:35 continuation:

- Tightened Iteration 6 trust hardening across AI prose surfaces. Ask Noum's
  deterministic offline fallback now runs through the same `replyQualityIssue`
  gate as live model replies before it renders as a coach bubble.
- Extended the existing `CoachChatQuoteGuardContext` / `ProofMomentService`
  transcript-verification contract to post-rep AI coach notes and
  `AIInsightsService` session debriefs. Attributed "you said ..." quotes that
  cannot be verified now fall back to deterministic non-quoting copy.
- Added `AIInsightsService.containsUnverifiedSessionDebriefQuote(...)` so the
  debrief network path and tests share the same rule. Empty/silent transcripts
  are now treated as "no source to quote," so attributed quotes are rejected
  instead of passing because the branch was skipped.
- Added focused tests for deterministic offline parity, cross-surface fabricated
  quote rejection, verified quote pass-through, non-attributed quoted technique
  copy, and empty-transcript debrief rejection.

Files touched across the recent handover work:

- `Noum/BigMomentStore.swift`
- `Noum/AICoachChatService.swift`
- `Noum/AIInsightsService.swift`
- `Noum/PostRepCoachNoteService.swift`
- `Noum/CoachContextBuilder.swift`
- `Noum/CoachReplyPipeline.swift`
- `Noum/LeagueManager.swift`
- `Noum/LeagueView.swift`
- `Noum/PeakRatingWallView.swift`
- `NoumTests/NoumTests.swift`
- `handover.md`
- `.screenshots/2026-06-08_autostop-de8ee0d-0006/HANDOFF.md`
- `.screenshots/2026-06-08_autostop-a5c19d8-0737/HANDOFF.md`

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
- Ask Noum now receives repeated transfer patterns when the user has at least 3
  same-kind real-world outcome reports. The line is self-report-only and cannot
  claim the app caused the result.
- Quote fabrication guardrails now cover Ask Noum, post-rep coach notes, and
  session debrief insights. Deterministic offline Ask Noum replies also clear
  the live reply-quality gate before rendering.
- Needs simulator/adversarial review across empty state, post-rep seed, weak
  evidence, pushback, and goal-change turns. A fabricated quote is the top trust
  failure; do not weaken `CoachChatQuoteGuardContext`.

Iteration 7 - Profile / transfer:

- Profile is collapsed by default: identity, optional rating hero when evidence
  exists, one coach read, evidence hub.
- Transfer state is now surfaced compactly via `BigMomentStore`, and repeated
  outcome reports can aggregate into a tentative same-kind transfer pattern for
  the coach context. Profile now also surfaces that repeated transfer pattern
  once the same-kind threshold is met, while keeping pending check-ins and
  active prep ahead of it.
- Still needs visual review for Dynamic Type, VoiceOver, thin-data users, and
  whether the expanded evidence disclosure is still too dense.

## Delta to a strong human communications coach

What Noum now does credibly:

- Records real reps and persists a history.
- Detects fillers with semantic/prompt-echo caution.
- Tracks rating, baselines, trends, proof moments, coach memory, and big moments.
- Prescribes one next rep from existing recommendation context.
- Can quote verified user words and use them as proof.
- Has a bounded case-file direction, upcoming-moment awareness, delivery fusion,
  reinforce/vary/replace adaptation, and tentative transfer patterns without
  claiming validation/parity.

Where a human coach is still ahead:

- Perception depth: a human reads breath, tension, posture, eye contact,
  energy, vocal variety, authority, emotional connection, and whether polished
  speech still feels evasive or detached.
- Case formulation: a human asks clarifying questions, notices what the user
  avoids, tests hypotheses live, and revises the read when the user disagrees.
- Intervention quality: a human designs drills against the exact user, room,
  audience, stake, and deadline, not just the detected metric.
- Adaptation: Noum now computes bounded reinforce/vary/replace signals from
  followed reps, but a human still notices qualitative frustration, avoidance,
  or confidence shifts while the drill is happening.
- Transfer: Noum can remember upcoming moments and aggregate repeated
  self-reported outcomes, but a human still follows up in richer context and can
  challenge or reinterpret the user's read of the room.
- Validation: a human coach has externally observable judgment. Noum still
  lacks expert-calibrated evaluation fixtures and longitudinal outcome proof.

High-leverage next product moves:

1. Build a version-controlled evaluation set and compare Noum reads to expert
   coach baselines. Label this "validation substrate", not validation.
2. Run adversarial Ask Noum review over fabricated quote attempts, weak
   evidence, goal changes, transfer claims, and user pushback.
3. Prove the true cold-start loop end to end without UI injection: ask -> speak
   -> first read in roughly 60 seconds.
4. Continue reducing Profile/Settings density while preserving thin-data
   self-suppression and evidence disclosure.
5. Add real-user longitudinal outcome tracking before any parity claim.

## Competitor delta, checked 2026-06-08

Sources:

- Yoodli overview: https://support.yoodli.ai/en/articles/9550461-yoodli-overview
- Yoodli roleplay platform: https://yoodli.ai/
- Yoodli official information: https://yoodli.ai/info-for-ai
- Orai homepage: https://orai.com/
- Orai pricing / training plan: https://orai.com/pricing/
- Speeko homepage: https://www.speeko.co/home
- Speeko subscriptions: https://www.speeko.co/subscriptions
- Speeko App Store: https://apps.apple.com/us/app/speeko-ai-for-public-speaking/id1071468459
- Duolingo Video Call with Lily: https://blog.duolingo.com/video-call/
- Duolingo Video Call with Falstaff: https://blog.duolingo.com/beginner-video-call-with-falstaff/
- Duolingo Android expansion release: https://investors.duolingo.com/news-releases/news-release-details/duolingo-launches-ai-powered-video-call-android

Yoodli:

- Strength: strong roleplay surface for pitches, presentations, interviews,
  sales calls, difficult conversations, multi-persona panels, and video-call
  coaching. Enterprise GTM, analytics, integrations, and team/coach workflows
  are ahead of Noum.
- Noum edge: iOS-native private coach identity, durable personal memory,
  verified quote/proof moments, pressure/filler coaching, and a more intimate
  single-player coach relationship.
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
  coach content. Its pricing page also makes free/basic vs Pro value visible
  with real-time guidance and premium exercises.
- Noum edge: stronger coaching-memory ambition, pressure modes, verified proof,
  and personal case formulation.
- Gap to close: Speeko's real-time "speaker coach when you need one" clarity
  and delivery-sensing breadth.

Duolingo:

- Strength: personality, retention design, path habit, and low-pressure AI
  conversation practice through Lily and the newer coached Falstaff calls. It
  makes speaking feel playful, frequent, and approachable.
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
- `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination "platform=iOS Simulator,id=3D077053-2981-4C5D-819D-FF6F9BA8AD06" -derivedDataPath ./DerivedData/Noum -only-testing:NoumTests/BigMomentTransferStoreTests -only-testing:NoumTests/CoachContextBuilderBigMomentTests`
  succeeded.
- `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination "platform=iOS Simulator,id=3D077053-2981-4C5D-819D-FF6F9BA8AD06" -derivedDataPath ./DerivedData/Noum-AIGuard -only-testing:NoumTests/AICoachChatDeterministicReplyTests -only-testing:NoumTests/AICoachChatReplyQualityGateTests -only-testing:NoumTests/CrossSurfaceQuoteFabricationGuardTests -only-testing:NoumTests/AIInsightsPromptAnchorTests`
  succeeded. Used the separate `Noum-AIGuard` DerivedData path because the
  default repo-local `DerivedData/Noum` build database was locked by an earlier
  process; no cleanup or process kill was performed.
- `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination "platform=iOS Simulator,id=3D077053-2981-4C5D-819D-FF6F9BA8AD06" -derivedDataPath ./DerivedData/Noum-AIGuard -only-testing:NoumTests/PostRepCoachNoteServiceDeterministicTests -only-testing:NoumTests/PostRepCoachNoteToneTrajectoryTests -only-testing:NoumTests/PostRepCoachNoteToneResolvedTests`
  succeeded after the AI note fabrication guard change.
- `.agents/skills/noum-screenshots/capture.sh` captured five tab tops to
  `.screenshots/2026-06-08_autostop-de8ee0d-0006/`.
- `.agents/skills/noum-screenshots/capture.sh` captured the 07:34 build's five
  tab tops to `.screenshots/2026-06-08_autostop-a5c19d8-0737/`.
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
