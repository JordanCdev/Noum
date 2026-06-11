# Review section feedback — video analysis (2026-06-10)

Source: `~/Desktop/noum-feedback/RPReplay_Final1781125647.MP4` (6m37s, voice-over screen recording, Review section).
Method: whisper transcription + 1fps frame extraction, each spoken segment paired to the exact on-screen UI, then grounded against the actual implementation (`Noum/SessionHistoryView.swift` + data-model inventory).

---

## TL;DR

The Review surface is a **chronological session list with one stats line** — Jordan's verdict: *"is this really a strong review?"* A human coach wouldn't hand you a logbook; they'd tell you what's improving, what isn't, and which reps prove it. The strongest thing on the page today is the one insight card ("Worth a replay"); everything else is inventory. Meanwhile the data layer already persists nearly everything needed for a real review (baselines with percentiles, trend analyzer, goal distance, recommendation outcomes, full transcripts, prompts) — almost none of it is surfaced here.

---

## Timestamped transcript ↔ screen pairing

| # | Time | What was on screen | What was said (condensed) |
|---|------|--------------------|---------------------------|
| S1 | 0:00–0:41 | Home tab bar (Train / **Review** / Profile / Settings) → Review list. Stats line `45 sessions saved · 3.4 avg score · IM Mode strongest`, filter chips, flat card list (Time Broke You 2/10, Timed 47s, Good warmup 2/10…). Held static 35s. | "We see just three pieces of information at the top… that's a cool insight, but **is this really a strong review?**" |
| S2 | 0:41–1:24 | Parked on the `WORTH A REPLAY` → `TARGETED PRACTICE` card ("'just' keeps showing up… Run Land the Pause"). | "'Worth a replay' — the part where we get the insight — is **the strongest thing here**. The scores are okay… but it's pretty weak. What I'd like to see is… I'm not sure actually." (His typed feedback answers this: visual progress, insights.) |
| S3 | 1:24–2:33 | Detail of "Time Broke You" (2/10, 15s, Fillers 0, WPM 0) → detail of "Table-topics ready" (9/10) with expanded full review → back to list where unscored reps sit above 9/10 and 10/10 reps. | "Scores like two out of ten or no score = **sessions not completed properly**. Higher scores… have additional metrics and information. **I would prioritise showing those higher scores first** — we don't want to just directly show all sessions." |
| S4 | 2:33–3:03 | Sweeping filter chips: All → Timed (has **Timed history** card: 20 reps, 3.4 avg, 3 in zone, 64 avg WPM, best rep) → Pressure Drill (**no summary card**) → IM Mode (has IM history card). | "Categories are okay. I **like that a lot — the card to summarise the timed history**. We should have that for— oh, IM history has it. That would be cool." |
| S5 | 3:03–3:57 | "Table-topics ready" detail: hero says 9/10 **and** "Your answer was only 34s — the target range is 45–90s". WPM 100 shown 3×, What Matters calls it "a strong range". Duration shows 34s in one place, 35s in another. No prompt anywhere. | "**The scoring is a bit too generous** — it was under the target range. 100 WPM… really depends on what the speech is about and the prompt. And **we don't actually get to see the prompt that was asked** — that is quite important." |
| S6 | 3:57–4:21 | Parked 24s on the Transcript card; text ends mid-sentence ("…To, like, say, a manager") with no marker or affordance. | "**It just cuts off the transcript.** I don't know if we didn't complete that or not." |
| S7 | 4:21–4:59 | Two session details → back to list: six near-identical "Good warmup 1/10" rows, one buried 8/10 "Solid response". No search, no sort. | "We should have **some sort of filtering and search** to review a particular session." |
| S8 | 4:59–5:48 | Frozen on the same flat list — date is the only organizing principle; no style/goal tagging anywhere. | "We definitely need **some sort of engine** to sort exercises in a way that helps them develop… Was this exercise a good example of them being **authoritative**? Of reaching that goal of being **humorous**?" |
| S9 | 5:48–6:36 | "Solid response" (8/10) detail: **Coach Read** card (What worked / Biggest improvement / Suggested drill). The "authoritative, king-like presence" paragraph appears **twice** (Focus next + Coach Read). Backs out to the warmup-junk list. | "We've got coach read here — a little bit lengthy, but **really good feedback**… The review section could be improved, for sure." |

