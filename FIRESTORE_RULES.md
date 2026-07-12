# Firestore security rules — Noum release contract

The canonical, deployable rules are [`firestore.rules`](firestore.rules).
`firebase.json` points directly to that file. Do not copy an older rules block
from documentation or the Firebase console.

The release contract is intentionally narrow:

- Private `users/{uid}` data is owner-readable and owner-writable only while
  `_accountDeletionState/{uid}` is absent.
- Competitive evidence, state, rate limits, friend authorization, deletion
  references, legacy-cutover proof, and deletion tombstones are client-denied.
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

Verification and deployment:

```sh
./scripts/test-coach-functions-emulator.sh
npx -y firebase-tools@latest deploy --only firestore:rules --project noum-d0b6f
```

Deployment is a deliberate release operation and is not performed by local
implementation or test runs.
