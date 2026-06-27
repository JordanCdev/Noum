# Coach-parity eval — 2026-06-27 (autonomous `noum2` run)

Branch: `ux-overhaul`. Method: ship-first, not re-score. The prior 8 evals
already converged at an honest **7.5/10**; this run spent its budget *shipping
verified code* toward the realistic ~9 ceiling rather than producing a 9th
scorecard. A 4-role audit panel (cold end-user · market/competitive · UX-honesty
· Swift-eng/QA) + synthesis fed the work; every finding was verified against
source before landing.

## Score

**Holds at 7.5/10.** No movement claimed. The single biggest lever
(`AutoGuidedFirstRep.enabled` flag-flip + on-device felt-QA) remains human-only,
so the *number* can't move in a headless run — but the experience behind that
flag is now materially better (instant start), and three correctness/honesty
defects were removed.

## Shipped this run (build + test verified, iPhone 17 sim, not pushed)

Two commits, both staged with explicit pathspecs so a concurrent session's
in-flight ~7-file coach-brain diff was preserved byte-for-byte.

**`2babca4` — auto-guided first-rep instant-start (closes the 15s gap).**
The highest-leverage first-rep move, blocked across the last several runs by
contention on `TimedPracticeView`. The mic-readiness-guard prerequisite has
landed and the tree was clear, so it shipped. Per-rep one-shot
(`AutoGuidedFirstRep.fastStartOnce`, armed at the fork, consumed once in the
QuickStart handshake) drives *this rep only* via `effectiveThinkingTime` (off) +
`effectiveKeepPromptVisible` (on) — the user's persistent prefs are never
written. Default-OFF (gated by `AutoGuidedFirstRep.enabled`). +4 tests.

**`55bbd57` — three fixes from the audit panel:**
1. **fast-start leak (regression in `2babca4`):** `resetState` didn't reset
   `fastStartActive`, so a retry/new-prompt rep #2 in the same view silently
   inherited instant-start. Fixed.
2. **delayed-finalize race (high):** `stopRecording()` finalizes on a 500ms
   delay; a new session in that window (live-coach push-to-talk re-tap,
   back-to-back Sudden Death) corrupted the new rep / blended metrics. Added a
   `sessionGeneration` token + pure `shouldFinalize` predicate; teardown +
   finalize bail if a newer session started. Happy path unchanged. +4 tests.
3. **honesty-signal inversion (medium):** the rule-based template fallback
   (`isAIBacked == false`) was badged **"Live"** — the opposite of the truth and
   inconsistent with every other provenance surface. Relabeled **"Rule-based"**;
   added the missing VoiceOver label on the debrief card.
   Plus: extracted `LeagueManager.shouldCelebratePromotion` (pure, behaviour-
   identical) so the `league_promotion_guard` invariant finally has tests. +5 tests.

## Deferred — NOT shipped headless (by design)

**Universal first-rep fast-start (audit finding #5, high leverage):** make the
*picker/Home* "Begin" first-ever rep also skip the 15s countdown (today only the
default-OFF auto-guided path does). The plumbing exists, but this changes the
live cold-start experience for **every** new user with no device felt-QA — which
is exactly why `AutoGuidedFirstRep` is default-OFF. Shipping it blind would
violate that discipline. Captured as a spec:
`docs/SPEC_first_rep_fast_start_universal.md`. Land it on Jordan's device session.

## What only Jordan can unblock (human-only levers)

1. **Flip `AutoGuidedFirstRep.enabled` + felt-QA on a real device** — the
   simulator has no mic, so only a device can certify mic-arms-once / no-echo /
   <30s-to-first-word / honest-read. Highest-leverage single action; converts the
   largest dark asset into the A* demo moment. Now QA's the *good* (instant-start)
   version, not the worst (15s countdown).
2. **Universal fast-start felt-QA** (the deferred spec above) — code-shippable,
   but whether instant mic-open feels calm vs abrupt for a first-timer is a
   device judgment.
3. **Cloud-STT on-device fallback decision** — product call vs the STT philosophy.
4. **Deferred-signup decision** — speak before the 3 onboarding questions.
5. **Video-into-coach-memory decision** — multi-week architecture commitment.

## Honest ceiling statement

Noum sits at an honest **7.5/10** vs human-coach parity. With the flag flipped
(after this run's instant-start + the universal fast-start) it realistically
reaches **~9/10** on the achievable axis: it matches the leaders' "one tap to
speaking" table-stakes while keeping the case file, the real-world-transfer loop,
and the anti-overclaim honesty that Speeko/Orai/Yoodli/Duolingo don't have. The
permanent gap to a literal **10/10 "with no doubt replaces a human coach" is the
trust moat itself** — `CoachParityReadiness` structurally refuses to self-certify
parity (`.forming` cap, `Noum/CoachParityReadiness.swift`). That refusal is
correct product design; keep it. Close the first 30 seconds, not the moat.

## Verification

- Both commits: build + targeted suites green on iPhone 17 sim
  (`AutoGuidedFirstRepTests`, `SpeechFinalizeGuardTests`, `LeaguePromotionGuardTests`
  — 36/36, **TEST SUCCEEDED**), full app target compiles.
- Every audit finding verified against source (isAIBacked semantics at
  `AIInsightsService.swift:45`; race in `stopRecording`; resetState omission;
  promotion guard inline at `recomputeTierAndBucket`) before any edit.
- **Not run (honest):** on-device felt-QA of the cold-start moment and the
  fast-start *feel* — requires a physical device + microphone.
- **Not pushed** — consistent with every prior continuation; Jordan reviews first.
