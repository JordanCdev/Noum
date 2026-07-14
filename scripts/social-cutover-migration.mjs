import {createHash} from "node:crypto";

export const CUTOVER_SCHEMA_VERSION = 3;
export const CUTOVER_JOURNAL_PATH = "_socialReferenceCutover/current";
export const CUTOVER_PHASES = Object.freeze([
  "journaled",
  "quarantined",
  "manifests-written",
  "verified",
  "complete",
]);

export const SOCIAL_LIMITS = Object.freeze({
  profiles: 1_000,
  memberships: 1_000,
  privateProfiles: 1_000,
  challenges: 1_000,
  challengeDescendants: 3_000,
  friendLinks: 1_000,
  manifests: 1_000,
  totalMutationDocuments: 400,
});

const ACCOUNT_LIMITS = Object.freeze({
  leagueMembershipPaths: 16,
  challengeIDs: 100,
  friendAccountIDs: 200,
});
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const LEAGUE_PATH_PATTERN =
  /^leagues\/(bronze|silver|gold|platinum|diamond)_\d{4}-W\d{2}\/members\/[^/]+$/;
const ACCOUNT_ID_PATTERN = /^[^/\u0000-\u001f\u007f]{1,128}$/;
const RUN_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;
const SHA256_PATTERN = /^[a-f0-9]{64}$/;

const PRIVATE_PROFILE_FIELDS = new Set([
  "speakingContext",
  "primaryGoal",
  "confidenceLevel",
  "biggestChallenge",
  "customChallengeText",
  "desiredOutcome",
  "speakingStyleGoal",
  "chosenStyleGoal",
  "styleReference",
  "coachingBrief",
  "motivationWhyNow",
  "successVision",
  "paraphrasedGoal",
  "bigMomentID",
  "secondaryStyleGoal",
]);
const REQUIRED_PRIVATE_PROFILE_FIELDS = [
  "speakingContext",
  "primaryGoal",
  "confidenceLevel",
  "biggestChallenge",
  "desiredOutcome",
  "speakingStyleGoal",
  "chosenStyleGoal",
  "styleReference",
  "coachingBrief",
  "motivationWhyNow",
  "successVision",
];
const PRIVATE_PROFILE_ENUMS = Object.freeze({
  speakingContext: ["work", "interviews", "presentations", "social"],
  primaryGoal: [
    "reduceFillers", "moreConcise", "thinkFaster", "calmerDelivery",
  ],
  confidenceLevel: [
    "beginner", "rebuilding", "inconsistent", "confident",
  ],
  biggestChallenge: ["fillerWords", "rambling", "freezing", "rushing"],
  desiredOutcome: ["concise", "composed", "persuasive", "spontaneous"],
  speakingStyleGoal: [
    "authoritative", "warm", "concise", "persuasive",
    "executive", "storytelling",
  ],
});
const OPTIONAL_STRING_BOUNDS = Object.freeze({
  customChallengeText: 90,
  paraphrasedGoal: 220,
});
const REQUIRED_STRING_BOUNDS = Object.freeze({
  styleReference: 500,
  coachingBrief: 2_000,
  motivationWhyNow: 1_000,
  successVision: 1_000,
});

function isPlainObject(value) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function canonicalValue(value) {
  if (Array.isArray(value)) return value.map(canonicalValue);
  if (!isPlainObject(value)) return value;
  return Object.fromEntries(
    Object.keys(value).sort().map((key) => [key, canonicalValue(value[key])])
  );
}

export function canonicalJSONStringify(value) {
  return JSON.stringify(canonicalValue(value));
}

export function canonicalSHA256(value) {
  return createHash("sha256").update(canonicalJSONStringify(value)).digest("hex");
}

function assertExactKeys(value, allowed, required, label) {
  if (!isPlainObject(value)) throw new Error(`${label} must be an object.`);
  const unknown = Object.keys(value).filter((key) => !allowed.has(key));
  if (unknown.length > 0) {
    throw new Error(`${label} has unsupported field ${unknown.sort()[0]}.`);
  }
  const missing = required.find((key) => !(key in value));
  if (missing) throw new Error(`${label} is missing ${missing}.`);
}

function assertEnum(value, accepted, label) {
  if (typeof value !== "string" || !accepted.includes(value)) {
    throw new Error(`${label} has an invalid enum value.`);
  }
}

function assertBoundedString(value, maximum, label) {
  if (typeof value !== "string" || [...value].length > maximum) {
    throw new Error(`${label} must be a string of at most ${maximum} characters.`);
  }
}

