//
//  CoachProviderChainTests.swift
//  NoumTests
//
//  Contracts behind the coach-chat provider failover: chain ordering with
//  cooldowns, refusal classification, the Anthropic request/extract branch,
//  and the deterministic repeat-guard that stops a provider outage from
//  presenting as the coach saying the same line on every turn.
//

import Foundation
import Testing
@testable import Noum

// MARK: - Provider identity

struct CoachChatProviderTests {

    @Test func anthropicProviderShape() {
        let provider = CoachChatProvider.anthropic
        #expect(provider.model == "claude-haiku-4-5")
        #expect(provider.endpoint?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(provider.keyName == "ANTHROPIC_API_KEY")
        #expect(provider.sharedProvider == nil)
    }

    @Test func sharedProvidersMapToExistingPlumbing() {
        #expect(CoachChatProvider.gemini.sharedProvider == .gemini)
        #expect(CoachChatProvider.openAI.sharedProvider == .openAI)
        #expect(CoachChatProvider.deepSeek.sharedProvider == .deepSeek)
        // Endpoint/model read through to the shared definitions.
        #expect(CoachChatProvider.gemini.model == AIProvider.gemini.model)
        #expect(CoachChatProvider.gemini.endpoint == AIProvider.gemini.endpoint)
    }

    @Test func preferenceOrderIsDeclarationOrder() {
        #expect(CoachChatProvider.allCases.first == .gemini)
        #expect(CoachChatProvider.allCases.contains(.anthropic))
    }
}

// MARK: - Chain ordering + refusal classification

struct CoachProviderChainTests {

    @Test func keyedProvidersReadsEnvironment() {
        let env = ["ANTHROPIC_API_KEY": "sk-test", "GEMINI_API_KEY": ""]
        let keyed = AICoachChatService.keyedProviders(env: env)
        #expect(keyed.contains(.anthropic))
        // Empty env value doesn't count as a key by itself (the local plist
        // may still supply one on a dev machine, so only assert presence
        // semantics for the explicitly-keyed provider).
    }

    @Test func coolingProvidersMoveToTheBackNotOut() {
        let now = Date()
        let chain = AICoachChatService.orderedChain(
            keyed: [.gemini, .anthropic],
            cooldowns: [.gemini: now.addingTimeInterval(30)],
            now: now
        )
        #expect(chain == [.anthropic, .gemini], "a cooling provider is retried last, never dropped")
    }

    @Test func expiredCooldownRestoresPreferenceOrder() {
        let now = Date()
        let chain = AICoachChatService.orderedChain(
            keyed: [.gemini, .anthropic],
            cooldowns: [.gemini: now.addingTimeInterval(-1)],
            now: now
        )
        #expect(chain == [.gemini, .anthropic])
    }

    @Test func allCoolingStillTriesEveryone() {
        let now = Date()
        let chain = AICoachChatService.orderedChain(
            keyed: [.gemini, .anthropic],
            cooldowns: [.gemini: now.addingTimeInterval(60), .anthropic: now.addingTimeInterval(60)],
            now: now
        )
        #expect(chain.count == 2, "when everything is cooling the chain must still run")
    }

    @Test func refusalClassification() {
        #expect(CoachChatProviderRefusal.classify(status: 429) == .rateLimited)
        #expect(CoachChatProviderRefusal.classify(status: 401) == .authBlocked)
        #expect(CoachChatProviderRefusal.classify(status: 403) == .authBlocked)
        #expect(CoachChatProviderRefusal.classify(status: 500) == .transient)
        #expect(CoachChatProviderRefusal.classify(status: 529) == .transient)
        #expect(CoachChatProviderRefusal.contentRejected.cooldown == 0,
                "a content miss must not bench the provider")
        #expect(CoachChatProviderRefusal.authBlocked.cooldown > CoachChatProviderRefusal.rateLimited.cooldown,
                "a dead key cools longer than a quota window")
    }
}

// MARK: - Anthropic extraction

struct AnthropicExtractionTests {

    private func data(_ json: String) -> Data { Data(json.utf8) }

