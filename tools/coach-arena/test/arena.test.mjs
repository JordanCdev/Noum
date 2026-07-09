// Unit tests for the Coach Arena core logic. Run: node --test  (or ./run.sh test)
import { existsSync, mkdtempSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

import { composeSystemPrompt, extractAll, VOICES } from '../lib/extractPrompt.mjs';
import { runChecks } from '../lib/checks.mjs';
import { combineScore } from '../lib/score.mjs';
import { parseJudge } from '../lib/judge.mjs';
import { renderContext } from '../lib/context.mjs';
import { depthRulesBlock } from '../lib/depthRules.mjs';
import { renderFailures, summarize } from '../lib/report.mjs';
import { finalizeReplyForFixture } from '../lib/finalizeReply.mjs';
import { productionSurfaceReplyForFixture } from '../lib/productionSurface.mjs';

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

test('depth rules mirror critical cold-start and voice-change guardrails', () => {
  const text = depthRulesBlock(baseFx({
    category: 'goal-change',
    turnDepth: 'groundedRead',
    userTurn: 'What voice should I even pick?',
  }));

  assert.match(text, /Cold start rule: when there is no baseline or no rated sessions/);
  assert.match(text, /do not open with 'No baseline yet'/);
  assert.match(text, /do not name internal practice modes/);
  assert.match(text, /do not set filler or score targets/);
  assert.match(text, /On voice or goal-change turns, do not use raw score, filler, or duration readouts as proof/);
  assert.match(text, /let the confirmation card handle UI/);
  assert.match(text, /do not tell them to tap, confirm, or lock it in/i);
});

test('run.sh app-path refuses stale canonical dump before scoring', () => {
  const dumpDir = mkdtempSync(join(tmpdir(), 'noum-app-path-stale-'));
  const reportPath = join(dumpDir, 'coach-chat-conversation-app-path-eval-v1.json');
  writeFileSync(reportPath, JSON.stringify({ passesAppPathFloor: true, rows: [] }), 'utf8');

  const result = spawnSync('bash', ['run.sh', 'app-path', reportPath], {
    cwd: rootDir,
    encoding: 'utf8',
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stdout, /"passes": false/);
  assert.match(result.stdout, /missingSourceGitCommitSidecar|missingSourceCoachFingerprintSidecar|noArenaTraceRows/);
  assert.doesNotMatch(result.stderr, /Warning: scoring app-path dump with stale-source guard disabled/);
});

test('run.sh stale app-path override routes to diagnostic output dirs', () => {
  const script = readFileSync(join(rootDir, 'run.sh'), 'utf8');

  assert.match(script, /reports_dir="reports\/app-path-diagnostic"/);
  assert.match(script, /synthetic_dir="synthetic\/app-path-diagnostic"/);
  assert.match(script, /default diagnostic reports dir is \$\{reports_dir\} unless --reports-dir overrides it/);
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

test('finalizer: report voice stripping preserves filler-comparison grammar', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: 'This is so generic, it could be for anyone.',
  });
  const result = finalizeReplyForFixture(
    'For a persuasive pitch, that softens the one line the whole thing turns on, more than your 7 fillers do.',
    fx,
  );

  assert.equal(result.text, 'For a persuasive pitch, that softens the one line the whole thing turns on, more than the filler words do.');
  assert.deepEqual(result.changes, ['reportVoiceResidue']);
  assert.doesNotMatch(result.text, /7 fillers|your do/i);
});

test('finalizer: display-only scaffold stripping recapitalizes new paragraph action', () => {
  const fx = baseFx({
    category: 'mechanics',
    turnDepth: 'groundedRead',
    userTurn: 'I ramble.',
  });
  const result = finalizeReplyForFixture(
    "You don't lose the thread — you keep adding to it.\n\nNext rep: say your point, one line of support, then stop.",
    fx,
  );

  assert.equal(result.text, "You don't lose the thread — you keep adding to it.\nSay your point, one line of support, then stop.");
  assert.deepEqual(result.changes, ['displaySanitizer']);
  assert.doesNotMatch(result.text, /\nsay/);
});

test('finalizer: stripped label does not break camel-case action starts', () => {
  const result = finalizeReplyForFixture(
    'Next rep: iOS launch answer, one reason, stop.',
    baseFx({ userTurn: 'what next?' }),
  );

  assert.equal(result.text, 'iOS launch answer, one reason, stop.');
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

test('production surface: cold-start product jargon falls back before user display', () => {
  const fx = baseFx({
    category: 'cold-start',
    evidence: { noRatedSessions: true, noVoiceSet: true },
    turnDepth: 'groundedRead',
    userTurn: 'What should I work on?',
  });
  const raw = "No baseline yet, so start there.\n\nDo one Ah-Counter round: 60 seconds on a topic you know cold, aiming to stay under 4 fillers. That gives you a first number.";
  const result = productionSurfaceReplyForFixture(raw, fx, {
    contextBlock: 'BASELINE\n- Not enough data for a stable baseline yet.',
  });

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['coldStartJargon']);
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.ok(!result.text.includes('Ah-Counter'));
  assert.ok(!/under\s+4\s+fillers/i.test(result.text));
  assert.ok(!/baseline/i.test(result.text));
  assert.ok(result.text.startsWith('Start with one real sample.'));
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: off-topic test metric drill redirects before user display', () => {
  const fx = baseFx({
    category: 'off-topic',
    turnDepth: 'quickMove',
    userTurn: 'egg',
  });
  const raw = "Egg won't sharpen you. This will: today's rep hit 80, 3 fillers, tight and clean. Run one more Timed rep and hold a silent beat where those fillers landed — aim to beat 3.";
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['offTopicTestWithDrill']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.offTopicTestFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, "Tiny test. All good. Send the moment you want to practice, and I'll give you one clean read.");
  assert.ok(!/score|fillers|timed|\/10|not a coaching ask|pretending/i.test(result.text));
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: greeting with drill greets back before user display', () => {
  const fx = baseFx({
    category: 'greeting',
    turnDepth: 'greeting',
    userTurn: 'Hi',
  });
  const raw = 'Good to have you back. Yesterday the close held once but softened once, so the target stands: land the final sentence flat and stop. Run one rep and make the whole point closing clean.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['greetingWithDrill']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.greetingFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, 'Hey — good to see you back. Pick up with the close: land the final sentence flat, then stop.');
  assert.ok(!/run one|next rep|fillers|timed|\/10/i.test(result.text));
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: trust repair without attunement falls back before user display', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: "That's not informative at all.",
  });
  const raw = 'Run one 60-second rep with the point in sentence one, then stop after one reason.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['noAttunementOnPushback']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.truthfulFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, "You're right to push me on that. I don't have a clean enough read to answer it well yet. Give me one 60-second rep on that exact scenario and I'll name the single biggest gap.");
  assert.ok(!/^run one/i.test(result.text));
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: thin trust repair falls back before user display', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: 'This sounds cold and generic, like AI tips.',
  });
  const raw = 'Fair push. Run one 60-second rep with the recommendation first, then stop cleanly.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['thinTrustRepair']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.truthfulFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, "You're right to push me on that. I don't have a clean enough read to answer it well yet. Give me one 60-second rep on that exact scenario and I'll name the single biggest gap.");
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: repetition callout falls back to course correction', () => {
  const fx = baseFx({
    category: 'repetition-callout',
    turnDepth: 'trustRepair',
    userTurn: "You're repeating yourself.",
  });
  const raw = 'Fair. I did. That rep hit 82 with a clean close — no reason to run it again.\n\nNew target: pace. Record 60 seconds and deliberately slow your three most important words, holding a silent beat before each.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['repetitionCourseCorrectionMiss']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.repetitionCourseCorrectionFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, 'Fair. I did repeat the same target. You led cleanly and the close held, so there is no reason to run that drill again. New target: pace. Slow the three words that carry the point, then hold one silent beat before the next sentence.');
  assert.doesNotMatch(result.text, /hit 82|lead with the point|point up front/i);
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: clean repetition course correction ships', () => {
  const fx = baseFx({
    category: 'repetition-callout',
    turnDepth: 'trustRepair',
    userTurn: "You're repeating yourself.",
  });
  const raw = 'Fair. I did repeat the same target. You led cleanly and the close held, so there is no reason to run that drill again. New target: pace. Slow the three words that carry the point, then hold one silent beat before the next sentence.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.deepEqual(result.reliabilityGate.issues, []);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: specific could-go-to-anyone repair ships', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: 'This is so generic, it could be for anyone.',
  });
  const raw = 'Fair. That read like it could go to anyone, and you deserve better this close to the investor call. The specific pattern is that you hedged the ask twice — "we\'re hoping to maybe raise around" instead of stating the number. State the raise as one flat sentence, then stop.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.deepEqual(result.reliabilityGate.issues, []);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: scaffolded too-generic repair falls back before display', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: 'This is so generic, it could be for anyone.',
  });
  const raw = 'Fair. That read like it could go to anyone, and you deserve better this close to the investor call.\n\nThe specific thing: on that pitch rep you hedged the ask twice — "we\'re hoping to maybe raise around" instead of the number. For a persuasive pitch, that softens the one line the whole thing turns on, more than your 7 fillers do.\n\nNext rep: state the raise as one flat sentence, then stop.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['genericRepairScaffolded']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.genericRepairFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, 'Fair. That was too generic. The specific pattern is the ask itself. You softened the number instead of stating it. State the raise as one flat sentence, no qualifier, then stop.');
  assert.ok(!/specific thing:|next rep:|fillers/i.test(result.text));
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: not-informative scaffolded repair falls back before user display', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: "That's not informative.",
  });
  const raw = 'Fair. That was fluff, not coaching. Real read: score 74, but your point did not arrive until sentence four. Next rep: say the point in sentence one, then back it. Cut the throat-clearing.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['notInformativeRepairScaffold']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.notInformativeRepairFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, 'Fair. I was too vague. The useful read is that your point arrived in sentence four after three warm-up sentences. Make sentence one the point; let one reason do the supporting.');
  assert.ok(!/real read:|score|cut the/i.test(result.text));
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: clean not-informative repair ships', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: "That's not informative.",
  });
  const raw = 'Fair. I was too vague. The useful read is that your point arrived in sentence four after three warm-up sentences. Make sentence one the point; let one reason do the supporting.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: straight-answer reply missing split falls back before user display', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: "Why can't you just give me a straight answer?",
  });
  const raw = "Fair. That was waffle. Straight answer: yes. Fillers dropped from 5.5 to 3.2 a minute over two weeks, and your last rep hit 3 in 60 seconds — your best on record. What's still moving is pace under pressure. Next rep, hold one silent beat before you answer a hard question.";
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['straightAnswerSplitMissing']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.straightAnswerSplitFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, 'Fair. Straight answer: yes on fillers; no on pace under pressure. Your filler trend is moving the right way, but the rush still shows up when the pressure rises. Next rep, hold one silent beat before the hard answer.');
  assert.ok(!/hit 3|scored/i.test(result.text));
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: clean straight-answer split ships', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: "Why can't you just give me a straight answer?",
  });
  const raw = 'Fair. Straight answer: yes on fillers; no on pace under pressure. Your filler trend is moving the right way, but the rush still shows up when the pressure rises. Next rep, hold one silent beat before the hard answer.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: pace self-frustration report voice falls back before user display', () => {
  const fx = baseFx({
    category: 'mechanics',
    turnDepth: 'groundedRead',
    userTurn: "I talk way too fast, people can't keep up.",
    evidence: { pace: 215, pauseRate: 0.09 },
    memoryState: { baseline: { pace: 215, pauseRate: 0.09 } },
  });
  const raw = "It's not the speed. Yesterday's rep was clean and scored 71, but pace sat near 215 with almost no gap between sentences — one idea ran straight into the next with no room to land.\n\nSo the fix isn't slowing down, it's the pause. Do a 60-second rep and hold one full second of silence after every sentence.";
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['paceSelfFrustrationReportVoice']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.paceSelfFrustrationFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, "You're not imagining it: 215 WPM with a 0.09 pause rate means the gap between sentences is disappearing. Fix the pause, not the speed. Next rep, hold one silent beat after every full stop and see if people track you without forcing a slower voice.");
  assert.ok(!/scored 71/i.test(result.text));
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: clean pace self-frustration read ships', () => {
  const fx = baseFx({
    category: 'mechanics',
    turnDepth: 'groundedRead',
    userTurn: "I talk way too fast, people can't keep up.",
    evidence: { pace: 215, pauseRate: 0.09 },
  });
  const raw = "You're not imagining it: 215 words a minute with a 0.09 pause rate means the gap between sentences is disappearing. Fix the pause, not the speed. Next rep, hold one silent beat after every full stop and see if people track you without forcing a slower voice.";
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: ramble scaffold falls back to stop rule', () => {
  const fx = baseFx({
    category: 'mechanics',
    turnDepth: 'groundedRead',
    userTurn: "I ramble — I start a point and three minutes later I'm somewhere else.",
  });
  const raw = "You don't lose the thread — you keep adding to it. Yesterday you opened with the actual point, then stacked three side stories before circling back to a weaker version of it. So the fix isn't focus, it's a stop signal.\n\nNext rep: say your point, one line of support, then cut before the first side story. One point, then silence.";
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['rambleStoppingRuleMiss']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.rambleStoppingRuleFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, 'You do not lose the thread; you keep reopening it. The tell is the weaker repeat at the end after the side stories. Use a hard stop: state the point, give one support line, then silence.');
  assert.doesNotMatch(result.text, /next rep:|be more concise/i);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: clean ramble stop rule ships', () => {
  const fx = baseFx({
    category: 'mechanics',
    turnDepth: 'groundedRead',
    userTurn: "I ramble — I start a point and three minutes later I'm somewhere else.",
  });
  const raw = 'You do not lose the thread; you keep reopening it. The tell is the weaker repeat at the end after the side stories. Use a hard stop: state the point, give one support line, then silence.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: leadership status report reply falls back to tonight rehearsal', () => {
  const fx = baseFx({
    category: 'leadership-update',
    turnDepth: 'deepAssessment',
    userTurn: "I have to give the weekly leadership update to the whole department tomorrow. It always feels like I'm just reading a status report and people zone out. Help.",
  });
  const raw = 'The room zones out because nine updates all land at the same weight — your last rep was clean at 77, but with no through-line, nothing gets to matter more than anything else. For tomorrow: pick the one update that actually changes what they do this week, open on it, and say the "so what" in a sentence before any detail.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['leadershipStatusReportMiss']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.leadershipStatusReportFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, 'That is a real risk for tomorrow: if every update lands at the same weight, the room hears a status report. The fix is hierarchy, not delivery polish. Tonight, write the opener as: "The one thing that matters this week is X because Y." Say it aloud three times, then let the other items become quick support.');
  assert.doesNotMatch(result.text, /77|score|clean at/i);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: clean leadership status report rehearsal ships', () => {
  const fx = baseFx({
    category: 'leadership-update',
    turnDepth: 'deepAssessment',
    userTurn: "I have to give the weekly leadership update to the whole department tomorrow. It always feels like I'm just reading a status report and people zone out. Help.",
  });
  const raw = 'That is a real risk for tomorrow: if every update lands at the same weight, the room hears a status report. The fix is hierarchy, not delivery polish. Tonight, write the opener as: "The one thing that matters this week is X because Y." Say it aloud three times, then let the other items become quick support.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: recurring close rush trend falls back to full trajectory read', () => {
  const fx = baseFx({
    category: 'mechanics',
    turnDepth: 'groundedRead',
    userTurn: 'What should I work on next? The last one felt solid to me.',
    memoryState: {
      positionalTrend: [
        { kind: 'rushedBurst', zone: 'close', dominantCount: 4, repsWithSignal: 5, windowRepCount: 6 },
      ],
    },
  });
  const raw = "The open landed — that read came through in today's rep too.\n\nThe one thing to fix is the close. Your last 20 seconds sped up and the final line ran together, and that pattern has shown up in 4 of your last 5 reps. That's the gap between how it felt and how it lands for the room.\n\nNext rep: hit your second-to-last sentence, hold a silent beat, then say the final line at half the pace you think you need.";
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['recurringCloseTrendDiluted']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.recurringCloseRushFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, 'That solid feeling is real, and the next edge is specific: the fastest stretch keeps landing at the close. It has shown up in 4 of the last 5 reps with a fast stretch, and 5 of the last 6 overall — a recurring spot, not a trait. Plant one silent beat before the final line.');
  assert.doesNotMatch(result.text, /second-to-last|half the pace/i);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: clean recurring close rush trajectory read ships', () => {
  const fx = baseFx({
    category: 'mechanics',
    turnDepth: 'groundedRead',
    userTurn: 'What should I work on next? The last one felt solid to me.',
    memoryState: {
      positionalTrend: [
        { kind: 'rushedBurst', zone: 'close', dominantCount: 4, repsWithSignal: 5, windowRepCount: 6 },
      ],
    },
  });
  const raw = 'That solid feeling is real, and the next edge is specific: the fastest stretch keeps landing at the close. It has shown up in 4 of the last 5 reps with a fast stretch, and 5 of the last 6 overall — a recurring spot, not a trait. Plant one silent beat before the final line.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: metadata self-knowledge answer with prescription falls back', () => {
  const fx = baseFx({
    category: 'metadata-trap',
    turnDepth: 'groundedRead',
    userTurn: 'What does your system actually know about me?',
    evidence: {
      goal: 'sounding like yourself in hard conversations',
      pressurePattern: 'race to fill silence when a moment turns tense',
      baselinePace: '170 WPM',
      streak: '12 days',
    },
  });
  const raw = "Here's the shape of it: you came in five weeks ago wanting to sound like yourself in the hard conversations, and you've shown up twelve days running to get there. The thread I'm working is that when a moment turns tense you speed up to outrun the silence — your 170 pace reads more like nerves than a habit.\n\nSo the thing to test: next rep, hold one silent beat before you answer a hard question.";
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['metadataSelfKnowledgeMiss']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.metadataSelfKnowledgeFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, 'Real read, not a script: you came in wanting to sound like yourself in hard conversations. The pattern I know is that tense moments make you race to fill silence; the numbers I can safely name are a pace baseline around 170 WPM and a 12-day streak. That is what I know. I will wait on a next drill until you ask for one.');
  assert.doesNotMatch(result.text, /next rep|system prompt|context block/i);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: clean metadata self-knowledge synthesis ships', () => {
  const fx = baseFx({
    category: 'metadata-trap',
    turnDepth: 'groundedRead',
    userTurn: 'What does your system actually know about me?',
    evidence: {
      goal: 'sounding like yourself in hard conversations',
      pressurePattern: 'race to fill silence when a moment turns tense',
      baselinePace: '170 WPM',
      streak: '12 days',
    },
  });
  const raw = 'Real read, not a script: you came in wanting to sound like yourself in hard conversations. The pattern I know is that tense moments make you race to fill silence; the numbers I can safely name are a pace baseline around 170 WPM and a 12-day streak. That is what I know. I will wait on a next drill until you ask for one.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: vulnerable pushback bare question falls back before user display', () => {
  const fx = baseFx({
    category: 'emotional-frustration',
    turnDepth: 'trustRepair',
    userTurn: "It's not easy.",
    memoryState: {
      recentReps: [
        { when: 'this week', mode: 'IM Conversation', note: 'held composure through a simulated interruption' },
      ],
    },
  });
  const raw = "No, it isn't — and a freeze in the room is a different animal than the reps you keep landing clean. When it hits, what goes first: the thought itself, or the words that were meant to carry it?";
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['vulnerablePushbackQuestionBurden']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.vulnerablePushbackFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, 'No, it is not easy. There is already one earned proof point: this week you held composure through an interruption. Keep the next step small: say only the first hard sentence, then stop.');
  assert.ok(!/what goes first/i.test(result.text));
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: vulnerable pushback fallback stays honest without earned evidence', () => {
  const fx = baseFx({
    category: 'emotional-frustration',
    turnDepth: 'trustRepair',
    userTurn: "It's not easy.",
  });
  const raw = "No, it isn't — and a freeze in the room is a different animal than the reps you keep landing clean. When it hits, what goes first: the thought itself, or the words that were meant to carry it?";
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['vulnerablePushbackQuestionBurden']);
  assert.equal(result.text, 'No, it is not easy. The freeze is real, so do not turn this into a full performance test. Keep the next step small: say only the first hard sentence, then stop.');
  assert.doesNotMatch(result.text, /earned proof point|held composure/i);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: vulnerable pushback with small-step invitation ships', () => {
  const fx = baseFx({
    category: 'emotional-frustration',
    turnDepth: 'trustRepair',
    userTurn: "It's not easy.",
  });
  const raw = 'No, it is not easy. Keep the next step small: test a smaller version in the next rep, then stop before defending it. Want to try?';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: voice state directive falls back before user display', () => {
  const fx = baseFx({
    category: 'goal-change',
    turnDepth: 'groundedRead',
    userTurn: 'What voice should I even pick? There are six and I do not know.',
  });
  const raw = "For meetings I'd start with Authoritative. Tap to confirm and I'll lock it in.";
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['goalStateDirectiveLeak']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.goalStateDirectiveFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, 'Start with Authoritative because meetings where you get talked over need short verdicts that hold the floor. Keep Executive presence as the close second if the room is more senior than interrupt-heavy. That gives you one voice to test, not six to debate.');
  assert.ok(!/tap|lock it|i'll set|i will set/i.test(result.text));
  assert.ok(!/do not choose/i.test(result.text));
  assert.ok(!result.deterministic.findings.some((f) => f.id === 'goalIntentStateDirective'));
  assert.ok(!result.deterministic.findings.some((f) => f.id === 'trailingSetupQuestion'));
});

