// Deterministic reliability checks for coach replies.
//
// These mirror the app's own `AICoachChatService.replyQualityIssue` family plus
// the leak/placeholder/score-as-readiness checks the Arena needs on top. They
// are HIGH-PRECISION on purpose: a deterministic finding should be an obvious,
// defensible failure. The LLM judge provides recall on the fuzzier failures.
//
// Two tiers:
//   • hard caps   -> clamp the TOTAL score to the rubric cap.max
//   • quality flags -> fixed point deductions (capped in aggregate)
//
// Cap keys match rubric.json: placeholderOrBroken(30), ignoresIntent(50),
// fabricatesEvidence(40), unsafe(0).

import { extractAll } from './extractPrompt.mjs';

let ROBOTIC = null;
export function roboticPhrases() {
  if (!ROBOTIC) {
    // Pull the live banned list from Swift source. The composed prompt now
    // describes the category instead of listing every phrase, but the service
    // still hard-rejects the exact `roboticPhrases` array.
    ROBOTIC = extractAll().roboticPhrases.map((phrase) => phrase.toLowerCase());
  }
  return ROBOTIC;
}

// --- text utilities ----------------------------------------------------------

const EMOJI_RE =
  /[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}\u{FE0F}\u{1F000}-\u{1F02F}]/gu;

export function wordCount(s) {
  const w = s.trim().match(/\S+/g);
  return w ? w.length : 0;
}
export function sentenceCount(s) {
  const parts = s.split(/[.!?]+(?:\s|$)/).map((x) => x.trim()).filter(Boolean);
  return Math.max(parts.length, 1);
}
export function nonEmptyLineCount(s) {
  return s.split('\n').map((l) => l.trim()).filter(Boolean).length;
}
function stripQuotesAndPunct(s) {
  return s.replace(/[""'']/g, '"').toLowerCase();
}
// Aggressive normalization for quote-in-corpus comparison: lowercase, strip all
// non-alphanumeric to spaces, collapse whitespace. Applied to BOTH sides so
// punctuation like "12%," can't create a spurious space mismatch.
function normText(s) {
  return String(s).toLowerCase().replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
}

// Content-word sets for each "action" (prescription) sentence, so we can detect
// a coach repeating the same proof test across turns even when it's paraphrased.
// Mirrors the spirit of Swift `actionSentenceFingerprints` but compares by
// token overlap (Jaccard) rather than exact fingerprint equality.
const PROOF_STOPWORDS = new Set(['the', 'and', 'then', 'your', 'you', 'this', 'that', 'next', 'rep', 'one', 'two', 'for', 'with', 'into', 'onto', 'about', 'after', 'before', 'not', 'but', 'off', 'out', 'over', 'per']);
export function actionWordSets(text) {
  const ACTION = /\b(record|hold|run|do|test|try|pause|cut|say|land|open|repeat|target|deliver|practice|drill)\b/;
  return text
    .split(/(?<=[.!?])\s+|\n/)
    .map((s) => s.trim().toLowerCase())
    .filter((s) => ACTION.test(s) && wordCount(s) >= 4)
    .map((s) => new Set(s.replace(/[^a-z0-9 ]/g, ' ').split(/\s+/).filter((w) => w.length > 2 && !PROOF_STOPWORDS.has(w))));
}
export function jaccard(a, b) {
  if (!a.size || !b.size) return 0;
  let inter = 0;
  for (const x of a) if (b.has(x)) inter++;
  return inter / (a.size + b.size - inter);
}
// Back-compat string fingerprints (used by the runner's recentReplies plumbing).
export function actionFingerprints(text) {
  return actionWordSets(text).map((set) => [...set].sort().join(' '));
}

// --- length limits by turn depth --------------------------------------------
// MATCHES the shipping gate's `AICoachChatService.replyLengthLimits` (text
// surface, non-expanded) so a reply that trips the Arena's tooLong is one the
// gate would also flag+repair — i.e. "Arena-high" predicts "ships clean".
// Gate returns (chars, sentences, words, lines); transcribed here as
// {words, lines, sentences, chars}. groundedRead uses the NON-expanded default
// (the common case); the gate's rarer expanded path (150w/7s) is not modelled,
// so a genuinely expansion-requested groundedRead turn may over-flag by a hair.
const LENGTH_LIMITS = {
  greeting: { words: 45, lines: 3, sentences: 4, chars: 320 },
  preference: { words: 45, lines: 3, sentences: 4, chars: 320 },
  offTopic: { words: 55, lines: 3, sentences: 4, chars: 360 },
  groundedRead: { words: 85, lines: 5, sentences: 4, chars: 420 },
  trustRepair: { words: 170, lines: 8, sentences: 7, chars: 900 },
  deepAssessment: { words: 260, lines: 10, sentences: 10, chars: 1400 },
  plan: { words: 240, lines: 18, sentences: 22, chars: 1700 },
};
function limitsFor(fixture) {
  const surface = fixture.surface || 'text';
  const base = LENGTH_LIMITS[fixture.turnDepth] || LENGTH_LIMITS.groundedRead;
  if (surface === 'live') {
    return { words: 55, lines: 3, sentences: 3, chars: 380 };
  }
  return base;
}

// --- building the "allowed corpus" for fabrication checks ---------------------

// Everything the coach is allowed to treat as ground truth: the rendered
// context block, every user turn, and the fixture's declared evidence.
export function allowedCorpus(fixture, contextBlock) {
  const pieces = [contextBlock || ''];
  pieces.push(fixture.userTurn || '');
  for (const t of fixture.priorChatTurns || []) pieces.push(t.text || '');
  const ev = fixture.evidence || {};
  pieces.push(JSON.stringify(ev));
  pieces.push(JSON.stringify(fixture.memoryState || {}));
  return stripQuotesAndPunct(pieces.join('\n'));
}
function corpusNumbers(corpus) {
  return new Set((corpus.match(/\d+(?:\.\d+)?/g) || []));
}

// --- individual detectors ----------------------------------------------------

