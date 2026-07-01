# iter 10 — Real-pipeline (app-path) eval: finding

Mined the existing app-path report (`reports/app-path/latest.json`, 2026-07-01 01:06),
the sibling's Python engine grading REAL app-generated candidates — the "what users
get" data the Node prompt-faithful engine can't see.

**Headline:** avg 68.54/100, FAILS thresholds; groundedRead weakest (63.3); dominant
failure "reply does not match expected coach move" on 8+ of the worst 10.

**Verified cause — NOT a production LLM-quality problem:**
- Trace provider breakdown: 31× gpt-4o-mini, **18× "Typed judgement fallback"
  (CoachAssessment)**, 1× null. 17 replies share the identical generic opening
  "Your last rep gives one usable signal: latest rep Timed, 7/10, 1 fillers, 50s…".
- For the typed-fallback fixtures, the trace's `rawReply` (the actual LLM draft) is
  GOOD and on-target — e.g. examples-from-sessions-010 rawReply: "One example is the
  rep where you said 'we focused on three priorities'… add one concrete example after
  the first reason" (directly answers "give me an example"). networking-intro-029
  rawReply builds the 20-second intro. But `finalReply` = the generic typed template,
  with `typedAssessmentFallbackApplied: true`, `qualityGateAcceptedFallback: true`,
  and **`issues: []`** (no gate rejection recorded).
- Production Swift (`AICoachChatService`) applies `deterministicAssessmentFallbackReply`
  ONLY when `sawContentRejection` (every provider content-rejected); with `issues: []`
  + a good rawReply, production would RETURN the good reply, never fall back. So the
  trace's typed-fallback-with-good-rawReply is a HARNESS artifact of the sibling's
  eval (capturing the typed read as the candidate; gpt-4o-mini, not production gemini),
  consistent with the known "harness artifacts, not bugs" note (coach_reliability_gate).

**Conclusion:** this report does NOT demonstrate production pipeline degradation — the
LLM `rawReply` layer is producing good, on-target replies. The 68.5 under-states real
quality because ~36% of graded candidates are the generic typed fallback, not the LLM
reply. To get a trustworthy real-pipeline number, the eval must (a) use the PRODUCTION
provider (gemini-3.5-flash, not gpt-4o-mini) and (b) grade the FINAL LLM reply, not the
typed fallback. Needs the sibling's harness + a key (blocked headless) — coordinate,
don't unilaterally change the sibling's engine.

**One real (edge-case) product observation — candidate, low priority:** the typed
fallback `deterministicAssessmentFallbackReply` is TURN-BLIND — it emits the same
"your last rep gives one usable signal: 7/10, 1 filler, 50s" regardless of whether the
user asked for an example, a networking intro, or a causation check. It only fires when
ALL providers content-reject (rare), but when it does the user gets a generic
non-answer. Worth making the fallback at least address the turn TYPE. Product call for
Jordan.
