# Run: 2026-06-10 · branch:ux-overhaul · HEAD 4c4a46c · Review overhaul: insight-first home + searchable history + detail trust fixes

## Mode
detailed

## Changes shipped (this run)
- Noum/SessionHistoryView.swift — Review home rebuilt insight-first: ProgressionChartsCard leads (honest "forming" card under 3 scored reps/30d), ReviewCoachReadCard, "Worth a second look" highlight rows, Worth a Replay (unchanged), Session history entry card. Detail view: prompt card, transcript "Recording ended here" marker, previous-rep context line, lead-sentence Focus next, rounded duration everywhere, dead code removed.
- Noum/SessionHistoryListView.swift (new) — demoted session log: mode chips, per-mode breakdown cards, search (headline/coach line/prompt/transcript), sort (newest/highest/longest), 2+ consecutive low-signal reps collapsed into an expandable line.
- Noum/ReviewHighlightsEngine.swift (new) — pure suggested-reviews engine: breakthrough / chosen-voice fit (voiceDeliveryBonus) / recent best; ≥5 scored reps floor.
- Noum/ReviewInsightCards.swift (new) — ReviewCoachReadCard (TrendAnalyzer, medium+ confidence only) + ReviewHighlightRow.
- Noum/PracticeSupport.swift:~5750 — evaluateTimedPractice caps under-target-range reps at 7 (no more "Table-topics ready 9/10" beside "only 34s — target 45–90s").
- NoumTests/ReviewExperienceTests.swift (new) — 24 tests across cap/engine/list model/presentation/coach read.
- NoumUITests (both tours) — route to session rows via the new `history.sessionListEntry` card.

## Screenshots
- 01_home_top.png / 01_train_top.png / 01_profile_top.png / 01_settings_top.png — unchanged tabs, regression eyeball
- 01_review_top.png — NEW Review home: chart (12 reps · 30d, +2.0 last-7d delta), Coach's read, Worth a Replay below
- tour_07-review-top.png / tour_08-review-bottom.png — tour seed (1 session): honest "forming" card + Session history entry card
- tour_08b-session-history-list.png — NEW list page: lead line, chips, search field, Newest sort, rows
- tour_09-session-detail.png — detail hero + Focus next + See full review
- tour_* (others) — standard 27-surface tour, untouched areas

## VISION gap
Pillar 4 (believable progress) now has a real home on Review: chart + confidence-gated coach read + evidence-named picks. Still short of coach parity stage 4 (Adaptation): the Coach's read names trends but not *why* they moved or what intervention drove them (RecommendationLearningStore outcomes remain unsurfaced). Goal-distance (distanceFromGoal) is still not rendered anywhere on Review.

## Next steps to reach desired state
1. Cross-mode summary card for the "All" filter on SessionHistoryListView (the per-mode cards Jordan loves have no All-view sibling) — Noum/SessionHistoryListView.swift.
2. Sessions-based fallback for SuddenDeathHistoryBreakdownCard when the run store is empty but PD sessions exist (observed on owner's device 2026-06-10 video, frame 0167).
3. Surface RecommendationOutcome deltas in ReviewCoachReadCard ("the pause drill moved your filler rate −1.2/min") — closes the prescribe→observe loop visibly.
4. distanceFromGoal trend line as a chart series or chip on the Review home.

## Regressions checked
- Home / Train / Profile / Settings tab tops — 01_*.png — no regression (untouched surfaces render as before)
- Review → session detail navigation — tour pass via new entry card — works
- Growth Library deep link path (.sessionDetail by UUID) — unchanged routing, highlight rows use the same destination
- Full NoumTests: 2449/2449 green

## Surfaces needing visual verification (cloud → local queue)
- Session detail with "See full review" EXPANDED on a prompted Timed rep: prompt card, Coach Read dedupe (lead sentence vs full paragraph), transcript end marker, previous-rep line. Unit-tested but not screenshotted expanded.
- Collapsed low-signal group row (needs a seed with 2+ consecutive junk reps).
- Search + sort interaction on a 40+ session history.

## For next run
- **If cloud**: items 1–3 from next steps are logic+SwiftUI work testable without a simulator; ReviewExperienceTests is the suite to extend.
- **If local**: capture the expanded full-review detail + a collapsed junk group; hand-test search keyboard behavior on device.
