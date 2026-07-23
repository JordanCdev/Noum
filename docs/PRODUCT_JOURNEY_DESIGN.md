# Noum Product Journey and Design Specification

**Status:** Product experience contract v1  
**North star:** `docs/VISION.md`  
**Evidence baseline:** `ux-overhaul` at `f441dd0191eb08f79ea159583878c1558f900df7`, using both source-bound research bundles and inspected Figma concepts  
**Supersedes:** earlier generated copies of `PRODUCT_JOURNEY_DESIGN.md`  
**Last consolidated:** 2026-07-23

## 1. Product experience

Noum should feel like one professional coach with a personalised plan, not a set of modes, cards, metrics, lessons, and chat surfaces.

The user-facing loop is:

> **UNDERSTAND → DIAGNOSE → SHOW → PRACTISE → COMPARE → ADAPT → TRANSFER**

The experience should make the user feel:

- Noum understands my goal;
- Noum has selected the right next step;
- the feedback comes from my own communication;
- the improvement is achievable now;
- my plan changes when the evidence changes.

## 2. Current-state evidence corrections

The current app is not starting from zero.

Verified at the audited commit:

- an immersive live coach call exists as the default voice-coach surface;
- typed Ask Noum exists as a secondary interaction mode;
- Review can show a verified quote, bounded observation, one-step rewrite, aspirational example, and targeted retry;
- the retry can preserve the source prompt;
- onboarding, paywall, first-week read, progress surfaces, Path, modes, lessons, projects, social surfaces, and settings exist;
- contextual Ask Noum can produce an evidence-aware reply.

Therefore the redesign should **sharpen, simplify, connect, and reliably surface** existing capabilities rather than recreate them as disconnected new features.

Current weaknesses remain:

- too many equal entry points;
- card-heavy, pale, static visual language;
- too much explanatory copy;
- weak distinction between coaching, evaluation, and progression;
- inconsistent reward/progression patterns;
- important teaching loops appear conditionally or too deep;
- live coach, typed coach, Today, Review, Path, and Progress do not yet feel like one relationship;
- prompt-layer evaluations still expose low-EQ and placeholder-like failures despite stronger app-path results.

## 3. Target information architecture — PROTOTYPE

Test four peer areas:

1. **Today** — current plan, earned progress, one next step, upcoming moment.
2. **Practice** — prescribed practice first; manual exploration secondary.
3. **Progress** — reviews, coaching trajectory, Path, milestones, achievements, and formal evaluation.
4. **You** — goal, coach memory, preferences, profile, privacy, subscription, and settings.

Noum is a cross-cutting coach relationship, not a fifth content silo:

- **Talk to Noum** launches the immersive voice interaction when available;
- **Type** provides the same contextual coach in text;
- entry points appear on Today, Review, Progress, and real-moment preparation;
- both modes inherit the same active plan, transcript context, memory, and trace ID.

Validate the four-area model against a three-area alternative before locking final navigation.

## 4. Day 0–7 journey

### Day 0 / first session

1. Ask desired outcome.
2. Ask what currently feels hardest.
3. Generate a personalised first prompt.
4. Brief the user with one target and success cue.
5. Record the rep.
6. Show `What I heard → One step better → Try it now`.
7. Present a provisional working focus with `Adjust focus`.
8. Run a targeted retry.
9. Compare the target and explain what Noum will learn next.

### Sessions 2–3

- keep the focus stable;
- vary scenario or difficulty;
- compare the same target;
- collect one brief reflection only when useful;
- show earned progress without overclaiming mastery.

### Session 4 / first-plan review

Show:

- what Noum learned;
- what changed;
- evidence from the user's speech;
- what remains uncertain;
- the next adapted plan;
- an optional formal evaluation view.

### Ongoing

- Today presents one prescribed next step;
- real-world moments can temporarily change urgency;
- outcomes outside the app update the plan;
- lapsed users return to a calm summary and a smaller restart step, not guilt copy.

## 5. Today

Today must answer within seconds:

- What am I working toward?
- What has Noum learned?
- What should I do now?

### Stable hierarchy

1. **Earned progress signal** — one short, evidence-backed line when new progress exists.
2. **Journey movement** — subtle plan or landmark change when warranted.
3. **Next coaching step** — one dominant prescription.
4. **Upcoming moment or latest coach context** — only when relevant.
5. Everything else behind secondary navigation or disclosure.

### Next coaching step

The card itself is the briefing. It contains:

- chosen practice;
- why it was selected;
- one target;
- one success cue;
- estimated duration;
- primary **Start** action;
- quiet **Make it shorter** / **Make it more challenging** adjustment.

After `Start`, launch practice directly. Do not add another mandatory explanation screen.

### Density limits

- one hero;
- one primary action;
- maximum two secondary blocks before disclosure;
- no mode catalogue on Today;
- no wall of metrics;
- no repeated plan explanation.

## 6. Practice

### Default

Prescribed practice comes first.

