# Noum Privacy Remediation Plan

**Date:** 2026-04-14
**Based on:** PRIVACY_AUDIT.md (same date)
**Status:** Implementation plan — not legal advice

---

## 1. Executive Remediation Summary

This plan converts the audit into four phases of concrete work. The app has strong fundamentals (no analytics SDKs, no ad tracking, local-first storage) but has several gaps that must be closed before a public launch.

**Blocking for launch:**
- Rotate and remove embedded AWS/Google credentials from the binary
- Add AI transcript disclosure (just-in-time, not a wall of consent)
- Remove DeepSeek as a user-facing provider
- Ship privacy policy and in-app Your Data page
- Fix the delete-account flow to be comprehensive
- Update App Store privacy nutrition labels

**Important but can ship fast-follow:**
- Data export (Download My Data)
- Session-level deletion
- Safer notification text
- Backend-proxied credential flows

**Maturity improvements:**
- Auto-retention rules
- Encrypted local storage for sensitive data
- Rotating invite codes

---

## 2. Prioritized Roadmap

### Phase 0: Immediate / Emergency (do before any public beta)

| # | Issue | Why It Matters | Fix | Owner |
|---|-------|---------------|-----|-------|
| 0.1 | AWS credentials in Info.plist | Anyone can extract these from the .ipa and make API calls on your AWS account. Financial and security risk. | (1) Rotate the AWS access key in IAM immediately. (2) Remove `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from Info.plist. (3) Replace with backend-vended temporary credentials (see Security Architecture §5). | iOS + Backend |
| 0.2 | Rotate exposed Google API keys | Keys in AIConfig.plist are extractable. Less severe than AWS (can be restricted) but should still be rotated. | (1) In Google Cloud Console, add iOS bundle ID restriction to both `GOOGLE_CLOUD_TTS_API_KEY` and `GEMINI_API_KEY`. (2) Rotate the keys. (3) Move to environment-variable-only injection for release builds (see §5). | iOS + Ops |
| 0.3 | Remove DeepSeek as user-facing provider | Chinese data jurisdiction. No DPA available. Sends full user transcripts to servers in China. Unacceptable for GDPR or any privacy-conscious consumer product. | Remove `deepSeek` from the `AIProvider` enum's `activeProvider` resolution. Keep the code for internal testing behind `DEVELOPER_ACCOUNT_IDS` only. See §8 for full reasoning. | iOS |

### Phase 1: Pre-Launch Must-Fix

| # | Issue | Why It Matters | Fix | Owner |
|---|-------|---------------|-----|-------|
| 1.1 | AI transcript disclosure | Users consent to microphone, not to their transcript being sent to OpenAI/Google. This is a regulatory and trust issue. | Add a one-time disclosure during first Coach Read use, and a persistent indicator showing the active AI provider. No per-click consent gate (too much friction). See Privacy UX §4. | iOS + Product |
| 1.2 | Ship privacy policy | App Store requires a privacy policy URL. You have the outline; it needs to be a real hosted page. | Convert §5 of audit into a real privacy policy. Host at `noum.app/privacy`. Link from App Store listing and in-app Settings. | Legal + Product |
| 1.3 | Ship in-app Your Data page | Users should be able to understand what data exists without reading a legal document. | Add a "Your Data" section in Settings using the draft from audit §4. See UX spec below. | iOS |
| 1.4 | Fix Delete Account completeness | Current flow deletes Firebase docs and Keychain, but does not clear all local UserDefaults data. Backend deletion path is a no-op when Firebase is configured but REST backend is also present. | (1) Clear all `{accountID}`-keyed UserDefaults on deletion. (2) Clear `NoumFriendsList`, `NoumSavedClubs`, `NoumChallenges`, `NoumAsyncChallenges`. (3) Add confirmation that explains video recordings must be deleted separately from Photos. (4) Verify backend deletion endpoint works end-to-end. | iOS + Backend |
| 1.5 | Safer notification content | Personal goals ("You said this matters because you have a big presentation") are visible on the lock screen. | Replace personalized notification bodies with generic text. Move personalized content to the app's notification content extension or in-app only. | iOS |
| 1.6 | App Store privacy nutrition labels | Required by App Store. Must accurately reflect data collection. | Fill out the App Store Connect privacy questionnaire based on §8 checklist below. | Product |
| 1.7 | Stop storing contact phone numbers | Phone numbers stored in UserDefaults are unnecessary — Noum only uses friend names for social features. | When adding a friend from contacts, store `displayName` only. Remove `phoneNumber` from `NoumFriend`. Drop stored phone numbers on next app launch via a migration step. | iOS |

### Phase 2: Near-Term Post-Launch (within 4-6 weeks)

| # | Issue | Fix | Owner |
|---|-------|-----|-------|
| 2.1 | Data export (Download My Data) | Build an on-device JSON export of all user data. See §7 for design. | iOS |
| 2.2 | Session-level deletion | Add swipe-to-delete on session history rows. Delete from local store + sync a deletion marker to backend/Firebase. | iOS + Backend |
| 2.3 | Backend-proxied AI calls | Route AI API calls through your backend instead of direct-from-client. Eliminates AI API keys from the client entirely. | Backend + iOS |
| 2.4 | Backend-proxied AWS credentials | Vend short-lived AWS STS credentials from your backend. Remove all static AWS credentials from the client. | Backend + iOS |
| 2.5 | Firestore security rules audit | Verify rules enforce user-can-only-read-write-own-documents. Test with a second account. | Backend/Ops |
| 2.6 | Sign DPAs | Ensure DPAs are signed with: AWS, OpenAI, Google Cloud, ElevenLabs. | Legal/Ops |
| 2.7 | Verify AI provider data policies | Confirm: (1) OpenAI 30-day retention, no training. (2) Google Gemini is Vertex-tier (no training), not AI Studio. (3) ElevenLabs doesn't use input for training. (4) AWS Transcribe opt-out of service improvement. | Ops |

### Phase 3: Maturity Improvements

| # | Issue | Fix | Owner |
|---|-------|-----|-------|
| 3.1 | Auto-retention for old sessions | Add optional 12-month auto-delete for sessions. Default: off. Surface in Settings. | iOS + Backend |
| 3.2 | Rotating invite codes | If QR or link-based friend invites return, use rotating, expiring invite tokens instead of persistent account UUIDs. | iOS + Backend |
| 3.3 | Encrypted local storage for transcripts | Move transcript storage from UserDefaults to an encrypted file (e.g., CryptoKit AES-GCM wrapping a Keychain-derived key). | iOS |
| 3.4 | Granular cloud sync controls | Let users opt out of syncing transcripts to cloud while keeping metrics sync. | iOS + Backend |
| 3.5 | Age gate or parental controls | If the app attracts younger users, consider a lightweight age gate. | Product |

---

## 3. Engineering Task List

These are structured as implementable tickets.

---

### TASK-001: Remove AWS credentials from Info.plist

**Priority:** P0 — Emergency
**Type:** iOS + Ops
**Depends on:** Nothing

**Description:**
Remove `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` entries from `Noum/Noum/Info.plist`. Rotate the exposed key in AWS IAM Console immediately.

**Acceptance criteria:**
- [ ] AWS key `<REDACTED — credential exposed in git; rotate before release>` is deactivated in IAM
- [ ] New key issued with minimal permissions (TranscribeStreaming only)
- [ ] Info.plist no longer contains any `AWS_*` keys
- [ ] Credentials loaded only from `Transcribe.plist` (local dev) or environment variables (CI/release)
- [ ] `Transcribe.plist` is in `.gitignore`
- [ ] App still transcribes speech correctly

**Implementation:**
In `Info.plist`, delete the four AWS key-value pairs. In `AuthManager.swift` / `SpeechRecognizerViewModel.swift`, verify the credential-loading fallback chain still works: env vars → Transcribe.plist → fail gracefully.

---

### TASK-002: Restrict and rotate Google API keys

**Priority:** P0 — Emergency
**Type:** Ops + iOS

**Description:**
In Google Cloud Console, apply iOS bundle ID restrictions to `GOOGLE_CLOUD_TTS_API_KEY` and `GEMINI_API_KEY`. Rotate both keys. For release builds, inject via Xcode scheme environment variables or CI, not bundled plists.

**Acceptance criteria:**
- [ ] Both keys restricted to iOS bundle ID in GCP Console
- [ ] Both keys rotated
- [ ] `AIConfig.plist` in repo contains only placeholder values
- [ ] Real `AIConfig.plist` is in `.gitignore` (like `Transcribe.plist`)
- [ ] CI/release builds inject keys via environment variables or a build-phase script

---

### TASK-003: Remove DeepSeek from user-facing AI provider rotation

**Priority:** P0
**Type:** iOS

**Description:**
Remove `.deepSeek` from the `activeProvider` computed property in `AISettingsManager`. Keep the DeepSeek code for developer-only testing.

**Implementation:**
In `PracticeSupport.swift`, `AISettingsManager.activeProvider`:
```swift
// Before:
[.gemini, .openAI, .deepSeek].first(where: hasAPIKey(for:))
// After:
[.gemini, .openAI].first(where: hasAPIKey(for:))
```

Also gate DeepSeek in `AICoachService` and `IMConversationEngine` so it's only available when the account ID is in `DEVELOPER_ACCOUNT_IDS`.

**Acceptance criteria:**
- [ ] No user-facing AI call can route to DeepSeek
- [ ] Developer accounts can still test DeepSeek
- [ ] `canRequestAnalysis` returns false if only DeepSeek key is configured (non-developer)

---

### TASK-004: Add AI transcript disclosure (one-time + persistent indicator)

**Priority:** P1 — Pre-launch
**Type:** iOS + Product

**Description:**
When the user first taps "Generate Coach Read" (or first IM session evaluates), show a one-time disclosure sheet:

> **Your transcript is analyzed by AI**
>
> To generate coaching feedback, your session transcript is sent to [Provider Name] for analysis. Your transcript is not used to train AI models.
>
> You can review how your data is handled in Settings > Your Data.
>
> [Continue] [Learn More]

After dismissal, persist a flag (`hasSeenAIDisclosure.{accountID}`). Do not show again.

Additionally, add a small label below the Coach Read button showing the active provider: "Powered by OpenAI" or "Powered by Google Gemini" — always visible, not obtrusive.

**Acceptance criteria:**
- [ ] Disclosure sheet appears exactly once per account
- [ ] Provider name is dynamically resolved from `aiSettings.activeProvider`
- [ ] "Learn More" navigates to the Your Data page
- [ ] Provider label visible on Coach Read card

---

### TASK-005: Build in-app Your Data page

**Priority:** P1 — Pre-launch
**Type:** iOS

**Description:**
Add a "Your Data" row in SettingsView that opens a scrollable page with the content from PRIVACY_AUDIT.md §4 (user-facing draft). Use the app's existing card/section styling.

**Sections:**
1. Your speech
2. Your coaching profile
3. AI-powered coaching
4. Video recordings
5. Voice playback
6. Session history and progress
7. Friends and social features
8. What we don't collect
9. Deleting your data
10. Contact us

Add a "Privacy Policy" link (external URL) at the bottom.

**Acceptance criteria:**
- [ ] Accessible from Settings
- [ ] Content matches audit draft
- [ ] Privacy policy link works
- [ ] Contact email is real

---

### TASK-006: Fix Delete Account to be comprehensive

**Priority:** P1 — Pre-launch
**Type:** iOS + Backend

**Description:**
The current `deleteCurrentAccount()` flow:
1. Calls `BackendSyncManager.shared.deleteAccount()` (Firebase Firestore deletion)
2. Deletes Firebase Auth user
3. Calls `signOut()` (clears Keychain)

**Missing:**
- Does not clear per-account UserDefaults keys (`coachingProfile.{id}`, `practiceSessions.{id}`, `profileXP.{id}`, `imRelationshipProfiles.{id}`, `recommendation.pending.{id}`, `recommendation.outcomes.{id}`)
- Does not clear global social data (`NoumFriendsList`, `NoumChallenges`, `NoumAsyncChallenges`, `NoumSavedClubs`)
- Does not warn about Photos library videos
- `deleteAccount()` in BackendSyncManager is a no-op for the REST backend path (only Firebase path implemented)

**Implementation:**
1. In `AuthManager.deleteCurrentAccount()`, before calling `signOut()`, add:
```swift
// Clear per-account data
let defaults = UserDefaults.standard
for key in ["coachingProfile", "practiceSessions", "profileXP",
            "imRelationshipProfiles", "recommendation.pending",
            "recommendation.outcomes",
            "coachingProfileOnboardingComplete"] {
    defaults.removeObject(forKey: "\(key).\(accountID)")
}
// Clear global user data
for key in ["NoumFriendsList", "NoumSavedClubs",
            "NoumChallenges", "NoumCompletedChallenges",
            "NoumAsyncChallenges"] {
    defaults.removeObject(forKey: key)
}
```

2. Update the delete confirmation alert text:
```
"This permanently removes your account, coaching profile, session history,
and all practice data. Video recordings saved to your Photos library must
be deleted separately."
```

3. Implement `deleteAccount()` for the REST backend path (POST to a `/v1/me/delete` endpoint or similar).

**Acceptance criteria:**
- [ ] After deletion, no UserDefaults data remains for that account
- [ ] Firebase Firestore data is deleted (sessions, profile, progress, recommendations)
- [ ] REST backend deletion endpoint is called if backend is configured
- [ ] Confirmation alert mentions Photos library
- [ ] App returns to sign-in/guest state

---

### TASK-007: Make notification content generic

**Priority:** P1 — Pre-launch
**Type:** iOS

**Description:**
In `NotificationManager.swift`, the `reminderBody()` function includes the user's free-text "why now" motivation and "success vision" in the notification body (lines 115-116). This is visible on the lock screen.

**Fix:**
Replace personalized text with generic alternatives:

```swift
// Before:
"You said this matters now because \(profile.whyNowReference).
 One more rep moves you closer to \(profile.successVisionReference)."

