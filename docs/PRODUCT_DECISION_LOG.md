# Noum Product Decision Log

**Status:** Authoritative decision register v1  
**North star:** `docs/VISION.md`  
**Evidence baseline:** `ux-overhaul` at `f441dd0191eb08f79ea159583878c1558f900df7`, source-bound v1 + v2 UI evidence, current Figma concepts, Coach Arena artifacts, trusted coaching/learning/UX research, and approved founder input  
**Last consolidated:** 2026-07-23

## Status definitions

- **LOCKED** — strong evidence and/or explicit founder approval; implement unless new evidence materially contradicts it.
- **PROTOTYPE** — strong direction, but exact implementation must be tested before becoming final.
- **FOUNDER** — research cannot decide this because it depends on positioning, commercial strategy, risk appetite, or brand preference.
- **DEFERRED** — valid idea, but not required for the first production-quality coaching loop.

## Locked decisions

| Decision | Evidence / reason | Implementation consequence | Validation |
|---|---|---|---|
| The personalised coaching plan is the product | VISION + coaching practice | Modes, metrics, lessons, Path, chat, and rewards support one adaptive plan | Users can state their focus and next step |
| Core loop is understand → diagnose → prescribe → practise → review → retry → adapt → transfer | Coaching and deliberate-practice evidence | Every primary surface must advance the loop | End-to-end task completion |
| Day-7 promise is credible understanding and a personalised plan, not mastery | Trust and evidence limits | Avoid overclaiming rapid skill transformation | Week-one comprehension/trust test |
| Onboarding asks desired outcome + felt difficulty | Minimum viable context | Remove long intake and early feature configuration | Time to first rep; abandonment |
| Upcoming real moment is optional/contextual | Not every user has one | Ask only when relevant | Onboarding completion |
| Style/voice is normally proposed after evidence | Reduces premature identity framing | Defer or make optional before first rep | Goal/style correction rate |
| First baseline rep is personalised | Relevance and activation | Prompt ties to outcome/difficulty | First-value rating |
| Standardised benchmark appears later | Comparability requires controlled conditions | Separate formal evaluation from first experience | Benchmark completion/trust |
| First focus is provisional and visible | One sample is insufficient | Show evidence depth and uncertainty boundary | Users understand it may change |
| Noum proposes confidently with a quiet correction path | Expert leadership + autonomy | `Start next step` primary; `Adjust focus` secondary | Correction in ≤2 taps |
| No percentage/confidence slider for focus correction | Does not identify the disagreement | Use categorical correction options | Correction quality |
| User correction outranks model inference | Trust and safety | Update retrieval, scoring, plan, and memory immediately | Regression tests |
| Keep one focus stable while varying practice | Expert coaching + deliberate practice | Change scenario/difficulty before changing lever | Same-target progress |
| Change focus on mastery, stagnation, mismatch, urgency, or dependency | Adaptive intervention logic | Add explicit focus-change reasons | Plan auditability |
| Noum recommends one daily session | Reduces choice overload | Prescription leads; catalogue secondary | Start time and completion |
| Adjustments are “Make it shorter / more challenging” | Positive, concrete language | No recurring intensity/motivation selector | Adjustment usage/completion |
| No recurring mood question | Friction and inference risk | Adapt from explicit user statements and evidence | Session start friction |
| Lower-capacity sessions preserve the target | Continuity without false comparison | Shorter practice, benchmark excluded | Trust and return rate |
| First post-rep sequence is What I heard → One step better → Try it now | Feedback and deliberate practice | Review hierarchy follows this order | Comprehension and retry rate |
| Exact transcript evidence precedes interpretation | Trust and provenance | Quote verification required | Quote-guard tests |
| One-step rewrite changes one lever and preserves voice | Achievable practice | Highlight changes; avoid full corporate rewrite | User preference and retry success |
| Aspirational end state is secondary | Prevents overload and mimicry | Label clearly; never score it | Users distinguish target vs aspiration |
| Retry uses same target and prompt when possible | Valid comparison | Preserve source context | Same-target comparison coverage |
| Reflection occurs after action, not before first value | Avoids onboarding burden | Ask briefly after retry or meaningful session | Response rate and usefulness |
| Daily coaching is evidence-first; overall score is secondary | Motivation and calibration | `View evaluation` disclosure | Trust, motivation, usage |
| Formal evaluation is periodic or user-requested | Comparable evidence | Baseline/review/benchmark modes | Rubric comprehension |
| Scoring is self-referenced, multi-dimensional, and evidence-bounded | Fairness and motivation | No default peer ranking | Score trust |
| Memory is bounded, inspectable, editable, and deletable | Trust and privacy | Typed case file, provenance, correction controls | Memory correction tests |
| Raw assistant chat is not evidence | Prevents self-echo | Persist typed plan/memory only | Retrieval tests |
| Goal changes alter training emphasis, not identity | EQ and authenticity safety | Ban “pretending”/fake-persona framing | Goal-change fixtures |
| Delivery intelligence is opt-in and within-user | Acoustic evidence limitations | Use pace/pause/variation conservatively | Consent and boundary tests |
| Voice signals cannot infer emotion/personality or affect formal scores | Safety and legal risk | No emotional labels; explicit override | Regression and policy tests |
| Engagement hierarchy is evidence win → journey movement → occasional milestone | Self-determination and trust | Replace hollow rewards with earned progress | Motivation interviews |
| Reinforcement arrives briefly, then collapses | Reward without clutter | One-time motion + compact signal | Recall and annoyance testing |
| Visual personality is calm premium + selective warmth/motion | Explicit founder approval | Adult, friendly, alive when earned | Visual preference + usability |
| Earlier Rep Report is a visual north star, not a score-first layout | Strongest inspected concept | Use focal hierarchy, contrast, spacing; demote score | Figma screenshot review |
| One dominant action per screen | HIG and overload evidence | Reduce competing CTAs and card walls | Five-second test |
| Typed and live Noum share one plan/context/trace | Existing architecture + product coherence | One coach relationship, multiple modalities | Cross-mode continuity |
| Long/detailed prompts must end in a terminal state | Reliability requirement | Accepted/repaired/fallback/error/cancelled | Failure-path tests |
| Prompt/app-path scores alone do not prove expert quality | Current eval disagreement | Human review and real-user outcomes required | Blinded coach calibration |

