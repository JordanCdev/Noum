# Noum Figma to SwiftUI handoff

This handoff replaces published Code Connect with a repository-owned mapping that works on the current Figma Professional plan.

- Figma: [Noum — Product Journey & Design System](https://www.figma.com/design/srCgE5IP3rWoNMWtHo3AnI)
- Machine-readable component and screen map: [`FIGMA_SWIFTUI_COMPONENT_MAP.json`](./FIGMA_SWIFTUI_COMPONENT_MAP.json)
- Milestone: M14
- Product pillars: personalized coaching, believable progress, coaching trust, and real-world transfer

## Figma pages

| Page | Purpose |
|---|---|
| `00 Current UX audit` | Current simulator evidence with Keep/Change critique |
| `01 Target journey and navigation` | One-target coaching loop, Day 0–7 contract, stable tabs, contextual destinations, and state-owner ledger |
| `02 Design system and variables` | Production color, type, spacing, radius, motion, components, variants, and accessibility behavior |
| `03 Core production screens` | Nine production targets at 402 × 874 points |
| `04 Loading, error, empty and accessibility states` | Non-happy-path states plus Dynamic Type, VoiceOver, Reduce Motion, contrast, touch, and device checks |
| `05 Interactive prototype` | Ten connected screen states and 22 interactions, starting at Today |
| `06 SwiftUI implementation handoff` | Visual counterpart to the repository mapping and implementation sequence |

## Production rules

1. Existing stores and managers remain the source of truth. Figma components are presentation contracts, not new state owners.
2. Keep the production navigation native: `TabView`, `NavigationStack`, native safe areas, native back behavior, and swipe-to-go-back.
3. The first visible post-rep content is verified evidence, one restrained observation, and one prescribed next action. Those three surfaces must describe the same lever; scores and detail are secondary.
4. Review must never regenerate a historical rewrite on appearance. Persist the source-bound rewrite snapshot before promising the same ladder later.
5. Targeted Retry uses the existing `TranscriptPracticeIntent` and `TimedPracticePromptHandoff`; it is a presentation branch inside Timed Practice, not a new durable store. It repeats the source prompt and applies the one-step target in the user's own words—it does not ask the user to recite the aspirational rewrite.
6. Unified Progress composes `RatingStore`, `ProfileManager`, `AchievementStore`, and `PathProgressManager`. Do not create a parallel progress owner.
7. Coaching Memory composes `CoachMemoryStore` and existing edit/delete behavior. Provenance and uncertainty remain visible.
8. Full-screen achievement sequences stay removed. Progress outcomes are inline, detection-safe receipts with no count-up, confetti, stagger chain, or forced animation.

## Implementation sequence

1. Render the source-bound targeted-retry intent in `TimedPracticeView`.
2. Reorder `SummaryView` around verified evidence and immediate retry.
3. Add durable rewrite ownership at the saved-session boundary.
4. Reuse the durable ladder in `SessionHistoryDetailView`.
5. Extract view-only `ReviewTranscriptStep`, `ProgressOutcomeRow`, `ProgressLandmark`, and `CoachingMemoryItem` components.
6. Compose Coaching Memory and Unified Progress from existing stores.
7. Run the Figma comparison loop for each screen: simulator capture, visual diff, UX critic, accessibility sweep, and revision.

## Accessibility acceptance

- Minimum 44 × 44 point interactive target; primary actions are 56 points high.
- Default, XL, and Accessibility XXXL layouts grow vertically and remain scrollable.
- VoiceOver order follows the visible evidence hierarchy. Decorative Path art is hidden.
- Verified quotes include original-transcript provenance and source duration in the same accessibility element.
- Retry cue chips are instructions, not buttons, and stack at large Dynamic Type sizes.
- Reduce Motion removes translation, scale, stagger, count-up, and looping progress animation.
- Microphone access is requested only after a user-initiated Start action.

## Honest implementation status

The design system, audit, non-happy-path states, nine core screens, and interactive prototype are authored. The Phase 1 implementation loop now includes evidence-first Summary, durable source-bound historical Review, visible same-prompt Targeted Retry, inspectable Ask context and response, the compact Path hierarchy, Coaching Memory, and one calm Unified Progress destination. Summary, Review, and Retry preserve one source-bound coaching lever end to end. Home and prescribed practice retain their existing production state owners and plan-first hierarchy. Remaining partial items in the JSON are cross-app presentation consolidation work—not missing Phase 1 journeys—and should only be extracted where it removes real duplication.
