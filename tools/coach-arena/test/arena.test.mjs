// Unit tests for the Coach Arena core logic. Run: node --test  (or ./run.sh test)
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

import { composeSystemPrompt, extractAll, VOICES } from '../lib/extractPrompt.mjs';
import { runChecks } from '../lib/checks.mjs';
import { combineScore } from '../lib/score.mjs';
import { parseJudge } from '../lib/judge.mjs';
import { renderContext } from '../lib/context.mjs';
import { summarize } from '../lib/report.mjs';
import { finalizeReplyForFixture } from '../lib/finalizeReply.mjs';

const rootDir = join(dirname(fileURLToPath(import.meta.url)), '..');
const baseFx = (over = {}) => ({ id: 'x', turnDepth: 'groundedRead', userTurn: 'what next?', goal: 'g', memoryState: {}, disqualifiers: [], ...over });
const scoredRecord = (over = {}) => ({
  status: 'scored',
  fixture: { id: 'scored', category: 'mechanics', turnDepth: 'groundedRead', ...over.fixture },
  score: { final: 80, capsTriggered: [], placeholderLeaks: 0, ...over.score },
  judge: {
    dims: {
      diagnosticIQ: { score: 20 },
      eqAttunement: { score: 20 },
      personalMemory: { score: 16 },
      interventionQuality: { score: 12 },
      dialogueFeel: { score: 12 },
    },
    ...over.judge,
  },
});

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

