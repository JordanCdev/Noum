#!/usr/bin/env node
// Coach Arena runner.
//
//   plan    compose the real system prompt + context + messages for every
//           fixture and write runs/<runId>/requests.json (+ per-fixture request
//           files) so a generator/judge can be driven, or a live provider run.
//   run     generate coach replies, run deterministic checks, judge, score, and
//           write reports. Provider: anthropic (needs ANTHROPIC_API_KEY),
//           cli (`claude -p`), or replay (captures dir).
//   report  re-render reports from the latest run.json.
//
// Env: ARENA_PROVIDER, ARENA_MODEL, ARENA_JUDGE_MODEL, ARENA_CAPTURES,
//      ARENA_FIXTURES (glob dir), ARENA_INCLUDE_SYNTHETIC=1.

import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { composeSystemPrompt, extractAll } from '../lib/extractPrompt.mjs';
import { renderContext } from '../lib/context.mjs';
import { runChecks } from '../lib/checks.mjs';
import { buildJudgeUserPayload, parseJudge, JUDGE_SYSTEM, JUDGE_VERSION } from '../lib/judge.mjs';
import { combineScore } from '../lib/score.mjs';
import { makeProvider, COACH_MODEL, JUDGE_MODEL } from '../lib/provider.mjs';
import { writeReports } from '../lib/report.mjs';
import { gitTrace, toolVersions } from '../lib/trace.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const CAPTURES = process.env.ARENA_CAPTURES || join(ROOT, 'runners', 'captures');
const REPORTS = join(ROOT, 'reports');
const RUNS = join(ROOT, 'runs');

function loadFixtures() {
  const dirs = [join(ROOT, 'fixtures', 'gold')];
  if (process.env.ARENA_INCLUDE_SYNTHETIC === '1') dirs.push(join(ROOT, 'synthetic', 'conversations'));
  const fixtures = [];
  for (const dir of dirs) {
    if (!existsSync(dir)) continue;
    for (const f of readdirSync(dir).filter((x) => x.endsWith('.json')).sort()) {
      const fx = JSON.parse(readFileSync(join(dir, f), 'utf8'));
      // A conversation file may hold an array of turn-fixtures.
      const items = Array.isArray(fx) ? fx : fx.turns ? expandConversation(fx) : [fx];
      for (const it of items) {
        it._file = f;
        fixtures.push(it);
      }
    }
  }
  return fixtures;
}

// Expand a multi-turn synthetic conversation into per-turn fixtures with the
// prior turns pre-loaded as priorChatTurns.
function expandConversation(conv) {
  const out = [];
  const history = [];
  for (let i = 0; i < conv.turns.length; i++) {
    const turn = conv.turns[i];
    if (turn.role !== 'user') {
      history.push({ role: turn.role, text: turn.text });
      continue;
    }
    // A user turn is GRADED only if it carries an expected move; otherwise it is
    // context that sets up a later graded turn.
    if (turn.expectedCoachMove) {
      out.push({
        id: `${conv.id}__t${i}`,
        category: conv.category || 'synthetic-conversation',
        turnDepth: turn.turnDepth || 'groundedRead',
        voice: conv.voice || null,
        goal: conv.goal,
        priorChatTurns: history.slice(),
        userTurn: turn.text,
        emotionalSignal: turn.emotionalSignal || null,
        memoryState: turn.memoryState || conv.memoryState || {},
        expectedCoachMove: turn.expectedCoachMove,
        badAnswerExample: turn.badAnswerExample || '',
        excellentAnswerExample: turn.excellentAnswerExample || '',
        disqualifiers: turn.disqualifiers || [],
      });
    }
    history.push({ role: 'user', text: turn.text });
    if (turn.assistantPlaceholder) history.push({ role: 'assistant', text: turn.assistantPlaceholder });
  }
  return out;
}

const MAX_TOKENS = { greeting: 300, preference: 300, offTopic: 300, groundedRead: 500, trustRepair: 700, deepAssessment: 900, plan: 1100 };

