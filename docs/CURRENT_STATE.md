# Noum — Current state

## 2026-07-11 — Home, practice, and Path production polish

Branch `codex/home-practice-path-polish` closes the simulator-visible quality
regressions from the cohesive UI pass without changing practice state machines
or state ownership. Home now uses its coaching gradient as the full tab canvas,
with one immersive action and quiet supporting rows instead of a gradient card
floating in empty space. Daily-goal celebration is event-driven: hydration and
app entry can never present it, while a newly completed rep may show one brief,
nonblocking rhythm receipt once per day.

All countdowns used by Filler Control, Pressure Drill, Cut the Crutch, and Pace
Training share a full-screen focused cue. Filler Control starts its elapsed clock
only after transcription actually begins, so missing simulator credentials return
to pristine setup with a readable status rather than exposing the legacy metrics
dashboard. The shared focused header stacks at accessibility text sizes. Train's
library has distinct Speaking drills, Conversation practice, and Learn and build
groups. Path replaces the cairn and bright pennant with grounded footprints and a
quiet trail marker, and its larger trees now scale naturally toward the viewer.

Simulator-only infrastructure is explicit: App Check uses the debug provider on
simulator builds, and `scripts/run-noum-with-ai.sh` forwards gitignored Deepgram,
Google Speech, AI, and optional App Check debug values through `SIMCTL_CHILD_*`.
No provider values are bundled or persisted by this change.

## 2026-07-11 — communication curriculum expansion

Branch `codex/communication-curriculum-expansion` extends the existing Lessons
and Roleplay state owners into a broader communication-learning loop. Lessons
grow from 5 to 12 across delivery, structure, conversation, explanation, and
rhetoric, adding active listening, question quality, closed-loop understanding,
plain explanation, feedback, boundaries, and repair. Apply steps now use
visible deterministic criteria with in-place retry instead of treating any
12-word non-rhetorical transcript as success. Successful rounds count toward
retention only when their expanding review interval is due; later rounds vary
the prompt, and each lesson ends with one real-world transfer task. Legacy
lesson progress decodes additively with an inferred review anchor.

Roleplay grows from 4 to 8 scenarios with feedback, boundary, trust-repair, and
discovery conversations. `RoleplayEngine` remains the single deterministic
owner and adds shared listening, ownership, inquiry, and constructiveness axes
beside directness, evidence, and composure. No practice state machine, Fast or
Ultra transport, session model, deep link, backend contract, or duplicate store
is introduced. Research rationale and honesty boundaries live in
`docs/COMMUNICATION_CURRICULUM_RESEARCH.md`.

