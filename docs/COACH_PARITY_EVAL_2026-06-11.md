# Coach-parity multi-role evaluation — 2026-06-11

Produced by the `coach-parity-current` workflow (6 role agents → adversarial
code verification → strategist synthesis). Run on branch `ux-overhaul` at commit
`a6e7524` (after the provenance affordance, before proof-sync `2986303`).
38 agents, ~2.78M subagent tokens. This eval supersedes the 06-10 evals:
both of those predate the concurrent agent's REVIEW-overhaul / HOME-gap /
TEXT-asknoum / CHAT-intelligence commits, so several of their findings were
already stale.

## Overall: 7.0 / 10

**Verdict (verbatim).** No — at HEAD Noum is not a 10/10 "no doubt replaces a
human coach," and by its own architectural design it never claims to be
(`CoachParityReadiness` structurally caps at `.forming`, verified). The honest
current-state read is ~7/10: the coaching substrate is genuinely differentiated
and trustworthy — durable case-file memory, transcript-verified quote guards,
celebration gating, and a refuse-to-overclaim contract that beats
Speeko/Orai/Yoodli/Duolingo on honesty and depth. But the real intelligence
stays invisible at the exact retention/trust moments that decide adoption.
**None of the closeable gaps require any overclaim to fix — they are about
making real intelligence felt, synchronously, at the right beat.**

## Role scores

| Role | Score |
|------|-------|
| Market researcher | 5.5 |
| Senior product/UX designer | 7.0 |
| End user (nervous beginner, day 0) | 7.0 |
| End user (returning power user, 30+ reps) | 6.5 |
| Veteran communications coach | 6.8 |
| QA / trust auditor | 8.1 |

## Ranked code-closeable build list (adversarially verified at HEAD)

Status column reconciled against the actual tree this session (the eval carried
two stale items forward — corrected here):

| # | Item | Effort | Status at end of 2026-06-11 session |
|---|------|--------|--------------------------------------|
| 1 | Land the proof moment synchronously in the post-rep beat | M | **DONE** (`2986303`) — first-frame `deterministicProof`, no finalize-hot-path risk |
| 2 | Wire the post-session follow-up notification | S | **ALREADY DONE (stale finding)** — `SessionFinalizer:184` → `scheduleFollowUpReminder` (+18h coach-voice nudge), opt-in/auth gated. The "dead code" claim is out of date. |
| 3 | Activate earned-momentum engine (RewardEngine + SessionCompletionCopy) | M | **DEFERRED — needs human decision.** Personal-best already celebrates via the `SessionFinalizer` path; wiring `evaluateSession` would double-fire and create a parallel celebration coordinator (CLAUDE.md ban on fragmented systems). |
| 4 | Rep-1/2 named prescription instead of a data recap | M | **SPEC'd** (below) — delicate coach-voice core; needs per-persona copy + on-device felt QA |
| 5 | Auto-seed the post-rep summary into the Ask Noum thread | S | **SPEC'd** — touches shared `AskNoumStore`; needs warm-but-not-shown handling + chat QA |
| 6 | Verified-quote provenance line everywhere a guarded quote renders | M | **STARTED** (`a6e7524`, post-rep WIN card); extend to chat + celebration |
| 7 | Surface the 4-week forward plan arc on Home | M | Partially shipped — `ForwardPlanService`/`HomePlanArcLine` wired; `showsPlanArc` keeps it off Home default. Visual-review call. |
| 8 | Guard `coachingDirectionCard` against cold-start thin data | S | **DEFERRED** — current cold-start copy is already honest ("a few more sessions…"); `coachingPlanCard` self-hides <3 reps. Force-hiding is a debatable subtraction → visual review. |
| 9 | Reframe LoginView/onboarding copy method→outcome | M | Visual/positioning judgment — left for Jordan (UI/UX lead). Current hero copy is honest, not egregiously method-first. |
| 10 | Bridge onboarding completion → day-0 greeting as one moment | M | SwiftUI flow change; needs simulator QA |
| 11 | Close the transfer loop (OutcomeTransferLink + coached debrief) | M | **The transformative move.** Outcomes feed coach *context* but not the next *prescription* (`PrepSessionPlanner.plan` ignores outcomes). Larger build. |
| 12 | Thread the prescribed isolated variable into the immediate post-rep note | M | `PostRepCoachNoteInput` carries no `observableTarget`; note judges full-rep metrics, never whether the ONE prescribed lever moved. Pairs with #4. |

## Genuine limitations — the honest answer to "10/10, replaces a human coach"

These cannot be closed in code alone (the ~3-point gap from 7 to 10 is mostly
here, not in the build list):

- **Perception ceiling (sensor/model).** Audio-only: ~4 baseline-relative
  channels + pause + composure. No prosody contour, pitch range, breathing,
  emphasis, eye contact, gesture, or "polished-but-evasive" read.
  `VideoAnalysisService` is thin/last-sequenced. `CoachDeliveryRead` deliberately
  caps at clear/timid/forming. Largest single chunk of the gap; needs a new
  sensor modality, not a call-site change.
- **Coach-parity is structurally unvalidatable in-app by design** —
  `CoachParityReadiness` never returns `.earned`. This is a feature.
- **Expert-rubric calibration unproven** — `CoachChatExpertBaselineSlot`
  fixtures are all `pendingExpertReview`; needs human-coach-scored baselines
  (VALIDATE-2).
- **Causal attribution structurally barred** — association-never-causation;
  proving a drill caused an outcome needs isolated-variable longitudinal data.
- **Felt warmth / "sounds like a real coach"** — judgeable only by on-device QA
  with real provider keys on hardware (VALIDATE-4).
- **Real D1/D7/D30 retention vs competitors** — empirical, needs a shipped
  cohort. No code change closes it.
- **Inner-experience capture** is bounded by design (4-option enum + 160-char
  note); a live coach probes conversationally.
- **Roleplay breadth** (interview/sales/pitch/presentation) is a deliberate
  non-goal — Yoodli owns breadth, Noum chose depth. Code-closeable but carries
  real architectural cost (parallel tone classifiers).

## Competitor read (current)

Noum already **beats the field on trust, depth, and refusal-to-overclaim** —
transcript-verified quote guards (`ProofMomentService` gates every cited line),
milestone-only celebration gating, rating-evidence enforcement, a deterministic
offline fallback held to the same rubric as live replies, and a parity-refusal
contract. No competitor ships this discipline; Speeko/Orai/Yoodli will generate
"you said X" without verifying X was spoken, and Duolingo's warmth is gamified,
not evidence-grounded. The `CoachCaseFile` is architecturally ahead of all four
on persistent personalized coaching. Where Noum **trails today** is felt clarity
and momentum at first contact (Orai's day-1 visible plan; Duolingo's warmth) —
and every trailing item is code-closeable without a single overclaim. It does
not yet replace a human coach (audio-only perception, unvalidated outcomes), and
it is honest enough to never pretend otherwise.
