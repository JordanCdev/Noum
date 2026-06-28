# Ask Noum / Chat with Noum — Feature & Limitations Brief

_For external evaluation. Prepared 2026-06-28 against branch `ux-overhaul`._

This document describes the **Noum coach** — the conversational feature users reach via
"Ask Noum" (text) and the live **coach call** (voice). It is written to be honest: every
capability is paired with its real boundary. Where a claim could be checked, it was checked
against the shipping Swift source, not assumed. File references are included so an evaluator
can audit; line numbers drift and are omitted in favour of file + symbol names.

---

## 1. What it is (in one paragraph)

Noum's coach is a single conversational brain reachable in two modes that share one thread and
one reply pipeline: a **text chat** (`AskNoumView`) and an **immersive voice call**
(`LiveCoachCallView`), both wrapped by `CoachSessionView`. A user message is turned into a
coach reply by `CoachReplyPipeline`, which assembles a compact portrait of the user (goals,
recent practice data, trends, durable "case file" memory, verified quotes), retrieves relevant
coaching technique from an **on-device knowledge base**, and sends all of it to a hosted LLM
through a failover chain of providers. Every reply passes a **quality gate** before it is shown;
replies that fail are repaired once or held back behind an honest notice. The feature is
deliberately conservative — it refuses to fabricate a coach answer locally, refuses to overclaim
from thin evidence, and structurally refuses to claim it has replaced a human coach.

**It is not:** a generic ChatGPT wrapper, an offline assistant, a multilingual coach, or a
streaming chatbot. Each of those boundaries is explained below.

---

## 2. The two modes

Both modes are containers around the same `AskNoumStore` thread and the same
`CoachReplyPipeline`. Switching between them never loses conversation context.

### 2.1 Text chat — `AskNoumView`
- Alternating message bubbles: right-aligned user bubbles, full-width coach cards with a colored
  left stroke (no per-bubble avatar, by design — reduces visual noise).
- Coach replies are formatted (bold lead-ins, bullets, numbered lists via
  `CoachFormattedMessageText`) and reveal **word-by-word** (~30 ms/word) unless Reduce Motion is
  on, in which case they land instantly.
- A living "presence" orb (`NoumCharacter`) at the top reacts to state: calm / thinking /
  coaching. A mini orb is the typing indicator ("Noum is thinking").
- **One unified 44 pt input control** that morphs by context: mic when the field is empty,
  send-arrow when there's text, stop when recording, waveform when the coach is speaking aloud.
- **One "continuation surface" per turn** (an arbiter picks the single highest-priority one):
  a goal/voice proposal, a hypothesis acknowledgement ("does this read match?"), a revised-read
  follow-up, or a "Next move" panel that can launch a practice rep.
- Thread options menu: start a coach call, toggle spoken replies, clear thread.

### 2.2 Voice call — `LiveCoachCallView`
- Immersive dark UI with a large tappable presence orb, a LIVE/COACH status pill, and live
  captions.
