# Run: 2026-05-27 - branch:Redesign - HEAD 8b81f40 - commit Sudden Death coaching progress before replay

## Mode
off - no screenshots were captured. The live toggle at `.agents/skills/noum-screenshots/.mode` is `off`; the skill's documented `.Codex` toggle path is not present.

## Changes Shipped (This Run)
- `Noum/SuddenDeathPracticeView.swift:1136` - a finished pressure run now commits XP, trends, achievements, and coaching-memory finalization before either replay or Coach Read, with a one-time guard.
- `Noum/PracticeSupport.swift:80` and `Noum/SummaryView.swift:2559` - Coach Read receives the already-committed result for rendering and cannot award the same Sudden Death run a second time.
- `Noum/SummaryView.swift:2559` - summary-owned mode finalization now passes its available spoken transcript into eloquence analysis.
- `Noum/TimedPracticeView.swift:2494`, `Noum/AhCounterView.swift:630`, and `Noum/IMPracticeView.swift:1360` - existing summary payload callers opt into the expanded contract without changing lifecycle ownership.

## Screenshots
- None generated in this run because capture mode is `off`.

## VISION Gap
This closes a pressure-mode trust gap: tapping `Go Again` no longer silently discards durable progress or coaching adaptation from a completed run. Noum is still short of human-coach parity because skill milestone presentation is not yet native to the replay loop, and delivery/real-world transfer evidence remains incomplete.

## Next Steps To Reach Desired State
1. Surface per-run skill or tier milestones within the Sudden Death result loop without forcing entry to `SummaryView`.
2. Add integration coverage asserting that `Go Again` commits progression and coach memory once, while subsequent Coach Read navigation does not reapply effects.
3. Continue the persistent case-file and intervention-cycle work described in `docs/VISION.md`.

## Regressions Checked
- iOS Simulator app build - succeeded using `xcodebuild -project Noum.xcodeproj -scheme Noum -sdk iphonesimulator -configuration Debug -derivedDataPath /private/tmp/NoumDerivedData CODE_SIGNING_ALLOWED=NO build`.
- Focused pressure tests - passed: `PressureSessionTotalsTests`, `PressureSessionTranscriptLogTests`, and `PressureSessionResultTests`.
- Visual sweep - intentionally skipped because screenshot mode is `off`.

## Surfaces Needing Visual Verification
- A real Sudden Death rep followed by `Go Again`, confirming earned state persists without showing a duplicate celebration later.
- A separate completed rep followed by Coach Read, confirming finalization is rendered without duplicate XP or coaching-memory effects.

## For Next Run
- **If cloud**: add testable completion-policy coverage for idempotent progression and memory finalization.
- **If local**: enable a targeted capture and microphone pass for replay and Coach Read once the result-loop milestone treatment is decided.
