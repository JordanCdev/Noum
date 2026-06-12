export const meta = {
  name: 'coach-parity-current',
  description: 'Multi-role coach-parity re-evaluation of Noum at current HEAD + adversarial code verification + strategist synthesis',
  phases: [
    { title: 'Evaluate', detail: '6 role agents score the current tree' },
    { title: 'Verify', detail: 'adversarially verify each claimed gap against code' },
    { title: 'Synthesize', detail: 'strategist re-score + ranked delta + honest limits' },
  ],
}

// Shared grounding every role agent gets. Read-only sandbox: agents read files,
// they do not build. Branch ux-overhaul, repo root /Users/jordan/src/GitHub/Noum.
const GROUND = `
You are evaluating the iOS app "Noum" — a premium communication-training / speaking-coach
app — at the CURRENT state of branch ux-overhaul (repo root: /Users/jordan/src/GitHub/Noum).
The goal under test: could Noum credibly RIVAL or REPLACE a human communications coach and
beat Speeko / Orai / Yoodli / Duolingo? Honest target is 10/10 "no doubt replaces a human coach".

GROUND EVERY CLAIM IN ACTUAL CODE. This is a Swift/SwiftUI codebase. Root-level Swift files
exist (ProfileView.swift, RewardEngine.swift, ReinforcementCopy.swift, AchievementsPage.swift)
AND files under Noum/. Grep from the repo root, not just Noum/. Read the file before asserting
a gap — many "missing" things were shipped recently. Key context docs:
- docs/VISION.md, CLAUDE.md (product invariants + engineering bans)
- docs/COACH_PARITY_EVAL_2026-06-10.md (prior eval, scored 6.3/10 at commit ac4194a)
- docs/UX_VALUE_OVERHAUL_SESSION_2026-06-10_CONTINUATION.md (prior eval, 7/10)
- handover.md (competitor delta, red lines, current iteration status)
IMPORTANT: HEAD is AHEAD of both prior evals — REVIEW-overhaul (insight-first Review home),
HOME-gap (Ask Noum coach row), TEXT-asknoum (open chat, day-0 AskNoumDayZeroGreeting),
CHAT-intelligence (honest offline chat) all shipped AFTER those evals. Verify against the
LIVE code, do not just restate prior eval findings.
Architectural invariant: the app DELIBERATELY never claims human-coach parity
(CoachParityReadiness structurally caps at .forming, never .earned) and never shows fake
progress. A finding that asks Noum to overclaim is WRONG, not a gap.
`

const ROLE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['role', 'score', 'headline', 'strengths', 'gaps'],
  properties: {
    role: { type: 'string' },
    score: { type: 'number', description: '0-10 from this role lens' },
    headline: { type: 'string', description: 'one-sentence verdict' },
    strengths: { type: 'array', items: { type: 'string' }, description: 'verified-in-code strengths, max 5' },
    gaps: {
      type: 'array',
      description: 'concrete gaps; each must name a file/symbol or be flagged as code-uncloseable',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['title', 'evidence', 'severity', 'codeCloseable'],
        properties: {
          title: { type: 'string' },
          evidence: { type: 'string', description: 'file:symbol or doc reference proving the gap exists NOW' },
          severity: { type: 'string', enum: ['high', 'medium', 'low'] },
          codeCloseable: { type: 'boolean', description: 'true if closeable in code alone (no hardware/human/longitudinal gate)' },
        },
      },
    },
  },
}

const ROLES = [
  { key: 'market', prompt: 'ROLE: Market researcher. Assess Noum vs Speeko, Orai, Yoodli, Duolingo on positioning, the first-90-seconds value promise, perceived differentiation, and whether the wedge (private evidence-led coaching with durable memory) is legible to a new user. Read handover.md competitor delta + HomeCoachCard + onboarding copy.' },
  { key: 'ux', prompt: 'ROLE: Senior product/UX designer. Assess hierarchy, density, premium feel, motion restraint, cold-start legibility, and whether the intelligence is FELT or buried. Read ContentView, HomeCoachCard, ProfileView, SummaryView, the Review/Train surfaces. Flag any surface where real capability is invisible.' },
  { key: 'beginner', prompt: 'ROLE: End user, nervous beginner, day 0. Walk the first run: onboarding -> can I talk to the coach before my first rep? -> first rep -> first read. Read AskNoumView (AskNoumDayZeroGreeting), onboarding, SummaryView. Does it feel like a coach who knows me, fast, warm, honest? Where does trust wobble?' },
  { key: 'power', prompt: 'ROLE: End user, returning power user, 30+ reps. Does the coach remember, adapt, prescribe a real next move, close the transfer loop, and feel like progress over time? Read CoachContextBuilder, CoachMemoryStore, RecommendationBiasEngine, BigMomentStore, ForwardPlanService, RatingStore.' },
  { key: 'coach', prompt: 'ROLE: Veteran human communications coach. Judge perception depth, case formulation, intervention quality, adaptation, and transfer against how YOU coach. Where is Noum genuinely coach-like and where is it shallow? Separate code-closeable gaps from real sensor/calibration/longitudinal limits. Read PracticeSupport, PostRepCoachNoteService, CoachContextBuilder, ProofMomentService.' },
  { key: 'qa', prompt: 'ROLE: QA / trust auditor. Hunt for overclaiming, fake progress, fabricated quotes, dead toggles, dead code presented as features, broken return loops, and honesty-contract violations. Verify the quote guard, celebration gating, rating-evidence gating. Check RewardEngine/SessionCompletionCopy for dead code. This is the trust moat — be adversarial.' },
]

