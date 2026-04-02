# Noum Recommendation Playbook

## Purpose
This document defines:
- the user benefit of each practice mode
- the user situations each mode is best for
- how a user's north-star goal should bias the next recommendation
- how IM Mode tone and scenario should be selected when conversation practice is the best next rep

The app should use this as a stable rules layer. AI can add freshness, wording, and nuance, but it should not invent the core mapping from scratch.

## Mode Benefits

### Timed Practice
- Core benefit: builds structure, clearer openings, fuller answers, and steadier pacing before pressure breaks the thought.
- Best for:
  - users who answer too briefly
  - users who need stronger answer shape
  - users who want to sound more complete and prepared
  - presentation and interview preparation

### Sudden Death
- Core benefit: builds fast thinking and composure when there is no warm-up and hesitation is exposed immediately.
- Best for:
  - users who freeze
  - users who overthink before answering
  - users who need sharper recall under pressure
  - interviews, live questions, high-pressure speaking moments

### Ah-Counter
- Core benefit: builds real-time awareness of filler habits and replaces verbal clutter with cleaner pauses.
- Best for:
  - users whose main drag is filler words
  - users who ramble or rush
  - users who need cleaner pacing and verbal discipline

### IM Mode
- Core benefit: builds tone control, relationship reading, message choice, and conversational realism.
- Best for:
  - users trying to become better in social conversation
  - workplace communication
  - networking
  - difficult conversations
  - users whose goal depends on sounding right with another person, not just sounding clean in isolation

## North-Star Bias Rules

### Reduce Fillers
- Primary mode bias:
  1. Ah-Counter
  2. Sudden Death
  3. Timed Practice
  4. IM Mode
- Reason:
  filler awareness needs to become live and automatic before realism is layered on.

### Be More Concise
- Primary mode bias:
  1. Timed Practice
  2. IM Mode
  3. Ah-Counter
  4. Sudden Death
- Reason:
  concise speaking depends on clearer structure and tighter wording before pure pressure.

### Think Faster
- Primary mode bias:
  1. Sudden Death
  2. Timed Practice
  3. IM Mode
  4. Ah-Counter
- Reason:
  the bottleneck is response speed and recovery under pressure.

### Sound Calmer / More Composed
- Primary mode bias:
  1. IM Mode
  2. Timed Practice
  3. Ah-Counter
  4. Sudden Death
- Reason:
  composure is most meaningfully tested in realistic interpersonal pressure, then reinforced in cleaner solo reps.

## Context Bias Rules

### Work
- Preferred IM scenario: `workUpdate`
- Escalation scenario: `difficultConversation`
- Typical tone bias: `professional`, `concise`, `calm`

### Social
- Preferred IM scenario: `socialCatchUp`
- Escalation scenario: none unless realism requires tension
- Typical tone bias: `warm`, `confident`

### Interviews
- Preferred mode bias: `suddenDeath`, then `timed`
- Preferred IM scenario when conversation realism helps: `workUpdate` or `networking`
- Typical tone bias: `professional`, `confident`, `concise`

### Presentations
- Preferred mode bias: `timed`, then `suddenDeath`
- Preferred IM scenario when realism helps: `workUpdate`
- Typical tone bias: `professional`, `confident`

## Style-to-Tone Mapping

- `Authoritative` -> `Confident`
- `Warm and welcoming` -> `Warm`
- `Concise and sharp` -> `Concise`
- `Persuasive` -> `Assertive`
- `Executive presence` -> `Professional`
- `Storytelling` -> `Confident`

## Freshness Rules
- Do not keep recommending the exact same top mode if it is already the user's strongest mode and they are stuck there.
- If the strongest mode matches the first-choice bias, rotate to the second-choice mode to keep training fresh.
- Keep the north-star bias intact even when rotating.

## IM Mode Recommendation Rules
- If IM Mode is recommended, include:
  - `recommendedScenario`
  - `recommendedTone`
  - `modeBenefit`
- Scenario and tone should be treated as a starting bias, not a rigid script.
- The app should still vary openings and contextual details so the experience stays fresh.

## Product Principle
- Rules decide the training intent.
- AI decides the phrasing, freshness, and realism.
- If AI and the rules disagree, the rules layer should still anchor the mode/tone/scenario recommendation so the app stays coherent.
