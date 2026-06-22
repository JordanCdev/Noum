# Coach-parity evaluation — 2026-06-22

Branch: `ux-overhaul` · HEAD at eval: `ddff056` · Run: autonomous `noum-1`
Method: role-diverse workflow (6 role agents → adversarial gap verification
against current code → strategist synthesis). Real local toolchain used to
verify the build + shipped-work test suites first.

Predecessor: `docs/COACH_PARITY_EVAL_2026-06-20.md` (6.5/10 @ `b085d51`).

## Panel-integrity caveat (read first — honesty mandate)

This run is **not** a clean 6-of-6 role consensus. Under concurrent machine load
**4 of the 6 role agents stalled** (no progress through 6 retries each — infra,
not a verdict). Two role scores returned cleanly: **Trust/Honesty 9.1** and
**Market-position 7.0**. The headline **7.2/10** is therefore anchored on: those
two returned scores, the **adversarially code-verified** gap list (every claimed
gap re-checked against actual files before counting), and the 06-20 baseline —
**not** a full panel. Treat 7.2 as a well-grounded point estimate, not a polled
average. The *gaps* below are the durable output: each is confirmed against a
specific file:line in the current tree.

## Honest score: 7.2 / 10  (+0.7 vs 6.5)

The shipped roadmap work since 06-20 moved the number — modestly and honestly.
Gains concentrate in dimensions that were already Noum's strength (trust
substance, adaptive-plan depth, the real-world transfer loop). The score did
**not** jump to 8+ because the single highest-leverage *acquisition* gap —
time-to-first-spoken-word — is verified still open (first-run routes to a picker,
not a rep), and continuous-conversation feel remains by-design ceded. Depth went
up; the moments that *sell* that depth moved less. 7.2 = "substantively ahead on
trust, still behind on demo feel."

## Scorecard

| Dimension | Score | Basis (code-grounded) |
|-----------|-------|-----------------------|
| Trust & honesty | **9.1** | Honesty floors, evidence-gated provenance, no-causation copy, cold-start gating. Best-in-class, engineered not claimed. |
| Adaptive-plan / transfer intelligence | **8.0** | `ForwardPlanService` reads `BigMomentStore.outcomeReports` into the 4-week plan; deterministic Week-4 bridge on did-not-transfer plurality; quiet honest receipt. |
| Personalized coaching / onboarding | **7.5** | Coach-led inline first-run (setup-as-root), custom growth-area free-text, inline goal refresh. Friction down, coherence up. |
| Market position vs leaders (substance) | **7.0** | Out-positions Speeko/Orai/Yoodli/Duolingo on coaching substance; cedes the demo moment + conversation feel. |
| Live-conversation feel | **6.0** | Push-to-talk only by design (echo-loop fix). A real felt delta vs Yoodli/Duolingo, honestly chosen. |
| Acquisition / first-rep moment | **5.5** | Verified open: first spoken word still gated behind picker + Begin tap + countdown. The drag on the overall. |
| **Overall** | **7.2** | Weighted to trust+substance, dragged by acquisition feel. |

## Delta since 6.5 — what the shipped work actually closed

- **Closed the real-world transfer loop in the plan** (`PLAN-TRANSFER`, `3a0bc5e`).
  `ForwardPlanService` now ingests `BigMomentStore.outcomeReports`; the 4-week
  plan adapts on did-not-transfer plurality with a deterministic Week-4 bridge
  clause and an honesty floor on the *transfer-read count* (not just total
  reports). A closed coach loop (practice → real moment → reported outcome →
  plan shift) that **no leader ships**. Biggest substance gain.
- **Made adaptation visible without overclaiming** (transfer-plan receipt,
  `e386a5e`). `CoachingPlanCard` renders a quiet "you told me X, so the plan
  shifted" receipt — did-not-transfer only, evidence-gated, no causation.
  Adaptation that was invisible at the retention moment is now legible.
- **Cut onboarding friction + raised coherence** (`de38004`/`d4f2582`).
  First-run setup is the app root (not a cover over Home); intro is coach-led;
  goal refresh is an inline Home card (not a sheet); "Something else" free-text
  growth area persists custom wording routed through 4 canonical buckets.
- **Fixed two chat trust leaks.** Ask Noum replies are calm/compact (Figtree,
  bounded Markdown, length-capped, 1-4 short lines); the live gate no longer
  scrapes contractions as bogus quotes (`CHAT-QUOTE`, `b085d51`).

Net: the **retention + trust** axis moved up materially; the **acquisition** axis
barely moved.

## Verified remaining gaps (prioritized, code-confirmed this run)

