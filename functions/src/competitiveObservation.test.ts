/* eslint-disable valid-jsdoc, require-jsdoc, max-len */

import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import test from "node:test";
import {
  COMPETITIVE_OBSERVATION_INTENT_LIFETIME_MS,
  COMPETITIVE_OBSERVATION_MAX_AUDIO_BYTES,
  COMPETITIVE_OBSERVATION_MAX_PROVIDER_WORDS,
  COMPETITIVE_OBSERVATION_MAX_TRANSCRIPT_CHARS,
  COMPETITIVE_OBSERVATION_MIN_AUDIO_BYTES,
  assertCompetitiveObservationIntentUsable,
  competitiveObservationDocument,
  competitiveObservationIntentMatches,
  competitiveObservationRetryMatches,
  completeCompetitiveObservationWork,
  DeepgramObservationError,
  transcribeCompetitivePCM,
  validateBeginCompetitiveObservationRequest,
  validateCompleteCompetitiveObservationRequest,
  validateDeepgramObservationResponse,
  validateStoredCompetitiveAudioDigestClaim,
  validateStoredCompetitiveObservation,
  validateStoredCompetitiveObservationIntent,
  type BeginCompetitiveObservationInput,
  type CompetitiveObservationAudio,
  type DeepgramCompetitiveObservation,
  type StoredCompetitiveObservationIntent,
} from "./competitiveObservation.js";

const sessionID = "2cb446d8-4f39-43a6-a95c-2486e47155bc";
const challengeID = "8ff009ea-177a-4598-96db-57c8f4266d28";
const requestID = "8f157f61-7330-4271-b47b-16d7e3786211";
const modelUUID = "36a5b2e8-7c1d-4b75-8e77-9bb2d5c1a8f4";
const promptSHA = "a".repeat(64);
const uid = "firebase-user";
const startedAtMs = 1_800_000;
const expiresAtMs = startedAtMs +
  COMPETITIVE_OBSERVATION_INTENT_LIFETIME_MS;

const validBeginRequest: BeginCompetitiveObservationInput = {
  schemaVersion: 1,
  sessionID,
  locale: "en-US",
  mode: "timed",
  demand: {
    schemaVersion: 1,
    timedDifficulty: "medium",
    suddenDeathDifficulty: null,
    speechProjectID: null,
  },
  promptProvenance: {source: "curated", promptDigest: promptSHA},
  challengeID: null,
};

function pcm(byteCount = 32_000): Buffer {
  const bytes = Buffer.alloc(byteCount);
  for (let index = 0; index < bytes.length; index += 2) {
    bytes.writeInt16LE(index % 32_767, index);
  }
  return bytes;
}

function completeRequest(bytes = pcm()): Record<string, unknown> {
  return {
    schemaVersion: 1,
    sessionID,
    audio: {
      encoding: "linear16",
      sampleRateHertz: 16_000,
      channelCount: 1,
      sampleWidthBits: 16,
      dataBase64: bytes.toString("base64"),
    },
  };
}

function intent(
  audioSHA256: string | null = null,
  status: "pending" | "observed" = "pending"
): StoredCompetitiveObservationIntent {
  return {
    ...validateBeginCompetitiveObservationRequest(validBeginRequest),
    uid,
    status,
    competitiveEligible: false,
    audioSHA256,
    startedAtMs,
    expiresAtMs,
    observationCompletedAtMs: status === "observed" ? startedAtMs + 20 : null,
  };
}

function storedIntentDocument(
  overrides: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    ...validBeginRequest,
    sessionID: sessionID.toUpperCase(),
    uid,
    status: "pending",
    competitiveEligible: false,
    audioSHA256: null,
    startedAt: startedAtMs,
    expiresAt: expiresAtMs,
    updatedAt: startedAtMs,
    observationCompletedAt: null,
    ...overrides,
  };
}

function observationAudio(bytes = pcm()): CompetitiveObservationAudio {
  return validateCompleteCompetitiveObservationRequest(
    completeRequest(bytes)
  ).audio;
}

