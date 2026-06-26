# Run: 2026-06-25 · branch:ux-overhaul · HEAD 28b1e2a · AI connectivity and coach-copy shippability pass

## Mode
light

## Changes shipped (this run)
- `Noum/AICoachChatService.swift` and sibling AI service files — shared API credential lookup and opt-in debug instrumentation so model calls can be probed and diagnosed without leaking keys.
- `Noum/PrimaryFocusMemory.swift` — success-criterion and persistent-baseline hypothesis copy now uses user-facing coach language instead of internal labels.
- `Noum/PracticeSupport.swift` — "continue and verify" recommendation copy handles pending criteria honestly and reads naturally when the target is already being met.
- `Noum/PracticeModeSelectionView.swift` — target/focus prescription line now uses clear label punctuation in the recommended practice card.
- `NoumTests/NoumTests.swift` — focused regression coverage for AI context, prescription copy, coach-memory hypothesis basis, and success-criterion wording.

## Screenshots
- `01_home_top.png` — Home tab, top of view before the final copy pass.
- `01_train_top.png` — Train tab before the final target/focus punctuation pass.
- `01_review_top.png` — Review tab, top of view.
- `01_profile_top.png` — Profile tab before the final hypothesis-basis copy pass.
- `01_settings_top.png` — Settings tab, top of view.
- `02_train_top_after.png` — Train tab after copy pass; target/focus wraps cleanly and the CTA remains visible.
- `02_profile_top_after.png` — Profile tab after copy pass; coach read no longer exposes "persistent blocker" internals.

## VISION gap
Noum is moving toward the "expert coach" loop, but the visible trust layer is fragile when internal evidence labels leak into user copy. This pass closes one narrow but important gap: evidence-backed copy now sounds like a coach explaining a read, not a telemetry label.

The larger VISION gap remains perception depth and validated coaching outcomes. Current simulator evidence supports flow quality, API reachability, and copy coherence; it does not prove real-world coaching replacement.

## Next steps to reach desired state
1. Add an in-app diagnostics surface for recent AI call health that is available only in debug/internal builds, so future QA can see provider, status, latency, and fallback reason without reading logs.
2. Run the detailed screenshot tour before TestFlight once the remaining unstaged UI work is finalized; this pass used light screenshots plus scoped UI tests.
3. Continue replacing generic "working hypothesis" prose with shorter, more conversational coach-read components where screenshots still show paragraph-heavy copy.

## Regressions checked
- AI provider path — live Gemini probe returned HTTP 200 with expected response during the AI-connectivity pass.
- Focused unit suites — `CoachContextBuilderTests`, `PracticeModePrescriptionCopyTests`, and `CoachMemoryEngineTests` passed on iPhone 17 simulator.
- Scoped UI tests — `NoumUITests.testPracticeModesOpenAvailableScreens` and `NoumUITests.testProfileEvidenceDisclosureStaysCoachEvidenceOnly` passed on iPhone 17 simulator.
- Train visual — `02_train_top_after.png`; no truncation, target/focus punctuation fixed, one primary Begin remains.
- Profile visual — `02_profile_top_after.png`; "Your profile" remains, authoritative icon appears, hypothesis basis is readable.

## Needs visual verification
- Full detailed 27-surface screenshot tour still needed before release signoff.
- Paywall, in-rep audio states, and summary dynamic states were not covered by this light pass.
