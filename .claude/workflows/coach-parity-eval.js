export const meta = {
  name: 'coach-parity-eval',
  description: 'Multi-role evaluation of Noum vs human-coach parity + Speeko/Orai/Yoodli/Duolingo; verify gaps against code; synthesize prioritized roadmap + 10-point scorecard',
  phases: [
    { title: 'Evaluate', detail: '6 role agents score Noum grounded in code+docs' },
    { title: 'Verify', detail: 'adversarially check each gap is real, not already shipped' },
    { title: 'Synthesize', detail: 'prioritized roadmap + scorecard + honest limits' },
  ],
}

const REPO = '/Users/jordan/src/GitHub/Noum'

const GROUND = `
You are evaluating the Noum iOS app (a premium communication-training / speaking-coach app).
Repo root: ${REPO}. It is a 116k-LoC SwiftUI iOS app. You CANNOT build or run it — read the source.

REQUIRED READING (read these first, they are the source of truth for current state):
- docs/VISION.md  (the product north star + coach-parity standard)
- HANDOVER.md  (current iteration status, delta-to-coach, competitor delta — read the LAST ~300 lines especially: "Current UX iteration status", "Delta to a strong human communications coach", "Competitor delta")
- docs/COACH_REPLACEMENT_SCORECARD.md  (the running scorecard — note it may be partly stale, verify against code)
- docs/UX_VALUE_OVERHAUL_ROADMAP.md  (the 7-iteration plan)

KEY CODE (grep/read as needed, don't read all of it):
- HomeCoachCard.swift, ContentView.swift (Home + nav), CoachingOnboardingView.swift (first run)
- PracticeModeSelectionView.swift, DrillSystem.swift, PathJourneyView.swift, LessonView.swift (practice/curriculum)
- AskNoumView.swift, AICoachChatService.swift, CoachContextBuilder.swift, CoachReplyPipeline (coach intelligence)
- SummaryView.swift, SummaryCards.swift, PostRepCoachNoteService.swift (post-rep feedback)
- ProfileView.swift, BigMomentStore.swift, ForwardPlanService.swift (progress + real-world transfer)
- FeedbackEngine.swift, FillerWordDetector.swift, BaselineEngine.swift (analysis)

HARD CONSTRAINTS you must respect when proposing changes (from CLAUDE.md + handover red lines):
- No "replaces a human coach" claims in app copy. No fake progress, fake loading, hearts/lives framing.
- No new stores/duplicate routes — reuse existing state owners.
- Brand rule: no illustration, no characters, no melodic music. Visual richness = SF Symbols + motion + color + shape.
- Never show league tier / peak rating / bucket before rating.hasRatedEvidence. Never quote user speech unless it passed the quote guard.
- Coaching honesty: weak evidence -> softer feedback; never punish semantically valid speech; no fake certainty from small samples.

Be concrete and grounded. Cite real file:line where you can. Distinguish "missing" from "present but weak".
`

const FINDINGS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['role', 'overallScore', 'summary', 'findings'],
  properties: {
    role: { type: 'string' },
    overallScore: { type: 'number', description: '0-10 score for Noum from this role\'s lens toward the 10/10 goal' },
    summary: { type: 'string', description: '3-5 sentence honest verdict from this role' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['title', 'severity', 'evidence', 'recommendation', 'effort', 'impact'],
        properties: {
          title: { type: 'string' },
          severity: { type: 'string', enum: ['blocker', 'high', 'medium', 'low'] },
          evidence: { type: 'string', description: 'What in the code/docs shows this. Cite file:line if possible.' },
          recommendation: { type: 'string', description: 'Concrete, implementable change respecting the hard constraints.' },
          effort: { type: 'string', enum: ['S', 'M', 'L', 'XL'] },
          impact: { type: 'string', enum: ['low', 'medium', 'high', 'transformative'] },
        },
      },
    },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['title', 'status', 'reasoning', 'reviseEffort'],
  properties: {
    title: { type: 'string' },
    status: { type: 'string', enum: ['real-gap', 'already-shipped', 'partially-done', 'out-of-scope-or-violates-constraint'] },
    reasoning: { type: 'string', description: 'What you found in the code that confirms or refutes the gap. Cite file:line.' },
    reviseEffort: { type: 'string', enum: ['S', 'M', 'L', 'XL'] },
  },
}