function providerObservation(
  audio: CompetitiveObservationAudio,
  overrides: Partial<DeepgramCompetitiveObservation> = {}
): DeepgramCompetitiveObservation {
  const transcript = "A clear answer.";
  return {
    transcript,
    transcriptSHA256: createHash("sha256").update(transcript).digest("hex"),
    wordCount: 3,
    providerRequestID: requestID.toUpperCase(),
    providerAudioSHA256: audio.sha256,
    providerDurationSeconds: audio.durationSeconds,
    modelUUID: modelUUID.toUpperCase(),
    modelName: "nova-3",
    modelVersion: "2026-01-01",
    ...overrides,
  };
}

function deepgramResponse(
  audio: CompetitiveObservationAudio,
  transcript = "A clear answer.",
  words: Array<Record<string, unknown>> = [
    {word: "A", start: 0, end: 0.1, confidence: 0.99},
    {word: "clear", start: 0.1, end: 0.3, confidence: 0.98},
    {word: "answer", start: 0.3, end: 0.7, confidence: 0.97},
  ]
): Record<string, unknown> {
  return {
    metadata: {
      request_id: requestID,
      sha256: audio.sha256,
      duration: audio.durationSeconds,
      channels: 1,
      models: [modelUUID],
      model_info: {
        [modelUUID]: {name: "nova-3", version: "2026-01-01"},
      },
    },
    results: {
      channels: [{alternatives: [{transcript, words}]}],
    },
  };
}

const numericDate = (value: unknown): number | null =>
  typeof value === "number" ? value : null;

test("begin request validates exact mode, demand, and prompt provenance", () => {
  const validated = validateBeginCompetitiveObservationRequest(
    validBeginRequest
  );
  assert.equal(validated.sessionID, sessionID.toUpperCase());
  assert.deepEqual(validated.demand, validBeginRequest.demand);
  assert.deepEqual(validated.promptProvenance, {
    source: "curated",
    promptDigest: promptSHA,
  });
});

test("begin accepts exact no-prompt and challenge bindings", () => {
  assert.doesNotThrow(() => validateBeginCompetitiveObservationRequest({
    ...validBeginRequest,
    mode: "ahCounter",
    demand: null,
    promptProvenance: {source: "none", promptDigest: null},
  }));
  const challenge = validateBeginCompetitiveObservationRequest({
    ...validBeginRequest,
    promptProvenance: {source: "challenge", promptDigest: promptSHA},
    challengeID,
  });
  assert.equal(challenge.challengeID, challengeID.toUpperCase());
});

test("begin rejects field smuggling and every invalid discriminator", () => {
  const invalid = [
    {...validBeginRequest, extra: true},
    {...validBeginRequest, schemaVersion: 2},
    {...validBeginRequest, sessionID: "not-a-uuid"},
    {...validBeginRequest, locale: "en-GB"},
    {...validBeginRequest, mode: "roleplay"},
    {...validBeginRequest, challengeID},
    {
      ...validBeginRequest,
      promptProvenance: {source: "challenge", promptDigest: promptSHA},
    },
    {
      ...validBeginRequest,
      promptProvenance: {source: "none", promptDigest: promptSHA},
    },
  ];
  for (const value of invalid) {
    assert.throws(() => validateBeginCompetitiveObservationRequest(value));
  }
});

test("begin enforces exact mode-demand coupling", () => {
  const invalidDemands = [
    {...validBeginRequest, demand: null},
    {
      ...validBeginRequest,
      mode: "suddenDeath",
      demand: validBeginRequest.demand,
    },
    {
      ...validBeginRequest,
      mode: "ahCounter",
      demand: validBeginRequest.demand,
    },
    {
      ...validBeginRequest,
      demand: {...validBeginRequest.demand, suddenDeathDifficulty: "hard"},
    },
  ];
  for (const value of invalidDemands) {
    assert.throws(() => validateBeginCompetitiveObservationRequest(value));
  }
  assert.doesNotThrow(() => validateBeginCompetitiveObservationRequest({
    ...validBeginRequest,
    mode: "suddenDeath",
    demand: {
      schemaVersion: 1,
      timedDifficulty: null,
      suddenDeathDifficulty: "hard",
      speechProjectID: null,
    },
  }));
});

