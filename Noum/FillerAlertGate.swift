import Foundation

struct FillerAlertDecision: Equatable {
    let detectionFired: Bool
    let shouldPlay: Bool
    let debugLine: String
}

struct FillerAlertGate {
    private var lastAlertDate: Date?
    private var lastHighConfidenceCount = 0

    var highConfidenceThreshold: Double = FillerDetection.suddenDeathThreshold
    var cooldown: TimeInterval = 1.2

    mutating func reset() {
        lastAlertDate = nil
        lastHighConfidenceCount = 0
    }

    mutating func evaluate(
        previousAdjustedCount: Int,
        adjustedCount: Int,
        detections: [FillerDetection],
        isEnabled: Bool,
        now: Date = Date()
    ) -> FillerAlertDecision {
        let highConfidenceCount = detections.filter { $0.confidence >= highConfidenceThreshold }.count
        let detectionFired = adjustedCount > previousAdjustedCount
        let highConfidenceIncrement = highConfidenceCount > lastHighConfidenceCount
        let elapsed = lastAlertDate.map { now.timeIntervalSince($0) } ?? .infinity
        let cooledDown = elapsed >= cooldown
        let shouldPlay = isEnabled && detectionFired && highConfidenceIncrement && cooledDown

        if shouldPlay {
            lastAlertDate = now
        }
        lastHighConfidenceCount = highConfidenceCount

        let reason: String
        if !isEnabled {
            reason = "disabled"
        } else if !detectionFired {
            reason = "no adjusted-count increase"
        } else if !highConfidenceIncrement {
            reason = "no new high-confidence filler"
        } else if !cooledDown {
            reason = "cooldown"
        } else {
            reason = "played"
        }

        return FillerAlertDecision(
            detectionFired: detectionFired,
            shouldPlay: shouldPlay,
            debugLine: "fired=\(detectionFired) play=\(shouldPlay) adjusted=\(adjustedCount) highConfidence=\(highConfidenceCount) reason=\(reason)"
        )
    }
}
