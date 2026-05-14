# Noum Privacy & Data Audit

**Date:** 2026-04-14
**Scope:** Full codebase audit of Noum iOS app
**Status:** Operational reference — not legal sign-off

---

## 1. Executive Summary

Noum is a speaking practice app that collects substantial user data across several categories: authentication credentials, coaching profiles with free-text personal goals, full speech transcripts, video/audio recordings, AI-generated coaching feedback, behavioral/gamification data, social/friend data, and contact information.

Data flows to multiple third parties:
- **AWS Transcribe** (real-time speech-to-text)
- **OpenAI, Google Gemini, DeepSeek** (AI coaching feedback, conversation generation)
- **Google Cloud TTS, OpenAI TTS, ElevenLabs** (voice synthesis)
- **Firebase** (authentication, Firestore sync, Remote Config)
- **Custom Noum backend** (optional — profile/session/XP sync)
- **Open-Meteo** (weather context — public API, no auth)

The app does **not** use Firebase Analytics, Crashlytics, or any third-party analytics SDK. There is no ad tracking.

**Key risks identified:**
- Full speech transcripts sent to multiple AI providers without explicit per-transmission consent
- AWS credentials embedded in Info.plist (shipped in binary)
- API keys for Google Cloud TTS and Gemini in bundled AIConfig.plist
- No data export mechanism for users
- No explicit data retention/deletion policy
- Contact phone numbers stored in UserDefaults (unencrypted at rest)
- Video frames (screenshots from recordings) sent to AI vision APIs for analysis

---

## 2. Full Data Inventory

### 2.1 Authentication & Account Data

| Field | Example | Collected Where | Purpose | Required? | Storage | Processor | Retention | Deletion | Sensitivity |
|-------|---------|----------------|---------|-----------|---------|-----------|-----------|----------|-------------|
| Account ID (UUID) | Firebase UID or generated UUID | Sign-in flow (AuthManager) | Identify user across sessions | Yes | iOS Keychain (`NoumAccountID`) | Firebase Auth, Noum backend | Indefinite | On account deletion | Medium |
| Display Name | "Jordan" | Apple/Google Sign-In | Personalization, social features | Optional | iOS Keychain (`NoumAccountName`) | Firebase Auth, Noum backend | Indefinite | On account deletion | Low |
| Auth Provider | "apple" / "google" / "guest" | Sign-in flow | Determine auth method | Yes | iOS Keychain (`NoumAccountProvider`) | Firebase Auth | Indefinite | On account deletion | Low |
| Apple Identity Token | JWT | Apple Sign-In | Authenticate with Firebase | Yes (Apple flow) | Memory only (transient) | Apple, Firebase Auth | Transient | Automatic | High |
| Google ID Token + Access Token | OAuth tokens | Google Sign-In | Authenticate with Firebase | Yes (Google flow) | Memory only (transient) | Google, Firebase Auth | Transient | Automatic | High |
| Firebase Anonymous UID | Auto-generated | App launch | Fallback identity | Automatic | Firebase Auth | Firebase | Until sign-in or deletion | On account deletion | Low |

### 2.2 Coaching Profile Data

| Field | Example | Collected Where | Purpose | Required? | Storage | Processor | Retention | Deletion | Sensitivity |
|-------|---------|----------------|---------|-----------|---------|-----------|-----------|----------|-------------|
| Speaking Context | "work" / "interviews" | Onboarding | Personalize coaching | Yes (onboarding) | UserDefaults (`coachingProfile.{accountID}`) | Noum backend, Firebase, AI providers (as context) | Indefinite | On account deletion | Low |
| Primary Goal | "reduceFillers" | Onboarding | Focus coaching advice | Yes | Same | Same | Indefinite | On account deletion | Low |
| Confidence Level | "rebuilding" | Onboarding | Calibrate difficulty | Yes | Same | Same | Indefinite | On account deletion | Medium |
| Biggest Challenge | "rambling" | Onboarding | Target coaching | Yes | Same | Same | Indefinite | On account deletion | Medium |
| Speaking Style Goal | "executive" | Onboarding | Shape AI feedback tone | Yes | Same | Same | Indefinite | On account deletion | Low |
| Style Reference | "Obama's calm delivery" | Onboarding (free text) | Personalize identity model | Optional | Same | Same | Indefinite | On account deletion | Low |
| Coaching Brief | "I want to stop saying um..." | Onboarding (free text) | Personalize coaching | Optional | Same | AI providers, backend | Indefinite | On account deletion | **Medium-High** |
| Why Now Motivation | "I have a big presentation next week" | Onboarding (free text) | Personalize coaching | Optional | Same | AI providers, backend | Indefinite | On account deletion | **Medium-High** |
| Success Vision | "I want to feel confident in meetings" | Onboarding (free text) | Personalize coaching | Optional | Same | AI providers, backend, also used in notification text | Indefinite | On account deletion | **Medium-High** |
| Onboarding Complete Flag | true | Onboarding | Track completion | Automatic | UserDefaults | Local only | Indefinite | On account deletion | None |

