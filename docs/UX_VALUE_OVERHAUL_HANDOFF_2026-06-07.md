# UX Value Overhaul — Handover for Codex

_Updated 2026-06-07 (after a Claude verification+fix session that followed Codex's big pass).
Self-contained: assume no memory of prior sessions. Read top-to-bottom before editing.
Supersedes the earlier version of this file (recoverable via git history)._

Branch: **`ux-overhaul`** (off `main`). Status: **clean-builds + runs**; the four
value screens are clean; the post-rep verdict is verified on-device. ~4 work items remain.

---

## 0. TL;DR — current state

- Codex did a large pass (179 files). A Claude session then **verified it actually
  compiles + runs** (Codex couldn't build), fixed the top honesty gaps, and confirmed
  the core value screen on the simulator.
- **Done + verified:** reward ownership (celebration only on a real crossing), first-run
  routes into the prescribed rep, daily-reminder loss-aversion removed, and the **post-rep
  verdict renders correctly** (score → 2-sentence read → WIN with inline verified quote →
  FIX + drill CTA → Pro upsell after value).
- **Remaining (priority order):** proof/verdict CTA a11y ids · "Sudden Death"→"Pressure
  Drill" literal rename + reconcile the dirty `Localizable.xcstrings` · Profile *disclosure*
  redundancy cut · reduced-motion gates · **Ask Noum structured reply** (biggest/riskiest).

---

## 1. Mission + the shippable wedge

Owner: _"UX is the biggest killer — too much text, useless info, not enough felt value,
not enough reason to return. Major overhaul. Eventually approach a human communications
coach's value, without shallow gamification."_

**Do NOT claim "replaces a human coach" in product copy/launch.** Long-term ambition only.
The shippable wedge:

> Coach-grade deliberate practice for high-stakes short speaking moments: one short rep,
> one grounded read, one next move, durable memory, eventual real-world transfer proof.

**The owner delegated every decision** — decide, implement, verify on the simulator, and
continue. Don't stop to ask; push until done.

The target loop: **Speak → one evidenced read → one prescribed next rep → real pattern
movement → real-event prep/outcome → coach adapts.** The fix is overwhelmingly
subtraction + hierarchy + making value felt, not new features.

---

## 2. ⚠️ Environment + build discipline (READ FIRST — decides what you can do)

- **Building + simulator verification REQUIRE macOS + Xcode 26.3 (local).** If you run in
  a Linux/cloud sandbox you **cannot build, run, or screenshot** — edit Swift only, and
  **never claim a change works**; leave build/sim verification to a local run. (Codex's
  pass shipped uncompiled; the Claude session caught that it nonetheless built.)
- **Binary mtime is the real build gate.** `xcodebuild` can exit 0 **without relinking**
  (incremental no-op) AND without recompiling files that depend on deleted symbols — a
  *false green* that hides errors and installs stale binaries. **Always confirm the app
  binary mtime advanced before trusting/installing**; use a **clean build** for risky or
  deletion-heavy changes.
- **See the post-rep Summary on the sim** via the DEBUG `noum://summary` deep link
  (`ContentView.consumeDeepLink`, renders from the most-recent seeded session). It
  re-finalizes the session, so a celebration chain fires — tap through
  **Session Complete → "View Summary" → "Continue"** to reach the verdict body. The driver
  is `NoumUITests/ScreenshotTour.testCaptureSummary`.
- **Multi-state capture:** `UI_TESTING_SEED_PROFILE
  <beginner|improvingIntermediate|plateauedAdvanced|pressureVulnerable|fillerFree>`;
  omit seed args for a true cold/empty first-run. `simctl erase` (NOT uninstall) for a
  genuine cold-start — app-group data survives an app uninstall.

---

## 3. Git state

- Branch `ux-overhaul`. **Not pushed this session** — confirm remote with `git status`.
- **Codex base (verified to clean-build):** `60c2bb9`, `c245cd2`, `6ae2672`.
- **Claude session commits (newest first):**
  - `3a2ea56` test: testCaptureSummary taps through the celebration chain to the verdict
  - `e8b413b` docs handoff update (now superseded by this file)
  - `b2b4cb3` Iteration 2/6: remove loss-aversion from the daily reminder
  - `2b42a16` Iteration 1+3: reward ownership + first-run routes into the prescribed rep
- **Uncommitted (intentionally left):** `Noum/Resources/Localizable.xcstrings` (−194/+93,
  likely Codex's in-flight pressure rename — **REVIEW before committing**, confirm es/fr
  weren't dropped, or revert). Also a generated `.derived-data-log-*` (ignore/restore).

---

## 4. Done + verified this session

- **Codex's 179-file pass clean-builds + runs.** The `SocialProfileView.swift` deletion is
  safe because Codex extracted its live symbols into `SocialFriendSheets.swift` (that
  deletion broke an earlier build before the extraction). Home / Profile / Practice-picker
  look strong (one coach hero / collapsed Profile / "Your next rep" Coach-Pick picker).
- **Reward ownership (Priority 1):** `SummaryView` celebration gates on a real
  `SessionFinalizer` crossing via `SummaryView.shouldShowCelebration(hasMilestoneCrossing:score:xpEarned:)`,
  NOT `score>=7 || xp>=100`. `detectMilestone` emits nothing on rep 1 (count milestones
  start at 10, streak at 3, no PB on rep 1) → first-rep + score/XP excluded by construction.
  `NoumTests/RewardOwnershipTests` passing.
- **First-run → prescribed rep (Priority 2):** `CoachingOnboardingView` first-run completion
  sets `DeepLinkRouter.shared.pending = noum://train` before `dismiss()` → new user lands on
  the picker's Coach Pick, not a cold Home (Settings-edit still just saves). ⚠️ Runtime
  landing is **logically** verified (the noum://train→picker route is proven) but NOT
  screenshot-verified: the `UI_TESTING_ONBOARDING` harness binds the onboarding cover's
  `isPresented` to a constant `true`, so it re-presents on dismiss. Verify via the real
  first-run path (no profile, non-UI_TESTING) — e.g. add a test-only flag that drives the
  NoumApp first-run cover.
- **Notification loss-aversion (Priority 6, partial):** `NotificationCopy.dailyReminder` no
  longer says "Hold your N-day streak"/"yours to keep" — now invite-framed. `streakWarning`
  was neutralized in the prior session.
- **Post-rep verdict VERIFIED on-device:** score ring + "Good control" + Fillers/Duration,
  then **THE READ** (tight 2 sentences), **WIN** with the **inline transcript-verified proof
  quote**, **FIX FIRST** + concrete move + "Start 45s drill", then "Ask Noum · PRO" upsell
  *after* the free value. The read is no longer restated 3×. Iteration 1 complete.
- **Proof honesty contract already tested:** `ProofMomentServiceTests.transcriptContainsRejectsFabrication`
  (and siblings) pin that a quote not verbatim in the transcript is rejected → deterministic
  fallback, never fabricated. So no extra proof-fail-path test is needed.

---

## 5. Remaining work (priority order, with pointers)

1. **Proof/verdict CTA a11y ids (Priority 3).** `PostRepVerdictCard` has a card id
   (`summary.postRepVerdict`) but its CTAs (Home/Retry/New/Share, the drill button) need
   stable identifiers for UI tests. (The proof fail-path itself is already unit-tested.)
2. **Pressure language (Priority 4).** ~15 user-facing "Sudden Death" literals remain —
   `PathNode.swift` (203/205/206/315/316/318), `PathProgressManager.swift:288`,
   `SuddenDeathDifficultyRunsView.swift` (75/101), `ForwardPlanService.swift:193`,
   `SummaryView.swift:2169` (share), `WeakAreasCard.swift` (55/140), `GoalJourneyEngine.swift`
   (227/243), `SuddenDeathHistoryExport.swift` (41-63), `DerivedReadsTrend.swift:316`.
   Rename to "Pressure Drill" (matches `PracticeMode.suddenDeath.displayLabel`); keep the
   enum `.suddenDeath` and persistence. Reword the awkward "Under pressure (Sudden Death)"
   and "Pressure round. Sudden Death…" by hand. **Reconcile the dirty `Localizable.xcstrings`
   in the same pass** (most of these literals are NOT localized struct params, so renaming
   is safe; untranslated keys fall back to English, which is current behaviour).
3. **Profile disclosure cut (Priority 5).** Default Profile is clean; the *disclosure* is the
   junk drawer. In `ProfileView.swift`: cut the rating redundancy — `YourArcCard` +
   `PeakRatingWallCard` + `ProgressionChartsCard` (lines ~523-525) all retell the rating;
   keep ONE trajectory. Demote `ModeMasteryCard` (~526), achievements, and the
   league/social/speak-off sections (~1750-1996). Keep: one rating trajectory, one coach
   read/next move, growth library/review, the transfer loop. Don't add a "simple mode" toggle.
4. **Reduced-motion gates (Priority 6).** Gate animations in `CoachingOnboardingView`,
   `SummaryCards.HeroScoreCard`, `ProfileView` numeric transitions,
   `PracticeModeSelectionView` selection, `SessionHistoryView` disclosure. Pattern used
   elsewhere: `@Environment(\.accessibilityReduceMotion)` then skip the spring/particles
   (keep haptic + sound).
5. **Ask Noum structured reply (biggest value, highest risk — do LAST, feature-flagged).**
   Still prose `ChatOutcome.reply(String)`. Make substantive turns read **read → evidence →
   move**; route every quoted "you said…" through `ProofMomentService`'s verify-in-transcript
   guard with a **tested fail path**; if the chat path can't guarantee the guard, structure
   only the post-rep summary. Don't force structure on greetings. Live call: cut the 4-field
   "COACHING READ" brief → one focus line / "Tap Talk".

---

## 6. Build / simulator recipe (macOS only)

```bash
xcrun simctl list devices booted            # this session used iPhone 17 (iOS 26.4)
UDID=<booted-udid>

# Build to repo-local DerivedData (install from HERE, not ~/Library/.../DerivedData/Noum-*):
xcodebuild build -project Noum.xcodeproj -scheme Noum \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath ./DerivedData/Noum -configuration Debug
stat -f "%Sm %N" ./DerivedData/Noum/Build/Products/Debug-iphonesimulator/Noum.app/Noum  # mtime MUST advance

# Render the verdict on the sim:
xcrun simctl install $UDID ./DerivedData/Noum/Build/Products/Debug-iphonesimulator/Noum.app
xcrun simctl launch --terminate-running-process $UDID com.jordancoaten.noum \
  UI_TESTING UI_TESTING_SEED_FORCE -DeepLink noum://summary
# (re-finalizes → tap Session Complete → View Summary → Continue to reach the verdict body)

# Focused tests + screenshot tours:
xcodebuild test ... -only-testing:NoumTests/RewardOwnershipTests
xcodebuild test ... -only-testing:NoumUITests/ScreenshotTour/testCaptureSummary -resultBundlePath /tmp/x.xcresult
xcrun xcresulttool export attachments --path /tmp/x.xcresult --output-path /tmp/x-att
```

Bundle id `com.jordancoaten.noum`; project `Noum.xcodeproj`, scheme `Noum`. Files under
`Noum/` are an Xcode synchronized folder (add/delete just works); **root-level** files
(`ProfileView.swift`, `RewardEngine.swift`, etc.) ARE in `project.pbxproj` — deleting them
needs pbxproj surgery.

Suggested focused suites (confirm names compile first): `RewardOwnershipTests`,
`ProofMomentServiceTests`, `HomeSignalGateTests`, `FirstRunFrictionContractTests`,
`PracticeModeRowExpansionTests`, `PostRepVerdictContentTests`, `ProfileCollapseContractTests`,
`NotificationCopyEveningNudgeTests`.

---

## 7. Gotchas / verify-before-acting

- **`SocialProfileView.swift` symbols are NOT dead** — they were extracted to
  `SocialFriendSheets.swift`; don't reintroduce/duplicate. `AchievementsPage.swift` (root)
  is **NOT dead** either (wired in `ProfileView`). Verify all symbols in a file, not just
  the type name, before deleting.
- **Several review "criticals" are artifacts, not bugs** — e.g. "Debug: Simulate Days"
  panel is `AuthManager.isDeveloper`-gated (hidden from real users); "Platinum home behind
  onboarding" was stale-sim capture contamination. Always check the finding against current
  code / a clean (`simctl erase`) state before acting.
- **First-run landing** can't be verified through `UI_TESTING_ONBOARDING` (cover re-presents).
- **The dirty xcstrings** is the one thing to resolve carefully (review, don't blind-commit).

---

## 8. Red lines (do not ship)

fake progress / fake peers / fake peaks / fake loading / fake AI thinking · "replace a
human coach" claims · unverified "you said…" quotes · first-rep celebration as if
improvement occurred · score/XP celebration not backed by a real crossing · hearts/lives
framing · punish-shame pressure outcomes · raw "the user…" coaching rationale in UI · empty
clinical rubrics foregrounded as relationship · paywall before first felt value · hidden
video/presence analysis without explicit consent.

---

## 9. Deeper context (read as needed)

- `docs/UX_VALUE_OVERHAUL_ROADMAP.md` — the 7-iteration plan (diagnosis, principles,
  per-iteration changes/success/risk, cut list, owner decisions §12, visual-review triage §13).
- `docs/UX_RENDERED_REVIEW.md` — the 3-lead (UX/QA/market) review of the real rendered screens.
- `docs/OVERHAUL_HANDOVER.md` — earlier (pre-Codex) handover; mostly superseded by this file.
- Market diff (still valid): Noum's edge is **evidence-led private coaching grounded in the
  user's own speech + durable memory** — "Noum noticed the real thing I said, showed the
  pattern moving, gave me the next rep." Competitors to beat on judgment-over-metrics:
  Yoodli, Orai, Speeko, Poised, Vocal Image, BoldVoice. Avoid: metrics-without-judgment,
  context-blind filler detection, generic repetition, cluttered AI surfaces, streak/hearts
  gamification.

---

## 10. Final-response structure (per AGENTS.md / CLAUDE.md)

End substantial responses with: **Implemented · Partially implemented · Blocked ·
Assumptions · Verification · Risks.** Be explicit when build/tests/screenshots were not run.
