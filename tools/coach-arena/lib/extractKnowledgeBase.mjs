// Extracts the REAL coaching knowledge corpus from Swift source so the Arena's
// retrieval can be a faithful port of the shipping BM25 brain instead of
// fixture-authored `coachingExpertise` data (which would be hand-picking the
// "right" card per fixture — overfitting, not retrieval).
//
// Source of truth: Noum/CoachingKnowledgeBase.swift (CoachKnowledgeCard array
// literals). Parsed with a small balanced-paren scanner, not a line regex,
// because field values are free-text Swift string literals that can contain
// commas, colons, and parens of their own.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '..', '..', '..');
const KB_FILE = join(REPO_ROOT, 'Noum', 'CoachingKnowledgeBase.swift');

// Find the span of the balanced-paren block starting at `openIdx` (the index
// of the `(` itself). Returns the index just past the matching `)`.
function matchParen(src, openIdx) {
  let depth = 0;
  for (let i = openIdx; i < src.length; i++) {
    const c = src[i];
    if (c === '"') {
      // skip over a Swift string literal (handles \" escapes)
      i++;
      while (i < src.length && src[i] !== '"') {
        if (src[i] === '\\') i++;
        i++;
      }
      continue;
    }
    if (c === '(') depth++;
    else if (c === ')') {
      depth--;
      if (depth === 0) return i + 1;
    }
  }
  throw new Error('extractKnowledgeBase: unbalanced parens from index ' + openIdx);
}

// Extract a `field: "string literal"` value from a card block, honoring \" escapes.
function stringField(block, field) {
  const m = block.match(new RegExp(`${field}:\\s*"`));
  if (!m) return null;
  let i = m.index + m[0].length;
  let out = '';
  while (i < block.length && block[i] !== '"') {
    if (block[i] === '\\') {
      out += block[i + 1];
      i += 2;
    } else {
      out += block[i];
      i++;
    }
  }
  return out;
}

// Extract a `field: [.a, .b, .c]` enum-case array (voiceAlignment, leverTags).
function enumArrayField(block, field) {
  const m = block.match(new RegExp(`${field}:\\s*\\[([^\\]]*)\\]`));
  if (!m) return [];
  return [...m[1].matchAll(/\.(\w+)/g)].map((x) => x[1]);
}

// Extract a `field: ["a", "b"]` string array (keywords).
function stringArrayField(block, field) {
  const m = block.match(new RegExp(`${field}:\\s*\\[([^\\]]*)\\]`));
  if (!m) return [];
  return [...m[1].matchAll(/"((?:[^"\\]|\\.)*)"/g)].map((x) => x[1].replace(/\\"/g, '"'));
}

// Extract a `field: .caseName` bare enum value (domain, evidenceTier).
function enumField(block, field) {
  const m = block.match(new RegExp(`${field}:\\s*\\.(\\w+)`));
  return m ? m[1] : null;
}

export function extractKnowledgeBase() {
  const src = readFileSync(KB_FILE, 'utf8');
  const cards = [];
  const anchor = 'CoachKnowledgeCard(';
  let idx = src.indexOf(anchor);
  if (idx < 0) throw new Error('extractKnowledgeBase: no CoachKnowledgeCard literals found');
  while (idx >= 0) {
    const openParen = idx + anchor.length - 1;
    const end = matchParen(src, openParen);
    const block = src.slice(openParen, end);
    const id = stringField(block, 'id');
    if (!id) throw new Error('extractKnowledgeBase: card block missing id near index ' + idx);
    cards.push({
      id,
      title: stringField(block, 'title'),
      domain: enumField(block, 'domain'),
      technique: stringField(block, 'technique'),
      why: stringField(block, 'why'),
      howToApply: stringField(block, 'howToApply'),
      successMarker: stringField(block, 'successMarker'),
      whenToUse: stringField(block, 'whenToUse'),
      voiceAlignment: enumArrayField(block, 'voiceAlignment'),
      leverTags: enumArrayField(block, 'leverTags'),
      evidenceTier: enumField(block, 'evidenceTier'),
      keywords: stringArrayField(block, 'keywords'),
    });
    idx = src.indexOf(anchor, end);
  }
  if (cards.length < 40) {
    throw new Error(`extractKnowledgeBase: suspiciously few cards parsed (${cards.length})`);
  }
  return cards;
}

// CLI: print a summary or the full JSON.
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const cards = extractKnowledgeBase();
  if (process.argv[2] === '--json') {
    process.stdout.write(JSON.stringify(cards, null, 2));
  } else {
    console.error(`Extracted ${cards.length} cards.`);
    const byDomain = {};
    for (const c of cards) byDomain[c.domain] = (byDomain[c.domain] || 0) + 1;
    console.error(JSON.stringify(byDomain, null, 2));
    console.error(`Sample: ${JSON.stringify(cards[0], null, 2)}`);
  }
}
