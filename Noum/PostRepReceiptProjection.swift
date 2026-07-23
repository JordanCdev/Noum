import Foundation
#if canImport(SwiftUI)
import SwiftUI

/// Presentation-only projection for the single inline Results receipt.
/// Progress remains owned by SessionFinalizer and the existing stores; this
/// type only orders and deduplicates the events captured for the completed
/// rep so one meaningful update leads and every other update stays available.
@available(iOS 17.0, *)
struct PostRepReceiptProjection: Equatable {
    struct Update: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
        let systemImage: String
    }

    let primary: Update
    let additional: [Update]
    let practiceCredit: String?

    var allUpdates: [Update] { [primary] + additional }

    static func resolve(
        milestone: MilestoneEvent?,
        reachedNewPracticeLevel: Bool,
        practiceLevelTitle: String,
        skillEvents: [SkillLevelUpEvent],
        newUnlocks: [AchievementTier],
        practiceCredit: String?
    ) -> PostRepReceiptProjection? {
        var personalBest: [Update] = []
        var skillChanges: [Update] = []
        var coachingMilestones: [Update] = []
        var practiceMilestones: [Update] = []
        var achievementRecords: [Update] = []

        if let milestone {
            let title = cleanSentence(milestone.title)
            let update = Update(
                id: "milestone-\(normalized(title))",
                title: title,
                detail: joinedDetail(milestone.subtitle, milestone.detail),
                systemImage: milestone.icon
            )
            if normalized(title).contains("personal best") {
                personalBest.append(update)
            } else if normalized(title).contains("level up") {
                practiceMilestones.append(
                    Update(
                        id: update.id,
                        title: "Practice record updated",
                        detail: update.detail,
                        systemImage: "waveform.path"
                    )
                )
            } else {
                coachingMilestones.append(update)
            }
        }

        skillChanges.append(contentsOf: skillEvents.map { event in
            Update(
                id: "skill-\(event.skillArea.rawValue)",
                title: "\(event.skillArea.displayName) improved",
                detail: event.subline,
                systemImage: event.skillArea.icon
            )
        })

        if reachedNewPracticeLevel,
           !practiceMilestones.contains(where: { normalized($0.detail).contains(normalized(practiceLevelTitle)) }) {
            practiceMilestones.append(
                Update(
                    id: "practice-level-\(normalized(practiceLevelTitle))",
                    title: "Practice record updated",
                    detail: "Reached \(practiceLevelTitle)",
                    systemImage: "waveform.path"
                )
            )
        }

        achievementRecords.append(contentsOf: newUnlocks.map { tier in
            Update(
                id: "achievement-\(tier.id)",
                title: cleanSentence(tier.title),
                detail: "Recorded · \(cleanSentence(tier.description))",
                systemImage: tier.symbolName
            )
        })

        let ordered = personalBest
            + skillChanges
            + coachingMilestones
            + practiceMilestones
            + achievementRecords
        let deduplicated = deduplicate(ordered)
        guard let primary = deduplicated.first else { return nil }

        return PostRepReceiptProjection(
            primary: primary,
            additional: Array(deduplicated.dropFirst()),
            practiceCredit: practiceCredit
        )
    }

    private static func deduplicate(_ updates: [Update]) -> [Update] {
        var seen: Set<String> = []
        return updates.filter { update in
            let semanticKey = normalized(update.title)
            guard seen.insert(semanticKey).inserted else { return false }
            return true
        }
    }

    private static func joinedDetail(_ first: String, _ second: String?) -> String {
        let parts = [Optional(first), second]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }

    private static func cleanSentence(_ source: String) -> String {
        source.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private static func normalized(_ source: String) -> String {
        cleanSentence(source)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

#endif
