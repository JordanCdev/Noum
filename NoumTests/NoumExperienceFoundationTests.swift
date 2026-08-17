import SwiftUI
import Testing
@testable import Noum
#if canImport(UIKit)
import UIKit
#endif

@Suite("Noum experience foundation")
struct NoumExperienceFoundationTests {
    @Test("Motion has exactly three semantic tiers")
    func motionTierVocabularyIsClosed() {
        #expect(NoumMotionTier.allCases.count == 3)
        #expect(NoumMotionTier.calm.allowance(reduceMotion: false).particleLimit == 0)
        #expect(NoumMotionTier.responsive.allowance(reduceMotion: false).particleLimit == 0)
        #expect(
            NoumMotionTier.earned.allowance(reduceMotion: false).particleLimit
                == NoumMotionMetric.maximumEarnedParticles
        )
        #expect(RetryRewardBeat.celebrationParticles == NoumMotionMetric.maximumEarnedParticles)
    }

    @Test("Reduce Motion removes spatial and particle effects")
    func reducedMotionAllowanceIsStatic() {
        for tier in NoumMotionTier.allCases {
            let allowance = tier.allowance(reduceMotion: true)
            #expect(allowance.maximumScaleDelta == 0)
            #expect(allowance.maximumTranslation == 0)
            #expect(allowance.particleLimit == 0)
            #expect(!allowance.allowsRepetition)
            #expect(allowance.duration <= 0.20)
        }
    }

    @Test("No experience tier authorizes an infinite loop")
    func fullScreenMotionNeverLoops() {
        for tier in NoumMotionTier.allCases {
            #expect(!tier.allowance(reduceMotion: false).allowsRepetition)
        }
    }

    @Test("Waveform states use the appropriate intensity")
    func waveformStatesMapToMotionSemantics() {
        #expect(NoumWaveformState.idle.motionTier == .calm)
        #expect(NoumWaveformState.listening.motionTier == .responsive)
        #expect(NoumWaveformState.processing.motionTier == .calm)
        #expect(NoumWaveformState.allCases.count == 3)
    }

    @Test("Progress values cannot draw outside their track")
    @MainActor
    func progressClampsAtBothBounds() {
        #expect(NoumProgressTrack(value: -0.5, label: "Progress").normalizedValue == 0)
        #expect(NoumProgressTrack(value: 0.42, label: "Progress").normalizedValue == 0.42)
        #expect(NoumProgressTrack(value: 1.5, label: "Progress").normalizedValue == 1)
    }

    @Test("Rewards require earned content")
    func invalidRewardsDoNotRender() {
        #expect(!NoumRewardKind.xp(0).isRenderable)
        #expect(!NoumRewardKind.xp(-10).isRenderable)
        #expect(NoumRewardKind.xp(10).isRenderable)
        #expect(!NoumRewardKind.milestone("   ").isRenderable)
        #expect(NoumRewardKind.milestone("First hold").isRenderable)
        #expect(NoumRewardKind.evidenceSaved.isRenderable)
    }

    @Test("Static graphic roles are closed, distinct, and never waveforms")
    func semanticGraphicVocabularyIsIntentional() {
        let symbols = NoumSemanticGraphicRole.allCases.map(\.systemName)
        #expect(Set(symbols).count == symbols.count)
        #expect(symbols.allSatisfy { !$0.localizedCaseInsensitiveContains("waveform") })
        #expect(NoumRewardKind.xp(10).semanticGraphicRole == .earnedXP)
        #expect(NoumRewardKind.evidenceSaved.semanticGraphicRole == .evidenceSaved)
        #expect(NoumRewardKind.milestone("First hold").semanticGraphicRole == .milestone)
    }

    #if canImport(UIKit)
    @Test("Every semantic graphic is available on the target platform")
    @MainActor
    func semanticGraphicSymbolsResolve() {
        for role in NoumSemanticGraphicRole.allCases {
            #expect(UIImage(systemName: role.systemName) != nil, Comment(rawValue: role.rawValue))
        }
    }
    #endif

    @Test("Interactive controls retain Apple's minimum target")
    func minimumTouchTargetIsAccessible() {
        #expect(NoumControlMetric.minimumTouchTarget >= 44)
    }

    @Test("Reward ink clears AA against both gold stops")
    @MainActor
    func rewardContrastClearsAA() {
        let ink = ColorContrastGuardTests.rgb(AppColor.rewardGoldInk, .light)
        for stop in [AppColor.rewardGoldStart, AppColor.rewardGoldEnd] {
            let fill = ColorContrastGuardTests.rgb(stop, .light)
            #expect(ColorContrastGuardTests.contrastRatio(ink, fill) >= 4.5)
        }
    }
}
