# Coach-parity multi-role evaluation — 2026-06-10

Produced by the `coach-parity-eval` workflow (6 role agents → adversarial
verification against code → synthesis). Run on branch `ux-overhaul` at commit
`ac4194a`. 27 agents, ~2.2M subagent tokens, 18 confirmed real/partial gaps.

## Overall: 6.3 / 10

**Verdict.** Noum is an unusually honest, architecturally coherent coaching
substrate — closer to coach-parity *on paper* than Speeko/Orai/Yoodli/Duolingo
are on outcomes. Its evidence-gating, quote guards, durable case file, and
association-not-causation discipline are real and verified in code. But it
cannot yet credibly rival the leaders on what users *feel*: the
first-run-to-value loop is built for repeat users, the strongest
differentiators (4-week plan, real-world transfer loop) are built but buried,
and several momentum systems are literally dead code. **The headline blocker is
not missing capability — the intelligence is real but invisible at the moments
that drive retention and trust.**

## Role scores

| Role | Score |
|------|-------|
| Market research | 5.5 |
| UX designer | 6.0 |
| End user (beginner) | 6.5 |
| End user (power) | 6.0 |
| Coach expert | 6.5 |
| QA / trust tester | 7.2 |

## Dimension scorecard

| Dimension | Score | Note |
|-----------|-------|------|
| Perception (delivery sensing) | 6 | Pitch/energy/pace/fillers/pauses shipped with honest nil-below-floor gates. Breathing absent, prosody monotone-binary, authority/tension only indirect. |
| Case formulation | 6 | CoachCaseFile + durable memory strong. Inner experience captured only as 4-option enum + 160-char note. Inference outpaces user confirmation. |
| Intervention | 6.5 | Prescriptions name mode+focus+target+rationale, but the isolated variable is never tracked or verified to have moved. |
| Adaptation | 6 | Association-only phrasing is correct/disciplined, but fires on aggregate score/filler, not the prescribed variable. No causal isolation. |
| Transfer | 5 | Prepare→event→reflect wired and outcome card is on Home, but no OutcomeTransferLink, no coached debrief, outcomes never feed the next decision. Collected, not closed-loop. |
| First-run | 5 | Ask Noum gated until rep 1 — coach can't be talked to day 0. No seeded onboarding question, no plan before first rep. Coach "knows you" but isn't felt until day 1. |
| Delight / retention | 4.5 | Return loop broken by dead code: post-session follow-up notification never enabled; RewardEngine.evaluateSession + SessionCompletionCopy.headline confirmed dead (zero invocations). Real progress not felt as momentum. |
| Competitive position | 5.5 | Wedge real but internally-focused/text-heavy. 4-week plan buried. Roleplay only 4 social IM scenarios — no interview/sales/pitch routes. |
| Trust / honesty | 8 | The genuine moat. Quote guard on chat + post-rep, celebration gating, rating hidden until evidence, deterministic fallbacks never overclaim. Better than any named competitor. |
| Premium feel | 6 | Restrained motion on-brand, but Profile still ~20 surfaces; coachingDirectionCard renders even on cold start (no thin-data guard). |

## Prioritized build list

1. **[S] Wire the post-session follow-up notification** — pure dead-code activation. Only 3 of 4 notification surfaces enabled; without this the app disappears after the first rep. Coach-voice continuity nudge (not loss-aversion).
2. **[S] Unlock seeded read-only Ask Noum on day 0** (after onboarding, not after rep 1). The "coach knows you" door is locked exactly when a first-timer is deciding to trust the product.
3. **[M] Fire a minor "personal-session-best" beat between major milestones** — activate the dead RewardEngine.evaluateSession / SessionCompletionCopy.headline. Honest momentum, no fake progress.
4. **[M] Surface the existing 4-week plan as a featured forward arc** on Home + picker. Orai-style visible plan; system already exists (ForwardPlanService), just buried.
5. **[M] Add interview / sales / difficult-conversation / presentation roleplay routes** to the picker, reusing the existing NPC + tone-matching backend.
6. **[M] Add one post-rep behavioral-observation prompt** bridging measured→felt, framed as hypothesis (never a label).
7. **[L] Consolidate Profile to ~4 surfaces + guard coachingDirectionCard on thin data.**
8. **[L] Close the transfer loop: OutcomeTransferLink + coached post-event debrief** — the transformative differentiation move.

## Genuine limitations (code alone cannot close)

- **Causal attribution** needs longitudinal isolated-variable data, not code.
- **Real-world transfer validation** needs months of real users hitting real moments and reporting outcomes.
- **Coach-parity claims** require blinded human-coach calibration (a research program, not a feature).
- **Deeper delivery sensing** (breathing, true prosody, authority/tension) needs on-device DSP/ML + real-hardware QA validated against human ground truth.
- **Subjective inner experience** is user-supplied; depth is bounded by user participation (never-label-from-telemetry rule).
- **Retention impact** (D1/D7/D30 vs competitors) is only answerable with real cohort analytics from a shipped build.
