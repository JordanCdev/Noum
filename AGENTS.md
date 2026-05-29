# Noum

Noum is a premium communication-training system focused on:

- speaking under pressure
- filler-word reduction
- conversational intelligence
- personalized coaching
- believable progress over time

Noum should feel like:

- a communication operating system
- a premium iOS product
- calm, intelligent, and restrained
- motivating through visible improvement
- cohesive across all modes

Not:

- a prototype
- a dashboard
- shallow gamification
- disconnected feature experiments
- a generic AI wrapper
- noisy productivity software

---

# Required reading

Before any non-trivial work:

Read:
- `docs/VISION.md`
- `docs/CURRENT_STATE.md`

Then identify:

1. Which milestone this work serves
2. Which product pillar this work supports
3. Which existing patterns must be preserved
4. Which existing state owners already exist

Do not begin implementation before understanding the current architecture.

---

# Required response structure

Before implementation, provide:

## Scope
What is being changed

## Product goal
Why this change exists

## Existing patterns being reused
Which architecture/state/UI patterns already exist

## Root causes
Underlying causes, not surface symptoms

## Risks
Potential regressions or architectural risks

## Plan
Files and systems being modified

---

# Architecture rules

Before creating new systems:

1. Search for existing implementations first
2. Reuse existing state ownership where possible
3. Extend existing managers/stores before creating new ones
4. Avoid duplicate screens, duplicate stores, duplicate routing, or parallel logic

Do not introduce:

- fragmented state ownership
- overlapping systems
- disconnected feature implementations
- temporary architecture that becomes permanent

If architecture is weak:
- refactor toward coherence
- do not layer hacks on top

---

# Product-system thinking

Do not treat features as isolated screens.

Every feature should reinforce:

- communication improvement
- pressure awareness
- coaching trust
- progress visibility
- replay motivation
- product coherence

Optimize for:
- clarity
- trust
- focus
- long-term maintainability
- believable coaching
- low-friction UX

Not:
- feature quantity
- novelty for its own sake
- unnecessary complexity

---

# UI / UX rules

Maintain:

- consistent spacing rhythm
- consistent card language
- consistent interaction behavior
- clear visual hierarchy
- premium readability
- restrained motion

Animations must:
- support comprehension
- communicate focus/state changes
- respect reduced-motion settings

Avoid:

- visual noise
- excessive modals
- setup friction
- cluttered dashboards
- aggressive gamification

Interactions should feel:
- intuitive
- calm
- responsive
- premium

---

# Coaching logic invariants

Always preserve:

- weak evidence → softer feedback
- repeated patterns → stronger intervention
- semantic speech ≠ filler speech
- pressure modes must feel fair
- coaching must avoid overclaiming

Never punish semantically valid speech patterns incorrectly.

Avoid fake certainty from small sample sizes.

---

# Engineering bans

Do not ship:

- placeholder logic presented as complete
- dead toggles without disabled-state explanation
- fake progress systems
- fake loading states
- duplicated state ownership
- disconnected feature branches
- hardcoded design values when tokens exist

No silent TODO architecture.

---

# Definition of done

A feature is NOT complete because UI exists.

Completion requires:

1. End-to-end functionality works
2. State persists correctly
3. Edge cases handled
4. Navigation flows verified
5. Empty/error states verified
6. Accessibility labels verified
7. Reduced-motion behavior respected
8. Existing flows regression-checked
9. No duplicated logic introduced
10. Visual consistency maintained
11. Real behavior verified, not assumed

If logic is critical:
- add tests if missing

Do not claim completion without verification evidence.

---

# Verification output requirements

Before final response, provide:

## Implemented
Completed functionality

## Partially implemented
Anything incomplete

## Blocked
Real blockers only

## Assumptions
Assumptions made

## Verification
What was tested and how

## Risks
Remaining concerns

---

# Pushback is expected

If a request:

- conflicts with architecture
- creates UX inconsistency
- introduces fragmented systems
- weakens product coherence
- adds shallow gamification
- harms trust

then push back.

Propose a stronger alternative briefly.

Optimize for:

- coherence
- maintainability
- believable UX
- shipping quality
- real communication improvement

not short-term feature accumulation.
