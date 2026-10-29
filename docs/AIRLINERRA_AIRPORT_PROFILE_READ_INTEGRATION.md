# Airlinerra — Airport profile read integration (29 October 2026)

## Scope
The 3,141 approved World 1 airports remain unchanged. Source-reported fields in `airlinerra_game.airport_reference_profiles`, `airport_runway_inventory`, and `airport_facilities` now have a dedicated authenticated **read-only** per-airport API. Null and source-unverified data must not be promoted into official verified fields.

- API: `POST /api/v1/player/airport-profile` with `{"airportKey":"OURAIRPORTS:4610"}`, authenticated bearer from the existing Supabase Auth session.
- Response: `{airport:{...}}` with separate codes, six-tier provisional/approved category, municipality/region, coordinates, timezone/candidate, game elevation provenance, runway list and facilities.
- Security: endpoint resolves only `airlinerra_game.approved_game_airports` World 1 keys; exact key validation, fresh email-confirmed Supabase Auth check, max 512-byte JSON body, private Postgres, no direct browser DB connections, no changes to gameplay.
- Deployment: **separate** Supabase Edge function `airlinerra-airport-profile` with independently deployed source from `server/airport-profile-edge-entry.ts`. This avoids overwriting the currently live `airlinerra-game` v10, which has airport-office code not yet merged into GitHub main.
- Browser: `website/airline-airports-office.mjs` renders fetched data, correct country/location for HQ, distinguishes candidates/estimated values and marks unknown runway operational status. Demand, live airline activity and slots still display pending.
- Localhost: `npm run preview` from `website` reads through `website/dev-scripts/real-player-read-gateway.mjs`; no private DB password needed.
- Published: `website/netlify/functions/airlinerra-game.mjs` proxies only this new profile route to the dedicated function via `server/production-game-api.mjs`; **Netlify must not be deployed until localhost acceptance**.
- Source and status: Belgrade BEG/LYBE stored: coordinates 44.818401/20.309099, 335 ft source-unverified, Major Hub provisional, Europe/Belgrade timezone candidate, two recorded runways 3500m and 3400m (operational status unknown); terminals/gates/slots/demand unknown.
- No changes to Aspen keep-open, game world activation, airline creations, charges, operations restrictions, pricing, or migration data.

## Local acceptance
1. Approve/merge PR after targeted CI passes; main branch is the normal owner localhost source (separate staging branch is not the normal Airlinerra owner preview).
2. From local repo: `git pull --ff-only origin main`; in `website` run `npm run preview`.
3. Sign in to existing Panonian account. Open Operations > Hubs > Headquarters > Airport profile. Country Serbia, municipality Belgrade, IATA BEG, ICAO LYBE, coords, time zone candidate, two **recorded** runways should be populated.
4. Verify unknown terminal count, slots, demand and commercial flights remain pending; source-unverified values must remain labeled.
5. Search another airport from Airports directory and verify no previously selected airport data leaks into the next profile.
6. Publish website only after manual acceptance.

## CI status
Profile-specific Node contract tests and static build run in `.github/workflows/airport-profile-read.yml`. Existing broad airport-register CI can have an unrelated baseline failure in `tests/test_airport_startup_3140.py` (expected width pending 82 vs actual 0); do not suppress or conflate it with profile integration.
