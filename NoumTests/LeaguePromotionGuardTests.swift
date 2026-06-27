//
//  LeaguePromotionGuardTests.swift
//  NoumTests
//
//  Pins the league_promotion_guard invariant — the rule that decides whether a
//  tier change queues a "Promoted to …" celebration. Three guards, all of which
//  must hold simultaneously, and each of which has been a real or near-miss bug:
//    1. First launch never celebrates (a fresh install with a seeded mid-tier
//       rating must not claim an unearned promotion on open).
//    2. No celebration without rated evidence (don't promote off the default
//       placeholder rating).
//    3. Only UPWARD crossings celebrate (a rating dip re-tiers silently — never
//       shame a regression).
//  These lived inline in `recomputeTierAndBucket` with zero coverage; the pure
//  `shouldCelebratePromotion` predicate is now their single source of truth.
//

import Foundation
import Testing
@testable import Noum

@Suite
@MainActor
struct LeaguePromotionGuardTests {

    @Test func firstLaunchNeverCelebrates() {
        // Even a large upward jump with evidence must not fire before the
        // last-seen tier has been initialized.
        #expect(
            LeagueManager.shouldCelebratePromotion(
                isInitialized: false, hasRatedEvidence: true,
                lastSeenFloor: 0, newFloor: 1000
            ) == false
        )
    }

    @Test func noEvidenceNeverCelebrates() {
        #expect(
            LeagueManager.shouldCelebratePromotion(
                isInitialized: true, hasRatedEvidence: false,
                lastSeenFloor: 400, newFloor: 800
            ) == false
        )
    }

    @Test func upwardCrossingWithEvidenceCelebrates() {
        #expect(
            LeagueManager.shouldCelebratePromotion(
                isInitialized: true, hasRatedEvidence: true,
                lastSeenFloor: 400, newFloor: 800
            ) == true
        )
    }

    @Test func downwardCrossingStaysSilent() {
        // Never punish-shame on regression.
        #expect(
            LeagueManager.shouldCelebratePromotion(
                isInitialized: true, hasRatedEvidence: true,
                lastSeenFloor: 800, newFloor: 400
            ) == false
        )
    }

    @Test func sameTierNeverCelebrates() {
        #expect(
            LeagueManager.shouldCelebratePromotion(
                isInitialized: true, hasRatedEvidence: true,
                lastSeenFloor: 600, newFloor: 600
            ) == false
        )
    }
}
