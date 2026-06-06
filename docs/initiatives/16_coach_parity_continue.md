# Initiative 16 — Coach-parity continuation (four threads)

Status: code-complete, NOT compiled or model-tested by the agent host (no Swift/Xcode toolchain, no LLM keys). Every symbol, case, initializer, and argument order was grep+read-confirmed against real source and every fixture hand-traced. The build, `xcodebuild test`, felt LLM quality, and rendered UI are the human's gates.

Branch: `Redesign`. All work EXTENDS existing owners — no new stores, no parallel routing. No genuinely-new file was required; the two new drills reuse the existing `FrameworkDrillChecks` + `DrillCatalog` path. 84 new tests added (1706 total in `NoumTests.swift`).

This continues the verified remaining-list in `docs/COACH_REPLACEMENT_SCORECARD.md` and builds ON TOP of initiatives #1/#8/#9/#10-13/#15 without disturbing them. The M26 vocal-energy edits already dirty in the tree were left alone.

---

## The proven contract (every piece below follows it)

Rich question-aware + whole-person context; explicit rubric + per-voice `CoachPersona` register; post-hoc grounding gate; **deterministic fallback** for offline / non-English / no-provider (never throw a raw error to the user); locale gate (`LocaleSettingsManager.shared.current.aiSupported`); numeric score untouched (read-only prompt context); single source of truth across surfaces; new fields bounded, decode-safe, defaulted for back-compat; pure logic unit-testable with a test per deterministic seam.

---

## Thread A — Offline chat fallback (AI-CHAT-FALLBACK)

**Problem.** `AICoachChatService` dead-ended offline: on `.network` / `.noProvider` / `.localeUnsupported` the user saw a system error notice. A real coach always responds.

**Change.** A deterministic, in-voice, grounded reply now lands on the unreachable/unsupported paths, mirroring `AICoachService.deterministicFeedback` + `PostRepCoachNoteService.deterministicNote`.

