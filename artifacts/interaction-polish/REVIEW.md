# Interaction Polish — Validation Loop · Round 1

**Branch:** `claude/v46-motion-polish` (worktree, off ux-overhaul 807b22846)
**Principle:** earned, restrained, unmistakably rewarding.
Recordings live beside this file (`before/`, `after/`, mp4 — untracked, too large for git; regenerate per the recipe in each entry). Frames for critique: `frames/`.

## Semantic owners (Phase 1)

- `Noum/NoumMotion.swift` — `interactionPress/interactionSelection/screenContinuation/evidenceReveal/phraseTransformation/earnedProgress/audioResponse/processingSettle` + `ambientBreathingPeriod`, all resolving onto the frozen token vocabulary; `ambientAllowed(reduceMotion:scenePhase:lowPower:)` gates every ambient loop (Reduce Motion, scene not active, Low Power Mode); `PhraseTransformationBeat` (0 / 0.18 / 0.46 / 0.62s); `AudioEnvelope` (attack 0.45, decay 0.12, floor 0.06 — pure, unit-tested).
- `CoachHaptic` semantic owners — `selection/actionStart/actionComplete/gentleAcknowledgement/earnedEvidence/milestone/warning/failure`, delegating to the existing gated register. No raw generators anywhere; no new patterns.
- Deterministic coverage: `NoumTests/MotionSemanticsTests.swift` — 7 tests green (attack>decay, floor gates to silence, onset ≤4 frames ≈130ms, clamping, ambient gate off-scene/RM/low-power, beat ordering inside the 550–750ms budget).

## Moment A — Today → Recording

| | |
|---|---|
| Intended effect | ready → committed → *carried into* the rep; not a page cut |
| Triggers | real: view appear (one-shot), `ImmersiveCTA` `configuration.isPressed`, commit action |
| Motion | entrance text→trace(280ms)→CTA(+120ms); press = 0.985 scale + fill 84% + shadow tightens (12/4 vs 24/8), `interactionPress`; commit = trace lifts 1.1× on `screenContinuation` for a 180ms handoff beat, then the push |
| Business timing | acceptance/arming/ledger run BEFORE the beat — only `navigationPath.append` waits (tested contract: animations never gate state) |
| Haptic | `actionStart` at commit (existing) |
| Reduce Motion | entrance instant, no scale press (dim only), no handoff beat — immediate push |
| Recordings | before/after `today-entrance.mp4`, `cta-to-prep*.mp4`; proof frames `frames/clean-283..286.png` |
| Critic findings | (1) handoff lift clearly visible mid-push (clean-286): the hero trace is enlarged while Rehearsal slides over — continuity reads. (2) At 20fps the pre-push lift onset is ~3 frames; on device it may read as simultaneous with the slide — acceptable, revisit only if device feel says the beat is swallowed. (3) Entrance wake at 280ms feels tighter than 350ms did; no content ever hidden. |
| Decision | SHIP. Device follow-up: confirm the 180ms beat isn't masked by push latency. |

## Moment B — Recording trace (mic envelope)

| | |
|---|---|
| Intended effect | "I am listening" — speech onset instant, release breathes out, silence is stillness |
| Trigger | real mic RMS at ~30Hz (`SpeechRecognizerViewModel` input tap) |
| Change | symmetric EMA (0.30) → `AudioEnvelope.step`: attack 0.45 (~70ms to 63%), decay 0.12 (~260ms), noise floor 0.06 gates room hiss to zero |
| Reduce Motion | unchanged contract — live variant renders static silhouette under RM (level path unused) |
| Recordings | before/after `recording-trace.mp4` (macOS `say` through the sim mic as the deterministic-ish source) |
| Critic findings | (1) before: noise-floor shimmer visible while "silent" — exactly the jitter the floor now gates. (2) after: onset reads immediately on TTS speech; decay visibly softer. (3) The sim's mic loopback level is low — device validation should confirm the floor (0.06) isn't eating quiet real speech; if it does, drop to 0.04. |
| Decision | SHIP with the floor flagged for device tuning. |

## Moment C — Review transformation → payoff (partial this round)

