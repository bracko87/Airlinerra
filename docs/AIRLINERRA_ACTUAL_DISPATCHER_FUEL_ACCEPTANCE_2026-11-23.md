# Airlinerra — Actual automatic flight dispatcher with real fuel integration

**Date:** 23 November 2026

**Acceptance result:** PASS, PostgreSQL 17 disposable GitHub Actions:
https://github.com/bracko87/Airlinerra/actions/runs/45252158920

## What executed

This acceptance workflow installs and executes the actual
`section9_auto_dispatch_due_flight_events_v1(integer)` function, with
the forward-only traffic-permission variable correction from
`20261123210000_section9_dispatch_traffic_permission_binding_fix.sql`.

The workflow also installs:

- The actual production fuel preflight function
  `section9_verify_game_fuel_before_departure_v1`.
- The actual production fuel departure receipt function
  `section9_capture_verified_departure_fuel_v1`.
- The real, SHA-256 HMAC-checking signed-movement writer,
  with its forward-only cancelled-occurrence/starter-position fixes in
  `20261123200000_section9_signed_movement_cancellation_guard.sql`.

The participating synthetic tables and proof-producer functions provide
an eligible airline/aircraft, certified schedule, airport slot evidence,
game licence and route right, maintenance clearance, verified game clock,
fixed fuel model quote, and a non-refuelling automatic fuel-supply result.
The test uses a disposable Vault key and checks real pgcrypto HMAC handling.

## Passing acceptance cases

1. Lowering authorized aircraft fuel custody to 100 kg (under 180 kg
   minimum planned fuel) causes the actual dispatcher to report
   `AIRCRAFT_FUEL_NOT_PROVEN_AT_ORIGIN`.
2. The blocked dispatch leaves the flight open, with zero signed
   movements and zero departure fuel receipts.
3. Restoring authorized 500 kg fuel allows the actual dispatcher to
   record a signed departure and exactly one real fuel receipt, and
   closes the occurrence.
4. Reexecuting the actual dispatcher does not create a duplicate
   departure movement.

## Production defect discovered and repaired in repo

The original dispatcher failed at its traffic-permission check with
`column reference "permission_code" is ambiguous`, because a local
PL/pgSQL variable had the same name as a referenced permission
application column. The forward-only corrective migration uses
`required_permission_code` for that local variable and leaves the
game activation controls unchanged.

## Isolation and limitations

- **No production deployment, migration execution, or release-setting
  change was made.**
- This is an integration test of the actual *automatic dispatcher and
  signed fuel-departure functions* using deliberately synthetic
  certification/clock/maintenance inputs; the source-producing systems
  themselves are not end-to-end verified.
- The actual auto-fuel top-up function is **not** run. The test uses a
  labelled non-refuelling stub and pre-approved synthetic fuel custody.
- Actual arrival fuel burn, airframe usage, ticket settlement and money
  ledger posting are **not** run.
- This workflow exercises the insufficient-fuel pre-dispatch block and
  successful atomic departure, **not every possible post-movement
  exceptional rollback path**.

## Files

- `.github/workflows/section9-real-dispatcher-fuel-ci.yml`
- `tests/sql/section9_real_dispatcher_disposable_dependencies.sql`
- `supabase/migrations/20261123210000_section9_dispatch_traffic_permission_binding_fix.sql`

## Next recommended release-safety boundary

Execute the actual once-only arrival fuel burn function, its genuine
signed arrival event and airframe usage receipt in a disposable database.
Verify exact remaining fuel, provenance and replay, with negative
cases for custody mismatch and rolled-back arrival. Follow with an
isolated full migration replay before any controlled production release.