test('replay captures cover every gold fixture when local captures are present', (t) => {
  const fixtureDir = join(rootDir, 'fixtures', 'gold');
  const captureDir = join(rootDir, 'runners', 'captures');
  if (!existsSync(captureDir)) {
    t.skip('local replay captures are gitignored regenerable artifacts');
    return;
  }
  const missing = [];

  for (const file of readdirSync(fixtureDir).filter((f) => f.endsWith('.json')).sort()) {
    const fixture = JSON.parse(readFileSync(join(fixtureDir, file), 'utf8'));
    for (const suffix of ['reply.txt', 'judge.json']) {
      const expected = join(captureDir, `${fixture.id}.${suffix}`);
      if (!existsSync(expected)) missing.push(`${fixture.id}.${suffix}`);
    }
  }

  assert.deepEqual(missing, []);
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
  assert.ok(r.caps.some((f) => f.id === 'roboticPhrase'));
  assert.equal(r.hardCap, 65);
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

test('checks: a proposal that ends on a "which one fits" choice question does NOT flag (rule 57, gold 45-what-voice)', () => {
  // The closing question IS the move — the user picks among the options just
  // proposed. This is the fixture gold; it must not trip trailingSetupQuestion.
  const gold = "Given you're trying to stop getting talked over in meetings, Authoritative is the closest fit — it trains a firm, verdict-first close instead of trailing off. Executive presence is the next-closest if the room is more senior leadership than peers. Which one matches the room you're actually in?";
  const r = runChecks(gold, baseFx({ category: 'goal-change' }), {});
  assert.ok(!r.findings.some((f) => f.id === 'trailingSetupQuestion'), 'a "which one matches" selection question is the move, not a setup hand-back');
  // But a "which meeting are you preparing for?" fact-supply hand-back still flags.
  const bad = runChecks('Lead with the recommendation and stop. Which meeting are you preparing for?', baseFx(), {});
  assert.ok(bad.findings.some((f) => f.id === 'trailingSetupQuestion'), 'a "which meeting" fact-supply question is still a banned hand-back');
});

test('checks: voiceIntegrity caps STRUCTURAL scaffold labels but NOT soft imperative lead-ins', () => {
  // Soft lead-ins the gold uses as natural spoken transitions must NOT hard-cap.
  for (const soft of [
    'Your point drifted late. Next rep: say it in sentence one, then prove it once.',
    'Four days is enough. Target: every answer leads with the verdict.',
  ]) {
    const r = runChecks(soft, baseFx(), {});
    assert.ok(!r.caps.some((f) => f.id === 'scaffoldStructuralLabel'), `soft lead-in must not cap: ${soft}`);
    assert.notEqual(r.hardCap, 65, `soft lead-in must not trip voiceIntegrity: ${soft}`);
  }
  // Internal reasoning-block labels are the coach's scaffold spoken aloud — cap below the gate.
  for (const structural of [
    'Read: your point arrived late. Say it first next time.',
    'Diagnosis: you rush the close. Hold a beat before the last line.',
    'Verdict: the ask was hedged. State the number flat next rep.',
  ]) {
    const r = runChecks(structural, baseFx(), {});
    assert.ok(r.caps.some((f) => f.id === 'scaffoldStructuralLabel'), `structural label must cap: ${structural}`);
    assert.equal(r.hardCap, 65, `structural label must trip voiceIntegrity (65): ${structural}`);
  }
});

test('checks: cold-start reply flags product mode and metric target before baseline', () => {
  const fx = baseFx({
    category: 'cold-start',
    evidence: { noRatedSessions: true, noVoiceSet: true },
    userTurn: 'What should I work on?',
  });
  const r = runChecks(
    'No baseline yet, so do one Ah-Counter round: 60 seconds on a topic you know cold, aiming to stay under 4 fillers. That gives you a first number.',
    fx,
    { contextBlock: 'BASELINE\n- Not enough data for a stable baseline yet.' },
  );
  assert.ok(r.findings.some((f) => f.id === 'coldStartProductJargon'));
  assert.ok(r.findings.some((f) => f.id === 'coldStartMetricTarget'));
  assert.ok(r.caps.some((f) => f.id === 'coldStartUncalibratedMetricTarget'));
  assert.ok(r.caps.some((f) => f.id === 'coldStartFakeCalibration'));
  assert.equal(r.hardCap, 30);
});

test('checks: cold-start worded filler target flags before baseline', () => {
  const fx = baseFx({
    category: 'cold-start',
    evidence: { noRatedSessions: true, noVoiceSet: true },
    userTurn: 'Where should I start?',
  });
  const r = runChecks(
    'No baseline yet, so record 60 seconds on something you know cold and stay below four fillers.',
    fx,
    { contextBlock: 'BASELINE\n- Not enough data for a stable baseline yet.' },
  );
  assert.ok(r.findings.some((f) => f.id === 'coldStartMetricTarget'));
  assert.ok(r.caps.some((f) => f.id === 'coldStartUncalibratedMetricTarget'));
  assert.equal(r.hardCap, 50);
  assert.ok(!r.caps.some((f) => f.id === 'coldStartFakeCalibration'));
});

test('checks: plain cold-start first rep does NOT flag product or metric overreach', () => {
  const fx = baseFx({
    category: 'cold-start',
    evidence: { noRatedSessions: true, noVoiceSet: true },
    userTurn: 'What should I work on?',
  });
  const r = runChecks(
    "No baseline yet, so start there. Record 60 seconds on anything you know well, and I'll have something real to read: pace, fillers, and where the point lands. Want to go now?",
    fx,
    { contextBlock: 'BASELINE\n- Not enough data for a stable baseline yet.' },
  );
  assert.ok(!r.findings.some((f) => f.id === 'coldStartProductJargon'));
  assert.ok(!r.findings.some((f) => f.id === 'coldStartMetricTarget'));
});

test('checks: vague cold-start baseline rep flags before baseline', () => {
  const fx = baseFx({
    category: 'cold-start',
    evidence: { noRatedSessions: true, noVoiceSet: true },
    userTurn: 'What should I work on?',
  });
  const r = runChecks(
    'No baseline yet, so record one short rep before polishing the answer.',
    fx,
    { contextBlock: 'BASELINE\n- Not enough data for a stable baseline yet.' },
  );
  assert.ok(r.findings.some((f) => f.id === 'coldStartVagueBaselineRep'));
});

test('checks: real-read trust-repair scaffold flags', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: "That's not informative.",
  });
  const r = runChecks(
    'Fair. That was too vague. Real read: your point arrived in sentence four.',
    fx,
    {},
  );
  assert.ok(r.findings.some((f) => f.id === 'scaffoldLabel'));
});