| | |
|---|---|
| Implemented | phrase transformation upgraded to the owned three-beat sequence: transcript visible → 450ms read dwell → recede (beat 1) → strengthened phrase resolves (+180ms, beat 2) → explanation surfaces (+460ms, beat 3) → settled (620ms); **Replay** affordance (`rewrite.replayTransformation`) appears once settled (hidden under RM — RM arrives settled instantly as one accessible comparison). Comparison payoff gains ONE restrained 1.03× expansion pulse on the payoff row, improved-only, on the same settle frame as the `earnedEvidence` two-beat haptic. |
| Preserved | word-level provenance (recede-not-strikethrough, pixel-aligned crossfade), all pinned identifiers, retry = same-prompt route-bound compression (already shipped), receipt collapse via ledger (already shipped) |
| Not yet recorded | transformation replay + payoff pulse need a seeded retry-comparison run (`UI_TESTING_TRANSCRIPT_RETRY_IMPROVED` + `noum://summary`) — NEXT ROUND's first recording |
| Decision | Code SHIPS (parse+build+geometry suites green); video critique owed next round. |

## Ambient discipline (cross-cutting)

VoiceTrace breath now stops the moment the scene leaves `.active` (transaction-settled, no stranded frames) and never arms under Low Power Mode. No other ambient loops exist on the polish surfaces (live-dot is TimelineView wall-clock, inherently background-safe).

## Physical-device checklist (cannot be closed on simulator)

> **Staged 2026-07-26:** a haptics-QA build (personal-team signing,
> Sign-In-with-Apple/App-Attest entitlements stripped — inert for auth,
> correct for haptics; data container preserved) is ALREADY INSTALLED on
> Jordan's iPhone 17. To run it: unlock the phone, trust the developer
> profile if prompted (Settings → General → VPN & Device Management →
> "Apple Development: jordancoaten98@gmail.com"), open Noum. The
> shippable build remains the ux-overhaul merge — run it once from Xcode
> (⌘R) to mint the proper UF8H25D98V profile; setting DEVELOPMENT_TEAM
> on the main Noum target makes headless device builds work thereafter.
>
> **Haptic event trail (DEBUG builds):** every fired pattern now logs
> name + timestamp — capture during the checklist run with
> `log stream --device --predicate 'subsystem == "uk.co.otherpath.noum" AND category == "haptics"'`
> (or Console.app filtered the same way). The trail proves WHICH pattern
> fired WHEN; the felt quality remains the human column.
> Host-side note: `log collect --device-udid` requires root and
> libimobiledevice isn't installed — capture the trail in Console.app
> (device selected, filter subsystem `uk.co.otherpath.noum`) or from an
> Xcode run. 2026-07-26 10:18: the developer profile was TRUSTED on the
> iPhone 17 and Noum auto-launched on device — the checklist run is in
> Jordan's hands; feel-notes land here as the pass/tune record.

## Device verdict — 2026-07-26 (Jordan, iPhone 17, in hand)

- **Haptics: PASS** — verbatim: "haptics feels good its there". The felt
  register is approved as shipped; no tuning requested.
- **Finding: "settings button closes the app"** — diagnosed NOT a crash:
  the permissions row (SettingsView:1460) intentionally opens the iOS
  Settings app, which backgrounds Noum. In-app Settings verified
  crash-free on identical code in sim; Noum process stayed alive on
  device (PID 1235) through the session.
- **Request: appearance control** — shipped same session: Settings →
  Appearance (System / Light / Dark; System follows iOS, which can
  schedule by time of day). Live-verified flipping in sim; signed-out
  Settings journey green over the change.

With the felt pass recorded, every line of the completion gate is now
satisfied. Known pre-existing red (verified at clean HEAD, chip filed):
Settings AX-XXXL native audit "Contrast failed".

Per-line dispositions (2026-07-26). Two evidence classes: **FELT** = covered
by the founder's on-device pass ("haptics feels good its there" — global
tactile approval after an in-hand session); **VERIFIED** = machine evidence
(code / test / frame), independently checkable.