phase('Evaluate')

const ROLES = [
  {
    key: 'market-research',
    prompt: `ROLE: Market researcher / competitive analyst. Score Noum against the category leaders Noum wants to rival: Speeko (real-time delivery sensing, clear free-vs-pro value), Orai (visible 4-week training plan artifact, simple promise), Yoodli (roleplay breadth: interviews, sales, panels, difficult conversations; analytics), Duolingo (delight, habit pacing, low-pressure AI conversation). For EACH competitor, name the single most important capability Noum lacks or does worse, and whether closing it is feasible within Noum's constraints. Score Noum's competitive position 0-10.`,
  },
  {
    key: 'ux-designer',
    prompt: `ROLE: Senior product/UX designer (Duolingo-grade polish bar, but calm/premium per Noum's brand). Evaluate visual hierarchy, motion, delight, information density, first-run friction, and whether each surface "feels premium" vs "feels like a prototype/dashboard". Flag text-heaviness (the owner's #1 complaint). Identify the highest-leverage UX/visual upgrades that respect the no-illustration/no-character brand rule. Score the UX 0-10.`,
  },
  {
    key: 'enduser-beginner',
    prompt: `ROLE: Honest end user — a nervous beginner who freezes in meetings and downloaded Noum yesterday. Walk the first-run -> first rep -> first feedback -> day-2 return path by reading the code. Be brutally honest: where do you get confused, where do you feel judged, where do you feel real value, where would you churn? Would you pay? Score your experience 0-10.`,
  },
  {
    key: 'enduser-power',
    prompt: `ROLE: Honest end user — a returning power user 30 days in (sales leader prepping for high-stakes pitches). Read the code for what the experience is at depth: does progress feel believable, does the coach remember you, does it adapt, does real-world transfer (BigMoment/prep) actually close the loop? Where does it feel hollow or repetitive? Would you keep paying? Score 0-10.`,
  },
  {
    key: 'coach-expert',
    prompt: `ROLE: Expert human communication coach. Assess coach-parity honestly across: perception depth, case formulation, intervention design, adaptation, transfer, and validation (see HANDOVER "Where a human coach is still ahead"). For each, state what Noum does today (cite code) and the smallest credible step that narrows the gap WITHOUT overclaiming. Where is Noum already coach-like? Score coaching credibility 0-10.`,
  },
  {
    key: 'qa-tester',
    prompt: `ROLE: QA / trust tester. Hunt for correctness, honesty, and edge-case risks that would break trust or feel broken: cold-start fabrication, unverified quotes leaking, celebrations firing on no evidence, empty/thin-data states, reduced-motion, Dynamic Type, dead toggles. Read the actual guards (ProofMomentService, HomeSignalGate, RatingStore.hasRatedEvidence, RewardEngine gating). Report real risks with file:line. Score robustness/trust 0-10.`,
  },
]

const evals = await parallel(ROLES.map(r => () =>
  agent(`${GROUND}\n\n${r.prompt}\n\nReturn 4-8 of your most important findings, each concrete and grounded. Set role to "${r.key}".`,
    { label: `eval:${r.key}`, phase: 'Evaluate', schema: FINDINGS_SCHEMA, agentType: 'Explore' })
)).then(rs => rs.filter(Boolean))

// Flatten all candidate gaps; keep role + score context.
const allFindings = evals.flatMap(e => (e.findings || []).map(f => ({ ...f, role: e.role })))
const highValue = allFindings.filter(f =>
  (f.severity === 'blocker' || f.severity === 'high' || f.severity === 'medium') &&
  (f.impact === 'high' || f.impact === 'transformative' || f.severity === 'blocker')
)
log(`${allFindings.length} findings; ${highValue.length} high-value candidates to verify`)

