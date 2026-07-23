# Deep Research Brief — Pre-Figma Pass (2026-07-24)

Paste everything below the line into ChatGPT Deep Research. If output quality
suffers from breadth, split into two runs: **Run 1 = sections A + C + F**
(commercial/process), **Run 2 = sections B + D + E** (design/coaching). Section
B is the one that directly blocks Figma.

---

## Context (read first, do not relitigate)

Noum is a premium iOS communication-coaching app (SwiftUI, iOS 26, solo
founder-developer). It coaches speaking under pressure: short recorded "reps,"
AI-scored evidence, a personalised plan, an immersive live voice-coach call, a
typed coach chat, and a review loop that shows a verified quote from the user's
own rep, a one-step rewrite of their words, and a one-tap targeted retry.

**Already decided — treat as fixed constraints, do not revisit:**

- The product is one personalised coaching plan; loop = understand → diagnose →
  prescribe → practise → review → retry → adapt → transfer.
- Social/leaderboards hidden at launch. Path folds under Progress. Coach
  persona = warm-professional, directness earned or on request. Paywall only
  after first meaningful coaching value. Data retention minimised by default.
- Figma-first design gate: two variants per surface, one decision, then SwiftUI.
- Four-tab IA (Today / Practice / Progress / You) is a prototype to TEST, not a
  fact (section C asks how).
- The live call remains the core relationship surface, but the current "orb"
  visual is explicitly open to revamp or replacement.
- Brand rules: **no illustrated characters, no mascots, no melodic music.**
  Visual identity is built from SF Symbols, motion, colour, and shape.
- Never claim human-coach parity/replacement.
- Working pricing default (validate, don't assume): ~£9.99/month or
  £69.99/year; free tier = 3 coached reps/week + full first-week review free.

For every recommendation: name your evidence, state confidence, and prefer
"here is the best-supported default + how to validate it" over surveys of
options.

---

## A. Commercial calibration (report-10 follow-up)

1. **Price validation.** For a premium individual communication-coaching
   subscription in 2026: is £9.99/mo / £69.99/yr the right opening price for
   UK+US? Compare current actual pricing and tiers of Yoodli, Orai, Speeko,
   Poised, Ultraspeaking, and any credible newcomer. Include annual-discount
   norms and App Store price-elasticity evidence. A great answer ends with a
   price table and one recommended price pair.
2. **Free-tier mechanics.** Is "3 coached reps/week + first-week review free"
   the right allowance shape, or does the evidence favour a time-boxed full
   trial (e.g. 7-day full access) instead of a perpetual metered free tier?
   Which converts and retains better in coaching/skill apps specifically?
3. **The rewrite-ladder allowance question.** After the free first week, should
   the AI rewrite ladder (the highest-value review moment) be (a) included in
   the 3 free weekly reps, (b) Pro-only, or (c) limited (e.g. 1 free
   ladder/week)? Weigh "free users must feel the core loop" against "the
   differentiator funds the product." Recommend one.
4. **Paywall placement.** Given paywall-after-first-value is fixed: exactly
   which moment converts best without damaging trust — after the first review,
   after the first retry comparison, or at the week-one read? Evidence from
   subscription-app benchmarks (e.g. RevenueCat) and category examples.
5. **Regional pricing.** Should UK, US, and EU launch prices differ, and by how
   much?

## B. Design research for the Figma gate (blocks design work)

6. **Premium-calm visual language, 2026.** What do the best premium,
   trust-dependent iOS apps (health, finance, coaching — e.g. current
   best-in-class examples by name and screen) do that makes them read
   "premium and calm" rather than "generic card dashboard"? Concrete
   ingredients: surface/tonal hierarchy, edge-to-edge vs card layouts, colour
   restraint, depth/materials (including how far to adopt iOS 26 Liquid Glass
   in a third-party app), and what over-carded design costs in perceived
   quality. Name specific apps/screens to study.
7. **Information density and comprehension.** Evidence on how much copy and how
   many simultaneous modules a mobile screen can carry before comprehension and
   action rates drop — to justify (or tune) our density limits: one hero, one
   primary action, max two secondary blocks before disclosure.
8. **Typography for coaching surfaces.** Best-practice mobile type hierarchies
   for evidence-heavy but calm surfaces (quote display, transcript comparison,
   highlighted-diff text). Include Dynamic Type survival strategies and
   examples of apps that show text-diffs/highlights well.
9. **Live-voice AI identity (the orb revamp).** Survey how current leading
   voice-AI products visually render "the AI is present, listening, speaking"
   — e.g. ChatGPT Advanced Voice, Gemini Live, Copilot Voice, Claude mobile
   voice, and premium meditation/coaching apps' session screens. Which visual
   metaphors (waveform, particle field, breathing geometry, aurora, typographic
   presence) read premium-adult vs gimmicky? Constraint: no faces, no
   characters, no anthropomorphic companion framing; must be feasible with
   SwiftUI/Metal + SF-Symbol-derived shapes. Recommend 2–3 directions worth
   designing as variants, with named references.
10. **Audio-reactive motion.** Patterns and parameters for voice-reactive
    visuals (input level → visual response latency, idle "breathing" rates,
    speaking vs listening state changes) that feel alive without being noisy;
    Reduce Motion alternatives for each.
11. **The five Review states.** Design patterns and real examples for:
    (a) an earned "here's a stronger version of your words" reveal;
    (b) **coached absence** — how premium products say "this feature
    intentionally doesn't apply here" without reading as broken;
    (c) generation-failed retry states that keep trust;
    (d) quiet in-context Pro upsell rows that don't feel gross (named
    examples of tasteful contextual upsells);
    (e) suppressed/secondary states when a comparison owns the screen.