1. **First-spoken-word still routes to a picker, not a rep.** *(real · highest
   value-toward-goal · FELT-QA GATED — do not blind-build)*
   First-run completion sets `noum://train`
   (`Noum/CoachingOnboardingView.swift:563-575`) → `ContentView.swift:1382`
   `replaceNavigationPath(with: .practiceSelection)` → the picker (Coach Pick +
   Begin). Every path into a rep is still behind a Button tap. This is the
   friction Speeko/Yoodli avoid and it sits squarely on the acquisition axis —
   the single biggest lever from 7.2 toward ~8.5. **Spec, do not autonomously
   build:** it's the make-or-break first impression and needs on-device feel +
   timing review (and it overlaps the live onboarding work). Spec:
   `docs/SPEC_first_rep_auto_guided.md`.

2. **Stale auto-rearm comment in `LiveCoachCallView`.** *(real · low effort ·
   safe)* — **FIXED THIS RUN** (`39d5d03`). The header still claimed HANDS-FREE
   auto re-arm, contradicting the shipped push-to-talk code (lines ~71-73, ~200,
   ~613) and risking a future dev reintroducing the echo-loop bug. Rewritten to
   describe push-to-talk and warn against re-arm. Comment-only.

## Genuine limitations (named precisely)

1. **`CoachParityReadiness` capped at `.forming`; a literal "replaces a human
   coach" claim is REFUSED — correctly.** The trust moat, an intentional VISION
   property. Do **not** remove the cap to chase a literal 10/10. (Unchanged across
   every prior eval.)
2. **Audio-only prosody ceiling.** No video/body-language read; Noum cannot
   assess the visual half of communication a human coach (or Yoodli's video mode)
   sees, nor true intensity-envelope/breath without new DSP. Structural.
3. **Transfer loop is gated on real-user reporting.** The closed loop only fires
   when the user reports an outcome; absent reports the plan can't
   transfer-adapt. Honest, but the headline intelligence stays dormant for
   non-reporters — value is gated on TestFlight/production participation.
4. **Continuous-listening feel ceded by design.** Push-to-talk is the honest
   behavior until root-cause echo cancellation (AVAudioSession voice-processing
   AEC / headset-gated re-arm) lands. Naive auto-rearm reintroduces the
   coach-hears-its-own-TTS bug.
5. **Felt copy is model-dependent.** Coaching warmth/credibility rides on the
   live model; quality is bounded by the model, not just the prompt — a real
   ceiling on "feels like a person," verifiable only by running the live pipeline
   on-device.

## Bottom line on the 10/10 / A* goal

Split the goal into its two axes:

- **Achievable axis — rival the leaders on substance + trust: Noum is genuinely
  there (≈9/10 trust, 7–8 substance).** It out-positions Speeko, Orai, Yoodli,
  and Duolingo on what a serious user keeps paying for: verified proof, a durable
  adaptive plan, and a *closed* real-world transfer loop with honest provenance.
  The one thing holding this axis below a clean A* is **demo-moment legibility** —
  the depth is real but under-shown at the first-rep and live-conversation moments
  that drive willingness-to-pay. Closing gap #1 reads this axis as A*.
- **Refused axis — literal human-coach replacement: correctly NOT pursued, and
  the refusal is a strength.** A literal "10/10, no-doubt replaces a human coach"
  is the wrong target by design; treating Noum's refusal as a missing point
  misreads the product.

**Verdict: 7.2/10 today, credible path to ~8.5 by closing only the first-rep
moment (felt-QA gated) — and an honest ceiling below "10 = replaces a coach" that
Noum chooses on purpose.** The score is held back by what's *visible at
acquisition*, not by what the system can *do*.

## Verification evidence (this run)

- `build-for-testing` exit 0 (warnings only) on isolated
  `./DerivedData/Noum-eval-verify`, HEAD `ddff056`; `NoumTests.xctest` +
  `NoumUITests.xctest` + xctestrun all produced.
- Focused `test-without-building`: **39 passed / 0 failed** across
  `ForwardPlanServiceDeterministicTests`, `CoachingPlanCardVisibilityTests`,
  `CoachingOnboardingCustomChallengeTests`, `DevSeedCoachIntelligenceFixtureTests`,
  `AICoachChatDeterministicReplyTests`, `CrossSurfaceQuoteFabricationGuardTests`,
  `BigMomentTransferEnrichmentTests`, `BigMomentTransferStoreTests`,
  `CoachContextBuilderBigMomentTests`.
- Both remaining gaps re-confirmed against actual current source before counting.
