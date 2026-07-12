#!/usr/bin/env node

import {mkdir, writeFile} from "node:fs/promises";
import {createRequire} from "node:module";
import {resolve} from "node:path";

const requireFromFunctions = createRequire(
  new URL("../functions/package.json", import.meta.url)
);
const {applicationDefault, initializeApp} = requireFromFunctions(
  "firebase-admin/app"
);
const {FieldValue, getFirestore} = requireFromFunctions(
  "firebase-admin/firestore"
);

const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const valueFor = (name) => args
  .find((argument) => argument.startsWith(`${name}=`))
  ?.slice(name.length + 1);

if (flag("--help")) {
  process.stdout.write(`
Usage:
  node scripts/migrate-social-reference-cutover.mjs --project=PROJECT_ID
  node scripts/migrate-social-reference-cutover.mjs --project=PROJECT_ID \\
    --apply --confirm-project=PROJECT_ID
  node scripts/migrate-social-reference-cutover.mjs --project=PROJECT_ID \\
    --apply --confirm-project=PROJECT_ID --purge-legacy-leagues \\
    --approve-purge=DELETE_LEGACY_LEAGUES

Default mode is remote-read-only. Every run writes an ignored local JSON
backup. --apply backfills exact manifests and writes the global cutover marker
only after all writes succeed. Purge requires both explicit destructive flags.
`);
  process.exit(0);
}

const projectID = valueFor("--project") ?? process.env.GCLOUD_PROJECT;
const apply = flag("--apply");
const purgeLegacyLeagues = flag("--purge-legacy-leagues");
const confirmedProject = valueFor("--confirm-project");
const purgeApproval = valueFor("--approve-purge");

if (!projectID) throw new Error("Pass --project=PROJECT_ID.");
if (apply && confirmedProject !== projectID) {
  throw new Error("--apply requires --confirm-project to match --project.");
}
if (purgeLegacyLeagues && !apply) {
  throw new Error("Legacy purge requires --apply.");
}
if (purgeLegacyLeagues && purgeApproval !== "DELETE_LEGACY_LEAGUES") {
  throw new Error(
    "Legacy purge requires --approve-purge=DELETE_LEGACY_LEAGUES."
  );
}

const GLOBAL_LIMITS = {
  profiles: 1_000,
  memberships: 1_000,
  challenges: 1_000,
  friendLinks: 1_000,
  manifests: 1_000,
};
const ACCOUNT_LIMITS = {
  leagueMembershipPaths: 16,
  challengeIDs: 100,
  friendAccountIDs: 200,
};
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const LEAGUE_PATH_PATTERN =
  /^leagues\/(bronze|silver|gold|platinum|diamond)_\d{4}-W\d{2}\/members\/[^/]+$/;

initializeApp({credential: applicationDefault(), projectId: projectID});
const firestore = getFirestore();

async function boundedSnapshot(query, label, limit) {
  const snapshot = await query.limit(limit + 1).get();
  if (snapshot.size > limit) {
    throw new Error(`${label} exceeds the reviewed bound of ${limit}.`);
  }
  return snapshot;
}

const [profiles, memberships, challenges, friendLinks, existingManifests] =
  await Promise.all([
    boundedSnapshot(
      firestore.collection("profiles_public"),
      "profiles_public",
      GLOBAL_LIMITS.profiles
    ),
    boundedSnapshot(
      firestore.collectionGroup("members"),
      "league memberships",
      GLOBAL_LIMITS.memberships
    ),
    boundedSnapshot(
      firestore.collection("challenges"),
      "challenges",
      GLOBAL_LIMITS.challenges
    ),
    boundedSnapshot(
      firestore.collectionGroup("friends"),
      "friend links",
      GLOBAL_LIMITS.friendLinks
    ),
    boundedSnapshot(
      firestore.collection("_socialReferences"),
      "existing social manifests",
      GLOBAL_LIMITS.manifests
    ),
  ]);

const manifests = new Map();
function manifestFor(accountID) {
  if (typeof accountID !== "string" || accountID.length < 1 ||
      accountID.length > 128 || accountID.includes("/")) {
    throw new Error("Inventory contains an invalid account ID.");
  }
  let manifest = manifests.get(accountID);
  if (!manifest) {
    manifest = {
      leagueMembershipPaths: new Set(),
      challengeIDs: new Set(),
      friendAccountIDs: new Set(),
    };
    manifests.set(accountID, manifest);
  }
  return manifest;
}

for (const profile of profiles.docs) manifestFor(profile.id);

for (const document of existingManifests.docs) {
  const accountID = document.id;
  const data = document.data();
  const manifest = manifestFor(accountID);
  for (const field of Object.keys(ACCOUNT_LIMITS)) {
    if (!Array.isArray(data[field])) {
      throw new Error(`Existing manifest ${accountID} has invalid ${field}.`);
    }
  }
  if (!purgeLegacyLeagues) {
    for (const path of data.leagueMembershipPaths) {
      manifest.leagueMembershipPaths.add(path);
    }
  }
  for (const id of data.challengeIDs) {
    if (typeof id !== "string" || !UUID_PATTERN.test(id)) {
      throw new Error(`Existing manifest ${accountID} has an invalid challenge.`);
    }
    manifest.challengeIDs.add(id.toUpperCase());
  }
  for (const id of data.friendAccountIDs ?? []) manifest.friendAccountIDs.add(id);
}