test("speech project provenance must match a bounded Timed project", () => {
  assert.doesNotThrow(() => validateBeginCompetitiveObservationRequest({
    ...validBeginRequest,
    demand: {...validBeginRequest.demand, speechProjectID: "ice_breaker"},
    promptProvenance: {
      source: "speech-project",
      promptDigest: promptSHA,
    },
  }));
  assert.throws(() => validateBeginCompetitiveObservationRequest({
    ...validBeginRequest,
    promptProvenance: {
      source: "speech-project",
      promptDigest: promptSHA,
    },
  }));
  assert.throws(() => validateBeginCompetitiveObservationRequest({
    ...validBeginRequest,
    demand: {...validBeginRequest.demand, speechProjectID: "ice_breaker"},
  }));
});

test("complete derives PCM hash and duration without client metrics", () => {
  const bytes = pcm(64_000);
  const validated = validateCompleteCompetitiveObservationRequest(
    completeRequest(bytes)
  );
  assert.equal(validated.sessionID, sessionID.toUpperCase());
  assert.equal(validated.audio.bytes.length, 64_000);
  assert.equal(validated.audio.durationSeconds, 2);
  assert.equal(
    validated.audio.sha256,
    createHash("sha256").update(bytes).digest("hex")
  );
  assert.equal("transcript" in validated, false);
  assert.equal("score" in validated, false);
  assert.equal("fillerWordCount" in validated, false);
});

test("complete accepts exact 150-second PCM boundary", () => {
  const bytes = Buffer.alloc(COMPETITIVE_OBSERVATION_MAX_AUDIO_BYTES);
  const validated = validateCompleteCompetitiveObservationRequest(
    completeRequest(bytes)
  );
  assert.equal(validated.audio.durationSeconds, 150);
});

test("complete rejects noncanonical, short, odd, oversized, and extra audio", () => {
  const base = completeRequest();
  const audio = base.audio as Record<string, unknown>;
  const invalid = [
    {...base, score: 10},
    {...base, audio: {...audio, sampleRateHertz: 48_000}},
    {...base, audio: {...audio, channelCount: 2}},
    {...base, audio: {...audio, dataBase64: "AA=A"}},
    completeRequest(Buffer.alloc(COMPETITIVE_OBSERVATION_MIN_AUDIO_BYTES - 2)),
    completeRequest(Buffer.alloc(COMPETITIVE_OBSERVATION_MIN_AUDIO_BYTES + 1)),
    completeRequest(Buffer.alloc(COMPETITIVE_OBSERVATION_MAX_AUDIO_BYTES + 2)),
  ];
  for (const value of invalid) {
    assert.throws(() => validateCompleteCompetitiveObservationRequest(value));
  }
});

test("intent equality projects only request fields", () => {
  const validated = validateBeginCompetitiveObservationRequest(
    validBeginRequest
  );
  assert.equal(competitiveObservationIntentMatches(intent(), validated), true);
  assert.equal(competitiveObservationIntentMatches(
    intent(),
    {...validated, locale: "fr-FR"}
  ), false);
});

test("stored intent requires exact schema and coherent timestamps", () => {
  const stored = validateStoredCompetitiveObservationIntent(
    storedIntentDocument(),
    uid,
    sessionID.toUpperCase(),
    numericDate
  );
  assert.equal(stored.expiresAtMs, expiresAtMs);
  for (const bad of [
    storedIntentDocument({extra: true}),
    storedIntentDocument({expiresAt: expiresAtMs + 1}),
    storedIntentDocument({status: "observed"}),
    storedIntentDocument({competitiveEligible: true}),
  ]) {
    assert.throws(() => validateStoredCompetitiveObservationIntent(
      bad, uid, sessionID.toUpperCase(), numericDate
    ));
  }
});