export function validatePrivateProfile(data, path = "private profile") {
  assertExactKeys(
    data,
    PRIVATE_PROFILE_FIELDS,
    REQUIRED_PRIVATE_PROFILE_FIELDS,
    path
  );
  for (const [field, accepted] of Object.entries(PRIVATE_PROFILE_ENUMS)) {
    assertEnum(data[field], accepted, `${path}.${field}`);
  }
  for (const field of ["chosenStyleGoal", "secondaryStyleGoal"]) {
    if (data[field] !== null && data[field] !== undefined) {
      assertEnum(
        data[field],
        PRIVATE_PROFILE_ENUMS.speakingStyleGoal,
        `${path}.${field}`
      );
    }
  }
  for (const [field, maximum] of Object.entries(REQUIRED_STRING_BOUNDS)) {
    assertBoundedString(data[field], maximum, `${path}.${field}`);
  }
  for (const [field, maximum] of Object.entries(OPTIONAL_STRING_BOUNDS)) {
    if (data[field] !== null && data[field] !== undefined) {
      assertBoundedString(data[field], maximum, `${path}.${field}`);
    }
  }
  if (data.bigMomentID !== null && data.bigMomentID !== undefined &&
      (typeof data.bigMomentID !== "string" ||
       !UUID_PATTERN.test(data.bigMomentID))) {
    throw new Error(`${path}.bigMomentID must be a UUID or null.`);
  }
  return data;
}

function assertAccountID(value, label = "account ID") {
  if (typeof value !== "string" || value !== value.trim() ||
      !ACCOUNT_ID_PATTERN.test(value)) {
    throw new Error(`Invalid ${label}.`);
  }
  return value;
}

function document(path, data) {
  if (typeof path !== "string" || path.startsWith("/") || path.endsWith("/")) {
    throw new Error("Inventory contains an invalid document path.");
  }
  return {path, data};
}

function sortedDocuments(documents) {
  const seen = new Set();
  return documents.map(({path, data}) => {
    if (seen.has(path)) throw new Error(`Inventory duplicates ${path}.`);
    seen.add(path);
    return document(path, data);
  }).sort((left, right) => left.path.localeCompare(right.path));
}

function assertBoundedDocuments(documents, label, maximum) {
  if (!Array.isArray(documents)) throw new Error(`${label} must be an array.`);
  if (documents.length > maximum) {
    throw new Error(`${label} exceeds the reviewed bound of ${maximum}.`);
  }
  return sortedDocuments(documents);
}

