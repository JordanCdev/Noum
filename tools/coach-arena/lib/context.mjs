// Renders a fixture's structured `memoryState` into a CONTEXT block that mirrors
// the section format of Noum's CoachContextBuilder.userContext. The exact
// uppercase section headers match the ones the system prompt's intelligence
// floor references, so the model reads them the same way it does in production.
//
// Sections are emitted ONLY when the fixture supplies data for them — the same
// "omit when absent so the model never invents one" contract the app follows.

function line(label, value) {
  if (value === undefined || value === null || value === '') return null;
  return `${label}: ${value}`;
}

function section(header, lines) {
  const kept = lines.filter(Boolean);
  if (!kept.length) return null;
  return `${header}\n${kept.map((l) => `- ${l}`).join('\n')}`;
}

const VOICE_LABEL = {
  authoritative: 'Authoritative',
  warm: 'Warm and welcoming',
  concise: 'Concise and sharp',
  persuasive: 'Persuasive',
  executive: 'Executive presence',
  storytelling: 'Storytelling',
};

// POSITIONAL TREND readout — a faithful JS port of Swift's
// `RepEventTrend.readout` (Noum/RepEventTrend.swift). The arena is production
// parity, so the harness must compose the EXACT coach-facing sentence the app
// emits from the same typed fields (kind / zone / dominantCount / repsWithSignal
// / windowRepCount) — including the prevalence-suppression rule (omit the base
// rate when the event carried every readable rep, so a 100% tail never reads as
// a redundant "N of N"). A fixture may instead pass a pre-composed string, which
// is used verbatim (mirrors the promptRelevance/structureRead string sections).
const POSITIONAL_TREND_ZONES = new Set(['opening', 'middle', 'close']);
const POSITIONAL_TREND_KINDS = new Set(['rushedBurst', 'longestPause', 'fillerCluster']);

function positionalTrendReadout(trend) {
  if (typeof trend === 'string') return trend.trim() || null;
  if (!trend || typeof trend !== 'object') return null;
  const { kind, zone, dominantCount, repsWithSignal, windowRepCount } = trend;
  if (!POSITIONAL_TREND_KINDS.has(kind) || !POSITIONAL_TREND_ZONES.has(zone)) return null;
  if (![dominantCount, repsWithSignal, windowRepCount].every((n) => Number.isInteger(n) && n > 0)) return null;

  const where = `the ${zone}`;
  const evidence = `in ${dominantCount} of your last ${repsWithSignal} reps`;
  const prevalence = repsWithSignal < windowRepCount
    ? ` It showed up in ${repsWithSignal} of your last ${windowRepCount} reps overall.`
    : '';
  switch (kind) {
    case 'rushedBurst':
      return `You've rushed ${where} ${evidence} that had a fast stretch — the fastest stretch keeps landing there.${prevalence} A recurring position, not a fixed trait.`;
    case 'longestPause':
      return `Your longest silence has fallen in ${where} ${evidence} that had a notable pause.${prevalence} A recurring position, not a fixed trait.`;
    case 'fillerCluster':
      return `Fillers have clustered in ${where} ${evidence} that had a filler cluster.${prevalence} A recurring position, not a fixed trait.`;
    default:
      return null;
  }
}

