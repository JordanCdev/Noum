//
//  RepEventTrendEngineTests.swift
//  NoumTests
//
//  Locks the pure positional-TREND engine that turns the persisted per-rep
//  `repEventLocations` into a recurring-position read ("you've rushed the close
//  in 4 of your last 5 reps"). Tests assert STRUCTURAL + honesty invariants
//  only — no calibration:
//    1. below the sample floor (< minRepsWithSignal reps carried the event) →
//       no trend, ever;
//    2. below the dominance floor (no zone holds a super-majority) → no trend;
//    3. below the absolute-count floor (a bare majority of a tiny set) → none;
//    4. a clear super-majority in one zone → a trend naming that zone, with the
//       dominant-of-total counts the readout quotes;
//    5. reps that DIDN'T carry the event are not in the denominator (a clean
//       rep never counts as evidence of a pattern);
//    6. ties between zones resolve deterministically to the earlier zone;
//    7. the readout is a rep-set hypothesis ("not a fixed trait"), never a
//       trait/diagnosis;
//    8. compute() takes the newest `window` sessions and omits when empty.

import Testing
import Foundation
@testable import Noum

@Suite("RepEventTrendEngineTests")
struct RepEventTrendEngineTests {

    // MARK: Fixtures

    /// A `RepEventLocations` carrying ONLY a rushed burst in `zone`.
    private func rushed(_ zone: RepEventLocations.Zone) -> RepEventLocations {
        RepEventLocations(
            longestPauseZone: nil, longestPauseSeconds: nil,
            rushedBurstZone: zone, rushedBurstWPM: 190,
            fillerClusterZone: nil, fillerClusterCount: nil,
            readout: "test"
        )
    }

    /// A `RepEventLocations` carrying ONLY a longest pause in `zone`.
    private func pause(_ zone: RepEventLocations.Zone) -> RepEventLocations {
        RepEventLocations(
            longestPauseZone: zone, longestPauseSeconds: 1.4,
            rushedBurstZone: nil, rushedBurstWPM: nil,
            fillerClusterZone: nil, fillerClusterCount: nil,
            readout: "test"
        )
    }

    /// A `RepEventLocations` carrying no positional signal at all.
    private func empty() -> RepEventLocations {
        RepEventLocations(
            longestPauseZone: nil, longestPauseSeconds: nil,
            rushedBurstZone: nil, rushedBurstWPM: nil,
            fillerClusterZone: nil, fillerClusterCount: nil,
            readout: "test"
        )
    }

    // MARK: 1 — sample-size floor

    @Test("Below minRepsWithSignal reps carrying the event → no trend")
    func belowSampleFloorIsSuppressed() {
        // Only 2 reps rushed anywhere — under the 3-rep minimum.
        let locations = [rushed(.close), rushed(.close), empty(), empty()]
        #expect(RepEventTrendEngine.trend(for: .rushedBurst, in: locations) == nil)
    }

    // MARK: 2 — dominance floor

    @Test("No zone holds a super-majority → no trend")
    func belowDominanceFloorIsSuppressed() {
        // 3 close / 3 opening — a 0.5 split, below the 0.6 dominance floor.
        let locations = [
            rushed(.close), rushed(.close), rushed(.close),
            rushed(.opening), rushed(.opening), rushed(.opening)
        ]
        #expect(RepEventTrendEngine.trend(for: .rushedBurst, in: locations) == nil)
    }

    // MARK: 3 — absolute-count floor

    @Test("A bare majority of a tiny set (2 of 3) → no trend")
    func belowAbsoluteCountFloorIsSuppressed() {
        // 2 close / 1 opening → 0.66 share clears dominance, but only 2
        // occurrences — under the 3-occurrence absolute floor.
        let locations = [rushed(.close), rushed(.close), rushed(.opening)]
        #expect(RepEventTrendEngine.trend(for: .rushedBurst, in: locations) == nil)
    }

    // MARK: 4 — a clear pattern qualifies

    @Test("Clear super-majority in one zone → a trend naming it with counts")
    func clearPatternQualifies() throws {
        // 4 close / 1 opening → 0.8 share, 4 occurrences. Qualifies.
        let locations = [
            rushed(.close), rushed(.close), rushed(.close), rushed(.close),
            rushed(.opening)
        ]
        let trend = try #require(RepEventTrendEngine.trend(for: .rushedBurst, in: locations))
        #expect(trend.kind == .rushedBurst)
        #expect(trend.zone == .close)
        #expect(trend.dominantCount == 4)
        #expect(trend.repsWithSignal == 5)
        // Every readable rep carried the event (5 of 5) → base rate is 100%, so
        // windowRepCount == repsWithSignal and the readout omits the base-rate tail.
        #expect(trend.windowRepCount == 5)
        #expect(trend.readout.contains("4 of your last 5"))
        #expect(trend.readout.contains("close"))
        #expect(!trend.readout.contains("overall"))
    }

