# Handover — accessibility pass + Otherpath identity migration

_Last updated: 2026-07-28 · branch `ux-overhaul` · HEAD `035a26492`_

Self-contained. Read top to bottom before continuing. The **Traps** section at the
end is not optional reading — every item in it cost hours to learn during this
session, and several of them will silently produce a wrong answer if ignored.

---

## TL;DR

Two workstreams landed. First, a verified defect sweep and accessibility pass
(15 commits). Second, Jordan's bundle-ID migration to the Otherpath Ltd
organisation identity, carried through the code and cloud config it touched.

**The single most important fact in this document:** `-only-testing:NoumTests`
is always green and tells you almost nothing. The full UI suite has **15
long-standing failures**. See [Test-suite reality](#test-suite-reality).

---

## Commits

```
035a26492 build: complete the Otherpath identity migration; fix two compiler warnings
51c78417e chore: string catalog sync for the accessibility labelling pass
a8e5fdd74 build: Debug-only entitlements so a free Apple team can build to a device
4cec287bc chngs                          <- NOT mine; a concurrent agent swept up my
                                            uncommitted hero-gradient work. Reasoning
                                            survives in code comments only.
5ae7bb91b a11y: give the tab bar the large-content viewer its clamp assumes
f031b459b a11y: reachable exits and verdict chips, and honour Reduce Motion/Transparency
e937f093f test: guard the contrast defect class the a11y tooling cannot see
83e01723f a11y: dark-mode onboarding, spoken rewrite diff, AA colour tokens, chart summary
e9e33ad8e fix: restore the 44pt tap targets — my previous root cause was wrong
aaa332c63 fix: evidence floor, Dynamic Type, and revert an a11y fix that broke a11y
a2b6cd26b fix: task leaks, ambience leak, a fabricated regression claim, and a dead toggle
21e4086de docs: record the motion-coverage decision; scope Profile's entrance honestly
2e14c8302 feat: make the declared motion actually fire — clock, countdown, summary, Profile
872472401 fix: four verified defects from the review pass, plus the silent first run
544677cbe test: stop two suites racing on the global flow log
bf3c074fa fix: Filler Control stops offering a Start that can never succeed
```

`origin/ux-overhaul` is 1 behind (only `035a26492` unpushed at time of writing).
Something in this repo auto-pushes — do not assume your local commits are private.

---

## OUTSTANDING — start here

### 1. Apple / cloud config Jordan must finish (blocking device + cloud work)

- **App Check for the new Firebase App ID.** `1:381934683469:ios:1f6d3cb46df771a7356304`
  (bundle `uk.co.otherpath.noum`). This is what `assertTrustedCaller` enforces on
  the `transcriptionToken` callable, so **cloud transcription stays broken until
  it is registered**, plus a debug token for local runs.
- **Confirm the `group.uk.co.otherpath.noum` app group exists** under team
  `6ARQD6LLU6` in the developer portal.
- **`Noum/GoogleService-Info.plist` is gitignored.** It exists only on Jordan's
  machine. Any other worktree or CI needs its own copy:
  `firebase apps:sdkconfig IOS 1:381934683469:ios:1f6d3cb46df771a7356304 --project noum-d0b6f --out Noum/GoogleService-Info.plist`
- **After cutover**, drop `com.jordancoaten.noum` from the Gemini and TTS API
  keys (both currently allow old + new deliberately, so nothing breaks mid-move).
- **Revert `Noum-Debug.entitlements`** once the paid programme is active — point
  Debug back at `Noum.entitlements` so Debug and Release test the same capability
  set. Reason is in that file's header.
- The **old Firebase iOS app** (`…b0b44845c0e98cde356304`, bundle
  `com.jordancoaten.noum`) is still registered and holds existing analytics.
  Harmless, but data now spans two app records. Decide whether to retire it.

### 2. The 15 pre-existing UI test failures

Triage started, not finished. Diagnosis summarised here.

**Group A — `JourneyAccessibilityAuditUITests`, 6 of 9 failing.**
Diagnosed properly and the conclusion is counter-intuitive: **most are false
positives.** All three "Contrast failed" elements on Home measure **5.38, 5.71
and 6.15:1** by direct pixel measurement of the audit's own element screenshots.
They pass AA. Xcode's contrast audit mishandles text over gradients (no single
representative backdrop colour).

The harness already anticipates this — `performVisibleAccessibilityAudit` takes
`verifiedContrastLabels`, and there are five named false-positive handlers
including `handlesVerifiedAdjustContrastFalsePositive`. Profile and ContextualAsk
already use the mechanism.

- **Action:** measure each flagged element, and where it passes, add its label to
  `verifiedContrastLabels` **with the measurement recorded in a comment**. Do not
  silence blindly.
