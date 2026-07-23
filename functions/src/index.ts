import {GoogleGenAI} from "@google/genai";
import {randomUUID} from "node:crypto";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {
  getFirestore,
  FieldValue,
  Timestamp,
  type DocumentReference,
  type DocumentSnapshot,
  type QueryDocumentSnapshot,
  type QuerySnapshot,
} from "firebase-admin/firestore";
import {defineSecret, defineString} from "firebase-functions/params";
import {setGlobalOptions} from "firebase-functions/v2";
import {
  type CallableRequest,
  type CallableResponse,
  HttpsError,
  onCall,
  onRequest,
  type Request,
} from "firebase-functions/v2/https";
import type {Response} from "express";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {
  type CoachBrief,
  type CoachChatQualityTier,
  type CoachEvidenceStrength,
  type CoachEvidenceReadKind,
  type CoachLatestRepMetricProjection,
  type CoachLongitudinalMetricTrend,
  type CoachLongitudinalTrendProjection,
  type CoachMetricKind,
  type CoachResponseKind,
  type CoachTurnDepth,
  type CoachTurnIntent,
  type CoachVoice,
  COACH_POLICY_VERSION,
  coachBriefRetainsRecentMove,
  coachReplyPolicyIssue,
  coachReplyWithoutObserverPromise,
  coachSystemPolicyForRequest,
  coachTurnRequestsMove,
  projectedMetricEvidenceText,
  thinkingBudgetForQualityTier,
} from "./coachPolicy.js";
import {
  type LegacyCoachChatCompletionPayload,
  type LegacyCoachChatInput,
  generateLegacyCoachCompletion,
  validateLegacyCoachChatRequest,
} from "./legacyCoachV1.js";
import {
  ACCOUNT_DELETION_RECONCILIATION_BATCH_SIZE,
  ACCOUNT_DELETION_RECONCILIATION_MIN_AGE_MS,
  AccountDeletionPartialError,
  type AccountDeletionWork,
  accountDeletionLogMetadata,
  accountDeletionStateAdmission,
  assertAppleRevocationSupported,
  assertDeleteAccountRequestIdentity,
  assertRecentAuthentication,
  completedAccountDeletionTombstone,
  deletionAuthenticationTime,
  executeAccountDeletionPlan,
  grantDeepgramTranscriptionToken,
  nextWindowRateState,
  pendingAccountDeletionReconciliationCandidate,
  ProviderGrantError,
  TRANSCRIPTION_TOKEN_HOUR_LIMIT,
  TRANSCRIPTION_TOKEN_MINUTE_LIMIT,
  transcriptionTokenLogMetadata,
  validateDeleteAccountRequest,
  validateTranscriptionTokenRequest,
  type WindowRateState,
} from "./releaseSecurity.js";
import {
  CHALLENGE_LIFETIME_MS,
  CHALLENGE_CREATE_HOUR_LIMIT,
  CHALLENGE_CREATE_MINUTE_LIMIT,
  CHALLENGE_DOCUMENT_SCHEMA_VERSION,
  CHALLENGE_REACTION_HOUR_LIMIT,
  CHALLENGE_REACTION_MINUTE_LIMIT,
  LEAGUE_LIST_READ_HOUR_LIMIT,
  LEAGUE_LIST_READ_MINUTE_LIMIT,
  PEER_PROFILE_READ_HOUR_LIMIT,
  PEER_PROFILE_READ_MINUTE_LIMIT,
  SOCIAL_SCHEMA_VERSION,
  advanceSocialState,
  assertSocialReferenceCutoverComplete,
  assertEvidenceBoundToChallenge,
  challengeEnvelope,
  challengeSide,
  challengeSubmissionDocument,
  combinedChallengeDocument,
  currentTrustedLeagueBucket,
  friendLinkEnvelope,
  isSocialReferenceCutoverComplete,
  profileFromSocialState,
  promptDigest,
  socialDateMilliseconds,
  socialReferenceManifestIncludingChallenge,
  socialReferenceManifestIncludingFriend,
  socialReferenceManifestUpdatingLeagueMembership,
  stableLegacyUUID,
  storedSocialState,
  validateChallengeSubmission,
  validateCombinedChallengeResult,
  validateCreateChallengeRequest,
  validateCurrentFriendManifest,
  validateGetPeerProfileRequest,
  validateListLeagueMembersRequest,
  validateReciprocalFriendLinks,
  validateReciprocalFriendManifests,
  validateServerFriendLink,
  validateRecordPeerSessionRequest,
  validateSetChallengeReactionRequest,
  validateSocialReferenceManifest,
  validateStoredChallenge,
  validateStoredPublicProfile,
  validateSubmitChallengeResultRequest,
  validateVerifiedSessionEvidence,
  type ChallengeSubmission,
  type FriendLinkEnvelope,
  type PublicProfileEnvelope,
  type ValidatedFriendLinkPair,
} from "./socialAuthority.js";
import {
  assertRecommendationMutationIdentity,
  decideRecommendationMutation,
  normalizeStoredRecommendationState,
  validateRecommendationMutation,
} from "./recommendationState.js";
import {
  growthAggregatePeriodKey,
  validateGrowthAggregate,
} from "./growthAggregate.js";
import {
  APP_STORE_NOTIFICATION_MARKER_RETENTION_MILLISECONDS,
  AppStoreNotificationProcessingError,
  appStoreNotificationHTTPStatus,
  appStoreSignedPayload,
  createAppStoreNotificationVerifier,
  parseAppStoreNotificationConfiguration,
  verifyAndProjectAppStoreNotification,
  type AppStoreLifecycleProjection,
} from "./appStoreServerNotifications.js";
import {Environment} from "@apple/app-store-server-library";
import {
  COMPETITIVE_OBSERVATION_HOUR_LIMIT,
  COMPETITIVE_OBSERVATION_INTENT_LIFETIME_MS,
  COMPETITIVE_OBSERVATION_MINUTE_LIMIT,
  competitiveAudioReplayClaim,
  competitiveAudioReplayDigest,
  competitiveObservationDocument,
  competitiveObservationIntentMatches,
  competitiveObservationProcessingIntent,
  completeCompetitiveObservationWork,
  DeepgramObservationError,
  assertCompetitiveObservationIntentUsable,
  transcribeCompetitivePCM,
  validateBeginCompetitiveObservationRequest,
  validateStoredCompetitiveAudioReplayClaim,
  validateStoredCompetitiveObservationIntent,
  type CompetitiveObservationAudio,
  type CompetitiveObservationRateState,
  type DeepgramCompetitiveObservation,
  type StoredCompetitiveObservation,
  type StoredCompetitiveObservationIntent,
} from "./competitiveObservation.js";
import {
  FRIEND_INVITE_ACCEPT_HOUR_LIMIT,
  FRIEND_INVITE_ACCEPT_MINUTE_LIMIT,
  FRIEND_INVITE_CREATE_HOUR_LIMIT,
  FRIEND_INVITE_CREATE_MINUTE_LIMIT,
  FRIEND_INVITE_LIFETIME_MS,
  FRIEND_LINK_LIST_HOUR_LIMIT,
  FRIEND_LINK_LIST_MINUTE_LIMIT,
  FRIEND_LINK_REMOVE_HOUR_LIMIT,
  FRIEND_LINK_REMOVE_MINUTE_LIMIT,
  FRIEND_LINK_SCHEMA_VERSION,
  FRIENDSHIP_SCHEMA_VERSION,
  MAX_ACTIVE_FRIENDS,
  MAX_ACTIVE_FRIEND_INVITES,
  friendInviteDigest,
  generateFriendInviteSecret,
  validateAcceptFriendInviteRequest,
  validateBoundFriendInviteReference,
  validateCreateFriendInviteRequest,
  validateListFriendLinksRequest,
  validateRemoveFriendLinkRequest,
  validateStoredFriendInvite,
  validateStoredFriendInviteReference,
} from "./friendshipAuthority.js";

export {validateLegacyCoachChatRequest} from "./legacyCoachV1.js";

initializeApp();
setGlobalOptions({
  maxInstances: 10,
  region: "europe-west2",
});
const COACH_RUNTIME_SERVICE_ACCOUNT =
  "noum-coach-runtime@noum-d0b6f.iam.gserviceaccount.com";
const TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT =
  "noum-transcription-runtime@noum-d0b6f.iam.gserviceaccount.com";
const ACCOUNT_RUNTIME_SERVICE_ACCOUNT =
  "noum-account-runtime@noum-d0b6f.iam.gserviceaccount.com";
const RECOMMENDATION_RUNTIME_SERVICE_ACCOUNT =
  "noum-recommendation-runtime@noum-d0b6f.iam.gserviceaccount.com";
const GROWTH_RUNTIME_SERVICE_ACCOUNT =
  "noum-growth-runtime@noum-d0b6f.iam.gserviceaccount.com";
const APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT =
  "noum-appstore-notifications-runtime@noum-d0b6f.iam.gserviceaccount.com";
const SOCIAL_RUNTIME_SERVICE_ACCOUNT =
  "noum-social-runtime@noum-d0b6f.iam.gserviceaccount.com";

const coachModel = defineString("COACH_MODEL", {
  default: "gemini-2.5-flash",
  description: "GA Vertex model serving Fast Ask Noum replies.",
});
const coachUltraModel = defineString("COACH_ULTRA_MODEL", {
  default: "gemini-2.5-pro",
  description: "GA Vertex model serving Ultra Ask Noum replies.",
});
const vertexLocation = defineString("VERTEX_LOCATION", {
  default: "europe-west1",
  description: "Vertex region that serves the configured coach model.",
});
const deepgramManagementKey = defineSecret("DEEPGRAM_MANAGEMENT_KEY");
const appStoreRootCertificates = defineSecret(
  "APP_STORE_ROOT_CERTIFICATES_BASE64"
);
const appStoreAppAppleID = defineString("APP_STORE_APP_APPLE_ID", {
  default: "",
  description: "Numeric App Store app ID bound into Apple's JWS verifier.",
});
const appStoreProductionNotificationsEnabled = defineString(
  "APP_STORE_PRODUCTION_NOTIFICATIONS_ENABLED",
  {
    default: "false",
    description: "Exact true switch for verified production notifications.",
  }
);
const appStoreSandboxNotificationsEnabled = defineString(
  "APP_STORE_SANDBOX_NOTIFICATIONS_ENABLED",
  {
    default: "false",
    description: "Exact true switch for verified sandbox notifications.",
  }
);

const MAX_MESSAGES = 12;
const MAX_MESSAGE_CHARS = 4_000;
const MAX_CONTEXT_CHARS = 12_000;
const MAX_QUOTE_SOURCES = 4;
const MAX_QUOTE_SOURCE_CHARS = 600;
const MAX_TOTAL_CHARS = 32_000;
const MAX_ACCOUNT_ID_CHARS = 128;
const MINUTE_LIMIT = 5;
const HOUR_LIMIT = 30;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type WireRole = "user" | "assistant";

export interface CoachChatWireMessage {
  role: WireRole;
  content: string;
}

export interface CoachChatInput {
  schemaVersion: 2;
  accountID: string;
  requestID: string;
  surface: "text" | "live";
  qualityTier: CoachChatQualityTier;
  coachVoice: CoachVoice | null;
  turnDepth: CoachTurnDepth;
  turnIntent: CoachTurnIntent;
  responseKind: CoachResponseKind;
  coachingBrief: CoachBrief | null;
  verifiedQuoteSources: string[];
  coachingContext: string;
  messages: CoachChatWireMessage[];
}

export type CoachGenerationMode =
  | "model"
  | "model-rewrite"
  | "model-sanitized"
  | "deterministic-brief";

export interface RateDecision {
  allowed: boolean;
  state: WindowRateState;
}

export type CoachAccountBinding = "verified" | "legacy-auth-derived";

/**
 * Verifies the client account scope against Firebase Auth.
 * @param {Pick<CoachChatInput, "schemaVersion" | "accountID">} input Request.
 * @param {string} authenticatedUID Verified Firebase Auth UID.
 * @return {CoachAccountBinding} Content-free operational binding label.
 */
export function assertCoachAccountBinding(
  input: Pick<CoachChatInput, "schemaVersion" | "accountID">,
  authenticatedUID: string
): CoachAccountBinding {
  if (input.accountID !== authenticatedUID) {
    throw new HttpsError(
      "permission-denied",
      "Account binding does not match the secure session.",
      {reason: "coach-account-binding-mismatch"}
    );
  }
  return "verified";
}

/**
 * Rejects requests that do not carry both Firebase trust signals.
 * @param {unknown} auth Verified Firebase Auth data.
 * @param {unknown} app Verified Firebase App Check data.
 * @return {void}
 */
export function assertTrustedCaller(auth: unknown, app: unknown): void {
  if (!auth) {
    throw new HttpsError("unauthenticated", "A secure session is required.");
  }
  if (!app) {
    throw new HttpsError(
      "failed-precondition",
      "App verification is required."
    );
  }
}

/**
 * Returns whether Vertex completed the response without truncation.
 * @param {unknown} value Vertex finish reason.
 * @return {boolean} Whether the response is complete.
 */
export function isAcceptableFinishReason(value: unknown): boolean {
  return value === "STOP";
}

/**
 * Builds the content-free metadata envelope used by operational logs.
 * @param {object} input Safe request identifiers.
 * @param {string} model Serving model.
 * @param {string} finishReason Vertex finish reason.
 * @param {number|undefined} inputTokens Input token count.
 * @param {number|undefined} outputTokens Output token count.
 * @param {number} latencyMs End-to-end latency.
 * @param {string} status Operational status.
 * @param {CoachAccountBinding} accountBinding Admission provenance.
 * @return {Record<string, unknown>} Content-free log fields.
 */
export function coachCompletionLogMetadata(
  input: Pick<
    CoachChatInput,
    "schemaVersion" | "requestID" | "surface" | "qualityTier" |
    "turnIntent" | "responseKind" | "turnDepth"
  >,
  model: string,
  finishReason: string,
  inputTokens: number | undefined,
  outputTokens: number | undefined,
  latencyMs: number,
  status: string,
  accountBinding: CoachAccountBinding = "verified"
): Record<string, unknown> {
  return {
    requestID: input.requestID,
    surface: input.surface,
    qualityTier: input.qualityTier,
    turnIntent: input.turnIntent,
    responseKind: input.responseKind,
    turnDepth: input.turnDepth,
    model,
    policyVersion: COACH_POLICY_VERSION,
    accountBinding,
    finishReason,
    inputTokens,
    outputTokens,
    latencyMs,
    status,
  };
}

/**
 * Builds the content- and identity-free failure envelope for Ask Noum.
 * @param {CoachChatInput} input Validated request.
 * @param {string} model Serving model.
 * @param {number} latencyMs End-to-end latency.
 * @param {string} status Stable error code.
 * @param {CoachAccountBinding} accountBinding Admission provenance.
 * @param {Record<string, string>} failureDetails Allowlisted quality codes.
 * @return {Record<string, unknown>} Safe operational fields.
 */
export function coachFailureLogMetadata(
  input: Pick<
    CoachChatInput,
    "schemaVersion" | "requestID" | "surface" | "qualityTier" |
    "turnIntent" | "responseKind" | "turnDepth"
  >,
  model: string,
  latencyMs: number,
  status: string,
  accountBinding: CoachAccountBinding = "verified",
  failureDetails: unknown = {}
): Record<string, unknown> {
  const qualityMetadata = allowlistedCoachFailureQualityFields(failureDetails);
  return {
    requestID: input.requestID,
    surface: input.surface,
    qualityTier: input.qualityTier,
    turnIntent: input.turnIntent,
    responseKind: input.responseKind,
    turnDepth: input.turnDepth,
    model,
    policyVersion: COACH_POLICY_VERSION,
    accountBinding,
    latencyMs,
    status,
    ...qualityMetadata,
  };
}

const COACH_POLICY_ISSUE_CODES = new Set([
  "empty", "invented-quote", "internal-language", "invented-setting",
  "invented-mechanism", "generic-opener", "outcome-promise",
  "coach-observer-promise", "unverified-personal-read", "invented-action",
  "unsolicited-action", "deferred-repair", "non-coaching-prescription",
  "non-coaching-brief-leak", "invented-number", "missing-metric-read",
  "missing-trend-read", "word-limit", "sentence-limit",
  "missing-evidence-clarification", "repeated-sentence", "repeated-anchor",
  "repeated-action", "repeated-prior-action", "missing-evidence-bridge",
  "missing-move-grounding", "missing-evidence-grounding",
]);

/**
 * Extracts only server-owned categorical quality codes from a callable error.
 * Provider drafts, user content, error messages, and arbitrary detail values
 * never enter production logs.
 * @param {unknown} error Candidate callable error.
 * @return {Record<string, string>} Allowlisted content-free fields.
 */
export function coachFailureQualityMetadata(
  error: unknown
): Record<string, string> {
  if (!(error instanceof HttpsError) ||
      typeof error.details !== "object" || error.details === null) {
    return {};
  }
  return allowlistedCoachFailureQualityFields(error.details);
}

/**
 * Reduces any candidate details object to the closed quality-log vocabulary.
 * The reason must identify the quality path before a policy label is admitted.
 * @param {unknown} candidate Candidate detail object.
 * @return {Record<string, string>} Allowlisted content-free fields.
 */
function allowlistedCoachFailureQualityFields(
  candidate: unknown
): Record<string, string> {
  if (typeof candidate !== "object" || candidate === null) return {};
  const details = candidate as Record<string, unknown>;
  const metadata: Record<string, string> = {};
  if (details.reason !== "coach-quality-rejected") return metadata;
  metadata.failureReason = "coach-quality-rejected";
  if (typeof details.policyIssue === "string" &&
      COACH_POLICY_ISSUE_CODES.has(details.policyIssue)) {
    metadata.policyIssue = details.policyIssue;
  }
  return metadata;
}

/** Typed completion returned to the iOS callable client. */
export interface CoachChatCompletionPayload {
  requestID: string;
  text: string;
  model: string;
  policyVersion: string;
  qualityTier: CoachChatQualityTier;
  generationMode: CoachGenerationMode;
  finishReason: string;
  inputTokens: number | undefined;
  outputTokens: number | undefined;
}

/** Minimal Gen AI response shape retained as the deterministic test seam. */
export interface CoachGenerateContentResponse {
  candidates?: Array<{
    content?: {parts?: Array<{text?: string}>};
    finishReason?: string;
  }>;
  usageMetadata?: {
    promptTokenCount?: number;
    candidatesTokenCount?: number;
  };
}

/** Injected stream I/O used by production Vertex and deterministic tests. */
export interface CoachStreamDependencies {
  generate: () => Promise<AsyncIterable<CoachGenerateContentResponse>>;
  sendDelta?: (chunk: {
    type: "delta";
    requestID: string;
    text: string;
  }) => Promise<unknown>;
  signal?: AbortSignal;
}

export interface VertexContent {
  role: "user" | "model";
  parts: Array<{text: string}>;
}

/**
 * Builds an alternating Vertex conversation and attaches context as bounded
 * user data exactly once. Adjacent failed/user turns are coalesced rather than
 * relying on provider-specific tolerance for duplicate roles.
 * @param {CoachChatInput} input Validated coach request.
 * @return {VertexContent[]} Vertex conversation contents.
 */
export function buildVertexContents(input: CoachChatInput): VertexContent[] {
  const normalized: VertexContent[] = [];
  for (const message of input.messages) {
    const role = message.role === "assistant" ? "model" : "user";
    const previous = normalized.at(-1);
    if (previous?.role === role) {
      previous.parts[0].text += `\n\n${message.content}`;
    } else {
      normalized.push({role, parts: [{text: message.content}]});
    }
  }

  const projectedEvidence = projectedMetricEvidenceText(input.coachingBrief);
  const brief = input.coachingBrief ? [
    "BOUNDED COACHING BRIEF (untrusted data)",
    `Evidence strength: ${input.coachingBrief.evidenceStrength}`,
    `Direct read: ${input.coachingBrief.directVerdict}`,
    input.coachingBrief.decisiveEvidence ?
      `Decisive evidence: ${input.coachingBrief.decisiveEvidence}` : null,
    input.coachingBrief.nextMove ?
      `Next move: ${input.coachingBrief.nextMove}` : null,
    input.coachingBrief.missingEvidence ?
      `Missing evidence: ${input.coachingBrief.missingEvidence}` : null,
    input.coachingBrief.repairFocus ?
      `Repair focus: ${input.coachingBrief.repairFocus}` : null,
    input.coachingBrief.evidenceReadKind ?
      `Evidence read: ${input.coachingBrief.evidenceReadKind}` : null,
    input.coachingBrief.requestedMetrics ?
      "Requested metrics: " +
        input.coachingBrief.requestedMetrics.join(", ") : null,
    projectedEvidence ? `Typed metric evidence: ${projectedEvidence}` : null,
  ].filter((line): line is string => Boolean(line)).join("\n") :
    "BOUNDED COACHING BRIEF: none supplied";
  const quoteSources = input.verifiedQuoteSources.length > 0 ? [
    "VERIFIED QUOTE SOURCES (exact untrusted speech data)",
    ...input.verifiedQuoteSources.map(
      (source, index) => `Source ${index + 1}: ${source}`
    ),
  ].join("\n") : "VERIFIED QUOTE SOURCES: none supplied";
  const context = `${brief}\n\n${quoteSources}\n\n` +
    "COACHING CONTEXT (untrusted data)\n" +
    input.coachingContext;
  if (normalized[0]?.role === "model") {
    normalized.unshift({role: "user", parts: [{text: context}]});
  } else if (normalized[0]?.role === "user") {
    const firstUser = normalized[0];
    firstUser.parts[0].text = `${context}\n\nUSER MESSAGE\n` +
      firstUser.parts[0].text;
  } else {
    normalized.unshift({role: "user", parts: [{text: context}]});
  }
  return normalized;
}

/** @return {HttpsError} Typed client-cancellation error. */
function cancellationError(): HttpsError {
  return new HttpsError("cancelled", "Coach request was cancelled.");
}

