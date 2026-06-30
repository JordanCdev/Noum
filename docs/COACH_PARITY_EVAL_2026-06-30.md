# Coach-parity eval — 2026-06-30 (autonomous `noum-1` run)

**17th iteration.** Two things shipped, both verified GREEN on device-class
simulator (iPhone 17 Pro / iOS 26.3 / Xcode 26.3), no push:

1. **Landed + corrected a stranded coach-chat reliability increment** that a
   prior concurrent session left uncommitted with a *broken test build*. Commit
   `ec40e99b`.
2. **Shipped Lever A — the positional rep-event coach read** (the one
   ship-now / collision-safe / non-human-gated lever a fresh 6-role panel
   surfaced and adversarially verified). Commit pending below.

Method this run: rather than a 17th near-identical scorecard, I (a) verified and
finished the in-flight diff, (b) ran the role panel the brief asks for — market
analyst · veteran coach · senior UX · skeptical end-user · staff engineer ·
QA-honesty adversary → adversarial verification of each named lever against the
actual code → synthesis — and (c) built the single lever that survived
verification as honestly buildable unattended.

---

## Score: **7.5 / 10** (was 7.4)

Per-lens panel scores: veteran-coach 7.5 · market-analyst 7.0 · skeptical
end-user 6.5 · staff-engineer 7.5 · QA-honesty 8.0. (The UX agent errored on a
schema retry cap; 5 of 6 returned, enough signal.)

The movement is small and earned: it reflects real reliability logic landing
(not theater) plus this run closing the two ceiling items the panel itself
flagged:

- **(a) A live false-attunement defect** the in-flight diff introduced — the
  bare `"what i meant"` / `"actual question"` / `"real question"` tokens added
  to `TurnDepthClassifier.isTrustRepair` fired on *benign self-clarification*
  ("what I meant was…", "my real question is about pace"), misrouting to
  `.trustRepair` → hard block → a phantom "you're right to push me" apology
  (a direct "coaching must avoid overclaiming" violation). **Fixed this run:**
  removed the polysemous bare tokens, kept the unambiguous "answer(ed) what i
  meant" pushback forms; intent mismatch on non-pushback turns is already
  handled at reply level by the new `missingIntentFit` gate. +2 regression tests
  (`benignSelfClarificationIsNotTrustRepair`, `explicitDidNotAnswerWhatIMeantIsTrustRepair`).
- **(b) The richest positional signal in the app was computed-then-discarded.**
  `TranscriptTimeline` + the captured per-word timings existed but had **zero
  production callers** — the coach could say "your average pace was high" but
  never "you rushed at the *close*". **Wired this run** as Lever A.

## Per-rival delta (still ahead on X)

- **Speeko** — real-time in-the-moment polish prompts as the *core* loop (Noum
  substantially matches via FillerAlertGate + LiveEloquenceHUD, but Speeko leads
  on the live-coach framing).
- **Orai** — the annotated playback surface: your words back with each
  filler/pause/rushed stretch marked *where it happened*. Noum now computes the
  positional read (Lever A) and the timeline substrate, but still renders only
  aggregate pills (the render is the deferred next slice).
- **Yoodli** — multi-persona voice/video roleplay breadth + enterprise-validated
  analytics at scale (a wide, genuinely human-gated moat).
