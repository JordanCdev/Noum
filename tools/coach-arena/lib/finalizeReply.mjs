// JS mirror of the shipping Ask Noum last-mile reply finalizer.
//
// Production commits user-visible coach text through
// AICoachChatService.finalizedCoachReply(...), which first strips model
// scaffold/Markdown residue, then removes bare report-voice telemetry on
// trust-repair and sensitive non-report turns. The Node arena should judge
// that final user-visible text for live/CLI runs. Replay captures, however,
// have stale judge files for their raw replies, so replay mode records this
// delta without applying it to the score.

const SCAFFOLD_LABEL =
  'read|the read|coach read|real read|observation|diagnosis|insight|next move|next rep|move|action|why|evidence|try this|try|focus|target|drill|practice|recommend|recommendation';

const SCAFFOLD_ONLY = new Set([
  'read', 'the read', 'coach read', 'observation', 'diagnosis', 'insight',
  'move', 'next move', 'next rep', 'action', 'why', 'evidence', 'try this',
  'try', 'focus', 'target', 'drill', 'practice', 'recommend',
  'recommendation',
]);

function replaceAll(value, re, replacement) {
  return value.replace(re, replacement);
}

function normalizeDisplayLine(line) {
  let value = line.trim();
  while (value.startsWith('#')) value = value.slice(1).trim();
  while (value.startsWith('>')) value = value.slice(1).trim();
  if (value.startsWith('* ') || value.startsWith('+ ')) {
    value = '- ' + value.slice(2).trim();
  }
  return value;
}

function collapseBlankLines(lines) {
  const output = [];
  let previousBlank = false;
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) {
      if (!previousBlank && output.length) output.push('');
      previousBlank = true;
    } else {
      output.push(trimmed);
      previousBlank = false;
    }
  }
  return output.join('\n').trim();
}

function numberedListPrefix(value) {
  const match = value.match(/^(\d+[.)])\s+(.+)$/);
  if (!match) return null;
  return { prefix: `${match[1]} `, body: match[2].trim() };
}

function isScaffoldOnlyDisplayLine(value) {
  const lower = value.trim().replace(/^[:.]+|[:.]+$/g, '').toLowerCase();
  return SCAFFOLD_ONLY.has(lower);
}

function recapitalizeSentenceStarts(value) {
  return value.replace(/(^|[.!?]\s+)([a-z])/g, (match, prefix, char, offset, full) => {
    const next = full[offset + prefix.length + char.length] || '';
    return `${prefix}${/[A-Z]/.test(next) ? char : char.toUpperCase()}`;
  });
}

function stripCoachLeadIn(value) {
  const stripped = value.replace(new RegExp(`^(${SCAFFOLD_LABEL}):\\s*`, 'i'), '');
  return stripped === value ? value : recapitalizeSentenceStarts(stripped);
}

function stripInlineCoachLeadIns(value) {
  const stripped = value.replace(
    new RegExp(`(^|[.!?]\\s+|[,;]\\s+|\\s+[—-]\\s+)(${SCAFFOLD_LABEL}):\\s*`, 'gi'),
    '$1',
  );
  return stripped === value ? value : recapitalizeSentenceStarts(stripped);
}

export function displayText(raw) {
  let value = String(raw || '').trim();
  if (!value) return '';

  value = replaceAll(value, /\[([^\]\n]+?)\]\([^\)\n]+?\)/g, '$1');
  value = replaceAll(value, /`([^`\n]+?)`/g, '$1');
  value = replaceAll(value, /\*\*([^\n*]+?)\*\*/g, '$1');
  value = replaceAll(value, /__([^\n_]+?)__/g, '$1');
  value = replaceAll(value, /\*([^\n*]+?)\*/g, '$1');
  value = replaceAll(value, /(^|[^A-Za-z0-9])_([^\n_]+?)_(?![A-Za-z0-9])/g, '$1$2');
  value = value.replace(/\*\*|__|`/g, '');

  return value
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .split('\n')
    .map(normalizeDisplayLine)
    .filter(Boolean)
    .join('\n')
    .trim();
}