/**
 * Races asynchronous work against a callable disconnect signal.
 * @param {Promise<T>} promise Work to await.
 * @param {AbortSignal|undefined} signal Callable cancellation signal.
 * @return {Promise<T>} Work result or a typed cancellation.
 */
async function waitForSignal<T>(
  promise: Promise<T>,
  signal: AbortSignal | undefined
): Promise<T> {
  if (!signal) return promise;
  if (signal.aborted) throw cancellationError();
  return new Promise<T>((resolve, reject) => {
    const cancel = () => reject(cancellationError());
    signal.addEventListener("abort", cancel, {once: true});
    promise.then(
      (value) => {
        signal.removeEventListener("abort", cancel);
        resolve(value);
      },
      (error) => {
        signal.removeEventListener("abort", cancel);
        reject(error);
      }
    );
  });
}

/**
 * Joins text parts from the first Vertex candidate.
 * @param {CoachGenerateContentResponse} response Vertex response.
 * @return {string} Joined candidate text.
 */
function responseText(response: CoachGenerateContentResponse): string {
  return response.candidates?.[0]?.content?.parts
    ?.map((part) => part.text ?? "")
    .join("") ?? "";
}

/**
 * Consumes one Vertex stream with typed deltas and a validated completion.
 * Exported so streaming, cancellation, truncation, and provider failures can
 * be verified without a live model or storing coaching content in fixtures.
 * @param {CoachChatInput} input Validated callable input.
 * @param {string} modelName Deployment-selected Vertex model.
 * @param {CoachStreamDependencies} dependencies Stream and cancellation I/O.
 * @return {Promise<CoachChatCompletionPayload>} Typed final completion.
 */
export async function consumeCoachStream(
  input: CoachChatInput,
  modelName: string,
  dependencies: CoachStreamDependencies
): Promise<CoachChatCompletionPayload> {
  const streamResult = await waitForSignal(
    dependencies.generate(),
    dependencies.signal
  );
  const iterator = streamResult[Symbol.asyncIterator]();
  let text = "";
  let finishReason = "UNKNOWN";
  let inputTokens: number | undefined;
  let outputTokens: number | undefined;
  try {
    let next = await waitForSignal(iterator.next(), dependencies.signal);
    while (!next.done) {
      const delta = responseText(next.value);
      text += delta;
      const candidateFinishReason = next.value.candidates?.[0]?.finishReason;
      if (candidateFinishReason) finishReason = candidateFinishReason;
      if (next.value.usageMetadata) {
        inputTokens = next.value.usageMetadata.promptTokenCount;
        outputTokens = next.value.usageMetadata.candidatesTokenCount;
      }
      if (delta && dependencies.sendDelta) {
        await waitForSignal(
          Promise.resolve(dependencies.sendDelta({
            type: "delta",
            requestID: input.requestID,
            text: delta,
          })),
          dependencies.signal
        );
      }
      next = await waitForSignal(iterator.next(), dependencies.signal);
    }
  } finally {
    if (dependencies.signal?.aborted) {
      void iterator.return?.(undefined);
    }
  }

  text = text.trim();
  if (!text || !isAcceptableFinishReason(finishReason)) {
    throw new HttpsError(
      "data-loss",
      "Coach generation did not complete.",
      {reason: finishReason, textCharacters: text.length}
    );
  }
  return {
    requestID: input.requestID,
    text,
    model: modelName,
    policyVersion: COACH_POLICY_VERSION,
    qualityTier: input.qualityTier,
    generationMode: "model",
    finishReason,
    inputTokens,
    outputTokens,
  };
}

export interface CoachGenerationDependencies {
  generate: (
    contents: VertexContent[],
    temperature: number
  ) => Promise<AsyncIterable<CoachGenerateContentResponse>>;
  signal?: AbortSignal;
}

export interface CoachGenerationResult {
  completion: CoachChatCompletionPayload;
  repaired: boolean;
}

/**
 * Gives the single most useful content-free correction for a rejected draft.
 * @param {string} issue Deterministic policy rejection code.
 * @return {string} Bounded rewrite direction.
 */
function coachRepairInstruction(issue: string): string {
  switch (issue) {
  case "repeated-action":
  case "repeated-anchor":
  case "repeated-sentence":
    return "State the action once and delete every restatement of it.";
  case "repeated-prior-action":
    return [
      "Do not paraphrase or reissue the recent action as if it were new.",
      "If the supplied brief keeps that intervention, name the current",
      "evidence once and say to stay with that focus without restating the",
      "drill. Otherwise advance the target, condition, or evidence check.",
    ].join(" ");
  case "generic-opener":
    return "Delete the praise or generic setup and answer immediately.";
  case "deferred-repair":
    return [
      "Own the miss in the present tense and make the next move an instruction",
      "to the speaker, not a promise about your next reply.",
    ].join(" ");
  case "outcome-promise":
    return "Remove the promise and use only an observable speaker behavior.";
  case "coach-observer-promise":
    return [
      "Delete the future-coach promise.",
      "Keep one supplied observation and one speaker action, making their",
      "relationship clear in natural prose, then stop.",
    ].join(" ");
  case "missing-recent-anchor":
    return [
      "Name the recent or latest rep and one exact supplied observation,",
      "then explain naturally why that observation supports one speaker move.",
    ].join(" ");
  case "missing-evidence-bridge":
    return [
      "Make clear why one supplied observation supports the speaker's move.",
      "A natural clause or two adjacent sentences are both acceptable.",
    ].join(" ");
  case "missing-move-grounding":
    return [
      "Use the supplied next move itself; do not substitute another action.",
      "State that move once in natural language.",
    ].join(" ");
  case "missing-evidence-grounding":
    return [
      "Use the distinct supplied evidence, not a topic word shared with the",
      "next move. Explain the relationship naturally without forcing a",
      "particular connector.",
    ].join(" ");
  case "non-coaching-prescription":
  case "non-coaching-brief-leak":
    return [
      "Answer this interaction naturally without a diagnosis, evidence read,",
      "practice instruction, or coaching drill.",
    ].join(" ");
  case "unsolicited-action":
    return [
      "Remove the next move or exercise. Answer only the explanation,",
      "reflection, or judgement the speaker asked for.",
    ].join(" ");
  case "invented-number":
  case "invented-quote":
  case "invented-setting":
  case "invented-mechanism":
  case "invented-action":
    return "Remove the unsupported claim instead of replacing it with another.";
  case "word-limit":
    return "Cut setup and secondary advice until the reply fits the limit.";
  default:
    return "Correct only the rejected issue without adding another claim.";
  }
}

/**
 * Builds one provider-visible repair turn without changing request evidence.
 * @param {VertexContent[]} contents Original bounded conversation.
 * @param {string} draft Rejected provider draft.
 * @param {string} issue Content-free deterministic rejection code.
 * @param {boolean} includeNextMove Whether this turn explicitly asks for one.
 * @return {VertexContent[]} Alternating conversation with a rewrite request.
 */
function coachRepairContents(
  contents: VertexContent[],
  draft: string,
  issue: string,
  includeNextMove: boolean
): VertexContent[] {
  return [
    ...contents,
    {role: "model", parts: [{text: draft}]},
    {
      role: "user",
      parts: [{text: [
        `The draft was rejected for ${issue}.`,
        coachRepairInstruction(issue),
        "Rewrite it from the supplied evidence only.",
        includeNextMove ?
          "Answer naturally once, then give at most one next move." :
          "Answer naturally once and do not add a next move or exercise.",
      ].join(" ")}],
    },
  ];
}

/**
 * Preserves availability when a coaching brief authorizes no action. The
 * typed client verdict has already made the evidence decision; another model
 * attempt must not invent an exercise merely to make the reply feel complete.
 * @param {CoachChatInput} input Validated request evidence.
 * @return {string|null} Policy-valid direct verdict, when available.
 */
function deterministicNoMoveReply(input: CoachChatInput): string | null {
  if (input.turnIntent !== "coaching" ||
      input.responseKind !== "personalEvidenceRead") return null;
  const brief = input.coachingBrief;
  if (!brief || brief.nextMove) return null;
  const directVerdict = brief.directVerdict.trim();
  if (!directVerdict) return null;
  // The typed verdict is already the client judgement layer's vetted honest
  // read. Returning it once is more natural than wrapping it in a second
  // evidence-gap disclaimer that repeats the same idea.
  const safeReply = /[.!?]$/u.test(directVerdict) ?
    directVerdict : `${directVerdict}.`;
  if (coachReplyPolicyIssue(input, safeReply)) {
    return null;
  }
  return safeReply;
}

/**
 * Salvages a grounded coaching sentence when the provider appended a separate
 * future-observer promise. The shared policy gate verifies the remaining
 * evidence and move; it does not force a connective into otherwise clear prose.
 * @param {CoachChatInput} input Validated request evidence.
 * @param {string} draft Rejected provider draft.
 * @return {string|null} Policy-valid grounded remainder, when available.
 */
function deterministicObserverPromiseReply(
  input: CoachChatInput,
  draft: string
): string | null {
  if (input.turnIntent !== "coaching") return null;
  const clean = coachReplyWithoutObserverPromise(draft);
  if (!clean) return null;
  return coachReplyPolicyIssue(input, clean) ? null : clean;
}

/**
 * Uses the client-owned judgement when two model drafts cannot verbalise it
 * cleanly. This is intentionally limited to short coaching turns; deep reads
 * and trust repair still require a coherent generated response.
 * @param {CoachChatInput} input Validated request evidence.
 * @return {string|null} Policy-valid evidence-to-move sentence.
 */
function deterministicGroundedBriefReply(
  input: CoachChatInput
): string | null {
  if (input.turnIntent !== "coaching") return null;
  const brief = input.coachingBrief;
  if (!brief?.nextMove || !brief.decisiveEvidence) return null;
  if (input.turnDepth !== "quickMove" && input.turnDepth !== "groundedRead") {
    return null;
  }

  const move = brief.nextMove.trim().replace(/[.!?]+$/u, "");
  const rawEvidence = brief.decisiveEvidence
    .trim()
    .replace(/[.!?]+$/u, "");
  if (!move || !rawEvidence) return null;

  let evidenceSentence: string;
  if (/^latest rep:\s*/iu.test(rawEvidence)) {
    evidenceSentence = rawEvidence.replace(
      /^latest rep:\s*/iu,
      "The latest rep showed "
    );
  } else if (/^recent reps?:\s*/iu.test(rawEvidence)) {
    evidenceSentence = rawEvidence.replace(
      /^recent reps?:\s*/iu,
      "Recent reps showed "
    );
  } else if (/^transcript signal:\s*/iu.test(rawEvidence)) {
    evidenceSentence = rawEvidence.replace(
      /^transcript signal:\s*/iu,
      "The latest transcript showed "
    );
  } else if (/^pace estimate:\s*/iu.test(rawEvidence)) {
    evidenceSentence = rawEvidence.replace(
      /^pace estimate:\s*/iu,
      "The latest rep's pace was "
    );
  } else {
    evidenceSentence = rawEvidence[0].toLocaleUpperCase("en") +
      rawEvidence.slice(1);
  }

  const moveSentence = move[0].toLocaleUpperCase("en") + move.slice(1);
  const safeReply = coachTurnRequestsMove(input) ?
    coachBriefRetainsRecentMove(input) ?
      `${evidenceSentence}. Stay with that focus for the next rep.` :
      `${evidenceSentence}. ${moveSentence}.` :
    `${evidenceSentence}.`;
  return coachReplyPolicyIssue(input, safeReply) ? null : safeReply;
}

/**
 * Buffers an untrusted draft, applies deterministic evidence checks, and makes
 * at most one hidden rewrite attempt. No rejected token reaches the client.
 * @param {CoachChatInput} input Validated callable input.
 * @param {string} modelName Deployment-selected Vertex model.
 * @param {VertexContent[]} contents Bounded alternating provider contents.
 * @param {CoachGenerationDependencies} dependencies Provider and cancellation.
 * @return {Promise<CoachGenerationResult>} Accepted completion and repair flag.
 */
export async function generateCoachCompletionWithRepair(
  input: CoachChatInput,
  modelName: string,
  contents: VertexContent[],
  dependencies: CoachGenerationDependencies
): Promise<CoachGenerationResult> {
  // Without an explicit consent-bound source and revision move, memory is not
  // provider work. Answer honestly without letting a model invent continuity.
  if (input.responseKind === "memoryHandoff" &&
      (!input.coachingBrief?.decisiveEvidence ||
        !input.coachingBrief.nextMove)) {
    return {
      completion: {
        requestID: input.requestID,
        text: "I don't have a clear pattern to carry forward yet.",
        model: modelName,
        policyVersion: COACH_POLICY_VERSION,
        qualityTier: input.qualityTier,
        generationMode: "deterministic-brief",
        finishReason: "STOP",
        inputTokens: undefined,
        outputTokens: undefined,
      },
      repaired: false,
    };
  }
  // A no-move brief is already the complete, client-vetted coaching decision.
  // Never ask a model to embellish an evidence gap into an unauthorized drill.
  if (input.turnIntent === "coaching" &&
      input.responseKind === "personalEvidenceRead" &&
      input.coachingBrief && !input.coachingBrief.nextMove) {
    const safeNoMoveReply = deterministicNoMoveReply(input);
    if (!safeNoMoveReply) {
      throw new HttpsError(
        "data-loss",
        "Coach brief did not pass evidence checks.",
        {reason: "invalid-no-move-verdict"}
      );
    }
    return {
      completion: {
        requestID: input.requestID,
        text: safeNoMoveReply,
        model: modelName,
        policyVersion: COACH_POLICY_VERSION,
        qualityTier: input.qualityTier,
        generationMode: "deterministic-brief",
        finishReason: "STOP",
        inputTokens: undefined,
        outputTokens: undefined,
      },
      repaired: false,
    };
  }

  const initialTemperature = input.qualityTier === "ultra" ? 0.45 : 0.55;
  let completion: CoachChatCompletionPayload | undefined;
  let issue: string | null = null;

  try {
    completion = await consumeCoachStream(input, modelName, {
      generate: () => dependencies.generate(contents, initialTemperature),
      signal: dependencies.signal,
    });
    issue = coachReplyPolicyIssue(input, completion.text);
  } catch (error) {
    if (!(error instanceof HttpsError) || error.code !== "data-loss") {
      throw error;
    }
    issue = "incomplete-generation";
  }

  if (!issue && completion) return {completion, repaired: false};
  if (completion) {
    if (issue === "coach-observer-promise") {
      const safeObserverReply = deterministicObserverPromiseReply(
        input,
        completion.text
      );
      if (safeObserverReply) {
        return {
          completion: {
            ...completion,
            text: safeObserverReply,
            generationMode: "model-sanitized",
            outputTokens: undefined,
          },
          repaired: true,
        };
      }
    }
  }

  const repairMayIncludeNextMove = input.responseKind === "memoryHandoff" ||
    (input.responseKind !== "conversational" &&
      coachTurnRequestsMove(input));
  const retryContents = completion ?
    coachRepairContents(
      contents,
      completion.text,
      issue ?? "policy",
      repairMayIncludeNextMove
    ) :
    contents;
  let repaired: CoachChatCompletionPayload;
  try {
    repaired = await consumeCoachStream(input, modelName, {
      generate: () => dependencies.generate(retryContents, 0.2),
      signal: dependencies.signal,
    });
  } catch (error) {
    if (!(error instanceof HttpsError) || error.code !== "data-loss") {
      throw error;
    }
    const safeBriefReply = deterministicGroundedBriefReply(input);
    if (!safeBriefReply) throw error;
    return {
      completion: {
        requestID: input.requestID,
        text: safeBriefReply,
        model: modelName,
        policyVersion: COACH_POLICY_VERSION,
        qualityTier: input.qualityTier,
        generationMode: "deterministic-brief",
        // The wire contract uses STOP to mean a complete visible response;
        // generationMode carries the separate authorship/provenance signal.
        finishReason: "STOP",
        inputTokens: undefined,
        outputTokens: undefined,
      },
      repaired: true,
    };
  }
  const repairedIssue = coachReplyPolicyIssue(input, repaired.text);
  if (repairedIssue === "coach-observer-promise") {
    const safeObserverReply = deterministicObserverPromiseReply(
      input,
      repaired.text
    );
    if (safeObserverReply) {
      return {
        completion: {
          ...repaired,
          text: safeObserverReply,
          generationMode: "model-sanitized",
          outputTokens: undefined,
        },
        repaired: true,
      };
    }
  }
  if (repairedIssue) {
    const safeBriefReply = deterministicGroundedBriefReply(input);
    if (safeBriefReply) {
      return {
        completion: {
          ...repaired,
          text: safeBriefReply,
          generationMode: "deterministic-brief",
          outputTokens: undefined,
        },
        repaired: true,
      };
    }
    throw new HttpsError(
      "failed-precondition",
      "Coach generation did not pass evidence checks.",
      {reason: "coach-quality-rejected", policyIssue: repairedIssue}
    );
  }
  return {
    completion: {...repaired, generationMode: "model-rewrite"},
    repaired: true,
  };
}

/**
 * Returns true for an unboxed JSON object.
 * @param {unknown} value Candidate JSON value.
 * @return {boolean} Whether the value is a record.
 */
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * Validates and normalizes one bounded request string.
 * @param {unknown} value Candidate string.
 * @param {string} field Public field name.
 * @param {number} maxLength Maximum accepted character count.
 * @return {string} Trimmed request value.
 */
function requiredString(
  value: unknown,
  field: string,
  maxLength: number
): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} must be a string.`);
  }
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} has an invalid length.`);
  }
  return trimmed;
}

/**
 * Validates an opaque Firebase UID without normalizing it. Equality is the
 * security property, so leading/trailing or embedded whitespace must fail
 * rather than being silently trimmed into another identifier.
 * @param {unknown} value Candidate account ID.
 * @return {string} Exact bounded account ID.
 */
function requiredCoachAccountID(value: unknown): string {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "accountID has an invalid format."
    );
  }
  const hasControlCharacter = Array.from(value).some((character) => {
    const codePoint = character.codePointAt(0) ?? 0;
    return codePoint <= 0x1f || codePoint === 0x7f;
  });
  if (value.length === 0 || value.length > MAX_ACCOUNT_ID_CHARS ||
      value.trim() !== value || /\s/u.test(value) || hasControlCharacter) {
    throw new HttpsError(
      "invalid-argument",
      "accountID has an invalid format."
    );
  }
  return value;
}

/**
 * Validates the versioned account-binding envelope shared by coach callables.
 * @param {Record<string, unknown>} data Callable request data.
 * @return {Pick<CoachChatInput, "schemaVersion" | "accountID">} Binding.
 */
function validateCoachAccountBindingFields(
  data: Record<string, unknown>
): Pick<CoachChatInput, "schemaVersion" | "accountID"> {
  if (data.schemaVersion === 2) {
    return {
      schemaVersion: 2,
      accountID: requiredCoachAccountID(data.accountID),
    };
  }
  throw new HttpsError("invalid-argument", "Unsupported schema version.");
}

/**
 * Validates one optional bounded request string.
 * @param {unknown} value Candidate value.
 * @param {string} field Public field name.
 * @param {number} maxLength Maximum accepted character count.
 * @return {string|null} Trimmed value or null when absent.
 */
function optionalString(
  value: unknown,
  field: string,
  maxLength: number
): string | null {
  if (value === undefined || value === null) return null;
  return requiredString(value, field, maxLength);
}

/**
 * Normalizes the two production service levels while accepting the legacy
 * provider-oriented values from older app builds.
 * @param {unknown} value Public quality-tier value.
 * @return {CoachChatQualityTier} Stable Fast or Ultra mode.
 */
export function normalizeQualityTier(value: unknown): CoachChatQualityTier {
  if (value === "fast" || value === "geminiFast") return "fast";
  if (value === "ultra" || value === "claudeReasoning") return "ultra";
  throw new HttpsError("invalid-argument", "Unsupported quality tier.");
}

const COACH_VOICES = new Set<CoachVoice>([
  "authoritative",
  "warm",
  "concise",
  "persuasive",
  "executive",
  "storytelling",
]);
const COACH_TURN_DEPTHS = new Set<CoachTurnDepth>([
  "quickMove",
  "groundedRead",
  "deepAssessment",
  "trustRepair",
]);
const COACH_TURN_INTENTS = new Set<CoachTurnIntent>([
  "coaching",
  "greeting",
  "offTopic",
  "preference",
  "vulnerable",
  "unknown",
]);
const COACH_RESPONSE_KINDS = new Set<CoachResponseKind>([
  "personalEvidenceRead",
  "generalCoaching",
  "memoryHandoff",
  "conversational",
]);
const CANONICAL_PERSONAL_NO_MOVE_VERDICT =
  "I don’t have enough evidence to choose your next move yet.";

/**
 * Validates an optional user-selected coaching voice.
 * @param {unknown} value Public voice selector.
 * @return {CoachVoice|null} Validated voice or the neutral default.
 */
export function normalizeCoachVoice(value: unknown): CoachVoice | null {
  if (value === undefined || value === null) return null;
  if (typeof value === "string" && COACH_VOICES.has(value as CoachVoice)) {
    return value as CoachVoice;
  }
  throw new HttpsError("invalid-argument", "Unsupported coach voice.");
}

/**
 * Validates turn depth while keeping omitted frame data conservative.
 * @param {unknown} value Public turn-depth selector.
 * @return {CoachTurnDepth} Validated depth or a conservative grounded read.
 */
export function normalizeCoachTurnDepth(value: unknown): CoachTurnDepth {
  if (value === undefined || value === null) return "groundedRead";
  if (typeof value === "string" &&
      COACH_TURN_DEPTHS.has(value as CoachTurnDepth)) {
    return value as CoachTurnDepth;
  }
  throw new HttpsError("invalid-argument", "Unsupported coach turn depth.");
}

/**
 * Validates the client-classified interaction intent. Omitted intent remains
 * in an unknown lane so the server never assumes the user requested a drill.
 * @param {unknown} value Public interaction intent.
 * @return {CoachTurnIntent} Validated intent or conservative legacy default.
 */