// After:
"A quick practice session keeps your momentum going.
 Open the app to pick up where you left off."
```

Keep the personalized versions only if they're delivered inside the app (not via notification).

**Acceptance criteria:**
- [ ] No notification body contains user-authored free text
- [ ] Notifications are still contextual (challenge progress, persona names are OK — they're system-generated, not user-authored)

---

### TASK-008: Remove phone numbers from friend storage

**Priority:** P1 — Pre-launch
**Type:** iOS

**Description:**
`NoumFriend.phoneNumber` stores contact phone numbers in UserDefaults. This data is unnecessary — the app doesn't use phone numbers for any feature after the friend is added.

**Implementation:**
1. Remove `phoneNumber` from `NoumFriend` struct
2. In `FriendsManager`, drop phone number when creating friends from contacts
3. Add a one-time migration in `FriendsManager.init()` that re-saves the friends list (which will strip phone numbers via the new Codable struct)

**Acceptance criteria:**
- [ ] `NoumFriend` no longer has a `phoneNumber` field
- [ ] Existing friend data is migrated (phone numbers dropped)
- [ ] Contacts import still works (name only)

---

### TASK-009: Build Download My Data (MVP)

**Priority:** P2 — Post-launch
**Type:** iOS

**Description:**
Generate a JSON file on-device containing all user data, and present it via a share sheet.

**Included data:**
- Coaching profile
- All practice sessions (with transcripts, metrics, AI feedback)
- IM relationship profiles
- XP and progression
- Recommendation outcomes
- Friends list (names only)
- Challenges
- Settings/preferences

**Excluded:**
- Video recordings (too large — tell user these are in Photos)
- API keys / credentials
- Raw audio (never stored)

**Format:** Single JSON file named `noum-data-export-{date}.json`

**UI:** Settings > Your Data > "Download My Data" button. Generates the file, presents `ShareLink`.

See §7 below for full design.

**Acceptance criteria:**
- [ ] Export contains all UserDefaults data for the account
- [ ] JSON is human-readable (pretty-printed)
- [ ] Share sheet appears with the file
- [ ] Does not include video files
- [ ] Works for guest accounts too

---

### TASK-010: Add session-level deletion

**Priority:** P2 — Post-launch
**Type:** iOS + Backend

**Description:**
Add swipe-to-delete on `SessionHistoryView` rows. When a session is deleted:
1. Remove from local `PracticeSessionStore`
2. If cloud sync is configured, delete the corresponding Firestore document or call backend DELETE endpoint
3. Remove any associated AI feedback

**Acceptance criteria:**
- [ ] Swipe-to-delete works on session history rows
- [ ] Deleted session is removed from local storage
- [ ] Deleted session is removed from cloud (Firebase/backend)
- [ ] Deletion confirmation alert shown

---

### TASK-011: Proxy AI calls through backend

**Priority:** P2 — Post-launch
**Type:** Backend + iOS

**Description:**
Route all AI coaching requests (OpenAI, Gemini) through the Noum backend instead of direct-from-client. This eliminates all AI API keys from the client binary.

**Backend endpoints:**
- `POST /v1/ai/coach` — proxies coaching feedback requests
- `POST /v1/ai/evaluate` — proxies IM conversation evaluation
- `POST /v1/ai/recommend` — proxies home recommendation generation
- (TTS and video analysis can remain direct-to-provider for latency, but with backend-vended short-lived tokens)

**Acceptance criteria:**
- [ ] No OpenAI or Gemini API keys in the client
- [ ] AI requests routed through backend
- [ ] Backend forwards to configured provider
- [ ] Latency acceptable (< 2s additional)

---

### TASK-012: Backend-vended AWS credentials

**Priority:** P2 — Post-launch
**Type:** Backend + iOS

**Description:**
Replace static AWS credentials with short-lived STS tokens vended by the backend.

**Flow:**
1. Client calls `GET /v1/auth/transcribe-credentials` (authenticated with X-Noum headers)
2. Backend calls `sts:AssumeRole` with a role that has only `transcribe:StartStreamTranscription` permission
3. Returns temporary credentials (15-minute expiry)
4. Client uses these for the AWS Transcribe session
5. Client refreshes when expired

**Acceptance criteria:**
- [ ] No static AWS credentials in client binary or config files
- [ ] Temporary credentials work with AWS Transcribe Streaming
- [ ] Credentials auto-refresh before expiry
- [ ] IAM role has minimal permissions

---

### TASK-013: Update App Store privacy nutrition labels

**Priority:** P1 — Pre-launch
**Type:** Product

See §9 checklist below for exact categories.

---

## 4. Privacy UX Recommendations

### What pages/settings should exist

**Settings screen additions:**
```
Settings
├── [existing sections]
├── Your Data                    ← NEW
│   ├── (scrollable info page)
│   ├── Download My Data         ← POST-LAUNCH
│   └── Privacy Policy (link)
├── Account
│   ├── Log Out
│   └── Delete Account           ← IMPROVED (see TASK-006)
```

### Where disclosures should appear

| Disclosure | Where | When | Type |
|-----------|-------|------|------|
| AI transcript analysis | Coach Read card (SummaryView) | First time user taps "Generate Coach Read" | One-time bottom sheet |
| Active AI provider | Coach Read card (SummaryView) | Always | Small label: "Powered by OpenAI" |
| Video frame analysis | Video Analysis button (SummaryView) | First time user taps "Analyze Video" | One-time bottom sheet |
| Cloud transcription | Microphone permission dialog | First practice session | iOS system dialog (existing) |
| Cloud sync | Settings > Your Data | Always visible | Informational text |
| Delete Account scope | Delete Account confirmation | Every time | Alert text (updated) |

### What belongs in onboarding vs settings vs just-in-time

**Onboarding:** Nothing new. The coaching profile onboarding is already the right amount. Do not add a privacy wall to onboarding — it signals distrust before the user has experienced value.

**Just-in-time (first use):** AI transcript disclosure, video analysis disclosure. These should appear exactly once, at the moment the user first triggers the action.

**Settings (always available):** Your Data page, Download My Data, Delete Account, Privacy Policy link. These are for users who want to understand or act on their data at any time.

### What the user should be told

Keep it short. Users don't read walls of text. The key messages:

1. "Your speech is converted to text using a cloud service (AWS). The audio is not stored."
2. "AI coaching feedback is generated by [OpenAI/Google]. Your transcript is sent for analysis but not used for training."
3. "Your sessions are stored on your device. If you're signed in, they sync to our cloud for backup."
4. "You can delete your account and all data from Settings."
5. "We don't use analytics, ads, or tracking."

---

## 5. Security Architecture Recommendations

### Target architecture (practical, not enterprise)

```
┌─────────────────────┐
│     iOS Client       │
│                      │
│  No API keys for:    │
│  - AWS               │
│  - OpenAI            │
│  - Gemini            │
│  - ElevenLabs        │
│                      │
│  Has:                │
│  - Backend API key   │
│  - Firebase config   │
│  (both restricted)   │
└──────────┬───────────┘
           │
           │ HTTPS + X-Noum-Account-ID
           │
