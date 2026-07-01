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

test('checks: length limits match the shipping gate (groundedRead tightened)', () => {
  // A 5-sentence groundedRead reply is within word/char bounds but exceeds the
  // gate's 4-sentence groundedRead cap — the Arena must flag tooLong so an
  // Arena-high score predicts the reply ships without a gate repair.
  const fiveSentences = 'Your open landed. The middle drifted. The close softened. Pace stayed steady. Next rep, hold the point through sentence two.';
  const r = runChecks(fiveSentences, baseFx(), { contextBlock: '' });
  assert.ok(r.findings.some((f) => f.id === 'tooLong'), '5-sentence groundedRead should trip tooLong (gate cap is 4)');
});

test('checks: length limits match the shipping gate (trustRepair loosened)', () => {
  // A ~145-word trust-repair reply is over the OLD Arena 110-word cap but well
  // within the gate's 170-word trustRepair limit — it must NOT flag tooLong,
  // or the Arena would penalise replies that ship fine.
  const reply = "That freeze is a real thing to sit with, and it makes sense it shook your confidence in pressure work after the week you have had. Here is what the reps actually show, though: your last three calm sessions held two fillers or fewer and the point led every time, so the mechanics are genuinely there when the timer is not running. The gap is narrow and specific, not a sign you cannot do this. What happened under the timer is the clock started before you had picked your first word, and everything scrambled from there. So the next rep is small on purpose: run one sixty-second round with no elimination clock, and each time the rush hits, hold one silent beat before you speak instead of filling it.";
  const r = runChecks(reply, baseFx({ turnDepth: 'trustRepair' }), { contextBlock: '' });
  assert.ok(!r.findings.some((f) => f.id === 'tooLong'), '145-word trustRepair should pass (gate allows 170)');
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

test('checks: honest rounding of a context metric is NOT fabrication', () => {
  const fx = baseFx({ userTurn: 'how did i do', memoryState: { baseline: { pace: 168.4, fillersPerMin: 6 } } });
  const ctx = renderContext(fx);
  const r = runChecks('Your pace was 168 words per minute — clean and steady.', fx, { contextBlock: ctx });
  assert.ok(!r.findings.some((f) => f.id === 'fabricatedMetric'), 'a rounded context metric must not be flagged');
  assert.notEqual(r.hardCap, 40);
});

test('checks: a genuinely invented metric IS fabrication', () => {
  const fx = baseFx({ userTurn: 'how did i do', memoryState: { baseline: { fillersPerMin: 6 } } });
  const ctx = renderContext(fx);
  const r = runChecks('Your 22 fillers per minute are the real problem.', fx, { contextBlock: ctx });
  assert.ok(r.findings.some((f) => f.id === 'fabricatedMetric'));
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

test('checks: canned coaching template repeated across turns flags (RALPH #4)', () => {
  const recent = ['Run one 60-second rep — verdict first, one reason, clean stop — then I will point to the fix.'];
  // Current reply re-serves the same 60-second-rep + verdict-first + clean-stop template.
  const r = runChecks('Let us keep it concrete: one 60-second rep, verdict first, clean stop, and I will name the change.', baseFx(), { recentReplies: recent });
  assert.ok(r.findings.some((f) => f.id === 'cannedTemplateRepeat'), 'whole-template recurrence should flag');
});

test('checks: coaching the same lever in fresh words does NOT flag as canned', () => {
  // Same focus (the close), genuinely different move — must not trip cannedTemplateRepeat.
  const recent = ['Run one 60-second rep — verdict first, one reason, clean stop.'];
  const r = runChecks('Your ending trails into "yeah, so". Land the ask itself and leave the silence there.', baseFx(), { recentReplies: recent });
  assert.ok(!r.findings.some((f) => f.id === 'cannedTemplateRepeat'));
});

test('checks: deferral with a question and no move on a decision turn flags (RALPH #6/#8)', () => {
  const fx = baseFx({ turnDepth: 'deepAssessment', userTurn: 'How far off am I from sounding authoritative?' });
  const r = runChecks('What are you trying to sound like in the room? And who is the audience?', fx, {});
  assert.ok(r.findings.some((f) => f.id === 'deferInsteadOfMove'), 'pure question-back on a deepAssessment turn should flag');
});

test('checks: a real prescription on a decision turn does NOT flag deferInsteadOfMove', () => {
  const fx = baseFx({ turnDepth: 'deepAssessment', userTurn: 'How far off am I?' });
  const r = runChecks('Honest read: closer mechanically than under pressure. Run one stakes rep and hold the open. Want to try it?', fx, {});
  assert.ok(!r.findings.some((f) => f.id === 'deferInsteadOfMove'));
});

test('checks: emotional decision turn is exempt from deferInsteadOfMove', () => {
  const fx = baseFx({ turnDepth: 'deepAssessment', emotionalSignal: 'exhausted', userTurn: 'I am exhausted.' });
  const r = runChecks('That sounds heavy. What would actually feel manageable right now?', fx, {});
  assert.ok(!r.findings.some((f) => f.id === 'deferInsteadOfMove'), 'exhausted turns may probe gently without a drill');
});

test('checks: move + trailing "what is the setting" hand-back flags (rule 40)', () => {
  // The cold-start-no-data live failure: gives the rep, then asks the banned setup question.
  const r = runChecks('No baseline yet, so start there. Record one rep on any work topic and I will tell you exactly what to target. What is the setting you are preparing for?', baseFx(), {});
  assert.ok(r.findings.some((f) => f.id === 'trailingSetupQuestion'), 'move + trailing setup question should flag');
});

test('checks: a warm "want the three questions?" offer does NOT flag (gold interview-prep)', () => {
  const r = runChecks('Drill the shape, not the content. Answer three likely questions with the conclusion in sentence one, hard stop at 60 seconds. Want the three questions?', baseFx({ turnDepth: 'deepAssessment' }), {});
  assert.ok(!r.findings.some((f) => f.id === 'trailingSetupQuestion'), 'a warm offer to continue is not a setup hand-back');
});

test('checks: a gentle emotional close with no prior drill does NOT flag trailingSetupQuestion', () => {
  const r = runChecks('That is real, and it makes sense. You do not have to decide anything right now. What would feel like enough before the next one?', baseFx({ emotionalSignal: 'exhausted' }), {});
  assert.ok(!r.findings.some((f) => f.id === 'trailingSetupQuestion'), 'gentle emotional question is the move, not a setup hand-back');
});

test('checks: a move that ENDS on the move (no trailing question) does NOT flag', () => {
  const r = runChecks('Your point arrived late. Put the recommendation in sentence one, then prove it once and stop.', baseFx(), {});
  assert.ok(!r.findings.some((f) => f.id === 'trailingSetupQuestion'));
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

test('score: closerTo=bad caps a grounded reply as a failure', () => {
  const det = { caps: [], flags: [], flagPenalty: 0, placeholderLeaks: 0 };
  const judge = { judgeTotal: 82, caps: {}, closerTo: 'bad' };
  const s = combineScore(det, judge);
  assert.equal(s.final, 45, 'a bad-resembling reply is capped however high its dims');
  assert.equal(s.closerToCap, 45);
});

test('score: closerTo=between deducts a modest amount', () => {
  const det = { caps: [], flags: [], flagPenalty: 0, placeholderLeaks: 0 };
  const judge = { judgeTotal: 84, caps: {}, closerTo: 'between' };
  const s = combineScore(det, judge);
  assert.equal(s.final, 78);
});

test('score: closerTo=excellent is unchanged', () => {
  const det = { caps: [], flags: [], flagPenalty: 0, placeholderLeaks: 0 };
  const judge = { judgeTotal: 88, caps: {}, closerTo: 'excellent' };
  const s = combineScore(det, judge);
  assert.equal(s.final, 88);
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