### 2.3 Speech Transcripts & Session Data

| Field | Example | Collected Where | Purpose | Required? | Storage | Processor | Retention | Deletion | Sensitivity |
|-------|---------|----------------|---------|-----------|---------|-----------|-----------|----------|-------------|
| Full Speech Transcript | "Good morning everyone, today I want to talk about..." | All practice modes (via AWS Transcribe) | Core feature — evaluate speech | Yes | UserDefaults (`practiceSessions.{accountID}`), synced to Firebase/backend | AWS Transcribe, AI providers (OpenAI/Gemini/DeepSeek), Noum backend | Indefinite | On account deletion | **High** |
| Filler Word Count | 7 | FillerWordDetector (on-device) | Coaching metric | Automatic | Same as transcript | Local computation, synced with session | Indefinite | With session | Low |
| Session Duration | 62.5 seconds | Timer (on-device) | Coaching metric | Automatic | Same | Synced with session | Indefinite | With session | Low |
| Words Per Minute | 142 | WPMEvaluator (on-device) | Coaching metric | Automatic | Computed, not stored separately | Local computation | Transient | N/A | None |
| Practice Mode | "timed" / "suddenDeath" / "imConversation" | Mode selection | Categorize sessions | Automatic | Same as transcript | Synced with session | Indefinite | With session | None |
| Practice Prompt | "Tell me about a time you failed" | Topic selection | Context for evaluation | Automatic | Same | AI providers (for evaluation) | Indefinite | With session | Low |
| Score (1-10) | 7 | PracticeEvaluator (on-device) | Coaching metric | Automatic | Same | Synced with session | Indefinite | With session | Low |
| AI Coach Feedback | {strengths, keyImprovement, suggestedDrill, revisedOpening} | AI providers | Deeper coaching | Optional (user-initiated) | Same | AI providers generate, stored locally + synced | Indefinite | With session | Medium |
| Session Headline | "Strong opening, watch the filler words" | On-device evaluation | Quick summary | Automatic | Same | Local + synced | Indefinite | With session | Low |
| XP Earned | 35 | Gamification system | Progress tracking | Automatic | UserDefaults (`profileXP.{accountID}`) + synced | Backend/Firebase | Indefinite | On account deletion | None |

### 2.4 IM Conversation Data

| Field | Example | Collected Where | Purpose | Required? | Storage | Processor | Retention | Deletion | Sensitivity |
|-------|---------|----------------|---------|-----------|---------|-----------|-----------|----------|-------------|
| Conversation Turns (all messages) | [{speaker: "user", text: "..."}, {speaker: "npc", text: "..."}] | IM practice mode | Conversation simulation | Yes (IM mode) | Stored with PracticeSession | AI providers (for reply generation + evaluation), Noum backend | Indefinite | With session | **High** |
| Conversation State | {trust: 72, engagement: 85, tension: 15} | AI-computed | Guide conversation flow | Automatic | Memory + session | AI providers, backend | Indefinite | With session | Low |
| Relationship Profile | {warmthScore, reliabilityScore, rememberedTopics, ...} | AI-computed over multiple sessions | Conversation continuity | Automatic | UserDefaults (`imRelationshipProfiles.{accountID}`) | AI providers, backend | Indefinite | On account deletion | Medium |
| Conversation Evaluation | {toneMatch, clarityScore, composureScore, ...} | AI providers | Post-session coaching | Automatic | With session | AI providers, backend | Indefinite | With session | Low |

### 2.5 Audio & Video Recordings

| Field | Example | Collected Where | Purpose | Required? | Storage | Processor | Retention | Deletion | Sensitivity |
|-------|---------|----------------|---------|-----------|---------|-----------|-----------|----------|-------------|
| Live Audio Stream | PCM 16-bit audio | Microphone capture | Real-time transcription | Yes | **Transient** — streamed to AWS, not stored locally as audio | AWS Transcribe (eu-west-2) | Not retained after transcription | Automatic | **High** |
| Video Recording | .mov file (up to 3 min) | Camera during practice | Self-review | Optional (premium) | Temp dir → Photos Library or Documents/Recordings/ | Local device only | Until user deletes from Photos/Files | Manual by user | **High** |
| Video Frames for AI Analysis | 4 JPEG frames (60% quality, base64) | Extracted from video | Nonverbal coaching feedback | Optional (user-initiated) | **Transient** — sent to API, not stored | OpenAI Vision or Gemini Vision | Not retained locally after send | Automatic | **High** |

### 2.6 Social & Friends Data

