# Ready-to-apply patch — double-Begin fix on the recommended-hero CTA

Status: **specced + compile-verified, NOT committed** (2026-06-25). Change 1 (source)
was applied and **`xcodebuild build` SUCCEEDED**, then reverted to keep the tree clean
for the concurrent session. It is **not** safe to ship the source alone:

> **Apply source + tests ATOMICALLY.** Change 1 alone turns
> `testFirstRunValueLoopReachesFirstVerdictWithInjectedTranscript`
> (`NoumUITests.swift:223`) RED. When Timed is the recommended hero, the
> `practiceMode.timed` row is excluded from the alternates (heroes aren't listed
> twice), so the test falls into the else-branch, taps the hero, and asserts
> `timedPractice.begin` exists at `:263`. With the arm() fix the hero auto-begins
> and that button never appears → assertion fails. The fix and Change 2 below MUST
> land in the same commit.

The required test edits live in files the concurrent coach-chat session has
**staged** (`NoumUITests.swift`, `ScreenshotTour.swift`), so this whole patch waits
for the session that lands that staged diff. It is the eval's prescribed step #2
toward A* and is now otherwise unblocked (the TimedPracticeView Impromptu rewrite has
landed, so the collision the 06-23 eval named is gone; only the test-file overlap and
this atomicity requirement remain).

## Why
Cold first-run path makes a brand-new user tap **Begin twice**: the picker's
recommended-hero CTA navigates into Timed Practice without arming the one-tap
quick-start flag, so the destination shows its own `timedPractice.begin` and the
user taps again. The plumbing already exists — `TimedPracticeView.swift:862`
consumes `PracticeModeQuickStart.consume(for: .timed)` and auto-calls
`beginSession()`. The hero CTA simply never arms it. The secondary "Start now"
CTA (`PracticeModeSelectionView.swift:743`) already does exactly the right thing.

This is the single highest-confidence lever on the Acquisition / first-rep score
(5.5 — the biggest drag in the 7.4/10 eval).

## Change 1 — source (collision-free)

`Noum/PracticeModeSelectionView.swift`, the recommended-hero `PrimaryCTA` closure
(~line 362-368). Add the arm call before the navigation push, mirroring `:743`.

Before:
```swift
PrimaryCTA(PracticeModePrescriptionCopy.beginLabel(for: option.title), tint: option.tint) {
    selectedMode = option.mode
    crutchSelected = false
    paceSelected = false
    recommendationLearningStore.markTapped(mode: option.mode)
    navigationPath.append(appDestination(for: option.mode))
}
```

After:
```swift
PrimaryCTA(PracticeModePrescriptionCopy.beginLabel(for: option.title), tint: option.tint) {
    selectedMode = option.mode
    crutchSelected = false
    paceSelected = false
    recommendationLearningStore.markTapped(mode: option.mode)
    // Arm one-tap quick-start so the destination auto-begins instead of
    // showing a second Begin. Mirrors the "Start now" CTA at :743; the
    // destination view consumes-and-clears the flag in its `.task`
    // (e.g. TimedPracticeView.swift:862), and the picker's own `.task`
    // clears any stale flag on re-entry (:318) so back-out can't re-trigger.
    PracticeModeQuickStart.arm(for: option.mode)
    navigationPath.append(appDestination(for: option.mode))
}
```

Notes:
- `appDestination(for:)` already maps every `option.mode`. `arm(for:)` stores the
  raw mode; `consume(for:)` only fires for the matching destination, so a
  mismatched mode is a safe no-op.
- Cut-the-Crutch and Pace are separate flags (`armCrutch`/`clearCrutch`) and are
  not reached by this hero CTA (it only renders pressure-mode options), so no
  change is needed there.

## Change 2 — onboarding first-rep UI test (file is STAGED — apply with the diff)

`NoumUITests/NoumUITests.swift`, the onboarding→first-rep test (~line 244-264).
The hero branch now auto-begins, so `timedPractice.begin` no longer appears on that
path. Gate the second-Begin tap to the non-armed (mode-row → `practiceModes.start`)
branch only.

Before:
```swift
if timedMode.waitForExistence(timeout: 8) {
    timedMode.tap()
    ...
    XCTAssertTrue(app.buttons["practiceModes.start"].waitForExistence(timeout: 5))
    app.buttons["practiceModes.start"].tap()
} else {
    let recommendedBegin = app.buttons["practiceModes.recommendedHero.begin"]
    XCTAssertTrue(
        recommendedBegin.waitForExistence(timeout: 5) && recommendedBegin.label.contains("Timed"),
        "Timed Practice should be selectable from the collapsed picker, or be the recommended hero."
    )
    recommendedBegin.tap()
}

let begin = app.buttons["timedPractice.begin"]
XCTAssertTrue(begin.waitForExistence(timeout: 10))
tapTimedPracticeBegin(begin, in: app)
```

