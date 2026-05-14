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
    /// Firebase Hosting default subdomain. The custom apex
    /// (e.g., `noum.app`) redirects here once DNS is wired.
    static let landing = URL(string: "https://noum-d0b6f.web.app")!

    /// Public privacy policy. Stable URL — App Store Connect, app
    /// reviewer notes, and any "noum.app/privacy" links should all
    /// resolve to this. Backed by `public/privacy.html` via the
    /// `firebase.json` rewrite `/privacy → /privacy.html`.
    static let privacy = URL(string: "https://noum-d0b6f.web.app/privacy")!
}
