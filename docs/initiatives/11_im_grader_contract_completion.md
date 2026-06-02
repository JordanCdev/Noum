# Initiative #11 — IM conversation-grader contract completion (locale gate + deterministic fallback + grounding gate)

Generated: 2026-06-01 · Branch `Redesign` · Status: **built, statically verified, pending `xcodebuild test`**

## Why this exists (the largest remaining contract hole on a primary feedback surface)

IM Mode is Noum's highest-fidelity role-play surface: the user holds a live
instant-message conversation with a tolerance-profiled persona, and the grade it
produces drives the **saved per-session score**, the **relationship state**
(`IMRelationshipProfile`), and the **next coach move**. Initiatives #8/#9 brought
the proven contract — rubric + grounding gate + deterministic fallback + locale
gate — to the post-rep note, the session debrief, and the Coach Read. The IM
grader was the one rich grader still missing **all three** of the load-bearing
contract pillars:

- It **threw** on every gated failure. `evaluateConversation`
  (`Noum/PracticeSupport.swift:8656`) threw `IMModeServiceError.unavailable` /
  `.evaluationFailed` on no-provider, non-2xx, and decode failure. A finished
  conversation — one the user already invested several turns in — dead-ended at
  the `IMPracticeView` "Couldn't finish" error screen offline. That is the
  sharpest possible HONESTY-3 violation: the work happened, and the product threw
  it away.
- It carried **no locale gate**. A Spanish or French IM rep got an English LLM
  grade (or the error screen), in direct violation of the locale invariant the
  rest of the app honors via `LocaleSettingsManager.shared.current.aiSupported`.
- It had **no grounding gate**. A generic, ungrounded LLM grade ("You did a
  solid job overall and showed good composure") was decoded and accepted as-is,
  then **saved as the session's score and headline** — a stat-restate dressed as
  a coach read, persisted to history.

The deterministic signals needed to close all three already existed and were
already the per-turn source of truth: `IMUserMessageAnalyzer.analyze`
(warmth/specificity/reciprocity/hostility/disengagement, `:1441`) and
`IMToneMatcher.score` (`:1410`). So this was pure depth on one existing owner.

Boxes ticked: **IM-SUBSTANCE** (IMConversationEvaluationService contract
completion); **HONESTY-3 extension** (a finished conversation never dead-ends
with a thrown error offline); **HONESTY-4 extension** (non-English IM reps get
the deterministic read, not an English LLM grade).

## What was built (2 files, +13 tests) — extend only, no new files

The `IMConversationEvaluation` wire schema (`:1704`) is **byte-identical** — its
`actualTone/toneMatch/clarity/composure/vocabulary/conversation/headline/
feedback/insights/suggestedDrill/outcome` keys, its `overallScore`/`xpEarned`/
`segments` derivations, and every render + persistence surface in `IMPracticeView`
are untouched. The struct was decode-only before this pass; the deterministic
fallback is its first construction site.

1. **`Noum/PracticeSupport.swift`** — `IMConversationEvaluationService`
   restructured to the proven `PostRepCoachNoteService.generate` /
   `AICoachService.generateDeeperFeedback` shape:
   - **`evaluateConversation`** is now **fallback-first + gated-accept**. The
     deterministic `IMConversationEvaluation` is computed up front from the IM
     analyzers; the body returns it (no longer throws) on `no provider / no key /
     no endpoint / non-2xx / decode failure / ungrounded AI read`. The protocol
     stays `async throws` for type-compat (only the two synchronous
     `JSONEncoder().encode(body)` calls remain throw-capable — a genuinely
     exceptional path), so the call-site `catch` is a real defensive net, not a
     dead toggle. The pre-existing **backend** evaluation path is preserved as a
     higher-fidelity attempt before the deterministic floor, and now also passes
     through the grounding gate.
   - **Locale gate:** `guard activeLocaleSupportsAI() else { return fallback }`
     (new private one-liner mirroring `AICoachService.activeLocaleSupportsAI`
     `:9301`) — a non-English IM rep gets the deterministic grounded read.
   - **`deterministicEvaluation(...)`** (`nonisolated static`, pure, unit-tested)
     — the always-on offline/non-English/no-provider read and the `fallback`
     every gated failure returns. Scores come from the **same** signals the live
     per-turn reads use: `IMToneMatcher.score` → `toneMatch`; the user turns'
     aggregated `IMUserMessageAnalyzer` warmth/specificity/reciprocity/hostility/
     disengagement → clarity/composure/vocabulary/conversation (each `clampScore`
     1...10 — no fake precision). The **headline quotes a real user turn** (the
     longest substantive one, capped to 14 words) — the grounding anchor — and
     short sessions (`<= 2` user turns or `< 30s`) soften to an "early read"
     rather than a confident verdict, matching the LLM prompt's own rule. The
     outcome is resolved by the **shared** `IMConversationOutcomeResolver` so the
     call site's `outcome?.closingMessage` path is preserved end-to-end. Never
     fabricates a quote (no usable turn → grounded scenario read).
   - **`evaluationEngagesTranscript(...)`** (`nonisolated static`, pure,
     unit-tested) — the grounding gate, mirroring
     `PostRepCoachNoteService.engagesTranscript` `:1112` and
     `AICoachService.engagesTranscript` `:9545`: the **headline + insights** must
     share a `>= 4`-char non-stop content word with the transcript OR contain a
     `>= 12`-char verbatim slice of it; empty transcript → passes. On failure the
     grounded deterministic fallback is substituted.
   - A `private nonisolated static let engagementStopWords` (same local-set
     pattern as the two sibling gates — those are `private` to their own types
     and cannot be reused cross-type) plus a private `inferredToneStatic` and the
     deterministic headline/feedback/insights/drill builders.

2. **`Noum/IMPracticeView.swift`** — **unchanged**. The grade is now
   non-throwing on every gated path, so the `evaluationFailed` "Couldn't finish"
   screen is effectively unreachable (a finished conversation always produces a
   grounded grade). The `try`/`do`/`catch` at the call site (`:1160`) still
   compiles and is left as the defensive net for the one remaining throw-capable
   path (request-body encoding) — exactly the precedent set by `SummaryView`'s
   `catch` for the Coach Read in initiative #9.

3. **`NoumTests/NoumTests.swift`** — `IMConversationEvaluationContractTests`
   (~13 cases): the deterministic fallback quotes an actual turn from a fixture
   conversation; the fallback clears its own grounding gate (no substitution
   loop); every dimension + `overallScore` clamps to `1...10`; the fallback's
   `toneMatch` equals the shared `IMToneMatcher.score` for the same tone/
   transcript (single-source agreement); short-session + empty-turns soften to an
   early read and never fabricate a quote; the grounding gate accepts a
   content-word match, a multi-word quoted detail, and an isolated `>= 12`-char
   verbatim slice with NO shared content word (proving the slice branch), rejects
   a generic ungrounded read, and passes an empty transcript; and the schema
   decodes unchanged (with and without the optional `outcome`).

## Invariants honored (the proven contract)

- **Rubric / single source of truth:** the fallback grade is computed from the
  SAME `IMToneMatcher` + `IMUserMessageAnalyzer` signals the live per-turn reads
  and the relationship layer already consume, so the saved grade can never
  disagree with the tone/relationship reads. `toneMatch` is pinned equal to the
  shared matcher in a test.
- **Grounding enforced in code:** the post-hoc `evaluationEngagesTranscript` gate
  converts the prompt's "reference an actual moment" from a hope into a contract
  — an ungrounded grade falls back rather than being saved as the score.
- **Deterministic fallback (real, grounded):** offline / non-English /
  no-provider returns a genuine coach-grade read that quotes a real turn and
  resolves a real outcome, never raw error text and never worse than today.
- **Locale gate:** the `aiSupported` one-liner returns the deterministic read on
  es-ES / fr-FR rather than an English LLM grade.
- **Score-safety:** IM scores are this surface's OWN grade (no shared per-rep
  numeric score is touched). The fallback's scores are clamped `1...10` and the
  schema's `overallScore`/`xpEarned` derivations are byte-identical.