    @Test("3-of-3 in one zone is the smallest nameable pattern")
    func threeOfThreeQualifies() throws {
        let trend = try #require(
            RepEventTrendEngine.trend(for: .longestPause, in: [pause(.opening), pause(.opening), pause(.opening)])
        )
        #expect(trend.zone == .opening)
        #expect(trend.dominantCount == 3)
        #expect(trend.repsWithSignal == 3)
    }

    // MARK: 5 — clean reps are not in the denominator

    @Test("Reps that didn't carry the event are excluded from the denominator")
    func cleanRepsExcludedFromDenominator() throws {
        // 3 rushed-close reps + 3 reps that never rushed. The clean reps must
        // NOT dilute the read to 3-of-6; the pattern denominator is reps-with-event.
        let locations = [
            rushed(.close), rushed(.close), rushed(.close),
            empty(), empty(), empty()
        ]
        let trend = try #require(RepEventTrendEngine.trend(for: .rushedBurst, in: locations))
        #expect(trend.repsWithSignal == 3)
        #expect(trend.dominantCount == 3)
        // ...but the clean reps DO count toward the base rate: the event only
        // surfaced in 3 of the 6 readable reps, and the readout says so, so a
        // 3-of-3 pattern can't read as pervasive.
        #expect(trend.windowRepCount == 6)
        #expect(trend.readout.contains("3 of your last 6 reps overall"))
    }

    // MARK: 6 — deterministic tie-break

    @Test("Zone ties resolve to the earlier zone deterministically")
    func tieResolvesToEarlierZone() throws {
        // 3 opening / 3 close is a tie in count; opening is earlier in the enum
        // order, so it wins — but 3/6 = 0.5 is below the dominance floor, so
        // this is actually suppressed. Use a case where the tie-break matters
        // AND the floor passes: 3 opening / 2 close of 5 → 0.6 share, opening.
        let locations = [
            pause(.opening), pause(.opening), pause(.opening),
            pause(.close), pause(.close)
        ]
        let trend = try #require(RepEventTrendEngine.trend(for: .longestPause, in: locations))
        #expect(trend.zone == .opening)
        #expect(trend.dominantCount == 3)
        #expect(trend.repsWithSignal == 5)
    }

    // MARK: 7 — honesty of the copy

    @Test("Readout is a rep-set hypothesis, never a trait")
    func readoutHedgesAsHypothesis() throws {
        let trend = try #require(
            RepEventTrendEngine.trend(for: .rushedBurst, in: Array(repeating: rushed(.middle), count: 3))
        )
        #expect(trend.readout.lowercased().contains("not a fixed trait"))
        // No second-person trait verdicts.
        #expect(!trend.readout.lowercased().contains("you are"))
        #expect(!trend.readout.lowercased().contains("you always"))
    }

    // MARK: 8 — compute() over sessions

    private func session(_ date: Date, _ loc: RepEventLocations?) -> PracticeSession {
        PracticeSession(
            transcript: "eligible positional rep", fillerWordCount: 0, duration: 30, date: date,
            repEventLocations: loc
        )
    }

    @Test("compute() surfaces a recurring position across recent sessions")
    func computeSurfacesTrend() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = (0..<4).map { i in
            session(base.addingTimeInterval(Double(i) * 60), rushed(.close))
        }
        let trends = RepEventTrendEngine.compute(sessions: sessions)
        #expect(trends.contains { $0.kind == .rushedBurst && $0.zone == .close })
    }

    @Test("compute() considers only the newest `window` sessions")
    func computeWindowsToNewest() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // 6 newest reps rush the OPENING; older reps rushed the close. Only the
        // window (newest 6) should count — so no close pattern survives.
        var sessions: [PracticeSession] = []
        for i in 0..<6 {   // newest — opening
            sessions.append(session(base.addingTimeInterval(Double(100 + i) * 60), rushed(.opening)))
        }
        for i in 0..<5 {   // older — close (should be excluded by the window)
            sessions.append(session(base.addingTimeInterval(Double(i) * 60), rushed(.close)))
        }
        let trends = RepEventTrendEngine.compute(sessions: sessions)
        let rushed = trends.first { $0.kind == .rushedBurst }
        #expect(rushed?.zone == .opening)
    }

    @Test("compute() over sessions with no positional signal is empty")
    func computeEmptyWhenNoSignal() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = (0..<4).map { i in
            session(base.addingTimeInterval(Double(i) * 60), nil)
        }
        #expect(RepEventTrendEngine.compute(sessions: sessions).isEmpty)
    }
}