test('checks: trust-repair raw score readout flags report voice', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: 'ok prove it again, what specifically have I been doing wrong',
  });
  const bad = runChecks(
    'Fair push. This week you scored 74 over 95 seconds with only 4 fillers, and the setup held the whole way. So hold one second before the final line.',
    fx,
    {},
  );
  const good = runChecks(
    'Fair push. Your last rep had 4 fillers, so say the decision first, give one proof point, then stop.',
    fx,
    {},
  );

  assert.ok(bad.findings.some((f) => f.id === 'trustRepairReportVoice'));
  assert.ok(bad.caps.some((f) => f.id === 'trustRepairReportVoiceCap'));
  assert.equal(bad.hardCap, 50);
  assert.ok(!good.findings.some((f) => f.id === 'trustRepairReportVoice'));
});

test('checks: trust-repair scaffold plus raw metric caps placeholder', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: "That's not informative.",
  });
  const r = runChecks(
    'Fair. That was fluff, not coaching. Real read: score 74, but your point arrived in sentence four. Next rep: say the point first.',
    fx,
    {},
  );

  assert.ok(r.findings.some((f) => f.id === 'scaffoldLabel'));
  assert.ok(r.findings.some((f) => f.id === 'trustRepairReportVoice'));
  assert.ok(r.caps.some((f) => f.id === 'trustRepairScaffoldReportVoice'));
  assert.equal(r.hardCap, 30);
});

test('finalizer: trust-repair scaffold and report voice are stripped before user display', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: "That's not informative.",
  });
  const result = finalizeReplyForFixture(
    'Fair. That was fluff, not coaching. Real read: score 74, but your point arrived in sentence four. Next rep: say the point first.',
    fx,
  );

  assert.equal(result.text, 'Fair. That was fluff, not coaching. Your point arrived in sentence four. Say the point first.');
  assert.deepEqual(result.changes, ['displaySanitizer', 'reportVoiceResidue']);
});

test('finalizer: requested metric answers keep their numbers', () => {
  const fx = baseFx({
    category: 'data-question',
    turnDepth: 'groundedRead',
    userTurn: "What's my filler rate?",
  });
  const reply = 'Your last rep had 3 fillers in 68 seconds, which is cleaner than the prior two.';
  const result = finalizeReplyForFixture(reply, fx);

  assert.equal(result.text, reply);
  assert.equal(result.changed, false);
});

test('checks: sensitive goal-change metric dump flags report voice', () => {
  const fx = baseFx({
    category: 'goal-change',
    turnDepth: 'groundedRead',
    userTurn: 'I think I want to sound more engaging.',
    memoryState: { goalIntent: { case: 'change', from: 'authoritative', to: 'engaging' } },
  });
  const bad = runChecks(
    'Before you pivot, know your authoritative work is landing: 80 this week, 3 fillers in 68 seconds, three weeks in.',
    fx,
    {},
  );
  const good = runChecks(
    'That warmer pull makes sense to test, but I would not treat it as decided yet. Engaging maps closest to Storytelling, with Warm as the softer option.',
    fx,
    {},
  );

  assert.ok(bad.findings.some((f) => f.id === 'sensitiveTurnReportVoice'));
  assert.ok(bad.caps.some((f) => f.id === 'sensitiveTurnReportVoiceCap'));
  assert.equal(bad.hardCap, 50);
  assert.ok(!good.findings.some((f) => f.id === 'sensitiveTurnReportVoice'));
});