test('production surface: engaging voice change preserves progress and asks why', () => {
  const fx = baseFx({
    category: 'goal-change',
    turnDepth: 'groundedRead',
    userTurn: 'I think I want to sound more engaging.',
  });
  const raw = 'Before you pivot, know your authoritative work is landing: 80 this week, 3 fillers in 68 seconds, three weeks in. That answer picks the voice, then tap to confirm and I\'ll lock it in.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['goalStateDirectiveLeak']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.goalStateDirectiveFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, 'Your authoritative work is already landing, so do not throw it away yet. Engaging maps closest to Storytelling, with Warm as the softer backup. Use Storytelling if you need more memorable shape; use Warm if you want the same authority to land with less distance. What changed: are you being heard now, or do you want the same point to land warmer?');
  assert.doesNotMatch(result.text, /80 this week|3 fillers|tap|lock it/i);
  assert.ok(!result.deterministic.findings.some((f) => f.id === 'goalIntentStateDirective'));
  assert.ok(!result.deterministic.findings.some((f) => f.id === 'goalIntentMissingEngagingMap'));
});

test('production surface: voice change raw metrics fall back without directive leak', () => {
  const fx = baseFx({
    category: 'goal-change',
    turnDepth: 'groundedRead',
    userTurn: 'I think I want to sound more engaging.',
  });
  const raw = 'Before you pivot, know your authoritative work is landing: 80 this week, 3 fillers in 68 seconds, three weeks in. Engaging maps closest to Storytelling, with Warm as the softer backup. What changed?';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['goalStateReportVoiceLeak']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.goalStateDirectiveFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, 'Your authoritative work is already landing, so do not throw it away yet. Engaging maps closest to Storytelling, with Warm as the softer backup. Use Storytelling if you need more memorable shape; use Warm if you want the same authority to land with less distance. What changed: are you being heard now, or do you want the same point to land warmer?');
  assert.doesNotMatch(result.text, /80 this week|3 fillers|68 seconds|tap|lock it/i);
});

