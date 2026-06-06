# M19 — Coach Workflow Gap Audit

_What a £130/hr human communication coach does across an engagement — and where Noum diverges._

---

## Phase 1 — Intake Interview

**What a human coach does**

The first 30–60 minutes is entirely discovery. The coach asks: Why are you here? What's the one Big Moment on the horizon — a board pitch, a job interview, an exec read-out — that is making this feel urgent? What's your fear, not your abstract goal? They ask the client to send recordings of past performance — a video of a previous talk, a Zoom clip, anything. They may ask for 360-degree feedback from a manager or peer. They build a picture of context, stakes, and failure pattern before prescribing anything. The intake is the contract: everything the coach does for the next 12 weeks is referenced back to what they learned in this hour.

**What Noum does today**

Onboarding captures `CoachingProfile` in multi-choice screens: speaking context, confidence level, biggest challenge, desired outcome, speaking style goal (`PracticeSupport.swift:368–415`). Three free-text questions follow post-rep via `DeferredProfileCapture.swift:24–112`: "What do you want to get better at?" at session 1, "Why does this matter right now?" at session 3, "If this improves, what changes?" at session 7. These map to `coachingBrief`, `motivationWhyNow`, and `successVision` fields on `CoachingProfile`. No recording intake. No stakeholder framing. No explicit Big Moment question.

**The gap**

The onboarding asks the right questions but in a passive, self-reported multiple-choice format with no open-ended follow-up and no record of the specific upcoming Moment that makes this urgent. The Big Moment — the pitch next Tuesday, the promotion panel in six weeks — is the most motivationally load-bearing piece of the intake interview and Noum never captures it. `motivationWhyNow` gets close but it's a free-text box shown at session 3 with no prompt to name a specific event or deadline. The coach has no record of what the client is building toward.

**Effort-to-impact: S effort × High impact.** A single optional "What's the next big moment?" field added to the goal capture flow (or as a `DeferredProfileCapture.Prompt` case at session 2) would give the AI context to make every reply feel personally high-stakes rather than generic. No new infrastructure needed; `CoachContextBuilder.userContext` already has a GOAL section that would surface it.

---

## Phase 2 — Diagnostic

**What a human coach does**

After intake, the coach asks the client to do a short "show me" recording — two minutes on any topic. The coach listens for 2–3 highest-leverage issues, ranked by impact. Not a checklist; a judgment call. "You bury your headline. Your opening filler cluster is masking your authority. Your pace fights your credibility — you're actually fast when you're confident, which inverts the signal." They name the levers, rank them, and make them visible to the client. The diagnostic is the foundation of the plan; without it, the plan is generic.

**What Noum does today**

The first session produces real diagnostic data: filler rate, pace (WPM), pause metrics, and a session score. `BaselineEngine` starts building the baseline after session 1 and confidence ratings improve with each session (`PracticeSupport.swift`, `BaselineEngine.swift`). `TrendAnalyzer.primaryFocus` identifies the single highest-leverage focus area (`TrendAnalyzer.swift:357–465`). `AIInsightsService` generates a session debrief narrative post-rep. The `WhatYouDidWellCard` and `WhatToImproveCard` (introduced in M17) present prioritised findings after each rep. This is genuinely strong coverage for a tool that can't ask the user to "show me."

**The gap**

Noum's diagnostic is continuous (re-runs after every session) rather than explicit (a named "this is your read" moment). The user never receives a single, clear "here are your two or three levers" statement that they can hold onto across multiple weeks. The `WhatToImproveCard` surfaces per-rep improvements but doesn't synthesise across sessions into a stable lever statement. The `CoachContextBuilder.userContext` TRENDS section does name persistent blockers (`PracticeSupport.swift`, `BaselineStore`), but the AI chat surface doesn't proactively surface these as "your diagnostic" — it waits for the user to ask.

**Effort-to-impact: S effort × Med impact.** The data is there. A "Your current two levers" card on the home screen or profile (reading from `baseline.persistentBlockers` when confidence is sufficient) would make the diagnostic visible without new infrastructure. The existing `HomeCoachCard` subtitle or the `VoiceMetricsCard` could carry this.

---

## Phase 3 — Individualized Plan

**What a human coach does**

After the diagnostic, the coach writes (or co-writes with the client) a 4–12 week plan. It has milestones calibrated to the client's Big Moment and lever priorities — not a menu of exercises but a sequence: "Weeks 1–2: eliminate opening filler cluster. Weeks 3–4: headline-first structure. Weeks 5–6: pressure rehearsal against your actual objections." The plan has a shape: early weeks build the foundation, later weeks load it under pressure, the final week is capstone rehearsal. The client knows what they're working toward and in what order.

