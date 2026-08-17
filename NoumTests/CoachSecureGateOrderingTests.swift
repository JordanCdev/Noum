import Foundation
import Testing

@Suite("Coach secure gate ordering")
struct CoachSecureGateOrderingTests {
    @Test("Secure replies are quality-gated before display residue stripping")
    func secureGateRunsBeforeFinalizer() throws {
        let source = try repositorySource("Noum/AICoachChatService.swift")
        let secureStart = try #require(source.range(of: "private func secureReply("))
        let providerCandidate = try #require(
            source.range(
                of: "let qualityCandidate = CoachReplyTextSanitizer.displayText",
                range: secureStart.lowerBound..<source.endIndex
            )
        )
        let secureGate = try #require(
            source.range(
                of: "Self.secureReplyQualityIssue(",
                range: providerCandidate.lowerBound..<source.endIndex
            )
        )
        let candidateInput = try #require(
            source.range(
                of: "in: qualityCandidate,",
                range: secureGate.lowerBound..<source.endIndex
            )
        )
        let finalizer = try #require(
            source.range(
                of: "let finalized = Self.finalizedCoachReply(",
                range: candidateInput.lowerBound..<source.endIndex
            )
        )

        #expect(providerCandidate.lowerBound < secureGate.lowerBound)
        #expect(secureGate.lowerBound < candidateInput.lowerBound)
        #expect(candidateInput.lowerBound < finalizer.lowerBound)
        #expect(source.contains("preFinalizerRawReportVoiceNeedsRepair"))
        #expect(source.contains("unrequested report voice"))
        #expect(source.contains("Secure coach scorecard used complete typed fallback"))
        #expect(source.contains("return .semanticJudgement(issue)"))
        #expect(source.contains("return visionQualityIssue("))
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