After:
```swift
if timedMode.waitForExistence(timeout: 8) {
    timedMode.tap()
    ...
    XCTAssertTrue(app.buttons["practiceModes.start"].waitForExistence(timeout: 5))
    app.buttons["practiceModes.start"].tap()
    // Mode-row + Start CTA does NOT arm quick-start, so the setup page's
    // Begin still appears and must be tapped to start the rep.
    let begin = app.buttons["timedPractice.begin"]
    XCTAssertTrue(begin.waitForExistence(timeout: 10))
    tapTimedPracticeBegin(begin, in: app)
} else {
    let recommendedBegin = app.buttons["practiceModes.recommendedHero.begin"]
    XCTAssertTrue(
        recommendedBegin.waitForExistence(timeout: 5) && recommendedBegin.label.contains("Timed"),
        "Timed Practice should be selectable from the collapsed picker, or be the recommended hero."
    )
    // Recommended hero now arms one-tap quick-start: the destination
    // auto-begins, so there is NO second Begin to tap. Asserting its
    // absence is the regression guard for the double-Begin fix.
    recommendedBegin.tap()
    XCTAssertFalse(
        app.buttons["timedPractice.begin"].waitForExistence(timeout: 3),
        "Recommended-hero path must auto-begin (one tap), not show a second Begin."
    )
}
```

(The shared `advanceToPostRepVerdict(in:)` call that follows is unchanged and works
for both branches; the auto-begin path simply enters the rep through the thinking
phase rather than an explicit Begin tap.)

## Change 3 — screenshot tour (file is STAGED — apply with the diff)

`NoumUITests/ScreenshotTour.swift`, `openModeSetup(_:in:)` (~line 436-444). This
helper screenshots the **setup page**; with the hero now auto-beginning, the timed
shortcut would land on the live rep instead. Drop the hero shortcut so the tour
always uses the row → `practiceModes.start` path, which still lands on setup.

Before:
```swift
private func openModeSetup(_ modeID: String, in app: XCUIApplication) -> Bool {
    if modeID == "practiceMode.timed" {
        let recommendedBegin = app.buttons["practiceModes.recommendedHero.begin"]
        if recommendedBegin.waitForExistence(timeout: 2),
           recommendedBegin.label.contains("Timed") {
            recommendedBegin.tap()
            return true
        }
    }

    let modeRow = revealPracticeMode(modeID, in: app)
    ...
}
```

After:
```swift
private func openModeSetup(_ modeID: String, in app: XCUIApplication) -> Bool {
    // NOTE: the recommended-hero CTA now arms one-tap quick-start and
    // auto-begins the rep, so it can no longer be used to reach the SETUP
    // page for a screenshot. Always go through the mode row + Start CTA,
    // which preserves the configure-first (setup-page) destination.
    let modeRow = revealPracticeMode(modeID, in: app)
    guard modeRow.waitForExistence(timeout: 3) else { return false }
    modeRow.tap()
    Thread.sleep(forTimeInterval: 0.4)

    let startCTA = app.buttons["practiceModes.start"]
    guard startCTA.waitForExistence(timeout: 3) else { return false }
    startCTA.tap()
    return true
}
```

## Unaffected (verified)
- `NoumUITests.swift:423 launchRecommendedHeroIfMatching` checks the screen
  container identifier (`timedPractice.screen`), which is present during the rep
  too — it passes unchanged after auto-begin.

## Verify after applying
```bash
xcodebuild test -project Noum.xcodeproj -scheme Noum \
  -destination "platform=iOS Simulator,id=<booted-UDID>" \
  -derivedDataPath ./DerivedData/Noum \
  -only-testing:NoumUITests/<onboardingFirstRepTest>
```
Then on-device QA the one-tap path: onboarding → Begin (hero) → lands directly in
the rep (through the thinking phase), no second Begin.

## Open product decision (do NOT silently bundle)
After auto-begin, the first rep enters a **15s thinking countdown**
(`enableThinkingTime` default true, `TimedPracticeView.swift:688`). For a
brand-new user's very first rep this is 15s of forced wait before speaking. Worth a
deliberate call: keep it (impromptu prep is intentional) vs. default the *first ever*
rep to instant-start. This is a product judgment for Jordan, not part of the
mechanical double-Begin fix.
