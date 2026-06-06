# Initiative #9 — Coach Read parity (question-aware input, substance rubric, grounding gate, locale gate, deterministic fallback)

Generated: 2026-06-01 · Branch `Redesign` · Status: **built + independently cold-verified (3 lenses, 0 blocking findings; 1 trivial dead-stopword cleanup applied), pending `xcodebuild test`**

## Why this exists (the feedback-intelligence finding)

The user's critique for this run: "the intelligence seems real basic and some hard
coding … ensure it's COMPREHENSIVE; that's the heart of having a replacement."

The "Coach Read" surface (`AICoachService.generateDeeperFeedback`, the explicitly-
labelled button on `SummaryView`) was the most-prominent surface still stuck at the
shallow tier that initiative #8 had already fixed for the post-rep note and the
session debrief:

- It **could not judge whether the answer engaged the question** — `AICoachSessionInput`
  carried no `prompt` field, even though `PracticeSession.prompt` is stored and in scope
  at the one call site. So the read reasoned over delivery metrics + transcript only.
- Its system prompt was a **generic Toastmasters block** with no quoting mandate, no
  lead-vs-buried judgment, no thin-data honesty.
- It **threw on every failure** (`transcriptTooShort` / `missingAPIKey` / non-2xx /
  decode), and `SummaryView` surfaced the raw error as `"Coach Read failed: …"` — and it
  carried **no locale gate**, so a Spanish/French rep got English LLM coaching or a raw
  error rather than a deterministic read. (`aiSupported` occurred **0 times** in
  `PracticeSupport.swift` before this pass.)
- It had **no post-hoc grounding gate**: a generic, ungrounded LLM read was accepted and
  rendered as-is.

This was the highest-leverage *intelligence-substrate* gap left on the feedback layer:
pure depth on one existing owner, mirroring the discipline of initiatives #1 and #8.

## What was built (4 files)

Pure depth on existing owners — **no new store/screen/engine/routing, no new UI**, and
the `AICoachFeedback` wire schema (`{strengths, keyImprovement, suggestedDrill,
revisedOpening}`) is **byte-identical** so all six render surfaces are untouched
(`FeedbackViews`, `SessionHistoryView`, `SummaryCards`, `WhatToImproveCard`,
`WhatYouDidWellCard`, plus the persistence in `saveAIFeedback`).

1. **`Noum/PracticeSupport.swift`**
   - **`AICoachSessionInput`** (`7439`): +4 defaulted fields (`prompt`, `voice`,
     `recentSessionSummaries`, `baselineFillerRate`/`baselinePaceWPM`) via an explicit
     init that defaults all of them, so the one caller and any future fixture compile
     unchanged (the struct previously used the implicit memberwise init).
   - **`systemPrompt` → `systemPrompt(persona:)`**: the generic Toastmasters block is
     replaced by a priority-ordered, substance-first rubric that mandates (1) judging
     answer / lead-vs-buried when a QUESTION ASKED is given, (2) quoting a real phrase,
     (3) support-vs-assertion, (4) honest continuity, with hard honesty rules (patterns
     are hypotheses; association never causation; no claim the input doesn't support;
     never punish-shame; no exclamation / chirp). Per-voice register via `CoachPersona`,
     mirroring `PostRepCoachNoteService.systemPrompt(persona:)`.
   - **user prompt** → extracted to a pure `nonisolated static userPrompt(input:profile:
     plan:baselineContext:)`. Adds the per-voice `AIInsightsService.registerClause`, a
     `THE QUESTION ASKED:` line (omitted when empty), confidence-gated baseline lines
     (omitted when nil), a `RECENT REPS (continuity, never invent)` block (omitted when
     empty), and switches the mode line from `rawValue` to `displayLabel` for cross-
     surface parity.
   - **`generateDeeperFeedback`** restructured to **fallback-first + gated-accept**
     (mirrors `PostRepCoachNoteService.generate` `368`): compute the deterministic
     `fallback` up front; `guard activeLocaleSupportsAI() else { return fallback }`;
     return the fallback (not throw) on thin transcript / no provider / no key / no
     endpoint / non-2xx / decode failure; after decode, gate on
     `passesBrandVoiceContract` then `engagesTranscript` before accepting. The protocol
     stays `async throws` for type-compat, but the body no longer throws on the gated
     paths — so `"Coach Read failed"` is no longer reachable for those cases.
   - New `nonisolated static` members (pure, unit-tested): `deterministicFeedback(input:)`,
     `engagesTranscript(_:transcript:)`, `passesBrandVoiceContract(_:)`,
     `recentSessionSummaries(sessions:currentRepID:)`, the private `engagementStopWords`
     set, and the private `activeLocaleSupportsAI()` one-liner. The fallback quotes the
     opener when present (never fabricating one) and states the **shared** answered/buried
     verdict via `PracticeEvaluator.promptAnswerVerdict` so every surface agrees.
   - Removed the now-unreachable private `AICoachService.apiError(from:provider:)` (each
     other service keeps its own copy; the shared error types remain in use elsewhere).

