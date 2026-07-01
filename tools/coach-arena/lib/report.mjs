// Renders reports/latest.json, reports/latest.md, reports/failures.md and keeps
// a run history for run-over-run comparison.

import { writeFileSync, readFileSync, existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const THRESH = {
  goldSuiteMean: 70,
  deepAssessmentMean: 70,
  trustRepairMean: 65,
  maxPlaceholderLeaks: 0,
};

function mean(xs) {
  return xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0;
}
function round1(x) {
  return Math.round(x * 10) / 10;
}

export function summarize(records) {
  const scored = records.filter((r) => r.status === 'scored');
  const all = scored.map((r) => r.score.final);
  const byGroup = (pred) => scored.filter(pred).map((r) => r.score.final);

  const groups = {};
  for (const r of scored) {
    const g = r.fixture.category || 'uncategorized';
    (groups[g] = groups[g] || []).push(r.score.final);
  }

  const capCounts = {};
  for (const r of scored) {
    for (const c of r.score.capsTriggered) capCounts[c.key] = (capCounts[c.key] || 0) + 1;
  }

  const placeholderLeaks = scored.reduce((s, r) => s + (r.score.placeholderLeaks || 0), 0);

  return {
    n: records.length,
    scored: scored.length,
    missing: records.filter((r) => r.status !== 'scored').length,
    mean: round1(mean(all)),
    median: all.length ? all.slice().sort((a, b) => a - b)[Math.floor(all.length / 2)] : 0,
    min: all.length ? Math.min(...all) : 0,
    max: all.length ? Math.max(...all) : 0,
    deepAssessmentMean: round1(mean(byGroup((r) => r.fixture.turnDepth === 'deepAssessment'))),
    trustRepairMean: round1(mean(byGroup((r) => r.fixture.turnDepth === 'trustRepair'))),
    byCategory: Object.fromEntries(Object.entries(groups).map(([k, v]) => [k, { n: v.length, mean: round1(mean(v)) }])),
    capCounts,
    placeholderLeaks,
    dimensionMeans: dimensionMeans(scored),
    thresholds: evalThresholds({ mean: mean(all), deep: mean(byGroup((r) => r.fixture.turnDepth === 'deepAssessment')), trust: mean(byGroup((r) => r.fixture.turnDepth === 'trustRepair')), placeholderLeaks }),
  };
}

function dimensionMeans(scored) {
  const keys = ['diagnosticIQ', 'eqAttunement', 'personalMemory', 'interventionQuality', 'dialogueFeel'];
  const out = {};
  for (const k of keys) {
    const vals = scored.map((r) => r.judge?.dims?.[k]?.score).filter((v) => v != null);
    out[k] = round1(mean(vals));
  }
  return out;
}

function evalThresholds({ mean: m, deep, trust, placeholderLeaks }) {
  return {
    goldSuiteMean: { value: round1(m), target: THRESH.goldSuiteMean, pass: m >= THRESH.goldSuiteMean },
    deepAssessmentMean: { value: round1(deep), target: THRESH.deepAssessmentMean, pass: !Number.isFinite(deep) || deep >= THRESH.deepAssessmentMean },
    trustRepairMean: { value: round1(trust), target: THRESH.trustRepairMean, pass: !Number.isFinite(trust) || trust >= THRESH.trustRepairMean },
    zeroPlaceholderLeaks: { value: placeholderLeaks, target: THRESH.maxPlaceholderLeaks, pass: placeholderLeaks <= THRESH.maxPlaceholderLeaks },
  };
}

function loadPrevious(reportsDir) {
  const p = join(reportsDir, 'latest.json');
  if (!existsSync(p)) return null;
  try {
    return JSON.parse(readFileSync(p, 'utf8'));
  } catch {
    return null;
  }
}

export function writeReports(run, reportsDir) {
  mkdirSync(reportsDir, { recursive: true });
  mkdirSync(join(reportsDir, 'history'), { recursive: true });
  const previous = loadPrevious(reportsDir);
  const summary = summarize(run.records);
  run.summary = summary;
  if (previous && previous.runId !== run.runId) run.previous = { runId: previous.runId, summary: previous.summary };

  writeFileSync(join(reportsDir, 'latest.json'), JSON.stringify(run, null, 2));
  writeFileSync(join(reportsDir, 'history', `${run.runId}.json`), JSON.stringify(run, null, 2));
  writeFileSync(join(reportsDir, 'latest.md'), renderMarkdown(run, previous));
  writeFileSync(join(reportsDir, 'failures.md'), renderFailures(run));
  return { summary };
}

function delta(cur, prev) {
  if (prev == null) return '';
  const d = round1(cur - prev);
  if (d === 0) return ' (±0)';
  return d > 0 ? ` (▲ +${d})` : ` (▼ ${d})`;
}

function renderMarkdown(run, previous) {
  const s = run.summary;
  const p = previous?.summary;
  const L = [];
  L.push(`# Coach Arena — ${run.runId}`);
  L.push('');
  L.push(`Provider: \`${run.meta.provider}\` · coach model: \`${run.meta.coachModel}\` · judge model: \`${run.meta.judgeModel}\``);
  L.push(`Git: \`${run.meta.git.shortCommit}\` on \`${run.meta.git.branch}\`${run.meta.git.dirty ? ` (+${run.meta.git.dirty} dirty)` : ''} · prompt: ${run.meta.promptProvenance.map((f) => `${f.path.split('/').pop()}@${f.sha256}`).join(', ')}`);
  L.push('');
  L.push(`## Headline`);
  L.push('');
  L.push(`| Metric | Value | Target | Pass |`);
  L.push(`|---|---|---|---|`);
  const t = s.thresholds;
  L.push(`| Gold-suite mean | **${s.mean}**${delta(s.mean, p?.mean)} | ${t.goldSuiteMean.target} | ${t.goldSuiteMean.pass ? '✅' : '❌'} |`);
  L.push(`| Deep-assessment mean | ${s.deepAssessmentMean}${delta(s.deepAssessmentMean, p?.deepAssessmentMean)} | ${t.deepAssessmentMean.target} | ${t.deepAssessmentMean.pass ? '✅' : '❌'} |`);
  L.push(`| Trust-repair mean | ${s.trustRepairMean}${delta(s.trustRepairMean, p?.trustRepairMean)} | ${t.trustRepairMean.target} | ${t.trustRepairMean.pass ? '✅' : '❌'} |`);
  L.push(`| Placeholder leaks | ${s.placeholderLeaks} | ${t.zeroPlaceholderLeaks.target} | ${t.zeroPlaceholderLeaks.pass ? '✅' : '❌'} |`);
  L.push('');
  L.push(`Scored ${s.scored}/${s.n} fixtures · range ${s.min}–${s.max} · median ${s.median}.${s.missing ? ` ${s.missing} missing capture(s).` : ''}`);
  L.push('');
  L.push(`## Dimension means (of max)`);
  L.push('');
  L.push(`| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |`);
  L.push(`|---|---|---|---|---|`);
  const d = s.dimensionMeans;
  L.push(`| ${d.diagnosticIQ} | ${d.eqAttunement} | ${d.personalMemory} | ${d.interventionQuality} | ${d.dialogueFeel} |`);
  L.push('');
  L.push(`## By category`);
  L.push('');
  L.push(`| Category | n | Mean |${p ? ' Δ |' : ''}`);
  L.push(`|---|---|---|${p ? '---|' : ''}`);
  for (const [k, v] of Object.entries(s.byCategory).sort((a, b) => a[1].mean - b[1].mean)) {
    const pv = p?.byCategory?.[k]?.mean;
    L.push(`| ${k} | ${v.n} | ${v.mean} |${p ? ` ${pv != null ? delta(v.mean, pv).trim() || '±0' : '—'} |` : ''}`);
  }
  L.push('');
  if (Object.keys(s.capCounts).length) {
    L.push(`## Reliability caps triggered`);
    L.push('');
    for (const [k, n] of Object.entries(s.capCounts)) L.push(`- \`${k}\`: ${n}`);
    L.push('');
  }
  L.push(`## Worst 10`);
  L.push('');
  const worst = run.records.filter((r) => r.status === 'scored').sort((a, b) => a.score.final - b.score.final).slice(0, 10);
  L.push(`| Score | Fixture | Turn | closerTo | Top issue |`);
  L.push(`|---|---|---|---|---|`);
  for (const r of worst) {
    const issue = r.deterministic.findings[0]?.id || r.judge?.failureReasons?.[0] || '—';
    L.push(`| **${r.score.final}** | ${r.fixture.id} | ${r.fixture.turnDepth} | ${r.score.closerTo || '—'} | ${String(issue).slice(0, 40)} |`);
  }
  L.push('');
  L.push(`See \`failures.md\` for full replies + judge reasoning. Raw: \`latest.json\`.`);
  return L.join('\n') + '\n';
}

function renderFailures(run) {
  const L = [];
  L.push(`# Coach Arena failures — ${run.runId}`);
  L.push('');
  const fails = run.records
    .filter((r) => r.status !== 'scored' || r.score.final < 70 || r.score.capsTriggered.length || r.score.placeholderLeaks)
    .sort((a, b) => (a.score?.final ?? -1) - (b.score?.final ?? -1));
  if (!fails.length) {
    L.push('No failures below threshold. 🎯');
    return L.join('\n') + '\n';
  }
  L.push(`${fails.length} fixture(s) below 70 / capped / missing.`);
  L.push('');
  for (const r of fails) {
    L.push(`## ${r.fixture.id} — ${r.status === 'scored' ? `**${r.score.final}/100**` : `\`${r.status}\``}`);
    L.push('');
    L.push(`- Category: \`${r.fixture.category}\` · turn: \`${r.fixture.turnDepth}\` · voice: \`${r.fixture.voice || 'none'}\``);
    L.push(`- User turn: ${JSON.stringify(r.fixture.userTurn)}`);
    L.push(`- Expected move: ${r.fixture.expectedCoachMove}`);
    if (r.status === 'scored') {
      const d = r.judge?.dims || {};
      L.push(`- Judge dims: IQ ${d.diagnosticIQ?.score}/25 · EQ ${d.eqAttunement?.score}/25 · Mem ${d.personalMemory?.score}/20 · Interv ${d.interventionQuality?.score}/15 · Feel ${d.dialogueFeel?.score}/15 · closerTo=${r.score.closerTo}`);
      if (r.score.capsTriggered.length) L.push(`- **Caps:** ${r.score.capsTriggered.map((c) => `${c.key}(≤${c.max}, ${c.sources.join('+')})`).join(', ')}`);
      if (r.deterministic.findings.length) L.push(`- Deterministic: ${r.deterministic.findings.map((f) => `${f.id}${f.evidence ? `("${f.evidence}")` : ''}`).join('; ')}`);
      if (r.judge?.failureReasons?.length) L.push(`- Judge: ${r.judge.failureReasons.join('; ')}`);
      if (r.judge?.suggestedFix) L.push(`- Suggested fix: ${r.judge.suggestedFix}`);
      L.push('');
      L.push('```');
      L.push('REPLY:');
      L.push(r.reply || '(empty)');
      L.push('```');
    } else {
      L.push(`- ${r.note || 'missing capture'}`);
    }
    L.push('');
  }
  return L.join('\n') + '\n';
}

export { THRESH };
