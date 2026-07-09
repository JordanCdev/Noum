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
    // Any signed-in user can read; only the owner can write or delete their
    // own doc. Delete is separate because request.resource is absent then.
    // Schema enforced on write — fields kept tight so a rogue client can't
    // dump arbitrary data into the public surface.
    match /profiles_public/{accountID} {
      allow read: if request.auth != null;
      allow create, update: if request.auth != null
                            && request.auth.uid == accountID
                            && validPublicProfile(accountID);
      allow delete: if request.auth != null
                    && request.auth.uid == accountID;
    }

    // ─── League membership ────────────────────────────────────────────
    // Bucket key shape: `{tier}_{ISO-year}-W{week}` e.g. `silver_2026-W19`.
    // Any signed-in user can read all members of a bucket (peer ranking).
    // Only the owning user can write their own member doc, and only with
    // the same shape as profiles_public.
    match /leagues/{bucket}/members/{accountID} {
      allow read: if request.auth != null;
      allow create, update: if request.auth != null
                            && request.auth.uid == accountID
                            && validPublicProfile(accountID);
      allow delete: if request.auth != null
                    && request.auth.uid == accountID;
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
                    && request.resource.data.id == challengeID
                    && request.resource.data.creatorAccountID == request.auth.uid
                    && validChallengeCreateShape()
                    && validChallengeParticipants();

      allow update: if request.auth != null
                    && resource != null
                    && request.auth.uid in resource.data.participantIDs
                    && updateOnlyOwnSlice();
    }

    function validPublicProfile(accountID) {
      return request.resource.data.accountID == accountID
             && request.resource.data.keys().hasOnly([
                  'accountID', 'displayName',
                  'rating', 'peakRating',
                  'currentStreak', 'weeklyReps', 'weeklyDelta',
                  'leagueTier', 'updatedAt'
                ])
             && request.resource.data.displayName is string
             && request.resource.data.displayName.size() <= 60
             && request.resource.data.rating is int
             && request.resource.data.rating >= 100
             && request.resource.data.rating <= 1000;
    }

    // The app indexes each challenge under both durable Firebase account IDs
    // and its legacy local UUIDs. Require exactly those identities so a creator
    // cannot grant an unrelated account read access through participantIDs.
    function validChallengeParticipants() {
      let participantIDs = request.resource.data.participantIDs;
      let expectedIDs = [
        request.resource.data.creatorAccountID,
        request.resource.data.opponentAccountID,
        request.resource.data.creatorID,
        request.resource.data.opponentID
      ];
      return request.resource.data.creatorAccountID is string
             && request.resource.data.opponentAccountID is string
             && request.resource.data.creatorID is string
             && request.resource.data.opponentID is string
             && request.resource.data.creatorAccountID
                != request.resource.data.opponentAccountID
             && participantIDs is list
             && participantIDs.hasAll(expectedIDs)
             && participantIDs.hasOnly(expectedIDs);
    }

    function validChallengeCreateShape() {
      let keys = request.resource.data.keys();
      return keys.hasOnly([
               'id', 'prompt', 'createdAt', 'expiresAt',
               'creatorID', 'creatorName', 'creatorAccountID',
               'opponentID', 'opponentName', 'opponentAccountID',
               'participantIDs',
               'creatorScore', 'creatorDuration', 'creatorSummary',
               'creatorReaction'
             ])
             && request.resource.data.prompt is string
             && request.resource.data.prompt.size() > 0
             && request.resource.data.prompt.size() <= 500
             && request.resource.data.creatorName is string
             && request.resource.data.creatorName.size() <= 60
             && request.resource.data.opponentName is string
             && request.resource.data.opponentName.size() <= 60;
    }

    // An update from the creator may only touch the creator-* result fields,
    // and an update from the opponent may only touch the opponent-* result
    // fields. The sole identity-field exception lets account deletion replace
    // the departing participant's own display name with "Removed user".
    function updateOnlyOwnSlice() {
      let isCreator = request.auth.uid == resource.data.creatorAccountID;
      let isOpponent = request.auth.uid == resource.data.opponentAccountID;
      let opponentResultFields = [
        'opponentScore', 'opponentDuration',
        'opponentSummary', 'opponentReaction'
      ];
      let creatorResultFields = [
        'creatorScore', 'creatorDuration',
        'creatorSummary', 'creatorReaction'
      ];
      let resultFields = isCreator ? creatorResultFields : opponentResultFields;
      let nameFields = isCreator ? ['creatorName'] : ['opponentName'];
      let allowedFields = resultFields.concat(nameFields);
      let immutableFields = ['id', 'prompt', 'createdAt', 'expiresAt',
                             'creatorID', 'creatorAccountID',
                             'opponentID', 'opponentAccountID',
                             'participantIDs'];
      let changedFields = request.resource.data.diff(resource.data).affectedKeys();
      let nameRedactionIsValid = !changedFields.hasAny(nameFields)
        || (isCreator && request.resource.data.creatorName == 'Removed user')
        || (isOpponent && request.resource.data.opponentName == 'Removed user');
      return (isCreator || isOpponent)
             && changedFields.hasOnly(allowedFields)
             && !changedFields.hasAny(immutableFields)
             && nameRedactionIsValid;
    }
  }
}
```

## Notes for the reviewer / future deploy

- The Swift code is the *minimum* contract. Anything tighter (e.g.
  enforcing `currentStreak >= 0`, capping `weeklyReps`) is fine and
  encouraged.
- `BackendSyncManager.syncFirebaseAsyncChallenge` encodes the complete
  `AsyncChallenge` and calls `setData(..., merge: true)`. Firestore's map diff
  therefore remains the correct update boundary: unchanged identity fields in
  the full payload do not count as affected keys, while a real mutation does.
- `creatorAccountID` / `opponentAccountID` are the Firebase identities used to
  choose the writable side. `creatorID` / `opponentID` are legacy local UUIDs
  and are immutable compatibility fields, not authorization identities.
- `participantIDs` is a denormalised query index. The app includes the two
  durable account IDs plus the two legacy UUIDs (deduplicated); create rules
  require that exact set and updates cannot change it.
- Challenge status is not a stored client-writable field. `AsyncChallenge`
  derives pending / your-turn / waiting / complete / expired from the two
  participant-owned score fields plus immutable `expiresAt`. The rules allow
  only each side's score, duration, summary, reaction, and display-name slice.
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
