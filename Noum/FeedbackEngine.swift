import Foundation

// MARK: - Coach Note

/// The three-part feedback structure shown after every session.
struct CoachNote {
    let momentum: String      // What is getting stronger
    let leverage: String      // What is currently holding the user back
    let nextStep: String      // What to do about it
}

// MARK: - Verdict Engine

/// Generates tone-aware, trend-informed feedback following the momentum/leverage/next-step pattern.
enum VerdictEngine {

    /// Generate a coach note from the current session and trend data.
    static func generate(
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        wpm: Double,
        score: Int,
        categoryRatings: [String: String],
        trends: [SkillTrend],
        primaryFocus: SkillArea,
        drillHistory: [DrillHistoryStore.Entry]
    ) -> CoachNote {
        let momentum = buildMomentum(
            fillerCount: fillerCount,
            wpm: wpm,
            score: score,
            categoryRatings: categoryRatings,
            trends: trends,
            drillHistory: drillHistory
        )

        let leverage = buildLeverage(
            primaryFocus: primaryFocus,
            fillerCount: fillerCount,
            wpm: wpm,
            duration: duration,
            wordCount: wordCount,
            categoryRatings: categoryRatings,
            trends: trends
        )

        let nextStep = buildNextStep(primaryFocus: primaryFocus, trends: trends)

        return CoachNote(momentum: momentum, leverage: leverage, nextStep: nextStep)
    }

    // MARK: - Momentum (What's Getting Stronger)

    private static func buildMomentum(
        fillerCount: Int,
        wpm: Double,
        score: Int,
        categoryRatings: [String: String],
        trends: [SkillTrend],
        drillHistory: [DrillHistoryStore.Entry]
    ) -> String {
        var strengths: [String] = []

        // Check for improving trends
        for trend in trends where trend.direction == .improving {
            switch trend.skillArea {
            case .fillerReduction:
                if let delta = trend.recentDelta {
                    strengths.append(delta)
                } else {
                    strengths.append("Your filler word control is getting stronger.")
                }
            case .paceControl:
                strengths.append("Your pace is becoming more controlled.")
            case .openingStrength:
                strengths.append("Your openings are getting more confident.")
            case .closingStrength:
                strengths.append("Your closings are landing more deliberately.")
            case .structure:
                strengths.append("Your answer structure is tightening up.")
            case .answerDevelopment:
                strengths.append("You're developing your ideas more fully.")
            default:
                strengths.append("Your \(trend.skillArea.displayName.lowercased()) is improving.")
            }
        }

        // Check for strong areas in this session
        if fillerCount == 0 && !strengths.contains(where: { $0.contains("filler") }) {
            strengths.append("Zero filler words — clean delivery.")
        }
        if wpm >= 110 && wpm <= 150 && !strengths.contains(where: { $0.contains("pace") }) {
            strengths.append("Natural, well-controlled pace.")
        }

        // Check strong category ratings
        let strongDimensions = categoryRatings.filter { $0.value == "Good" }.map(\.key)
        if strongDimensions.count >= 3 && strengths.isEmpty {
            strengths.append("Solid performance across \(strongDimensions.prefix(2).joined(separator: " and ").lowercased()).")
        }

        // Check drill streaks
        if let lastSkill = drillHistory.first?.skillArea {
            let streak = drillHistory.prefix(while: { $0.skillArea == lastSkill && $0.succeeded }).count
            if streak >= 3 {
                strengths.insert("\(lastSkill.displayName) is becoming second nature — \(streak) successful drills in a row.", at: 0)
            }
        }

        // Fallback — always find something
        if strengths.isEmpty {
            if score >= 7 {
                strengths.append("Solid session overall — you showed control and intention.")
            } else if score >= 5 {
                strengths.append("You showed up and practiced — that's the foundation everything else builds on.")
            } else {
                strengths.append("Every session builds the habit. The fact that you're here matters.")
            }
        }

        return strengths.prefix(2).joined(separator: " ")
    }

    // MARK: - Leverage (What's Holding You Back)

