# Firestore security rules — Noum release contract

The canonical, deployable rules are [`firestore.rules`](firestore.rules).
`firebase.json` points directly to that file. Do not copy an older rules block
from documentation or the Firebase console.

The release contract is intentionally narrow:

- Private `users/{uid}` data is limited to the registered root, profile,
  progress, session, and recommendation paths with bounded document shapes.
  Those paths are owner-readable and owner-writable only while
  `_accountDeletionState/{uid}` is absent; arbitrary nested paths are denied.
- Competitive evidence, state, rate limits, friend authorization, deletion
  references, migration run journals and quarantine records, legacy-cutover
  proof, and deletion tombstones are client-denied.
- `profiles_public` and league members are not directly readable. Authenticated,
  App Check-verified callables provide reciprocal-friend profile reads and a
  bounded current-league list derived from trusted server state.
- Clients may change only their bounded `displayName` on an existing public
  profile or league member; every competitive field remains server-authored.
- Challenge metadata is participant-readable, each private submission is
  readable only by its owner, and the combined result is participant-readable
  only after the server materializes it.
- All client creates and competitive-result writes are denied.

Account deletion deliberately fails closed until
`_socialReferenceCutover/current` proves the legacy social inventory was
backfilled. A pending tombstone blocks writes throughout retryable cleanup.

The recoverable migration namespace is server-only and uses these exact paths:

- `_socialReferenceCutover/current` is the source-bound resumable run journal
  while a migration is in progress. The server replaces that same document
  with the global completion marker only after exact inventory verification.
- `_socialReferenceQuarantine/{runID}/documents/{sourcePathSHA256}` stores one
  recoverable source record. `sourcePathSHA256` is the deterministic lowercase
  canonical SHA-256 of the original document-path value; the record binds the
  exact source path, source data, source digest, backup digest, and run ID.
- `_socialReferences/{accountID}` remains the exact-deletion manifest.

The in-progress journal is schema v2 with exact provenance plus one phase from
`journaled`, `quarantined`, `manifests-written`, or `verified`. Its exact keys
are `schemaVersion`, `status`, `runID`, `projectID`, `sourceGitCommit`,
`sourceImplementationSHA256`, `backupDigest`, `phase`, and `inventoryDigest`.

The completion marker is accepted only as the exact schema-v2 provenance
record: `schemaVersion`, `status`, `runID`, `projectID`, `sourceGitCommit`,
`sourceImplementationSHA256`, `backupDigest`, `inventoryDigest`,
`verifiedInventoryDigest`, and `completedAt`. The project must be
`noum-d0b6f`, `runID` must use 1–64 safe characters, every source/digest field
must use its bounded lowercase hex form, `completedAt` must be a Firestore
timestamp, and `inventoryDigest` must equal `verifiedInventoryDigest`. Absent,
in-progress, v1, malformed, or extra-field markers keep every social callable
closed.

Every client, including an authenticated owner, is denied get, list, create,
update, and delete access throughout those namespaces. Only trusted Admin SDK
runtimes may create or recover migration data. A completion marker is not a
replacement for a run journal or quarantine copy.

Prepare that cutover with the guarded migration utility. The first command is
remote-read-only and produces an ignored local backup; neither write mode
should be used without reviewing that backup and obtaining approval:

```sh
node scripts/migrate-social-reference-cutover.mjs --project=noum-d0b6f
node scripts/migrate-social-reference-cutover.mjs --project=noum-d0b6f \
  --apply --confirm-project=noum-d0b6f
```

Apply fails closed while any legacy client-authored public profile or league
row exists unless the explicit purge approval is present. The recoverable path
writes the source-bound journal first, copies and deletes each legacy document
inside one transaction, resumes from verified phases after interruption, then
writes manifests and verifies the exact resulting inventory before completing
the marker. Rollback restores the original source and manifest inventory before
removing quarantine and the journal. Legacy ratings, streaks, and league values
are never promoted into trusted server state.

Verification and deployment:

```sh
./scripts/test-coach-functions-emulator.sh
npx -y firebase-tools@latest deploy --only firestore:rules --project noum-d0b6f
```

Deployment is a deliberate release operation and is not performed by local
implementation or test runs.
