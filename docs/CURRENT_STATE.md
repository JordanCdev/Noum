# Noum — Current state

_Last updated: 2026-05-23 (M24 Track 1 — Coach Persona + Post-Rep Coach Note Service: the £130/hr coach turns toward the user and says "here's what I just saw" the moment a rep finalizes. New `Noum/CoachPersona.swift` — pure data model wrapping per-voice persona traits (registerName, signatureTone, openings: [String], closings: [String], reflectionLead). Six SpeakingStyleGoal voices + `default` nil fallback, each carrying a 3-line openings catalogue + 3-line closings catalogue + reflectionLead phrase. `opening(seed:)` / `closing(seed:)` use a stable seed so the same rep always renders the same line — text doesn't shuffle on re-paint. New `Noum/PostRepCoachNote.swift` value type (`id` + `sessionID` + `voice` + `noteText` + `isAIBacked` + `generatedAt`). New `Noum/PostRepCoachNoteStore.swift` per-account UserDefaults persistence keyed `postRepCoachNote.<accountID>` (mirrors AskNoumStore testable-init pattern with `defaults:` + `accountIDProvider:` so tests are hermetic without touching KeychainHelper). `record(_:)` de-dupes on sessionID so the deterministic → AI upgrade path REPLACES rather than stacks. 30-note capacity with oldest-by-generatedAt eviction. `latestNote()` feeds the Ask Noum context. Lifecycle hooks (`reloadForCurrentAccount` / `endSession` / `deleteAllData`) wired through AuthManager. New `Noum/PostRepCoachNoteService.swift` actor wrapping AI generation + `nonisolated static deterministicNote(input:)` fallback (exposed for tests). AI path: JSON-strict `{"note": "..."}` response, provider plumbing identical to AIInsightsService (OpenAI/DeepSeek/Gemini, AIConfig.plist keys, locale + API-key guards), brand-voice contract validation (`passesBrandVoiceContract`) rejects model output containing `!`, "Let's", "Awesome", "Great job", or overlong text and falls back. Deterministic path priority chain: (1) filler comparison vs baseline → win ("1 filler — well below your usual rate") at ratio ≤0.5× + count ≤2 or loss ("10 fillers — above your baseline. Slow the open next time") at ratio ≥1.5× + count ≥3; (2) zero fillers with ≥20 word floor → universal clean-run marker; (3) score band (≥8 → strong-score sentence; ≤4 → weak-score sentence that NEVER punish-shames per brand-voice contract); (4) pace outside 100-160 WPM when measurable (>170 → rushed; <95 → slow); (5) duration <20s → short-rep honesty without scolding; (6) fallback → neutral steady-delivery note. Voice carries through CoachPersona.persona(for:) so the same facts produce different phrasing for authoritative (verdict-shaped) vs warm (felt-experience-shaped) vs concise (clipped) coaching. Length cap: ≤200 chars across both paths. New `Noum/CoachReadCard.swift` SwiftUI hero card — brand-purple register (per M14 home-card design language: purple = "your coach speaking", mode-tint = "this is what to do"), NoumCharacter.Inline coaching glyph, voice-shaped header label ("COACH READ" / "FROM YOUR COACH" / "COACH NOTE" / "COACH BRIEFING" / "COACH BRIEF" per voice), optional "RULE-BASED" provenance tag (only when `isAIBacked == false`), note text in Typography.body. `PracticeSessionFinalizer.finalize` now ends with `recordPostRepCoachNote(for:)` — builds PostRepCoachNoteInput from finalized session + live stores (CoachingProfileStore.shared.profile + BaselineStore.shared.baseline + BigMomentStore.shared.activeMoment + daysUntil), calls `deterministicNote(input:)` synchronously and records it (Summary surface has a coach voice to render on the first paint cycle), then spawns a detached Task for the AI upgrade that re-records only when the upgrade is actually AI-backed. `CoachContextBuilder.userContext(...)` gains optional `latestRepNote: PostRepCoachNote? = nil` param; new LAST REP NOTE section renders between RECENT and PATH with explicit provenance labeling ("AI-generated" vs "rule-based (template)") so the model never claims "I noticed X" about a template line. `AskNoumView` observes PostRepCoachNoteStore.shared and threads `latestNote()` into the context call so the persistent chat coach builds on its own earlier read instead of starting fresh every turn. `SummaryView` renders CoachReadCard between HeroScoreCard and WhatYouDidWellCard, gated on `postRepCoachNoteStore.note(for: sessionStore.sessions.first?.id) != nil` (always present by the time SummaryView mounts because the finalizer writes synchronously). `AuthManager.deferStoreReloadForCurrentAccount` + `deferStoreSessionReset` extend to include `PostRepCoachNoteStore.shared`; `clearAllUserData(for:)` adds `postRepCoachNote.<accountID>`. 40+ new tests across 4 suites: `CoachPersonaTests` (6 tests: persona-for-nil returns default, every voice returns distinct registerName, every voice has non-empty openings/closings/reflectionLead, brand-voice contract no-exclamations across ALL persona lines × voices, seeded picks are stable, seeded picks don't crash on extreme seeds), `PostRepCoachNoteServiceDeterministicTests` (18 tests: honest-rule-based provenance, voice carries through, sessionID carries through, zero-fillers always celebrated as clean run, strong score cites the number, weak score NEVER punish-shames (no failure/bad/poor/terrible), rushed pace cites WPM, slow pace cites WPM, short rep stays honest, no-exclamations contract across 60 voice×score×filler combos, length-cap ≤200 across 20 voice×score combos, filler-loss branch fires at ≥1.5× baseline + count ≥3, filler-win branch fires at ≤0.5× baseline + count ≤2, brand-voice validator rejects exclamations/chirpy filler/overlong + accepts clean text, collapseWhitespace + ensureNoExclamations helpers), `PostRepCoachNoteStoreTests` (9 tests: record+fetch round trip, dedupes on sessionID, capacity evicts oldest by generatedAt, latestNote returns highest, clearAll empties, deleteAllData wipes by account, per-account key isolation, reload reads from disk, endSession clears in-memory without erasing disk), `CoachContextLastRepNoteTests` (4 tests: section omitted when nil, present when set, provenance surfaces correctly, sits before PATH/end-of-context). Closes M24 Track 1 from the previous session's deferred slate; Track 2 (Summary dedupe) and Track 3 (Sudden Death scoring view + SuddenDeathRunHistoryStore + friends scores) remain deferred. The artifact a user can now hold: a coaching note in their own coach's voice, tied to the rep they just finished, that the persistent chat coach builds on every time they come back. Previously: M24 partial — Sudden Death prompt audio replay fix (round-keyed cache) + skill level-up flash timing bump (single-event hold 0.35s → 1.80s for HIG-compliant read pace). Previously: M23 — Situational Preparation Mode lands as MVP (landing + per-step launchers under HomeCoachCard CTA when BigMoment.daysUntil ≤ 14). Previously: M22 — Monthly Coach Letter MVP (deterministic, auto-fire on month boundary). Previously: M21 — Session Intent: the £130/hr coach's "what are we working on today?" lands as a pre-rep sheet over Timed + Sudden Death. New `Noum/SessionIntentStore.swift` ((1) `SessionIntent` Codable struct: `id` + `priority: CoachingPriority` + `label` + `kind: SessionIntentOptionKind` (`.planWeek`/`.trendFocus`/`.voiceGoal`/`.generic`) + `declaredAt` + optional `sessionID` linked post-finalize; (2) `@MainActor` `SessionIntentStore` singleton with `@Published private(set) var pendingIntent: SessionIntent?` (transient — cleared every consume / endSession / view-disappear) + `@Published private(set) var history: [SessionIntent]` (bounded at `historyCap == 30`, per-account UserDefaults `sessionIntent.history.<accountID>`); (3) lifecycle `reloadForCurrentAccount()` / `endSession()` / `deleteAllData(for:)` mirroring BigMomentStore + ForwardPlanStore patterns; (4) API `setPending(_:)` / `clearPending()` / `consume(sessionID:) -> SessionIntent?` (links to session ID, writes to history, clears pending — returns nil when nothing pending, the common path)). New `CoachingPriority.aligned(with: SkillArea)` static bridge maps the 10 SkillArea cases into the 4-way CoachingPriority bucket (fillerReduction → reduceFillers, conciseSpeaking/structure/answerDevelopment → moreConcise, openingStrength/closingStrength → thinkFaster, paceControl/pauseUsage/vocalEmphasis/confidence → calmerDelivery) so trend focus + plan-week focus both flow into the intent space without leaking SkillArea into the UI. New `CoachingPriority.intentChipLabel` short first-person voice-shaped labels (≤24 chars, no exclamations, no leading "I ") for the chip row. New `SessionIntentMatcher.aligns(bulletID:with:)` pure-function bullet-to-priority matcher keyed on the existing `WhatYouDidWellCard` / `WhatToImproveCard` bullet ID conventions (`category-<Dimension>`, `filler`, `pace-fast`, `pace-slow`) so neither card needs structural changes beyond reading a bool. New `Noum/SessionIntentEngine.swift` pure-function `options(forwardPlan:trendFocus:profile:now:calendar:) -> [SessionIntent]` that produces 1–4 ordered options: plan-week first (most-earned signal — the coach wrote a program), trend focus second (data-driven), voice goal third (the user's long-term direction), generic "Open rep" always last. Dedup rule: same `CoachingPriority` only appears once; if plan-week and trend collapse to the same bucket, the trend-focus option is skipped. Reads `ForwardPlan.currentWeek(now:calendar:)` so the option set reflects week-2 focus after 8 days, not always week 1. New `Noum/SessionIntentPromptView.swift` sheet-style view with reduce-motion-safe single-tap commit chips, voice-shaped reason eyebrows ("From your plan" / "Your weakest area" / "Your stated goal" — generic chip carries no eyebrow), skip toolbar button + swipe-to-dismiss both drop cleanly (rep finalizes with `intentFocus: nil`), `presentationDetents: [.medium]`. `Noum/SpeechRecognizerViewModel.swift` `PracticeSession` gains `intentFocus: CoachingPriority?` + `intentLabel: String?` (`decodeIfPresent` so older persisted sessions decode with nil). `Noum/PracticeSupport.swift` `PracticeSessionDraft` mirrors the two new fields. `PracticeSessionFinalizer.finalize(...)` reads `SessionIntentStore.shared.pendingIntent` once on entry, injects into a mutated draft when the caller hasn't supplied one of its own, appends, then calls `SessionIntentStore.shared.consume(sessionID:)` to link + clear — single-source decision means every mode (Timed, Sudden Death, Ah-Counter, drill mini-runs) automatically picks up declared intent without touching call sites. `PracticeSessionStore.append(_:)` threads the two fields into the new PracticeSession. `Noum/CoachContextBuilder.swift` `userContext(...)` RECENT block now reads each session's `intentLabel` (whitespace-trimmed) and appends a compact " · Intent: <label>" tail to the per-session row — coach can say "you came in wanting to tighten structure — here's what I saw" without needing a separate section. Empty/whitespace-only labels silently omit the tail (defensive contract). `Noum/TimedPracticeView.swift` + `Noum/SuddenDeathPracticeView.swift` add `@StateObject forwardPlanStore` + `@StateObject sessionIntentStore` + `@State showIntentPrompt: Bool` + `@State intentPromptShownThisVisit: Bool` + `.sheet(isPresented:)` rendering `SessionIntentPromptView` with options computed live from `SessionIntentEngine.options(forwardPlan:..., trendFocus: TrendAnalyzer.primaryFocus(trends: TrendAnalyzer.analyze(snapshots: SkillTrendStore.shared.snapshots), currentSessionSnapshot: nil, recentDrills: DrillHistoryStore.shared.entries, styleGoal: profile?.speakingStyleGoal), profile:)`. Sheet auto-presents in `.task` exactly when `phase == .setup && !intentPromptShownThisVisit && pendingIntent == nil` (skipped on `PracticeModeQuickStart.consume(...)` Quick-Start path — the user already committed to launching). `.onDisappear` clears any leftover pending intent so the next mode entry starts clean. `Noum/WhatYouDidWellCard.swift` + `Noum/WhatToImproveCard.swift` gain optional `intentFocus: CoachingPriority?` param; bullet-row VStack restructured to put the headline + the optional `intentMatchChip` ("scope" SF Symbol + "YOU AIMED FOR THIS" small-caps Capsule) in a 6pt-spaced inner VStack — Wins card uses `AppColor.positive` tint (you delivered on what you aimed for), Improve card uses `AppColor.caution` tint (you flagged it, here's the verdict). Chip renders only when the bullet ID aligns with the declared priority via `SessionIntentMatcher.aligns(...)`. `Noum/SummaryView.swift` passes `sessionStore.sessions.first?.intentFocus` into both cards. `Noum/AuthManager.swift` registers `SessionIntentStore.shared` in `deferStoreReloadForCurrentAccount` + `deferStoreSessionReset` + adds `sessionIntent.history.<accountID>` to `clearAllUserData(for:)`. 25+ new tests across 6 suites: `CoachingPriorityAlignedWithSkillAreaTests` (filler→reduceFillers, concise→moreConcise×3, openings→thinkFaster×2, pace→calmerDelivery×4, every-SkillArea-maps-somewhere via allCases iteration, chip labels ≤24 char + no "!" + not "I " prefix), `SessionIntentEngineTests` (cold-start returns only generic, profile-only returns goal+generic, plan-week lands first, dedupe of plan+trend collapsing to same bucket, generic always last across 12 input combos, plan-week-uses-current-week-not-week-one with mixed 4-week plan + 8-day offset), `SessionIntentStoreTests` (SessionIntent JSON round-trip, reason labels are coach-voice for plan/trend/goal + nil for generic, historyCap == 30 contract, per-account key isolation), `SessionIntentMatcherTests` (filler→filler+Clarity, concise→Structure+Depth+Clarity, thinkFaster→Opening+pace-fast, calmerDelivery→pace-fast+pace-slow+Pace, momentum/leverage/ai-strength/ai-improvement never match any priority — keeps chip signal high), `CoachContextBuilderIntentTests` (intent tail appears with label, omitted with nil, defensive omit on whitespace-only label), `PracticeSessionIntentDecodingTests` (old persisted session decodes intent as nil, new session with intent round-trips). Closes M21 of the M19-M23 slate; M19 (Big Moment Intake) + M20 (Forward Plan) + M21 (Session Intent) now ship in sequence as `docs/M19_strategy.md` recommended — the persistent AI coach now reads the user's declared focus from every recent rep and the summary cards visually confirm "you aimed for this, here's what landed." Previously: M20 — Forward Plan: 4-week coach-written program lands end-to-end. New `Noum/ForwardPlanStore.swift` (per-account UserDefaults `forwardPlan.<accountID>`, MainActor singleton with `replace(_:)` / `clearPlan()` / `reloadForCurrentAccount()` / `endSession()` / `deleteAllData(for:)` mirroring the BigMomentStore lifecycle pattern); `ForwardPlan` struct (id + `weeks: [PlanWeek]` exactly 4 + `generatedAt` + `bigMomentID: UUID?` + `voiceAtGeneration: SpeakingStyleGoal?` + `isAIBacked: Bool`) carries the program; `PlanWeek` (weekIndex 1..4 + focus + focusSkillArea + suggestedMode + sessionTarget 2..5 + ≤200-char rationale) is the per-week unit. Pure-function `ForwardPlan.currentWeekIndex(now:calendar:)` projects the plan onto the calendar — week 1 on days 0..6, week 4 clamps past day 28 so the coach keeps coaching after the program ends; `ForwardPlan.isInvalidated(by:)` detects BigMomentID drift so a stale plan can warn rather than silently misrepresent. New `Noum/ForwardPlanService.swift` actor wraps the OpenAI/DeepSeek/Gemini provider plumbing (same shape as `AIInsightsService`) with JSON-strict response shape and a parallel `nonisolated static` deterministic fallback that builds the same 4-week shape from declining trends → weak-stable trends → baseline thresholds → voice goal alignment → BigMomentCategory mock mode → consolidation. Honest about provenance: `isAIBacked: false` on the rule-based path so the UI labels accordingly rather than presenting template copy as AI insight. Pure helpers (`weakestSkillArea(baseline:trends:)` / `strongestSkillArea(baseline:)` / `modeFor(skillArea:)` / `bestModeForVoice(_:)` / `mockModeFor(category:)` / `sessionTarget(weeklyReps:base:)`) all exposed for tests. New `Noum/ForwardPlanRenderer` produces multi-paragraph coach-voice text (opening with BigMoment reference when set + AI-vs-rule-based provenance line, one paragraph per week, voice-shaped closing line for all 6 voices + nil). New `Noum/ForwardPlanCoordinator` (MainActor enum) is the bridge: `buildInput()` assembles the snapshot from live stores (CoachingProfile + Baseline + sessions + rating + BigMoment + SkillTrendStore.snapshots + StreakFreezeManager.currentStreak + DrillHistoryStore.entries), `generateAndAnnounce()` calls the service + persists via `ForwardPlanStore.replace(_:)` + injects the rendered coach message via new `AskNoumStore.injectCoachTurn(_:)`. `CoachContextBuilder.userContext(...)` gains an optional `forwardPlan:` parameter; PLAN section renders current week's focus + mode + rationale + completed-vs-target progress, with explicit "stale" warning when BigMomentID drift is detected — coach is told to recommend regeneration rather than quote a misaligned plan. `AskNoumView.runReply` threads both BigMoment + ForwardPlan into the context call so every reply reads the current week. New `Noum/CoachingPlanCard.swift` — Profile-tab surface with pure `CoachingPlanCardVisibility.resolve(plan:profile:sessions:activeBigMomentID:now:calendar:)` four-state resolver (`.hidden` when no profile or no plan + <3 sessions, `.prompt` when ≥3 sessions but no plan, `.live(plan, completed)` when matching/both-nil BigMomentID, `.stale(plan, completed)` when BigMomentID drifted). The view renders three layouts: pre-prompt CTA card, live week+progress card, stale card with "regenerate" hint. Voice-shaped CTA copy mirrors the `askNoumProfileLabel(for:)` catalog so all entry points sound coherent. Card tap → opens noum://ask AND fires `ForwardPlanCoordinator.generateAndAnnounce()` on prompt/stale states. `Noum/AskNoumStore` gains `injectCoachTurn(_:) -> UUID?` (trims whitespace, returns nil on empty, appends as a non-pending `.coach` row without setting `isAwaitingReply` — direct injects don't lock the input bar). `Noum/AuthManager.deferStoreReloadForCurrentAccount` + `deferStoreSessionReset` extend to include `ForwardPlanStore.shared`; `clearAllUserData(for:)` adds `forwardPlan.<accountID>` + the M19 `bigMoment.<accountID>` + `bigMomentArchive.<accountID>` keys that were missing from the wipe list. 50+ new tests across 6 suites: `ForwardPlanCalendarTests` (11 tests: week 1 on day 0/6, week 2 on day 7, week 4 on day 21, week 4 clamp past day 42, currentWeek resolution, dateRange seven-day half-open, dateRange clamp on out-of-range index, isInvalidated mismatch / match / both-nil / cleared / added contracts), `ForwardPlanProgressTests` (5 tests: in-week sessions count, out-of-range exclude, week-2 boundary count, empty sessions zero, day-7 boundary fires into week 2), `ForwardPlanServiceDeterministicTests` (20 tests: 4-week count, isAIBacked false, voice carrying through, declining-high-confidence week 1, baseline filler week 1, voice-goal week 2, structure fallback week 2, sudden-death week 3, no-filler-stack week 3, BigMoment mock week 4 mapping for each category, consolidation week 4 when no BigMoment, sessionTarget clamping at floor/ceiling/steady, modeFor/bestModeForVoice/mockModeFor mappings, brand-voice exclamation contract across all variants, weakestSkillArea priority / strongest nil-when-insufficient / strongest-finds-low-filler), `ForwardPlanRendererTests` (6 tests: opening references BigMoment, generic without, rule-based honesty, AI-backed honesty, includes all 4 weeks, voice-shaped closing + no exclamations across all 6 voices × BigMoment-or-not), `ForwardPlanContextTests` (4 tests: PLAN omitted when nil, PLAN present when set, progress count matches sessions filter, stale warning surfaces when BigMomentID differs), `CoachingPlanCardVisibilityTests` (9 tests: hidden-when-no-profile, hidden-when-<3-sessions, prompt-at-3, live-on-match, live-on-both-nil, stale-on-drift, stale-on-cleared-moment, live carries completed count, voice-shaped CTA labels for every voice + live-state-empty contract), `AskNoumStoreInjectCoachTurnTests` (5 tests: nil on empty / whitespace-only, append as non-pending coach row, doesn't set isAwaitingReply, trims). Closes M20 of the M19-M23 slate; M19 (Big Moment Intake) and M20 (Forward Plan) now ship in parallel as `docs/M19_strategy.md` recommended. Previously: M18 + M19 strategy push — Sudden Death rework + SpeechRecognizer crash guard + 3-track personalization research synthesized into M19-M23 roadmap: M18 ships Sudden Death as the filler-eradication game its name promises — `PressureRoundConfig.config(for:difficulty:)` now hard-codes `fillerTolerance: 0` across all 8 rounds × 3 difficulties (one filler = instant elimination); `SuddenDeathDifficulty.fillerToleranceShift` removed since it no longer varies; difficulty subtitles updated to reflect new meaning ("Wider start window. More time per round." / "Tight start window. Less time per round."); `RoundOutcome.fillerOverload.label` "Filler Spike" → "Filler — instant elimination"; new `PressureTimerEngine.pendingUserWaitingRound: Int?` published property + `confirmBeginUserWaiting()` method gates the `.npcTurn → .userTurnWaiting` phase transition on TTS `didFinish` so the prompt card stays expanded through the full readout; new live `N/10 words` counter chip during `.userTurnActive` with calm secondary→accent→primary color progression + light haptic (`UIImpactFeedbackGenerator.light`) firing once per round on the exact frame `wordCount` crosses `minimumWords`; new `Noum/SuddenDeathHighScoreStore.swift` (per-account UserDefaults `suddenDeath.bestRounds.<difficulty>.<accountID>`, same pattern as RatingStore, `recordRun(roundsSurvived:difficulty:) -> Bool` returns isNewBest); new `Noum/SuddenDeathResultView.swift` (318 LOC, extracted from inline `resultScreen` lines 905-1029 of SuddenDeathPracticeView) replaces "Rushed Start" mode-name header with contextual run-summary header — "New Best · N rounds" / "Clean Run · N rounds" / "Eliminated · Round N", mode/difficulty demoted to subtitle; number-roll-up animation 0→final over 0.6s ease-out, reduce-motion users see final value immediately; NEW HIGH! badge with SparkleRibbon when `recordRun` returns true; real `UIActivityViewController` share button via `UIViewControllerRepresentable` wrapper (plain-text snippet, no fake-social fabrication — anti-goal compliant); XP chip bumped from 12pt caption to `.title3.weight(.bold)` so it reads as a reward not a footnote; 17 new tests across SuddenDeathMechanicTests (11) + SuddenDeathHighScoreStoreTests (6). M19 fix pass closes two M18 smoke-surfaced bugs: (1) `SpeechRecognizerViewModel.startAudioStream` `installTap` was throwing NSException → SIGABRT when `inputNode.inputFormat(forBus: 0)` returned a 0-channel format on the simulator after `.playback` (TTS) → `.playAndRecord` transition; defensive guard now checks `inputFormat.channelCount > 0 && sampleRate > 0` and throws typed `AudioStreamError.invalidInputFormat` instead of crashing; `.allowBluetooth` added to session options for valid sim input format; (2) cloud TTS path (`IMMessageSpeaker.speakPrompt`) was returning `true` the instant the network fetch completed not when audio actually finished, so the prompt card was collapsing mid-readout — now estimates readout duration from word count (0.55s/word × 0.85 rate + 0.5s overhead, floor 1.5s), `Task.sleep`s that duration, then clears `isSpeakingPrompt` + calls `confirmBeginUserWaiting()`; npcCard collapsed `lineLimit` bumped 2 → 3 as gating-failure safety net. M19 strategy phase: 4-agent parallel research team produced three independent deliverables — `docs/M19_audit_personalization.md` (every Noum intake field + per-session metric + derived insight mapped to USED/PARTIAL/DORMANT verdicts with file:line citations; finding: 11 intake fields, 3 USED, 4 PARTIAL, 4 DORMANT including `successVision` which evaporates after one-time AI paraphrase; `TrendAnalyzer` direction outputs never reach `CoachContextBuilder.userContext` so the persistent AI coach cannot cite "your filler rate has been declining for 3 weeks"), `docs/M19_audit_coach_workflow.md` (£130/hr human-coach workflow mapped across 7 engagement phases — intake/diagnostic/individualized plan/drill prescription/check-in/adapt/capstone — with per-phase verdict on Noum coverage; honest finding: Phase 4 drill prescription is genuinely strong via `TrendAnalyzer.primaryFocus` + `RecommendationBiasEngine` + mode differentiation, extend not rebuild; top 3 highest-leverage closures: no Big Moment capture / plan is invisible / adaptation is silent), `docs/M19_proposed_milestones.md` (5 concrete M19-M23 milestones with per-milestone architecture sketch + success criteria + anti-goal compliance check + estimated parallel track count). All three tracks reasoned independently and converged on Big Moment capture as the foundational gap. `docs/M19_strategy.md` synthesizes all three into a single decision-grade roadmap. Previously: M17 polish push — eloquence promotion + single-event timing + live transcript preview + chip parser tests: continues the M17 polish arc by closing four of the six items the previous two handoffs flagged as concrete + deferred, leaving the two that need real device access. (1) `WhatYouDidWellCard.computeBullets(...)` now promotes the first eloquence finding **above** the second good category — a detected rhetorical move is concrete on-tape evidence; a second "felt solid" is the same impression as the first, so concrete beats restated under the 3-cap. Refactor extracts a `private static func bullet(forGoodCategory:)` helper so the two category-bullet construction sites stay byte-identical. Two test updates: `eloquenceFindingDropsWhenMomentumPlusTwoCategoriesAlreadyFill` renamed to `eloquencePromotedAboveSecondGoodCategory` with the assertion flipped; new `secondGoodCategoryStillLandsWhenNoEloquence` locks the no-eloquence path so the common-case visual doesn't regress. (2) `PreSummaryCelebration.present(index:)` tightens single-event full-motion timing to ~0.65s total (vs ~1.1s multi-event): in-spring response 0.42s, hold 0.35s, bars delay 0.12s, bars spring 0.40s — multi-event keeps the original parade-of-moments timing, reduce-motion path unchanged (was already ≤0.7s). (3) `AskNoumView.inputBar` lifted from a single HStack into a VStack of (`partialTranscriptPreview` + `inputBarRow`). New `partialTranscriptPreview` `@ViewBuilder` renders only while `voiceInput.state == .recording`: shows "Listening…" at 0.55-opacity italic brand-blue when the recognizer hasn't landed a word yet; shows the live `partialTranscript` at 0.85-opacity once words arrive. Waveform icon with `.symbolEffect(.variableColor.iterative)` (reduce-motion suppressed); VoiceOver label flips with content. Transition is `.opacity` + `.move(edge: .bottom)`; `.animation` modifiers debounce both state and text changes, both nil under reduce-motion. The `AskNoumVoiceInput` wrapper was already publishing `partialTranscript` per M17 — the view just hadn't consumed it. (4) New `CoachContextBuilderChipParserTests` suite (18 tests) covering `parseAndFilterChips`: happy path (3 tests: plain newline-separated, nil-on-shortfall, extra-truncated-to-count), cleanup (4 tests: bullet/dash markers, numeric enumeration, straight + smart quotes, blank lines + whitespace), brand-voice contract (8 tests: exclamation drops, `let's`/`Lets` drop, 7 leading directives parametrized, emoji pictograph drops, min-4-char drops, max-60-char drops, exact-min-and-max-pass, unicode-below-emoji-threshold-passes), and integration (2 tests: layered mess recovery, count not exceeded). The function is `internal` on the `CoachContextBuilder` enum so `@testable import Noum` reaches it; `passesChipFilter` is `private` but every gate it enforces is locked through the parser-level interface. — Previously: M17 redesign integration verification + bullet selector test contract: the M17 summary redesign (PreSummaryCelebration + WhatYouDidWell / WhatToImprove hero cards + TalkToNoum CTA) landed unverified in commit `77c3524`. This push locks the design contract by refactoring the bullet-selection logic out of the View body into pure `static func computeBullets(...)` accessors on `WhatYouDidWellCard` and `WhatToImproveCard` — the custom-filler-words dep flows in as a parameter so tests don't have to mutate `ClutchWordStore.shared`. New `TalkToNoumCTACard.headlineCopy(isPremium:)` / `subCopy` / `ctaCopy` / `accessibilityLabel` static accessors expose the copy contract. 25 new tests across three suites — `WhatYouDidWellBulletSelectorTests` (11 tests: minimal-effort silence, momentum-only / empty-momentum, good-categories cap at 2, .ok rating excluded, eloquence drop-when-saturated / land-with-headroom, eloquence snippet→.quote evidence, AI strength headroom gating, AI empty-string defensive, hard 3-cap, category note→text evidence), `WhatToImproveBulletSelectorTests` (13 tests: minimal-effort silence, clean-rep silence, leverage+nextStep evidence binding, filler ≥2 threshold, filler cluster framing ≥5, leverage-by-name dedup against category, category cap at 2, pace-fast ≥170 WPM, pace-slow ≤95 WPM, pace headroom suppression, pace min-words/duration gates, AI keyImprovement tail + headroom suppression, hard 3-cap), `TalkToNoumCTACardCopyTests` (5 tests: headline invariance, sub-copy divergence, CTA copy by state, brand-voice contract (no "!", no "Let's", no chirpy filler — applied across every emitted string), accessibility lock-signal only-for-free). Closes the verification gap left by the partial M17 commit; the design contract is now compiler-enforced. — Previously: Growth Library — quote → source session navigation + seeded CoachingProfile: each `GrowthLibraryView` quote card is now a `NavigationLink(value: AppDestination.sessionDetail(sessionID:))` so the user can tap a banked moment → land on the full `SessionHistoryDetailView` that produced it (same chrome the History tab uses; full transcript, AI coach read, IM conversation card, metric breakdown). `ContentView`'s destination switch resolves the session against the live `PracticeSessionStore` with a graceful `SessionHistoryView` fallback if the source session was deleted since the artifact was banked. `SessionHistoryDetailView` lifted from `private struct` → `struct` so the destination switch can render it without duplication. New `AppDestination.sessionDetail(sessionID: UUID)` case + four `AppDestinationSessionDetailTests` lock the Hashable / Equatable / distinctness contract. The Growth Library moves from read-only evidence-display ("here's a thing you said") to a learning loop ("here's a thing you said — go re-read the full session"). Closes the explicit "future move" left in the previous push's HANDOFF. ALSO: `DevSeedData.injectProfile(_:)` now seeds `CoachingProfileStore` alongside sessions / baseline / rating / XP via a new internal helper `seedCoachingProfile(for:)` (each `SeedProfile` carries a narrative-coherent voice + priority + challenge + brief + motivation + success vision — improvingIntermediate → warm + moreConcise, plateauedAdvanced → authoritative + presentations, pressureVulnerable → executive + calmerDelivery, fillerFree → concise + persuasive, beginner → warm + reduceFillers + rebuilding). New DEBUG-only `CoachingProfileStore.replaceForDebug(_:)` mirrors the pattern of `PracticeSessionStore.replaceAllForDebug` / `RatingStore.replaceForDebug` and skips production side effects (backend sync, AI paraphrase). Closes the M16 explicit TODO that sat in `NoumUITests.swift:23`: `testHomeScreenAndPrimaryNavigation` reverts from the `noum://path` deep-link fallback back to the tap-the-card pattern on `home.path` (with deep-link fallback retained for slow-simulator flakes). HomeSignalGate's `coachingProfileSet` branch now lights up for every seed profile, so every M14 goal-aware surface — VoiceAnchorBanner, LiveEloquenceHUD, VoiceAlignmentChip, goal-progress ring — has something to read on a seeded simulator. Seven `DevSeedCoachingProfileTests` lock the per-seed voice mapping + completeness contract + ≥4 distinct voices across the 5 seeds for visual breadth in the screenshot tour. // Previous Growth Library push: the chip on `ProfileView` is now a `NavigationLink(value: AppDestination.growthLibrary)` that opens `GrowthLibraryView` — quote cards (italic verbatim slice + technique chip + claim + relative date + AI/Live badge) grouped into "This week" / "Last week" / "Week of MMM d" buckets via a new pure `ProofMomentStore.weeklyGroups(from:now:calendar:)` static helper; new `noum://growth` deep link for symmetry with `noum://ask`; honest empty state when archive is cold; six `GrowthLibraryWeeklyGroupingTests` lock the grouping contract — empty input → no buckets, same-week collapse, newest-week-first, This/Last-week labels, older buckets use explicit week-of-date, cross-year buckets carry the year so January 2025 vs January 2026 can never blur. Continues the M15 "a coach who's actually present" arc: the evidence the coach references in chat is now also browseable on the profile, so the user can see their own progress in their own words.) M5–M13 shipped, M14 in flight: goal-aware coaching surfaces + LookingAheadCard + mid-session voice anchor + goal-aware live HUD + Typography Dynamic Type contract + goal-aware coach note momentum + visible goal-progress ring on the profile + home recommendation voice-alignment chip + calmer-delivery snapshot trend + Looking-Ahead voice chip closes the loop + goal-aware drill picker closes the inside of the loop + goal-aware leverage + next step + drill rationale closes the verdict copy edge + goal-aware delivery bonus closes the scoring edge — score, copy, and drill are all goal-aware end-to-end + **Home Coach Card hero redesign** + **6-surface premium hero pattern** (Profile/Review/Settings/Mode Picker/Path Journey/Bottom Nav) + **noum-screenshots skill + SessionEnd hook + 27-shot detailed tour** + **tab-level `noum://` deep links** + **UI_TESTING_SEED_FORCE + celebration suppression** + **VoiceAlignmentChip on hero** + **NoumCharacterStage 5-stage story arc** + **Path-centric Home (second hero with Chapter/Mission framing)** + **VoiceMetricsCard (Pause + Word Choice first-class)** + **PathNodeCelebration cinematic upgrade** + **Mission framing copy** + **SummaryView "Mission cleared" headline on path unlock** + **AIWeeklyInsightCard chapter eyebrow mirrors path chapter** + **HomeCoachCard now serves the empty state too — unified premium first impression** + **Ah-Counter hero parity with other modes** + **Coach voice audit — 7 user-facing exclamations dropped** + **NoumCharacterStage test coverage** + **Ask Noum — persistent AI coach chat with voice-specific personality + full user context** + **Proof Moments — transcript-anchored evidence of growth on Weekly Insight + Path Celebration + Personal Best** + **Summary → Ask Noum bridge — session-anchored, voice-shaped opener seeds the chat so users can ask their coach about THIS rep with one tap** + **Goal-aware live UI extended to every practice mode — VoiceAnchorBanner + LiveEloquenceHUD now ship in SuddenDeath, AhCounter, and IM, not just Timed; banner gains `resetsBetweenReps: false` so multi-round / multi-turn surfaces fire it once per session, not once per turn** + **Ask Noum third entry point — Profile Coaching Direction card now carries a restrained voice-shaped "Ask Noum about your goal →" link; persistent-coach footprint now reaches Home (ambient) + Summary (rep-anchored) + Profile (goal-anchored), all three through the same `noum://ask` deep link** + **`firebase.json` carries the `firestore.rules` pointer — `firebase deploy --only firestore:rules,hosting` is now the literal command for the M14 milestone deploy, no config edit step in between** + **Ask Noum follow-up chips — three voice-shaped, topic-anchored nudges land beneath the most-recent coach reply, turning the chat from respond-and-wait into a live, alive conversation; first match wins on drill / pause / pace / filler / weekly anchors with a generic fallback so every reply yields chips, restraint contract collapses the row on pending / system-notice / empty-reply states, every voice × topic cell carries three brand-voice-compliant chips locked by tests** + **Proof Moment archive — every generated proof persists per-account in `ProofMomentStore` (max 12 records, idempotent on session ID, dropped-by-addedAt cap, most-recent-by-session-date sort); the Ask Noum coach reads the freshest three via a new optional `recentProofs:` param on `CoachContextBuilder.userContext` and surfaces a `PROOFS` section with verbatim quotes the model can quote back at the user ("Three weeks ago you said 'we focused on three priorities' — that's the move you've been refining"); no proofs = no section (cold-start users never see a fabricated quote); fifteen unit tests lock persistence round-trip, per-account isolation, idempotency, cap-by-addedAt eviction, most-recent-first ordering, hard-3-cap in context, GOAL-precedes-PROOFS section order** + **M15 Phase 3 — Mode literacy tap-to-expand: each `PracticeModeOptionRow` gets a "What this trains" affordance with 3 lines of coach-voice copy (Pressure type / What it surfaces / Typical rep length) wrapped in a 28pt `NoumCharacter.Inline` `.coaching` glyph. Set-based multi-row-open semantics, separate row-select Button vs 44×44 expand-overlay Button, reduce-motion gated via `animateMode(_:)`, existing `practiceMode.<id>` accessibility IDs preserved (tour regression gate) plus new `practiceMode.<id>.expandButton` IDs added. Four `PracticeModeRowExpansionTests` lock the contract (complete triple per mode / no chirpy filler / rep-length mentions a unit / lines stay terse)** + **M15 Phase 4 — Home discipline (signal-gated home cards): new `Noum/HomeSignalGate.swift` (pure function over sessionStore + pathProgress + coachingProfileStore + AppStorage override) → `HomeCardGate` struct of per-card `Bool` flags. Cold start shows only Coach + UtilityStrip + AskNoum (3 cards); Daily Challenge + VoiceMetrics unlock at session 1; AI Weekly Insight at 3 sessions per ISO week; Journey at goal-set state OR unlocked path node. Settings "Show every home card" toggle (`practice.showAllHomeCards` AppStorage) is the full-reversibility escape hatch. Seven `HomeSignalGateTests` pin every branch including the ISO-week boundary and the `allVisible` override contract**)_

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
- **Screenshot + handoff workflow:** `noum-screenshots` skill at
  `.claude/skills/noum-screenshots/` with three modes (off/light/
  detailed) stored in a `.mode` file. Light = 5 tab tops via
  `-DeepLink` (~30s); detailed = 27-shot tour via
  `xcodebuild test -only-testing:NoumUITests/ScreenshotTour/...` (~3min).
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
- `Noum/Noum/PathJourneyView.swift` — map surface that combines the new
  node grid with retained decorative artwork.
