# Initiative 15 — Coach Personalization (tailored, personal Ask Noum)

Status: implemented by agents, NOT yet compiled / run / heard. The agent host has
no Swift/Xcode toolchain and no LLM/TTS API keys. Every symbol below was
grep/read-confirmed against the real code, but felt LLM quality, spoken-voice
naturalness and latency, the AVAudioSession record<->playback handoff, and all
rendered UI are unverified and can only be judged on device (iPhone 17 Pro
simulator + hardware). This document records intent, the guardrails enforced,
the exact seams touched, and the verification plan — it makes no claim that the
result looks good, sounds good, or works. Those are the human's gates.

## Why this initiative exists

Four real problems were observed on-device, all symptoms of the coach not feeling
like *your* coach:

1. **Goal change had zero pushback and no prior-goal context.** Typing a
   non-canonical word ("Engaging") made the coach narrate, in prose, "You have
   chosen 'Engaging' ... I will now tailor my feedback" — a silent, fabricated
   acceptance with no confirmation, no reference to the prior goal, no question.
2. **A chosen/changed goal was not reflected app-wide.** Profile's "Coaching
   Direction" and "Your Coach's Read" were generic delivery talk with no
   reference to the user's chosen voice. The app did not *feel* tailored.
3. **Prompts and chips were static.** Empty-state starters and the "Keep Going"
   follow-up chips were canned per-voice rather than generated from the
   conversation + recent sessions.
4. **Interacting with the coach was plain texting.** No way to speak to the coach
   and have it speak back, despite the STT (`AskNoumVoiceInput`) and cloud-TTS
   (`IMMessageSpeaker`) infra already existing.

## The proven contract (every intelligence/feedback piece follows it)

Inherited from PostRepCoachNoteService and initiatives #8/#9, applied to every
new AI path here: rich question-aware + whole-person context; explicit
per-voice register; a post-hoc grounding gate that rejects generic/ungrounded
output; a deterministic fallback for offline / non-English / no-provider (never
throw a raw error to the user); the locale gate
(`LocaleSettingsManager.shared.current.aiSupported`); numeric score untouched;
single source of truth across surfaces; new fields bounded, decode-safe,
defaulted for back-compat; pure logic unit-tested at the deterministic seams.

## Guardrails enforced for the goal-change work (non-negotiable)

- **The LLM never writes the profile.** It may only PROPOSE. The only two
  `coachingProfileStore.save` call sites reachable from chat are the two
  card-tap handlers `recordGoalSet` (AskNoumView.swift:1267) and
  `recordGoalChange` (AskNoumView.swift:1317). No new save path was introduced.
