# M15 — "A coach who's actually present" — Handoff

## Current production-closure continuation — 2026-07-16 deletion fence

This continuation covers the account-deletion boundary developed on
`ux-overhaul` above `ea667cfd4`. Preserve the existing `AuthManager`,
`AccountDataRegistry`, Ask Noum, Forward Plan, and recommendation-sync owners;
do not add a parallel deletion or provider-work store. The durable Keychain
record is the admission authority across relaunch. Its account, provider,
request UUID, and phase are monotonic; missing alone permits scoped provider
work, and generic sign-out never clears an uncertain deletion.

Ask Noum auxiliary/reply transports and Forward Plan pending/active transports
are now cancellable and lease-checked across deletion. Recommendation local
admission and backend queue/hydration/acknowledgement paths reuse the same
durable gate. Settings derives recovery from persisted phase: admission-closed
may retry, remote-committed/local-cleanup-started may only finish device
cleanup, and remote-requested remains support-only. Support context contains
an opaque request reference and phase, never account or coaching content.

The checked callable requires schema v2 and an expected account ID equal to
the verified Firebase UID. Exact current-attempt safe preflights are typed;
generic failed-precondition and resumed requests stay ambiguous. The server
sets a two-hour expiry on the minimal completed deletion marker, Firestore
write rules gate on its existence until TTL deletes it, and TTL is cleanup
metadata rather than client authority. The caller reports success only after
exact marker finalization; if
that fails, the pending marker remains as the safer write fence. Exact
duplicates preserve the completed marker, while mismatched or malformed state
fails closed. `reconcileAccountDeletionTombstones` runs every 15 minutes,
paginates past malformed rows, and replays the same full deletion worklist for
exact pending rows at least 30 minutes old whether Auth still contains the user
or has already removed it. Failed unchanged rows remain pending and rotate via
their refreshed `updatedAt`.

Focused iOS verification passes **70/70**, adjacent regression verification
passes **55/55**, and a final frozen-source policy/recovery selection passes
**23/23**. The full unsigned unit target passes **4,402 unique tests / 4,421
executions**; its result bundle is
`/private/tmp/noum-account-deletion-full-final-20260716.xcresult`. Functions
passes **115/115** unit tests, **7/7** deploy-lock checks, **18/18** cloud-
operations validator tests, and **28/28** full local emulator tests including a
stale-token private write rejected with 403 and direct scheduled-callback
recovery. The current-source unsigned Release simulator build succeeds. A
light current-source five-tab sweep is recorded in
`.screenshots/2026-07-16_account-deletion-fence/HANDOFF.md`; it does not cover
the deletion sheet, relaunch, support-only recovery, accessibility, or live
backend behavior.

Do not describe this as production deletion readiness. The Functions, rules,
scheduler identity, composite index, and TTL configuration are undeployed; a
direct local callback invocation proves neither live scheduler delivery nor TTL
cleanup. A lost success reply after Auth removal has no durable client receipt
or unauthenticated recovery route. Backend work outside the explicitly fenced
surfaces and device-global AI-call diagnostics still need audit. Signed
physical-device deletion, accessibility, live-provider, professional,
longitudinal, operational, and all five required external artifacts remain
missing. The gate remains **NO-GO at 18/100 with 0/5 required external
artifacts**.

## Current production-closure continuation — 2026-07-16

This handoff covers the Forward Plan metric-qualification source developed on
`ux-overhaul` above baseline `8f0107df1`. It reuses the existing baseline,
filler-evidence, authentication, plan, session, provider-consent, and Ask Noum
owners. Recent filler context reaches the provider only as a per-minute rate
after the shared 20-word, 15-second, confidence, current-schema, and non-fixture
boundary; otherwise it is explicitly not measured. Persisted filler and pace
baselines likewise use the current-comparison accessors. Independent mode,
score, and average-score evidence remains available.

The final validity check and actual data-task start occur synchronously in one
MainActor turn. Provider, deterministic, and fallback outcomes revalidate after
suspension, and the final compare-and-save requires the source,
authorization, plan owner, and Ask Noum loaded account to remain exact.
Lifecycle, reload, completed local deletion, assignment, and
phrase-reconciliation mutations invalidate stale requests. Focused metric
verification passes **7/7**, the combined metric and Forward Plan selection
passes **134/134**, and the complete unsigned target passes **4,355 unique
tests / 4,374 device-configuration executions** with zero failures or skips.
Its result bundle is
`/private/tmp/noum-forward-plan-metric-full-20260716-0140.xcresult`. The
current-source unsigned Release simulator build succeeds.

