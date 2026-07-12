# Run: 2026-07-12 · branch:ux-overhaul · HEAD b9258cb7 · rewrite controls and phrase-bank verification

## Mode

light

## Changes shipped (this run)

- `Noum/AIRewriteService.swift:76` — adds light, medium, and strong rewrite movement while retaining meaning and vocabulary-preservation constraints.
- `Noum/AIRewriteService.swift` — falls back to a transparent, conservative on-device rewrite when an AI provider is absent or fails; it removes only safe transcript-derived disfluencies, duplicates, and context-free lead-ins, and withholds cosmetic edits.
- `Noum/RewriteSuggestionCard.swift:37` — adds a segmented change-level control, original-versus-rewrite comparison, explicit save, and accessible Phrase Bank entry point.
- `Noum/PhraseBankStore.swift:38` — adds a bounded, account-scoped, identifier-filtered saved-phrase store with deletion and reload behavior.
- `Noum/AccountDataRegistry.swift:403` — registers Phrase Bank data for account export and deletion.
- `Noum/GoalOutcomeCard.swift:5` — only renders a tailored outcome for a voice the user actually chose.
- `Noum/GoalOutcomeCard.swift:44` — adds an opt-in goal-milestone share note only after established, repeated comparable evidence; its text excludes transcripts, raw scores, and causal claims.
- `TranscriptionProvider.swift:328` and `Noum/SpeechRecognizerViewModel.swift:308` — malformed legacy provider settings no longer silently select direct AWS; Release AWS resolution routes locally.

## Screenshots

- `01_home_top.png` — Home tab, top of view.
- `01_train_top.png` — Train tab and recommended rep.
- `01_review_top.png` — Review tab and evidence-to-next-action hierarchy.
- `01_profile_top.png` — Profile tab and user-facing coaching context.
- `01_settings_top.png` — Settings tab and practice/privacy-adjacent controls.
- `goal-outcome-share-summary.png` — injected prescribed-rep loop returned to Summary with established repeated evidence, early-improvement copy, and the privacy-safe `Share this milestone` affordance visible.
- `on-device-rewrite-card.png` — Summary’s Pro rewrite card with Medium selected, a transparent private on-device label, original/rewrite comparison, and save affordance.
- `on-device-rewrite-phrase-bank.png` — saved on-device rewrite rendered in the account-scoped Phrase Bank sheet with its goal, intensity, and weakness labels.

## VISION gap

The new phrase bank closes the reusable-rewrite portion of the goal-directed coaching loop: a user can keep an explicitly chosen line without retaining a duplicate source transcript. The on-device fallback now gives the same loop a privacy-preserving path when a cloud AI provider is unavailable. The remaining gap is provider calibration and physical-device evaluation, not a missing persistence, privacy, or simulator-flow path.

## Next steps to reach desired state

1. Add locale-specific calibration evidence before exposing qualitative goal-outcome reads beyond English.
2. Run the provider-backed rewrite acceptance and visual check on a signed physical device; keep the current on-device result as the offline path, not a proxy for provider quality.
3. Complete the release runbook's real-device, provider, credential-incident, social-cutover, and external-calibration gates.

## Regressions checked

- Five tab roots — `01_home_top.png`, `01_train_top.png`, `01_review_top.png`, `01_profile_top.png`, `01_settings_top.png` — rendered without a launch failure or navigation regression.
- Focused logic and persistence tests — 33 tests passed in the M26 goal-outcome, local-transcription, Phrase Bank, and account-data suites.
- Focused goal-outcome logic — 15 tests passed on iPhone 17 simulator, including on-device fallback and milestone-evidence gating.
- End-to-end prescribed-rep loop — the `GoalOutcomeLoopUITests` Summary → Timed → Summary path passed and captured `goal-outcome-share-summary.png`.
- End-to-end offline rewrite loop — the Summary card rendered the on-device edit with cloud AI unavailable, saved it, and opened the populated Phrase Bank sheet in `GoalOutcomeLoopUITests`. Both focused UI tests passed together.

## Surfaces needing visual verification (cloud → physical-device queue)

- Provider-backed rewrite acceptance, latency, and visual output still require a signed physical-device/provider pass. The private on-device fallback, segmented intensity control, saved state, and Phrase Bank sheet are now simulator-captured.

## For next run

- **If cloud**: continue locale-calibration and release-evidence work without claiming unverified production readiness.
- **If local**: preserve the current deterministic fallback test and run a real-device transcription and consent/fallback matrix when a signed build is available.