- **The system prompt structurally forbids prose acceptance.** New rule 16
  (CoachContextBuilder.swift:119-139) bans the model from ever setting,
  changing, choosing, saving, or confirming a voice, and from stating in any
  words that one was set/changed/chosen/updated/locked-in/saved. It names the
  four forbidden sentence shapes ("You have chosen X", "I've set your style to
  X", "Your voice is now X", "I'll tailor my feedback to X from now on") and
  requires the model to PROPOSE, map to the closest of the six real voices, and
  defer the commit to the card.
- **Non-canonical descriptors are handled, never invented.**
  `detectGoalIntent` (CoachContextBuilder.swift:1360) runs a primary resolve
  (`resolveRequestedVoice`, exact rawValue/title then `voiceAliases`), and when
  that misses but an explicit set/change phrase is present, a secondary
  closest-match pass (`resolveDescriptorVoice`) maps a named *quality* onto the
  nearest of the six via `voiceDescriptorAliases` (CoachContextBuilder.swift:1277-1284,
  e.g. "engaging"/"memorable" -> Storytelling, "composed"/"polished" ->
  Executive presence). An unmappable descriptor leaves the requested voice nil,
  which opens the **guided-pick palette** — one chip per real voice — never a
  fabricated voice.
- **A change names the trade-off and asks a question.**
  `goalIntentContextLines` (CoachContextBuilder.swift:1434) emits, for a
  `.change` intent, a trade-off line (name what they have been building in the
  current voice, cite reps/since-date if present) plus an instruction to ask why
  they want to change and what shifted — before they decide.
- **Switch / Blend / Keep, recorded as history.** `goalProposalChips`
  (CoachContextBuilder.swift:1556) offers Switch <new>, Blend <old>+<new>, Keep
  <old> for a resolved change target. Blend keeps the primary and adds the
  secondary (AskNoumView.swift:1308-1311 sets `chosenStyleGoal` and the
  secondary). `recordGoalChange` appends a bounded `CoachCourseChange` and
  saves a mutated copy — baseline / history / trends are never wiped.
- **Anti-thrash note.** `recentVoiceChangeCount` (CoachContextBuilder.swift:1405)
  counts confirmed voice changes in the trailing week; at/above
  `voiceThrashThreshold = 2` the GOAL block surfaces a tentative "give the
  current voice more reps" note. It is a note, never a block — the choice stays
  the user's.

## Hard invariants honored

Extend existing owners — no parallel stores, screens, or routing.
CoachingProfile/Store, SpeakingStyleGoal, AskNoumView, AskNoumVoiceInput,
AICoachChatService, CoachContextBuilder, CoachCourseChange, ProfileView's
coaching section, SummaryView, CaseReviewCard, and the existing cloud-TTS
service `IMMessageSpeaker` were all extended in place. Deliberate practice, not
gamification. Brand: no illustration/characters/melody — the speaking-state cue
is a `waveform`-family SF Symbol with variableColor motion. Coach-lens: one
coherent read across surfaces, patient but decisive. Reduced-motion respected;
accessibility labels on every new control.

## Thread 1 — Goal-change pushback (the headline change)

Files: CoachContextBuilder.swift, AskNoumView.swift, NoumTests/NoumTests.swift.

Root causes addressed: (a) `detectGoalIntent` previously fired the card only for
the six canonical voices + intent phrases, so an unknown word produced no card;
(b) the system prompt did not forbid prose goal-acceptance, so the model
fabricated it. Both are closed: the descriptor closest-match pass + guided-pick
fallback ensure a card always appears for a genuine set/change intent, and rule
16 forbids the model from claiming the change. The card remains the only commit
path.

## Thread 2 — Reflect the chosen voice app-wide

Files: PracticeSupport.swift, ProfileView.swift, SummaryView.swift,
CaseReviewCard.swift, NoumTests/NoumTests.swift.

`CoachingProfile.chosenStyleGoal` (PracticeSupport.swift:510) is the single
source of truth for "the user picked"; `hasChosenVoice` (:514) gates
tailored-vs-generic. Two new pure, nil-returning computed properties —
`chosenVoiceRegisterLabel` and `chosenVoiceCoachingLead`
(PracticeSupport.swift:717-742) — return nil when `chosenStyleGoal == nil`, so a
never-chosen profile stays on the exact existing generic copy. Profile's
"Coaching Direction" (ProfileView.swift:147), the Review card's "Your Coach's
Read" (CaseReviewCard.swift:45), and the post-rep Summary coach card
(SummaryView.swift:1828) read these helpers and fall back verbatim. No model
call, no grounding gate, no locale gate, no numeric score touched. A blend names
both voices; a secondary equal to the primary collapses to single-voice.

## Thread 3 — Dynamic prompts and chips

Files: CoachContextBuilder.swift, AskNoumView.swift, NoumTests/NoumTests.swift.

The follow-up chips were already partly dynamic; this thread closes the
remaining static surfaces. `generateAIStarterPrompts`
(CoachContextBuilder.swift:2200) is the new AI path for empty-state starters,
mirroring `generateAIFollowUpChips` exactly: locale gate -> provider gate (OpenAI
/ DeepSeek / Gemini) -> bounded request (max ~120 tokens, 8s timeout) ->
`parseAndFilterChips` grounding gate (:2823) -> nil -> deterministic fallback
(`starterPrompts`). `recentSessionDigestForChips` (:2352) supplies recent-rep
context to both paths. The grounding gate rejects over-long, chirpy, or empty
output and any leaked transcript, returning nil so the caller always shows the
static catalog rather than a dead row. The view calls both paths via `.task`
with a deterministic value visible immediately (AskNoumView.swift:764, 806-814,
722-731).

## Thread 4 — Spoken coach mode

Files: PracticeSupport.swift (IMMessageSpeaker + the playback-settings owner),
AskNoumView.swift.

S4 (foundation, isolated to TTS): `IMMessageSpeaker` now conforms to
`AVAudioPlayerDelegate` (PracticeSupport.swift:3971) with a published
`isSpeaking` (:3995) driven by the real AVAudioPlayer lifecycle. The natural
finish (`audioPlayerDidFinishPlaying`, :4442) clears the state ONLY for the
player matching the current generation token, so a barge-in or a new clip never
clears the new state; `stop()` (:4233) clears `isSpeaking` and advances the
generation token. The M25 generation-token race fix is preserved.

S5 (UX): a new `@Published askNoumSpokenRepliesEnabled` on the existing
`IMVoicePlaybackSettingsManager` (PracticeSupport.swift:3874), **default OFF**
(reads `UserDefaults.bool`, no first-run seed), persisted to a new key. The
voice-mode toggle (AskNoumView.swift:418, identifier `askNoum.voiceModeToggle`)
is only visible when `speaker.canSpeakReplies` is true (:396) — i.e. a cloud TTS
provider is configured (`canSpeakReplies`, PracticeSupport.swift:4266, gates on
Google / OpenAI / backend). Spoken playback triggers at the single reply-visible
chokepoint (AskNoumView.swift:1892-1904), gated by `AskNoumSpokenMode.shouldSpeak`
on toggle ON + locale supports AI + a real non-empty `.reply` (a `.failure`
notice is never spoken), with the tone resolved from the voice via
`coachTone(for:)`. The trailing input control gains a `.speaking` state
(AskNoumView.swift:1584) rendering a variableColor waveform Stop affordance;
tapping it, or reaching for the mic, or sending mid-speech barge-in-stops audio
(:1589 / :1596); leaving the screen stops audio (`.onDisappear`, :308). The
speaking animation is suppressed under reduced motion (`&& !reduceMotion`,
:1624). VoiceOver: the toggle reads "Spoken replies on/off"; the speaking
control carries a state label. Note: there is an AVSpeechSynthesizer offline
fallback inside `speak()`, but the toggle's *visibility* is gated on cloud
availability — so on a device with no cloud provider the toggle is hidden and
the experience stays text-only by design.

## Verification plan (human)

Unit + UI tests:

- `xcodebuild build-for-testing -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/noum-dd`
- `xcodebuild test-without-building -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/noum-dd -only-testing:NoumTests`
- `xcodebuild test-without-building -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/noum-dd -only-testing:NoumUITests/NoumUITests/testAskNoumGoalChangeSurfacesConfirmationCard`

New deterministic unit coverage includes (NoumTests.swift): goal-intent detection
(initial-set vs change, alias resolution across all six voices, non-canonical
descriptor closest-match, unmappable -> guided pick, bare-mention-without-intent
does not fire); the goal-proposal chip catalog (switch/blend/keep shapes, blend
omitted when target equals current, stable IDs + non-empty dispatch text);
anti-thrash window counting and threshold; the chosen-voice helpers (unchosen ->
nil/generic, chosen single-voice + blend copy, legacy decode back-compat, no
exclamation/emoji for any voice); the AI starter parse/fallback; and the speaker
seam (isSpeaking false after stop, stop advances generation, natural finish
fires handoff, never speaks when toggle off / locale unsupported / empty reply /
any failure).

Manual launch:

- `xcrun simctl launch booted com.noum.app UI_TESTING UI_TESTING_SEED_FORCE -DeepLink noum://ask`
- `xcrun simctl io booted screenshot /tmp/noum-ask-empty.png`
- `xcrun simctl launch booted com.noum.app UI_TESTING UI_TESTING_SEED_FORCE -DeepLink noum://profile`

Device QA (human eyes/ears — the agents cannot judge these):

1. Goal pushback reads right; non-canonical "engaging" surfaces a Storytelling
   card; the coach never claims the goal was set in prose.
2. Goal change from an existing voice shows switch/blend/keep, names the
   trade-off, asks a question; blend persists; repeated switching surfaces the
   anti-thrash note; declining changes nothing; the LLM never writes the profile.
3. Profile "Coaching Direction"/"Your Coach's Read", Summary coach card, and the
   Review card reference the chosen voice when set, read generic when unchosen,
   and change when the voice changes; the layout reads premium.
4. Chips feel dynamic + session-aware with a provider; degrade cleanly offline /
   non-English / no-sessions; no raw transcript leaks into a chip.
5. The coach speaks replies (cloud TTS) when voice mode is on; judge latency,
   naturalness, and that the chosen voice's tone is right.
6. Speaking state renders the waveform Stop; Stop and barge-in halt audio
   instantly with no bleed across turns; leaving the screen stops audio.
7. Voice-mode toggle is default OFF, persists, is hidden without a TTS provider;
   VoiceOver labels work; reduced-motion suppresses the speaking animation;
   non-English stays text-only.
8. The AVAudioSession record<->playback handoff (listening -> speaking ->
   listening) does not get stuck in the wrong category; barge-in re-acquires
   playback. This is the highest-risk on-device item — the prepareForPlayback
   one-shot guard may need a deferred relaxation; verify explicitly.

## Risks / honest caveats

- Nothing was compiled, run, or heard by the agents. Cross-file editor errors
  are module-index noise; the human's build is the real check.
- Felt LLM quality (does the pushback sound like a real coach? do the chips feel
  tailored?) and spoken-voice quality (latency, naturalness, tone match) are
  device-only.
- The AVAudioSession record<->playback handoff under barge-in is the most likely
  place for a real defect and must be exercised by hand.
- The `nonisolated` AVAudioPlayerDelegate hops to `@MainActor` capturing a
  non-Sendable player, matching the file's existing pre-Swift-6 posture; a Swift
  6 strict-mode build may warn (one-line fix available).
- `#if DEBUG`-gated seed remains a latent Release-build consideration noted in
  prior memory, untouched here.
