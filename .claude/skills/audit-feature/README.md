# audit-feature

A senior-engineer / senior-designer review skill for Noum features. Use when something feels off and you want a structured second opinion.

## Quick start

In Claude Code, type:

```
/audit-feature <feature name>
```

Examples:
- `/audit-feature Cut the Crutch`
- `/audit-feature Daily Goal`
- `/audit-feature Streak Freeze`
- `/audit-feature Settings screen`
- `/audit-feature Onboarding flow`
- `/audit-feature Rating chart`

Claude will produce a structured audit covering:

1. **Files involved** — what's in scope
2. **Does it work end-to-end?** — trace the user flow, flag broken paths
3. **Voice & copy** — flags chirpy copy, leaked user text, generic boilerplate
4. **Accessibility** — VoiceOver, Dynamic Type, reduce motion, 44pt targets
5. **Edge / empty / error states** — what happens when things break
6. **Design spec alignment** — tokens, radii, springs, mode tints
7. **Per-account scoping** — persisted state + wipe list coverage
8. **Coupling** — what else this feature touches
9. **Stubbed vs shipping** — features that look done but aren't
10. **Top 3 fixes** — highest-leverage one-line action items

## When to use this skill

- A feature feels off but you can't pinpoint why
- Before declaring a non-trivial feature "done"
- Periodic health-checks on already-shipped features
- Pre-release sanity sweeps

## When NOT to use this skill

- Reviewing a single PR diff — use a normal code review pass
- Performance issues — use Instruments
- Layout debugging — use Xcode previews + the simulator
- Backend integration testing — needs runtime verification, this skill can only flag the gap

## What the report does NOT replace

- Running the feature on a real device
- Watching a real user use it
- TestFlight feedback
- Designer review of pixel-level rendering

The skill is good at structural and conventional issues. It cannot see how a feature *feels* under thumb. Always run the simulator after a fix.

## Files

- `SKILL.md` — invocation rules + sub-agent prompt template
- `README.md` — this file