- **Duolingo** — habit-loop retention / streak-grade engagement at mass scale
  (a gap Noum keeps *partly by design* per CLAUDE.md's anti-gamification stance).

---

## What shipped #1 — coach-chat reliability increment (`ec40e99b`)

A prior session left ~5,100 lines uncommitted on the hot coach-chat surface.
The app target compiled; the **test target did not** (a referenced
`evaluateLiveLongFormConversation` live-harness helper was never defined). This
run:

- **`missingIntentFit` semantic gate** (`AICoachChatService`) — catches the
  coach answering a *neighboring* coaching task (example / why / check / capture
  / keep-change / threshold) instead of the user's actual ask; threads
  `latestUserTurn` through the gate and adds `replyIsGroundedInConversationFollowUp`
  so genuine follow-ups are no longer mis-flagged unanchored. This is the direct
  answer to the recurring "same response back / didn't answer what I meant"
  complaint.
- **`noAttunementOnPushback` promoted to a HARD block** — a trust-repair turn
  that opens by prescribing instead of acknowledging now gets the deterministic
  repair read substituted.
- **Near-duplicate plumbing** + **long-form conversation eval-report schema** +
  selectors with 3 keyless unit tests.
- **Honest completion of the broken test build:** rather than fabricate ~200
  lines of live-only driver code that cannot be runtime-verified in an
  unattended/keyless run, kept all verifiable structural work and **deferred the
  one live multi-turn driver** with an explicit marker. The live run now reports
  zero long-form rows rather than silently passing unevaluated turns.
- **Fixed the false-attunement defect** (above).

Verification: build-for-testing GREEN; `CoachJudgementLayerTests` +
`CoachReliabilityGateTests` + `CoachChatConversationEvaluationTests` +
`CoachLiveEvaluationTests` all pass (56/0 on the focused fix run).

## What shipped #2 — Lever A: positional rep-event coach read

The one lever that survived adversarial verification as *real-and-buildable /
ship-now-unattended* (the other four were correctly already-deferred,
collision-unsafe-now, or premise-invalid — see roadmap below).

- **New pure engine** `Noum/RepEventLocations.swift` — `RepEventLocationsEngine.derive(timeline:)`
  reduces a `TranscriptTimeline` to a small Codable summary: the zone
  (opening / middle / close third) and magnitude of the longest pause, the
  fastest rushed burst, and a filler cluster (>= 2 in one zone). Returns **nil**
  unless at least one credible positional signal exists — a single stray filler
  never becomes a "you cluster fillers" claim. **Introduces no new pace/pause
  threshold** (reuses the timeline's existing edges); the only construct is the
  coarse third, documented as a readout aid, not a tuning knob.
- **Persisted on the session** mirroring `vocalEnergyMetrics` 1:1 — optional
  Codable field on `PracticeSession` (`decodeIfPresent`, so old sessions decode
  unchanged), threaded through `PracticeSessionDraft` / `PracticeSessionFinalizer`,
  computed at `finalizeTranscript` from the captured per-word timings.
- **Surfaced to the coach** — one `lines.append` in `CoachContextBuilder`'s
  most-recent-rep block, beside the existing Composure / Confidence / Structural
  reads. The coach can now locate a problem ("you rushed at the close") instead
  of only naming a whole-rep average.
- **9 new unit tests** (`RepEventLocationsEngineTests`) — nil-guards, pause/burst
  zone selection, third boundaries, the >= 2 filler-cluster floor, deterministic
  tie-break, and readout-names-only-present-signals.

Disjoint from the hot coach-chat surface; no calibration debt; no overclaim.
This raises *intervention precision*, NOT the perception or validation axes — no
parity claim is implied. It is also the honest prerequisite for the deferred
render (it persists the positional summary that render would draw).

---

## Prioritized roadmap (post-verification)

### (A) Ship-now, collision-safe, non-human-gated — DONE this run
Lever A above (wire `TranscriptTimeline` → positional rep-event read).

### (B) Defer to a device-owning session (buildable, but felt-QA / hot-surface gated)
- **Render the annotated transcript timeline in the rep review surface**
  (`SummaryView`) — engine + positional read are now done and green, but the
  render is human-gated on reduced-motion + VoiceOver + visual-correctness
  felt-QA. Lever A is its honest data prerequisite.
- **Pin the prompt through rep #1 for first-time users** (`TimedPracticeView`) —
  code-safe but overrides a deliberately default-OFF first-rep UX choice; same
  felt-QA gate as `AutoGuidedFirstRep`.

### (C) Human-gated / rejected
- **Promote felt-experience reflection above the score drawer** — *rejected*:
  premise factually wrong (the `ReflectionFeeling` chip row is unbuilt UI with
  zero production callers; this would be net-new feature work reversing a
  git-documented M16 IA decision on the hero surface). Belongs in a human-led
  design session.

---

## The honest 10/10 answer (unchanged, by design)

Literal "with no doubt replaces a human coach, 10/10" stays **refused by design**
via `CoachParityReadiness.forming` — a deliberate trust moat enforced by
CLAUDE.md's no-"replaces-a-human-coach" claim and "coaching must avoid
overclaiming." An app that asserted coach-replacement on audio-token proxies
would be lying. The three genuinely-remaining gaps are all human-gated and
unreachable by an unattended agent:

1. **Perception depth** — breath catch, throat tension, eyes dropping on the
   hard sentence, the tremor under a "polished" answer. A phone mic reads the
   *words produced*, not the *state the speaker was in*. Needs a real delivery
   signal + device QA only Jordan can supply.
2. **Externally-calibrated scoring** — coach quality is still proxied by
   substring/threshold heuristics; "intent fit" and "attunement" are phrase
   lists, not understanding. Honestly closing it needs expert-coach labeling of
   the bands + live-provider transcript sweeps.
3. **Longitudinal outcome proof** — no evidence yet that following Noum's
   recommendations improved a real user's real interview/pitch/conversation.
   Needs real-user outcome data over time.

The tree scores high on honesty *because* it is candid about all three (the
18/100 eval-substrate cap, the `.forming` readiness). The residual
heuristic-as-judgement substrate — the exact thing this run's own `"what i
meant"` false positive exposed and this run then fixed — is the ceiling no
amount of unattended code can lift.

## Connectors note

Figma + Canva MCP connectors are live in this environment but were **not**
auto-triggered: they perform external writes (publishing designs), which an
unattended run should not initiate without a human in the loop. The deferred
(B) render is the right place to use Figma — in a device-owning session where
Jordan can review the visual.
