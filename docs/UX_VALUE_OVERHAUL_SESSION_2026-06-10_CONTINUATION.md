# Noum overhaul — session continuation 2026-06-10

Branch: `ux-overhaul`
Mode: autonomous scheduled run (`noum-1`), no user present.
Toolchain: real (Xcode 26.x on this Mac) — every "verified" claim below is
compiled + tested on the iPhone 17 simulator, not hand-traced. The evaluation
subagents were sandboxed (read-only, no toolchain); their findings were
re-verified here against the real build and, importantly, against the actual
code (the strategist corrected several stale evaluator findings — see below).

## TL;DR

- The prior iterations (1–7) are landed. This session verified the **uncommitted
  in-flight tree** (GoalJourney removal + displayed-streak consolidation + goal
  grounding + several "make the wedge felt" surfaces) builds clean and passes
  the **full `NoumTests` suite: 2,273 / 0 fail**, then committed it (`e22a786`).
- Ran a fresh **10-agent multi-role evaluation** (market researcher, UX designer,
  cold + returning end-users, communications-coaching expert, QA/trust auditor →
  strategist synthesis → 3 engineer specs). Honest defensible score: **7/10** on
  the depth+trust axis (feels more coach-like than Speeko/Orai/Yoodli). The
  literal "10/10 that with no doubt replaces a human coach" answer is **no**, and
  the app is correct to never claim it (see Limitations).
- Shipped two owner-local, fully unit-tested fixes from the ranked backlog:
  **REMEMBER-4 coherence** (the durable case file no longer quotes a stale
  upcoming moment) and **cold-start copy** (benefit-first, depth-curve legible).
- The remaining high-leverage backlog is documented with engineer-grade specs
  below; the items left unimplemented are **SwiftUI visual changes that need
  simulator/screenshot QA** an autonomous run can't honestly verify, plus the
  human-gated validation items no code can close.

## A concurrency note for the next agent

A **separate automated verification harness was running concurrently** this
session (a parallel scheduled task / loop doing `xcodebuild clean build` and the
full `NoumTests` run against the same `./DerivedData/Noum`). It periodically held
the XCBuild DB lock and false-failed two of my full-suite runs with
`mkstemp`/`Channel disconnected` result-bundle errors — **infrastructure, not
test failures**. If you see those, it's lock contention: run focused suites with
an explicit `-resultBundlePath /tmp/...`, or use a separate `-derivedDataPath`,
and don't fight the other process. I let its run be authoritative for the
full-suite green.

## What shipped (verified)

### Commit `e22a786` — Consolidate streak ownership + ground prescription in goal

The in-flight work, validated as coherent, end-to-end wired, and
honest-by-construction, then committed:

- **Dead `GoalJourney` system removed** (engine/store/step/tests — fully
  unreferenced; grep-confirmed no dangling symbols).
- **Displayed-streak consolidation** (closes `path_and_streak_fragmentation`):
  `StreakFreezeManager.currentStreak` is now the single freeze-aware owner every
  user-facing streak reads (Home status line + recommendation-engine input), so
  a freeze can never make the number look like a bug.
- **Home streak status line** — quiet, ≥2-day, no countdown/loss-aversion, fail-
  quiet defaults, a11y id `home.streakStatus`.
- **Goal-grounding line under Coach Pick** — ties the ONE prescribed rep to the
  user's stated goal via the measured `distanceFromGoal` read; self-suppresses on
  no profile, due goal check-in, or thin baseline.
- Live-call landing line, Ask Noum chat continuation surface, Profile
  resolved-weakness payoff, goal-grounded practice copy. +483 lines of tests.

### Commit `<pending>` — REMEMBER-4 coherence + cold-start legibility

