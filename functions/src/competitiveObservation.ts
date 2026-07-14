/* eslint-disable valid-jsdoc, require-jsdoc */

import {createHash} from "node:crypto";
import {HttpsError} from "firebase-functions/v2/https";
import type {WindowRateState} from "./releaseSecurity.js";

export const COMPETITIVE_OBSERVATION_SCHEMA_VERSION = 1;
export const COMPETITIVE_OBSERVATION_INTENT_LIFETIME_MS = 10 * 60 * 1_000;
export const COMPETITIVE_OBSERVATION_SAMPLE_RATE_HERTZ = 16_000;
export const COMPETITIVE_OBSERVATION_CHANNEL_COUNT = 1;
export const COMPETITIVE_OBSERVATION_SAMPLE_WIDTH_BITS = 16;
export const COMPETITIVE_OBSERVATION_MAX_SECONDS = 150;
export const COMPETITIVE_OBSERVATION_MAX_AUDIO_BYTES = 4_800_000;
export const COMPETITIVE_OBSERVATION_MIN_AUDIO_BYTES = 8_000;
export const COMPETITIVE_OBSERVATION_MINUTE_LIMIT = 6;
export const COMPETITIVE_OBSERVATION_HOUR_LIMIT = 60;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA256_PATTERN = /^[0-9a-f]{64}$/;
const PROJECT_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$/;
export const COMPETITIVE_OBSERVATION_MAX_TRANSCRIPT_CHARS = 12_000;
export const COMPETITIVE_OBSERVATION_MAX_PROVIDER_WORDS = 3_000;
const MAX_PROVIDER_RESPONSE_BYTES = 2 * 1024 * 1024;
const DEEPGRAM_LISTEN_URL = "https://api.deepgram.com/v1/listen";

export type CompetitiveObservationLocale = "en-US" | "es-ES" | "fr-FR";
export type CompetitiveObservationMode =
  "timed" | "suddenDeath" | "ahCounter" | "imConversation";
export type CompetitivePromptSource =
  "none" | "curated" | "ai-generated" | "user-authored" |
  "speech-project" | "challenge";

export interface CompetitiveObservationDemand {
  schemaVersion: 1;
  timedDifficulty: "free" | "easy" | "medium" | "hard" | null;
  suddenDeathDifficulty: "easy" | "medium" | "hard" | null;
  speechProjectID: string | null;
}

export interface CompetitivePromptProvenance {
  source: CompetitivePromptSource;
  promptDigest: string | null;
}

export interface BeginCompetitiveObservationInput {
  schemaVersion: 1;
  sessionID: string;
  locale: CompetitiveObservationLocale;
  mode: CompetitiveObservationMode;
  demand: CompetitiveObservationDemand | null;
  promptProvenance: CompetitivePromptProvenance;
  challengeID: string | null;
}

export interface CompetitiveObservationAudio {
  encoding: "linear16";
  sampleRateHertz: 16_000;
  channelCount: 1;
  sampleWidthBits: 16;
  bytes: Buffer;
  sha256: string;
  durationSeconds: number;
}

export interface CompleteCompetitiveObservationInput {
  schemaVersion: 1;
  sessionID: string;
  audio: CompetitiveObservationAudio;
}

export interface StoredCompetitiveObservationIntent
  extends BeginCompetitiveObservationInput {
  uid: string;
  status: "pending" | "observed";
  competitiveEligible: false;
  audioSHA256: string | null;
  startedAtMs: number;
  expiresAtMs: number;
  observationCompletedAtMs: number | null;
}

export interface StoredCompetitiveAudioDigestClaim {
  schemaVersion: 1;
  uid: string;
  sessionID: string;
  audioSHA256: string;
  claimedAtMs: number;
  expiresAtMs: number;
}

export interface DeepgramCompetitiveObservation {
  transcript: string;
  transcriptSHA256: string;
  wordCount: number;
  providerRequestID: string;
  providerAudioSHA256: string;
  providerDurationSeconds: number;
  modelUUID: string;
  modelName: string;
  modelVersion: string;
}