- `Noum/Noum/StreakFreezeManager.swift` — weekly-replenishing streak
  freeze; protects the streak across one missed day per ISO week.
  Wires the app icon badge through `UNUserNotificationCenter.setBadgeCount`
  (passively gated on authorization, never triggers a prompt).
- `Noum/Noum/NoumCharacter.swift` — abstract speaker-character composed
  from SF Symbols (waveform variants + halos + glow), four moods (calm /
  listening / excited / coaching), state-specific accents (sparkle ribbon
  on excited, symmetric arc-pulses on listening, slight tilt on coaching).
  Used on the home hero, FirstRepCelebration, ProfileView header, and
  AchievementsTreeView hero strip. Brand-rule compliant: motion + color
  + shape, no illustration.
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
    rewrote the journey-card assertion from tap-the-card to deep-link
    via `noum://path`, mirroring `ScreenshotTour.launchSeededAt`. Test
    now passes on a freshly-erased simulator. TODO left in-file: extend
    `DevSeedData.injectProfile(.improvingIntermediate)` to populate
    `CoachingProfileStore` so future gated-card tests can use tap-the-
    card patterns again. Commit `bad4824`.
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
  `GoalRefreshManager` fires a lightweight "still your goal?" sheet every
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
  Deploy itself still pending explicit greenlight (operational,
  not engineering).
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
  + active challenge, `SummaryView` transcript card, `FirstRepCelebration`
  CTAs, `WordChoiceCard`, `PauseSummaryCard`, `PersonalBestHeroCard`)
  migrated off ad-hoc `.system(size:)` onto the catalog or
  `Typography.figtreeNumeric(...)`. Remaining `.system(size:)` call
  sites are intentional: bitmap share card rendered via `ImageRenderer`
  at a fixed 360pt frame (`SummaryView` lines 1860–2033), achievement
  grid badges inside fixed 48pt cells (`ProfileView` 710, 720), and a
  few decorative SF Symbol particles. A unit test
  (`typographyRolesResolveToFonts`) locks the catalog contract so a
  future refactor that drops `relativeTo:` fails the test suite.
- **Hosted privacy policy URL** — bundled `PrivacyPolicy.md` renders
  in-app via `PrivacyPolicyView`. App Store submission also requires
  a hosted public URL (Firebase Hosting or similar). Open.

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
  except on celebration overlays. Sentence case for body, Title
  Case + uppercase + 0.8 tracking for micro-labels.
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
