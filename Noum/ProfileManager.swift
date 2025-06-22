import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@MainActor
final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @Published private(set) var xp: Int
    private let xpKey = "profileXP"

    private init() {
        xp = UserDefaults.standard.integer(forKey: xpKey)
    }

    func addXP(_ amount: Int) {
        guard amount > 0 else { return }
        xp += amount
        UserDefaults.standard.set(xp, forKey: xpKey)
    }

    /// Progress towards the next level as a value between 0 and 1.
    var progressTowardsNextLevel: Double {
        Double(xp % 1000) / 1000.0
    }

    private let mainLevels = [
        "Beginner Speaker",
        "Novice Speaker",
        "Average Speaker",
        "Professional Speaker",
        "World Class Speaker"
    ]

    var levelTitle: String {
        let totalLevel = xp / 1000
        let mainIndex = min(totalLevel / 3, mainLevels.count - 1)
        let subIndex = totalLevel % 3
        let roman = ["I", "II", "III"][min(subIndex, 2)]
        return "\(mainLevels[mainIndex]) \(roman)"
    }

    static func levelTitle(forXP xp: Int) -> String {
        let manager = ProfileManager.shared
        let totalLevel = xp / 1000
        let mainIndex = min(totalLevel / 3, manager.mainLevels.count - 1)
        let subIndex = totalLevel % 3
        let roman = ["I", "II", "III"][min(subIndex, 2)]
        return "\(manager.mainLevels[mainIndex]) \(roman)"
    }

    static func progressTowardsNextLevel(forXP xp: Int) -> Double {
        Double(xp % 1000) / 1000.0
    }

    static func xpNeededToNextLevel(forXP xp: Int) -> Int {
        1000 - (xp % 1000)
    }
}
#endif
