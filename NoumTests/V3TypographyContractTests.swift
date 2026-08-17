import Foundation
import Testing

@Suite("V3 typography contracts")
struct V3TypographyContractTests {
    @Test("User-facing compact roles keep an eleven-point floor")
    func compactTypeFloor() throws {
        let source = try repositorySource("Noum/Typography.swift")

        #expect(source.contains("static let micro = Typography.figtree(size: 11"))
        #expect(source.contains("static let nav = Typography.figtree(size: 11"))
        #expect(!source.contains("static let micro = Typography.figtree(size: 10"))
        #expect(!source.contains("static let nav = Typography.figtree(size: 10"))
    }

    @Test("V3 primary-surface user copy keeps an eleven-point floor")
    func primarySurfaceCopyFloor() throws {
        let home = try repositorySource("Noum/HomeCoachCard.swift")
        let summaryCards = try repositorySource("Noum/SummaryCards.swift")
        let summary = try repositorySource("Noum/SummaryView.swift")
        let progress = try repositorySource("Noum/SessionHistoryView.swift")
        let timed = try repositorySource("Noum/TimedPracticeView.swift")

        #expect(home.contains("Typography.figtree(size: 11, weight: .heavy, relativeTo: .caption2)"))
        #expect(!home.contains("Typography.figtree(size: 10.5"))

        #expect(summaryCards.contains("Text(durationAssessment.rawValue)"))
        #expect(summaryCards.contains("Text(drill.format == .miniDrill ? \"Quick Drill\" : \"Full Retry\")"))
        #expect(summaryCards.contains("Text(confidenceLabel.uppercased())"))
        #expect(!summaryCards.contains("Typography.figtree(size: 9, weight: .bold, relativeTo: .caption2)"))

        #expect(!summary.contains(".font(.system(size: 10, weight: .bold))"))
        #expect(!summary.contains(".font(.system(size: 10, weight: .semibold))"))
        #expect(!progress.contains("Typography.figtree(size: 9.5"))

        #expect(!timed.contains("Text(\"Fillers\")\n                            .font(.system(size: 10"))
        #expect(!timed.contains("Text(\"READING YOUR REP\")\n                        .font(Typography.figtree(size: 10"))
    }

    @Test("Primary-surface exceptions are live or decorative fixed-format glyphs")
    func fixedFormatExceptionsRemainScoped() throws {
        let sources = [
            "Noum/HomeCoachCard.swift",
            "Noum/SummaryCards.swift",
            "Noum/SummaryView.swift",
            "Noum/SessionHistoryView.swift",
            "Noum/TimedPracticeView.swift",
        ]
        var exceptions: [(path: String, fragment: String)] = []
        for path in sources {
            let source = try repositorySource(path)
            exceptions += try subElevenTextFontFragments(in: source).map {
                (path: path, fragment: $0)
            }
        }

        // This contract is intentionally limited to the five V3 primary
        // surfaces above. REC/LIVE and the milestone time codes are compact,
        // fixed-format live readouts; they are the only user-visible Text
        // exceptions in that scope. Decorative Image glyph sizes are not copy.
        #expect(exceptions.count == 3)
        #expect(exceptions.allSatisfy { $0.path == "Noum/TimedPracticeView.swift" })
        #expect(exceptions.contains { $0.fragment.contains("Text(\"REC\")") })
        #expect(exceptions.contains { $0.fragment.contains("Text(\"LIVE\")") })
        #expect(exceptions.contains { $0.fragment.contains("Text(label)") })
    }

    private func subElevenTextFontFragments(in source: String) throws -> [String] {
        let regex = try NSRegularExpression(
            pattern: #"Text\([^\n]*\)\s*\n\s*\.font\([^\n]*size:\s*(?:[0-9](?:\.[0-9]+)?|10(?:\.[0-9]+)?)[,\)]"#
        )
        let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)
        return regex.matches(in: source, range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: source) else { return nil }
            return String(source[range])
        }
    }

    private func repositorySource(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let root = testsDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
