# HANDOFF — Ask Noum third entry point + Firestore deploy unblock

## Scope

Three files touched: `ProfileView.swift` (+58 LOC, new
`askNoumProfileLink` view + `askNoumProfileLabel(for:)` voice-shaped
copy catalogue), `firebase.json` (+3 LOC, the missing `firestore`
block), and `docs/CURRENT_STATE.md` (trail-of-breadcrumbs entry, new
Profile entry bullet under the Ask Noum section, privacy-policy
block rewritten to reflect the firebase.json fix).

The brief: continue from the existing TO-DO, push toward A+ on the
M14 "open the loop" milestone, and stay on the `Redesign` branch.
Previously, Ask Noum had two entry points — the ambient home promo
(`ContentView.askNoumPromoCard`) and the post-session bridge
(`SummaryView.askCoachBridgeCard`). The third surface where users
sit with their coaching context — the Profile's Coaching Direction
card with its goal text, goal-progress ring, and captured
reflections — had no handoff into the persistent coach thread.
Closing that gap is the engineering content of this push. The
operational side closes a parallel gap: `firebase.json` was missing
the `firestore` pointer block, so the M14 deploy command always
required a config edit step in between.

## What changed

### Move 1 — `ProfileView.askNoumProfileLink`

- `ProfileView.swift` lines 702–706 (the existing `coachingInsight`
  text inside `coachingDirectionCard`) now have a sibling `if
  coachingProfileStore.profile != nil { askNoumProfileLink }` block
  immediately after. The gate matches the rest of the goal-aware
  surfaces: silent for pre-onboarding sessions where there's no
  coaching profile to anchor a conversation to, surfaced once the
  user has captured a goal.
- The new private view `askNoumProfileLink` (~25 LOC) renders a
  small brand-purple "Ask Noum <voice-shape> →" link. No card
  chrome, no NoumCharacter glyph — restrained on purpose so it
  reads as a quiet handoff at the foot of the existing Coaching
  Direction card, not a second hero competing with the
  `GoalProgressView` ring above it. Tap fires `openURL("noum://ask")`
  via the existing `@Environment(\.openURL)` already declared at
  `ProfileView.swift:41`.
- The new private helper `askNoumProfileLabel(for: SpeakingStyleGoal?)`
  is the voice-shaped copy catalogue. Mirrors the catalogue pattern
  used by `ContentView.askNoumPromoHeadline` and
  `SummaryView.askCoachBridgeHeadline` so all three coach entry
  points sound like the same coach. Phrasing is ambient (goal-
  anchored, not rep-anchored) because Profile isn't tied to a
  specific session.

Voice catalogue:

- `.authoritative` → "Ask Noum what to drill next"
- `.warm` → "Talk to Noum about your goal"
- `.concise` → "Ask Noum — one move"
- `.persuasive` → "Ask Noum where to leverage"
- `.executive` → "Brief Noum on what's next"
- `.storytelling` → "Tell Noum what's next"
- `.none` → "Ask Noum about your goal"

### Move 2 — `firebase.json` carries `firestore.rules` pointer

- `firebase.json` gained a top-level `"firestore": {"rules":
  "firestore.rules"}` block between the existing `functions` array
  and `hosting` block. Three lines, no other changes.
- Why this matters: the M14 milestone's definition of done in
  `docs/VISION.md` requires `firebase deploy --only firestore:rules`
  to land. Before this push, that command would have failed
  immediately ("no rules configured") and required a config edit
  in between. Now `firebase deploy --only firestore:rules,hosting
  --project noum-d0b6f` is a literal one-shot command. The deploy
  itself remains pending Jordan's explicit greenlight — that's
  operational, not engineering.

### Move 3 — `docs/CURRENT_STATE.md` updated

- Header trail-of-breadcrumbs (line 3) gets two new bullets so a
  cold-read of the doc tells you what's new since the last push:
  the Profile Ask Noum entry, and the `firebase.json` fix.
- The Ask Noum section (lines 162–198 previously) gets a new
  Profile entry bullet positioned BEFORE the Post-session entry —
  the entry order now reads Home → Profile → Summary, matching the
  visual hierarchy a user would discover them in (Home tab,
  Profile tab, then post-rep flow).
- The Hosted privacy policy URL block under "Stubbed /
  placeholder" is rewritten to reflect the resolved config gap —
  no longer says "firebase.json needs the block added", now says
  it carries it. Deploy itself still flagged as pending.