export function normalizeCoachTurnIntent(value: unknown): CoachTurnIntent {
  if (value === undefined || value === null) return "unknown";
  if (typeof value === "string" &&
      COACH_TURN_INTENTS.has(value as CoachTurnIntent)) {
    return value as CoachTurnIntent;
  }
  throw new HttpsError("invalid-argument", "Unsupported coach turn intent.");
}

/**
 * Validates the schema-v2 boundary between personal evidence reads and other
 * coaching turns. It is required so omitted client data cannot silently relax
 * the personal no-move gate.
 * @param {unknown} value Public response-kind selector.
 * @return {CoachResponseKind} Validated response kind.
 */
export function normalizeCoachResponseKind(value: unknown): CoachResponseKind {
  if (typeof value === "string" &&
      COACH_RESPONSE_KINDS.has(value as CoachResponseKind)) {
    return value as CoachResponseKind;
  }
  throw new HttpsError("invalid-argument", "Unsupported coach response kind.");
}

/**
 * Rejects contradictory schema-v2 policy frames before rate-limit or provider
 * work. A conversational response is valid exactly for a known non-coaching
 * intent and may not carry a coaching brief; all other response kinds remain
 * confined to coaching or conservative legacy-unknown intent.
 * @param {CoachTurnIntent} turnIntent Validated interaction intent.
 * @param {CoachResponseKind} responseKind Validated response policy lane.
 * @param {CoachBrief|null} coachingBrief Validated bounded coach brief.
 */
export function assertCoachResponseFrameCoherence(
  turnIntent: CoachTurnIntent,
  responseKind: CoachResponseKind,
  coachingBrief: CoachBrief | null
): void {
  const hasTypedEvidence = Boolean(
    coachingBrief?.evidenceReadKind ||
    coachingBrief?.requestedMetrics ||
    coachingBrief?.latestRepMetrics ||
    coachingBrief?.longitudinalTrend
  );
  const knownNonCoaching = turnIntent === "greeting" ||
    turnIntent === "offTopic" ||
    turnIntent === "preference" ||
    turnIntent === "vulnerable";
  if (responseKind === "conversational") {
    if (!knownNonCoaching || coachingBrief !== null) {
      throw new HttpsError(
        "invalid-argument",
        "Coach response frame is contradictory."
      );
    }
    return;
  }
  if (responseKind === "generalCoaching" && coachingBrief !== null) {
    throw new HttpsError(
      "invalid-argument",
      "Coach response frame is contradictory."
    );
  }
  if (responseKind !== "personalEvidenceRead" && hasTypedEvidence) {
    throw new HttpsError(
      "invalid-argument",
      "Coach response frame is contradictory."
    );
  }
  if (responseKind === "personalEvidenceRead" && coachingBrief &&
      hasTypedEvidence &&
      (!coachingBrief.evidenceReadKind || coachingBrief.nextMove)) {
    throw new HttpsError(
      "invalid-argument",
      "Coach response frame is contradictory."
    );
  }
  if (responseKind === "personalEvidenceRead" && coachingBrief &&
      !coachingBrief.nextMove) {
    if (coachingBrief.evidenceReadKind === "latestRepMetrics") {
      const requested = coachingBrief.requestedMetrics;
      if (!requested || coachingBrief.longitudinalTrend) {
        throw new HttpsError(
          "invalid-argument",
          "Coach response frame is contradictory."
        );
      }
      const projection = coachingBrief.latestRepMetrics;
      const hasValue = (metric: CoachMetricKind): boolean => {
        if (!projection) return false;
        switch (metric) {
        case "score": return projection.score !== undefined;
        case "fillerCount": return projection.fillerCount !== undefined;
        case "fillerRatePerMinute":
          return projection.fillerRatePerMinute !== undefined;
        case "paceWordsPerMinute":
          return projection.paceWordsPerMinute !== undefined;
        case "durationSeconds": return true;
        }
      };
      const hasRequestedValue = requested.some(hasValue);
      if ((hasRequestedValue &&
          (coachingBrief.evidenceStrength !== "weak" ||
           coachingBrief.decisiveEvidence === null)) ||
          (!hasRequestedValue &&
          (coachingBrief.evidenceStrength !== "missing" ||
           coachingBrief.decisiveEvidence !== null))) {
        throw new HttpsError(
          "invalid-argument",
          "Coach response frame is contradictory."
        );
      }
      return;
    }
    if (coachingBrief.evidenceReadKind === "longitudinalTrend") {
      if (coachingBrief.requestedMetrics || coachingBrief.latestRepMetrics) {
        throw new HttpsError(
          "invalid-argument",
          "Coach response frame is contradictory."
        );
      }
      const hasTrend = coachingBrief.longitudinalTrend !== undefined;
      if ((hasTrend &&
          (coachingBrief.evidenceStrength !== "repeated" ||
           coachingBrief.decisiveEvidence === null)) ||
          (!hasTrend &&
          (coachingBrief.evidenceStrength !== "missing" ||
           coachingBrief.decisiveEvidence !== null))) {
        throw new HttpsError(
          "invalid-argument",
          "Coach response frame is contradictory."
        );
      }
      return;
    }
    if (hasTypedEvidence ||
        coachingBrief.evidenceStrength !== "missing" ||
        coachingBrief.decisiveEvidence !== null ||
        coachingBrief.directVerdict !== CANONICAL_PERSONAL_NO_MOVE_VERDICT) {
      throw new HttpsError(
        "invalid-argument",
        "Coach response frame is contradictory."
      );
    }
  }
  if (knownNonCoaching) {
    throw new HttpsError(
      "invalid-argument",
      "Coach response frame is contradictory."
    );
  }
}

const COACH_EVIDENCE_STRENGTHS = new Set<CoachEvidenceStrength>([
  "missing",
  "weak",
  "forming",
  "repeated",
]);
const COACH_EVIDENCE_READ_KINDS = new Set<CoachEvidenceReadKind>([
  "latestRepMetrics",
  "longitudinalTrend",
]);
const COACH_METRIC_KINDS = new Set<CoachMetricKind>([
  "score",
  "fillerCount",
  "fillerRatePerMinute",
  "paceWordsPerMinute",
  "durationSeconds",
]);
const COACH_LONGITUDINAL_METRICS = new Set<
  CoachLongitudinalMetricTrend["metric"]
>([
  "score",
  "fillerRatePerMinute",
  "paceWordsPerMinute",
]);
const COACH_TREND_DIRECTIONS = new Set<
  CoachLongitudinalMetricTrend["direction"]
>(["improving", "declining", "stable"]);
const CURRENT_COMPARISON_METRIC_SCHEMA_VERSION = 2;

/**
 * @param {Record<string, unknown>} value Candidate public object.
 * @param {Set<string>} allowedKeys Exact allowed field names.
 * @param {string} field Public field path.
 * @return {void}
 */
function assertOnlyKeys(
  value: Record<string, unknown>,
  allowedKeys: Set<string>,
  field: string
): void {
  if (Object.keys(value).some((key) => !allowedKeys.has(key))) {
    throw new HttpsError("invalid-argument", `${field} has extra fields.`);
  }
}

/**
 * @param {unknown} value Candidate public number.
 * @param {string} field Public field path.
 * @param {number} minimum Inclusive lower bound.
 * @param {number} maximum Inclusive upper bound.
 * @param {boolean} integer Whether an integer is required.
 * @return {number} Validated number.
 */
function boundedNumber(
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
  integer = false
): number {
  if (typeof value !== "number" || !Number.isFinite(value) ||
      value < minimum || value > maximum ||
      (integer && !Number.isInteger(value))) {
    throw new HttpsError(
      "invalid-argument",
      `${field} has an invalid value.`
    );
  }
  return value;
}

/**
 * @param {unknown} value Candidate optional public number.
 * @param {string} field Public field path.
 * @param {number} minimum Inclusive lower bound.
 * @param {number} maximum Inclusive upper bound.
 * @param {boolean} integer Whether an integer is required.
 * @return {number|undefined} Validated number when present.
 */
function optionalBoundedNumber(
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
  integer = false
): number | undefined {
  if (value === undefined || value === null) return undefined;
  return boundedNumber(value, field, minimum, maximum, integer);
}

/**
 * @param {unknown} value Candidate session identifier.
 * @param {string} field Public field path.
 * @return {string} Validated UUID.
 */
function sessionUUID(value: unknown, field: string): string {
  const uuid = requiredString(value, field, 36);
  if (!UUID_PATTERN.test(uuid)) {
    throw new HttpsError("invalid-argument", `${field} must be a UUID.`);
  }
  return uuid;
}

/**
 * @param {unknown} value Candidate latest-rep projection.
 * @return {CoachLatestRepMetricProjection|undefined} Validated projection.
 */
function validateLatestRepMetricProjection(
  value: unknown
): CoachLatestRepMetricProjection | undefined {
  if (value === undefined || value === null) return undefined;
  if (!isRecord(value)) {
    throw new HttpsError(
      "invalid-argument",
      "coachingBrief.latestRepMetrics must be an object."
    );
  }
  assertOnlyKeys(value, new Set([
    "sourceSessionID",
    "comparisonMetricSchemaVersion",
    "mode",
    "score",
    "fillerCount",
    "fillerRatePerMinute",
    "paceWordsPerMinute",
    "durationSeconds",
    "transcriptWordCount",
  ]), "coachingBrief.latestRepMetrics");
  if (value.comparisonMetricSchemaVersion !==
      CURRENT_COMPARISON_METRIC_SCHEMA_VERSION) {
    throw new HttpsError(
      "invalid-argument",
      "coachingBrief.latestRepMetrics has an unsupported metric schema."
    );
  }
  const fillerCount = optionalBoundedNumber(
    value.fillerCount,
    "coachingBrief.latestRepMetrics.fillerCount",
    0,
    100_000,
    true
  );
  const fillerRatePerMinute = optionalBoundedNumber(
    value.fillerRatePerMinute,
    "coachingBrief.latestRepMetrics.fillerRatePerMinute",
    0,
    10_000
  );
  if ((fillerCount === undefined) !==
      (fillerRatePerMinute === undefined)) {
    throw new HttpsError(
      "invalid-argument",
      "coachingBrief.latestRepMetrics has incomplete filler evidence."
    );
  }
  const projection: CoachLatestRepMetricProjection = {
    sourceSessionID: sessionUUID(
      value.sourceSessionID,
      "coachingBrief.latestRepMetrics.sourceSessionID"
    ),
    comparisonMetricSchemaVersion:
      CURRENT_COMPARISON_METRIC_SCHEMA_VERSION,
    mode: requiredString(
      value.mode,
      "coachingBrief.latestRepMetrics.mode",
      80
    ),
    durationSeconds: boundedNumber(
      value.durationSeconds,
      "coachingBrief.latestRepMetrics.durationSeconds",
      15,
      7_200,
      true
    ),
    transcriptWordCount: boundedNumber(
      value.transcriptWordCount,
      "coachingBrief.latestRepMetrics.transcriptWordCount",
      20,
      100_000,
      true
    ),
  };
  const score = optionalBoundedNumber(
    value.score,
    "coachingBrief.latestRepMetrics.score",
    0,
    10,
    true
  );
  const pace = optionalBoundedNumber(
    value.paceWordsPerMinute,
    "coachingBrief.latestRepMetrics.paceWordsPerMinute",
    1,
    2_000,
    true
  );
  if (score !== undefined) projection.score = score;
  if (fillerCount !== undefined) projection.fillerCount = fillerCount;
  if (fillerRatePerMinute !== undefined) {
    projection.fillerRatePerMinute = fillerRatePerMinute;
  }
  if (pace !== undefined) projection.paceWordsPerMinute = pace;
  return projection;
}

/**
 * Mirrors the client-owned movement policy used to construct the projection.
 * The callable still validates it independently so a forged client cannot pair
 * improving language with values that moved the other way.
 * @param {string} metric Metric kind.
 * @param {number} currentValue Latest value.
 * @param {number} priorAverage Exact-comparator average.
 * @return {string} Expected direction.
 */
function expectedLongitudinalDirection(
  metric: CoachLongitudinalMetricTrend["metric"],
  currentValue: number,
  priorAverage: number
): CoachLongitudinalMetricTrend["direction"] {
  let improvement: number;
  let threshold: number;
  switch (metric) {
  case "score":
    improvement = currentValue - priorAverage;
    threshold = 0.5;
    break;
  case "fillerRatePerMinute":
    improvement = priorAverage - currentValue;
    threshold = 0.75;
    break;
  case "paceWordsPerMinute":
    improvement = Math.abs(priorAverage - 130) -
      Math.abs(currentValue - 130);
    threshold = 10;
    break;
  }
  if (improvement >= threshold) return "improving";
  if (improvement <= -threshold) return "declining";
  return "stable";
}

/**
 * @param {unknown} value Candidate longitudinal metric.
 * @param {number} index Metric index for public error paths.
 * @return {CoachLongitudinalMetricTrend} Validated trend metric.
 */
function validateLongitudinalMetric(
  value: unknown,
  index: number
): CoachLongitudinalMetricTrend {
  const field = `coachingBrief.longitudinalTrend.metrics[${index}]`;
  if (!isRecord(value)) {
    throw new HttpsError("invalid-argument", `${field} must be an object.`);
  }
  assertOnlyKeys(value, new Set([
    "metric",
    "direction",
    "currentValue",
    "priorAverage",
  ]), field);
  if (typeof value.metric !== "string" ||
      !COACH_LONGITUDINAL_METRICS.has(
        value.metric as CoachLongitudinalMetricTrend["metric"]
      )) {
    throw new HttpsError("invalid-argument", `${field}.metric is invalid.`);
  }
  if (typeof value.direction !== "string" ||
      !COACH_TREND_DIRECTIONS.has(
        value.direction as CoachLongitudinalMetricTrend["direction"]
      )) {
    throw new HttpsError("invalid-argument", `${field}.direction is invalid.`);
  }
  const metric = value.metric as CoachLongitudinalMetricTrend["metric"];
  const maximum = metric === "score" ? 10 : 10_000;
  const currentValue = boundedNumber(
    value.currentValue,
    `${field}.currentValue`,
    metric === "paceWordsPerMinute" ? 1 : 0,
    maximum
  );
  const priorAverage = boundedNumber(
    value.priorAverage,
    `${field}.priorAverage`,
    metric === "paceWordsPerMinute" ? 1 : 0,
    maximum
  );
  const direction = value.direction as
    CoachLongitudinalMetricTrend["direction"];
  if (direction !== expectedLongitudinalDirection(
    metric,
    currentValue,
    priorAverage
  )) {
    throw new HttpsError(
      "invalid-argument",
      `${field}.direction does not match its values.`
    );
  }
  return {metric, direction, currentValue, priorAverage};
}

/**
 * @param {unknown} value Candidate longitudinal projection.
 * @return {CoachLongitudinalTrendProjection|undefined} Validated projection.
 */
function validateLongitudinalTrendProjection(
  value: unknown
): CoachLongitudinalTrendProjection | undefined {
  if (value === undefined || value === null) return undefined;
  if (!isRecord(value)) {
    throw new HttpsError(
      "invalid-argument",
      "coachingBrief.longitudinalTrend must be an object."
    );
  }
  assertOnlyKeys(value, new Set([
    "sourceSessionID",
    "comparisonMetricSchemaVersion",
    "mode",
    "comparableSessionIDs",
    "metrics",
  ]), "coachingBrief.longitudinalTrend");
  if (value.comparisonMetricSchemaVersion !==
      CURRENT_COMPARISON_METRIC_SCHEMA_VERSION) {
    throw new HttpsError(
      "invalid-argument",
      "coachingBrief.longitudinalTrend has an unsupported metric schema."
    );
  }
  const sourceSessionID = sessionUUID(
    value.sourceSessionID,
    "coachingBrief.longitudinalTrend.sourceSessionID"
  );
  if (!Array.isArray(value.comparableSessionIDs) ||
      value.comparableSessionIDs.length < 2 ||
      value.comparableSessionIDs.length > 5) {
    throw new HttpsError(
      "invalid-argument",
      "coachingBrief.longitudinalTrend has an invalid comparison count."
    );
  }
  const comparableSessionIDs = value.comparableSessionIDs.map((id, index) =>
    sessionUUID(
      id,
      `coachingBrief.longitudinalTrend.comparableSessionIDs[${index}]`
    )
  );
  if (new Set(comparableSessionIDs).size !== comparableSessionIDs.length ||
      comparableSessionIDs.includes(sourceSessionID)) {
    throw new HttpsError(
      "invalid-argument",
      "coachingBrief.longitudinalTrend has duplicate session provenance."
    );
  }
  if (!Array.isArray(value.metrics) || value.metrics.length === 0 ||
      value.metrics.length > 3) {
    throw new HttpsError(
      "invalid-argument",
      "coachingBrief.longitudinalTrend has an invalid metric count."
    );
  }
  const metrics = value.metrics.map(validateLongitudinalMetric);
  if (new Set(metrics.map((metric) => metric.metric)).size !== metrics.length) {
    throw new HttpsError(
      "invalid-argument",
      "coachingBrief.longitudinalTrend has duplicate metrics."
    );
  }
  return {
    sourceSessionID,
    comparisonMetricSchemaVersion:
      CURRENT_COMPARISON_METRIC_SCHEMA_VERSION,
    mode: requiredString(
      value.mode,
      "coachingBrief.longitudinalTrend.mode",
      80
    ),
    comparableSessionIDs,
    metrics,
  };
}

/**
 * Validates the bounded deterministic assessment selected by the app. It is
 * still provider-visible data, never an instruction or authorization source.
 * @param {unknown} value Public coaching brief.
 * @return {CoachBrief|null} Validated brief or null when omitted.
 */
export function validateCoachBrief(value: unknown): CoachBrief | null {
  if (value === undefined || value === null) return null;
  if (!isRecord(value)) {
    throw new HttpsError(
      "invalid-argument",
      "coachingBrief must be an object."
    );
  }
  const allowedKeys = new Set([
    "evidenceStrength",
    "directVerdict",
    "decisiveEvidence",
    "nextMove",
    "missingEvidence",
    "repairFocus",
    "evidenceReadKind",
    "requestedMetrics",
    "latestRepMetrics",
    "longitudinalTrend",
  ]);
  if (Object.keys(value).some((key) => !allowedKeys.has(key))) {
    throw new HttpsError("invalid-argument", "coachingBrief has extra fields.");
  }
  if (typeof value.evidenceStrength !== "string" ||
      !COACH_EVIDENCE_STRENGTHS.has(
        value.evidenceStrength as CoachEvidenceStrength
      )) {
    throw new HttpsError(
      "invalid-argument",
      "Unsupported coaching evidence strength."
    );
  }
  let evidenceReadKind: CoachEvidenceReadKind | undefined;
  if (value.evidenceReadKind !== undefined &&
      value.evidenceReadKind !== null) {
    if (typeof value.evidenceReadKind !== "string" ||
        !COACH_EVIDENCE_READ_KINDS.has(
          value.evidenceReadKind as CoachEvidenceReadKind
        )) {
      throw new HttpsError(
        "invalid-argument",
        "Unsupported coaching evidence read kind."
      );
    }
    evidenceReadKind = value.evidenceReadKind as CoachEvidenceReadKind;
  }
  let requestedMetrics: CoachMetricKind[] | undefined;
  if (value.requestedMetrics !== undefined &&
      value.requestedMetrics !== null) {
    if (!Array.isArray(value.requestedMetrics) ||
        value.requestedMetrics.length === 0 ||
        value.requestedMetrics.length > COACH_METRIC_KINDS.size ||
        value.requestedMetrics.some((metric) =>
          typeof metric !== "string" ||
          !COACH_METRIC_KINDS.has(metric as CoachMetricKind))) {
      throw new HttpsError(
        "invalid-argument",
        "coachingBrief.requestedMetrics is invalid."
      );
    }
    requestedMetrics = value.requestedMetrics as CoachMetricKind[];
    if (new Set(requestedMetrics).size !== requestedMetrics.length) {
      throw new HttpsError(
        "invalid-argument",
        "coachingBrief.requestedMetrics has duplicates."
      );
    }
  }
  const latestRepMetrics = validateLatestRepMetricProjection(
    value.latestRepMetrics
  );
  const longitudinalTrend = validateLongitudinalTrendProjection(
    value.longitudinalTrend
  );
  const brief: CoachBrief = {
    evidenceStrength: value.evidenceStrength as CoachEvidenceStrength,
    directVerdict: requiredString(
      value.directVerdict,
      "coachingBrief.directVerdict",
      600
    ),
    decisiveEvidence: optionalString(
      value.decisiveEvidence,
      "coachingBrief.decisiveEvidence",
      600
    ),
    nextMove: optionalString(
      value.nextMove,
      "coachingBrief.nextMove",
      600
    ),
    missingEvidence: optionalString(
      value.missingEvidence,
      "coachingBrief.missingEvidence",
      600
    ),
    repairFocus: optionalString(
      value.repairFocus,
      "coachingBrief.repairFocus",
      600
    ),
  };
  if (evidenceReadKind) brief.evidenceReadKind = evidenceReadKind;
  if (requestedMetrics) brief.requestedMetrics = requestedMetrics;
  if (latestRepMetrics) brief.latestRepMetrics = latestRepMetrics;
  if (longitudinalTrend) brief.longitudinalTrend = longitudinalTrend;
  return brief;
}

/**
 * Validates exact transcript/proof sources that may support a verbatim quote.
 * @param {unknown} value Public quote-source list.
 * @return {string[]} Bounded exact sources, or an empty omitted-field default.
 */
export function validateVerifiedQuoteSources(value: unknown): string[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value) || value.length > MAX_QUOTE_SOURCES) {
    throw new HttpsError(
      "invalid-argument",
      "verifiedQuoteSources has an invalid count."
    );
  }
  return value.map((source, index) => requiredString(
    source,
    `verifiedQuoteSources[${index}]`,
    MAX_QUOTE_SOURCE_CHARS
  ));
}

/**
 * Selects the deployment-configured model for Fast or Ultra mode.
 * @param {CoachChatQualityTier} tier Validated service level.
 * @param {string} fastModel Low-latency model name.
 * @param {string} ultraModel Deeper-reasoning model name.
 * @return {string} Vertex model name.
 */
