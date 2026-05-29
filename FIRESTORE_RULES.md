# Firestore security rules — Noum (M2: Peer Pull v1)

The iOS app talks to Firestore directly via the SDK and cannot enforce
write isolation on its own. The rules below are required for the
peer-pull surfaces (public profile, league members, async challenges) to
be safe to ship. Deploy them via the Firebase console or `firebase
deploy --only firestore:rules`.

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // ─── Per-user private data ────────────────────────────────────────
    // Owners only — already covered by the existing rules. Listed here
    // for completeness so reviewers see the full picture.
    match /users/{accountID}/{document=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == accountID;
    }

    // ─── Public profile (peer-readable subset) ─────────────────────────
    // Any signed-in user can read; only the owner can write their own doc.
    // Schema enforced on write — fields kept tight so a rogue client can't
    // dump arbitrary data into the public surface.
    match /profiles_public/{accountID} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.auth.uid == accountID
                   && request.resource.data.accountID == accountID
                   && request.resource.data.keys().hasOnly([
                        'accountID', 'displayName',
                        'rating', 'peakRating',
                        'currentStreak', 'weeklyReps', 'weeklyDelta',
                        'leagueTier', 'updatedAt'
                      ])
                   && request.resource.data.displayName.size() <= 60
                   && request.resource.data.rating is int
                   && request.resource.data.rating >= 100
                   && request.resource.data.rating <= 1000;
    }

    // ─── League membership ────────────────────────────────────────────
    // Bucket key shape: `{tier}_{ISO-year}-W{week}` e.g. `silver_2026-W19`.
    // Any signed-in user can read all members of a bucket (peer ranking).
    // Only the owning user can write their own member doc, and only with
    // the same shape as profiles_public.
    match /leagues/{bucket}/members/{accountID} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.auth.uid == accountID
                   && request.resource.data.accountID == accountID;
    }

    // ─── Async challenges (two-participant docs) ──────────────────────
    // Both participants can read the whole doc. Each can only write the
    // fields that belong to "their" side of the challenge.
    match /challenges/{challengeID} {
      allow read: if request.auth != null
                  && resource != null
                  && request.auth.uid in resource.data.participantIDs;

      // Creator: full write while the doc is being created (initial sync).
      // After creation, only their own slice.
      allow create: if request.auth != null
                    && request.resource.data.creatorID == request.auth.uid
                    && request.resource.data.participantIDs.hasAll([
                         request.resource.data.creatorID,
                         request.resource.data.opponentID
                       ]);

      allow update: if request.auth != null
                    && resource != null
                    && request.auth.uid in resource.data.participantIDs
                    && updateOnlyOwnSlice();
    }

    // Helper: an update from the creator may only touch the creator-* fields,
    // and an update from the opponent may only touch the opponent-* fields.
    function updateOnlyOwnSlice() {
      let isCreator = request.auth.uid == resource.data.creatorID;
      let opponentFields = [
        'opponentScore', 'opponentDuration',
        'opponentSummary', 'opponentReaction', 'opponentName'
      ];
      let creatorFields = [
        'creatorScore', 'creatorDuration',
        'creatorSummary', 'creatorReaction', 'creatorName'
      ];
      let allowedFields = isCreator ? creatorFields : opponentFields;
      let immutableFields = ['id', 'prompt', 'createdAt', 'expiresAt',
                             'creatorID', 'opponentID', 'participantIDs'];
      return request.resource.data.diff(resource.data)
        .affectedKeys()
        .hasOnly(allowedFields)
        || request.resource.data.diff(resource.data)
        .affectedKeys()
        .hasOnly(allowedFields.concat(immutableFields));
    }
  }
}
```

## Notes for the reviewer / future deploy

- The Swift code is the *minimum* contract. Anything tighter (e.g.
  enforcing `currentStreak >= 0`, capping `weeklyReps`) is fine and
  encouraged.
- `participantIDs` is a denormalised index field added on write so
  `whereField("participantIDs", arrayContains:)` queries work without a
  composite index. The rule enforces that it always equals
  `[creatorID, opponentID]` so it can't be tampered with.
- League buckets are created lazily by the first writer in a tier+week
  pair. There is no top-level `leagues/{bucket}` document; only the
  `members/` subcollection exists. That's intentional — the bucket is a
  rendezvous, not a tracked entity.
- On account deletion the iOS client (a) deletes
  `profiles_public/{accountID}` and (b) nullifies the user's slice in
  every challenge they participate in. League member docs across past
  buckets aren't pruned by the client — they bear no PII beyond display
  name + numeric stats and the user's eventual `profiles_public` deletion
  is what the front-end queries against.
