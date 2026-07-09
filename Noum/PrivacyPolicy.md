# Noum Privacy Policy

**Last updated:** July 9, 2026

Noum ("we", "us", "our") is a speaking practice app that helps you improve your communication skills through guided exercises, AI coaching, and conversation simulations. This policy explains what data we collect, why, who processes it, and how you can control it.

---

## 1. Data We Collect

### Account Data
- **Account identifier** (Firebase UID or generated UUID) — to identify your account across sessions
- **Display name** (from Apple or Google Sign-In, if provided) — for personalization
- **Authentication provider** (Apple, Google, or Guest) — to manage your sign-in method

We do not collect your email address, phone number, or password. Authentication is handled entirely by Apple Sign-In, Google Sign-In, or anonymous guest sessions through Firebase Authentication.

### Coaching Profile
During onboarding, you may provide:
- Speaking context (e.g., "work", "interviews")
- Primary goal, confidence level, biggest challenge
- Speaking style preferences
- Free-text fields: coaching brief, motivation, and success vision

This information is used to personalize your coaching experience and AI feedback.

### Speech Transcripts and Session Data
When you use a practice mode, the app:
- Streams your audio to the configured speech-to-text provider for real-time transcription. The shipping providers are **Deepgram** (the default), **Amazon Web Services (AWS) Transcribe**, and **Google Cloud Speech-to-Text**
- Stores the resulting text transcript, filler word count, session duration, score, and practice mode on your device
- May send the transcript and relevant session evidence to a generative-AI provider when you use a cloud coaching feature, such as Coach Read, conversation simulation, or Ask Noum

For short Ask Noum voice questions, the app first uses the configured cloud transcription provider and may fall back to Apple Speech Recognition. Apple determines whether that fallback is processed on-device or by Apple for the device, language, and system configuration.

Noum does not save the streamed microphone audio as an audio file on your device or Noum's servers. Speech-to-text providers process the stream under their own terms and retention practices.

### AI Coaching Feedback
When you use a cloud AI coaching feature, Noum sends the information needed to answer that request. Depending on the feature, configuration, and fallback routing, a request may be processed by one or more of the following providers:
- **Google Gemini**
- **Anthropic Claude**
- **OpenAI**
- **DeepSeek**

For **Ask Noum**, this includes your current message, a bounded number of recent conversation turns, and bounded coaching context and session evidence. When available and relevant, that context may include your coaching profile and goals, recent session metrics or transcript evidence, saved proof quotes, coaching memory, plans, reflections, or an upcoming speaking moment. Noum limits the context assembled for each request; it does not send an unbounded copy of your on-device history.

Other AI features may send a speech transcript and related coaching context, and may send selected video frames when you explicitly request nonverbal feedback. Providers process data under their own API terms, privacy policies, account settings, and retention practices. Those practices vary and can include temporary or longer retention for service operation, safety, abuse prevention, or legal compliance; Noum does not promise zero provider-side retention.

### Spoken AI Replies
When spoken replies or prompt readout are enabled, the text to be spoken may be sent to **Google Cloud Text-to-Speech**. If that service is unavailable or not configured, **OpenAI Text-to-Speech** may be used as the cloud fallback. An Apple on-device voice may be used as a terminal fallback on supported devices; that fallback does not send the text to Google Cloud or OpenAI for synthesis.

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
- **Contacts** — optional, only if you choose to add friends from your contacts (only names are imported; phone numbers are not stored)
- **Notifications** — optional, for practice reminders
- **Speech Recognition** — for optional Ask Noum voice input and Apple transcription fallback; Apple may process recognition on-device or through its service depending on system availability

---

## 2. How We Use Your Data

| Purpose | Data Used |
|---------|-----------|
| Real-time speech-to-text | Audio stream (sent to Deepgram, AWS Transcribe, or Google Cloud Speech-to-Text; Ask Noum voice input may use Apple Speech Recognition as a fallback) |
| AI coaching feedback | Speech transcript or Ask Noum message, recent conversation turns, bounded coaching context and session evidence, and optionally selected video frames (sent to configured Google, Anthropic, OpenAI, or DeepSeek services) |
| Personalized coaching | Coaching profile, session history |
| Progress tracking | Session scores, XP, streaks, challenge completion |
| Conversation simulation | IM conversation turns and relevant relationship/context fields sent to the configured AI provider |
| Spoken replies and prompt readout | Text to be spoken (sent to Google Cloud Text-to-Speech or OpenAI Text-to-Speech when cloud speech is used) |
| Practice reminders | Notification preferences, coaching context (not user-authored text) |
| Account management | Account ID, auth provider |

We do **not** use your data for advertising, user profiling for marketing purposes, or sale to third parties.

---

## 3. Third-Party Data Processors

