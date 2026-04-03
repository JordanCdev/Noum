import Foundation

/// Represents the WPM evaluation result with category and target range
public struct WPMRead {
    public let wpm: Int
    public let category: WPMCategory
    public let targetRange: ClosedRange<Double>
    public var label: String { category.label }
    
    public init(wpm: Int, category: WPMCategory, targetRange: ClosedRange<Double>) {
        self.wpm = wpm
        self.category = category
        self.targetRange = targetRange
    }
}

/// Categories for speaking pace based on scientific research
/// Reference: National Center for Voice and Speech, University of Iowa
/// Average conversational speech: 120-150 WPM
/// Professional presentations: 140-160 WPM
/// Broadcast news anchors: 150-170 WPM
public enum WPMCategory: String, Codable, CaseIterable {
    case verySlow      // < 100 WPM - unnaturally slow, may lose listener engagement
    case slow          // 100-120 WPM - deliberate pace, good for complex topics
    case optimal       // Mode-dependent optimal range
    case fast          // Approaching rushed, may reduce clarity
    case veryFast      // > 180 WPM - rushed, reduces comprehension
    
    public var label: String {
        switch self {
        case .verySlow: return "Very slow"
        case .slow: return "Slow"
        case .optimal: return "Optimal"
        case .fast: return "Fast"
        case .veryFast: return "Very fast"
        }
    }
    
    public var description: String {
        switch self {
        case .verySlow: return "May lose listener attention"
        case .slow: return "Deliberate and clear"
        case .optimal: return "Natural and engaging"
        case .fast: return "Approaching rushed"
        case .veryFast: return "Too fast for clarity"
        }
    }
}

/// Evaluates speaking pace (Words Per Minute) based on scientific research and context
public enum WPMEvaluator {
    
    /// Evaluates WPM with mode, tone, and scenario context
    /// - Parameters:
    ///   - wpm: Words per minute to evaluate
    ///   - modeRawValue: The practice mode as a string (timed, suddenDeath, ahCounter, imConversation)
    ///   - toneID: Optional tone identifier for IM mode (confident, empathetic, etc.)
    ///   - scenarioID: Optional scenario identifier for IM mode (work, difficult, social, etc.)
    /// - Returns: WPMRead containing the evaluation and target range
    public static func read(wpm: Double, modeRawValue: String, toneID: String? = nil, scenarioID: String? = nil) -> WPMRead {
        let range = adjustedRange(for: modeRawValue, toneID: toneID, scenarioID: scenarioID)
        let wpmInt = Int(round(wpm))
        let category: WPMCategory
        
        if range.contains(wpm) {
            category = .optimal
        } else if wpm < range.lowerBound {
            let diff = range.lowerBound - wpm
            category = diff <= 15 ? .slow : .verySlow
        } else {
            let diff = wpm - range.upperBound
            category = diff <= 15 ? .fast : .veryFast
        }
        
        return WPMRead(wpm: wpmInt, category: category, targetRange: range)
    }
    
    /// Calculates the optimal WPM range for a given mode with tone and scenario adjustments
    /// Scientific basis:
    /// - Conversational speech: 120-150 WPM (NCVS research)
    /// - Professional presentations: 140-160 WPM
    /// - Careful/deliberate: 100-130 WPM (complex topics, empathetic contexts)
    /// - Live conversations adjust slower for processing and turn-taking
    public static func adjustedRange(for modeRawValue: String, toneID: String? = nil, scenarioID: String? = nil) -> ClosedRange<Double> {
        let baseline: ClosedRange<Double>
        
        // Scientific WPM baselines by mode
        switch modeRawValue.lowercased() {
        case "timed":
            // Standard practice: professional presentation pace
            baseline = 130...160
            
        case "suddendeath":
            // High-pressure mode: slightly faster, controlled urgency
            // Research shows pressure increases pace by 10-15 WPM
            baseline = 140...170
            
        case "ahcounter":
            // Deliberate pace: focus on clarity and reducing fillers
            // Slower pace reduces cognitive load and filler production
            baseline = 110...140
            
        case "imconversation":
            // Live conversation: natural turn-taking pace
            // Research shows conversations are 15-20% slower than monologues
            // for processing, response formation, and listening
            baseline = 100...135
            
        default:
            // Default to conversational standard
            baseline = 120...150
        }
        
        // Only apply tone/scenario adjustments for IM mode
        guard modeRawValue.lowercased() == "imconversation" else {
            return clampRange(baseline)
        }
        
        let toneShift = toneShiftFor(toneID: toneID)
        let scenarioShift = scenarioShiftFor(scenarioID: scenarioID)
        
        let lower = baseline.lowerBound + toneShift + scenarioShift
        let upper = baseline.upperBound + toneShift + scenarioShift
        
        return clampRange(lower...upper)
    }
    
