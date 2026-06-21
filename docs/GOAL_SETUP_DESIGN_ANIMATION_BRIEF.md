# Noum Goal Setup Design + Motion Brief

## Context

Noum is a premium iOS communication coach. The goal/setup experience is the user's first handshake with the product, so it must feel like a calm coaching intake rather than a modal setup task.

## Problem

The previous setup/goal refresh treatment felt too much like a popup. It interrupted the app instead of feeling woven into the coaching relationship. The tone also leaned administrative instead of friendly, intelligent, and human.

## Desired Feeling

- Calm, premium, and focused
- Friendly without being cute
- Coach-like, not form-like
- Lightly cinematic, not decorative
- Clear enough that the user always knows what to do next

## Product Principles

- The setup flow should feel like Noum is taking a few bearings before coaching.
- Goal refresh should feel like a coach recalibrating, not the app nagging.
- Motion should support state change and comprehension.
- Reduced-motion users must get the same information without flourish.
- No confetti, mascot theatrics, bouncing stickers, noisy progress, or fake celebration.

## Current Surfaces

1. First-run setup root
   - Temporary app root until complete, not a cover over Home.
   - Current copy begins: "First, a few bearings."
   - CTA: "Start setup."

2. Inline direction check
   - Appears at the top of Home when goal refresh is due.
   - Lets the user confirm, adjust, or dismiss in place.
   - Current copy begins: "Is this still the conversation you want Noum to train for?"

## Design Deliverables

- High-fidelity Figma frames for:
  - First-run setup intro
  - Setup question step
  - Setup completion/summary
  - Inline direction check collapsed state
  - Inline direction check editing state
  - Small-screen stress case with long goal text
- Component specs:
  - Spacing, typography, color tokens, corner radius, shadows
  - Button states: default, pressed, disabled, focus/accessibility
  - Text wrapping behavior for long goals
- Redlines or dev notes that map to existing SwiftUI tokens where possible.

## Motion Deliverables

- 2-3 short motion studies, each 2-5 seconds:
  - Setup card entrance
  - Step transition
  - Direction-check confirm/dismiss/edit transition
- Preferred handoff formats:
  - Video preview: `.mp4`
  - Implementation reference: timing/easing notes
  - Optional production asset only if genuinely needed: Lottie/Rive
- Motion must include a reduced-motion equivalent.

## Motion Direction

- Setup card entrance: subtle upward settle + opacity, 250-400ms.
- Step transition: content changes with directional continuity, no carousel gimmick.
- Progress ring: quiet continuation, not a game meter.
- Direction check: expand/edit should feel like a card opening, not a sheet appearing.
- Confirm: card resolves away calmly; no celebration.

## What To Avoid

- Modal/popup framing
- Onboarding illustrations that feel generic
- Mascot-heavy animation
- Oversized celebration
- Progress bars that imply gamification
- Copy that says "configure", "setup complete", "30 seconds", or similar admin language
- Motion that blocks the user from starting a rep

## Acceptance Criteria

- A first-time user understands why setup exists in under 5 seconds.
- The experience feels like part of the product, not an overlay.
- Long text does not collide with buttons or the floating tab dock.
- Direction check actions are visible without scrolling when forced on Home.
- Reduced motion has no lost meaning.
- Developer can implement with existing SwiftUI primitives unless a motion asset is clearly worth it.

## Hiring Recommendation

Look for a senior iOS product designer with motion taste, or a product designer plus a motion designer who has shipped app onboarding. Portfolio keywords to search:

- iOS onboarding
- product motion
- SwiftUI animation
- Rive
- Lottie
- premium mobile app
- coaching / wellness / learning app

Good places to search:

- Contra: strong for independent product designers and motion specialists.
- Dribbble Hiring: broad design marketplace, useful for portfolio browsing.
- Behance Hire: good for visual/motion portfolios.
- Upwork: useful if you write a tight brief and filter aggressively.

## Suggested Project Shape

- Fixed-scope 1-week sprint.
- Day 1: audit current screenshots and agree principles.
- Day 2-3: explore 2 visual directions.
- Day 4: pick one direction and refine mobile states.
- Day 5: motion pass + implementation notes.
- Optional day 6-7: developer QA after implementation screenshots.

## Budget Guidance

- Senior product designer/motion consultant: expect premium rates.
- Prefer paying for a focused sprint over an open-ended redesign.
- Do not hire someone who only offers a static Dribbble-style shot; this needs interaction design, motion judgment, and iOS constraints.