test("intent usability rejects wrong owner, backdating, and expiry", () => {
  assert.doesNotThrow(() => assertCompetitiveObservationIntentUsable(
    intent(), uid, sessionID.toUpperCase(), startedAtMs
  ));
  assert.throws(() => assertCompetitiveObservationIntentUsable(
    intent(), "other-user", sessionID.toUpperCase(), startedAtMs
  ));
  assert.throws(() => assertCompetitiveObservationIntentUsable(
    intent(), uid, sessionID.toUpperCase(), startedAtMs - 1
  ));
  assert.throws(() => assertCompetitiveObservationIntentUsable(
    intent(), uid, sessionID.toUpperCase(), expiresAtMs + 1
  ));
});

test("per-UID audio digest claim has an exact replay schema", () => {
  const sha = "b".repeat(64);
  const document = {
    schemaVersion: 1,
    uid,
    sessionID: sessionID.toUpperCase(),
    audioSHA256: sha,
    claimedAt: startedAtMs,
    expiresAt: expiresAtMs,
  };
  assert.equal(validateStoredCompetitiveAudioDigestClaim(
    document, uid, sessionID.toUpperCase(), sha, numericDate
  ).audioSHA256, sha);
  assert.throws(() => validateStoredCompetitiveAudioDigestClaim(
    {...document, extra: true},
    uid,
    sessionID.toUpperCase(),
    sha,
    numericDate
  ));
});

test("Deepgram response validates audio, model, words, and transcript hash", () => {
  const audio = observationAudio();
  const result = validateDeepgramObservationResponse(
    deepgramResponse(audio),
    audio
  );
  assert.equal(result.transcript, "A clear answer.");
  assert.equal(result.wordCount, 3);
  assert.equal(result.providerAudioSHA256, audio.sha256);
  assert.equal(
    result.transcriptSHA256,
    createHash("sha256").update(result.transcript).digest("hex")
  );
});

test("valid provider silence stays empty and never manufactures words", () => {
  const audio = observationAudio();
  const result = validateDeepgramObservationResponse(
    deepgramResponse(audio, "", []),
    audio
  );
  assert.equal(result.transcript, "");
  assert.equal(result.wordCount, 0);
});

test("provider response rejects mismatched audio and unbounded output", () => {
  const audio = observationAudio();
  const wrongSHA = deepgramResponse(audio);
  (wrongSHA.metadata as Record<string, unknown>).sha256 = "c".repeat(64);
  assert.throws(
    () => validateDeepgramObservationResponse(wrongSHA, audio),
    DeepgramObservationError
  );
  const tooLong = "x".repeat(
    COMPETITIVE_OBSERVATION_MAX_TRANSCRIPT_CHARS + 1
  );
  assert.throws(() => validateDeepgramObservationResponse(
    deepgramResponse(audio, tooLong, []), audio
  ));
  const tooManyWords = Array.from(
    {length: COMPETITIVE_OBSERVATION_MAX_PROVIDER_WORDS + 1},
    () => ({word: "x", start: 0, end: 0.1, confidence: 1})
  );
  assert.throws(() => validateDeepgramObservationResponse(
    deepgramResponse(audio, "x", tooManyWords), audio
  ));
});

test("Deepgram adapter sends bounded private-model-improvement opt-out PCM", async () => {
  const audio = observationAudio();
  let capturedURL: URL | null = null;
  let capturedInit: RequestInit | undefined;
  const fetchImpl: typeof fetch = async (input, init) => {
    capturedURL = new URL(input.toString());
    capturedInit = init;
    return new Response(JSON.stringify(deepgramResponse(audio)), {
      status: 200,
      headers: {"content-type": "application/json"},
    });
  };
  const token = `${"a".repeat(24)}.${"b".repeat(24)}.${"c".repeat(24)}`;
  const result = await transcribeCompetitivePCM(
    token,
    "en-US",
    audio,
    {fetchImpl}
  );
  assert.equal(result.wordCount, 3);
  assert.notEqual(capturedURL, null);
  const sentURL = capturedURL as unknown as URL;
  assert.equal(sentURL.searchParams.get("mip_opt_out"), "true");
  assert.equal(sentURL.searchParams.get("encoding"), "linear16");
  assert.equal(sentURL.searchParams.get("sample_rate"), "16000");
  assert.equal(sentURL.searchParams.get("channels"), "1");
  assert.equal((capturedInit?.headers as Record<string, string>)[
    "content-type"
  ], "audio/raw");
  assert.equal((capturedInit?.body as Uint8Array).byteLength, audio.bytes.length);
});

