import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import test from "node:test";
import {
  assertTrustedCaller,
  buildVertexContents,
  type CoachGenerateContentResponse,
  coachCompletionLogMetadata,
  consumeCoachStream,
  isAcceptableFinishReason,
  maxOutputTokensForRequest,
  modelForQualityTier,
  nextRateState,
  normalizeQualityTier,
  validateCoachChatRequest,
} from "./index.js";
import {FinishReason} from "@google/genai";

const request = {
  schemaVersion: 1,
  requestID: "2cb446d8-4f39-43a6-a95c-2486e47155bc",
  surface: "text",
  qualityTier: "fast",
  coachingContext: "One completed rep. Evidence remains early.",
  messages: [{role: "user", content: "What should I fix first?"}],
};

test("validates the versioned coach request", () => {
  assert.deepEqual(validateCoachChatRequest(request), request);
});

test("normalizes legacy tiers and routes Fast and Ultra models", () => {
  assert.equal(normalizeQualityTier("geminiFast"), "fast");
  assert.equal(normalizeQualityTier("claudeReasoning"), "ultra");
  assert.equal(modelForQualityTier("fast", "flash", "pro"), "flash");
  assert.equal(modelForQualityTier("ultra", "flash", "pro"), "pro");
});

test("server budgets cover every Fast and Ultra client route", () => {
  assert.equal(maxOutputTokensForRequest("text", "fast"), 180);
  assert.equal(maxOutputTokensForRequest("text", "ultra"), 380);
  assert.equal(maxOutputTokensForRequest("live", "fast"), 220);
  assert.equal(maxOutputTokensForRequest("live", "ultra"), 220);
});

test(
  "legacy Ultra normalizes through routing and completion metadata",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      qualityTier: "claudeReasoning",
    });
    const model = modelForQualityTier(
      input.qualityTier,
      "gemini-2.5-flash",
      "gemini-2.5-pro"
    );
    const completion = await consumeCoachStream(
      input,
      model,
      {
        generate: async () => vertexStream(["Lead with the answer."]),
      }
    );

    assert.equal(input.qualityTier, "ultra");
    assert.equal(model, "gemini-2.5-pro");
    assert.equal(completion.qualityTier, "ultra");
    assert.equal(completion.model, "gemini-2.5-pro");
  }
);

test("rejects an oversized message list", () => {
  assert.throws(() => validateCoachChatRequest({
    ...request,
    messages: Array.from({length: 13}, () => request.messages[0]),
  }));
});

test("rejects every invalid public request discriminator", () => {
  for (const patch of [
    {schemaVersion: 2},
    {requestID: "not-a-uuid"},
    {requestID: "00000000-0000-0000-0000-000000000000"},
    {surface: "settings"},
    {qualityTier: "unknown"},
    {coachingContext: ""},
    {messages: []},
    {messages: [{role: "system", content: "Policy"}]},
    {messages: [{role: "user", content: ""}]},
  ]) {
    assert.throws(() => validateCoachChatRequest({...request, ...patch}));
  }
});

test("accepts exact field boundaries and rejects one character over", () => {
  const exact = {
    ...request,
    coachingContext: "c".repeat(12_000),
    messages: [
      {role: "assistant", content: "a".repeat(4_000)},
      {role: "user", content: "u".repeat(4_000)},
    ],
  };
  assert.equal(validateCoachChatRequest(exact).coachingContext.length, 12_000);
  assert.throws(() => validateCoachChatRequest({
    ...exact,
    coachingContext: "c".repeat(12_001),
  }));
  assert.throws(() => validateCoachChatRequest({
    ...request,
    messages: [{role: "user", content: "u".repeat(4_001)}],
  }));
});

test("rejects total input over the 32000 character envelope", () => {
  assert.doesNotThrow(() => validateCoachChatRequest({
    ...request,
    coachingContext: "c".repeat(12_000),
    messages: Array.from({length: 5}, (_, index) => ({
      role: index === 4 ? "user" : "assistant",
      content: "m".repeat(4_000),
    })),
  }));
  assert.throws(() => validateCoachChatRequest({
    ...request,
    coachingContext: "c".repeat(12_000),
    messages: [
      ...Array.from({length: 5}, () => ({
        role: "assistant",
        content: "m".repeat(4_000),
      })),
      {role: "user", content: "x"},
    ],
  }));
});

