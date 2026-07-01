#!/usr/bin/env node
// Prepares the judging batch: for every fixture that has a reply capture, runs
// the deterministic checks and writes the full judge payload (fixture + reply +
// contextBlock + deterministic findings) to a per-fixture file. Judge agents
// then read judges/rubric-judge.md once + their payloads and write
// captures/<id>.judge.json.
//
// Usage: node runners/prepare-judge.mjs [numBatches]   (default 6)

import { writeFileSync, mkdirSync, existsSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { renderContext } from '../lib/context.mjs';
import { runChecks } from '../lib/checks.mjs';
import { buildJudgeUserPayload } from '../lib/judge.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const CAPTURES = process.env.ARENA_CAPTURES || join(ROOT, 'runners', 'captures');
const PREP = join(ROOT, 'runs', 'prepare-judge');

function loadFixtures() {
  const dirs = [join(ROOT, 'fixtures', 'gold')];
  if (process.env.ARENA_INCLUDE_SYNTHETIC !== '0') dirs.push(join(ROOT, 'synthetic', 'conversations'));
  const fixtures = [];
  for (const dir of dirs) {
    if (!existsSync(dir)) continue;
    for (const f of readdirSync(dir).filter((x) => x.endsWith('.json')).sort()) {
      const fx = JSON.parse(readFileSync(join(dir, f), 'utf8'));
      const items = Array.isArray(fx) ? fx : fx.turns ? expand(fx) : [fx];
      fixtures.push(...items);
    }
  }
  return fixtures;
}
function expand(conv) {
  const out = [];
  const history = [];
  for (let i = 0; i < conv.turns.length; i++) {
    const t = conv.turns[i];
    if (t.role !== 'user') { history.push({ role: t.role, text: t.text }); continue; }
    if (t.expectedCoachMove) {
      out.push({ id: `${conv.id}__t${i}`, category: conv.category || 'synthetic-conversation', turnDepth: t.turnDepth || 'groundedRead', voice: conv.voice || null, goal: conv.goal, priorChatTurns: history.slice(), userTurn: t.text, emotionalSignal: t.emotionalSignal || null, memoryState: t.memoryState || conv.memoryState || {}, expectedCoachMove: t.expectedCoachMove, badAnswerExample: t.badAnswerExample || '', excellentAnswerExample: t.excellentAnswerExample || '', disqualifiers: t.disqualifiers || [] });
    }
    history.push({ role: 'user', text: t.text });
    if (t.assistantPlaceholder) history.push({ role: 'assistant', text: t.assistantPlaceholder });
  }
  return out;
}

function main() {
  const numBatches = parseInt(process.argv[2] || '6', 10);
  const fixtures = loadFixtures();

  if (existsSync(PREP)) rmSync(PREP, { recursive: true });
  mkdirSync(join(PREP, 'payloads'), { recursive: true });
  mkdirSync(join(PREP, 'batches'), { recursive: true });

  const ready = [];
  const missing = [];
  for (const fx of fixtures) {
    const replyPath = join(CAPTURES, `${fx.id}.reply.txt`);
    if (!existsSync(replyPath)) { missing.push(fx.id); continue; }
    const reply = readFileSync(replyPath, 'utf8').trim();
    const contextBlock = renderContext(fx);
    const recentReplies = (fx.priorChatTurns || []).filter((t) => t.role === 'assistant').map((t) => t.text);
    const deterministic = runChecks(reply, fx, { contextBlock, recentReplies });
    const payload = buildJudgeUserPayload(fx, reply, contextBlock, deterministic);
    writeFileSync(join(PREP, 'payloads', `${fx.id}.json`), payload);
    ready.push(fx.id);
  }

  const chunkSize = Math.ceil(ready.length / numBatches) || 1;
  const batches = Array.from({ length: numBatches }, (_, k) => ready.slice(k * chunkSize, (k + 1) * chunkSize)).filter((b) => b.length);
  batches.forEach((ids, k) => writeFileSync(join(PREP, 'batches', `batch-${k}.json`), JSON.stringify({ batch: k, ids }, null, 2)));

  console.log(`Judge payloads ready: ${ready.length}, missing reply: ${missing.length}, batches: ${batches.length} -> ${PREP}`);
  if (missing.length) console.log(`Missing replies: ${missing.join(', ')}`);
}
main();