┌──────────▼───────────┐
│    Noum Backend       │
│                       │
│  Proxies:             │
│  - AI coaching calls  │
│  - TTS (optional)     │
│  - Video analysis     │
│                       │
│  Vends:               │
│  - AWS STS temp creds │
│                       │
│  Stores:              │
│  - AI API keys        │
│  - AWS master creds   │
└───────────────────────┘
```

### Phased approach

**Phase 0 (now):** Rotate and restrict keys. Remove from Info.plist. Keep direct-to-provider calls but load keys from env vars only.

**Phase 2 (post-launch):** Proxy AI calls through backend. Vend AWS temp credentials. Client has zero third-party API keys.

**Phase 3 (maturity):** Encrypt local transcript storage. Consider certificate pinning for backend calls.

### Local storage

| Data | Current Storage | Recommended |
|------|----------------|-------------|
| Account ID, name, provider | Keychain | Keep (correct) |
| Coaching profile | UserDefaults | Acceptable (low sensitivity) |
| Transcripts | UserDefaults | Move to encrypted file (CryptoKit AES-GCM) in Phase 3 |
| Friend phone numbers | UserDefaults | Remove phone numbers entirely (TASK-008) |
| AI API keys | Bundled plist | Remove from client (Phase 2) |
| AWS credentials | Info.plist | Remove immediately (TASK-001) |

### Transcripts: local vs sync vs optional

**Recommendation:** Keep the current model (sync by default when signed in) but:
1. Make it clearly disclosed in Your Data page
2. Add session-level deletion (TASK-010)
3. In Phase 3, add a Settings toggle: "Sync session transcripts to cloud" (default: on for signed-in users)

Do not make sync opt-in by default — it would break the cross-device experience that signed-in users expect. Instead, disclose and give control.

---

## 6. Retention & Deletion Recommendations

### What should be stored indefinitely
- Account credentials (until deletion)
- Coaching profile (until deletion)
- XP/progression (until deletion)

### What should auto-delete
- Monthly usage counters: already auto-reset (correct)
- IM relationship decay: already implemented (correct)
- Transient data (audio, tokens, video frames): already transient (correct)

### What should be user-deletable at session level
- Individual practice sessions (TASK-010)
- AI coach feedback (deleted with session)
- Individual friends (already possible)
- Saved clubs (already possible)

### What should be excluded from cloud sync
- Friend phone numbers (being removed — TASK-008)
- Saved clubs (already local-only)
- Challenges (already local-only)
- Notification preferences (already local-only)

### What should stay on-device only
- Video recordings (already device-only — correct)
- Friend data (already local-only — correct)
- Challenge data (already local-only — correct)

### What should require explicit opt-in
- Video recording (already opt-in per session — correct)
- AI video analysis (already user-initiated — correct)
- Contacts access (already system-gated — correct)
- Location access (already system-gated — correct)

### Product rules by data type

| Data Type | Rule |
|-----------|------|
| **Transcripts** | Stored locally + synced (when signed in). Deletable per-session. Auto-delete option (12 months, off by default) in Phase 3. |
| **Video recordings** | Device-only. User manages via Photos. Not covered by Delete Account (disclosed in confirmation). |
| **AI feedback** | Stored with session. Deleted when session is deleted. |
| **Coaching profile free-text** | Stored locally + synced. Deleted on account deletion. Not exposed in notifications (TASK-007). |
| **IM conversations** | Stored with session. Deletable per-session. Relationship profiles decay over time (already implemented). |
| **Contacts/friends** | Local-only. Phone numbers removed (TASK-008). Names only. |
| **Notifications** | Generic text only (TASK-007). Preference stored locally. |
| **Usage counters** | Local-only. Auto-reset monthly. |

---

## 7. Download My Data (MVP Design)

### What data is included

```json
{
  "exportDate": "2026-04-14T10:30:00Z",
  "exportVersion": 1,
  "account": {
    "id": "abc-123",
    "provider": "apple",
    "displayName": "Jordan"
  },
  "coachingProfile": {
    "speakingContext": "work",
    "primaryGoal": "reduceFillers",
    // ... all profile fields
  },
  "sessions": [
    {
      "id": "session-uuid",
      "date": "2026-04-10T14:30:00Z",
      "mode": "timed",
      "transcript": "Good morning everyone...",
      "fillerWordCount": 7,
      "duration": 62.5,
      "score": 7,
      "xpEarned": 35,
      "headline": "Strong opening, watch the filler words",
      "aiCoachFeedback": {
        "strengths": ["Clear structure", "Good pace"],
        "keyImprovement": "Reduce filler words in transitions",
        "suggestedDrill": "Practice transitions without fillers",
        "revisedOpening": "Good morning, team. Today I want to cover..."
      },
      "prompt": "Tell me about a recent success",
      "imConversationDetails": null
    }
  ],
  "xp": 2450,
  "friends": [
    { "displayName": "Alex", "addedAt": "2026-03-15" }
  ],
  "challenges": [],
  "settings": {
    "timedDifficulty": "medium",
    "voicePlaybackEnabled": true,
    "practiceRemindersEnabled": false
  }
}
```

### What is excluded
- Video recordings (too large; tell user they're in Photos)
- Raw audio (never stored)
- API keys / credentials
- Transient data

### How it works in the UI

```
Settings > Your Data > [Download My Data]
    ↓