test("Deepgram adapter maps network, HTTP, and token failures safely", async () => {
  const audio = observationAudio();
  const token = `${"a".repeat(24)}.${"b".repeat(24)}.${"c".repeat(24)}`;
  await assert.rejects(
    transcribeCompetitivePCM(token, "en-US", audio, {
      fetchImpl: async () => {
        throw new Error("secret provider detail");
      },
    }),
    (error: DeepgramObservationError) => error.reason === "network"
  );
  await assert.rejects(
    transcribeCompetitivePCM(token, "en-US", audio, {
      fetchImpl: async () => new Response("denied", {status: 401}),
    }),
    (error: DeepgramObservationError) => error.reason === "provider-http"
  );
  await assert.rejects(
    transcribeCompetitivePCM("not-a-token", "en-US", audio),
    (error: DeepgramObservationError) => error.reason === "configuration"
  );
});

test("complete orchestration orders claim, provider, and final commit", async () => {
  const audio = observationAudio();
  const boundIntent = intent(audio.sha256);
  const provider = providerObservation(audio);
  const order: string[] = [];
  const result = await completeCompetitiveObservationWork(completeRequest(), {
    claimAudio: async () => {
      order.push("claim");
      return boundIntent;
    },
    transcribe: async () => {
      order.push("provider");
      return provider;
    },
    commitObservation: async () => {
      order.push("commit");
      return {replayed: false};
    },
  });
  assert.deepEqual(order, ["claim", "provider", "commit"]);
  assert.equal(result.provider.transcript, "A clear answer.");
  assert.equal(result.replayed, false);
});

test("complete orchestration never calls provider after a failed claim", async () => {
  let providerCalled = false;
  await assert.rejects(completeCompetitiveObservationWork(completeRequest(), {
    claimAudio: async () => {
      throw new Error("deletion pending");
    },
    transcribe: async () => {
      providerCalled = true;
      return providerObservation(observationAudio());
    },
    commitObservation: async () => ({replayed: false}),
  }));
  assert.equal(providerCalled, false);
});

test("observation document is transcript-free and permanently ineligible", () => {
  const audio = observationAudio();
  const boundIntent = intent(audio.sha256);
  const provider = providerObservation(audio);
  const document = competitiveObservationDocument(
    boundIntent,
    audio,
    provider,
    startedAtMs + 1_000
  );
  assert.equal(document.competitiveEligible, false);
  assert.equal("transcript" in document, false);
  assert.equal("bytes" in document.audio, false);
  assert.equal(document.expiresAtMs, expiresAtMs);
  assert.equal(competitiveObservationRetryMatches(document, document), true);
  assert.equal(competitiveObservationRetryMatches(
    document,
    {...document, transcriptSHA256: "d".repeat(64)}
  ), false);
});

test("stored observation validator rejects extra and eligible state", () => {
  const audio = observationAudio();
  const document = competitiveObservationDocument(
    intent(audio.sha256),
    audio,
    providerObservation(audio),
    startedAtMs + 1_000
  );
  const stored = {
    ...document,
    startedAt: document.startedAtMs,
    expiresAt: document.expiresAtMs,
    observedAt: document.observedAtMs,
  } as Record<string, unknown>;
  delete stored.startedAtMs;
  delete stored.expiresAtMs;
  delete stored.observedAtMs;
  assert.equal(validateStoredCompetitiveObservation(
    stored, uid, sessionID.toUpperCase(), numericDate
  ).competitiveEligible, false);
  assert.throws(() => validateStoredCompetitiveObservation(
    {...stored, competitiveEligible: true},
    uid,
    sessionID.toUpperCase(),
    numericDate
  ));
  assert.throws(() => validateStoredCompetitiveObservation(
    {...stored, transcript: "private words"},
    uid,
    sessionID.toUpperCase(),
    numericDate
  ));
});
