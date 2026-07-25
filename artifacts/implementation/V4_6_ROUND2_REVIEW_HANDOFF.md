# V4.6 Founder-Feedback — Review & Research Handoff

**Date:** 2026-07-25 · **Branch:** `ux-overhaul` (NOT pushed) · **HEAD:** `ba326517e`

```
ba326517e  fix: founder-feedback round 2 — audit-confirmed edge fixes, honest fallback rehearsal, copy sweep, dead-code removal
10c83d156  chore: string catalog sync for founder-feedback polish round
35cb0ce2d  merge: V4.6 founder-feedback polish round        (= e5b85f181, "round 1")
63b760f67  merge: implement V4.6 personalised coaching loop  (Slices 1–4)
```

`main` untouched. A separate local session is running the orphan-cleanup chip
(HomeSignalGate.swift, ModeMasteryViews.swift, streak-first-sight cascade) —
expect its commit to land on this branch independently.

---

## 1. What each founder-feedback item became

| Feedback | Landed in | Where |
|---|---|---|
| Home top bar sliver, doesn't fit one screen | Round 1 (+R2 hardening) | `HomeCoachCard.swift` gradient bleed (now −240), one-line entry rows in `ContentView.swift` `cohesiveHomeCards`; R2 added `scrollBounceBehavior(.basedOnSize)` |
| Audio bar static, app should feel alive | Round 1 (+R2 bugfix) | `VoiceTrace.swift:128-190` — 2.4s per-bar breathing ripple, RM-safe; R2 fixed frozen-squash on RM toggle + scenePhase re-arm |
| Profile double icon | Round 1 | `ProfileView.swift:2489-2530` (one small glyph), `SettingsView.swift:566-576` (neutral NoumCharacter orb) |
| Rehearsal = confusing "Where you stand" box, is order required? | Round 1 decided **ordered + locks** (graduated exposure: ease in → pressure → real shape); R2 fixed the logic | One list in `PrepSessionView.swift`; state machine now pure `PrepSessionPlanner.stepStatuses` |
| Chat: too much text, context box useless, "warm and welcoming coach", orb | Round 1 (+R2 honesty) | `AskNoumView.swift` — one-line context pill (copy now derived, not static), "Your personal communications coach.", waveform badge |
| Check again → Report issue + remediation | Round 1 (+R2 reliability) | `AskNoumView.swift` availability banner; R2: counter resets on every restore, scenePhase re-probe, secondary Check again, diagnostics in mail, web fallback |
| Train readability, CTA under nav, hide recommended from list, collapse on browse | Round 1 (+R2 AA + reset) | `PracticeModeSelectionView.swift`; R2: dark action tints, dead-clearance removal, browse-state resets |
| "get your voice on tape" + wording sweep | Round 1 (one string) + **R2 full sweep** | ~20 strings across 16 files (see §3 Copy) |
| Rehearsal "why these 3 for me" | Round 1 static arc; **R2 availability-aware** | `PrepSessionPlanner.introCopy` — 4 honest variants. Per-user-history tailoring NOT done (see §5) |

---

## 2. Review guide — highest-risk first

1. **Rehearsal ordered attribution** — `Noum/PrepSessionPlanner.swift`
   (`PrepStepStatus`, `stepStatuses(plan:sessions:momentCreatedAt:)`).
   The core rule: walk steps in order; each consumes the earliest unconsumed
   qualifying rep matching its planned mode (preferred) or its offered Timed
   fallback. This is what kills the permanent lock dead-end. Check the
   judgement call: *a fallback rep advances the lock sequence but readiness
   () stays shape-honest* — done rows covered via fallback say
   "…the pressure round itself is still untested."
   Unit tests: `NoumTests/PrepSessionAvailabilityTests.swift` (happy path,
   out-of-order coverage, fallback unlock, planned-shape preference,
   all-done, last-step fallback marker).
2. **Ask Noum availability policy** — `Noum/AskNoumView.swift`
   (`AskNoumAvailabilityRecheckPolicy` + one `.onChange(of:
   liveCoachAvailability)` reset). Judgement calls: auth-pending /
   debug-provider reasons don't count toward the Report-issue swap;
   Report issue coexists with a quiet Check again. Mail diagnostics in
   `NoumWebURLs.askNoumUnavailableSupportMail` (reason code, retry count,
   app/OS — no content). No unit coverage yet (policy is a pure static —
   cheap to add).
3. **Train colour registers** — `DesignSystem.swift`
   (`modePaceAction`, `modeSuddenDeathAction`, `brandBlueOnWash`).
   Decorative tints untouched; only filled-CTA surfaces darkened.
   Contrast arithmetic is in the token doc comments. Visual: 
   `.screenshots/2026-07-25_founder-verify/13-train-pace-cta.png`.
4. **VoiceTrace animation invariant** — `Noum/VoiceTrace.swift`. Rest scale
   is derived (`(breathes && isBreathing) ? 0.84 : 1.0`) so any disarm path
   is freeze-proof; re-arm goes through a `disablesAnimations` transaction.
5. **Dead-code deletions** (~1,500 lines net across R2) — old home stacks in
   `ContentView.swift`, pre-dedup catalogue in
   `PracticeModeSelectionView.swift`, orb/context-card remnants in
   `AskNoumView.swift`, `displayLine` in the planner, "Show advanced home
   cards" toggle in `SettingsView.swift`. Each symbol was grep-verified
   repo-wide before deletion; full audit trail in §6.
