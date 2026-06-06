# Ask Noum — Experience North Star & Anti-Patterns

> **Living reference.** We keep returning to this until the Ask Noum experience
> is _perfect_. It captures BOTH the bar we're building toward AND — equally
> first-class — the things we do **not** like and are moving away from. When in
> doubt about an Ask Noum decision, check this doc. Add to it; don't let it go
> stale.
>
> Origin: Jordan's review of the Ask Noum chat (two screenshots, 2026-06-03).

---

## North Star (the one sentence)

Ask Noum should feel **as close as possible to talking with a real, excellent
human communication coach** — interactive, voice-first, emotionally
intelligent, and concretely actionable. It is **not** a text chatbot, not a
generic AI wrapper, not a form.

If a real coach wouldn't say it, phrase it that way, or make you type it — we
don't ship it.

---

## ❌ What we do NOT like (anti-patterns — move away from these)

These are the reference for "what not to do." Grounded against the current
build where known.

1. **Low EQ / robotic replies.** The coach reads as a machine, not a person.
   - **Worst offender (never repeat):** the user sent a truncated `"What do"`
     and the coach replied _"What do you mean by 'What do'? Can you please
     clarify your question?"_ A human coach never interrogates a half-typed
     message like a form validator. They ride past it, infer intent warmly, or
     gently pick up the thread. This single reply is the canonical example of
     the EQ we're moving away from.
2. **Replies feel templated, not intelligent.** It IS customised (it knows the
   declining-score trend, the "Engaging" style, the vocal-variety focus) — so
   the data is wired — but the _voice_ is flat and generic. Customisation ≠
   intelligence. The felt sense of "this thing actually gets me" is missing.
3. **Prompts/suggestions aren't dynamic.** The "KEEP GOING" chips ("What's the
   next move?" / "Tell me more." / "Where should I focus?") read as a fixed,
   generic menu. _(Grounded note: they are actually generated from context via
   `CoachContextBuilder.followUpSuggestions(...)`, NOT hardcoded — so the fix is
   the **quality/variety/specificity** of generation, not "make them dynamic
   from scratch." They must feel situational: reference what was just said, the
   user's actual case, the next concrete step.)_
4. **The microphone button doesn't work.** A blue mic invites a tap and nothing
   happens. A non-functional control is the worst kind of broken — it promises
   the exact thing (talking) we say is the point. _(Grounded note: voice-input
   infra exists — `inputControlMode` `.mic/.recording/.processing`, gated on
   `AskNoumVoiceInput.isAvailable`. So "doesn't work" is likely an
   availability/permission/simulator gate or a real bug — must be root-caused,
   not assumed absent. Either way, from the user's seat it is broken, and that
   is unacceptable.)_
5. **Text/IM as the DEFAULT paradigm.** A messaging thread is the wrong default
   for a coach. People want to **talk**. Leading with a text box makes Noum feel
   like a chat app, not a coaching conversation.
6. **Visual polish isn't there yet.** "Still doesn't look that great." The
   surface needs to read as premium and calm, in register with the rest of the
   app.
7. **(Implied) Multiple prompts/cards at once look messy.** Stacking suggestion
   chips + a mode card + more would clutter. One call-to-action at a time.

---

## ✅ What we want (target behaviors)

1. **Voice-first, interactive by default.** The default experience mimics
   speaking with a coach: you talk, it listens, it talks back. Fluid, turn-based
   conversation — not "type a message."
   - **Text is the small fallback, not the default.** A discreet, small icon
     somewhere lets people who _can't_ speak (quiet room, accessibility,
     preference) switch to messaging. Text must stay first-class for
     accessibility — but it is the opt-in, not the front door.
2. **Human-grade EQ.** Replies sound like a perceptive coach: warm, specific,
   never a clarify-request to a partial message, gracefully handles
   garbled/short/voice-transcription-imperfect input, reads between the lines,
   reflects the person back to themselves. Short where a coach would be short.
3. **Genuinely dynamic, contextual prompts.** Any suggested follow-ups are
   situational — they reference what was just said and the user's real case, and
   change every turn. Never a static-feeling menu.
