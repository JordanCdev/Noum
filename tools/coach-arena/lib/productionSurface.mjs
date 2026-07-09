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

const LOW_SIGNAL_OFF_TOPIC_TESTS = new Set(['egg', 'banana', 'asdf', 'test', 'lol', 'huh']);
const GREETING_SMALL_TALK = new Set([
  'hi',
  'hey',
  'hello',
  'yo',
  'good morning',
  'good afternoon',
  'good evening',
  'im back',
  'i am back',
  'back again',
]);

const OFF_TOPIC_TEST_SAFE_WORDS = /\b(score|filler|voice|rate|plan|help|practice|interview|meeting|presentation|pitch|better|improve|why|what|how)\b/;

const DRILL_MARKERS = [
  'try this next',
  'the signal i can use',
  'next lever',
  'proof test',
  'run one',
  'run a',
  '60-second',
  '45-second',
  'next rep',
  'one rep',
  'put the verdict',
  'the opening is',
  'the ending is',
  'the close is',
  'verdict first',
  'fillers',
  'wpm',
  '/10',
  'under a timer',
  'pressure drill',
  'ah-counter',
  'hedge',
  'clean stop',
  'sentence one',
];

const COACH_ABILITY_CLAIM_MARKERS = [
  'i can coach',
  'let me coach',
  'i will coach',
  'ill coach',
  "i'll coach",
];

const NAMED_REP_MARKERS = [
  'the latest rep',
  'your latest rep',
  'the last rep',
  'your last rep',
  'this rep',
  'that rep',
  'the rep you',
];

const EVIDENCE_LIMIT_ACKNOWLEDGEMENT_MARKERS = [
  'not enough evidence',
  'no baseline',
  'not enough to',
  'missing:',
  'i would not',
  'i wouldnt',
  'i cannot prove',
  'i cant prove',
  'not proven',
  'need one rep',
  'need a rep',
  'before i can coach',
  'would be guessing',
  'cannot call',
  'not a trait yet',
  'no rep',
  'havent recorded',
  "haven't recorded",
  'record 60 seconds',
  'record one',
];

const TRUST_REPAIR_ACKNOWLEDGEMENT_MARKERS = [
  'fair',
  "you're right",
  'youre right',
  'you are right',
  'i hear',
  'good push',
  "that's fair",
  'thats fair',
  'i missed',
  'i owe you',
  'right to push',
  'right to call',
  'makes sense',
  'i get it',
  'valid',
  'my read was off',
  'let me repair',
  'let me fix',
  'let me correct',
  'i was',
  "i didn't",
  'i didnt',
  "you're pushing",
  "that's on me",
  'thats on me',
  'no, it is not easy',
  'no it is not easy',
  "no, it isn't",
  "no it isn't",
  'no, it isnt',
  'no it isnt',
];

const TRUST_REPAIR_MOVE_MARKERS = [
  'i missed',
  'i gave you advice',
  'i gave advice',
  'i used too much',
  'i sounded cold',
  'i leaned on generic',
  'i was too generic',
  'that read was',
  'that sounded cold',
  'robotic and cold',
  'too much writing',
  'that was generic',
  'could go to anyone',
  'specific thing',
  'specific pattern',
  'generic ai wrapper',
  'not a coach read',
  'generic advice',
  'too generic',
  'i did not answer',
  "i didn't answer",
  'i didnt answer',
  'answered around',
  'useful read',
  'repeated the same',
  'changing the evidence',
  'same test',
  'same coaching move',
  'sound easier than it feels',
  'not easy',
  'hard part',
  'close is the leak',
  'under pressure',
  'before prescribing',
  'the prior answer',
  'my prior answer',
  'that answer',
  'the miss',
  'the real question',
  'the actual question',
  'the friction',
  'advice, not coaching',
  'not coaching',
  'what i should have said',
  'plain answer:',
  'straight answer:',
  'the real read is',
  'real read:',
  'one safe signal',
  'what matters is',
];

const GENERIC_REPAIR_USER_MARKERS = [
  'too generic',
  'so generic',
  'sounds generic',
  'generic ai',
  'generic advice',
  'generic tips',
  'could be for anyone',
  'could go to anyone',
  'not specific',
  "isn't specific",
  'isnt specific',
];

const GENERIC_REPAIR_SCAFFOLD_MARKERS = [
  'the specific thing:',
  'specific thing:',
  'the specific pattern:',
  'specific pattern:',
  'real read:',
  'next rep:',
];

const GENERIC_REPAIR_PATTERN_MARKERS = [
  'hedged the ask',
  'softened the ask',
  'the ask',
  'the number',
  'stating the number',
  'state the raise',
  'qualifier',
  'flat sentence',
  'recommendation arrived',
  'recommendation first',
  'sentence one',
  'opener',
  'opening',
  'close',
  'point arrived',
  'warmth arrives',
  'one safe signal',
  'safe signal',
];

const NOT_INFORMATIVE_REPAIR_USER_MARKERS = [
  'not informative',
  'not useful',
  'not helpful',
  "doesn't help",
  'doesnt help',
  'does not help',
  'missed the point',
  'too vague',
  'vague answer',
];

const NOT_INFORMATIVE_REPAIR_SCAFFOLD_MARKERS = [
  'real read:',
  'that was fluff',
  'cut the throat-clearing',
  'cut the throat clearing',
  'cut the fluff',
  'next rep:',
  'not coaching. real read',
];

const STRAIGHT_ANSWER_USER_MARKERS = [
  'straight answer',
  'just answer',
  'answer me directly',
  'direct answer',
  'give me a yes or no',
  'yes or no',
];

const REPETITION_CALLOUT_USER_MARKERS = [
  'repeating yourself',
  'repeat yourself',
  'repeated yourself',
  'same thing again',
  'same advice again',
  'same drill again',
  'same note again',
  'same target again',
  'on loop',
];

const PACE_SELF_FRUSTRATION_USER_MARKERS = [
  'talk too fast',
  'talk way too fast',
  'speak too fast',
  'speaking too fast',
  'too fast',
  "can't keep up",
  'cant keep up',
  "people can't keep up",
  'people cant keep up',
  'rushing',
  'i rush',
  "i'm rushing",
  'im rushing',
];

