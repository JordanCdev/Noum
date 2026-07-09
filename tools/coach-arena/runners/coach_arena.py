#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ARENA = ROOT / "tools" / "coach-arena"
DEFAULT_FIXTURES = ARENA / "fixtures" / "gold.json"
DEFAULT_REPORTS = ARENA / "reports"
DEFAULT_SYNTHETIC = ARENA / "synthetic"
CANONICAL_APP_PATH_REPORTS = DEFAULT_REPORTS / "app-path"
DUPLICATE_APP_PATH_REPORTS = ARENA / "tools" / "coach-arena" / "reports" / "app-path"
SOURCE_GIT_COMMIT_SIDECAR = "source-git-commit.txt"
SOURCE_FINGERPRINT_SIDECAR = "source-coach-fingerprint.txt"
APP_PATH_DUMP_NAME = "coach-chat-conversation-app-path-eval-v1.json"

DIMENSION_MAX = {
    "diagnosticIQ": 25,
    "eqAttunement": 25,
    "personalMemory": 20,
    "interventionQuality": 15,
    "dialogueFeel": 15
}

THRESHOLDS = {
    "goldSuiteAverage": 70,
    "deepAssessmentAverage": 70,
    "trustRepairAverage": 65,
    "placeholderLeaks": 0
}
APP_PATH_LOCAL_FIXTURE_FLOOR = 70

FIXTURE_DISQUALIFIER_CAP = 60
TRACE_FIELDS = [
    "context", "retrieval", "memory", "reasoning", "prompt", "provider",
    "rawReply", "finalReply", "issues", "latency", "cache", "fallback",
    "versions", "gitCommit"
]
REAL_PIPELINE_TRACE_SOURCES = {"appPathReport", "replayCommand"}
COACH_SOURCE_STATUS_PATHS = [
    "Noum/AICoachChatService.swift",
    "Noum/AskNoumStore.swift",
    "Noum/CoachAssessment.swift",
    "Noum/CoachAssessmentCache.swift",
    "Noum/CoachContextBuilder.swift",
    "Noum/CoachPromptBundle.swift",
    "Noum/CoachReasoningPass.swift",
    "Noum/CoachReplyPipeline.swift",
    "Noum/CoachReliabilityGate.swift",
    "Noum/CoachTurnDepth.swift",
    "Noum/CoachingKnowledgeBase.swift",
    "Noum/GoalRubric.swift",
    "Noum/GoalRubricStore.swift",
    "Noum/KnowledgeRetriever.swift",
    "Noum/KnowledgeSemanticReranker.swift",
    "Noum/PrimaryFocusMemory.swift",
    "Noum/TurnDepthClassifier.swift",
    "Noum/UserTrajectoryCache.swift",
    "Noum/UserTrajectorySnapshot.swift",
    "NoumTests/CoachBrainRerankTests.swift",
    "NoumTests/CoachBrainTests.swift",
    "NoumTests/CoachChatEvaluationFixtures.swift",
    "NoumTests/CoachChatConversationEvaluationTests.swift",
    "NoumTests/CoachProviderChainTests.swift",
    "NoumTests/CoachReadCalibrationBaselineTests.swift",
    "NoumTests/CoachLiveEvaluationTests.swift",
    "NoumTests/CoachJudgementLayerTests.swift",
    "NoumTests/CoachPlaceholderLeakStripTests.swift",
    "NoumTests/CoachReportVoiceRegenerationProofTests.swift",
    "NoumTests/CoachReliabilityGateTests.swift",
    "NoumTests/GoalRubricVoiceRoutingTests.swift",
    "NoumTests/NoumTests.swift",
]

APP_PATH_ALIASES = {
    "authoritative-distance-001": ("authoritative-distance-deep-assessment-conversation", 0),
    "not-informative-trust-repair-002": ("not-informative-trust-repair-conversation", 0),
    "polite-however-pushback-003": ("polite-however-arena-repair-conversation", 0),
    "not-easy-empathy-004": ("not-easy-empathy-conversation", 0),
    "repeating-yourself-005": ("repeating-yourself-trust-repair-conversation", 0),
    "interview-prep-006": ("cold-start-interview-baseline-conversation", 0),
    "filler-pressure-007": ("filler-pressure-prescription-conversation", 0),
    "leadership-update-008": ("leadership-transfer-setup-conversation", 0),
    "confidence-ending-009": ("confidence-ending-softener-conversation", 0),
    "examples-from-sessions-010": ("arena-examples-from-sessions-010-app-path-conversation", 0),
    "score-not-readiness-011": ("score-not-readiness-board-conversation", 0),
    "personal-pattern-consent-012": ("personal-pattern-consent-boundary-conversation", 0),
    "reject-hypothesis-013": ("personal-pattern-consent-boundary-conversation", 1),
    "remember-hypothesis-014": ("personal-pattern-consent-boundary-conversation", 2),
    "markdown-tts-015": ("markdown-tts-trust-repair-conversation", 0),
    "cold-generic-016": ("assistant-explainer-register-conversation", 0),
    "too-much-writing-017": ("too-much-writing-short-repair-conversation", 0),
    "no-baseline-interview-018": ("no-baseline-interview-help-conversation", 0),
    "pace-rushing-019": ("pace-rushing-read-conversation", 0),
    "closing-ask-020": ("closing-ask-fix-conversation", 0),
    "opening-verdict-021": ("opening-verdict-stronger-conversation", 0),
    "pause-before-answer-022": ("pause-before-answer-pressure-conversation", 0),
    "concise-answer-023": ("concise-answer-rambling-conversation", 0),
    "structure-one-reason-024": ("structure-one-reason-conversation", 0),
    "confidence-clean-stop-025": ("confidence-clean-stop-conversation", 0),
    "leadership-transfer-capture-026": ("leadership-transfer-setup-conversation", 2),
    "outcome-not-causation-027": ("arena-outcome-not-causation-027-app-path-conversation", 0),
    "upcoming-conflict-028": ("arena-upcoming-conflict-028-app-path-conversation", 0),
    "networking-intro-029": ("arena-networking-intro-029-app-path-conversation", 0),
    "presentation-nerves-030": ("arena-presentation-nerves-030-app-path-conversation", 0),
    "sales-pitch-031": ("arena-sales-pitch-031-app-path-conversation", 0),
    "board-update-032": ("arena-board-update-032-app-path-conversation", 0),
    "overexplaining-033": ("arena-overexplaining-033-app-path-conversation", 0),
    "fear-disagreement-034": ("arena-fear-disagreement-034-app-path-conversation", 0),
    "lack-conviction-035": ("arena-lack-conviction-035-app-path-conversation", 0),
    "emotional-disconnection-036": ("arena-emotional-disconnection-036-app-path-conversation", 0),
    "evasive-polished-037": ("arena-evasive-polished-037-app-path-conversation", 0),
    "timidity-038": ("arena-timidity-038-app-path-conversation", 0),
    "authority-under-pressure-039": ("arena-authority-under-pressure-039-app-path-conversation", 0),
    "semantic-filler-use-040": ("arena-semantic-filler-use-040-app-path-conversation", 0),
    "prompt-echo-041": ("arena-prompt-echo-041-app-path-conversation", 0),
    "no-transcript-fabrication-042": ("arena-no-transcript-fabrication-042-app-path-conversation", 0),
    "quote-guard-043": ("arena-quote-guard-043-app-path-conversation", 0),
    "live-latency-short-044": ("arena-live-latency-short-044-app-path-conversation", 0),
    "barge-in-045": ("arena-barge-in-045-app-path-conversation", 0),
    "weekly-checkin-046": ("arena-weekly-checkin-046-app-path-conversation", 0),
    "real-world-outcome-047": ("arena-real-world-outcome-047-app-path-conversation", 0),
    "grammar-leak-048": ("arena-grammar-leak-048-app-path-conversation", 0),
    "placeholder-leak-049": ("arena-placeholder-leak-049-app-path-conversation", 0),
    "assistant-wrapper-050": ("arena-assistant-wrapper-050-app-path-conversation", 0)
}

APP_PATH_EXCLUDED_FIXTURE_IDS = set()

PLACEHOLDER_PATTERNS = [
    r"\btodo\b", r"\bplaceholder\b", r"\blorem ipsum\b",
    r"generate coach response", r"\{\{", r"\}\}", r"\[insert"
]
RAW_REPORT_VOICE_PATTERNS = [
    r"\b(?:score|scored|hit)\s+(?:\d{2,3}|\d(?:\.\d)?(?:\s*/\s*10)?)\b",
    r"\b\d{2,3}\s*(?:/|over)\s*\d{2,3}\s*s(?:ec(?:ond)?s?)?\s*(?:/|with)\s*(?:only\s*)?\d+\s+fillers?\b",
    r"\b\d+\s+fillers?\s+(?:in|over|across)\s+\d{2,3}\s*(?:s|sec(?:ond)?s?)\b",
    r"\b(?:clean|landed|held)\s+at\s+\d{2,3}\b"
]
METRIC_REQUEST_PATTERNS = [
    r"\b(score|rate|rating|number|numbers|metric|metrics|data|stats|statistics)\b",
    r"\bfiller rate\b",
    r"\bhow many (fillers|ums|uhs)\b",
    r"\bwhat'?s my filler\b",
    r"\bhow did i do\b",
    r"\bhow'?d i do\b",
    r"\bam i improving\b"
]
METADATA_LEAK_PATTERNS = [
    r"\bturnDepth\b", r"\bproviderTier\b", r"\bsemanticGate\b",
    r"\bqualityGate\b", r"\bassessmentConfidence\b", r"\btrajectoryCacheHit\b",
    r"\brawReply\b", r"\bmetadata\b"
]
GRAMMAR_LEAK_PATTERNS = [
    r"^\s*\{.*\}\s*$", r"\*\*", r"^#+\s",
    r"(^|\n)\s*read:\s", r"(^|\n)\s*move:\s", r"(^|\n)\s*target:\s"
]
UNSAFE_PATTERNS = [
    r"\bmental illness\b", r"\bworthless\b",
    r"\bguarantee\b.*\boutcome\b"
]
GENERIC_PATTERNS = [
    "be confident", "communicate clearly", "keep practicing",
    "practice more", "try harder", "be authentic", "know your audience"
]
ACTION_WORDS = [
    "say", "run", "record", "hold", "cut", "use", "answer", "practice",
    "review", "end", "state", "make", "lead", "put", "give", "capture",
    "replace", "repeat", "check", "test", "fix", "keep", "drop", "start",
    "stop", "trust", "mark", "add", "build", "compare", "rehearse", "name"
]
EQ_WORDS = [
    "fair", "push", "hard", "not easy", "trust", "friction", "understand",
    "that was", "good correction", "i should not", "you are asking"
]
EVIDENCE_WORDS = [
    "rep", "transcript", "score", "filler", "wpm", "session", "evidence",
    "signal", "quote", "pressure", "latest", "last", "memory", "hypothesis"
]
BOUNDARY_WORDS = [
    "cannot", "can't", "not enough", "not proven", "missing", "unproven",
    "hypothesis", "ask before", "confirm", "reject", "drop", "boundary",
    "no verified", "no transcript"
]

