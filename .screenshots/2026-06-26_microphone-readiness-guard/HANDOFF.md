# Run: 2026-06-26 · branch:ux-overhaul · HEAD 2dc0f5d · microphone readiness guard

## Mode
light

## Changes shipped (this run)
- `Noum/SpeechRecognizerViewModel.swift:13` — added an explicit microphone permission state with blocking/recovery semantics.
- `Noum/SpeechRecognizerViewModel.swift:241` — exposed an async practice permission request instead of fire-and-forget console logging.
- `Noum/TimedPracticeView.swift:1066` — added a quiet setup readiness card for undetermined, denied, and unavailable microphone states.
- `Noum/TimedPracticeView.swift:1148` — added an in-rep recovery card when recording cannot start.
- `Noum/TimedPracticeView.swift:2590` — preflights microphone access before the Timed/Impromptu countdown begins.
- `NoumTests/PracticeMicrophonePermissionStateTests.swift:13` — added focused tests for the permission-state contract.

## Screenshots
- `01_home_top.png` — Home tab, top of view; rendered correctly.
- `01_train_top.png` — Train tab; rendered correctly and shows the simplified Begin / Adjust this rep entry.
- `01_review_top.png` — Review tab; rendered correctly. Note: top-level deep link showed a `Done` pill, worth later checking against intended navigation context.
- `01_profile_top.png` — Profile tab; rendered correctly.
- `01_settings_top.png` — not captured. CoreSimulator escalation budget stopped on the final Settings launch.

## VISION gap
Noum needs to feel trustworthy before it can replace a paid coach. A first rep that appears to record while the microphone is blocked breaks that trust and can produce fake progress. This change keeps the first-value loop honest: the user is asked or guided before the rep starts, and recording failures are surfaced with a recovery path.

## Next steps to reach desired state
1. Add a simulator/UI-test hook for denied microphone permission so the readiness card and recovery card can be captured deterministically.
2. Re-run light screenshots once CoreSimulator access is available and include Settings.
3. Consider sharing the same explicit microphone recovery surface with Ah-Counter, Sudden Death, and Lesson recording flows.

## Regressions checked
- Home launch — `01_home_top.png` — no blank/splash regression.
- Train launch — `01_train_top.png` — no blank/splash regression.
- Review launch — `01_review_top.png` — no blank/splash regression; `Done` pill noted.
- Profile launch — `01_profile_top.png` — no blank/splash regression.

## Surfaces needing visual verification
- Timed/Impromptu mic-denied setup readiness card.
- Timed/Impromptu recording failure recovery card.
- Settings tab top screenshot.

## For next run
- If cloud: continue pure logic/tests around microphone state sharing across practice modes.
- If local: reset/deny microphone permission on the simulator, capture Timed setup/recovery states, and finish the missing Settings screenshot.
