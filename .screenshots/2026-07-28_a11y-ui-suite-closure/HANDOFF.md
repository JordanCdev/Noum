# Run: 2026-07-29 · branch:ux-overhaul · HEAD 517998349 · Accessibility pass and Otherpath identity closure

## Mode

light

## Changes shipped (this run)

- `Noum.xcodeproj/project.pbxproj:852` and `Noum.xcodeproj/project.pbxproj:986` — app, test, widget, Watch, Messages, and Watch companion identities use the `uk.co.otherpath.noum` namespace.
- `functions/src/appStoreServerNotifications.ts:32` and `scripts/release_testflight_preflight.py:34` — App Store notification verification, App Group expectations, and release/CI contracts bind to the same migrated identity.
- `scripts/run-noum-with-ai.sh:8`, `maestro/chat_smoke.yaml:25`, and `.agents/skills/noum-screenshots/SKILL.md:26` — simulator, Maestro, and screenshot automation launch the migrated bundle.
- `Noum/KeychainHelper.swift:7` and `Noum/AuthManager.swift:1300` — UI automation identities are isolated from production Keychain state, and signed-out fixtures fail closed instead of inheriting simulator-global authentication.
- `Noum/ProgressionCharts.swift:51` and `Noum/ProgressionCharts.swift:916` — progress charts use appearance-aware opaque roles, non-colour hierarchy, truthful low-evidence presentation, and targeted accessibility appearance behavior.
- `Noum/SessionHistoryListView.swift:312` — Session History search, sort, filters, and rows expose stable semantics, selected-state cues, 44-point targets, and an Accessibility XXXL layout.
- `Noum/TimedPracticeView.swift:2379` — long Accessibility XXXL prompts scroll within the thinking body while the primary **Start Now** action stays pinned and operable.
- `Noum/SuddenDeathPracticeView.swift:22` and `Noum/PracticeSupport.swift:6085` — prompt readout, local speech callbacks, and recorder handoff are request- and generation-bound across Timed and Sudden Death practice.
- `NoumTests/ProductionReadinessOverhaulTests.swift:8` — a source-owned identity contract rejects exact legacy bundle/App Group literals across active release, launch, entitlement, and operational paths.
- `docs/CURRENT_STATE.md:3` — exact final unit, app/UI, identity, and focused verification evidence plus remaining external launch gates.

## Screenshots

- `01_home_top.png` — Today tab, fresh local guest and first-rep action.
- `01_train_top.png` — Practice tab, coach-selected Timed Practice recommendation.
- `01_review_top.png` — Progress/Review tab, truthful fresh-account empty state.
- `01_profile_top.png` — You/Profile tab, current plan and Library entry.
- `01_settings_top.png` — Settings route, practice, cue, language, sound, and appearance controls.

All five PNGs were opened and visually inspected after capture. Each rendered
the expected destination; there were no blank, splash, crash, or wrong-route
frames.

## VISION gap

The touched surfaces now better match Noum's calm, coherent communication
system: progress presentation is evidence-aware, practice actions remain
operable at large text sizes, state ownership stays unified, and speech
handoffs no longer overclaim stale lifecycle events. The remaining
accessibility gap is architectural rather than isolated to these screens:
Reduce Transparency and Differentiate Without Color are handled deliberately
by charts but not yet audited across every visual surface; many controls still
have sparse `accessibilityValue` coverage; the live-transcript serif treatment
still needs a product decision; and physical-device VoiceOver, motion, audio
interruption, and microphone behavior are not proven by simulator evidence.

## Next steps to reach desired state

1. Audit app-wide Reduce Transparency and Differentiate Without Color behavior from `DesignSystem.swift` rather than adding per-screen exceptions.
2. Extend native accessibility audits from `NoumUITests/JourneyAccessibilityAuditUITests.swift` to prioritize stateful controls with missing `accessibilityValue` semantics.
3. Resolve the live-transcript serif decision in `Noum/TimedPracticeView.swift`, then verify the chosen treatment at Accessibility XXXL.
4. Run the existing VoiceOver, Reduce Motion, speech playback, audio interruption, and recording lifecycle checklist on a physical iPhone before release sign-off.
5. Complete App Check registration, App Group confirmation, Firebase plist/API-key cutover, paid-team entitlement correction, and old Firebase-app retirement as operator-owned release gates.

## Regressions checked

- Full serialized `NoumTests` — `/private/tmp/noum-codex-full-unit-final-72.xcresult` — 4,785 passed, 0 failed, 2 expected failures, 0 skipped.
- Full serialized `NoumUITests` — `/private/tmp/noum-codex-full-ui-final-69.xcresult` — 95/95 device executions passed with no failures or skips; 90/90 top-level after parameterized aggregation.
- Source-owned Otherpath identity contract — `/private/tmp/noum-codex-identity-contract-71.xcresult` — 1/1, no regression.
- Functions and release gates — 191/191 Functions tests, 9/9 deployment locks, and 117/117 release-script tests.
- Timed Accessibility XXXL primary action — `/private/tmp/noum-codex-timed-axxxl-layout-66.xcresult` and `-67.xcresult` — 1/1 twice, no regression.
- Prompt/media lifecycle — `/private/tmp/noum-codex-focused-speech-lifecycle-63.xcresult` — 16/16, no regression.
- Progress chart presentation and contrast — `/private/tmp/noum-codex-focused-chart-53.xcresult` — 35/35, no regression.
- Session History Accessibility XXXL controls — `/private/tmp/noum-codex-history-axxxl-55.xcresult` — 1/1, no regression.
- Native transcript accessibility audit — `/private/tmp/noum-codex-transcript-audit-57.xcresult` and `-58.xcresult` — 1/1 twice, no regression.
- Five tab tops — the PNGs in this folder — expected routes and complete rendering confirmed.

## Surfaces needing visual verification (cloud → local queue)

- Physical-device VoiceOver traversal and rotor behavior.
- Reduce Motion during actual prompt playback, recording handoff, and video interruption.
- System Reduce Transparency and Differentiate Without Color outside the chart surfaces.
- Live transcript typography and in-rep states with real microphone/audio-session behavior.

## For next run

- **If cloud**: continue static accessibility-value inventory and consolidate shared verdict-chip semantics without claiming device behavior.
- **If local**: perform the physical-device accessibility/audio checklist and capture focused in-rep Dynamic Type states after the transcript typography decision.
