# Screenshot Handoff: Transfer Debrief + Current Case Strip

- Date: 2026-06-21
- Mode: light
- Branch: ux-overhaul
- Commit at capture: e386a5e
- Simulator: iPhone 17

## Scope Captured

- Post-transfer outcome acknowledgement now reads as a short coaching debrief instead of a thin acknowledgement.
- Ask Noum empty state now surfaces the current case landing anchor when a standing plan exists.
- Top-level app routes were smoke-captured after installing the fresh local build.

## Product Goal

Close the felt loop between preparation, transfer, debrief, and the next coaching move. The app should feel less like a collection of features and more like a coach that remembers the user's current case and reviews real-world attempts with restraint.

## Screenshots

- `01_home_top.png`
- `02_train_top.png`
- `03_review_top.png`
- `04_profile_top.png`
- `05_settings_top.png`

## Visual Verification

- Home: readable top-level experience, visible Ask Noum entry, no blank state or clipping.
- Train: coach-pick rationale wraps cleanly; route opens the next-rep picker state.
- Review: chart and coach-read hierarchy remain readable; route opens a modal-style Review state with Back/Done controls.
- Profile: top card, rating card, and coach card are visible with acceptable wrapping.
- Settings: practice controls and toggles are visible and aligned.

No screenshot in this light pass showed a blank route, obvious overlap, or an app crash.

## Functional Verification

Focused tests passed:

```sh
xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:NoumTests/BigMomentTransferStoreTests \
  -only-testing:NoumTests/BigMomentTransferEnrichmentTests \
  -only-testing:NoumTests/BigMomentOutcomeAckTests \
  -only-testing:NoumTests/BigMomentOutcomeAckTransientTests \
  -only-testing:NoumTests/AskNoumVoiceFirstDefaultTests \
  -derivedDataPath .build/transfer-debrief-test
```

Result: `** TEST SUCCEEDED **`

Earlier coach-quality focused suite also passed:

```sh
xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:NoumTests/AICoachChatReplyQualityGateTests \
  -only-testing:NoumTests/CoachChatEvaluationFixtureTests \
  -only-testing:NoumTests/AICoachChatDeterministicReplyTests \
  -only-testing:NoumTests/ForwardPlanServiceDeterministicTests \
  -only-testing:NoumTests/CoachingPlanCardVisibilityTests \
  -derivedDataPath .build/coach-quality-test
```

Result: `** TEST SUCCEEDED **`

After the final UI-guidance cleanup, the focused Ask Noum suite was rerun:

```sh
xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:NoumTests/AskNoumVoiceFirstDefaultTests \
  -derivedDataPath .build/transfer-debrief-test
```

Result: `** TEST SUCCEEDED **`

## Notes

- The light screenshot route behavior for Train, Review, and Settings enters existing nested/modal states. This was observed and documented, but not treated as a regression from this pass.
- Expert-coach parity is improved but not proven by code/tests alone. True parity still needs rubric-based human review against expert coach transcripts and real user outcomes.

## Suggested Next Pass

- Run a detailed seeded scenario tour that exercises Ask Noum with a standing case file visible in the empty state.
- Add a UI test around post-transfer acknowledgement copy if the underlying Big Moment outcome flow has stable navigation hooks.
- Continue the roadmap-gated first-run work only after the planned IA/spec review, since onboarding changes have larger product-risk surface.