| Service | Data Shared | Purpose | Data Terms |
|---------|-------------|---------|------------|
| **Deepgram** | Real-time audio stream | Default speech-to-text transcription | [Deepgram Terms](https://deepgram.com/terms) |
| **AWS Transcribe** (Amazon) | Real-time audio stream | Speech-to-text transcription | [AWS Service Terms](https://aws.amazon.com/service-terms/) |
| **Google Cloud Speech-to-Text** | Real-time audio stream | Speech-to-text transcription | [Google Cloud Data Processing and Security Terms](https://cloud.google.com/terms/data-processing-terms) |
| **Apple Speech Recognition** | Short voice-question audio when the Apple fallback is used | Ask Noum voice transcription; processing location depends on Apple's service/device availability | [Apple Privacy Policy](https://www.apple.com/legal/privacy/) |
| **Google Gemini / Google Cloud Agent Platform** | Speech transcript or Ask Noum message, recent turns, bounded coaching context/session evidence, optionally selected video frames | AI coaching feedback and conversation generation | [Gemini API Terms](https://ai.google.dev/gemini-api/terms) |
| **Anthropic Claude** | Ask Noum message, recent turns, bounded coaching context/session evidence | Ask Noum coaching replies and fallback processing | [Anthropic API Retention](https://privacy.anthropic.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data) |
| **OpenAI** | Speech transcript or Ask Noum message, recent turns, bounded coaching context/session evidence, optionally selected video frames; text for speech synthesis | AI coaching feedback, conversation generation, and fallback text-to-speech | [OpenAI API Data Controls](https://platform.openai.com/docs/models/default-usage-policies-by-endpoint) |
| **DeepSeek** | Speech transcript or Ask Noum message, recent turns, bounded coaching context/session evidence | AI coaching feedback and fallback conversation generation | [DeepSeek Privacy Policy](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html) |
| **Google Cloud Text-to-Speech** | Text prompts for voice synthesis | AI character voices in conversation mode | [Google Cloud Terms](https://cloud.google.com/terms) |
| **Firebase** (Google) | Account ID, display name, optionally synced profile/session data | Authentication and optional cloud sync | [Firebase Terms](https://firebase.google.com/terms) |
| **Open-Meteo** | Approximate location (via IP, not GPS) | Weather context for conversation topics | Public API, no authentication, no personal data sent |

No data is shared with analytics providers, advertising networks, or data brokers.

---

## 4. Data Storage

### On Your Device
Most of your data is stored locally on your device using:
- **iOS Keychain** — account credentials (encrypted by iOS)
- **UserDefaults** — coaching profile, session history, friend names, XP, settings

### Cloud Storage (Optional)
If Firebase is configured, the following may be synced:
- Coaching profile
- Practice session history
- XP and gamification data
- IM relationship profiles

Cloud-synced data is stored in Firebase Firestore and is associated with your account ID.

### Temporary Credentials
Some speech-to-text paths use short-lived provider credentials obtained from Noum's backend. Their lifetime and scope depend on the selected provider. The app keeps these temporary credentials in memory for the active service window and does not intentionally persist them to disk.

---

## 5. Data Retention

- **On-device data** is retained until you delete it (via session deletion, account deletion, or app uninstall)
- **Noum-controlled Firebase data** is retained while your account is active and is submitted for deletion when you delete your account. Shared records and operational backups may follow different deletion windows
- **Streamed audio** is not retained by Noum as an audio file. Speech-to-text providers handle the stream under their own service terms and retention practices
- **AI-provider inputs and outputs** are handled under the selected provider's terms, privacy policy, service tier, and account settings. Retention and model-improvement practices differ across Google, Anthropic, OpenAI, and DeepSeek and may change; review the links above for current details

---

## 6. Your Rights and Controls

### View Your Data
Go to **Settings > Your Data** in the app to see a summary of all data stored on your device and which cloud services process your data.

### Export Your Data
In **Settings > Your Data > Export All My Data**, you can export all locally stored data as a JSON file.

### Delete Individual Sessions
Long-press any session in your Session History to delete it.

### Delete Your Account
Go to **Settings > Delete Account**. This will:
- Delete account-scoped data that Noum controls from our backend and Firebase
- Remove all per-account data from your device (coaching profile, sessions, XP, friends, AI settings)
- Delete your Firebase Authentication account
- Sign you out

Account deletion is irreversible. Noum removes per-account data from the device and starts deletion of account-scoped backend records it controls. Third-party processors may retain request data for their published retention periods, safety or abuse-prevention needs, legal obligations, or configured service features. Shared challenge or league records and backups may also require separate cleanup or retention windows.

### Notification Privacy
Practice reminder notifications reference your coaching context (e.g., "Your conversation practice is waiting") but never display your personal text (goals, coaching brief, etc.) on the lock screen.

---

## 7. Children's Privacy

Noum is not directed at children under 13. We do not knowingly collect personal information from children under 13. If you believe a child under 13 has provided us with personal data, please contact us and we will delete it.

---

## 8. Security

- Authentication is handled by Apple and Google Sign-In via Firebase, using industry-standard OAuth flows
- Cloud-speech credentials intended for client use are short-lived and are not intentionally persisted; broader provider secrets are not intended to be distributed in the app
- All network communication uses HTTPS/TLS
- On-device credentials are stored in the iOS Keychain (hardware-encrypted)

---

## 9. Changes to This Policy

We may update this privacy policy from time to time. We will update the "Last updated" date at the top when we make changes. Continued use of the app after changes constitutes acceptance of the updated policy.

---

## 10. Contact

If you have questions about this privacy policy or your data, contact us at:

**Email:** [your-email@example.com]

---

*This privacy policy applies to the Noum iOS app.*
