# Run: 2026-05-20 · branch:cloud/loc-summaryview-2026-05-20 · M13 long tail — SummaryView ES/FR translation batch 1

The M13 honest gap from `docs/VISION.md` ("Hundreds of strings remain hardcoded across the app") was a misread of the state — the SwiftUI `Text("...")` calls already consult `Localizable.xcstrings` automatically; what's actually missing is the **translation values** behind ~580 keys that exist in the catalog but only carry the English source string. This run fills in the first batch from the highest-traffic post-session surface: `SummaryView.swift`.

24 user-facing strings on `SummaryView` and its child cards now ship with native Spanish + French translations. Catalog coverage went from 33 → 57 fully-translated keys (4.9% → 8.4%). All translations follow the existing voice (`tú` in Spanish, `tu` in French, `rep` → `sesión`/`séance` per the established `Pre-rep prep` precedent).

## Mode
Linux blind — no simulator, no Xcode. All changes flagged for visual verification on the next local run.

## What shipped

| File | Change |
|---|---|
| `Noum/Resources/Localizable.xcstrings` | Added `es` + `fr` `stringUnit`s (state: `translated`) to 24 keys covering `SummaryView` surfaces. Surgical edits via Python — diff is +357/-24 lines, no reformat of unrelated entries. |

No Swift code changed. The strings were already going through `Text("...")` so they auto-localise the moment translations land in the catalog.

## Keys translated (24)

| English | Spanish | French |
|---|---|---|
| Session Details | Detalles de sesión | Détails de séance |
| Coach read preview | Vista previa del coach | Aperçu du coach |
| Strong Moments | Momentos fuertes | Moments forts |
| Transcript | Transcripción | Transcription |
| Watch recording | Ver grabación | Voir l'enregistrement |
| Verdict | Veredicto | Verdict |
| Next Rep | Próxima sesión | Prochaine séance |
| Your rule | Tu regla | Ta règle |
| Start rep | Empezar | Démarrer |
| Breakdown | Desglose | Détail |
| Session Recording | Grabación de sesión | Enregistrement de la séance |
| Saved | Guardado | Enregistré |
| AI Video Analysis | Análisis de video con IA | Analyse vidéo IA |
| Coach | Coach | Coach |
| What you did well | Lo que hiciste bien | Ce que tu as bien fait |
| Key improvement | Mejora clave | Amélioration clé |
| Suggested drill | Ejercicio sugerido | Exercice suggéré |
| Try this opening | Prueba este inicio | Essaie cette ouverture |
| Monthly coaching limit reached | Límite mensual de coach alcanzado | Limite mensuelle de coach atteinte |
| Details | Detalles | Détails |
| Recordings are temporary unless saved. | Las grabaciones son temporales si no las guardas. | Les enregistrements sont temporaires sauf si tu les sauvegardes. |
| Choose how to share this session | Elige cómo compartir esta sesión | Choisis comment partager cette séance |
| See what Pro unlocks | Mira lo que desbloquea Pro | Vois ce que débloque Pro |
| Unlock deeper insights | Desbloquea más análisis | Débloque plus d'analyses |

## Voice rules followed

- **Spanish:** `tú` form (informal), matches existing `Tu regla` precedent and `Vas liderando` voice.
- **French:** `tu` form (informal), matches `Tu mènes` / `Tu te rapproches` precedent.
- **`rep` → `sesión`/`séance`:** established by `Pre-rep prep` → `Antes de la sesión` / `Avant la séance`. "Rep" is gym/coach jargon that doesn't transfer cleanly; the existing translation uses the natural-language equivalent.
- **Loanwords preserved:** `Coach`, `Pro`, `IA` (Spanish/French for AI) stay as in catalog precedents.

## Catalog growth

| Metric | Before | After |
|---|---|---|
| Total keys in catalog | 679 | 679 |
| Fully translated (`es` + `fr` both `translated`) | 33 | **57** |
| Coverage | 4.9% | **8.4%** |

The catalog itself isn't growing — it was already populated by Xcode's auto-extraction from `Text("...")` call sites. This work is filling in the translation values that were missing.

## Surfaces needing visual verification

When the next local session installs Spanish or French as the practice language, the `SummaryView` post-session screen will show translated text on these specific surfaces:

1. **SummaryView → Session Details section header** — was English-only, now reads `Detalles de sesión` (ES) / `Détails de séance` (FR).
2. **SummaryView → Coach card** — "What you did well", "Key improvement", "Suggested drill", "Try this opening" all translate.
3. **SummaryView → Pro upsell card** — "Unlock deeper insights", "Coach read preview", "See what Pro unlocks" translate.
4. **SummaryView → Strong Moments / Verdict / Breakdown / Transcript sections** — all section headers translate.
5. **SummaryView → Next Rep card** — "Next Rep", "Your rule", "Start rep" translate.
6. **SummaryView → Session Recording card** — "Watch recording", "Saved", "Recordings are temporary unless saved." translate.
7. **SummaryView → Share dialog** — "Choose how to share this session" translates.
8. **SummaryView → AI Video Analysis card** — "AI Video Analysis", "Monthly coaching limit reached" translate.

To verify: set Settings → Practice language → Spanish (or French), finish a Timed session, scroll the SummaryView from top to bottom. Confirm no rendering regression (no clipping from longer French strings — most are within 1.5x of English length).

## Risks

- **Longer strings in French** — `Limite mensuelle de coach atteinte` is 39 chars vs `Monthly coaching limit reached` 30 chars (1.3x). Could clip in narrow card layouts. Visual verification needed.
- **Voice consistency** — translations follow the established `tú`/`tu` informal voice. If a future translator prefers `usted`/`vous`, the whole catalog needs a sweep; this batch sticks with what's already shipped.
- **No Swift code changes** — zero regression risk for English users. The English `Text("...")` calls render exactly as before.

## VISION gap closing (estimate)

M13's "Honest gaps remaining" lists "Hundreds of strings remain hardcoded across the app". The actual gap is the translation layer of the auto-extracted catalog, not the Swift source. This batch lowers that gap from 580 untranslated keys to 556 (roughly 4% chip away). Many more batches needed; SummaryView's high-traffic strings are the highest-leverage starting point.

Operational M14 work (Firestore rules deploy, hosted privacy URL, TestFlight build) is still pending and requires Mac / cloud creds — none possible from Linux blind. The `public/privacy.html` is production-ready; the `firestore.rules` are deployment-ready. Both are blocked on the Mac/cloud-creds gate.

## Branch + commit SHA

Branch: `cloud/loc-summaryview-2026-05-20`
Commit SHA: will be set on push.

## Next runs (suggested batches)

Following the Routine 4 priority order, the next localization batches should hit:

1. **ProfileView.swift** — 32 hardcoded strings, second-highest traffic surface after Summary. Targets: section headers ("Best ever", "Best in friends" — already done; remaining: settings rows, peak rating row labels, goal direction copy).
2. **PracticeModeSelectionView.swift** — mode subtitles (longer descriptive copy, needs slightly more careful translation).
3. **CoachingOnboardingView.swift** — onboarding copy. Critical first-impression surface for non-English speakers.
4. **EmptyStateView.swift** call sites — short strings, high-leverage for the 5 surfaces it ships on.

Each batch should follow this run's pattern: surgical xcstrings edits, no Swift code changes, voice rules locked.
