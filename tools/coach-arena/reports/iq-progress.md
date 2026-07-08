# IQ/RAG architecture push — progress log

Goal: raise the honest gold-suite mean toward 90+ on all five dimensions by
moving intelligence into the app's own retrieval/knowledge/decision layer
(docs/RAG_IQ_ARCHITECTURE_RESEARCH.md), so Haiku (coach) + Sonnet (judge)
genuinely clears the bar. Every number below is a live run:
`ARENA_MODEL=claude-haiku-4-5-20251001 ARENA_JUDGE_MODEL=claude-sonnet-4-6 ./tools/coach-arena/run.sh run`.

## Baseline (2026-07-08, commit 3acd7939)

Mean **62.7**. IQ 18.4/25 · EQ 17.4/25 · Memory 13.4/20 · Intervention 9.9/15 · Dialogue 10.6/15.
Floor 3 (`set-authoritative`). 30/51 sub-70.

Key finding from reading tools/coach-arena/runners/replay.mjs +
lib/context.mjs: **the arena is a single-shot call** — system prompt +
rendered context -> one generate() -> deterministic checks + judge. It does
NOT exercise the Swift app's retry/repair loop, quality gates, or reliability
gate (those live only in `AICoachChatService.reply`/`CoachReplyPipeline`).
So every lever that can move this score has to live in either (a) the
literal system-prompt text `CoachContextBuilder.systemPrompt` extracts, or
(b) the context-block content the harness renders. Retrieval
(`KnowledgeRetriever`/`CoachingKnowledgeBase`) was **completely unused** by
the harness — 0/51 gold fixtures set `memoryState.coachingExpertise`, so the
"RAG" half of the architecture had never been measured at all.

## Round 1 — REPLY CONTRACT primacy block (system prompt only)

Change: added a compact, imperative "REPLY CONTRACT" checklist at the very
TOP of `CoachContextBuilder.systemPrompt` (before the per-voice personality),
covering: explicit word ceilings per situation, one-move discipline, no
scaffold labels, voice-propose-not-set + engaging->Storytelling/Warm mapping.
Rationale: the existing ~400-line prompt already states nearly every rule
these fixtures violate, but buried mid-document; primacy + a scannable
checklist should help a weak one-shot model actually comply. This is the
"compress/prioritize for a distractible small model" lever (research finding
6/7) applied to the instruction layer, not just retrieved knowledge.

**Result: mean 62.7 -> 63.7 (+1.0).** Dimensions roughly flat: IQ 18.4->18.8,
EQ 17.4->17.7, Memory 13.4->13.4, Intervention 9.9->9.7 (-0.2, noise),
Dialogue 10.6->10.9. Sub-70 fixtures 30->28. Floor 3->9.