1. **REMEMBER-4 coherence (ranked #2, the actual bug).** The persisted
   `CoachCaseFile.upcomingMomentLine` was re-derived only on the *primary*
   memory rebuild (`SessionFinalizer` → `CoachMemoryEngine.build`). The four+
   *incremental* rebuild sites in `CoachMemoryStore` (`noteReflection` ×2,
   `noteHypothesisAcknowledgement`, `noteVoiceChange`, `noteTransferOutcome`)
   carried the OLD value forward (`memory.caseFile?.upcomingMomentLine`). So if
   the user added or changed a real-world moment between full refreshes, the
   durable case could quote a stale or absent moment — the coherence spine
   (goal + baseline + pattern + nearest moment) drifted.
   - Fix: each rebuild site now re-derives from the **live** store. Added an
     `upcomingMoment: BigMoment??` parameter (outer `nil` default = read the live
     `BigMomentStore.shared.activeMoment`; `.some(...)` injects for tests — a
     default arg can't reference main-actor state, hence the double optional).
     Production callers are unchanged and correct-by-default.
   - Test: `CoachMemoryStoreTests.incrementalRebuildReDerivesUpcomingMomentFromCurrentMoment`
     — swap moment A→B then fire an incremental rebuild → case quotes B not A;
     inject "no moment" → line drops (no stale text). Regression slice over
     `CoachMemoryStoreTests` + `CoachMemoryEngineTests` + `CoachContextBuilderTests`
     + `CoachContextBuilderBigMomentTests`: TEST SUCCEEDED.

2. **Cold-start copy (ranked #4).** `HomeAskNoumEvidenceCopy.line(sessionCount:)`
   was method-first ("I'll keep the read light") — every evaluator flagged it as
   reading like a *limitation* at the moment of lowest patience, losing the
   mental-model battle to Orai's visible 4-week plan and Duolingo's first-session
   warmth. Reframed the cold-start (0-rep) and 1-rep lines benefit-first and made
   the depth curve legible ("…name the first lever worth training. A few more,
   and I'll name your core move.") while preserving every pinned honesty
   substring (no "30 days", no "baseline", no fabricated history). New test
   `coldCopyMakesTheDepthCurveLegibleWithoutFabricatingHistory`.

## Evaluation verdict (10-agent panel, code-ground-truth corrected)

Role scores: market 5.5 · UX 7.2 · cold-start user 5.5 · returning user 6.5 ·
coaching expert 6.2 · QA/trust 8.2. **Strategist synthesis: 7/10 defensible.**

The strategist verified findings against the actual tree and **retired several
stale evaluator claims** — do not re-spend these, they are already wired:
TRANSFER-3 (Profile renders `ProfileTransferStatusContent` from the trend
reducer), cold-start `coachLoopReadinessCard` (Profile), and chat quoting
(`CoachReplyPipeline` threads `ProofMomentStore.recent` as `verifiedProofQuotes`).

### Per-competitor (web-grounded against the handover competitor delta)

- **Speeko** — Noum ahead on durable memory + honesty + quote verification;
  behind on real-time in-call coaching and delivery-sensing breadth. Don't chase
  breadth; close the felt-presence gap.
- **Orai** — Noum is the deeper coach but loses the first-90-seconds clarity
  battle (Orai's 4-week plan is a visible day-1 artifact). Fix is legibility, not
  a rigid plan. (Partially addressed this session by #4.)
- **Yoodli** — different games. Noum wins solo depth+trust; Yoodli owns
  teams/breadth/roleplay. Deliberate non-goal, not a defect.
- **Duolingo** — Noum ahead on honesty/restraint (asymmetric earned-only motion,
  fail-quiet streak, no theater); behind on first-session warmth. Borrow the
  warmth WITHOUT the gamification — benefit-first copy + synchronous earned
  moments, not XP/streaks. (Partially addressed by #4.)

## Ranked remaining backlog (owner-local, code-tickable, no red-line risk)

Left unimplemented this run because each is a **SwiftUI visual change that needs
simulator/screenshot QA** to verify honestly (the light-capture route currently
lands tabs on the wrong surface — see handover), or is Medium-risk on the
finalize/summary hot path. All have engineer specs in the workflow result.

1. **Proof moment lands synchronously in the post-rep beat** (M, high) —
   `SummaryView`/`PostRepCoachNoteService`/`PracticeSupport`. Today
   `loadPersonalBestProof()` runs `.task { await }` ~0.5s after the summary
   paints, fracturing the single most coach-like moment (Noum quoting your own
   verified words the instant you finish). Pre-resolve the proof in the
   finalization payload with reserved layout space; deterministic fallback, never
   a spinner. *Risk: a synchronous proof call in finalize can touch a 14s
   URLSession timeout — needs a hard ≤2s ceiling and careful main-actor handling.
   Do NOT use `DispatchSemaphore` on the main actor.*
2. **Auto-seed the post-rep summary into the Ask Noum thread by default** (M,
   high) — `SessionFinalizer`/`SummaryView`. `onAskNoumAboutRep` already exists
   and uses `AskNoumStore.shared.injectUserTurn`; make continuity the default
   state of the thread (warm when opened) without auto-navigating. Same store,
   same route, no second coach door.
3. **Rep-1 named prescription instead of a data recap** (M, high) —
   `PostRepCoachNoteService`. On reps 1–2 the note reads as data ("you logged 7
   fillers; baseline still forming") rather than coaching. Pair the honest
   evidence caveat with ONE deterministic, mode-appropriate next move drawn from
   the rep's own weakest measured signal. Preserve weak-evidence→softer-feedback;
   verify no causation claim.
4. **Verified-quote provenance affordance** (S, medium) — `SummaryCards`. Noum's
   strongest technical edge (quote verification through
   `ProofMomentService.transcriptContains`) is invisible. Add a quiet "your
   words / from your Wed rep" provenance line on quotes that already passed the
   guard. Strictly no "verified vs competitors" / parity framing.
5. **Restrained earned-motion on the rating tick + resolved-weakness line** (S,
   medium) — `ProfileView`. `ProfileRatingTickMotion` already animates only on a
   new weekly best (asymmetric, never on drops). Add a brief upward-only glow +
   single `UIImpactFeedback(.medium)` and a 0.3–0.4s fade/scale-in, gated behind
   Reduce Motion. Pure upward celebration; honors never-punish-shame.
6. **Rep-1 score success-bar explainer** (S, medium) — `PrimaryFocusMemory`
   `buildSuccessCriterion` (thin-data branch) → `SummaryView`. On rep 1 frame the
   ring as "this is your baseline, not a grade"; show the soft personalized bar
   once 2–3 reps exist.

## Genuine limitations — the honest answer to "10/10, replaces a human coach"

No. A self-certified "10/10 replacement" would itself violate Noum's honesty
contract — and notably `CoachParityReadiness` structurally caps validation at
`.forming` and **never returns `.earned`**, which is the most trustworthy thing
in the product. The ~3-point gap from 7 to 10 is overwhelmingly **not code**:

- **Perception ceiling (architectural/sensor).** Audio-only: ~4 baseline-relative
  channels + pause + composure. Cannot sense prosody contour, pitch range,
  breathing, emphasis, eye contact, gesture, or whether clean speech still feels
  evasive. `VideoAnalysisService` is thin/orphaned and sequenced last. This is the
  largest single chunk of the gap; it needs a new sensor modality, not a call-site
  change.
- **Expert calibration (VALIDATE-2, human-gated).** Requires real executive
  coaches scoring Noum's reads against the same transcripts.
- **Longitudinal outcomes (VALIDATE-3, human + time-gated).** Proof that real
  users measurably improve over 6–12 weeks cannot be manufactured in code. The
  transfer-trend reducer (`minimumReports=3`) is the substrate for surfacing it
  once it exists.
- **Felt LLM quality (VALIDATE-4, provider-key + on-device gated).** Whether the
  reads *feel* like a warm, clear, real coach is judgeable only by on-device QA
  with real provider keys on hardware. Agents can harden guards, not certify warmth.
- **60-second cold-start unproven on hardware.** Fake-delay path is removed and
  UI-test hooks exist; no real-device timed ask→speak→read run exists.
- **Hardware cold-start timing (real-device-gated).** Streak calendar-boundary
  behavior, the app-icon badge contract, and freeze nudge timing need real-device
  calendar transitions; fail-quiet display gate is sound but the live timing
  contract needs manual hardware QA.

**Bottom line.** The credible, defensible target is "feels more coach-like than
Speeko/Orai/Yoodli on the depth + trust axis" — a real 7/10 wedge reached by
closing the coaching loop and making the existing honesty *felt* (legible
cold-start, synchronous proof, warm continuity, visible provenance). Parity is
provable only by expert calibration + real users improving over time. Continue
pushing felt-depth and legibility; do not let the score tempt a parity claim.

## Connectors checked

- **Figma MCP** (`@figma`) and **Canva MCP** are both connected in this
  environment. Neither was exercised: the highest-leverage work this session was
  a correctness bug + copy + an evaluation, none of which needed a new visual
  artifact. The next session that takes on the visual backlog (items 4–6, the
  felt-motion + provenance work) should use Figma to spec the provenance chip and
  earned-motion timing against the existing design tokens before implementing.
- No additional connectors are required for the remaining code-tickable backlog.
  The human-gated validation items need a real provider key + a physical device,
  which are out of an agent's reach.
