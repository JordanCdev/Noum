// Faithful JS port of Noum/KnowledgeRetriever.swift's BM25 retrieval + the
// CoachExpertiseFormatter output shape, run over the REAL corpus extracted by
// extractKnowledgeBase.mjs. This lets the Arena exercise the actual retrieval
// mechanism per-fixture (query = the user's turn, gated the same way the app
// gates it) instead of fixture-authored `coachingExpertise` data, which would
// be hand-picking "the right card" per fixture rather than testing retrieval.
//
// Kept in lockstep with the Swift source: same constants, same stopword list,
// same technique/repair-turn signal lists, same tie-break order. If
// KnowledgeRetriever.swift changes, this file must change with it (same
// maintenance contract as extractPrompt.mjs's Swift-source extraction).

import { extractKnowledgeBase } from './extractKnowledgeBase.mjs';

// MARK: Tuning constants (mirror KnowledgeRetriever.swift)
export const BM25_K1 = 1.2;
export const BM25_B = 0.75;
export const LEVER_BOOST = 0.6;
export const VOICE_BOOST = 0.25;
export const LEVER_SEED_SCORE = 0.5;
export const DEFAULT_LIMIT = 2;

const STOPWORDS = new Set([
  'the', 'a', 'an', 'and', 'or', 'but', 'if', 'then', 'of', 'to', 'in',
  'on', 'for', 'with', 'as', 'at', 'by', 'is', 'are', 'was', 'were', 'be',
  'been', 'it', 'its', 'this', 'that', 'these', 'those', 'i', 'you', 'your',
  'my', 'me', 'we', 'us', 'they', 'them', 'he', 'she', 'do', 'does', 'did',
  'can', 'could', 'should', 'would', 'will', 'im', 'ive', 'id', 'so', 'up',
  'out', 'not', 'no', 'yes', 'ok', 'okay', 'get', 'got', 'have', 'has',
]);

function stem(token) {
  if (token.length >= 4 && token.endsWith('s') && !token.endsWith('ss')) {
    return token.slice(0, -1);
  }
  return token;
}

export function tokenize(text) {
  const lowered = String(text || '').toLowerCase();
  const raw = lowered.split(/[^a-z0-9]+/).filter(Boolean);
  return raw.filter((t) => t.length > 1 && !STOPWORDS.has(t)).map(stem);
}

function searchableText(card) {
  return [card.title, card.technique, card.why, card.howToApply, card.whenToUse, card.domain]
    .concat(card.keywords)
    .join(' ');
}

class BM25Index {
  constructor(cards) {
    this.postings = new Map(); // term -> Map(cardId -> tf)
    this.docLengths = new Map(); // cardId -> token count
    this.docFrequency = new Map(); // term -> df
    let totalLength = 0;
    for (const card of cards) {
      const tokens = tokenize(searchableText(card));
      this.docLengths.set(card.id, tokens.length);
      totalLength += tokens.length;
      const termCounts = new Map();
      for (const tok of tokens) termCounts.set(tok, (termCounts.get(tok) || 0) + 1);
      for (const [term, count] of termCounts) {
        if (!this.postings.has(term)) this.postings.set(term, new Map());
        this.postings.get(term).set(card.id, count);
        this.docFrequency.set(term, (this.docFrequency.get(term) || 0) + 1);
      }
    }
    this.documentCount = cards.length;
    this.averageDocLength = cards.length ? totalLength / cards.length : 0;
  }

  bm25(queryTokens, cardId) {
    if (!this.documentCount || !this.averageDocLength) return 0;
    const dl = this.docLengths.get(cardId);
    if (dl === undefined) return 0;
    const n = this.documentCount;
    let score = 0;
    for (const term of new Set(queryTokens)) {
      const df = this.docFrequency.get(term);
      const tf = this.postings.get(term)?.get(cardId);
      if (!df || !tf) continue;
      const idf = Math.max(0, Math.log((n - df + 0.5) / (df + 0.5) + 1));
      const numerator = tf * (BM25_K1 + 1);
      const denominator = tf + BM25_K1 * (1 - BM25_B + (BM25_B * dl) / this.averageDocLength);
      score += idf * (numerator / denominator);
    }
    return score;
  }
}

let CARDS = null;
let INDEX = null;
function corpus() {
  if (!CARDS) {
    CARDS = extractKnowledgeBase();
    INDEX = new BM25Index(CARDS);
  }
  return { cards: CARDS, index: INDEX };
}

// MARK: Technique / repair-turn gates (mirror KnowledgeRetriever.swift verbatim)

const TECHNIQUE_SIGNALS = [
  'how do i', 'how do you', 'how can i', 'how to', 'how should i',
  "what's the best way", 'what is the best way', 'best way to',
  'what should i', 'what do i do', 'help me', 'any advice', 'advice on',
  'tip', 'tips', 'technique', 'get better at', 'improve my', 'improve at',
  'work on my', 'stop saying', 'deal with', 'how do i handle', 'handle a',
  'prepare for', 'preparing for', 'i keep', 'i always', 'i tend to',
  'i struggle', 'struggle with', "i can't stop", 'fix my', 'what can i do',
];