export function modelForQualityTier(
  tier: CoachChatQualityTier,
  fastModel: string,
  ultraModel: string
): string {
  return tier === "ultra" ? ultraModel : fastModel;
}

/**
 * Pins model-specific thinking behavior instead of assuming a configurable
 * model accepts the current tier budget. Unknown model drift fails closed.
 * @param {CoachChatQualityTier} tier Validated service level.
 * @param {string} modelName Deployment-configured model.
 * @return {number} Verified thinking-token budget for this exact model.
 */
export function thinkingBudgetForModel(
  tier: CoachChatQualityTier,
  modelName: string
): number {
  const supported = tier === "fast" ?
    modelName === "gemini-2.5-flash" :
    modelName === "gemini-2.5-pro";
  if (!supported) {
    throw new HttpsError(
      "failed-precondition",
      "Configured coach model is not supported by this policy."
    );
  }
  return thinkingBudgetForQualityTier(tier);
}

/**
 * Keeps the server generation ceiling large enough for the validated depth
 * frame while the system policy provides the stricter user-visible word cap.
 * @param {string} surface Reply surface.
 * @param {CoachChatQualityTier} tier Canonical Fast/Ultra route.
 * @return {number} Maximum generated tokens.
 */
export function maxOutputTokensForRequest(
  surface: CoachChatInput["surface"],
  tier: CoachChatQualityTier
): number {
  if (surface === "live") {
    return 220;
  }
  return tier === "ultra" ? 380 : 180;
}

/**
 * Validates the public callable contract without retaining request content.
 * @param {unknown} data Raw callable payload.
 * @return {CoachChatInput} Validated request.
 */
export function validateCoachChatRequest(data: unknown): CoachChatInput {
  if (!isRecord(data)) {
    throw new HttpsError("invalid-argument", "Request must be an object.");
  }
  assertOnlyKeys(data, new Set([
    "schemaVersion",
    "accountID",
    "requestID",
    "surface",
    "qualityTier",
    "coachVoice",
    "turnDepth",
    "turnIntent",
    "responseKind",
    "coachingBrief",
    "verifiedQuoteSources",
    "coachingContext",
    "messages",
  ]), "Request");
  const binding = validateCoachAccountBindingFields(data);
  const requestID = requiredString(data.requestID, "requestID", 64);
  if (!UUID_PATTERN.test(requestID)) {
    throw new HttpsError("invalid-argument", "requestID must be a UUID.");
  }
  if (data.surface !== "text" && data.surface !== "live") {
    throw new HttpsError("invalid-argument", "Unsupported coach surface.");
  }
  const qualityTier = normalizeQualityTier(data.qualityTier);
  const coachVoice = normalizeCoachVoice(data.coachVoice);
  const turnDepth = normalizeCoachTurnDepth(data.turnDepth);
  const turnIntent = normalizeCoachTurnIntent(data.turnIntent);
  const responseKind = normalizeCoachResponseKind(data.responseKind);
  const coachingBrief = validateCoachBrief(data.coachingBrief);
  assertCoachResponseFrameCoherence(
    turnIntent,
    responseKind,
    coachingBrief
  );
  const verifiedQuoteSources = validateVerifiedQuoteSources(
    data.verifiedQuoteSources
  );
  const coachingContext = requiredString(
    data.coachingContext,
    "coachingContext",
    MAX_CONTEXT_CHARS
  );
  if (!Array.isArray(data.messages) || data.messages.length === 0 ||
      data.messages.length > MAX_MESSAGES) {
    throw new HttpsError("invalid-argument", "messages has an invalid count.");
  }
  const messages = data.messages.map((raw, index): CoachChatWireMessage => {
    if (!isRecord(raw) || (raw.role !== "user" && raw.role !== "assistant")) {
      throw new HttpsError(
        "invalid-argument",
        `messages[${index}] has an invalid role.`
      );
    }
    return {
      role: raw.role,
      content: requiredString(
        raw.content,
        `messages[${index}].content`,
        MAX_MESSAGE_CHARS
      ),
    };
  });
  if (messages[messages.length - 1].role !== "user") {
    throw new HttpsError("invalid-argument", "Last message must be from user.");
  }
  const briefChars = coachingBrief ? JSON.stringify(coachingBrief).length : 0;
  const quoteChars = verifiedQuoteSources.reduce(
    (sum, source) => sum + source.length,
    0
  );
  const totalChars = coachingContext.length + briefChars + quoteChars +
    messages.reduce((sum, message) => sum + message.content.length, 0);
  if (totalChars > MAX_TOTAL_CHARS) {
    throw new HttpsError("invalid-argument", "Request is too large.");
  }
  return {
    ...binding,
    requestID,
    surface: data.surface,
    qualityTier,
    coachVoice,
    turnDepth,
    turnIntent,
    responseKind,
    coachingBrief,
    verifiedQuoteSources,
    coachingContext,
    messages,
  };
}

export const coachChatAvailability = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 10,
    memory: "256MiB",
    serviceAccount: COACH_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    if (!isRecord(request.data) || request.data.schemaVersion !== 1) {
      throw new HttpsError("invalid-argument", "Unsupported schema version.");
    }
    const requestID = requiredString(request.data.requestID, "requestID", 64);
    if (!UUID_PATTERN.test(requestID)) {
      throw new HttpsError("invalid-argument", "requestID must be a UUID.");
    }
    logger.info("coachChat preflight", {
      requestID,
      accountBinding: "legacy-auth-derived",
      status: "available",
    });
    return {
      available: true,
      functionName: "coachChatV2",
      requestSchemaVersion: 2,
      policyVersion: COACH_POLICY_VERSION,
    };
  }
);

/**
 * Computes the next minute/hour counters as a pure transaction helper.
 * @param {Partial<RateState>|undefined} current Stored counter state.
 * @param {number} nowMs Current Unix time in milliseconds.
 * @return {RateDecision} Next counters and whether the call is allowed.
 */
export function nextRateState(
  current: Partial<WindowRateState> | undefined,
  nowMs: number
): RateDecision {
  return nextWindowRateState(current, nowMs, MINUTE_LIMIT, HOUR_LIMIT);
}

/**
 * Atomically consumes one server-only request budget for a Firebase UID.
 * @param {string} uid Authenticated Firebase account ID.
 * @return {Promise<void>} Resolves after the budget is consumed.
 */
export async function enforceRateLimit(uid: string): Promise<void> {
  const firestore = getFirestore();
  const ref = firestore.collection("_serverRateLimits").doc(uid);
  const deletionRef = firestore.collection("_accountDeletionState").doc(uid);
  await firestore.runTransaction(async (transaction) => {
    const deletionSnapshot = await transaction.get(deletionRef);
    const snapshot = await transaction.get(ref);
    assertAccountDeletionNotPending(deletionSnapshot.exists);
    const data = snapshot.exists ? snapshot.data() : undefined;
    const current = isRecord(data?.coachChat) ?
      data.coachChat as Partial<WindowRateState> :
      data as Partial<WindowRateState> | undefined;
    const decision = nextRateState(
      current,
      Date.now()
    );
    if (!decision.allowed) {
      throw new HttpsError(
        "resource-exhausted",
        "Live coaching is taking a short pause."
      );
    }
    transaction.set(ref, {coachChat: decision.state}, {merge: true});
  });
}

/**
 * Builds content-free operational fields for the frozen compatibility route.
 * @param {LegacyCoachChatInput} input Validated legacy request.
 * @param {string} model Serving model.
 * @param {number} latencyMs End-to-end latency.
 * @param {string} status Stable completion status.
 * @param {LegacyCoachChatCompletionPayload|undefined} completion Completion.
 * @return {Record<string, unknown>} Safe legacy log fields.
 */
function legacyCoachLogMetadata(
  input: LegacyCoachChatInput,
  model: string,
  latencyMs: number,
  status: string,
  completion?: LegacyCoachChatCompletionPayload
): Record<string, unknown> {
  return {
    requestID: input.requestID,
    surface: input.surface,
    qualityTier: input.qualityTier,
    model,
    accountBinding: "legacy-auth-derived",
    finishReason: completion?.finishReason,
    inputTokens: completion?.inputTokens,
    outputTokens: completion?.outputTokens,
    latencyMs,
    status,
  };
}

/**
 * Executes the frozen schema-v1 provider contract after trusted admission.
 * It intentionally streams one provider attempt directly, without schema-v2
 * rewrite, deterministic fallback, policy framing, or completion metadata.
 * @param {LegacyCoachChatInput} input Validated installed-client request.
 * @param {boolean} acceptsStreaming Whether the caller requested stream frames.
 * @param {CallableResponse<unknown>|undefined} response Stream/cancel channel.
 * @return {Promise<LegacyCoachChatCompletionPayload>} Frozen completion.
 */
async function executeLegacyCoachChat(
  input: LegacyCoachChatInput,
  acceptsStreaming: boolean,
  response: CallableResponse<unknown> | undefined
): Promise<LegacyCoachChatCompletionPayload> {
  const startedAt = Date.now();
  const project = process.env.GCLOUD_PROJECT ??
    process.env.GOOGLE_CLOUD_PROJECT;
  if (!project) {
    throw new HttpsError("failed-precondition", "Cloud project unavailable.");
  }

  const modelName = modelForQualityTier(
    input.qualityTier,
    coachModel.value(),
    coachUltraModel.value()
  );
  if (process.env.FUNCTIONS_EMULATOR === "true" &&
      process.env.COACH_EMULATOR_STUB === "1") {
    const text = input.qualityTier === "ultra" ?
      "Ultra coaching route verified." : "Fast coaching route verified.";
    if (acceptsStreaming && response) {
      await response.sendChunk({
        type: "delta",
        requestID: input.requestID,
        text,
      });
    }
    const completion: LegacyCoachChatCompletionPayload = {
      requestID: input.requestID,
      text,
      model: modelName,
      qualityTier: input.qualityTier,
      finishReason: "STOP",
      inputTokens: 1,
      outputTokens: 1,
    };
    logger.info(
      "coachChat emulator route completed",
      legacyCoachLogMetadata(
        input,
        modelName,
        Date.now() - startedAt,
        "emulator-ok",
        completion
      )
    );
    return completion;
  }

  const vertex = new GoogleGenAI({
    vertexai: true,
    project,
    location: vertexLocation.value(),
    apiVersion: "v1",
  });

  try {
    const completion = await generateLegacyCoachCompletion(
      input,
      modelName,
      {
        generate: (contents, config) =>
          vertex.models.generateContentStream({
            model: modelName,
            contents,
            config,
          }),
        sendDelta: acceptsStreaming && response ?
          (chunk) => response.sendChunk(chunk) : undefined,
        signal: response?.signal,
      }
    );
    logger.info(
      "coachChat completed",
      legacyCoachLogMetadata(
        input,
        modelName,
        Date.now() - startedAt,
        "ok",
        completion
      )
    );
    return completion;
  } catch (error) {
    const code = error instanceof HttpsError ? error.code : "unavailable";
    logger.error(
      "coachChat failed",
      legacyCoachLogMetadata(
        input,
        modelName,
        Date.now() - startedAt,
        code
      )
    );
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("unavailable", "Live coaching is unavailable.");
  }
}

/**
 * Executes one already-admitted schema-v2 request. Binding and rate limiting
 * must complete before this helper starts model selection or provider work.
 * @param {CoachChatInput} input Canonical validated schema-v2 input.
 * @param {boolean} acceptsStreaming Whether the caller requested stream frames.
 * @param {CallableResponse<unknown>|undefined} response Stream/cancel channel.
 * @param {CoachAccountBinding} accountBinding Content-free admission label.
 * @return {Promise<CoachChatCompletionPayload>} Typed coach completion.
 */
async function executeCoachChatV2(
  input: CoachChatInput,
  acceptsStreaming: boolean,
  response: CallableResponse<unknown> | undefined,
  accountBinding: CoachAccountBinding
): Promise<CoachChatCompletionPayload> {
  const startedAt = Date.now();
  const project = process.env.GCLOUD_PROJECT ??
    process.env.GOOGLE_CLOUD_PROJECT;
  if (!project) {
    throw new HttpsError("failed-precondition", "Cloud project unavailable.");
  }

  const modelName = modelForQualityTier(
    input.qualityTier,
    coachModel.value(),
    coachUltraModel.value()
  );
  if (process.env.FUNCTIONS_EMULATOR === "true" &&
      process.env.COACH_EMULATOR_STUB === "1") {
    const text = input.qualityTier === "ultra" ?
      "Ultra coaching route verified." : "Fast coaching route verified.";
    if (acceptsStreaming && response) {
      await response.sendChunk({
        type: "delta",
        requestID: input.requestID,
        text,
      });
    }
    const completion: CoachChatCompletionPayload = {
      requestID: input.requestID,
      text,
      model: modelName,
      policyVersion: COACH_POLICY_VERSION,
      qualityTier: input.qualityTier,
      generationMode: "model",
      finishReason: "STOP",
      inputTokens: 1,
      outputTokens: 1,
    };
    logger.info("coachChatV2 emulator route completed", {
      ...coachCompletionLogMetadata(
        input, modelName, "STOP", 1, 1,
        Date.now() - startedAt, "emulator-ok", accountBinding
      ),
      generationMode: completion.generationMode,
    });
    return completion;
  }
  const vertex = new GoogleGenAI({
    vertexai: true,
    project,
    location: vertexLocation.value(),
    apiVersion: "v1",
  });
  const contents = buildVertexContents(input);

  try {
    const generation = await generateCoachCompletionWithRepair(
      input,
      modelName,
      contents,
      {
        generate: (attemptContents, temperature) =>
          vertex.models.generateContentStream({
            model: modelName,
            contents: attemptContents,
            config: {
              systemInstruction: coachSystemPolicyForRequest(input),
              temperature,
              thinkingConfig: {
                thinkingBudget: thinkingBudgetForModel(
                  input.qualityTier,
                  modelName
                ),
              },
              maxOutputTokens: maxOutputTokensForRequest(
                input.surface,
                input.qualityTier
              ),
              abortSignal: response?.signal,
            },
          }),
        signal: response?.signal,
      }
    );
    const completion = generation.completion;
    // Rejected drafts are buffered server-side. Once the final draft clears
    // evidence checks, one typed chunk preserves the callable stream shape
    // without exposing fabricated or soon-to-be-replaced text.
    if (acceptsStreaming && response) {
      await waitForSignal(
        Promise.resolve(response.sendChunk({
          type: "delta",
          requestID: input.requestID,
          text: completion.text,
        })),
        response.signal
      );
    }
    logger.info("coachChatV2 completed", {
      ...coachCompletionLogMetadata(
        input, modelName, completion.finishReason,
        completion.inputTokens, completion.outputTokens,
        Date.now() - startedAt, generation.repaired ? "ok-repaired" : "ok",
        accountBinding
      ),
      generationMode: completion.generationMode,
    });
    return completion;
  } catch (error) {
    const code = error instanceof HttpsError ? error.code : "unavailable";
    logger.error(
      "coachChatV2 failed",
      coachFailureLogMetadata(
        input,
        modelName,
        Date.now() - startedAt,
        code,
        accountBinding,
        coachFailureQualityMetadata(error)
      )
    );
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("unavailable", "Live coaching is unavailable.");
  }
}

/**
 * Compatibility endpoint for installed schema-v1 clients. Authentication is
 * used for trusted admission and rate scope only; no newer payload field is
 * allowed into the frozen provider contract.
 */
export const coachChat = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 120,
    memory: "512MiB",
    serviceAccount: COACH_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request, response) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    const input = validateLegacyCoachChatRequest(request.data);
    await enforceRateLimit(uid);
    return executeLegacyCoachChat(
      input,
      request.acceptsStreaming,
      response
    );
  }
);

/** Secure schema-v2 endpoint. It never accepts or falls back to schema v1. */
export const coachChatV2 = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 120,
    memory: "512MiB",
    serviceAccount: COACH_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request, response) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    const input = validateCoachChatRequest(request.data);
    const accountBinding = assertCoachAccountBinding(input, uid);
    await enforceRateLimit(uid);
    return executeCoachChatV2(
      input,
      request.acceptsStreaming,
      response,
      accountBinding
    );
  }
);

/**
 * Atomically consumes one short-lived speech-token budget for a Firebase UID.
 * Token counters live beside, but never overwrite, Ask Noum counters.
 * @param {string} uid Authenticated Firebase account ID.
 * @return {Promise<void>} Resolves after the budget is consumed.
 */
async function enforceTranscriptionTokenRateLimit(uid: string): Promise<void> {
  const firestore = getFirestore();
  const ref = firestore.collection("_serverRateLimits").doc(uid);
  const deletionRef = firestore.collection("_accountDeletionState").doc(uid);
  await firestore.runTransaction(async (transaction) => {
    const deletionSnapshot = await transaction.get(deletionRef);
    const snapshot = await transaction.get(ref);
    assertAccountDeletionNotPending(deletionSnapshot.exists);
    const data = snapshot.exists ? snapshot.data() : undefined;
    const current = isRecord(data?.transcriptionToken) ?
      data.transcriptionToken as Partial<WindowRateState> : undefined;
    const decision = nextWindowRateState(
      current,
      Date.now(),
      TRANSCRIPTION_TOKEN_MINUTE_LIMIT,
      TRANSCRIPTION_TOKEN_HOUR_LIMIT
    );
    if (!decision.allowed) {
      throw new HttpsError(
        "resource-exhausted",
        "Speech connection requests are taking a short pause."
      );
    }
    transaction.set(
      ref,
      {transcriptionToken: decision.state},
      {merge: true}
    );
  });
}

export const transcriptionToken = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 15,
    memory: "256MiB",
    serviceAccount: TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT,
    secrets: [deepgramManagementKey],
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    validateTranscriptionTokenRequest(request.data);
    await enforceTranscriptionTokenRateLimit(uid);

    const startedAt = Date.now();
    try {
      const token = await grantDeepgramTranscriptionToken(
        deepgramManagementKey.value(),
        {
          nowMs: startedAt,
          signal: AbortSignal.timeout(8_000),
        }
      );
      logger.info(
        "transcriptionToken completed",
        transcriptionTokenLogMetadata(
          "ok",
          Date.now() - startedAt,
          Math.max(
            0,
            Math.round((Date.parse(token.expiresAt) - startedAt) / 1_000)
          )
        )
      );
      return token;
    } catch (error) {
      const status = error instanceof ProviderGrantError ?
        error.reason : "unavailable";
      logger.error(
        "transcriptionToken failed",
        transcriptionTokenLogMetadata(status, Date.now() - startedAt)
      );
      if (error instanceof ProviderGrantError &&
          error.reason === "configuration") {
        throw new HttpsError(
          "failed-precondition",
          "Speech service is not configured."
        );
      }
      throw new HttpsError(
        "unavailable",
        "Speech connection is unavailable. Try again."
      );
    }
  }
);

type CompetitiveObservationRateOperation =
  "competitiveObservationBegin" | "competitiveObservationComplete";

/**
 * Consumes one server-owned competitive-observation request budget.
 * @param {string} uid Authenticated Firebase account ID.
 * @param {CompetitiveObservationRateOperation} operation Protected operation.
 * @return {Promise<void>} Resolves after budget consumption.
 */
async function enforceCompetitiveObservationRateLimit(
  uid: string,
  operation: CompetitiveObservationRateOperation
): Promise<void> {
  const firestore = getFirestore();
  const ref = firestore.collection("_serverRateLimits").doc(uid);
  const deletionRef = firestore.collection("_accountDeletionState").doc(uid);
  await firestore.runTransaction(async (transaction) => {
    const deletionSnapshot = await transaction.get(deletionRef);
    const snapshot = await transaction.get(ref);
    assertAccountDeletionNotPending(deletionSnapshot.exists);
    const data = snapshot.data();
    const current = isRecord(data?.[operation]) ?
      data?.[operation] as CompetitiveObservationRateState : undefined;
    const decision = nextWindowRateState(
      current,
      Date.now(),
      COMPETITIVE_OBSERVATION_MINUTE_LIMIT,
      COMPETITIVE_OBSERVATION_HOUR_LIMIT
    );
    if (!decision.allowed) {
      throw new HttpsError(
        "resource-exhausted",
        "Competitive observation requests are taking a short pause."
      );
    }
    transaction.set(ref, {[operation]: decision.state}, {merge: true});
  });
}

/**
 * Verifies a challenge prompt against the exact server-owned challenge.
 * @param {string} uid Authenticated Firebase account ID.
 * @param {string} challengeID Bound challenge UUID.
 * @param {string} expectedPromptDigest Client-declared prompt digest.
 * @return {Promise<void>} Resolves only for an active participant binding.
 */
async function assertCompetitiveChallengeBinding(
  uid: string,
  challengeID: string,
  expectedPromptDigest: string
): Promise<void> {
  await assertSocialCallablesAvailable();
  const snapshot = await getFirestore().collection("challenges")
    .doc(challengeID).get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "Challenge not found.");
  }
  const challenge = validateStoredChallenge(snapshot.data(), challengeID);
  challengeSide(challenge, uid);
  const expiresAt = socialDateMilliseconds(challenge.expiresAt);
  if (expiresAt === null || expiresAt < Date.now() ||
      challenge.completedAt !== null ||
      challenge.promptDigest !== expectedPromptDigest) {
    throw new HttpsError(
      "failed-precondition",
      "Challenge observation binding is unavailable."
    );
  }
}

