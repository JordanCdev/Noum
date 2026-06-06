export const meta = {
  name: 'coach-parity-audit',
  description: 'Audit Noum against the 7-stage coach-parity standard, adversarially verify each gap, and synthesize a prioritized roadmap toward the ultimate goal (coach parity)',
  phases: [
    { title: 'Assess', detail: 'one agent per coach-parity stage maps real code vs the vision' },
    { title: 'Verify', detail: 'an Explore skeptic tries to refute each claimed gap against the codebase' },
    { title: 'Synthesize', detail: 'rank surviving gaps into a prioritized roadmap + write the doc body' },
  ],
}

const SHARED = `Noum is a premium iOS communication-training app (Swift/SwiftUI). Its ULTIMATE GOAL (North Star) is COACH PARITY: deliver the repeatable, evidence-led work of an excellent human communication coach — diagnose the individual, remember what matters, prescribe deliberate practice, observe response, adapt the plan, and prepare the user for real-world moments — proven by durable user outcomes, NEVER claimed from a single LLM reply, one rep, or a feature checklist.

The coach-parity standard (the literal definition of "done") has 7 stages: Diagnosis, Case formulation, Intervention, Adaptation, Perception, Transfer, Validation.

Hard rules from docs/VISION.md + CLAUDE.md you MUST honor in every assessment:
- EXTEND existing state owners; do NOT propose new parallel systems/stores/screens/routing. Named owners: CoachingProfileStore, CoachMemoryStore, RecommendationLearningStore, CoachCaseFile, session history (SessionStore), forward-plan stores, CoachContextBuilder.
- Every recommendation needs evidence, a purpose, an observable target, and an HONEST evidence threshold for changing the plan.
- Weak evidence -> tentative language; repeated evidence can strengthen; association is NEVER described as causation.
- Inferred psychological/interpersonal patterns are coach HYPOTHESES, never facts/diagnoses; ask the user before persisting or strengthening them.
- Anti-goals (do not propose any of these): vanity-metric dashboards, fake gamification/unlocks, punish-shame on regression, generic AI-chat wrapper, ad/sponsor surfaces, hearts/lives practice-gating, any leaderboard that publishes raw transcripts.

Repo facts: Swift files live BOTH at project root (e.g. ProfileView.swift) AND under Noum/. Tests live in NoumTests/NoumTests.swift. The build host has NO Swift/Xcode toolchain, so propose code/design steps, NOT "run xcodebuild". docs/CURRENT_STATE.md is an enormous append-only changelog — Grep it for specific terms, do NOT read it whole. Ground EVERY claim in real file:line evidence via Glob/Grep/Read.`

const STAGES = [
  {
    key: 'diagnosis', name: 'Diagnosis',
    definition: 'Establish a credible baseline and identify the user’s high-leverage communication pattern without overclaiming thin evidence.',
    seeds: ['TrendAnalyzer (primaryFocus/distanceFromGoal)', 'PrimaryFocusMemory.swift', 'CoachingProfileStore', 'PracticeEvaluator', 'rating/score/baseline capture', 'GoalRefreshManager'],
  },
  {
    key: 'formulation', name: 'Case formulation',
    definition: 'Retain a concise, revisable understanding of the user’s goal, blockers, strengths, pressure triggers, subjective experience, confidence and avoidance patterns, and upcoming moments. Deeper personal patterns must be treated as hypotheses the user can confirm or reject.',
    seeds: ['CoachCaseFile', 'CoachMemoryStore', 'CoachingProfileStore', 'CoachContextBuilder.swift', 'SessionReflectionInlineCard.swift', 'PrimaryFocusMemory.swift', 'forward-plan / proof-moment stores'],
  },
  {
    key: 'intervention', name: 'Intervention',
    definition: 'Prescribe a drill for a reason, name the observable target, and define what improvement would look like before the user starts.',
    seeds: ['RecommendationBiasEngine (blueprint / toneDrillBlueprint)', 'RecommendationLearningStore', 'HomeCoachCard', 'PracticeModeSelectionView', 'IMHistorySummary.swift (toneDrillSignal)', 'docs/recommendation-playbook.md'],
  },
  {
    key: 'adaptation', name: 'Adaptation',
    definition: 'Compare response across multiple attempts and either reinforce, vary, or replace the intervention with an explained rationale.',
    seeds: ['IMHistorySummary.swift (toneDrillProgress / toneDrillResolved)', 'RecommendationLearningStore', 'response-to-recommendation evidence', 'RevisedReadCard / AskNoumView.swift (rebuild-verdict)', 'SessionFinalizer.swift (PracticeSessionFinalizer)'],
  },
  {
    key: 'perception', name: 'Perception (delivery sensing)',
    definition: 'Assess not only words and fillers but vocal variety, intonation, breathing, energy, pitch range, authority, tension, structure, composure, and, when explicitly enabled, posture/eye contact/visual presence. Distinguish clear communication from speech that is merely polished, evasive, timid, over-rehearsed, or emotionally detached.',
    seeds: ['PracticeEvaluator (voiceDeliveryBonus)', 'WPMEvaluator', 'filler/disfluency detection', 'pace/pause metrics', 'eloquence engine / rhetorical-device detection', 'speech-recognition providers', 'SummaryCards.swift', 'prosody/intonation/pitch/breathing (likely absent — verify)'],
  },
  {
    key: 'transfer', name: 'Transfer (real-world)',
    definition: 'Connect training to real conversations, presentations, interviews, pitches, conflict, leadership, dating, and networking, then collect honest outcome/reflection and perceived audience-response evidence AFTER the event.',
    seeds: ['Big Moment', 'forward-plan stores', 'transfer reviews', 'post-event outcome / audience-reaction check-ins', 'SessionReflectionInlineCard.swift', 'AskNoumView.swift'],
  },
  {
    key: 'validation', name: 'Validation (human-coach calibration)',
    definition: 'Demonstrate that recommendations and feedback are as useful and trustworthy as professional-coach judgment on representative sessions and longitudinal user outcomes.',
    seeds: ['AIInsightsService', 'AIPromptGeneratorService', 'GrammarFeedbackService', 'blinded evaluation set / calibration harness (likely absent — verify)', 'docs/M19_audit_coach_workflow.md', 'docs/M19_audit_personalization.md'],
  },
]

