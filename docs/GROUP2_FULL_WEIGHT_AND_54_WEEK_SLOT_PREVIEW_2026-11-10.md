# Group 2: full-weight runway and 54-week slot preflight bridge — 2026-11-10

## Deployed in production Supabase
Project `hwllkabgzaynalahvkpz`, airlinerra_game schema. Migrations committed on GitHub `main` and successfully deployed:
- `20261110175500_group2_full_weight_slot_leg_preview.sql`
- `20261110181000_group2_weekly_slot_capacity_bridge.sql`

New private, read-only infrastructure:
1. `group2_full_weight_slot_leg_preview_v1(airport_key,configuration_id,operation,time_utc,stand_type)`: game-specific full-weight MTOW/MLW runway reference (from existing Section 5 aircraft full-weight reference, with observed Group 1 airport elevation formula), plus local-time, weekday, 10-minute/hour slot capacity and actual existing reservation-count snapshot. It does NOT allocate a reservation or approve a flight. Missing aircraft reference is blocked; missing/zero capacity is blocked.
2. `section6_group2_slot_capacity_bridge_v1`: 1,118 Group 2 airports in a read-only view matching the Section 6 capacity columns (`terminal_stands`, `remote_stands`, `cargo_stands`, and per-direction/10-minute capacity). Explicit `admitted_for_bookings=false`; it is deliberately NOT the live `section6_airport_slot_capacity_v1` table.
3. `group2_weekly_slot_route_preview_v1(...)`: models local departure/arrival time buckets for a 54-week repeated schedule (Monday 0-based weekday, hour and ten-minute intervals), stand-category/hour limits, and counts existing reservations. Uses the same bucket concept as Section 6 but a separate private Group 2 capacity view. Limited to **two Group 2 airports**, valid weekly schedule items, and 7 or fewer timetable entries. Never inserts slot records. It does not run runway/Chapter/licence gates automatically.

Important: all three are server-private; anon/authenticated/public permissions revoked. No airline, HQ, office, flight scheduling, movements or booking tables were changed.

## Production verification
After one fail-closed migration test failure (invalid test expectation), the full-weight migration was corrected and successfully applied. Verified examples:
- Grant County International (OURAIRPORTS:20581), Boeing 737-800 config 1: 4,115.7m game runway vs 2,429m elevation-adjusted MTOW game distance; terminal 3 per 10-minute bucket, zero reservations; preliminary capacity pass, **canReserve=false**.
- Paris–Le Bourget (OURAIRPORTS:4183), ATR 72-200 config 202: modeled terminal capacity **0**, blocked.
- Paris–Le Bourget, Boeing 737-900 config 194: 2,395.1m game runway vs 2,771m elevation-adjusted full-weight requirement, blocked.
- Airbus A340-500 config 239: full-weight engine has no reference despite its sourced Chapter 14; blocked for missing runway reference rather than guessed.
- Grant County to Ciudad Real weekly one-flight/day-pattern example: 54-week DST-aware local-time bucketing, preliminary capacity pass, **no reservations written**.
- Paris–Le Bourget to Ciudad Real with terminal stand: fails due to zero modeled terminal capacity.

Database postchecks: 1,118 staging Group 2 capacity records, 0 in live Section 6 Group 2 capacity rows, 0 Group 2 slot reservations, 0 Group 2 commercial activations, 0 saved planned HQ/hub/station intentions, existing approved Group 1 roster 3,141.

## Limits and next activation work
These are **planning checks**, not integration of actual Group 2 booking/flight operations.
- Existing live `section6_weekly_slot_preflight_v1` still reads approved Group 1 airport reference profiles and slot-capacity table.
- Group 2 has no FK-backed access to active slot reservations, flight schedules, aircraft movement state or HQ/office tables.
- The Group 2 weekly preview does not compare route-specific aircraft runway requirements or per-occurrence nighttime/Chapter restrictions. It must be paired with the separate Group 2 readiness/conditional checks and then brought inside one trusted scheduling transaction.
- No real-world dispatch clearance: weather, aircraft-specific declared TORA/LDA, slope, obstacles, operational status, traffic rights and final runway approvals remain outside preview.
- A full end-to-end authenticated game-browser test and passing GitHub CI still need verification.

Do not promote Group 2 into `approved_game_airports` simply to make these previews pass; admission must be a separate guarded release after all requirements are checked.