| Field | Example | Collected Where | Purpose | Required? | Storage | Processor | Retention | Deletion | Sensitivity |
|-------|---------|----------------|---------|-----------|---------|-----------|-----------|----------|-------------|
| Friend Display Name | "Alex" | Manual entry or contacts import | Social features | Optional | UserDefaults (`NoumFriendsList`) | **Local only** — not synced to backend | Indefinite | Manual removal | Low |
| Friend Phone Number | "+1-555-0123" | Contacts framework | Friend identification | Optional | UserDefaults (`NoumFriendsList`) | **Local only** | Indefinite | Manual removal | **Medium-High** |
| Friend UUID | Generated UUID | Friend add flow | Link challenges | Automatic | UserDefaults | Local only | With friend record | On removal | Low |
| Add Method | "contacts" / "qrCode" | Friend add flow | Attribution | Automatic | UserDefaults | Local only | With friend record | On removal | None |
| Async Challenge Data | {prompt, scores, reactions} | Challenge creation | Social speak-offs | Optional | UserDefaults (`NoumAsyncChallenges`) | **Local only** (MVP — designed for future sync) | Indefinite | Manual | Low |

### 2.7 Contacts Access

| Field | Example | Collected Where | Purpose | Required? | Storage | Processor | Retention | Deletion | Sensitivity |
|-------|---------|----------------|---------|-----------|---------|-----------|-----------|----------|-------------|
| Contact Names | "Jane Smith" | iOS Contacts framework | Find friends | Optional (user-initiated) | Memory during browsing; stored only when user adds as friend | **Local only** | Transient unless user adds friend | Automatic (browse) / manual (friends) | Medium |
| Contact Phone Numbers | "+1-555-0100" | iOS Contacts framework | Identify contacts | Optional | Same — stored with friend if added | **Local only** | Same | Same | **High** |

### 2.8 Location Data

| Field | Example | Collected Where | Purpose | Required? | Storage | Processor | Retention | Deletion | Sensitivity |
|-------|---------|----------------|---------|-----------|---------|-----------|-----------|----------|-------------|
| Approximate Location (coordinate) | 51.5074, -0.1278 | CoreLocation (When In Use) | Find nearby speaking clubs; daylight calculation for path UI | Optional (user-initiated for clubs) | **Memory only** — not persisted or synced | Apple MapKit (local search), Open-Meteo (geocoding) | Transient | Automatic | Medium |

### 2.9 Device & App Metadata

| Field | Example | Collected Where | Purpose | Required? | Storage | Processor | Retention | Deletion | Sensitivity |
|-------|---------|----------------|---------|-----------|---------|-----------|-----------|----------|-------------|
| Audio Sample Rate | 48000 Hz | AVAudioSession | Configure transcription | Automatic | Memory only | AWS Transcribe | Transient | Automatic | None |
| Preferred Language | en-US | Hardcoded | Speech recognition language | Automatic | N/A | AWS Transcribe | N/A | N/A | None |
| Device Notification Permission | authorized/denied | UNUserNotificationCenter | Schedule reminders | Optional | UserDefaults (`practiceRemindersEnabled`) | Apple Push Notification (local only) | Indefinite | Settings toggle | None |

### 2.10 Purchase & Subscription Data

| Field | Example | Collected Where | Purpose | Required? | Storage | Processor | Retention | Deletion | Sensitivity |
|-------|---------|----------------|---------|-----------|---------|-----------|-----------|----------|-------------|
| Premium Status | true/false | StoreKit 2 | Feature gating | Automatic | UserDefaults (`NoumPremiumEntitlement`) | Apple StoreKit | Indefinite | Managed by Apple | Low |
| Purchased Product IDs | "com.noum.pro.monthly" | StoreKit 2 | Subscription tracking | Automatic | Memory (verified at runtime) | Apple StoreKit | Managed by Apple | Managed by Apple | Low |
| Video Analysis Credits | 3 remaining | Credit system | Usage limiting | Automatic | UserDefaults (`NoumVideoAnalysisCredits`) | Local only | Monthly reset | Automatic reset | None |
| AI Analysis Count | 45 this month | Usage tracking | Fair use cap | Automatic | UserDefaults (`aiMonthlyAnalysisCount`) | Local only | Monthly reset | Automatic reset | None |

### 2.11 Gamification & Progress Data

| Field | Example | Collected Where | Purpose | Required? | Storage | Processor | Retention | Deletion | Sensitivity |
|-------|---------|----------------|---------|-----------|---------|-----------|-----------|----------|-------------|
| XP (Experience Points) | 2450 | Post-session award | Progress/rank tracking | Automatic | UserDefaults (`profileXP.{accountID}`) + synced | Backend/Firebase | Indefinite | On account deletion | None |
| Challenges | [{title, goal, current, completed}] | ChallengesManager | Engagement | Automatic | UserDefaults (`NoumChallenges`) | Local only | Indefinite | Manual/auto-cycle | None |
| Recommendation Exposures | {fingerprint, title, tappedAt} | ContentView | Improve recommendations | Automatic | UserDefaults (`recommendation.pending.{accountID}`) + synced | Backend/Firebase | Indefinite | On account deletion | Low |
| Recommendation Outcomes | {followed, scoreDelta, fillerDelta} | Post-session | Learn from user behavior | Automatic | UserDefaults (`recommendation.outcomes.{accountID}`) + synced | Backend/Firebase | Indefinite | On account deletion | Low |

