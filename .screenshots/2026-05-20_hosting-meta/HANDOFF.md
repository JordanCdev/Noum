# Run: 2026-05-20 · branch:cloud/hosting-meta-2026-05-20 · M14 ship polish — public hosting meta tags

The `public/privacy.html` page is one of the four hard gates on M14's "Definition of done" (`docs/VISION.md`): the App Store submission needs a hosted privacy-policy URL. The page itself was already production-quality. This run adds the meta-layer that makes the URL behave correctly when the App Store reviewer (or anyone else) shares it:

- **OpenGraph + Twitter Card meta** — the privacy URL now renders a proper preview card when shared on Slack, iMessage, Twitter, App Store Connect.
- **`theme-color` + `canonical`** — Safari address-bar tint matches Noum brand; canonical URL declared for both pages.
- **`robots: index,follow`** on the privacy page so it's findable.

No content changes. No layout changes. No new pages.

## Mode
Linux blind — no simulator, no Xcode. Hosting verification is a `firebase emulators:start` / browser visit job that requires Node.js + Firebase CLI; this run only writes the HTML.

## What shipped

| File | Change |
|---|---|
| `public/index.html` | Added OG (`og:type`, `og:title`, `og:description`, `og:url`, `og:site_name`), Twitter Card (`twitter:card`, `twitter:title`, `twitter:description`), `theme-color`, `canonical`. +10 lines. No layout / styling / copy changes. |
| `public/privacy.html` | Same set of meta tags as `index.html`, scoped to the privacy URL, plus `robots: index,follow`. +11 lines. No legal copy changes. |

## Why this matters for M14

The App Store submission flow asks for a privacy-policy URL. When the reviewer pastes that URL into Slack / iMessage / a CRM ticket, the link will now render a branded preview card with the page title + description instead of a bare URL. Same applies for anyone who shares the link with a beta tester. Small detail; reads as "this app cares about how it shows up."

It also closes the standard SEO defaults — `theme-color` for mobile browsers, `canonical` to prevent duplicate-content ambiguity (`/privacy` vs `/privacy.html`), `robots: index,follow` so search engines can confirm the policy URL is real (Apple cross-checks against the public web).

## Verification

Once deployed (`firebase deploy --only hosting`):

```bash
curl -s https://noum-d0b6f.web.app/privacy | grep -E '(og:|twitter:|theme-color|canonical|robots)'
```

Should return all 8 meta lines plus the canonical `<link>`.

In a browser, a Slack/iMessage paste of `https://noum-d0b6f.web.app/privacy` should now show:
- Title: "Noum — Privacy Policy"
- Description: "How Noum collects, uses, and protects your data."

…instead of just the URL.

## Surfaces needing visual verification

None on the iOS app side — this PR doesn't touch Swift. Hosting visual verification is a Mac + browser job that's downstream.

## Risks

- **URL hardcoded as `noum-d0b6f.web.app`** — matches the value in `docs/TESTFLIGHT_QA.md`. If the production hosting moves to a custom domain (e.g. `noum.app`), all four `og:url` / `canonical` lines need a sweep. Cheap to update.
- **No image specified for `og:image`** — preview cards will use the default Twitter/Slack favicon fallback. Adding an `og:image` requires a real PNG asset in `public/` (a 1200×630 brand card). Not in scope for this batch; flagged for a follow-up.
- **Firebase Hosting rewrites unchanged** — `/privacy → /privacy.html` rewrite already present in `firebase.json`. The canonical URL uses `/privacy` to match the user-facing route.

## VISION gap closing (estimate)

M14 "Definition of done" item 2 — "Public privacy-policy URL hosted... and wired into Settings → Privacy & Data" — is now slightly more ship-ready. The hosting itself was already deployable; this PR makes it look right when shared. The actual `firebase deploy --only hosting` invocation still needs a Mac + Firebase CLI session and is the remaining work on this gate.

Operational M14 work (Firestore rules deploy, hosting deploy, TestFlight build, real-device QA) is still pending and requires Mac / cloud creds — none possible from Linux blind.

## Branch + commit SHA

Branch: `cloud/hosting-meta-2026-05-20`
Commit SHA: will be set on push.

## Follow-up suggestions

- **`og:image`** — a 1200×630 PNG showing the Noum brand mark + tagline, added to `public/` and referenced from both pages. Pure design work, separate PR.
- **`public/terms.html`** — if the App Store reviewer asks for a Terms of Use page (sometimes requested for subscription apps), this is the natural follow-up. Pattern from `privacy.html` carries over directly.
