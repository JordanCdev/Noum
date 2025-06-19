import Foundation

struct FillerWordDetector {
    static let baseFillerWords: Set<String> = [
        "uh", "um", "er", "erm", "ah", "eh", "huh",
        "like", "so", "you know"
    ]

    static let fillerWordRegexes: [NSRegularExpression] = {
        var regexes: [NSRegularExpression] = []
        if let dynamic = try? NSRegularExpression(
            pattern: #"(?i)(?<!\w)(?:u+h{2,}|u+m{2,}|hu+h+|er{2,}|er+m{2,}|ah+|eh+|h+m+|m{2,})(?=\b|[^\w]|$)"#
        ) {
            regexes.append(dynamic)
        }
        for word in baseFillerWords {
            let escaped = NSRegularExpression.escapedPattern(for: word)
            let pattern = #"(?i)(?<!\w)\#(escaped)(?=\b|[^\w]|$)"#
            if let r = try? NSRegularExpression(pattern: pattern) {
                regexes.append(r)
            }
        }
        return regexes
    }()

    static func matches(in text: String) -> [NSTextCheckingResult] {
        fillerWordRegexes.flatMap { regex in
            regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        }
    }

    static func count(in text: String) -> Int {
        matches(in: text).count
    }
}