## Prototype decisions

| Decision | Current recommendation | Why not locked | Test |
|---|---|---|---|
| Four primary areas | Today, Practice, Progress, You | Exact navigation cannot be proven from research alone | Compare with three-area alternative |
| Ask/Talk to Noum is not a fifth tab | Contextual entry across the app | Live-coach prominence needs usability testing | Discovery and usage tasks |
| Four 5–8 minute sessions in week one | Initial dose hypothesis | No universal evidence for exact dosage | Compare 3/4/5-session paths |
| Today hierarchy | progress signal → journey movement → next step → context | Exact density and ordering need prototype evidence | Five-second + task tests |
| Maximum two secondary blocks before disclosure | Strong anti-overload rule | Some states may need exceptions | Dynamic Type and task testing |
| Path becomes a child of Progress | Supports one journey | Founder may value Path as stronger brand surface | Navigation prototype |
| Achievements/levels/streaks merge into Progress | Reduces reward fragmentation | Existing retention behaviour unknown | Retention and comprehension test |
| Manual Practice is secondary | Strong evidence for prescription-first | Advanced users may need faster access | Novice vs advanced task test |
| Review aspirational example placement | Secondary disclosure or lower section | Exact visibility needs testing | Comprehension and overwhelm test |
| Score default visibility | Hidden/secondary in ordinary practice | Some users may strongly prefer it | Preference + motivation experiment |
| Hybrid visual direction | Rep Report confidence + reduced density | Requires real screen variants | Today/Review/Progress A/B critique |
| Exact motion/haptic system | Restrained, evidence-triggered | Emotional response is prototype-dependent | Reduce Motion and user testing |
| Transcript change highlighting | Phrase/sentence-level semantic highlight | Best visual representation unknown | Two variant test |
| Low-capacity adaptation UI | Revised prescription card + quiet adjustment | Copy and discoverability need testing | Scenario testing |
| Weekly review composition | learning, change, uncertainty, next plan | Exact duration and detail need testing | Week-one pilot |
| Social comparison visibility | Secondary and opt-in | User value and harm differ by audience | Controlled prototype/test |

## Founder decisions — resolved 2026-07-23

Resolved via `FOUNDER_DECISION_SHEET_2026-07-23.md` and the founder-decision
research pass (deep-research report 10), with one founder override noted below.

