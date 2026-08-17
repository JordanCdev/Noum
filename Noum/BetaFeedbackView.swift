import Foundation

enum BetaFeedbackCategory: String, CaseIterable, Identifiable, Hashable {
    case bug = "Something broke"
    case confusing = "Something was confusing"
    case coaching = "Coaching felt wrong"
    case idea = "I have an idea"

    var id: String { rawValue }

    var subjectLabel: String {
        switch self {
        case .bug: return "Bug"
        case .confusing: return "Confusing experience"
        case .coaching: return "Coaching quality"
        case .idea: return "Idea"
        }
    }
}

/// Content-free, compile-time allowlist for where a beta report was opened.
/// This deliberately cannot accept arbitrary route titles, prompts, transcript
/// fragments, or user-entered metadata.
enum BetaFeedbackFlowScreen: String, CaseIterable, Equatable {
    case settingsBetaFeedback = "settings/beta-feedback"

    var flowLabel: String {
        switch self {
        case .settingsBetaFeedback: return "Settings"
        }
    }

    var screenLabel: String {
        switch self {
        case .settingsBetaFeedback: return "Beta feedback"
        }
    }

    var redactedSummary: String {
        "Flow: \(flowLabel)\nScreen: \(screenLabel)"
    }
}

/// Content-free build context that a beta tester can inspect before sharing.
/// Do not add account, coaching, session, or speech data here: the value of
/// this report is source correlation, not a hidden telemetry export.
struct BetaFeedbackDiagnostics: Equatable {
    let appVersion: String
    let buildNumber: String
    let sourceCommit: String
    let systemVersion: String

    static let excludedDataNotice =
        "Diagnostics never include: name, email, account ID, transcripts, recordings, prompts, coaching content, or authentication data."
    static let crashLogNotice =
        "No crash logs are attached to this report."

    static func current(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> BetaFeedbackDiagnostics {
        let info = bundle.infoDictionary
        return BetaFeedbackDiagnostics(
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: info?["CFBundleVersion"] as? String ?? "unknown",
            sourceCommit: info?["NoumSourceGitCommit"] as? String ?? "unbound",
            systemVersion: processInfo.operatingSystemVersionString
        )
    }

    var appVersionSummary: String {
        "\(appVersion) (\(buildNumber))"
    }

    var redactedSummary: String {
        """
        App version: \(appVersion)
        Build: \(buildNumber)
        Source commit: \(sourceCommit)
        System: \(systemVersion)
        \(Self.crashLogNotice)
        """
    }
}

struct BetaFeedbackReport: Equatable {
    static let maximumMessageLength = 1_200

    let category: BetaFeedbackCategory
    let message: String
    let diagnostics: BetaFeedbackDiagnostics
    let flowScreen: BetaFeedbackFlowScreen

    init(
        category: BetaFeedbackCategory,
        message: String,
        diagnostics: BetaFeedbackDiagnostics,
        flowScreen: BetaFeedbackFlowScreen = .settingsBetaFeedback
    ) {
        self.category = category
        self.message = String(message.prefix(Self.maximumMessageLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.diagnostics = diagnostics
        self.flowScreen = flowScreen
    }

    var canSend: Bool { !message.isEmpty }

    var subject: String {
        "Noum private beta feedback — \(category.subjectLabel)"
    }

    var shareText: String {
        """
        Noum private beta feedback

        Type: \(category.rawValue)
        \(flowScreen.redactedSummary)

        Feedback:
        \(message)

        Redacted diagnostic summary:
        \(diagnostics.redactedSummary)

        \(BetaFeedbackDiagnostics.excludedDataNotice)
        """
    }

    var emailURL: URL {
        NoumWebURLs.betaFeedbackMail(subject: subject, body: shareText)
    }
}

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, *)
struct BetaFeedbackView: View {
    @Environment(\.openURL) private var openURL
    @State private var category: BetaFeedbackCategory = .bug
    @State private var feedback = ""

    private let diagnostics: BetaFeedbackDiagnostics
    private let flowScreen: BetaFeedbackFlowScreen