Do not broaden this into full Forward Plan completion. First-plan generation is
source-reachable after three eligible reps through **Profile → Library →
Coaching evidence → Coaching direction**, correcting the preceding audit, but
that entry is deeply buried. Home suppresses `.prompt`, Ask Noum has no
dedicated entry, and the mounted stale-plan path does not explain a legitimate
fail-closed result or retain its task for proactive cancellation. Deletion
initiation is not a lease input, so provider work can start or continue until
local teardown. Device-global AI-call diagnostics remain outside lifecycle and
registry deletion; their reason metadata can expose interaction/coaching-gate
details, and an optional live-evaluation path can append provider draft
fragments even though no checked-in build setting enables it. Repeated
full-history hashing may cost MainActor time, and the Ask/plan durable writes
are not crash-atomic. No UI changed, and no Forward-Plan-specific rendered,
physical-device, live-provider, professional, longitudinal, operational, or
required external evidence was added. The authoritative gate remains **NO-GO
at 18/100, with 0/5 required external artifacts**.

## Current production-closure continuation — 2026-07-15

This handoff covers the bounded production-closure source developed on
`ux-overhaul` above baseline `8fbdbab6e`. The May M15 brief below remains
historical context; do not use its branch, merge, or completion claims as
current instructions.

The current source closes the verified P0 account/source race behind
M15 Proof Moments through existing owners. `PracticeSessionStore` supplies an
account-scoped loaded-store epoch with the exact saved row;
`ProofMomentStore` issues a request only for a signed-in, fully hydrated account
whose live row matches every captured source field. The token and cache carry
account lifecycle, store generation, source revision, and the exact
voice/goal/baseline generation identity. Cache hits revalidate, every provider
or deterministic outcome passes through one archive compare-and-save boundary,
and a failed save is neither cached nor returned.

Weekly Insight, Path Celebration, First Rep, and Summary capture that request
synchronously before Proof Moment work can suspend and revalidate the result
immediately before assigning it. Weekly Insight also rejects and clears stale
account-lifecycle state. Focused verification passes **39/39** and the related
regression selection passes **130/130**. The complete unsigned target passes
**4,331 unique tests / 4,350 device-configuration executions** with zero
failures or skips; the result bundle is
`.build-roleplay-terminal/Full-NoumTests-ProofCAS-20260715-final-r2.xcresult`.
The current-source unsigned Release simulator build succeeds for this source.
The light current-source five-tab simulator sweep renders
the expected tab tops and is recorded in
`.screenshots/2026-07-15-proof-moment-account-cas/HANDOFF.md`; it does not
exercise the Proof Moment account-transition path.

Do not broaden this P0 closure into a full Proof Moment completion claim.
Same-account voice/goal/baseline drift is not live-revalidated; source mutation
or deletion after commit does not remove the archived proof; rendered surfaces
discard the token after assignment; and cancellation during the archive hop can
still leave a durable write. The unused unchecked archive writer is also a
latent internal bypass. These are P1/P2 follow-ups through the same owners.

The preceding bounded slice extends exact-session Summary integrity through the
premium persisted Coach Read using the existing session, baseline, and coaching
owners. Generation resolves the identified saved row and exposes transcript,
prompt, mode, score, duration, and score-only continuity while deliberately
withholding filler/WPM/pace mechanics from free-form provider and fallback
prose. Derivative strengths/blockers, clutch-word history, and filler/pace
pressure reads are withheld too; qualified mechanics remain in deterministic
Summary components.

Provider output fails closed for invented current or historical mechanics,
common filler/speed aliases, and fabricated transcript quotes. Required quote
presence and quote integrity are separate: every observational quote and every
attributed quote in any field is checked, while legacy safe nonquoted reads
remain available. Contraction-safe deterministic quotes keep the offline save
path viable. An account-scoped full-source token is captured
before the asynchronous request; the store atomically rechecks it, revalidates
the output, persists, and returns the saved value. Summary and both Review
replay paths selectively hide unsupported legacy mechanic prose without
deleting grounded nonmetric coaching.

For that preceding Coach Read slice, focused verification passes 56 unique
tests / 58 device executions. Its complete unsigned simulator unit target
passes 4,320 unique tests / 4,339 device executions with zero failures or
skips, and its unsigned Release simulator build succeeds. The light five-tab
sweep is still blocked before tab content by the normal guest account-save
failure; see `.screenshots/2026-07-15_summary-verdict-evidence/HANDOFF.md` and
do not count those captures as visual proof.

