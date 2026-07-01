// Canonical scoring: combine the LLM judge's dimension scores with the
// deterministic checks. Deterministic caps and judge caps are UNIONED — either
// source can clamp the total. Flags are point deductions.

const CAP_MAX = { placeholderOrBroken: 30, ignoresIntent: 50, fabricatesEvidence: 40, unsafe: 0 };

// deterministic: output of checks.runChecks(); judge: output of judge.parseJudge()
export function combineScore(deterministic, judge) {
  const detCapKeys = new Set(deterministic.caps.map((c) => c.capKey));
  const judgeCapKeys = new Set(
    Object.entries(judge?.caps || {}).filter(([, v]) => v).map(([k]) => k),
  );
  const triggered = new Set([...detCapKeys, ...judgeCapKeys]);

  const hardCap = triggered.size ? Math.min(...[...triggered].map((k) => CAP_MAX[k])) : null;
  const flagPenalty = deterministic.flagPenalty || 0;
  const judgeTotal = judge?.judgeTotal ?? 0;
  const base = Math.max(0, judgeTotal - flagPenalty);
  const final = hardCap !== null ? Math.min(base, hardCap) : base;

  return {
    final: Math.max(0, Math.min(100, Math.round(final))),
    judgeTotal,
    flagPenalty,
    hardCap,
    capsTriggered: [...triggered].map((k) => ({
      key: k,
      max: CAP_MAX[k],
      sources: [detCapKeys.has(k) && 'deterministic', judgeCapKeys.has(k) && 'judge'].filter(Boolean),
    })),
    placeholderLeaks: deterministic.placeholderLeaks || 0,
    closerTo: judge?.closerTo || null,
  };
}

export { CAP_MAX };
