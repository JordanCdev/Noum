# App Store launch and growth gates

These are operating thresholds, not claims about current performance. Record
the source, cohort dates, denominator, storefront, app version, and observation
window whenever a gate is evaluated. Never combine synthetic fixtures with
real-user cohorts.

## Day 0

| Gate | Initial target | Source |
|---|---:|---|
| Permissionless first value completed | ≥70% | Bounded local growth aggregate |
| First spoken rep begun | ≥50% | Bounded local growth aggregate |
| Completed rep reaches summary | ≥85% | Bounded local growth aggregate |
| Median time to first useful value | <60 seconds | Bounded local growth aggregate |

## First seven days

| Gate | Initial floor | Growth target |
|---|---:|---:|
| Day-1 retention | ≥27% | App Store Connect category/business-model 75th percentile |
| Day-7 retention | ≥14% | App Store Connect category/business-model 75th percentile |
| Activated users completing rep 2 within 48 hours | ≥30% | Improve after cohort confidence |
| Day-1 returners viewing first-week read | ≥35% | Improve after cohort confidence |

Do not scale acquisition unless Day-1 and Day-7 also meet the current App
Store Connect peer-group median. The numerical floors above are planning
thresholds; Apple's live peer benchmark is the release authority.

## Commercial

App Store Connect is authoritative for download → trial, trial → paid,
Day-35 paid conversion, refunds, proceeds, renewals, and peer comparison. The
consented first-party aggregate is intentionally anonymous and daily; it can
measure activation coverage and bounded AI usage/cost, but its daily totals
must not be joined or divided into a trial-conversion cohort. Reconcile the two
sources at aggregate reporting boundaries without inventing user-level linkage.
Use `commercial-reconciliation.md` for that comparison. The checked-in CLI
requires a `calendar-event` window, all storefronts/plans/builds, explicit
closed-day coverage, source hashes, and fixed identifier-free columns. Because
Apple's Sales and Trends reports use Pacific dates while Noum batches close in
UTC, even a zero delta remains a coverage check with a timezone caution—not an
exact event-time match. Cross-currency proceeds/AI-cost arithmetic is blocked
without a separately hashed conversion receipt.
Contribution-margin arithmetic is also blocked whenever the anonymous daily
aggregate reports any unpriced off-device AI usage. Known priced cost remains
visible, but missing provider units are never assumed to cost zero. On-device
processing remains a genuine zero-cost route and does not enter that count.

| Gate | Required before material paid acquisition |
|---|---:|
| Download → trial | ≥7% |
| Trial → paid | ≥35% |
| Day-35 download → paid | ≥3% |
| Refund rate | <4% |
| Contribution margin after Apple and AI cost | ≥75% |
| 90-day LTV / CAC | ≥3× |
| Acquisition payback | ≤6 months |

At the planning mix of 70% annual and 30% monthly, use 900 active payers as the
operating target for £5,000 monthly App Store receipts. Replace planning math
with App Store proceeds, refunds, taxes, renewal failures, and measured AI cost
before making spend decisions.

## Evidence and scale sequence

1. Current-source live-provider evaluation.
2. Blinded review by at least three qualified communication coaches.
3. Four-week closed beta: at least 30 qualitative participants and 200 installs,
   with enrollment, attrition, delayed follow-up, and negative outcomes kept.
4. Physical same-build TestFlight verification.
5. At least 500 qualified installs before judging trial conversion or spending
   materially on acquisition.

The 200-install D1/D7 cohort is a first-release evidence gate. The 500-install
threshold is a distinct, nonblocking scale/conversion-readiness signal: being
below 500 must not reduce the release-readiness score or add a launch blocker.

The release remains NO-GO while any corresponding item in
`docs/MANUAL_LAUNCH_ACTIONS.md` is open.
