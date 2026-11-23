# Airlinerra — actual signed arrival, fuel burn, airframe counters and custody mismatch rollback

**Verified date:** 2026-11-23

**Latest result:** PASS (PostgreSQL 17 disposable GitHub Actions)
https://github.com/bracko87/Airlinerra/actions/runs/45253245734

## Executed production SQL

- Actual `section9_auto_dispatch_due_flight_events_v1` dispatcher with forward-only traffic-permission correction.
- Actual SHA-256 HMAC-verifying signed movement writer with forward-only cancelled-occurrence/verified-starter correction.
- Unmodified `section9_verify_game_fuel_before_departure_v1`.
- Unmodified `section9_capture_verified_departure_fuel_v1`.
- Unmodified `section9_apply_arrival_airframe_usage_once_v1`.
- Unmodified `section9_apply_verified_arrival_fuel_burn_once_v1`.

These were executed in one isolated PostgreSQL 17 database with independently labelled synthetic permission, maintenance, clock, airfield, schedule, reserve-fuel quote, and no-refuelling evidence providers. The events used a genuine pgcrypto HMAC produced with a disposable key.

## Passing assertions

1. The actual dispatcher records a genuine signed departure and fuel receipt and closes its occurrence.
2. Advancing the synthetic game clock to arrival records one signed arrival, one airframe-usage receipt, and one actual fuel-burn receipt.
3. Fuel custody decrements from 500 to 380 kg after a planned 120 kg burn; custody revision increments from 1 to 2 and location changes to destination TEST-BBB.
4. Airframe maintenance increases by 1.000 hour and 1 cycle.
5. Repeated dispatcher execution and direct receipt invocations do not apply another burn, hour, or cycle.
6. A second synthetic flight departs validly, but its custody revision is intentionally modified during flight. The actual automatic dispatcher raises `SECTION9_FLIGHT_FUEL_CUSTODY_CHANGED_IN_TRANSIT_ROLLBACK`; the attempted signed arrival, airframe counter update and arrival burn receipt all roll back. The valid prior departure and its fuel receipt remain intact.

## Files

- `.github/workflows/section9-real-arrival-fuel-ci.yml`
- `tests/sql/section9_real_arrival_disposable_dependencies.sql`
- `tests/sql/section9_arrival_custody_conflict_disposable_setup.sql`
- `supabase/migrations/20261123200000_section9_signed_movement_cancellation_guard.sql`
- `supabase/migrations/20261123210000_section9_dispatch_traffic_permission_binding_fix.sql`

## Boundaries and next step

**Production unchanged.** No live Supabase migration applied, release switch changed, flight activated, or ledger posted.

This test does not exercise the real automatic fuel-supply engine, the true reserve-aware aircraft consumption model, production certification/permission generators, or live ticket settlement. It uses the real dispatcher and functions but supplies synthetic upstream evidence.

Before deployment, run the full migrations against isolated staging, reconcile existing historical function definitions and their grant policies, verify no dependency regression, and independently test real fuel top-up and finance boundaries. Release must remain disabled until those checks pass.
