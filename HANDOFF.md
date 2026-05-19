# HANDOFF — Review screen dream pass

## What changed

`Noum/SessionHistoryView.swift` — summary strip hero, per-mode session row stripe, Replay/Mistakes hero halos, premium section sentence.

### Summary strip hero treatment
- **`summaryStrip`** (`Noum/SessionHistoryView.swift:227-238`). Replaced the opaque `AppColor.cardBackground` rounded rectangle with the new `heroBackground(tint:cornerRadius:)` helper — opaque white base + top-anchored brand-blue `RadialGradient` (0.12 → 0.03 → clear, endRadius 320) + 0.18-opacity brand-blue hairline border. Added soft brand-blue shadow (0.14 opacity, 14pt radius, 6pt y-offset). Brand-blue is the rating/analytics register, which is the right home for the Sessions/Avg Score/Strongest read.

### Hero background helpers
- **`heroBackground(tint:cornerRadius:)`** (`Noum/SessionHistoryView.swift:246-260`). Mirrors `HomeCoachCard.coachCardBackground` / `LeagueView.tierCardBackground` shape: card base + top-anchored radial tint + faint stroke border. Used by `summaryStrip`.
- **`heroHalo(tint:)`** (`Noum/SessionHistoryView.swift:266-278`). Tinted ambient glow that bleeds beyond a wrapped card's edges via negative padding + blur — used for the Replay / Mistakes cards because their internals already paint an opaque `cardBackground` and the spec said not to touch them. The halo + tinted shadow are the visible hero treatment.

### Session row mode-tint stripe
- **`sessionRow(_:)`** (`Noum/SessionHistoryView.swift:384-442`). Was: a 4×48pt rounded-rect stripe pinned to the top with a `.padding(.top, 4)`. Now: a 4pt-wide stripe with `.frame(maxHeight: .infinity)` inside an `HStack(alignment: .top, spacing: 0)` so it stretches to the row's natural height. Switched the color source from a local `modeColor(for:)` to the canonical `AppColor.tint(for:)` so Timed=blue, Sudden Death=orange, Ah-Counter=green, IM=indigo all come from the same token set the rest of the app uses. The row wraps in `.clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))` so the stripe conforms to the card's rounded left edge cleanly. Removed the now-unused `modeColor(for:)` helper.

### Replay misses + Mistakes to fix hero halos
- **MistakeReplayCard wrap** (`Noum/SessionHistoryView.swift:128-134`). Wrapped with `.background(heroHalo(tint: mistakeReplayHaloTint))` + `.shadow(color: mistakeReplayHaloTint.opacity(0.16), radius: 16, x: 0, y: 8)`. The tint comes from `mistakeReplayHaloTint` (`Noum/SessionHistoryView.swift:81-98`), which mirrors the card's own sourcing priority (most recent low-score ≤5 in 14d → most recent high-filler ≥6 in 14d → brand-blue fallback). So the halo color matches the mode of the session the user is most likely about to replay. Card internals untouched.
- **WeakAreasCard wrap** (`Noum/SessionHistoryView.swift:140-146`). Wrapped with `.background(heroHalo(tint: AppColor.brandBlue))` + brand-blue shadow. This card surfaces durable analytics-level weaknesses, so the analytics/rating tint is the right register. Card internals untouched.

### "All sessions" section sentence
- **Section header block** (`Noum/SessionHistoryView.swift:152-164`). Was: `Text(sectionTitle)` rendered as `subheadline.weight(.semibold)` + `.textCase(.uppercase)` + secondary tint — a small-caps wireframe label. Now: `Typography.cardTitle` (20pt Figtree bold) + primary tint + a 1pt `AppColor.subtleBorder` hairline underneath. Reads as a premium app sentence.
- **`sectionTitle`** (`Noum/SessionHistoryView.swift:470-475`). Changed `"All Sessions"` → `"All sessions"` and `"<Mode> Sessions"` → `"<Mode> sessions"` to match the noum-design sentence-case rule.

## What did NOT change

- `MistakeReplayCard.swift` and `WeakAreasCard.swift` internals — visual chrome only, applied externally via `.background(heroHalo)` + `.shadow`.
- `SessionHistoryDetailView` (the per-session push) — untouched.
- Empty state (`emptyState`, `emptyFilterState`) — untouched.
- Session ordering, mode filtering, delete alert, context menu, navigation routing — untouched.
- Trends panel (`trendsSection`, `miniTrend`) — untouched. The summary strip is the only hero in the top stack; trends stay as a quiet disclosure row by design.
- Mode filter chips (`modeFilterChips`, `filterChip`) — untouched.
- The `history.row.<uuid>` accessibility identifiers and `history.screen` ID — preserved (UI test contract).
- No new managers, stores, routes, or state ownership introduced.

## Verification

- File reads cleanly end-to-end after edits; `modeColor(for:)` removed because no remaining call sites use it. All other helpers (`modeLabel`, `scoreColor`, `sessionOneLiner`, `averageScore`, `trendDelta`) intact.
- Tint source for the row stripe is now `AppColor.tint(for:)` — same helper used by HomeCoachCard, LeagueView, MistakeReplayCard internals, so per-mode color is consistent across the app.
- Halo + shadow live outside each card's `.background(AppColor.cardBackground, in: ...)` paint, so the card's own internal structure (header, rows, stroke overlay, scale-in animation) renders unchanged.
- No build performed (per the brief).

## Risks

- `heroHalo` uses `.padding(-10)` to bleed the radial fill ~10pt beyond the wrapped card's silhouette. In the unlikely case the wrapped card has its own clip that doesn't include negative-padded backgrounds, the halo could be cropped — but neither `MistakeReplayCard` nor `WeakAreasCard` applies an outer clip, so the bleed lands as intended. The blur (10pt) keeps the edge soft.
- The session row's leading stripe relies on `HStack(alignment: .top) + .frame(maxHeight: .infinity)` to stretch the stripe to the tallest sibling's height. If the right-side content collapses to a single line (e.g., a session with no `headline`, no `coachSummary`, no fillers), the stripe will be ~24pt instead of the prior fixed 48pt — but the row in that minimal state is also visually shorter, so the stripe still reads correctly as a full-height accent. Acceptable.
- The MistakeReplay halo tint is derived in the SessionHistoryView level (not exposed from the card itself), so the priority logic is duplicated from `MistakeReplayCard.rows`. If that card's sourcing rules evolve, this tint will drift. Trade-off: avoids changing the card's public surface for a visual-chrome change. Worth a future tidy if the rules grow.
