# Run: 2026-07-18 · branch:ux-overhaul · HEAD 716b9fc7b · Ask Noum goal continuity and incident tracing

## Mode

light

## Changes shipped (this run)

- `Noum/CoachContextBuilder.swift` — carries typed voice intent through clarification and names the real Persuasive practice catalogue.
- `Noum/AskNoumView.swift` — acknowledges a voice change only after profile persistence succeeds and keeps failed saves recoverable.
- `Noum/CoachReplyPipeline.swift` — correlates each turn across the pipeline and gates deterministic recovery copy before surfacing it.
- `Noum/AICoachChatService.swift` — replays the immediate referent, aligns Persuasive quality checks, and records content-free rejection labels.
- `Noum/AskNoumStore.swift` — retains a transient categorical failure receipt under the authoritative coach-row trace.
- `functions/src/index.ts` — emits allowlisted intent, response, depth, and quality metadata without conversation content.

## Screenshots

- `01_home_top.png` — Home tab, top of view.
- `01_train_top.png` — Train tab, recommended practice surface.
- `01_review_top.png` — Review tab, recent movement surface.
- `01_profile_top.png` — Profile tab with Persuasive visible as the voice target.
- `01_settings_top.png` — Settings tab.

## VISION gap

The deterministic path now preserves a saved coaching goal, answers against Noum's real practice catalogue, and leaves a private trace when a turn fails. That better supports the calm, truthful communication-operating-system goal in `docs/VISION.md`. It does not yet prove that open-ended replies consistently feel like a perceptive human expert: no current-source live-provider conversation sweep or independent coach calibration exists.

## Next steps to reach desired state

1. Add typed evidence provenance or split the contradictory fixtures for the seven excluded fallback tests; do not relax `Noum/CoachReplyPipeline.swift` evidence gates.
2. Commit and deploy the updated Functions source through the authorized source-bound release workflow, then replay the exact Persuasive clarification and detailed practice question with trace IDs retained.
3. Add a deterministic Ask Noum UI fixture for goal-save success, goal-save failure, clarification continuity, and the detailed capability response.

## Regressions checked

- Home root — `01_home_top.png` — expected hero and navigation render after a normally signed install.
- Train root — `01_train_top.png` — recommended Timed Practice surface renders.
- Review root — `01_review_top.png` — recent movement surface renders.
- Profile root — `01_profile_top.png` — Persuasive target is visible and consistent with persisted state.
- Settings root — `01_settings_top.png` — grouped settings render.
- Account preparation — an unsigned diagnostic install reproduced Keychain status `-34018`; reinstalling the normally signed Debug build restored the five tab roots.

## Surfaces needing visual verification (cloud → local queue)

- Ask Noum exact goal-change acknowledgement and bare-clarification sequence.
- Ask Noum detailed practice/capability answer and correlated failure presentation.
- Voice-goal save failure card and retry state.

## For next run

- **If cloud**: extend typed evidence fixtures and audit the remaining transport-level correlation gaps.
- **If local**: deploy only through the authorized source-bound workflow, replay the reporter's exact conversation, and capture the Ask Noum states above.
