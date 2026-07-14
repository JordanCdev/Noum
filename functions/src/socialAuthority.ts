/* eslint-disable valid-jsdoc, require-jsdoc, max-len */

import {createHash} from "node:crypto";
import {HttpsError} from "firebase-functions/v2/https";

export const SOCIAL_SCHEMA_VERSION = 1;
export const CHALLENGE_DOCUMENT_SCHEMA_VERSION = 2;
export const INITIAL_RATING = 400;
export const MAX_DISPLAY_NAME_CHARS = 60;
export const MAX_PROMPT_CHARS = 500;
export const MAX_RESULT_SUMMARY_CHARS = 240;
export const CHALLENGE_LIFETIME_MS = 3 * 24 * 60 * 60 * 1_000;
export const SOCIAL_PRACTICE_DAY_LIMIT = 400;
export const SOCIAL_RATING_EVENT_LIMIT = 100;
export const CHALLENGE_CREATE_MINUTE_LIMIT = 3;
export const CHALLENGE_CREATE_HOUR_LIMIT = 20;
export const CHALLENGE_REACTION_MINUTE_LIMIT = 10;
export const CHALLENGE_REACTION_HOUR_LIMIT = 100;
export const PEER_PROFILE_READ_MINUTE_LIMIT = 30;
export const PEER_PROFILE_READ_HOUR_LIMIT = 300;
export const LEAGUE_LIST_READ_MINUTE_LIMIT = 10;
export const LEAGUE_LIST_READ_HOUR_LIMIT = 100;
export const MAX_LEAGUE_MEMBER_RESULTS = 50;
export const VERIFIED_EVIDENCE_SOURCE = "noum-server-evaluator";
export const CHALLENGE_REACTIONS = [
  "🔥", "👏", "💪", "🤯", "🏆", "❤️",
] as const;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA256_PATTERN = /^[0-9a-f]{64}$/;
const GIT_COMMIT_PATTERN = /^[0-9a-f]{40}$/;
const SOCIAL_CUTOVER_RUN_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;
const PRODUCTION_PROJECT_ID = "noum-d0b6f";
const LEAGUE_BUCKET_PATTERN =
  /^(bronze|silver|gold|platinum|diamond)_\d{4}-W\d{2}$/;
const MAX_CLOCK_SKEW_MS = 5 * 60 * 1_000;
const MIN_SESSION_DATE_MS = Date.UTC(2020, 0, 1);
const MAX_SESSION_DURATION_SECONDS = 4 * 60 * 60;
const ROLLING_WEEK_MS = 7 * 24 * 60 * 60 * 1_000;
const MAX_REFERENCE_CHALLENGES = 100;
const MAX_REFERENCE_LEAGUES = 16;
const MAX_REFERENCE_FRIENDS = 200;

export type LeagueTier =
  "bronze" | "silver" | "gold" | "platinum" | "diamond";
export type ChallengeReaction = typeof CHALLENGE_REACTIONS[number];
export type ChallengeSide = "creator" | "opponent";

export interface RecordPeerSessionInput {
  schemaVersion: 1;
  sessionID: string;
  displayName: string;
}

export interface CreateChallengeInput {
  schemaVersion: 1;
  challengeID: string;
  opponentAccountID: string;
  prompt: string;
}

export interface SubmitChallengeResultInput {
  schemaVersion: 1;
  challengeID: string;
  sessionID: string;
}

export interface SetChallengeReactionInput {
  schemaVersion: 1;
  challengeID: string;
  reaction: ChallengeReaction;
}

export interface GetPeerProfileInput {
  schemaVersion: 1;
  accountID: string;
}

export interface ListLeagueMembersInput {
  schemaVersion: 1;
  limit: number;
}

export interface VerifiedSessionEvidence {
  sessionID: string;
  score: number;
  dateMs: number;
  duration: number;
  isRated: boolean;
  summary: string | null;
  challengeID: string | null;
  promptDigest: string | null;
}

export interface RatingEvent {
  sessionID: string;
  dateMs: number;
  delta: number;
}

export interface StoredSocialState {
  schemaVersion: 2;
  rating: number;
  peakRating: number;
  totalRatedSessions: number;
  weekKey: string;
  weeklyReps: number;
  practiceDays: string[];
  ratingEvents: RatingEvent[];
  currentBucket: string | null;
  latestEvidenceDateMs: number | null;
  latestEvidenceSessionID: string | null;
  displayName: string;
  updatedAtMs: number;
}

export interface PublicProfileEnvelope {
  accountID: string;
  displayName: string;
  rating: number;
  peakRating: number;
  currentStreak: number;
  weeklyReps: number;
  weeklyDelta: number;
  leagueTier: LeagueTier | null;
  updatedAt: number;
}

export interface AdvancedSocialState {
  state: StoredSocialState;
  profile: PublicProfileEnvelope;
  ratingDelta: number;
}

export interface ChallengeSubmission {
  schemaVersion: 1;
  challengeID: string;
  accountID: string;
  side: ChallengeSide;
  sessionID: string;
  score: number;
  duration: number;
  summary: string | null;
  submittedAt: unknown;
  reaction: ChallengeReaction | null;
  reactedAt: unknown | null;
}

export interface CombinedChallengeResult {
  schemaVersion: 1;
  challengeID: string;
  creatorSessionID: string;
  creatorScore: number;
  creatorDuration: number;
  creatorSummary: string | null;
  creatorSubmittedAt: unknown;
  creatorReaction: ChallengeReaction | null;
  creatorReactedAt: unknown | null;
  opponentSessionID: string;
  opponentScore: number;
  opponentDuration: number;
  opponentSummary: string | null;
  opponentSubmittedAt: unknown;
  opponentReaction: ChallengeReaction | null;
  opponentReactedAt: unknown | null;
  completedAt: unknown;
}

