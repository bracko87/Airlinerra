# Group 2 enters the real schedule-save boundary — 2026-11-10

## Production changes completed
Applied:
1. `supabase/migrations/20261110194500_group2_owner_verified_schedule_preflight.sql`
2. `supabase/migrations/20261110201000_group2_schedule_save_fail_closed_owner_preflight.sql`

The first introduces the private read-only `group2_owned_aircraft_route_preflight_v1`, which checks a verified player UUID against the actual owned airline, active world membership, owned in-service aircraft, passenger/cargo stand compatibility and the existing 54-week Group 2 route runway, slot and noise/curfew preview.

The second modifies the **real** `section6_save_owned_aircraft_schedule_with_slots_v1` function. When origin or destination belongs to Group 2, it calls owner-verified preflight then raises `SECTION6_GROUP2_NOT_YET_ADMITTED`, including the preflight decision as error detail. This happens before the first airline flight schedule draft or slot-reservation mutation. The ordinary Group 1 capacity locks, draft save, slot preflight and reservation insert remain in the function unchanged. This does **not** open Group 2 flights.

Production `airlinerra-flight-schedule-drafts` active Edge function v11 was inspected: its bundled `server/flight-schedule-service.mjs` uses `SCHEDULE_SQL.save`, which calls exactly the modified `section6_save_owned_aircraft_schedule_with_slots_v1` database function. No Edge redeployment was needed for this database function change.

## Verification
- Readback confirmed that `SECTION6_GROUP2_NOT_YET_ADMITTED` exists in the deployed function and precedes `section5_save_owned_aircraft_schedule_draft_v1`.
- A production SQL regression probe called the schedule-save function with non-existent owner/aircraft UUIDs and Group 2 airport keys, captured `SECTION6_GROUP2_NOT_YET_ADMITTED`, and verified identical before/after counts for schedule drafts and weekly slot reservations. The probe was stored under `tests/group2_schedule_save_boundary.sql`.
- Production counts: Group 1 approved 3,141; Group 2 prepared 1,118; Group 2 operationally activated 0; Group 2 saved plans 0; Group 2 existing slot reservations 0.

## Important remaining boundaries
- This is **diagnostic integration into a real save path**, not permission to save Group 2 draft flights. The fail-closed exception remains intentional.
- HQ/home-airport and hub/station foreign keys remain approved Group 1 only. Player-facing Group 2 location plans have a separate table, not operational entries.
- Actual Group 2 release still needs conditional restrictions for per-aircraft use, license and traffic-right checks, fleet movement/home-base admission, transactionally enforced weekly slot reservations and approval policy for new airport keys.
- GitHub Actions and live authenticated browser acceptance are **not confirmed**. An owner-authenticated real-aircraft plan preview has not been executed. Do not mark Group 2 active or claim end-to-end flight support.
