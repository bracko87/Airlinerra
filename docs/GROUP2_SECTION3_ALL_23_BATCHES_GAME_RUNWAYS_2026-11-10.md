# Airlinerra — Group 2 Section 3 runway game-data closure
Date: 2026-11-10

All 1,118 owner-preapproved Group 2 airports retain existing runway lengths/surfaces and game widths, assigned using the **same fixed 23 batches** from Section 1. Production database acceptance verified **23/23 batches, 1,118/1,118 GAME runway profiles complete** under `game_complete_estimated`.

- Registry qualified runway length and surface usable in game: 1,118/1,118.
- Game runway widths: 1,118/1,118, including **20 explicitly identified category-median width estimates**. The other 1,098 are source-reported details **not independently verified**.
- **Nine** airports have no detailed runway observation; qualified registry length is present. The missing detailed observation remains visible.
- None of these measurements certifies the airport for any specific aircraft, takeoff weight, runway performance or operational movement. Real dispatch decisions must use separately verified operational constraints.
- `airport_group2_section3_game_registry_v1` records each airport's source-versus-game data distinctions.
- `airport_group2_section3_batch_completion_v1`, immutable `airport_group2_section3_batch_acceptance_v1`, and `airport_group2_section3_overall_status_v1` retain batch acceptance evidence.
- Private views and RLS-protected immutable acceptance snapshots; direct anonymous/authenticated grants revoked.

Independent source verification remains **open**. Group 1 still has 3,141 airports, Group 2 has zero commercial admissions, and World 1 stays `planned`. This change does not make airports playable or update flight scheduling. Next section: **Section 4 facilities**, same 23 batches.