export interface ChallengeEnvelope {
  id: string;
  prompt: string;
  createdAt: number;
  expiresAt: number;
  creatorID: string;
  creatorName: string;
  creatorAccountID: string;
  opponentID: string;
  opponentName: string;
  opponentAccountID: string;
  creatorScore: number | null;
  creatorDuration: number | null;
  creatorSummary: string | null;
  opponentScore: number | null;
  opponentDuration: number | null;
  opponentSummary: string | null;
  creatorReaction: ChallengeReaction | null;
  opponentReaction: ChallengeReaction | null;
}

export interface SocialReferenceManifest {
  leagueMembershipPaths: string[];
  challengeIDs: string[];
  friendAccountIDs: string[];
}

export function isSocialRecord(
  value: unknown
): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasExactKeys(
  value: Record<string, unknown>,
  expected: string[]
): boolean {
  const actual = Object.keys(value).sort();
  const sortedExpected = [...expected].sort();
  return actual.length === sortedExpected.length &&
    actual.every((key, index) => key === sortedExpected[index]);
}

function validatedUUID(value: unknown, label: string): string {
  if (typeof value !== "string" || !UUID_PATTERN.test(value)) {
    throw new HttpsError("invalid-argument", `Invalid ${label}.`);
  }
  return value.toUpperCase();
}

function validatedBoundedString(
  value: unknown,
  label: string,
  maxCharacters: number
): string {
  if (typeof value !== "string" || value !== value.trim() ||
      value.length < 1 || value.length > maxCharacters) {
    throw new HttpsError("invalid-argument", `Invalid ${label}.`);
  }
  return value;
}

function isValidFirebaseUID(value: unknown): value is string {
  const hasControlCharacter = typeof value === "string" &&
    Array.from(value).some((character) => {
      const code = character.charCodeAt(0);
      return code < 32 || code === 127;
    });
  return typeof value === "string" && value === value.trim() &&
    value.length >= 1 && value.length <= 128 && !value.includes("/") &&
    !hasControlCharacter;
}

export function validateFirebaseUID(value: unknown): string {
  if (!isValidFirebaseUID(value)) {
    throw new HttpsError("invalid-argument", "Invalid participant account.");
  }
  return value;
}

export function validateRecordPeerSessionRequest(
  data: unknown
): RecordPeerSessionInput {
  if (!isSocialRecord(data) || data.schemaVersion !== SOCIAL_SCHEMA_VERSION ||
      !hasExactKeys(data, ["schemaVersion", "sessionID", "displayName"])) {
    throw new HttpsError("invalid-argument", "Invalid peer-session request.");
  }
  return {
    schemaVersion: 1,
    sessionID: validatedUUID(data.sessionID, "session ID"),
    displayName: validatedBoundedString(
      data.displayName,
      "display name",
      MAX_DISPLAY_NAME_CHARS
    ),
  };
}

export function validateCreateChallengeRequest(
  data: unknown
): CreateChallengeInput {
  if (!isSocialRecord(data) || data.schemaVersion !== SOCIAL_SCHEMA_VERSION ||
      !hasExactKeys(data, [
        "schemaVersion", "challengeID", "opponentAccountID", "prompt",
      ])) {
    throw new HttpsError("invalid-argument", "Invalid challenge request.");
  }
  return {
    schemaVersion: 1,
    challengeID: validatedUUID(data.challengeID, "challenge ID"),
    opponentAccountID: validateFirebaseUID(data.opponentAccountID),
    prompt: validatedBoundedString(data.prompt, "challenge prompt", MAX_PROMPT_CHARS),
  };
}

export function validateSubmitChallengeResultRequest(
  data: unknown
): SubmitChallengeResultInput {
  if (!isSocialRecord(data) || data.schemaVersion !== SOCIAL_SCHEMA_VERSION ||
      !hasExactKeys(data, ["schemaVersion", "challengeID", "sessionID"])) {
    throw new HttpsError("invalid-argument", "Invalid challenge result.");
  }
  return {
    schemaVersion: 1,
    challengeID: validatedUUID(data.challengeID, "challenge ID"),
    sessionID: validatedUUID(data.sessionID, "session ID"),
  };
}

export function validateSetChallengeReactionRequest(
  data: unknown
): SetChallengeReactionInput {
  if (!isSocialRecord(data) || data.schemaVersion !== SOCIAL_SCHEMA_VERSION ||
      !hasExactKeys(data, ["schemaVersion", "challengeID", "reaction"]) ||
      typeof data.reaction !== "string" ||
      !CHALLENGE_REACTIONS.includes(data.reaction as ChallengeReaction)) {
    throw new HttpsError("invalid-argument", "Invalid challenge reaction.");
  }
  return {
    schemaVersion: 1,
    challengeID: validatedUUID(data.challengeID, "challenge ID"),
    reaction: data.reaction as ChallengeReaction,
  };
}

export function validateGetPeerProfileRequest(
  data: unknown
): GetPeerProfileInput {
  if (!isSocialRecord(data) || data.schemaVersion !== SOCIAL_SCHEMA_VERSION ||
      !hasExactKeys(data, ["schemaVersion", "accountID"])) {
    throw new HttpsError("invalid-argument", "Invalid peer-profile request.");
  }
  return {
    schemaVersion: 1,
    accountID: validateFirebaseUID(data.accountID),
  };
}

export function validateListLeagueMembersRequest(
  data: unknown
): ListLeagueMembersInput {
  if (!isSocialRecord(data) || data.schemaVersion !== SOCIAL_SCHEMA_VERSION ||
      !hasExactKeys(data, ["schemaVersion", "limit"]) ||
      typeof data.limit !== "number" || !Number.isInteger(data.limit) ||
      data.limit < 1 || data.limit > MAX_LEAGUE_MEMBER_RESULTS) {
    throw new HttpsError("invalid-argument", "Invalid league-list request.");
  }
  return {schemaVersion: 1, limit: data.limit};
}

