# Airlinerra — Group 1 + Group 2 unified Section 1–8 game-data catalog

Date: 2026-11-10

## Successful production migration
Migration `supabase/migrations/20261110233000_airport_group1_group2_unified_sections1_8_catalog.sql` applied to Airlinerra production Supabase.

The **combined prepared Section 1–8 game-data registry** now contains exactly **4,259** unique airports:
- **Group 1**: 3,141 existing World 1 approved airport records.
- **Group 2**: 1,118 preapproved game profiles, fixed 23 batches.

Group 1 and Group 2 originally stored corresponding eight-section information in **different table structures**. The new common interface normalizes their basic game fields while retaining the original richer source documents as structured JSON in `section_1_8_source_data`.

The new tables/views are:
- `airlinerra_game.airport_sections1_8_combined_members_v1`: physical combined membership table with 4,259 records, primary key on `(world_id, airport_key)`, source group and commercial access scope.
- `airlinerra_game.airport_sections1_8_combined_catalog_v1`: unified read-only game-data view with common fields for Section 1 identity, Section 2 category, Section 3 runway, Section 4 facilities, Section 5 curfew/noise, Section 6 slots, Section 7 outbound demand/seasonality, and Section 8 fees/tariffs. Full original fields are available as JSON nested by section, preserving distinct provenance.
- `airlinerra_game.airport_sections1_8_combined_status_v1`: combined coverage and safeguards.

Privacy/access: the membership table has RLS enabled and is not granted to `anon` or `authenticated`; both views have `security_invoker=true` and direct public/authenticated grants revoked. This is internal data, not yet wired into the public game client.

## Exact post-install verification
Production SQL readback gave:
- Total combined: **4,259**; Group 1 **3,141**; Group 2 **1,118**.
- Records containing data objects for all eight sections: **4,259**.
- Missing key shared fields (including airport code, coordinates, timezone, runway, stands, slot capacity, night/noise game values, outbound traffic, seasonality, prices): **0**.
- Duplicate airport keys: **0**; duplicate combined display game lookup codes: **0**.
- Group 1 approved World 1 table remains **3,141**, not 4,259.
- Group 2 commercial admission / activation remains **0**; World 1 remains `planned`.
- Group 1 fictional Aleksandrovo Airport's 2,200m runway is retained from the explicitly owner-defined fictional design / qualifying registry, marked as fictional, **not** a real-world observed runway.

## Scope distinction
This unifies **game-data preparation** in the database. It does not:
- Migrate the 1,118 Group 2 airports into `airlinerra_game.approved_game_airports`.
- Grant Group 2 commercial access, owner release, aircraft dispatch or slot booking.
- Automatically change player airport search/route planner endpoints to the new view.
- Prove the live scheduling engine actually enforces per-aircraft noise classes, curfew times, airport capacities or all runway rules.
- Assert independent source verification for estimated Group 2 values. Group 1's different data provenance remains in its original source records.

For rollout, check existing application catalog consumers and server-owned release gates, then separately authorize any operational switch after integration tests.
