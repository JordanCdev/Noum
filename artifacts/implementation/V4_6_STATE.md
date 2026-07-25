# V4.6 Implementation State

**Branch:** `claude/v4-6-swiftui-implementation` (isolated worktree `/Users/jordan/src/GitHub/Noum-v46-impl`, base `ux-overhaul` @ `97028234a`)
**Updated:** 2026-07-25 (Slice 2 in flight)

## Completed frames

| Frame | Node | Status | Evidence |
|---|---|---|---|
| Review / Explore / Retry / Comparison | 258:1006/1309/1032/1045 | DONE in base commit 97028234a (previous session) | Fresh worktree build + 20/20 targeted tests (ProductJourneyContractTests, AccessibilityContrastTests) via xcresult on iPhone 17 Pro iOS 26.5 |
| Today | 258:934 | Implemented + verified on sim | `.screenshots/v46-slice2/01-today.png` vs Today-final.png |
| Recording — live | 258:981 | Implemented + verified end-to-end on sim (scripted provider; prompt dominant, chip, clock, level-reactive trace, cue, pill; honest retryable-error terminal also exercised via real 401) | `.screenshots/v46-slice2/02-recording-live.png` |
| Recording — silence | 258:1195 | Implemented + verified (dimmed trace + reassurance cue at ~2.5 s quiet) | `03-recording-silence.png` |
| Recording — final seconds | 258:1252 | Implemented + verified (amber clock 0:07 + "Land the close"; cue outranks silence) | `04-recording-final-seconds.png` |
| Processing | 258:994 | Implemented + verified (`.processing` phase wraps the existing finalize pipeline; READING YOUR REP chip, settling trace, cue, quiet Cancel; 1.4 s frozen beat; low-evidence/retryable/cancelled terminals + FlowLog stages; auto-stop at 0:00 routes through the same path) | `05-processing.png` (mid-dissolve), `06-review-after-rep.png` (loop closes into Review) |

## Key changes so far (Slice 2)

