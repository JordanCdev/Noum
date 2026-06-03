# Noum Coach-Parity Brief For Claude

> **STATUS UPDATE — 2026-06-03 (M25 coach-parity sprint).** The five
> highest-leverage additions below have now been substantially implemented,
> verified (full `NoumTests` suite green), and committed on `Redesign`. See
> `docs/CURRENT_STATE.md` for the detailed per-feature record. Quick map:
> #1 user-facing case file + acknowledgement → **done** (was already largely
> present; acknowledgement now also lives on the Profile card, F4a); #2 weekly
> coach check-in → **done** (F1, new `CoachCheckInStore`); #3 Big Moment
> simulation → **done by extension** (the rehearsal flow already existed as
> `PrepSessionPlanner`/`PrepSessionView`; F2 added the missing readiness read +
> coach awareness — this brief's "not present" framing for it was stale); #4
> persistent delivery profile → **done** (F3, surfaces the existing fused
> `CoachDeliveryRead` + trends); #5 transfer outcome loop → **done/enriched**
> (F4b adds a structured "did your prep transfer?" signal). Plus **F5**, a new
> coach-parity readiness instrument operationalizing stage-7 honesty (validation
> never self-certified).
>
> **Corrected re-assessment (honest, two-axis):**
> - Coaching **capability** (does the app implement the coach loop as software):
>   **~8/10** — the gap to 9 is *perception depth* (delivery sensing is still
>   ~4 baseline-relative audio channels; no prosody-contour/breathing/emphasis,
>   no opt-in visual presence — VISION roadmap #2/#4), not the relational stages.
> - Validated **human-coach replacement**: **~2.5/10** and structurally cannot
>   move without real users + longitudinal outcomes + blinded professional-coach
>   calibration (VISION stage 7 / roadmap #5). This is a real-world gap, not a
>   code gap, and must never be self-certified.
>
> **Doc correction:** `VideoAnalysisService` (listed under "strong foundations"
> below) exists but is **thin/orphaned** — it sends extracted frames to a vision
> model and renders the result on the Summary screen, but does NOT feed coach
> memory or the case file. Treat it as a partial foundation, not a coaching
> capability.

## Mission

Move Noum closer to the product ambition in `docs/VISION.md`: an accessible
replacement for a strong human communication / public-speaking coach.

Do not treat this as "add more AI." The goal is coach-like continuity:

- diagnose the individual
- maintain a clear case formulation
- prescribe deliberate practice
- observe response across reps
- adapt the plan with an explained rationale
- prepare for real-world moments
- collect outcome evidence after those moments

Noum must never imply professional-coach parity from one LLM reply, one rep,
or a feature checklist. Parity must be earned through durable outcomes.

## Current Assessment

Current score:

- Personalized communication-training app: about 6/10
- Human communication coach replacement: about 4.5-5/10

Why:

Noum now has a real architecture for coaching continuity. The major gap is no
longer "does the app know anything?" It does. The gap is whether it behaves
like a coach who actively manages the user's case over time.

Strong foundations already present:

- `CoachMemoryStore`
- `CoachCaseFile`
- `CoachContextBuilder`
- `RecommendationLearningStore`
- `SessionReflectionStore`
- `BigMomentStore`
- `ForwardPlanStore` / `ForwardPlanService`
- `NextActionEngine`
- `VocalEnergyMetrics`
- `ComposureRead`
- `ConfidenceMarkerRead`
- `StructuralRead`
- `CoachDeliveryRead`
- `VideoAnalysisService`

Preserve these. Do not create a disconnected coaching system.

## Main Delta

Noum knows more about what happened than why it happened.

It has a durable case spine, but the user does not yet experience the app like
a coach who says:

"Here is my read of you. Here is what we are testing. Here is your drill. Here
is the success measure. After three attempts, here is what changed. Because
your real pitch is in six days, here is the rehearsal we are doing next."

That is the missing feeling.

## Product Principle

Build a coaching operating system, not isolated features.

Every addition should strengthen one of:

- diagnosis
- formulation
- prescription
- observation
- adaptation
- transfer
- validation

Avoid:

- shallow gamification
- generic AI chat wrappers
- fake certainty
- duplicate memory stores
- dead UI toggles
- new screens that do not feed the coaching loop

## Highest-Leverage Additions

### 1. User-Facing Coaching Case File

Build a visible "Your coaching read" surface backed by `CoachCaseFile`.

It should show:

- current hypothesis
- evidence depth
- active intervention
- observable target
- success measure
- review due state
- upcoming Big Moment, when present
- latest subjective pattern
- transfer read
- next coach move

It must let the user respond:

- "This fits"
- "Not quite"
- "I am not sure"

Reuse `CoachMemoryStore.noteHypothesisAcknowledgement(...)` where possible.
If new response types are needed, extend existing coach-memory structures
rather than creating parallel state.

Good locations:

- Profile coaching area
- Ask Noum case-review starter
- Summary after a review-due intervention

Definition of done:

- Case surface is generated from `CoachCaseFile`, not duplicate logic.
- User acknowledgement updates durable memory.
- Ask Noum context reflects the acknowledgement.
- Weak evidence remains tentative.
- Tests cover display eligibility, acknowledgement persistence, and context
  output.

### 2. Weekly Coach Check-In

A human coach asks questions. Noum currently generates insights, but it does
not sufficiently run a bidirectional check-in.

Add a short weekly check-in that asks:

- What felt hardest this week?
- Where did this show up outside the app?
- What real moment is coming next?
- Did the current drill help, stall, or miss?

Reuse `SessionReflectionStore` if the data is a rep reflection. If the check-in
is broader than one session, create a small bounded `CoachCheckInStore`, but
only after confirming no existing owner fits.

The check-in should update the durable case. It should not become a diary
feature disconnected from coaching.

Definition of done:

- Check-ins persist per account.
- Recent check-ins feed `CoachContextBuilder.userContext`.
- `CoachCaseFile` can incorporate a concise latest check-in summary.
- Empty state is honest and low-friction.
- Tests cover persistence, cap/ordering, and context lines.

### 3. Big Moment Simulation / Capstone Mode

Noum has `BigMomentStore` and practice modes, but it still lacks a human-coach
style rehearsal tied to the actual event.

Build a Big Moment rehearsal flow that:

- reads the active `BigMoment`
- chooses a simulation shape by category
- uses existing Timed / Sudden Death / IM practice where possible
- asks realistic follow-ups for interviews, pitches, reviews, conflict, etc.
- produces a readiness read
- updates the case file with what needs rehearsal next

Do not create a generic "AI roleplay" island. It must integrate with:

- `BigMomentStore`
- `ForwardPlanStore`
- `CoachMemoryStore`
- `RecommendationLearningStore`
- existing practice routes

Definition of done:

- A Big Moment within the horizon changes the recommended rehearsal.
- The rehearsal result feeds coach memory and Ask Noum context.
- Outcome check-in after the real event updates transfer evidence.
- Tests cover category routing, no-moment fallback, and context integration.

### 4. Persistent Delivery Profile

Delivery sensing is much better than before, but the user still needs a
durable coach read of how they come across.

Use existing signals:

- `VocalEnergyMetrics`
- `PitchMetrics`
- `PauseMetrics`
- `ComposureRead`
- `ConfidenceMarkerRead`
- `StructuralRead`
- `CoachDeliveryRead`
- optional `VideoAnalysisResult`

Add a bounded delivery profile that answers:

- What delivery pattern is recurring?
- What has improved?
- What breaks under pressure?
- What is the next delivery target?

Be careful:

- Never label the person.
- Say "these reps read as tentative," not "you are timid."
- Avoid claims like evasive / detached unless the evidence can support them.

Definition of done:

- Delivery profile is derived from existing session history.
- It is persisted or rebuildable through an existing owner.
- Ask Noum sees it as a hypothesis, not a diagnosis.
- Video analysis, when present, contributes without becoming mandatory.
- Tests cover thin-signal omission and repeated-signal strengthening.

### 5. Transfer Outcome Loop

A coach is valuable because real moments go better. Noum must measure that.

Extend the existing Big Moment outcome flow so the user can report:

- what happened
- how the audience / counterpart responded
- what felt difficult
- what they avoided
- what landed
- whether the prescribed drill transferred

Then update:

- `BigMomentStore`
- `CoachMemoryStore`
- `CoachCaseFile`
- Ask Noum context
- future plan / next action

Definition of done:

- Outcome reports stay explicitly user-reported.
- The app never claims the drill caused the outcome.
- Positive, mixed, and poor outcomes all produce useful next moves.
- Tests cover transfer context, case update, and no-causation wording.

## Suggested First Implementation

Start with the user-facing Coaching Case File.

Reason:

The architecture already exists. Making it visible creates the feeling that
Noum is managing the user's development like a coach. It also creates the
confirmation loop needed before deeper personal hypotheses become durable.

Recommended first task:

1. Search existing case-review UI (`CaseReviewCard`, `AskNoumView`,
   `SummaryView`, Profile coaching sections).
2. Add a compact `CoachCaseFileCard` or extend an existing case-review card.
3. Read from `CoachMemoryStore.currentMemory?.caseFile`.
4. Show hypothesis, active intervention, target, success measure, next move.
5. Add three acknowledgement controls.
6. Wire acknowledgement to `CoachMemoryStore`.
7. Ensure `CoachContextBuilder.userContext` reflects the response.
8. Add tests.

Do not build a new store unless absolutely necessary.

## Required Guardrails

- Weak evidence -> tentative language.
- Repeated evidence -> stronger intervention.
- User self-report -> explore, do not diagnose.
- Transfer evidence -> user-reported, not causation.
- Stated goal and measured read must be reconciled, not silently overridden.
- Video/presence analysis must be opt-in and must not block the core coach.
- No fake progress states.
- No gamification that weakens trust.

## Useful Files

- `docs/VISION.md`
- `docs/CURRENT_STATE.md`
- `Noum/PrimaryFocusMemory.swift`
- `Noum/CoachContextBuilder.swift`
- `Noum/AskNoumView.swift`
- `Noum/SummaryView.swift`
- `Noum/CaseReviewCard.swift`
- `Noum/BigMomentStore.swift`
- `Noum/ForwardPlanService.swift`
- `Noum/NextActionEngine.swift`
- `Noum/DerivedReadsTrend.swift`
- `Noum/ComposureRead.swift`
- `Noum/ConfidenceMarkerRead.swift`
- `Noum/StructuralRead.swift`
- `Noum/VocalEnergyMetrics.swift`
- `Noum/PracticeSupport.swift`
- `NoumTests/NoumTests.swift`

## Claude Prompt

Use this if handing the work to Claude:

> Read `docs/VISION.md`, `docs/CURRENT_STATE.md`, and
> `docs/COACH_PARITY_CLAUDE_BRIEF.md`. Implement the next highest-leverage step
> toward Noum replacing a human communication/public-speaking coach. Start with
> a user-facing Coaching Case File surface backed by `CoachCaseFile` and
> `CoachMemoryStore`. Reuse existing state owners and UI patterns. Do not create
> duplicate memory, duplicate routing, or disconnected AI surfaces. Preserve the
> evidence rules: weak evidence is tentative, subjective patterns are
> hypotheses, and transfer reports are not causal proof. Add focused tests and
> update docs if the product state changes.

