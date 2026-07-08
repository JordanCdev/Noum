// High-precision JS mirror of the last-mile production surface.
//
// `finalizeReplyForFixture` mirrors AICoachChatService.finalizedCoachReply.
// Production then still runs CoachReliabilityGate before committing the text to
// the UI. The full Swift gate has assessment-aware fallbacks, so this file only
// mirrors cases with a stable static recovery shape. It is diagnostic; official
// replay scoring remains tied to captured judge files.

import { finalizeReplyForFixture } from './finalizeReply.mjs';
import { runChecks } from './checks.mjs';

const COLD_START_FINDINGS = new Set([
  'coldStartFakeCalibration',
  'coldStartMetricTarget',
  'coldStartProductJargon',
  'coldStartUncalibratedMetricTarget',
  'coldStartVagueBaselineRep',
]);

function hasFinding(findings, ids) {
  return (findings || []).some((finding) => ids.has(finding.id));
}

function coldStartFallback(surface = 'text') {
  if (surface === 'live') {
    return "No baseline yet, so start there. Give me 60 seconds on something you know cold, like how you'd explain what you do to a stranger. Then I'll have something real to work from. Want to go now?";
  }
  return "No baseline yet, so start there. Run a quick 60-second rep on something you know cold, like how you'd explain what you do to a stranger. That gives me your real pace and rhythm and the fastest read on what actually matters for you. Want to give it a go?";
}

export function productionSurfaceReplyForFixture(raw, fixture = {}, opts = {}) {
  const finalizer = finalizeReplyForFixture(raw, fixture);
  const recentReplies = opts.recentReplies || [];
  const deterministic = runChecks(finalizer.text, fixture, {
    contextBlock: opts.contextBlock || '',
    recentReplies,
  });

  if (hasFinding(deterministic.findings, COLD_START_FINDINGS)) {
    const text = coldStartFallback(fixture.surface || opts.surface || 'text');
    const fallbackDeterministic = runChecks(text, fixture, {
      contextBlock: opts.contextBlock || '',
      recentReplies,
    });
    return {
      text,
      changed: text !== String(raw || '').trim(),
      changes: [...new Set([...finalizer.changes, 'reliabilityGateFallback'])],
      finalizer,
      reliabilityGate: {
        changed: true,
        issues: ['coldStartJargon'],
        source: 'CoachReliabilityGate.coldStartFallback',
      },
      deterministic: fallbackDeterministic,
    };
  }

  return {
    text: finalizer.text,
    changed: finalizer.changed,
    changes: finalizer.changes,
    finalizer,
    reliabilityGate: {
      changed: false,
      issues: [],
      source: null,
    },
    deterministic,
  };
}
