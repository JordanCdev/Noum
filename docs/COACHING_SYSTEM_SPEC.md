# Noum Coaching System Specification

**Status:** Product contract v1 — implementation may not contradict this document silently  
**North star:** `docs/VISION.md`  
**Evidence baseline:** `ux-overhaul` at `f441dd0191eb08f79ea159583878c1558f900df7`, using the v1 + v2 research bundles, current Coach Arena artifacts, Figma explorations, and approved founder decisions  
**Supersedes:** earlier generated copies of `COACHING_SYSTEM_SPEC.md`  
**Last consolidated:** 2026-07-23

## 1. Product contract

Noum is a personalised communications coach, not a collection of speech tools.

The coaching loop is:

> **UNDERSTAND → DIAGNOSE → PRESCRIBE → PRACTISE → REVIEW → RETRY → ADAPT → TRANSFER**

The plan is the product. Exercises, metrics, chat, lessons, Path, achievements, and live coaching are supporting mechanisms.

### Day-7 promise

After a credible first week, the user should believe:

> **Noum understands how I communicate, what I am trying to achieve, and has built a credible plan specifically for me.**

Noum must not promise mastery in seven days. It must prove that its understanding and plan are becoming more accurate.

### Launch validation audience

Noum's mission is broad. The initial validation audience is:

> **Adults with a personally meaningful communication goal who will complete several short practices across one week.**

A future go-to-market wedge may be narrower, but the coaching system must adapt to the user's outcome rather than force a universal curriculum.

## 2. First-week contract

### Dose hypothesis — PROTOTYPE

Test **four sessions of roughly 5–8 minutes within seven days**. Daily use is not required. Missed days must not trigger guilt or invalidate progress.

By the first-plan review, Noum should:

1. understand the user's desired outcome and felt difficulty;
2. establish a qualified baseline from the user's own speech;
3. propose one provisional high-leverage working focus;
4. run repeated, targeted practice against that focus;
5. compare the same target across attempts;
6. show movement, lack of movement, or contradictory evidence;
7. explain what it learned, what remains uncertain, and what changes next.

### What counts as proof

Progress combines three evidence layers:

- **Objective signal:** filler burden, pause placement, pace stability, vocal variety, or another qualified measure;
- **Trained behaviour:** the target behaviour changed, such as stating the answer earlier or holding the close;
- **User experience:** the user reports that the attempt felt clearer, calmer, more natural, or more effective.

The evidence must match the user's goal. Lower fillers, slower pace, or wider vocabulary are not automatically better.

## 3. Coaching decision hierarchy

Noum must not choose the plan from one score, one transcript, or one model judgement.

1. **Direction:** the user's chosen communication outcome.
2. **Initial focus:** the user's felt difficulty plus evidence from the first qualified sample.
3. **Next practice:** response to the current intervention across repeated attempts.
4. **Plan revision:** repeated evidence, user reflection, contradictory evidence, and intervention response.
5. **Ultimate validation:** outcomes in real situations and the user's account of audience or counterpart response.

Real-world outcomes carry the highest authority when available, but they are too infrequent and noisy to select every daily exercise.

## 4. Minimum onboarding

Ask only what is needed to make the first sample meaningful.

### Required

1. **Desired outcome:** “What would you like to communicate better?”
2. **Felt difficulty:** “What currently feels hardest?”

### Optional and contextual

- an upcoming real situation, only when one exists;
- extra context, only when it changes the sample or plan;
- communication style or voice should normally be proposed after hearing evidence, then confirmed or corrected.

Do not require a long intake questionnaire before the user speaks.

## 5. Baseline and first working focus

### Baseline model

Use a hybrid baseline:

1. Start with a personalised first rep tied to the user's outcome and felt difficulty.
2. Show useful coaching immediately.
3. Introduce a standardised benchmark later for comparable formal evaluation.

### First working focus

After rep one, Noum presents a **provisional working focus**, not a finished diagnosis.

The presentation must include:

- one verified piece of evidence;
- one bounded interpretation;
- one next test;
- a visible but secondary uncertainty boundary;
- an effortless correction path.

Recommended pattern:

> **Your first working focus**  
> Based on this rep, Noum thinks you add context before stating the main point. We’ll test whether leading with the answer makes you clearer.  
> *Early read — this will update as Noum learns.*

- Primary: **Start next step**
- Secondary: **Adjust focus**

### Correction rules

Do not use a percentage or confidence slider. It does not tell Noum what it misunderstood.

`Adjust focus` should offer:

