# Coach-parity evaluation — 2026-06-20

Branch: `ux-overhaul` · HEAD at eval: `b085d51`
Method: 33-agent `coach-parity-eval` workflow (6 role agents → adversarial gap
verification → strategist synthesis). 44 raw findings → 26 high-value candidates
→ **17 confirmed** as real or partial gaps after code-grounded verification.

Predecessor: `docs/COACH_PARITY_EVAL_2026-06-14.md` (7.1/10).

## Honest score: 6.5 / 10

The drop vs the 06-14 number is **not a regression** — it is a more critical,
beginner-weighted panel. Since 06-14 the tree gained rank-1 emotional-read
visibility (`985ba09`), the rank-2 call-landing anchor (`16151f9`), and the
chat-quote contraction fix (`b085d51`); none of those regressed. The new panel
simply weighted the **first-90-seconds adoption moment** and the **north-star
transfer loop** harder, and those are the two weakest dimensions.

### Role scores

| Role | Score |
|------|-------|
| market-research | 6.5 |
| ux-designer | 5.5 |
| end-user (beginner) | 4.0 |
| end-user (power) | 6.5 |
| coach-expert | 7.2 |
| qa-tester | 7.1 |

The beginner role (4.0) is the floor and the headline story: depth is real but
**invisible at the moments that decide adoption**.

### Verdict (strategist synthesis)

> Noum has built the most honest, architecturally serious coaching substrate in
> its category — transcript-verified quote guards, evidence-scaled confidence, a
> durable `CoachCaseFile`, and deterministic fallbacks that refuse to overclaim.
> On trust architecture and long-term retention potential it genuinely beats
> Speeko/Orai/Yoodli/Duolingo. But the goal is "credibly rival the leaders AND
> approach coach parity," and the headline blocker is that the intelligence is
> **invisible at exactly the moments that decide adoption and felt-coaching**:
> the first 90 seconds still routes through a picker tap (time-to-first-spoken-
> word > 60s), the coach never opens with the remembered plan in a visible way,
> and the north-star transfer loop stores outcomes but never debriefs them or
> feeds them back into the next plan. The product still feels closer to an honest
> speaking mirror than a retained coach. **It can credibly rival the leaders on
> trust today; it cannot yet claim coach parity, and the gap is overwhelmingly
> visibility-and-loop-closure, not new analysis.**

## 10-point scorecard

| Dimension | Score | Note |
|-----------|-------|------|
| Perception | 6.5 | Four-channel composure/confidence read, honestly gated with "early read" framing when <3 channels contribute. Ceiling: pitch-CV only; true prosody/intensity-envelope/breathing need new DSP. |
| Case formulation | 7.0 | `CoachCaseFile` spine injected into every turn; stated-vs-measured concordance. Weaker than a human on live clarifying questions / revising on disagreement. |
| Intervention | 7.0 | Drills prescribed with observable targets + success measures; goal-aware end to end. Human still designs against room/audience/stake, not just the metric. |
| Adaptation | 6.0 | Bounded reinforce/vary/replace verdicts exist and are honest, but the reasoning is **invisible at the adaptation moment** — user never sees "I'm changing your drill because X across 3 reps." |
| Transfer | 4.5 | Lowest vs north-star weight. Infrastructure end to end, but NO felt loop: one deterministic ack, no AI debrief, and `ForwardPlanService` does **not** read `outcomeReports` so the next plan ignores real-world results. |
| First-run | 4.0 | Biggest adoption blocker. Onboarding lands on the picker; time-to-first-spoken-word > 60s; no auto-guided first rep, no "your first read" framing. End-to-end cold-start <60s unproven on a real build. |
| Delight / retention | 6.0 | Honest celebration gating, no fake progress, asymmetric motion. Lacks Duolingo's "one small session, visible progress" felt loop. |
| Competitive position | 6.5 | Wins decisively on trust/memory/verified-proof (real moat). Cedes the first-90-seconds; push-to-talk vs continuous-listening is a felt difference. |
| Trust / honesty | 8.0 | **Strongest dimension.** Quote guard robust + well-tested; thin-data self-suppression; cold-start Peak/rating gated on `hasRatedEvidence`. |
| Premium feel | 6.5 | Clean typography, restrained motion, coherent card language. Undercut by residual density and coach replies reading as prose, not a structured read. |

