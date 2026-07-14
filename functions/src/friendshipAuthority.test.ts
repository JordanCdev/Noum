/* eslint-disable valid-jsdoc, require-jsdoc, max-len */

import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import test from "node:test";
import {
  FRIEND_INVITE_LIFETIME_MS,
  MAX_ACTIVE_FRIENDS,
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

const nowMs = Date.UTC(2026, 6, 14, 16);
const digest = "a".repeat(64);

function timestamp(milliseconds: number): {toMillis: () => number} {
  return {toMillis: () => milliseconds};
}

function timestampMilliseconds(value: unknown): number | null {
  if (typeof value !== "object" || value === null ||
      !("toMillis" in value) ||
      typeof (value as {toMillis?: unknown}).toMillis !== "function") {
    return null;
  }
  return (value as {toMillis: () => number}).toMillis();
}

function activeInvite(overrides: Record<string, unknown> = {}): object {
  return {
    schemaVersion: 1,
    status: "active",
    tokenDigest: digest,
    inviterAccountID: "inviter-account",
    inviterDisplayName: "Jordan",
    createdAt: timestamp(nowMs),
    expiresAt: timestamp(nowMs + FRIEND_INVITE_LIFETIME_MS),
    acceptedAccountID: null,
    acceptorDisplayName: null,
    acceptedAt: null,
    pairID: null,
    revokedAt: null,
    ...overrides,
  };
}

test("friendship requests require exact bounded v1 contracts", () => {
  assert.deepEqual(validateCreateFriendInviteRequest({
    schemaVersion: 1,
    displayName: "Jordan",
  }), {schemaVersion: 1, displayName: "Jordan"});
  assert.throws(() => validateCreateFriendInviteRequest({
    schemaVersion: 1,
    displayName: " Jordan",
  }));
  assert.throws(() => validateCreateFriendInviteRequest({
    schemaVersion: 1,
    displayName: "Jordan",
    accountID: "client-claim",
  }));

  const secret = generateFriendInviteSecret();
  assert.deepEqual(validateAcceptFriendInviteRequest({
    schemaVersion: 1,
    inviteToken: secret.inviteToken,
    displayName: "Alex",
  }), {
    schemaVersion: 1,
    inviteToken: secret.inviteToken,
    displayName: "Alex",
  });
  assert.throws(() => validateAcceptFriendInviteRequest({
    schemaVersion: 1,
    inviteToken: `${secret.inviteToken}=`,
    displayName: "Alex",
  }));
  assert.throws(() => validateAcceptFriendInviteRequest({
    schemaVersion: 1,
    inviteToken: secret.inviteToken,
    displayName: "Alex",
    inviterAccountID: "client-claim",
  }));

  assert.deepEqual(validateListFriendLinksRequest({
    schemaVersion: 1,
    limit: MAX_ACTIVE_FRIENDS,
  }), {schemaVersion: 1, limit: MAX_ACTIVE_FRIENDS});
  assert.throws(() => validateListFriendLinksRequest({
    schemaVersion: 1,
    limit: MAX_ACTIVE_FRIENDS - 1,
  }));
  assert.deepEqual(validateRemoveFriendLinkRequest({
    schemaVersion: 1,
    friendAccountID: "friend-account",
    pairID: "c713738e-d9ed-4337-986e-09205089d42e",
  }), {
    schemaVersion: 1,
    friendAccountID: "friend-account",
    pairID: "C713738E-D9ED-4337-986E-09205089D42E",
  });
  assert.throws(() => validateRemoveFriendLinkRequest({
    schemaVersion: 1,
    friendAccountID: "friend/account",
    pairID: "C713738E-D9ED-4337-986E-09205089D42E",
  }));
  assert.throws(() => validateRemoveFriendLinkRequest({
    schemaVersion: 1,
    friendAccountID: "friend-account",
    pairID: "not-a-pair",
  }));
});

test("invite secrets are canonical 256-bit base64url values hashed with SHA-256", () => {
  const first = generateFriendInviteSecret();
  const second = generateFriendInviteSecret();
  assert.match(first.inviteToken, /^[A-Za-z0-9_-]{43}$/);
  assert.match(first.tokenDigest, /^[0-9a-f]{64}$/);
  assert.equal(Buffer.from(first.inviteToken, "base64url").length, 32);
  assert.equal(friendInviteDigest(first.inviteToken), first.tokenDigest);
  const tokenBytes = Buffer.from(first.inviteToken, "base64url");
  const exactDigest = createHash("sha256")
    .update(Buffer.from("noum.friend-invite.v1\0", "utf8"))
    .update(tokenBytes)
    .digest("hex");
  assert.equal(first.tokenDigest, exactDigest);
  assert.notEqual(
    first.tokenDigest,
    createHash("sha256").update(first.inviteToken, "utf8").digest("hex")
  );
  assert.notEqual(
    first.tokenDigest,
    createHash("sha256").update(tokenBytes).digest("hex")
  );
  assert.notEqual(first.inviteToken, second.inviteToken);
  assert.notEqual(first.tokenDigest, second.tokenDigest);
});

test("stored invites enforce every exact terminal state shape", () => {
  assert.deepEqual(validateStoredFriendInvite(
    activeInvite(), digest, timestampMilliseconds
  ), {
    schemaVersion: 1,
    status: "active",
    tokenDigest: digest,
    inviterAccountID: "inviter-account",
    inviterDisplayName: "Jordan",
    createdAtMs: nowMs,
    expiresAtMs: nowMs + FRIEND_INVITE_LIFETIME_MS,
    acceptedAccountID: null,
    acceptorDisplayName: null,
    acceptedAtMs: null,
    pairID: null,
    revokedAtMs: null,
  });
  const accepted = activeInvite({
    status: "accepted",
    acceptedAccountID: "acceptor-account",
    acceptorDisplayName: "Alex",
    acceptedAt: timestamp(nowMs + 1_000),
    pairID: "C713738E-D9ED-4337-986E-09205089D42E",
  });
  assert.equal(validateStoredFriendInvite(
    accepted, digest, timestampMilliseconds
  ).acceptedAccountID, "acceptor-account");
  assert.equal(validateStoredFriendInvite(
    {...accepted, status: "revoked", revokedAt: timestamp(nowMs + 2_000)},
    digest,
    timestampMilliseconds
  ).status, "revoked");
  assert.equal(validateStoredFriendInvite(
    activeInvite({
      status: "superseded",
      acceptedAccountID: "acceptor-account",
      acceptorDisplayName: "Alex",
      revokedAt: timestamp(nowMs + 2_000),
    }),
    digest,
    timestampMilliseconds
  ).status, "superseded");
  for (const corrupt of [
    {...activeInvite(), inviteToken: "raw-secret"},
    activeInvite({acceptedAccountID: "acceptor-account"}),
    accepted,
    activeInvite({expiresAt: timestamp(nowMs + 1_000)}),
  ]) {
    const candidate = corrupt === accepted ?
      {...accepted, acceptedAccountID: "inviter-account"} : corrupt;
    assert.throws(() => validateStoredFriendInvite(
      candidate, digest, timestampMilliseconds
    ));
  }
});

test("per-account invite references are exact and never carry raw tokens", () => {
  const activeReference = {
    schemaVersion: 1,
    tokenDigest: digest,
    accountID: "inviter-account",
    role: "inviter",
    status: "active",
    counterpartAccountID: null,
    expiresAt: timestamp(nowMs + FRIEND_INVITE_LIFETIME_MS),
    updatedAt: timestamp(nowMs),
  };
  assert.equal(validateStoredFriendInviteReference(
    activeReference,
    "inviter-account",
    digest,
    timestampMilliseconds
  ).status, "active");
  assert.throws(() => validateStoredFriendInviteReference(
    {...activeReference, inviteToken: "raw-secret"},
    "inviter-account",
    digest,
    timestampMilliseconds
  ));
  assert.throws(() => validateStoredFriendInviteReference(
    {...activeReference, role: "acceptor"},
    "inviter-account",
    digest,
    timestampMilliseconds
  ));
  assert.doesNotThrow(() => validateBoundFriendInviteReference(
    activeReference,
    "inviter-account",
    digest,
    "inviter",
    "active",
    null,
    timestampMilliseconds
  ));
  const supersededReference = {
    ...activeReference,
    status: "superseded",
    counterpartAccountID: "acceptor-account",
    updatedAt: timestamp(nowMs + 1_000),
  };
  assert.equal(validateStoredFriendInviteReference(
    supersededReference,
    "inviter-account",
    digest,
    timestampMilliseconds
  ).status, "superseded");
  assert.throws(() => validateBoundFriendInviteReference(
    activeReference,
    "inviter-account",
    digest,
    "inviter",
    "accepted",
    "acceptor-account",
    timestampMilliseconds
  ));
});