    private static func buildLeverage(
        primaryFocus: SkillArea,
        fillerCount: Int,
        wpm: Double,
        duration: TimeInterval,
        wordCount: Int,
        categoryRatings: [String: String],
        trends: [SkillTrend]
    ) -> String {
        let sensitivity = primaryFocus.feedbackSensitivity
        let trend = trends.first(where: { $0.skillArea == primaryFocus })

        switch primaryFocus {
        case .fillerReduction:
            return fillerLeverage(count: fillerCount, sensitivity: sensitivity, trend: trend)
        case .paceControl:
            return paceLeverage(wpm: wpm, sensitivity: sensitivity)
        case .openingStrength:
            return "Your opening is the biggest opportunity right now — a strong first sentence sets the tone for everything after."
        case .closingStrength:
            return "Your answer trailed off instead of ending with intention. A deliberate close is what people remember."
        case .structure:
            return "Your ideas ran together without clear structure. A simple framework makes even impromptu answers feel prepared."
        case .answerDevelopment:
            if duration < 15 {
                return "Your answer was only \(Int(duration)) seconds — too short to develop any real depth."
            }
            return "Your answer stayed surface-level. One well-developed idea with a specific example beats three shallow points."
        case .conciseSpeaking:
            if duration > 120 {
                return "Your answer ran long at \(Int(duration)) seconds. Being concise means finding the core of what you want to say."
            }
            return "Your delivery could be tighter. Try leading with your conclusion and cutting anything that doesn't directly support it."
        case .pauseUsage:
            return "Your delivery could use more breathing room. Deliberate pauses make your points land harder."
        case .vocalEmphasis:
            return "Your delivery was steady but flat. Varying your emphasis on key words makes your message more compelling."
        case .confidence:
            return "Your delivery had hedge words or hesitation that softened your authority. Committing to each statement changes how you're perceived."
        }
    }

    private static func fillerLeverage(count: Int, sensitivity: FeedbackSensitivity, trend: SkillTrend?) -> String {
        // Gentle framing for filler words — this is anxiety-adjacent
        if let trend, trend.direction == .improving {
            return "Fillers are still above target at \(count), but they've been coming down — you're moving in the right direction. The next drill can push this further."
        }

        if count >= 8 {
            return "\(count) filler words this session. This is common when your brain is working faster than your mouth — the fix is learning to pause instead of fill."
        } else if count >= 5 {
            return "\(count) filler words — most appeared at transition points between ideas. These are trainable moments."
        } else {
            return "A few filler words crept in at transition points. They're minor but noticeable."
        }
    }

    private static func paceLeverage(wpm: Double, sensitivity: FeedbackSensitivity) -> String {
        if wpm > 170 {
            return "Your pace hit \(Int(wpm)) WPM — noticeably fast. Speed can undermine clarity even when content is strong."
        } else if wpm > 150 {
            return "Your pace was a bit quick at \(Int(wpm)) WPM. Slowing your start can bring the whole answer into a more natural range."
        } else if wpm < 90 {
            return "Your pace was \(Int(wpm)) WPM — quite measured. A slightly quicker conversational pace can help your delivery feel more natural."
        } else if wpm < 110 {
            return "Your pace was a touch slow at \(Int(wpm)) WPM. Committing to each sentence before starting it can help maintain flow."
        }
        return "Your pace could be more consistent. Aim for a natural conversational rhythm."
    }

    // MARK: - Next Step

    private static func buildNextStep(primaryFocus: SkillArea, trends: [SkillTrend]) -> String {
        let trend = trends.first(where: { $0.skillArea == primaryFocus })

        // If improving, acknowledge and push forward
        if trend?.direction == .improving {
            return "You're making progress here. One focused drill can solidify the gains."
        }

        // If new issue, be reassuring
        if trend?.direction == .newIssue {
            return "This just popped up — a quick drill can reset it before it becomes a pattern."
        }

        // Default: point to the drill
        return "A focused drill on \(primaryFocus.displayName.lowercased()) is the best next step."
    }

    // MARK: - Dynamic Drill Rationale

