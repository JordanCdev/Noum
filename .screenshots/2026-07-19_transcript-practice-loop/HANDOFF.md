# Run: 2026-07-19 · branch:codex/product-journey-launch · source fe0498e29 · transcript practice loop

## Mode

light

## Changes shipped (this run)

- `Noum/TranscriptPracticeLoop.swift` — source-bound one-lever retry comparison, cautious terminal outcomes, and content-free provenance.
- `Noum/SummaryView.swift` and `Noum/RewriteSuggestionCard.swift` — verified original → one-step rewrite → aspirational end state → targeted practice.
- `Noum/TimedPracticeView.swift` and `Noum/TimedPracticePromptHandoff.swift` — exact prescription consumption, retry comparison, and outcome commit.
- `Noum/FlowObservability.swift` and `Noum/SettingsView.swift` — joined coach/training trace timelines and copyable privacy-safe IDs.
- `Noum/NoumApp.swift` and `Noum/DevSeedData.swift` — deterministic fixture repair at the account-hydration boundary.

## Screenshots

- `01_home_top.png` — Home with one dominant evidence-based next step and contextual Ask Noum entry.
- `01_train_top.png` — Train with the same recommendation leading the practice library.
- `01_review_top.png` — Review with one movement story and direct latest-rep review.
- `01_profile_top.png` — Profile with voice target, rating, and current coaching focus.
- `01_settings_top.png` — Settings practice controls.
- `transcript-ladder.png` — achievable rung, labelled aspiration, retry target, and direct practice action.
- `transcript-ladder-retry-comparison.png` — exact retry comparison, cautious evidence language, adaptation, and next intervention.

## VISION gap

The local app now renders the `SHOW → PRACTISE → COMPARE → ADAPT` segment as one joined journey and keeps Home/Train/Review/Profile aligned on the same coaching focus. The screenshots do not prove real speech recognition, physical-device audio behavior, longitudinal transfer, live-provider coaching quality, professional acceptance, or production operations.

## Next steps to reach desired state

1. Execute `docs/MANUAL_LAUNCH_ACTIONS.md` against one source-bound signed release candidate.
2. Collect live-provider, professional-coach, longitudinal real-user, physical TestFlight, and operational sign-off artifacts without substituting simulator evidence.
3. Run focused VoiceOver, largest Dynamic Type, dark mode, and Reduce Motion visual checks on the signed candidate.

## Regressions checked

- Home root — `01_home_top.png` — correct seeded next step; no bootstrap, overlay, or blank state.
- Train root — `01_train_top.png` — recommendation and library render; no wrong deep-link destination.
- Review root — `01_review_top.png` — movement story and latest-rep entry render.
- Profile root — `01_profile_top.png` — voice goal remains a target/emphasis, not identity language.
- Settings root — `01_settings_top.png` — controls render without obstruction.
- Summary ladder → Timed retry → adapted intervention — both focused attachments plus passing XCUITest; no silent route loss.

## Surfaces needing visual verification (cloud → local queue)

- Settings → Debug traces after real provider attempts and terminal failures.
- Real microphone retry with low-confidence transcription and meaning drift.
- VoiceOver, largest Dynamic Type, dark mode, and Reduce Motion across the transcript ladder and retry comparison.
- Signed physical-device audio routes, interruptions, StoreKit, widgets, Live Activities, and TestFlight install state.

## For next run

- **If cloud**: review source-bound reports and prepare redacted external-evidence packets only; do not claim hardware or live-provider proof.
- **If local**: capture the Debug trace viewer plus accessibility extremes on the exact signed candidate, then execute the physical TestFlight checklist.