    init(
        diagnostics: BetaFeedbackDiagnostics = .current(),
        flowScreen: BetaFeedbackFlowScreen = .settingsBetaFeedback
    ) {
        self.diagnostics = diagnostics
        self.flowScreen = flowScreen
    }

    private var report: BetaFeedbackReport {
        BetaFeedbackReport(
            category: category,
            message: feedback,
            diagnostics: diagnostics,
            flowScreen: flowScreen
        )
    }

    var body: some View {
        ReadingScreenScaffold(
            title: "Beta feedback",
            subtitle: "Tell us what blocked you while it is still fresh."
        ) {
            feedbackCard
            diagnosticsCard
            actions
        }
        .navigationTitle("Beta feedback")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("betaFeedback.screen")
    }

    private var feedbackCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("What happened?")
                        .font(Typography.cardTitle)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Avoid names and transcript quotes.")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Picker("Feedback type", selection: $category) {
                    ForEach(BetaFeedbackCategory.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("betaFeedback.category")

                ZStack(alignment: .topLeading) {
                    if feedback.isEmpty {
                        Text("Describe what you expected and what happened.")
                            .font(Typography.body)
                            .foregroundStyle(AppColor.textTertiary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: limitedFeedback)
                        .font(Typography.body)
                        .foregroundStyle(AppColor.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(Spacing.sm)
                        .frame(minHeight: 150)
                        .accessibilityLabel("Beta feedback details")
                        .accessibilityIdentifier("betaFeedback.details")
                }
                .background(
                    AppColor.innerSurface,
                    in: RoundedRectangle(
                        cornerRadius: CornerRadius.medium,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: CornerRadius.medium,
                        style: .continuous
                    )
                    .stroke(AppColor.subtleBorder, lineWidth: 1)
                }

                Text("\(feedback.count)/\(BetaFeedbackReport.maximumMessageLength)")
                    .font(Typography.caption.monospacedDigit())
                    .foregroundStyle(AppColor.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("\(feedback.count) of \(BetaFeedbackReport.maximumMessageLength) characters")
            }
        }
    }

    private var diagnosticsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Redacted diagnostics", systemImage: "checkmark.shield.fill")
                    .font(Typography.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)

                Text("You can inspect everything attached to your report.")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)

                Divider()

                diagnosticRow("Version", value: diagnostics.appVersionSummary)
                diagnosticRow("Source commit", value: diagnostics.sourceCommit)
                diagnosticRow("System", value: diagnostics.systemVersion)
                diagnosticRow("Flow / screen", value: "\(flowScreen.flowLabel) / \(flowScreen.screenLabel)")
                diagnosticRow("Crash logs", value: BetaFeedbackDiagnostics.crashLogNotice)

                Divider()

                Text(BetaFeedbackDiagnostics.excludedDataNotice)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("betaFeedback.redactionNotice")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("betaFeedback.diagnostics")
    }

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryCTA("Email feedback", icon: "envelope.fill") {
                openURL(report.emailURL) { accepted in
                    if !accepted {
                        openURL(NoumWebURLs.support)
                    }
                }
            }
            .disabled(!report.canSend)
            .accessibilityHint(
                report.canSend
                    ? "Opens a pre-filled email to Noum support."
                    : "Enter feedback before sending."
            )
            .accessibilityIdentifier("betaFeedback.email")

            ShareLink(
                item: report.shareText,
                subject: Text(report.subject),
                message: Text("Noum private beta feedback")
            ) {
                Label("Share a copy", systemImage: "square.and.arrow.up")
                    .font(Typography.cardLabel)
                    .foregroundStyle(report.canSend ? AppColor.brandBlue : AppColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.pressable)
            .disabled(!report.canSend)
            .accessibilityHint("Shares the same redacted report through another app.")
            .accessibilityIdentifier("betaFeedback.share")

            Text("Feedback is sent only when you choose Email or Share.")
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var limitedFeedback: Binding<String> {
        Binding(
            get: { feedback },
            set: { feedback = String($0.prefix(BetaFeedbackReport.maximumMessageLength)) }
        )
    }

    private func diagnosticRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(Typography.caption.monospaced())
                .foregroundStyle(AppColor.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
