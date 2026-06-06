# Noum UX/Value Overhaul — Handover (for Codex)

_Handoff from a Claude Code session, 2026-06-06/07. Self-contained: the receiving
agent has no memory of the prior session. Read this top-to-bottom before editing._

---

## 0. Mission (owner's directive)

> "UX is the biggest killer of this app — too much text, useless info, not enough
> value felt. Major overhaul. The app must confidently move toward replacing a
> human communications coach **and** keep users coming back — not from shallow
> gamification but from **immense value**. Nail both. Make it look amazing,
> dopamine-inducing animations like Duolingo. Make all the decisions yourself and
> drive every iteration to done; build + verify on the simulator as you go."

The owner delegated **all** decisions. Don't ask — decide, implement, verify, continue.

---

## 1. Read these first (the plan is already written)

1. **`docs/UX_VALUE_OVERHAUL_ROADMAP.md`** — the authoritative 7-iteration plan:
   diagnosis, 7 design principles, cross-cutting rules (incl. paywall), per-iteration
   changes / success criteria / risk, orphaned-surface dispositions, cut list,
   **§10 open debates**, **§12 owner decisions (already made)**, **§13 visual-review
   triage (real bugs vs capture artifacts)**.
2. **`docs/UX_RENDERED_REVIEW.md`** — the 3-lead (UX / QA-a11y / market) review of the
   *real rendered screens* across 4 user states. 72 critical/high findings.

Both were produced by multi-agent workflows grounded in the actual SwiftUI + a
122-screenshot corpus. Treat them as the source of truth for *what* to change.

---

## 2. ⚠️ Environment — READ THIS (decides what you can do)

- **Building + simulator verification REQUIRE macOS + Xcode 26.3 (local).**
- If you (Codex) run in a **Linux/cloud sandbox, you CANNOT build, run, or
  screenshot.** You may edit Swift, but you **must not claim a change works** —
  leave build/sim verification to a local run (the owner, or Claude on the Mac).
  Do logic-only edits + leave precise verification notes. (This mirrors the
  constraint sandboxed agents already hit this session.)
- **Verification discipline (learned the hard way — do not skip):**
  `xcodebuild` incremental can report **exit 0 without relinking** (binary mtime
  unchanged) **and without recompiling dependent files** — a *false green* that
  hides real errors and ships stale binaries.
  → **Always confirm the app binary mtime advanced before trusting/installing.**
  → Use a **clean build** for risky changes. Recipe in §6.

---

## 3. Git state

- Work branch: **`ux-overhaul`** (branched off `main`). At session start, `main` was
  fast-forwarded to the old `Redesign` tip (`0c87c82`). **Nothing is pushed** (local only).
- Commits on `ux-overhaul` (newest first):
  - `f5c4f06` Iteration 1: noum://summary force-hook + summary capture test (infra)
  - `4def34a` Iteration 1 (WIP): post-rep WIN leads with the user's verified words
  - `132f0f6` Iteration 2: honesty + a11y + dead-code sweep
  - `39c934e` capture tooling + roadmap/review docs
- Tree is clean. Commit per iteration; **do not push** without the owner's OK.

---

## 4. Owner decisions already made (roadmap §12)

1. **Streak** → quiet, no-countdown status line; every loss-aversion string removed. Not a pressure anchor.
2. **Comeback trigger** → neutral-invite notifications; assert a delta only above the in-app debrief's conservative threshold; primary lever is the in-session coach-memory callback.
3. **Per-rep dopamine** → rep stays near-silent; the beat lives in the post-rep score-ring resolve; the full multi-sensory celebration fires **only on real `RewardEngine .major` crossings**.
4. **Picker** → one prescribed rep as hero **with** a visible one-tap "pick another" escape.

---

## 5. Status per iteration

### ✅ Iteration 2 — DONE, verified on-device, committed (`132f0f6`)
- Removed forever-pulsing nav icons (reduce-motion violation), `ContentView.swift`.
- Neutralized loss-aversion streak notification copy → invite framing, `NotificationCopy.swift` (`streakWarning`).
- Cut decorative "+XP" path-card label, `PathJourneyView.swift` (real DailyChallenge XP untouched).
- Removed `Int.random(45...92)` simulated-opponent scoring → honest pending, `ChallengesManager.swift`.
- Removed the cosmetic location-permission prompt on Path open, `PathDaylightModel.activate()`.
- **Reverted** a planned deletion: `SocialProfileView.swift` is **NOT dead** (other files use symbols inside it) — see §7.

