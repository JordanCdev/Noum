import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - BigMoment Model

enum BigMomentCategory: String, Codable, CaseIterable {
    case presentation
    case interview
    case review
    case conversation
    case publicSpeaking
    case other

    var title: String {
        switch self {
        case .presentation:  return "Presentation"
        case .interview:     return "Interview"
        case .review:        return "Review"
        case .conversation:  return "Conversation"
        case .publicSpeaking: return "Public speaking"
        case .other:         return "Other"
        }
    }

    var sfSymbol: String {
        switch self {
        case .presentation:  return "briefcase"
        case .interview:     return "person.crop.rectangle"
        case .review:        return "calendar.badge.clock"
        case .conversation:  return "text.bubble"
        case .publicSpeaking: return "mic.fill"
        case .other:         return "square.grid.2x2"
        }
    }

    /// Lowercase, sentence-embeddable form for coach copy and
    /// lock-screen notification bodies — "7 days to your presentation."
    /// reads better than "...your Presentation." with a mid-sentence
    /// capital. Use `title` for standalone labels (settings rows, sheet
    /// headers); use `displayName` inside running sentences.
    var displayName: String {
        switch self {
        case .presentation:  return "presentation"
        case .interview:     return "interview"
        case .review:        return "performance review"
        case .conversation:  return "difficult conversation"
        case .publicSpeaking: return "public speaking event"
        case .other:         return "big moment"
        }
    }
}

struct BigMoment: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var date: Date?
    var category: BigMomentCategory
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        date: Date? = nil,
        category: BigMomentCategory,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.category = category
        self.createdAt = createdAt
    }
}

// MARK: - BigMomentStore

@MainActor
final class BigMomentStore: ObservableObject {
    static let shared = BigMomentStore()

    @Published private(set) var activeMoment: BigMoment?
    @Published private(set) var archive: [BigMoment] = []

    private let accountKey = "NoumAccountID"
    private let activeMomentKeyPrefix = "bigMoment."
    private let archiveKeyPrefix = "bigMomentArchive."
    private static let archiveCap = 5

    private init() {}

    // MARK: - Lifecycle

    func reloadForCurrentAccount() {
        guard let accountID = currentAccountID else {
            activeMoment = nil
            archive = []
            return
        }
        activeMoment = Self.loadMoment(forKey: activeMomentKey(for: accountID))
        archive = Self.loadArchive(forKey: archiveKey(for: accountID))
        archiveExpiredIfNeeded(accountID: accountID)
    }

    func endSession() {
        activeMoment = nil
        archive = []
    }

    // MARK: - API

    func setMoment(_ moment: BigMoment) {
        guard let accountID = currentAccountID else { return }
        activeMoment = moment
        persist(accountID: accountID)
    }

    func clearMoment() {
        guard let accountID = currentAccountID else { return }
        activeMoment = nil
        UserDefaults.standard.removeObject(forKey: activeMomentKey(for: accountID))
    }

    func daysUntil() -> Int? {
        guard let moment = activeMoment else { return nil }
        return daysUntil(moment)
    }

    /// Days from today until `moment.date`, or nil if no date is set.
    /// Negative values mean the moment has passed. `nonisolated` because
    /// this is pure calendar math — no `activeMoment` read needed — so
    /// non-MainActor callers (e.g. `CoachContextBuilder.userContext`)
    /// can use it directly.
    nonisolated func daysUntil(_ moment: BigMoment) -> Int? {
        guard let date = moment.date else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: today, to: target)
        return components.day
    }

    // MARK: - Private

    private func archiveExpiredIfNeeded(accountID: String) {
        guard let moment = activeMoment,
              let date = moment.date,
              date < Calendar.current.startOfDay(for: Date()) else { return }
        var updatedArchive = archive
        updatedArchive.insert(moment, at: 0)
        if updatedArchive.count > Self.archiveCap {
            updatedArchive = Array(updatedArchive.prefix(Self.archiveCap))
        }
        archive = updatedArchive
        activeMoment = nil
        UserDefaults.standard.removeObject(forKey: activeMomentKey(for: accountID))
        if let data = try? JSONEncoder().encode(updatedArchive) {
            UserDefaults.standard.set(data, forKey: archiveKey(for: accountID))
        }
    }

    private func persist(accountID: String) {
        if let moment = activeMoment, let data = try? JSONEncoder().encode(moment) {
            UserDefaults.standard.set(data, forKey: activeMomentKey(for: accountID))
        }
    }

    private func activeMomentKey(for accountID: String) -> String {
        "\(activeMomentKeyPrefix)\(accountID)"
    }

    private func archiveKey(for accountID: String) -> String {
        "\(archiveKeyPrefix)\(accountID)"
    }

    private var currentAccountID: String? {
        KeychainHelper.load(key: accountKey)
    }

    private static func loadMoment(forKey key: String) -> BigMoment? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let moment = try? JSONDecoder().decode(BigMoment.self, from: data) else { return nil }
        return moment
    }

    private static func loadArchive(forKey key: String) -> [BigMoment] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let moments = try? JSONDecoder().decode([BigMoment].self, from: data) else { return [] }
        return moments
    }

    // MARK: - Auth Wipe

    func deleteAllData(for accountID: String) {
        UserDefaults.standard.removeObject(forKey: activeMomentKey(for: accountID))
        UserDefaults.standard.removeObject(forKey: archiveKey(for: accountID))
        if currentAccountID == accountID {
            activeMoment = nil
            archive = []
        }
    }
}