export interface StoredCompetitiveObservation {
  schemaVersion: 1;
  uid: string;
  sessionID: string;
  observationSource: "noum-server-observer-v1";
  competitiveEligible: false;
  locale: CompetitiveObservationLocale;
  mode: CompetitiveObservationMode;
  demand: CompetitiveObservationDemand | null;
  promptProvenance: CompetitivePromptProvenance;
  challengeID: string | null;
  audio: {
    encoding: "linear16";
    sampleRateHertz: 16_000;
    channelCount: 1;
    sampleWidthBits: 16;
    byteCount: number;
    durationSeconds: number;
    sha256: string;
  };
  provider: {
    name: "deepgram";
    requestID: string;
    audioSHA256: string;
    durationSeconds: number;
    modelUUID: string;
    modelName: string;
    modelVersion: string;
  };
  transcriptSHA256: string;
  wordCount: number;
  startedAtMs: number;
  expiresAtMs: number;
  observedAtMs: number;
}

export interface CompleteCompetitiveObservationResult {
  input: CompleteCompetitiveObservationInput;
  intent: StoredCompetitiveObservationIntent;
  provider: DeepgramCompetitiveObservation;
  replayed: boolean;
}

export interface CompleteCompetitiveObservationDependencies {
  claimAudio: (
    input: CompleteCompetitiveObservationInput
  ) => Promise<StoredCompetitiveObservationIntent>;
  transcribe: (
    intent: StoredCompetitiveObservationIntent,
    audio: CompetitiveObservationAudio
  ) => Promise<DeepgramCompetitiveObservation>;
  commitObservation: (
    intent: StoredCompetitiveObservationIntent,
    audio: CompetitiveObservationAudio,
    provider: DeepgramCompetitiveObservation
  ) => Promise<{replayed: boolean}>;
}

export type CompetitiveObservationRateState = Partial<WindowRateState>;

export type DeepgramObservationFailure =
  "configuration" | "network" | "provider-http" | "provider-response";

export class DeepgramObservationError extends Error {
  constructor(readonly reason: DeepgramObservationFailure) {
    super("Competitive speech observation unavailable.");
    this.name = "DeepgramObservationError";
  }
}

