# Run: 2026-06-06 · branch:Redesign · HEAD 460aa27 · Ask Noum header cleanup + mic retry

## Mode
off (screenshot mode file missing)

## Changes shipped (this run)
- `Noum/AskNoumView.swift` — collapsed Ask Noum header actions into one chat-options menu; removed misleading visible "Live" pill and separate spoken-replies micro-toggle.
- `Noum/AskNoumView.swift` — voice-first transcripts now submit as a user turn after recording stops; typed fallback still behaves like editable dictation.
- `Noum/AskNoumVoiceInput.swift` — transient recognizer/audio failures remain retryable, invalid simulator input formats fail softly, and start failures reset to idle.
- `NoumTests/NoumTests.swift` — added retry-gate coverage and updated voice-first status expectations.

## Screenshots
- No PNGs captured. The screenshot mode file `.Codex/skills/noum-screenshots/.mode` was missing, so capture was treated as off.

## VISION gap
Ask Noum should feel like a professional coach conversation, not a control-heavy AI wrapper. This run reduces visual chrome and fixes a voice-first friction point, but it still needs live visual QA on-device/simulator to confirm the new header and input states feel premium.

## Next steps to reach desired state
1. Recreate/configure the screenshot mode file, then capture Ask Noum specifically in empty-thread, active-thread, voice-first idle, recording, retry-notice, and spoken-reply-enabled states.
2. Verify real mic capture on a physical device; simulator audio start failures can be host-device issues even when app retry handling is correct.

## Regressions checked
- Ask Noum focused tests — `xcodebuild test -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:NoumTests/AskNoumVoiceInputNoticeTests -only-testing:NoumTests/AskNoumVoiceFirstDefaultTests` — passed.
- App build — `xcodebuild build -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17'` — passed.

## Surfaces needing visual verification
- Ask Noum header after menu consolidation.
- Ask Noum voice-first bar after auto-send behavior.
- Mic retry notice on simulator audio failure.

## For next run
- **If cloud**: continue pure logic/copy work only.
- **If local**: restore screenshot mode, capture Ask Noum states, and test mic on a physical device.