test('production surface: clean voice recommendation ships', () => {
  const fx = baseFx({
    category: 'goal-change',
    turnDepth: 'groundedRead',
    userTurn: 'Just set me to authoritative.',
  });
  const raw = 'Authoritative is a sensible recommendation: verdict first, one reason, clean stop. Try it on the next 60-second answer.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
  assert.ok(!result.deterministic.findings.some((f) => f.id === 'goalIntentStateDirective'));
});

test('production surface: substantive trust repair does not invent a fallback', () => {
  const fx = baseFx({
    category: 'trust-repair',
    turnDepth: 'trustRepair',
    userTurn: 'This sounds cold and generic, like AI tips.',
  });
  const raw = 'Fair. That was advice, not coaching. Your warmth arrives before the recommendation, so put the recommendation first, then add one reassurance after it.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: clean off-topic redirect does not invent a fallback', () => {
  const fx = baseFx({
    category: 'off-topic',
    turnDepth: 'quickMove',
    userTurn: 'asdf',
  });
  const raw = "Tiny test. All good. Send the moment you want to practice, and I'll give you one clean read.";
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: odd word inside a real coaching question is not off-topic', () => {
  const fx = baseFx({
    category: 'mechanics',
    turnDepth: 'groundedRead',
    userTurn: 'why do I keep saying egg when I freeze?',
  });
  const raw = 'Your filler is showing up when pressure spikes. Run one 45-second rep and replace the first filler with a silent beat.';
  const result = productionSurfaceReplyForFixture(raw, fx);

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
});

test('production surface: clean finalized text does not invent a fallback', () => {
  const fx = baseFx({
    category: 'cold-start',
    evidence: { noRatedSessions: true, noVoiceSet: true },
    turnDepth: 'groundedRead',
    userTurn: 'What should I work on?',
  });
  const raw = "No baseline yet, so start there. Record 60 seconds on something you know well, and I'll have something real to read.";
  const result = productionSurfaceReplyForFixture(raw, fx, {
    contextBlock: 'BASELINE\n- Not enough data for a stable baseline yet.',
  });

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
});

test('production surface: cold-start named-rep overclaim falls back before user display', () => {
  const fx = baseFx({
    category: 'cold-start',
    evidence: { noRatedSessions: true, noVoiceSet: true },
    turnDepth: 'groundedRead',
    userTurn: 'Can you coach this?',
  });
  const raw = 'I can coach the latest rep: the close is the usable signal, so make the final sentence the ask, then stop.';
  const result = productionSurfaceReplyForFixture(raw, fx, {
    contextBlock: 'BASELINE\n- Not enough data for a stable baseline yet.',
  });

  assert.equal(result.reliabilityGate.changed, true);
  assert.deepEqual(result.reliabilityGate.issues, ['evidenceOverclaimNoBaseline']);
  assert.equal(result.reliabilityGate.source, 'CoachReliabilityGate.noBaselineReadFallback');
  assert.ok(result.changes.includes('reliabilityGateFallback'));
  assert.equal(result.text, "There's no rep for me to read yet, so I won't invent one. Record 60 seconds first, then I'll coach the opener and close from what actually happened — that's the honest way to do this.");
  assert.ok(!/latest rep|usable signal/i.test(result.text));
  assert.equal(result.deterministic.hardCap, null);
  assert.equal(result.deterministic.placeholderLeaks, 0);
});

test('production surface: honest cold-start missing-evidence read is not overclaim fallback', () => {
  const fx = baseFx({
    category: 'cold-start',
    evidence: { noRatedSessions: true, noVoiceSet: true },
    turnDepth: 'groundedRead',
    userTurn: 'Can you coach this?',
  });
  const raw = 'I need one rep before I can coach this honestly. Record 60 seconds, then I will read the opener and close.';
  const result = productionSurfaceReplyForFixture(raw, fx, {
    contextBlock: 'BASELINE\n- Not enough data for a stable baseline yet.',
  });

  assert.equal(result.reliabilityGate.changed, false);
  assert.equal(result.text, raw);
  assert.equal(result.deterministic.hardCap, null);
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
        reliabilityGate: {
          changed: true,
          issues: ['coldStartJargon'],
          source: 'CoachReliabilityGate.coldStartFallback',
        },
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
  assert.equal(summary.userVisibleDeterministic.reliabilityFallbackReplies, 1);
  assert.deepEqual(summary.userVisibleDeterministic.unbackedCappedFixtureIDs, ['unmodeled-cap']);
  assert.equal(summary.userVisibleDeterministic.placeholderLeaks, 0);
  assert.equal(summary.userVisibleDeterministic.capCounts.voiceIntegrity, 2);
  assert.equal(summary.userVisibleDeterministic.gateBackedCapCounts.voiceIntegrity, 1);
  assert.equal(summary.userVisibleDeterministic.unbackedCapCounts.voiceIntegrity, 1);
});

test('report: failures show mirrored production-surface fallback without changing raw score', () => {
  const record = scoredRecord({
    fixture: {
      id: 'cold-start-no-data',
      category: 'cold-start',
      turnDepth: 'groundedRead',
      userTurn: 'What should I work on?',
      expectedCoachMove: 'Give one first rep without inventing data.',
    },
    score: {
      final: 22,
      capsTriggered: [{ key: 'placeholderOrBroken', max: 30, sources: ['deterministic'] }],
      placeholderLeaks: 1,
    },
  });
  record.reply = 'Do one Ah-Counter round and stay under 4 fillers.';
  record.finalizer = {
    changed: true,
    changes: ['displaySanitizer'],
    scoringMode: 'rawReplayJudge',
    finalizedReply: 'Do one Ah-Counter round and stay under 4 fillers.',
  };
  record.deterministic = {
    findings: [{ id: 'coldStartProductJargon', evidence: 'Ah-Counter' }],
  };
  record.userVisible = {
    reply: "Start with one real sample. Run a quick 60-second rep on something you know well, and I'll have something honest to coach.",
    changedFromScoredReply: true,
    reliabilityGate: {
      changed: true,
      issues: ['coldStartJargon'],
      source: 'CoachReliabilityGate.coldStartFallback',
    },
    deterministic: { findings: [], hardCap: null, placeholderLeaks: 0 },
  };

  const text = renderFailures({ runId: 'unit-run', records: [record] });
  assert.ok(text.includes('Mirrored production-surface fallback: coldStartJargon via `CoachReliabilityGate.coldStartFallback`'));
  assert.ok(text.includes('replay score remains raw'));
  assert.ok(text.includes('MIRRORED USER-VISIBLE TEXT:'));
  assert.ok(text.includes('Start with one real sample.'));
});