    /// Generate a session-specific rationale for why this drill was selected.
    /// This is NOT a static template — it uses the session's actual data.
    static func drillRationale(
        for skillArea: SkillArea,
        fillerCount: Int,
        wpm: Double,
        duration: TimeInterval,
        wordCount: Int,
        categoryRatings: [String: String]
    ) -> String {
        switch skillArea {
        case .fillerReduction:
            if fillerCount >= 8 {
                return "You used \(fillerCount) filler words — they clustered at transition points when your brain was searching for the next thought."
            } else if fillerCount >= 5 {
                return "You used \(fillerCount) filler words this session. Most speakers can cut these significantly with focused practice."
            } else {
                return "You had \(fillerCount) filler words — they appeared between ideas and made transitions less clean."
            }

        case .openingStrength:
            return "Your opening didn't land with impact. The first sentence is where confidence is established."

        case .closingStrength:
            return "Your answer trailed off rather than ending with conviction. A strong close is what stays with the listener."

        case .paceControl:
            if wpm > 160 {
                return "Your pace hit \(Int(wpm)) WPM — faster than conversational. Slowing down makes you sound more in control."
            } else if wpm < 100 && duration >= 15 {
                return "Your pace was \(Int(wpm)) WPM — hesitant delivery can undermine strong content."
            }
            return "Your pace wasn't in the natural conversational range. Steady rhythm signals confidence."

        case .structure:
            return "Your answer didn't have clear sections. Without structure, even good ideas blur together."

        case .answerDevelopment:
            if duration < 15 {
                return "Your answer was only \(Int(duration)) seconds — too short to develop any real point."
            }
            return "Your content stayed surface-level. Adding one specific example makes the difference."

        case .conciseSpeaking:
            if wordCount > 300 {
                return "You used \(wordCount) words — more than needed. Finding the core of your message is the skill."
            }
            return "Your delivery could be tighter. Lead with the conclusion, then support it."

        case .pauseUsage:
            return "Your delivery had no deliberate pauses. Pauses create emphasis and give the listener time to absorb."

        case .vocalEmphasis:
            return "Your delivery was consistent but lacked emphasis. Varying your tone on key words makes ideas stick."

        case .confidence:
            return "Some hedge words or hesitation softened your authority. Committing to each statement changes perception."
        }
    }
}

// MARK: - Drill Recommendation Engine (v2)

/// The upgraded drill engine that uses both session metrics and trend data.
enum DrillEngineV2 {

    /// Generate a drill recommendation using session data + cross-session trends.
    static func recommend(
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        score: Int,
        feedbackCategories: [(dimension: String, rating: String)],
        trendStore: SkillTrendStore = .shared,
        drillHistory: DrillHistoryStore = .shared
    ) -> DrillRecommendationV2 {
        let wpm = duration > 0 ? Double(wordCount) / duration * 60 : 0
        let isMinimal = wordCount < 5 || duration < 5

        // Build category ratings dict
        let categoryRatings = Dictionary(uniqueKeysWithValues: feedbackCategories.map { ($0.dimension, $0.rating) })

        // Get trends
        let trends = TrendAnalyzer.analyze(snapshots: trendStore.snapshots)

        // Build a current session snapshot for trend context
        let sessionSnapshot = SkillSnapshot(
            sessionId: UUID(),
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            wpm: wpm,
            score: score,
            categoryRatings: categoryRatings
        )

        // Determine primary focus area using trend intelligence
        let focusArea: SkillArea

        if isMinimal {
            focusArea = .answerDevelopment
        } else {
            focusArea = determineFocus(
                fillerCount: fillerCount,
                wpm: wpm,
                duration: duration,
                score: score,
                categoryRatings: categoryRatings,
                trends: trends,
                sessionSnapshot: sessionSnapshot,
                drillHistory: drillHistory
            )
        }

        // Select a fresh variation for this skill area
        guard let variation = DrillSelector.select(for: focusArea, history: drillHistory) else {
            // Extreme fallback
            let fallback = DrillCatalog.structureDrills.first!
            return DrillRecommendationV2(
                variation: fallback,
                reason: "Practice with intention — structure your answer clearly.",
                trendContext: nil,
                alternateFormat: nil
            )
        }

        // Generate dynamic rationale
        let reason = VerdictEngine.drillRationale(
            for: focusArea,
            fillerCount: fillerCount,
            wpm: wpm,
            duration: duration,
            wordCount: wordCount,
            categoryRatings: categoryRatings
        )

        // Get trend context
        let context = TrendAnalyzer.trendContext(for: focusArea, trends: trends)

        // Determine if alternate format should be offered
        let alternate: DrillFormat?
        if score >= 7 && variation.format == .miniDrill {
            alternate = .fullRetry
        } else if variation.format == .fullRetry {
            alternate = .miniDrill
        } else {
            alternate = nil
        }

        return DrillRecommendationV2(
            variation: variation,
            reason: reason,
            trendContext: context,
            alternateFormat: alternate
        )
    }

