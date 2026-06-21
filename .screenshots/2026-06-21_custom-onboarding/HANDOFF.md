# Run: 2026-06-21 - branch:ux-overhaul - HEAD d4f2582 - Custom onboarding challenge

## Mode
focused UI test capture

## Changes shipped (this run)
- Noum/CoachingOnboardingView.swift - Growth-area setup now includes a "Something else" option with inline user input and Next gating.
- Noum/PracticeSupport.swift - `CoachingProfile` now persists optional custom challenge wording while keeping `SpeakingChallenge` as the stable routing bucket.
- Noum/CoachContextBuilder.swift - Ask Noum context reads custom challenge wording when present and names the nearest starting bucket for routing honesty.
- Noum/GoalParaphraseService.swift - Onboarding goal paraphrase input now uses the custom challenge label when present.
- Noum/SettingsView.swift - Coaching profile settings display custom challenge wording instead of forcing the preset label.
- NoumTests/NoumTests.swift - Unit coverage pins custom challenge persistence, blank fallback, and routing buckets.
- NoumUITests/NoumUITests.swift - UI coverage exercises the "Something else" setup path and keeps a summary screenshot.

## Screenshots
- onboarding-custom-challenge-summary.png - First-run setup completed via "Something else"; summary shows "I sound defensive when challenged" as Biggest challenge.

## VISION gap
The setup flow now feels less taxonomic and more coach-like: the user can name their real problem in their own words. The engine still routes through four canonical buckets, so a future deeper personalization pass could replace keyword fallback with a richer, inspectable classification step.

## Next steps to reach desired state
1. Noum/CoachingOnboardingView.swift - Consider applying the same "Something else" pattern to the context step if early users report that work/interview/presentation/social is too narrow.
2. Noum/PracticeSupport.swift - If custom challenge usage grows, add an explicit reviewed classification field instead of relying on deterministic keyword routing.

## Regressions checked
- Custom setup path - onboarding-custom-challenge-summary.png - user-entered challenge persists into the summary.
- Existing preset setup path - covered by existing `testOnboardingFlowSmoke` helper shape; preset option identifiers are unchanged.

## Surfaces needing visual verification (cloud -> local queue)
- None from this run.

## For next run
- If cloud: focus on copy/schema tests; simulator screenshot already captured locally.
- If local: rerun `NoumUITests/NoumUITests/testOnboardingCustomChallengePath` after any setup-card layout changes.
