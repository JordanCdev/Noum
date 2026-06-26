# Run: 2026-06-25 - branch:ux-overhaul - HEAD a93a071 - AI provider health check

## Mode
light

## Changes shipped (this run)
- Noum/PracticeSupport.swift - Added `AIProviderHealthProbe`, a fixed-sentinel provider preflight that uses the existing active-provider/key path and records only metadata into `AICallDiagnosticsStore`.
- Noum/SettingsView.swift - Added a developer-only "Run provider check" action to the existing AI calls diagnostics card, with a short status line after the probe completes.
- NoumTests/NoumTests.swift - Added `AIProviderHealthProbeTests` covering request shape, sentinel parsing, provider error-class extraction, and result summaries.
- .screenshots/2026-06-25_ai-call-diagnostics/HANDOFF.md - Updated the prior handoff with the live Gemini 429 `RESOURCE_EXHAUSTED` finding and the provider-health next step.

## Screenshots
- Not captured. The light sweep was attempted after the Settings UI change, but `xcrun simctl boot 3D077053-2981-4C5D-819D-FF6F9BA8AD06` required escalation and the approval review timed out twice before the simulator could boot.

## VISION gap
Noum's coach-parity promise depends on model-backed surfaces being operationally trustworthy. The previous diagnostics pass made failures visible after a user hit an AI surface; this run adds a deliberate preflight so QA can detect capped, missing, or unhealthy provider configuration before a TestFlight build reaches users.

## Next steps to reach desired state
1. AI provider ops - Raise the Gemini AI Studio monthly spend cap or configure a usable secondary OpenAI key, then run the Settings provider check and confirm a `Provider health check` success record.
2. Local QA - Re-run the `noum-screenshots` light sweep after simulator boot access is available, ideally with a developer account seed that exposes `settings.aiCallDiagnostics.card`.
3. Release QA - Add a checklist item that the provider-health preflight must pass before TestFlight upload.

## Regressions checked
- `xcodebuild test` - `AIProviderCredentialTests`, `AICallDiagnosticsStoreTests`, and `AIProviderHealthProbeTests` passed on iPhone 17 simulator.
- `git diff --check` - clean before the screenshot handoff was written.

## Surfaces needing visual verification
- Developer-only Settings AI calls diagnostics card with the new "Run provider check" action.
- Post-check summary text for success and failure states.

## For next run
- If local: boot the simulator, run the light screenshot sweep, then manually exercise the provider check once the Gemini cap or fallback provider is fixed.
- If cloud: continue coach-parity gap work that does not require simulator UI capture.
