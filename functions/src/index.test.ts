import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import test from "node:test";
import {
  assertCoachAccountBinding,
  assertTrustedCaller,
  assertSocialCallablesAvailable,
  buildVertexContents,
  type CoachGenerateContentResponse,
  coachCompletionLogMetadata,
  coachFailureLogMetadata,
  coachFailureQualityMetadata,
  consumeCoachStream,
  generateCoachCompletionWithRepair,
  isAcceptableFinishReason,
  maxOutputTokensForRequest,
  modelForQualityTier,
  nextRateState,
  normalizeCoachTurnDepth,
  normalizeCoachResponseKind,
  normalizeCoachVoice,
  normalizeQualityTier,
  thinkingBudgetForModel,
  validateCoachChatRequest,
  validateLegacyCoachChatRequest,
} from "./index.js";
import {
  LEGACY_COACH_SYSTEM_POLICY,
  buildLegacyVertexContents,
  consumeLegacyCoachStream,
  generateLegacyCoachCompletion,
  legacyCoachGenerationConfig,
  type LegacyCoachGenerateContentResponse,
  type LegacyCoachChatInput,
} from "./legacyCoachV1.js";
import {
  COACH_POLICY_VERSION,
  coachBriefRetainsRecentMove,
  coachTurnRequestsMove,
  coachReplyPolicyIssue,
  coachReplyWithoutObserverPromise,
  coachSystemPolicyForRequest,
  maxCoachReplySentences,
  maxCoachReplyWords,
  thinkingBudgetForQualityTier,
} from "./coachPolicy.js";
import {FinishReason} from "@google/genai";
import {HttpsError} from "firebase-functions/v2/https";

const request = {
  schemaVersion: 2,
  accountID: "firebase-account-123",
  requestID: "2cb446d8-4f39-43a6-a95c-2486e47155bc",
  surface: "text",
  qualityTier: "fast",
  coachVoice: "concise",
  turnDepth: "quickMove",
  turnIntent: "coaching",
  responseKind: "personalEvidenceRead",
  coachingBrief: {
    evidenceStrength: "weak",
    directVerdict: "The evidence is too thin to name a repeated pattern.",
    decisiveEvidence: [
      "The available app practice rep placed setup before the recommendation.",
    ].join(""),
    nextMove: "Put the recommendation first in the next practice.",
    missingEvidence: "A comparable follow-up rep is missing.",
    repairFocus: null,
  },
  verifiedQuoteSources: ["The speaker said: we should wait."],
  coachingContext: "One completed rep. Evidence remains early.",
  messages: [{role: "user", content: "What should I fix first?"}],
};

const authorizedSwiftMoves = [
  "Advance the read: keep the prior target, but change the proof to the " +
    "next observable sentence.",
  "Repair the same answer in plain speech: no markdown, one specific read, " +
    "one move.",
  "Log the outcome as a field note, then repeat one pressure rep and check " +
    "the same observable target.",
  "Replay the answer once and replace one hedge with a direct recommendation.",
  "Place one silent beat after the verdict, then finish the reason in one " +
    "sentence.",
  "Add one concrete example after the verdict, then stop before a second " +
    "example.",
  "Test a smaller version in the next rep: say only the disagreement and one " +
    "calm reason, then stop before defending it.",
  // Retain compatibility with the earlier memory-handoff move while newly
  // generated memory turns use the safer explicit test/drop construction.
  "Keep the prior target and test it in the next pressure rep.",
] as const;

interface HttpsErrorShape {
  code?: string;
  details?: {reason?: string};
}

/**
 * Returns the shared account-deletion executor from the source contract.
 * @param {string} source Function source.
 * @return {string} Shared deletion executor source.
 */
function deletionExecutorSource(source: string): string {
  const start = source.indexOf("async function executeAccountDeletion(");
  const end = source.indexOf("export const deleteAccount", start);
  assert.equal(start >= 0 && end > start, true);
  return source.slice(start, end);
}

test("validates the versioned coach request", () => {
  assert.deepEqual(validateCoachChatRequest(request), request);
});

test("validates and grounds a typed latest-rep metric read", async () => {
  const sourceSessionID = "6af73432-1cf0-4ccd-971f-94da2d2019e5";
  const input = validateCoachChatRequest({
    ...request,
    turnDepth: "groundedRead",
    messages: [{role: "user", content: "What was my filler count?"}],
    coachingBrief: {
      evidenceStrength: "weak",
      directVerdict: "Your latest Ah Counter rep had 3 fillers in 60 seconds.",
      decisiveEvidence: "latest Ah Counter rep, 60 seconds, 3 fillers",
      nextMove: null,
      missingEvidence: null,
      repairFocus: null,
      evidenceReadKind: "latestRepMetrics",
      requestedMetrics: ["fillerCount"],
      latestRepMetrics: {
        sourceSessionID,
        comparisonMetricSchemaVersion: 2,
        mode: "Ah Counter",
        score: 3,
        fillerCount: 3,
        fillerRatePerMinute: 3,
        paceWordsPerMinute: 120,
        durationSeconds: 60,
        transcriptWordCount: 120,
      },
    },
  });
  assert.equal(input.coachingBrief?.evidenceReadKind, "latestRepMetrics");
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "Your latest Ah Counter rep had 3 fillers in 60 seconds."
    ),
    null
  );
  assert.equal(
    coachReplyPolicyIssue(input, "Your latest rep scored 3/10."),
    "missing-metric-read"
  );
  const prompt = buildVertexContents(input)
    .flatMap((content) => content.parts)
    .map((part) => part.text)
    .join("\n");
  assert.match(prompt, /Typed metric evidence: latest Ah Counter rep/u);
  assert.doesNotMatch(prompt, new RegExp(sourceSessionID, "u"));
  const latestBrief = input.coachingBrief;
  assert.ok(latestBrief);
  const rateInput = validateCoachChatRequest({
    ...request,
    turnDepth: "groundedRead",
    messages: [{role: "user", content: "What was my filler rate?"}],
    coachingBrief: {
      ...latestBrief,
      directVerdict:
        "You averaged 3.0 fillers per minute in your latest Ah Counter rep.",
      requestedMetrics: ["fillerRatePerMinute"],
    },
  });
  assert.equal(
    coachReplyPolicyIssue(
      rateInput,
      "You averaged 3.0 fillers per minute in your latest Ah Counter rep."
    ),
    null
  );
  for (const typedInput of [input, rateInput]) {
    let attempts = 0;
    const result = await generateCoachCompletionWithRepair(
      typedInput,
      "gemini-2.5-flash",
      buildVertexContents(typedInput),
      {
        generate: async () => {
          attempts += 1;
          return vertexStream(["A model must not run for this typed read."]);
        },
      }
    );
    assert.equal(attempts, 0);
    assert.equal(result.completion.generationMode, "deterministic-brief");
    assert.equal(
      result.completion.text,
      typedInput.coachingBrief?.directVerdict
    );
  }
});

test(
  "validates a qualified longitudinal read without broadening it",
  async () => {
    const sourceSessionID = "90d0bd18-f706-40fb-9734-a355c587171b";
    const firstPriorID = "2e8d6761-b531-431f-b519-43f27d58166c";
    const secondPriorID = "f8a3ed0c-130e-4db1-9b16-371834c6296d";
    const input = validateCoachChatRequest({
      ...request,
      turnDepth: "deepAssessment",
      messages: [{role: "user", content: "Am I improving?"}],
      coachingBrief: {
        evidenceStrength: "repeated",
        directVerdict: [
          "There’s a positive signal in your latest Ah Counter rep, but I ",
          "wouldn’t call it overall improvement yet. Compared with 2 earlier ",
          "reps using the same setup, score was 8.0/10 versus 7.0/10. This is ",
          "practice evidence in Noum, not proof of transfer to real ",
          "conversations.",
        ].join(""),
        decisiveEvidence: "score 8.0/10 versus 7.0/10",
        nextMove: null,
        missingEvidence: "This reflects practice in Noum only.",
        repairFocus: null,
        evidenceReadKind: "longitudinalTrend",
        longitudinalTrend: {
          sourceSessionID,
          comparisonMetricSchemaVersion: 2,
          mode: "Ah Counter",
          comparableSessionIDs: [firstPriorID, secondPriorID],
          metrics: [{
            metric: "score",
            direction: "improving",
            currentValue: 8,
            priorAverage: 7,
          }],
        },
      },
    });
    assert.equal(
      coachReplyPolicyIssue(input, input.coachingBrief?.directVerdict ?? ""),
      null
    );
    assert.equal(
      coachReplyPolicyIssue(input, "You are definitely improving overall."),
      "missing-trend-read"
    );
    assert.equal(
      coachReplyPolicyIssue(
        input,
        "Your latest Ah Counter rep moved in the wrong direction. " +
        "Compared with 2 earlier reps using the same setup, score was " +
        "8.0/10 versus 7.0/10. This is a signal, not a broad verdict."
      ),
      "missing-trend-read"
    );
    const trendBrief = input.coachingBrief;
    assert.ok(trendBrief?.longitudinalTrend);
    assert.throws(() => validateCoachChatRequest({
      ...request,
      turnDepth: "deepAssessment",
      messages: [{role: "user", content: "Am I improving?"}],
      coachingBrief: {
        ...trendBrief,
        longitudinalTrend: {
          ...trendBrief.longitudinalTrend,
          metrics: [{
            metric: "score",
            direction: "declining",
            currentValue: 8,
            priorAverage: 7,
          }],
        },
      },
    }));
    const roundedBoundary = validateCoachChatRequest({
      ...request,
      turnDepth: "deepAssessment",
      messages: [{role: "user", content: "Is my filler rate improving?"}],
      coachingBrief: {
        ...trendBrief,
        directVerdict: [
          "There’s a positive signal in your latest Ah Counter rep, but I ",
          "wouldn’t call it overall improvement yet. Compared with 2 earlier ",
          "reps using the same setup, filler rate was 2.0 per minute versus ",
          "2.8 per minute. This is practice evidence in Noum, not proof of ",
          "transfer to real conversations.",
        ].join(""),
        decisiveEvidence: "filler rate 2.0/min versus 2.8/min",
        longitudinalTrend: {
          ...trendBrief.longitudinalTrend,
          metrics: [{
            metric: "fillerRatePerMinute",
            direction: "improving",
            currentValue: 2.0,
            priorAverage: 2.8,
          }],
        },
      },
    });
    assert.equal(
      roundedBoundary.coachingBrief?.longitudinalTrend?.metrics[0].direction,
      "improving"
    );
    assert.throws(() => validateCoachChatRequest({
      ...roundedBoundary,
      coachingBrief: {
        ...roundedBoundary.coachingBrief,
        longitudinalTrend: {
          ...roundedBoundary.coachingBrief?.longitudinalTrend,
          metrics: [{
            metric: "fillerRatePerMinute",
            direction: "stable",
            currentValue: 2.0,
            priorAverage: 2.8,
          }],
        },
      },
    }));
    const prompt = buildVertexContents(input)
      .flatMap((content) => content.parts)
      .map((part) => part.text)
      .join("\n");
    assert.match(prompt, /2 earlier comparable reps/u);
    assert.doesNotMatch(prompt, new RegExp(sourceSessionID, "u"));
    assert.doesNotMatch(prompt, new RegExp(firstPriorID, "u"));
    let attempts = 0;
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-pro",
      buildVertexContents(input),
      {
        generate: async () => {
          attempts += 1;
          return vertexStream(["A model must not run for this typed read."]);
        },
      }
    );
    assert.equal(attempts, 0);
    assert.equal(result.completion.generationMode, "deterministic-brief");
    assert.equal(result.completion.text, input.coachingBrief?.directVerdict);
  }
);

test("rejects malformed or leaked typed metric projections", () => {
  const latestBrief = {
    evidenceStrength: "weak",
    directVerdict: "Your latest rep scored 7/10.",
    decisiveEvidence: "score 7/10",
    nextMove: null,
    missingEvidence: null,
    repairFocus: null,
    evidenceReadKind: "latestRepMetrics",
    requestedMetrics: ["score"],
    latestRepMetrics: {
      sourceSessionID: "f8f024cc-778b-4df2-a373-bbb7fb50b728",
      comparisonMetricSchemaVersion: 2,
      mode: "Timed",
      score: 7,
      durationSeconds: 60,
      transcriptWordCount: 100,
    },
  };
  assert.throws(() => validateCoachChatRequest({
    ...request,
    coachingBrief: {
      ...latestBrief,
      latestRepMetrics: {
        ...latestBrief.latestRepMetrics,
        comparisonMetricSchemaVersion: 1,
      },
    },
  }));
  assert.throws(() => validateCoachChatRequest({
    ...request,
    responseKind: "generalCoaching",
    coachingBrief: latestBrief,
  }));
  assert.throws(() => validateCoachChatRequest({
    ...request,
    unexpectedProjection: true,
  }));
});

test("normalizes legacy tiers and routes Fast and Ultra models", () => {
  assert.equal(normalizeQualityTier("geminiFast"), "fast");
  assert.equal(normalizeQualityTier("claudeReasoning"), "ultra");
  assert.equal(modelForQualityTier("fast", "flash", "pro"), "flash");
  assert.equal(modelForQualityTier("ultra", "flash", "pro"), "pro");
});

