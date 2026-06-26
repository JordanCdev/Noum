# Run: 2026-06-25 · branch:ux-overhaul · HEAD a93a071 · Weekly check-in confidence + avoidance signals

## Mode
light

## Changes shipped (this run)
- `Noum/CoachCheckInStore.swift:51` — added `CoachConfidenceShift` and optional `confidenceShift` / `avoidedSaying` fields to the existing weekly check-in model.
- `Noum/CoachCheckInStore.swift:126` — weekly check-in coach-context lines now carry confidence and avoidance as explicitly user-reported evidence.
- `Noum/WeeklyCheckInCard.swift:47` — tightened the Profile card copy around human-coach signals: hard moment, avoidance, confidence.
- `Noum/WeeklyCheckInCard.swift:101` — added an optional confidence picker and avoidance field to the existing weekly check-in sheet.
- `Noum/WeeklyCheckInCard.swift:174` — reused the existing `FlowLayout` chip pattern so longer option labels wrap cleanly on small phones.
- `ProfileView.swift:76` — restored `.weeklyCheckIn` to the active Profile coaching-evidence plan so the card is reachable when due.
- `Noum/NoumApp.swift:88` — added `FORCE_WEEKLY_CHECKIN` debug launch state for deterministic UI capture only.
- `NoumUITests/ScreenshotTour.swift:271` — added focused screenshot coverage for the weekly check-in sheet.
- `Noum/CoachContextBuilder.swift:436` — added a pure weekly check-in question selector so Ask Noum gets one context-aware human-coach question instead of a generic category list.
- `Noum/CoachContextBuilder.swift:657` — the Ask Noum context/check-in opportunity now asks at most one concise weekly question and labels any answer as user-reported evidence.
- `NoumTests/NoumTests.swift:7629` — pinned weekly check-in inside the coach-evidence cluster, after readiness and before case review.
- `NoumTests/NoumTests.swift:21001` — covered confidence + avoidance flowing into coach context, plus missed/stalled drill priority, avoidance, confidence, and selected-question context wiring.
- `NoumTests/NoumTests.swift:34472` — covered user-reported/non-diagnostic context lines, persistence, trimming, and legacy decode.

## Screenshots
- `01_home_top.png` — Home tab, top of view.
- `01_train_top.png` — Train tab, top of view.
- `01_review_top.png` — Review tab, top of view.
- `01_profile_top.png` — Profile tab, top of view.
- `01_settings_top.png` — Settings tab, top of view.
- `profile-weekly-check-in-sheet.png` — forced due weekly check-in sheet via `ScreenshotTour.testCaptureWeeklyCheckInSheetOnly`.

## VISION gap
VISION calls out that a strong coach asks what felt difficult, where confidence changed, what the user avoided, and whether the work transferred outside the app. Noum already had the weekly check-in owner and cadence; this run deepened that same owner with two missing subjective signals and taught the chat context to suggest one sharper follow-up instead of leaving the model to juggle a list.

## Next steps to reach desired state
1. Consider a future case-file summarizer that strengthens confidence/avoidance patterns only after repeated user confirmation.
2. Add smallest-viewport sheet capture if the supported-device matrix narrows below iPhone 17 proportions.

## Regressions checked
- Focused unit tests — `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=3D077053-2981-4C5D-819D-FF6F9BA8AD06' -configuration Debug -derivedDataPath .derived-data -only-testing:NoumTests/ProfileCollapseContractTests -only-testing:NoumTests/CoachCheckInStoreTests -only-testing:NoumTests/CoachContextBuilderWeeklyCheckInOpportunityTests` — passed.
- Focused follow-up selector tests — `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=3D077053-2981-4C5D-819D-FF6F9BA8AD06' -configuration Debug -derivedDataPath .derived-data -only-testing:NoumTests/CoachContextBuilderWeeklyCheckInOpportunityTests` — passed.
- Focused UI screenshot test — `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=3D077053-2981-4C5D-819D-FF6F9BA8AD06' -configuration Debug -derivedDataPath .derived-data -only-testing:NoumUITests/ScreenshotTour/testCaptureWeeklyCheckInSheetOnly -resultBundlePath /tmp/noum-weekly-checkin-sheet.xcresult` — passed.
- Profile top — `01_profile_top.png` — rendered the Profile screen without crash or deep-link failure.
- Settings top — `01_settings_top.png` — rendered the Settings screen without crash or deep-link failure.
- Weekly check-in sheet — `profile-weekly-check-in-sheet.png` — rendered full sheet, optional fields, confidence chips, avoidance field, and drill verdict chips without overlap.

## Surfaces needing visual verification
- Smallest supported iPhone viewport for the weekly check-in sheet. iPhone 17 capture is clean; a smaller-width capture would be a useful extra before a broad TestFlight UI sweep.

## For next run
- **If cloud**: continue logic or copy work that does not need Simulator.
- **If local**: capture the weekly check-in sheet on the smallest supported viewport and run the detailed tour after the next UI batch.