export interface DeepgramObservationDependencies {
  fetchImpl?: typeof fetch;
  signal?: AbortSignal;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasExactKeys(
  value: Record<string, unknown>,
  expected: readonly string[]
): boolean {
  const actual = Object.keys(value).sort();
  const sortedExpected = [...expected].sort();
  return actual.length === sortedExpected.length &&
    actual.every((key, index) => key === sortedExpected[index]);
}

function normalizedUUID(value: unknown, label: string): string {
  if (typeof value !== "string" || !UUID_PATTERN.test(value)) {
    throw new HttpsError("invalid-argument", `Invalid ${label}.`);
  }
  return value.toUpperCase();
}

function normalizedSHA256(value: unknown, label: string): string {
  if (typeof value !== "string" || !SHA256_PATTERN.test(value)) {
    throw new HttpsError("invalid-argument", `Invalid ${label}.`);
  }
  return value;
}

function validateDemand(
  value: unknown,
  mode: CompetitiveObservationMode
): CompetitiveObservationDemand | null {
  if (value === null) {
    if (mode === "timed" || mode === "suddenDeath") {
      throw new HttpsError("invalid-argument", "Practice demand is required.");
    }
    return null;
  }
  if (!isRecord(value) || value.schemaVersion !== 1 ||
      !hasExactKeys(value, [
        "schemaVersion", "timedDifficulty", "suddenDeathDifficulty",
        "speechProjectID",
      ])) {
    throw new HttpsError("invalid-argument", "Invalid practice demand.");
  }
  const timedDifficulty = value.timedDifficulty;
  const suddenDeathDifficulty = value.suddenDeathDifficulty;
  const speechProjectID = value.speechProjectID;
  const validTimed = timedDifficulty === "free" || timedDifficulty === "easy" ||
    timedDifficulty === "medium" || timedDifficulty === "hard";
  const validSuddenDeath = suddenDeathDifficulty === "easy" ||
    suddenDeathDifficulty === "medium" || suddenDeathDifficulty === "hard";
  const validProject = speechProjectID === null ||
    (typeof speechProjectID === "string" &&
      PROJECT_ID_PATTERN.test(speechProjectID));
  if (!validProject) {
    throw new HttpsError("invalid-argument", "Invalid practice demand.");
  }
  if (mode === "timed" && validTimed && suddenDeathDifficulty === null) {
    return {
      schemaVersion: 1,
      timedDifficulty,
      suddenDeathDifficulty: null,
      speechProjectID: speechProjectID as string | null,
    };
  }
  if (mode === "suddenDeath" && timedDifficulty === null &&
      validSuddenDeath && speechProjectID === null) {
    return {
      schemaVersion: 1,
      timedDifficulty: null,
      suddenDeathDifficulty,
      speechProjectID: null,
    };
  }
  throw new HttpsError("invalid-argument", "Invalid practice demand.");
}

function validatePromptProvenance(
  value: unknown,
  demand: CompetitiveObservationDemand | null,
  challengeID: string | null
): CompetitivePromptProvenance {
  if (!isRecord(value) || !hasExactKeys(value, ["source", "promptDigest"])) {
    throw new HttpsError("invalid-argument", "Invalid prompt provenance.");
  }
  const source = value.source;
  const allowed: CompetitivePromptSource[] = [
    "none", "curated", "ai-generated", "user-authored",
    "speech-project", "challenge",
  ];
  if (typeof source !== "string" ||
      !allowed.includes(source as CompetitivePromptSource)) {
    throw new HttpsError("invalid-argument", "Invalid prompt provenance.");
  }
  if (source === "none") {
    if (value.promptDigest !== null || challengeID !== null) {
      throw new HttpsError("invalid-argument", "Invalid prompt provenance.");
    }
    return {source: "none", promptDigest: null};
  }
  const promptDigest = normalizedSHA256(value.promptDigest, "prompt digest");
  if ((source === "challenge") !== (challengeID !== null)) {
    throw new HttpsError("invalid-argument", "Invalid challenge binding.");
  }
  if (source === "speech-project" && !demand?.speechProjectID) {
    throw new HttpsError("invalid-argument", "Invalid project binding.");
  }
  if (source !== "speech-project" && demand?.speechProjectID) {
    throw new HttpsError("invalid-argument", "Invalid project binding.");
  }
  return {source: source as CompetitivePromptSource, promptDigest};
}

export function validateBeginCompetitiveObservationRequest(
  data: unknown
): BeginCompetitiveObservationInput {
  if (!isRecord(data) || data.schemaVersion !== 1 ||
      !hasExactKeys(data, [
        "schemaVersion", "sessionID", "locale", "mode", "demand",
        "promptProvenance", "challengeID",
      ])) {
    throw new HttpsError("invalid-argument", "Invalid observation request.");
  }
  if (data.locale !== "en-US" && data.locale !== "es-ES" &&
      data.locale !== "fr-FR") {
    throw new HttpsError("invalid-argument", "Unsupported practice locale.");
  }
  if (data.mode !== "timed" && data.mode !== "suddenDeath" &&
      data.mode !== "ahCounter" && data.mode !== "imConversation") {
    throw new HttpsError("invalid-argument", "Unsupported practice mode.");
  }
  const challengeID = data.challengeID === null ? null :
    normalizedUUID(data.challengeID, "challenge ID");
  const demand = validateDemand(data.demand, data.mode);
  const promptProvenance = validatePromptProvenance(
    data.promptProvenance,
    demand,
    challengeID
  );
  return {
    schemaVersion: 1,
    sessionID: normalizedUUID(data.sessionID, "session ID"),
    locale: data.locale,
    mode: data.mode,
    demand,
    promptProvenance,
    challengeID,
  };
}

function isBase64Character(code: number): boolean {
  return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) ||
    (code >= 48 && code <= 57) || code === 43 || code === 47;
}

function hasCanonicalBase64Shape(value: string): boolean {
  if (value.length === 0 || value.length % 4 !== 0) return false;
  const firstPadding = value.indexOf("=");
  const payloadEnd = firstPadding === -1 ? value.length : firstPadding;
  const paddingCount = value.length - payloadEnd;
  if (paddingCount > 2) return false;
  for (let index = 0; index < payloadEnd; index += 1) {
    if (!isBase64Character(value.charCodeAt(index))) return false;
  }
  for (let index = payloadEnd; index < value.length; index += 1) {
    if (value.charCodeAt(index) !== 61) return false;
  }
  return true;
}