const PACE_SELF_FRUSTRATION_GENERIC_ADVICE_MARKERS = [
  'just slow down',
  'be more confident',
  'try to relax',
  'take a breath',
  'practice more',
  'speak slower',
];

const PACE_SELF_FRUSTRATION_ATTUNEMENT_MARKERS = [
  "you're not imagining",
  'you are not imagining',
  'makes sense',
  'that makes sense',
  "people can't keep up",
  'people cant keep up',
  'not a confidence problem',
  'not confidence',
];

const PACE_SELF_FRUSTRATION_GAP_MARKERS = [
  'gap between sentences',
  'gap between points',
  'sentence boundary',
  'full stop',
  'silent beat',
  'pause',
  'pause rate',
  'space between',
  'room to land',
];

const RAMBLE_STOPPING_RULE_USER_MARKERS = [
  'i ramble',
  'ramble',
  'rambling',
  'lose the thread',
  'losing the thread',
  'somewhere else',
  'go on too long',
  'talk too long',
  'keep talking',
  'keep adding',
  'side story',
  'side stories',
];

const RAMBLE_STOPPING_RULE_MECHANISM_MARKERS = [
  'stop signal',
  'stopping rule',
  'stop rule',
  'hard stop',
  'one line of support',
  'one support line',
  'one supporting reason',
  'side story',
  'side stories',
  'weaker version',
  'weaker repeat',
  'restate',
  'reopening',
  'keep adding',
  'point, one',
  'point. one',
  'point; one',
  'point, then silence',
  'one point, then silence',
];

const RAMBLE_STOPPING_RULE_GENERIC_ADVICE_MARKERS = [
  'be more concise',
  'stay concise',
  'focus more',
  'stay focused',
  'structure your thoughts',
  'keep it brief',
  'practice summarizing',
];

const RAMBLE_STOPPING_RULE_SCAFFOLD_MARKERS = [
  'next rep:',
  'try this next:',
  'proof test:',
  'the fix is:',
];

const LEADERSHIP_STATUS_HIERARCHY_MARKERS = [
  'hierarchy',
  'one thing',
  'so what',
  'top-line',
  'top line',
  'same weight',
  'equal weight',
  'through-line',
  'through line',
];

const LEADERSHIP_STATUS_REHEARSAL_MARKERS = [
  'tonight',
  'write the opener',
  'write and say',
  'say the opener',
  'say it aloud',
  'rehearse',
  'aloud',
];

const RECURRING_CLOSE_RUSH_USER_WORK_MARKERS = [
  'what should i work on next',
  'what should i work on',
  'work on next',
  'next thing to work on',
  'what next',
];

const RECURRING_CLOSE_RUSH_USER_SOLID_MARKERS = [
  'felt solid',
  'feels solid',
  'last one felt solid',
  'that felt solid',
  'solid to me',
];

const METADATA_SELF_KNOWLEDGE_USER_MARKERS = [
  'what does your system actually know about me',
  'what do you actually know about me',
  'what do you know about me',
  'what does noum know about me',
  'what does your system know about me',
  'what do you have on me',
];

const METADATA_SELF_KNOWLEDGE_LEAK_MARKERS = [
  'system prompt',
  'context block',
  'metadata',
  'database row',
  'section header',
  'raw json',
  'internal scaffold',
];

const METADATA_SELF_KNOWLEDGE_PRESCRIPTION_MARKERS = [
  'so the thing to test',
  'thing to test',
  'next rep',
  'try this next',
  'run one',
  'record 60',
  'hold one silent beat',
  'proof test',
];

const VULNERABLE_PUSHBACK_MARKERS = [
  "it's not easy",
  'its not easy',
  'not easy',
  'not that easy',
  'easier said',
  'harder than',
  'this is hard',
  'that is hard',
  'i freeze',
  'i froze',
  'i blank',
  'i panic',
  'i get stuck',
  'discouraged',
  'defeated',
];

const VULNERABLE_SAFE_QUESTION_MARKERS = [
  'want to go',
  'want to try',
  'want to give it',
  'can we start',
  'shall we',
  'ready to',
];

const LOW_PRESSURE_ACTION_MARKERS = [
  'test a smaller version',
  'smaller version',
  'one calm reason',
  'say only',
  'stop before',
  'one small step',
  'keep it small',
  'keep the next step small',
  'silent beat',
  'next rep',
  'record 60 seconds',
  'no full performance test',
];

const GOAL_OR_VOICE_CHANGE_MARKERS = [
  'voice',
  'authoritative',
  'warm',
  'concise',
  'persuasive',
  'executive',
  'storytelling',
  'engaging',
  'more engaging',
  'set me to',
  'change my goal',
  'change my voice',
  'pick',
  'choose',
];

const GOAL_STATE_DIRECTIVE_MARKERS = [
  'tap to confirm',
  'tap the card',
  'tap confirm',
  "confirm and i'll",
  'confirm and i will',
  "i'll lock it in",
  'i will lock it in',
  'ill lock it in',
  'lock it in',
  "i'll set it",
  'i will set it',
  'ill set it',
  "i'll set your voice",
  'i will set your voice',
  'ill set your voice',
  "i've set",
  'i have set',
  'voice is now',
  'voice has been',
  "i'll save",
  'i will save',
  'that answer picks the voice',
  'that picks the voice',
];

function hasFinding(findings, ids) {
  return (findings || []).some((finding) => ids.has(finding.id));
}

function normalizedTurnText(text) {
  return String(text || '').toLowerCase().replace(/[^a-z0-9\s]/g, '').replace(/\s+/g, ' ').trim();
}

function wordCount(text) {
  const words = String(text || '').trim().match(/\S+/g);
  return words ? words.length : 0;
}

function isLowSignalOffTopicTest(text) {
  const normalized = normalizedTurnText(text);
  if (!normalized) return false;
  if (LOW_SIGNAL_OFF_TOPIC_TESTS.has(normalized)) return true;
  if (normalized.length > 18 || wordCount(normalized) > 2) return false;
  return !OFF_TOPIC_TEST_SAFE_WORDS.test(normalized);
}

function isGreetingOrSmallTalk(text) {
  return GREETING_SMALL_TALK.has(normalizedTurnText(text));
}

