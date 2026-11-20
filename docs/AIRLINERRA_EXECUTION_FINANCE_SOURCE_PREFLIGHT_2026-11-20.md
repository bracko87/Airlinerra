# Airlinerra execution/finance source-proof preflight — November 20, 2026

## Implemented

**Production Supabase migration applied:** `supabase/migrations/20261120215500_section9_execution_finance_source_preflight_readonly.sql`.

Added a private read-only `airlinerra_game.section9_execution_finance_certificate_source_preflight_v1(airline_uuid,schedule_uuid,version,game_day,clearance_type)` function for the two as-yet-unreleased certification types: `trusted_flight_execution` and `commercial_finance`.

It reads actual World 1 release flags, trusted execution and fuel readiness, finance approval (for the commercial finance source), the independently verified Berlin game date, exact persisted draft/version, airline-owned in-service leased/owned aircraft, game fuel model, and the three existing signed certificate rows (operator, traffic rights, airport slots), linked to their original audit event identities.

The function cannot issue or represent a certificate, even if every underlying preliminary condition succeeds. It always returns `verified=false`, `certificateIssued=false`, `sourceAuthorityReleased=false` and non-authorization status `source_preflight_complete_not_certifiable` or `blocked_unreleased_execution_finance_source`. It has no write statements, and execution privileges are revoked from `PUBLIC`, `anon`, `authenticated` and `service_role`.

A private Node adapter, `server/section9-unreleased-certificate-source-reader.mjs`, performs strict argument and JSON-result validation. It will reject any response that purports to issue a certificate, authorize a source, activate a flight, create reservations, move aircraft or post a ledger entry. Neither it nor this SQL function receives an HMAC signing key. The private certification sink still rejects all actual attempts to issue either new type with `SECTION9_UNRELEASED_EXECUTION_OR_FINANCE_CERTIFICATION`, as implemented in the previous migration.

## Verification

Automated isolated Node tests: https://github.com/bracko87/Airlinerra/actions/runs/44810725321 — **success**.

Confirmed actual live Supabase read-only responses for a deliberately nonexistent FRA–MUC fixture identity:
- Trusted flight execution: `blocked_unreleased_execution_finance_source` and blockers including paused commercial activation, no trusted execution release, no flight/fuel engine activation and missing draft version.
- Commercial finance: all above plus `FINANCE_POSTING_NOT_APPROVED`.
- Both returned `verified=false`, `certificateIssued=false`, `sourceAuthorityReleased=false`, `ledgerPosted=false`.
- Function privileges for anonymous, authenticated and service roles are all false.

The migration changes **no production release flags, no schedule rows, no player finance, and no licence design**.

## What is *not* finished

This is a real-data **negative and preliminary source preflight**, *not* an independent signed positive source producer. It is intentionally impossible for the new code to deliver a live trusted execution or finance certification. Next implement private proof producers with separate authority keys and independent primary event sources, then a same-transaction PostgreSQL source recheck for each type before removing the current explicit database rejection. A full end-to-end FRA–MUC activation-to-settlement disposable run and controlled owner-authorized production activation remain pending.

Earlier complete isolated positive two-leg activation: https://github.com/bracko87/Airlinerra/actions/runs/44806462333 . Earlier real HMAC + ticket + six-way finance settlement (synthetic supporting state): https://github.com/bracko87/Airlinerra/actions/runs/44801467387 .