Show:

- why this rep fits the active plan;
- target;
- success criterion;
- evidence Noum will inspect;
- duration;
- one Start action.

### Manual exploration

Retain manual selection behind **Choose manually**. It should feel intentional and separate, not compete with the prescription.

Modes are implementation choices under the plan. Their setup screens should inherit the same visual system and state the coaching purpose before configuration details.

### Active recording

Keep the interface calm:

- prompt or scenario;
- timer/state;
- one short target cue;
- essential controls;
- no competing coaching text;
- no live score that distracts from speaking.

Live interventions should be rare, observable, and optional. Do not interrupt the user's flow to display speculative emotion or personality inference.

## 7. Processing and reliability states

Processing must communicate activity without long explanatory text.

Every request ends visibly as:

- response ready;
- repair in progress;
- truthful fallback;
- actionable retry;
- provider unavailable;
- cancelled.

Never leave a generic spinner indefinitely. Expose a trace ID in Developer Tools or support export, not in normal consumer UI.

## 8. Review

The Review teaching loop already exists conditionally. Make it the reliable default when evidence quality permits.

### First visible order

1. **What I heard**
   - exact verified quote;
   - one earned strength;
   - one diagnosis.
2. **One step better**
   - minimally improved wording;
   - change highlights;
   - one-sentence rationale.
3. **Try it now**
   - same-target retry;
   - one success criterion;
   - one dominant CTA.

### Secondary content

Behind disclosure:

- aspirational end state;
- full transcript;
- detailed evidence;
- metric breakdown;
- formal rubric;
- alternative hypotheses;
- coaching rationale;
- export, only after privacy/redaction rules are defined.

### Copy limits

- one diagnosis sentence;
- one rationale sentence;
- one retry instruction;
- avoid repeated labels and long paragraphs;
- prefer highlighted transcript changes over explanation.

## 9. Targeted retry and comparison

Retry is one tap and preserves the same source prompt where possible.

Before speaking, show only:

- same target;
- one cue;
- duration;
- Start.

After the retry, show:

- target improved / held / regressed / insufficient evidence;
- compact original-versus-retry comparison;
- one brief felt-experience question when useful;
- Noum's plan decision: repeat, vary, increase challenge, or move on.

Do not score unrelated dimensions unless a severe issue invalidates the attempt.

## 10. Progress

Progress should tell one coaching story:

- desired outcome;
- current working focus or active plan;
- intervention and evidence depth;
- specific changes earned;
- remaining uncertainty;
- real-world outcomes;
- next review point.

### Progress hierarchy

1. current coaching stage;
2. strongest recent evidence win;
3. active target and next review;
4. weekly or benchmark evaluation;
5. full history and detailed metrics.

### Path and rewards

Path, levels, achievements, streaks, personal bests, and milestones use one visual grammar.

- evidence win first;
- journey movement second;
- milestone celebration occasionally;
- no hollow XP or constant confetti;
- no shame or fear of losing progress;
- social comparison is secondary and opt-in.

Path should become a concise visual representation of the plan, not an independent curriculum competing with it.

## 11. You

You contains:

- desired outcome and goal history;
- coaching preferences;
- coaching memory and evidence provenance;
- optional delivery-tailoring consent;
- account, privacy, subscription, accessibility, and settings.

### Memory management

Use an inspectable, editable destination rather than generic alert popups.

Each memory item should show:

- what Noum knows or is testing;
- source;
- date;
- confidence/evidence depth;
- edit, correct, or remove action.

Sensitive hypotheses require explicit language and easy correction.

## 12. Talk to Noum / Ask Noum

Noum should not open as an empty generic chatbot.

Attach explicit, removable context:

- active goal;
- working focus or intervention;
- latest relevant rep or transcript;
- upcoming moment;
- user-selected memory.

Offer contextual prompts such as:

- Why did you choose this focus?
- Show me what changed in my wording.
- How does this connect to my goal?
- That answer did not feel like me.
- What should I practise before tomorrow?

The immersive live call remains a core relationship mode. Typed interaction is a connected alternative, not a separate intelligence stack.

## 13. Onboarding

The existing onboarding should be simplified, not replaced wholesale.

Required sequence:

1. clear value promise;
2. desired outcome;
3. felt difficulty;
4. microphone/privacy explanation at the moment of need;
5. personalised first rep.

Defer style selection unless it directly improves the first prompt. Style should usually be proposed after hearing the user.

Avoid:

- feature tours;
- long copy;
- early paywall interruption before value;
- generic `Not now` / `Save` popup chrome;
- forcing users to understand modes.

## 14. Visual system

### Direction

Use:

> **New coaching journey architecture + the earlier Rep Report's visual confidence + much lower information density.**

The current Figma prototype is an information-architecture reference, not an approved production visual system.

### Personality

- calm and premium at rest;
- warm, responsive, and alive when progress is earned;
- professional and adult, not sterile or childish.

### Colour