function decodeCanonicalAudio(value: string): Buffer {
  const maximumBase64Length = Math.ceil(
    COMPETITIVE_OBSERVATION_MAX_AUDIO_BYTES / 3
  ) * 4;
  if (value.length > maximumBase64Length ||
      !hasCanonicalBase64Shape(value)) {
    throw new HttpsError("invalid-argument", "Invalid audio payload.");
  }
  const bytes = Buffer.from(value, "base64");
  if (bytes.toString("base64") !== value ||
      bytes.length < COMPETITIVE_OBSERVATION_MIN_AUDIO_BYTES ||
      bytes.length > COMPETITIVE_OBSERVATION_MAX_AUDIO_BYTES ||
      bytes.length % 2 !== 0) {
    throw new HttpsError("invalid-argument", "Invalid audio payload.");
  }
  return bytes;
}

export function validateCompleteCompetitiveObservationRequest(
  data: unknown
): CompleteCompetitiveObservationInput {
  if (!isRecord(data) || data.schemaVersion !== 1 ||
      !hasExactKeys(data, ["schemaVersion", "sessionID", "audio"]) ||
      !isRecord(data.audio) || !hasExactKeys(data.audio, [
    "encoding", "sampleRateHertz", "channelCount", "sampleWidthBits",
    "dataBase64",
  ]) || data.audio.encoding !== "linear16" ||
      data.audio.sampleRateHertz !== 16_000 ||
      data.audio.channelCount !== 1 || data.audio.sampleWidthBits !== 16 ||
      typeof data.audio.dataBase64 !== "string") {
    throw new HttpsError("invalid-argument", "Invalid observation audio.");
  }
  const bytes = decodeCanonicalAudio(data.audio.dataBase64);
  return {
    schemaVersion: 1,
    sessionID: normalizedUUID(data.sessionID, "session ID"),
    audio: {
      encoding: "linear16",
      sampleRateHertz: 16_000,
      channelCount: 1,
      sampleWidthBits: 16,
      bytes,
      sha256: createHash("sha256").update(bytes).digest("hex"),
      durationSeconds: bytes.length /
        (COMPETITIVE_OBSERVATION_SAMPLE_RATE_HERTZ * 2),
    },
  };
}

export function competitiveObservationIntentMatches(
  stored: BeginCompetitiveObservationInput,
  requested: BeginCompetitiveObservationInput
): boolean {
  const storedRequest: BeginCompetitiveObservationInput = {
    schemaVersion: stored.schemaVersion,
    sessionID: stored.sessionID,
    locale: stored.locale,
    mode: stored.mode,
    demand: stored.demand,
    promptProvenance: stored.promptProvenance,
    challengeID: stored.challengeID,
  };
  return JSON.stringify(storedRequest) === JSON.stringify(requested);
}

export function assertCompetitiveObservationIntentUsable(
  intent: StoredCompetitiveObservationIntent,
  uid: string,
  sessionID: string,
  nowMs: number
): void {
  if (intent.uid !== uid || intent.sessionID !== sessionID ||
      intent.schemaVersion !== 1 || intent.competitiveEligible !== false) {
    throw new HttpsError(
      "failed-precondition",
      "Observation intent unavailable."
    );
  }
  if (!Number.isFinite(nowMs) || nowMs < intent.startedAtMs ||
      nowMs > intent.expiresAtMs) {
    throw new HttpsError("deadline-exceeded", "Observation intent expired.");
  }
}

export type CompetitiveObservationDateMilliseconds = (
  value: unknown
) => number | null;

export function validateStoredCompetitiveAudioDigestClaim(
  value: unknown,
  expectedUID: string,
  expectedSessionID: string,
  expectedSHA256: string,
  dateMilliseconds: CompetitiveObservationDateMilliseconds
): StoredCompetitiveAudioDigestClaim {
  if (!isRecord(value) || !hasExactKeys(value, [
    "schemaVersion", "uid", "sessionID", "audioSHA256", "claimedAt",
    "expiresAt",
  ]) || value.schemaVersion !== 1 || value.uid !== expectedUID ||
      value.sessionID !== expectedSessionID ||
      value.audioSHA256 !== expectedSHA256 ||
      !SHA256_PATTERN.test(expectedSHA256)) {
    throw new HttpsError("data-loss", "Audio replay claim is invalid.");
  }
  const claimedAtMs = dateMilliseconds(value.claimedAt);
  const expiresAtMs = dateMilliseconds(value.expiresAt);
  if (claimedAtMs === null || expiresAtMs === null ||
      claimedAtMs > expiresAtMs) {
    throw new HttpsError("data-loss", "Audio replay claim is invalid.");
  }
  return {
    schemaVersion: 1,
    uid: expectedUID,
    sessionID: expectedSessionID,
    audioSHA256: expectedSHA256,
    claimedAtMs,
    expiresAtMs,
  };
}