_Last updated: 2026-06-04 (M24 deferred slate round 41 — TONE-DRILL SOLVED freshness window for the chat-coach context block on branch `Redesign`. `IMHistorySummary.toneDrillResolved(from:)` returns the resolved read FOREVER once a scenario crosses the drill bar — correct for the recommendation engine's persistence-of-victory contract, but surfaced verbatim into the chat-coach context block since round 13, it meant the chat coach read the same TONE-DRILL SOLVED section on every reply for months after the crossing — beating a dead horse on a win the user closed weeks ago, exactly the register a human coach moves past. Round 41 closes the gap with a new `CoachContextBuilder.toneDrillSolvedRecencyDays: Int = 14` static constant + `static func toneDrillSolvedIsFresh(_:now:) -> Bool` pure predicate (guards `elapsed >= 0` then checks `elapsed <= TimeInterval(14 * 86_400)`, defensive negative-elapsed guard) + a one-clause additive gate on the existing `if let resolved = IMHistorySummary.toneDrillResolved(from: sessions)` block in `userContext` that ALSO requires `sessions.lazy.map(\.date).max()` (the user's most-recent rep) to be inside the 14-day window. Anchored against the user's own cadence (not wall-clock) so the predicate is pure, intrinsically test-stable, and reads as "fresh relative to the user's cadence" — a user actively practicing other scenarios deserves the win named for longer; a user who's stopped practicing entirely sees the win age out at 14 days flat. Mirrors `repeatedPushbackRecencyDays = 14` from round 38 by deliberate cross-surface symmetry — the cross-surface-constants test pins both equal so a future tune of one forces consideration of the other. Inclusive 14-day boundary (`predicateFiresAtExactRecencyBoundary` + `predicateDropsJustBeyondRecencyBoundary` pin both halves). PURE-CONTEXT surface only: no engine state change, no recommendation-blueprint change, no hero-ribbon/post-rep-note change, no schema bump, no view changes. The line's own guidance ("name the win once and point them at the next target rather than re-prescribing the solved drill") had been a soft prompt to the model since round 13; the freshness gate is the hard structural backstop — past the window, the context simply doesn't carry the SOLVED section, so the chat coach moves on whether the model remembered to or not. New `@MainActor @Suite("ToneDrillSolvedFreshnessTests")` (11 `@Test` methods + 2 private fixture helpers) pins the pure predicate on every branch (happy / boundary / outside / defensive negative-elapsed), the userContext integration on fresh / stale / boundary states (both halves of the 14-day boundary pinned structurally end-to-end), the round-13 TRAJECTORY-and-SOLVED coexistence contract preserved across the freshness gate, AND the cross-surface-constants symmetry with `repeatedPushbackRecencyDays`. Sessions persisted before round 41 read correctly through the predicate automatically. Vision: coach-parity stage #3 (Intervention — moving on to the next target) + stage #4 (Adaptation — closing the feedback loop on the time axis) + pillar #5 (Personalized coaching — chat-coach cadence-aware on the win surface) + pillar #4 (Believable progress — the win still exists across every other surface; only the chat-coach context is narrowed). Files: `Noum/CoachContextBuilder.swift` (+`toneDrillSolvedRecencyDays` constant + `toneDrillSolvedIsFresh(_:now:)` predicate + one-clause additive gate on the existing TONE-DRILL SOLVED `if let` in `userContext`), `NoumTests/NoumTests.swift` (+11 tests in new `ToneDrillSolvedFreshnessTests` suite), `HANDOFF.md`, `docs/CURRENT_STATE.md`. Branch `Redesign`. Build-host caveat unchanged: no Xcode/Swift toolchain here, so NOTHING was compiled or run; the predicate mirrors the round-38 `interventionUnderRepeatedPushbackApplies` shape line-for-line and the `userContext` gate adds ONE clause to an existing condition, so a real `xcodebuild test --filter ToneDrillSolvedFreshnessTests` + a glance at a once-resolved scenario aged past 14 days from the user's most-recent rep on simulator (confirm the chat-coach context no longer carries TONE-DRILL SOLVED while the hero ribbon and the post-rep note are preserved verbatim) is still wanted before TestFlight. Previously: M25 coach-parity sprint — six features pushing toward the VISION coach-parity loop, EACH built + compiled + unit-tested + committed on branch `Redesign`, with the FULL `NoumTests` suite green (1744 tests, exit 0) on Xcode 26.3 / iPhone 17 Pro sim — unlike the prior logic-only rounds, this work is verified, not hand-traced. (F4a) Acknowledgement chips on the Profile `CaseReviewCard` (confirm/question/reject the working hypothesis via the SAME `CoachMemoryStore.noteHypothesisAcknowledgement` path AskNoum uses — no parallel state; additive `onAcknowledge` closure so previews/other call sites render the read-only card unchanged; pure static `hasUnacknowledgedHypothesis`/`acknowledgedEcho` helpers + 5 tests). (F3) User-facing `DeliveryProfile` (recurring pattern / what improved / what breaks under pressure / next target) composed from the EXISTING Composure/ConfidenceMarker/`DerivedReadsTrendEngine` reads + a Sudden-Death-vs-baseline pressure split, persisted on `CoachMemory` beside `coachDeliveryRead` (survives the post-hoc caseFile mutators) and surfaced as `DeliveryProfileCard` in the Profile Coaching cluster — never labels the person, self-suppresses below evidence floor (nil → card omitted); 8 tests. (F1) Weekly bidirectional `CoachCheckInStore` (what was hardest / where it showed up outside the app / drill helped-stalled-missed) on a no-nag 7-day cadence, account-scoped persistence + auth reload/endSession wiring mirroring `BigMomentStore`, feeding a WEEKLY CHECK-IN context section + a `WeeklyCheckInCard`/sheet shown only when due (ruled out SessionReflectionStore/CoachMemoryStore/BigMomentStore as owners; 'what's coming next' deliberately NOT duplicated — BigMomentStore stays its owner); 6 tests. (F4b) Enriched `BigMomentOutcomeReport` with a structured `ReportedDrillTransfer` ('did your prep carry over?') flowing additively into BOTH the AI context (`coachContextLine`) and the case file (`CoachTransferReview.reportedOutcomeLine`), strict no-causation ('they felt their prep carried', never 'the drill caused'), backward-compat decode; 4 tests. (F2) Extended the EXISTING `PrepSessionPlanner`/`PrepSessionView` rehearsal (the audit mislabeled it 'not started' — it existed) with a `PrepSessionReadiness` read (which rehearsal shapes the user has run since the moment was set → notStarted/underway/rehearsed, an honest snapshot never a pass/fail) + a 'Where you stand' card + a BIG MOMENT rehearsal-readiness context line so Ask Noum nudges the remaining rehearsal; 6 tests. (F5) `CoachParityReadiness` instrumentation — per-user evidence-depth across all 7 loop stages (diagnose/formulate/prescribe/observe/adapt/transfer/validate) where VALIDATION is STRUCTURALLY CAPPED at `.forming` (no code branch returns `.earned` — the app never self-certifies parity), driving a COACHING READINESS claim-scaling block in the coach context ('never claim coach-parity/validation') + a 'How well Noum knows you' card; 6 tests. Adversarial audit verdicts: honesty 9.5/10 (the validation cap is a missing branch not a runtime check; causation genuinely avoided; no person-labeling; cards self-suppress rather than render empty shells), coaching CAPABILITY ~8/10 (the relational + transfer + honest-self-assessment stages are now real, surfaced, and the loop is coherent end-to-end; the gap to 9 is PERCEPTION DEPTH — delivery sensing is still ~4 baseline-relative audio channels with no prosody-contour/breathing/emphasis and no opt-in visual presence, VISION roadmap #2/#4; `VideoAnalysisService` exists but is THIN/orphaned — frame-to-Vision/LLM, wired to Summary display only, not to coach memory), and VALIDATED human-coach REPLACEMENT ~2.5/10 which structurally CANNOT move without real users + longitudinal outcomes + blinded professional-coach calibration (VISION stage 7 / roadmap #5) — a real-world gap by design, not a code gap. Device QA still wanted for the new SwiftUI surfaces before TestFlight. Files: `Noum/CaseReviewCard.swift`, `Noum/DerivedReadsTrend.swift`, `Noum/DeliveryProfileCard.swift`, `Noum/CoachCheckInStore.swift`, `Noum/WeeklyCheckInCard.swift`, `Noum/BigMomentStore.swift`, `Noum/BigMomentOutcomeInlineCard.swift`, `Noum/PrepSessionPlanner.swift`, `Noum/PrepSessionView.swift`, `Noum/CoachParityReadiness.swift`, `Noum/CoachParityReadinessCard.swift`, `Noum/CoachContextBuilder.swift`, `Noum/PrimaryFocusMemory.swift`, `Noum/AskNoumView.swift`, `Noum/AuthManager.swift`, `ProfileView.swift`, `NoumTests/NoumTests.swift`, `docs/CURRENT_STATE.md`, `docs/COACH_PARITY_CLAUDE_BRIEF.md`. Previously: M24 deferred slate round 20 — SOLVED ribbon on the hero score card, closing round-19 "Future move" #1 (the same item that rolled forward from rounds 16–19). Round 14 already taught the post-rep `CoachReadCard` (prose) to *headline* the IM tone-drill SOLVED win on the crossing rep — the rep that pushes a scenario's hit rate from "below the 40% drill bar" to "holding above the 60% hold bar." That landed the win in the coach's voice, but a user who skims the score ring and stops there never saw the SOLVED moment named visually; the `LookingAheadCard` / `HeroScoreCard` moved silently to the next focus. Round 20 surfaces the same moment as a quiet mode-tinted capsule on the hero — making it unmissable without competing with the score ring. The crossing-detection primitive (`IMHistorySummary.toneDrillResolved`) + its 12 tests in `IMToneDrillResolvedTests` have been in place since round 13; surfacing it on the hero is a pure addition. `HeroScoreCard` grows an additive `var toneDrillResolvedRibbon: ToneDrillResolvedRibbon? = nil` (default-nil so every existing call site keeps compiling and renders the pre-round-20 descriptive-only hero), a nested `ToneDrillResolvedRibbon: Equatable` value type carrying `scenarioTitle: String` + `toneTitle: String` (two display strings so the renderer doesn't depend on the iOS-17-gated `IMHistorySummary` / `IMToneDrillResolved` types — the owning view does the lookup, the card stays pure presentation; Equatable so SwiftUI's diff-aware re-renders treat a stable scenario+tone pair as equal and the capsule doesn't flicker on parent re-renders), a testable `shouldShowToneDrillResolvedRibbon: Bool` predicate, and a testable `toneDrillResolvedRibbonLabel: String?` property returning `"Solved · \(toneTitle) tone in \(scenarioTitle)"` (e.g. "Solved · Calm tone in Difficult Conversation") — mirrors the post-rep coach-note's `Your <tone> tone in <scenario> is solved` phrasing but compressed to a chip label: names the outcome as observed hit rate, never claims a drill *caused* the win, never re-prescribes. Body branches: when the label is non-nil, the card renders a `HStack` row between the score ring and the headline with `checkmark.seal.fill` glyph + the label, both in `AppColor.modeIM` tint, with a 0.10-alpha IM-tinted capsule background, accessibility identifier `summary.hero.toneDrillSolvedRibbon`. `SummaryView` grows a `heroToneDrillResolvedRibbon: HeroScoreCard.ToneDrillResolvedRibbon?` computed property performing the crossing detection — mirrors `PracticeSessionFinalizer.recordPostRepCoachNote`'s crossing logic byte-for-byte (same `IMModeAvailability` + `#available(iOS 17.0, *)` guards as `imToneDrillSignal`; only `imConversationDetails != nil` reps can resolve; `sessions = sessionStore.sessions`, `priorSessions = sessions.dropFirst()`; `resolvedNow != nil && resolvedBefore == nil` predicate isolates the crossing rep — a scenario already solved before this rep stays quiet, a genuine relapse-then-reclear correctly reads as a new crossing). The `HeroScoreCard` call site in `expandableDetailsSection` threads `heroToneDrillResolvedRibbon` through as the new last argument. 6 new tests in a new `HeroScoreCardToneDrillRibbonContractTests` struct (defaultInitOmitsRibbonForBackCompat — locks the additive default so existing `HeroScoreCard` call sites stay compiling; wiringRibbonEnablesRender — pins the predicate the body reads; ribbonLabelShapeNamesToneAndScenario — pins the per-scenario/per-tone label shape across all 4 scenarios × 6 tones = 24 combinations, asserts the label contains both names AND leads with "Solved"; ribbonLabelHasNoUrgencyOrFanfare — brand-voice contract: no exclamations, "let's", "now", "hurry", "amazing", "nailed", "crushed", locked across 4 representative pairs; ribbonStaysHiddenWhenNotWired — explicit-nil keeps both gates honest separately from the default-omits case; ribbonValueTypeEquatability — same scenario+tone compares equal, different scenario compares unequal, different tone compares unequal so SwiftUI's diff-aware re-renders don't flicker). The visual treatment stays deliberately restrained (mode-tinted capsule, in register with the existing "Toward your <voice>" chip on LookingAheadCard and the "Best this week" chip on the per-mode breakdown cards) because the comment from rounds 16–19 was that the *visual treatment* wants device QA, not the closure-pass itself; this round ships the smallest possible ribbon that signals "you just closed the gap the coach has been working on with you" without competing with the score ring. Vision: pillar #5 (Personalized coaching) — round 14 named the SOLVED win in the coach's voice; round 20 surfaces it as a visual tag on the hero so the user who skims the score ring still sees the moment named; coach-parity stage #4 (Adaptation) — the user sees the arc "drill prescribed → drill recovering → drill solved" across rounds 11–13 (Adaptation trajectory) + round 14 (note headlining) + round 20 (visual ribbon). Anti-drift hygiene noted: the crossing predicate now lives in two places (finalizer for note, summary for ribbon) — tracked as round-20 future move #1 (lift the crossing helper into a static `IMHistorySummary.toneDrillCrossing(in:scenario:)` so both surfaces call into one tested point, exactly the same hygiene move round 17 made for `SummaryLookingAheadRouter`). Files: `Noum/SummaryCards.swift` (+`toneDrillResolvedRibbon` field, +nested `ToneDrillResolvedRibbon: Equatable` value type, +`shouldShowToneDrillResolvedRibbon` predicate, +`toneDrillResolvedRibbonLabel` property, opt-in capsule body branch between score ring and headline, doc-comment), `Noum/SummaryView.swift` (+`heroToneDrillResolvedRibbon` computed property with crossing detection, `HeroScoreCard` call site adds one argument), `NoumTests/NoumTests.swift` (+6 tests), `HANDOFF.md`, `docs/CURRENT_STATE.md`. Branch `Redesign`. Build-host caveat unchanged: no Xcode/Swift toolchain here, so NOTHING was compiled or run; the additive opt-in mirrors `LookingAheadCard.onStart`'s default-nil shape (round 19) and the crossing detection mirrors the finalizer's crossing logic byte-for-byte. Previously: M24 deferred slate round 19 — wired `SummaryLookingAheadRouter` into `LookingAheadCard` with an opt-in subordinate launch CTA, closing round-18 "Future move" #1 (the same item that rolled forward from rounds 16 and 17). The post-rep "Looking ahead" card already named the recommended next mode and explained why, but the user had no way to act on it from the card — they had to back out of the summary and find the mode picker manually. The router and its 13 tests have been in place since rounds 16–17, so the wire-up is a pure addition: every branch (IM with scenario+tone re-arming, IM nil-pair fallback to picker, IM-unavailable fallback to Timed, plain Timed/SD/Ah-Counter) is already locked. `LookingAheadCard` grows an additive `var onStart: (() -> Void)? = nil` (default-nil so every existing call site — including all 6 `LookingAheadCardVoiceAlignmentTests` — keeps compiling and renders the pre-round-19 descriptive-only card), a testable `shouldShowStartCTA: Bool` predicate, and a testable `startCTALabel: String` property reading through `PracticeMode.displayLabel` (so a future rename of the canonical helper propagates to the CTA without a manual sync). The body branches: when `onStart` is non-nil, it appends a `Button { onStart() } label: { ... }` row beneath the voice-alignment chip with `arrow.forward.circle.fill` + `startCTALabel`, both rendered in `AppColor.tint(for: hint.mode)` with a 0.10-alpha mode-tinted capsule background, `buttonStyle(.plain)`, accessibility identifier `summary.lookingAhead.startCTA`. `SummaryView` grows a `var onStartLookingAhead: ((AppDestination) -> Void)?` field; `expandableDetailsSection` threads the closure via `onStartLookingAhead.map { callback in { ... } }` so nil-in → nil-out, and when wired the inner closure computes the destination per-tap via `SummaryLookingAheadRouter.destination(for: summaryRecommendation, imAvailable: IMModeAvailability.isAvailable)`. The router is the exact same one `HomeCoachCard.destination()` (round 18) and `ContentView.practiceAppDestination(for:)` (round 17) call into, so all three launch surfaces produce the same destination for the same data shape — IM-unavailable fallback to Timed lands once and propagates everywhere. Path-based init wires `onStartLookingAhead` with the same pop-then-push shape as `onPracticeAgain`: `SummaryDataStore.remove(for: payloadId)`, pop up to 2 entries (summary + prior practice), `.asyncAfter(0.05)`, push the destination — same UX contract (the user is launching a NEW rep so the stale summary shouldn't be reachable via the back chevron). 6 new tests in a new `LookingAheadCardStartCTAContractTests` struct (defaultInitOmitsStartCallbackForBackCompat — locks the additive default so existing voice-alignment tests stay compiling; wiringCallbackEnablesCTARender — pins the predicate the body reads; startCTALabelMatchesModeDisplayLabel — pins per-mode copy through the canonical helper for all 4 modes; startCTALabelHasNoUrgencyOrFanfare — brand-voice contract: no exclamations, "let's", "now", "hurry", locked across all 4 modes; callbackInvokesOnTap — locks the zero-arg closure signature; ctaShowsAcrossEveryMode — gate predicate is mode-agnostic). The visual treatment stays deliberately restrained (mode-tinted capsule, in register with the existing "Toward your <voice>" chip) because the comment from rounds 16–18 was that the *visual treatment* wants device QA, not the closure-pass itself; this round ships the smallest possible CTA that signals "tap to start" without competing with the drill CTA above the disclosure. Vision: pillar #5 (Personalized coaching) — a coach who tells you "your next session should be X" doesn't walk out without handing you the door; coach-parity stage #3 (Intervention) — the user can act on the prescription in the same beat the coach delivers it. Anti-drift hygiene held — router stays the single source of truth for the mode → destination mapping across all three launch surfaces. Files: `Noum/SummaryCards.swift` (+`onStart` field, `shouldShowStartCTA` predicate, `startCTALabel` property, opt-in body branch, doc-comment rewrite), `Noum/SummaryView.swift` (+`onStartLookingAhead` field, `expandableDetailsSection` threading, path-init wiring), `NoumTests/NoumTests.swift` (+6 tests), `HANDOFF.md`, `docs/CURRENT_STATE.md`. Branch `Redesign`. Build-host caveat unchanged: no Xcode/Swift toolchain here, so NOTHING was compiled or run; the additive opt-in mirrors `Hint.styleGoal`'s default-nil shape (round 14 in the M14 chain) and the path-init wiring mirrors `onPracticeAgain` byte-for-byte, but a real `xcodebuild test` + a glance at the card on simulator (confirm CTA renders, tap navigates correctly, back chevron doesn't land on stale summary, IM-unavailable falls back to Timed) is still wanted before TestFlight. Previously: M24 deferred slate round 18 — collapsed `HomeCoachCard.destination(for: mode)` into a zero-arg `destination()` helper, closing round-17 "Future move" #3. After round 17, the helper was already a one-liner that ignored its `mode` argument entirely — it called `SummaryLookingAheadRouter.destination(for: recommendationBlueprint, imAvailable: IMModeAvailability.isAvailable)`, and the router reads `recommendedMode` straight off the blueprint. The `mode` argument at the single call site (`beginRecommendedRep()`) was always `recommendedMode` (a local rebinding of `recommendationBlueprint.recommendedMode`), so the parameter was dead weight *and* a small silent-drift hole: nothing in the type system stopped a future caller from threading a different `PracticeMode` than the blueprint says, producing a launch that disagrees with the recommendation the user just tapped. Round 18 removes the parameter (`destination(for: mode) -> AppDestination` → `destination() -> AppDestination`), updates the single caller (`navigationPath.append(destination(for: mode))` → `navigationPath.append(destination())`), and rewrites the helper's doc-comment to name *why* the signature is now zero-arg. Doc-comments in `PracticeSupport.swift` (the `SummaryLookingAheadRouter`-level comment that named the two call sites) and `NoumTests/NoumTests.swift` (the `imRecommendationFallsBackToTimedWhenImUnavailable` test comment that mirrored the old `HomeCoachCard.destination(for:)` signature) updated to the new shape. No new tests — the round-17 13 tests in `SummaryLookingAheadRouterTests` still exercise the router as a pure function and don't depend on the helper signature. Behavior unchanged across all four modes × IM-availability states (the helper still delegates to the same router with the same arguments). Pure refactor, no SwiftUI surface visible to the user, no new persistent state, no new AI surface — which is why it could ship without device QA while the closure-pass UI wire-up of round-16 "Future move" #1 still waits for hardware. Previously: M24 deferred slate round 17 — collapsed the duplicate destination-mapping in `HomeCoachCard.destination(for:)` and `ContentView.practiceAppDestination(for:)` through `SummaryLookingAheadRouter`, closing round-16 "Future move" #2. Three surfaces (home coach card recommendation, mode-picker suggestion tile, and — once round-16 "Future move" #1's closure-pass UI lands — the post-rep `LookingAheadCard`) all computed the same launch destination from the same shape of data with three hand-aligned switches over `PracticeMode`. New lower-level overload `SummaryLookingAheadRouter.destination(for:scenario:tone:imAvailable:)` in `PracticeSupport.swift` takes the three fields the router actually reads (`mode`, optional `scenario`, optional `tone`) explicitly so callers that hold this data on a value type other than `RecommendationBiasBlueprint` (specifically: `ContentView`'s private `PracticeSuggestion`) can route through the same logic without building a blueprint just to throw it away. The blueprint overload is now a one-line delegation into the lower-level form. `HomeCoachCard.destination(for: mode)` collapses to a single `SummaryLookingAheadRouter.destination(for: recommendationBlueprint, imAvailable: IMModeAvailability.isAvailable)` call; `ContentView.practiceAppDestination(for: suggestion)` collapses to a single `SummaryLookingAheadRouter.destination(for: suggestion.mode, scenario: suggestion.recommendedScenario, tone: suggestion.recommendedTone, imAvailable: IMModeAvailability.isAvailable)` call (theme-caching side effect — seeding `timedPractice.selectedTheme` from `suggestion.suggestedTheme` when the mode is Timed — stays outside the router as a suggestion-specific concern, not part of the destination contract). 7 new tests in `SummaryLookingAheadRouterTests` lock the lower-level overload across all four modes × scenario/tone presence × availability states, plus a `blueprintAndLowerLevelOverloadsAgree` parity test that pins all 32 mode × scenario/tone × availability combinations stay byte-identical between the two forms — so the home coach card and the ContentView suggestion tile can't silently diverge from the post-rep `LookingAheadCard`'s launch destination. Pure refactor, no SwiftUI imports added, no new dependencies between files, no user-visible surface change — behavior is byte-identical to the prior three switches. The closure-pass UI wire-up for round-16 "Future move" #1 (the `LookingAheadCard` interactive CTA) stays deferred for real-device QA and now has exactly *one* tested switch to call through instead of three to coordinate. Round 16 was — pure router for the post-rep "Looking ahead" recommendation launch: the Track-1 pre-work for round-15 "Future move" #1. The `LookingAheadCard` on the post-rep Summary already reads from `summaryRecommendation` (`RecommendationBiasEngine.blueprint(...)`), and the blueprint carries `recommendedScenario` + `recommendedTone` whenever the tone-drill signal fires — but the card itself is descriptive, not tappable, so the user has no way to launch directly into the prescribed scenario from there. Wiring the closure-pass + subordinate CTA on the card wants device QA this build host lacks; locking the *destination contract* the closure-pass will call through doesn't. New pure router `SummaryLookingAheadRouter.destination(for:imAvailable:)` in `PracticeSupport.swift` (placed directly below `SummaryPracticeAgainRouter`, next to `AppDestination`) maps a `RecommendationBiasBlueprint` to the destination launching the recommendation should push: IM mode threads `recommendedScenario` / `recommendedTone` through to `.imPractice(scenario:tone:)` when `imAvailable` is true, falls back to `.timedPractice` when IM Mode is unconfigured (mirroring the existing fallbacks in `HomeCoachCard.destination(for:)` and `ContentView.practiceAppDestination`). Goal-biased IM recommendations with nil scenario/tone still route to `.imPractice(nil, nil)` — the picker stays the safe default, no substitution to Timed. Timed / Sudden Death / Ah-Counter recommendations route to their plain practice destinations regardless of the IM fields on the blueprint or the availability flag. Six new tests in `SummaryLookingAheadRouterTests` lock every branch: IM with scenario+tone re-arms both, IM with nil pair routes to the picker, IM with `imAvailable == false` falls back to Timed *even when* scenario+tone are set, and Timed / Sudden Death / Ah-Counter each route to their plain practice destinations under both availability states. The router doc-comment names the two duplicate destination-mappers (`HomeCoachCard.destination(for:)`, `ContentView.practiceAppDestination(for:)`) so a future round can collapse them through the shared router without re-deriving the call sites. The closure-pass UI wire-up of `LookingAheadCard` is still deferred for device QA but reduces to a one-liner once a build host is available. Pure-router + tests work, no device QA. Prior round (15) — Practice Again preserves the just-finished IM scenario + tone: closes round-14 "Future move" #2. The post-rep Summary's "Practice Again" CTA was hard-coding `imPractice(scenario: nil, tone: nil)` for IM reps even though the finished rep's `IMConversationDetails.setup` already carries the exact pair the user just ran. The picker reappearing every rep is friction the other modes never inflict — Timed, Sudden Death, and Ah-Counter all relaunch their own surfaces clean. New pure router `SummaryPracticeAgainRouter.destination(for:imSetup:)` in `PracticeSupport.swift` (next to `AppDestination`) carries the IM setup through to `.imPractice(scenario:tone:)`; the non-IM modes ignore any setup passed alongside them so the cross-pollination can't happen. `SummaryView.swift` path-based init captures `entry?.imConversationDetails?.setup` once and threads it into the router on tap. Five new tests in `SummaryPracticeAgainRouterTests` lock the contract: IM rep re-arms scenario + tone, IM rep without setup falls back to the picker (the safe default), and Timed / Sudden Death / Ah-Counter each route to their plain practice destinations regardless of whether an IM setup is passed in. Pure-router + closure-wiring work, no device QA. Prior round (14) — headline the tone-drill WIN in the post-rep coach note: closes round-13 "Future move" #1. Round 13 threaded the resolved read into Ask Noum, but the post-rep `CoachReadCard` still only spoke to a drill *in flight* (recovering/slipping). A human coach who pushed you on a tone for weeks names the win once the moment it finally holds, then moves you on — so this round gives the post-rep note that read, gated to fire on the crossing rep only. New per-scenario overload `IMHistorySummary.toneDrillResolved(from:scenario:)` (the existing cross-scenario scan now maps over it) is the primitive the finalizer needs: `PracticeSessionFinalizer` compares the just-finished scenario's resolved read with vs. without this rep — resolved now AND not a rep ago means THIS rep closed the gap, so the win headlines exactly once and never repeats on later reps (a genuine relapse-then-reclear correctly reads as a new crossing). New `PostRepCoachNoteInput` SOLVED trio (`imToneDrillResolved` + scenario/tone titles), set only on the crossing rep; a top-of-chain branch in `metricSentence` that outranks even a personal best (a closed prescribed-drill loop is the rarer, higher-trust signal), rendered by new voice-shaped `imToneResolvedSentence` ("Your calm tone in Difficult Conversation is solved — 0% to 100%, holding now. Target met; next one's open.") which names the outcome as observed hit rate, never claims a drill caused it, never re-prescribes; plus a `SOLVED this rep` momentum line in the AI prompt carrying the same honesty guidance. 9 new tests (`IMToneDrillResolvedTests` +4: per-scenario matches cross-scenario, scoped-nil-for-other-scenario, crossing fires-once-not-before, no-repeat-after-crossing; `PostRepCoachNoteToneResolvedTests` +5: win headlines the note, outranks personal best, honest fall-through, all-voice clean + budget). Pure-helper + deterministic-copy work, no device QA. Prior round (13) — surface the tone-drill WIN, not only the in-flight drill: closes round-12 "Future move" #3. Rounds 9–12 taught the recommendation card AND the two coach surfaces (Ask Noum + post-rep note) to adapt to a tone drill *while it is still failing* (`IMHistorySummary.toneDrillSignal`/`toneDrillProgress` both fire only sub-40%). But both self-clear the moment a scenario climbs past the drill bar — correct for the recommendation engine, but it left the coach silent at exactly the moment the user closed the gap. New pure helper `IMHistorySummary.toneDrillResolved(from:)` is the complement: it fires only on genuine turnaround evidence — an earliest window below the drill bar (a real gap existed), a latest window holding at/above the new `toneDrillResolvedHoldRate` (0.6 — "held, not scraped over"), and an overall rate at/above the drill bar so the active drill has already cleared (so "solved" and "still drilling" can never both fire for one scenario; they CAN co-exist across two). Returns the single freshest win (most-recent evaluated rep first, tiebreak by larger climb then more evidence). New type `IMToneDrillResolved` (PracticeSupport). Threaded into Ask Noum: `CoachContextBuilder.userContext` appends a `TONE-DRILL SOLVED` section (new helper `toneDrillResolvedLines(for:)` — same citeable register as the trajectory lines, "0% to 100% … holding above the drill bar now" + guidance to name the win once and move to the next target), and system-prompt intelligence-floor rule #9 forbids re-prescribing a solved drill or claiming causation. 12 new tests (`IMToneDrillResolvedTests` — turnaround detection + five negative paths: empty, too-thin, never-struggled, still-active-drill, bouncy-recent + freshest-win selection + constant boundary; `ToneDrillResolvedContextTests` — line shape, end-to-end surfacing, omission, and the coexist case where a drill in one scenario and a win in another both surface). Logic-only, no device QA on this build host. Prior round 12 — thread the tone-drill trajectory into the chat coach + post-rep note: closes round-11 "Future move" #1. Rounds 9–11 taught the next-practice CARD to adapt to the Adaptation read (`IMHistorySummary.toneDrillProgress`); this round carries that same read into the two surfaces that still gave a static line. (1) Ask Noum — `CoachContextBuilder.userContext` now appends a `TONE-DRILL TRAJECTORY` section computed from `IMHistorySummary.toneDrillSignal(from: sessions)`: a terse, citeable data line ("Calm tone in Difficult Conversation: tone-match 0% to 50% (earliest vs latest reps) — recovering.") plus a per-direction guidance clause, gated to the prescribed scenario's `progress` (nil below 4 evaluated reps, so the coach never invents a movement). System-prompt intelligence-floor rule #8 instructs the model to reinforce a recovering drill, change the approach on a slipping one, and treat a stalled one as a plateau — never re-issue the original miss, never claim causation. New pure helper `CoachContextBuilder.toneDrillTrajectoryLines(for:)`. (2) Post-rep note — `PostRepCoachNoteService` gains momentum branch 0d: when the just-finished rep is an IM conversation whose committed tone is recovering/slipping (stalled falls through), the deterministic note headlines the trajectory ahead of per-rep metrics via voice-shaped `imToneTrajectorySentence` (7 voices × 2 directions), and the AI path gets the same fact in its MOMENTUM block. `PostRepCoachNoteInput` gains additive `imToneDrillProgress`/`imToneDrillScenarioTitle`/`imToneDrillToneTitle` (defaulted nil → every existing construction unchanged); `PracticeSessionFinalizer.recordPostRepCoachNote` computes the read for the finished rep's scenario from full history. 11 new tests (`ToneDrillTrajectoryContextTests`, `PostRepCoachNoteToneTrajectoryTests`). Logic-only, no device QA on this build host. Prior round 11 — tone-drill Adaptation read: closes round-10 "Future move" #3, the vision's named "next standard" (intervention-aware coaching: did the prescribed work help, and what should change?). The IM tone-drill loop already PRESCRIBES the weakest scenario + tone (`IMHistorySummary.toneDrillSignal` → `RecommendationBiasEngine.toneDrillBlueprint`), but it gave the IDENTICAL "you missed X%" copy every time regardless of whether the user's tone was recovering or stuck — the prescribe side without the observe side. New pure helper `IMHistorySummary.toneDrillProgress(from:scenario:)` adds the Adaptation half: it compares the tone-match hit rate of a scenario's earliest vs latest evaluated-rep window (`window = min(3, count / 2)`, mirroring `relationalTrend` so the two windows never overlap), ordered oldest→newest, reusing the same `.imConversation` + scenario filter and missing/whitespace-`actualTone` exclusion as `toneMatchStats`. Returns new non-gated value type `IMToneDrillProgress` (`direction: .recovering / .stalled / .slipping` + `earlierRate` + `recentRate` + `windowSize`); nil below 4 evaluated reps (fewer can't split two disjoint windows honestly). `toneDrillProgressThreshold = 0.15` shared with the suite — below the smallest possible non-zero swing (one rep flipping a 2-rep window == 0.5) yet above 0, so a flat history reads `.stalled` and any real flip reads directional, robust to fractional rounding. `IMToneDrillSignal` gains an ADDITIVE `progress: IMToneDrillProgress?` (custom init defaults it nil → every existing construction, including the test fixtures, is byte-for-byte unchanged); `toneDrillSignal` computes progress for the WINNER scenario only (the other candidates are never prescribed, so their trajectory isn't needed) and attaches it. `toneDrillBlueprint` now branches on `signal.progress?.direction`: `.recovering` REINFORCES the drill the user is on (`whyMode` "your calm tone is landing more often than it was — the drill is working. One more focused rep locks it in"; `whyNow` reports the climb "up to 50% from 0%"); `.slipping` VARIES the intervention (`whyMode` "slipped back — same scenario, but change how you open it"; `whyNow` "dropped to X% down from Y%, re-run it slower and commit to the tone from the first beat"); `.stalled` / nil keeps the neutral overall-rate prescription unchanged. The mode / scenario / tone prefill is IDENTICAL across all three branches — only the rationale adapts, so all four recommendation surfaces (ContentView / HomeCoachCard / PracticeModeSelectionView / SummaryView) pick the adaptive copy up for free, since they already pass the signal straight through. New `IMToneDrillProgressTests` (9 cases: nil on empty + below-4-reps, missing/blank-`actualTone` exclusion keeps it below the bar, recovering/slipping/stalled classification with exact earlier/recent rates, 6-rep non-overlapping windows at windowSize 3, scenario + mode filter isolation, threshold-constant robustness bounds) + 4 new engine-copy cases on `IMToneDrillSignalTests` (reinforces on recovering, varies on slipping, stays neutral on stalled AND nil, end-to-end `toneDrillSignal` carries a recovering read for the prescribed scenario). Vision: pillar #5 (Personalized coaching) + coach-parity stage #4 (Adaptation) — "compare response across multiple attempts and either reinforce, vary, or replace the intervention with an explained rationale." Honest-data contract held: no recovering/slipping claim without ≥4 evaluated reps AND a real ≥0.15 swing; no shame — a slip is framed as data plus a constructive next step, never a failure state. Files: `Noum/IMHistorySummary.swift` (+`toneDrillProgress` helper + `toneDrillProgressThreshold` + winner-progress attach in `toneDrillSignal`), `Noum/PracticeSupport.swift` (+`IMToneDrillProgress` type, +`progress` field/custom-init on `IMToneDrillSignal`, branched `toneDrillBlueprint` copy), `NoumTests/NoumTests.swift` (+13 tests), `HANDOFF.md`, `docs/CURRENT_STATE.md`. Branch `Redesign`. Build-host caveat unchanged: no Xcode/Swift toolchain here, so NOTHING was compiled or run; the helper mirrors `relationalTrend` line-for-line, the signal change is purely additive (custom init defaults `progress` nil so all four callers + every test are unchanged), and the blueprint branch is pure string selection over an already-tested enum, so a real `xcodebuild test` + a glance at the coach card on a recovering vs stuck sub-40% scenario is still wanted before TestFlight. NOT yet wired into Ask Noum context or post-rep coach-note copy (the recommendation surfaces consume it; threading the trajectory into the persistent-chat context is the natural next round). Previously: M24 deferred slate round 10 — tone-drill offered everywhere the user lands: closes round-9 "Future move" #1 by wiring the remaining two recommendation surfaces. `PracticeModeSelectionView.computeRecommendation` now passes the same `IMHistorySummary.toneDrillSignal(from:)` (availability-guarded, identical to Home) into `RecommendationBiasEngine.blueprint`, caches `blueprint.recommendedScenario`/`recommendedTone`, and `appDestination(for: .imConversation)` now returns `.imPractice(scenario: cachedRecommendedScenario, tone: cachedRecommendedTone)` instead of `nil, nil` — so launching IM from the picker prefills the exact scenario + tone the engine prescribes (a tone drill OR the goal-based default), and a one-tap IM quick-start drops straight into that drill. `SummaryView.summaryRecommendation` also passes the signal (via a new `if #available(iOS 17.0, *)`-guarded `imToneDrillSignal` since `SummaryView` is unannotated), so the post-rep "Looking ahead" card — after a non-IM rep — names the exact weak scenario and reports the observed hit rate instead of a generic mode nudge. The destination contract is locked both ways: `blueprintWithoutSignalKeepsNormalBias` now also asserts `recommendedTone == nil` off-IM (so a free-choice IM launch keeps the normal scenario grid, no stale prefill), and new `goalBasedIMRecommendationCarriesScenarioAndTone` asserts a calmer-delivery/social/warm profile yields IM + socialCatchUp + warm. Deferred: making the informational `LookingAheadCard` itself tappable (new interactive nav UI wants real-device QA, consistent with round 9's deferral), and preserving the just-finished IM scenario/tone on "Practice Again". Prior round (round 9): per-scenario tone-drill recommendation — closes the top remaining "Future move" (#1) from the round-8 HANDOFF by wiring the IM loop's READ side (per-scenario trust/tension + tone-match chips on the History list and scenario detail) to its ACT side. New pure helper `IMHistorySummary.toneDrillSignal(from:)` scans every scenario's `toneMatchStats` and surfaces the SINGLE scenario where the user's committed tone reliably misses — worst hit rate first, tiebreak by `evaluatedCount` then most-recent evaluated rep; `targetTone` is the tone the user committed to most in that scenario's evaluated reps (`dominantEvaluatedTone`, tiebreak most-recent), never a profile default. Honest evidence bar: a scenario qualifies ONLY with at least `toneDrillMinEvaluatedReps` (3) evaluated (actual-tone-bearing) reps AND `matchRate` STRICTLY below `toneDrillMatchRateThreshold` (0.4) — a low rate on 1–2 reps is noise, an undefined rate is not a miss, so no fabricated drill. New value type `IMToneDrillSignal` (scenario/targetTone/matchRate/evaluatedCount) lives non-gated next to the engine. `RecommendationBiasEngine.blueprint` gains an ADDITIVE `imToneSignal:` param (default nil → all four existing callers byte-for-byte unchanged); when present it short-circuits to `toneDrillBlueprint` BEFORE the goal-based bias, prescribing IM (the relevant skill area for tone) with the scenario + tone prefilled and copy that reports the OBSERVED hit rate ("your calm tone landed only 25% of the time — re-run the same scenario"), no reframe, no shame. `ContentView.recommendationBiasBlueprint` + `HomeCoachCard.recommendationBlueprint` compute and pass the signal (guarded on `IMModeAvailability.isAvailable`), so the coach card's title (`focus` → "Difficult Conversation tone"), target chip, subtitle (`whyNow`), and the one-tap CTA destination (`.imPractice(scenario:tone:)`) all auto-fill the weakest setup. The override self-clears once the hit rate recovers above 40%. New `IMToneDrillSignalTests` (12 cases) lock: nil on empty history, nil below the rep bar, nil at the exact 0.40 boundary (strictly-below contract), fires at 0.25/4-reps with correct fields, worst-scenario selection, evidence tiebreak, dominant-tone choice across mixed committed tones, missing/blank `actualTone` excluded from the count, the engine-override fields + honest copy, the nil-signal regression guard, and the end-to-end signal→blueprint path. Vision: pillars #3 (Conversational intelligence) + #5 (Personalized coaching); coach-parity stages Intervention + Adaptation — a recommendation with evidence, an observable target (the tone), and an honest threshold for firing AND for self-clearing. NOT yet wired into PracticeModeSelectionView / SummaryView (they pass no signal → unchanged; their IM launch still prefills nil) — next round. Build-host caveat unchanged: no Xcode/Swift toolchain here, so NOTHING was compiled or run; the change mirrors the existing pure-helper + locked-test pattern line-for-line and the engine change is purely additive, so a real `xcodebuild test` + a glance at the coach card with a sub-40% scenario is still wanted before TestFlight. Previously: M24 deferred slate round 8 — trust/tension trend chips on the IM History list row: closes the top remaining "Future move" (#5) from the round-7 HANDOFF. The round-7 pure helper `IMHistorySummary.relationalTrend(from:scenario:)` is now also read on `Noum/IMHistoryBreakdownCard.swift` — each scenario row carries the same two directional trend chips the scenario detail header shows ("Trust ↑" green / "Tension ↓" green, amber on the reverse via `goodWhenUp`: arrow = raw numeric direction, tint = value judgment), so the list reads the relational arc per scenario without a drill-in. Round-7 deferred this only on a row-crowding layout-QA concern; resolved STRUCTURALLY (no simulator needed) by restructuring `breakdownRow` into a VStack and moving the chip row — the trend chips PLUS the round-7 tone-match chip — onto its own full-width line beneath the stat columns, so up to three small capsules read side-by-side without clipping on narrow devices (also lifts the round-7 tone chip out of the cramped title column where it used to sit under the subtitle). Honest-data contracts unchanged: trend chips need ≥4 final-state reps with a non-flat |Δ|≥0.5 signal (`hasSignal`), the tone chip needs ≥1 recorded `actualTone`; a cold-start or stable scenario shows NO chip rather than a fabricated flat/zero reading, and `chipRow` self-hides entirely when neither has signal. Trend + tone fold into the row's combined VoiceOver label (`relationalTrendCopy(for:)` + existing tone copy) and the visual chip row is `accessibilityHidden` so there is no double read. New `IMHistoryBreakdownTrendContractTests` (3 cases) lock the two-part list contract the row depends on: a ≥4-rep improving scenario yields BOTH a `breakdowns` row AND a non-nil trend with `hasSignal == true` (chip shows); a 2-rep scenario renders a row but `relationalTrend` is nil (chip hidden, stats still render); a stable 4-rep scenario renders a row with a non-nil trend whose `hasSignal == false` (chip hidden). Vision-aligned on pillar #3 (conversational intelligence — the per-scenario relational-arc read a human coach gives from history) + pillar #4 (believable progress — every new surface self-hides on insufficient data, no fabricated points). Files: `Noum/IMHistoryBreakdownCard.swift` (+chip row, `chipRow`/`trendChip`/`relationalTrend(for:)`/`relationalTrendCopy(for:)` helpers, row → VStack, doc-comment update), `NoumTests/NoumTests.swift` (+3 tests), `HANDOFF.md`, `docs/CURRENT_STATE.md`. Branch `Redesign`. Remaining Future moves carried forward: per-scenario drill recommendations (wants a dedicated `RecommendationBiasEngine` push — feeds 7 consumer surfaces), peer Sudden Death scores (blocked on `PublicProfileSnapshot` schema), `coachNoteRevealed` cleanup (animation-chain risk), rate-limiter live refresh (low priority, Settings modal). Previously: M24 deferred slate round 7 — per-scenario trust/tension trend chips + tone-match list chip: closes two more "Future moves" (#4 + #5) from the round-6 HANDOFF, both surfacing a per-scenario signal already computed + tested in `IMHistorySummary` as a one-glance chip one rung up the navigation tree. (1) New pure helper `IMHistorySummary.relationalTrend(from:scenario:) -> IMScenarioRelationalTrend?` reduces the per-rep trust/tension trace into a single directional read by comparing the mean of the earliest `window` reps against the latest `window` reps, where `window = min(3, count / 2)` — a bound that guarantees the two averaging windows NEVER overlap (2·window ≤ count for every count) so the first stretch and recent stretch are genuinely disjoint. New nested `IMScenarioRelationalTrend` (Equatable) carries `trust`/`tension` of type `Movement` (`.up`/`.down`/`.flat` — the RAW numeric direction, so the helper stays honest about what the numbers did and leaves the good/bad value judgment to the view), `trustDelta`/`tensionDelta` (latest − earliest window mean, rounded 0.1), `windowSize`, and a `hasSignal` convenience (true when ≥1 metric is non-flat). `relationalTrendThreshold = 0.5` shared with the test suite so the flat-vs-trend boundary is asserted not guessed. Defensive contracts (locked by `IMScenarioRelationalTrendTests`, 10 cases): reuses `tracePoints(from:scenario:)` so it inherits the `.imConversation` filter + final-state requirement + scenario filter + oldest→newest ordering for free; nil below 4 contributing reps (fewer can't separate a first stretch from a recent stretch honestly); windows never overlap; `.flat` when |delta| < 0.5 per metric independently; a stable-but-sufficient history returns a non-nil struct with `hasSignal == false` (enough data, no trend → header chips self-hide). (2) `Noum/IMScenarioDetailView.swift` summary header gains a trend chip row beneath the three stat tiles, rendered only when `relationalTrend` non-nil AND `hasSignal` true: `trendChip(label:movement:goodWhenUp:)` `@ViewBuilder` self-hides on a flat metric, arrow glyph (`arrow.up.right`/`arrow.down.right`) shows the RAW direction while tint reads the value judgment — `goodWhenUp` flips the green (`AppColor.positive`) / amber (`AppColor.caution`) assignment so trust-up + tension-down both read green, the reverse reads amber. Calm 0.12-alpha capsule register (matches the tone-match strip — data, not celebration/penalty). Combined VoiceOver label ("Recent trend: trust trending up, tension trending down, based on your earliest and latest N reps.") + accessibility id `history.im.scenario.trendChips`. (3) `Noum/IMHistoryBreakdownCard.swift` row gains a compact "Tone X/Y" chip beneath the subtitle in the leading column, rendered only when `evaluatedCount > 0`: `toneMatchStats(for:)` reads the same pure `IMHistorySummary.toneMatchStats` helper the drill-down uses (list row + detail view never drift on the rate); `toneMatchChip(stats:)` is a `target` glyph + "Tone X/Y" in the mode-tinted calm capsule, marked `accessibilityHidden(true)` because the row's combined label already folds in the tone read (", tone matched X of Y reps") — no double read; a scenario the evaluator never produced a tone for shows NO chip rather than a fabricated 0/0. Vision-aligned: pillars #3 (conversational intelligence — "your last few Difficult Conversation reps recovered trust faster and held tension lower" reads on the header in one glance, tone accuracy reads on the History list without a drill-in) + #4 (believable progress — every surface self-hides on insufficient/missing data, no fabricated points, no fake-zero percentages). Anti-goal compliant: trend helper reports the raw numeric movement reading `normalizedTrust`/`normalizedTension` directly (no smoothing, no AI reframe); tone chip reuses the engine's own `actualTone` substring matcher; no punish-shame (a low tone-match or amber chip is calm informative data, never a red failure state). Remaining deferred "Future moves": per-scenario drill recommendations (`RecommendationBiasEngine` feeds 7 consumer surfaces — wants a dedicated push), peer SD scores (blocked on `PublicProfileSnapshot` schema), `coachNoteRevealed` cleanup (animation-chain risk), rate-limiter live refresh (low priority), trend chips on the History list row (now that `relationalTrend` is pure — deferred only on row-crowding layout QA). Previously: M24 deferred slate round 6 — IMScenarioDetailView analytics + empty-state CTA: closes three more "Future moves" from the round-5 HANDOFF on a single coherent surface (the per-scenario IM drill-down). (1) New pure helpers on `Noum/IMHistorySummary.swift` — `IMScenarioTracePoint` value type (`id` + `date` + `trust` + `tension`) + `tracePoints(from:scenario:) -> [IMScenarioTracePoint]` ordered oldest→newest so Chart consumers read left-to-right as time-moves-forward (defensive: filters to `.imConversation` internally, ignores reps without `imConversationDetails` or without a recorded `finalState`, drops cross-scenario reps, reads through `IMConversationState.normalizedTrust`/`normalizedTension` so out-of-range engine output never plots past the visible 1-10 band); `IMScenarioToneMatchStats` value type (`evaluatedCount` + `matchCount` + `matchRate: Double?` + `lastFive: [LastFiveEntry]`) + `toneMatchStats(from:scenario:) -> IMScenarioToneMatchStats` + `matches(targetTone:actualTone:) -> Bool` (exposed pure-static matcher: case-insensitive substring containment of the target tone's English title in `actualTone`, the same shape the server-side evaluator produces). Defensive contracts: ignores reps where `actualTone == nil` or whitespace-only (the evaluator didn't actually produce a reading — that's not a miss, it's missing data, excluded from both numerator and denominator), drops cross-scenario reps, `lastFive` is newest-first bounded at 5, `matchRate == nil` when `evaluatedCount == 0` (no honest denominator → no fabricated zero percent). (2) `Noum/IMScenarioDetailView.swift` gains three new surfaces: (a) `traceChartCard` — two-line `SwiftUI Chart` sparkline plotting trust (teal) + tension (orange) across reps in this scenario, oldest→newest, with mode-tinted card chrome + legend dots + "oldest → newest" caption. Catmull-Rom interpolation, `chartYScale(domain: 1...10)`, axis marks at 1/5/10 on y axis. Chart itself is `accessibilityHidden(true)`; outer VStack carries one combined VoiceOver label ("Trust and tension trace across N reps. Trust moved from X to Y; tension moved from X to Y, on a 1-to-10 scale."). Self-hides when `tracePoints.count < 2` (a single point isn't a trace; the card collapses entirely rather than rendering a placeholder). (b) `toneMatchCard` — "last 5 reps" chip strip + "X of Y matched" ratio caption, mode-tinted register, sits beneath the trace card (or beneath the summary header when trace card self-hides). Match chip: `checkmark.circle` tinted `AppColor.positive` when matched, `xmark.circle` tinted `AppColor.caution` when not, both at 0.14-alpha background so the row reads as a calm sequence not a celebration/penalty. Self-hides when `evaluatedCount == 0` (no rep recorded an `actualTone` yet). Combined VoiceOver label ("Tone match: 3 of 5 reps matched the target tone, 60 percent."). (c) Empty-state CTA — pill-shaped "Launch this scenario" button on the empty state (mode-tinted Capsule with `play.circle.fill` glyph) pushes `AppDestination.imPractice(scenario:tone:)` with `tone: nil` so the IM practice view's own picker resolves it from the user's last preference — same behaviour the Quick Start CTA uses, launch path stays coherent across entry points. Accessibility identifier `history.im.scenario.launchCTA`; accessibility label "Launch <scenario title>". (3) Two new test suites (16 cases, ~240 LOC): `IMScenarioTracePointsTests` (6: empty input → empty result, scenario filter isolation, oldest→newest ordering, drops reps without final state, normalizer clamps out-of-range to 1-10 band, drops non-IM modes); `IMScenarioToneMatchStatsTests` (10: empty input, nil actualTone exclusion, whitespace-only exclusion, case insensitivity across all 6 IMTargetTone × multiple casings, substring containment ("warmly confident" matches `.confident`), empty actual never matches, scenario filter isolation, last-five newest-first ordering with 6-rep fixture confirming the oldest entry is excluded, rate rounding to two decimals (2 of 3 → 0.67), non-IM exclusion). The artifact a user can now hold: (a) per-scenario sparkline reads "your last three Difficult Conversation reps recovered trust faster than your first five" without scanning numeric rows; (b) tone-match strip reads "3 of 5 matched" + visual chip row showing which of the last 5 reps the evaluator read as matching the target tone; (c) on a cold-start scenario (rare — only reachable via deep-link or after every rep is deleted), the empty state carries a real launch button so the user can act from inside the screen. Vision-aligned: pillars #3 (conversational intelligence — the per-scenario read a £130/hr human coach would surface after pulling the data) + #4 (believable progress — both cards self-hide on insufficient data, no fabricated visuals, no placeholder logic). Anti-goal compliant: matcher reads from engine's own `actualTone` string not an AI reframe, trace reads normalized values directly with no smoothing, empty-state CTA never auto-launches. Previously: M24 deferred slate round 5 — IM per-scenario drill-down + WPM zone band on Timed + best-this-week chips across all four per-mode breakdown cards: closes three more "Future moves" from the round-4 HANDOFF without device-only QA, schema work, or animation-chain risk. (1) New `Noum/IMScenarioDetailView.swift` (~290 LOC) parallels `SuddenDeathDifficultyRunsView` — reached by tapping a scenario row in the IM breakdown card. Mode-tinted summary header (best score / avg trust / avg tension), per-rep row list with trophy on top-scoring rep, trust + tension chips + target-tone capsule + relative date, tap-through to standard `sessionDetail(sessionID:)`, trailing-toolbar `ShareLink` with the new `IMHistoryExport.formatPlainText(sessions:scenario:)` helper — same anti-goal contract as `SuddenDeathHistoryExport` (zero transcript content, locked by `IMHistoryExportTests.crossScenarioExportNeverContainsTranscriptContent` that injects sentences from `IMConversationTurn.text` + `finalState.beat` into a fixture and asserts they never leak). New `AppDestination.imScenarioDetail(scenario:)` case wired through `ContentView`'s navigationDestination switch; `SessionHistoryView` now passes `onSelectScenario:` through to the IM breakdown card. (2) `TimedHistoryBreakdownCard` gains a 6pt mode-tinted progress band beneath the stat row — "N of M reps in zone" on the left, "130–160 WPM" on the right, filled to `inZoneRepCount / runCount` ratio via a `GeometryReader` for responsive width. Accessibility hidden on the bar itself with a single combined `accessibilityLabel` on the outer VStack (one screen-reader chunk, not two). Range copy reads from canonical `TimedHistorySummary.zoneMinWPM`/`zoneMaxWPM` constants so a future zone shift can never produce stale labels. Self-hides on `runCount == 0`. (3) Best-this-week chips across all four per-mode breakdown cards via a two-shape design — inline "THIS WEEK" capsule next to the Best/Cleanest-rep eyebrow on Timed + Ah-Counter (cards with a single best-rep cell), header capsule with named data point ("Best this week · 8 rounds · Hard" / "Best this week · 9/10 · Difficult Conversation") on SD + IM (cards with per-row breakdowns where the chip is the only place the user reads "current peak" without scanning). `TimedHistorySummaryStats.bestIsThisWeek: Bool` + `AhCounterHistorySummaryStats.cleanestIsThisWeek: Bool` added, computed via new `isThisWeek(date:now:calendar:)` pure static helpers on both summary modules. New `SuddenDeathHistorySummary.bestThisWeek(from:now:calendar:) -> SuddenDeathRunRecord?` + `IMHistorySummary.bestThisWeek(from:now:calendar:) -> (session:scenario:score:)?` static pickers. Defensive contracts (locked by tests): inclusive 7-day window [`now - 7d`, `now`], boundary alignment between Timed + Ah-Counter helpers explicitly tested, future dates never read as "this week" (clock drift / fixture mistake guard), tiebreak by most-recent date so user reads "today's best" before "Tuesday's best", IM picker ignores non-IM sessions even when they outscore IM reps. Brand-voice contract: no exclamations, no "you peaked!" framing — just the time tag. 7 new test suites (~410 LOC across 30+ tests): `TimedHistorySummaryBestThisWeekTests` (7), `AhCounterHistorySummaryThisWeekTests` (5), `SuddenDeathBestThisWeekTests` (5), `IMBestThisWeekTests` (5), `IMHistoryExportTests` (6 — empty placeholder, transcript-leak check, scenario filter isolation, header row shape lock, unscored rep "—" rendering, stable scenario order in cross-scenario export), `TimedHistoryZoneBandContractTests` (2 — range constants locked to 130–160, in-zone count ≤ run count invariant), and 4 new cases on the existing `AppDestinationSessionDetailTests` for the `imScenarioDetail` Hashable/Equatable/distinctness-from-SD contract. The artifact a user can now hold: (a) tap any IM scenario row → land on a per-scenario detail view with trust + tension chips for every rep, plus a plain-text share with zero transcript content; (b) Timed in-zone count reads as a visual band, not just an integer; (c) "is my peak fresh or stale?" reads in one glance via a quiet `THIS WEEK` capsule (Timed + Ah-Counter) or a one-line header chip naming the difficulty/scenario (SD + IM). Vision-aligned: pillars #3 (conversational intelligence) + #4 (believable progress) + anti-goals (honest "no chip" fallback when no rep is fresh enough, zero transcript leaks, never blocks practice). Previously: M24 deferred slate round 4 — Timed + IM History breakdown cards + post-rep daily-cap hint + Profile SD share row: closes four more "Future moves" from the M24 round-3 HANDOFF and lands per-mode hero parity across all four modes on History (SD + Ah-Counter + Timed + IM). (1) New `Noum/TimedHistorySummary.swift` pure helper: `summarize(sessions:now:calendar:) -> TimedHistorySummaryStats?` surfaces `runCount` + `averageScore: Double?` + `best: BestRep?` (highest score, tiebreak by most-recent date) + `averageWPM: Int?` + `inZoneRepCount: Int` (count of reps in `WPMEvaluator` Timed band 130–160 WPM, locked by `zoneMinWPM`/`zoneMaxWPM` constants + a `zoneBoundsLockedToConstants` test) + `trend: TrendComparison?` (7-day vs prior-7-day mean score; |Δ| < 0.3 reads as `.steady` to filter single-rep noise). Defensive contracts: filters to `.timed` mode internally, averageScore considers only scored reps (older sessions decode with nil score), averageWPM drops zero-duration/zero-word reps (no divide-by-zero), trend nil when EITHER window empty (no fabricated direction). New `Noum/TimedHistoryBreakdownCard.swift` SwiftUI hero card mirroring `AhCounterHistoryBreakdownCard`: `AppColor.modeTimed` (Timed blue) radial wash + tint border, header (`timer` glyph + "Timed history" + rep count + optional trend chip — "Up 0.4 vs last week" / "Down 0.4 vs last week" / "Steady vs last week"), stat row (avg score · in zone · avg WPM), tappable best-rep cell pushing `AppDestination.sessionDetail(sessionID:)`. Self-hides on cold start. Wired into `SessionHistoryView` as the symmetric branch alongside SD + Ah-Counter — when `selectedModeFilter == .timed`, the card renders above the session rows; reads from already-`filteredSessions`. (2) New `Noum/IMHistorySummary.swift` pure helper: `breakdowns(from: sessions) -> [IMScenarioBreakdown]` produces one row per `IMConversationScenario` (Social Catch-Up / Work Update / Difficult Conversation / Networking) carrying `runCount` + `averageScore: Double?` + `bestScore: Int?` + `bestScoreDate: Date?` + `averageFinalTrust: Double?` (mean of `IMConversationState.normalizedTrust` across reps with a final state) + `averageFinalTension: Double?` + `lastPlayed: Date`. Excludes sessions without `imConversationDetails` (a rep without recorded scenario metadata can't be classified). Sort: most-recently played first. New `Noum/IMHistoryBreakdownCard.swift` SwiftUI hero card with `AppColor.modeIM` (IM purple-blue) tint and SD-shaped layout — header + one row per scenario carrying the scenario title + subtitle ("3 reps · best 9/10 last week", omits the "best" tail on unscored scenarios), three stat columns (avg score · avg trust · avg tension), optional chevron when `onSelectScenario` is provided (currently nil — the IM per-scenario drill-down is a future move; the callback shape is in place for a future view). Self-hides when no IM reps with conversation metadata exist. Wired into `SessionHistoryView` when `selectedModeFilter == .imConversation`. All four modes now ship with a per-mode hero card on the History surface — the original goal of the per-mode stat surface track. (3) `Noum/CoachReadCard.swift` gains a daily-cap hint: new `static let dailyBudgetHintThresholdRatio: Double = 0.75` + pure `static func dailyBudgetHintCopy(remaining: Int) -> String` that produces "Rule-based today — coach notes resume tomorrow." (0 remaining), "1 AI coach note remaining today." (singular), or "N AI coach notes remaining today." (plural). New `dailyCoachNoteRemaining` + `dailyCoachNoteCap` computed properties read `AIRateLimiter.shared.remainingToday(kind: .postRepCoachNote)` + `currentCap()`; `shouldShowDailyBudgetHint` gate fires only when `note.isAIBacked == true` AND used ≥ 75% of cap (the RULE-BASED tag above already tells the rule-based story, so layering a budget hint on top would be noise). Threshold (0.75) is intentionally LOWER than `AISettingsManager.usageAwarenessThreshold` (0.90) because the daily cap is smaller (12 free / 40 Pro vs 20 free / 100 Pro monthly) so the user notices it earlier in the day. Brand-voice contract: no exclamations, no "running out" framing, no fake urgency — locked by `CoachReadCardDailyBudgetHintTests.hintCopyHasNoUrgencyFraming` (banned phrases: "running out" / "hurry" / "almost out" / "left!" / "Last") + `hintCopyHasNoExclamations`. Visual register: `Typography.captionSmall` in `AppColor.textSecondary` — quiet caption beneath the note text, doesn't compete. (4) `ProfileView.suddenDeathHistoryShareRow` — quiet `ShareLink` row in the Progression cluster, beneath `ModeMasteryCard` and above `achievementsPanel`. Reads from `SuddenDeathRunHistoryStore.shared.runs` (new `@StateObject` on the view). Self-hides when `runs.count == 0` so a user who hasn't touched Sudden Death sees nothing. Reuses `SuddenDeathHistoryExport.formatPlainText(runs:)` — the same cross-difficulty helper the SD Result-screen menu calls into (round 3) and the per-difficulty drill-down view (round 2). Same anti-goal contract: zero transcript content end-to-end, locked by `SuddenDeathHistoryExportTests.exportNeverContainsTranscriptContent`. Visual register: single row (not a card) with 28pt `bolt.fill` icon in `AppColor.modeSuddenDeath` tint + two-line text ("Share Sudden Death history" + "N runs · cross-difficulty plain-text") + trailing `square.and.arrow.up` glyph; opens system activity sheet. Accessibility identifier `profile.suddenDeath.historyShare` for future UI test coverage. 42 new tests across three suites: `TimedHistorySummaryTests` (15: summarize empty + mode-filter × 3, averages × 3, best rep × 3, pace + zone × 3, trend window × 5), `IMHistorySummaryTests` (15: filtering + empty × 3, grouping × 2, averages × 4, best score × 3, totals × 3), `CoachReadCardDailyBudgetHintTests` (7: copy by remaining × 4, brand-voice contract × 2, threshold inequalities × 1). The artifact a user can now hold: (a) their Timed track record reads as a per-mode hero on History; (b) their IM track record reads as a per-scenario rollup with trust/tension averages; (c) they can see when their AI coach is about to go rule-based via a quiet caption on the post-rep coach note; (d) they can share their full Sudden Death track record from Profile in one tap. Vision-aligned: pillars #3 (conversational intelligence) + #4 (believable progress) + anti-goals (honest fallbacks, no transcript leaks, never blocks practice). Previously: M24 deferred slate round 3 — Settings AI-budget surface + SD Result history-export menu + Ah-Counter History breakdown card: closes three more "Future moves" from the M24 round-2 HANDOFF. (1) Settings → Account → AI usage now surfaces TWO budgets — `AIRateLimiter.remainingToday(.postRepCoachNote)` (daily, resets at midnight) and `AISettingsManager.remainingAnalyses` (monthly, resets on the first of the month) — as honest "X of Y" reads in the right-now-active tier. Section auto-hides when `aiSettings.activeProvider == nil` (no AI keys configured → honest absence). Each row flips to `AppColor.caution` tint + "Rule-based today" sublabel when the budget is exhausted; the user finally has an answer to "why did my coach go rule-based today?" Free-tier users see a final row "Pro gets 40/day · 100/month" with `crown.fill` glyph + paywall sheet on tap; copy generated from `AIRateLimiter.premiumDailyCap` + `AISettingsManager.premiumMonthlyDebriefLimit` so a future cap bump can never produce stale marketing. (2) `SuddenDeathResultView` Share button lifted into a Menu when `runHistoryStore.runs.count > 1` — two options: "Share this run" (the original one-line brag, `bolt.fill`) and "Share full history (N runs)" (cross-difficulty plain-text table via the existing `SuddenDeathHistoryExport.formatPlainText(runs:)` helper, `list.bullet.rectangle`). New `ShareKind` enum (`thisRun` / `fullHistory`) + `pendingShareKind: @State` decouples the menu close animation from the sheet present so the user never sees the sheet flicker between values. When `runHistoryStore.runs.count <= 1`, the menu collapses back to a plain Button — restraint over redundant choice. Cross-difficulty export reuses the leaderboard rule from `docs/VISION.md` (locked by `SuddenDeathHistoryExportTests.exportNeverContainsTranscriptContent`): zero transcript content end-to-end. (3) New `Noum/AhCounterHistorySummary.swift` pure helper mirrors `SuddenDeathHistorySummary` — produces `AhCounterHistorySummaryStats?` from a list of `PracticeSession`. Public surface: `summarize(sessions:now:calendar:) -> AhCounterHistorySummaryStats?`, `ratePerMinute(fillerCount:durationSeconds:) -> Double`, `trendComparison(sessions:now:calendar:) -> TrendComparison?` (the last two exposed for tests). Defensive contracts: filters to `.ahCounter` mode internally (upstream filter mistakes → empty/nil, not mixed-mode aggregate); zero-duration sessions dropped from rate calculations (divide-by-zero can never crash); cleanest-rep tiebreak by date (most-recent wins); trend nil when EITHER 7-day window is empty (no fabricated single-point direction); steady threshold |Δrate| < 0.5/min filters out single-rep noise. New `Noum/AhCounterHistoryBreakdownCard.swift` — SwiftUI hero card with mode-tinted background (`AppColor.modeAhCounter`), header (title + rep count + trend chip — `arrow.down.right`/`arrow.up.right`/`equal`), stat row (avg/min · clean reps · best/min), tappable cleanest-rep cell pushing `AppDestination.sessionDetail(sessionID:)`. Self-hides when `summarize(sessions:)` returns nil (cold start). Wired into `SessionHistoryView` as the symmetric branch alongside the existing SD breakdown — when `selectedModeFilter == .ahCounter`, the card renders above the session rows; reads from already-`filteredSessions`. `AISettingsManager.premiumMonthlyDebriefLimit` + `freeMonthlyDebriefLimit` lifted from `private static let` to internal `static let` so the Settings CTA can quote them; runtime cap path unchanged (alias). 21 new tests across `AhCounterHistorySummaryTests` (19: ratePerMinute math × 4, summarize empty + mode-filter × 3, cleanest rep × 3, averages × 2, cleanRepCount × 1, runCount × 1, trend window contract × 5) + `AISettingsManagerPremiumConstantsTests` (2: premium > free, free > 0). The artifact a user can hold: (a) they can see why their coach went rule-based today in Settings → AI usage; (b) they can share their full SD track record from the Result screen in one tap; (c) their Ah-Counter filler-rate trend reads as a per-mode hero on History. Vision-aligned: pillars #1 (filler reduction) + #4 (believable progress) + anti-goals (honest fallbacks, no transcript leaks, never blocks practice). Previously: M24 Track 1 — Coach Persona + Post-Rep Coach Note Service: the £130/hr coach turns toward the user and says "here's what I just saw" the moment a rep finalizes. New `Noum/CoachPersona.swift` — pure data model wrapping per-voice persona traits (registerName, signatureTone, openings: [String], closings: [String], reflectionLead). Six SpeakingStyleGoal voices + `default` nil fallback, each carrying a 3-line openings catalogue + 3-line closings catalogue + reflectionLead phrase. `opening(seed:)` / `closing(seed:)` use a stable seed so the same rep always renders the same line — text doesn't shuffle on re-paint. New `Noum/PostRepCoachNote.swift` value type (`id` + `sessionID` + `voice` + `noteText` + `isAIBacked` + `generatedAt`). New `Noum/PostRepCoachNoteStore.swift` per-account UserDefaults persistence keyed `postRepCoachNote.<accountID>` (mirrors AskNoumStore testable-init pattern with `defaults:` + `accountIDProvider:` so tests are hermetic without touching KeychainHelper). `record(_:)` de-dupes on sessionID so the deterministic → AI upgrade path REPLACES rather than stacks. 30-note capacity with oldest-by-generatedAt eviction. `latestNote()` feeds the Ask Noum context. Lifecycle hooks (`reloadForCurrentAccount` / `endSession` / `deleteAllData`) wired through AuthManager. New `Noum/PostRepCoachNoteService.swift` actor wrapping AI generation + `nonisolated static deterministicNote(input:)` fallback (exposed for tests). AI path: JSON-strict `{"note": "..."}` response, provider plumbing identical to AIInsightsService (OpenAI/DeepSeek/Gemini, AIConfig.plist keys, locale + API-key guards), brand-voice contract validation (`passesBrandVoiceContract`) rejects model output containing `!`, "Let's", "Awesome", "Great job", or overlong text and falls back. Deterministic path priority chain: (1) filler comparison vs baseline → win ("1 filler — well below your usual rate") at ratio ≤0.5× + count ≤2 or loss ("10 fillers — above your baseline. Slow the open next time") at ratio ≥1.5× + count ≥3; (2) zero fillers with ≥20 word floor → universal clean-run marker; (3) score band (≥8 → strong-score sentence; ≤4 → weak-score sentence that NEVER punish-shames per brand-voice contract); (4) pace outside 100-160 WPM when measurable (>170 → rushed; <95 → slow); (5) duration <20s → short-rep honesty without scolding; (6) fallback → neutral steady-delivery note. Voice carries through CoachPersona.persona(for:) so the same facts produce different phrasing for authoritative (verdict-shaped) vs warm (felt-experience-shaped) vs concise (clipped) coaching. Length cap: ≤200 chars across both paths. New `Noum/CoachReadCard.swift` SwiftUI hero card — brand-purple register (per M14 home-card design language: purple = "your coach speaking", mode-tint = "this is what to do"), NoumCharacter.Inline coaching glyph, voice-shaped header label ("COACH READ" / "FROM YOUR COACH" / "COACH NOTE" / "COACH BRIEFING" / "COACH BRIEF" per voice), optional "RULE-BASED" provenance tag (only when `isAIBacked == false`), note text in Typography.body. `PracticeSessionFinalizer.finalize` now ends with `recordPostRepCoachNote(for:)` — builds PostRepCoachNoteInput from finalized session + live stores (CoachingProfileStore.shared.profile + BaselineStore.shared.baseline + BigMomentStore.shared.activeMoment + daysUntil), calls `deterministicNote(input:)` synchronously and records it (Summary surface has a coach voice to render on the first paint cycle), then spawns a detached Task for the AI upgrade that re-records only when the upgrade is actually AI-backed. `CoachContextBuilder.userContext(...)` gains optional `latestRepNote: PostRepCoachNote? = nil` param; new LAST REP NOTE section renders between RECENT and PATH with explicit provenance labeling ("AI-generated" vs "rule-based (template)") so the model never claims "I noticed X" about a template line. `AskNoumView` observes PostRepCoachNoteStore.shared and threads `latestNote()` into the context call so the persistent chat coach builds on its own earlier read instead of starting fresh every turn. `SummaryView` renders CoachReadCard between HeroScoreCard and WhatYouDidWellCard, gated on `postRepCoachNoteStore.note(for: sessionStore.sessions.first?.id) != nil` (always present by the time SummaryView mounts because the finalizer writes synchronously). `AuthManager.deferStoreReloadForCurrentAccount` + `deferStoreSessionReset` extend to include `PostRepCoachNoteStore.shared`; `clearAllUserData(for:)` adds `postRepCoachNote.<accountID>`. 40+ new tests across 4 suites: `CoachPersonaTests` (6 tests: persona-for-nil returns default, every voice returns distinct registerName, every voice has non-empty openings/closings/reflectionLead, brand-voice contract no-exclamations across ALL persona lines × voices, seeded picks are stable, seeded picks don't crash on extreme seeds), `PostRepCoachNoteServiceDeterministicTests` (18 tests: honest-rule-based provenance, voice carries through, sessionID carries through, zero-fillers always celebrated as clean run, strong score cites the number, weak score NEVER punish-shames (no failure/bad/poor/terrible), rushed pace cites WPM, slow pace cites WPM, short rep stays honest, no-exclamations contract across 60 voice×score×filler combos, length-cap ≤200 across 20 voice×score combos, filler-loss branch fires at ≥1.5× baseline + count ≥3, filler-win branch fires at ≤0.5× baseline + count ≤2, brand-voice validator rejects exclamations/chirpy filler/overlong + accepts clean text, collapseWhitespace + ensureNoExclamations helpers), `PostRepCoachNoteStoreTests` (9 tests: record+fetch round trip, dedupes on sessionID, capacity evicts oldest by generatedAt, latestNote returns highest, clearAll empties, deleteAllData wipes by account, per-account key isolation, reload reads from disk, endSession clears in-memory without erasing disk), `CoachContextLastRepNoteTests` (4 tests: section omitted when nil, present when set, provenance surfaces correctly, sits before PATH/end-of-context). Closes M24 Track 1 from the previous session's deferred slate; Track 2 (Summary dedupe) and Track 3 (Sudden Death scoring view + SuddenDeathRunHistoryStore + friends scores) remain deferred. The artifact a user can now hold: a coaching note in their own coach's voice, tied to the rep they just finished, that the persistent chat coach builds on every time they come back. Previously: M24 partial — Sudden Death prompt audio replay fix (round-keyed cache) + skill level-up flash timing bump (single-event hold 0.35s → 1.80s for HIG-compliant read pace). Previously: M23 — Situational Preparation Mode lands as MVP (landing + per-step launchers under HomeCoachCard CTA when BigMoment.daysUntil ≤ 14). Previously: M22 — Monthly Coach Letter MVP (deterministic, auto-fire on month boundary). Previously: M21 — Session Intent: the £130/hr coach's "what are we working on today?" lands as a pre-rep sheet over Timed + Sudden Death. New `Noum/SessionIntentStore.swift` ((1) `SessionIntent` Codable struct: `id` + `priority: CoachingPriority` + `label` + `kind: SessionIntentOptionKind` (`.planWeek`/`.trendFocus`/`.voiceGoal`/`.generic`) + `declaredAt` + optional `sessionID` linked post-finalize; (2) `@MainActor` `SessionIntentStore` singleton with `@Published private(set) var pendingIntent: SessionIntent?` (transient — cleared every consume / endSession / view-disappear) + `@Published private(set) var history: [SessionIntent]` (bounded at `historyCap == 30`, per-account UserDefaults `sessionIntent.history.<accountID>`); (3) lifecycle `reloadForCurrentAccount()` / `endSession()` / `deleteAllData(for:)` mirroring BigMomentStore + ForwardPlanStore patterns; (4) API `setPending(_:)` / `clearPending()` / `consume(sessionID:) -> SessionIntent?` (links to session ID, writes to history, clears pending — returns nil when nothing pending, the common path)). New `CoachingPriority.aligned(with: SkillArea)` static bridge maps the 10 SkillArea cases into the 4-way CoachingPriority bucket (fillerReduction → reduceFillers, conciseSpeaking/structure/answerDevelopment → moreConcise, openingStrength/closingStrength → thinkFaster, paceControl/pauseUsage/vocalEmphasis/confidence → calmerDelivery) so trend focus + plan-week focus both flow into the intent space without leaking SkillArea into the UI. New `CoachingPriority.intentChipLabel` short first-person voice-shaped labels (≤24 chars, no exclamations, no leading "I ") for the chip row. New `SessionIntentMatcher.aligns(bulletID:with:)` pure-function bullet-to-priority matcher keyed on the existing `WhatYouDidWellCard` / `WhatToImproveCard` bullet ID conventions (`category-<Dimension>`, `filler`, `pace-fast`, `pace-slow`) so neither card needs structural changes beyond reading a bool. New `Noum/SessionIntentEngine.swift` pure-function `options(forwardPlan:trendFocus:profile:now:calendar:) -> [SessionIntent]` that produces 1–4 ordered options: plan-week first (most-earned signal — the coach wrote a program), trend focus second (data-driven), voice goal third (the user's long-term direction), generic "Open rep" always last. Dedup rule: same `CoachingPriority` only appears once; if plan-week and trend collapse to the same bucket, the trend-focus option is skipped. Reads `ForwardPlan.currentWeek(now:calendar:)` so the option set reflects week-2 focus after 8 days, not always week 1. New `Noum/SessionIntentPromptView.swift` sheet-style view with reduce-motion-safe single-tap commit chips, voice-shaped reason eyebrows ("From your plan" / "Your weakest area" / "Your stated goal" — generic chip carries no eyebrow), skip toolbar button + swipe-to-dismiss both drop cleanly (rep finalizes with `intentFocus: nil`), `presentationDetents: [.medium]`. `Noum/SpeechRecognizerViewModel.swift` `PracticeSession` gains `intentFocus: CoachingPriority?` + `intentLabel: String?` (`decodeIfPresent` so older persisted sessions decode with nil). `Noum/PracticeSupport.swift` `PracticeSessionDraft` mirrors the two new fields. `PracticeSessionFinalizer.finalize(...)` reads `SessionIntentStore.shared.pendingIntent` once on entry, injects into a mutated draft when the caller hasn't supplied one of its own, appends, then calls `SessionIntentStore.shared.consume(sessionID:)` to link + clear — single-source decision means every mode (Timed, Sudden Death, Ah-Counter, drill mini-runs) automatically picks up declared intent without touching call sites. `PracticeSessionStore.append(_:)` threads the two fields into the new PracticeSession. `Noum/CoachContextBuilder.swift` `userContext(...)` RECENT block now reads each session's `intentLabel` (whitespace-trimmed) and appends a compact " · Intent: <label>" tail to the per-session row — coach can say "you came in wanting to tighten structure — here's what I saw" without needing a separate section. Empty/whitespace-only labels silently omit the tail (defensive contract). `Noum/TimedPracticeView.swift` + `Noum/SuddenDeathPracticeView.swift` add `@StateObject forwardPlanStore` + `@StateObject sessionIntentStore` + `@State showIntentPrompt: Bool` + `@State intentPromptShownThisVisit: Bool` + `.sheet(isPresented:)` rendering `SessionIntentPromptView` with options computed live from `SessionIntentEngine.options(forwardPlan:..., trendFocus: TrendAnalyzer.primaryFocus(trends: TrendAnalyzer.analyze(snapshots: SkillTrendStore.shared.snapshots), currentSessionSnapshot: nil, recentDrills: DrillHistoryStore.shared.entries, styleGoal: profile?.speakingStyleGoal), profile:)`. Sheet auto-presents in `.task` exactly when `phase == .setup && !intentPromptShownThisVisit && pendingIntent == nil` (skipped on `PracticeModeQuickStart.consume(...)` Quick-Start path — the user already committed to launching). `.onDisappear` clears any leftover pending intent so the next mode entry starts clean. `Noum/WhatYouDidWellCard.swift` + `Noum/WhatToImproveCard.swift` gain optional `intentFocus: CoachingPriority?` param; bullet-row VStack restructured to put the headline + the optional `intentMatchChip` ("scope" SF Symbol + "YOU AIMED FOR THIS" small-caps Capsule) in a 6pt-spaced inner VStack — Wins card uses `AppColor.positive` tint (you delivered on what you aimed for), Improve card uses `AppColor.caution` tint (you flagged it, here's the verdict). Chip renders only when the bullet ID aligns with the declared priority via `SessionIntentMatcher.aligns(...)`. `Noum/SummaryView.swift` passes `sessionStore.sessions.first?.intentFocus` into both cards. `Noum/AuthManager.swift` registers `SessionIntentStore.shared` in `deferStoreReloadForCurrentAccount` + `deferStoreSessionReset` + adds `sessionIntent.history.<accountID>` to `clearAllUserData(for:)`. 25+ new tests across 6 suites: `CoachingPriorityAlignedWithSkillAreaTests` (filler→reduceFillers, concise→moreConcise×3, openings→thinkFaster×2, pace→calmerDelivery×4, every-SkillArea-maps-somewhere via allCases iteration, chip labels ≤24 char + no "!" + not "I " prefix), `SessionIntentEngineTests` (cold-start returns only generic, profile-only returns goal+generic, plan-week lands first, dedupe of plan+trend collapsing to same bucket, generic always last across 12 input combos, plan-week-uses-current-week-not-week-one with mixed 4-week plan + 8-day offset), `SessionIntentStoreTests` (SessionIntent JSON round-trip, reason labels are coach-voice for plan/trend/goal + nil for generic, historyCap == 30 contract, per-account key isolation), `SessionIntentMatcherTests` (filler→filler+Clarity, concise→Structure+Depth+Clarity, thinkFaster→Opening+pace-fast, calmerDelivery→pace-fast+pace-slow+Pace, momentum/leverage/ai-strength/ai-improvement never match any priority — keeps chip signal high), `CoachContextBuilderIntentTests` (intent tail appears with label, omitted with nil, defensive omit on whitespace-only label), `PracticeSessionIntentDecodingTests` (old persisted session decodes intent as nil, new session with intent round-trips). Closes M21 of the M19-M23 slate; M19 (Big Moment Intake) + M20 (Forward Plan) + M21 (Session Intent) now ship in sequence as `docs/M19_strategy.md` recommended — the persistent AI coach now reads the user's declared focus from every recent rep and the summary cards visually confirm "you aimed for this, here's what landed." Previously: M20 — Forward Plan: 4-week coach-written program lands end-to-end. New `Noum/ForwardPlanStore.swift` (per-account UserDefaults `forwardPlan.<accountID>`, MainActor singleton with `replace(_:)` / `clearPlan()` / `reloadForCurrentAccount()` / `endSession()` / `deleteAllData(for:)` mirroring the BigMomentStore lifecycle pattern); `ForwardPlan` struct (id + `weeks: [PlanWeek]` exactly 4 + `generatedAt` + `bigMomentID: UUID?` + `voiceAtGeneration: SpeakingStyleGoal?` + `isAIBacked: Bool`) carries the program; `PlanWeek` (weekIndex 1..4 + focus + focusSkillArea + suggestedMode + sessionTarget 2..5 + ≤200-char rationale) is the per-week unit. Pure-function `ForwardPlan.currentWeekIndex(now:calendar:)` projects the plan onto the calendar — week 1 on days 0..6, week 4 clamps past day 28 so the coach keeps coaching after the program ends; `ForwardPlan.isInvalidated(by:)` detects BigMomentID drift so a stale plan can warn rather than silently misrepresent. New `Noum/ForwardPlanService.swift` actor wraps the OpenAI/DeepSeek/Gemini provider plumbing (same shape as `AIInsightsService`) with JSON-strict response shape and a parallel `nonisolated static` deterministic fallback that builds the same 4-week shape from declining trends → weak-stable trends → baseline thresholds → voice goal alignment → BigMomentCategory mock mode → consolidation. Honest about provenance: `isAIBacked: false` on the rule-based path so the UI labels accordingly rather than presenting template copy as AI insight. Pure helpers (`weakestSkillArea(baseline:trends:)` / `strongestSkillArea(baseline:)` / `modeFor(skillArea:)` / `bestModeForVoice(_:)` / `mockModeFor(category:)` / `sessionTarget(weeklyReps:base:)`) all exposed for tests. New `Noum/ForwardPlanRenderer` produces multi-paragraph coach-voice text (opening with BigMoment reference when set + AI-vs-rule-based provenance line, one paragraph per week, voice-shaped closing line for all 6 voices + nil). New `Noum/ForwardPlanCoordinator` (MainActor enum) is the bridge: `buildInput()` assembles the snapshot from live stores (CoachingProfile + Baseline + sessions + rating + BigMoment + SkillTrendStore.snapshots + StreakFreezeManager.currentStreak + DrillHistoryStore.entries), `generateAndAnnounce()` calls the service + persists via `ForwardPlanStore.replace(_:)` + injects the rendered coach message via new `AskNoumStore.injectCoachTurn(_:)`. `CoachContextBuilder.userContext(...)` gains an optional `forwardPlan:` parameter; PLAN section renders current week's focus + mode + rationale + completed-vs-target progress, with explicit "stale" warning when BigMomentID drift is detected — coach is told to recommend regeneration rather than quote a misaligned plan. `AskNoumView.runReply` threads both BigMoment + ForwardPlan into the context call so every reply reads the current week. New `Noum/CoachingPlanCard.swift` — Profile-tab surface with pure `CoachingPlanCardVisibility.resolve(plan:profile:sessions:activeBigMomentID:now:calendar:)` four-state resolver (`.hidden` when no profile or no plan + <3 sessions, `.prompt` when ≥3 sessions but no plan, `.live(plan, completed)` when matching/both-nil BigMomentID, `.stale(plan, completed)` when BigMomentID drifted). The view renders three layouts: pre-prompt CTA card, live week+progress card, stale card with "regenerate" hint. Voice-shaped CTA copy mirrors the `askNoumProfileLabel(for:)` catalog so all entry points sound coherent. Card tap → opens noum://ask AND fires `ForwardPlanCoordinator.generateAndAnnounce()` on prompt/stale states. `Noum/AskNoumStore` gains `injectCoachTurn(_:) -> UUID?` (trims whitespace, returns nil on empty, appends as a non-pending `.coach` row without setting `isAwaitingReply` — direct injects don't lock the input bar). `Noum/AuthManager.deferStoreReloadForCurrentAccount` + `deferStoreSessionReset` extend to include `ForwardPlanStore.shared`; `clearAllUserData(for:)` adds `forwardPlan.<accountID>` + the M19 `bigMoment.<accountID>` + `bigMomentArchive.<accountID>` keys that were missing from the wipe list. 50+ new tests across 6 suites: `ForwardPlanCalendarTests` (11 tests: week 1 on day 0/6, week 2 on day 7, week 4 on day 21, week 4 clamp past day 42, currentWeek resolution, dateRange seven-day half-open, dateRange clamp on out-of-range index, isInvalidated mismatch / match / both-nil / cleared / added contracts), `ForwardPlanProgressTests` (5 tests: in-week sessions count, out-of-range exclude, week-2 boundary count, empty sessions zero, day-7 boundary fires into week 2), `ForwardPlanServiceDeterministicTests` (20 tests: 4-week count, isAIBacked false, voice carrying through, declining-high-confidence week 1, baseline filler week 1, voice-goal week 2, structure fallback week 2, sudden-death week 3, no-filler-stack week 3, BigMoment mock week 4 mapping for each category, consolidation week 4 when no BigMoment, sessionTarget clamping at floor/ceiling/steady, modeFor/bestModeForVoice/mockModeFor mappings, brand-voice exclamation contract across all variants, weakestSkillArea priority / strongest nil-when-insufficient / strongest-finds-low-filler), `ForwardPlanRendererTests` (6 tests: opening references BigMoment, generic without, rule-based honesty, AI-backed honesty, includes all 4 weeks, voice-shaped closing + no exclamations across all 6 voices × BigMoment-or-not), `ForwardPlanContextTests` (4 tests: PLAN omitted when nil, PLAN present when set, progress count matches sessions filter, stale warning surfaces when BigMomentID differs), `CoachingPlanCardVisibilityTests` (9 tests: hidden-when-no-profile, hidden-when-<3-sessions, prompt-at-3, live-on-match, live-on-both-nil, stale-on-drift, stale-on-cleared-moment, live carries completed count, voice-shaped CTA labels for every voice + live-state-empty contract), `AskNoumStoreInjectCoachTurnTests` (5 tests: nil on empty / whitespace-only, append as non-pending coach row, doesn't set isAwaitingReply, trims). Closes M20 of the M19-M23 slate; M19 (Big Moment Intake) and M20 (Forward Plan) now ship in parallel as `docs/M19_strategy.md` recommended. Previously: M18 + M19 strategy push — Sudden Death rework + SpeechRecognizer crash guard + 3-track personalization research synthesized into M19-M23 roadmap: M18 ships Sudden Death as the filler-eradication game its name promises — `PressureRoundConfig.config(for:difficulty:)` now hard-codes `fillerTolerance: 0` across all 8 rounds × 3 difficulties (one filler = instant elimination); `SuddenDeathDifficulty.fillerToleranceShift` removed since it no longer varies; difficulty subtitles updated to reflect new meaning ("Wider start window. More time per round." / "Tight start window. Less time per round."); `RoundOutcome.fillerOverload.label` "Filler Spike" → "Filler — instant elimination"; new `PressureTimerEngine.pendingUserWaitingRound: Int?` published property + `confirmBeginUserWaiting()` method gates the `.npcTurn → .userTurnWaiting` phase transition on TTS `didFinish` so the prompt card stays expanded through the full readout; new live `N/10 words` counter chip during `.userTurnActive` with calm secondary→accent→primary color progression + light haptic (`UIImpactFeedbackGenerator.light`) firing once per round on the exact frame `wordCount` crosses `minimumWords`; new `Noum/SuddenDeathHighScoreStore.swift` (per-account UserDefaults `suddenDeath.bestRounds.<difficulty>.<accountID>`, same pattern as RatingStore, `recordRun(roundsSurvived:difficulty:) -> Bool` returns isNewBest); new `Noum/SuddenDeathResultView.swift` (318 LOC, extracted from inline `resultScreen` lines 905-1029 of SuddenDeathPracticeView) replaces "Rushed Start" mode-name header with contextual run-summary header — "New Best · N rounds" / "Clean Run · N rounds" / "Eliminated · Round N", mode/difficulty demoted to subtitle; number-roll-up animation 0→final over 0.6s ease-out, reduce-motion users see final value immediately; NEW HIGH! badge with SparkleRibbon when `recordRun` returns true; real `UIActivityViewController` share button via `UIViewControllerRepresentable` wrapper (plain-text snippet, no fake-social fabrication — anti-goal compliant); XP chip bumped from 12pt caption to `.title3.weight(.bold)` so it reads as a reward not a footnote; 17 new tests across SuddenDeathMechanicTests (11) + SuddenDeathHighScoreStoreTests (6). M19 fix pass closes two M18 smoke-surfaced bugs: (1) `SpeechRecognizerViewModel.startAudioStream` `installTap` was throwing NSException → SIGABRT when `inputNode.inputFormat(forBus: 0)` returned a 0-channel format on the simulator after `.playback` (TTS) → `.playAndRecord` transition; defensive guard now checks `inputFormat.channelCount > 0 && sampleRate > 0` and throws typed `AudioStreamError.invalidInputFormat` instead of crashing; `.allowBluetooth` added to session options for valid sim input format; (2) cloud TTS path (`IMMessageSpeaker.speakPrompt`) was returning `true` the instant the network fetch completed not when audio actually finished, so the prompt card was collapsing mid-readout — now estimates readout duration from word count (0.55s/word × 0.85 rate + 0.5s overhead, floor 1.5s), `Task.sleep`s that duration, then clears `isSpeakingPrompt` + calls `confirmBeginUserWaiting()`; npcCard collapsed `lineLimit` bumped 2 → 3 as gating-failure safety net. M19 strategy phase: 4-agent parallel research team produced three independent deliverables — `docs/M19_audit_personalization.md` (every Noum intake field + per-session metric + derived insight mapped to USED/PARTIAL/DORMANT verdicts with file:line citations; finding: 11 intake fields, 3 USED, 4 PARTIAL, 4 DORMANT including `successVision` which evaporates after one-time AI paraphrase; `TrendAnalyzer` direction outputs never reach `CoachContextBuilder.userContext` so the persistent AI coach cannot cite "your filler rate has been declining for 3 weeks"), `docs/M19_audit_coach_workflow.md` (£130/hr human-coach workflow mapped across 7 engagement phases — intake/diagnostic/individualized plan/drill prescription/check-in/adapt/capstone — with per-phase verdict on Noum coverage; honest finding: Phase 4 drill prescription is genuinely strong via `TrendAnalyzer.primaryFocus` + `RecommendationBiasEngine` + mode differentiation, extend not rebuild; top 3 highest-leverage closures: no Big Moment capture / plan is invisible / adaptation is silent), `docs/M19_proposed_milestones.md` (5 concrete M19-M23 milestones with per-milestone architecture sketch + success criteria + anti-goal compliance check + estimated parallel track count). All three tracks reasoned independently and converged on Big Moment capture as the foundational gap. `docs/M19_strategy.md` synthesizes all three into a single decision-grade roadmap. Previously: M17 polish push — eloquence promotion + single-event timing + live transcript preview + chip parser tests: continues the M17 polish arc by closing four of the six items the previous two handoffs flagged as concrete + deferred, leaving the two that need real device access. (1) `WhatYouDidWellCard.computeBullets(...)` now promotes the first eloquence finding **above** the second good category — a detected rhetorical move is concrete on-tape evidence; a second "felt solid" is the same impression as the first, so concrete beats restated under the 3-cap. Refactor extracts a `private static func bullet(forGoodCategory:)` helper so the two category-bullet construction sites stay byte-identical. Two test updates: `eloquenceFindingDropsWhenMomentumPlusTwoCategoriesAlreadyFill` renamed to `eloquencePromotedAboveSecondGoodCategory` with the assertion flipped; new `secondGoodCategoryStillLandsWhenNoEloquence` locks the no-eloquence path so the common-case visual doesn't regress. (2) `PreSummaryCelebration.present(index:)` tightens single-event full-motion timing to ~0.65s total (vs ~1.1s multi-event): in-spring response 0.42s, hold 0.35s, bars delay 0.12s, bars spring 0.40s — multi-event keeps the original parade-of-moments timing, reduce-motion path unchanged (was already ≤0.7s). (3) `AskNoumView.inputBar` lifted from a single HStack into a VStack of (`partialTranscriptPreview` + `inputBarRow`). New `partialTranscriptPreview` `@ViewBuilder` renders only while `voiceInput.state == .recording`: shows "Listening…" at 0.55-opacity italic brand-blue when the recognizer hasn't landed a word yet; shows the live `partialTranscript` at 0.85-opacity once words arrive. Waveform icon with `.symbolEffect(.variableColor.iterative)` (reduce-motion suppressed); VoiceOver label flips with content. Transition is `.opacity` + `.move(edge: .bottom)`; `.animation` modifiers debounce both state and text changes, both nil under reduce-motion. The `AskNoumVoiceInput` wrapper was already publishing `partialTranscript` per M17 — the view just hadn't consumed it. (4) New `CoachContextBuilderChipParserTests` suite (18 tests) covering `parseAndFilterChips`: happy path (3 tests: plain newline-separated, nil-on-shortfall, extra-truncated-to-count), cleanup (4 tests: bullet/dash markers, numeric enumeration, straight + smart quotes, blank lines + whitespace), brand-voice contract (8 tests: exclamation drops, `let's`/`Lets` drop, 7 leading directives parametrized, emoji pictograph drops, min-4-char drops, max-60-char drops, exact-min-and-max-pass, unicode-below-emoji-threshold-passes), and integration (2 tests: layered mess recovery, count not exceeded). The function is `internal` on the `CoachContextBuilder` enum so `@testable import Noum` reaches it; `passesChipFilter` is `private` but every gate it enforces is locked through the parser-level interface. — Previously: M17 redesign integration verification + bullet selector test contract: the M17 summary redesign (PreSummaryCelebration + WhatYouDidWell / WhatToImprove hero cards + TalkToNoum CTA) landed unverified in commit `77c3524`. This push locks the design contract by refactoring the bullet-selection logic out of the View body into pure `static func computeBullets(...)` accessors on `WhatYouDidWellCard` and `WhatToImproveCard` — the custom-filler-words dep flows in as a parameter so tests don't have to mutate `ClutchWordStore.shared`. New `TalkToNoumCTACard.headlineCopy(isPremium:)` / `subCopy` / `ctaCopy` / `accessibilityLabel` static accessors expose the copy contract. 25 new tests across three suites — `WhatYouDidWellBulletSelectorTests` (11 tests: minimal-effort silence, momentum-only / empty-momentum, good-categories cap at 2, .ok rating excluded, eloquence drop-when-saturated / land-with-headroom, eloquence snippet→.quote evidence, AI strength headroom gating, AI empty-string defensive, hard 3-cap, category note→text evidence), `WhatToImproveBulletSelectorTests` (13 tests: minimal-effort silence, clean-rep silence, leverage+nextStep evidence binding, filler ≥2 threshold, filler cluster framing ≥5, leverage-by-name dedup against category, category cap at 2, pace-fast ≥170 WPM, pace-slow ≤95 WPM, pace headroom suppression, pace min-words/duration gates, AI keyImprovement tail + headroom suppression, hard 3-cap), `TalkToNoumCTACardCopyTests` (5 tests: headline invariance, sub-copy divergence, CTA copy by state, brand-voice contract (no "!", no "Let's", no chirpy filler — applied across every emitted string), accessibility lock-signal only-for-free). Closes the verification gap left by the partial M17 commit; the design contract is now compiler-enforced. — Previously: Growth Library — quote → source session navigation + seeded CoachingProfile: each `GrowthLibraryView` quote card is now a `NavigationLink(value: AppDestination.sessionDetail(sessionID:))` so the user can tap a banked moment → land on the full `SessionHistoryDetailView` that produced it (same chrome the History tab uses; full transcript, AI coach read, IM conversation card, metric breakdown). `ContentView`'s destination switch resolves the session against the live `PracticeSessionStore` with a graceful `SessionHistoryView` fallback if the source session was deleted since the artifact was banked. `SessionHistoryDetailView` lifted from `private struct` → `struct` so the destination switch can render it without duplication. New `AppDestination.sessionDetail(sessionID: UUID)` case + four `AppDestinationSessionDetailTests` lock the Hashable / Equatable / distinctness contract. The Growth Library moves from read-only evidence-display ("here's a thing you said") to a learning loop ("here's a thing you said — go re-read the full session"). Closes the explicit "future move" left in the previous push's HANDOFF. ALSO: `DevSeedData.injectProfile(_:)` now seeds `CoachingProfileStore` alongside sessions / baseline / rating / XP via a new internal helper `seedCoachingProfile(for:)` (each `SeedProfile` carries a narrative-coherent voice + priority + challenge + brief + motivation + success vision — improvingIntermediate → warm + moreConcise, plateauedAdvanced → authoritative + presentations, pressureVulnerable → executive + calmerDelivery, fillerFree → concise + persuasive, beginner → warm + reduceFillers + rebuilding). New DEBUG-only `CoachingProfileStore.replaceForDebug(_:)` mirrors the pattern of `PracticeSessionStore.replaceAllForDebug` / `RatingStore.replaceForDebug` and skips production side effects (backend sync, AI paraphrase). Closes the M16 explicit TODO that sat in `NoumUITests.swift:23`: `testHomeScreenAndPrimaryNavigation` reverts from the `noum://path` deep-link fallback back to the tap-the-card pattern on `home.path` (with deep-link fallback retained for slow-simulator flakes). HomeSignalGate's `coachingProfileSet` branch now lights up for every seed profile, so every M14 goal-aware surface — VoiceAnchorBanner, LiveEloquenceHUD, VoiceAlignmentChip, goal-progress ring — has something to read on a seeded simulator. Seven `DevSeedCoachingProfileTests` lock the per-seed voice mapping + completeness contract + ≥4 distinct voices across the 5 seeds for visual breadth in the screenshot tour. // Previous Growth Library push: the chip on `ProfileView` is now a `NavigationLink(value: AppDestination.growthLibrary)` that opens `GrowthLibraryView` — quote cards (italic verbatim slice + technique chip + claim + relative date + AI/Live badge) grouped into "This week" / "Last week" / "Week of MMM d" buckets via a new pure `ProofMomentStore.weeklyGroups(from:now:calendar:)` static helper; new `noum://growth` deep link for symmetry with `noum://ask`; honest empty state when archive is cold; six `GrowthLibraryWeeklyGroupingTests` lock the grouping contract — empty input → no buckets, same-week collapse, newest-week-first, This/Last-week labels, older buckets use explicit week-of-date, cross-year buckets carry the year so January 2025 vs January 2026 can never blur. Continues the M15 "a coach who's actually present" arc: the evidence the coach references in chat is now also browseable on the profile, so the user can see their own progress in their own words.) M5–M13 shipped, M14 in flight: goal-aware coaching surfaces + LookingAheadCard + mid-session voice anchor + goal-aware live HUD + Typography Dynamic Type contract + goal-aware coach note momentum + visible goal-progress ring on the profile + home recommendation voice-alignment chip + calmer-delivery snapshot trend + Looking-Ahead voice chip closes the loop + goal-aware drill picker closes the inside of the loop + goal-aware leverage + next step + drill rationale closes the verdict copy edge + goal-aware delivery bonus closes the scoring edge — score, copy, and drill are all goal-aware end-to-end + **Home Coach Card hero redesign** + **6-surface premium hero pattern** (Profile/Review/Settings/Mode Picker/Path Journey/Bottom Nav) + **noum-screenshots skill + SessionEnd hook + 27-shot detailed tour** + **tab-level `noum://` deep links** + **UI_TESTING_SEED_FORCE + celebration suppression** + **VoiceAlignmentChip on hero** + **NoumCharacterStage 5-stage story arc** + **Path-centric Home (second hero with Chapter/Mission framing)** + **VoiceMetricsCard (Pause + Word Choice first-class)** + **PathNodeCelebration cinematic upgrade** + **Mission framing copy** + **SummaryView "Mission cleared" headline on path unlock** + **AIWeeklyInsightCard chapter eyebrow mirrors path chapter** + **HomeCoachCard now serves the empty state too — unified premium first impression** + **Ah-Counter hero parity with other modes** + **Coach voice audit — 7 user-facing exclamations dropped** + **NoumCharacterStage test coverage** + **Ask Noum — persistent AI coach chat with voice-specific personality + full user context** + **Proof Moments — transcript-anchored evidence of growth on Weekly Insight + Path Celebration + Personal Best** + **Summary → Ask Noum bridge — session-anchored, voice-shaped opener seeds the chat so users can ask their coach about THIS rep with one tap** + **Goal-aware live UI extended to every practice mode — VoiceAnchorBanner + LiveEloquenceHUD now ship in SuddenDeath, AhCounter, and IM, not just Timed; banner gains `resetsBetweenReps: false` so multi-round / multi-turn surfaces fire it once per session, not once per turn** + **Ask Noum third entry point — Profile Coaching Direction card now carries a restrained voice-shaped "Ask Noum about your goal →" link; persistent-coach footprint now reaches Home (ambient) + Summary (rep-anchored) + Profile (goal-anchored), all three through the same `noum://ask` deep link** + **`firebase.json` carries the `firestore.rules` pointer — `firebase deploy --only firestore:rules,hosting` is now the literal command for the M14 milestone deploy, no config edit step in between** + **Ask Noum follow-up chips — three voice-shaped, topic-anchored nudges land beneath the most-recent coach reply, turning the chat from respond-and-wait into a live, alive conversation; first match wins on drill / pause / pace / filler / weekly anchors with a generic fallback so every reply yields chips, restraint contract collapses the row on pending / system-notice / empty-reply states, every voice × topic cell carries three brand-voice-compliant chips locked by tests** + **Proof Moment archive — every generated proof persists per-account in `ProofMomentStore` (max 12 records, idempotent on session ID, dropped-by-addedAt cap, most-recent-by-session-date sort); the Ask Noum coach reads the freshest three via a new optional `recentProofs:` param on `CoachContextBuilder.userContext` and surfaces a `PROOFS` section with verbatim quotes the model can quote back at the user ("Three weeks ago you said 'we focused on three priorities' — that's the move you've been refining"); no proofs = no section (cold-start users never see a fabricated quote); fifteen unit tests lock persistence round-trip, per-account isolation, idempotency, cap-by-addedAt eviction, most-recent-first ordering, hard-3-cap in context, GOAL-precedes-PROOFS section order** + **M15 Phase 3 — Mode literacy tap-to-expand: each `PracticeModeOptionRow` gets a "What this trains" affordance with 3 lines of coach-voice copy (Pressure type / What it surfaces / Typical rep length) wrapped in a 28pt `NoumCharacter.Inline` `.coaching` glyph. Set-based multi-row-open semantics, separate row-select Button vs 44×44 expand-overlay Button, reduce-motion gated via `animateMode(_:)`, existing `practiceMode.<id>` accessibility IDs preserved (tour regression gate) plus new `practiceMode.<id>.expandButton` IDs added. Four `PracticeModeRowExpansionTests` lock the contract (complete triple per mode / no chirpy filler / rep-length mentions a unit / lines stay terse)** + **M15 Phase 4 — Home discipline (signal-gated home cards): new `Noum/HomeSignalGate.swift` (pure function over sessionStore + pathProgress + coachingProfileStore + AppStorage override) → `HomeCardGate` struct of per-card `Bool` flags. Cold start shows only Coach + UtilityStrip + AskNoum (3 cards); Daily Challenge + VoiceMetrics unlock at session 1; AI Weekly Insight at 3 sessions per ISO week; Journey at goal-set state OR unlocked path node. Settings "Show every home card" toggle (`practice.showAllHomeCards` AppStorage) is the full-reversibility escape hatch. Seven `HomeSignalGateTests` pin every branch including the ISO-week boundary and the `allVisible` override contract**)_