test(
  "validates coaching frame and defaults omitted frame fields conservatively",
  () => {
    assert.equal(normalizeCoachVoice("executive"), "executive");
    assert.equal(normalizeCoachVoice(undefined), null);
    assert.equal(normalizeCoachTurnDepth("trustRepair"), "trustRepair");
    assert.equal(normalizeCoachTurnDepth(undefined), "groundedRead");
    assert.equal(
      normalizeCoachResponseKind("generalCoaching"),
      "generalCoaching"
    );

    const unframedRequest: Record<string, unknown> = {...request};
    delete unframedRequest.coachVoice;
    delete unframedRequest.turnDepth;
    delete unframedRequest.turnIntent;
    delete unframedRequest.coachingBrief;
    delete unframedRequest.verifiedQuoteSources;
    const normalized = validateCoachChatRequest(unframedRequest);
    assert.equal(normalized.coachVoice, null);
    assert.equal(normalized.turnDepth, "groundedRead");
    assert.equal(normalized.turnIntent, "unknown");
    assert.equal(normalized.responseKind, "personalEvidenceRead");
    assert.equal(normalized.coachingBrief, null);
    assert.deepEqual(normalized.verifiedQuoteSources, []);
    assert.equal(normalized.schemaVersion, 2);
    assert.equal(normalized.accountID, request.accountID);
    assert.equal(normalized.coachingContext, request.coachingContext);
    assert.deepEqual(normalized.messages, [request.messages.at(-1)]);
    assert.throws(() => normalizeCoachVoice("dominant"));
    assert.throws(() => normalizeCoachTurnDepth("longReport"));
    assert.throws(() => normalizeCoachResponseKind(undefined));
  }
);

test("rejects contradictory response-kind and intent frames", () => {
  assert.doesNotThrow(() => validateCoachChatRequest({
    ...request,
    turnIntent: "greeting",
    responseKind: "conversational",
    coachingBrief: null,
  }));
  assert.doesNotThrow(() => validateCoachChatRequest({
    ...request,
    turnIntent: "unknown",
    responseKind: "personalEvidenceRead",
    coachingBrief: null,
  }));
  for (const turnIntent of [
    "greeting", "offTopic", "preference", "vulnerable",
  ] as const) {
    assert.doesNotThrow(() => validateCoachChatRequest({
      ...request,
      turnIntent,
      responseKind: "conversational",
      coachingBrief: null,
    }));
  }
  for (const turnIntent of ["coaching", "unknown"] as const) {
    for (const responseKind of [
      "personalEvidenceRead", "generalCoaching", "memoryHandoff",
    ] as const) {
      assert.doesNotThrow(() => validateCoachChatRequest({
        ...request,
        turnIntent,
        responseKind,
        coachingBrief: responseKind === "generalCoaching" ? null :
          request.coachingBrief,
      }));
    }
  }

  for (const patch of [
    {
      turnIntent: "greeting",
      responseKind: "personalEvidenceRead",
      coachingBrief: null,
    },
    {
      turnIntent: "greeting",
      responseKind: "conversational",
      coachingBrief: request.coachingBrief,
    },
    {
      turnIntent: "coaching",
      responseKind: "conversational",
      coachingBrief: null,
    },
    {
      turnIntent: "unknown",
      responseKind: "conversational",
      coachingBrief: null,
    },
    {
      turnIntent: "vulnerable",
      responseKind: "memoryHandoff",
      coachingBrief: null,
    },
    {
      turnIntent: "coaching",
      responseKind: "generalCoaching",
      coachingBrief: request.coachingBrief,
    },
  ]) {
    assert.throws(
      () => validateCoachChatRequest({...request, ...patch}),
      (error: unknown) =>
        (error as HttpsErrorShape).code === "invalid-argument"
    );
  }
});

test("shipping coach policy is concise, grounded, and frame-specific", () => {
  const standard = coachSystemPolicyForRequest({
    surface: "text",
    turnDepth: "groundedRead",
    turnIntent: "coaching",
    responseKind: "personalEvidenceRead",
    coachVoice: "warm",
  });
  assert.match(standard, new RegExp(COACH_POLICY_VERSION));
  assert.match(standard, /actual question in the first sentence/i);
  assert.match(
    standard,
    /Never\s+repeat the diagnosis, evidence, action, or success sign/i
  );
  assert.match(standard, /Never invent a quote, number, duration, score/i);
  assert.match(standard, /practice rep as a meeting, interview, presentation/i);
  assert.match(standard, /one question that would change the recommendation/i);
  assert.match(standard, /no more than 50 words/i);
  assert.match(standard, /candid, natural, and encouraging/i);

  const repair = coachSystemPolicyForRequest({
    surface: "text",
    turnDepth: "trustRepair",
    turnIntent: "coaching",
    responseKind: "personalEvidenceRead",
    coachVoice: null,
  });
  assert.match(repair, /own the specific miss/i);
  assert.match(repair, /Do not defend or restate the rejected advice/i);

  const live = coachSystemPolicyForRequest({
    surface: "live",
    turnDepth: "deepAssessment",
    turnIntent: "coaching",
    responseKind: "personalEvidenceRead",
    coachVoice: "executive",
  });
  assert.match(live, /one or two short sentences/i);
  assert.match(live, /no more than 35 words/i);

  const general = coachSystemPolicyForRequest({
    surface: "text",
    turnDepth: "groundedRead",
    turnIntent: "coaching",
    responseKind: "generalCoaching",
    coachVoice: null,
  });
  assert.match(general, /answer the craft question directly/i);
  assert.match(general, /do not insert a personal evidence gap/i);
  assert.match(general, /one\s+communication reason/i);

  const memory = coachSystemPolicyForRequest({
    surface: "text",
    turnDepth: "groundedRead",
    turnIntent: "coaching",
    responseKind: "memoryHandoff",
    coachVoice: null,
  });
  assert.match(memory, /What I'd carry forward for now/i);
  assert.match(memory, /Do not use the internal phrase testable hypothesis/i);
});

test("coach reply ceilings match every visible response lane", () => {
  const personal = {
    surface: "text",
    turnDepth: "groundedRead",
    turnIntent: "coaching",
    responseKind: "personalEvidenceRead",
    coachVoice: null,
  } as const;
  assert.equal(maxCoachReplyWords(personal), 50);
  assert.equal(maxCoachReplySentences(personal), 2);
  assert.equal(
    maxCoachReplyWords({...personal, turnDepth: "deepAssessment"}),
    90
  );
  assert.equal(
    maxCoachReplySentences({...personal, turnDepth: "deepAssessment"}),
    5
  );
  assert.equal(
    maxCoachReplyWords({...personal, turnDepth: "trustRepair"}),
    45
  );
  assert.equal(
    maxCoachReplyWords({...personal, responseKind: "generalCoaching"}),
    45
  );
  assert.equal(
    maxCoachReplySentences({...personal, responseKind: "generalCoaching"}),
    3
  );
  assert.equal(
    maxCoachReplyWords({...personal, responseKind: "memoryHandoff"}),
    50
  );
  assert.equal(maxCoachReplyWords({
    ...personal,
    turnIntent: "greeting",
    responseKind: "conversational",
  }), 30);
  assert.equal(maxCoachReplyWords({...personal, surface: "live"}), 35);
  assert.equal(maxCoachReplySentences({...personal, surface: "live"}), 2);
});

test("a stored move appears only when the current turn asks for action", () => {
  const actionRequest = validateCoachChatRequest(request);
  assert.equal(coachTurnRequestsMove(actionRequest), true);
  for (const actionTurn of [
    "What could I change first?",
    "How would I make this clearer?",
    "Do you have any advice?",
    "What would you recommend?",
    "What's the best way to practice this?",
    "What is the best way to practise this?",
  ]) {
    const paraphrasedRequest = validateCoachChatRequest({
      ...request,
      messages: [{role: "user", content: actionTurn}],
    });
    assert.equal(coachTurnRequestsMove(paraphrasedRequest), true, actionTurn);
  }

  const explanationRequest = validateCoachChatRequest({
    ...request,
    messages: [{
      role: "user",
      content: "Why did that practice answer feel repetitive?",
    }],
  });
  assert.equal(coachTurnRequestsMove(explanationRequest), false);
  const practiceObservation = validateCoachChatRequest({
    ...request,
    messages: [{
      role: "user",
      content: "That practice answer felt repetitive.",
    }],
  });
  assert.equal(coachTurnRequestsMove(practiceObservation), false);
  assert.equal(
    coachReplyPolicyIssue(
      explanationRequest,
      "The available app practice rep placed setup before the recommendation."
    ),
    null
  );
  for (const unsolicitedReply of [
    "The available app practice rep placed setup before the recommendation. " +
      "Put the recommendation first in the next practice.",
    "Because the setup arrived first, you should put the recommendation " +
      "first in the next practice.",
    "The next move would be to put the recommendation first in the next " +
      "practice.",
    "One thing worth doing is to put the recommendation first in the next " +
      "practice.",
  ]) {
    assert.equal(
      coachReplyPolicyIssue(explanationRequest, unsolicitedReply),
      "unsolicited-action",
      unsolicitedReply
    );
  }

  assert.equal(
    coachReplyPolicyIssue(
      actionRequest,
      "Put the recommendation first in the next practice because the " +
        "available app practice rep placed setup before it."
    ),
    null
  );

  const generalCraftRequest = validateCoachChatRequest({
    ...request,
    responseKind: "generalCoaching",
    coachingBrief: null,
    messages: [{
      role: "user",
      content: "Why does an answer-first structure work?",
    }],
  });
  assert.equal(
    coachReplyPolicyIssue(
      generalCraftRequest,
      "Lead with the answer so the listener can place the reason that follows."
    ),
    null
  );
  assert.equal(
    coachReplyPolicyIssue(
      generalCraftRequest,
      "Answer-first works because it lets the listener locate the point " +
        "before the support."
    ),
    null
  );
});

test("an unsolicited move is invisibly rewritten as the requested read",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      messages: [{
        role: "user",
        content: "Why did that practice answer feel repetitive?",
      }],
    });
    const calls: string[] = [];
    const generations = [
      vertexStream([
        "The available app practice rep placed setup before the " +
          "recommendation. Put the recommendation first in the next practice.",
      ]),
      vertexStream([
        "The available app practice rep placed setup before the " +
          "recommendation.",
      ]),
    ];
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-flash",
      buildVertexContents(input),
      {
        generate: async (contents) => {
          calls.push(JSON.stringify(contents));
          const generation = generations.shift();
          assert.ok(generation);
          return generation;
        },
      }
    );

    assert.equal(calls.length, 2);
    assert.match(calls[1], /rejected for unsolicited-action/);
    assert.match(calls[1], /do not add a next move or exercise/);
    assert.equal(result.repaired, true);
    assert.equal(result.completion.generationMode, "model-rewrite");
    assert.equal(
      result.completion.text,
      "The available app practice rep placed setup before the recommendation."
    );
  });

test("two unsolicited drafts fall back to the evidence-only typed read",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      messages: [{
        role: "user",
        content: "Why did that practice answer feel repetitive?",
      }],
    });
    let attempts = 0;
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-flash",
      buildVertexContents(input),
      {
        generate: async () => {
          attempts += 1;
          return vertexStream([
            "The available app practice rep placed setup before the " +
              "recommendation. Put the recommendation first in the next " +
              "practice.",
          ]);
        },
      }
    );

    assert.equal(attempts, 2);
    assert.equal(result.repaired, true);
    assert.equal(result.completion.generationMode, "deterministic-brief");
    assert.equal(
      result.completion.text,
      "The available app practice rep placed setup before the recommendation."
    );
  });

test(
  "observer-promise removal preserves only complete grounded sentences",
  () => {
    assert.equal(
      coachReplyWithoutObserverPromise(
        "Put the recommendation first because the setup came first. " +
      "I'll watch for that order."
      ),
      "Put the recommendation first because the setup came first."
    );
    assert.equal(
      coachReplyWithoutObserverPromise(
        "Put the recommendation first; I'll watch for that order."
      ),
      null
    );
  }
);

test("thinking budgets preserve visible reply capacity on both models", () => {
  assert.equal(thinkingBudgetForQualityTier("fast"), 0);
  assert.equal(thinkingBudgetForQualityTier("ultra"), 128);
  assert.equal(
    thinkingBudgetForQualityTier("ultra") <
      maxOutputTokensForRequest("text", "ultra"),
    true
  );
});

