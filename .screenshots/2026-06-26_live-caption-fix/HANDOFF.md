# Run: 2026-06-26 - branch:ux-overhaul - HEAD 97b5097 - live coach caption cleanup

## Mode
light

## Changes shipped (this run)
- Noum/AICoachChatService.swift:132 - Added `CoachReplyTextSanitizer.liveDisplayText(from:)` so Live Coach captions drop markdown bullets, numbered markers, and scaffold labels such as `Read:` and `Move:`.
- Noum/LiveCoachCallView.swift:160 - Live Coach captions now use the live-display sanitizer instead of the general chat display sanitizer.
- Noum/LiveCoachCallView.swift:68 - Reduced the Live Coach visual/caption weight so the call feels less like a debug transcript card.
- Noum/CoachContextBuilder.swift:122 - Added a prompt guardrail telling the coach not to format live-call replies with `Read:`, `Move:`, `Target:`, or `Next rep:` labels.
- NoumTests/NoumTests.swift:9440 - Added unit coverage for live caption scaffold stripping.
- NoumUITests/NoumChatFlowUITests.swift:224 - Tightened the Live Coach UI test so visible captions fail if `Read:` or `Move:` leaks.

## Screenshots
- 01_home_top.png - Home top view rendered.
- 01_train_top.png - Train next-rep view rendered.
- 01_review_top.png - Review top view rendered.
- 01_profile_top.png - Profile top view rendered.
- 01_settings_top.png - Settings top view rendered.
- live_caption_normalized.png - Focused Live Coach UI-test attachment showing the corrected caption with no scaffold labels.

## VISION gap
Noum should feel like a premium communication operating system and a high-EQ coach. The previous Live Coach caption leaked internal coaching structure into a user-facing call, which made the experience feel mechanical and lower trust. This run fixes that leak for display, speech-adjacent sanitization, prompt generation, and UI regression coverage.

## Next steps to reach desired state
1. Noum/LiveCoachCallView.swift - Revisit the full Live Coach composition once the broader call interaction model settles; the caption is cleaner now, but the call surface still needs richer spoken-turn states and less static empty space.
2. Noum/CoachContextBuilder.swift - Keep hardening reply-shape contracts around mode-specific surfaces so chat, call, and practice feedback each use the right amount of structure.
3. NoumUITests/NoumChatFlowUITests.swift - Extend the focused Live Coach test to cover a live model reply path once deterministic AI-call fixtures exist.

## Regressions checked
- Live Coach caption - live_caption_normalized.png - no `Read:` or `Move:` label remains visible.
- Home - 01_home_top.png - rendered correctly after the app install.
- Train - 01_train_top.png - next-rep surface rendered correctly.
- Review - 01_review_top.png - progress surface rendered correctly.
- Profile - 01_profile_top.png - voice target and rating surface rendered correctly.
- Settings - 01_settings_top.png - practice settings surface rendered correctly.

## Surfaces needing visual verification (cloud -> local queue)
- Full manual Live Coach conversation with real microphone input.
- Long Live Coach replies that overflow the compact caption area.
- Reduced-motion Live Coach call animations.

## For next run
- If cloud: continue deterministic sanitizer and prompt-contract tests.
- If local: run the detailed screenshot tour if broader UI changes are made, and add a hand-driven Live Coach call recording pass if audio behavior changes.
