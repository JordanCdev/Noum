# UX visual direction — restrained evidence system (2026-07-22)

This document supersedes the June colour pass. The earlier rule—one vibrant
gradient hero per screen—made coaching surfaces compete with their content and
pulled Noum toward promotional, game-like UI. The current direction follows
`VISION.md`: calm, intelligent, evidence-led, and motivating through believable
improvement.

This is a presentation contract. Coaching logic, evidence floors, state owners,
and honesty gates remain unchanged.

## Core rules

1. **The evidence is the emphasis.** Use hierarchy, concise copy, and whitespace
   before colour or motion. A screen should answer “what matters now?” in its
   first viewport.
2. **Neutral canvas, bounded accent.** Root screens use
   `AppColor.screenBackground`; primary content uses `cardBackground`; inset
   content uses `innerSurface`. Saturated multicolour gradients are not root
   canvases or default cards.
3. **One primary action.** The highest-value next step gets one solid
   `AppColor.brandBlue` action. Alternatives remain text or quiet rows.
4. **Three semantic accent roles.** Blue is action/read, green is verified
   proof, amber is the next lever. Pro purple identifies premium coaching but
   does not compete with the primary action. Mode tints stay inside exercise UI.
5. **Progressive disclosure is the default.** Show the result, one bounded
   observation, and one next action. Supporting analytics, rewrites, history,
   and commercial depth sit behind Details or in their own destination.
6. **Motion explains state.** No ambient breathing, parallax washes, repeating
   rays, chained celebrations, or automatic presentation. Reduced Motion gets
   static state plus simple opacity where a transition is still useful.

## Type and surface hierarchy

- Figtree remains the display/numeric family; Manrope remains the body/UI
  family. All roles come from `Typography` and scale with Dynamic Type.
- A root screen has one `Typography.screenTitle` and at most one short
  subtitle. A pushed screen uses an inline navigation title and does not repeat
  it as a second large heading.
- Top-level cards use `CornerRadius.large`; nested groups use
  `CornerRadius.medium`; related rows prefer dividers over separate cards.
- Most cards have no shadow. A genuinely elevated surface may use at most a
  black or semantic shadow around 0.08–0.10 opacity, radius 10–12, y 4–6.
- Coaching labels are sentence case. Uppercase is reserved for fixed-format
  live status where it materially improves scanning.

## Home

- Home uses the neutral app canvas, including behind the native tab bar and
  home indicator.
- The coach recommendation is a compact white card: small Noum mark, “Today’s
  focus,” one title, one short reason, an optional voice/mode chip, and one solid
  action.
- If a real-world moment is close, preparation becomes the primary action and
  the ordinary rep is a quiet alternative.
- First-week step, Ask Noum, and progress receipts are bounded quiet cards. They
  must not reconstruct an immersive hero stack.
- Big Moment intake is user initiated or deep-link initiated. Completing
  onboarding never auto-opens another sheet.

## Post-rep

- The default read is one receipt: result, one verified quote when supportable,
  one restrained observation, and one prescribed next action.
- Progress is compact and inline. Achievement, level, and personal-best events
  do not chain full-screen overlays.
- Rewrites, Ask Noum, sharing, comparisons, and detailed analytics remain
  available after the proof moment without competing with it.
- A contextual paywall appears only after the useful-value moment.

## Profile, Path, and Train

- Profile progress uses a neutral card with a small semantic accent rather than
  a blue-to-green billboard. Evidence detail remains disclosure-led.
- Path preserves the open corridor, opaque separated trees, calm waypoint, and
  distinct Reason/Landmark sections. Illustration supports the path; it does not
  consume the majority of the viewport.
- Train is plan-first: one compact coach-built recommendation. The full library
  remains collapsed behind “Choose for myself.”

## Navigation and accessibility

- `AppShellView` owns a native five-tab `TabView`. Do not replace it with a
  custom tab bar or hide the system home indicator.
- Final scroll content must be fully reachable above native navigation chrome.
- At accessibility text sizes, horizontal stats and choice grids stack; text
  grows before decorative art; verified evidence and next actions never
  truncate.
- Colour is never the only status signal. Every action keeps a minimum 44-point
  target and an explicit accessibility label where its visible copy is not
  sufficient.

## Verification

Review the same deterministic screenshot tour at default type, Accessibility
XXXL, and Reduce Motion. Inspect fresh, thin-evidence, and mature states. A pass
is successful when each screen has one obvious reading order, no content is
hidden by native navigation, and the product feels like one coaching system
rather than a collection of promotional cards.