Combined with the typed feedback: session/exercise counts are **profile stats, not review**; Review should show **insights, visually** (development line/bar chart of effort + progress), a **suggested-reviews engine**, a **session-history sub-section** (filterable by mode), and this is where **baselines → insights → progress-to-goal** lives. Positively encouraging, never punishing.

---

## What works — preserve these

- **"Worth a replay" / Targeted Practice** — called "the strongest thing here". The insight-density is the model for the whole page.
- **Per-mode history summary cards** (Timed history, IM history) — "I like that a lot."
- **Coach Read** — "really good feedback", screenshot-worthy. Trim, don't cut.
- **Mode filter chips** — "categories are okay to do."

---

## Ranked improvement areas

### 1. Review's identity: insight-first, not list-first ⟵ S1, S2 + typed feedback
The page leads with a logbook. A review should lead with **what a coach would say**: a development chart (effort + progress over time), what's improving, what needs work — across all modes, positively framed. Evidence of how wrong the current weighting is: the only chart that exists (`ProgressionChartsCard`, 30-day, 5 series, week-over-week deltas) renders **only on Profile**, while Review's own "History overview" + sparkline trends sit at the **bottom** of the list, collapsed by default. The raw materials are unusually good: `CommunicationBaseline` (15 dimensions, EMA, p25–p75 personal bands, 5-tier confidence), `TrendAnalyzer` (per-skill improving/declining with confidence), `DerivedReadsTrend`, `RatingStore` (50 snapshots, weekly delta). Honesty gates already exist (confidence tiers) so weak evidence can stay soft.
Per typed feedback: move "45 sessions saved"-style counters to Profile.

### 2. Suggested-reviews / development engine ⟵ S8 + typed feedback
The ask: surface sessions **by what develops the user**, tied to their chosen style goal — "your best example of being authoritative", "this rep moved you toward concise". Nothing in the UI connects sessions to goals today (generic titles, mechanical one-liners). Zero new persistence needed: `chosenStyleGoal`/`speakingStyleGoal` (CoachingProfile), `distanceFromGoal`/`measuredDistanceFromGoal` (BaselineEngine), `RecommendationLearningStore` outcomes (did the prescription move the metric — scoreDelta/fillerDelta per session), `intentFocus` vs actual metrics, `ProofMomentArchive`, `SessionReflectionStore` (felt vs measured mismatch). This is the retention/trust moment the coach-parity eval flagged as the headline blocker.

### 3. Session history → searchable sub-surface, quality-first ⟵ S3, S7 + typed feedback
Demote "all sessions" to a **Session history** card/button off the Review page. Inside it: keep mode chips, add **search + sort/filter** (score, date, mode, has-coach-read), and stop treating all reps equally — six identical "Good warmup 1/10" rows bury the one 8/10 worth revisiting. Collapse low-signal reps (score ≤2 or unscored) into a compact "N short/incomplete reps" strip instead of full cards. Data is honest here: `score == nil` reliably means saved-but-never-scored (bailed pre-summary); near-zero scores are real scored reps; sub-1s/empty reps are never persisted. Hard-coded newest-first today; no search field exists.

### 4. Scoring credibility ⟵ S5 (coaching-logic invariant)
"Table-topics ready" shows **9/10** on the same card that says the answer missed the target range (34s vs 45–90s) — "the scoring is a bit too generous" is a trust hit at the exact moment we want trust. Also: "What Matters" asserts 100 WPM is "a strong range" as fact; Jordan's point — pace judgment depends on the prompt. Score should visibly reconcile with the stated target miss (cap, or explain why it still scored high), and pace claims should soften when context is unknown.

### 5. Show the prompt in session detail ⟵ S5
`PracticeSession.prompt` is **persisted and never displayed** — zero occurrences of `prompt` in `SessionHistoryView.swift` (it already shows truncated on MistakeReplayCard rows). Without the question, neither the score nor the pace read can be sanity-checked. Cheapest high-trust fix on the list.

### 6. Transcript ending trust marker ⟵ S6
Transcript ends mid-sentence with no signal whether display truncated it or the rep ended there. Storage is full-fidelity (no truncation at rest; only AI-prompt consumers cap at 900 chars), so this is a **rendering/affordance** gap: add an explicit end-of-recording marker (and an expand affordance if long). Costs nothing, removes "did it even capture my speech?" doubt.

### 7. Per-mode summary cards everywhere ⟵ S4
The pattern he loves is inconsistent: Timed + IM showed cards on camera; **Pressure Drill showed none** (SuddenDeath/AhCounter breakdown cards exist in code but self-hide — verify the Pressure Drill filter actually maps to a card with his data); the **All view has no summary at all** — arguably the place a cross-mode "season so far" card belongs (feeds Rank 1).