4. **Actionable: one mode/exercise recommendation at a time, as a tappable
   card.** When the coach recommends concrete work (e.g. "let's work on vocal
   variety"), surface **a single** prompt/card (e.g. at the bottom) that takes
   the user **directly** into the relevant mode/exercise.
   - **Exactly one at a time.** Never stack cards/prompts. One clear next action.
   - **Defined lifecycle (must be designed, not incidental).** Decide precisely
     when the card APPEARS and when it DISAPPEARS. Candidate rules to pin down:
     appears only when the coach has named a concrete, launchable next action;
     disappears on tap, when superseded by a newer recommendation, when the user
     sends another turn / the conversation moves on, or after it's been acted on.
     **Open — resolve before building.**
   - _(Grounded note: the launch machinery already exists elsewhere —
     `AppDestination` + `SummaryLookingAheadRouter` power the post-rep "go to
     recommended mode" CTA. Reuse that routing; don't invent a parallel path.)_
5. **A mic that actually works**, driving a real spoken turn end-to-end (capture
   → transcribe → coach hears it → coach replies, ideally spoken back via the
   existing `IMMessageSpeaker` TTS).
6. **Premium, calm visual polish** consistent with the app's card language,
   spacing rhythm, and restrained motion.

---

## Open questions (decide before/while building)

- **Card lifecycle:** exact appear/disappear rules (tap / supersede / next-turn
  / acted-on / scroll-away?). Pick rules that never leave a stale launch card.
- **Voice interaction model:** push-to-talk vs. continuous vs. turn-based;
  latency budget; how barge-in/interruption works; what happens mid-reply.
- **"IM style should go altogether" — how literally?** Remove the text thread as
  the default surface but keep it as the fallback view, or a deeper restructure?
  Need to reconcile with existing chat history + the "insights banked" surface.
- **Mic root cause:** is it a simulator/permission/availability gate or a real
  bug on device? Determines whether it's a quick fix or infra work.
- **EQ mechanism:** is the low-EQ reply the model, the system prompt, or the
  deterministic fallback path? (The "clarify your question" reply smells like a
  generic LLM hedge on short input — likely fixable via prompt guidance to
  handle partial/short/voice-transcribed input gracefully and never demand
  clarification.)

---

## Grounded code notes (what exists today — reuse, don't duplicate)

- **Surface:** `Noum/AskNoumView.swift` (chat thread, input control, follow-up
  chips, starter chips, TTS playback).
- **Voice OUT (TTS):** `IMMessageSpeaker.shared.speak(...)` — already wired;
  muteable (the muted-speaker icon top-right). The coach _can_ speak.
- **Voice IN:** `AskNoumVoiceInput` + `inputControlMode` (`.mic/.recording/
  .processing`) — infra exists, availability-gated.
- **Follow-up chips:** `CoachContextBuilder.followUpSuggestions(...)` (generated,
  not hardcoded — improve generation, don't rebuild).
- **Coach replies + context:** `CoachContextBuilder.userContext/systemPrompt`
  feed the model; deterministic fallback exists for offline/no-provider.
- **Mode launching:** `AppDestination` + `SummaryLookingAheadRouter` (the
  existing post-rep "go to recommended mode" CTA) — reuse for the Ask Noum
  mode-launch card.

---

## Status log

- **2026-06-03** — Doc created from Jordan's screenshot review. Nothing fixed
  yet; this captures the target + anti-patterns. Next: confirm scope (esp. the
  voice-first default — a significant change) before implementing.
- **2026-06-03 (later)** — Implemented A1–A5 (each compiled + unit-tested +
  committed on `Redesign`), and verified live on the iPhone 17 Pro simulator
  (screenshot confirms they render):
  - **A1 EQ** — system-prompt rule so the coach never demands clarification of a
    short/partial/voice-garbled message (the "What do" anti-pattern #1).
  - **A2 mic** — fixed the on-device-recognition force that defeated the cloud
    fallback (a silent-fail cause) + added visible failure feedback (no more
    silent nothing). End-to-end CAPTURE still needs **device QA** — sim mic/STT
    is unreliable, and the original report was likely from the simulator.
  - **A3 mode-launch card** — ONE tappable card from the coach's reply → the
    matching practice mode (reuses `AppDestination`); one-at-a-time, takes
    precedence over chips, clean lifecycle (tied to the latest coach reply).
  - **A4 dynamic prompts** — added a vocal-delivery topic so pitch/variety
    replies get situational chips instead of the generic set.
  - **A5 voice-first** — coach speaks by default (was muted) + input leads with
    "Tap the mic to talk — or type…". Simulator screenshot confirms the speaker
    is unmuted and the placeholder is voice-led.
  - **A6 polish** — verified the rendered state: clean + premium-leaning
    (situational chips + voice-first confirmed). Substantive aesthetic polish
    deferred to specific direction — a taste call best made on a real render.
- **2026-06-03 (A7 — voice-first rebuild)** — Built the voice-first input UI
  and **verified it renders** on the iPhone 17 Pro simulator (screenshot): a
  prominent centered talk button is the default ("Tap to talk"), text demoted to
  a small "Type instead" opt-in, a "waveform" toggle returns from text →
  voice, conversation thread + chips unchanged. Reuses the existing
  `inputControlMode` + a now-shared `performInputAction`, so the
  record→transcript→send flow can't drift. Also fixed a **latent build break**
  it surfaced: a never-compiled M24-round suite (`SecondCyclePushbackContextTests`)
  had a spurious `@available` on its `@Suite` (Swift Testing forbids it) — that
  suite now compiles AND runs.
  **Still open:** on-device **mic-capture + TTS QA** (can't verify spoken
  turns from this host — needs a real device); fine-grained aesthetic polish
  (iterative, to Jordan's eye); a continuous hands-free turn loop (currently
  tap-to-talk → review → send, which is the safe default).
