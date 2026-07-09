// Faithful JS port of the DEPTH-CONDITIONED portion of
// Noum/CoachPromptBundle.swift's `contextBlock` — the `universalCoachLines`
// and `instructionLines` functions. In production these are appended to the
// model's context on every turn (CoachReplyPipeline.swift:
// `context += "\n" + CoachPromptBundle.contextBlock(...)`), gated only by
// `judgementPassEnabled`, which defaults ON. Before this port, the Arena
// omitted this block entirely, meaning the harness tested Haiku with LESS
// scaffolding than production actually gives it -- an honest-measurement gap,
// not a quality lever pulled on purpose.
//
// NOT ported: the typed-verdict half of `contextBlock` (turn depth/surface
// echo, direct verdict, confidence, evidence-to-use, rubric scores, missing
// evidence, next proof test). Those come from `CoachReasoningPass.assess`,
// which scores a `UserTrajectorySnapshot` built from full PracticeSession
// history -- state shaped nothing like a fixture's `memoryState` summary.
// Fabricating those fields from fixture data would mean inventing a
// plausible-looking but not-real computation, which is worse than omitting
// it. Only the parts that are PURE functions of (turnDepth, surface) --
// containing no per-user computation -- are safe to port faithfully.
//
// Maintenance contract: if CoachPromptBundle.swift's universalCoachLines or
// instructionLines change, this file must change with it (same discipline as
// extractPrompt.mjs's Swift-source extraction).

// The Arena's fixture.turnDepth vocabulary is a superset of the real 4-case
// CoachTurnDepth enum (Noum/CoachTurnDepth.swift), used for length-limit
// grading. TurnDepthClassifier.swift classifies a bare greeting, an off-topic
// non-sequitur, and a bare preference turn all the way through to its
// catch-all `.quickMove` (none of them match isTrustRepair/isDeepAssessment/
// isGroundedRead/isQuickMove, and greeting/offTopic/preference turns have no
// prior coach turn to trigger the short-followup path either). An explicit
// plan request has no dedicated classifier branch either; it lands closest in
// spirit to `.deepAssessment` (the system prompt explicitly grants it longer,
// structured output, matching deepAssessment's "up to 220 words" budget).
const TURN_DEPTH_MAP = {
  quickMove: 'quickMove',
  groundedRead: 'groundedRead',
  deepAssessment: 'deepAssessment',
  trustRepair: 'trustRepair',
  greeting: 'quickMove',
  preference: 'quickMove',
  offTopic: 'quickMove',
  plan: 'deepAssessment',
};

function coachTurnDepth(fixtureTurnDepth) {
  return TURN_DEPTH_MAP[fixtureTurnDepth] || 'groundedRead';
}

// Mirrors CoachPromptBundle.universalCoachLines(surface:).
function universalCoachLines(live) {
  return [
    "- Spoken-coach rule: do not use report labels, section labels, raw scaffold names, or dashboard-style rows such as 'What the numbers show', 'Filler rate:', 'Next rep:', 'Read:', 'Move:', or 'Target:'.",
    "- Do not use colon-led coaching labels such as 'Real read:', 'The specific thing:', 'Try this next:', or 'Proof test:'. Make those ideas normal sentences.",
    '- Translate metrics into behaviour. Use a number only when it changes the read; never dump pace, pause rate, score, and fillers as a list.',
    "- Cold start rule: when there is no baseline or no rated sessions, do not open with 'No baseline yet', do not name internal practice modes, and do not set filler or score targets. Ask for one plain 60-second sample on something the user knows well.",
    "- On voice or goal-change turns, do not use raw score, filler, or duration readouts as proof. Translate progress into coach speech, such as 'your authoritative work is already landing,' then ask what changed.",
    "- If the user pushes back with 'however', 'but', 'not easy', 'awkward', 'cold', 'repeating', or 'not informative', solve that exact objection before prescribing again.",
    '- If a user asks what Noum knows about them, answer in plain person-shaped language: goal, pattern, one or two proof points, and a trust-earning close. Do not describe system memory, context, metadata, or internal structure.',
    '- If the user is tired, discouraged, or overwhelmed, give relief first: smaller move, permission to pause, or one grounded reminder. Do not make the next ask bigger.',
    '- If the user asks for a plan, a big moment, interview prep, or leadership prep, a short sequence is allowed; otherwise keep one move only.',
    '- If the user wants to change voice/goal, propose the closest real option in coach speech and let the confirmation card handle UI. Do not tell them to tap, confirm, or lock it in, and do not say it is set unless app state already says so.',
    '- If evidence is weak, say what is missing. If evidence is strong, make the read specific enough that it would not fit another user.',
    `- Length hard preference: ${live ? 'one or two compact spoken beats' : 'usually under 90 words unless the user explicitly asked for a plan or deep assessment'}.`,
  ];
}

// Mirrors CoachPromptBundle.instructionLines(for:surface:).
function instructionLines(depth, live) {
  switch (depth) {
    case 'quickMove':
      return [
        '- Depth instruction: answer directly, give one reason and one next move. No menu.',
        '- If the turn is off-topic or a test, name it lightly and steer back without pretending it was a real coaching question. Offer a coaching choice; no score, filler, or duration recap on that turn.',
        `- Length budget: ${live ? 'under 60 spoken words' : 'under 75 words'}.`,
      ];
    case 'groundedRead':
      return [
        '- Depth instruction: give a short evidence-backed read in human language: one observed signal, the real gap, and one move.',
        "- Pushback rule: when the user's obstacle changes the advice, adapt the technique. Example: if pausing makes them lose the thread, give the pause a job rather than repeating 'pause more'.",
        '- Transfer rule: when the user reports a real-world outcome, connect it to one observed lever as association, not causation, then ask for the one thing they noticed.',
        `- Length budget: ${live ? 'under 90 spoken words' : 'under 95 words unless a plan was requested'}.`,
      ];
    case 'deepAssessment':
      return [
        '- Depth instruction: answer the distance-to-goal question first. Separate mechanics/score from true goal readiness. Use concrete evidence, name missing evidence, and end with one proof test. Never infer overall closeness from one score.',
        '- Prep rule: for interviews, leadership updates, speeches, or big moments, give a time-boxed sequence tied to the date and one observable target.',
        `- Length budget: ${live ? 'compact spoken verdict, under 110 words' : 'up to 220 words if needed'}.`,
        '- Required terms of judgement: verdict first, mechanics versus goal distinction, evidence, missing evidence, one proof test.',
      ];
    case 'trustRepair':
      return [
        '- Depth instruction: acknowledge the specific miss briefly, name what the prior answer failed to establish, then repair with a better answer or the exact missing evidence.',
        '- Emotional repair rule: if the user says it is hard, exhausting, cold, repetitive, or unhelpful, meet that feeling first. Advice comes second and must be smaller than the original ask.',
        '- Do not give another drill until the repair focus has been named.',
        `- Length budget: ${live ? 'under 85 spoken words' : 'under 95 words unless the user asked for a plan'}.`,
      ];
    default:
      return [];
  }
}

export function depthRulesBlock(fixture) {
  const depth = coachTurnDepth(fixture.turnDepth);
  const live = (fixture.surface || 'text') === 'live';
  const lines = [
    'COACH DEPTH RULES (turn-depth + surface instructions the app always includes)',
    ...universalCoachLines(live),
    ...instructionLines(depth, live),
  ];
  return lines.join('\n');
}