- `DesignSystem.swift` — V4.6 tokens (coachingInk #4C2BB8, coachAccent #7C3AED, heroGradientStart/End, warmCanvas, immersiveTop/Bottom), Spacing.xl/xxl/xxxl, CornerRadius.pill/hero, `ImmersiveCTA` (white pill: pressed 84%, disabled, 3-dot loading, RM-safe), V4.6 motion tokens (v46Settle/v46Quick/v46Dissolve/v46ReduceMotionFade).
- `Noum/VoiceTrace.swift` (NEW) — the single voice motif: idleHero/earnedHero/live/settling variants from frozen geometry + `VoiceTraceDayCluster` for Progress. Live variant is level-reactive (5% quantised, RM = static bars); all traces `accessibilityHidden`.
- `Noum/HomeCoachCard.swift` — V4.6 Today hero (eyebrow → headline → reason → real meta clauses → idle trace → one dominant Start; prep precedence retained as contextual slot). Start now arms `PracticeModeQuickStart` so the hero IS the briefing (no setup interstitial). All existing ids/pipelines preserved.
- `Noum/ContentView.swift` — warm canvas + bottom violet wash, top-bleed hero scroll, left-aligned "Adjust practice ›" + confirmationDialog (real per-rep answer clocks + manual catalogue; never rewrites saved settings).
- `Noum/TimedPracticeView.swift` — V4.6 recording surface (static dark stage, REC chip w/ folded drill/pressure context, remaining clock incl. amber final-seconds, dominant quoted prompt, level-reactive VoiceTrace, single cue w/ precedence finalSeconds→silence→retry→drill→sublabel, ImmersiveCTA "I'm done"); `.processing` phase (honest terminals; 1s max dwell before Review); banners suppressed on immersive stage only.
- `Noum/RewriteSuggestionCard.swift` — editorial CTA fill aligned to contract coachingInk (#4C2BB8, was `pro`).
- `Noum/SpeechRecognizerViewModel.swift` — `UITestScriptedTranscriptionProvider` (DEBUG-only, `UI_TESTING_TRANSCRIPTION_SCRIPTED`): deterministic full-loop capture without live STT.
- `NoumTests/V46CoachingLoopSurfaceTests.swift` (NEW) — trace geometry + scripted-seam gate contracts.

## Slice 3 (Updated Today 258:1078 + Progress 258:1131)

- `Noum/V46ProgressPresentation.swift` — pure resolvers: `V46ProgressPresentation.make` (comparable-ledger-only Progress head: bounded headline classes Becoming reliable./Not yet steady./Early read., honest tally subtitle, ≤4 trajectory days with amber lapse, ≤3 evidence rows, real review row from `CoachIntervention.reviewDueAt`), `V46EarnedTodayPresentation.make` (once-per-event Updated Today; "shorter clock" only when the clock genuinely tightened), `V46EarnedEvidenceLedger` (per-account ack + receipt-dismiss keys, registered in AccountDataRegistry as "v46-earned-evidence").
- `HomeCoachCard` — earned chip (mini trace + "New evidence · from your retry"), headline/meta/CTA overrides, earnedHero trace, body line suppressed in the earned state, acknowledged on first render.
- `ContentView` — collapsed compact receipt on later visits (10-min floor prevents co-presentation), dismissible once, positive tint.
- `SessionHistoryView` — `v46ProgressHead` replaces the story card whenever comparable evidence exists (legacy story remains the no-evidence fallback); plan-review row routes to the existing weekly check-in.
- `DevSeedData.seedV46ComparableEvidenceIfRequested` (`UI_TESTING_V46_EVIDENCE`) — 4 comparable outcomes (3 holds incl. under-pressure today, 1 pressure lapse) through the store's own persistence.
- Verified on sim: Updated Today hero (chip/headline/meta/earned trace — `.screenshots/v46-slice3/01-updated-today.png`) and Progress head with the exact frozen subtitle derived from real ledger data (`02-progress-head.png`). Deviation: with an active BigMoment ≤14 days, prep keeps the CTA slot (contextual-moment precedence) — the earned CTA override applies only to the ordinary branch.

## Slice 4 (dark theme, capsule nav, AX/RM/offline proofs)

- **Dark mode shipped**: `AppColor` semantic tokens are now trait-resolving per the frozen contract (screen #FAF9F7→#17151C, cards → warm dark surfaces, ink/accent → #9061F9, receded → #8A93A4, pressed → #7A4FF0, quiet violet → #2B2440, feedback colours explicitly mapped — never grey-bucketed); the root `.preferredColorScheme(.light)` pin is removed. Immersive recording/processing stay natively dark.
- **Capsule nav completed**: bar hides on pushed destinations (tab roots only), caps its own Dynamic Type like native chrome, uses dynamic card/border tokens in dark. Settings entry added to the You root (`profile.openSettings` gear → existing `AppDestination.settings`); `noum://settings` still routes. UI tests re-pointed (NoumUITests ×2, FastLaneFirstSessionUITests ×1).
- **Tour extended**: `testCaptureV46RetryComparisonLoop` completes retry → scripted recording → processing → same-target comparison card (closes the last visual-coverage gap).
- **Proof captures** in `.screenshots/v46-slice4/`: dark-01-updated-today, dark-02-review, dark-03-progress, ax3-today, ax5-review (34pt quote wraps, nothing truncated), rm-recording (static bars at drawn state, no ambient motion), offline-provider-failure (honest retryable card).
- Home scroll clearance raised to the tab-root constant so cards never sit under the floating capsule.

## Known deviations / notes

- Status bar renders dark over the violet hero (app pins `.preferredColorScheme(.light)`); resolved with the Slice 4 theme work.
- Hero clock preference: the V4.6 recording surface always shows the clock (silence/final-seconds depend on it); legacy timer-display preference still governs transcript/camera layouts.
- Recording clock is the session clock (e.g. 2:30 standard policy); the difficulty's 60/30/15s "answer clock" remains the scoring target range — mock's "0:12 left" is a session near its end.
- SpotlightOrbView + milestone scale animation are no longer used by the immersive layout (kept for camera/transcript paths pending Slice 4 cleanup decision).

## Blockers (real)

- **Live STT unavailable in this environment**: Deepgram key in local gitignored plists returns 401 (revoked in the 2026-07-18 leak closure — chip filed for Jordan); simulator SFSpeechRecognizer interrupts mid-session. Full-loop verification proceeds via the scripted DEBUG provider; real-device/live-provider verification remains for Jordan.

## Current commit

- Base: 97028234a (Slice 1). Slice 2 not yet committed.

## Exact next task

Scripted-provider full-loop run on sim: capture recording live/silence/final-seconds, processing, review, comparison → fix visual deltas (≤3 iterations) → targeted tests → commit Slice 2.

## V4.6.1/V4.6.2 motion & haptics (2026-07-25, on ux-overhaul)

- Semantic motion vocabulary + gated haptic register are LIVE (see
  `artifacts/motion/MOTION_SPEC.md` — the canonical temporal contract,
  mirrored in Figma page 18 `280:497`). All raw UIFeedbackGenerator
  call sites migrated; `withMotion` is the blessed RM guard.
- Signature moments implemented: Today hero entrance + armed trace
  (real CTA press state via `ImmersiveCTA(isPressed:)`), earned
  announcement on `payoffReveal` + `earnedEvidence` two-beat haptic,
  comparison payoff settle-frame, Progress grow-in, Train morph/dim,
  Rehearsal focus/count, Ask Noum presence states + banner arc,
  tab-bar pill glide (bar-scoped `matchedGeometryEffect`) + selection
  haptic.
- Proof: `.screenshots/2026-07-25_v461-motion/` (incl. md5-identical
  RM pair). Device haptic proof STILL OWED — simulator cannot render
  haptics; run the register on a physical iPhone before TestFlight.
- Pre-existing red (chip filed, reproduces at clean HEAD):
  RecommendationSurfaceRouting theme-leak ×2, GoalOutcomeLoop ladder
  rung.
