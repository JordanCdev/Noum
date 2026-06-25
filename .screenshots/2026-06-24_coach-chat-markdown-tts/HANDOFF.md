# Run: 2026-06-24 · branch:ux-overhaul · HEAD 46b92d5 · coach chat markdown and TTS cleanup

## Mode
light

## Changes shipped (this run)
- `Noum/AICoachChatService.swift` — normalizes provider replies before quality gating, storage, and speech; adds debug logging around provider choice, normalization, repair, and failure causes.
- `Noum/AskNoumStore.swift` — stores sanitized coach replies, cleans legacy persisted markdown rows on load, and replaces the cold "clearer sentence" rejection notice with a non-blaming coach-system notice.
- `Noum/AskNoumView.swift` — renders plain lead-ins as strong text without requiring raw `**`, and routes spoken replies through the sanitizer before TTS.
- `Noum/LiveCoachCallView.swift` — sanitizes coach captions so legacy `**Read:**` / `**Move:**` rows cannot appear in the live call.
- `Noum/CoachContextBuilder.swift` — updates coach-chat prompt contracts to avoid literal Markdown markers and robotic fixed labels by default.
- `Noum/CoachReplyPipeline.swift` — logs chat context assembly and reply/failure outcomes.
- `NoumUITests/NoumChatFlowUITests.swift` — adds a deterministic simulator regression proving a markdown-heavy provider reply renders without raw formatting markers.
- `NoumTests/CoachProviderChainTests.swift` — adds a provider-chain regression proving a rejected robotic draft + failed repair falls back to a trust-repair reply for user critique instead of the cold notice.
- `NoumTests/NoumTests.swift` — adds/updates sanitizer, spoken TTS, store persistence, prompt, formatter, and quality-gate tests.

## Screenshots
- `01_home_top.png` — Home surface after fresh install/deep link.
- `01_train_top.png` — Train / next-rep surface.
- `01_review_top.png` — Review trend surface.
- `01_profile_top.png` — Profile / coaching read surface.
- `01_settings_top.png` — Settings surface.
- Exact Ask Noum markdown regression screenshot is stored in the `NoumChatFlowUITests.testMarkdownReplyRendersWithoutRawFormattingMarkers` xcresult attachment, not in this light sweep.

## VISION gap
The pass closes a trust-breaking presentation bug: raw AI scaffolding was leaking into UI and TTS, making Noum feel like an exposed prompt rather than a coach. It also improves the cold failure path so user critique is treated as a repair moment instead of blaming the user for unclear input.

This does not complete human-coach parity. The deeper gap remains longitudinal calibration against expert coach judgment, stronger real-world transfer evidence, and richer delivery sensing beyond text/pace/filler signals.

## Next steps to reach desired state
1. Add an evaluation fixture that scores frustrated-user repair turns against the expert baseline in `NoumTests/CoachChatEvaluationFixtures.swift`.
2. Run a full detailed screenshot tour after the next broader UI pass, because this run only needed the light visual handoff plus the focused chat UI regression.

## Regressions checked
- Typed Ask Noum turn with forced markdown provider reply — UI test passed; rendered/accessibility labels contain no raw `**`.
- Live-call coach caption with forced markdown reply — UI test passed; rendered/accessibility labels contain no raw `**`.
- TTS text path — focused unit tests passed; `spokenTextNeverReadsMarkdownOrScaffoldLabels` covers stripped speech output.
- Store persistence — focused unit tests passed; legacy markdown rows are normalized before persistence/reload.
- Prompt contract — focused unit tests passed; system prompt forbids literal Markdown markers because UI and TTS share text.
- Provider rejection path — focused unit test passed; bad provider draft + bad repair draft now logs the rejection path and returns a trust-repair reply for explicit user critique.
- Five top-level visual surfaces — light screenshots captured and manually inspected; no blank/splash captures.

## Surfaces needing visual verification
- A real-device TTS listen-through remains useful, because simulator tests prove the spoken string but not the acoustic output.

## For next run
- If cloud: extend the coach-chat evaluation corpus and static prompt tests.
- If local: add the live-call forced-caption route, run its UI test, then capture a focused Ask Noum screenshot alongside the standard light sweep.