## Architecture overview

- **Framework:** SwiftUI, iOS 17 minimum.
- **App targets:** Main iOS app (`Noum`), home-screen + lock-screen widgets
  (`NoumWidget`, also hosts the Live Activity), iMessage extension
  (`NoumMessages`), and a watchOS glance (`NoumWatch`, currently detached
  from the iOS scheme until the watchOS 26.2 simulator runtime is installed
  locally).
- **State management:** `ObservableObject` singletons (`*.shared`) injected into
  views via `@StateObject` — `AuthManager`, `ProfileManager`,
  `PracticeSettingsManager`, `HapticsSettings`, `NotificationManager`,
  `NotificationPrePromptManager`, `PremiumManager`, `CoachingProfileStore`,
  `PracticeSessionStore`, `IMVoicePlaybackSettingsManager`,
  `RecommendationLearningStore`, `RatingStore`, `BaselineStore`,
  `ChallengesManager`, `FriendsManager`, `ClubsManager`, `AchievementStore`,
  `ClutchWordStore`, `LessonStore`, `PathProgressManager`,
  `OnboardingHeroManager`, `StreakFreezeManager`,
  `FirstRepCelebrationManager`, `DeepLinkRouter`. No Observation-framework
  migration yet.
- **Persistence:** `UserDefaults` keyed per-account
  (`<key>.<accountID>`), Keychain for the account ID + provider, and
  `BackendSyncManager` for optional Firebase sync of XP, sessions,
  coaching profile, and recommendation outcomes.