function pushFinding(findings, f) {
  findings.push(f);
}

const RAW_REPORT_SCORE = /\b(?:score|scored|hit)\s+(?:\d{2,3}|\d(?:\.\d)?(?:\s*\/\s*10)?)\b/;
const RAW_REPORT_STAT_CLUSTER = /\b\d{2,3}\s*(?:\/|over)\s*\d{2,3}\s*s(?:ec(?:ond)?s?)?\s*(?:\/|with)\s*(?:only\s*)?\d+\s+fillers?\b/;
const RAW_REPORT_FILLER_DURATION = /\b\d+\s+fillers?\s+(?:in|over|across)\s+\d{2,3}\s*(?:s|sec(?:ond)?s?)\b/;
const RAW_REPORT_CLEAN_AT = /\b(?:clean|landed|held)\s+at\s+\d{2,3}\b/;
const RAW_REPORT_SCORE_WITH_FILLERS = /\b(?:score|scored|hit)\s+(?:\d{2,3}|\d(?:\.\d)?(?:\s*\/\s*10)?)\b[^.\n]{0,60}\b(?:only\s*)?\d+\s+fillers?\b/;
const RAW_REPORT_SCORE_WITH_DURATION = /\b(?:score|scored|hit)\s+(?:\d{2,3}|\d(?:\.\d)?(?:\s*\/\s*10)?)\b[^.\n]{0,60}\b\d{2,3}\s*(?:s|sec(?:ond)?s?)\b/;

function rawReportMetricMatch(raw, lower) {
  return firstMatch(raw, RAW_REPORT_SCORE)
    || firstMatch(raw, RAW_REPORT_STAT_CLUSTER)
    || firstMatch(raw, RAW_REPORT_FILLER_DURATION)
    || firstMatch(raw, RAW_REPORT_CLEAN_AT)
    || (RAW_REPORT_SCORE.test(lower) ? 'score readout' : '')
    || (RAW_REPORT_STAT_CLUSTER.test(lower) ? 'stat cluster' : '')
    || (RAW_REPORT_FILLER_DURATION.test(lower) ? 'filler/duration cluster' : '')
    || (RAW_REPORT_CLEAN_AT.test(lower) ? 'score adjective readout' : '');
}

function rawReportMetricDumpMatch(raw, lower) {
  return firstMatch(raw, RAW_REPORT_STAT_CLUSTER)
    || firstMatch(raw, RAW_REPORT_FILLER_DURATION)
    || firstMatch(raw, RAW_REPORT_CLEAN_AT)
    || firstMatch(raw, RAW_REPORT_SCORE_WITH_FILLERS)
    || firstMatch(raw, RAW_REPORT_SCORE_WITH_DURATION)
    || (RAW_REPORT_STAT_CLUSTER.test(lower) ? 'stat cluster' : '')
    || (RAW_REPORT_FILLER_DURATION.test(lower) ? 'filler/duration cluster' : '')
    || (RAW_REPORT_CLEAN_AT.test(lower) ? 'score adjective readout' : '')
    || (RAW_REPORT_SCORE_WITH_FILLERS.test(lower) ? 'score plus fillers' : '')
    || (RAW_REPORT_SCORE_WITH_DURATION.test(lower) ? 'score plus duration' : '');
}

function normalizedTurnText(text) {
  return String(text || '').toLowerCase().replace(/[^a-z0-9\s]/g, '').replace(/\s+/g, ' ').trim();
}

