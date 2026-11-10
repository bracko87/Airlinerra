# Group 2 — Section 5 restrictions: review register, NOT game-data closure
Date: 2026-11-10

## Current production result
**23/23 fixed batches catalogued**, covering all **1,118/1,118** airports. Every airport has `game_nighttime_ban=NULL` and `game_noise_restrictions=NULL`; `game_restriction_basis=UNSOURCED_NO_OPERATIONAL_CLEARANCE` and `dispatch_restrictions_status=NOT_VERIFIED_FOR_DISPATCH`.

Therefore:
- **0/1,118 restrictions verified or source-ready.**
- **1,118/1,118 need source research**, with preserved unknown values.
- **1,118/1,118 remain dispatch-blocked**.
- Section 5 is **OPEN**, status `source_research_required`; NOT `game_complete_estimated`.

Unknown cannot be replaced by `false`, which could wrongly imply no night ban/noise limit. Real-world dispatch requires reliable dated authoritative sources, and the game must not interpret estimated/default flags as operational authorization.

New read-only review models:
- `airlinerra_game.airport_group2_section5_restrictions_review_v1`
- `airlinerra_game.airport_group2_section5_batch_review_status_v1`
- `airlinerra_game.airport_group2_section5_overall_status_v1`

These are private security-invoker views with direct anon/authenticated grants revoked. Original source and game records remain untouched. World 1 still `planned`, Group 1 unchanged at 3,141, Group 2 has zero airport commercial admissions.

## Follow-on research
For each airport, seek airport/aviation-authority AIP documents, published operational hours, NOTAM or aeronautical publications, dated local restrictions and noise procedures as available. Preserve source URL, effective date, jurisdiction, observed restriction wording, reviewed status and conflicts. AirlineSim may aid airport lookup but cannot certify regulatory permissions or serve as authoritative curfew data.

## Next strict section
Section 6 is **Capacity and Slots** (not Section 5). It has existing provisional game data and should be audited independently while the Section 5 source queue remains open. Section 6 game acceptance does not override Section 5 dispatch blocks.
