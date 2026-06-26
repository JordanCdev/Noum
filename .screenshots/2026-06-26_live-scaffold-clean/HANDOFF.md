# Run: 2026-06-26 - branch:ux-overhaul - HEAD 97b5097 - live coach scaffold cleanup

## Mode
light

## Changes shipped (this run)
- Noum/AICoachChatService.swift:130 - added coach-facing reply normalization that strips visible planning labels such as Read, Move, Target, and Next rep while preserving useful bullets.
- Noum/AICoachChatService.swift:381 - added a quality-gate issue for scaffold-label replies so generated coach copy is repaired before it reaches the user.
- Noum/AskNoumStore.swift:203 - normalized live coach replies before persistence, injection, and legacy thread reload cleanup.
- Noum/LiveCoachCallView.swift:160 - live captions now use the shared live-display sanitizer.
- Noum/AskNoumView.swift:889 - Ask Noum case subtitle now reads like user-facing coaching context instead of raw case-file state.
- Noum/AskNoumView.swift:1094 - standing-plan landing copy now passes through the sanitizer before display.
- Noum/PracticeModeSelectionView.swift:66 - Train coach-pick target/focus copy now displays as plain coaching copy instead of `Target:` / `Focus:` labels.
- NoumUITests/NoumChatFlowUITests.swift:102 - UI test now waits for the coach bubble text to hydrate before asserting or screenshotting.

## Screenshots
- 01_home_top.png - Home tab top.
- 01_train_top.png - Train tab top; refreshed after removing `Target:` / `Focus:` labels.
- 01_review_top.png - Review tab top.
- 01_profile_top.png - Profile tab top.
- 01_settings_top.png - Settings tab top.
- live-caption-markdown-normalized.png - forced markdown scaffold reply in live call.
- live-caption-plain-scaffold-normalized.png - forced plain `Read:` / `Move:` scaffold reply in live call.
- typed-markdown-reply-normalized.png - forced markdown scaffold reply in Ask Noum chat.

## VISION gap
Noum needs to feel like a premium communication coach, not a visible prompt template. The old live call and some adjacent surfaces leaked internal structure labels into user-facing copy, which weakened trust and made Noum feel less human. The current pass reduces that gap for the live-call caption, Ask Noum chat, saved coach replies, standing-plan copy, and Train coach-pick copy.

## Next steps to reach desired state
1. Noum/PrimaryFocusMemory.swift - consider removing `Target:` from stored `callLandingAnchor` generation rather than only sanitizing at display time.
2. Noum/PracticeModeSelectionView.swift - consider adding a snapshot/UI assertion for the coach-pick card so `Target:` / `Focus:` does not return.
3. Noum/ReviewView.swift - the score chart is legible in the light sweep, but should still get a separate design pass if graph appeal remains a product concern.

## Regressions checked
- Live call markdown scaffold - live-caption-markdown-normalized.png - no raw markdown or `Read:` / `Move:` labels visible.
- Live call plain scaffold - live-caption-plain-scaffold-normalized.png - no `Read:` / `Move:` labels visible.
- Ask Noum forced markdown reply - typed-markdown-reply-normalized.png - no `Target:` / `Next rep:` labels visible.
- Train coach pick - 01_train_top.png - target/focus copy no longer exposes `Target:` / `Focus:`.
- Five tab top sweep - home, train, review, profile, settings all rendered the expected screen.

## Surfaces needing visual verification (cloud -> local queue)
- Detailed screenshot tour was not run; in-rep dynamic states, paywall, friend leaderboard, and invite QR remain outside this light sweep.
- Detailed practice-mode setup screens should be recaptured after the broader impromptu/settings redesign is complete.

## For next run
- If cloud: continue logic/tests around coach response quality and case-file memory without simulator dependencies.
- If local: run the detailed `ScreenshotTour` after the remaining UI work settles.