    // MARK: - Focus Determination

    private static func determineFocus(
        fillerCount: Int,
        wpm: Double,
        duration: TimeInterval,
        score: Int,
        categoryRatings: [String: String],
        trends: [SkillTrend],
        sessionSnapshot: SkillSnapshot,
        drillHistory: DrillHistoryStore
    ) -> SkillArea {
        // First: check if current session has a clear, urgent weakness
        let urgentFocus = urgentSessionFocus(
            fillerCount: fillerCount,
            wpm: wpm,
            duration: duration,
            categoryRatings: categoryRatings
        )

        // If we have trend data, let TrendAnalyzer weigh in
        if !trends.isEmpty {
            let trendFocus = TrendAnalyzer.primaryFocus(
                trends: trends,
                currentSessionSnapshot: sessionSnapshot,
                recentDrills: drillHistory.entries
            )

            // If session has an urgent weakness AND trend analysis agrees, use it
            if let urgent = urgentFocus, urgent == trendFocus {
                return urgent
            }

            // If session has an urgent weakness but trend says something else,
            // use session weakness if it's severe, otherwise trust trends
            if let urgent = urgentFocus {
                if fillerCount >= 8 || duration < 10 || wpm > 180 {
                    return urgent  // Severe session issue overrides trend
                }
                return trendFocus  // Moderate issue — trust the trend analysis
            }

            return trendFocus
        }

        // No trend data — fall back to session-only analysis
        return urgentFocus ?? sessionOnlyFocus(
            fillerCount: fillerCount,
            wpm: wpm,
            duration: duration,
            score: score,
            categoryRatings: categoryRatings
        )
    }

    /// Check for urgent single-session weaknesses.
    private static func urgentSessionFocus(
        fillerCount: Int,
        wpm: Double,
        duration: TimeInterval,
        categoryRatings: [String: String]
    ) -> SkillArea? {
        if fillerCount >= 5 { return .fillerReduction }
        if duration < 15 { return .answerDevelopment }
        if wpm > 160 { return .paceControl }
        if wpm > 0 && wpm < 100 && duration >= 15 { return .paceControl }
        if categoryRatings["Opening"] == "Could improve" { return .openingStrength }
        if categoryRatings["Structure"] == "Could improve" { return .structure }
        if categoryRatings["Close"] == "Could improve" { return .closingStrength }
        if categoryRatings["Depth"] == "Could improve" { return .answerDevelopment }
        if fillerCount >= 2 { return .fillerReduction }
        return nil
    }

    /// Session-only focus when no trend data exists (new users).
    private static func sessionOnlyFocus(
        fillerCount: Int,
        wpm: Double,
        duration: TimeInterval,
        score: Int,
        categoryRatings: [String: String]
    ) -> SkillArea {
        if fillerCount >= 5 { return .fillerReduction }
        if duration < 15 { return .answerDevelopment }
        if wpm > 160 { return .paceControl }
        if fillerCount >= 2 { return .fillerReduction }
        if categoryRatings["Opening"] == "Could improve" { return .openingStrength }
        if categoryRatings["Structure"] == "Could improve" { return .structure }
        if categoryRatings["Close"] == "Could improve" { return .closingStrength }
        if wpm > 0 && wpm < 100 && duration >= 15 { return .paceControl }
        if categoryRatings["Depth"] == "Could improve" { return .answerDevelopment }
        if score >= 7 { return .confidence }
        return .structure
    }
}
