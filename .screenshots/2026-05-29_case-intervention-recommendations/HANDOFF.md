# Run: 2026-05-29 · branch:Redesign · HEAD 671489d · case-file intervention recommendations

## Mode
off

## Changes shipped (this run)
- Noum/PracticeSupport.swift:7096 — added `RecommendationBlueprintSource` so recommendation surfaces know when a case-file intervention won precedence.
- Noum/PracticeSupport.swift:7260 — `RecommendationBiasEngine.blueprint` now accepts `CoachMemory` and keeps active interventions in rotation while evidence is awaiting/forming/verification.
- Noum/ContentView.swift:68 — Home reads `CoachMemoryStore` and bypasses stale AI recommendation copy while the case-file intervention is active.
- Noum/HomeCoachCard.swift:30 — Home coach card reads the same case-file recommendation source and names the active case in its headline/subtitle.
- Noum/PracticeModeSelectionView.swift:64 — mode picker recommendations now read the same case-file intervention source.
- Noum/SummaryView.swift:69 — post-rep Looking Ahead recommendations now read the case file and can show a same-mode continuation when it is the active intervention.
- Noum/CaseReviewCard.swift:61 — Profile case review card now surfaces the latest real-world transfer check-in when present.
- NoumTests/NoumTests.swift:15122 — added recommendation tests for intervention continuation, criterion fallback, and stopping when adaptation is required.

## Screenshots
- Screenshots mode is `off`; no PNGs captured.

## VISION gap
This closes part of the “persistent Coaching Case File and Intervention Cycle” gap in docs/VISION.md: the app now lets the durable case file steer the next recommendation across Home, Summary, and the mode picker instead of treating the latest metrics as a fresh stateless suggestion. It does not yet let users confirm/reject the working hypothesis, and it still lacks deeper delivery sensing such as prosody, pause quality, posture, and vocal authority.

## Next steps to reach desired state
1. Noum/SummaryView.swift — add a concise intervention-review prompt when `CoachIntervention.reviewDueAt` is due and minimum followed reps are met.
2. Noum/AskNoumView.swift — add a direct “review this case” starter that asks the coach to reassess the active hypothesis, drill, success criterion, and latest transfer check-in.
3. Noum/PrimaryFocusMemory.swift — record user confirmation/rejection of the current hypothesis so case confidence can move on more than practice metrics alone.

## Regressions checked
- Recommendation engine and router — `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' -derivedDataPath /private/tmp/NoumDerivedDataCaseCycle CODE_SIGNING_ALLOWED=NO -only-testing:NoumTests/IMToneDrillSignalTests -only-testing:NoumTests/SummaryLookingAheadRouterTests` — passed.
- Whitespace hygiene — `git diff --check` — passed.

## Surfaces needing visual verification (cloud → local queue)
- Home coach card when an active case intervention exists.
- Practice mode picker recommendation row when an active case intervention exists.
- Summary Looking Ahead card when the recommended mode matches the completed mode because the case file wants another followed rep.
- Profile `Your Coach's Read` card with a `lastTransferReview`.

## For next run
- **If cloud**: continue pure state/engine work around intervention review prompts and Ask Noum case-review context.
- **If local**: switch screenshots mode to `light` or `detailed`, seed an active `CoachMemory.activeIntervention`, and capture Home, Train, Summary, and Profile case-file states.
