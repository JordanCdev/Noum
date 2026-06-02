//
//  ReinforcementCopy.swift
//  Noum
//
//  Context-aware copy for reward moments, milestone celebrations,
//  drill feedback, and progress framing. No fake praise — every line
//  is specific, honest, and forward-looking.
//

import Foundation

// MARK: - Session Completion Copy

enum SessionCompletionCopy {

    /// Headline for the summary screen based on score and trajectory.
    static func headline(score: Int, previousAvg: Int?, isPersonalBest: Bool) -> String {
        if isPersonalBest {
            return "New personal best."
        }
        if let avg = previousAvg, score > avg + 1 {
            return "Clear step up from your recent baseline."
        }
        if score >= 8 {
            return "Strong session. Controlled and clear."
        }
        if score >= 6 {
            return "Solid session. Room to sharpen a few areas."
        }
        if let avg = previousAvg, score >= avg {
            return "Consistent with your recent sessions."
        }
        if score >= 4 {
            return "Tough one. Your next drill targets the gap."
        }
        return "Every rep builds the pattern. Come back for another."
    }

    /// Short XP context line shown near the XP badge.
    static func xpContext(xpEarned: Int, xpToNext: Int) -> String {
        if xpToNext <= xpEarned {
            return "Level up incoming."
        }
        if xpToNext <= 200 {
            return "\(xpToNext) XP to next level."
        }
        return "+\(xpEarned) XP earned."
    }
}

// MARK: - Drill Completion Copy

enum DrillCompletionCopy {

    /// Result title — never says "failed." Drill-specific when possible.
    static func title(succeeded: Bool) -> String {
        succeeded ? "Drill Complete" : "Keep Going"
    }

    /// Drill-type-aware result title with specific, outcome-mapped language.
    static func title(for outcome: MiniDrillOutcome) -> String {
        switch outcome.drillType {
        case .beatTheBrake:
            if outcome.succeeded {
                if let m = outcome.beatTheBrakeMetrics, m.zonePercentage >= 0.80 {
                    return "Cleaner Rhythm"
                }
                return "Controlled Pace"
            }
            if let m = outcome.beatTheBrakeMetrics, m.averageWPM > 140 {
                return "Rushed Finish"
            }
            return "Pace Slipped"

        case .landThePause:
            if outcome.succeeded {
                if let m = outcome.landThePauseMetrics, m.transitionFillers == 0 {
                    return "Clean Pauses"
                }
                return "Strong Transitions"
            }
            if let m = outcome.landThePauseMetrics, m.transitionFillers > 0 {
                return "Rushed Between Points"
            }
            return "Combo Broken"

        case .prepStack:
            if outcome.succeeded {
                return "Strong Stack"
            }
            if let m = outcome.prepStackMetrics, m.stepsCompleted <= 2 {
                return "Missing Support"
            }
            return "Weak Close"

        case .frameworkCheck:
            return frameworkTitle(for: outcome)

        case .standard:
            return title(for: outcome.drill.skillArea, succeeded: outcome.succeeded)
        }
    }

    /// Result title for a named-framework drill, keyed off the post-hoc
    /// structural verdict when present. Falls back to the generic skill-area
    /// title below the detector's evidence floor (no verdict) so a too-thin rep
    /// never gets a structural label it didn't earn.
    private static func frameworkTitle(for outcome: MiniDrillOutcome) -> String {
        switch outcome.frameworkVerdict {
        case .star(.turnDetected):
            return "Found the Turn"
        case .star(.flat):
            return "Set the Scene"
        case .claimCounter(.counterAcknowledged):
            return "Both Sides"
        case .claimCounter(.oneSided):
            return "One Side So Far"
        case .elevatorPitch(.landed):
            return "Pitch Landed"
        case .elevatorPitch(.overTime):
            return "Ran Long"
        case .elevatorPitch(.missingName):
            return "Who Are You?"
        case .elevatorPitch(.missingHook):
            return "Need a Hook"
        case .none:
            // Below the evidence floor — fall back to the neutral skill title.
            return title(for: outcome.drill.skillArea, succeeded: outcome.succeeded)
        }
    }