export function validateStoredCompetitiveObservationIntent(
  value: unknown,
  expectedUID: string,
  expectedSessionID: string,
  dateMilliseconds: CompetitiveObservationDateMilliseconds
): StoredCompetitiveObservationIntent {
  if (!isRecord(value) || !hasExactKeys(value, [
    "schemaVersion", "uid", "sessionID", "locale", "mode", "demand",
    "promptProvenance", "challengeID", "status", "competitiveEligible",
    "audioSHA256", "startedAt", "expiresAt", "updatedAt",
    "observationCompletedAt",
  ]) || value.schemaVersion !== 1 || value.uid !== expectedUID ||
      value.competitiveEligible !== false ||
      (value.status !== "pending" && value.status !== "observed") ||
      !(value.audioSHA256 === null ||
        (typeof value.audioSHA256 === "string" &&
          SHA256_PATTERN.test(value.audioSHA256)))) {
    throw new HttpsError(
      "failed-precondition",
      "Observation intent unavailable."
    );
  }
  const request = validateBeginCompetitiveObservationRequest({
    schemaVersion: value.schemaVersion,
    sessionID: value.sessionID,
    locale: value.locale,
    mode: value.mode,
    demand: value.demand,
    promptProvenance: value.promptProvenance,
    challengeID: value.challengeID,
  });
  if (request.sessionID !== expectedSessionID) {
    throw new HttpsError(
      "failed-precondition",
      "Observation intent unavailable."
    );
  }
  const startedAtMs = dateMilliseconds(value.startedAt);
  const expiresAtMs = dateMilliseconds(value.expiresAt);
  const updatedAtMs = dateMilliseconds(value.updatedAt);
  const observationCompletedAtMs = value.observationCompletedAt === null ?
    null : dateMilliseconds(value.observationCompletedAt);
  if (startedAtMs === null || expiresAtMs === null || updatedAtMs === null ||
      expiresAtMs - startedAtMs !==
        COMPETITIVE_OBSERVATION_INTENT_LIFETIME_MS ||
      updatedAtMs < startedAtMs || updatedAtMs > expiresAtMs ||
      (value.status === "pending" && observationCompletedAtMs !== null) ||
      (value.status === "observed" &&
        (observationCompletedAtMs === null || value.audioSHA256 === null))) {
    throw new HttpsError(
      "failed-precondition",
      "Observation intent unavailable."
    );
  }
  return {
    ...request,
    uid: expectedUID,
    status: value.status,
    competitiveEligible: false,
    audioSHA256: value.audioSHA256,
    startedAtMs,
    expiresAtMs,
    observationCompletedAtMs,
  };
}

export function competitiveObservationDocument(
  intent: StoredCompetitiveObservationIntent,
  audio: CompetitiveObservationAudio,
  provider: DeepgramCompetitiveObservation,
  observedAtMs: number
): StoredCompetitiveObservation {
  assertCompetitiveObservationIntentUsable(
    intent,
    intent.uid,
    intent.sessionID,
    observedAtMs
  );
  if (intent.audioSHA256 !== audio.sha256 ||
      provider.providerAudioSHA256 !== audio.sha256 ||
      !Number.isFinite(observedAtMs)) {
    throw new HttpsError("failed-precondition", "Observation binding changed.");
  }
  return {
    schemaVersion: 1,
    uid: intent.uid,
    sessionID: intent.sessionID,
    observationSource: "noum-server-observer-v1",
    competitiveEligible: false,
    locale: intent.locale,
    mode: intent.mode,
    demand: intent.demand,
    promptProvenance: intent.promptProvenance,
    challengeID: intent.challengeID,
    audio: {
      encoding: "linear16",
      sampleRateHertz: 16_000,
      channelCount: 1,
      sampleWidthBits: 16,
      byteCount: audio.bytes.length,
      durationSeconds: audio.durationSeconds,
      sha256: audio.sha256,
    },
    provider: {
      name: "deepgram",
      requestID: provider.providerRequestID,
      audioSHA256: provider.providerAudioSHA256,
      durationSeconds: provider.providerDurationSeconds,
      modelUUID: provider.modelUUID,
      modelName: provider.modelName,
      modelVersion: provider.modelVersion,
    },
    transcriptSHA256: provider.transcriptSHA256,
    wordCount: provider.wordCount,
    startedAtMs: intent.startedAtMs,
    expiresAtMs: intent.expiresAtMs,
    observedAtMs,
  };
}

