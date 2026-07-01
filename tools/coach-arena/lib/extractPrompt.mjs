// Extracts the REAL Noum coach system prompt from Swift source so the Arena
// measures the shipping instructions, not a paraphrase. When the Swift prompt
// changes, re-running the extractor updates the Arena. This is the tether that
// makes "replay through the real pipeline" honest at the instruction layer.
//
// Source of truth:
//   Noum/CoachContextBuilder.swift  -> systemPrompt(...), coachPersonality(...),
//                                       defaultCoachPersonality, feature-flag rules
//   Noum/AICoachChatService.swift   -> roboticPhrases (hard-banned wording)
//
// Swift multiline-string semantics reproduced: closing-delimiter dedent +
// trailing-backslash line continuation.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { createHash } from 'node:crypto';

const __dirname = dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = join(__dirname, '..', '..', '..');
const CTX_BUILDER = join(REPO_ROOT, 'Noum', 'CoachContextBuilder.swift');
const CHAT_SERVICE = join(REPO_ROOT, 'Noum', 'AICoachChatService.swift');

export const VOICES = [
  'authoritative',
  'warm',
  'concise',
  'persuasive',
  'executive',
  'storytelling',
];

// --- Swift multiline helpers -------------------------------------------------

function dedent(text, indent) {
  const pad = ' '.repeat(indent);
  return text
    .split('\n')
    .map((l) => (l.startsWith(pad) ? l.slice(indent) : l.replace(/^\s+/, '')))
    .join('\n');
}

// A line ending in `\` in a Swift multiline literal escapes the newline: the
// next line is joined with no line break (and no inserted space).
function joinContinuations(text) {
  const lines = text.split('\n');
  let out = '';
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.endsWith('\\')) {
      out += line.slice(0, -1);
    } else {
      out += line + (i < lines.length - 1 ? '\n' : '');
    }
  }
  return out;
}

function swiftMultiline(rawLines, closerIndent) {
  return joinContinuations(dedent(rawLines, closerIndent)).trim();
}

