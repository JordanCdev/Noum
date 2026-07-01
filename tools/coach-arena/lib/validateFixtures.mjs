// Validates every gold fixture: required fields, enum values, and that the
// `excellentAnswerExample` itself passes the deterministic checks (a gold
// answer that trips our own leak/robotic detectors is a broken fixture), while
// the `badAnswerExample` does NOT pass cleanly (a "bad" example that our checks
// love means the fixture isn't discriminating).

import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { runChecks } from './checks.mjs';
import { renderContext } from './context.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const GOLD = join(__dirname, '..', 'fixtures', 'gold');

const TURN_DEPTHS = ['greeting', 'preference', 'offTopic', 'groundedRead', 'trustRepair', 'deepAssessment', 'plan'];
const VOICES = ['authoritative', 'warm', 'concise', 'persuasive', 'executive', 'storytelling', null];
const REQUIRED = ['id', 'category', 'turnDepth', 'userTurn', 'goal', 'expectedCoachMove', 'badAnswerExample', 'excellentAnswerExample'];

function validateOne(fx, file) {
  const errs = [];
  const warns = [];
  for (const f of REQUIRED) if (fx[f] === undefined || fx[f] === '') errs.push(`missing required: ${f}`);
  if (!TURN_DEPTHS.includes(fx.turnDepth)) errs.push(`bad turnDepth: ${fx.turnDepth}`);
  if (fx.voice !== undefined && !VOICES.includes(fx.voice)) errs.push(`bad voice: ${fx.voice}`);
  if (fx.id && !/^[a-z0-9-]+$/.test(fx.id)) errs.push(`id not kebab-case: ${fx.id}`);

  const ctx = renderContext(fx);
  // Gold "excellent" must pass our own checks (no hard cap, no leaks).
  if (fx.excellentAnswerExample) {
    const r = runChecks(fx.excellentAnswerExample, fx, { contextBlock: ctx });
    if (r.hardCap !== null) errs.push(`excellentAnswerExample trips a hard cap: ${r.caps.map((c) => c.id).join(',')}`);
    if (r.placeholderLeaks) errs.push(`excellentAnswerExample leaks placeholder/metadata`);
    if (r.flagPenalty >= 12) warns.push(`excellentAnswerExample has flags: ${r.flags.map((f) => f.id).join(',')}`);
  }
  // Bad example should be caught by SOMETHING (checks or by design the judge);
  // warn if our deterministic checks find it totally clean (weak discriminator).
  if (fx.badAnswerExample) {
    const r = runChecks(fx.badAnswerExample, fx, { contextBlock: ctx });
    if (r.hardCap === null && r.flagPenalty === 0 && !(fx.disqualifiers || []).length) {
      warns.push(`badAnswerExample passes checks cleanly and no disqualifiers — relies entirely on judge`);
    }
  }
  if (!(fx.disqualifiers || []).length) warns.push('no disqualifiers');
  return { file, id: fx.id, errs, warns };
}

export function validateAll() {
  const files = readdirSync(GOLD).filter((f) => f.endsWith('.json')).sort();
  const results = [];
  const ids = new Set();
  for (const f of files) {
    let fx;
    try {
      fx = JSON.parse(readFileSync(join(GOLD, f), 'utf8'));
    } catch (e) {
      results.push({ file: f, id: '?', errs: ['invalid JSON: ' + e.message], warns: [] });
      continue;
    }
    if (ids.has(fx.id)) results.push({ file: f, id: fx.id, errs: ['duplicate id'], warns: [] });
    ids.add(fx.id);
    results.push(validateOne(fx, f));
  }
  return results;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const results = validateAll();
  let errs = 0;
  let warns = 0;
  for (const r of results) {
    for (const e of r.errs) {
      console.log(`ERROR ${r.file} [${r.id}]: ${e}`);
      errs++;
    }
    for (const w of r.warns) {
      console.log(`warn  ${r.file} [${r.id}]: ${w}`);
      warns++;
    }
  }
  console.log(`\n${results.length} fixtures · ${errs} errors · ${warns} warnings`);
  process.exit(errs ? 1 : 0);
}