function validateInventory(raw) {
  if (!isPlainObject(raw)) throw new Error("Inventory must be an object.");
  const inventory = {
    profiles: assertBoundedDocuments(
      raw.profiles ?? [], "profiles_public", SOCIAL_LIMITS.profiles
    ),
    leagueMemberships: assertBoundedDocuments(
      raw.leagueMemberships ?? [],
      "league memberships",
      SOCIAL_LIMITS.memberships
    ),
    privateProfiles: assertBoundedDocuments(
      raw.privateProfiles ?? [],
      "private profiles",
      SOCIAL_LIMITS.privateProfiles
    ),
    challenges: assertBoundedDocuments(
      raw.challenges ?? [], "challenges", SOCIAL_LIMITS.challenges
    ),
    challengeDescendants: assertBoundedDocuments(
      raw.challengeDescendants ?? [],
      "challenge descendants",
      SOCIAL_LIMITS.challengeDescendants
    ),
    friendLinks: assertBoundedDocuments(
      raw.friendLinks ?? [], "friend links", SOCIAL_LIMITS.friendLinks
    ),
    existingManifests: assertBoundedDocuments(
      raw.existingManifests ?? [],
      "existing social manifests",
      SOCIAL_LIMITS.manifests
    ),
    existingCutover: raw.existingCutover ?? null,
  };

  for (const profile of inventory.profiles) {
    const match = /^profiles_public\/([^/]+)$/.exec(profile.path);
    if (!match) throw new Error(`Invalid public profile path ${profile.path}.`);
    assertAccountID(match[1], "public-profile account ID");
  }
  for (const membership of inventory.leagueMemberships) {
    const match = /^leagues\/[^/]+\/members\/([^/]+)$/.exec(membership.path);
    if (!match || !LEAGUE_PATH_PATTERN.test(membership.path)) {
      throw new Error(`Invalid league membership path ${membership.path}.`);
    }
    const accountID = assertAccountID(match[1], "league account ID");
    if (!isPlainObject(membership.data) ||
        membership.data.accountID !== accountID) {
      throw new Error(`Membership account mismatch at ${membership.path}.`);
    }
  }
  for (const privateProfile of inventory.privateProfiles) {
    const match = /^users\/([^/]+)\/profile\/main$/.exec(privateProfile.path);
    if (!match) throw new Error(`Invalid private profile path ${privateProfile.path}.`);
    assertAccountID(match[1], "private-profile account ID");
    validatePrivateProfile(privateProfile.data, privateProfile.path);
  }
  for (const challenge of inventory.challenges) {
    const match = /^challenges\/([^/]+)$/.exec(challenge.path);
    if (!match || !UUID_PATTERN.test(match[1]) || !isPlainObject(challenge.data)) {
      throw new Error(`Invalid challenge at ${challenge.path}.`);
    }
    if (match[1] !== match[1].toUpperCase()) {
      throw new Error(
        `Challenge document ID is not canonical uppercase at ${challenge.path}.`
      );
    }
    const {creatorAccountID, opponentAccountID} = challenge.data;
    assertAccountID(creatorAccountID, "challenge creator account ID");
    assertAccountID(opponentAccountID, "challenge opponent account ID");
    if (creatorAccountID === opponentAccountID) {
      throw new Error(`Challenge participants match at ${challenge.path}.`);
    }
  }
  for (const descendant of inventory.challengeDescendants) {
    const segments = descendant.path.split("/");
    if (segments.length < 4 || segments.length % 2 !== 0 ||
        segments[0] !== "challenges" ||
        !UUID_PATTERN.test(segments[1]) ||
        segments[1] !== segments[1].toUpperCase() ||
        !isPlainObject(descendant.data)) {
      throw new Error(
        `Invalid challenge descendant at ${descendant.path}.`
      );
    }
  }
  for (const link of inventory.friendLinks) {
    const match = /^_socialFriendLinks\/([^/]+)\/friends\/([^/]+)$/.exec(
      link.path
    );
    if (!match) throw new Error(`Invalid friend link path ${link.path}.`);
    assertAccountID(match[1], "friend-link owner");
    assertAccountID(match[2], "friend-link peer");
    if (match[1] === match[2]) throw new Error(`Self friend link at ${link.path}.`);
  }
  for (const manifest of inventory.existingManifests) {
    const match = /^_socialReferences\/([^/]+)$/.exec(manifest.path);
    if (!match) throw new Error(`Invalid social manifest path ${manifest.path}.`);
    validateManifest(manifest.data, match[1], manifest.path);
  }
  if (inventory.existingCutover !== null) {
    if (inventory.existingCutover.path !== CUTOVER_JOURNAL_PATH) {
      throw new Error("Inventory contains an invalid cutover marker path.");
    }
  }
  return inventory;
}

function validateManifest(data, accountID, label) {
  if (!isPlainObject(data)) throw new Error(`${label} is not an object.`);
  for (const [field, maximum] of Object.entries(ACCOUNT_LIMITS)) {
    if (!Array.isArray(data[field]) || data[field].length > maximum) {
      throw new Error(`${label} has invalid ${field}.`);
    }
  }
  for (const path of data.leagueMembershipPaths) {
    if (typeof path !== "string" || !LEAGUE_PATH_PATTERN.test(path) ||
        !path.endsWith(`/members/${accountID}`)) {
      throw new Error(`${label} has an invalid league reference.`);
    }
  }
  for (const id of data.challengeIDs) {
    if (typeof id !== "string" || !UUID_PATTERN.test(id)) {
      throw new Error(`${label} has an invalid challenge reference.`);
    }
    if (id !== id.toUpperCase()) {
      throw new Error(`${label} has a noncanonical challenge reference.`);
    }
  }
  for (const id of data.friendAccountIDs) {
    if (typeof id !== "string" || id === accountID) {
      throw new Error(`${label} has an invalid friend reference.`);
    }
    assertAccountID(id, "manifest friend account ID");
  }
}

function sourceBinding(binding) {
  if (!isPlainObject(binding) ||
      typeof binding.repositoryCommit !== "string" ||
      !/^[a-f0-9]{40}$/.test(binding.repositoryCommit) ||
      typeof binding.implementationSHA256 !== "string" ||
      !SHA256_PATTERN.test(binding.implementationSHA256)) {
    throw new Error("Backup source binding is invalid.");
  }
  return {
    repositoryCommit: binding.repositoryCommit,
    implementationSHA256: binding.implementationSHA256,
  };
}

