# Airlinerra world activation and global airport catalog correction — 2026-11-10

## User-approved corrections performed
1. Changed public.airlinerra_game_worlds World 1 **Horizon** from `planned` to **`active`**, setting `opens_at` to the true database time. Verification: `2026-11-10 16:40:21.38715+00`. Atlas (World 2) and Odyssey (World 3) remain `planned`, as no opening was requested for them.
2. Removed the `world_id=1` constraint from `airlinerra_game.airport_location_eligibility_v1` and inserted the **same 4,259 location-eligible airports** in each world. Each world includes **1,118 Group 2** locations. World-specific airline membership, scheduling and financial state remain separate.
3. Updated `server/onboarding-context-service.mjs` to enrich airport-location records in every world from a **shared World 1 source catalog** for categories, runway lengths, coordinates and other metadata. Deployed new source to `airlinerra-game` Supabase Edge **version 21**.
4. Committed migrations `20261110223000_share_location_catalog_across_worlds.sql` and `20261110224000_open_horizon_world1.sql` on GitHub `main`.

## Verified production data
| World | State | Eligible airport locations | Group 2 |
|---|---|---:|---:|
| Horizon / 1 | active | 4,259 | 1,118 |
| Atlas / 2 | planned | 4,259 | 1,118 |
| Odyssey / 3 | planned | 4,259 | 1,118 |

All 4,259 records per world have category and runway data in the onboarding join. The operational `approved_game_airports` registry still has **3,141** World 1 airports and Group 2 commercial approvals **0**. Group 2 slot reservations **0**. The global platform public release gate remains **false**, so this is NOT confirmation that public user registration is open.

The authoritative game-time clock remains `not_connected` for each world; no tick proof or clock date was fabricated. Flight movement and scheduling gates must not be bypassed merely because world state is active.

## Design rule
Airport identities and physical attributes are **global/shared**, not specific to World 1. World-specific differences should be player/airline data, game time, airline financial state, booking capacity usage, traffic schedules and world release status. Group 2 HQ/station/hub location eligibility is separate from operational/dispatch approval.

## Still open
- Shared location records were populated in all three world rows; a durable propagation strategy for later catalog edits should be designed/verified before future changes to the airport catalog.
- Public release policy/legal approval and game-clock connection are separate from `worlds.state`.
- External static website deployment and end-to-end login checks are unverified.
- Group 2 commercial operations are not live, even though HQ/office locations can be selected in the protected backend.