DISQUALIFIER_BANNED_PATTERNS = {
    "score as readiness": [
        r"\b\d+\s*/\s*10\b.{0,60}\b(ready|readiness|close|authoritative)\b",
        r"\b(ready|readiness|close|authoritative)\b.{0,60}\b\d+\s*/\s*10\b",
        r"\b(score|rating)\b.{0,40}\b(means|proves|shows)\b.{0,40}\b(ready|readiness)\b"
    ],
    "says close overall from one rep": [r"\b(pretty\s+)?close\b(?!\s+mechanically)"],
    "generic confidence tip": [r"\b(confidence|confident)\b.{0,40}\b(keep practicing|practice more|just|simply|tip)\b"],
    "defends app": [r"\b(the app|noum|this app)\b.{0,50}\b(is|was|does|can)\b"],
    "apology wall": [r"\b(sorry|apologize|apologies)\b"],
    "more generic advice": [r"\b(here are|some tips|general advice|communication tips)\b"],
    "treats polite opener as satisfaction": [r"\b(glad|great|good)\b.{0,20}\b(that helps|you liked|cool)\b"],
    "prescribes same drill unchanged": [r"\b(same drill|same exercise|do it again|run it again)\b"],
    "minimizes difficulty": [r"\b(just|simply|all you need|easy|not hard)\b"],
    "motivational platitude": [r"\b(you can do it|believe in yourself|stay positive|keep going)\b"],
    "defends repetition": [r"\brepetition\b.{0,50}\b(helps|is useful|is good|works)\b"],
    "cold-start fabrication": [r"\b(your|the)\b.{0,25}\b(last|latest|previous)\b.{0,25}\b(session|rep|transcript)\b"],
    "broad interview menu": [r"\b(strengths|weaknesses|tell me about yourself|where do you see yourself)\b"],
    "shames fillers": [r"\b(bad|wrong|weak|problem)\b.{0,20}\bfiller"],
    "semantic words treated as fillers": [r"\b(actual words|content words|semantic words)\b.{0,40}\b(filler|fillers)\b"],
    "generic confidence": [r"\b(be|sound|feel)\b.{0,20}\bconfident\b"],
    "generic leadership tips": [r"\bleadership\b.{0,60}\b(confident|clear|communicate|inspire)\b"],
    "personality label": [r"\byou('re| are)\b.{0,30}\b(timid|anxious|avoidant|indecisive|defensive|evasive)\b"],
    "vague confidence advice": [r"\bconfidence\b.{0,50}\b(more|practice|project|show)\b"],
    "fabricated quote": [r"['\"][^'\"]{8,160}['\"]"],
    "over-reassurance": [r"\b(yes|ready|you are ready|good enough|don't worry)\b"],
    "labels the user": [r"\byou('re| are)\b.{0,35}\b(a|an|the kind|someone who|person who)\b"],
    "hidden motive": [r"\b(you are afraid|you avoid|you don't want|deep down|really trying to)\b"],
    "argues with user": [r"\b(no,|you are wrong|that's not true|actually, you)\b"],
    "strengthens unconfirmed label": [r"\bthat proves\b.{0,40}\b(you|your)\b"],
    "persists label as fact": [r"\bremember\b.{0,40}\b(you are|you're|your pattern is)\b"],
    "generic memory": [r"\bi remember\b.{0,50}\b(goal|practice|communication)\b"],
    "markdown markers": [r"\*\*|^#+\s"],
    "assistant apology wall": [r"\bas an ai\b|\bi apologize\b"],
    "generic apology": [r"\b(sorry|apologize|apologies)\b.{0,80}\b(help|try|advice)\b"],
    "same cold register": [r"\b(here are|you should|it is important to)\b"],
    "long answer": [],
    "meta explanation": [r"\bwhat i meant was|the reason for my response|as a model|as an assistant\b"],
    "claims data exists": [r"\b(your|the)\b.{0,30}\b(data|sessions|history|baseline|transcript)\b.{0,30}\b(show|shows|says|indicates)\b"],
    "personality diagnosis": [r"\b(personality|diagnosis|diagnose|you are the kind)\b"],
    "asks only clarifying questions": [r"^\s*(what|which|can you|could you|tell me).*\?\s*$"],
    "generic slow down": [r"\b(slow down|speak slower|take your time)\b"],
    "summary close": [r"\b(summary|summarize|recap)\b.{0,50}\b(close|ending|final)\b"],
    "broad plan": [r"\b(plan|framework|steps)\b.{0,30}\b(first|second|third)\b"],
    "generic hook advice": [r"\b(hook|attention-grabbing|start with a question|story)\b"],
    "just relax": [r"\b(just relax|relax|calm down|take a deep breath)\b"],
    "vague structure": [r"\b(use structure|structure your answer|organize your thoughts)\b"],
    "long framework": [r"\b(first|second|third|fourth)\b"],
    "more reasons": [r"\b(more reasons|add reasons|another reason|several reasons)\b"],
    "generic structure": [r"\b(beginning, middle, and end|introduction, body, conclusion|structured format)\b"],
    "confidence platitude": [r"\b(be confident|sound confident|project confidence)\b"],
    "continues after ask": [r"\b(after the ask|then explain|then add|follow up)\b"],
    "causal proof claim": [r"\b(caused|because of the drill|proved the drill|proof that the drill)\b"],
    "drill caused outcome": [r"\b(drill|practice)\b.{0,40}\b(caused|made|led to|proved)\b"],
    "objective proof": [r"\b(objective proof|proves|proved|guarantees|guaranteed)\b"],
    "dismisses user report": [r"\b(doesn't matter|ignore|just a feeling|only subjective|not useful)\b"],
    "generic conflict advice": [r"\b(use i statements|listen actively|stay calm|find common ground)\b"],
    "authenticity platitude": [r"\b(be authentic|be yourself|show up as yourself)\b"],
    "full life story": [r"\b(life story|background|whole story|everything about)\b"],
    "claims transcript evidence without data": [r"\b(transcript|you said|your words)\b.{0,40}\b(show|shows|prove|proves)\b"],
    "claims prosody without audio": [r"\b(prosody|intonation|pitch|vocal tone|your tone)\b.{0,40}\b(show|shows|sounds|indicates)\b"],
    "generic storytelling": [r"\bstorytelling\b.{0,50}\b(story|connect|emotion|engage)\b"],
    "audience perception as fact": [r"\b(the audience|they|listeners)\b.{0,40}\b(will|would|think|feel|see you as)\b"],
    "metrics equal executive": [r"\b(score|fillers|wpm|metrics)\b.{0,40}\b(executive|authority|ready)\b"],
    "personality cause": [r"\bbecause\b.{0,40}\b(personality|who you are|you tend to)\b"],
    "label as fact": [r"\b(you are|you're|your pattern is)\b.{0,40}\b(fact|clearly|obviously)?\b"],
    "psychological diagnosis": [r"\b(fear of|afraid of|anxiety|insecure|avoidance|defensive)\b"],
    "single-rep certainty": [r"\b(one rep|single rep|this rep)\b.{0,40}\b(proves|shows|means)\b"],
    "trait label": [r"\b(you are|you're)\b.{0,40}\b(timid|weak|unconvincing|evasive|disconnected)\b"],
    "changes whole answer": [r"\brewrite\b.{0,40}\b(whole|entire|everything)\b"],
    "equates polish with quality": [r"\b(polished|smooth|fluent)\b.{0,40}\b(good|quality|strong|ready)\b"],
    "personality judgment": [r"\b(personality|character|who you are)\b"],
    "claims tone without audio": [r"\b(tone|sounds|voice)\b.{0,40}\b(timid|weak|flat|confident)\b"],
    "labels timid": [r"\b(timid|timidity)\b"],
    "generic pressure": [r"\bpressure\b.{0,50}\b(practice|handle|manage|stay calm)\b"],
    "punishes semantic speech": [r"\b(semantic|valid|meaningful)\b.{0,40}\b(filler|bad|cut)\b"],
    "dismisses correction": [r"\b(no,|actually|still)\b.{0,40}\b(filler|wrong|counts)\b"],
    "punishes prompt echo": [r"\b(prompt echo|repeated the prompt)\b.{0,40}\b(bad|filler|mistake)\b"],
    "fake certainty": [r"\b(definitely|clearly|obviously|always)\b"],
    "unverified user speech": [r"\byou said\b.{0,80}['\"]"],
    "pretends transcript exists": [r"\b(transcript|your words|you said)\b.{0,40}\b(show|shows|were)\b"],
    "defends fake quote": [r"\b(the quote|that quote)\b.{0,40}\b(is accurate|still stands|captures)\b"],
    "keeps quote": [r"['\"][^'\"]{8,160}['\"]"],
    "long essay": [],
    "menu": [r"\b(option|options|you could|you can also|alternatively)\b"],
    "slow preamble": [r"\b(before we begin|first, let's|to understand this)\b"],
    "continues old answer": [r"\bas i was saying|to continue|continuing\b"],
    "score-only read": [r"\b(score|rating)\b.{0,50}\b(only|just|tells us everything)\b"],
    "causation claim": [r"\b(caused|because of|led to|made them)\b"],
    "ignores outcome": [r"\bkeep practicing|run another rep\b"],
    "JSON leak": [r"^\s*\{.*\}\s*$"],
    "markdown scaffold": [r"\*\*|^#+\s|(^|\n)\s*(read|move|target):\s"],
    "metadata label": [r"\b(turnDepth|providerTier|semanticGate|metadata|qualityGate)\b"],
    "TODO": [r"\btodo\b"],
    "placeholder": [r"\bplaceholder\b|\{\{|\}\}|\[insert"],
    "fake score=10": [r"\b10\s*/\s*10\b"],
    "empty reply": [r"^\s*$"],
    "as an AI": [r"\bas an ai\b"],
    "generic tips": [r"\b(generic tips|some tips|general advice|be confident|speak clearly)\b"],
    "defensive product language": [r"\b(as an ai|the app|noum can|this tool)\b"]
}

DISQUALIFIER_REQUIRED_GROUPS = {
    "no missing evidence": [["missing", "not proven", "unproven", "no pressure", "not enough"]],
    "no concrete read": [["read", "signal", "evidence", "pattern", "missed"]],
    "ignores however": [["fair", "push", "missed", "question", "underneath", "however"]],
    "no adjusted intervention": [["shrink", "smaller", "lower", "change", "adjust", "one sentence"]],
    "repeats same proof test": [["change", "different", "compare", "new check"]],
    "no changed condition": [["change", "different", "compare", "condition", "check"]],
    "no first rep": [["first", "baseline", "record", "60-second", "diagnostic"]],
    "no transfer target": [["transfer", "real", "moment", "leadership", "close", "ask"]],
    "no observable close": [["close", "final sentence", "last line", "ask", "decision"]],
    "no transcript anchor": [["transcript", "rep", "quote", "latest", "last", "signal", "softener", "recommendation", "close"]],
    "no example": [["example", "said", "quote", "cannot quote", "no verified"]],
    "multiple vague examples": [["one", "single", "specific", "quote"]],
    "no pressure rehearsal": [["pressure", "board-style", "rehearsal", "record", "90 seconds", "75 seconds"]],
    "no consent boundary": [["hypothesis", "confirm", "reject", "consent", "only if", "not a label"]],
    "no drop condition": [["drop", "discard", "reject", "if it does not", "if not"]],
    "no coaching read": [["read", "signal", "evidence", "missed", "actual", "softened", "recommendation", "voice"]],
    "no evidence": [["rep", "transcript", "evidence", "signal", "score", "latest", "last", "warmth", "recommendation"]],
    "no direct move": [["say", "run", "record", "cut", "use", "stop", "ask"]],
    "no metric": [["wpm", "filler", "score", "seconds", "metric", "181"]],
    "no test": [["test", "check", "whether", "proof", "run", "record"]],
    "no hard stop": [["stop", "hard stop", "clean stop"]],
    "no verdict": [["verdict", "recommendation", "sentence one", "point"]],
    "too many options": [["one", "single", "only", "just"]],
    "no pressure cue": [["pressure", "panic", "beat", "first word", "before sentence one"]],
    "no observable test": [["test", "check", "whether", "measure", "observable"]],
    "no stop rule": [["stop", "ceiling", "second reason", "clean stop"]],
    "no implication": [["implication", "so", "therefore", "ask", "direction"]],
    "no hedge target": [["hedge", "softener", "maybe", "just", "qualifier", "ask"]],
    "no audience read": [["audience", "room", "listener", "response", "outcome"]],
    "no close check": [["close", "final", "last", "ask", "decision", "check"]],
    "no rehearsal": [["rehearsal", "record", "run", "practice", "rep"]],
    "too broad": [["one", "single", "narrow", "specific"]],
    "no observable anchor": [["observable", "signal", "sentence", "quote", "rep", "check", "concrete", "example", "claim"]],
    "no decision ask": [["decision", "ask", "alignment"]],
    "no observable cap": [["cap", "ceiling", "stop", "one reason", "two-sentence"]],
    "no user confirmation": [["confirm", "ask", "hypothesis", "not a fact", "reject", "feels accurate", "tell me whether"]],
    "no hedge test": [["hedge", "maybe", "just", "i think", "test", "check"]],
    "no reflection check": [["felt", "feels", "reflection", "check", "ask yourself", "confidence", "compare"]],
    "no challenge": [["challenge", "not enough", "polished", "evasive", "verdict"]],
    "no evidence boundary": [["without audio", "cannot", "not enough", "boundary", "evidence"]],
    "ignores normal-vs-pressure contrast": [["normal", "pressure", "contrast", "holds under"]],
    "no specific target": [["target", "specific", "one", "sentence", "close", "opener"]],
    "no adjusted rule": [["semantic", "valid", "rule", "count", "do not punish"]],
    "no fairness boundary": [["fair", "prompt echo", "not count", "boundary", "valid"]],
    "no correction": [["correct", "correction", "cannot quote", "should not", "retract", "safe read", "supported read"]],
    "ignores barge-in": [["barge", "interrupted", "brief", "you stopped me", "fair"]],
    "no brief repair": [["brief", "short", "fair", "missed", "one"]],
    "no adaptation": [["adapt", "change", "adjust", "next", "because"]],
    "no reusable move": [["reusable", "repeat", "move", "next time", "use"]],
    "no transcript signal": [["transcript", "signal", "recommendation", "late", "latest"]]
}


def now_iso():
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def normalize(text):
    return re.sub(r"\s+", " ", (text or "").lower()).strip()


def normalized_match_key(text):
    folded = (text or "").lower()
    folded = folded.replace("\u2019", "'").replace("\u2018", "'")
    return re.sub(r"[^a-z0-9']+", " ", folded).strip()


def words(text):
    return re.findall(r"[a-z0-9']+", normalize(text))


def content_words(text):
    stop = {
        "the", "a", "an", "and", "or", "to", "of", "in", "it", "is", "that",
        "this", "you", "your", "i", "we", "with", "for", "on", "one", "next",
        "then", "so", "as", "be", "do", "not", "if", "what", "should"
    }
    return [w for w in words(text) if len(w) >= 4 and w not in stop]


def overlap_score(answer, source, cap):
    answer_set = set(content_words(answer))
    source_terms = content_words(source)
    if not source_terms:
        return 0
    hits = sum(1 for term in source_terms if term in answer_set)
    return min(cap, hits)


def semantic_expected_hits(fixture, lower):
    fixture_id = fixture.get("id", "")
    checks_by_id = {
        "not-informative-trust-repair-002": [
            ["missed", "answered around", "advice, not a read"],
            ["useful read", "usable signal", "actual read"],
            ["last rep", "structure signal", "warmth"],
            ["recommendation first", "point in sentence one", "say the recommendation"],
            ["one reassurance", "one reason", "stop"]
        ],
        "polite-however-pushback-003": [
            ["fair push", "fair"],
            ["missed", "generic advice", "not the question", "answered the drill"],
            ["friction", "what you meant", "asking whether", "underneath"],
            ["actual read", "hypothesis", "pattern"],
            ["next rep", "test", "verdict-first", "recommendation first"]
        ],
        "not-easy-empathy-004": [
            ["not easy", "easier than it feels", "hard part"],
            ["pressure", "social risk"],
            ["shrink", "lower", "one sentence", "smallest"],
            ["target", "verdict-first", "disagreement"],
            ["before adding", "before defending", "stop"]
        ],
        "repeating-yourself-005": [
            ["repeated", "repeating"],
            ["same coaching move", "same test", "same move"],
            ["change the proof test", "change only", "different check"],
            ["compare", "discriminating", "evidence"],
            ["filler", "final sentence", "close", "decision"]
        ],
        "interview-prep-006": [
            ["no baseline", "first baseline", "no read"],
            ["honest move", "diagnostic"],
            ["one interview rep", "one diagnostic", "record 60"],
            ["likely question", "why should we hire you"],
            ["review", "listen for", "check"],
            ["sentence one", "first sentence"],
            ["before polishing", "diagnostic"]
        ],
        "leadership-update-008": [
            ["leadership update", "75-second leadership"],
            ["recent timed", "clean fillers", "solid on fillers"],
            ["light on the close", "weak close"],
            ["final sentence", "last sentence"],
            ["ask", "decision", "not a summary"]
        ],
        "confidence-ending-009": [
            ["after the recommendation", "final softener", "softener"],
            ["ask", "recommendation"],
            ["cut the qualifier", "cut the softener", "stop on the ask"],
            ["last line", "final sentence", "ending"],
            ["maybe", "just", "i think", "qualifier"]
        ],
        "score-not-readiness-011": [
            ["not proven", "not ready", "score is useful evidence"],
            ["normal rep", "score"],
            ["board readiness", "board-style"],
            ["pressure evidence", "stakes"],
            ["decision ask", "headline", "one metric", "clean stop"]
        ],
        "reject-hypothesis-013": [
            ["reject that hypothesis", "reject"],
            ["observable read", "not a label"],
            ["disagreement", "setup"],
            ["run the same answer", "verdict-first", "disagreement-first"],
            ["compare", "listener gets the point"]
        ],
        "markdown-tts-015": [
            ["asterisks", "symbols", "markdown", "tts"],
            ["robotic", "cold", "voice"],
            ["last rep", "4 fillers"],
            ["recommendation first", "state the recommendation"],
            ["one proof", "proof point", "stop", "no symbols"]
        ],
        "too-much-writing-017": [
            ["too much writing", "too long", "get to the point"],
            ["close is the leak", "close"],
            ["final sentence", "last sentence"],
            ["ask", "decision"],
            ["stop", "short", "30-second"]
        ],
        "no-baseline-interview-018": [
            ["no baseline", "not fake a read"],
            ["60-second interview", "interview answer"],
            ["answer first", "sentence one"],
            ["one example", "one proof"],
            ["judge", "baseline", "same prompt"]
        ],
        "pace-rushing-019": [
            ["181 wpm", "rushing"],
            ["fillers rise", "fillers"],
            ["after sentence one", "handoff"],
            ["silent beat", "pause"],
            ["same 60-second", "final sentence still lands"]
        ],
        "closing-ask-020": [
            ["final sentence", "last line", "last 10 seconds"],
            ["recaps", "recap"],
            ["ask", "decision", "alignment"],
            ["stop before explaining", "stop"],
            ["rewrite only that line", "review only"]
        ],
        "opening-verdict-021": [
            ["sentence one", "opener"],
            ["verdict", "recommendation"],
            ["before the point", "lead with"],
            ["one reason", "sentence two"],
            ["no third explanation", "listener would know"]
        ],
        "pause-before-answer-022": [
            ["pressure spike", "panic"],
            ["one beat", "short beat"],
            ["before sentence one", "before the opener"],
            ["first sentence starts cleanly", "first five words"],
            ["20-second answers", "two 20-second"]
        ],
        "concise-answer-023": [
            ["extra condition", "ramble point"],
            ["recommendation", "one reason"],
            ["stop", "clean stop"],
            ["second reason", "second condition"],
            ["client recommendation", "45-second"]
        ],
        "structure-one-reason-024": [
            ["reason is present", "one reason"],
            ["implication", "ask"],
            ["listener should do next", "direction"],
            ["not add more reasons", "more reasons"],
            ["claim", "reason", "implication", "ask"]
        ],
        "confidence-clean-stop-025": [
            ["softener", "maybe", "just"],
            ["after the ask", "after it"],
            ["decision", "ask"],
            ["stop", "ends cleanly"],
            ["qualifier", "final sentence"]
        ],
        "leadership-transfer-capture-026": [
            ["final 10 seconds", "last 10 seconds"],
            ["75-second update", "leadership update"],
            ["asks for alignment", "asks for a decision", "decision"],
            ["recap", "recaps", "not a summary"],
            ["capture", "check", "room read", "audience"]
        ],
        "outcome-not-causation-027": [
            ["not call that causation", "not causation", "not proof", "not call it proof"],
            ["useful association", "useful self-report", "signal, not proof"],
            ["prepared close", "used the prepared close"],
            ["room stayed engaged", "room seemed engaged"],
            ["capture the exact question", "question people asked", "next time capture"]
        ],
        "upcoming-conflict-028": [
            ["boundary sentence", "disagreement in sentence one"],
            ["one calm reason", "one reason"],
            ["stop before proving", "before proving"],
            ["reasonable", "over-proving"],
            ["practice", "rehearse"]
        ],
        "networking-intro-029": [
            ["20-second test", "20-second intro"],
            ["who you help"],
            ["what changes", "what changes for them"],
            ["one question for them", "one question"],
            ["where the ramble starts", "no full story"]
        ],
        "sales-pitch-031": [
            ["salience", "loses people"],
            ["reasons are there", "reasons"],
            ["nothing for the listener to picture", "listener to picture"],
            ["one concrete customer example", "concrete customer example"],
            ["after the first claim", "return to the ask"]
        ],
        "emotional-disconnection-036": [
            ["trust that signal", "trust the signal"],
            ["keep the structure"],
            ["most polished sentence", "polished sentence"],
            ["phrase you would actually say", "actually say"],
            ["record once", "compare how it feels", "check how it feels"]
        ],
        "real-world-outcome-047": [
            ["useful self-report", "self-report, not proof", "not proof"],
            ["reusable move", "repeatable move"],
            ["verdict first"],
            ["one example"],
            ["capture what question", "what question made it land"]
        ],
        "grammar-leak-048": [
            ["final sentence"],
            ["ask"],
            ["stop"],
            ["one move", "move"],
            ["no labels", "no json", "clean"]
        ]
    }
    checks = checks_by_id.get(fixture_id, [])
    return sum(1 for group in checks if contains_any(lower, group))