## What did NOT change

- `Noum/ContentView.swift` — untouched. The home `askNoumPromoCard`
  + the existing `noum://ask` deep-link route at lines 1718–1720
  are the navigation owner; the new Profile link is just a
  consumer of that same route. No new `AppDestination` case, no
  navigationPath binding bleed into Profile.
- `Noum/SummaryView.swift` — untouched. The post-session bridge
  preserves its session-anchored opener seeding pattern (different
  contract from the Profile ambient handoff). Both can coexist —
  Profile fires ambient, Summary fires rep-anchored, neither
  overlaps the other.
- `Noum/AskNoumStore.swift`, `Noum/AskNoumView.swift`,
  `Noum/AICoachChatService.swift`, `Noum/CoachContextBuilder.swift`
  — all untouched. The third entry point reads from the same
  store, surfaces the same view, runs the same provider chain.
- `firestore.rules` — untouched. The file is correct; the
  `firebase.json` was the only piece blocking the literal one-shot
  deploy command.
- Brand voice rules respected: link copy carries no exclamations,
  no "Let's", no chirpiness, no emoji. The arrow glyph
  (`arrow.right`) matches the chevron pattern the existing
  promo/bridge cards use.
- Design tokens pulled from `DesignSystem.swift` (`AppColor.pro`,
  `Spacing.lg`) and `Typography.swift` (`Typography.caption`).
  No literal hex, no magic spacing, no bespoke fonts.
- `Localizable.xcstrings` — untouched. Link copy is English-only
  per the M13 honest gap. Future localisation pass picks this up
  alongside the rest of the Ask Noum copy.

## Risks

1. **Three entry points might feel like the coach is being
   "pushed."** The home promo is a hero card; the summary bridge
   is a small inline button; the new Profile link is the smallest
   surface of the three (no card, no glyph, single-line link).
   The gradient of size matches the gradient of intent: ambient
   discovery (home), in-the-moment (summary), goal-anchored
   reflection (profile). Acceptable risk; if the link feels too
   pushy in QA, the gate already silences it for pre-onboarding
   sessions and could be downgraded further (e.g. only show when
   `baseline.measuredDistanceFromGoal` returns nil-or-not-good).
2. **Voice-catalogue drift across three surfaces.** All three
   catalogues (`askNoumPromoHeadline`, `askCoachBridgeHeadline`,
   `askNoumProfileLabel`) are independent copy maps keyed by
   `SpeakingStyleGoal`. If a future move adds a 7th voice, three
   sites need editing. Acceptable: the catalogue pattern is
   intentional (each surface has its own register — ambient,
   rep-anchored, goal-anchored), and a shared catalogue would
   collapse them into one register and lose the voice texture.
3. **`openURL("noum://ask")` round-trips through the URL handler
   instead of pushing the destination directly.** This adds one
   extra hop relative to the home promo's
   `navigationPath.append(AppDestination.askNoum)` pattern. The
   `DeepLinkRouter` handler at `ContentView.swift:1718` already
   resets `navigationPath` and pushes `askNoum`, so the user
   lands in the same place — but if the Profile is inside a deeper
   nav stack, the route reset would pop those parents. Profile is
   the tab root in this codebase (handled in `ContentView` as a
   destination, not nested under anything that needs preserving),
   so the reset is a no-op. If a future move adds a sub-stack
   under Profile, this link should be re-evaluated.
4. **`firebase.json` change doesn't trigger any CI we have on
   Linux.** The cloud sandbox here has no `firebase-tools`. The
   block is the documented contract; visual verification of the
   one-shot deploy command landing requires a local `firebase
   deploy --only firestore:rules --dry-run` pass before Jordan
   greenlights the actual deploy.
