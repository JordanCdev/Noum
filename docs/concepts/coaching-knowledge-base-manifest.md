# Coaching Knowledge Base — manifest

The "brain" behind Ask Noum: a curated, on-device body of communication-coaching
expertise the model is grounded in, so its prescribed moves come from real
coaching practice instead of an averaged-out base-model guess. This is the piece
that was missing — the chat had rich *user telemetry* but zero *coaching
expertise* to cite. RAG closes that gap.

## What shipped

| File | Role |
| --- | --- |
| `Noum/CoachingKnowledgeBase.swift` | The corpus. `CoachKnowledgeCard` schema + `CoachKnowledgeBase.cards` (~64 curated cards). Pure value types, in-binary, no download, no network. |
| `Noum/KnowledgeRetriever.swift` | BM25 retriever (`KnowledgeRetriever.retrieve`) + the honesty gate + `CoachExpertiseFormatter`. Pure, deterministic, `nonisolated`. |
| `Noum/CoachContextBuilder.swift` | `userContext(...)` gained `coachingExpertise:` (defaulted) and emits a `COACHING EXPERTISE` section before `END CONTEXT`. `systemPrompt(...)` gained intelligence-floor rule **#18**. |
| `Noum/CoachReplyPipeline.swift` | `generate()` retrieves (BM25 + optional rerank), threads it into `userContext`, and passes the agentic flag + `CoachToolContext` to the chat service. Same single brain. |
| `Noum/KnowledgeVectorMath.swift` | Pure vector math for the rerank: mean-pool, L2-normalize, cosine, Reciprocal Rank Fusion. Host-testable (no framework). |
| `Noum/KnowledgeSemanticReranker.swift` | Optional `NLContextualEmbedding` rerank actor + `KnowledgeBrainFlags`. Warmup off the reply path; silent BM25 fallback; device-only. |
| `Noum/AICoachChatService.swift` | Soft-anchor gate fix + the agentic `retrieve_expertise` tool-calling loop (`geminiAgenticReply` + the verified Gemini function-calling wire format). |
| `NoumTests/CoachBrainTests.swift`, `NoumTests/CoachBrainRerankTests.swift` | Corpus integrity, retriever relevance + gate, formatter honesty, context injection, anchor-gate regression, vector math, rerank fallback, and the agentic tool/parse helpers. |

## Retrieval decision: BM25 primary, embeddings as an optional rerank

For an ~64-card bounded corpus, **pure-Swift BM25** (k1=1.2, b=0.75) over an
in-memory inverted index is the primary mechanism, NOT a fallback. Why:

- Deterministic, zero-dependency, sub-millisecond, works offline **and in the
  iOS Simulator**, and is fully unit-testable without a device, a model
  download, or any API key.
- An ANN/vector DB (ObjectBox/USearch/SQLiteVec) buys nothing at this size —
  brute-force over ~64 vectors is already trivial.

**Optional rerank (BUILT — `KnowledgeBrainFlags.semanticRerankEnabled`, on, device-only):**
an `NLContextualEmbedding` (iOS 17) semantic rerank of the BM25 top-K
(`rerankCandidatePool = 10` → top 4). The contextual-embedding asset **does not
load in the iOS Simulator** (Apple FB22699606) and downloads on first device run,
so the design makes it a strict enhancement: warmup is **fire-and-forget OFF the
reply path** (`KnowledgeSemanticReranker.warmUpIfNeeded`); the reply path only
uses it when the model is already `.ready` and otherwise returns BM25 order
untouched — it **never blocks or fails** the reply. Per-token `[Double]` vectors
are mean-pooled + L2-normalized (→ `[Float]` cache), and the BM25 and cosine
rankings are fused with Reciprocal Rank Fusion (k=60). The flag is ON because it
degrades to BM25 everywhere it can't run; flip it OFF to avoid the one-time
on-device asset download entirely. **Pure math is unit-tested
(`KnowledgeVectorMathTests`); the embedding path itself needs physical-device QA**
(it always falls back to BM25 in the Simulator, verified by
`KnowledgeRerankFallbackTests`).

## The honesty contract (why this doesn't become a platitude wrapper)

1. **A card is technique reference, never a reading of the user.** The user's own
   telemetry (CONTEXT) is always the evidence; a card is only the method. System
   prompt rule #18 makes the precedence explicit: when a card conflicts with the
   user's observed data, **the user's data wins**, and the coach never states a
   card as a finding about the user or claims a technique caused a result.