test("reply evidence gate rejects invented and repetitive coaching", () => {
  const input = validateCoachChatRequest(request);
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "You paused for 2 seconds before your recommendation."
    ),
    "invented-number"
  );
  assert.equal(
    coachReplyPolicyIssue(input, "You said \"we should wait\" in the meeting."),
    "invented-setting"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "Use this pressure proof as the next move."
    ),
    "internal-language"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "Your mind is protecting you from a perceived threat."
    ),
    "invented-mechanism"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "It's great that you're thinking about your confidence."
    ),
    "generic-opener"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "Open with the main point and your score should go up."
    ),
    "outcome-promise"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "Hold one silent beat because that silence reads as composure and " +
        "stops the filler before it starts."
    ),
    "outcome-promise"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "Your fillers came because the recommendation did not lead, and the " +
        "rush to fill silence brings out the um. This explanation is " +
        "deliberately padded beyond the ordinary reply ceiling so evidence " +
        "safety must still win over compression during repair."
    ),
    "outcome-promise"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "I'll know you've got it when the recommendation comes first."
    ),
    "coach-observer-promise"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "I'll be able to tell whether your confidence changed."
    ),
    "coach-observer-promise"
  );
  const trustRepairInput = validateCoachChatRequest({
    ...request,
    turnDepth: "trustRepair",
  });
  assert.equal(
    coachReplyPolicyIssue(
      trustRepairInput,
      "You are right. For the next answer, I will state the decision first."
    ),
    "deferred-repair"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "Your exact words were \"we should wait\"."
    ),
    "missing-move-grounding"
  );
  assert.equal(
    coachReplyPolicyIssue(input, "You said \"we should rush\"."),
    "invented-quote"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "Put your recommendation first in the next practice."
    ),
    "missing-evidence-grounding"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "You are meeting the clarity standard, but the close is still soft."
    ),
    "missing-move-grounding"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "Lead with the recommendation. Put the recommendation first."
    ),
    "repeated-sentence"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      [
        "Lead with the decision, then support it with the relevant detail.",
        "State your decision in the first sentence, then give one reason.",
      ].join(" ")
    ),
    "repeated-action"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      [
        "Your recommendation is clear.",
        "Keep the recommendation first and stop after the evidence.",
      ].join(" ")
    ),
    "missing-evidence-grounding"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "The app practice rep placed setup first, so put your recommendation " +
        "first in the next practice."
    ),
    null
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "The app practice rep placed setup before the recommendation, so " +
        "practice breathing before you answer."
    ),
    "missing-move-grounding"
  );

  for (const turnIntent of [
    "greeting", "offTopic", "preference", "vulnerable",
  ] as const) {
    const nonCoaching = validateCoachChatRequest({
      ...request,
      turnIntent,
      responseKind: "conversational",
      coachingBrief: null,
    });
    assert.equal(
      coachReplyPolicyIssue(
        nonCoaching,
        "Hi. Because the recommendation matters, put it first."
      ),
      "non-coaching-prescription"
    );
    assert.equal(
      coachReplyPolicyIssue(nonCoaching, "You should pause."),
      "non-coaching-prescription"
    );
    assert.equal(
      coachReplyPolicyIssue(nonCoaching, "You can start."),
      "non-coaching-prescription"
    );
    for (const reply of [
      "Fair, so say the point first.",
      "Fair, then hold one silent beat.",
      "Fair, make the final sentence the ask.",
      "Fair, end with the decision.",
    ]) {
      assert.equal(
        coachReplyPolicyIssue(nonCoaching, reply),
        "non-coaching-prescription"
      );
    }
    assert.equal(
      coachReplyPolicyIssue(nonCoaching, "Hi, good to see you."),
      null
    );
    assert.equal(
      coachReplyPolicyIssue(
        nonCoaching,
        "Fair—the wording mattered because the answer was unclear."
      ),
      null
    );
  }
  const reporterStyleRepair = validateCoachChatRequest({
    ...request,
    turnDepth: "trustRepair",
    turnIntent: "preference",
    responseKind: "conversational",
    coachingBrief: null,
    messages: [{
      role: "user",
      content: "it just says weird wording and too much redundant wording, " +
        "doesn’t feel like a human expert communications coach at all",
    }],
  });
  assert.equal(
    coachReplyPolicyIssue(
      reporterStyleRepair,
      "You’re right—I repeated the point. I’ll answer once and directly " +
        "from here."
    ),
    null
  );
  assert.doesNotMatch(
    coachSystemPolicyForRequest(reporterStyleRepair),
    /give a changed next move/i
  );

  const repeatedPriorAction = validateCoachChatRequest({
    ...request,
    messages: [
      {
        role: "assistant",
        content: [
          "The setup came first, so put the recommendation first,",
          "then give one reason.",
        ].join(" "),
      },
      {role: "user", content: "What should I fix now?"},
    ],
  });
  assert.equal(
    coachReplyPolicyIssue(
      repeatedPriorAction,
      "Put the recommendation first, then give one reason."
    ),
    "repeated-prior-action"
  );
  assert.equal(coachBriefRetainsRecentMove(repeatedPriorAction), true);
  assert.equal(
    coachReplyPolicyIssue(
      repeatedPriorAction,
      [
        "The available app practice rep placed setup before the " +
          "recommendation.",
        "Lead with the decision, then give one reason.",
      ].join(" ")
    ),
    "repeated-prior-action"
  );
  assert.equal(
    coachReplyPolicyIssue(
      repeatedPriorAction,
      [
        "The available app practice rep placed setup before the " +
          "recommendation.",
        "Stay with that focus for the next rep.",
      ].join(" ")
    ),
    null
  );
  const retainedMoveWasNotRequested = validateCoachChatRequest({
    ...repeatedPriorAction,
    messages: [
      ...repeatedPriorAction.messages.slice(0, -1),
      {role: "user", content: "Why did that answer feel repetitive?"},
    ],
  });
  assert.equal(
    coachReplyPolicyIssue(
      retainedMoveWasNotRequested,
      [
        "The available app practice rep placed setup before the " +
          "recommendation.",
        "Stay with that focus for the next rep.",
      ].join(" ")
    ),
    "unsolicited-action"
  );

  const pollutedHistory = validateCoachChatRequest({
    ...request,
    coachingBrief: null,
    verifiedQuoteSources: [],
    coachingContext: [
      "Generic options include interview or meeting preparation.",
      "An instruction example may mention 60 seconds.",
    ].join(" "),
    messages: [
      {
        role: "assistant",
        content: "Your meeting had a 27-second pause.",
      },
      {role: "user", content: "What should I change?"},
    ],
  });
  assert.equal(
    coachReplyPolicyIssue(
      pollutedHistory,
      "In the meeting, remove the 27-second pause."
    ),
    "invented-setting"
  );
  assert.equal(
    coachReplyPolicyIssue(
      pollutedHistory,
      "Your last meeting showed the same delay."
    ),
    "invented-setting"
  );

  const compatibleLegacyContext = validateCoachChatRequest({
    ...request,
    coachingBrief: null,
    verifiedQuoteSources: [],
    coachingContext: [
      "VERIFIED RECENT REP: 2 fillers across 60 seconds.",
      "VERIFIED EXCERPT: we should decide before we explain.",
    ].join("\n"),
  });
  assert.equal(
    coachReplyPolicyIssue(
      compatibleLegacyContext,
      "The recent rep had 2 fillers across 60 seconds."
    ),
    "unverified-personal-read"
  );
  assert.equal(
    coachReplyPolicyIssue(
      compatibleLegacyContext,
      "Your last answer gave the recommendation after the setup."
    ),
    "unverified-personal-read"
  );
  assert.equal(
    coachReplyPolicyIssue(
      compatibleLegacyContext,
      "Your exact words were \"we should decide before we explain\"."
    ),
    "invented-quote"
  );
  const compatibleVerifiedQuote = validateCoachChatRequest({
    ...compatibleLegacyContext,
    verifiedQuoteSources: ["we should decide before we explain"],
  });
  assert.equal(
    coachReplyPolicyIssue(
      compatibleVerifiedQuote,
      "Your exact words were \"we should decide before we explain\"."
    ),
    "missing-evidence-clarification"
  );

  const noMoveInput = validateCoachChatRequest({
    ...request,
    coachingBrief: {
      evidenceStrength: "missing",
      directVerdict:
        "I don’t have enough evidence to choose your next move yet.",
      decisiveEvidence: null,
      nextMove: null,
      missingEvidence: "A comparable answer is missing.",
      repairFocus: null,
    },
  });
  assert.equal(
    coachReplyPolicyIssue(
      noMoveInput,
      "There is not enough comparable evidence yet. Answer a similar prompt."
    ),
    "invented-action"
  );
  assert.equal(
    coachReplyPolicyIssue(
      noMoveInput,
      [
        "There is not enough comparable evidence yet.",
        "To compare, say how confident you feel on a scale of one to ten.",
      ].join(" ")
    ),
    "invented-action"
  );
  assert.equal(
    coachReplyPolicyIssue(
      noMoveInput,
      "There is not enough comparable evidence yet, so record another rep."
    ),
    "invented-action"
  );
  assert.equal(
    coachReplyPolicyIssue(
      noMoveInput,
      "There is not enough comparable evidence yet; and then say it again."
    ),
    "invented-action"
  );
  assert.equal(
    coachReplyPolicyIssue(
      noMoveInput,
      "There is not enough comparable evidence yet — therefore you might " +
        "record another rep."
    ),
    "invented-action"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "Use a confidence scale of one to ten before the next practice."
    ),
    "invented-number"
  );
});

test("direct evaluations require exact metric provenance", () => {
  const directEvaluation = validateCoachChatRequest({
    ...request,
    turnDepth: "groundedRead",
    messages: [{role: "user", content: "How did I do?"}],
  });
  assert.equal(
    coachReplyPolicyIssue(
      directEvaluation,
      "The latest measured rep had 5 fillers."
    ),
    "invented-number"
  );

  const measuredEvaluation = validateCoachChatRequest({
    ...directEvaluation,
    coachingBrief: {
      ...request.coachingBrief,
      directVerdict: "The filler result is an early signal, not a pattern.",
      decisiveEvidence: "The latest measured rep had 5 fillers in 60 seconds.",
    },
  });
  assert.equal(
    coachReplyPolicyIssue(
      measuredEvaluation,
      "The latest measured rep had 5 fillers in 60 seconds."
    ),
    null
  );
  assert.equal(
    coachReplyPolicyIssue(measuredEvaluation, "Your score was 5."),
    "invented-number"
  );

  const userReportedEvaluation = validateCoachChatRequest({
    ...directEvaluation,
    messages: [{
      role: "user",
      content: "I counted 5 fillers. How did I do?",
    }],
  });
  assert.equal(
    coachReplyPolicyIssue(userReportedEvaluation, "You had 5 fillers."),
    "invented-number"
  );
  assert.equal(
    coachReplyPolicyIssue(
      userReportedEvaluation,
      "By your count, that answer had 5 fillers."
    ),
    null
  );
});

test("accepts every authorized Swift move verb with exact evidence grounding",
  () => {
    for (const nextMove of authorizedSwiftMoves) {
      const input = validateCoachChatRequest({
        ...request,
        turnDepth: "groundedRead",
        coachingBrief: {
          evidenceStrength: "forming",
          directVerdict: "The setup obscured the recommendation.",
          decisiveEvidence: "latest rep: the setup obscured the recommendation",
          nextMove,
          missingEvidence: null,
          repairFocus: null,
        },
      });
      const reply = `${nextMove.replace(/[.!?]+$/u, "")} because the latest ` +
        "rep showed the setup obscured the recommendation.";
      assert.equal(coachReplyPolicyIssue(input, reply), null, nextMove);
    }

    const unrelated = validateCoachChatRequest({
      ...request,
      coachingBrief: {
        evidenceStrength: "forming",
        directVerdict: "The setup obscured the recommendation.",
        decisiveEvidence: "latest rep: the setup obscured the recommendation",
        nextMove: authorizedSwiftMoves[0],
        missingEvidence: null,
        repairFocus: null,
      },
    });
    assert.equal(
      coachReplyPolicyIssue(
        unrelated,
        "Practice breathing slowly because the latest rep showed the setup " +
          "obscured the recommendation."
      ),
      "missing-move-grounding"
    );

    const unsafeGenericDo = validateCoachChatRequest({
      ...request,
      coachingBrief: {
        evidenceStrength: "forming",
        directVerdict: "The setup obscured the recommendation.",
        decisiveEvidence: "latest rep: the setup obscured the recommendation",
        nextMove: "Do the next rep more clearly.",
        missingEvidence: null,
        repairFocus: null,
      },
    });
    assert.equal(
      coachReplyPolicyIssue(
        unsafeGenericDo,
        "Do the next rep more clearly because the latest rep showed the " +
          "setup obscured the recommendation."
      ),
      "missing-move-grounding"
    );
  });

test("invalid provider draft gets one hidden bounded rewrite", async () => {
  const input = validateCoachChatRequest(request);
  const calls: Array<{temperature: number; contents: string}> = [];
  const generations = [
    vertexStream([
      "You paused for 2 seconds before your recommendation.",
    ]),
    vertexStream([
      "Put your recommendation first because the app practice rep placed " +
        "setup before it.",
    ]),
  ];
  const result = await generateCoachCompletionWithRepair(
    input,
    "gemini-2.5-flash",
    buildVertexContents(input),
    {
      generate: async (contents, temperature) => {
        calls.push({
          temperature,
          contents: JSON.stringify(contents),
        });
        const generation = generations.shift();
        assert.ok(generation);
        return generation;
      },
    }
  );

  assert.equal(result.repaired, true);
  assert.equal(result.completion.generationMode, "model-rewrite");
  assert.equal(
    result.completion.text,
    "Put your recommendation first because the app practice rep placed " +
      "setup before it."
  );
  assert.deepEqual(calls.map((call) => call.temperature), [0.55, 0.2]);
  assert.match(calls[1].contents, /rejected for invented-number/);
  assert.match(calls[1].contents, /Remove the unsupported claim/);
});

test("typed draft fallback is grounded", async () => {
  const input = validateCoachChatRequest({
    ...request,
    coachingBrief: {
      evidenceStrength: "weak",
      directVerdict: "The recommendation arrived after the setup.",
      decisiveEvidence: [
        "The recent rep placed the setup before the recommendation.",
      ].join(""),
      nextMove: "Put the recommendation first in the next practice.",
      missingEvidence: "A comparable follow-up rep is missing.",
      repairFocus: null,
    },
  });
  let attempts = 0;
  const result = await generateCoachCompletionWithRepair(
    input,
    "gemini-2.5-flash",
    buildVertexContents(input),
    {
      generate: async () => {
        attempts += 1;
        return vertexStream([
          "You paused for 2 seconds before your recommendation.",
        ]);
      },
    }
  );

  assert.equal(attempts, 2);
  assert.equal(result.repaired, true);
  assert.equal(result.completion.generationMode, "deterministic-brief");
  assert.equal(result.completion.outputTokens, undefined);
  assert.equal(
    result.completion.text,
    "The recent rep placed the setup before the recommendation. " +
      "Put the recommendation first in the next practice."
  );
});

test("typed fallback continues a retained intervention without repeating it",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      messages: [
        {
          role: "assistant",
          content: "Put the recommendation first in the next practice.",
        },
        {role: "user", content: "What should I fix now?"},
      ],
    });
    let attempts = 0;
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-flash",
      buildVertexContents(input),
      {
        generate: async () => {
          attempts += 1;
          return vertexStream([
            "You paused for 99 seconds before your recommendation.",
          ]);
        },
      }
    );

    assert.equal(attempts, 2);
    assert.equal(result.repaired, true);
    assert.equal(result.completion.generationMode, "deterministic-brief");
    assert.equal(
      result.completion.text,
      "The available app practice rep placed setup before the " +
        "recommendation. " +
        "Stay with that focus for the next rep."
    );
    assert.equal(coachReplyPolicyIssue(input, result.completion.text), null);
  });