phase('Verify')

// Adversarially verify each high-value gap against the ACTUAL code — the scorecard is known to be partly stale.
const verdicts = await parallel(highValue.map(f => () =>
  agent(`${GROUND}\n\nADVERSARIAL VERIFICATION. A reviewer claims this is a gap in Noum:\n\nTITLE: ${f.title}\nEVIDENCE CLAIMED: ${f.evidence}\nPROPOSED FIX: ${f.recommendation}\n\nYour job: read the actual code and decide if this is genuinely missing, already shipped, partially done, or out-of-scope/violates a constraint. Default to skepticism — many "gaps" are already implemented behind a different name. Cite file:line. Set title to "${f.title}".`,
    { label: `verify:${f.title.slice(0, 40)}`, phase: 'Verify', schema: VERDICT_SCHEMA, agentType: 'Explore' })
    .then(v => v ? { ...f, verdict: v } : null)
)).then(rs => rs.filter(Boolean))

const confirmed = verdicts.filter(v => v.verdict.status === 'real-gap' || v.verdict.status === 'partially-done')
log(`${confirmed.length}/${verdicts.length} candidates confirmed as real or partial gaps`)

phase('Synthesize')

const SYNTH_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['overallScore', 'scorecard', 'verdict', 'topMoves', 'genuineLimitations'],
  properties: {
    overallScore: { type: 'number', description: 'Honest 0-10 overall vs the 10/10 coach-parity + rival-the-leaders goal' },
    verdict: { type: 'string', description: 'Honest 4-6 sentence overall verdict: can this credibly rival the leaders / approach coach parity, and what is the headline blocker.' },
    scorecard: {
      type: 'array',
      description: 'One row per dimension',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['dimension', 'score', 'note'],
        properties: {
          dimension: { type: 'string' },
          score: { type: 'number' },
          note: { type: 'string' },
        },
      },
    },
    topMoves: {
      type: 'array',
      description: 'Prioritized, implementable build list — highest leverage first',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['rank', 'title', 'why', 'what', 'effort', 'files'],
        properties: {
          rank: { type: 'number' },
          title: { type: 'string' },
          why: { type: 'string' },
          what: { type: 'string', description: 'Concrete implementation approach respecting constraints' },
          effort: { type: 'string', enum: ['S', 'M', 'L', 'XL'] },
          files: { type: 'string', description: 'Likely files to touch' },
        },
      },
    },
    genuineLimitations: {
      type: 'array',
      description: 'Honest limitations that cannot be closed by code alone (need data, hardware, real users, expert calibration)',
      items: { type: 'string' },
    },
  },
}

const synthesis = await agent(
  `${GROUND}\n\nYou are the lead synthesist. Below are role-based evaluations and the verified gap list (only real/partial gaps).\n\nROLE SCORES:\n${evals.map(e => `- ${e.role}: ${e.overallScore}/10 — ${e.summary}`).join('\n')}\n\nVERIFIED GAPS (real or partial):\n${confirmed.map(c => `- [${c.severity}/${c.impact}/${c.verdict.status}] ${c.title}: ${c.verdict.reasoning} | fix: ${c.recommendation}`).join('\n\n')}\n\nProduce: (1) an honest overall 0-10 score vs the goal of "could credibly rival Speeko/Orai/Yoodli/Duolingo and approach human-coach parity"; (2) a per-dimension scorecard (perception, case-formulation, intervention, adaptation, transfer, first-run, delight/retention, competitive position, trust/honesty, premium-feel); (3) a RANKED topMoves build list — favor high-impact moves that are S/M effort and respect every hard constraint, but include the 1-2 transformative L/XL moves that would most close the competitor gap; (4) genuineLimitations that code alone cannot fix. Be honest — do not inflate scores.`,
  { label: 'synthesize', phase: 'Synthesize', schema: SYNTH_SCHEMA }
)

return { roleScores: evals.map(e => ({ role: e.role, score: e.overallScore })), confirmedGaps: confirmed.length, synthesis }
