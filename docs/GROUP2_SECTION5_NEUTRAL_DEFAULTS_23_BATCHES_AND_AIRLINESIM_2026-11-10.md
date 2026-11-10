# Group 2 Section 5 — neutral game defaults and AirlineSim source distinction
Date: 2026-11-10

## User-approved game rule
For Group 2's 1,118 airports divided into 23 fixed batches (22 x 50, final 18), use public AirlineSim airport fields for nighttime bans and noise restrictions when an exact ICAO match provides both values. For airports with no matching sourced rule currently recorded, use **No nighttime ban / No noise restrictions as an explicitly unverified game default**.

This is **game-data completeness only**, not a claim that each airport was searched online or that restrictions do not exist in the real world. Never promote the rule to legal approval, real-world certification, dispatch permission or flight activation.

## Production status verified after migration
- 23/23 batches have complete Section 5 game flags; 1,118/1,118 game profiles populated.
- **2** airports have sourced AirlineSim game settings in the source provenance table.
- **1,116** airports remain neutral game defaults, not researched certificates.
- **5** airports have partial operator/AIP source reviews without both restriction rules resolved; those are still neutral defaults unless AirlineSim-specific data supersedes.
- **1,111** have no individually recorded source review.
- Real-world source verification: **0 complete**; dispatch/source-research queue still **1,118 unresolved**.
- Group 1 still **3,141**, Group 2 commercially activated **0**, World 1 remains `planned`.

### Exact AirlineSim matches used (Batch 1)
- `SBBH` Belo Horizonte Pampulha: AirlineSim night ban **00:01–05:59**; **no noise restrictions**. [AirlineSim game page](https://kaitak.airlinesim.aero/app/info/airports/405?0=&tabs=0). This is an AirlineSim value, NOT an independent legal curfew. Official Brazilian airport hours may differ by applicable publication/effective date.
- `KAFW` Alliance Ft. Worth: AirlineSim **no nighttime ban**, **no noise restrictions**. [AirlineSim game page](https://tristar.airlinesim.aero/app/info/airports/4141?2=&tabs=0).

### Database architecture
- `airport_group2_game_profiles_v1`: game booleans now populated; legacy provenance constraint `UNSOURCED_NO_OPERATIONAL_CLEARANCE` remains unchanged, so game defaults cannot be mistaken for legal dispatch clearance.
- `airport_group2_section5_game_policy_v1`: each airport's game flags, origin (`UNVERIFIED_NEUTRAL_GAME_DEFAULT` or `AIRLINESIM_SOURCE_REVIEWED_GAME_RULE`), source URL and hours when found, recorded-check status, hard false real certification and dispatch approval.
- `airport_group2_section5_game_batch_completion_v1`, `airport_group2_section5_game_overall_status_v1`: game-data completion across the 23 batches.
- `airport_group2_section5_restrictions_review_v1` was corrected to retain source research as required when the underlying value is an unsourced neutral game default, even though its game booleans are no longer NULL.
- Existing source findings, source batch progress, and previously completed sections stay separate and unchanged.

## Limitation: actual internet coverage
AirlineSim does expose nighttime/noise fields on public per-airport pages. Its public Austria country list does not include Batch 1's military LOXT or LOXZ. Search of accessible public results found exact AirlineSim matches SBBH and KAFW, not 1,118 independently verified airport rules. The remaining 1,116 defaults represent **unknown source coverage**, not an assertion that an exhaustive lookup proved absence of restrictions.

## Future upgrades
Research more airports in 50-airport batches; replace a neutral default only when both fields are found for an exact identifier, with source URL and observed date, and retain a history of the prior game assumption. For sourced night bans, store the specified local hours, and for noise restrictions store the actual affected Chapter/class rather than only a Boolean. Be clear that AirlineSim is a game database, not an aviation regulatory authority.

Never activate commercial flights merely because Section 5 estimated game data is complete.