export const beginCompetitiveObservation = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
    serviceAccount: TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    await assertSocialCallablesAvailable();
    const input = validateBeginCompetitiveObservationRequest(request.data);
    await enforceCompetitiveObservationRateLimit(
      uid,
      "competitiveObservationBegin"
    );
    if (input.challengeID && input.promptProvenance.promptDigest) {
      await assertCompetitiveChallengeBinding(
        uid,
        input.challengeID,
        input.promptProvenance.promptDigest
      );
    }
    const firestore = getFirestore();
    const nowMs = Date.now();
    const expiresAtMs = nowMs + COMPETITIVE_OBSERVATION_INTENT_LIFETIME_MS;
    const intentRef = firestore.collection("_competitiveCaptureIntents")
      .doc(uid).collection("captureIntents").doc(input.sessionID);
    const deletionRef = firestore.collection("_accountDeletionState").doc(uid);
    const result = await firestore.runTransaction(async (transaction) => {
      const deletionSnapshot = await transaction.get(deletionRef);
      const intentSnapshot = await transaction.get(intentRef);
      assertAccountDeletionNotPending(deletionSnapshot.exists);
      if (intentSnapshot.exists) {
        const existing = validateStoredCompetitiveObservationIntent(
          intentSnapshot.data(),
          uid,
          input.sessionID,
          socialDateMilliseconds
        );
        if (!competitiveObservationIntentMatches(existing, input)) {
          throw new HttpsError(
            "already-exists",
            "This session already has a different observation intent."
          );
        }
        assertCompetitiveObservationIntentUsable(
          existing,
          uid,
          input.sessionID,
          nowMs
        );
        if (existing.status !== "pending") {
          throw new HttpsError(
            "already-exists",
            "This observation has already started provider processing."
          );
        }
        return {expiresAtMs: existing.expiresAtMs, replayed: true};
      }
      const now = Timestamp.fromMillis(nowMs);
      transaction.create(intentRef, {
        ...input,
        uid,
        status: "pending",
        competitiveEligible: false,
        audioSHA256: null,
        startedAt: now,
        expiresAt: Timestamp.fromMillis(expiresAtMs),
        updatedAt: now,
        processingStartedAt: null,
        observationCompletedAt: null,
      });
      return {expiresAtMs, replayed: false};
    });
    logger.info("beginCompetitiveObservation completed", {
      operation: "beginCompetitiveObservation",
      status: result.replayed ? "replayed" : "created",
    });
    return {
      schemaVersion: 1,
      sessionID: input.sessionID,
      expiresAt: new Date(result.expiresAtMs).toISOString(),
      replayed: result.replayed,
    };
  }
);

/**
 * Converts pure observation timestamps to server Firestore timestamps.
 * @param {StoredCompetitiveObservation} observation Validated observation.
 * @return {Record<string, unknown>} Exact Firestore document.
 */
function competitiveObservationFirestoreDocument(
  observation: StoredCompetitiveObservation
): Record<string, unknown> {
  return {
    schemaVersion: observation.schemaVersion,
    uid: observation.uid,
    sessionID: observation.sessionID,
    observationSource: observation.observationSource,
    competitiveEligible: observation.competitiveEligible,
    locale: observation.locale,
    mode: observation.mode,
    demand: observation.demand,
    promptProvenance: observation.promptProvenance,
    challengeID: observation.challengeID,
    audio: observation.audio,
    provider: observation.provider,
    transcriptSHA256: observation.transcriptSHA256,
    wordCount: observation.wordCount,
    startedAt: Timestamp.fromMillis(observation.startedAtMs),
    expiresAt: Timestamp.fromMillis(observation.expiresAtMs),
    observedAt: Timestamp.fromMillis(observation.observedAtMs),
  };
}

export const completeCompetitiveObservation = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 120,
    memory: "512MiB",
    serviceAccount: TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT,
    secrets: [deepgramManagementKey],
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    await assertSocialCallablesAvailable();
    await enforceCompetitiveObservationRateLimit(
      uid,
      "competitiveObservationComplete"
    );
    const firestore = getFirestore();
    const startedAt = Date.now();
    try {
      const result = await completeCompetitiveObservationWork(request.data, {
        claimAudio: async (input) => {
          const intentRef = firestore.collection("_competitiveCaptureIntents")
            .doc(uid).collection("captureIntents").doc(input.sessionID);
          const replayDigest = competitiveAudioReplayDigest(
            input.audio.sha256
          );
          const replayRef = firestore.collection(
            "_competitiveAudioReplayClaims"
          ).doc(replayDigest);
          const deletionRef = firestore.collection("_accountDeletionState")
            .doc(uid);
          return firestore.runTransaction(async (transaction) => {
            const deletionSnapshot = await transaction.get(deletionRef);
            const intentSnapshot = await transaction.get(intentRef);
            const replaySnapshot = await transaction.get(replayRef);
            assertAccountDeletionNotPending(deletionSnapshot.exists);
            const nowMs = Date.now();
            const intent = validateStoredCompetitiveObservationIntent(
              intentSnapshot.data(),
              uid,
              input.sessionID,
              socialDateMilliseconds
            );
            assertCompetitiveObservationIntentUsable(
              intent,
              uid,
              input.sessionID,
              nowMs
            );
            const processingIntent = competitiveObservationProcessingIntent(
              intent,
              input.audio.sha256,
              nowMs
            );
            if (replaySnapshot.exists) {
              throw new HttpsError(
                "already-exists",
                "This audio was already used for another observation."
              );
            }
            const claim = competitiveAudioReplayClaim(
              input.audio.sha256,
              nowMs
            );
            transaction.create(replayRef, {
              schemaVersion: claim.schemaVersion,
              digest: claim.digest,
              claimedAt: Timestamp.fromMillis(claim.claimedAtMs),
              expiresAt: Timestamp.fromMillis(claim.expiresAtMs),
            });
            transaction.update(intentRef, {
              status: "processing",
              audioSHA256: input.audio.sha256,
              processingStartedAt: Timestamp.fromMillis(nowMs),
              updatedAt: Timestamp.fromMillis(nowMs),
            });
            return processingIntent;
          });
        },
        transcribe: async (intent, audio) => {
          const token = await grantDeepgramTranscriptionToken(
            deepgramManagementKey.value(),
            {nowMs: Date.now(), signal: AbortSignal.timeout(8_000)}
          );
          return transcribeCompetitivePCM(
            token.accessToken,
            intent.locale,
            audio,
            {signal: AbortSignal.timeout(90_000)}
          );
        },
        commitObservation: async (claimedIntent, audio, provider) => {
          return commitCompetitiveObservation(
            uid,
            claimedIntent,
            audio,
            provider
          );
        },
      });
      logger.info("completeCompetitiveObservation completed", {
        operation: "completeCompetitiveObservation",
        status: "observed",
        latencyMs: Date.now() - startedAt,
      });
      return {
        schemaVersion: 1,
        sessionID: result.input.sessionID,
        transcript: result.provider.transcript,
        durationSeconds: result.input.audio.durationSeconds,
        wordCount: result.provider.wordCount,
        competitiveEligible: false,
        replayed: false,
      };
    } catch (error) {
      const status = error instanceof DeepgramObservationError ?
        error.reason : error instanceof ProviderGrantError ?
          error.reason : error instanceof HttpsError ?
            error.code : "unavailable";
      logger.error("completeCompetitiveObservation failed", {
        operation: "completeCompetitiveObservation",
        status,
        latencyMs: Date.now() - startedAt,
      });
      if (error instanceof HttpsError) throw error;
      if (error instanceof DeepgramObservationError &&
          error.reason === "provider-response") {
        throw new HttpsError("data-loss", "Speech observation was unusable.");
      }
      if ((error instanceof DeepgramObservationError &&
           error.reason === "configuration") ||
          (error instanceof ProviderGrantError &&
           error.reason === "configuration")) {
        throw new HttpsError(
          "failed-precondition",
          "Speech observation is not configured."
        );
      }
      throw new HttpsError(
        "unavailable",
        "Speech observation is unavailable. Try again."
      );
    }
  }
);

/**
 * Atomically writes or verifies one transcript-free server observation.
 * @param {string} uid Authenticated Firebase account ID.
 * @param {StoredCompetitiveObservationIntent} claimedIntent Claimed intent.
 * @param {CompetitiveObservationAudio} audio Validated PCM facts.
 * @param {DeepgramCompetitiveObservation} provider Provider observation.
 * @return {Promise<void>} Resolves after the first observation commit.
 */
async function commitCompetitiveObservation(
  uid: string,
  claimedIntent: StoredCompetitiveObservationIntent,
  audio: CompetitiveObservationAudio,
  provider: DeepgramCompetitiveObservation
): Promise<void> {
  const firestore = getFirestore();
  const intentRef = firestore.collection("_competitiveCaptureIntents")
    .doc(uid).collection("captureIntents").doc(claimedIntent.sessionID);
  const replayDigest = competitiveAudioReplayDigest(audio.sha256);
  const replayRef = firestore.collection("_competitiveAudioReplayClaims")
    .doc(replayDigest);
  const observationRef = firestore.collection("_competitiveObservations")
    .doc(uid).collection("observations").doc(claimedIntent.sessionID);
  const deletionRef = firestore.collection("_accountDeletionState").doc(uid);
  return firestore.runTransaction(async (transaction) => {
    const deletionSnapshot = await transaction.get(deletionRef);
    const intentSnapshot = await transaction.get(intentRef);
    const replaySnapshot = await transaction.get(replayRef);
    const observationSnapshot = await transaction.get(observationRef);
    assertAccountDeletionNotPending(deletionSnapshot.exists);
    const nowMs = Date.now();
    const intent = validateStoredCompetitiveObservationIntent(
      intentSnapshot.data(),
      uid,
      claimedIntent.sessionID,
      socialDateMilliseconds
    );
    assertCompetitiveObservationIntentUsable(
      intent,
      uid,
      claimedIntent.sessionID,
      nowMs
    );
    if (intent.audioSHA256 !== audio.sha256) {
      throw new HttpsError("data-loss", "Audio binding changed.");
    }
    const replayClaim = validateStoredCompetitiveAudioReplayClaim(
      replaySnapshot.data(),
      replayDigest,
      socialDateMilliseconds
    );
    if (replayClaim.claimedAtMs !== intent.processingStartedAtMs) {
      throw new HttpsError("data-loss", "Audio replay binding changed.");
    }
    if (observationSnapshot.exists) {
      throw new HttpsError(
        "already-exists",
        "This observation was already completed."
      );
    }
    if (intent.status !== "processing" ||
        intent.processingStartedAtMs === null ||
        intent.observationCompletedAtMs !== null) {
      throw new HttpsError("data-loss", "Observation state is incomplete.");
    }
    const candidate = competitiveObservationDocument(
      intent,
      audio,
      provider,
      nowMs
    );
    transaction.create(
      observationRef,
      competitiveObservationFirestoreDocument(candidate)
    );
    transaction.update(intentRef, {
      status: "observed",
      updatedAt: Timestamp.fromMillis(nowMs),
      observationCompletedAt: Timestamp.fromMillis(nowMs),
    });
  });
}

/**
 * Firestore representation of the public, non-PII peer profile.
 * @param {PublicProfileEnvelope} profile Raw public profile values.
 * @param {Timestamp} updatedAt Server-authored update timestamp.
 * @return {Record<string, unknown>} Firestore document data.
 */
function publicProfileDocument(
  profile: PublicProfileEnvelope,
  updatedAt: Timestamp
): Record<string, unknown> {
  return {
    accountID: profile.accountID,
    displayName: profile.displayName,
    rating: profile.rating,
    peakRating: profile.peakRating,
    currentStreak: profile.currentStreak,
    weeklyReps: profile.weeklyReps,
    weeklyDelta: profile.weeklyDelta,
    leagueTier: profile.leagueTier,
    updatedAt,
  };
}

/**
 * Reads a strict display name from an existing server-authored profile.
 * @param {unknown} value Public profile document data.
 * @return {string} Validated display name.
 */
function socialProfileDisplayName(value: unknown): string {
  if (!isRecord(value) || typeof value.displayName !== "string" ||
      value.displayName.length < 1 || value.displayName.length > 60) {
    throw new HttpsError(
      "failed-precondition",
      "Both speakers need a public profile before starting a challenge."
    );
  }
  return value.displayName;
}

type SocialRateOperation =
  "challengeCreate" | "challengeReaction" |
  "peerProfileRead" | "leagueListRead" |
  "friendInviteCreate" | "friendInviteAccept" |
  "friendLinkList" | "friendLinkRemove";

/**
 * Rejects every social mutation while account deletion is pending.
 * @param {boolean} pending Whether the server tombstone exists.
 */
function assertAccountDeletionNotPending(pending: boolean): void {
  if (!pending) return;
  throw new HttpsError(
    "failed-precondition",
    "Account deletion is already in progress.",
    {reason: "account-deletion-pending"}
  );
}

/**
 * Returns the deliberately indistinguishable invite lookup failure.
 * @return {HttpsError} Generic invite-unavailable error.
 */
function friendInviteUnavailableError(): HttpsError {
  return new HttpsError(
    "failed-precondition",
    "This friend invite is unavailable.",
    {reason: "friend-invite-unavailable"}
  );
}

/**
 * Returns exact server link facts, or null for security-favoring cleanup.
 * @param {unknown} value Candidate link document.
 * @param {string} accountID Owning account ID.
 * @param {string} friendAccountID Reciprocal account ID.
 * @return {ValidatedFriendLinkPair|null} Link facts.
 */
function validatedFriendLinkOrNull(
  value: unknown,
  accountID: string,
  friendAccountID: string
): ValidatedFriendLinkPair | null {
  try {
    return validateServerFriendLink(value, accountID, friendAccountID);
  } catch {
    return null;
  }
}

/**
 * Consumes a server-only fixed-window social-operation budget.
 * @param {string} uid Verified Firebase account ID.
 * @param {SocialRateOperation} operation Protected operation name.
 * @param {number} minuteLimit Per-minute ceiling.
 * @param {number} hourLimit Per-hour ceiling.
 * @return {Promise<void>} Resolves after the budget is consumed.
 */
async function enforceSocialRateLimit(
  uid: string,
  operation: SocialRateOperation,
  minuteLimit: number,
  hourLimit: number
): Promise<void> {
  const firestore = getFirestore();
  const ref = firestore.collection("_serverRateLimits").doc(uid);
  const deletionRef = firestore.collection("_accountDeletionState").doc(uid);
  await firestore.runTransaction(async (transaction) => {
    const deletionSnapshot = await transaction.get(deletionRef);
    const snapshot = await transaction.get(ref);
    assertAccountDeletionNotPending(deletionSnapshot.exists);
    const data = snapshot.data();
    const current = isRecord(data?.[operation]) ?
      data?.[operation] as Partial<WindowRateState> : undefined;
    const decision = nextWindowRateState(
      current,
      Date.now(),
      minuteLimit,
      hourLimit
    );
    if (!decision.allowed) {
      throw new HttpsError(
        "resource-exhausted",
        "Social requests are taking a short pause. Try again later."
      );
    }
    transaction.set(ref, {[operation]: decision.state}, {merge: true});
  });
}

type SocialCutoverMarkerLoader = () => Promise<unknown>;

/**
 * Fails closed unless the exact reviewed global social cutover is complete.
 * @param {SocialCutoverMarkerLoader} loadMarker Injectable marker read seam.
 * @return {Promise<void>} Resolves only when social callables may proceed.
 */
export async function assertSocialCallablesAvailable(
  loadMarker: SocialCutoverMarkerLoader = async () => {
    const snapshot = await getFirestore()
      .collection("_socialReferenceCutover").doc("current").get();
    return snapshot.data();
  }
): Promise<void> {
  let marker: unknown;
  try {
    marker = await loadMarker();
  } catch {
    marker = undefined;
  }
  if (isSocialReferenceCutoverComplete(marker)) return;
  throw new HttpsError(
    "failed-precondition",
    "Social features are temporarily unavailable.",
    {reason: "social-reference-cutover-incomplete"}
  );
}

export const getPeerProfile = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
    serviceAccount: SOCIAL_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    await assertSocialCallablesAvailable();
    const input = validateGetPeerProfileRequest(request.data);
    if (input.accountID === uid) {
      throw new HttpsError(
        "invalid-argument",
        "Choose another speaker's profile."
      );
    }
    await enforceSocialRateLimit(
      uid,
      "peerProfileRead",
      PEER_PROFILE_READ_MINUTE_LIMIT,
      PEER_PROFILE_READ_HOUR_LIMIT
    );
    const firestore = getFirestore();
    const snapshots = await firestore.getAll(
      firestore.collection("_accountDeletionState").doc(uid),
      firestore.collection("_accountDeletionState").doc(input.accountID),
      firestore.collection("_socialFriendLinks").doc(uid)
        .collection("friends").doc(input.accountID),
      firestore.collection("_socialFriendLinks").doc(input.accountID)
        .collection("friends").doc(uid),
      firestore.collection("_socialReferences").doc(uid),
      firestore.collection("_socialReferences").doc(input.accountID),
      firestore.collection("profiles_public").doc(input.accountID)
    );
    assertAccountDeletionNotPending(snapshots[0].exists || snapshots[1].exists);
    validateReciprocalFriendLinks(
      snapshots[2].data(),
      snapshots[3].data(),
      uid,
      input.accountID
    );
    validateReciprocalFriendManifests(
      snapshots[4].data(),
      snapshots[5].data(),
      uid,
      input.accountID
    );
    if (!snapshots[6].exists) {
      throw new HttpsError("not-found", "Peer profile not found.");
    }
    return {
      schemaVersion: SOCIAL_SCHEMA_VERSION,
      profile: validateStoredPublicProfile(
        snapshots[6].data(),
        input.accountID
      ),
    };
  }
);

export const listLeagueMembers = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
    serviceAccount: SOCIAL_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    await assertSocialCallablesAvailable();
    const input = validateListLeagueMembersRequest(request.data);
    await enforceSocialRateLimit(
      uid,
      "leagueListRead",
      LEAGUE_LIST_READ_MINUTE_LIMIT,
      LEAGUE_LIST_READ_HOUR_LIMIT
    );
    const firestore = getFirestore();
    const [deletionSnapshot, stateSnapshot] = await firestore.getAll(
      firestore.collection("_accountDeletionState").doc(uid),
      firestore.collection("_socialState").doc(uid)
    );
    assertAccountDeletionNotPending(deletionSnapshot.exists);
    const bucket = currentTrustedLeagueBucket(
      stateSnapshot.data(),
      Date.now()
    );
    const snapshot = await firestore.collection("leagues")
      .doc(bucket).collection("members")
      .orderBy("rating", "desc").limit(input.limit).get();
    return {
      schemaVersion: SOCIAL_SCHEMA_VERSION,
      bucket,
      members: snapshot.docs.map((document) =>
        validateStoredPublicProfile(document.data(), document.id)
      ),
    };
  }
);

export const createFriendInvite = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
    serviceAccount: SOCIAL_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    await assertSocialCallablesAvailable();
    const input = validateCreateFriendInviteRequest(request.data);
    await enforceSocialRateLimit(
      uid,
      "friendInviteCreate",
      FRIEND_INVITE_CREATE_MINUTE_LIMIT,
      FRIEND_INVITE_CREATE_HOUR_LIMIT
    );
    const secret = generateFriendInviteSecret();
    const nowMs = Date.now();
    const expiresAtMs = nowMs + FRIEND_INVITE_LIFETIME_MS;
    const firestore = getFirestore();
    const deletionRef = firestore.collection("_accountDeletionState").doc(uid);
    const inviteRef = firestore.collection("_socialFriendInvites")
      .doc(secret.tokenDigest);
    const accountInviteRefs = firestore.collection("_socialReferences")
      .doc(uid).collection("friendInvites");
    const accountInviteRef = accountInviteRefs.doc(secret.tokenDigest);

    await firestore.runTransaction(async (transaction) => {
      const deletionSnapshot = await transaction.get(deletionRef);
      const activeSnapshot = await transaction.get(
        accountInviteRefs.where("status", "==", "active")
          .limit(MAX_ACTIVE_FRIEND_INVITES + 1)
      );
      assertAccountDeletionNotPending(deletionSnapshot.exists);
      let activeCount = 0;
      const expiredDigests: string[] = [];
      for (const document of activeSnapshot.docs) {
        const reference = validateStoredFriendInviteReference(
          document.data(),
          uid,
          document.id,
          socialDateMilliseconds
        );
        if (reference.expiresAtMs <= nowMs) expiredDigests.push(document.id);
        else activeCount += 1;
      }
      if (activeCount >= MAX_ACTIVE_FRIEND_INVITES) {
        throw new HttpsError(
          "resource-exhausted",
          "Too many active friend invites. " +
            "Let one expire before creating another.",
          {reason: "friend-invite-capacity"}
        );
      }
      for (const expiredDigest of expiredDigests) {
        transaction.delete(accountInviteRefs.doc(expiredDigest));
        transaction.delete(
          firestore.collection("_socialFriendInvites").doc(expiredDigest)
        );
      }
      const createdAt = Timestamp.fromMillis(nowMs);
      const expiresAt = Timestamp.fromMillis(expiresAtMs);
      transaction.create(inviteRef, {
        schemaVersion: FRIENDSHIP_SCHEMA_VERSION,
        status: "active",
        tokenDigest: secret.tokenDigest,
        inviterAccountID: uid,
        inviterDisplayName: input.displayName,
        createdAt,
        expiresAt,
        acceptedAccountID: null,
        acceptorDisplayName: null,
        acceptedAt: null,
        pairID: null,
        revokedAt: null,
      });
      transaction.create(accountInviteRef, {
        schemaVersion: FRIENDSHIP_SCHEMA_VERSION,
        tokenDigest: secret.tokenDigest,
        accountID: uid,
        role: "inviter",
        status: "active",
        counterpartAccountID: null,
        expiresAt,
        updatedAt: createdAt,
      });
    });
    return {
      schemaVersion: FRIENDSHIP_SCHEMA_VERSION,
      inviteToken: secret.inviteToken,
      expiresAt: expiresAtMs / 1_000,
    };
  }
);