- **Genuine defects in this group:** the `textClipped` issues (e.g. "Your
  first-week read", which measures 15.11:1 so is definitely not contrast), and
  `testSettings…` which reports `element=nil` and cannot be diagnosed from the
  log at all.
- **How to get the diagnosis:** the harness logs every issue as an
  `NOUM_A11Y_ISSUE` activity with identifier, label, frame and Apple's detail.
  Extract with `xcrun xcresulttool get test-results activities --test-id … --path …`
  and grep for `NOUM_A11Y_ISSUE`. Element screenshots come from
  `xcrun xcresulttool export attachments`.

**Group B — five first-run tests asserting a DISABLED feature.**
`testOnboardingFlowSmoke`, `testFirstRunCloudDeclineStillReachesLocalCapablePractice`,
`testFirstRunValueLoopReachesFirstVerdictWithInjectedTranscript`,
`FastLaneFirstSessionUITests` ×2.

They assert that finishing onboarding lands on `timedPractice.screen`. It does
not, **by design**: `AutoGuidedFirstRep.defaultEnabled = false`, introduced
already-off in `f392b01f5`. Onboarding correctly lands on Today with
`home.coachCard.begin`. Commit `6d49e6505` already corrected one sibling test for
exactly this premise — **copy that pattern**. Verify per test whether the product
should route there (fix product) or the test encodes the dead lane (fix test).

**Group C — diagnose individually:**
`testCompletedOnboardingSurvivesInterruptionAndRelaunch`,
`testProfileEvidenceDisclosureStaysCoachEvidenceOnly`,
`FocusedPracticeSetupUITests/testFocusedSetupIdentifiersSelectionTraitsAndTabBarHiding`,
`ReviewProgressEligibilityUITests/testProfileUsesTwoMeasuredRepsWhileLinkingToFiveRawRows`.

**Group D — correct the record.** `docs/CURRENT_STATE.md` claims "zero failed or
skipped tests" and "4,514 Swift tests… zero failures or skips". True of
`NoumTests`, false of the full suite. Update it to state its scope.

### 3. Accessibility items still open

Ranked. All verified against code, none started.

1. **`ProgressionCharts` marks are 14–22% alpha** (~1.2:1 against the plot area)
   and its axis labels were 10pt `.tertiary`. The chart now has a spoken summary
   (`chartAccessibilityLabel`) but the *visual* contrast is still failing.
2. **`accessibilityReduceTransparency` and `accessibilityDifferentiateWithoutColor`
   have ZERO reads app-wide** — 19 material surfaces, and a semantic system where
   violet = coach voice, blue = action, green = delta, amber = lapse. The amber
   token's own comment says "ALWAYS paired with a text cue", so the principle is
   understood but has no system-level hook. Architectural, not a patch.
3. **`accessibilityValue` appears 19 times against 334 labels.** State is baked
   into labels rather than exposed as values, which costs correct announcements
   when a value changes.
4. **The live transcript is the only serif in the codebase**, undocumented, in a
   type system whose roles are SF Pro Rounded/Text. Left alone deliberately —
   typeface is a founder call. Noted in `TimedPracticeView`.
5. **Extract a shared `CoachVerdictChip`.** Four near-identical chip sites
   (`AskNoumView` ×3, `CaseReviewCard` ×1) were each given `minHeight: 44`
   separately. The refactor is right but wants its own verification pass.
6. **`SessionHistoryListView`**: mode filter chips carry selection in colour only
   (no `.isSelected`, ~30pt tall); clear-search glyph is ~14pt.

### 4. Design / motion

- **Device-felt motion is still owed.** `FIGMA_GATE_DECISIONS.md` lists "exact
  motion values on device" as untested, and it cannot be closed from a simulator.
- Figma page 18 (`280:497`) gained **section E** (`302:497`) documenting four
  moments the Motion Contract never covered. The decision is recorded in
  `PRODUCT_DECISION_LOG.md` under 2026-07-27.

---

## What landed this session

### Verified defect sweep

Adversarially verified — 21 confirmed of 31 candidates, 10 refuted.

- **Microphone reopened after the user left the screen.** Three unheld `Task`s in
  `TimedPracticeView` (brief-reveal auto-start, `beginSession`, `newPromptSession`)
  resumed on a departed view and opened the mic and ambience behind whatever
  screen the user had moved to. Note `try? await Task.sleep` swallows
  cancellation, so the handle alone is insufficient — the post-sleep
  `Task.isCancelled` check is load-bearing.
- **Semantically valid speech counted as filler.** The positional rep-event read
  used the raw lexicon, so genuine connective "like"/"so" fed a "you clustered
  fillers" claim. Now uses semantically adjusted detections.
- **Fake celebration on rep #1.** `TrendAnalyzer.analyze` emitted two trends for
  `.conciseSpeaking`, and `SkillProgressionStore.record` mutates its snapshot
  inside the loop, so the second compared against the first instead of history.
  Fixed at source and defensively at the consumer.
- **Fabricated regression claim.** At exactly 3 reps the "older" window is empty
  and `average` returns 0, so `olderAvg <= 2 && recentAvg >= 4` told users their
  fillers had "just spiked" with no earlier window to spike from.
- **Sudden Death ambience leak** on back-out during `.npcTurn`.
- **Dead toggle** in the Share sheet claiming audio/video was being shared when
  `createRequest` takes no recording.
- **Evidence floor defeated** — `SummaryView` passed `BaselineStat.empty`'s 0
  unconditionally, and 0 hedges/min maps to a *perfect* composure score, so the
  2-channel minimum was met by a channel that had measured nothing.

### Accessibility

- **Onboarding was unreadable in Dark appearance — 1.01:1.** Hardcoded near-black
  ink on `AppColor.innerSurface`. Every existing check passed it because the text
  was present in the accessibility tree; it was broken only for a sighted user in
  Dark mode. 18 of 21 literals moved to adaptive tokens.
- **The rewrite diff is now spoken** — the gate required it and it is the
  product's signature moment. The changed-word sets already existed for the
  visual highlight and were simply never voiced.
- **`positive` and `caution` now meet AA** (3.44 → 5.16:1, 2.79 → 4.72:1, light
  values only; dark were already 8.7+). `positive` is the gate's own prescribed
  `#0E7A3B`, which had never been adopted.
- **Hero gradient end stop** darkened to the gate's `#6D46D6`; hero text
  opacities raised. Measured 3.57 → 5.71:1 on the meta line.
- Drill exits and verdict chips to 44pt; Reduce Motion gating; the tab bar's
  large-content viewer.

### Two test guards (`e937f093f`)

- **`ColorContrastGuardTests`** — 27 pairings × light/dark at AA thresholds,
  resolving REAL tokens through a `UITraitCollection` so it cannot drift from
  `DesignSystem.swift`. **Adding a token pairing to the app means adding it to
  that table.** Includes a self-check that fails if the trait provider is ever
  lost — without it every token resolves light and all 27 pass while proving
  nothing.
- **`HardcodedInkLintTests`** — bans NEW `foregroundStyle(Color(red:…))`.
  Foregrounds only; ~120 hardcoded FILLS are legitimately fixed decorative
  surfaces. Three sites allowlisted with reasons. Verified by injecting a
  violation and confirming it fails.

Note: the contrast guard would NOT have caught the onboarding bug — a literal
never touches a token. The lint is the one that covers the motivating case.

---

## Test-suite reality

| Scope | Result |
|---|---|
| `-only-testing:NoumTests` | **4750 / 0** — always green |
| `NoumTests` + full `NoumUITests` | **4824 passed, 15 failed** |

The 15 are pre-existing. Verified by running the same suites at `e9e33ad8e`:
`JourneyAccessibilityAuditUITests` failed **7 of 9** there, and the other nine
were an identical list.

**Never report "N passed / 0 failed" without naming the scope it covers.**

---

## Traps

Each of these produced a confidently wrong answer during this session.

1. **A green suite after a FAILED build is a stale binary.** Happened three
   times; once it reported `4750 passed` immediately after `build_exit=65`.
   Always check the build exit code before trusting test output, and prefer a
   script that refuses to run tests when the build fails.

2. **A bisect whose failures all precede its passes is confounded by time, not
   evidence.** I "bisected" a UI failure across nine builds to a flip-camera
   `.frame(36→44)`, reverted a correct accessibility fix, and wrote a commit
   explaining a mechanism that was impossible — the view only renders behind
   `isFullScreenCameraActive`, and the test dies before that. Re-running the
   suspect build 3× in a quiet machine state: 3/3 pass. **Before attributing a UI
   failure to code, re-run the suspect build several times serially with nothing
   else running.**

3. **`Failed to get matching snapshots: Timed out while evaluating UI query` is
   load starvation, not an app bug.** It appears on `descendants(matching: .any)`
   against a large Accessibility XXXL hierarchy while other `xcodebuild`
   invocations run. An assertion failure means the app; a query timeout means the
   machine.

4. **Do not run two builds against the same `derivedDataPath`.** Produces
   `database is locked … two concurrent builds`. I blamed the concurrent agent;
   `pgrep -fl xcodebuild` showed it was my own overlapping build. Use an isolated
   path (`./DerivedData/<yourname>`) when anything else may be building.

5. **Swift Testing `-only-testing` filters need `()`.** A `@Test` filter without
   parentheses runs ZERO tests and prints TEST SUCCEEDED.

6. **`.serialized` orders tests within a suite, not across suites.** Two suites
   both resetting `FlowEventLog.shared` wiped each other's in-flight traces. A
   global actor does not fix it — the tests suspend at `await`, which is exactly
   where the other suite resumes. See `NoumTests/FlowEventLogTestGate.swift`.

7. **A concurrent agent commits to this worktree.** `4cec287bc "chngs"` swept up
   my uncommitted work. Commit eagerly and stage explicitly; an unstaged change
   here is not private, just unlabelled.

8. **Verify the mechanism, not just the correlation.** Check the view actually
   renders on the failing path (read the gating conditions; check the sim
   container's prefs) before believing a layout story.

---

## Related task chips spawned

- Fix first-run onboarding → Timed Practice routing (may be a stale test — see
  Group B)
- Give Ah Counter a real recovery affordance (its provider-failure surface is a
  passive status line; it does NOT strand the user — verified — but the register
  is weaker than Timed's)
- Add a Dark-mode contrast guard to the a11y suite (partly delivered by
  `e937f093f`; the UI-sweep half is not done)
- Triage the 15 pre-existing UI test failures (Group A–D above)