### 2.12 Clubs Data

| Field | Example | Collected Where | Purpose | Required? | Storage | Processor | Retention | Deletion | Sensitivity |
|-------|---------|----------------|---------|-----------|---------|-----------|-----------|----------|-------------|
| Saved Speaking Clubs | {name, address, coords, phone, website} | MapKit local search | Help find local clubs | Optional | UserDefaults (`NoumSavedClubs`) | Apple MapKit (search), **Local only** | Indefinite | Manual removal | Low |

### 2.13 Notification Content

| Field | Example | Collected Where | Purpose | Required? | Storage | Processor | Retention | Deletion | Sensitivity |
|-------|---------|----------------|---------|-----------|---------|-----------|-----------|----------|-------------|
| Notification Body | "You said this matters because [user's motivation]. One more rep..." | NotificationManager | Re-engagement | Optional | iOS notification system (local) | **Apple only** — local notifications, no push server | Cleared by OS | Automatic | **Medium** — exposes personal goals on lock screen |

---

## 3. Third-Party Processors / Services

### 3.1 AWS (Amazon Web Services)

| Aspect | Detail |
|--------|--------|
| **Service** | Amazon Transcribe Streaming |
| **Data Received** | Real-time PCM audio stream from microphone |
| **Region** | eu-west-2 (London) |
| **Why** | Core feature: speech-to-text transcription during all practice modes |
| **Auth** | AWS Access Key ID + Secret Access Key (+ optional Session Token) |
| **Verify** | (1) Data processing agreement with AWS. (2) Transcribe data retention settings — verify audio is not stored by AWS post-transcription. (3) AWS credentials rotation and IAM policy restrictions. (4) Whether AWS Transcribe uses data for model improvement (opt-out required). |

### 3.2 OpenAI

| Aspect | Detail |
|--------|--------|
| **Services** | GPT-4o-mini (chat completions), TTS-1 (text-to-speech) |
| **Data Received** | (Chat) System prompt + user transcript + coaching context + session metrics. (TTS) Text to speak + voice instructions. |
| **Why** | AI coaching feedback generation; voice synthesis for IM mode and prompt readout |
| **Auth** | Bearer token (API key) |
| **Verify** | (1) OpenAI data usage policy — API data is not used for training by default since March 2023, but verify. (2) Data retention: OpenAI retains API inputs for 30 days for abuse monitoring. (3) Whether data is processed in EU or US. (4) DPA (Data Processing Addendum) signed. |

### 3.3 Google (Gemini AI + Cloud TTS)

