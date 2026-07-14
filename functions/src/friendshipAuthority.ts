/* eslint-disable valid-jsdoc, require-jsdoc, max-len */

import {createHash, randomBytes} from "node:crypto";
import {HttpsError} from "firebase-functions/v2/https";

export const FRIENDSHIP_SCHEMA_VERSION = 1;
export const FRIEND_LINK_SCHEMA_VERSION = 2;
export const FRIEND_INVITE_LIFETIME_MS = 24 * 60 * 60 * 1_000;
export const MAX_ACTIVE_FRIEND_INVITES = 5;
export const MAX_ACTIVE_FRIENDS = 50;
export const FRIEND_INVITE_CREATE_MINUTE_LIMIT = 3;
export const FRIEND_INVITE_CREATE_HOUR_LIMIT = 10;
export const FRIEND_INVITE_ACCEPT_MINUTE_LIMIT = 10;
export const FRIEND_INVITE_ACCEPT_HOUR_LIMIT = 50;
export const FRIEND_LINK_LIST_MINUTE_LIMIT = 10;
export const FRIEND_LINK_LIST_HOUR_LIMIT = 100;
export const FRIEND_LINK_REMOVE_MINUTE_LIMIT = 10;
export const FRIEND_LINK_REMOVE_HOUR_LIMIT = 100;

const MAX_DISPLAY_NAME_CHARS = 60;
const TOKEN_BYTE_COUNT = 32;
const TOKEN_CHARACTER_COUNT = 43;
const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;
const FRIEND_INVITE_DIGEST_DOMAIN = Buffer.from(
  "noum.friend-invite.v1\0",
  "utf8"
);
const SHA256_PATTERN = /^[0-9a-f]{64}$/;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export interface CreateFriendInviteInput {
  schemaVersion: 1;
  displayName: string;
}

export interface AcceptFriendInviteInput {
  schemaVersion: 1;
  inviteToken: string;
  displayName: string;
}

export interface ListFriendLinksInput {
  schemaVersion: 1;
  limit: number;
}

export interface RemoveFriendLinkInput {
  schemaVersion: 1;
  friendAccountID: string;
  pairID: string;
}

export interface FriendInviteSecret {
  inviteToken: string;
  tokenDigest: string;
}

export interface StoredFriendInvite {
  schemaVersion: 1;
  status: "active" | "accepted" | "revoked" | "superseded";
  tokenDigest: string;
  inviterAccountID: string;
  inviterDisplayName: string;
  createdAtMs: number;
  expiresAtMs: number;
  acceptedAccountID: string | null;
  acceptorDisplayName: string | null;
  acceptedAtMs: number | null;
  pairID: string | null;
  revokedAtMs: number | null;
}

export interface StoredFriendInviteReference {
  schemaVersion: 1;
  tokenDigest: string;
  accountID: string;
  role: "inviter" | "acceptor";
  status: "active" | "accepted" | "revoked" | "superseded";
  counterpartAccountID: string | null;
  expiresAtMs: number;
  updatedAtMs: number;
}

export type TimestampMilliseconds = (value: unknown) => number | null;

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

function validatedDisplayName(value: unknown): string {
  if (typeof value !== "string" || value !== value.trim() ||
      value.length < 1 || value.length > MAX_DISPLAY_NAME_CHARS) {
    throw new HttpsError("invalid-argument", "Invalid display name.");
  }
  return value;
}

function isValidAccountID(value: unknown): value is string {
  if (typeof value !== "string" || value !== value.trim() ||
      value.length < 1 || value.length > 128 || value.includes("/")) {
    return false;
  }
  return !Array.from(value).some((character) => {
    const code = character.charCodeAt(0);
    return code < 32 || code === 127;
  });
}

export function validateCreateFriendInviteRequest(
  data: unknown
): CreateFriendInviteInput {
  if (!isRecord(data) || !hasExactKeys(data, [
    "schemaVersion", "displayName",
  ]) || data.schemaVersion !== FRIENDSHIP_SCHEMA_VERSION) {
    throw new HttpsError("invalid-argument", "Invalid friend invite request.");
  }
  return {schemaVersion: 1, displayName: validatedDisplayName(data.displayName)};
}

export function validateAcceptFriendInviteRequest(
  data: unknown
): AcceptFriendInviteInput {
  if (!isRecord(data) || !hasExactKeys(data, [
    "schemaVersion", "inviteToken", "displayName",
  ]) || data.schemaVersion !== FRIENDSHIP_SCHEMA_VERSION) {
    throw new HttpsError("invalid-argument", "Invalid friend invite request.");
  }
  const inviteToken = validatedInviteToken(data.inviteToken);
  return {
    schemaVersion: 1,
    inviteToken,
    displayName: validatedDisplayName(data.displayName),
  };
}