export const acceptFriendInvite = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 60,
    memory: "256MiB",
    serviceAccount: SOCIAL_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    await assertSocialCallablesAvailable();
    const input = validateAcceptFriendInviteRequest(request.data);
    await enforceSocialRateLimit(
      uid,
      "friendInviteAccept",
      FRIEND_INVITE_ACCEPT_MINUTE_LIMIT,
      FRIEND_INVITE_ACCEPT_HOUR_LIMIT
    );
    const tokenDigest = friendInviteDigest(input.inviteToken);
    const pairID = randomUUID().toUpperCase();
    const nowMs = Date.now();
    const linkedAt = Timestamp.fromMillis(nowMs);
    const firestore = getFirestore();
    const inviteRef = firestore.collection("_socialFriendInvites")
      .doc(tokenDigest);

    const outcome = await firestore.runTransaction(async (transaction) => {
      const inviteSnapshot = await transaction.get(inviteRef);
      const invite = validateStoredFriendInvite(
        inviteSnapshot.data(),
        tokenDigest,
        socialDateMilliseconds
      );
      const inviterAccountID = invite.inviterAccountID;
      if (inviterAccountID === uid) {
        throw new HttpsError(
          "invalid-argument",
          "Use this invite with another account.",
          {reason: "friend-invite-self"}
        );
      }
      if (invite.expiresAtMs <= nowMs) {
        throw friendInviteUnavailableError();
      }
      if (invite.status !== "active" && invite.status !== "accepted") {
        throw friendInviteUnavailableError();
      }

      const ownDeletionRef = firestore.collection("_accountDeletionState")
        .doc(uid);
      const inviterDeletionRef = firestore.collection("_accountDeletionState")
        .doc(inviterAccountID);
      const ownLinkRef = firestore.collection("_socialFriendLinks").doc(uid)
        .collection("friends").doc(inviterAccountID);
      const inviterLinkRef = firestore.collection("_socialFriendLinks")
        .doc(inviterAccountID).collection("friends").doc(uid);
      const ownReferencesRef = firestore.collection("_socialReferences")
        .doc(uid);
      const inviterReferencesRef = firestore.collection("_socialReferences")
        .doc(inviterAccountID);
      const ownInviteRef = ownReferencesRef.collection("friendInvites")
        .doc(tokenDigest);
      const inviterInviteRef = inviterReferencesRef.collection("friendInvites")
        .doc(tokenDigest);
      const ownDeletion = await transaction.get(ownDeletionRef);
      const inviterDeletion = await transaction.get(inviterDeletionRef);
      const ownLink = await transaction.get(ownLinkRef);
      const inviterLink = await transaction.get(inviterLinkRef);
      const ownReferences = await transaction.get(ownReferencesRef);
      const inviterReferences = await transaction.get(inviterReferencesRef);
      const ownInvite = await transaction.get(ownInviteRef);
      const inviterInvite = await transaction.get(inviterInviteRef);
      assertAccountDeletionNotPending(
        ownDeletion.exists || inviterDeletion.exists
      );

      if (invite.status === "accepted") {
        if (invite.acceptedAccountID !== uid || invite.pairID === null) {
          throw friendInviteUnavailableError();
        }
        const pair = validateReciprocalFriendLinks(
          ownLink.data(),
          inviterLink.data(),
          uid,
          inviterAccountID
        );
        validateReciprocalFriendManifests(
          ownReferences.data(),
          inviterReferences.data(),
          uid,
          inviterAccountID
        );
        validateBoundFriendInviteReference(
          ownInvite.data(),
          uid,
          tokenDigest,
          "acceptor",
          "accepted",
          inviterAccountID,
          socialDateMilliseconds
        );
        validateBoundFriendInviteReference(
          inviterInvite.data(),
          inviterAccountID,
          tokenDigest,
          "inviter",
          "accepted",
          uid,
          socialDateMilliseconds
        );
        if (pair.inviteDigest !== tokenDigest ||
            pair.pairID !== invite.pairID) {
          throw new HttpsError(
            "failed-precondition",
            "This friend connection is unavailable.",
            {reason: "friend-authorization-unavailable"}
          );
        }
        return {
          schemaVersion: FRIENDSHIP_SCHEMA_VERSION,
          friend: friendLinkEnvelope(pair),
        };
      }

      validateBoundFriendInviteReference(
        inviterInvite.data(),
        inviterAccountID,
        tokenDigest,
        "inviter",
        "active",
        null,
        socialDateMilliseconds
      );
      if (ownInvite.exists) {
        throw new HttpsError(
          "failed-precondition",
          "This friend invite is unavailable.",
          {reason: "friend-invite-unavailable"}
        );
      }
      const ownBaseManifest = validateCurrentFriendManifest(
        ownReferences.data(), uid
      );
      const inviterBaseManifest = validateCurrentFriendManifest(
        inviterReferences.data(), inviterAccountID
      );
      if (ownLink.exists || inviterLink.exists) {
        if (ownLink.exists && inviterLink.exists) {
          validateReciprocalFriendLinks(
            ownLink.data(), inviterLink.data(), uid, inviterAccountID
          );
          validateReciprocalFriendManifests(
            ownReferences.data(),
            inviterReferences.data(),
            uid,
            inviterAccountID
          );
          transaction.update(inviteRef, {
            status: "superseded",
            acceptedAccountID: uid,
            acceptorDisplayName: input.displayName,
            revokedAt: linkedAt,
          });
          transaction.update(inviterInviteRef, {
            status: "superseded",
            counterpartAccountID: uid,
            updatedAt: linkedAt,
          });
          return {superseded: true as const};
        }
        throw new HttpsError(
          "failed-precondition",
          "This friend connection is unavailable.",
          {reason: "friend-authorization-unavailable"}
        );
      }
      if (ownBaseManifest.friendAccountIDs.includes(inviterAccountID) ||
          inviterBaseManifest.friendAccountIDs.includes(uid)) {
        throw new HttpsError(
          "failed-precondition",
          "This friend connection is unavailable.",
          {reason: "friend-authorization-unavailable"}
        );
      }
      const ownManifest = socialReferenceManifestIncludingFriend(
        ownBaseManifest, uid, inviterAccountID
      );
      const inviterManifest = socialReferenceManifestIncludingFriend(
        inviterBaseManifest, inviterAccountID, uid
      );
      const ownLinkDocument = {
        schemaVersion: FRIEND_LINK_SCHEMA_VERSION,
        status: "active",
        accountID: uid,
        friendAccountID: inviterAccountID,
        pairID,
        friendDisplayName: invite.inviterDisplayName,
        inviteDigest: tokenDigest,
        inviteExpiresAt: Timestamp.fromMillis(invite.expiresAtMs),
        linkedAt,
      };
      const inviterLinkDocument = {
        schemaVersion: FRIEND_LINK_SCHEMA_VERSION,
        status: "active",
        accountID: inviterAccountID,
        friendAccountID: uid,
        pairID,
        friendDisplayName: input.displayName,
        inviteDigest: tokenDigest,
        inviteExpiresAt: Timestamp.fromMillis(invite.expiresAtMs),
        linkedAt,
      };
      transaction.create(ownLinkRef, ownLinkDocument);
      transaction.create(inviterLinkRef, inviterLinkDocument);
      transaction.set(ownReferencesRef, ownManifest);
      transaction.set(inviterReferencesRef, inviterManifest);
      transaction.update(inviteRef, {
        status: "accepted",
        acceptedAccountID: uid,
        acceptorDisplayName: input.displayName,
        acceptedAt: linkedAt,
        pairID,
      });
      transaction.update(inviterInviteRef, {
        status: "accepted",
        counterpartAccountID: uid,
        updatedAt: linkedAt,
      });
      transaction.create(ownInviteRef, {
        schemaVersion: FRIENDSHIP_SCHEMA_VERSION,
        tokenDigest,
        accountID: uid,
        role: "acceptor",
        status: "accepted",
        counterpartAccountID: inviterAccountID,
        expiresAt: Timestamp.fromMillis(invite.expiresAtMs),
        updatedAt: linkedAt,
      });
      return {
        schemaVersion: FRIENDSHIP_SCHEMA_VERSION,
        friend: friendLinkEnvelope(validateReciprocalFriendLinks(
          ownLinkDocument,
          inviterLinkDocument,
          uid,
          inviterAccountID
        )),
      };
    });
    if ("superseded" in outcome) throw friendInviteUnavailableError();
    return outcome;
  }
);

export const listFriendLinks = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
    serviceAccount: SOCIAL_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    await assertSocialCallablesAvailable();
    validateListFriendLinksRequest(request.data);
    await enforceSocialRateLimit(
      uid,
      "friendLinkList",
      FRIEND_LINK_LIST_MINUTE_LIMIT,
      FRIEND_LINK_LIST_HOUR_LIMIT
    );
    const firestore = getFirestore();
    return firestore.runTransaction(async (transaction) => {
      const deletion = await transaction.get(
        firestore.collection("_accountDeletionState").doc(uid)
      );
      const ownReferences = await transaction.get(
        firestore.collection("_socialReferences").doc(uid)
      );
      assertAccountDeletionNotPending(deletion.exists);
      const ownManifest = validateCurrentFriendManifest(
        ownReferences.data(), uid
      );
      const friendIDs = [...ownManifest.friendAccountIDs].sort();
      const friends: FriendLinkEnvelope[] = [];
      for (const friendAccountID of friendIDs) {
        const friendDeletion = await transaction.get(
          firestore.collection("_accountDeletionState").doc(friendAccountID)
        );
        const ownLink = await transaction.get(
          firestore.collection("_socialFriendLinks").doc(uid)
            .collection("friends").doc(friendAccountID)
        );
        const friendLink = await transaction.get(
          firestore.collection("_socialFriendLinks").doc(friendAccountID)
            .collection("friends").doc(uid)
        );
        const friendReferences = await transaction.get(
          firestore.collection("_socialReferences").doc(friendAccountID)
        );
        assertAccountDeletionNotPending(friendDeletion.exists);
        const pair = validateReciprocalFriendLinks(
          ownLink.data(), friendLink.data(), uid, friendAccountID
        );
        validateReciprocalFriendManifests(
          ownReferences.data(), friendReferences.data(), uid, friendAccountID
        );
        friends.push(friendLinkEnvelope(pair));
      }
      return {schemaVersion: FRIENDSHIP_SCHEMA_VERSION, friends};
    });
  }
);

export const removeFriendLink = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 60,
    memory: "256MiB",
    serviceAccount: SOCIAL_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    await assertSocialCallablesAvailable();
    const input = validateRemoveFriendLinkRequest(request.data);
    if (input.friendAccountID === uid) {
      throw new HttpsError("invalid-argument", "Choose another account.");
    }
    await enforceSocialRateLimit(
      uid,
      "friendLinkRemove",
      FRIEND_LINK_REMOVE_MINUTE_LIMIT,
      FRIEND_LINK_REMOVE_HOUR_LIMIT
    );
    const firestore = getFirestore();
    const friendAccountID = input.friendAccountID;
    return firestore.runTransaction(async (transaction) => {
      const ownDeletion = await transaction.get(
        firestore.collection("_accountDeletionState").doc(uid)
      );
      const friendDeletion = await transaction.get(
        firestore.collection("_accountDeletionState").doc(friendAccountID)
      );
      const ownLinkRef = firestore.collection("_socialFriendLinks").doc(uid)
        .collection("friends").doc(friendAccountID);
      const friendLinkRef = firestore.collection("_socialFriendLinks")
        .doc(friendAccountID).collection("friends").doc(uid);
      const ownReferencesRef = firestore.collection("_socialReferences")
        .doc(uid);
      const friendReferencesRef = firestore.collection("_socialReferences")
        .doc(friendAccountID);
      const ownLink = await transaction.get(ownLinkRef);
      const friendLink = await transaction.get(friendLinkRef);
      const ownReferences = await transaction.get(ownReferencesRef);
      const friendReferences = await transaction.get(friendReferencesRef);
      assertAccountDeletionNotPending(
        ownDeletion.exists || friendDeletion.exists
      );
      const ownFriendIDs = ownReferences.data()?.friendAccountIDs;
      const friendFriendIDs = friendReferences.data()?.friendAccountIDs;
      const ownHadFriend = Array.isArray(ownFriendIDs) &&
        ownFriendIDs.includes(friendAccountID);
      const friendHadOwner = Array.isArray(friendFriendIDs) &&
        friendFriendIDs.includes(uid);
      const candidateLinks = [
        ownLink.exists ? validatedFriendLinkOrNull(
          ownLink.data(), uid, friendAccountID
        ) : null,
        friendLink.exists ? validatedFriendLinkOrNull(
          friendLink.data(), friendAccountID, uid
        ) : null,
      ].filter((candidate): candidate is NonNullable<typeof candidate> =>
        candidate !== null
      );
      const uniqueLinks = candidateLinks.filter((candidate, index, all) =>
        all.findIndex((other) =>
          other.inviteDigest === candidate.inviteDigest
        ) === index
      );
      if (candidateLinks.some((link) => link.pairID !== input.pairID)) {
        throw new HttpsError(
          "failed-precondition",
          "This friend connection has changed.",
          {reason: "friend-link-generation-mismatch"}
        );
      }
      const receipts: Array<{
        link: ReturnType<typeof validateServerFriendLink>;
        inviteRef: DocumentReference;
        ownInviteRef: DocumentReference;
        friendInviteRef: DocumentReference;
        inviteSnapshot: DocumentSnapshot;
        ownInviteSnapshot: DocumentSnapshot;
        friendInviteSnapshot: DocumentSnapshot;
      }> = [];
      for (const link of uniqueLinks) {
        const inviteRef = firestore.collection("_socialFriendInvites")
          .doc(link.inviteDigest);
        const ownInviteRef = ownReferencesRef.collection("friendInvites")
          .doc(link.inviteDigest);
        const friendInviteRef = friendReferencesRef
          .collection("friendInvites").doc(link.inviteDigest);
        receipts.push({
          link,
          inviteRef,
          ownInviteRef,
          friendInviteRef,
          inviteSnapshot: await transaction.get(inviteRef),
          ownInviteSnapshot: await transaction.get(ownInviteRef),
          friendInviteSnapshot: await transaction.get(friendInviteRef),
        });
      }
      const revokedAt = Timestamp.now();
      for (const receipt of receipts) {
        let invite: ReturnType<typeof validateStoredFriendInvite> | null = null;
        try {
          invite = receipt.inviteSnapshot.exists ? validateStoredFriendInvite(
            receipt.inviteSnapshot.data(),
            receipt.link.inviteDigest,
            socialDateMilliseconds
          ) : null;
        } catch {
          invite = null;
        }
        const participants = invite ? new Set([
          invite.inviterAccountID,
          invite.acceptedAccountID,
        ]) : new Set<string>();
        const matchesLink = invite !== null &&
          (invite.status === "accepted" || invite.status === "revoked") &&
          invite.pairID === receipt.link.pairID && participants.size === 2 &&
          participants.has(uid) && participants.has(friendAccountID);
        if (receipt.inviteSnapshot.exists) {
          if (matchesLink) {
            transaction.update(receipt.inviteRef, {
              status: "revoked",
              revokedAt,
            });
          } else {
            transaction.delete(receipt.inviteRef);
          }
        }
        for (const reference of [
          {
            snapshot: receipt.ownInviteSnapshot,
            ref: receipt.ownInviteRef,
            accountID: uid,
            counterpartAccountID: friendAccountID,
          },
          {
            snapshot: receipt.friendInviteSnapshot,
            ref: receipt.friendInviteRef,
            accountID: friendAccountID,
            counterpartAccountID: uid,
          },
        ]) {
          if (!reference.snapshot.exists) continue;
          let referenceMatches = false;
          if (matchesLink && invite) {
            const role = invite.inviterAccountID === reference.accountID ?
              "inviter" : "acceptor";
            try {
              const stored = validateStoredFriendInviteReference(
                reference.snapshot.data(),
                reference.accountID,
                receipt.link.inviteDigest,
                socialDateMilliseconds
              );
              referenceMatches = stored.role === role &&
                (stored.status === "accepted" || stored.status === "revoked") &&
                stored.counterpartAccountID === reference.counterpartAccountID;
            } catch {
              referenceMatches = false;
            }
          }
          if (referenceMatches) {
            transaction.update(reference.ref, {
              status: "revoked",
              updatedAt: revokedAt,
            });
          } else {
            transaction.delete(reference.ref);
          }
        }
      }
      transaction.delete(ownLinkRef);
      transaction.delete(friendLinkRef);
      if (ownReferences.exists) {
        transaction.update(ownReferencesRef, {
          friendAccountIDs: FieldValue.arrayRemove(friendAccountID),
        });
      }
      if (friendReferences.exists) {
        transaction.update(friendReferencesRef, {
          friendAccountIDs: FieldValue.arrayRemove(uid),
        });
      }
      const removed = ownLink.exists || friendLink.exists ||
        ownHadFriend || friendHadOwner;
      return {
        schemaVersion: FRIENDSHIP_SCHEMA_VERSION,
        friendAccountID,
        pairID: input.pairID,
        removed,
      };
    });
  }
);

export const recordPeerSession = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 60,
    memory: "256MiB",
    serviceAccount: SOCIAL_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    await assertSocialCallablesAvailable();
    const input = validateRecordPeerSessionRequest(request.data);
    const firestore = getFirestore();
    const nowMs = Date.now();
    const updatedAt = Timestamp.fromMillis(nowMs);
    const stateRef = firestore.collection("_socialState").doc(uid);
    const markerRef = stateRef.collection("processedSessions")
      .doc(input.sessionID);
    const evidenceRef = firestore.collection("_verifiedSessionEvidence")
      .doc(uid).collection("sessions").doc(input.sessionID);
    const referencesRef = firestore.collection("_socialReferences").doc(uid);
    const publicProfileRef = firestore.collection("profiles_public").doc(uid);
    const deletionRef = firestore.collection("_accountDeletionState").doc(uid);

    return firestore.runTransaction(async (transaction) => {
      const deletionSnapshot = await transaction.get(deletionRef);
      const evidenceSnapshot = await transaction.get(evidenceRef);
      const stateSnapshot = await transaction.get(stateRef);
      const markerSnapshot = await transaction.get(markerRef);
      const referencesSnapshot = await transaction.get(referencesRef);
      assertAccountDeletionNotPending(deletionSnapshot.exists);
      const evidence = validateVerifiedSessionEvidence(
        evidenceSnapshot.data(),
        input.sessionID,
        nowMs
      );
      const stateData = stateSnapshot.data();
      const previous = storedSocialState(
        isRecord(stateData) && stateData.schemaVersion === 2 ? stateData : null,
        input.displayName,
        nowMs
      );
      const marker = markerSnapshot.data();
      const references = validateSocialReferenceManifest(
        referencesSnapshot.data(),
        uid
      );
      if (isRecord(marker) && marker.schemaVersion === 2 &&
          marker.evidenceSource === "noum-server-evaluator") {
        return {
          schemaVersion: SOCIAL_SCHEMA_VERSION,
          sessionID: input.sessionID,
          processed: false,
          profile: profileFromSocialState(previous, uid, nowMs),
        };
      }
      const advanced = advanceSocialState(
        previous,
        evidence,
        uid,
        input.displayName,
        nowMs
      );
      const profileData = publicProfileDocument(advanced.profile, updatedAt);

      if (previous.currentBucket &&
          previous.currentBucket !== advanced.state.currentBucket) {
        transaction.delete(
          firestore.collection("leagues").doc(previous.currentBucket)
            .collection("members").doc(uid)
        );
      }
      transaction.set(stateRef, {
        ...advanced.state,
        updatedAt,
      });
      transaction.set(markerRef, {
        schemaVersion: 2,
        sessionID: input.sessionID,
        evidenceSource: "noum-server-evaluator",
        sessionDate: Timestamp.fromMillis(evidence.dateMs),
        isRated: evidence.isRated,
        ratingDelta: advanced.ratingDelta,
        processedAt: updatedAt,
      });
      transaction.set(publicProfileRef, profileData);
      const updatedReferences =
        socialReferenceManifestUpdatingLeagueMembership(
          references,
          uid,
          previous.currentBucket,
          advanced.state.currentBucket
        );
      transaction.set(referencesRef, updatedReferences);
      if (advanced.state.currentBucket) {
        transaction.set(
          firestore.collection("leagues").doc(advanced.state.currentBucket)
            .collection("members").doc(uid),
          profileData
        );
      }
      return {
        schemaVersion: SOCIAL_SCHEMA_VERSION,
        sessionID: input.sessionID,
        processed: true,
        profile: advanced.profile,
      };
    });
  }
);

export const createChallenge = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 60,
    memory: "256MiB",
    serviceAccount: SOCIAL_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    await assertSocialCallablesAvailable();
    const input = validateCreateChallengeRequest(request.data);
    if (input.opponentAccountID === uid) {
      throw new HttpsError(
        "invalid-argument",
        "Choose another speaker for this challenge."
      );
    }
    await enforceSocialRateLimit(
      uid,
      "challengeCreate",
      CHALLENGE_CREATE_MINUTE_LIMIT,
      CHALLENGE_CREATE_HOUR_LIMIT
    );
    const firestore = getFirestore();
    const challengeRef = firestore.collection("challenges")
      .doc(input.challengeID);

    return firestore.runTransaction(async (transaction) => {
      const existing = await transaction.get(challengeRef);
      if (existing.exists) {
        const challenge = validateStoredChallenge(
          existing.data(),
          input.challengeID
        );
        if (challenge.creatorAccountID !== uid ||
            challenge.opponentAccountID !== input.opponentAccountID ||
            challenge.prompt !== input.prompt) {
          throw new HttpsError(
            "already-exists",
            "That challenge identifier is already in use."
          );
        }
        return {
          schemaVersion: SOCIAL_SCHEMA_VERSION,
          created: false,
          challenge: challengeEnvelope(challenge, uid),
        };
      }

      const creatorFriendLink = await transaction.get(
        firestore.collection("_socialFriendLinks").doc(uid)
          .collection("friends").doc(input.opponentAccountID)
      );
      const opponentFriendLink = await transaction.get(
        firestore.collection("_socialFriendLinks").doc(input.opponentAccountID)
          .collection("friends").doc(uid)
      );
      const creatorDeletion = await transaction.get(
        firestore.collection("_accountDeletionState").doc(uid)
      );
      const opponentDeletion = await transaction.get(
        firestore.collection("_accountDeletionState")
          .doc(input.opponentAccountID)
      );
      assertAccountDeletionNotPending(
        creatorDeletion.exists || opponentDeletion.exists
      );
      validateReciprocalFriendLinks(
        creatorFriendLink.data(),
        opponentFriendLink.data(),
        uid,
        input.opponentAccountID
      );
      const creatorProfile = await transaction.get(
        firestore.collection("profiles_public").doc(uid)
      );
      const opponentProfile = await transaction.get(
        firestore.collection("profiles_public").doc(input.opponentAccountID)
      );
      const creatorReferencesRef = firestore.collection("_socialReferences")
        .doc(uid);
      const opponentReferencesRef = firestore.collection("_socialReferences")
        .doc(input.opponentAccountID);
      const creatorReferencesSnapshot = await transaction.get(
        creatorReferencesRef
      );
      const opponentReferencesSnapshot = await transaction.get(
        opponentReferencesRef
      );
      validateReciprocalFriendManifests(
        creatorReferencesSnapshot.data(),
        opponentReferencesSnapshot.data(),
        uid,
        input.opponentAccountID
      );
      if (!creatorProfile.exists || !opponentProfile.exists) {
        throw new HttpsError(
          "failed-precondition",
          "Both speakers need a public profile before starting a challenge."
        );
      }
      const nowMs = Date.now();
      const challenge: Record<string, unknown> = {
        schemaVersion: CHALLENGE_DOCUMENT_SCHEMA_VERSION,
        id: input.challengeID,
        prompt: input.prompt,
        promptDigest: promptDigest(input.prompt),
        createdAt: Timestamp.fromMillis(nowMs),
        expiresAt: Timestamp.fromMillis(nowMs + CHALLENGE_LIFETIME_MS),
        creatorID: stableLegacyUUID(uid),
        creatorName: socialProfileDisplayName(creatorProfile.data()),
        creatorAccountID: uid,
        opponentID: stableLegacyUUID(input.opponentAccountID),
        opponentName: socialProfileDisplayName(opponentProfile.data()),
        opponentAccountID: input.opponentAccountID,
        participantIDs: [uid, input.opponentAccountID],
        completedAt: null,
      };
      const creatorReferences = socialReferenceManifestIncludingChallenge(
        creatorReferencesSnapshot.data(),
        uid,
        input.challengeID
      );
      const opponentReferences = socialReferenceManifestIncludingChallenge(
        opponentReferencesSnapshot.data(),
        input.opponentAccountID,
        input.challengeID
      );
      transaction.create(challengeRef, challenge);
      transaction.set(creatorReferencesRef, creatorReferences);
      transaction.set(opponentReferencesRef, opponentReferences);
      return {
        schemaVersion: SOCIAL_SCHEMA_VERSION,
        created: true,
        challenge: challengeEnvelope(challenge, uid),
      };
    });
  }
);

