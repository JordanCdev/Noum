# Noum Privacy Policy

**Last updated:** July 13, 2026

Noum ("we", "us", "our") is a speaking practice app that helps you improve your communication skills through guided exercises, AI coaching, and conversation simulations. This policy explains what data we collect, why, who processes it, and how you can control it.

---

## 1. Data We Collect

### Account Data
- **Account identifier** (Firebase UID or generated UUID) — to identify your account across sessions
- **Display name** (from Apple or Google Sign-In, if provided) — for personalization
- **Authentication provider** (Apple, Google, or Guest) — to manage your sign-in method

Noum itself does not store your email address, phone number, or password in Noum profile or session records. Apple and Google account sign-in is handled through those providers and Firebase Authentication. Guest access normally uses anonymous Firebase Authentication when it is available and completes during the bounded launch window. When Firebase Authentication is unconfigured, unavailable, or cannot complete during that window, Noum creates a local-only guest account identifier and stores it in the iOS Keychain instead of creating a Firebase Authentication user. This fallback applies to account sign-in and persistence only; cloud-backed features you choose to use may still contact the processors described in this policy.

When Google Sign-In is used, Google's bundled sign-in SDK declares that it may process linked name, email address, phone number, coarse location, user ID, device ID, other usage data, and other data types. Its manifest lists name, email address, phone number, and coarse location for app functionality; user ID and other data types for app functionality and analytics; and device ID and other usage data for analytics. The data available to that SDK depends on the Google account and sign-in flow.

It declares no tracking. The Firebase Authentication SDK manifest declares linked user ID for app functionality; Firebase Authentication, Firestore, Remote Config, and Firebase Installations SDK manifests declare unlinked other diagnostic data for analytics purposes. Firebase Remote Config also declares UserDefaults access for app functionality.

Firebase Remote Config can deliver an exact, versioned first-run experience token to an eligible new account. Noum stores the resulting content-free assignment and actual route exposure in that account's local flow log; those records contain no audio, transcript, or typed response. Missing, empty, unknown, or not-yet-active configuration does not assign an experiment, and developer, automated-test, returning, and already-started accounts are excluded from new assignment. Noum does not include a dedicated Firebase Analytics SDK or perform population experiment analysis in the app.

### Coaching Profile
During onboarding, you may provide:
- Speaking context (e.g., "work", "interviews")
- Primary goal, confidence level, biggest challenge
- Speaking style preferences
- Free-text fields: coaching brief, motivation, and success vision

This information is used to personalize your coaching experience and AI feedback.

### Speech Transcripts and Session Data
When you use a practice mode, the app:
- Streams your audio to **Deepgram**, Noum's production cloud speech-to-text provider, for real-time transcription
- Stores the resulting text transcript, filler word count, session duration, score, and practice mode on your device
- May send the transcript and relevant session evidence to a generative-AI provider when you use a cloud coaching feature, such as Coach Read, conversation simulation, or Ask Noum

For short Ask Noum voice questions, the app first uses the configured cloud transcription provider and may fall back to Apple Speech Recognition. Apple determines whether that fallback is processed on-device or by Apple for the device, language, and system configuration.

Noum does not save the streamed microphone audio as an audio file on your device or Noum's servers. Production Deepgram requests set `mip_opt_out=true`. Deepgram documents that opted-out data is retained only as needed to process the request. Apple handles any Speech Recognition fallback under Apple's own service and device-dependent processing terms.

Before Noum sends live audio, transcripts, coaching-profile fields, session context, or selected video frames to cloud speech or AI providers, the app asks for account-scoped cloud-processing permission. The disclosure identifies the data categories, purposes, and processor categories involved. If you choose **Not now** or later revoke permission, Noum does not start those cloud requests. Deterministic coaching remains available where supported, while cloud-dependent transcription, conversation, voice, and generated-coaching features may be unavailable. You can review or change this choice in **Settings > Cloud Processing**. A materially changed disclosure or processor manifest requires a new decision.