export function createBackupEnvelope({
  projectID,
  capturedAt,
  binding,
  inventory: rawInventory,
}) {
  if (typeof projectID !== "string" || projectID.length < 1) {
    throw new Error("Backup project ID is invalid.");
  }
  if (typeof capturedAt !== "string" ||
      !Number.isFinite(Date.parse(capturedAt))) {
    throw new Error("Backup capture time is invalid.");
  }
  const inventory = validateInventory(rawInventory);
  const payload = {
    schemaVersion: CUTOVER_SCHEMA_VERSION,
    projectID,
    capturedAt,
    sourceBinding: sourceBinding(binding),
    inventory,
  };
  return {
    payload,
    digest: {
      algorithm: "sha256",
      value: canonicalSHA256(payload),
    },
  };
}

export function verifyBackupEnvelope(envelope, {
  projectID,
  expectedDigest,
  binding,
} = {}) {
  if (!isPlainObject(envelope) || !isPlainObject(envelope.payload) ||
      !isPlainObject(envelope.digest) ||
      envelope.payload.schemaVersion !== CUTOVER_SCHEMA_VERSION ||
      envelope.digest.algorithm !== "sha256" ||
      !SHA256_PATTERN.test(envelope.digest.value ?? "")) {
    throw new Error("Backup envelope is invalid.");
  }
  const actualDigest = canonicalSHA256(envelope.payload);
  if (actualDigest !== envelope.digest.value ||
      (expectedDigest && actualDigest !== expectedDigest)) {
    throw new Error("Backup digest does not match the canonical payload.");
  }
  if (projectID && envelope.payload.projectID !== projectID) {
    throw new Error("Backup project does not match the requested project.");
  }
  if (binding && canonicalJSONStringify(envelope.payload.sourceBinding) !==
      canonicalJSONStringify(sourceBinding(binding))) {
    throw new Error("Backup source does not match this migration implementation.");
  }
  validateInventory(envelope.payload.inventory);
  return envelope;
}

function quarantinePath(runID, sourcePath) {
  return `_socialReferenceQuarantine/${runID}/documents/` +
    canonicalSHA256(sourcePath);
}

function manifestAccumulator() {
  return {
    leagueMembershipPaths: new Set(),
    challengeIDs: new Set(),
    friendAccountIDs: new Set(),
  };
}

function buildPlan(envelope, runID) {
  if (typeof runID !== "string" || !RUN_ID_PATTERN.test(runID)) {
    throw new Error("Run ID must contain 1–64 safe characters.");
  }
  const inventory = validateInventory(envelope.payload.inventory);
  const manifestByAccount = new Map();
  const forAccount = (rawID) => {
    const accountID = assertAccountID(rawID);
    if (!manifestByAccount.has(accountID)) {
      manifestByAccount.set(accountID, manifestAccumulator());
    }
    return manifestByAccount.get(accountID);
  };

  for (const profile of inventory.profiles) {
    forAccount(profile.path.slice("profiles_public/".length));
  }
  for (const membership of inventory.leagueMemberships) {
    forAccount(membership.path.split("/")[3]);
  }
  for (const privateProfile of inventory.privateProfiles) {
    forAccount(privateProfile.path.split("/")[1]);
  }
  for (const existing of inventory.existingManifests) {
    const accountID = existing.path.split("/")[1];
    forAccount(accountID);
  }
  for (const challenge of inventory.challenges) {
    forAccount(challenge.data.creatorAccountID);
    forAccount(challenge.data.opponentAccountID);
  }
  for (const link of inventory.friendLinks) {
    const [, owner, , friend] = link.path.split("/");
    forAccount(owner);
    forAccount(friend);
  }

  const manifests = [...manifestByAccount.entries()].sort(([a], [b]) =>
    a.localeCompare(b)
  ).map(([accountID, values]) => {
    const data = {
      leagueMembershipPaths: [],
      challengeIDs: [...values.challengeIDs].sort(),
      friendAccountIDs: [...values.friendAccountIDs].sort(),
    };
    validateManifest(data, accountID, `_socialReferences/${accountID}`);
    return {path: `_socialReferences/${accountID}`, data};
  });
  if (manifests.length > SOCIAL_LIMITS.manifests) {
    throw new Error("Planned manifests exceed the reviewed bound.");
  }

  const legacy = [
    ...inventory.profiles,
    ...inventory.leagueMemberships,
    ...inventory.challenges,
    ...inventory.challengeDescendants,
    ...inventory.friendLinks,
  ]
    .sort((left, right) => left.path.localeCompare(right.path));
  if (legacy.length + manifests.length > SOCIAL_LIMITS.totalMutationDocuments) {
    throw new Error(
      "Mutation inventory exceeds the conservative 400-document run bound."
    );
  }
  return {
    runID,
    digest: envelope.digest.value,
    projectID: envelope.payload.projectID,
    sourceBinding: envelope.payload.sourceBinding,
    inventory,
    legacy,
    manifests,
    quarantine: legacy.map((source) => ({
      path: quarantinePath(runID, source.path),
      data: {
        schemaVersion: CUTOVER_SCHEMA_VERSION,
        runID,
        backupDigest: envelope.digest.value,
        sourcePath: source.path,
        sourceData: source.data,
        sourceSHA256: canonicalSHA256(source.data),
      },
    })),
  };
}

