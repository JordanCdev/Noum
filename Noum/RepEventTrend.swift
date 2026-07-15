import Foundation

// MARK: - Rep Event Trend Engine
//
// The LONGITUDINAL companion to `RepEventLocations`. Today the coach can read
// WHERE a single rep's events fell ("the fastest stretch ran in the close" —
// `CoachContextBuilder`'s POSITIONAL READ, most-recent rep only). A real coach
// does more: it notices when the SAME position keeps failing — "you've rushed
// the close in four of your last five reps" — and that recurring-location read
// is the difference between naming a slip and naming a habit.
//
// This engine turns the already-persisted per-rep `repEventLocations` into that
// recurring-position read. Design mirrors `DerivedReadsTrendEngine` deliberately:
//
// - **Pure function, no new persistence.** Every input already persists on
//   `PracticeSession.repEventLocations` (written at finalize by
//   `SpeechRecognizerViewModel`). This only reads the recent window and tallies.
// - **Honest by construction (CLAUDE.md: avoid fake certainty from small
//   samples).** A recurring position is named ONLY when, among the recent reps
//   that actually carried that event type, at least `minRepsWithSignal` reps
//   had it AND one zone holds a super-majority (`dominanceFloor`) with an
//   absolute floor of `minDominantReps` occurrences. Two reps rushing the close
//   never becomes "you rush the close." Below any floor the trend is omitted.
// - **A hypothesis about the REP SET, never a trait.** The copy reads "in N of
//   your last M reps … a recurring position, not a fixed trait" — association
//   over the reps, never a causal claim about the person. It counts only reps
//   where that event OCCURRED (the denominator is "reps with a rushed stretch",
//   not all reps), so a clean rep is never mis-counted as evidence of a pattern.
// - **Reads markers, not the person.** Same positional/factual voice as
//   `RepEventLocations.readout` — it locates a recurring event, never a verdict.

/// One recurring-position read across the recent rep window: the event type,
/// the zone it keeps landing in, and how strong the evidence is.
struct RepEventTrend: Codable, Equatable, Hashable {

    /// Which positional event recurred. Names only the three the per-rep
    /// `RepEventLocations` engine can honestly locate — nothing finer.
    enum EventKind: String, Codable, Equatable, CaseIterable {
        case rushedBurst
        case longestPause
        case fillerCluster
    }

    let kind: EventKind
    /// The zone the event keeps landing in.
    let zone: RepEventLocations.Zone
    /// How many of the recent reps-with-this-event had it in `zone`.
    let dominantCount: Int
    /// How many recent reps carried this event type at all (the denominator
    /// the pattern is measured against).
    let repsWithSignal: Int
    /// How many recent reps we could read positionally at all — the BASE RATE
    /// denominator. `repsWithSignal <= windowRepCount` always. Lets the readout
    /// weight prevalence: an event that keeps landing in one zone but only
    /// surfaces in a few of the readable reps is a narrower claim than one that
    /// surfaces in every rep. Without it, "in 3 of your last 3 reps with a
    /// rushed stretch" reads as pervasive even when only 3 of 6 reps rushed at
    /// all (CLAUDE.md: avoid fake certainty from small samples).
    let windowRepCount: Int

    /// Coach-voice readout naming the recurring position, framed as a rep-set
    /// hypothesis. Used by `CoachContextBuilder`'s POSITIONAL TREND section.
    var readout: String {
        let where_ = "the \(zone.label)"
        let evidence = "in \(dominantCount) of your last \(repsWithSignal) reps"
        // Weight prevalence honestly: when the event only surfaced in SOME of
        // the readable reps, name that base rate so a narrow-but-consistent
        // position can't read as something the user does on every rep. Omitted
        // when the event carried every readable rep (base rate is already 100%).
        let prevalence = repsWithSignal < windowRepCount
            ? " It showed up in \(repsWithSignal) of your last \(windowRepCount) reps overall."
            : ""
        switch kind {
        case .rushedBurst:
            return "You've rushed \(where_) \(evidence) that had a fast stretch — the fastest stretch keeps landing there.\(prevalence) A recurring position, not a fixed trait."
        case .longestPause:
            return "Your longest silence has fallen in \(where_) \(evidence) that had a notable pause.\(prevalence) A recurring position, not a fixed trait."
        case .fillerCluster:
            return "Fillers have clustered in \(where_) \(evidence) that had a filler cluster.\(prevalence) A recurring position, not a fixed trait."
        }
    }
}

