// Renders reports/latest.json, reports/latest.md, reports/failures.md and keeps
// a run history for run-over-run comparison.

import { writeFileSync, readFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';

const THRESH = {
  goldSuiteMean: 70,
  deepAssessmentMean: 70,
  trustRepairMean: 65,
  maxMissingReplies: 0,
  fixtureScoreFloor: 60,
  maxSub70Fixtures: 0,
  maxPlaceholderLeaks: 0,
};

function mean(xs) {
  return xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0;
}
function round1(x) {
  return Math.round(x * 10) / 10;
}

// Deterministic findings that are mirrored by the shipping live quality gate,
// final reliability gate, or repair path. This audit is intentionally phrased as
// "likely" because replay cannot execute the full Swift repair loop.
const LIVE_GATE_BACKED_CAP_FINDING_IDS = new Set([
  'bareClarification',
  'brokenReply',
  'coldStartFakeCalibration',
  'coldStartMetricTarget',
  'coldStartProductJargon',
  'coldStartUncalibratedMetricTarget',
  'coldStartVagueBaselineRep',
  'defensiveProductLanguage',
  'fabricatedMetric',
  'fabricatedQuote',
  'fakeScore',
  'goalIntentStateDirective',
  'menuInsteadOfDecision',
  'metadataLeak',
  'personLabelVerdict',
  'placeholderLeak',
  'punishShame',
  'repeatedProofTest',
  'roboticPhrase',
  'scaffoldLabel',
  'scaffoldStructuralLabel',
  'scoreAsReadiness',
  'sensitiveTurnReportVoice',
  'sensitiveTurnReportVoiceCap',
  'tooLong',
  'trailingSetupQuestion',
  'trustRepairReportVoice',
  'trustRepairReportVoiceCap',
]);

function deterministicCapFindings(deterministic) {
  return (deterministic.findings || []).filter((finding) => finding.tier === 'cap' || finding.capKey);
}

function liveQualityGateBacksFinding(finding) {
  return LIVE_GATE_BACKED_CAP_FINDING_IDS.has(finding.id);
}

// Prompt-caching / cost accounting — COST/LATENCY evidence only, never a
// quality signal. Reads whatever `usage` the provider call captured on
// `record.trace.usage` (Anthropic: cache_creation_input_tokens /
// cache_read_input_tokens; Gemini: cachedContentTokenCount). Records without
// a `trace.usage` (replay/cli providers, or a fixture that errored before
// generation) are silently excluded from the denominator rather than
// counted as cache misses — there's no usage data to judge either way.
function cacheSummary(records) {
  let requestsWithUsage = 0;
  let cacheHits = 0;
  let cacheReadTokens = 0;
  let cacheCreationTokens = 0;
  let cachedContentTokens = 0;
  let inputTokens = 0;
  let outputTokens = 0;

  for (const r of records) {
    const usage = r.trace?.usage;
    if (!usage) continue;
    requestsWithUsage++;
    const read = usage.cache_read_input_tokens || 0;
    const created = usage.cache_creation_input_tokens || 0;
    const cachedContent = usage.cachedContentTokenCount || 0;
    cacheReadTokens += read;
    cacheCreationTokens += created;
    cachedContentTokens += cachedContent;
    inputTokens += usage.input_tokens || usage.promptTokenCount || 0;
    outputTokens += usage.output_tokens || usage.candidatesTokenCount || 0;
    if (read > 0 || cachedContent > 0) cacheHits++;
  }

  if (requestsWithUsage === 0) {
    return {
      requestsWithUsage: 0,
      cacheHits: 0,
      cacheHitRate: null,
      cacheReadTokens: 0,
      cacheCreationTokens: 0,
      cachedContentTokens: 0,
      inputTokens: 0,
      outputTokens: 0,
      estimatedTokensSaved: 0,
    };
  }

  return {
    requestsWithUsage,
    cacheHits,
    cacheHitRate: round1((cacheHits / requestsWithUsage) * 100),
    cacheReadTokens,
    cacheCreationTokens,
    cachedContentTokens,
    inputTokens,
    outputTokens,
    // Cache reads bill at a fraction of a fresh input token (provider
    // pricing, not modeled here) — this is the raw token count that avoided
    // full-price re-processing, not a dollar or latency claim.
    estimatedTokensSaved: cacheReadTokens + cachedContentTokens,
  };
}

function userVisibleDeterministicSummary(records) {
  const checked = records.filter((r) => r.status === 'scored' && (r.userVisible?.deterministic || r.deterministic));
  if (!checked.length) {
    return {
      repliesChecked: 0,
      changedFromScoredReply: 0,
      cappedReplies: 0,
      gateBackedCappedReplies: 0,
      unbackedCappedReplies: 0,
      unbackedCappedFixtureIDs: [],
      placeholderLeaks: 0,
      capCounts: {},
      gateBackedCapCounts: {},
      unbackedCapCounts: {},
      findingCounts: {},
    };
  }

  const capCounts = {};
  const gateBackedCapCounts = {};
  const unbackedCapCounts = {};
  const findingCounts = {};
  const unbackedCappedFixtureIDs = [];
  let cappedReplies = 0;
  let gateBackedCappedReplies = 0;
  let unbackedCappedReplies = 0;
  let placeholderLeaks = 0;
  let changedFromScoredReply = 0;
  for (const r of checked) {
    const deterministic = r.userVisible?.deterministic || r.deterministic;
    if (r.userVisible?.changedFromScoredReply) changedFromScoredReply++;
    const capFindings = deterministicCapFindings(deterministic);
    if (deterministic.hardCap != null) {
      cappedReplies++;
      const unbacked = capFindings.filter((finding) => !liveQualityGateBacksFinding(finding));
      if (capFindings.length && unbacked.length === 0) {
        gateBackedCappedReplies++;
      } else {
        unbackedCappedReplies++;
        unbackedCappedFixtureIDs.push(r.fixture?.id || r.id || 'unknown');
      }
      for (const finding of capFindings) {
        const counts = liveQualityGateBacksFinding(finding) ? gateBackedCapCounts : unbackedCapCounts;
        const key = finding.capKey || finding.id || 'unknown';
        counts[key] = (counts[key] || 0) + 1;
      }
    }
    placeholderLeaks += deterministic.placeholderLeaks || 0;
    for (const finding of deterministic.findings || []) {
      findingCounts[finding.id] = (findingCounts[finding.id] || 0) + 1;
      if (finding.tier === 'cap' && finding.capKey) {
        capCounts[finding.capKey] = (capCounts[finding.capKey] || 0) + 1;
      }
    }
  }

  return {
    repliesChecked: checked.length,
    changedFromScoredReply,
    cappedReplies,
    gateBackedCappedReplies,
    unbackedCappedReplies,
    unbackedCappedFixtureIDs,
    placeholderLeaks,
    capCounts,
    gateBackedCapCounts,
    unbackedCapCounts,
    findingCounts,
  };
}

export function summarize(records) {
  const scored = records.filter((r) => r.status === 'scored');
  const all = scored.map((r) => r.score.final);
  const byGroup = (pred) => scored.filter(pred).map((r) => r.score.final);
  const missing = records.filter((r) => r.status !== 'scored').length;
  const min = all.length ? Math.min(...all) : 0;
  const sub70 = scored.filter((r) => r.score.final < 70).length;

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
  const finalizerDeltas = records.filter((r) => r.finalizer?.changed).length;
  const replayJudgeStaleFinalizerDeltas = records.filter(
    (r) => r.finalizer?.scoringMode === 'rawReplayJudge'
  ).length;
  const finalizerChangeCounts = {};
  for (const r of records) {
    for (const change of r.finalizer?.changes || []) {
      finalizerChangeCounts[change] = (finalizerChangeCounts[change] || 0) + 1;
    }
  }
  const thresholds = evalThresholds({
    mean: mean(all),
    deep: mean(byGroup((r) => r.fixture.turnDepth === 'deepAssessment')),
    trust: mean(byGroup((r) => r.fixture.turnDepth === 'trustRepair')),
    missing,
    min,
    sub70,
    placeholderLeaks,
  });

  return {
    n: records.length,
    scored: scored.length,
    missing,
    mean: round1(mean(all)),
    median: all.length ? all.slice().sort((a, b) => a - b)[Math.floor(all.length / 2)] : 0,
    min,
    max: all.length ? Math.max(...all) : 0,
    sub70,
    deepAssessmentMean: round1(mean(byGroup((r) => r.fixture.turnDepth === 'deepAssessment'))),
    trustRepairMean: round1(mean(byGroup((r) => r.fixture.turnDepth === 'trustRepair'))),
    byCategory: Object.fromEntries(Object.entries(groups).map(([k, v]) => [k, { n: v.length, mean: round1(mean(v)) }])),
    capCounts,
    placeholderLeaks,
    dimensionMeans: dimensionMeans(scored),
    thresholds,
    productionReady: Object.values(thresholds).every((t) => t.pass),
    cacheSummary: cacheSummary(records),
    userVisibleDeterministic: userVisibleDeterministicSummary(records),
    finalizerDeltas,
    replayJudgeStaleFinalizerDeltas,
    finalizerChangeCounts,
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

function evalThresholds({ mean: m, deep, trust, missing, min, sub70, placeholderLeaks }) {
  return {
    goldSuiteMean: { value: round1(m), target: THRESH.goldSuiteMean, pass: m >= THRESH.goldSuiteMean },
    deepAssessmentMean: { value: round1(deep), target: THRESH.deepAssessmentMean, pass: !Number.isFinite(deep) || deep >= THRESH.deepAssessmentMean },
    trustRepairMean: { value: round1(trust), target: THRESH.trustRepairMean, pass: !Number.isFinite(trust) || trust >= THRESH.trustRepairMean },
    zeroMissingReplies: { value: missing, target: THRESH.maxMissingReplies, pass: missing <= THRESH.maxMissingReplies },
    fixtureScoreFloor: { value: min, target: THRESH.fixtureScoreFloor, pass: min >= THRESH.fixtureScoreFloor },
    zeroSub70Fixtures: { value: sub70, target: THRESH.maxSub70Fixtures, pass: sub70 <= THRESH.maxSub70Fixtures },
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
  writeFileSync(join(reportsDir, 'latest.md'), renderMarkdown(run, previous, reportsDir));
  writeFileSync(join(reportsDir, 'failures.md'), renderFailures(run));
  return { summary };
}

function delta(cur, prev) {
  if (prev == null) return '';
  const d = round1(cur - prev);
  if (d === 0) return ' (±0)';
  return d > 0 ? ` (▲ +${d})` : ` (▼ ${d})`;
}

function readJsonIfPresent(path) {
  if (!existsSync(path)) return null;
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return null;
  }
}

function latestCanonicalAppPathSnapshot(reportsDir) {
  const appPathReport = readJsonIfPresent(join(reportsDir, 'app-path', 'latest.json'));
  if (!appPathReport?.summary) return null;
  const s = appPathReport.summary;
  return {
    generatedAt: appPathReport.generatedAt || null,
    candidate: appPathReport.candidate || null,
    average: s.average ?? null,
    realPipelineEvidencePasses: s.realPipelineEvidencePasses ?? s.productionEvidencePasses ?? null,
    evidenceClaim: s.evidenceClaim ?? null,
    traceQualityPasses: s.traceQualityPasses ?? null,
    placeholderLeaks: s.placeholderLeaks ?? null,
    failureCount: s.failureCount ?? null,
    visionScore: s.visionProductionReadiness?.score ?? null,
    visionClaim: s.visionProductionReadiness?.claim ?? null,
  };
}

function staleDuplicateAppPathStatus(reportsDir) {
  const arenaRoot = dirname(reportsDir);
  const duplicateLatest = join(arenaRoot, 'tools', 'coach-arena', 'reports', 'app-path', 'latest.json');
  if (!existsSync(duplicateLatest)) return 'resolved (no nested duplicate latest.json found)';
  const duplicate = readJsonIfPresent(duplicateLatest);
  const generated = duplicate?.generatedAt || duplicate?.runId || 'unreadable';
  return `stale duplicate present at tools/coach-arena/tools/coach-arena/reports/app-path/latest.json (generated ${generated}); ignore this path`;
}

function renderReportLens(run, reportsDir) {
  const app = latestCanonicalAppPathSnapshot(reportsDir);
  const L = [];
  L.push('## Report lens and canonical paths');
  L.push('');
  L.push('| Field | Value |');
  L.push('|---|---|');
  L.push('| Current report | prompt-layer / Node prompt-faithful |');
  L.push('| Current report path | `tools/coach-arena/reports/latest.md` |');
  L.push('| Comparable app-path report | `tools/coach-arena/reports/app-path/latest.md` |');
  L.push('| App-path source of truth | canonical `tools/coach-arena/reports/app-path/` only |');
  L.push(`| Nested duplicate app-path path | ${staleDuplicateAppPathStatus(reportsDir)} |`);
  if (app) {
    L.push(`| Latest canonical app-path generated | ${app.generatedAt ? `\`${app.generatedAt}\`` : 'not reported'} |`);
    L.push(`| Latest canonical app-path average | ${app.average == null ? 'not reported' : `\`${app.average}/100\``} |`);
    // Two DISTINCT booleans that used to collide under the bare word "evidence":
    // the freshness-inclusive production GATE (realPipelineEvidencePasses — fails
    // when the app-path dump's source tree is dirty/uncommitted) vs. trace-level
    // quality (traceQualityPasses — are the captured traces real/complete/unique).
    // Render both, labeled, so a false gate on stale source can't be misread as
    // fake traces, and a true trace-quality can't be misread as a passing gate.
    L.push(`| App-path evidence gate (incl. source freshness) | ${app.realPipelineEvidencePasses == null ? 'not reported' : `\`${app.realPipelineEvidencePasses}\` · claim \`${app.evidenceClaim}\``} |`);
    L.push(`| App-path trace-level quality (traces real/complete/unique) | ${app.traceQualityPasses == null ? 'not reported' : `\`${app.traceQualityPasses}\``} |`);
    L.push(`| Latest canonical app-path leaks/failures | leaks \`${app.placeholderLeaks ?? 'not reported'}\` · failures \`${app.failureCount ?? 'not reported'}\` |`);
    L.push(`| Latest canonical app-path VISION boundary | score \`${app.visionScore ?? 'not reported'}\` · claim \`${app.visionClaim ?? 'not reported'}\` |`);
  } else {
    L.push('| Latest canonical app-path snapshot | unavailable; run `./tools/coach-arena/run.sh app-path` with a fresh dump |');
  }
  L.push('');
  return L;
}

function currentAppPathEvidence(run) {
  const s = run.summary || {};
  if (s.traceAudit || s.traceQualityAudit || s.productionEvidencePasses != null || s.traceQualityPasses != null) {
    return {
      status: 'available',
      score: s.appPathScore ?? s.average ?? s.mean ?? null,
      tracePasses: s.productionEvidencePasses ?? s.traceQualityPasses ?? null,
      realPipelineTraceCount: s.traceAudit?.realPipelineTraceCount ?? null,
      completeTraceCount: s.traceAudit?.completeTraceCount ?? null,
      placeholderLeaks: s.placeholderLeaks ?? null,
      fallbackSummary: s.providerFallbackSummary ?? s.fallbackSummary ?? null,
      latencySummary: s.traceQualityAudit?.latency ?? null,
      cacheSummary: s.cacheSummary ?? null,
      source: 'current run'
    };
  }
  return {
    status: 'unavailable',
    source: 'prompt-layer run',
    reason: 'This run used the Node prompt-faithful engine. It does not execute the Swift retrieval, memory, caching, provider fallback, live quality gate, or UI pipeline. Run ./tools/coach-arena/run.sh python with a fresh app-path dump to produce this evidence.'
  };
}

function renderCacheSummary(cache) {
  const L = [];
  L.push('## Prompt-cache usage (this run)');
  L.push('');
  if (!cache || cache.requestsWithUsage === 0) {
    L.push('No usage data on this run (replay/cli provider, or no scored requests).');
    L.push('');
    return L;
  }
  L.push('| Metric | Value |');
  L.push('|---|---|');
  L.push(`| Requests with usage data | ${cache.requestsWithUsage} |`);
  L.push(`| Cache hit rate | ${cache.cacheHitRate}% (${cache.cacheHits}/${cache.requestsWithUsage}) |`);
  L.push(`| Cache read tokens (Anthropic) | ${cache.cacheReadTokens} |`);
  L.push(`| Cache creation tokens (Anthropic) | ${cache.cacheCreationTokens} |`);
  L.push(`| Cached content tokens (Gemini) | ${cache.cachedContentTokens} |`);
  L.push(`| Input tokens | ${cache.inputTokens} |`);
  L.push(`| Output tokens | ${cache.outputTokens} |`);
  L.push(`| Estimated tokens saved by cache | ${cache.estimatedTokensSaved} |`);
  L.push('');
  return L;
}

function renderUserVisibleAudit(summary, provider) {
  const L = [];
  L.push('## Finalized deterministic audit');
  L.push('');
  if (!summary || summary.repliesChecked === 0) {
    L.push('No finalized reply audit data on this run.');
    L.push('');
    return L;
  }
  const note = provider === 'replay'
    ? 'Diagnostic only: replay judge scores remain tied to raw captured replies, and replay cannot execute the live quality-gate repair path.'
    : 'Official score path: generated replies were finalized before deterministic checks and judge scoring.';
  L.push(note);
  L.push('');
  L.push('| Metric | Value |');
  L.push('|---|---|');
  L.push(`| Replies checked | ${summary.repliesChecked} |`);
  L.push(`| Changed from scored reply | ${summary.changedFromScoredReply} |`);
  L.push(`| Replies with deterministic hard caps | ${summary.cappedReplies} |`);
  L.push(`| Likely blocked/repaired by live gate | ${summary.gateBackedCappedReplies ?? 0} |`);
  L.push(`| No production backstop identified | ${summary.unbackedCappedReplies ?? 0} |`);
  L.push(`| Placeholder/fallback leaks after finalizer | ${summary.placeholderLeaks} |`);
  const caps = Object.entries(summary.capCounts || {})
    .map(([key, count]) => `${key} ${count}`)
    .join(', ');
  L.push(`| Cap breakdown | ${caps || 'none'} |`);
  const unbackedIDs = (summary.unbackedCappedFixtureIDs || []).join(', ');
  L.push(`| Unbacked capped fixture IDs | ${unbackedIDs || 'none'} |`);
  L.push('');
  return L;
}

function renderAppPathEvidence(run) {
  const app = currentAppPathEvidence(run);
  const L = [];
  L.push('## App-path evidence');
  L.push('');
  L.push('| Metric | Value |');
  L.push('|---|---|');
  if (app.status === 'available') {
    L.push(`| Status | available (${app.source}) |`);
    L.push(`| App-path score | ${app.score ?? 'not reported'} |`);
    L.push(`| Trace / production audit | ${app.tracePasses == null ? 'not reported' : app.tracePasses ? 'pass' : 'fail'} |`);
    L.push(`| Real pipeline traces | ${app.realPipelineTraceCount ?? 'not reported'} |`);
    L.push(`| Complete traces | ${app.completeTraceCount ?? 'not reported'} |`);
    L.push(`| Placeholder / fallback leaks | ${app.placeholderLeaks ?? 'not reported'} |`);
    L.push(`| Provider fallback summary | ${app.fallbackSummary ?? 'not reported'} |`);
    L.push(`| Latency / TTFT | ${app.latencySummary ? JSON.stringify(app.latencySummary) : 'not reported'} |`);
    L.push(`| Cache hit rate | ${app.cacheSummary ?? 'not reported'} |`);
  } else {
    L.push(`| Status | unavailable (${app.source}) |`);
    L.push(`| App-path score | unavailable |`);
    L.push(`| Why | ${app.reason} |`);
  }
  L.push('');
  return L;
}

function renderMarkdown(run, previous, reportsDir) {
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
  L.push(`| Missing captures | ${s.missing} | ${t.zeroMissingReplies.target} | ${t.zeroMissingReplies.pass ? '✅' : '❌'} |`);
  L.push(`| Fixture score floor | ${s.min} | ${t.fixtureScoreFloor.target} | ${t.fixtureScoreFloor.pass ? '✅' : '❌'} |`);
  L.push(`| Sub-70 fixtures | ${s.sub70} | ${t.zeroSub70Fixtures.target} | ${t.zeroSub70Fixtures.pass ? '✅' : '❌'} |`);
  L.push(`| Placeholder leaks | ${s.placeholderLeaks} | ${t.zeroPlaceholderLeaks.target} | ${t.zeroPlaceholderLeaks.pass ? '✅' : '❌'} |`);
  L.push('');
  L.push(`Scored ${s.scored}/${s.n} fixtures · range ${s.min}–${s.max} · median ${s.median}.${s.missing ? ` ${s.missing} missing capture(s).` : ''}`);
  if (s.finalizerDeltas) {
    const stale = s.replayJudgeStaleFinalizerDeltas
      ? ` ${s.replayJudgeStaleFinalizerDeltas} replay judge(s) remain scored against raw captured text.`
      : '';
    const breakdown = Object.entries(s.finalizerChangeCounts || {})
      .map(([key, count]) => `${key} ${count}`)
      .join(', ');
    L.push(`Finalizer changed ${s.finalizerDeltas} generated repl${s.finalizerDeltas === 1 ? 'y' : 'ies'} before user display${breakdown ? ` (${breakdown})` : ''}.${stale}`);
  }
  L.push('');
  L.push(...renderReportLens(run, reportsDir));
  L.push(...renderCacheSummary(s.cacheSummary));
  L.push(...renderUserVisibleAudit(s.userVisibleDeterministic, run.meta.provider));
  L.push(...renderAppPathEvidence(run));
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
      if (r.finalizer?.changed) {
        L.push('');
        L.push(`- User-visible finalizer delta: ${r.finalizer.changes.join(', ')} · scoring mode \`${r.finalizer.scoringMode}\``);
        L.push('');
        L.push('```');
        L.push('FINALIZED USER TEXT:');
        L.push(r.finalizer.finalizedReply || '(empty)');
        L.push('```');
      }
    } else {
      L.push(`- ${r.note || 'missing capture'}`);
    }
    L.push('');
  }
  return L.join('\n') + '\n';
}

export { THRESH };