### 8. Coach Read: trim + connect ⟵ S9
Keep the substance ("really good feedback"). Two fixes: (a) the same "Biggest improvement" paragraph renders **twice** on one screen (Focus next + Coach Read) — dedupe; (b) "I'm not too sure what's happened between the different sessions and this" — nothing narrates the jump from 1/10 warmups to an 8/10. A one-line "what changed since last rep" would make progress legible (TrendAnalyzer deltas already computed).

---

## Implementation notes (from code grounding)

- Review is not a tab: `HomeBottomShortcut` id `review` → `AppDestination.sessionHistory` → `SessionHistoryView` (1194 lines, also contains `SessionHistoryDetailView`). Deep links: `noum://review|history`.
- Stored-but-unsurfaced per session: pauseMetrics, pitchMetrics, vocalEnergyMetrics, grammarFindings, pressureLevel/isRated, prompt+theme, categoryRatings (SkillSnapshot), reflections, eloquence findings — all recomputable/nil-safe.
- "Worth a replay" CTA is practice-again, not review-again: it can't relaunch the same prompt (prompt source-of-truth is `@State` in TimedPracticeView) — relevant if Rank 2 wants "redo this rep".
- SkillSnapshot ledger caps at 30; long-horizon sub-rating trends need recompute from the unbounded session store.
- Audio/video recordings are not persisted — no listen-back from history; "replay" must stay metaphorical for now.
- Minor: duration renders 34s and 35s on the same detail screen (hero vs Focus chip); `imSessionStreak` + `historyBubble` are dead code in SessionHistoryView.swift.

---

## Implementation decisions (2026-06-10, same session)

Implemented on `ux-overhaul` immediately after this analysis:

1. **Rank 1** — Review home is now insight-first: `ProgressionChartsCard` (reused from Profile, 5-series + 7v7 delta) leads the page, with an honest "development picture is forming" card below the 3-scored-reps floor; then a `ReviewCoachReadCard` (top improving + top focus skill from TrendAnalyzer, medium+ confidence only, focus framed in brand blue not warning colors); then "Worth a second look" picks; then the untouched "Worth a replay" section; then a Session History entry card. Lifetime counters dropped from the page (count lives on the entry card; avg score on the list lead line; Profile already carries stats).
2. **Rank 2** — `ReviewHighlightsEngine` (new, pure): breakthrough rep (score ≥7 beating own prior-5 average by ≥2), goal example (delivery ranked by the same `voiceDeliveryBonus` read the evaluator scores with, only when `hasChosenVoice`), recent best (14d, ≥8). ≥5 scored reps required before anything surfaces; dedupe by session.
3. **Rank 3** — `SessionHistoryListView` (new sub-page): mode chips + per-mode breakdown cards moved here, plus search (headline/coach line/prompt/transcript), sort (newest / highest score / longest), and runs of 2+ consecutive low-signal reps (score ≤2, or unscored under 20s) collapsed into one expandable line. Searching disables collapsing. Single junk reps stay full rows — hiding one reads as editing history.
4. **Rank 4** — capped, not just explained: `evaluateTimedPractice` now ceilings an under-target-range rep at 7 ("Solid response" band), so "Table-topics ready 9/10" can never sit beside "only 34s — target 45–90s" again. On-target reps unaffected.
5. **Rank 5** — prompt card (with theme tag) renders in session detail whenever a prompt was captured.
6. **Rank 6** — transcript card ends with "Recording ended here · Ns".
7. **Rank 8** — Focus next shows the lead sentence of the coach paragraph (full text stays in Coach Read — no more double render); hero carries a neutral "Previous <mode> rep: X/10 · date" context line. Duration now rounds identically everywhere (34s/35s mismatch fixed). Dead `imSessionStreak`/`historyBubble` removed.

**Deferred (follow-ups):** listen-back replay (audio isn't persisted); "Worth a replay" relaunching the exact prompt.

**Landed 2026-06-11 (`7660a13`):** Rank 7 both halves — `CrossModeHistoryBreakdownCard` (reps + avg score + 7-day trend per mode on the "All" filter, rows tap through to the mode's filter chip) and a sessions-based fallback on `SuddenDeathHistoryBreakdownCard` (rep count / avg score / best rep from `PracticeSession` rows when the run store is empty but PD sessions exist — the exact state on the owner's device in the feedback video).
