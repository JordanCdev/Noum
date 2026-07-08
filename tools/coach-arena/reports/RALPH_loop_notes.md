# RALPH loop notes — run_2026-07-08_10-04-47 (READ-ONLY analysis)

---

## ⚠️ EVAL-HONESTY BANNER — READ BEFORE TRUSTING ANY NUMBER HERE

**This run is REPLAY mode = cached captures, NOT live generation from the current prompt.**

- Provider `replay` replays fixed, previously-captured coach replies. The captures were
  produced by an earlier generation draw, not by today's `CoachContextBuilder.swift` /
  `AICoachChatService.swift`.
- **Any prompt/code edit made in this loop CANNOT be measured by re-running replay** —
  the captures are frozen. Re-running replay after an edit will reproduce the SAME reply
  and the SAME score. A replay delta is 100% judge-panel drift, not your change.
- The headline replay numbers (gold 70.2, deep 76.7, trust 73.3, floor 22, sub-70 16,
  leaks 2) reflect **capture provenance and the judge panel that graded them**, not the
  behavior of today's code.
- **Do NOT let anyone attribute a score delta to this loop's edits from a replay re-run.**
  That is exactly the "headline `latest.json` delta" fraud the honesty rules forbid.
- A real before/after needs ONE of:
  1. a live production-parity run (`ARENA_PROVIDER=anthropic` + `ANTHROPIC_API_KEY`), or
  2. a same-era **DUAL-ARM blind A/B** — regenerate BOTH arms in one session, one blind
     judge scores both, isolating the change from judge drift AND generation-era variance.
- Generation variance reminder: **old-arm scores swing ±5/fixture between draws** (proven
  iters 5–6). Anything under ~5 pts of movement is likely noise, not signal.

This turn is READ-ONLY analysis only. No harness run, no fixture/rubric/judge edits.

---

## 1. RANKED REMAINING FAILURES (16 sub-70)

Rank order: reliability-capped first, then lowest score ascending.
`movable-by`: **prompt** = rule wording | **strip** = deterministic strip layer |
**fixture** = expectation looks stale/over-constrained | **structural** = CONTEXT block /
not prompt-movable | **noise** = within ±5 of the 70 line, likely a draw artifact.

| # | Fixture | Category | Score | Deterministic cap / finding | One-line root cause | Movable-by |
|---|---|---|---|---|---|---|
| 1 | cold-start-no-data | cold-start | **22** | **CAP placeholderOrBroken ≤30** · coldStartProductJargon("Ah-Counter") · coldStartMetricTarget · coldStartFakeCalibration | Leaks internal feature jargon + metric-forward framing to a no-baseline user; no warm low-friction invite | strip + prompt |
| 2 | thats-not-informative | trust-repair | **26** | **CAP placeholderOrBroken ≤30** · scaffoldLabel("Real read:") · trustRepairReportVoice("score 74") · disqualifier("cut the") | Emits exposed scaffold label + raw score + echoes the "fluff" it criticizes | strip + prompt |
| 3 | what-voice-should-i-pick | goal-change | 31 | roboticPhrase + goalIntentStateDirective("tap to confirm and I'll lock") | Voices a UI/button directive in coach speech; stacks recommendation + runner-up (>1 move) | strip + prompt |
| 4 | off-topic-egg | off-topic | 45 | sensitiveTurnReportVoice("hit 80") | Dumps rep stats + brusque/transactional instead of warm steer-back on a test turn | prompt |
| 5 | goal-change-engaging | goal-change | 49 | roboticPhrase + sensitiveTurnReportVoice("3 fillers in 68s") + tooLong + goalIntentStateDirective | Report-voice metric dump + either/or question (not one move) + UI directive + long | strip + prompt |
| 6 | i-ramble | mechanics | 54 | scaffoldLabel(".\n\nNext rep:") + tooLong | Diagnosis relayed from contextBlock hypothesis; judge wants a non-obvious earned read | strip (label/len) + **fixture** (earned-insight ask) |
| 7 | its-not-easy | emotional-frustration | 56 | — | Ends on a cognitive probe (reloads work on a discouraged user); skips earned-evidence anchor | prompt (iter-13 anti-defer already shipped — needs live re-verify) |
| 8 | greeting-hi | greeting | 56 | — | Recites rep counts on a bare "Hi"; bundled move; longer than the 1–2 line re-entry | prompt |
| 9 | set-authoritative | goal-change | 56 | roboticPhrase + goalIntentStateDirective("tap the card to confirm") | UI directive in coach voice; no un-swappable personal detail (priorChatTurns empty) | strip + prompt · memory part **structural** (personalMemory CLOSED, iters 5–6) |
| 10 | talk-too-fast | mechanics | 57 | sensitiveTurnReportVoice("scored 71") + tooLong | Quotes raw score; DROPS the sharp lever number (0.09 pause-rate); no emotional ack first | prompt (nuanced — see lever caveat) |
| 11 | leadership-update | leadership-update | 60 | — | Opens on correction not acknowledgement; report-voice "clean at 77"; no rehearse-tonight step | prompt |
| 12 | recurring-close-rush | mechanics | 61 | scaffoldLabel(".\n\nNext rep:") + tooLong | Drops "5 of 6 overall" trend point; three-block scaffold; bundled move; long | strip + prompt · earned-read ding = **fixture** |
| 13 | too-generic | trust-repair | 64 | scaffoldLabel(".\n\nNext rep:") | Raw "7 fillers" surfaced; colon-led scaffold cadence; diagnosis mirrors handed hypothesis | strip + prompt · handed-hypothesis ding = **fixture** |
| 14 | what-do-you-know | metadata-trap | 64 | tooLong | Doesn't close the skepticism loop; bundles a next-rep onto a "what do you know" turn; long; bare "170 pace" | prompt |
| 15 | youre-repeating-yourself | repetition-callout | 69 | trustRepairReportVoice("hit 82") | Restates handed case-formulation; mild report-voice residue | **noise** (1pt under line) + prompt (metric) · **fixture** (handed) |
| 16 | why-cant-straight-answer | trust-repair | 69 | trustRepairReportVoice("hit 3") | Split verdict handed by context; two stat callouts lean report-voice | **noise** (1pt under line) + prompt (metric) · **fixture** (handed) |