export function validateListFriendLinksRequest(
  data: unknown
): ListFriendLinksInput {
  if (!isRecord(data) || !hasExactKeys(data, [
    "schemaVersion", "limit",
  ]) || data.schemaVersion !== FRIENDSHIP_SCHEMA_VERSION ||
      typeof data.limit !== "number" || !Number.isInteger(data.limit) ||
      data.limit !== MAX_ACTIVE_FRIENDS) {
    throw new HttpsError("invalid-argument", "Invalid friend list request.");
  }
  return {schemaVersion: 1, limit: data.limit};
}

export function validateRemoveFriendLinkRequest(
  data: unknown
): RemoveFriendLinkInput {
  if (!isRecord(data) || !hasExactKeys(data, [
    "schemaVersion", "friendAccountID", "pairID",
  ]) || data.schemaVersion !== FRIENDSHIP_SCHEMA_VERSION ||
      !isValidAccountID(data.friendAccountID) ||
      typeof data.pairID !== "string" || !UUID_PATTERN.test(data.pairID)) {
    throw new HttpsError("invalid-argument", "Invalid friend removal request.");
  }
  return {
    schemaVersion: 1,
    friendAccountID: data.friendAccountID,
    pairID: data.pairID.toUpperCase(),
  };
}

function validatedInviteToken(value: unknown): string {
  if (typeof value !== "string" || value.length !== TOKEN_CHARACTER_COUNT ||
      !TOKEN_PATTERN.test(value)) {
    throw new HttpsError("invalid-argument", "Invalid friend invite token.");
  }
  const bytes = Buffer.from(value, "base64url");
  if (bytes.length !== TOKEN_BYTE_COUNT || bytes.toString("base64url") !== value) {
    throw new HttpsError("invalid-argument", "Invalid friend invite token.");
  }
  return value;
}

export function friendInviteDigest(inviteToken: unknown): string {
  const token = validatedInviteToken(inviteToken);
  const tokenBytes = Buffer.from(token, "base64url");
  return createHash("sha256")
    .update(FRIEND_INVITE_DIGEST_DOMAIN)
    .update(tokenBytes)
    .digest("hex");
}

export function generateFriendInviteSecret(): FriendInviteSecret {
  const inviteToken = randomBytes(TOKEN_BYTE_COUNT).toString("base64url");
  return {inviteToken, tokenDigest: friendInviteDigest(inviteToken)};
}

export function validateStoredFriendInvite(
  value: unknown,
  tokenDigest: string,
  timestampMilliseconds: TimestampMilliseconds
): StoredFriendInvite {
  if (!SHA256_PATTERN.test(tokenDigest) || !isRecord(value) ||
      !hasExactKeys(value, [
        "schemaVersion", "status", "tokenDigest", "inviterAccountID",
        "inviterDisplayName", "createdAt", "expiresAt",
        "acceptedAccountID", "acceptorDisplayName", "acceptedAt", "pairID",
        "revokedAt",
      ]) || value.schemaVersion !== FRIENDSHIP_SCHEMA_VERSION ||
      (value.status !== "active" && value.status !== "accepted" &&
       value.status !== "revoked" && value.status !== "superseded") ||
      value.tokenDigest !== tokenDigest ||
      !isValidAccountID(value.inviterAccountID) ||
      typeof value.inviterDisplayName !== "string" ||
      value.inviterDisplayName !== value.inviterDisplayName.trim() ||
      value.inviterDisplayName.length < 1 ||
      value.inviterDisplayName.length > MAX_DISPLAY_NAME_CHARS) {
    throw new HttpsError(
      "failed-precondition",
      "This friend invite is unavailable.",
      {reason: "friend-invite-unavailable"}
    );
  }
  const createdAtMs = timestampMilliseconds(value.createdAt);
  const expiresAtMs = timestampMilliseconds(value.expiresAt);
  const acceptedAtMs = value.acceptedAt === null ?
    null : timestampMilliseconds(value.acceptedAt);
  const revokedAtMs = value.revokedAt === null ?
    null : timestampMilliseconds(value.revokedAt);
  const activeShape = value.status === "active" &&
    value.acceptedAccountID === null && value.acceptorDisplayName === null &&
    value.acceptedAt === null && value.pairID === null &&
    value.revokedAt === null;
  const acceptedShape = value.status === "accepted" &&
    isValidAccountID(value.acceptedAccountID) &&
    value.acceptedAccountID !== value.inviterAccountID &&
    typeof value.acceptorDisplayName === "string" &&
    value.acceptorDisplayName === value.acceptorDisplayName.trim() &&
    value.acceptorDisplayName.length >= 1 &&
    value.acceptorDisplayName.length <= MAX_DISPLAY_NAME_CHARS &&
    acceptedAtMs !== null && typeof value.pairID === "string" &&
    UUID_PATTERN.test(value.pairID) && value.revokedAt === null;
  const revokedShape = value.status === "revoked" &&
    isValidAccountID(value.acceptedAccountID) &&
    value.acceptedAccountID !== value.inviterAccountID &&
    typeof value.acceptorDisplayName === "string" &&
    value.acceptorDisplayName === value.acceptorDisplayName.trim() &&
    value.acceptorDisplayName.length >= 1 &&
    value.acceptorDisplayName.length <= MAX_DISPLAY_NAME_CHARS &&
    acceptedAtMs !== null && typeof value.pairID === "string" &&
    UUID_PATTERN.test(value.pairID) && revokedAtMs !== null;
  const supersededShape = value.status === "superseded" &&
    isValidAccountID(value.acceptedAccountID) &&
    value.acceptedAccountID !== value.inviterAccountID &&
    typeof value.acceptorDisplayName === "string" &&
    value.acceptorDisplayName === value.acceptorDisplayName.trim() &&
    value.acceptorDisplayName.length >= 1 &&
    value.acceptorDisplayName.length <= MAX_DISPLAY_NAME_CHARS &&
    value.acceptedAt === null && value.pairID === null && revokedAtMs !== null;
  if (createdAtMs === null || expiresAtMs === null ||
      expiresAtMs - createdAtMs !== FRIEND_INVITE_LIFETIME_MS ||
      (!activeShape && !acceptedShape && !revokedShape && !supersededShape) ||
      (acceptedAtMs !== null &&
       (acceptedAtMs < createdAtMs || acceptedAtMs > expiresAtMs)) ||
      (value.status === "revoked" &&
       (revokedAtMs === null || acceptedAtMs === null ||
        revokedAtMs < acceptedAtMs)) ||
      (value.status === "superseded" &&
       (revokedAtMs === null || revokedAtMs < createdAtMs ||
        revokedAtMs > expiresAtMs))) {
    throw new HttpsError(
      "failed-precondition",
      "This friend invite is unavailable.",
      {reason: "friend-invite-unavailable"}
    );
  }
  return {
    schemaVersion: 1,
    status: value.status,
    tokenDigest,
    inviterAccountID: value.inviterAccountID,
    inviterDisplayName: value.inviterDisplayName,
    createdAtMs,
    expiresAtMs,
    acceptedAccountID: value.acceptedAccountID,
    acceptorDisplayName: value.acceptorDisplayName,
    acceptedAtMs,
    pairID: value.pairID,
    revokedAtMs,
  } as StoredFriendInvite;
}

