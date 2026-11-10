# Airlinerra Group 2 — Section 4 facility game-data closure
Date: 2026-11-10

## Production database acceptance

- 1,118/1,118 preapproved Group 2 airports meet Section 4 **game_complete_estimated**.
- Fixed batch membership reused without movement: 23/23 accepted (batches 1–22: 50; batch 23: 18).
- All 1,118 facility profiles explicitly use `CATEGORY_MEDIAN_GAME_ESTIMATE_NOT_VERIFIED_FACILITY`. **No real airport terminals, stands or handling capacity were independently verified as part of this closure.**
- Passenger-only: 953 with passenger terminals/stands, zero cargo stands.
- Cargo-only: 43 with cargo stands, no passenger terminals/stands.
- Passenger and cargo: 122 with both.
- No NULL/negative facility counts or missing provenance; traffic-intention/facility consistency checked.
- No estimated game facility count is proof of a physical terminal, stand, apron geometry, legal restriction, slot authorization, or actual aircraft compatibility.

## Database objects
- `airport_group2_section4_game_registry_v1` — per-airport facilities, provenance and game acceptance;
- `airport_group2_section4_batch_completion_v1` — live counts by frozen batch;
- `airport_group2_section4_batch_acceptance_v1` — immutable RLS-protected completion snapshots;
- `airport_group2_section4_overall_status_v1` — combined 23-batch result.

Private tables/views deny direct `anon` and `authenticated` access. Post-install SQL readback confirmed 23 batches, 1,118 game-complete, 1,118 estimated, zero incomplete batches. Group 1 remains 3,141, Group 2 commercial-enable count remains zero, World 1 remains `planned`.

## Next
Section 5 — airport operating capacity/slots, against the same 23 batches. Use the existing game-slot model only if documented and internally complete. Never promote estimated facility counts to real-world certification or dispatch authority.