**What Noum does today**

The path system (`PathProgressManager.swift`, `PathNode.swift`) provides a progression of 20+ nodes with concrete unlock criteria (`scoreAtLeast`, `cleanRunsInWindow`, `modeMasteryLevel`, `totalLessonCrowns`). The home shows the current node title and gating phrase. The AI chat (`AskNoumView.swift`) can generate a day-by-day plan when asked — the system prompt explicitly instructs the model to produce "a concrete day-by-day sequence (Mon: X, Tue: Y)" when the user requests a practice plan (`CoachContextBuilder.swift:81–86`). Goal-aware drill selection in `TrendAnalyzer.primaryFocus` adds a priority bonus on goal-aligned skills. This is non-trivial coverage; the path is a real plan, not decoration.

**The gap**

The path plan is generic across all users — every user progresses through the same node sequence regardless of their Big Moment, specific challenge, or lever priority. A user working toward a board pitch and a user working toward daily-meeting confidence unlock the same nodes in the same order. There is no "your plan for the next 4 weeks, built around your goal and your two levers." The AI chat can produce this on request but the user has to ask, and most won't. The individualized plan is the most user-retaining artifact the coach produces; Noum offers the infrastructure (path + AI) but not the artifact.

**Effort-to-impact: L effort × High impact.** Building a user-specific plan surface that composes path node milestones + lever priorities + Big Moment deadline into a human-readable 4-week roadmap is a meaningful feature. The data inputs exist; the composition layer and the surface don't.

---

## Phase 4 — Drill Prescription

**What a human coach does**

Between sessions, the coach prescribes specific homework targeting the lever. Not "practice speaking." Specifically: "Every morning for 2 weeks, record yourself opening the 3 hardest objections from your sales process. No fillers. One take, no re-recording." The prescription names the mode, the rep count, the success threshold, and the duration. It is never one-size-fits-all; the same lever (filler reduction) gets different drills for an exec (Sudden Death with their actual board scenarios) vs a nervous new hire (Timed with easy prompts, building reps).

**What Noum does today**

This is Noum's strongest phase. `RecommendationBiasEngine` (`PracticeModeSelectionView.swift`) drives the recommended mode. `TrendAnalyzer.primaryFocus` ranks skills by improvement leverage and applies a goal-alignment bonus (`TrendAnalyzer.swift:366–465`). `WhatToImproveCard` includes a drill CTA tied to the session's top lever. The mini-drills (`BeatTheBrakeView`, `LandThePauseView`, `PREPStackView`) target specific skills. `DailyChallengeTile` provides rotating daily drill missions. The AI coach in chat recommends specific drills tied to the user's data when asked. Multiple practice modes (Timed, Sudden Death, Ah-Counter, IM) offer genuinely differentiated pressure profiles. The `CoachContextBuilder` system prompt instructs the model to "end most replies with one concrete next move."

**The gap**

Drill prescription is reactive (the user opens the app and Noum suggests) rather than proactive (the user receives a drill assignment before they open the app). A human coach's prescription carries the accountability of a homework assignment; the user committed to it in a session. Noum's suggestion is available but optional — there's no "here's your drill for the next three days, and I'll ask you about it" loop. The prescription also doesn't adapt to the user's schedule or streak pattern (no "you practice 4 days a week, so here's 4 reps with a Monday reset").

**Effort-to-impact: M effort × Med impact.** A "this week's drill" card on the home screen — computed from the current lever + mode recommendation + streak pattern, visible for 3–5 days, then refreshed — would tighten the prescription loop without requiring backend notification infrastructure. The existing `HomeSignalGate` already gates cards by signal; adding a time-bounded drill assignment card is additive.

---

## Phase 5 — Check-In

**What a human coach does**

Weekly or bi-weekly session. The client brings recordings and progress. The coach gives specific feedback tied to the plan: "You're clean on the opening filler. Now I'm hearing it cluster in your transition sentences — you're fine when you hold the floor, it's the handoffs that break." They reference the Big Moment explicitly: "Three weeks until the pitch — at your current pace you'll be clean on fillers; your pace is still too fast for the board context." The check-in is not a new lesson; it's a progress review against the known plan.

**What Noum does today**