- **Cross-process state:** `SharedNoumState` writes a JSON snapshot
  (streak, freezes, reps-today, next-node) into the
  `group.com.jordancoaten.noum` App Group. `SharedNoumStateMirror` keeps
  it fresh after every session finalize and on every scenePhase active.
  Widget extension + Live Activity read this snapshot — never the main
  app's UserDefaults.
- **Audio / speech:** `AVAudioEngine` capture →
  pluggable `TranscriptionProvider` (AWS Transcribe streaming, Deepgram
  WebSocket, Google Speech-to-Text V2). Provider chosen via the
  `transcriptionProvider` AppStorage key. On-device `SFSpeechRecognizer`
  is **not** used.
- **Backend:** Firebase Auth (Apple, Google, anonymous), Firestore
  via `BackendSyncManager`, optional REST backend for vended AWS
  credentials. Privacy posture documented in `Noum/Noum/PRIVACY_*.md`.
- **AI providers:** Google Gemini, OpenAI, and DeepSeek for coaching
  analysis (`AINPCChatService`, `AIInsightsService`, `GoalParaphraseService`),
  configured in `AIConfig.plist`. Google Cloud TTS for IM voice playback
  with OpenAI fallback.
- **URL scheme:** `noum://` registered in `Info.plist`. `DeepLinkRouter`
  buffers incoming URLs until `ContentView` owns the navigation stack.
  Routes: `noum://growth`/`library`, `noum://lesson/<id>`, `noum://practice`/`train`,
  `noum://review`/`history`, `noum://profile`/`social`, `noum://settings`,
  `noum://home`, `noum://league`, `noum://path`, `noum://lessons`,
  `noum://friend/<id>`. Tab-level routes were added M14 for the
  `noum-screenshots` skill — each resets `navigationPath` and pushes
  the corresponding `AppDestination` for atomic tab jumps. Cold-start
  routing via `-DeepLink <noum://...>` launch arg lets `simctl launch
  --terminate-running-process` drive nav without iOS's "Open in Noum?"
  confirmation blocking headless capture.
