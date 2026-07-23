# Commercial aggregate reconciliation contract

This workflow produces a repeatable, content-free comparison between Noum's
optional first-party daily aggregate and App Store Connect subscription
reports. It does **not** turn the first-party aggregate into a source of truth.
App Store Connect remains authoritative for subscription outcomes, proceeds,
refunds, conversion, and peer benchmarks.

The checked-in template is intentionally incomplete and cannot pass evidence
mode. Copy it to the protected release-evidence directory; do not put real
reports in the repository.

```sh
cp AppStore/commercial-reconciliation.template.json \
  /secure/noum-commercial/reconciliation.json
```

## Why the input is normalized

Apple's Subscription Event Report 1_3 contains app, subscription, and group
identifiers that do not belong in a durable discrepancy note. Its dates are
Pacific Time. Noum's anonymous batches contain no user identifier and close on
UTC-day boundaries. The CLI therefore accepts two small normalized sources,
binds each source by SHA-256, and writes neither source paths nor Apple/account/
product identifiers to the result. The normalized first-party JSON is version
2 because its lifecycle and AI-cost projections have different authorities and
must remain structurally separate.

Do not use a Subscriber Report as input: it contains Subscriber IDs. Do not add
an identifier column to either normalized file; the parser requires the exact
headers below and refuses extras.

