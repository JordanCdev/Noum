# Initiative #8 — Prompt-grounded content read ("did you answer it / lead with the point")

Generated: 2026-06-01 · Branch `Redesign` · Status: **built, pending `xcodebuild test`**

## Why this exists (the feedback-intelligence finding)

A repertoire + feedback-intelligence audit (workflow `coach-repertoire`, run `wf_711a603f-6aa`)
asked the blunt question: is Noum's feedback *a coach who heard you*, or *metrics with
nice copy*? The honest verdict:

- **Delivery** (fillers, pace, pitch/monotone via real on-device f0, vocal energy,
  pauses, composure/confidence fusion) is genuinely strong and honest — rivals or
  beats most apps.
- **Substance** was near-absent. The decisive fact, verified three ways:
  `PracticeSession.prompt` (the question the user answered) **is stored** and **is in
  scope at the eval call site**, yet **no feedback surface — deterministic or LLM —
  ever compared the answer to the question.** `Relevance: Stayed on topic` was literally
  `min(wordCount/65, 1) >= 0.7`. Both LLM input structs lacked a question field, so even
  the surfaces that read the transcript couldn't judge "did you answer it" or "did you
  bury the lede" — the half of coaching that separates *clear* from merely *polished*.

This was the single highest-leverage gap: it repairs the load-bearing relevance signal
that **every Timed rep** surfaces and that downstream reads (StructuralRead, drill focus,
coach context) inherit.

## What was built (5 files, ~13 tests)

Pure depth on existing owners — no new store/screen/engine/routing, no new UI, copy
byte-identical.

1. **`Noum/PracticeSupport.swift`** — `PracticeEvaluator.PromptRelevanceRead` + pure
   `promptRelevance(prompt:transcript:)` with 5 named, test-locked thresholds
   (`minPromptContentWordsForRelevance=3`, `minTranscriptWordsForRelevance=12`,
   `relevanceStrongOverlap=0.30`, `relevanceWeakOverlap=0.12`, `relevanceAbsentDefault=0.70`).
   Conservative lexical content-word overlap between question and transcript;
   `evaluateTimedPractice` gains a `question:` param and feeds the rating (NOT the score)
   `relevanceProgress: evidenceFloorMet ? progress : nil` — byte-identical to the old
   length proxy on weak/absent evidence, so it never drifts up or down on thin data.
