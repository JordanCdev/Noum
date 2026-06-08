# Noum overhaul — session continuation 2026-06-08

Branch: `ux-overhaul`
Mode: autonomous scheduled run (`noum2`), no user present.
Toolchain: real (Xcode 26.x on this Mac) — every claim below is compiled + tested,
not hand-traced. Subagents used for evaluation were sandboxed (read-only, no
toolchain); their findings were re-verified here against the real build.

## What this session did

### 1. Multi-role evaluation workflow

Ran a 10-agent workflow (`noum-coach-parity-eval`) with distinct roles:
market researcher (live competitor check), senior UX critic, skeptical end-user,
communications-coaching expert (scored against `COACH_REPLACEMENT_SCORECARD.md`),
QA/trust auditor → strategist synthesis → 4 engineer spec agents.

Every code-tickable gap the panel named maps to a real owner that already exists
in the repo (CoachContextBuilder, BigMomentStore, PrimaryFocusMemory,
AICoachChatService, PostRepCoachNoteService, AIInsightsService, ProofMomentService,
FrameworkDrillChecks, ProfileView). The panel agreed with the scorecard's own
"Remaining (code-tickable)" list — no invented work.

### 2. Two trust fixes — implemented, compiled, tested

Both were the highest-leverage, lowest-risk, owner-local findings: trust seams a
communications coach cannot have, since fabricated or low-quality "evidence" is
the single failure that breaks coaching trust.

**Fix A — Offline Ask Noum replies held to the live quality bar.**
`AICoachChatService.reply()` gated live model replies through `replyQualityIssue`
but returned the five deterministic offline fallbacks (`.noProvider`,
`.localeUnsupported`, two `.network`, `.empty`) ungated. Added
`deterministicReplyOutcome(failure:context:latestUserTurn:)`, which routes every
offline line through the same gate. Design subtlety verified by test: the gate
blocks only **objective** failures (robotic phrasing, over-length, defensive
product language, menu-instead-of-decision, fabricated quote, overclaim). A
turn-contextual `.unanchoredCoaching` / `.missingPrescribedAction` on a genuinely
cold no-data line is **allowed** — the honest "run one more rep, I'll read it when
I'm back online" response is correct when there is no data to anchor to, and must
not be silenced. If a future copy change ever produced an objective failure, the
user now gets the honest `.empty` ("try rephrasing") notice instead of a sub-bar
substitute. No new store/route.
Files: `Noum/AICoachChatService.swift` (5 call sites + new wrapper).

**Fix B — Every AI prose surface that quotes the user routes through the proof
guard.** `ProofMomentService.transcriptContains` (via the chat
`CoachChatQuoteGuardContext`) verified quotes only on the live chat path. The
post-rep coach note (`PostRepCoachNoteService.generate`) gated prose with
brand-voice + lexical `engagesTranscript` only, and the sessionDebrief insight
(`AIInsightsService.insight`) — whose system prompt actively pushes the model to
quote the user — had **no** post-generation quote verification at all. A
fabricated `you said "…"` could reach the user dressed as proof on both. Both now
run any attributed quote through the same guard the live chat uses; an
unverifiable quote falls back to the deterministic, non-quoting copy. The
insight gate verifies against the **full** transcript (not the 900-char prompt
cap) so a legitimate quote is never falsely rejected. Reuses the existing guard —
no duplicate regex, no new owner.
Files: `Noum/PostRepCoachNoteService.swift`, `Noum/AIInsightsService.swift`.

### Tests added (all green)

- `AICoachChatDeterministicReplyTests`: deterministic lines carry no objective
  quality failure across every cause × voice; the gated wrapper always emits a
  coach bubble for normal contexts.
- `CrossSurfaceQuoteFabricationGuardTests`: fabricated attributed quote rejected;
  verified quote (flexible match) accepted; non-attributed quotes not falsely
  flagged; insight headline+body assembly rejected on fabrication; empty
  transcript → attributed quote correctly rejected.

## Verification (real toolchain)

- `xcodebuild build` — **BUILD SUCCEEDED** (binary mtime advanced).
- New/affected suites: **76 passed / 0 failed**
  (`AICoachChatDeterministicReplyTests`, `AICoachChatReplyQualityGateTests`,
  `CrossSurfaceQuoteFabricationGuardTests`).
- Regression slice across every touched service: **282 passed / 0 failed**
  (AICoachChat, PostRepCoachNote, AIInsights, ProofMoment archive/service,
  CoachChatEvaluationFixture, BelievableProgressZeroData).