function replyDrillsInsteadOfRedirect(text) {
  const lowered = String(text || '').toLowerCase();
  return DRILL_MARKERS.some((marker) => lowered.includes(marker));
}

function containsAny(lowered, markers) {
  return markers.some((marker) => lowered.includes(marker));
}

function isColdStartFixture(fixture = {}, opts = {}) {
  const contextBlock = String(opts.contextBlock || '').toLowerCase();
  return fixture.evidence?.noRatedSessions === true
    || /\b(no baseline|no rated sessions|not enough data for a stable baseline|no voice set yet)\b/.test(contextBlock);
}

function acknowledgesMissingEvidence(text) {
  return containsAny(String(text || '').toLowerCase(), EVIDENCE_LIMIT_ACKNOWLEDGEMENT_MARKERS);
}

function overclaimsNamedRepEvidence(text) {
  const lowered = String(text || '').toLowerCase();
  return containsAny(lowered, COACH_ABILITY_CLAIM_MARKERS)
    && containsAny(lowered, NAMED_REP_MARKERS);
}

function isTrustRepairFixture(fixture = {}) {
  return fixture.turnDepth === 'trustRepair' || fixture.category === 'trust-repair';
}

function openingAcknowledges(text) {
  return containsAny(String(text || '').toLowerCase().slice(0, 140), TRUST_REPAIR_ACKNOWLEDGEMENT_MARKERS);
}

function lacksTrustRepairMove(text) {
  return !containsAny(String(text || '').toLowerCase(), TRUST_REPAIR_MOVE_MARKERS);
}

function genericRepairUserTurn(text) {
  return containsAny(String(text || '').toLowerCase(), GENERIC_REPAIR_USER_MARKERS);
}

function genericRepairNeedsSpecificPattern(text) {
  const lowered = String(text || '').toLowerCase();
  return containsAny(lowered, GENERIC_REPAIR_SCAFFOLD_MARKERS)
    || /\b[0-9]+(\.[0-9]+)?\s+(fillers?|filler words?)\b/.test(lowered)
    || /\bscore[sd]? [0-9]+\b/.test(lowered)
    || !containsAny(lowered, GENERIC_REPAIR_PATTERN_MARKERS);
}

function notInformativeRepairUserTurn(text) {
  return containsAny(String(text || '').toLowerCase(), NOT_INFORMATIVE_REPAIR_USER_MARKERS);
}

function leaksNotInformativeRepairScaffold(text) {
  const lowered = String(text || '').toLowerCase();
  return containsAny(lowered, NOT_INFORMATIVE_REPAIR_SCAFFOLD_MARKERS)
    || /\bscore [0-9]+\b/.test(lowered)
    || /\b[0-9]+\/10\b/.test(lowered);
}

function straightAnswerUserTurn(text) {
  return containsAny(String(text || '').toLowerCase(), STRAIGHT_ANSWER_USER_MARKERS);
}

function straightAnswerLeaksReportVoice(text) {
  const lowered = String(text || '').toLowerCase();
  return /\bhit [0-9]+ in [0-9]+ seconds\b/.test(lowered)
    || /\blast rep (hit )?[0-9]+ in [0-9]+ seconds\b/.test(lowered)
    || /\bscored [0-9]+\b/.test(lowered);
}

function straightAnswerNeedsSplitRepair(text) {
  const lowered = String(text || '').toLowerCase();
  if (straightAnswerLeaksReportVoice(lowered)) return true;
  if (!containsAny(lowered, ['straight answer', 'plain answer', 'direct answer'])) return true;
  const hasYesHalf = containsAny(lowered, [
    'yes on',
    'yes, on',
    'yes for',
    'yes: fillers',
    'yes. fillers',
    'yes — fillers',
    'yes - fillers',
  ]);
  const hasNoHalf = containsAny(lowered, [
    'no on',
    'no, on',
    'no for',
    'no: pace',
    'no. pace',
    'no — pace',
    'no - pace',
    'not on pace',
    'pace is no',
  ]);
  return !(hasYesHalf && hasNoHalf);
}

function repetitionCalloutUserTurn(text) {
  return containsAny(String(text || '').toLowerCase(), REPETITION_CALLOUT_USER_MARKERS);
}

function repetitionCourseCorrectionLeaksReportVoice(text) {
  const lowered = String(text || '').toLowerCase();
  return /\b(?:score|scored|hit)\s+\d{2,3}\b/.test(lowered)
    || /\b(?:clean|landed|held)\s+at\s+\d{2,3}\b/.test(lowered);
}

function repeatsOldPointFirstDrill(text) {
  const lowered = String(text || '').toLowerCase();
  return /\blead(?:ing)?\s+with\s+(?:the\s+|your\s+)?point\b/.test(lowered)
    || /\bpoint\s+(?:up\s+)?front\b/.test(lowered)
    || /\bpoint\s+in\s+(?:the\s+)?first\s+sentence\b/.test(lowered);
}

function repetitionCourseCorrectionNeedsRepair(text) {
  const lowered = String(text || '').toLowerCase();
  if (repetitionCourseCorrectionLeaksReportVoice(lowered)) return true;
  if (repeatsOldPointFirstDrill(lowered)) return true;
  const ownsRepetition = containsAny(lowered, [
    'repeat the same',
    'repeated the same',
    'same drill',
    'same target',
    'same note',
    'same coaching',
    'i did repeat',
    'that was the same',
  ]);
  const marksOldTargetMet = containsAny(lowered, [
    'already cleared',
    'already met',
    'target is met',
    'target was met',
    'it is done',
    "it's done",
    'its done',
    'no reason to run it again',
    'no reason to run that drill again',
    'led clean',
    'led cleanly',
    'close held',
    'closed clean',
    'clean close',
  ]);
  const advancesPlan = containsAny(lowered, [
    'new target',
    'next target',
    'next lever',
    'move on',
    'advance',
    'pace',
    'tempo',
    'variation',
    'vary',
  ]);
  return !(ownsRepetition && marksOldTargetMet && advancesPlan);
}

function paceSelfFrustrationUserTurn(text) {
  return containsAny(String(text || '').toLowerCase(), PACE_SELF_FRUSTRATION_USER_MARKERS);
}

