import Foundation
import Testing
@testable import Noum

@Suite("Private beta feedback")
struct BetaFeedbackReportTests {
    private let diagnostics = BetaFeedbackDiagnostics(
        appVersion: "1.1",
        buildNumber: "42",
        sourceCommit: "0123456789abcdef0123456789abcdef01234567",
        systemVersion: "iOS 26.2"
    )

    @Test("Report carries exact source-bound build context")
    func reportCarriesBuildContext() {
        let report = BetaFeedbackReport(
            category: .bug,
            message: "The retry button did not respond.",
            diagnostics: diagnostics
        )

        #expect(report.canSend)
        #expect(report.shareText.contains("Type: Something broke"))
        #expect(report.shareText.contains("App version: 1.1"))
        #expect(report.shareText.contains("Build: 42"))
        #expect(report.shareText.contains(diagnostics.sourceCommit))
        #expect(report.shareText.contains("System: iOS 26.2"))
        #expect(report.shareText.contains("No crash logs are attached"))
        #expect(report.shareText.contains("Flow: Settings"))
        #expect(report.shareText.contains("Screen: Beta feedback"))
    }

    @Test("Coach-quality feedback is a first-class category")
    func coachingCategoryIsAvailable() {
        let report = BetaFeedbackReport(
            category: .coaching,
            message: "The advice did not match what happened in the rep.",
            diagnostics: diagnostics
        )

        #expect(BetaFeedbackCategory.allCases.contains(.coaching))
        #expect(report.shareText.contains("Type: Coaching felt wrong"))
        #expect(report.subject.hasSuffix("Coaching quality"))
    }

    @Test("Flow and screen context is content-free and allowlisted")
    func flowScreenContextIsAllowlisted() {
        let report = BetaFeedbackReport(
            category: .bug,
            message: "The button did not respond.",
            diagnostics: diagnostics,
            flowScreen: .settingsBetaFeedback
        )

        #expect(BetaFeedbackFlowScreen.allCases == [.settingsBetaFeedback])
        #expect(report.flowScreen.rawValue == "settings/beta-feedback")
        #expect(report.flowScreen.redactedSummary == "Flow: Settings\nScreen: Beta feedback")
        #expect(!report.flowScreen.redactedSummary.lowercased().contains("transcript"))
        #expect(!report.flowScreen.redactedSummary.lowercased().contains("account"))
    }

    @Test("Redaction boundary is explicit and content-free")
    func redactionBoundaryIsExplicit() {
        let summary = diagnostics.redactedSummary.lowercased()
        let notice = BetaFeedbackDiagnostics.excludedDataNotice.lowercased()

        #expect(!summary.contains("account id:"))
        #expect(!summary.contains("transcript:"))
        #expect(!summary.contains("recording:"))
        #expect(notice.contains("account id"))
        #expect(notice.contains("transcripts"))
        #expect(notice.contains("recordings"))
        #expect(notice.contains("prompts"))
        #expect(notice.contains("coaching content"))
        #expect(notice.contains("authentication data"))
        #expect(BetaFeedbackDiagnostics.crashLogNotice.hasPrefix("No crash logs are attached"))
    }

    @Test("Email routes through monitored support inbox")
    func emailUsesSupportInbox() throws {
        let report = BetaFeedbackReport(
            category: .confusing,
            message: "I could not tell what to do next.",
            diagnostics: diagnostics
        )
        let components = try #require(
            URLComponents(url: report.emailURL, resolvingAgainstBaseURL: false)
        )
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })

        #expect(components.scheme == "mailto")
        #expect(components.path == NoumWebURLs.supportEmail)
        #expect(query["subject"] == "Noum private beta feedback — Confusing experience")
        #expect(query["body"] == report.shareText)
    }

    @Test("Blank feedback cannot be sent")
    func blankFeedbackCannotBeSent() {
        let report = BetaFeedbackReport(
            category: .idea,
            message: " \n ",
            diagnostics: diagnostics
        )

        #expect(!report.canSend)
        #expect(report.message.isEmpty)
    }

    @Test("Feedback is bounded before mail URL construction")
    func feedbackIsBounded() {
        let report = BetaFeedbackReport(
            category: .bug,
            message: String(repeating: "a", count: BetaFeedbackReport.maximumMessageLength + 50),
            diagnostics: diagnostics
        )

        #expect(report.message.count == BetaFeedbackReport.maximumMessageLength)
    }

    @Test("Settings exposes the visible beta route")
    func settingsExposesVisibleRoute() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testsDirectory.deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/SettingsView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("BetaFeedbackView()"))
        #expect(source.contains("Send beta feedback"))
        #expect(source.contains("settings.betaFeedback"))
    }

    @Test("Diagnostics contain children without replacing the redaction notice identity")
    func diagnosticsPreserveRedactionNoticeAccessibilityIdentity() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testsDirectory.deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/BetaFeedbackView.swift"),
            encoding: .utf8
        )
        let cardStart = try #require(source.range(of: "private var diagnosticsCard: some View"))
        let actionsStart = try #require(
            source.range(
                of: "private var actions: some View",
                range: cardStart.upperBound..<source.endIndex
            )
        )
        let card = String(source[cardStart.lowerBound..<actionsStart.lowerBound])
        let containment = try #require(
            card.range(of: ".accessibilityElement(children: .contain)")
        )
        let rootIdentifier = try #require(
            card.range(of: ".accessibilityIdentifier(\"betaFeedback.diagnostics\")")
        )

        #expect(card.contains(".accessibilityIdentifier(\"betaFeedback.redactionNotice\")"))
        #expect(containment.lowerBound < rootIdentifier.lowerBound)
        #expect(!card.contains(".accessibilityElement(children: .combine)"))
    }
}