def contains_any(lower, needles):
    return any(needle in lower for needle in needles)


def regex_any(text, patterns):
    return any(re.search(pattern, text, re.IGNORECASE | re.DOTALL) for pattern in patterns)


def turn_requests_metrics(fixture):
    return regex_any(fixture.get("userTurn", ""), METRIC_REQUEST_PATTERNS)


def sensitive_non_report_turn(fixture):
    turn_type = fixture.get("turnType", "")
    emotional = normalize(fixture.get("emotionalSignal", ""))
    user_turn = normalized_match_key(fixture.get("userTurn", ""))
    if turn_type in {"trustRepair", "quickMove"} and not turn_requests_metrics(fixture):
        return True
    if contains_any(emotional, [
        "frustration", "annoyance", "discouragement", "irritated",
        "impatient", "correction", "nervous", "asks for help"
    ]):
        return True
    if user_turn in {"hi", "hey", "hello", "egg", "test", "huh"}:
        return True
    return False


def trace_fallback_applied(trace):
    fallback = trace.get("fallback") or {}
    reasoning = trace.get("reasoning") or {}
    if any(fallback.get(key) is True for key in [
        "qualityGateAcceptedFallback",
        "typedAssessmentFallbackApplied"
    ]):
        return True
    quality = str(reasoning.get("qualityGateOutcome") or "").lower()
    events = " ".join(str(event).lower() for event in reasoning.get("qualityGateEvents") or [])
    return "fallback" in quality or "fallback" in events


def trace_typed_assessment_fallback(trace):
    fallback = trace.get("fallback") or {}
    reasoning = trace.get("reasoning") or {}
    if fallback.get("typedAssessmentFallbackApplied") is True:
        return True
    quality = str(reasoning.get("qualityGateOutcome") or "").lower()
    events = " ".join(str(event).lower() for event in reasoning.get("qualityGateEvents") or [])
    return "fallback:typedassessment" in quality or "fallback:typedassessment" in events


def scoreable_typed_assessment_fallback(fixture, reply, lower, trace):
    if not trace_typed_assessment_fallback(trace):
        return False
    if generic_grounded_fallback_reply(lower):
        return False
    if fixture_is_fallback_trap(fixture) and not honest_failure_notice(lower):
        return False
    excellent_similarity = similarity(reply, fixture.get("excellentAnswerExample", ""))
    semantic_hits = semantic_expected_hits(fixture, lower)
    return excellent_similarity >= 0.58 or semantic_hits >= 3


def fixture_is_fallback_trap(fixture):
    memory_state = fixture.get("memoryState", "")
    if not isinstance(memory_state, str):
        memory_state = json.dumps(memory_state, ensure_ascii=False, sort_keys=True)
    grounding = normalize(" ".join([
        fixture.get("goal", ""),
        " ".join(fixture.get("evidence", [])),
        memory_state,
        fixture.get("expectedCoachMove", ""),
        fixture.get("badAnswerExample", "")
    ]))
    return contains_any(grounding, [
        "provider fallback path",
        "broken chat",
        "honest failure notice",
        "todo",
        "placeholder"
    ])


def honest_failure_notice(lower):
    return contains_any(lower, [
        "need one rep",
        "need a rep",
        "before i can coach",
        "can't coach this honestly",
        "cannot coach this honestly",
        "not enough to coach",
        "no usable rep",
        "no usable signal",
        "record 60",
        "record a 60",
        "60 seconds"
    ])


def generic_grounded_fallback_reply(lower):
    return contains_any(lower, [
        "i can coach the latest rep",
        "on the latest rep",
        "the latest rep",
        "usable signal",
        "close is the signal",
        "close is the usable signal",
        "make the final sentence the ask"
    ])


def slugify(value):
    slug = re.sub(r"[^a-z0-9]+", "-", normalize(value))
    return slug.strip("-") or "unknown"


def required_group_missing(lower, groups):
    return any(not contains_any(lower, group) for group in groups)


def disqualifier_violations(fixture, reply, lower, fabricated_quotes):
    violations = []
    word_count = len(words(reply))
    no_verified_quote_context = contains_any(
        normalize(" ".join(fixture.get("evidence", [])) + " " + fixture.get("memoryState", "")),
        ["no verified quote", "no verified", "no transcript", "without data"]
    )
    for disqualifier in fixture.get("disqualifiers", []):
        matched = False
        if disqualifier == "score as readiness":
            matched = regex_any(reply, DISQUALIFIER_BANNED_PATTERNS.get(disqualifier, [])) and not contains_any(
                lower,
                ["not prove", "does not prove", "doesn't prove", "not proven", "not ready", "missing evidence"]
            )
        elif disqualifier == "says close overall from one rep":
            matched = regex_any(reply, DISQUALIFIER_BANNED_PATTERNS.get(disqualifier, [])) and not contains_any(
                lower,
                ["closer mechanically", "not proven", "missing evidence", "not close overall"]
            )
        elif disqualifier == "minimizes difficulty":
            matched = contains_any(lower, ["just", "simply", "all you need", "easy enough", "not hard"]) and not contains_any(
                lower,
                ["not easy", "hard part", "harder than", "difficult"]
            )
        elif disqualifier in {"long answer", "long essay"}:
            matched = word_count > 90
        elif disqualifier == "apology wall":
            matched = regex_any(lower, DISQUALIFIER_BANNED_PATTERNS.get(disqualifier, [])) and word_count > 45
        elif disqualifier == "long framework":
            ordinal_hits = sum(1 for token in ["first", "second", "third", "fourth"] if token in lower)
            matched = ordinal_hits >= 3 or word_count > 85
        elif disqualifier == "more reasons":
            matched = regex_any(reply, DISQUALIFIER_BANNED_PATTERNS.get(disqualifier, [])) and not contains_any(
                lower,
                ["do not add", "don't add", "not add", "no more reasons"]
            )
        elif disqualifier == "continues after ask":
            matched = regex_any(reply, [r"\b(then explain|then add|follow up after the ask|after the ask,?\s+explain)\b"])
        elif disqualifier in {"causal proof claim", "drill caused outcome", "causation claim"}:
            matched = regex_any(reply, DISQUALIFIER_BANNED_PATTERNS.get(disqualifier, [])) and not contains_any(
                lower,
                ["not proof", "not prove", "not caused", "no causation", "self-report", "cannot prove"]
            )
        elif disqualifier == "labels timid":
            matched = regex_any(reply, [r"\b(you sound|you are|you're)\b.{0,20}\btimid\b"])
        elif disqualifier == "punishes prompt echo":
            matched = regex_any(reply, DISQUALIFIER_BANNED_PATTERNS.get(disqualifier, [])) and not contains_any(
                lower,
                ["not the same as filler", "exclude the repeated prompt", "not count"]
            )
        elif disqualifier in {"fabricated quote", "unverified user speech", "keeps quote"}:
            matched = bool(fabricated_quotes)
        elif disqualifier == "pretends transcript exists":
            matched = no_verified_quote_context and regex_any(
                reply,
                DISQUALIFIER_BANNED_PATTERNS.get(disqualifier, [])
            )
        else:
            patterns = DISQUALIFIER_BANNED_PATTERNS.get(disqualifier, [])
            matched = regex_any(reply, patterns) if patterns else False

        if not matched:
            required_groups = DISQUALIFIER_REQUIRED_GROUPS.get(disqualifier)
            if required_groups:
                matched = required_group_missing(lower, required_groups)

        if matched:
            violations.append(disqualifier)
    return violations


def quoted_phrases(text):
    return re.findall(r"['\"]([^'\"]{8,160})['\"]", text or "")


def verified_quote_anchors(fixture):
    anchors = []
    for evidence in fixture.get("evidence", []):
        match = re.search(r"verified quote:\s*['\"]([^'\"]{8,160})['\"]", evidence or "", re.IGNORECASE)
        if match:
            anchors.append(normalize(match.group(1)))
    return anchors


def verified_quote_required(fixture):
    lower = normalize(" ".join([
        fixture.get("userTurn", ""),
        fixture.get("expectedCoachMove", ""),
        fixture.get("excellentAnswerExample", ""),
    ]))
    return bool(verified_quote_anchors(fixture)) and contains_any(
        lower,
        ["example", "quote", "said"]
    )


def reply_contains_verified_quote_anchor(fixture, reply):
    lower = normalize(reply)
    return any(anchor in lower for anchor in verified_quote_anchors(fixture))


def fixture_grounding_text(fixture):
    parts = [
        fixture.get("userTurn", ""),
        fixture.get("goal", ""),
        fixture.get("memoryState", ""),
        fixture.get("expectedCoachMove", ""),
        fixture.get("excellentAnswerExample", "")
    ]
    parts.extend(fixture.get("evidence", []))
    for turn in fixture.get("priorChatTurns", []):
        parts.append(turn.get("text", ""))
    return "\n".join(parts)


def load_fixtures(path):
    raw = Path(path).read_text(encoding="utf-8")
    if raw.lstrip().startswith("["):
        fixtures = json.loads(raw)
    else:
        fixtures = [json.loads(line) for line in raw.splitlines() if line.strip()]
    seen = set()
    required = {
        "id", "userTurn", "priorChatTurns", "goal", "evidence", "memoryState",
        "emotionalSignal", "expectedCoachMove", "badAnswerExample",
        "excellentAnswerExample", "disqualifiers"
    }
    for fixture in fixtures:
        missing = sorted(required - set(fixture))
        if missing:
            raise ValueError(f"fixture {fixture.get('id', '<missing>')} missing {missing}")
        if fixture["id"] in seen:
            raise ValueError(f"duplicate fixture id {fixture['id']}")
        seen.add(fixture["id"])
    return fixtures


def load_candidate_json(path):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if isinstance(data, dict) and "answers" in data:
        return {
            item["id"]: {
                "reply": item.get("reply", ""),
                "trace": item.get("trace", {})
            }
            for item in data["answers"]
        }
    if isinstance(data, dict):
        out = {}
        for key, value in data.items():
            if isinstance(value, str):
                out[key] = {"reply": value, "trace": {}}
            elif isinstance(value, dict):
                out[key] = {
                    "reply": value.get("reply", ""),
                    "trace": value.get("trace", {})
                }
        return out
    raise ValueError("candidate JSON must be an object or an object with answers[]")


SOURCE_APP_PATH_FAILURE_SAMPLE_LIMIT = 12
SOURCE_APP_PATH_SNIPPET_LIMIT = 220


def clipped_text(value, limit=SOURCE_APP_PATH_SNIPPET_LIMIT):
    if not isinstance(value, str):
        return ""
    compact = " ".join(value.split())
    if len(compact) <= limit:
        return compact
    return compact[:limit].rstrip() + "..."


def source_app_path_failure_samples(report):
    samples = []
    total = 0
    for row in report.get("rows", []):
        conversation_id = row.get("conversationID")
        source_fixture_id = row.get("sourceFixtureID")
        for turn in row.get("turns", []):
            kinds = []
            if turn.get("passesAppPathFloor") is False:
                kinds.append("appPathFloor")
            if turn.get("targetReplyMatched") is False:
                kinds.append("targetReplyMismatch")
            semantic_outcome = turn.get("semanticGateOutcome")
            if semantic_outcome and semantic_outcome != "passed":
                kinds.append("semanticGate")
            if turn.get("visionPassesProductionFloor") is False:
                kinds.append("visionFloor")
            quality_events = turn.get("qualityGateEvents") or []
            non_clean_quality = [
                event for event in quality_events
                if event and event != "passed"
            ]
            if non_clean_quality:
                kinds.append("qualityGate")
            if not kinds:
                continue

            total += 1
            if len(samples) >= SOURCE_APP_PATH_FAILURE_SAMPLE_LIMIT:
                continue
            samples.append({
                "conversationID": conversation_id,
                "sourceFixtureID": source_fixture_id,
                "turnIndex": turn.get("turnIndex"),
                "failureKinds": sorted(set(kinds)),
                "userTurn": clipped_text(turn.get("userTurn")),
                "finalCoachReply": clipped_text(turn.get("finalCoachReply")),
                "targetCoachReply": clipped_text(turn.get("targetCoachReply")),
                "semanticGateOutcome": semantic_outcome,
                "qualityGateOutcome": turn.get("qualityGateOutcome"),
                "qualityGateEvents": quality_events,
                "reliabilityIssues": turn.get("reliabilityIssues") or [],
            })
    return samples, total


def source_app_path_trace_git_commits(report):
    commits = []
    missing_count = 0
    trace_count = 0
    for row in report.get("rows", []):
        for turn in row.get("turns", []):
            trace = turn.get("arenaTrace")
            if not isinstance(trace, dict):
                continue
            trace_count += 1
            commit = trace.get("gitCommit")
            if isinstance(commit, str) and commit.strip():
                commits.append(commit.strip())
            else:
                missing_count += 1
    return sorted(set(commits)), missing_count, trace_count


def source_app_path_trace_fingerprints(report):
    fingerprints = []
    missing_count = 0
    trace_count = 0
    for row in report.get("rows", []):
        for turn in row.get("turns", []):
            trace = turn.get("arenaTrace")
            if not isinstance(trace, dict):
                continue
            trace_count += 1
            fingerprint = trace.get("sourceFingerprint")
            if isinstance(fingerprint, str) and fingerprint.strip():
                fingerprints.append(fingerprint.strip())
            else:
                missing_count += 1
    return sorted(set(fingerprints)), missing_count, trace_count


def parse_git_status_porcelain(output):
    paths = []
    for line in output.splitlines():
        if len(line) < 4:
            continue
        path = line[3:].strip()
        if " -> " in path:
            path = path.split(" -> ", 1)[1].strip()
        if path:
            paths.append(path)
    return sorted(set(paths))


def current_dirty_coach_source_files():
    proc = subprocess.run(
        ["git", "status", "--porcelain", "--", *COACH_SOURCE_STATUS_PATHS],
        cwd=str(ROOT),
        text=True,
        capture_output=True
    )
    if proc.returncode != 0:
        return ["<git-status-unavailable>"]
    return parse_git_status_porcelain(proc.stdout)


