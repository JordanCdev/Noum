# Noum — Privacy Execution Package

> Generated: April 2025
> Scope: Solo-founder iOS app preparing for premium App Store launch
> Prerequisite: PRIVACY_AUDIT.md and PRIVACY_REMEDIATION.md

---

## 1. Executive Execution Summary

This document converts the remediation plan into paste-ready implementation tickets, a best-effort order, and a clear split between what Claude can code and what Jordan must do in cloud consoles, App Store Connect, and with legal counsel.

**Bottom line:** There are **4 emergency items** that must ship before any public build (credentials in bundle, incomplete account deletion, DeepSeek in rotation, notification PII). After those, the remaining items improve trust but are not launch-blockers if the privacy policy is honest about current state.

---

## 2. Best Implementation Order

| Order | Ticket | Why This Order | Blocking? |
|-------|--------|---------------|-----------|
| 1 | EXEC-01: Remove bundled credentials | Live AWS keys in IPA. Anyone with a jailbroken phone or `.ipa` extract can read them. | **Yes — launch blocker** |
| 2 | EXEC-02: Remove DeepSeek from provider rotation | Chinese data jurisdiction with no DPA. Transcripts are personal data. | **Yes — launch blocker** |
| 3 | EXEC-03: Fix account deletion | `deleteCurrentAccount()` leaves all UserDefaults behind. REST-backend deletion is a no-op. Apple requires full deletion for App Store. | **Yes — launch blocker** |
| 4 | EXEC-04: Genericize notification text | Lock screen shows user-authored personal coaching text to anyone who picks up the phone. | **Yes — launch blocker** |
| 5 | EXEC-05: Remove phone numbers from NoumFriend | Unnecessary PII collection. Easy fix, big privacy win. | Recommended before launch |
| 6 | EXEC-06: Add AI transcript disclosure | Users should know their speech is sent to cloud AI. Required for trust + App Store review. | Recommended before launch |
| 7 | EXEC-07: Improve delete-account confirmation UX | Current text is misleading ("this app session"). Should explain what is actually deleted. | Recommended before launch |
| 8 | EXEC-08: Add "Your Data" page in Settings | Shows users what data exists and where. Builds trust for premium. | Post-launch OK |
| 9 | EXEC-09: Build data export ("Download My Data") | On-device JSON export of all UserDefaults data stores. | Post-launch OK |
| 10 | EXEC-10: Restrict/rotate API keys in cloud consoles | Google Cloud TTS + Gemini keys are bundled. Add HTTP referrer or iOS bundle restrictions. | Do alongside EXEC-01 |
| 11 | EXEC-11: Host privacy policy | Required URL for App Store submission. | **Yes — before first submission** |
| 12 | EXEC-12: Complete App Store privacy labels | Privacy Nutrition Labels in App Store Connect. | **Yes — before first submission** |
| 13 | EXEC-13: Session-level data deletion | Let users delete individual practice sessions from history. | Post-launch OK |

---

## 3. Implementation Tickets

---

### EXEC-01: Remove Bundled AWS Credentials from Info.plist

**Priority:** P0 — Emergency
**Complexity:** Small (code change) + Medium (infra decision)
**Outcome:** No AWS credentials ship in the app binary.

#### Problem
`Info.plist` lines 5–8 contain live AWS IAM credentials:
```
AWS_ACCESS_KEY_ID: AKIAXYKJUU5SNXAK2YNZ
AWS_SECRET_ACCESS_KEY: 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
```
These are readable from any `.ipa` extract or jailbroken device.

#### Affected Files
| File | Lines | Change |
|------|-------|--------|
| `Info.plist` | 5–12 | Remove all 4 AWS keys (ACCESS_KEY_ID, SECRET_ACCESS_KEY, SESSION_TOKEN, REGION) |
| `AuthManager.swift` | 638–668 | Rewrite `loadCredentials()` — remove Info.plist fallback path (lines 647–656) |
| `Transcribe.plist.example` | — | Keep as template only; `.gitignore` the real `Transcribe.plist` |