const ASSESSMENT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['stageKey', 'maturity', 'maturityRationale', 'whatExists', 'highestLeverageGap'],
  properties: {
    stageKey: { type: 'string' },
    maturity: { type: 'integer', minimum: 0, maximum: 5, description: '0 absent, 3 real-but-shallow, 5 at human-coach parity' },
    maturityRationale: { type: 'string' },
    whatExists: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false, required: ['capability', 'evidence'],
        properties: { capability: { type: 'string' }, evidence: { type: 'string', description: 'file path, optional :line' }, stateOwner: { type: 'string' } },
      },
    },
    highestLeverageGap: {
      type: 'object', additionalProperties: false,
      required: ['title', 'description', 'whyItMattersForParity', 'stateOwnerToExtend', 'concreteNextStep', 'evidenceThreshold'],
      properties: {
        title: { type: 'string' },
        description: { type: 'string' },
        whyItMattersForParity: { type: 'string' },
        stateOwnerToExtend: { type: 'string', description: 'an EXISTING owner to extend, not a new system' },
        concreteNextStep: { type: 'string' },
        evidenceThreshold: { type: 'string', description: 'honest bar before the coach acts on / changes the plan' },
        pillarsTouched: { type: 'array', items: { type: 'string' } },
      },
    },
    secondaryGaps: {
      type: 'array',
      items: { type: 'object', additionalProperties: false, required: ['title'], properties: { title: { type: 'string' }, description: { type: 'string' } } },
    },
  },
}

const VERDICT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['gapTitle', 'isReal', 'confidence', 'recommendation', 'rationale'],
  properties: {
    gapTitle: { type: 'string' },
    isReal: { type: 'boolean', description: 'true = genuinely open; false = already addressed in code' },
    confidence: { type: 'number', minimum: 0, maximum: 1 },
    refutingEvidence: { type: 'string', description: 'existing code/tests that already deliver this (file:line); empty if none found' },
    adjustedGap: { type: 'string', description: 'refined scope if only PARTIALLY done; empty if no change' },
    recommendation: { type: 'string', enum: ['keep', 'refine', 'drop'] },
    rationale: { type: 'string' },
  },
}

const ROADMAP_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['northStar', 'currentMaturity', 'initiatives', 'sequencing', 'antiGoalsGuardrail', 'fullMarkdown'],
  properties: {
    northStar: { type: 'string' },
    currentMaturity: {
      type: 'array',
      items: { type: 'object', additionalProperties: false, required: ['stage', 'score'], properties: { stage: { type: 'string' }, score: { type: 'integer' }, note: { type: 'string' } } },
    },
    initiatives: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        required: ['rank', 'title', 'parityStagesAdvanced', 'leverageRationale', 'stateOwnersToExtend', 'firstConcreteStep', 'evidenceThreshold', 'risk'],
        properties: {
          rank: { type: 'integer' },
          title: { type: 'string' },
          parityStagesAdvanced: { type: 'array', items: { type: 'string' } },
          leverageRationale: { type: 'string' },
          stateOwnersToExtend: { type: 'array', items: { type: 'string' } },
          firstConcreteStep: { type: 'string' },
          evidenceThreshold: { type: 'string' },
          risk: { type: 'string' },
        },
      },
    },
    sequencing: { type: 'string' },
    antiGoalsGuardrail: { type: 'string' },
    fullMarkdown: { type: 'string', description: 'the complete body of docs/COACH_PARITY_ROADMAP.md' },
  },
}

