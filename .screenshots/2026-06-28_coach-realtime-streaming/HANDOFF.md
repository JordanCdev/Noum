# Run: 2026-06-28 · branch:ux-overhaul · HEAD 1e5463a4 · coach realtime streaming

## Mode
light

## Changes shipped (this run)
- Noum/AICoachChatService.swift:74 — added a guarded provider partial gate so streamed provider chunks only become visible after a complete, sanitized, substantial first sentence.
- Noum/AICoachChatService.swift:737 — added provider streaming endpoint resolution for Google Cloud/Gemini/Claude/shared providers.
- Noum/CoachReplyPipeline.swift:246 — routes guarded provider partials into the existing pending coach row with turn metadata.
- NoumTests/CoachJudgementLayerTests.swift:101 — added focused tests for sentence-boundary waiting, scaffold stripping, and short interjection handling.

## Screenshots
- 01_home_top.png — Home surface rendered; includes Ask Noum entry and bottom navigation.
- 01_train_top.png — Train deep link rendered current "Your next rep" surface, not the full mode picker root.
- 01_review_top.png — Review surface rendered with progress/evidence cards; captured with back/done chrome from current navigation state.
- 01_profile_top.png — Profile surface rendered with speaking rating and coach read.
- 01_settings_top.png — Settings deep link rendered the practice defaults/settings surface.

## VISION gap
Noum's chat/live coaching path is now closer to the target "expert coach at your fingertips" latency posture: local reads appear immediately and provider streaming now records first-token timing. Visual proof is still limited to tab/deep-link tops; live-call in-rep states such as Thinking, Speaking, and Summary need dedicated hooks before they can be visually regression-checked.

## Next steps to reach desired state
1. Extend NoumUITests/ScreenshotTour.swift with live-call test hooks for pending coach read, provider-streaming partial, final caption, and reduced-motion states.
2. Capture an Ask Noum thread fixture showing a deep-assessment pending row transitioning from local read to streamed provider partial to final accepted reply.
3. Add a top-level tab reset/deep-link check so light screenshots consistently land on root tab surfaces.

## Regressions checked
- Home — 01_home_top.png — nonblank, premium surface still renders with Ask Noum entry.
- Train — 01_train_top.png — nonblank practice recommendation surface renders; root tab exactness still needs cleanup.
- Review — 01_review_top.png — progress/evidence copy remains visible and not overlapping.
- Profile — 01_profile_top.png — rating and coach read remain visible and readable.
- Settings — 01_settings_top.png — practice defaults controls remain visible and readable.
- Live external provider eval — DerivedData/Noum/noum-live-coach-eval.md — 3/3 fixtures passed professional-coach and semantic gates.

## Surfaces needing visual verification (cloud → local queue)
- LiveCoachCallView in-rep dynamic states: listening, thinking, local provisional read speaking, streamed provider partial visible, final caption.
- AskNoumView text thread pending row with provider partial streaming.
- Reduced-motion variants for live-call caption/provisional read transitions.

## For next run
- **If cloud**: continue pure logic/test work around semantic gates and streaming accumulators.
- **If local**: add richer screenshot tour hooks for live-call and Ask Noum streaming transitions, then rerun detailed mode.
