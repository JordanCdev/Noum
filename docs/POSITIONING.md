# Positioning — draft copy for Jordan's review

Status: **DRAFT. Not shipped app copy.** This is a proposal for the lead (Jordan) to
edit and, when the concurrent Swift agent is idle, land as runtime strings. Origin:
2026-07-06 autonomous role-based re-benchmark (`docs/COACH_PARITY_EVAL_2026-07-06.md`).
It is the top-ranked, zero-collision, keyless lever from that run.

## Why this exists

Noum's genuinely category-leading asset is **invisible to a prospect**. The eval scored
"positioning / branded credibility" at **5/10 — the worst axis on the board** — while
scoring "coaching honesty / restraint" at **9/10 with no rival in category**. Every
competitor (Speeko, Orai, Yoodli) sells a promise the moment you open the store page;
Noum's differentiator — that it *refuses to overclaim*, quotes your own verified words
back as proof, and holds a durable case on you — is buried in code and never stated.

This doc converts that moat into a marketable stance **without breaking it**. Every line
below stays inside the `CoachParityReadiness.forming` cap: no "replaces a human coach,"
no invented endorsement, no fake certainty.

## Red lines carried in (do not cross)

- No "replaces / as good as / better than a human coach" framing anywhere.
- No named coach, no invented credential, no borrowed authority (contrast Speeko's
  Roger Love — we do NOT fabricate an equivalent).
- No score-as-readiness. Progress is shown, never sold as a guarantee.
- Credibility claims must be truthfully sourced to what actually ships.

---

## 1. Category one-liner (the stance)

**Primary:**
> **The communication coach that only tells you what it can prove.**

**Alternates (same stance, different emphasis):**
> A speaking coach that remembers your own words — and never overclaims.
>
> Evidence-led speaking practice. It quotes you back, tracks what's real, and says
> "not enough yet" when it doesn't know.

Why this stance: it claims the one thing rivals structurally *can't* — restraint as a
feature. In a category crowded with "AI speech scores," "the coach that only tells you
what it can prove" is a defensible wedge, and it is *true* of the shipped product
(evidence floors, verified-quote proof moments, `.forming` cap).

## 2. First-run "why Noum is different" beat (draft)

A single calm card, shown once, before or just after the first rep. Three short lines,
Noum's restrained voice — not a feature list:

> **Most speaking apps score you. Noum coaches you.**
> It listens for the patterns that actually repeat, remembers the moments you're
> preparing for, and shows you proof in your own words — never a number it can't back up.
>
> _You'll see less at first, and more as it earns the right to say it._

That last line is the honesty moat *stated as a benefit* — it pre-frames the deliberate
thin-data self-suppression (why a cold user sees the generic fallback) as integrity, not
absence. It also sets the expectation the eval flagged as a real limitation: depth is
earned over 3–6 reps by design.

## 3. Credibility subline (truthfully sourced)

Noum ships an on-device coaching knowledge base (`CoachingKnowledgeBase`, ~64 cards)
that grounds the model in real communication-coaching practice. That is a *true,
verifiable* credibility asset — so we can state it plainly, with no named authority:

> **Grounded in established communication-coaching methods.**

Do **not** escalate this to a named coach or a claimed endorsement. If a real
named-coach partnership is ever secured, that becomes a separate, far stronger asset —
see below.

## 4. Strategy note — the named-coach gap (not for this run)

Speeko's durable edge is a named authority (Roger Love). Noum has the better *coaching
discipline* but no *named face*. Two honest options, ranked:

1. **Partnership (strongest):** a real, credited communication coach reviews and endorses
   the methodology. This is the only fully honest way to match Speeko's authority anchor.
   It is a business-development decision, not an engineering one.
2. **Methodology transparency (ship-now):** publish *what* Noum's coaching is grounded in
   (the knowledge-base topics, the honesty invariants) as a short "how Noum coaches" page.
   Turns the discipline itself into the credential. Zero external dependency.

Recommendation: ship #2 as a trust page now; pursue #1 when there's a real relationship —
never fabricate a proxy for it.

---

## Where each line eventually lands (for Jordan, when the Swift lane is free)

- Category one-liner → App Store subtitle + a positioning line on the marketing surface.
- First-run beat → a single card near `CoachingOnboardingView` (~line 204–211), one-shot,
  reduced-motion safe, self-hiding after first view.
- Credibility subline → a quiet subline under the onboarding value copy.
- "How Noum coaches" trust page → new lightweight view; a new-file change, so serialize
  it after the concurrent parity agent finishes (avoids `project.pbxproj` churn).

**This run did not edit `CoachingOnboardingView.swift`** — it is a contended Swift file
while the parity-Wave agent is active. Copy is handed to Jordan to land safely.
