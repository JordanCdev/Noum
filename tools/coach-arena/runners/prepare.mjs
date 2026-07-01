#!/usr/bin/env node
// Prepares a generation batch: writes the shared coach system prompt once per
// voice (large, read once by an agent) and a SMALL per-fixture request (voice +
// context block + messages). Generation agents then read one voice prompt +
// their small reqs and write captures/<id>.reply.txt. This keeps each agent
// well within context budget vs. re-reading a 24k system prompt per fixture.
//
// Usage: node runners/prepare.mjs [numBatches]   (default 6)

import { writeFileSync, mkdirSync, existsSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { composeSystemPrompt, extractAll, VOICES } from '../lib/extractPrompt.mjs';
import { renderContext } from '../lib/context.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const PREP = join(ROOT, 'runs', 'prepare');

const MAX_TOKENS = { greeting: 300, preference: 300, offTopic: 300, groundedRead: 500, trustRepair: 700, deepAssessment: 900, plan: 1100 };

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
      out.push({ id: `${conv.id}__t${i}`, turnDepth: t.turnDepth || 'groundedRead', voice: conv.voice || null, priorChatTurns: history.slice(), userTurn: t.text, memoryState: t.memoryState || conv.memoryState || {} });
    }
    history.push({ role: 'user', text: t.text });
    if (t.assistantPlaceholder) history.push({ role: 'assistant', text: t.assistantPlaceholder });
  }
  return out;
}

function main() {
  const numBatches = parseInt(process.argv[2] || '6', 10);
  const extracted = extractAll();
  const fixtures = loadFixtures();

  if (existsSync(PREP)) rmSync(PREP, { recursive: true });
  mkdirSync(join(PREP, 'prompts'), { recursive: true });
  mkdirSync(join(PREP, 'req'), { recursive: true });
  mkdirSync(join(PREP, 'batches'), { recursive: true });

  // Shared system prompt per voice actually used.
  const usedVoices = new Set(fixtures.map((f) => f.voice || 'default'));
  for (const v of usedVoices) {
    const voice = v === 'default' ? null : v;
    writeFileSync(join(PREP, 'prompts', `${v}.txt`), composeSystemPrompt(voice, {}, extracted));
  }

  // Per-fixture small request.
  for (const fx of fixtures) {
    const contextBlock = renderContext(fx);
    const messages = [];
    for (const t of fx.priorChatTurns || []) messages.push({ role: t.role === 'assistant' ? 'assistant' : 'user', content: t.text });
    messages.push({ role: 'user', content: fx.userTurn });
    writeFileSync(join(PREP, 'req', `${fx.id}.json`), JSON.stringify({ id: fx.id, voice: fx.voice || 'default', turnDepth: fx.turnDepth, maxTokens: MAX_TOKENS[fx.turnDepth] || 500, contextBlock, messages }, null, 2));
  }

  // Batches: sort by voice then chunk CONTIGUOUSLY so each batch spans only
  // 1-2 voices (an agent reads at most a couple of 24k prompt files).
  const sorted = fixtures.slice().sort((a, b) => String(a.voice || 'default').localeCompare(String(b.voice || 'default')));
  const chunkSize = Math.ceil(sorted.length / numBatches);
  const batches = Array.from({ length: numBatches }, (_, k) => sorted.slice(k * chunkSize, (k + 1) * chunkSize).map((f) => f.id)).filter((b) => b.length);
  batches.forEach((ids, k) => {
    const voices = [...new Set(ids.map((id) => JSON.parse(readFileSync(join(PREP, 'req', `${id}.json`), 'utf8')).voice))];
    writeFileSync(join(PREP, 'batches', `batch-${k}.json`), JSON.stringify({ batch: k, ids, voices }, null, 2));
  });

  console.log(`Prepared ${fixtures.length} fixtures, ${usedVoices.size} voice prompts, ${numBatches} batches -> ${PREP}`);
  console.log(`Voices: ${[...usedVoices].join(', ')}`);
  batches.forEach((ids, k) => console.log(`  batch-${k}: ${ids.length} fixtures, voices=${[...new Set(ids.map((id) => JSON.parse(readFileSync(join(PREP, 'req', `${id}.json`), 'utf8')).voice))].join('/')}`));
}
main();