// Anthropic prompt-caching system split, matching Noum/AICoachChatService.swift
// exactly: the stable voice prompt as its own cache_control-marked block,
// followed by the per-fixture dynamic context block, uncached. Only the live
// 'anthropic' provider path uses this — cli/plan consumers keep the flattened
// `system` string so requests.json and `claude -p --system-prompt` (which
// takes a single string arg) are unaffected.
function anthropicSystemBlocks(system, contextBlock) {
  return [
    { type: 'text', text: system, cache_control: { type: 'ephemeral' } },
    { type: 'text', text: contextBlock },
  ];
}

function composeRequest(fixture, extracted) {
  const system = composeSystemPrompt(fixture.voice || null, {}, extracted);
  const contextBlock = renderContext(fixture);
  const fullSystem = system + '\n\n' + contextBlock;
  const messages = [];
  for (const t of fixture.priorChatTurns || []) messages.push({ role: t.role === 'assistant' ? 'assistant' : 'user', content: t.text });
  messages.push({ role: 'user', content: fixture.userTurn });
  return {
    system: fullSystem,
    systemBlocks: anthropicSystemBlocks(system, contextBlock),
    contextBlock,
    messages,
    maxTokens: MAX_TOKENS[fixture.turnDepth] || 500,
  };
}

function newRunId() {
  const iso = new Date().toISOString().replace(/[:.]/g, '-').replace('T', '_').slice(0, 19);
  return `run_${iso}`;
}

function pickProvider() {
  const name = process.env.ARENA_PROVIDER || (process.env.ANTHROPIC_API_KEY ? 'anthropic' : 'replay');
  return { name, provider: makeProvider(name, { capturesDir: CAPTURES }) };
}

async function cmdPlan() {
  const extracted = extractAll();
  const fixtures = loadFixtures();
  const runId = newRunId();
  const dir = join(RUNS, runId);
  mkdirSync(dir, { recursive: true });
  mkdirSync(CAPTURES, { recursive: true });
  const requests = fixtures.map((fx) => {
    const req = composeRequest(fx, extracted);
    return {
      id: fx.id,
      file: fx._file,
      turnDepth: fx.turnDepth,
      voice: fx.voice || null,
      system: req.system,
      messages: req.messages,
      contextBlock: req.contextBlock,
      maxTokens: req.maxTokens,
      judgePayloadInputs: { fixtureId: fx.id },
    };
  });
  writeFileSync(join(dir, 'requests.json'), JSON.stringify({ runId, count: requests.length, coachModel: COACH_MODEL, requests }, null, 2));
  writeFileSync(join(RUNS, 'latest-plan.txt'), dir);
  console.error(`Planned ${requests.length} fixtures -> ${join(dir, 'requests.json')}`);
  console.error(`Captures expected in: ${CAPTURES}/<id>.reply.txt and <id>.judge.json`);
}