- **Mostly right**
- **Not the main issue**
- **Something else feels harder**

Ask for text or voice detail only when necessary.

- User correction outranks model inference.
- No response is never treated as strong agreement.
- Ask explicitly only for weak, contradictory, sensitive, identity-adjacent, or goal-change evidence.
- A rejected focus must stop affecting recommendations unless later evidence transparently re-establishes it.

## 6. Intervention cycle

Noum should keep one high-leverage focus stable long enough to learn whether the intervention works.

> **Keep the focus → vary scenario or difficulty → compare the same target → adapt from evidence**

Change focus when:

- the target holds across relevant situations;
- correct practice stagnates;
- user feedback or evidence contradicts the focus;
- an urgent real-world situation changes priority;
- another skill is blocking progress.

A low-capacity day changes session shape, not automatically the underlying focus.

## 7. Daily session recommendation

Noum behaves like a confident coach, not a configuration wizard.

It should recommend one session using:

1. the active plan and intervention;
2. response to recent practice;
3. explicit statements about time, energy, confidence, or pressure;
4. recent completion, abandonment, and retry behaviour;
5. an upcoming real moment when known.

The recommendation card contains:

- the chosen practice;
- why it fits the plan;
- one target;
- one success criterion;
- expected duration;
- one primary Start action.

Provide quiet adjustments:

- **Make it shorter**
- **Make it more challenging**

Do not ask “How motivated are you?” or require an “intensity” choice every session.

### Lower-capacity session

When the user explicitly signals limited energy or time:

- preserve the active target;
- reduce duration, attempts, pressure, or feedback depth;
- use warm, professional language;
- avoid a prominent overall score;
- record the result as practice evidence, not a standard benchmark.

Example:

> “We’ll keep this useful and light: one short rep, one thing to notice, then you’re done.”

## 8. Post-rep coaching and retry

The first visible sequence is:

### 1. What I heard

One compact component containing:

- an exact, quote-verified excerpt;
- one earned strength;
- one evidence-bounded diagnosis.

### 2. One step better

Show a minimal rewrite of the user's own words:

- change one high-leverage lever;
- preserve meaning and natural voice;
- highlight what changed;
- explain why in one sentence;
- avoid generic corporate or “executive” replacement language.

### 3. Try it now

Offer a one-tap targeted retry:

- same prompt or scenario where possible;
- one observable target;
- one success criterion;
- no unrelated scoring unless a severe issue invalidates the attempt.

### After retry

1. Compare the trained target across attempts.
2. Ask one brief reflection about how it felt.
3. Decide: repeat, vary, add pressure, or move on.
4. Update the plan and explain the decision briefly.

### Aspirational end state

An end-state exemplar may appear as a secondary reference. It must be labelled aspirational, preserve the user's meaning, and never become the immediate target when it changes several skills at once.

### Current-state note

The real app already contains verified evidence, a one-step rewrite, an aspirational example, and targeted retry when a durable rewrite snapshot exists. The product task is to make this loop **reliably earned, consistently surfaced, and visually coherent**, not rebuild it from zero.

## 9. Coaching versus evaluation

Daily coaching and formal evaluation are different modes.

### Daily coaching

Default to:

- verified evidence;
- one useful interpretation;
- one next move.

Do not make one overall score the hero of ordinary practice.

### Formal evaluation

Offer a detailed rubric during:

- baseline assessment;
- weekly or monthly review;
- user-requested benchmark;
- controlled comparison sessions.

Evaluation should be:

- self-referenced, not peer-ranked;
- multi-dimensional;
- evidence-bounded;
- explicit when evidence is insufficient;
- optional in everyday views.

Comparable trends require comparable evidence conditions. A deliberately light session should not lower a formal benchmark trend.

## 10. Memory and case formulation

Raw chat history is not the coaching record.

Persist bounded, inspectable state when useful:

- desired outcome and goal history;
- user-confirmed preferences;
- verified strengths and repeated patterns;
- active hypothesis and confidence;
- active intervention, target, success measure, and review point;
- response to recommendations;
- user-reported confidence, difficulty, nerves, avoidance, or authenticity concerns;
- upcoming real moments and reported outcomes;
- contradictory evidence and user corrections.

Rules:

- user evidence outranks prior assistant prose;
- one observation never becomes a durable trait;
- sensitive patterns remain hypotheses;
- every item has source, date, confidence, and provenance;
- users can inspect, correct, and delete memory;
- goal changes preserve goal-independent evidence and invalidate only goal-dependent plans;
- rejected hypotheses stop influencing retrieval and recommendations.

