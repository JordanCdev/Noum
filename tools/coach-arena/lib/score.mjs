// Canonical scoring: combine the LLM judge's dimension scores with the
// deterministic checks. Deterministic caps and judge caps are UNIONED — either
// source can clamp the total. Flags are point deductions.

const CAP_MAX = { placeholderOrBroken: 30, ignoresIntent: 50, fabricatesEvidence: 40, unsafe: 0 };

// deterministic: output of checks.runChecks(); judge: output of judge.parseJudge()
export function combineScore(deterministic, judge) {
  const detCapKeys = new Set(deterministic.caps.map((c) => c.capKey));
  const closerTo = judge?.closerTo || null;
  const rawJudgeCapKeys = Object.entries(judge?.caps || {})
    .filter(([, v]) => v)
    .map(([k]) => k);
  // Self-contradiction guard (live-confirmed defect, 2026-07-06): the judge can
  // hallucinate a cap boolean — am-i-improving got placeholderOrBroken=true on a
  // fully grounded reply the SAME judge called closerTo=excellent, crushing an
  // ~excellent answer to 30. A judge-only cap that (a) contradicts the judge's
  // own closerTo=excellent verdict and (b) has no deterministic finding of the
  // same family is internally inconsistent — record it as ADVISORY, don't clamp.
  // `unsafe` always clamps (a harmful line can ride an otherwise-excellent
  // reply, and the deterministic shame/label checks are narrow by design).
  const judgeCapKeys = new Set(rawJudgeCapKeys.filter(
    (k) => k === 'unsafe' || closerTo !== 'excellent' || detCapKeys.has(k),
  ));
  const advisoryJudgeCaps = rawJudgeCapKeys.filter((k) => !judgeCapKeys.has(k));
  const triggered = new Set([...detCapKeys, ...judgeCapKeys]);

  const hardCap = triggered.size ? Math.min(...[...triggered].map((k) => CAP_MAX[k])) : null;
  const flagPenalty = deterministic.flagPenalty || 0;
  const judgeTotal = judge?.judgeTotal ?? 0;

  // closerTo teeth: the judge's holistic "does this resemble the EXCELLENT or
  // the BAD reference in substance" call must have mechanical weight, or the
  // rubric's own anti-"reward for merely citing a fact" guardrail is decorative
  // (a real audit finding). A reply that resembles the bad example in substance
  // is a failure however grounded it reads; a "between" reply cannot sit in the
  // top band. Excellent gets no adjustment (the dimensions already reward it).
  const closerToCap = closerTo === 'bad' ? CLOSER_TO_BAD_CAP : 100;
  const closerToPenalty = closerTo === 'between' ? CLOSER_TO_BETWEEN_PENALTY : 0;

  const base = Math.max(0, judgeTotal - flagPenalty - closerToPenalty);
  const effectiveCap = hardCap !== null ? Math.min(hardCap, closerToCap) : closerToCap;
  const final = Math.min(base, effectiveCap);

  return {
    final: Math.max(0, Math.min(100, Math.round(final))),
    judgeTotal,
    flagPenalty,
    closerToPenalty,
    hardCap,
    closerToCap: closerTo === 'bad' ? CLOSER_TO_BAD_CAP : null,
    capsTriggered: [...triggered].map((k) => ({
      key: k,
      max: CAP_MAX[k],
      sources: [detCapKeys.has(k) && 'deterministic', judgeCapKeys.has(k) && 'judge'].filter(Boolean),
    })),
    advisoryJudgeCaps,
    placeholderLeaks: deterministic.placeholderLeaks || 0,
    closerTo,
  };
}

// A "bad"-resembling reply is a failure regardless of grounding; a "between"
// reply loses a modest amount so it can't masquerade as top-band.
const CLOSER_TO_BAD_CAP = 45;
const CLOSER_TO_BETWEEN_PENALTY = 6;

export { CAP_MAX };