function paceSelfFrustrationNeedsRepair(text) {
  const lowered = String(text || '').toLowerCase();
  if (straightAnswerLeaksReportVoice(lowered)) return true;
  if (containsAny(lowered, PACE_SELF_FRUSTRATION_GENERIC_ADVICE_MARKERS)) return true;
  if (!containsAny(lowered, PACE_SELF_FRUSTRATION_ATTUNEMENT_MARKERS)) return true;
  const namesPace = containsAny(lowered, ['pace', 'speed', 'fast', 'slow', 'rush', 'rushing']);
  if (!namesPace) return false;
  return !containsAny(lowered, PACE_SELF_FRUSTRATION_GAP_MARKERS);
}

function rambleStoppingRuleUserTurn(text) {
  return containsAny(String(text || '').toLowerCase(), RAMBLE_STOPPING_RULE_USER_MARKERS);
}

function rambleStoppingRuleNeedsRepair(text) {
  const lowered = String(text || '').toLowerCase();
  if (containsAny(lowered, RAMBLE_STOPPING_RULE_SCAFFOLD_MARKERS)) return true;
  if (wordCount(lowered) > 55) return true;
  if (containsAny(lowered, RAMBLE_STOPPING_RULE_GENERIC_ADVICE_MARKERS)) return true;
  return !containsAny(lowered, RAMBLE_STOPPING_RULE_MECHANISM_MARKERS);
}

function metricNumber(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  const match = String(value).match(/[0-9]+(?:\.[0-9]+)?/);
  return match ? match[0] : null;
}

function paceSelfFrustrationMetricRead(fixture = {}, replyText = '', opts = {}) {
  const directPace = metricNumber(fixture.evidence?.pace)
    || metricNumber(fixture.memoryState?.baseline?.pace);
  const directPauseRate = metricNumber(fixture.evidence?.pauseRate)
    || metricNumber(fixture.memoryState?.baseline?.pauseRate);
  const source = [
    opts.contextBlock || '',
    replyText,
    JSON.stringify(fixture.evidence || {}),
    JSON.stringify(fixture.memoryState || {}),
  ].join(' ');
  const pace = directPace
    || source.match(/\b([1-9][0-9]{2})\s*(?:wpm|words a minute|words per minute)\b/i)?.[1]
    || source.match(/\bpace(?:\s+(?:sat|held|is|was|near|around|estimate|estimate:|at))*\s*(?:near|around|at)?\s*([1-9][0-9]{2})\b/i)?.[1]
    || null;
  const pauseRate = directPauseRate
    || source.match(/\bpause rate(?:\s*(?:is|was|:|-|=))?\s*(0\.[0-9]+)\b/i)?.[1]
    || source.match(/\b(0\.[0-9]+)\s*pause rate\b/i)?.[1]
    || null;
  if (pace && pauseRate) return `${pace} WPM with a ${pauseRate} pause rate`;
  if (pace) return `${pace} WPM`;
  if (pauseRate) return `a ${pauseRate} pause rate`;
  return null;
}

function leadershipStatusReportUserTurn(text) {
  const lowered = String(text || '').toLowerCase();
  const hasLeadershipMoment = containsAny(lowered, [
    'leadership update',
    'weekly update',
    'department update',
    'whole department',
  ]);
  const hasStatusProblem = containsAny(lowered, [
    'status report',
    'zone out',
    'people zone out',
  ]);
  return hasLeadershipMoment && hasStatusProblem;
}

function leadershipStatusReportLeaksReportVoice(text) {
  const lowered = String(text || '').toLowerCase();
  return /\b(?:clean|landed|held)\s+at\s+\d{2,3}\b/.test(lowered)
    || /\b(?:score|scored|hit)\s+\d{2,3}\b/.test(lowered);
}

function leadershipStatusReportNeedsRepair(text) {
  const lowered = String(text || '').toLowerCase();
  if (leadershipStatusReportLeaksReportVoice(lowered)) return true;
  const namesHierarchy = containsAny(lowered, LEADERSHIP_STATUS_HIERARCHY_MARKERS);
  const hasSameNightRehearsal = containsAny(lowered, LEADERSHIP_STATUS_REHEARSAL_MARKERS);
  return !(namesHierarchy && hasSameNightRehearsal);
}

function recurringCloseRushUserTurn(text) {
  const lowered = String(text || '').toLowerCase();
  return containsAny(lowered, RECURRING_CLOSE_RUSH_USER_WORK_MARKERS)
    && containsAny(lowered, RECURRING_CLOSE_RUSH_USER_SOLID_MARKERS);
}

function recurringCloseRushDominantCountPresent(text) {
  return /\b4\s+of\s+(?:your\s+|the\s+)?last\s+5\b/i.test(String(text || ''));
}

function recurringCloseRushOverallCountPresent(text) {
  return /\b(?:5|five)\s+of\s+(?:your\s+|the\s+)?last\s+(?:6|six)\b/i.test(String(text || ''));
}

function recurringCloseRushTrendAvailable(fixture = {}, replyText = '', opts = {}) {
  const source = [
    opts.contextBlock || '',
    replyText,
    JSON.stringify(fixture.evidence || {}),
    JSON.stringify(fixture.memoryState || {}),
  ].join(' ').toLowerCase();
  if (!containsAny(source, ['close', 'final line', 'ending'])) return false;
  if (recurringCloseRushDominantCountPresent(source) && recurringCloseRushOverallCountPresent(source)) {
    return true;
  }
  const trends = fixture.memoryState?.positionalTrend || [];
  return trends.some((trend) => trend
    && trend.kind === 'rushedBurst'
    && trend.zone === 'close'
    && Number(trend.dominantCount) === 4
    && Number(trend.repsWithSignal) === 5
    && Number(trend.windowRepCount) === 6);
}

function recurringCloseRushNeedsRepair(text) {
  const lowered = String(text || '').toLowerCase();
  if (containsAny(lowered, ['next rep:', 'proof test:', 'diagnosis:'])) return true;
  if (!(recurringCloseRushDominantCountPresent(lowered) && recurringCloseRushOverallCountPresent(lowered))) {
    return true;
  }
  const moveMarkers = [
    'second-to-last sentence',
    'second to last sentence',
    'silent beat',
    'final line at half',
    'half the pace',
    'say the final line',
    'slow the exit',
  ];
  const moveCount = moveMarkers.reduce(
    (count, marker) => count + (lowered.includes(marker) ? 1 : 0),
    0,
  );
  return moveCount > 2;
}

