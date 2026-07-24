# Figma Design Gate — Decisions

**Date:** 2026-07-24 · **File:** https://www.figma.com/design/srCgE5IP3rWoNMWtHo3AnI/
**Method:** two full-fidelity variants per surface (page 02), five independent critic lenses (IA/flow, visual, accessibility, coaching-content, SwiftUI feasibility), decision synthesized from verdicts — the designer did not approve its own work.

## Approved system — "One hero" hybrid

**Today = variant B's focal violet hero. Review = variant A's transcript-first sheet. Progress = variant A's trajectory narrative.**

Critic tally: Review A won 3–1 (a11y preferred B's labeled structure — folded in via VoiceOver labels, not visible compartments). Progress A won 4–0. Today split 2–2 (IA+visual → B; a11y+coaching → A) and was resolved by the visual critic's system rule, which all lenses' fixes converge on:

> **The violet gradient hero is the app's single marquee moment and appears exactly once: Today's prescription. Everywhere else is open editorial — violet caps eyebrow, big ink headline, short violet rule, content directly on the warm canvas.** Two gradient heroes two tabs apart turn the coach's voice into wallpaper.

### System rules (bind everything downstream)

1. **One hero per app.** Gradient = the startable daily brief on Today only. Review/Progress/You never use a gradient surface (Review's retry block, Progress's trajectory stay editorial).
2. **Color roles are semantic and exclusive.** Violet = coach voice + evidence accents (eyebrows, quote bar, diff emphasis, plan chips). Blue = the startable action, always a full-width pill on the canvas — moved OUT of the hero so the hero announces and the button acts. Green = qualified improvement deltas only ("+2 reps this week", "down from 9%") — never status dots, never "VERIFIED".
3. **Two label levels only.** Violet caps eyebrow = section intent (max 2/screen). Grey caps micro = data annotation. Review-B's third layer (YOU SAID / ONE STEP) is banned as visible UI; its structure lives in VoiceOver labels instead.
4. **One tertiary row per screen**, always the chevron-row pattern ("Stakeholder review · Thursday ›"). No dot-separated text-link clusters — adjustments become two real ≥44pt quiet buttons.
5. **Cards only for evidence objects** (verified quote, rewrite comparison, stat) — everything narrative sits on the canvas.

### Accessibility gates (from the a11y critic, apply at componentization)

- No sub-4.5:1 white-opacity text on gradients: 100% white text; darken the gradient's light stop to ≥ #6D46D6 behind body copy; opacity only on decorative shapes.
- The rewrite diff must be spoken, not just seen: quote+caption grouped as one a11y element with explicit "Your original… / Upgrade — adds 'decide today'…" labels.
- Tab active state gets a non-color cue + `.isSelected`; waypoint dots decorative with a text label ("Stage 3 of 5").
- Micro-labels: minimum caption2 Dynamic Type, ≥4.5:1 (grey → #5A6474, green → #0E7A3B).
- Heroes must survive AX5: no fixed heights, chips wrap vertically, in-card charts demote to text summaries at AX3+.
- Trend bars get an AXChartDescriptor audio graph + summary label; minimum bar fill 3:1.

### Copy corrections (from the coaching critic)

- "WHAT I HEARD" → **"WHAT NOUM HEARD · VERIFIED 0:48"** (Noum is third person).
- "WEEK 1 · PLAN ON TRACK" → **"WEEK 1 · REP 3 OF 4"** (no self-grading).
- "+2 this week" → **"+2 reps this week"** (bounded units).
- "Meaning kept · your words · one lever changed" → **"Same idea — the decision lands first."** (coach, not validator).
- "7/10 · View full evaluation" → **"View full evaluation ›"** with the score inside the disclosure (true score demotion); optionally "7/10 — decision timing is the gap" *inside* the evaluation view.
- Today-B's duplicate evidence line collapses into one provenance row: evidence + plan in a single line under the hero.

### SwiftUI feasibility (assessed against the existing codebase)

All winning patterns have shipped precedents: `HeroGradient` (DesignSystem.swift, beauty pass) covers the Today hero; the floating capsule tab bar already exists (`.regularMaterial` pill in `safeAreaInset`); changed-word rewrite highlighting already renders in SessionHistoryView's upgrade card; trend bars = existing SwiftUI Charts usage. No new state owners required. Keep the existing custom pill nav rather than migrating to native iOS 26 TabView in this cycle; revisit with the Liquid Glass adoption pass.

### Fonts

SF Pro fonts are locally-installed system fonts and render with broken metrics through Figma's plugin/server pipeline. Figma mocks therefore use the design-system README's sanctioned substitutes — **Nunito** (for SF Pro Rounded roles) + **Inter** (for SF Pro Text roles). SwiftUI implementation uses real SF Pro Rounded via `.fontDesign(.rounded)`; the mapping is 1:1 by role in FIGMA_SWIFTUI_COMPONENT_MAP.md.

## Rejected

- **Previous run's entire visual layer** (archived, page 00): flat equal-card stacks on cold grey, navy/cyan coach identity, Figtree/Manrope, label soup, timid type. Root causes fixed at token level (warm canvas, violet coach family) and in the label/card rules above.
- **Review B / Progress B as defaults**: card-stack regression and hero dilution respectively — with their two genuinely good ideas kept (B's bounded evidence bullet copy; B's labeled structure as VoiceOver semantics).
- **Score-first surfaces** anywhere in daily coaching.

## Still to test (not lockable from critique)

- 4-tab vs 3-tab IA: task-test plan with thresholds on page 01; keep 4-tab as prototype until run.
- Live-call identity: three directions (breathing orb / aurora / typographic presence) to be built in 06 and preference-tested.
- Exact motion values on device (tokens carry Reduce Motion zeros already).

---

## Freeze addendum — 2026-07-24 (closing run)

**THE FIGMA GATE IS FROZEN.** Approved frames `109:497` (Today), `110:497` (Review), `111:497` (Progress) are locked except for defects. Changes now follow the decision-log governance: record evidence → propose → update — never silently.

### Closing-run corrections
- Stale-metadata note: Figma's REST metadata endpoint intermittently reports only a subset of pages; the plugin API (`use_figma`) confirmed all ten pages 00–09 exist and is the source of truth.
- Stale Figtree/Manrope foundations board and the old Home/Train/Review/Profile/Settings journey board moved to 00 Archive; fresh foundations board `128:497` states the only valid guidance (Nunito/Inter mocks ↔ SF Pro device; Path under Progress; both IAs are hypotheses; no Material 3 / Simple DS in production frames; iOS 26 kit for native chrome only).
- Scripted lint (Stark/Design Lint are interactive plugins the MCP cannot drive — equivalent checks scripted): 33 unbound texts bound to styles (+4 new role styles: Eyebrow/Button/Chip/Row), 2 decorative fills bound, Quiet button raised to 45pt. Remaining intentional: the one-step diff text is mixed-font by design (the highlight); hero interior whites are raw by design (on-gradient). Run Stark manually in-editor before first TestFlight designs review for certification-grade numbers.
- Live-call: 10-state matrices for all three directions (`131:497` D1, `132:497` D2, `132:554` D3) with Reduce Motion and reproducibility notes (D1 = pure SwiftUI shapes; D2 = Metal/mesh-gradient, needs runtime justification; D3 = cheapest pure SwiftUI). **No winner chosen — preference test required.**
- Product states added (page 05, `133:497–133:712`): first-session minimal evidence, earned-progress arrival, goal-changed (evidence carried over, no identity shaming), low-capacity, no-upcoming-moment, offline.
- IA: H2 Coach/Practice/You wired prototype built (`134:497/530/546`); H1 = approved screens. 17 prototype links verified, zero dead hotspots.

---

## Production polish V2 — 2026-07-24

Page `137:497`. V1 approved frames remain locked; V2 candidates await founder acceptance: Today `138:497` (+dark `150:497`), Review `139:497`, Progress `141:497`. Full record: `artifacts/figma/production-polish-v2/REVIEW.md`.

Key decisions made in this pass:
- **Motif law:** the waveform mark lives in exactly two homes — Today hero presence + active tab glyph. Never stamped beside titles.
- **Transformation integrity:** the one-step rewrite highlights what now leads in the user's own words; Noum never inserts its own phrasing while claiming "your words." ("nothing added, nothing lost" is the contract.)
- **Amber canonized:** `color/feedback/caution` marks honest lapses (hollow ring + text label, never color alone).
- **Edge-to-edge hero** replaces card-on-canvas on Today; blue CTA straddles the hero seam.
- Vocabulary: the trained behaviour's failure mode is "wind-up" on every surface.