export function coachReplyText(raw) {
  const display = displayText(raw);
  if (!display) return '';

  const lines = display.split('\n').map((line) => {
    let value = line.trim();
    if (!value) return '';

    let prefix = '';
    const bullet = ['- ', '* ', '+ ', '• '].find((marker) => value.startsWith(marker));
    if (bullet) {
      prefix = bullet;
      value = value.slice(bullet.length).trim();
    } else {
      const list = numberedListPrefix(value);
      if (list) {
        prefix = list.prefix;
        value = list.body;
      }
    }

    value = stripCoachLeadIn(value);
    value = stripInlineCoachLeadIns(value).trim();
    if (!value || isScaffoldOnlyDisplayLine(value)) return '';
    return prefix ? `${prefix}${value}` : value;
  });

  return collapseBlankLines(lines);
}

const REPORT_VOICE_BRIDGE_PATTERNS = [
  /\b(?:your|the)\s+(?:last|latest)\s+rep\s+had\s+\d+\s+fillers?\s*,?\s+so\s+/gi,
  /\byou\s+had\s+\d+\s+fillers?\s*,?\s+so\s+/gi,
  /\bthere\s+(?:was|were)\s+\d+\s+fillers?\s*,?\s+so\s+/gi,
];

const REPORT_VOICE_PHRASE_TRANSLATIONS = [
  [/\b(more than\s+)(?:your|the)?\s*\d+\s+fillers?\s+(?:do|did)\b/gi, '$1the filler words do'],
];

const REPORT_VOICE_MODE_ONLY_PATTERNS = [
  /(^|[.!?]\s+)the signal i can use is\s+(?:timed(?:\s+practice)?|practice|pressure(?:\s+drill)?)\s*[.!?]?\s*/gi,
];

const REPORT_VOICE_PATTERNS = [
  /\b(?:score|scored|scoring|hit)\s+\d{1,3}(?:\.\d)?(?:\s*\/\s*10)?\b/gi,
  /(?:,\s*)?\b\d(?:\.\d)?\s*\/\s*10\s*,\s*\d+\s+fillers?\s*,\s*\d+\s*s(?:ec(?:ond)?s?)?\b/gi,
  /\b\d{2,3}\s*(?:\/|over)\s*\d{2,3}\s*s(?:ec(?:ond)?s?)?\s*(?:\/|with)\s*(?:only\s*)?\d+\s+fillers?\b/gi,
  /\b\d+\s+fillers?\s+(?:in|over|across)\s+\d{2,3}\s*s(?:ec(?:ond)?s?)?\b/gi,
  /\b(?:clean|landed|held)\s+at\s+\d{2,3}\b/gi,
  /\b\d{2,3}\s*(?:words per minute|wpm)\b/gi,
  /\b\d+\s+fillers?\b/gi,
];

export function strippingReportVoiceResidue(text) {
  let value = String(text || '');
  for (const [re, replacement] of REPORT_VOICE_PHRASE_TRANSLATIONS) {
    value = value.replace(re, replacement);
  }
  for (const re of REPORT_VOICE_BRIDGE_PATTERNS) value = value.replace(re, '');
  for (const re of REPORT_VOICE_MODE_ONLY_PATTERNS) value = value.replace(re, '$1');
  for (const re of REPORT_VOICE_PATTERNS) {
    value = value.replace(new RegExp(`${re.source}(?:\\s*[,;—-]\\s*(?:but|and|though|with|only)\\b)?`, 'gi'), '');
  }
  value = value
    .replace(/([.!?]\s+)(?:but|and|so|though)\s+/gi, '$1')
    .replace(/\.\s*\.\s+/g, '. ')
    .replace(/\s*,\s*,/g, ',')
    .replace(/([.!?:])\s*,\s*/g, '$1 ')
    .replace(/(^|[.!?]\s+)—\s+/g, '$1')
    .replace(/\s+—\s+(?=[.!?]|$)/g, ' ')
    .replace(/([:,])\s*(?=[.!?])/g, '')
    .replace(/\s{2,}/g, ' ')
    .replace(/\s+([,.;:!?])/g, '$1');
  return recapitalizeSentenceStarts(value).trim();
}

