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
}
#endif
