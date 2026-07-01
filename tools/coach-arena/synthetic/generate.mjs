#!/usr/bin/env node
// Emits the 10 synthetic multi-turn conversations from synthetic/conversations.data.mjs
// into synthetic/conversations/*.json, and sanity-checks that each expands into
// at least one gradeable turn with the required fields. These conversations
// stress the coach across turns: memory, consistency, not-repeating, trust
// repair mid-arc, transfer reports.
//
// Include them in a run with: ARENA_INCLUDE_SYNTHETIC=1 node runners/replay.mjs run

import { writeFileSync, mkdirSync, readdirSync, rmSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { conversations } from './conversations.data.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT = join(__dirname, 'conversations');

function expandCount(conv) {
  // mirror runner.expandConversation's grading rule: user turns with an
  // expectedCoachMove are graded.
  return (conv.turns || []).filter((t) => t.role === 'user' && t.expectedCoachMove).length;
}

function main() {
  if (existsSync(OUT)) {
    for (const f of readdirSync(OUT).filter((x) => x.endsWith('.json'))) rmSync(join(OUT, f));
  }
  mkdirSync(OUT, { recursive: true });

  let gradable = 0;
  const errs = [];
  for (const conv of conversations) {
    if (!conv.id) errs.push('conversation missing id');
    const g = expandCount(conv);
    gradable += g;
    if (g === 0) errs.push(`${conv.id}: no graded turns (need >=1 user turn with expectedCoachMove)`);
    for (const t of conv.turns || []) {
      if (t.role === 'user' && t.expectedCoachMove) {
        for (const req of ['badAnswerExample', 'excellentAnswerExample']) {
          if (!t[req]) errs.push(`${conv.id}: graded turn "${(t.text || '').slice(0, 30)}" missing ${req}`);
        }
      }
    }
    writeFileSync(join(OUT, `${conv.id}.json`), JSON.stringify(conv, null, 2));
  }

  console.log(`Wrote ${conversations.length} conversations -> ${OUT}`);
  console.log(`Total gradeable turns: ${gradable}`);
  if (errs.length) {
    console.error('\nISSUES:');
    for (const e of errs) console.error('  ' + e);
    process.exit(1);
  }
  console.log('All conversations expand into gradeable turns. ✅');
}

main();