6. **AX identifier gotcha** (regression-prone pattern): container-level
   `.accessibilityIdentifier` blankets descendants — it stomped
   `prepSession.step.N.begin` until moved onto the header text
   (`PrepSessionView.swift` stepsCard). Worth a conventions note.

### Copy (all display-text only; IDs/keys untouched)

"on tape"×2, "Noum listens live"×3, "case file"×3, "WHAT NOUM HEARD →
FROM YOUR TRANSCRIPT"×2, "Minute Man → The Full Minute", "Fortnight Force →
Two-Week Streak", "Most people stop at 3. → This is where practice starts
compounding.", "Slipping → Needs a rep" (never-punish-shame), "Trim the Fat →
Trim the Extras", "never lose an audience again → your audience will stay
with you", plus grammar/tone fixes in NotificationCopy, SummaryView,
PathJourneyView, ShareableSessionCard, FirstRepCelebration, ProfileView
share copy. Diff view: `git show ba326517e --stat` then per-file.

---

## 3. Verification evidence

- **Unit:** full `NoumTests` target — 4,763 assertions, 1 failure
  (pre-existing: pinned account-data inventory missing `v46-earned-evidence`
  from the V4.6 merge) → fixed, `AccountDataRegistryTests` re-run green.
  xcresult: `DerivedData/Noum/Logs/Test/Test-Noum-2026.07.25_15-32-04-+0100.xcresult`.
- **UI:** rewritten `PrepSessionAvailabilityUITests` green end-to-end
  (honest fallback plan, zero "Unlocks after" remnants, 44pt targets,
  route-bound prompt preserved). xcresult `…15-48-14…` + rerun.
- **Sim (seeded, dark, iPhone 17 / iOS 26.5):**
  `.screenshots/2026-07-25_founder-verify/` — Today breathing frames differ
  (f1/f2 md5), one-screen fit, no top sliver (10-*), Ask Noum honest pill +
  grammatical headline (11), Report-issue swap after two failed checks (04),
  Train compact row + deduped catalogue + AA Pace CTA (12, 13), Profile (05),
  Settings (09). Rehearsal fallback-covered plan: xcresult attachment
  (exported copy at the path in §6).
- **Build recipe** (two traps, both bit this session):
  - The shared `Noum.xcscheme` is **gitignored** and had been silently
    deleted — every `-scheme Noum` build failed while piped output looked
    green. Recreated (copy `Noum-StoreKit.xcscheme`, strip the two
    `StoreKitConfigurationFileReference` blocks). Consider tracking it.
  - `xcodebuild | tail` reports the *filter's* exit code — use
    `set -o pipefail` or verify via xcresult, never pipe-tail output.

---

## 4. Known limitations (deliberate, not bugs)

- **iPhone SE-height (667pt):** seeded Today overflows into scroll at
  default type. V4.6 fit contract was verified on 874pt-class devices.
- **PrimaryCTA** white-on-dark-brandBlue = 3.54:1 — passes the large-text
  exemption only; a global brandBlue change ripples everywhere, so left.
- **Dynamic Type:** Profile's small voice glyph doesn't scale
  (`VoiceGoalIcon` fixed-size; shared component, deferred).
- **Prod coach backend** stays down by decision (see deepgram closure
  memory) — the sim's "temporarily unavailable" banner is expected.

## 5. Open product questions (research fodder)

1. **Rehearsal page identity** — it still titles "Rehearsal"; feedback said
   it reads as a "Your Plan" page. Rename, or keep the event-anchored frame?
2. **Per-user tailored "why"** — intro arc is event- and availability-aware
   but not history-aware ("your last pressure rep dropped fillers 40%…").
   Worth wiring `distanceFromGoal` / recent-rep evidence into one clause?
3. **Privacy reassurance in Ask Noum** — the old card's growth-analytics
   sentence is now VoiceOver-only. Does a sighted user ever need it back
   (e.g. first-open one-shot, or inside Manage)?
4. **Duplicate manage-context affordances** — pill "Manage" + thread-options
   "Manage attached context" on one screen. Collapse to one?
5. **Nil-voice Profile header** has no brand mark while Settings keeps the
   orb — intentional asymmetry or restore a neutral mark?
6. **M5 goal-grounding line** lost its last surface when the old Train
   catalogue died. Re-home it (hero? Why-this-rep?) or retire the struct?
7. **"Rehearsal in N days" card value** — now carries the tailored why, but
   is proximity + arc enough, or should it show evidence ("2 of 3 shapes
   covered") once attribution data exists?

## 6. Artefacts & audit trail

- Adversarial audit (5 surfaces, per-claim VERIFIED/PARTIAL/BROKEN + gaps
  with file:line): `…/scratchpad/audit_results.json` (session-local; key
  findings reproduced in commit ba326517e's message).
- Fix-agent decision logs (what was changed, what was deliberately skipped):
  workflow `wf_ed9d69ca-914` journal (session-local).
- Frozen design source: `artifacts/figma/v4.6-final/` +
  `v4.6-production-ready/` (app now matches `Dark-Today-final.png`
  structurally; Train/Rehearsal/Ask Noum have no frozen pages — they follow
  the token contract in `artifacts/implementation/V4_6_IMPLEMENTATION_PLAN.md`).
- To run the branch review: `/code-review ultra` from this branch.

## 7. Next release task

TestFlight blockers unchanged from the V4.6 state doc: prod coach-backend
rebind (gated, folded into next backend release) and a real-device pass on
the RAG/agentic retrieval flags (`coach_brain_rag` memory). Everything
UI-side on this branch is green and evidence-backed.
