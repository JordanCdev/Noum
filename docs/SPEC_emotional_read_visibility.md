# Spec — make the coach's emotional read visible (rank 1, 2026-06-14 eval)

Status: **APPROACH #1 SHIPPED 2026-06-15 — commit `985ba09` (`COACH-VISIBLE`).**
The "Recommended approach (lowest-risk)" below — strengthen the frame instruction
— is now in `CoachContextBuilder.liveCoachingFrameLines`: when a signal is
**strong this turn AND sustained across the arc** (`primary.confidence == .strong`
and `detectArcPattern(...).signal == primary.signal`), it appends a near-imperative
"Open this reply by naming this read in plain language…" line. The coach's words
stay model-generated, so they still pass the reply quality gate, and a weak /
tentative / one-off read never forces a visible open. Pure + 3 unit tests
(`strongSustainedSignalEmitsMandatoryOpenInstruction`,
`tentativeSignalNeverForcesVisibleOpen`, `oneOffStrongSignalDoesNotForceVisibleOpen`).
Verified green on the iPhone 17 Pro simulator (full `CoachContextBuilderTests`
pass; a deliberate FAIL-probe confirmed the new tests are genuinely selected and
executing). NB: `985ba09` was committed by the concurrent `noum2` run from an
identical in-tree implementation; the `noum-1` run reproduced the same code
byte-for-byte independently and ran the verification above — two agents converging
on the same minimal change is itself a correctness signal.

**Still owed before this is fully closed:** the on-device felt-QA of the *spoken*
open (does the model's resulting acknowledgment sound like a coach or a template,
across warm / authoritative / concise / executive voices). The instruction is in
place and safe; the felt quality of the output it produces is the human gate an
autonomous run cannot stand in for. The guaranteed-gate path (below) remains
unbuilt and is only needed if QA finds the model disobeys the instruction.

----

Original spec (retained for the guaranteed-gate path, still unbuilt):

Its precision prerequisite (rank 4, confidence-graded detection) **shipped** on
`49b96e9`+, so the foundation this depends on is in place.

## The gap

`CoachContextBuilder.liveCoachingFrameLines` already detects an emotional signal
and tells the model how to handle it (`emotionalCoachingMove`), but those are
*guidance lines fed into the prompt* — not user-facing text. The model **may or
may not** open by naming the read. Result: the single most coach-defining
moment ("I'm hearing some frustration — that's been the thread for a few turns")
is left to chance. Being *seen* is the coaching; right now it's invisible at the
exact trust moment.

## Why it's delicate (read before building)

- `emotionalCoachingMove(...)` returns **model instructions**, not user copy.
  You cannot prepend it to the reply verbatim — it would read as clinical
  meta-text.
- Prepending an authored line *bypasses* the reply-quality gate
  (`AICoachChatService.deterministicReplyOutcome` / `replyQualityIssue`) and
  risks **double-naming** if the model also acknowledged the feeling.
- Ships false empathy if the detector misfires — which is exactly why rank 4
  (now landed) had to come first.

## Recommended approach (lowest-risk of the visible options)

Prefer **strengthening the frame instruction** over mechanically injecting text:

1. In `liveCoachingFrameLines`, when a **strong + sustained** signal exists
   (now distinguishable via the shipped confidence grade + confidence-weighted
   `detectArcPattern`), append a near-imperative line:
   `- Open this reply by naming this read in plain language before anything else
   (one short clause, e.g. "Sounds like the last few reps have been
   frustrating"). Do not use clinical labels.`
   The coach's words stay **model-generated** → they still pass the normal
   quality gate, and there's no double-naming because the model owns the whole
   reply.
2. Keep the existing tentative path silent-to-soft (no mandatory open) so a weak
   signal never forces a visible misread.

If product wants a **guaranteed** visible acknowledgment (model can disobey #1):
add an `EmotionalSignalVisibilityGate` as a pure post-reply pass in
`CoachReplyPipeline.generate` (after `AICoachChatService.reply`, before
`AskNoumStore.completeCoachTurn`). It must:
- expose a small **internal** read from `CoachContextBuilder` of `(signal,
  confidence, sustained)` for the current turn (do **not** widen the private
  `EmotionalSignal` enum — return a plain label string + bool);
- only fire on **strong + sustained**;
- scan the model reply for soft-acknowledgment lexemes (hear/feel/sense/picking
  up/that's been) and **skip** if already named (no double-naming);
- prepend ONE authored plain-language clause keyed off the signal label (a small
  bounded copy table — NOT `emotionalCoachingMove`), never quoting user words
  (so `ProofMomentService` is untouched);
- respect the 2-sentence reply budget — replace, don't add, if it would overflow.

## Files

- `Noum/CoachContextBuilder.swift` (`liveCoachingFrameLines`; optional internal
  read accessor for the gate)
- `Noum/CoachReplyPipeline.swift` (only if the guaranteed-gate path is chosen)

## Tests

- `test_strongSustainedSignal_emitsMandatoryOpenInstruction`
- `test_tentativeSignal_neverForcesVisibleOpen`
- `test_visibilityGate_skipsWhenReplyAlreadyNamesTheFeeling` (gate path)
- `test_visibilityGate_neverQuotesUserSpeech` (gate path)
- `test_visibilityGate_respectsReplySentenceBudget` (gate path)

## Required human QA before merge

On-device, real provider key: does the opened acknowledgment sound like a coach
or like a template? Run the warm / authoritative / concise / executive voices.
This is the felt-quality gate the autonomous run cannot stand in for.