Wins: trust-repair category +5.7, cold-start +45, off-topic +25,
leadership-update +21.
Regressions (diagnosed from failures.md): the new contract's heavy emphasis
on "exactly ONE next move" crowded out the pre-existing "acknowledge before
advise" / "a move can be rest" nuance on vulnerable/exhausted turns —
`feel-like-fraud` 55->30, `exhausted` 46->32, `its-not-easy` 36->38 (still
failing) all got WORSE: the model rushed to a drill/question instead of
sitting with the feeling. Also: `set-authoritative` stayed catastrophic (3->9,
still says "Done... Tap the confirmation card" almost verbatim) despite an
explicit contract bullet banning exactly that — a real, narrow ceiling on
what one-shot prompt text can force from Haiku (production catches this via
a deterministic repair-loop gate the arena doesn't run). One new fabricated-
metric miss (`plan-request-week`: invented "160 wpm" instead of a number
already in context) — added an explicit "never invent a number not already
in CONTEXT" rule in response.

**Verdict: KEPT** (net positive, no dimension materially regressed) — but
immediately patched forward (still round 1, not yet re-measured standalone)
with: (a) explicit rest-is-a-valid-move + acknowledge-first-on-vulnerable-
turns rule, (b) never-invent-a-number rule. These will be measured together
with round 2's retrieval changes since both are well-motivated, low-risk,
independent-file changes — see below.

## Round 2 — retrieval precision + knowledge base + depth-rules fidelity (in progress)

Three changes bundled into one measured run (to conserve full-run cost/time;
each is independently well-motivated and touches different files):

1. **Retrieval precision gate** (`Noum/KnowledgeRetriever.swift` +
   `tools/coach-arena/lib/knowledgeRetrieval.mjs`, faithful JS port): the
   BM25 admission gate was `score > 0`, which is far too permissive on short
   conversational queries — common-word overlap let an off-topic card
   (e.g. a conflict-de-escalation card) outscore the genuinely relevant one
   (measured directly: for "when I pause I lose my train of thought", the
   highest-BM25 card was an unrelated story-arc card at 7.99 vs the relevant
   pause card at 4.49). Added a keyword-anchor requirement: a card is only
   admitted when the user's own words hit one of its curated `keywords`
   (verified against all existing `KnowledgeRetrieverTests` — still pass).
   Also cut `defaultLimit` 4->2, matching the system prompt's own "pull in at
   most one or two techniques" rule instead of leaving 4 noisy candidates for
   the model to self-filter.
2. **Knowledge base gap fill**: added `filler-give-the-pause-a-job` card —
   the corpus had NO card for "the pause feels awkward / I lose my train of
   thought", which is exactly the `okay-thats-cool-however` fixture's
   expected move and a plausible generalizable real-user question.
3. **Arena fidelity gap — CoachPromptBundle depth-rules port**
   (`tools/coach-arena/lib/depthRules.mjs`): discovered `CoachReplyPipeline`
   appends `CoachPromptBundle.contextBlock` (per-turn-depth length budgets +
   rules) to context on every real turn, gated only by a default-on flag —
   but the arena's `context.mjs` never rendered any of it. Ported only the
   PURE, turn-depth+surface-conditioned half (`universalCoachLines` +
   `instructionLines` — no per-user computation); explicitly did NOT port the
   typed-verdict half (`directVerdict`/`evidenceUsed`/`nextProofTest`), since
   that requires `CoachReasoningPass` scoring a full `UserTrajectorySnapshot`
   that fixtures don't carry — faking it would mean inventing a plausible-
   looking but non-real computation. This was a real "the harness tests
   Haiku with less scaffolding than production gives it" gap, not a lever
   pulled for score.
4. Retroactive round-1 patch (vulnerable-turn nuance + never-invent-a-number)
   included in this measurement.

**Result: mean 63.7 -> 63.3 (-0.4).** Deep-assessment mean cratered 72.1 -> 64.2
(-7.9), big-moment -23. Diagnosed the deep-assessment/big-moment regression to
the depth-rules port specifically: for `big-moment-wedding-speech` (an
emotionally-loaded "I'm dreading my brother's speech, I always go blank" turn
classified as `deepAssessment`), the ported instruction forced "verdict first,
separate mechanics from goal readiness, name missing evidence, end with one
proof test" onto a turn that needed warmth + an immediate concrete step —
production pairs that same instruction with an ADAPTIVE typed verdict
(`CoachReasoningPass`) that would have softened/retargeted it; the bare
instruction text without that nuance is a worse mismatch than omitting it.

**Action: unwired `depthRulesBlock` from `context.mjs`** (kept the file —
faithful and possibly useful later paired with adaptive nuance — just stopped
calling it). Re-ran retrieval+card alone (no depth-rules) to isolate:

## Round 3 — retrieval + knowledge card only (depth-rules reverted)

**Result: mean 63.3 -> 63.9 (+0.6).** Deep-assessment recovered to 72.1
(back to round-1 level, confirming the depth-rules diagnosis). BUT
`big-moment-wedding-speech` got WORSE again (33 -> 25) even with depth-rules
OUT — direct proof that fixture's swing wasn't solely about depth-rules; it
also independently re-uses the hard-banned phrase "your brain" almost every
draw (Haiku's default explanatory metaphor for a mental lapse), which caps
the score regardless of context content. Also: `goal-change` category
cratered to 22.7 (from 36 in round 2) purely from **resampling the same
prompt+context** — retrieval never even fired for those two fixtures (no
`baseline`/`caseFormulation`/`coachMemory`/`rating` field for the gate to
key on), so the round-2 vs round-3 prompt was byte-identical for them, yet
scores swung 36 -> 22.7 from Haiku's own sampling variance alone. **This is
the clearest direct evidence this session that single-run deltas of even
10-25 points at the category level can be pure generation noise, not
signal** — confirms the standing methodology note (dual-arm A/B needed to
trust a subtle effect; large systematic effects like the depth-rules
mismatch still show through the noise).

Added two more targeted, independently-justified fixes in response to
recurring, mechanically-cited failures (not chasing this run's specific
numbers): explicit ban on brain/neuroscience-metaphor phrasing (own the
observable pattern, not "your brain"), and an explicit requirement that a
"which voice should I pick" turn must lead with one concrete recommendation,
never a bare clarifying question.

## Round 4 — + brain-phrase ban + voice-recommendation enforcement

**Result: mean 63.9 -> 64.8 (+0.9).** Best run yet, and the only one where
**all five dimensions sit above the original baseline simultaneously**: IQ
18.9 (base 18.4), EQ 18.2 (base 17.4, best of any run), Memory 13.7 (base
13.4, best of any run), Intervention 10.0 (base 9.9), Dialogue 10.8 (base
10.6). `set-authoritative` remained pinned near zero (7/100) — the single
most-reproducing failure across every round of this session (3, 3, 9, 1, 7 —
never above 16/100 in 5 runs) despite three independent rule restatements
banning exactly this pattern ("Done... Tap the confirmation card to lock it
in"). This looks like a genuine one-shot compliance ceiling for Haiku on
this specific input, not a wording problem — production catches it via a
deterministic repair-loop gate (`goalIntentStateDirective` +
`CoachReliabilityGate`) that the single-shot arena structurally cannot
exercise.

Added one more targeted fix for this exact, most-catastrophic recurring
failure: a concrete few-shot bad/good example pair for "just set me to
authoritative" in the "Senior-coach examples" block (abstract rules clearly
weren't landing after 3 restatements; a concrete negative example is a
different, more concrete lever).

## Round 5 — + few-shot voice-set example (final measured state)

**Result: mean 64.8 -> 62.9 (-1.9).** The fix worked exactly as intended for
its target category — `goal-change` jumped from 28 to 52.7 (+24.7),
including `set-authoritative` finally getting real content instead of a
bare "Done." — but the AGGREGATE dropped because five UNRELATED categories
that this edit could not possibly touch (interview-prep -22,
repetition-callout -30, score-question -20, memory-recall -14,
leadership-update -15) all swung hard negative in the same draw. This is the
same generation-variance signature as round 3, now unambiguous: a
category-specific edit produced its intended category-specific gain while
the headline mean moved in the opposite direction from resampling noise
elsewhere. Full `NoumTests` suite re-verified green (3316/3316 passed, 0
failures) after every change in this session.

## Honest summary across all 5 post-baseline measurements

| Run | Mean | IQ/25 | EQ/25 | Mem/20 | Interv/15 | Dialogue/15 |
|---|---|---|---|---|---|---|
| Baseline | 62.7 | 18.4 | 17.4 | 13.4 | 9.9 | 10.6 |
| Round 1 | 63.7 | 18.8 | 17.7 | 13.4 | 9.7 | 10.9 |
| Round 2 | 63.3 | 18.6 | 17.3 | 13.2 | 9.9 | 10.4 |
| Round 3 | 63.9 | 18.7 | 17.4 | 12.9 | 10.0 | 10.7 |
| Round 4 | 64.8 | 18.9 | 18.2 | 13.7 | 10.0 | 10.8 |
| Round 5 | 62.9 | 18.7 | 17.7 | 13.4 | 10.0 | 10.6 |
| **Avg of 5** | **63.72** | **18.74** | **17.66** | **13.32** | **9.92** | **10.68** |
| **Δ vs baseline** | **+1.0** | **+0.34** | **+0.26** | **-0.08** | **+0.02** | **+0.08** |

**Kept in the final committed state** (each independently verified/justified,
not chasing a specific noisy run): REPLY CONTRACT primacy block (length
ceilings, one-move discipline, scaffold-label ban, voice-propose rules,
vulnerable-turn/rest-is-a-move nuance, never-invent-a-number, brain-phrase
ban, voice-recommendation enforcement, few-shot voice-set example);
retrieval precision gate + `defaultLimit` 4->2 in `KnowledgeRetriever.swift`
(verified via 13/13 `KnowledgeRetrieverTests` + direct manual inspection
showing correct top-ranked cards); new `filler-give-the-pause-a-job`
knowledge card (fills a real, verified corpus gap); faithful JS ports of all
of the above for the arena (`knowledgeRetrieval.mjs`, `extractKnowledgeBase.mjs`).

**Reverted**: the `CoachPromptBundle` depth-rules port (`depthRules.mjs`) —
file kept but unwired from `context.mjs`, since it measured net-negative with
a clear causal mechanism (blunt turn-depth-only framing without the adaptive
typed-verdict nuance production pairs it with).

## Honest ceiling assessment (this session)

The gold-suite mean moved from **62.7 to an average of ~63.7** across five
post-change measurements (individual runs: 62.9-64.8) — a real but modest
gain, not a breakthrough, and **nowhere close to 90 on any dimension**.
Remaining gap to 90 (using the 5-run average): IQ needs +6.3 (25/25 ->
current 18.7), EQ needs +7.3, **Memory needs +6.7 and is the only dimension
that did NOT improve** (13.3/20 avg, essentially flat vs baseline 13.4 — the
retrieval/knowledge-card work targets IQ/Intervention, not Memory, and no
change this session directly improved how the model weaves the user's own
specific data into an "un-swappable" answer), Intervention needs +3.6,
Dialogue needs +2.8.

Two structural reasons this plateaued rather than closing the gap:

1. **The arena is single-shot; production is not.** Production's real
   reliability comes from a retry/repair loop and multiple deterministic
   gates (`AICoachChatService.replyQualityIssue`/`semanticQualityIssue`,
   `CoachReliabilityGate`) that regenerate or substitute a reply when it
   trips a disqualifier. The single most catastrophic, most-reproducing
   failure in the whole fixture set (`set-authoritative`, pinned at
   1-16/100 across every run) is exactly the kind of failure those
   production gates exist to catch. No amount of system-prompt wording
   closes that gap in a one-shot harness — the fix lives in the harness's
   fidelity to production's retry architecture, not in the prompt.
2. **Generation variance is large relative to the effect sizes available
   from prompt/retrieval tuning.** Category-level swings of 15-30 points
   from resampling the IDENTICAL prompt+context (rounds 2 vs 3's
   `goal-change`, round 5's five unrelated-category swings) are the same
   order of magnitude as the total gain this session achieved. Single
   before/after runs are not sufficient to confidently attribute mean
   movements under about 3 points; only changes with an independently
   verifiable mechanism (unit tests, direct inspection, or a clear causal
   story corroborated by category-level movement matching the change's
   actual scope) should be trusted from one run.

Memory + Intervention (the two dimensions the goal named weakest) remain the
weakest, and Memory specifically did not move this session — closing that
gap needs a different lever than this session pulled (e.g., an explicit
"un-swappable" self-check tied to the user's specific cited facts, or
wiring real `CoachCaseFile`/trajectory evidence into a richer, adaptive
context block — the `CoachReasoningPass`/`CoachPromptBundle` typed-verdict
half this session deliberately did not fake). That is the highest-value
next lever, not further system-prompt wordsmithing.