| Aspect | Detail |
|--------|--------|
| **Services** | Gemini 2.5 Flash (generative AI), Google Cloud Text-to-Speech (Chirp3-HD voices) |
| **Data Received** | (Gemini) System prompt + transcript + coaching context. (TTS) Text + voice/language selection. |
| **Why** | AI coaching feedback; voice synthesis |
| **Auth** | API key (Gemini), API key or OAuth token (Cloud TTS) |
| **Verify** | (1) Google Cloud data processing terms. (2) Whether Gemini API uses data for training (check terms — Google's policy differs from Vertex AI vs. AI Studio). (3) TTS data retention policy. (4) Data location (US/EU). |

### 3.4 DeepSeek

| Aspect | Detail |
|--------|--------|
| **Services** | DeepSeek Chat (deepseek-chat model) |
| **Data Received** | System prompt + transcript + coaching context |
| **Why** | Alternative AI coaching provider |
| **Auth** | Bearer token (API key) |
| **Verify** | (1) DeepSeek is a Chinese AI company — verify data processing jurisdiction. (2) Data retention and training policies. (3) Whether this is appropriate for users subject to GDPR or other data sovereignty requirements. (4) DPA availability. **This is a significant concern if handling EU user data.** |

### 3.5 ElevenLabs

| Aspect | Detail |
|--------|--------|
| **Services** | Text-to-Speech (eleven_flash_v2_5 model) |
| **Data Received** | Text to synthesize + voice settings |
| **Why** | Premium voice synthesis for IM conversation mode |
| **Auth** | API key (xi-api-key header) |
| **Verify** | (1) ElevenLabs data processing terms. (2) Whether text input is used for voice model training. (3) Data retention policy. (4) DPA if handling EU data. |

### 3.6 Firebase (Google)

| Aspect | Detail |
|--------|--------|
| **Services** | Firebase Auth, Firestore, Remote Config, App Check |
| **Data Received** | (Auth) OAuth tokens, anonymous UIDs. (Firestore) User profiles, session data with transcripts, XP, recommendation state. (Remote Config) App reads config; Firebase logs fetch events. |
| **Why** | Authentication, cloud data sync, remote configuration |
| **Auth** | Firebase SDK (auto-managed tokens) |
| **Verify** | (1) Firebase data processing terms. (2) Firestore data location (check project settings). (3) Whether Firebase Auth logs are retained. (4) Firestore security rules are properly configured. (5) No Firebase Analytics is active (confirmed in audit). |

### 3.7 Apple Services

| Aspect | Detail |
|--------|--------|
| **Services** | Sign in with Apple, StoreKit 2, MapKit, Contacts, CoreLocation, AVFoundation, UserNotifications |
| **Data Received** | (Auth) Apple identity token, user name. (StoreKit) Purchase transactions. (MapKit) Search queries + coordinates. (Contacts) Read access. (Location) Coordinates for club search and daylight model. |
| **Why** | Platform services — auth, payments, maps, contacts, media, notifications |
| **Verify** | (1) Apple's platform data handling is governed by Apple's own terms. (2) Ensure App Store privacy nutrition labels match actual data collection. |

### 3.8 Open-Meteo

| Aspect | Detail |
|--------|--------|
| **Services** | Geocoding API, Forecast API |
| **Data Received** | Location name or lat/long coordinates |
| **Why** | Weather context for IM conversation scenarios |
| **Auth** | None (public API) |
| **Verify** | (1) Open-Meteo is open-source and free. (2) No user identifiers sent. (3) Minimal privacy risk. |

### 3.9 Noum Custom Backend (Optional)

| Aspect | Detail |
|--------|--------|
| **Services** | REST API (profile sync, session sync, XP sync, recommendation sync, IM reply, IM evaluation, TTS, account deletion) |
| **Data Received** | Full user profile, full session data including transcripts, conversation turns, XP, recommendation behavior |
| **Headers Sent** | X-Noum-Account-ID, X-Noum-Auth-Provider, X-Noum-API-Key |
| **Why** | Server-side data persistence, AI routing, TTS routing |
| **Verify** | (1) Backend hosting location and provider. (2) Backend data retention and deletion policies. (3) Backend security (encryption at rest, access controls). (4) Whether backend forwards data to additional sub-processors. (5) Account deletion endpoint properly purges all data. |

### 3.10 BBC (RSS Feeds)

| Aspect | Detail |
|--------|--------|
| **Services** | BBC RSS news feeds (for conversation context) |
| **Data Received** | None — app fetches public RSS feed |
| **Why** | Provide topical conversation context in IM mode |
| **Verify** | No user data is sent. Minimal risk. |

---

## 4. User-Facing "Your Data" Page (Draft)

---

### Your Data in Noum

**What we collect and why**

Noum helps you practice speaking. To do that well, we process certain data during your sessions and store it on your device. Here's what that means in plain terms.

**Your speech**
When you practice, your voice is captured by your microphone and converted to text in real time using a cloud transcription service (Amazon Transcribe). The audio stream is processed live and is not stored as a recording by the transcription service. The resulting text transcript is saved on your device so you can review your progress.

**Your coaching profile**
During onboarding, you share your speaking goals, challenges, and context. This helps us personalize your coaching experience. Your profile is stored on your device and, if you're signed in, synced securely to our cloud service so it's available across devices.

**AI-powered coaching**
When you use features like Coach Read or IM conversation mode, your transcript and session context are sent to an AI service (such as OpenAI or Google) to generate personalized feedback. We send only the information needed for that specific analysis. AI providers process your data according to their API terms and do not use it to train their models.

**Video recordings**
If you choose to record video during practice, the recording is saved to your device (Photos library or app storage). Video stays on your device unless you explicitly share it. If you use AI Video Analysis, a small number of still frames from your recording are sent to an AI vision service for nonverbal feedback — these frames are not stored after analysis.

**Voice playback**
In conversation mode, AI-generated responses are spoken aloud using cloud text-to-speech services. The text of the AI's message is sent to the voice provider; no audio of your voice is sent for this purpose.

**Session history and progress**
Your practice sessions, scores, XP, streaks, and coaching feedback are stored on your device. If you're signed in, this data syncs to our cloud service for backup and cross-device access.

**Friends and social features**
Friend data (names, optionally phone numbers from your contacts) is stored on your device only and is not sent to our servers.

**What we don't collect**
- We do not use any analytics or advertising SDKs
- We do not track your activity across other apps
- We do not sell or share your data with advertisers
- We do not use your data to train AI models

**Deleting your data**
You can delete your account and all associated data from Settings > Account > Delete Account. This removes your data from our cloud services and your device. Video recordings saved to your Photos library are managed by you separately.

**Contact us**
If you have questions about your data, contact us at [privacy@noum.app] (replace with actual contact).

---

## 5. Privacy Policy Outline

This outline is structured around actual data flows identified in the audit. It is not a legal document.

### I. Introduction
- App name, developer, purpose
- Effective date

### II. Data We Collect

#### A. Data You Provide
- Account information (name via Apple/Google Sign-In)
- Coaching profile (speaking goals, challenges, style preferences, free-text fields)
- Friend information (names, optionally phone numbers from contacts)
- Feedback requests (custom notes when sharing sessions)

#### B. Data Generated Through Use
- Speech transcripts (generated from voice via cloud transcription)
- Session metrics (duration, filler count, score, XP)
- AI coaching feedback (generated by third-party AI from transcripts)
- Conversation data in IM mode (turns, tone assessments, relationship state)
- Video recordings (optional, stored on device)
- Video analysis frames (optional, sent to AI for nonverbal analysis)
- Gamification data (XP, streaks, challenges, achievements)
- Recommendation interaction data (what was suggested, whether followed)

#### C. Data Collected Automatically
- Authentication tokens (transient, for sign-in)
- Device audio sample rate (for transcription configuration)
- Approximate location (only when using club finder feature, not stored)
- Subscription/purchase status (managed by Apple StoreKit)

### III. How We Use Your Data
- Provide real-time speech transcription
- Generate AI coaching feedback
- Personalize coaching based on your profile and history
- Enable social features (friends, challenges)
- Track progress (XP, streaks, session history)
- Sync data across devices (if signed in)
- Schedule practice reminders (local notifications)

### IV. Third-Party Services
- Amazon Web Services (speech transcription — eu-west-2)
- OpenAI (AI coaching, text-to-speech)
- Google Cloud (AI coaching via Gemini, text-to-speech)
- DeepSeek (AI coaching — alternative provider)
- ElevenLabs (text-to-speech)
- Firebase by Google (authentication, cloud storage, remote configuration)
- Apple (authentication, payments, maps, contacts access)
- Open-Meteo (weather data for conversation context — no user data sent)

### V. Data Storage & Security
- On-device: UserDefaults (unencrypted but sandboxed), Keychain (encrypted)
- Cloud: Firebase Firestore and/or custom backend (HTTPS, authenticated)
- API keys transmitted over HTTPS with bearer tokens
- No data encryption at rest beyond iOS sandbox protections

### VI. Data Retention
- Session data: stored indefinitely until user deletes account
- Transcripts: stored indefinitely with sessions
- Video recordings: managed by user (Photos library)
- Transient data (audio streams, OAuth tokens, video frames): not stored
- Monthly usage counters: auto-reset monthly

### VII. Your Rights & Controls
- Delete account: Settings > Account > Delete Account
- Remove friends: Settings > Friends
- Toggle notifications: Settings > Reminders
- Control video recording: opt-in per session
- AI coaching: user-initiated (Coach Read button)
- No data currently exportable (gap — see recommendations)

### VIII. Children's Privacy
- App is not directed at children under 13
- No age verification currently implemented

### IX. Changes to This Policy
- Users will be notified of material changes

### X. Contact
- [privacy@noum.app]

---

## 6. Retention / Deletion Matrix

| Data Category | Storage Location | Retention Rule | Auto-Delete? | User Can Delete? | Needs Clarification? |
|--------------|-----------------|----------------|--------------|------------------|---------------------|
| **Account credentials** | Keychain | Until account deletion | No | Yes (Delete Account) | No |
| **Auth tokens (Apple/Google)** | Memory | Transient — session only | Yes | N/A | No |
| **Coaching profile** | UserDefaults + Cloud | Until account deletion | No | Yes (Delete Account) | No |
| **Speech transcripts** | UserDefaults + Cloud | Until account deletion | No | Yes (Delete Account) | **Yes — should offer per-session deletion** |
| **Session metrics** | UserDefaults + Cloud | Until account deletion | No | Yes (Delete Account) | No |
| **AI coach feedback** | UserDefaults + Cloud | Until account deletion | No | Yes (Delete Account) | No |
| **IM conversation turns** | UserDefaults + Cloud | Until account deletion | No | Yes (Delete Account) | **Yes — contains conversational user text** |
| **IM relationship profiles** | UserDefaults + Cloud | Until account deletion (with time decay) | Partial (decay) | Yes (Delete Account) | No |
| **Video recordings** | Photos Library / Documents | Until user deletes | No | Yes (manual) | **Yes — not covered by Delete Account** |
| **Audio stream** | Not stored | Transient processing only | Yes | N/A | Verify AWS doesn't retain |
| **Video frames for AI** | Not stored | Transient processing only | Yes | N/A | Verify AI providers don't retain |
| **Friend data** | UserDefaults (local) | Until user removes friend | No | Yes (manual) | No |
| **Contact phone numbers** | UserDefaults (local, with friend) | Until friend removed | No | Yes (remove friend) | **Yes — sensitive, unencrypted** |
| **Location** | Memory | Transient — not stored | Yes | N/A | No |
| **XP / Progression** | UserDefaults + Cloud | Until account deletion | No | Yes (Delete Account) | No |
| **Challenges** | UserDefaults (local) | Until completed/expired | Partial | No explicit mechanism | Minor |
| **Recommendation data** | UserDefaults + Cloud | Until account deletion | No | Yes (Delete Account) | No |
| **Saved clubs** | UserDefaults (local) | Until user removes | No | Yes (manual) | No |
| **Monthly usage counters** | UserDefaults (local) | Monthly auto-reset | Yes | N/A | No |
| **Purchase/subscription** | Apple-managed | Managed by Apple | Apple | Via Apple | No |
| **Notification preference** | UserDefaults (local) | Indefinite | No | Settings toggle | No |
| **API keys** | Plist + Env vars | App lifecycle | N/A | N/A | **Yes — see security risks** |

---

## 7. Privacy Drift Checklist

Use this checklist whenever adding a new feature, integrating a new service, or changing data handling.

### Data Collection
- [ ] Does this feature collect any **new** user data not in the current inventory?
- [ ] Does it collect data from a **new source** (sensor, API, user input)?
- [ ] Does it store data that was previously transient?
- [ ] Does it increase the **granularity** of existing data (e.g., adding timestamps to something that didn't have them)?

### Third-Party Services
- [ ] Does this feature introduce a **new third-party service or SDK**?
- [ ] Does it send user data to an **existing service in a new way** (e.g., sending transcripts where only metrics were sent before)?
- [ ] Does the new service have a **Data Processing Agreement (DPA)** signed?
- [ ] Is the new service's **data jurisdiction** compatible with your user base (GDPR, etc.)?
- [ ] Does the service use customer data for **model training** by default?

### Storage & Retention
- [ ] Does this feature change where data is **stored** (new database, new cloud service, etc.)?
- [ ] Does it change **retention duration** (e.g., keeping data longer)?
- [ ] Does it create data that **should** have a retention limit but doesn't?
- [ ] Is the data **encrypted at rest**? Should it be?

### User Disclosure & Consent
- [ ] Does this feature require a **new permission** (camera, microphone, contacts, location, health, etc.)?
- [ ] Does it require **new user consent** before activation?
- [ ] Does the user understand what data is being collected and why? Is the **in-app disclosure** updated?
- [ ] Is the **privacy policy** still accurate?
- [ ] Does it affect **App Store privacy nutrition labels**?

### User Control
- [ ] Can the user **opt out** of this data collection?
- [ ] Can the user **delete** data created by this feature?
- [ ] Does **Delete Account** properly remove this data?
- [ ] Is the data included in any **data export** mechanism?

### Security
- [ ] Are new **API keys or credentials** properly secured (not hardcoded, not in bundled plists)?
- [ ] Is data transmitted over **HTTPS** with proper authentication?
- [ ] Is sensitive data (PII, transcripts, recordings) encrypted in transit and at rest?
- [ ] Could this feature **leak data through notifications** (lock screen visibility)?

### App Store Compliance
- [ ] Does this change affect the App Store **privacy nutrition label**?
- [ ] Is the App Tracking Transparency (ATT) framework required?
- [ ] Are all **Info.plist usage description strings** still accurate?

---

## 8. Risks & Open Questions

### CRITICAL

**R1. AWS credentials embedded in Info.plist (shipped in binary)**
The file `Info.plist` contains `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in plain text. These are compiled into the app binary and can be extracted by anyone with the .ipa. This is a security vulnerability — these credentials should be rotated immediately and replaced with a secure credential-vending mechanism (e.g., AWS Cognito Identity Pools, or vend temporary credentials from your backend).

**R2. Google API keys in bundled AIConfig.plist**
`GOOGLE_CLOUD_TTS_API_KEY` and `GEMINI_API_KEY` are live keys in a bundled plist. While Google API keys are somewhat less sensitive than AWS secrets (they can be restricted by bundle ID), they should still be protected. Verify that these keys have proper restrictions configured in the Google Cloud Console (restrict to iOS bundle identifier).

**R3. Full transcripts sent to multiple AI providers without per-transmission consent**
User transcripts — which may contain personal, professional, or sensitive content — are sent to OpenAI, Google Gemini, and/or DeepSeek for coaching feedback. The user consents to microphone use but is not explicitly informed before each AI analysis that their transcript is being sent to a third-party AI service. Consider:
- Adding clear disclosure in the Coach Read UI
- Showing which AI provider is being used
- Allowing users to opt out of AI analysis while keeping local evaluation

**R4. DeepSeek data jurisdiction concern**
DeepSeek is a Chinese AI company. If configured as the active AI provider, user transcripts and coaching profiles are sent to DeepSeek's servers. This may create data sovereignty issues for EU users (GDPR), US users subject to organizational data policies, or users in jurisdictions with data localization requirements. Recommend:
- Making DeepSeek opt-in only
- Clearly disclosing the jurisdiction
- Or removing it as a provider if you're unsure about compliance

### HIGH

**R5. No data export mechanism**
Users have no way to export their data (transcripts, session history, coaching feedback). This is required under GDPR Article 20 (Right to Data Portability) and is good practice regardless. Implement a "Download My Data" feature.

**R6. Video recordings not covered by Delete Account**
When a user deletes their account, videos saved to the Photos library are not removed (the app doesn't have delete access to Photos). Users should be clearly informed that saved videos must be deleted separately from their Photos app.

**R7. Contact phone numbers stored unencrypted**
Friend phone numbers imported from contacts are stored in UserDefaults, which is not encrypted at rest beyond iOS sandbox protections. If the device is compromised, these numbers are exposed. Consider either not storing phone numbers or using the Keychain for this data.

**R8. Personal goals/motivation in lock screen notifications**
The notification body can include the user's free-text "why now" motivation and "success vision" — e.g., "You said this matters because you have a big presentation next week." This is visible on the lock screen to anyone nearby. Recommend:
- Using generic notification text
- Or only including personal text in notification content that requires device unlock

### MEDIUM

**R9. No explicit retention policy**
Session data (including full transcripts) is stored indefinitely until the user deletes their account. There is no automatic cleanup. Consider implementing:
- Optional auto-deletion after a configurable period (e.g., 12 months)
- Session-level deletion in the UI
- Clear disclosure of "stored indefinitely" in privacy policy

**R10. Recommendation learning data could reveal behavioral patterns**
The recommendation system tracks what was suggested, whether the user followed it, and performance deltas. While individually low-sensitivity, in aggregate this creates a detailed behavioral profile. Ensure this is disclosed and included in data export.

**R11. QR code exposes account UUID**
The friend QR code format `noum://friend/{UUID}` exposes the user's account UUID. While UUIDs are not directly PII, they are persistent identifiers. Consider using rotating or expiring invite codes instead.

**R12. Firebase Firestore security rules unverified**
The audit cannot verify server-side Firestore security rules. Ensure that:
- Users can only read/write their own documents
- No cross-user data access is possible
- Admin access is properly restricted

**R13. Backend account deletion completeness unverified**
`BackendSyncManager.deleteAccount()` exists but the actual server-side implementation wasn't auditable. Verify that the backend:
- Deletes all user data from all storage systems
- Removes data from any backups within a reasonable timeframe
- Returns confirmation of deletion

### LOW

**R14. Open-Meteo location queries not logged but could be intercepted**
While no user identifier is sent to Open-Meteo, the app sends location coordinates (city name or lat/long) over HTTPS. Minimal risk, but worth noting if precise user location is considered sensitive.

**R15. BBC RSS feed fetches create server logs**
The app fetches BBC RSS feeds for conversation context. BBC's servers will log the requesting IP address. No user data is sent, but this creates a network fingerprint. Minimal risk.

**R16. Async challenges designed for future backend sync**
The challenge data model includes fields for cross-user data sharing (opponent scores, reactions). While currently local-only, the architecture is designed for cloud sync. When this is enabled, it will need its own privacy review and disclosure.

### ITEMS NEEDING MANUAL VERIFICATION

1. **AWS Transcribe data retention settings** — Verify in AWS Console that automatic content redaction is configured if needed, and that AWS is not retaining audio for service improvement (opt-out available in AWS settings).

2. **OpenAI API data retention** — Verify your OpenAI organization settings. As of early 2025, API data is retained for 30 days for abuse monitoring but not used for training. Confirm this hasn't changed.

3. **Google Gemini API data usage** — Google's terms differ between AI Studio (free tier, data may be used for training) and Vertex AI (enterprise, data not used for training). Verify which tier you're using.

4. **Firestore data location** — Check Firebase Console > Project Settings > General to confirm data location.

5. **App Store privacy nutrition labels** — Update the App Store listing to accurately reflect:
   - Data linked to identity: name, user ID, usage data, diagnostics (session metrics)
   - Data not linked to identity: N/A (all data is linked to account)
   - Data used to track you: None
   - Data collected: Contact info (optional), user content (transcripts, recordings), usage data, identifiers

6. **DPAs (Data Processing Agreements)** — Ensure you have signed DPAs with: AWS, OpenAI, Google Cloud, ElevenLabs, DeepSeek (if used). Firebase is covered under Google Cloud DPA.

---

*This document should be reviewed and updated whenever the codebase changes. Use the Privacy Drift Checklist (Section 7) as a gate for all new features.*