const leagueDocuments = memberships.docs.filter((document) => {
  const parts = document.ref.path.split("/");
  return parts.length === 4 && parts[0] === "leagues" &&
    parts[2] === "members";
});
if (leagueDocuments.length !== memberships.size) {
  throw new Error("A non-league collectionGroup('members') document was found.");
}
for (const document of leagueDocuments) {
  const accountID = document.id;
  const dataAccountID = document.get("accountID");
  if (dataAccountID !== accountID) {
    throw new Error(`Membership account mismatch at ${document.ref.path}.`);
  }
  if (!LEAGUE_PATH_PATTERN.test(document.ref.path)) {
    throw new Error(`Membership path is invalid at ${document.ref.path}.`);
  }
  if (!purgeLegacyLeagues) {
    manifestFor(accountID).leagueMembershipPaths.add(document.ref.path);
  } else {
    manifestFor(accountID);
  }
}

for (const document of challenges.docs) {
  const data = document.data();
  const creator = data.creatorAccountID;
  const opponent = data.opponentAccountID;
  if (typeof creator !== "string" || typeof opponent !== "string" ||
      creator === opponent || !UUID_PATTERN.test(document.id)) {
    throw new Error(`Challenge participants are invalid at ${document.ref.path}.`);
  }
  manifestFor(creator).challengeIDs.add(document.id.toUpperCase());
  manifestFor(opponent).challengeIDs.add(document.id.toUpperCase());
}

for (const document of friendLinks.docs) {
  const parts = document.ref.path.split("/");
  if (parts.length !== 4 || parts[0] !== "_socialFriendLinks" ||
      parts[2] !== "friends") {
    throw new Error(`Friend-link path is invalid at ${document.ref.path}.`);
  }
  const owner = parts[1];
  const friend = parts[3];
  if (owner === friend) throw new Error("Self friend-link found.");
  manifestFor(owner).friendAccountIDs.add(friend);
  manifestFor(friend).friendAccountIDs.add(owner);
}

const referencedFriendAccountIDs = new Set();
for (const manifest of manifests.values()) {
  for (const friendAccountID of manifest.friendAccountIDs) {
    referencedFriendAccountIDs.add(friendAccountID);
  }
}
for (const friendAccountID of referencedFriendAccountIDs) {
  manifestFor(friendAccountID);
}

for (const [accountID, manifest] of manifests) {
  for (const [field, maximum] of Object.entries(ACCOUNT_LIMITS)) {
    if (manifest[field].size > maximum) {
      throw new Error(`${accountID} exceeds ${field} bound ${maximum}.`);
    }
  }
  for (const path of manifest.leagueMembershipPaths) {
    if (typeof path !== "string" || !LEAGUE_PATH_PATTERN.test(path) ||
        !path.endsWith(`/members/${accountID}`)) {
      throw new Error(`${accountID} has an invalid league reference.`);
    }
  }
  for (const challengeID of manifest.challengeIDs) {
    if (typeof challengeID !== "string" || !UUID_PATTERN.test(challengeID)) {
      throw new Error(`${accountID} has an invalid challenge reference.`);
    }
  }
  for (const friendAccountID of manifest.friendAccountIDs) {
    if (typeof friendAccountID !== "string" ||
        friendAccountID === accountID) {
      throw new Error(`${accountID} has an invalid friend reference.`);
    }
  }
}

const serializable = (snapshot) => snapshot.docs.map((document) => ({
  path: document.ref.path,
  data: document.data(),
}));
const backup = {
  schemaVersion: 1,
  projectID,
  capturedAt: new Date().toISOString(),
  profiles: serializable(profiles),
  leagueMemberships: serializable(memberships),
  challenges: serializable(challenges),
  friendLinks: serializable(friendLinks),
  existingManifests: serializable(existingManifests),
};
const backupDirectory = resolve(process.cwd(), "backups");
await mkdir(backupDirectory, {recursive: true});
const backupName = `social-cutover-${backup.capturedAt.replaceAll(":", "-")}.json`;
const backupPath = resolve(backupDirectory, backupName);
await writeFile(backupPath, `${JSON.stringify(backup, null, 2)}\n`, {
  mode: 0o600,
});

const summary = {
  mode: apply ? "apply" : "dry-run",
  projectID,
  backupPath,
  profileDocuments: profiles.size,
  leagueMembershipDocuments: leagueDocuments.length,
  challengeDocuments: challenges.size,
  friendLinkDocuments: friendLinks.size,
  manifestAccounts: manifests.size,
  purgeLegacyLeagues,
};
process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);

if (!apply) {
  process.stdout.write("Dry run complete. No remote writes were performed.\n");
  process.exit(0);
}

const writer = firestore.bulkWriter();
const writes = [];
for (const [accountID, manifest] of manifests) {
  writes.push(writer.set(firestore.collection("_socialReferences").doc(accountID), {
    leagueMembershipPaths: [...manifest.leagueMembershipPaths].sort(),
    challengeIDs: [...manifest.challengeIDs].sort(),
    friendAccountIDs: [...manifest.friendAccountIDs].sort(),
    updatedAt: FieldValue.serverTimestamp(),
  }));
}
if (purgeLegacyLeagues) {
  for (const document of leagueDocuments) writes.push(writer.delete(document.ref));
}
try {
  await Promise.all(writes);
} finally {
  await writer.close();
}

await firestore.collection("_socialReferenceCutover").doc("current").set({
  schemaVersion: 1,
  status: "complete",
  completedAt: FieldValue.serverTimestamp(),
  inventory: {
    profileDocuments: profiles.size,
    leagueMembershipDocuments: leagueDocuments.length,
    challengeDocuments: challenges.size,
    friendLinkDocuments: friendLinks.size,
    manifestAccounts: manifests.size,
    purgedLegacyLeagues: purgeLegacyLeagues,
  },
});
process.stdout.write("Backfill committed; global cutover is now complete.\n");
