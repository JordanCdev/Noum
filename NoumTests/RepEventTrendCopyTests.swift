//
//  RepEventTrendCopyTests.swift
//  NoumTests
//
//  Locks the pure copy contract behind `RepEventTrendCard` — the visible,
//  user-facing projection of `RepEventTrendEngine`'s output. Tests assert the
//  card can NEVER assert more than the engine earned:
//    1. the evidence subline names the earned denominator (dominant-of-signal),
//       never all reps — so a low base rate can't read as universal;
//    2. the headline names the recurring event + zone as a pattern ("keeps"),
//       never a trait verdict;
//    3. the hedge footer + a11y readout carry the rep-set framing;
//    4. every event kind maps to its own copy + the SAME symbol/color tokens
//       RepTimelineCard uses.

import Testing
import Foundation
@testable import Noum

@Suite("RepEventTrendCopyTests")
struct RepEventTrendCopyTests {

    private func trend(_ kind: RepEventTrend.EventKind, _ zone: RepEventLocations.Zone, _ dom: Int, _ total: Int) -> RepEventTrend {
        RepEventTrend(kind: kind, zone: zone, dominantCount: dom, repsWithSignal: total)
    }

    // 1 — earned denominator, never "all reps"
    @Test("Evidence subline quotes the earned denominator, not all reps")
    func evidenceNamesEarnedDenominator() {
        let line = RepEventTrendCopy.evidenceSubline(for: trend(.rushedBurst, .close, 4, 5))
        #expect(line == "In 4 of your last 5 reps with a rushed stretch.")
        // Names the base ("with a rushed stretch") so it can't imply prevalence.
        #expect(line.contains("with a rushed stretch"))
    }

    @Test("Each kind's subline names its own event base")
    func evidenceBasePerKind() {
        #expect(RepEventTrendCopy.evidenceSubline(for: trend(.longestPause, .opening, 3, 3)).contains("with a notable pause"))
        #expect(RepEventTrendCopy.evidenceSubline(for: trend(.fillerCluster, .middle, 3, 4)).contains("with a filler cluster"))
    }

    // 2 — headline is a pattern, never a trait
    @Test("Headline names event + zone as a recurring pattern, not a trait")
    func headlineIsPatternNotTrait() {
        let h = RepEventTrendCopy.headline(for: trend(.rushedBurst, .close, 4, 5))
        #expect(h == "Your fastest stretch keeps landing in the close.")
        #expect(h.contains("keeps"))
        let lowered = h.lowercased()
        #expect(!lowered.contains("you are"))
        #expect(!lowered.contains("you always"))
        #expect(!lowered.contains("you rush"))   // no verdict on the person
    }

    @Test("Pause + filler headlines name their zone")
    func headlinePerKindZone() {
        #expect(RepEventTrendCopy.headline(for: trend(.longestPause, .opening, 3, 3)).contains("opening"))
        #expect(RepEventTrendCopy.headline(for: trend(.fillerCluster, .middle, 3, 4)).contains("middle"))
    }

    // 3 — rep-set hedge on footer + a11y
    @Test("Hedge footer and a11y readout carry the rep-set framing")
    func hedgeFramingPresent() {
        #expect(RepEventTrendCopy.hedgeFooter.lowercased().contains("not a fixed trait"))
        let a11y = RepEventTrendCopy.accessibilityReadout(for: [trend(.rushedBurst, .close, 4, 5)])
        #expect(a11y.contains("Recurring pattern"))
        #expect(a11y.lowercased().contains("not a fixed trait"))
        #expect(a11y.contains("close"))
    }

    @Test("A11y readout covers every rendered trend")
    func a11yCoversAllTrends() {
        let a11y = RepEventTrendCopy.accessibilityReadout(for: [
            trend(.rushedBurst, .close, 4, 5),
            trend(.longestPause, .opening, 3, 3)
        ])
        #expect(a11y.contains("fastest stretch in the close"))
        #expect(a11y.contains("longest silence in the opening"))
    }

    // 4 — token reuse per kind
    @Test("Each kind maps to the RepTimelineCard token symbols")
    func styleReusesTimelineTokens() {
        #expect(RepEventTrendCopy.style(for: .rushedBurst).symbol == "hare.fill")
        #expect(RepEventTrendCopy.style(for: .longestPause).symbol == "pause.circle.fill")
        #expect(RepEventTrendCopy.style(for: .fillerCluster).symbol == "waveform")
    }
}