- **Screenshot + handoff workflow:** `noum-screenshots` skill copies
  live at `.agents/skills/noum-screenshots/` (Codex skill body) and
  `.claude/skills/noum-screenshots/` (SessionEnd hook target), each
  with a `.mode` file (`off`/`light`/`detailed`). Light = 5 tab tops
  via `-DeepLink` (~30s); detailed = 27-shot tour via `xcodebuild
  test -only-testing:NoumUITests/ScreenshotTour/...` (~3min).
  `SessionEnd` hook in `.claude/settings.json` auto-runs light at
  session end. HANDOFF.md files commit to git (cross-machine
  protocol); PNGs are gitignored (local artifact).
- **Cloud routine prompts:** six markdown briefs in `.routines/`
  (vision drift audit, refactor backlog grinder, coach voice copy
  audit, localization migration, test coverage scan, M5 goal-aware
  HUD step). Each prompt is self-contained for scheduled cloud
  agents to run cold.
- **Test-mode launch args:** `UI_TESTING` (skip onboarding hero),
  `UI_TESTING_SEED` (seed if empty), `UI_TESTING_SEED_FORCE` (always
  reseed — used by the tour for deterministic state),
  `FORCE_GOAL_REFRESH` / `FORCE_NOTIFICATION_PROMPT` (force-fire
  conditional sheets for capture). Celebration suppression
  (`LeagueManager.suppressCelebrationsForTesting()` +
  `DailyGoalManager.consumeGoalCelebration()` + `PathProgressManager.
  consumeCelebration()` + `LessonStore.consumeCelebration()`) fires
  after seed inject so overlay celebrations don't block tour taps.
  **`DevSeedData.injectProfile(_:)` now also seeds
  `CoachingProfileStore`** via `seedCoachingProfile(for:)` (internal,
  per-seed narrative — improvingIntermediate → warm + moreConcise,
  plateauedAdvanced → authoritative + presentations, pressureVulnerable
  → executive + calmerDelivery, fillerFree → concise + persuasive,
  beginner → warm + reduceFillers + rebuilding). A new DEBUG-only
  `CoachingProfileStore.replaceForDebug(_:)` mirrors
  `replaceAllForDebug` / `replaceForDebug` patterns on the other
  stores and skips production side effects (backend sync, AI
  paraphrase). HomeSignalGate's `coachingProfileSet` branch now
  lights up for every seed profile, so M14 goal-aware surfaces
  (VoiceAnchorBanner, LiveEloquenceHUD, VoiceAlignmentChip,
  goal-progress ring) all read on a seeded simulator — and the UI
  test `testHomeScreenAndPrimaryNavigation` reverts from the
  `noum://path` deep-link fallback back to the tap-the-card pattern
  on `home.path` (deep-link fallback retained as defense against
  slow-simulator flakes). Seven `DevSeedCoachingProfileTests` lock
  the per-seed mapping + completeness + ≥4-distinct-voices contract.
- **Design tokens location:** `Noum/DesignSystem.swift` — single source
  of truth for `Spacing`, `CornerRadius`, `AppColor`, springs, shared
  components (`CardView`, `StatCard`, `PrimaryCTA`, `PressableButtonStyle`,
  `LightGradientBackground`, `SectionHeader`, `ErrorCard`,
  `MilestoneCelebrationOverlay`, `EmptyStateView`). **Typography lives in
  `Noum/Typography.swift`** — Figtree (display/rounded) + Manrope
  (text/UI), bundled as variable TTF in `Noum/Resources/Fonts/`,
  registered via `Info.plist` `UIAppFonts`. The default body font is
  set globally on the app root with `.environment(\.font, Typography.body)`.
- **Design spec:** `.claude/skills/noum-design/` — voice rules, color
  palette, type scale, motion, iconography. `DesignSystem.swift` +
  `Typography.swift` win on conflict.

## Key files / modules

### Home (M14 redesign)
- `Noum/HomeCoachCard.swift` — unified home hero. Single composed
  card carrying `NoumCharacter` (90pt, mode-tinted) + `coachTitle`
  + `coachSubtitle` + `VoiceAlignmentChip` + "Begin · <Mode>" CTA.
  Background: Pro-purple radial wash + faint mode-tinted trailing
  accent + purple hairline border + soft purple elevation shadow.
  Two registers: purple = "your coach speaking", mode tint = "this
  is what to do." **Now serves both the empty-state (brand-new
  user) and populated-state (returning user)** — replaces the
  legacy `heroCard + firstSessionCard` pair on empty state. The
  no-signal branch reads `.listening` mood (the coach is hearing
  you for the first time, not advising you yet) + profile-aware
  subtitle (picks up `CoachingProfile.biggestChallenge` if the
  user finished onboarding) + "Begin · First rep" CTA. ~155 LOC
  of duplicated empty-state UI deleted from `ContentView`.
- `Noum/HomeUtilityStrip.swift` — slim 36pt row beneath the Coach
  Card. Streak chip on left (taps → Profile), word-of-day on
  right (taps → seeds a Timed rep). No card chrome, low-emphasis
  by design.
- `Noum/Noum/DailyChallengeTile.swift` — coach-voice rewrite
  (5 states). Row subtitles dropped (title + XP only); subtitle
  moves to accessibility label. Inline `NoumCharacter.Inline`
  glyph in the TODAY header. Copy register: "Today's mission" not
  "Today's challenge" — uniform with journey card + path nodes.
- `Noum/VoiceMetricsCard.swift` — first-class Home card surfacing
  Pause + Word Choice metrics (the underweight VISION items).
  Brand-blue ambient. Coach voice: "77% unique words. Up from
  65% last week." Collapses entirely when no qualifying data —
  no placeholder.
- `Noum/NoumCharacterStage.swift` — five-stage character story
  arc (`awakening` 0–500 XP → `voice` 500–1500 → `composure`
  1500–3500 → `command` 3500–8000 → `mastery` 8000+). Pure-
  function `current(xp:)`. Per-account ratchet (UserDefaults key
  `noumCharacter.peakStage.<accountID>`) — never visible
  regression on XP drops. Applied to NoumCharacter atop mood;
  stage = lifetime arc, mood = moment-to-moment state.

### AI Coach Chat ("Ask Noum") — persistent coaching companion
- `Noum/AskNoumView.swift` — chat surface with embodied NoumCharacter
  header (60pt, brand-purple, listening mood while a reply is in
  flight). Empty state renders a voice-specific headline + body +
  4 starter prompts so first-message friction is zero. Threads
  alternate brand-blue user bubbles (right-aligned) with white
  coach cards (left-aligned, NoumCharacter.Inline glyph for
  continuity). Reduce-motion-aware typing indicator. Tap-to-
  clear via menu. **Follow-up chips ("Keep going") appear beneath
  the most-recent coach reply** — three voice-shaped, topic-
  anchored nudges sourced from `CoachContextBuilder.followUp-
  Suggestions(forCoachReply:voice:)`. Topic detection finds drill /
  pause / pace / filler / weekly anchors in the reply text (first
  match wins; falls back to a generic chip set). Each chip is a
  capsule button; tap fires the same `send` path as starters, so
  the chip text lands as the user's next turn. Chip row collapses
  when (a) the latest message is pending, (b) the latest message is
  a system notice, (c) a reply is in flight, (d) the reply is empty.
  Visual register: `Typography.caption.weight(.semibold)` brand-
  purple text on `AppColor.cardBackground` capsules with a quiet
  brand-purple stroke — quieter than the starter chips (which are
  full rows) so they read as an extension of the conversation, not
  a second prompt block. Wraps via the existing `FlowLayout`
  (defined for the AIWeeklyInsightCard evidence pills) so the row
  breaks gracefully on small widths.
- `Noum/AskNoumStore.swift` — per-account ObservableObject thread
  store. Capped at 40 messages on disk; pending coach rows never
  persist (mid-reply crash → clean relaunch). User-authored
  messages get a UUID at send for dedupe. Replay-for-model
  excludes system notices + pending rows.