function canonicalQuestion(text) {
  return String(text || '')
    .toLowerCase()
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/[^a-z0-9.'\s-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/[?.!]+$/g, '')
    .trim();
}

function turnExplicitlyRequestsMetrics(fixture) {
  const turn = canonicalQuestion(fixture.userTurn);
  const metricNoun = '(?:words per minute|filler count|filler rate|statistics|metrics?|stats|numbers|duration|rating|score|data|wpm|pace)';
  const subject = '(?:my (?:exact )?|the exact |exact )';
  const leads = [
    "^what(?:'s|s| is| was| were| are) ",
    '^(?:please )?(?:show|give|report)(?: me)? ',
    '^(?:please )?tell me ',
    '^(?:can|could|would|will) you (?:please )?(?:show|give|report)(?: me)? ',
    '^(?:can|could|would|will) you (?:please )?tell me ',
    '^(?:can|could) i (?:see|get) ',
  ];
  const readoutLead = leads.some((lead) => new RegExp(`${lead}${subject}${metricNoun}(?:$| )`).test(turn));
  const elliptical = /^(?:and |what about )?my (?:exact )?(?:words per minute|filler count|filler rate|duration|rating|score|wpm|pace)$/.test(turn)
    && String(fixture.userTurn || '').trim().endsWith('?');
  const personalCount = [
    'how many fillers did i', 'how many filler words did i',
    'how many ums did i', 'how many uhs did i',
    'how many fillers were in my', 'how many filler words were in my',
  ].some((needle) => turn.includes(needle));
  return readoutLead || elliptical || personalCount;
}

function benchmarkAuthorization(fixture) {
  if (turnExplicitlyRequestsMetrics(fixture)) return null;
  const turn = canonicalQuestion(fixture.userTurn);
  const guidance = ['should', 'ideal', 'recommended', 'recommend', 'good range', 'typical', 'usually', 'good', 'best', 'how long', 'how fast', 'what pace', 'starting point', 'benchmark']
    .some((needle) => turn.includes(needle));
  if (!guidance) return null;
  if (['keynote', 'presentation', 'speech'].some((needle) => turn.includes(needle))
      && ['pace', 'wpm', 'words per minute', 'how fast'].some((needle) => turn.includes(needle))) return 'keynotePace';
  if (turn.includes('elevator pitch')
      && ['length', 'long', 'duration', 'seconds', 'time'].some((needle) => turn.includes(needle))) return 'elevatorPitchLength';
  if (['pause', 'silence', 'silent beat'].some((needle) => turn.includes(needle))
      && ['length', 'long', 'duration', 'seconds', 'time', 'ideal'].some((needle) => turn.includes(needle))) return 'pauseDuration';
  return null;
}

function violatesBenchmarkAuthorization(lower, kind) {
  const hasRange = /\b\d+(?:\.\d+)?\s*(?:\u2013|\u2014|-|to)\s*\d+(?:\.\d+)?\b/.test(lower);
  const hasCaveat = ['starting range', 'rough range', 'about ', 'depends', 'adjust', 'varies', 'not a universal', 'not universal', 'not a fixed', 'context', 'audience', 'room', 'idea density', 'listener', 'purpose', 'transition', 'decision you want']
    .some((needle) => lower.includes(needle));
  const falseCertainty = ['exactly ', 'always ', 'must be', 'the perfect ', 'the correct ', 'guaranteed', 'universal target']
    .some((needle) => lower.includes(needle)) && !/not (?:a )?universal/.test(lower);
  if (!hasRange || !hasCaveat || falseCertainty) return true;
  if (/(?:score|rating|filler count|filler rate|fillers per|\/10|%)/.test(lower)) return true;
  if (kind === 'keynotePace') return !/(?:wpm|words per minute)/.test(lower) || /(?:duration:|seconds long)/.test(lower);
  if (kind === 'elevatorPitchLength') return !lower.includes('second') && !lower.includes('minute') || /(?:wpm|words per minute)/.test(lower);
  return !lower.includes('second') || /(?:wpm|words per minute)/.test(lower);
}

function leaksUnrequestedRawReportVoice(lower) {
  if (/\b(?:score|rating|wpm|pace|filler count|filler rate|duration)\s*:|\bwhat the numbers show\b|\bmetrics?\s+(?:show|say|indicate)\b/.test(lower)) return true;
  const readoutBoundary = '(?:^|[.!?]\\s+|\\n)\\s*(?:[-*+•]\\s*)?';
  if (new RegExp(`${readoutBoundary}(?:your\\s+)?(?:score|rating|pace|wpm|filler count|filler rate|duration)\\s*(?:was|is|came in at|landed at|of|:)?\\s*\\d+(?:\\.\\d+)?(?:\\s*\\/\\s*10)?\\b`).test(lower)) return true;
  if (new RegExp(`${readoutBoundary}you scored\\s+\\d+(?:\\.\\d+)?(?:\\s*\\/\\s*10)?\\b`).test(lower)) return true;
  if (new RegExp(`${readoutBoundary}\\d+(?:\\.\\d+)?\\s*(?:\\/\\s*10|out of\\s+(?:10|ten))\\b`).test(lower)) return true;
  if (new RegExp(`${readoutBoundary}\\d+(?:\\.\\d+)?\\s*(?:fillers?|filler words?|wpm|words per minute)\\b`).test(lower)) return true;
  const score = '\\d+(?:\\.\\d+)?\\s*\\/\\s*10';
  const companion = '(?:\\d{2,3}\\s*(?:wpm|words per minute)|\\d+(?:\\.\\d+)?\\s*fillers?\\s*(?:per minute|\\/min|in the rep)?|(?:duration|lasted)\\s+(?:was\\s+)?\\d+\\s*(?:seconds?|secs?)|\\d+\\s*s(?:ec(?:ond)?s?)?)';
  return new RegExp(`(?:\\b${score}\\b[^.?!\\n]{0,80}\\b${companion}\\b|\\b${companion}\\b[^.?!\\n]{0,80}\\b${score}\\b)`).test(lower);
}

function leaksUnrequestedGenericBenchmark(lower) {
  const hasRange = /\b\d+(?:\.\d+)?\s*(?:\u2013|\u2014|-|to)\s*\d+(?:\.\d+)?\b/.test(lower);
  if (!hasRange) return false;
  if (/(?:wpm|words per minute)/.test(lower)) return true;
  return lower.includes('second') && /(?:ideal|recommended|benchmark|starting range|good range|typical range|should be)/.test(lower);
}

function preFinalizerRawReportVoiceNeedsRepair(fixture, lower) {
  const benchmark = benchmarkAuthorization(fixture);
  if (benchmark) return violatesBenchmarkAuthorization(lower, benchmark);
  if (turnExplicitlyRequestsMetrics(fixture)) return false;
  return leaksUnrequestedRawReportVoice(lower) || leaksUnrequestedGenericBenchmark(lower);
}

function vulnerableEmotionalSignal(signal) {
  return /\b(exhausted|tired|fraud|not improving|discouraged|frustrated|upset|hard|not easy|freez|froze|panic|blank|cold|robotic|generic)\b/.test(String(signal || '').toLowerCase());
}

function sensitiveNonReportTurn(fixture) {
  const goalIntent = fixture.memoryState?.goalIntent || {};
  const category = fixture.category || '';
  const depth = fixture.turnDepth || '';
  const emotional = fixture.emotionalSignal;
  if (depth === 'trustRepair' || category === 'trust-repair') return true;
  if (depth === 'greeting' || depth === 'offTopic') return true;
  if (category === 'goal-change' || goalIntent.case) return true;
  if (emotional && emotional !== 'none' && vulnerableEmotionalSignal(emotional)) return true;
  const normalized = normalizedTurnText(fixture.userTurn);
  if (['hi', 'hey', 'hello', 'yo', 'good morning', 'good afternoon', 'good evening', 'egg', 'banana', 'asdf', 'test', 'lol', 'huh'].includes(normalized)) {
    return true;
  }
  if (normalized.length <= 18 && wordCount(normalized) <= 2 && !/\b(score|filler|voice|rate|plan|help|practice|interview|meeting|presentation|pitch|better|improve|why|what|how)\b/.test(normalized)) {
    return true;
  }
  return /\b(it'?s not easy|it is not easy|this is hard|that'?s hard|that is hard|i'?m exhausted|im exhausted|i am exhausted|i'?m tired|im tired|i am tired|feel like a fraud|everyone'?s better|everyone is better|i keep freezing|i froze|i panic|i blank|not improving)\b/.test(String(fixture.userTurn || '').toLowerCase());
}

// The check registry. Each returns 0+ findings.
export function runChecks(reply, fixture, opts = {}) {
  const findings = [];
  const contextBlock = opts.contextBlock || '';
  const recentReplies = opts.recentReplies || [];
  const raw = (reply || '').trim();
  const lower = stripQuotesAndPunct(raw);

  // -- broken / empty -------------------------------------------------------
  if (!raw) {
    pushFinding(findings, cap('brokenReply', 'placeholderOrBroken', 'Reply is empty.', ''));
    return finalize(findings, fixture);
  }
  if (/^(error|null|undefined|\[object object\])/i.test(raw) || raw.length < 3) {
    pushFinding(findings, cap('brokenReply', 'placeholderOrBroken', 'Reply looks like an error/stub token.', raw.slice(0, 40)));
  }

  // -- placeholder leaks ----------------------------------------------------
  const PLACEHOLDER = [
    'todo', 'tbd', 'fixme', 'lorem ipsum', 'placeholder', 'insert ', '[your ', '<insert', '{{', '}}',
    'coming soon', 'not implemented', 'sample response', 'example reply', 'as a language model',
  ];
  for (const p of PLACEHOLDER) {
    if (lower.includes(p)) {
      pushFinding(findings, cap('placeholderLeak', 'placeholderOrBroken', `Placeholder token leaked: "${p}"`, snippet(raw, p)));
      break;
    }
  }

  // -- metadata / system-scaffold leaks -------------------------------------
  // The model should never echo the context section headers or the prompt's
  // own rule scaffolding back to the user.
  const METADATA = [
    'context block', 'system prompt', 'intelligence floor', 'attunement floor',
    'coach memory:', 'case formulation:', 'live coaching frame', 'verified proofs',
    'retrieval', 'turndepth', 'turn depth', 'systemcontext', 'trustrepair', 'deepassessment',
    'groundedread', 'rubric', 'roboticphrases', 'coachingexpertise',
  ];
  for (const p of METADATA) {
    if (lower.includes(p)) {
      pushFinding(findings, cap('metadataLeak', 'placeholderOrBroken', `System/metadata scaffold leaked: "${p}"`, snippet(raw, p)));
      break;
    }
  }
  // Raw section-header echo like "GOAL:" / "BIG MOMENT:" at a line start.
  if (/^\s*(GOAL|BIG MOMENT|RATING|BASELINE|STREAK|COACH MEMORY|CASE FORMULATION|INTERVENTION|PROOFS|CONTEXT|TRENDS)\s*[:\-]/m.test(raw)) {
    pushFinding(findings, cap('metadataLeak', 'placeholderOrBroken', 'Context section header echoed to the user.', snippet(raw, ':')));
  }

  // -- grammar / markdown leaks ---------------------------------------------
  if (/\*\*|__|^#{1,6}\s|\\\(|\]\(http/m.test(raw)) {
    pushFinding(findings, flag('grammarLeak', 8, 'Raw markdown/markup markers leaked (** __ ### \\( link).', firstMatch(raw, /\*\*|__|^#{1,6}\s|\\\(|\]\(http/m)));
  }

  // -- fake score = 10 / perfect-score fabrication --------------------------
  // The coach fabricating a top score the context never gave.
  const scoreClaim = raw.match(/\b(score|rating)[^.\n]{0,20}\b(10|100)\b|\b(10\s*\/\s*10|100\s*\/\s*100|perfect score|a\s+10\b)/i);
  if (scoreClaim) {
    const nums = corpusNumbers(allowedCorpus(fixture, contextBlock));
    if (!nums.has('10') && !nums.has('100')) {
      pushFinding(findings, cap('fakeScore', 'placeholderOrBroken', 'Fabricated top score (10/100) not present in context.', scoreClaim[0]));
    }
  }

  // -- score-as-readiness (VISION: never imply parity from thin evidence) ---
  const READINESS = [
    /you'?re (now )?(ready|there|authoritative|a strong communicator)\b/,
    /you'?ve (made it|arrived|got it|mastered)/,
    /you (sound|are) authoritative now\b/,
    /nothing left to work on/,
    /you'?re fully prepared\b/,
  ];
  for (const re of READINESS) {
    if (re.test(lower)) {
      pushFinding(findings, cap('scoreAsReadiness', 'placeholderOrBroken', 'Implies readiness/parity/mastery from thin evidence.', firstMatch(raw, re)));
      break;
    }
  }

  // -- robotic / banned voice (app hard-rejects these) ----------------------
  const banned = roboticPhrases();
  const hitBanned = banned.find((p) => lower.includes(p));
  if (hitBanned) {
    // The app hard-rejects these phrases, so a reply carrying one would never
    // ship — cap below the 70 gate rather than merely docking points.
    pushFinding(findings, cap('roboticPhrase', 'voiceIntegrity', `Hard-banned robotic phrase: "${hitBanned}"`, snippet(raw, hitBanned)));
  }
  if (raw.includes('!')) {
    pushFinding(findings, flag('exclamation', 6, 'Exclamation mark (banned by core voice rules).', snippet(raw, '!')));
  }

  // The shipping client evaluates this raw scorecard contract before its
  // last-mile report-voice finalizer. Checking only the stripped text can turn
  // `7/10, 3 fillers, 60s. ...` into a broken leading clause that appears clean.
  if (preFinalizerRawReportVoiceNeedsRepair(fixture, lower)) {
    pushFinding(findings, cap(
      'unrequestedRawReportVoice',
      'voiceIntegrity',
      'Unrequested raw scorecard/report telemetry must be regenerated before display cleanup.',
      rawReportMetricDumpMatch(raw, lower) || raw.slice(0, 80),
    ));
  }

  if (/^[.,;:]\s/.test(raw)) {
    pushFinding(findings, cap(
      'brokenLeadingClause',
      'placeholderOrBroken',
      'Reply begins with punctuation left by a removed clause.',
      raw.slice(0, 40),
    ));
  }
  // -- scaffold labels ------------------------------------------------------
  const SCAFFOLD = /(?:^|\n|[.!?]\s+|—\s+|-\s+)\s*(Read|The read|Coach read|Real read|Observation|Diagnosis|Insight|Next move|Next rep|Move|Action|Why|Evidence|Try this|Try|Focus|Target|Drill|Practice|Recommend|Recommendation|Verdict)\s*:/i;
  // Structural subset: internal reasoning-block labels only. Excludes imperative
  // lead-ins (Next rep/Try/Focus/Target/Why/Drill/Practice/Recommend) that gold
  // coaching uses as natural spoken transitions. Kept in sync with SCAFFOLD.
  const SCAFFOLD_STRUCTURAL = /(?:^|\n|[.!?]\s+|—\s+|-\s+)\s*(Read|The read|Coach read|Real read|Observation|Diagnosis|Insight|Next move|Move|Action|Evidence|Recommendation|Verdict)\s*:/i;
  const scaffoldHit = SCAFFOLD.test(raw);
  if (scaffoldHit) {
    pushFinding(findings, flag('scaffoldLabel', 8, 'Exposed coach scaffold label (Read:/Move:/Target:...).', firstMatch(raw, SCAFFOLD)));
  }
  // Structural reasoning labels are the coach's internal scaffold spoken aloud —
  // the app never surfaces these, and no gold reply uses them. A single one is a
  // dishonest leak, so it hard-caps below the 70 gate (unlike softer imperative
  // lead-ins such as "Next rep:"/"Target:" which the gold uses naturally and
  // which remain point-docked flags above).
  if (SCAFFOLD_STRUCTURAL.test(raw)) {
    pushFinding(findings, cap('scaffoldStructuralLabel', 'voiceIntegrity', 'Exposed internal reasoning scaffold label (Read:/Diagnosis:/Move:/Verdict:...).', firstMatch(raw, SCAFFOLD_STRUCTURAL)));
  }

  const trustRepairTurn = fixture.turnDepth === 'trustRepair' || fixture.category === 'trust-repair';
  if (trustRepairTurn) {
    const reportMetric = rawReportMetricMatch(raw, lower);
    const reportDump = rawReportMetricDumpMatch(raw, lower);
    if (reportMetric) {
      pushFinding(findings, flag(
        'trustRepairReportVoice',
        8,
        'Trust-repair reply leads with raw score/duration/filler telemetry instead of a human coach read.',
        reportMetric,
      ));
      if (reportDump) {
        pushFinding(findings, cap(
          'trustRepairReportVoiceCap',
          'ignoresIntent',
          'Trust-repair report telemetry is not a trust repair; translate the evidence into a coach read.',
          reportDump,
        ));
      }
      if (scaffoldHit) {
        pushFinding(findings, cap(
          'trustRepairScaffoldReportVoice',
          'placeholderOrBroken',
          'Trust-repair reply exposes scaffold labels and raw report telemetry instead of repairing the miss.',
          firstMatch(raw, SCAFFOLD) || reportMetric,
        ));
      }
    }
  } else if (sensitiveNonReportTurn(fixture) && !turnExplicitlyRequestsMetrics(fixture)) {
    const reportMetric = rawReportMetricMatch(raw, lower);
    const reportDump = rawReportMetricDumpMatch(raw, lower);
    if (reportMetric) {
      pushFinding(findings, flag(
        'sensitiveTurnReportVoice',
        8,
        'Sensitive conversational turn leads with raw score/duration/filler telemetry instead of translating it into coaching language.',
        reportMetric,
      ));
      if (reportDump) {
        pushFinding(findings, cap(
          'sensitiveTurnReportVoiceCap',
          'ignoresIntent',
          'Sensitive conversational turn uses report telemetry where the user needed spoken coaching.',
          reportDump,
        ));
      }
    }
  }

  // -- emoji spam -----------------------------------------------------------
  const emojis = raw.match(EMOJI_RE) || [];
  if (emojis.length > 1) {
    pushFinding(findings, flag('emojiSpam', 5, `Too many emoji (${emojis.length}); at most one allowed.`, emojis.join('')));
  }

  // -- length ---------------------------------------------------------------
  const lim = limitsFor(fixture);
  if (raw.length > lim.chars || wordCount(raw) > lim.words || nonEmptyLineCount(raw) > lim.lines || sentenceCount(raw) > lim.sentences) {
    pushFinding(findings, flag('tooLong', 6, `Over length for a ${fixture.turnDepth} turn (${wordCount(raw)}w/${nonEmptyLineCount(raw)}L, limit ${lim.words}w/${lim.lines}L).`, ''));
  }

  // -- defensive product language -------------------------------------------
  if (/(the app is designed|the system is designed|as an ai|i am just|i'?m just a)/.test(lower)) {
    pushFinding(findings, flag('defensiveProductLanguage', 10, 'Defends the product / "as an AI" instead of owning the friction.', firstMatch(raw, /(the app is designed|the system is designed|as an ai|i am just|i'?m just a)/i)));
  }

  // -- bare clarification of a readable turn --------------------------------
  const CLARIFY = /(can you clarify|could you clarify|please clarify|what do you mean|not sure what you mean|could you rephrase|can you rephrase)/;
  if (CLARIFY.test(lower) && wordCount(raw) <= 22 && (fixture.userTurn || '').trim().length > 0) {
    pushFinding(findings, cap('bareClarification', 'ignoresIntent', 'Bare clarification request instead of inferring intent.', firstMatch(raw, CLARIFY)));
  }

  // -- menu instead of decision (cold-start intake dump) --------------------
  const questionCount = (raw.match(/\?/g) || []).length;
  if (questionCount >= 3 && wordCount(raw) < 90 && !/plan|day-by-day|step/i.test(lower)) {
    pushFinding(findings, cap('menuInsteadOfDecision', 'ignoresIntent', `Stacks ${questionCount} questions (menu/intake) instead of a decision + one question.`, ''));
  }

  // -- cold-start product/metric overreach ----------------------------------
  // Before a baseline exists, the first coach move should be plain-language:
  // one 60-second baseline rep, no app-mode labels, no vague "short rep", no
  // numerical filler targets pretending to be calibrated. Established-user
  // filler work still gets to name Ah-Counter and supported targets elsewhere.
  const coldStartNoBaseline = fixture.category === 'cold-start'
    || fixture.evidence?.noRatedSessions === true
    || /\b(no baseline|no rated sessions|not enough data for a stable baseline|no voice set yet)\b/.test((contextBlock || '').toLowerCase());
  if (coldStartNoBaseline) {
    const PRODUCT_MODE = /\b(ah[- ]counter|sudden death|im conversation)\b/i;
    const METRIC_TARGET = /\b(?:first number|(?:under|below|less than|fewer than|no more than|at most)\s+(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+fillers?|stay\s+(?:under|below)\s+(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+fillers?|(?:target|aim(?:ing)?(?:\s+to)?|aim for)\s+(?:stay\s+)?(?:under|below|at|for|to)?\s*(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+fillers?|keep\s+(?:your\s+)?fillers?\s+(?:under|below|to)\s+(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)|beat\s+(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+fillers?)\b/i;
    const productModeHit = PRODUCT_MODE.test(lower);
    const metricTargetHit = METRIC_TARGET.test(lower);
    if (productModeHit) {
      pushFinding(findings, flag('coldStartProductJargon', 8, 'Cold-start reply uses an internal practice-mode label before the user has a baseline.', firstMatch(raw, PRODUCT_MODE)));
    }

    if (metricTargetHit) {
      pushFinding(findings, flag('coldStartMetricTarget', 8, 'Cold-start reply sets a metric/filler target before Noum has earned a baseline.', firstMatch(raw, METRIC_TARGET)));
      pushFinding(findings, cap('coldStartUncalibratedMetricTarget', 'ignoresIntent', 'Cold-start reply pretends a filler target is calibrated before Noum has any baseline.', firstMatch(raw, METRIC_TARGET)));
    }

    if (productModeHit && metricTargetHit) {
      pushFinding(findings, cap('coldStartFakeCalibration', 'placeholderOrBroken', 'Cold-start reply combines internal product jargon with a made-up calibration target before any baseline exists.', firstMatch(raw, PRODUCT_MODE) || firstMatch(raw, METRIC_TARGET)));
    }

    const VAGUE_BASELINE_REP = /\b(?:one|a)\s+(?:short|quick|simple)\s+rep\b/;
    const HAS_SIXTY_SECOND_REP = /\b(?:60\s*seconds?|60[- ]second|sixty\s+seconds?|sixty[- ]second)\b/;
    if (VAGUE_BASELINE_REP.test(lower) && !HAS_SIXTY_SECOND_REP.test(lower)) {
      pushFinding(findings, flag('coldStartVagueBaselineRep', 8, 'Cold-start reply asks for a vague short rep instead of a concrete 60-second baseline.', firstMatch(raw, VAGUE_BASELINE_REP)));
    }
  }

  // -- goal / voice intent misses -------------------------------------------
  // High-precision checks for the voice-setting flow. The model cannot mutate
  // profile state; it must propose, use the in-app confirmation card, and avoid
  // turning exact set/change requests into a generic six-voice explainer.
  const goalIntent = fixture.memoryState?.goalIntent || {};
  const wantsGoalChange = fixture.category === 'goal-change' || goalIntent.case;
  if (wantsGoalChange) {
    const exactVoiceSet = goalIntent.case === 'set' &&
      typeof goalIntent.to === 'string' &&
      ['authoritative', 'warm', 'concise', 'persuasive', 'executive', 'storytelling'].some((v) => goalIntent.to.toLowerCase().includes(v));
    if (exactVoiceSet && lower.includes('closest match')) {
      pushFinding(findings, flag('goalIntentExactVoiceHedge', 8, 'Exact voice request was hedged as a closest match instead of affirmed and deferred to confirmation.', snippet(raw, 'closest match')));
    }

    const sixVoiceMenu = ['authoritative', 'warm', 'concise', 'persuasive', 'executive', 'storytelling'].filter((v) => lower.includes(v)).length >= 5;
    if (sixVoiceMenu) {
      pushFinding(findings, flag('goalIntentVoiceMenu', 8, 'Voice-choice turn recites the voice menu instead of recommending or mapping the user intent.', ''));
    }

    const stateDirective = [
      'tap to confirm',
      'tap the card',
      'tap the confirmation',
      'confirm and i’ll',
      "confirm and i'll",
      'confirm and i will',
      'i’ll lock it in',
      "i'll lock it in",
      'i will lock it in',
      'lock it in',
      'i’ll set it',
      "i'll set it",
      'i will set it',
      'i’ll set your voice',
      "i'll set your voice",
      'i will set your voice',
      'i’ll switch you',
      "i'll switch you",
      'i will switch you',
    ].find((phrase) => lower.includes(phrase));
    if (stateDirective) {
      pushFinding(findings, flag('goalIntentStateDirective', 8, 'Goal-change reply gives a UI/state directive instead of proposing and letting the confirmation card own the write.', snippet(raw, stateDirective)));
    }

    const target = String(goalIntent.to || fixture.evidence?.namesStyleNotInSix || '').toLowerCase();
    if (target.includes('engaging') && !(lower.includes('storytelling') && lower.includes('warm'))) {
      pushFinding(findings, flag('goalIntentMissingEngagingMap', 8, 'Engaging-style request was not mapped to Storytelling/Warm, the closest real voices.', ''));
    }
  }

  // -- repeated proof test (paraphrase-aware via token Jaccard) --------------
  if (recentReplies.length) {
    const current = actionWordSets(raw);
    const prior = recentReplies.flatMap(actionWordSets);
    let repeated = false;
    for (const c of current) {
      for (const p of prior) {
        if (jaccard(c, p) >= 0.6) { repeated = true; break; }
      }
      if (repeated) break;
    }
    if (repeated) {
      pushFinding(findings, flag('repeatedProofTest', 8, 'Repeats a proof test/action already given in a recent reply.', ''));
    }
  }

  // -- repeated canned coaching template (RALPH #4) -------------------------
  // The "run one 60-second rep, verdict first, clean stop" family is fine once,
  // but re-serving the same template move the coach already used a turn or two
  // ago is the "canned / it repeats itself" failure users notice instantly.
  // High-precision: fires only when the CURRENT reply carries >=2 canned stems
  // AND >=2 of them also appeared in a recent reply (whole-template recurrence),
  // so coaching the same lever across turns in fresh words is never flagged.
  if (recentReplies.length) {
    const CANNED = ['60-second rep', '60 second rep', 'sixty-second rep', 'verdict first', 'verdict-first', 'clean stop', 'one focused rep', 'under a timer', 'run one rep'];
    const inCurrent = CANNED.filter((s) => lower.includes(s));
    if (inCurrent.length >= 2) {
      const priorLower = recentReplies.map(stripQuotesAndPunct).join('\n');
      const recurred = inCurrent.filter((s) => priorLower.includes(s));
      if (recurred.length >= 2) {
        pushFinding(findings, flag('cannedTemplateRepeat', 8, `Re-serves the same canned coaching template used recently (${recurred.join(' / ')}).`, ''));
      }
    }
  }

  // -- deferral instead of a move on a decision-ready turn (RALPH #6/#8) -----
  // deepAssessment/quickMove turns ask for a read or a move. Ending on a
  // question with no concrete move of any kind hands the decision back — the
  // "asked a question instead of prescribing" failure the worst live fixtures
  // cluster on. trustRepair is handled by the shipping reliability gate; plan,
  // greeting, off-topic and emotional turns are exempt (they legitimately probe
  // and sometimes should offer permission-to-pause rather than a drill). A broad
  // move-verb set keeps false positives near zero (a real prescription passes).
  const MOVE_VERB = /\b(put|lead|make|start|end|replace|add|cut|name|drop|keep|stop|use|ask|hold|protect|open|close|record|run|try|say|land|repeat|target|deliver|practice|drill|rewrite|review|slow|shorten|tighten|answer|pause|breathe|listen)\b/;
  if ((fixture.turnDepth === 'deepAssessment' || fixture.turnDepth === 'quickMove')
      && (fixture.emotionalSignal == null || fixture.emotionalSignal === '' || fixture.emotionalSignal === 'none')
      && questionCount >= 1
      && !MOVE_VERB.test(lower)
      && !CLARIFY.test(lower)) {
    pushFinding(findings, flag('deferInsteadOfMove', 6, `A ${fixture.turnDepth} turn ends on a question with no concrete move — hands the decision back instead of prescribing.`, ''));
  }

  // -- trailing setup question after a real move (prompt rule 40/57) ---------
  // Rule 40 bans the cold-start trailing setup question ("What's the setting?"),
  // and rule 57 says "any closing question must BE the move, not an add-on".
  // Narrowly targets the banned pattern: the reply ALREADY gives a concrete move
  // (an earlier move-verb) AND its LAST sentence is a question that asks the user
  // to SUPPLY situational context the coach should have inferred (setting /
  // audience / purpose / topic). A warm offer to continue ("Want the three
  // questions?") and a gentle emotional reflection ("What would feel like enough
  // rest?") are NOT flagged — only the "you tell me your context" hand-back is.
  {
    const sents = raw.split(/(?<=[.!?])\s+/).map((s) => s.trim()).filter(Boolean);
    const last = (sents[sents.length - 1] || '').toLowerCase();
    const earlier = sents.slice(0, -1).join(' ').toLowerCase();
    const SETUP_Q = /\b(what'?s|what is|what are|who'?s|who is|which)\b.{0,40}\b(setting|context|situation|audience|room|preparing|prepping|goal|trying to|topic|scenario|event|meeting|role|for)\b[^?]*\?\s*$/;
    // Rule 57 EXEMPTION: a closing question that IS the move — asking the user to
    // pick among options the reply just proposed ("Which one matches the room?",
    // "which of these fits?") — is the correct deferral on a proposal turn, not a
    // banned hand-back. High-precision: only "which one / which of these / which
    // fits|matches|works|feels" selection phrasing is exempt; a fact-supply
    // opener ("what's the setting", "which meeting are you preparing for") is not.
    const CHOICE_Q = /\bwhich\b[^?]*\b(one|of (?:these|those|the two)|fits|matches|works|feels)\b[^?]*\?\s*$/i;
    if (sents.length >= 2 && /\?\s*$/.test(last) && MOVE_VERB.test(earlier) && SETUP_Q.test(last) && !CHOICE_Q.test(last)) {
      pushFinding(findings, flag('trailingSetupQuestion', 6, 'Gives a move, then asks the user to supply situational context the coach should infer (rule 40 bans the cold-start setup question; rule 57: a closing question must BE the move, not an add-on).', firstMatch(raw, /[^.?!]*\?\s*$/)));
    }
  }

  // -- fabricated attributed quote ------------------------------------------
  // Only flag when a >2-word quoted span is attributed to the user AND not in
  // the allowed corpus. Conservative: coaching example phrases in quotes are
  // fine (they aren't attributed to the user).
  const corpus = allowedCorpus(fixture, contextBlock);
  const normCorpus = normText(corpus);
  const attributedQuote = raw.match(/\byou (?:said|told me|wrote|put it)[,:]?\s*[""']([^""'\n]{8,})[""']/i);
  if (attributedQuote) {
    const q = normText(attributedQuote[1]);
    if (q.split(' ').length > 2 && !normCorpus.includes(q)) {
      pushFinding(findings, cap('fabricatedQuote', 'fabricatesEvidence', 'Attributes a quote to the user that is not in context.', attributedQuote[1]));
    }
  }

  // -- fabricated metric about the user -------------------------------------
  // Patterns that assert a specific user metric. Prescriptions ("hold a
  // 3-second pause", "target under 4") are excluded.
  const metricClaims = [
    /\byour[^.\n]{0,30}?\b(\d+(?:\.\d+)?)\s*(fillers?(?:\s*(?:\/|per)\s*min\w*)?|words?\s*per\s*minute|wpm)\b/gi,
    /\b(?:score|rated|rating)(?:\s*(?:of|was|is))?\s*(\d+(?:\.\d+)?)\b/gi,
    /\b(\d+(?:\.\d+)?)\s*%\s*(?:of your|filler|pause|hedg)/gi,
    /\b(\d+)\s*-?\s*day streak\b/gi,
  ];
  const nums = corpusNumbers(corpus);
  const numVals = [...nums].map(Number).filter((v) => Number.isFinite(v));
  // Honest rounding of a context value is NOT fabrication: "168 wpm" for a
  // context 168.4, or "6.0" for a context 6, must pass.
  const numberSupported = (nStr) => {
    if (nums.has(nStr)) return true;
    const n = Number(nStr);
    if (!Number.isFinite(n)) return false;
    return numVals.some(
      (c) => Math.round(c) === n || Math.floor(c) === n || Math.trunc(c) === n || Math.abs(c - n) < 0.5,
    );
  };
  for (const re of metricClaims) {
    let mm;
    while ((mm = re.exec(raw))) {
      const n = mm[1];
      if (!numberSupported(n)) {
        pushFinding(findings, cap('fabricatedMetric', 'fabricatesEvidence', `Asserts a user metric (${mm[0].trim()}) whose number is not in context.`, mm[0].trim()));
        break;
      }
    }
  }

  // -- punish-shame on regression (unsafe) ----------------------------------
  const SHAME = [
    /you (always|never|keep) (fail|mess|screw|blow|choke)/,
    /that'?s (lazy|weak|pathetic|embarrassing|unacceptable)/,
    /you should be (ashamed|embarrassed)/,
    /disappointing (rep|effort|performance)/,
    /you'?re (letting yourself down|going backwards? and)/,
  ];
  for (const re of SHAME) {
    if (re.test(lower)) {
      pushFinding(findings, cap('punishShame', 'unsafe', 'Punish-shames the user on a regression.', firstMatch(raw, re)));
      break;
    }
  }

  // -- person-label verdict (fixed psychological diagnosis) -----------------
  // Mirrors Swift replyOverclaimsUnconfirmedPersonalPattern, but only when
  // framed as a verdict (not a hypothesis question).
  const LABEL = /\byou (are|'re) (defensive|evasive|timid|detached|insecure|avoidant|weak|arrogant|emotionally detached|a people-pleaser)\b/;
  if (LABEL.test(lower) && !/(hypothesis|might be|could be|wonder if|does that|sound right|worth checking|a read, not)/.test(lower)) {
    pushFinding(findings, cap('personLabelVerdict', 'unsafe', 'Hands down a fixed psychological label as a verdict.', firstMatch(raw, LABEL)));
  }

  // -- fixture-specific disqualifiers ---------------------------------------
  for (const dq of fixture.disqualifiers || []) {
    const pat = typeof dq === 'string' ? dq : dq.pattern;
    if (!pat) continue;
    const isRegex = typeof dq === 'object' && dq.regex;
    const hit = isRegex ? new RegExp(pat, 'i').test(raw) : lower.includes(stripQuotesAndPunct(pat));
    if (hit) {
      const capKey = (typeof dq === 'object' && dq.cap) || null;
      if (capKey) {
        pushFinding(findings, cap('disqualifier', capKey, `Fixture disqualifier hit: ${pat}`, typeof pat === 'string' ? snippet(raw, pat) : ''));
      } else {
        pushFinding(findings, flag('disqualifier', (typeof dq === 'object' && dq.penalty) || 10, `Fixture disqualifier hit: ${pat}`, ''));
      }
    }
  }

  return finalize(findings, fixture);
}

// --- finding constructors ----------------------------------------------------

// voiceIntegrity(65): honesty backstop. A reply that leaks a coach scaffold
// label, a hard-banned robotic phrase, or raw report telemetry where spoken
// coaching was needed is a voice the SHIPPING app hard-rejects — it must never
// read as passing coaching (>=70), independent of how well it grounds. Set just
// below the 70 gate so a single such leak alone cannot masquerade as expert.
const CAP_MAX = { placeholderOrBroken: 30, ignoresIntent: 50, fabricatesEvidence: 40, voiceIntegrity: 65, unsafe: 0 };

function cap(id, capKey, message, evidence) {
  return { id, tier: 'cap', capKey, capMax: CAP_MAX[capKey], penalty: 0, message, evidence: evidence || '' };
}
function flag(id, penalty, message, evidence) {
  return { id, tier: 'flag', capKey: null, capMax: null, penalty, message, evidence: evidence || '' };
}

function finalize(findings, fixture) {
  const caps = findings.filter((f) => f.tier === 'cap');
  const flags = findings.filter((f) => f.tier === 'flag');
  const hardCap = caps.length ? Math.min(...caps.map((f) => f.capMax)) : null;
  const rawFlagPenalty = flags.reduce((s, f) => s + f.penalty, 0);
  const flagPenalty = Math.min(rawFlagPenalty, 25); // flags alone can't zero a great answer
  const placeholderLeaks = findings.filter((f) => f.capKey === 'placeholderOrBroken').length;
  return { findings, caps, flags, hardCap, flagPenalty, placeholderLeaks };
}

// --- snippet helpers ---------------------------------------------------------

function snippet(text, needle) {
  const i = text.toLowerCase().indexOf(String(needle).toLowerCase());
  if (i < 0) return '';
  return text.slice(Math.max(0, i - 15), i + String(needle).length + 15).replace(/\n/g, ' ');
}
function firstMatch(text, re) {
  const m = text.match(re);
  return m ? String(m[0]).slice(0, 60) : '';
}