function matching(left, right) {
  return canonicalJSONStringify(left) === canonicalJSONStringify(right);
}

function expectedVerifiedInventory(plan) {
  return {
    profiles: [],
    leagueMemberships: [],
    privateProfiles: plan.inventory.privateProfiles,
    challenges: [],
    challengeDescendants: [],
    friendLinks: [],
    manifests: plan.manifests,
    quarantine: plan.quarantine,
  };
}

function verifiedInventoryDigest(plan) {
  return canonicalSHA256(expectedVerifiedInventory(plan));
}

function journalFor(plan, phase) {
  return {
    schemaVersion: CUTOVER_SCHEMA_VERSION,
    status: "in-progress",
    runID: plan.runID,
    projectID: plan.projectID,
    sourceGitCommit: plan.sourceBinding.repositoryCommit,
    sourceImplementationSHA256: plan.sourceBinding.implementationSHA256,
    backupDigest: plan.digest,
    phase,
    inventoryDigest: verifiedInventoryDigest(plan),
  };
}

function assertJournalBinding(journal, plan, {allowComplete = false} = {}) {
  if (!isPlainObject(journal) || journal.runID !== plan.runID ||
      journal.backupDigest !== plan.digest ||
      journal.projectID !== plan.projectID ||
      journal.sourceGitCommit !== plan.sourceBinding.repositoryCommit ||
      journal.sourceImplementationSHA256 !==
        plan.sourceBinding.implementationSHA256 ||
      journal.schemaVersion !== CUTOVER_SCHEMA_VERSION) {
    throw new Error("A different run or backup digest owns the cutover journal.");
  }
  if (journal.status === "complete") {
    if (allowComplete) {
      const expectedKeys = [
        "schemaVersion", "status", "runID", "projectID",
        "sourceGitCommit", "sourceImplementationSHA256", "backupDigest",
        "inventoryDigest", "verifiedInventoryDigest", "completedAt",
      ].sort();
      const actualKeys = Object.keys(journal).sort();
      const expectedDigest = verifiedInventoryDigest(plan);
      const timestampType = journal.completedAt?.$noumType;
      if (!matching(actualKeys, expectedKeys) ||
          journal.inventoryDigest !== expectedDigest ||
          journal.verifiedInventoryDigest !== expectedDigest ||
          !["timestamp", "server-timestamp"].includes(timestampType)) {
        throw new Error("The complete cutover marker is invalid.");
      }
      return;
    }
    throw new Error("The social reference cutover is already complete.");
  }
  if (journal.status !== "in-progress") {
    throw new Error("The cutover journal has an invalid status.");
  }
}

async function assertInventoryMatchesBackup(store, plan, {resume = false} = {}) {
  const current = validateInventory(await store.readInventory());
  for (const category of ["privateProfiles"]) {
    if (!matching(current[category], plan.inventory[category])) {
      throw new Error(`${category} changed after the source-bound backup.`);
    }
  }
  if (!resume) {
    for (const category of [
      "profiles", "leagueMemberships", "challenges",
      "challengeDescendants", "friendLinks", "existingManifests",
    ]) {
      if (!matching(current[category], plan.inventory[category])) {
        throw new Error(`${category} changed after the source-bound backup.`);
      }
    }
    if (current.existingCutover !== null) {
      throw new Error("A cutover journal or marker already exists.");
    }
  }
}

async function advanceJournal(store, plan, phase) {
  await store.transaction(async (transaction) => {
    const current = await transaction.get(CUTOVER_JOURNAL_PATH);
    assertJournalBinding(current, plan);
    transaction.set(CUTOVER_JOURNAL_PATH, journalFor(plan, phase));
  });
}

