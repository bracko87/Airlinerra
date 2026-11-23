# Airlinerra — Actual game-only automatic fuel supply integration acceptance

**Date:** 23 November 2026

**Result:** **PASS** — disposable PostgreSQL 17 GitHub Actions
https://github.com/bracko87/Airlinerra/actions/runs/45254572700

## What was executed

The workflow installs and executes the unmodified production SQL bodies for:

- `section9_auto_supply_game_only_fuel_v1`
- `section9_verify_game_fuel_before_departure_v1`
- `section9_capture_verified_departure_fuel_v1`
- `section9_auto_dispatch_due_flight_events_v1`

It also uses the actual HMAC-verifying signed-movement writer with the previously committed forward-only corrections in `20261123200000_section9_signed_movement_cancellation_guard.sql`, and the corrected traffic permission variable in `20261123210000_section9_dispatch_traffic_permission_binding_fix.sql`.

The dependency stack uses synthetic airport facilities, certification, licence, slots, maintenance clearance, nonproduction Vault signing secret and reserve-fuel quotation. The actual supplier function, dispatcher, preflight and departure fuel receipt themselves are not mocked.

## Passing acceptance checks

1. Pre-authorized 100 kg aircraft fuel with a 180 kg minimum requirement cannot be topped up at a simulated airport where `fuel_available=false`. The production auto supplier reports `blocked_no_game_airport_fuel_service` and the dispatcher records neither movement nor departure fuel receipt.
2. With that airport's game-only fuel service marked available, the **actual dispatcher calls the actual supplier**. Exactly 80 kg is loaded into custody, resulting in 180 kg with custody revision 2. The supplier event is written with the expected deterministic `game-auto-fuel-v1-` ID, source `game_authority_approved`, added 80 kg and after-load 180 kg.
3. The unchanged fuel preflight verifies the authorized new receipt and available fuel. The actual signed writer records one genuine SHA-256 HMAC departure, the unchanged fuel departure receipt records its fuel proof, and the occurrence closes.
4. Repeated dispatch records zero additional departures, and direct replay of auto supply after booking closure refuses the nonoperating flight. Exactly one auto-fuel load receipt, one signed departure movement, and custody revision 2 remain.

## Source files

- `tests/sql/section9_real_auto_fuel_disposable_dependencies.sql`
- `.github/workflows/section9-real-auto-fuel-ci.yml`
- `supabase/migrations/20261117110000_section9_game_fuel_custody_supply_dispatch_v1.sql`

## Limitations and next steps

No production deployment, Supabase migration, live flight, financial settlement, or release switch change occurred. These tests use a synthetic fuel quote and upstream certification and do **not** certify real aircraft fuel grades or real-world flight operations.

This test covers **top-up of an existing valid custody record**, not first-ever custody creation from authorized starter-position evidence, all concurrent supplier/cancellation races, or the actual fuel-cost/finance settlement workflow.

**Recommended next safety sequence:**
1. Add first-ever custody creation and invalid starter-position scenarios for the real supplier; test concurrent supplier calls on a single aircraft.
2. Replay the forward-only migrations in an isolated staging migration stack to catch ordering, permission and schema drift.
3. Validate fuel and postflight financial settlement separately before considering production deployment.