## Prioritized roadmap (next highest-value BUILDABLE slices)

1. **Close the first 60 seconds** (M) — onboarding → auto-guided ~20-30s first
   rep → one honest "your first read" (fillers, wpm), no celebration, no paywall.
   Reuse the existing session-start path; feature-flag the auto-route; keep a
   one-tap escape to the picker. *Files:* `CoachingOnboardingView.swift:561`
   (cut deep-link), `ContentView.swift`, `PracticeModeSelectionView.swift` /
   `TimedPracticeView`, `SummaryView.swift`.
   **Felt-QA gated:** must verify cold-start AND returning-user branches on a
   real build via xcresult, not UI-test injection — a delicate change to the most
   important UX moment. Spec it; do not blind-build autonomously.

2. **Transfer debrief + plan-adaptation loop** (L) — new `PostTransferCoachNote`
   service mirroring `PostRepCoachNoteService`: after an outcome report, one
   optional 2-3 sentence debrief (what seemed to carry / one tentative pattern /
   one next move), strict no-causation copy through the same quote guard. Then
   wire `BigMomentStore.outcomeReports` into `ForwardPlanInput` so the next plan
   adapts. Reuse `CoachMemoryStore.noteTransferOutcome`; add no new store.
   *Files:* new `PostTransferCoachNote.swift`, `BigMomentOutcomeInlineCard.swift:188`,
   `ForwardPlanService.swift`, `CoachContextBuilder.swift`, `NoumTests.swift`.
   **Buildable core, felt copy gated:** the `ForwardPlanInput` wiring is pure and
   unit-testable; the debrief *wording* wants felt QA. Highest north-star value.

   **↳ CORE SHIPPED 2026-06-21** (`PLAN-TRANSFER`, autonomous `noum-1`,
   adversarially reviewed): the pure half — wiring real-world outcomes into the
   planner so the next plan *stops ignoring* real results. `ForwardPlanInput`
   now carries `transferOutcomes`; the AI path injects the existing
   `BigMomentStore.transferTrends` `contextLine` (the SAME honesty-gated,
   no-causation aggregator the live coach reads) plus a planner rule to bridge
   rehearsal→room when prep hasn't been carrying; the deterministic Week-4 mock
   gains a forward-looking, no-causation bridge clause when the active moment's
   category shows a clear `.didNotTransfer` plurality. Honesty floor enforced on
   the transfer-read count itself (not just total reports — a leak the
   adversarial review caught and that's now regression-tested). Strict-plurality
   + category-scoped + never echoes "fell short." 8 new tests, full
   `ForwardPlanServiceDeterministicTests` green. **Still owed (the felt half):**
   (a) the `PostTransferCoachNote` report-time debrief, and (b) **adaptation
   provenance** — a visible "you told me X → I changed the plan" receipt at the
   plan card (`CoachingPlanCard.swift:178`); the loop now closes in the engine
   but is still unfelt by the user (the eval's Adaptation-6.0 invisibility). The
   strategist flagged provenance as the single highest-value next increment.

3. **Make adaptation + remembered plan visible at call/chat landing** (M) — lead
   with one data-grounded line restating the standing plan and, when a multi-rep
   adaptation verdict exists, naming what changed ("Last 3 reps your pauses
   tightened — keeping you on the pace drill"). Gate on the existing multi-rep
   floor. *Files:* `LiveCoachCallView.swift`, `AskNoumView.swift`,
   `AICoachChatService.swift:1283`, `CoachContextBuilder.swift`.
   **Overlap caution:** partially overlaps the shipped rank-2 call-landing anchor
   (`16151f9`) and rank-1 emotional open (`985ba09`); scope to *adaptation
   reasoning* specifically to avoid double-naming.

4. **Pilot visible coach confidence** (S) — surface the already-graded
   `SignalConfidence` as a quiet phrase ("This is a clear pattern" vs "Early
   read — still building the picture"), never a numeric badge. Reuse the
   strong-sustained gate that already forces the visible emotional open.
   *Files:* `CoachContextBuilder.swift`, `HomeCoachCard.swift`,
   `AskNoumView.swift`, `PostRepVerdictCard.swift`.
   **Overlap caution:** risks double-naming with the shipped rank-1 open; needs
   felt phrasing QA.

5. **Harden the honesty guards** (S as billed; larger on inspection) —
   *Re-scoped after code verification this run:*
   - **Level-up guard → DROPPED.** `RewardEngine.evaluateSession` is **dormant**
     (called nowhere live; `SessionFinalizer` owns celebration — wiring the
     parallel engine would double-fire, per the 2026-06-11 architecture note).
     Guarding dead code would be a fix presented on code that never runs.
   - **Seal `ProofMoment` → needs Jordan's architecture call.** There are **two
     legitimate grounded minters**, not one: `ProofMomentService` (transcript-
     contains verified) AND `FirstRepCelebration.celebrationLocalProof`
     (verbatim-slice, surface-only, documented). A compile-time seal funneling
     all construction through the service would break the valid second path.
     Unifying them is a real refactor (type API + DEBUG fixture + 6 tests), not
     a blind autonomous change.
   - **Fail-path test → already covered.** `transcriptContainsRejectsFabrication`,
     `deterministicProof*` tests, and `CrossSurfaceQuoteFabricationGuardTests`
     already CI-enforce the fabrication guard on the deterministic path.

## Genuine limitations (by design or out of autonomous reach)

1. **True prosody/intonation/breathing perception** (VISION pillar 5) requires
   new DSP — intensity envelope, formant tracking, breath detection — that no UI
   work supplies. The audio-only signal ceiling caps perception parity until this
   lands, and honesty rules correctly block claiming it before then.
2. **Coach-parity validation** (VISION stage 7) cannot be code-proven: it needs a
   blinded expert-coach evaluation set and a longitudinal pilot rating
   diagnosis/usefulness/fairness against human baselines. Until that exists, any
   parity claim is unearned — the "replaces a human coach" refusal
   (`CoachParityReadiness` caps at `.forming`) is **correct by design, not a
   missing feature.** This is the trust moat; do not remove the cap to chase 10/10.
3. **Real-world transfer outcomes** depend on users actually reporting how the
   interview/pitch went. The loop (move #2) can be built, but its value is gated
   on real-user participation that only TestFlight/production provides.
4. **Continuous-listening conversational mode** (the Yoodli/Duolingo felt-
   advantage over push-to-talk) was deliberately removed due to an echo loop.
   Closing that delta is a hardware/audio-session engineering problem, and
   re-introducing it risks the same regression.
5. **Felt-quality of the model's spoken coach open** is model-dependent and needs
   on-device QA with real provider keys — verifiable only by running the live
   pipeline, not by reading source.

## Bottom line on the 10/10 / A* goal

Literal "10/10, no-doubt replaces a human communications coach" = **no**, and the
app is *right* to refuse it (limitation 2). On the achievable axis — "credibly
rival Speeko/Orai/Yoodli/Duolingo on substance and trust" — Noum is already
ahead on trust/memory/verified-proof (8.0) and behind on **visibility at
adoption** (first-run 4.0) and **loop closure** (transfer 4.5). Every point of
remaining headroom is visibility-and-loop-closure work (moves #1–#3), not new
analysis. Closing #1 and #2 is the path from 6.5 toward the high-7s/low-8s that
the substrate already earns.