    /// Skill-area-aware titles for standard drills.
    private static func title(for skillArea: SkillArea, succeeded: Bool) -> String {
        switch skillArea {
        case .fillerReduction:
            return succeeded ? "Clean Run" : "Keep Cleaning"
        case .paceControl:
            return succeeded ? "Steady Pace" : "Pace Check"
        case .openingStrength:
            return succeeded ? "Strong Open" : "Sharpen the Hook"
        case .closingStrength:
            return succeeded ? "Clean Close" : "Stick the Landing"
        case .structure:
            return succeeded ? "Clear Framework" : "Build the Frame"
        case .answerDevelopment:
            return succeeded ? "Fully Developed" : "Go Deeper"
        case .conciseSpeaking:
            return succeeded ? "Tight and Focused" : "Trim the Fat"
        case .pauseUsage:
            return succeeded ? "Deliberate Pauses" : "Let It Breathe"
        case .vocalEmphasis:
            return succeeded ? "Strong Delivery" : "More Color"
        case .confidence:
            return succeeded ? "Steady and Sure" : "Commit to It"
        }
    }

    /// Skill-specific one-liner based on actual metrics.
    static func feedbackLine(
        skillArea: SkillArea,
        succeeded: Bool,
        fillerCount: Int,
        wordCount: Int,
        duration: TimeInterval,
        wpm: Double
    ) -> String {
        switch skillArea {
        case .fillerReduction:
            if succeeded {
                if fillerCount == 0 {
                    return "Zero filler words — clean run."
                }
                return "Just \(fillerCount) filler — nearly clean."
            }
            return "\(fillerCount) filler\(fillerCount == 1 ? "" : "s") — getting closer to clean."

        case .paceControl:
            let wpmInt = Int(wpm)
            if succeeded {
                return "\(wpmInt) WPM — right in the zone."
            }
            if wpm > 160 {
                return "\(wpmInt) WPM — still running hot. Slow the opening."
            }
            return "\(wpmInt) WPM — push for more energy and flow."

        case .openingStrength:
            if succeeded {
                return "Strong open. \(wordCount) words, clear thesis."
            }
            return "Solid start. Push for a sharper first line."

        case .closingStrength:
            if succeeded {
                return "Clean close. Landed with conviction."
            }
            return "The end trailed off. Try finishing with a statement, not a fade."

        case .structure:
            if succeeded {
                return "Clear framework. Distinct sections."
            }
            return "Good content. Needs sharper transitions between points."

        case .answerDevelopment:
            let durInt = Int(duration)
            if succeeded {
                return "\(durInt)s with \(wordCount) words. Developed and complete."
            }
            return "Push deeper. Add a specific example or 'so what' line."

        case .conciseSpeaking:
            let durInt = Int(duration)
            if succeeded {
                return "\(durInt)s, \(wordCount) words. Tight and focused."
            }
            return "\(durInt)s — trim the extras. Lead with the point."

        case .pauseUsage:
            if succeeded {
                return "Clean pauses. No fillers filling the gaps."
            }
            return "Let the silence land. Pauses are your tool, not your enemy."

        case .vocalEmphasis:
            if succeeded {
                return "Good energy and emphasis. The words carried weight."
            }
            return "Vary your delivery. Emphasize the words that matter most."

        case .confidence:
            if succeeded {
                return "Steady delivery. \(fillerCount == 0 ? "No" : "Minimal") hesitation."
            }
            return "Good attempt. Commit to your first sentence — the rest follows."
        }
    }

    /// Streak acknowledgment — only shown when relevant.
    static func streakLine(count: Int, skillArea: SkillArea) -> String? {
        guard count >= 2 else { return nil }
        if count >= 5 {
            return "\(count) in a row for \(skillArea.displayName). Becoming second nature."
        }
        return "\(count) in a row."
    }

    /// "Try another" button framing.
    static func tryAnotherLabel(succeeded: Bool) -> String {
        succeeded ? "Try Another Variation" : "Try Another Drill"
    }

    // MARK: - Specialized Drill Feedback