test('checks: sensitive greeting metric dump flags report voice but data question allows it', () => {
  const greeting = baseFx({ turnDepth: 'greeting', userTurn: 'Hi' });
  const dataQuestion = baseFx({ category: 'data-question', turnDepth: 'groundedRead', userTurn: "What's my filler rate?" });
  const bad = runChecks(
    "Good to have you back. Today's rep hit 80, 3 fillers, tight and clean, so run one more.",
    greeting,
    {},
  );
  const allowed = runChecks(
    'Your last rep had 3 fillers in 68 seconds, which is cleaner than the prior two.',
    dataQuestion,
    {},
  );

  assert.ok(bad.findings.some((f) => f.id === 'sensitiveTurnReportVoice'));
  assert.equal(bad.hardCap, 50);
  assert.ok(!allowed.findings.some((f) => f.id === 'sensitiveTurnReportVoice'));
});

test('checks: established-user Ah-Counter target is allowed when evidence exists', () => {
  const fx = baseFx({
    category: 'mechanics',
    evidence: { baseline: { fillersPerMin: 5.4 } },
    memoryState: {
      recentReps: [
        { when: 'this week', mode: 'Ah-Counter', fillers: 5, durationSec: 60 },
      ],
    },
    userTurn: 'What is my filler rate?',
  });
  const r = runChecks(
    'Your current baseline is 5.4 fillers per minute. Your last Ah-Counter rep had them clustering in the back half, so next round target under 4 fillers after the 30-second mark.',
    fx,
    { contextBlock: renderContext(fx) },
  );
  assert.ok(!r.findings.some((f) => f.id === 'coldStartProductJargon'));
  assert.ok(!r.findings.some((f) => f.id === 'coldStartMetricTarget'));
});

test('checks: exact voice set request flags closest-match hedge', () => {
  const fx = baseFx({
    category: 'goal-change',
    memoryState: { goalIntent: { case: 'set', to: 'authoritative' } },
    userTurn: 'Just set me to authoritative.',
  });
  const r = runChecks('The closest match is Authoritative. Tap to confirm on the card.', fx, {});
  assert.ok(r.findings.some((f) => f.id === 'goalIntentExactVoiceHedge'));
});

test('checks: engaging goal-change must map to Storytelling and Warm', () => {
  const fx = baseFx({
    category: 'goal-change',
    memoryState: { goalIntent: { case: 'change', from: 'authoritative', to: 'engaging' } },
    userTurn: 'I think I want to sound more engaging.',
  });
  const bad = runChecks('Engaging makes sense. Tap the card when you are ready.', fx, {});
  assert.ok(bad.findings.some((f) => f.id === 'goalIntentMissingEngagingMap'));

  const good = runChecks('Engaging is not one of the six. Closest are Storytelling for arcs or Warm for connection; pick the pull before you use the confirmation card.', fx, {});
  assert.ok(!good.findings.some((f) => f.id === 'goalIntentMissingEngagingMap'));
});

test('checks: voice-choice turn flags six-voice menu dump', () => {
  const fx = baseFx({
    category: 'goal-change',
    userTurn: 'What voice should I even pick?',
  });
  const r = runChecks('You can choose Authoritative, Warm, Concise, Persuasive, Executive Presence, or Storytelling. Each has benefits.', fx, {});
  assert.ok(r.findings.some((f) => f.id === 'goalIntentVoiceMenu'));
});