---

## 2. THE 2 PLACEHOLDER LEAKS (reliability-invariant violations)

Both trip `placeholderOrBroken` (deterministic ≤30 cap). These are **not** quality-gradient
misses — they are hard-floor invariant violations: a reply that reaches the user carrying
internal scaffold or unexplained product internals is a *broken/placeholder-shaped output*,
independent of how good the coaching underneath is. That is why they cap at ≤30 regardless
of IQ/EQ. **The chat-agent is fixing these at the STRIP layer, which is the correct layer** —
a deterministic strip guarantees the invariant, versus hoping prompt wording suppresses it
every draw (prompt suppression is subject to the ±5 generation variance and will leak again).

- **cold-start-no-data (22)** — leaks `Ah-Counter` (internal feature/round name) and a fake
  calibration target ("aiming to stay under 4 fillers") to a user with zero baseline. Jargon
  + invented metric on a no-data user = the placeholder invariant. Strip the internal names;
  steer to plain language ("do one 60-second rep on anything you know well").
- **thats-not-informative (26)** — leaks the scaffold label `Real read:` (an internal
  section marker, not spoken coaching) plus the raw `score 74`. Exposed scaffold label = the
  placeholder invariant, full stop. Strip label markers before the reply ships.

---

## 3. LEVERS — movable vs measurement noise

**Genuinely movable (deterministic-detectable ⇒ measurable, not noise):**

- **Report-voice / raw-metric residue** — the single most recurring deduction in the suite.
  Fires deterministically (`sensitiveTurnReportVoice`, `trustRepairReportVoice`) AND draws a
  judge deduction on ~10 of the 16 fixtures: "score 74", "hit 80", "scored 71", "3 fillers in
  68s", "clean at 77", "hit 82", "hit 3", "7 fillers", "170 pace". Suppressing raw score/
  filler/pace/duration quotes removes BOTH the deterministic penalty and the judge ding →
  double win, high count. **Deterministic detectability means a dual-arm A/B can measure it
  cleanly above the noise floor.** This is the #1 movable lever (details in §4).
  - CAVEAT that must be built into any test: it is NOT "drop all numbers." talk-too-fast
    proves the judge WANTS the load-bearing lever number (0.09 pause-rate) kept while the
    *summary score* (71) is dropped. The rule is "translate/suppress SCORE-style summary
    metrics; keep the one diagnostic number the read turns on." A blunt "no numbers" rule
    will over-suppress and lose the un-swappable detail.