    /// Beat the Brake — pace zone drill feedback.
    static func beatTheBrakeFeedback(metrics: BeatTheBrakeMetrics, succeeded: Bool) -> String {
        let pct = Int(metrics.zonePercentage * 100)
        let avg = Int(metrics.averageWPM)
        if succeeded {
            return "\(pct)% pace control at \(avg) WPM avg; this trained slowing down before filler pressure builds."
        }
        if metrics.averageWPM > 140 {
            return "\(pct)% pace control; \(metrics.rushedBursts) rushed burst\(metrics.rushedBursts == 1 ? "" : "s") pushed you past the target band."
        }
        if metrics.averageWPM < 110 {
            return "\(pct)% pace control; \(avg) WPM was below the challenge band."
        }
        return "\(pct)% pace control at \(avg) WPM; the goal is steadier rhythm, not zero fillers."
    }

    /// Land the Pause — checkpoint pause drill feedback.
    static func landThePauseFeedback(metrics: LandThePauseMetrics, succeeded: Bool) -> String {
        let locked = metrics.checkpointsLocked
        if succeeded {
            if metrics.transitionFillers == 0 {
                return "\(locked)/3 pauses banked; your transitions stayed clean."
            }
            return "\(locked)/3 pauses banked with \(metrics.transitionFillers) transition filler\(metrics.transitionFillers == 1 ? "" : "s")."
        }
        if locked == 0 {
            return "No pauses banked yet. Deliver one point, stop, then let the silence register."
        }
        return "\(locked)/3 pauses banked; the combo broke before all three points landed."
    }

    /// PREP Stack — guided structure drill feedback.
    static func prepStackFeedback(metrics: PREPStackMetrics, succeeded: Bool) -> String {
        let steps = metrics.stepsCompleted
        let dur = Int(metrics.totalDuration)
        if succeeded {
            return "Full PREP in \(dur)s with a clear final point."
        }
        if steps <= 2 {
            return "\(steps)/4 steps — push through all four. Point → Reason → Example → Point."
        }
        return "\(steps)/4 steps — strengthen the close so the stack lands."
    }

    /// Named-framework drill feedback (STAR turn / claim-counter / elevator
    /// pitch). The structural counterpart to `prepStackFeedback`: surfaces ONE
    /// constructive nudge keyed to the post-hoc `FrameworkDrillVerdict`. It is
    /// honest by construction:
    ///
    /// - A positive verdict (`turnDetected` / `counterAcknowledged` / `landed`)
    ///   names what the framework move was and why it worked.
    /// - A miss verdict frames the missing structural move as the next target —
    ///   never a verdict on whether the content was *right* (association, not
    ///   causation), and never punitive.
    /// - `nil` verdict (below the detector's evidence floor) falls back to the
    ///   generic skill-area feedback line: no confident "no turn" / "one-sided"
    ///   on thin data.
    ///
    /// `outcome` carries the verdict + the generic-fallback inputs.
    static func frameworkFeedback(outcome: MiniDrillOutcome) -> String {
        switch outcome.frameworkVerdict {
        case .star(.turnDetected):
            return "There's the turn — the pivot from setup to change is what makes a story land instead of describe."
        case .star(.flat):
            return "Solid scene-setting. Now find the turn: the \"…but then…\" or \"…until…\" moment where it changed."
        case .claimCounter(.counterAcknowledged):
            return "You named the counter, then bridged back — that's what makes a case persuasive, not just stated."
        case .claimCounter(.oneSided):
            return "Strong claim. Next, acknowledge the best counter (\"Some would say…\") before bridging back — it makes the argument land harder."
        case .elevatorPitch(.landed):
            return "Named yourself and landed one hook inside the box. That's a pitch, not a ramble."
        case .elevatorPitch(.overTime):
            return "Good substance — now tighten it under 30 seconds. The pitch is the doors-closing version."
        case .elevatorPitch(.missingName):
            return "One hook, but introduce yourself first — \"I'm…\" — the name is half the pitch."
        case .elevatorPitch(.missingHook):
            return "You named yourself — now land one concrete hook worth remembering, then stop."
        case .none:
            // Below the evidence floor: defer to the neutral skill-area line so
            // a too-thin rep never earns a structural claim it didn't support.
            let wpm = outcome.duration > 0 ? Double(outcome.wordCount) / outcome.duration * 60 : 0
            return feedbackLine(
                skillArea: outcome.drill.skillArea,
                succeeded: outcome.succeeded,
                fillerCount: outcome.fillerCount,
                wordCount: outcome.wordCount,
                duration: outcome.duration,
                wpm: wpm
            )
        }
    }
}