test("deterministic brief fallback accepts every authorized Swift move",
  async () => {
    for (const nextMove of authorizedSwiftMoves) {
      const input = validateCoachChatRequest({
        ...request,
        turnDepth: "groundedRead",
        coachingBrief: {
          evidenceStrength: "forming",
          directVerdict: "The setup obscured the recommendation.",
          decisiveEvidence: "latest rep: the setup obscured the recommendation",
          nextMove,
          missingEvidence: null,
          repairFocus: null,
        },
      });
      let attempts = 0;
      const result = await generateCoachCompletionWithRepair(
        input,
        "gemini-2.5-flash",
        buildVertexContents(input),
        {
          generate: async () => {
            attempts += 1;
            return vertexStream([
              "You paused for 99 seconds before the recommendation.",
            ]);
          },
        }
      );
      assert.equal(attempts, 2, nextMove);
      assert.equal(
        result.completion.generationMode,
        "deterministic-brief",
        nextMove
      );
      assert.equal(
        coachReplyPolicyIssue(input, result.completion.text),
        null,
        nextMove
      );
    }
  });

test("separate observer promise is removed without another model call",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      verifiedQuoteSources: [],
      coachingContext: "The recommendation arrived after the setup.",
    });
    let attempts = 0;
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-flash",
      buildVertexContents(input),
      {
        generate: async () => {
          attempts += 1;
          return vertexStream([
            "Put your recommendation first in the next practice because the " +
          "app practice rep placed setup before it. I'll watch for that order.",
          ]);
        },
      }
    );

    assert.equal(attempts, 1);
    assert.equal(result.repaired, true);
    assert.equal(result.completion.generationMode, "model-sanitized");
    assert.equal(
      result.completion.text,
      "Put your recommendation first in the next practice because the app " +
        "practice rep placed setup before it."
    );
    assert.equal(result.completion.outputTokens, undefined);
  });

test("ungrounded observer draft gets one rewrite before safe removal",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      verifiedQuoteSources: [],
      coachingContext: "The recommendation arrived after the setup.",
    });
    const calls: string[] = [];
    const generations = [
      vertexStream([
        "Put your recommendation before the setup in your next practice. " +
      "I'll watch for that order.",
      ]),
      vertexStream([
        "Put your recommendation first in the next practice because the app " +
      "practice rep placed setup before it. I'll watch for that order.",
      ]),
    ];
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-flash",
      buildVertexContents(input),
      {
        generate: async (contents) => {
          calls.push(JSON.stringify(contents));
          const generation = generations.shift();
          assert.ok(generation);
          return generation;
        },
      }
    );

    assert.equal(calls.length, 2);
    assert.match(calls[1], /relationship clear in natural prose/);
    assert.equal(result.completion.generationMode, "model-sanitized");
    assert.equal(
      result.completion.text,
      "Put your recommendation first in the next practice because the app " +
        "practice rep placed setup before it."
    );
  });

test("personal read without a typed brief asks one useful question",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      coachingBrief: null,
      verifiedQuoteSources: [],
      coachingContext: [
        "RECENT (most-recent first)",
        "- Evidence: The recommendation arrived after the setup.",
        "- Coaching move: Put the recommendation first in the next practice.",
      ].join("\n"),
    });
    assert.equal(
      coachReplyPolicyIssue(
        input,
        "Put your recommendation before the setup in your next practice, " +
          "so that the recommendation arrives first."
      ),
      "missing-evidence-clarification"
    );

    const generations = [
      vertexStream([
        "Put your recommendation before the setup in your next practice, " +
          "so that the recommendation arrives first.",
      ]),
      vertexStream([
        "I don't have enough evidence to answer that honestly yet. " +
          "What did you say first in the answer you want me to read?",
      ]),
    ];
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-flash",
      buildVertexContents(input),
      {
        generate: async () => {
          const generation = generations.shift();
          assert.ok(generation);
          return generation;
        },
      }
    );

    assert.equal(result.repaired, true);
    assert.equal(
      result.completion.text,
      "I don't have enough evidence to answer that honestly yet. " +
        "What did you say first in the answer you want me to read?"
    );
  });

test("general coaching actions require one communication reason", () => {
  const input = validateCoachChatRequest({
    ...request,
    responseKind: "generalCoaching",
    coachingBrief: null,
    verifiedQuoteSources: [],
    coachingContext: [
      "RECENT (most-recent first)",
      "No quantity-qualified personal rep is available.",
      "COACHING EXPERTISE: Structure a presentation around one decision.",
    ].join("\n"),
    messages: [{
      role: "user",
      content: "How do I structure a presentation?",
    }],
  });
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "Open with the decision, then give one reason and one concrete example."
    ),
    "missing-evidence-bridge"
  );
  assert.equal(
    coachReplyPolicyIssue(
      input,
      "Open with the decision, then give one reason and one concrete " +
        "example; that order separates the point from its support."
    ),
    null
  );
});

test("general coaching with no personal move still reaches generation",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      responseKind: "generalCoaching",
      coachingBrief: null,
      messages: [{
        role: "user",
        content: "How do I structure a presentation?",
      }],
    });
    let attempts = 0;
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-flash",
      buildVertexContents(input),
      {
        generate: async () => {
          attempts += 1;
          return vertexStream([
            "Open with the decision, then give one reason and one example; " +
              "that order separates the point from its support.",
          ]);
        },
      }
    );
    assert.equal(attempts, 1);
    assert.equal(result.completion.generationMode, "model");
    assert.match(result.completion.text, /Open with the decision/);
  });

test("ungrounded v2 general coaching repairs a fabricated personal read",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      responseKind: "generalCoaching",
      coachingBrief: null,
      coachingContext: [
        "RECENT (most-recent first)",
        "Broad context mentions setup before the recommendation.",
        "COACHING EXPERTISE: Open with a decision, reason, then example.",
      ].join("\n"),
      messages: [{
        role: "user",
        content: "How do I structure a presentation?",
      }],
    });
    assert.equal(
      coachReplyPolicyIssue(
        input,
        "Your recent reps show the setup before the recommendation."
      ),
      "unverified-personal-read"
    );

    let attempts = 0;
    const generations = [
      "Your recent reps show the setup before the recommendation.",
      "Open with the decision, then give one reason and one example; " +
        "that order separates the point from its support.",
    ];
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-flash",
      buildVertexContents(input),
      {
        generate: async () => {
          attempts += 1;
          const text = generations.shift();
          assert.ok(text);
          return vertexStream([text]);
        },
      }
    );
    assert.equal(attempts, 2);
    assert.equal(result.repaired, true);
    assert.equal(result.completion.generationMode, "model-rewrite");
    assert.match(result.completion.text, /Open with the decision/);
  });

test("memory handoff reaches generation with its consent-bound hypothesis",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      responseKind: "memoryHandoff",
      turnDepth: "groundedRead",
      coachingBrief: {
        evidenceStrength: "forming",
        directVerdict: [
          "Use this memory as a testable hypothesis only:",
          "disagreement may be getting softened by setup.",
        ].join(" "),
        decisiveEvidence: [
          "prior coach read: the disagreement arrived after too much setup",
        ].join(""),
        nextMove: [
          "Use two pressure reps to test whether the point arrives late;",
          "drop the hypothesis if verdict-first solves it.",
        ].join(" "),
        missingEvidence: null,
        repairFocus: null,
      },
      messages: [{role: "user", content: "What should Noum remember?"}],
    });
    let attempts = 0;
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-flash",
      buildVertexContents(input),
      {
        generate: async () => {
          attempts += 1;
          return vertexStream([[
            "For now, I'd remember one possible pattern: disagreement may be",
            "getting softened by setup because the prior coach read placed the",
            "point late. Use two pressure reps to test whether the point still",
            "arrives late; keep the read if it does, and drop it if",
            "verdict-first solves the order.",
          ].join(" ")]);
        },
      }
    );
    assert.equal(attempts, 1);
    assert.equal(result.completion.generationMode, "model");
    assert.match(result.completion.text, /I'd remember one possible pattern/);
    assert.doesNotMatch(result.completion.text, /testable hypothesis/i);
  });

test("incomplete memory is a zero-provider no-memory reply",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      responseKind: "memoryHandoff",
      coachingBrief: null,
      messages: [{role: "user", content: "What should Noum remember?"}],
    });
    let attempts = 0;
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-flash",
      buildVertexContents(input),
      {
        generate: async () => {
          attempts += 1;
          return vertexStream(["Invented memory that must never run."]);
        },
      }
    );
    assert.equal(attempts, 0);
    assert.equal(result.completion.generationMode, "deterministic-brief");
    assert.equal(
      result.completion.text,
      "I don't have a clear pattern to carry forward yet."
    );
  });

test(
  "no-move brief uses its vetted verdict without another model call",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      coachingBrief: {
        evidenceStrength: "missing",
        directVerdict:
          "I don’t have enough evidence to choose your next move yet.",
        decisiveEvidence: null,
        nextMove: null,
        missingEvidence: "A comparable answer is missing.",
        repairFocus: null,
      },
    });
    let attempts = 0;
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-flash",
      buildVertexContents(input),
      {
        generate: async () => {
          attempts += 1;
          return vertexStream([
            "To compare, say how confident you feel on a scale of one to ten.",
          ]);
        },
      }
    );

    assert.equal(attempts, 0);
    assert.equal(result.repaired, false);
    assert.equal(result.completion.generationMode, "deterministic-brief");
    assert.equal(
      result.completion.text,
      "I don’t have enough evidence to choose your next move yet."
    );
    assert.equal(result.completion.outputTokens, undefined);
  }
);

test(
  "truncated provider draft gets only one lower-temperature retry",
  async () => {
    const input = validateCoachChatRequest(request);
    let attempt = 0;
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-flash",
      buildVertexContents(input),
      {
        generate: async (_contents, temperature) => {
          attempt += 1;
          if (attempt === 1) {
            assert.equal(temperature, 0.55);
            return vertexStream(["Partial"], FinishReason.MAX_TOKENS);
          }
          assert.equal(temperature, 0.2);
          return vertexStream([
            "Put your recommendation first in the next practice.",
          ]);
        },
      }
    );
    assert.equal(attempt, 2);
    assert.equal(result.repaired, true);
    assert.equal(result.completion.generationMode, "deterministic-brief");
  }
);

test(
  "coaching intent falls back to its brief after an incomplete rewrite",
  async () => {
    const input = validateCoachChatRequest(request);
    let attempts = 0;
    const result = await generateCoachCompletionWithRepair(
      input,
      "gemini-2.5-flash",
      buildVertexContents(input),
      {
        generate: async () => {
          attempts += 1;
          if (attempts === 1) {
            return vertexStream([
              "You paused for 2 seconds before your recommendation.",
            ]);
          }
          return vertexStream(["Partial"], FinishReason.MAX_TOKENS);
        },
      }
    );

    assert.equal(attempts, 2);
    assert.equal(result.repaired, true);
    assert.equal(result.completion.generationMode, "deterministic-brief");
    assert.equal(
      result.completion.text,
      "The available app practice rep placed setup before the " +
        "recommendation. " +
        "Put the recommendation first in the next practice."
    );
  }
);

test("policy-invalid no-move verdict fails at request validation", () => {
  assert.throws(
    () => validateCoachChatRequest({
      ...request,
      coachingBrief: {
        evidenceStrength: "missing",
        directVerdict: "There isn't enough evidence, so record another rep.",
        decisiveEvidence: null,
        nextMove: null,
        missingEvidence: "A comparable answer is missing.",
        repairFocus: null,
      },
    }),
    (error: unknown) =>
      (error as HttpsErrorShape).code === "invalid-argument"
  );
});

test(
  "non-coaching intents never receive a deterministic coaching brief",
  async () => {
    for (const turnIntent of [
      "greeting", "offTopic", "preference", "vulnerable",
    ] as const) {
      const input = validateCoachChatRequest({
        ...request,
        turnIntent,
        responseKind: "conversational",
        coachingBrief: null,
      });
      let attempts = 0;
      await assert.rejects(
        () => generateCoachCompletionWithRepair(
          input,
          "gemini-2.5-flash",
          buildVertexContents(input),
          {
            generate: async () => {
              attempts += 1;
              if (attempts === 1) {
                return vertexStream([
                  "You paused for 2 seconds before your recommendation.",
                ]);
              }
              return vertexStream(["Partial"], FinishReason.MAX_TOKENS);
            },
          }
        ),
        (error: unknown) => {
          const httpsError = error as HttpsErrorShape;
          return httpsError.code === "data-loss" &&
            httpsError.details?.reason === FinishReason.MAX_TOKENS;
        },
        turnIntent
      );
      assert.equal(attempts, 2, turnIntent);
    }
  }
);

test(
  "policy exhaustion is typed separately from malformed output",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      turnIntent: "preference",
      responseKind: "conversational",
      coachingBrief: null,
    });
    let attempts = 0;
    await assert.rejects(
      () => generateCoachCompletionWithRepair(
        input,
        "gemini-2.5-flash",
        buildVertexContents(input),
        {
          generate: async () => {
            attempts += 1;
            return attempts === 1 ?
              vertexStream(["Practice more."]) :
              vertexStream(["Record another answer."]);
          },
        }
      ),
      (error: unknown) => {
        const typed = error as HttpsErrorShape;
        return typed.code === "failed-precondition" &&
          typed.details?.reason === "coach-quality-rejected";
      }
    );
    assert.equal(attempts, 2);
  }
);

test("configured model names are pinned to verified thinking behavior", () => {
  assert.equal(
    thinkingBudgetForModel("fast", "gemini-2.5-flash"),
    0
  );
  assert.equal(
    thinkingBudgetForModel("ultra", "gemini-2.5-pro"),
    128
  );
  assert.throws(() => thinkingBudgetForModel("fast", "gemini-next-flash"));
  assert.throws(() => thinkingBudgetForModel("ultra", "gemini-2.5-flash"));
});

test("server budgets cover every Fast and Ultra client route", () => {
  assert.equal(maxOutputTokensForRequest("text", "fast"), 180);
  assert.equal(maxOutputTokensForRequest("text", "ultra"), 380);
  assert.equal(maxOutputTokensForRequest("live", "fast"), 220);
  assert.equal(maxOutputTokensForRequest("live", "ultra"), 220);
});