export function socialDateMilliseconds(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value > 10_000_000_000 ? value : value * 1_000;
  }
  if (value instanceof Date) return value.getTime();
  if (isSocialRecord(value) && typeof value.toMillis === "function") {
    const milliseconds = (value.toMillis as () => unknown)();
    return typeof milliseconds === "number" && Number.isFinite(milliseconds) ?
      milliseconds : null;
  }
  if (isSocialRecord(value) && typeof value._seconds === "number") {
    return value._seconds * 1_000;
  }
  return null;
}

function isServerTimestamp(value: unknown): boolean {
  return isSocialRecord(value) && typeof value.toMillis === "function" &&
    socialDateMilliseconds(value) !== null;
}

export function verifiedEvidenceUnavailable(): never {
  throw new HttpsError(
    "failed-precondition",
    "Verified competitive evidence is not available for this rep.",
    {reason: "verified-evidence-unavailable"}
  );
}

export function validateVerifiedSessionEvidence(
  value: unknown,
  sessionID: string,
  nowMs: number
): VerifiedSessionEvidence {
  if (!isSocialRecord(value) || value.schemaVersion !== 1 ||
      value.evidenceSource !== VERIFIED_EVIDENCE_SOURCE ||
      typeof value.evaluatorVersion !== "number" ||
      !Number.isInteger(value.evaluatorVersion) || value.evaluatorVersion < 1 ||
      value.competitiveEligible !== true ||
      typeof value.sessionID !== "string" ||
      value.sessionID.toUpperCase() !== sessionID ||
      typeof value.duration !== "number" || !Number.isFinite(value.duration) ||
      value.duration < 1 || value.duration > MAX_SESSION_DURATION_SECONDS ||
      typeof value.score !== "number" || !Number.isInteger(value.score) ||
      value.score < 0 || value.score > 10 ||
      typeof value.isRated !== "boolean" ||
      !(value.summary === null ||
        (typeof value.summary === "string" &&
         value.summary.length <= MAX_RESULT_SUMMARY_CHARS)) ||
      !(value.challengeID === null ||
        (typeof value.challengeID === "string" &&
         UUID_PATTERN.test(value.challengeID))) ||
      !(value.promptDigest === null ||
        (typeof value.promptDigest === "string" &&
         SHA256_PATTERN.test(value.promptDigest))) ||
      !isServerTimestamp(value.completedAt) ||
      !isServerTimestamp(value.attestedAt)) {
    return verifiedEvidenceUnavailable();
  }
  const completedAt = socialDateMilliseconds(value.completedAt);
  const attestedAt = socialDateMilliseconds(value.attestedAt);
  if (completedAt === null || attestedAt === null ||
      completedAt < MIN_SESSION_DATE_MS ||
      completedAt > nowMs + MAX_CLOCK_SKEW_MS ||
      attestedAt < completedAt || attestedAt > nowMs + MAX_CLOCK_SKEW_MS) {
    return verifiedEvidenceUnavailable();
  }
  return {
    sessionID,
    score: value.score as number,
    dateMs: completedAt,
    duration: value.duration as number,
    isRated: value.isRated as boolean,
    summary: value.summary as string | null,
    challengeID: typeof value.challengeID === "string" ?
      value.challengeID.toUpperCase() : null,
    promptDigest: value.promptDigest as string | null,
  };
}

export function promptDigest(prompt: string): string {
  return createHash("sha256").update(prompt, "utf8").digest("hex");
}

export function assertEvidenceBoundToChallenge(
  evidence: VerifiedSessionEvidence,
  challenge: Record<string, unknown>,
  nowMs: number
): void {
  const createdAt = socialDateMilliseconds(challenge.createdAt);
  const expiresAt = socialDateMilliseconds(challenge.expiresAt);
  if (createdAt === null || expiresAt === null || nowMs > expiresAt) {
    throw new HttpsError(
      "failed-precondition",
      "This challenge has expired.",
      {reason: "challenge-expired"}
    );
  }
  if (evidence.dateMs < createdAt || evidence.dateMs > expiresAt ||
      evidence.challengeID !== challenge.id ||
      typeof challenge.prompt !== "string" ||
      typeof challenge.promptDigest !== "string" ||
      promptDigest(challenge.prompt) !== challenge.promptDigest ||
      evidence.promptDigest !== challenge.promptDigest) {
    throw new HttpsError(
      "failed-precondition",
      "Use verified evidence recorded for this exact prompt.",
      {reason: "prompt-unbound-evidence"}
    );
  }
}

export function calculateRatingDelta(
  currentRating: number,
  sessionScore: number
): number {
  const k = currentRating < 600 ? 32 : currentRating < 800 ? 24 : 16;
  const expected = currentRating / 1_000;
  const actual = sessionScore / 10;
  const raw = k * (actual - expected);
  return raw >= 0 ? Math.floor(raw + 0.5) : Math.ceil(raw - 0.5);
}