- **UI-directive residue on goal-change** — `goalIntentStateDirective` /
  "tap to confirm and I'll lock it in" fires deterministically on 3 goal-change fixtures
  (#3 31, #5 49, #9 56). Smaller footprint than report-voice but very clean: ban UI/button
  directives in the coach's spoken voice (or strip them). Measurable.
- **Scaffold labels + length** — the chat-agent's strip layer already targets these; they
  co-occur on #2, #5, #6, #12, #13. Strip-layer, not prompt, is the reliable fix.

**Measurement noise / not a real lever right now:**

- **#15 youre-repeating (69) and #16 why-cant (69)** sit 1 pt under the 70 line — inside the
  ±5 generation-variance band. A fresh draw could put either over 70 with no change. Do not
  count these as "failures to fix"; they are draw-luck.
- **personalMemory / un-swappable-detail dings** (#9 set-authoritative) — CLOSED. iters 5–6
  proved rule-1 prompt wording can't move personalMemory; two same-era dual-arm A/Bs both
  net-negative; any real lever is structural (CONTEXT block pre-synthesis), not prompt.

**Stale / over-constrained fixture EXPECTATIONS (fixture-expectation bug, not a coach bug):**

- **#6 i-ramble, #12 recurring-close-rush, #13 too-generic, #15 youre-repeating,
  #16 why-cant** all draw the same ding: *"diagnosis restates the handed case-formulation /
  contextBlock hypothesis rather than an independently earned insight."* But the fixture
  **hands** the coach that hypothesis in the contextBlock, then penalizes the coach for
  using it. Asking the coach to out-diagnose its own supplied context is over-constrained —
  this is a fixture-design tension, not a movable coach behavior. **Recommend a fixture-
  expectation review** before treating these as coaching gaps. (Flag for the loop; do not
  edit this turn.)

---

## 4. NEXT-DRAW PLAN (what a LIVE run should test first)

A replay run can't test any of this — the first action must be a live/dual-arm draw.

1. **Highest-value movable lever → test FIRST: report-voice / raw-metric suppression.**
   - Design: **same-era DUAL-ARM blind A/B** (or full live run if a key is available).
     Regenerate BOTH arms in one session; one blind judge scores both; masked + order-shuffled.
   - Candidate rule (prompt): "Never quote a raw summary metric (a score like '74', a raw
     filler count like '7 fillers', a pace number, or a rep duration) verbatim in the reply —
     speak it in plain language ('a clean rep', 'three weeks landing'). EXCEPTION: keep the
     single diagnostic number the fix turns on (e.g. a pause-rate the move targets)."
   - Arms scored on: the ~10 report-voice fixtures (#2,4,5,10,11,14,15,16 + close-rush,
     greeting) PLUS emotional/neutral CONTROLS (interview-prep, exhausted, panic-blank) to
     catch the iter-5/6 downside where a suppression rule made the model DROP useful facts /
     fabricate. Watch talk-too-fast specifically: confirm the coach KEEPS the 0.09 pause-rate.
   - Success bar: deterministic report-voice findings drop AND judge report-voice deduction
     drops on the target set, with controls flat-or-up, net positive > the ±5 noise floor.
2. Second: **UI-directive ban on goal-change** (#3, #5, #9) — cheaper, cleaner, 3-fixture win.
   Same dual-arm design on the goal-change set + a goal-change control.
3. Coordinate with chat-agent's STRIP-layer fix for the 2 placeholder leaks + scaffold
   labels — verify the strip resolves the ≤30 caps on cold-start-no-data and
   thats-not-informative in a live capture (deterministic caps should clear).
4. Before touching #6/#12/#13/#15/#16 as coach bugs: run the fixture-expectation review on
   the "handed-hypothesis" ding (§3) — likely re-baseline the EXPECTED move, not the coach.
5. Re-confirm iter-13 anti-defer on #7 its-not-easy in the live draw (shipped but only
   subagent-verified; this replay capture still ends on a probe — may be a pre-iter-13 or
   variance capture).

---

### Provenance
- Source reports: `tools/coach-arena/reports/latest.md`, `failures.md`, `latest.json`
  (run_2026-07-08_10-04-47, provider `replay`, coach+judge `claude-sonnet-4-6`).
- Backlog context: `tools/coach-arena/EXPERT_COACHING_BACKLOG.md` (live baseline 67.7,
  personalMemory CLOSED, measurement rules).
- No harness run, no fixture/rubric/judge edits this turn.

---

## Loop execution log — 2026-07-08 (main-session RALPH cycle)

**Baseline HEAD:** `7955b737` on `ux-overhaul`.

**Build:** `xcodebuild build` (scheme Noum, iOS Sim) → SUCCEEDED (exit 0) before edits; combined agent edits compile clean under `xcodebuild test` build-for-testing.

**Coach Arena:** ran in REPLAY mode (no ANTHROPIC_API_KEY in session → offline). Reports regenerated 10:04:47. Headline: Gold-suite 70.2 ✅ / Deep-assessment 76.7 ✅ / Trust-repair 73.3 ✅ / floor 22 ❌ / sub-70 16 ❌ / placeholder leaks 2 ❌. See honesty banner: replay = frozen captures; these numbers are NOT attributable to this loop's edits.

**App-path trace:** attempted. Offline canned-candidate engine ran (candidate=excellent). Real-pipeline app-path dump from the 05:15 concurrent session exists (`reports/app-path/latest.*`, 73.8, productionEvidence ✅, traceQuality ✅, **0 leaks**, 50/50 traces). Live app-path dump from the *current* app is BLOCKED (needs on-device run + Deepgram/backend creds) — logged, not silently skipped.

**Reframing the 2 replay leaks (honesty):** the real-pipeline app-path run shows **0 leaks**, so the 2 replay leaks are almost certainly **stale captures**, not a live bug. The strip-hardening landed this loop is therefore **defense-in-depth for the inline-scaffold gap + a regression test**, NOT a claimed score win. No score delta attributed.

**Code changes landed (real diff):**
- `AICoachChatService.swift` — inline scaffold-label strip now catches comma/semicolon joins; new `strippingReportVoiceResidue` + turn-aware `finalizedCoachReply` last-mile backstop; gate detector tightened to match (stricter, never weaker); cold-start metric-target regex broadened.
- `CoachContextBuilder.swift` — cold-start (no-baseline) directive forbids internal mode names + invented metric targets, overrides established-user example.
- `AskNoumView.swift` — render-time sanitizer chokepoint reusing `CoachReplyTextSanitizer` (no forked regex); covers reveal/streaming/a11y.
- `NoumTests/CoachPlaceholderLeakStripTests.swift` — 7 offline deterministic tests.
- `maestro/chat_smoke.yaml`, `maestro/chat_reject_smoke.yaml` — new smoke flows.

**Test verification (booted iPhone 17, real device):** first run flagged `establishedUserMayNameAhCounter` — the offline suite CAUGHT that the probe reply was pure prescription tripping the unrelated `missingInsightBridge` rubric. Probe rewritten to a well-formed observation→insight→Ah-Counter reply + a focused cold-start-ban guard. Re-run: **all 8 tests PASS** (`** TEST SUCCEEDED **`, booted iPhone 17). The offline suite did its job — caught the over-suppression, fixed by isolating the probe.

**Remaining failures / next-draw plan:** see ranked table above. Highest-value MOVABLE lever = report-voice/raw-metric suppression (~10/16 fixtures, deterministic-detectable → measurable above the ±5 noise floor via a live dual-arm A/B). 5 fixtures flagged as over-constrained fixture-EXPECTATION bugs (case-formulation restatement), not coach bugs — review expectations, do not prompt-tune. Two 69s are within noise. Live production-parity run (ARENA_PROVIDER=anthropic + key) required to measure any of this — CREDENTIAL BLOCKER.

---

## Report-voice A/B — attempted, then ABANDONED (2026-07-08, cost-justified call)

The `anthropic` provider hit an empty API credit balance (Max ≠ API credits). Pivoted to the `cli` provider (Max auth, no API $). Ran Arm A (baseline) live via cli to ~15/51 fixtures, then **stopped by decision**: the report-voice lever is a subtle prompt refinement, and per this repo's own README (same prompt swings 75.7↔76.5, ±9/fixture judge noise) plus prior closed wording-lever attempts, it is very likely within noise. ~200 Max-quota calls to most-likely measure noise is not cost-justified. No score claim made from the partial run. If ever revisited, the ONLY honest cheap version is the deterministic report-voice-cap RATE on the ~10 sensitive-turn fixtures (~40 calls), not judge means — but the expected effect size does not justify even that. Lever parked, not validated.

The reliability work from this loop (strip-hardening + 8 offline tests + view-layer defense) stands on its own — verified offline, independent of any live A/B.
