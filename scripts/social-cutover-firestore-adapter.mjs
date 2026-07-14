import {createRequire} from "node:module";

import {
  decodeFirestoreValue,
  encodeFirestoreValue,
  SOCIAL_LIMITS,
} from "./social-cutover-migration.mjs";
import {
  createGcloudUserAuthClient,
  SocialCutoverCredentialMode,
  validateSocialCutoverRuntime,
} from "./social-cutover-credentials.mjs";

const requireFromFunctions = createRequire(
  new URL("../functions/package.json", import.meta.url)
);

async function boundedSnapshot(query, label, limit) {
  const snapshot = await query.limit(limit + 1).get();
  if (snapshot.size > limit) {
    throw new Error(`${label} exceeds the reviewed bound of ${limit}.`);
  }
  return snapshot;
}

const documents = (snapshot) => snapshot.docs.map((snapshotDocument) => ({
  path: snapshotDocument.ref.path,
  data: encodeFirestoreValue(snapshotDocument.data()),
}));

export async function readRemoteSocialInventory(firestore) {
  const [
    profiles,
    memberships,
    privateProfiles,
    challenges,
    friendLinks,
    manifests,
    cutover,
  ] = await Promise.all([
    boundedSnapshot(
      firestore.collection("profiles_public"),
      "profiles_public",
      SOCIAL_LIMITS.profiles
    ),
    boundedSnapshot(
      firestore.collectionGroup("members"),
      "league memberships",
      SOCIAL_LIMITS.memberships
    ),
    boundedSnapshot(
      firestore.collectionGroup("profile"),
      "private profiles",
      SOCIAL_LIMITS.privateProfiles
    ),
    boundedSnapshot(
      firestore.collection("challenges"),
      "challenges",
      SOCIAL_LIMITS.challenges
    ),
    boundedSnapshot(
      firestore.collectionGroup("friends"),
      "friend links",
      SOCIAL_LIMITS.friendLinks
    ),
    boundedSnapshot(
      firestore.collection("_socialReferences"),
      "existing social manifests",
      SOCIAL_LIMITS.manifests
    ),
    firestore.collection("_socialReferenceCutover").doc("current").get(),
  ]);
  return {
    profiles: documents(profiles),
    leagueMemberships: documents(memberships),
    privateProfiles: documents(privateProfiles),
    challenges: documents(challenges),
    friendLinks: documents(friendLinks),
    existingManifests: documents(manifests),
    existingCutover: cutover.exists ? {
      path: cutover.ref.path,
      data: encodeFirestoreValue(cutover.data()),
    } : null,
  };
}

export class FirestoreMigrationStore {
  constructor({firestore, FieldValue, GeoPoint, Timestamp}) {
    this.firestore = firestore;
    this.decodeAdapters = {
      timestamp: (seconds, nanoseconds) =>
        new Timestamp(seconds, nanoseconds),
      geopoint: (latitude, longitude) => new GeoPoint(latitude, longitude),
      reference: (path) => firestore.doc(path),
      serverTimestamp: () => FieldValue.serverTimestamp(),
    };
  }

  serverTimestampValue() {
    return {$noumType: "server-timestamp"};
  }

  async get(path) {
    const snapshot = await this.firestore.doc(path).get();
    return snapshot.exists ? encodeFirestoreValue(snapshot.data()) : null;
  }

  async transaction(operation) {
    await this.firestore.runTransaction(async (nativeTransaction) => {
      const transaction = {
        get: async (path) => {
          const snapshot = await nativeTransaction.get(this.firestore.doc(path));
          return snapshot.exists ? encodeFirestoreValue(snapshot.data()) : null;
        },
        set: (path, data) => nativeTransaction.set(
          this.firestore.doc(path),
          decodeFirestoreValue(data, this.decodeAdapters)
        ),
        delete: (path) => nativeTransaction.delete(this.firestore.doc(path)),
      };
      await operation(transaction);
    });
  }

  readInventory() {
    return readRemoteSocialInventory(this.firestore);
  }
}

export function createFirestoreMigrationAdapter({
  projectID,
  credentialMode,
  env = process.env,
}) {
  validateSocialCutoverRuntime({credentialMode, projectID, env});
  const adminApp = requireFromFunctions("firebase-admin/app");
  const {
    FieldValue,
    Firestore,
    GeoPoint,
    Timestamp,
    getFirestore,
  } = requireFromFunctions("firebase-admin/firestore");

  let app = null;
  let firestore;
  if (credentialMode === SocialCutoverCredentialMode.gcloudUser) {
    const authClient = createGcloudUserAuthClient({projectID});
    firestore = new Firestore({authClient, preferRest: true, projectId: projectID});
  } else if (credentialMode === SocialCutoverCredentialMode.emulatorOnly) {
    // The direct client honors FIRESTORE_EMULATOR_HOST without creating an
    // Admin app or initializing application-default credentials. Runtime
    // validation above already pins demo-noum + loopback.
    firestore = new Firestore({projectId: projectID});
  } else {
    app = adminApp.initializeApp({
      credential: adminApp.applicationDefault(),
      projectId: projectID,
    });
    firestore = getFirestore(app);
  }

  return {
    app,
    firestore,
    store: new FirestoreMigrationStore({
      firestore,
      FieldValue,
      GeoPoint,
      Timestamp,
    }),
  };
}