Apple documents the current [Subscription Event Report 1_3 fields](https://developer.apple.com/help/app-store-connect/reference/reporting/subscription-event-report/),
the [subscription event definitions](https://developer.apple.com/help/app-store-connect/reference/reporting/subscription-events),
and the Pacific-Time boundary used by [downloadable Sales and Trends reports](https://developer.apple.com/help/app-store-connect/measure-app-performance/download-and-view-reports/).
Re-check those sources before preparing each release because report contracts
can change.

## Boundary contract

The filled manifest must declare:

- a 7–35 day range, with an exclusive end date and one explicit row per day;
- an `asOfDate` on or after the exclusive end, so no open day is included;
- `calendar-event`, never an install, activation, trial-start, or subscriber
  cohort;
- Noum `UTC` days and App Store Connect `America/Los_Angeles` date labels;
- every storefront, every Noum subscription, and every app version/build.
  Apple's Subscription Event Report has no app-version dimension, so filtering
  only the first-party side to a candidate build would create a false mismatch.

The two date labels are intentionally **not** claimed to be identical timestamp
windows. The result always retains that warning. Use discrepancies to inspect
coverage, background delivery, delayed StoreKit observation, or report timing;
do not "correct" Apple's authority totals with client observations.

## First-party normalized JSON

Create `first-party-growth.json` from the reviewed
`_growthAggregatePeriods` export. The v2 contract deliberately contains two
source-bound projections:

1. **Lifecycle:** select only documents whose `source` is exactly
   `appStoreServerNotificationsV2`, whose `environment` is exactly
   `production`, and whose server-owned document schema is the Notifications V2
   lifecycle projection. Sum only their five allowlisted lifecycle counters.
   Exclude sandbox documents and every client app-version/build document.
2. **AI cost:** select only schema-v2 app-version/build period documents written
   by the explicit-consent client aggregate path. Sum all app versions/builds
   for each UTC day, but retain only `estimatedAICostMicros`,
   `estimatedAICostCurrency`, and `unpricedAIUsageCount`. Exclude every document
   carrying the App Store notification `source`, and never copy subscription
   lifecycle counters from client documents.

Do not sum all documents in the collection. Doing so can count the same
subscription transition once from the client and again from Apple. The
normalization review note must record both selectors above. Include a row with
explicit zeros in **each** projection when no matching event or usage was
observed; absence is not proof of zero.

```json
{
  "schemaVersion": 2,
  "lifecycle": {
    "source": "appStoreServerNotificationsV2",
    "environment": "production",
    "days": [
      {
        "dateUTC": "2026-07-01",
        "eventCounts": {
          "growth.subscription.trialStarted": 4,
          "growth.subscription.entitlementRenewed": 2,
          "growth.subscription.billingFailed": 1,
          "growth.subscription.purchaseRefunded": 0,
          "growth.subscription.entitlementExpired": 1
        }
      }
    ]
  },
  "aiCost": {
    "source": "consented-client-growth-aggregates-v2",
    "days": [
      {
        "dateUTC": "2026-07-01",
        "estimatedAICostMicros": 38120,
        "estimatedAICostCurrency": "USD",
        "unpricedAIUsageCount": 0
      }
    ]
  }
}
```

The parser refuses the combined v1 shape, a sandbox lifecycle projection, a
non-Notifications-V2 lifecycle source, or an AI-cost source other than the
consented client aggregate. These labels are part of the hashed normalization
contract; they are not optional documentation.

No batch ID, document ID, event UUID, account/device/installation ID, timestamp,
prompt, transcript, quote, plan text, product identifier, or arbitrary metadata
is accepted.

`unpricedAIUsageCount` is the bounded count of off-device provider attempts for
which Noum could not establish priced token or audio units. It must remain zero
before the CLI will calculate a residual or contribution margin. Known priced
cost is still retained when the count is non-zero, but commercial readiness is
`BLOCKED_UNPRICED_AI_USAGE`; missing price evidence is never treated as free.
Deliberate on-device work emits no paid or unpriced provider-usage event and
therefore does not inflate this count.

## App Store Connect lifecycle CSV

Download the **daily Subscription Event Report 1_3** for every date in scope,
filter to Noum and all Noum subscription plans, and aggregate `Quantity` into
the fixed lifecycle families below. After a second operator checks the mapping,
write one identifier-free row per Pacific date:

```csv
event_date_pt,trial_started,renewal,billing_failure,refund,expiry
2026-07-01,4,2,1,0,1
```

Mapping rules:

| Safe family | App Store Connect source | Noum observation |
|---|---|---|
| `trial_started` | `Start Introductory Offer` where the offer type is `Free Trial` | `growth.subscription.trialStarted` |
| `renewal` | renewal-family events that extend paid service; preserve the reviewed event list beside the raw export | `growth.subscription.entitlementRenewed` |
| `billing_failure` | events entering Billing Retry or Billing Grace Period due to a billing issue | `growth.subscription.billingFailed` |
| `refund` | refund-family events | `growth.subscription.purchaseRefunded` |
| `expiry` | terminal cancellation/expiry-family events where access ended | `growth.subscription.entitlementExpired` |

Apple event families evolve. Preserve the exact raw event-to-family mapping in
the protected evidence packet and have a different operator verify it. The CLI
cannot infer that mapping from renamed or new Apple events and intentionally
does not accept an arbitrary mapping override.

## Optional proceeds and currency evidence

To add an income observation, normalize an App Store Connect proceeds export to
this exact CSV. `developer_proceeds_micros` is a signed integer in the declared
single ISO-4217 currency (a negative daily total is accepted when
refunds exceed proceeds). Declare `sales-and-trends-estimated-proceeds` in the
manifest. Apple's final financial reports use fiscal-month boundaries, so they
must be reconciled separately on their exact fiscal period; relabeling a monthly
financial report as daily evidence is refused.

```csv
event_date_pt,developer_proceeds_micros,currency
2026-07-01,14250000,USD
```

If proceeds and Noum's estimated AI costs use different currencies, the CLI
refuses arithmetic unless a separately hashed `currency-conversion-v1` JSON is
provided:

```json
{
  "schemaVersion": 1,
  "fromCurrency": "USD",
  "toCurrency": "GBP",
  "rateNumerator": 79,
  "rateDenominator": 100,
  "effectiveDate": "2026-07-04",
  "sourceEvidenceSha256": "<sha256-of-the-retained-rate-receipt>"
}
```

The result rounds half-up to one micro-unit. Its residual subtracts only the AI
cost present in the aggregate; it is not a complete contribution-margin claim
unless every other variable cost is added in the separate finance model.
Any non-zero unpriced usage count makes both residual fields `null` and blocks
the commercial-readiness result, even when proceeds and a currency conversion
receipt are otherwise complete.

## Run and retain

Hash each normalized source, set `templateStatus` to
`COLLECTED_REAL_EXPORTS`, fill the source-bound app version/commit and all
relative paths, and bind both each normalized file and its original raw export
with SHA-256. Then run:

```sh
python3 scripts/reconcile_app_store_commercial.py \
  --manifest /secure/noum-commercial/reconciliation.json \
  --output /secure/noum-commercial/reconciliation-result.json
```

Retain together:

1. original App Store Connect export and its SHA-256;
2. reviewed normalization/mapping note;
3. first-party aggregate export and normalization note;
4. filled manifest and normalized inputs;
5. content-free result and command output;
6. independent verifier sign-off.

A zero delta is only `COUNTS_MATCH_WITH_TIMEZONE_CAUTION`; a non-zero delta is
`DISCREPANCY_REVIEW_REQUIRED`. Neither status authorizes subscriber linkage,
download-to-trial or trial-to-paid division, retention math, peer-benchmark
replacement, or paid acquisition.