2. **`Noum/PostRepCoachNoteService.swift`** — `prompt` field on `PostRepCoachNoteInput`;
   `THE QUESTION ASKED: …` injected before the transcript block; a **presence gate**
   (`engagesTranscript`) that falls back to the deterministic note if the AI note doesn't
   actually engage the transcript (mirrors `GrammarFeedbackService`'s excerpt-must-appear).
3. **`Noum/AIInsightsService.swift`** — `promptOverride` on `AIInsightInput`; question
   injected into the sessionDebrief read.
4. **`Noum/TimedPracticeView.swift`** — passes the in-scope `question` into the evaluator.
5. **`NoumTests/NoumTests.swift`** — relevance reducer boundary/floor/ramp tests,
   score-invariance (off-topic changes rating not score), the engagement gate, and
   prompt-injection presence/omit tests.

## Invariants honored

- **Score safety:** `rawScore` still reads only `contentProgress`; only the Relevance
  *rating* changed. No numeric-score movement.
- **No fake certainty:** overlap-driven reads clamp at `.ok` (0.45) — never a confident
  "off-topic" verdict from lexical overlap alone on a borderline sample; evidence floors
  default high; weak evidence falls back to today's behavior exactly.
- **Locale/offline:** AI gates untouched; non-English/offline gets the deterministic
  overlap rating + deterministic note.
- **Coach-lens:** the stored `PracticeSession.prompt` is the single source of truth across
  the deterministic rating + both AI reads.

## Verification (this run)

Three parallel cold-read lenses. Compile + coherence: non-blocking. Test-trace: 3
**test-fixture** bugs (not implementation bugs) — an off-by-one content-word count and two
too-coarse substring matchers — all fixed and re-verified against real source:
- `across` (≥4 chars, not a stop word) made the boundary prompt 11 words not 10 → corrected to a true 10-word prompt so 3/10 = 0.30 hits the `.good` boundary.
- the two "omit" tests matched the bare phrase `THE QUESTION ASKED`, which now also appears
  in the transcript-block header → tightened to the colon-qualified injected line `THE QUESTION ASKED: `.

**Gate (yours):** `xcodebuild test` on a Mac. No Swift toolchain on the build host, so all
of the above is static analysis + hand-tracing.

## Tracked follow-on — LANDED (2026-06-01)

The one place "one coherent read across every surface" was not yet fully literal: the live
chat coach (`CoachContextBuilder`) and the `FeedbackEngine` three-part Timed note didn't
carry the prompt-answer signal *directly* — the chat coach inherited it as free-text via the
LAST REP NOTE. **This is now closed.** Both surfaces read the SAME pure reducer.

What was built (5 files, ~19 tests):

1. **`Noum/PracticeSupport.swift`** — `PracticeEvaluator.PromptAnswerVerdict` (`.answered` /
   `.partial` / `.buried`) + pure `promptAnswerVerdict(for:)` mapping a `PromptRelevanceRead`
   onto the shared band using the SAME named overlap thresholds the rating uses. Returns
   `nil` below the evidence floor — the single point both follow-on surfaces call into, so
   the chat coach and the post-rep note can never disagree about a rep.
2. **`Noum/CoachContextBuilder.swift`** — a `PROMPT RELEVANCE` rep-context section (Timed
   most-recent rep only; IM relevance stays carried by the TONE-DRILL sections) via
   `promptRelevanceLines(for:prompt:)`, mirroring the `toneDrillTrajectoryLines` data-line +
   guidance-clause register, plus system-prompt intelligence-floor **rule 14** (lexical
   association, never a confident off-topic). Omitted entirely below the evidence floor.
3. **`Noum/FeedbackEngine.swift`** — `promptRelevance:` param on `VerdictEngine.generate`
   (Layer 2b) + `buildPromptRelevanceNote`, the Timed analog of `buildIMContextNote`:
   appends ONE constructive "lead with the point" nudge to the leverage line, and ONLY on a
   clear miss (`.buried`). Never moves the score, momentum, or next-step.
4. **`Noum/SessionFinalizer.swift`** + **`Noum/SummaryView.swift`** — compute the read from
   the in-scope `sessionPrompt` + transcript (Timed only; nil elsewhere keeps every other
   mode byte-identical) and thread it into both `generate` call sites.
5. **`NoumTests/NoumTests.swift`** — `PromptRelevanceFollowOnTests` (~19): verdict-band
   mapping incl. the strong-boundary-inclusive + below-floor-nil cases (reusing the #8
   ScoreCalibration fixtures so overlap bands stay locked); the FeedbackEngine note fires
   on `.buried` / stays silent on `.answered`/`.partial`/below-floor / leaves momentum +
   next-step byte-identical / restrained-copy (no "off-topic", no fanfare) / nil-arg
   back-compat; the chat section surfaces on buried + answered Timed reps, omits below the
   floor and for non-Timed reps; and the decisive `oneReadDrivesBothSurfaces` coherence test.

Invariants honored (same as the parent slice): association not causation (copy + rule 14 +
the association disclaimer in the buried guidance); no confident off-topic on weak evidence
(verdict is `nil` below the floor, the note fires only on the clear-miss band, the leverage
nudge is constructive not a verdict); deterministic + offline (pure reducer, no AI gate
touched); copy in the restrained voice ("lead vs buried", byte-shaped like
`buildIMContextNote` and the tone-drill lines).

**Verification (this run):** `xcodebuild build-for-testing` (app + NoumTests) compiled clean
(exit 0); `xcodebuild test -only-testing:NoumTests/PromptRelevanceFollowOnTests` ran green
on the iPhone 17 Pro simulator (all ~19 cases passed). The full `xcodebuild test` suite is
still the human's pre-TestFlight gate.

## The next repertoire gaps (ranked, from the same audit)

After this lands, the highest-value **new deliberate-practice exercises** a coach would
assign (all confirmed genuinely missing): lead-with-the-point / BLUF detection (now
unblocked by the prompt anchor); guided STAR/narrative drill with per-beat prompts and a
"turn" check; named persuasion frameworks beyond PREP (AREA, Monroe's, claim-evidence-warrant);
reframing/bridging hostile questions; elevator-pitch / analogy / articulation warmups; and
deeper IM tone/relevance grading (today single-keyword lookup on the highest-fidelity
role-play surface).