### AI Coaching Feedback
When you use a production cloud AI coaching feature, Noum sends the information needed to answer that request to **Google Vertex AI (Gemini)** through a protected Firebase callable. Developer-only provider configurations are excluded from the Release bundle and are not production processors.

If you explicitly save a suggested rewrite to your Phrase Bank, Noum stores only that saved phrase and its coaching labels on your device. It does not save an additional copy of the source transcript to the Phrase Bank, and Phrase Bank entries are included in account export and deletion.

For **Ask Noum**, this includes your current message, a bounded number of recent conversation turns, and bounded coaching context and session evidence. When available and relevant, that context may include your coaching profile and goals, recent session metrics or transcript evidence, saved proof quotes, coaching memory, plans, reflections, or an upcoming speaking moment. Noum limits the context assembled for each request; it does not send an unbounded copy of your on-device history.

In production, Ask Noum sends your current message, bounded recent conversation turns, and bounded coaching context and session evidence through a Firebase Functions endpoint. The function then sends the bounded request to Google Vertex AI (Gemini). Firebase Authentication and Firebase App Check tokens accompany that request to authenticate the caller, verify the app request, and protect the service from abuse. Firebase Functions processes the bounded request as an application-service intermediary; Noum does not use this transport for advertising or cross-app tracking.

This covers production Ask Noum messages, bounded recent turns, and bounded coaching context/session evidence sent through Firebase Functions; Firebase Authentication and App Check tokens or attestation data used to secure that transport.

Other supported production AI features may send a speech transcript and related coaching context, and may send selected video frames only when you explicitly request visual feedback. Google and Firebase process data under their API terms, privacy policies, account settings, and retention practices. Those practices can include retention for service operation, safety, abuse prevention, or legal compliance; Noum does not promise zero provider-side retention.

### Spoken AI Replies
The Release app uses Apple's on-device speech synthesizer for spoken replies and prompt readout. Developer-only cloud text-to-speech configuration is excluded from the Release bundle, so production prompt speech is not sent to a cloud text-to-speech provider.

### Video Recordings
If you enable camera recording during practice (premium feature):
- Video is recorded and stored locally on your device
- You choose whether to save it to your Photos library or the app's documents folder
- Video frames may be sent to AI providers for nonverbal coaching feedback only when you explicitly request it
- We do not upload or store your video recordings on any server