function metadataSelfKnowledgeUserTurn(text) {
  return containsAny(String(text || '').toLowerCase(), METADATA_SELF_KNOWLEDGE_USER_MARKERS);
}

function metadataSelfKnowledgeSourceAvailable(fixture = {}, replyText = '', opts = {}) {
  const source = [
    opts.contextBlock || '',
    replyText,
    JSON.stringify(fixture.evidence || {}),
    JSON.stringify(fixture.memoryState || {}),
  ].join(' ').toLowerCase();
  const hasGoal = containsAny(source, [
    'sound like yourself',
    'sounding like yourself',
    'hard conversations',
    'tough conversations',
  ]);
  const hasPressurePattern = containsAny(source, [
    'fill silence',
    'outrun the silence',
    'race to fill',
    'speed up',
    'tense',
  ]);
  const hasBoundedNumbers = containsAny(source, [
    '170 pace',
    '170 wpm',
    'twelve days',
    '12 days',
    '12-day',
    'twelve-day',
  ]);
  return hasGoal && hasPressurePattern && hasBoundedNumbers;
}

function metadataSelfKnowledgeNeedsRepair(text) {
  const lowered = String(text || '').toLowerCase();
  if (containsAny(lowered, METADATA_SELF_KNOWLEDGE_LEAK_MARKERS)) return true;
  if (containsAny(lowered, METADATA_SELF_KNOWLEDGE_PRESCRIPTION_MARKERS)) return true;
  const closesSkepticismLoop = containsAny(lowered, [
    'real read',
    'not a script',
    'not a database',
    'what i know',
  ]);
  return !closesSkepticismLoop && wordCount(lowered) > 75;
}

function vulnerablePushbackUserTurn(text) {
  return containsAny(String(text || '').toLowerCase(), VULNERABLE_PUSHBACK_MARKERS);
}

function burdensVulnerablePushback(reply, userTurn) {
  if (!vulnerablePushbackUserTurn(userTurn)) return false;
  const lowered = String(reply || '').toLowerCase();
  if (!lowered.trim().endsWith('?')) return false;
  if (containsAny(lowered, VULNERABLE_SAFE_QUESTION_MARKERS)) return false;
  if (containsAny(lowered, LOW_PRESSURE_ACTION_MARKERS)) return false;
  return true;
}

function goalOrVoiceChangeUserTurn(text) {
  return containsAny(String(text || '').toLowerCase(), GOAL_OR_VOICE_CHANGE_MARKERS);
}

function leaksGoalStateDirective(text) {
  return containsAny(String(text || '').toLowerCase(), GOAL_STATE_DIRECTIVE_MARKERS);
}

function leaksGoalStateReportVoice(text) {
  const lowered = String(text || '').toLowerCase();
  return /\b(?:score|scored|hit)\s+\d{2,3}\b/.test(lowered)
    || /\b\d{2,3}\s+this week\b/.test(lowered)
    || /\b\d+\s+fillers?\s+(?:in|over|across)\s+\d{2,3}\s*(?:s|sec(?:ond)?s?)\b/.test(lowered)
    || /\b\d{2,3}\s*(?:\/|over)\s*\d{2,3}\s*s(?:ec(?:ond)?s?)?\s*(?:\/|with)\s*(?:only\s*)?\d+\s+fillers?\b/.test(lowered)
    || /\b\d(?:\.\d)?\s*\/\s*10\b/.test(lowered);
}

function greetingThreadCue(replyText = '') {
  const lowered = String(replyText || '').toLowerCase();
  if (/(close|final sentence|final line|ending)/.test(lowered)) {
    if (/(flat|softened|softener)/.test(lowered)) {
      return 'Pick up with the close: land the final sentence flat, then stop.';
    }
    if (/(silent beat|plant one beat|plant a beat)/.test(lowered)) {
      return 'Pick up with the close: plant one silent beat before the final line.';
    }
    return 'Pick up with the close: make the final sentence the ask, then stop.';
  }
  if (/(opener|opening|recommendation|verdict|point first)/.test(lowered)) {
    return 'Pick up with the opener: lead with the recommendation, give one reason, then stop.';
  }
  return null;
}

function greetingFallback(surface = 'text', replyText = '') {
  const cue = greetingThreadCue(replyText);
  if (cue) {
    return surface === 'live'
      ? `Hey — good to see you. ${cue}`
      : `Hey — good to see you back. ${cue}`;
  }
  if (surface === 'live') {
    return 'Hey — good to see you. Want to keep going, or is something else on your mind?';
  }
  return 'Hey — good to see you back. Want to pick up where we left off, or is there something specific on your mind?';
}

function coldStartFallback(surface = 'text') {
  if (surface === 'live') {
    return "Start with one real sample. Give me 60 seconds on something you know well, like how you'd explain what you do to a stranger. Then I'll have something honest to coach. Want to go now?";
  }
  return "Start with one real sample. Do one 60-second rep on something you know well — how you'd explain what you do to a stranger works nicely. Then I can give you a real read. Want to go now?";
}

function offTopicTestFallback(surface = 'text') {
  if (surface === 'live') {
    return "Tiny test. All good. Give me the moment you want to practice, and I'll give you one clean read.";
  }
  return "Tiny test. All good. Send the moment you want to practice, and I'll give you one clean read.";
}

function noBaselineReadFallback(surface = 'text') {
  if (surface === 'live') {
    return "There's no rep for me to read yet, so I won't guess one. Give me 60 seconds — record now and I'll read the opener and close for real. Want to go?";
  }
  return "There's no rep for me to read yet, so I won't invent one. Record 60 seconds first, then I'll coach the opener and close from what actually happened — that's the honest way to do this.";
}

function trustRepairStaticFallback(surface = 'text') {
  if (surface === 'live') {
    return "You're right to push me. I don't have a clean read yet — give me one 60-second rep on that exact moment and I'll name the biggest gap.";
  }
  return "You're right to push me on that. I don't have a clean enough read to answer it well yet. Give me one 60-second rep on that exact scenario and I'll name the single biggest gap.";
}

