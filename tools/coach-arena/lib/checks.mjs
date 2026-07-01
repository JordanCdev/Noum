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

import { composeSystemPrompt } from './extractPrompt.mjs';

let ROBOTIC = null;
export function roboticPhrases() {
  if (!ROBOTIC) {
    // Pull the live banned list out of the composed prompt's own listing so
    // the checker and the shipped prompt can never drift.
    const prompt = composeSystemPrompt('authoritative');
    const m = prompt.match(/Hard-banned wording[^:]*:\s*([\s\S]*?)\.\s*\n/);
    ROBOTIC = m
      ? [...m[1].matchAll(/"([^"]+)"/g)].map((x) => x[1].toLowerCase())
      : [];
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

// --- length limits by turn depth (approximates Swift replyLengthLimits) ------

const LENGTH_LIMITS = {
  greeting: { words: 45, lines: 3, sentences: 4, chars: 320 },
  preference: { words: 45, lines: 3, sentences: 4, chars: 320 },
  offTopic: { words: 55, lines: 3, sentences: 4, chars: 360 },
  groundedRead: { words: 90, lines: 5, sentences: 7, chars: 640 },
  trustRepair: { words: 110, lines: 6, sentences: 8, chars: 760 },
  deepAssessment: { words: 170, lines: 11, sentences: 13, chars: 1200 },
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
    pushFinding(findings, flag('roboticPhrase', 12, `Hard-banned robotic phrase: "${hitBanned}"`, snippet(raw, hitBanned)));
  }
  if (raw.includes('!')) {
    pushFinding(findings, flag('exclamation', 6, 'Exclamation mark (banned by core voice rules).', snippet(raw, '!')));
  }
  // -- scaffold labels ------------------------------------------------------
  const SCAFFOLD = /(?:^|\n|[.!?]\s+|—\s+|-\s+)\s*(Read|Move|Target|Next rep|Evidence|Why|Verdict|Diagnosis|Action)\s*:/;
  if (SCAFFOLD.test(raw)) {
    pushFinding(findings, flag('scaffoldLabel', 8, 'Exposed coach scaffold label (Read:/Move:/Target:...).', firstMatch(raw, SCAFFOLD)));
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
  for (const re of metricClaims) {
    let mm;
    while ((mm = re.exec(raw))) {
      const n = mm[1];
      if (!nums.has(n)) {
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

const CAP_MAX = { placeholderOrBroken: 30, ignoresIntent: 50, fabricatesEvidence: 40, unsafe: 0 };

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