| Decision | Resolution | Rationale | Implementation consequence |
|---|---|---|---|
| League/friend leaderboard at launch | **Hidden from core journey; code retained** | Leaderboard effects are mixed and design-dependent; SDT risk to intrinsic motivation; social can't safely ship pre-cutover anyway | Stays behind release gates, out of primary nav; revisit later as an opt-in layer |
| Path as named destination | **Folds under Progress as the plan's visual layer** | Tabs reflect top-level hierarchy; Path as a peer destination tells a second progress story | "Path" survives as branded metaphor and visual grammar inside one Progress narrative |
| Default coach persona | **Warm-professional; directness earned over time or on explicit request** | Working-alliance evidence: warmth builds the trust that later makes challenge land; "Be direct with me" style requests are honoured immediately | No harsh-by-default copy; directness escalates with evidence or by request |
| Live-call surface and orb | **Live call stays the core relationship surface; the orb VISUAL is explicitly not locked — founder authorises revamp or replacement** (overrides report 10's "centerpiece" framing) | The relationship mode is proven; the current orb rendering is not sacred brand equity | Design gate may propose a new live-call identity within brand rules (SF Symbols + motion + colour + shape; no characters, no anthropomorphic companion framing) |
| Paywall timing | **Strong paywall only after first meaningful coaching value** (first real review or first retry) | Category norms + trust-dependent product; harder variants testable later | Free path must reach the first review/retry unblocked |
| Data retention defaults | **Minimise by default; explicit keep/export/delete controls** | ICO storage-limitation guidance; privacy posture as commercial asset | Audit current retention behaviour pre-launch; continuity features become opt-in retention |
| Design-gate medium | **Figma first (two variants per surface), one decision, then SwiftUI** | Parallel low-fidelity exploration is cheaper than SwiftUI divergence; discipline is the hard gate, not more design | No SwiftUI restyling before an approved frame |
| Sequencing | **Slice 1 (first value loop) outranks M14 ops when engineering time conflicts** | The first complete coaching loop is the value mechanism; M14 gates are mostly operator-owned and proceed in parallel | Build order follows §17 slices; release gates continue independently |

### Founder decisions still open

| Decision | Status | Working default |
|---|---|---|
| Free-tier allowance and subscription price | Working default set, needs unit-economics calibration | 3 free coached reps/week + first-week review free; ~£9.99/month or £69.99/year. Next research pass should be commercial calibration, not more product UX |
| Initial go-to-market wedge | Deferred to commercial planning | Validate with adults facing meaningful work communication moments |
| Human-coach calibration investment | Deferred until budget allows | Small blinded expert review before any broad claims |
| Public claim about replacing a human coach | **Settled: never claim parity** (VISION non-negotiable) | Position as personalised AI coaching |

## Deferred

- generic emotion-recognition;
- passive background listening;
- workplace/education emotion inference;
- broad visual-presence analysis before audio/text trust is established;
- PDF coaching-evidence export until redaction and provenance are defined;
- more gamification surfaces;
- broad localisation expansion before the core journey is validated;
- new feature islands that do not strengthen the coaching loop.

## Resolved contradictions

1. **“Review/retry is missing”** — incorrect. It exists conditionally; the task is reliable surfacing and coherent design.
2. **“Typed Ask Noum is the main coach”** — incomplete. The app includes an immersive live coach call; typed interaction is a connected alternative.
3. **“App-path score proves coaching quality”** — incorrect. Prompt-layer failures and human-readable transcripts remain material evidence.
4. **“V2 replaces V1”** — incorrect. V2 supplements V1; both share the same audited source commit.
5. **“Figma prototype is production visual direction”** — rejected. It is useful for flow but remains too grey, card-heavy, and generic.
6. **“Daily practice is required”** — rejected. Week-one continuity matters, but rigid daily compliance and guilt mechanics do not.

## Governance

- `VISION.md` defines ambition and non-negotiable ethics.
- `COACHING_SYSTEM_SPEC.md` defines how Noum thinks, remembers, adapts, and evaluates.
- `PRODUCT_JOURNEY_DESIGN.md` defines how users experience that intelligence.
- This file defines which decisions are locked, testable, founder-owned, or deferred.

When implementation evidence challenges a decision:

1. record the evidence;
2. propose the change;
3. update classification and rationale;
4. update both affected specifications;
5. add a validation method;
6. never silently contradict the product contract.