phase('Evaluate')
const roleResults = await parallel(
  ROLES.map(r => () =>
    agent(`${GROUND}\n\n${r.prompt}\n\nReturn your structured evaluation. Be specific and code-grounded.`,
      { label: `eval:${r.key}`, phase: 'Evaluate', schema: ROLE_SCHEMA, agentType: 'Explore' })
  )
).then(rs => rs.filter(Boolean))

// Collect all code-closeable, high/medium gaps for adversarial verification.
const candidateGaps = roleResults.flatMap(r =>
  (r.gaps || [])
    .filter(g => g.codeCloseable && g.severity !== 'low')
    .map(g => ({ ...g, fromRole: r.role }))
)

phase('Verify')
const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['title', 'isRealGapNow', 'verdict', 'effort', 'redLineRisk'],
  properties: {
    title: { type: 'string' },
    isRealGapNow: { type: 'boolean', description: 'true ONLY if the gap genuinely exists in current HEAD code' },
    verdict: { type: 'string', description: 'what the code actually shows; cite file:symbol' },
    effort: { type: 'string', enum: ['S', 'M', 'L'] },
    redLineRisk: { type: 'string', description: 'any CLAUDE.md red-line / architectural-fragmentation risk in fixing it, or "none"' },
  },
}
const verified = await parallel(
  candidateGaps.map(g => () =>
    agent(`${GROUND}\n\nA role evaluator (${g.fromRole}) claims this gap exists in CURRENT code:\n` +
      `TITLE: ${g.title}\nEVIDENCE CLAIMED: ${g.evidence}\nSEVERITY: ${g.severity}\n\n` +
      `Adversarially verify against the LIVE tree. Open the named files/symbols. ` +
      `Default to isRealGapNow=false unless you can prove the gap is real at HEAD. ` +
      `If a recent commit already closed it, say so. Assess effort and any red-line/fragmentation risk in fixing it.`,
      { label: `verify:${g.title.slice(0, 32)}`, phase: 'Verify', schema: VERDICT_SCHEMA, agentType: 'Explore' })
  )
).then(rs => rs.filter(Boolean))

const confirmed = verified.filter(v => v.isRealGapNow)

phase('Synthesize')
const SYNTH_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['overallScore', 'verdict', 'roleScores', 'rankedBuildList', 'genuineLimitations', 'competitorRead'],
  properties: {
    overallScore: { type: 'number' },
    verdict: { type: 'string', description: '2-4 sentence honest current-state verdict incl. literal 10/10 answer' },
    roleScores: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['role', 'score'], properties: { role: { type: 'string' }, score: { type: 'number' } } } },
    rankedBuildList: {
      type: 'array', description: 'confirmed code-closeable moves, highest leverage first',
      items: { type: 'object', additionalProperties: false, required: ['rank', 'title', 'effort', 'why'], properties: { rank: { type: 'number' }, title: { type: 'string' }, effort: { type: 'string' }, why: { type: 'string' } } },
    },
    genuineLimitations: { type: 'array', items: { type: 'string' }, description: 'gaps code alone cannot close (sensor/calibration/longitudinal/hardware)' },
    competitorRead: { type: 'string', description: 'where Noum stands vs Speeko/Orai/Yoodli/Duolingo now' },
  },
}
const synthesis = await agent(
  `${GROUND}\n\nYou are the lead strategist. Synthesize the panel into one honest current-state read.\n\n` +
  `ROLE EVALUATIONS:\n${JSON.stringify(roleResults, null, 1)}\n\n` +
  `ADVERSARIALLY-CONFIRMED CODE-CLOSEABLE GAPS (real at HEAD):\n${JSON.stringify(confirmed, null, 1)}\n\n` +
  `Produce: an overall 0-10 score (defensible, not inflated), the honest literal answer to ` +
  `"10/10, no doubt replaces a human coach", per-role scores, a ranked build list of ONLY the ` +
  `confirmed code-closeable moves, the genuine limitations no code can close, and the competitor read. ` +
  `Respect the honesty contract: never recommend an overclaim.`,
  { label: 'strategist', phase: 'Synthesize', schema: SYNTH_SCHEMA }
)

return { roleResults, confirmedGaps: confirmed, synthesis }
