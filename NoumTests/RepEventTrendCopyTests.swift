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

    private func trend(_ kind: RepEventTrend.EventKind, _ zone: RepEventLocations.Zone, _ dom: Int, _ total: Int, window: Int? = nil) -> RepEventTrend {
        // Default window == signal → the event carried every readable rep, so
        // the base-rate tail is suppressed and the clean subline is asserted.
        RepEventTrend(kind: kind, zone: zone, dominantCount: dom, repsWithSignal: total, windowRepCount: window ?? total)
    }

    // 1 — earned denominator, never "all reps"
    @Test("Evidence subline quotes the earned denominator, not all reps")
    func evidenceNamesEarnedDenominator() {
        let line = RepEventTrendCopy.evidenceSubline(for: trend(.rushedBurst, .close, 4, 5))
        #expect(line == "In 4 of your last 5 reps with a rushed stretch.")
        // Names the base ("with a rushed stretch") so it can't imply prevalence.
        #expect(line.contains("with a rushed stretch"))
    }

    // 1b — base-rate tail weights prevalence when the event was NOT in every rep
    @Test("Subline names the base rate when the event only surfaced in some reps")
    func evidenceNamesBaseRateWhenSparse() {
        // 5 of 6 readable reps rushed; 4 of those in the close. The tail must
        // name the 5-of-6 base rate so the read can't imply a rush on every rep.
        let line = RepEventTrendCopy.evidenceSubline(for: trend(.rushedBurst, .close, 4, 5, window: 6))
        #expect(line == "In 4 of your last 5 reps with a rushed stretch — 5 of 6 reps overall.")
        #expect(line.contains("5 of 6 reps overall"))
    }

    @Test("Base-rate tail is suppressed when the event carried every readable rep")
    func evidenceOmitsBaseRateWhenUniversal() {
        // repsWithSignal == windowRepCount → base rate is 100%, tail redundant.
        let line = RepEventTrendCopy.evidenceSubline(for: trend(.longestPause, .opening, 3, 4, window: 4))
        #expect(!line.contains("overall"))
        #expect(line.hasSuffix("with a notable pause."))
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

    @Test("A11y readout carries the SAME base rate the visual subline does")
    func a11yCarriesBaseRateWhenSparse() {
        // Sparse case (5 of 6) → VoiceOver must NOT get the un-hedged line the
        // sighted user no longer sees; it carries the base-rate clarifier too.
        let sparse = RepEventTrendCopy.accessibilityReadout(for: [trend(.rushedBurst, .close, 4, 5, window: 6)])
        #expect(sparse.contains("5 of 6 overall"))
        // Universal case (3 of 3) → no redundant base-rate tail, same as visual.
        let universal = RepEventTrendCopy.accessibilityReadout(for: [trend(.longestPause, .opening, 3, 3)])
        #expect(!universal.contains("overall"))
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

    // 5 — Home hero subtitle: the composed one-line projection.
    //     Locks the exact string a five-role panel + adversarial trust audit
    //     approved (zone-as-subject "keeps" framing + earned denominator).
    @Test("Home subtitle reuses the vetted headline and appends the earned denominator")
    func homeSubtitleComposesHeadlinePlusDenominator() {
        let line = RepEventTrendCopy.homeSubtitle(for: trend(.rushedBurst, .close, 4, 5))
        #expect(line == "Your fastest stretch keeps landing in the close — 4 of your last 5 reps that rushed.")
        // Reuses the vetted headline verbatim (period swapped for the clause).
        #expect(line.hasPrefix("Your fastest stretch keeps landing in the close"))
        #expect(line.contains("keeps"))                 // pattern, not a trait
    }

    @Test("Home subtitle never frames a trait or a second-person verdict")
    func homeSubtitleIsTraitSafe() {
        for kind in RepEventTrend.EventKind.allCases {
            let line = RepEventTrendCopy.homeSubtitle(for: trend(kind, .close, 3, 4)).lowercased()
            #expect(!line.contains("you rush"))
            #expect(!line.contains("you've rushed"))
            #expect(!line.contains("you are"))
            #expect(!line.contains("you always"))
            #expect(!line.contains("!"))                // no hype / exclamation
        }
    }

    @Test("Home subtitle denominator is reps-that-carried-the-event, never all reps")
    func homeSubtitleUsesEarnedDenominator() {
        // 4 dominant, 5 reps-with-signal, out of a 6-rep window. The line must
        // quote the SIGNAL denominator (5), never the window (6) — quoting 6
        // would imply the event happened on every rep (the red-line lie).
        let line = RepEventTrendCopy.homeSubtitle(for: trend(.rushedBurst, .close, 4, 5, window: 6))
        #expect(line.contains("4 of your last 5 reps"))
        #expect(!line.contains("of your last 6"))
    }

    @Test("Home subtitle names each kind's own event verb")
    func homeSubtitlePerKindVerb() {
        #expect(RepEventTrendCopy.homeSubtitle(for: trend(.rushedBurst, .close, 3, 3)).hasSuffix("reps that rushed."))
        #expect(RepEventTrendCopy.homeSubtitle(for: trend(.longestPause, .opening, 3, 3)).hasSuffix("reps that held a silence."))
        #expect(RepEventTrendCopy.homeSubtitle(for: trend(.fillerCluster, .middle, 3, 3)).hasSuffix("reps that leaned on fillers."))
    }
}
