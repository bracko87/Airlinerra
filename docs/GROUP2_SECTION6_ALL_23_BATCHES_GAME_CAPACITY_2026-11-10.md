# Airlinerra — Group 2 Section 6 capacity and slots: game-data closure
Date: 2026-11-10

## Acceptance
Production database migration installed and readback verified: **1,118 / 1,118** provisional capacity profiles and **23 / 23** fixed batches meet `game_complete_estimated`, with no failed batches.

- **1,118** profiles have the explicit basis `GROUP1_CATEGORY_MEDIAN_GAME_NOT_COORDINATOR_SLOTS`.
- Passenger stand availability: **1,075** airports; cargo stand availability: **165** airports. Categories overlap for mixed passenger/cargo airports.
- All Section 6 stand counts agree with Section 4 facility stand counts: **0 mismatches**.
- No negative or missing slots; **0** cases of slots for a nonexistent stand type, or a stand type without its corresponding game slot count.
- The per-10-minute terminal/remote/cargo game slot values are *not* official slot coordinator allocations, real capacity, legal clearances or guarantees of throughput.

## Data objects
- `airport_group2_section6_game_registry_v1`: each airport's per-10-minute game capacity and clear estimate provenance.
- `airport_group2_section6_batch_completion_v1`: counts and acceptance status by fixed batch.
- `airport_group2_section6_batch_acceptance_v1`: immutable, RLS-protected acceptance records.
- `airport_group2_section6_overall_status_v1`: consolidated result for all 1,118 airports.

All newly created views use `security_invoker=true` and deny direct anonymous/authenticated grants. The acceptance table has RLS and immutable trigger protection.

## Safety and outstanding work
Section 5 operating restrictions remain **OPEN** with 1,118 unknown nighttime/noise restrictions, and none is cleared for dispatch. This Section 6 closure does not bypass it. Group 1 remains 3,141; commercial Group 2 admissions remain 0; World 1 remains `planned`.

Next: Section 7 game-data audit following the established schema, same 23 batches. Independent real-source research for all estimated airport sections remains open.