- **No fake certainty:** short sessions soften to an "early read"; the fallback
  never fabricates a quote (no usable turn → grounded scenario read, no empty
  `''`).
- **Bounded / decode-safe / defaulted:** the schema is unchanged and still
  decode-safe (the optional `outcome` decode is pinned); the fallback is the
  struct's first construction site and uses the synthesized memberwise init in
  exact field order.
- **Coach-lens + brand:** one coherent read across the live reads + the fallback;
  patient-but-decisive copy in the restrained voice (no "!", no chirp, all under
  the 320-char field bound the sibling services enforce).
- **No dead toggle:** `IMModeServiceError.evaluationFailed` is no longer thrown,
  but it remains a valid member of the `LocalizedError` type (Swift does not warn
  on unused enum cases); the `evaluationFailed` UI state is still reachable via
  the request-encoding throw, so it is a defensive net, not a dead affordance.

## Deliberately NOT changed (honest scope boundary)

- The model tier and the LLM `systemPrompt` / `prompt` for the IM grader are
  unchanged — this run raises the **substrate** (fallback + grounding + locale),
  not the model or the live prompt copy, mirroring initiative #9's boundary.
- The `IMModeAvailability.isAvailable` top-of-method throw was removed (it gated
  whether IM is *startable*; by the time `evaluateConversation` runs the
  conversation has already happened, so the no-provider/no-backend case now falls
  through to the deterministic floor rather than dead-ending a finished rep).

## Verification (this run)

No Swift/Xcode toolchain and no LLM keys on the build host, so nothing was
compiled or model-run. Verification is static:

- Every ground-truth anchor (the schema, the analyzers, `IMToneMatcher`, the
  outcome resolver, the locale one-liner, the two sibling grounding gates, the
  call site) was confirmed against real `file:line` before editing.
- Brace balance on both edited files is exact (1581/1581 and 2456/2456).
- The grounding-gate fixtures were hand-traced with a standalone model mirroring
  the real tokenizer (`split` on non-letter/non-number), the `>= 4`-char filter,
  the exact `engagementStopWords` set, and the `>= 12`-char slide window: the
  slice-isolation fixture passes via the **slice** branch only (content-word
  branch confirmed not firing), the reject fixture returns `false`, and the
  accept fixtures return `true` — all as asserted, no off-by-one.
- The fallback fixture's longest user turn was confirmed unambiguously longest
  (68 chars vs ~59-62) and exactly 14 words (the cap), so the whole turn appears
  in the headline regardless of `max(by:)` tie semantics.

This designs the substrate that determines reasoning quality on the IM surface
(non-throwing finish, grounded fallback, grounding contract, locale gate, schema
stability) — **not the felt quality of live LLM grades**, which only on-device QA
with real keys can judge.

**Gate (yours):** `xcodebuild build-for-testing` + `xcodebuild test
-only-testing:NoumTests/IMConversationEvaluationContractTests` on a Mac, then the
full suite as the pre-TestFlight gate.