async function cmdRun() {
  const extracted = extractAll();
  const fixtures = loadFixtures();
  const { name: providerName, provider } = pickProvider();
  const runId = newRunId();

  const meta = {
    runId,
    provider: providerName,
    coachModel: COACH_MODEL,
    judgeModel: JUDGE_MODEL,
    judgeVersion: JUDGE_VERSION,
    git: gitTrace(),
    versions: toolVersions({ judge: JUDGE_VERSION }),
    promptProvenance: extracted.provenance,
    startedAt: new Date().toISOString(),
  };

  const records = [];
  let i = 0;
  for (const fx of fixtures) {
    i++;
    const req = composeRequest(fx, extracted);
    const rec = { fixture: publicFixture(fx), status: 'pending' };
    try {
      // 1. generate — the live anthropic provider gets the cache-split
      // system (production parity, and the only way this run can ever
      // produce a non-zero cache-read count); cli/replay get the flattened
      // string they've always taken.
      const generateSystem = providerName === 'anthropic' ? req.systemBlocks : req.system;
      const gen = await provider.generate({ id: fx.id }, { system: generateSystem, messages: req.messages, maxTokens: req.maxTokens });
      const reply = gen.text || '';
      rec.reply = reply;
      rec.trace = {
        provider: gen.provider,
        model: gen.model,
        latencyMs: gen.latencyMs,
        usage: gen.usage,
        stopReason: gen.stopReason,
        contextChars: req.contextBlock.length,
        systemChars: req.system.length,
        promptProvenance: extracted.provenance,
        gitCommit: meta.git.commit,
      };
      if (gen.missing) {
        rec.status = 'missing-reply';
        rec.note = `No capture at captures/${fx.id}.reply.txt (provider=${providerName}).`;
        records.push(rec);
        process.stderr.write(`  [${i}/${fixtures.length}] ${fx.id}: MISSING reply capture\n`);
        continue;
      }

      // 2. deterministic checks
      const recentReplies = (fx.priorChatTurns || []).filter((t) => t.role === 'assistant').map((t) => t.text);
      const deterministic = runChecks(reply, fx, { contextBlock: req.contextBlock, recentReplies });
      rec.deterministic = { findings: deterministic.findings, flagPenalty: deterministic.flagPenalty, hardCap: deterministic.hardCap, placeholderLeaks: deterministic.placeholderLeaks };

      // 3. judge
      const payload = buildJudgeUserPayload(fx, reply, req.contextBlock, deterministic);
      const jr = await provider.judge({ id: fx.id }, { system: JUDGE_SYSTEM, messages: [{ role: 'user', content: payload }], maxTokens: 900 });
      if (jr.missing) {
        rec.status = 'missing-judge';
        rec.note = `No capture at captures/${fx.id}.judge.json.`;
        // still keep deterministic-only partial
        records.push(rec);
        process.stderr.write(`  [${i}/${fixtures.length}] ${fx.id}: reply OK, MISSING judge\n`);
        continue;
      }
      let judge;
      try {
        judge = parseJudge(jr.text);
      } catch (e) {
        rec.status = 'judge-parse-error';
        rec.note = String(e.message);
        rec.judgeRaw = jr.text.slice(0, 400);
        records.push(rec);
        process.stderr.write(`  [${i}/${fixtures.length}] ${fx.id}: judge parse error\n`);
        continue;
      }
      rec.judge = judge;

      // 4. combine
      rec.score = combineScore(deterministic, judge);
      rec.status = 'scored';
      process.stderr.write(`  [${i}/${fixtures.length}] ${fx.id}: ${rec.score.final}/100 (IQ${judge.dims.diagnosticIQ.score} EQ${judge.dims.eqAttunement.score} M${judge.dims.personalMemory.score})${rec.score.capsTriggered.length ? ' CAP:' + rec.score.capsTriggered.map((c) => c.key).join(',') : ''}\n`);
    } catch (e) {
      rec.status = 'error';
      rec.note = String(e.message);
      process.stderr.write(`  [${i}/${fixtures.length}] ${fx.id}: ERROR ${e.message}\n`);
    }
    records.push(rec);
  }

  meta.finishedAt = new Date().toISOString();
  const run = { runId, meta, records };
  const { summary } = writeReports(run, REPORTS);
  console.error('\n==== SUMMARY ====');
  console.error(JSON.stringify(summary.thresholds, null, 2));
  console.error(`mean=${summary.mean} scored=${summary.scored}/${summary.n} leaks=${summary.placeholderLeaks}`);
  console.error(`Reports: reports/latest.md, reports/failures.md, reports/latest.json`);
}

function publicFixture(fx) {
  return {
    id: fx.id,
    category: fx.category,
    turnDepth: fx.turnDepth,
    voice: fx.voice || null,
    goal: fx.goal,
    userTurn: fx.userTurn,
    emotionalSignal: fx.emotionalSignal || null,
    expectedCoachMove: fx.expectedCoachMove,
    badAnswerExample: fx.badAnswerExample,
    excellentAnswerExample: fx.excellentAnswerExample,
    disqualifiers: fx.disqualifiers || [],
    file: fx._file,
  };
}

async function cmdReport() {
  const p = join(REPORTS, 'latest.json');
  if (!existsSync(p)) throw new Error('no reports/latest.json to re-render');
  const run = JSON.parse(readFileSync(p, 'utf8'));
  writeReports(run, REPORTS);
  console.error('Re-rendered reports from latest.json');
}

const cmd = process.argv[2] || 'run';
const map = { plan: cmdPlan, run: cmdRun, report: cmdReport };
if (!map[cmd]) {
  console.error(`Usage: replay.mjs <plan|run|report>`);
  process.exit(1);
}
map[cmd]().catch((e) => {
  console.error(e.stack || e.message);
  process.exit(1);
});
