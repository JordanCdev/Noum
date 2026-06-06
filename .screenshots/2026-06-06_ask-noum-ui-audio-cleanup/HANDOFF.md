# Run: 2026-06-06 · branch:Redesign · HEAD 03f8945 · Ask Noum UI/audio cleanup

## Mode
focused local capture. `.Codex/skills/noum-screenshots/.mode` was missing, so this was not a full light/detailed sweep.

## Changes shipped (this run)
- `Noum/AskNoumView.swift:440` — simplified the Ask Noum header into one coach identity row with secondary actions in a single options menu.
- `Noum/AskNoumView.swift:1682` — replaced the large voice-first footer with a compact mic/status/preview row and a keyboard icon.
- `Noum/AskNoumView.swift:1858` — changed text input placeholder to `Message Noum...`.
- `Noum/AskNoumVoiceInput.swift:287` — moved app-side audio setup to `.allowBluetoothHFP` and the modern `AVAudioApplication.requestRecordPermission`.
- `Noum/ContentView.swift:507` and `Noum/NoumApp.swift:180` — prevented home-root Big Moment intake from stealing focus during direct deep-link routes.
- `Noum/CoachContextBuilder.swift:106` and `Noum/AICoachChatService.swift:428` — removed the exact report-like decline phrase from the coach prompt and added it to the reply-quality rejection list.

## Screenshots
- `ask_noum_type_debug_final.png` — actual Ask Noum typed chat after Debug install + `noum://ask/type`; header/input cleanup visible.
- `ask_noum_type_ui_testing.png` / `ask_noum_type_seeded.png` / `ask_noum_type_after_guard.png` — pre-fix evidence that Big Moment intake could intercept the Ask Noum deep-link path.
- `ask_noum_type_final.png` — Release build evidence that screenshot `-DeepLink` args are DEBUG-only, so Release stayed on the Train root.

## VISION gap
Ask Noum is less visually cluttered and less misleading, but it still needs a fresh-turn check after a live model response. The old persisted bubble in the captured thread shows exactly why the new phrase gate matters: future replies should be shorter and more human, but old stored messages will not rewrite themselves.

## Next steps to reach desired state
1. Run a fresh Ask Noum turn with provider access enabled and verify the reply-quality repair path rewrites report-like openings.
2. Add a small UI-test route for `noum://ask/type` that asserts the Big Moment intake sheet is absent when a direct chat route is requested.
3. Consider making screenshot mode file creation explicit so local captures do not silently fall into ad-hoc mode.

## Regressions checked
- Ask Noum typed route — `ask_noum_type_debug_final.png` — reaches chat in Debug with no Big Moment sheet.
- Ask Noum header — `ask_noum_type_debug_final.png` — visible Live/speaker clutter removed.
- Voice/text composer — `ask_noum_type_debug_final.png` — placeholder and single mic path visible.

## Surfaces needing visual verification
- Fresh generated coach reply after the prompt/quality-gate change; current screenshot contains older persisted thread content.

## For next run
- If cloud: work on deterministic tests for the direct-route Big Moment suppression.
- If local: capture a fresh Ask Noum response with provider access and compare against the old persisted wording.