### IM Conversation Data
In conversation simulation mode, the app stores:
- All message turns (yours and the AI character's)
- Conversation state and relationship profiles
- Conversation evaluations

This data is stored on your device and optionally synced to Firebase if backend sync is configured.

### Gamification Data
- XP points, streaks, challenge progress, and speaking rank
- Stored on your device and optionally synced to Firebase

### Device Permissions
The app requests:
- **Microphone** — required for speech practice (core functionality)
- **Camera** — optional, for video recording during practice
- **Location** — optional. If you choose nearby-club search, Noum requests When In Use access. Club search configures Core Location with a one-kilometre desired accuracy and uses the resulting coordinate as the centre of a 25-kilometre Apple MapKit search. If you have already granted location access, the Path may request a location with a three-kilometre desired accuracy and ask Apple to resolve its time zone solely to align the cosmetic day/night scene. These device coordinates remain in memory and are not sent to Noum's backend or Open-Meteo.
- **Notifications** — optional, for practice reminders
- **Speech Recognition** — for optional Ask Noum voice input and Apple transcription fallback; Apple may process recognition on-device or through its service depending on system availability

---

## 2. How We Use Your Data

| Purpose | Data Used |
|---------|-----------|
| Real-time speech-to-text | Audio stream sent to Deepgram with `mip_opt_out=true`; Ask Noum voice input may use Apple Speech Recognition as a fallback |
| AI coaching feedback | Speech transcript or Ask Noum message, recent conversation turns, bounded coaching context and session evidence, and selected video frames only when an explicitly requested production visual-feedback feature supports them. Production requests pass through Firebase Functions with Firebase Authentication and App Check before reaching Google Vertex AI |
| Personalized coaching | Coaching profile, session history |
| Progress tracking | Session scores, XP, streaks, challenge completion |
| Conversation simulation | IM conversation turns and relevant relationship/context fields sent to the configured AI provider |
| Spoken replies and prompt readout | Text rendered by Apple's on-device speech synthesizer in the Release app |
| Nearby clubs and Path daylight | An optional device coordinate handled through Apple Core Location, MapKit, and geocoding APIs; Core Location is configured with a one-kilometre desired accuracy for club search and three kilometres for Path daylight |
| Conversation weather context | A city or region label inferred from the device time zone and locale, or supplied by app configuration, sent to Open-Meteo for geocoding; coordinates returned by Open-Meteo are then sent to its forecast API |
| Practice reminders | Notification preferences, coaching context (not user-authored text) |
| Account management and sync reliability | Firebase UID or a generated local guest UUID, auth provider, and optional sync data; required Google Sign-In and Firebase SDKs also perform the vendor-declared sign-in, diagnostic, security, and analytics-purpose processing described below |

We do **not** use your data for advertising, user profiling for marketing purposes, or sale to third parties.

---

## 3. Third-Party Data Processors

<!-- PROCESSOR-MANIFEST:START -->
| Service | Data Shared | Purpose | Data Terms |
|---------|-------------|---------|------------|
| **Deepgram** | Real-time audio stream with mip_opt_out=true | Production speech-to-text transcription | [Deepgram Terms](https://deepgram.com/terms) |
| **Apple Speech Recognition** | Short voice-question audio when the Apple fallback is used | Ask Noum voice transcription; processing location depends on Apple's service and device availability | [Apple Privacy Policy](https://www.apple.com/legal/privacy/) |
| **Apple Core Location / MapKit** | Device coordinate when you request nearby-club search; a location passed to Apple geocoding for Path daylight only when permission already exists | Nearby-club results and a cosmetic local day/night scene; iOS controls the location ultimately supplied | [Apple Privacy Policy](https://www.apple.com/legal/privacy/) |
| **Google Vertex AI (Gemini)** | Speech transcript or Ask Noum message, bounded recent turns, bounded coaching context and session evidence, and selected video frames only when a production feature explicitly supports and requests visual feedback | Production generated coaching and conversation responses | [Google Cloud Terms](https://cloud.google.com/terms) |
| **Google Sign-In** | The SDK vendor declaration covers linked account and device data when Google Sign-In is used | Authentication and vendor-declared service diagnostics; Noum does not use it for advertising or cross-app tracking | [Google Privacy Policy](https://policies.google.com/privacy) |
| **Firebase (Google)** | Bounded production coaching requests and Authentication and App Check proof; account identity, optional sync data, Firebase installation data, and versioned Remote Config values are processed separately for account and configuration functionality | Protected callable transport and abuse protection for cloud coaching, plus authentication, optional sync, first-run configuration, and vendor-declared diagnostics | [Firebase Terms](https://firebase.google.com/terms) |
| **Open-Meteo** | A city or region label inferred from device time zone and locale, or supplied by app configuration; then coordinates returned by Open-Meteo itself | Conversation weather context; Noum does not send a Core Location coordinate or account identifier | [Open-Meteo Terms](https://open-meteo.com/en/terms) |
<!-- PROCESSOR-MANIFEST:END -->

Noum does not include a dedicated Firebase Analytics SDK, advertising SDK, or cross-app tracking SDK. Required Google Sign-In, Firebase Authentication, Firestore, Remote Config, and Firebase Installations SDKs carry vendor-declared analytics-purpose processing as described above. Noum does not use that processing for advertising or cross-app tracking. Noum does not share data with advertising networks or data brokers.

---

## 4. Data Storage

### On Your Device
Most of your data is stored locally on your device using:
- **iOS Keychain** — account credentials (encrypted by iOS)
- **UserDefaults** — coaching profile, session history, saved Phrase Bank entries, friend names, XP, settings

### Cloud Storage (Optional)
If Firebase is configured, the following may be synced:
- Coaching profile
- Practice session history
- XP and progression data
- Recommendation state

Cloud-synced data is stored in Firebase Firestore and is associated with your account ID.

### Temporary Credentials
Production Deepgram transcription uses a short-lived provider credential obtained from Noum's backend. The app keeps the temporary credential in memory for the active service window and does not intentionally persist it to disk.

---

## 5. Data Retention

- **On-device data** is retained until you delete it (via session deletion, account deletion, or app uninstall)
- **Noum-controlled Firebase data** is retained while your account is active and is submitted for deletion when you delete your account. Shared records and operational backups may follow different deletion windows
- **Streamed audio** is not retained by Noum as an audio file. Production Deepgram requests set `mip_opt_out=true`; Deepgram says opted-out data is retained only as needed to process the request. Apple handles any Speech Recognition fallback under its own terms
- **AI-provider inputs and outputs** are handled under Google and Firebase terms, privacy policies, service tier, and account settings. Retention and model-improvement practices may change; review the links above for current details

---

## 6. Your Rights and Controls

### View Your Data
Go to **Settings > Your Data** in the app to see a summary of the principal data stored on your device and which cloud services may process it.

### Export Your Data
In **Settings > Your Data > Export account data**, Noum creates `Noum-export-YYYY-MM-DD.zip`. The archive contains a versioned manifest, one JSON snapshot for every registered local account-data participant, residual account-scoped records that are not yet owned by a named participant, and app-managed files under `Documents/Recordings` when present. Legacy records or recordings that were not stamped with an account ID are explicitly labelled as device-local and unattributed. Recordings saved to Photos, Keychain authentication material, provider credentials, and data retained by third-party processors are not included.

### Delete Individual Sessions
Long-press any session in your Session History to delete it.

### Delete Your Account
Go to **Settings > Delete Account**. This will:
- Delete account-scoped data that Noum controls from our backend and Firebase
- Remove identified per-account data from your device after remote deletion succeeds
- Delete your Firebase Authentication account, if one exists
- Sign you out

Account deletion is irreversible once completed. Noum performs deletion through an authenticated, idempotent account service and does not clear local state or claim success when the remote request fails. The service may require you to sign in again. For Sign in with Apple accounts, Noum stops before mutation unless it can safely revoke the Apple authorization; the app explains the blocker and leaves local and remote data unchanged. Deleting a Noum account does not cancel an App Store subscription, which you manage through your Apple account.

Third-party processors may retain request data for their published retention periods, safety or abuse-prevention needs, legal obligations, or configured service features. Shared challenge or league records and backups may also require separate cleanup or retention windows.

### Notification Privacy
Practice reminder notifications reference your coaching context (e.g., "Your conversation practice is waiting") but never display your personal text (goals, coaching brief, etc.) on the lock screen.

---

## 7. Children's Privacy

Noum is not directed at children under 13. We do not knowingly collect personal information from children under 13. If you believe a child under 13 has provided us with personal data, please contact us and we will delete it.

---

## 8. Security

- Apple and Google account sign-in is handled through Firebase Authentication using industry-standard OAuth flows; guest access uses anonymous Firebase Authentication when it completes during the bounded launch window or a Keychain-backed local identifier when Firebase is unconfigured, unavailable, or cannot complete during that window
- Cloud-speech credentials intended for client use are short-lived and are not intentionally persisted; broader provider secrets are not intended to be distributed in the app
- All network communication uses HTTPS/TLS
- On-device credentials are stored in the iOS Keychain (hardware-encrypted)

---

## 9. Changes to This Policy

We may update this privacy policy from time to time. We will update the "Last updated" date at the top when we make changes. Continued use of the app after changes constitutes acceptance of the updated policy.

---

## 10. Contact

If you have questions about this privacy policy or your data, contact us at:

**Email:** [noumsupport@gmail.com](mailto:noumsupport@gmail.com)

---

*This privacy policy applies to the Noum iOS app.*
