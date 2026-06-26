# Ask Noum Typed Polish — 2026-06-26

## Scope

- Polished the typed Ask Noum current-focus strip so it reads as coach-facing context (`Target:`, `Focus:`, `Drill:`) instead of raw state copy such as `Working on ...`.
- Allowed the current-focus strip to wrap to two lines so the user's active goal does not truncate awkwardly.
- Added typed Ask Noum to `ScreenshotTour.testCaptureAdvancementSurfaces` with a deterministic formatted coach reply.
- Replaced Settings' generic profile waveform mark with the existing voice-target icon when the user has a chosen voice.
- Added a compact Profile evidence-row entry for the existing Baseline map so the radar/progress/goal-gap surface is discoverable without expanding a generic evidence disclosure first.

## Product goal

Ask Noum is a core proof point for the "expert coach" claim. The typed thread should feel concise, human, and grounded in the user's actual coaching case without exposing implementation language.

## Evidence

- Fresh screenshot: `25d-ask-noum-typed.png`
- Fresh screenshot: `settings-profile-voice-icon.png`
- Fresh screenshot: `profile-baseline-map.png`
- Unit test: `NoumTests/NoumTests/AskNoumVoiceFirstDefaultTests`
- Unit test: `NoumTests/NoumTests/ProfileCollapseContractTests`
- UI regression: `NoumUITests/NoumChatFlowUITests/testMarkdownReplyRendersWithoutRawFormattingMarkers`
- UI regression: `NoumUITests/NoumUITests/testHomeScreenAndPrimaryNavigation`
- UI screenshot: `NoumUITests/ScreenshotTour/testCaptureProfileBaselineMapOnly`
- Detailed screenshot tour: `NoumUITests/ScreenshotTour/testCaptureAdvancementSurfaces`

## Notes

- No new state owner was introduced. The strip still reads the existing `CoachCaseFile` through `CoachMemoryStore`.
- The screenshot tour now captures 28 attachments, including the typed Ask Noum surface.
- Settings reuses `VoiceGoalIcon` / `SpeakingStyleGoal.voiceIconSystemName`; there is no duplicate icon mapping.
- The baseline evidence row only reveals existing evidence; `BaselineCoachMap` remains the single source for formation progress, radar reads, goal gap, and signup motivation.