## 11. EQ, goal changes, and coaching judgement

Before responding, Noum should determine:

1. What is the user literally asking?
2. What are they emotionally signalling?
3. What evidence is available and missing?
4. Do they need an answer, acknowledgement, explanation, question, or exercise?
5. What is the smallest useful next move?
6. What should change in the plan or memory?

Changing a voice or style goal means changing **training emphasis**, not identity.

Avoid:

- identity-level claims;
- “pretending,” fake-persona, or authenticity-shaming language;
- report voice and internal labels;
- automatically prescribing another exercise after every turn;
- repetitive “sentence one / the ask / then stop” coaching;
- false certainty from one score or one rep.

## 12. Consented delivery intelligence

A limited version of delivery adaptation is permitted as transparent secondary evidence.

Permitted within-user signals during intentional recordings:

- pace and pace change;
- pause frequency and distribution;
- restarts and hesitation events;
- pitch range and vocal variety;
- vocal energy as an acoustic measurement;
- stability across repeated attempts.

Priority:

1. explicit user statement;
2. intervention response;
3. repeated behavioural evidence;
4. within-user acoustic change;
5. population-level inference only as weak context.

Noum must not infer or persist mood, motivation, personality, authenticity, mental health, or intent from voice. Say:

> “Your pauses were longer than your usual range.”

Never:

> “You sounded anxious.”

Requirements:

- explicit opt-in after initial value is demonstrated;
- intentional recordings only;
- Settings control and deletion path;
- derived features with source and provenance, not emotional labels;
- explanation when delivery evidence changed the recommendation;
- no direct effect on formal scoring or long-term plan;
- separate legal and policy review before workplace or education deployment.

## 13. Engagement and reinforcement

Engagement should come from meaningful progress:

- **Autonomy:** Noum leads; the user can correct or adjust.
- **Competence:** show specific, earned improvement.
- **Relatedness:** remember context and respond humanly.
- **Meaning:** connect practice to the user's outcome.
- **Momentum:** make the next step small and obvious.

Use a three-level reinforcement hierarchy:

1. **Evidence win:** name what concretely improved.
2. **Journey movement:** show how the evidence advances the plan.
3. **Milestone moment:** reserve stronger recognition for meaningful personal bests, mastered targets, completed intervention cycles, or real-world transfer.

Use a brief arrival moment once, then collapse it into a compact progress signal. Avoid hollow praise, constant confetti, arbitrary XP as proof of skill, guilt-based streaks, and default peer comparison.

## 14. Reliability and observability

Every coaching request must reach one terminal state:

- accepted response;
- repaired response;
- truthful fallback;
- actionable retryable error;
- explicit unavailable-provider state;
- user cancellation.

Never indefinite loading, silent loss, or an irrelevant deterministic fallback.

A root trace should connect:

> classification → goal → memory → evidence → prompt → provider attempts → streaming → quality gates → repair/fallback → persistence → UI result

Record privacy-safe metadata including trace ID, provider/model, prompt-module hashes, selected evidence/memory provenance, token/context estimates, cache usage, time to first token, full latency, status, retries, gate failures, substitution reason, and final UI state.

The current app has an immersive live coach call plus typed interaction. Treat Noum as one cross-cutting coach relationship; voice and typed modes must share the same plan, memory, evidence, and trace model.

## 15. Validation

A change is not validated by model confidence or one automated score.

Require:

- source-bound trace provenance;
- regression fixtures for goal changes, emotional pushback, long prompts, transcript rewrites, memory correction, consent, and delivery-signal boundaries;
- tests proving user input overrides passive adaptation;
- tests proving acoustic signals cannot create sensitive labels or alter formal scores;
- full transcript inspection;
- same-target retry comparison;
- real-user longitudinal outcomes;
- eventual blinded professional-coach calibration.

Product success metrics should include:

- activation to first meaningful coaching read;
- completion of first targeted retry;
- return for a second and fourth session;
- user comprehension of the working focus;
- correction rate and correction recovery;
- repeated evidence on the active target;
- real-world outcome capture;
- trust and perceived usefulness.

## 16. Non-goals

Noum is not:

- a generic AI chat wrapper;
- a dashboard of vanity metrics;
- a rigid seven-day course;
- a peer-ranking product by default;
- an emotion-recognition system;
- a system that labels personality from telemetry;
- a game that rewards app activity as if it proved communication growth.

See `PRODUCT_DECISION_LOG.md` for decision status and `PRODUCT_JOURNEY_DESIGN.md` for the user-facing implementation contract.
