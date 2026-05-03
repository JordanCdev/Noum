# audit-feature

Senior-engineer / senior-designer review of a single Noum feature. Given a feature name (e.g. "Cut the Crutch", "Daily Goal Ring", "Streak Freeze"), produces a structured audit covering whether it actually works, reads on-voice, handles edge cases, matches the design spec, and what's stubbed vs shipping.

## When to invoke

- The user says a feature "feels off" or "doesn't seem right"
- After shipping a non-trivial feature, before considering it done
- Periodically as a health check on shipping features

## Invocation

```
/audit-feature <feature name or area>
```

Examples:
- `/audit-feature Cut the Crutch`
- `/audit-feature Daily Goal`
- `/audit-feature Settings screen`
- `/audit-feature Notifications`
- `/audit-feature Onboarding flow`

If the user invokes this skill without specifying a feature, ask which one — don't audit "the whole app" in one pass; the report stops being useful.

## How the skill runs

1. **Confirm scope.** Echo back the feature being audited and the files/symbols you'll cover. If the user doesn't push back, proceed.
2. **Spawn an Explore sub-agent** with the structured prompt below. The sub-agent reads the relevant Swift files, traces user flow paper-end-to-end, and returns its findings.
3. **Write the report** to a markdown buffer in the conversation (do not write to disk unless asked). Keep it under ~800 words.
4. **Highlight the top 3 issues** at the bottom in a one-line "if you fix nothing else, fix these" section.

## Sub-agent prompt template

When invoking the Explore sub-agent, brief it like this:

```
Audit the "{feature name}" feature in the Noum iOS app at /Users/jordan/src/GitHub/Noum.
Repo conventions live in `Noum/Claude.MD` and `.claude/skills/noum-design/README.md`.
Design tokens live in `Noum/DesignSystem.swift` (the Swift source wins on conflict).
Current vs goal state live in `docs/CURRENT_STATE.md` and `docs/VISION.md`.

For this feature, return a structured audit covering:

1. **Files involved** — list the implementation files with one-line summaries.

2. **Does it actually work end-to-end?** Trace the user flow from entry to exit.
   Flag any path that compiles but doesn't behave (e.g. UI exists but no backing
   data, completion handler that goes nowhere, persistent state that never reads
   back).

3. **Voice / copy** — every user-facing string. Flag:
   - "Let's", chirpy copy, exclamation marks, emoji
   - User-authored text dropped into UI without paraphrase or quotation
   - Lock-screen-visible strings that quote sensitive user input
   - Generic boilerplate that should be specific

4. **Accessibility** — for every interactive element:
   - VoiceOver label + hint present?
   - Dynamic Type holds at .accessibility3?
   - Reduce-motion respected on animations?
   - 44pt min hit targets?

5. **Edge / empty / error states** — what happens when the input is empty,
   the network is down, the user has no permissions, the data is malformed?

6. **Design spec alignment** — tokens (no literal hex / spacing magic numbers),
   corner radii (only the 4 values), card shape, mode tints, animation springs.
   Flag any deviation.

7. **Per-account scoping** — any persisted state should be keyed by accountID.
   Check the wipe list in `AuthManager.clearAllUserData` covers the feature's keys.

8. **Coupling** — what else does this feature touch? Could a small change here
   ripple? (Example: PracticeMode enum has 72 switches across 9 files.)

9. **Stubbed vs shipping** — be specific. "X is implemented" ≠ "X works in
   production for a real user". Flag features that look done but fake their
   output, hardcode their progress, or skip a real round-trip.

10. **Top 3 issues if you fix nothing else** — the highest-leverage 1-line fixes.

Be concrete. File:line refs everywhere. Under 800 words. No hedging.
```

## Output format

The skill's final reply to the user follows this shape:

```markdown
# Audit: {Feature name}

**Files** (4): `CutTheCrutchEngine.swift`, `CutTheCrutchView.swift`, …

## Does it work end-to-end?
{Trace the flow. Flag broken paths.}

## Voice & copy
{Issues with strings.}

## Accessibility
{Gaps.}

## Edge / empty / error states
{What's missing.}

## Design spec
{Token compliance, deviations.}

## Per-account scoping
{Persistent state audit.}

## Coupling
{What else this touches.}

## Stubbed vs shipping
{What looks real but isn't.}

---

**Top 3 fixes:**
1. {one-line fix}
2. {one-line fix}
3. {one-line fix}
```

## What this skill is NOT

- Not a code review for individual diffs (use git diff + the standard review flow)
- Not a UI test runner (use XCUITest)
- Not a performance audit (use Instruments)
- Not an automated check that runs on every commit (use a Stop hook for that)

It's a **focused, manual, on-demand review** for "this feature feels off — tell me why."

## Limitations

- Cannot run the simulator. The audit reads code + traces flow logically; it cannot
  observe runtime behavior. For runtime issues, the report must say so explicitly
  ("this needs to be exercised in the simulator to confirm").
- Cannot test against a real backend. Backend-coupled features get flagged as
  "needs end-to-end test on TestFlight" rather than "broken".
- Voice is judged against `Claude.MD` rules and the `noum-design` skill's
  README, not subjective taste. If you disagree with a voice flag, the skill
  is wrong less often than it's right, but it's not infallible.
