# Communication curriculum research

_Reviewed 2026-07-11 for the communication curriculum expansion._

## Decision

Noum's existing offering was strong on solo delivery mechanics and structured
speaking, but too narrow to represent communication as an exchange. The first
curriculum expansion therefore prioritizes four missing capabilities:

1. listening and checking understanding;
2. question quality and discovery;
3. explanation for a specific audience;
4. feedback, boundaries, and repair.

The expansion stays inside the existing Lessons and Roleplay systems. It does
not add a second curriculum store, a generic AI roleplay product, or a new
progress currency.

## What the source material supports

### Communication is more than polished output

- Toastmasters' published core competencies extend beyond speech structure to
  active listening, audience connection, evaluation and feedback, persuasive
  communication, difficult audiences, Q&A, online meetings, and panel
  moderation. Source: [Pathways Paths and Core Competencies](https://devccdn.toastmasters.org/medias/files/pathways/8077-pathways-path-and-core-competencies/8077-pathways-paths-and-core-competencies_2022.pdf).
- A quasi-experimental active-listening curriculum taught attending behavior,
  open and closed questions, paraphrasing, summarizing, reflection of meaning,
  empathy, confrontation, and feedback through experiential practice. Source:
  [Improving officer-soldier communication through active listening skills training](https://pmc.ncbi.nlm.nih.gov/articles/PMC10013498/).
- AHRQ's TeamSTEPPS materials make closed-loop communication, check-back,
  teach-back, handoffs, formative feedback, assertion, and conflict resolution
  explicit trainable tools. Sources: [TeamSTEPPS modules](https://www.ahrq.gov/teamstepps-program/resources/modules/index.html),
  [Check-Back](https://www.ahrq.gov/teamstepps-program/curriculum/communication/tools/checkback.html),
  [Teach-Back](https://www.ahrq.gov/teamstepps-program/curriculum/communication/tools/teachback.html), and
  [DESC](https://www.ahrq.gov/teamstepps-program/curriculum/mutual/tools/desc.html).

These sources are not copied as branded frameworks inside Noum. Their shared
skill primitives inform general-purpose exercises such as reflecting meaning,
closing the loop, describing behavior and impact, and proposing a next step.

### Learning requires production, feedback, and another attempt

- A randomized trial found benefits from a multi-modal sequence that combined
  teaching, deliberate practice, online material, self-reflection, feedback,
  and a booster session. Source: [Improving Residents' Code Status Discussion Skills](https://pmc.ncbi.nlm.nih.gov/articles/PMC3387757/).
- An RCT with video-recorded communication practice used self-reflection and
  corrective feedback rather than lesson exposure alone. Source:
  [Deliberate Practice and Communication Skills](https://eric.ed.gov/?id=EJ1372867).
- Long-term follow-up research found that trained communication behaviors can
  transfer into real practice, while also showing that transfer is a distinct
  outcome that must be designed for. Sources:
  [Enduring impact of communication skills training](https://pmc.ncbi.nlm.nih.gov/articles/PMC2394345/) and
  [Transfer of Communication Skills to the Workplace](https://ascopubs.org/doi/10.1200/JCO.2014.57.3287).

This supports Noum's Concept → Spot it → Apply structure, but also exposed a
gap: a generic 12-word transcript was being treated as successful application.
The expansion replaces that shortcut with visible criteria, immediate feedback,
and an in-place retry.

### Retention and transfer should not be inferred from massed repetition

- A tutorial review identifies spaced practice, interleaving, retrieval
  practice, elaboration, concrete examples, and dual coding as well-supported
  learning strategies. Source: [Teaching the science of learning](https://pubmed.ncbi.nlm.nih.gov/29399621/).
- A systematic review of interleaving examines both retention and transfer to
  new items. Source: [A systematic review of interleaving as a concept learning strategy](https://bera-journals.onlinelibrary.wiley.com/doi/full/10.1002/rev3.3266).
- A meta-analysis covering 122 experiments found that retrieval-practice
  transfer depends on factors including elaboration and response congruency;
  retrieval is useful, not automatically generalizable. Source:
  [Transfer of test-enhanced learning](https://pubmed.ncbi.nlm.nih.gov/29733621/).

Noum consequently uses a modest expanding review schedule and varies the Apply
prompt on later rounds. The intervals are a transparent product heuristic, not
an assertion of an individually optimal memory model.

### Clarity begins with audience and main message

- CDC guidance defines plain language around what a specific audience can
  understand the first time, and recommends putting the main message first,
  using familiar words, and organizing by audience need. Sources:
  [CDC Plain Language](https://www.cdc.gov/health-literacy/php/develop-materials/plain-language.html) and
  [CDC Clear Communication Index](https://www.cdc.gov/ccindex/tool/page-2.html).

This supports a dedicated explanation lesson rather than treating concise
speech, vocabulary, or eloquence as sufficient evidence of clarity.

## Implemented learning loop

Each lesson now contains:

1. one concept and example;
2. one contrastive recognition check;
3. one spoken Apply prompt;
4. two or three observable criteria with specific feedback;
5. an in-place retry when the move is not yet visible;
6. a different prompt on later reviews;
7. one concrete real-world transfer task;
8. a spaced revisit before another pass counts toward retention.

The roleplay catalog adds feedback, boundary, repair, and discovery
conversations. Their shared deterministic engine now recognizes listening,
ownership, inquiry, and constructive next-step signals in addition to the
existing directness, evidence, and composure axes.

## Honesty boundaries

- Transcript checks can observe words and response shape; they cannot prove
  empathy, intent, relationship repair, or listener understanding.
- A successful lesson round is evidence that the move appeared once, not that
  the user has mastered a person or situation.
- Spaced rounds improve the learning design but do not establish real-world
  transfer. The transfer prompt is a bridge; outcome reporting remains owned by
  Noum's existing real-world moment and reflection systems.
- Healthcare and military sources are used for broadly applicable
  communication primitives, not for clinical, safety-critical, or command
  certification claims.

## Still underweight after this pass

- nonverbal presence and audience-response sensing;
- group facilitation and meeting moderation;
- negotiation across competing interests;
- intercultural adaptation beyond plain-language audience fit;
- external validation against trained human coaches and longitudinal outcomes.

Those require deeper sensing, richer simulations, or real-world validation.
They should not be represented as solved by adding more authored prompts.