test("rejects a request whose last turn is not the user", () => {
  assert.throws(() => validateCoachChatRequest({
    ...request,
    messages: [{role: "assistant", content: "A reply"}],
  }));
});

test("minute rate limit allows five and rejects the sixth", () => {
  const now = 1_800_000;
  let state = nextRateState(undefined, now);
  assert.equal(state.allowed, true);
  for (let count = 2; count <= 5; count += 1) {
    state = nextRateState(state.state, now);
    assert.equal(state.allowed, true);
  }
  state = nextRateState(state.state, now);
  assert.equal(state.allowed, false);
});

test("rate windows reset independently", () => {
  const first = nextRateState(undefined, 3_600_000);
  const nextMinute = nextRateState(first.state, 3_660_000);
  assert.equal(nextMinute.state.minuteCount, 1);
  assert.equal(nextMinute.state.hourCount, 2);
  const nextHour = nextRateState(nextMinute.state, 7_200_000);
  assert.equal(nextHour.state.minuteCount, 1);
  assert.equal(nextHour.state.hourCount, 1);
});

test("hour rate limit allows thirty and rejects the thirty-first", () => {
  const hourStart = 10 * 3_600_000;
  let state = nextRateState(undefined, hourStart);
  for (let count = 2; count <= 30; count += 1) {
    state = nextRateState(state.state, hourStart + (count - 1) * 60_000);
    assert.equal(state.allowed, true);
  }
  state = nextRateState(state.state, hourStart + 30 * 60_000);
  assert.equal(state.allowed, false);
});

test("requires both authenticated and App Check-verified callers", () => {
  assert.throws(() => assertTrustedCaller(undefined, {appId: "app"}));
  assert.throws(() => assertTrustedCaller({uid: "user"}, undefined));
  assert.doesNotThrow(() => assertTrustedCaller(
    {uid: "user"},
    {appId: "app"}
  ));
});

test("client rules deny every rate-limit collection operation", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  assert.match(
    rules,
    // This exact server-only rule should remain visually auditable.
    // eslint-disable-next-line max-len
    /match \/_serverRateLimits\/\{[^}]+\}[\s\S]*?allow read, write: if false;/
  );
});

test("only complete STOP generations are accepted", () => {
  assert.equal(isAcceptableFinishReason("STOP"), true);
  const rejected = [
    "MAX_TOKENS", "SAFETY", "RECITATION", "UNKNOWN", null,
  ];
  for (const reason of rejected) {
    assert.equal(isAcceptableFinishReason(reason), false);
  }
});

test("operational log metadata cannot contain coaching content", () => {
  const metadata = coachCompletionLogMetadata(
    validateCoachChatRequest(request),
    "gemini-2.5-flash",
    "STOP",
    200,
    40,
    900,
    "ok"
  );
  const serialized = JSON.stringify(metadata);
  assert.equal(serialized.includes(request.coachingContext), false);
  assert.equal(serialized.includes(request.messages[0].content), false);
  assert.deepEqual(Object.keys(metadata).sort(), [
    "finishReason", "inputTokens", "latencyMs", "model", "outputTokens",
    "qualityTier", "requestID", "status", "surface",
  ]);
});

test("Vertex contents attach context once and coalesce adjacent roles", () => {
  const input = validateCoachChatRequest({
    ...request,
    messages: [
      {role: "assistant", content: "Earlier reply"},
      {role: "user", content: "First unanswered turn"},
      {role: "user", content: "Current turn"},
    ],
  });
  const contents = buildVertexContents(input);
  assert.equal(contents[0].role, "user");
  assert.equal(contents[1].role, "model");
  assert.equal(contents[2].role, "user");
  assert.equal(
    contents[2].parts[0].text.includes("First unanswered turn"),
    true
  );
  assert.equal(contents[2].parts[0].text.includes("Current turn"), true);
  const serialized = JSON.stringify(contents);
  assert.equal(serialized.match(/COACHING CONTEXT/g)?.length, 1);
  for (let index = 1; index < contents.length; index += 1) {
    assert.notEqual(contents[index - 1].role, contents[index].role);
  }
});

