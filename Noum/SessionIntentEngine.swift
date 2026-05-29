import Foundation

// MARK: - Session Intent Engine
//
// Pure-function options builder for the pre-rep "Today's focus?" sheet.
// Takes the active forward plan, the user's trend focus, and their
// coaching profile; produces 3 ordered `SessionIntent` options the
// prompt can render as chip buttons.
//
// Ordering rule: **earned options first.** A plan-week focus is the most
// earned (the coach handed the user a written program; honoring it is
// the strongest signal). Trend focus is next (the data says this is
// what's holding the user back). Profile goal is the floor (the user's
// stated long-term direction). A generic "Open rep" option is always
// appended last so the user can decline a focus and still tap something
// concrete.
//
// Deduplication rule: same `CoachingPriority` only appears once. If the
// plan-week priority and the trend-focus priority collapse to the same
// bucket, the trend-focus option is skipped (the plan-week reason label
// is more specific and feels more coach-grade).
//
// Bound: 4 options max. The generic option always lands. The chip row
// renders comfortably on every supported width up to 4 chips.

enum SessionIntentEngine {

    /// Build the option set the pre-rep prompt should render. Pure
    /// function — inputs in, ordered options out — so the tests can
    /// pin every branch without spinning up a SwiftUI runtime.
    ///
    /// - Parameters:
    ///   - forwardPlan: The user's active 4-week plan, if any. The
    ///     current week's focus is the highest-priority option.
    ///   - trendFocus: The skill area `TrendAnalyzer.primaryFocus(...)`
    ///     identified as the user's current weakest area, if any.
    ///   - profile: The user's coaching profile, if any. The
    ///     `primaryGoal` becomes the floor option.
    ///   - now: Clock injection (test-friendly). Used only to project
    ///     the plan's current week.
    ///   - calendar: Calendar injection (test-friendly).
    /// - Returns: 1 to 4 ordered `SessionIntent` options. Always
    ///   includes the generic "Open rep" option last.
    static func options(
        forwardPlan: ForwardPlan?,
        trendFocus: SkillArea?,
        profile: CoachingProfile?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [SessionIntent] {
        var out: [SessionIntent] = []
        var seenPriorities: Set<CoachingPriority> = []

        // 1) Plan-week focus — the most earned signal. The coach wrote
        //    a 4-week program; honoring this week's focus is the
        //    strongest declaration the user can make.
        if let plan = forwardPlan,
           let week = plan.currentWeek(now: now, calendar: calendar) {
            let priority = week.focus
            let intent = SessionIntent(
                priority: priority,
                label: priority.intentChipLabel,
                kind: .planWeek
            )
            out.append(intent)
            seenPriorities.insert(priority)
        }

        // 2) Trend focus — what the data says is holding the user back
        //    right now. Skipped if it collapses to the plan-week
        //    priority (no duplicate buckets).
        if let trendFocus {
            let priority = CoachingPriority.aligned(with: trendFocus)
            if !seenPriorities.contains(priority) {
                let intent = SessionIntent(
                    priority: priority,
                    label: priority.intentChipLabel,
                    kind: .trendFocus
                )
                out.append(intent)
                seenPriorities.insert(priority)
            }
        }

        // 3) Voice goal — the user's stated long-term direction. The
        //    floor option so cold-start users (no plan, no trends) still
        //    get a real chip beyond "Open rep".
        if let profile {
            let priority = profile.primaryGoal
            if !seenPriorities.contains(priority) {
                let intent = SessionIntent(
                    priority: priority,
                    label: priority.intentChipLabel,
                    kind: .voiceGoal
                )
                out.append(intent)
                seenPriorities.insert(priority)
            }
        }

        // 4) Generic — always present, always last. Gives the user a
        //    concrete "I just want to speak" option so they never have
        //    to dismiss the sheet awkwardly.
        let genericLabel = "Open rep"
        let generic = SessionIntent(
            // Pick a default priority for the generic option — pick the
            // user's profile goal when available so the metadata still
            // carries a useful signal even when they tap "Open rep".
            // Cold-start (no profile) falls through to `.calmerDelivery`
            // as the most universally-applicable starting point.
            priority: profile?.primaryGoal ?? .calmerDelivery,
            label: genericLabel,
            kind: .generic
        )
        out.append(generic)

        return out
    }
}
