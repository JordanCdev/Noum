// Judge payload construction + strict parsing/validation of the judge's JSON.
// The judge itself is an LLM (production-parity: same Claude family as the app).
// In this repo the judge is invoked either via the Anthropic API (run.sh --live)
// or by capturing a Claude subagent's JSON (replay mode).

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
export const JUDGE_SYSTEM = readFileSync(join(__dirname, '..', 'judges', 'rubric-judge.md'), 'utf8');
export const JUDGE_VERSION = '1.0.0';

const DIM_MAX = {
  diagnosticIQ: 25,
  eqAttunement: 25,
  personalMemory: 20,
  interventionQuality: 15,
  dialogueFeel: 15,
};

export function buildJudgeUserPayload(fixture, reply, contextBlock, deterministic) {
  return JSON.stringify(
    {
      id: fixture.id,
      goal: fixture.goal,
      voice: fixture.voice || null,
      priorChatTurns: fixture.priorChatTurns || [],
      userTurn: fixture.userTurn,
      emotionalSignal: fixture.emotionalSignal || null,
      contextBlock,
      expectedCoachMove: fixture.expectedCoachMove,
      badAnswerExample: fixture.badAnswerExample,
      excellentAnswerExample: fixture.excellentAnswerExample,
      disqualifiers: (fixture.disqualifiers || []).map((d) => (typeof d === 'string' ? d : d.pattern)),
      deterministicFindings: (deterministic?.findings || []).map((f) => ({ id: f.id, capKey: f.capKey, message: f.message })),
      actualReply: reply,
    },
    null,
    2,
  );
}

function clampInt(v, max) {
  const n = Math.round(Number(v));
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(max, n));
}

// Parse the judge output. Tolerant of a leading/trailing code fence or prose,
// but validates the shape and clamps every score. Throws only if no JSON object
// can be found at all.
export function parseJudge(text) {
  let jsonStr = text.trim();
  const fence = jsonStr.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fence) jsonStr = fence[1].trim();
  const first = jsonStr.indexOf('{');
  const last = jsonStr.lastIndexOf('}');
  if (first < 0 || last < 0) throw new Error('judge: no JSON object found');
  jsonStr = jsonStr.slice(first, last + 1);
  const raw = JSON.parse(jsonStr);

  const dims = {};
  let total = 0;
  for (const [k, max] of Object.entries(DIM_MAX)) {
    const entry = raw[k] || {};
    const score = clampInt(typeof entry === 'object' ? entry.score : entry, max);
    dims[k] = { score, max, reason: (typeof entry === 'object' && entry.reason) || '' };
    total += score;
  }
  const caps = {
    placeholderOrBroken: !!raw.caps?.placeholderOrBroken,
    ignoresIntent: !!raw.caps?.ignoresIntent,
    fabricatesEvidence: !!raw.caps?.fabricatesEvidence,
    unsafe: !!raw.caps?.unsafe,
  };
  return {
    dims,
    judgeTotal: total,
    caps,
    closerTo: ['bad', 'between', 'excellent'].includes(raw.closerTo) ? raw.closerTo : 'between',
    failureReasons: Array.isArray(raw.failureReasons) ? raw.failureReasons.slice(0, 8).map(String) : [],
    suggestedFix: typeof raw.suggestedFix === 'string' ? raw.suggestedFix : '',
    judgeVersion: JUDGE_VERSION,
  };
}

export { DIM_MAX };