function maybeFault(faultAfterPhase, phase) {
  if (faultAfterPhase === phase) throw new Error(`Injected fault after ${phase}.`);
}

async function verifyApplied(store, plan, {allowComplete = false} = {}) {
  const current = validateInventory(await store.readInventory());
  if (current.profiles.length !== 0 ||
      current.leagueMemberships.length !== 0 ||
      current.challenges.length !== 0 ||
      current.challengeDescendants.length !== 0 ||
      current.friendLinks.length !== 0) {
    throw new Error("Legacy social source documents remain after quarantine.");
  }
  if (!matching(current.privateProfiles, plan.inventory.privateProfiles) ||
      !matching(current.existingManifests, plan.manifests)) {
    throw new Error("Post-migration inventory does not match the exact plan.");
  }
  for (let index = 0; index < plan.quarantine.length; index += 1) {
    const actual = await store.get(plan.quarantine[index].path);
    if (!matching(actual, plan.quarantine[index].data)) {
      throw new Error(`Quarantine verification failed for ${plan.legacy[index].path}.`);
    }
  }
  assertJournalBinding(current.existingCutover?.data, plan, {allowComplete});
}

export async function applyRecoverableCutover({
  store,
  envelope,
  runID,
  faultAfterPhase,
}) {
  verifyBackupEnvelope(envelope);
  const plan = buildPlan(envelope, runID);
  const initialJournal = await store.get(CUTOVER_JOURNAL_PATH);
  if (initialJournal?.status === "complete") {
    assertJournalBinding(initialJournal, plan, {allowComplete: true});
    await verifyApplied(store, plan, {allowComplete: true});
    return {status: "complete", resumed: true, plan};
  }
  const resume = initialJournal !== null && initialJournal !== undefined;
  if (resume) assertJournalBinding(initialJournal, plan);
  await assertInventoryMatchesBackup(store, plan, {resume});

  if (!resume) {
    await store.transaction(async (transaction) => {
      const current = await transaction.get(CUTOVER_JOURNAL_PATH);
      if (current !== null && current !== undefined) {
        throw new Error("A cutover journal appeared during preflight.");
      }
      transaction.set(CUTOVER_JOURNAL_PATH, journalFor(plan, "journaled"));
    });
  }
  maybeFault(faultAfterPhase, "journaled");

  for (let index = 0; index < plan.legacy.length; index += 1) {
    const source = plan.legacy[index];
    const quarantine = plan.quarantine[index];
    await store.transaction(async (transaction) => {
      const [journal, sourceData, quarantineData] = await Promise.all([
        transaction.get(CUTOVER_JOURNAL_PATH),
        transaction.get(source.path),
        transaction.get(quarantine.path),
      ]);
      assertJournalBinding(journal, plan);
      if (sourceData !== null && sourceData !== undefined) {
        if (!matching(sourceData, source.data)) {
          throw new Error(`Legacy source changed at ${source.path}.`);
        }
        if (quarantineData !== null && quarantineData !== undefined &&
            !matching(quarantineData, quarantine.data)) {
          throw new Error(`Conflicting quarantine at ${quarantine.path}.`);
        }
        transaction.set(quarantine.path, quarantine.data);
        transaction.delete(source.path);
      } else if (!matching(quarantineData, quarantine.data)) {
        throw new Error(`Missing source and quarantine for ${source.path}.`);
      }
    });
  }
  await advanceJournal(store, plan, "quarantined");
  maybeFault(faultAfterPhase, "quarantined");

  for (const manifest of plan.manifests) {
    await store.transaction(async (transaction) => {
      const journal = await transaction.get(CUTOVER_JOURNAL_PATH);
      assertJournalBinding(journal, plan);
      transaction.set(manifest.path, manifest.data);
    });
  }
  await advanceJournal(store, plan, "manifests-written");
  maybeFault(faultAfterPhase, "manifests-written");

  await verifyApplied(store, plan);
  await advanceJournal(store, plan, "verified");
  maybeFault(faultAfterPhase, "verified");

  await store.transaction(async (transaction) => {
    const journal = await transaction.get(CUTOVER_JOURNAL_PATH);
    assertJournalBinding(journal, plan);
    transaction.set(CUTOVER_JOURNAL_PATH, {
      schemaVersion: CUTOVER_SCHEMA_VERSION,
      status: "complete",
      runID: plan.runID,
      projectID: plan.projectID,
      sourceGitCommit: plan.sourceBinding.repositoryCommit,
      sourceImplementationSHA256: plan.sourceBinding.implementationSHA256,
      backupDigest: plan.digest,
      inventoryDigest: verifiedInventoryDigest(plan),
      verifiedInventoryDigest: verifiedInventoryDigest(plan),
      completedAt: store.serverTimestampValue(),
    });
  });
  maybeFault(faultAfterPhase, "complete");
  return {status: "complete", resumed: resume, plan};
}