- **Push-to-talk, not auto-listen.** Turn shape: tap Talk → speak → the mic auto-sends after
  **2.2 s of silence** (or a 30 s hard cap) → coach thinks → coach speaks → mic stays closed →
  the user must tap Talk again. Auto re-arm was deliberately removed because it created an echo
  loop (the mic transcribed the coach's own TTS). This is enforced and commented against
  regression in several places.
- **Barge-in:** tapping Talk while the coach is speaking interrupts it and takes the floor.
- **Dead-mic watchdog:** if the mic is armed but hears nothing for 6 s (a common simulator/route
  failure), the call ends with an honest line: _"I can't hear you — check mic access, or use Type
  instead."_ — rather than a frozen "Listening…".
- Controls are Zoom-style: Talk (primary), Mute/Unmute spoken replies, Type (switch to chat),
  Leave (de-emphasized, never styled as "next").

### 2.3 Day-zero behaviour (before the first practice rep)
Before a user has completed a single rep, the thread is **read-only**. It shows a deterministic
(non-LLM) greeting that acknowledges their stated challenge and chosen voice, states honestly
"no read yet," and offers a single CTA to run the first rep. Rationale: a coaching reply with
zero evidence would be a guess wearing a coach's voice. Full conversation unlocks after rep 1.

---

## 3. Entry points & lifecycle

- **Home coach card** ("Ask your coach") — appears after the first rep or once a coaching profile
  exists. Routes to the call by default.
- **Post-rep Summary** — "Talk to your coach about this rep" injects a session-anchored opener and
  pushes the thread.
- **Default door logic** (`CoachSessionView`): a `.live` request falls back to `.type` when voice
  permission is missing or the user is a true cold-start (rep 0 + no chosen voice), so nobody lands
  in a dead-mic call. An explicit `.type` request is always honored.
- There is **no public deep-link** into Ask Noum today; cross-surface entry is the programmatic
  inject path.

---

## 4. The coach brain (on-device grounding)

This is what separates Noum from a thin wrapper. Three on-device layers run before any network call.

### 4.1 Curated knowledge base — `CoachingKnowledgeBase`
- **61 hand-authored coaching cards** (verified count; the integrity test asserts ≥ 50) across 13
  domains: filler reduction, composure under pressure, pacing/clarity, structure, rhetoric,
  progress reading, voice register, and five "transfer" domains (interviews, presentations,
  conflict, leadership, social, networking).
- Each card carries an **evidence tier** — `empirical` (~18), `practitioner` (~37), `folk` (~6) —
  and the prompt formatter softens language for weaker tiers, so the model can't present a
  rule-of-thumb as established science.
- Cards teach the coach _how to coach a signal_; they never make claims about the user. User data
  always wins over a card. Ships in-binary (offline-capable, no download).

### 4.2 Retrieval — `KnowledgeRetriever`
- **Primary: pure-Swift BM25** over an in-memory inverted index. Deterministic, dependency-free,
  sub-millisecond, offline, fully unit-tested. Boosted by the user's active skill lever and chosen
  voice.
- **Cold-start honesty gate:** for a user with no diagnosis/lever, technique is surfaced _only_ if
  the turn explicitly asks for it ("how do I…", "tips", "help me…"). Otherwise zero cards — no
  unsolicited prescriptions.
- Retrieval is **single-shot per turn** (one call inside the pipeline). The retriever is written
  "tool-shaped" so a future model-driven agentic tool-loop could call it repeatedly — **but that
  loop is not implemented today.** (A prior internal note describing an "agentic retrieve_expertise
  tool-loop" as landed was optimistic; the current code does one retrieval per reply.)

### 4.3 Optional semantic rerank — `KnowledgeSemanticReranker`
- An optional rerank using Apple's on-device `NLContextualEmbedding` (iOS 17+) with reciprocal-rank
  fusion over a wider BM25 pool.
- Flag `KnowledgeBrainFlags.semanticRerankEnabled` defaults **on**, but it is **fire-and-forget and
  non-blocking**: warmup runs off the reply path, and if the model isn't ready (Simulator, offline,
  assets not downloaded) the reply silently uses plain BM25. It can never delay or break a reply.

### 4.4 User context — `CoachContextBuilder`
On every turn the pipeline assembles a bounded (target ≤ ~500 tokens of summary) portrait from
roughly 15+ sections, including: chosen voice/goal and why-now; an active "big moment" and
rehearsal readiness; real-world transfer outcomes (explicitly marked "user's read, not objective
proof"); weekly check-in self-reports; baseline metrics; recent rated sessions; streaks; path
progression; per-skill trends; the coaching memory case file; recent verified proof quotes; a
delivery profile; and the recent chat turns. Transcripts are **not** dumped — only metrics and
short summaries, plus the single most-recent timed transcript used for quote verification.

### 4.5 Durable memory — `CoachMemory` / `CoachMemoryStore` (in `PrimaryFocusMemory.swift`)
The coach keeps a persisted, per-account **case file**: a working hypothesis, the active skill
lever and why, an intervention with an explicit success criterion and review date, an adaptation
log (bounded to the last 8 course-changes with reasons), the user's one-tap acknowledgement of the
current hypothesis (confirmed / uncertain / rejected), reflection patterns, and transfer reviews.
This is what lets the coach say "we changed course because you pushed back" and review a
prescription on a cadence — and it persists across app launches.

---

## 5. The reply pipeline & quality control

### 5.1 Flow
`AskNoumStore.appendUserTurn` → `CoachReplyPipeline.generate` assembles system prompt + context +
retrieved expertise + grounding quotes → `AICoachChatService.reply` runs the provider chain →
quality gate → (repair if needed) → `AskNoumStore.completeCoachTurn` persists the result.

### 5.2 Provider chain — `AICoachChatService`
Hardcoded preference order, each tried only if a key is configured; failed/blocked providers move
to the back on a cooldown rather than being dropped:
1. **Google Agent Platform / Vertex** (default model `gemini-3.5-flash`)
2. **Gemini direct** (`gemini-3.5-flash`)
3. **Anthropic Claude** (default `claude-sonnet-4-6`) — positioned as a **quality fallback**, not a
   cheap default
4. **OpenAI**
5. **DeepSeek**

Parameters: temperature **0.6**, output cap **180 tokens** (128 on a repair pass), history replay
capped at **24 messages** (~12 turn pairs). Truncation-honest: a length-cut completion becomes an
honest "didn't get enough back" notice, not a sentence that stops mid-word. Cooldowns: 60 s
(rate-limit / 429), 600 s (auth/billing block / 401–403, and 402 payment-required maps here),
30 s (transient 5xx).

### 5.3 Quality gate — the part most evaluators will care about
Before any reply is shown, `replyQualityIssue` runs ~14 checks and rejects replies that, e.g.:
are too long; use banned robotic phrasing ("based on your data", "let's", "as an AI"); offer a menu
instead of a decision; ask a bare clarifying question instead of inferring intent; defend the
product instead of repairing trust; **overclaim certainty** from thin evidence; **quote user speech
that wasn't actually said** (a dual quote-guard against fabricated transcripts); name a technique
the user didn't ask for; expose internal scaffold labels; or ignore retrieved expertise on a
technique-seeking turn.

A failed reply triggers **one repair pass** to the same provider with explicit rewrite
instructions; the repair is re-gated. If it still fails, that provider is treated as content-rejected
and the chain moves on. If everything fails, the user sees a typed, honest system notice — the app
**never fabricates a coach reply locally**.

### 5.4 System prompt & coaching invariants
The voice-specific system prompt (`CoachContextBuilder.systemPrompt`) hard-codes the coaching
invariants: weak evidence → softer language; never state audience perception as fact; no fake
causation from metrics; no absolute structure claims without support; never punish-shame a
regression; drills are tests, not guarantees; cite at least one concrete fact from context or it
reads as a wrapper. Two refinement flags (`structuredReplyShape`, `judgmentLayerRule`) both default
**on**.

---

## 6. Voice stack (call mode)

- **Speech-to-text: Deepgram Nova-2**, real-time over WebSocket. The app fetches a short-lived,
  scoped Deepgram key from the backend, then streams 16-bit PCM. **Fallback:** Apple's on-device
  `SFSpeechRecognizer` if the cloud path fails (then skipped for the rest of the session).
- **Text-to-speech:** cloud TTS chain (Google Cloud TTS → OpenAI `tts-1` "nova" → backend), with
  on-device `AVSpeechSynthesizer` as a last resort. The on-device voice is audibly distinct on
  purpose. A monotonic generation counter prevents a stale TTS fetch from playing over a newer turn.
- **Audio session:** `.playAndRecord` + `.duckOthers`, speaker-forced. The procedurally-synthesized
  `SoundscapeEngine` ambience ducks (not hard-stops) under recording.
- Spoken replies are gated on the user's Aloud toggle **and** an English-locale check.

---

## 7. Persistence & privacy

- **On-device only.** The chat thread (messages, capped at **40** on disk) is stored in
  UserDefaults keyed by account ID. There is **no cloud sync / no Firestore backup** of the
  conversation. Clearing the thread or signing out wipes it.
- **What leaves the device on each turn:** the system prompt, the ~500-token user-context summary
  (goals, metrics, trends, recent chat turns, retrieved cards), up to 24 prior messages, and the
  most-recent timed transcript + verified quotes used for grounding. This goes to whichever hosted
  LLM provider answers (Google / Anthropic / OpenAI / DeepSeek). It is sufficient context that a
  provider sees a coherent portrait of the user's practice, goals, and stated insecurities.
- **What does not leave:** full practice-session transcripts (only summaries), audio (STT is
  separate), and account identifiers (UID/email aren't in the request body).
- Transport is standard TLS; there is no per-turn end-to-end encryption beyond that.

---

## 8. Honest limitations (read this section closely)

These are the real boundaries an evaluator should weigh.

1. **Backend auth is currently broken (CRITICAL, open).** The transcription-key endpoint trusts a
   **spoofable `X-Noum-Account-ID` header** with no verifiable credential, and the shipped backend
   URL is extractable from the app. Anyone can mint account-level Deepgram keys; the same pattern
   exposes an AWS-credentials endpoint and several IM endpoints. This is documented in
   `docs/SECURITY_deepgram_key_endpoint.md`. Fix (key rotation + Firebase-token-verified, rate-limited,
   short-TTL scoped keys) is **pending and off-repo**. **This must be fixed before any real-user
   launch.** It does not affect text-chat correctness, but it is the most serious issue in the system.

2. **Single STT provider, single backend dependency.** Voice input depends on Deepgram + the backend
   key-minting endpoint, with only Apple on-device STT as a degraded fallback. No AWS/Google STT
   fallback is wired.

3. **No offline mode.** Every text reply requires a live network round-trip to a hosted LLM; voice
   requires network for STT, reply, and (usually) TTS. The brain's grounding is on-device, but
   generation is not.

4. **English-only (M13 policy).** Non-English practice locales receive a typed "English only" notice
   instead of a reply, rather than a lower-quality localized coach.

5. **No spend cap on chat.** The `AIRateLimiter` (free 12/day, premium 40/day) currently governs
   **only post-rep coach notes** — chat is explicitly exempt. Provider cooldowns are the only brake.
   A power user could run unbounded chat turns and incur real cost.

6. **Single hosted-LLM dependency per reply, no A/B.** The provider order is hardcoded; there is no
   per-user model override or experiment bucketing without a code change.

7. **No streaming.** Replies return as a complete payload; the word-by-word reveal is a client-side
   animation, not token streaming.

8. **The agentic retrieval loop is aspirational, not built.** Retrieval is one BM25(+optional
   rerank) call per turn. The "tool-shaped" framing is forward-looking only.

9. **Verification caveat on recent work.** Much of the recent coach logic was authored in
   environments without an Xcode/Swift toolchain and was reviewed statically, not compiled or run in
   that round (see `HANDOFF.md`). The most recent _full_ local build/test pass reported ~1961 pass /
   3 pre-existing UI failures; treat the green status as "verified at the last real build," and
   re-run `xcodebuild test` on a real host before shipping. The quality gate, provider chain, and
   knowledge corpus themselves have solid unit coverage (~85–100 chat-specific tests across
   `CoachBrainTests`, `CoachProviderChainTests`, `CoachLiveEvaluationTests`, `CoachBrainRerankTests`,
   plus `NoumChatFlowUITests`).

10. **Coach-parity is bounded by design.** Internal evals place the coach around **7.5/10** against
    human-coach parity. The app **structurally refuses** to self-certify "replaces a human coach"
    (`CoachParityReadiness` caps validation at `.forming` — no code path returns "earned"). The
    remaining gap is partly perception depth (delivery sensing is a few audio-derived channels; no
    prosody-contour/breathing analysis; the video pipeline is thin and not wired into coach memory)
    and partly things that can only move with real users + longitudinal outcomes. This ceiling is
    intentional, not a bug.

---

## 9. Quick reference — where things live

| Concern | Primary file(s) |
|---|---|
| Text chat UI | `Noum/AskNoumView.swift` |
| Voice call UI + turn loop | `Noum/LiveCoachCallView.swift` |
| Mode container / door logic | `Noum/CoachSessionView.swift` |
| Thread state & persistence | `Noum/AskNoumStore.swift` |
| Voice input / STT chain | `Noum/AskNoumVoiceInput.swift`, `DeepgramProvider.swift` |
| Reply orchestration | `Noum/CoachReplyPipeline.swift` |
| Provider chain, quality gate, repair | `Noum/AICoachChatService.swift` |
| System prompt + user context | `Noum/CoachContextBuilder.swift` |
| Knowledge corpus | `Noum/CoachingKnowledgeBase.swift` |
| Retrieval (BM25) | `Noum/KnowledgeRetriever.swift` |
| Optional semantic rerank | `Noum/KnowledgeSemanticReranker.swift` |
| Durable coach memory / case file | `Noum/PrimaryFocusMemory.swift` |
| TTS / spoken replies | `Noum/PracticeSupport.swift` (`IMMessageSpeaker`) |
| Rate limiting | `Noum/AIRateLimiter.swift` |
| Known security issue | `docs/SECURITY_deepgram_key_endpoint.md` |

---

## 10. One-line verdict for an evaluator

A genuinely grounded, honesty-first coaching conversation — curated expertise + durable per-user
memory + a strict quality gate, in two well-considered modes — whose two material risks are an
**unfixed spoofable-auth backend leak** (must fix before launch) and the usual hosted-LLM
dependencies (network-required, single-provider-per-reply, English-only). It is deliberately built
to under-promise: it will not pretend to be offline, will not fabricate replies, and will not claim
to have replaced a human coach.