// Capture the body of a triple-quoted block. `startMarker` locates the line
// that opens the literal (contains `"""`). Returns { body, closerIndent }.
function captureBlock(src, startIdx) {
  const openNl = src.indexOf('\n', startIdx);
  const lines = src.slice(openNl + 1).split('\n');
  const body = [];
  for (const line of lines) {
    if (/^\s*"""/.test(line)) {
      const closerIndent = line.match(/^(\s*)/)[1].length;
      return { body: body.join('\n'), closerIndent };
    }
    body.push(line);
  }
  throw new Error('Unterminated Swift multiline literal starting near index ' + startIdx);
}

function blockAfter(src, anchorRegex) {
  const m = src.match(anchorRegex);
  if (!m) throw new Error('extractPrompt: anchor not found: ' + anchorRegex);
  const idx = src.indexOf('"""', m.index);
  if (idx < 0) throw new Error('extractPrompt: no """ after anchor ' + anchorRegex);
  const { body, closerIndent } = captureBlock(src, idx);
  return swiftMultiline(body, closerIndent);
}

// --- Extractors --------------------------------------------------------------

export function extractRoboticPhrases(chatSrc) {
  const m = chatSrc.match(/roboticPhrases\s*=\s*\[/);
  if (!m) throw new Error('extractPrompt: roboticPhrases array not found');
  const start = chatSrc.indexOf('[', m.index);
  const end = chatSrc.indexOf('\n    ]', start);
  const slice = chatSrc.slice(start, end);
  const phrases = [...slice.matchAll(/"((?:[^"\\]|\\.)*)"/g)].map((x) =>
    x[1].replace(/\\"/g, '"'),
  );
  if (phrases.length < 20) {
    throw new Error(`extractPrompt: roboticPhrases too short (${phrases.length})`);
  }
  return phrases;
}

export function extractPersonalities(ctxSrc) {
  const out = {};
  const fnStart = ctxSrc.indexOf('static func coachPersonality(for goal:');
  const fnSrc = ctxSrc.slice(fnStart, ctxSrc.indexOf('\n    }', fnStart));
  const caseRe = /case \.(\w+):/g;
  let cm;
  while ((cm = caseRe.exec(fnSrc))) {
    const voice = cm[1];
    const q = fnSrc.indexOf('"""', cm.index);
    const { body, closerIndent } = captureBlock(fnSrc, q);
    out[voice] = swiftMultiline(body, closerIndent);
  }
  out.default = blockAfter(ctxSrc, /static let defaultCoachPersonality\s*=/);
  for (const v of VOICES) {
    if (!out[v]) throw new Error('extractPrompt: missing personality for ' + v);
  }
  return out;
}

function fileMeta(path, src) {
  return { path: path.replace(REPO_ROOT + '/', ''), sha256: createHash('sha256').update(src).digest('hex').slice(0, 16), bytes: src.length };
}

export function extractAll() {
  const ctxSrc = readFileSync(CTX_BUILDER, 'utf8');
  const chatSrc = readFileSync(CHAT_SERVICE, 'utf8');

  const roboticPhrases = extractRoboticPhrases(chatSrc);
  const personalities = extractPersonalities(ctxSrc);

  // The systemPrompt return literal (with unresolved interpolations).
  const spAnchor = ctxSrc.indexOf('return """', ctxSrc.indexOf('static func systemPrompt('));
  const { body, closerIndent } = captureBlock(ctxSrc, spAnchor);
  const template = swiftMultiline(body, closerIndent);

  // The two feature-flag rule blocks (default ON in production).
  const structuredReplyRule = blockAfter(ctxSrc, /let structuredReplyRule = structuredReplyShapeEnabled \?/);
  const judgmentLayerRule = blockAfter(ctxSrc, /let judgmentLayerRule = judgmentLayerRuleEnabled \?/);

  return {
    template,
    personalities,
    structuredReplyRule,
    judgmentLayerRule,
    roboticPhrases,
    provenance: [fileMeta(CTX_BUILDER, ctxSrc), fileMeta(CHAT_SERVICE, chatSrc)],
  };
}

// Resolve the `\(...)` interpolations for a given voice.
export function composeSystemPrompt(
  voice = null,
  opts = {},
  extracted = null,
) {
  const ex = extracted || extractAll();
  const { structuredReplyShapeEnabled = true, judgmentLayerRuleEnabled = true } = opts;
  const personality = (voice && ex.personalities[voice]) || ex.personalities.default;

  let out = ex.template;
  out = out.replace('\\(personality)', personality);
  out = out.replace('\\(structuredReplyRule)', structuredReplyShapeEnabled ? ex.structuredReplyRule : '');
  out = out.replace('\\(judgmentLayerRule)', judgmentLayerRuleEnabled ? ex.judgmentLayerRule : '');

  // Robotic-phrase interpolation blob -> the joined quoted list.
  const blobStart = out.indexOf('\\(AICoachChatService.roboticPhrases');
  if (blobStart >= 0) {
    const endMarker = '.joined(separator: ", "))';
    const blobEnd = out.indexOf(endMarker, blobStart) + endMarker.length;
    const joined = ex.roboticPhrases.map((p) => `"${p}"`).join(', ');
    out = out.slice(0, blobStart) + joined + out.slice(blobEnd);
  }

  // Integrity: the composed prompt must still carry its structural anchors.
  const anchors = [
    'You are Noum',
    'Core voice rules',
    'Human-coach attunement floor',
    'Intelligence floor',
    'never punish-shame',
  ];
  for (const a of anchors) {
    if (!out.includes(a)) {
      throw new Error(`composeSystemPrompt: integrity anchor missing after resolution: "${a}"`);
    }
  }
  if (out.includes('\\(')) {
    const leftover = out.slice(out.indexOf('\\('), out.indexOf('\\(') + 60);
    throw new Error('composeSystemPrompt: unresolved interpolation remains: ' + leftover);
  }
  return out;
}

// CLI: print a summary or a composed prompt.
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const arg = process.argv[2];
  const ex = extractAll();
  if (arg && VOICES.includes(arg)) {
    process.stdout.write(composeSystemPrompt(arg, {}, ex));
  } else if (arg === '--json') {
    const prompts = {};
    for (const v of [...VOICES, null]) prompts[v || 'default'] = composeSystemPrompt(v, {}, ex);
    process.stdout.write(JSON.stringify({ provenance: ex.provenance, roboticPhraseCount: ex.roboticPhrases.length, prompts }, null, 2));
  } else {
    const p = composeSystemPrompt('authoritative', {}, ex);
    console.error(`Extracted OK.`);
    console.error(`  robotic phrases: ${ex.roboticPhrases.length}`);
    console.error(`  personalities:   ${Object.keys(ex.personalities).join(', ')}`);
    console.error(`  composed (authoritative): ${p.length} chars, ${p.split('\n').length} lines`);
    console.error(`  provenance: ${ex.provenance.map((f) => `${f.path}@${f.sha256}`).join(', ')}`);
    console.error(`\nUsage: node lib/extractPrompt.mjs <voice|--json>`);
  }
}
