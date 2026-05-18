# Routine 4 — Localization migration (Night, 21:00 daily)

## Slot
Night, 21:00 local time.

## Purpose
Per M13's known gap (`docs/VISION.md`): "The catalog covers ~30 keys today. Hundreds of strings remain hardcoded across the app." This routine batch-migrates 10–20 hardcoded English strings per night into the `Localizable.xcstrings` catalog. Pure copy work — perfect for cloud agents.

## Prompt

```
You're the M13 localization migration grinder. Every night, batch-migrate 10–20 hardcoded English strings into the `.xcstrings` catalog. M14 ships TestFlight; M13's known gap is the long tail of strings still hardcoded.

Running on Linux. Read + edit Swift + edit `.xcstrings` (JSON). No iOS Simulator.

## Required reading (every run)

1. `CLAUDE.md`
2. `docs/VISION.md` — M13 "Honest gaps remaining" section
3. `Noum/Noum/Localizable.xcstrings` — current catalog. Understand the schema. Note which keys exist.
4. The last 7 `.screenshots/<date>_localization/HANDOFF.md` to see what was migrated already

## Pick today's batch

Priority order for what to migrate next:
1. **Summary card bodies** — `Noum/Noum/SummaryView.swift` and any nested cards in the summary flow. High user-impact, frequent surface.
2. **Profile section headers beyond simple labels** — anything not already covered by `SettingsSectionLabel(LocalizedStringKey)`.
3. **AI Coach setup copy** — `Noum/Noum/CoachingOnboardingView.swift` and related.
4. **Practice mode descriptions** — `Noum/Noum/PracticeModeSelectionView.swift` mode subtitles.
5. **Empty states** — `Noum/Noum/EmptyStateView.swift` and call sites.

Pick the FIRST source file from this list that has 10+ unmigrated strings. Migrate from that file. Don't spread across files in one run — it's a worse PR.

## Migration mechanics

For each string:
1. Generate a key in the convention `<surface>.<context>.<purpose>` (e.g. `summary.eloquenceCard.headline`). Match existing naming conventions in the .xcstrings file.
2. Add the key to `Localizable.xcstrings` with the English source string + empty `es-ES` + `fr-FR` entries (marked `state: "translated"` if you're confident, `state: "new"` otherwise — default to "new" for safety).
3. Replace the hardcoded Swift string with `Text("<key>")` or `String(localized: "<key>")` as appropriate to the call site.
4. NEVER change the rendered English — the migration must be functionally invisible.

## Brand + engineering rules

- Voice unchanged. This is mechanical migration, not a copy rewrite. If you find a voice violation while migrating, FLAG it in HANDOFF for routine 3 (voice audit) to address — don't fix it here.
- Existing `.xcstrings` conventions preserved: same key style, same sourceLanguage, same JSON shape.
- Spanish + French translations: only fill in if (a) the source string is clearly translatable without context (single word labels, numbers + units), or (b) it's identical to an already-translated key. Otherwise leave empty + `state: "new"`. Translation quality matters more than translation count.

## Write HANDOFF.md at `.screenshots/<YYYY-MM-DD>_localization/HANDOFF.md`

Sections:
- File migrated + number of strings (e.g. `SummaryView.swift — 14 strings`)
- Catalog growth (key count before → after)
- Surfaces needing visual verification (every view file touched needs a screenshot pass to confirm rendering identity)
- Spanish/French keys filled in vs. left as `state: "new"` (count of each)
- Branch name + commit SHA

## Commit policy
- Commit on `cloud/loc-<source-file>-<YYYY-MM-DD>`. Push.
- One commit per source file. Message: `loc: migrate <file> strings into xcstrings`.

## Don't
- Don't change the rendered English.
- Don't auto-translate creative copy ("Push a sharper rep" → ?? — leave for human translation).
- Don't refactor.
- Don't migrate strings from more than one source file per run.
- Don't open PRs.
```
