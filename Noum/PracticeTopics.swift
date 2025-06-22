import Foundation

struct PracticeTopics {
    static let topics: [String] = [
        "Describe your favorite vacation",
        "Talk about a memorable meal you've had",
        "Explain a hobby you enjoy",
        "Share an interesting fact you know",
        "Discuss a goal you have for the future"
    ]

    static func random() -> String {
        topics.randomElement() ?? "Talk about anything you like"
    }
}