12. **Progress narratives without gamification.** Examples and evidence for
    progress surfaces built on evidence and trajectory (before/after, trend +
    next review) rather than XP/streak walls — what Strava/Whoop/Oura-class
    products get right and wrong for a coaching context where the streak is
    NOT the product.
13. **Onboarding to first value.** Current best-in-class minimal onboarding
    (≤2 questions before first action) in speech/coaching/skill apps:
    time-to-first-value benchmarks, mic-permission timing conversion evidence,
    and the best examples of a "provisional read" moment (the app admits it's
    an early hypothesis). Name screens to study.
14. **Paywall UX.** Given placement from A4: the paywall screen itself —
    layouts, value framing, and copy patterns with the best conversion + trust
    evidence for coaching/skill subscriptions in 2026.
15. **Dark mode + accessibility for this system.** Token strategy for a warm
    off-white/violet system that survives dark mode without inversion mush;
    Reduce Motion replacement patterns for earned-progress moments; VoiceOver
    grouping patterns for quote-vs-rewrite comparison cards.

## C. The IA test (4-tab vs 3-tab)

16. **Strongest 3-area counter-proposal.** Before testing 4 areas
    (Today/Practice/Progress/You), what is the strongest evidence-based 3-area
    alternative for this product (e.g. Coach / Practice / You with progress
    inside Coach)? Argue the best case for it so the test is fair.
17. **Test method for a solo founder.** The cheapest credible way to run this
    comparison without a research team: task-based unmoderated testing
    (which platform in 2026, cost, participant count for directional
    confidence), five-second tests, first-click tests; which tasks to use
    (e.g. "start today's practice," "find what changed last week," "correct
    what the coach thinks you're working on"); and what pass/fail thresholds
    are defensible at small n.

## D. Coaching feedback quality (feeds the reply-quality work)

18. **Feedback phrasing that lands.** From coaching, sports-coaching, and
    feedback research: the sentence-level patterns that make feedback feel
    specific, fair, and actionable (evidence → meaning → one move), and the
    patterns that damage trust (generic praise, over-hedging, verdict-first).
    Concrete before/after phrasing examples usable as style references.
19. **Repair after pushback.** Best-practice language when a user disputes or
    is stung by feedback ("that's not what I said," "be less harsh") —
    alliance-repair moves from coaching/therapy literature translated to
    sentence patterns an AI coach can use without grovelling or capitulating
    on evidence.
20. **Evaluation rubrics worth borrowing.** The strongest public speaking
    evaluation rubrics (Toastmasters evaluation guides, debate adjudication,
    exec-coaching assessment frameworks) — what dimensions and evidence
    standards they use that our formal-evaluation mode should mirror.

## E. Transfer and retention specifics

21. **Pre-moment preparation.** Evidence-based pre-performance routines for
    high-stakes communication (interviews, presentations, difficult
    conversations) that an app can guide in ≤5 minutes — what actually reduces
    anxiety and improves delivery (implementation intentions, rehearsal
    structure, arousal reappraisal), and what's snake oil.
22. **Post-moment reflection.** The reflection-question sets with the best
    evidence for improving transfer to the next event; how soon after the
    event to ask; how to ask about audience/counterpart reaction without
    leading the witness.
23. **Reminder cadence + copy.** For a 3-reps/week product: notification
    timing/cadence evidence and copy patterns that drive return without guilt
    mechanics; when a reminder should reference the plan ("your opening held
    twice — one more rep locks it") vs stay neutral.

## F. Small clarifiers (fold in wherever they fit)

24. **"Rep" terminology.** Does gym-derived "rep" resonate or alienate for a
    broad adult communication audience (especially outside fitness culture,
    UK+US)? Alternatives if weak ("round," "take," "attempt," "practice").
25. **Voice-app privacy norms.** What retention windows and privacy-label
    disclosures do leading voice/recording apps use in 2026 — so our
    minimise-by-default posture is stated in familiar, credible terms.
26. **Aspirational-example ethics.** Any evidence on whether showing an
    "aspirational" AI rewrite alongside the user's own words motivates or
    demoralises, and the framing that keeps it motivating.

---

## Output format requested

- Per question: recommendation → evidence with citations → confidence
  (high/medium/low) → how to validate cheaply.
- Name specific apps and screens as visual references wherever possible
  (section B especially).
- End with: (1) a one-page decision summary table; (2) the ten most
  design-actionable findings for the Figma gate; (3) anything you found that
  contradicts one of our fixed decisions — flag it, don't silently comply.