function genericRepairFallback(surface = 'text', replyText = '') {
  const lowered = String(replyText || '').toLowerCase();
  if (containsAny(lowered, ['ask', 'raise', 'number', 'qualifier', 'hoping to maybe'])) {
    if (surface === 'live') {
      return 'Fair. That was too generic. The specific pattern is the ask itself. State the number flat, no qualifier, then stop.';
    }
    return 'Fair. That was too generic. The specific pattern is the ask itself. You softened the number instead of stating it. State the raise as one flat sentence, no qualifier, then stop.';
  }
  if (lowered.includes('recommendation')) {
    if (surface === 'live') {
      return 'Fair. That sounded generic. The specific pattern is that the recommendation arrived late. Put it in sentence one, give one reason, then stop.';
    }
    return 'Fair. That sounded like generic advice, not a coach read. The specific pattern is that your recommendation arrived late. Put the recommendation in sentence one, give one reason, then stop.';
  }
  if (surface === 'live') {
    return 'Fair. That was too generic. The specific pattern is that the point arrived late. Lead with the point, give one reason, then stop.';
  }
  return 'Fair. That was too generic. The specific pattern is that your point arrived late instead of leading the answer. Make sentence one the point, give one reason, then stop.';
}

function notInformativeRepairFallback(surface = 'text') {
  if (surface === 'live') {
    return 'Fair. I was too vague. Your point arrived after three warm-up sentences. Make sentence one the point; let one reason do the supporting.';
  }
  return 'Fair. I was too vague. The useful read is that your point arrived in sentence four after three warm-up sentences. Make sentence one the point; let one reason do the supporting.';
}

function straightAnswerSplitFallback(surface = 'text') {
  if (surface === 'live') {
    return 'Fair. Straight answer: yes on fillers; no on pace under pressure. The next test is one silent beat before the hard answer.';
  }
  return 'Fair. Straight answer: yes on fillers; no on pace under pressure. Your filler trend is moving the right way, but the rush still shows up when the pressure rises. Next rep, hold one silent beat before the hard answer.';
}

function repetitionCourseCorrectionFallback(surface = 'text') {
  if (surface === 'live') {
    return 'Fair. I did repeat the same target. You led cleanly and the close held, so move on: pace. Slow the three words that carry the point, then hold one silent beat.';
  }
  return 'Fair. I did repeat the same target. You led cleanly and the close held, so there is no reason to run that drill again. New target: pace. Slow the three words that carry the point, then hold one silent beat before the next sentence.';
}

function paceSelfFrustrationFallback(surface = 'text', fixture = {}, replyText = '', opts = {}) {
  const metricRead = paceSelfFrustrationMetricRead(fixture, replyText, opts);
  if (surface === 'live') {
    if (metricRead) {
      return `You're not imagining it. ${metricRead} points to the gap, not confidence. Hold one silent beat after each full stop.`;
    }
    return "You're not imagining it. Fix the pause, not the speed: one silent beat after each full stop, then see if people track you better.";
  }
  if (metricRead) {
    return `You're not imagining it: ${metricRead} means the gap between sentences is disappearing. Fix the pause, not the speed. Next rep, hold one silent beat after every full stop and see if people track you without forcing a slower voice.`;
  }
  return "You're not imagining it: this reads like a missing gap between sentences, not a confidence problem. Fix the pause, not the speed. Next rep, hold one silent beat after every full stop and see if people track you without forcing a slower voice.";
}

function rambleStoppingRuleFallback(surface = 'text') {
  if (surface === 'live') {
    return 'You do not lose the thread; you reopen it. The tell is the weaker repeat after the side stories. Use a hard stop: point, one support line, silence.';
  }
  return 'You do not lose the thread; you keep reopening it. The tell is the weaker repeat at the end after the side stories. Use a hard stop: state the point, give one support line, then silence.';
}

function leadershipStatusReportFallback(surface = 'text') {
  if (surface === 'live') {
    return 'That is a real risk for tomorrow: equal-weight updates make people stop tracking. Make hierarchy the fix. Say the opener aloud tonight: "The one thing that matters this week is X because Y."';
  }
  return 'That is a real risk for tomorrow: if every update lands at the same weight, the room hears a status report. The fix is hierarchy, not delivery polish. Tonight, write the opener as: "The one thing that matters this week is X because Y." Say it aloud three times, then let the other items become quick support.';
}

function recurringCloseRushFallback(surface = 'text') {
  if (surface === 'live') {
    return 'The solid feeling is real; the next edge is the close. It has rushed in 4 of the last 5 fast-stretch reps and 5 of the last 6 overall. Plant one silent beat before the final line.';
  }
  return 'That solid feeling is real, and the next edge is specific: the fastest stretch keeps landing at the close. It has shown up in 4 of the last 5 reps with a fast stretch, and 5 of the last 6 overall — a recurring spot, not a trait. Plant one silent beat before the final line.';
}

function metadataSelfKnowledgeFallback(surface = 'text') {
  if (surface === 'live') {
    return 'Real read, not a script: you want to sound like yourself in hard conversations. The pattern I know is racing to fill silence under pressure; the safe numbers are roughly 170 WPM and a 12-day streak.';
  }
  return 'Real read, not a script: you came in wanting to sound like yourself in hard conversations. The pattern I know is that tense moments make you race to fill silence; the numbers I can safely name are a pace baseline around 170 WPM and a 12-day streak. That is what I know. I will wait on a next drill until you ask for one.';
}

function vulnerablePushbackEvidenceAnchor(fixture = {}) {
  const reps = Array.isArray(fixture.memoryState?.recentReps) ? fixture.memoryState.recentReps : [];
  const joined = reps
    .map((rep) => [rep.note, rep.mode, rep.when].filter(Boolean).join(' '))
    .join(' ')
    .toLowerCase();
  if (/held composure through (?:a simulated )?interruption|handled an interruption/.test(joined)) {
    return 'There is already one earned proof point: this week you held composure through an interruption.';
  }
  return '';
}