async function verifyRolledBack(store, plan, {journalExpected}) {
  const current = validateInventory(await store.readInventory());
  for (const category of [
    "profiles", "leagueMemberships", "privateProfiles", "challenges",
    "challengeDescendants", "friendLinks", "existingManifests",
  ]) {
    if (!matching(current[category], plan.inventory[category])) {
      throw new Error(`Rollback verification failed for ${category}.`);
    }
  }
  for (const quarantine of plan.quarantine) {
    if (await store.get(quarantine.path) !== null) {
      throw new Error("Rollback left a quarantine document behind.");
    }
  }
  if (journalExpected) assertJournalBinding(current.existingCutover?.data, plan);
  if (!journalExpected && current.existingCutover !== null) {
    throw new Error("Rollback left the run journal behind.");
  }
}

export async function rollbackRecoverableCutover({
  store,
  envelope,
  runID,
  faultAfterPhase,
}) {
  verifyBackupEnvelope(envelope);
  const plan = buildPlan(envelope, runID);
  const journal = await store.get(CUTOVER_JOURNAL_PATH);
  if (journal === null || journal === undefined) {
    await verifyRolledBack(store, plan, {journalExpected: false});
    return {status: "rolled-back", resumed: true, plan};
  }
  assertJournalBinding(journal, plan);

  for (let index = plan.legacy.length - 1; index >= 0; index -= 1) {
    const source = plan.legacy[index];
    const quarantine = plan.quarantine[index];
    await store.transaction(async (transaction) => {
      const [currentJournal, sourceData, quarantineData] = await Promise.all([
        transaction.get(CUTOVER_JOURNAL_PATH),
        transaction.get(source.path),
        transaction.get(quarantine.path),
      ]);
      assertJournalBinding(currentJournal, plan);
      if (sourceData !== null && sourceData !== undefined &&
          !matching(sourceData, source.data)) {
        throw new Error(`Rollback source conflict at ${source.path}.`);
      }
      if (quarantineData !== null && quarantineData !== undefined &&
          !matching(quarantineData, quarantine.data)) {
        throw new Error(`Rollback quarantine conflict at ${quarantine.path}.`);
      }
      if ((sourceData === null || sourceData === undefined) &&
          (quarantineData === null || quarantineData === undefined)) {
        throw new Error(`Rollback cannot recover ${source.path}.`);
      }
      transaction.set(source.path, source.data);
      if (quarantineData !== null && quarantineData !== undefined) {
        transaction.delete(quarantine.path);
      }
    });
  }
  maybeFault(faultAfterPhase, "sources-restored");

  const originalByPath = new Map(
    plan.inventory.existingManifests.map((entry) => [entry.path, entry.data])
  );
  const manifestPaths = new Set([
    ...plan.manifests.map((entry) => entry.path),
    ...originalByPath.keys(),
  ]);
  for (const path of [...manifestPaths].sort()) {
    await store.transaction(async (transaction) => {
      const currentJournal = await transaction.get(CUTOVER_JOURNAL_PATH);
      assertJournalBinding(currentJournal, plan);
      if (originalByPath.has(path)) transaction.set(path, originalByPath.get(path));
      else transaction.delete(path);
    });
  }
  maybeFault(faultAfterPhase, "manifests-restored");

  await verifyRolledBack(store, plan, {journalExpected: true});
  maybeFault(faultAfterPhase, "rollback-verified");
  await store.transaction(async (transaction) => {
    const currentJournal = await transaction.get(CUTOVER_JOURNAL_PATH);
    assertJournalBinding(currentJournal, plan);
    transaction.delete(CUTOVER_JOURNAL_PATH);
  });
  await verifyRolledBack(store, plan, {journalExpected: false});
  return {status: "rolled-back", resumed: false, plan};
}

