# Noum Chat With Noum - Updated Assessment

Date: June 28, 2026  
Scope: Chat with Noum and Live Coach, measured against the deep-research brief for expert coaching judgement, low-latency response, memory, trust repair, and evidence-grounded advice.

## Headline Score

**88 / 100**

This score is for the current Chat with Noum / Live Coach experience against the targeted research brief, not for full professional human-coach replacement.

If scoring the broader ambition of "Noum as a validated replacement for a strong human communication coach," the honest score is lower: **72 / 100**. The product is now much stronger as a coaching system, but true coach parity still needs real-world outcome validation, richer perception signals, and more longitudinal evidence.

## One-Line Read

Noum has moved from "grounded but sometimes shallow AI advice" to a real low-latency coaching judgement system: it now classifies the user's intent, forms a typed assessment before wording, separates mechanics from readiness, repairs bad answers, streams or shows an immediate local read, and avoids slow live retrieval loops.

## What Changed Since The Previous Assessment

The largest change is architectural. The app no longer asks the model to invent judgement from a blob of context. It now creates a deterministic coaching assessment first, then asks the model to verbalize it.

Resolved:

- Added turn-depth classification: quick move, grounded read, deep assessment, trust repair.
- Added deterministic coach reasoning before LLM wording.
- Added goal-rubric scoring for the authoritative-voice path.
- Added cached trajectory state so live turns do not rebuild coaching history from scratch.
- Added depth-specific routing: fast models for quick/grounded turns, Claude-first for deeper judgement and trust repair.
- Added semantic quality gates for deep-assessment failures.
- Added trust-repair behavior for "not helpful", "robotic", "too much writing", and formatting/TTS complaints.
- Added provider streaming where available.
- Added a local immediate coach read when the model is still verbalizing.
- Fixed live-mode retrieval so live coaching uses deterministic BM25 only and never kicks semantic rerank/warmup during the spoken-response budget.
- Added observability for turn depth, cache hit, provider choice, latency, semantic gate result, and immediate pushback.

## Current Scorecard

| Area | Score | Read |
|---|---:|---|
| Typed judgement architecture | 96 | Strong. The model now verbalizes an assessment instead of inventing the assessment. |
| Deep-assessment answer quality | 94 | Strong on the target failure case: "How far off am I?" no longer returns only a score and one tip. |
| Trust repair | 91 | Strong. The system acknowledges the miss and repairs the answer in plain language. |
| Low-latency design | 90 | Strong. Live mode now avoids slow semantic rerank and can show immediate coach reads. |
| Provider routing | 89 | Strong. Quick turns use fast routing; deeper/trust turns prefer stronger reasoning. |
| Semantic safety gates | 88 | Strong for the covered cases; needs wider adversarial traffic over time. |
| Memory and trajectory grounding | 86 | Good. Cached snapshots and existing stores are reused, but richer longitudinal case learning still has room to grow. |
| Streaming/live feel | 85 | Good. Provider streaming and provisional reads are in place; real-device spoken UX still needs repeated field testing. |
| Evaluation coverage | 82 | Good. Targeted unit/UI/live evals are strong; broader real-user validation is still missing. |
| Perception depth | 64 | Still the biggest product gap. Noum needs richer prosody, emphasis, breath, energy, tension, and presence signals. |
| Real-world transfer validation | 62 | Still early. The app can prepare and reflect, but it has not yet proven durable outside-practice outcomes. |

## Why The Score Is 88, Not 100

The targeted chat-coach architecture is now largely solved. The remaining points are not mostly "write more prompt" problems. They are product-validation and sensing problems.

Reasons it is high:

- The original shallow-reply failure is structurally addressed.
- Deep assessment now requires verdict, evidence, missing evidence, and a proof test.
- A single clean score cannot imply overall closeness.
- Trust repair is first-class.
- Live mode has a real latency guard.
- The app has passing unit, UI, and live provider evaluation evidence.

Reasons it is not 100:

- Real-device latency and spoken feel still need repeated physical-device checks.
- Professional-coach parity requires longitudinal user outcomes, not only fixture success.
- Perception depth is still underpowered: prosody, emphasis, breathing, vocal energy, tension, and presence are not yet strong enough.
- Transfer outside practice is still lightly validated.
- One tertiary provider fallback, DeepSeek, returned HTTP 402 during live eval attempts.

