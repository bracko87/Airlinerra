# Airlinerra — Initial fuel custody and supplier concurrency acceptance

**Date:** 23 November 2026

**Result:** PASS — disposable PostgreSQL 17 GitHub Actions
https://github.com/bracko87/Airlinerra/actions/runs/45255497302

## Scope

The CI workflow loads the **unchanged** real production
`section9_auto_supply_game_only_fuel_v1` and
`section9_verify_game_fuel_before_departure_v1` functions from
`20261117110000_section9_game_fuel_custody_supply_dispatch_v1.sql`.

Game airport service, verified starter-position input, aircraft/model, reserve-aware quote, licence, clock and certification evidence are deliberately synthetic. No production database or release switch was modified.

## Passed regression cases

1. **Incorrect starter airport**: with no fuel-custody row and no prior source receipts, a synthetic independently verified starter airport different from the flight's departure airport makes the real supplier return `blocked_unverified_aircraft_fuel_starter_location`. Both custody and load-receipt row counts remain zero.
2. **First-ever authorized fuel load**: changing starter evidence to the correct origin airport lets the actual auto supplier create the first custody row with exactly 180 kg, revision 1, source kind `approved_game_fuel_load`, and a single `game_authority_approved` supply receipt with 180 kg added. The actual preflight verifies that source and quantity. A second supply call returns `game_fuel_already_sufficient` and writes nothing.
3. **Concurrent supply serialization**: resetting fuel to no custody, the first real supplier call runs in an open transaction holding the aircraft's exact production advisory lock `(583731,hashtext(aircraft UUID))`. A concurrent independent call returns `game_auto_fuel_aircraft_busy`. The original transaction commits its legitimate supply; a subsequent call sees sufficient fuel. Counts remain exactly one custody row and one authorized receipt, revision 1.

## Files

- `.github/workflows/section9-auto-fuel-starter-concurrency-ci.yml`
- `tests/sql/section9_real_auto_fuel_disposable_dependencies.sql`
- `supabase/migrations/20261117110000_section9_game_fuel_custody_supply_dispatch_v1.sql`

## Unverified boundaries

No real-world fuel-grade proof, production airport/supplier evidence, operational airport service, client billing, real-world release permission, or live production operations were tested. The collision test includes a deliberately held advisory transaction lock and one competing supplier call; it is not a high-volume randomized stress test. Full historical database migration replay and isolated staging remain outstanding.

**Next priority:** establish a complete fresh PostgreSQL/Supabase migration replay and verify that repository-only forward corrections preserve access-control grants and existing schema before any controlled production migration.