/**
 * Builds the smallest valid Vertex response fixture.
 * @param {string} text Candidate text.
 * @param {FinishReason|undefined} finishReason Candidate finish reason.
 * @param {boolean} includeUsage Whether to attach final token metadata.
 * @return {CoachGenerateContentResponse} Vertex response fixture.
 */
function vertexResponse(
  text: string,
  finishReason: FinishReason | undefined,
  includeUsage = false
): CoachGenerateContentResponse {
  const response: CoachGenerateContentResponse = {
    candidates: [{content: {parts: [{text}]}, finishReason}],
  };
  if (includeUsage) {
    response.usageMetadata = {
      promptTokenCount: 120,
      candidatesTokenCount: 24,
    };
  }
  return response;
}

/**
 * Builds a deterministic Vertex stream fixture.
 * @param {string[]} chunks Streamed text chunks.
 * @param {FinishReason} finishReason Final candidate reason.
 * @return {AsyncIterable<CoachGenerateContentResponse>} Vertex stream fixture.
 */
function vertexStream(
  chunks: string[],
  finishReason: FinishReason = FinishReason.STOP
): AsyncIterable<CoachGenerateContentResponse> {
  return (async function* () {
    if (chunks.length === 0) {
      yield vertexResponse("", finishReason, true);
      return;
    }
    for (const [index, chunk] of chunks.entries()) {
      const isFinal = index === chunks.length - 1;
      yield vertexResponse(
        chunk,
        isFinal ? finishReason : undefined,
        isFinal
      );
    }
  })();
}

test("streams typed deltas and returns typed completion metadata", async () => {
  const deltas: unknown[] = [];
  const completion = await consumeCoachStream(
    validateCoachChatRequest(request),
    "gemini-2.5-flash",
    {
      generate: async () => vertexStream(["Lead first. ", "Add proof."]),
      sendDelta: async (delta) => {
        deltas.push(delta);
      },
    }
  );
  assert.deepEqual(deltas, [
    {type: "delta", requestID: request.requestID, text: "Lead first. "},
    {type: "delta", requestID: request.requestID, text: "Add proof."},
  ]);
  assert.deepEqual(completion, {
    requestID: request.requestID,
    text: "Lead first. Add proof.",
    model: "gemini-2.5-flash",
    qualityTier: "fast",
    finishReason: "STOP",
    inputTokens: 120,
    outputTokens: 24,
  });
});

test("accepts a final metadata-only Gen AI stream chunk", async () => {
  const completion = await consumeCoachStream(
    validateCoachChatRequest(request),
    "gemini-2.5-flash",
    {
      generate: async () => (async function* () {
        yield vertexResponse("Lead first.", undefined);
        yield vertexResponse("", FinishReason.STOP, true);
      })(),
    }
  );

  assert.equal(completion.text, "Lead first.");
  assert.equal(completion.finishReason, "STOP");
  assert.equal(completion.inputTokens, 120);
  assert.equal(completion.outputTokens, 24);
});

test("rejects truncated and empty Vertex completions", async () => {
  for (const result of [
    vertexStream(["Partial"], FinishReason.MAX_TOKENS),
    vertexStream([], FinishReason.STOP),
  ]) {
    await assert.rejects(() => consumeCoachStream(
      validateCoachChatRequest(request),
      "gemini-2.5-flash",
      {generate: async () => result}
    ));
  }
});

test("propagates Vertex failures for callable error mapping", async () => {
  const providerError = new Error("vertex unavailable");
  await assert.rejects(
    () => consumeCoachStream(
      validateCoachChatRequest(request),
      "gemini-2.5-flash",
      {generate: async () => {
        throw providerError;
      }}
    ),
    providerError
  );
});

test(
  "cancels an in-flight stream when the callable client disconnects",
  async () => {
    const controller = new AbortController();
    const blockedStream: AsyncIterable<CoachGenerateContentResponse> =
      (async function* () {
        await new Promise<void>(() => undefined);
        yield vertexResponse("never sent", FinishReason.STOP, true);
      })();
    const pending = consumeCoachStream(
      validateCoachChatRequest(request),
      "gemini-2.5-flash",
      {generate: async () => blockedStream, signal: controller.signal}
    );
    controller.abort();
    await assert.rejects(pending, (error: unknown) => {
      return typeof error === "object" && error !== null &&
      "code" in error && error.code === "cancelled";
    });
  }
);