This is not product-wide metric or Coach Read closure. Next audit the
qualitative Summary delivery line, durable CoachMemory/derived delivery reads,
IM baseline comparison, Ask Noum session opener, share/request-feedback WPM,
Proof Moment metric qualification plus the P1/P2 lifecycle/replay gaps above,
Forward Plan metric qualification and first-plan reachability, and remaining
durable narrative/reward consumers.
Standalone Pace attribution and wider Roleplay routing remain product/schema
decisions. No Proof-Moment-specific rendered, physical-device, provider,
professional, longitudinal, operational, or required external evidence was
added by the current slice. Do not claim production readiness: the
authoritative gate remains **NO-GO at 18/100, with 0/5 required external
artifacts**.

_Last updated: 2026-05-21 · branch `Redesign` · base HEAD `60a9afe`_

This doc is self-contained. Read top to bottom before starting any pending phase. You should not need this conversation to pick up.

---

## Context — what M15 exists to fix

Noum is feature-complete (M14 in flight: deploy + TestFlight). But the user experience has three concrete problems that compound:

1. **No real "coach presence."** `NoumCharacter` (`Noum/NoumCharacter.swift`) is intentionally abstract per the brand rule "no illustration" — an SF-Symbol waveform inside halos. It breathes, it has 4 moods + 5 stages. But it doesn't *react* to the user. They don't feel a someone-is-here.
2. **No Day-1 tailored payoff.** `FirstRepCelebration` (`Noum/FirstRepCelebration.swift`) celebrates duration + filler count after rep 1. That's coach *evidence* but not *insight*. The "Noum heard you and noticed something specific" moment is gated behind weeks of use (Proof Moments only surface on Weekly Insight / Path Celebration / Personal Best today).
3. **Home is dense; mode picker is opaque to newcomers.** 5–6 cards stacked on home from session 1. The Sudden Death / IM / Ah-Counter / Cut-the-Crutch mode names mean nothing to a first-timer.

VISION.md anti-goals — read these before touching anything:
- "A streak-and-badge addiction loop"
- "A hearts-and-lives gating game"
- "Shallow gamification"
- "A noisy productivity app"

M15's framing: **retention through believable presence**, not slot-machine mechanics. Rewards = the coach noticing specific things in *your* words. Not popups.

---

## Required reading before any phase

- `CLAUDE.md` (repo root) — response structure, no shallow gamification, terse code, no comments unless they explain WHY
- `docs/VISION.md` — North Star, pillars, anti-goals
- `docs/CURRENT_STATE.md` — architecture, state managers, patterns
- `.claude/skills/noum-design/` — voice rules, color palette, type scale
- `Noum/DesignSystem.swift` + `Noum/Typography.swift` — tokens (single source of truth)

CLAUDE.md mandates a "Scope / Product goal / Existing patterns / Root causes / Risks / Plan" block before any implementation. Honour it.

---

## The five pillars of M15

| Pillar | What it does | Status |
|--------|--------------|--------|
| 1. Character with presence | New moods `.thinking` + `.noticing`, audio amplitude binding | **Phase 1 SHIPPED** on `Redesign`; **Phase 1b PENDING** (wire orb into practice views) |
| 2. "Noum heard you" on rep 1 | Promote `ProofMomentService` to rep-1 surface; replace generic stats in `FirstRepCelebration` | **PENDING** |
| 3. Mode literacy without choice paralysis | Tap-to-expand "What this trains" on each mode row | **PENDING** |
| 4. Home discipline | Signal-gated home — 3 cards for first 5 sessions, more unlock as data accrues | **PENDING** |
| 5. Insight streak (restrained "gamification") | Count of banked Proof Moments surfaced on Profile + AskNoum | **SHIPPED** in worktree `worktree-agent-a3207f6e`, NOT MERGED |

---

## What's shipped so far

### Phase 1 — orb upgrade (in `Redesign`, uncommitted)

Three files changed:

**`Noum/NoumCharacter.swift`**
- New mood cases: `.thinking` and `.noticing`
- `.thinking`: dimmer glow than `.listening`, slower smaller wobble, distinct symbol (`waveform.circle`), no listening arcs — "the orb is processing internally, not actively hearing audio"
- `.noticing`: brightest glow of all moods, brief inhale-scale (1.10 → 1.0 over 0.4s), distinct symbol (`waveform.path.badge.plus`) — for the moment the coach catches something
- New parameter `audioLevel: Double? = nil` — when non-nil and mood is `.listening`, the core scale picks up an additive boost (capped at +18%) so the orb visibly tracks the user's voice
- All 8 internal switches on `Mood` updated (4 in main view, 4 in `Inline` variant)
- `retriggerForMood()` extended to handle the `.noticing` inhale animation
- Reduce-motion respected throughout