enum RepEventTrendEngine {

    /// How many recent reps to consider. Positional signal is sparser than the
    /// per-rep composite scores `DerivedReadsTrendEngine` walks (many reps carry
    /// no qualifying pause/burst/cluster at all), so the window is a touch wider
    /// than that engine's 5 — enough reps to let a real habit surface.
    static let window: Int = 6

    /// Minimum recent reps that must have carried the event type before its
    /// position is even eligible to be called recurring. Below this the sample
    /// is too small to distinguish a habit from noise.
    static let minRepsWithSignal: Int = 3

    /// Absolute floor on how many reps put the event in the SAME zone. Combined
    /// with `minRepsWithSignal`, this means the smallest nameable pattern is
    /// 3-of-3 in one zone — never 2 reps, never a bare majority of a tiny set.
    static let minDominantReps: Int = 3

    /// The dominant zone must hold at least this share of the reps-with-signal.
    /// 0.6 = a clear super-majority; a 3/5 split (0.6) qualifies, a 3/6 (0.5)
    /// does not — a coin-flip between zones is not a recurring position.
    static let dominanceFloor: Double = 0.6

    /// Compose recurring-position reads across the recent window. Returns at
    /// most one trend per event kind, in a fixed kind order, and an empty array
    /// when nothing has earned a floor (so the coach context omits the section
    /// rather than padding it with a non-finding).
    static func compute(sessions: [PracticeSession]) -> [RepEventTrend] {
        // Newest-first, then the recent window — same ordering discipline as
        // `DerivedReadsTrendEngine.compute`.
        let recent = Array(
            PracticeProgressEligibility.eligibleSessions(in: sessions)
                .sorted { $0.date > $1.date }
                .prefix(window)
        )
        let locations = recent.compactMap { $0.repEventLocations }
        guard !locations.isEmpty else { return [] }

        var trends: [RepEventTrend] = []
        for kind in RepEventTrend.EventKind.allCases {
            if let trend = trend(for: kind, in: locations) {
                trends.append(trend)
            }
        }
        return trends
    }

    /// Tally one event kind's zones across the window and emit a trend only when
    /// every honesty floor is met. Pure; `internal` so tests can drive it
    /// directly on `[RepEventLocations]` without session fixtures.
    static func trend(
        for kind: RepEventTrend.EventKind,
        in locations: [RepEventLocations]
    ) -> RepEventTrend? {
        // Collect the zone each rep placed this event in (nil = rep didn't
        // carry this event, so it is not part of the denominator).
        let zones: [RepEventLocations.Zone] = locations.compactMap { loc in
            switch kind {
            case .rushedBurst:   return loc.rushedBurstZone
            case .longestPause:  return loc.longestPauseZone
            case .fillerCluster: return loc.fillerClusterZone
            }
        }
        guard zones.count >= minRepsWithSignal else { return nil }

        // Dominant zone — iterate in the enum's fixed order so ties resolve
        // deterministically (earliest zone wins), keeping the read test-stable.
        var counts: [RepEventLocations.Zone: Int] = [:]
        for zone in zones { counts[zone, default: 0] += 1 }
        var dominantZone: RepEventLocations.Zone?
        var dominantCount = 0
        for zone in RepEventLocations.Zone.allCases {
            let count = counts[zone] ?? 0
            if count > dominantCount {
                dominantZone = zone
                dominantCount = count
            }
        }
        guard let dominantZone else { return nil }

        // Honesty floors: absolute occurrence count AND super-majority share.
        guard dominantCount >= minDominantReps else { return nil }
        guard Double(dominantCount) / Double(zones.count) >= dominanceFloor else { return nil }

        return RepEventTrend(
            kind: kind,
            zone: dominantZone,
            dominantCount: dominantCount,
            repsWithSignal: zones.count,
            // Base rate: every rep we could read positionally in the window, not
            // just the ones that carried this event. `zones` is a compactMap
            // subset of `locations`, so repsWithSignal <= windowRepCount holds.
            windowRepCount: locations.count
        )
    }
}
