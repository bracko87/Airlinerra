# Airlinerra — positive execution/finance source-snapshot acceptance (20 Nov 2026)

## Verified real SQL result

GitHub Actions: https://github.com/bracko87/Airlinerra/actions/runs/44815663876 — **passed**.

The test installs **unchanged production source SQL** for:
- `section9_execution_finance_certificate_source_preflight_v1` from `20261120215500_section9_execution_finance_source_preflight_readonly.sql`;
- `section9_execution_finance_source_snapshot_v1` from `20261120224500_section9_execution_finance_source_snapshot_candidates.sql`.

Both are executed inside a fresh PostgreSQL 17 instance named `airlinerra_disposable`, whose database identity is checked before fixtures are created. Release approvals and flight evidence are **synthetic controlled records** for an FRA (OURAIRPORTS:2212) → MUC (OURAIRPORTS:2218) draft schedule with one owned in-service aircraft, source-clock fixture, released fuel model, and three fictional older operator/route/slot certification rows with linked event identities.

## Passed test behaviors

1. Real trusted-execution source snapshot returns `source_snapshot_candidate_not_authorized`, `candidateReady=true`, nonempty 32-character lowercase-hex fingerprint, `certificateIssued=false`.
2. Real commercial-finance snapshot returns a **distinct** valid fingerprint for the same schedule and date, with `certificateIssued=false`.
3. Exact repeated source values produce the identical execution fingerprint.
4. Changing the destination airport key changes the fingerprint without changing the date or version.
5. Changing the reviewed execution-producer release-evidence reference changes the fingerprint.
6. Revoking the prior route-rights clearance blocks fingerprint generation and includes `PRIOR_INDEPENDENT_CERTIFICATIONS_MISSING`.
7. Pausing commercial-finance posting blocks the finance snapshot and includes `FINANCE_POSTING_NOT_APPROVED`.
8. Invalidating the game-clock fixture blocks the source snapshot and includes `AUTHORITATIVE_GAME_DAY_NOT_VERIFIED`.
9. Bumping the persisted schedule version rejects a call using the stale version.
10. No execution or commercial-finance certificates are created.

## Files

- `tests/sql/section9_disposable_source_snapshot_positive_bootstrap.sql`
- `tests/sql/section9_disposable_source_snapshot_positive_acceptance.sql`
- `.github/workflows/section9-source-snapshot-positive-disposable-ci.yml`

## Limits and next step

This test proves the **actual production source-snapshot functions** can read positive state and preserve deterministic, version-bound candidate evidence. It **does not** prove production AOC/traffic-rights issuance, authentic independent clock signatures, real airport capacity reservations, release approval, or independent issuer HMAC verification. Its three earlier certification event rows are test fixtures, not real approvals.

The production certification sink **still expressly refuses** `trusted_flight_execution` and `commercial_finance` (SQLSTATE 42501). Candidate fingerprints cannot issue tickets, activate flights, record movements or change money.

Next: implement **two independently authenticated authority-specific proof producers and HMAC signers** together with same-transaction database source rechecks, validate source-fingerprint tamper/staleness/revocation in disposable PostgreSQL, and only then test all ten certificates. Production release flags and player data remain unchanged.