export function competitiveObservationRetryMatches(
  stored: StoredCompetitiveObservation,
  candidate: StoredCompetitiveObservation
): boolean {
  return stored.uid === candidate.uid &&
    stored.sessionID === candidate.sessionID &&
    stored.observationSource === candidate.observationSource &&
    stored.competitiveEligible === false &&
    stored.audio.sha256 === candidate.audio.sha256 &&
    stored.audio.byteCount === candidate.audio.byteCount &&
    stored.transcriptSHA256 === candidate.transcriptSHA256 &&
    stored.wordCount === candidate.wordCount &&
    stored.provider.audioSHA256 === candidate.provider.audioSHA256 &&
    stored.provider.modelUUID === candidate.provider.modelUUID &&
    stored.provider.modelName === candidate.provider.modelName &&
    stored.provider.modelVersion === candidate.provider.modelVersion;
}

export function validateStoredCompetitiveObservation(
  value: unknown,
  expectedUID: string,
  expectedSessionID: string,
  dateMilliseconds: CompetitiveObservationDateMilliseconds
): StoredCompetitiveObservation {
  if (!isRecord(value) || !hasExactKeys(value, [
    "schemaVersion", "uid", "sessionID", "observationSource",
    "competitiveEligible", "locale", "mode", "demand",
    "promptProvenance", "challengeID", "audio", "provider",
    "transcriptSHA256", "wordCount", "startedAt", "expiresAt",
    "observedAt",
  ]) || value.schemaVersion !== 1 || value.uid !== expectedUID ||
      value.observationSource !== "noum-server-observer-v1" ||
      value.competitiveEligible !== false || !isRecord(value.audio) ||
      !isRecord(value.provider)) {
    throw new HttpsError("data-loss", "Stored observation is invalid.");
  }
  const request = validateBeginCompetitiveObservationRequest({
    schemaVersion: value.schemaVersion,
    sessionID: value.sessionID,
    locale: value.locale,
    mode: value.mode,
    demand: value.demand,
    promptProvenance: value.promptProvenance,
    challengeID: value.challengeID,
  });
  const audio = value.audio;
  const provider = value.provider;
  const byteCount = audio.byteCount;
  const durationSeconds = audio.durationSeconds;
  const providerDurationSeconds = provider.durationSeconds;
  const wordCount = value.wordCount;
  const transcriptSHA256 = value.transcriptSHA256;
  const startedAtMs = dateMilliseconds(value.startedAt);
  const expiresAtMs = dateMilliseconds(value.expiresAt);
  const observedAtMs = dateMilliseconds(value.observedAt);
  if (request.sessionID !== expectedSessionID ||
      !hasExactKeys(audio, [
        "encoding", "sampleRateHertz", "channelCount", "sampleWidthBits",
        "byteCount", "durationSeconds", "sha256",
      ]) || audio.encoding !== "linear16" ||
      audio.sampleRateHertz !== 16_000 || audio.channelCount !== 1 ||
      audio.sampleWidthBits !== 16 || !Number.isInteger(byteCount) ||
      (byteCount as number) < COMPETITIVE_OBSERVATION_MIN_AUDIO_BYTES ||
      (byteCount as number) > COMPETITIVE_OBSERVATION_MAX_AUDIO_BYTES ||
      (byteCount as number) % 2 !== 0 ||
      typeof durationSeconds !== "number" ||
      !Number.isFinite(durationSeconds) ||
      durationSeconds !== (byteCount as number) / 32_000 ||
      typeof audio.sha256 !== "string" || !SHA256_PATTERN.test(audio.sha256) ||
      !hasExactKeys(provider, [
        "name", "requestID", "audioSHA256", "durationSeconds", "modelUUID",
        "modelName", "modelVersion",
      ]) || provider.name !== "deepgram" ||
      typeof provider.requestID !== "string" ||
      !UUID_PATTERN.test(provider.requestID) ||
      provider.audioSHA256 !== audio.sha256 ||
      typeof providerDurationSeconds !== "number" ||
      !Number.isFinite(providerDurationSeconds) ||
      Math.abs(providerDurationSeconds - durationSeconds) >
        Math.max(0.1, durationSeconds * 0.02) ||
      typeof provider.modelUUID !== "string" ||
      !UUID_PATTERN.test(provider.modelUUID) ||
      !boundedProviderString(provider.modelName, 128) ||
      !boundedProviderString(provider.modelVersion, 128) ||
      typeof transcriptSHA256 !== "string" ||
      !SHA256_PATTERN.test(transcriptSHA256) ||
      typeof wordCount !== "number" || !Number.isInteger(wordCount) ||
      wordCount < 0 ||
      wordCount > COMPETITIVE_OBSERVATION_MAX_PROVIDER_WORDS ||
      startedAtMs === null || expiresAtMs === null || observedAtMs === null ||
      expiresAtMs - startedAtMs !==
        COMPETITIVE_OBSERVATION_INTENT_LIFETIME_MS ||
      observedAtMs < startedAtMs || observedAtMs > expiresAtMs) {
    throw new HttpsError("data-loss", "Stored observation is invalid.");
  }
  return {
    schemaVersion: 1,
    uid: expectedUID,
    sessionID: request.sessionID,
    observationSource: "noum-server-observer-v1",
    competitiveEligible: false,
    locale: request.locale,
    mode: request.mode,
    demand: request.demand,
    promptProvenance: request.promptProvenance,
    challengeID: request.challengeID,
    audio: {
      encoding: "linear16",
      sampleRateHertz: 16_000,
      channelCount: 1,
      sampleWidthBits: 16,
      byteCount: byteCount as number,
      durationSeconds,
      sha256: audio.sha256,
    },
    provider: {
      name: "deepgram",
      requestID: provider.requestID.toUpperCase(),
      audioSHA256: provider.audioSHA256 as string,
      durationSeconds: providerDurationSeconds,
      modelUUID: provider.modelUUID.toUpperCase(),
      modelName: provider.modelName as string,
      modelVersion: provider.modelVersion as string,
    },
    transcriptSHA256,
    wordCount,
    startedAtMs,
    expiresAtMs,
    observedAtMs,
  };
}

