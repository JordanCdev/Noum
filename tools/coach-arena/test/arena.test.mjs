// Unit tests for the Coach Arena core logic. Run: node --test  (or ./run.sh test)
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { composeSystemPrompt, extractAll, VOICES } from '../lib/extractPrompt.mjs';
import { runChecks } from '../lib/checks.mjs';
import { combineScore } from '../lib/score.mjs';
import { parseJudge } from '../lib/judge.mjs';
import { renderContext } from '../lib/context.mjs';

const baseFx = (over = {}) => ({ id: 'x', turnDepth: 'groundedRead', userTurn: 'what next?', goal: 'g', memoryState: {}, disqualifiers: [], ...over });

test('extractPrompt: all voices compose with integrity anchors', () => {
  const ex = extractAll();
  assert.ok(ex.roboticPhrases.length >= 50, 'robotic phrases extracted');
  for (const v of [...VOICES, null]) {
    const p = composeSystemPrompt(v, {}, ex);
    assert.ok(p.includes('You are Noum'));
    assert.ok(p.includes('Intelligence floor'));
    assert.ok(!p.includes('\\('), 'no unresolved interpolation for voice ' + v);
  }
});

test('checks: clean strong reply has no findings', () => {
  const fx = baseFx({ memoryState: { baseline: { fillersPerMin: 6 } } });
  const ctx = renderContext(fx);
  const r = runChecks('Your last rep buried the point until sentence four. Say it first next rep, then support it.', fx, { contextBlock: ctx });
  assert.equal(r.hardCap, null);
  assert.equal(r.flagPenalty, 0);
  assert.equal(r.findings.length, 0);
});

test('checks: robotic phrase flags', () => {
  const r = runChecks('Based on your data, keep practicing.', baseFx(), {});
  assert.ok(r.findings.some((f) => f.id === 'roboticPhrase'));
  assert.ok(r.flagPenalty > 0);
});

test('checks: exclamation flags', () => {
  const r = runChecks('Great work today, hold a beat next rep!', baseFx(), {});
  assert.ok(r.findings.some((f) => f.id === 'exclamation'));
});

test('checks: fake score = 10 caps placeholderOrBroken', () => {
  const r = runChecks('That was a perfect 10/10, you are ready now.', baseFx(), { contextBlock: 'CONTEXT\n- nothing' });
  assert.equal(r.hardCap, 30);
  assert.ok(r.placeholderLeaks >= 1);
});

test('checks: metadata leak caps', () => {
  const r = runChecks('Reading your CONTEXT block, the Intelligence floor says quote a fact.', baseFx(), {});
  assert.equal(r.hardCap, 30);
});

test('checks: bare clarification caps ignoresIntent', () => {
  const r = runChecks('Can you clarify what you mean?', baseFx(), {});
  assert.equal(r.hardCap, 50);
});

test('checks: punish-shame caps unsafe (0)', () => {
  const r = runChecks('That was a disappointing rep and you always choke.', baseFx(), {});
  assert.equal(r.hardCap, 0);
});

test('checks: fabricated attributed quote caps fabricatesEvidence', () => {
  const fx = baseFx({ userTurn: 'how did I do' });
  const r = runChecks('You said "I never prepare for these meetings" so that is the issue.', fx, { contextBlock: 'CONTEXT\n- nothing relevant' });
  assert.equal(r.hardCap, 40);
});

test('checks: grounded attributed quote with punctuation is NOT fabrication', () => {
  const fx = baseFx({
    userTurn: 'whats my biggest weakness',
    memoryState: { recentReps: [{ when: 'yesterday', mode: 'Timed', note: "said 'the number is probably around 12%, give or take' when stating the figure" }] },
  });
  const ctx = renderContext(fx);
  const r = runChecks('Yesterday you said "the number is probably around 12%, give or take," which reads as hedging.', fx, { contextBlock: ctx });
  assert.ok(!r.findings.some((f) => f.id === 'fabricatedQuote'), 'grounded quote must not be flagged');
  assert.notEqual(r.hardCap, 40);
});

test('checks: repeated proof test flags', () => {
  const recent = ['Record a 60-second answer and land the point in the first sentence, then stop.'];
  const r = runChecks('Record a 60-second answer and land the point in sentence one, then stop.', baseFx(), { recentReplies: recent });
  assert.ok(r.findings.some((f) => f.id === 'repeatedProofTest'));
});

test('checks: fixture disqualifier substring + regex + cap', () => {
  const fx = baseFx({ disqualifiers: ['forbidden phrase', { pattern: '\\bset to authoritative\\b', regex: true, cap: 'placeholderOrBroken' }] });
  const r1 = runChecks('this contains a forbidden phrase here', fx, {});
  assert.ok(r1.findings.some((f) => f.id === 'disqualifier'));
  const r2 = runChecks("I've set to authoritative for you.", fx, {});
  assert.equal(r2.hardCap, 30);
});

test('score: clamps to smallest triggered cap, unions det+judge', () => {
  const det = { caps: [{ capKey: 'ignoresIntent', capMax: 50 }], flags: [], flagPenalty: 0, placeholderLeaks: 0 };
  const judge = { judgeTotal: 88, caps: { placeholderOrBroken: true, ignoresIntent: false, fabricatesEvidence: false, unsafe: false }, closerTo: 'bad' };
  const s = combineScore(det, judge);
  assert.equal(s.hardCap, 30); // min(50 det, 30 judge)
  assert.equal(s.final, 30);
});

test('score: flags deduct but cannot zero a great capless answer', () => {
  const det = { caps: [], flags: [], flagPenalty: 12, placeholderLeaks: 0 };
  const judge = { judgeTotal: 90, caps: {}, closerTo: 'excellent' };
  const s = combineScore(det, judge);
  assert.equal(s.hardCap, null);
  assert.equal(s.final, 78);
});

test('judge: parses, clamps out-of-range scores, tolerates fences', () => {
  const text = '```json\n{"diagnosticIQ":{"score":40,"reason":"a"},"eqAttunement":{"score":20},"personalMemory":{"score":18},"interventionQuality":{"score":14},"dialogueFeel":{"score":13},"caps":{"placeholderOrBroken":false,"ignoresIntent":false,"fabricatesEvidence":false,"unsafe":false},"closerTo":"excellent","failureReasons":[],"suggestedFix":"none"}\n```';
  const j = parseJudge(text);
  assert.equal(j.dims.diagnosticIQ.score, 25); // clamped from 40
  assert.equal(j.judgeTotal, 25 + 20 + 18 + 14 + 13);
  assert.equal(j.closerTo, 'excellent');
});

test('judge: throws on non-JSON', () => {
  assert.throws(() => parseJudge('no json here'));
});

test('context: renders section headers the prompt references', () => {
  const fx = baseFx({ voice: 'authoritative', memoryState: { goal: { voice: 'authoritative', whyNow: 'w' }, baseline: { fillersPerMin: 4 }, proofs: ['a real line'] } });
  const ctx = renderContext(fx);
  assert.ok(ctx.includes('GOAL'));
  assert.ok(ctx.includes('BASELINE'));
  assert.ok(ctx.includes('VERIFIED PROOFS'));
});
