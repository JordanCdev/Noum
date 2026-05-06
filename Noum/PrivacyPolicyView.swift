import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Privacy Policy View
//
// Renders the bundled `PrivacyPolicy.md` (Noum/PrivacyPolicy.md) so the
// user can read it without leaving the app. Required for App Store
// submission. The Markdown is parsed with `AttributedString` so headings,
// lists, bold, and links render natively.
//
// If the bundle resource is missing for any reason (build misconfiguration),
// the view falls back to a single-line message rather than an empty view —
// "missing" is more useful than silent for a legal surface.

@available(iOS 17.0, macOS 12.0, *)
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var policy: AttributedString = AttributedString("Loading…")
    @State private var loadFailed: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if loadFailed {
                        Text("The privacy policy isn't available right now. Please try again, or visit our website.")
                            .font(Typography.body)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(policy)
                            .font(Typography.body)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.screenH)
                .padding(.vertical, Spacing.lg)
            }
            .background(AppColor.screenBackground.ignoresSafeArea())
            .navigationTitle("Privacy policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColor.brandBlue)
                }
            }
            .task { await loadPolicy() }
            .accessibilityIdentifier("privacyPolicy.screen")
        }
    }

    private func loadPolicy() async {
        guard let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "md"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            await MainActor.run { loadFailed = true }
            return
        }
        // `AttributedString.init(markdown:options:)` handles headings, lists,
        // emphasis, and links. `.full` parsing keeps line breaks meaningful so
        // the policy reads as authored rather than collapsed onto one paragraph.
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full
        )
        let parsed = (try? AttributedString(markdown: raw, options: options)) ?? AttributedString(raw)
        await MainActor.run { self.policy = parsed }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Privacy policy") {
    PrivacyPolicyView()
}
#endif

#endif