function boundedProviderString(
  value: unknown,
  maximum: number
): string | null {
  if (typeof value !== "string" || value !== value.trim() ||
      value.length < 1 || value.length > maximum) return null;
  return value;
}

export function validateDeepgramObservationResponse(
  value: unknown,
  audio: CompetitiveObservationAudio
): DeepgramCompetitiveObservation {
  if (!isRecord(value) || !isRecord(value.metadata) ||
      !isRecord(value.results)) {
    throw new DeepgramObservationError("provider-response");
  }
  const metadata = value.metadata;
  const requestID = boundedProviderString(metadata.request_id, 128);
  const providerAudioSHA256 = boundedProviderString(metadata.sha256, 64);
  const providerDuration = metadata.duration;
  const models = metadata.models;
  const modelInfo = metadata.model_info;
  const channels = value.results.channels;
  if (!requestID || !UUID_PATTERN.test(requestID) ||
      !providerAudioSHA256 || !SHA256_PATTERN.test(providerAudioSHA256) ||
      providerAudioSHA256 !== audio.sha256 ||
      typeof providerDuration !== "number" ||
      !Number.isFinite(providerDuration) || providerDuration <= 0 ||
      Math.abs(providerDuration - audio.durationSeconds) >
        Math.max(0.1, audio.durationSeconds * 0.02) ||
      metadata.channels !== 1 || !Array.isArray(models) ||
      models.length !== 1 || typeof models[0] !== "string" ||
      !UUID_PATTERN.test(models[0]) || !isRecord(modelInfo) ||
      !Array.isArray(channels) || channels.length !== 1 ||
      !isRecord(channels[0]) || !Array.isArray(channels[0].alternatives) ||
      channels[0].alternatives.length < 1 ||
      !isRecord(channels[0].alternatives[0])) {
    throw new DeepgramObservationError("provider-response");
  }
  const modelUUID = models[0];
  const model = modelInfo[modelUUID];
  const alternative = channels[0].alternatives[0];
  if (!isRecord(model) || typeof alternative.transcript !== "string" ||
      alternative.transcript.length >
        COMPETITIVE_OBSERVATION_MAX_TRANSCRIPT_CHARS ||
      !Array.isArray(alternative.words) ||
      alternative.words.length > COMPETITIVE_OBSERVATION_MAX_PROVIDER_WORDS) {
    throw new DeepgramObservationError("provider-response");
  }
  const modelName = boundedProviderString(model.name, 128);
  const modelVersion = boundedProviderString(model.version, 128);
  if (!modelName || !modelVersion) {
    throw new DeepgramObservationError("provider-response");
  }
  for (const word of alternative.words) {
    if (!isRecord(word) || !boundedProviderString(word.word, 256) ||
        typeof word.start !== "number" || !Number.isFinite(word.start) ||
        word.start < 0 || typeof word.end !== "number" ||
        !Number.isFinite(word.end) || word.end < word.start ||
        word.end > providerDuration + 0.1 ||
        typeof word.confidence !== "number" ||
        !Number.isFinite(word.confidence) || word.confidence < 0 ||
        word.confidence > 1) {
      throw new DeepgramObservationError("provider-response");
    }
  }
  const transcript = alternative.transcript.trim();
  return {
    transcript,
    transcriptSHA256: createHash("sha256")
      .update(transcript, "utf8").digest("hex"),
    wordCount: alternative.words.length,
    providerRequestID: requestID.toUpperCase(),
    providerAudioSHA256,
    providerDurationSeconds: providerDuration,
    modelUUID: modelUUID.toUpperCase(),
    modelName,
    modelVersion,
  };
}