#### Implementation Steps
1. Delete lines 5–12 from `Info.plist` (the 4 AWS key-value pairs)
2. In `AuthManager.swift` `loadCredentials()`, remove the `Bundle.main.object(forInfoDictionaryKey:)` block (lines 647–656)
3. Keep the env-var path (lines 640–644) for dev builds and the `Transcribe.plist` path (lines 657–664) for local testing
4. Ensure `Transcribe.plist` is in `.gitignore` (not committed to repo)
5. **Jordan (AWS Console):** Rotate the exposed IAM access key immediately — the current key should be considered compromised if the repo has ever been shared

#### Claude Can Help With
- Editing `Info.plist` to remove the keys
- Editing `AuthManager.swift` to remove the Info.plist fallback
- Verifying the build still compiles

#### Jordan Must Do Manually
- [ ] Go to AWS IAM Console → rotate/revoke access key `AKIAXYKJUU5SNXAK2YNZ`
- [ ] Create new IAM credentials (or switch to STS temporary credentials)
- [ ] Decide long-term credential strategy: Xcode env vars, `Transcribe.plist` (gitignored), or backend-proxied transcription
- [ ] If repo is/was public: treat the current key as compromised and audit CloudTrail logs

#### Acceptance Criteria
- `Info.plist` contains zero AWS keys
- App builds and runs with credentials supplied via env vars or `Transcribe.plist`
- `Transcribe.plist` is in `.gitignore`
- Old AWS key is deactivated in IAM Console

---

### EXEC-02: Remove DeepSeek from User-Facing AI Provider Rotation

**Priority:** P0 — Emergency
**Complexity:** Small
**Outcome:** User speech transcripts are never sent to DeepSeek servers.

#### Problem
`AISettingsManager.activeProvider` (PracticeSupport.swift:3259–3261) includes `.deepSeek` in the fallback chain:
```swift
var activeProvider: AIProvider? {
    [.gemini, .openAI, .deepSeek].first(where: hasAPIKey(for:))
}
```
DeepSeek is a Chinese AI company. User transcripts are personal data. No DPA is available from DeepSeek.

#### Affected Files
| File | Lines | Change |
|------|-------|--------|
| `PracticeSupport.swift` | 3259–3261 | Remove `.deepSeek` from the array |

#### Implementation Steps
1. Change line 3260 from `[.gemini, .openAI, .deepSeek]` to `[.gemini, .openAI]`
2. Optionally: leave `.deepSeek` available only when `DEVELOPER_ACCOUNT_IDS` contains the current user (for your own testing)

#### Claude Can Help With
- Making the one-line code change
- Optionally gating DeepSeek behind developer-only check

#### Jordan Must Do Manually
- [ ] Decide: remove DeepSeek entirely, or gate it behind developer-only flag?
- [ ] If DeepSeek API key is in `AIConfig.plist`, clear it or leave empty

#### Acceptance Criteria
- Non-developer users never hit DeepSeek
- `activeProvider` returns only `.gemini` or `.openAI` for production users

---

### EXEC-03: Fix Account Deletion to Actually Delete All Data

**Priority:** P0 — Launch Blocker (Apple requires complete account deletion)
**Complexity:** Medium
**Outcome:** "Delete Account" removes ALL user data from device and backend.

#### Problem
`deleteCurrentAccount()` (AuthManager.swift:348–373) calls `BackendSyncManager.deleteAccount()` then `signOut()`. But:
1. `signOut()` (line 332–346) only clears Keychain — it does NOT clear UserDefaults
2. `BackendSyncManager.deleteAccount()` (line 115–122) is a **no-op** for the REST backend path — only the Firebase path is implemented
3. Seven per-account UserDefaults key patterns are left behind

#### Affected Files
| File | Lines | Change |
|------|-------|--------|
| `AuthManager.swift` | 348–373 | Add UserDefaults cleanup before `signOut()` |
| `AuthManager.swift` | 332–346 | Consider adding UserDefaults cleanup to `signOut()` as well |
| `BackendSyncManager.swift` | 115–122 | Implement REST-backend account deletion (or document that REST path is unused) |
| `BackendSyncManager.swift` | 286–296 | `deleteFirebaseAccount()` has 200-session limit — should paginate |

#### Per-Account UserDefaults Keys to Clear
These are the keys that `deleteCurrentAccount()` currently leaves behind:

| Key Pattern | Source File | Line |
|-------------|------------|------|
| `coachingProfile.{accountID}` | PracticeSupport.swift | 3011 |
| `coachingProfileOnboardingComplete.{accountID}` | PracticeSupport.swift | 3012 |
| `practiceSessions.{accountID}` | PracticeSupport.swift | 5339 |
| `imRelationshipProfiles.{accountID}` | PracticeSupport.swift | 3219 |
| `recommendation.pending.{accountID}` | PracticeSupport.swift | 5543 |
| `recommendation.outcomes.{accountID}` | PracticeSupport.swift | 5550 |
| `profileXP.{accountID}` | ProfileManager.swift | 114 |

#### Implementation Steps
1. Add a `clearAllUserData(for accountID: String)` method to `AuthManager` (or a new privacy utility) that removes all 7 UserDefaults key patterns
2. Call this method from `deleteCurrentAccount()` BEFORE `signOut()`
3. Also clear: `"NoumFriendsList"` (FriendsManager), any `analysisCount`/`analysisMonth` keys from AISettingsManager
4. Decide on REST backend deletion: if REST path is unused in production, add a `print` warning; if it IS used, implement a `DELETE /accounts/{id}` endpoint
5. Fix the 200-session limit in `deleteFirebaseAccount()` — add a loop that paginates until all sessions are deleted
6. Update the delete confirmation text in SettingsView.swift:76–83 to accurately describe what is deleted

#### Claude Can Help With
- Writing `clearAllUserData(for:)` method
- Integrating it into `deleteCurrentAccount()`
- Updating the confirmation dialog text
- Adding pagination to `deleteFirebaseAccount()`