    @Test func extractsTextBlocks() {
        let payload = data("""
        {"content":[{"type":"text","text":"Lead with the point."}],"stop_reason":"end_turn"}
        """)
        let result = AICoachChatService.extractAnthropicReplyText(from: payload)
        #expect(result == .text("Lead with the point."))
    }

    @Test func truncatedReplyIsNeverCommitted() {
        let payload = data("""
        {"content":[{"type":"text","text":"This reply stops dead mid"}],"stop_reason":"max_tokens"}
        """)
        #expect(AICoachChatService.extractAnthropicReplyText(from: payload) == .lengthTruncated)
    }

    @Test func emptyContentIsEmpty() {
        let payload = data("""
        {"content":[],"stop_reason":"end_turn"}
        """)
        #expect(AICoachChatService.extractAnthropicReplyText(from: payload) == .empty)
    }

    @Test func malformedPayloadIsEmpty() {
        #expect(AICoachChatService.extractAnthropicReplyText(from: data("not json")) == .empty)
    }

    @Test func chatExtractRoutesSharedProvidersThroughExistingPath() {
        // OpenAI-shaped payload extracted via the chat wrapper for .openAI.
        let payload = data("""
        {"choices":[{"message":{"content":"Hold the pause."},"finish_reason":"stop"}]}
        """)
        let viaWrapper = AICoachChatService.chatExtractReplyText(from: payload, provider: .openAI)
        let direct = AICoachChatService.extractReplyText(from: payload, provider: .openAI)
        #expect(viaWrapper == direct)
    }
}

// MARK: - Deterministic repeat-guard

struct DeterministicRepeatGuardTests {

    @Test func identicalContextNeverRepeatsThePreviousBubble() {
        let context = ChatFallbackContext()
        let first = AICoachChatService.deterministicReplyOutcome(failure: .network, context: context)
        guard case .deterministicReply(let firstText) = first else {
            Issue.record("primary deterministic outcome should be a reply")
            return
        }

        let second = AICoachChatService.deterministicReplyOutcome(
            failure: .network,
            context: context,
            previousCoachText: firstText
        )
        guard case .deterministicReply(let secondText) = second else {
            Issue.record("repeat-guarded outcome should still be a reply")
            return
        }
        #expect(
            AICoachChatService.normalizedFallbackText(firstText) != AICoachChatService.normalizedFallbackText(secondText),
            "back-to-back outage turns must not produce the same bubble"
        )
    }

    @Test func noRepeatGuardWhenPreviousDiffers() {
        let context = ChatFallbackContext()
        let outcome = AICoachChatService.deterministicReplyOutcome(
            failure: .network,
            context: context,
            previousCoachText: "A genuinely different earlier reply."
        )
        guard case .deterministicReply(let text) = outcome else {
            Issue.record("expected a deterministic reply")
            return
        }
        let primary = AICoachChatService.deterministicReply(failure: .network, context: context)
        #expect(text == primary, "the primary line stays when it doesn't repeat")
    }

    @Test func alternateAvoidsTheGivenText() {
        let context = ChatFallbackContext()
        let primary = AICoachChatService.deterministicReply(failure: .network, context: context)
        let avoided = AICoachChatService.normalizedFallbackText(primary)!
        let alternate = AICoachChatService.alternateDeterministicReply(context: context, avoidingNormalized: avoided)
        #expect(AICoachChatService.normalizedFallbackText(alternate) != avoided)
        #expect(!alternate.contains("!"), "fallback copy keeps the no-exclamation contract")
        #expect(alternate.count <= 220)
    }

    @Test func alternateChainSurvivesAvoidingItsOwnFirstCandidate() {
        let context = ChatFallbackContext()
        // First call returns the lead+steady candidate; avoiding THAT must
        // surface the neutral honest line — never an empty string or repeat.
        let first = AICoachChatService.alternateDeterministicReply(context: context, avoidingNormalized: "never-matches")
        let second = AICoachChatService.alternateDeterministicReply(
            context: context,
            avoidingNormalized: AICoachChatService.normalizedFallbackText(first) ?? "never-matches"
        )
        #expect(!second.isEmpty)
        #expect(AICoachChatService.normalizedFallbackText(second) != AICoachChatService.normalizedFallbackText(first))
    }
}