The `AIWeeklyInsightCard` provides a weekly AI narrative covering trends (`AIInsightsService.weeklyNarrative`). The `AskNoumView` acts as an on-demand check-in surface — the user can bring a question and the coach reads the context block to provide session-specific feedback. Post-rep, `WhatYouDidWellCard` and `WhatToImproveCard` give immediate rep-level feedback. The `GrowthLibraryView` lets the user browse their proof moments over time. `SessionHistoryDetailView` gives a full transcript + AI debrief for any past session.

**The gap**

The weekly insight is generated, not conversation-initiated. A real check-in is bidirectional: the coach asks the client to bring something ("what did you record this week?"), the client surfaces it, the coach responds to what's actually there. Noum's check-in is one-directional — the AI reads the data and narrates, but it doesn't actively prompt the user to reflect or bring something. More critically, the check-in never explicitly references the user's Big Moment or the remaining time to it. "You have 3 weeks until your pitch" is the most motivating framing a check-in can carry; Noum has no awareness of when the Big Moment is.

**Effort-to-impact: M effort × High impact.** A weekly push notification that references the user's goal and a specific metric trend ("Your filler rate dropped 30% this week — here's what's working") would convert the weekly insight from passive to active. The notification plumbing exists (`NotificationManager.swift:scheduleWeeklyDigest`); the content is currently generic. Personalizing it to the user's current lever trend + streak is the gap.

---

## Phase 6 — Adapt

**What a human coach does**

The coach shifts the plan based on what's working and what isn't. If a lever resolves faster than expected, they escalate: "You've cracked filler control — now we're working on stage presence." If the client is regressing, they de-escalate: "Let's go back to fundamentals. You're overcorrecting for pace and losing naturalness." The plan is a living document, not a contract. The coach tracks the client's improvement trajectory and makes explicit plan changes that the client understands and consents to.

**What Noum does today**

`TrendAnalyzer` re-analyzes patterns every session and `TrendAnalyzer.primaryFocus` shifts focus when the top lever changes (`TrendAnalyzer.swift:357–465`). `BaselineEngine` continuously updates its confidence ratings and identifies resolved blockers. The `RecommendationBiasEngine` re-weights mode suggestions as mastery improves. `ModeMastery` tracks per-mode progress and gates recommendations (`PracticeSupport.swift`). The path node system escalates difficulty via concrete unlock criteria. Adaptation happens automatically and continuously.

**The gap**

Adaptation is silent. The user never hears "I've shifted your focus from fillers to pace because your filler rate is now stable." The automatic re-weighting in `TrendAnalyzer.primaryFocus` is real, but invisible. A human coach marks plan changes explicitly because the client's understanding and buy-in is part of the intervention. When Noum's focus shifts, the user may notice a different suggestion in the `WhatToImproveCard` but there's no "I've updated your focus" moment. This matters more when a lever regresses — the silent shift back to fundamentals could read as inconsistency rather than intentional recalibration.

**Effort-to-impact: S effort × Med impact.** A one-line "Your focus has shifted" note in the `AIWeeklyInsightCard` when `TrendAnalyzer.primaryFocus` changes from one session-window to the next — citing the resolved skill and the new priority — would make the adaptation visible without new infrastructure. The data is already computed; surfacing the change is a copy and rendering task.

---

## Phase 7 — Capstone

**What a human coach does**

In the final session(s) before the Big Moment, the coach does simulation rehearsal. Not a generic rep — the actual talk, pitch, or interview, delivered under realistic pressure. "You've got 12 minutes. Go." The coach plays the hard audience, asks the brutal follow-up question, puts the client in the exact pressure scenario they'll face. Post-rehearsal debrief is specific: "You lost composure on the third question. Here's the reframe." The capstone is the entire engagement compressed into one session: the original lever, the plan, the progress, and the final calibration for the real event.

**What Noum does today**

The `IMPracticeView` (AI conversation reps with tone and scenario control) is the closest analog to simulation rehearsal — it generates adversarial questions based on the prompt and tracks the user's composure under follow-up pressure. Sudden Death with hard difficulty is the most pressure-faithful practice mode. The `SpeechProject` system (8 Toastmasters-style structured speeches with concrete objectives) provides a capstone structure for prepared-speech contexts. The AI coach in `AskNoumView` can serve as a pre-event debrief surface when prompted.

**The gap**

