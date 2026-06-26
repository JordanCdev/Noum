# Run: 2026-06-25 · branch:ux-overhaul · HEAD a93a071 · AI provider diagnostics/settings check

## Mode
light

## Changes shipped (this run)
- `Noum/PracticeSupport.swift` — AI diagnostics now include a redacted provider setup summary and compact OpenAI/DeepSeek error-class parsing.
- `Noum/SettingsView.swift` — developer AI diagnostics card shows provider key presence/missing status without exposing secrets.
- `NoumTests/NoumTests.swift` — tests pin provider setup summary, no-key leakage, and OpenAI error-class handling.

## Screenshots
- `01_home_top.png` — Home tab, rendered correctly.
- `01_train_top.png` — Train tab / next rep screen, rendered correctly.
- `01_review_top.png` — Review tab, rendered correctly.
- `01_profile_top.png` — Profile tab, rendered correctly.
- `01_settings_top.png` — Settings/practice settings surface, rendered correctly.

## VISION gap
Noum's coach-parity promise depends on knowing whether the AI model path is actually alive. A configured key is not enough: the live Gemini probe reached Google but returned `PERMISSION_DENIED`, while OpenAI/DeepSeek keys are missing. The app now exposes non-secret diagnostics for this state instead of allowing silent fallback behavior to look like weak coaching.

## Next steps to reach desired state
1. Enable the Google Generative Language API for the Gemini key's Google project, or replace the bundled Gemini key with one from an enabled project.
2. Configure a real fallback provider key if Noum should remain functional when Gemini is unhealthy.
3. Add a focused UI-test scroll/capture for the developer AI diagnostics card if that internal surface becomes release-critical.

## Regressions checked
- Home top — `01_home_top.png` — no blank/splash regression.
- Train top — `01_train_top.png` — no blank/splash regression.
- Review top — `01_review_top.png` — no blank/splash regression.
- Profile top — `01_profile_top.png` — no blank/splash regression.
- Settings top — `01_settings_top.png` — no blank/splash regression.

## Surfaces needing visual verification
- The lower Settings developer AI diagnostics card was not directly visible in the light top screenshot; behavior is covered by focused unit tests.

## For next run
- **If cloud**: continue code-level provider fallback or API-key hygiene work.
- **If local**: after fixing provider credentials, run the in-app "Run provider check" button and capture the diagnostics card scrolled into view.