2. **Evidence tiers are enforced, not decorative.** Each card carries
   `empirical` / `practitioner` / `folk`. The formatter appends a softening
   qualifier (`[established coaching practice]`, `[rule of thumb — offer it,
   don't assert it]`) for the weaker tiers, matching the app's existing
   weak-evidence → softer-language rule. `CoachKnowledgeBaseIntegrityTests`
   asserts the tiers are actually used.
3. **Readiness gate.** `retrieve` returns `[]` for a cold-start user (no
   `CoachMemory.currentLever`) UNLESS the turn explicitly asks for technique. So
   a brand-new user isn't prescribed technique on thin evidence; the coach reads
   the person.
4. **The corpus can never fight the gate.** `noCardContainsAGateBannedPhrase`
   asserts no card's formatted line contains any `AICoachChatService`
   robotic/defensive banned phrase — so retrieval can't tempt the model into a
   phrase its own reply gate would reject.

> **Sync rule:** `CoachBrainTests.bannedPhrases` mirrors the private
> `roboticPhrases` + `defensiveProductPhrases` in `AICoachChatService`. If that
> gate list changes, update the test list here too.

## Corpus sources & coverage

Hand-authored to the same evidence-honest bar as the intelligence floor, with
vocabulary aligned to what the app already detects (`EloquenceEngine` devices,
`LessonsCatalog` lessons, `SkillArea` levers). Domains map to the product pillars
and the real-world transfer surfaces in `docs/VISION.md`:

filler reduction · composure/pressure · pacing & clarity · structure · rhetoric
(the EloquenceEngine devices) · reading progress (small-sample humility) · voice
register (one per voice) · transfer: interviews / presentations / difficult
conversations / leadership / social-dating / networking.

## Day-to-day reliability fix (shipped alongside)

`AICoachChatService.replyHasObservableAnchor` was rejecting valid SOFT anchors
(no hard keyword/digit), which false-tripped `.unanchoredCoaching` and dumped
good replies to the deterministic fallback. It now also accepts a temporal
marker + a second-person action ("earlier you rushed the open…"). The change
only **admits** more replies — it never newly rejects — so the shared
`LiveCoachCallView` spoken path can't regress from it.

*Not changed (deliberately):* the `"let's"` ban. It is brand-enforced in BOTH the
gate and the system prompt (and pinned by the `rejectsLetsRegister` test), so
they're consistent; un-banning it is a brand-voice taste call for the owner, not
a bug fix.

## Agentic tool-calling loop (BUILT — `KnowledgeBrainFlags.agenticToolCallingEnabled`, on)

Model-driven retrieval: the coach can call the **`retrieve_expertise`** tool on
demand (it crafts its own query) instead of relying only on the pre-retrieved
block. `AICoachChatService.geminiAgenticReply` runs the Gemini function-calling
loop with the **verified wire format** — `tools[].functionDeclarations`,
`toolConfig.functionCallingConfig.mode = "AUTO"`, and critically the tool RESULT
turn is `role: "user"` with a `functionResponse` part (NOT `"function"`/`"tool"`,
which would break the call). Parsing iterates `parts[]` (never assumes index 0)
and treats a `MAX_TOKENS` finish as unusable.

Safety envelope:
- **Text chat only.** `AskNoumView` passes `allowAgentic: true`; the live
  `LiveCoachCallView` voice call leaves it false (latency).
- **Gemini only**, bounded to `agenticMaxRounds = 3`.
- **Fully fallback-guarded.** Any failure (network, parse, unknown tool, gate
  fail, round budget) returns nil → the existing single-shot path runs, carrying
  the SAME grounded context, so the fallback reply is still expertise-grounded.
  Worst case is exactly today's behavior.
- The final agentic text still passes the same quality gate + repair pass.

The deterministic helpers (`expertiseToolDeclaration`, `executeExpertiseTool`,
`geminiContents`, `parseGeminiStep`) are unit-tested (`AgenticToolLoopTests`); the
**live multi-turn loop needs device/network QA** (it can't run against the
offline Simulator test loop).

## Known debt

- `userContext` is now a 27-parameter pure function. The new `coachingExpertise`
  param is additive + defaulted for zero-risk wiring; a future refactor could
  fold the turn-level inputs into a context struct.
