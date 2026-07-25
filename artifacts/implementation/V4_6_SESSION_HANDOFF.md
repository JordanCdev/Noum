# V4.6 Implementation — Session Handoff (2026-07-25)

**Worktree:** `/Users/jordan/src/GitHub/Noum-v46-impl` · branch `claude/v4-6-swiftui-implementation` (base `ux-overhaul` @ 97028234a). NOT pushed, NOT merged.
**Primary worktree untouched** (scheduled agents share it — keep using this isolated worktree; gitignored plists were copied in: AIConfig/BackendConfig/GoogleService-Info/Info/Transcribe/TranscriptionProviders.plist).

## Commits on this branch

1. `97028234a` Slice 1 (base, previous session) — Review transformation, retry continuity, comparison payoff.
2. `7a9e46ab6` Slice 2 — Today hero, recording surface (live/silence/final-seconds), honest Processing phase, VoiceTrace family, ImmersiveCTA, V4.6 tokens/motion, scripted STT provider, quick-start Today→Recording continuity.
3. `00eaa0911` Slice 3 — Updated Today earned state (once-per-event + collapsed receipt), evidence-led Progress head, V46ProgressPresentation resolvers + ledger, UI_TESTING_V46_EVIDENCE fixture.
4. (in flight) Slice 4 partial — V4.6 four-tab floating capsule (Today/Practice/Progress/You; Settings folds under You, still deep-linkable).

## Verified (all via xcresult / on-sim captures, iPhone 17 Pro iOS 26.5)

- Targeted suites 34/34 green after each slice (ProductJourneyContract, AccessibilityContrast, V46CoachingLoopSurface, V46ProgressPresentation).
- Full loop runs end-to-end on sim with `UI_TESTING_TRANSCRIPTION_SCRIPTED` (Deepgram key is dead — see blockers).
- Captures: `.screenshots/v46-slice2/` (Today, recording live/silence/final-seconds, processing, review) and `.screenshots/v46-slice3/` (updated today, progress head, capsule bar).

## Real blockers

1. **Deepgram 401** — local `Noum/Transcribe.plist` key was revoked in the 2026-07-18 leak closure. Live STT untestable anywhere until Jordan mints a new key (chip filed). Scripted provider covers deterministic verification.
2. **Sim SFSpeechRecognizer** interrupts mid-session — local-provider live runs unreliable in sim; fine on device.

## Remaining Slice 4 work (in priority order)

1. **Dark mode** — app root pins `.preferredColorScheme(.light)` (NoumApp.swift:245); ALL AppColor values are static literals. Token contract is fully recorded in `V4_6_IMPLEMENTATION_PLAN.md` (screen #FAF9F7→#17151C, receded #5A6474→#8A93A4, pressed #3F2499→#7A4FF0, ink/accent →#9061F9, dark frames are semantic recolours). Plan: convert loop-surface tokens to `Color(UIColor { trait })`, unpin root, full visual sweep (AccessibilityContrastTests resolves `.light` explicitly at :53 — extend with dark assertions).
2. **AX3/AX5 proofs** — hero/review already use relativeTo:-anchored fonts + wrap; need capture sweep at AX3+AX5 vs 258:1617/1630/1655/1687 + 263:933 (CTA grows ≥76–84, radius follows height).
3. **UI-test updates** — tests asserting the old 5-tab bar (`nav.settings` button taps, ScreenshotTour tab hops) need re-pointing: Settings now = You tab → push `AppDestination.settings` (deep link `noum://settings` still selects the hidden settings tab). Grep `nav.settings` in NoumUITests.
4. **Tour extension** — add a `testCaptureV46Loop` using `UI_TESTING_TRANSCRIPTION_SCRIPTED` + `UI_TESTING_V46_EVIDENCE` (recording → processing → review → comparison; comparison card still lacks tour coverage).
5. **Remaining state exhibits** — offline state, dark exhibits, RM capture pass (RM behavior is implemented per-motion via `updateWithMotion`/ternaries; needs a Reduce Motion ON capture sweep).
6. Cleanup: `SpotlightOrbView` + milestone-scale animation now unused by the immersive layout (kept for camera/transcript paths); `emptyStateHomeCards`/`populatedHomeCards` in ContentView are dead code from an older generation.

## Key implementation facts (avoid re-deriving)

- Figma page 17 node map + all measured geometry: `artifacts/implementation/V4_6_IMPLEMENTATION_PLAN.md`. Local validated exports: `artifacts/figma/v4.6-final/`.
- Recording clock = session clock (`timingPolicy.targetSeconds`, standard 150s); difficulty 60/30/15s is the scoring target range. Final-seconds = remaining ≤10s (amber + "Land the close", outranks silence cue). Silence = presentation-only 2.5s window on `audioLevel` (>0.1 resets).
- Auto-stop at 0:00 routes through `stopSession()` → `.processing` phase; ready-dwell floor 1.4s (frozen beat). Cancel = `finalizationTask?.cancel()` + FlowLog `rep.processing.cancelled` + dismiss.
- Today Start arms `PracticeModeQuickStart` → setup screen skipped (hero IS the briefing). Adjust dialog launches per-rep `AppDestination.timedPractice(difficulty:)` (never rewrites settings).
- Earned-state contract: `V46EarnedEvidenceLedger` ack on first render; receipt after 10-min floor; keys registered as "v46-earned-evidence".
- Seed recipe: `UI_TESTING UI_TESTING_SEED_FORCE UI_TESTING_SEED_PROFILE improvingIntermediate UI_TESTING_PREMIUM UI_TESTING_TRANSCRIPTION_SCRIPTED UI_TESTING_V46_EVIDENCE` (+ grant mic via `simctl privacy`; cloud consent via Settings → Cloud processing → Allow; `transcriptionProvider=local` default in sim is NOT needed with the scripted arg).
- Simulator: iPhone 17 Pro iOS 26.5 `3C09680E-CD51-42EA-859A-EAB4B4318644`; build with worktree-local `./DerivedData/Noum`; never run concurrent xcodebuild.