async function readBoundedProviderJSON(response: Response): Promise<unknown> {
  const declared = response.headers.get("content-length");
  if (declared !== null) {
    const count = Number(declared);
    if (!Number.isInteger(count) || count < 0 ||
        count > MAX_PROVIDER_RESPONSE_BYTES) {
      throw new DeepgramObservationError("provider-response");
    }
  }
  if (!response.body) {
    throw new DeepgramObservationError("provider-response");
  }
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  let done = false;
  while (!done) {
    const next = await reader.read();
    if (next.done) {
      done = true;
      continue;
    }
    total += next.value.byteLength;
    if (total > MAX_PROVIDER_RESPONSE_BYTES) {
      await reader.cancel();
      throw new DeepgramObservationError("provider-response");
    }
    chunks.push(next.value);
  }
  const bytes = Buffer.concat(chunks.map((chunk) => Buffer.from(chunk)), total);
  try {
    return JSON.parse(bytes.toString("utf8"));
  } catch {
    throw new DeepgramObservationError("provider-response");
  }
}

export async function transcribeCompetitivePCM(
  accessToken: string,
  locale: CompetitiveObservationLocale,
  audio: CompetitiveObservationAudio,
  dependencies: DeepgramObservationDependencies = {}
): Promise<DeepgramCompetitiveObservation> {
  const token = accessToken.trim();
  const jwtParts = token.split(".");
  if (token.length < 64 || token.length > 8_192 ||
      jwtParts.length !== 3 || jwtParts.some((part) =>
    part.length === 0 || !/^[A-Za-z0-9_-]+$/.test(part)
  )) {
    throw new DeepgramObservationError("configuration");
  }
  const url = new URL(DEEPGRAM_LISTEN_URL);
  url.searchParams.set("model", "nova-3");
  url.searchParams.set("language", locale);
  url.searchParams.set("encoding", "linear16");
  url.searchParams.set("sample_rate", "16000");
  url.searchParams.set("channels", "1");
  url.searchParams.set("smart_format", "true");
  url.searchParams.set("punctuate", "true");
  url.searchParams.set("mip_opt_out", "true");
  let response: Response;
  try {
    response = await (dependencies.fetchImpl ?? fetch)(url, {
      method: "POST",
      headers: {
        "authorization": `Bearer ${token}`,
        "content-type": "audio/raw",
      },
      body: new Uint8Array(audio.bytes),
      signal: dependencies.signal,
    });
  } catch {
    throw new DeepgramObservationError("network");
  }
  if (!response.ok) {
    throw new DeepgramObservationError("provider-http");
  }
  return validateDeepgramObservationResponse(
    await readBoundedProviderJSON(response),
    audio
  );
}

export async function completeCompetitiveObservationWork(
  data: unknown,
  dependencies: CompleteCompetitiveObservationDependencies
): Promise<CompleteCompetitiveObservationResult> {
  const input = validateCompleteCompetitiveObservationRequest(data);
  const intent = await dependencies.claimAudio(input);
  const provider = await dependencies.transcribe(intent, input.audio);
  const committed = await dependencies.commitObservation(
    intent,
    input.audio,
    provider
  );
  return {input, intent, provider, replayed: committed.replayed};
}