- `Noum/AICoachChatService.swift` — actor wrapping the same
  OpenAI / DeepSeek / Gemini providers as `AIInsightsService`.
  Multi-turn replay capped at 24 messages per request; temp 0.6,
  max_tokens 380. Failure-soft: nil return on any error → store
  renders a system notice instead of an empty bubble.
- `Noum/CoachContextBuilder.swift` — pure-function context layer.
  `systemPrompt(for:)` composes a brand-voice frame + per-voice
  personality block (authoritative = "senior advisor giving a
  verdict", warm = "trusted mentor genuinely curious", concise =
  "clipped, one idea per turn", persuasive = "structured,
  premise→evidence→recommendation", executive = "chief-of-staff
  briefing", storytelling = "narrative arcs"). `userContext(...)`
  produces a structured snapshot the model gets every turn: goal,
  rating + tier + delta, baseline numbers (only when confidence
  ≥ initial — never quotes a fake-zero stat), recent 3 sessions,
  path chapter + mission, trends, **and a PROOFS block of up to
  three verbatim transcript-anchored moments from past reps**.
  Insufficient-confidence dimensions are omitted entirely so the
  model cannot fabricate; the PROOFS block is similarly omitted
  when the archive is empty (cold-start users get no fabricated
  quotes). When proofs exist, the model is instructed to quote
  them directly when relevant — "Three weeks ago you said 'we
  focused on three priorities' — that's the move you've been
  refining" instead of generic numeric framing.
- `Noum/ProofMomentArchive.swift` — per-account `ProofMomentStore`
  (ObservableObject, `@MainActor`) persisting `ProofMomentRecord`
  entries to UserDefaults keyed `proofMoment.archive.<accountID>`.
  Bounded at 12 records, idempotent on `sessionID` (re-saving a
  proof for the same session replaces — so a deterministic
  fallback upgraded by a later AI fetch lands cleanly), cap
  evicts oldest-by-`addedAt` (so a recent refresh-replace doesn't
  accidentally drop the record we just upgraded), `recent(limit:)`
  returns most-recent-first by `sessionDate`. `ProofMomentService.
  proof(for:)` writes successful proofs into the store via a
  MainActor hop so the chat surface has on-disk continuity even
  after the actor's in-memory cache evaporates. Reused by
  `AskNoumView.runReply` (passes `proofStore.recent(limit: 3)`
  into the context block). **Now also surfaced visually** via
  `Noum/GrowthLibraryView.swift` — see the Growth Library bullet
  below.
- `Noum/GrowthLibraryView.swift` — Profile-launched timeline that
  renders the same archive as quote-anchored evidence the user can
  actually browse. Each entry is a card: technique chip + verbatim
  quote (italic, prefixed with a quote glyph in muted Pro-purple) +
  one-line claim + relative date + an honest "Coach reading" /
  "Pattern match" badge that tells the user whether the proof was AI-
  generated or pattern-matched. Records group by ISO week via a new
  `nonisolated static ProofMomentStore.weeklyGroups(from:now:calendar:)`
  pure helper — buckets labelled "This week" / "Last week" / "Week of
  MMM d" (with year suffix when the bucket year doesn't match the
  current year, so January 2025 vs January 2026 never blurs). Empty
  archive renders an honest empty state ("Nothing banked yet …"). The
  surface is purely additive — no scoring change, no notification,
  no streak loop. Closes the M15 vision arc end-to-end: the same
  evidence the coach quotes in chat is now also visible on the
  profile so the user can see their own progress in their own words.
  Reachable via Profile chip (`profile.insightsBanked.link`) or
  `noum://growth` deep link. Each quote card in the library is now a
  `NavigationLink(value: AppDestination.sessionDetail(sessionID:))` so
  the user can tap a banked moment → land on the same
  `SessionHistoryDetailView` the History tab uses — full transcript,
  AI coach read, IM conversation card, metric breakdown. The Growth
  Library moves from evidence-display to a learning loop: see the
  thing you said, then go re-read the full session you said it in.
  `ContentView`'s destination switch resolves the session against the
  live `PracticeSessionStore` with a graceful `SessionHistoryView`
  fallback when the source session has been deleted since the
  artifact was banked. `SessionHistoryDetailView` lifted from
  `private struct` → `struct` (internal) so the destination switch
  can render it without view duplication. Four
  `AppDestinationSessionDetailTests` lock the Hashable / Equatable /
  distinctness contract.
- Home entry: `ContentView.askNoumPromoCard` — brand-purple
  ambient card between journey card and DailyChallengeTile.
  Voice-specific headline + body + "Open the thread →" CTA.
  Tap pushes `AppDestination.askNoum`. Also reachable via
  `noum://ask` deep link.
- Profile entry: `ProfileView.askNoumProfileLink` — restrained
  brand-purple "Ask Noum about your goal →" link at the bottom
  of the Coaching Direction card, sits right after the
  goal-progress ring + captured reflections + coaching insight.
  Voice-shaped label catalogue mirrors the home promo and
  summary bridge so all three coach entry points sound like the
  same voice (e.g. authoritative: "Ask Noum what to drill
  next"; warm: "Talk to Noum about your goal"; concise: "Ask
  Noum — one move"). Hidden when no `CoachingProfile` is set
  (silent for pre-onboarding sessions, matching the rest of the
  goal-aware surfaces). Uses `openURL("noum://ask")` so the
  existing `DeepLinkRouter` consumer in `ContentView` owns the
  navigation — no path binding leaks into Profile. Restrained
  visually (no card chrome, no glyph) so it reads as a quiet
  handoff inside the existing Coaching card, not a second hero
  competing with the goal ring above. Closes the persistent-
  coach footprint: the user can now reach Ask Noum from Home
  (ambient promo), Summary (session-anchored bridge), and
  Profile (goal-anchored link).
- Post-session entry: `SummaryView.askCoachBridgeCard` — small
  brand-purple bridge card inside the secondary stack (above
  `xpProgressCard`, below the drill CTA) that opens Ask Noum
  with a session-anchored opener already seeded in the thread.
  Voice-shaped headline ("Want a verdict on this rep?" /
  "Want the one move from this rep?" / etc.) + NoumCharacter
  inline glyph for register continuity. Tap fires
  `onAskNoumAboutRep(opener)` — the path-based init wires the
  callback to inject the opener into `AskNoumStore` then push
  `AppDestination.askNoum`. `AskNoumView.onAppear` consumes
  `AskNoumStore.pendingInjectedCoachID` and runs the model so
  the user lands inside a reply already in flight. Hidden when
  the callback isn't wired (previews / share-card render
  paths). `CoachContextBuilder.sessionOpener(mode:score:
  fillerCount:duration:voice:)` is the pure-function copy
  generator — produces a two-sentence opener with concrete
  metrics + a voice-shaped ask (authoritative gets a verdict
  ask, warm gets a felt-experience ask, executive gets a
  brief, storytelling references the arc, etc.). Single-filler
  / no-score paths degrade cleanly (no "0/10" leakage,
  pluralisation handled). `AskNoumStore.injectUserTurn(_:)`
  is idempotent while a reply is pending — double-tapping the
  bridge returns the existing pending coachID instead of
  queuing duplicates. After the prior reply lands, re-inject
  legitimately appends a fresh pair (the user is asking
  again). Twelve unit tests in `CoachContextBuilderTests`
  (sessionOpener block) + `AskNoumStoreTests` (cross-surface
  inject block) lock the metric-presence, pluralisation,
  score-absence, voice-shape, every-voice-handled,
  pending-id-publish, consume-once, idempotency-while-pending,
  empty-text-rejected, re-inject-after-reply, and clear-
  thread-wipes-signal contracts.

### Proof Moments — transcript-anchored evidence of growth
- `Noum/ProofMomentService.swift` — actor that extracts ONE
  short (5–14 word) verbatim quote from a session's transcript
  + a voice-specific technique label + a one-sentence coach claim.
  AI path uses the same provider plumbing as `AIInsightsService`
  with a JSON-strict response shape (`quote`, `technique`,
  `claim`). Verifies the quote actually appears in the transcript
  (case-insensitive, smart-quote-normalised) before caching — any
  fabrication falls through to the deterministic template path.
  Deterministic fallback picks the longest 4–14-word clause from
  the transcript and stamps it with a voice-specific
  (technique, claim) shape — e.g. authoritative + clean rep =
  "Declarative Close", concise + clean rep = "BLUF",
  storytelling + long rep = "Scene Set". Per-session cache
  (`UUID → ProofMoment`); invalidation via `invalidate(sessionID:)`.
- `Noum/AIWeeklyInsightCard.swift` — "Proof of the week" section
  appended below the AI narrative body. Picks the highest-scoring
  rated session from the 7-day window so the proof reads as a
  victory lap, not a random sample. Collapses entirely if no
  qualifying session exists.
- `Noum/PathNodeCelebration.swift` — accepts optional `proof:`
  param. When non-nil, renders an italicized quote + technique
  chip below the stat line, fading in alongside the stat. Loaded
  on appear via `ContentView.loadPathCelebrationProof()`. Visual
  restraint: this is the celebration register, the proof is
  supportive (not shouting).
- `Noum/CelebrationViews.swift` `PersonalBestCelebrationScreen` —
  accepts optional `proof:` param. Loaded on appear via
  `SummaryView.loadPersonalBestProof()` from the just-finished
  session so the quote is fresh in the user's ear.

### Path / mission gameplay loop
- `Noum/Noum/PathProgressManager.swift` + `Noum/Noum/PathNode.swift`
  — node-by-node unlocks (unchanged this push; consumed widely).
- `Noum/Noum/ContentView.swift` `journeyPreviewCard` — promoted to
  slot 3 (Home position 2 after Coach Card + utility strip). Reads
  as a SECOND HERO: brand-blue ambient + "YOUR JOURNEY · Chapter ·
  <Tier>" eyebrow + "Mission X of N" + node title + gating line +
  "Open the Path" CTA.
- `Noum/HomeCoachCard.swift` — new `mission-within-reach` coach
  title variant when `PathProgressManager.currentNode` is one rep
  / score-point from unlocking. Drives users at the path naturally.
- `Noum/Noum/PathNodeCelebration.swift` — full-screen cinematic
  on path unlock: brand-blue radial backdrop, 140pt stage-aware
  NoumCharacter (`.excited`), "Mission Complete." headline,
  chapter eyebrow, specific stat line ("X reps. Y clean pauses.
  You earned this."), five-beat motion sequence (reduce-motion-
  aware).
- `Noum/Noum/SummaryView.swift` — headline variant: when
  `PathProgressManager.shared.pendingCelebrationNodeID` is set,
  the summary reads "Mission cleared" instead of the score-based
  generic ("Strong delivery" / "Building momentum" / etc.).
- `Noum/Noum/AIWeeklyInsightCard.swift` — chapter eyebrow above
  the headline tied to `PathProgressManager.currentNode.node.tier`
  (the *path-chapter the user is travelling through*), not the
  rating tier — so the eyebrow always matches what the journey
  card on the same screen reads. Falls back to LeagueTier only
  when the path is cleared. Reads "CHAPTER · BRONZE" while still
  in the Bronze section of the path, even if the user's overall
  rating has reached Gold.
- `Noum/Noum/ProgressionCharts.swift` — pillar picker (Score /
  Fillers / Pace / Pauses / Pitch) now scrolls horizontally with
  `.fixedSize` on each pill so the labels never wrap mid-word
  ("Fill / ers", "Pa / ce") when the row exceeds the rating
  card's inner width.

### Core practice loop
- `Noum/Noum/PracticeModeSelectionView.swift` — mode picker, drives
  `RecommendationBiasEngine` for the recommended row.
- `Noum/Noum/TimedPracticeView.swift` — Timed mode (3 difficulties,
  optional Pressure Mode, optional thinking time).
- `Noum/Noum/SuddenDeathPracticeView.swift` — pressure mode where one
  filler ends the round. Now exposes a per-mode difficulty
  (Easy/Medium/Hard) that scales filler tolerance and start-window.
- `Noum/Noum/AhCounterView.swift` — free-form speak with live filler
  and pacing tracking.
- `Noum/Noum/IMPracticeView.swift` — live AI conversation reps with
  tone/scenario control.
- `Noum/BeatTheBrakeView.swift`, `LandThePauseView.swift`,
  `PREPStackView.swift` — focused mini-drills layered on top of the
  main modes.
- `Noum/Noum/PressureTimerEngine.swift` — auto-ramping round configs:
  start window 12s→3s, filler tolerance 3→0, follow-ups in R2/3/5,
  fresh prompt in R4.
- `Noum/Noum/LiveEloquenceHUD.swift` — in-session detection chip; pops
  briefly when `EloquenceEngine` recognises a rhetorical device mid-rep.
- `Noum/Noum/PressureLiveActivityCoordinator.swift` — Live Activity
  that mirrors a Sudden Death session to the Dynamic Island + lock
  screen. Shipped end-to-end; needs real-device QA (Live Activity is
  not testable on simulator).

### Lessons (Duolingo-style teaching layer)
- `Noum/Noum/Lesson.swift` + `LessonsCatalog.swift` — five lessons
  across rhetoric, structure, presence, and recovery, each with three
  steps (concept → spot it → say it).
- `Noum/Noum/LessonStore.swift` — 0–5 crown progression per lesson,
  per-account; emits a `LessonCelebration` (unlocked / levelUp /
  mastered) on each pass that the home screen consumes.
- `Noum/Noum/LessonView.swift` + `LessonsHomeView.swift` — catalog
  browser with crown rows, summary strip, first-time empty state, and
  the `LessonCelebrationOverlay` that fires on every crown gain.
- Lessons feed back into the path: `PathProgressInput.totalLessonCrowns`
  and `maxLessonCrown` are read by criteria like
  `totalLessonCrowns(N)` / `lessonMastered`.

### Speech & feedback
- `Noum/Noum/SpeechRecognizerViewModel.swift` — provider-agnostic
  capture + filler highlight + recording.
- `Noum/Noum/FillerWordDetector.swift` — semantic vs disfluency
  classification, prompt-echo exclusion, confidence scoring 0.15–0.95.
- `Noum/Noum/WPMEvaluator.swift` — mode + tone + scenario aware WPM
  bands (Timed 130–160, Sudden Death 140–170, IM 100–135).
- `Noum/Noum/RatingEngine.swift` + `RatingStore.swift` — ELO-inspired
  100–1000 rating, only Pressure Mode sessions move it, K-factor decays.
- `Noum/Noum/BaselineEngine.swift` + `BaselineStore.swift` — 0–10
  session score, strengths, persistent blockers, pressure profile.
- `Noum/Noum/TrendAnalyzer.swift` — improvement/stable/declining/
  newIssue/resolved classification per skill snapshot.
- `Noum/Noum/EloquenceEngine.swift` — eleven rhetorical-device
  detectors (tricolon, anaphora, epistrophe, alliteration, isocolon,
  antithesis, polysyndeton, asyndeton, diacope, epizeuxis, rhetorical
  question). Conservative thresholds; covered by 9 unit tests.
- `Noum/Noum/EloquenceXP.swift` — 5–25 XP per detected device,
  60-cap per session, diminishing returns inside a single rep.
- `Noum/Noum/AIInsightsService.swift` — narrative insight generator
  (weeklyNarrative / sessionDebrief / patternBreak). Reuses the
  Gemini/OpenAI/DeepSeek provider plumbing; falls back to a template
  when no AI provider is configured. Cached per week-bucket so quota
  isn't re-spent on the same input.

### Progression & retention
- `Noum/Noum/ProfileManager.swift` — XP store (per-account), level
  ladder (`Beginner/Novice/Average/Professional/World Class` × I/II/III),
  rank symbol/tint/title.
- `Noum/Noum/ModeMastery.swift` (in `PracticeSupport.swift`) — per-mode
  mastery (Bronze/Silver/Gold/Platinum) computed from session count +
  baseline score within that mode. Surfaced on the profile and read by
  path criteria (`modeMasteryLevel`, `modeMasteryAnyLevel`).
- `Noum/Noum/AchievementStore.swift` + `Noum/Noum/AchievementsTreeView.swift`
  — 7 tracks (Volume, Consistency, Clarity, Scores, Endurance, Modes,
  Mastery) plus a hierarchical tree view that visualises locked /
  unlocked branches.
- `Noum/Noum/ChallengesManager.swift` — daily/weekly/streak/social
  challenge models; `RetentionLoopEngine` produces an "active challenge"
  snapshot for the home screen.
- `Noum/Noum/PathNode.swift` + `PathNodeCelebration.swift` +
  `PathProgressManager.swift` — node-by-node path with concrete entry
  conditions evaluated against `PathProgressInput` (sessions, baseline,
  rating, streak, mode-mastery, lesson crowns). The home screen surfaces
  the next node with a one-tap CTA. Past + current + next-3 visible on
  the path map; further-out nodes stay masked. **M3 milestone shipped.**
- `Noum/Noum/PathJourneyView.swift` — habit-first journey page (2026-06-10
  overhaul, founder voice-feedback driven). The landscape artwork binds to
  the BASE `PracticeJourneySnapshot` (1/21 of the trail per practiced day
  in a rolling 21-day window) — the habit metaphor, NEVER node counts
  (`applyingPathPresentation` removed; `withDisplayedStreak` swaps in the
  freeze-aware streak). Page reads top-to-bottom as one story: hero
  landscape (destination glow at the vanishing point + full `NoumCharacter`
  walker standing at the reveal frontier, stage-ratcheted, additive-only —
  no dimming on absence, ever) → consistency strip ("N of the last 21 days
  walked" — never "Day N", the window rolls) → single Today CTA → "Why
  you're walking" card (provenance rule: quotes + italics ONLY for the
  user's literal words — successVision → motivationWhyNow → paraphrasedGoal
  → coachingBrief → capture invitation, `JourneyWhyComposer` pure + tested,
  incl. a never-punish sweep over every state) → "Trail landmarks" card
  (System B demoted to a position read) → challenge + skill milestones
  collapsed into one "Along the way" disclosure → honesty footer. Flag tap
  scrolls to the why card. **Vocabulary: "mission" → "landmark" app-wide**
  (PathJourneyPresentation, ContentView journey card + a11y IDs,
  PathNodeCelebration headline "Landmark reached.", YourArcCard,
  HomeCoachCard, SummaryView headline, DailyChallengeTile → "Today's
  focus", LedgerRoleLines.landmarkRole, CoachContextBuilder "- Current
  landmark:"; "landmark" verified collision-free vs "marker"/"chapter"/
  "waypoint"). On-artwork landmark pins deliberately NOT shipped: pinning
  node positions onto a days-driven reveal implies a day↔node equivalence
  that doesn't exist (fake-progress). Day-bloom settle beat shipped
  (2026-06-11): on page appear, `JourneyDayBloomRatchet`
  (`Noum/Noum/JourneyDayBloomRatchet.swift`; per-account UserDefaults key
  `noum.journey.lastSeenPracticedDays.<accountID>`, seed-on-first-sight,
  upward-only fire, silent decrease on window slide — the league-
  promotion-guard lesson) compares live practiced days against last-seen;
  on a genuine rise the artwork holds at the previous fraction for ~0.5s
  then plays one ~0.8s settle — reveal band advances, new flowers
  stagger-bloom (flower/grass nodes got stable index ids so insertions
  animate instead of the whole field crossfading), and the walker steps
  forward with a single `.moodPulse(.excited)` (`MoodPulseWrapper` now
  carries `stage` and is one-shot per identity, so no replay on
  nav-back). Reduce-motion replaces the settle with a whole-artwork
  crossfade and no pulse. The ratchet commits atomically inside
  `evaluate` — an interrupted bloom is dropped, never replayed — and is
  unit-tested (`JourneyDayBloomRatchetTests`). Both ratchet keys (stage +
  day-bloom) enumerated in `AuthManager.clearAllUserData`. Still
  deferred: walker-relative pins, grass sway, wear system, full-bleed
  hero.
- `Noum/Noum/StreakFreezeManager.swift` — weekly-replenishing streak
  freeze; protects the streak across one missed day per ISO week.
  Wires the app icon badge through `UNUserNotificationCenter.setBadgeCount`
  (passively gated on authorization, never triggers a prompt).
- `Noum/Noum/NoumCharacter.swift` — abstract speaker-character composed
  from SF Symbols (waveform variants + halos + glow), four moods (calm /
  listening / excited / coaching), state-specific accents (sparkle ribbon
  on excited, symmetric arc-pulses on listening, slight tilt on coaching).
  Used on the home hero, FirstRepCelebration, ProfileView header,
  AchievementsTreeView hero strip, and the journey-page walker. Brand-rule
  compliant: motion + color + shape, no illustration. 2026-06-10: the
  continuous 30fps phase loop + mastery sparkle loop are now held in
  `@State` task handles and cancelled in `onDisappear` (previously raw
  `Task { while true }` — every appearance leaked a loop that span forever
  after the view left the hierarchy); `runEntrance` restarts them on
  re-appearance.
- `Noum/Noum/PauseMetrics.swift` + `Noum/Noum/PauseSummaryCard.swift` —
  M4 v1: pause statistics (count, mean, longest, filled-vs-unfilled
  ratio) computed from word timings during finalize. Card hides when
  no metrics; integrates into BaselineEngine + ProgressionCharts +
  TrendAnalyzer + path-node criteria (`heldSilentPause`,
  `cleanPauseSession`).
- `Noum/Noum/WordChoiceMetrics.swift` + `Noum/Noum/WordChoiceCard.swift`
  — M4 v1: unique-content-word ratio + top 3 repeated content words
  after stop-word + filler filtering. Card hides for sessions under
  20 content words.
- `Noum/Noum/PrivacyInfo.xcprivacy` — App Store privacy manifest
  declaring data collection categories (audio, name, user ID,
  product interaction, crash + performance), API usage reasons
  (UserDefaults `CA92.1`, system boot time `35F9.1`, file timestamp
  `C617.1`), and `NSPrivacyTracking=false`. Required for App Store
  submission since May 2024.
- `Noum/Noum/SoundscapeEngine.swift` + `Noum/Noum/SoundscapePickerView.swift`
  — pre-rep ambience generator (`AVAudioSourceNode`-based pink/brown
  noise + sine drones), 4 modes (Off/Focus/Calm/Steady), Pro-gated for
  non-Off modes. Wired into Timed thinking-window, AhCounter launch
  countdown, and SuddenDeath countdown phase. Cuts the moment recording
  starts so it never bleeds onto the rep.
- `Noum/Noum/TierPromotionOverlay.swift` — full-screen tier-up
  celebration (Bronze→Silver, etc.). Detected by `LeagueManager` via
  `lastSeenTier` persistence; fires through `fullScreenCover(item:)` so
  promotions earned mid-session show on next home open. First-launch
  guard prevents false promotion celebrations on brand-new installs.
- `Noum/Noum/FirstRepCelebration.swift` + `Noum/Noum/ConfettiLayer.swift`
  — first-rep moment: full-screen overlay + share sheet rendered via
  `ImageRenderer`. Fires once, persists per-account.
- `Noum/Noum/OnboardingHeroView.swift` + `OnboardingHeroManager.swift`
  — three-screen value-prop intro presented on first launch via
  `fullScreenCover`. Skipped under `UI_TESTING` and
  `UI_TESTING_SEED` arguments.
- `Noum/Noum/ProgressionCharts.swift` — animated `SwiftUI Chart` views
  (LineMark + AreaMark) for filler trend, score trend, and pace
  trend on the profile. Replaces the older "trend pill only" surface.
- `Noum/Noum/WeakAreasCard.swift` + `Noum/Noum/MistakeReplayCard.swift`
  — Review-tab surfaces that summarise the patterns the user is
  repeating and let them tap into a re-prompted rep.
- `Noum/RewardEngine.swift` (`Noum/`) — emits XP, streak, and
  milestone events.