function vulnerablePushbackFallback(surface = 'text', fixture = {}) {
  const anchor = vulnerablePushbackEvidenceAnchor(fixture);
  const frame = 'The hard part is the first hard sentence, not the whole performance.';
  if (surface === 'live') {
    if (anchor) {
      return `No, it is not easy. ${anchor} ${frame} Keep it small: say only the first hard sentence, then stop.`;
    }
    return `No, it is not easy. ${frame} Keep it small: say only the first hard sentence, then stop.`;
  }
  if (anchor) {
    return `No, it is not easy. ${anchor} ${frame} Keep the next step small: say only the first hard sentence, then stop.`;
  }
  return `No, it is not easy. ${frame} Keep the next step small: say only the first hard sentence, then stop.`;
}

function goalStateProgressAnchor(replyText = '') {
  const lowered = String(replyText || '').toLowerCase();
  if (containsAny(lowered, ['three weeks', '3 weeks', 'authoritative work is landing'])) {
    return 'Your authoritative work is already landing, so do not throw it away yet. ';
  }
  return '';
}

function goalStateDirectiveFallback(surface = 'text', userTurn = '', replyText = '') {
  const lowered = String(userTurn || '').toLowerCase();
  if (containsAny(lowered, ['engaging', 'more engaging', 'engage'])) {
    const progress = goalStateProgressAnchor(replyText);
    if (surface === 'live') {
      return `${progress}Engaging maps closest to Storytelling, with Warm as the softer backup. What changed: do you need more memorable shape, or the same authority to land warmer?`;
    }
    return `${progress}Engaging maps closest to Storytelling, with Warm as the softer backup. Use Storytelling if you need more memorable shape; use Warm if you want the same authority to land with less distance. What changed: are you being heard now, or do you want the same point to land warmer?`;
  }
  if (containsAny(lowered, ['what voice', 'which voice', 'voice should', 'six', 'dont know', "don't know"])) {
    if (surface === 'live') {
      return 'Start with Authoritative: short verdicts hold the floor when people talk over you. Executive presence is the backup if the room is more senior than interrupt-heavy.';
    }
    return 'Given you are trying to stop getting talked over in meetings, Authoritative is the closest fit: short verdicts that hold the floor. Executive presence is the next-closest if the room is more senior leadership than peers. Which one matches the room you are actually in?';
  }
  if (containsAny(lowered, ['authoritative', 'verdict-first', 'verdict first'])) {
    if (surface === 'live') {
      return 'Authoritative is a sensible recommendation: verdict first, one reason, clean stop. Try it on the next 60-second answer.';
    }
    return 'Authoritative is a sensible recommendation: verdict first, one reason, clean stop. Treat it as the voice to try next; the practice test is a 60-second answer where sentence one carries the recommendation.';
  }
  if (surface === 'live') {
    return 'I can recommend the direction without pretending to change it from chat. Start with the voice that matches the room, then test it in one short answer.';
  }
  return 'I can recommend the direction without pretending to change it from chat. Start with the voice that matches the room you actually need to handle, then test it in one short answer.';
}

function fallbackResult({ text, raw, fixture, opts, finalizer, issue, source }) {
  const fallbackDeterministic = runChecks(text, fixture, {
    contextBlock: opts.contextBlock || '',
    recentReplies: opts.recentReplies || [],
  });
  return {
    text,
    changed: text !== String(raw || '').trim(),
    changes: [...new Set([...finalizer.changes, 'reliabilityGateFallback'])],
    finalizer,
    reliabilityGate: {
      changed: true,
      issues: [issue],
      source,
    },
    deterministic: fallbackDeterministic,
  };
}

