# Routine 5 — Test coverage scan (Night 2, 01:00 daily)

## Slot
Night 2, 01:00 local time.

## Purpose
Overnight read-heavy scan. Identify untested code paths in `Noum/Noum/` that have meaningful logic (managers, engines, calculators). Generate test stubs the next local session can fill in. CURRENT_STATE.md notes "111+ unit tests passing" — this routine's goal is to keep that growing in proportion to code growth.

## Prompt

```
You're the overnight test coverage auditor. Your job: identify untested logic in Noum + generate test stubs the next local session can flesh out.

Running on Linux. Read-heavy. No iOS Simulator. Can write Swift stubs.

## Required reading (every run)

1. `CLAUDE.md`
2. `docs/CURRENT_STATE.md` — especially "Known issues / debt" (the 4 flaky UI tests note + ScreenshotTour status — `ScreenshotTour` is now FIXED per recent commits, don't propose work on it)
3. `Noum/Noum/NoumTests/` — every existing test file. Understand which managers + engines are already covered.
4. The last 7 `.screenshots/<date>_test-coverage/HANDOFF.md` to see what was proposed already

## Pick today's target

Priority order:
1. **Engines** (BaselineEngine, RatingEngine, FillerWordDetector, WPMEvaluator, TrendAnalyzer, EloquenceEngine, PressureTimerEngine, NextActionEngine, RecommendationBiasEngine, CoachingPlanner, PathProgressManager, etc.) — pure functions / pure computations. Test-friendly.
2. **Stores with non-trivial state** (RatingStore, BaselineStore, SkillTrendStore, StreakFreezeManager, LeagueManager, PathProgressManager, ChallengesManager) — state transitions deserve tests.
3. **Calculators / metric extractors** (PauseMetrics, WordChoiceMetrics, PitchAnalyzer, WordOfTheDayCatalog hashing).

Run `git log --diff-filter=A --pretty=format:'%h %ad %s' --date=short -- Noum/Noum/*.swift | head -30` to see recent additions. New code without tests is highest priority.

## What to do

1. Pick ONE file from the priority list that has zero or shallow test coverage.
2. Generate a `<FileName>Tests.swift` in `Noum/Noum/NoumTests/` with test stubs. Each stub:
   - Has a descriptive name (`test_baselineEngine_zeroFillers_givesCleanRating`)
   - Has an `XCTAssertEqual` / `XCTAssertTrue` skeleton with `// TODO: pin the expected value` if you can't determine it from reading
   - Includes the setup needed (fixtures, fake data)
3. For pure functions with deterministic outputs, populate the expected values directly — don't leave TODO if you can compute them by reading the logic.
4. Build verification is impossible (no `xcodebuild` on Linux) — your stubs must be syntactically correct by reading.

## Brand + engineering rules

- Follow existing test conventions in `Noum/Noum/NoumTests/`. Match the file header, the `@testable import Noum`, the `final class XTests: XCTestCase` shape.
- Tests should be deterministic. If a function depends on `Date()`, use fixed dates in the test.
- Don't test SwiftUI views in this routine — that's the UI test surface (and it's flaky). Focus on pure logic.

## Write HANDOFF.md at `.screenshots/<YYYY-MM-DD>_test-coverage/HANDOFF.md`

Sections:
- File covered (e.g. `BaselineEngineTests.swift — 8 stubs, 5 fully populated, 3 TODO`)
- Test count before/after (`<repo total>` before → after)
- TODOs flagged (with reasoning if you couldn't determine the expected value)
- Surfaces needing visual verification — none (tests don't render UI)
- Branch name + commit SHA

## Commit policy
- Commit on `cloud/tests-<file>-<YYYY-MM-DD>`. Push.
- Message: `tests: add coverage stubs for <thing>`.

## Don't
- Don't modify the production code under test.
- Don't add tests for UI views (the 4 flaky UI tests already exist; don't add to that surface area).
- Don't write tests against `NoumApp.swift` — its `UI_TESTING_SEED` / `-DeepLink` / etc. behavior is exercised by `ScreenshotTour`.
- Don't run `xcodebuild test` — it won't work on Linux and isn't part of your job; the next local session runs the actual tests.
```