export function isoWeekKey(dateMs: number): string {
  const date = new Date(dateMs);
  const day = date.getUTCDay() || 7;
  const thursday = new Date(Date.UTC(
    date.getUTCFullYear(),
    date.getUTCMonth(),
    date.getUTCDate() + 4 - day
  ));
  const yearStart = new Date(Date.UTC(thursday.getUTCFullYear(), 0, 1));
  const week = Math.ceil(
    (((thursday.getTime() - yearStart.getTime()) / 86_400_000) + 1) / 7
  );
  return `${thursday.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

export function socialDayKey(dateMs: number): string {
  return new Date(dateMs).toISOString().slice(0, 10);
}

export function leagueTierForRating(rating: number): LeagueTier {
  if (rating < 300) return "bronze";
  if (rating < 500) return "silver";
  if (rating < 700) return "gold";
  if (rating < 850) return "platinum";
  return "diamond";
}

export function calculateCurrentStreak(
  dayKeys: string[],
  nowMs: number
): number {
  const days = new Set(dayKeys);
  const cursor = new Date(`${socialDayKey(nowMs)}T00:00:00.000Z`);
  const keyAt = (date: Date): string => date.toISOString().slice(0, 10);
  if (!days.has(keyAt(cursor))) {
    cursor.setUTCDate(cursor.getUTCDate() - 1);
    if (!days.has(keyAt(cursor))) return 0;
  }
  let streak = 0;
  for (let checked = 0; checked <= SOCIAL_PRACTICE_DAY_LIMIT; checked += 1) {
    if (!days.has(keyAt(cursor))) break;
    streak += 1;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  return streak;
}

export function storedSocialState(
  value: unknown,
  displayName: string,
  nowMs: number
): StoredSocialState {
  if (value === undefined || value === null) {
    return {
      schemaVersion: 2,
      rating: INITIAL_RATING,
      peakRating: INITIAL_RATING,
      totalRatedSessions: 0,
      weekKey: isoWeekKey(nowMs),
      weeklyReps: 0,
      practiceDays: [],
      ratingEvents: [],
      currentBucket: null,
      latestEvidenceDateMs: null,
      latestEvidenceSessionID: null,
      displayName,
      updatedAtMs: nowMs,
    };
  }
  if (!isSocialRecord(value) || value.schemaVersion !== 2 ||
      typeof value.rating !== "number" || !Number.isInteger(value.rating) ||
      value.rating < 100 || value.rating > 1_000 ||
      typeof value.peakRating !== "number" || !Number.isInteger(value.peakRating) ||
      value.peakRating < value.rating || value.peakRating > 1_000 ||
      typeof value.totalRatedSessions !== "number" ||
      !Number.isInteger(value.totalRatedSessions) || value.totalRatedSessions < 0 ||
      typeof value.weekKey !== "string" ||
      typeof value.weeklyReps !== "number" || !Number.isInteger(value.weeklyReps) ||
      value.weeklyReps < 0 || !Array.isArray(value.practiceDays) ||
      !value.practiceDays.every((day) => typeof day === "string") ||
      !Array.isArray(value.ratingEvents) ||
      !value.ratingEvents.every(validRatingEvent) ||
      !(value.currentBucket === null ||
        (typeof value.currentBucket === "string" &&
         LEAGUE_BUCKET_PATTERN.test(value.currentBucket))) ||
      !(value.latestEvidenceDateMs === null ||
        (typeof value.latestEvidenceDateMs === "number" &&
         Number.isFinite(value.latestEvidenceDateMs) &&
         value.latestEvidenceDateMs >= MIN_SESSION_DATE_MS)) ||
      !(value.latestEvidenceSessionID === null ||
        (typeof value.latestEvidenceSessionID === "string" &&
         UUID_PATTERN.test(value.latestEvidenceSessionID))) ||
      ((value.latestEvidenceDateMs === null) !==
       (value.latestEvidenceSessionID === null)) ||
      typeof value.displayName !== "string" || value.displayName.length < 1 ||
      value.displayName.length > MAX_DISPLAY_NAME_CHARS ||
      typeof value.updatedAtMs !== "number" || !Number.isFinite(value.updatedAtMs)) {
    throw new Error("Corrupt server social state.");
  }
  return value as unknown as StoredSocialState;
}

function validRatingEvent(value: unknown): value is RatingEvent {
  return isSocialRecord(value) && typeof value.sessionID === "string" &&
    UUID_PATTERN.test(value.sessionID) && typeof value.dateMs === "number" &&
    Number.isFinite(value.dateMs) && typeof value.delta === "number" &&
    Number.isInteger(value.delta) && Math.abs(value.delta) <= 32;
}

export function advanceSocialState(
  previous: StoredSocialState,
  evidence: VerifiedSessionEvidence,
  accountID: string,
  displayName: string,
  nowMs: number
): AdvancedSocialState {
  assertEvidenceFollowsState(previous, evidence);
  const currentWeekKey = isoWeekKey(nowMs);
  const sessionWeekKey = isoWeekKey(evidence.dateMs);
  const weeklyReps = (previous.weekKey === currentWeekKey ?
    previous.weeklyReps : 0) + (sessionWeekKey === currentWeekKey ? 1 : 0);
  const ratingDelta = evidence.isRated ?
    calculateRatingDelta(previous.rating, evidence.score) : 0;
  const rating = evidence.isRated ?
    Math.max(100, Math.min(1_000, previous.rating + ratingDelta)) :
    previous.rating;
  const peakRating = Math.max(previous.peakRating, rating);
  const totalRatedSessions = previous.totalRatedSessions +
    (evidence.isRated ? 1 : 0);
  const oldestDayMs = nowMs - SOCIAL_PRACTICE_DAY_LIMIT * 86_400_000;
  const newDay = evidence.dateMs >= oldestDayMs ?
    [socialDayKey(evidence.dateMs)] : [];
  const practiceDays = Array.from(new Set([
    ...previous.practiceDays.filter((day) => {
      const parsed = Date.parse(`${day}T00:00:00.000Z`);
      return Number.isFinite(parsed) && parsed >= oldestDayMs;
    }),
    ...newDay,
  ])).sort().slice(-SOCIAL_PRACTICE_DAY_LIMIT);
  const ratingEvents = [
    ...previous.ratingEvents,
    ...(evidence.isRated ? [{
      sessionID: evidence.sessionID,
      dateMs: evidence.dateMs,
      delta: ratingDelta,
    }] : []),
  ]
    .filter((event) => event.dateMs >= nowMs - ROLLING_WEEK_MS)
    .sort((left, right) => left.dateMs - right.dateMs)
    .slice(-SOCIAL_RATING_EVENT_LIMIT);
  const weeklyDelta = ratingEvents.reduce((sum, event) => sum + event.delta, 0);
  const leagueTier = totalRatedSessions > 0 ? leagueTierForRating(rating) : null;
  const currentBucket = leagueTier ? `${leagueTier}_${currentWeekKey}` : null;
  return {
    ratingDelta,
    state: {
      schemaVersion: 2,
      rating,
      peakRating,
      totalRatedSessions,
      weekKey: currentWeekKey,
      weeklyReps,
      practiceDays,
      ratingEvents,
      currentBucket,
      latestEvidenceDateMs: evidence.dateMs,
      latestEvidenceSessionID: evidence.sessionID,
      displayName,
      updatedAtMs: nowMs,
    },
    profile: {
      accountID,
      displayName,
      rating,
      peakRating,
      currentStreak: calculateCurrentStreak(practiceDays, nowMs),
      weeklyReps,
      weeklyDelta,
      leagueTier,
      updatedAt: nowMs / 1_000,
    },
  };
}

function assertEvidenceFollowsState(
  previous: StoredSocialState,
  evidence: VerifiedSessionEvidence
): void {
  const previousDate = previous.latestEvidenceDateMs;
  const previousID = previous.latestEvidenceSessionID;
  if (previousDate === null || previousID === null) return;
  if (evidence.dateMs < previousDate ||
      (evidence.dateMs === previousDate &&
       evidence.sessionID <= previousID)) {
    throw new HttpsError(
      "failed-precondition",
      "Competitive evidence must be processed in recording order.",
      {reason: "out-of-order-evidence"}
    );
  }
}

export function profileFromSocialState(
  state: StoredSocialState,
  accountID: string,
  nowMs: number
): PublicProfileEnvelope {
  const currentWeek = isoWeekKey(nowMs);
  const ratingEvents = state.ratingEvents
    .filter((event) => event.dateMs >= nowMs - ROLLING_WEEK_MS);
  const leagueTier = state.totalRatedSessions > 0 ?
    leagueTierForRating(state.rating) : null;
  return {
    accountID,
    displayName: state.displayName,
    rating: state.rating,
    peakRating: state.peakRating,
    currentStreak: calculateCurrentStreak(state.practiceDays, nowMs),
    weeklyReps: state.weekKey === currentWeek ? state.weeklyReps : 0,
    weeklyDelta: ratingEvents.reduce((sum, event) => sum + event.delta, 0),
    leagueTier,
    updatedAt: state.updatedAtMs / 1_000,
  };
}

export function validateStoredPublicProfile(
  value: unknown,
  accountID: string
): PublicProfileEnvelope {
  const validTier = isSocialRecord(value) &&
    (value.leagueTier === null || value.leagueTier === "bronze" ||
     value.leagueTier === "silver" || value.leagueTier === "gold" ||
     value.leagueTier === "platinum" || value.leagueTier === "diamond");
  if (!isSocialRecord(value) || !hasExactKeys(value, [
    "accountID", "displayName", "rating", "peakRating", "currentStreak",
    "weeklyReps", "weeklyDelta", "leagueTier", "updatedAt",
  ]) || value.accountID !== accountID ||
      typeof value.displayName !== "string" ||
      value.displayName.length < 1 ||
      value.displayName.length > MAX_DISPLAY_NAME_CHARS ||
      typeof value.rating !== "number" || !Number.isInteger(value.rating) ||
      value.rating < 100 || value.rating > 1_000 ||
      typeof value.peakRating !== "number" ||
      !Number.isInteger(value.peakRating) ||
      value.peakRating < value.rating || value.peakRating > 1_000 ||
      typeof value.currentStreak !== "number" ||
      !Number.isInteger(value.currentStreak) || value.currentStreak < 0 ||
      value.currentStreak > 10_000 ||
      typeof value.weeklyReps !== "number" ||
      !Number.isInteger(value.weeklyReps) || value.weeklyReps < 0 ||
      value.weeklyReps > 10_000 ||
      typeof value.weeklyDelta !== "number" ||
      !Number.isInteger(value.weeklyDelta) ||
      Math.abs(value.weeklyDelta) > 10_000 || !validTier ||
      !isServerTimestamp(value.updatedAt)) {
    throw new Error("Corrupt server public profile.");
  }
  const updatedAt = socialDateMilliseconds(value.updatedAt);
  if (updatedAt === null) throw new Error("Corrupt server profile timestamp.");
  return {
    accountID,
    displayName: value.displayName,
    rating: value.rating,
    peakRating: value.peakRating,
    currentStreak: value.currentStreak,
    weeklyReps: value.weeklyReps,
    weeklyDelta: value.weeklyDelta,
    leagueTier: value.leagueTier as LeagueTier | null,
    updatedAt: updatedAt / 1_000,
  };
}

export function validateTrustedSocialState(value: unknown): StoredSocialState {
  try {
    if (!isSocialRecord(value) || value.schemaVersion !== 2) throw new Error();
    return storedSocialState(value, "", 0);
  } catch {
    throw new HttpsError(
      "failed-precondition",
      "Trusted league state is not available.",
      {reason: "trusted-social-state-unavailable"}
    );
  }
}

export function currentTrustedLeagueBucket(
  value: unknown,
  nowMs: number
): string {
  const state = validateTrustedSocialState(value);
  const currentWeek = isoWeekKey(nowMs);
  if (!state.currentBucket || state.weekKey !== currentWeek ||
      !state.currentBucket.endsWith(`_${currentWeek}`)) {
    throw new HttpsError(
      "failed-precondition",
      "Trusted league state is not available.",
      {reason: "trusted-social-state-unavailable"}
    );
  }
  return state.currentBucket;
}

export function isSocialReferenceCutoverComplete(value: unknown): boolean {
  if (!isSocialRecord(value) || !hasExactKeys(value, [
    "schemaVersion",
    "status",
    "runID",
    "projectID",
    "sourceGitCommit",
    "sourceImplementationSHA256",
    "backupDigest",
    "inventoryDigest",
    "verifiedInventoryDigest",
    "completedAt",
  ]) || value.schemaVersion !== 3 || value.status !== "complete" ||
      typeof value.runID !== "string" ||
      !SOCIAL_CUTOVER_RUN_ID_PATTERN.test(value.runID) ||
      value.projectID !== PRODUCTION_PROJECT_ID ||
      typeof value.sourceGitCommit !== "string" ||
      !GIT_COMMIT_PATTERN.test(value.sourceGitCommit) ||
      typeof value.sourceImplementationSHA256 !== "string" ||
      !SHA256_PATTERN.test(value.sourceImplementationSHA256) ||
      typeof value.backupDigest !== "string" ||
      !SHA256_PATTERN.test(value.backupDigest) ||
      typeof value.inventoryDigest !== "string" ||
      !SHA256_PATTERN.test(value.inventoryDigest) ||
      typeof value.verifiedInventoryDigest !== "string" ||
      !SHA256_PATTERN.test(value.verifiedInventoryDigest) ||
      value.inventoryDigest !== value.verifiedInventoryDigest ||
      !isServerTimestamp(value.completedAt)) {
    return false;
  }
  return true;
}

export function assertSocialReferenceCutoverComplete(value: unknown): void {
  if (!isSocialReferenceCutoverComplete(value)) {
    throw new HttpsError(
      "failed-precondition",
      "Account deletion is waiting for the legacy social index.",
      {reason: "social-reference-cutover-incomplete"}
    );
  }
}

export function stableLegacyUUID(accountID: string): string {
  const bytes = Buffer.from(
    createHash("sha256").update(accountID).digest().subarray(0, 16)
  );
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-` +
    `${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export function challengeSide(
  challenge: Record<string, unknown>,
  uid: string
): ChallengeSide {
  if (challenge.creatorAccountID === uid) return "creator";
  if (challenge.opponentAccountID === uid) return "opponent";
  throw new HttpsError("permission-denied", "You are not part of this challenge.");
}

export function validateStoredChallenge(
  value: unknown,
  challengeID: string
): Record<string, unknown> {
  if (!isSocialRecord(value) || !hasExactKeys(value, [
    "schemaVersion", "id", "prompt", "promptDigest", "createdAt",
    "expiresAt", "creatorID", "creatorName", "creatorAccountID",
    "opponentID", "opponentName", "opponentAccountID", "participantIDs",
    "completedAt",
  ]) ||
      value.schemaVersion !== CHALLENGE_DOCUMENT_SCHEMA_VERSION ||
      value.id !== challengeID || typeof value.prompt !== "string" ||
      value.prompt.length < 1 || value.prompt.length > MAX_PROMPT_CHARS ||
      typeof value.promptDigest !== "string" ||
      promptDigest(value.prompt) !== value.promptDigest ||
      !isServerTimestamp(value.createdAt) ||
      !isServerTimestamp(value.expiresAt) ||
      typeof value.creatorAccountID !== "string" ||
      typeof value.opponentAccountID !== "string" ||
      value.creatorAccountID === value.opponentAccountID ||
      typeof value.creatorID !== "string" || !UUID_PATTERN.test(value.creatorID) ||
      typeof value.opponentID !== "string" || !UUID_PATTERN.test(value.opponentID) ||
      typeof value.creatorName !== "string" ||
      typeof value.opponentName !== "string" ||
      !Array.isArray(value.participantIDs) ||
      value.participantIDs.length !== 2 ||
      !value.participantIDs.includes(value.creatorAccountID) ||
      !value.participantIDs.includes(value.opponentAccountID) ||
      !(value.completedAt === null || isServerTimestamp(value.completedAt))) {
    throw new Error("Corrupt server challenge.");
  }
  return value;
}

export function challengeSubmissionDocument(
  challengeID: string,
  accountID: string,
  side: ChallengeSide,
  evidence: VerifiedSessionEvidence,
  submittedAt: unknown
): ChallengeSubmission {
  return {
    schemaVersion: 1,
    challengeID,
    accountID,
    side,
    sessionID: evidence.sessionID,
    score: evidence.score,
    duration: evidence.duration,
    summary: evidence.summary,
    submittedAt,
    reaction: null,
    reactedAt: null,
  };
}

export function validateChallengeSubmission(
  value: unknown,
  challengeID: string,
  accountID: string,
  side: ChallengeSide
): ChallengeSubmission {
  if (!isSocialRecord(value) || value.schemaVersion !== 1 ||
      value.challengeID !== challengeID || value.accountID !== accountID ||
      value.side !== side || typeof value.sessionID !== "string" ||
      !UUID_PATTERN.test(value.sessionID) ||
      typeof value.score !== "number" || !Number.isInteger(value.score) ||
      value.score < 0 || value.score > 10 ||
      typeof value.duration !== "number" || !Number.isFinite(value.duration) ||
      value.duration < 1 || value.duration > MAX_SESSION_DURATION_SECONDS ||
      !(value.summary === null ||
        (typeof value.summary === "string" &&
         value.summary.length <= MAX_RESULT_SUMMARY_CHARS)) ||
      !isServerTimestamp(value.submittedAt) ||
      !(value.reaction === null ||
        (typeof value.reaction === "string" &&
         CHALLENGE_REACTIONS.includes(value.reaction as ChallengeReaction))) ||
      !(value.reactedAt === null || isServerTimestamp(value.reactedAt))) {
    throw new Error("Corrupt server challenge submission.");
  }
  return value as unknown as ChallengeSubmission;
}

export function combinedChallengeDocument(
  challengeID: string,
  creator: ChallengeSubmission,
  opponent: ChallengeSubmission,
  completedAt: unknown
): CombinedChallengeResult {
  return {
    schemaVersion: 1,
    challengeID,
    creatorSessionID: creator.sessionID,
    creatorScore: creator.score,
    creatorDuration: creator.duration,
    creatorSummary: creator.summary,
    creatorSubmittedAt: creator.submittedAt,
    creatorReaction: creator.reaction,
    creatorReactedAt: creator.reactedAt,
    opponentSessionID: opponent.sessionID,
    opponentScore: opponent.score,
    opponentDuration: opponent.duration,
    opponentSummary: opponent.summary,
    opponentSubmittedAt: opponent.submittedAt,
    opponentReaction: opponent.reaction,
    opponentReactedAt: opponent.reactedAt,
    completedAt,
  };
}

export function validateCombinedChallengeResult(
  value: unknown,
  challengeID: string
): CombinedChallengeResult {
  if (!isSocialRecord(value) || value.schemaVersion !== 1 ||
      value.challengeID !== challengeID ||
      typeof value.creatorSessionID !== "string" ||
      !UUID_PATTERN.test(value.creatorSessionID) ||
      typeof value.opponentSessionID !== "string" ||
      !UUID_PATTERN.test(value.opponentSessionID) ||
      !validCombinedSide(value, "creator") ||
      !validCombinedSide(value, "opponent") ||
      !isServerTimestamp(value.completedAt)) {
    throw new Error("Corrupt combined challenge result.");
  }
  return value as unknown as CombinedChallengeResult;
}

function validCombinedSide(
  value: Record<string, unknown>,
  side: ChallengeSide
): boolean {
  const score = value[`${side}Score`];
  const duration = value[`${side}Duration`];
  const summary = value[`${side}Summary`];
  const submittedAt = value[`${side}SubmittedAt`];
  const reaction = value[`${side}Reaction`];
  const reactedAt = value[`${side}ReactedAt`];
  return typeof score === "number" && Number.isInteger(score) &&
    score >= 0 && score <= 10 &&
    typeof duration === "number" && Number.isFinite(duration) && duration >= 1 &&
    (summary === null ||
      (typeof summary === "string" && summary.length <= MAX_RESULT_SUMMARY_CHARS)) &&
    isServerTimestamp(submittedAt) &&
    (reaction === null ||
      (typeof reaction === "string" &&
       CHALLENGE_REACTIONS.includes(reaction as ChallengeReaction))) &&
    (reactedAt === null || isServerTimestamp(reactedAt));
}

export function challengeEnvelope(
  value: unknown,
  viewerAccountID?: string,
  ownSubmissionValue?: unknown,
  combinedValue?: unknown
): ChallengeEnvelope {
  if (!isSocialRecord(value) || typeof value.id !== "string") {
    throw new Error("Invalid challenge envelope source.");
  }
  const challenge = validateStoredChallenge(value, value.id);
  const createdAt = socialDateMilliseconds(challenge.createdAt);
  const expiresAt = socialDateMilliseconds(challenge.expiresAt);
  if (createdAt === null || expiresAt === null) {
    throw new Error("Invalid challenge timestamps.");
  }
  let creator: ChallengeSubmission | null = null;
  let opponent: ChallengeSubmission | null = null;
  if (combinedValue !== undefined && combinedValue !== null) {
    const combined = validateCombinedChallengeResult(combinedValue, value.id);
    creator = combinedSideAsSubmission(combined, challenge, "creator");
    opponent = combinedSideAsSubmission(combined, challenge, "opponent");
  } else if (viewerAccountID && ownSubmissionValue) {
    const side = challengeSide(challenge, viewerAccountID);
    const submission = validateChallengeSubmission(
      ownSubmissionValue,
      value.id,
      viewerAccountID,
      side
    );
    if (side === "creator") creator = submission;
    else opponent = submission;
  }
  return {
    id: challenge.id as string,
    prompt: challenge.prompt as string,
    createdAt: createdAt / 1_000,
    expiresAt: expiresAt / 1_000,
    creatorID: challenge.creatorID as string,
    creatorName: challenge.creatorName as string,
    creatorAccountID: challenge.creatorAccountID as string,
    opponentID: challenge.opponentID as string,
    opponentName: challenge.opponentName as string,
    opponentAccountID: challenge.opponentAccountID as string,
    creatorScore: creator?.score ?? null,
    creatorDuration: creator?.duration ?? null,
    creatorSummary: creator?.summary ?? null,
    opponentScore: opponent?.score ?? null,
    opponentDuration: opponent?.duration ?? null,
    opponentSummary: opponent?.summary ?? null,
    creatorReaction: creator?.reaction ?? null,
    opponentReaction: opponent?.reaction ?? null,
  };
}

function combinedSideAsSubmission(
  combined: CombinedChallengeResult,
  challenge: Record<string, unknown>,
  side: ChallengeSide
): ChallengeSubmission {
  const accountID = challenge[`${side}AccountID`];
  if (typeof accountID !== "string") {
    throw new Error("Corrupt challenge participant.");
  }
  return {
    schemaVersion: 1,
    challengeID: combined.challengeID,
    accountID,
    side,
    sessionID: combined[`${side}SessionID`],
    score: combined[`${side}Score`],
    duration: combined[`${side}Duration`],
    summary: combined[`${side}Summary`],
    submittedAt: combined[`${side}SubmittedAt`],
    reaction: combined[`${side}Reaction`],
    reactedAt: combined[`${side}ReactedAt`],
  };
}

export function validateReciprocalFriendLinks(
  creatorLinkValue: unknown,
  opponentLinkValue: unknown,
  creatorAccountID: string,
  opponentAccountID: string
): void {
  const valid = isSocialRecord(creatorLinkValue) &&
    isSocialRecord(opponentLinkValue) &&
    hasExactKeys(creatorLinkValue, [
      "schemaVersion", "status", "accountID", "friendAccountID", "pairID",
      "linkedAt",
    ]) &&
    hasExactKeys(opponentLinkValue, [
      "schemaVersion", "status", "accountID", "friendAccountID", "pairID",
      "linkedAt",
    ]) &&
    creatorLinkValue.schemaVersion === 1 &&
    opponentLinkValue.schemaVersion === 1 &&
    creatorLinkValue.status === "active" &&
    opponentLinkValue.status === "active" &&
    creatorLinkValue.accountID === creatorAccountID &&
    creatorLinkValue.friendAccountID === opponentAccountID &&
    opponentLinkValue.accountID === opponentAccountID &&
    opponentLinkValue.friendAccountID === creatorAccountID &&
    typeof creatorLinkValue.pairID === "string" &&
    UUID_PATTERN.test(creatorLinkValue.pairID) &&
    opponentLinkValue.pairID === creatorLinkValue.pairID &&
    isServerTimestamp(creatorLinkValue.linkedAt) &&
    isServerTimestamp(opponentLinkValue.linkedAt);
  if (!valid) {
    throw new HttpsError(
      "failed-precondition",
      "Challenges require a server-verified friend link.",
      {reason: "friend-authorization-unavailable"}
    );
  }
}

export function validateSocialReferenceManifest(
  value: unknown,
  accountID: string
): SocialReferenceManifest {
  if (value === undefined || value === null) {
    return {
      leagueMembershipPaths: [],
      challengeIDs: [],
      friendAccountIDs: [],
    };
  }
  if (!isSocialRecord(value)) {
    throw new Error("Corrupt server social references.");
  }
  const leagueMembershipPaths = value.leagueMembershipPaths;
  const challengeIDs = value.challengeIDs;
  const friendAccountIDs = value.friendAccountIDs;
  if (!Array.isArray(leagueMembershipPaths) ||
      leagueMembershipPaths.length > MAX_REFERENCE_LEAGUES ||
      !leagueMembershipPaths.every((path) =>
        validLeagueMembershipPath(path, accountID)) ||
      !Array.isArray(challengeIDs) ||
      challengeIDs.length > MAX_REFERENCE_CHALLENGES ||
      !challengeIDs.every((id) =>
        typeof id === "string" && UUID_PATTERN.test(id)) ||
      !Array.isArray(friendAccountIDs) ||
      friendAccountIDs.length > MAX_REFERENCE_FRIENDS ||
      !friendAccountIDs.every((id) =>
        isValidFirebaseUID(id) && id !== accountID)) {
    throw new Error("Corrupt server social references.");
  }
  return {
    leagueMembershipPaths: [...new Set(leagueMembershipPaths as string[])],
    challengeIDs: [...new Set(
      (challengeIDs as string[]).map((id) => id.toUpperCase())
    )],
    friendAccountIDs: [...new Set(friendAccountIDs as string[])],
  };
}

export function socialReferenceManifestIncludingChallenge(
  value: unknown,
  accountID: string,
  challengeID: string
): SocialReferenceManifest {
  const references = validateSocialReferenceManifest(value, accountID);
  const canonicalChallengeID = challengeID.toUpperCase();
  if (!UUID_PATTERN.test(canonicalChallengeID)) {
    throw new Error("Invalid server challenge reference.");
  }
  if (references.challengeIDs.includes(canonicalChallengeID)) {
    return references;
  }
  if (references.challengeIDs.length >= MAX_REFERENCE_CHALLENGES) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many retained challenges. Try again later.",
      {reason: "challenge-reference-capacity"}
    );
  }
  return {
    leagueMembershipPaths: references.leagueMembershipPaths,
    challengeIDs: [...references.challengeIDs, canonicalChallengeID],
    friendAccountIDs: references.friendAccountIDs,
  };
}

export function socialReferenceManifestUpdatingLeagueMembership(
  value: unknown,
  accountID: string,
  previousBucket: string | null,
  nextBucket: string | null
): SocialReferenceManifest {
  const references = validateSocialReferenceManifest(value, accountID);
  const previousPath = previousBucket ?
    `leagues/${previousBucket}/members/${accountID}` : null;
  const nextPath = nextBucket ?
    `leagues/${nextBucket}/members/${accountID}` : null;
  const leagueMembershipPaths = references.leagueMembershipPaths.filter(
    (path) => path !== previousPath
  );
  if (nextPath && !leagueMembershipPaths.includes(nextPath)) {
    if (leagueMembershipPaths.length >= MAX_REFERENCE_LEAGUES) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many retained league references. Try again later.",
        {reason: "league-reference-capacity"}
      );
    }
    leagueMembershipPaths.push(nextPath);
  }
  return {
    leagueMembershipPaths,
    challengeIDs: references.challengeIDs,
    friendAccountIDs: references.friendAccountIDs,
  };
}

function validLeagueMembershipPath(value: unknown, accountID: string): boolean {
  if (typeof value !== "string") return false;
  const parts = value.split("/");
  return parts.length === 4 && parts[0] === "leagues" &&
    LEAGUE_BUCKET_PATTERN.test(parts[1]) &&
    parts[2] === "members" && parts[3] === accountID;
}