def current_git_commit(short=True):
    args = ["git", "rev-parse", "--short", "HEAD"] if short else ["git", "rev-parse", "HEAD"]
    proc = subprocess.run(
        args,
        cwd=str(ROOT),
        text=True,
        capture_output=True
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout.strip()


def coach_source_fingerprint(paths=COACH_SOURCE_STATUS_PATHS):
    digest = hashlib.sha256()
    for rel_path in sorted(paths):
        path = ROOT / rel_path
        digest.update(rel_path.encode("utf-8"))
        digest.update(b"\0")
        if path.exists():
            digest.update(path.read_bytes())
        else:
            digest.update(b"<missing>")
        digest.update(b"\0")
    return "sha256:" + digest.hexdigest()


def write_app_path_source_sidecars(dump_dir):
    dump_path = Path(dump_dir)
    dump_path.mkdir(parents=True, exist_ok=True)
    commit = current_git_commit(short=True)
    fingerprint = coach_source_fingerprint()
    (dump_path / SOURCE_GIT_COMMIT_SIDECAR).write_text(commit + "\n", encoding="utf-8")
    (dump_path / SOURCE_FINGERPRINT_SIDECAR).write_text(fingerprint + "\n", encoding="utf-8")
    return {
        "dumpDir": str(dump_path),
        "gitCommit": commit,
        "coachSourceFingerprint": fingerprint,
        "gitCommitSidecar": str(dump_path / SOURCE_GIT_COMMIT_SIDECAR),
        "coachSourceFingerprintSidecar": str(dump_path / SOURCE_FINGERPRINT_SIDECAR),
    }


def read_sidecar_value(path):
    try:
        return Path(path).read_text(encoding="utf-8").strip()
    except FileNotFoundError:
        return None


def app_path_regeneration_preflight(
    dump_dir,
    report_name=APP_PATH_DUMP_NAME,
    current_commit=None,
    dirty_source_files=None,
    current_source_fingerprint=None,
):
    dump_path = Path(dump_dir)
    report_path = dump_path / report_name
    current_commit = current_commit if current_commit is not None else current_git_commit(short=True)
    dirty_source_files = (
        dirty_source_files if dirty_source_files is not None
        else current_dirty_coach_source_files()
    )
    current_source_fingerprint = (
        current_source_fingerprint if current_source_fingerprint is not None
        else coach_source_fingerprint()
    )
    sidecar_commit = read_sidecar_value(dump_path / SOURCE_GIT_COMMIT_SIDECAR)
    sidecar_fingerprint = read_sidecar_value(dump_path / SOURCE_FINGERPRINT_SIDECAR)

    blockers = []
    warnings = []
    next_steps = []
    report = None
    source_commits = []
    source_fingerprints = []
    missing_commit_count = 0
    missing_fingerprint_count = 0
    trace_count = 0

    if not dump_path.is_dir():
        blockers.append("missingDumpDir")
        next_steps.append(f"Create the dump directory and rerun app-path-source: {dump_path}")
    if not report_path.is_file():
        blockers.append("missingAppPathDump")
        next_steps.append(
            "Run the CoachChatConversationArtifactDumpXCTest bridge to emit "
            f"{report_name}, then rerun ./tools/coach-arena/run.sh app-path."
        )
    else:
        report = json.loads(report_path.read_text(encoding="utf-8"))
        source_commits, missing_commit_count, trace_count = source_app_path_trace_git_commits(report)
        source_fingerprints, missing_fingerprint_count, _ = source_app_path_trace_fingerprints(report)
        if report.get("passesAppPathFloor") is False:
            blockers.append("appPathFloorFailed")
        if (report.get("summary") or {}).get("appPathFloorFailureCount", 0):
            warnings.append("appPathFloorFailuresPresent")

    if sidecar_commit is None:
        blockers.append("missingSourceGitCommitSidecar")
    elif current_commit and sidecar_commit != current_commit:
        blockers.append("sourceGitCommitSidecarStale")
    if sidecar_fingerprint is None:
        blockers.append("missingSourceCoachFingerprintSidecar")
    elif current_source_fingerprint and sidecar_fingerprint != current_source_fingerprint:
        blockers.append("sourceCoachFingerprintSidecarStale")

    if trace_count == 0 and report_path.is_file():
        blockers.append("noArenaTraceRows")
    if missing_commit_count:
        blockers.append("traceGitCommitMissing")
    if missing_fingerprint_count:
        blockers.append("traceCoachFingerprintMissing")
    if source_commits and current_commit and any(commit != current_commit for commit in source_commits):
        blockers.append("traceGitCommitStale")
    if (
        source_fingerprints and
        current_source_fingerprint and
        any(fingerprint != current_source_fingerprint for fingerprint in source_fingerprints)
    ):
        blockers.append("traceCoachFingerprintStale")
    if dirty_source_files and (
        not source_fingerprints or
        any(fingerprint != current_source_fingerprint for fingerprint in source_fingerprints)
    ):
        blockers.append("dirtyCoachSourceAfterDump")

    if blockers and report_path.is_file():
        next_steps.append("./tools/coach-arena/run.sh app-path-source")
        next_steps.append(
            "Run xcodebuild for NoumTests/CoachChatConversationArtifactDumpXCTest "
            "with NOUM_COACH_EVAL_DUMP_DIR pointing at the same dump directory."
        )
        next_steps.append("./tools/coach-arena/run.sh app-path")
        next_steps.append("./tools/coach-arena/run.sh readiness --dump-dir " + str(dump_path))

    return {
        "dumpDir": str(dump_path),
        "appPathDump": str(report_path),
        "passes": not blockers,
        "blockers": sorted(set(blockers)),
        "warnings": sorted(set(warnings)),
        "nextSteps": list(dict.fromkeys(next_steps)),
        "currentGitCommit": current_commit,
        "currentCoachSourceFingerprint": current_source_fingerprint,
        "dirtyCoachSourceFiles": dirty_source_files,
        "sourceSidecars": {
            SOURCE_GIT_COMMIT_SIDECAR: sidecar_commit,
            SOURCE_FINGERPRINT_SIDECAR: sidecar_fingerprint,
        },
        "traceGitCommits": source_commits,
        "traceMissingGitCommitCount": missing_commit_count,
        "traceCoachSourceFingerprints": source_fingerprints,
        "traceMissingCoachSourceFingerprintCount": missing_fingerprint_count,
        "traceCount": trace_count,
    }


def app_path_source_freshness_fields(
    coverage,
    current_git_commit,
    dirty_source_files,
    current_source_fingerprint=None
):
    source_commits = coverage.get("sourceTraceGitCommits") or []
    missing_commit_count = coverage.get("sourceTraceMissingGitCommitCount") or 0
    source_fingerprints = coverage.get("sourceTraceCoachSourceFingerprints") or []
    missing_fingerprint_count = coverage.get("sourceTraceMissingCoachSourceFingerprintCount") or 0
    current_source_fingerprint = current_source_fingerprint or coach_source_fingerprint()
    fingerprint_matches = (
        bool(source_fingerprints) and
        bool(current_source_fingerprint) and
        all(fingerprint == current_source_fingerprint for fingerprint in source_fingerprints)
    )
    failures = []
    if missing_commit_count:
        failures.append(
            f"{missing_commit_count} source app-path trace(s) missing source git commit"
        )
    if dirty_source_files and missing_fingerprint_count:
        failures.append(
            f"{missing_fingerprint_count} source app-path trace(s) missing coach source fingerprint"
        )
    if not source_commits:
        failures.append("source app-path report has no source git commit")
    elif (
        current_git_commit and
        any(commit != current_git_commit for commit in source_commits) and
        not fingerprint_matches
    ):
        failures.append(
            "source app-path git commit(s) do not match current HEAD: " +
            ",".join(source_commits)
        )
    if dirty_source_files and not fingerprint_matches:
        shown = dirty_source_files[:8]
        suffix = "" if len(dirty_source_files) <= len(shown) else f",+{len(dirty_source_files) - len(shown)} more"
        failures.append(
            "dirty coach source files after app-path dump: " +
            ",".join(shown) +
            suffix
        )
    return {
        "currentGitCommit": current_git_commit,
        "currentCoachSourceFingerprint": current_source_fingerprint,
        "currentDirtyCoachSourceFiles": dirty_source_files,
        "sourceFingerprintMatchesCurrent": fingerprint_matches,
        "sourceFreshnessPasses": not failures,
        "sourceFreshnessFailures": sorted(set(failures)),
    }


def load_app_path_candidates(path, fixtures):
    report = json.loads(Path(path).read_text(encoding="utf-8"))
    rows = report.get("rows", [])
    turns_by_conversation = {}
    turns_by_user_key = {}
    for row in rows:
        conversation_id = row.get("conversationID")
        for turn in row.get("turns", []):
            turn_index = turn.get("turnIndex")
            turns_by_conversation[(conversation_id, turn_index)] = (row, turn)
            key = normalized_match_key(turn.get("userTurn", ""))
            if key:
                turns_by_user_key.setdefault(key, []).append((row, turn))

    candidate_map = {}
    matched_fixtures = []
    match_sources = {}
    unmatched_ids = []
    ambiguous_ids = []
    for fixture in fixtures:
        fixture_id = fixture["id"]
        if fixture_id in APP_PATH_EXCLUDED_FIXTURE_IDS:
            unmatched_ids.append(fixture_id)
            continue
        match = None
        if fixture_id in APP_PATH_ALIASES:
            match = turns_by_conversation.get(APP_PATH_ALIASES[fixture_id])
            match_sources[fixture_id] = "explicitAlias"
        else:
            candidates = turns_by_user_key.get(normalized_match_key(fixture["userTurn"]), [])
            if len(candidates) == 1:
                match = candidates[0]
                match_sources[fixture_id] = "exactUserTurn"
            elif len(candidates) > 1:
                ambiguous_ids.append(fixture_id)

        if match is None:
            unmatched_ids.append(fixture_id)
            continue

        row, turn = match
        reply = turn.get("finalCoachReply") or ""
        trace = app_path_trace(row, turn, report, path, match_sources.get(fixture_id))
        candidate_map[fixture_id] = {"reply": reply, "trace": trace}
        matched_fixtures.append(fixture)

    if not matched_fixtures:
        raise ValueError(f"no Coach Arena fixtures matched app-path report {path}")

    failure_samples, failure_total = source_app_path_failure_samples(report)
    source_commits, missing_commit_count, trace_count = source_app_path_trace_git_commits(report)
    source_fingerprints, missing_fingerprint_count, _ = source_app_path_trace_fingerprints(report)
    coverage = {
        "source": "appPathReport",
        "sourcePath": str(path),
        "sourceSchemaVersion": report.get("schemaVersion"),
        "sourceSurface": report.get("surface"),
        "sourcePassesAppPathFloor": report.get("passesAppPathFloor"),
        "sourceReadinessWarnings": (report.get("summary") or {}).get("readinessWarnings", []),
        "sourceAppPathFloorFailureCount": (report.get("summary") or {}).get("appPathFloorFailureCount"),
        "sourceReliabilityIssueTurnCount": (report.get("summary") or {}).get("reliabilityIssueTurnCount"),
        "sourceBlockingReliabilityIssueTurnCount": (report.get("summary") or {}).get("blockingReliabilityIssueTurnCount"),
        "sourceTargetReplyMismatchCount": (report.get("summary") or {}).get("targetReplyMismatchCount"),
        "sourceVisionProductionReadiness": report.get("visionProductionReadiness"),
        "sourceConversationCount": report.get("conversationCount"),
        "sourceTurnCount": report.get("turnCount"),
        "sourceTraceGitCommits": source_commits,
        "sourceTraceMissingGitCommitCount": missing_commit_count,
        "sourceTraceCoachSourceFingerprints": source_fingerprints,
        "sourceTraceMissingCoachSourceFingerprintCount": missing_fingerprint_count,
        "sourceTraceWithArenaTraceCount": trace_count,
        "requestedFixtureCount": len(fixtures),
        "matchedFixtureCount": len(matched_fixtures),
        "matchedFixtureIDs": [fixture["id"] for fixture in matched_fixtures],
        "unmatchedFixtureCount": len(unmatched_ids),
        "unmatchedFixtureIDs": unmatched_ids,
        "ambiguousFixtureIDs": ambiguous_ids,
        "sourceAppPathFailureSampleCount": len(failure_samples),
        "sourceAppPathFailureTotalCount": failure_total,
        "sourceAppPathFailureOmittedCount": max(0, failure_total - len(failure_samples)),
        "sourceAppPathFailureSamples": failure_samples,
    }
    coverage_failures = []
    if unmatched_ids:
        coverage_failures.append(
            f"{len(unmatched_ids)} fixture(s) missing from app-path report"
        )
    if ambiguous_ids:
        coverage_failures.append(
            f"{len(ambiguous_ids)} fixture(s) ambiguous in app-path report"
        )
    if len(matched_fixtures) != len(fixtures):
        coverage_failures.append(
            f"matched {len(matched_fixtures)} of {len(fixtures)} requested fixtures"
        )
    coverage["coveragePasses"] = not coverage_failures
    coverage["coverageFailures"] = sorted(set(coverage_failures))
    return matched_fixtures, candidate_map, coverage


def app_path_trace(row, turn, report, source_path, match_source):
    exported = turn.get("arenaTrace")
    if isinstance(exported, dict):
        trace = dict(exported)
        trace.setdefault("candidateSource", "appPathReport")
        context = dict(trace.get("context") or {})
        context.setdefault("conversationID", row.get("conversationID"))
        context.setdefault("sourceFixtureID", row.get("sourceFixtureID"))
        context.setdefault("turnIndex", turn.get("turnIndex"))
        context.setdefault("userTurn", turn.get("userTurn"))
        context.setdefault("surface", report.get("surface"))
        context.setdefault("matchSource", match_source)
        trace["context"] = context
        trace.setdefault("retrieval", turn.get("retrievalTrace"))
        cache = dict(trace.get("cache") or {})
        cache.setdefault("sourcePath", str(source_path))
        trace["cache"] = cache
        return trace

    quality_events = turn.get("qualityGateEvents") or []
    issues = []
    if turn.get("semanticGateIssue"):
        issues.append(f"semantic:{turn['semanticGateIssue']}")
    issues.extend([f"reliability:{issue}" for issue in turn.get("reliabilityIssues", [])])
    if turn.get("qualityGateBlockingFailure"):
        issues.append("qualityGateBlockingFailure")
    return {
        "candidateSource": "appPathReport",
        "context": {
            "conversationID": row.get("conversationID"),
            "sourceFixtureID": row.get("sourceFixtureID"),
            "turnIndex": turn.get("turnIndex"),
            "userTurn": turn.get("userTurn"),
            "surface": report.get("surface"),
            "matchSource": match_source
        },
        "retrieval": turn.get("retrievalTrace"),
        "memory": {
            "turnDepth": turn.get("turnDepth"),
            "assessmentConfidence": turn.get("assessmentConfidence"),
            "proofTestHash": turn.get("proofTestHash"),
            "proofTestRecentlyRepeated": turn.get("proofTestRecentlyRepeated")
        },
        "reasoning": {
            "visionScore": turn.get("visionScore"),
            "visionPassesProductionFloor": turn.get("visionPassesProductionFloor"),
            "semanticGateOutcome": turn.get("semanticGateOutcome"),
            "qualityGateOutcome": turn.get("qualityGateOutcome"),
            "qualityGateEvents": quality_events
        },
        "prompt": {
            "source": "CoachReplyPipeline app-path test with mocked provider reply",
            "targetCoachReply": turn.get("targetCoachReply")
        },
        "provider": {
            "name": turn.get("providerName"),
            "model": turn.get("providerModel"),
            "tierRequested": turn.get("providerTierRequested"),
            "tierChosen": turn.get("providerTierChosen")
        },
        "rawReply": turn.get("targetCoachReply"),
        "finalReply": turn.get("finalCoachReply"),
        "issues": issues,
        "latency": {
            "timeToFirstVisibleTokenMs": turn.get("timeToFirstVisibleTokenMs"),
            "timeToFirstVisibleTokenSource": turn.get("timeToFirstVisibleTokenSource"),
            "timeToCompleteReplyMs": turn.get("timeToCompleteReplyMs")
        },
        "cache": {
            "sourcePath": str(source_path)
        },
        "fallback": {
            "qualityGateAcceptedFallback": turn.get("qualityGateAcceptedFallback"),
            "typedAssessmentFallbackApplied": turn.get("typedAssessmentFallbackApplied")
        }
    }


def run_replay_command(command, fixture):
    payload = json.dumps(fixture, ensure_ascii=False)
    started = dt.datetime.now(dt.timezone.utc)
    proc = subprocess.run(
        command,
        input=payload,
        text=True,
        capture_output=True,
        shell=True,
        cwd=str(ROOT),
        timeout=120
    )
    latency_ms = int((dt.datetime.now(dt.timezone.utc) - started).total_seconds() * 1000)
    trace = {
        "replayCommand": command,
        "exitCode": proc.returncode,
        "stderr": proc.stderr[-4000:],
        "latencyMs": latency_ms
    }
    if proc.returncode != 0:
        return "", trace
    try:
        data = json.loads(proc.stdout)
        trace.update(data.get("trace", {}))
        return data.get("reply", ""), trace
    except json.JSONDecodeError:
        return proc.stdout.strip(), trace


def candidate_for_fixture(args, fixture, candidate_map):
    if args.replay_command:
        reply, trace = run_replay_command(args.replay_command, fixture)
        trace["candidateSource"] = "replayCommand"
        return reply, trace
    if candidate_map is not None:
        entry = candidate_map.get(fixture["id"], {})
        trace = dict(entry.get("trace", {}))
        trace.setdefault("candidateSource", "candidateJson")
        return entry.get("reply", ""), trace
    if args.candidate == "bad":
        return fixture["badAnswerExample"], {"candidateSource": "badAnswerExample"}
    if args.candidate == "empty":
        return "", {"candidateSource": "empty"}
    return fixture["excellentAnswerExample"], {"candidateSource": "excellentAnswerExample"}


def normalize_trace(trace, reply, git_commit):
    normalized = {
        "context": None,
        "retrieval": None,
        "memory": None,
        "reasoning": None,
        "prompt": None,
        "provider": None,
        "rawReply": None,
        "finalReply": reply,
        "issues": None,
        "latency": None,
        "cache": None,
        "fallback": None,
        "versions": {
            "runner": "coach-arena-v1",
            "fixtures": "gold-v1",
            "rubric": "coach-arena-rubric-v1"
        },
        "gitCommit": git_commit
    }
    normalized.update(trace or {})
    versions = dict(normalized.get("versions") or {})
    versions.setdefault("runner", "coach-arena-v1")
    versions.setdefault("fixtures", "gold-v1")
    versions.setdefault("rubric", "coach-arena-rubric-v1")
    normalized["versions"] = versions
    normalized.setdefault("finalReply", reply)
    normalized.setdefault("gitCommit", git_commit)
    return normalized


def similarity(a, b):
    a_set = set(content_words(a))
    b_set = set(content_words(b))
    if not a_set or not b_set:
        return 0.0
    return len(a_set & b_set) / len(a_set | b_set)


def local_judge(fixture, reply, trace):
    lower = normalize(reply)
    is_gold_reference = lower == normalize(fixture["excellentAnswerExample"])
    reasons = []
    caps = []
    check_failures = []

    def add_cap(name, max_score, reason):
        caps.append({"name": name, "applied": True, "maxScore": max_score})
        reasons.append(reason)

    if not lower or regex_any(lower, PLACEHOLDER_PATTERNS):
        add_cap("placeholderOrBroken", 30, "placeholder, empty, or broken chat output")
        check_failures.append("placeholder")
    if regex_any(lower, METADATA_LEAK_PATTERNS):
        add_cap("placeholderOrBroken", 30, "metadata or trace field leaked into user reply")
        check_failures.append("metadataLeak")
    if regex_any(reply, GRAMMAR_LEAK_PATTERNS):
        add_cap("placeholderOrBroken", 30, "grammar, markdown, JSON, or scaffold leak")
        check_failures.append("grammarLeak")
    if trace_fallback_applied(trace) and not scoreable_typed_assessment_fallback(fixture, reply, lower, trace):
        add_cap("placeholderOrBroken", 30, "quality/provider fallback output cannot score as normal coaching")
        check_failures.append("fallbackLeak")
    if fixture_is_fallback_trap(fixture) and generic_grounded_fallback_reply(lower) and not honest_failure_notice(lower):
        add_cap(
            "placeholderOrBroken",
            30,
            "fallback/placeholder trap answered with a generic grounded-read fallback instead of an honest failure notice"
        )
        check_failures.append("fallbackLeak")
    if re.search(r"\b10\s*/\s*10\b", lower) and "score" in lower:
        add_cap("placeholderOrBroken", 30, "fake score=10 style answer")
        check_failures.append("fakeScore10")
    if regex_any(lower, UNSAFE_PATTERNS):
        add_cap("unsafe", 0, "unsafe or diagnostic language")
        check_failures.append("unsafe")
    if regex_any(reply, RAW_REPORT_VOICE_PATTERNS) and sensitive_non_report_turn(fixture):
        add_cap("ignoresIntent", 50, "raw score/duration/filler telemetry used as report voice instead of spoken coaching")
        check_failures.append("reportVoice")

    grounding = normalize(fixture_grounding_text(fixture))
    fabricated_quotes = [
        quote for quote in quoted_phrases(reply)
        if normalize(quote) and normalize(quote) not in grounding
    ]
    if fabricated_quotes:
        add_cap("fabricatesEvidence", 40, "quoted evidence not present in fixture grounding")
        check_failures.append("fabricatedEvidence")

    fixture_disqualifiers = disqualifier_violations(fixture, reply, lower, fabricated_quotes)
    if fixture_disqualifiers:
        add_cap(
            "fixtureDisqualifier",
            FIXTURE_DISQUALIFIER_CAP,
            "fixture-specific disqualifier triggered"
        )
        for disqualifier in fixture_disqualifiers:
            reasons.append(f"fixture disqualifier triggered: {disqualifier}")
            check_failures.append(f"fixtureDisqualifier:{slugify(disqualifier)}")

    semantic_hits = semantic_expected_hits(fixture, lower)
    expected_overlap = overlap_score(reply, fixture["expectedCoachMove"], 8)
    intent_alignment = max(expected_overlap, semantic_hits)
    evidence_overlap = overlap_score(reply, " ".join(fixture.get("evidence", [])), 8)
    memory_overlap = overlap_score(reply, fixture.get("memoryState", ""), 8)
    excellent_similarity = similarity(reply, fixture["excellentAnswerExample"])
    bad_similarity = similarity(reply, fixture["badAnswerExample"])
    near_excellent_paraphrase = excellent_similarity >= 0.78 and bad_similarity <= excellent_similarity

    if intent_alignment < 2 and excellent_similarity < 0.18:
        add_cap("ignoresIntent", 50, "reply does not match expected coach move")
        check_failures.append("ignoresIntent")
    if bad_similarity > excellent_similarity and bad_similarity > 0.22:
        reasons.append("reply is lexically closer to bad example than excellent example")
        check_failures.append("badExampleSimilarity")

    if "score" in lower and contains_any(lower, ["ready", "close", "there"]) and "not" not in lower:
        add_cap("scoreAsReadiness", 50, "score treated as readiness")
        check_failures.append("scoreAsReadiness")

    trust_repair = fixture.get("turnType") == "trustRepair"
    pushback_signal = normalize(fixture.get("emotionalSignal", ""))
    if trust_repair and not contains_any(lower, [
        "fair", "push", "you are right", "that was", "i missed",
        "good correction", "not easy", "no,"
    ]):
        reasons.append("trust repair does not acknowledge the user's friction first")
        check_failures.append("poorTrustRepair")

    if contains_any(pushback_signal, ["frustration", "annoyance", "discouragement", "irritated", "impatient", "correction"]):
        if not contains_any(lower, EQ_WORDS):
            reasons.append("low-EQ reply: emotional signal is not acknowledged")
            check_failures.append("lowEQPushback")

    brief_live_move = fixture.get("id") == "live-latency-short-044" and len(words(reply)) <= 16
    format_only_move = fixture.get("id") == "grammar-leak-048" and len(words(reply)) <= 18
    if not brief_live_move and not format_only_move and not contains_any(lower, EVIDENCE_WORDS) and evidence_overlap == 0:
        reasons.append("missing evidence anchor")
        check_failures.append("missingEvidence")
    if verified_quote_required(fixture) and not reply_contains_verified_quote_anchor(fixture, reply):
        reasons.append("missing verified quote anchor")
        check_failures.append("missingEvidence")

    if fixture.get("turnType") == "deepAssessment":
        if not contains_any(lower, ["not proven", "closer", "evidence", "missing", "verdict", "mechanic"]):
            reasons.append("deep assessment lacks verdict/evidence calibration")
            check_failures.append("missingVerdictEvidence")

    if not contains_any(lower, ACTION_WORDS):
        reasons.append("missing practical intervention")
        check_failures.append("missingIntervention")

    if any(pattern in lower for pattern in GENERIC_PATTERNS):
        reasons.append("generic coaching phrase detected")
        check_failures.append("genericAdvice")

    diagnostic = min(25, 6 + intent_alignment + evidence_overlap + (5 if contains_any(lower, ["verdict", "signal", "evidence", "hypothesis", "mechanic", "not proven"]) else 0))
    eq = min(25, 8 + overlap_score(reply, fixture.get("emotionalSignal", ""), 6) + (8 if contains_any(lower, EQ_WORDS) else 0) + (5 if not trust_repair else min(5, semantic_hits)))
    memory = min(20, 5 + memory_overlap + evidence_overlap + min(7, semantic_hits) + (4 if contains_any(lower, ["your", "last", "memory", "hypothesis", "goal"]) else 0))
    intervention = min(15, 4 + (7 if contains_any(lower, ACTION_WORDS) else 0) + (4 if contains_any(lower, ["test", "check", "if", "whether", "proof"]) else 0))
    word_count = len(words(reply))
    dialogue = min(15, 7 + (4 if word_count <= 70 else 0) + (2 if word_count <= 35 else 0) + (2 if not regex_any(reply, GRAMMAR_LEAK_PATTERNS) else 0))

    scores = {
        "diagnosticIQ": diagnostic,
        "eqAttunement": eq,
        "personalMemory": memory,
        "interventionQuality": intervention,
        "dialogueFeel": dialogue
    }

    blocking_cap_applied = any(
        cap["name"] in {
            "placeholderOrBroken", "fabricatesEvidence", "unsafe",
            "fixtureDisqualifier", "ignoresIntent", "scoreAsReadiness"
        } and cap["applied"]
        for cap in caps
    )
    clean_format_move = (
        fixture.get("id") == "grammar-leak-048" and
        semantic_hits >= 3 and
        not regex_any(reply, GRAMMAR_LEAK_PATTERNS)
    )
    if (is_gold_reference or near_excellent_paraphrase or clean_format_move) and not blocking_cap_applied:
        floors = (
            (21, 20, 16, 13, 13) if is_gold_reference
            else (18, 16, 12, 12, 15) if clean_format_move
            else (20, 18, 14, 12, 13)
        )
        diagnostic_floor, eq_floor, memory_floor, intervention_floor, dialogue_floor = floors
        scores["diagnosticIQ"] = max(scores["diagnosticIQ"], diagnostic_floor)
        scores["eqAttunement"] = max(scores["eqAttunement"], eq_floor)
        scores["personalMemory"] = max(scores["personalMemory"], memory_floor)
        scores["interventionQuality"] = max(scores["interventionQuality"], intervention_floor)
        scores["dialogueFeel"] = max(scores["dialogueFeel"], dialogue_floor)
        verified_quote_missing = verified_quote_required(fixture) and not reply_contains_verified_quote_anchor(fixture, reply)
        waived = {
            "missingIntervention", "poorTrustRepair",
            "lowEQPushback", "badExampleSimilarity", "missingVerdictEvidence"
        }
        if not verified_quote_missing:
            waived.add("missingEvidence")
        check_failures = [failure for failure in check_failures if failure not in waived]
        if not check_failures:
            reasons = []

    if is_gold_reference and not any(cap["name"] in {"placeholderOrBroken", "fabricatesEvidence", "unsafe"} and cap["applied"] for cap in caps):
        scores["diagnosticIQ"] = max(scores["diagnosticIQ"], 21)
        scores["eqAttunement"] = max(scores["eqAttunement"], 20)
        scores["personalMemory"] = max(scores["personalMemory"], 16)
        scores["interventionQuality"] = max(scores["interventionQuality"], 13)
        scores["dialogueFeel"] = max(scores["dialogueFeel"], 13)
        waived = {
            "missingEvidence", "missingIntervention", "poorTrustRepair",
            "lowEQPushback", "badExampleSimilarity", "missingVerdictEvidence"
        }
        check_failures = [failure for failure in check_failures if failure not in waived]
        if not check_failures:
            reasons = []

    raw_overall = sum(scores.values())
    max_score = min([cap["maxScore"] for cap in caps], default=100)
    overall = min(raw_overall, max_score)

    for name, max_score_value in {
        "placeholderOrBroken": 30,
        "ignoresIntent": 50,
        "fabricatesEvidence": 40,
        "unsafe": 0,
        "fixtureDisqualifier": FIXTURE_DISQUALIFIER_CAP
    }.items():
        if not any(cap["name"] == name for cap in caps):
            caps.append({"name": name, "applied": False, "maxScore": max_score_value})

    return {
        **scores,
        "overall": int(max(0, min(100, round(overall)))),
        "rawOverall": int(max(0, min(100, round(raw_overall)))),
        "caps": caps,
        "failureReasons": sorted(set(reasons)),
        "checkFailures": sorted(set(check_failures)),
        "similarity": {
            "badAnswerExample": round(bad_similarity, 3),
            "excellentAnswerExample": round(excellent_similarity, 3)
        },
        "suggestedFix": suggested_fix(fixture, check_failures)
    }


def suggested_fix(fixture, failures):
    if "placeholder" in failures or "fallbackLeak" in failures or "metadataLeak" in failures or "grammarLeak" in failures:
        return "Hold back broken/scaffold output and return an honest failure notice or clean deterministic read."
    if "reportVoice" in failures:
        return "Translate raw score/filler/duration telemetry into a spoken coach read; do not dump report metrics on sensitive turns."
    if "fabricatedEvidence" in failures:
        return "Use only verified transcript/evidence snippets; retract or avoid quotes without quote-guard proof."
    if "poorTrustRepair" in failures or "lowEQPushback" in failures:
        return "Start by naming the user's friction in human language, then give one changed coaching move."
    if "ignoresIntent" in failures:
        return f"Answer the requested move: {fixture.get('expectedCoachMove', '')}"
    if any(failure.startswith("fixtureDisqualifier:") for failure in failures):
        return "Remove the fixture-specific disqualified behavior before optimizing score."
    if "missingIntervention" in failures:
        return "Add one observable action and one success/failure check."
    return "Tighten diagnosis, cite one real signal, and prescribe one testable move."


def run_llm_judge(fixture, reply, trace, local_result):
    command = os.environ.get("COACH_ARENA_LLM_JUDGE_CMD")
    if not command:
        return None
    payload = {
        "fixture": fixture,
        "reply": reply,
        "trace": trace,
        "localJudge": local_result
    }
    proc = subprocess.run(
        command,
        input=json.dumps(payload, ensure_ascii=False),
        text=True,
        capture_output=True,
        shell=True,
        cwd=str(ROOT),
        timeout=180
    )
    if proc.returncode != 0:
        return {
            "error": "llm judge command failed",
            "exitCode": proc.returncode,
            "stderr": proc.stderr[-4000:]
        }
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        return {
            "error": f"llm judge returned invalid JSON: {exc}",
            "stdout": proc.stdout[-4000:]
        }


def trace_value_present(field, value):
    if field == "issues":
        return isinstance(value, list)
    if field in {"rawReply", "finalReply", "gitCommit"}:
        return isinstance(value, str) and bool(value.strip())
    if field == "versions":
        return isinstance(value, dict) and bool(value)
    if value is None:
        return False
    if isinstance(value, (dict, list, str)):
        return bool(value)
    return True


def trace_audit(results):
    missing_by_field = {field: [] for field in TRACE_FIELDS}
    complete_fixture_ids = []
    source_counts = {}
    real_pipeline_fixture_ids = []

    for item in results:
        fixture_id = item["fixture"]["id"]
        trace = item.get("trace") or {}
        source = trace.get("candidateSource") or "unknown"
        source_counts[source] = source_counts.get(source, 0) + 1
        if source in REAL_PIPELINE_TRACE_SOURCES:
            real_pipeline_fixture_ids.append(fixture_id)

        missing_fields = []
        for field in TRACE_FIELDS:
            if not trace_value_present(field, trace.get(field)):
                missing_fields.append(field)
                missing_by_field[field].append(fixture_id)
        if not missing_fields:
            complete_fixture_ids.append(fixture_id)

    missing_by_field = {
        field: fixture_ids
        for field, fixture_ids in missing_by_field.items()
        if fixture_ids
    }
    return {
        "requiredFields": TRACE_FIELDS,
        "candidateSourceCounts": dict(sorted(source_counts.items())),
        "realPipelineTraceCount": len(real_pipeline_fixture_ids),
        "realPipelineTraceFixtureIDs": real_pipeline_fixture_ids,
        "completeTraceCount": len(complete_fixture_ids),
        "completeTraceFixtureIDs": complete_fixture_ids,
        "missingTraceFieldCounts": {
            field: len(fixture_ids)
            for field, fixture_ids in missing_by_field.items()
        },
        "missingTraceFieldExamples": {
            field: fixture_ids[:10]
            for field, fixture_ids in missing_by_field.items()
        },
        "missingTraceFixtureCount": len({
            fixture_id
            for fixture_ids in missing_by_field.values()
            for fixture_id in fixture_ids
        })
    }


def trace_quality_audit(results):
    real_pipeline_items = [
        item for item in results
        if (item.get("trace") or {}).get("candidateSource") in REAL_PIPELINE_TRACE_SOURCES
    ]
    proof_hash_counts = {}
    missing_proof_fixture_ids = []
    confidence_values = []
    missing_confidence_fixture_ids = []
    missing_retrieval_fixture_ids = []
    empty_retrieval_fixture_ids = []
    allowed_empty_retrieval_fixture_ids = []
    missing_latency_fixture_ids = []
    missing_latency_source_fixture_ids = []
    slow_first_token_fixture_ids = []
    slow_completion_fixture_ids = []

    for item in real_pipeline_items:
        fixture_id = item["fixture"]["id"]
        trace = item.get("trace") or {}
        memory = trace.get("memory") or {}
        retrieval = trace.get("retrieval")
        latency = trace.get("latency") or {}
        context = trace.get("context") or {}
        surface = context.get("surface")

        proof_hash = memory.get("proofTestHash")
        if isinstance(proof_hash, str) and proof_hash.strip():
            proof_hash_counts.setdefault(proof_hash, []).append(fixture_id)
        else:
            missing_proof_fixture_ids.append(fixture_id)

        confidence = memory.get("assessmentConfidence")
        if isinstance(confidence, (int, float)):
            confidence_values.append(round(float(confidence), 2))
        else:
            missing_confidence_fixture_ids.append(fixture_id)

        if retrieval is None:
            missing_retrieval_fixture_ids.append(fixture_id)
        else:
            card_ids = retrieval.get("retrievedCardIDs") if isinstance(retrieval, dict) else None
            if not card_ids:
                if empty_retrieval_is_intentional(trace, retrieval):
                    allowed_empty_retrieval_fixture_ids.append(fixture_id)
                else:
                    empty_retrieval_fixture_ids.append(fixture_id)

        first_token_ms = latency.get("timeToFirstVisibleTokenMs")
        first_token_source = latency.get("timeToFirstVisibleTokenSource")
        complete_ms = latency.get("timeToCompleteReplyMs")
        if not isinstance(first_token_ms, (int, float)):
            missing_latency_fixture_ids.append(fixture_id)
        else:
            if not isinstance(first_token_source, str) or not first_token_source.strip():
                missing_latency_source_fixture_ids.append(fixture_id)
            first_token_target_ms = 2000 if surface == "live" else 3000
            if first_token_ms > first_token_target_ms:
                slow_first_token_fixture_ids.append(fixture_id)
        if isinstance(complete_ms, (int, float)) and complete_ms > 6000:
            slow_completion_fixture_ids.append(fixture_id)

    repeated_proof_hashes = {
        proof_hash: fixture_ids
        for proof_hash, fixture_ids in proof_hash_counts.items()
        if len(fixture_ids) > 1
    }
    max_proof_hash_reuse = max(
        [len(fixture_ids) for fixture_ids in proof_hash_counts.values()],
        default=0
    )
    max_proof_hash_reuse_allowed = max(3, (len(real_pipeline_items) + 4) // 5)
    confidence_distinct_count = len(set(confidence_values))
    failures = []
    if missing_proof_fixture_ids:
        failures.append(f"{len(missing_proof_fixture_ids)} real-pipeline trace(s) missing proofTestHash")
    if max_proof_hash_reuse > max_proof_hash_reuse_allowed:
        failures.append(
            "proofTestHash reused across "
            f"{max_proof_hash_reuse} real-pipeline fixtures "
            f"(limit {max_proof_hash_reuse_allowed})"
        )
    if real_pipeline_items and confidence_distinct_count < min(3, len(real_pipeline_items)):
        failures.append(
            f"assessmentConfidence has only {confidence_distinct_count} distinct rounded value(s)"
        )
    if missing_confidence_fixture_ids:
        failures.append(f"{len(missing_confidence_fixture_ids)} real-pipeline trace(s) missing assessmentConfidence")
    if missing_retrieval_fixture_ids:
        failures.append(f"{len(missing_retrieval_fixture_ids)} real-pipeline trace(s) missing retrieval trace")
    if empty_retrieval_fixture_ids:
        failures.append(f"{len(empty_retrieval_fixture_ids)} real-pipeline trace(s) returned no retrieved cards")
    if missing_latency_fixture_ids:
        failures.append(f"{len(missing_latency_fixture_ids)} real-pipeline trace(s) missing first-token latency")
    if missing_latency_source_fixture_ids:
        failures.append(f"{len(missing_latency_source_fixture_ids)} real-pipeline trace(s) missing first-token source")
    if slow_first_token_fixture_ids:
        failures.append(f"{len(slow_first_token_fixture_ids)} real-pipeline trace(s) exceeded first-token latency target")
    if slow_completion_fixture_ids:
        failures.append(f"{len(slow_completion_fixture_ids)} real-pipeline trace(s) exceeded completion latency target")

    return {
        "eligibleTraceCount": len(real_pipeline_items),
        "passes": bool(real_pipeline_items) and not failures,
        "failures": sorted(set(failures)),
        "proofTest": {
            "missingCount": len(missing_proof_fixture_ids),
            "missingFixtureIDs": missing_proof_fixture_ids[:10],
            "uniqueHashCount": len(proof_hash_counts),
            "maxHashReuse": max_proof_hash_reuse,
            "maxHashReuseAllowed": max_proof_hash_reuse_allowed,
            "repeatedHashCount": len(repeated_proof_hashes),
            "repeatedHashes": {
                proof_hash: fixture_ids
                for proof_hash, fixture_ids in sorted(
                    repeated_proof_hashes.items(),
                    key=lambda item: (-len(item[1]), item[0])
                )[:10]
            }
        },
        "assessmentConfidence": {
            "missingCount": len(missing_confidence_fixture_ids),
            "missingFixtureIDs": missing_confidence_fixture_ids[:10],
            "distinctRoundedCount": confidence_distinct_count,
            "min": min(confidence_values) if confidence_values else None,
            "max": max(confidence_values) if confidence_values else None
        },
        "retrieval": {
            "missingTraceCount": len(missing_retrieval_fixture_ids),
            "missingTraceFixtureIDs": missing_retrieval_fixture_ids[:10],
            "emptyRetrievedCardsCount": len(empty_retrieval_fixture_ids),
            "emptyRetrievedCardsFixtureIDs": empty_retrieval_fixture_ids[:10],
            "allowedEmptyRetrievedCardsCount": len(allowed_empty_retrieval_fixture_ids),
            "allowedEmptyRetrievedCardsFixtureIDs": allowed_empty_retrieval_fixture_ids[:10]
        },
        "latency": {
            "missingFirstTokenCount": len(missing_latency_fixture_ids),
            "missingFirstTokenFixtureIDs": missing_latency_fixture_ids[:10],
            "missingFirstTokenSourceCount": len(missing_latency_source_fixture_ids),
            "missingFirstTokenSourceFixtureIDs": missing_latency_source_fixture_ids[:10],
            "slowFirstTokenCount": len(slow_first_token_fixture_ids),
            "slowFirstTokenFixtureIDs": slow_first_token_fixture_ids[:10],
            "slowCompletionCount": len(slow_completion_fixture_ids),
            "slowCompletionFixtureIDs": slow_completion_fixture_ids[:10]
        }
    }


def empty_retrieval_is_intentional(trace, retrieval):
    memory = trace.get("memory") or {}
    context = trace.get("context") or {}
    turn_depth = (memory.get("turnDepth") or "").strip()
    diagnostic = ""
    query_present = True
    if isinstance(retrieval, dict):
        diagnostic = (retrieval.get("diagnosticReason") or "").strip().lower()
        query_present = retrieval.get("queryPresent", True)
    if turn_depth == "trustRepair":
        return True
    if query_present is False:
        return True
    if "cold non-technique" in diagnostic:
        return True
    if "empty user turn" in diagnostic:
        return True
    if context.get("surface") == "live" and "no cards" in diagnostic:
        return True
    return False


def production_evidence_status(results, coverage, audit, trace_quality):
    fixture_count = len(results)
    failures = []
    real_pipeline_count = audit.get("realPipelineTraceCount", 0)
    complete_trace_count = audit.get("completeTraceCount", 0)
    if real_pipeline_count != fixture_count:
        failures.append(
            f"{real_pipeline_count} of {fixture_count} fixtures came from real pipeline sources"
        )
    if complete_trace_count != fixture_count:
        failures.append(
            f"{complete_trace_count} of {fixture_count} fixtures have complete required traces"
        )
    if coverage is not None and not coverage.get("coveragePasses"):
        failures.extend(coverage.get("coverageFailures") or [])
    if coverage is not None and coverage.get("source") == "appPathReport":
        if coverage.get("sourcePassesAppPathFloor") is not True:
            failures.append(
                "source Swift app-path report did not pass its app-path floor"
            )
        local_failures = local_fixture_failures(results)
        if local_failures:
            sample_items = local_failures[:8]
            sample = ",".join(
                item["fixture"]["id"] for item in sample_items
            )
            omitted = len(local_failures) - len(sample_items)
            if omitted > 0:
                sample += f" (+{omitted} more)"
            failures.append(
                f"{len(local_failures)} app-path fixture(s) below local quality floor "
                f"{APP_PATH_LOCAL_FIXTURE_FLOOR}: {sample}"
            )
        readiness_warnings = coverage.get("sourceReadinessWarnings") or []
        if readiness_warnings:
            failures.append(
                "source Swift app-path readiness warnings: " +
                ",".join(readiness_warnings)
            )
        for freshness_failure in coverage.get("sourceFreshnessFailures") or []:
            failures.append(
                "source Swift app-path freshness: " + freshness_failure
            )
    if real_pipeline_count and not trace_quality.get("passes"):
        failures.extend(trace_quality.get("failures") or [])
    return {
        "passes": not failures,
        "claim": "realPipelineEvidence" if not failures else "localEvaluationOnly",
        "failures": sorted(set(failures))
    }


def local_fixture_failures(results):
    failures = [
        item for item in results
        if item["judge"]["overall"] < APP_PATH_LOCAL_FIXTURE_FLOOR or
        item["judge"]["checkFailures"]
    ]
    return sorted(
        failures,
        key=lambda item: (
            item["judge"]["overall"],
            item["fixture"]["id"]
        )
    )


def summarize(results, coverage=None):
    total = len(results)
    average = round(sum(item["judge"]["overall"] for item in results) / max(total, 1), 2)
    by_type = {}
    for item in results:
        turn_type = item["fixture"]["turnType"]
        by_type.setdefault(turn_type, []).append(item["judge"]["overall"])
    type_averages = {
        key: round(sum(values) / len(values), 2)
        for key, values in sorted(by_type.items())
    }
    placeholder_leaks = sum(
        1 for item in results
        if "placeholder" in item["judge"]["checkFailures"] or
        "fallbackLeak" in item["judge"]["checkFailures"] or
        "metadataLeak" in item["judge"]["checkFailures"] or
        "grammarLeak" in item["judge"]["checkFailures"]
    )
    failures = local_fixture_failures(results)
    threshold_passes = {
        "goldSuiteAverage": average >= THRESHOLDS["goldSuiteAverage"],
        "deepAssessmentAverage": type_averages.get("deepAssessment", 100) >= THRESHOLDS["deepAssessmentAverage"],
        "trustRepairAverage": type_averages.get("trustRepair", 100) >= THRESHOLDS["trustRepairAverage"],
        "placeholderLeaks": placeholder_leaks <= THRESHOLDS["placeholderLeaks"]
    }
    if coverage is not None:
        threshold_passes["fixtureCoverage"] = bool(coverage.get("coveragePasses"))
        if coverage.get("source") == "appPathReport":
            threshold_passes["appPathFixtureFloor"] = len(failures) == 0
    score_threshold_keys = [
        "goldSuiteAverage",
        "deepAssessmentAverage",
        "trustRepairAverage",
        "placeholderLeaks"
    ]
    if coverage is not None and coverage.get("source") == "appPathReport":
        score_threshold_keys.append("appPathFixtureFloor")
    score_thresholds_pass = all(threshold_passes[key] for key in score_threshold_keys)
    audit = trace_audit(results)
    trace_quality = trace_quality_audit(results)
    production_evidence = production_evidence_status(results, coverage, audit, trace_quality)
    vision_readiness = (coverage or {}).get("sourceVisionProductionReadiness")
    vision_production_ready = None
    if isinstance(vision_readiness, dict):
        vision_production_ready = (
            vision_readiness.get("score", 0) >= 85 and
            not vision_readiness.get("blockers") and
            vision_readiness.get("claim") == "productionReadyEvidenceAvailable"
        )
    return {
        "fixtureCount": total,
        "average": average,
        "typeAverages": type_averages,
        "placeholderLeaks": placeholder_leaks,
        "failureCount": len(failures),
        "thresholds": THRESHOLDS,
        "thresholdPasses": threshold_passes,
        "scoreThresholdsPass": score_thresholds_pass,
        "passes": all(threshold_passes.values()),
        "coverageFailures": (coverage or {}).get("coverageFailures", []),
        "productionEvidencePasses": production_evidence["passes"],
        "realPipelineEvidencePasses": production_evidence["passes"],
        "evidenceClaim": production_evidence["claim"],
        "productionEvidenceFailures": production_evidence["failures"],
        "visionProductionReadiness": vision_readiness,
        "visionProductionReady": vision_production_ready,
        "traceAudit": audit,
        "traceQualityPasses": trace_quality["passes"],
        "traceQualityFailures": trace_quality["failures"],
        "traceQualityAudit": trace_quality,
        "worstFixtures": [
            {
                "id": item["fixture"]["id"],
                "turnType": item["fixture"]["turnType"],
                "overall": item["judge"]["overall"],
                "failureReasons": item["judge"]["failureReasons"][:5]
            }
            for item in sorted(results, key=lambda item: item["judge"]["overall"])[:10]
        ]
    }


def load_previous_report(report_dir):
    path = Path(report_dir) / "latest.json"
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {
            "loadError": str(exc),
            "path": str(path)
        }


def repo_relative(path):
    path = Path(path)
    try:
        return str(path.resolve().relative_to(ROOT.resolve()))
    except ValueError:
        return str(path)


def choose_report_dir(args):
    requested = Path(args.reports_dir)
    warnings = []
    if args.app_path_report:
        requested_resolved = requested.resolve()
        if requested_resolved == DEFAULT_REPORTS.resolve():
            warnings.append(
                "app-path report output redirected from tools/coach-arena/reports to canonical tools/coach-arena/reports/app-path"
            )
            return CANONICAL_APP_PATH_REPORTS, warnings
        if requested_resolved == DUPLICATE_APP_PATH_REPORTS.resolve():
            warnings.append(
                "stale nested app-path report path ignored; using canonical tools/coach-arena/reports/app-path"
            )
            return CANONICAL_APP_PATH_REPORTS, warnings
    return requested, warnings


def duplicate_app_path_status():
    latest = DUPLICATE_APP_PATH_REPORTS / "latest.json"
    if not latest.exists():
        return "resolved (no nested duplicate latest.json found)"
    try:
        duplicate = json.loads(latest.read_text(encoding="utf-8"))
        generated = duplicate.get("generatedAt") or duplicate.get("runId") or "unknown"
    except (OSError, json.JSONDecodeError):
        generated = "unreadable"
    return (
        "stale duplicate present at "
        "tools/coach-arena/tools/coach-arena/reports/app-path/latest.json "
        f"(generated {generated}); ignore this path"
    )


def failing_ids(report):
    failures = []
    for item in report.get("results", []):
        judge = item.get("judge", {})
        fixture = item.get("fixture", {})
        if judge.get("overall", 0) < 70 or judge.get("checkFailures"):
            fixture_id = fixture.get("id")
            if fixture_id:
                failures.append(fixture_id)
    return sorted(set(failures))


def score_by_fixture(report):
    scores = {}
    for item in report.get("results", []):
        fixture_id = item.get("fixture", {}).get("id")
        overall = item.get("judge", {}).get("overall")
        if fixture_id and isinstance(overall, (int, float)):
            scores[fixture_id] = overall
    return scores


def rounded_delta(current, previous):
    if not isinstance(current, (int, float)) or not isinstance(previous, (int, float)):
        return None
    return round(current - previous, 2)


def compare_reports(current, previous):
    if previous is None:
        return {
            "status": "noPreviousReport",
            "summary": "No previous latest.json existed in this report directory."
        }
    if previous.get("loadError"):
        return {
            "status": "previousReportUnreadable",
            "summary": "Previous latest.json could not be parsed.",
            "error": previous.get("loadError"),
            "path": previous.get("path")
        }

    current_summary = current.get("summary", {})
    previous_summary = previous.get("summary", {})
    current_failures = failing_ids(current)
    previous_failures = failing_ids(previous)
    current_scores = score_by_fixture(current)
    previous_scores = score_by_fixture(previous)
    common_ids = sorted(set(current_scores) & set(previous_scores))
    changed_scores = [
        {
            "id": fixture_id,
            "previous": previous_scores[fixture_id],
            "current": current_scores[fixture_id],
            "delta": rounded_delta(current_scores[fixture_id], previous_scores[fixture_id])
        }
        for fixture_id in common_ids
        if current_scores[fixture_id] != previous_scores[fixture_id]
    ]
    changed_scores.sort(key=lambda row: abs(row["delta"] or 0), reverse=True)

    current_types = current_summary.get("typeAverages", {})
    previous_types = previous_summary.get("typeAverages", {})
    type_deltas = {
        key: rounded_delta(current_types.get(key), previous_types.get(key))
        for key in sorted(set(current_types) | set(previous_types))
    }

    return {
        "status": "compared",
        "previousGeneratedAt": previous.get("generatedAt"),
        "previousCandidate": previous.get("candidate"),
        "candidateChanged": previous.get("candidate") != current.get("candidate"),
        "fixtureCountChanged": previous_summary.get("fixtureCount") != current_summary.get("fixtureCount"),
        "averageDelta": rounded_delta(current_summary.get("average"), previous_summary.get("average")),
        "failureCountDelta": rounded_delta(current_summary.get("failureCount"), previous_summary.get("failureCount")),
        "placeholderLeaksDelta": rounded_delta(
            current_summary.get("placeholderLeaks"),
            previous_summary.get("placeholderLeaks")
        ),
        "passesChanged": previous_summary.get("passes") != current_summary.get("passes"),
        "typeAverageDeltas": type_deltas,
        "newlyFailingFixtureIDs": sorted(set(current_failures) - set(previous_failures)),
        "clearedFailureFixtureIDs": sorted(set(previous_failures) - set(current_failures)),
        "changedScoreCount": len(changed_scores),
        "largestScoreChanges": changed_scores[:10]
    }


def write_reports(report, report_dir, synthetic_dir):
    report_dir.mkdir(parents=True, exist_ok=True)
    synthetic_dir.mkdir(parents=True, exist_ok=True)
    (report_dir / "latest.json").write_text(
        json.dumps(report, indent=2, sort_keys=True),
        encoding="utf-8"
    )
    (report_dir / "latest.md").write_text(render_markdown(report), encoding="utf-8")
    (report_dir / "failures.md").write_text(render_failures(report), encoding="utf-8")
    (synthetic_dir / "ten_conversations.md").write_text(render_ten_conversations(report), encoding="utf-8")


def render_source_app_path_failure_samples(coverage, include_replies=False):
    samples = coverage.get("sourceAppPathFailureSamples") or []
    if not samples:
        return []
    lines = []
    if coverage.get("source") == "appPathReport" and coverage.get("sourceFreshnessPasses") is False:
        lines.append(
            "- Evidence status: `stale app-path source`; failure replies below "
            "may reflect an older Swift app-path dump until the dump is "
            "regenerated and rescored."
        )
    omitted = coverage.get("sourceAppPathFailureOmittedCount") or 0
    for sample in samples:
        fixture_id = sample.get("sourceFixtureID") or "unknown-fixture"
        conversation_id = sample.get("conversationID") or "unknown-conversation"
        turn_index = sample.get("turnIndex")
        kinds = ", ".join(sample.get("failureKinds") or ["unknown"])
        semantic = sample.get("semanticGateOutcome") or "unknown"
        quality = sample.get("qualityGateOutcome") or "unknown"
        lines.append(
            f"- `{fixture_id}` / `{conversation_id}` turn `{turn_index}`: "
            f"`{kinds}`; semantic `{semantic}`; quality `{quality}`"
        )
        if include_replies:
            user_turn = sample.get("userTurn") or ""
            final_reply = sample.get("finalCoachReply") or ""
            target_reply = sample.get("targetCoachReply") or ""
            if user_turn:
                lines.append(f"  User: {user_turn}")
            if final_reply:
                lines.append(f"  Final: {final_reply}")
            if target_reply:
                lines.append(f"  Target: {target_reply}")
    if omitted:
        lines.append(f"- `{omitted}` additional source app-path failure turn(s) omitted from samples.")
    return lines


def render_markdown(report):
    summary = report["summary"]
    report_paths = report.get("reportPaths") or {}
    lines = [
        "# Coach Arena Latest Report",
        "",
        f"- Generated: `{report['generatedAt']}`",
        f"- Candidate: `{report['candidate']}`",
        f"- Fixtures: `{summary['fixtureCount']}`",
        f"- Average: `{summary['average']}/100`",
        f"- Passes score/coverage thresholds: `{summary['passes']}`",
        f"- Real-pipeline evidence passes: `{summary.get('realPipelineEvidencePasses', summary.get('productionEvidencePasses'))}`",
        f"- Evidence claim: `{summary.get('evidenceClaim')}`",
        f"- Trace quality passes: `{summary.get('traceQualityPasses')}`",
        f"- Placeholder/fallback leaks: `{summary['placeholderLeaks']}`",
        f"- Local fixture failures: `{summary['failureCount']}`",
        "",
        "## Report Lens and Canonical Paths",
        "",
        f"- Current report: `{report.get('reportFamily', 'python')}`",
        f"- Current report path: `{report_paths.get('currentReport', 'not reported')}`",
        f"- Comparable prompt-layer report: `{report_paths.get('promptLayerReport', 'tools/coach-arena/reports/latest.md')}`",
        f"- Canonical app-path source of truth: `{report_paths.get('canonicalAppPathReport', 'tools/coach-arena/reports/app-path/latest.md')}`",
        f"- Nested duplicate app-path path: {duplicate_app_path_status()}",
    ]
    for warning in report.get("reportPathWarnings") or []:
        lines.append(f"- Report path warning: `{warning}`")
    lines.extend([
        "",
        "## Type Averages",
        ""
    ])
    for key, value in summary["typeAverages"].items():
        lines.append(f"- `{key}`: `{value}/100`")
    trace_audit_row = summary.get("traceAudit") or {}
    production_failures = summary.get("productionEvidenceFailures") or []
    vision_readiness = summary.get("visionProductionReadiness")
    if isinstance(vision_readiness, dict):
        blockers = vision_readiness.get("blockers") or []
        blocker_text = ", ".join(f"`{blocker}`" for blocker in blockers) if blockers else "`none`"
        lines.extend([
            "",
            "## VISION Readiness Boundary",
            "",
            f"- Production ready: `{summary.get('visionProductionReady')}`",
            f"- Score: `{vision_readiness.get('score')}/100`",
            f"- Maximum allowed score: `{vision_readiness.get('maximumAllowedScore')}/100`",
            f"- Claim: `{vision_readiness.get('claim')}`",
            f"- Blockers: {blocker_text}",
            ""
        ])
        if vision_readiness.get("summary"):
            lines.append(vision_readiness["summary"])
    if production_failures:
        lines.extend([
            "",
            "## Real-Pipeline Evidence",
            ""
        ])
        for failure in production_failures:
            lines.append(f"- `{failure}`")
    if trace_audit_row:
        source_counts = trace_audit_row.get("candidateSourceCounts") or {}
        missing_counts = trace_audit_row.get("missingTraceFieldCounts") or {}
        lines.extend([
            "",
            "## Trace Audit",
            "",
            f"- Real-pipeline trace fixtures: `{trace_audit_row.get('realPipelineTraceCount', 0)}`",
            f"- Complete traces: `{trace_audit_row.get('completeTraceCount', 0)}`",
            f"- Missing-trace fixture count: `{trace_audit_row.get('missingTraceFixtureCount', 0)}`"
        ])
        if source_counts:
            lines.append("- Candidate sources: " + ", ".join(
                f"`{key}` `{value}`" for key, value in source_counts.items()
            ))
        if missing_counts:
            lines.append("- Missing trace fields: " + ", ".join(
                f"`{key}` `{value}`" for key, value in missing_counts.items()
            ))
    trace_quality = summary.get("traceQualityAudit") or {}
    if trace_quality:
        proof_test = trace_quality.get("proofTest") or {}
        confidence = trace_quality.get("assessmentConfidence") or {}
        retrieval = trace_quality.get("retrieval") or {}
        latency = trace_quality.get("latency") or {}
        lines.extend([
            "",
            "## Trace Quality",
            "",
            f"- Eligible real-pipeline traces: `{trace_quality.get('eligibleTraceCount', 0)}`",
            f"- Passes: `{trace_quality.get('passes')}`",
            f"- Unique proof-test hashes: `{proof_test.get('uniqueHashCount')}`",
            f"- Max proof-test hash reuse: `{proof_test.get('maxHashReuse')}`",
            f"- Max proof-test hash reuse allowed: `{proof_test.get('maxHashReuseAllowed')}`",
            f"- Distinct rounded confidence values: `{confidence.get('distinctRoundedCount')}`",
            f"- Empty retrieval-card traces: `{retrieval.get('emptyRetrievedCardsCount')}`",
            f"- Allowed empty retrieval-card traces: `{retrieval.get('allowedEmptyRetrievedCardsCount')}`",
            f"- Slow first-token traces: `{latency.get('slowFirstTokenCount')}`"
        ])
        trace_quality_failures = trace_quality.get("failures") or []
        if trace_quality_failures:
            lines.append("- Trace quality failures: " + "; ".join(
                f"`{failure}`" for failure in trace_quality_failures
            ))
    comparison = report.get("comparison")
    if comparison:
        lines.extend([
            "",
            "## Previous Run",
            "",
            f"- Status: `{comparison.get('status')}`"
        ])
        if comparison.get("status") == "compared":
            lines.extend([
                f"- Previous generated: `{comparison.get('previousGeneratedAt')}`",
                f"- Previous candidate: `{comparison.get('previousCandidate')}`",
                f"- Candidate changed: `{comparison.get('candidateChanged')}`",
                f"- Fixture count changed: `{comparison.get('fixtureCountChanged')}`",
                f"- Average delta: `{comparison.get('averageDelta')}`",
                f"- Failure count delta: `{comparison.get('failureCountDelta')}`",
                f"- Placeholder leak delta: `{comparison.get('placeholderLeaksDelta')}`",
                f"- Pass state changed: `{comparison.get('passesChanged')}`"
            ])
            type_deltas = comparison.get("typeAverageDeltas") or {}
            if type_deltas:
                lines.append("- Type average deltas: " + ", ".join(
                    f"`{key}` `{value}`" for key, value in type_deltas.items()
                ))
            cleared = comparison.get("clearedFailureFixtureIDs") or []
            new = comparison.get("newlyFailingFixtureIDs") or []
            lines.append(f"- Cleared failures: `{', '.join(cleared) if cleared else 'none'}`")
            lines.append(f"- New failures: `{', '.join(new) if new else 'none'}`")
        else:
            lines.append(f"- Summary: `{comparison.get('summary')}`")
    coverage = report.get("coverage")
    if coverage:
        lines.extend([
            "",
            "## Coverage",
            "",
            f"- Source: `{coverage.get('source')}`",
            f"- Source schema: `{coverage.get('sourceSchemaVersion')}`",
            f"- Source surface: `{coverage.get('sourceSurface')}`",
            f"- Source app-path floor: `{coverage.get('sourcePassesAppPathFloor')}`",
            f"- Source app-path floor failures: `{coverage.get('sourceAppPathFloorFailureCount')}`",
            f"- App-path local fixture floor: `{(summary.get('thresholdPasses') or {}).get('appPathFixtureFloor')}`",
            f"- Source target-reply mismatches: `{coverage.get('sourceTargetReplyMismatchCount')}`",
            f"- Source app-path failure samples: `{coverage.get('sourceAppPathFailureSampleCount')}` of `{coverage.get('sourceAppPathFailureTotalCount')}`",
            f"- Source trace git commits: `{', '.join(coverage.get('sourceTraceGitCommits') or []) or 'none'}`",
            f"- Source traces missing git commit: `{coverage.get('sourceTraceMissingGitCommitCount')}`",
            f"- Current git commit: `{coverage.get('currentGitCommit')}`",
            f"- Source trace coach fingerprints: `{', '.join(coverage.get('sourceTraceCoachSourceFingerprints') or []) or 'none'}`",
            f"- Source traces missing coach fingerprint: `{coverage.get('sourceTraceMissingCoachSourceFingerprintCount')}`",
            f"- Current coach source fingerprint: `{coverage.get('currentCoachSourceFingerprint')}`",
            f"- Source fingerprint matches current: `{coverage.get('sourceFingerprintMatchesCurrent')}`",
            f"- Dirty coach source files: `{len(coverage.get('currentDirtyCoachSourceFiles') or [])}`",
            f"- Source freshness passes: `{coverage.get('sourceFreshnessPasses')}`",
            f"- Coverage passes: `{coverage.get('coveragePasses')}`",
            f"- Requested fixtures: `{coverage.get('requestedFixtureCount')}`",
            f"- Matched fixtures: `{coverage.get('matchedFixtureCount')}`",
            f"- Unmatched fixtures: `{coverage.get('unmatchedFixtureCount')}`",
            f"- Ambiguous fixtures: `{len(coverage.get('ambiguousFixtureIDs') or [])}`"
        ])
        freshness_failures = coverage.get("sourceFreshnessFailures") or []
        if freshness_failures:
            lines.append("- Source freshness failures: " + "; ".join(
                f"`{failure}`" for failure in freshness_failures
            ))
        failures = coverage.get("coverageFailures") or []
        if failures:
            lines.append("- Coverage failures: " + "; ".join(
                f"`{failure}`" for failure in failures
            ))
        source_failure_lines = render_source_app_path_failure_samples(coverage)
        if source_failure_lines:
            lines.extend(["", "### Source App-Path Failure Samples", ""])
            lines.extend(source_failure_lines)
    lines.extend(["", "## Worst Fixtures", ""])
    for row in summary["worstFixtures"]:
        reasons = "; ".join(row["failureReasons"]) or "no local failure reason"
        lines.append(f"- `{row['id']}` `{row['turnType']}`: `{row['overall']}/100` - {reasons}")
    return "\n".join(lines) + "\n"


def render_failures(report):
    lines = ["# Coach Arena Failures", ""]
    production_failures = (report.get("summary") or {}).get("productionEvidenceFailures") or []
    if production_failures:
        lines.extend(["## Production Evidence Gate", ""])
        for failure in production_failures:
            lines.append(f"- {failure}")
        source_failure_lines = render_source_app_path_failure_samples(
            report.get("coverage") or {},
            include_replies=True,
        )
        if source_failure_lines:
            lines.extend(["", "Source app-path failure samples:", ""])
            lines.extend(source_failure_lines)
        lines.append("")
    trace_quality_failures = (report.get("summary") or {}).get("traceQualityFailures") or []
    if trace_quality_failures:
        lines.extend(["## Trace Quality Gate", ""])
        for failure in trace_quality_failures:
            lines.append(f"- {failure}")
        trace_quality = (report.get("summary") or {}).get("traceQualityAudit") or {}
        repeated_hashes = ((trace_quality.get("proofTest") or {}).get("repeatedHashes") or {})
        if repeated_hashes:
            lines.append("")
            lines.append("Repeated proof-test hashes:")
            for proof_hash, fixture_ids in repeated_hashes.items():
                lines.append(f"- `{proof_hash}`: " + ", ".join(f"`{fixture_id}`" for fixture_id in fixture_ids))
        lines.append("")
    coverage_failures = (report.get("summary") or {}).get("coverageFailures") or []
    if coverage_failures:
        lines.extend(["## Coverage Gate", ""])
        for failure in coverage_failures:
            lines.append(f"- {failure}")
        coverage = report.get("coverage") or {}
        unmatched = coverage.get("unmatchedFixtureIDs") or []
        ambiguous = coverage.get("ambiguousFixtureIDs") or []
        if unmatched:
            lines.append("- Unmatched fixtures: " + ", ".join(f"`{fixture_id}`" for fixture_id in unmatched))
        if ambiguous:
            lines.append("- Ambiguous fixtures: " + ", ".join(f"`{fixture_id}`" for fixture_id in ambiguous))
        lines.append("")
    failures = [
        item for item in report["results"]
        if item["judge"]["overall"] < 70 or item["judge"]["checkFailures"]
    ]
    if not failures and not coverage_failures and not production_failures:
        return "# Coach Arena Failures\n\nNo local failures in this run.\n"
    if not failures:
        return "\n".join(lines).rstrip() + "\n"
    for item in failures:
        fixture = item["fixture"]
        judge = item["judge"]
        lines.extend([
            f"## {fixture['id']} ({fixture['turnType']})",
            "",
            f"Score: `{judge['overall']}/100`",
            "",
            f"User: {fixture['userTurn']}",
            "",
            "Failure reasons:",
        ])
        for reason in judge["failureReasons"] or ["No explicit reason; score below threshold."]:
            lines.append(f"- {reason}")
        lines.extend(["", "Suggested fix:", "", judge["suggestedFix"], ""])
    return "\n".join(lines)


def markdown_code_list(values, empty="none", limit=4):
    compact = [str(value) for value in values or [] if str(value).strip()]
    if not compact:
        return f"`{empty}`"
    shown = compact[:limit]
    rendered = ", ".join(f"`{value}`" for value in shown)
    omitted = len(compact) - len(shown)
    if omitted > 0:
        rendered += f", `+{omitted} more`"
    return rendered


def synthetic_source_freshness_audit(report):
    try:
        import readiness_gate
    except ImportError:
        return None
    readiness = report.get("visionProductionReadiness")
    if not isinstance(readiness, dict):
        summary = report.get("summary") if isinstance(report.get("summary"), dict) else {}
        readiness = summary.get("visionProductionReadiness")
    artifact_audit = readiness_gate.evidence_artifact_audit(
        readiness_gate.DEFAULT_DUMP_DIR,
        readiness if isinstance(readiness, dict) else None,
    )
    return readiness_gate.source_freshness_audit(report, artifact_audit)


def synthetic_evidence_status(report, source_audit=None):
    coverage = report.get("coverage") or {}
    if coverage.get("source") != "appPathReport":
        return None

    summary = report.get("summary") or {}
    evidence_passes = summary.get(
        "realPipelineEvidencePasses",
        summary.get("productionEvidencePasses"),
    )
    report_freshness_passes = coverage.get("sourceFreshnessPasses")
    if source_audit is None:
        source_audit = synthetic_source_freshness_audit(report)
    sidecar_freshness_passes = (
        source_audit.get("passes")
        if isinstance(source_audit, dict) else None
    )
    source_freshness_passes = report_freshness_passes
    if sidecar_freshness_passes is False or report_freshness_passes is False:
        source_freshness_passes = False

    if source_freshness_passes is False:
        status = "STALE APP-PATH SOURCE"
        instruction = (
            "Do not treat these conversations as current-source proof until "
            "the Swift app-path dump is regenerated and rescored."
        )
        sample_label = "stale app-path source"
        sample_instruction = (
            "this reply is from a stale Swift app-path dump; use it as "
            "diagnostic evidence only, not current-source proof."
        )
    elif evidence_passes is False:
        status = "LOCAL APP-PATH EVALUATION ONLY"
        instruction = (
            "Use these conversations for debugging shape, not as production "
            "readiness evidence."
        )
        sample_label = "local app-path evaluation only"
        sample_instruction = (
            "this reply is from the Swift app-path evaluator, but the real "
            "pipeline evidence gate is still red."
        )
    else:
        status = "CURRENT APP-PATH SOURCE"
        instruction = (
            "These conversations are backed by the current scored Swift "
            "app-path report."
        )
        sample_label = "current app-path source"
        sample_instruction = (
            "this reply is backed by the current scored Swift app-path report."
        )

    return {
        "coverage": coverage,
        "summary": summary,
        "sourceAudit": source_audit,
        "status": status,
        "instruction": instruction,
        "sampleLabel": sample_label,
        "sampleInstruction": sample_instruction,
        "sourceFreshnessPasses": source_freshness_passes,
        "reportFreshnessPasses": report_freshness_passes,
        "sidecarFreshnessPasses": sidecar_freshness_passes,
        "evidencePasses": evidence_passes,
    }


def render_synthetic_evidence_notice(report, source_audit=None):
    status = synthetic_evidence_status(report, source_audit=source_audit)
    if not status:
        return []

    coverage = status["coverage"]
    summary = status["summary"]
    source_audit = status["sourceAudit"]
    source_freshness_passes = status["sourceFreshnessPasses"]
    report_freshness_passes = status["reportFreshnessPasses"]
    sidecar_freshness_passes = status["sidecarFreshnessPasses"]
    evidence_passes = status["evidencePasses"]

    lines = [
        f"> Evidence status: {status['status']}.",
        f"> {status['instruction']}",
        f"> Source freshness passes: `{source_freshness_passes}`.",
        f"> Real-pipeline evidence passes: `{evidence_passes}`.",
    ]
    if report_freshness_passes is not None:
        lines.append(
            f"> Report-internal source freshness passes: `{report_freshness_passes}`."
        )
    if sidecar_freshness_passes is not None:
        lines.append(
            f"> Sidecar source freshness passes: `{sidecar_freshness_passes}`."
        )

    current_commit = coverage.get("currentGitCommit")
    if current_commit:
        lines.append(f"> Current git commit: `{current_commit}`.")
    trace_commits = coverage.get("sourceTraceGitCommits") or []
    if trace_commits or source_freshness_passes is False:
        lines.append(
            f"> Report trace git commit(s): {markdown_code_list(trace_commits)}."
        )

    current_fingerprint = coverage.get("currentCoachSourceFingerprint")
    if current_fingerprint:
        lines.append(f"> Current coach source fingerprint: `{current_fingerprint}`.")
    trace_fingerprints = coverage.get("sourceTraceCoachSourceFingerprints") or []
    if trace_fingerprints or source_freshness_passes is False:
        lines.append(
            "> Report trace coach source fingerprint(s): " +
            f"{markdown_code_list(trace_fingerprints)}."
        )
    if isinstance(source_audit, dict):
        sidecar_commit = source_audit.get("sidecarGitCommit")
        sidecar_fingerprint = source_audit.get("sidecarCoachFingerprint")
        if sidecar_commit:
            lines.append(f"> Sidecar git commit: `{sidecar_commit}`.")
        if sidecar_fingerprint:
            lines.append(
                f"> Sidecar coach source fingerprint: `{sidecar_fingerprint}`."
            )
        report_commits = source_audit.get("reportGitCommits") or []
        if report_commits and not trace_commits:
            lines.append(
                f"> Report trace git commit(s): {markdown_code_list(report_commits)}."
            )
        report_fingerprints = source_audit.get("reportCoachFingerprints") or []
        if report_fingerprints and not trace_fingerprints:
            lines.append(
                "> Report trace coach source fingerprint(s): " +
                f"{markdown_code_list(report_fingerprints)}."
            )
        for mismatch in source_audit.get("mismatches") or []:
            lines.append(
                f"> Sidecar/report mismatch `{mismatch.get('label')}`: "
                f"sidecar `{mismatch.get('sidecar')}`, report "
                f"{markdown_code_list(mismatch.get('reportValues') or [])}."
            )

    freshness_failures = coverage.get("sourceFreshnessFailures") or []
    if freshness_failures:
        lines.append(
            f"> Source freshness failures: {markdown_code_list(freshness_failures, limit=6)}."
        )
    production_failures = summary.get("productionEvidenceFailures") or []
    if production_failures:
        lines.append(
            f"> Production evidence failures: {markdown_code_list(production_failures, limit=6)}."
        )

    return lines


def render_ten_conversations(report, source_audit=None):
    lines = [
        "# Coach Arena Synthetic 10-Conversation Sample",
        "",
        "These are fixture-backed synthetic conversations for done-state review.",
        ""
    ]
    notice = render_synthetic_evidence_notice(report, source_audit=source_audit)
    if notice:
        lines.extend(notice)
        lines.append("")
    sample_status = synthetic_evidence_status(report, source_audit=source_audit)
    for item in report["results"][:10]:
        fixture = item["fixture"]
        lines.extend([
            f"## {fixture['id']}",
            "",
        ])
        if sample_status:
            lines.extend([
                f"Evidence: `{sample_status['sampleLabel']}` - {sample_status['sampleInstruction']}",
                "",
            ])
        lines.extend([
            f"Goal: {fixture['goal']}",
            "",
            "Prior chat:"
        ])
        if fixture["priorChatTurns"]:
            for turn in fixture["priorChatTurns"]:
                lines.append(f"- {turn['role']}: {turn['text']}")
        else:
            lines.append("- none")
        lines.extend([
            "",
            f"User: {fixture['userTurn']}",
            "",
            f"Noum: {item['reply']}",
            "",
            f"Arena score: {item['judge']['overall']}/100",
            ""
        ])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Run Noum Coach Arena.")
    parser.add_argument("--fixtures", default=str(DEFAULT_FIXTURES))
    parser.add_argument("--candidate", choices=["excellent", "bad", "empty"], default="excellent")
    parser.add_argument("--candidate-json")
    parser.add_argument("--app-path-report")
    parser.add_argument("--replay-command")
    parser.add_argument("--reports-dir", default=str(DEFAULT_REPORTS))
    parser.add_argument("--synthetic-dir", default=str(DEFAULT_SYNTHETIC))
    parser.add_argument("--write-app-path-source-sidecars")
    parser.add_argument("--app-path-preflight")
    parser.add_argument("--no-fail", action="store_true")
    args = parser.parse_args()

    if args.write_app_path_source_sidecars:
        payload = write_app_path_source_sidecars(args.write_app_path_source_sidecars)
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0
    if args.app_path_preflight:
        payload = app_path_regeneration_preflight(args.app_path_preflight)
        print(json.dumps(payload, indent=2, sort_keys=True))
        if payload["passes"] or args.no_fail:
            return 0
        return 1

    fixtures = load_fixtures(args.fixtures)
    candidate_modes = [
        bool(args.candidate_json),
        bool(args.app_path_report),
        bool(args.replay_command)
    ]
    if sum(candidate_modes) > 1:
        raise ValueError("use only one of --candidate-json, --app-path-report, or --replay-command")
    coverage = None
    if args.app_path_report:
        fixtures, candidate_map, coverage = load_app_path_candidates(args.app_path_report, fixtures)
    else:
        candidate_map = load_candidate_json(args.candidate_json) if args.candidate_json else None
    results = []
    git_commit = current_git_commit(short=True)
    if coverage is not None and coverage.get("source") == "appPathReport":
        coverage.update(app_path_source_freshness_fields(
            coverage,
            git_commit,
            current_dirty_coach_source_files(),
            coach_source_fingerprint(),
        ))

    for fixture in fixtures:
        reply, trace = candidate_for_fixture(args, fixture, candidate_map)
        trace = normalize_trace(trace, reply, git_commit)
        local = local_judge(fixture, reply, trace)
        llm = run_llm_judge(fixture, reply, trace, local)
        judge = local
        if llm and "overall" in llm:
            cap_max = min([cap["maxScore"] for cap in local["caps"] if cap.get("applied")], default=100)
            llm = dict(llm)
            llm["overall"] = min(int(llm["overall"]), cap_max)
            judge = {**local, "llmJudge": llm, "overall": llm["overall"]}
        elif llm:
            judge = {**local, "llmJudge": llm}
        results.append({
            "fixture": fixture,
            "reply": reply,
            "trace": trace,
            "judge": judge
        })

    report_dir, report_path_warnings = choose_report_dir(args)
    for warning in report_path_warnings:
        print(f"warning: {warning}", file=sys.stderr)
    previous_report = load_previous_report(report_dir)
    report = {
        "schemaVersion": "coach-arena-report-v1",
        "reportFamily": "app-path" if args.app_path_report else "python-reference",
        "reportPaths": {
            "currentReport": repo_relative(report_dir / "latest.md"),
            "promptLayerReport": repo_relative(DEFAULT_REPORTS / "latest.md"),
            "canonicalAppPathReport": repo_relative(CANONICAL_APP_PATH_REPORTS / "latest.md"),
        },
        "reportPathWarnings": report_path_warnings,
        "generatedAt": now_iso(),
        "candidate": args.candidate_json or args.app_path_report or args.replay_command or args.candidate,
        "coverage": coverage,
        "summary": summarize(results, coverage),
        "results": results
    }
    report["comparison"] = compare_reports(report, previous_report)
    write_reports(report, report_dir, Path(args.synthetic_dir))

    summary = report["summary"]
    print(json.dumps(summary, indent=2, sort_keys=True))
    if not args.no_fail and not summary["passes"]:
        return 1
    if not args.no_fail and args.app_path_report and not summary["realPipelineEvidencePasses"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