export function encodeFirestoreValue(value) {
  if (value === null || typeof value === "string" ||
      typeof value === "boolean") return value;
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new Error("Firestore number is not finite.");
    return value;
  }
  if (Array.isArray(value)) return value.map(encodeFirestoreValue);
  if (value instanceof Date) return {$noumType: "date", iso: value.toISOString()};
  if (Buffer.isBuffer(value) || value instanceof Uint8Array) {
    return {$noumType: "bytes", base64: Buffer.from(value).toString("base64")};
  }
  if (typeof value?.seconds === "number" &&
      typeof value?.nanoseconds === "number" &&
      typeof value?.toDate === "function") {
    return {
      $noumType: "timestamp",
      seconds: value.seconds,
      nanoseconds: value.nanoseconds,
    };
  }
  if (typeof value?.latitude === "number" &&
      typeof value?.longitude === "number") {
    return {
      $noumType: "geopoint",
      latitude: value.latitude,
      longitude: value.longitude,
    };
  }
  if (typeof value?.path === "string" &&
      value.constructor?.name?.includes("DocumentReference")) {
    return {$noumType: "reference", path: value.path};
  }
  if (!isPlainObject(value)) throw new Error("Unsupported Firestore value type.");
  if ("$noumType" in value) {
    throw new Error("Firestore data uses the reserved $noumType backup field.");
  }
  return Object.fromEntries(
    Object.entries(value).map(([key, nested]) => [key, encodeFirestoreValue(nested)])
  );
}

export function decodeFirestoreValue(value, adapters = {}) {
  if (value === null || typeof value !== "object") return value;
  if (Array.isArray(value)) {
    return value.map((nested) => decodeFirestoreValue(nested, adapters));
  }
  if (value.$noumType === "timestamp") {
    if (!adapters.timestamp) throw new Error("Timestamp adapter is unavailable.");
    return adapters.timestamp(value.seconds, value.nanoseconds);
  }
  if (value.$noumType === "date") return new Date(value.iso);
  if (value.$noumType === "bytes") return Buffer.from(value.base64, "base64");
  if (value.$noumType === "geopoint") {
    if (!adapters.geopoint) throw new Error("GeoPoint adapter is unavailable.");
    return adapters.geopoint(value.latitude, value.longitude);
  }
  if (value.$noumType === "reference") {
    if (!adapters.reference) throw new Error("Reference adapter is unavailable.");
    return adapters.reference(value.path);
  }
  if (value.$noumType === "server-timestamp") {
    if (!adapters.serverTimestamp) {
      throw new Error("Server timestamp adapter is unavailable.");
    }
    return adapters.serverTimestamp();
  }
  return Object.fromEntries(
    Object.entries(value).map(([key, nested]) => [
      key,
      decodeFirestoreValue(nested, adapters),
    ])
  );
}

export class MemoryMigrationStore {
  constructor(documents = []) {
    this.documents = new Map(
      documents.map(({path, data}) => [path, structuredClone(data)])
    );
    this.remoteWrites = 0;
  }

  async get(path) {
    return this.documents.has(path) ?
      structuredClone(this.documents.get(path)) : null;
  }

  serverTimestampValue() {
    return {$noumType: "server-timestamp"};
  }

  async transaction(operation) {
    const draft = new Map([...this.documents].map(([path, data]) => [
      path, structuredClone(data),
    ]));
    let writes = 0;
    const transaction = {
      get: async (path) => draft.has(path) ? structuredClone(draft.get(path)) : null,
      set: (path, data) => {
        draft.set(path, structuredClone(data));
        writes += 1;
      },
      delete: (path) => {
        draft.delete(path);
        writes += 1;
      },
    };
    await operation(transaction);
    this.documents = draft;
    this.remoteWrites += writes;
  }

  async readInventory() {
    const entries = [...this.documents.entries()].map(([path, data]) => ({
      path,
      data: structuredClone(data),
    }));
    const match = (pattern) => entries.filter(({path}) => pattern.test(path));
    return {
      profiles: match(/^profiles_public\/[^/]+$/),
      leagueMemberships: match(/^leagues\/[^/]+\/members\/[^/]+$/),
      privateProfiles: match(/^users\/[^/]+\/profile\/main$/),
      challenges: match(/^challenges\/[^/]+$/),
      challengeDescendants: entries.filter(({path}) => {
        const segments = path.split("/");
        return segments.length >= 4 && segments.length % 2 === 0 &&
          segments[0] === "challenges";
      }),
      friendLinks: match(/^_socialFriendLinks\/[^/]+\/friends\/[^/]+$/),
      existingManifests: match(/^_socialReferences\/[^/]+$/),
      existingCutover: this.documents.has(CUTOVER_JOURNAL_PATH) ? {
        path: CUTOVER_JOURNAL_PATH,
        data: structuredClone(this.documents.get(CUTOVER_JOURNAL_PATH)),
      } : null,
    };
  }
}