export const submitChallengeResult = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 60,
    memory: "256MiB",
    serviceAccount: SOCIAL_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    await assertSocialCallablesAvailable();
    const input = validateSubmitChallengeResultRequest(request.data);
    const firestore = getFirestore();
    const challengeRef = firestore.collection("challenges")
      .doc(input.challengeID);
    const evidenceRef = firestore.collection("_verifiedSessionEvidence")
      .doc(uid).collection("sessions").doc(input.sessionID);
    const replayRef = firestore.collection("_socialState").doc(uid)
      .collection("challengeResults").doc(input.sessionID);

    return firestore.runTransaction(async (transaction) => {
      const challengeSnapshot = await transaction.get(challengeRef);
      if (!challengeSnapshot.exists) {
        throw new HttpsError("not-found", "Challenge not found.");
      }
      const challenge = validateStoredChallenge(
        challengeSnapshot.data(),
        input.challengeID
      );
      const side = challengeSide(challenge, uid);
      const otherSide = side === "creator" ? "opponent" : "creator";
      const otherAccountID = challenge[`${otherSide}AccountID`];
      if (typeof otherAccountID !== "string") {
        throw new Error("Corrupt challenge participant identity.");
      }
      const submissions = challengeRef.collection("submissions");
      const ownSubmissionRef = submissions.doc(uid);
      const otherSubmissionRef = submissions.doc(otherAccountID);
      const combinedRef = challengeRef.collection("combined").doc("result");
      const ownDeletionRef = firestore.collection("_accountDeletionState")
        .doc(uid);
      const otherDeletionRef = firestore.collection("_accountDeletionState")
        .doc(otherAccountID);
      const ownDeletionSnapshot = await transaction.get(ownDeletionRef);
      const otherDeletionSnapshot = await transaction.get(otherDeletionRef);
      const evidenceSnapshot = await transaction.get(evidenceRef);
      const replaySnapshot = await transaction.get(replayRef);
      const ownSubmissionSnapshot = await transaction.get(ownSubmissionRef);
      const otherSubmissionSnapshot = await transaction.get(otherSubmissionRef);
      const combinedSnapshot = await transaction.get(combinedRef);
      assertAccountDeletionNotPending(
        ownDeletionSnapshot.exists || otherDeletionSnapshot.exists
      );

      if (ownSubmissionSnapshot.exists) {
        const ownSubmission = validateChallengeSubmission(
          ownSubmissionSnapshot.data(),
          input.challengeID,
          uid,
          side
        );
        const replay = replaySnapshot.data();
        if (ownSubmission.sessionID === input.sessionID &&
            isRecord(replay) && replay.schemaVersion === 2 &&
            replay.challengeID === input.challengeID && replay.side === side) {
          const combined = combinedSnapshot.exists ?
            validateCombinedChallengeResult(
              combinedSnapshot.data(),
              input.challengeID
            ) : undefined;
          return {
            schemaVersion: SOCIAL_SCHEMA_VERSION,
            sessionID: input.sessionID,
            submitted: false,
            challenge: challengeEnvelope(
              challenge,
              uid,
              ownSubmission,
              combined
            ),
          };
        }
        throw new HttpsError(
          "failed-precondition",
          "Your result for this challenge is already recorded."
        );
      }
      if (combinedSnapshot.exists) {
        throw new Error("Combined result exists without caller submission.");
      }
      if (replaySnapshot.exists) {
        throw new HttpsError(
          "already-exists",
          "That session has already been used for a challenge."
        );
      }

      const nowMs = Date.now();
      const expiresAt = socialDateMilliseconds(challenge.expiresAt);
      if (expiresAt === null || nowMs > expiresAt) {
        throw new HttpsError(
          "failed-precondition",
          "This challenge has expired.",
          {reason: "challenge-expired"}
        );
      }
      const evidence = validateVerifiedSessionEvidence(
        evidenceSnapshot.data(),
        input.sessionID,
        nowMs
      );
      assertEvidenceBoundToChallenge(evidence, challenge, nowMs);
      const submittedAt = Timestamp.fromMillis(nowMs);
      const ownSubmission = challengeSubmissionDocument(
        input.challengeID,
        uid,
        side,
        evidence,
        submittedAt
      );
      const otherSubmission = otherSubmissionSnapshot.exists ?
        validateChallengeSubmission(
          otherSubmissionSnapshot.data(),
          input.challengeID,
          otherAccountID,
          otherSide
        ) : null;
      transaction.create(ownSubmissionRef, ownSubmission);
      transaction.set(replayRef, {
        schemaVersion: 2,
        challengeID: input.challengeID,
        sessionID: input.sessionID,
        side,
        submittedAt,
      });
      let combined: ReturnType<typeof combinedChallengeDocument> | undefined;
      if (otherSubmission) {
        const creatorSubmission: ChallengeSubmission = side === "creator" ?
          ownSubmission : otherSubmission;
        const opponentSubmission: ChallengeSubmission = side === "opponent" ?
          ownSubmission : otherSubmission;
        combined = combinedChallengeDocument(
          input.challengeID,
          creatorSubmission,
          opponentSubmission,
          submittedAt
        );
        transaction.create(combinedRef, combined);
        transaction.update(challengeRef, {completedAt: submittedAt});
      }
      return {
        schemaVersion: SOCIAL_SCHEMA_VERSION,
        sessionID: input.sessionID,
        submitted: true,
        challenge: challengeEnvelope(
          challenge,
          uid,
          ownSubmission,
          combined
        ),
      };
    });
  }
);

export const setChallengeReaction = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
    serviceAccount: SOCIAL_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    await assertSocialCallablesAvailable();
    const input = validateSetChallengeReactionRequest(request.data);
    await enforceSocialRateLimit(
      uid,
      "challengeReaction",
      CHALLENGE_REACTION_MINUTE_LIMIT,
      CHALLENGE_REACTION_HOUR_LIMIT
    );
    const firestore = getFirestore();
    const challengeRef = firestore.collection("challenges")
      .doc(input.challengeID);

    return firestore.runTransaction(async (transaction) => {
      const challengeSnapshot = await transaction.get(challengeRef);
      if (!challengeSnapshot.exists) {
        throw new HttpsError("not-found", "Challenge not found.");
      }
      const challenge = validateStoredChallenge(
        challengeSnapshot.data(),
        input.challengeID
      );
      const side = challengeSide(challenge, uid);
      const otherSide = side === "creator" ? "opponent" : "creator";
      const otherAccountID = challenge[`${otherSide}AccountID`];
      if (typeof otherAccountID !== "string") {
        throw new Error("Corrupt challenge participant identity.");
      }
      const ownSubmissionRef = challengeRef.collection("submissions").doc(uid);
      const otherSubmissionRef = challengeRef.collection("submissions")
        .doc(otherAccountID);
      const combinedRef = challengeRef.collection("combined").doc("result");
      const ownDeletionSnapshot = await transaction.get(
        firestore.collection("_accountDeletionState").doc(uid)
      );
      const otherDeletionSnapshot = await transaction.get(
        firestore.collection("_accountDeletionState").doc(otherAccountID)
      );
      const ownSnapshot = await transaction.get(ownSubmissionRef);
      const otherSnapshot = await transaction.get(otherSubmissionRef);
      const combinedSnapshot = await transaction.get(combinedRef);
      assertAccountDeletionNotPending(
        ownDeletionSnapshot.exists || otherDeletionSnapshot.exists
      );
      if (!ownSnapshot.exists || !otherSnapshot.exists ||
          !combinedSnapshot.exists) {
        throw new HttpsError(
          "failed-precondition",
          "Reactions unlock after both speakers finish."
        );
      }
      const ownSubmission = validateChallengeSubmission(
        ownSnapshot.data(),
        input.challengeID,
        uid,
        side
      );
      validateChallengeSubmission(
        otherSnapshot.data(),
        input.challengeID,
        otherAccountID,
        otherSide
      );
      const combined = validateCombinedChallengeResult(
        combinedSnapshot.data(),
        input.challengeID
      );
      if (ownSubmission.reaction === input.reaction) {
        return {
          schemaVersion: SOCIAL_SCHEMA_VERSION,
          updated: false,
          challenge: challengeEnvelope(challenge, uid, ownSubmission, combined),
        };
      }
      const reactedAt = Timestamp.now();
      const submissionUpdates = {
        reaction: input.reaction,
        reactedAt,
      };
      const combinedUpdates = {
        [`${side}Reaction`]: input.reaction,
        [`${side}ReactedAt`]: reactedAt,
      };
      transaction.update(ownSubmissionRef, submissionUpdates);
      transaction.update(combinedRef, combinedUpdates);
      return {
        schemaVersion: SOCIAL_SCHEMA_VERSION,
        updated: true,
        challenge: challengeEnvelope(
          challenge,
          uid,
          {...ownSubmission, ...submissionUpdates},
          {...combined, ...combinedUpdates}
        ),
      };
    });
  }
);

export const syncRecommendationState = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
    serviceAccount: RECOMMENDATION_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    const input = validateRecommendationMutation(request.data);
    assertRecommendationMutationIdentity(input.expectedAccountID, uid);
    const firestore = getFirestore();
    const deletionRef = firestore.collection("_accountDeletionState").doc(uid);
    const stateRef = firestore.collection("users").doc(uid)
      .collection("recommendations").doc("state");

    return firestore.runTransaction(async (transaction) => {
      const deletionSnapshot = await transaction.get(deletionRef);
      const stateSnapshot = await transaction.get(stateRef);
      assertAccountDeletionNotPending(deletionSnapshot.exists);
      const current = normalizeStoredRecommendationState(
        stateSnapshot.exists ? stateSnapshot.data() : undefined
      );
      const decision = decideRecommendationMutation(current, input);
      if (decision.status === "committed") {
        transaction.set(stateRef, {
          ...decision.state,
          updatedAt: Timestamp.now(),
        });
      }
      return decision;
    });
  }
);

interface GrowthAggregateRateState {
  dayStartMilliseconds: number;
  count: number;
}

/**
 * Advances the server-only daily aggregate admission counter.
 * @param {unknown} current Existing counter state.
 * @param {number} nowMilliseconds Trusted server wall clock.
 * @return {GrowthAggregateRateState} Next bounded counter state.
 */
function nextGrowthAggregateRateState(
  current: unknown,
  nowMilliseconds: number
): GrowthAggregateRateState {
  const dayStartMilliseconds = nowMilliseconds -
    (nowMilliseconds % 86_400_000);
  if (!isRecord(current) ||
      current.dayStartMilliseconds !== dayStartMilliseconds ||
      typeof current.count !== "number" ||
      !Number.isSafeInteger(current.count)) {
    return {dayStartMilliseconds, count: 1};
  }
  if (current.count >= 8) {
    throw new HttpsError(
      "resource-exhausted",
      "Aggregate reporting is taking a short pause."
    );
  }
  return {dayStartMilliseconds, count: current.count + 1};
}

/**
 * Converts validated counters to atomic Firestore increments.
 * @param {Record<string, number>} values Validated counter map.
 * @return {Record<string, FieldValue>} Atomic increments.
 */
function growthCountIncrements(
  values: Record<string, number>
): Record<string, FieldValue> {
  return Object.fromEntries(Object.entries(values).map(([key, value]) => [
    key,
    FieldValue.increment(value),
  ]));
}

/**
 * Produces a bounded Firestore document component from a version string.
 * @param {string} value Validated version string.
 * @return {string} Safe document component.
 */
function growthVersionToken(value: string): string {
  return value.replace(/[^0-9a-z-]/giu, "_");
}

/**
 * Accepts one explicit-consent, content-free daily aggregate. Auth and App
 * Check protect admission, but neither UID nor any event-level identifier is
 * written to the aggregate or idempotency documents.
 */
export const recordGrowthAggregate = onCall(
  {
    enforceAppCheck: true,
    serviceAccount: GROWTH_RUNTIME_SERVICE_ACCOUNT,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    const input = validateGrowthAggregate(request.data);
    const periodKey = growthAggregatePeriodKey(input);
    const periodDocumentID = [
      periodKey,
      growthVersionToken(input.appVersion),
      growthVersionToken(input.buildNumber),
    ].join("_");
    const cohortDocumentID = [
      input.activationCohortDay,
      growthVersionToken(input.appVersion),
      growthVersionToken(input.buildNumber),
    ].join("_");
    const firestore = getFirestore();
    const deletionRef = firestore.collection("_accountDeletionState").doc(uid);
    const markerRef = firestore.collection("_growthAggregateBatches")
      .doc(input.batchID);
    const periodRef = firestore.collection("_growthAggregatePeriods")
      .doc(periodDocumentID);
    const cohortRef = firestore.collection("_growthActivationCohorts")
      .doc(cohortDocumentID);
    const rateRef = firestore.collection("_serverRateLimits").doc(uid);

    return firestore.runTransaction(async (transaction) => {
      const deletionSnapshot = await transaction.get(deletionRef);
      const markerSnapshot = await transaction.get(markerRef);
      assertAccountDeletionNotPending(deletionSnapshot.exists);
      if (markerSnapshot.exists) {
        return {accepted: true, duplicate: true, batchID: input.batchID};
      }
      const rateSnapshot = await transaction.get(rateRef);
      const rateData = rateSnapshot.exists ? rateSnapshot.data() : undefined;
      const nextRate = nextGrowthAggregateRateState(
        isRecord(rateData?.growthAggregate) ?
          rateData.growthAggregate : undefined,
        Date.now()
      );

      transaction.set(rateRef, {growthAggregate: nextRate}, {merge: true});
      transaction.create(markerRef, {
        schemaVersion: 2,
        periodKey,
        activationCohortDay: input.activationCohortDay,
        createdAt: Timestamp.now(),
        expiresAt: Timestamp.fromMillis(
          input.periodEndMilliseconds + 35 * 86_400_000
        ),
      });
      transaction.set(periodRef, {
        schemaVersion: 2,
        appVersion: input.appVersion,
        buildNumber: input.buildNumber,
        periodStart: Timestamp.fromMillis(input.periodStartMilliseconds),
        periodEnd: Timestamp.fromMillis(input.periodEndMilliseconds),
        batchCount: FieldValue.increment(1),
        eventCounts: growthCountIncrements(input.eventCounts),
        paywallSourceCounts: growthCountIncrements(
          input.paywallSourceCounts
        ),
        planSelectionCounts: growthCountIncrements(
          input.planSelectionCounts
        ),
        trialEligibilityCounts: growthCountIncrements(
          input.trialEligibilityCounts
        ),
        inactiveReasonCounts: growthCountIncrements(
          input.inactiveReasonCounts
        ),
        notificationOpenCounts: growthCountIncrements(
          input.notificationOpenCounts
        ),
        activeDayIndexCounts: growthCountIncrements(
          input.activeDayIndexCounts
        ),
        firstWrittenValueDurationBucketCounts: growthCountIncrements(
          input.firstWrittenValueDurationBucketCounts
        ),
        secondPracticeWithin48HoursCount: FieldValue.increment(
          input.secondPracticeWithin48HoursCount
        ),
        weeklyReadAmongDay1ReturnersCount: FieldValue.increment(
          input.weeklyReadAmongDay1ReturnersCount
        ),
        estimatedAICostMicros: FieldValue.increment(
          input.estimatedAICostMicros
        ),
        estimatedAICostCurrency: input.estimatedAICostCurrency,
        unpricedAIUsageCount: FieldValue.increment(
          input.unpricedAIUsageCount
        ),
        aiBudgetReservationCount: FieldValue.increment(
          input.aiBudgetReservationCount
        ),
        updatedAt: Timestamp.now(),
      }, {merge: true});
      transaction.set(cohortRef, {
        schemaVersion: 2,
        activationCohortDay: input.activationCohortDay,
        appVersion: input.appVersion,
        buildNumber: input.buildNumber,
        batchCount: FieldValue.increment(1),
        accountActivatedCount: FieldValue.increment(
          input.eventCounts["growth.lifecycle.accountActivated"] ?? 0
        ),
        activeDayIndexCounts: growthCountIncrements(
          input.activeDayIndexCounts
        ),
        secondPracticeWithin48HoursCount: FieldValue.increment(
          input.secondPracticeWithin48HoursCount
        ),
        weeklyReadAmongDay1ReturnersCount: FieldValue.increment(
          input.weeklyReadAmongDay1ReturnersCount
        ),
        updatedAt: Timestamp.now(),
      }, {merge: true});
      return {accepted: true, duplicate: false, batchID: input.batchID};
    });
  }
);

/**
 * Writes one verified, anonymous App Store lifecycle projection exactly once.
 * The digest is a one-way replay marker; no Apple JWS, receipt, transaction,
 * product, account, or device identifier is retained.
 * @param {AppStoreLifecycleProjection} projection Verified bounded counters.
 * @return {Promise<boolean>} True when Apple retried an existing notification.
 */
async function recordAppStoreLifecycleProjection(
  projection: AppStoreLifecycleProjection
): Promise<boolean> {
  const firestore = getFirestore();
  const markerRef = firestore.collection("_appStoreNotificationMarkers")
    .doc(projection.notificationDigest);
  const periodRef = firestore.collection("_growthAggregatePeriods").doc([
    projection.periodKey,
    "appstore-notifications-v2",
    projection.environment,
  ].join("_"));
  return firestore.runTransaction(async (transaction) => {
    const markerSnapshot = await transaction.get(markerRef);
    if (markerSnapshot.exists) return true;

    const eventNames = Object.keys(projection.eventCounts);
    transaction.create(markerRef, {
      schemaVersion: 1,
      source: projection.source,
      environment: projection.environment,
      periodKey: projection.periodKey,
      lifecycleEventCount: eventNames.length,
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromMillis(
        Date.now() + APP_STORE_NOTIFICATION_MARKER_RETENTION_MILLISECONDS
      ),
    });
    transaction.set(periodRef, {
      schemaVersion: 1,
      source: projection.source,
      environment: projection.environment,
      periodStart: Timestamp.fromMillis(projection.periodStartMilliseconds),
      periodEnd: Timestamp.fromMillis(projection.periodEndMilliseconds),
      verifiedNotificationCount: FieldValue.increment(1),
      ignoredNotificationCount: FieldValue.increment(
        eventNames.length === 0 ? 1 : 0
      ),
      ...(eventNames.length > 0 ? {
        eventCounts: growthCountIncrements(
          projection.eventCounts as Record<string, number>
        ),
      } : {}),
      updatedAt: Timestamp.now(),
    }, {merge: true});
    return false;
  });
}

/**
 * Handles one environment-specific Apple Notifications V2 endpoint.
 * @param {Request} request Public HTTPS request from Apple.
 * @param {Response} response Empty response recognized by Apple.
 * @param {Environment.PRODUCTION|Environment.SANDBOX} environment Target.
 * @param {string} enabled Exact operator-controlled feature switch.
 * @return {Promise<void>} Resolves after response completion.
 */
async function handleAppStoreServerNotification(
  request: Request,
  response: Response,
  environment: Environment.PRODUCTION | Environment.SANDBOX,
  enabled: string
): Promise<void> {
  const environmentLabel = environment === Environment.PRODUCTION ?
    "production" : "sandbox";
  try {
    if (request.method !== "POST" || !request.is("application/json")) {
      throw new AppStoreNotificationProcessingError(
        "request-malformed",
        false
      );
    }
    const configuration = parseAppStoreNotificationConfiguration({
      enabled,
      appAppleID: appStoreAppAppleID.value(),
      rootCertificatesBase64: appStoreRootCertificates.value(),
      environment,
    });
    const signedPayload = appStoreSignedPayload(request.body);
    const verifier = createAppStoreNotificationVerifier(configuration);
    const projection = await verifyAndProjectAppStoreNotification(
      signedPayload,
      verifier,
      configuration
    );
    const duplicate = await recordAppStoreLifecycleProjection(projection);
    logger.info("Verified App Store lifecycle aggregate processed.", {
      source: projection.source,
      environment: projection.environment,
      duplicate,
      lifecycleEventCount: Object.keys(projection.eventCounts).length,
    });
    response.status(200).end();
  } catch (error) {
    if (error instanceof AppStoreNotificationProcessingError) {
      logger.warn("App Store lifecycle notification rejected.", {
        source: "appStoreServerNotificationsV2",
        environment: environmentLabel,
        reason: error.code,
        retryable: error.retryable,
      });
      response.status(appStoreNotificationHTTPStatus(error)).end();
      return;
    }
    logger.error("App Store lifecycle aggregate write unavailable.", {
      source: "appStoreServerNotificationsV2",
      environment: environmentLabel,
      reason: "storage-unavailable",
    });
    response.status(503).end();
  }
}