test(
  "legacy Ultra normalizes through routing and completion metadata",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      qualityTier: "claudeReasoning",
    });
    const model = modelForQualityTier(
      input.qualityTier,
      "gemini-2.5-flash",
      "gemini-2.5-pro"
    );
    const completion = await consumeCoachStream(
      input,
      model,
      {
        generate: async () => vertexStream(["Lead with the answer."]),
      }
    );

    assert.equal(input.qualityTier, "ultra");
    assert.equal(model, "gemini-2.5-pro");
    assert.equal(completion.qualityTier, "ultra");
    assert.equal(completion.model, "gemini-2.5-pro");
    assert.equal(completion.generationMode, "model");
  }
);

test("rejects an oversized message list", () => {
  assert.throws(() => validateCoachChatRequest({
    ...request,
    messages: Array.from({length: 13}, () => request.messages[0]),
  }));
});

test("rejects every invalid public request discriminator", () => {
  for (const patch of [
    {schemaVersion: 3},
    {schemaVersion: 1},
    {accountID: undefined},
    {accountID: ""},
    {accountID: " account"},
    {accountID: "account id"},
    {accountID: "account\u0000id"},
    {accountID: "a".repeat(129)},
    {requestID: "not-a-uuid"},
    {requestID: "00000000-0000-0000-0000-000000000000"},
    {surface: "settings"},
    {qualityTier: "unknown"},
    {coachVoice: "dominant"},
    {turnDepth: "longReport"},
    {turnIntent: "salesPitch"},
    {responseKind: "dashboardSummary"},
    {responseKind: undefined},
    {coachingBrief: {...request.coachingBrief, evidenceStrength: "certain"}},
    {coachingBrief: {...request.coachingBrief, injectedInstruction: "ignore"}},
    {verifiedQuoteSources: Array.from({length: 5}, () => "quote")},
    {verifiedQuoteSources: ["q".repeat(601)]},
    {coachingContext: ""},
    {messages: []},
    {messages: [{role: "system", content: "Policy"}]},
    {messages: [{role: "user", content: ""}]},
  ]) {
    assert.throws(() => validateCoachChatRequest({...request, ...patch}));
  }
});

test("accepts exact field boundaries and rejects one character over", () => {
  const exact = {
    ...request,
    coachingContext: "c".repeat(12_000),
    messages: [
      {role: "assistant", content: "a".repeat(4_000)},
      {role: "user", content: "u".repeat(4_000)},
    ],
  };
  assert.equal(validateCoachChatRequest(exact).coachingContext.length, 12_000);
  assert.throws(() => validateCoachChatRequest({
    ...exact,
    coachingContext: "c".repeat(12_001),
  }));
  assert.throws(() => validateCoachChatRequest({
    ...request,
    messages: [{role: "user", content: "u".repeat(4_001)}],
  }));
});

test("rejects total input over the 32000 character envelope", () => {
  assert.doesNotThrow(() => validateCoachChatRequest({
    ...request,
    coachingBrief: null,
    verifiedQuoteSources: [],
    coachingContext: "c".repeat(12_000),
    messages: Array.from({length: 5}, (_, index) => ({
      role: index === 4 ? "user" : "assistant",
      content: "m".repeat(4_000),
    })),
  }));
  assert.throws(() => validateCoachChatRequest({
    ...request,
    coachingBrief: null,
    coachingContext: "c".repeat(12_000),
    messages: [
      ...Array.from({length: 5}, () => ({
        role: "assistant",
        content: "m".repeat(4_000),
      })),
      {role: "user", content: "x"},
    ],
  }));
});

test("rejects a request whose last turn is not the user", () => {
  assert.throws(() => validateCoachChatRequest({
    ...request,
    messages: [{role: "assistant", content: "A reply"}],
  }));
});

test("minute rate limit allows five and rejects the sixth", () => {
  const now = 1_800_000;
  let state = nextRateState(undefined, now);
  assert.equal(state.allowed, true);
  for (let count = 2; count <= 5; count += 1) {
    state = nextRateState(state.state, now);
    assert.equal(state.allowed, true);
  }
  state = nextRateState(state.state, now);
  assert.equal(state.allowed, false);
});

test("rate windows reset independently", () => {
  const first = nextRateState(undefined, 3_600_000);
  const nextMinute = nextRateState(first.state, 3_660_000);
  assert.equal(nextMinute.state.minuteCount, 1);
  assert.equal(nextMinute.state.hourCount, 2);
  const nextHour = nextRateState(nextMinute.state, 7_200_000);
  assert.equal(nextHour.state.minuteCount, 1);
  assert.equal(nextHour.state.hourCount, 1);
});

test("hour rate limit allows thirty and rejects the thirty-first", () => {
  const hourStart = 10 * 3_600_000;
  let state = nextRateState(undefined, hourStart);
  for (let count = 2; count <= 30; count += 1) {
    state = nextRateState(state.state, hourStart + (count - 1) * 60_000);
    assert.equal(state.allowed, true);
  }
  state = nextRateState(state.state, hourStart + 30 * 60_000);
  assert.equal(state.allowed, false);
});

test("requires both authenticated and App Check-verified callers", () => {
  assert.throws(() => assertTrustedCaller(undefined, {appId: "app"}));
  assert.throws(() => assertTrustedCaller({uid: "user"}, undefined));
  assert.doesNotThrow(() => assertTrustedCaller(
    {uid: "user"},
    {appId: "app"}
  ));
});

test("v2 coach requests are bound to the exact authenticated account", () => {
  const input = validateCoachChatRequest(request);
  assert.equal(
    assertCoachAccountBinding(input, request.accountID),
    "verified"
  );

  const otherUID = "different-firebase-account";
  assert.throws(
    () => assertCoachAccountBinding(input, otherUID),
    (error: unknown) => {
      const httpsError = error as HttpsErrorShape & {message?: string};
      const serialized = JSON.stringify(error);
      return httpsError.code === "permission-denied" &&
        httpsError.details?.reason === "coach-account-binding-mismatch" &&
        httpsError.message ===
          "Account binding does not match the secure session." &&
        !serialized.includes(request.accountID) &&
        !serialized.includes(otherUID);
    }
  );
});

test("legacy v1 preserves its envelope and ignores v2 authority fields", () => {
  const legacy = {
    schemaVersion: 1,
    requestID: request.requestID,
    surface: "text",
    qualityTier: "geminiFast",
    coachingContext: "  RECENT evidence  ",
    messages: [
      {role: "assistant", content: "  Prior coach turn.  "},
      {role: "user", content: "  What should I do now?  "},
    ],
    accountID: "payload-account-must-not-win",
    coachVoice: "authoritative",
    turnDepth: "deepAssessment",
    turnIntent: "coaching",
    responseKind: "personalEvidenceRead",
    coachingBrief: request.coachingBrief,
    verifiedQuoteSources: request.verifiedQuoteSources,
  };
  assert.throws(
    () => validateCoachChatRequest(legacy),
    (error: unknown) => (error as HttpsErrorShape).code === "invalid-argument"
  );

  const normalized = validateLegacyCoachChatRequest(legacy);
  assert.deepEqual(normalized, {
    schemaVersion: 1,
    requestID: request.requestID,
    surface: "text",
    qualityTier: "fast",
    coachingContext: "RECENT evidence",
    messages: [
      {role: "assistant", content: "Prior coach turn."},
      {role: "user", content: "What should I do now?"},
    ],
  });
  assert.deepEqual(Object.keys(normalized).sort(), [
    "coachingContext",
    "messages",
    "qualityTier",
    "requestID",
    "schemaVersion",
    "surface",
  ]);
  assert.throws(() => validateLegacyCoachChatRequest(request));
});

test("legacy v1 validator preserves original aliases and boundaries", () => {
  const base = {
    schemaVersion: 1,
    requestID: request.requestID,
    surface: "text",
    qualityTier: "claudeReasoning",
    coachingContext: "c".repeat(12_000),
    messages: [{role: "user", content: "m".repeat(4_000)}],
  };
  assert.equal(
    validateLegacyCoachChatRequest(base).qualityTier,
    "ultra"
  );
  assert.equal(
    validateLegacyCoachChatRequest({
      ...base,
      coachingContext: "context",
      messages: Array.from({length: 12}, () => ({
        role: "user",
        content: "message",
      })),
    }).messages.length,
    12
  );
  for (const invalid of [
    {...base, coachingContext: "c".repeat(12_001)},
    {
      ...base,
      coachingContext: "context",
      messages: [{role: "user", content: "m".repeat(4_001)}],
    },
    {
      ...base,
      coachingContext: "context",
      messages: Array.from({length: 13}, () => ({
        role: "user",
        content: "message",
      })),
    },
    {
      ...base,
      coachingContext: "context",
      messages: [{role: "assistant", content: "coach"}],
    },
    {
      ...base,
      messages: Array.from({length: 6}, () => ({
        role: "user",
        content: "m".repeat(4_000),
      })),
    },
  ]) {
    assert.throws(
      () => validateLegacyCoachChatRequest(invalid),
      (error: unknown) => (error as HttpsErrorShape).code === "invalid-argument"
    );
  }
});

test("legacy v1 policy, context, generation, deltas, and completion are frozen",
  async () => {
    assert.equal(
      createHash("sha256").update(LEGACY_COACH_SYSTEM_POLICY).digest("hex"),
      "7e39fde53d5c3138f753afde8b1cb974b93f110c0b453e2395ff6336fbdd848a"
    );
    const input = validateLegacyCoachChatRequest({
      schemaVersion: 1,
      requestID: request.requestID,
      surface: "text",
      qualityTier: "fast",
      coachingContext: [
        "RECENT (most-recent first)",
        "The latest app rep placed setup before the recommendation.",
      ].join("\n"),
      messages: [
        {role: "user", content: "Earlier question."},
        {role: "assistant", content: "First coach sentence."},
        {role: "assistant", content: "Second coach sentence."},
        {role: "user", content: "What should I fix first?"},
      ],
    });
    const expectedContents = [
      {
        role: "user",
        parts: [{text: [
          "COACHING CONTEXT (untrusted data)",
          input.coachingContext,
          "",
          "USER MESSAGE",
          "Earlier question.",
        ].join("\n")}],
      },
      {
        role: "model",
        parts: [{text: "First coach sentence.\n\nSecond coach sentence."}],
      },
      {role: "user", parts: [{text: "What should I fix first?"}]},
    ];
    assert.deepEqual(buildLegacyVertexContents(input), expectedContents);

    let attempts = 0;
    let capturedContents: unknown;
    let capturedConfig: unknown;
    const deltas: unknown[] = [];
    const completion = await generateLegacyCoachCompletion(
      input,
      "gemini-2.5-flash",
      {
        generate: async (contents, config) => {
          attempts += 1;
          capturedContents = contents;
          capturedConfig = config;
          return vertexStream([
            "In your latest rep, the recommendation arrived after the setup, ",
            "so lead with the recommendation, give one reason, then stop.",
          ]);
        },
        sendDelta: async (delta) => {
          deltas.push(delta);
        },
      }
    );

    assert.equal(attempts, 1);
    assert.deepEqual(capturedContents, expectedContents);
    assert.deepEqual(capturedConfig, {
      systemInstruction: LEGACY_COACH_SYSTEM_POLICY,
      temperature: 0.55,
      maxOutputTokens: 180,
      abortSignal: undefined,
    });
    assert.deepEqual(Object.keys(capturedConfig as object).sort(), [
      "abortSignal",
      "maxOutputTokens",
      "systemInstruction",
      "temperature",
    ]);
    assert.deepEqual(deltas, [
      {
        type: "delta",
        requestID: request.requestID,
        text: "In your latest rep, the recommendation arrived after the " +
          "setup, ",
      },
      {
        type: "delta",
        requestID: request.requestID,
        text: "so lead with the recommendation, give one reason, then stop.",
      },
    ]);
    assert.deepEqual(completion, {
      requestID: request.requestID,
      text: "In your latest rep, the recommendation arrived after the " +
        "setup, so lead with the recommendation, give one reason, then stop.",
      model: "gemini-2.5-flash",
      qualityTier: "fast",
      finishReason: "STOP",
      inputTokens: 120,
      outputTokens: 24,
    });
    assert.deepEqual(Object.keys(completion).sort(), [
      "finishReason",
      "inputTokens",
      "model",
      "outputTokens",
      "qualityTier",
      "requestID",
      "text",
    ]);
  });

test("legacy generation config preserves tier and surface ceilings", () => {
  const base = validateLegacyCoachChatRequest({
    schemaVersion: 1,
    requestID: request.requestID,
    surface: "text",
    qualityTier: "fast",
    coachingContext: "Bounded context.",
    messages: [{role: "user", content: "Coach this."}],
  });
  const cases: Array<{
    input: LegacyCoachChatInput;
    temperature: number;
    maxOutputTokens: number;
  }> = [
    {input: base, temperature: 0.55, maxOutputTokens: 180},
    {
      input: {...base, qualityTier: "ultra"},
      temperature: 0.45,
      maxOutputTokens: 380,
    },
    {
      input: {...base, surface: "live", qualityTier: "fast"},
      temperature: 0.55,
      maxOutputTokens: 220,
    },
    {
      input: {...base, surface: "live", qualityTier: "ultra"},
      temperature: 0.45,
      maxOutputTokens: 220,
    },
  ];
  for (const item of cases) {
    const config = legacyCoachGenerationConfig(item.input, undefined);
    assert.equal(config.temperature, item.temperature);
    assert.equal(config.maxOutputTokens, item.maxOutputTokens);
    assert.equal("thinkingConfig" in config, false);
  }
});