2. **`Noum/SummaryView.swift`** — the single call site (`requestDeeperFeedback`) populates
   the 4 new fields from already-in-scope owners: `prompt` = `recentSessions.first?.prompt
   ?? sessionPrompt ?? ""`; `voice` = `coachingProfileStore.profile?.speakingStyleGoal`;
   `recentSessionSummaries` = `AICoachService.recentSessionSummaries(sessions:
   sessionStore.sessions, currentRepID: latestSessionID)`; baseline filler/pace from
   `baselineStore.baseline` with the `confidence == .insufficient ? nil : value` gate
   (the same gate at `PracticeSupport.swift:7182-7185`). The `catch` block is left as a
   defensive net but no longer the path for the gated failures.

3. **`NoumTests/NoumTests.swift`** — a 15-case `CoachReadParityTests` suite mirroring the
   `PostRepCoachNoteServiceDeterministicTests` discipline: deterministic well-formed /
   brand-voice sweeps across all 6 voices × score bands × filler counts; the
   answered/buried verdict mapping; the no-substance-claim-below-evidence-floor lock;
   opener-quote presence/absence; the `engagesTranscript` accept (shared word / verbatim
   slice / empty) + reject (stat-restate); the `passesBrandVoiceContract` exclamation/
   chirp rejections; the schema decode lock; the defaulted-init compile-guard; the
   user-prompt omit/surface tests; and the two pure call-site helpers (recent-summaries
   exclude-current-rep + bound-to-3, baseline extraction nil-on-insufficient).

## Invariants honored

- **Score safety:** this surface never computes the per-rep score. The score is produced
  entirely in `PracticeEvaluator` (`PracticeSupport.swift:4932-4962`); `generateDeeperFeedback`
  only *reads* `input.score` as prompt context and emits qualitative text. `input.score`
  appears only inside the prompt string and is never written back. Zero score-regression
  surface — verified.
- **No fake certainty / association not causation:** the deterministic substance verdict
  is asserted ONLY above its evidence floor (`promptAnswerVerdict` returns `nil` when
  `evidenceFloorMet == false`); below the floor the fallback states delivery facts only.
  Baseline comparisons fire only when the confidence-gated baseline is present. The rubric
  explicitly labels patterns as hypotheses and forbids causation.
- **Grounding enforced in code:** the post-hoc `engagesTranscript` gate (shared ≥4-char
  non-stop content word OR ≥12-char verbatim slice across `keyImprovement` /
  `revisedOpening`) converts the prompt's "quote them" from a hope into a contract — an
  ungrounded read falls back. Empty transcript → passes (never blocks).
- **Locale / offline:** `activeLocaleSupportsAI()` (the `aiSupported` one-liner that was
  absent from all of `PracticeSupport.swift`) plus the provider/key/endpoint guards return
  a real deterministic grounded read — strictly better than today's raw error, never
  worse. This closes the one substantive feedback surface that violated the locale
  invariant.
- **Coach-lens / single source of truth:** the answered/buried read flows from the same
  `PracticeEvaluator.promptRelevance` + `promptAnswerVerdict` the 7-dimension Relevance
  rating, the live chat coach context, and the Timed three-part note already read — the
  Coach Read can never disagree with them about whether the point led or was buried. The
  per-voice register flows through the same `CoachPersona` / `AIInsightsService.registerClause`
  mapping the post-rep note and debrief use, so it sounds like the same coach.
- **Schema unchanged:** `AICoachFeedback` is byte-identical; a decode test locks the wire
  contract the six render surfaces depend on.

## Deliberately NOT threaded (honest scope boundary)

`CoachMemory` / `workingHypothesis` / `CoachCaseFile` / `activeIntervention` and the
derived Composure/Confidence/Structural reads are **not** added to this surface. That is
multi-struct plumbing across several input owners — the next-tier move flagged in the
audit — and would push past the bounded one-service diff. This pass raises the surface
from shallow to comprehensive on the **substance + grounding + honesty + locale** axes
while staying statically verifiable in one pass.

The model tier (gpt-4o-mini / gemini-2.5-flash) is unchanged — that is a separate lever.
This run raises the *substrate*, not the model.

## Verification (this run)

No Swift/Xcode toolchain and no LLM keys on the build host, so nothing was compiled or
model-run. Verification is static: every ground-truth anchor was confirmed against real
`file:line` before editing; the deterministic verdict inputs in the test suite were
hand-traced against the real `relevanceStopWords` set and the `promptRelevance`
thresholds (`relevanceStrongOverlap = 0.30`, `relevanceWeakOverlap = 0.12`, the 3-content-
word / 12-transcript-word evidence floor); the `AICoachFeedback` schema and all render
call sites were confirmed untouched; the one `AICoachSessionInput` construction site (and
zero test fixtures) was confirmed, so the defaulted init keeps every caller compiling.

This designs the substrate that determines reasoning quality (input richness, rubric
depth, grounding contract, deterministic fallback, locale gate, schema stability) — **not
the felt quality of live responses**, which only on-device QA with real keys can judge.

**Gate (yours):** `xcodebuild test` on a Mac.

## Tracked follow-on (not silent — deliberate deferral)

- Thread the `CoachCaseFile` / active-intervention / derived-read context into
  `AICoachSessionInput` (and the parallel `PostRepCoachNoteInput` / `AIInsightInput`) so
  the Coach Read also reasons about the user's standing hypothesis and observable target —
  the next-tier comprehensiveness move.
- Tune the `engagesTranscript` gate leniency once on-device QA shows the real
  accept/fallback ratio (it is deliberately lenient now — OR across two fields, content-
  word OR slice — to fall back to a real read rather than over-reject).
