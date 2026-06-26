# Run: 2026-06-26 · branch: ux-overhaul · AI insight fallback honesty

## Mode
logic/copy audit

## Changes shipped
- `Noum/AIInsightsService.swift` now routes deterministic fallback generation through a static helper so the no-provider path is directly testable.
- Weekly negative fallback copy now frames fillers under pressure as the clearest suspect, not a proven cause.
- High-score session fallback no longer says "low filler count" when the rep still contains elevated fillers.
- High-score session fallback now says the result suggests the technique held and asks for another pressure rep before calling it solved.
- `NoumTests/NoumTests.swift` pins the fallback honesty rules with focused deterministic fallback coverage.

## VISION gap
`docs/VISION.md` requires weak evidence to stay tentative and forbids treating association as causation. The deterministic fallback is user-visible when the AI provider is unavailable, so it has to obey the same trust contract as model-backed coaching.

## Screenshots
None. This pass changed copy/logic only; no UI surface changed.

## Verification
- `git diff --check -- Noum/AIInsightsService.swift NoumTests/NoumTests.swift`
- `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=3D077053-2981-4C5D-819D-FF6F9BA8AD06' -derivedDataPath .derived-data/setup-polish -only-testing:NoumTests/AIInsightsDeterministicFallbackTests -only-testing:NoumTests/AIInsightsPromptAnchorTests`