// MARK: - Milestone Copy

enum MilestoneCopy {

    static func sessionCount(_ count: Int) -> (title: String, subtitle: String, detail: String?) {
        switch count {
        case 10:
            return ("10 Sessions", "Double digits. You're building a real skill.", "Most people stop at 3.")
        case 25:
            return ("25 Sessions", "Serious commitment. Your patterns are locked in.", nil)
        case 50:
            return ("50 Sessions", "You've put in the reps. This isn't casual anymore.", nil)
        case 100:
            return ("100 Sessions", "Triple digits. You are the kind of person who practices.", nil)
        default:
            return ("\(count) Sessions", "Consistent practice compounds.", nil)
        }
    }

    static func streakMilestone(_ days: Int) -> (title: String, subtitle: String, detail: String?) {
        switch days {
        case 3:
            return ("3-Day Streak", "Three days running. Momentum building.", "Next milestone: 7 days")
        case 7:
            return ("7-Day Streak", "A full week of practice.", "Next milestone: 14 days")
        case 14:
            return ("14-Day Streak", "Two weeks. This is a habit now.", "Next milestone: 30 days")
        case 30:
            return ("30-Day Streak", "One month straight. Exceptional discipline.", nil)
        default:
            return ("\(days)-Day Streak", "You've practiced \(days) days in a row.", nil)
        }
    }

    static func skillResolved(_ skill: SkillArea) -> (title: String, subtitle: String, detail: String?) {
        return (
            "Issue Resolved",
            "\(skill.displayName) is no longer a concern.",
            "This hasn't flagged in your last several sessions."
        )
    }

    static func drillStreak(_ count: Int, skill: SkillArea) -> (title: String, subtitle: String, detail: String?) {
        return (
            "\(count)-Drill Streak",
            "\(count) successful \(skill.displayName.lowercased()) drills in a row.",
            "Consistency is how skill becomes instinct."
        )
    }
}

// MARK: - Trend Framing Copy

enum TrendFramingCopy {

    /// Context line for the skill progress card.
    static func trendContext(direction: TrendDirection, confidence: TrendConfidence, sessionsInWindow: Int) -> String {
        switch direction {
        case .improving:
            if confidence == .high {
                return "Improving steadily over \(sessionsInWindow) sessions."
            }
            return "Trending in the right direction."
        case .stable:
            if sessionsInWindow <= 1 {
                return "First read — not enough sessions yet to call a trend."
            }
            return "Stable for \(sessionsInWindow) sessions."
        case .declining:
            if confidence == .high {
                return "Slipping over your last \(sessionsInWindow) sessions."
            }
            return "Worth watching — recent sessions show a dip."
        case .newIssue:
            return "New — this hasn't been a problem before."
        case .resolved:
            return "Resolved. No longer flagging."
        }
    }

    /// Stagnation nudge — shown when a skill stays at the same level for many sessions.
    static func stagnationNudge(skill: SkillArea, sessionsAtLevel: Int) -> String? {
        guard sessionsAtLevel >= 8 else { return nil }
        return "\(skill.displayName) has been at the same level for \(sessionsAtLevel) sessions. A focused drill could break through."
    }
}

// MARK: - Return Copy

enum ReturnCopy {

    /// Welcome-back framing based on absence length.
    static func welcomeBack(daysAway: Int, lastScore: Int?) -> String {
        if daysAway >= 14 {
            return "Welcome back. Your patterns are still here — pick up where you left off."
        }
        if daysAway >= 7 {
            return "Good to see you back. A quick session will shake off the rust."
        }
        if daysAway >= 3 {
            return "Back at it. Consistency is everything."
        }
        return "Another day, another rep."
    }
}

// SkillArea.displayName is defined in DrillSystem.swift