### Notifications (4 surfaces, soft-sell pre-prompt)
- `Noum/Noum/NotificationManager.swift` — three daily-rhythm surfaces
  (`scheduleDailyReminder`, `scheduleStreakWarning`, `scheduleWeeklyDigest`)
  plus the legacy 18h follow-up. `refreshScheduledNotifications` is
  called on every scenePhase active, but is **passive** — it reads
  `UNUserNotificationCenter.notificationSettings()` and only re-arms
  when status is authorized/provisional/ephemeral. The hard system
  prompt is reserved for the explicit `set*Enabled(true)` toggles
  fired from the pre-prompt sheet.
- `Noum/Noum/NotificationCopy.swift` — lock-screen-safe streak-aware
  copy. Title/body adapts to streak length, freezes available, and
  reps today.
- `Noum/Noum/NotificationPrePrompt.swift` — soft-sell sheet shown
  exactly once after the first finished rep (`sessionCount == 1`).
  "Maybe later" honours a 30-day cool-down. The accept path enables
  all three daily-rhythm surfaces in sequence so iOS only prompts once.

### Social
- `Noum/Noum/FriendsManager.swift` — local friends list, names only,
  no phone numbers. Optional `accountID` per friend so peer stats can
  be fetched from `profiles_public/{accountID}` (M2).
- `Noum/Noum/ChallengesManager.swift` — async challenge model
  (two participants, prompt, results). Backend round-trip via
  `BackendSyncManager.syncAsyncChallenge` / `fetchAsyncChallenges`.
- `Noum/Noum/ClubsManager.swift` — clubs scaffolding.
- `Noum/Noum/SocialProfileView.swift` — older public-facing profile
  view (not the active surface; `ProfileView.swift` at the project root
  is what the home nav routes to).
- `Noum/Noum/LeagueManager.swift` + `Noum/Noum/LeagueView.swift` —
  weekly league with tier-from-rating bucketing
  (`{tier}_{ISO-year}-W{week}`), reads top 20 members per bucket.
- `Noum/Noum/PublicProfileSnapshot.swift` — Codable subset written to
  `profiles_public/{accountID}` and to `leagues/{bucket}/members/{id}`.
  Read by friends + league.
- `FIRESTORE_RULES.md` (project root) — rules required to deploy the M2
  collections safely (peer-readable but owner-write only).

### Premium & infra
- `Noum/Noum/PremiumManager.swift` — StoreKit 2 (Monthly/Annual),
  feature gates, monthly video-analysis credits.
- `Noum/Noum/AuthManager.swift` — Apple, Google, anonymous, account
  delete with full per-account UserDefaults wipe.
- `Noum/Noum/BackendSyncManager.swift` — Firebase + REST sync.

### Widgets, Live Activity, iMessage, watchOS
- `NoumWidget/` — five widget sizes (small/medium/large for streak +
  lock-screen rectangular/circular). Reads `SharedNoumState` from the
  App Group. Hosts the Live Activity bundle.
- `NoumWidget/PracticeLiveActivity.swift` — Live Activity layout for
  Sudden Death rounds (Dynamic Island compact / expanded / minimal).
- `Noum/PracticeLiveActivityAttributes.swift` (also copied into the
  widget target) — shared `ActivityAttributes` definition; both targets
  must compile against the exact same struct.
- `NoumMessages/` — iMessage extension scaffolding for sharing rep
  results / async-challenge invites inline.
- `NoumWatch/` — watchOS 10+ glance. Detached from the iOS scheme
  pending local install of the watchOS 26.2 simulator runtime.

### Settings & UX primitives
- `Noum/Noum/SettingsView.swift` — production settings (refactored).
- `Noum/Noum/SettingsRow.swift` — `SettingsToggleRow`, `SettingsNavRow`,
  `SettingsStatusRow`, `SettingsSectionLabel`.
- `Noum/Noum/EmptyStateView.swift` — reusable empty-state component
  (large tinted SF Symbol → headline → body → optional capsule CTA).
  Used on Lessons, Session History, Friends, Friend Leaderboard, and
  Async Speak-offs surfaces.
- `Noum/Noum/HapticsSettings.swift` — global haptics gate, honored
  by `CoachHaptic` and every `.sensoryFeedback`.
- `Noum/Noum/CoachHaptic.swift` — every haptic pattern routes through
  `HapticsSettings.isEnabledSync`.

## Feature status

### Implemented (shipping end-to-end)