const COACH_REPAIR_SUBJECT_SIGNALS = [
  'this ', 'that ', 'it ', 'your answer', 'your reply',
  'your response', 'the answer', 'the reply', 'the response',
  'responses feel', 'reply feels', 'answer feels', 'noum', 'coach',
];

const COACH_REPAIR_QUALITY_SIGNALS = [
  'robotic', 'generic ai', 'generic tips', 'cold', 'overexplained',
  'over-explained', 'not human', 'low eq', 'not high eq',
  'too much writing', 'too long', 'less text', 'less writing',
  "doesn't feel", 'does not feel', 'nowhere near', 'no where near',
];

const COACH_FORMATTING_REPAIR_SIGNALS = [
  '**', 'markdown', 'tts', 'read them out', 'read aloud',
  "don't format", 'do not format', 'symbols',
];

export function isCoachRepairTurn(query) {
  const lower = String(query || '').toLowerCase();
  if (!lower) return false;
  if (COACH_FORMATTING_REPAIR_SIGNALS.some((s) => lower.includes(s))) return true;
  if (!COACH_REPAIR_SUBJECT_SIGNALS.some((s) => lower.includes(s))) return false;
  return COACH_REPAIR_QUALITY_SIGNALS.some((s) => lower.includes(s));
}

export function isTechniqueSeekingTurn(query) {
  const lower = String(query || '').toLowerCase();
  if (!lower) return false;
  if (isCoachRepairTurn(lower)) return false;
  return TECHNIQUE_SIGNALS.some((s) => lower.includes(s));
}

// MARK: Retrieval (mirrors KnowledgeRetriever.retrieve)

/**
 * @param {object} opts
 * @param {string} opts.query - the user's latest turn.
 * @param {string|null} opts.lever - a SkillArea raw value, or null.
 * @param {string|null} opts.voice - a SpeakingStyleGoal raw value, or null.
 * @param {boolean} opts.hasDiagnosis - whether the user has an established case.
 * @param {number} [opts.limit]
 * @returns {object[]} cards, highest relevance first.
 */
export function retrieve({ query, lever = null, voice = null, hasDiagnosis = false, limit = DEFAULT_LIMIT }) {
  const trimmed = String(query || '').trim();
  if (isCoachRepairTurn(trimmed)) return [];

  const techniqueTurn = isTechniqueSeekingTurn(trimmed);
  if (!techniqueTurn && !hasDiagnosis) return [];

  const { cards, index } = corpus();
  const queryTokens = tokenize(trimmed);
  const queryTokenSet = new Set(queryTokens);

  const scored = [];
  for (const card of cards) {
    let base = index.bm25(queryTokens, card.id);
    const leverMatch = lever ? card.leverTags.includes(lever) : false;
    if (base === 0 && leverMatch && hasDiagnosis) base = LEVER_SEED_SCORE;
    if (base <= 0) continue;

    // Precision gate (mirrors KnowledgeRetriever.swift): admit only on a
    // curated-keyword hit or the lever-seed path. See the Swift comment for
    // why unrestricted prose BM25 is too noisy for short conversational
    // queries.
    const keywordTokens = new Set(card.keywords.flatMap(tokenize));
    const keywordMatch = [...keywordTokens].some((t) => queryTokenSet.has(t));
    if (!keywordMatch && !(leverMatch && hasDiagnosis)) continue;

    const voiceMatch = voice ? card.voiceAlignment.length > 0 && card.voiceAlignment.includes(voice) : false;
    const multiplier = 1.0 + (leverMatch ? LEVER_BOOST : 0) + (voiceMatch ? VOICE_BOOST : 0);
    scored.push({ card, score: base * multiplier });
  }

  scored.sort((a, b) => (b.score !== a.score ? b.score - a.score : a.card.id < b.card.id ? -1 : 1));
  return scored.slice(0, Math.max(0, limit)).map((s) => s.card);
}

// MARK: Formatter (mirrors CoachExpertiseFormatter)

const SOFTENING_QUALIFIER = {
  empirical: '',
  practitioner: 'established coaching practice',
  folk: "rule of thumb — offer it, don't assert it",
};

export const EXPERTISE_HEADER =
  "COACHING EXPERTISE (curated technique to ground THIS turn's move — apply it to the user's own data above; it is craft reference, never a reading of the user)";

export function formatCardLine(card) {
  const qualifier = SOFTENING_QUALIFIER[card.evidenceTier] || '';
  const suffix = qualifier ? ` [${qualifier}]` : '';
  return `- ${card.title} (${card.technique}): ${card.why}. Apply it: ${card.howToApply}. Working when: ${card.successMarker}.${suffix}`;
}

export function expertiseContextLines(cards) {
  if (!cards.length) return [];
  return [EXPERTISE_HEADER, ...cards.map(formatCardLine)];
}
