# Run: 2026-05-19 · branch: claude/relaxed-davinci-yTui9 (off Redesign) · M14 progress

Continued M14 work on top of the Redesign branch. Two concrete pushes:
the test compile blocker is fixed and the WordOfTheDay catalog is now
130 entries (up from 30) on a path toward the documented 365 target.

## What changed

### 1. `NoumTests/NoumTests.swift` — macro type-check timeout repaired

The 2026-05-18 HANDOFF flagged `xcodebuild test` as blocked by a Swift
macro type-check timeout at lines 1581/1611 in `EloquenceEngineTests`.
Root cause: `#expect(...)` macro expansions containing inline closures
in string interpolation (`\(findings.map { $0.device })`). The macro
expansion has to re-type-check an enum-returning closure inside an
interpolation inside the macro body — Swift's inference gives up.

Fix applied across every `#expect` in `EloquenceEngineTests` and the
four `FillerDetectionTests` lines flagged by the original timeout
report (lines 106, 128, 136, 144):
- extracted each closure-returning diagnostic into a `let diag = ...`
  outside the macro;
- added a private `EloquenceEngineTests.devices(in:)` helper so every
  test in the struct shares one diagnostic-formatting path that
  returns `[String]` (raw values), keeping closures off the macro
  call site;
- swapped trailing-closure `.contains(where:)` for the simpler
  `.contains { ... }` form to keep the predicate's type clearly
  inferred before the macro sees it.

No production behaviour changed — these are test-side restructurings
of the `#expect` arguments only.

### 2. `Noum/WordOfTheDay.swift` — catalog 30 → 130 entries

CURRENT_STATE.md listed the catalog at ~30 entries with the documented
gap "needs growth to ~365 to satisfy the 'no repeats inside a year'
target." Added 100 curated entries across ten thematic blocks:

| Block | Count | Examples |
|---|---|---|
| Speaking craft | 10 | Articulate, Cadence, Modulate, Punctuate, Land |
| Judgement and decision-making | 10 | Discern, Calibrate, Vet, Triangulate, Reconcile |
| Character | 10 | Integrity, Steadfast, Principled, Resolute, Disciplined |
| Mind-state | 10 | Present, Attuned, Centred, Grounded, Measured |
| Communication moves | 10 | Surface, Name, Acknowledge, Concede, Bridge |
| Ideas and argument | 10 | Premise, Tenet, Thesis, Caveat, Nuance |
| Action | 10 | Undertake, Embark, Commit, Spearhead, Champion |
| Craft and refinement | 10 | Refine, Sculpt, Render, Temper, Workshop |
| Reflection | 10 | Ponder, Contemplate, Reflect, Mull, Revisit |
| Strength | 10 | Fortitude, Mettle, Grit, Resolve, Persist |

Every new entry honours the four test invariants
(`WordOfTheDayCatalogTests`):
- headword (lowercased) appears in `acceptedForms` (init does this);
- all four display fields non-empty;
- `definition.count <= 90` (verified by grep on the literal);
- `promptSuggestion.hasSuffix("?")` (verified by grep on the literal).

No duplicate headwords vs. the 30 pre-existing entries. Voice is
"trusted speaking coach" throughout — no "Let's", no exclamations, no
emoji, brand-rule clean.

## What's still open

- **Continue catalog growth to 365.** 235 more entries to reach the
  documented "no repeats in a year" target. Same template, same
  invariants. Pure content work, no engineering risk.
- **M14 operational items unchanged:**
  - `firebase deploy --only firestore:rules` — Linux env can't deploy.
  - Public privacy URL hosting via `public/privacy.html` —
    Firebase Hosting deploy still needs to happen from a session that
    has `firebase` CLI authenticated.
  - TestFlight build cut against real hardware — Mac/Xcode required.
- **NoumTests verification.** The macro-timeout fix is a structural
  refactor that should resolve the type-check blowup, but I can't run
  `xcodebuild test` from Linux. Next local session should run the
  test target end-to-end to confirm the compile completes and the
  EloquenceEngine + FillerDetection tests still pass behaviourally.

## Surfaces needing visual verification

- **`WordOfTheDayTile`** on populated home — render with several of
  the new entries (catalog selection is hashed, so this needs date
  manipulation or a fixed seed) to confirm:
  - definitions render on a single line on iPhone 15 widths;
  - prompt fits the existing two-line clamp without truncating
    awkwardly on the longer prompts (e.g. "Whose ears would you most
    trust to workshop something half-finished with?");
  - none of the new headwords cause a layout regression next to
    existing partOfSpeech tags ("verb"/"noun"/"adjective" only —
    no new POS introduced).

## Branch / commit

- Branch: `claude/relaxed-davinci-yTui9` (rebased onto `Redesign`).
- Files touched:
  - `NoumTests/NoumTests.swift` — macro-heavy `#expect` calls split
    into intermediate let-bindings.
  - `Noum/WordOfTheDay.swift` — 100 new `WordOfTheDayEntry` literals
    appended.
  - `docs/CURRENT_STATE.md` — catalog count + gap note updated to
    reflect 130/365.
  - `.screenshots/2026-05-19_relaxed-davinci/HANDOFF.md` — this file.

## VISION gap closing

- **Believable progress / personalised coaching pillars.** Growing
  the vocabulary catalog from 30 → 130 entries quadruples the
  expected gap between repeats. A user opening the app daily now
  sees substantially more variety before any single word recurs —
  the "small daily commitment point distinct from a full rep"
  becomes meaningfully durable rather than running out after a
  month.
- **No new engineering risk.** Catalog growth is pure literal
  expansion against tested invariants. The test-compile fix unblocks
  CI for the next local session.
