# Noum Privacy Policy

**Last updated:** April 14, 2026

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
- Streams your audio to **Amazon Web Services (AWS) Transcribe** for real-time speech-to-text conversion
- Stores the resulting text transcript, filler word count, session duration, score, and practice mode on your device
- Optionally sends the transcript to an AI provider for coaching feedback (only when you tap "Generate Coach Read")

Audio is streamed in real time and is **not stored** on your device or our servers as audio files.

### AI Coaching Feedback
When you request AI coaching analysis, your speech transcript (and optionally video frames for nonverbal feedback) is sent to one of the following AI providers:
- **Google Gemini**
- **OpenAI**

These providers process your transcript under their respective API data terms. Under their API terms, your data is **not used to train their AI models**.

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
- **Speech Recognition** — for on-device speech processing

---

## 2. How We Use Your Data

| Purpose | Data Used |
|---------|-----------|
| Real-time speech-to-text | Audio stream (sent to AWS Transcribe) |
| AI coaching feedback | Speech transcript, coaching profile, optionally video frames (sent to Google Gemini or OpenAI) |
| Personalized coaching | Coaching profile, session history |
| Progress tracking | Session scores, XP, streaks, challenge completion |
| Conversation simulation | IM conversation turns, relationship profiles |
| Practice reminders | Notification preferences, coaching context (not user-authored text) |
| Account management | Account ID, auth provider |

We do **not** use your data for advertising, user profiling for marketing purposes, or sale to third parties.

---

## 3. Third-Party Data Processors

| Service | Data Shared | Purpose | Data Terms |
|---------|-------------|---------|------------|
| **AWS Transcribe** (Amazon) | Real-time audio stream | Speech-to-text transcription | [AWS Service Terms](https://aws.amazon.com/service-terms/) — audio is not stored after processing |
| **Google Gemini** (Google) | Speech transcript, coaching profile, optionally video frames | AI coaching feedback and conversation generation | [Google API Terms](https://ai.google.dev/terms) — API data is not used for model training |
| **OpenAI** | Speech transcript, coaching profile, optionally video frames | AI coaching feedback | [OpenAI API Terms](https://openai.com/policies/api-data-usage-policies) — API data is not used for model training |
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
The app obtains short-lived AWS credentials (valid for 15 minutes) from our backend to access speech-to-text services. These credentials are held in memory only and are not persisted to disk.

---

## 5. Data Retention

- **On-device data** is retained until you delete it (via session deletion, account deletion, or app uninstall)
- **Firebase data** is retained until you delete your account
- **AWS Transcribe** does not retain audio after real-time processing
- **AI providers** (Gemini, OpenAI) process data under their API terms and do not retain it for training

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
- Delete all your data from our backend and Firebase
- Remove all per-account data from your device (coaching profile, sessions, XP, friends, AI settings)
- Delete your Firebase Authentication account
- Sign you out

Account deletion is immediate and irreversible. We do not retain any personal data after account deletion.

### Notification Privacy
Practice reminder notifications reference your coaching context (e.g., "Your conversation practice is waiting") but never display your personal text (goals, coaching brief, etc.) on the lock screen.

---

## 7. Children's Privacy

Noum is not directed at children under 13. We do not knowingly collect personal information from children under 13. If you believe a child under 13 has provided us with personal data, please contact us and we will delete it.

---

## 8. Security

- Authentication is handled by Apple and Google Sign-In via Firebase, using industry-standard OAuth flows
- AWS credentials are short-lived (15 minutes) and vended through a secure backend — no long-lived keys are stored in the app
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