- warm off-white or light neutral canvas;
- dark ink text;
- violet/purple primary brand accent;
- semantic blue, green, and amber sparingly;
- gradients only for focal moments, not every card;
- dark mode uses semantic tokens, not simple inversion.

### Typography

Use a compact hierarchy:

- Screen title: 30–34 pt, bold/semibold;
- Hero insight: 24–30 pt;
- Section title: 17–20 pt, semibold;
- Body: 16–17 pt;
- Supporting text: 13–15 pt;
- Eyebrows: rare, short, never as the main information carrier.

Dynamic Type must preserve hierarchy without hiding secondary correction actions.

### Spacing and surfaces

Use an 8-point base rhythm with semantic tokens.

- 20–24 pt screen margins;
- 24–32 pt between primary sections;
- 16–20 pt internal padding;
- 18–28 pt radii based on component role;
- avoid nesting cards inside cards;
- open layouts are preferred for headings, narrative, and progress;
- cards are reserved for distinct interactive or evidence objects.

### Card policy

Allow only a small set:

1. hero/prescription;
2. verified evidence;
3. transcript comparison;
4. progress event;
5. disclosure/detail;
6. error/offline.

Do not wrap every row, label, and paragraph in a container.

### Motion and haptics

Motion explains state:

- 180–260 ms for local transitions;
- 300–450 ms for earned progress moments;
- subtle spring only for direct manipulation or completion;
- light haptic for selection;
- success haptic for earned milestone, not ordinary taps;
- Reduce Motion replaces movement with calm opacity/state changes.

### Illustration

Use illustration only when it clarifies progress or emotional tone. Path artwork should be polished, spatially open, opaque, and subordinate to the coaching stage. Avoid low-quality footsteps, clip-art trees, and decorative scenes without product meaning.

## 15. Copy and information-density rules

Copy should be short, human, confident, and evidence-led.

Prefer:

- “Your opening held in three of four recent reps.”
- “Today, shorten the proof point.”
- “Early read — Noum will refine this.”

Avoid:

- generic praise;
- report voice;
- raw metadata;
- repeating the same explanation across screens;
- long prose where a comparison can show the point;
- identity or authenticity judgements.

Every screen should have one clear sentence that explains why it exists.

## 16. Figma update plan

Update the existing Noum Figma project. Do not create another disconnected audit file.

### Pages

1. `00 Evidence archive` — current screenshots and rejected explorations.
2. `01 Product flow` — Day 0, first week, ongoing, real-moment, failure flows.
3. `02 Foundations` — variables, type, spacing, colour, elevation, motion.
4. `03 Components` — reusable variants and states.
5. `04 Reference screens` — Today, Review, Progress; two variants each initially.
6. `05 Core journey` — onboarding through retry and plan update.
7. `06 Coach and context` — live call, typed coach, memory, goal change.
8. `07 Accessibility and states` — dark, Dynamic Type, VoiceOver, Reduce Motion, loading, error, offline.
9. `08 Prototype` — complete clickable coaching loop.
10. `09 Handoff` — annotations, SwiftUI mapping, acceptance criteria.

### First design gate

Before expanding the full app, approve:

- Today;
- Review;
- Progress.

Each gets two real visual alternatives using editable components, not screenshot collages. Test them with tasks before selecting the system.

### Required component families

- app shell/navigation;
- hero prescription;
- evidence win;
- working-focus card;
- verified quote;
- one-step comparison;
- retry action;
- progress event/landmark;
- memory item;
- coach context attachment;
- formal evaluation disclosure;
- loading/error/offline;
- achievement arrival and collapsed state.

## 17. Implementation sequence

Implement complete vertical slices, not broad screen restyling.

### Slice 1 — first value loop

Onboarding → personalised rep → Review → one-step rewrite → targeted retry → provisional focus.

### Slice 2 — returning loop

Today → prescribed practice → Review → plan update → compact progress signal.

### Slice 3 — coaching relationship

Contextual live/typed Noum → goal change → memory correction → long-prompt/error recovery.

### Slice 4 — progress system

Progress → Path → weekly review → unified achievements/milestones.

Each slice requires:

1. approved Figma frames;
2. SwiftUI implementation;
3. deterministic screenshot capture;
4. Figma-versus-app comparison;
5. accessibility checks;
6. targeted tests;
7. current-source evidence bundle.

## 18. Validation

Task-test whether users can, without explanation:

- identify today's next action;
- understand why Noum selected it;
- begin without browsing a catalogue;
- understand what mattered in their words;
- see one achievable improvement;
- retry the same target;
- understand how the result changed the plan;
- correct Noum quickly;
- find formal evaluation when desired;
- distinguish evidence, hypothesis, and aspiration.

No visual direction is approved only because it looks attractive. It must improve comprehension, trust, action, and continuity.

See `PRODUCT_DECISION_LOG.md` for decision status and `COACHING_SYSTEM_SPEC.md` for coaching logic.
