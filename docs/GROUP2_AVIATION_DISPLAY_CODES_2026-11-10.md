# Airlinerra Group 2 aviation code correction — 2026-11-10

## Original issue
Route planning showed internal artificial database lookup labels (G2-1649, G2-31795) in place of airport location identifiers. Those values were never ICAO codes. User requested realistic airport aviation identifiers for all 1,118 Group 2 airports, shared across worlds.

## Deployed
Migration `supabase/migrations/20261110232000_group2_aviation_display_codes.sql` completed in Supabase production project `hwllkabgzaynalahvkpz`.
- Keeps `airport_key`, `source_ident`, `source_gps_code` and `game_lookup_code` unchanged. The latter has an existing strict check enforcing `G2-%`, so it remains an **internal** lookup code only.
- Creates `airlinerra_game.airport_group2_aviation_display_codes_v1` for separately tracked four-letter display code, original lookup, source, and assurance level. RLS is enabled and the table is not available to public, anon, or authenticated direct access.
- Populates 1,118 codes, all unique, with no collisions with Group 1 approved airport codes.
- Updates the shared `airport_location_eligibility_v1.airport_code` for all three worlds (3,354 Group 2 location rows), retaining selection/flight admission flags and approved rosters unchanged.

## Verified cases
- Ponikve Airport, Serbia, airport key OURAIRPORTS:1649 → **LYUZ**; official airport website https://aerodromponikve.rs/?lang=en states ICAO LYUZ, IATA UZC.
- Kukës International Airport, Albania, airport key OURAIRPORTS:31795 → **LAKU**; airport website https://kuiport.al/en/article/43/Facts-of-KFZ states ICAO LAKU, IATA KFZ.
- Kyiv/Zhuliany, Ukraine, airport key OURAIRPORTS:6478 → **UKKK**, crosschecked with aviation trade directory https://centreforaviation.com/data/profiles/airports/kyiv-igor-sikorsky-international-airport-iev
- Chamical, Argentina, airport key OURAIRPORTS:5774 → **SACT**, *external reported code requiring authority-level confirmation*; source https://airportexpert.com/airports/ar/f/sact.

For the other 1,114 Group 2 airports the 4-letter **source GPS code** was used. OurAirports documents that `gps_code` is not necessarily a verified four-letter ICAO assignment: https://ourairports.com/help/data-dictionary.html. The game must NOT label every 4-letter display code as independently ICAO-confirmed; distinguish sourced GPS identifiers from actual ICAO verification.

## Production API
- `airlinerra-game` Supabase Edge **v24 ACTIVE**: player route picker and prepared airport directory read the corrected shared `airport_location_eligibility_v1.airport_code`. Owner-only Group 2 future location descriptions also use that code.
- `server/player-read-service.mjs` and `server/group2-location-plans-service.mjs` committed on GitHub `main`.
- `tests/test_player_read_api.mjs` regression test added for LYUZ display and nonbookable Group 2.
- The Group 2 detailed planning airport profile already reads `l.airport_code`, so benefits from shared corrections.

## Verified production counts
- 1,118 Group 2 display codes, all exactly 4 uppercase letters and unique.
- 0 Group 1 collisions.
- 3,354/3,354 Group 2 location rows use matching corrected codes across the three worlds; zero G2- placeholders in the location display column.
- 3 sourced ICAO identifications, 1 separately reported candidate pending authority verification, 1,114 source GPS identifiers pending ICAO verification.
- Group 1 approved roster remains 3,141, Group 2 commercial activation remains 0.

## Still to verify
An actual authenticated localhost/browser screen has **not** been observed after frontend restart. Passing GitHub Actions test outcome not verified. The changed database / Edge source has been read back. Changes do not activate flights.
