# UX Visual Direction — approved colour pass (2026-06-09)

Owner reviewed the before/after mockups (`.screenshots/2026-06-07_mockups/preview/index.html`,
served locally) and approved the direction: **"the post summary screen is really improved"**;
earlier feedback "seriously boring, too much of the same icons, no colour" is resolved by this pass.
This doc is the implementation brief for folding the direction into SwiftUI. It does NOT change
coaching logic — visual + hierarchy only.

## Direction (the three rules)

1. **One vibrant gradient hero per screen; everything else stays calm.** White cards with
   per-concept coloured icon chips. No all-white sameness, no gradient-on-everything.
2. **Varied iconography.** Each concept gets its own symbol (read=eye, win=check, fix=arrow-up,
   ask=chat bubble, journey=compass, coach=shield-check, library=trophy, history=clock).
   The **waveform mark is brand identity only** — one small instance (Home top bar), never
   repeated as a per-card avatar. SF Symbols in app (no illustration/characters — brand rule).
   No emoji in product UI (flame = SF Symbol `flame.fill`, not 🔥).
3. **Semantic colour, consistently:** blue = coach/read · green = win/proof · amber = fix/next
   lever · indigo/violet = verdict/score · warm orange = streak day-pill.

## Per-screen

### Post-rep verdict (SummaryView)
- Hero: indigo→violet gradient card (`#3B6EF5 → #6A4DF5 → #8B3DF5`), white score ring inside,
  verdict title + one-line sub, 3 glass stat chips (fillers / duration / pace).
- Below: THE READ (white card, blue eye chip) → WIN (green-tinted card + verified quote rail)
  → FIX FIRST (amber-tinted card + "Next move ·" line).
- **OWNER DECISION: exit lives at the BOTTOM, not the top.** No "Done" in the nav bar.
  Bottom panel after FIX: primary `Start 45-second drill` (blue pill) + secondary `Done`
  (ghost/outline). Forces the scroll through the feedback before leaving. Label stays "Done".

### Home (ContentView)
- Top bar: small waveform brand mark (left) + streak day-pill (right, warm orange gradient,
  `flame.fill`, quiet status — NO countdown, per never-punish-shame).
- Greeting (`Hello, <name>`) then ONE coach hero: blue→cyan gradient (`#2E7BF6 → #3BA1FF →
  #16C7CE`), eyebrow YOUR COACH · TODAY, prescription title, 1-line why, goal chip
  (glass pill), white `Begin` CTA.
- Ask Noum = white row + violet chat chip. Journey = white card, compass chip, real progress
  bar (gradient fill), chapter pill.
- **Settings tab STAYS** (mockup dropped it for space — do not drop in app). Tab bar dock:
  resolve the "fake tab bar" per Iteration 4 (real selection state or stop styling as tabs).

### Profile (ProfileView)
- Identity row: gradient monogram avatar (blue→violet), name, voice target, Speaker-tier pill
  (blue→cyan gradient).
- ONE believable-progress hero: blue→green gradient (`#2E7BF6 → #2B8F9C → #159E68`), big rating,
  glass `▲ +N this week` chip (only when real + positive; silent on drops), white bar-sparkline
  from real `ratingHistory`, one honest plain-English line.
- Coach read = white card, indigo shield chip, read + "Next move ·". Growth library (green trophy
  chip) + History (grey clock chip) as quiet rows.
- **Pro upsell stays but placed AFTER value** (below rating hero / coach read), consistent with
  the verdict's "upsell after value" pattern. Never above the hero.

## Implementation rules

- **Tokens first:** add gradient/colour definitions to the design system (DesignSystem /
  AppColor / Typography) — no hex literals scattered in views.
- Honesty gates unchanged: rating hero gated on `hasRatedEvidence`; delta chip only on real
  weekly data; celebrations remain RewardEngine `.major`-gated; drops silent.
- Reduced-motion: every new motion (ring resolve, hero entrance, sparkline draw) needs an
  `accessibilityReduceMotion` static fallback. A11y labels on all new chips/CTAs.
- Verify on simulator with screenshot capture (binary-mtime gate; `noum://summary` for verdict).

## Open question (revisit after first on-device render)

All three heroes are blue-family gradients — coherent but possibly samey screen-to-screen.
Candidate: tier the verdict hero by score band (e.g. muted slate <5, indigo 5–7, violet+gold 8+),
keeping upward-only celebration rules. Decide on device, not in mockups.