const assessPrompt = (stage) => `${SHARED}

You are assessing ONE coach-parity stage: "${stage.name}".
Stage definition (from the coach-parity standard): ${stage.definition}

Likely-relevant code to investigate (seed list, search BOTH project root and Noum/; follow the real code, this is not exhaustive): ${stage.seeds.join('; ')}.

Do this:
1. Read the relevant parts of docs/VISION.md (North star, Product pillars, the Coach-parity standard, the "where we are underweight" assessment, and the post-M14 roadmap).
2. Use Glob/Grep/Read to find what the codebase ACTUALLY implements for THIS stage today. Cite file:line for each real capability.
3. Score maturity 0-5 (0 absent, 3 real-but-shallow, 5 at human-coach parity) with a one-line rationale tied to evidence.
4. Identify the SINGLE highest-leverage gap that, if closed, would move THIS stage most toward coach parity. It MUST extend a named EXISTING state owner, have a concrete first next step, and an honest evidence threshold. Note which product pillars it touches.
5. List up to 3 secondary gaps (title + one line each).

Be ruthless about evidence: do NOT claim a gap exists without first checking the code — this codebase already shipped many rounds of deep coaching work, so an unchecked gap is likely a false positive. Do NOT propose new parallel systems. Return ONLY the structured object.`

const verifyPrompt = (stage, a) => `${SHARED}

You are an ADVERSARIAL VERIFIER for the coach-parity stage "${stage.name}". A prior agent claims the following is the highest-leverage OPEN gap. Your job is to try to REFUTE that it is open.

GAP TITLE: ${a.highestLeverageGap.title}
GAP DESCRIPTION: ${a.highestLeverageGap.description}
CLAIMED next step: ${a.highestLeverageGap.concreteNextStep}
What the prior agent says already exists: ${JSON.stringify(a.whatExists)}

Search the codebase hard (project root + Noum/ + NoumTests/NoumTests.swift + Grep docs/CURRENT_STATE.md for specific terms) for existing code, tests, or persisted state that ALREADY delivers this capability, fully or partially.
- If existing code already delivers it -> isReal=false, recommendation=drop, cite the refuting file:line in refutingEvidence.
- If it is only PARTIALLY done -> isReal=true, recommendation=refine, put the genuinely-missing remainder in adjustedGap and cite what already exists.
- If after a thorough search you cannot find it -> isReal=true, recommendation=keep.
Set confidence honestly (how sure are you of the verdict). Return ONLY the structured object.`

const synthPrompt = (clean) => `${SHARED}

All 7 coach-parity stages have been assessed and each claimed gap adversarially verified. Data (assessment + verdict per stage):

${JSON.stringify(clean, null, 2)}

Produce a PRIORITIZED ROADMAP toward the ultimate goal (coach parity). Rules:
- Honor the verdicts: DROP gaps the verifier refuted (isReal=false). For "refine" verdicts, use adjustedGap as the real scope. For "keep", use the original gap.
- Rank surviving initiatives by leverage toward coach parity. Weight the stages the vision itself names as most underweight (Perception/delivery sensing, Transfer, Validation, and deepening the Case file + Adaptation) and respect the vision's own post-M14 sequencing (stable ship -> case file/intervention cycle -> delivery intelligence -> real-moment transfer -> presence with consent -> human-coach calibration).
- Each initiative: which parity stage(s) it advances, why it is high-leverage, which EXISTING state owners to extend, the first concrete code/design step, the honest evidence threshold, and the main risk.
- Build a currentMaturity table from the assessments (stage + 0-5 score + one-line note).
- Add a sequencing note (what must precede what) and an anti-goals guardrail (what NOT to build).
- Produce fullMarkdown: the COMPLETE body of docs/COACH_PARITY_ROADMAP.md — H1 title, a "Generated: 2026-06-01" line, a one-paragraph north-star restatement, the maturity table, the ranked initiatives (each as a subsection), the sequencing note, and the anti-goals guardrail. Use an honest, restrained, premium voice. No overclaiming, no fake certainty, no hollow fanfare.

Return ONLY the structured object.`

log('Auditing Noum against the 7-stage coach-parity standard (the app’s ultimate goal).')

const results = await pipeline(
  STAGES,
  (stage) => agent(assessPrompt(stage), { label: `assess:${stage.key}`, phase: 'Assess', schema: ASSESSMENT_SCHEMA }),
  (assessment, stage) => agent(verifyPrompt(stage, assessment), { label: `verify:${stage.key}`, phase: 'Verify', schema: VERDICT_SCHEMA, agentType: 'Explore' })
    .then((verdict) => ({ key: stage.key, name: stage.name, assessment, verdict })),
)

const clean = results.filter(Boolean)
log(`Assessed + verified ${clean.length}/${STAGES.length} stages. Synthesizing roadmap.`)

phase('Synthesize')
const roadmap = await agent(synthPrompt(clean), { label: 'synthesize-roadmap', phase: 'Synthesize', schema: ROADMAP_SCHEMA })

return { stages: clean, roadmap }