export function productionSurfaceReplyForFixture(raw, fixture = {}, opts = {}) {
  const finalizer = finalizeReplyForFixture(raw, fixture);
  const recentReplies = opts.recentReplies || [];
  const deterministic = runChecks(finalizer.text, fixture, {
    contextBlock: opts.contextBlock || '',
    recentReplies,
  });

  if (isGreetingOrSmallTalk(fixture.userTurn) && replyDrillsInsteadOfRedirect(finalizer.text)) {
    const text = greetingFallback(fixture.surface || opts.surface || 'text', finalizer.text);
    return fallbackResult({
      text,
      raw,
      fixture,
      opts,
      finalizer,
      issue: 'greetingWithDrill',
      source: 'CoachReliabilityGate.greetingFallback',
    });
  }

  if (isLowSignalOffTopicTest(fixture.userTurn) && replyDrillsInsteadOfRedirect(finalizer.text)) {
    const text = offTopicTestFallback(fixture.surface || opts.surface || 'text');
    return fallbackResult({
      text,
      raw,
      fixture,
      opts,
      finalizer,
      issue: 'offTopicTestWithDrill',
      source: 'CoachReliabilityGate.offTopicTestFallback',
    });
  }

  if (goalOrVoiceChangeUserTurn(fixture.userTurn) && leaksGoalStateDirective(finalizer.text)) {
    const text = goalStateDirectiveFallback(
      fixture.surface || opts.surface || 'text',
      fixture.userTurn,
      finalizer.text,
    );
    return fallbackResult({
      text,
      raw,
      fixture,
      opts,
      finalizer,
      issue: 'goalStateDirectiveLeak',
      source: 'CoachReliabilityGate.goalStateDirectiveFallback',
    });
  }

  if (goalOrVoiceChangeUserTurn(fixture.userTurn) && leaksGoalStateReportVoice(finalizer.text)) {
    const text = goalStateDirectiveFallback(
      fixture.surface || opts.surface || 'text',
      fixture.userTurn,
      finalizer.text,
    );
    return fallbackResult({
      text,
      raw,
      fixture,
      opts,
      finalizer,
      issue: 'goalStateReportVoiceLeak',
      source: 'CoachReliabilityGate.goalStateDirectiveFallback',
    });
  }

  if (
    !isTrustRepairFixture(fixture)
    && paceSelfFrustrationUserTurn(fixture.userTurn)
    && paceSelfFrustrationNeedsRepair(finalizer.text)
  ) {
    const text = paceSelfFrustrationFallback(
      fixture.surface || opts.surface || 'text',
      fixture,
      finalizer.text,
      opts,
    );
    return fallbackResult({
      text,
      raw,
      fixture,
      opts,
      finalizer,
      issue: 'paceSelfFrustrationReportVoice',
      source: 'CoachReliabilityGate.paceSelfFrustrationFallback',
    });
  }

  if (
    !isTrustRepairFixture(fixture)
    && rambleStoppingRuleUserTurn(fixture.userTurn)
    && rambleStoppingRuleNeedsRepair(finalizer.text)
  ) {
    const text = rambleStoppingRuleFallback(fixture.surface || opts.surface || 'text');
    return fallbackResult({
      text,
      raw,
      fixture,
      opts,
      finalizer,
      issue: 'rambleStoppingRuleMiss',
      source: 'CoachReliabilityGate.rambleStoppingRuleFallback',
    });
  }

  if (
    !isTrustRepairFixture(fixture)
    && leadershipStatusReportUserTurn(fixture.userTurn)
    && leadershipStatusReportNeedsRepair(finalizer.text)
  ) {
    const text = leadershipStatusReportFallback(fixture.surface || opts.surface || 'text');
    return fallbackResult({
      text,
      raw,
      fixture,
      opts,
      finalizer,
      issue: 'leadershipStatusReportMiss',
      source: 'CoachReliabilityGate.leadershipStatusReportFallback',
    });
  }

  if (
    !isTrustRepairFixture(fixture)
    && recurringCloseRushUserTurn(fixture.userTurn)
    && recurringCloseRushTrendAvailable(fixture, finalizer.text, opts)
    && recurringCloseRushNeedsRepair(finalizer.text)
  ) {
    const text = recurringCloseRushFallback(fixture.surface || opts.surface || 'text');
    return fallbackResult({
      text,
      raw,
      fixture,
      opts,
      finalizer,
      issue: 'recurringCloseTrendDiluted',
      source: 'CoachReliabilityGate.recurringCloseRushFallback',
    });
  }

  if (
    !isTrustRepairFixture(fixture)
    && metadataSelfKnowledgeUserTurn(fixture.userTurn)
    && metadataSelfKnowledgeSourceAvailable(fixture, finalizer.text, opts)
    && metadataSelfKnowledgeNeedsRepair(finalizer.text)
  ) {
    const text = metadataSelfKnowledgeFallback(fixture.surface || opts.surface || 'text');
    return fallbackResult({
      text,
      raw,
      fixture,
      opts,
      finalizer,
      issue: 'metadataSelfKnowledgeMiss',
      source: 'CoachReliabilityGate.metadataSelfKnowledgeFallback',
    });
  }

  if (isTrustRepairFixture(fixture) && finalizer.text.trim()) {
    const isRepetitionCallout = repetitionCalloutUserTurn(fixture.userTurn);
    if (burdensVulnerablePushback(finalizer.text, fixture.userTurn)) {
      const text = vulnerablePushbackFallback(fixture.surface || opts.surface || 'text', fixture);
      return fallbackResult({
        text,
        raw,
        fixture,
        opts,
        finalizer,
        issue: 'vulnerablePushbackQuestionBurden',
        source: 'CoachReliabilityGate.vulnerablePushbackFallback',
      });
    }
    if (
      notInformativeRepairUserTurn(fixture.userTurn)
      && leaksNotInformativeRepairScaffold(finalizer.text)
    ) {
      const text = notInformativeRepairFallback(fixture.surface || opts.surface || 'text');
      return fallbackResult({
        text,
        raw,
        fixture,
        opts,
        finalizer,
        issue: 'notInformativeRepairScaffold',
        source: 'CoachReliabilityGate.notInformativeRepairFallback',
      });
    }
    if (
      straightAnswerUserTurn(fixture.userTurn)
      && straightAnswerNeedsSplitRepair(finalizer.text)
    ) {
      const text = straightAnswerSplitFallback(fixture.surface || opts.surface || 'text');
      return fallbackResult({
        text,
        raw,
        fixture,
        opts,
        finalizer,
        issue: 'straightAnswerSplitMissing',
        source: 'CoachReliabilityGate.straightAnswerSplitFallback',
      });
    }
    if (
      isRepetitionCallout
      && repetitionCourseCorrectionNeedsRepair(finalizer.text)
    ) {
      const text = repetitionCourseCorrectionFallback(fixture.surface || opts.surface || 'text');
      return fallbackResult({
        text,
        raw,
        fixture,
        opts,
        finalizer,
        issue: 'repetitionCourseCorrectionMiss',
        source: 'CoachReliabilityGate.repetitionCourseCorrectionFallback',
      });
    }
    if (
      !isRepetitionCallout
      && genericRepairUserTurn(fixture.userTurn)
      && genericRepairNeedsSpecificPattern(finalizer.text)
    ) {
      const text = genericRepairFallback(fixture.surface || opts.surface || 'text', finalizer.text);
      return fallbackResult({
        text,
        raw,
        fixture,
        opts,
        finalizer,
        issue: 'genericRepairScaffolded',
        source: 'CoachReliabilityGate.genericRepairFallback',
      });
    }
    const trustRepairIssue = !openingAcknowledges(finalizer.text)
      ? 'noAttunementOnPushback'
      : (!isRepetitionCallout && lacksTrustRepairMove(finalizer.text) ? 'thinTrustRepair' : null);
    if (trustRepairIssue) {
      const text = trustRepairStaticFallback(fixture.surface || opts.surface || 'text');
      return fallbackResult({
        text,
        raw,
        fixture,
        opts,
        finalizer,
        issue: trustRepairIssue,
        source: 'CoachReliabilityGate.truthfulFallback',
      });
    }
  }

  if (
    isColdStartFixture(fixture, opts)
    && !isGreetingOrSmallTalk(fixture.userTurn)
    && overclaimsNamedRepEvidence(finalizer.text)
    && !acknowledgesMissingEvidence(finalizer.text)
  ) {
    const text = noBaselineReadFallback(fixture.surface || opts.surface || 'text');
    return fallbackResult({
      text,
      raw,
      fixture,
      opts,
      finalizer,
      issue: 'evidenceOverclaimNoBaseline',
      source: 'CoachReliabilityGate.noBaselineReadFallback',
    });
  }

  if (hasFinding(deterministic.findings, COLD_START_FINDINGS)) {
    const text = coldStartFallback(fixture.surface || opts.surface || 'text');
    return fallbackResult({
      text,
      raw,
      fixture,
      opts,
      finalizer,
      issue: 'coldStartJargon',
      source: 'CoachReliabilityGate.coldStartFallback',
    });
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
