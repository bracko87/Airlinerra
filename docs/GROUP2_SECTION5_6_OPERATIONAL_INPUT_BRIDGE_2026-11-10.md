# Airlinerra — Group 2 Section 5/6 integration input bridge and operational blockers
Date: 2026-11-10

## Delivered in production
Migration `supabase/migrations/20261110164500_group2_section5_6_engine_input_preview.sql` applied successfully to production Supabase project `hwllkabgzaynalahvkpz`.

Private, read-only database views:
- `airlinerra_game.airport_group2_engine_input_preview_v1`: one row per Group 2 airport, exposing existing runway, stand/10-minute capacity, timezone, game curfew/noise flags, review provenance, source details and explicit operational blockers.
- `airlinerra_game.airport_group2_engine_input_summary_v1`: coverage of prepared airport data and what is still missing from the **live operational** engines.

Both views use `security_invoker=true`, and all grants to `PUBLIC`, `anon` and `authenticated` are revoked. They do not modify any routes, flight schedules, bookings, airport office statuses or aircraft movements.

## Verified production postchecks
- 1,118 / 1,118 prepared airports with positive game runway length
- 1,118 / 1,118 with nonnegative stand-type per-10-minute capacities
- 1,118 / 1,118 with game curfew/noise flags
- 0 Group 2 airports represented in the existing `section5_airport_operating_policy_v1` engine
- 0 Group 2 airports represented in the existing `section6_airport_slot_capacity_v1` engine
- 0 Group 2 airports in `approved_game_airports`
- 0 Group 2 declared dispatch authorizations; 0 active Group 2 HQ or offices
- 3,141 approved Group 1 airports unchanged

Two Group 2 Medium airports have game noise restrictions: Paris–Le Bourget (also a curfew flag) and Ciudad Real. Both have nonempty source descriptions. **Text is not machine-readable enforcement.** These still require a structured aircraft-specific noise Chapter and local-time rule implementation; null/missing string checks alone do not validate completeness.

## Why not make Group 2 active immediately?
The `approved_game_airports` table is referenced not just by HQ and office FKs but by many operational tables: flight schedules, routes, slot reservations, aircraft delivery and current positions, maintenance locations, and flight movements. Extending those FKs/approvals without integrating the Section 5 and 6 engine gates could open an unintended path to operate flights at airports whose operating rules have not been evaluated. Changing the FK on `airlines` alone is not sufficient.

## Subsequent engineering order
1. Add a trusted Section 5 **structured** rule converter for Group 2 game policies; preserve conditional operating exceptions and never reduce Paris–Le Bourget to a blanket 24-hour closure.
2. Integrate Group 2 stand capacity and timezones with the server-owned slot preflight, maintaining strict admission blocks on actual reservations.
3. Update aircraft full-weight runway, noise Chapter, scheduling, movement and licence checks for Group 2.
4. Only after all of those pass, promote approved airport records and turn future HQ/hub/station plans into operational selections through owner-authorized actions.
5. Test end-to-end with a verified manager before releasing; do not infer operational availability merely from a prepared airport directory or planned-location UI.

This migration and its SQL postchecks are verified. It does not constitute live flight engine integration or commercial admission.