#### Jordan Must Do Manually
- [ ] Decide whether REST backend path needs a deletion endpoint
- [ ] Verify the Firebase deletion works for accounts with >200 sessions (or decide if that's an edge case)
- [ ] Test the full flow: create account → add data → delete account → verify nothing remains in UserDefaults

#### Acceptance Criteria
- After "Delete Account": all 7 per-account UserDefaults keys are removed
- `NoumFriendsList` is cleared
- Firebase backend: all sessions (even >200) are deleted
- Keychain is cleared (existing behavior)
- Delete confirmation text accurately describes what happens
- App navigates to signed-out state cleanly

---

### EXEC-04: Genericize Notification Text (Remove PII from Lock Screen)

**Priority:** P0 — Launch Blocker
**Complexity:** Small
**Outcome:** No user-authored coaching text appears on the lock screen.

#### Problem
`reminderBody()` (NotificationManager.swift:101–124) surfaces user-authored text on the lock screen:
- Line 116: `"You said this matters now because \(profile.whyNowReference)..."`
- Line 120: `"A short session is enough to keep moving toward \(profile.personalGoalReference)."`

Anyone who picks up the phone can read this. Coaching profiles may contain sensitive personal context (e.g., "my boss intimidates me", "I stutter in meetings").

#### Affected Files
| File | Lines | Change |
|------|-------|--------|
| `NotificationManager.swift` | 101–124 | Replace personalized bodies with generic motivational text |

#### Implementation Steps
1. Replace the personalized branches (lines 115–121) with generic text that doesn't include user-authored content
2. Example replacements:
   - Instead of `"You said this matters now because {whyNow}..."` → `"You've got a reason to practice today. A short session keeps the momentum going."`
   - Instead of `"...keep moving toward {personalGoal}."` → `"A short session is enough to keep building your skills."`
3. Keep the challenge progress branch (line 111–113) — it only shows system-generated progress text, not user-authored content
4. Keep the `nextMove` branch (line 107–108) if nextMove is AI-generated (not user-authored)

#### Claude Can Help With
- Rewriting the notification body text
- Verifying no other notification paths leak PII

#### Jordan Must Do Manually
- [ ] Review the replacement text and adjust tone to match your brand
- [ ] Decide: should rich personalization be available in notification *content* (only visible when unlocked)? This would require `UNNotificationContentExtension` — probably overkill for now

#### Acceptance Criteria
- Lock screen notifications contain zero user-authored text
- Notification still feels motivational and relevant
- Challenge progress text (system-generated) is still OK to show

---

### EXEC-05: Remove Phone Numbers from NoumFriend

**Priority:** P1 — Pre-launch
**Complexity:** Small
**Outcome:** App no longer stores contact phone numbers.

#### Problem
`NoumFriend` struct (FriendsManager.swift:8–30) has a `phoneNumber: String?` field. Phone numbers are sensitive PII collected from device contacts. The app doesn't appear to use phone numbers for any feature after the initial contact matching.

#### Affected Files
| File | Lines | Change |
|------|-------|--------|
| `FriendsManager.swift` | 11 | Remove `phoneNumber` property |
| Legacy contact import surface | Removed | Do not restore CNContact phone-number ingestion without an explicit privacy design |

#### Implementation Steps
1. Remove `var phoneNumber: String?` from `NoumFriend` struct (line 11)
2. Keep friend import flows from collecting phone numbers unless contact matching is redesigned with explicit consent and purpose
3. Existing stored data: add a migration or just ignore (Codable will decode old data without the field thanks to the optional)

#### Claude Can Help With
- Removing the property and fixing all compile errors
- Verifying the build succeeds

#### Jordan Must Do Manually
- [ ] Decide: do you need phone numbers for any future feature (SMS invites, etc.)? If so, collect them only at invite-send time, not at friend-add time

#### Acceptance Criteria
- `NoumFriend` has no `phoneNumber` field
- Contact import no longer stores phone numbers
- Build succeeds with zero errors

---

### EXEC-06: Add AI Transcript Disclosure

**Priority:** P1 — Pre-launch
**Complexity:** Small–Medium
**Outcome:** Users see a clear disclosure before their speech is first sent to a cloud AI.

#### Problem
The app sends live speech transcripts to Gemini/OpenAI for coaching analysis. Users are not told this happens.

#### Affected Files
| File | Change |
|------|--------|
| `PracticeSupport.swift` (CoachingProfileManager or AISettingsManager) | Add a `hasAcknowledgedAIDisclosure` flag |
| `SummaryView.swift` | Show disclosure before first AI coaching analysis |
| New: inline disclosure view or alert | One-time "Your speech is analyzed by AI" disclosure |

#### Implementation Steps
1. Add `hasAcknowledgedAIDisclosure.{accountID}` UserDefaults flag
2. Before the first AI coaching request, show a one-time disclosure: "Your speech transcript will be sent to [Google Gemini / OpenAI] for coaching analysis. Your data is processed under their API terms and is not used to train their models. [Continue / Learn More]"
3. Gate the AI analysis behind this acknowledgment
4. Add the flag to the "Your Data" page and account deletion cleanup

#### Claude Can Help With
- Adding the flag and gating logic
- Creating the disclosure alert/sheet UI

#### Jordan Must Do Manually
- [ ] Write/approve the exact disclosure text
- [ ] Decide: is a one-time banner enough, or do you want it in Settings too?
- [ ] Verify that OpenAI and Google API ToS actually say "not used for training" (they do for API usage, but confirm)

#### Acceptance Criteria
- First AI coaching request shows a disclosure
- User must tap "Continue" before transcript is sent
- Disclosure is shown once per account, not every session

---

### EXEC-07: Improve Delete Account Confirmation UX

**Priority:** P1 — Pre-launch
**Complexity:** Small
**Outcome:** Delete confirmation accurately tells users what will be deleted.

#### Problem
Current text (SettingsView.swift:82): `"This removes the current account and its synced practice data from this app session."` — this is vague and slightly misleading.

#### Affected Files
| File | Lines | Change |
|------|-------|--------|
| `SettingsView.swift` | 76–83 | Rewrite alert text |

#### Implementation Steps
1. Replace the confirmation text with something accurate:
   ```
   "This permanently deletes your account and all associated data, including:
   • Practice session history
   • Coaching profile and preferences
   • AI analysis history
   • Synced data on our servers
   
   This cannot be undone."
   ```
2. Consider adding a 2-step confirmation (type "DELETE" or similar) for extra safety

#### Claude Can Help With
- Rewriting the alert text
- Adding a 2-step confirmation if desired

#### Jordan Must Do Manually
- [ ] Approve the final confirmation text

#### Acceptance Criteria
- Delete confirmation accurately lists what is deleted
- Text matches what `deleteCurrentAccount()` actually does (after EXEC-03 fix)

---

### EXEC-08: Add "Your Data" Page in Settings

**Priority:** P2 — Post-launch OK
**Complexity:** Medium
**Outcome:** Users can see what data the app stores and where.

#### Affected Files
| File | Change |
|------|--------|
| `SettingsView.swift` | Add navigation link to new "Your Data" view |
| New: `YourDataView.swift` | New SwiftUI view showing data inventory |

#### Implementation Steps
1. Create `YourDataView.swift` with sections:
   - **On This Device:** Coaching profile, practice sessions, preferences, recordings (in Photos)
   - **On Our Servers:** Synced sessions, profile, progress (if Firebase/backend)
   - **Third-Party Processing:** AI providers (Gemini, OpenAI), AWS Transcribe — with links to their privacy policies
   - **Actions:** Delete Account, Export Data (link to EXEC-09)
2. Add a "Your Data" row in the Settings account section
3. Pull live data counts from UserDefaults (e.g., "42 practice sessions stored")

#### Claude Can Help With
- Building the entire `YourDataView.swift`
- Adding it to SettingsView navigation

#### Jordan Must Do Manually
- [ ] Review and approve the text/layout
- [ ] Add links to third-party privacy policies (Google, OpenAI, AWS)

---

### EXEC-09: Build Data Export ("Download My Data")

**Priority:** P2 — Post-launch OK
**Complexity:** Medium
**Outcome:** Users can export all their data as a JSON file.

#### Data Stores to Export
| Store | Key Pattern | Type |
|-------|-------------|------|
| Coaching Profile | `coachingProfile.{accountID}` | JSON (Codable) |
| Onboarding Status | `coachingProfileOnboardingComplete.{accountID}` | Bool |
| Practice Sessions | `practiceSessions.{accountID}` | JSON array (Codable) |
| IM Relationship Profiles | `imRelationshipProfiles.{accountID}` | JSON dict (Codable) |
| Recommendations (pending) | `recommendation.pending.{accountID}` | JSON (Codable) |
| Recommendations (outcomes) | `recommendation.outcomes.{accountID}` | JSON (Codable) |
| XP | `profileXP.{accountID}` | JSON (Codable) |
| Friends List | `NoumFriendsList` | JSON array (Codable) |

#### Implementation Steps
1. Create a `DataExporter` utility that reads all stores and produces a single JSON
2. Use `UIActivityViewController` to let users share/save the file
3. Add an "Export My Data" button in the "Your Data" page (EXEC-08) or Settings
4. JSON structure:
   ```json
   {
     "exportDate": "2025-04-14T...",
     "accountID": "abc123",
     "coachingProfile": { ... },
     "practiceSessions": [ ... ],
     "relationshipProfiles": { ... },
     "recommendations": { ... },
     "xp": { ... },
     "friends": [ ... ]
   }
   ```

#### Claude Can Help With
- Writing the full `DataExporter` class
- Creating the export UI

#### Jordan Must Do Manually
- [ ] Test with real data to verify completeness
- [ ] Decide: should export include Firebase-synced data too? (Would require an async fetch)

---

### EXEC-10: Restrict/Rotate Google API Keys

**Priority:** P1 — Do alongside EXEC-01
**Complexity:** Small (code: none; cloud console work)
**Outcome:** Bundled Google API keys are restricted to your app's iOS bundle ID.

#### Problem
`AIConfig.plist` contains live Google keys:
- `GOOGLE_CLOUD_TTS_API_KEY: AIzaSyDWtZntoiOiu9AsaKfUdqAyDdQzZXEJ2u8`
- `GEMINI_API_KEY: AIzaSyA9GfKHkiX-zYSCsonoN_nYDaBBMqD_UMo`

Unlike AWS credentials, Google API keys can be restricted to specific iOS bundle IDs, which significantly reduces risk. But they should still be restricted.

#### Affected Files
No code changes needed — this is cloud console work.

#### Jordan Must Do Manually
- [ ] Google Cloud Console → APIs & Services → Credentials
- [ ] For the TTS API key: Add iOS app restriction with your bundle ID
- [ ] For the Gemini API key: Add iOS app restriction with your bundle ID
- [ ] Set API quotas/budgets to prevent abuse if keys are extracted
- [ ] Long-term: move these calls to your backend (EXEC-01 long-term path)

#### Acceptance Criteria
- Both Google API keys have iOS bundle ID restrictions
- Billing alerts are set in Google Cloud

---

### EXEC-11: Host Privacy Policy

**Priority:** P0 — Required for App Store Submission
**Complexity:** Small
**Outcome:** A publicly accessible privacy policy URL exists.

#### Jordan Must Do Manually
- [ ] Write the privacy policy (use the outline from PRIVACY_AUDIT.md Section 5)
- [ ] Host it at a stable URL (e.g., `noum.app/privacy` or GitHub Pages)
- [ ] Enter the URL in App Store Connect → App Information → Privacy Policy URL
- [ ] Decide: do you also need a Terms of Service? (recommended for premium apps)

#### Claude Can Help With
- Drafting the privacy policy text based on the audit findings
- Nothing else — hosting and legal sign-off are on Jordan

---

### EXEC-12: Complete App Store Privacy Labels

**Priority:** P0 — Required for App Store Submission
**Complexity:** Small
**Outcome:** Accurate Privacy Nutrition Labels in App Store Connect.

#### Privacy Label Mapping

| Data Type (Apple Category) | Collected | Linked to Identity | Used for Tracking | Purpose |
|---------------------------|-----------|-------------------|-------------------|---------|
| Name | Yes | Yes | No | App Functionality |
| Email Address | Yes | Yes | No | App Functionality |
| Audio Data | Yes (microphone) | Yes | No | App Functionality |
| Speech Data | Yes (transcripts) | Yes | No | App Functionality |
| Photos or Videos | Yes (recordings) | Yes | No | App Functionality |
| Contacts | Yes (phone numbers — remove in EXEC-05) | No | No | App Functionality |
| Location (coarse) | Yes | No | No | App Functionality |
| Performance Data | No | — | — | — |
| Diagnostics | No | — | — | — |

#### Jordan Must Do Manually
- [ ] Log into App Store Connect
- [ ] Navigate to App Privacy section
- [ ] Fill in the privacy labels per the mapping above
- [ ] Update after EXEC-05 (contacts) if phone number collection is removed

---

### EXEC-13: Session-Level Data Deletion

**Priority:** P2 — Post-launch OK
**Complexity:** Small–Medium
**Outcome:** Users can delete individual practice sessions from history.

#### Affected Files
| File | Change |
|------|--------|
| `SessionHistoryView.swift` | Add swipe-to-delete on session rows |
| `PracticeSupport.swift` (SessionStore) | Add `deleteSession(id:)` method |
| `BackendSyncManager.swift` | Add single-session deletion sync |

#### Implementation Steps
1. Add `.onDelete` modifier to the session list in `SessionHistoryView`
2. Add a `deleteSession(id: UUID)` method to `SessionStore` that removes the session from the array and re-saves to UserDefaults
3. If the session was synced to Firebase, also delete the corresponding Firestore document
4. Show a confirmation before deletion

#### Claude Can Help With
- All code changes

---

## 4. What Jordan Needs to Do Manually

### Cloud Console Tasks
| Task | Service | When | Ticket |
|------|---------|------|--------|
| Rotate/revoke AWS access key `AKIAXYKJUU5SNXAK2YNZ` | AWS IAM | Immediately | EXEC-01 |
| Create new IAM credentials or switch to STS | AWS IAM | Before next build | EXEC-01 |
| Audit CloudTrail for unauthorized usage of exposed key | AWS CloudTrail | Immediately | EXEC-01 |
| Restrict Google TTS API key to iOS bundle ID | Google Cloud | Before launch | EXEC-10 |
| Restrict Gemini API key to iOS bundle ID | Google Cloud | Before launch | EXEC-10 |
| Set billing alerts/quotas on Google APIs | Google Cloud | Before launch | EXEC-10 |

### App Store Connect Tasks
| Task | When | Ticket |
|------|------|--------|
| Enter privacy policy URL | Before first submission | EXEC-11 |
| Complete privacy nutrition labels | Before first submission | EXEC-12 |
| Review App Store data deletion requirements | Before first submission | EXEC-03 |

### Legal / Content Tasks
| Task | When | Ticket |
|------|------|--------|
| Write and host privacy policy | Before first submission | EXEC-11 |
| Write Terms of Service (recommended for premium) | Before first submission | — |
| Verify OpenAI API ToS: data not used for training | Before launch | EXEC-06 |
| Verify Google Gemini API ToS: data not used for training | Before launch | EXEC-06 |
| Decide: do you need a DPA with Google/OpenAI? | Before launch if targeting EU | — |

### Code Decisions Only Jordan Can Make
| Decision | Options | Impact | Ticket |
|----------|---------|--------|--------|
| AWS credential strategy long-term | (a) Env vars only, (b) Gitignored plist, (c) Backend-proxied transcription | Determines whether any credentials ship in the binary | EXEC-01 |
| DeepSeek: remove entirely or developer-gate? | (a) Remove from code, (b) Gate behind developer ID check | Affects whether you can still test with DeepSeek | EXEC-02 |
| REST backend deletion: is it used? | (a) Yes → implement endpoint, (b) No → document as unused | Determines scope of EXEC-03 | EXEC-03 |
| Notification personalization: generic only, or rich when unlocked? | (a) Generic always, (b) Rich via NotificationContentExtension | Determines complexity of EXEC-04 | EXEC-04 |
| Phone numbers for future features? | (a) Remove now, (b) Keep for SMS invites | Determines if EXEC-05 is a delete or a refactor | EXEC-05 |
| AI disclosure text | Write and approve the exact wording | Determines EXEC-06 copy | EXEC-06 |

---

## 5. Where Claude Helps vs. Where It Doesn't

| Area | Claude Can Do | Claude Cannot Do |
|------|--------------|-----------------|
| **Code changes** | All 13 tickets' code modifications | — |
| **Info.plist edits** | Remove AWS keys, verify structure | — |
| **Build verification** | Build the project, check for compile errors | Run on a real device |
| **Privacy policy draft** | Write full text based on audit | Provide legal advice or certify compliance |
| **Cloud console changes** | — | Rotate AWS keys, restrict Google keys, set billing alerts |
| **App Store Connect** | — | Fill in privacy labels, enter URLs |
| **API ToS verification** | Fetch and summarize current ToS pages | Provide legal interpretation |
| **Testing** | Run unit tests, verify compilation | Test full user flows on device |
| **Data export** | Write the complete DataExporter class | Verify it captures all real-world data correctly |
| **Legal review** | Flag items that need legal attention | Replace a lawyer's review |

### Recommended Claude Session Plan
1. **Session A (now):** EXEC-01 + EXEC-02 + EXEC-04 + EXEC-05 — pure code changes, no decisions needed
2. **Session B:** EXEC-03 (after Jordan decides on REST backend) + EXEC-07
3. **Session C:** EXEC-06 (after Jordan writes disclosure text) + EXEC-08 + EXEC-09
4. **Session D:** EXEC-13

---

## 6. Minimal Launch-Safe Version

If you want to ship the **smallest set of changes** that make the app acceptable for a premium App Store launch:

### Must-Have (4 tickets)
| Ticket | Effort | What It Fixes |
|--------|--------|--------------|
| EXEC-01: Remove bundled AWS creds | ~30 lines changed | Credentials in binary |
| EXEC-02: Remove DeepSeek | 1 line changed | Chinese data jurisdiction |
| EXEC-03: Fix account deletion | ~50 lines added | Apple App Store requirement |
| EXEC-11: Host privacy policy | 0 code (writing + hosting) | App Store submission requirement |

### Should-Have (3 tickets)
| Ticket | Effort | What It Fixes |
|--------|--------|--------------|
| EXEC-04: Genericize notifications | ~10 lines changed | PII on lock screen |
| EXEC-05: Remove phone numbers | ~5 lines changed | Unnecessary PII |
| EXEC-12: Privacy labels | 0 code (App Store Connect) | App Store submission requirement |

### Nice-to-Have (everything else)
EXEC-06 through EXEC-10, EXEC-13 — these improve trust and UX but are not launch-blockers if your privacy policy honestly discloses current practices.

**Total launch-safe code changes: ~100 lines across 5 files.**

---

## 7. Verification Checklist

After implementing the launch-safe tickets, verify each item:

### EXEC-01: Credentials Removed
- [ ] `Info.plist` contains zero AWS keys (`grep -i AWS Info.plist` returns nothing)
- [ ] App builds successfully
- [ ] App runs and AWS Transcribe still works (via env vars or Transcribe.plist)
- [ ] Old AWS key is deactivated in IAM Console
- [ ] `AIConfig.plist` is NOT in git history (or is in `.gitignore`)

### EXEC-02: DeepSeek Removed
- [ ] `activeProvider` array does not contain `.deepSeek`
- [ ] With only a DeepSeek key configured, `activeProvider` returns `nil`
- [ ] AI coaching still works with Gemini or OpenAI key

### EXEC-03: Account Deletion Complete
- [ ] Create a test account, add sessions, coaching profile, XP, friends, recommendations
- [ ] Tap "Delete Account"
- [ ] Verify in UserDefaults: all 7 per-account keys are removed
- [ ] Verify `NoumFriendsList` is cleared
- [ ] Verify Keychain entries are cleared
- [ ] If Firebase: verify Firestore documents are deleted
- [ ] App navigates to signed-out / login state
- [ ] Re-launching the app shows a clean state

### EXEC-04: Notifications Genericized
- [ ] Trigger a test notification (set a practice reminder)
- [ ] Lock the phone, check the notification on lock screen
- [ ] Notification body contains no user-authored text
- [ ] Notification still feels motivational and useful

### EXEC-05: Phone Numbers Removed
- [ ] `NoumFriend` struct has no `phoneNumber` property
- [ ] Build succeeds
- [ ] Adding a friend from contacts does not store their phone number

### EXEC-07: Delete Confirmation Updated
- [ ] Tap "Delete Account" in Settings
- [ ] Confirmation dialog accurately lists what will be deleted
- [ ] Cancel works, Delete works

### EXEC-11: Privacy Policy Live
- [ ] Privacy policy URL is accessible in a browser
- [ ] URL is entered in App Store Connect
- [ ] Policy content matches actual app data practices

### EXEC-12: Privacy Labels Complete
- [ ] All data types are declared in App Store Connect
- [ ] Labels match actual collection practices (updated after EXEC-05)

---

## 8. Open Decisions Jordan Still Needs to Make

| # | Decision | Context | Recommendation | Blocks |
|---|----------|---------|----------------|--------|
| 1 | **AWS credential delivery method** | Current: bundled in Info.plist. Options: (a) Xcode env vars only, (b) gitignored Transcribe.plist, (c) backend proxy | **(b) for now**, (c) long-term | EXEC-01 |
| 2 | **DeepSeek: remove or developer-gate?** | DeepSeek in AIConfig.plist is currently empty, but code still checks for it | **Remove from array.** You can always add it back for testing via env var. | EXEC-02 |
| 3 | **Is the REST backend path used in production?** | `BackendSyncManager` has both REST and Firebase paths. REST `deleteAccount()` is a no-op. | If Firebase is your production backend, just add a log warning for the REST path. If REST is used, you need a DELETE endpoint. | EXEC-03 |
| 4 | **Do you want rich notifications when phone is unlocked?** | Requires `UNNotificationContentExtension` | **No — generic text is fine for now.** Revisit post-launch. | EXEC-04 |
| 5 | **Do you need phone numbers for any future feature?** | SMS invites, WhatsApp sharing, etc. | **Remove now.** Collect at point of use if needed later. | EXEC-05 |
| 6 | **AI disclosure: one-time banner or settings toggle?** | One-time is simpler. Toggle lets users revoke. | **One-time banner before first AI analysis.** Add to "Your Data" page later. | EXEC-06 |
| 7 | **Privacy policy: write yourself or use a generator?** | Generators (Termly, iubenda) are fast but generic. Hand-written is more accurate. | **Use a generator as a starting point, then customize** with specifics from the audit. | EXEC-11 |
| 8 | **Do you need Terms of Service for premium?** | Apple doesn't require it, but it protects you legally. | **Yes, write one.** Cover subscription terms, refund policy, acceptable use. | — |
| 9 | **EU users: do you need GDPR-specific compliance?** | If you sell in the EU App Store, GDPR applies. | **Yes, if EU is a target market.** Requires DPAs with Google/OpenAI, legal basis documentation, right to erasure (EXEC-03 covers this). | — |

---

## Summary

**Launch-blocker code changes:** ~100 lines across 5 files (EXEC-01, 02, 03, 04, 05)
**Launch-blocker manual tasks:** Rotate AWS key, restrict Google keys, host privacy policy, fill App Store privacy labels
**Open decisions:** 9 items that only Jordan can decide
**Claude can implement:** All code changes in a single session after decisions are made
**Timeline dependency:** AWS key rotation should happen immediately regardless of code changes