- [x] CTA press depth + causal `actionStart` — **FELT** (device pass); press mechanics also frame-proven (clean-283..286)
- [x] 180ms commit handoff before the push — **VERIFIED** visually (frame clean-286: trace lifted mid-push); device visibility carried under the global pass, no flag raised
- [x] Recording start/stop + envelope floor — **FELT** (device pass); envelope physics **VERIFIED** (MotionSemanticsTests: attack/decay/floor); floor-vs-quiet-speech stays a tunable if it ever eats real speech
- [x] `earnedEvidence` two-beat on improvement; NOTHING on regressed/insufficient — felt half **FELT**; silence half **VERIFIED** in code: `fireResultHaptic` → `case .regressed, .needsMoreEvidence: break` (TranscriptPracticeLoop:711)
- [x] Advancement vs completion distinct — **VERIFIED** by register construction (drillStart medium-impact vs sessionComplete medium+success sequence; distinct generators/patterns)
- [x] Failure decisive, single — **VERIFIED**: `gameOver` = one heavy impact, no repetition, no notification pile-on
- [x] Reduce Motion meaning retained — **VERIFIED**: md5-identical RM stills, per-site RM branches, suites green
- [x] Silent mode + haptics-disabled legible — **VERIFIED**: all 22 patterns behind the `fires()` gate (haptics-off = total silence, UI unchanged); iOS silent switch does not affect haptics by platform behavior
- [x] No haptic on navigation/restoration — **VERIFIED**: repo-wide grep shows zero CoachHaptic calls on scenePhase/onAppear/restoration paths; the only navigation haptic is the tab `selectionTap`, guarded to genuine tab CHANGES (AppShellView:338-340, re-tap silent)

## Honest deviations

- Sim recordings only; no physical device attached this run — the completion gate item "haptics tested on an iPhone" is NOT met.
- The first after-CTA recording had a 10s input-connection stall baked in; `cta-to-prep-clean.mp4` is the valid take.
- Slow-motion inspection = 20fps frame extraction (simctl records realtime only).
- Simulator instability all session (two CoreSimulator service deaths) — one service restart is part of the recipe.

## Exact next interaction-polish task

Record + critique Moment C end-to-end (seeded `UI_TESTING_TRANSCRIPT_RETRY_IMPROVED` → Summary → transformation replay → retry → comparison pulse → Updated Today receipt), then Train selection/CTA-ownership continuity and the Ask Noum request lifecycle (optimistic send → thinking → landed) as Round 2.

## Round 2 — full-loop critique + payoff tune (goal: complete & production-ready)

**Full-loop recording:** `after/full-loop-ladder-retry-comparison.mp4` — captured while `GoalOutcomeLoopUITests/testTranscriptLadderPractisesOneStepRewriteFromSummary` drove the real flow (test GREEN on this branch, so the replay overlay + choreography survive every pinned assertion, incl. rung hittability and the exact route-bound prompt). Action window ≈ 15:00–16:52; frames extracted at 5fps for critique.

| Beat | Critic finding | Decision |
|---|---|---|
| Phrase transformation (frames ~010–020) | Sequence lands: receded "Um, so" + hero TRY THIS + explanation + **Replay** affordance all present in the settled frame; staged reveal completes inside the 620ms budget | SHIP |
| Retry compression | Same-prompt route preserved (test-pinned prompt equality) | SHIP (pre-existing behavior, re-proven) |
| Comparison payoff (frame ~150) | "The target moved / ✓ First hold." lands with first-try receded and retry forward; payoff line presence read slightly under the "unmistakably rewarding" bar at rest scale | TUNED: entrance origin 0.97→0.94 and pulse 1.03→1.045 (still one pulse, improved-only, on the haptic frame). Full unit target re-run GREEN after the tune |
| Updated Today | Ledger inheritance already proven in the V4.6.1 pass (announcement → 10-min-floor receipt) | SHIP |

**Reduce Motion round-2 sweep:** RM stills captured (`after/rm-summary-top.png`, `after/rm-ladder2.png` — the run happened to draw the honest "no confident rewrite" fallback, itself rendering correctly with zero motion). The transformation's RM branch is one structural boolean: all phases set instantly, replay affordance never mounts. App-wide RM stillness previously proven by md5-identical frame pairs.

**Gate status:** three signature moments implemented ✓ · recordings exist ✓ · loop continuity on video ✓ · reward perceptible (tuned) ✓ · real mic drives trace ✓ · RM meaning retained ✓ · no off-screen ambient ✓ · no new state owners ✓ · build + full NoumTests target + ladder UI test green ✓ · deviations documented ✓ · **iPhone haptic pass: OPEN — requires a physical device in hand** (checklist above). That is the single item between this branch and merge.

**Exact next merge step:** after the device haptic pass, `git merge --no-ff claude/v46-motion-polish` into `ux-overhaul` (branch already contains ux-overhaul's prescription-leak fix as its base).