test("secure v2 binding precedes rate limiting and v2-only execution", () => {
  const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
  const start = source.indexOf("export const coachChatV2 = onCall");
  const end = source.indexOf(
    "async function enforceTranscriptionTokenRateLimit",
    start
  );
  assert.equal(start >= 0 && end > start, true);
  const handler = source.slice(
    start,
    end
  );
  const binding = handler.indexOf("assertCoachAccountBinding(input, uid)");
  const rateLimit = handler.indexOf("await enforceRateLimit(uid)");
  const execution = handler.indexOf("return executeCoachChatV2(");
  assert.equal(binding >= 0, true);
  assert.equal(binding < rateLimit, true);
  assert.equal(rateLimit < execution, true);
  assert.doesNotMatch(
    handler,
    /validateLegacyCoachChatRequest|executeLegacyCoachChat|schemaVersion\s*=/i
  );
});

test("legacy and secure coach endpoints remain additive and isolated", () => {
  const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
  const availability = source.slice(
    source.indexOf("export const coachChatAvailability = onCall"),
    source.indexOf("export function nextRateState")
  );
  const legacy = source.slice(
    source.indexOf("export const coachChat = onCall"),
    source.indexOf("export const coachChatV2 = onCall")
  );
  const secure = source.slice(
    source.indexOf("export const coachChatV2 = onCall"),
    source.indexOf("async function enforceTranscriptionTokenRateLimit")
  );
  const legacyExecutor = source.slice(
    source.indexOf("async function executeLegacyCoachChat"),
    source.indexOf("async function executeCoachChatV2")
  );
  const rateLimiter = source.slice(
    source.indexOf("export async function enforceRateLimit"),
    source.indexOf("function legacyCoachLogMetadata")
  );
  assert.match(availability, /request\.data\.schemaVersion !== 1/);
  assert.match(availability, /functionName:\s*"coachChatV2"/);
  assert.match(availability, /requestSchemaVersion:\s*2/);
  assert.match(availability, /policyVersion:\s*COACH_POLICY_VERSION/);
  const trust = legacy.indexOf(
    "assertTrustedCaller(request.auth, request.app)"
  );
  const validation = legacy.indexOf(
    "validateLegacyCoachChatRequest(request.data)"
  );
  const rateLimit = legacy.indexOf("await enforceRateLimit(uid)");
  const execution = legacy.indexOf("return executeLegacyCoachChat(");
  assert.match(legacy, /enforceAppCheck: true/);
  assert.equal(trust >= 0, true);
  assert.equal(trust < validation, true);
  assert.equal(validation >= 0, true);
  assert.equal(validation < rateLimit, true);
  assert.equal(rateLimit < execution, true);
  assert.doesNotMatch(
    legacy,
    /validateCoachChatRequest\(request\.data\)|executeCoachChatV2/
  );
  assert.match(legacyExecutor, /generateLegacyCoachCompletion/);
  const v2ExecutionLeak = new RegExp(
    "generateCoachCompletionWithRepair|coachSystemPolicyForRequest|" +
      "thinkingConfig"
  );
  assert.doesNotMatch(
    legacyExecutor,
    v2ExecutionLeak
  );
  assert.match(rateLimiter, /collection\("_accountDeletionState"\)/);
  assert.match(rateLimiter, /assertAccountDeletionNotPending/);
  assert.match(secure, /validateCoachChatRequest\(request\.data\)/);
  assert.doesNotMatch(
    secure,
    /schemaVersion\s*===?\s*1|legacy|executeLegacyCoachChat/i
  );
});

test("client rules deny every rate-limit collection operation", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  assert.match(
    rules,
    // This exact server-only rule should remain visually auditable.
    // eslint-disable-next-line max-len
    /match \/_serverRateLimits\/\{[^}]+\}[\s\S]*?allow read, write: if false;/
  );
});

test("recommendation state is callable-only", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  assert.match(
    rules,
    // eslint-disable-next-line max-len
    /match \/recommendations\/\{recommendationID\}[\s\S]*?allow read:[\s\S]*?allow create, update: if false;[\s\S]*?allow delete: if false;/
  );
  const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
  const start = source.indexOf("export const syncRecommendationState");
  const end = source.indexOf("function isAuthUserNotFound", start);
  assert.equal(start >= 0 && end > start, true);
  const callable = source.slice(start, end);
  assert.match(callable, /enforceAppCheck: true/);
  assert.match(callable, /assertTrustedCaller\(request\.auth, request\.app\)/);
  const validationIndex = callable.indexOf("validateRecommendationMutation(");
  const identityIndex = callable.indexOf(
    "assertRecommendationMutationIdentity(input.expectedAccountID, uid)"
  );
  const transactionIndex = callable.indexOf("runTransaction");
  assert.equal(validationIndex >= 0, true);
  assert.equal(identityIndex > validationIndex, true);
  assert.equal(transactionIndex > identityIndex, true);
  assert.match(callable, /runTransaction/);
  assert.match(callable, /_accountDeletionState/);
  assert.doesNotMatch(callable, /assertSocialCallablesAvailable/);
});