function normalizedTurnText(text) {
  return String(text || '').toLowerCase().replace(/[^a-z0-9\s]/g, '').replace(/\s+/g, ' ').trim();
}

function wordCount(text) {
  const words = String(text || '').trim().match(/\S+/g);
  return words ? words.length : 0;
}

function turnExplicitlyRequestsMetrics(turn) {
  return /\b(score|rate|rating|number|numbers|metric|metrics|data|stats|statistics|filler rate|how many fillers|how many ums|how many uhs|what'?s my filler|what is my filler|how did i do|how'?d i do|how am i doing|am i improving)\b/i.test(turn || '');
}

function turnLooksLikeVoiceGoalIntent(turn) {
  return /\b(voice|style|sound more|sound less|authoritative|warm|concise|persuasive|executive|storytelling|engaging|set me|switch me|change my goal|pick)\b/i.test(turn || '');
}

function turnLooksLikeGreeting(turn) {
  return ['hi', 'hey', 'hello', 'yo', 'good morning', 'good afternoon', 'good evening', 'im back', 'i am back', 'back again'].includes(normalizedTurnText(turn));
}

function turnLooksLikeLowSignalOffTopicTest(turn) {
  const normalized = normalizedTurnText(turn);
  if (['egg', 'banana', 'asdf', 'test', 'lol', 'huh'].includes(normalized)) return true;
  if (normalized.length > 18 || wordCount(normalized) > 2) return false;
  return !/\b(score|filler|voice|rate|plan|help|practice|interview|meeting|presentation|pitch|better|improve|why|what|how)\b/.test(normalized);
}

function turnLooksEmotionallyVulnerable(turn) {
  return /\b(it'?s not easy|it is not easy|this is hard|that'?s hard|that is hard|i'?m exhausted|im exhausted|i am exhausted|i'?m tired|im tired|i am tired|i feel like a fraud|feel like a fraud|everyone is better|everyone'?s better|i keep freezing|i froze|i panic|i blank|not improving)\b/i.test(turn || '');
}

function turnIsSensitiveNonReportTurn(turn, turnDepth) {
  return turnDepth === 'trustRepair'
    || turnLooksLikeVoiceGoalIntent(turn)
    || turnLooksLikeGreeting(turn)
    || turnLooksLikeLowSignalOffTopicTest(turn)
    || turnLooksEmotionallyVulnerable(turn);
}

function containsCompactMetricCluster(text) {
  return /\b\d(?:\.\d)?\s*\/\s*10\s*,\s*\d+\s+fillers?\s*,\s*\d+\s*s(?:ec(?:ond)?s?)?\b/i.test(text || '');
}

function containsModeOnlyEvidenceSentence(text) {
  return /(^|[.!?]\s+)the signal i can use is\s+(?:timed(?:\s+practice)?|practice|pressure(?:\s+drill)?)\s*[.!?]?/i.test(text || '');
}

export function finalizeReplyForFixture(raw, fixture = {}) {
  const normalized = coachReplyText(raw);
  if (!normalized) {
    return { text: normalized, changed: normalized !== String(raw || '').trim(), changes: ['displaySanitizer'] };
  }

  const lowerTurn = String(fixture.userTurn || '').trim().toLowerCase();
  const depth = fixture.turnDepth || 'groundedRead';
  const sensitive = turnIsSensitiveNonReportTurn(lowerTurn, depth);
  const shouldStripReportVoice = (
    sensitive
    || containsCompactMetricCluster(normalized)
    || containsModeOnlyEvidenceSentence(normalized)
  ) && !turnExplicitlyRequestsMetrics(lowerTurn);

  const stripped = shouldStripReportVoice ? strippingReportVoiceResidue(normalized) : normalized;
  const finalText = stripped || normalized;
  const rawTrimmed = String(raw || '').trim();
  const changes = [];
  if (normalized !== rawTrimmed) changes.push('displaySanitizer');
  if (finalText !== normalized) changes.push('reportVoiceResidue');
  return {
    text: finalText,
    changed: finalText !== rawTrimmed,
    changes,
  };
}