## Competitor verdict (panel, web-checked 2026-06-08)

Noum does not win on breadth and should not try to. Speeko (real-time in-call
coaching, large exercise library, delivery-sensing breadth), Orai (simple 4-week
plan, easiest cold-start mental model), Yoodli (enterprise/teams, many languages,
multi-persona roleplay), Duolingo (delight, habit loop, distribution) each own a
territory Noum should not chase. Noum's defensible wedge is the one none of them
systematically do: **private, evidence-led coaching that durably remembers the
user's own words and real moments, refuses to claim progress before rated
evidence, verifies quotes before saying "you said," and never self-certifies
coach parity.** Today that wedge is real in code but under-felt by users (thin
case file for most users, transfer loop barely surfaced, no visible curriculum
spine, cold-start unproven on hardware). Net: ahead on honesty + memory, behind
on felt depth + legibility, dead-even-or-behind on delivery-sensing breadth
(audio-only; no prosody contour or presence).

## Highest-leverage remaining code-tickable backlog (panel-ranked)

All map to existing owners; none needs a new store/route.

1. REMEMBER-4 — persist the nearest upcoming `BigMoment` on the durable
   `CoachCaseFile` (currently per-turn context only). *Full spec authored this
   session (see workflow result); ~5 build call sites + decode safety.*
2. TRANSFER-3 surface — wire the existing `BigMomentTransferTrend` reducer into a
   compact, self-report-framed Profile/Home chip (reducer already emits it).
3. PRESCRIBE-3 — ground the pre-rep success bar in the user's own `priorAverage`
   instead of a fixed switch.
4. SUBSTANCE-4 remainder — thread `reviewDueAt` (review cadence) into
   `AICoachSessionInput` (hypothesis/target/measure are already threaded).
5. DELIVERY-7 — one fused `CoachDeliveryRead` on the case file.
6. Make the curriculum spine visible without a dashboard; surface
   `CoachParityReadiness` per-stage evidence on Profile (turns the honesty
   constraint into a visible trust feature).

## Genuine limitations — no code closes these (honest answer to "10/10")

A self-certified "10/10, replaces a human coach" would itself violate Noum's
honesty contract. The remaining distance is not mostly code:

- **Perception depth (architectural/sensor limit).** Noum senses ~4
  baseline-relative audio channels + RMS energy/composure. It cannot read prosody
  contour, pitch range, breathing, emphasis, posture, eye contact, gesture, or
  whether polished speech still feels evasive/detached. `VideoAnalysisService` is
  thin and orphaned; presence is intentionally sequenced last.
- **Expert-coach calibration (VALIDATE-2, human-gated).** Requires expert
  per-fixture baselines + a pre-registered scored comparison.
- **Longitudinal real-user outcomes (VALIDATE-3, human-gated).** Proof that
  coaching durably changes real behavior needs real users over weeks/months.
- **Felt LLM quality (VALIDATE-4, human-gated).** Whether the reads *feel* like an
  excellent coach is judgeable only by on-device QA with real provider keys.
- **60-second cold-start unproven on hardware.** The fake-delay path is removed
  and UI-test hooks exist, but no real-device timed ask→speak→read run exists.
- **Live coaching dynamics no current architecture replicates.** Asking
  clarifying questions and revising the hypothesis under user disagreement;
  designing a drill against the exact room/audience/stake/deadline; noticing
  qualitative frustration/avoidance mid-drill.
- **Quote-selection bias.** A perfect quote guard prevents fabricated quotes but
  cannot judge whether a true quote is representative. Mitigable in copy, not
  fully closable in code.

**Bottom line:** the credible target is "feels more coach-like than Speeko/Orai/
Yoodli on the depth + trust axis," reached by closing the coaching loop and making
the existing honesty visible — *not* a parity claim. Parity is provable only by
expert calibration + real users improving over time.

## Connectors

- **Figma MCP** (`@figma`) — available; the prior session reported its allowance
  was exhausted. Not exercised here (no concrete design brief that beat shipping
  verified trust fixes).
- **Canva MCP** — now connected in this environment (the previous handover said it
  was unavailable). Usable for static visual proposals next session.
- No additional connectors are required to execute the remaining code-tickable
  backlog. A real provider key + a physical device are what's needed for the
  human-gated validation items, and those are out of an agent's reach.