- **M15 closed + M16 retention surfaces shipped (2026-05-21)** —
  `Redesign` branch carries 12 commits closing out M15 ("a coach who's
  actually present") and starting M16 (retention surfaces).
  - M15 Phase 1b — `NoumCharacter` orb wired into all 5 practice views
    with live `speechVM.audioLevel` binding. Per-view tints + sizes
    (44pt setup, 32–36pt active bars). Immersive layouts deliberately
    skip the orb since `SpotlightOrbView` owns the visual center there.
    Commit `121d270`.
  - M15 Phase 2 — `FirstRepCelebration` quotes the user's actual words
    via a deterministic fallback chain: `celebrationLocalProof` →
    `minimumVerbatimSlice` (sentence > comma > 4–14 word window).
    Voice-shaped framing per `SpeakingStyleGoal`. `.noticing` orb pulse
    when the proof lands. Commit `b5f8d56`.
  - M15 Phase 5 — `insightsBankedChip` on Profile + `insightsCaption`
    in Ask Noum, both gated on `ProofMomentStore.records.count > 0`.
    No streak shame, no zero-state placeholder. Commit `2ec3c7b`.
  - M15 release audit (`docs/M15_release_audit.md`) — 14 M15-touched
    files audited against VISION anti-goals + a11y checklist. Clean on
    anti-goals; one SHOULD-FIX patched inline (`.accessibilityHidden(true)`
    on hero `NoumCharacter` + reduceMotion gate on `loadProof`'s
    `withAnimation`). Commits `d4eb4cf` + `94f7b96`.
  - M15 test coverage — 39 new tests across 3 suites in
    `NoumTests/NoumTests.swift` (FirstRepCelebrationFallbackTests,
    HomeSignalGateEdgeTests, InsightsBankedChipTests). Minimal
    Phase 2 refactor (`celebrationLocalProof`, `minimumVerbatimSlice`,
    `wordCount` dropped to internal; `quoteFraming` body extracted to
    static `quoteFramingCopy` so it's testable without a View instance).
    Commit `409f4f2`.
  - M15 UI test reliability — `testHomeScreenAndPrimaryNavigation`
    originally rewrote the journey-card assertion from tap-the-card to
    deep-link via `noum://path`, mirroring
    `ScreenshotTour.launchSeededAt`, so the test could pass on a
    freshly-erased simulator. The later Growth Library seed-profile
    pass closed that temporary gap: `DevSeedData.injectProfile` now
    populates `CoachingProfileStore`, and the test again prefers the
    tap-the-card path with the deep link retained only as a slow-sim
    fallback. Commits `bad4824` and Growth Library seed-profile push.
  - M16 Peak-rating wall (VISION future-milestone #1) — new
    `PeakRatingWallView` with three sections (Best in week / Best ever /
    Best in your friends), per-section empty-state behaviour, sparkline
    that collapses below 2 points. `LeagueManager` extended with
    `peakRatingsInBucket(limit:)`; `RatingStore` gains
    `peakRatingThisWeek`. Entry links from Profile + LeagueView.
    Commit `60c8ce1`.
  - M16 Daily-challenge rhythm v1 (VISION future-milestone #3 + closes
    the "single tile" known-debt entry) — M8 pool extended 8 → 30
    challenges across filler-discipline, mode-specific, pace, sustain,
    pause, pitch (`PitchMetrics.isReliable`-gated), pressure, engagement.
    Fixed a real determinism bug in M8: `DailyChallengeGenerator.hash()`
    used Swift's randomised Hasher, so trios changed across app
    relaunches. Replaced with FNV-1a 64-bit seed of (dayKey + accountID).
    New 8:30 PM expiry warning notification (offset from streak warning).
    `LeagueManager.recordDailyChallengeCompletion` adds a weekly
    engagement counter — NOT a rating mutator. Commit `faa84e6`.
  - M16 Word of the day (VISION future-milestone #5) — M9 catalog
    extended 30 → 142 entries chosen for communication value (no SAT
    vocab, no consultant jargon). Same FNV-1a determinism fix applied
    to `WordOfTheDayCatalog.entry(for:accountID:)`. "Used today" check
    indicator on the home strip word button. Deleted dead
    `WordOfTheDayTile.swift`. Commit `a7a17a6`.
  - M15 release prep — version bump 1.0 → 1.1, build 1 → 2, and
    `docs/RELEASE_NOTES.md` written. Commits `bc4e83d` + `bacc63b`.

- **Onboarding hero** — `OnboardingHeroView` shows on every brand-new
  account install. Three-screen value prop ("speak with more clarity"
  → "real-time coaching" → "believable progress"). Skip + Begin both
  persist `hasSeen`. Bypassed under `UI_TESTING` so the screenshot
  tour isn't gated by it.
- **Lessons system (Duolingo-style)** — five lessons × three steps ×
  0–5 crowns, with celebration overlay on every crown gain. Surface
  reachable from the home tab; lesson progress feeds the path via
  `totalLessonCrowns` / `maxLessonCrown` so the curriculum and the
  path are one progression, not two.
- **Path nodes (M3 v1)** — node-by-node gameplay with concrete entry
  conditions (`scoreAtLeast`, `streakAtLeast`, `modeMasteryLevel`,
  `cleanRunsInWindow`, `totalLessonCrowns`, etc.). Home shows the next
  node with one-tap CTA. Path map renders past + current + next-3 with
  state indicators; further-out nodes stay masked.
- **Eloquence detection + XP** — `EloquenceEngine` runs on every
  session transcript and surfaces eleven rhetorical devices in the
  summary's `EloquenceFindingsCard` plus a brief in-session HUD.
  Detections award 5–25 XP each, capped at 60/session with diminishing
  returns. Conservative thresholds; the card hides when there's nothing
  notable. Inspired by Forsyth's *Elements of Eloquence*. Unit-tested.
- **Speech projects** — Toastmasters-inspired structured prepared
  speeches in `Noum/SpeechProject.swift` + `SpeechProjectsView`. Eight
  projects (Ice Breaker, Table Topic, Vocal Variety, Body of Evidence,
  Storytelling Arc, Persuade with Structure, Teach It in 90,
  Inspire Your Audience) with concrete objectives and curated prompts.
  Reachable from the practice picker; project context is handed off
  to `TimedPracticeView` via `SpeechProjectContext.current`.
- **Speech-to-text** — three providers (AWS Transcribe streaming,
  Deepgram WS, Google Speech V2) with quality metrics tracked per
  provider.
- **Filler word detection** — semantic ("like" as simile vs filler),
  prompt-echo aware, confidence-graded. Not a naive keyword match.
- **Pace / WPM** — computed, mode + tone + scenario aware, persisted
  on every session, surfaced in summaries.
- **Scoring** — `BaselineEngine` 0–10 score every session;
  `RatingEngine` ELO-style rating for Pressure Mode sessions only.
- **Recording** — audio is implicit via transcription. Video via
  `VideoRecordingManager` saved to the app sandbox; gated to Pro.
- **Auth & accounts** — Apple, Google, anonymous "Guest" via Firebase.
  Account deletion wipes per-account UserDefaults, Firebase Auth user,
  and backend records.
- **Premium tier** — StoreKit 2 with Monthly ($4.99) and Annual ($29.99),
  feature gates for Coach Mode, Live Transcript, Filler Tracking,
  Trends, Video, Saved Transcripts, Unlimited Async Challenges, AI
  Video Analysis (5/mo), 100 AI coaching reads.
- **Streaks + freeze** — calculated from session dates; one weekly-
  replenishing freeze auto-protects the streak across a missed day.
  Surfaced in home, profile, reminder copy, widget, and the soft-sell
  pre-prompt's value-prop bullets. App icon badge mirrors the current
  streak via `setBadgeCount`.
- **Pitch trend on profile + baseline integration + grammar polish (M11)** —
  M10's known gaps are closed. `CommunicationBaseline.pitchVariation` is a
  new BaseStat dimension; only sessions with `PitchMetrics.isReliable`
  contribute (older / silent / out-of-range reps don't drag the value).
  Decoded with `decodeIfPresent` for backward compat. `SkillSnapshot.pitchMonotone`
  is a new field on the trend store; `SessionFinalizer` writes it after every
  session that captured a reliable reading. `TrendAnalyzer.analyzePitch`
  produces an improving/declining/stable read mapped to `vocalEmphasis` skill
  area (closest existing match — pitch variation is one lever vocal emphasis
  pulls). `ProgressionChartsCard` gains a 5th series — Pitch — rendering
  variation (1 - monotone) so up = better, matching the score series. Series
  is auto-included since `ChartSeries` is `CaseIterable`. New strength
  ("Vocal variety", monotone ≤ 0.35) and persistent blocker ("Monotone
  delivery", ≥ 5 reliable reads at ≥ 0.75 monotone) drop into existing
  identifyStrengths / identifyBlockers paths. AI promptContext now mentions
  pitch baseline so the coach reads can ground feedback in flat-vs-varied
  delivery. **Grammar polish service** — `GrammarFeedbackService` is a Pro-
  gated actor mirroring `AIInsightsService`'s provider plumbing
  (Gemini/OpenAI/DeepSeek). Conservative skip rules: under 12s duration,
  under 25 words, transcript confidence below 0.55, or filler ratio ≥ 30%
  (throat-clearing). System prompt forbids stylistic preferences and
  filler nags (FillerWordDetector owns that surface). Excerpt validation
  drops any note whose quote isn't actually in the transcript — defensive
  against fabrication. Cached per session ID, never re-spends quota for
  the same input. **No template fallback** — without an AI provider we
  show nothing rather than invent grammar issues. `GrammarPolishCard`
  renders up to 3 notes with category chip + severity tint + verbatim
  excerpt + imperative suggestion. "Looks clean" appears when the pass
  ran and found nothing — that's the signal that grammar was reviewed,
  not that the feature is broken. Hidden for free users (belt-and-braces
  gate at both card and service). Skipped sessions render nothing rather
  than a noisy empty state. Unit-tested at the skip-rule + parser level.
- **Pitch / intonation v1 (M10)** — On-device pitch detection via
  `PitchAnalyzer` (Sendable class). The AVAudioEngine `installTap`
  callback captures samples into an `OSAllocatedUnfairLock`-protected
  buffer with zero DSP on the audio thread. At session end, `analyze()`
  walks the buffer in 2048-sample windows (50% overlap) and runs
  vDSP-based normalized autocorrelation. Peak-picking uses first-local-
  max-above-voicing-threshold (0.30) — avoids octave doubling that
  plagues naive argmax-based pitch detectors (validated against pure
  220Hz / 140Hz sines, silent windows, and seeded white noise).
  `PitchMetrics` carries meanHz, stdHz, voicedRatio, windowCount;
  `monotoneScore` (0–1) calibrated to 8–35Hz stdev. `isReliable`
  gates surfacing — needs ≥10 windows, ≥20% voiced, and a mean inside
  70–400Hz vocal range, otherwise the summary card hides itself rather
  than mislead. `PitchSummaryCard` shows a horizontal Varied↔Monotone
  meter alongside coach copy. Legacy `PracticeSession` JSON decodes
  cleanly with nil pitchMetrics.
- **Word of the day (M9)** — `WordOfTheDayCatalog` ships 30 curated
  entries (word, part-of-speech, definition, 30s prompt suggestion, and
  inflected acceptedForms list). `entry(for:)` hashes the ISO day key
  to pick deterministically — same day, same word, no backend.
  `WordOfTheDayManager` (per-account) scans today's session transcripts
  for any acceptedForm using a word-boundary safe tokenizer (matches
  app-wide `wordCount` semantics) so substrings of unrelated words don't
  trigger. "Used" stamps a per-day set in UserDefaults so a future
  vocabulary-streak surface can read from it. `WordOfTheDayTile` on
  populated home shows the word + definition + suggested prompt;
  "Try it" seeds `timedPractice.suggestedPrompt` and pushes
  `AppDestination.timedPractice`. `SessionFinalizer` triggers
  evaluation after each session. Catalog covers ~30 days; needs growth
  to ~365 to satisfy the "no repeats inside a year" target.
- **Daily challenges (M8)** — `DailyChallenge.swift` defines 8 strict
  challenge kinds keyed to real `PracticeSession` fields (held pause
  ≥ 3s unfilled, zero-filler rep ≥ 14 words, score ≥ 8/10, etc.).
  `DailyChallengeGenerator` returns a deterministic 3-of-8 trio per
  ISO date via Splitmix64 — same day produces same trio across launches.
  `DailyChallengesManager` (per-account, `@MainActor`) auto-rolls at
  midnight, re-evaluates after each session via the SessionStore
  subscription, and exposes `readyToClaim` for tile state. Claim is
  user-tap-only; XP awarded via `ProfileManager.shared.addXP`. 9pm
  local soft-expiry switches the tile to a faded treatment (no shame)
  but stays claimable until midnight. `DailyChallengeTile` is the
  third card on populated home, between `DailyGoalCard` and
  `streakCard`. `SessionFinalizer` triggers `ensureForToday()` +
  `recomputeReady()` after every finalize. Per-device claim state —
  not synced across devices yet.
- **First-rep celebration** — full-screen overlay + share sheet on
  the user's first finished rep. Persists per-account.
- **XP / levels / ranks** — XP persistent per-account, levels derived
  (`xp / 1000` with sub-level Roman numerals), rank surface on home,
  profile, and Settings hero.
- **Per-mode mastery** — Bronze/Silver/Gold/Platinum per
  PracticeMode, derived from session count + baseline score within
  the mode. Surfaced on the profile and read by path criteria.
- **Achievements + tree view** — 7 tracks, real unlock paths, unlock
  dates stored, badge animations, plus a hierarchical
  `AchievementsTreeView` that visualises locked/unlocked branches.
- **Difficulty levels — Timed and Sudden Death** — Easy / Medium /
  Hard for both. Sudden Death difficulty scales filler tolerance and
  start-window.
- **Topic / prompt generation (M7)** — 200+ curated prompts in
  `PracticeTopics.swift` across 8 themes, plus a 70/30 mix with
  `AIPromptGeneratorService`. The AI generator is an actor that mirrors
  `GoalParaphraseService`'s provider plumbing (Gemini / OpenAI / DeepSeek)
  and produces one prompt biased by `CoachingPriority` + weakest baseline
  dimension. Deterministic `PromptContentFilter` rejects directives,
  missing terminal `?`, length out of bounds, PII shapes, and chained
  exclamations before any prompt reaches the user. `PromptHistoryStore`
  dedupes within a 14-day per-account window. The orchestrator runs the
  AI hop under a strict 3-second latency budget — falls back to the pool
  on any failure or timeout. Without an `AIProvider` configured, all
  sessions use the curated pool (no regression). Wired into
  `TimedPracticeView` and `SuddenDeathPracticeView`; mini-drills and
  async-challenge prompts intentionally keep deterministic seeding.
- **AI coaching reads** — Coach Mode + Coach Read via
  `AINPCChatService` (Gemini / OpenAI / DeepSeek), gated to Pro,
  100/mo limit.
- **AI narrative insights** — `AIInsightsService` produces weekly
  narrative + post-session debrief + pattern-break insights. Cached
  per week-bucket. Falls back to a rich template insight when no
  provider is configured so the card stays useful offline.
- **Pressure Mode** — auto-ramping round configs across Timed and
  Sudden Death; baseline-aware pressure classification.
- **Pressure Live Activity** — Sudden Death rounds mirror to the
  Dynamic Island + lock screen via `PressureLiveActivityCoordinator`.
  Shipped end-to-end; needs real-device QA.
- **Define goal & why (M5 Coach memory v1)** — captured during
  `CoachingOnboardingView`, surfaced in reminder bodies and recommendation
  context. After capture, `GoalParaphraseService` runs a single best-effort
  AI pass and stores the result as `CoachingProfile.paraphrasedGoal`. UI
  surfaces use the paraphrase via `displayableGoal`. **M5 additions:**
  `GoalRefreshManager` fires a lightweight inline direction check every
  14 days (after session 20+); `CommunicationBaseline.distanceFromGoal(_:)`
  returns a normalized 0–1 proximity metric per `CoachingPriority`;
  `AIInsightInput.goalDistance` is passed to AI prompts so the session
  debrief opens with a goal-grounding sentence; `RecommendationBiasBlueprint`
  gains `suggestedTimedDifficulty` and `suggestedTheme` (goal-mapped),
  seeded into the practice session on quick-start tap.
- **Trend charts** — `ProgressionCharts` renders animated SwiftUI
  `Chart` line + area marks for filler / score / pace on the profile.
  `TrendAnalyzer` data also surfaces as the existing trend pill.
- **Peak rating wall (M6)** — `SpeakingRating.weekPeakRating` tracks
  the highest rating reached within the current ISO week. Resets at
  every week boundary (legacy data decodes cleanly with current overall
  as the default week peak). `PeakRatingWallCard` on `ProfileView`
  shows three rows — Best ever (`peakRating`), Best this week
  (`weekPeakRating` if `isWeekPeakCurrent`, else "—"), Best in friends
  (max `lastKnownPeakRating` across linked-account friends). Honest
  empty states: "Awaiting sync" when no friend has been backend-synced;
  "No linked friends" when all friends are local-only; "You lead" when
  the user's peak exceeds every friend's; "Tied with [name]" when
  matched. Friend peer reads need `FIRESTORE_RULES.md` deployed for
  real data — card handles empty `members` arrays correctly today.
- **Recommendation engine** — `RecommendationBiasEngine` +
  `CoachingPlanner` produce next-best-mode + reason, with
  `RecommendationLearningStore` tracking whether following the
  recommendation actually moved score/filler/duration deltas.
- **Notifications — four surfaces, soft-sell pre-prompt** — opt-in
  via `NotificationPrePromptSheet` after the first finished rep, then
  three daily-rhythm surfaces (daily reminder, streak warning, weekly
  digest) plus the legacy 18h follow-up. Lock-screen-safe copy that
  never quotes the user's typed goal. Passive scenePhase refresh —
  no surprise prompts.
- **Widget extension** — five sizes (small/medium/large + lock-screen
  rectangular/circular) reading the App Group `SharedNoumState`
  snapshot. Updates after every session finalize and on scenePhase
  active.
- **Deep linking** — `noum://` URL scheme registered. `DeepLinkRouter`
  buffers the URL; `ContentView` consumes it once it owns the nav
  stack. Routes: `/lesson/<id>`, `/practice`, `/friend/<id>`.
- **Friends / async challenges (M2 v1)** — round-trip via Firestore
  shared docs at `challenges/{id}` is shipped. Each participant writes
  their own slice and reads the doc. Friend invitation by QR code
  carries the inviter's `accountID` so peer stats can be fetched.
- **Weekly league (M2 v1)** — `LeagueManager` writes the user's
  snapshot to `leagues/{tier}_{ISO-year}-W{week}/members/{accountID}`
  after every session. `LeagueView` reads top 20 of the current bucket.
  Tier is derived from rating (Bronze < 300, Silver < 500, Gold < 700,
  Platinum < 850, Diamond ≥ 850).
- **Settings** — production-quality refactor with hero profile, Pro/
  Free state, manage-subscription deep link, typed deletion confirm,
  haptics master gate, mic permission status, "Your data" sheet,
  diagnostic copy.
- **Empty-state primitive** — `EmptyStateView` shipped across Lessons,
  Session History, Friends, Friend Leaderboard, and Async Speak-offs.
  Voice-controlled (no "Let's", no exclamations, no emoji).
- **iMessage extension target (`NoumMessages`)** — scaffolded; share
  rep results / async-challenge invites inline. Not yet promoted to
  prime tab nav.
- **watchOS glance target (`NoumWatch`)** — built; detached from iOS
  scheme until local watchOS 26.2 simulator runtime install. Surfaces
  streak + reps-today + a one-tap "start a quick rep" CTA.

### Partially implemented

- **Pause analysis** — **M4 v1 shipped**. `PauseMetrics` (count, mean,
  longest, filledRatio) computed at finalize for every Timed / Sudden
  Death / Ah-Counter / IM session. Renders in the summary's
  `PauseSummaryCard`, integrated into `BaselineEngine` (`pauseRate` +
  `pauseFilledRatio` dimensions), surfaces as a 4th series in
  `ProgressionCharts`, drives 2 path-node criteria (`heldSilentPause`,
  `cleanPauseSession`) + 2 path nodes ("Hold a silent beat",
  "Composed pauses"), and drives `TrendAnalyzer.analyzePause` so the
  pause direction (improving/stable/declining) folds into the existing
  primary-focus pick. Land the Pause mini-drill remains as a focused
  in-session lock-in mechanic.
- **Word choice** — **M4 v1 shipped**. `WordChoiceMetrics` (unique
  ratio + top 3 repeated content words after stop-word + filler
  filtering, 20-content-word minimum) renders in the summary's
  `WordChoiceCard`. `ClutchWordStore` continues to track user-defined
  "clutch words" alongside. Vocabulary range was already in
  `BaselineEngine` via unique-ratio; no new dimension added (the
  existing vocab signal covers the baseline; the card surfaces the
  detail per-rep).
- **Daily / weekly challenges** — model + UI scaffold real, used by
  `RetentionLoopEngine` to produce one "active challenge" tile.
  **Auto-rotation / weekly reset / leaderboard not wired.** It's a
  single rolling status, not a true daily challenge surface.
- **Clubs** — `ClubsManager.swift` is scaffolding only; no real club
  membership / club challenges / club leaderboard ship.
- **Topic generation — AI** — pool is static. The AI infrastructure
  exists (`AINPCChatService`) but isn't wired to generate fresh
  prompts.
- **iMessage / watchOS surfaces** — both targets compile and ship;
  neither has had a real-device QA pass yet.

### Stubbed / placeholder

- **Goal-driven coaching feedback in mid-session UI** — the goal is
  captured and now reaches post-session coaching surfaces:
  `NextActionEngine.recommend` appends a goal-aligned suffix to the
  reasoning when the chosen drill targets an aligned skill area, and
  `MiniDrillResultView` shows a "Closer to your <voice> voice" capsule
  on successful drills that align with the user's
  `SpeakingStyleGoal`. Alignment map lives on
  `SpeakingStyleGoal.alignedSkillAreas` in `DrillSystem.swift` (e.g.
  `.concise` → `[conciseSpeaking, structure, fillerReduction]`).
  **Mid-session live UI now reads the goal too**: a sister mapping
  `SpeakingStyleGoal.alignedEloquenceDevices` ties each voice to the
  rhetorical moves that most directly serve it (e.g. `.warm` →
  `[anaphora, diacope, rhetoricalQuestion, alliteration]`).
  `LiveEloquenceHUD` accepts a `styleGoal:` and swaps its chip subtext
  from the neutral "noticed" to "toward your <voice> voice" the moment
  a goal-aligned rhetorical move lands during the rep, with a slightly
  brighter stroke + shadow on aligned chips so the visual rhythm
  matches the copy. `VoiceAnchorBanner` (new, restrained) pulses for
  ~4s at the top of `TimedPracticeView` on the first false→true
  transition of `speechVM.isRecording` per session, says "Toward your
  <voice> voice" once, then fades — suppressed when an active drill
  already owns the in-the-moment intent surface, and silent when no
  `CoachingProfile` is set. Together those two surfaces give every
  Timed rep at least one personalized touchpoint (banner) and a richer
  one when the listener earns a goal-aligned rhetorical move (HUD).
  **And both surfaces now extend to every other live practice mode
  too**, not just Timed: `SuddenDeathPracticeView`, `AhCounterView`,
  and `IMPracticeView` each mount a `LiveEloquenceHUD(styleGoal:)` at
  the top of their live phase and a `VoiceAnchorBanner` when a voice
  goal is set. `VoiceAnchorBanner` gains a `resetsBetweenReps: Bool
  = true` flag so the Timed default (re-arm each rep, since one
  view mount = one finished rep) is preserved, while multi-rep
  surfaces pass `false` — SuddenDeath rounds and IM dictated replies
  go through several `isRecording` cycles inside one session, and
  re-flashing the same anchor at the user each turn would dilute
  the moment. The HUD's existing self-reset behaviour (`.onChange(of:
  speechVM.isRecording)` resets the announced-device set every time
  recording flips on) is correct for those modes — each pressure
  round / each dictated reply can re-celebrate the same rhetorical
  move legitimately, since they're separate micro-reps. Result: the
  in-the-moment side of the goal-aware coaching loop ships on every
  practice surface a user can speak into, not just one. SuddenDeath
  overlay gates on `phaseGroup == .live` so setup/result stay calm;
  IM overlay gates on `isSessionActive && !isEndingConversation` so
  the setup and ending screens stay calm.
  **Post-session momentum line is now goal-aware too**:
  `VerdictEngine.generate` runs `enrichMomentumWithStyleAlignment` when
  a `styleGoal` is set — for any improving `SkillTrend` whose
  `skillArea` lands in `SpeakingStyleGoal.alignedSkillAreas`, the
  Coach Note momentum line gains a clause like "Your pace gain moves
  you toward your warm voice." Restraint built in: the helper only
  fires when there's a real improving trend on a goal-aligned skill,
  so it never invents personalization for off-goal wins. Three unit
  tests cover the celebrate / off-goal-silent / no-goal-silent paths.
  **Profile now visualises distance-from-goal as a real progress
  ring**: `GoalProgressView` (new) sits inside the Coaching Direction
  card and reads `baseline.measuredDistanceFromGoal(primaryGoal)` —
  a sibling of the existing `distanceFromGoal` that returns nil
  instead of the legacy 0.5-default when the underlying dimension is
  `.insufficient`. The ring fills to `(1 - distance) * 100%` and
  colour-bands by proximity (positive ≥ 75%, brandBlue ≥ 50%, caution
  ≥ 25%, secondary otherwise). A week-over-week trend chip ("Closer
  this week" / "Holding steady" / "Slipped this week") fires when
  `GoalProgressTrend.compute` finds ≥ 3 recent + ≥ 3 prior qualifying
  `SkillSnapshot`s. `.calmerDelivery` is now measurable end-to-end:
  `SkillSnapshot.pauseFilledRatio` is a new optional field written by
  `SessionFinalizer` whenever the session contained ≥ 1 pause (zero-
  pause reps stay nil so they can't be mistaken for "perfectly calm"),
  and `CommunicationBaseline.distanceFromGoal(_:, in:)` aggregates the
  qualifying ratios with the same 0.8 saturation target as the
  persistent baseline. The chip stays hidden until the user has
  accumulated ≥ 3 reps with real pause history in each window —
  restraint over coverage. Closes the M14 goal-aware loop end-to-end
  for every voice: the same metric that anchors the pre-rep
  `VoiceAnchorBanner`, biases the mid-rep `LiveEloquenceHUD`, and
  frames the post-rep Coach Note momentum is now visible on the
  profile as a single proximity reading the user can watch move,
  for all four `CoachingPriority` values. Fifteen unit tests cover
  the formula correctness across all four goals, the insufficient-
  data nil paths (including the zero-pause skip), the trend-direction
  classifier, and the chip-copy restraint contract.
  **Home recommendation tile is now goal-aware too**: a fifth surface
  in the chain. `PracticeMode.primarySkillAreas` maps each mode to the
  2–3 skill areas it most directly trains (e.g. `.timed` →
  `[.structure, .answerDevelopment, .openingStrength]`,
  `.ahCounter` → `[.fillerReduction, .paceControl, .pauseUsage]`).
  `SpeakingStyleGoal.aligns(with mode:)` is true iff that mode's primary
  skills overlap with the voice's `alignedSkillAreas`. `VoiceAlignmentChip`
  (new) sits under the subtitle of the home `suggestionLink` and reads
  "Toward your <voice> voice" when the chosen voice and the recommended
  mode line up. Silent in three honest paths: no `CoachingProfile`, no
  `SpeakingStyleGoal` on the profile, or the alignment intersection is
  empty (warm-voice users on a sudden-death recommendation see nothing,
  not a fake nudge). The set design ensures every voice has at least one
  aligned mode (so the chip is reachable for everyone) AND every voice has
  at least one non-aligned mode (so the chip retains meaning when it does
  fire). Twelve unit tests cover the mode→skill mapping, six aligned /
  non-aligned voice×mode cases, the coverage invariants (no orphan modes,
  no always-on voices), and the brand-voice copy guards.
  **Looking Ahead card now wears the same chip**: sixth surface in the
  chain. `LookingAheadCard.Hint` gained an optional `styleGoal:
  SpeakingStyleGoal?` field (defaulted nil so the legacy initializer
  still compiles), and the card renders the existing `VoiceAlignmentChip`
  underneath the body copy with `AppColor.tint(for:)` mirroring the
  mode-color contract used by the home tile. `SummaryView.lookingAheadHint`
  passes `coachingProfileStore.profile?.speakingStyleGoal` through. The
  same three honest silent paths apply on the post-rep surface — no
  profile, no voice goal, or off-mode alignment — so the post-session
  surface respects the same restraint the home surface respects. Six
  unit tests in `LookingAheadCardVoiceAlignmentTests` lock the
  `Hint.shouldShowVoiceAlignment` predicate independently of SwiftUI:
  aligned voice×mode shows the chip; warm→sudden-death stays silent;
  nil voice stays silent; every voice has at least one firing and one
  silent mode; the legacy initializer back-compat is locked. Closes the
  goal-aware coaching loop end-to-end — every surface the app uses to
  recommend, frame, or report on a user's next move now reads from the
  same `SpeakingStyleGoal` source of truth.
  **The drill picker itself is now goal-aware too**: seventh surface,
  closes the inside of the loop. Earlier work covered every *display*
  of the next move (pre-rep banner, mid-rep HUD, post-rep momentum,
  profile ring, home chip, looking-ahead chip) — but the actual choice
  of *which* skill area to drill on still ignored the voice goal.
  `TrendAnalyzer.primaryFocus(...)` now takes an optional
  `styleGoal: SpeakingStyleGoal?` and applies a small `+10` priority
  bonus to goal-aligned trends. The bias is intentionally small: it
  breaks ties between equal-priority candidates and tips near-ties at
  the developing/solid tiers, but the gaps between urgent tiers
  (declining-high-confidence 100, weak-stable 90, new-issue 80) are
  wide enough that an urgent off-goal trend always wins over a
  goal-aligned developing one. Urgency-first, voice-second.
  `DrillEngineV2.recommend(...)` threads `styleGoal:` through
  `determineFocus(...)` → `primaryFocus(...)` (trend path) and
  `sessionOnlyFocus(...)` (day-one path, no trends). The day-one
  fallback no longer returns the generic `.structure` when a voice
  is stated — it returns the voice's canonical
  `primaryAlignedSkillArea` (a new deterministic accessor since
  `alignedSkillAreas` is a `Set` without order). So a brand-new user
  who picks "warm" gets a pace-control drill from their first
  session, not a structure drill. `NextActionEngine.standardDrill`
  resolves `SpeakingStyleGoal` from `NextActionInput.styleGoal` and
  passes it through; `SessionFinalizer` also threads the voice into
  the Coach Note `primaryFocus` lookup so the "leverage" line stays
  aligned with the skill the drill is about to train (no more "your
  biggest opportunity is structure" appearing next to a pace drill).
  `SummaryView.drillRecommendationV2` reads
  `coachingProfileStore.profile?.speakingStyleGoal` too, so the
  view-tier preview matches the persisted recommendation. Ten unit
  tests in `GoalAwareDrillSelectionTests` lock the contract: bias
  breaks ties at the developing tier, bias never overrides
  declining-high / weak-stable / new-issue (three separate tests),
  bias is silent without a goal, day-one fallback maps every voice
  to its canonical lever, and the `primaryAlignedSkillArea`
  mapping itself is asserted against every voice in the catalog so
  a future refactor can't quietly shuffle the order.
- **AI-generated recommendation reasons** — `RecommendationBiasEngine`
  now feeds dynamic per-user `whyNow` / `whyMode` text into the
  practice mode picker's recommended row. Falls back to the pre-baked
  per-mode line when no profile / no session history exists.
  `modeBenefit` + `whyNow` also surface on the post-session summary
  via `LookingAheadCard` at the bottom of the expandable details
  section — gated on ≥3 sessions of signal AND a different
  recommended mode than the one just finished, so the in-the-moment
  drill stays the hero. The blueprint's `focus` and `target` fields
  remain home-screen only.
- **Hosted privacy policy URL** — the bundled `PrivacyPolicy.md` is
  now rendered in-app via `PrivacyPolicyView`, reachable from
  Settings → Privacy & Data → Privacy policy. `public/privacy.html`
  + `public/index.html` are staged and `firebase.json` has the
  hosting + `/privacy` rewrite. `firestore.rules` file is committed
  alongside `FIRESTORE_RULES.md`, AND `firebase.json` now carries
  the `"firestore": {"rules": "firestore.rules"}` pointer block so
  `firebase deploy --only firestore:rules,hosting --project
  noum-d0b6f` is the literal one-shot command — no in-between edit.
  Deploy was attempted from the 2026-06-08 local Codex shell, but
  this shell has Node only and no `npm`, `npx`, or `firebase` binary
  (`npx -y firebase-tools@latest --version` returned
  `zsh:1: command not found: npx`). Operational next step: run the
  literal deploy command from an authenticated machine with Firebase
  CLI, or add approved Firebase CLI tooling to this workspace.
- **SpeakingRatingCard placeholder — resolved.** When
  `rating.ratingHistory` is empty `RatingHistoryChart` returns
  `EmptyView()` from the chart slot, collapsing it entirely. The
  card header (rating number + peak + session count) stays visible
  above, and the trend strip ("Holding steady" / "Trending up" /
  etc.) still surfaces from the live trend computation. No
  placeholder copy is rendered. See `Noum/RatingHistoryChart.swift`
  lines 38–49.

### Not started

- **Multilingual support** — every transcription provider is hardcoded
  to `en-US`; all copy and prompts are English.
- **Sponsor / advertisement surfaces** — none, and they conflict with
  the paid model. Mentioned on the original Trello but flagged here
  as "do not build".
- **Lives / hearts gating** — not present (and probably not the right
  loss-aversion mechanic for a speaking app — flagged for VISION).

## Known issues / debt

- **Pressure Live Activity needs real-device QA** — Live Activity is
  not testable on simulator; lock-screen rendering and Dynamic Island
  presentation must be verified on hardware before launch.
- **NoumWatch detached from iOS scheme** — watchOS 26.2 simulator
  runtime not installed locally. Either install the runtime and
  re-attach, or keep detached until watch stack is ready for QA.
- **Onboarding goal text quality is variable** — users type free-form
  prose. The picker no longer renders this verbatim, but the underlying
  input quality means goal text shouldn't be embedded into UI without
  a paraphrase pass.
- **Daily challenge — resolved (2026-05-21, commit `faa84e6`)** —
  M16 daily-rhythm v1 replaced the single tile with 3 rotating
  challenges, deterministic daily reset (FNV-1a hash fixing M8's
  silent randomised-Hasher bug), and an 8:30 PM expiry warning
  notification. Pool grew 8 → 30 challenges.
- **`AISettingsManager` is referenced but lives inside
  `PracticeSupport.swift`** — that file is 7,800+ lines and a
  long-term refactor target.
- **UI tests — fully resolved (2026-05-22)** — the historical
  `app.buttons[...]` query + `UI_TESTING_SEED` injection fixes had
  already landed in earlier commits, and the last fragile case
  (`testHomeScreenAndPrimaryNavigation`) had been rewritten to
  deep-link via `noum://path`. The remaining "M16 follow-up" TODO
  (seed `CoachingProfileStore` from `DevSeedData.injectProfile`) is
  now closed — `DevSeedData.injectProfile` writes a per-seed
  `CoachingProfile` via the new DEBUG-only
  `CoachingProfileStore.replaceForDebug(_:)`, the
  `testHomeScreenAndPrimaryNavigation` test reverts to the
  tap-the-card pattern on `home.path` (deep-link fallback retained
  for slow-simulator flakes), and seven new
  `DevSeedCoachingProfileTests` lock the per-seed voice mapping.
  Future gated-card tests can now use tap-the-card patterns on
  every M14/M15 surface gated by `HomeSignalGate`.
- **Dynamic Type partial coverage** — every `Typography.*` role now
  binds to a `Font.TextStyle` via `relativeTo:` so the canonical type
  catalog tracks Dynamic Type end-to-end. The `figtree(...)` and
  `manrope(...)` builders require the new argument so the contract is
  compiler-enforced. Hero surfaces (`SplashScreenView`, `ProfileView`
  rank panel + rating display + league panel + goal row + reflections
  + active challenge, `SummaryView` transcript card,
  `FirstRepCelebration` CTAs, `WordChoiceCard`, `PauseSummaryCard`,
  `PersonalBestHeroCard`) migrated off ad-hoc `.system(size:)` onto the
  catalog or `Typography.figtreeNumeric(...)`. A 2026-06-08 local
  continuation also migrated the first-run login hero/buttons, Home coach
  card title, Settings cluster/micro/toggle labels, Big Moment intake
  header/category text, practice-mode picker header, session-focus prompt,
  IM conversation setup/ending copy, Path Journey headings/pill values, and
  Mode Mastery headers/badges, Ah-Counter / Pace Training / Cut the Crutch
  static mode headers and result copy, mini-drill result copy, Path mission
  completion headline, the Pro upsell title/body, Speaking Rank profile
  labels/headings, Tier Promotion league title, Skill Progress direction
  badges, review-stat badges, Coaching Profile onboarding hero copy, and
  Achievements Tree count label onto `Typography`. A later 2026-06-08
  continuation moved the personal-best celebration, level-up celebration,
  achievement unlock celebration, and post-session progression overlay copy
  onto `Typography` / `Typography.figtreeNumeric(...)`, leaving icon glyphs
  and fixed-format live practice counters alone.
  A DEBUG-only `UI_TESTING_OVERLAY <kind>` root harness in `NoumApp`
  now renders the real post-session progression, personal-best, level-up,
  and achievement-unlock overlay views for `ScreenshotTour.
  testCaptureCelebrationOverlays`; the corrected 2026-06-08 simulator run
  passed and the exported PNG attachments were spot-checked at default
  text size. A subsequent SummaryCards pass moved the score/points
  numerals and compact duration/drill/confidence badge copy off fixed
  `.system(size:)` text onto `Typography` builders. A Timed practice setup
  pass moved the `Impromptu` setup title and Coach-mode `PRO` badge onto
  `Typography`, leaving live timers/countdowns/REC/filler counters and the
  camera transcript overlay as fixed-format live controls for a separate
  layout review. A later ordinary-badge pass moved the daily goal ring count,
  feedback preview score, friend challenge score, leaderboard/rating wall ranks
  and ratings, league rating values, onboarding step ring, Sudden Death
  uncertain-fill indicator, and Sudden Death result points onto `Typography`
  builders. Large Dynamic Type and real-device overlay QA remain open.
  Remaining `.system(size:)`
  call sites are mixed: some are intentional fixed-format surfaces
  (bitmap share cards rendered through `ImageRenderer`, live practice
  countdowns/timers/WPM/filler readouts, camera overlay transcript text,
  SF Symbol icons, and decorative particles), while other legacy text in
  summary/share-card generation still needs surface-by-surface review.
  Do not treat this migration as complete until those call sites are
  audited. A unit test (`typographyRolesResolveToFonts`) locks the catalog
  contract so a future refactor that drops `relativeTo:` fails the test
  suite.
- **Firebase tooling is available; local emulators still need Java** —
  Node 22, npm, and Firebase CLI 15.23.0 are available and authenticated for
  `noum-d0b6f`. Functions lint, build, and the 22-test transport suite pass.
  The Auth/Firestore/Functions emulator integration command cannot start on
  this Mac until a Java runtime is installed; deployment remains a deliberate
  release action rather than part of local UI verification.

## 2026-07-11 — cohesive UI, language, and journey pass

- Home now resolves one evidence-backed next action, then exposes Ask Noum and
  at most one quiet conditional row. Train owns the practice library, Roleplay,
  Lessons, Speech Projects, and Path beneath one recommended rep.
- Review opens with one movement story and keeps charts collapsed. Profile has
  a compact identity line, one rating hero, one evidence-scaled coaching brief,
  and one library disclosure. Settings uses native grouped rows.
- Summary renders one verdict, one combined “What held” / “Next move” debrief,
  one next-rep action, and quiet Ask Noum, details, and Done affordances.
- Timed Practice, Pressure Drill, Filler Control, Conversation Practice, Cut
  the Crutch, Pace Training, and Roleplay keep their existing state machines
  while sharing the focused full-screen practice language. Codable mode values
  and stored sessions are unchanged.
- Presentation copy normalizes internal coaching terms at the rendering and
  Ask Noum persistence boundary; backend prompts, quality fixtures, Fast/Ultra
  routing, and wire contracts remain intact.
- Peer Comparison remains hidden without a genuine non-self member. Direct
  links show a forming state instead of fabricated standings.
- The detailed iPhone 17 tour covers tab roots, practice setup, Summary,
  onboarding, paywall, supporting sheets, and evidence-density states. The
  screenshot handoff for this pass lives under
  `.screenshots/2026-07-11_cohesive-ui-language-pass/`.

## Conventions to preserve

- **State pattern:** new managers follow `final class X: ObservableObject`
  + `static let shared = X()` + `@Published` + UserDefaults persistence.
  Injected into views via `@StateObject private var x = X.shared`.
  **Do not** introduce `@Observable` until the codebase migrates as a
  whole.
- **Per-account scoping:** every persisted user value is keyed
  `<feature>.<accountID>`. Account deletion must clear every key —
  see `AuthManager.clearAllUserData(for:)` for the canonical list.
- **Cross-process state:** widgets, Live Activity, and watch glances
  read `SharedNoumState` from the App Group. Never read main-app
  UserDefaults from an extension.
- **Notification authorization:** never trigger the iOS hard prompt
  except from an explicit user action (the `set*Enabled(true)`
  toggles wired off the pre-prompt sheet). Passive surfaces
  (`refreshScheduledNotifications`, `applyAppIconBadge`) read
  `notificationSettings()` and silently no-op when not authorized.
- **Design tokens:** all spacing, radii, and color come from
  `DesignSystem.swift` (`Spacing.*`, `CornerRadius.*`, `AppColor.*`).
  No literal hex, no magic spacing numbers.
- **Voice:** trusted speaking-coach tone. No "Let's", no chirpy
  copy, no emoji in user-facing strings, no exclamation marks
  except on celebration overlays. Use sentence case for body, section,
  navigation, and micro-label copy; uppercase is reserved for genuinely
  fixed-format technical or live-status readouts.
- **Haptics:** every haptic pattern routes through `CoachHaptic.*`,
  which honors `HapticsSettings.isEnabledSync`. SwiftUI rows with
  `.sensoryFeedback` gate on `HapticsSettings.shared.isEnabled` in
  the trigger condition. Never call `UIImpactFeedbackGenerator`
  directly.
- **Press feedback:** every interactive element uses
  `.buttonStyle(.pressable)`. No bespoke press animations.
- **Lock-screen safety:** notification copy never quotes user-authored
  goal text directly — see `NotificationManager.reminderTitle` /
  `reminderBody`, and `NotificationCopy.swift` for daily-rhythm copy.
- **AVAudioApplication.recordPermission** is the iOS 17 API. Don't
  reach for the deprecated `AVAudioSession.requestRecordPermission`.
- **Preview safety:** preview blocks must not mutate real `.shared`
  managers in ways that survive the preview tear-down. Mutations like
  `revokePremium()` / `upgradeToPremium()` are tolerated because they
  reset on relaunch, but new previews should prefer constructor
  injection where the manager surface allows it.
- **Singleton init reentry:** when a singleton's `init` calls
  `recompute()` or any mirror-write, defer the cross-singleton write
  with `DispatchQueue.main.async`. Direct calls during init can
  re-enter `.shared` and deadlock the dispatch_once.
