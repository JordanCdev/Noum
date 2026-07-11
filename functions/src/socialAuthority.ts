/* eslint-disable valid-jsdoc, require-jsdoc, max-len */

import {createHash} from "node:crypto";
import {HttpsError} from "firebase-functions/v2/https";

export const SOCIAL_SCHEMA_VERSION = 1;
export const INITIAL_RATING = 400;
export const MAX_DISPLAY_NAME_CHARS = 60;
export const MAX_PROMPT_CHARS = 500;
export const MAX_RESULT_SUMMARY_CHARS = 240;
export const CHALLENGE_LIFETIME_MS = 3 * 24 * 60 * 60 * 1_000;
export const SOCIAL_PRACTICE_DAY_LIMIT = 400;
export const SOCIAL_RATING_EVENT_LIMIT = 100;
export const CHALLENGE_REACTIONS = [
  "🔥", "👏", "💪", "🤯", "🏆", "❤️",
] as const;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MAX_CLOCK_SKEW_MS = 5 * 60 * 1_000;
const MIN_SESSION_DATE_MS = Date.UTC(2020, 0, 1);
const MAX_SESSION_DURATION_SECONDS = 4 * 60 * 60;
const ROLLING_WEEK_MS = 7 * 24 * 60 * 60 * 1_000;

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

export interface ValidatedSocialSession {
  sessionID: string;
  score: number;
  dateMs: number;
  duration: number;
  isRated: boolean;
  summary: string | null;
}

export interface RatingEvent {
  sessionID: string;
  dateMs: number;
  delta: number;
}