### 🔧 Iteration 1 — IN PROGRESS
**Done + committed (build-verified):**
- Pulled the reflection card out of the comprehension flow (`SummaryView.swift`); deferred reflection still lives in the Details drawer (`DeferredCaptureInlineCard`).
- **WIN card leads with the user's verified words**: `WhatYouDidWellCard` gained an inline `proof` row (claim + verbatim transcript-verified quote + technique); SummaryView now loads the `ProofMomentService` proof on **every** summary (was celebration-only) and passes it in. Eloquence quote deduped so two quotes never stack. (`4def34a`)
- Verification infra: `noum://summary` DEBUG force-hook + `ScreenshotTour.testCaptureSummary`. (`f5c4f06`)

**Honesty contract (already structural):** the proof quote is guaranteed verbatim in
the transcript or `ProofMomentService.proof(...)` returns `nil` and the row doesn't
render. `ProofMomentService.transcriptContains` is the guard; deterministic fallback exists.

**Remaining for Iteration 1:**
1. **Visually confirm the proof-WIN row.** `testCaptureSummary` currently lands on the
   post-finalization **"First Rep" achievement overlay** (the hook's `Entry` has
   `committedFinalization: nil`, so SummaryView re-finalizes + fires reward events).
   Fix: in `testCaptureSummary`, after launch, tap the overlay's **"Continue"** button
   (then any second milestone overlay) before `deepAttach`. Then re-run and eyeball the
   `WhatYouDidWellCard` proof row (accessibility id `summary.whatYouDidWell.proof`).
2. **Tighten the read so it isn't restated 3×.** `CoachReadCard` renders the full
   voice note (momentum+leverage+nextStep) + a "Deep analysis" reveal; WhatYouDidWell
   shows momentum, WhatToImprove shows leverage+nextStep. Keep CoachReadCard to a tight
   ~2-sentence read and move the "Deep analysis" reveal into the Details drawer; reduce
   WhatToImprove to the one fix + its concrete move.
3. **Confirm celebration honesty:** `RewardEngine.emit` gates `.major` at
   `RewardEngine.swift:99` (`if event.tier == .major && activeCelebration == nil`);
   SummaryView gates the overlay on `celebrationVisible && !reduceMotion` (~803). Confirm
   no celebration on the onboarding/first rep; reduced-motion fallback keeps haptic+sound.
4. **Honesty unit test:** verify (or add) a test for the proof **fail path**
   (`ProofMomentService.transcriptContains` returns false → nil → template). grep `NoumTests`.

### ⏳ Iterations 3–7 — PENDING (roadmap §5 has full detail)
- **3 First-60-seconds:** route the EXISTING `CoachingOnboardingView` (context/challenge/voice option lists) into the production first-run, replacing the 3-slide hero; then one short rep → one honest "first read" (NO celebration/verdict on rep 1). Delete the **12s+2s fake-loading bar** (`CoachingOnboardingView.swift` ~`processingDuration=12.0`, ~line 698); cut the forced 1s splash (`NoumApp.swift` ~89); no paywall before the first rep. Feature-flag; verify cold-start **and** returning-user branches.
- **4 Home:** make `HomeCoachCard` the only hero; fold Ask-Noum into it; gate the utility strip + Ask promo behind ≥1 rep; remove the cold-start overclaim "I read your last 30 days" (`ContentView.swift` ~1272); fix the fake tab bar. **Also fix the COLD-START FABRICATION bug** (verified real, §7): a 0-rep user sees Profile "highest rating yet · 400" + League "Silver". Gate every celebration / peak / tier / league on ≥1 real *rated* session. Relates to the `league_promotion_guard` need.
- **5 One prescription + spine:** picker leads with the recommended rep + "pick another"; kill the blocking "Today's focus?" modal for new users; consolidate crowns + drill/challenge XP onto the **speaking-rating** spine (keep the credit, change where it surfaces); reconcile the 3 pace thresholds into one constant; rename Cut-the-Crutch "hearts" (engine + UI).
- **6 Coach reply gets a shape (ENGINE, highest trust-risk):** structured read→evidence→move. Route every quoted "you said X" through the `ProofMomentService` verify-in-transcript guard with a **tested fail path**; if the chat path can't guarantee the guard, structure ONLY the post-rep summary. Don't force structure on greetings. Live call: cut the 4-field "COACHING READ" brief → one focus line / "Tap Talk".
- **7 Profile 22→4 + transfer loop:** reduce Profile to ~4 surfaces (identity; one believable-progress hero; one coach read+move+proof; quiet History/Library). **Carry forward each card's self-suppress-on-thin-data discipline and TEST the thin-data path** (the review's top risk). Build the BigMoment/PrepSession prepare→event→reflect outcome loop (no causation copy). Cut `CoachParityReadinessCard`.

Sequencing rule (roadmap §11 footer): do NOT land 3, 6, and 7 in one pass — each is high-effort on the most-trafficked ~8,500 LoC with a historically flaky test net. Feature-flag, build, verify between each.

---

## 6. Build / simulator recipe (macOS only)

