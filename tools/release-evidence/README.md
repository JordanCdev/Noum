# Noum release-evidence workflow

This tool prepares and validates the four human/operational evidence artifacts
that cannot be earned by simulator tests:

- professional-coach calibration;
- longitudinal real-user transfer;
- physical-device TestFlight QA;
- operational launch completion.

It does **not** generate results, claim production readiness, run providers,
deploy services, upload builds, or replace `readiness_gate.py`. Every initialized
artifact is marked `NOT_PRODUCTION_EVIDENCE` and fails validation.

See `docs/PRODUCTION_EVIDENCE_COLLECTION.md` for the end-to-end operator
procedure.

## Commands

```bash
./tools/release-evidence/run.sh init --run-dir /secure/path/to/run \
  --initialized-by-id '<real operator identifier>' \
  --initialized-by-role '<real operator role>'

./tools/release-evidence/run.sh register-attachment \
  --run-dir /secure/path/to/run \
  --id '<stable evidence id>' \
  --kind '<required kind>' \
  --file /secure/path/to/real-evidence \
  --captured-at '2026-07-13T12:00:00Z' \
  --verified-by-id '<real verifier identifier>'

./tools/release-evidence/run.sh summarize --run-dir /secure/path/to/run
./tools/release-evidence/run.sh validate --run-dir /secure/path/to/run
./tools/release-evidence/run.sh promote --run-dir /secure/path/to/run
```

`register-attachment` copies the file beneath the run, computes its SHA-256,
and returns an `evidence://...` reference. The artifact JSON must use that
reference. Files containing personal data additionally require an access-control
reference. Never register raw transcripts, participant names, credentials,
unredacted receipts, or App Store secrets.

`summarize` derives counts from entered rows. It never changes pass/fail claims,
ratings, outcomes, warnings, attestations, or the visible template status.

`promote` requires a complete independent promotion approval, re-runs the
existing readiness artifact validator against the exact source-bound packet,
and atomically copies only the four managed artifacts. It writes a receipt that
explicitly says `launchReadyClaimed: false`; the Swift manifest and full
readiness gate must be refreshed afterwards.

The extended preflight also prevents two common false promotions: a successful
cloud probe cannot mask an open legacy-credential or social-cutover gate, and a
direct Xcode development-device install cannot be recorded as TestFlight QA.
