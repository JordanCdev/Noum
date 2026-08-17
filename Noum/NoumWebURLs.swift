import Foundation

// MARK: - Hosted URLs (M14 prep)
//
// Single source of truth for Noum's externally-hosted URLs. These are
// served by Firebase Hosting from the `public/` directory at the repo
// root. The hosting target is configured in `firebase.json`; deploy only via
// the checked-in source-bound `scripts/deploy-hosting.mjs` wrapper.
//
// `hostingOrigin` is deliberately the verified Firebase origin while the
// custom domain is parked. App Store metadata is source-checked against this
// value. Switch this one origin only after both origins pass the four-page
// exact-body gate and the custom domain has direct TLS (no cross-origin hop).

enum NoumWebURLs {
    /// Active public origin. The release validator permits only Noum's
    /// Firebase Hosting origin or, after verified cutover, `https://noum.app`.
    static let hostingOrigin = URL(string: "https://noum-d0b6f.web.app")!

    /// Monitored support inbox used for privacy and account-deletion help
    /// until the custom-domain mailbox is ready.
    static let supportEmail = "noumsupport@gmail.com"
    static let supportMail = URL(string: "mailto:\(supportEmail)")!

    /// User-initiated private-beta report. The caller owns the visible report
    /// body; this helper only routes it to the existing monitored inbox.
    /// Diagnostics must remain inspectable and content-free before arriving
    /// here (see `BetaFeedbackDiagnostics`).
    static func betaFeedbackMail(subject: String, body: String) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(
                name: "subject",
                value: subject.replacingOccurrences(of: "\n", with: " ")
            ),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url ?? supportMail
    }

    /// Ask Noum unavailable-after-retries support draft. Privacy-safe
    /// diagnostics only — the typed unavailability reason code, the failed
    /// re-check count, and app/OS versions, so support can distinguish a
    /// deploy gap from a transient service blip. Never account identifiers,
    /// transcripts, or coaching content (same boundary as
    /// `deletionSupportMail`).
    static func askNoumUnavailableSupportMail(
        reasonCode: String,
        failedRecheckCount: Int,
        appVersion: String,
        systemVersion: String
    ) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(
                name: "subject",
                value: "Noum unavailable after retries"
            ),
            URLQueryItem(
                name: "body",
                value: """
                Ask Noum shows as unavailable after retries.

                Reason code: \(reasonCode)
                Failed re-checks: \(failedRecheckCount)
                App version: \(appVersion)
                System: \(systemVersion)

                Please do not include practice transcripts or other coaching content.
                """
            )
        ]
        return components.url ?? supportMail
    }

    /// Account-deletion support needs the same opaque request reference that
    /// appears in server logs. The local phase helps triage without exposing
    /// an account identifier or coaching content in the email draft.
    static func deletionSupportMail(
        requestReference: String?,
        phase: String?
    ) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        let referenceLine = requestReference.map {
            "Deletion reference: \($0)"
        } ?? "Deletion reference: unavailable"
        let phaseLine = phase.map {
            "Local deletion phase: \($0)"
        } ?? "Local deletion phase: unavailable"
        components.queryItems = [
            URLQueryItem(
                name: "subject",
                value: "Noum account deletion support"
            ),
            URLQueryItem(
                name: "body",
                value: """
                I need help verifying an account deletion.

                \(referenceLine)
                \(phaseLine)

                Please do not include practice transcripts or other coaching content.
                """
            )
        ]
        return components.url ?? supportMail
    }

    /// Public landing page at the currently verified hosting origin.
    static let landing = hostingOrigin

    /// Public privacy policy. Backed by `public/privacy.html` via the
    /// `firebase.json` rewrite `/privacy → /privacy.html`.
    static let privacy = hostingOrigin.appendingPathComponent("privacy")

    /// Public explanation of Noum's evidence boundaries. Keep this on the
    /// verified Firebase origin until the custom-domain DNS/TLS/body gate is
    /// complete; App Store metadata may move to `noum.app` only after that.
    static let coachingMethod = hostingOrigin.appendingPathComponent("how-noum-coaches")

    /// Browser-based support destination for App Store Connect and users who
    /// cannot open an email composer. The page links to the monitored inbox.
    static let support = hostingOrigin.appendingPathComponent("support")

    /// Apple's account-level subscription management surface. Account
    /// deletion never claims to cancel a StoreKit subscription automatically.
    static let manageSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!
}