test('checks: goal-change turn flags UI/state directive', () => {
  const fx = baseFx({
    category: 'goal-change',
    userTurn: 'What voice should I even pick?',
  });
  const bad = runChecks('Start with Authoritative. Tap to confirm and I’ll lock it in.', fx, {});
  assert.ok(bad.findings.some((f) => f.id === 'goalIntentStateDirective'));

  const good = runChecks('Start with Authoritative because meetings where you get talked over need short verdicts that hold the floor. Executive presence is the close second if the room is more senior than interrupt-heavy.', fx, {});
  assert.ok(!good.findings.some((f) => f.id === 'goalIntentStateDirective'));
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

test('score: hallucinated judge cap contradicting closerTo=excellent is advisory, not clamped', () => {
  // The live am-i-improving defect: judge says closerTo=excellent AND
  // placeholderOrBroken=true on a grounded reply with zero deterministic caps.
  const det = { caps: [], flags: [{ id: 'scaffoldLabel', penalty: 8 }], flagPenalty: 8, placeholderLeaks: 0 };
  const judge = { judgeTotal: 84, caps: { placeholderOrBroken: true, ignoresIntent: false, fabricatesEvidence: false, unsafe: false }, closerTo: 'excellent' };
  const s = combineScore(det, judge);
  assert.equal(s.hardCap, null, 'self-contradicted judge-only cap must not clamp');
  assert.equal(s.final, 76); // 84 - 8 flag, no cap
  assert.deepEqual(s.advisoryJudgeCaps, ['placeholderOrBroken'], 'discarded cap is recorded as advisory');
});

test('score: judge cap with closerTo=between still clamps (guard is excellent-only)', () => {
  const det = { caps: [], flags: [], flagPenalty: 0, placeholderLeaks: 0 };
  const judge = { judgeTotal: 80, caps: { placeholderOrBroken: true, ignoresIntent: false, fabricatesEvidence: false, unsafe: false }, closerTo: 'between' };
  const s = combineScore(det, judge);
  assert.equal(s.hardCap, 30);
  assert.equal(s.final, 30);
});

test('score: judge unsafe cap always clamps even against closerTo=excellent', () => {
  const det = { caps: [], flags: [], flagPenalty: 0, placeholderLeaks: 0 };
  const judge = { judgeTotal: 92, caps: { placeholderOrBroken: false, ignoresIntent: false, fabricatesEvidence: false, unsafe: true }, closerTo: 'excellent' };
  const s = combineScore(det, judge);
  assert.equal(s.hardCap, 0, 'unsafe is never discardable');
  assert.equal(s.final, 0);
});

test('score: deterministically corroborated judge cap clamps even with closerTo=excellent', () => {
  const det = { caps: [{ capKey: 'placeholderOrBroken', capMax: 30 }], flags: [], flagPenalty: 0, placeholderLeaks: 1 };
  const judge = { judgeTotal: 90, caps: { placeholderOrBroken: true, ignoresIntent: false, fabricatesEvidence: false, unsafe: false }, closerTo: 'excellent' };
  const s = combineScore(det, judge);
  assert.equal(s.hardCap, 30, 'deterministic evidence keeps the clamp');
  assert.equal(s.final, 30);
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

// POSITIONAL TREND — the recurring-position read iters 19-20 shipped to the app
// but the harness never rendered, so the loop could not judge the coach speaking
// its own #1 named behavior. These lock the render + Swift-parity wording so the
// harness composes the EXACT sentence CoachContextBuilder emits.
test('context: POSITIONAL TREND renders and mirrors Swift RepEventTrend.readout (with prevalence)', () => {
  const fx = baseFx({ memoryState: { positionalTrend: [{ kind: 'rushedBurst', zone: 'close', dominantCount: 4, repsWithSignal: 5, windowRepCount: 6 }] } });
  const ctx = renderContext(fx);
  assert.ok(ctx.includes('POSITIONAL TREND (recurring event position across recent reps)'), 'header present');
  // Byte-for-byte the Swift readout (RepEventTrend.swift:74-75) at this shape.
  assert.ok(ctx.includes("You've rushed the close in 4 of your last 5 reps that had a fast stretch — the fastest stretch keeps landing there. It showed up in 5 of your last 6 reps overall. A recurring position, not a fixed trait."), 'composed line + base-rate prevalence matches Swift');
});

test('context: POSITIONAL TREND suppresses the base-rate tail when the event carried every readable rep', () => {
  const fx = baseFx({ memoryState: { positionalTrend: [{ kind: 'longestPause', zone: 'opening', dominantCount: 3, repsWithSignal: 5, windowRepCount: 5 }] } });
  const ctx = renderContext(fx);
  // repsWithSignal === windowRepCount → no "It showed up in N of your last N reps overall." (mirrors Swift's `repsWithSignal < windowRepCount` guard).
  assert.ok(ctx.includes('Your longest silence has fallen in the opening in 3 of your last 5 reps that had a notable pause. A recurring position, not a fixed trait.'));
  assert.ok(!ctx.includes('reps overall'), 'no redundant N-of-N base rate when prevalence is 100%');
});

test('context: POSITIONAL TREND is omitted entirely when absent (never invents a section)', () => {
  const ctx = renderContext(baseFx());
  assert.ok(!ctx.includes('POSITIONAL TREND'), 'no section without data');
});

test('context: POSITIONAL TREND drops malformed trends but keeps valid ones', () => {
  const fx = baseFx({ memoryState: { positionalTrend: [
    { kind: 'bogusKind', zone: 'close', dominantCount: 4, repsWithSignal: 5, windowRepCount: 6 },
    { kind: 'fillerCluster', zone: 'middle', dominantCount: 3, repsWithSignal: 4, windowRepCount: 6 },
  ] } });
  const ctx = renderContext(fx);
  assert.ok(ctx.includes('Fillers have clustered in the middle in 3 of your last 4 reps'), 'valid trend renders');
  assert.ok(!ctx.includes('bogusKind'), 'malformed trend dropped, not leaked');
});

test('report: production readiness fails on missing captures and low fixture pockets', () => {
  const summary = summarize([
    scoredRecord({ fixture: { id: 'strong', turnDepth: 'deepAssessment' }, score: { final: 90 } }),
    scoredRecord({ fixture: { id: 'weak', turnDepth: 'trustRepair' }, score: { final: 55 } }),
    { status: 'missing-reply', fixture: { id: 'missing', category: 'mechanics', turnDepth: 'groundedRead' } },
  ]);

  assert.equal(summary.productionReady, false);
  assert.equal(summary.missing, 1);
  assert.equal(summary.sub70, 1);
  assert.equal(summary.thresholds.zeroMissingReplies.pass, false);
  assert.equal(summary.thresholds.fixtureScoreFloor.pass, false);
  assert.equal(summary.thresholds.zeroSub70Fixtures.pass, false);
});

test('report: production readiness can pass only with complete coverage and no weak fixtures', () => {
  const summary = summarize([
    scoredRecord({ fixture: { id: 'deep', turnDepth: 'deepAssessment' }, score: { final: 72 } }),
    scoredRecord({ fixture: { id: 'trust', turnDepth: 'trustRepair' }, score: { final: 70 } }),
    scoredRecord({ fixture: { id: 'grounded', turnDepth: 'groundedRead' }, score: { final: 78 } }),
  ]);

  assert.equal(summary.productionReady, true);
  assert.equal(summary.missing, 0);
  assert.equal(summary.sub70, 0);
  assert.equal(summary.thresholds.zeroMissingReplies.pass, true);
  assert.equal(summary.thresholds.fixtureScoreFloor.pass, true);
  assert.equal(summary.thresholds.zeroSub70Fixtures.pass, true);
});

test('report: cacheSummary is additive and reports zero on records with no usage data', () => {
  const summary = summarize([
    scoredRecord({ fixture: { id: 'a' } }),
    scoredRecord({ fixture: { id: 'b' } }),
  ]);
  assert.deepEqual(summary.cacheSummary, {
    requestsWithUsage: 0,
    cacheHits: 0,
    cacheHitRate: null,
    cacheReadTokens: 0,
    cacheCreationTokens: 0,
    cachedContentTokens: 0,
    inputTokens: 0,
    outputTokens: 0,
    estimatedTokensSaved: 0,
  });
});

test('report: cacheSummary aggregates Anthropic cache_read/cache_creation across records', () => {
  const summary = summarize([
    {
      ...scoredRecord({ fixture: { id: 'hit' } }),
      trace: { usage: { input_tokens: 1300, output_tokens: 40, cache_creation_input_tokens: 0, cache_read_input_tokens: 1180 } },
    },
    {
      ...scoredRecord({ fixture: { id: 'miss' } }),
      trace: { usage: { input_tokens: 1300, output_tokens: 38, cache_creation_input_tokens: 1180, cache_read_input_tokens: 0 } },
    },
  ]);
  const c = summary.cacheSummary;
  assert.equal(c.requestsWithUsage, 2);
  assert.equal(c.cacheHits, 1);
  assert.equal(c.cacheHitRate, 50);
  assert.equal(c.cacheReadTokens, 1180);
  assert.equal(c.cacheCreationTokens, 1180);
  assert.equal(c.inputTokens, 2600);
  assert.equal(c.outputTokens, 78);
  assert.equal(c.estimatedTokensSaved, 1180);
});

test('report: cacheSummary reads Gemini cachedContentTokenCount independently of Anthropic fields', () => {
  const summary = summarize([
    {
      ...scoredRecord({ fixture: { id: 'gemini-hit' } }),
      trace: { usage: { promptTokenCount: 900, candidatesTokenCount: 30, cachedContentTokenCount: 700 } },
    },
  ]);
  const c = summary.cacheSummary;
  assert.equal(c.requestsWithUsage, 1);
  assert.equal(c.cacheHits, 1);
  assert.equal(c.cachedContentTokens, 700);
  assert.equal(c.inputTokens, 900);
  assert.equal(c.outputTokens, 30);
  assert.equal(c.estimatedTokensSaved, 700);
});

test('report: user-visible deterministic audit is separate from official scoring', () => {
  const summary = summarize([
    {
      ...scoredRecord({ score: { final: 82, placeholderLeaks: 1 } }),
      userVisible: {
        changedFromScoredReply: true,
        deterministic: {
          findings: [
            { id: 'sensitiveTurnReportVoice', tier: 'flag', capKey: null },
          ],
          hardCap: null,
          placeholderLeaks: 0,
        },
      },
    },
    {
      ...scoredRecord({ score: { final: 84, placeholderLeaks: 0 } }),
      userVisible: {
        changedFromScoredReply: false,
        deterministic: {
          findings: [
            { id: 'scaffoldStructuralLabel', tier: 'cap', capKey: 'voiceIntegrity' },
          ],
          hardCap: 65,
          placeholderLeaks: 0,
        },
      },
    },
    {
      ...scoredRecord({ score: { final: 86, placeholderLeaks: 0 }, fixture: { id: 'unmodeled-cap' } }),
      userVisible: {
        changedFromScoredReply: false,
        deterministic: {
          findings: [
            { id: 'newUnmodeledCap', tier: 'cap', capKey: 'voiceIntegrity' },
          ],
          hardCap: 65,
          placeholderLeaks: 0,
        },
      },
    },
  ]);

  assert.equal(summary.placeholderLeaks, 1, 'official raw-score leak count is unchanged');
  assert.equal(summary.userVisibleDeterministic.repliesChecked, 3);
  assert.equal(summary.userVisibleDeterministic.changedFromScoredReply, 1);
  assert.equal(summary.userVisibleDeterministic.cappedReplies, 2);
  assert.equal(summary.userVisibleDeterministic.gateBackedCappedReplies, 1);
  assert.equal(summary.userVisibleDeterministic.unbackedCappedReplies, 1);
  assert.deepEqual(summary.userVisibleDeterministic.unbackedCappedFixtureIDs, ['unmodeled-cap']);
  assert.equal(summary.userVisibleDeterministic.placeholderLeaks, 0);
  assert.equal(summary.userVisibleDeterministic.capCounts.voiceIntegrity, 2);
  assert.equal(summary.userVisibleDeterministic.gateBackedCapCounts.voiceIntegrity, 1);
  assert.equal(summary.userVisibleDeterministic.unbackedCapCounts.voiceIntegrity, 1);
});