There is no "capstone mode" that is explicitly tied to the user's Big Moment, triggered by proximity to a named deadline, or structured as a simulation of a specific upcoming event. A user could use IM mode to rehearse a board pitch, but they'd have to set it up themselves and the mode doesn't know the pitch is coming. The `SpeechProject` system is structurally strong but generic — the project doesn't adapt to the user's actual presentation content or stakes. There is no "three days before your event — here's your pre-moment protocol" flow.

**Effort-to-impact: L effort × High impact.** Building a true capstone mode requires capturing the Big Moment (Phase 1 gap), tracking proximity to it, and constructing a simulation rep that references the user's actual scenario. This is a multi-phase feature. The minimum viable version — a "Prep for a specific moment" entry in the practice picker that names the event, sets a rep target for the week, and triggers an IM-mode rep with the event as context — is smaller but still M effort.

---

## The 3 Highest-Leverage Gaps to Close

### Gap 1 — No Big Moment capture (Phase 1 → Phase 7 chain)

**Why highest leverage:** Every other coaching phase references the Big Moment. The intake builds around it. The plan sequences toward it. The check-in counts down to it. The capstone rehearses it. Without capturing a specific upcoming event and deadline, Noum's coaching can only be generic. The AI chat can say "you have a board pitch — here's how to prep" if the user types it, but the system has no ambient awareness of what the user is building toward. A single field — "What's coming up?" with an optional date — would propagate motivational specificity across every AI-generated surface: weekly insights, drill assignments, check-in copy, and eventually a capstone prompt.

**Minimum-viable shape:** Add a `BigMomentRecord` (event description, optional date) to `CoachingProfile`. Capture it as an optional `DeferredProfileCapture.Prompt` case at session 2 ("What's coming up that makes this feel urgent?"). Surface it in `CoachContextBuilder.userContext` as a BIG MOMENT section (between GOAL and RATING). When present and within 14 days, `AIWeeklyInsightCard` + `NotificationCopy` reference it by name and countdown.

**Files likely involved:** `PracticeSupport.swift` (CoachingProfile), `DeferredProfileCapture.swift` (new Prompt case), `CoachContextBuilder.swift` (new context section), `NotificationCopy.swift`, `AIWeeklyInsightCard.swift`.

---

### Gap 2 — Plan is invisible (Phase 3)

**Why highest leverage:** The path is the plan but the user can't see it as "my plan for the next 4 weeks." The path node sequence is generic. The AI can generate a custom day-by-day plan on request but the user has to ask, the plan isn't persisted, and it doesn't reference path milestones. This is a retention lever: users who can see "here's what I'm working on and in what order" have a reason to return that users who just "do reps" don't.

**Minimum-viable shape:** A "Your plan" section in the Profile view (or a dedicated sub-view) that composes the next 3 path nodes + the current primary lever + the Big Moment deadline into a human-readable 4-line summary: "Your focus this week: filler control. Your next unlock: [node title] in [X reps]. Your goal: [paraphrasedGoal]. Your moment: [event, X days away]." No new AI calls — pure composition from existing data in `PathProgressManager`, `TrendAnalyzer.primaryFocus`, `CoachingProfile`, and the proposed `BigMomentRecord`.

**Files likely involved:** `ProfileView.swift`, `PathProgressManager.swift`, `TrendAnalyzer.swift`, `CoachingProfile` (new BigMomentRecord field), possibly a new `YourPlanCard.swift`.

---

### Gap 3 — Adaptation is silent (Phase 6)

**Why highest leverage:** This is the gap with the lowest build cost and the highest trust impact. When Noum's focus shifts — because a blocker resolved or a new pattern emerged — the user experiences it as the coach changing its mind without explanation. Making the shift explicit ("Your filler rate is now stable — shifting focus to pace") converts a potential confusion signal into a proof-of-intelligence moment. It's also the inverse of the anti-goal "fake certainty from small sample sizes" — explicitly naming when a conclusion has changed is a trust move.

**Minimum-viable shape:** In `AIWeeklyInsightCard`, compare the current `TrendAnalyzer.primaryFocus` result against a persisted `lastWeekPrimaryFocus` key (stored in UserDefaults per-account). When they differ, prepend a one-sentence shift notice: "Your filler rate is now stable. This week's focus shifts to pace." The same delta could feed a line in `NotificationCopy.scheduleWeeklyDigest`. Zero new architecture; one new `UserDefaults` key and 20 lines of conditional copy.

**Files likely involved:** `AIWeeklyInsightCard.swift`, `TrendAnalyzer.swift` (or caller), `NotificationCopy.swift`, `UserDefaults` key in `SessionFinalizer.swift` or `AIInsightsService.swift`.