5. **Profile coaching-card density.** Adding a fifth row (after
   goal text → progress ring → reflections → insight) raises the
   card's vertical footprint slightly. The link is `Typography.
   caption.weight(.semibold)` (small) with `padding(.top, 2)`, so
   the height bump is ~16pt. Below the iPhone 12-Pro fold on a
   long-reflection user, but the Profile is a vertical scroll —
   the card stays the same width and the rest of the page just
   scrolls one beat further. Acceptable.

## Verification

### Implemented

- `ProfileView.askNoumProfileLink` mounts inside
  `coachingDirectionCard`, gated on `coachingProfileStore.profile
  != nil`, fires `openURL("noum://ask")`.
- `ProfileView.askNoumProfileLabel(for:)` returns voice-shaped
  copy for every `SpeakingStyleGoal` case + the nil case.
- `firebase.json` carries the `"firestore": {"rules":
  "firestore.rules"}` top-level block.
- `docs/CURRENT_STATE.md` trail-of-breadcrumbs entry + new
  Profile entry bullet + privacy-policy block rewrite.

### Partially implemented

- None.

### Blocked / needs visual QA on device

- The new Profile link has not been visually verified in this
  push (cloud sandbox, no Xcode toolchain). The three critical
  visual checks for QA:
  1. **Coaching Direction card layout**: link sits cleanly under
     the existing coaching insight text, no awkward gap, no
     overlap with the reflections block above when the user has
     captured all three reflection answers.
  2. **Voice-catalogue shape**: each of the 7 catalogue entries
     (6 voices + nil) reads in the same register as its sister
     entries in `askNoumPromoHeadline` and
     `askCoachBridgeHeadline`. Spot-check by setting each voice
     in Settings and screenshotting Profile.
  3. **noum://ask deep link round-trip**: tap from Profile pops
     to Home root and pushes the AskNoumView destination (because
     the `DeepLinkRouter` handler at `ContentView.swift:1718–1720`
     resets `navigationPath` before appending). Visual
     verification: Profile → tap link → AskNoumView lands
     cleanly with empty-state copy in the user's voice.

### Assumptions

- `openURL("noum://ask")` is the right navigation contract for
  the Profile entry point. Pattern verified against the existing
  deep-link consumer at `ContentView.swift:1718`. Resets the
  nav path before appending, so the user lands at AskNoum with
  no Profile-stack ghost behind them. Acceptable — once the
  user is talking to the coach, the previous Profile state isn't
  load-bearing.
- The `if coachingProfileStore.profile != nil` gate is the right
  silence condition. Stricter gates considered (e.g. require a
  goal to be set, require `≥ 1` finished session) but the
  Coaching Direction card itself already needs a profile to
  render its existing contents — adding a stricter gate on the
  link would create asymmetric visibility within the same card.
- The arrow-glyph (`arrow.right`) matches the chevron pattern
  the existing two promo/bridge surfaces use. Verified by
  reading `askCoachBridgeCard` (line 1786–1793 of SummaryView)
  and `askNoumPromoCard` (line 1077–1085 of ContentView) —
  both use `Image(systemName: "arrow.right")` with the same
  `font(.caption.weight(.bold))` + `foregroundStyle(AppColor.pro)`
  pattern. One visual rhythm across all three coach entry
  points.

### Verification (what was checked)

- All file reads + edits applied via Edit / Write tools; no
  Bash builds run (sandboxed Linux environment, no Xcode
  toolchain).
- `grep` after the ProfileView edit confirmed the new
  `askNoumProfileLink` and `askNoumProfileLabel` symbols land
  exactly once in the file with no accidental duplication into
  the SummaryView or ContentView equivalents.
- The deep-link route `case "ask", "asknoum":` is confirmed in
  `ContentView.swift:1718–1720` — the new Profile link is just a
  consumer of that already-registered route. No new route added,
  no `AppDestination` enum case added.
- `firebase.json` JSON validity: the new `firestore` block is a
  top-level sibling of `functions` and `hosting`, comma after
  the `functions` array close (line 19), comma before the
  `hosting` key (line 23). Matches the schema documented at
  firebase.google.com/docs/cli#initialize_a_firebase_project.
- The `firestore.rules` file referenced by the new block exists
  at the project root (confirmed via `ls firestore.rules`), so
  the deploy command will find it.
- `CoachingProfileStore.profile` access pattern in ProfileView is
  identical to the existing `if let profile = coachingProfileStore.
  profile` read at the top of the same `coachingDirectionCard`
  body — same store, same nullability contract.

### Risks

- See "Risks" section above.

## Files modified

- `ProfileView.swift` (+58 LOC — `askNoumProfileLink` + helper).
- `firebase.json` (+3 LOC — `firestore.rules` pointer block).
- `docs/CURRENT_STATE.md` (trail-of-breadcrumbs + Ask Noum
  section Profile bullet + privacy-policy block rewrite).
- `HANDOFF.md` (rewritten — this file).

## Branch

`Redesign` — committed and pushed per the brief. The user
explicitly requested work on the Redesign branch ("ensure
working on the redesign branch too (very important)"). All
M14 commits land here; this push continues that pattern.