Generating... (progress indicator, ~1-2 seconds)
    ↓
Share sheet with noum-data-export-2026-04-14.json
```

### Implementation

1. Read all UserDefaults data for the current account
2. Assemble into a `NoumDataExport` Codable struct
3. Encode to pretty-printed JSON
4. Write to temp file
5. Present `ShareLink` or `UIActivityViewController`

Entirely on-device. No backend call needed. This is the MVP.

**Post-MVP:** If the backend stores data that the client doesn't have locally (e.g., older sessions that were pruned), add a `GET /v1/me/export` backend endpoint that returns the same JSON structure.

---

## 8. DeepSeek Decision

### Recommendation: Remove from user-facing provider rotation. Keep code for internal testing only.

### Reasoning:

1. **Jurisdiction:** DeepSeek is a Chinese company. User transcripts and coaching profiles — which contain personal goals, speaking challenges, and free-text motivations — would be sent to servers likely in China. This creates unacceptable data sovereignty risk for EU users (GDPR requires adequate protection or explicit consent for non-EU transfers), and reputational risk for any privacy-conscious user base.

2. **No DPA:** DeepSeek does not publish a GDPR-compliant Data Processing Agreement for API customers. Without a DPA, you cannot legally use them as a data processor for EU personal data.

3. **Training policy unclear:** DeepSeek's API data usage policy is less transparent than OpenAI's or Google's. It's unclear whether API inputs may be used for model improvement.

4. **Not needed:** You already have two strong providers (OpenAI, Google Gemini). DeepSeek adds fallback redundancy but at a cost that outweighs the benefit.

5. **Cost of keeping:** If DeepSeek is available to users, you must disclose it in your privacy policy, App Store labels, and in-app disclosures. This adds compliance burden for a provider you don't need.

### Implementation:

```swift
// AISettingsManager.activeProvider — remove .deepSeek:
var activeProvider: AIProvider? {
    [.gemini, .openAI].first(where: hasAPIKey(for:))
}
```

Keep the `AIProvider.deepSeek` enum case and all associated code. Gate it behind developer-account checks:

```swift
var availableProviders: [AIProvider] {
    var providers: [AIProvider] = [.gemini, .openAI]
    if AuthManager.shared.isDeveloper {
        providers.append(.deepSeek)
    }
    return providers
}
```

This lets you test DeepSeek internally without exposing users to it.

---

## 9. App Store + Legal/Compliance Checklist

### App Store Privacy Nutrition Labels

Based on the audit, fill out App Store Connect as follows:

**Data Used to Track You:** None

**Data Linked to You:**

| Category | Data Type | Purpose |
|----------|-----------|---------|
| Contact Info | Name | App Functionality |
| User Content | Audio Data, Other User Content (transcripts) | App Functionality |
| Identifiers | User ID | App Functionality |
| Usage Data | Product Interaction | App Functionality |
| Diagnostics | Other Diagnostic Data (session metrics) | App Functionality |
| Purchases | Purchase History | App Functionality |

**Data Not Linked to You:** None (all data is linked to account ID)

**Data Not Collected:**
- Health & Fitness
- Financial Info
- Sensitive Info
- Browsing History
- Search History
- Location (transient, not stored)
- Contacts (phone numbers being removed; only accessed transiently)

### Permission Prompts

| Permission | Current String | Status |
|-----------|---------------|--------|
| Microphone | "Noum uses the microphone to listen to and transcribe your speaking practice sessions." | OK |
| Speech Recognition | "Noum uses speech recognition to transcribe your practice sessions in real time." | OK |
| Camera | "Noum uses the camera to record your practice sessions so you can review your delivery." | OK |
| Photo Library (Add) | "Noum saves your session recordings to the Photos library so you can review and share them." | OK |
| Contacts | "Noum checks your contacts to help you find friends who also use the app." | OK |
| Location | "Noum uses your approximate location only when you search for nearby speaking clubs." | Current copy matches the only user-initiated location flow. Path daylight visuals use timezone fallback and must not trigger an OS prompt. |

### Privacy Policy

- [ ] Privacy policy hosted at a public URL
- [ ] URL entered in App Store Connect
- [ ] Policy covers all data categories from the audit
- [ ] Policy names all third-party processors
- [ ] Policy explains user rights (delete, export)
- [ ] Policy explains data retention
- [ ] Policy has a contact email

### Other Legal

- [ ] Terms of Service / Terms of Use (separate from privacy policy)
- [ ] DPAs signed with: AWS, OpenAI, Google Cloud (Firebase + Gemini + TTS), ElevenLabs
- [ ] DeepSeek removed from user-facing use (no DPA needed)
- [ ] Apple's App Store Review Guidelines §5.1.1 (data collection and storage) compliance
- [ ] Apple's App Store Review Guidelines §5.1.2 (data use and sharing) compliance
- [ ] GDPR compliance self-assessment (if serving EU users)
- [ ] CCPA compliance self-assessment (if serving California users)
- [ ] COPPA: confirm app is not directed at children under 13

### Security Basics

- [ ] No credentials in committed code or bundled config files
- [ ] All network requests use HTTPS
- [ ] Firebase security rules audited
- [ ] AWS IAM role follows least-privilege principle
- [ ] API keys restricted (Google: bundle ID restriction; AWS: minimal IAM policy)
- [ ] Account deletion works end-to-end (local + cloud + Firebase Auth)

---

## 10. Items for Legal Review Only

These items require input from a lawyer or compliance professional. Do not try to self-resolve:

1. **Privacy policy final text.** The outline in the audit is a starting point, but the final privacy policy must be reviewed by counsel, particularly the third-party processor disclosures and data retention sections.

2. **GDPR applicability.** If the app will be available in the EU (which it will be on the App Store by default), confirm whether you need to appoint a Data Protection Officer, conduct a Data Protection Impact Assessment (DPIA), or register with a supervisory authority.

3. **International data transfers.** User transcripts are processed by US-based companies (OpenAI, Google) and AWS in eu-west-2 (London). Confirm whether Standard Contractual Clauses (SCCs) or other transfer mechanisms are needed.

4. **CCPA applicability.** If you have California users, determine whether CCPA applies and whether you need a "Do Not Sell My Personal Information" mechanism (likely not, since you don't sell data, but confirm).

5. **Children's data (COPPA).** Confirm the age threshold for your app and whether any age-gating mechanism is required. If the app could attract users under 13, COPPA compliance is required.

6. **Terms of Service.** Separate from the privacy policy, you need ToS covering user-generated content (transcripts, recordings), acceptable use, liability limitations, etc.

7. **Apple App Review compliance.** Have counsel review the App Store Review Guidelines §5.1 (Legal) section to confirm all privacy requirements are met before first submission.

8. **Data breach notification obligations.** Determine what obligations you have if user transcripts or coaching profiles are exposed in a breach. This depends on jurisdiction and data types.

---

*This document is the implementation companion to PRIVACY_AUDIT.md. Use together for planning and execution.*