export interface StoredSocialState {
  schemaVersion: 1;
  rating: number;
  peakRating: number;
  totalRatedSessions: number;
  weekKey: string;
  weeklyReps: number;
  practiceDays: string[];
  ratingEvents: RatingEvent[];
  currentBucket: string | null;
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

/** True only for an unboxed JSON object. */
export function isSocialRecord(
  value: unknown
): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Enforces an exact request key set before public data reaches a handler. */
function hasExactKeys(
  value: Record<string, unknown>,
  expected: string[]
): boolean {
  const actual = Object.keys(value).sort();
  const sortedExpected = [...expected].sort();
  return actual.length === sortedExpected.length &&
    actual.every((key, index) => key === sortedExpected[index]);
}

/** Returns a normalized UUID or rejects the public request. */
function validatedUUID(value: unknown, label: string): string {
  if (typeof value !== "string" || !UUID_PATTERN.test(value)) {
    throw new HttpsError("invalid-argument", `Invalid ${label}.`);
  }
  return value.toUpperCase();
}

/** Returns a bounded, non-blank string without silently trimming it. */
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

/** Firebase UIDs are opaque but cannot be blank, huge, or contain a slash. */
export function validateFirebaseUID(value: unknown): string {
  const hasControlCharacter = typeof value === "string" &&
    Array.from(value).some((character) => {
      const code = character.charCodeAt(0);
      return code < 32 || code === 127;
    });
  if (typeof value !== "string" || value !== value.trim() ||
      value.length < 1 || value.length > 128 || value.includes("/") ||
      hasControlCharacter) {
    throw new HttpsError("invalid-argument", "Invalid participant account.");
  }
  return value;
}

/** Validates the exact v1 record-peer-session request. */
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

/** Validates the exact v1 challenge-creation request. */
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

/** Validates the exact v1 challenge-result request. */
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

/** Validates the exact v1 reaction request and its closed enum. */
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

/** Converts supported persisted date representations to Unix milliseconds. */
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

/**
 * Validates that a social result comes from a complete, non-fixture session.
 * The callable never accepts score, duration, date, or rating flags directly.
 */
export function validateStoredSocialSession(
  value: unknown,
  sessionID: string,
  nowMs: number
): ValidatedSocialSession {
  if (!isSocialRecord(value) ||
      typeof value.id !== "string" || value.id.toUpperCase() !== sessionID ||
      typeof value.transcript !== "string" || value.transcript.trim().length < 1 ||
      typeof value.duration !== "number" || !Number.isFinite(value.duration) ||
      value.duration < 1 || value.duration > MAX_SESSION_DURATION_SECONDS ||
      typeof value.score !== "number" || !Number.isInteger(value.score) ||
      value.score < 0 || value.score > 10 ||
      typeof value.isRated !== "boolean" ||
      value.isEvaluationFixture !== false ||
      (value.fixtureID !== undefined && value.fixtureID !== null)) {
    throw new HttpsError(
      "failed-precondition",
      "This session is not a complete real recording."
    );
  }
  const dateMs = socialDateMilliseconds(value.date);
  if (dateMs === null || dateMs < MIN_SESSION_DATE_MS ||
      dateMs > nowMs + MAX_CLOCK_SKEW_MS) {
    throw new HttpsError(
      "failed-precondition",
      "This session does not have a valid completion date."
    );
  }
  const summaryValue = [value.headline, value.coachSummary]
    .find((candidate) => typeof candidate === "string" && candidate.trim().length > 0);
  const summary = typeof summaryValue === "string" ?
    Array.from(summaryValue.trim()).slice(0, MAX_RESULT_SUMMARY_CHARS).join("") :
    null;
  return {
    sessionID,
    score: value.score,
    dateMs,
    duration: value.duration,
    isRated: value.isRated,
    summary,
  };
}

/** Swift's default `.rounded()` is nearest-or-away-from-zero on exact ties. */
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

/** UTC ISO-week key used by both the state reducer and league bucket. */
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

/** UTC calendar-day key, avoiding server locale and daylight-saving drift. */
export function socialDayKey(dateMs: number): string {
  return new Date(dateMs).toISOString().slice(0, 10);
}

/** Returns the rating tier for a server-owned rating. */
export function leagueTierForRating(rating: number): LeagueTier {
  if (rating < 300) return "bronze";
  if (rating < 500) return "silver";
  if (rating < 700) return "gold";
  if (rating < 850) return "platinum";
  return "diamond";
}

/** Mirrors the app's one-grace-day streak over a bounded UTC day set. */
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
  let graceUsed = false;
  for (let checked = 0; checked <= SOCIAL_PRACTICE_DAY_LIMIT; checked += 1) {
    if (days.has(keyAt(cursor))) {
      streak += 1;
    } else if (!graceUsed) {
      graceUsed = true;
    } else {
      break;
    }
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  return streak;
}

/** Strictly restores server-only social state or initializes it once. */
export function storedSocialState(
  value: unknown,
  displayName: string,
  nowMs: number
): StoredSocialState {
  if (value === undefined || value === null) {
    return {
      schemaVersion: 1,
      rating: INITIAL_RATING,
      peakRating: INITIAL_RATING,
      totalRatedSessions: 0,
      weekKey: isoWeekKey(nowMs),
      weeklyReps: 0,
      practiceDays: [],
      ratingEvents: [],
      currentBucket: null,
      displayName,
      updatedAtMs: nowMs,
    };
  }
  if (!isSocialRecord(value) || value.schemaVersion !== 1 ||
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
      !(value.currentBucket === null || typeof value.currentBucket === "string") ||
      typeof value.displayName !== "string" ||
      typeof value.updatedAtMs !== "number" || !Number.isFinite(value.updatedAtMs)) {
    throw new Error("Corrupt server social state.");
  }
  return value as unknown as StoredSocialState;
}

/** Validates one bounded server-owned rating-history item. */
function validRatingEvent(value: unknown): value is RatingEvent {
  return isSocialRecord(value) && typeof value.sessionID === "string" &&
    UUID_PATTERN.test(value.sessionID) && typeof value.dateMs === "number" &&
    Number.isFinite(value.dateMs) && typeof value.delta === "number" &&
    Number.isInteger(value.delta) && Math.abs(value.delta) <= 32;
}

/** Advances public statistics from exactly one already-validated session. */
export function advanceSocialState(
  previous: StoredSocialState,
  session: ValidatedSocialSession,
  accountID: string,
  displayName: string,
  nowMs: number
): AdvancedSocialState {
  const currentWeekKey = isoWeekKey(nowMs);
  const sessionWeekKey = isoWeekKey(session.dateMs);
  const weeklyReps = (previous.weekKey === currentWeekKey ?
    previous.weeklyReps : 0) + (sessionWeekKey === currentWeekKey ? 1 : 0);
  const ratingDelta = session.isRated ?
    calculateRatingDelta(previous.rating, session.score) : 0;
  const rating = session.isRated ?
    Math.max(100, Math.min(1_000, previous.rating + ratingDelta)) :
    previous.rating;
  const peakRating = Math.max(previous.peakRating, rating);
  const totalRatedSessions = previous.totalRatedSessions +
    (session.isRated ? 1 : 0);

  const oldestDayMs = nowMs - SOCIAL_PRACTICE_DAY_LIMIT * 86_400_000;
  const practiceDays = Array.from(new Set([
    ...previous.practiceDays.filter((day) => {
      const parsed = Date.parse(`${day}T00:00:00.000Z`);
      return Number.isFinite(parsed) && parsed >= oldestDayMs;
    }),
    socialDayKey(session.dateMs),
  ])).sort().slice(-SOCIAL_PRACTICE_DAY_LIMIT);

  const ratingEvents = [
    ...previous.ratingEvents,
    ...(session.isRated ? [{
      sessionID: session.sessionID,
      dateMs: session.dateMs,
      delta: ratingDelta,
    }] : []),
  ]
    .filter((event) => event.dateMs >= nowMs - ROLLING_WEEK_MS)
    .sort((left, right) => left.dateMs - right.dateMs)
    .slice(-SOCIAL_RATING_EVENT_LIMIT);
  const weeklyDelta = ratingEvents.reduce((sum, event) => sum + event.delta, 0);
  const leagueTier = totalRatedSessions > 0 ? leagueTierForRating(rating) : null;
  const currentBucket = leagueTier ? `${leagueTier}_${currentWeekKey}` : null;
  const updatedAt = nowMs / 1_000;

  return {
    ratingDelta,
    state: {
      schemaVersion: 1,
      rating,
      peakRating,
      totalRatedSessions,
      weekKey: currentWeekKey,
      weeklyReps,
      practiceDays,
      ratingEvents,
      currentBucket,
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
      updatedAt,
    },
  };
}

/** Reconstructs the latest profile on an idempotent record-session replay. */
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

/** Stable presentation-only UUID for legacy Swift challenge fields. */
export function stableLegacyUUID(accountID: string): string {
  const bytes = Buffer.from(createHash("sha256").update(accountID).digest().subarray(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-` +
    `${hex.slice(16, 20)}-${hex.slice(20)}`;
}

/** Returns which immutable side of a challenge belongs to the caller. */
export function challengeSide(
  challenge: Record<string, unknown>,
  uid: string
): ChallengeSide {
  if (challenge.creatorAccountID === uid) return "creator";
  if (challenge.opponentAccountID === uid) return "opponent";
  throw new HttpsError("permission-denied", "You are not part of this challenge.");
}

/** Validates a server-owned challenge enough for safe updates and responses. */
export function validateStoredChallenge(
  value: unknown,
  challengeID: string
): Record<string, unknown> {
  if (!isSocialRecord(value) || value.schemaVersion !== 1 ||
      value.id !== challengeID || typeof value.prompt !== "string" ||
      socialDateMilliseconds(value.createdAt) === null ||
      socialDateMilliseconds(value.expiresAt) === null ||
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
      !value.participantIDs.includes(value.opponentAccountID)) {
    throw new Error("Corrupt server challenge.");
  }
  return value;
}

/** Serializes Firestore timestamps and optional fields into the locked wire DTO. */
export function challengeEnvelope(value: unknown): ChallengeEnvelope {
  if (!isSocialRecord(value) || typeof value.id !== "string") {
    throw new Error("Invalid challenge envelope source.");
  }
  const challenge = validateStoredChallenge(value, value.id);
  const createdAt = socialDateMilliseconds(challenge.createdAt);
  const expiresAt = socialDateMilliseconds(challenge.expiresAt);
  if (createdAt === null || expiresAt === null) {
    throw new Error("Invalid challenge timestamps.");
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
    creatorScore: optionalInteger(challenge.creatorScore),
    creatorDuration: optionalNumber(challenge.creatorDuration),
    creatorSummary: optionalString(challenge.creatorSummary),
    opponentScore: optionalInteger(challenge.opponentScore),
    opponentDuration: optionalNumber(challenge.opponentDuration),
    opponentSummary: optionalString(challenge.opponentSummary),
    creatorReaction: optionalReaction(challenge.creatorReaction),
    opponentReaction: optionalReaction(challenge.opponentReaction),
  };
}

function optionalInteger(value: unknown): number | null {
  return typeof value === "number" && Number.isInteger(value) ? value : null;
}

function optionalNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function optionalString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function optionalReaction(value: unknown): ChallengeReaction | null {
  return typeof value === "string" &&
    CHALLENGE_REACTIONS.includes(value as ChallengeReaction) ?
    value as ChallengeReaction : null;
}
