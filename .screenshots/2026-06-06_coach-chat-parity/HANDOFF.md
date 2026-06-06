# Run: 2026-06-06 · branch:Redesign · HEAD 8a865a1 · coach-chat parity and premium UX audit

## Mode
light

## Changes shipped (this run)
- `Noum/AICoachChatService.swift` — added stricter senior-coach reply gates so robotic, overlong, menu-like, or ungrounded replies are repaired/fallen back.
- `Noum/CoachContextBuilder.swift` — added turn-aware follow-up chip filtering so AI chips must match the actual user/coach exchange instead of generic "keep going" prompts.
- `Noum/AskNoumModeSuggestion.swift` — narrowed Ah-Counter launch routing so plain filler mentions do not become mode cards unless a filler drill/round is explicitly prescribed.
- `Noum/ContentView.swift` — aligned empty Home with the coach-first `HomeSignalGate` floor instead of showing daily/progression surfaces before user signal exists.
- `Noum/PracticeModeSelectionView.swift` — split mode title and metadata into separate rows to prevent Recommended/mastery badges from crushing the mode title on iPhone widths.
- `NoumTests/NoumTests.swift` — added regression coverage for coach reply quality, context-aware chips, evaluation fixtures, Home gate contracts, and filler mention routing.
- `docs/COACH_REPLACEMENT_SCORECARD.md` — updated the coach-parity assessment with current validation gaps.

## Screenshots
- `01_home_top.png` — Home tab, top of view.
- `01_train_top.png` — Train tab, top of view. Captured before the final Train card layout fix; recapture was blocked by the approval layer after the corrected build installed.
- `01_review_top.png` — Review tab, top of view.
- `01_profile_top.png` — Profile tab.
- `01_settings_top.png` — Settings tab.

## VISION gap
The app is moving toward a persistent coach, not just a generic AI wrapper: it now carries case-file context, active intervention framing, follow-up chip discipline, and better text-mode response gates. The remaining gap to the VISION goal is evidence and depth. Noum still needs stronger validated outcome loops, deeper delivery perception, and more human-caliber case formulation before it can credibly claim parity with a senior communications coach.

## Next steps to reach desired state
1. Add a true coach validation harness that scores generated replies against expert-written rubrics and stores regressions by scenario.
2. Deepen transfer tracking so real-world events, confidence, avoidance, and outcome changes influence the next prescription.
3. Add first-class delivery signals for pause quality, intonation, vocal variety, energy, and word-choice structure.
4. Re-capture `01_train_top.png` after the metadata-row layout fix and inspect the card hierarchy on iPhone 17.

## Regressions checked
- Focused coach/home/routing tests — passed.
- Full app build — passed.
- Light screenshot sweep — rendered Home, Train, Review, Profile, and Settings; Train exposed cramped row metadata, which was patched and build-verified.

## Surfaces needing visual verification
- Train picker after `PracticeModeSelectionView` layout fix. Corrected build installed; final screenshot recapture was blocked by the approval layer.
- Ask Noum live chat with actual LLM responses still needs a screen-recorded UX pass when usage/permissions allow.

## For next run
- If cloud: continue coach validation harness and transfer-summary logic without simulator dependence.
- If local: recapture Train, run a real Ask Noum chat flow, and inspect whether follow-up chips now feel specific to the prior turn.