## Evidence From Latest Verification

Latest live eval report:

`DerivedData/Noum/noum-live-coach-eval.md`

Live evaluation summary:

- 19 fixture turns were run through the configured provider chain.
- All rubric scores were 10/10.
- All quality issues were nil.
- All semantic issues were nil.
- Google Cloud Gemini streaming succeeded on fast turns.
- Claude streaming succeeded on trust repair and deep reasoning turns.
- Typed judgement fallback recovered safely when provider output failed quality expectations.

Focused test coverage passed:

- `CoachKnowledgeRetrievalPolicyTests`
- `CoachProvisionalReadEligibilityTests`
- `KnowledgeVectorMathTests`
- `KnowledgeRerankFallbackTests`
- Earlier target coverage also passed for:
  - live landing newest-rep selection
  - Ask Noum pushback diagnostics
  - user trajectory cache invalidation
  - deep-judgement UI regression
  - live external provider evaluation

Hygiene:

- `git diff --check` passed.

## Resolved Blockers

### 1. Shallow "score plus one tip" replies

Resolved. Deep assessments now have to include a calibrated verdict, mechanics-vs-goal distinction, concrete evidence, missing evidence, and one proof test.

### 2. Model inventing judgement during wording

Resolved. `CoachReasoningPass` creates typed `CoachAssessment` first. The LLM verbalizes that assessment.

### 3. Live mode risking slow retrieval

Resolved. Live turns now bypass semantic rerank and use deterministic BM25 grounding only.

### 4. Trust repair not being first-class

Resolved. Trust-repair turns route differently, prompt differently, and can fall back to typed repair language.

### 5. Streaming being only cosmetic

Resolved for the current target. Provider streaming is used where available, and local immediate reads can appear while the provider completes.

### 6. Lack of observability

Resolved for the target layer. The system records turn depth, cache hit/miss, reasoning latency, provider choice, time to first visible token, full latency, semantic-gate outcome, and immediate pushback.

## Remaining Gaps

### 1. Human-coach validation

Noum still needs real-user, longitudinal validation: do users actually perform better in interviews, presentations, leadership conversations, conflict, pitches, networking, or other real moments?

### 2. Perception depth

The app still needs richer delivery sensing before it can claim near-human coach judgement:

- intonation
- pitch range
- emphasis
- vocal energy
- breathing
- tension
- composure under pressure
- presence signals, if users opt in

### 3. Real-device spoken UX

Simulator and live provider evals are strong, but repeated physical-device checks are still needed for:

- first spoken response latency
- TTS pacing
- interruption behavior
- whether the immediate read feels helpful or abrupt
- whether deep follow-ups feel optional rather than heavy

### 4. Provider operations

DeepSeek returned HTTP 402 during fallback attempts. This does not block the current chain because Google/Claude plus typed fallback passed, but it is worth fixing if DeepSeek is intended to remain an active tertiary fallback.

### 5. Broader adversarial traffic

The current fixtures cover the known failure modes well. The next standard is broader adversarial evaluation across messy, emotional, vague, and contradictory user turns.

## Anything Needed From The User

No app-code blocker is currently waiting on the user.

Optional user-side actions:

- Fix DeepSeek billing/quota if that fallback should be active.
- Run a physical-device live call and judge spoken feel.
- Share the updated build with a small test cohort and collect real user feedback.
- Compare Noum's advice against a human coach on the same practice transcripts.

## Recommended Next Step

Move from implementation proof to validation proof.

Best next work:

1. Run a physical-device live-coach latency and spoken-feel pass.
2. Add a small blinded evaluation: same transcript, Noum response, human-coach response, rated by usefulness and specificity.
3. Expand delivery sensing beyond text metrics into prosody and vocal presence.
4. Add follow-up outcome checks for real-world moments.

## Shareable Conclusion

Noum's Chat with Noum and Live Coach system is now in a strong beta-quality state for expert-style communication coaching. The core architecture is no longer a generic AI chat wrapper; it has typed judgement, memory, evidence thresholds, depth-aware routing, trust repair, streaming behavior, and live-latency safeguards.

The honest current score is **88/100** for the targeted chat-coach research brief.

The remaining path to 100 is not mostly more prompt engineering. It is real-world validation, richer perception, repeated physical-device QA, and proof that Noum's coaching changes outcomes outside the app.
