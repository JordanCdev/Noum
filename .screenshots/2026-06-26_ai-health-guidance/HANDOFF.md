# Run: 2026-06-26 · branch:ux-overhaul · HEAD a93a071 · AI provider health diagnostics

## Mode
light

## Changes shipped (this run)
- `Noum/AICoachChatService.swift:523` — Google Cloud chat health probes now use the Agent Platform API-key express endpoint shape.
- `Noum/PracticeSupport.swift:990` — shared Gemini diagnostics can route through the same Agent Platform endpoint when an Agent Platform key is configured.
- `Noum/PracticeSupport.swift:1331` — provider health guidance turns raw check results into actionable support messages without leaking keys or private model paths.
- `Noum/PracticeSupport.swift:1527` — 404/NOT_FOUND responses are classified as a model-or-endpoint configuration failure.
- `Noum/SettingsView.swift:1540` — Settings runs shared structured-AI and Ask Noum chat provider probes together.
- `Noum/SettingsView.swift:1557` — Settings renders a concise guidance card after the raw AI health summary.
- `Noum/AIConfig.plist.example:41` — local config template now documents Agent Platform API key + model without stale project/location fields.

## Screenshots
- `01_home_top.png` — Home tab, top of view.
- `01_train_top.png` — Train tab, coach-picked next rep.
- `01_review_top.png` — Review tab, progress and coach read.
- `01_profile_top.png` — Profile tab, voice-target profile card.
- `01_settings_top.png` — Settings tab, profile card and practice defaults.

## VISION gap
Noum needs believable AI coaching, not silent fallback behavior. This run improves launch-readiness by making live model health visible, copyable, and supportable. The local Google Cloud key/model path still does not return a healthy sentinel, so the app is better instrumented, but the production AI provider path is not yet proven healthy.

## Next steps to reach desired state
1. Fix external provider setup: validate the Google Cloud Agent Platform key, enabled API surface, and model ID, or configure a healthy direct Gemini/OpenAI/Claude key.
2. Capture Settings mid/bottom or run detailed screenshot mode to visually verify the AI diagnostics guidance card after a provider check.
3. Decide whether TestFlight should rely on local bundled keys, remote-vended provider config, or a backend proxy before release.

## Regressions checked
- Home top — `01_home_top.png` — no blank launch or broken primary CTA.
- Train top — `01_train_top.png` — recommended rep is focused and the overloaded setup is not first-screen clutter.
- Profile top — `01_profile_top.png` — profile identity now reads as the user's profile, not “Guest Speaker.”
- Settings top — `01_settings_top.png` — profile card and practice defaults render without overlap.
- Detailed UI tour — attempted via `ScreenshotTour.testCaptureAdvancementSurfaces`; Xcode/simulator runner stalled during launch/log finalization and was interrupted, so this is not counted as a pass.

## Surfaces needing visual verification (cloud → local queue)
- Settings AI diagnostics card after tapping “Run provider checks”; the light screenshot stops above this lower settings section.
- Full detailed tour after the current dirty worktree settles, especially Settings mid/bottom and Ask Noum typed-chat polish.

## For next run
- **If cloud**: continue pure logic/test work around provider configuration, prompt quality, and diagnostics export.
- **If local**: run detailed screenshots or a targeted Settings UI test that scrolls to `settings.aiCallDiagnostics.card` after a health check.
