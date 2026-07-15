# Run: 2026-07-13 · branch:ux-overhaul · HEAD 4f656ba0 · close the research-driven implementation and local production-evidence boundary

## Mode

light

## Changes shipped (this run)

- `Noum/NextActionEngine.swift:73` — one fail-closed mode-availability projection now keeps rendered recommendations and launch destinations coherent across Summary, Home, Train, Ask Noum, and Prep.
- `Noum/TimedPracticePromptHandoff.swift:13` — bounded Timed prompts now use an account- and exact-route-bound, one-shot in-process handoff instead of unscoped persisted text.
- `Noum/ForwardPlanStore.swift:418` — the active Forward Plan week can safely reference a Phrase Bank entry by ID and reconcile deletion or newly unsafe content.
- `NoumTests/CoachChatConversationEvaluationTests.swift:721` — app-path fixtures now declare styled/neutral provenance explicitly, and the short-latency close fixture is grounded in retrievable user context.
- `tools/coach-arena/runners/coach_arena.py:1917` — trace quality validates styled, neutral, unknown, and contradictory semantic-assessment provenance without fabricating style evidence.

## Screenshots

- `01_home_top.png` — Home tab, permissionless cold-start state.
- `01_train_top.png` — Train tab, available Timed recommendation and practice library.
- `01_review_top.png` — Review tab, honest no-session empty state.
- `01_profile_top.png` — Profile tab, evidence-limited coaching focus.
- `01_settings_top.png` — Settings tab, practice controls and disabled pressure state.

## VISION gap

The five tab tops preserve Noum's calm, restrained first-run hierarchy and do not
invent progress. This light sweep does not visually prove the changed transient
routes: Summary/Home Phrase Bank prompt handoff, Prep's unavailable-mode fallback,
Ask Noum's recommendation launch, or tap-time capability loss. Production parity
also remains unearned until real-provider, professional-reviewer, longitudinal,
physical-TestFlight, and operational evidence exists.

## Next steps to reach desired state

1. Collect the exact 14-surface/77-check physical TestFlight artifact described in `docs/TESTFLIGHT_QA.md` against a signed release candidate.
2. Run the authorized current-source live-provider sweep and obtain blinded professional-coach plus longitudinal transfer evidence.
3. Add deterministic screenshot-tour coverage for the transient Prompt/Prep/Ask launch paths if they become stable test hooks.

## Regressions checked

- Permissionless Home — `01_home_top.png` — first rep and setup choices remain clear; no fake progress.
- Train availability — `01_train_top.png` — Timed Practice is runnable and the unavailable pressure control is not presented as the recommendation.
- Review empty state — `01_review_top.png` — no fabricated history or metrics.
- Profile evidence floor — `01_profile_top.png` — coaching copy asks for evidence instead of overclaiming.
- Settings — `01_settings_top.png` — pressure remains visibly disabled at cold start; spacing and tab chrome are intact.

## Surfaces needing visual verification (cloud → local queue)

- Summary/Home active-week Phrase Bank prompt launch and one-shot consumption.
- Prep pressure/audience fallback while the planned readiness identity stays unchanged.
- Ask Noum mode recommendation under live capability loss and recovery.
- Reduced-motion behavior on the affected navigation and recommendation surfaces.

## For next run

- **If cloud**: review source/evidence changes only; do not claim simulator or physical-device proof.
- **If local**: run the detailed tour on a disposable seeded simulator, then capture the transient Prompt/Prep/Ask paths with targeted launch hooks.