test("growth aggregates are trusted, bounded, anonymous server writes", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  assert.match(
    rules,
    // eslint-disable-next-line max-len
    /match \/_growthAggregateBatches\/\{document=\*\*\}[\s\S]*?allow read, write: if false;/
  );
  assert.match(
    rules,
    // eslint-disable-next-line max-len
    /match \/_growthAggregatePeriods\/\{document=\*\*\}[\s\S]*?allow read, write: if false;/
  );
  assert.match(
    rules,
    // eslint-disable-next-line max-len
    /match \/_growthActivationCohorts\/\{document=\*\*\}[\s\S]*?allow read, write: if false;/
  );
  const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
  const start = source.indexOf("export const recordGrowthAggregate");
  const end = source.indexOf("function isAuthUserNotFound", start);
  assert.equal(start >= 0 && end > start, true);
  const callable = source.slice(start, end);
  assert.match(callable, /enforceAppCheck: true/);
  assert.match(callable, /assertTrustedCaller\(request\.auth, request\.app\)/);
  assert.match(callable, /validateGrowthAggregate\(request\.data\)/);
  assert.match(callable, /_accountDeletionState/);
  assert.match(callable, /_growthAggregateBatches/);
  assert.match(callable, /_growthAggregatePeriods/);
  assert.match(callable, /_growthActivationCohorts/);
  assert.match(callable, /activationCohortDay/);
  assert.match(
    callable,
    // eslint-disable-next-line max-len
    /accountActivatedCount: FieldValue\.increment\([\s\S]*?growth\.lifecycle\.accountActivated/
  );
  assert.match(
    callable,
    // eslint-disable-next-line max-len
    /weeklyReadAmongDay1ReturnersCount: FieldValue\.increment/
  );
  assert.match(
    callable,
    // eslint-disable-next-line max-len
    /unpricedAIUsageCount: FieldValue\.increment\([\s\S]*?input\.unpricedAIUsageCount/
  );
  assert.doesNotMatch(callable, /transaction\.set\([^)]*uid/u);
});

test("App Store notifications verify before anonymous writes", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  assert.match(
    rules,
    // eslint-disable-next-line max-len
    /match \/_appStoreNotificationMarkers\/\{document=\*\*\}[\s\S]*?allow read, write: if false;/
  );
  const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
  const handlerStart = source.indexOf(
    "async function handleAppStoreServerNotification"
  );
  const productionStart = source.indexOf(
    "export const appStoreServerNotificationsV2 = onRequest"
  );
  const sandboxStart = source.indexOf(
    "export const appStoreServerNotificationsV2Sandbox = onRequest"
  );
  const handler = source.slice(handlerStart, productionStart);
  const production = source.slice(productionStart, sandboxStart);
  const sandboxEnd = source.indexOf("/**\n * True only", sandboxStart);
  const sandbox = source.slice(sandboxStart, sandboxEnd);
  assert.equal(handlerStart >= 0 && productionStart > handlerStart, true);
  assert.match(handler, /parseAppStoreNotificationConfiguration\(/);
  assert.match(handler, /appStoreSignedPayload\(request\.body\)/);
  assert.match(handler, /createAppStoreNotificationVerifier\(configuration\)/);
  assert.match(handler, /verifyAndProjectAppStoreNotification\(/);
  assert.match(handler, /recordAppStoreLifecycleProjection\(projection\)/);
  assert.match(handler, /appStoreNotificationHTTPStatus\(error\)/);
  assert.doesNotMatch(handler, /error\.retryable \? 503 : 400/);
  assert.equal(
    handler.indexOf("verifyAndProjectAppStoreNotification(") <
      handler.indexOf("recordAppStoreLifecycleProjection(projection)"),
    true
  );
  for (const endpoint of [production, sandbox]) {
    assert.match(endpoint, /invoker: "public"/);
    assert.match(
      endpoint,
      /serviceAccount: APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT/
    );
    assert.match(endpoint, /secrets: \[appStoreRootCertificates\]/);
    assert.match(endpoint, /handleAppStoreServerNotification\(/);
    assert.doesNotMatch(endpoint, /assertTrustedCaller|enforceAppCheck/);
  }

  const writerStart = source.indexOf(
    "async function recordAppStoreLifecycleProjection"
  );
  const writer = source.slice(writerStart, handlerStart);
  assert.match(writer, /_appStoreNotificationMarkers/);
  assert.match(writer, /_growthAggregatePeriods/);
  assert.match(writer, /markerSnapshot\.exists/);
  assert.match(writer, /transaction\.create\(markerRef/);
  for (const forbidden of [
    "signedPayload",
    "signedTransactionInfo",
    "signedRenewalInfo",
    "productId",
    "appAccountToken",
    "transactionId",
  ]) {
    assert.equal(writer.includes(forbidden), false, forbidden);
  }
});

test(
  "exactly twelve competitive and social callables share the cutover gate",
  () => {
    const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
    const exportedCallables = [...source.matchAll(
    // eslint-disable-next-line max-len
      /export const (\w+) = onCall\([\s\S]*?(?=\nexport const \w+ = onCall|\n\/\*\*|$)/g
    )];
    const gated = exportedCallables
      .filter((match) =>
        match[0].includes("await assertSocialCallablesAvailable();")
      )
      .map((match) => match[1])
      .sort();
    assert.deepEqual(gated, [
      "acceptFriendInvite",
      "beginCompetitiveObservation",
      "completeCompetitiveObservation",
      "createChallenge",
      "createFriendInvite",
      "getPeerProfile",
      "listFriendLinks",
      "listLeagueMembers",
      "recordPeerSession",
      "removeFriendLink",
      "setChallengeReaction",
      "submitChallengeResult",
    ]);
    for (const callableName of gated) {
      const callable = exportedCallables.find(
        (match) => match[1] === callableName
      );
      assert.ok(callable);
      const gateIndex = callable[0].indexOf(
        "await assertSocialCallablesAvailable();"
      );
      const isObservation = callableName.includes("CompetitiveObservation");
      const firstProtectedWork = isObservation ?
        callable[0].indexOf("enforceCompetitiveObservationRateLimit") :
        callable[0].search(/(?:const input = )?validate[A-Z]/);
      assert.equal(gateIndex >= 0 && gateIndex < firstProtectedWork, true);
    }

    const recommendation = exportedCallables.find(
      (match) => match[1] === "syncRecommendationState"
    );
    assert.ok(recommendation);
    assert.doesNotMatch(recommendation[0], /assertSocialCallablesAvailable/);

    const deletion = exportedCallables.find(
      (match) => match[1] === "deleteAccount"
    );
    assert.ok(deletion);
    assert.match(deletion[0], /executeAccountDeletion\(request\)/);
    assert.doesNotMatch(deletion[0], /assertSocialCallablesAvailable/);
    assert.match(
      deletionExecutorSource(source),
      /assertSocialReferenceCutoverComplete/
    );
  }
);

test(
  "competitive observation callables preserve the ineligible boundary",
  () => {
    const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
    const beginStart = source.indexOf(
      "export const beginCompetitiveObservation"
    );
    const completeStart = source.indexOf(
      "export const completeCompetitiveObservation"
    );
    const completeEnd = source.indexOf(
      "function publicProfileDocument",
      completeStart
    );
    assert.equal(beginStart >= 0 && completeStart > beginStart, true);
    assert.equal(completeEnd > completeStart, true);
    const begin = source.slice(beginStart, completeStart);
    const complete = source.slice(completeStart, completeEnd);
    const rateStart = source.indexOf(
      "async function enforceCompetitiveObservationRateLimit"
    );
    const rateOwner = source.slice(rateStart, beginStart);
    for (const callable of [begin, complete]) {
      assert.match(callable, /enforceAppCheck: true/);
      assert.match(callable, /TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT/);
      assert.match(
        callable,
        /assertTrustedCaller\(request\.auth, request\.app\)/
      );
      assert.match(callable, /await assertSocialCallablesAvailable\(\)/);
      assert.match(callable, /_accountDeletionState/);
      assert.doesNotMatch(callable, /_verifiedSessionEvidence/);
    }
    assert.match(complete, /secrets: \[deepgramManagementKey\]/);
    assert.match(complete, /collection\("captureIntents"\)/);
    assert.match(complete, /_competitiveAudioReplayClaims/);
    assert.match(complete, /competitiveAudioReplayDigest/);
    assert.match(complete, /competitiveAudioReplayClaim/);
    assert.match(complete, /validateStoredCompetitiveAudioReplayClaim/);
    assert.doesNotMatch(complete, /collection\("audioDigests"\)/);
    const replayCreate = complete.match(
      /transaction\.create\(replayRef, \{([\s\S]*?)\}\);/
    );
    assert.ok(replayCreate);
    assert.match(replayCreate[1], /schemaVersion/);
    assert.match(replayCreate[1], /digest/);
    assert.match(replayCreate[1], /claimedAt/);
    assert.match(replayCreate[1], /expiresAt/);
    assert.doesNotMatch(
      replayCreate[1],
      /uid|sessionID|audioSHA256|competitiveEligible|transcript/
    );
    assert.match(complete, /collection\("observations"\)/);
    assert.match(complete, /competitiveEligible: false/);
    assert.match(rateOwner, /COMPETITIVE_OBSERVATION_MINUTE_LIMIT/);
    assert.match(rateOwner, /COMPETITIVE_OBSERVATION_HOUR_LIMIT/);
    assert.match(complete, /status: "processing"/);
    assert.match(complete, /processingStartedAt: Timestamp\.fromMillis/);
    assert.match(complete, /intent\.status !== "processing"/);
    assert.doesNotMatch(complete, /competitiveObservationRetryMatches/);
    assert.doesNotMatch(complete, /fillerWordCount|isRated|score:/);
    const workStart = complete.indexOf("completeCompetitiveObservationWork");
    const claimStart = complete.indexOf("claimAudio:", workStart);
    const providerStart = complete.indexOf("transcribe:", workStart);
    const commitStart = complete.indexOf("commitObservation:", workStart);
    assert.equal(
      workStart >= 0 && claimStart > workStart && providerStart > claimStart &&
      commitStart > providerStart,
      true
    );
  }
);

test("friendship callables preserve server-only reciprocal authority", () => {
  const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
  const names = [
    "createFriendInvite",
    "acceptFriendInvite",
    "listFriendLinks",
    "removeFriendLink",
  ];
  for (const [index, name] of names.entries()) {
    const start = source.indexOf(`export const ${name}`);
    const endName = names[index + 1] ?? "recordPeerSession";
    const end = source.indexOf(`export const ${endName}`, start + 1);
    const callable = source.slice(start, end);
    assert.match(callable, /enforceAppCheck: true/);
    assert.match(callable, /SOCIAL_RUNTIME_SERVICE_ACCOUNT/);
    assert.match(
      callable,
      /assertTrustedCaller\(request\.auth, request\.app\)/
    );
    assert.match(callable, /await assertSocialCallablesAvailable\(\)/);
    assert.match(callable, /_accountDeletionState/);
  }
  const create = source.slice(
    source.indexOf("export const createFriendInvite"),
    source.indexOf("export const acceptFriendInvite")
  );
  assert.match(create, /where\("status", "==", "active"\)/);
  assert.match(create, /MAX_ACTIVE_FRIEND_INVITES \+ 1/);
  assert.match(create, /friend-invite-capacity/);
  const accept = source.slice(
    source.indexOf("export const acceptFriendInvite"),
    source.indexOf("export const listFriendLinks")
  );
  assert.match(accept, /FRIEND_LINK_SCHEMA_VERSION/);
  assert.match(accept, /inviteDigest: tokenDigest/);
  assert.match(accept, /validateReciprocalFriendManifests/);
  assert.doesNotMatch(accept, /logger\.(info|warn|error)/);
  const remove = source.slice(
    source.indexOf("export const removeFriendLink"),
    source.indexOf("export const recordPeerSession")
  );
  assert.match(remove, /status: "revoked"/);
  assert.match(remove, /friend-link-generation-mismatch/);
  assert.match(remove, /pairID: input\.pairID/);
  assert.match(remove, /transaction\.delete\(ownLinkRef\)/);
  assert.match(remove, /transaction\.delete\(friendLinkRef\)/);
  assert.match(remove, /friendAccountID,/);
  const list = source.slice(
    source.indexOf("export const listFriendLinks"),
    source.indexOf("export const removeFriendLink")
  );
  assert.match(list, /\.friendAccountIDs\]\.sort\(\)/);
  assert.doesNotMatch(list, /\.slice\(/);
  const deletion = deletionExecutorSource(source);
  assert.match(deletion, /collectionGroup\("friends"\)/);
  assert.match(deletion, /FieldValue\.arrayRemove\(uid\)/);
  const callable = source.slice(
    source.indexOf("export const deleteAccount"),
    source.indexOf("export const reconcileAccountDeletionTombstones")
  );
  const validateIndex = callable.indexOf("validateDeleteAccountRequest(");
  const identityBindingIndex = callable.indexOf(
    "assertDeleteAccountRequestIdentity("
  );
  const firstDeletionWorkIndex = callable.indexOf(
    "executeAccountDeletion(request)"
  );
  assert.equal(
    validateIndex >= 0 &&
      identityBindingIndex > validateIndex &&
      identityBindingIndex < firstDeletionWorkIndex,
    true
  );
  const peer = source.slice(
    source.indexOf("export const getPeerProfile"),
    source.indexOf("export const listLeagueMembers")
  );
  assert.match(peer, /validateReciprocalFriendLinks/);
  assert.match(peer, /validateReciprocalFriendManifests/);
  const challenge = source.slice(
    source.indexOf("export const createChallenge"),
    source.indexOf("export const submitChallengeResult")
  );
  assert.match(challenge, /validateReciprocalFriendLinks/);
  assert.match(challenge, /validateReciprocalFriendManifests/);
});

test(
  "social callable gate rejects unavailable markers with a stable error",
  async () => {
    await assert.doesNotReject(
      () => assertSocialCallablesAvailable(async () => ({
        schemaVersion: 4,
        status: "complete",
        runID: "B713738E-D9ED-4337-986E-09205089D42E",
        projectID: "noum-d0b6f",
        sourceGitCommit: "a".repeat(40),
        sourceImplementationSHA256: "b".repeat(64),
        backupDigest: "c".repeat(64),
        inventoryDigest: "d".repeat(64),
        verifiedInventoryDigest: "d".repeat(64),
        completedAt: {toMillis: () => 1_800_000},
      }))
    );
    await assert.rejects(
      () => assertSocialCallablesAvailable(async () => undefined),
      (error: unknown) => {
        const httpsError = error as HttpsErrorShape;
        return httpsError.code === "failed-precondition" &&
          httpsError.details?.reason === "social-reference-cutover-incomplete";
      }
    );
    await assert.rejects(
      () => assertSocialCallablesAvailable(async () => ({
        schemaVersion: 2,
        status: "complete",
      })),
      (error: unknown) => (error as HttpsErrorShape)
        .details?.reason === "social-reference-cutover-incomplete"
    );
    await assert.rejects(
      () => assertSocialCallablesAvailable(async () => {
        throw new Error("backend unavailable");
      }),
      (error: unknown) => (error as {details?: {reason?: string}})
        .details?.reason === "social-reference-cutover-incomplete"
    );
  }
);

test("private profile optional fields remain type and size bounded", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  const start = rules.indexOf("function validPrivateProfile(data)");
  const end = rules.indexOf("function validPrivateProgress(data)");
  assert.equal(start >= 0 && end > start, true);
  const validator = rules.slice(start, end);

  const requiredFragments = [
    "!('customChallengeText' in data)",
    "data.customChallengeText == null",
    "validBoundedString(data.customChallengeText, 90)",
    "!('paraphrasedGoal' in data)",
    "data.paraphrasedGoal == null",
    "validBoundedString(data.paraphrasedGoal, 220)",
    "!('bigMomentID' in data)",
    "data.bigMomentID == null",
    "data.bigMomentID is string",
    "data.bigMomentID.matches(",
    "!('secondaryStyleGoal' in data)",
    "data.secondaryStyleGoal == null",
    "validSpeakingStyleGoal(data.secondaryStyleGoal)",
  ];
  for (const fragment of requiredFragments) {
    assert.equal(validator.includes(fragment), true, fragment);
  }
});

test("private sessions validate demand and metric provenance", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  const demandStart = rules.indexOf("function validPracticeDemand(data)");
  const sessionStart = rules.indexOf(
    "function validPrivateSession(data, sessionID)"
  );
  const sessionEnd = rules.indexOf(
    "function validPublicProfile(data, accountID)"
  );
  assert.equal(demandStart >= 0 && sessionStart > demandStart, true);
  assert.equal(sessionEnd > sessionStart, true);

  const demandValidator = rules.slice(demandStart, sessionStart);
  const sessionValidator = rules.slice(sessionStart, sessionEnd);
  const demandFragments = [
    "!('practiceDemand' in data)",
    "data.practiceDemand is map",
    "'schemaVersion', 'timedDifficulty'",
    "data.practiceDemand.schemaVersion == 1",
    "data.mode == 'timed'",
    "'free', 'easy', 'medium', 'hard'",
    "!('suddenDeathDifficulty' in data.practiceDemand)",
    "data.mode == 'suddenDeath'",
    "'easy', 'medium', 'hard'",
    "!('timedDifficulty' in data.practiceDemand)",
    "'ice_breaker', 'table_topic', 'vocal_variety'",
  ];
  for (const fragment of demandFragments) {
    assert.equal(demandValidator.includes(fragment), true, fragment);
  }

  const sessionFragments = [
    "'comparisonMetricSchemaVersion', 'practiceDemand'",
    "data.comparisonMetricSchemaVersion is int",
    "data.comparisonMetricSchemaVersion in [1, 2]",
    "validPracticeDemand(data)",
  ];
  for (const fragment of sessionFragments) {
    assert.equal(sessionValidator.includes(fragment), true, fragment);
  }
});

test("private profile enum fields match Codable raw values", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  ).replace(/\s+/g, " ")
    .replace(/\[\s+/g, "[")
    .replace(/\s+\]/g, "]");
  const requiredFragments = [
    "function validSpeakingContext(value) { return value in " +
      "['work', 'interviews', 'presentations', 'social']; }",
    "function validCoachingPriority(value) { return value in " +
      "['reduceFillers', 'moreConcise', 'thinkFaster', " +
      "'calmerDelivery']; }",
    "function validConfidenceLevel(value) { return value in " +
      "['beginner', 'rebuilding', 'inconsistent', 'confident']; }",
    "function validSpeakingChallenge(value) { return value in " +
      "['fillerWords', 'rambling', 'freezing', 'rushing']; }",
    "function validSpeakingOutcome(value) { return value in " +
      "['concise', 'composed', 'persuasive', 'spontaneous']; }",
    "function validSpeakingStyleGoal(value) { return value in " +
      "['authoritative', 'warm', 'concise', 'persuasive', " +
      "'executive', 'storytelling']; }",
    "validSpeakingContext(data.speakingContext)",
    "validCoachingPriority(data.primaryGoal)",
    "validConfidenceLevel(data.confidenceLevel)",
    "validSpeakingChallenge(data.biggestChallenge)",
    "validSpeakingOutcome(data.desiredOutcome)",
    "validSpeakingStyleGoal(data.speakingStyleGoal)",
    "validSpeakingStyleGoal(data.chosenStyleGoal)",
  ];
  for (const fragment of requiredFragments) {
    assert.equal(rules.includes(fragment), true, fragment);
  }
});

test("account deletion uses exact server-owned social references", () => {
  const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
  assert.equal(source.includes("collectionGroup(\"friends\")"), true);
  assert.match(source, /collection\("_socialReferences"\)/);
  assert.match(source, /validateSocialReferenceManifest\(/);
  assert.match(source, /references\.leagueMembershipPaths/);
  assert.match(source, /references\.challengeIDs/);
  assert.match(source, /rawFriendIDs/);
  assert.match(source, /friendInvites: async/);
  assert.match(source, /_socialFriendInvites/);
  const observationStart = source.indexOf("competitiveObservations: async");
  const rateStart = source.indexOf("rateLimits: async");
  const finalizerStart = source.indexOf("socialReferenceManifest: async");
  assert.equal(
    observationStart >= 0 && rateStart > observationStart &&
      finalizerStart > rateStart,
    true
  );
  const observationCleanup = source.slice(observationStart, rateStart);
  assert.match(observationCleanup, /_competitiveCaptureIntents/);
  assert.match(observationCleanup, /_competitiveObservations/);
  assert.match(observationCleanup, /recursiveDelete/);
  assert.equal(
    source.slice(rateStart, finalizerStart).includes("_socialReferences"),
    false
  );
});

test("competitive observation storage is callable-only", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  for (const collection of [
    "_competitiveCaptureIntents",
    "_competitiveObservations",
    "_competitiveAudioReplayClaims",
  ]) {
    const start = rules.indexOf(`match /${collection}/{document=**}`);
    assert.notEqual(start, -1, collection);
    assert.match(
      rules.slice(start, start + 130),
      /allow read, write: if false;/
    );
  }
});

test("completed deletion tombstones remain server-only write fences", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  assert.match(rules, /function deletionFenceExists\(accountID\)/);
  assert.match(
    rules,
    /return isOwner\(accountID\) && !deletionFenceExists\(accountID\);/
  );
  const storageStart = rules.indexOf(
    "match /_accountDeletionState/{document=**}"
  );
  assert.notEqual(storageStart, -1);
  assert.match(
    rules.slice(storageStart, storageStart + 140),
    /allow read, write: if false;/
  );

  const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
  const deletion = deletionExecutorSource(source);
  assert.match(deletion, /schemaVersion: 3,[\s\S]*?status: "pending"/);
  assert.match(deletion, /appleRevocationRequiredAtAdmission/);
  assert.match(deletion, /appleAuthorizationRevoked/);
  assert.match(
    deletion,
    /admission === "resumePending"[\s\S]*?schemaVersion: 3/
  );
  assert.match(
    deletion,
    // eslint-disable-next-line max-len
    /completedTombstone:[\s\S]*?transaction\.set\(deletionStateRef, completedAccountDeletionTombstone\(/
  );
  assert.doesNotMatch(deletion, /deletionStateRef\.delete\(\)/);
  assert.match(deletion, /admission === "alreadyCompleted"/);

  const scheduler = source.slice(
    source.indexOf("export const reconcileAccountDeletionTombstones")
  );
  assert.match(scheduler, /onSchedule\(/);
  assert.match(scheduler, /schedule: "every 15 minutes"/);
  assert.match(scheduler, /serviceAccount: ACCOUNT_RUNTIME_SERVICE_ACCOUNT/);
  assert.match(scheduler, /where\("status", "==", "pending"\)/);
  assert.match(scheduler, /where\("updatedAt", "<=", cutoff\)/);
  assert.match(
    scheduler,
    /pendingAccountDeletionReconciliationCandidate\(/
  );
  assert.match(
    scheduler,
    /const candidates: PendingAccountDeletionReconciliationCandidate\[\]/
  );
  assert.match(scheduler, /executeAccountDeletion\(null, candidate\)/);
  assert.match(scheduler, /case "retained"/);
  assert.match(scheduler, /pageQuery\.startAfter\(cursor\)/);
  assert.match(
    scheduler,
    /admission === "resumePending"[\s\S]*?updatedAt: Timestamp\.now\(\)/
  );
  assert.doesNotMatch(scheduler, /completedAccountDeletionTombstone\(/);
  assert.doesNotMatch(scheduler, /deletionStateRef\.delete\(\)/);
  assert.match(deletion, /executeAccountDeletionPlan\(work\)/);
});

test("ephemeral server records have source-declared TTL", () => {
  const config = JSON.parse(readFileSync(
    resolve(process.cwd(), "../firestore.indexes.json"),
    "utf8"
  )) as {
    indexes?: Array<Record<string, unknown>>;
    fieldOverrides?: Array<Record<string, unknown>>;
  };
  const ttlGroups = new Set((config.fieldOverrides ?? [])
    .filter((entry) => entry.fieldPath === "expiresAt" && entry.ttl === true &&
      Array.isArray(entry.indexes) && entry.indexes.length === 0)
    .map((entry) => entry.collectionGroup));
  for (const collectionGroup of [
    "_accountDeletionState",
    "captureIntents",
    "observations",
    "_competitiveAudioReplayClaims",
  ]) {
    assert.equal(ttlGroups.has(collectionGroup), true, collectionGroup);
  }
  assert.deepEqual(
    (config.indexes ?? []).find(
      (entry) => entry.collectionGroup === "_accountDeletionState"
    ),
    {
      collectionGroup: "_accountDeletionState",
      queryScope: "COLLECTION",
      fields: [
        {fieldPath: "status", order: "ASCENDING"},
        {fieldPath: "updatedAt", order: "ASCENDING"},
      ],
    }
  );
});

test("friendship authority storage is callable-only", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  for (const collection of [
    "_socialFriendLinks",
    "_socialFriendInvites",
    "_socialReferences",
  ]) {
    const start = rules.indexOf(`match /${collection}/{document=**}`);
    assert.notEqual(start, -1, collection);
    assert.match(
      rules.slice(start, start + 130),
      /allow read, write: if false;/
    );
  }
});

test("only complete STOP generations are accepted", () => {
  assert.equal(isAcceptableFinishReason("STOP"), true);
  const rejected = [
    "MAX_TOKENS", "SAFETY", "RECITATION", "UNKNOWN", null,
  ];
  for (const reason of rejected) {
    assert.equal(isAcceptableFinishReason(reason), false);
  }
});

test(
  "operational coach logs contain neither content nor account identity",
  () => {
    const input = validateCoachChatRequest(request);
    const metadata = coachCompletionLogMetadata(
      input,
      "gemini-2.5-flash",
      "STOP",
      200,
      40,
      900,
      "ok"
    );
    const serialized = JSON.stringify(metadata);
    assert.equal(serialized.includes(request.coachingContext), false);
    assert.equal(serialized.includes(request.messages[0].content), false);
    assert.equal(serialized.includes(request.accountID), false);
    assert.deepEqual(Object.keys(metadata).sort(), [
      "accountBinding", "finishReason", "inputTokens", "latencyMs", "model",
      "outputTokens", "policyVersion", "qualityTier", "requestID",
      "responseKind", "status", "surface", "turnDepth", "turnIntent",
    ]);

    const failure = coachFailureLogMetadata(
      input,
      "gemini-2.5-flash",
      900,
      "data-loss"
    );
    const serializedFailure = JSON.stringify(failure);
    assert.equal(serializedFailure.includes(request.coachingContext), false);
    assert.equal(
      serializedFailure.includes(request.messages[0].content),
      false
    );
    assert.equal(serializedFailure.includes(request.accountID), false);
    assert.deepEqual(Object.keys(failure).sort(), [
      "accountBinding", "latencyMs", "model", "policyVersion", "qualityTier",
      "requestID", "responseKind", "status", "surface", "turnDepth",
      "turnIntent",
    ]);
  }
);

test(
  "coach failure detail logging accepts only server-owned quality codes",
  () => {
    const safe = coachFailureQualityMetadata(new HttpsError(
      "failed-precondition",
      "SECRET_USER_CONTENT",
      {reason: "coach-quality-rejected", policyIssue: "missing-evidence-bridge"}
    ));
    assert.deepEqual(safe, {
      failureReason: "coach-quality-rejected",
      policyIssue: "missing-evidence-bridge",
    });

    const unsafe = coachFailureQualityMetadata(new HttpsError(
      "failed-precondition",
      "SECRET_USER_CONTENT",
      {reason: "SECRET_REASON", policyIssue: "SECRET_DRAFT"}
    ));
    assert.deepEqual(unsafe, {});
    assert.equal(JSON.stringify(unsafe).includes("SECRET"), false);

    const protectedLog = coachFailureLogMetadata(
      validateCoachChatRequest(request),
      "gemini-2.5-flash",
      120,
      "failed-precondition",
      "verified",
      {
        reason: "SECRET_REASON",
        policyIssue: "SECRET_DRAFT",
        requestID: "SECRET_OVERRIDE",
        accountBinding: "SECRET_ACCOUNT",
      }
    );
    const serialized = JSON.stringify(protectedLog);
    assert.equal(protectedLog.requestID, request.requestID);
    assert.equal(protectedLog.accountBinding, "verified");
    assert.equal(serialized.includes("SECRET"), false);

    const unrelated = coachFailureQualityMetadata(new HttpsError(
      "failed-precondition",
      "content-free",
      {reason: "other", policyIssue: "missing-evidence-bridge"}
    ));
    assert.deepEqual(unrelated, {});
  }
);

test("Vertex contents attach context once and coalesce adjacent roles", () => {
  const input = validateCoachChatRequest({
    ...request,
    messages: [
      {role: "assistant", content: "Earlier reply"},
      {role: "user", content: "First unanswered turn"},
      {role: "user", content: "Current turn"},
    ],
  });
  const contents = buildVertexContents(input);
  assert.equal(contents[0].role, "user");
  assert.equal(contents[1].role, "model");
  assert.equal(contents[2].role, "user");
  assert.equal(
    contents[2].parts[0].text.includes("First unanswered turn"),
    true
  );
  assert.equal(contents[2].parts[0].text.includes("Current turn"), true);
  const serialized = JSON.stringify(contents);
  assert.equal(serialized.match(/COACHING CONTEXT/g)?.length, 1);
  for (let index = 1; index < contents.length; index += 1) {
    assert.notEqual(contents[index - 1].role, contents[index].role);
  }
});

/**
 * Builds the smallest valid Vertex response fixture.
 * @param {string} text Candidate text.
 * @param {FinishReason|undefined} finishReason Candidate finish reason.
 * @param {boolean} includeUsage Whether to attach final token metadata.
 * @return {CoachGenerateContentResponse} Vertex response fixture.
 */
function vertexResponse(
  text: string,
  finishReason: FinishReason | undefined,
  includeUsage = false
): CoachGenerateContentResponse {
  const response: CoachGenerateContentResponse = {
    candidates: [{content: {parts: [{text}]}, finishReason}],
  };
  if (includeUsage) {
    response.usageMetadata = {
      promptTokenCount: 120,
      candidatesTokenCount: 24,
    };
  }
  return response;
}

/**
 * Builds a deterministic Vertex stream fixture.
 * @param {string[]} chunks Streamed text chunks.
 * @param {FinishReason} finishReason Final candidate reason.
 * @return {AsyncIterable<CoachGenerateContentResponse>} Vertex stream fixture.
 */
function vertexStream(
  chunks: string[],
  finishReason: FinishReason = FinishReason.STOP
): AsyncIterable<CoachGenerateContentResponse> {
  return (async function* () {
    if (chunks.length === 0) {
      yield vertexResponse("", finishReason, true);
      return;
    }
    for (const [index, chunk] of chunks.entries()) {
      const isFinal = index === chunks.length - 1;
      yield vertexResponse(
        chunk,
        isFinal ? finishReason : undefined,
        isFinal
      );
    }
  })();
}

test("legacy stream accepts a final metadata-only provider chunk", async () => {
  const input = validateLegacyCoachChatRequest({
    schemaVersion: 1,
    requestID: request.requestID,
    surface: "text",
    qualityTier: "fast",
    coachingContext: "Bounded context.",
    messages: [{role: "user", content: "Coach this."}],
  });
  const completion = await consumeLegacyCoachStream(
    input,
    "gemini-2.5-flash",
    {
      generate: async () => (async function* () {
        yield vertexResponse("Lead first.", undefined);
        yield vertexResponse("", FinishReason.STOP, true);
      })(),
    }
  );
  assert.deepEqual(completion, {
    requestID: request.requestID,
    text: "Lead first.",
    model: "gemini-2.5-flash",
    qualityTier: "fast",
    finishReason: "STOP",
    inputTokens: 120,
    outputTokens: 24,
  });
});

test("legacy stream preserves original empty and truncation failures",
  async () => {
    const input = validateLegacyCoachChatRequest({
      schemaVersion: 1,
      requestID: request.requestID,
      surface: "text",
      qualityTier: "fast",
      coachingContext: "Bounded context.",
      messages: [{role: "user", content: "Coach this."}],
    });
    for (const result of [
      vertexStream(["Partial"], FinishReason.MAX_TOKENS),
      vertexStream([], FinishReason.STOP),
    ]) {
      await assert.rejects(
        () => consumeLegacyCoachStream(
          input,
          "gemini-2.5-flash",
          {generate: async () => result}
        ),
        (error: unknown) => {
          const typed = error as HttpsErrorShape & {message?: string};
          return typed.code === "data-loss" &&
            typed.message === "Coach returned no usable text.";
        }
      );
    }
  });

test("legacy stream propagates provider errors for callable mapping",
  async () => {
    const input = validateLegacyCoachChatRequest({
      schemaVersion: 1,
      requestID: request.requestID,
      surface: "text",
      qualityTier: "fast",
      coachingContext: "Bounded context.",
      messages: [{role: "user", content: "Coach this."}],
    });
    const providerError = new Error("vertex unavailable");
    await assert.rejects(
      () => consumeLegacyCoachStream(
        input,
        "gemini-2.5-flash",
        {generate: async () => {
          throw providerError;
        }}
      ),
      providerError
    );
  });

test("legacy stream preserves callable disconnect cancellation", async () => {
  const input = validateLegacyCoachChatRequest({
    schemaVersion: 1,
    requestID: request.requestID,
    surface: "text",
    qualityTier: "fast",
    coachingContext: "Bounded context.",
    messages: [{role: "user", content: "Coach this."}],
  });
  const controller = new AbortController();
  const blockedStream: AsyncIterable<LegacyCoachGenerateContentResponse> =
    (async function* () {
      await new Promise<void>(() => undefined);
      yield vertexResponse("never sent", FinishReason.STOP, true);
    })();
  const pending = consumeLegacyCoachStream(
    input,
    "gemini-2.5-flash",
    {generate: async () => blockedStream, signal: controller.signal}
  );
  controller.abort();
  await assert.rejects(pending, (error: unknown) => {
    return typeof error === "object" && error !== null &&
      "code" in error && error.code === "cancelled";
  });
});

test("streams typed deltas and returns typed completion metadata", async () => {
  const deltas: unknown[] = [];
  const completion = await consumeCoachStream(
    validateCoachChatRequest(request),
    "gemini-2.5-flash",
    {
      generate: async () => vertexStream(["Lead first. ", "Add proof."]),
      sendDelta: async (delta) => {
        deltas.push(delta);
      },
    }
  );
  assert.deepEqual(deltas, [
    {type: "delta", requestID: request.requestID, text: "Lead first. "},
    {type: "delta", requestID: request.requestID, text: "Add proof."},
  ]);
  assert.deepEqual(completion, {
    requestID: request.requestID,
    text: "Lead first. Add proof.",
    model: "gemini-2.5-flash",
    policyVersion: COACH_POLICY_VERSION,
    qualityTier: "fast",
    generationMode: "model",
    finishReason: "STOP",
    inputTokens: 120,
    outputTokens: 24,
  });
});

test("accepts a final metadata-only Gen AI stream chunk", async () => {
  const completion = await consumeCoachStream(
    validateCoachChatRequest(request),
    "gemini-2.5-flash",
    {
      generate: async () => (async function* () {
        yield vertexResponse("Lead first.", undefined);
        yield vertexResponse("", FinishReason.STOP, true);
      })(),
    }
  );

  assert.equal(completion.text, "Lead first.");
  assert.equal(completion.finishReason, "STOP");
  assert.equal(completion.inputTokens, 120);
  assert.equal(completion.outputTokens, 24);
});

test("rejects truncated and empty Vertex completions", async () => {
  for (const result of [
    vertexStream(["Partial"], FinishReason.MAX_TOKENS),
    vertexStream([], FinishReason.STOP),
  ]) {
    await assert.rejects(() => consumeCoachStream(
      validateCoachChatRequest(request),
      "gemini-2.5-flash",
      {generate: async () => result}
    ));
  }
});

test("propagates Vertex failures for callable error mapping", async () => {
  const providerError = new Error("vertex unavailable");
  await assert.rejects(
    () => consumeCoachStream(
      validateCoachChatRequest(request),
      "gemini-2.5-flash",
      {generate: async () => {
        throw providerError;
      }}
    ),
    providerError
  );
});

test(
  "cancels an in-flight stream when the callable client disconnects",
  async () => {
    const controller = new AbortController();
    const blockedStream: AsyncIterable<CoachGenerateContentResponse> =
      (async function* () {
        await new Promise<void>(() => undefined);
        yield vertexResponse("never sent", FinishReason.STOP, true);
      })();
    const pending = consumeCoachStream(
      validateCoachChatRequest(request),
      "gemini-2.5-flash",
      {generate: async () => blockedStream, signal: controller.signal}
    );
    controller.abort();
    await assert.rejects(pending, (error: unknown) => {
      return typeof error === "object" && error !== null &&
      "code" in error && error.code === "cancelled";
    });
  }
);
