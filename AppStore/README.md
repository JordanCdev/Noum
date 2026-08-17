# Noum App Store release package

This directory is the source-controlled brief for App Store Connect. It does
not claim that Apple-side configuration, pricing, trials, screenshots, review,
or release submission has been completed.

## Positioning

- Name: **Noum: Communication Coach**
- Subtitle: **Evidence-led speaking coach**
- Primary audience: professionals preparing for high-stakes meetings,
  interviews, and presentations.
- Promise: Noum uses saved practice evidence, names uncertainty, and prescribes
  one next rep. It does not claim to read motives or replace a human coach.

## Subscription configuration

The identifiers in `Noum/PremiumManager.swift` remain authoritative:

| Product | App Store Connect price | Introductory offer |
|---|---:|---|
| `com.noum.pro.monthly` | GBP 11.99 monthly | None |
| `com.noum.pro.annual` | GBP 79.99 yearly | 7 days free, then annual renewal |

App Store Connect must localize prices for every enabled territory. The app
must render only StoreKit-returned price and offer data; these numbers are an
operator brief, never a runtime fallback.

The 15% commission used by the operating model is conditional, not a product
constant. The release operator must retain Apple Small Business Program
acceptance when eligible, or calculate contribution margin with the account's
actual commission tier.

## Product-page work

- Default page: evidence-led communication coaching.
- Custom pages: Interview, Leadership meetings, Presentations.
- Product-page optimization: three variants from `product-pages.json`.
- Screenshots: follow `screenshot-brief.md`; no synthetic metrics or invented
  testimonials.
- Preview: 20–30 seconds, showing one rep → evidence → prescribed next action.
- Release binding: copy `release-assets.template.json` outside the repository,
  fill it only from the signed TestFlight candidate, and preserve every media
  SHA-256, source commit, version/build, fixture ID, page mapping, and App Store
  Connect/public product-page link.
- Experiment decision: copy `aso-experiment.template.json` outside the
  repository before starting PPO. Use App Store Connect's traffic estimate to
  pre-register a positive per-arm/storefront denominator (the source template
  deliberately leaves it unset), then preserve the single tested app version,
  observation window, result export, decision, and independent verification.
  An inconclusive result remains inconclusive.
- Launch/scale decisions: use `launch-gates.md`; every result needs its cohort,
  denominator, version, storefront, and source.
- Commercial reconciliation: use `commercial-reconciliation.md` and the
  checked-in incomplete template. The utility compares identifier-free
  calendar-event totals only, preserves the UTC-versus-Pacific boundary warning,
  and refuses cross-currency arithmetic without a hashed conversion receipt.

## External release gates

Before submission, the release operator must complete and independently verify:

1. StoreKit products, subscription group, trial eligibility, grace period,
   billing retry, restore, cancellation, refund, and expiry behavior.
2. Exact support/privacy/marketing bodies at the active Firebase origin; then
   direct `noum.app` TLS/DNS before the custom-domain switch.
3. Signed archive, processed TestFlight build, physical purchase/restore flow,
   accessibility matrix, microphone/interruption behavior, and source binding.
4. Live-provider evaluation, professional calibration, longitudinal beta, and
   operational sign-off from `docs/MANUAL_LAUNCH_ACTIONS.md`.

Nothing in this directory substitutes for those external proofs.

Validate the source-controlled brief before preparing a release:

```sh
python3 scripts/validate-app-store-package.py
```

The default command validates the two deliberately empty contracts; it does
not validate release media or an experiment result. From a completely clean
checkout bound to the captured source commit, validate the separately filled
release manifest (and its real files) with:

```sh
python3 scripts/validate-app-store-package.py \
  --verify-release-assets /secure/noum-app-store/release-assets.json
```

The strict mode verifies all 13 mapped screenshot files, exact 6.9-inch image
dimensions, absence of alpha, SHA-256 values, the 20–30 second preview's
resolution/codec/frame rate, signed-candidate evidence, TestFlight capture
channel, custom-page links, PPO treatment links, and clean Git binding. It
requires `ffprobe`; the checked-in empty template cannot pass it.

After App Store Connect reports a completed PPO experiment, validate its
separately retained result with:

```sh
python3 scripts/validate-app-store-package.py \
  --verify-aso-experiment-results /secure/noum-app-store/aso-experiment.json
```

This checks the pre-registered GB/US result matrix, exact version and source
commit, 7–90 day window, per-arm denominators, Apple's conversion/lift/status
and confidence output, App Store Connect export, decision record, and distinct
decision-maker/verifier. A treatment can be adopted only when Apple reports it
performing better with at least 90% confidence. It does not upload
anything to App Store Connect or manufacture a winning treatment. Apple only
runs PPO tests for a Ready-for-Distribution live app, so this is a post-launch
paid-acquisition/scale gate rather than a first-release prerequisite. See
Apple's [PPO analytics definitions](https://developer.apple.com/help/app-store-connect-analytics/acquisition/product-page-optimization/).

Before App Store submission, verify the active in-app/App Store origin:

```sh
python3 scripts/validate-app-store-package.py --verify-live-urls
```

This reads at most 256 KiB per page and requires exact bytes for the homepage,
privacy, support, and coaching-method pages. App and metadata remain on the
Firebase origin while `noum.app` is parked. Once Firebase reports the custom
domain connected with valid TLS, prove both direct origins before changing the
single `NoumWebURLs.hostingOrigin` value and metadata:

```sh
python3 scripts/validate-app-store-package.py \
  --verify-custom-domain-cutover
```

Cross-origin redirects, marker-only matches, stale bytes, and oversized bodies
all fail. After the source switch, the normal live gate verifies `noum.app` as
the active origin; retain the dual-origin run as rollback proof.

After the first consented production aggregate and real App Store Connect
Subscription Event Report are available, create the separately retained
content-free discrepancy note with:

```sh
python3 scripts/reconcile_app_store_commercial.py \
  --manifest /secure/noum-commercial/reconciliation.json \
  --output /secure/noum-commercial/reconciliation-result.json
```

This is an operational evidence command, not part of repository validation;
the checked-in template deliberately contains no real reports.

Apple's current source specifications are the authority if accepted dimensions
or codecs change: [screenshots](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
and [app previews](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/).