**`Noum/SpeechRecognizerViewModel.swift`**
- New `@Published var audioLevel: Double = 0.0` — smoothed RMS envelope, main-actor isolated, updated at ~30Hz during recording
- New private static `audioLevelSmoothing: Double = 0.30` — blend coefficient
- Audio tap (`installTap` at line ~342) extended to compute RMS, dispatch to main, smooth-blend the published value
- `teardownAudioStream()` resets level to 0 (so a stopped rep doesn't leave the orb stuck on the last live value)
- New `nonisolated static func normalizedRMSLevel(buffer:)` — dB-mapped envelope, -50dB → 0, -10dB → 1

**`Noum/AskNoumView.swift`**
- Header `NoumCharacter` uses `.thinking` (not `.listening`) while awaiting reply — reads more accurately
- `pendingDots` view replaced with a 24pt `NoumCharacter(mood: .thinking, …)` — same coach, no stylistic break with the rest of the surface

Build: **green** (177s, no warnings introduced).

### Phase 5 — insight streak (worktree `worktree-agent-a3207f6e`, NOT MERGED)

Lives at `.claude/worktrees/agent-a3207f6e`. Diff: +96 lines across 2 files.

- `ProfileView.swift` — `@StateObject private var proofStore = ProofMomentStore.shared`, new `insightsBankedChip` between speaking-rating card and YourArc. "N insights banked · Most recent: Xd ago". Hidden when count is 0. Pluralization correct.
- `Noum/AskNoumView.swift` — low-emphasis "insights" caption above the input bar. Hidden when count is 0.
- Build: **green** in the worktree.

**To merge into `Redesign`:**
```sh
git -C /Users/jordan/src/GitHub/Noum merge --no-ff worktree-agent-a3207f6e
```

**Pre-existing hygiene note from the agent:** `Noum/Info.plist` is gitignored but required for `xcodebuild`. The worktree had to copy it from the primary checkout. Not part of the staged diff. Confirm this is the intended setup for worktrees (it's likely an existing pattern, not a Phase 5 problem).

---

## Phases pending — full briefs

### Phase 1b — orb in practice views with audio binding

**Goal:** make the "Noum is hearing me" payoff visible. Today `audioLevel` is published but no view consumes it.

**Where to place the character:**
- `Noum/TimedPracticeView.swift` — add a 44pt `NoumCharacter` at the top, near (or replacing part of) the existing top bar. Must not crowd the timer / topic prompt.
- `Noum/SuddenDeathPracticeView.swift` — same placement convention
- `Noum/AhCounterView.swift` — same
- `Noum/IMPracticeView.swift` — same
- `Noum/CutTheCrutchView.swift` — same

**Binding pattern:**
```swift
NoumCharacter(
    mood: speechVM.isRecording ? .listening : .calm,
    tint: AppColor.brandBlue,        // or mode tint
    size: 44,
    audioLevel: speechVM.audioLevel, // <-- the new published envelope
    stage: characterStage
)
```

**Design constraints:**
- Per-view layouts differ. Don't blindly stamp the same code into each — match each view's existing top-bar rhythm.
- The orb must not block tap targets or compete with the timer for the user's eye.
- `LiveEloquenceHUD` is a transient overlay below the top bar; coexists naturally.
- Reduce-motion: the orb internally handles this. Don't add extra gates.

**Risk:** audio binding running at 30Hz could feel jittery if the smoothing coefficient is off. Tune by ear if needed. If a per-view feel is wrong, the smoothing constant lives in `SpeechRecognizerViewModel.audioLevelSmoothing` (static, single source).

**Validation:**
- `mcp__xcode-tools__BuildProject` → green
- Capture: `/noum-screenshots detailed` (mode is already set to `detailed` in `.claude/skills/noum-screenshots/.mode`). New captures should show the orb on practice setup screens.

---

### Phase 2 — "Noum heard you" on rep 1

**Goal:** replace generic stats on `FirstRepCelebration` with a *single coach observation that quotes the user's actual words*. Today: "You held for X seconds with Y fillers." Target: "You said *'um, the way I see it'* — three fillers in your opener. That's a tell, not a habit yet."

**Files:**
- `Noum/FirstRepCelebration.swift:38-300` — replace the subtitle pattern. Keep the character-driven hero composition; only change what's said.
- `Noum/ProofMomentService.swift` — must work for rep 1 (no prior session history). Today it expects a session to exist. Confirm.
- `Noum/ProofMomentArchive.swift` — store already handles idempotent rep-1 writes.
- `Noum/CoachContextBuilder.swift` — confirm `sessionOpener(mode:score:fillerCount:duration:voice:)` can produce a verbatim-quote variant.

**Hard requirement: deterministic fallback.** `AIInsightsService` has the pattern. If AI is cold/unavailable on rep 1, the fallback must STILL produce a quote-anchored observation — extract the most distinctive filler-cluster sentence from the transcript and frame it. The moment cannot fail. CLAUDE.md mandates "Real behavior verified, not assumed."

**Pair with Phase 1b's `.noticing` mood:** if the orb is now on the rep view (Phase 1b), the orb should flash `.noticing` when the proof lands on the celebration screen. Use the existing `moodPulse` extension (`Noum/NoumCharacter.swift:734`).

**Risk:** quoting the user's own filler back at them must not feel mocking. Voice-shaped framing matters. Look at `CoachContextBuilder`'s per-voice tone — authoritative gets a verdict register, warm gets a felt register.

---

### Phase 3 — Mode literacy without choice paralysis

**Goal:** lower the cost of "I don't know what Sudden Death is" without modal sheets.

**File:** `Noum/PracticeModeSelectionView.swift:141-560`

**Move:** each `PracticeModeOptionRow` gets a tap-to-expand "What this trains" affordance:
- 3 lines max
- *Pressure type* (e.g. "Hard time limit + zero tolerance for fillers.")
- *What it surfaces* (e.g. "Surfaces whether you reach for crutches under pressure.")
- *Typical rep length* (e.g. "30–90s rep.")
- Default state unchanged — the row keeps its existing one-line subtitle. Expand on chevron tap or row tap.

**Bonus (if scope permits):** the 28pt `NoumCharacter.Inline` appears inside the expanded section and visually narrates the mode summary. No audio.

**Constraints:**
- Pure additive. No reflow of the existing row layout when collapsed.
- Tests: existing `practiceMode.<id>` accessibility IDs must still resolve. The screenshot tour (`NoumUITests/ScreenshotTour.swift`) taps these.
- Reduce-motion: expansion animation respects the environment.

---

### Phase 4 — Home discipline

**Goal:** first 5 sessions, home shows max 3 cards. Cards aren't deleted — they unlock as signal accrues.

**File:** `Noum/ContentView.swift:284-1100` (the home composition block) + new `Noum/HomeSignalGate.swift` helper

**Gating rules (sketch, refine in implementation):**
- Always visible: `HomeCoachCard`, `HomeUtilityStrip`
- Path / Journey card: needs `PathProgressManager.shared` to have at least one unlocked node or a goal-set state
- Ask Noum promo card: visible from session 1 (already a Day-1 value)
- Daily Challenge tile: appears after first successful session
- VoiceMetricsCard: appears after session 1 (already gated by `displaysQualifyingData`)
- AI Weekly Insight card: appears after 3 sessions in current week
- Word of the Day tile: lives in HomeUtilityStrip already; no change

**Settings escape hatch:** add `practice.showAllHomeCards: Bool` AppStorage key, off by default. Surface in Settings as "Show all home cards (advanced)" — for power users who don't want the gradual reveal.

**Risk:** changes the home for everyone. Settings toggle is non-optional. Reversible.

---

## Sequencing recommendation

Phases can run in three modes:
1. **Serial in primary checkout** — me/Claude does them one by one
2. **Parallel via worktree agents** — multiple background agents, each gets a self-contained brief from this doc, results land on separate branches
3. **Hybrid** — heavy/sensitive phase serial, independent ones parallel

**Recommended order:**

1. **Merge Phase 5** onto `Redesign` (1 minute, manual git step)
2. **Phase 1b** — serial, here. Touches 5 practice views; each needs design care.
3. **Phase 2** — serial after Phase 1b lands, because it benefits from the orb's `.noticing` mood being live in the surface.
4. **Phases 3 and 4 in parallel** — independent files, no overlap with each other or with Phase 2.

If you want maximum parallelism right now: spawn Phases 3 and 4 as background worktree agents immediately, then do Phase 1b serially.

---

## How to run a parallel worktree agent (for Phases 3, 4)

The pattern that worked for Phase 5:

```
Agent(
  subagent_type: "general-purpose",
  isolation: "worktree",
  run_in_background: true,
  prompt: "<full self-contained brief from this doc>"
)
```

The agent's brief must:
- Reference `CLAUDE.md` requirements
- Reference VISION.md anti-goals
- Give exact file paths + line numbers
- State what NOT to change
- Specify the `xcodebuild build` validation command
- Say "do not commit — leave staged for human review"

A Phase 5–shaped prompt averages ~600 words. Phase 3 / 4 should each have a similar brief — use the briefs above as the starting body.

---

## Verification / validation

**Build (any phase):**
```sh
xcodebuild build -project Noum.xcodeproj -scheme Noum \
  -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' \
  -configuration Debug
```

Or via Xcode tools: `mcp__xcode-tools__BuildProject` (faster in-IDE).

**Per-file diagnostics:** `mcp__xcode-tools__XcodeRefreshCodeIssuesInFile` — sub-second compile errors before running a full build.

**Screenshots (post-phase):** `/noum-screenshots detailed` invokes the skill. Mode is already set to `detailed` at `.claude/skills/noum-screenshots/.mode`. The tour runs `xcodebuild test` against `NoumUITests/ScreenshotTour` — be aware test target was failing pre-2026-05-21 on the proof-moments tests; the fix (added `@MainActor` to `ProofMomentArchiveTests`) is in `NoumTests/NoumTests.swift:5802`. Confirm this fix is still present before running screenshots.

**Captures land in:** `.screenshots/<date>_<slug>/` with a `HANDOFF.md`. PNGs gitignored; HANDOFF committed.

---

## Anti-pattern reminders

- Don't add a Localizable.xcstrings entry for every new string. Most of the app is still English-only; M13 only migrated ~30 keys. Hardcoded English in M15 is fine.
- Don't create new state managers. M15 touches existing stores only.
- Don't add comments that explain what the code does — only why. CLAUDE.md.
- Don't ship "loading…" placeholders or empty toggle states. CLAUDE.md.
- Don't celebrate fake progress. VISION.md "Anti-goals." If the rep was bad, the coach says so honestly — soft when evidence is weak, firmer with repeated patterns. (`Noum/CoachContextBuilder.swift` is your reference for tone.)

---

## Quick reference — key files

| Topic | File | Notes |
|-------|------|-------|
| Character | `Noum/NoumCharacter.swift` | Phase 1 changes ✓; `audioLevel:` param ready for consumers |
| Audio amplitude | `Noum/SpeechRecognizerViewModel.swift` | `audioLevel` published; consume in Phase 1b |
| Ask Noum | `Noum/AskNoumView.swift` | `.thinking` orb live ✓ |
| Proof Moments | `Noum/ProofMomentArchive.swift`, `Noum/ProofMomentService.swift` | Used by Phase 2, 5 |
| First Rep | `Noum/FirstRepCelebration.swift` | Phase 2 target |
| Mode picker | `Noum/PracticeModeSelectionView.swift` | Phase 3 target |
| Home | `Noum/ContentView.swift` (home block) | Phase 4 target |
| Profile | `ProfileView.swift` | Phase 5 (worktree) |
| Tour | `NoumUITests/ScreenshotTour.swift` | Test fix in `NoumTests/NoumTests.swift:5802` (added `@MainActor`) — keep |
| Design tokens | `Noum/DesignSystem.swift`, `Noum/Typography.swift` | Single source of truth |
| Brand voice | `.claude/skills/noum-design/SKILL.md` | Voice rules |

---

## One-paragraph elevator pitch for the LLM doing the work

You're shipping M15 — five small, coherent changes that turn Noum from a strong analytics-flavored coach app into one where the user feels a real coach is present. Your through-line is the Noum orb: it now has new moods (`.thinking`, `.noticing`) and can bind to live audio amplitude (`audioLevel`). Use this through-line in every phase. Day-1 payoff comes from Phase 2 (the coach quotes the user's actual words back to them after rep 1). Home gets cleaner (Phase 4). Mode literacy gets fixed (Phase 3). And there's a small, restrained "insights banked" counter (Phase 5, already in a worktree) that surfaces growth without dopamine-loop mechanics. Honour VISION.md anti-goals — *no* shallow gamification, *no* hearts-and-lives, *no* streak shaming. The coach is real because what they say is specific to the user's words. That's the loop.
