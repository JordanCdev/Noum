# Run: 2026-06-26 · branch:ux-overhaul · HEAD 97b5097 · live-call scaffold caption fix

## Mode
light

## Changes shipped (this run)
- `Noum/LiveCoachCallView.swift` — live-call captions now use the strict `CoachReplyTextSanitizer.liveDisplayText(from:)` path and include a DEBUG fixture for the exact plain `Read:` / `Move:` leak.
- `Noum/AICoachChatService.swift` — shared sanitizer has a live-display mode that strips coach scaffold labels while preserving the useful coaching content.
- `NoumTests/NoumTests.swift` — added pure sanitizer coverage for plain live-call scaffold labels.
- `NoumUITests/NoumChatFlowUITests.swift` — added simulator coverage for the owner-visible plain-label live-call caption regression.

## Screenshots
- `01_home_top.png` — Home tab rendered correctly.
- `01_train_top.png` — Train tab rendered correctly; pre-existing copy artifact noted: target/focus is compressed into one line.
- `01_review_top.png` — Review tab rendered correctly.
- `01_profile_top.png` — Profile tab rendered correctly.
- `01_settings_top.png` — Settings tab rendered correctly.

## VISION gap
Noum's live coach must feel like a human coach, not a visible prompt scaffold. The live-call surface now strips template labels from the caption and spoken path, so the user hears and sees the coaching move rather than the model's internal shape.

## Next steps to reach desired state
1. `Noum/CoachContextBuilder.swift` — continue discouraging scaffold-style reply formats at prompt level so the sanitizer remains a backstop, not the main product experience.
2. `Noum/PracticeModeSelectionView.swift` or related Train card owner — revisit the compressed `Target: ... · Focus: ...` line seen in the light sweep.

## Regressions checked
- Live-call markdown caption fixture — `NoumUITests/NoumChatFlowUITests/testLiveCallCaptionRendersWithoutRawFormattingMarkers` — passed.
- Live-call plain scaffold fixture — `NoumUITests/NoumChatFlowUITests/testLiveCallCaptionStripsPlainScaffoldLabels` — passed.
- Shared text sanitizer — `NoumTests/CoachReplyTextSanitizerTests` — 10 tests passed.
- Light screenshot sweep — Home, Train, Review, Profile, Settings rendered expected top-level screens.

## Surfaces needing visual verification
- Real microphone/TTS live-call loop with a model-produced reply on device; automated coverage uses seeded caption fixtures because simulator microphone input is not reliable.

## For next run
- If cloud: continue prompt/quality-gate work around natural coach replies without simulator dependencies.
- If local: run one real live-call turn after rebuilding on the simulator/device and confirm the visible caption stays label-free with a live Gemini reply.