```bash
# Pick a booted sim (this session used iPhone 17 Pro, iOS 26.3):
xcrun simctl list devices booted
UDID=0FC8C57F-480C-4681-9B6F-224D9AA53277

# Build to repo-local DerivedData (install from HERE — NOT ~/Library/.../DerivedData/Noum-*, which is stale):
xcodebuild build -project Noum.xcodeproj -scheme Noum \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath ./DerivedData/Noum -configuration Debug

# VERIFY RELINK before trusting/installing (guards the false-green trap):
stat -f "%Sm  %N" ./DerivedData/Noum/Build/Products/Debug-iphonesimulator/Noum.app/Noum   # mtime must advance

# Install + render a screen via deep link:
xcrun simctl install $UDID ./DerivedData/Noum/Build/Products/Debug-iphonesimulator/Noum.app
xcrun simctl launch --terminate-running-process $UDID com.jordancoaten.noum \
  UI_TESTING UI_TESTING_SEED_FORCE -DeepLink noum://summary
xcrun simctl io $UDID screenshot /tmp/shot.png

# Screenshot tour (swipes/states) via XCUITest, then extract attachments:
xcodebuild test -project Noum.xcodeproj -scheme Noum -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath ./DerivedData/Noum \
  -only-testing:NoumUITests/ScreenshotTour/testCaptureSummary -resultBundlePath /tmp/x.xcresult
xcrun xcresulttool export attachments --path /tmp/x.xcresult --output-path /tmp/x-att   # manifest.json maps files

# TRUE cold-start (uninstall is NOT enough — app-group data survives):
xcrun simctl shutdown $UDID; xcrun simctl erase $UDID; xcrun simctl boot $UDID
```

Bundle id: `com.jordancoaten.noum`. Project: `Noum.xcodeproj`, scheme `Noum`.
Files under `Noum/` are an Xcode synchronized folder (NOT in project.pbxproj — add/delete
just works); **root-level** files (e.g. `ProfileView.swift`, `AchievementsPage.swift`,
`RewardEngine.swift`) ARE listed in `project.pbxproj` — deleting them needs pbxproj surgery.

---

## 7. Gotchas / lessons (do not repeat)

- **`SocialProfileView.swift` (1,495 LoC) is NOT dead** — other files reference symbols
  *inside* it; deleting it breaks the build. A name-grep for `SocialProfileView` missed
  this; an incremental build false-greened it. **`AchievementsPage.swift` is also NOT
  dead** (wired in `ProfileView.swift:41/255/1227`). Verify *all* symbols in a file, not
  just the type name, before deleting.
- **False-green builds:** see §2. Check binary mtime; clean-build risky changes.
- **Screenshot-corpus contamination:** seeded data persists in the app-group container
  across an app uninstall — only `simctl erase` truly resets to cold-start. The
  deep-audit "A-cold-*" frames in the corpus were re-captured after an erase.
- **Verify findings before acting:** several review "criticals" were artifacts, not bugs —
  "Platinum power-user home behind onboarding" = pre-erase capture contamination; the
  "Debug: Simulate Days" panel = gated by `AuthManager.isDeveloper` (AIConfig.plist
  allowlist; `false` for real users). The **cold-start fabrication** bug (Profile "highest
  rating yet 400" / League "Silver" for a 0-rep user) IS real (post-erase) → Iteration 4/7.
- **`noum://summary` hook re-finalizes** the session (Entry `committedFinalization: nil`),
  firing the achievement celebration overlay; tap "Continue" to reach the body, or build a
  real `SessionFinalizationResult` for a clean render.

---

## 8. Capture / test infrastructure added this session

- `UI_TESTING_SEED_PROFILE <rawValue>` (`NoumApp.swift`) → seed any of 5 `DevSeedData`
  personas (`beginner`, `improvingIntermediate`, `plateauedAdvanced`, `pressureVulnerable`,
  `fillerFree`); omit the seed args for a true empty/cold first-run.
- `NoumUITests/ScreenshotTour.swift`: `testCaptureDeepAudit` (4 states × every surface,
  full-scroll + accessibility-tree dumps), `testCaptureColdStart`, `testCaptureOnboardingFlow`,
  `testCaptureSummary`.
- `noum://summary` DEBUG deep link (`ContentView.consumeDeepLink`) → post-rep summary from
  the most-recent seeded session.
- Corpus (gitignored): `.screenshots/2026-06-06_deep-audit/` (122 png + 97 AX txt).

---

## 9. Immediate next step

Finish Iteration 1: (1) tweak `testCaptureSummary` to dismiss the "First Rep" celebration
("Continue") and screenshot the WhatYouDidWell **proof row** to visually confirm it renders;
(2) tighten `CoachReadCard` + reduce `WhatToImprove`; (3) confirm celebration `.major`-only +
reduced-motion; (4) proof fail-path test. Then commit Iteration 1 and proceed to Iteration 3.
