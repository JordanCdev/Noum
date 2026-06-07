# UX Value Overhaul — Handover for Codex

_Updated 2026-06-07 (after a Claude verification+fix session that followed Codex's big pass).
Self-contained: assume no memory of prior sessions. Read top-to-bottom before editing.
Supersedes the earlier version of this file (recoverable via git history)._

Branch: **`ux-overhaul`** (off `main`). Status: **focused tests passing after Codex
continuation**; the post-rep verdict was verified on-device in the Claude session, and
the real first-run onboarding → Train route is now verified by UI test. The remaining
gap is visual/runtime screenshot review plus the larger roadmap work that was never
closed by the original handoff list.

---

## 0. TL;DR — current state

- Codex did a large pass (179 files). A Claude session then **verified it actually
  compiles + runs** (Codex couldn't build), fixed the top honesty gaps, and confirmed
  the core value screen on the simulator.
- **Done + verified:** reward ownership (celebration only on a real crossing), first-run
  routes into the prescribed rep, daily-reminder loss-aversion removed, and the **post-rep
  verdict renders correctly** (score → 2-sentence read → WIN with inline verified quote →
  FIX + drill CTA → Pro upsell after value).
- **Codex continuation completed:** proof/verdict CTA a11y ids · "Sudden Death"→
  "Pressure Drill" user-facing rename + `Localizable.xcstrings` JSON reconciliation ·
  Profile disclosure redundancy cut · reduced-motion gates on named hotspots · Ask Noum
  structured-reply prompt flag + quote guard · Cut the Crutch picker copy locked against
  hearts/lives framing · real first-run route verified outside the pinned onboarding harness.
- **Roadmap status:** Iteration 1 complete. Iteration 2 mostly complete. Iteration 3
  partially complete (route verified; true "ask → speak → first read within ~60s" still
  needs end-to-end product proof). Iterations 4 and 5 are not complete. Iterations 6 and
  7 are partial. Do not confuse "handoff list closed" with "app done."
- **Remaining:** screenshot/visual sweep on simulator and the broader product-readiness
  pass beyond this handoff's priority list.

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
  the picker's Coach Pick, not a cold Home (Settings-edit still just saves). Codex added
  `UI_TESTING_REAL_FIRST_RUN`, which opts UI tests back into the real `NoumApp` app-level
  first-run cover instead of the pinned `UI_TESTING_ONBOARDING` harness. Verified by
  `NoumUITests/NoumUITests/testOnboardingFlowSmoke`, which now completes onboarding and
  asserts `practiceModes.screen` appears.
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

## 5. Codex continuation work completed

1. **Proof/verdict CTA a11y ids (Priority 3).** `PostRepVerdictCard` now exposes stable
   identifiers for the root and drill/retry CTA buttons, with VoiceOver hints on the drill
   actions.
2. **Pressure language (Priority 4).** User-facing "Sudden Death" copy was renamed to
   **"Pressure Drill"** across the identified surfaces while preserving `.suddenDeath`
   enum/persistence names. `Localizable.xcstrings` was reconciled and validated as JSON.
3. **Profile disclosure cut (Priority 5).** Expanded Profile details now follow a tested
   `ProfileEvidenceDetailPlan`: one rating trajectory, coach evidence next, optional systems
   demoted. The old full social/speak-off sections no longer dominate the disclosure; compact
   rows preserve community and achievement access.
4. **Reduced-motion gates (Priority 6).** `CoachingOnboardingView`, `SummaryCards.HeroScoreCard`,
   `ProfileView` numeric/disclosure transitions, `PracticeModeSelectionView`, and
   `SessionHistoryView` now skip springs/pulse/bounce where `accessibilityReduceMotion` is on.
5. **Ask Noum structured reply (Priority 6/7, high risk).** The chat remains `String`-based,
   but the system prompt now has a defaults-backed structured-shape flag
   (`askNoum.structuredReplyShape.enabled`, default on) for **read -> evidence -> next move**.
   A tested `CoachChatQuoteGuardContext` rejects live replies that use quoted "you said..."
   language unless the quote appears in a known transcript, a verified proof quote, or the
   latest user turn. Repair passes must clear the same guard.
6. **Anti-goal copy guard.** Cut the Crutch picker copy now lives on
   `PracticeModePrescriptionCopy` and has a test proving it says "slips" rather than
   hearts/lives/no-second-chances framing. Internal engine names still use `heartsRemaining`
   for compatibility; the user-facing register is locked.

## 5a. Remaining work

1. **Visual/runtime verification.** Run the screenshot sweep after this continuation and inspect
   Profile expanded details, Practice picker, Summary verdict, and Ask Noum empty/live states.
   Codex checked this on 2026-06-07: the local simulator is available, but both screenshot
   mode files are currently `off`, so no PNGs were captured. A minimal verification note lives
   at `.screenshots/2026-06-07_codex-ux-continuation/HANDOFF.md`.
2. **Full readiness iteration.** This pass closes the handoff's implementation list; it does not
   prove the app is "done." Continue with a full product QA/market-readiness evaluation after
   screenshots and simulator walkthroughs.

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