- `ChatOutcome` gained `case deterministicReply(String)` — distinct from `.reply` so the store can render it as a coach message while the spoken path stays silent.
- `AICoachChatService.deterministicReply(failure:context:)` (pure, `nonisolated`, total) + private helpers `bodySentence`, `verdictSentence`, `standingCaseLine`, `steadyFallback`, `bounded`, `lowerFirst`. It assembles: persona reflection-lead → one grounded body sentence (the **shared** `PracticeEvaluator.promptAnswerVerdict` above its floor, else a delivery fact, else a case-advancing line, else a steady in-voice fallback) → the standing case folded in association-only framing (suppressed when no durable case exists). Run through `collapseWhitespace` / `ensureNoExclamations` / `truncate` (reused from `PostRepCoachNoteService`), bounded to brand-voice length. Cause-agnostic copy (the user can't tell offline vs unconfigured vs locale-blocked).
- The transport-reached-but-refused path (non-2xx) and the catch (transport/encode failure) both return `.deterministicReply`. **`.empty` deliberately keeps its honest notice** — the model WAS reached, and a canned line could mask a real truncation bug.
- `AskNoumStore` renders `.reply` and `.deterministicReply` identically (a coach bubble, not a system notice). `AskNoumView` / `AskNoumSpokenMode.shouldSpeak` returns `false` for `.deterministicReply` so the fallback is never spoken aloud.

Non-English uses the same deterministic path by layer-wide precedent (locale-agnostic English copy).

Files: `Noum/AICoachChatService.swift`, `Noum/AskNoumStore.swift`, `Noum/AskNoumView.swift`, tests in `NoumTests/NoumTests.swift` (`AskNoumStoreTests`).

---

## Thread B — Deeper case-file context

### B1 — Grounded success-bar criterion (#5)

`PracticeEvaluator.criterionSummary(metric:threshold:window:priorAverage:priorRepCount:)` (PrimaryFocusMemory.swift) gained two trailing-defaulted params. Behind a `>= minPriorRepsForGroundedCriterion` (3) gate AND a real average, the success bar now quotes the user's own numbers — e.g. "your last 5 reps averaged 4.2% — hold at 4 or fewer per rep across 3 reps". Below the floor it falls back **byte-identical** to the prior generic copy. Internal caller `buildSuccessCriterion` passes `priorAverage` / `priorValues.count`.

### B1 — Upcoming BigMoment on the durable case (#2)

`CoachCaseFile` gained a stored `upcomingMomentLine: String?` and `CoachCaseFile.build(from:now:upcomingMomentLine:)` threads it through. The raw `BigMoment` is threaded INTO `CoachMemoryEngine.build(...)` as a new `upcomingMoment: BigMoment?` param (added before `now`/`calendar`), and the pure build computes the line via `CoachCaseFile.upcomingMomentLine(for:)` (horizon `upcomingMomentHorizonDays = 60`, using `BigMomentStore.daysUntil`). **The pure build never reads the store** — `SessionFinalizer` passes `upcomingMoment: BigMomentStore.shared.activeMoment` at the call site, mirroring the `lastTransferReview` wiring.

### B2 — Standing-case context in the Coach Read (SUBSTANCE-4)

`AICoachSessionInput` gained three trailing-defaulted fields after `baselinePaceWPM`: `standingHypothesis`, `standingObservableTarget`, `standingSuccessMeasure`. The user-prompt build reads them so the Coach Read rubric reasons over the user's STANDING goal/target, not just the last rep. `SummaryView` populates them from `coachMemoryStore.currentMemory?.workingHypothesis` / `caseFile?.observableTarget` / `caseFile?.successMeasure` — **single source of truth**: the target/measure reuse the already-summarized case file, never re-derived from `activeIntervention`. Cold start passes nils and the read is unchanged. Non-persisted struct, so no Codable concern.

Files: `Noum/PrimaryFocusMemory.swift`, `Noum/SessionFinalizer.swift`, `Noum/PracticeSupport.swift`, `Noum/SummaryView.swift`, tests in `NoumTests.swift` (`CoachMemoryEngineTests` + Coach Read tests).

---

## Thread C — More deliberate-practice exercises

### C1 — Two new framework drills (EXERCISE-7 + EXERCISE-5 remainder)

Mirror the shipped `starTurn` / `claimCounter` / `elevatorPitch` exactly — pure `frameworkCheck` detectors wired through every existing touch point. No new view, no new store, no router change.

- **Reframe the Curveball** (`structure.bridgeReframe`, `.structure`): `FrameworkDrillChecks.bridgeReframe(transcript:) -> BridgeReframeVerdict?`. Returns `nil` below the 6-content-word floor; `.reframed` when a fair-acknowledgement marker precedes a priority-bridge marker; `.facedDirectly` otherwise. Hostility was previously only DETECTED, never drilled.
- **AREA — Answer, Reason, Example, Answer** (`depth.areaAnswer`, `.answerDevelopment`): `areaAnswer(transcript:) -> AreaVerdict?` (`complete` / `missingLead` / `missingReason` / `missingExample` / `noClosingLoop`). Returns `nil` below the floor — never a confident negative on a thin rep.

Wired through: `DrillSystem` (`frameworkCheck` switch + new `FrameworkDrill` cases + `DrillCatalog` entries), `MiniDrillView` (result copy), `ReinforcementCopy`.

### C2 — Argument-logic + concision-of-meaning (ARGUMENT-LOGIC + CONCISION-OF-MEANING)

Two new pure read+verdict pairs on `PracticeEvaluator`, modeled on the `promptRelevance` / `promptAnswerVerdict` contract (read struct → verdict enum → nil-below-floor mapping):

- **Argument logic.** `argumentStructure(transcript:) -> ArgumentStructureRead`; `argumentLogicVerdict(for:) -> ArgumentLogicVerdict?`. A deterministic claim → evidence → implication signal (evidence and implication marker bands deliberately split). Nil below `minContentWordsForArgument` (6) OR when no claim was asserted. **Two consumers:** `PracticeEvaluator.timedModeInsights` (post-rep insight line) AND `CoachContextBuilder.argumentLogicLines` (an "ARGUMENT LOGIC (most-recent rep…)" block in the chat-coach context).
- **Concision of meaning.** `meaningDensity(transcript:relevance:) -> MeaningDensityRead`; `concisionOfMeaningVerdict(for:) -> ConcisionOfMeaningVerdict?`. A content-word-density + answer-arrival metric, distinct from raw word count and lexical diversity. `< meaningDensityLowFraction` (0.35) → `.padded`; `>= meaningDensityHighFraction` (0.50) with an early point arrival → positive. Nil below the token floor. **Consumer:** `PracticeEvaluator.timedModeInsights`.

Files: `Noum/FrameworkDrillChecks.swift`, `Noum/DrillSystem.swift`, `Noum/MiniDrillView.swift`, `ReinforcementCopy.swift`, `Noum/PracticeSupport.swift`, `Noum/CoachContextBuilder.swift`, tests in `NoumTests.swift`.

---

## Thread D — Adaptation everywhere + fused delivery read

### D1 — Adaptation tie-breaker across tiers (OBSERVE+ADAPT-2)

The reinforce/vary/replace verdict (`RecommendationAdaptationAnalyzer`, shipped) previously biased only Priority-6. It now influences other tiers as a **tie-breaker only**.

- New private `NextActionEngine.confidentReplace(forMode:input:)` wraps `RecommendationAdaptationAnalyzer.adaptationVerdict(mode:in:)` over `input.recommendationOutcomes`, returning true only on `action == .replace && confidence == .confident`. An empty / below-floor ledger always returns `false`.
- Applied at the pressure (P3) and stretch (P7) tiers: a confident `.replace` biases AWAY from the not-moving mode (flip to the other pressure mode, or switch modality to an IM conversation). Both pressure modes confidently-replaced → fall through so the cascade hands off a drill/stretch instead of re-prescribing a stalled mode. `.vary` is inert.
- **Never overrides a hard real-time signal** (P1/P2/P4/P5 win unchanged). `recommend(input:)` stays a total function and its signature is **unchanged** — `recommendationOutcomes` was already a defaulted field passed in, so the engine stays pure and no call site changes.

Files: `Noum/NextActionEngine.swift`, tests in `NoumTests.swift` (`NextActionEngineTests`, 8 new).

### D2 — Fused durable delivery read (#3)

The most interpretively dangerous slice — built conservatively.

- New `CoachDeliveryRead` (Codable, Equatable) in `DerivedReadsTrend.swift`: `dominantPattern` (`.forming` / `.clear` / `.timid`), `evidenceDepth`, `tentativeLine: String?`, `isCharacterized`.
- `DerivedReadsTrendEngine.fusedDeliveryRead(sessions:snapshots:hedgingPerMinutePerSession:paceBaselinePerSession:)` **combines existing per-rep reads** — Composure / ConfidenceMarker / Pitch / VocalEnergy / Structural — over the recent-rep window using the EXACT per-session derive path `compute` uses (so the fused read can never diverge from the per-rep reads). It is NOT a new analyzer.
- **Characterization only at >= 4 consistent votes.** Below that → `.forming` and the `tentativeLine` is **suppressed** (the coach says nothing rather than guess). Split votes → `.forming`. Every line reads the REP SET, never the person — a hypothesis, never a trait/diagnosis. Per-user baseline calibration (`BaselineEngine`-derived inputs) keeps soft/accented speakers from being mislabeled.
- Persisted on `CoachMemory.coachDeliveryRead` (added LAST on the memberwise init; `init(from:)` + `CodingKeys` updated; decoded with `decodeIfPresent` for back-compat). Build step: `memory.coachDeliveryRead = freshDeliveryRead.flatMap { $0.isCharacterized ? $0 : nil } ?? previous?.coachDeliveryRead` — a fresh characterized read wins, else the previous durable read carries forward across a thin window.
- Surfaced via `CoachContextBuilder` (one-line tentative read in the coach context).

Files: `Noum/DerivedReadsTrend.swift`, `Noum/PrimaryFocusMemory.swift`, `Noum/CoachContextBuilder.swift`, tests in `NoumTests.swift` (`FusedDeliveryRead` suite, between `DerivedReadsTrendEngineTests` and `RevisedReadCardTests`).

---

## Changed initializers (arg-order is the high-risk area — bit us 3x this session)

All new params are trailing + defaulted. Full new orders:

- **`AICoachSessionInput.init`** (PracticeSupport.swift:8209): `transcript, mode, score, fillerCount, duration, wordsPerMinute, speakingIdentity, prompt, voice, recentSessionSummaries, baselineFillerRate, baselinePaceWPM, standingHypothesis, standingObservableTarget, standingSuccessMeasure`. Call site: `SummaryView`.
- **`CoachMemory.init`** (PrimaryFocusMemory.swift:792): … `weeklyRepCount, isLatestSessionPersonalBest, coachDeliveryRead` (new, LAST).
- **`CoachCaseFile.build`** (PrimaryFocusMemory.swift:951): `from, now, upcomingMomentLine` (new, LAST).
- **`CoachMemoryEngine.build`** (PrimaryFocusMemory.swift:1114): … `latestTransferReport, upcomingMoment (new), now, calendar`. Call site: `SessionFinalizer` passes `BigMomentStore.shared.activeMoment`.
- **`PracticeEvaluator.criterionSummary`** (PrimaryFocusMemory.swift:1709, private): `metric, threshold, window, priorAverage (new), priorRepCount (new)`.
- **Unchanged (no arg-order risk):** `NextActionEngine.recommend(input:)`, `RecommendationAdaptationAnalyzer.adaptationVerdict(mode:in:)`.

## New accessibility identifiers

None. The two new drills route through the existing drill picker and reuse its identifiers; no new UI element introduced a new a11y id.

---

## Verification the human still owns

1. `xcodebuild build-for-testing -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build` — first, to catch any arg-order / symbol break (cross-file "cannot find type" editor noise aside).
2. `xcodebuild test-without-building … -only-testing:NoumTests` — the 84 new deterministic-seam tests.
3. UI + felt-quality on device/simulator: offline chat fallback voice and grounding; the grounded success-bar copy vs the byte-identical generic fallback; the two new drills end-to-end through the picker; the fused delivery read staying `.forming`/suppressed below 4 votes and reading as a hypothesis (never a diagnosis) at/above it.

Honest limits: no agent compiled, ran, or model-tested any of this. LLM-felt quality and rendered UI need the human's device.
