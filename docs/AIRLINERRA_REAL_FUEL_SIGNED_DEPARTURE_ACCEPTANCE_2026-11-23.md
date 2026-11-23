# Airlinerra — real signed departure + real fuel preflight/receipt acceptance

**Date:** 2026-11-23

**Result:** PASS — isolated PostgreSQL 17 GitHub Actions run
https://github.com/bracko87/Airlinerra/actions/runs/45250531248

## Verified executable integration

The disposable database executed the actual unmodified production SQL for:

- `section9_verify_game_fuel_before_departure_v1(text)`
- `section9_capture_verified_departure_fuel_v1(text,text)`

The real signed movement writer with the forward-only cancellation guard
(`20261123200000_section9_signed_movement_cancellation_guard.sql`) was also installed.

A genuine SHA-256 HMAC signature was generated with pgcrypto and a synthetic,
nonproduction Vault key. Synthetic game clock, aircraft/route activation,
and fixed reserve-aware fuel quote records supplied the required dependencies.

### Passing assertions

1. A 500 kg authorized, matching custody source and 180 kg minimum
   planned fuel passed the unchanged fuel preflight.
2. In one transaction, the real HMAC signed departure was inserted,
   the unchanged fuel receipt function recorded the departure fuel
   evidence, and the booking status was closed. Movement and fuel
   receipt counts were both exactly one.
3. Repeated invocation of the departure fuel receipt function returned
   a stable already-proven replay status without creating a duplicate.
4. With authorized custody reduced to 100 kg (below the required 180 kg),
   the unchanged preflight returned
   `blocked_insufficient_aircraft_fuel_including_reserve`.
5. A deliberately attempted signed departure in one transaction
   followed by the real receipt function's failed fuel verification
   triggered the dispatch-equivalent rollback error. The transaction
   left zero signed movements, zero departure receipts, and the flight
   occurrence still open.

## Source and test files

- `tests/sql/section9_real_fuel_departure_disposable_dependencies.sql`
- `tests/sql/section9_real_signed_movement_disposable_dependencies.sql`
- `tests/sql/section9_real_cancellation_disposable_bootstrap.sql`
- `.github/workflows/section9-real-fuel-departure-ci.yml`
- `supabase/migrations/20261117110000_section9_game_fuel_custody_supply_dispatch_v1.sql`
- `supabase/migrations/20261123200000_section9_signed_movement_cancellation_guard.sql`

## Unverified scope

This **does not run** the complete actual
`section9_auto_dispatch_due_flight_events_v1` dispatcher. The test
orchestrates the same signed-write, receipt, booking close and rollback
sequence explicitly, using real underlying functions. Other actual
components not tested in this run include the game auto-fuel top-up
function, the true reserve-aware quotation model, fuel burn at
arrival, airframe cycles, passenger settlement and financial posting.
The release/clock/certification input stack is synthetic.

The corrective migration remains **repository-only**; it has not been
deployed to the production database, and no production release settings
were changed.

**Next acceptance boundary:** exercise the full real automatic dispatcher
using independently verified synthetic aircraft, certified slot,
permissions, and fuel inputs, and verify its failure paths; then test
real arrival burn and receipt reconciliation; finally rebuild/validate
the forward-only migrations on isolated staging prior to controlled
deployment.