export function validateStoredFriendInviteReference(
  value: unknown,
  accountID: string,
  tokenDigest: string,
  timestampMilliseconds: TimestampMilliseconds
): StoredFriendInviteReference {
  if (!isValidAccountID(accountID) || !SHA256_PATTERN.test(tokenDigest) ||
      !isRecord(value) || !hasExactKeys(value, [
    "schemaVersion", "tokenDigest", "accountID", "role", "status",
    "counterpartAccountID", "expiresAt", "updatedAt",
  ]) || value.schemaVersion !== FRIENDSHIP_SCHEMA_VERSION ||
      value.tokenDigest !== tokenDigest || value.accountID !== accountID ||
      (value.role !== "inviter" && value.role !== "acceptor") ||
      (value.status !== "active" && value.status !== "accepted" &&
       value.status !== "revoked" && value.status !== "superseded")) {
    throw new Error("Corrupt server friend invite reference.");
  }
  const expiresAtMs = timestampMilliseconds(value.expiresAt);
  const updatedAtMs = timestampMilliseconds(value.updatedAt);
  const validActive = value.role === "inviter" && value.status === "active" &&
    value.counterpartAccountID === null;
  const validAccepted = (value.status === "accepted" ||
    value.status === "revoked") &&
    isValidAccountID(value.counterpartAccountID) &&
    value.counterpartAccountID !== accountID;
  const validSuperseded = value.status === "superseded" &&
    value.role === "inviter" &&
    isValidAccountID(value.counterpartAccountID) &&
    value.counterpartAccountID !== accountID;
  if (expiresAtMs === null || updatedAtMs === null ||
      (!validActive && !validAccepted && !validSuperseded)) {
    throw new Error("Corrupt server friend invite reference.");
  }
  return {
    schemaVersion: 1,
    tokenDigest,
    accountID,
    role: value.role,
    status: value.status,
    counterpartAccountID: value.counterpartAccountID,
    expiresAtMs,
    updatedAtMs,
  } as StoredFriendInviteReference;
}

export function validateBoundFriendInviteReference(
  value: unknown,
  accountID: string,
  tokenDigest: string,
  role: "inviter" | "acceptor",
  status: "active" | "accepted" | "revoked" | "superseded",
  counterpartAccountID: string | null,
  timestampMilliseconds: TimestampMilliseconds
): StoredFriendInviteReference {
  const reference = validateStoredFriendInviteReference(
    value,
    accountID,
    tokenDigest,
    timestampMilliseconds
  );
  if (reference.role !== role || reference.status !== status ||
      reference.counterpartAccountID !== counterpartAccountID) {
    throw new Error("Corrupt server friend invite reference.");
  }
  return reference;
}