    /// Determines if the speaking pace is rushed
    public static func isRushed(wpm: Double, modeRawValue: String, toneID: String? = nil, scenarioID: String? = nil) -> Bool {
        let readResult = read(wpm: wpm, modeRawValue: modeRawValue, toneID: toneID, scenarioID: scenarioID)
        return readResult.category == .fast || readResult.category == .veryFast
    }
    
    /// Calculates a stability score (0-10) based on how close WPM is to the optimal range midpoint
    public static func stabilityScore(wpm: Double, targetRange: ClosedRange<Double>) -> Double {
        let mid = (targetRange.lowerBound + targetRange.upperBound) / 2.0
        let distance = abs(wpm - mid)
        // Score decreases by 1 point for every 6 WPM away from optimal
        let capped = min(distance / 6.0, 10.0)
        return max(0, 10 - capped)
    }
    
    // MARK: - Private helpers
    
    /// Adjusts WPM range based on communication tone
    /// Research basis: Emotional tone affects speech rate
    /// - Confident/assertive: +10-15 WPM (decisiveness, urgency)
    /// - Empathetic/calm: -10-15 WPM (deliberation, careful listening)
    private static func toneShiftFor(toneID: String?) -> Double {
        guard let tone = toneID?.lowercased() else { return 0 }
        
        // Confident, assertive, decisive: faster pace conveys certainty
        if tone.contains("confident") || tone.contains("assertive") || tone.contains("decisive") {
            return 12
        }
        
        // Empathetic, calm, warm: slower pace for connection and careful thought
        if tone.contains("calm") || tone.contains("empathetic") || tone.contains("warm") || tone.contains("compassionate") {
            return -12
        }
        
        // Friendly, casual: slightly slower for approachability
        if tone.contains("friendly") || tone.contains("casual") || tone.contains("relaxed") {
            return -6
        }
        
        // Energetic, enthusiastic: faster pace for excitement
        if tone.contains("energetic") || tone.contains("enthusiastic") || tone.contains("excited") {
            return 10
        }
        
        // Professional, formal: standard pace
        if tone.contains("professional") || tone.contains("formal") || tone.contains("business") {
            return 0
        }
        
        // Apologetic, careful: slower for consideration
        if tone.contains("apologetic") || tone.contains("careful") || tone.contains("cautious") {
            return -8
        }
        
        return 0
    }
    
    /// Adjusts WPM range based on conversation scenario
    /// Research basis: Context complexity affects optimal pace
    /// - Difficult conversations: -10-15 WPM (careful word choice, emotional processing)
    /// - Social/casual: -5-8 WPM (relaxed, relationship-building)
    /// - Networking: +5 WPM (energy, engagement)
    private static func scenarioShiftFor(scenarioID: String?) -> Double {
        guard let scenario = scenarioID?.lowercased() else { return 0 }
        
        // Difficult conversations: slow for careful navigation
        if scenario.contains("difficult") || scenario.contains("conflict") || scenario.contains("sensitive") {
            return -12
        }
        
        // Work updates, status: standard professional pace
        if scenario.contains("work") || scenario.contains("update") || scenario.contains("status") {
            return 0
        }
        
        // Networking: energetic, engaging pace
        if scenario.contains("networking") || scenario.contains("meeting") {
            return 6
        }
        
        // Social, casual: relaxed, conversational
        if scenario.contains("social") || scenario.contains("catch") || scenario.contains("casual") {
            return -6
        }
        
        // Feedback, coaching: measured, deliberate
        if scenario.contains("feedback") || scenario.contains("coaching") || scenario.contains("mentoring") {
            return -8
        }
        
        // Negotiation: controlled but not slow
        if scenario.contains("negotiation") || scenario.contains("sales") {
            return -3
        }
        
        return 0
    }
    
    /// Clamps the WPM range to realistic human speech boundaries
    /// Minimum: 80 WPM (extremely slow, still comprehensible)
    /// Maximum: 200 WPM (upper limit of human comprehension without training)
    private static func clampRange(_ range: ClosedRange<Double>) -> ClosedRange<Double> {
        let lower = max(80, range.lowerBound)
        let upper = min(200, range.upperBound)
        return lower...upper
    }
}