export function renderContext(fixture) {
  const m = fixture.memoryState || {};
  const blocks = [];

  // GOAL
  if (m.goal || fixture.voice) {
    const g = m.goal || {};
    blocks.push(
      section('GOAL', [
        line('Voice', VOICE_LABEL[fixture.voice || g.voice] || g.voice || 'not set yet'),
        line('Why now', g.whyNow),
        line('Their vision of success', g.visionOfSuccess),
        line('Since', g.since),
      ]),
    );
  }

  if (m.goalIntent) {
    const gi = m.goalIntent;
    blocks.push(
      section('GOAL INTENT', [
        line('Case', gi.case),
        line('From', gi.from),
        line('To', gi.to),
        gi.note,
      ]),
    );
  }

  if (m.bigMoment) {
    const b = m.bigMoment;
    blocks.push(
      section('BIG MOMENT', [
        line('Category', b.category),
        line('Days remaining', b.daysRemaining),
        line('What', b.title),
        line('Rehearsal readiness', b.rehearsalReadiness),
      ]),
    );
  }

  if (m.rating) {
    const r = m.rating;
    blocks.push(
      section('RATING', [
        line('Overall', r.overall),
        line('Week peak', r.weekPeak),
        line('Weekly delta', r.weeklyDelta),
      ]),
    );
  }

  if (m.baseline) {
    const b = m.baseline;
    blocks.push(
      section('BASELINE', [
        line('Fillers per minute', b.fillersPerMin),
        line('Pace (words/min)', b.pace),
        line('Pause rate', b.pauseRate),
        line('Hedging per minute', b.hedgingPerMin),
      ]),
    );
  }

  if (m.streak) {
    blocks.push(
      section('STREAK', [line('Current', m.streak.current), line('Reps this week', m.streak.repsThisWeek)]),
    );
  }

  if (m.coachMemory) {
    const c = m.coachMemory;
    blocks.push(
      section('COACH MEMORY', [
        line('Evidence depth', c.evidenceDepth),
        line('Goal anchor', c.goalAnchor),
        line('Declared intent', c.declaredIntent),
        line('Preserve', c.preserve),
        line('Watch', c.watch),
        ...(c.hypotheses || []).map((h) => `Hypothesis: ${h}`),
      ]),
    );
  }

  if (m.caseFormulation) {
    const c = m.caseFormulation;
    blocks.push(
      section('CASE FORMULATION', [
        line('Hypothesis', c.hypothesis),
        line('Goal fit', c.goalFit),
        line('Stated-vs-measured', c.statedVsMeasured),
        line('Subjective reflection', c.subjectiveReflection),
        line('Transfer', c.transfer),
      ]),
    );
  }

  if (m.interventionCycle) {
    const c = m.interventionCycle;
    blocks.push(
      section('INTERVENTION CYCLE', [
        line('Active intervention', c.intervention),
        line('Observable target', c.target),
        line('Success criterion', c.successCriterion),
        line('Review status', c.reviewStatus),
        line('Cadence', c.cadence),
        line('Course change', c.courseChange),
      ]),
    );
  }

  if (m.activePrescription) blocks.push(section('ACTIVE PRESCRIPTION', [m.activePrescription]));
  if (m.interventionResponse) blocks.push(section('INTERVENTION RESPONSE', [m.interventionResponse]));

  if (m.recentReps && m.recentReps.length) {
    blocks.push(
      'RECENT REPS\n' +
        m.recentReps
          .map((r) => {
            const bits = [r.mode, r.score != null ? `score ${r.score}` : null, r.fillers != null ? `${r.fillers} fillers` : null, r.durationSec != null ? `${r.durationSec}s` : null, r.note]
              .filter(Boolean)
              .join(', ');
            return `- ${r.when || 'recent'}: ${bits}`;
          })
          .join('\n'),
    );
  }

  if (m.trends) {
    blocks.push(section('TRENDS', [line('Strengths', m.trends.strengths), line('Persistent blockers', m.trends.blockers)]));
  }

  if (m.path) blocks.push(section('PATH', [line('Node', m.path.node), line('Landmark', m.path.landmark)]));

  if (m.proofs && m.proofs.length) {
    blocks.push('VERIFIED PROOFS (verbatim quotes the user actually said)\n' + m.proofs.map((p) => `- "${p}"`).join('\n'));
  }

  if (m.realWorldTransfer) blocks.push(section('REAL-WORLD TRANSFER (subjective, user-reported)', [m.realWorldTransfer]));
  if (m.subjectiveReflection) blocks.push(section('SUBJECTIVE REFLECTION (the user\'s own inner read)', [m.subjectiveReflection]));
  if (m.subjectivePattern) blocks.push(section('SUBJECTIVE PATTERN (repeated self-report, a hypothesis)', [m.subjectivePattern]));
  if (m.toneDrillTrajectory) blocks.push(section('TONE-DRILL TRAJECTORY', [m.toneDrillTrajectory]));
  if (m.toneDrillSolved) blocks.push(section('TONE-DRILL SOLVED', [m.toneDrillSolved]));
  if (m.promptRelevance) blocks.push(section('PROMPT RELEVANCE (positional read of the most-recent rep)', [m.promptRelevance]));
  if (m.structureRead) blocks.push(section('STRUCTURE READ (most-recent rep close)', [m.structureRead]));

  // POSITIONAL TREND — the longitudinal companion to PROMPT RELEVANCE's
  // most-recent-rep read. Mirrors `CoachContextBuilder`'s POSITIONAL TREND block
  // (Noum/CoachContextBuilder.swift) so the harness feeds the coach the
  // recurring-position line iters 19-20 shipped. Omitted when absent (same
  // "never invent a section" contract as every block above).
  if (m.positionalTrend) {
    const trends = Array.isArray(m.positionalTrend) ? m.positionalTrend : [m.positionalTrend];
    const readouts = trends.map(positionalTrendReadout).filter(Boolean);
    if (readouts.length) blocks.push(section('POSITIONAL TREND (recurring event position across recent reps)', readouts));
  }

  if (m.coachingExpertise && m.coachingExpertise.length) {
    blocks.push(
      'COACHING EXPERTISE (craft reference — not a reading of the user)\n' +
        m.coachingExpertise
          .map((c) => `- ${c.title}${c.evidence ? ` [${c.evidence}]` : ''}: ${c.body}`)
          .join('\n'),
    );
  }

  if (m.liveCoachingFrame) {
    const f = m.liveCoachingFrame;
    blocks.push(
      section('LIVE COACHING FRAME', [
        line('Need', f.need),
        line('Emotional signal', f.emotionalSignal),
        line('Emotional register', f.emotionalRegister),
        line('Sustained pattern', f.sustainedPattern),
      ]),
    );
  }

  const body = blocks.filter(Boolean).join('\n\n');
  return `CONTEXT\n${body || '- No durable data yet (cold start).'}`;
}
