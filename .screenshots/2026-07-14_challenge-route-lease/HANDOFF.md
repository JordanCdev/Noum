# Run: 2026-07-14 · branch:ux-overhaul · HEAD c7cd0b51 · Bind challenge submission to an exact saved-session route lease

## Mode
light — capture skipped because this run changed only challenge authority and
session-lifecycle logic; no visual surface changed.

## Changes shipped (this run)
- `Noum/ChallengesManager.swift:244` — makes the prompt-bearing challenge arm a process-local, expiry-bounded route lease and removes it from durable account snapshots.
- `Noum/ChallengesManager.swift:581` — arms only from authoritative cached participant, expiry, unplayed, account, token, and exact-prompt state; binding and submission require the exact saved session.
- `Noum/TimedPracticeView.swift:1070` — arms only after the opaque Timed handoff is successfully consumed.
- `Noum/TimedPracticeView.swift:3194` — binds authority to the exact session returned by the existing speech-session owner before Summary.
- `NoumTests/SocialAuthorityClientTests.swift:311` — covers route eligibility, byte-exact binding, expiry, cancellation, and legacy prompt-bearing key purge.

## Screenshots
- None. There was no UI change, and simulator images cannot prove this authority boundary.

## VISION gap
This hardens coaching trust and product coherence by preventing stale or
persisted prompt-bearing challenge authority from being reused against another
rep. The trusted deterministic evaluator, calibrated evidence floor, hydrated
opponent route, deployed retention, and eligible server evidence producer are
still absent, so competitive results remain disabled and ineligible.

## Next steps to reach desired state
1. Define and independently calibrate the deterministic evaluator and evidence-floor policy before adding an eligible `_verifiedSessionEvidence` writer.
2. After authority is earned, add one hydrated/opponent launch path through the existing challenge and Timed owners rather than a parallel route.
3. Collect deployed TTL/replay, live-provider, professional-review, longitudinal, physical-TestFlight, and operational evidence.

## Regressions checked
- Challenge route consume → Timed capture → exact saved-session binding → Summary submission — focused simulator tests, 73/73 passed.
- Timed prompt handoff, account registry, session finalization, social lifecycle, and demand persistence — included in the same 73/73 focused run.
- UI visuals — not applicable; no rendered values, layout, motion, accessibility labels, or navigation destinations changed.

## Surfaces needing visual verification (cloud → local queue)
- None introduced by this run. Hydrated/opponent challenge UI remains intentionally unimplemented and false-gated.

## For next run
- **If cloud**: continue evaluator/evidence-contract work that does not claim external calibration or deployment.
- **If local**: no visual sweep is needed until the challenge UI itself changes; preserve the fail-closed capability gates.
