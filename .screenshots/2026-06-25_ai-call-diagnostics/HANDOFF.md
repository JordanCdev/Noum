# Run: 2026-06-25 - branch:ux-overhaul - HEAD a93a071 - AI call diagnostics

## Mode
light

## Changes shipped (this run)
- Noum/PracticeSupport.swift - Added a bounded, persisted, non-secret AI call diagnostics store.
- Noum/AICoachChatService.swift - Records Ask Noum transport success, fallback, and failure outcomes.
- Noum/PracticeSupport.swift - Records post-rep Coach Read skips, fallbacks, failures, and accepted AI reads.
- Noum/SettingsView.swift - Adds developer-only AI calls diagnostics card with count, latest outcome, provider, copy log, and reset.
- NoumTests/NoumTests.swift - Adds diagnostics record/store/export coverage.
- Extended diagnostics coverage across independent model-backed surfaces: AI insights, prompt generation, rewrite suggestions, goal paraphrasing, grammar polish, post-rep coach notes, proof moments, pressure follow-ups, forward plans, Ask Noum starter/follow-up chips, Home recommendations, IM conversation replies/evaluations, and video analysis.

## Live provider probe
- Gemini endpoint is reachable, but the configured project returned HTTP 429 `RESOURCE_EXHAUSTED`.
- Sanitized provider message: project has exceeded its monthly spending cap.
- Local key check: Gemini usable key present; OpenAI and DeepSeek usable keys absent.
- Current product effect: surfaces that rely on `AISettingsManager.activeProvider` will select Gemini first and then fallback/skip/fail according to their safety path until the Gemini spend cap is raised or a usable secondary provider is configured.
- Follow-up implemented: Settings now has a developer-only provider-health preflight that records a `Provider health check` diagnostic from the same active-provider/key path.

## Screenshots
- 01_home_top.png - Home tab, top of view.
- 01_train_top.png - Train tab, prescribed next rep.
- 01_review_top.png - Review tab, chart and coach read.
- 01_profile_top.png - Profile tab, profile hero and coach evidence.
- 01_settings_top.png - Settings tab, top of user settings.

## VISION gap
Noum relies on trustworthy AI-backed coaching, but provider failures were hard to distinguish after the fact: missing key, unsupported locale, rate-limit/HTTP fallback, transport failure, or accepted model output all looked the same from QA. This run adds an internal operational trace without storing sensitive user content.

## Next steps to reach desired state
1. Noum/SettingsView.swift - Add a deterministic UI-testing auth hook only if product wants automated coverage of developer-only settings surfaces.
2. AI provider ops - Raise the Gemini AI Studio monthly spend cap or configure a usable OpenAI key so live model calls can return output again.
3. Release QA - Run the Settings provider-health preflight before TestFlight upload and require a success record.
4. Backend - Longer term, proxy provider calls server-side so client builds do not hold third-party model keys and provider failover can be managed centrally.

## Regressions checked
- Home top - 01_home_top.png - rendered populated coaching entry and Ask Noum card.
- Train top - 01_train_top.png - prescribed rep card wraps cleanly and has a single "Other ways to practice" control.
- Review top - 01_review_top.png - chart and coach read render.
- Profile top - 01_profile_top.png - "Your profile" copy and rolling-baseline language render cleanly.
- Settings top - 01_settings_top.png - Settings still opens after the diagnostics view edit.

## Surfaces needing visual verification
- Developer-only AI calls diagnostics card: compiled and unit-tested, but not visually captured because the seeded UI-test auth path does not guarantee a developer account ID.

## For next run
- If local: decide whether to add a debug-only launch arg for developer account seeding, then capture the expanded Settings advanced diagnostics card directly.
- If cloud: add a small provider-health check to release QA so capped/quota-exhausted provider configs are caught before a TestFlight build.