/** Production App Store Server Notifications V2 receiver. */
export const appStoreServerNotificationsV2 = onRequest(
  {
    invoker: "public",
    cors: false,
    serviceAccount: APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT,
    secrets: [appStoreRootCertificates],
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request, response) => handleAppStoreServerNotification(
    request,
    response,
    Environment.PRODUCTION,
    appStoreProductionNotificationsEnabled.value()
  )
);

/** Sandbox App Store Server Notifications V2 receiver. */
export const appStoreServerNotificationsV2Sandbox = onRequest(
  {
    invoker: "public",
    cors: false,
    serviceAccount: APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT,
    secrets: [appStoreRootCertificates],
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request, response) => handleAppStoreServerNotification(
    request,
    response,
    Environment.SANDBOX,
    appStoreSandboxNotificationsEnabled.value()
  )
);

/**
 * True only when an Admin Auth error reports a missing user.
 * @param {unknown} error Candidate Admin SDK error.
 * @return {boolean} Whether the code is auth/user-not-found.
 */
function isAuthUserNotFound(error: unknown): boolean {
  return isRecord(error) && error.code === "auth/user-not-found";
}

type VerifiedAccountDeletionStateAdmission =
  | "createPending"
  | "resumePending"
  | "alreadyCompleted";

/**
 * Converts exact stored deletion state into a safe request disposition.
 * @param {unknown} data Stored server-owned marker, or undefined when absent.
 * @param {string} accountID Verified Firebase UID and document ID.
 * @param {string} requestID Validated durable deletion request UUID.
 * @return {VerifiedAccountDeletionStateAdmission} Safe admission decision.
 */
function verifiedAccountDeletionStateAdmission(
  data: unknown,
  accountID: string,
  requestID: string
): VerifiedAccountDeletionStateAdmission {
  const admission = accountDeletionStateAdmission(
    data,
    accountID,
    requestID,
    socialDateMilliseconds
  );
  if (admission === "invalid") {
    throw new HttpsError(
      "failed-precondition",
      "Account deletion state could not be verified.",
      {reason: "account-deletion-state-mismatch"}
    );
  }
  return admission;
}

type AccountDeletionExecutionResult =
  | "deleted"
  | "alreadyCompleted"
  | "stateChanged";

/**
 * Executes the one shared deletion worklist for a callable or reconciliation.
 * @param {CallableRequest<unknown>|null} request Verified callable request.
 * @param {PendingAccountDeletionReconciliationCandidate|null} reconciliation
 * Exact stale pending row selected by the server-only scheduled path.
 * @return {Promise<AccountDeletionExecutionResult>} Safe terminal disposition.
 */
async function executeAccountDeletion(
  request: CallableRequest<unknown> | null,
  reconciliation: {
    accountID: string;
    requestID: string;
  } | null = null
): Promise<AccountDeletionExecutionResult> {
  const startedAt = Date.now();
  const firestore = getFirestore();
  const auth = getAuth();
  let uid: string;
  let requestID: string;
  let authUserExists: boolean;

  if (request) {
    assertTrustedCaller(request.auth, request.app);
    const authenticatedUID = request.auth?.uid;
    if (!authenticatedUID) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    const deletionRequest = validateDeleteAccountRequest(request.data);
    assertDeleteAccountRequestIdentity(
      deletionRequest.expectedAccountID,
      authenticatedUID
    );
    uid = authenticatedUID;
    requestID = deletionRequest.requestID;
    assertRecentAuthentication(
      deletionAuthenticationTime(request.auth?.token),
      startedAt
    );

    const deletionStateRef = firestore.collection("_accountDeletionState")
      .doc(uid);
    const initialDeletionState = await deletionStateRef.get();
    const initialAdmission = verifiedAccountDeletionStateAdmission(
      initialDeletionState.exists ? initialDeletionState.data() : undefined,
      uid,
      requestID
    );
    if (initialAdmission === "alreadyCompleted") {
      logger.info(
        "deleteAccount already completed",
        accountDeletionLogMetadata(
          requestID,
          "already-completed",
          Date.now() - startedAt
        )
      );
      return "alreadyCompleted";
    }

    authUserExists = true;
    let providerIDs: string[] = [];
    try {
      const user = await auth.getUser(uid);
      providerIDs = user.providerData.map((provider) => provider.providerId);
    } catch (error) {
      if (isAuthUserNotFound(error)) {
        authUserExists = false;
      } else {
        logger.error(
          "deleteAccount auth lookup failed",
          accountDeletionLogMetadata(
            requestID,
            "auth-lookup-failed",
            Date.now() - startedAt
          )
        );
        throw new HttpsError(
          "unavailable",
          "Account deletion could not start. Try again."
        );
      }
    }

    assertAppleRevocationSupported(providerIDs);
  } else {
    if (!reconciliation) {
      throw new Error("Missing account deletion reconciliation candidate.");
    }
    uid = reconciliation.accountID;
    requestID = reconciliation.requestID;
    const deletionStateRef = firestore.collection("_accountDeletionState")
      .doc(uid);
    const pendingState = await deletionStateRef.get();
    const currentCandidate = pendingState.exists ?
      pendingAccountDeletionReconciliationCandidate(
        pendingState.data(),
        pendingState.id,
        startedAt,
        socialDateMilliseconds
      ) : null;
    if (!currentCandidate ||
          currentCandidate.accountID !== reconciliation.accountID ||
          currentCandidate.requestID !== reconciliation.requestID) {
      return "stateChanged";
    }
    let providerIDs: string[] = [];
    try {
      const user = await auth.getUser(uid);
      providerIDs = user.providerData.map((provider) => provider.providerId);
      authUserExists = true;
    } catch (error) {
      if (!isAuthUserNotFound(error)) throw error;
      authUserExists = false;
    }
    assertAppleRevocationSupported(providerIDs);
  }

  const cutoverSnapshot = await firestore
    .collection("_socialReferenceCutover").doc("current").get();
  assertSocialReferenceCutoverComplete(cutoverSnapshot.data());

  const deletionStateRef = firestore.collection("_accountDeletionState")
    .doc(uid);
  if (request) {
    const pendingAdmission = await firestore.runTransaction(
      async (transaction) => {
        const snapshot = await transaction.get(deletionStateRef);
        const admission = verifiedAccountDeletionStateAdmission(
          snapshot.exists ? snapshot.data() : undefined,
          uid,
          requestID
        );
        if (admission === "createPending") {
          transaction.set(deletionStateRef, {
            schemaVersion: 2,
            status: "pending",
            accountID: uid,
            requestID,
            startedAt: Timestamp.fromMillis(startedAt),
            updatedAt: Timestamp.now(),
          });
        } else if (admission === "resumePending") {
          transaction.update(deletionStateRef, {updatedAt: Timestamp.now()});
        }
        return admission;
      }
    );
    if (pendingAdmission === "alreadyCompleted") {
      logger.info(
        "deleteAccount concurrently completed",
        accountDeletionLogMetadata(
          requestID,
          "already-completed",
          Date.now() - startedAt
        )
      );
      return "alreadyCompleted";
    }
  } else {
    const stillPending = await firestore.runTransaction(
      async (transaction) => {
        const current = await transaction.get(deletionStateRef);
        const candidate = current.exists ?
          pendingAccountDeletionReconciliationCandidate(
            current.data(),
            current.id,
            Date.now(),
            socialDateMilliseconds
          ) : null;
        return candidate?.accountID === uid &&
            candidate.requestID === requestID;
      }
    );
    if (!stillPending) return "stateChanged";
  }

  const work: AccountDeletionWork = {
    userTree: async () => {
      await firestore.recursiveDelete(
        firestore.collection("users").doc(uid)
      );
    },
    publicProfile: async () => {
      await firestore.collection("profiles_public").doc(uid).delete();
    },
    leagueMemberships: async () => {
      const snapshot = await firestore.collection("_socialReferences")
        .doc(uid).get();
      const references = validateSocialReferenceManifest(
        snapshot.data(),
        uid
      );
      const batch = firestore.batch();
      for (const path of references.leagueMembershipPaths) {
        batch.delete(firestore.doc(path));
      }
      await batch.commit();
    },
    challenges: async () => {
      const snapshot = await firestore.collection("_socialReferences")
        .doc(uid).get();
      const references = validateSocialReferenceManifest(
        snapshot.data(),
        uid
      );
      for (const challengeID of references.challengeIDs) {
        const challengeRef = firestore.collection("challenges")
          .doc(challengeID);
        const challengeSnapshot = await challengeRef.get();
        let otherAccountID: string | null = null;
        if (challengeSnapshot.exists) {
          const challenge = validateStoredChallenge(
            challengeSnapshot.data(),
            challengeID
          );
          const side = challengeSide(challenge, uid);
          const otherSide = side === "creator" ? "opponent" : "creator";
          const candidate = challenge[`${otherSide}AccountID`];
          otherAccountID = typeof candidate === "string" ? candidate : null;
        }
        if (otherAccountID) {
          const otherReferencesRef = firestore
            .collection("_socialReferences").doc(otherAccountID);
          await firestore.runTransaction(async (transaction) => {
            const otherReferencesSnapshot = await transaction.get(
              otherReferencesRef
            );
            if (!otherReferencesSnapshot.exists) return;
            const otherReferences = validateSocialReferenceManifest(
              otherReferencesSnapshot.data(),
              otherAccountID
            );
            transaction.set(otherReferencesRef, {
              ...otherReferences,
              challengeIDs: otherReferences.challengeIDs.filter(
                (candidate) => candidate !== challengeID
              ),
            });
          });
        }
        await firestore.recursiveDelete(challengeRef);
      }
    },
    friendInvites: async () => {
      const inviteCollection = firestore.collection("_socialFriendInvites");
      const [inviteReferences, invited, accepted] = await Promise.all([
        firestore.collection("_socialReferences").doc(uid)
          .collection("friendInvites").get(),
        inviteCollection.where("inviterAccountID", "==", uid).get(),
        inviteCollection.where("acceptedAccountID", "==", uid).get(),
      ]);
      const inviteDigests = new Set<string>();
      const participantIDs = new Map<string, Set<string>>();
      const addParticipant = (digest: string, candidate: unknown) => {
        if (typeof candidate !== "string" || candidate === uid ||
              candidate.length < 1 || candidate.length > 128 ||
              candidate.includes("/")) return;
        const participants = participantIDs.get(digest) ?? new Set<string>();
        participants.add(candidate);
        participantIDs.set(digest, participants);
      };
      for (const document of inviteReferences.docs) {
        inviteDigests.add(document.id);
        try {
          const reference = validateStoredFriendInviteReference(
            document.data(),
            uid,
            document.id,
            socialDateMilliseconds
          );
          addParticipant(document.id, reference.counterpartAccountID);
        } catch {
          addParticipant(
            document.id,
            document.data().counterpartAccountID
          );
        }
      }
      for (const document of [...invited.docs, ...accepted.docs]) {
        inviteDigests.add(document.id);
        addParticipant(document.id, document.data().inviterAccountID);
        addParticipant(document.id, document.data().acceptedAccountID);
      }
      for (const digest of inviteDigests) {
        await firestore.runTransaction(async (transaction) => {
          transaction.delete(inviteCollection.doc(digest));
          transaction.delete(
            firestore.collection("_socialReferences").doc(uid)
              .collection("friendInvites").doc(digest)
          );
          for (const participantID of participantIDs.get(digest) ?? []) {
            transaction.delete(
              firestore.collection("_socialReferences")
                .doc(participantID)
                .collection("friendInvites").doc(digest)
            );
          }
        });
      }
    },
    friendLinks: async () => {
      const snapshot = await firestore.collection("_socialReferences")
        .doc(uid).get();
      const safeAccountID = (candidate: unknown): candidate is string =>
        typeof candidate === "string" && candidate !== uid &&
          candidate.length >= 1 && candidate.length <= 128 &&
          !candidate.includes("/");
      const manifestFriendIDs = new Set<string>();
      const rawFriendIDs = snapshot.data()?.friendAccountIDs;
      if (Array.isArray(rawFriendIDs)) {
        for (const candidate of rawFriendIDs.slice(
          0, MAX_ACTIVE_FRIENDS + 1
        )) {
          if (safeAccountID(candidate)) manifestFriendIDs.add(candidate);
        }
      }
      let includeManifest = true;
      let discoveringLinks = true;
      while (discoveringLinks) {
        const discoveryResults: [QuerySnapshot, QuerySnapshot] =
            await Promise.all([
              firestore.collectionGroup("friends")
                .where("accountID", "==", uid)
                .limit(MAX_ACTIVE_FRIENDS + 1).get(),
              firestore.collectionGroup("friends")
                .where("friendAccountID", "==", uid)
                .limit(MAX_ACTIVE_FRIENDS + 1).get(),
            ]);
        const [ownedLinks, incomingLinks] = discoveryResults;
        const linkDocuments = new Map<string, QueryDocumentSnapshot>(
          [...ownedLinks.docs, ...incomingLinks.docs]
            .map((document) => [document.ref.path, document] as const)
        );
        const friendAccountIDs = new Set<string>(
          includeManifest ? manifestFriendIDs : []
        );
        includeManifest = false;
        for (const document of linkDocuments.values()) {
          const data = document.data();
          if (data.accountID === uid && safeAccountID(data.friendAccountID)) {
            friendAccountIDs.add(data.friendAccountID);
          }
          if (data.friendAccountID === uid && safeAccountID(data.accountID)) {
            friendAccountIDs.add(data.accountID);
          }
          const ownerID = document.ref.parent.parent?.id;
          if (ownerID === uid && safeAccountID(document.id)) {
            friendAccountIDs.add(document.id);
          } else if (document.id === uid && safeAccountID(ownerID)) {
            friendAccountIDs.add(ownerID);
          }
        }
        if (linkDocuments.size === 0 && friendAccountIDs.size === 0) {
          discoveringLinks = false;
          continue;
        }
        const friendReferences = [...friendAccountIDs].map(
          (friendAccountID) => firestore.collection("_socialReferences")
            .doc(friendAccountID)
        );
        const referenceSnapshots = await Promise.all(
          friendReferences.map((reference) => reference.get())
        );
        const deleteReferences = new Map<string, DocumentReference>();
        for (const document of linkDocuments.values()) {
          deleteReferences.set(document.ref.path, document.ref);
        }
        for (const friendAccountID of friendAccountIDs) {
          const ownLinkRef = firestore.collection("_socialFriendLinks")
            .doc(uid).collection("friends").doc(friendAccountID);
          const reciprocalLinkRef = firestore.collection("_socialFriendLinks")
            .doc(friendAccountID).collection("friends").doc(uid);
          deleteReferences.set(ownLinkRef.path, ownLinkRef);
          deleteReferences.set(reciprocalLinkRef.path, reciprocalLinkRef);
        }
        const batch = firestore.batch();
        for (const reference of deleteReferences.values()) {
          batch.delete(reference);
        }
        for (const referenceSnapshot of referenceSnapshots) {
          if (referenceSnapshot.exists) {
            batch.update(referenceSnapshot.ref, {
              friendAccountIDs: FieldValue.arrayRemove(uid),
            });
          }
        }
        await batch.commit();
      }
    },
    competitiveObservations: async () => {
      await Promise.all([
        firestore.recursiveDelete(
          firestore.collection("_competitiveCaptureIntents").doc(uid)
        ),
        firestore.recursiveDelete(
          firestore.collection("_competitiveObservations").doc(uid)
        ),
      ]);
    },
    rateLimits: async () => {
      await Promise.all([
        firestore.collection("_serverRateLimits").doc(uid).delete(),
        firestore.recursiveDelete(
          firestore.collection("_socialState").doc(uid)
        ),
        firestore.recursiveDelete(
          firestore.collection("_verifiedSessionEvidence").doc(uid)
        ),
        firestore.recursiveDelete(
          firestore.collection("_socialFriendLinks").doc(uid)
        ),
      ]);
    },
    socialReferenceManifest: async () => {
      await firestore.recursiveDelete(
        firestore.collection("_socialReferences").doc(uid)
      );
    },
    authUser: async () => {
      if (!authUserExists) return;
      try {
        await auth.deleteUser(uid);
      } catch (error) {
        if (!isAuthUserNotFound(error)) throw error;
      }
    },
    completedTombstone: async () => {
      try {
        await firestore.runTransaction(async (transaction) => {
          const current = await transaction.get(deletionStateRef);
          const admission = verifiedAccountDeletionStateAdmission(
            current.exists ? current.data() : undefined,
            uid,
            requestID
          );
          if (admission === "alreadyCompleted") return;
          if (admission !== "resumePending") {
            throw new Error("Deletion fence was not pending at completion.");
          }
          transaction.set(deletionStateRef, completedAccountDeletionTombstone(
            uid,
            requestID,
            Date.now()
          ));
        });
      } catch (error) {
        logger.warn(
          "deleteAccount tombstone finalization deferred",
          accountDeletionLogMetadata(
            requestID,
            "tombstone-finalization-deferred",
            Date.now() - startedAt,
            ["completedTombstone"]
          )
        );
        throw error;
      }
    },
  };

  try {
    await executeAccountDeletionPlan(work);
    logger.info(
      "deleteAccount completed",
      accountDeletionLogMetadata(
        requestID,
        "ok",
        Date.now() - startedAt
      )
    );
    return "deleted";
  } catch (error) {
    const failedSteps = error instanceof AccountDeletionPartialError ?
      error.failedSteps : [];
    logger.error(
      "deleteAccount failed",
      accountDeletionLogMetadata(
        requestID,
        "partial-failure",
        Date.now() - startedAt,
        failedSteps
      )
    );
    throw new HttpsError(
      "internal",
      "Account deletion did not complete. Try again."
    );
  }
}

export const deleteAccount = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 540,
    memory: "512MiB",
    serviceAccount: ACCOUNT_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "A secure session is required.");
    }
    const input = validateDeleteAccountRequest(request.data);
    assertDeleteAccountRequestIdentity(input.expectedAccountID, uid);
    const result = await executeAccountDeletion(request);
    if (result !== "deleted" && result !== "alreadyCompleted") {
      throw new HttpsError(
        "internal",
        "Account deletion did not complete. Try again."
      );
    }
    return {deleted: true, requestID: input.requestID};
  }
);

export const reconcileAccountDeletionTombstones = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "Etc/UTC",
    timeoutSeconds: 300,
    memory: "256MiB",
    serviceAccount: ACCOUNT_RUNTIME_SERVICE_ACCOUNT,
    retryCount: 3,
    minBackoffSeconds: 60,
    maxBackoffSeconds: 600,
  },
  async () => {
    const startedAt = Date.now();
    const firestore = getFirestore();
    const cutoff = Timestamp.fromMillis(
      startedAt - ACCOUNT_DELETION_RECONCILIATION_MIN_AGE_MS
    );
    const pendingQuery = firestore.collection("_accountDeletionState")
      .where("status", "==", "pending")
      .where("updatedAt", "<=", cutoff)
      .orderBy("updatedAt", "asc");
    const candidates: Array<{accountID: string; requestID: string}> = [];
    let cursor: QueryDocumentSnapshot | null = null;
    let scanned = 0;
    let reconciled = 0;
    let retained = 0;
    let superseded = 0;
    let failures = 0;

    while (candidates.length <
        ACCOUNT_DELETION_RECONCILIATION_BATCH_SIZE) {
      let pageQuery = pendingQuery.limit(
        ACCOUNT_DELETION_RECONCILIATION_BATCH_SIZE
      );
      if (cursor) pageQuery = pageQuery.startAfter(cursor);
      const page = await pageQuery.get();
      scanned += page.size;
      for (const document of page.docs) {
        const candidate = pendingAccountDeletionReconciliationCandidate(
          document.data(),
          document.id,
          startedAt,
          socialDateMilliseconds
        );
        if (candidate) {
          candidates.push(candidate);
          if (candidates.length ===
              ACCOUNT_DELETION_RECONCILIATION_BATCH_SIZE) break;
        } else {
          retained += 1;
        }
      }
      cursor = page.docs.at(-1) ?? null;
      if (page.empty || page.size <
          ACCOUNT_DELETION_RECONCILIATION_BATCH_SIZE) break;
    }

    for (const candidate of candidates) {
      try {
        const result = await executeAccountDeletion(null, candidate);
        switch (result) {
        case "deleted":
        case "alreadyCompleted":
          reconciled += 1;
          break;
        case "stateChanged":
          superseded += 1;
          break;
        }
      } catch {
        failures += 1;
        try {
          await firestore.runTransaction(async (transaction) => {
            const reference = firestore.collection("_accountDeletionState")
              .doc(candidate.accountID);
            const current = await transaction.get(reference);
            const admission = verifiedAccountDeletionStateAdmission(
              current.exists ? current.data() : undefined,
              candidate.accountID,
              candidate.requestID
            );
            if (admission === "resumePending") {
              transaction.update(reference, {updatedAt: Timestamp.now()});
            }
          });
        } catch {
          // The original failed attempt is already counted and retried.
        }
      }
    }

    const metadata = {
      operation: "reconcileAccountDeletionTombstones",
      status: failures === 0 ? "ok" : "partial-failure",
      scanned,
      reconciled,
      retained,
      superseded,
      failures,
      latencyMs: Date.now() - startedAt,
    };
    if (failures > 0) {
      logger.error("Account deletion reconciliation incomplete", metadata);
      throw new Error("Account deletion reconciliation incomplete.");
    }
    logger.info("Account deletion reconciliation completed", metadata);
  }
);
