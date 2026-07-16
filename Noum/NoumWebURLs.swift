import Foundation

// MARK: - Hosted URLs (M14 prep)
//
// Single source of truth for Noum's externally-hosted URLs. These are
// served by Firebase Hosting from the `public/` directory at the repo
// root. The hosting target is configured in `firebase.json`; deploy via
// `firebase deploy --only hosting`.
//
// The privacy URL is the one the App Store privacy field expects — keep
// it stable across releases. The marketing URL is the landing page
// hit when the user taps "noum.app" anywhere in the app.

enum NoumWebURLs {
    /// Monitored support inbox used for privacy and account-deletion help
    /// until the custom-domain mailbox is ready.
    static let supportEmail = "noumsupport@gmail.com"
    static let supportMail = URL(string: "mailto:\(supportEmail)")!

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

    /// Firebase Hosting default subdomain. The custom apex
    /// (e.g., `noum.app`) redirects here once DNS is wired.
    static let landing = URL(string: "https://noum-d0b6f.web.app")!

    /// Public privacy policy. Stable URL — App Store Connect, app
    /// reviewer notes, and any "noum.app/privacy" links should all
    /// resolve to this. Backed by `public/privacy.html` via the
    /// `firebase.json` rewrite `/privacy → /privacy.html`.
    static let privacy = URL(string: "https://noum-d0b6f.web.app/privacy")!

    /// Apple's account-level subscription management surface. Account
    /// deletion never claims to cancel a StoreKit subscription automatically.
    static let manageSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!
}
