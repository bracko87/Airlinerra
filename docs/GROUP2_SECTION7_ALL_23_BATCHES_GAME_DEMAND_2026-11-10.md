# Airlinerra — Group 2 Section 7 demand game-data acceptance
Date: 2026-11-10

## Production result
All **1,118 / 1,118** owner-preapproved Group 2 airports have Section 7 passenger/cargo demand game profiles; all **23 fixed batches** accepted as `game_complete_estimated`.

- Passenger only: 953; cargo only: 43; passenger + cargo: 122.
- Daily outbound passengers and cargo tonnes present, nonnegative, consistent with traffic intent and with the main Group 2 game profiles.
- Cargo-only has zero passenger demand, passenger-only has zero cargo demand; each eligible use has positive demand.
- All 1,118 profiles use `GROUP1_CATEGORY_MEDIAN_NEUTRAL_SEASON_GAME_ESTIMATE` and seasonal default `neutral_unverified_game_default_v1`; no independently observed passenger/cargo volumes or real seasonal curves are asserted.
- No Group 2 flight authorization: Section 5 operating restrictions remain unresolved for all 1,118 airports, World 1 remains planned, Group 1 still 3,141 airports.

## Database read models and acceptance
- `airport_group2_section7_game_registry_v1` — per-airport traffic intent, outbound passenger/cargo game demand, estimate basis and completeness.
- `airport_group2_section7_batch_completion_v1` — per-batch completeness.
- `airport_group2_section7_batch_acceptance_v1` — immutable RLS-protected 23-batch acceptance evidence.
- `airport_group2_section7_overall_status_v1` — consolidated game-data completion and explicit no-authorization status.

Private security-invoker views; direct anon/authenticated grants revoked. Acceptance table immutable and RLS-protected. Post-install verification returned 23 batches, 1,118 complete, 0 incomplete batches.

## Outstanding work
Real-world departing demand, cargo tonnage, airport-specific seasonality and route-specific demand distributions need separate independent research and approval. This Section 7 game-data closure does not authorize selling tickets, dispatching aircraft, booking slots or starting the simulation.

Next: Group 2 Section 8 economics, same 23 fixed batches, with Group 1 unchanged.
