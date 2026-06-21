# Run: 2026-06-21 - branch:ux-overhaul - HEAD de38004 - Ask Noum chat style

## Mode
light

## Changes shipped (this run)
- Noum/CoachContextBuilder.swift:101 - Prompt now allows rare useful emoji and compact Markdown formatting while keeping trust, evidence, and brevity constraints.
- Noum/CoachContextBuilder.swift:110 - Text replies default to 1-4 short lines, usually under 75 words, with bold lead-ins, short bullets, or numbered steps only when useful.
- Noum/AICoachChatService.swift:666 - Quality gate now caps normal replies by characters, sentences, words, and non-empty lines so formatted replies stay concise.
- Noum/AskNoumView.swift:58 - Added a small Markdown formatter for coach replies: paragraphs, bullets, numbered steps, and `**bold**` inline segments.
- Noum/AskNoumView.swift:207 - Coach message renderer uses the Figtree display family from the rating-card system for replies, while preserving bold emphasis, bullets, numbered rows, and accent markers.
- Noum/AskNoumView.swift:2151 - Coach bubble restyled into a full-width calm card with a quiet left rail instead of repeated per-message orb noise.
- Noum/AskNoumView.swift:2224 - Hydrated coach replies now fall back to full text if reveal state is armed with an empty prefix, preventing blank reply cards.
- Noum/AskNoumView.swift:2637 - Typed send now dismisses composer focus so the answer has room to land.
- NoumUITests/NoumChatFlowUITests.swift:49 - UI test counts coach bubbles by any accessibility element because the redesigned bubble owns the accessibility label.
- NoumUITests/NoumChatFlowUITests.swift:93 - UI test waits briefly before its screenshot so the word-reveal has painted visible text.
- NoumTests/NoumTests.swift:8410 - Unit tests cover paragraph, bullet, numbered, bold, and heading-stripping formatting behavior.

## Screenshots
- 01_home_top.png - Home tab top, rendered correctly.
- 01_train_top.png - Train tab top, rendered correctly.
- 01_review_top.png - Review tab top, rendered correctly.
- 01_profile_top.png - Profile tab top, rendered correctly.
- 01_settings_top.png - Settings tab top, rendered correctly.
- typed-turn-resolved.png - Ask Noum typed message -> coach reply -> Figtree-formatted bubble + Next Move.

## VISION gap
The chat is now more readable and coach-like, with Figtree extending the premium rating-card voice into Noum replies. The Ask Noum surface still has remnants of the older generic voice/orb identity in the header and typing state; the larger product identity pass should still decide whether the header avatar should become a more human, target-specific mark.

## Next steps to reach desired state
1. Noum/AskNoumView.swift - Consider a dedicated Ask Noum header identity that aligns with saved voice-target icons instead of the generic waveform orb.
2. Noum/AICoachChatService.swift - Add a snapshot-style fixture for one live formatted reply so prompt regressions are easier to spot without waiting on a provider.

## Regressions checked
- Ask Noum typed chat - typed-turn-resolved.png - Send resolves to a live/offline coach bubble, text is visible, formatted, and Next Move remains reachable.
- Home tab - 01_home_top.png - no blank or wrong deep link.
- Train tab - 01_train_top.png - no blank or wrong deep link.
- Review tab - 01_review_top.png - no blank or wrong deep link.
- Profile tab - 01_profile_top.png - no blank or wrong deep link.
- Settings tab - 01_settings_top.png - no blank or wrong deep link.

## Surfaces needing visual verification (cloud -> local queue)
- None from this run.

## For next run
- If cloud: work on prompt/formatter tests only; simulator screenshots are already captured locally.
- If local: rerun `NoumUITests/NoumChatFlowUITests/testTypedTurnResolvesToACoachReply` after any chat UI or reply animation change.
